# The centre action fills the work area inset by the outer gap alone. The inner
# gap is set and must not show: there is no neighbour to be apart from.
CASE_OUTER_GAP=8
CASE_INNER_GAP=12

case_body() {
    open_test_window --title "Gap centre" >/dev/null
    warp 640 400
    begin_gesture; flick 30 0; end_gesture
    assert_contains "$(mg_log)" "snapped:centre" "centre action committed"

    assert_eq "$(( $(work_area_field 1) + CASE_OUTER_GAP ))" "$(frame_field 1)" \
        "window is the outer gap from the left edge"
    assert_eq "$(( $(work_area_field 2) + CASE_OUTER_GAP ))" "$(frame_field 2)" \
        "window is the outer gap from the top edge"
    assert_eq "$(( $(work_area_field 3) - 2 * CASE_OUTER_GAP ))" "$(frame_field 3)" \
        "window is the outer gap from the right edge, and the inner gap plays no part"
    assert_eq "$(( $(work_area_field 4) - 2 * CASE_OUTER_GAP ))" "$(frame_field 4)" \
        "window is the outer gap from the bottom edge"
}
