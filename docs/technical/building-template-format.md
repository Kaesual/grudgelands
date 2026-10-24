# Building template format

Round 56 (lane TPLFORMAT), the contract for lanes FREEZE-TOWNS, FREEZE-CAPITALS, VIEWER and EDITOR. The user's
rulings are [Round 56 plan §2](../planning/round56-plan.md#2-the-users-rulings-2026-10-22), rulings 20–33. This
document changes only through the coordinator.

A **building template** is one town building saved as a text file: its cells, its points and the roles that make it
race-neutral. After the freeze the templates are the source of truth for every town building (ruling 23); the
streets, plazas, walls, city edge, trees, terrain fitting, plot approaches, capital plot placement and terrace
podiums stay algorithmic (ruling 20). The name keeps these files apart from wp40's POI, kit and tree templates.

## 1. Files and places

| What | Where |
|---|---|
| Templates | `mods/MAPGEN/grug_mapgen/building_templates/templates/<name>.tpl` |
| Town layouts | `mods/MAPGEN/grug_mapgen/building_templates/layouts/<town>.layout` |
| Known defects (the baseline of ruling 33) | `mods/MAPGEN/grug_mapgen/building_templates/known_defects.txt` |
| The validator (the gate) | `tools/building_templates/check.py` |
| The editor palette | `tools/building_templates/editor_palette.txt` |
| The node registry the tools read | `tools/building_templates/nodes.json` (lane VIEWER refreshes it from the headless dump; it carries `walkable`, `node_box`, `collision_box`, `selection_box`, `light_source`, `groups`, `paramtype2` and the drawing fields) |
| The baseline ref (§6.2) | `mods/MAPGEN/grug_mapgen/building_templates/BASELINE` |

- A template name is `[a-z0-9_]+`, unique in the directory. The exporter names a template after its first user
  (`<town>_<plot id>`); a template several placements share keeps that name.
- All files are UTF-8 text with `\n` line ends. Lines starting with `#` (after optional spaces) are comments,
  except inside a grid row. Blank lines are ignored outside grids.
- Every file starts with a magic line: `grudgelands-building-template 1`, `grudgelands-town-layout 1` or
  `grudgelands-town-roster 1` (§4). A reader refuses another magic or version.
- The game reads the files once at load (the loader in grug_mapgen). A malformed file stops the server at load with
  the file name, the line number and the reason, never mid-generation. Readers keep the file order everywhere
  (no `pairs` order).

## 2. Frame and box

A template is stored in the frame of the part it came from: the frame `wp13/parts.lua` uses for a part
`{buffer, w, d, points}` before `parts.stamp` turns and moves it.

- **Pivot** `w d`: the part's footprint, which the rotation turns about (`parts.rotate_footprint(x, z, w, d,
  turns)`). It is metadata, not the box: an eave overhang or an apron lies outside `0 … w−1` and keeps its negative
  or larger coordinates, exactly as today.
- **Box** `origin` `x0 y0 z0` and `size` `sx sy sz`: the smallest box holding every cell and every point. The box
  includes everything the building writes outside its footprint (overhang, apron, foundation skirt).
- **The editor never changes the box or the pivot** (ruling 27). A cell outside the box is a validation error.
- x grows to the east, z to the north, y up, in the part's frame (turns = 0). Facedir 0/1/2/3 point at
  +Z/+X/−Z/−X; wallmounted values as in `parts.lua`'s header.
- `parts.stamp`'s rotation is the only rotation: cells by `rotate_footprint`, param2 by `rotate_param2` then
  `canonical_param2`, points by `rotate_footprint` and `face + turns`.

## 3. The template file

An abbreviated example (rows shortened; a real row has exactly `sx` cells):

```
grudgelands-building-template 1
name hearthpine_forge_hall
pivot 11 15
origin -1 0 -1
size 13 9 17
cell 1
meta peak=8
races dwarf

