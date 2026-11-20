#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
ADB="$HOME/Android/Sdk/platform-tools/adb"
OUT=docs/runs/2026-10-24-perf-baseline
# Install the normal lib/main.dart PROFILE build before this script.
# No data clear: preserves device settings and reveals; process-cold, warm disk cache.
for trial in 1 2 3 4 5; do
  "$ADB" shell am force-stop tech.ahmadjz.greymushaf
  "$ADB" logcat -c
  "$ADB" shell 'date +%s%3N; am start -W -n tech.ahmadjz.greymushaf/.MainActivity' > "$OUT/cold-$trial.txt"
  sleep 2
  "$ADB" logcat -d -s flutter >> "$OUT/cold-$trial.txt"
  "$ADB" shell dumpsys meminfo tech.ahmadjz.greymushaf > "$OUT/pss-cold-$trial.txt"
done
