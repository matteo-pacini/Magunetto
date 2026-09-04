## Context

See `proposal.md` — Why. Three facts about the code as it stands shape the design.

**One function makes every rectangle.** `rectFor(sector, area)` in `geometry.js` is called twice:
from `extension.js` to open the outline, and from `snap.js` to place the window. It imports nothing
and is unit-tested outside a shell. Whatever it returns is both what is drawn and what is applied.

**It already splits with integers.** Halves are `floor(width / 2)` for the near half and the
remainder for the far half, so adjacent halves meet exactly on odd work areas. Tiling Assistant, the
closest sibling on GNOME, insets each side by `windowGap / 2`, which goes fractional on odd values
and lands on a half-pixel; the shell then rounds and the two windows are no longer the configured
distance apart.

**Preferences are read per gesture, not cached.** The preview flag is read when the menu opens, the
travel style at commit. Nothing is connected to `changed::` signals in the shell process.

## Goals / Non-Goals

**Goals:**

- Two integers, one place in the code that reads them, one function that applies them.
- Zero gaps produce byte-identical rectangles to today's, so the existing 41 harness cases are the
  regression suite for the default.
- Exact integer spacing: two neighbours are the inner gap apart to the pixel, on every size and
  every value.

**Non-Goals:**

- Per-side outer gaps. i3, Tiling Assistant and Loop offer them; this cut offers one value. Adding
  four keys later is additive and nothing here forecloses it.
- Smart gaps, which vanish when a window is alone. A radial snap has no notion of how many windows
  a workspace holds and should not acquire one for this.
- Negative gaps. i3 allows a negative outer to cancel its inner at the edges because its edge gap is
  the sum of the two. Here the edge gets the outer alone, so there is nothing to cancel.
- Gaps on the drawn menu itself, or on the travel. Both are unchanged.

## Decisions

### Inner is the total distance between neighbours; the edge gets the outer alone

Two conventions exist. i3's: inner is space between windows, and the edge gets outer *plus* inner.
Tiling Assistant's: inner is space between windows, and the edge gets the screen gap alone. Pop
Shell insets the whole area by outer and then each tile by inner, which is the i3 sum by another
route.

Tiling Assistant's is chosen. It is the closest sibling — halves and quarters on GNOME, with no
tree — and it is the one a user can reason about without a diagram: the number you set is the
distance you see. The sum convention makes an edge gap of 8 require outer 8 minus inner, which is
how i3 came to allow negative values.

### Take the gaps out of the span, then split

The alternative is to split as now and then inset each half by `inner / 2` on its shared side. That
is what Tiling Assistant does, and on an odd inner gap it puts a seam at a half pixel. Instead:

```
usable  = width - 2 * outer - inner
near    = floor(usable / 2)
far     = usable - near

near.x  = area.x + outer
far.x   = near.x + near + inner
```

The same along the other axis. Every value is an integer, the two halves differ by at most one
pixel, and `far.x - (near.x + near)` is `inner` exactly. With both gaps at zero this is the existing
arithmetic unchanged, which is what lets the existing cases stand as the regression suite.

Quarters are the two axes composed. The centre action is the area inset by `outer` on each side, and
`inner` does not enter.

### `rectFor(sector, area, gaps)` — a third argument, defaulting to none

Two shapes were considered: pass the gaps into `rectFor`, or shrink the area before calling it and
add a separate seam function. The second cannot express the seam: shrinking the area handles the
outer gap, but the inner gap changes where the midpoint is, and that is inside the split.

So `rectFor` takes `{outer, inner}` and defaults it to `{outer: 0, inner: 0}`. Every existing call
and every existing unit test is unchanged. The maths stays in a module that imports nothing.

### Read once per gesture, in `extension.js`, and hand the values down

`_onTrigger` already reads the preview flag and decides the monitor for the whole gesture. The gaps
join it: read there, held on the instance, passed to `rectFor` in `_onSelect` and to `snap()` at
commit. Reading them at both points instead would let a change between selection and release make
the outline and the landing disagree, which is the one thing the design exists to prevent.

