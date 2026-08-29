## Context

See `proposal.md` — Why. Three facts about the ground shape everything below, and all three were
read out of the shell's own sources rather than assumed.

**`TilePreview` is exported.** `ui/windowManager.js` declares it `export const`, not an underscore
private, and the shell drives it from `_showTilePreview` for edge tiling. It is an `St.Widget` that
parents itself into `global.window_group`, eases `x`/`y`/`width`/`height`/`opacity` towards a target
rectangle, no-ops when handed the rectangle it already holds, and fades out on `close()`.

**It grows out of the window.** On first show, and again whenever the monitor changes, it positions
itself at the target window's own frame rect intersected with the monitor, at zero opacity, and
eases from there. Loop — the macOS window manager this extension takes its gesture from — makes the
same decision a three-way user preference (`screenCenter`, `radialMenu`, `actionCenter`). The
shell's answer is better and is free: an outline that grows out of the window reads as *that window
is going there*.

**Layering needs no work.** `global.window_group` sits beneath `Main.uiGroup`, and the menu is added
with `addTopChrome`. So the ring draws above the outline, and the outline draws beneath the window
actor, without either being told about the other.

## Goals / Non-Goals

**Goals:**

- Show the region before the user commits to it, using the component the shell already ships, so it
  looks like the preview GNOME shows when a window is dragged to a screen edge.
- Add the preview without giving `radialMenu.js` any dependency it does not already have.
- One preference, off-switch only.

**Non-Goals:**

- Any styling of our own. See the decision below; this is the deliberate limit on the change.
- Any control over padding, corner radius, border thickness, opacity or blur. Loop offers all five;
  offering none is what keeps this to one preference rather than six, and thirteen catalogues rather
  than a dialog redesign.
- Changing what a sector means. `geometry.js` is untouched.

## Decisions

### Reuse `TilePreview` unmodified rather than subclassing or writing our own

Three options were considered: reuse as-is, subclass and override `_updateStyle()`, and write a
bespoke widget.

Reuse is about ten lines. It is also the only one of the three that cannot be restyled: `open()`
calls `_updateStyle()` on every update, so any `style_class` set from outside is overwritten on the
next sector change. And the shell's style vocabulary is incomplete for this extension —

```js
const styles = ['tile-preview'];
if (this._rect.x === monitor.x)                                    styles.push('tile-preview-left');
if (this._rect.x + this._rect.width === monitor.x + monitor.width) styles.push('tile-preview-right');
```

— left and right only, because GNOME's edge tiling has no quarters and no top or bottom halves. A
top-left quarter is therefore drawn with a left edge's corner treatment.

Accepted, and it is the decision the change is scoped around. Looking like the shell is the point of
reusing the shell's widget; corner radii are not what a preview is for; and a subclass would trade a
visible cosmetic detail for an override of a private method, which is the more fragile dependency of
the two. If the corners come to matter, subclassing is the next step and nothing here forecloses it.

### One instance, constructed lazily, destroyed in `disable()`

`close()` fades and hides; it does not destroy, and the widget stays parented to
`global.window_group`. Constructing one per gesture would leave a hidden actor behind for every
gesture of the session. The shell's own pattern is lazy-construct-and-reuse
(`if (!this._tilePreview) this._tilePreview = new TilePreview()`), and this follows it.

`disable()` destroys it, for the same reason it already calls `cancelAll()`: everything created
while enabled has to be reachable from teardown, and a widget in the shell's own group is exactly
the kind of thing the review guidelines are about.

### The preview lives in `extension.js`, and the menu reports selection upward

`TilePreview.open()` needs the target window. `radialMenu.js` does not have one, and giving it one
means either passing the window in or importing `snap.js` for the work area — and `snap.js` pulls in
`animate.js` and Meta, into a module that today imports nothing but `geometry.js`.

So the menu gains an `onSelect(sector)` callback beside the `onFinish` it already has, invoked at
the line where it already notices the selection changed. `extension.js` owns the preview, and it is
the only place that already holds all three things the preview needs: the target window, the
gesture's monitor, and the settings object.

