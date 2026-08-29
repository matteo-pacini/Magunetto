# The outline belongs to the monitor the gesture was made on, not the one holding
# the window. It follows the gesture's monitor by construction rather than by
# looking one up, which is exactly the kind of thing a refactor quietly undoes.
CASE_MONITORS="1280x800,1280x800"

case_body() {
    open_test_window --title "Preview cross" >/dev/null
    shell_eval 'global.display.get_focus_window().move_to_monitor(0); "moved"' >/dev/null
    settle
    assert_eq "0" "$(eval_value 'String(global.display.get_focus_window().get_monitor())')" \
        "window starts on the first monitor"

    local mon_x
    mon_x=$(eval_value 'String(global.display.get_monitor_geometry(1).x)')
    warp $(( mon_x + 640 )) 400

    begin_gesture
    flick 300 0
    settle_travel

    assert_eq "$(( $(monitor_work_area_field 1 1) + $(monitor_work_area_field 1 3) / 2 ))" \
        "$(preview_field 1)" "the outline is on the monitor the gesture was made on"

    end_gesture
    assert_eq "-1" "$(preview_field 1)" "nothing left outlined after the commit"
}
