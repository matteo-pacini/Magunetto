# Maximised and fullscreen state is cleared before placing.

case_body() {
    open_test_window --title "Maxed" >/dev/null
    warp 640 400

    shell_eval 'global.display.get_focus_window().maximize(); "maximised"' >/dev/null
    settle
    assert_eq "true" "$(eval_value 'String(global.display.get_focus_window().is_maximized())')" \
        "window starts maximised"

    begin_gesture
    flick 300 0
    end_gesture

    assert_contains "$(mg_log)" "snapped:right" "maximised window was snapped"
    assert_eq "false" "$(eval_value 'String(global.display.get_focus_window().is_maximized())')" \
        "window is no longer maximised"
    assert_eq "$(( $(work_area_field 1) + $(work_area_field 3) / 2 ))" "$(frame_field 1)" \
        "window took the right half"
}

