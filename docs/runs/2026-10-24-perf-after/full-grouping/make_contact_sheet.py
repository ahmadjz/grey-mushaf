"""Exact 40px crops, 8x nearest-neighbour; no altered source pixels."""
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFont
import json

root = Path(__file__).resolve().parents[4]
reference = root / 'docs/runs/2026-10-24-perf-baseline/parity/images'
candidate = root / 'docs/runs/2026-10-24-perf-after/parity/stage1/images'
locations = json.loads((root / 'docs/runs/2026-10-24-perf-after/stage1/pixel-locations.json').read_text())['images']
out = Path(__file__).resolve().parent
# Largest RGB(A) delta per distinct page/physical-pixel position. Ties prefer
# unrevealed, then dark mode so repeated states do not occupy extra rows.
spots = {}
for name, changes in locations.items():
    page = name.split('-dark-')[0].split('-light-')[0]
    for change in changes:
        key = (page, *change['xy'])
        rank = (change['max_delta'], 'unrevealed' in name, '-dark-' in name)
        if key not in spots or rank > spots[key][0]:
            spots[key] = (rank, name, change)
selected = sorted(spots.values(), key=lambda item: (-item[0][0], item[1], item[2]['xy']))[:6]
font = ImageFont.truetype('/usr/share/fonts/google-noto/NotoSans-Regular.ttf', 18)
small = ImageFont.truetype('/usr/share/fonts/google-noto/NotoSans-Regular.ttf', 15)
row_h, gap, side = 396, 16, 320
sheet = Image.new('RGB', (3 * side + 4 * gap, 70 + len(selected) * row_h), '#dddddd')
draw = ImageDraw.Draw(sheet)
draw.text((gap, 9), 'FULL GROUPING: six worst distinct physical-pixel locations', fill='black', font=font)
draw.text((gap, 34), '40x40 physical px; 8x nearest-neighbour. Absolute diff is unamplified.', fill='black', font=small)
metadata=[]
for i, (rank, name, spot) in enumerate(selected):
    a=Image.open(reference/name).convert('RGBA');b=Image.open(candidate/name).convert('RGBA')
    x,y=spot['xy'];box=(x-20,y-20,x+20,y+20)
    diff=ImageChops.difference(a,b)
    total=a.width*a.height; changed=len(locations[name])
    top=70+i*row_h
    label=f'{name.removesuffix(".png")} | pixel ({x},{y}) | max delta {rank[0]}'
    draw.text((gap,top),label,fill='black',font=font)
    draw.text((gap,top+23),f'Whole image: {changed:,} changed / {total:,} pixels',fill='black',font=small)
    for j,(title,img) in enumerate([('Reference',a),('Candidate',b),('Absolute RGB diff',diff)]):
        left=gap+j*(side+gap)
        draw.text((left,top+43),title,fill='black',font=small)
        crop=img.convert('RGB').crop(box).resize((side,side),Image.Resampling.NEAREST)
        sheet.paste(crop,(left,top+65))
    metadata.append(dict(image=name,pixel=[x,y],crop=list(box),changed=changed,total=total,maxDelta=rank[0]))
path=root/'docs/runs/shots/2026-10-24-full-grouping-six-worst.png'
sheet.save(path)
(out/'contact-sheet.json').write_text(json.dumps(metadata,indent=2)+'\n')
lines=['# Full-grouping pixel counts','', 'Original full-grouping captures, raw RGBA, no tolerance. Every image is 2,592,000 physical pixels.','', '| Image | Changed / total pixels |','|---|---:|']
diff=json.loads((candidate/'diff.json').read_text())
for name,r in sorted(diff['images'].items()):
    with Image.open(reference/name) as im: total=im.width*im.height
    lines.append(f'| {name} | {r["pixels"]} / {total} |')
(out/'pixel-counts.md').write_text('\n'.join(lines)+'\n')
print(path)
print(json.dumps(metadata,indent=2))
