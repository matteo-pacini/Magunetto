# A fullscreen window leaves fullscreen and takes the requested geometry.

case_body() {
    open_test_window --title "Full" >/dev/null
    warp 640 400

    shell_eval 'global.display.get_focus_window().make_fullscreen(); "fullscreen"' >/dev/null
    settle
    assert_eq "true" "$(eval_value 'String(global.display.get_focus_window().is_fullscreen())')" \
        "window starts fullscreen"

    begin_gesture
    flick 300 0
    end_gesture

    assert_contains "$(mg_log)" "snapped:right" "fullscreen window was snapped"
    assert_eq "false" "$(eval_value 'String(global.display.get_focus_window().is_fullscreen())')" \
        "window left fullscreen"
    assert_eq "$(( $(work_area_field 1) + $(work_area_field 3) / 2 ))" "$(frame_field 1)" \
        "window took the right half"
}
