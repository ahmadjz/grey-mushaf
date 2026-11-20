#!/usr/bin/env bash
set -u
ROOT=/home/ahmadjz/Documents/Quran
export PATH="$HOME/development/flutter/bin:$HOME/.local/bin:$PATH"
cd "$ROOT/app"
while kill -0 70313 2>/dev/null; do sleep 20; done
if [ ! -f "$ROOT/docs/runs/2026-11-01-phone-perf/frame_samples_ms.json" ]; then echo 'STOP: frame capture did not complete'; exit 1; fi
for MODE in profile release; do
 LOG="$ROOT/docs/runs/shots/2026-11-01-build-$MODE.log"
 heavy env GRADLE_OPTS=-Dorg.gradle.daemon=false flutter build apk --offline --"$MODE" --target=lib/main.dart --target-platform android-arm64 > "$LOG" 2>&1
 result=$?
 echo "$MODE build EXIT=$result"
 tail -10 "$LOG"
 rg -n -m 10 'FAIL|FAILED|Exception|Error|error:' "$LOG"
 if [ "$result" -ne 0 ]; then exit "$result"; fi
 "$HOME/Android/Sdk/platform-tools/adb" -s 2be3110f install -r build/app/outputs/flutter-apk/app-$MODE.apk > "$ROOT/docs/runs/2026-11-01-phone-perf/install-$MODE.log" 2>&1
 result=$?
 echo "$MODE install EXIT=$result"
 if [ "$result" -ne 0 ]; then cat "$ROOT/docs/runs/2026-11-01-phone-perf/install-$MODE.log"; exit "$result"; fi
 python3 "$ROOT/docs/runs/2026-11-01-phone-perf/cold_memory.py" "$MODE"
 result=$?
 echo "$MODE measurements EXIT=$result"
 if [ "$result" -ne 0 ]; then exit "$result"; fi
done
for CHECK in analyze test; do
 LOG="$ROOT/docs/runs/shots/2026-11-01-$CHECK.log"
 heavy flutter "$CHECK" > "$LOG" 2>&1
 result=$?
 echo "$CHECK EXIT=$result"
 tail -5 "$LOG"
 rg -n -m 10 'FAIL|FAILED|Exception|Error|error:' "$LOG"
done
