# A short flick selects the centre action, which fills the work area.

case_body() {
    open_test_window --title "Centre" >/dev/null
    warp 640 400

    begin_gesture
    flick 30 0
    assert_contains "$(mg_log)" "select:centre" "short movement selects the centre action"
    end_gesture

    assert_contains "$(mg_log)" "snapped:centre" "centre action committed"
    assert_eq "$(mg_rect WorkArea)" "$(mg_rect TargetFrame)" "window fills the work area"
}
