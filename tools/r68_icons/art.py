# SPDX-License-Identifier: GPL-3.0-or-later
"""Original 16-pixel drawings. Candidate media: CC0-1.0, GPT-6 Astra.

Only coordinates and colour ramps enter these drawings; no source sprite is
sampled. The shipped gear informs the ramps (see LICENSE-media.md).
"""
from PIL import Image, ImageDraw, ImageFilter

METALS = ('copper', 'tin', 'bronze', 'iron', 'steel', 'silver',
          'silversteel', 'embersteel', 'abyssal_steel', 'gold')
GEMS = ('citrine', 'jade', 'garnet', 'sapphire', 'ruby', 'diamond')
SETTINGS = ('tin', 'iron', 'copper_inlaid_steel', 'gold',
            'gold_filigreed_embersteel', 'gold_filigreed_abyssal_steel')

# Edge, shadow, body, light, glint. Two or three colour families, five values.
# Bronze follows the armour's ochre; copper is redder. Iron follows the sword;
# silversteel the chest armour; embersteel the sword and T5 trinkets.
METAL = {
    'copper': '4b2522 873f2f bd6546 e49c77 ffd2a4',
    'tin': '35444b 637880 9caeb2 cedee0 f3ffff',
    'bronze': '30261f 80532f b78145 deae6b f6d49a',
    'iron': '302e2b 3e3c3a 686460 86817c b0aaa4',
    'steel': '343a40 686868 939393 bfc3c6 eaeaea',
    'silver': '55544d 96968d d5d5c9 eeefe6 fffff8',
    'silversteel': '29384d 7c91ab b6c5d6 e2eaf1 ffffff',
    'embersteel': '291d23 4a1812 8c3e32 cc6639 ffb858',
    'abyssal_steel': '25243f 2e243e 5a4a74 8874a6 d4c4ea',
    'gold': '634916 967727 c5ab49 e7d781 fff3bb',
}
# Settings follow the actual shipped Round 45 B trinket ramps, including iron
# and copper-inlaid steel, which are cooler than the plain weapon versions.
SETTING_METALS = (
    METAL['tin'], '292f34 414e54 697b80 94adb0 c6d8d7',
    '2c3d50 556c82 8da6bc c2d7e6 f0faff', METAL['gold'],
    '291d23 532a2d 8c3e32 cc6639 ffb858',
    '25243f 414365 65638c 9897c4 d7dafb',
)
GEM = {
    'citrine': '5b3510 9c6013 d59b1d f3c641 ffe999',
    'jade': '17392b 265d43 448b59 80b87a c8e3aa',
    'garnet': '351a20 582229 91372e be5b41 ef9971',
    'sapphire': '14213d 1c3976 285bb9 548def b3d8ff',
    'ruby': '450e29 840d3b c91950 f3446b ff9eaa',
    'diamond': '32465d 58849a a1cfdb e1f5f7 ffffff',
    'quartz': '55565d 8e969e c3c8c4 e4e6d9 fffff3',
    'abyssal_crystal': '1b152a 302041 532e76 8952b4 c29be7',
}


def ramp(text):
    return ['#' + c for c in text.split()]


def canvas():
    im = Image.new('RGBA', (16, 16))
    return im, ImageDraw.Draw(im)


