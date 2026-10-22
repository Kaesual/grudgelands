# Building template tools (`tools/building_templates`)

Tools for the building templates of
[building-template-format.md](../../docs/technical/building-template-format.md):
the node registry they read, and (from lanes VIEWER and FREEZE-TOWNS) the
viewer, the gallery, the exporter and the validator. Nothing here ships with the game.

## The node registry (`nodes.json`)

`nodes.json` is every registered node of the game as the engine sees it after
all mods are loaded: the drawing fields the viewer needs (`drawtype`, `tiles`,
`overlay_tiles`, `special_tiles`, `node_box`, `connects_to`, `connect_sides`,
`mesh`, `paramtype`, `visual_scale`, `use_texture_alpha`, `color`, `palette`,
`waving`, `leveled`) and the fields the validator needs (`walkable`,
`collision_box`, `selection_box`, `light_source`, `groups`, `paramtype2`,
`place_param2`, `liquidtype`, `climbable`, `buildable_to`), plus the English
`description` (first line) for the editor's item list, and the alias table.
A field the mod left out carries the engine's default. It is the validator's
source of known nodes (format doc §1, §6.1).

The file is sorted (keys at every level) with one node and one alias per line,
so a refresh with unchanged node definitions is byte-identical and a changed
node shows as a one-line diff.

### Refreshing it

The file only changes when node **definitions** change (a new decor node, new
node boxes, new textures, changed groups). Template edits never need it.
Refresh it with one isolated headless boot (about a minute; it counts as one
Lua process, so through the shared queue when one is in use):

```sh
tools/building_templates/node_dump/refresh.sh
git diff --stat tools/building_templates/nodes.json
```

`refresh.sh` stages the disposable probe `node_dump/grug_template_node_dump`
through `PROBE=` of `tools/luanti_headless.sh` (never into `mods/`, never the
personal Luanti folder), the probe writes `<world>/template_nodes.json` once all
mods are loaded and shuts the server down, and `node_dump/normalize.py` writes
the sorted file. The run directory is removed afterwards; a failed run keeps it
and says where.

## The viewer and the gallery (`viewer/`)

The town viewer, the template gallery and the shared node renderer the
template editor reuses: see [`viewer/README.md`](viewer/README.md).
