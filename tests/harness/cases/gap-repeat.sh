# With gaps set, applying the same sector twice leaves the window in the same
# place: the gaps are measured from the work area, not from where the window is.
CASE_OUTER_GAP=8
CASE_INNER_GAP=12

case_body() {
    open_test_window --title "Gap repeat" >/dev/null
    warp 640 400

    begin_gesture; flick 300 0; end_gesture
    local first
    first=$(mg_rect TargetFrame)
    assert_ne "$(mg_rect WorkArea)" "$first" "the first snap was inset"

    warp 640 400
    begin_gesture; flick 300 0; end_gesture

    assert_eq "$first" "$(mg_rect TargetFrame)" "second snap matches the first"
}
