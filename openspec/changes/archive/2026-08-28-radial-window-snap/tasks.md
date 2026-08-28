## 1. Project skeleton and development environment

- [x] 1.1 Add `gnome-shell`, `glib`, `gjs`, `nodejs`, and `jq` to the `flake.nix` devShell and verify `gnome-shell-test-tool`, `gdbus`, `glib-compile-schemas`, `gjs`, and `node` all resolve inside `nix develop`
- [x] 1.2 Create the extension skeleton (`metadata.json` declaring shell-version 50 and the UUID, an `extension.js` whose enable/disable do nothing yet) and verify `gnome-extensions info <uuid>` reports the extension after symlinking it into the per-user extension directory
- [x] 1.3 Add the GSettings schema with the default shortcut accelerator as the schema default value, compile it, and verify `gsettings get` returns that accelerator without any prior write
- [x] 1.4 Add a minimal `prefs.js` that renders the shortcut setting and verify `gnome-extensions prefs <uuid>` opens without error

## 2. Gesture mathematics (no toolkit imports)

- [x] 2.1 Implement `sectorFor(dx, dy)` mapping accumulated pointer delta to a dead-zone result, the centre action, or one of eight directional sectors, importing nothing from `gi://`
- [x] 2.2 Implement `rectFor(sector, workArea)` mapping a sector to a rectangle within a plain work-area object
- [x] 2.3 Add a Node test runner and unit tests covering the three distance bands, all eight directions being distinct, and adjacent halves abutting with no gap and no overlap; verify the suite passes with no shell running

## 3. Headless test harness

- [x] 3.1 Add the env-gated test D-Bus interface to the extension exposing the state log, the target window rectangle, and synthetic keyboard and pointer input via compositor virtual input devices; verify it is absent when the environment variable is unset and present when it is set
- [x] 3.2 Write the harness script that boots a headless shell with a virtual monitor and unsafe mode under an isolated home, data, and config directory, and verify the developer's real desktop settings are untouched after a run
- [x] 3.3 Make the harness poll for shell readiness and dismiss the overview before asserting, and verify the focused window is reported correctly on a cold boot
- [x] 3.4 Make the harness issue the first pointer warp twice to work around the dropped-coordinate quirk, and verify a warp to a known position reports that exact position
- [x] 3.5 Add JavaScript exception detection over the shell's error output and verify a deliberately thrown error fails the run even when assertions pass
- [x] 3.6 Add failure-only screenshot capture and verify a PNG is produced when an assertion fails and not when the run succeeds

## 4. Trigger, modal grab, and release detection

- [x] 4.1 Register the keybinding from the schema with auto-repeat ignored, and verify via the state log that holding the shortcut fires it exactly once
- [x] 4.2 Take the modal grab with the system-modal action mode, check the grab actually captured the keyboard, and verify the gesture aborts cleanly with the grab released when acquisition fails
- [x] 4.3 Resolve the primary modifier bit from the keybinding mask and commit on release by resampling live modifier state rather than trusting event state; verify with a synthetic press, motion, and release that the log shows the release and the commit
- [x] 4.4 Sample modifier state once immediately after grabbing and finish straight away if already released; verify a press-then-immediate-release leaves no menu on screen
- [x] 4.5 Add the bounded dismissal timeout for a shortcut configured with no modifier, and verify the menu dismisses without further input
- [x] 4.6 Handle Escape as cancel, and verify a later modifier release after Escape does not move the window
- [x] 4.7 Guarantee the grab is released on every exit path including commit, cancel, timeout, and actor destruction; verify by running all four paths in sequence and confirming input still reaches the desktop afterwards

## 5. Overlay rendering

- [x] 5.1 Add the fullscreen reactive container sized to the target window's monitor, placed in the shell's top chrome, and verify a screenshot shows it covering that monitor
- [x] 5.2 Draw the sectors, dead zone, and centre action with Cairo, taking colours and lengths from the theme node; verify a screenshot shows the menu and that it scales with the HiDPI scale factor
- [x] 5.3 Repaint on selection change so the selected sector is visually distinct and no sector is highlighted in the dead zone; verify by screenshot at three pointer positions
- [x] 5.4 Route pointer motion from the grabbed actor into accumulated deltas feeding `sectorFor`, and verify the state log shows the selection following a multi-direction gesture
- [x] 5.5 Verify a gesture beginning against a screen edge can still select the sector pointing off that edge
- [x] 5.6 Add easing for menu appearance and dismissal using actor easing and an adjustment for interpolated drawn values, with no manual frame timer; verify no timer sources remain after dismissal

## 6. Window snapping

- [x] 6.1 Capture the target window at gesture start and keep acting on it for the whole gesture; verify a focus change mid-gesture still moves the original window
- [x] 6.2 Refuse windows that cannot be moved or resized and surfaces that are not ordinary application windows; verify no gesture starts and nothing moves
- [x] 6.3 Handle the target window closing mid-gesture without error; verify the run completes with no exception in the shell log
- [x] 6.4 Convert the compositor rectangle type to the plain work-area object at the boundary and compute geometry from the monitor work area; verify a snapped window does not overlap the panel
- [x] 6.5 Clear maximised and fullscreen state before applying geometry; verify a maximised window and a fullscreen window both take the requested half
- [x] 6.6 Apply geometry as a user operation using the move-then-move-and-resize sequence; verify a terminal with size increments moves to the correct origin rather than staying put
- [x] 6.7 Verify a window with a minimum size larger than the target moves to the requested origin and keeps its minimum size
- [x] 6.8 Verify snapping the same window to the same sector twice produces identical geometry both times

## 7. End-to-end verification against the specs

- [x] 7.1 Add a harness test per scenario in `specs/radial-menu/spec.md` and verify all pass
- [x] 7.2 Add a harness test per scenario in `specs/window-snap/spec.md` and verify all pass
- [x] 7.3 Verify the full inner-loop cycle completes in roughly fifteen seconds and leaves no stray shell process or socket behind
- [x] 7.4 Run a multi-monitor harness configuration and verify the menu appears on the monitor holding the focused window and geometry stays on that monitor

## 8. Packaging and merge gate

- [x] 8.1 Add the Nix derivation that compiles the schema and installs into the system extension path, and verify the built output loads in a headless session
- [x] 8.2 Add the NixOS virtual-machine test that boots a session, enables the extension, drives the gesture through the test interface rather than the atomic key-send primitive, and asserts the resulting geometry; verify it passes
- [x] 8.3 Wire the unit tests, the harness suite, and the virtual-machine test into a single command and verify it fails when any tier fails
- [x] 8.4 Confirm the shipped build does not export the test interface when the environment variable is unset, and verify by introspecting the bus in a normal session
- [x] 8.5 Add a GPL-compatible licence and a README covering install, the shortcut, and the GNOME 50 version policy; verify the extension installs by following the README on a clean checkout
