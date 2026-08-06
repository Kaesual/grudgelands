# Research: Biome & Flora Assets (Trees, Plants, Terrain Nodes)

Status: 2026-08-06 · Scope: reusable NODES / TREE SCHEMATICS / DECORATIONS for our 6
race regions. We compose our own mapgen; we only harvest content. All licenses below
were verified on ContentDB (package pages / API). Project code: GPLv3+.

## Summary

Coverage is excellent. **Ethereal NG** (MIT code, CC BY-SA 3.0 media) alone can seed 5
of 6 regions and keeps its trees as separable Lua schematics. **Everness** (LGPL-2.1+
code, CC BY-SA 4.0 media) is the only strong source for the Undead "Cursed Lands"
look plus a baobab savanna. Wilhelmine's **naturalbiomes** and **livingjungle** are
MIT code *and* MIT media — the most permissive full-biome sources (savanna, alpine,
swamp, jungle). **ebiomes** (GPL-3.0+ / CC BY-SA 3.0) deliberately matches vanilla MTG
16px style — ideal glue content. No candidate has NC/ND or GPLv2-only problems; the
main risks are *style mixing* (Ethereal ships inconsistent 16px/32px textures) and the
copyleft media licenses (CC BY-SA) requiring per-file attribution + share-alike.

## Region Coverage Matrix

| Region (race) | Primary source | Secondary / fill |
|---|---|---|
| Plains/Meadows (Humans) | MTG base + ethereal (prairie, grassy, orange/birch trees) | plantlife (sunflowers, bushes, ferns), ebiomes grasslands |
| Mountains/Hills (Dwarves) | ethereal (alpine, grove, frost pine, redwood) | naturalbiomes alpine, moretrees (cedar, fir, sequoia via L-system) |
| Forests (Elves) | ebiomes (deciduous, maple/oak) + moretrees (beech, birch, oak) | ethereal sakura + "magical forest" for high-elf flair, plantlife ferns/vines |
| Savanna/Badlands (Orcs) | naturalbiomes (wet savanna, outback, bushland) | ethereal (savannah, mesa) + everness Baobab Savanna; MTG bakedclay-style mesa nodes |
| Jungle/Swamp (Trolls) | livingjungle (mangrove, lianas, rafflesia) | ethereal (jungle, swamp, mangrove), Atlante swamp (mud, mangrove), everness bamboo |
| Dark forest/Blight (Undead) | everness (Cursed Lands, Forsaken Desert nodes) | dfcaverns fungal flora (tower caps — surface-adapt), ethereal mushroom biome; retextured willows |

## Candidates

