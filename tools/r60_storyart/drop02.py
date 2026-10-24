"""Round 60 story art drop 02: the five picked sprites (all P2). CC0-1.0.

GPT-6 Astra, 2026-10-24. Original, AI-assisted pixel art. Copied from the
drop's paint.py, trimmed to the user's picks (proposal P2, "hooded and
splayed structures"): a shuttered lantern on a low timber cradle, an
A-frame sight with an open pale ring, an inclined reading cord on unequal
forked pegs, a hinged two-wing register, and the Dispatch Folio's 16x16
inventory icon (a landscape folder with a lowered front flap). Integer
Pillow drawing only; no input images, image models, random numbers, text
drawing or antialiasing.
"""
from PIL import Image, ImageDraw

PAL = {
    'edge': '#27282a', 'deep': '#40352e',
    'wood_s': '#674a35', 'wood': '#8b6543', 'wood_l': '#b28a55', 'cut': '#c5a474',
    'iron_s': '#3c4546', 'iron': '#596361', 'iron_l': '#87928a',
    'glass_s': '#bda66a', 'glass': '#e5d49a', 'glass_l': '#f5ebbe',
    'bone_s': '#a99c77', 'bone': '#d9cba7', 'bone_l': '#f0e6c6',
    'cord_s': '#8e7850', 'cord': '#cdbb89', 'cord_l': '#f1e0af',
    'slate_s': '#414b49', 'slate': '#58625a', 'slate_l': '#748073',
    'paper_s': '#ab9e78', 'paper': '#d7cba6', 'paper_l': '#eee5c8',
    'ink': '#403c35', 'leather_s': '#694734', 'leather': '#966a43',
    'leather_l': '#bb9058', 'mark': '#6c5741',
}


class Brush:
    def __init__(self, side=32):
        self.im = Image.new('RGBA', (side, side), (0,0,0,0))
        self.d = ImageDraw.Draw(self.im)

    def rect(self, box, c):
        self.d.rectangle(box, fill=PAL.get(c,c))

    def poly(self, points, c):
        self.d.polygon(points, fill=PAL.get(c,c))

    def line(self, points, c, width=1):
        self.d.line(points, fill=PAL.get(c,c), width=width)

    def dot(self, xy, c):
        self.d.point(xy, fill=PAL.get(c,c))


def lantern_hood():
    b = Brush()
    # Wooden cradle: two short legs and broad skids, no stone plinth.
    for x in (7,22):
        b.rect((x,21,x+3,29), 'edge')
        b.line([(x+1,22),(x+1,28)], 'wood_l')
        b.rect((x-3,29,x+5,31), 'edge')
        b.line([(x-2,30),(x+4,30)], 'wood')
    b.rect((9,25,23,27), 'edge')
    b.line([(10,26),(22,26)], 'wood_s')
    # Wide six-sided housing with a protruding rain hood and side shutters.
    b.poly([(8,5),(23,5),(29,10),(29,19),(24,24),(7,24),(2,19),(2,10)], 'edge')
    b.poly([(8,6),(23,6),(27,9),(4,9)], 'iron')
    b.line([(9,6),(22,6),(25,8)], 'iron_l')
    b.poly([(4,10),(8,11),(8,21),(4,18)], 'iron')
    b.poly([(24,11),(27,10),(27,18),(24,21)], 'iron_s')
    b.line([(4,11),(4,17)], 'iron_l')
    b.poly([(10,10),(21,10),(24,12),(24,19),(21,22),(10,22),(7,19),(7,12)], 'edge')
    b.poly([(11,11),(20,11),(22,13),(22,18),(20,20),(11,20),(9,18),(9,13)], 'glass_s')
    b.poly([(11,11),(20,11),(22,13),(21,18),(19,19),(11,19),(9,17),(9,13)], 'glass')
    b.poly([(11,11),(20,11),(21,12),(12,12),(10,14),(10,16),(9,16),(9,13)], 'glass_l')
    b.line([(8,22),(23,22)], 'iron')
    b.line([(9,22),(14,22)], 'iron_l')
    b.rect((12,3,19,4), 'edge')
    b.line([(13,3),(18,3)], 'iron')
    return b.im


def ring(b, cx, cy):
    """Rigid octagonal pale ring, with a genuinely open viewing aperture."""
    outer = [(-4,-8),(4,-8),(8,-4),(8,4),(4,8),(-4,8),(-8,4),(-8,-4)]
    core = [(-3,-6),(3,-6),(6,-3),(6,3),(3,6),(-3,6),(-6,3),(-6,-3)]
    hole = [(-2,-3),(2,-3),(3,-2),(3,2),(2,3),(-2,3),(-3,2),(-3,-2)]
    at = lambda pts: [(cx+x,cy+y) for x,y in pts]
    b.poly(at(outer), 'edge')
    b.poly(at(core), 'bone_s')
    b.line(at([(-6,2),(-6,-3),(-3,-6),(3,-6),(5,-4)]), 'bone_l', 2)
    b.line(at([(6,-2),(6,3),(3,6),(-3,6),(-5,4)]), 'bone', 2)
    # This clear aperture is cut before the timber mount is added.
    b.poly(at(hole), (0,0,0,0))
    b.line(at([(-4,-2),(-4,2),(-2,4),(2,4),(4,2)]), 'edge')


