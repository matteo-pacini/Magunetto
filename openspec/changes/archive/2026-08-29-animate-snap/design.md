## Context

See `proposal.md` — Why.

Every finding below was established empirically against GNOME Shell 50.4 in a headless session, not
from documentation. The probes replayed `snap()`'s exact call sequence and recorded what the
compositor reported and when.

Three constraints shape everything:

**A frame rectangle cannot be interpolated.** `move_resize_frame()` is one configure to the client,
which repaints once at the new size. There is no intermediate geometry to tween.

**The compositor reports a move and a resize differently.** Replaying the call sequence with each
`size-changed` stamped by the phase it arrived in:

```
  PURE MOVE  (640x768 at x=0  ->  640x768 at x=640)
    size-changed, synchronous inside move_frame():  640,32,640x768   <- already final
    ...and that is the only signal it ever emits.

  RESIZE  (500x400  ->  640x384)
    size-changed, synchronous inside move_frame():  0,32,500x400     <- size still OLD
    size-changed, async once the client acks:       0,32,640x384     <- final
```

`get_frame_rect()` immediately after both calls still reports `500x400` for the resize. The new size
is not observable until the client has acked.

**The shell already animates two of the paths.** Clearing maximised or fullscreen state emits
`size-change` (`UNMAXIMIZE`, `UNFULLSCREEN`), which drives the shell's own clone animation in
`windowManager.js`. It animates to the correct final rectangle, because it reads `get_frame_rect()`
at `size-changed` time — after our placement has landed. So those two paths animate today and
everything else does not.

## Goals / Non-Goals

**Goals:**

- One animation owns the whole move, so every snap looks alike whatever the window was doing before.
- No client round-trips beyond the single configure placement already costs.
- A window can never be left displaced, scaled, or frozen.

**Non-Goals:**

- Configurable duration. See `proposal.md` — What Changes.
- Animating anything other than the snap. Manual moves, resizes and the shell's own effects are
  untouched.
- Matching the shell's animation pixel for pixel. Matching its *approach* is the point; the timing
  and curve are ours.

## Decisions

### Transform the actor, do not tween the geometry

The window is placed once, immediately. What animates is its compositor actor: counter-transformed
back to where the window was, then eased to identity, with a snapshot of the old pixels crossfading
over the top. This is `_prepareAnimationInfo` / `_sizeChangedWindow` in `windowManager.js`, which is
how the shell animates maximise.

*Alternative — tween the real frame rectangle.* A timeline calling `move_resize_frame()` each frame.
Rejected: one configure per frame, a full relayout per step in GTK4 clients, and windows that resize
in fixed increments would stutter through their increment grid. It is also the only approach whose
cost scales with duration.

*Alternative — route through `tile()` or `maximize()` to inherit the shell's animation for free.*
Rejected: covers halves and the centre action only, never quarters; and it makes windows genuinely
tiled, which brings keyboard resize handles and snap-back-on-drag that this capability does not
promise. The centre action deliberately fills the work area rather than maximising, and that
distinction would be lost.

### Suppress the shell's animation rather than work around it

`Main.wm.skipNextEffect(actor)` immediately before `unmaximize()` / `unmake_fullscreen()`.

The alternative was to let the shell animate those two paths and only animate the rest ourselves.
Rejected because it leaves the inconsistency the change exists to remove: the shell's duration is a
fixed 250ms and its curve is fixed, so the preference would silently not apply to maximised windows,
and two animations would be transforming the same actor.

`skipNextEffect` is a `Set` drained by `_shouldAnimateActor` via `.delete()`. A skip that is queued
but never consumed stays queued and swallows the *next* unrelated effect for that actor — a window
that vanishes with no animation when minimised ten minutes later. The probe established that the
effect fires in exactly these two cases and only these, so the skip is queued only immediately
before the call that consumes it. It cannot go stale.

### Freeze the actor across the placement

`Meta.WindowActor.freeze()` before placing, `thaw()` once the transforms are written.

Without it the window is painted at its destination for the frames between the placement landing and
the compositor reporting it, and the animation then yanks it back to the start — seen as a brief
jump at the moment of release. The GIR is explicit that freeze "inhibits updates and geometry
changes", which is exactly the window needed.

