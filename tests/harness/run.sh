#!/usr/bin/env bash
#
# Boots a headless GNOME Shell with the extension loaded and runs the harness
# cases against it.
#
#   tests/harness/run.sh [case-name ...]
#
# Everything runs under a throwaway home: the settings database is a file keyed
# by the home directory rather than by the message bus, so a session sharing the
# developer's home would write to their real desktop configuration.

set -uo pipefail

HARNESS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$HARNESS_DIR/../.." && pwd)
UUID=magunetto@matteopacini.me

# shellcheck source=lib.sh
source "$HARNESS_DIR/lib.sh"

DEFAULT_MONITORS=1280x800
DEFAULT_SHORTCUT="['<Alt>z']"
DEFAULT_ANIMATION=true
DEFAULT_PREVIEW=true
DEFAULT_OUTER_GAP=0
DEFAULT_INNER_GAP=0
DEFAULT_CURVE="'quint'"
# The desktop's own switch, which zeroes every easing duration in the shell.
DEFAULT_DESKTOP_ANIMATIONS=true

ARTIFACT_DIR=${MAGUNETTO_ARTIFACTS:-$REPO_DIR/.harness}
rm -rf "$ARTIFACT_DIR"
mkdir -p "$ARTIFACT_DIR"

TOTAL_FAILURES=0
SESSION_DIR=
SESSION_PROFILE=
SHELL_PID=

cleanup() {
    stop_session
    [ -n "${ROOT_DIR:-}" ] && rm -rf "$ROOT_DIR"
}
trap cleanup EXIT

ROOT_DIR=$(mktemp -d)

# --- session lifecycle --------------------------------------------------------

stop_session() {
    [ -z "$SESSION_DIR" ] && return 0
    close_all_windows 2>/dev/null || true
    if [ -n "$SHELL_PID" ]; then
        kill "$SHELL_PID" 2>/dev/null
        wait "$SHELL_PID" 2>/dev/null
    fi
    SHELL_PID=
    SESSION_DIR=
    SESSION_PROFILE=
}

