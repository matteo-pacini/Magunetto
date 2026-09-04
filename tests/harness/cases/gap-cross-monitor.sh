# The gaps apply on every monitor alike: a gesture on the second monitor insets
# the window from that monitor's work area by the same values.
CASE_MONITORS="1280x800,1280x800"
CASE_OUTER_GAP=8
CASE_INNER_GAP=12

case_body() {
    open_test_window --title "Gap cross" >/dev/null
    shell_eval 'global.display.get_focus_window().move_to_monitor(0); "moved"' >/dev/null
    settle
    assert_eq "0" "$(eval_value 'String(global.display.get_focus_window().get_monitor())')" \
        "window starts on the first monitor"

    local mon_x
    mon_x=$(eval_value 'String(global.display.get_monitor_geometry(1).x)')
    warp $(( mon_x + 640 )) 400

    begin_gesture; flick 300 0; end_gesture
    assert_contains "$(mg_log)" "snapped:right" "the gesture committed"

    local mx my mw mh usable
    mx=$(monitor_work_area_field 1 1); my=$(monitor_work_area_field 1 2)
    mw=$(monitor_work_area_field 1 3); mh=$(monitor_work_area_field 1 4)
    usable=$(( mw - 2 * CASE_OUTER_GAP - CASE_INNER_GAP ))

    assert_eq "$(( mx + CASE_OUTER_GAP + usable / 2 + CASE_INNER_GAP ))" "$(frame_field 1)" \
        "window starts an inner gap past the second monitor's seam"
    assert_eq "$(( mx + mw - CASE_OUTER_GAP ))" "$(( $(frame_field 1) + $(frame_field 3) ))" \
        "window ends an outer gap short of the second monitor's right edge"
    assert_eq "$(( my + CASE_OUTER_GAP ))" "$(frame_field 2)" \
        "window is an outer gap below the second monitor's top edge"
}
