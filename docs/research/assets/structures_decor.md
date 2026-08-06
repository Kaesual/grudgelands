# Research: Structures, Schematics & Decoration

Topic: building material for faction capitals, military outposts, race villages,
plus props/flair and faction banners. Target: GPLv3+ game; media reuse only under
GPL-family / LGPL / MIT / Apache / CC0 / CC BY / CC BY-SA.

## Summary

The **castle_* suite by FaceDeer** (MIT code+media, minetest-mods org) is the single
best source for capital/outpost building blocks: masonry walls, arrowslits,
murder holes, gates/portcullis, medieval lighting, tapestries and wall shields —
exactly WoW-keep flair. **cottages** (Sokomine) and **darkage** cover village-tier
roofs/furniture and pre-industrial nodes. For faction banners, the
**pandorabox banners fork** (layered heraldic designs, GPLv3/CC0) plus the simple
CC0 **Banners** mod cover both custom crests and mass-produced flags. Ready-made
building schematics come from **mg_villages** (GPLv3 .mts houses per village type),
and its sister lib **handle_schematics** is the reference for mapgen placement
code (rotation, material substitution, ground level detection). Props:
**xdecor-libre** (permissive, light) first, **homedecor** (heavy) selectively.

No GPLv2-only blockers among the top picks. Main integration cost everywhere:
node names reference `default:*` from Minetest Game — we must remap materials
and prune crafting recipes for a from-scratch game.

## Candidates

| Mod / Pack | Author | Code / Media | Harvestable | Deps on MTG | Maint. | Prio |
|---|---|---|---|---|---|---|
| [castle_masonry](https://content.luanti.org/packages/FaceDeer/castle_masonry/) | FaceDeer | MIT / MIT | Node set: walls, pillars, arrowslits, embrasures, machicolations, roof slate, paving | Medium (material list uses `default` nodes; mask-overlay textures easy to retarget) | Stable, low activity | **1** |
| [castle_gates](https://content.luanti.org/packages/FaceDeer/castle_gates/) | FaceDeer | MIT / MIT | Swinging/sliding gate system, portcullis, dungeon doors + gate code | Low | Stable | **1** |
| [castle_lighting](https://content.luanti.org/packages/FaceDeer/castle_lighting/) | FaceDeer | MIT / MIT | Braziers, chandeliers, candles — capital lighting | Low | Stable | **1** |
| [castle_tapestries](https://content.luanti.org/packages/FaceDeer/castle_tapestries/) | FaceDeer | MIT / MIT | Colorable tapestries in 3 lengths — faction-color hall decor | Low | Stable | **1** |
| castle_shields / castle_storage / castle_weapons | FaceDeer | MIT / MIT | Decorative wall shields (heraldry!), crates/barrels, weapon props | Low | Stable | 2 |
| [banners (pandorabox fork)](https://github.com/pandorabox-io/banners) | shamoanjac / pandorabox-io | GPL-3.0 / CC0 | Layered heraldic banner designs, banner items — ideal for 6 faction crests | Low | Fork of abandoned repo, minimal activity — plan to vendor & own | **1** |
| [Banners](https://content.luanti.org/packages/Anonymous_moose/banner/) | Anonymous_moose | CC0 / CC0 | Simple wool-color banners + loom mechanic, banner hangers | Low (wool) | Low activity; CC0 = harvest freely | 2 |
| [cottages](https://content.luanti.org/packages/Sokomine/cottages/) | Sokomine | GPL-3.0-only / CC-BY-SA-3.0 | Village-tier: straw/slate/reed roofs, shutters, simple beds/tables/benches, anvil | Low-Medium | Maintained, active tracker | **1** |
| [darkage](https://content.luanti.org/packages/addi/darkage/) | addi (adrido) | MIT / CC0 | Pre-industrial nodes: basalt, chalk, mud, reinforced wood, round glass — village/undead texture variety | Medium | Maintained | 2 |
| [mg_villages](https://content.luanti.org/packages/Sokomine/mg_villages/) | Sokomine | GPL-3.0-only / GPL-3.0-only | **Ready .mts building schematics** (several village/house types) + village layout logic | High (schematics reference MTG nodes → needs `replacements`) | Last real update 2020 | 2 (schematics), code as reference |
| [handle_schematics](https://content.luanti.org/packages/Sokomine/handle_schematics/) | Sokomine | GPL-3.0-only / — | **Placement code patterns**: mapgen placement, rotation, material substitution, metadata restore | None (library) | Stable since 2020 | **1** (as reference/vendored lib) |
| [schemedit](https://content.luanti.org/packages/Wuzzy/schemedit/) | Wuzzy | (libre) | Dev tool to create/edit our own .mts schematics — toolchain, not shipped | — | Maintained | **1** (workflow) |
| [xdecor-libre](https://content.luanti.org/packages/Wuzzy/xdecor/) | Wuzzy | BSD-3-Clause / CC-BY-4.0 | Light props: item frames, candles, lamps, doors, workbench, chess, cauldron | Medium | Maintenance-only, reliable | **1** |
| [homedecor_modpack](https://content.luanti.org/packages/VanessaE/homedecor_modpack/) | mt-mods | LGPL-3.0-only / CC-BY-SA-4.0 | Huge prop pool (sofas, tables, fences, exterior); cherry-pick only | High (33 submods, basic_materials, signs_lib) | Actively maintained | 3 (selective harvest) |
| [dfcaverns](https://content.luanti.org/packages/FaceDeer/dfcaverns/) | FaceDeer | MIT / MIT | Underground flora/decor — Undead/Troll zone flair only | Low | Actively developed | 3 (optional) |
| My Castle / Castles++ / Cracked Castle | Don / philipbenr / pampogokiraly | verify per-mod | Overlaps castle_* suite; Cracked Castle useful for Undead ruins look | ? | Low | 4 |

## Notes

- **License compatibility:** GPL-3.0-only (Sokomine mods, banners fork) combines fine
  with our GPLv3+ code — the combined work is distributed as GPLv3. No NC/ND found.
  ⚠ No GPLv2-only among top picks; re-verify per-file when vendoring (older mods
  sometimes contain WTFPL/unclear textures — check `license.txt` per texture).
- ⚠ Anonymous_moose Banners has **no public repo** on ContentDB — download the
  release zip and archive it in-repo with attribution.
- **Placement pattern:** core `minetest.place_schematic_on_vmanip()` inside
  `register_on_generated` + deferred `minetest.place_schematic` for structures
  crossing mapblock borders; handle_schematics shows production-grade handling of
  rotation, `replacements` tables (material palette per race!) and terrain fitting.
  The `replacements` idea maps 1 schematic → 6 race skins (stone→obsidian for Orcs etc.).
- **Faction banners plan:** vendor pandorabox banners' layered-texture approach
  (`[combine`/overlay masks), pre-bake 6 static faction crest nodes first; player
  heraldry later.
- **Strategy:** don't depend on any of these mods at runtime — vendor node
  definitions + textures into our own `wob_*` mods with per-file attribution
  (media licenses permit this), keeping zero `default` dependency.
