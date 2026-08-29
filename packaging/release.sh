#!/usr/bin/env bash
#
# Builds the release artefacts and attaches them to a GitHub release.
#
#   nix develop --command packaging/release.sh          # the tag matching metadata.json
#   nix develop --command packaging/release.sh v0.2.0   # a named tag
#
# Uploading is the only step that reaches outside this machine, and it happens
# last, after everything has been built and checked.

set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$REPO_DIR"

UUID=magunetto@matteopacini.me
VERSION=$(jq -r '."version-name"' "$UUID/metadata.json")
TAG=${1:-v$VERSION}

# The tag names the version users will report bugs against, so it has to agree
# with what the extension tells the shell it is.
if [ "$TAG" != "v$VERSION" ]; then
    echo "tag $TAG does not match metadata.json version-name $VERSION" >&2
    exit 1
fi

if ! git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "tag $TAG does not exist; create and push it first" >&2
    exit 1
fi

# Artefacts built from a dirty tree would not match the tag they are attached to.
if [ -n "$(git status --porcelain)" ]; then
    echo "working tree is dirty; commit or stash before releasing" >&2
    git status --short >&2
    exit 1
fi

if [ "$(git rev-parse HEAD)" != "$(git rev-parse "$TAG^{commit}")" ]; then
    echo "HEAD is not $TAG; check out the tag before releasing" >&2
    exit 1
fi

packaging/build.sh

echo
if gh release view "$TAG" >/dev/null 2>&1; then
    echo "attaching to existing release $TAG"
    gh release upload "$TAG" --clobber dist/*
else
    echo "no release $TAG yet; create it with gh release create, then re-run" >&2
    exit 1
fi

echo
gh release view "$TAG" --json assets --jq '.assets[] | "  \(.name)  \(.size) bytes"'
