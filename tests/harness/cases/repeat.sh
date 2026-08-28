# Applying the same sector twice leaves the window in the same place.

case_body() {
    open_test_window --title "Repeat" >/dev/null
    warp 640 400

    begin_gesture; flick 300 0; end_gesture
    local first
    first=$(mg_rect TargetFrame)

    warp 640 400
    begin_gesture; flick 300 0; end_gesture

    assert_eq "$first" "$(mg_rect TargetFrame)" "second snap matches the first"
}
