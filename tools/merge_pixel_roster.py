"""Merge inspected raster-frame metadata without altering source art."""
import json
from pathlib import Path
import numpy as np
from PIL import Image
from map_pixel_roster import components

ROOT = Path(__file__).resolve().parents[1]
manifest = ROOT / 'assets/pixel_v1/manifest.json'
data = json.loads(manifest.read_text(encoding='utf-8'))
hero = data['actors']['player']
hero['source_frames'] = hero['source_frames'][:32]
for frame in hero['source_frames']:
    frame['anchor'][1] = max(frame['anchor'][1],frame['rect'][3])
image = np.asarray(Image.open(ROOT / 'assets/pixel_v1/moonli_combat_raw.png'))
groups = components(image[:, :, 3] >= 100)[:16]
groups.sort(key=lambda b: (b[1]+b[3])/2)
ordered = []
for row in range(4):
    ordered += sorted(groups[row*4:row*4+4], key=lambda b: b[0])
# Inspected body/ground pivots, excluding the coat hem from the foot centroid.
anchor_x = [244,244,242,242,225,234,237,233,233,233,235,236,230,231,234,236]
for i, (x,y,r,b,n) in enumerate(ordered):
    left, top = max(0,x-1), max(0,y-1)
    right, bottom = min(image.shape[1],r+1), min(image.shape[0],b+1)
    ax, ay = anchor_x[i]+(i%4)*362-left, bottom-top
    width, height = right-left, bottom-top
    dx = 35-round(ax*.16)
    assert dx >= 0 and dx+round(width*.16) <= 48, (i,dx,width,ax)
    hero['source_frames'].append(dict(sheet='res://assets/pixel_v1/moonli_combat_raw.png',
        rect=[left,top,width,height], anchor=[ax,ay]))
def clip(ids, fps):
    return dict(frames=ids, fps=fps, loop=False)
hero['animations'].update(dict(cast=clip(list(range(32,40)),16),
    attack=clip(list(range(32,40)),16), hurt=clip(list(range(40,44)),12),
    defeat=clip(list(range(44,48)),8), recover=clip([38,39],12)))
data['actors'].update(json.loads((ROOT/'assets/pixel_v1/roster_frames.json').read_text(encoding='utf-8')))
data['ready'] = True
data['status'] = 'approved_pixel_style_active_full_roster'
data['approved_motion'] = '48x64 coherent authored pixel frames; user approved size and gait'
manifest.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Activated:', {k:len(v['source_frames']) for k,v in data['actors'].items()})
