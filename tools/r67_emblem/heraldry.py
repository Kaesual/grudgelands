"""Original Pass 3 heraldry, drawn with Pillow/numpy; no external art inputs."""
import re

import numpy as np
from PIL import Image, ImageDraw

SCALE = 6
IVORY = '#d6c59b'
GOLD = '#aa9164'
VARIANTS = ('1', '2', '3')
IDEAS = {
    'accord': {
        '1': ('A1', 'The Watchful Hart', 'A hart caboshed: slender, mirrored antlers above a long face, held on a weathered shield.'),
        '2': ('A2', 'The Standing Hart', 'A hart statant: an upright neck, a quiet back and four fine legs beneath branching antlers.'),
        '3': ('A3', 'The Oathhart', 'A hart head couped in profile: a long neck and sweeping tines, like an old embroidered livery.'),
    },
    'throng': {
        '1': ('B1', 'The Ironwood Boar', 'A boar head couped in profile: a long snout, a rising tusk and a sharply bristled nape.'),
        '2': ('B2', 'The Marching Boar', 'A boar passant: a low head, a heavy shoulder and four stout legs moving beneath a bristled back.'),
        '3': ('B3', 'The Defiant Boar', 'A boar caboshed: wide ears, a blunt snout and paired tusks framed by an ordered bristled mane.'),
    },
}



def down(im, size):
    return im.resize(size, Image.Resampling.LANCZOS)


def path(draw, spec, fill=None, stroke=None, width=1):
    """Rasterize our own small M/L/C/Q/Z paths, in 100-unit art coordinates."""
    tokens = re.findall(r'[MLCQZ]|-?\d+(?:\.\d+)?', spec)
    points = []
    i = 0
    while i < len(tokens):
        command = tokens[i]
        i += 1
        count = {'M': 2, 'L': 2, 'C': 6, 'Q': 4, 'Z': 0}[command]
        values = list(map(float, tokens[i:i+count]))
        i += count
        if command == 'M' and points:
            raise ValueError('Each path must contain only one subpath')
        if command in ('M', 'L'):
            points.append(tuple(values))
        elif command in ('C', 'Q'):
            p0 = np.array(points[-1])
            controls = np.array(values).reshape(-1, 2)
            for t in np.linspace(0, 1, 25)[1:]:
                if command == 'C':
                    p = ((1-t)**3*p0 + 3*(1-t)**2*t*controls[0]
                         + 3*(1-t)*t*t*controls[1] + t**3*controls[2])
                else:
                    p = (1-t)**2*p0 + 2*(1-t)*t*controls[0] + t*t*controls[1]
                points.append(tuple(p))
        else:
            points.append(points[0])
    pixels = [(round(x*SCALE), round(y*SCALE)) for x, y in points]
    if fill is not None:
        draw.polygon(pixels, fill=fill)
    if stroke is not None:
        draw.line(pixels, fill=stroke, width=max(1, round(width*SCALE)), joint='curve')


def ellipse(draw, box, fill):
    draw.ellipse(tuple(round(v*SCALE) for v in box), fill=fill)


def mirror(mask):
    """Exactly mirror the raster geometry, including half-pixel sample centres."""
    return Image.fromarray(np.maximum(np.array(mask), np.array(mask)[:, ::-1]))


def hart_front(d, h):
    # Tapered antler beams and individual tines, with open field between them.
    # The whole charge is mirrored after drawing; neither side is freehand drift.
    for shape in (
        'M44 43 C35 36 29 29 26 20 C24 14 25 7 28 2 C26 13 29 24 35 30 L46 39 Z',
        'M28 25 C18 24 12 17 10 8 C14 16 20 21 28 22 Z',
        'M33 32 C24 34 17 30 13 24 C19 29 25 30 31 29 Z',
        'M26 17 C31 13 34 8 35 2 C37 10 32 17 27 20 Z',
        'M35 32 C36 24 39 21 40 17 C42 23 39 30 38 35 Z',
        'M41 46 C32 41 25 39 18 40 C21 48 29 54 39 55 Z',
        'M50 39 Q43 38 40 43 L38 51 L40 65 Q41 72 45 80 L45 86 Q47 90 50 91 Z',
    ):
        path(d, shape, 255)
    # Deliberate eye, ear and nostril cuts; the surrounding face stays connected.
    path(d, 'M24 43 Q32 44 37 49 Q30 49 24 43 Z', 0)
    path(d, 'M40 57 L46 59 L44 62 L41 61 Z', 0)
    path(d, 'M46 82 L49 83 L48 85 L46 85 Z', 0)
    path(h, 'M48 47 Q45 57 47 70', stroke=230, width=1.3)
    path(h, 'M42 64 Q43 72 46 76', stroke=210, width=1.3)