def bar(key, variant):
    im, d = canvas()
    o, s, m, l, h = ramp(METAL[key])
    if variant == 'a':
        # A long, tapered mould casting, viewed from above left.
        d.polygon([(1,7),(9,2),(12,3),(14,6),(14,9),(6,14),(1,11)], fill=o)
        d.polygon([(2,8),(6,10),(6,12),(2,10)], fill=m)
        d.polygon([(7,10),(13,7),(13,9),(7,12)], fill=s)
        d.polygon([(2,7),(9,3),(11,4),(13,6),(6,10)], fill=l)
        d.line([(3,7),(9,4),(11,5)], fill=h)
        d.line([(6,10),(13,6)], fill=m)
        if key == 'tin':
            d.line([(6,6),(8,5)], fill=l)  # interrupted, soft casting edge
            d.point((9,7), fill=m)
        elif key == 'iron':
            d.line([(3,8),(4,7),(5,7)], fill=s)  # hammer scar
            d.point((10,5), fill=m)
        elif key == 'steel':
            d.line([(8,4),(10,7)], fill=h)  # a clean ground face
        elif key == 'silver':
            d.polygon([(4,7),(9,4),(10,5),(6,8)], fill=h)
            d.point((11,6), fill=s)  # tiny mint punch
        elif key == 'silversteel':
            d.line([(5,8),(11,5)], fill=m)
            d.line([(7,8),(11,6)], fill=h)  # cold double ridge
        elif key == 'embersteel':
            d.line([(6,10),(13,6)], fill=h)
            d.line([(9,9),(10,10)], fill=l)
        elif key == 'abyssal_steel':
            d.polygon([(5,6),(8,5),(10,6),(7,8)], fill=s)
            d.line([(7,10),(12,7)], fill=h)
        elif key == 'bronze':
            d.line([(3,8),(5,9)], fill=m)
        elif key == 'gold':
            d.polygon([(4,7),(9,4),(10,4),(6,7)], fill=h)
    else:
        # A short, broad forged billet: horizontal, clipped corners, end cap.
        d.polygon([(1,6),(4,3),(12,3),(14,5),(14,11),(11,13),(3,13),(1,11)], fill=o)
        d.polygon([(2,6),(4,4),(11,4),(13,6),(11,8),(4,8)], fill=l)
        d.polygon([(2,7),(4,9),(11,9),(11,12),(4,12),(2,10)], fill=m)
        d.polygon([(12,8),(13,7),(13,10),(12,11)], fill=s)
        d.line([(4,4),(10,4)], fill=h)
        d.line([(4,9),(10,9)], fill=s)
        if key == 'tin':
            d.line([(6,4),(8,4)], fill=l)
            d.line([(3,7),(5,8)], fill=h)
        elif key == 'iron':
            d.rectangle((5,6,6,6), fill=m)
            d.point((9,5), fill=s)
            d.line([(3,10),(4,11)], fill=s)
        elif key == 'steel':
            d.line([(9,4),(6,7)], fill=h)
            d.line([(9,5),(7,7)], fill=m)
        elif key == 'silver':
            d.rectangle((5,5,10,6), fill=h)
            d.rectangle((7,10,8,10), fill=s)
        elif key == 'silversteel':
            d.line([(5,5),(11,5)], fill=m)
            d.line([(5,7),(11,7)], fill=h)
        elif key == 'embersteel':
            d.line([(3,8),(11,8),(13,6)], fill=h)
            d.point((6,11), fill=l)
        elif key == 'abyssal_steel':
            d.polygon([(6,5),(10,5),(8,7),(4,7)], fill=s)
            d.line([(12,8),(12,10)], fill=h)
        elif key == 'bronze':
            d.line([(4,7),(5,7)], fill=m)
        elif key == 'gold':
            d.line([(5,5),(10,5)], fill=h)
    return im


