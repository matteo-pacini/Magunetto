# Not a test: drives a full tour of every sector and records it.
# Run with: tests/harness/run.sh _demo
#
# The recording lands in .harness/demo.webm. Turn it into the README's assets with
# tests/harness/demo-encode.sh.

case_body() {
    open_test_window --title "Magunetto" >/dev/null
    warp 640 400
    settle

    start_recording "$ARTIFACT_DIR/demo" || return
    sleep 1

    # The pointer is drawn into the recording, so the flick reads as a gesture
    # rather than as the window moving on its own. Moving in steps makes the
    # sweep visible at 30fps; one jump would be a single frame.
    sweep() { # dx dy
        local steps=6 i
        for i in $(seq $steps); do
            mg Move "$(( $1 / steps ))" "$(( $2 / steps ))" >/dev/null
            sleep 0.02
        done
        settle
    }

    tour() { # dx dy label
        warp 640 400
        begin_gesture
        sleep 0.25
        sweep "$1" "$2"
        sleep 0.35
        release_gesture
        # Long enough for the 220ms travel to play out and be seen to land.
        sleep 0.9
        echo "      $3 -> $(mg_rect TargetFrame)" >&2
    }

    tour  340    0  "right"
    tour  240  240  "bottom-right"
    tour    0  340  "bottom"
    tour -240  240  "bottom-left"
    tour -340    0  "left"
    tour -240 -240  "top-left"
    tour    0 -340  "top"
    tour  240 -240  "top-right"
    tour   30    0  "centre"

    sleep 1
    stop_recording
    echo "      recorded $RECORDING_FILE" >&2
}
