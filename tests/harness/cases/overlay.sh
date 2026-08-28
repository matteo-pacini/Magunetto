# The menu is actually drawn, and the drawing changes with the selection.

case_body() {
    open_test_window --title "Overlay" >/dev/null
    warp 640 400

    local dir="$ARTIFACT_DIR/overlay"
    mkdir -p "$dir"

    begin_gesture
    screenshot "$dir/deadzone.png"

    flick 300 0
    screenshot "$dir/right.png"

    flick -600 0
    screenshot "$dir/left.png"

    end_gesture

    for shot in deadzone right left; do
        if [ -s "$dir/$shot.png" ]; then
            pass "screenshot captured while the menu was up ($shot)"
        else
            fail "no screenshot for $shot"
        fi
    done

    # Different selections must not render identically.
    if cmp -s "$dir/right.png" "$dir/left.png"; then
        fail "selecting a different sector did not change what is drawn"
    else
        pass "the highlighted sector changes what is drawn"
    fi
    if cmp -s "$dir/deadzone.png" "$dir/right.png"; then
        fail "selecting a sector did not change the menu"
    else
        pass "selecting a sector changes the menu"
    fi
}
