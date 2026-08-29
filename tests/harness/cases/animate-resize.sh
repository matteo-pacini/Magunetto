# Snapping to a region of a different size waits on the client acking the new
# size. Every report before that ack still carries the old one.

case_body() {
    open_test_window --title "Resize" >/dev/null
    warp 640 400

    # A quarter first, so the next snap doubles the height.
    begin_gesture; flick -240 -240; end_gesture
    assert_contains "$(mg_log)" "snapped:top-left" "parked on a quarter"
    local height
    height=$(frame_field 4)

    warp 640 400
    begin_gesture
    flick -300 0
    release_gesture
    assert_travels "the window travels to the left half"
    settle_travel

    assert_ne "$height" "$(frame_field 4)" "the half is taller than the quarter"
    assert_eq "$(work_area_field 4)" "$(frame_field 4)" "it lands on the full work area height"
    assert_at_rest "the actor is back at rest"
    assert_eq "0" "$(mg_ghosts)" "no snapshot left behind"
}