def setting(tier, variant):
    im, d = canvas()
    o, s, m, l, h = ramp(SETTING_METALS[tier-1])
    trim = ramp(METAL['copper' if tier == 3 else 'gold'])
    if variant == 'a':
        # Loose open bezel; the hole is transparent, not a dark gemstone.
        outlines = [
            [(5,3),(10,3),(13,6),(13,10),(10,13),(5,13),(2,10),(2,6)],
            [(3,3),(12,3),(13,4),(13,12),(12,13),(3,13),(2,12),(2,4)],
            [(5,2),(10,2),(13,5),(13,11),(10,14),(5,14),(2,11),(2,5)],
            [(5,2),(10,2),(13,5),(14,8),(12,12),(9,14),(5,13),(2,10),(1,6)],
            [(7,1),(14,7),(14,9),(8,15),(1,9),(1,7)],
            [(5,1),(10,1),(13,5),(13,11),(10,14),(5,14),(2,11),(2,5)],
        ]
        d.polygon(outlines[tier-1], fill=o)
        d.polygon([(5,3),(10,3),(12,5),(12,10),(10,12),(5,12),(3,10),(3,5)], fill=m)
        d.line([(3,9),(3,5),(5,3),(10,3)], fill=l, width=2)
        d.line([(5,12),(10,12),(12,10),(12,6)], fill=s, width=2)
        d.polygon([(6,5),(9,5),(10,6),(10,9),(9,10),(6,10),(5,9),(5,6)], fill=o)
        d.polygon([(6,6),(9,6),(9,9),(6,9)], fill=(0,0,0,0))
        d.line([(4,5),(5,4),(8,4)], fill=h)
        if tier == 2:
            d.rectangle((3,4,4,5), fill=l)
            d.rectangle((11,10,12,11), fill=s)
        if tier in (3,5,6):
            _, ts, tm, tl, _ = trim
            d.line([(3,6),(4,4),(5,3)], fill=tl)
            d.line([(10,12),(12,10),(12,8)], fill=tm)
            if tier >= 5:
                d.line([(5,12),(4,10)], fill=tm)
                d.line([(10,3),(11,5)], fill=tl)
                d.point((4,11), fill=tl)
                d.point((11,11), fill=tl)
        if tier == 4:
            d.line([(2,6),(2,8)], fill=h)
            d.point((12,11), fill=l)
        if tier == 5:
            d.line([(7,2),(8,3)], fill=h)
            d.line([(7,13),(8,13)], fill=l)
        if tier == 6:
            d.line([(5,2),(10,2)], fill=h)
            d.line([(5,13),(10,13)], fill=l)
    else:
        # A ring blank in side view: open crown and visibly empty shank.
        d.polygon([(4,6),(11,6),(13,8),(13,11),(10,14),(5,14),(2,11),(2,8)], fill=o)
        d.polygon([(4,7),(11,7),(12,9),(11,12),(9,13),(5,12),(3,10)], fill=m)
        d.line([(3,10),(4,8),(5,7)], fill=l, width=2)
        d.line([(6,13),(9,13),(12,10)], fill=s)
        d.polygon([(6,8),(9,8),(10,9),(10,11),(8,12),(6,11),(5,10)], fill=o)
        d.polygon([(6,9),(9,9),(9,10),(8,11),(6,10)], fill=(0,0,0,0))
        # Empty mouth, open to the background. Prongs never converge on a gem.
        left, right = (3,12) if tier in (2,5) else (4,11)
        d.rectangle((left,2,left+2,6), fill=o)
        d.rectangle((right-2,2,right,6), fill=o)
        d.line([(left+1,2),(left+1,5),(6,6),(9,6),(right-1,5),(right-1,2)], fill=l)
        d.line([(6,7),(9,7)], fill=s)
        d.point((left+1,2), fill=h)
        if tier == 2:
            d.rectangle((3,2,5,3), fill=l)
            d.rectangle((10,2,12,3), fill=m)
        if tier in (3,5,6):
            d.line([(3,9),(4,8),(5,8)], fill=trim[3])
            d.line([(10,12),(11,11),(11,10)], fill=trim[2])
            d.point((right-1,2), fill=trim[3])
            if tier >= 5:
                d.line([(5,12),(7,13)], fill=trim[3])
        if tier == 4:
            d.line([(6,5),(9,5)], fill=l)
            d.point((4,10), fill=h)
        if tier == 5:
            d.line([(3,1),(4,2),(5,4)], fill=h)
            d.line([(12,1),(11,2),(10,4)], fill=l)
        if tier == 6:
            d.line([(5,1),(5,4)], fill=h)
            d.line([(10,1),(10,4)], fill=l)
            d.line([(6,13),(9,13)], fill=trim[2])
    return im


