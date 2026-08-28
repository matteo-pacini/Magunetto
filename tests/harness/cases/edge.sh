# A gesture beginning against a screen edge can still reach the sector pointing
# off that edge.

case_body() {
    open_test_window --title "Edge" >/dev/null
    warp 1279 400

    begin_gesture
    flick 300 0
    assert_contains "$(mg_log)" "select:right" "right sector reachable from the right edge"
    end_gesture

    assert_contains "$(mg_log)" "snapped:right" "snapped despite starting at the edge"
}
