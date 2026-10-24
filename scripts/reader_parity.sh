#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../app"
export PATH="$HOME/development/flutter/bin:$PATH"
export PARITY_OUT="${1:?absolute capture destination required}"
mkdir -p "$PARITY_OUT"
heavy env GRADLE_OPTS=-Dorg.gradle.daemon=false flutter drive --profile --no-dds --driver=test_driver/parity_driver.dart --target=integration_test/parity_test.dart -d emulator-5554
PARITY_REFERENCE="$PARITY_OUT/images" PARITY_CANDIDATE="$PARITY_OUT/repeat" heavy flutter test tool/parity_diff.dart
if [ "$#" -gt 1 ]; then
  PARITY_REFERENCE="$2/images" PARITY_CANDIDATE="$PARITY_OUT/images" heavy flutter test tool/parity_diff.dart
fi