legend
W role wall
F role floor
s role roof_stair channel=roof o=facedir:1
d role door variant=_a o=facedir:2
h role door_hidden o=facedir:2
T node default:torch_wall o=wallmounted:3
p role flower else=air
r race dwarf=F human=W *=F
end

layer 0
|WWWWWWWWWWWWW|
|WFFFFFFFFFFFW|
...
layer 1
|  ..d..      |
...

points
doors 5 1 0 face=2
inside 3 1 7 id=forge_hall
room_corner 1 0 1 top=5 closed=true id=forge_hall
room_corner 9 0 13 top=5 closed=true id=forge_hall
end
```

### 3.1 Header

| Line | Meaning |
|---|---|
| `name <name>` | equals the file name without `.tpl` |
| `pivot <w> <d>` | the rotation footprint (§2) |
| `origin <x0> <y0> <z0>` | the box's minimum corner in the part frame |
| `size <sx> <sy> <sz>` | the box's extent; every count ≥ 1 |
| `cell 1` or `cell 2` | characters per grid cell (§3.3) |
| `meta <key>=<value> …` | the part's metadata the towns read (`peak`, and the measurements the town code takes from the part, §4.1), carried to the stamp result; values as point attributes (§3.4); zero or more lines |
| `races <race> …` | the races whose placements use this template, from the layouts; the validator checks it against them |

### 3.2 Legend

Between `legend` and `end`, one entry per line: a key (one or two characters, as `cell` says), then the entry. The
keys `.` and ` ` (and `..` and two spaces with `cell 2`) are reserved (§3.3). Keys are printable ASCII; no key
contains a space, `.`, `|` or `#` in any position (with `cell 2` too). An edit is compared by the legend
**entry** a cell names, not by its key character (a renamed key is no edit).

An entry is one of:

- **A role** (ruling 22): `role <role> [variant=<suffix>] [channel=<channel>] [o=<orientation>] [else=<fallback>]`.
  The stamp resolves it through the placement's palette: `palette.node(role)`, `palette.variant(role, suffix)`
  for the family roles of `palette.prefix_roles` (door, bed, bed_fancy, pillar), `palette.maybe(role)` for an
  optional role. `channel` names which of the placement's palettes resolves it (§4.2; default: the main palette);
  today's roof palettes are the channel `roof`. A building-bound write that used the town's own palette on a
  placement whose main palette is another (Stillgrave's chapel, Kapok's spirit lodge) uses the channel `town`,
  set in the layout as `town=<palette name>` (usually the plain race palette).
- **A fixed node**: `node <node name> [o=<orientation>]`, the same for every race (a torch that is a torch for every
  race, glass, a station that only this building has).
- **A race switch**: `race <race>=<key> … [*=<key>]`, choosing another legend key per race of the placement (`*`
  for every race not named). It covers cells where a race builds a different role or shape at the same place
  (per-position flora, a race whose bed stands where another race's bench stands). The keys it names are legend
  entries of their own and may not be race switches. A placement whose race is neither named nor covered by `*` is a
  validation error.

**Orientation** `o=<kind>:<value>`, the param2 in the template's own frame (turns = 0):
- `facedir:<n>`: the upright axis 0–3, the upside-down axis 20–23 (only for a stair or a slab, `parts.shaped`),
  the lying axes 4–19 (only for a tree piece);
- `wallmounted:<n>`: 0–5;
- no `o=`: the **default write**, what a part does today when it calls `buf:put` without a param2: the resolved
  node's `parts.place_param2` (0, or the pinned meshoptions value), which `parts.stamp` then turns like any other
  param2. A facedir slab written without a param2 in a plot turned once lands on facedir 1 today, and so it does
  from a template.

The stamp resolves the node first, then its param2 from the resolved node's kind (`parts.param2_kind`, the table in
`parts.lua`; never the registry's `paramtype2`):
- no `o=`: `canonical_param2(rotate_param2(place_param2(node), kind, turns))`;
- `o=` of the resolved node's kind: `canonical_param2(rotate_param2(value, kind, turns))`;
- a resolved node of kind `none`: 0, whatever is stored (today's `Buffer:put` refuses anything else, so every race
  whose node has no orientation wrote 0);
- a resolved meshoptions node: its pinned value;
- a stored kind that differs otherwise (facedir stored, wallmounted resolved): an error the validator reports for
  that race.

That is how one cell can be a pane at param2 3 for one race and bars at 0 for another, and how a role whose node
is facedir for one race (an anvil workbench) and plain for another (an iron block) shares one cell.

**Panes** are stored as the building-bound writes left them before the town's pane pass (the `window` role,
`o=facedir:0` for a wall along x, `o=facedir:3` along z, as `parts.pane` writes it); the town runs
`parts.resolve_panes` over the whole pad after everything, as today, so the settled shape follows from the
neighbours. The pass is idempotent, so a pane a part already settled itself may be stored settled.

