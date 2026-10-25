# Building template tools (`tools/building_templates`)

Tools for the building templates of
[building-template-format.md](../../docs/technical/building-template-format.md):
the node registry they read, and (from lanes VIEWER, FREEZE-TOWNS and EDITOR)
the viewer, the gallery, the exporter, the validator and the editor. Nothing
here ships with the game.

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

## The freeze (lanes FREEZE-TOWNS and FREEZE-CAPITALS, Round 56)

The six start towns' and the six capitals' buildings were cut out of the
finished towns into the templates under
`mods/MAPGEN/grug_mapgen/building_templates/` (format doc §8).
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
  the town writes kept in its box. `export.py --check` proved the committed
  templates were still that export; it is **retired** since Round 58 (lane
  HALLS made the first deliberate template edit, the Miner's Guild houses), so
  it now only says so, and `check.py` is the gate. Rerunning the export
  (`export.py --overwrite-edits`, refused without the flag) would put every
  template back to the generators' version and delete the templates made
  since.
- `export.py` also runs `export_capitals.lua` on the mapgen of
  `PRE_CAPITAL_FREEZE`: every capital's core and every district plot built on
  its own (`freeze_build.build_capital`), with **role-only** probe tags (a
  capital compares names across its palette handles, so every handle tags
  alike, `<node>#h0:<role>`, and a role's channel is the first of the
  placement's palettes binding it to the cell's node). Every stamped part is a
  placement (the core's buildings, each plot's building, the ruin close's two
  shells), cut with the writes of the building-bound steps listed in
  `CAPITALS` (hall floor bands, braziers, hangings, the chapel belfry, the
  deck breastworks, room decor); the door-tagged socket overrides and the
  door-tagged core sockets move into the templates; every template carries
  `extent` and `top` (the part's measurements, format doc §4.1). It writes one
  roster per capital (`layouts/<capital>.roster`) and
  `freeze_report_capitals.txt` (with the placements and their templates, and
  the capital parts that equal a start town's template apart from the
  measurements). The shared pieces of both exporters are `export_lib.lua`.
- **Planted templates** (lane TREES, Round 56; format doc §4.2): a part that
  planted trees or scattered undergrowth (the groves, orchards and copses,
  the Lethariel boughs: 13 templates) keeps its trees algorithmic.
  `freeze_build.lua` records each part buffer's planting (the buffer when the
  part first planted, the stems with their `dressing` planter, height and the
  buffer's tree spacing, the undergrowth call, the cells planting wrote and
  the writes after it) and `export_capitals.lua` cuts such a part as the
  cells before planting, the stems as `trees` points, `plant_spacing` and
  `undergrowth` meta and the writes after planting as `late` entries; a part
  whose planting is not "cells, trees, undergrowth, late" is refused. Read
  back through the game's loader, a planted placement must be exactly its
  generator's part, trees and all. The freeze's templates stay the
  templates: a planted template's identity is its whole generated part (so
  Lethariel's groves do not merge with Highcourt's quiet grove), and its
  users must agree on the planted form but for the stems' `height=`, which
  the tree generator does not read (Nhal Veyr's vigil copse shares the market
  copse's heights 6 for its own 7; the report says so). No start town plants
  (`export.lua` refuses a planting stamp). The planted templates were re-cut
  and `BASELINE` moved to that commit with the lane brief as the
  coordinator's approval (format doc §6.2).
- `check.py` is the validator of format doc §6 and the gate (it reads
  `late` entries, part of an entry's identity, refuses a race switch or an
  `else=` naming a `late` entry, holds every `trees` stem to written ground
  that is not air and warns, rule `stem_soil`, when that ground is not wild
  soil for a placing race, where no tree grows): `check.py`
  (against `BASELINE`), `check.py --baseline=self` (the freeze),
  `--write-known-defects` (the exporter's known-defects baseline, empty
  since Round 62), `--self-test` (the parser and
  every rule on mutated copies of a frozen template, the loader parity and the
  roster cases). It reads the palettes and the param2 rules from the game's
  Lua through `palette_dump.lua` (LuaJIT), the registry from `nodes.json`, and
  runs the game's own loader through `loader_check.lua`: a file the game
  refuses is an error (rule `loader`), every start town and capital is built
  from the files (rule `build`; skipped with a warning in a checkout without
  `wp40`, the editor's test clones) and each roster's counts must equal what
  the capital's code places (rule `roster`). The editor imports
  `validate(root, baseline, replaced, builds=True)` (the build adds about
  five seconds).
- `editor_palette.txt`: the editor palette (format doc §7), written from the
  rules and the registry; lane EDITOR added `role door_hidden` (the door's
  upper cell, which the editor places with the door; without it every new
  door would fail the palette rule) and removed the rooted water plants
  (`default:coral_cyan`, `_green`, `_pink`, `default:sand_with_kelp`; the
  plain coral blocks stay).
- `town_identity.lua <repo> [<tree>] [--load]`: what the towns build, per
  start town the settlement identity and the point digest (and with `--load`
  the construction time and the allocation), per capital its identity
  digest (the settlement identities of its core and plots), cells, point
  digest, build digest and blueprint count (and with `--load` its numbers). `tools/check_upgrade.py` runs it on the pushed commit and on
  the working tree and wants a map reset when they differ.

## The editor (`editor/`, lane EDITOR, Round 56)

A local tool for editing the town buildings (Round 56 rulings 25–31). Start
it by hand from the repository root and open the address it prints:

```sh
python3 tools/building_templates/editor/serve.py            # http://127.0.0.1:8756/
python3 tools/building_templates/editor/serve.py --port 9000
```

It needs Python 3 with Pillow (textures), LuaJIT and git, as the gallery and
the validator do, and the browser fetches three.js 0.160.0 from the CDN. It
starts in well under a second; Ctrl+C stops it.

**What it may do.** The server listens on 127.0.0.1 only and answers only
requests addressed to `127.0.0.1` or `localhost` (no other host name, no
cross-origin request, JSON only). It reads the templates, layouts and rosters
of this working tree and writes **only existing template files** in
`mods/MAPGEN/grug_mapgen/building_templates/templates/`, and only on Save. It
never creates, renames or deletes a file and never runs a git command that
writes: its one git use is `git show HEAD:<template>` for the "changed since
commit" highlight. Drafts stay in the browser's local storage.

**The page.** The template list (by town, with "used N× in …"), then one
template: the 3D view (the shared `viewer/renderer.js`: orbit, walk, noclip)
beside the layer grid (north up, the template's own frame; the town turns
it).
- Layers: the buttons, ▲/▼, PageUp/PageDown or the mouse wheel over the grid.
  In 3D the layers above the current one are drawn transparent, hidden or
  shown; the current layer is outlined and its force-air (blue) and
  leave-unchanged (amber) cells are marked.
- The footprint (pivot) is dashed; the **street side** (the footprint side of
  an entrance door point) is an amber edge with an arrow into the door, in the
  grid and in 3D, with the template frame's +x and +z axes.
- **Preview:** each placement's palettes ("As placed", the default) or a plain
  race palette; roles are drawn in that material.
- **Tools** (keys 1–6): Paint (drag to paint), Pick (or Alt+click), Air (force
  air), Unchanged (leave unchanged), Rotate (90°, only where the node's kind
  allows it in every placing palette: facedir 0–3 keeping an upside-down
  axis, wallmounted only around the four walls, never onto the floor or the
  ceiling), Flip (no key; only where the result is valid in every placing
  palette, as for Rotate), Move point. A
  click in the 3D view applies the tool to the block under the pointer (a
  point moves onto it).
- **Flip** turns a stair or a slab upside down and back, keeping its look:
  facedir 0↔20, 1↔23, 2↔22, 3↔21 (the axis 20 rotation runs the other way,
  as the stairs mod writes it), and for an inner or outer stair 0↔21, 1↔20,
  2↔23, 3↔22 (its raised quarter stays over the same quarter of the cell).
  Upside down is offered only when every placing palette whose node is
  facedir names a stair or a slab of the same shape (`parts.shaped`). A
  wallmounted node goes wall → floor (1) → ceiling (0) → wall: always the
  wall of `wallmounted:2` (support at +x), Rotate turns it on from there. A
  wallmounted node keeps its node: a wall torch flipped onto the floor stays
  `light_wall`, not `light_post`. Doors, beds, lying tree pieces and nodes
  without orientation are refused. Rotating an upside-down stair keeps it
  upside down.
- **Items:** the roles first (with a corner mark, in the preview's material;
  a required role a placing race does not bind, or an optional one no
  placing race binds, is disabled), the role variants with a channel the template uses
  (`roof_stair · roof palette`), then the editor palette's groups, with a
  search. `R` or ↻ turns the item before painting. A fixed node in a template
  several races place asks first (ruling 22). Nodes whose boxes reach into a
  neighbouring cell are marked in the list.
- **Optional roles** are stored with their fallback (ruling 22): painting one
  reuses the template's own legend entry for that role (same variant, channel
  and orientation) and otherwise writes `else=air`; it never adds a second
  entry that differs only by `else=`.
- **Multi-cell objects** (format doc §5): a door takes its cell and the one
  above (locked: only emptying, turning or picking it acts there, on the whole
  door), a bed its cell and the next along its facing. They are placed only
  where their other cells are free (force air or leave unchanged) and inside
  the box; painting over or emptying one part removes the whole object.
- **Points** (the list under the grid, or click a marker with Move point):
  move only; the group, order, face and attributes never change (ruling 28).
  A planted template's stems are `trees` points like any other (moved on
  its ground layer); its trees and undergrowth are not drawn (the game grows
  them at load), and a cell picked from a `late` entry is painted `late`.
