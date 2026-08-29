# The monitor is chosen when the menu opens and not reconsidered. Pointer motion
# that crosses onto the next monitor mid-gesture selects a sector; it does not
# retarget the window.
CASE_MONITORS="1280x800,1280x800"

case_body() {
    open_test_window --title "Latch" >/dev/null
    shell_eval 'global.display.get_focus_window().move_to_monitor(1); "moved"' >/dev/null
    settle

    local mon_x
    mon_x=$(eval_value 'String(global.display.get_monitor_geometry(1).x)')

    # Near enough to the seam that a leftward flick carries the pointer onto the
    # first monitor: nothing pins it there, unlike the outer edge of the union.
    warp $(( mon_x + 80 )) 400

    begin_gesture
    flick -300 0
    assert_contains "$(mg_log)" "select:left" "left sector selected"
    assert_eq "true" "$(eval_value 'String(global.get_pointer()[0] < global.display.get_monitor_geometry(1).x)')" \
        "the flick carried the pointer onto the first monitor"
    end_gesture

    assert_eq "1" "$(eval_value 'String(global.display.get_focus_window().get_monitor())')" \
        "window stayed on the monitor the gesture began on"
    assert_eq "$(monitor_work_area_field 1 1)" "$(frame_field 1)" \
        "window took that monitor's left half"
}
