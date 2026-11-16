#!/usr/bin/env python3
"""Drop 02: original CC0 1.0 pixel paintings. Pillow + standard library only.

Cloth and trim are sampled in the same physical coordinates on the cloak and
its triangular wings. No random numbers, antialiasing, downloads or model art.
Drop 01 is read only; its painting helpers are imported without calling main.
"""
import importlib.util
import json
import math
import sys
from pathlib import Path
from PIL import Image

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = ROOT.parent / "drop-01"
spec = importlib.util.spec_from_file_location("original_painter", ORIGINAL/"src/paint.py")
old = importlib.util.module_from_spec(spec)
spec.loader.exec_module(old)
Paint, star = old.Paint, old.star

# Supplied model: half-width 2.05 model units / .525; height 16 skin units.
# Wings: width 3, angle 20 degrees, thickness .35; hinge inset into the box.
HALF = 2.05 / .525
HEIGHT = 16.0
INSET = .35 / 2 * math.sin(math.radians(20)) + .05
HINGE = HALF - INSET
SPAN = 3.0 + INSET
SLOPE = SPAN / HEIGHT
NORMAL = math.hypot(1, SLOPE)
CATALOG = []
ORIGINALS = ("hearthkeeper_1", "aurora_1", "moonsilk_2", "moonsilk_3",
             "royal_ermine_1", "royal_ermine_3")
NAMES = ("Emberwake", "Veilstream", "Pearlwing", "Moonfall", "Wintercourt", "Frost Regent")


def lerp_table(value, points):
    if value <= points[0][0]:
        return points[0][1]
    for (x0,y0),(x1,y1) in zip(points, points[1:]):
        if value <= x1:
            return y0+(y1-y0)*(value-x0)/(x1-x0)
    return points[-1][1]


def outline(y):
    return max(HALF, HINGE + SPAN*y/HEIGHT)


def distance(x,y):
    """Physical distance inside the slanted outline or bottom, not UV pixels."""
    return min((outline(y)-abs(x))/NORMAL, HEIGHT-y)


def xy(panel, x, y):
    if panel == "cloak":
        return (x+.5-8)*HALF/8, (y+.5)*.5
    return -(HINGE+(7.5-x)*SPAN/8), (y+.5)*.5


class Garment:
    def __init__(self, original, colors=None):
        data = next(v for v in json.loads((ORIGINAL/"catalog.json").read_text()) if v["id"]==original)
        self.original, self.name = original, data["name"]
        self.colors = colors or " ".join(data["palette"])
        self.c = Paint(self.colors)
        self.w = Paint(self.colors,8)
        self.l = Paint(self.colors)
        self.wl = Paint(self.colors,8)

    def base(self, dark=0, mid=1, light=None):
        old.cloth(self.c,dark,mid,light)
        # A wing shares the neighbouring calm outer fold, rather than inventing
        # its own central highlight at the seam.
        self.w.rect((0,0,7,31),dark)
        return self

    def sample(self, fn):
        for key,p in (("cloak",self.c),("wing",self.w)):
            for y in range(32):
                for x in range(p.im.width):
                    color = fn(*xy(key,x,y), key, x, y)
                    if color is not None:
                        p.dot(x,y,color)

    def trim(self, width, color, shadow=None):
        def f(x,y,panel,px,py):
            # The two atlases have different texel widths. Use the physical
            # join for their boundary texels, so the border changes colour on
            # the same row on both sides instead of making a one-texel jog.
            if (panel=="cloak" and px in (0,15)) or (panel=="wing" and px==7):
                x=math.copysign(HALF,x)
            d=distance(x,y)
            if d <= width:
                return shadow if shadow is not None and d>width-.18 else color
        self.sample(f)

    def lining(self, dark=0, mid=1, trim=3, width=.4):
        old.cloth(self.l,dark,mid)
        self.wl.rect((0,0,7,31),dark)
        for key,p in (("cloak",self.l),("wing",self.wl)):
            for y in range(32):
                for x in range(p.im.width):
                    if distance(*xy(key,x,y)) <= width:
                        p.dot(x,y,trim)
        # wl is still in outer-face orientation; save() mirrors it for the lining.

    def save(self, version, idea):
        cid=f"{self.original}_{version}"
        cloak=Image.new("RGBA",(32,32));cloak.paste(self.c.im,(0,0));cloak.paste(self.l.im,(16,0))
        wings=Image.new("RGBA",(16,32));wings.paste(self.w.im,(0,0))
        wings.paste(self.wl.im.transpose(Image.Transpose.FLIP_LEFT_RIGHT),(8,0))
        cloak.save(ROOT/"art"/f"cloak_{cid}.png",optimize=False)
        wings.save(ROOT/"art"/f"wings_{cid}.png",optimize=False)
        CATALOG.append(dict(id=cid, original_id=self.original, name=self.name,
                            refinement=version, wings=True, palette=self.colors.upper().split(),
                            changes=idea))