# Each mineral has its own silhouette, even before cutting.
ROUGH = {
    'citrine': [(3,10),(4,4),(8,1),(11,3),(12,9),(10,13),(5,14)],
    'jade': [(1,7),(4,4),(7,3),(11,4),(14,7),(13,11),(9,13),(4,12),(2,10)],
    'garnet': [(2,6),(5,3),(9,3),(13,6),(12,11),(8,14),(3,12),(1,9)],
    'sapphire': [(4,4),(8,1),(11,4),(12,11),(9,14),(4,12),(2,8)],
    'ruby': [(4,12),(3,7),(6,2),(10,1),(12,5),(10,10),(8,14)],
    'diamond': [(1,8),(6,2),(9,3),(13,7),(12,11),(7,14),(3,12)],
}
CUT_A = {
    'citrine': [(5,2),(10,2),(12,5),(10,11),(7,14),(3,9),(3,5)],
    'jade': [(4,4),(10,3),(13,6),(13,9),(10,12),(5,13),(2,10),(1,7)],
    'garnet': [(4,3),(11,3),(13,5),(13,10),(10,13),(4,13),(2,11),(2,5)],
    'sapphire': [(7,1),(12,4),(13,9),(8,14),(3,12),(2,6)],
    'ruby': [(8,1),(12,6),(13,10),(11,13),(7,14),(3,12),(2,9),(4,5)],
    'diamond': [(4,3),(11,3),(14,7),(8,14),(1,7)],
}
CUT_B = {
    'citrine': [(3,4),(12,4),(14,6),(14,9),(12,11),(3,11),(1,9),(1,6)],
    'jade': [(1,8),(5,4),(10,2),(14,7),(10,11),(5,13)],
    'garnet': [(5,2),(10,2),(14,7),(11,12),(4,13),(1,8)],
    'sapphire': [(3,3),(12,3),(13,4),(13,12),(12,13),(3,13),(2,12),(2,4)],
    'ruby': [(5,2),(10,2),(13,5),(14,9),(11,13),(6,14),(2,11),(1,6)],
    'diamond': [(5,1),(10,1),(13,4),(13,11),(10,14),(5,14),(2,11),(2,4)],
}


def cut_gem(key, variant):
    im, d = canvas()
    o, s, m, l, h = ramp(GEM[key])
    points = (CUT_A if variant == 'a' else CUT_B)[key]
    # Facets follow the perimeter of each cut, with a large saturated table.
    inner = [(round(7.5+(x-7.5)*.48), round(7.5+(y-7.5)*.48)) for x,y in points]
    d.polygon(points, fill=o)
    inset = [(round(7.5+(x-7.5)*.86), round(7.5+(y-7.5)*.86)) for x,y in points]
    for i, p in enumerate(inset):
        j = (i+1) % len(points)
        # Fixed upper-left illumination; right and bottom facets stay dark.
        mx, my = (p[0]+inset[j][0])/2, (p[1]+inset[j][1])/2
        c = l if mx+my < 14 else s
        if i % 3 == 1 and mx+my < 18:
            c = m
        d.polygon([p,inset[j],inner[j],inner[i]], fill=c)
    d.polygon(inner, fill=m)
    if variant == 'a':
        d.line([inner[0],inner[1]], fill=l)
        d.line([inset[-1],inset[0]], fill=h)
        # Deliberate large crown planes: polished stones must not read as
        # merely smoother specimens. Keep highlights off the saturated table.
        if key == 'citrine':
            d.line([(5,3),(9,3)], fill=h)
            d.polygon([(9,5),(11,5),(9,10),(7,12),(8,8)], fill=s)
            d.line([(4,6),(4,8)], fill=l)
        elif key == 'jade':
            d.polygon([(4,5),(9,4),(11,5),(8,6),(4,7)], fill=l)
            d.line([(4,5),(7,4)], fill=h)
            d.polygon([(5,11),(10,10),(12,8),(11,11),(6,12)], fill=s)
        elif key == 'garnet':
            d.polygon([(4,4),(10,4),(8,6),(6,6)], fill=l)
            d.polygon([(11,5),(12,6),(12,10),(10,11),(10,7)], fill=s)
            d.line([(4,5),(3,7)], fill=h)
            d.line([(5,11),(9,11)], fill=s)
        elif key == 'sapphire':
            d.polygon([(7,2),(11,4),(8,5),(5,5)], fill=l)
            d.polygon([(11,5),(12,9),(9,12),(9,8)], fill=s)
            d.line([(4,5),(3,7),(4,9)], fill=h)
        elif key == 'ruby':
            d.polygon([(8,3),(10,6),(7,6),(4,9),(5,6)], fill=l)
            d.polygon([(11,7),(12,10),(10,12),(8,13),(9,9)], fill=s)
            d.line([(7,4),(6,6)], fill=h)
    else:
        # Broad step facets instead of A's individual radial crown facets.
        d.line(inner + [inner[0]], fill=l)
        d.line([inner[2],inner[3]], fill=s)
        d.line([inset[0],inset[1]], fill=h)
    if key == 'diamond' and variant == 'a':
        d.polygon([(4,4),(10,4),(12,6),(3,6)], fill=h)
        d.polygon([(3,7),(7,7),(8,12)], fill=l)
        d.polygon([(8,7),(12,7),(8,12)], fill=m)
        d.line([(6,5),(8,12)], fill=h)
    if key == 'diamond' and variant == 'b':
        d.rectangle((6,4,9,10), fill=l)
        d.line([(4,4),(4,10)], fill=h)
        d.line([(6,3),(9,3)], fill=h)
    return im


