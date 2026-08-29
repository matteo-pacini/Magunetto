## Context

See `proposal.md` — Why. The relevant constraints came out of reading mutter and the shell's own
bundled JS rather than documentation, because three of them contradict what the code appears to
assume.

**A modal grab receives motion for the whole stage.** `clutter_actor_collect_event_actors`
(`clutter/clutter/clutter-actor.c`) collapses the emission chain to the grab actor alone whenever the
picked actor falls outside it — the comment there reads *"The grab root conceptually extends
infinitely in all directions"*. The shell relies on this: `ui/dnd.js` grabs a **0×0** actor and
receives every motion event of a whole-desktop drag. So the menu widget's one-monitor allocation
constrains what is drawn, not what is delivered, and `event.get_coords()` is already in stage
coordinates that span every monitor.

**Mutter reassigns a window's monitor from its frame rect, on every move.**
`meta_window_move_resize_internal` calls `meta_window_update_monitor` at the end of every move or
resize; the Wayland implementation picks by the centre of the frame rect, falling back to largest
overlap. No explicit call is needed to make a window change monitors — moving it there is enough.

**The pointer is unconstrained at a seam.** Motion between abutting monitors passes straight through;
only the outer edge of the union pins it. The harness demonstrates both halves: `edge.sh` flicks
+300 from x=1279 on a single monitor and the pointer pins, whereas the same flick with a second
monitor attached crosses onto it.

## Goals / Non-Goals

**Goals:**

- One decision — *which monitor is this gesture on* — made once, from one pointer read, and used by
  both the menu and the snap.
- No observable change on a single-monitor desktop, and none when the pointer and the window agree.
- A regression guard against re-deciding the monitor later in the gesture, since that mistake would
  pass every other test.

**Non-Goals:**

- Sector directions that mean "toward the next monitor" (see Decisions).
- Multi-monitor coverage at the VM tier (see Decisions).
- Any change to how a sector maps to a rectangle. `geometry.js` takes a work area as a parameter and
  has never known whose it is; it is untouched.
- Following the pointer *between* monitors mid-gesture, which the latching decision rules out
  deliberately.

## Decisions

### Latch the monitor at open time, not at release

The gesture's monitor is resolved once, in `_onTrigger`, and held for the gesture.

*Alternative rejected: resolve at release.* It reads as the more responsive design and is a trap.
Because the pointer crosses a seam freely, a 300-pixel rightward flick begun anywhere within 300
pixels of the boundary would land the pointer on the next monitor and send the window there — on a
gesture the user made entirely to snap it to the right half of the screen they were already on. The
failure is layout-dependent and intermittent, which is the worst kind.

Latching also makes the monitor consistent with the gesture origin, which `radialMenu.open()` already
latches and never re-reads. Both become one decision taken at one instant.

### Resolve the pointer to a monitor with `findMonitorForPoint`, not `get_current_monitor`

`global.display.get_current_monitor()` is the obvious API and the shell uses it in two places. It
performs its own pointer read inside C, independent of the `global.get_pointer()` call that produces
the origin, so in principle the two can disagree if the pointer moves between them.
`Main.layoutManager.findMonitorForPoint(x, y)` takes the coordinates we already have, so one pointer
read drives both the monitor and the origin and they cannot diverge.

It also fails more usefully. In a gap between non-abutting monitors `get_current_monitor()` returns
**0** — mutter's own comment is *"Pretend its the first when there is no actual current monitor"* —
which is an arbitrary monitor the user may not be near. `findMonitorForPoint` returns `null`, letting
the fallback be the target window's monitor: the behaviour that shipped before this change.

### Pass the monitor index into `snap()` rather than let it re-read `get_monitor()`

`snap()` could rely on mutter having reassigned the window's monitor. It should not, for two reasons.

The reassignment can be **declined**. `meta_window_wayland_update_main_monitor` applies hysteresis
when the old and new monitors have different scales and stage views are not scaled: it rescales the
frame rect and refuses the switch if the rescaled rect would land elsewhere, to stop a window
alternating between monitors as scaling changes. On a mixed-DPI desktop a window can therefore be
visually on the new monitor while still reporting the old one. A caller holding the index it chose is
immune; a caller re-reading is not.

Second, ordering. `snap()` computes the rectangle *before* it moves the window, so at that moment the
window is still on its old monitor whatever mutter would do afterwards. Reading `get_monitor()` there
is simply asking the wrong question.

This is why `workAreaFor` changes signature from taking a window to taking a monitor index.

