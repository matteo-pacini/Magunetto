# The whole gesture: hold the shortcut, flick right, release, window snaps.

case_body() {
    open_test_window --title "Gesture" >/dev/null
    warp 640 400

    begin_gesture
    assert_contains "$(mg_log)" "keybinding-fired" "shortcut fired"
    assert_contains "$(mg_log)" "overlay-up" "menu opened"
    assert_eq "true" "$(mg_bool OverlayUp)" "overlay reports itself up"

    flick 300 0
    assert_contains "$(mg_log)" "select:right" "flicking right selects the right sector"

    end_gesture
    assert_contains "$(mg_log)" "released" "modifier release was detected"
    assert_contains "$(mg_log)" "snapped:right" "window was snapped"
    assert_eq "false" "$(mg_bool OverlayUp)" "menu dismissed after commit"
    assert_eq "false" "$(mg_bool GrabHeld)" "grab released after commit"

    local ax aw ay ah
    ax=$(work_area_field 1); aw=$(work_area_field 3)
    ay=$(work_area_field 2); ah=$(work_area_field 4)
    assert_eq "$(( ax + aw / 2 ))" "$(frame_field 1)" "window sits at the right half origin"
    assert_eq "$ay" "$(frame_field 2)" "window starts below the panel"
    assert_eq "$ah" "$(frame_field 4)" "window spans the work area height"

    # A committed gesture must not leave the dismissal timeout armed behind it.
    sleep 2
    assert_not_contains "$(mg_log)" "timed-out" "no timeout fired after the commit"
}

