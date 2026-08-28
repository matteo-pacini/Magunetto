# A window whose minimum size exceeds the target still moves to the right origin.

case_body() {
    open_test_window --title "Big" --min-width 900 --min-height 700 >/dev/null
    warp 640 400

    begin_gesture; flick 300 0; end_gesture
    assert_contains "$(mg_log)" "snapped:right" "constrained window was snapped"

    local expected
    expected=$(( $(work_area_field 1) + $(work_area_field 3) / 2 ))
    assert_eq "$expected" "$(frame_field 1)" "window moved to the requested origin"
}
