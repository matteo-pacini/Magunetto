# The gesture belongs to the monitor holding the pointer, not the one holding the
# window: a window is snapped onto the monitor the gesture was made on.
CASE_MONITORS="1280x800,1280x800"

case_body() {
    open_test_window --title "Cross" >/dev/null
    shell_eval 'global.display.get_focus_window().move_to_monitor(0); "moved"' >/dev/null
    settle
    assert_eq "0" "$(eval_value 'String(global.display.get_focus_window().get_monitor())')" \
        "window starts on the first monitor"

    local mon_x
    mon_x=$(eval_value 'String(global.display.get_monitor_geometry(1).x)')
    warp $(( mon_x + 640 )) 400

    begin_gesture; flick 300 0; end_gesture
    assert_contains "$(mg_log)" "snapped:right" "the gesture committed"

    assert_eq "1" "$(eval_value 'String(global.display.get_focus_window().get_monitor())')" \
        "window moved to the monitor the gesture was made on"
    assert_eq "$(( $(monitor_work_area_field 1 1) + $(monitor_work_area_field 1 3) / 2 ))" \
        "$(frame_field 1)" "geometry computed against that monitor's work area"
}