Thaw happens as soon as the transforms are set, not when the animation ends. Waiting would apply the
scale to the old texture size for the entire run.

Freeze is refcounted and an unpaired freeze stops the window updating permanently, so there are
three release paths, whichever arrives first: the animation starting, the actor being destroyed, and
a timeout. `snap()` additionally skips the animation entirely when the target rectangle is the one
the window already occupies, since that reports no change at all.

### Trigger on size, not on the first signal

Given the reporting asymmetry above:

```
  requested size already current?
        |
   yes -+-> start now
        |         (a move landed inside move_frame; nothing further is coming,
        |          and waiting for a signal would hang until the timeout)
        |
    no -+-> wait for a size-changed whose size differs from the old rectangle
                  (a resize; every report before the client's ack still carries
                   the old size, and acting on one of those animates a scale of 1)
```

Acting on the first signal unconditionally was tried and produces a no-op animation for fullscreen
windows — the transform computes to identity because the rectangle has not moved yet. The size
comparison is what separates a stale report from a real one.

A 250ms timeout starts the animation on whatever geometry exists, for a client that never takes the
size it was offered — a window whose minimum size exceeds its target quarter. Chosen over the
alternative of abandoning the animation because the window should still be seen to move; chosen
short because a slide that begins much later than the gesture reads as a glitch rather than a
transition.

### Seven curves, described, with the duration fixed

A curve and a duration are not independent axes: a sharp curve needs a longer duration than a soft
one to read the same way, so offering both invites combinations that look broken. The curve carries
the character, so that is the axis offered.

The set spans the sharpness range in perceptible steps and adds two with distinct character. Curves
that only interpolate between neighbours were cut — a step too fine to see is a step not worth
offering.

Each curve applies separately to translation and to scale, because overshoot means different things
for each. Applied to scale it renders the window larger than the region it is snapping into,
lapping over whatever is beside it; applied to translation alone it reads as momentum. `Spring` is
that split — overshoot on the slide, none on the size. `Overshoot` applies it to both and is the one
option that visibly exceeds its region, which its description states.

`Settle` is a cubic Bézier rather than one of Clutter's named modes, so it is applied through
`set_cubic_bezier_progress()` on the transition after `ease()` has created it.

### Accessibility comes for free

The shell patches `Clutter.Actor.set_easing_duration` through `adjustAnimationTime()`, which returns
0 when `org.gnome.desktop.interface enable-animations` is false. Any `ease()` inside the shell
already collapses to instant, so the requirement that desktop preferences are honoured needs no code
— but it does need a test, because it would break silently.

### The harness needs a new surface

The animation changes neither the final geometry nor the state log, so every existing assertion
passes whether it works, silently no-ops, or strands the window off-screen. A test-only
actor-transform surface is not optional here; without it this change is unverifiable.

`run.sh` keys session reuse on monitors and shortcut. Animation settings become a third dimension in
that key.

## Risks / Trade-offs

- **An unpaired freeze stops a window updating forever.** → Three independent release paths, plus
  skipping the animation when the geometry would not change. The harness asserts that a window is
  still movable after a repeat snap, which is the case that produced no signal at all.
- **The snapshot is taken with `paint_to_content()`, which can fail.** → Treated as optional: the
  transform animation runs without a crossfade rather than not running.
- **Scaling the actor scales its shadow with it.** → Accepted; the shell's own animation has the
  same property, so snapping looks like the rest of the desktop.
- **A window closing mid-animation could leave the snapshot on screen.** → The snapshot is tied to
  the actor's `destroy`.
- **`Overshoot` visibly exceeds the region.** → Kept, because the choice is the user's, and its
  description says what it does. `Spring` is listed above it so the clean version is seen first.
- **The 250ms fallback animates from stale geometry for a very slow client.** → Degrades to a
  correct slide with no scale change, rather than to nothing.

## Open Questions

None. The two that were open — whether clearing maximised state fires the shell's own animation, and
when the compositor reports a move versus a resize — were settled by probe before this was written.
