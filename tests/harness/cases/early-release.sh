# Pressing and releasing faster than the menu can appear leaves nothing on screen.

case_body() {
    open_test_window --title "Early" >/dev/null
    warp 640 400

    ensure_normal_mode
    key_press $KEY_Alt_L
    key_press $KEY_z
    key_release $KEY_z
    key_release $KEY_Alt_L
    settle; sleep 0.5

    assert_eq "false" "$(mg_bool OverlayUp)" "no menu left on screen"
    assert_eq "false" "$(mg_bool GrabHeld)" "no grab left in place"
}
