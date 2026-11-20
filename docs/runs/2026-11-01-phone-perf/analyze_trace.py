import json,collections,statistics
from pathlib import Path
p=Path(__file__).parent
out={}
for orient in ('portrait','landscape'):
 events=json.loads((p/f'{orient}_trace.json').read_text())['traceEvents']; stacks=collections.defaultdict(list);spans=[]
 for e in events:
  tid=(e.get('pid'),e.get('tid'))
  if e.get('ph')=='B': stacks[tid].append(e)
  elif e.get('ph')=='E' and stacks[tid]:
   b=stacks[tid].pop();spans.append(dict(name=b.get('name'),ts=b['ts'],dur=e['ts']-b['ts'],tid=tid,args=b.get('args',{})))
  elif e.get('ph')=='X':spans.append(dict(name=e.get('name'),ts=e['ts'],dur=e.get('dur',0),tid=tid,args=e.get('args',{})))
 frames=sorted([s for s in spans if s['name']=='Animator::BeginFrame'],key=lambda x:x['ts'])
 paints=[s for s in spans if s['name']=='_PageRender'];hist=collections.Counter()
 for i,f in enumerate(frames):
  end=frames[i+1]['ts'] if i+1<len(frames) else f['ts']+f['dur'];hist[sum(f['ts']<=s['ts']<end for s in paints)]+=1
 durations={}
 for name in ('GPURasterizer::Draw','LayerTree::Paint','CreateGlyphAtlas','UpdateAtlasBitmap','AppendToExistingAtlas','Canvas::saveLayer','RenderPassGLES::EncodeCommandsInReactor','BUILD','LAYOUT','PAINT','SEMANTICS','_PageRender'):
  a=[s['dur']/1000 for s in spans if s['name']==name]
  if a:durations[name]={'count':len(a),'avg_ms':statistics.mean(a),'worst_ms':max(a),'sum_ms':sum(a)}
 positive=[e['ts'] for e in events if e.get('ts',0)>0]
 out[orient]={'window_s':(max(positive)-min(positive))/1e6,'ui_frames':len(frames),'page_paint_frames_histogram':dict(hist),'page_render_paints':len(paints),'durations_inclusive':durations,'cache_names':sorted({str(e.get('name')) for e in events if 'cache' in str(e.get('name')).lower()})}
(p/'trace-analysis.json').write_text(json.dumps(out,indent=2));print(json.dumps(out,indent=2))
d=json.loads((p/'motion.json').read_text());groups=collections.defaultdict(list)
for s in d['swipes']:
 offsets=s['offsets'];groups[(s['blank'],s['landscape'])].append({'first':offsets[0][0]/1000,'settle':(offsets[-1][0]-s['release_us'])/1000})
for key,rows in groups.items(): print('motion blank/landscape',key,'count',len(rows),'first logical movement median ms',statistics.median(r['first'] for r in rows),'settle median/range ms',statistics.median(r['settle'] for r in rows),min(r['settle'] for r in rows),max(r['settle'] for r in rows))
