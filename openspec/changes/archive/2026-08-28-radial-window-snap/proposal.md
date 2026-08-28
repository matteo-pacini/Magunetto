## Why

Radial, direction-based window snapping does not exist on Linux. macOS has Loop, where holding a
key raises a radial menu and flicking the mouse toward a sector snaps the focused window to that
region of the screen. On GNOME the equivalent tools are all rectangular zone pickers or
keyboard-only tile selectors, which require aiming at a target rather than gesturing in a
direction. Direction is faster than aim: a sector spans 45 degrees and needs no precision, so the
gesture can be made without looking at the menu once it is learned.

The interaction is feasible on GNOME 50 but only from inside the compositor. Wayland gives an
external application no way to move another application's window, and both attempts to standardise
such a protocol were rejected. The portal that provides global shortcuts has open bugs where held
shortcuts stick, and an override-redirect overlay never receives keyboard focus by design. A GNOME
Shell extension has none of these limitations, and every mechanism the interaction needs already
exists in shipped GNOME code — the Alt-Tab switcher detects modifier release, Fly-Pie proved
hold-and-gesture works in GJS, and the tiling extensions have settled how to move a window
reliably. Nobody has assembled them into a radial snapper.

## What Changes

- New GNOME Shell extension, `magunetto@matteopacini.me`, written in GJS.
- A configurable shortcut raises a radial overlay on the monitor holding the focused window.
- While the shortcut modifier is held, pointer movement selects a sector by angle and distance
  from the point where the gesture began. Releasing the modifier applies the sector's geometry to
  the focused window; Escape cancels without moving it.
- Sectors cover the eight compass directions (halves and quarters) plus a centre action, matching
  Loop's default arrangement.
- A test-only D-Bus interface, exported only when an environment variable is set, drives synthetic
  input and reports internal state so the extension can be verified headlessly with no human
  watching the screen.
- Targets GNOME 50 exclusively. No compatibility shims, version probes, or feature detection. Each
  future GNOME major gets its own branch and tag, and the GNOME 50 tag remains usable by GNOME 50
  users after that.

## Capabilities

### New Capabilities

- `radial-menu`: Raising, drawing, and dismissing the radial overlay, and translating pointer
  movement into a selected sector. Covers shortcut invocation, the modal grab, hold-and-release
  commit semantics, cancellation, and what the user sees while choosing.
- `window-snap`: Choosing the window to act on and giving it new geometry. Covers resolving the
  target window, mapping a sector to a rectangle within the monitor's work area, and applying that
  rectangle so it survives maximised state and applications that constrain their own size.

### Modified Capabilities

None. This is a new project with no existing specs.

## Impact

- **New code**: extension sources (`extension.js`, `prefs.js`, `metadata.json`, a compiled GSettings
  schema), overlay and geometry modules, and a test harness.
- **Geometry and sector maths live in modules that import nothing from `gi://`**, so they can be
  unit-tested outside a running shell.
- **`flake.nix`**: the devShell currently provides only `openspec`. It gains `gnome-shell` (for
  `gnome-shell-test-tool`), `glib` (for `gdbus` and `glib-compile-schemas`), `gjs`, `nodejs`, and
  `jq`. Tools that cannot work on GNOME 50 — `wtype`, `grim`, `xdotool`, `xvfb-run` — are
  deliberately excluded.
- **Testing**: a headless `gnome-shell --headless --virtual-monitor --unsafe-mode` session under
  `dbus-run-session` forms the inner development loop; a `pkgs.nixosTest` and unit tests for the
  pure maths form the merge gate.
- **Distribution**: installable from the flake into
  `~/.local/share/gnome-shell/extensions/<uuid>`. Publishing to extensions.gnome.org is out of
  scope for this change, but the licence must stay GPL-compatible to keep that option open.
- **No changes to existing systems.** The repository currently contains no source code.
