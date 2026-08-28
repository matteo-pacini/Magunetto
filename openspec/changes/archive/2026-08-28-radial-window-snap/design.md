## Context

See `proposal.md` — Why for motivation, and `specs/` for the behavior being built.

Three constraints shape everything below.

**The code must run inside the compositor.** On Wayland, an external client cannot move another
client's window: no protocol grants it, and both attempts to standardise one were rejected. The
two supporting capabilities fail independently as well — the global-shortcuts portal has open bugs
where held shortcuts stick, and an override-redirect overlay is stacked above other windows but
never receives keyboard focus by design. Since the whole interaction is "hold a key, watch the
pointer, release to commit", an external process is not a viable host.

**Every mechanism already exists in shipped code, but has never been combined this way.** GNOME's
own Alt-Tab switcher detects modifier release; Fly-Pie's Turbo Mode proved hold-and-gesture works
in an extension; Tactile shows the modal fullscreen overlay shape in about 200 lines; the tiling
extensions have converged on how to move a window so it actually lands. No radial window snapper
exists on Linux, so the novelty is assembly, not invention.

**The target is a single GNOME version.** GNOME 50.4 is what runs on the development machine and is
current stable. GNOME 51 is expected roughly a month out and removes an API this design depends on.

## Goals / Non-Goals

**Goals:**

- Run entirely inside GNOME Shell as one extension, with no helper process or daemon.
- Keep the interaction responsive: the code executes on the compositor thread, so a stall is a
  desktop-wide stutter, not a slow app.
- Keep sector and rectangle maths free of any toolkit import so it is unit-testable outside a
  running shell.
- Make the whole feature verifiable headlessly and unattended, so changes can be checked without a
  human logging out and watching the screen.

**Non-Goals:**

- Portability to other compositors. KDE and wlroots would each need a separate implementation in a
  different language; the shared surface is the maths and nothing else.
- Supporting more than one GNOME version from one branch. No version probes, no feature detection,
  no compatibility shims.
- Publishing to extensions.gnome.org as part of this change. The licence stays GPL-compatible so
  the option survives, but review and submission are separate work.
- Loop's wider feature set — window cycling, drag-to-snap, preview animation, undo history,
  padding configuration. This change is the radial gesture and the snap it produces.

## Decisions

### Ship as a GNOME Shell extension in GJS

Alternatives considered and rejected: a normal application using the global-shortcuts portal plus a
layer-shell overlay (Mutter implements no layer-shell, the portal's held-shortcut bugs are open,
and no protocol would let it move the window anyway); an XWayland override-redirect overlay (gets
stacking but never keyboard focus, so the gesture cannot be read); a Mutter patch (unshippable).

The extension route is not merely the best option, it is the only one where all three required
capabilities exist at once.

### Target GNOME 50 only, with a branch and tag per major

`metadata.json` declares `"shell-version": ["50"]` and the code assumes 50 throughout. When GNOME 51
arrives, a new branch adapts to it; the GNOME 50 tag keeps working for anyone still on 50.

The alternative — one codebase spanning several versions — is what makes the existing tiling
extensions hard to read, and the churn on this exact code path is real: 45 renamed the rectangle
type, 49 changed the maximise signature, 50 changed grab semantics, and 51 replaces the key-release
mechanism. Guarding all of that inline costs more than maintaining a branch, and this change does
not need to serve users on older distributions.

The cost is accepted deliberately: a GNOME 50-only extension serves few people beyond its author
until the 51 branch lands.

### Detect modifier release the way the Alt-Tab switcher does

The commit signal is release of the shortcut's *modifier*, not of its trigger key. The mechanism:
take the modifier mask from the keybinding, reduce it to its primary (highest) bit, take a modal
grab, and on each key-release event re-read live modifier state from the pointer query rather than
trusting the event's own state field. When the primary modifier bit is clear, commit.

Two details are copied deliberately because they are bug fixes, not style. Live modifier state is
re-read because the event's state predates the release. And a bounded timeout is required for a
shortcut configured without any modifier, which otherwise can never commit — this is what satisfies
the "menu always dismisses itself" requirement.

**Amended during implementation.** This design originally called for checking that the grab actually
captured the keyboard. GNOME 50 removed both `Clutter.GrabState` and `grab.get_seat_state()`, and
the shell's own switcher no longer checks anything — it just takes the grab. The check is therefore
made by asking who holds key focus after `pushModal`: if it is not the menu actor, the gesture
aborts and releases. Same guarantee, expressed through an API that still exists.

Rejected alternative: the keybinding flag that re-invokes the handler on key release. It fires on
release of the trigger key, not the modifier, which is the wrong semantics — the user may release
the letter while still holding the modifier and continuing the gesture.

Also rejected: polling modifier state on a timer, which is what every existing tiling extension
does for its drag features. It is what forced their "hold" features to require an in-progress mouse
drag, and it costs a wakeup per interval on the compositor thread.