def octagon(box, clip):
    """Clockwise corners, centred on the half-pixel axes; no rounded scaling."""
    x0, y0, x1, y1 = box
    return [(x0+clip,y0),(x1-clip,y0),(x1,y0+clip),(x1,y1-clip),
            (x1-clip,y1),(x0+clip,y1),(x0,y1-clip),(x0,y0+clip)]


# Each perimeter and table is authored on the pixel grid. Symmetry concerns
# the cut geometry; the deliberately asymmetric upper-left light is shared.
CUT_C = {
    'citrine': (octagon((1,0,14,15),3), octagon((4,3,11,12),1)),
    'jade': (octagon((0,2,15,13),2), octagon((3,5,12,10),1)),
    'garnet': (octagon((1,1,14,14),1), octagon((4,4,11,11),1)),
    'sapphire': (octagon((1,0,14,15),4), octagon((4,3,11,12),2)),
    'ruby': (octagon((2,0,13,15),3), octagon((5,3,10,12),1)),
    'diamond': (octagon((0,0,15,15),4), octagon((3,3,12,12),2)),
}
CUT_D = {
    'citrine': ([(5,2),(10,2),(13,3),(15,6),(15,9),(13,12),(10,13),(5,13),(2,12),(0,9),(0,6),(2,3)],
                [(6,5),(9,5),(11,6),(12,7),(12,8),(11,9),(9,10),(6,10),(4,9),(3,8),(3,7),(4,6)]),
    'jade': (octagon((1,1,14,14),2), octagon((4,4,11,11),1)),
    'garnet': (octagon((1,1,14,14),4), octagon((4,4,11,11),2)),
    'sapphire': (octagon((0,2,15,13),3), octagon((4,5,11,10),1)),
    'ruby': ([(7,0),(8,0),(12,5),(14,9),(13,12),(10,15),(5,15),(2,12),(1,9),(3,5)],
             [(7,4),(8,4),(10,7),(11,9),(10,11),(9,12),(6,12),(5,11),(4,9),(5,7)]),
}


