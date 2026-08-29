# Helpers available to harness case files. Sourced by run.sh; not executable on
# its own.

TEST_IFACE=dev.matteopacini.Magunetto.Test
TEST_PATH=/dev/matteopacini/Magunetto/Test

# --- talking to the extension -------------------------------------------------

mg() {
    local method=$1; shift
    gdbus call --session -d org.gnome.Shell -o "$TEST_PATH" \
        -m "$TEST_IFACE.$method" -- "$@"
}

mg_prop() {
    gdbus call --session -d org.gnome.Shell -o "$TEST_PATH" \
        -m org.freedesktop.DBus.Properties.Get "$TEST_IFACE" "$1"
}

# Numbers only, space separated: "(( 640, 32, 640, 768),)" -> "640 32 640 768"
mg_rect() {
    mg "$1" | tr -dc '0-9,-' | tr ',' ' ' | xargs
}

mg_log() {
    mg_prop Log | sed -e "s/^(<'//" -e "s/'>,)$//"
}

# The animation moves the actor, not the window, so it is invisible to mg_rect.
# "(((0.0, 0.0, 1.0, 1.0),),)" -> "0.0 0.0 1.0 1.0"
mg_xform() {
    mg ActorTransform | tr -dc '0-9.,-' | tr ',' ' ' | xargs
}

# True while the actor sits at rest: no offset, no scaling.
mg_at_rest() {
    [ "$(mg_xform)" = "0.0 0.0 1.0 1.0" ]
}

# "(<uint32 0>,)" -> "0". The type name carries digits of its own, so the value
# has to be cut out rather than filtered for.
mg_ghosts() {
    mg_prop Ghosts | sed -e 's/.*uint32 //' -e 's/[^0-9].*//'
}

mg_bool() {
    case "$(mg_prop "$1")" in
        *true*) echo true ;;
        *) echo false ;;
    esac
}

shell_eval() {
    gdbus call --session -d org.gnome.Shell -o /org/gnome/Shell \
        -m org.gnome.Shell.Eval "$1"
}

# Eval answers "(true, '<json>')". Unwrap it to the bare value so conditions can
# match what the expression returned rather than the call-succeeded flag.
eval_value() {
    shell_eval "$1" | sed -e "s/^(true, '//" -e "s/')$//" -e 's/^"//' -e 's/"$//'
}

eval_true() {
    [ "$(eval_value "$1")" = "true" ]
}

# --- input --------------------------------------------------------------------

key_press()   { mg Key "$1" true  >/dev/null; }
key_release() { mg Key "$1" false >/dev/null; }

KEY_Super_L=65515
KEY_Control_L=65507
KEY_Alt_L=65513
KEY_Escape=65307
KEY_space=32
KEY_z=122

# The first absolute warp after a virtual pointer device is created drops one
# coordinate, so the opening warp of a run is always issued twice.
warp() {
    mg Warp "$1" "$2" >/dev/null
    if [ "${_warped:-}" != yes ]; then
        mg Warp "$1" "$2" >/dev/null
        _warped=yes
    fi
    settle
}

move_pointer() { mg Move "$1" "$2" >/dev/null; settle; }

# Give the compositor a turn to process what was just injected.
settle() {
    shell_eval 'true' >/dev/null 2>&1
    sleep 0.15
}

# --- the shell hook -------------------------------------------------------------

# Loads shellhook.js into the running shell and waits for its interface to
# answer. The extension ships nothing of this: everything the cases call is
# exported from here, by a module the shell imports at our request.
#
# The import is a promise, and a promise fired into Eval reports nothing — a
# failing import answers `(true, '"requested"')` exactly like a working one. So
# the outcome is stashed where a second call can read it, and the object path is
# polled before any case runs.
install_hook() {
    local hook=$HARNESS_DIR/shellhook.js

    shell_eval "
        globalThis.magunettoHookResult = 'pending';
        import('file://$hook')
            .then(m => { globalThis.magunettoHookResult = String(m.init()); })
            .catch(e => { globalThis.magunettoHookResult = 'failed: ' + e; });
        'requested'" >/dev/null

    if ! wait_until "mg WorkArea >/dev/null 2>&1" 15; then
        echo "  the shell hook never answered: $(eval_value 'String(globalThis.magunettoHookResult)')"
        return 1
    fi
    return 0
}

