#!/usr/bin/env python3
"""Import the CC0 sign font into grug_text (Round 68 lane TEXT).

Source: VoxeLibre's sign font (`textures/_*.png`, one 5x12 or 6x12 white
glyph per file) and its character table
(`mods/ITEMS/mcl_signs/characters.tsv`: character, glyph file, width).
The glyphs are copied byte for byte under the mod prefix
(`_a_.png` -> `grug_text_a_.png`), the table is rewritten as
`<character>\t<texture name>` with only the rows whose glyph file exists
(VoxeLibre's table names five files it does not ship: those characters
show the placeholder glyph), plus the placeholder `_rc` itself.

    python3 tools/r68_text/import_font.py [--source DIR] [--check]

`--source` is the VoxeLibre checkout (default
reference_projects/VoxeLibre); `--check` compares the shipped files with a
fresh import and exits 1 on any difference (no file is written).
"""
import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MOD = ROOT / 'mods/CORE/grug_text'
PREFIX = 'grug_text'
PLACEHOLDER = '_rc'


def build(source):
    table = source / 'mods/ITEMS/mcl_signs/characters.tsv'
    glyphs = source / 'textures'
    rows, files, missing = [], {}, []
    for line in table.read_text(encoding='utf-8').split('\n'):
        parts = line.split('\t')
        if len(parts) != 3:
            continue
        char, glyph = parts[0], parts[1]
        if not (glyphs / (glyph + '.png')).is_file():
            missing.append((char, glyph))
            continue
        name = PREFIX + glyph
        files[name + '.png'] = (glyphs / (glyph + '.png')).read_bytes()
        rows.append(char + '\t' + name)
    files[PREFIX + PLACEHOLDER + '.png'] = (glyphs / (PLACEHOLDER + '.png')).read_bytes()
    tsv = ('\n'.join(rows) + '\n').encode('utf-8')
    return tsv, files, missing


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--source', default=str(ROOT / 'reference_projects/VoxeLibre'))
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    source = Path(args.source)
    if not (source / 'mods/ITEMS/mcl_signs/characters.tsv').is_file():
        sys.exit(f'no VoxeLibre checkout at {source} (git submodule update --init '
                 'reference_projects/VoxeLibre, or pass --source)')
    tsv, files, missing = build(source)
    count = tsv.count(b'\n')
    textures = MOD / 'textures'
    shipped = {p.name for p in textures.glob(PREFIX + '_*.png')} if textures.is_dir() else set()
    if args.check:
        bad = []
        if (MOD / 'characters.tsv').read_bytes() != tsv:
            bad.append('characters.tsv')
        for name, data in sorted(files.items()):
            path = textures / name
            if not path.is_file() or path.read_bytes() != data:
                bad.append(name)
        bad += sorted(shipped - set(files))
        if bad:
            print('import_font: differs: ' + ', '.join(bad[:20]) + (' ...' if len(bad) > 20 else ''))
            return 1
        print(f'import_font: OK ({len(files)} glyph files, {count} characters)')
        return 0
    textures.mkdir(parents=True, exist_ok=True)
    for name in sorted(shipped - set(files)):
        (textures / name).unlink()
    for name, data in files.items():
        (textures / name).write_bytes(data)
    (MOD / 'characters.tsv').write_bytes(tsv)
    print(f'import_font: wrote {len(files)} glyph files and {count} characters')
    for char, glyph in missing:
        print(f'  no glyph file {glyph}.png for {char!r}: placeholder')
    return 0


if __name__ == '__main__':
    sys.exit(main())
