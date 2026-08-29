# Not a test: records one snap per travel style, for the README's comparison grid.
# Run with: tests/harness/run.sh _curves
#
# The clips land in .harness/curve-<key>.webm. Turn them into the README's assets
# with tests/harness/curves-encode.sh.
#
# One snap, identical for all seven — same window, same distance, same target —
# because anything that varies between them stops the grid being a comparison.
# The tour belongs to the hero demo above the grid, which shows the default style
# in use; this shows what each style does to a single travel.
#
# All seven are recorded in one session rather than one session each. The curve
# is read at commit time, so setting it on the extension's own settings object
# between takes is enough, and a session boot costs more than the clip.
#
# 60fps, not the 30 a gesture demo would need: a travel lasts 220ms, which is
# seven frames at 30 and thirteen at 60. Seven cannot distinguish an ease that is
# nearly over by its midpoint from one that overshoots.

CASE_ANIMATION=true

# The window starts small and left of the target, so the snap both moves and
# resizes it. A snap eases translation and scale separately, and scale is the
# whole difference between Spring and Overshoot — they share a translation ease
# and differ only in whether the size overshoots with it. A start rect that
# merely mirrors the target exercises neither that difference nor half the code.
START_RECT="80, 180, 420, 320"

set_curve() {
    shell_eval "Main.extensionManager.lookup('$UUID').stateObj._settings
        .set_string('snap-animation-curve', '$1')" >/dev/null
    [ "$(eval_value "Main.extensionManager.lookup('$UUID').stateObj._settings
        .get_string('snap-animation-curve')")" = "$1" ]
}

focused_rect() {
    eval_value "(r => [r.x, r.y, r.width, r.height].join(' '))(
        global.display.get_focus_window().get_frame_rect())"
}

# Checked rather than assumed: an Eval that throws still answers, so a window
# left where the previous take snapped it would record a clip of nothing
# happening. A resize is not reported until the client acks the configure, so
# this waits for the rectangle rather than sleeping and hoping.
reset_window() {
    shell_eval "let w = global.display.get_focus_window();
        w.move_resize_frame(true, $START_RECT);
        'ok'" >/dev/null

    local want=${START_RECT//,/}
    if ! wait_until "[ \"\$(focused_rect)\" = \"$want\" ]" 5; then
        echo "      wanted [$want], got [$(focused_rect)]" >&2
        return 1
    fi
}

case_body() {
    silence_banners

    open_test_window --title "Magunetto" >/dev/null
    warp 640 400
    settle

    local key
    for key in $(curve_keys); do
        set_curve "$key" || { fail "could not select $key"; return 1; }
        reset_window || { fail "$key: window did not return to the start rect"; return 1; }

        start_recording "$ARTIFACT_DIR/curve-$key" 60 || return 1
        sleep 0.6

        warp 290 340
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
        echo "      $key -> $(focused_rect)" >&2
    done
}
