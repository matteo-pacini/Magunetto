# Not a test: records one clip per travel style, for the README's comparison grid.
# Run with: tests/harness/run.sh _curves
#
# The clips land in .harness/curve-<key>.webm. Turn them into the README's assets
# with tests/harness/curves-encode.sh.
#
# All seven are recorded in one session rather than one session each, because the
# curve is read at commit time — so setting it on the extension's own settings
# object between takes is enough, and a session boot costs more than the clip.
#
# 60fps, not the 30 a gesture demo uses: a travel lasts 220ms, which is seven
# frames at 30 and thirteen at 60. Seven cannot show the difference between an
# ease that is nearly over by its midpoint and one that overshoots.

CASE_ANIMATION=true

CURVE_KEYS="expo quint md cubic quad spring back"

# The window starts on the left and snaps right, so the travel is as long as the
# work area allows. Its leading edge stays on screen throughout, which is what
# makes an overshoot visible: the trailing styles carry it past the target and
# back, and only an edge that is not clipped can show that.
START_RECT="0, 32, 620, 736"

set_curve() {
    shell_eval "Main.extensionManager.lookup('$UUID').stateObj._settings
        .set_string('snap-animation-curve', '$1')" >/dev/null
    [ "$(eval_value "Main.extensionManager.lookup('$UUID').stateObj._settings
        .get_string('snap-animation-curve')")" = "$1" ]
}

# Checked rather than assumed: an Eval that throws still answers, so a window
# left where the previous take snapped it would record seven clips of nothing
# happening.
reset_window() {
    shell_eval "let w = global.display.get_focus_window();
        w.move_resize_frame(true, $START_RECT);
        'ok'" >/dev/null

    # A resize is not reported until the client acks the configure, so this waits
    # for the rectangle rather than sleeping and hoping. Read from the focused
    # window, not from TargetFrame — that reports the window a gesture acted on,
    # and answers -1 -1 -1 -1 until one has.
    local want=${START_RECT//,/}
    if ! wait_until "[ \"\$(focused_rect)\" = \"$want\" ]" 5; then
        echo "      wanted [$want], got [$(focused_rect)]" >&2
        return 1
    fi
}

focused_rect() {
    eval_value "(r => [r.x, r.y, r.width, r.height].join(' '))(
        global.display.get_focus_window().get_frame_rect())"
}

case_body() {
    open_test_window --title "Magunetto" >/dev/null
    warp 640 400
    settle

    local key
    for key in $CURVE_KEYS; do
        set_curve "$key" || { fail "could not select $key"; return 1; }
        reset_window || { fail "$key: window did not return to the start rect"; return 1; }

        start_recording "$ARTIFACT_DIR/curve-$key" 60 || return 1
        sleep 0.6

        warp 320 400
        begin_gesture
        sleep 0.2
        # One jump, not a sweep: the gesture is not the subject here, the travel
        # is, and a slow sweep would be most of the clip.
        mg Move 300 0 >/dev/null
        sleep 0.3
        release_gesture
        # The travel is 220ms; the rest is long enough to read as having landed.
        sleep 0.8

        stop_recording
        echo "      $key -> $(mg_rect TargetFrame)" >&2
    done
}
