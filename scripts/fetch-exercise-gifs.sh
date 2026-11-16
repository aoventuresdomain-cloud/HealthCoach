#!/bin/sh
# Downloads every exercise GIF named in Content/exercises/exercises.json into
# Content/exercises/media/<mediaId>.gif, so the build bundles them and the app
# never fetches media at runtime (docs/spikes/s4-gifs.md). The files are not
# committed: the media isn't ours to redistribute (personal use only).
#
# Fails loudly if any URL doesn't return a GIF. Skips files already present.
# Usage: scripts/fetch-exercise-gifs.sh [repo root]
set -eu
root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
out="$root/Content/exercises/media"
mkdir -p "$out"

python3 - "$root/Content/exercises/exercises.json" <<'PY' > "$out/.list"
import json, sys
for e in json.load(open(sys.argv[1]))["exercises"]:
    m = e.get("media")
    if m and m.get("url") and m.get("mediaId"):
        print(m["mediaId"], m["url"])
PY

failed=0
fetched=0
while read -r id url; do
    file="$out/$id.gif"
    if [ -s "$file" ] && [ "$(head -c 4 "$file")" = "GIF8" ]; then continue; fi
    if curl -fsSL --retry 3 --max-time 30 -o "$file.part" "$url" && [ "$(head -c 4 "$file.part")" = "GIF8" ]; then
        mv "$file.part" "$file"
        fetched=$((fetched + 1))
    else
        echo "error: $id: $url did not return a GIF" >&2
        rm -f "$file.part"
        failed=$((failed + 1))
    fi
done < "$out/.list"
rm -f "$out/.list"

echo "GIFs: $fetched fetched, $(ls "$out"/*.gif 2>/dev/null | wc -l | tr -d ' ') present, $failed failed"
[ "$failed" -eq 0 ]
