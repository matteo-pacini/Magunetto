# Two windows snapped to opposite halves sit the outer gap from the work area
# edges and exactly the inner gap apart. The seam is asserted from both sides:
# the left window's far edge and the right window's near edge.
CASE_OUTER_GAP=8
CASE_INNER_GAP=12

case_body() {
    open_test_window --title "Gap left" >/dev/null
    warp 640 400
    begin_gesture; flick -300 0; end_gesture
    assert_contains "$(mg_log)" "snapped:left" "first window took the left half"

    local ax ay aw ah lx ly lw lh
    ax=$(work_area_field 1); ay=$(work_area_field 2)
    aw=$(work_area_field 3); ah=$(work_area_field 4)
    lx=$(frame_field 1); ly=$(frame_field 2); lw=$(frame_field 3); lh=$(frame_field 4)

    assert_eq "$(( ax + CASE_OUTER_GAP ))" "$lx" "left window is the outer gap from the left edge"
    assert_eq "$(( ay + CASE_OUTER_GAP ))" "$ly" "left window is the outer gap from the top"
    assert_eq "$(( ah - 2 * CASE_OUTER_GAP ))" "$lh" "left window is the outer gap from the bottom"

    open_test_window --title "Gap right" >/dev/null
    warp 640 400
    begin_gesture; flick 300 0; end_gesture
    assert_contains "$(mg_log)" "snapped:right" "second window took the right half"

    local rx rw
    rx=$(frame_field 1); rw=$(frame_field 3)
    assert_eq "$CASE_INNER_GAP" "$(( rx - (lx + lw) ))" "the two windows are the inner gap apart"
    assert_eq "$(( ax + aw - CASE_OUTER_GAP ))" "$(( rx + rw ))" \
        "right window is the outer gap from the right edge"
    assert_eq "$(( ay + CASE_OUTER_GAP ))" "$(frame_field 2)" "right window is the outer gap from the top"
}
