# Opposite quarters are inset on both axes: the outer gap on the sides that touch
# the work area, and one inner gap between them horizontally and vertically.
CASE_OUTER_GAP=8
CASE_INNER_GAP=12

case_body() {
    open_test_window --title "Gap top-left" >/dev/null
    warp 640 400
    begin_gesture; flick -200 -200; end_gesture
    assert_contains "$(mg_log)" "snapped:top-left" "first window took the top-left quarter"

    local ax ay aw ah tx ty tw th
    ax=$(work_area_field 1); ay=$(work_area_field 2)
    aw=$(work_area_field 3); ah=$(work_area_field 4)
    tx=$(frame_field 1); ty=$(frame_field 2); tw=$(frame_field 3); th=$(frame_field 4)

    assert_eq "$(( ax + CASE_OUTER_GAP ))" "$tx" "quarter is the outer gap from the left edge"
    assert_eq "$(( ay + CASE_OUTER_GAP ))" "$ty" "quarter is the outer gap from the top edge"

    open_test_window --title "Gap bottom-right" >/dev/null
    warp 640 400
    begin_gesture; flick 200 200; end_gesture
    assert_contains "$(mg_log)" "snapped:bottom-right" "second window took the bottom-right quarter"

    local bx by bw bh
    bx=$(frame_field 1); by=$(frame_field 2); bw=$(frame_field 3); bh=$(frame_field 4)
    assert_eq "$CASE_INNER_GAP" "$(( bx - (tx + tw) ))" "quarters are the inner gap apart horizontally"
    assert_eq "$CASE_INNER_GAP" "$(( by - (ty + th) ))" "quarters are the inner gap apart vertically"
    assert_eq "$(( ax + aw - CASE_OUTER_GAP ))" "$(( bx + bw ))" "quarter is the outer gap from the right edge"
    assert_eq "$(( ay + ah - CASE_OUTER_GAP ))" "$(( by + bh ))" "quarter is the outer gap from the bottom edge"
}