def ember(version):
    bold=version=="r2"
    colors="#2B202B #623744 #C34C46 #F58E5D #FFE4B5 #CCD3D8" if bold else None
    g=Garment("hearthkeeper_1",colors).base()
    if not bold:
        # Keep the familiar flame shapes, removing the obsolete interior binding.
        im=Image.open(ORIGINAL/"art/cloak_hearthkeeper_1.png").convert("RGBA")
        for y in range(1,32):
            for x in range(1,15):
                g.c.im.putpixel((x,y),im.getpixel((x,y)))
        for y in range(1,32):
            g.c.im.putpixel((0,y),g.c.im.getpixel((1,y)))
            g.c.im.putpixel((15,y),g.c.im.getpixel((14,y)))
    red=[(0,12),(1,16),(2,23),(4,18),(5,25),(6,23),(7,25),(8,23),(9,25),(10,21),(11,27),(12,25),(14,30)]
    orange=[(0,22),(1,26),(2,27),(4,24),(6,29),(8,28),(10,25),(12,29),(14,31)]
    def fire(x,y,panel,*_):
        if not bold and panel=="cloak": return None
        u=abs(x)*8/HALF; row=y*2
        if row>=26+u*.60 and u<5: return 4
        if row>=lerp_table(u,orange): return 3
        if row>=lerp_table(u,red): return 2
        if bold and y<2.5 and abs(x)<HALF-.5:return 1
        return None
    g.sample(fire)
    g.trim(.43 if bold else .30,5)
    g.c.rect((2,0,13,0),5)
    g.lining(trim=3)
    g.save(version,
           "The flame field is redrawn as larger nested tongues spanning the cloak and wings, with a warmer shoulder and a brighter core. A continuous silver perimeter replaces the internal side bindings." if bold else
           "The central flame painting is retained; silver bindings move from the cloak/wing seams to the whole outer outline. Wing flames are quieter and the lining's hem now follows the same perimeter.")


def aurora(version):
    bold=version=="r2"
    colors="#211C34 #3D3057 #8B5DB6 #278F99 #A1F0CF #D0E3E6" if bold else None
    g=Garment("aurora_1",colors).base()
    knots=[(0,21),(2,22),(5,20),(10,18),(12,18),(16,21)]
    if bold:knots=[(0,21),(3,23),(6,20),(10,16),(12,16),(16,21)]
    def lights(x,y,*_):
        u=8+x*8/HALF
        if 0<=u<=16: center=lerp_table(u,knots)
        else: center=knots[0][1]+(abs(x)-HALF)*2
        d=y*2-center
        if -1.5<=d<(.5 if bold else -.1):return 4
        if -.1<=d<2.5:return 3
        if -5.5<=d<-3:return 2
    g.sample(lights)
    # Both ends return to one height: a mirrored wing can join both sides.
    g.trim(.30,2 if bold else 1)
    for x,y in [(4,6),(11,4)]:star(g.c,x,y,5)
    if bold:g.c.dot(9,8,3)
    g.lining(trim=3)
    g.save(version,
           "A broader mint ribbon makes a deeper S-curve, with a restrained violet echo and a fine violet outline. Both ends meet their mirrored wings at one height so the light wraps the garment." if bold else
           "The diagonal light ribbon curls gently back to a shared height at both hinges, fixing the mismatched wing bands. Its bright edge is kept narrow, with the original two stars and dark field.")


