## 1. Observability first

The animation changes neither the final geometry nor the state log, so nothing in the existing suite
can see it. This group comes first because without it every later task is unverifiable.

- [x] 1.1 Add an `ActorTransform` method to `lib/testInterface.js` returning the target window
      actor's `translation_x`, `translation_y`, `scale_x`, `scale_y`, and verify it reports
      `0,0,1,1` for a window that is not moving
- [x] 1.2 Add a `Ghosts` property reporting how many snapshot widgets are parented, and verify it
      reports 0 in an idle session
- [x] 1.3 Add `mg_xform` and `mg_ghosts` helpers to `tests/harness/lib.sh`, and verify they parse
      the D-Bus replies by calling them from an existing case
- [x] 1.4 Extend `run.sh`'s session profile key with the animation settings so cases can vary them,
      and verify by running two cases with different settings that each gets the settings it asked
      for

## 2. The curves

- [x] 2.1 Add `lib/curves.js` with the seven curves, each carrying its translation mode, scale mode
      and optional Bézier control points, and verify `node --test tests/*.test.js` passes with a new
      unit test asserting all seven resolve and that an unknown name falls back to the default
- [x] 2.2 Implement `easeWith()` applying Bézier control points through
      `set_cubic_bezier_progress()` after `ease()` has created the transitions, and verify a snap
      under the `Settle` curve raises no exception in the harness

## 3. The animation

- [x] 3.1 Add `lib/animate.js` with `capture()`: snapshot via `paint_to_content()`, freeze the
      actor, and verify a captured window stops updating until thawed
- [x] 3.2 Implement the release path — disconnect, thaw exactly once, reachable from the animation
      starting, the actor being destroyed, and a 250ms timeout — and verify with a harness case that
      a repeat snap to the same region leaves the window still movable by a subsequent snap
- [x] 3.3 Implement the trigger split: start immediately when the requested size is already current,
      otherwise wait for a `size-changed` whose size differs from the old rectangle. Verify with
      harness cases that both a pure move and a resize produce a non-identity transform
- [x] 3.4 Implement the transform and crossfade, easing translation and scale separately so the two
      can carry different curves, and verify the transform returns to `0,0,1,1` and `Ghosts` returns
      to 0 after every case

## 4. Wiring

- [x] 4.1 Add `snap-animation` (boolean, default true) and `snap-animation-curve` (string, default
      `quint`) to the GSettings schema, and verify `glib-compile-schemas` succeeds and a fresh
      session reports both defaults
- [x] 4.2 Call `Main.wm.skipNextEffect(actor)` in `snap.js` immediately before `unmaximize()` /
      `unmake_fullscreen()`, and verify a maximised snap leaves no `__animationInfo` on the actor
- [x] 4.3 Skip the animation in `snap.js` when the target rectangle is the one the window already
      occupies, and verify the repeat-snap case reports an unchanged frame and a clean transform
- [x] 4.4 Read both settings in `extension.js` at commit time and pass them through, and verify
      changing the curve mid-session affects the next snap without a reload

## 5. Preferences

- [x] 5.1 Add an `Adw.SwitchRow` for the animation to `prefs.js`, and verify toggling it writes
      `snap-animation`
- [x] 5.2 Add an `Adw.ComboRow` listing the seven styles in spectrum order — Instant, Snappy,
      Settle, Soft, Standard, Spring, Overshoot — and verify selecting one writes the matching key
- [x] 5.3 Update the combo row's subtitle to the selected style's description on every change, and
      verify each of the seven shows its own description, including that `Overshoot` states it
      exceeds the region

## 6. Behaviour under test

One case per scenario in `specs/window-snap/spec.md` that this change adds.

- [x] 6.1 Add `animate-move.sh` and `animate-resize.sh` covering same-size and different-size snaps,
      asserting a non-identity transform mid-flight and identity after
- [x] 6.2 Add cases for maximised and fullscreen sources, asserting both animate and that neither
      leaves the shell's own animation running
- [x] 6.3 Add `animate-off.sh` asserting the transform never leaves identity when `snap-animation`
      is false
- [x] 6.4 Add `animate-interrupt.sh` snapping twice in quick succession, asserting the window lands
      on the second region with a clean transform and no leftover snapshot
- [x] 6.5 Add `animate-closed.sh` closing the window mid-animation, asserting no exception and no
      leftover snapshot
- [x] 6.6 Add `animate-desktop-off.sh` setting `enable-animations` false, asserting placement is
      immediate and lands exactly on the region
- [x] 6.7 Add a case for a window whose minimum size exceeds its target, asserting the travel still
      completes and the transform settles

## 7. Finishing

- [x] 7.1 Run `tests/run-all.sh` and confirm every tier passes, including the pre-existing 21 cases
- [x] 7.2 Re-record `assets/demo.gif` via `tests/harness/run.sh _demo` now that the motion is worth
      showing, and verify the new file is committed
- [x] 7.3 Document the settings in `README.md` under Changing the shortcut, including the Home
      Manager dconf keys, and verify the example matches the shipped schema
- [x] 7.4 Add to the Traps section of `AGENTS.md`: a move is reported synchronously from
      `move_frame()` while a resize is only reported after the client acks, and an unpaired
      `freeze()` stops a window updating permanently
- [x] 7.5 Add to the Traps section of `AGENTS.md`: with the extension already installed, the outer
      compositor swallows its own bindings before they reach a nested `watch.sh` session, so the
      nested session needs a different shortcut