`snap()` gains a fifth argument rather than taking a rectangle: it already records the sector, and
computing the rectangle from the monitor it is given is its stated contract.

### Two `Adw.SpinRow`s, bound with `Gio.SettingsBindFlags.DEFAULT`

The two switch rows in the Snapping group are bound the same way, so the rows follow the pattern
beside them. A spin row needs an upper bound; the schema `<range>` supplies 0 to 100, and the row's
adjustment repeats it, since GTK cannot read a schema range. 100 is what Loop's slider stops at, and
it is already a quarter of a 1280-wide half. Nobody else caps: Pop Shell is a free text entry,
Tiling Assistant and i3 have no bound. A bound is needed here for the widget, not for the maths.

Placed after Style: the group reads preview, travel, style, then where the region sits. A snap-time
setting rather than a display one, but a third group of two rows would say less than it costs.

### The keys are `snap-outer-gap` and `snap-inner-gap`, type `i`

The existing keys are `snap-` prefixed. `i` with a range rather than `u`: the range is what the
schema enforces, and `get_int` is what the preferences code beside it reads most naturally.

### Harness: session knobs, not mid-session writes

Two ways to set the gaps for a case: write them into the session keyfile as `CASE_OUTER_GAP` and
`CASE_INNER_GAP`, like `CASE_PREVIEW`; or set them on the extension's settings object mid-session,
like `_curves.sh` does for the travel style.

Knobs are chosen. A mid-session write has to be undone at the end of the case, and a case that
fails an assertion halfway does not reach its own teardown, so the next case in the shared session
inherits gaps it did not ask for and fails for a reason that is not in its file. Knobs cost one more
shell boot for the whole gap group, since every gap case uses the same pair of values and so shares
one session.

The one scenario the knobs cannot prove — a change applies to the next gesture — is proven the way
`_curves.sh` proves it for the style: set the key through the settings object inside a gap-profile
session, gesture, and set it back. That case is the exception and says so.

The profile grep in `run.sh` that groups cases by session omits `PREVIEW` today, so `preview-off`
already sorts among default cases and costs a boot each way. Adding the two new names to that
pattern, and `PREVIEW` with them, is in scope: the grouping is the mechanism this design relies on.

### Two windows, one target at a time

The seam scenarios need two windows. The hook reports `TargetFrame` for the extension's target,
which is the focused window at the moment the gesture began, so a case snaps the first window,
reads its frame, opens the second — `open_test_window` activates it — snaps that, and reads again.
No hook change is needed.

## Risks / Trade-offs

**A minimum-size window cannot take a gapped region** → Same as today without gaps, and already
covered: it moves to the region's origin and keeps its minimum size. The origin now includes the
outer gap, which `min-size.sh` does not assert and the new cases do not need to; the behaviour is
unchanged in kind.

**A large gap on a small monitor leaves a tiny region** → Accepted. The range stops at 100 per key,
so a quarter on a 1280×800 work area is at worst 490×300. The maths never produces a negative size
below that; the unit tier asserts it at the bound.

**Eight strings block the unit tier until thirteen catalogues are filled** → Not mitigated, by
design, as with the preview. `tests/l10n.test.js` goes red when the strings land and stays red until
`po/update.sh` has run and every catalogue is complete. The task order puts translation before the
final run.

**"Gap" has an established rendering in some GNOME catalogues and not in others** → Mitigated by
the translator brief: point at how GNOME's own shell and Tiling Assistant render it where they do,
and at the row's role where they do not. The two titles must be distinct from each other in every
language, which the unit tier can assert as it does for the seven style names.

**The spec's "adjacent halves abut" scenario changes meaning** → The scenario keeps its name and
gains the gap; with the gap at zero it says what it always said. The existing `gesture.sh`-family
cases stay as its zero-gap proof and one new case is its non-zero proof.

## Migration Plan

None beyond two new keys with defaults. An existing installation upgrades with both at 0 and sees
no change. Rollback is reverting the commit; the two unused keys in dconf are harmless.
