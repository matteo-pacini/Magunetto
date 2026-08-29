# Disabling the extension while a window is still travelling.
#
# A travel outlives the gesture that started it, and holds a timeout source, two
# signal connections, a frozen actor and a widget in the shell's own group — none
# of it reachable from the objects the extension tears down. The freeze is the one
# that matters: an unpaired one is permanent, and the window never updates again.
#
# The hook cannot see any of this. It reaches the actor through the extension's
# target window, which disable() clears, so this case reads the actor directly.

CASE_ANIMATION=true

actor_xform() {
    eval_value "(a => a ? [a.translation_x.toFixed(1), a.translation_y.toFixed(1),
        a.scale_x.toFixed(3), a.scale_y.toFixed(3)].join(' ') : 'no-actor')(
        global.get_window_actors()[0])"
}

snapshots() {
    eval_value "String(Main.uiGroup.get_children()
        .filter(c => c.name === 'magunetto-snapshot').length)"
}

case_body() {
    open_test_window --title "Disabled mid-travel" >/dev/null
    warp 640 400

    begin_gesture
    flick -300 0
    release_gesture

    # The snapshot exists only while the travel runs, so it is how the case knows
    # it caught one rather than arriving after it landed.
    local caught=0 deadline=$((SECONDS + 3))
    while [ "$SECONDS" -lt "$deadline" ]; do
        if [ "$(snapshots)" -gt 0 ]; then
            caught=1
            break
        fi
    done
    assert_eq "1" "$caught" "a travel was caught in flight"

    gnome-extensions disable "$UUID"

    assert_eq "0.0 0.0 1.000 1.000" "$(actor_xform)" "the actor is put back at rest"
    assert_eq "0" "$(snapshots)" "the snapshot is gone"

    # An unpaired freeze() reports nothing at all; the only way to see one is to
    # move the window and find that it did not.
    assert_eq "moved" "$(eval_value "(w => {
        const r = w.get_frame_rect();
        w.move_frame(true, r.x + 40, r.y);
        return w.get_frame_rect().x === r.x + 40 ? 'moved' : 'frozen';
    })(global.get_window_actors()[0].meta_window)")" "the actor was thawed"

    # This session is shared with every case after it.
    gnome-extensions enable "$UUID"
    wait_until "gnome-extensions info '$UUID' | grep -q ACTIVE" 15 \
        || fail "the extension did not come back"
    wait_until "mg WorkArea >/dev/null 2>&1" 10 \
        || fail "the hook stopped answering after re-enabling"
}
