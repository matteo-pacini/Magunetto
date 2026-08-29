#!/usr/bin/env bash
#
# Regenerates po/magunetto.pot from the sources listed in POTFILES, and brings
# every catalogue in LINGUAS up to date with it.
#
#   nix develop --command po/update.sh            # extract, then merge
#   nix develop --command po/update.sh --check    # extract, compare, touch nothing
#
# Run it after adding or changing any string a user can see. The unit tier runs
# --check, so forgetting leaves a failing test rather than thirteen catalogues
# quietly missing a string.

set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$REPO_DIR"

PO=po
POT=$PO/magunetto.pot

# xgettext reads a .gschema.xml only through the ITS rules glib ships, and finds
# them only under GETTEXTDATADIRS. Without it the schema contributes nothing and
# the template is six strings short, silently.
: "${GETTEXTDATADIRS:?not set — run this inside nix develop}"
[ -f "$GETTEXTDATADIRS/its/gschema.its" ] || {
    echo "no gschema.its under $GETTEXTDATADIRS/its" >&2
    exit 1
}

lines() { grep -vE '^\s*(#|$)' "$1"; }

mapfile -t SOURCES < <(lines "$PO/POTFILES")
mapfile -t LOCALES < <(lines "$PO/LINGUAS")

# `this.gettext` rather than a bare `gettext`: the preferences object inherits
# the method, so there is no imported function to name. `N_` is curveInfo.js's
# marker, which stays untranslated there and is translated where it is shown.
# The reader is chosen per file, so the schema needs no separate pass.
extract() {
    xgettext \
        --from-code=UTF-8 \
        --keyword=N_ \
        --keyword=this.gettext \
        --add-comments=Translators: \
        --package-name=Magunetto \
        --msgid-bugs-address=https://github.com/matteo-pacini/Magunetto/issues \
        --copyright-holder="Matteo Pacini" \
        --output="$1" \
        "${SOURCES[@]}"
    sed -i 's/charset=CHARSET/charset=UTF-8/' "$1"
}

if [ "${1:-}" = --check ]; then
    fresh=$(mktemp); trap 'rm -f "$fresh"' EXIT
    extract "$fresh"
    # The creation date is stamped at extraction and always differs.
    if diff -u \
        <(grep -v '^"POT-Creation-Date:' "$POT") \
        <(grep -v '^"POT-Creation-Date:' "$fresh")
    then
        echo "$POT is current"
        exit 0
    fi
    echo "$POT is stale — run po/update.sh" >&2
    exit 1
fi

extract "$POT"
echo "$POT: $(($(grep -c '^msgid' "$POT") - 1)) messages"

for locale in "${LOCALES[@]}"; do
    target=$PO/$locale.po
    if [ -f "$target" ]; then
        msgmerge --quiet --update --backup=none "$target" "$POT"
    else
        msginit --no-translator --locale="$locale" --input="$POT" --output="$target"
    fi
    printf '  %-6s %s\n' "$locale" \
        "$(msgfmt --check --statistics --output-file=/dev/null "$target" 2>&1)"
done
