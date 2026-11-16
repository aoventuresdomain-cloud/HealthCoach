#!/bin/sh
# Prints the UDID of an available iOS 26 iPhone Pro simulator (Dynamic Island).
set -eu
xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
found = sorted(
    (runtime, d["name"], d["udid"])
    for runtime, ds in devices.items() if ".iOS-26" in runtime
    for d in ds if d["name"].startswith("iPhone") and "Pro" in d["name"]
)
if not found:
    sys.exit("No iOS 26 iPhone Pro simulator on this runner")
runtime, name, udid = found[-1]
print(f"Using {name} ({runtime})", file=sys.stderr)
print(udid)
'
