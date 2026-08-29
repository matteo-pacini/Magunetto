#!/usr/bin/env bash
#
# Builds every artefact a release ships, into dist/.
#
#   nix develop --command packaging/build.sh
#
#   dist/magunetto@matteopacini.me.shell-extension.zip   any distro, by hand
#   dist/gnome-shell-extension-magunetto_<v>_all.deb     Debian, Ubuntu
#   dist/gnome-shell-extension-magunetto-<v>-1.noarch.rpm  Fedora, openSUSE
#   dist/gnome-shell-extension-magunetto-<v>-1-any.pkg.tar.zst  Arch
#
# Nothing here talks to a package repository. The files are attached to the
# GitHub release and installed directly, which needs no account anywhere and no
# trust in a third party's build.
#
# The deb, rpm and pacman packages all come from the same staged tree, so they
# cannot disagree about where anything goes. Only the zip differs: it carries a
# compiled schema, because a hand-installed extension has nothing to compile one
# for it.

set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$REPO_DIR"

UUID=magunetto@matteopacini.me
PKGNAME=gnome-shell-extension-magunetto
DIST=$REPO_DIR/dist
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

# metadata.json is the single source of truth: the shell reads it, and the
# version constraint below is derived from the same field the shell checks.
VERSION=$(jq -r '."version-name"' "$UUID/metadata.json")
GNOME_MIN=$(jq -r '."shell-version" | map(tonumber) | min' "$UUID/metadata.json")
GNOME_MAX=$(jq -r '1 + (."shell-version" | map(tonumber) | max)' "$UUID/metadata.json")

SUMMARY="Radial window snapper for GNOME Shell"
DESCRIPTION="Hold a shortcut, flick the pointer toward a direction, and release:
the focused window snaps to that region of the screen. Targets GNOME Shell
${GNOME_MIN} only."
MAINTAINER="Matteo Pacini <m@matteopacini.me>"
URL=https://github.com/matteo-pacini/Magunetto

rm -rf "$DIST"
mkdir -p "$DIST"

echo "magunetto $VERSION, for GNOME Shell $GNOME_MIN"

# --- the zip ------------------------------------------------------------------
#
# From the Nix output rather than `gnome-extensions pack`, which silently drops
# lib/ unless every subdirectory is named with --extra-source.

echo "  zip"
NIX_OUT=$(nix build .#default --no-link --print-out-paths)
(cd "$NIX_OUT/share/gnome-shell/extensions/$UUID" \
    && zip -qr "$DIST/$UUID.shell-extension.zip" .)

# --- the staged tree the distro packages share --------------------------------

packaging/install.sh "$STAGE" /usr

fpm_common=(
    -s dir
    -C "$STAGE"
    -n "$PKGNAME"
    -v "$VERSION"
    --iteration 1
    --license "GPL-3.0-or-later"
    --maintainer "$MAINTAINER"
    --url "$URL"
    --description "$DESCRIPTION"
    --category gnome
    -f
)

# --- deb ----------------------------------------------------------------------
#
# The "~" makes a prerelease such as 51~beta fail the upper bound rather than
# satisfy it.

echo "  deb"
fpm "${fpm_common[@]}" -t deb -a all -p "$DIST" \
    --depends "gnome-shell (>= ${GNOME_MIN}~)" \
    --depends "gnome-shell (<< ${GNOME_MAX}~)" \
    usr >/dev/null

# --- rpm ----------------------------------------------------------------------

echo "  rpm"
fpm "${fpm_common[@]}" -t rpm -a noarch -p "$DIST" \
    --rpm-summary "$SUMMARY" \
    --depends "gnome-shell >= ${GNOME_MIN}" \
    --depends "gnome-shell < ${GNOME_MAX}" \
    usr >/dev/null

# --- pacman -------------------------------------------------------------------
#
# No upper bound: pinning it would make pacman refuse the user's GNOME upgrade
# until they uninstall this, which is worse than the shell listing the extension
# as unsupported.

echo "  pacman"
fpm "${fpm_common[@]}" -t pacman -a any -p "$DIST" \
    --depends "gnome-shell>=${GNOME_MIN}" \
    usr >/dev/null

echo
( cd "$DIST" && ls -la . | tail -n +2 )