def sighting_tripod():
    b = Brush()
    # Splayed timber A-frame with a low horizontal brace.
    b.line([(15,2),(3,30)], 'edge', 5)
    b.line([(17,2),(29,30)], 'edge', 5)
    b.line([(15,3),(4,29)], 'wood', 3)
    b.line([(17,3),(28,29)], 'wood_s', 3)
    b.line([(14,5),(4,29)], 'wood_l')
    b.line([(18,6),(28,28)], 'wood')
    b.rect((2,29,8,31), 'edge')
    b.rect((24,29,30,31), 'edge')
    b.line([(3,30),(7,30)], 'wood_l')
    b.line([(25,30),(29,30)], 'wood')
    ring(b, 16, 14)
    b.rect((6,24,26,27), 'edge')
    b.rect((7,25,25,26), 'wood')
    b.line([(8,25),(23,25)], 'wood_l')
    b.rect((14,2,18,5), 'iron_s')
    b.line([(14,3),(17,3)], 'iron_l')
    b.rect((7,13,9,15), 'iron')
    b.rect((23,13,25,15), 'iron')
    b.dot((7,13), 'iron_l')
    b.dot((24,13), 'iron_l')
    return b.im


def peg(b, x, top, fork=False):
    b.poly([(x,top+2),(x+1,top),(x+4,top+1),(x+4,31),(x,31)], 'edge')
    b.rect((x+1,top+3,x+3,30), 'wood_s')
    b.line([(x+1,top+3),(x+1,29)], 'wood_l')
    b.line([(x+2,top+5),(x+2,28)], 'wood')
    b.poly([(x+1,top+1),(x+3,top+1),(x+3,top+2),(x+1,top+3)], 'cut')
    if fork:
        b.rect((x+2,top,x+2,top+3), (0,0,0,0))


def knot(b, x, y, turn=False):
    """Two diagonal overlapping wraps; attached to the taut horizontal strand."""
    # Five-pixel width leaves visible straight cord between all three knots.
    # The seven-pixel height and two lobes make the wraps larger than the strand.
    rows = ('.ee..', 'ehhe.', 'ehsce', 'echhe', 'eshce', '.ehe.', '..e..')
    colors = {'e':'edge', 'h':'cord_l', 'c':'cord', 's':'cord_s'}
    for dy,row in enumerate(rows):
        for dx,c in enumerate(row):
            if c != '.':
                xx = 4-dx if turn else dx
                b.dot((x+xx-2,y+dy-3),colors[c])


def knots_raked():
    b = Brush()
    peg(b, 1, 13, True)
    peg(b, 27, 20, True)
    b.line([(3,17),(29,24)], 'edge', 4)
    b.line([(3,16),(29,23)], 'cord_l')
    b.line([(3,17),(29,24)], 'cord')
    for x,y in ((8,18),(15,20),(25,23)):
        knot(b, x,y, turn=True)
    b.line([(2,20),(4,20)], 'cord_s')
    b.line([(28,26),(30,26)], 'cord_s')
    return b.im


def notice_wings():
    b = Brush()
    # Open two-wing register, staggered tops and flared supports.
    b.line([(8,22),(5,30)], 'edge', 4)
    b.line([(24,22),(28,30)], 'edge', 4)
    b.line([(8,23),(6,30)], 'wood_l', 2)
    b.line([(24,23),(27,30)], 'wood', 2)
    b.rect((2,30,9,31), 'edge')
    b.rect((24,30,30,31), 'edge')
    b.rect((7,26,25,28), 'edge')
    b.line([(8,27),(24,27)], 'wood_s')
    b.poly([(1,7),(14,5),(17,8),(17,24),(2,25)], 'edge')
    b.poly([(2,8),(13,6),(15,8),(15,23),(3,23)], 'wood_s')
    b.poly([(3,10),(13,8),(13,21),(4,22)], 'slate')
    b.line([(3,8),(12,7)], 'wood_l')
    b.poly([(16,5),(28,2),(30,4),(30,23),(16,25)], 'edge')
    b.poly([(18,6),(28,4),(28,21),(18,23)], 'paper_s')
    b.poly([(19,7),(27,5),(27,20),(19,21)], 'paper')
    b.line([(18,5),(28,3)], 'wood_l')
    b.line([(29,5),(29,22)], 'wood_s')
    b.rect((15,8,17,23), 'wood_s')
    b.rect((14,10,18,11), 'iron')
    b.rect((14,20,18,21), 'iron')
    b.dot((15,10), 'iron_l')
    b.dot((15,20), 'iron_l')
    # Each column follows its own leaf, still only abstract short strokes.
    for y,n in ((11,6),(16,4),(20,5)):
        b.rect((5,y,5+n-1,y+1), 'paper_l')
    for y,n in ((8,5),(13,6),(18,5)):
        b.line([(20,y+1),(20+n-1,y)], 'mark')
    b.line([(26,6),(20,21)], 'ink', 2)
    return b.im


def folio_front():
    b = Brush(16)
    # A landscape folder with a lowered front flap and offset pale form stack.
    b.poly([(3,1),(12,1),(14,3),(15,11),(12,14),(2,14),(0,11),(1,4)], 'deep')
    b.poly([(3,2),(12,2),(13,4),(2,6)], 'leather')
    b.line([(4,2),(11,2)], 'leather_l')
    b.poly([(2,5),(11,3),(13,4),(14,10),(4,12),(1,10)], 'paper_s')
    b.line([(3,11),(13,9)], 'paper_l')
    b.poly([(3,4),(11,3),(12,4),(12,9),(3,10)], 'paper')
    b.line([(3,4),(10,3)], 'paper_l')
    b.line([(3,5),(3,8)], 'paper_l')
    b.rect((5,5,8,6), 'ink')
    b.line([(4,9),(11,8)], 'paper_l')
    b.line([(4,11),(12,10)], 'paper_l')
    b.poly([(1,11),(6,12),(13,11),(12,13),(3,13)], 'leather')
    b.line([(2,11),(6,12),(12,11)], 'leather_l')
    b.line([(4,13),(11,13)], 'leather_s')
    return b.im
