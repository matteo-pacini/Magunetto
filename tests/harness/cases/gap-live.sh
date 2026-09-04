# A gap changed while the extension is enabled applies to the next gesture. The
# values are read as a gesture begins rather than cached, so nothing has to be
# reloaded.
#
# This is the one gap case that writes to the settings mid-session, as _curves.sh
# does for the travel style, and it restores the profile's value before it ends:
# the session is shared with the other gap cases, and one of them running after
# this with a stray value would fail for a reason that is not in its file.
CASE_OUTER_GAP=8
CASE_INNER_GAP=12

LIVE_INNER=40

set_inner_gap() {
    shell_eval "Main.extensionManager.lookup('$UUID').stateObj._settings
        .set_int('snap-inner-gap', $1)" >/dev/null
    [ "$(eval_value "Main.extensionManager.lookup('$UUID').stateObj._settings
        .get_int('snap-inner-gap')")" = "$1" ]
}

case_body() {
    open_test_window --title "Gap live" >/dev/null
    warp 640 400

    set_inner_gap $LIVE_INNER || fail "could not set the inner gap"

    begin_gesture; flick 300 0; end_gesture
    assert_contains "$(mg_log)" "snapped:right" "the gesture committed"

    local ax aw usable
    ax=$(work_area_field 1); aw=$(work_area_field 3)
    usable=$(( aw - 2 * CASE_OUTER_GAP - LIVE_INNER ))
    assert_eq "$(( ax + CASE_OUTER_GAP + usable / 2 + LIVE_INNER ))" "$(frame_field 1)" \
        "the seam uses the value set after the extension was enabled"

    set_inner_gap $CASE_INNER_GAP || fail "could not restore the inner gap"
}
