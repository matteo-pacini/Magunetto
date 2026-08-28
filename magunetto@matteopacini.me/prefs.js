import Adw from 'gi://Adw';
import Gdk from 'gi://Gdk';
import Gtk from 'gi://Gtk';
import {ExtensionPreferences} from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';

const KEY = 'show-radial-menu';

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
        window.add(page);
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