def polished_gem(key, variant):
    """C: a step-cut family. D: oval, square, round, cushion, pear, brilliant."""
    im, d = canvas()
    o, s, m, l, h = ramp(GEM[key])
    if key == 'diamond' and variant == 'd':
        # Side elevation: a wide crown/table over three simple pavilion planes.
        # Paired coordinates keep even the two-pixel culet exactly symmetric.
        points = [(4,1),(11,1),(15,6),(8,14),(7,14),(0,6)]
        d.polygon(points, fill=o)
        d.polygon([(4,2),(11,2),(14,6),(1,6)], fill=l)
        d.polygon([(5,2),(10,2),(11,5),(4,5)], fill=h)
        d.polygon([(2,7),(6,7),(7,12)], fill=m)
        d.polygon([(6,7),(9,7),(8,12),(7,12)], fill=h)
        d.polygon([(9,7),(13,7),(8,12)], fill=s)
        d.line([(2,6),(13,6)], fill=l)
        return im
    points, table = (CUT_C if variant == 'c' else CUT_D)[key]
    mask = Image.new('L',(16,16))
    ImageDraw.Draw(mask).polygon(points,fill=255)
    # A consistent one-pixel border, including along slopes. Padding makes
    # the erosion correct even when a cut reaches the icon's outer row.
    padded = Image.new('L',(18,18))
    padded.paste(mask,(1,1))
    inside = padded.filter(ImageFilter.MinFilter(3)).crop((1,1,17,17))
    d.rectangle((0,0,15,15),fill=o)
    planes, pd = canvas()
    for i, p in enumerate(points):
        j = (i+1) % len(points)
        q = points[j]
        mx, my = (p[0]+q[0])/2, (p[1]+q[1])/2
        # Three broad values: bright upper/left, body at the shoulders,
        # dark lower/right. D alternates a few planes for radial cut cues.
        colour = l if mx+my < 14 else s
        if variant == 'd':
            if mx < 5 and my < 6:
                colour = h
            elif mx < 6 and my > 10:
                colour = m
            elif mx > 10 and my < 6:
                colour = m
        pd.polygon([p,q,table[j],table[i]],fill=colour)
    pd.polygon(table,fill=l if key=='diamond' else m)
    if variant == 'c' or key == 'jade':
        # Crisp parallel rims make the central table explicit without noise.
        pd.line([table[-1],table[0],table[1]],fill=h if key=='diamond' else l)
        pd.line([table[3],table[4],table[5]],fill=s)
    else:
        pd.line([table[-1],table[0],table[1]],fill=l)
        # The bottom table edge separates its broad face from the pavilion.
        bottom = max(y for x,y in table)
        edge = [(x,y) for x,y in table if y == bottom]
        if len(edge) == 2:
            pd.line(edge,fill=s)
    # One straight polish glint, never an extra blob outside the contour.
    x0,y0 = points[0]; x1,y1 = points[1]
    pd.line([(x0,y0+1),(x1,y1+1)],fill=h)
    im.paste(planes,(0,0),inside)
    im.putalpha(mask)
    return im


def polished_block(key, variant):
    """Solid cut material with quiet step planes (C) or crown planes (D)."""
    if key == 'abyssal_crystal':
        return block(key,'a','gem')  # the accepted raw mineral is unchanged
    o,s,m,l,h = ramp(GEM[key])
    im = Image.new('RGBA',(16,16),m)
    d = ImageDraw.Draw(im)
    hi, lo = mix(m,l,.42), mix(m,s,.32)
    edge = mix(m,s,.40)
    d.rectangle((0,0,15,15),outline=edge)
    if variant == 'c':
        # One broad squared table; two parallel bevels in the same material.
        for inset in (1,3):
            d.line([(inset,14-inset),(inset,inset),(14-inset,inset)],fill=hi)
            d.line([(inset+1,15-inset),(15-inset,15-inset),(15-inset,inset+1)],fill=lo)
    else:
        # The face is a continuous polished block, not a transparent jewel
        # pasted onto a background. Four facets meet a broad square table.
        d.polygon([(1,1),(14,1),(10,5),(5,5)],fill=hi)
        d.polygon([(1,1),(5,5),(5,10),(1,14)],fill=mix(m,l,.25))
        d.polygon([(14,1),(14,14),(10,10),(10,5)],fill=lo)
        d.polygon([(1,14),(14,14),(10,10),(5,10)],fill=mix(m,s,.22))
        d.line([(3,2),(10,2)],fill=mix(m,l,.52))
    return im


