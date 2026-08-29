## Why

The gesture never asks where the pointer is. `extension.js` builds the menu with
`monitorIndex: target.get_monitor()` and `snap.js` computes geometry from `window.get_monitor()` —
two independent lookups, both answered by the window. The pointer is read once, for the gesture
origin, and is then clamped into the window's monitor:

```js
const [pointerX, pointerY] = global.get_pointer();
this._origin = {
    x: clamp(pointerX, mx + margin, mx + width - margin),   // mx, width: the window's monitor
    y: clamp(pointerY, my + margin, my + height - margin),
};
```

So with the focused window on one monitor and the pointer on another, the menu is drawn on the
window's monitor, jammed against the edge nearest the pointer, and there is no gesture that can move
a window between monitors.

That clamp is not a bug in itself. It exists because *"the pointer cannot travel past a screen edge,
so a gesture starting there would leave the far sectors unreachable"* — true at an outer edge, and
false at the seam between two monitors, where the pointer travels straight through. It is being
applied against the wrong rectangle, at the one boundary where it has no reason to fire.

## What Changes

- **The pointer chooses the monitor.** The monitor holding the pointer when the menu opens is the
  monitor the menu is drawn on and the monitor whose work area the sector is resolved against.
- **The choice is latched at open time**, alongside the gesture origin, and is never re-read. A flick
  that carries the pointer across a seam does not retarget the window. This matters because pointer
  motion is genuinely unconstrained between abutting monitors: deciding at release time would throw
  a window to the next screen on any sufficiently long flick near a seam.
- **BREAKING (behaviour):** a committed gesture can now move a window to another monitor. The
  `window-snap` requirement that a snapped window *"does not move to another monitor"* is withdrawn.
- **BREAKING (behaviour):** the menu no longer follows the target window. The `radial-menu`
  requirement that it is drawn on *"the monitor containing the window that will be acted upon"* is
  replaced by one naming the pointer's monitor.
- `snap()` is told which monitor to use rather than deriving it. This is not only plumbing: mutter
  applies hysteresis when a move crosses monitors of differing scale and can decline to reassign
  `window->monitor` at all, so a caller that re-reads `get_monitor()` after the move inherits an
  ambiguity that a caller holding the index does not.
- When the pointer is on no monitor at all — a gap in a non-abutting layout, where
  `findMonitorForPoint` answers `null` — the gesture falls back to the target window's monitor, which
  is exactly today's behaviour.
- Three harness cases cover it, sharing one two-monitor session: pointer and window in agreement,
  pointer and window on different monitors, and a flick across the seam that must not retarget.

## Capabilities

### New Capabilities

None. Both surfaces this touches already have a capability that owns them.

### Modified Capabilities

- `radial-menu`: the requirement *"Menu appears on the monitor of the target window"* is replaced by
  one that names the monitor under the pointer, and fixes it at the moment the menu opens.
- `window-snap`: the requirement *"Geometry is computed within the monitor work area"* keeps its
  work-area guarantee and loses its same-monitor guarantee; the monitor it computes against becomes
  the gesture's, not the window's.

## Impact

**Code**

- `magunetto@matteopacini.me/extension.js` — `_onTrigger` reads the pointer, resolves it to a monitor
  via `Main.layoutManager.findMonitorForPoint`, holds the result for the gesture, and passes it to
  both the menu and the snap.
- `magunetto@matteopacini.me/lib/snap.js` — `workAreaFor` takes a monitor index instead of a window;
  `snap()` takes the index as a parameter.
- `magunetto@matteopacini.me/lib/radialMenu.js` — **unchanged.** It already clamps the origin against
  whatever monitor geometry it is given, and its widget's one-monitor allocation does not restrict
  input: a modal grab receives motion for the whole stage, and `event.get_coords()` is already in
  stage coordinates.
- `magunetto@matteopacini.me/lib/geometry.js` — **unchanged.** `rectFor` takes a work area as a
  parameter and has never known whose it is.
- `magunetto@matteopacini.me/lib/animate.js` — **unchanged.** It works entirely in frame rects and
  names no monitor, so a travel crosses a seam without being told.

**Tests**

- `tests/harness/cases/multi-monitor.sh` — keeps its assertions, which stay true: it places pointer
  and window on the same monitor. Its header comment inverts.
- `tests/harness/cases/cross-monitor.sh` — new.
- `tests/harness/cases/cross-monitor-latch.sh` — new.
- These cases cannot use the `work_area_field` helper. `shellhook.js` derives `WorkArea()` from the
  target window's monitor, so it reports the old monitor before the fix and the new one after — an
  assertion built on it holds in both worlds and proves nothing. They read a work area by explicit
  monitor index instead.
- The VM tier is **not** extended. Multi-head there has no NixOS option, only raw qemu flags with no
  precedent in `nixos/tests`, and the driver's `screendump` can photograph only head 0 — so a failure
  could not show the monitor it happened on. The tier's job is that an installed tree loads and
  binds, and the harness already has two monitors.

**Behaviour a user may notice beyond the fix**

- `snap()` moves windows as a user operation. With `workspaces-only-on-primary` — on by default in
  GNOME — mutter pulls a window onto the active workspace when a user move lands it on the primary
  monitor. A cross-monitor snap toward the primary can therefore change a window's workspace. This is
  mutter's own semantics for any user-initiated move, and is accepted rather than worked around.
