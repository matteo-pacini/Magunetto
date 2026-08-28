# Windows that refuse resizing are left alone.

case_body() {
    open_test_window --title "Fixed" --not-resizable >/dev/null
    warp 640 400
    local before
    before=$(mg_rect FocusedFrame)

    begin_gesture
    assert_contains "$(mg_log)" "no-target" "a window that refuses resizing is refused"
    assert_eq "false" "$(mg_bool OverlayUp)" "no menu is raised for it"
    end_gesture

    assert_eq "$before" "$(mg_rect FocusedFrame)" "the window did not move"
}
