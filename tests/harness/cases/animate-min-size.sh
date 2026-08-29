# A window that will not shrink to its region never acks the size it was offered,
# so the report the travel waits on never arrives. It still has to travel, and it
# still has to be left updating.

case_body() {
    open_test_window --title "Min size" --min-width 900 --min-height 700 >/dev/null
    warp 640 400

    begin_gesture
    flick -240 -240
    release_gesture
    assert_travels "the window travels towards its quarter"
    settle_travel

    assert_contains "$(mg_log)" "snapped:top-left" "the snap committed"
    assert_eq "$(work_area_field 1)" "$(frame_field 1)" "it sits at the quarter's origin"
    assert_at_rest "the actor is back at rest"
    assert_eq "0" "$(mg_ghosts)" "no snapshot left behind"

    # A window left frozen would report the old geometry for ever.
    warp 640 400
    begin_gesture; flick 300 0; end_gesture
    assert_ne "$(work_area_field 1)" "$(frame_field 1)" "it can still be moved afterwards"
}
