#!/usr/bin/env python3
"""Compose unretouched Atlas/before/after contact sheets and a local review index."""
import argparse
import html
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

PAGES = {
    'inventory': 'preview-inventory.png',
    'achievements': 'final-character-achievements.png',
    'talents': 'final-talents-bulwark.png',
    'crafting': 'final-crafting-recipes.png',
    'chest': 'preview-chest.png',
    'quest': 'preview-quest.png',
    'map': 'preview-map.png',
    'privileged': 'preview-all-tabs.png',
}
CASES = [('small', '1035 x 696 / GUI 1'), ('large', '1920 x 1080 / GUI 1'),
         ('scale15', '1035 x 696 / GUI 1.5')]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path, help='contains atlas/, before-*/ and after-*/')
    args = parser.parse_args()
    root = args.root
    font = ImageFont.truetype('DejaVuSans.ttf', 20)
    small = ImageFont.truetype('DejaVuSans.ttf', 16)
    width, height = 720, 510
    sheets = root / 'contact-sheets'
    sheets.mkdir(exist_ok=True)
    links = []
    for page, preview in PAGES.items():
        sheet = Image.new('RGB', (width * 3, 70 + height * 6), '#11181c')
        draw = ImageDraw.Draw(sheet)
        draw.text((15, 10), f'{page.upper()} — Atlas 03 / before 0d03734a / fidelity pass', font=font, fill='#eeeae1')
        draw.text((15, 40), 'Full screenshots, fitted without cropping. Content/scene differs from the browser study.', font=small, fill='#a9aea4')
        raw = []
        for row, (case, scene) in enumerate((case, scene) for case in CASES for scene in ('dark', 'bright')):
            case_id, label = case
            y = 70 + row * height
            paths = [root / 'atlas' / preview,
                     root / f'before-{case_id}' / f'{scene}_{page}.png',
                     root / f'after-{case_id}' / f'{scene}_{page}.png']
            for col, path in enumerate(paths):
                im = Image.open(path).convert('RGB')
                im = ImageOps.contain(im, (width - 12, height - 48))
                sheet.paste(im, (col * width + (width - im.width) // 2, y + 40 + (height - 48 - im.height) // 2))
                caption = 'Atlas 03 (approved study)' if col == 0 else f'{"Before" if col == 1 else "After"}: {label}, {scene}'
                draw.text((col * width + 10, y + 10), caption, font=small, fill='#d4b375')
            raw.append(f'<li>{label}, {scene}: ' + ' / '.join(
                f'<a href="{html.escape(str(p.relative_to(root)))}">{title}</a>'
                for p, title in zip(paths, ['Atlas', 'Before', 'After'])) + '</li>')
        sheet.save(sheets / f'{page}.png')
        links.append(f'<section><h2>{page.title()}</h2><a href="contact-sheets/{page}.png"><img src="contact-sheets/{page}.png" loading="lazy"></a><ul>{"".join(raw)}</ul></section>')
    (root / 'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>Grudgelands UI fidelity review</title>
<style>body{background:#11181c;color:#eeeae1;font:16px system-ui;margin:2rem auto;max-width:1600px;padding:1rem}a{color:#d4b375}img{width:100%}section{margin:3rem 0}li{margin:.5rem 0}</style>
<h1>UI fidelity review — 25 October 2026</h1>
<p>Atlas 03, before (0d03734a), and the fidelity pass. Click a sheet to zoom, or open a full-resolution original below it.</p>
<p>Real desktop Luanti 5.17 client, isolated test worlds; controlled stone/night and snow/day scenes. GUI 1 at both resolutions and GUI 1.5 at 1035×696. These are desktop captures, not a browser-client test. Native HUD/chat remain visible behind the translucent forms.</p>
<p>Atlas uses example data. The probe uses live level-30 character data, the Crafting overview and a real quest-giver route; content is intentionally not fabricated to match the study. All 13 privileged tabs are included as an extra case. Failed intermediate captures are excluded from these comparisons. User appearance approval and interactive desktop/web acceptance remain pending.</p>
''' + ''.join(links))
    print(f'Wrote {len(PAGES)} contact sheets and {root / "index.html"}')

if __name__ == '__main__':
    main()
