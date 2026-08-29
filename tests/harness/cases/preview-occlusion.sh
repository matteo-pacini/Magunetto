# The outline has to be seen, not merely to exist.
#
# TilePreview.open() lowers itself below the window actor, which is what the shell
# wants while a window is being dragged elsewhere. This gesture leaves the window
# where it is, so a region overlapping it hid the outline completely.
#
# Every other preview case asserts a rectangle, and every one of them passed while
# nothing was visible: occlusion is not expressible as a rectangle. This asserts
# the stacking order instead.

z_order() {
    eval_value "(() => {
        const kids = global.window_group.get_children();
        const preview = kids.findIndex(c => c.constructor.name.includes('TilePreview'));
        const actor = kids.indexOf(global.display.get_focus_window().get_compositor_private());
        return preview + ' ' + actor;
    })()"
}

case_body() {
    open_test_window --title "Occlusion" >/dev/null
    warp 640 400

    # Put the window on the right half, so the next gesture's region falls inside it.
    begin_gesture; flick 300 0; end_gesture
    assert_eq "$(( $(work_area_field 1) + $(work_area_field 3) / 2 ))" "$(frame_field 1)" \
        "window occupies the right half"

    # The bottom-right quarter is wholly inside the right half the window now fills.
    begin_gesture
    flick 240 240
    settle_travel
    assert_contains "$(mg_log)" "select:bottom-right" "a region inside the window is selected"

    local order preview actor
    order=$(z_order)
    preview=${order%% *}
    actor=${order##* }
    assert_ne "-1" "$preview" "the preview widget is in the shell's window group"

    if [ "$preview" -gt "$actor" ]; then
        pass "the outline is stacked above the window it overlaps"
    else
        fail "the outline is behind the window (preview at $preview, window at $actor)"
    fi

    end_gesture
}