### Take the modal grab with a system-modal action mode

A modal grab is what routes both key-release and pointer motion to the overlay actor. Taking it
with the default action mode would suppress every other shortcut while the menu is up; the
system-modal mode is what Tactile uses and keeps the rest of the desktop's bindings alive.

Grab acquisition can lose a race, so the result is checked and the gesture aborts cleanly if the
keyboard was not actually grabbed. Immediately after grabbing, live modifier state is sampled once
— if the user already released, the gesture commits or cancels right there. That closes the
"released before the menu appeared" scenario in the spec.

### Draw with a fullscreen reactive widget and a Cairo drawing area

The overlay is one reactive container sized to the target monitor, holding a drawing area that
paints the sectors. It is added to the shell's top chrome so it sits above windows and popups.

Direct Cairo painting is chosen over composing the menu from styled child actors because the shape
is radial: sector wedges, an inner dead zone, and a highlight that follows an angle. Expressing
that as widgets means fighting a box-oriented layout system. Colours and lengths still come from
the theme node so the menu honours the user's theme and HiDPI scaling rather than hardcoding
pixels.

Selection changes trigger a repaint. Animated transitions use the actor's easing and an adjustment
object for any interpolated drawn value, so no manual frame timer runs on the compositor thread.

### Keep the gesture maths in toolkit-free modules

`sectorFor(dx, dy)` and `rectFor(sector, workArea)` import nothing. The work area crosses the
boundary as a plain object, and the extension converts the compositor's rectangle type at the edge.

This is what makes the fastest test tier possible — the maths runs under a plain JS test runner in
milliseconds, with no shell, no display, and no D-Bus. Angle bucketing, the three distance bands,
and the abut-without-gaps property of adjacent halves are all pure functions of their inputs and
belong there.

### Keep every direction reachable from a screen edge

When a gesture starts near a screen edge, the pointer cannot travel further in that direction and
absolute position stops changing — the far sectors become unreachable.

The original plan was Loop's: integrate raw movement deltas past the clamp. That is not available
here. `Clutter.Event.get_relative_motion()` exists but takes six out-parameters that GJS does not
map, so calling it throws.

Instead the gesture reads absolute coordinates and pulls the *origin* inward: it is clamped to at
least the ring radius away from every edge of the monitor. A pointer pinned against the right edge
is then still that far to the right of the origin, so the right sector is selectable. The menu is
drawn at the same clamped origin, so what is shown matches what is selected. A monitor too narrow to
clamp on both sides falls back to centring.

### Apply geometry with the sequence the tiling extensions converged on

Clear maximised and fullscreen state first, or the placement is silently ignored. Compute against
the monitor's work area so panels are excluded. Then move, then move-and-resize — the redundant
first move is the shipped workaround for windows that resize in fixed increments, which otherwise
take the new size but stay where they were.

Geometry is applied as a user operation so the window is not clamped in ways that break
multi-monitor placement.

Resize is asynchronous on Wayland: reading geometry back immediately returns stale values. Anything
that needs the settled rectangle waits for the window's own geometry-changed signal instead of
reading straight after the call. This matters more for tests than for the feature itself.

### Ship the default shortcut as a schema default

The accelerator lives in the compiled GSettings schema as its default value rather than being
written at enable time. A settings write on the enable path was observed to be applied only
intermittently, leaving the shortcut silently unbound. Making it a schema default removes the write
from the critical path entirely.

The default is `<Alt>z`. Two constraints narrowed the choice, both found by testing candidates
against a running shell:

- **Super cannot be the held modifier.** Pressing Super switches the shell into overview action
  mode, and a keybinding registered for normal mode stops matching while it is held, so the handler
  never runs. This rules out the whole family of Super combinations.
- **`<Alt>space` reads best but is taken.** GNOME binds it to the window menu, and that binding
  wins: the shortcut silently does nothing until the user clears it. Rejected as a default because
  it would appear broken on a fresh install.

`<Alt>z` fires reliably, needs one modifier, is one-handed, and collides with nothing in GNOME's
defaults. Users can rebind to anything in preferences, including `<Alt>space` once they clear the
window-menu binding.

### Expose a test interface from inside the extension, gated by an environment variable

Assertions cannot come from outside: the shell's evaluation interface and its screenshot interface
are both restricted to allowlisted callers, and the window-introspection interface is limited to
portal senders and reports no geometry.

So the extension exports its own D-Bus interface when a designated environment variable is set, and
not otherwise. It offers three things: synthetic input via compositor virtual input devices
(keyboard and pointer, including the modifier press and release the gesture depends on), the target
window's current rectangle, and an ordered log of internal state transitions.

That log is the primary assertion surface. A run yields a trace like `enabled`, `keybinding-fired`,
`overlay-up`, `motion`, `release`, `snapped:right`, which states what the extension believed
happened, in order. Asserting on that is far more stable than asserting on pixels — Fly-Pie
disabled its image-diffing CI in March 2026 precisely because it was too flaky.

