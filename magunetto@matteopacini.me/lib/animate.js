// Showing a window travelling from where it was to where it was snapped.
//
// A frame rectangle cannot be interpolated: applying one is a single configure
// to the client, which repaints once at the new size. What travels is the
// compositor actor, counter-transformed back to the old rectangle and eased to
// identity, with a snapshot of the old pixels crossfading over it. This is how
// the shell animates maximise, in windowManager.js.

import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {easeWith} from './curves.js';

export const DURATION = 220;

// Named so the test interface can count snapshots that outlived their animation.
export const SNAPSHOT_NAME = 'magunetto-snapshot';

// How long to wait for a client that never takes the size it was offered. Past
// this the travel runs on whatever geometry the window ended up with: a slide
// starting much later than the gesture reads as a glitch rather than a
// transition.
const SETTLE_TIMEOUT = 250;

// Snapshot the window as it looks now and hold it there. Must run before the
// geometry moves: the content is the old pixels the crossfade needs, and the
// freeze is what stops the window being drawn at its destination during the
// frames between the placement landing and the compositor reporting it.
export function capture(window) {
    const actor = window.get_compositor_private();
    if (!actor)
        return null;

    const rect = window.get_frame_rect();
    if (rect.width < 1 || rect.height < 1)
        return null;

    // Losing the snapshot costs the crossfade, not the travel.
    let content = null;
    try {
        content = actor.paint_to_content(rect);
    } catch {
        content = null;
    }

    actor.freeze();
    return {actor, rect, content, frozen: true};
}

export function animate(snapshot, curve, target) {
    const {actor, rect: oldRect, content} = snapshot;
    const wm = global.window_manager;

    let sizeId = 0;
    let started = false;
    let destroyId = actor.connect('destroy', () => {
        // Nothing to thaw once the actor is gone.
        snapshot.frozen = false;
        started = true;
        release();
    });

    GLib.timeout_add(GLib.PRIORITY_DEFAULT, SETTLE_TIMEOUT, () => {
        start();
        return GLib.SOURCE_REMOVE;
    });

    // freeze() is refcounted and an unpaired one stops the window updating for
    // good, so every path out of here comes through this and it runs once.
    function release() {
        if (sizeId) {
            wm.disconnect(sizeId);
            sizeId = 0;
        }
        if (destroyId) {
            actor.disconnect(destroyId);
            destroyId = 0;
        }
        if (snapshot.frozen) {
            snapshot.frozen = false;
            actor.thaw();
        }
    }

    function start() {
        if (started)
            return;
        started = true;

        const newRect = actor.meta_window.get_frame_rect();
        const scaleX = newRect.width / oldRect.width;
        const scaleY = newRect.height / oldRect.height;
        if (!(scaleX > 0) || !(scaleY > 0)) {
            release();
            return;
        }

        if (content) {
            const ghost = new St.Widget({content, name: SNAPSHOT_NAME});
            ghost.set_offscreen_redirect(Clutter.OffscreenRedirect.ALWAYS);
            ghost.set_position(oldRect.x, oldRect.y);
            ghost.set_size(oldRect.width, oldRect.height);
            Main.uiGroup.add_child(ghost);

            // The window can close mid-travel; its snapshot must not outlive it.
            actor.connectObject('destroy', () => ghost.destroy(), ghost);

            // Both callbacks go on the last ease of each object. A duration of
            // zero — which is what the desktop's own animation switch produces —
            // runs onStopped synchronously, so one on the first ease would tear
            // the object down while the second was still being set up.
            easeWith(ghost, {x: newRect.x, y: newRect.y},
                curve.translate, curve.bezier, DURATION);
            easeWith(ghost, {scale_x: scaleX, scale_y: scaleY, opacity: 0},
                curve.scale, curve.bezier, DURATION, () => ghost.destroy());
        }

        // Clearing a travel still running from an earlier snap. Nothing puts the
        // actor back to rest afterwards, and nothing needs to: each ease lands
        // exactly on its target, and an interrupted one is overwritten here.
        actor.remove_all_transitions();
        actor.translation_x = oldRect.x - newRect.x;
        actor.translation_y = oldRect.y - newRect.y;
        actor.scale_x = 1 / scaleX;
        actor.scale_y = 1 / scaleY;

        easeWith(actor, {translation_x: 0, translation_y: 0},
            curve.translate, curve.bezier, DURATION);
        easeWith(actor, {scale_x: 1, scale_y: 1},
            curve.scale, curve.bezier, DURATION);

        // Thawing now rather than when the travel ends: waiting would apply the
        // scale to the old texture size for the whole run.
        release();
    }

    // A move takes effect inside move_frame(), so by now the window is already
    // where it belongs and the one size-changed it will ever emit has been and
    // gone. A resize is different: the client has to ack the configure first, and
    // every report before that ack still carries the old size, so acting on one
    // would compute a scale of 1 and animate nothing.
    const landed = actor.meta_window.get_frame_rect();
    if (landed.width === target.width && landed.height === target.height) {
        start();
        return;
    }

    sizeId = wm.connect('size-changed', (_wm, changed) => {
        if (changed !== actor)
            return;
        const now = actor.meta_window.get_frame_rect();
        if (now.width === oldRect.width && now.height === oldRect.height)
            return;
        start();
    });
}
