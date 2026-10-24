#!/usr/bin/env bash
# Isolated sequential profile/release measurement. Start Medium_Phone with 4096 MB.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
STAGE="${1:?stage name required}"
OUT="$ROOT/docs/runs/2026-10-24-perf-after/$STAGE"
ADB="$HOME/Android/Sdk/platform-tools/adb"
export PATH="$HOME/development/flutter/bin:$PATH"
mkdir -p "$OUT"
cd app
PERF_OUT="$OUT" heavy env GRADLE_OPTS=-Dorg.gradle.daemon=false flutter drive --profile --no-dds --driver=test_driver/perf_baseline_driver.dart --target=integration_test/perf_baseline_test.dart -d emulator-5554 > "$OUT/frames.log" 2>&1
for MODE in profile release; do
  mkdir -p "$OUT/$MODE"
  heavy env GRADLE_OPTS=-Dorg.gradle.daemon=false flutter build apk --"$MODE" --target=lib/main.dart --target-platform android-x64 > "$OUT/$MODE/build.log" 2>&1
  "$ADB" install -r "build/app/outputs/flutter-apk/app-$MODE.apk" > "$OUT/$MODE/install.log"
  PERF_RESULT="$OUT/$MODE" python3 - <<'PY'
import subprocess,time,re,json,os
from pathlib import Path
adb=str(Path.home()/'Android/Sdk/platform-tools/adb'); out=Path(os.environ['PERF_RESULT'])
def run(*args): return subprocess.check_output([adb,*args],text=True)
def memory(tag):
 s=run('shell','dumpsys','meminfo','tech.ahmadjz.greymushaf'); (out/f'mem-{tag}.txt').write_text(s)
 return int(re.search(r'TOTAL PSS:\s+(\d+)',s)[1])
result={'device':'Medium_Phone,4096MB,x86_64,API37,Impeller OpenGLES','build':out.name,'cold':[]}
for i in range(5):
 run('shell','am','force-stop','tech.ahmadjz.greymushaf');run('logcat','-c')
 start=run('shell','date +%s%3N; am start -W -n tech.ahmadjz.greymushaf/.MainActivity');time.sleep(2)
 log=run('logcat','-d','-s','flutter'); (out/f'cold-{i}.txt').write_text(start+log)
 result['cold'].append({'reader_ms':int(re.search(r'READER_FIRST_FRAME (\d+)',log)[1])-int(start.splitlines()[0]),'display_ms':int(re.search(r'TotalTime: (\d+)',start)[1]),'pss_kib':memory(f'cold-{i}')})
# Fifth cold launch starts at page 1. No reveal/settings changes or data clearing.
for i in range(603):
 run('shell','input','swipe','150','1200','950','1200','120');time.sleep(.2)
 if i+1==20: result['after20_pss_kib']=memory('after20')
 if (i+1)%80==0: print(out.name,i+1,flush=True)
log=run('logcat','-d','-s','flutter');(out/'pages.log').write_text(log)
pages={1}|{int(n) for n in re.findall(r'READER_PAGE (\d+)',log)}
result['coverage']=len(pages);result['missing']=sorted(set(range(1,605))-pages)
result['after604_pss_kib']=memory('after604');time.sleep(30);result['settled_pss_kib']=memory('settled')
(out/'numbers.json').write_text(json.dumps(result,indent=2))
assert not result['missing'], result['missing']
PY
done
