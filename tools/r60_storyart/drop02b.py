"""Round 60 story art drop 02b: the picked Captain's Orders icons. CC0-1.0.

GPT-6 Astra, 2026-10-24. Original, AI-assisted pixel art. Copied from the
drop's paint.py, trimmed to the user's pick (proposal P2, rolled
despatches): a tight diagonal roll tied to a hanging seal tag, steel-blue
with a brass clamp and pale wax for The Accord, warm paper with ochre
wraps and oxblood wax for The Throng, a scorched upper rim on both.
16x16 inventory icons. Integer Pillow drawing only; no input images, image
models, random numbers, lettering or antialiasing.
"""
from PIL import Image, ImageDraw


PAL = {
    'edge': '#27282a',
    'blue_s': '#3a5061', 'blue': '#59778b', 'blue_l': '#8faab2',
    'paper_s': '#927451', 'paper': '#bf9f70', 'paper_l': '#e0c699',
    'brass_s': '#766139', 'brass': '#aa8c4c', 'brass_l': '#d7be7b',
    'cord_s': '#79592f', 'cord': '#c29649', 'cord_l': '#e4c379',
    'wax_s': '#786f59', 'wax_d': '#a99c77', 'wax': '#d9cba7', 'wax_l': '#f0e6c6',
    'red_s': '#3a2430', 'red_d': '#652f3f', 'red': '#91494e', 'red_l': '#ba746b',
    'scorch': '#453632', 'char': '#292729', 'ash': '#796858',
}


class Brush:
    def __init__(self):
        self.im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def poly(self, points, colour):
        self.d.polygon(points, fill=PAL[colour])

    def rect(self, box, colour):
        self.d.rectangle(box, fill=PAL[colour])

    def line(self, points, colour):
        self.d.line(points, fill=PAL[colour], width=1)

    def dot(self, xy, colour):
        self.d.point(xy, fill=PAL[colour])


def seal(b, x, y, faction):
    """Five-pixel wax puddle, blank face and clipped irregular edge."""
    rows = ('.sss.', 'shhws', 'shwws', 'swwds', '.sds.')
    family = 'wax' if faction == 'accord' else 'red'
    colours = {'s': family + '_s', 'h': family + '_l',
               'w': family, 'd': family + '_d'}
    for dy, row in enumerate(rows):
        for dx, c in enumerate(row):
            if c != '.':
                b.dot((x + dx, y + dy), colours[c])


def roll(faction):
    """P2: tightly rolled diagonal despatch, tied to a hanging seal tag."""
    b = Brush()
    base = 'blue' if faction == 'accord' else 'paper'
    # Tag behind the body; its short neck remains visible above the wax.
    b.poly([(9, 8), (11, 8), (12, 12), (10, 14), (8, 12)], 'edge')
    b.poly([(10, 9), (10, 12), (11, 12), (11, 10)], base + '_l')
    # Narrow roll rises from lower left to upper right, with stepped end rims.
    b.poly([(9, 1), (12, 1), (14, 3), (14, 5), (6, 13),
            (3, 13), (1, 11), (1, 9)], 'edge')
    b.poly([(9, 2), (12, 2), (13, 3), (13, 5), (6, 12),
            (3, 12), (2, 11), (2, 9)], base + '_s')
    b.poly([(9, 3), (11, 3), (12, 5), (5, 11), (3, 10), (3, 9)], base)
    b.line([(3, 9), (9, 3), (11, 3)], base + '_l')
    b.line([(4, 10), (9, 5)], base)
    # Small curled ends, entirely closed; no open pale document face.
    b.line([(9, 2), (11, 2), (13, 4), (12, 5)], base + '_l')
    # A tiny exposed cut-paper lip makes the roll distinct from a metal tube.
    b.line([(9, 2), (11, 2)], 'wax')
    b.dot((10, 2), 'wax_l')
    b.line([(10, 3), (11, 3), (12, 4)], base + '_s')
    b.dot((11, 4), base + '_s')
    b.line([(2, 9), (2, 10), (4, 12), (5, 12)], base + '_l')
    b.line([(3, 9), (4, 10), (4, 11)], base + '_s')
    b.dot((3, 10), 'edge')
    # Scorch on the outer corner of the upper rim.
    b.poly([(12, 2), (13, 3), (13, 6), (11, 4)], 'scorch')
    b.line([(13, 3), (14, 4)], 'char')
    b.dot((12, 4), 'ash')
    if faction == 'accord':
        # Rigid brass clamp crosses the blue cylinder.
        b.line([(6, 5), (9, 8)], 'brass_s')
        b.line([(5, 6), (8, 9)], 'brass_l')
        b.line([(6, 7), (8, 9)], 'brass')
        b.dot((7, 7), 'brass_s')
        b.line([(9, 9), (10, 10)], 'brass')
    else:
        # Two thin cord wraps and their short trailing knot.
        b.line([(6, 5), (9, 8)], 'cord_s')
        b.line([(5, 6), (8, 9)], 'cord_l')
        b.line([(4, 7), (7, 10)], 'cord')
        b.dot((8, 8), 'cord_s')
        b.line([(8, 9), (10, 9), (11, 10)], 'cord_l')
        b.dot((7, 11), 'cord')
    seal(b, 8, 10, faction)
    return b.im
