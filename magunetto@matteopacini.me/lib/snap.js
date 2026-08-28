// Applying a chosen sector to a window.

import Meta from 'gi://Meta';

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
export function workAreaFor(window) {
    const monitor = window.get_monitor();
    const area = global.workspace_manager.get_active_workspace()
        .get_work_area_for_monitor(monitor);

    return {x: area.x, y: area.y, width: area.width, height: area.height};
}

export function snap(window, sector) {
    const rect = rectFor(sector, workAreaFor(window));
    if (!rect)
        return null;

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

    return rect;
}
