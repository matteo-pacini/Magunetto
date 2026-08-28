# A diagonal flick selects a corner quarter.

case_body() {
    open_test_window --title "Quarter" >/dev/null
    warp 640 400

    begin_gesture
    flick 200 200
    assert_contains "$(mg_log)" "select:bottom-right" "diagonal selects the bottom-right sector"
    end_gesture

    assert_contains "$(mg_log)" "snapped:bottom-right" "quarter committed"

    local ax ay aw ah
    ax=$(work_area_field 1); ay=$(work_area_field 2)
    aw=$(work_area_field 3); ah=$(work_area_field 4)
    assert_eq "$(( ax + aw / 2 ))" "$(frame_field 1)" "quarter starts at the horizontal midpoint"
    assert_eq "$(( ay + ah / 2 ))" "$(frame_field 2)" "quarter starts at the vertical midpoint"
}
