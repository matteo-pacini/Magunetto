// The harness's control surface, injected into a running shell rather than
// shipped. run.sh imports this file by absolute path through the shell's own
// evaluation interface and calls init(); the extension neither knows about it
// nor cooperates.
//
// It lives inside the shell because assertions cannot come from outside one: the
// gesture needs a modifier held down while the pointer moves, which nothing
// outside the compositor can do on Wayland, and the window introspection
// interface reports no geometry.
//
// It is not part of the extension because it need not be. Synthesising input is
// how GNOME Shell's own tests drive the compositor, but shipping the ability to
// do so over the session bus is not something any other extension does.

import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';

// Carried rather than imported: a module loaded by absolute path resolves its
// relative imports against its own directory, so it cannot reach into the
// extension. Renaming the snapshot actor without changing this here would make
// every ghost assertion read zero and pass vacuously, which animate-ghosts.sh
// exists to catch.
const SNAPSHOT_NAME = 'magunetto-snapshot';

export const BUS_NAME = 'dev.matteopacini.Magunetto.Test';
export const OBJECT_PATH = '/dev/matteopacini/Magunetto/Test';
const EXTENSION_UUID = 'magunetto@matteopacini.me';

const INTERFACE = `
<node>
  <interface name="dev.matteopacini.Magunetto.Test">
    <method name="TargetFrame">
      <arg type="(iiii)" direction="out" name="rect"/>
    </method>
    <method name="FocusedFrame">
      <arg type="(iiii)" direction="out" name="rect"/>
    </method>
    <method name="WorkArea">
      <arg type="(iiii)" direction="out" name="rect"/>
    </method>
    <method name="Key">
      <arg type="u" direction="in" name="keyval"/>
      <arg type="b" direction="in" name="press"/>
    </method>
    <method name="Warp">
      <arg type="d" direction="in" name="x"/>
      <arg type="d" direction="in" name="y"/>
    </method>
    <method name="Move">
      <arg type="d" direction="in" name="dx"/>
      <arg type="d" direction="in" name="dy"/>
    </method>
    <method name="ActorTransform">
      <arg type="(dddd)" direction="out" name="transform"/>
    </method>
    <method name="ClearLog"/>
    <property name="Log" type="s" access="read"/>
    <property name="OverlayUp" type="b" access="read"/>
    <property name="GrabHeld" type="b" access="read"/>
    <property name="Ghosts" type="u" access="read"/>
  </interface>
</node>`;

const EMPTY_RECT = [-1, -1, -1, -1];

// A scale of -1 cannot occur, so it distinguishes "no actor to report on" from
// an actor sitting at rest.
const NO_TRANSFORM = [0, 0, -1, -1];

function frameOf(window) {
    if (!window)
        return EMPTY_RECT;

    const rect = window.get_frame_rect();
    return [rect.x, rect.y, rect.width, rect.height];
}

export class TestInterface {
    constructor(extension) {
        this._extension = extension;

        const seat = global.stage.context.get_backend().get_default_seat();
        this._keyboard = seat.create_virtual_device(Clutter.InputDeviceType.KEYBOARD_DEVICE);
        this._pointer = seat.create_virtual_device(Clutter.InputDeviceType.POINTER_DEVICE);

        this._dbus = Gio.DBusExportedObject.wrapJSObject(INTERFACE, this);
        this._dbus.export(Gio.DBus.session, OBJECT_PATH);
    }

    destroy() {
        this._dbus?.unexport();
        this._dbus = null;
        this._keyboard = null;
        this._pointer = null;
        this._extension = null;
    }

    get Log() {
        return JSON.stringify(this._extension.log);
    }

    get OverlayUp() {
        return this._extension.isOverlayUp;
    }

    get GrabHeld() {
        return this._extension.isGrabHeld;
    }

    // Snapshots left behind after an animation are invisible to every other
    // assertion here: they sit above the windows and change no geometry.
    get Ghosts() {
        return Main.uiGroup.get_children()
            .filter(child => child.name === SNAPSHOT_NAME).length;
    }

    ClearLog() {
        this._extension.clearLog();
    }

    // The animation moves the actor, not the window, so it is invisible to
    // TargetFrame: the frame rect is final from the moment the snap is applied.
    ActorTransform() {
        const actor = this._extension.targetWindow?.get_compositor_private();
        if (!actor)
            return NO_TRANSFORM;

        return [actor.translation_x, actor.translation_y, actor.scale_x, actor.scale_y];
    }

    TargetFrame() {
        return frameOf(this._extension.targetWindow);
    }

    FocusedFrame() {
        return frameOf(global.display.get_focus_window());
    }

    WorkArea() {
        const window = this._extension.targetWindow ?? global.display.get_focus_window();
        const monitor = window ? window.get_monitor() : global.display.get_primary_monitor();
        const area = global.workspace_manager.get_active_workspace()
            .get_work_area_for_monitor(monitor);

        return [area.x, area.y, area.width, area.height];
    }

    Key(keyval, press) {
        this._keyboard.notify_keyval(
            GLib.get_monotonic_time(),
            keyval,
            press ? Clutter.KeyState.PRESSED : Clutter.KeyState.RELEASED);
    }

    Warp(x, y) {
        this._pointer.notify_absolute_motion(GLib.get_monotonic_time(), x, y);
    }

    Move(dx, dy) {
        this._pointer.notify_relative_motion(GLib.get_monotonic_time(), dx, dy);
    }
}

// Entry point for the injection. Finds the extension instead of being built by
// it, so nothing in the shipped code refers to any of this.
export function init() {
    const extension = Main.extensionManager.lookup(EXTENSION_UUID)?.stateObj;
    if (!extension)
        throw new Error(`${EXTENSION_UUID} is not loaded; nothing to hook`);

    globalThis.magunettoHook?.destroy();
    globalThis.magunettoHook = new TestInterface(extension);
    return 'hooked';
}
