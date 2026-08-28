# A window closing mid-gesture is handled without an exception.

case_body() {
    open_test_window --title "Doomed" >/dev/null
    warp 640 400

    begin_gesture
    flick 300 0

    pkill -f "$HARNESS_DIR/testwindow.js"
    wait_until "[ \"\$(window_count)\" = 0 ]" 10

    end_gesture
    assert_contains "$(mg_log)" "target-gone" "the vanished window was noticed"
    assert_not_contains "$(mg_log)" "snapped:" "nothing was snapped"
}
