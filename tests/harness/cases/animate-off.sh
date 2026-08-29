# With the animation turned off, the window is placed and nothing moves.

CASE_ANIMATION=false

case_body() {
    open_test_window --title "No animation" >/dev/null
    warp 640 400

    begin_gesture
    flick -300 0
    release_gesture
    assert_no_travel "the actor never leaves rest"
    settle_travel

    assert_contains "$(mg_log)" "snapped:left" "the snap still happened"
    assert_eq "$(( $(work_area_field 3) / 2 ))" "$(frame_field 3)" "it occupies the half"
    assert_eq "0" "$(mg_ghosts)" "no snapshot was taken"
}
