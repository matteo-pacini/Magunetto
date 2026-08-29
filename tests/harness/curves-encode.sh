#!/usr/bin/env bash
#
# Turns the travel-style recordings into the README's comparison grid.
#
#   dbus-run-session -- tests/harness/run.sh _curves   # records .harness/curve-*.webm
#   tests/harness/curves-encode.sh                     # writes assets/curves/*.gif
#
# A travel lasts 220ms. Played at speed that is a blink, and seven of them side by
# side would look identical — so these are slowed, all by the same factor, which
# keeps the comparison honest even though none of them is real time. What the
# grid is for is the *shape* of each ease, not how long it takes.
#
# The clip is found rather than assumed: the gesture before it is driven by fixed
# sleeps, but those drift by up to a tenth of a second between takes, which is
# half the travel. ffmpeg's scene detection finds the frame the window starts
# moving, and everything is cut relative to that.

set -euo pipefail

HARNESS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$HARNESS_DIR/../.." && pwd)
cd "$REPO_DIR"

SOURCE_DIR=${MAGUNETTO_ARTIFACTS:-$REPO_DIR/.harness}
OUT_DIR=$REPO_DIR/assets/curves

WIDTH=${WIDTH:-260}
FPS=${FPS:-25}
COLORS=${COLORS:-48}
SLOW=${SLOW:-3}
LEAD=${LEAD:-0.12}     # stillness before the travel
LENGTH=${LENGTH:-0.70} # lead + the 220ms travel + long enough to read as landed

command -v ffmpeg >/dev/null || {
    echo "ffmpeg not found; run inside nix develop" >&2
    exit 1
}

# The list of styles comes from the table that defines them, so a style added
# later cannot be silently left out of the grid.
KEYS=$(node -e "import('$REPO_DIR/magunetto@matteopacini.me/lib/curveInfo.js')
    .then(m => console.log(m.CURVE_KEYS.join(' ')))")

mkdir -p "$OUT_DIR"

for key in $KEYS; do
    source_file=$SOURCE_DIR/curve-$key.webm
    [ -f "$source_file" ] || {
        echo "no recording at $source_file; run the _curves case first" >&2
        exit 1
    }

    # The first change large enough to be the window moving. The radial menu
    # fading in is a change too, but a far smaller one.
    # Not piped into head: under `set -o pipefail` that closes ffprobe's output
    # early, and the SIGPIPE it dies of takes the whole script with it.
    scenes=$(ffprobe -v error -f lavfi \
        "movie=$source_file,select=gt(scene\,0.02)" \
        -show_entries frame=pts_time -of csv=p=0 2>/dev/null)
    start=${scenes%%$'\n'*}
    [ -n "$start" ] || {
        echo "$key: no travel found in $source_file" >&2
        exit 1
    }

    from=$(awk -v s="$start" -v l="$LEAD" 'BEGIN { printf "%.3f", (s - l < 0 ? 0 : s - l) }')

    ffmpeg -y -loglevel error -ss "$from" -t "$LENGTH" -i "$source_file" \
        -vf "setpts=$SLOW*PTS,fps=$FPS,scale=$WIDTH:-1:flags=lanczos,split[a][b];\
[a]palettegen=max_colors=$COLORS:stats_mode=diff[p];\
[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
        -loop 0 "$OUT_DIR/$key.gif"

    printf '  %-7s travel at %-7s %s\n' \
        "$key" "${start}s" "$(du -h "$OUT_DIR/$key.gif" | cut -f1)"
done

echo
printf 'total %s in %s\n' "$(du -sh "$OUT_DIR" | cut -f1)" "$OUT_DIR"
