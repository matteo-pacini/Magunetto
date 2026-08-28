# Escape abandons the gesture, and a later release does not move the window.

case_body() {
    open_test_window --title "Cancel" >/dev/null
    warp 640 400
    local before
    before=$(mg_rect FocusedFrame)

    begin_gesture
    flick 300 0
    assert_contains "$(mg_log)" "select:right" "a sector was selected before cancelling"

    key_press $KEY_Escape
    key_release $KEY_Escape
    settle

    assert_contains "$(mg_log)" "cancelled" "escape cancelled the gesture"
    assert_eq "false" "$(mg_bool OverlayUp)" "menu dismissed on cancel"

    end_gesture
    assert_not_contains "$(mg_log)" "snapped:" "releasing after cancel does not snap"
    assert_eq "$before" "$(mg_rect FocusedFrame)" "window untouched after cancel"
    assert_eq "false" "$(mg_bool GrabHeld)" "grab released after cancel"
}
