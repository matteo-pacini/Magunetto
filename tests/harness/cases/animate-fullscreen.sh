# Leaving fullscreen is the other size change the shell animates for itself.

case_body() {
    open_test_window --title "Fullscreen" >/dev/null
    warp 640 400
    shell_eval 'let w = global.display.get_focus_window(); w.make_fullscreen(); "ok"' >/dev/null
    settle

    begin_gesture
    flick -300 0
    release_gesture
    assert_travels "the fullscreen window travels to the left half"

    assert_eq "false" \
        "$(eval_value 'String(!!global.get_window_actors()[0].__animationInfo)')" \
        "the shell is not animating it too"

    settle_travel
    assert_eq "$(work_area_field 2)" "$(frame_field 2)" "it lands inside the work area"
    assert_at_rest "the actor is back at rest"
    assert_eq "0" "$(mg_ghosts)" "no snapshot left behind"
}