### `rectFor()` keeps returning plain objects; `extension.js` builds the `Mtk.Rectangle`

`TilePreview.open()` calls `this._rect.equal(tileRect)` and reads `.x`/`.y`/`.width`/`.height`, so
it wants an `Mtk.Rectangle`. `rectFor()` returns a plain object, deliberately, so that the geometry
maths can be unit-tested outside a running shell.

The conversion belongs at the call site in `extension.js`, which is already the boundary between the
toolkit and the maths — `snap.js` does the same thing in the other direction in `workAreaFor()`.

Worth knowing while implementing: a missing conversion does not fail on the first selection, because
`_rect` is `null` then and the `equal()` guard is skipped. It fails on the *second*, with
`TypeError: this._rect.equal is not a function`. A quick manual test that flicks once and releases
will not find it.

### The dead zone closes the preview, and `rectFor()` already says so

`rectFor(NONE, area)` returns `null`. That is exactly the condition under which the preview should
be closed, so the mapping needs no separate rule: a rectangle opens it, `null` closes it.

### The preference governs whether, not how

The shell replaces `actor.ease()` with a zero-duration version when desktop animations are off, so
with them off the outline appears at its region instead of sliding to it. That is the right
behaviour and comes for free — the preview's job is to say where the window will go, and that
information should not depend on whether the desktop animates.

This is a deliberate asymmetry with `snap-animation`, where desktop animations being off suppresses
the feature entirely. The difference is that a travel *is* motion, so with motion removed there is
nothing left; a preview is a rectangle that happens to arrive with motion.

The preference is read when the menu opens rather than cached at `enable()`, matching how the travel
style is read at commit time, so a change applies to the next gesture without a reload.

### `PreviewRect` on the test hook

The preview changes neither the state log nor any window's geometry, which is the same problem the
travel had. It is solved the same way: a method on the injected hook that reports what is otherwise
only visible on screen.

It reports the widget's live allocation, not a stored target, so it is honest about what is drawn —
which means a case that samples it immediately after a flick sees a rectangle still easing towards
its region. Cases must settle first, exactly as the travel cases do. Reporting the target instead
would make the cases simpler and the assertion weaker: it would pass even if the widget never
moved.

## Risks / Trade-offs

**A quarter is drawn with an edge's corner treatment** → Accepted, and the reason the change is
scoped this way. Named here so it is a known limitation rather than a bug report. Subclassing
`TilePreview` and overriding `_updateStyle()` is the remedy if it matters later.

**Reusing a shell-internal class ties this to a GNOME version** → Mitigated by how this repository is
organised: one GNOME major per branch, no version guards, and a port starts at the version's porting
guide. `TilePreview` is exported rather than private, which is the weaker form of the risk. A port
to 51 has to check it, and so does every other shell import already here.

**A hidden widget left in `global.window_group`** → Mitigated by the single-instance decision and by
`disable()` destroying it. A harness case disables the extension mid-gesture and asserts nothing is
left, mirroring `animate-disabled.sh`, which is the case that found the equivalent problem for the
travel.

**Four strings block the unit tier until thirteen catalogues are filled** → Not mitigated, by
design. `tests/l10n.test.js` re-extracts the template and compares, so it goes red the moment the
strings land and stays red until `po/update.sh` has run and every catalogue is complete. That is
what stops a string reaching users untranslated, and it is the same discipline that shipped the
catalogues in the first place. The task order puts translation before the final test run.

**The preview and the travel both answer "where does it land"** → Accepted as complementary rather
than redundant. The preview answers before the decision, the travel after it. Someone will
reasonably ask whether both are wanted, which is what the two preferences are for: either can be
turned off without the other.

## Migration Plan

None required beyond the new key, which has a default. An existing installation gains the preview on
upgrade without any settings change; turning it off is one switch. Rollback is reverting the commit,
and the unused key in a user's dconf is harmless.