start_session() {
    local monitors=$1 shortcut=$2 animation=$3 curve=$4 desktop_animations=$5 preview=$6
    local outer_gap=$7 inner_gap=$8

    SESSION_DIR=$(mktemp -d "$ROOT_DIR/session.XXXXXX")
    mkdir -p "$SESSION_DIR/data/gnome-shell/extensions" "$SESSION_DIR/config"
    ln -sfn "$REPO_DIR/$UUID" "$SESSION_DIR/data/gnome-shell/extensions/$UUID"

    export HOME=$SESSION_DIR
    export XDG_DATA_HOME=$SESSION_DIR/data
    export XDG_CONFIG_HOME=$SESSION_DIR/config
    export XDG_CACHE_HOME=$SESSION_DIR/cache
    export WAYLAND_DISPLAY="magunetto-$$"
    export GDK_BACKEND=wayland
    unset _warped

    # There is no dconf service in a bare session, so GSettings would fall back to
    # a per-process memory backend and silently discard every write. The keyfile
    # backend gives the shell and the harness one settings store they both see.
    export GSETTINGS_BACKEND=keyfile
    mkdir -p "$SESSION_DIR/config/glib-2.0/settings"
    cat > "$SESSION_DIR/config/glib-2.0/settings/keyfile" <<KEYFILE
[org/gnome/shell]
disable-extension-version-validation=true

[org/gnome/desktop/interface]
enable-hot-corners=false
enable-animations=$desktop_animations

[org/gnome/shell/extensions/magunetto]
show-radial-menu=$shortcut
snap-animation=$animation
snap-preview=$preview
snap-animation-curve=$curve
snap-outer-gap=$outer_gap
snap-inner-gap=$inner_gap
KEYFILE

    local args=(--headless --unsafe-mode --wayland-display "magunetto-$$")
    local spec
    for spec in ${monitors//,/ }; do
        args+=(--virtual-monitor "$spec")
    done

    gnome-shell "${args[@]}" >"$SESSION_DIR/shell.log" 2>&1 &
    SHELL_PID=$!

    if ! wait_until "[ \"\$(eval_value 'String(Main.layoutManager._startingUp)')\" = false ]" 60; then
        echo "  shell did not become ready; last log lines:"
        tail -5 "$SESSION_DIR/shell.log" | sed 's/^/    /'
        return 1
    fi


    gnome-extensions enable "$UUID"
    if ! wait_until "gnome-extensions info '$UUID' | grep -q ACTIVE" 15; then
        echo "  extension never became ACTIVE"
        grep -E 'JS ERROR|Gjs-CRITICAL' "$SESSION_DIR/shell.log" | head -3 | sed 's/^/    /'
        return 1
    fi

    # The shell starts with the overview showing, which keeps focus tracking from
    # settling until it is dismissed.
    shell_eval 'Main.overview.hide()' >/dev/null
    wait_until "[ \"\$(eval_value 'String(Main.overview.visible)')\" = false ]" 10

    if ! install_hook; then
        echo "  the shell hook could not be installed"
        return 1
    fi

    SESSION_PROFILE="$monitors|$shortcut|$animation|$curve|$desktop_animations|$preview|$outer_gap|$inner_gap"
    return 0
}

ensure_session() {
    local wanted="$1|$2|$3|$4|$5|$6|$7|$8"
    [ "$SESSION_PROFILE" = "$wanted" ] && return 0
    stop_session
    start_session "$@"
}

# --- running cases ------------------------------------------------------------

screenshot() {
    shell_eval "true" >/dev/null
    gdbus call --session -d org.gnome.Shell -o /org/gnome/Shell/Screenshot \
        -m org.gnome.Shell.Screenshot.Screenshot false false "$1" >/dev/null 2>&1
}

run_case() {
    local file=$1
    local name
    name=$(basename "$file" .sh)

    # Defaults a case may override before it runs.
    CASE_MONITORS=$DEFAULT_MONITORS
    CASE_SHORTCUT=$DEFAULT_SHORTCUT
    CASE_ANIMATION=$DEFAULT_ANIMATION
    CASE_PREVIEW=$DEFAULT_PREVIEW
    CASE_CURVE=$DEFAULT_CURVE
    CASE_DESKTOP_ANIMATIONS=$DEFAULT_DESKTOP_ANIMATIONS
    CASE_OUTER_GAP=$DEFAULT_OUTER_GAP
    CASE_INNER_GAP=$DEFAULT_INNER_GAP
    unset -f case_body 2>/dev/null

    # shellcheck disable=SC1090
    source "$file"

    if ! ensure_session "$CASE_MONITORS" "$CASE_SHORTCUT" "$CASE_ANIMATION" \
                        "$CASE_CURVE" "$CASE_DESKTOP_ANIMATIONS" "$CASE_PREVIEW" \
                        "$CASE_OUTER_GAP" "$CASE_INNER_GAP"; then
        echo "  $name: SESSION FAILED"
        TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
        return
    fi

    echo "  $name"
    CASE_FAILURES=0
    local errors_before
    errors_before=$(grep -cE 'JS ERROR|Gjs-CRITICAL' "$SESSION_DIR/shell.log")

    hide_overview
    SESSION_STARTUP_LOG=$(mg_log)
    mg ClearLog >/dev/null 2>&1
    case_body

    # An exception in the extension fails the case even when every assertion held.
    local errors_after
    errors_after=$(grep -cE 'JS ERROR|Gjs-CRITICAL' "$SESSION_DIR/shell.log")
    if [ "$errors_after" -gt "$errors_before" ]; then
        fail "extension raised an exception"
        grep -E 'JS ERROR|Gjs-CRITICAL' "$SESSION_DIR/shell.log" | tail -2 | sed 's/^/      /'
    fi

    close_all_windows

    if [ "$CASE_FAILURES" -gt 0 ]; then
        screenshot "$ARTIFACT_DIR/$name.png"
        cp "$SESSION_DIR/shell.log" "$ARTIFACT_DIR/$name.log" 2>/dev/null
        cp "$SESSION_DIR/windows.log" "$ARTIFACT_DIR/$name.windows.log" 2>/dev/null
        TOTAL_FAILURES=$((TOTAL_FAILURES + CASE_FAILURES))
    fi
}

# --- main ---------------------------------------------------------------------

if [ $# -gt 0 ]; then
    CASES=()
    for name in "$@"; do
        CASES+=("$HARNESS_DIR/cases/$name.sh")
    done
else
    # Files starting with an underscore are not tests (see _demo.sh); they run
    # only when named explicitly.
    mapfile -t CASES < <(find "$HARNESS_DIR/cases" -name '*.sh' ! -name '_*' | sort)
fi

# Cases sharing a session profile run together, so the shell boots once per
# distinct profile rather than once per case.
mapfile -t CASES < <(
    for file in "${CASES[@]}"; do
        profile=$(grep -hE '^CASE_(MONITORS|SHORTCUT|ANIMATION|PREVIEW|CURVE|DESKTOP_ANIMATIONS|OUTER_GAP|INNER_GAP)=' \
            "$file" | sort | tr '\n' ' ')
        echo "$profile|$file"
    done | sort | cut -d'|' -f2-
)

started=$SECONDS
STRAY_BEFORE=$(pgrep -f "wayland-display magunetto-" 2>/dev/null | wc -l)
for file in "${CASES[@]}"; do
    run_case "$file"
done
stop_session

# Nothing may outlive the run: a stray shell would hold its socket and its monitor.
sleep 1
STRAY_AFTER=$(pgrep -f "wayland-display magunetto-" 2>/dev/null | wc -l)
if [ "$STRAY_AFTER" -gt "$STRAY_BEFORE" ]; then
    echo "  stray shell processes left behind: $STRAY_AFTER"
    TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
fi

echo
if [ "$TOTAL_FAILURES" -eq 0 ]; then
    echo "harness: all cases passed in $((SECONDS - started))s"
    exit 0
fi
echo "harness: $TOTAL_FAILURES failure(s) in $((SECONDS - started))s; artifacts in $ARTIFACT_DIR"
exit 1
