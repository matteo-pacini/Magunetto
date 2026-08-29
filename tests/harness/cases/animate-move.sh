# Snapping between two regions of the same size is a pure move: the compositor
# reports it synchronously and never reports it again. A travel driven only by
# the later report would never start.

case_body() {
    open_test_window --title "Move" >/dev/null
    warp 640 400

    # Left half first, so the next snap changes position but not size.
    begin_gesture; flick -300 0; end_gesture
    assert_contains "$(mg_log)" "snapped:left" "parked on the left half"
    local width
    width=$(frame_field 3)

    warp 640 400
    begin_gesture
    flick 300 0
    release_gesture
    assert_travels "the window travels to the right half"
    settle_travel

    assert_eq "$width" "$(frame_field 3)" "the two halves are the same width"
    assert_eq "$(( $(work_area_field 1) + $(work_area_field 3) / 2 ))" "$(frame_field 1)" \
        "it lands exactly on the right half"
    assert_at_rest "the actor is back at rest"
    assert_eq "0" "$(mg_ghosts)" "no snapshot left behind"
}
