#!/bin/sh
# QA-5: export the UI tests' kept attachments (XCTAttachment screenshots) from
# the result bundle as PNGs, named after the test and the attachment, so
# reviewers can open them on the qa/gate-0a-shots branch.
# Usage: export-attachments.sh <path.xcresult> <out dir>
set -eu
bundle="$1"; out="$2"
raw="$(mktemp -d)"
mkdir -p "$out"
xcrun xcresulttool export attachments --path "$bundle" --output-path "$raw"
# manifest.json: [{testIdentifier, attachments: [{exportedFileName, suggestedHumanReadableName}]}]
python3 - "$raw" "$out" <<'PY'
import json, os, re, shutil, sys
raw, out = sys.argv[1], sys.argv[2]
with open(os.path.join(raw, "manifest.json")) as f:
    manifest = json.load(f)
count = 0
for test in manifest:
    name = test.get("testIdentifier", "test").split("/")[-1].replace("()", "")
    for a in test.get("attachments", []):
        src = os.path.join(raw, a["exportedFileName"])
        ext = os.path.splitext(src)[1] or ".png"
        label = a.get("suggestedHumanReadableName") or os.path.splitext(a["exportedFileName"])[0]
        label = os.path.splitext(label)[0]
        safe = re.sub(r"[^A-Za-z0-9._-]+", "-", f"{name}-{label}").strip("-")
        dst = os.path.join(out, safe + ext)
        n = 2
        while os.path.exists(dst):
            dst = os.path.join(out, f"{safe}-{n}{ext}"); n += 1
        shutil.copyfile(src, dst)
        count += 1
print(f"exported {count} attachments to {out}")
PY
