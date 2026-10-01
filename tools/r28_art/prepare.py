#!/usr/bin/env python3
"""Rebuild the complete Round 28 art handoff; requires Pillow 12.3.0.

The generated originals (about 48 MB) are not in git: they are archived
outside the repository (manifest `originals.archive`) and found through
--originals PATH, or in docs/planning/round28/art/originals/ when present.
Manifest `source` paths keep their docs/planning/round28/art/originals/
prefix; the rest of such a path is relative to the originals directory.

Without --check, every icon and sheet is re-exported from the originals and
the manifest rewritten (originals required).

--check with originals reproduces every PNG in memory and checks catalog
coverage, original and export hashes, exact filenames, palettes, alpha,
margins and sheets. --check without originals skips the re-export: it checks
the committed icons (hashes, palettes, alpha, margins), rebuilds the sheets
from them and checks the recorded originals-sheet hash. This deterministic
export needs no network.
"""
import argparse
import hashlib
import io
import json
import re
import textwrap
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, __version__ as PILLOW_VERSION

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "docs/planning/round28/art"
MANIFEST = ART / "manifest.json"
ORIGINALS_PREFIX = "docs/planning/round28/art/originals/"
ORIGINALS = None  # directory holding the originals, set in main(); None = absent


def sha(data):
    return hashlib.sha256(data).hexdigest()


def original(source):
    """The file of a manifest `source` path inside the originals directory."""
    assert source.startswith(ORIGINALS_PREFIX), source
    return ORIGINALS / source[len(ORIGINALS_PREFIX):]


def committed(path):
    """A committed PNG: the decoded image and its exact bytes."""
    data = (ROOT / path).read_bytes()
    return Image.open(io.BytesIO(data)).convert("RGBA"), data


def png(image):
    stream = io.BytesIO()
    image.save(stream, format="PNG", optimize=True)
    return stream.getvalue()


