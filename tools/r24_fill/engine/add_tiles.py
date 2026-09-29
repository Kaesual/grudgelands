"""Add the Round 24 rock tiles (grug_materials/init.lua ROCK_TILES, built in a
loop the static tile scanner cannot follow) to a node_tiles.json made by
tools/wp13/extract_tiles.py. Usage: add_tiles.py IN.json OUT.json"""
import json, sys
d = json.load(open(sys.argv[1]))
rocks = {"t2_stone": "default_stone.png^[multiply:#ebebf0",
         "t3_stone": "default_stone.png^[multiply:#d7d7df",
         "slate": "default_stone.png^[colorize:#3e4a5c:130",
         "basalt": "default_stone.png^[colorize:#1c1c20:170",
         "granite": "default_stone.png^[colorize:#a8705e:110"}
for k, v in rocks.items():
    d['nodes']['grug_materials:' + k] = {'tiles': [v], 'shape': 'cube',
                                         'source': 'r24 manual (grug_materials/init.lua ROCK_TILES)'}
# grug ores: approximated with the iron mineral overlay (render only)
for k in ['quartz', 'silver', 'citrine', 'garnet', 'jade']:
    d['nodes']['grug_materials:stone_with_' + k] = {
        'tiles': ['default_stone.png^default_mineral_iron.png'], 'shape': 'cube',
        'source': 'r24 manual approx'}
json.dump(d, open(sys.argv[2], 'w'))
