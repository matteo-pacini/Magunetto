# Not a test: drives a full tour of every sector and captures frames for a demo.
# Run with: tests/harness/run.sh _demo

FRAME=0
case_body() {
    local dir="$ARTIFACT_DIR/demo"
    mkdir -p "$dir"

    frame() {
        FRAME=$((FRAME + 1))
        screenshot "$(printf '%s/%03d.png' "$dir" "$FRAME")"
    }

    open_test_window --title "Magunetto" >/dev/null
    warp 640 400
    frame; frame

    tour() { # dx dy label
        warp 640 400
        begin_gesture
        frame
        flick "$1" "$2"
        frame; frame
        end_gesture
        frame; frame
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

    frame
    echo "      captured $FRAME frames in $dir" >&2
}
