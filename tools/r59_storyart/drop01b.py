"""Round 59 story art drop 01b: the picked rope snare. CC0-1.0.

GPT-6 Astra, 2026-10-24. Original, AI-assisted pixel art. Copied from the
drop's paint.py, trimmed to its final pass (the user's pick): drop 01 P1's
tall closed loop and short wooden peg, the loop in matte brown hemp cord
with a crossing knot at the peg. Integer Pillow drawing; no input image
pixels, text, randomness or antialiasing.
"""
import math
from PIL import Image, ImageDraw

PAL = {
    'edge': '#25262a',
    'rope_edge': '#292728',
    'strand': '#63442f',
    'shade': '#94683f',
    'hemp': '#ae8050',
    'fibre': '#bf9561',
    'wood': '#76533b', 'wood_l': '#a37b4c', 'wood_h': '#c29b62',
}
LOOP = [(13,3),(20,3),(24,6),(27,11),(28,18),(26,23),
        (22,27),(13,28),(7,25),(4,20),(4,13),(7,7),(13,3)]


def rope(im, points, width=5, phase=0):
    """Three-pixel cord core, dark perimeter, oblique dark ply every 4.5 px."""
    d = ImageDraw.Draw(im)
    d.line(points, fill=PAL['rope_edge'], width=width, joint='curve')
    mask = Image.new('L', im.size)
    ImageDraw.Draw(mask).line(points, fill=255, width=width-2, joint='curve')
    segments=[]
    travelled=0
    for a,b in zip(points,points[1:]):
        dx,dy=b[0]-a[0],b[1]-a[1]
        length=math.hypot(dx,dy)
        segments.append((a,dx,dy,length,travelled))
        travelled+=length
    for y in range(im.height):
        for x in range(im.width):
            if not mask.getpixel((x,y)):
                continue
            nearest=None
            for (ax,ay),dx,dy,length,start in segments:
                t=max(0,min(1,((x-ax)*dx+(y-ay)*dy)/(length*length)))
                ex,ey=x-(ax+t*dx),y-(ay+t*dy)
                dist=ex*ex+ey*ey
                if nearest is None or dist<nearest[0]:
                    normal=(-dy*(x-ax)+dx*(y-ay))/length
                    nearest=(dist,start+t*length,normal)
            _,along,normal=nearest
            twist=(along+normal*.95+phase)%4.5
            colour='strand' if twist<1.1 else 'shade' if twist<1.8 else 'fibre' if twist<3.1 else 'hemp'
            d.point((x,y),fill=PAL[colour])


def peg(im):
    """P1's unchanged short wooden peg, ending at row 31."""
    d=ImageDraw.Draw(im)
    d.polygon([(6,21),(9,18),(13,21),(12,31),(6,31)],fill=PAL['edge'])
    d.polygon([(8,21),(10,20),(11,22),(10,30),(8,30)],fill=PAL['wood'])
    d.line([(8,23),(8,29)],fill=PAL['wood_l'])
    d.polygon([(7,21),(10,19),(12,21),(9,23)],fill=PAL['wood_h'])


def knot(im):
    """Two clear, overlapping cord turns, with a short attached free end."""
    d=ImageDraw.Draw(im)
    # End comes from behind the overhand knot and lies above the baseline.
    d.line([(12,27),(16,29),(19,29)],fill=PAL['rope_edge'],width=3)
    d.line([(12,27),(16,29),(19,29)],fill=PAL['hemp'])
    d.point((16,29),fill=PAL['strand'])
    # Broad lower turn, then a second turn crossing in front of it.
    d.polygon([(6,24),(10,23),(13,24),(14,26),(12,28),
               (8,29),(5,27)],fill=PAL['rope_edge'])
    d.polygon([(7,25),(10,24),(12,25),(12,27),(9,28),(6,26)],
              fill=PAL['shade'])
    d.line([(6,25),(8,27),(10,27),(12,26)],fill=PAL['hemp'],width=2)
    d.line([(6,25),(8,27),(10,27)],fill=PAL['fibre'])
    # The opposing crossing reads as a knot rather than another piece
    # of the lower-left loop. A dark underpass separates the two turns.
    d.line([(6,27),(11,24)],fill=PAL['rope_edge'],width=3)
    d.line([(6,27),(11,24)],fill=PAL['hemp'],width=2)
    d.line([(6,27),(10,25)],fill=PAL['fibre'])
    d.point((11,24),fill=PAL['shade'])
    d.point((9,27),fill=PAL['strand'])
    d.point((10,28),fill=PAL['hemp'])


def snare_bundle():
    im=Image.new('RGBA',(32,32),(0,0,0,0))
    rope(im,LOOP)
    # Correct the pixel-grid phase at the lower-right bend: the two
    # short diagonal plies remain legible when scaled to 41 px at 15 nodes.
    d=ImageDraw.Draw(im)
    d.line([(25,21),(27,22)],fill=PAL['strand'])
    d.line([(23,25),(25,26)],fill=PAL['strand'])
    d.point((24,24),fill=PAL['fibre'])
    peg(im)
    knot(im)
    return im
