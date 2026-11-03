# Mini pixel framework: shapes -> masks, 3-tone rim shading (light from upper-left), auto outline.
from PIL import Image
W,H=32,40
def hx(s): s=s.lstrip('#'); return tuple(int(s[i:i+2],16) for i in (0,2,4))
class Canvas:
    def __init__(s): s.px={}  # (x,y)->color
    def shape(s,pts,tones,flat=False):
        pts=set(pts); L,M,D=tones
        for (x,y) in pts:
            if flat: c=M
            else:
                lit=((x-1,y) not in pts) or ((x,y-1) not in pts)
                drk=((x+1,y) not in pts) or ((x,y+1) not in pts)
                c=L if lit and not drk else (D if drk and not lit else M)
                if lit and drk: c=M
            s.px[(x,y)]=c
    def put(s,x,y,c): s.px[(x,y)]=c
    def outline(s,warm,cool,warmset):
        out={}
        for (x,y),c in list(s.px.items()):
            for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
                n=(x+dx,y+dy)
                if n not in s.px and 0<=n[0]<W and 0<=n[1]<H:
                    out[n]=warm if c in warmset else cool
        s.px.update(out)
    def img(s):
        im=Image.new('RGBA',(W,H),(0,0,0,0))
        for (x,y),c in s.px.items():
            if 0<=x<W and 0<=y<H: im.putpixel((x,y),c+(255,))
        return im
def rect(x0,y0,x1,y1): return [(x,y) for x in range(x0,x1+1) for y in range(y0,y1+1)]
def ell(cx,cy,rx,ry): return [(x,y) for x in range(int(cx-rx-1),int(cx+rx+2)) for y in range(int(cy-ry-1),int(cy+ry+2)) if ((x-cx)/(rx+.4))**2+((y-cy)/(ry+.4))**2<=1]
