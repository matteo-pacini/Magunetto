## Why

Snapping is instant, and inconsistently so. A window that was maximised or fullscreen already
animates into its new region, because clearing that state is a size change the shell animates on its
own; every other snap jumps. The result is that the same gesture looks different depending on what
the window was doing beforehand, and the common case — an ordinary window moving between regions —
is the one with no motion at all to connect where the window was to where it went.

## What Changes

- The window slides and scales from its previous rectangle into its snapped one, for every sector
  and regardless of what state the window was in.
- The animation the shell runs for itself when a maximised or fullscreen window is cleared is
  suppressed, so a single animation covers the whole move and every snap looks alike.
- Two preferences: a switch to turn the animation off, and a choice of seven easing curves with a
  plain-language description of each.
- Placement itself is unchanged. The same rectangle is computed and applied; only its presentation
  differs.

Not in this change: the duration is fixed at 220ms and is not configurable. A curve and a duration
are not independent — a sharp curve wants a longer duration than a soft one to read the same way —
and exposing both invites combinations that look broken. The curve is the axis worth offering.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `window-snap`: placement gains an animated presentation, and two settings that govern it. The
  geometry requirements are untouched; what is added is that the window is seen to travel to its
  computed rectangle rather than appearing there, and that this can be turned off or restyled.

## Impact

- `magunetto@matteopacini.me/lib/snap.js` — captures the window before moving it, suppresses the
  shell's own animation, hands off to the animation.
- `magunetto@matteopacini.me/lib/animate.js` — new. Freeze, snapshot, counter-transform, ease.
- `magunetto@matteopacini.me/lib/curves.js` — new. The seven curves and their application.
- `magunetto@matteopacini.me/extension.js` — reads the two settings at commit time.
- `magunetto@matteopacini.me/prefs.js` — the switch and the curve picker.
- `magunetto@matteopacini.me/schemas/` — two new keys.
- `magunetto@matteopacini.me/lib/testInterface.js` — an actor-transform surface, without which none
  of this is observable from the harness.
- `tests/harness/cases/` — new cases; `tests/harness/run.sh` gains a third dimension in the session
  profile key so cases can vary the animation settings.

No new dependencies. Everything used is already in the shell: `Meta.WindowActor.freeze`,
`paint_to_content`, `Main.wm.skipNextEffect`, and Clutter's easing.
