// Test-only control surface. Exported solely when MAGUNETTO_TEST is set in the
// environment, because it can synthesise input and would be a capability leak in
// a normal session.
//
// It exists because assertions cannot come from outside the shell: the shell's
// evaluation and screenshot interfaces are restricted to allowlisted callers,
// and the window introspection interface reports no geometry. It also exists
// because the virtual-machine test tier cannot hold a modifier down while moving
// the pointer, so even there the gesture is driven through here.

import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {SNAPSHOT_NAME} from './animate.js';

export const BUS_NAME = 'dev.matteopacini.Magunetto.Test';
export const OBJECT_PATH = '/dev/matteopacini/Magunetto/Test';

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