def hart_standing(d, h):
    # A continuous torso, neck and muzzle; legs are separate deliberate profiles.
    path(d, 'M43 49 C52 52 69 50 78 52 Q90 53 91 62 L85 71 Q78 73 72 70 Q60 72 49 67 C43 63 37 56 34 47 L30 35 L22 36 L13 32 L14 28 L27 24 L32 21 Q39 23 39 30 L39 40 Z', 255)
    path(d, 'M30 24 Q22 23 21 16 Q29 17 34 23 Z', 255)
    path(d, 'M35 24 Q36 17 42 16 Q43 23 37 28 Z', 255)
    # Back legs first, then the weight-bearing near legs; wide intervening gaps.
    path(d, 'M48 62 L42 76 L35 86 L29 87 L29 90 L38 90 L47 78 L53 65 Z', 255)
    path(d, 'M81 64 L77 74 L84 84 L84 88 L78 89 L78 92 L89 92 L88 82 L84 73 L89 66 Z', 255)
    path(d, 'M45 60 L50 66 L47 88 L43 90 L43 93 L52 93 L52 88 L54 68 Z', 255)
    path(d, 'M88 62 L93 64 L91 77 L95 88 L95 92 L87 92 L87 89 L90 88 L85 77 Z', 255)
    path(d, 'M87 56 Q94 52 97 56 Q97 60 91 61 Z', 255)
    # Small, tapering crown of antlers above the side-facing head.
    for shape in (
        'M32 25 C27 18 27 9 31 2 C29 11 30 17 35 23 Z',
        'M29 14 Q21 14 18 5 Q23 11 29 11 Z',
        'M29 8 L37 2 Q35 9 30 11 Z',
        'M37 25 Q41 17 47 8 Q45 19 40 27 Z',
        'M42 18 Q38 14 39 8 L44 15 Z',
        'M44 15 Q49 14 53 9 Q52 17 43 20 Z',
    ):
        path(d, shape, 255)
    ellipse(d, (27, 27, 30, 30), 0)
    path(d, 'M14 29 L19 29 L18 32 L14 31 Z', 0)
    path(h, 'M35 34 Q34 45 44 56', stroke=220, width=1.3)
    path(h, 'M55 56 Q68 58 77 56', stroke=180, width=1.3)
    path(h, 'M79 61 Q76 66 79 71', stroke=210, width=1.3)


def hart_profile(d, h):
    # Long upright neck, alert ears and a fine muzzle. Cut base, never a blob.
    path(d, 'M44 35 C53 33 60 39 62 49 L59 65 Q60 79 67 89 L35 89 Q49 76 46 64 L39 48 L28 48 L15 43 L13 39 L30 33 Q37 29 44 35 Z', 255)
    path(d, 'M43 36 Q49 26 60 29 Q58 38 50 41 Z', 255)
    path(d, 'M35 35 Q26 32 24 26 Q34 27 41 34 Z', 255)
    # Two distinct swept antlers, the nearer larger; all tips narrow to a point.
    for shape in (
        'M41 35 C36 25 34 13 40 2 C37 15 40 24 45 34 Z',
        'M37 22 Q25 19 22 10 Q29 17 37 19 Z',
        'M37 13 Q30 9 31 2 L39 11 Z',
        'M39 28 Q29 28 25 23 Q32 25 40 25 Z',
        'M48 34 C52 27 60 18 65 4 C64 20 57 29 52 37 Z',
        'M56 23 Q51 17 53 9 Q55 16 59 19 Z',
        'M61 15 Q70 13 74 7 Q73 16 62 19 Z',
        'M53 29 Q65 27 70 21 Q69 30 54 32 Z',
    ):
        path(d, shape, 255)
    path(d, 'M50 34 L56 31 L53 36 Z', 0)
    path(d, 'M30 37 L35 37 L33 40 L30 39 Z', 0)
    path(d, 'M14 40 L19 40 L18 43 L15 43 Z', 0)
    path(h, 'M47 44 Q52 59 53 70 Q54 78 60 84', stroke=230, width=1.3)
    path(h, 'M20 44 L30 45', stroke=230, width=1.3)


