#!/usr/bin/env python3
"""Round 69 lane CAMP: install the user's pick, Wallwright, as the game's camp
site templates, from tools/r69_camp_art/candidates/wallwright/.

One change on the way: the role `ground_bare` becomes `subsoil`. The editor
palette leaves `ground_bare` out because three races bind it to a falling node
(gravel, desert sand), so the template gate refuses it; `subsoil` is bare earth
on every race. It touches the seven gap cells of the rear footing and nothing
else.

Usage: python3 tools/r69_camp/install_pick.py [--check]
"""
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'tools/r69_camp_art/candidates/wallwright'
TARGET = ROOT / 'mods/MAPGEN/grug_mapgen/building_templates/templates'
RACES = ('dwarf', 'human', 'elf', 'undead', 'orc', 'troll')


def installed(race):
    text = (SOURCE / ('camp_site_%s.tpl' % race)).read_text()
    assert text.count(' role ground_bare\n') == 1, race
    return text.replace(' role ground_bare\n', ' role subsoil\n')


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--check', action='store_true')
    args = ap.parse_args()
    for race in RACES:
        path = TARGET / ('camp_site_%s.tpl' % race)
        if args.check:
            assert path.read_text() == installed(race), 'template differs: ' + str(path)
        else:
            path.write_text(installed(race))
    print('Round 69: 6 camp site templates ' + ('verified' if args.check else 'installed'))


if __name__ == '__main__':
    main()
