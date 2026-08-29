#!/bin/sh
#
# Installs the extension into a staging root, for every packaging format in this
# directory.
#
#   packaging/install.sh <destdir> [prefix]
#
# It exists so the layout is stated once. The three formats here would otherwise
# each carry their own copy of it, and the copies would drift.
#
# Two things differ from the zip and the Nix package, and both are deliberate:
#
#   - The GSettings schema is installed uncompiled, into the system schema
#     directory. Every distro compiles that directory itself — a dpkg trigger, an
#     rpm file trigger, a pacman hook — and Arch's guidelines forbid a package
#     running glib-compile-schemas at all.
#   - The extension keeps no schemas/ directory of its own. Without one,
#     getSettings() falls back to the default schema source, which is exactly
#     where the schema was just installed.
#
# The zip and the Nix package ship a compiled schema instead, because neither has
# anything to compile it for them at install time.

set -eu

DESTDIR=${1:?usage: install.sh <destdir> [prefix]}
PREFIX=${2:-/usr}

UUID=magunetto@matteopacini.me
SRC=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

EXTDIR=$DESTDIR$PREFIX/share/gnome-shell/extensions/$UUID
SCHEMADIR=$DESTDIR$PREFIX/share/glib-2.0/schemas

install -d "$EXTDIR" "$SCHEMADIR"
cp -r "$SRC/$UUID/." "$EXTDIR"

install -m 644 "$SRC/$UUID"/schemas/*.gschema.xml "$SCHEMADIR"
rm -rf "$EXTDIR/schemas"

# Present only when someone has built locally; it must never reach a package.
rm -f "$EXTDIR/gschemas.compiled"

# rpmlint and lintian both object to an executable bit with no interpreter.
find "$EXTDIR" -type f -exec chmod 644 {} +
find "$EXTDIR" -type d -exec chmod 755 {} +
