"""Round 59 story art drop 01: the three picked sprites. CC0-1.0.

GPT-6 Astra, 2026-10-24. Original, AI-assisted pixel art. Copied from the
drop's paint.py, trimmed to the user's picks: dispatch_record P1 (trestle
board), witness_record P2 (two bound tablets), held_supplies P1 (packs
behind a rope cross). Integer-coordinate Pillow drawing only; no input
images, image models, random numbers, text drawing or antialiasing.
"""
from PIL import Image, ImageDraw

PAL = {
    'edge': '#25262a', 'deep': '#3d3431',
    'wood': '#76533b', 'wood_l': '#a37b4c', 'wood_h': '#c29b62',
    'board': '#47433c', 'board_l': '#656052',
    'paper': '#dacfaa', 'paper_h': '#eee5c8', 'paper_s': '#a79a76',
    'mark': '#827258',
    'band': '#525d61', 'band_l': '#76817e',
    'wax_d': '#79402d', 'wax': '#b77140', 'wax_h': '#dda15c',
    'cord_d': '#725237', 'cord': '#c1a06a', 'cord_h': '#ead3a0',
    'sage_d': '#535e49', 'sage': '#78836a', 'sage_h': '#9da488',
    'cloth_d': '#795c48', 'cloth': '#ab8a5d', 'cloth_h': '#c7ac7a',
}


class Brush:
    def __init__(self):
        self.im = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def rect(self, box, color):
        self.d.rectangle(box, fill=PAL.get(color, color))

    def poly(self, points, color):
        self.d.polygon(points, fill=PAL.get(color, color))

    def line(self, points, color, width=1):
        self.d.line(points, fill=PAL.get(color, color), width=width)

    def dot(self, xy, color):
        self.d.point(xy, fill=PAL.get(color, color))


def seal(b, x, y):
    """Continuous solid wax disk with a lit rim; no crack or glyph."""
    b.poly([(x+2,y),(x+5,y),(x+7,y+2),(x+7,y+5),
            (x+5,y+7),(x+2,y+7),(x,y+5),(x,y+2)], 'edge')
    b.poly([(x+2,y+1),(x+5,y+1),(x+6,y+2),(x+6,y+5),
            (x+5,y+6),(x+2,y+6),(x+1,y+5),(x+1,y+2)], 'wax_d')
    b.rect((x+2,y+2,x+5,y+5), 'wax')
    b.line([(x+1,y+3),(x+2,y+1),(x+4,y+1)], 'wax_h')
    b.dot((x+2,y+2), 'wax_h')


def dispatch_record():
    """P1: portrait writing board on splayed feet, slate band, ochre seal."""
    b = Brush()
    # Two splayed feet; no chest, stone plinth, or scroll spindle.
    b.poly([(9,20),(13,20),(11,29),(13,30),(13,31),(4,31),(4,29),(7,28)], 'edge')
    b.poly([(19,20),(23,20),(25,28),(28,29),(28,31),(19,31),(19,29),(21,28)], 'edge')
    b.line([(10,23),(8,29),(6,30)], 'wood_l', 2)
    b.line([(21,23),(23,29),(26,30)], 'wood', 2)
    b.rect((9,26,23,27), 'deep')
    b.line([(10,26),(22,26)], 'wood_l')
    # High, portrait writing board with a visible dark bevel.
    b.poly([(7,2),(23,2),(26,5),(25,24),(6,24),(5,5)], 'edge')
    b.poly([(7,4),(23,3),(24,5),(23,22),(7,22)], 'board')
    b.line([(7,4),(22,4)], 'board_l')
    b.line([(6,7),(6,20)], 'wood')
    b.line([(8,23),(24,23)], 'wood_l')
    # One large pale cover sheet, blank apart from broad nonletter marks.
    b.poly([(9,5),(20,5),(22,7),(21,20),(9,21),(8,19)], 'paper_s')
    b.poly([(9,5),(19,5),(21,7),(20,19),(9,19)], 'paper')
    b.rect((9,5,18,6), 'paper_h')
    b.line([(9,7),(9,11)], 'paper_h')
    b.poly([(20,5),(20,7),(22,7)], 'paper_h')
    b.rect((12,8,17,9), 'mark')
    b.rect((11,11,15,11), 'paper_s')
    # Broad transverse band: cool slate cloth, then unbroken warm wax.
    b.rect((6,13,24,17), 'edge')
    b.rect((7,13,23,16), 'band')
    b.rect((7,13,23,13), 'band_l')
    seal(b, 15, 12)
    return b.im


