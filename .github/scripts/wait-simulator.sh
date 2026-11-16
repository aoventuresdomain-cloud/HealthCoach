#!/bin/sh
# Waits (up to 10 minutes) for prepare-simulator.sh to finish; fails with its log if it didn't.
set -eu
i=0
while [ ! -f sim-ready ]; do
  i=$((i + 1))
  if [ "$i" -gt 600 ]; then echo "Simulator not ready after 10 minutes"; cat sim-prepare.log || true; exit 1; fi
  sleep 1
done
cat sim-prepare.log || true
