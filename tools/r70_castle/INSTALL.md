# Round 70 CASTLE — CAPITALS handoff

**User pick, 2026-11-07: A — Crownward, pass 3.** B and C remain proposal
records. This lane is **compatible, tools only**; installing the castle is
CAPITALS work under Round 70's **map reset**.

## Files and palette bindings

Take only the six templates in [candidates/crownward/](candidates/crownward/).
Install them under `mods/MAPGEN/grug_mapgen/building_templates/templates/`
using the existing hall names below; change each template's `name` header
to match its destination filename. This preserves the existing caller ids.
Keep the roster's existing palette definitions. [palettes.json](palettes.json)
records the exact overrides applied over each race's `wp13/palette.lua` base;
it is a tooling reference, not a runtime file to copy.

| Picked source | Destination `.tpl` stem | Main binding | Roof binding |
|---|---|---|---|
| `castle_dwarf.tpl` | `dur_brannoc_kings_hall` | `slate` | `slate` |
| `castle_human.tpl` | `highcourt_kings_hall` | `white_slate` | `white_slate` |
| `castle_elf.tpl` | `lethariel_kings_hall` | `pale` | `pale` |
| `castle_orc.tpl` | `gor_drazhak_warlord_hall` | `ors` | `ors` |
| `castle_undead.tpl` | `nhal_veyr_mausoleum` | `crypt` | `crypt_vault` |
| `castle_troll.tpl` | `kezamba_kings_hall` | `basalt` | `basalt` |

Replace the corresponding `use` line in each capital's `layouts/*.roster`:

```text
use dur_brannoc_kings_hall count=1 main=slate roof=slate
use highcourt_kings_hall count=1 main=white_slate roof=white_slate
use lethariel_kings_hall count=1 main=pale roof=pale
use gor_drazhak_warlord_hall count=1 main=ors roof=ors
use nhal_veyr_mausoleum count=1 main=crypt roof=crypt_vault
use kezamba_kings_hall count=1 main=basalt roof=basalt
```

The new templates use exactly one named channel, **`roof`**. Gor Drazhak's
old `town=town` channel goes away. The actual placement bindings in the six
`wp13/<capital>.lua` builders must agree with these roster lines. CAPITALS
owns the new core anchors and surrounding layouts.

No new CASTLE nodes/textures: existing bronze blocks and bottom slabs frame
the throne; `rug_accent` provides its cloth. Install GUILD's five selected
full blocks first: `grug_guild:ornamented_iron`, `ornamented_steel`,
`ornamented_silversteel`, `ornamented_embersteel`, `ornamented_abyssal_steel`.
Their texture handoff is [ART's INSTALL](../r70_art/INSTALL.md).
[preview_nodes.json](preview_nodes.json) is only for the preview, not a mod.

## Remaining integration gate

The supplied `~/projects/grudgelands-orchestration/r70/reports/castle-check.md`
checked pass 1 (`b20cee75`). Its remaining integration requests, verified
against `tools/building_templates/check.py`, are:

- Install the five GUILD nodes and refresh
  `tools/building_templates/nodes.json` and `editor_palette.txt`; otherwise
  `known_node` / `edit_palette` fail. Explicit air already uses `.`.
- Account for the deliberate box and point changes against the old hall
  baseline: `box_baseline` and `point_baseline` remain until the coordinator
  advances `building_templates/BASELINE` to the approved installation commit
  under the [format's baseline procedure](../../docs/technical/building-template-format.md#62-hard-only-for-edited-cells-content).
  `--baseline=self` alone does not complete the normal gate.
- Supply the exact `roof=` bindings above, matching code placements, and
  finish the capital layouts. The gate loads and builds every town/capital
  and checks actual uses against roster counts; copying templates alone is
  insufficient.

Then run `python3 tools/building_templates/check.py`, `--self-test`, and the
viewer/editor topic checks required by AGENTS.md. CASTLE's builder/verifier
pass on the standalone candidates; they do not certify installed layouts,
runtime paths or combat. The [report](REPORT.md) retains the GUI checklist.

## Geometry and sockets

Pivot **45 × 35**, origin **(0,0,0)**, box **45 × 34 × 35** (x/y/z), peak 33.
All unused cells force air. Throne **5 × 3 × 7** (width/depth/height),
x 20…24, z 28…30, y 5…11; seat **3 × 2** at y 6. Dais remains **15 × 7**,
x 15…29, z 25…31. The ornaments span x 20…24 at (y 10,z 30), in the metal
order above. King body clearance before the chair is **0.02 node**, verified
with its final 0.96-wide, 2.72-high box; keep the socket and chair aligned.

Turn 0: +x east, +z north. Socket ids, order, faces, roles and tags are unchanged.

| Socket | x | y | z | Face | Role / tags |
|---|---:|---:|---:|---:|---|
| `king` | 22 | 5 | 27 | 2 | king |
| `throne_guard_west` | 19 | 5 | 27 | 2 | guard_post |
| `throne_guard_east` | 25 | 5 | 27 | 2 | guard_post |
| `door_guard_west` | 18 | 3 | 4 | 0 | guard_post |
| `door_guard_east` | 26 | 3 | 4 | 0 | guard_post |
| `hall_waypoint` | 22 | 3 | 6 | 0 | waypoint |
| `hall_idle_west` | 7 | 3 | 17 | 1 | idle, `[bench]` |
| `hall_idle_east` | 37 | 3 | 17 | 3 | idle, `[bench]` |
| `hall_idle_service` | 7 | 3 | 23 | 3 | idle, `[door]` |

Entrance points: approach `(22,1,0)` face 2; hall arch `(22,3,8)` face 2;
west service `(4,3,20)` face 3; east service `(40,3,20)` face 1.
The `inside` point is `(22,3,12)`. These are open arches, with no door leaves.
Use native `parts.stamp`: turn maps are `(x,z)`, `(z,44−x)`, `(44−x,34−z)`,
`(34−z,x)`; face gains turns modulo 4. Odd turns occupy 35 × 45;
Kezamba faces north with turn 2. Add the final CAPITALS placement anchor.
