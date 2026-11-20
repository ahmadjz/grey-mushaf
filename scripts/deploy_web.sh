#!/usr/bin/env bash
# usage: scripts/deploy_web.sh <stage-dir> [vps]
set -euo pipefail
stage=$(realpath -m "$1")
cd "$(dirname "$0")/../app"
[ -f web/sqlite3.wasm ] || dart run sqflite_common_ffi_web:setup
heavy flutter build web --release ${SYNC_URL:+--dart-define=SYNC_URL=$SYNC_URL}
mkdir -p "$stage/public" "$stage/private"
rsync -a --delete --exclude /assets/assets build/web/ "$stage/public/"
rsync -a --delete build/web/assets/assets/ "$stage/private/"
if [ "${2:-}" = vps ]; then
  rsync -a --delete "$stage/" vps:/srv/mushaf.ahmadjz.tech/web/
fi
