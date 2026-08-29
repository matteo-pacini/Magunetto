#!/usr/bin/env bash
#
# Opens a nested GNOME Shell in a window on your desktop with the extension
# loaded, so the menu can be driven by hand.
#
#   tests/harness/watch.sh
#
# Your own session is untouched: the nested shell runs against a throwaway home
# with its own settings store.
#
# Inside the nested window: press and hold Alt, tap X, move the mouse toward a
# direction, then release Alt to snap the focused window.
#
# X rather than the extension's own Z, so that a copy installed on the desktop
# outside does not swallow the shortcut: the outer compositor matches its own
# keybindings first, and what it matches never reaches this window.

set -uo pipefail

HARNESS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$HARNESS_DIR/../.." && pwd)
UUID=magunetto@matteopacini.me

SESSION_DIR=$(mktemp -d)
trap 'rm -rf "$SESSION_DIR"' EXIT

mkdir -p "$SESSION_DIR/data/gnome-shell/extensions" \
         "$SESSION_DIR/config/glib-2.0/settings"
ln -sfn "$REPO_DIR/$UUID" "$SESSION_DIR/data/gnome-shell/extensions/$UUID"

cat > "$SESSION_DIR/config/glib-2.0/settings/keyfile" <<KEYFILE
[org/gnome/shell]
disable-extension-version-validation=true
enabled-extensions=['$UUID']

[org/gnome/desktop/interface]
enable-hot-corners=false

[org/gnome/shell/extensions/magunetto]
show-radial-menu=['<Alt>x']
KEYFILE

export HOME=$SESSION_DIR
export XDG_DATA_HOME=$SESSION_DIR/data
export XDG_CONFIG_HOME=$SESSION_DIR/config
export XDG_CACHE_HOME=$SESSION_DIR/cache
export GSETTINGS_BACKEND=keyfile

echo "Nested shell starting. Close its window to finish."
echo "Shortcut: hold Alt, tap X, move the mouse, release."

# --devkit is GNOME 50's nested mode; --nested was removed.
dbus-run-session -- gnome-shell --devkit --wayland &
SHELL_PID=$!

sleep 6
# A window to snap, launched into the nested session.
WAYLAND_DISPLAY=$(ls "$XDG_RUNTIME_DIR" | grep -E '^wayland-[0-9]+$' | tail -1) \
GDK_BACKEND=wayland \
env ${MAGUNETTO_TYPELIB_PATH:+GI_TYPELIB_PATH="$MAGUNETTO_TYPELIB_PATH"} \
    gjs -m "$HARNESS_DIR/testwindow.js" --title "Snap me" >/dev/null 2>&1 &

wait "$SHELL_PID"
