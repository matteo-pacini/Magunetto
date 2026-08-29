## Context

See `proposal.md` — Why. The fault is not that the preview was drawn in the wrong place; it is that
"outlined" was taken to mean "an actor exists at those coordinates", which is exactly what the tests
checked.

The archived `add-landing-preview` design states that layering "needs no work", reasoning that
`global.window_group` sits beneath `Main.uiGroup` so the ring draws above the outline. That much was
true and remains true. What it missed is the *other* end: `TilePreview.open()` also lowers itself
below the window actor, every time it is called. Two layering questions, one of them never asked.

## Goals / Non-Goals

**Goals:**

- The outline is seen wherever the region falls, including over the window being previewed.
- A test that fails on the unfixed tree, in a class the existing preview cases cannot express.
- Regenerated demo assets, since the committed ones record the defect.

**Non-Goals:**

- Styling. Unchanged from `add-landing-preview`: `TilePreview` is reused as the shell draws it, and
  `_updateStyle()` still overwrites `style_class` on every update.
- Any change to what a sector means or where a window lands. `geometry.js` and `snap.js` are
  untouched.
- Rewriting the archived change. Its design is a record of what was decided, and the sentence that
  turned out to be incomplete is part of how this was missed.

## Decisions

### Raise after every `open()`, not once

`open()` ends with `set_child_below_sibling(this, windowActor)` and runs on every selection change,
so a single raise at construction would be undone by the first sector change. The raise has to
follow each `open()` call.

This is the same shape as the `Mtk.Rectangle` trap from the previous change: the first selection
behaves, and the second reveals the problem. A manual test that flicks once will not find either.

*Alternative rejected: subclass `TilePreview` and override `open()`.* It would put the raise where it
belongs rather than at the call site, but overriding a method to undo its last line is a more
fragile coupling than calling one public method after it, and the previous change already decided
against subclassing for styling. Two lines at the call site, with a comment saying why, is the
smaller commitment.

*Alternative rejected: reparent the preview into `Main.uiGroup`.* It would sit above every window
without any raising, but it would then also sit above the radial menu unless ordered against it, and
`TilePreview` parents itself to `global.window_group` in `_init` — so this trades one ordering
problem for two.

### Above every window, not only above the target

The raise puts the preview at the top of `global.window_group`, so it also covers windows other than
the target.

That is the right reading of what it is: the outline is transient chrome that exists for the length
of a gesture, and it answers "where will this go", which is a question about a region of the screen
rather than about one window's stacking. Raising it above only the target would leave it hidden
behind any window stacked above that one — a window the user can see, over a region the outline is
supposed to be describing.

### The regression test asserts stacking order, not geometry

Every existing preview case asserts a rectangle, and all of them passed while the feature was
invisible. A rectangle cannot express what is in front of what.

The new case reads the index of the preview and of the target window's actor within
`global.window_group.get_children()` and asserts the preview is above. That is the actual contract,
it is cheap, and it fails on the unfixed tree.

It deliberately puts the window somewhere the region overlaps — a window on a half, gestured toward
a quarter inside that half — because a case that gestures from a small centred window passes either
way. That is precisely the shape of the two hands-on sessions that missed this.

## Risks / Trade-offs

**The preview covers unrelated windows while a gesture is in flight** → Accepted, and argued for
above. It lasts as long as the modifier is held, and the radial menu is already drawn over
everything for the same reason.

**Reading child indices couples the test to `TilePreview` living in `global.window_group`** → It is
already coupled: `preview-disabled.sh` counts children of that group to prove teardown. Both would
need revisiting if the widget were ever reparented, and both would fail loudly rather than silently,
which is the failure mode this change exists to correct.

**The demo assets have to be regenerated, and the recording is not reproducible byte-for-byte** →
Accepted. `assets/demo.gif` is generated, not hand-made, and its exact frames have never been
reproducible; the encoder finds the travel by scene detection for that reason. The check is that the
clip's duration matches the wall clock its case takes, not that it matches a previous file.

## Migration Plan

None. No settings, no stored state, no schema change. The preference added by the previous change is
untouched, and a user who turned the preview off sees no difference.
