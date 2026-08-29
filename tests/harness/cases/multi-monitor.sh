# Pointer and window on the same monitor: the gesture is made where the window
# already is, so the menu and the resulting geometry both stay there. The
# cross-monitor cases cover the gesture being made anywhere else.
CASE_MONITORS="1280x800,1280x800"

case_body() {
    assert_eq "2" "$(eval_value 'String(Main.layoutManager.monitors.length)')" "two monitors present"

    open_test_window --title "Second" >/dev/null
    shell_eval 'global.display.get_focus_window().move_to_monitor(1); "moved"' >/dev/null
    settle
    assert_eq "1" "$(eval_value 'String(global.display.get_focus_window().get_monitor())')" \
        "window is on the second monitor"

    local mon_x
    mon_x=$(eval_value 'String(global.display.get_monitor_geometry(1).x)')
    warp $(( mon_x + 640 )) 400

    begin_gesture; flick 300 0; end_gesture
    assert_contains "$(mg_log)" "snapped:right" "window on the second monitor was snapped"

    assert_eq "1" "$(eval_value 'String(global.display.get_focus_window().get_monitor())')" \
        "window stayed on its monitor"
    assert_eq "$(( $(work_area_field 1) + $(work_area_field 3) / 2 ))" "$(frame_field 1)" \
        "geometry computed against that monitor's work area"
}
