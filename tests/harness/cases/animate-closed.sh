# A window closing mid-travel. Its snapshot sits above the windows and changes no
# geometry, so nothing else here would notice one that outlived its window.

case_body() {
    open_test_window --title "Closing" >/dev/null
    warp 640 400

    begin_gesture
    flick -300 0
    release_gesture
    assert_travels "the travel starts"

    close_all_windows
    settle_travel

    assert_eq "0" "$(mg_ghosts)" "the snapshot went with the window"
    assert_eq "0" "$(window_count)" "the window is gone"
}
