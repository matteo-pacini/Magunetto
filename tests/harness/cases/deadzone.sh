# Releasing without moving selects nothing and leaves the window alone.

case_body() {
    open_test_window --title "Deadzone" >/dev/null
    warp 640 400
    local before
    before=$(mg_rect FocusedFrame)

    begin_gesture
    end_gesture

    assert_contains "$(mg_log)" "no-selection" "nothing was selected"
    assert_not_contains "$(mg_log)" "snapped:" "no snap happened"
    assert_eq "$before" "$(mg_rect FocusedFrame)" "window geometry unchanged"
}
