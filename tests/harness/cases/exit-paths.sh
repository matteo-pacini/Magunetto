# Every way a gesture can end must release the grab and leave the desktop usable.
#
# The timeout path needs a shortcut with no modifier, so it lives in
# no-modifier.sh rather than here.

case_body() {
    open_test_window --title "Exits" >/dev/null

    # 1. commit
    warp 640 400
    begin_gesture; flick 300 0; end_gesture
    assert_eq "false" "$(mg_bool GrabHeld)" "grab released after commit"

    # 2. cancel
    warp 640 400
    begin_gesture
    key_press $KEY_Escape; key_release $KEY_Escape; settle
    end_gesture
    assert_eq "false" "$(mg_bool GrabHeld)" "grab released after cancel"

    # 3. release with nothing selected
    warp 640 400
    begin_gesture; end_gesture
    assert_eq "false" "$(mg_bool GrabHeld)" "grab released after an empty gesture"

    # 4. the actor being destroyed underneath the gesture
    warp 640 400
    begin_gesture
    assert_eq "true" "$(mg_bool OverlayUp)" "menu is up before destroying it"
    # The menu holds key focus while it is modal.
    shell_eval 'global.stage.get_key_focus().destroy(); String(1)' >/dev/null
    settle
    end_gesture
    assert_eq "false" "$(mg_bool GrabHeld)" "grab released when the actor is destroyed"
    assert_eq "0" "$(eval_value 'String(Main.modalCount)')" "no modal grab left on the shell"

    # Input must still reach the desktop: a fresh gesture has to work.
    mg ClearLog >/dev/null
    warp 640 400
    begin_gesture; flick 300 0; end_gesture
    assert_contains "$(mg_log)" "snapped:right" "gestures still work after every exit path"
}
