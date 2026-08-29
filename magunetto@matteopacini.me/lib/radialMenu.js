// The radial menu itself: the modal grab, the gesture, and the drawing.

import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Shell from 'gi://Shell';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {
    CENTRE,
    CENTRE_BAND_RADIUS,
    DEAD_ZONE_RADIUS,
    DIRECTIONS,
    NONE,
    sectorFor,
} from './geometry.js';

// A shortcut with no modifier can never be committed by releasing one, so the
// menu would otherwise stay up forever.
const NO_MODS_TIMEOUT = 1500;
const FADE_DURATION = 120;
const RING_THICKNESS = 46;
const GAP = 3;
const EDGE_MARGIN = 8;

// The highest set bit of the modifier mask. Releasing that one modifier is what
// commits, matching how the shell's own window switcher decides it is finished.
export function primaryModifier(mask) {
    if (mask === 0)
        return 0;

    let primary = 1;
    while (mask > 1) {
        mask >>= 1;
        primary <<= 1;
    }
    return primary;
}

const RadialArea = GObject.registerClass(
class RadialArea extends St.DrawingArea {
    _init(params) {
        super._init({style_class: 'magunetto-menu', ...params});
        this._sector = NONE;
        this._origin = {x: 0, y: 0};
    }

    setOrigin(x, y) {
        this._origin = {x, y};
        this.queue_repaint();
    }

    setSector(sector) {
        if (this._sector === sector)
            return;
        this._sector = sector;
        this.queue_repaint();
    }

    _setColor(cr, color, alpha = 1) {
        cr.setSourceRGBA(
            color.red / 255,
            color.green / 255,
            color.blue / 255,
            (color.alpha / 255) * alpha);
    }

    vfunc_repaint() {
        const cr = this.get_context();
        const themeNode = this.get_theme_node();
        const scale = St.ThemeContext.get_for_stage(global.stage).scale_factor;

        const foreground = themeNode.get_foreground_color();
        const background = themeNode.get_background_color();

        const {x: cx, y: cy} = this._origin;
        const inner = DEAD_ZONE_RADIUS * scale;
        const centreOuter = CENTRE_BAND_RADIUS * scale;
        const ringOuter = centreOuter + RING_THICKNESS * scale;
        const span = (2 * Math.PI) / DIRECTIONS.length;
        const gap = (GAP * scale) / ringOuter;

        cr.setLineWidth(Math.max(1, scale));

        // Centre action: a disc between the dead zone and the ring.
        cr.arc(cx, cy, centreOuter - GAP * scale, 0, 2 * Math.PI);
        cr.newSubPath();
        cr.arc(cx, cy, inner, 0, 2 * Math.PI);
        cr.setFillRule(1); // even-odd, so the dead zone stays punched out
        this._setColor(cr, this._sector === CENTRE ? foreground : background,
            this._sector === CENTRE ? 0.85 : 1);
        cr.fill();

        DIRECTIONS.forEach((direction, index) => {
            const centreAngle = index * span;
            const from = centreAngle - span / 2 + gap;
            const to = centreAngle + span / 2 - gap;

            cr.newPath();
            cr.arc(cx, cy, ringOuter, from, to);
            cr.arcNegative(cx, cy, centreOuter, to, from);
            cr.closePath();

            const selected = this._sector === direction;
            this._setColor(cr, selected ? foreground : background, selected ? 0.85 : 1);
            cr.fill();
        });

        cr.$dispose();
    }
});