def witness_record():
    """P2: two loose tablets at unequal heights, bound with a side knot."""
    b = Brush()
    # Two loose, offset tablets, one much higher; no central book fold.
    b.poly([(16,6),(25,8),(29,27),(26,30),(15,28),(12,10)], 'edge')
    b.poly([(16,8),(24,10),(27,26),(25,28),(17,26),(14,11)], 'paper')
    b.line([(16,8),(23,10)], 'paper_h')
    b.line([(15,11),(18,24)], 'paper_h')
    b.line([(18,27),(25,29),(28,27)], 'paper_s')
    b.line([(18,13),(23,14)], 'mark', 2)
    b.line([(20,17),(24,18)], 'paper_s')
    # The shorter tablet overlaps the lower left corner of the tall one.
    b.poly([(3,16),(12,12),(15,13),(19,28),(15,31),(3,29),(1,20)], 'edge')
    b.poly([(4,17),(12,14),(13,15),(17,27),(14,29),(4,27),(3,20)], 'paper')
    b.line([(4,17),(11,15)], 'paper_h')
    b.line([(4,18),(5,25)], 'paper_h')
    b.line([(5,28),(14,30),(18,28)], 'paper_s')
    b.line([(7,20),(11,18)], 'mark', 2)
    b.line([(8,24),(12,23)], 'paper_s')
    # Strong oblique wrap joins the leaves without suggesting a spine.
    b.line([(3,25),(15,24),(27,21)], 'edge', 4)
    b.line([(3,25),(15,24),(27,21)], 'cord_d', 3)
    b.line([(3,24),(15,23),(27,20)], 'cord_h')
    b.line([(21,9),(22,16),(22,27)], 'edge', 3)
    b.line([(21,9),(22,16),(22,27)], 'cord', 2)
    b.line([(21,9),(22,15)], 'cord_h')
    b.poly([(19,20),(23,19),(26,22),(24,26),(20,27),(17,24)], 'edge')
    b.poly([(20,21),(23,21),(24,23),(22,25),(19,24)], 'cord')
    b.line([(20,21),(21,23),(23,23)], 'cord_h')
    b.line([(22,26),(25,28)], 'cord', 2)
    return b.im


def packs(b):
    """Two compact, separately outlined cloth packs behind the barrier."""
    b.poly([(5,8),(8,6),(13,6),(15,10),(15,27),(12,29),(4,28),(3,24),(3,12)], 'edge')
    b.poly([(6,9),(11,8),(13,11),(13,26),(5,26),(5,13)], 'sage')
    b.poly([(11,10),(13,11),(13,26),(10,27),(10,14)], 'sage_d')
    b.line([(6,10),(6,18)], 'sage_h')
    b.poly([(6,8),(8,6),(11,7),(13,10),(8,11)], 'sage_h')
    b.line([(7,7),(11,8),(11,10),(8,10)], 'deep')
    b.poly([(19,10),(24,9),(28,12),(29,25),(27,29),(17,29),(16,24),(16,14)], 'edge')
    b.poly([(19,12),(24,11),(26,13),(27,25),(25,27),(18,27),(18,15)], 'cloth')
    b.poly([(24,12),(26,13),(27,25),(25,27),(24,22)], 'cloth_d')
    b.line([(19,14),(19,23)], 'cloth_h')
    b.poly([(19,11),(23,10),(26,12),(25,14),(20,14)], 'cloth_h')
    b.line([(21,10),(23,12),(24,12)], 'deep')


def held_supplies():
    """P1: two cloth packs behind stakes and an oversized crossed jute cord."""
    b = Brush()
    packs(b)
    # Upright stakes frame an emphatic crossed cord, not a treasure box.
    b.poly([(1,16),(3,13),(5,15),(5,31),(1,31)], 'edge')
    b.poly([(26,15),(28,13),(30,16),(30,31),(26,31)], 'edge')
    b.rect((2,17,3,30), 'wood')
    b.line([(2,16),(2,28)], 'wood_l')
    b.rect((27,17,28,30), 'wood')
    b.line([(27,16),(27,28)], 'wood_l')
    for points in ([(3,17),(27,26)], [(3,26),(27,17)]):
        b.line(points, 'edge', 5)
        b.line(points, 'cord_d', 3)
        b.line([(x,y-1) for x,y in points], 'cord', 2)
        b.line([(x,y-1) for x,y in points], 'cord_h')
    for x in (2,27):
        b.line([(x-1,17),(x+2,16)], 'cord_h')
        b.line([(x-1,26),(x+2,25)], 'cord_h')
    b.poly([(12,18),(16,17),(20,21),(18,25),(14,26),(10,22)], 'edge')
    b.poly([(12,20),(16,19),(18,21),(17,23),(14,24),(12,22)], 'cord')
    b.line([(12,20),(14,22),(16,22),(18,20)], 'cord_h')
    b.line([(14,24),(12,28)], 'cord_d', 3)
    b.line([(14,24),(12,28)], 'cord_h')
    b.line([(17,24),(20,28)], 'cord_d', 3)
    b.line([(17,24),(20,28)], 'cord')
    return b.im
