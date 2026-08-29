import Adw from 'gi://Adw';
import Gdk from 'gi://Gdk';
import Gio from 'gi://Gio';
import Gtk from 'gi://Gtk';
import {ExtensionPreferences} from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';

import {CURVES, CURVE_KEYS, DEFAULT_CURVE} from './lib/curveInfo.js';

const KEY = 'show-radial-menu';
const ANIMATION_KEY = 'snap-animation';
const CURVE_KEY = 'snap-animation-curve';

// A shortcut with no modifier cannot be committed by releasing one, so the
// gesture would only ever end on the dismissal timeout.
function isUsableShortcut(mask, keyval) {
    if (mask === 0)
        return false;
    return Gtk.accelerator_valid(keyval, mask);
}

export default class MagunettoPreferences extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        const settings = this.getSettings();

        const row = new Adw.ActionRow({
            title: 'Radial menu shortcut',
            subtitle: 'Hold to raise the menu, release to snap',
        });

        const label = new Gtk.ShortcutLabel({valign: Gtk.Align.CENTER});
        const sync = () => {
            label.accelerator = settings.get_strv(KEY)[0] ?? '';
        };
        settings.connect(`changed::${KEY}`, sync);
        sync();

        row.add_suffix(label);
        row.activatable_widget = label;
        row.connect('activated', () => this._capture(window, settings));

        const group = new Adw.PreferencesGroup();
        group.add(row);

        const page = new Adw.PreferencesPage();
        page.add(group);
        page.add(this._snapGroup(settings));
        window.add(page);
    }

    _snapGroup(settings) {
        const group = new Adw.PreferencesGroup({title: 'Snapping'});

        const animate = new Adw.SwitchRow({
            title: 'Animate',
            subtitle: 'Show the window travelling to its new region',
        });
        settings.bind(ANIMATION_KEY, animate, 'active', Gio.SettingsBindFlags.DEFAULT);
        group.add(animate);

        const style = new Adw.ComboRow({
            title: 'Style',
            model: Gtk.StringList.new(CURVE_KEYS.map(key => CURVES[key].label)),
        });

        // The subtitle is the whole point of the row: it says what the selection
        // will look like, so the styles can be compared without trying each one.
        // Set from the selection rather than from the notify handler, which does
        // not fire when the stored style is already the one shown.
        const showSelected = () => {
            const key = CURVE_KEYS[style.selected] ?? DEFAULT_CURVE;
            style.subtitle = CURVES[key].description;
            return key;
        };

        style.connect('notify::selected', () => {
            const key = showSelected();
            if (settings.get_string(CURVE_KEY) !== key)
                settings.set_string(CURVE_KEY, key);
        });

        const syncStyle = () => {
            const index = CURVE_KEYS.indexOf(settings.get_string(CURVE_KEY));
            style.selected = index === -1 ? CURVE_KEYS.indexOf(DEFAULT_CURVE) : index;
            showSelected();
        };
        settings.connect(`changed::${CURVE_KEY}`, syncStyle);
        syncStyle();

        // The style is inert while the animation is off.
        settings.bind(ANIMATION_KEY, style, 'sensitive', Gio.SettingsBindFlags.GET);
        group.add(style);

        return group;
    }

    _capture(parent, settings) {
        const dialog = new Adw.AlertDialog({
            heading: 'Press a shortcut',
            body: 'The shortcut must include a modifier key.',
        });
        dialog.add_response('cancel', 'Cancel');

        const controller = new Gtk.EventControllerKey();
        controller.connect('key-pressed', (_c, keyval, _keycode, state) => {
            const mask = state & Gtk.accelerator_get_default_mod_mask();

            if (keyval === Gdk.KEY_Escape && mask === 0) {
                dialog.close();
                return Gdk.EVENT_STOP;
            }
            if (!isUsableShortcut(mask, keyval))
                return Gdk.EVENT_STOP;

            settings.set_strv(KEY, [Gtk.accelerator_name(keyval, mask)]);
            dialog.close();
            return Gdk.EVENT_STOP;
        });
        dialog.add_controller(controller);
        dialog.present(parent);
    }
}
