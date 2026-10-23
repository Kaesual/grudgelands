"""Drop 01: original, deterministic pixel painting. CC0-1.0.

Pillow and the Python standard library only. No source images are opened here.
All geometry is integer texels. All alpha is either 0 or 255.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
TIERS = ['bronze', 'iron', 'steel', 'silversteel', 'embersteel', 'abyssal steel']
# Accent families read against the shipped bars, never a whole-object tint.
# Main / lit / shadow. Steel is deliberately darker than neutral iron.
ACCENTS = [
    ('#c78238', '#f4b257', '#865027'),
    ('#b6b7b0', '#ecece3', '#777c7b'),
    ('#5f747e', '#99adb4', '#3c4c55'),
    ('#b0d5ef', '#e8f4ff', '#718da8'),
    ('#bb6447', '#f49b6b', '#773f35'),
    ('#8266aa', '#c0a1db', '#503c6f'),
]
INK = '#24252a'
LEATHER = '#795440'
BRASS = '#a77d48'
LIGHT = '#e7bf73'
BONE = '#dbcfae'
PAPER = '#d8c399'

def blank(size=(16, 16)):
    return Image.new('RGBA', size, (0, 0, 0, 0))

def sprite(rows, palette):
    assert len({len(r) for r in rows}) == 1
    im = blank((len(rows[0]), len(rows)))
    d = ImageDraw.Draw(im)
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c != '.':
                d.point((x,y), fill=palette[c])
    return im

def lamp(t):
    a,h,s = ACCENTS[t-1]
    return sprite([
        '......kkkk......',
        '.....kb..bk.....',
        '.....kb..bk.....',
        '....kkbbbbkk....',
        '...kbbbbbbbbk...',
        '....kddddddk....',
        '....kbllllbk....',
        '....kblllwbk....',
        '....kblwwlbk....',
        '....kblwwlbk....',
        '....kbllllbk....',
        '....kddddddk....',
        '...kaaaaaaaak...',
        '...khhhhaaask...',
        '....kkkkkkkk....',
        '................',
    ], {'k':INK, 'b':BRASS, 'd':'#5c4834', 'l':'#c89847', 'w':'#ffe1a0', 'a':a,'h':h,'s':s})

def compass(t):
    a,h,s = ACCENTS[t-1]
    return sprite([
        '.......kk.......',
        '......kbbk......',
        '......kbbk......',
        '....kkkkkkkk....',
        '..kkhhhhhaaakk..',
        '..khpppppppaak..',
        '.khppppkppppask.',
        '.khpppkkppppask.',
        '.kapppkkkpppask.',
        '.kappppkppppask.',
        '.kappppbbpppask.',
        '..kappppbppask..',
        '..kkaaaaaasskk..',
        '....kkkkkkkk....',
        '................',
        '................',
    ], {'k':INK,'b':LEATHER, 'p':PAPER, 'a':a, 'h':h, 's':s})

def vial(t):
    a,h,s = ACCENTS[t-1]
    return sprite([
        '......kkkk......',
        '.....kbbbbk.....',
        '.....kbhbbk.....',
        '......kbbk......',
        '....kaaaaaak....',
        '....khhhassk....',
        '....kggggggk....',
        '...kgwggggggk...',
        '...kgwggggggk...',
        '...kgwgdddggk...',
        '...kggdddddgk...',
        '...kgddllldgk...',
        '...kgdlllllgk...',
        '....kgdddggk....',
        '.....kkkkkk.....',
        '................',
    ], {'k':INK,'b':LEATHER,'h':h,'a':a,'s':s,'g':'#9faeaa','w':'#e0e6ce','d':'#76603e','l':'#c8a361'})

def folded_map(t):
    a,h,s = ACCENTS[t-1]
    return sprite([
        '................',
        '.......kk.......',
        '...kkkkppkkkk...',
        '.kkpppspppspppk.',
        '.kppppspppspppk.',
        '.kppppspppspppk.',
        '.kppppsppkspkpk.',
        '.kpppkspppkpppk.',
        '.kpkppsppkspkpk.',
        '.kppppspppspppk.',
        '.kaaaaaaaaaaaak.',
        '.khhhhaaaaaaask.',
        '.kppppspppspppk.',
        '..kkkkpppskkkk..',
        '......kkkk......',
        '................',
    ], {'k':INK, 'p':PAPER, 's':'#a68a61','a':a,'h':h})

def cloth(p, rank):
    # Large cloth fields; no noise, isolated speckles, or fine stitch texture.
    im = blank((32,32))
    d = ImageDraw.Draw(im)
    if p == 1:
        edge,base,lit,lining = '#252e32','#354146','#3d4a4d','#2b3336'
        trim,shine = '#997044','#d1a25d'
    else:
        edge,base,lit,lining = '#332e2b','#594a3e','#645344','#3e3630'
        trim,shine = '#85705a','#bca17b'
    d.rectangle((0,0,15,31),fill=base)
    d.rectangle((0,0,1,31),fill=edge)
    d.rectangle((3,2,5,29),fill=lit)
    d.rectangle((13,0,15,31),fill=edge)
    d.rectangle((16,0,31,31),fill=lining)
    d.rectangle((16,0,17,31),fill=edge)
    d.rectangle((30,0,31,31),fill=edge)
    d.rectangle((0,0,15,2),fill=lit)
    d.rectangle((0,30,31,31),fill=edge)
    if rank >= 6:
        d.rectangle((0,27,15,28),fill=trim)
        d.line((0,27,15,27),fill=shine)
        d.rectangle((16,28,31,29),fill=trim)
        d.rectangle((1,3,2,26),fill=trim)
        d.rectangle((13,3,14,26),fill=trim)
    if rank == 10:
        d.rectangle((0,29,31,30),fill=shine)
        d.rectangle((0,3,15,4),fill=trim)
        d.rectangle((17,3,30,4),fill=trim)
    return im

def cloak_p1(rank):
    im = cloth(1, rank)
    d = ImageDraw.Draw(im)
    dark,metal,warm,hot = '#202b2e','#b28c52','#d3a359','#f3d58f'
    if rank == 3:
        # Modest lamp patch, sized to survive the narrow cloak face.
        d.rectangle((6,10,9,12),fill=metal)
        d.rectangle((7,11,8,12),fill=dark)
        d.rectangle((4,13,11,14),fill=metal)
        d.rectangle((5,15,10,21),fill=metal)
        d.rectangle((6,15,9,19),fill=warm)
        d.rectangle((7,16,8,18),fill=hot)
        d.rectangle((4,21,11,22),fill=metal)
    else:
        # The pick's broad steel head and wooden haft support a larger lamp.
        d.line((3,18,11,7),fill=dark,width=3)
        d.line((3,18,11,7),fill=metal,width=1)
        d.line((6,6,12,9),fill='#a1a9a5',width=2)
        d.point((13,10),fill='#a1a9a5')
        d.rectangle((6,10,9,12),fill=metal)
        d.rectangle((7,11,8,12),fill=dark)
        d.rectangle((3,13,12,14),fill=metal)
        d.rectangle((4,15,11,22),fill=metal)
        d.rectangle((5,15,10,20),fill=warm)
        d.rectangle((7,15,9,19),fill=hot)
        d.rectangle((3,22,12,23),fill=metal)
    if rank == 10:
        # Warm light reaches the hems and the wing's mineral bands.
        d.rectangle((5,24,10,26),fill='#75613e')
        d.rectangle((6,24,9,27),fill=metal)
        d.rectangle((7,24,8,28),fill=hot)
        d.line((1,7,1,11),fill=warm)
        d.line((14,7,14,11),fill=warm)
        d.rectangle((4,15,4,21),fill=hot)
        d.rectangle((11,15,11,21),fill=hot)
    return im

def cloak_p2(rank):
    im = cloth(2,rank)
    d = ImageDraw.Draw(im)
    shadow,ore,lit = '#302c28','#b5ab91','#eee0b8'
    if rank == 3:
        seam = [(10,9),(8,12),(9,15),(6,18),(7,22)]
        d.line(seam,fill=shadow,width=4)
        d.line(seam,fill=ore,width=2)
        d.line([(10,9),(8,12),(9,14)],fill=lit,width=1)
    else:
        seam = [(10,6),(8,10),(9,14),(6,18),(7,22),(5,25)]
        d.line(seam,fill=shadow,width=5)
        d.line(seam,fill=ore,width=3)
        d.line([(9,7),(7,11),(8,14),(5,18)],fill=lit,width=1)
        d.line([(8,14),(12,17),(11,21)],fill=shadow,width=4)
        d.line([(8,14),(12,17),(11,21)],fill=ore,width=2)
        d.line([(7,22),(3,24)],fill=ore,width=2)
    if rank == 10:
        # Three broad strata open outward into the wing triangles.
        d.polygon([(0,24),(5,22),(8,25),(15,22),(15,25),(8,28),(5,25),(0,27)],fill='#968568')
        d.line([(0,25),(5,23),(8,26),(15,23)],fill=lit,width=1)
        d.polygon([(5,12),(7,10),(10,12),(11,15),(8,18),(5,16)],fill=shadow)
        d.polygon([(5,12),(7,11),(9,12),(10,15),(8,17),(6,15)],fill=ore)
        d.line([(6,12),(7,12),(8,15)],fill=lit,width=2)
        d.line([(3,7),(5,11),(6,12)],fill=ore,width=2)
    return im

def wings(p):
    im = blank((16,32))
    d = ImageDraw.Draw(im)
    # Every texel intersecting the actual geometric triangle is opaque.
    # The front lining is the horizontal mirror of the outer half's mask.
    for y in range(32):
        for x in range(8):
            if 32*(7-x) <= 8*(y+1):
                if p == 1:
                    c = '#354146' if x >= 4 else '#293438'
                    if y >= 22 + x//2:
                        c = '#7c6542'
                    if y >= 25 + x//3:
                        c = '#b28c52'
                    if y == 29:
                        c = '#efd08a'
                    if y == 30:
                        c = '#d1a25d'
                    if y == 31:
                        c = '#252e32'
                    lining = '#303a3c' if y < 28 else '#997044'
                else:
                    c = '#594a3e' if x > 3 else '#453b33'
                    if 19+x//2 <= y <= 21+x//2:
                        c = '#968568'
                    if y == 20+x//2:
                        c = '#eee0b8'
                    if y >= 26:
                        c = '#85705a'
                    if y in (29,30):
                        c = '#bca17b'
                    if y == 31:
                        c = '#332e2b'
                    lining = '#3e3630' if y < 28 else '#85705a'
                d.point((x,y),fill=c)
                d.point((15-x,y),fill=lining)
    return im

def remains(p):
    # One opaque cut edge around each natural object; stone stays transparent.
    # A skull and a tool occupy different corners, so this cannot read as ore.
    if p == 1:
        rows = [
            '................',
            '...kkkk.........',
            '..kbbbbk...kk...',
            '..kbwwbbk.kmmk..',
            '..kbkbkbk..kmmk.',
            '..kbbbbbk..kbk..',
            '...kbbbk..kbk...',
            '....kbk...kk....',
            '..........bk....',
            '..kk.....kbk....',
            '.kccck...kk.....',
            '..kcck..........',
            '..kck...kkkk....',
            '...k...kbbbk....',
            '........kkk.....',
            '................',
        ]
    else:
        rows = [
            '................',
            '.........kkkk...',
            '........kbwwbk..',
            '........kbbbbk..',
            '..kk....kbkbkbk.',
            '.kmmk...kbbbbbk.',
            '.kmmmk...kbbbk..',
            '.kmwmk....kbk...',
            '.kmmmk..........',
            '..kk.....kkkk...',
            '.....kk.kbbbbk..',
            '....kcck.kkkk...',
            '...kccck........',
            '...kcck.........',
            '....kk..........',
            '................',
        ]
    return sprite(rows,{'k':'#39322c','b':'#c2b28d','w':'#eee1bc','m':'#897b5c','c':'#76604c'})

def status(p, kind):
    # Native 64px composition; object pixels use an exact integer 3x scale.
    im = blank((64,64))
    d = ImageDraw.Draw(im)
    # Match the precedent's calm, opaque dark slot without copying its pixels.
    d.rectangle((0,0,63,63),fill='#18242e')
    d.rectangle((2,2,61,61),fill='#202d35')
    fn = (lamp if kind == 'ore_sense' else compass) if p == 1 else (vial if kind == 'ore_sense' else folded_map)
    obj = fn(1).resize((48,48),Image.Resampling.NEAREST)
    im.alpha_composite(obj,(8,12))
    if kind == 'ore_sense':
        # Signal marks above the object are an effect cue, independent of tier.
        d.line([(20,8),(20,4)],fill='#dcc18b',width=2)
        d.line([(32,6),(32,0)],fill='#e7d4a9',width=2)
        d.line([(44,8),(44,4)],fill='#dcc18b',width=2)
        d.rectangle((10,24,11,25),fill='#b39864')
        d.rectangle((54,24,55,25),fill='#b39864')
    else:
        d.line([(48,6),(54,6),(54,12)],fill='#e7d4a9',width=2)
        d.line([(48,16),(54,16),(54,12)],fill='#e7d4a9',width=2)
        d.rectangle((50,10,51,11),fill='#b39864')
    return im

def notes(p):
    idea = (
        'Lamplight and tools: charcoal workcloth carries a growing lamp badge, with a pick at rank 6 and broad bands of lamplight across the rank 10 wings. Ore Sense is a hooded brass lamp; Treasure Hunt is a pocket compass. The remains show a skull beside a snapped pick and a cloth scrap.'
        if p == 1 else
        'Reading the rock: an irregular pale ore seam grows across earth-brown workcloth, forks at rank 6, and opens into layered stone wings at rank 10. Ore Sense is a corked assay vial of mineral dust; Treasure Hunt is a folded survey map. The remains show a skull, a crushed lamp and a loose cloth scrap.'
    )
    lines = [idea,'', 'Original proposal art and scripts: CC0-1.0. Unselected proposals; no game integration. Shared by The Accord and The Throng; no guild name assigned.','']
    ranklines = (
        ['A modest lamp patch on untrimmed charcoal cloth.', 'Larger lamp, a pick above it, reinforced side strips and a bronze hem.', 'Bright lamp core, light down to a double hem, paired with the broad mining wings.']
        if p == 1 else
        ['A single pale seam in plain brown workcloth.', 'A thicker forked seam, side strips and a reinforced hem.', 'A broad ore nodule and outward strata, paired with the layered mining wings.']
    )
    for r, text in zip((3,6,10), ranklines):
        lines.append(f'- `cloak_guild_{r}.png` — 32×32; outer x=0–15, lining x=16–31. {text}')
    lines.append('- `wings_guild_10.png` — 16×32; outer x=0–7 (hinge x=7), lining x=8–15; mirrored by the model; fully opaque across every sampled triangle texel.')
    for kind, noun in [('ore_sense','brass lamp' if p == 1 else 'glass assay vial'),('treasure_hunt','parchment-faced compass' if p == 1 else 'folded parchment map')]:
        for t,name in enumerate(TIERS,1):
            loc = ('lower rim' if kind == 'ore_sense' else 'case rim') if p == 1 else ('neck collar' if kind == 'ore_sense' else 'paper band')
            lines.append(f'- `{kind}_t{t}.png` — 16×16; natural-coloured {noun}; T{t} {name} accent on the {loc}.')
    lines += [
        '- `status_ore_sense.png` — 64×64; the same object with three detection rays, fixed brass accent independent of tier; opaque dark status slot.',
        '- `status_treasure_hunt.png` — 64×64; the same object with a small destination bracket, fixed brass accent independent of tier; opaque dark status slot.',
        '- `miners_remains_overlay.png` — 16×16; bone, worn tool and cloth in an opaque dark cut edge; transparent elsewhere. Use the same overlay on all six faces over the depth tier\'s host stone.',
        '',
        'Host composition: T1 `default_stone.png`; T2–T6 `grug_materials_tN_stone.png`, followed by `^miners_remains_overlay.png`. Do not recolour the bones or the stone. Preview composites live only in `checks/`; no copied stone pixels are included in the proposal assets.',
    ]
    return '\n'.join(lines)+'\n'

def main():
    for p in (1,2):
        out = ROOT / f'p{p}'
        out.mkdir(parents=True,exist_ok=True)
        for r in (3,6,10):
            (cloak_p1(r) if p == 1 else cloak_p2(r)).save(out / f'cloak_guild_{r}.png')
        wings(p).save(out/'wings_guild_10.png')
        for t in range(1,7):
            (lamp(t) if p == 1 else vial(t)).save(out/f'ore_sense_t{t}.png')
            (compass(t) if p == 1 else folded_map(t)).save(out/f'treasure_hunt_t{t}.png')
        for kind in ('ore_sense','treasure_hunt'):
            status(p,kind).save(out/f'status_{kind}.png')
        remains(p).save(out/'miners_remains_overlay.png')
        (out/'notes.md').write_text(notes(p),encoding='utf-8')

if __name__ == '__main__':
    main()