Rejected alternative: running the shell with its unsafe mode enabled and using the evaluation
interface for assertions. It works, and the harness enables it anyway for screenshots, but building
the assertions on it would make the tests depend on a debugging escape hatch rather than on an
interface the extension controls.

This design deliberately mirrors ddterm, which uses the same shape — in-shell test hook, virtual
input devices, host-side assertions over D-Bus — and is the only actively maintained extension with
CI that genuinely exercises behavior rather than just linting.

### Two test tiers

The inner loop boots a headless shell with a virtual monitor, in an isolated environment so it
cannot touch the developer's real desktop settings, with the extension symlinked in. It drives the
gesture through the test interface and asserts on the state log and the resulting rectangle. A full
cycle is on the order of fifteen seconds. Screenshots are captured on failure only, as diagnostics.
The shell's error output is scanned for JavaScript exceptions, which fail the run even if the
assertions passed.

The merge gate adds a NixOS virtual-machine test that boots a real session, plus the pure-maths unit
tests. The VM tier has a hard limitation: its key-sending primitive presses and releases atomically,
so it cannot hold a modifier while moving the pointer. The gesture must therefore be driven through
the in-shell test interface even there — which is another reason that interface exists.

Environment isolation is not optional. The settings database is a file keyed by the home directory,
not by the message bus, so a test session sharing the developer's home would write to their real
desktop configuration.

### Package with Nix, install per-user for development

The devShell gains the shell (for its test tool), the GLib tooling, a JS engine, Node, and a JSON
processor. Tools that cannot work on this target are deliberately excluded rather than left in
hopefully: with the X11 backend removed and neither a virtual-keyboard nor a screen-copy protocol
implemented, the usual Wayland automation tools are all dead ends here.

For development the extension directory is symlinked into the per-user extension path so edits are
live. The packaged derivation follows the pattern nixpkgs already uses for source-built extensions.

## Risks / Trade-offs

- **Extension code runs on the compositor thread** → any stall janks the entire desktop, unlike an
  app that only janks itself. Repaints are confined to selection changes, no polling timers are
  used, and the maths is trivial arithmetic. This is the main reason the polling approach used by
  other extensions was rejected.

- **GNOME 51 lands in roughly a month and removes the key-release mechanism** → the replacement API
  already exists in GNOME 50's introspection data, so the migration is known before it is needed.
  The 50 branch is tagged and left working; 51 is a separate branch. Accepted cost of the
  single-version decision.

- **A modal grab that is taken but never released wedges the desktop** → release is guaranteed on
  every exit path including commit, cancel, timeout, and actor destruction, and grab acquisition
  failure aborts the gesture rather than proceeding half-initialised. The spec makes guaranteed
  dismissal a requirement precisely so this is tested rather than assumed.

- **Windows do not always accept the requested geometry** → applications with size increments,
  minimum sizes, or fixed aspect ratios land close but not exact. The specs require correct origin
  and best-effort size rather than exact dimensions, and tests assert on the axes the feature
  controls rather than on all four numbers.

- **The first synthetic pointer warp after creating a virtual device was observed to drop one
  coordinate** → the harness issues the initial warp twice. A test-harness quirk, not a product
  bug, but it silently corrupts the first gesture of a run if ignored.

- **The shell boots with the overview showing** → focus tracking misbehaves until it is dismissed,
  so the harness closes it and waits before asserting anything about the focused window. The shell
  also returns to the overview whenever the last window closes, and the hot corner can be tripped by
  a synthetic warp, so the harness disables hot corners and re-checks the action mode before
  injecting a shortcut.

- **A throwaway `HOME` does not isolate settings** → GSettings still reaches the running dconf
  service over the session bus, so harness writes land in the developer's own desktop configuration.
  This happened during implementation and had to be undone by hand. Sessions now also force
  `GSETTINGS_BACKEND=keyfile`, which keeps every write inside the temporary directory.

- **A GNOME 50-only extension has almost no audience** → accepted deliberately. The user is the
  first user; the 51 branch widens it later.

## Migration Plan

Nothing to migrate — no existing users, no existing code, no data.

Development installs by symlink into the per-user extension directory, with extension version
validation disabled in the test session only. Release is a tag on the GNOME 50 branch plus a Nix
derivation that installs into the system extension path.

Rollback is disabling the extension, which restores stock behavior immediately; no window state
outlives the process.

## Open Questions

- Whether the sector arrangement should be user-configurable (count, which action sits in the
  centre) or fixed at eight directions plus centre. The specs fix the default arrangement, and
  configurability can be added later without changing them.
- Whether to show a preview of the destination rectangle while the gesture is in progress. Loop
  does; it is additive and changes no committed behavior.
- Whether the extension should later be submitted to extensions.gnome.org, which brings review
  requirements and a wider support burden.
