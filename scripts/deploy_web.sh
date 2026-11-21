#!/usr/bin/env bash
# usage: scripts/deploy_web.sh <empty-or-previous-stage-dir> [vps]
set -euo pipefail
[ $# -ge 1 ] || { echo "usage: $0 <stage-dir> [vps]" >&2; exit 2; }
stage=$(realpath -m "$1")
root=$(realpath "$(dirname "$0")/..")
cd "$root/app"
[ -f web/sqlite3.wasm ] || dart run sqflite_common_ffi_web:setup
heavy flutter build web --release ${SYNC_URL:+--dart-define=SYNC_URL=$SYNC_URL}
mkdir -p "$stage/public" "$stage/private"
rsync -a --delete --delete-excluded --no-links --exclude /assets/assets build/web/ "$stage/public/"
rsync -a --delete --no-links build/web/assets/assets/ "$stage/private/"
if [ "${2:-}" = vps ]; then
  ssh vps 'mkdir -p /srv/mushaf.ahmadjz.tech/web'
  rsync -a --delete --no-links "$stage/public" "$stage/private" vps:/srv/mushaf.ahmadjz.tech/web/
  rsync -a "$root/server/pb_hooks/web.pb.js" vps:/srv/mushaf.ahmadjz.tech/pb_hooks/
fi
