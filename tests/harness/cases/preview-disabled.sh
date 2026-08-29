# Disabling the extension while the menu is up, with a region outlined.
#
# TilePreview.close() only fades and hides; the widget stays parented to the
# shell's own window group until something destroys it. Nothing the extension
# tears down reaches it, so disable() has to do it by hand.
#
# The hook cannot see this. PreviewRect reaches the widget through the extension,
# which disable() drops, so this case counts the widgets in the shell's group.

previews() {
    eval_value "String(global.window_group.get_children()
        .filter(c => c.constructor.name.includes('TilePreview')).length)"
}

case_body() {
    open_test_window --title "Disabled mid-preview" >/dev/null
    warp 640 400

    begin_gesture
    flick 300 0
    settle_travel
    assert_ne "-1" "$(preview_field 1)" "a region is outlined before disabling"
    assert_eq "1" "$(previews)" "the preview widget is in the shell's group"

    gnome-extensions disable "$UUID"
    settle

    assert_eq "0" "$(previews)" "the preview widget is gone after disable()"

    # This session is shared with every case after it.
    gnome-extensions enable "$UUID"
    wait_until "gnome-extensions info '$UUID' | grep -q ACTIVE" 15 \
        || fail "the extension did not come back"
    wait_until "mg WorkArea >/dev/null 2>&1" 10 \
        || fail "the hook stopped answering after re-enabling"
}
