# The outline shows the inset region, and the window then lands exactly on it.
# Both come from one function, so this is the case that fails if either caller
# stops passing the gaps.
CASE_OUTER_GAP=8
CASE_INNER_GAP=12

case_body() {
    open_test_window --title "Gap preview" >/dev/null
    warp 640 400

    begin_gesture
    flick 300 0
    settle_travel

    local ax aw usable outlined
    ax=$(work_area_field 1); aw=$(work_area_field 3)
    usable=$(( aw - 2 * CASE_OUTER_GAP - CASE_INNER_GAP ))
    assert_eq "$(( ax + CASE_OUTER_GAP + usable / 2 + CASE_INNER_GAP ))" "$(preview_field 1)" \
        "the outline starts an inner gap past the seam"
    assert_eq "$(( usable - usable / 2 ))" "$(preview_field 3)" \
        "the outline is the gapped half's width"
    outlined=$(mg_rect PreviewRect)

    end_gesture
    assert_contains "$(mg_log)" "snapped:right" "the gesture committed"
    assert_eq "$outlined" "$(mg_rect TargetFrame)" "the window landed on the outlined region"
}
