## Why

The preview is drawn behind the window it is previewing, so it is invisible whenever the region it
outlines overlaps where the window already sits. That is most of the time: a window on the right
half being sent to the bottom-right quarter, a maximised window being sent anywhere, a window being
sent to the region it is already in but a little smaller. The generated tour in `assets/demo.gif`
shows it plainly — the first gesture works, because the window is small and centred, and the
remaining eight show a highlighted sector with no outline anywhere on screen.

The cause is one line inside the shell's own `TilePreview.open()`:

```js
global.window_group.set_child_below_sibling(this, windowActor);
```

That is correct for what the shell uses it for. Edge tiling shows a preview while the window is
being **dragged**, so the window is under the pointer somewhere else and the preview belongs behind
it. This extension's gesture never moves the window until the modifier is released, so the window
stays exactly where the outline needs to be seen.

Nothing caught it. Forty harness cases passed, because `PreviewRect` reports the widget's
allocation and the allocation was always correct — occlusion is not expressible as a rectangle. Two
hands-on sessions passed too, because `watch.sh` opens one small centred window, which is precisely
the case that happens to work.

## What Changes

- The outline is drawn above the target window, so a region overlapping the window is still seen.
- **The requirement is tightened.** `The region a gesture would place the window in is shown` said
  the region "is outlined", which an implementation can satisfy while drawing it where nobody can
  see it. It now says the outline is drawn above the target window, and carries a scenario for the
  overlapping case that was silently broken.
- A harness case asserts the preview's position in the stacking order relative to the target
  window's actor. This is the assertion class that was missing: every existing preview case asserts
  a rectangle, and a rectangle cannot express what is in front of what.
- `assets/demo.gif` and `assets/demo.mp4` are regenerated, because the committed pair currently
  record the defect.

## Capabilities

### Modified Capabilities

- `radial-menu`: `The region a gesture would place the window in is shown` gains the requirement
  that the outline is drawn above the target window, and a scenario covering a region that overlaps
  the window's current position.

`window-snap` is unchanged: what a sector means geometrically, and where the window ends up, were
never affected — only whether the user could see the offer before accepting it.

## Impact

**Code**

- `magunetto@matteopacini.me/extension.js` — raises the preview after each `open()`. It has to be
  after each one rather than once at construction, because `open()` lowers it again every time.

**Tests**

- `tests/harness/cases/preview-occlusion.sh` — new. Snaps a window to a half, then gestures toward a
  region inside that half, and asserts the preview sits above the window's actor in
  `global.window_group`. Fails on the unfixed tree.

**Assets**

- `assets/demo.gif`, `assets/demo.mp4` — regenerated from a recording that shows the preview
  working. `tests/harness/cases/_demo.sh` already carries a longer dwell after the sweep so the
  outline is seen at rest rather than still arriving.

**Not changed**

- The archived `add-landing-preview` change keeps its `design.md`, including its claim that layering
  "needs no work". An archived change records what was decided at the time; the living contract is
  `openspec/specs/`, and that is what this change corrects.
