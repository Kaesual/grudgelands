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
    'panel': ((10, 16, 23, 165), (68, 81, 93, 150)),
    'button': ((37, 47, 57, 240), (83, 98, 110, 220)),
    'hover': ((54, 66, 76, 250), (191, 161, 103, 255)),
    'pressed': ((24, 33, 42, 250), (166, 135, 80, 255)),
    'selected': ((78, 63, 40, 244), (187, 151, 89, 255)),
    'danger': ((75, 37, 41, 240), (151, 84, 82, 255)),
}

def build(check=False):
    OUT.mkdir(exist_ok=True)
    for name, (fill, border) in COLORS.items():
        image = Image.new('RGBA', (96, 96))
        draw = ImageDraw.Draw(image)
        draw.rounded_rectangle((0, 0, 95, 95), radius=18, fill=fill, outline=border, width=3)
        image = image.resize((32, 32), Image.Resampling.LANCZOS)
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
