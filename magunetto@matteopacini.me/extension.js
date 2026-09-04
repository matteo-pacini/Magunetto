import Meta from 'gi://Meta';
import Mtk from 'gi://Mtk';
import Shell from 'gi://Shell';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {TilePreview} from 'resource:///org/gnome/shell/ui/windowManager.js';

import {cancelAll} from './lib/animate.js';
import {curveFor} from './lib/curves.js';
import {NONE, rectFor} from './lib/geometry.js';
import {RadialMenu} from './lib/radialMenu.js';
import {isSnappable, snap, stillExists, workAreaFor} from './lib/snap.js';

const KEYBINDING = 'show-radial-menu';

// The state trace is a development aid that nothing reads in a normal session,
// so it is bounded rather than left to grow for as long as the shell runs. Every
// gesture appends a handful of entries; no single run of the harness comes near
// this, so what it holds is still the whole of what a case did.
const LOG_LIMIT = 200;

export default class MagunettoExtension extends Extension {
    enable() {
        this._log = [];
        this._menu = null;
        this._closing = null;
        this._targetWindow = null;
        this._gestureMonitor = null;
        this._preview = null;
        this._previewEnabled = false;
        this._gaps = null;
        this._settings = this.getSettings();

        const action = Main.wm.addKeybinding(
            KEYBINDING,
            this._settings,
            Meta.KeyBindingFlags.IGNORE_AUTOREPEAT,
            Shell.ActionMode.NORMAL,
            this._onTrigger.bind(this));

        this.record(`keybinding:${action}:${this._settings.get_strv(KEYBINDING)[0]}`);

        this.record('enabled');
    }

    disable() {
        this._menu?.destroy();
        this._menu = null;

        // A committed menu is still fading when the gesture ends, so it is no
        // longer the open one and still has to go.
        this._closing?.destroy();
        this._closing = null;

        // A travel outlives the gesture that started it, and holds a timeout, a
        // frozen actor and a widget in the shell's own group.
        cancelAll();

        // close() only hides it; the widget stays parented to the shell's own
        // window group until something destroys it.
        this._preview?.destroy();
        this._preview = null;

        Main.wm.removeKeybinding(KEYBINDING);

        this._targetWindow = null;
        this._gestureMonitor = null;
        this._gaps = null;
        this._settings = null;
        this._log = null;
    }

    // The ordered trace of what the extension believed happened. Tests assert on
    // this rather than on pixels.
    get log() {
        return this._log ?? [];
    }

    record(entry) {
        if (!this._log)
            return;

        this._log.push(entry);
        if (this._log.length > LOG_LIMIT)
            this._log.shift();
    }

    clearLog() {
        if (this._log)
            this._log.length = 0;
    }

    get targetWindow() {
        return this._targetWindow;
    }

    get isOverlayUp() {
        return this._menu !== null;
    }

    get isGrabHeld() {
        return this._menu?.isGrabHeld ?? false;
    }

    // The preview is drawn and nothing else, so tests have no other way to see
    // it: it moves no window and writes nothing to the log.
    get preview() {
        return this._preview;
    }

    _onTrigger(display, window, event, binding) {
        if (this._menu) {
            this.record('already-open');
            return;
        }

        const target = global.display.get_focus_window();
        if (!isSnappable(target)) {
            this.record('no-target');
            return;
        }

        this.record(`keybinding-fired:${binding.get_mask()}`);
        this._targetWindow = target;

        // The gesture belongs to the monitor under the pointer, decided once here
        // and held for the rest of it. Deciding again at release would be wrong:
        // nothing pins the pointer at the seam between two monitors, so a flick
        // begun anywhere near one carries it across, and the window would follow.
        // In a gap between monitors there is no answer, and the window's own
        // monitor is the one the gesture would have used before it asked.
        const [pointerX, pointerY] = global.get_pointer();
        const monitor = Main.layoutManager.findMonitorForPoint(pointerX, pointerY);
        this._gestureMonitor = monitor ? monitor.index : target.get_monitor();

        // Read as the gesture starts rather than cached, so a preference change
        // applies to the next gesture without reloading the extension. The gaps
        // are held for the whole gesture: the outline and the landing are the
        // same rectangle only if both are computed from the same values.
        this._previewEnabled = this._settings.get_boolean('snap-preview');
        this._gaps = {
            outer: this._settings.get_int('snap-outer-gap'),
            inner: this._settings.get_int('snap-inner-gap'),
        };

        const menu = new RadialMenu({
            monitorIndex: this._gestureMonitor,
            mask: binding.get_mask(),
            record: this.record.bind(this),
            onSelect: this._onSelect.bind(this),
            onFinish: this._onFinish.bind(this),
            onGone: () => {
                if (this._closing === menu)
                    this._closing = null;
            },
        });
        this._menu = menu;

        if (!menu.open()) {
            this._menu = null;
            this._targetWindow = null;
            return;
        }

        this.record('overlay-up');
    }

    // The preview belongs here rather than to the menu: opening it needs the
    // target window, and reaching that from radialMenu.js would pull snap.js —
    // and through it animate.js and Meta — into a module that imports nothing
    // but the geometry maths.
    _onSelect(sector) {
        if (!this._previewEnabled)
            return;

        const rect = rectFor(sector, workAreaFor(this._gestureMonitor), this._gaps);
        if (!rect) {
            // rectFor answers null for the dead zone, which is exactly when
            // releasing would place nothing and so nothing should be shown.
            this._preview?.close();
            return;
        }

        // close() only fades and hides, leaving the widget parented to the
        // shell's window group, so one instance is kept and reused rather than
        // built per gesture. This is the shell's own pattern for it.
        this._preview ??= new TilePreview();

        // TilePreview compares rectangles with Mtk's own equal(), so a plain
        // object cannot be passed. geometry.js stays free of any toolkit import
        // by being unit-tested outside a shell, which makes this the boundary.
        this._preview.open(this._targetWindow, new Mtk.Rectangle(rect),
            this._gestureMonitor);

        // open() ends by lowering the preview below the window actor, which suits
        // the shell showing where a window being dragged will land. This gesture
        // leaves the window where it is, so a region overlapping it would hide the
        // outline entirely. Raised after every open, not once: open() lowers it
        // again on each selection change.
        global.window_group.set_child_above_sibling(this._preview, null);
    }

    _onFinish(sector) {
        // The menu reports itself finished as the fade starts, not when it ends,
        // so it is no longer the open one but is still on screen. Held until it
        // is really gone, so disable() can cut the fade short.
        this._closing = this._menu;
        this._menu = null;

        // Committed or abandoned, the gesture is over and the region it was
        // offering is no longer a question.
        this._preview?.close();

        const target = this._targetWindow;
        if (sector === NONE) {
            this.record('no-selection');
            return;
        }

        // The window may have closed while the menu was up.
        if (!stillExists(target)) {
            this.record('target-gone');
            return;
        }

        // Read at commit time rather than cached, so a preference change applies
        // to the next gesture without reloading the extension.
        const curve = this._settings.get_boolean('snap-animation')
            ? curveFor(this._settings.get_string('snap-animation-curve'))
            : null;

        snap(target, sector, curve, this._gestureMonitor, this._gaps);
        this.record(`snapped:${sector}`);
    }
}
