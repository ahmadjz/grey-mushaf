#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../../app"
export PATH="$HOME/development/flutter/bin:$PATH"
# Start Medium_Phone with -memory 4096 first. Run without other heavy jobs.
heavy env GRADLE_OPTS=-Dorg.gradle.daemon=false flutter drive --profile --no-dds \
  --driver=test_driver/perf_baseline_driver.dart \
  --target=integration_test/perf_baseline_test.dart -d emulator-5554
