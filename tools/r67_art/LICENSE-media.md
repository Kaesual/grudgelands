# Round 67 ART — media provenance

## Original candidates

All 44 files in `candidates/` are original pixel geometry authored for
Grudgelands by GPT-6 Astra on 2026-10-30. They are drawn entirely by
`generate.py` with Pillow and numpy: no source image pixels, external
images, generated bitmap sources or fonts enter a candidate.

The project dedicates any rights it holds in these original images to
**CC0-1.0**, to the extent such rights exist. The generator is
**GPL-3.0-or-later**, following the repository code licence.

| Files | Count | Construction |
|---|---:|---|
| `race_{human,dwarf,elf,orc,troll,undead}_{a,b}.png` | 12 | Original 32px pixel drawings, exported at 64px with nearest-neighbour sampling. |
| `chest_{steel,abyssal}_{top,side,front,lock,inside}_{a,b}.png` | 20 | Original wood grain, metal panels, straps, hardware and dark lining. |
| `{bookshelf,vessels,shelf_side}_{steel,abyssal}_{a,b}.png` | 12 | Original frames, books, bottles and matching side/top panels. |

Identically named files in `preview/` are byte-identical copies of the
candidates. Their projected candidate views use the original candidate
textures. The open views also use the existing chest geometry; that
geometry retains its existing licence.

## Comparison assets

The following are **review-only** references, not new distributable
candidates. The original files are copied byte for byte unless otherwise
stated. Their existing attribution and licence records remain authoritative:

| Preview files | Source and existing attribution |
|---|---|
| `ref_class_*.png` | `mods/PLAYER/grug_classes/textures/grug_class_*.png`; [class media ledger](../../mods/PLAYER/grug_classes/LICENSE-media.md), CC0-1.0. |
| `ref_faction_*.png` | `mods/PLAYER/grug_inventory/textures/grug_inventory_faction_*.png`; [inventory media ledger](../../mods/PLAYER/grug_inventory/LICENSE-media.md), CC0-1.0. |
| `ref_wood_chest_*.png`, `ref_wood_bookshelf.png`, `ref_wood_shelf_side.png`, `ref_steel_bar_base.png` | `mods/BASE/default/textures/default_chest_*.png`, `default_bookshelf.png`, `default_wood.png`, `default_steel_ingot.png`; [source attribution](../../mods/BASE/default/README.txt) and [licence](../../mods/BASE/default/license.txt). |
| `ref_wood_vessels.png` | `mods/BASE/vessels/textures/vessels_shelf.png`; [source attribution](../../mods/BASE/vessels/README.txt) and [licence](../../mods/BASE/vessels/license.txt). |
| `ref_abyssal_pick.png` | `mods/ITEMS/grug_materials/textures/grug_materials_tool_abyssal_steelpick.png`; [material media ledger](../../mods/ITEMS/grug_materials/LICENSE-media.md). |
| `ref_steel_bar.png`, `ref_abyssal_bar.png` | Offline colour blends of `default_steel_ingot.png`, following the material colours in `grug_materials/ores.lua`; retain the source image licence. They are labelled approximations, not engine captures. |
| `view_wood_*.png` | Projected views of the existing wooden textures above; retain the source texture licences. |
| `view_*_open*.png` | Projection of `mods/BASE/default/models/chest_open.obj`; [model attribution](../../mods/BASE/default/README.txt) and [licence](../../mods/BASE/default/license.txt). |
| `race_contact.png`, `container_contact.png` | Review compilations; reference images retain the licences above. |

The palette and format were inspected against local assets. The race
colours follow `mods/PLAYER/grug_visuals/looks.lua`; material hues follow
the steel and abyssal bar definitions and the existing abyssal tools.
These references supply palette and presentation context, not candidate
image data. Integration lanes should copy only the selected candidates
and add their CC0 provenance to the receiving mod's media ledger.