def pearl(version):
    bold=version=="r2"
    colors="#655F80 #A3A0B8 #D4DBE3 #FFF5EC #89C5C1 #C9A5C6" if bold else None
    g=Garment("moonsilk_2",colors).base(1,2,3)
    p=g.c
    p.rect((0,0,15,31),2)
    p.poly([(1,0),(7,0),(6,4),(3,7)],3)
    p.poly([(1,2),(7,7),(14,2),(12,12),(8,21),(3,12)],3)
    p.poly([(1,9),(6,17),(7,27),(3,23)],4)
    p.poly([(14,8),(10,18),(8,27),(13,22)],5)
    if bold:
        p.poly([(2,6),(6,12),(8,24),(5,21)],3)
        p.poly([(14,7),(12,15),(9,27),(13,23)],5)
        p.line([(4,16),(6,21),(7,27)],4,2)
    # Broad pale surfaces reach the hinge; facets taper within them.
    def wing_fold(x,y,panel,*_):
        if panel!="wing":return None
        q=max(0,(abs(x)-HALF)/SPAN)
        if q>y/HEIGHT:return 2
        if y<5 or q>y/HEIGHT*.76:return 3
        if 8<y<13.5 and .18<q<.42:return 4
        if bold and y>12.5 and q>.35:return 5
        return 2
    g.sample(wing_fold)
    # Preserve the pearl fan's curved decorative hem, joining both endpoints
    # to the wings. The thinner perimeter binding follows the real silhouette.
    def pearl_arc(x,y,*_):
        if abs(x)<=HALF:
            t=abs(x)/HALF
            row=29.5-4.5*t*t
        else:row=25+5*(abs(x)-HALF)/SPAN
        delta=y*2-row
        if 0<=delta<1:return 0 if bold else 1
        if 1<=delta<2:return 3
    g.sample(pearl_arc)
    g.trim(.42 if bold else .30,0 if bold else 1)
    if bold:
        g.sample(lambda x,y,*_:3 if .42<distance(x,y)<.88 else None)
    star(p,7,5,0,True)
    g.lining(trim=4)
    g.save(version,
           "Longer mint and blush folds strengthen the pearl fan, with an ivory inset beside a continuous dusk-silver perimeter. The curved pearl hem joins the wings, which share the pale body field and larger opalescent facets." if bold else
           "The pearl fan and clasp are preserved while the curved hem is aligned across both hinges and given a fine perimeter binding. Pale wing fields meet the body more calmly, with fewer small facet fragments.")


def moon(version):
    bold=version=="r2"
    colors="#514B6D #807D9F #C2C9DA #FFF1DF #A6D3D0 #D6B9D1" if bold else None
    g=Garment("moonsilk_3",colors).base(0,1,2)
    p=g.c
    p.poly([(10,3),(6,4),(3,8),(2,14),(3,20),(6,24),(11,25),(8,21),(6,16),(6,11),(8,7)],3)
    p.line([(10,3),(6,4),(3,8),(2,14)],4)
    if bold:
        p.poly([(3,10),(4,9),(4,16),(6,21),(9,24),(6,23),(3,19)],3)
    def hem(x,y,*_):
        u=8+x*8/HALF
        if 0<=u<=16: top=lerp_table(u,[(0,27),(4,28),(8,28),(10,27),(13,26),(16,27)])
        else: top=27+(abs(x)-HALF)*.9
        d=y*2-top
        if 0<=d<1:return 5
        if 1<=d<3.5:return 2
    g.sample(hem)
    g.trim(.40 if bold else .26,3 if bold else 2)
    star(p,11,12,3,True)
    star(g.w,5,19,3,True)
    if bold:p.dot(11,20,4)
    g.lining(trim=4)
    g.save(version,
           "A deeper lavender field and a fuller ivory crescent sharpen the moon at distance. The sweeping pearl hem returns to both hinges at the same height, framed by a brighter continuous moonlit edge." if bold else
           "The crescent and star remain unchanged, while the pearl hem is redrawn to meet both mirrored wings cleanly. One fine silver outline replaces the disconnected wing tips.")


