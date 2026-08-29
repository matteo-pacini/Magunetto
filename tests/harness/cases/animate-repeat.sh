# Snapping to the region the window already occupies changes no geometry, so the
# compositor reports nothing at all. A travel armed for a report that never comes
# would hold the window frozen until it timed out.

case_body() {
    open_test_window --title "Repeat travel" >/dev/null
    warp 640 400

    begin_gesture; flick -300 0; end_gesture
    local first
    first=$(mg_rect TargetFrame)

    warp 640 400
    begin_gesture
    flick -300 0
    release_gesture
    assert_no_travel "nothing travels when nothing moves"
    settle_travel

    assert_eq "$first" "$(mg_rect TargetFrame)" "the window stayed put"
    assert_eq "0" "$(mg_ghosts)" "no snapshot was left"

    # The freeze is refcounted: an unpaired one stops the window updating for good.
    warp 640 400
    begin_gesture; flick 300 0; end_gesture
    assert_eq "$(( $(work_area_field 1) + $(work_area_field 3) / 2 ))" "$(frame_field 1)" \
        "a later snap still lands"
}
