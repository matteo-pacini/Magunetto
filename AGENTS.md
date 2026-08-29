# Magunetto

A GNOME Shell extension: hold a shortcut, flick the pointer toward a direction, release, and the
focused window snaps to that region. GJS, targeting **GNOME 50 only**.

## Why it is shaped this way

Wayland gives no client the ability to move another client's window, and no protocol for it was ever
accepted. The gesture also needs modifier-release detection and a grab, neither of which an external
app can get. So the code runs inside the compositor as an extension — that is the only place all
three are possible, not a preference.

One GNOME version per branch, no version guards. The APIs this depends on changed in 45, 49, 50 and
again in 51; guarding them inline is what makes comparable extensions hard to read.

## Map

| Path | What it holds |
|---|---|
| `magunetto@matteopacini.me/extension.js` | keybinding, gesture lifecycle, state log |
| `magunetto@matteopacini.me/prefs.js` | the shortcut, and the two snapping settings |
| `magunetto@matteopacini.me/lib/geometry.js` | sector and rect maths — imports nothing, unit-tested |
| `magunetto@matteopacini.me/lib/curveInfo.js` | travel styles and their prose — imports nothing, read by prefs too |
| `magunetto@matteopacini.me/lib/curves.js` | resolving a style into Clutter easing |
| `magunetto@matteopacini.me/lib/animate.js` | freeze, snapshot, counter-transform, ease |
| `magunetto@matteopacini.me/lib/radialMenu.js` | modal grab, release detection, Cairo drawing |
| `magunetto@matteopacini.me/lib/snap.js` | target eligibility, applying geometry |
| `magunetto@matteopacini.me/lib/testInterface.js` | test-only D-Bus surface, gated on `MAGUNETTO_TEST` |
| `tests/harness/` | headless-shell harness; `cases/` is one file per behaviour |
| `openspec/changes/*/specs/` | the behaviour contract; scenarios map 1:1 to harness cases |

`README.md` covers install and usage. `openspec/changes/*/design.md` records why each technical
choice was made, including the rejected alternatives.

## The loop

Everything runs inside `nix develop`.

```sh
node --test tests/*.test.js                 # maths and curve table, ~75ms, no shell
dbus-run-session -- tests/harness/run.sh    # 31 cases against a headless shell, ~85s
dbus-run-session -- tests/harness/run.sh gesture cancel   # named cases while iterating
tests/run-all.sh                            # both tiers; --vm adds the VM test (~15min)
tests/harness/watch.sh                      # nested shell in a window, to drive by hand
```

Work at the cheapest tier that can prove the change: geometry changes need only the unit tier;
anything touching the shell needs the harness. Add a case in `tests/harness/cases/` for each spec
scenario you affect — a case defines `case_body()` and uses the helpers in `harness/lib.sh`
(`begin_gesture`, `flick`, `end_gesture`, `mg_log`, `mg_rect`, `assert_eq`). A case may override
`CASE_MONITORS`, `CASE_SHORTCUT`, `CASE_ANIMATION`, `CASE_CURVE` and `CASE_DESKTOP_ANIMATIONS`;
sharing those values with another case means sharing its session rather than booting a new shell.

Assert on the extension's state log and on window geometry, not on pixels. Failing cases leave a
screenshot and the shell log in `.harness/`.

The snap animation is the exception: it changes neither, so it is only visible through `mg_xform`
and `mg_ghosts`, and only while it runs. Release with `release_gesture`, assert with
`assert_travels` / `assert_no_travel` / `assert_at_rest`, then `settle_travel`. `end_gesture` waits
the travel out, so a case built on it passes whether the window travelled or teleported.

## The demo

`assets/demo.gif` is generated, not hand-made, so it always shows the code as it stands:

```sh
dbus-run-session -- tests/harness/run.sh _demo   # records .harness/demo.webm
tests/harness/demo-encode.sh                     # writes assets/demo.{gif,mp4}
```

`_demo.sh` is a case that records rather than asserts; `run.sh` skips `_`-prefixed files unless they
are named. Screenshots cannot capture this — one costs a good part of the 220ms a travel lasts — so
it drives `org.gnome.Shell.Screencast` instead.

## Traps

These cost hours to rediscover.

- **The shell cannot be restarted on Wayland.** Never tell someone to log out to test a change; use
  `watch.sh` or the harness.