# --- recording ----------------------------------------------------------------

# Screenshots cannot show the snap animation: one costs a good part of the 220ms
# the travel lasts, so a tour assembled from them catches a frame or two of motion
# at best. A screencast records at the compositor's own rate.
#
# The service ties a recording to the D-Bus connection that asked for it, and
# `gdbus call` exits the moment its call returns — which ends the recording with
# "Sender has vanished". Asking from inside the shell makes the shell the sender,
# and the shell is still there when the recording is stopped.
start_recording() {
    local template=$1
    # 30 is enough for a gesture. A single travel lasts 220ms, so anything that
    # means to show the shape of one needs more frames than that yields.
    local framerate=${2:-30}

    shell_eval "
        const {Gio: G, GLib: L} = imports.gi;
        global._mgRecBus = G.DBus.session;
        global._mgRecFile = null;
        global._mgRecBus.call('org.gnome.Shell.Screencast', '/org/gnome/Shell/Screencast',
            'org.gnome.Shell.Screencast', 'Screencast',
            new L.Variant('(sa{sv})', ['$template', {
                'framerate': new L.Variant('i', $framerate),
                'draw-cursor': new L.Variant('b', true),
            }]),
            null, G.DBusCallFlags.NONE, -1, null,
            (src, res) => {
                const [ok, used] = src.call_finish(res).deepUnpack();
                global._mgRecFile = ok ? used : '';
            });
        'requested'" >/dev/null

    if ! wait_until "[ -n \"\$(eval_value 'String(global._mgRecFile)')\" ] && \
                     [ \"\$(eval_value 'String(global._mgRecFile)')\" != null ]" 15; then
        fail "the recording never started"
        return 1
    fi

    RECORDING_FILE=$(eval_value 'String(global._mgRecFile)')
    [ -n "$RECORDING_FILE" ] || { fail "the recording was refused"; return 1; }
    return 0
}

stop_recording() {
    shell_eval "
        global._mgRecBus.call('org.gnome.Shell.Screencast', '/org/gnome/Shell/Screencast',
            'org.gnome.Shell.Screencast', 'StopScreencast', null,
            null, imports.gi.Gio.DBusCallFlags.NONE, -1, null, null);
        'stopping'" >/dev/null

    # The file is still being muxed when the call returns.
    wait_until "[ -s '$RECORDING_FILE' ]" 15
    sleep 1.5
}

# --- windows ------------------------------------------------------------------

# With no windows open the shell falls back to the overview, which holds a modal
# grab and keeps any window that maps afterwards from taking focus.
hide_overview() {
    eval_true 'String(Main.overview.visible)' || return 0
    shell_eval 'Main.overview.hide()' >/dev/null
    wait_until "[ \"\$(eval_value 'String(Main.overview.visible)')\" = false ]" 10
}

# Keybindings registered for NORMAL are filtered while the shell is in any other
# action mode, so tests must confirm the mode before injecting a shortcut.
ensure_normal_mode() {
    hide_overview
    wait_until "[ \"\$(eval_value 'String(Main.actionMode)')\" = 1 ]" 5
}

window_count() {
    eval_value 'String(global.get_window_actors().length)'
}

open_test_window() {
    local before
    before=$(window_count)

    env ${MAGUNETTO_TYPELIB_PATH:+GI_TYPELIB_PATH="$MAGUNETTO_TYPELIB_PATH"} \
        gjs -m "$HARNESS_DIR/testwindow.js" "$@" >>"$SESSION_DIR/windows.log" 2>&1 &
    local pid=$!

    if ! wait_until "[ \"\$(window_count)\" -gt $before ]" 20; then
        fail "test window never appeared (still $(window_count) windows)"
        return 1
    fi
    hide_overview

    # Synthetic input earlier in the run counts as user activity, so a window
    # mapping afterwards loses the focus-stealing race and opens unfocused.
    # Activating it explicitly is what a user clicking it would achieve.
    shell_eval 'let w = global.get_window_actors().at(-1).meta_window;
                w.activate(global.get_current_time()); "activated"' >/dev/null

    if ! wait_until "eval_true 'String(!!global.display.get_focus_window())'" 20; then
        fail "test window appeared but never took focus"
        echo "      windows=$(window_count)" \
             "overview=$(eval_value 'String(Main.overview.visible)')" \
             "modal=$(eval_value 'String(Main.modalCount)')" \
             "focusApp=$(eval_value 'String(Shell.WindowTracker.get_default().focus_app)')" >&2
        return 1
    fi
    settle
    ensure_normal_mode
    echo "$pid"
}