| Mod | Author | Code | Media | Maintenance | Notes |
|---|---|---|---|---|---|
| [ethereal](https://content.luanti.org/packages/TenPlus1/ethereal/) | TenPlus1 | MIT | CC BY-SA 3.0 | Active (2026) | ~30 biomes, 15+ tree types; schematics are separable Lua tables in `schematics/`. Deps: default, flowers. ⚠ Mixed 16px/32px textures — cherry-pick and normalize. |
| [everness](https://content.luanti.org/packages/SaKeL/everness/) | SaKeL | LGPL-2.1-or-later | CC BY-SA 4.0 | Active (2025) | Cursed Lands, Crystal/Coral Forest, Baobab Savanna, Forsaken Desert/Tundra; .mts schematics in `schematics/`, no hard deps. Strong distinctive style — verify px scale against our base on import. |
| [naturalbiomes](https://content.luanti.org/packages/Liil/naturalbiomes/) | Liil (Wilhelmine) | MIT | **MIT** | Stale (2022) | 9 biomes: wet savanna, outback, alpine, alder swamp, bamboo, mediterranean, heath, bushland. Most permissive media. Deps: default, doors, stairs, xpanes (trim on import). Repo: github.com/Skandarella/naturalbiomes |
| [livingjungle](https://content.luanti.org/packages/mt-mods/livingjungle/) | Wilhelmine / mt-mods | MIT | **MIT** | Maintenance-only (2022) | Dense jungle: mangroves, lianas, rafflesia, jungle building blocks. Deps: default, doors, stairs. Perf-heavy as-shipped; fine when we register decorations ourselves. |
| [ebiomes](https://content.luanti.org/packages/CowboyLv/ebiomes/) | CowboyLv | GPL-3.0-or-later | CC BY-SA 3.0 | Active (2026) | Deciduous forests (maple, oak), steppes, dry/warm grassland, swamp+bog, humid/jungle savanna, mediterranean. Explicitly styled to match vanilla MTG 16px — best style fit. Deps: default, dye, stairs. |
| [moretrees](https://content.luanti.org/packages/VanessaE/moretrees/) | VanessaE / mt-mods | LGPL-3.0-only | CC BY-SA 4.0 | Low activity | 13+ trees (beech, cedar, fir, sequoia, oak, willow, palm…). Mostly L-system tree defs, not .mts — reusable via `minetest.spawn_tree()` / bake to .mts ourselves. Dep: xcompat. LGPL-3.0-only is GPLv3-compatible. |
| [plantlife_modpack](https://content.luanti.org/packages/VanessaE/plantlife_modpack/) | VanessaE / mt-mods | LGPL-3.0-only | CC BY-SA 4.0 | Low activity | Ground cover: ferns, bushes, vines, waterlilies, seaweed, fallen trunks, mushrooms, poison ivy. ⚠ Hard dep on `biome_lib` (its own spawner) — extract node defs + textures, re-register as plain decorations. |
| [swamp](https://content.luanti.org/packages/Atlante/swamp/) | Atlante | LGPL-2.1-or-later | CC BY-SA 3.0 | Stale (2023) | Compact swamp: mangrove trees, mud nodes. Small, easy to strip for the Troll region. |
| [dfcaverns](https://content.luanti.org/packages/FaceDeer/dfcaverns/) | FaceDeer | MIT | MIT | Repo active; CDB listing old | Giant fungi (tower caps, spore trees), gloomy flora — great raw material for surface "blight" after retint. Underground-oriented; take nodes/schematics only. |
| [asuna](https://content.luanti.org/packages/EmptyStar/asuna/) (game) | EmptyStar | GPL-3.0-only | CC BY-SA 4.0 | Active (2025) | Curated bundle of the above (everness, ethereal, naturalbiomes, livingjungle, marinara, caverealms). Useful as *reference* for tuned biome/decoration params. ⚠ GPL-3.0-only code: compatible with GPLv3+, but any copied code pins the combination to GPLv3 — prefer upstream mods directly. |

## Notes

- **Schematic separability:** ethereal (Lua schematics) and everness (.mts) are trivially
  separable; naturalbiomes/livingjungle register schematics + decorations in plain
  `minetest.register_decoration` calls — easy to lift. moretrees needs L-system replay
  or baking to .mts. plantlife needs decoupling from biome_lib.
- **Style:** target 16px MTG look. ebiomes/naturalbiomes/livingjungle fit natively;
  ethereal needs per-texture curation (⚠ mixed resolutions); everness is stylistically
  bold — best kept concentrated in the Undead region where "different" reads as intent.
- **License hygiene:** no NC/ND, no GPLv2-only found. CC BY-SA media (ethereal,
  everness, ebiomes, moretrees, plantlife, swamp) ⇒ our derived/retinted textures stay
  CC BY-SA; document per-file in a media ATTRIBUTION table. MIT media (naturalbiomes,
  livingjungle, dfcaverns) can be relicensed/edited freely with attribution.
- **Priority:** 1) ethereal + ebiomes as broad base, 2) everness for Undead, 3)
  naturalbiomes + livingjungle for Orc/Troll, 4) plantlife ground cover pass,
  5) moretrees/dfcaverns/swamp as cherry-picks.
