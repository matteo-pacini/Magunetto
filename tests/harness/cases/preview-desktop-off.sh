# Turning off desktop animations takes the motion out of the preview, not the
# preview itself. The shell zeroes every easing duration, so the outline appears
# at its region rather than sliding to it — but where the window will land is
# information, not decoration, and it is still shown.
#
# The obvious implementation suppresses the preview alongside the travel, which
# this catches.

CASE_DESKTOP_ANIMATIONS=false

case_body() {
    open_test_window --title "Preview desktop off" >/dev/null
    warp 640 400

    begin_gesture
    flick 300 0
    settle

    assert_eq "$(( $(work_area_field 1) + $(work_area_field 3) / 2 ))" "$(preview_field 1)" \
        "the region is still outlined with desktop animations off"

    end_gesture
    assert_eq "-1" "$(preview_field 1)" "nothing left outlined after the commit"
}