close_all_windows() {
    pkill -f "$HARNESS_DIR/testwindow.js" 2>/dev/null || true
    wait_until "[ \"\$(eval_value 'String(global.get_window_actors().length)')\" = 0 ]" || true
}

# --- assertions ---------------------------------------------------------------

CASE_FAILURES=0

fail() {
    CASE_FAILURES=$((CASE_FAILURES + 1))
    echo "    FAIL: $*" >&2
}

pass() {
    echo "    ok: $*" >&2
}

assert_eq() {
    if [ "$1" = "$2" ]; then
        pass "$3"
    else
        fail "$3 (expected '$1', got '$2')"
    fi
}

assert_ne() {
    if [ "$1" != "$2" ]; then
        pass "$3"
    else
        fail "$3 (both were '$1')"
    fi
}

assert_contains() {
    case "$1" in
        *"$2"*) pass "$3" ;;
        *) fail "$3 (no '$2' in '$1')" ;;
    esac
}

# The travel lasts a fifth of a second and changes no geometry, so it can only be
# caught while it runs. A case that looked only afterwards would pass whether the
# window travelled or appeared.
assert_travels() {
    local deadline=$((SECONDS + 3)) seen
    while [ "$SECONDS" -lt "$deadline" ]; do
        seen=$(mg_xform)
        if [ "$seen" != "0.0 0.0 1.0 1.0" ]; then
            pass "$1 (moved to $seen)"
            return 0
        fi
        sleep 0.02
    done
    fail "$1 (the actor never left rest)"
}

assert_no_travel() {
    local deadline=$((SECONDS + 1)) seen
    while [ "$SECONDS" -lt "$deadline" ]; do
        seen=$(mg_xform)
        if [ "$seen" != "0.0 0.0 1.0 1.0" ]; then
            fail "$1 (the actor moved to $seen)"
            return 1
        fi
        sleep 0.05
    done
    pass "$1"
}

assert_at_rest() {
    assert_eq "0.0 0.0 1.0 1.0" "$(mg_xform)" "$1"
}

assert_not_contains() {
    case "$1" in
        *"$2"*) fail "$3 (unexpected '$2' in '$1')" ;;
        *) pass "$3" ;;
    esac
}

# Retry a shell condition until it holds or the timeout expires.
wait_until() {
    local condition=$1 deadline=$((SECONDS + ${2:-10}))
    while [ "$SECONDS" -lt "$deadline" ]; do
        if eval "$condition" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.2
    done
    return 1
}

# --- gestures -----------------------------------------------------------------

KEY_F9=65478

# The default shortcut is <Alt>z, so Alt is the modifier whose release commits.
begin_gesture() {
    ensure_normal_mode
    key_press $KEY_Alt_L
    key_press $KEY_z
    key_release $KEY_z
    settle
}

end_gesture() {
    release_gesture
    settle_travel
}

# end_gesture waits the travel out, so it is no use to a case that needs to see
# the travel happening. Those release the modifier themselves, sample, then settle.
release_gesture() {
    key_release $KEY_Alt_L
}

settle_travel() {
    settle
    sleep 0.4
}

flick() { move_pointer "$1" "$2"; }

work_area_field() { mg_rect WorkArea | cut -d' ' -f"$1"; }
frame_field()     { mg_rect TargetFrame | cut -d' ' -f"$1"; }

# --- recording helpers shared by the demo cases -------------------------------

# The travel styles, in the order curveInfo.js declares them, so anything that
# iterates them cannot fall behind the table that defines them.
curve_keys() {
    node -e "import('$REPO_DIR/magunetto@matteopacini.me/lib/curveInfo.js')
        .then(m => console.log(m.CURVE_KEYS.join(' ')))"
}

# Starting a screencast raises a notification, and it does not land in the same
# place in every take — it appears inside some clips and not others, which reads
# as the recording differing when only the banner does.
silence_banners() {
    shell_eval "new imports.gi.Gio.Settings({schema_id: 'org.gnome.desktop.notifications'})
        .set_boolean('show-banners', false); 'ok'" >/dev/null
}