### Do not use `Meta.Window.move_to_monitor()`

It exists and the shell uses it for the "Move to Monitor Left/Right" window-menu items, so it looks
like the intended API. It is the wrong one here: it *"[moves] the window to the monitor with index
@monitor, keeping the relative position of the window's top left corner"* — a relative reposition
against the new work area. `snap()` has already computed an absolute rectangle. Calling both would
mean one move fighting the other, and the shell's own use of it (`ui/main.js`) has to wait on a
`window-entered-monitor` signal to sequence what follows, which a plain `move_resize_frame` does not
require.

### Sector directions stay relative to the gesture's monitor

Pointer on the second monitor, window on the first, gesture **left**: the window takes the *left half
of the second monitor*.

*Alternative rejected: direction means "travel toward that monitor".* It has an intuitive appeal and
it does not survive contact with a real desktop. The eight sectors would mean different things
depending on physical layout — "left" would be a monitor jump on a horizontal arrangement and a
half-screen snap on a vertical one — and there is no answer at all for the four corner sectors, or
for the direction pointing away from every other monitor. The menu is drawn on the gesture's monitor
and its sectors are that monitor's regions; what is shown is what is applied.

### Cover this at the harness tier only

Multi-head in the VM tier has no NixOS option — `max_outputs` appears nowhere under `nixos/` in
nixpkgs, and `virtualisation.resolution` is a single `{x, y}`. The only route is raw qemu flags
through `virtualisation.qemu.options` with no precedent in `nixos/tests`, and the test driver's
`screendump` takes no head argument, so a failure on the second monitor could not be photographed.
Against a 15-minute tier whose purpose is that an installed tree loads and binds, that is a poor
trade. The harness already takes `--virtual-monitor` twice and boots in 85 seconds.

If a multi-monitor question ever proves installed-tree-specific rather than behavioural, the pattern
to copy is `tests/locale-check.js`: a `writeShellScriptBin` baked at Nix eval time, put on PATH, run
through `su alice`, pass/fail by exit status.

### The three harness cases share one session

All three declare `CASE_MONITORS="1280x800,1280x800"` and no other overrides, so `run.sh` reuses one
shell across them rather than booting three. Their assertions read a work area by explicit monitor
index rather than through the `work_area_field` helper: `shellhook.js` derives `WorkArea()` from the
target window's monitor, so it reports the old monitor before the fix and the new one after, and an
assertion built on it would hold in both worlds.

## Risks / Trade-offs

**A cross-monitor snap toward the primary monitor can change a window's workspace** → Accepted, not
mitigated. `snap()` moves as a user operation, and with `workspaces-only-on-primary` (on by default
in GNOME) mutter pulls a window onto the active workspace when a user move lands it on the primary.
Windows on secondary monitors are sticky across workspaces and one on the primary cannot be, so
something has to give. This is mutter's behaviour for *any* user-initiated move, including dragging
by the titlebar; diverging from it would be the surprise. Recorded here so it is not rediscovered as
a bug.

**A window on a mixed-scale desktop may report the monitor it is no longer on** → Mitigated for this
change by passing the index rather than re-reading it, so the snap is correct regardless. What
remains is that `window.get_monitor()` may disagree with where the window appears — a mutter
behaviour this change neither causes nor can fix. Nothing in the extension reads it after the move.

**The pointer may cross a seam between `_onTrigger` and `RadialMenu.open()`** → Accepted. The two
read the pointer a fraction apart, so the origin can belong to a monitor the gesture did not latch.
The existing clamp then pulls the origin to the latched monitor's edge, which is exactly what the
clamp is for and leaves every sector reachable. It is a correctness-preserving degradation, not a
bug, and closing it would mean threading the origin down from `_onTrigger` for no observable gain.

**A future refactor could re-read the pointer's monitor at release** → Mitigated by
`cross-monitor-latch.sh`. Without it the mistake passes every other case in the suite, including the
new cross-monitor one, and only shows up on a user's desktop as windows occasionally landing on the
wrong screen.

**Two monitors of different sizes are not covered by the new cases** → Accepted. The existing
`window-snap` requirement already covers proportional geometry across differing sizes, and the
sector maths is unit-tested independently of any monitor. Adding a third session profile to the
harness would cost a shell boot to re-test arithmetic that has no monitor in it.

## Migration Plan

None required. No settings, no stored state, and no schema change. On a single-monitor desktop the
pointer is always on the target window's monitor, so the resolved monitor is identical to today's and
the behaviour is unchanged. Rollback is reverting the commit.
