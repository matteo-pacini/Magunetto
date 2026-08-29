#!/usr/bin/env bash
#
# Every test tier in one command. Fails if any tier fails.
#
#   tests/run-all.sh            unit + harness
#   tests/run-all.sh --vm       unit + harness + the NixOS virtual-machine test

set -uo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$REPO_DIR" || exit 1

STATUS=0

echo "== unit: gesture mathematics =="
if node --test tests/*.test.js; then
    echo "unit: pass"
else
    echo "unit: FAIL"
    STATUS=1
fi

echo
echo "== harness: headless GNOME Shell =="
if env -u WAYLAND_DISPLAY -u DISPLAY dbus-run-session -- ./tests/harness/run.sh; then
    echo "harness: pass"
else
    echo "harness: FAIL"
    STATUS=1
fi

if [ "${1:-}" = "--vm" ]; then
    # The VM builds from the flake source, which is the git tree. An untracked
    # file is absent from the derivation, and the only symptom is an extension
    # that never reaches ACTIVE fifteen minutes later.
    # po/ is a source of the derivation too: the catalogues are compiled from it.
    untracked=$(git -C "$REPO_DIR" ls-files --others --exclude-standard -- \
        "magunetto@matteopacini.me" "po" 2>/dev/null)
    if [ -n "$untracked" ]; then
        echo "vm: refusing to run, these extension files are untracked:"
        echo "$untracked" | sed 's/^/    /'
        echo "  git add them first, or the VM will install an extension without them."
        exit 1
    fi

    echo
    echo "== virtual machine: full GNOME session =="
    if nix build .#checks.x86_64-linux.vm --no-link; then
        echo "vm: pass"
    else
        echo "vm: FAIL"
        STATUS=1
    fi
fi

echo
[ "$STATUS" -eq 0 ] && echo "all tiers passed" || echo "at least one tier failed"
exit "$STATUS"
