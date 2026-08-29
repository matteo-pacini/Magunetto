#!/usr/bin/env bash
#
# Turns the demo recording into the assets the README uses.
#
#   dbus-run-session -- tests/harness/run.sh _demo   # records .harness/demo.webm
#   tests/harness/demo-encode.sh                     # writes assets/demo.{gif,mp4}
#
# The recording is real time at the compositor's own frame rate. The mp4 keeps
# that; the gif trades frames for size, because a smooth animation is exactly the
# thing GIF compresses worst.

set -euo pipefail

HARNESS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(cd -- "$HARNESS_DIR/../.." && pwd)

SOURCE=${1:-$REPO_DIR/.harness/demo.webm}
GIF=$REPO_DIR/assets/demo.gif
MP4=$REPO_DIR/assets/demo.mp4

GIF_WIDTH=720
GIF_FPS=16
GIF_COLORS=64

[ -f "$SOURCE" ] || {
    echo "no recording at $SOURCE; run the _demo case first" >&2
    exit 1
}

command -v ffmpeg >/dev/null || {
    echo "ffmpeg not found; run inside nix develop" >&2
    exit 1
}

ffmpeg -y -loglevel error -i "$SOURCE" \
    -vf "fps=$GIF_FPS,scale=$GIF_WIDTH:-1:flags=lanczos,split[a][b];\
[a]palettegen=max_colors=$GIF_COLORS:stats_mode=diff[p];\
[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
    -loop 0 "$GIF"

ffmpeg -y -loglevel error -i "$SOURCE" \
    -c:v libx264 -preset slow -crf 26 -pix_fmt yuv420p \
    -movflags +faststart "$MP4"

printf '%s  %s\n' "$(du -h "$GIF" | cut -f1)" "$GIF"
printf '%s  %s\n' "$(du -h "$MP4" | cut -f1)" "$MP4"
