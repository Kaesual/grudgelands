#!/usr/bin/env python3
"""Layer a website view onto the saved opening; never rebuild or write game assets."""
import argparse
import base64
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import random
import re
import struct
import subprocess
import tempfile
import zlib

from PIL import Image, ImageChops, PngImagePlugin

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = HERE / 'wide'
SHIPPED = ROOT / 'tools/web_data/media/grug_creation_intro_wide.png'
GAME = ROOT / 'mods/PLAYER/grug_classes/textures/grug_creation_intro.png'
CELL = struct.Struct('<hhhHB')
PAYLOAD = re.compile(r'(<script id="payload" type="application/json">)(.*?)(</script>)', re.S)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def digest(value):
    return sha(json.dumps(value, sort_keys=True, separators=(',', ':')).encode())


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def inputs():
    # The committed page is intro.py's packed geometry, media and renderer.
    # Reuse it so the website layer never reruns or overwrites the game build.
    paths = ['scene.json', 'scene-build.json', 'scenes.html', 'wide.json',
             'wide-build.py', 'wide-capture.mjs']
    return {str((HERE / p).relative_to(ROOT)): sha((HERE / p).read_bytes()) for p in paths}


def build():
    page = (HERE / 'scenes.html').read_text()
    match = PAYLOAD.search(page)
    assert match, 'Base page has no scene payload'
    payload = json.loads(match[2])
    base = payload['scenes']['intro']
    spec = json.loads((HERE / 'scene.json').read_text())
    receipt = json.loads((HERE / 'scene-build.json').read_text())['intro']
    assert base['spec'] == spec, 'Saved page differs from the game recipe; rebuild the base separately'
    assert receipt['render_input'] == base['digest'], 'Base page/build receipt mismatch'
    assert receipt['recipe'] == digest(spec), 'Base recipe/build receipt mismatch'
    assert receipt['cells'] == base['count']
    assert not payload['body'], 'Opening must not contain a reference figure'

    layer = json.loads((HERE / 'wide.json').read_text())
    assert set(layer) == {'camera', 'terrain', 'trees', 'barricades', 'fallen_logs',
                          'rubble', 'foreground_stones'}
    camera = layer['camera']
    assert set(camera) == {'eye', 'target', 'fov'}
    assert all(len(camera[k]) == 3 and all(math.isfinite(v) for v in camera[k])
               for k in ('eye', 'target'))
    assert 1 < camera['fov'] < 179
    cells = list(CELL.iter_unpack(base64.b64decode(base['cells'])))
    assert len(cells) == base['count']
    occupied = {c[:3] for c in cells}
    kinds = {t['name']: i for i, t in enumerate(payload['types'])}
    xmin, xmax = layer['terrain']['x']
    zmin, zmax = layer['terrain']['z']
    assert xmin > max(c[0] for c in cells), 'Wide ground must extend the right edge only'
    assert all(isinstance(v, int) and -32768 <= v <= 32767 for v in (xmin, xmax, zmin, zmax))
    assert xmin <= xmax and zmin <= zmax
    added = {}

    def put(x, y, z, kind, p2=0):
        assert (x, y, z) not in occupied, 'Wide layer overwrites a base cell'
        added[x, y, z] = (kind, p2)

    def background_height(x, z):
        ramp = min(1, max(0, (z - 60) / 15))
        return max(0, math.floor(ramp * (2.2 + 1.2 * math.sin(x * .085 + z * .045)
                                       + .9 * math.cos(z * .11 - x * .025))))

    for x in range(xmin, xmax + 1):
        for z in range(zmin, zmax + 1):
            # Same terrain formula, seed and node palette as ../intro.py.
            height = background_height(x, z)
            t = ((x // 4 * 73856093 ^ z // 4 * 19349663 ^ spec['seed']) % 100) / 100
            surface = 'default:dirt' if t < .83 else (
                'default:gravel' if t < .96 else 'grug_decor:darkage_basalt_rubble')
            for y in range(-2, height + 1):
                node = 'default:stone' if y == -2 else 'default:dirt'
                if y == height:
                    node = 'default:dirt_with_grass' if z > 60 else surface
                put(x, y, z, kinds[node])

    # Reuse complete, isolated trees already packed by the shipped generator.
    # No Lua run, fresh tree shape, extra texture or base-scene rebuild is needed.
    tree_kinds = {i for name, i in kinds.items() if 'pine_' in name or 'aspen_' in name}
    for tree in layer['trees']:
        sx, sz = tree['source']
        tx, tz = tree['at']
        source = [c for c in cells if c[3] in tree_kinds and
                  abs(c[0] - sx) <= 4 and abs(c[2] - sz) <= 4]
        assert source and all(abs(c[0] - sx) < 4 and abs(c[2] - sz) < 4 for c in source)
        dy = background_height(tx, tz) - background_height(sx, sz)
        for x, y, z, kind, p2 in source:
            at = (x + tx - sx, y + dy, z + tz - sz)
            assert at not in added, 'Wide tree collision'
            put(*at, kind, p2)

    log = kinds['default:tree']
    for fence in layer['barricades']:
        cx, cz = fence['at']
        half = fence['length'] // 2
        for x in range(cx - half, cx + half + 1):
            put(x, 2, cz, log, 12)
        for x in range(cx - half, cx + half + 1, 4):
            for y in range(4):
                put(x, y + 1, cz - 2 + y, log)
                put(x, y + 1, cz + 2 - y, log)
    for cx, z, length in layer['fallen_logs']:
        for x in range(cx, cx + length):
            put(x, 1, z, log, 12)
    rubble = layer['rubble']
    rng = random.Random(spec['seed'])
    for _ in range(rubble['count']):
        x, z = rng.randint(*rubble['x']), rng.randint(*rubble['z'])
        if x < (z + 44) * .8 + 2:
            continue  # Keep the scattered stones beyond the game camera's right edge.
        if (x, 1, z) not in occupied and (x, 1, z) not in added:
            put(x, 1, z, kinds[rng.choice(['default:stone', 'grug_decor:darkage_basalt_rubble'])])
    for x, z, node in layer['foreground_stones']:
        put(x, 1, z, kinds[node])

    wide = copy.deepcopy(base)
    wide['spec']['camera'] = camera
    wide['count'] += len(added)
    rows = [(*at, *node) for at, node in added.items()]
    wide['cells'] = base64.b64encode(b''.join(CELL.pack(*c) for c in sorted(cells + rows))).decode()
    sources = inputs()
    render_input = digest(sources)
    wide['digest'] = render_input

    def scene_page(scene):
        data = dict(payload, scenes={'intro': scene})
        return page[:match.start(2)] + json.dumps(data, separators=(',', ':')).replace('</', '<\\/') + page[match.end(2):]

    # The layer comparison retains every added cell, but uses the GAME camera.
    game_layer = copy.deepcopy(wide)
    game_layer['spec']['camera'] = spec['camera']
    return {
        'pages': {'wide': scene_page(wide), 'game-base': page, 'game-layer': scene_page(game_layer)},
        'input': render_input, 'sources': sources, 'camera': camera,
        'game_camera': spec['camera'], 'cells': wide['count'], 'added_cells': len(added),
    }


def mark_srgb(path):
    # Chromium's canvas already outputs sRGB pixels. Declare it explicitly,
    # without resampling, colour conversion or recompressing the image data.
    data = path.read_bytes()
    with Image.open(path) as image:
        assert not image.info.get('icc_profile'), 'Unexpected profile in browser PNG'
        if image.info.get('srgb') == 0:
            return
        assert 'srgb' not in image.info
    chunk = b'sRGB\x00'  # Rendering intent: perceptual.
    path.write_bytes(data[:33] + struct.pack('>I', 1) + chunk +
                    struct.pack('>I', zlib.crc32(chunk)) + data[33:])


def save_rgb(source, target):
    # Drop Chromium's uniformly opaque alpha, preserving every RGB sample.
    with Image.open(source) as image:
        assert image.mode == 'RGBA' and image.getchannel('A').getextrema() == (255, 255)
        info = PngImagePlugin.PngInfo()
        info.add(b'sRGB', b'\x00')
        image.convert('RGB').save(target, pnginfo=info)


def difference():
    with Image.open(OUT / 'game-base.png') as a, Image.open(OUT / 'game-layer.png') as b:
        assert a.size == b.size == (1920, 1080)
        diff = ImageChops.difference(a.convert('RGBA'), b.convert('RGBA'))
    maxima = [high for low, high in diff.getextrema()]
    mask = diff.getchannel('R')
    for channel in ('G', 'B', 'A'):
        mask = ImageChops.lighter(mask, diff.getchannel(channel))
    changed = mask.width * mask.height - mask.histogram()[0]
    bounds = mask.getbbox()
    return diff.convert('RGB'), {
        'differing_pixels': changed,
        'largest_channel_difference': max(maxima),
        'channel_maxima_rgba': maxima,
        'bounds_xyxy_exclusive': list(bounds) if bounds else None,
    }


def png_check(path, size, output=None, mode=None):
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', f'{path}: not PNG'
    if output:
        assert sha(data) == output, f'{path}: output hash differs from receipt'
    with Image.open(path) as image:
        image.verify()
    with Image.open(path) as image:
        assert image.size == size, f'{path}: wrong dimensions'
        assert image.info.get('srgb') == 0, f'{path}: missing sRGB declaration'
        assert image.mode in ('RGB', 'RGBA')
        if mode:
            assert image.mode == mode, f'{path}: expected {mode}, got {image.mode}'
        if image.mode == 'RGBA':
            assert image.getchannel('A').getextrema() == (255, 255), f'{path}: transparent pixels'


def check(data):
    receipt = json.loads((OUT / 'intro.json').read_text())
    assert receipt['input'] == data['input'], 'Wide render inputs changed; rebuild'
    assert receipt['sources'] == data['sources']
    assert receipt['camera'] == data['camera']
    assert receipt['width'] == 2560 and receipt['height'] == 1440
    assert receipt['cells'] == data['cells'] and receipt['added_cells'] == data['added_cells']
    assert receipt['color_space'] == 'sRGB'
    assert receipt['mode'] == 'RGB'
    png_check(SHIPPED, (2560, 1440), receipt['output'], mode='RGB')
    assert SHIPPED.stat().st_size == receipt['bytes']
    proof = json.loads((OUT / 'proof.json').read_text())
    assert proof['input'] == data['input'] and proof['camera'] == data['game_camera']
    assert proof['game_png_sha256'] == sha(GAME.read_bytes()), 'Installed game image changed'
    assert proof['width'] == 1920 and proof['height'] == 1080
    png_check(OUT / 'diff.png', (1920, 1080), proof['outputs']['diff.png'], mode='RGB')
    # The large comparison captures are rebuild output. The committed diff and
    # its pixel counts remain verifiable in a fresh checkout without them.
    with Image.open(OUT / 'diff.png') as diff:
        mask = ImageChops.lighter(ImageChops.lighter(diff.getchannel('R'), diff.getchannel('G')),
                                  diff.getchannel('B'))
        bounds = mask.getbbox()
        maxima = [high for low, high in diff.getextrema()] + [0]
        measured = {'differing_pixels': mask.width * mask.height - mask.histogram()[0],
                    'largest_channel_difference': max(maxima), 'channel_maxima_rgba': maxima,
                    'bounds_xyxy_exclusive': list(bounds) if bounds else None}
    assert proof['difference'] == measured, 'Pixel counts do not match committed diff'
    print(f"Wide receipt OK: 2560 x 1440 RGB sRGB, {receipt['bytes']} bytes, website hash matches")
    print(f"Game-camera proof: {measured['differing_pixels']} differing pixels, "
          f"maximum channel delta {measured['largest_channel_difference']}, "
          f"bounds {measured['bounds_xyxy_exclusive']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Verify receipts and website PNG; exit 1 if stale')
    parser.add_argument('--chrome', default=os.environ.get('CHROME_BIN', '/usr/bin/chromium-browser'))
    args = parser.parse_args()
    data = build()
    if args.check:
        check(data)
        return
    OUT.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='grug-intro-wide-') as folder:
        temp = Path(folder)
        for name, page in data['pages'].items():
            (temp / (name + '.html')).write_text(page)
        subprocess.run(['node', str(HERE / 'wide-capture.mjs'), '--render', folder,
                        '--chrome', args.chrome], check=True)
        captures = json.loads((temp / 'captures.json').read_text())
        for source, dest in [('wide', 'intro'), ('game-base', 'game-base'), ('game-layer', 'game-layer')]:
            target = OUT / (dest + '.png')
            if source == 'wide':
                save_rgb(temp / (source + '.png'), target)
            else:
                target.write_bytes((temp / (source + '.png')).read_bytes())
                mark_srgb(target)
    png = (OUT / 'intro.png').read_bytes()
    write_json(OUT / 'intro.json', {
        'input': data['input'], 'sources': data['sources'], 'output': sha(png),
        'width': 2560, 'height': 1440, 'bytes': len(png), 'color_space': 'sRGB', 'mode': 'RGB',
        'camera': data['camera'], 'cells': data['cells'], 'added_cells': data['added_cells'],
        'renderer': 'tools/building_templates/viewer/renderer.js (embedded in intro/scenes.html)',
        'browser': captures['browser'], 'capture': captures['wide'],
    })
    diff, measured = difference()
    diff.save(OUT / 'diff.png')
    mark_srgb(OUT / 'diff.png')
    write_json(OUT / 'proof.json', {
        'input': data['input'], 'width': 1920, 'height': 1080,
        'camera': data['game_camera'], 'browser': captures['browser'],
        'game_png_sha256': sha(GAME.read_bytes()),
        'difference': measured,
        'outputs': {name: sha((OUT / name).read_bytes()) for name in ('game-base.png', 'game-layer.png', 'diff.png')},
        'captures': {name: captures[name] for name in ('game-base', 'game-layer')},
        'comparison': 'Fresh base versus base plus the whole wide layer; game camera and size in both. Not the old installed PNG.',
    })
    SHIPPED.parent.mkdir(parents=True, exist_ok=True)
    SHIPPED.write_bytes(png)
    check(data)


if __name__ == '__main__':
    try:
        main()
    except (AssertionError, KeyError, ValueError, OSError) as error:
        raise SystemExit(f'Wide opening check/build failed: {error}')
