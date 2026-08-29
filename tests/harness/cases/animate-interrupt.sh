# A second gesture while the first is still travelling. The actor carries the
# transform of a running travel, so a second one that did not clear it first
# would compose the two and strand the window.

case_body() {
    open_test_window --title "Interrupt" >/dev/null
    warp 640 400

    begin_gesture; flick -300 0; release_gesture
    assert_travels "the first travel starts"

    # No settle: the second gesture lands while the first is still running.
    warp 640 400
    begin_gesture
    flick 300 0
    end_gesture

    assert_contains "$(mg_log)" "snapped:right" "the second snap committed"
    assert_eq "$(( $(work_area_field 1) + $(work_area_field 3) / 2 ))" "$(frame_field 1)" \
        "the window is on the right half"
    assert_at_rest "the actor is back at rest"
    assert_eq "0" "$(mg_ghosts)" "no snapshot left behind"
}