def boar_profile(d, h):
    # Forehead slopes into a long blunt snout. Bristles follow the nape, not a crown.
    path(d, 'M19 43 L32 37 Q42 24 53 25 L61 20 L62 26 L69 24 L68 31 L76 30 L74 37 L82 37 L79 44 L86 47 L81 53 L87 59 L81 62 Q76 74 77 84 L43 84 Q46 77 43 71 Q35 68 29 60 L15 59 L9 56 L8 44 L12 41 Z', 255)
    # Distinct triangular ear: sloping base separates it from the bristled nape.
    path(d, 'M46 32 Q42 24 43 13 Q53 16 59 27 L54 38 Z', 255)
    path(d, 'M47 20 L54 28 L50 32 Z', 0)
    # Mouth is a broad field cut; the rising lower tusk grows through that space.
    path(d, 'M13 53 L27 53 Q36 53 42 51 L40 54 Q33 57 25 56 L14 56 Z', 0)
    tusk = 'M28 59 C36 61 39 50 33 36 C45 45 42 62 33 64 Z'
    path(d, tusk, 255, stroke=0, width=3)
    path(d, tusk, 255)
    path(d, 'M39 34 L46 32 L44 36 L40 37 Z', 0)
    path(d, 'M12 45 L16 45 L17 49 L13 49 Z', 0)
    # Engraved cheek and ordered hair cuts, consistent light line weight.
    path(h, 'M54 42 Q48 55 56 67 Q59 73 67 76', stroke=230, width=1.3)
    path(h, 'M65 39 L62 49', stroke=220, width=1.3)
    path(h, 'M71 47 L68 57', stroke=220, width=1.3)
    path(h, 'M76 58 L73 67', stroke=220, width=1.3)
    path(h, 'M53 79 L72 79', stroke=190, width=1.3)


def boar_walking(d, h):
    # Stout, arched shoulder and low muzzle, with bristles along the actual back.
    path(d, 'M12 51 L26 47 L34 34 L39 24 L44 28 L49 20 L53 25 L59 18 L62 24 L68 19 L70 25 L77 22 L79 28 Q92 29 94 44 L93 54 Q87 66 76 65 L60 65 L49 63 Q43 69 34 65 L24 62 L13 63 L8 59 L7 52 Z', 255)
    # Four legs with readable knee direction and broad cloven feet.
    path(d, 'M41 58 L45 65 L38 77 L27 80 L23 77 L24 74 L33 73 Z', 255)
    path(d, 'M70 60 L78 61 L77 69 L85 78 L84 82 L76 82 L75 79 L69 71 Z', 255)
    path(d, 'M48 59 L55 63 L51 78 L51 84 L40 84 L39 80 L44 78 Z', 255)
    path(d, 'M85 57 L93 53 L89 68 L94 81 L92 85 L81 85 L80 81 L85 80 L81 70 Z', 255)
    path(d, 'M29 39 Q26 29 31 25 L41 35 L36 46 Z', 255)
    path(d, 'M31 31 L36 36 L33 39 Z', 0)
    # A thin hooked tail, separate from legs and body silhouette.
    path(d, 'M91 35 Q101 29 98 43 L96 49 L94 47 Q98 32 92 38 Z', 255)
    path(d, 'M11 57 L23 56 L33 52 L34 56 L24 60 L12 60 Z', 0)
    path(d, 'M24 61 Q34 63 34 47 Q41 59 31 66 Z', 0)
    path(d, 'M25 61 Q32 62 33 49 Q38 60 30 64 Z', 255)
    path(d, 'M25 47 L30 45 L30 49 L26 50 Z', 0)
    ellipse(d, (10, 53, 13, 56), 0)
    path(h, 'M46 37 Q39 49 48 58', stroke=220, width=1.3)
    path(h, 'M53 32 Q70 30 81 34', stroke=200, width=1.3)
    path(h, 'M79 43 Q75 51 81 56', stroke=220, width=1.3)


