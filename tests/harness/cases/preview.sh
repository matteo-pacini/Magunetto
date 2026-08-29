# The region a gesture would place the window in is outlined while the menu is up,
# and the outline follows the selection.

case_body() {
    open_test_window --title "Preview" >/dev/null
    warp 640 400

    begin_gesture
    assert_eq "-1" "$(preview_field 1)" "nothing outlined in the dead zone"

    flick 300 0
    settle_travel
    assert_eq "$(( $(work_area_field 1) + $(work_area_field 3) / 2 ))" "$(preview_field 1)" \
        "the right half is outlined"
    assert_eq "$(( $(work_area_field 3) / 2 ))" "$(preview_field 3)" \
        "outline is half the work area wide"

    # The outline follows the selection rather than being drawn once.
    flick -600 0
    settle_travel
    assert_eq "$(work_area_field 1)" "$(preview_field 1)" \
        "outline moved to the left half"

    # Back inside the dead zone, releasing would place nothing, so nothing is shown.
    flick 300 0
    settle_travel
    assert_eq "-1" "$(preview_field 1)" "outline withdrawn back in the dead zone"

    flick -300 0
    end_gesture
    assert_contains "$(mg_log)" "snapped:left" "the gesture committed"
    assert_eq "-1" "$(preview_field 1)" "nothing left outlined after the commit"
}
