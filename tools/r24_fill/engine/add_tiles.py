"""Add the Round 24 rock tiles (grug_materials/init.lua ROCK_TILES, used in a
registration loop the static tile scanner cannot follow) to a node_tiles.json
made by tools/wp13/extract_tiles.py. Usage: add_tiles.py IN.json OUT.json"""
import json, os, re, sys
here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.abspath(os.path.join(here, "..", "..", ".."))
d = json.load(open(sys.argv[1]))
src = open(os.path.join(repo, "mods/ITEMS/grug_materials/init.lua")).read()
block = src[src.index("local ROCK_TILES = {"):]
block = block[:block.index("}")]
for key, tile in re.findall(r'(\w+)\s*=\s*"([^"]+)"', block):
    d['nodes']['grug_materials:' + key] = {'tiles': [tile], 'shape': 'cube',
                                           'source': 'grug_materials/init.lua ROCK_TILES'}
# grug ores not found by the scanner: iron overlay as a stand-in (render only)
for k in ['quartz', 'silver', 'citrine', 'garnet', 'jade']:
    d['nodes'].setdefault('grug_materials:stone_with_' + k, {
        'tiles': ['default_stone.png^default_mineral_iron.png'], 'shape': 'cube',
        'source': 'r24 render stand-in'})
json.dump(d, open(sys.argv[2], 'w'))
