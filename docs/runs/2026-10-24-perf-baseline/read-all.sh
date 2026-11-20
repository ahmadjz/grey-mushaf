#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
python3 - <<'PY'
import subprocess,time,re,json
from pathlib import Path
adb=str(Path.home()/'Android/Sdk/platform-tools/adb')
out=Path('docs/runs/2026-10-24-perf-baseline')
def run(*args): return subprocess.check_output([adb,*args],text=True)
run('logcat','-c')
run('shell','am','force-stop','tech.ahmadjz.greymushaf')
run('shell','am','start','-W','-n','tech.ahmadjz.greymushaf/.MainActivity')
time.sleep(3)
def pss(tag):
 s=run('shell','dumpsys','meminfo','tech.ahmadjz.greymushaf')
 (out/f'pss-{tag}.txt').write_text(s)
 match=re.search(r'TOTAL PSS:\s+(\d+)',s)
 print(json.dumps({'phase':tag,'pss_kib':int(match[1]) if match else None}),flush=True)
pss('read-start')
for i in range(603):
 run('shell','input','swipe','150','1200','950','1200','120')
 time.sleep(.20)
 if i+1 == 20 or (i+1)%80==0: pss(f'read-{i+1}')
log=run('logcat','-d','-s','flutter')
(out/'read-all-logcat.txt').write_text(log)
pages={1}|{int(n) for n in re.findall(r'READER_PAGE (\d+)',log)}
print(json.dumps({'unique_pages':len(pages),'missing':sorted(set(range(1,605))-pages)}),flush=True)
pss('after-604-immediate')
time.sleep(30)
pss('after-604-settled')
assert len(pages)==604, 'Not every page was visited; do not claim full-read PSS'
PY
