import Meta from 'gi://Meta';
import Shell from 'gi://Shell';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {cancelAll} from './lib/animate.js';
import {curveFor} from './lib/curves.js';
import {NONE} from './lib/geometry.js';
import {RadialMenu} from './lib/radialMenu.js';
import {isSnappable, snap, stillExists} from './lib/snap.js';

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

        Main.wm.removeKeybinding(KEYBINDING);

        this._targetWindow = null;
        this._gestureMonitor = null;
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

        const menu = new RadialMenu({
            monitorIndex: this._gestureMonitor,
            mask: binding.get_mask(),
            record: this.record.bind(this),
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

    _onFinish(sector) {
        // The menu reports itself finished as the fade starts, not when it ends,
        // so it is no longer the open one but is still on screen. Held until it
        // is really gone, so disable() can cut the fade short.
        this._closing = this._menu;
        this._menu = null;

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

        snap(target, sector, curve, this._gestureMonitor);
        this.record(`snapped:${sector}`);
    }
}
