import subprocess,time,re,json,sys,statistics
from pathlib import Path
adb=str(Path.home()/'Android/Sdk/platform-tools/adb'); out=Path(__file__).parent/sys.argv[1];out.mkdir(exist_ok=True)
def run(*args):return subprocess.check_output([adb,'-s','2be3110f',*args],text=True)
def memory(tag):
 s=run('shell','dumpsys','meminfo','tech.ahmadjz.greymushaf');(out/f'mem-{tag}.txt').write_text(s)
 return int(re.search(r'TOTAL PSS:\s+(\d+)',s)[1])
r={'device':'Redmi Note 9 Pro (2be3110f), Android12 API31, arm64, 60Hz','build':out.name,'cold':[]}
for i in range(5):
 run('shell','am','force-stop','tech.ahmadjz.greymushaf');run('logcat','-c')
 s=run('shell','date +%s%3N; am start -W -n tech.ahmadjz.greymushaf/.MainActivity');time.sleep(2)
 log=run('logcat','-d','-s','flutter');(out/f'cold-{i}.txt').write_text(s+log)
 reader=re.search(r'READER_FIRST_FRAME (\d+)',log);display=re.search(r'TotalTime: (\d+)',s)
 r['cold'].append({'reader_ms':int(reader[1])-int(s.splitlines()[0]) if reader else None,'display_ms':int(display[1]) if display else None})
for i in range(20):
 run('shell','input','swipe','150','1200','950','1200','250');time.sleep(.5)
r['after20_pss_kib']=memory('after20');(out/'pages.log').write_text(run('logcat','-d','-s','flutter'))
r['page_changes']=re.findall(r'READER_PAGE (\d+)',(out/'pages.log').read_text())
(out/'numbers.json').write_text(json.dumps(r,indent=2));print(json.dumps(r))
