#!/usr/bin/env python3
"""Reproducible small RGBA nine-slice UI assets; no external artwork."""
from pathlib import Path
from PIL import Image, ImageDraw
import argparse
import io

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'mods/CORE/grug_core/textures'
COLORS = {
    'window': ((18, 24, 31, 231), (91, 96, 102, 210)),
    'panel': ((10, 16, 17, 94), (209, 192, 154, 43)),
    'button': ((238, 234, 225, 14), None),
    'hover': ((238, 234, 225, 27), None),
    'focus': ((212, 183, 125, 38), None),
    'pressed': ((187, 160, 98, 48), None),
    'selected': ((187, 160, 98, 30), None),
    'danger': ((200, 137, 122, 18), None),
    'nav_hover': ((238, 234, 225, 14), None),
    'nav_selected': ((187, 160, 98, 24), None),
}

def symbol(name):
    image = Image.new('RGBA', (96, 96))
    d = ImageDraw.Draw(image)
    ink = (238, 234, 225, 255)
    def line(points): d.line(points, fill=ink, width=5, joint='curve')
    if name == 'emblem': line([(48, 9), (80, 48), (48, 87), (16, 48), (48, 9)])
    elif name == 'inventory':
        d.rounded_rectangle((21, 32, 75, 82), radius=5, outline=ink, width=5)
        d.arc((32, 12, 64, 53), 180, 360, fill=ink, width=5)
        line([(22, 49), (74, 49)])
    elif name == 'character':
        d.ellipse((34, 12, 62, 40), outline=ink, width=5)
        d.arc((19, 43, 77, 105), 180, 360, fill=ink, width=5)
    elif name == 'talents':
        line([(48, 9), (59, 35), (87, 39), (66, 58), (72, 86), (48, 72),
              (24, 86), (30, 58), (9, 39), (37, 35), (48, 9)])
    elif name == 'crafting':
        line([(24, 75), (66, 31), (80, 42), (86, 33), (60, 9), (51, 18), (62, 28)])
    elif name == 'party':
        d.ellipse((30, 12, 54, 36), outline=ink, width=5)
        d.arc((14, 40, 70, 104), 180, 360, fill=ink, width=5)
        d.arc((49, 16, 75, 43), 260, 100, fill=ink, width=5)
        d.arc((53, 45, 89, 99), 270, 360, fill=ink, width=5)
    elif name == 'map':
        line([(12, 20), (36, 10), (60, 20), (84, 10), (84, 76), (60, 86),
              (36, 76), (12, 86), (12, 20)])
        line([(36, 10), (36, 76)]); line([(60, 20), (60, 86)])
    elif name == 'help':
        d.ellipse((12, 12, 84, 84), outline=ink, width=5)
        d.arc((35, 26, 61, 52), 180, 470, fill=ink, width=5)
        line([(48, 49), (48, 59)]); d.ellipse((45, 68, 51, 74), fill=ink)
    elif name == 'mail':
        d.rectangle((12, 23, 84, 75), outline=ink, width=5)
        line([(12, 23), (48, 52), (84, 23)])
    else:
        d.rectangle((17, 17, 79, 79), outline=ink, width=5)
        line([(17, 48), (79, 48)]); line([(48, 17), (48, 79)])
    return image.resize((32, 32), Image.Resampling.LANCZOS)

def build(check=False):
    OUT.mkdir(exist_ok=True)
    images = {}
    for name, (fill, border) in COLORS.items():
        image = Image.new('RGBA', (96, 96))
        draw = ImageDraw.Draw(image)
        draw.rounded_rectangle((0, 0, 95, 95), radius=18 if border else (0 if name.startswith('nav_') else 9), fill=fill, outline=border, width=3)
        image = image.resize((32, 32), Image.Resampling.LANCZOS)
        images[name] = image
    images['clear'] = Image.new('RGBA', (32, 32))
    for name in ['emblem', 'inventory', 'character', 'talents', 'crafting', 'party', 'map', 'help', 'mail', 'creative']:
        images['icon_' + name] = symbol(name)
    for name, image in images.items():
        out = io.BytesIO()
        image.save(out, format='PNG', optimize=False)
        path = OUT / ('grug_ui_' + name + '.png')
        if check:
            assert path.read_bytes() == out.getvalue(), str(path)
        else:
            path.write_bytes(out.getvalue())
    print('UI theme assets verified' if check else 'UI theme assets built')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    build(parser.parse_args().check)