def rough_gem(key, variant):
    im, d = canvas()
    o, s, m, l, h = ramp(GEM[key])
    if variant == 'a':
        points = ROUGH[key]
        d.polygon(points, fill=o)
        d.polygon([(x+(1 if x<7 else -1), y+(1 if y<7 else -1)) for x,y in points], fill=s)
        d.polygon([(4,6),(7,3),(10,5),(9,10),(5,11),(3,8)], fill=m)
        d.polygon([(4,6),(7,3),(8,5),(6,8),(3,8)], fill=l)
        d.line([(5,6),(6,4)], fill=h)
        d.line([(9,6),(8,9),(10,11)], fill=o)
        if key == 'jade':
            d.polygon([(3,7),(6,5),(11,6),(12,9),(8,11),(4,10)], fill=m)
            d.line([(4,7),(7,6),(9,6)], fill=l)
        if key == 'ruby':
            # Natural elongated corundum crystal; cut A becomes a pear.
            d.polygon([(5,7),(7,3),(10,2),(11,5),(8,11),(6,12)], fill=m)
            d.line([(7,4),(6,7),(6,10)], fill=l)
    else:
        # Broken host-rock specimen, with one dominant mineral exposure.
        d.polygon([(2,7),(4,3),(7,4),(10,2),(13,6),(12,9),(14,11),(10,14),(4,13),(1,10)], fill='#303037')
        d.polygon([(2,8),(6,5),(10,6),(13,11),(10,13),(4,12)], fill='#686568')
        d.line([(3,10),(5,12),(8,12)], fill='#999187')
        shape = [(max(2,x),max(2,y-1)) for x,y in ROUGH[key]]
        d.polygon(shape, fill=o)
        d.polygon([(4,5),(8,3),(11,5),(10,9),(6,11),(3,8)], fill=m)
        d.polygon([(4,5),(8,3),(8,6),(5,8),(3,8)], fill=l)
        d.polygon([(8,7),(11,5),(10,9),(6,11)], fill=s)
        d.line([(4,5),(6,4)], fill=h)
        d.line([(8,3),(8,5),(6,7)], fill=o)
    return im


def mineral(key, variant):
    im, d = canvas()
    o, s, m, l, h = ramp(GEM[key])
    if key == 'quartz':
        if variant == 'a':
            d.polygon([(2,7),(4,4),(6,6),(7,2),(10,1),(12,4),(12,11),(9,14),(4,13),(2,11)], fill=o)
            d.polygon([(3,7),(4,6),(5,7),(6,12),(4,11)], fill=m)
            d.polygon([(8,3),(10,2),(11,4),(11,11),(8,13),(7,11)], fill=l)
            d.polygon([(10,4),(11,4),(11,11),(9,12)], fill=m)
            d.line([(8,4),(8,9)], fill=h)
            d.line([(4,7),(4,10)], fill=h)
        else:
            d.polygon([(1,9),(4,5),(11,2),(14,4),(14,7),(10,10),(5,13),(2,12)], fill=o)
            d.polygon([(3,9),(5,6),(11,3),(13,4),(11,6),(5,11)], fill=l)
            d.polygon([(5,11),(11,6),(13,5),(13,7),(9,10),(5,12)], fill=m)
            d.line([(5,7),(10,4)], fill=h)
            d.line([(8,7),(9,9)], fill=s)
    elif variant == 'a':
        d.polygon([(2,6),(4,4),(6,7),(7,1),(10,3),(11,8),(13,5),(14,7),(12,12),(8,15),(3,12)], fill=o)
        d.polygon([(7,3),(9,4),(10,10),(8,13),(6,11)], fill=m)
        d.line([(7,4),(7,9),(8,12)], fill=h)
        d.polygon([(3,6),(4,6),(6,11),(5,12)], fill=l)
        d.line([(13,7),(11,11)], fill=l)
        d.polygon([(9,4),(10,10),(8,13),(9,8)], fill=s)
    else:
        d.polygon([(1,12),(4,7),(8,2),(11,1),(11,5),(14,4),(13,8),(8,13),(4,14)], fill=o)
        d.polygon([(3,11),(8,4),(10,2),(9,7),(6,11)], fill=m)
        d.line([(4,9),(8,4)], fill=h)
        d.polygon([(6,12),(10,8),(13,5),(12,8),(8,12)], fill=l)
        d.line([(7,9),(9,7)], fill=s)
    return im


def mix(a, b, factor):
    a, b = Image.new('RGB',(1,1),a).getpixel((0,0)), Image.new('RGB',(1,1),b).getpixel((0,0))
    return tuple(round(x*(1-factor)+y*factor) for x,y in zip(a,b)) + (255,)


