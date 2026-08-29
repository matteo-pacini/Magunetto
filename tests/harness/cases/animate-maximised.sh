# Clearing maximised state is a size change the shell animates itself. Only one
# travel may be in charge of the move, and it must be ours.

case_body() {
    open_test_window --title "Maximised" >/dev/null
    warp 640 400
    shell_eval 'let w = global.display.get_focus_window(); w.maximize(3); "ok"' >/dev/null
    settle

    begin_gesture
    flick -300 0
    release_gesture
    assert_travels "the maximised window travels to the left half"

    # The shell hangs its own animation off the actor; ours leaves it untouched.
    assert_eq "false" \
        "$(eval_value 'String(!!global.get_window_actors()[0].__animationInfo)')" \
        "the shell is not animating it too"

    settle_travel
    assert_eq "$(( $(work_area_field 3) / 2 ))" "$(frame_field 3)" "it lands on the half"
    assert_at_rest "the actor is back at rest"
    assert_eq "0" "$(mg_ghosts)" "no snapshot left behind"
}
