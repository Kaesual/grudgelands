#!/usr/bin/env python3
"""Capture, publish and verify the six website PNGs and their figure anchors."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
from PIL import Image, PngImagePlugin
from build import HERE, SOURCE, ROOT, RACES, sha, write_json, project

MEDIA = ROOT / 'tools/web_data/media'
INTRO_MARKER = '<!-- INTRO lane: append the wide opening notice below this line. -->'


def shipped(race):
    return MEDIA/('grug_creation_'+race+'_wide.png')


def verify_sources(build):
    for name, expected in (build['sources'] | build['protected_game_images']).items():
        assert sha(ROOT/name) == expected, 'Changed source; rebuild: '+name


def license_text():
    rows = '\n'.join('| `grug_creation_'+race+'_wide.png` | `'+sha(shipped(race))+'` |'
                     for race in RACES)
    return (HERE/'license.md.in').read_text().replace('__HASH_ROWS__', rows)


def check():
    build = json.loads((HERE/'build.json').read_text())
    verify_sources(build)
    scenes = json.loads((HERE/'scene-build.json').read_text())
    anchors = {}
    for race in RACES:
        # The committed media copy is the picture; renders/<race>.png is
        # ignored build output and is compared only when present.
        image = shipped(race)
        local = HERE/'renders'/(race+'.png')
        receipt = json.loads(local.with_suffix('.json').read_text())
        assert receipt['input'] == scenes[race]['render_input'], (race, 'stale input digest')
        assert receipt['source_digest'] == build['source_digest'], (race, 'stale source digest')
        assert receipt['output'] == sha(image), (race, 'PNG hash mismatch')
        assert not local.exists() or sha(local) == receipt['output'], (race, 'build output differs from receipt')
        assert receipt['width'] == 2560 and receipt['height'] == 1440
        assert receipt['camera']['fov'] == scenes[race]['camera']['fov']
        for key in ('pos', 'target'):
            expected = scenes[race]['camera']['eye' if key == 'pos' else key]
            assert all(abs(a-b) < 1e-9 for a, b in zip(receipt['camera'][key], expected))
        figure = receipt['figure']
        assert set(figure) == {'x', 'y', 'node'}
        assert all(isinstance(v, (int, float)) and 0 < v < 1 and v == round(v, 6) for v in figure.values())
        spec = json.loads((SOURCE/'scenes'/(race+'.json')).read_text())
        feet = spec['portrait']['feet']
        x, y, _ = project(feet, scenes[race]['camera'], 2560/1440)
        _, top, _ = project([feet[0], feet[1]+1, feet[2]], scenes[race]['camera'], 2560/1440)
        assert figure == {'x': round(x, 6), 'y': round(y, 6), 'node': round(y-top, 6)}, (race, 'projection mismatch')
        with Image.open(image) as im:
            assert im.format == 'PNG' and im.size == (2560, 1440) and im.mode == 'RGB'
            assert im.info.get('srgb') == 0, (race, 'missing sRGB declaration')
        anchors[race] = {'figure': figure}
        print(race+': shipped PNG, receipt and sRGB PASS')
    expected = json.dumps(anchors, indent=2, sort_keys=True, ensure_ascii=True)+'\n'
    assert (MEDIA/'wide.json').read_bytes() == expected.encode('ascii'), 'wide.json differs'
    assert (MEDIA/'LICENSE-media.md').read_text().split(INTRO_MARKER)[0] == license_text(), 'Stale race media ledger'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--chrome', default='/usr/bin/chromium-browser')
    args = parser.parse_args()
    if args.check:
        check()
        return
    build = json.loads((HERE/'build.json').read_text())
    verify_sources(build)
    for race in RACES:
        # Seed the ignored render cache from the committed copy, so an
        # unchanged scene is not captured again (render-scenes.mjs checks
        # input digest and output hash against the receipt).
        local = HERE/'renders'/(race+'.png')
        if not local.exists() and shipped(race).exists():
            local.write_bytes(shipped(race).read_bytes())
    subprocess.run(['node', str(SOURCE/'render-scenes.mjs'), '--directory', str(HERE),
                    '--width', '2560', '--height', '1440', '--figure-anchor', '--chrome', args.chrome], check=True)
    MEDIA.mkdir(parents=True, exist_ok=True)
    anchors = {}
    for race in RACES:
        local = HERE/'renders'/(race+'.png')
        receipt = json.loads(local.with_suffix('.json').read_text())
        with Image.open(local) as original:
            # Canvas sRGB values stay unchanged; remove opaque alpha and declare
            # the colour space explicitly. This is lossless PNG encoding only.
            if original.mode == 'RGBA':
                assert original.getchannel('A').getextrema() == (255, 255)
            rgb = original.convert('RGB')
        info = PngImagePlugin.PngInfo()
        info.add(b'sRGB', b'\x00')
        rgb.save(local, pnginfo=info, optimize=True)
        receipt.update(output=sha(local), color_space='sRGB', source_digest=build['source_digest'])
        write_json(local.with_suffix('.json'), receipt)
        shipped(race).write_bytes(local.read_bytes())
        anchors[race] = {'figure': receipt['figure']}
    write_json(MEDIA/'wide.json', anchors)
    ledger = MEDIA/'LICENSE-media.md'
    tail = ledger.read_text().partition(INTRO_MARKER)[2] if ledger.exists() else '\n'
    ledger.write_text(license_text()+INTRO_MARKER+tail)
    check()


if __name__ == '__main__':
    try:
        main()
    except (AssertionError, OSError, ValueError) as error:
        print('FAIL:', error, file=sys.stderr)
        sys.exit(1)
