## Why

The gesture asks the user to commit before showing them anything. The menu says which sector is
selected, but a sector is an abstraction — "bottom-right" is not the same thing as seeing the
rectangle it means on the screen in front of you. Where a region ends up depends on the work area,
which depends on panels and docks and, since 0.4.2, on which monitor the gesture was made on. The
only way to find out today is to release and look.

The shell already draws exactly this for its own edge tiling, and exports the component that does
it: `TilePreview` in `ui/windowManager.js`. Nothing here has to be invented — the target rectangle
is already computed by `rectFor()`, the monitor is already decided by the gesture, and the moment
the selection changes is already a single line in `radialMenu.js`.

## What Changes

- While the menu is up, the region the window would land in is outlined on screen. The outline
  follows the selection, and is absent while the pointer is in the dead zone, where releasing would
  do nothing.
- The outline grows out of the target window on first appearance rather than appearing from
  nowhere, which is what makes it read as *this window is going there* rather than as a rectangle
  that happened.
- The shell's own `TilePreview` is reused unmodified. It is drawn in the shell's theme, so the
  preview looks like the one GNOME already shows when a window is dragged to a screen edge.
- **No styling of our own.** `TilePreview._updateStyle()` recomputes its style class on every
  update, so a reused instance cannot be restyled, and its vocabulary only distinguishes the left
  and right edges — GNOME's edge tiling has no quarters. A quarter therefore gets an edge's corner
  treatment. Accepted: looking like the shell is the point, and corner radii are not what the
  preview is for.
- A new preference, `snap-preview`, turns it off. Default on.
- The preference is honoured for the next gesture, read when the menu opens, in the same way the
  travel style is read at commit time rather than cached.
- Turning the preview off is **not** the same as turning desktop animations off. With desktop
  animations disabled the shell gives `ease()` a zero duration, so the outline appears at its region
  rather than sliding to it — the information stays, only the motion goes. `snap-animation` is the
  opposite case, where the motion is the whole feature.
- The four strings this adds — a schema summary and description, a preferences row title and
  subtitle — are translated into all thirteen shipped languages: `en_US`, `de`, `pt_BR`, `es`,
  `fr`, `ru`, `it`, `pl`, `nl`, `uk`, `ja`, `tr`, `zh_CN`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `radial-menu`: one added requirement, that the region a gesture would place the window in is shown
  while the menu is up.

`localisation` is deliberately **not** modified. Its requirements are written against "every string
the preferences dialog can display" and "every string in the template" rather than against any
count, so four new strings are already inside the existing contract. The work is real; the contract
does not change. `window-snap` is not modified either: what a sector means geometrically is
unchanged, and the preview only displays it.

## Impact

**Code**

- `magunetto@matteopacini.me/extension.js` — owns one lazily-constructed `TilePreview`, opens and
  closes it as the selection changes, and destroys it in `disable()`. It is the only place that
  already holds all three things the preview needs: the target window, the gesture's monitor, and
  the settings object.
- `magunetto@matteopacini.me/lib/radialMenu.js` — one `onSelect(sector)` callback, invoked where the
  menu already notices the selection changed. The preview is not built here: `TilePreview.open()`
  needs the target window, and reaching it would drag `snap.js`, and through it `animate.js` and
  Meta, into a module that today imports nothing but `geometry.js`.
- `magunetto@matteopacini.me/lib/geometry.js` — **unchanged**. `rectFor()` already returns the
  rectangle, and returns `null` for the dead zone, which is exactly when the preview should be
  closed.
- `magunetto@matteopacini.me/schemas/*.gschema.xml` — the `snap-preview` key.
- `magunetto@matteopacini.me/prefs.js` — one row, in the existing Snapping group, above Animate so
  the group reads in the order the user meets the features: preview, then travel, then style.

**Tests**

- `tests/harness/shellhook.js` — a `PreviewRect` method. The preview is invisible to the state log
  and to window geometry, which is the same problem the travel had and is solved the same way.
- New harness cases: the preview takes the sector's rectangle, is absent in the dead zone, is gone
  after a commit and after a cancel, survives desktop animations being off, and is left behind by
  neither `disable()` mid-gesture nor the preference being off.
- `tests/l10n.test.js` — no new tests. It re-extracts the template and compares, so it fails on the
  new strings until `po/update.sh` has run and all thirteen catalogues are complete. That is the
  test doing its job, not a change to it.

**Translation**

- `po/magunetto.pot` grows from 29 messages to 33, and thirteen `.po` files gain four entries each.
