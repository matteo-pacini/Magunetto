// Applying a chosen sector to a window.

import Meta from 'gi://Meta';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {animate, capture} from './animate.js';
import {rectFor} from './geometry.js';

export function isSnappable(window) {
    if (!window)
        return false;
    if (window.get_window_type() !== Meta.WindowType.NORMAL)
        return false;
    if (window.is_skip_taskbar())
        return false;

    // A maximised or fullscreen window reports that it allows neither moving nor
    // resizing, because in that state it does not. Snapping clears that state
    // first, so the question is whether the window would be resizable once it is
    // cleared.
    if (window.is_maximized() || window.is_fullscreen())
        return true;

    return window.allows_move() && window.allows_resize();
}

// A window that has been closed keeps its JavaScript wrapper alive for a while,
// but loses its compositor actor immediately.
export function stillExists(window) {
    return !!window && !!window.get_compositor_private();
}

// Mtk.Rectangle crosses into plain objects here so the geometry maths stays free
// of any toolkit import.
export function workAreaFor(monitorIndex) {
    const area = global.workspace_manager.get_active_workspace()
        .get_work_area_for_monitor(monitorIndex);

    return {x: area.x, y: area.y, width: area.width, height: area.height};
}

// The monitor is the caller's to decide, not this function's to look up. Asking
// the window would answer with the monitor it is leaving, since the rectangle is
// computed before the move; and after the move mutter may decline to reassign it
// at all, holding a window to its old monitor when the two differ in scale.
export function snap(window, sector, curve, monitorIndex, gaps) {
    const rect = rectFor(sector, workAreaFor(monitorIndex), gaps);
    if (!rect)
        return null;

    // Snapping to the region the window already occupies changes no geometry, so
    // nothing would ever be reported to drive a travel to completion.
    const current = window.get_frame_rect();
    const moves = current.x !== rect.x || current.y !== rect.y ||
        current.width !== rect.width || current.height !== rect.height;

    const snapshot = curve && moves ? capture(window) : null;
    const actor = window.get_compositor_private();

    // Leaving maximised or fullscreen is a size change the shell animates itself,
    // towards the rectangle this call is about to override. Suppressing it leaves
    // one travel in charge of the whole move. The skip is queued only immediately
    // before the effect that consumes it, so it cannot go stale and swallow an
    // unrelated animation later.
    if (actor && (window.is_maximized() || window.is_fullscreen()))
        Main.wm.skipNextEffect(actor);

    // Placement on a maximised or fullscreen window is ignored, so that state has
    // to go first.
    if (window.is_maximized())
        window.unmaximize();
    if (window.is_fullscreen())
        window.unmake_fullscreen();

    // The redundant move is what makes windows that resize in fixed increments
    // actually move: given only move_resize_frame they take the new size and stay
    // where they were. Both calls are user operations so the window is not
    // clamped in ways that break multi-monitor placement.
    window.move_frame(true, rect.x, rect.y);
    window.move_resize_frame(true, rect.x, rect.y, rect.width, rect.height);

    if (snapshot)
        animate(snapshot, curve, rect);

    return rect;
}