def boar_front(d, h):
    # Symmetrical boar mask: nape spikes descend along the cheek, ears project wide.
    for shape in (
        'M50 17 L45 15 L43 20 L36 16 L35 23 L28 21 L29 29 L21 29 L25 37 L17 40 L23 46 L18 52 L24 57 L20 63 L27 68 L25 74 L34 78 L35 84 L44 86 L50 89 Z',
        'M37 31 Q26 19 11 19 Q13 36 29 42 L37 39 Z',
    ):
        path(d, shape, 255)
    path(d, 'M18 24 Q26 25 32 33 L28 35 Q22 31 18 24 Z', 0)
    # Temple/eye cuts leave a long wedge muzzle distinctly apart from the cheeks.
    path(d, 'M28 44 L39 45 L37 49 L30 49 Z', 0)
    path(d, 'M39 52 Q36 62 38 68', stroke=0, width=1.4)
    # Cut around each curved tusk, then draw its narrower ivory inside.
    path(d, 'M39 76 C23 77 20 64 25 53 C25 65 29 69 37 67 Z', 0)
    path(d, 'M38 74 C25 75 22 65 25 56 C26 65 30 70 38 69 Z', 255)
    path(h, 'M42 31 L44 51', stroke=220, width=1.3)
    path(h, 'M30 56 L28 62', stroke=220, width=1.3)
    # Half of the blunt nose disk, mirrored into a broad uninterrupted snout.
    path(h, 'M50 64 Q42 63 40 67 L40 75 Q44 79 50 79 Z', 230)
    ellipse(d, (43, 69, 47, 73), 0)
    path(d, 'M44 82 L50 83 L50 84 L44 84 Z', 0)


def motif(faction, variant):
    """Hand-authored contours, negative-space cuts and restrained gold engraving."""
    mask = Image.new('L', (100*SCALE, 100*SCALE))
    detail = Image.new('L', mask.size)
    drawing = {
        ('accord', '1'): hart_front, ('accord', '2'): hart_standing,
        ('accord', '3'): hart_profile, ('throng', '1'): boar_profile,
        ('throng', '2'): boar_walking, ('throng', '3'): boar_front,
    }[faction, variant]
    drawing(ImageDraw.Draw(mask), ImageDraw.Draw(detail))
    if (faction, variant) in (('accord', '1'), ('throng', '3')):
        mask, detail = mirror(mask), mirror(detail)
    detail = Image.fromarray(np.minimum(np.array(detail), np.array(mask)))
    return mask, detail


