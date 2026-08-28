# A shortcut with no modifier can never be committed by a release, so the menu
# must dismiss itself on a timeout.
CASE_SHORTCUT="['F9']"

case_body() {
    open_test_window --title "NoMods" >/dev/null
    warp 640 400
    ensure_normal_mode

    key_press $KEY_F9
    key_release $KEY_F9
    settle

    assert_eq "true" "$(mg_bool OverlayUp)" "menu opened without a modifier"

    sleep 2.2
    assert_contains "$(mg_log)" "timed-out" "menu dismissed itself on the timeout"
    assert_eq "false" "$(mg_bool OverlayUp)" "menu gone after the timeout"
    assert_eq "false" "$(mg_bool GrabHeld)" "grab released after the timeout"
}