**Optional roles and their fallback** `else=<fallback>`: what the stamp writes when the placement's palette does not
bind the role (`palette.maybe` answers nil): `else=air` (force air), `else=unchanged` (write nothing, today's
`maybe` behaviour when the part skips the cell) or `else=<key>` (another legend entry, for example the plain bed for
a fancy bed). An optional role without `else=` means `else=unchanged`. A required role (`palette.required`) takes
no `else=`.

**Families** (`door`, `bed`, `bed_fancy`, `pillar`) always carry `variant=`, with a suffix the family declares. The
door's upper cell is the role `door_hidden`.

### 3.3 Grid

After the legend, one block per y layer from `y0` to `y0 + sy − 1`, each starting with `layer <y>` (the absolute y
in the part frame). A layer has `sz` rows from `z0` (first row) to `z0 + sz − 1` (last row); a row is `|`, then
`sx` cells from `x0` to `x0 + sx − 1`, then `|`. Every row has exactly that width; nothing follows the closing `|`.

A cell is a legend key, or:
- `.` (`..`): **force air**, the part writes air (ruling 25);
- ` ` (two spaces): **leave unchanged**, the part writes nothing.

The `|` frame keeps a row's spaces safe from editors that strip trailing whitespace. A template that needs more
legend keys than single printable characters allow uses `cell 2` (two characters per cell, the frame unchanged).

### 3.4 Points

Between `points` and `end`, one point per line, in list order (the order matters: room corners come in pairs,
patrol points in their walking order):

```
<group> <x> <y> <z> [face=<0-3>] [<key>=<value> …]
```

- `x y z` in the part frame, inside the box.
- `face` is a facedir 0–3 and turns with the part (`parts.stamp`).
- other attributes are copied to the stamp result as they are: integers, `true`/`false`, a bare word
  `[A-Za-z0-9_:.{}-]+` (`{` and `}` only as the token `{id}`), a double-quoted string without `"` or newline, or an ordered **list** of such scalars in
  brackets, `tags=[door,work]` (`[]` is the empty list). A point may omit attributes another point of its group has
  (the second `room_corner` of a pair often carries none).
- **`{id}`** inside a string or bare-word value is replaced by the placement's id at stamp time
  (`id={id}_post_west`), so a template several placements share keeps their per-placement point ids.
- **The editor may move a point (x, y, z) and nothing else** (ruling 28): the group, the order, `face` and every
  attribute stay. The validator compares them with the baseline version (§6.3).

