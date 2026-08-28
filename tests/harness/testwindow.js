#!/usr/bin/env gjs -m
//
// A predictable window for harness tests. Real applications differ in how they
// negotiate size, which is the point: options here reproduce the awkward cases
// the specs call out (a minimum size larger than the target, a window that
// refuses to resize) without depending on any particular application being
// installed.
//
// Usage: testwindow.js [--title T] [--min-width W] [--min-height H]
//                      [--width W] [--height H] [--not-resizable]

import GLib from 'gi://GLib';
import Gtk from 'gi://Gtk?version=4.0';

const options = {
    title: 'Magunetto Test Window',
    width: 360,
    height: 240,
    minWidth: 0,
    minHeight: 0,
    resizable: true,
};

const argv = [...ARGV];
while (argv.length > 0) {
    const flag = argv.shift();
    switch (flag) {
    case '--title':
        options.title = argv.shift();
        break;
    case '--width':
        options.width = Number(argv.shift());
        break;
    case '--height':
        options.height = Number(argv.shift());
        break;
    case '--min-width':
        options.minWidth = Number(argv.shift());
        break;
    case '--min-height':
        options.minHeight = Number(argv.shift());
        break;
    case '--not-resizable':
        options.resizable = false;
        break;
    default:
        printerr(`unknown option: ${flag}`);
        imports.system.exit(2);
    }
}

Gtk.init();

const loop = GLib.MainLoop.new(null, false);

const window = new Gtk.Window({
    title: options.title,
    default_width: options.width,
    default_height: options.height,
    resizable: options.resizable,
});

if (options.minWidth > 0 || options.minHeight > 0) {
    // A child with a size request is what actually imposes a minimum size on the
    // toplevel; setting it on the window alone is only a default.
    window.set_child(new Gtk.Box({
        width_request: options.minWidth,
        height_request: options.minHeight,
    }));
}

window.connect('close-request', () => {
    loop.quit();
    return false;
});

window.present();
loop.run();
