#!/usr/bin/env bash
# Isolated fixture only: never clears the reader's normal reveals.db.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
OUT="${1:?absolute output directory required}"
DEVICE="${2:-emulator-5554}"
export PATH="$HOME/development/flutter/bin:$PATH"
mkdir -p "$OUT"
cd app
for PHASE in write read; do
  PROOF_OUT="$OUT/$PHASE.json" heavy env GRADLE_OPTS=-Dorg.gradle.daemon=false flutter drive --profile --no-dds --keep-app-running --dart-define="RESTART_PHASE=$PHASE" --driver=test_driver/proof_driver.dart --target=integration_test/restart_proof_test.dart -d "$DEVICE" > "$OUT/$PHASE.log" 2>&1
  "$HOME/Android/Sdk/platform-tools/adb" -s "$DEVICE" shell am force-stop tech.ahmadjz.greymushaf
done
python3 - "$OUT" <<'PY'
import json,sys
from pathlib import Path
root=Path(sys.argv[1]); a=json.loads((root/'write.json').read_text());b=json.loads((root/'read.json').read_text())
assert a['pid']!=b['pid'], 'Restart must use distinct Android processes'
assert a['device_id']==b['device_id'] and a['records']==b['records']
assert b['cleanup']=='database deleted at teardown'
print('Separate-process reveal persistence passed; reader-restart-proof.db removed. Identifiers: write.json/read.json.')
PY
