# The desktop's own animation switch zeroes every easing duration in the shell,
# so it overrides this extension's preference. It would break silently: nothing
# in the extension reads the setting, so only a test can catch a regression.

CASE_DESKTOP_ANIMATIONS=false

case_body() {
    open_test_window --title "Desktop off" >/dev/null
    warp 640 400

    begin_gesture
    flick -300 0
    release_gesture
    assert_no_travel "the actor never leaves rest"
    settle_travel

    assert_contains "$(mg_log)" "snapped:left" "the snap still happened"
    assert_eq "$(( $(work_area_field 3) / 2 ))" "$(frame_field 3)" "it lands exactly on the half"
    assert_eq "$(work_area_field 1)" "$(frame_field 1)" "at the correct origin"
    assert_eq "0" "$(mg_ghosts)" "nothing left over"
}