**Building points only.** Points a town places for a building in town coordinates today become points of the
template (ruling 32): a town point belongs to a placement when the town's code derives it from that placement
(from its id, its stamp result or its door), or when it is a town socket tagged `door` that stands within 3 nodes
(the largest of |dx|, |dy|, |dz| at most 3) of one of that placement's `doors` points (the start towns write those as literal coordinates). This covers the `door`-tagged sockets of Hearthpine, Dawnmere,
Silverleaf, Sunscar, Kapok, Stillgrave and the capitals and hand-set inside points (Sunscar). Town-wide points (street patrols,
the waystone, the plaza vendors, sockets on the town's own ground with no building) stay in the town. The exporter
lists every point it moves, with the rule that moved it.

- The town keeps **building its own lists** (sockets, doorways, rooms) in today's order: where it placed such a
  point by hand, it now takes the position from the stamp result by the point's `id` (`sockets` with `id=`) and
  inserts it at the same place in its list, so the point digest stays equal. Such a template point carries only its
  `id` and `face`; the role, tags and every other attribute stay in the town's own entry, which names the building
  and the point id (the template holds where the point stands, the town what it is for).
- A town socket's direction is converted to `face` (facedir 0–3) for the template and back to the town's own
  encoding after the stamp; the exporter proves the round trip for every moved point.
- A building point may stand outside the building's walls on ground the town writes (Hearthpine's hall quest giver
  stands on the path two nodes before the door); such cells are "leave unchanged" in the template, and the point
  rules treat them as below.

**Point groups and where they must stand** (ruling 33, hard). The coordinator's reading of the code; a lane that
finds a group missing here, or a rule that does not match the code, reports it and the coordinator extends this
table before the lane merges.

| Group | Today from | Placed as |
|---|---|---|
| `doors` | the door writers of the former generators (now in the templates) | in a **doorway**: a door leaf cell (a member of the `door` family, `_a` or `_b`) whose facedir equals `face`, or an open doorway with no door (two passable cells above each other, as the elf tree platform writes it) |
| `room_corner` | the former room writers | in pairs (1st and 2nd, 3rd and 4th …), both at the same y, inside the box (the y is the room's floor or the first cell above it, as each writer chose; no node rule) |
| `inside` | the destination spot | a standing point (below) |
| `lights` | the light writers | no placement rule (no town reads the group; towns find lights from the cells); kept as data |
| `sockets` | the NPC and quest sockets | a standing point |
| `trees` | the stems of a planted template (§4.2) | inside the box, the stem column's ground cell (y = 0) written by the template and not air; attributes `kind=<planter>` and `height=<n>` |

A **standing point** is a cell whose node and the node above are both passable while the node below is walkable.
Passable: not `walkable` in the registry, or part of a door (the leaf and its `door_hidden`, which the registry
marks walkable so falling nodes stop on it), or "leave unchanged". Walkable below: `walkable` in the registry, or a
"leave unchanged" cell at or below the template's ground layer (y ≤ 0 of the part frame, the town's ground). A gate
(`fence_gate`, a `doors:gate_*` node) is not a door leaf.

## 4. The town layout file

```
grudgelands-town-layout 1
town hearthpine
race dwarf

palette slate race=dwarf roof_slab=grug_decor:darkage_slate_tile_slab roof_stair=grug_decor:darkage_slate_tile_stair

place forge_hall template=hearthpine_forge_hall x=-5 y=0 z=-26 turns=0 roof=slate
place west_home template=hearthpine_west_home x=-26 y=0 z=2 turns=3
```

- `town <id>` and `race <race>`: the town and its race (the main palette).
- `palette <name> race=<race> [<role>=<node> …]`: a named palette, built as `palette.new(race, overrides)` builds it
  today (an override names a declared role).
- `place <id> template=<name> x= y= z= turns= [main=<palette name>] [<channel>=<palette name> …] [lift=<n>]`: one placement,
  in **stamp order** (the order the town writes its buildings today). `id` is the building's landmark id (the plot
  id the town's code and quests use). `x y z` is exactly the anchor `parts.stamp` takes, any lift included
  (Silverleaf stamps at `y = lift`; the town still adds its lift to what it derives from the stamp result, as
  today). `lift` is read only by the town's podium code (the terrace, its railings, the lift it adds); for a
  lifted placement `y` equals `lift`. `main` is the placement's main palette when it is not the town's (Stillgrave's chapel builds from the
  `crypt` palette, Kapok's terrace plots from `terrace`); a channel the placement does not set resolves through the
  placement's main palette (today's `spec.roof_palette or palette`, where `palette` is the one the generator got).
- **Overrides belong here, never in a template** (Silverleaf's pale roofs, Highcourt's white and slate).

