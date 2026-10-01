#!/usr/bin/env python3
"""Assemble the full art manifest from preserved generation receipts and palettes.

This does not call a model. Run after all originals have been generated, then
run prepare.py. --partial is only for visual inspection during production.
"""
import argparse
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'docs/planning/round28/art'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--partial', action='store_true')
    args = parser.parse_args()
    probe = json.loads((ART / 'probe_manifest.json').read_text())
    catalog = json.loads((ROOT / probe['catalog']).read_text())
    palettes = json.loads((ROOT / 'tools/r28_art/palettes.json').read_text())
    probes = {a['id']: a for a in probe['assets']}
    assets = []
    missing = []
    for item in catalog:
        if 'icon' not in item:
            continue
        key = item['id'].split(':')[1]
        if item['id'] in probes:
            asset = copy.deepcopy(probes[item['id']])
            asset['probe_reuse'] = {'manifest': 'docs/planning/round28/art/probe_manifest.json',
                                    'sha256_16': asset['outputs']['16']['sha256']}
            asset['generation_icon_brief'] = asset['icon']
        else:
            receipt = ART / 'generation' / (item['id'].replace(':', '_') + '.json')
            if not receipt.exists():
                missing.append(item['id'])
                continue
            asset = json.loads(receipt.read_text())
            asset['palette'] = palettes[key]
        for field in ('name', 'tier', 'family', 'icon', 'description'):
            asset[field] = item[field]
        asset['kind'] = item['kind']
        asset['outputs'] = {'16': {'path': 'docs/planning/round28/art/icons/' + item['id'].replace(':', '_') + '.png'}}
        assets.append(asset)
    if missing and not args.partial:
        raise SystemExit(f'Missing {len(missing)} originals: ' + ', '.join(missing))

    # Existing family signatures first; generic drops where that family had no
    # signature before Round 28. Wisp has no surface drop and uses an explicit
    # material analogue, never labelled as an existing wisp signature.
    comparisons = {
        'zombie': ('zombie_flesh', 'Rotting Flesh', 'existing family material'),
        'outlaw': ('stolen_purse', 'Stolen Purse', 'existing outlaw drop'),
        'boar': ('boar_tusk', 'Boar Tusk', 'existing family signature'),
        'rat': ('raw_meat', 'Raw Meat', 'existing rat drop'),
        'crab': ('scaled_hide', 'Scaled Hide', 'existing crab drop'),
        'fox': ('fang', 'Fang', 'existing fox drop'),
        'grazer': ('leather', 'Leather', 'existing grazer drop'),
        'feline': ('raptor_claw', 'Small Cat Claw', 'existing family signature'),
        'canid': ('fang', 'Fang', 'existing family signature'),
        'bear': ('bear_claw', 'Bear Claw', 'existing family material'),
        'crocodile': ('croc_tooth', 'Crocodile Tooth', 'existing family material'),
        'ooze': ('slime_gel', 'Slime Gel', 'existing family material'),
        'mirefolk': ('shiny_scale', 'Shiny Scale', 'existing family material'),
        'wisp': ('stone_core', 'Stone Core', 'analogue; surface wisp has no loot'),
        'treant': ('stick', 'Stick', 'existing treant drop'),
        'weevil': ('raw_meat', 'Raw Meat', 'existing weevil drop'),
        'ape': ('ape_hair', 'Ape Hair', 'existing family signature'),
        'venomous': ('venom_sac', 'Venom Sac', 'existing family material'),
        'spider': ('spider_silk', 'Spider Silk', 'existing family material'),
        'goblin': ('stolen_purse', 'Stolen Purse', 'existing family signature'),
        'skeleton': ('bone', 'Bone', 'existing family material'),
        'witch': ('venom_sac', 'Venom Sac', 'existing witch drop'),
        'scavenger': ('sharp_feather', 'Sharp Feather', 'existing family material'),
        'stone': ('stone_core', 'Stone Core', 'existing family material'),
    }
    references = []
    for family, (key, name, relation) in comparisons.items():
        ref = {'family': family, 'name': name, 'relation': relation,
               'path': f'mods/ENTITIES/grug_mobs/textures/grug_mobs_item_{key}.png',
               'license_record': 'mods/ENTITIES/grug_mobs/LICENSE-media.md',
               'author': 'Grudgelands project', 'license': 'CC0-1.0',
               'comparison_treatment': 'Unmodified source pixels, nearest-neighbour 8x enlargement; comparison only, not generation input.'}
        if key in ('zombie_flesh', 'slime_gel'):
            ref.update(author='XSSheep / VoxeLibre contributors', license='CC-BY-SA-4.0',
                       source_url='https://git.minetest.land/VoxeLibre/VoxeLibre')
        elif key in ('raw_meat', 'leather'):
            ref.update(path='mods/ENTITIES/mobs/textures/mobs_' + ('meat_raw' if key == 'raw_meat' else key) + '.png',
                       license_record='mods/ENTITIES/mobs/license.txt', author='TenPlus1', license='CC0-1.0')
        elif key == 'stick':
            ref.update(path='mods/BASE/default/textures/default_stick.png',
                       license_record='mods/BASE/default/README.txt', author='BlockMen', license='CC-BY-SA-3.0')
        references.append(ref)
    manifest = {
        'tool': probe['tool'], 'date': '2026-10-02',
        'status': 'production in progress' if missing else (
            'complete; user style approval 2026-10-02 (Jan); independent review Claude Opus 5.5: MERGE; '
            'integrated (mods/ENTITIES/grug_mobs/textures)'),
        'license': probe['license'], 'catalog': probe['catalog'],
        # The originals live outside git (archive path and note in the probe manifest).
        'originals': copy.deepcopy(probe['originals']),
        'scope': 'Every new item in global catalog/items.json; later zone-local additions are outside this snapshot.',
        'expected_counts': {'1': 9, '2': 15, '3': 21, '4': 18, '5': 10, '6': 16},
        'assets': sorted(assets, key=lambda a: (a['tier'], a['family'], a['id'])),
        'references': references, 'postprocess': copy.deepcopy(probe['postprocess']),
        'probe_manifest': 'docs/planning/round28/art/probe_manifest.json',
        'retired_probe': {'id': 'grug_mobs:rusted_braces', 'reason': 'Removed from approved catalogue; retained only as historical probe, not an installable icon.'},
        'probe_brief_exceptions': {
            'grug_mobs:rat_tail': 'Approved open hook retained; revised catalogue asks for S curl.',
            'grug_mobs:bandit_talisman': 'Approved bone charm retained; revised catalogue asks for wooden disc.',
            'grug_mobs:fox_tail': 'Approved upward comma retained; revised catalogue describes downward curl.',
            'grug_mobs:bound_wisp_mote': 'Approved blue bottled light retained; revised catalogue asks for violet sphere with copper arcs.'
        },
        'generation': {'new_originals': len([a for a in assets if 'probe_reuse' not in a]),
                       'reused_probe_icons': len([a for a in assets if 'probe_reuse' in a]),
                       'input_images': 0, 'discarded_variants': sum(len(a.get('discarded_variants', [])) for a in assets),
                       'failed_attempts': sum(bool(a.get('prior_failed_attempt')) for a in assets),
                       'source_handling': 'Built-in imagegen PNGs copied byte-for-byte; no CLI/API fallback. Original alpha retained. Receipts preserve exact prompts and source paths.'},
        'assessment': {'style': 'Approved premultiplied BOX export, hard alpha and muted material palettes retained. Native 16px icons inspected on tier and family sheets.',
                       'limitations': ['Coded Talisman tally cuts, Siege Weapon Strap stitching and Bone Chitin pores merge into larger clusters at 16px; the silhouette and material cues remain the identifying features.', 'Ash Feather deliberately has the lowest dark-slot contrast because the brief specifies soot-black material; the two orange barbs remain its main cue.', 'Approved Bound Wisp Mote remains a blue bottle and can read as a mana potion; explicit probe reuse takes precedence over the revised violet-sphere brief.'],
                       'probe_policy': 'Five catalogue-matching probe IDs reuse their exact approved 16px bytes. Four changed briefs are recorded as explicit reuse exceptions. Rusted Braces is historical only.'},
        'review': {'classification': 'non-trivial art and export tooling', 'implementer': 'GPT-6 Astra',
                   'independent_reviewer': 'Claude Opus 5.5 (coordinator review, 2026-10-02): MERGE',
                   'critical_high_findings': None,
                   'review_fix_rounds': 0, 'elapsed_wall_time': 'not measured',
                   'user_style_approval': '2026-10-02 (Jan): Ja, die Icons finde ich gut, der Stil gefällt mir. Bitte so umsetzen.',
                   'runtime': 'integrated (mods/ENTITIES/grug_mobs/textures)'}
    }
    manifest['postprocess']['algorithm'] = 'Unchanged probe export: crop alpha >= 128 bounds; proportionally fit 14x14; premultiplied-alpha BOX downsample; binary alpha threshold 128; nearest fixed material palette without dithering; center on transparent 16x16 canvas.'
    (ART / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Assembled {len(assets)} assets; {len(missing)} outstanding')


if __name__ == '__main__':
    main()