- **A new file that is not `git add`ed does not exist to the VM tier.** `nix build` takes a flake's
  source from the git tree, so an untracked file is simply absent from the derivation — the VM
  installs an extension whose imports point at nothing, and the only symptom is that it never
  reaches ACTIVE (`ImportError: Unable to load file from: .../lib/curves.js`). The unit and harness
  tiers read the working tree and see the file, so they pass. `git add` before running `--vm`.
- **Test sessions need a throwaway `HOME` *and* `GSETTINGS_BACKEND=keyfile`.** With only the first,
  GSettings reaches the real dconf service over the session bus and writes land in the developer's
  desktop configuration. This has already happened once.
- **`org.gnome.Shell.Eval` answers `(true, '<json>')`, or `(false, '')` when refused.** Match the
  quoted value. `grep -q false` matches the *refusal*, which silently turns a check into a no-op.
- **Eval and Screenshot need `gnome-shell --unsafe-mode`.** In a NixOS VM, override the template unit
  `org.gnome.Shell@`, not the instance `org.gnome.Shell@wayland`, or it has no effect.
- **The first synthetic pointer warp after a virtual device is created drops a coordinate.** Warp
  twice; `harness/lib.sh` does this once per run.
- **Super cannot be a hold-modifier.** Pressing it switches the shell to overview action mode, and
  bindings registered for normal mode stop matching. The hot corner does the same, so the harness
  disables it.
- **`watch.sh` is deaf if the extension is already installed on your desktop.** The outer compositor
  matches its own keybindings before anything reaches the nested window, so the shortcut is consumed
  out there. Give the nested session a different one rather than disabling your real extension —
  that writes to `enabled-extensions`, which is Home Manager's on this machine.
- **A move is reported synchronously; a resize is not.** `move_frame()` emits `size-changed` before
  it returns, with the new rectangle already in place, and emits nothing further. `move_resize_frame()`
  emits one immediately that still carries the *old* size, then another once the client acks the
  configure. `get_frame_rect()` right after the call still reports the old size. Anything driven off
  the first report animates a scale of 1; anything connected after the call misses a pure move
  entirely.
- **`MetaWindowActor.freeze()` is refcounted and an unpaired one is permanent.** A frozen actor stops
  updating for good — no repaints, no geometry. Every path out has to thaw, including the ones where
  the expected signal never arrives. Snapping to the rectangle a window already occupies reports
  nothing at all, which is the case that finds this.
- **`Main.wm.skipNextEffect()` is a queue, not a flag.** It is a `Set` drained by `.delete()`, so a
  skip that is never consumed swallows the next unrelated effect for that actor — a window that
  silently fails to animate when minimised, much later. Queue it only immediately before the call
  that consumes it.
- **A window mapping after synthetic input loses the focus-stealing race** and must be activated
  explicitly. With no windows open the shell falls back to the overview, which holds a grab.
- **A screencast dies with its caller.** `org.gnome.Shell.Screencast` ties the recording to the
  D-Bus connection that asked for it, and `gdbus call` exits as soon as its call returns — so the
  call answers `(true, '<path>')`, leaves a stub file, and the log says `Fatal error while
  recording: Sender has vanished`. Ask from inside the shell with an `Eval` call: the shell is then
  the sender and is still there to stop it. Its bus name is its own, not a path under
  `org.gnome.Shell`, and `file_template` now wants no extension.
- **Verify APIs against the installed shell**, not against documentation or memory. GNOME 50 removed
  `Clutter.GrabState`, `grab.get_seat_state()` and `Meta.Window.get_maximized()`, and
  `Clutter.Event.get_relative_motion()` is unusable from GJS. Read the shell's own sources — the JS
  is bundled in `libshell-18.so`:

  ```sh
  SO=$(dirname $(readlink -f $(command -v gnome-shell)))/../lib/gnome-shell/libshell-18.so
  gresource extract "$SO" /org/gnome/shell/ui/switcherPopup.js
  ```

  For anything else, probe the live API from a headless session with an `Eval` call rather than
  trusting documentation.

## Planning

This repo uses OpenSpec: `openspec list`, `openspec status --change <name>`. Behaviour changes belong
in a change's `specs/` before they are implemented, and each scenario should end up with a harness
case.
