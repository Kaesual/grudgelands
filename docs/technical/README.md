# Technical references

Contracts, formats and implementation seams. The question-by-question entry
point is [the documentation guide](../README.md); the
[module guide](module-guide.md) holds the seams and pitfalls per area, the
[mod map](mod-map.md) the ownership of each concern.

## Authoritative records kept in docs/research

These research records are cited as the current reference by live docs or
code comments. They stay at their paths because mod comments, tools or
frozen digest keys name them; treat them as technical references.

| Record | What it is the reference for | Why it stays |
|---|---|---|
| [wp40-simple-map-r6-contract.md](../research/wp40-simple-map-r6-contract.md) | the exact R6 content contract of the named-zone map | frozen digest key in `wp40/r6_content.lua` and `r7_r6_manifest.lua`; do not edit |
| [wp40-completion.md](../research/wp40-completion.md) | the accepted WP40 world foundation (2026-09-13); superseded for the supply checks by Round 22 D1/D5 | cited by the module guide and BACKLOG; links into its sibling WP40 records |
| [wp6_spawn_budget.md](../research/wp6_spawn_budget.md) | per-biome active object sums and the spawn density math behind `biomes_mobs.md` §4 | cited in seven `grug_mobs` files and `minetest.conf` |
| [perf-review-2026-10.md](../research/perf-review-2026-10.md) | the Round 29 performance review: findings, probes, method | cited by AGENTS.md, `spawn_regions.md` and a `grug_mobs` comment |
| [wp13-npc-sockets-contract.md](../research/wp13-npc-sockets-contract.md) | settlement sockets between the town structures and the NPCs | cited in 16 mod files, a tool and `settlements.md` |
| [wp13-character-visuals-contract.md](../research/wp13-character-visuals-contract.md) | one compose function for player and humanoid appearance | cited in four mod files, `character_visuals.md`, `settlements.md` |
| [hud-bars.md](../research/hud-bars.md) | the bottom-centre HUD column as shipped | cited in `grug_core/hud_layout.lua`, `grug_abilities/init.lua`, `classes.md` |
| [mob-pressure.md](../research/mob-pressure.md) | mob pressure as shipped (movement aggregator, attack cadence, ranged family) and its punch-rate probe | cited by `combat_stats.md`; pairs with its task card |
| [mapgen-chunk-profile-2026-10.md](../research/mapgen-chunk-profile-2026-10.md) | Lua time per R7 mapgen stage and chunk type, the WP48 levers | linked from tool READMEs, the module guide and BACKLOG |