- **Undo, redo** (Ctrl+Z, Ctrl+Y), **Reset** (back to the saved file), the
  "changed since commit" outline (cells whose legend entry differs from the
  file at HEAD) and a draft in local storage, offered again after a crash or
  reload when the file has not changed since.
- **Save** runs the validator first (`check.validate`, imported, against
  `BASELINE`, the known defects as warnings, every town and capital built
  through the game's loader, a few seconds; the page is busy meanwhile): an
  error of this template, or a build, roster or loader error of a town or
  capital that places it, refuses the save and is listed with its cell (red
  in the grid and in 3D) or its town; a build error of a town that does not
  place the template (broken before the edit) is a warning;
  warnings need a confirmation, and the dialog says "used N× in …" (a
  template several placements use changes all of them). **Check** runs the
  validator without saving.

**The writer** (`editor/tplfile.py`): the page sends cells, legend entries and
point positions; the server takes the header, the box, the pivot and every
point's group, face and attributes from the file on disk, writes the file in
the canonical layout the freeze exporter writes (unused legend entries
dropped, keys kept) and replaces it atomically (a temp file in the same
directory, fsync, rename). Every frozen template is canonical, so an unedited
save writes identical bytes; a file that is not canonical is reported when it
opens, never rewritten then. New legend entries get the next free key in the
exporter's order; a legend that outgrows single characters becomes `cell 2`.

Files: `serve.py` (the server and the save gate), `tplfile.py` (model and
writer), `model.js` (the edit rules and the stamp's resolution, no page code),
`editor.js` and `editor.html` (the page). Tests: `tools/r56_editor/`
(`test_editor.py`: the server, the writer's round trip on every template, the
save gate, path confinement; `gui_run.py`: the GUI checklist path in a
headless Chromium with screenshots). Both work on a disposable shared clone,
never on the working tree.
