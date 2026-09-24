"""Read PNG alpha only and write Godot atlas rectangles; never alter image pixels."""
import json
from pathlib import Path
import numpy as np
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'assets/porcelain_desk/craft'
def main_component(mask):
    # Run-length connected-component analysis of alpha; produces metadata only.
    parents=[];counts=[];boxes=[];previous=[]
    def find(i):
        while parents[i]!=i:
            parents[i]=parents[parents[i]];i=parents[i]
        return i
    for y,row in enumerate(mask):
        edges=np.diff(np.pad(row.astype(np.int8),(1,1)))
        starts=np.flatnonzero(edges==1);ends=np.flatnonzero(edges==-1)
        current=[]
        for left,right in zip(starts,ends):
            left=int(left);right=int(right);i=len(parents)
            parents.append(i);counts.append(right-left);boxes.append([left,y,right,y+1])
            for pl,pr,pi in previous:
                if pl<right and pr>left:
                    target=find(pi);source=find(i)
                    if target!=source:
                        parents[source]=target;counts[target]+=counts[source]
                        a,b=boxes[target],boxes[source]
                        boxes[target]=[min(a[0],b[0]),min(a[1],b[1]),max(a[2],b[2]),max(a[3],b[3])]
            current.append((left,right,i))
        previous=current
    roots=[i for i in range(len(parents)) if find(i)==i]
    return boxes[max(roots,key=lambda i:counts[i])]
GUIDES = {
 'yuan_a': [0,282,553,825,1098,1355,1585,1916],
 'yuan_b': [0,282,552,825,1100,1372,1615,1916],
 'ming_a': [0,295,575,855,1135,1390,1623,1916],
 'ming_b': [0,309,611,909,1200,1445,1640,1916],
 'qing_a': [0,294,577,856,1140,1390,1618,1916],
 'qing_b': [0,280,552,827,1100,1350,1590,1916],
 'republic_a': [0,315,630,937,1234,1480,1670,1916],
 'republic_b': [0,326,635,945,1246,1455,1640,1916],
}
for p in sorted(FOLDER.glob('*.png')):
    im=Image.open(p).convert('RGBA'); w,h=im.size
    a=np.asarray(im)[:,:,3]
    identity=p.stem.rsplit('_',1)[0]
    if p.stem=='republic_a_hidden': identity='ming_a'
    if p.stem=='republic_b_hidden': identity='ming_b'
    guides=[round(v*h/1916) for v in GUIDES[identity]]
    # Find the local inter-row valley to account for generated spacing drift.
    projection=np.count_nonzero(a>150,axis=1)
    bounds=[0]
    for g in guides[1:-1]:
        lo=max(bounds[-1]+60,g-22); hi=min(h-1,g+22)
        smoothed=np.convolve(projection,np.ones(3)/3,mode='same')
        values=smoothed[lo:hi]
        candidates=np.flatnonzero(values <= values.min()+2)+lo
        cut=int(candidates[np.argmin(abs(candidates-g))])
        bounds.append(cut)
    bounds.append(h)
    rects=[]
    for row in range(7):
        for col in range(3):
            x0=max(0,round(col*w/3)-50); x1=min(w,round((col+1)*w/3)+60)
            y0,y1=bounds[row:row+2]
            mask=a[y0:y1,x0:x1]>(8 if row==6 else 80)
            bx,by,br,bb=main_component(mask)
            left=max(x0,x0+bx-2);right=min(x1,x0+br+2)
            top=max(y0,y0+by-2);bottom=min(y1,y0+bb+2)
            rects.append([left,top,right-left,bottom-top])
    p.with_suffix('.regions.json').write_text(json.dumps({'size':[w,h],'rects':rects,'rows':bounds}),encoding='utf-8')
    print(p.stem, im.size, 'rows', bounds)