export const RadialMenu = GObject.registerClass(
class RadialMenu extends St.Widget {
    _init({monitorIndex, mask, record, onSelect, onFinish, onGone}) {
        const geometry = global.display.get_monitor_geometry(monitorIndex);

        super._init({
            reactive: true,
            x: geometry.x,
            y: geometry.y,
            width: geometry.width,
            height: geometry.height,
            opacity: 0,
        });

        this._record = record;
        this._onSelect = onSelect;
        this._onFinish = onFinish;
        this._onGone = onGone;
        this._mask = mask;
        this._geometry = geometry;
        this._sector = NONE;
        this._origin = {x: 0, y: 0};
        this._dx = 0;
        this._dy = 0;
        this._grab = null;
        this._noModsTimeoutId = 0;
        this._finished = false;

        this._area = new RadialArea({
            x: 0,
            y: 0,
            width: geometry.width,
            height: geometry.height,
        });
        this.add_child(this._area);

        this.connect('destroy', this._onDestroy.bind(this));
    }

    // The grab belongs to the menu; the owner reports whether one is held rather
    // than reaching into the field that holds it.
    get isGrabHeld() {
        return this._grab !== null;
    }

    open() {
        Main.layoutManager.addTopChrome(this);

        // System-modal rather than the default action mode, which would suppress
        // every other shortcut on the desktop while the menu is up.
        this._grab = Main.pushModal(this, {actionMode: Shell.ActionMode.SYSTEM_MODAL});

        // GNOME 50 exposes no seat state on the grab, so whether the grab took
        // effect is checked by asking who actually holds key focus.
        if (global.stage.get_key_focus() !== this) {
            this._record('grab-failed');
            this._releaseGrab();
            this.destroy();
            return false;
        }

        this._modifierMask = primaryModifier(this._mask);

        // The pointer cannot travel past a screen edge, so a gesture starting
        // there would leave the far sectors unreachable. Pulling the origin
        // inward by the ring radius keeps every direction within reach, and the
        // menu is drawn at that same origin so what is shown matches what is
        // selected.
        const [pointerX, pointerY] = global.get_pointer();
        const margin = CENTRE_BAND_RADIUS + EDGE_MARGIN;
        const {x: mx, y: my, width, height} = this._geometry;

        this._origin = {
            x: clamp(pointerX, mx + margin, mx + width - margin),
            y: clamp(pointerY, my + margin, my + height - margin),
        };
        this._area.setOrigin(this._origin.x - mx, this._origin.y - my);

        this.ease({
            opacity: 255,
            duration: FADE_DURATION,
            mode: Clutter.AnimationMode.EASE_OUT_QUAD,
        });

        // The user may have released the modifier before the grab landed, in
        // which case no release event is ever delivered.
        if (this._modifierMask) {
            const [, , mods] = global.get_pointer();
            if (!(mods & this._modifierMask)) {
                this._finish();
                return true;
            }
        } else {
            this._resetNoModsTimeout();
        }

        return true;
    }

    vfunc_motion_event(event) {
        const [x, y] = event.get_coords();
        this._dx = x - this._origin.x;
        this._dy = y - this._origin.y;

        const sector = sectorFor(this._dx, this._dy);
        if (sector !== this._sector) {
            this._sector = sector;
            this._area.setSector(sector);
            this._record(`select:${sector}`);
            this._onSelect(sector);
        }

        return Clutter.EVENT_STOP;
    }

    vfunc_key_press_event(event) {
        if (event.get_key_symbol() === Clutter.KEY_Escape) {
            this._record('cancelled');
            this._cancel();
        }

        return Clutter.EVENT_STOP;
    }

    vfunc_key_release_event(event) {
        if (this._modifierMask) {
            // Live modifier state, not the event's own: the event predates the
            // release it is reporting.
            const [, , mods] = global.get_pointer();
            if ((mods & this._modifierMask) === 0) {
                this._record('released');
                this._finish();
            }
        } else {
            this._resetNoModsTimeout();
        }

        return Clutter.EVENT_STOP;
    }

    _resetNoModsTimeout() {
        this._clearNoModsTimeout();
        this._noModsTimeoutId = GLib.timeout_add(
            GLib.PRIORITY_DEFAULT, NO_MODS_TIMEOUT, () => {
                this._noModsTimeoutId = 0;
                this._record('timed-out');
                this._finish();
                return GLib.SOURCE_REMOVE;
            });
    }

    _clearNoModsTimeout() {
        if (this._noModsTimeoutId) {
            GLib.source_remove(this._noModsTimeoutId);
            this._noModsTimeoutId = 0;
        }
    }

    _finish() {
        if (this._finished)
            return;
        this._finished = true;

        const sector = this._sector;
        this._close();
        this._onFinish(sector);
    }

    _cancel() {
        if (this._finished)
            return;
        this._finished = true;

        this._close();
        this._onFinish(NONE);
    }

    _releaseGrab() {
        if (this._grab) {
            Main.popModal(this._grab);
            this._grab = null;
        }
    }

    _close() {
        this._clearNoModsTimeout();
        this._releaseGrab();

        this.ease({
            opacity: 0,
            duration: FADE_DURATION,
            mode: Clutter.AnimationMode.EASE_OUT_QUAD,
            onComplete: () => this.destroy(),
        });
    }

    _onDestroy() {
        // Nothing may outlive the actor: a grab left in place would wedge the
        // desktop, and a live timeout would fire against a destroyed menu.
        this._clearNoModsTimeout();
        this._releaseGrab();

        // Destruction can also come from outside, without the gesture having
        // finished. The owner still has to be told, or it goes on believing a
        // menu is open and refuses every later gesture.
        if (!this._finished) {
            this._finished = true;
            this._onFinish(NONE);
        }

        // A menu that has finished is still on screen for the length of its
        // fade. This is the only word the owner gets that it is really gone.
        this._onGone();
    }
});

function clamp(value, low, high) {
    // A monitor narrower than twice the margin has no room to pull the origin
    // inward on both sides; centring is the best available compromise.
    if (low > high)
        return (low + high) / 2;

    return Math.min(Math.max(value, low), high);
}