def block(key, variant, family):
    o, s, m, l, h = ramp((METAL if family == 'metal' else GEM)[key])
    im = Image.new('RGBA',(16,16),m)
    d = ImageDraw.Draw(im)
    # Full opacity for a solid node. Same-colour outer edges tile without
    # accidental jumps; broad, deliberately low-contrast inset bevels.
    edge = mix(m,s,.45)
    hi, lo = mix(m,l,.38), mix(m,s,.35)
    d.rectangle((0,0,15,15), outline=edge)
    if variant == 'a':
        d.line([(1,14),(1,1),(14,1)], fill=hi)
        d.line([(2,14),(14,14),(14,2)], fill=lo)
        if family == 'metal':
            d.line([(3,3),(9,3)], fill=mix(m,l,.18))
            if key == 'iron':
                d.line([(4,5),(6,5)], fill=lo)
            elif key == 'silversteel':
                d.line([(3,4),(10,4)], fill=hi)
                d.line([(5,6),(12,6)], fill=hi)
            elif key == 'steel':
                d.line([(8,3),(11,6)], fill=hi)
            elif key == 'embersteel':
                d.line([(3,13),(12,13)], fill=mix(m,h,.3))
            elif key == 'abyssal_steel':
                d.line([(3,3),(6,6),(6,8)], fill=lo)
        else:
            d.polygon([(2,2),(13,2),(10,5),(5,5),(5,10),(2,13)], fill=hi)
            d.polygon([(13,3),(13,13),(3,13),(6,10),(10,10),(10,6)], fill=lo)
            d.line([(3,3),(7,3)], fill=mix(m,l,.60))
    else:
        if family == 'metal':
            # Two offset courses of cast metal: no rivets or dark mortar.
            d.line([(1,8),(14,8)], fill=lo)
            d.line([(1,1),(14,1)], fill=hi)
            d.line([(1,9),(14,9)], fill=hi)
            d.line([(10,1),(10,7)], fill=lo)
            d.line([(5,9),(5,14)], fill=lo)
            d.line([(11,2),(11,6)], fill=hi)
            d.line([(6,10),(6,13)], fill=hi)
            if key == 'embersteel':
                d.line([(2,7),(8,7)], fill=mix(m,h,.25))
            elif key == 'abyssal_steel':
                d.line([(7,13),(12,10)], fill=lo)
        else:
            # Two large polished slabs, with broad stepped facets.
            d.line([(8,1),(8,14)], fill=lo)
            for x in (1,9):
                d.polygon([(x,2),(x+5,2),(x+4,4),(x+1,4),(x+1,11),(x,13)], fill=hi)
                d.polygon([(x+5,3),(x+5,13),(x+1,13),(x+2,11),(x+4,11),(x+4,5)], fill=lo)
    return im


def candidates():
    result = {}
    for v in ('a','b'):
        result['bars_'+v] = {k+'_bar': bar(k,v) for k in METALS}
        result['bars_'+v].update({k+'_block': block(k,v,'metal') for k in METALS})
        result['settings_'+v] = {'setting_'+k: setting(i,v) for i,k in enumerate(SETTINGS,1)}
        result['gems_'+v] = {}
        for k in GEMS:
            result['gems_'+v]['rough_'+k] = rough_gem(k,v)
            result['gems_'+v]['cut_'+k] = cut_gem(k,v)
        for k in ('quartz','abyssal_crystal'):
            result['gems_'+v][k] = mineral(k,v)
        result['gems_'+v].update({k+'_block': block(k,v,'gem') for k in (*GEMS,'abyssal_crystal')})
    for v in ('c','d'):
        # Rough gems and both minerals are reused from A by the preview and
        # measurements, not duplicated. Every new folder holds 6 cuts + 7 faces.
        result['gems_'+v] = {'cut_'+k: polished_gem(k,v) for k in GEMS}
        result['gems_'+v].update({k+'_block': polished_block(k,v) for k in (*GEMS,'abyssal_crystal')})
    return result
