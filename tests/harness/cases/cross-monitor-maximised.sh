# A maximised window is cleared and sent across: unmaximising restores it on the
# monitor it started from, and the placement that follows still has to land on the
# monitor the gesture was made on.
CASE_MONITORS="1280x800,1280x800"

case_body() {
    open_test_window --title "MaxedCross" >/dev/null
    shell_eval 'let w = global.display.get_focus_window();
                w.move_to_monitor(0); w.maximize(); "maximised"' >/dev/null
    settle
    assert_eq "true" "$(eval_value 'String(global.display.get_focus_window().is_maximized())')" \
        "window starts maximised on the first monitor"

    local mon_x
    mon_x=$(eval_value 'String(global.display.get_monitor_geometry(1).x)')
    warp $(( mon_x + 640 )) 400

    begin_gesture; flick 300 0; end_gesture

    assert_contains "$(mg_log)" "snapped:right" "the gesture committed"
    assert_eq "false" "$(eval_value 'String(global.display.get_focus_window().is_maximized())')" \
        "window is no longer maximised"
    assert_eq "1" "$(eval_value 'String(global.display.get_focus_window().get_monitor())')" \
        "window moved to the monitor the gesture was made on"
    assert_eq "$(( $(monitor_work_area_field 1 1) + $(monitor_work_area_field 1 3) / 2 ))" \
        "$(frame_field 1)" "window took that monitor's right half"
}
