# Breach Road · Second pass

[Open the offline pick page](index.html) · [Matched before/after views](renders/overview.png) · [Builder’s plan and section](renders/breach_plan.png)

1. **Height.** The through-road is at **0**, the broken arcade at **+3**, both hall floors and lookout spurs at **+6**. Twelve five-wide sandstone-brick flights have half-node treads. Each gate has a direct stair route to the road. A flank stair and a level approach reach each lookout. Mirrored eye-to-eye sightlines from the spurs to the road measure 23.5–26.2 nodes. The stair geometry follows [The Stilled Seam](../../mods/PLAYER/grug_expeditions/templates/stilled_seam.exp) and the [Expedition relief rules](../../docs/technical/expedition-template-format.md).
2. **Footprint.** Two opposed wings and narrow road mouths occupy **6,957 columns inside 99 × 91 nodes**. Broken breastworks shelter the high ground. Fallen wall footings cover the rear approaches. Both halls keep their screened bronze sills, muster space and emberglass waystone marker. Gates stand 44 nodes apart.
3. **Smoke.** Two cold hearths send smoke past the piers. The stills freeze the same effect that moves in 3D. Coordinates are node centres, +x east, +z north, road surface node y=0.

| Hearth (x, y, z) | Puffs/s | Life | Width, nodes | Mean drift (x, y, z), nodes/s |
|---|---:|---:|---:|---|
| East (+7, +0.75, +16) | 2 | 5.5 s | 0.9 → 3.4 | (+0.55, +2.2, +0.15) |
| West (−7, +0.75, −16) | 2 | 5.5 s | 0.9 → 3.4 | (+0.55, +2.2, +0.15) |

Use one shared pair, one puff every 0.5 s per hearth, **22 live maximum**. Horizontal drift varies by up to 0.091 nodes/s per axis. The shipped `default_item_smoke.png` takes tint `#b9b4ae` and fades from 64% opacity. [Effect recipe](smoke.py) · [Shipped particle helper](../../mods/CORE/grug_core/particles.lua)

4. **Dressing.** Two broken apple trunks on the woodland fringe and two groups of excavated basalt on the clay side mark the rear paths below the standards.
5. **Palette.** The 11-seed SITE study places the footprint across zones 35 and 36. The seed selects local biome patches. Green grass really occurs in zone 35. The first pass’s moss soil belongs to elf forest. The draft illustrates deep forest west and badlands east. The builder should retain each column’s local surface at the six-node fringe. [Zone shares](../../mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua) · [Border selector](../../mods/MAPGEN/grug_mapgen/wp40/zones.lua) · [Surface rules](../../docs/design/world_zones.md)

| Zone | Biomes and native materials |
|---|---|
| 35 · The Broken Causeway | Meadows 40%, deep forest 25%, swamp 35%. Grass, dirt, litter, apple trees and aspen. Ferns, wet grass and stilt trees on swamp mud. Desert stone beneath meadow and forest, mossy cobble beneath swamp. |
| 36 · The Shattered Line | Badlands 65%, savanna 20%, swamp 15%. Mesa clay, dry dirt, shrubs and cactus over basalt. Dry grass and acacia over sandstone in savanna. |

[Soils](../../mods/MAPGEN/grug_mapgen/wp40/r6_content.lua) · [Stone](../../mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua) · [Plant and tree catalogue](../../mods/MAPGEN/grug_mapgen/wp40/r7_r6_manifest.lua) · [All 25 shipped node IDs](nodes.json)

**Terrain handoff.** The fringe absorbs ±3 nodes. Use a common road datum for both halls. Beyond that allowance, cut the uphill bank and extend downhill retaining walls to solid ground. Across 21–139 nodes of relief, acceptable earthworks, lake treatment and a spur where the road misses remain Round 85 decisions. Guard positions, mounts indoors and hostile-spawn limits remain open.

**Compatible, tools only.** `python3 tools/r84_arena_draft/build.py --check` passed, reproducing templates, plates and page. Firefox passed 17 offline interaction checks with Canvas. Hardware WebGL and in-game riding remain unverified. Grep found no fixture reading the changed documents. No Lua fixture or engine ran.

Final design commit `e01ad5e2da8f33520b505ff2936b7c34f8087e00`. Resolve the final report commit with `git log -1 --format=%H -- tools/r84_arena_draft/REPORT.md`. The lane handoff records its hash and the empty `git status --porcelain` result.
