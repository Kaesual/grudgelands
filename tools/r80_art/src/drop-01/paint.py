#!/usr/bin/env python3
"""Original cloak paintings, CC0 1.0. Python 3 + Pillow; no external art.

Run from any directory: python3 art/drop-01/src/paint.py
All coordinates are native texels. No antialiasing, resampling, or randomness.
The wings' unused texels remain painted to give the diagonal a safe opaque guard.
"""
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art"
CATALOG = []


class Paint:
    def __init__(self, colors, width=16):
        self.colors = colors.split()
        self.im = Image.new("RGBA", (width, 32), self.colors[0])
        self.d = ImageDraw.Draw(self.im)

    def rect(self, box, c):
        self.d.rectangle(box, fill=self.colors[c])

    def poly(self, points, c):
        self.d.polygon(points, fill=self.colors[c])

    def line(self, points, c, width=1):
        self.d.line(points, fill=self.colors[c], width=width)

    def dot(self, x, y, c):
        self.d.point((x, y), fill=self.colors[c])

    def rows(self, x, y, rows, mapping):
        for j, row in enumerate(rows):
            for i, char in enumerate(row):
                if char != ".":
                    self.dot(x + i, y + j, mapping[char])


def cloth(p, dark=0, mid=1, light=None):
    """Broad woven folds: upper-left light, shadow toward the bottom/right."""
    w = p.im.width
    p.rect((0, 0, w-1, 31), dark)
    p.poly([(1, 0), (w-3, 0), (w-4, 9), (w-5, 26), (2, 29)], mid)
    if light is not None:
        p.poly([(2, 0), (w//2, 0), (w//2-1, 5), (3, 7)], light)


def binding(p, c, shade=None, bottom=True):
    p.line([(0, 1), (0, 31)], c)
    p.line([(15, 1), (15, 31)], c if shade is None else shade)
    if bottom:
        p.line([(0, 31), (15, 31)], c if shade is None else shade)


def star(p, x, y, c, large=False):
    p.dot(x, y, c)
    if large:
        p.line([(x-1, y), (x+1, y)], c)
        p.line([(x, y-1), (x, y+1)], c)


def lining(colors, base=0, fold=1, trim=4):
    p = Paint(colors)
    cloth(p, base, fold)
    p.rect((0, 29, 15, 29), trim)
    p.rect((0, 31, 15, 31), base)
    return p


def wing(colors, kind, base=0, fold=1):
    """Paint the left outer triangle at x 0..7, then its reflected lining."""
    p = Paint(colors, 8)
    cloth(p, base, fold)
    if kind == "fire":
        p.poly([(0, 31), (0, 25), (2, 27), (3, 18), (4, 24), (6, 13), (7, 20), (7, 31)], 2)
        p.poly([(0, 31), (2, 29), (3, 24), (4, 28), (6, 21), (7, 26), (7, 31)], 3)
        p.line([(1, 31), (4, 31), (6, 27), (7, 28)], 4)
        p.line([(7, 0), (0, 31)], 5)
    elif kind == "ash":
        p.poly([(7, 0), (7, 31), (0, 31), (3, 20), (4, 23), (6, 12)], 2)
        p.poly([(0, 31), (3, 25), (4, 27), (6, 18), (7, 23), (7, 31)], 4)
        p.poly([(3, 31), (5, 27), (7, 25), (7, 31)], 5)
        p.line([(7, 0), (0, 31)], 3)
    elif kind == "ribbon":
        p.poly([(0, 26), (7, 17), (7, 21), (0, 30)], 3)
        p.line([(0, 27), (7, 18)], 4)
        p.poly([(0, 21), (7, 12), (7, 14), (0, 23)], 2)
        p.line([(7, 1), (0, 31)], 1)
        p.line([(1, 31), (7, 31)], 2)
    elif kind == "horizon":
        p.poly([(0, 24), (7, 18), (7, 25), (0, 29)], 2)
        p.line([(0, 25), (7, 20)], 4, 2)
        p.line([(0, 29), (7, 25)], 3)
        p.line([(7, 0), (0, 31)], 5)
        p.line([(0, 31), (7, 31)], 5)
    elif kind == "rose":
        p.poly([(7, 9), (0, 31), (3, 31), (7, 19)], 2)
        p.poly([(7, 20), (4, 31), (7, 31)], 3)
        p.line([(0, 31), (7, 17)], 0)
        p.line([(2, 31), (7, 19)], 0)
        p.line([(7, 0), (0, 31)], 4)
        p.line([(0, 31), (7, 31)], 0)
    elif kind == "prism":
        p.poly([(7, 0), (2, 25), (7, 16)], 4)
        p.poly([(1, 26), (7, 18), (7, 30)], 2)
        p.poly([(1, 28), (7, 31), (0, 31)], 3)
        p.line([(7, 0), (0, 31)], 0)
        p.line([(2, 25), (7, 17)], 0)
        p.line([(1, 27), (7, 31)], 0)
        p.line([(0, 31), (7, 31)], 0)
    elif kind == "pearl":
        p.poly([(7, 0), (0, 31), (7, 25)], 3)
        p.poly([(7, 8), (3, 27), (7, 22)], 4)
        p.line([(0, 30), (7, 24)], 5)
        p.line([(0, 31), (7, 27)], 1)
        p.line([(7, 0), (0, 31)], 2)
    elif kind == "beam":
        p.poly([(7, 14), (0, 31), (7, 31)], 2)
        p.poly([(7, 22), (3, 31), (7, 31)], 3)
        p.line([(7, 0), (0, 31)], 5)
        p.line([(0, 31), (7, 31)], 4)
    elif kind == "watch":
        p.poly([(7, 0), (0, 31), (3, 31), (7, 13)], 4)
        p.poly([(4, 31), (7, 19), (7, 31)], 2)
        p.line([(7, 0), (0, 31)], 5)
        p.line([(1, 31), (7, 31)], 3)
    elif kind == "court":
        p.line([(7, 0), (0, 31)], 4, 2)
        p.line([(0, 30), (7, 30)], 3)
        p.line([(0, 31), (7, 31)], 4)
    elif kind == "ermine":
        p.poly([(7, 0), (0, 31), (3, 31), (7, 12)], 4)
        for x, y in [(5, 14), (3, 23), (1, 30)]:
            p.dot(x, y-2, 0)
            p.line([(x, y-1), (x, y)], 0)
        p.line([(7, 0), (0, 31)], 3)
        p.line([(0, 31), (7, 31)], 3)
    elif kind == "hearth":
        # Small paired fires frame the central hearth instead of a flame field.
        p.poly([(2,30),(3,25),(4,20),(5,25),(6,23),(7,30)],2)
        p.poly([(3,30),(4,25),(5,28),(6,26),(6,30)],3)
        p.dot(4,29,4)
        p.line([(7,2),(1,28),(1,31),(7,31)],5)
    elif kind == "curtain":
        # Vertical hanging lights echo the main cloth, inside the sampled wedge.
        for x,top,bottom in [(3,19,29),(6,8,26)]:
            p.rect((x,top,x+1,bottom-3),2)
            p.line([(x,top),(x,bottom-1)],3)
            p.line([(x+1,top+1),(x+1,bottom-5)],4)
            p.dot(x,bottom,5)
        p.line([(1,31),(7,31)],5)
    elif kind == "lancet":
        # Large leaded panes repeat the window's horizontal mullion at row 21.
        p.poly([(7,5),(2,24),(2,28),(7,28)],2)
        p.poly([(7,11),(4,21),(4,27),(7,27)],3)
        p.line([(6,16),(6,20)],4)
        p.line([(1,21),(7,21)],0)
        p.line([(3,20),(3,28)],0)
        p.line([(7,5),(2,24)],5)
        p.line([(2,28),(7,28)],5)
        p.line([(1,29),(7,29)],0)
    elif kind == "stars":
        # Same pearl field, star scale and two-row selvedge as the outer cloak.
        p.poly([(7,0),(4,14),(6,11)],3)
        star(p,4,26,0,True)
        p.dot(7,27,0)
        p.rect((0,30,7,30),4)
        p.rect((0,31,7,31),0)
    elif kind == "moonwake":
        p.poly([(0,31),(3,29),(7,24),(7,31)],2)
        p.line([(0,31),(3,30),(7,26)],5)
        p.line([(1,29),(4,27),(7,23)],3)
        star(p,5,19,3,True)
        p.dot(2,30,0)
    elif kind == "rays":
        # Separate rays around the halo, distinct from Dawnwatch's solid beam.
        p.poly([(7,14),(2,24),(1,29),(7,26)],2)
        p.line([(7,17),(3,24)],3)
        p.line([(7,23),(3,28)],3)
        p.dot(3,24,4)
        p.dot(3,28,4)
        p.line([(7,1),(0,31)],5)
        p.line([(1,31),(7,31)],5)
    elif kind == "stole":
        # Low fur cuffs echo the diagonal sash without a full ermine frame.
        p.poly([(7,22),(0,28),(0,31),(4,31),(7,28)],5)
        p.poly([(7,23),(1,28),(1,30),(4,30),(7,27)],4)
        p.line([(7,21),(1,27)],3)
        p.dot(4,26,0)
        p.line([(4,27),(4,28)],0)
        p.line([(3,29),(5,29)],0)
    else:
        raise ValueError(kind)
    back = Paint(colors, 8)
    cloth(back, base, fold)
    # The lining's hinge is its left edge, unlike the exterior's right edge.
    back.line([(7, 0), (0, 31)], 1)
    back.line([(0, 30), (7, 30)], 3 if kind != "ermine" else 4)
    # New wings use the cloak's actual lining colours and trim height.
    if kind in {"hearth", "curtain", "lancet", "stars", "moonwake", "rays", "stole"}:
        cloth(back,0,1)
        trim = {"hearth":4,"curtain":5,"lancet":3,"stars":4,
                "moonwake":4,"rays":3,"stole":3}[kind]
        back.line([(0,29),(7,29)],trim)
        back.line([(0,31),(7,31)],0)
    sheet = Image.new("RGBA", (16, 32))
    sheet.paste(p.im, (0, 0))
    sheet.paste(back.im.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (8, 0))
    return sheet


def save(cid, name, colors, idea, p, inner=None, wings=None):
    if wings is None:
        raise ValueError(f"Reward cloak {cid} requires matching wings")
    if inner is None:
        inner = lining(colors)
    im = Image.new("RGBA", (32, 32))
    im.paste(p.im, (0, 0))
    im.paste(inner.im, (16, 0))
    im.save(ART / f"cloak_{cid}.png", optimize=False)
    if wings is not None:
        wings.save(ART / f"wings_{cid}.png", optimize=False)
    CATALOG.append(dict(id=cid, name=name, wings=wings is not None,
                        palette=colors.upper().split(), idea=idea))


def hearthkeeper():
    c = "#281E2A #56303C #B44846 #EF8555 #FFE1AF #BDC7CD"
    p = Paint(c); cloth(p)
    p.poly([(1,31),(1,23),(3,26),(4,18),(6,23),(8,12),(10,20),(12,17),(13,25),(14,23),(14,31)],2)
    p.poly([(2,31),(4,27),(5,23),(7,27),(8,19),(10,25),(12,22),(13,29),(14,31)],3)
    p.poly([(5,31),(7,27),(8,25),(9,28),(11,31)],4)
    binding(p,5,5,False); p.rect((2,0,13,0),5)
    save("hearthkeeper_1","Emberwake",c,
         "A quiet oxblood shoulder opens into rising ember tongues. Silver edges and flame-painted wings carry the glow around the silhouette.",
         p, lining(c,0,1,3), wing(c,"fire"))

    p = Paint(c); cloth(p)
    p.line([(2,24),(2,10),(4,7),(7,5),(8,5),(11,7),(13,10),(13,24)],5)
    p.line([(3,24),(12,24)],5)
    p.rows(4,10,["....r...","...rr...","...ro...","..roo...","..roo.r.",".rooor..",".rooorr.","rooooor.","roowoor.",".rwwwr..","..rrr..."],{"r":2,"o":3,"w":4})
    p.rect((3,28,12,28),2); p.rect((5,29,10,29),3)
    save("hearthkeeper_2","Hearthseal",c,
         "One sheltered flame sits inside a pointed silver hearth frame. Small flames and silver bindings on the wings flank the emblem, preserving its quiet ceremonial focus.",
         p,wings=wing(c,"hearth"))

    c = "#382C3B #68515C #B6A8B1 #F0E7E4 #BF5047 #F6A16C"
    p = Paint(c); cloth(p,0,2,3)
    p.poly([(0,0),(3,0),(5,15),(8,24),(10,16),(13,0),(15,0),(15,31),(0,31)],1)
    p.poly([(0,0),(2,0),(3,15),(7,29),(9,29),(13,15),(14,0),(15,0),(15,31),(0,31)],0)
    p.poly([(0,31),(0,22),(3,26),(4,22),(8,29),(11,20),(12,25),(15,22),(15,31)],4)
    p.poly([(2,31),(4,27),(8,30),(11,25),(13,29),(15,27),(15,31)],5)
    p.line([(1,0),(3,13),(7,25)],3)
    p.line([(14,0),(12,14),(9,25)],2)
    save("hearthkeeper_3","Ashen Dawn",c,
         "Pale ash silk falls in a long taper over charcoal, with a hot coral hem. Broad light folds and silver-edged wings make a brighter interpretation of the fire.",
         p,lining(c,0,1,5),wing(c,"ash"))


def aurora():
    c = "#201D35 #352C50 #8053AD #248D94 #8DE9BE #C5DCE2"
    p = Paint(c); cloth(p)
    p.poly([(1,16),(5,13),(10,12),(14,8),(14,12),(10,16),(5,17),(1,20)],2)
    p.poly([(1,21),(5,18),(10,17),(14,13),(14,18),(10,21),(5,22),(1,25)],3)
    p.line([(1,22),(5,19),(10,18),(14,14)],4,2)
    p.line([(2,30),(13,30)],2)
    star(p,4,6,5); star(p,11,4,5)
    save("aurora_1","Veilstream",c,
         "A single sweeping mint ribbon crosses a violet night field, with a second dim violet echo. The ribbon continues into the wings as a wide, readable gesture.",
         p,lining(c,0,1,3),wing(c,"ribbon"))

    c = "#172B31 #25424B #3C757E #48BCAB #A6E6C7 #8D73B8"
    p = Paint(c); cloth(p)
    for x, top, bottom in [(2,6,22),(6,3,27),(10,7,24)]:
        p.rect((x,top,x+2,bottom-3),2)
        p.rect((x,top,x,bottom-1),3)
        p.rect((x+1,top+2,x+1,bottom-5),4)
        p.dot(x,bottom,5)
    p.poly([(1,4),(5,1),(9,2),(14,5),(14,7),(9,4),(5,3),(1,6)],3)
    p.line([(1,4),(5,1),(9,2),(14,5)],4)
    p.line([(3,30),(12,30)],5)
    save("aurora_2","Still Curtain",c,
         "Three long curtains of green light descend from a luminous shoulder arc. More hanging lights cross the wings, keeping the vertical rhythm and generous dark gaps across the whole garment.",
         p,lining(c,0,1,5),wing(c,"curtain"))

    c = "#242037 #3A3558 #437D96 #9470C2 #A3EDDA #C6D8E5"
    p = Paint(c); cloth(p)
    p.line([(2,22),(2,13),(4,8),(6,6),(9,6),(11,8),(13,13),(13,22)],2,2)
    p.line([(3,18),(3,12),(6,7),(9,7),(12,12),(12,18)],4)
    p.poly([(1,24),(5,22),(10,22),(14,24),(14,28),(10,26),(5,26),(1,28)],2)
    p.line([(1,25),(5,23),(10,23),(14,25)],4)
    p.line([(1,29),(5,27),(10,27),(14,29)],3)
    star(p,7,15,5,True)
    binding(p,5,2)
    save("aurora_3","Polar Halo",c,
         "An arched aurora shelters one star above a low horizon of mint and violet. Silver-edged wings extend the horizon into a luminous fan.",
         p,lining(c,0,1,3),wing(c,"horizon"))


def stained_glass():
    c = "#231F35 #40304E #A34276 #3A9C9A #9CD9CC #C4A1D8"
    p = Paint(c); cloth(p)
    p.poly([(1,29),(1,10),(3,6),(7,2),(8,2),(12,6),(14,10),(14,29)],0)
    p.poly([(2,28),(2,11),(4,7),(7,4),(8,4),(11,7),(13,11),(13,28)],2)
    p.poly([(7,5),(4,10),(4,19),(7,23),(8,23),(11,19),(11,10),(8,5)],3)
    p.poly([(7,8),(5,12),(5,16),(7,19),(8,19),(10,16),(10,12),(8,8)],4)
    p.line([(7,4),(7,28)],0)
    p.line([(2,11),(13,11)],0)
    p.line([(2,21),(13,21)],0)
    p.line([(2,28),(13,28)],5)
    p.line([(2,11),(4,7),(7,4),(8,4),(11,7)],5)
    save("stained_glass_1","Quiet Lancet",c,
         "One tall pointed window holds large ruby and sea-glass panes. Matching leaded wing panes extend its horizontal divisions while keeping the tall central window dominant.",
         p,lining(c,0,1,3),wing(c,"lancet"))

    c = "#211F32 #453050 #B6538C #3EA4A0 #C1ABD9 #E6E2C8"
    p = Paint(c); cloth(p)
    p.poly([(6,5),(9,5),(13,9),(13,16),(9,20),(6,20),(2,16),(2,9)],0)
    p.poly([(6,6),(9,6),(12,9),(12,16),(9,19),(6,19),(3,16),(3,9)],2)
    p.poly([(7,7),(8,7),(10,10),(10,15),(8,18),(7,18),(5,15),(5,10)],3)
    p.line([(3,9),(12,16)],0)
    p.line([(3,16),(12,9)],0)
    p.line([(7,6),(7,19)],0)
    p.line([(3,12),(12,12)],0)
    p.rect((6,11,9,14),0); p.rect((7,12,8,13),5)
    p.line([(6,5),(9,5),(13,9)],4)
    p.poly([(2,31),(7,22),(8,22),(13,31)],3)
    p.line([(7,22),(7,31)],0)
    p.line([(1,30),(14,30)],0)
    save("stained_glass_2","Roseward",c,
         "A rose window forms one broad jewel rosette above a fan of glass. The wing panels repeat its radial lines for a generous ceremonial silhouette.",
         p,lining(c,0,1,3),wing(c,"rose"))

    c = "#322B46 #6B617C #A78ACB #69B8B9 #DDE6E4 #F9F3E7"
    p = Paint(c); p.rect((0,0,15,31),4)
    p.poly([(1,0),(7,0),(4,12)],5)
    p.poly([(9,0),(14,0),(11,12)],3)
    p.poly([(7,2),(11,14),(7,27),(4,14)],2)
    p.poly([(1,15),(5,29),(1,29)],3)
    p.poly([(14,15),(10,29),(14,29)],2)
    p.line([(0,0),(7,0),(4,13),(8,29),(15,31)],0)
    p.line([(15,0),(9,0),(11,13),(8,29),(0,31)],0)
    p.line([(0,16),(4,13),(7,2),(11,13),(15,16)],0)
    binding(p,0,0)
    p.dot(7,13,5); p.dot(7,14,5)
    save("stained_glass_3","Opal Prism",c,
         "Pale opal glass surrounds one elongated amethyst lozenge. Angular lead seams and matching faceted wings make a bright architectural alternative to the two dark windows.",
         p,lining(c,1,2,4),wing(c,"prism",1,4))


def moonsilk():
    c = "#625E7D #9A98B3 #CFD4DF #F8F4ED #8DBFBE #CEAFC9"
    p = Paint(c); cloth(p,1,2,3)
    p.rows(4,7,["...mmm..","..mmm...",".mmm....","mmm.....","mmm.....","mmm.....","mmm.....","mmm.....",".mmm....","..mmm...","...mmm.."],{"m":0})
    p.line([(6,9),(5,11),(5,14),(6,16)],4)
    for x,y,b in [(3,26,False),(7,27,True),(12,26,False)]: star(p,x,y,0,b)
    p.rect((0,30,15,30),4); p.rect((0,31,15,31),0)
    save("moonsilk_1","Silver Vigil",c,
         "A large dusk-silver crescent rests on warm white silk, above a hem of stars. Quiet pearl wings continue the stars and sea-green selvedge, leaving the crescent as the single focal point.",
         p,lining(c,0,1,4),wing(c,"stars",1,2))

    p = Paint(c); cloth(p,1,2,3)
    p.poly([(1,2),(7,7),(14,2),(12,12),(8,21),(3,12)],3)
    p.poly([(1,9),(6,17),(7,27),(3,23)],4)
    p.poly([(14,8),(10,18),(8,27),(13,22)],5)
    p.line([(1,26),(5,29),(10,29),(14,26)],0)
    p.line([(1,27),(5,30),(10,30),(14,27)],3)
    star(p,7,5,0,True)
    save("moonsilk_2","Pearlwing",c,
         "Overlapping white, sea-green and blush folds turn the whole cloak into a pearl fan. Pale wings continue the folds, with a dark curved seam holding the hem together.",
         p,lining(c,0,1,4),wing(c,"pearl",1,2))

    c = "#5E587B #9290AF #C5C9DC #F8F1E8 #B3D6D3 #D9BFD6"
    p = Paint(c); cloth(p,0,1,2)
    p.poly([(10,3),(6,4),(3,8),(2,14),(3,20),(6,24),(11,25),(8,21),(6,16),(6,11),(8,7)],3)
    p.line([(10,3),(6,4),(3,8),(2,14)],4)
    p.poly([(15,19),(11,25),(5,28),(0,27),(0,31),(6,31),(12,28),(15,24)],2)
    p.line([(0,28),(5,29),(11,26),(15,21)],5)
    star(p,11,12,3,True); star(p,12,29,3); star(p,3,30,0)
    save("moonsilk_3","Moonfall",c,
         "An oversized ivory crescent sweeps down one side of lavender silk. Stars and curved pearl hems on the wings echo the asymmetric sweep while leaving the main field open.",
         p,lining(c,0,1,4),wing(c,"moonwake"))


def lantern(p, x, y, metal=5, warmth=3, core=4, dark=0):
    p.rows(x,y,["..mmm..","..m.m..",".mmmmm.","mmmmmmm",".mwwwm.",".mwcwm.",".mwcwm.",".mwcwm.",".mwwwm.","mmmmmmm","..mmm.."],
           {"m":metal,"w":warmth,"c":core})
    p.dot(x+3,y+9,dark)


def lantern_bearer():
    c = "#1D2E31 #345052 #665049 #D68A60 #FFE3AF #BACEC8"
    p = Paint(c); cloth(p)
    p.poly([(5,5),(10,5),(13,10),(13,22),(10,26),(5,26),(2,22),(2,10)],2)
    p.line([(7,1),(7,9)],5)
    lantern(p,4,10)
    p.line([(3,28),(12,28)],5); p.line([(5,29),(10,29)],3)
    save("lantern_bearer_1","Everlight",c,
         "A generous silver lantern floats in one muted warm halo on forest-dark cloth. Short warm rays spread onto silver-edged wings, framing the lantern without replacing the calm ground with a solid beam.",
         p,lining(c,0,1,3),wing(c,"rays"))

    c = "#292330 #4C3546 #9C5152 #E99A75 #FFEAC6 #C8CDD4"
    p = Paint(c); cloth(p)
    p.poly([(6,13),(9,13),(14,31),(1,31)],2)
    p.poly([(7,15),(8,15),(12,31),(3,31)],3)
    p.poly([(7,17),(8,17),(9,31),(6,31)],4)
    lantern(p,4,4)
    p.line([(7,0),(7,3)],5)
    binding(p,5,1,False)
    save("lantern_bearer_2","Dawnwatch",c,
         "A high lantern casts a broadening shaft of peach light down the entire back. Illuminated wing hems spread that beam into a warm, unmistakable silhouette.",
         p,lining(c,0,1,3),wing(c,"beam"))

    c = "#322736 #644650 #A66B67 #E5AD89 #F4D9B3 #D7DCDA"
    p = Paint(c); cloth(p,1,4,5)
    p.poly([(3,28),(3,9),(5,5),(7,3),(8,3),(10,5),(12,9),(12,28)],0)
    p.line([(2,28),(2,9),(5,4),(7,2),(8,2),(11,5),(13,9),(13,28)],3)
    p.line([(7,4),(7,10)],5)
    lantern(p,4,11,5,3,4)
    p.line([(4,26),(11,26)],2)
    p.rect((0,30,15,30),3); p.rect((0,31,15,31),1)
    save("lantern_bearer_3","Watchlight",c,
         "A dark arched alcove is cut in paint into luminous parchment silk, with a lantern suspended inside. Pale outer wing edges make the halo itself the garment.",
         p,lining(c,0,1,3),wing(c,"watch",0,1))


def tuft(p,x,y):
    p.dot(x,y,0)
    p.line([(x,y+1),(x,y+2)],0)
    p.line([(x-1,y+3),(x+1,y+3)],0)


def royal_ermine():
    c = "#2B2035 #522E6D #79508E #B9B4CB #F5EFE8 #DCD4DC"
    p = Paint(c); cloth(p,0,1,2)
    p.poly([(0,0),(15,0),(15,5),(12,7),(10,8),(5,8),(3,7),(0,5)],5)
    p.poly([(0,0),(15,0),(15,3),(12,5),(10,6),(5,6),(3,5),(0,3)],4)
    for x,y in [(2,1),(7,3),(12,1)]: tuft(p,x,y)
    p.rect((2,28,13,28),3); p.rect((1,30,14,30),4)
    save("royal_ermine_1","Wintercourt",c,
         "A broad white ermine shoulder cape falls over a calm plum field. Three black tufts and restrained silver wing edges give the classic court silhouette a clean distance read.",
         p,lining(c,0,1,3),wing(c,"court"))

    p = Paint(c); cloth(p,0,1,2)
    p.poly([(0,0),(5,0),(15,25),(15,31),(12,31),(0,7)],5)
    p.poly([(0,0),(3,0),(15,29),(15,31),(14,31),(0,4)],4)
    for x,y in [(2,3),(6,12),(10,21)]: tuft(p,x,y)
    p.rect((9,3,12,5),3); p.rect((10,3,11,4),4)
    p.line([(1,30),(8,30)],3)
    save("royal_ermine_2","Snow Sash",c,
         "One diagonal ermine stole crosses rich violet velvet, fastened by a small silver clasp. Tufted fur cuffs at the wing tips echo the stole while its asymmetric sweep remains the main gesture.",
         p,lining(c,0,1,3),wing(c,"stole"))

    p = Paint(c); cloth(p,0,1,2)
    p.rect((0,0,2,31),4); p.rect((13,0,15,31),5)
    p.rect((0,27,15,31),5); p.rect((0,27,15,29),4)
    p.line([(3,2),(3,25),(12,25),(12,2)],3)
    for x,y in [(1,4),(1,16),(14,4),(14,16),(5,27),(10,27)]: tuft(p,x,y)
    p.poly([(7,8),(9,12),(7,17),(5,12)],3)
    p.poly([(7,9),(8,12),(7,14),(6,12)],2)
    p.dot(7,9,4)
    save("royal_ermine_3","Frost Regent",c,
         "Ermine borders frame a long velvet panel and one silver lozenge. Fur follows the wings' slanted edges, giving the strongest white outline of the three court designs.",
         p,lining(c,0,1,3),wing(c,"ermine"))


def main():
    ART.mkdir(parents=True, exist_ok=True)
    for paint in (hearthkeeper, aurora, stained_glass, moonsilk, lantern_bearer, royal_ermine):
        paint()
    expected = {f"cloak_{v['id']}.png" for v in CATALOG}
    expected |= {f"wings_{v['id']}.png" for v in CATALOG if v['wings']}
    actual = {p.name for p in ART.glob("*.png")}
    if actual != expected:
        raise SystemExit(f"Unexpected art files: {actual ^ expected}")
    hashes = {}
    for f in sorted(ART.glob("*.png")):
        im = Image.open(f).convert("RGBA")
        assert im.size == ((32,32) if f.name.startswith("cloak_") else (16,32)), f
        assert im.getchannel("A").getextrema() == (255,255), f
        hashes[f.name] = hashlib.sha256(f.read_bytes()).hexdigest()
    (ROOT / "catalog.json").write_text(json.dumps(CATALOG, indent=2) + "\n")
    (ROOT / "art-sha256.json").write_text(json.dumps(hashes, indent=2) + "\n")
    notes = ["# Drop 01 — painting notes", "", "Original art dedicated to the public domain under CC0 1.0. Each palette lists every colour used by that draft's cloak and wings. Wings have fully painted unused texels as an opaque sampling guard; the model supplies their triangular shape.", ""]
    for v in CATALOG:
        notes += [f"## {v['id']}", "", f"- Proposed name: **{v['name']}**", f"- Wings: {'yes' if v['wings'] else 'no'}", "- Palette: " + ", ".join(v['palette']), "", v['idea'], ""]
    (ROOT / "notes.md").write_text("\n".join(notes))
    print(f"Painted {len(CATALOG)} cloaks and {sum(v['wings'] for v in CATALOG)} wing sheets.")


if __name__ == "__main__":
    main()
