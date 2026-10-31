"""Original Pass 4 heraldry, drawn with Pillow/numpy; no external art inputs."""
import re

import numpy as np
from PIL import Image, ImageDraw

SCALE = 6
IVORY = '#d6c59b'
GOLD = '#aa9164'
VARIANTS = ('1', '2', '3')
PAIRS = {
    '1': ('Painted livery', 'Broad, quiet ivory shapes and open negative space: the clearest reading at row size.'),
    '2': ('Cut ivory', 'Swept antlers and long tusks, with measured gold engraving following the planes of each face.'),
    '3': ('Needlework', 'Fuller faces and upward ears, edged with a fine, regularly spaced gold stitch.'),
}
IDEAS = {
    'accord': {
        '1': ('H1', 'The Broadbrow Hart', 'A broad brow, leaf-shaped ears and four airy antler tips per side, painted in old ivory.'),
        '2': ('H2', 'The Highbough Hart', 'Tall swept antlers, level ears and a tapered face with restrained gold cheek engraving.'),
        '3': ('H3', 'The Leafear Hart', 'Upright leaf ears and a fuller muzzle beneath a branching rack, worked as stitched ivory cloth.'),
    },
    'throng': {
        '1': ('K1', 'The Tuskguard Boar', 'A bristled wedge of a head, long narrow snout and two great rising tusks, painted in old ivory.'),
        '2': ('K2', 'The Flinttusk Boar', 'A long angular face, swept ears and tall curved tusks with gold engraving along the cheek planes.'),
        '3': ('K3', 'The Bristleback Boar', 'A full bristled brow, pointed ears and stout, upturned tusks, edged in tiny gold stitches.'),
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


def shapes(draw, contours, fill):
    for contour in contours:
        path(draw, contour, fill)


def hart(d, h, variant):
    """One authored half: each beam, ear, brow and facial cut has a clear role."""
    # Every rack has four tips per side: terminal, two outward tines, one inward.
    racks = {
        '1': (
            'M42 46 C32 39 24 29 21 18 C19 11 20 5 24 1 C22 10 24 19 28 26 C32 32 38 37 45 42 Z',
            'M23 21 C14 20 9 14 8 7 C12 14 17 18 23 19 Z',
            'M30 33 C18 32 10 28 7 21 C14 28 20 30 29 31 Z',
            'M23 20 C30 16 33 10 33 4 C35 13 31 20 25 22 Z',
        ),
        '2': (
            'M43 45 C32 39 25 30 25 20 C24 11 28 4 33 1 C28 9 27 17 29 25 C31 32 37 37 46 42 Z',
            'M26 20 C17 19 12 12 12 5 C16 13 21 17 27 18 Z',
            'M31 33 C18 33 10 26 8 18 C14 26 21 30 30 31 Z',
            'M28 23 C34 19 39 11 38 5 C41 14 37 23 30 25 Z',
        ),
        '3': (
            'M42 44 C32 37 25 29 22 20 C19 12 22 5 27 1 C23 10 24 17 27 23 C31 30 37 35 45 40 Z',
            'M23 22 C15 21 9 14 9 7 C14 15 19 19 24 20 Z',
            'M31 34 C21 34 12 30 8 24 C16 30 22 32 29 32 Z',
            'M25 20 C31 16 34 10 34 3 C37 12 32 21 27 22 Z',
        ),
    }
    shapes(d, racks[variant], 255)
    # The heads differ in contour, not just texture: broad / tapered / full.
    faces = {
        '1': ('M50 43 Q41 41 36 47 L37 56 Q36 63 40 69 L43 78 L43 84 Q44 91 50 93 Z',
              'M39 48 C30 41 19 40 9 41 C14 52 25 59 37 57 L42 53 Z',
              'M17 45 Q27 45 35 51 L34 54 Q24 53 17 45 Z'),
        '2': ('M50 43 Q42 40 37 46 L38 58 L40 68 L44 79 L44 85 Q45 92 50 93 Z',
              'M40 48 C31 42 18 42 9 45 C16 55 28 59 39 55 L43 52 Z',
              'M17 47 Q27 46 35 51 L34 54 Q25 53 17 47 Z'),
        '3': ('M50 43 Q41 40 35 47 L37 59 Q36 66 40 72 L42 79 L42 85 Q44 93 50 93 Z',
              'M39 48 C29 39 20 36 11 37 C15 49 25 57 38 56 L43 52 Z',
              'M18 42 Q27 43 35 50 L34 53 Q24 51 18 42 Z'),
    }
    face, ear, ear_cut = faces[variant]
    shapes(d, (ear, face), 255)
    shapes(d, (ear_cut, 'M39 59 Q43 58 46 61 Q43 64 40 62 Z',
               'M45 84 Q47 82 50 83 L50 88 Q47 88 45 84 Z'), 0)
    # Minimal paint has no dangling face lines; the whole muzzle stays light.
    if variant == '2':
        path(h, 'M43 49 Q46 53 47 57', stroke=225, width=1.35)
        path(h, 'M40 66 Q42 72 45 77', stroke=225, width=1.35)
        path(h, 'M46 90 L50 91', stroke=210, width=1.35)
    elif variant == '3':
        path(h, 'M40 66 Q42 72 45 76', stroke=180, width=1.35)


def boar(d, h, variant):
    """Crest + pointed ear + wedge-shaped cheek + long snout + external tusk."""
    # The top bristles grow out of the skull; descending cheek tufts frame it.
    outlines = {
        '1': (
            'M50 7 L45 17 L41 13 L38 23 L31 21 L31 30 L27 38 L25 46 L29 46 L27 57 L32 55 L32 65 L37 62 L39 74 L43 82 L43 88 L50 93 Z',
            'M34 33 C27 23 21 19 15 18 Q16 31 26 40 L33 42 Z',
            'M21 25 L29 32 L29 36 Q24 32 21 25 Z',
            'M38 76 C25 83 11 70 18 45 C18 61 24 69 36 68 Z',
        ),
        '2': (
            'M50 6 L45 18 L42 12 L38 24 L32 22 L32 31 L28 40 L26 48 L30 47 L29 59 L34 56 L35 68 L40 65 L42 78 L44 88 L50 94 Z',
            'M36 34 C28 26 20 24 12 24 Q18 36 28 41 L36 43 Z',
            'M19 28 L30 33 L30 37 Q25 35 19 28 Z',
            'M39 76 C25 85 10 69 19 41 C18 61 25 68 37 69 Z',
        ),
        '3': (
            'M50 8 L45 16 L41 13 L38 23 L32 21 L31 29 L26 37 L24 46 L28 46 L26 57 L32 55 L32 66 L37 64 L39 77 L43 87 L50 93 Z',
            'M35 34 C28 22 22 19 16 17 Q15 31 26 41 L34 43 Z',
            'M21 25 L29 32 L29 37 Q23 32 21 25 Z',
            'M39 76 C25 85 11 72 17 47 C19 61 24 67 37 67 Z',
        ),
    }
    face, ear, ear_cut, tusk = outlines[variant]
    shapes(d, (ear, face), 255)
    shapes(d, (ear_cut,
               'M31 43 Q36 42 41 47 Q36 49 33 47 Z',
               'M41 51 Q38 61 40 71 L43 76 L43 69 Q41 60 43 53 Z'), 0)
    # A narrow tapered nose terminates the long bridge. No round pig-nose disk.
    path(h, 'M50 75 L43 75 L41 81 L44 86 L50 88 Z', 215)
    path(d, 'M44 79 L47 80 L46 84 L43 82 Z', 0)
    # Keep a generous field-coloured moat between cheek and tusk, even at 24 px.
    path(d, tusk, 255, stroke=0, width=4.2)
    path(d, tusk, 255)
    if variant == '2':
        for contour in ('M43 27 L45 37', 'M32 52 L34 58',
                        'M37 62 L39 69', 'M45 89 L50 91'):
            path(h, contour, stroke=225, width=1.35)
    elif variant == '3':
        path(h, 'M42 29 L45 37', stroke=180, width=1.35)
        path(h, 'M34 52 L36 60', stroke=180, width=1.35)


def outline_stitch(mask):
    """Fine gold dashes one unit inside a contour; subordinate to the silhouette."""
    from PIL import ImageFilter
    outer = np.array(mask.filter(ImageFilter.MinFilter(5)))
    inner = np.array(mask.filter(ImageFilter.MinFilter(13)))
    edge = np.maximum(outer.astype(int)-inner.astype(int), 0)
    yy, xx = np.indices(edge.shape)
    # A regular diagonal stitch, mirrored with the rest of the charge below.
    dashes = ((np.minimum(xx, edge.shape[1]-1-xx)+yy)//8) % 3 != 0
    return Image.fromarray((edge*dashes*.85).astype('uint8'))


def motif(faction, variant):
    """Mirrored geometry, distinct contours and a controlled detail hierarchy."""
    mask = Image.new('L', (100*SCALE, 100*SCALE))
    detail = Image.new('L', mask.size)
    (hart if faction == 'accord' else boar)(ImageDraw.Draw(mask), ImageDraw.Draw(detail), variant)
    mask, detail = mirror(mask), mirror(detail)
    if variant == '3':
        detail = Image.fromarray(np.maximum(np.array(detail), np.array(outline_stitch(mask))))
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
    charge = paint(silhouette, ink, 21, thread=(variant == '3'))
    charge.alpha_composite(paint(details, GOLD, 22, thread=(variant == '3')))
    size, x, y = (80, 10, 15) if faction == 'accord' else (82, 9, 10)
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
    charge = paint(silhouette, ink, 41, thread=(variant == '3'))
    charge.alpha_composite(paint(details, GOLD, 42, thread=(variant == '3')))
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
