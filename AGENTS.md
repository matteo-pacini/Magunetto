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
| `magunetto@matteopacini.me/lib/geometry.js` | sector and rect maths — imports nothing, unit-tested |
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
node --test tests/*.test.js                 # maths only, ~75ms, no shell
dbus-run-session -- tests/harness/run.sh    # 21 cases against a headless shell, ~53s
dbus-run-session -- tests/harness/run.sh gesture cancel   # named cases while iterating
tests/run-all.sh                            # both tiers; --vm adds the VM test (~15min)
tests/harness/watch.sh                      # nested shell in a window, to drive by hand
```

Work at the cheapest tier that can prove the change: geometry changes need only the unit tier;
anything touching the shell needs the harness. Add a case in `tests/harness/cases/` for each spec
scenario you affect — a case defines `case_body()` and uses the helpers in `harness/lib.sh`
(`begin_gesture`, `flick`, `end_gesture`, `mg_log`, `mg_rect`, `assert_eq`).

Assert on the extension's state log and on window geometry, not on pixels. Failing cases leave a
screenshot and the shell log in `.harness/`.

## Traps

These cost hours to rediscover.

- **The shell cannot be restarted on Wayland.** Never tell someone to log out to test a change; use
  `watch.sh` or the harness.
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
- **A window mapping after synthetic input loses the focus-stealing race** and must be activated
  explicitly. With no windows open the shell falls back to the overview, which holds a grab.
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