A town whose building placement stays algorithmic (the capital plot planner, ruling 20) may have no layout file:
its code names the template and the palettes per placement. Its "used N× in …" list and the validator's palette
checks then come from a roster the freeze writes next to the layouts (`layouts/<town>.roster`, magic line
`grudgelands-town-roster 1`, then a `town` and a `race` line, the same `palette`
lines as a layout, then one `use <template> count=<n> [main=<palette name>] [<channel>=<palette name> …]` line per
template and palette combination), which the validator checks against a build. In a roster, a `use` line
without `main=` means the palette named `town`, and a non-roof channel resolves to the roster palette of the same
name. A `sockets` point without a `role` attribute is the position of a town entry (§3.4).

### 4.1 The loader's result

The loader turns a template into a **part** exactly like a generator's result, `{buffer, w, d, peak, points, …meta}`
(a `parts.buffer` filled in the template frame for the placement's palettes, `w`/`d` from `pivot`, the `meta` values
as fields), so `parts.stamp` stays the only rotation and its `footprint` comes out as before. The groups every
generator part carried (`doors`, `lights`, `inside`, `room_corner`) are always present in the result, empty when
the template has no such point. Town code that
measures a part (`ground_area` and `clear_to` in the capital plot builders read the part's own non-air cells) must
measure what it measured before: such a measurement is computed from the part as the generator built it and stored
in `meta` (for example `meta extent=[x0,z0,x1,z1]`), in the part frame, and the town code reads it from there and
rotates it as it rotates cells.

### 4.2 Planting (trees stay algorithmic)

Trees are vegetation, not buildings: they come from the tree generator (`dressing.grown` and the planters built on
it), so a change of the generator reaches every tree (the user, 2026-10-22, overriding the first freeze of the
capital groves and orchards). A template whose part planted trees (groves, orchards, copses, gardens) is a
**planted template**:

- its cells are what the part wrote **before** planting (ground, paths, hedges, kerbs);
- its `trees` points are the stems, in planting order, each with the planter (`kind=`, the `dressing` function the
  part called) and `height=`; `meta plant_spacing=<n>` when the part set `buf.tree_spacing`;
- `meta undergrowth=[x0,z0,x1,z1,density]` when the part scattered undergrowth after planting;
- cells the part wrote **after** planting (lanterns, a gate, anything written over the grown trees) are legend
  entries marked `late` (`role path_light late`, `node … late`); `late` is allowed on role and node entries, not on
  race switches, and air written after planting is `node air late`;
- a template that only scatters undergrowth (Lethariel's bough platforms) is planted too, with no `trees` points.

The loader builds the part buffer from the cells, plants at the `trees` points in order with the placement's
palette (in the part's own frame, before `parts.stamp`, exactly as the generator did), scatters the undergrowth,
writes the `late` cells, and only then returns the part. A stem whose tree does not fit stays out, as before. The
template therefore holds no tree, leaf or undergrowth cell, and the editor moves stems as points (ruling 28).

## 5. Multi-cell objects

A multi-cell object takes several cells, is placed only where all of them are free and is removed as a whole
(ruling 29). The validator (hard) and the editor know:

| Object | Cells |
|---|---|
| Door | the leaf (a member of the `door` family, variant `_a` or `_b`) at y, `door_hidden` at y + 1 with facedir = the leaf's for `_a` and (leaf + 3) % 4 for `_b` (`parts.door`); gates are not doors |
| Bed | `_bottom` at the cell, `_top` one step along its facedir with the same facedir (`parts.bed`), for `bed` and `bed_fancy` |

Only doors and beds reserve cells. Other nodes whose box reaches into a neighbouring cell (lane EDITOR's list
from `nodes.json`: the castle pillars' crossbraces, the open window shutter, the wagon wheel on the road, corals and
kelp, seagrass, the waystone, the cairn base, the tree bases, the mob fences) only **overhang**: they take one cell,
and the editor marks the overhang in its item list. `xpanes:door_steel_bar_*` would be a door, but no palette binds
it. A pillar stack (`pillar` `_bottom`, `_middle`, `_top`) is three single cells.

## 6. Validation rules

One validator, `tools/building_templates/check.py`, used by the gate and by the editor before it saves (the
editor imports it). It exits non-zero on any error and prints warnings. Its inputs are the template and layout
files, the palettes (`wp13/palette.lua`, `troll_palette.lua`, read through LuaJIT or a dump the tool writes and
checks), the node registry (`nodes.json`), the editor palette and the known-defects list.

### 6.1 Always hard (structure)

- the file parses; header, legend and grid as §3; the name matches the file;
- every cell and point inside the box; layers, rows and widths complete;
- every legend key used is defined; every role is declared in `palette.lua`; every variant suffix is the family's;
  `else=` only on optional roles; race switches name defined, non-switch keys;
- **known nodes:** every fixed node, and every node a role resolves to for each race and channel palette of every
  placement, is in the registry (`nodes.json`);
- **roles per placement:** every role a placement resolves is bound by that placement's palette for that channel,
  or is optional (ruling 22);
- **orientation:** every stored orientation fits the resolved node's kind for every placing race (§3.2) and the
  `parts.lua` limits (upside-down only for shaped nodes, lying axes only for tree pieces);
- **multi-cell objects** complete (§5);
- **points** placed as their group requires (§3.4), in pairs where the group needs them; ids, groups, order, faces
  and attributes equal the baseline version's (only positions may differ, ruling 28);
- the box and the pivot equal the baseline version's (ruling 27);
- every layout: known templates, the `races` header covering its race, channels naming defined palettes, no two
  placements with the same id.

### 6.2 Hard only for edited cells (content)

An **edited cell** is a cell whose legend entry differs from the template's **baseline version**: the file at the
commit `BASELINE` names (§1; one line, a commit id). The freeze lane writes it in a commit after the one that adds
the templates, naming that commit; a later lane that changes templates on purpose (with a declared map reset, §9)
moves it with the coordinator's approval. A template missing at the baseline counts every cell as edited. The
exporter runs the validator with `--baseline=self` (the files compared with themselves: no cell edited), so the
freeze passes its own gate before `BASELINE` exists. The tool needs the repository's history; without it, it stops
with a clear message. Without a `BASELINE` file the validator refuses to run except with `--baseline=self` (so
deleting the file cannot switch the content rules off). The named commit must be in main's history (lanes merge
with `--no-ff`, never squashed or rebased), or `BASELINE` names a tag.

- **The editor palette:** an edited cell holds only a role or node the editor palette allows (§7). Existing cells
  outside the palette (river water in a fountain, farm soil and crops, stations with inventories) stay valid; they
  just cannot be painted anew.
- **Reachability:** every standing point (`inside`, `sockets`, and any group the table marks as standing) that is
  reachable from an entrance in the baseline version is reachable now. The walk: from the entrance cells, steps to
  the four horizontal neighbours with a height change of at most one node, onto standing cells only, doors
  passable. Entrances are the `doors` points; a template without door points starts from every standing cell on
  its box edge.
- **The entrance on the footprint edge:** when the baseline version has a door point on the edge of the pivot
  footprint (or one step outside it), the edit keeps one there.

### 6.3 Warnings

- a "leave unchanged" cell in a floor inside the walls (a cell at the y of a `room_corner` pair, inside its
  rectangle);
- a fixed node painted into a template several races use (the editor flags it too, ruling 22);
- every entry of `known_defects.txt` that still holds (the frozen state's known defects, ruling 33: what the freeze
  lanes list; the Lethariel bough stair was fixed in the templates in Round 58). An entry that no longer holds is
  reported so it can be removed.
- every standing point unreachable in the baseline version already (reported, not refused).

`known_defects.txt`: one entry per line, `<template> <rule> <x> <y> <z> <note …>`; the rule is a validator rule id
the tool prints with each finding.

## 7. The editor palette

`tools/building_templates/editor_palette.txt` lists what an edited cell may hold: one entry per line, `role <role>`
or `node <name>`, with a group heading line `[<group>]` for the editor's item list (full blocks, stairs and slabs,
glass and panes, fences, doors, beds, lights, decor). It holds no liquids, no falling nodes, no plants that need
soil, no nodes with inventories or text the game does not fill, and no nodes whose function depends on where they
stand (crafting stations and the like) unless the template already has one (that cell is then not an edit). Roles
come first in the editor's list, drawn in the previewed race's material. New roles are added in `palette.lua` by a
lane, never in the editor (ruling 22).

## 8. The freeze (lanes FREEZE-TOWNS and FREEZE-CAPITALS)

- **What a template holds** (ruling 32), defined by the **step that writes**, not by where the cell lies:
  - the building's own part (its generator), and
  - the **building-bound steps**: later town steps that write into that building because of it (parameterised by
    its id, its placement or its stamp result: hall inlays, braziers and hangings, belfries, room and apron decor,
    the hall's lamps). The exporter lists the building-bound steps of every town by name.
  - Everything else stays in the town's code: paths and plazas, terrain and podiums (Silverleaf's podium railings),
    the city edge and walls, outer stairs and parapets the town builds around a plot (Sunscar), ropes and lanterns
    of the town's decks (Kapok), and the tree pass (`layout.green`) with every leaf it writes.
  - A cell's template value is the **last building-bound write** to it, never "what the finished town holds" (a
    leaf the final tree pass drops on a roof stays the town's). A cell no building-bound step writes is "leave
    unchanged".
  - **Stamp time:** the template writes everything at the stamp. Where moving a building-bound write from its later
    step to the stamp would change what a step in between does (a `free_area` or `natural` test, a tree cut by
    `Buffer:put`, a measurement), that write stays in the town's code and the exporter lists it; byte identity
    decides. Where a step cannot be split cleanly, the whole step may stay (Hearthpine's decor: its paved approaches
    would erase 9 of its 67 writes); its cells are then not template content until a map-reset round moves them.
  - Town points derived from the building become template points as §3.4 says.
- **Roles** (ruling 22) are found by building each part with each placing race's palette and with **tagged probe
  palettes**: every role bound to a tagged name that answers every name predicate the generators ask exactly as the
  placing race's real node does (`parts.full_solid`, `pane_connects`, `wild_soil`, `is_pane`, `shaped`,
  `tree_piece`, `param2_kind`, `place_param2`, `layout.green`'s tree choice by `tree_log`, `decor_kit`'s window and
  soft tests, and any other the lane finds), with channels tagged apart where the code allows (where it compares node names across palette handles, as the
  capital code does, all handles are tagged alike and a role's channel is taken from the first palette of the
  placement that binds that node; byte identity decides); a probe palette handle keeps `race` = the placing race (the decor kit branches on
  `palette.race`). A cell holding a tagged name follows that
  role; a cell that follows none is a fixed node; a cell the probe cannot decide keeps its node and is listed.
  Building a part with another race's palette may fail (a wall torch with no solid support); role inference uses the
  placing races only, and the other races' failures are tolerated and reported, not errors. Roles identical in all
  six palettes today are still recorded as roles; where only the probe can tell them apart, a group may map to one
  canonical role.
- **Identical parts become one template:** the same legend entries in the same cells, the same points (each point
  value that contains the placement's id written as `{id}`, §3.4) and the same `meta` (the measurements of §4.1 are
  part of a template's identity).
- **Proof:** the settlement identity hashes of every town unchanged, and a digest of everything the identity bytes
  leave out (landmarks, sockets, doorways, rooms, inside points, `peak`, any other point the towns or quests read)
  equal before and after.

## 9. Release rule

A change to a template, a layout, a palette or anything else that changes what the towns build changes new worlds:
the release declares a map reset. `tools/check_upgrade.py` enforces it by comparing the generated settlement
identities and the point digest with the previous release (lane FREEZE-TOWNS).