def winter(version):
    bold=version=="r2"
    colors="#2D2039 #593175 #815797 #BCB9CE #F8F1E9 #DED7E1" if bold else None
    g=Garment("royal_ermine_1",colors).base(0,1,2)
    if bold:
        g.c.poly([(3,8),(6,9),(5,23),(3,25)],2)
        g.c.poly([(11,8),(13,7),(12,24),(10,25)],0)
    def collar(x,y,*_):
        u=min(1,abs(x)/HALF)
        bottom=lerp_table(u,[(0,4.1 if bold else 4),(0.5,3.7),(1,2.5)])
        if y<bottom-.75:return 4
        if y<bottom:return 5
    g.sample(collar)
    for x,y in [(2,1),(7,3),(12,1)]:old.tuft(g.c,x,y)
    g.trim(.56 if bold else .34,4,3)
    if bold:
        # Small silver stitches stay low and ordered; the velvet field is quiet.
        for x in (4,11):g.c.dot(x,29,3)
    g.lining(trim=3)
    g.save(version,
           "The velvet gains two broad, top-lit folds and a slightly fuller fur collar. A wider ivory-and-silver binding runs around the entire garment, with just two low silver stitches." if bold else
           "The broad ermine collar is preserved and extends into the narrow wing shoulders. The detached hem bars become one restrained ivory-and-silver binding around the cloak and wings.")


def frost(version):
    bold=version=="r2"
    g=Garment("royal_ermine_3").base(0,1,2)
    # A single widening velvet field; no full-height stripes at the hinges.
    g.c.rect((0,0,15,31),1)
    g.c.poly([(3,0),(8,0),(6,10),(4,25),(3,25)],2)
    g.w.rect((0,0,7,31),1)
    width=1.32 if bold else 1.02
    g.trim(width,4,5)
    # Upper-left fur receives the light. A shaded underside preserves the hem.
    g.sample(lambda x,y,*_:5 if HEIGHT-y<.28 else None)
    side_ys=(2.0,5.7,9.5,13.0) if bold else (2.0,6.4,10.8)
    centers=[(outline(y)-width*.51*NORMAL,y) for y in side_ys]
    bottom_x=(1.4,3.6,5.5) if bold else (1.7,5.1)
    centers += [(x,HEIGHT-width*.52) for x in bottom_x]
    def tufts(x,y,*_):
        if distance(x,y)>width-.15:return None
        for cx,cy in centers:
            dx,dy=abs(x)-cx,y-cy
            if (abs(dx)<.16 and -.48<dy<.30) or (abs(dx)<.36 and .18<dy<.48):return 0
    g.sample(tufts)
    p=g.c
    if bold:
        p.poly([(7,7),(10,12),(7,18),(4,12)],3)
        p.poly([(7,9),(8,12),(7,15),(6,12)],0)
        p.line([(7,8),(5,12),(7,16)],4)
        p.dot(7,12,5)
    else:
        p.poly([(7,8),(9,12),(7,17),(5,12)],3)
        p.poly([(7,9),(8,12),(7,14),(6,12)],2)
        p.dot(7,9,4)
    g.lining(trim=3,width=.35)
    g.save(version,
           "A fuller ermine frame follows the joined outer outline at a constant physical width, with a denser tuft rhythm and a larger hollow silver lozenge. The violet interior opens into the wings instead of remaining trapped in a narrow middle panel." if bold else
           "The duplicated vertical fur stripes are replaced by one narrow ermine frame measured across cloak and wings. It leaves the upper middle panel for the slanted wing edges and bottom, opening a wider violet field around the original silver lozenge.")


def main():
    (ROOT/"art").mkdir(parents=True,exist_ok=True)
    for painter in (ember,aurora,pearl,moon,winter,frost):
        for version in ("r1","r2"):painter(version)
    (ROOT/"catalog.json").write_text(json.dumps(CATALOG,indent=2)+"\n")
    lines=["# Drop 02 — refinement notes", "", "Original CC0 1.0 art. Every refinement has wings; names are unchanged. Palettes list the colours used by the cloak and its wings.", ""]
    for v in CATALOG:
        lines += [f"## {v['id']}","",f"- Name: **{v['name']}**","- Wings: yes",
                  "- Palette: "+", ".join(v["palette"]),"",v["changes"],""]
    (ROOT/"notes.md").write_text("\n".join(lines))
    print("Painted 12 refinements and 12 matching wing sheets.")


if __name__=="__main__":main()
