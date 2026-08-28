import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {NONE} from './lib/geometry.js';
import {RadialMenu} from './lib/radialMenu.js';
import {isSnappable, snap, stillExists} from './lib/snap.js';
import {TestInterface} from './lib/testInterface.js';

const KEYBINDING = 'show-radial-menu';

export default class MagunettoExtension extends Extension {
    enable() {
        this._log = [];
        this._menu = null;
        this._targetWindow = null;
        this._settings = this.getSettings();

        const action = Main.wm.addKeybinding(
            KEYBINDING,
            this._settings,
            Meta.KeyBindingFlags.IGNORE_AUTOREPEAT,
            Shell.ActionMode.NORMAL,
            this._onTrigger.bind(this));

        this.record(`keybinding:${action}:${this._settings.get_strv(KEYBINDING)[0]}`);

        this.record('enabled');

        if (GLib.getenv('MAGUNETTO_TEST'))
            this._test = new TestInterface(this);
    }

    disable() {
        this._menu?.destroy();
        this._menu = null;

        Main.wm.removeKeybinding(KEYBINDING);

        this._test?.destroy();
        this._test = null;
        this._targetWindow = null;
        this._settings = null;
        this._log = null;
    }

    // The ordered trace of what the extension believed happened. Tests assert on
    // this rather than on pixels.
    get log() {
        return this._log ?? [];
    }

    record(entry) {
        this._log?.push(entry);
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
        return this._menu?._grab != null;
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

        const menu = new RadialMenu({
            monitorIndex: target.get_monitor(),
            mask: binding.get_mask(),
            record: this.record.bind(this),
            onFinish: this._onFinish.bind(this),
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

        snap(target, sector);
        this.record(`snapped:${sector}`);
    }
}
