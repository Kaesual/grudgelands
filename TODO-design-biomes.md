# TODO — Biome & Mob Catalog

Framework decided 2026-08-06 (world.md §8: ring model — settled race
biomes in core/inner ring, shared nature biomes outward; identical base
drops on both continents; high mob density ~1 visible mob per 15–20 m in
wilderness; nature mobs aggressive on sight vs players AND NPCs).

This TODO holds the DETAILED catalog to spec — it is a **blocker for
WP18** (mapgen needs the biome list) and **WP6** (mob rosters). Goal: a
spec precise enough for autonomous agent work.

## Q1 — Final biome list per band

For each of the 6 race bands: settled variant (core/inner) + wild
variant (outer), engine params (heat/humidity points, surface nodes,
decorations, tree schematics from BASE/vendorable sources). Working
draft to refine:

| Band | Settled (core/inner) | Wild (outer) |
|---|---|---|
| Alliance west (Dwarves) | pine hills | high crags (40–60) |
| Alliance center (Humans) | plains/meadows | deep forest (10–30) → cliffs at the back coast |
| Alliance east (Elves) | light forest | deep forest → jungle fringe (35–55) |
| Horde west (Undead) | blight | blighted bone-forest (40–60) |
| Horde center (Orcs) | savanna | badlands/mesa (10–30 → 45) |
| Horde east (Trolls) | jungle edge | deep jungle (35–55) |
| both, strait side | war-coast beaches (5–25) | — |
| both | swamp pockets in low outer terrain (25–40) | — |

Open: do both continents get literally the SAME wild biomes (max drop
symmetry) or mirrored flavor variants with shared drop tables
(leaning: shared drop tables, distinct flavor — "same loot, different
look").

## Q2 — Mob roster per biome

Per biome 2–3 mob types: one behavior verb each (combat_stats.md §3
readability rules), level from position (mob_level_at), stats from the
combat_stats formulas, drops (base materials identical cross-continent;
leather sources flagged for the Leatherworker mechanic). Working draft:
coast crabs/shore lizards; forest wolves (pack)/bears (territorial);
swamp crocodiles (ambush)/sludges (slow-tanky); jungle snakes
(poison DoT)/panthers (fast on-sight)/giant spiders; crags harpies
(dogshoot)/stone golems (elite). Zombies stay core/starter night mobs;
boars core/inner.

## Q3 — Spawn parameters per biome

Per biome: spawn nodes (biome signature nodes — LotT trick), interval/
chance/aoc tuned to the density target, day/night split, zone gating
via `_wob_spawn_zones` (later the radial field). Must respect the
performance rules (AGENTS.md) at 100-player scale.

## Q4 — Base material map

Which base drops (leather, cloth sources, food plants, alchemy herbs —
professions.md gathering split) come from which biomes/mobs, so both
continents can feed all base recipes (world.md §8). Ties into
TODO-design-items-crafting.md §5.
