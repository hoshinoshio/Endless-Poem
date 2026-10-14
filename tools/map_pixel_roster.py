"""Read-only alpha analysis; writes frame metadata, never alters source images."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
KEYS = ['guard', 'elite', 'boss', 'instrument', 'observer', 'anchor', 'musheng']

def components(mask):
    parents = []
    runs = []
    previous = []
    def find(i):
        while parents[i] != i:
            parents[i] = parents[parents[i]]
            i = parents[i]
        return i
    for y, row in enumerate(mask):
        edges = np.diff(np.r_[False, row, False].astype(np.int8))
        current = []
        for x0, x1 in zip(np.where(edges == 1)[0], np.where(edges == -1)[0]):
            i = len(parents)
            parents.append(i)
            runs.append((int(x0), int(x1), y))
            for p, a, b in previous:
                if a <= x1 and b >= x0:
                    parents[find(i)] = find(p)
            current.append((i, x0, x1))
        previous = current
    groups = {}
    for i, (a, b, y) in enumerate(runs):
        k = find(i)
        if k not in groups: groups[k] = [a, y, b, y+1, 0]
        g = groups[k]
        g[0], g[1], g[2], g[3] = min(g[0],a), min(g[1],y), max(g[2],b), max(g[3],y+1)
        g[4] += b-a
    return sorted(groups.values(), key=lambda g:g[4], reverse=True)

def animations(mechanical, npc):
    specs = {'walk':(list(range(8)),10,True), 'run':(list(range(8)),14,True),
             'idle':([8,9],3,True), 'windup':([10,11],7,False),
             'attack':([12,13],9,False), 'cast':([10,11,12,13,14,15],8,False),
             'recover':([14,15],7,False), 'hurt':([16,17],8,False),
             'defeat':([18,19],5,False)}
    if mechanical:
        specs['hover'] = (list(range(8)),8,True)
        specs['idle'] = (list(range(8)),8,True)
        specs['rest'] = ([8,9],3,True)
    if npc: specs['talk'] = (list(range(10,16)),6,True)
    return {k:dict(frames=f,fps=p,loop=l) for k,(f,p,l) in specs.items()}

def map_actor(key):
    path = ROOT/'assets/pixel_v1'/f'{key}_raw.png'
    rgba = np.asarray(Image.open(path).convert('RGBA'))
    mask = rgba[:,:,3] >= 100
    groups = components(mask)
    main = groups[:20]
    if len(main) != 20 or min(g[4] for g in main) < 1000:
        raise ValueError(f'{key}: expected 20 substantial disconnected subjects: {main}')
    # Spatial ordering uses observed subjects, never assumed equally sized cells.
    main.sort(key=lambda g:(g[1]+g[3])/2)
    ordered = []
    for row in range(5): ordered += sorted(main[row*4:row*4+4], key=lambda g:g[0])
    satellites = [[] for _ in ordered]
    for small in groups[20:]:
        if small[4] < 3: continue
        cx,cy = (small[0]+small[2])/2,(small[1]+small[3])/2
        distances = [max(g[0]-cx,0,cx-g[2])**2+max(g[1]-cy,0,cy-g[3])**2 for g in ordered]
        owner = int(np.argmin(distances))
        # Observer's detached first spell crosses the nominal column boundary.
        # Inspection ties these stars to frame 12's outstretched hand.
        if key == 'observer' and 700 <= cy <= 820 and 260 <= cx < 400:
            owner = 12
        if distances[owner] <= 75**2: satellites[owner].append(small)
    mechanical = key in ('instrument','anchor')
    entries = []
    for i,g in enumerate(ordered):
        x0,y0,x1,y1,_ = g
        # Attach isolated glints within a small halo of the actor's main component.
        for h in satellites[i]:
            x0,y0,x1,y1 = min(x0,h[0]),min(y0,h[1]),max(x1,h[2]),max(y1,h[3])
        x0,y0,x1,y1 = max(0,x0-1),max(0,y0-1),min(mask.shape[1],x1+1),min(mask.shape[0],y1+1)
        w,h = x1-x0,y1-y0
        local = mask[y0:y1,x0:x1]
        if mechanical:
            ax = w/2
        else:
            # Ground support, excluding the attack weapon's far tip where possible.
            yy,xx = np.where(local[max(0,h-int(h*.09)):])
            ax = float(np.median(xx)) if len(xx) else w/2
            if i>=18:
                # Fallen bodies retain their torso axis, not the discarded weapon tip.
                yy,xx = np.where(local[int(h*.35):int(h*.8)])
                ax = float(np.median(xx)) if len(xx) else ax
        entries.append(dict(sheet=f'res://assets/pixel_v1/{key}_raw.png',rect=[x0,y0,w,h],anchor=[round(ax,2),h+8 if mechanical else h]))
    left = max(e['anchor'][0] for e in entries)
    right = max(e['rect'][2]-e['anchor'][0] for e in entries)
    height = max(e['anchor'][1] for e in entries)
    factor = min(46/(left+right),62/height)
    native_ax = max(1,min(47,round(1+left*factor)))
    factor = min(factor,(native_ax-1)/left,(47-native_ax)/right)
    config = dict(source_frames=entries,source_scale=round(factor,7),frame_anchor=[native_ax,64],
                  scale={'guard':4,'elite':6,'boss':5,'instrument':3,'observer':5,'anchor':2,'musheng':3}[key],
                  mechanical=mechanical,animations=animations(mechanical,key=='musheng'))
    covered = np.zeros_like(mask)
    for e in entries:
        x,y,w,h = e['rect']
        covered[y:y+h,x:x+w] = True
        s = config['source_scale']
        dx = native_ax-round(e['anchor'][0]*s)
        dy = 64-round(e['anchor'][1]*s)
        assert dx >= 0 and dy >= 0 and dx+round(w*s)<=48 and dy+round(h*s)<=64, (key,e,dx,dy)
    print('canvas fit OK; uncovered alpha>=100 pixels:',int(np.sum(mask & ~covered)))
    print(key,'components',len(groups),'main counts',[g[4] for g in ordered], 'scale',config['source_scale'],'anchor',native_ax)
    print('rects', [e['rect'] for e in entries])
    return config

if __name__ == '__main__':
    output = {key:map_actor(key) for key in KEYS if (ROOT/'assets/pixel_v1'/f'{key}_raw.png').exists()}
    (ROOT/'assets/pixel_v1/roster_frames.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
