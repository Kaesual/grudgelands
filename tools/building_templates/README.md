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

## The freeze (lane FREEZE-TOWNS, Round 56)

The six start towns' buildings were cut out of the finished towns into the
templates under `mods/MAPGEN/grug_mapgen/building_templates/` (format doc §8).
Since then the templates are the source of truth; the tools below are the
record of how they were made and the gates that keep them honest.

- `export.py` runs `export.lua` on the mapgen of the pre-freeze commit
  (`PRE_FREEZE`, extracted with `git archive`): `freeze_build.lua` builds each
  town twice, once with the race palettes and once with **tagged probe
  palettes** (every role bound to `<node>#<handle>:<role>`, every name
  predicate of the library answering for the node), logs every write with the
  town statement that made it, and the exporter takes each building's part
  plus the writes of the town's building-bound steps (listed in `TOWNS` with
  the rule that assigns a write to a building), labels every cell from its
  probe twin (a role and its channel, or a fixed node), moves the door-tagged
  sockets within three nodes of a building's door and Sunscar's platform point
  into the template, merges identical parts and writes the templates and one
  layout per town. It then reads every template back through the game's loader
  and requires exactly the cut cells for every placement, and resolves each
  template for all six races against the generator ("per-race shapes").
  `freeze_report.txt` is its report: the building-bound steps per town, the
  steps kept in town code by the stamp-time rule (Hearthpine's decor), the
  points moved, per template its cells, legend, role and fixed-node cells and
  the town writes kept in its box. `export.py --check` proves the committed
  templates are still that export (it fails once a template is edited on
  purpose; it is not a release gate). Rerunning `export.py` without `--check`
  overwrites every template.
- `check.py` is the validator of format doc §6 and the gate: `check.py`
  (against `BASELINE`), `check.py --baseline=self` (the freeze),
  `--write-known-defects` (the exporter's known-defects baseline; empty for
  the start towns), `--self-test` (the parser and every rule on mutated copies
  of a frozen template). It reads the palettes and the param2 rules from the
  game's Lua through `palette_dump.lua` (LuaJIT) and the registry from
  `nodes.json`. The editor imports `validate(root, baseline, replaced)`.
- `editor_palette.txt`: the first version of the editor palette (format doc
  §7), written from the rules and the registry; lane EDITOR extends it.
- `town_identity.lua <repo> [<tree>] [--load]`: what the towns build, per
  start town the settlement identity and the point digest (and with `--load`
  the construction time and the allocation), per capital a digest over its
  core and plots. `tools/check_upgrade.py` runs it on the pushed commit and on
  the working tree and wants a map reset when they differ.
