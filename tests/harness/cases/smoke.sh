# The harness can reach the extension, read its state, and drive a window.

case_body() {
    assert_eq "[]" "$(mg_log)" "state log starts empty for each case"
    assert_eq "false" "$(mg_bool OverlayUp)" "no overlay before any gesture"

    open_test_window --title "Smoke" >/dev/null
    assert_ne "-1 -1 -1 -1" "$(mg_rect FocusedFrame)" "focused window reports a frame"
    assert_ne "-1 -1 -1 -1" "$(mg_rect WorkArea)" "work area is readable"
}
