# The snapshot's name is spelled in two places: lib/animate.js sets it, and
# harness/shellhook.js counts it. The hook cannot import the constant, because a
# module loaded by absolute path resolves relative imports against its own
# directory.
#
# Every other case asserts the count is zero. If the two spellings ever drift
# apart the count is zero always, and all of them keep passing while asserting
# nothing. This one asserts a snapshot exists while a window is travelling, so
# the drift fails the suite instead.

case_body() {
    open_test_window --title "Ghosts" >/dev/null
    warp 640 400

    begin_gesture
    flick -300 0
    release_gesture

    # The crossfade lasts as long as the travel does, and starts with it.
    local seen=0 deadline=$((SECONDS + 3))
    while [ "$SECONDS" -lt "$deadline" ]; do
        if [ "$(mg_ghosts)" -gt 0 ]; then
            seen=1
            break
        fi
        sleep 0.02
    done
    assert_eq "1" "$seen" "a snapshot is drawn while the window travels"

    settle_travel
    assert_eq "0" "$(mg_ghosts)" "and is gone once it lands"
}
