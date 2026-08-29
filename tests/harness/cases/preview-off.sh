# The preference suppresses the outline and nothing else: the menu still shows the
# selection, and committing places the window exactly where it would have.
CASE_PREVIEW=false

case_body() {
    open_test_window --title "Preview off" >/dev/null
    warp 640 400

    begin_gesture
    flick 300 0
    settle_travel

    assert_eq "-1" "$(preview_field 1)" "no region is outlined"
    assert_contains "$(mg_log)" "select:right" "the menu still reports the selection"

    end_gesture
    assert_contains "$(mg_log)" "snapped:right" "the gesture committed"
    assert_eq "$(( $(work_area_field 1) + $(work_area_field 3) / 2 ))" "$(frame_field 1)" \
        "the window took the right half regardless"
}