def export(asset, size):
    original_image = Image.open(original(asset["source"])).convert("RGBA")
    mask = original_image.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    box = mask.getbbox()
    if not box or mask.getextrema() != (0, 255):
        raise ValueError(f"Missing transparent subject: {asset['id']}")
    cropped = original_image.crop(box)
    extent = size * 7 // 8
    scale = extent / max(cropped.size)
    shape = tuple(max(1, round(d * scale)) for d in cropped.size)
    # Premultiplied RGB avoids dark fringes from invisible source RGB.
    small = cropped.convert("RGBa").resize(shape, Image.Resampling.BOX).convert("RGBA")
    colors = [tuple(bytes.fromhex(c)) for c in asset["palette"]]
    pixels = small.load()
    for y in range(small.height):
        for x in range(small.width):
            r, g, b, a = pixels[x, y]
            if a < 128:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                nearest = min(colors, key=lambda c: (c[0]-r)**2 + (c[1]-g)**2 + (c[2]-b)**2)
                pixels[x, y] = nearest + (255,)
    result = Image.new("RGBA", (size, size))
    result.paste(small, ((size - small.width)//2, (size - small.height)//2))
    return result


def tile(image, scale, light=False):
    side = image.width * scale
    background = Image.new("RGBA", (side, side), "#cec9bc" if light else "#303039")
    background.alpha_composite(image.resize((side, side), Image.Resampling.NEAREST))
    return background.convert("RGB")


def sheet(manifest, icons):
    """Each row places one 16px probe next to one existing 16px item at 8x."""
    out = Image.new("RGB", (1040, 1190), "#171c23")
    draw = ImageDraw.Draw(out)
    font = ImageFont.load_default(size=14)
    small = ImageFont.load_default(size=12)
    title = ImageFont.load_default(size=25)
    draw.text((24, 18), "GRUDGELANDS / ROUND 28 / LOOT ART PROBE", font=title, fill="#f1e8d3")
    draw.text((24, 54), "Native pixels, nearest-neighbour enlargement | Six generated originals | Style approval pending", font=font, fill="#b9c5cc")
    for x, label in [(24, "NEW 16 x 16 / 8x"), (190, "EXISTING 16 x 16 / 8x"),
                     (386, "NEW 32 x 32 / 4x"), (552, "NEW 16 / LIGHT"), (718, "ACTUAL SIZE + NOTES")]:
        draw.text((x, 89), label, font=small, fill="#e0cda7")
    for index, (asset, ref) in enumerate(zip(manifest["assets"], manifest["references"])):
        y = 122 + index * 174
        icon = icons[asset["id"]][16]
        variant = icons[asset["id"]][32]
        existing = Image.open(ROOT / ref["path"]).convert("RGBA")
        assert existing.size == (16, 16)
        for x, im, scale, light in [(24, icon, 8, False), (190, existing, 8, False),
                                    (386, variant, 4, False), (552, icon, 8, True)]:
            out.paste(tile(im, scale, light), (x, y))
        draw.text((24, y+135), asset["name"] + f" (T{asset['tier']})", font=small, fill="#edf0f3")
        draw.text((190, y+135), ref["name"], font=small, fill="#b9c5cc")
        draw.text((386, y+135), "Independent 32px export", font=small, fill="#b9c5cc")
        out.paste(tile(icon, 1), (720, y+8))
        out.paste(tile(variant, 1), (755, y))
        draw.text((720, y+48), asset["id"].split(":")[1], font=font, fill="#edf0f3")
        draw.text((720, y+73), f"{len(set(icon.get_flattened_data()))-1} opaque colors / hard alpha", font=small, fill="#b9c5cc")
        note = asset.get("visual_note", "")
        for line, text in enumerate(note.split("\n")):
            draw.text((720, y+96+line*17), text, font=small, fill="#e0cda7")
    draw.text((24, 1170), "Comparison media retain original licenses; credits and exact source paths: manifest.json", font=small, fill="#b9c5cc")
    return out


def original_sheet(manifest):
    out = Image.new("RGB", (960, 390), "#303039")
    draw = ImageDraw.Draw(out)
    font = ImageFont.load_default(size=14)
    for index, asset in enumerate(manifest["assets"]):
        x, y = (index % 3)*320, (index // 3)*195
        im = Image.open(original(asset["source"])).convert("RGBA")
        im.thumbnail((160, 160), Image.Resampling.LANCZOS)
        out.paste(im, (x+(320-im.width)//2, y), im)
        draw.text((x+25, y+167), asset["name"], font=font, fill="#edf0f3")
    return out


def wrapped(draw, position, text, width=27, color='#d8dddf', size=13):
    x, y = position
    font = ImageFont.load_default(size=size)
    for line in textwrap.wrap(text, width=width):
        draw.text((x, y), line, fill=color, font=font)
        y += size + 3


def tier_sheet(manifest, icons, tier):
    assets = [a for a in manifest['assets'] if a['tier'] == tier]
    rows = (len(assets) + 2) // 3
    out = Image.new('RGB', (1224, 100 + rows * 242), '#171c23')
    draw = ImageDraw.Draw(out)
    draw.text((20, 16), f'GRUDGELANDS / T{tier} / {len(assets)} NEW ICONS',
              font=ImageFont.load_default(size=24), fill='#f1e8d3')
    draw.text((20, 51), 'Native 16px at 8x | NEW left, EXISTING right | Original pixels; no smoothing',
              font=ImageFont.load_default(size=15), fill='#bac6cc')
    refs = {r['family']: r for r in manifest['references']}
    for n, asset in enumerate(assets):
        x, y = 20 + (n % 3) * 404, 90 + (n // 3) * 242
        ref = refs[asset['family']]
        icon = icons[asset['id']][16]
        existing = Image.open(ROOT / ref['path']).convert('RGBA')
        assert existing.size == (16, 16), ref['path']
        out.paste(tile(icon, 8), (x, y))
        out.paste(tile(existing, 8), (x + 176, y))
        out.paste(tile(icon, 1, True), (x + 139, y + 8))
        out.paste(tile(icon, 1), (x + 139, y + 34))
        wrapped(draw, (x, y + 135), asset['name'], width=22)
        wrapped(draw, (x, y + 176), asset['id'].split(':')[1], width=25, size=11, color='#a9b5bb')
        wrapped(draw, (x + 176, y + 135), ref['name'], width=24)
        wrapped(draw, (x + 176, y + 172), ref['relation'], width=24, size=12, color='#cbbb91')
        draw.line((x, y+229, x+372, y+229), fill='#39424b')
    return out


def motif(asset):
    key = asset['id'].split(':')[1]
    family = asset['family']
    if family == 'zombie':
        return 'zombie / flesh' if 'flesh' in key else 'zombie / teeth'
    if family == 'outlaw':
        return 'outlaw / straps' if 'strap' in key else 'outlaw / talismans'
    if family == 'rat':
        return 'rat / fur' if 'fur' in key else 'rat / tails'
    if family == 'crab':
        return 'crab / eyes' if 'eye' in key else 'crab / shell and leg'
    return family


def family_rows(manifest, catalog):
    rows = {}
    for asset in manifest['assets']:
        rows.setdefault(motif(asset), {})[asset['tier']] = (asset['name'], asset['id'], False)
    # Existing members belong in their catalogue tiers; generic cross-band
    # recipe materials are explicitly marked existing, not newly tier-locked.
    references = {r['path'].split('/')[-1]: r for r in manifest['references']}
    for item in catalog:
        family = motif(item)
        if family not in rows or item.get('icon'):
            continue
        path = 'grug_mobs_item_' + item['id'].split(':')[1] + '.png'
        if path in references and item['tier'] not in rows[family]:
            rows[family][item['tier']] = (item['name'], references[path]['path'], True)
    # Existing boar tusk is in the same motif; all rows use explicit empty
    # cells for missing tiers rather than inventing catalogue items.
    return sorted(rows.items())


def family_sheet(rows, icons, title='ALL TIER FAMILIES'):
    out = Image.new('RGB', (1510, 105 + len(rows) * 210), '#171c23')
    draw = ImageDraw.Draw(out)
    draw.text((20, 14), 'GRUDGELANDS / ' + title,
              font=ImageFont.load_default(size=24), fill='#f1e8d3')
    draw.text((20, 46), '16px icons at 8x | E = existing material/signature (generic metadata does not restrict drop tier) | - = absent',
              font=ImageFont.load_default(size=13), fill='#bac6cc')
    for tier in range(1, 7):
        draw.text((220 + (tier-1)*210, 77), f'T{tier}', font=ImageFont.load_default(size=19), fill='#e0cda7')
    for n, (label, tiers) in enumerate(rows):
        y = 107 + n * 210
        wrapped(draw, (20, y+45), label, width=19, size=18, color='#e0cda7')
        for tier in range(1, 7):
            x = 220 + (tier-1)*210
            if tier not in tiers:
                draw.text((x+58, y+51), '-', font=ImageFont.load_default(size=22), fill='#56636c')
                continue
            name, source, existing = tiers[tier]
            im = Image.open(ROOT / source).convert('RGBA') if existing else icons[source][16]
            out.paste(tile(im, 8), (x, y))
            out.paste(tile(im, 1, True), (x + 137, y + 7))
            wrapped(draw, (x, y+135), ('E: ' if existing else '') + name, width=23,
                    color='#b9c5cc' if existing else '#f1e8d3')
        draw.line((20, y+197, 1489, y+197), fill='#39424b')
    return out


def new_catalog_items(catalog):
    """Audit actual explicit and material() mob registrations, not kind alone."""
    source = (ROOT / 'mods/ENTITIES/grug_mobs/items.lua').read_text()
    registered = set(re.findall(r'core\.register_craftitem\("([^"\n]+)"\s*,', source))
    registered.update('grug_mobs:' + key for key in re.findall(r'^material\("([^"\n]+)"', source, re.M))
    # These five non-mob IDs are established materials in the catalog snapshot.
    external = {'mobs:meat_raw', 'mobs:leather', 'default:stick', 'default:apple', 'grug_materials:quartz'}
    reused = registered | external
    new = [a for a in catalog if a['id'] not in reused]
    assert all('icon' in a for a in new), 'New catalog item lacks an icon brief'
    assert all('icon' not in a for a in catalog if a['id'] in reused), 'Existing item unexpectedly requests new icon'
    return new


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--partial', action='store_true', help='Production previews only; incompatible with --check')
    parser.add_argument('--originals', help='Directory of the archived originals (manifest originals.archive)')
    args = parser.parse_args()
    assert not (args.check and args.partial)
    global ORIGINALS
    if args.originals:
        ORIGINALS = Path(args.originals).resolve()
        assert ORIGINALS.is_dir(), f'No originals directory: {ORIGINALS}'
    elif (ART / 'originals').is_dir():
        ORIGINALS = ART / 'originals'
    assert ORIGINALS or args.check, 'Rebuilding needs the originals: --originals PATH (manifest originals.archive)'
    assert PILLOW_VERSION == '12.3.0', f'Pinned Pillow 12.3.0 required, found {PILLOW_VERSION}'
    manifest = json.loads(MANIFEST.read_text())
    previous = json.loads(MANIFEST.read_text())
    catalog_data = json.loads((ROOT / manifest['catalog']).read_text())
    catalog = {a['id']: a for a in catalog_data}
    expected = {a['id'] for a in new_catalog_items(catalog_data)}
    actual = [a['id'] for a in manifest['assets']]
    assert len(actual) == len(set(actual)), 'Duplicate asset ID'
    if not args.partial:
        assert set(actual) == expected, f'Catalog coverage mismatch: {set(actual) ^ expected}'
        assert Counter(str(a['tier']) for a in manifest['assets']) == Counter(manifest['expected_counts'])
        assert len(actual) == 89
    else:
        assert set(actual) <= expected
    icons = {}

    def save(path, data):
        target = ROOT / path
        assert target.resolve().is_relative_to(ART.resolve()), path
        if args.check:
            assert target.read_bytes() == data, f'Rebuild mismatch: {path}'
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        return {'path': path, 'sha256': sha(data), 'bytes': len(data)}

    for asset in manifest['assets']:
        for field in ('name', 'tier', 'family', 'icon', 'description', 'kind'):
            assert asset[field] == catalog[asset['id']][field], (asset['id'], field)
        if ORIGINALS:
            source = original(asset['source'])
            asset['source_sha256'] = sha(source.read_bytes())
            asset['source_size'] = list(Image.open(source).size)
        if not asset.get('probe_reuse'):
            receipt_path = ART / 'generation' / (asset['id'].replace(':', '_') + '.json')
            receipt = json.loads(receipt_path.read_text())
            for field in ('id', 'prompt', 'source', 'generation_source'):
                assert receipt[field] == asset[field], (asset['id'], field)
            asset['generation_receipt_sha256'] = sha(receipt_path.read_bytes())
        for variant in asset.get('discarded_variants', []):
            assert variant['source'].startswith(ORIGINALS_PREFIX + 'variants/'), variant['source']
            if ORIGINALS:
                variant_path = original(variant['source'])
                variant['source_sha256'] = sha(variant_path.read_bytes())
                variant['source_size'] = list(Image.open(variant_path).size)
        assert len(asset['palette']) in range(6, 9)
        assert len(set(asset['palette'])) == len(asset['palette'])
        assert all(re.fullmatch('[0-9a-f]{6}', color) for color in asset['palette'])
        path = 'docs/planning/round28/art/icons/' + asset['id'].replace(':', '_') + '.png'
        assert asset['outputs']['16']['path'] == path
        if ORIGINALS:
            im = export(asset, 16)
            data = png(im)
        else:
            im, data = committed(path)
        assert set(im.getchannel('A').get_flattened_data()) == {0, 255}
        bbox = im.getbbox()
        assert bbox and min(bbox[:2]) >= 1 and max(bbox[2:]) <= 15
        palette = {tuple(bytes.fromhex(c)) for c in asset['palette']}
        opaque = {p[:3] for p in im.get_flattened_data() if p[3]}
        assert opaque <= palette
        assert 3 <= len(opaque) <= 8, asset['id']
        icons[asset['id']] = {16: im}
        result = save(path, data)
        result.update(size=[16, 16], opaque_colors=len(opaque))
        asset['outputs']['16'] = result
        if asset.get('probe_reuse'):
            assert result['sha256'] == asset['probe_reuse']['sha256_16'], 'Probe changed'
    if not args.partial:
        files = {p.name for p in (ART / 'icons').glob('*.png')}
        assert files == {a['id'].replace(':', '_') + '.png' for a in manifest['assets']}
        hashes = [a['outputs']['16']['sha256'] for a in manifest['assets']]
        assert len(set(hashes)) == len(hashes), 'Duplicate rendered icon'
    for ref in manifest['references']:
        assert (ROOT / ref['license_record']).exists()
        ref['sha256'] = sha((ROOT / ref['path']).read_bytes())
    manifest['catalog_sha256'] = sha((ROOT / manifest['catalog']).read_bytes())
    manifest['pillow_version'] = PILLOW_VERSION
    manifest['script_sha256'] = sha(Path(__file__).read_bytes())
    manifest['supporting_scripts'] = {name: sha((ROOT / 'tools/r28_art' / name).read_bytes())
                                      for name in ('assemble.py', 'palettes.json')}
    manifest['contact_sheets'] = [save(f'docs/planning/round28/art/sheet_t{t}.png', png(tier_sheet(manifest, icons, t)))
                                  for t in range(1, 7)]
    rows = family_rows(manifest, catalog_data)
    shown = [source for _, tiers in rows for _, source, existing in tiers.values() if not existing]
    assert Counter(shown) == Counter(actual), 'Family sheet loses or duplicates a new icon'
    manifest['family_sheet'] = save('docs/planning/round28/art/sheet_families.png', png(family_sheet(rows, icons)))
    manifest['family_sheet_parts'] = [save(f'docs/planning/round28/art/sheet_families_{i//10+1}.png',
                                          png(family_sheet(rows[i:i+10], icons, f'TIER FAMILIES / {i//10+1}')))
                                      for i in range(0, len(rows), 10)]
    # Keep the historical six-probe artifacts byte-identical and reproducible,
    # even though Rusted Braces is no longer in the production catalogue.
    probe = json.loads((ART / 'probe_manifest.json').read_text())
    probe_icons = {}
    for asset in probe['assets']:
        if ORIGINALS:
            assert sha(original(asset['source']).read_bytes()) == asset['source_sha256']
        probe_icons[asset['id']] = {}
        for size in (16, 32):
            if ORIGINALS:
                im = export(asset, size)
                data = png(im)
            else:
                im, data = committed(asset['outputs'][str(size)]['path'])
            probe_icons[asset['id']][size] = im
            assert sha(data) == asset['outputs'][str(size)]['sha256']
            save(asset['outputs'][str(size)]['path'], data)
    result = save(probe['contact_sheet']['path'], png(sheet(probe, probe_icons)))
    assert result == probe['contact_sheet'], 'Historical sheet changed'
    if ORIGINALS:
        result = save(probe['originals_sheet']['path'], png(original_sheet(probe)))
    else:
        data = (ROOT / probe['originals_sheet']['path']).read_bytes()
        result = {'path': probe['originals_sheet']['path'], 'sha256': sha(data), 'bytes': len(data)}
    assert result == probe['originals_sheet'], 'Historical sheet changed'
    if not args.partial:
        if ORIGINALS:
            sources = {a['source'] for a in manifest['assets'] + probe['assets']}
            sources.update(v['source'] for a in manifest['assets'] for v in a.get('discarded_variants', []))
            present = {ORIGINALS_PREFIX + p.relative_to(ORIGINALS).as_posix() for p in ORIGINALS.rglob('*.png')}
            assert sources == present, f'Untracked/missing originals: {sources ^ present}'
        receipts = {a['id'].replace(':', '_') + '.json' for a in manifest['assets'] if not a.get('probe_reuse')}
        assert receipts == {p.name for p in (ART / 'generation').glob('*.json')}
    manifest['historical_probe_sha256'] = sha((ART / 'probe_manifest.json').read_bytes())
    if args.check:
        assert manifest == previous, 'Manifest metadata mismatch; rebuild required'
    else:
        MANIFEST.write_text(json.dumps(manifest, indent=2) + '\n')
    checked = ('originals, native exports' if ORIGINALS
               else 'committed icons (originals absent, re-export skipped)')
    print(f"{'PREVIEW' if args.partial else 'PASS'}: {len(actual)} catalog IDs; {checked}, palettes, alpha, margins, hashes, tier/family sheets; six historical probes preserved")


if __name__ == '__main__':
    main()