def paint(mask, colour, seed, thread=False):
    """Matte pigment/thread, with small tonal variations, never shiny facets."""
    w, h = mask.size
    y, x = np.mgrid[:h, :w].astype(float) / SCALE
    rng = np.random.default_rng(seed)
    variation = 1 + .028*np.sin(x*.23+y*.15) + .021*np.cos(y*.37-x*.09)
    # Native-pixel-sized dye flecks survive reduction; seeded and repeatable.
    grain = rng.uniform(-1, 1, ((h+SCALE-1)//SCALE, (w+SCALE-1)//SCALE))
    grain = np.repeat(np.repeat(grain, SCALE, 0), SCALE, 1)[:h, :w]
    variation += .034*grain
    if thread:
        variation += .024*np.sin((x+y*.5)*np.pi*2) + .009*rng.standard_normal((h, w))
    else:
        variation += .008*np.sin(y*np.pi*2) + .008*np.cos(x*np.pi*2)
    rgb = np.array(Image.new('RGB', (1, 1), colour).getpixel((0, 0)))
    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[:, :, :3] = np.clip(rgb*variation[:, :, None], 0, 255).astype(np.uint8)
    out[:, :, 3] = np.array(mask)
    return Image.fromarray(out)


SHIELD = 'M9 12 Q24 14 34 7 Q50 12 66 7 Q78 14 91 12 L89 47 C86 71 70 88 50 96 C30 88 14 71 11 47 Z'
INNER = 'M13 17 Q25 18 35 12 Q50 17 65 12 Q77 18 87 17 L85 47 C82 68 68 84 50 91 C32 84 18 68 15 47 Z'


def icon(faction, variant, palette):
    cloth, ink = palette[faction]
    mask = Image.new('L', (100*SCALE, 100*SCALE))
    path(ImageDraw.Draw(mask), SHIELD, 255)
    im = paint(mask, cloth, 1)
    d = ImageDraw.Draw(im)
    path(d, SHIELD, stroke=GOLD, width=1.6)
    path(d, INNER, stroke='#85734f', width=.55)
    silhouette, details = motif(faction, variant)
    # A restrained coloured field leaves almost the full face to the charge.
    charge = paint(silhouette, ink, 21, thread=True)
    charge.alpha_composite(paint(details, GOLD, 22, thread=True))
    size, x, y = {
        ('accord', '1'): (83, 8, 12), ('accord', '2'): (64, 16, 12),
        ('accord', '3'): (80, 10, 9), ('throng', '1'): (82, 9, 9),
        ('throng', '2'): (69, 14, 10), ('throng', '3'): (82, 9, 7),
    }[faction, variant]
    charge = down(charge, (size*SCALE, size*SCALE))
    im.alpha_composite(charge, (x*SCALE, y*SCALE))
    d = ImageDraw.Draw(im)
    # Few stitches/rivets, subordinate to the light silhouette.
    for x, y in ((16, 20), (84, 20), (50, 88)):
        ellipse(d, (x-.8, y-.8, x+.8, y+.8), IVORY)
    for y, x in ((29, 14.5), (35, 15), (41, 15.5), (47, 16.5), (53, 18)):
        for mirror in (False, True):
            xx = 100-x if mirror else x
            path(d, f'M{xx} {y} L{xx+.3} {y+1.6}', stroke=GOLD, width=.65)
    return im


def banner(faction, variant, palette, reference):
    cloth, ink = palette[faction]
    w, h = 128*SCALE, 256*SCALE
    y, x = np.mgrid[:h, :w].astype(float)/SCALE
    rgb = np.array(Image.new('RGB', (1, 1), cloth).getpixel((0, 0)))
    # Crossed warp/weft, slow dye variation, faded edges and rubbed hem.
    weave = .011*np.sin(x*np.pi*2) + .014*np.sin(y*np.pi)
    folds = .022*np.cos(x*.22) + .012*np.sin(x*.47+y*.025)
    wear = .02*np.sin(x*.13+y*.07)*np.sin(y*.12)
    edge = np.exp(-np.minimum(abs(x-9), abs(x-119))/4.8)
    hem_y = 226-abs(x-64)*.34
    hem = np.exp(-abs(y-hem_y)/4)
    fade = .065*edge + .08*hem
    data = np.zeros((h, w, 4), dtype=np.uint8)
    surface = rgb[None, None, :]*(1+weave+folds+wear)[:, :, None]
    surface += (np.array([155, 139, 108])-rgb)[None, None, :]*fade[:, :, None]
    grain = np.random.default_rng(67).uniform(-1.3, 1.3, (256, 128))
    grain = np.repeat(np.repeat(grain, SCALE, 0), SCALE, 1)
    surface += grain[:, :, None]
    data[:, :, :3] = np.clip(surface, 0, 255).astype(np.uint8)
    data[:, :, 3] = 255
    im = Image.fromarray(data)
    # Border follows the existing pointed cloth cut, not a new rectangle.
    trim = Image.new('L', (w, h))
    td = ImageDraw.Draw(trim)
    path(td, 'M16 37 L112 37 L112 204 L64 220 L16 204 Z', stroke=255, width=1.4)
    path(td, 'M20 41 L108 41 L108 201 L64 215 L20 201 Z', stroke=190, width=.55)
    # A little vinework in the corners, and a tied leaf spray near the hem.
    for mirror in (False, True):
        decor = Image.new('L', (w, h))
        dd = ImageDraw.Draw(decor)
        path(dd, 'M24 67 Q24 47 42 47 Q49 48 45 54 Q40 57 38 52', stroke=190, width=.9)
        path(dd, 'M26 57 Q29 47 35 48 Q35 54 26 57 Z', 210)
        path(dd, 'M23 66 Q33 59 35 64 Q32 69 23 66 Z', 180)
        path(dd, 'M64 202 Q48 200 40 189', stroke=210, width=.8)
        path(dd, 'M50 197 Q41 195 43 186 Q51 188 50 197 Z', 220)
        path(dd, 'M57 200 Q51 191 55 188 Q62 192 57 200 Z', 220)
        if mirror:
            decor = decor.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        trim = Image.fromarray(np.maximum(np.array(trim), np.array(decor)))
    im.alpha_composite(paint(trim, GOLD, 31, thread=True))
    silhouette, details = motif(faction, variant)
    charge = paint(silhouette, ink, 41, thread=True)
    charge.alpha_composite(paint(details, GOLD, 42, thread=True))
    charge = down(charge, (92*SCALE, 92*SCALE))
    im.alpha_composite(charge, (18*SCALE, 79*SCALE))
    # Worn threads inside the silhouette: the model's alpha stays untouched.
    d = ImageDraw.Draw(im)
    for i in range(41):
        px = 18 + i*2.3
        py = 224-abs(px-64)*.34
        path(d, f'M{px:.3f} {py-1.6:.3f} L{px+.7:.3f} {py-4.4:.3f}',
             stroke=(*rgb.astype(int), 255), width=.65)
    im = down(im, (128, 256))
    im.putalpha(reference.getchannel('A'))
    data = np.array(im)
    data[data[:, :, 3] == 0, :3] = 0
    return Image.fromarray(data)
