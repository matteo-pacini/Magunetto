## Why

A snapped window today fills its region to the pixel: two halves meet with no space between them,
and every region runs to the edge of the work area. That is what GNOME's own edge tiling does, and
it is the wrong look for anyone who runs a gapped desktop — i3, Sway, Hyprland, Pop Shell, Tiling
Assistant and Loop all offer space between windows and around them. Nothing about the gesture
changes; only what a region means on screen.

`rectFor()` in `geometry.js` is the one place that turns a sector into a rectangle, and both the
preview and the snap already go through it. Insetting there changes the outline and the landing
together, so the two cannot disagree.

## What Changes

- Two new integer preferences, both in logical pixels, both 0 by default:
  - `snap-outer-gap` — the space between a region and the edge of the work area, on all four sides.
  - `snap-inner-gap` — the total space between two adjacent regions: two halves snapped side by
    side are exactly this far apart.
- Every region is inset accordingly: halves and quarters get the outer gap on the sides that touch
  the work area edge and share the inner gap on the sides that touch each other. The centre action
  fills the work area inset by the outer gap alone.
- The outline shown while the menu is up takes the inset rectangle, because it is the same
  rectangle.
- Both values are read when a gesture begins, so a change applies to the next gesture without
  reloading the extension, as the travel style and the preview already do.
- The six strings this adds — two row titles that double as the schema summaries, two row
  subtitles, and two schema descriptions — are translated into all thirteen shipped languages: `en_US`, `de`,
  `pt_BR`, `es`, `fr`, `ru`, `it`, `pl`, `nl`, `uk`, `ja`, `tr`, `zh_CN`.
- With both values at their default of 0, every rectangle is identical to today's. No existing
  behaviour changes for an existing installation.

Deliberately left out: per-side outer values, and "smart gaps" that vanish when a window is alone.
Both are what the tiling window managers offer and both are extra keys and strings for a first cut
that nobody has asked for.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `window-snap`: the requirement that sectors map to halves, quarters and the whole work area is
  restated so that adjacent halves are separated by the inner gap rather than abutting, and a new
  requirement introduces the two gaps, their defaults, and their effect on each kind of region.

`radial-menu` is **not** modified. Its preview requirement already says the outlined region matches
the geometry the window would be given, and it will, because both come from one function.
`localisation` is not modified either: its requirements are written against every displayed string
and every template string rather than against a count, so six new strings are already inside the
contract.

## Impact

**Code**

- `magunetto@matteopacini.me/lib/geometry.js` — `rectFor()` gains a gaps argument. All the maths
  lives here, and it stays importing nothing so the unit tier can prove it.
- `magunetto@matteopacini.me/extension.js` — reads the two keys when the gesture begins, holds them
  for the gesture, and hands them to the preview and the snap.
- `magunetto@matteopacini.me/lib/snap.js` — `snap()` passes the gaps through to `rectFor()`.
- `magunetto@matteopacini.me/schemas/*.gschema.xml` — the two keys, ranged 0 to 100.
- `magunetto@matteopacini.me/prefs.js` — two spin rows in the existing Snapping group.

**Tests**

- `tests/geometry.test.js` — the gap arithmetic: edges, seams, quarters, odd sizes, odd gaps, and
  that zero gaps reproduce today's rectangles exactly.
- `tests/harness/run.sh` — two session knobs, `CASE_OUTER_GAP` and `CASE_INNER_GAP`, written into
  the session keyfile beside the existing ones.
- New harness cases: two windows snapped to opposite halves are the inner gap apart and the outer
  gap from the edges; a quarter; the centre action; the outline carries the gaps; a gesture on a
  secondary monitor; and a repeat is stable with gaps set.
- `tests/l10n.test.js` — no new tests. It re-extracts and compares, so it fails on the new strings
  until `po/update.sh` has run and all thirteen catalogues are complete.

**Translation**

- `po/magunetto.pot` grows from 33 messages to 39, and thirteen `.po` files gain six entries each.
- `po/TRANSLATING.md` gains the six strings, their placement, and their budgets.

**Documentation**

- `README.md` — the Snapping section and the Home Manager example.
- `AGENTS.md` — the map entry for `prefs.js`, and the harness case count.
