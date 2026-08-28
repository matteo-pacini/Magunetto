# The window acted on is the one focused when the gesture began.

case_body() {
    open_test_window --title "First" >/dev/null
    local first
    first=$(eval_value 'String(global.display.get_focus_window().get_id())')
    warp 640 400

    begin_gesture
    assert_eq "$first" "$(eval_value 'String(Main.magunettoTarget ?? global.display.get_focus_window().get_id())')" \
        "gesture began on the focused window"

    flick 300 0
    end_gesture
    assert_contains "$(mg_log)" "snapped:right" "the original window was snapped"
}
