"""Original Pass 2 heraldry, drawn with Pillow/numpy; no external art inputs."""
import re

import numpy as np
from PIL import Image, ImageDraw

SCALE = 6
IVORY = '#d6c59b'
GOLD = '#aa9164'
IDEAS = {
    'a': ('Hart & Boar', 'The Oathhart', 'The Unbowed Boar',
          'A hart bears a branching antler on either side: unlike homelands held in one proud pact.',
          'A bristled boar turns its tusk toward the foe: many peoples standing stubbornly together.'),
    'b': ('Oak & Horn', 'The Bound Oak', 'The Gathering Horn',
          'Three oak boughs share a stout trunk and roots: the pact has grown deep into its homelands.',
          'A heavy, bound war horn calls scattered voices into one host, sworn to its own oaths.'),
    'c': ('Falcon & Serpent', 'The Vigil Falcon', 'The Unbroken Coil',
          'A folded-wing falcon keeps watch above the border: a compact herald of shared vigilance.',
          'A coiled serpent raises its head without yielding: a host whose will cannot be bound.'),
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


def motif(faction, variant):
    """Return a full-sized silhouette and sparse thread-detail mask."""
    mask = Image.new('L', (100*SCALE, 100*SCALE))
    detail = Image.new('L', mask.size)
    d, h = ImageDraw.Draw(mask), ImageDraw.Draw(detail)
    if variant == 'a' and faction == 'accord':
        # The forehead and antlers remain one connected silhouette.
        left = 'M44 45 C34 37 25 33 22 22 Q20 13 22 7 C16 13 16 24 21 32 Q10 27 5 13 Q3 25 8 31 L23 42 Q32 46 39 50 Z'
        path(d, left, 255)
        path(d, 'M26 36 L29 22 L26 10 L35 20 L35 37 Z', 255)
        path(d, 'M19 32 L8 35 L2 29 L5 41 L31 45 Z', 255)
        mask = Image.fromarray(np.maximum(np.array(mask), np.array(mask)[:, ::-1]))
        d = ImageDraw.Draw(mask)
        path(d, 'M40 41 C43 37 57 37 60 42 L64 47 Q73 40 81 43 Q78 56 65 59 L61 75 Q59 86 50 91 Q41 86 39 75 L35 59 Q22 56 19 43 Q28 40 36 47 Z', 255)
        path(d, 'M38 60 L44 62 L42 66 L38 64 Z', 0)
        path(d, 'M62 60 L56 62 L58 66 L62 64 Z', 0)
        path(h, 'M50 47 Q45 65 50 77 Q54 66 50 47 Z', 170)
        path(h, 'M45 83 Q50 86 55 82', stroke=200, width=1.3)
    elif variant == 'a':
        # Broad side profile, bristles, snout and a single unmistakable tusk.
        path(d, 'M12 76 Q18 57 16 46 L9 40 L23 35 L17 26 L33 27 L29 16 L45 23 L48 12 L59 26 Q70 28 77 42 L94 48 L96 62 L85 68 L69 68 Q65 80 54 83 L25 89 Z', 255)
        path(d, 'M49 33 Q52 18 64 15 L61 40 Z', 255)
        # Cut a field-coloured crescent behind the rising tusk.
        path(d, 'M66 54 Q78 69 92 57 Q82 81 64 72 Z', 0)
        path(d, 'M60 66 Q78 83 86 46 Q94 78 69 81 Z', 255)
        ellipse(d, (67, 40, 73, 45), 0)
        ellipse(d, (87, 52, 92, 57), 0)
        path(h, 'M28 43 Q27 65 39 76', stroke=180, width=2.3)
        path(h, 'M35 40 Q34 59 44 68', stroke=150, width=1.5)
        path(h, 'M54 33 L59 23', stroke=200, width=2)
    elif variant == 'b' and faction == 'accord':
        # Three generous lobed boughs, no geometrical arrow tips.
        path(d, 'M44 52 L56 52 L56 70 Q66 79 78 83 L83 91 L61 86 L50 81 L38 87 L17 91 L23 82 Q36 77 43 69 Z', 255)
        path(d, 'M46 62 L27 55 L20 41 L29 36 L38 50 L47 52 Z', 255)
        path(d, 'M53 60 L73 54 L81 40 L71 36 L64 48 L53 51 Z', 255)
        path(d, 'M42 39 C32 34 32 26 39 24 C31 16 39 10 44 12 Q49 0 55 11 C65 8 71 18 63 24 C71 30 66 38 58 38 L57 48 L44 49 Z', 255)
        path(d, 'M33 49 C27 55 17 53 18 46 C7 49 1 40 10 35 C2 28 9 20 17 25 C20 16 31 21 29 29 C41 27 43 40 34 42 Z', 255)
        path(d, 'M66 48 C74 55 84 51 82 45 C94 47 99 38 90 33 C98 24 88 18 81 24 C79 15 67 20 70 29 C58 28 57 39 65 42 Z', 255)
        path(h, 'M50 18 Q47 46 50 73', stroke=160, width=2.2)
        path(h, 'M17 32 Q28 34 32 44', stroke=160, width=1.5)
        path(h, 'M84 31 Q72 35 69 43', stroke=160, width=1.5)
    elif variant == 'b':
        path(d, 'M14 14 Q4 37 13 62 C23 86 55 94 78 76 Q90 65 95 49 Q79 66 63 65 C40 64 29 43 40 26 Z', 255)
        path(d, 'M10 12 Q11 8 16 9 L45 23 L41 31 L9 19 Z', 255)
        path(h, 'M19 26 Q15 49 30 64', stroke=165, width=2)
        path(h, 'M12 46 L30 44 L33 52 L15 55 Z', 190)
        path(h, 'M42 75 L48 61 L56 64 L51 81 Z', 190)
    elif variant == 'c' and faction == 'accord':
        path(d, 'M34 83 L28 94 L49 87 L59 91 L57 78 C69 72 74 55 69 39 Q65 30 68 24 L82 24 L92 32 L88 18 L75 14 C68 3 48 7 44 19 Q38 31 26 37 L14 42 L26 45 L15 51 L28 53 Q18 66 20 80 L28 73 Z', 255)
        path(h, 'M47 34 C33 41 29 57 30 69 C44 66 56 50 58 33 Q52 29 47 34 Z', 180)
        path(h, 'M47 39 Q36 49 34 60', stroke=85, width=1.6)
        ellipse(d, (67, 15, 72, 19), 0)
        path(d, 'M43 78 L42 85 L63 85 L63 89 L35 89 L35 84 Z', 255)
    else:
        # One broad, open coil; the head and hooked muzzle face outwards.
        path(d, 'M65 48 C81 53 92 66 85 79 C76 96 41 95 24 84 C7 72 11 48 29 41 C42 35 56 41 58 54 C60 65 51 73 39 70 Q47 65 46 57 Q43 50 34 53 C23 58 27 72 40 76 C59 83 78 73 68 63 C58 53 52 48 53 38 Q53 30 60 24 L54 14 L68 17 Q75 9 86 14 L96 25 L89 34 L75 34 Q66 34 65 41 Z', 255)
        ellipse(d, (80, 19, 85, 23), 0)
        path(d, 'M88 29 L95 27 L94 31 Z', 0)
        path(h, 'M61 38 Q61 50 72 58 C87 73 72 85 49 85', stroke=170, width=2)
        path(h, 'M20 66 Q20 49 35 47', stroke=160, width=1.8)
    # Interior thread never paints outside the main motif.
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
        ('accord', 'a'): (75, 12, 9), ('throng', 'a'): (70, 14, 11),
        ('accord', 'b'): (70, 15, 11), ('throng', 'b'): (75, 12, 10),
        ('accord', 'c'): (75, 12, 9), ('throng', 'c'): (74, 12, 10),
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
