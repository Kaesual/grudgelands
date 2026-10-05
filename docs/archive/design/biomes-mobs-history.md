# Biomes and mobs: historical placement extracts

Archived 2026-10-05 (Round 37 lane DD) from `docs/design/biomes_mobs.md` at
`9dc5f717`. These are the palette-era placement texts from before the Round 28
spawn recipes: the Round 18 zone selection of regional tints and the
pre-recipe ABM row table, which the mob files' `-- §4 row` comments still
quote. Their present-tense claims apply only to their original period; they
are not current design. Since Round 28 the recipes
(`mods/ENTITIES/grug_mobs/data/zones/*.spawns.json`) place every surface mob
([zone_mobs.md](../../design/zone_mobs.md) is the generated table), and since
Round 30 a surface row no zone keeps registers no ABM
([biomes_mobs.md](../../design/biomes_mobs.md) §4).

## Source: biomes_mobs.md §0, "Round 18 surface eligibility and regional identities"

### Round 18 surface eligibility and regional identities

Ordinary surface spawns require their natural minimum level to fit the actual
local difficulty query. The level field still rises toward the warfront on both
continents; a species cannot clamp itself upward into an easier band. This gate
does not change depth populations or authored encounters. Settlement spawn
protection is unchanged and does not prevent an already spawned mob from
walking into a town.

A named zone selects one interchangeable regional wildlife tint. Host nodes and
day/night clocks remain additional requirements, not alternative authorities.

| Family | Current zone selection |
|---|---|
| Boar | Base in the nine Accord/Orc settled zones (including Whitebridge); Plague in Stillgrave/Mournfen; Jungle in Kapok/Raincall |
| Zombie / Husk | Husk in Sunscar, Redtusk and Shattered Line; Zombie elsewhere |
| Spider | Jungle in Glassroot, Thunderroot, Skyglass and Stormscale; existing faction forest tint on its exclusive hosts elsewhere |
| Lynx / Panther / Snow Leopard | Panther in those four mixed/high-jungle zones; Lynx in jungle-edge start/home zones at L4+ (band 2 of Kapok, Round 24); Snow Leopard in its named mountain zones |
| Skeleton archer tints | Raider in war zones; Frost Stray in Wyrmglass; Archer in other eligible forest/mountain zones |

Distinct combat roles such as Goblin melee/ranged members and Bog Witch remain
separate creatures. The same imported mesh does not by itself equate differently
shaped/scaled bird species or visibly different combat roles. NPC/guard model
reuse is unrestricted. Existing spawn caps/rates, dispositions and drop tables
remain; this revision does not add a density multiplier.

Troll early Lynx kill objectives use Tapir, while the later Raincall outpost Lynx
objective remains. The Orc chain's night patrol hunts Husks; the Husk spawns
in Sunscar from band 2 of the start-zone gradient (L4+, Round 24), so that
quest is level 5 with the level-5 reward of 180 XP (`progression.md` §4; the
other races' Zombie patrols stay level 4 at 140 XP: the Zombie spawns from L3).
Counts and copper rewards are unchanged.

## Source: biomes_mobs.md §4, the pre-recipe ABM row table and its notes

The text below followed the "WP37 closed; table interpretation" paragraph of
§4.

The `chance` column below still prints the never-shipped values of
2026-08-08 for the other rows, computed with that inverted multiplication. It
is historical, not the runtime table; the shipped row values are in
`mods/ENTITIES/grug_mobs/*.lua` (their `-- §4 row` comments quote them).

| Mob | nodes (spawn on) | interval | chance | aoc | light | zones |
|-----|------------------|----------|--------|-----|-------|-------|
| Boar (all tints) | all six settled tops **+ forest litter, mesa_clay, gravel, snowblock, mud, sand** (core/inner filler); the **Jungle Boar** additionally carries **canopy litter** — deep-jungle patches in `inner` (§1.5) | 20 | 1125 | 5 | min 10 | core, inner |
| Rabbit/Hare | settled tops **+ the filler tops of its own continent** — Rabbit: forest litter, gravel, snowblock, mud, sand; Hare: mud, sand (no mesa_clay, §3.1 "the badlands carry no critter"). Split by a `territory_at` check | 20 | 1350 | 3 | min 10 | core, inner |
| Zombie | settled tops **+ forest litter, canopy litter, mesa_clay, gravel, snowblock, mud, sand** (night filler) | 20 | 1200 | 4 | max 5 (blight: any) | core, inner, war_coast |
| Wolf/Blightfang | coniferous litter, forest litter, bone litter, grass | 20 | 1125 | 5 | any | inner, outer |
| Hyena | dry grass, mesa_clay | 20 | 1125 | 5 | any | inner, outer |
| Jungle Lynx (Raptor slot) | rainforest litter **+ canopy litter** | 20 | 1125 | 5 | min 10 | inner, outer |
| Bear/Plaguehide | forest litter **+ silver litter, coniferous litter, grass** (Bear) / bone litter **+ blight_dirt, dry grass** (Plaguehide) | 20 | 2100 | 2 | min 10 | outer, coast |
| Jungle Ape | rainforest litter **+ canopy litter** | 20 | 2100 | 2 | min 10 | outer, coast |
| Giant Spider (all) | forest litter **+ silver litter, coniferous litter, grass** (Giant) / bone litter **+ blight_dirt, dry grass** (Pale) / rainforest litter **+ canopy litter** (Jungle) | 20 | 1800 | 4 | max 5 | outer, coast, underground |
| Stag/Gaunt Stag/Zebra | forest litter, bone litter, grass, dry grass | 20 | 1350 | 3 | min 10 | inner, outer |
| Skeleton Archer | bone litter, blight_dirt, settled tops (war coast) | 20 | 1500 | 3 | max 5 | outer, war_coast |
| Skeleton Raider | **every land top** + sand (war_coast-exclusive) | 20 | 1500 | 3 | max 5 | war_coast |
| Crag Eagle/Vulture | gravel, **snowblock**, mesa_clay | 20 | 1500 | 3 | min 10 | outer, coast |
| Stone/Mesa Golem (elite) | gravel, **snowblock**, stone, mesa_clay | 30 | 9000 (Stone Golem above y 300: 12000, Round 22 Phase 6 — bare high crags offer ~1.3× the hosts per area) | 1 | any | outer, coast, underground |
| Ram | gravel, **snowblock** | 20 | 1650 | 2 | min 10 | outer |
| Panther | rainforest litter **+ canopy litter** | 20 | 1350 | 4 | max 5 | outer, coast |
| Serpent | rainforest litter **+ canopy litter**, mud | 20 | 1350 | 4 | min 10 | outer, coast |
| Crocodile | mud (only) | 20 | 1350 | 3 | any | outer |
| Bog Ooze | mud | 20 | 1500 | 3 | any | outer |
| Parrot | rainforest litter | 20 | 1875 | 2 | min 10 | core, inner |
| Carrion Crow | **every land top** except sand (the Gull holds that slot); war_coast-exclusive | 20 | 1875 | 2 | min 10 | war_coast |
| Shore Crab | sand within 6 nodes of sea-level water, y 0–20 | 20 | 300 | 3 | any | level below 45 (§3.1) |
| Gull | sand | 20 | 1875 | 2 | min 10 | strait, war_coast, coast, **outer** |
| **Cave Bat** (critter) | stone **+ `group:grug_stratum`** | 20 | 2200 | 2 | max 5 | underground |
| **Cave Crawler** (critter) | stone **+ `group:grug_stratum`** | 20 | 2200 | **1** | max 5 | underground |
| **Bone Weevil** (critter) | bone litter / blight_dirt — **two rows, one entity name, one budget**; the row stamps the tint | 20 | 2933 | 2 | min 10 | (none — the node gates) |
| **Bog Fowl** (critter) | mud (only) | 20 | 2933 | 2 | min 10 | (none — the node gates) |
| **Poacher** | grass, forest litter, silver litter | 20 | 2200 | **4 at night** (base 3 ×1.25, ceiling) | night | exact named-zone palette |
| **Frost Stray** | gravel, snowblock | 20 | 2400 | **4 at night** (base 3 ×1.25, ceiling) | night | exact named-zone palette |
| **Sun-Dried Husk** | dry grass, mesa clay | 20 | 2000 | **5 at night** (base 4 ×1.25) | night | exact named-zone palette |
| **Song Bird** (critter) | silver litter | 20 | 2200 | 2 | day | Silverleaf exact family row |
| **Spiderling** | stone + `group:grug_stratum`, y −40…−100 | 20 | 2400 | 3 | max 5, clock ignored | underground |
| **Blood Bat** | stone + `group:grug_stratum`, y −101…−300 | 20 | 2200 | 4 | max 5, clock ignored | underground |
| **Stone Mite** | `group:grug_stratum`, y ≤ −700 | 20 | 2000 | 5 | max 5, clock ignored | underground |
| **Fox** | grass, coniferous litter, silver litter | 20 | 1900 | 3 | day | exact named-zone routes; L4 start gate |
| **Ibex** | coniferous litter, gravel, snowblock | 20 | 1900 | 3 | day | Dwarf column; L4 start gate |
| **Wild Turkey** (critter) | grass | 20 | 2100 | 2 | day | Dawnmere, Goldmead |
| **Plains Runner** (passive prey) | dry grass | 20 | 2100 | 2 | day | Sunscar |
| **Tapir** | rainforest litter, canopy litter | 20 | 1900 | 3 | day | Troll column; L4 start gate |
| **Giant Rat** | six settled tops / stone + `group:grug_stratum` | 20 | 1600 surface / 1800 cave | **5 at night** surface (base 4 ×1.25) / 4 cave | night surface; max 5 underground | all starts / y −40…−300 |
| **Scorpion** | dry grass, mesa clay | 20 | 1800 | **5 at night** (base 4 ×1.25) | night; plus a daylight row (min light 10, day toggle) with the same values, admitted only in Sunscar by the zone clock (Round 24) | Orc column and Shattered Line; L4 start gate |
| **Viper** | rainforest litter | 20 | 1800 | **5 at night** (base 4 ×1.25) | night; plus a daylight row (min light 10, day toggle) with the same values, admitted only in Kapok by the zone clock (Round 24) | Kapok and Raincall; L4 start gate |
| **Goblin Raider** | coniferous litter, gravel, snowblock, dry grass, mesa clay | 20 | 2400 | **3 at night** (base 2 ×1.25, ceiling) | night | exact Goblin-Raid palettes |
| **Goblin Slinger / Raider Hound** | same Goblin-Raid tops | 20 | 2400 | **2 each at night** (base 1 ×1.25, ceiling) | night | exact Goblin-Raid palettes |
| **Snow Leopard** | gravel, snowblock | 20 | 2100 | **4 at night** (base 3 ×1.25, ceiling) | night | Frostbarrow, Stormvault, Wyrmglass |
| **Wisp** | mud, silver/forest/bone/canopy/rainforest litter | 20 | 2200 | **4 at night** (base 3 ×1.25, ceiling) | night | exact named-zone routes |
| **Ashen / Gravewood Treant** | forest litter / bone litter | 20 | 2600 | **3 each at night** (base 2 ×1.25, ceiling) | night | exact tint-specific routes |
| Reef Lurker (elite crab) | sand within 6 nodes of sea-level water, y 0–20 | 30 | 1100 | 1 | any | level 45–60 (§3.1) |
| Kraken Guard | ocean water surface, open sea only (own check) | 60 | 12000 | 1 | any | (outside continents) |
| Bandits / Mirefolk | **no ABM** — camp anchor with **respawn slots** (world.md §4a): max 3–5, one refill per 30–60 s (Round 28 ruling 37), dormant catch-up; in a zone with a spawn recipe a recipe camp (§4.2) replaces the fire | — | — | 3–5 per camp | — | camp pos |
| Named rares | **no ABM** — scheduled spawner, 2–4 h respawn, broadcast | — | — | 1 | — | fixed routes |

**The Bandit Archer costs no spawn budget** (2026-09-16). It has no row of its
own: the bandit camp's slot roll picks it **1 in 3** per slot, so the camp is
still the 3–5 of the Bandits/Mirefolk row above and simply not all of one
kind. Both families count against that one head count
(`grug_mobs/camps.lua`), which is why an archer can never make a camp grow.
It is also why ruling 3's "more ranged mobs" reaches the INNER ring, where the
four pre-existing ranged mobs — Skeleton Archer, Skeleton Raider, Stone Golem,
Mesa Golem — never went: before this, a player met no ranged enemy at all
below roughly level 25.

Row notes:
- **Crocodile spawns on mud only.** "Water at mud" is not expressible:
  the spawn ABM's `nodes` list is the node it spawns ON and `neighbors`
  is an OR set, so "water AND mud" cannot be written. The lurking-in-
  water half of the verb is delivered by `floats` instead — the croc
  spawns on the mud bank and drifts into the pool.
- The **Skeleton Raider** reuses the Skeleton Archer's numbers
  (20 / 1500 / 3, night); it is the war-coast family, so its
  `war_coast`-only zone does all the gating and it needs no extra
  check. Its table is the skeleton table **plus heavy cloth 1/3**.
- **Parrot** and **Carrion Crow** are priced like the Gull, the other
  "flees" bird: 20 / 1875 / 2. Neither creates a new peak. The Crow's
  move to passive prey (§3.0) changed **no** spawn number — same row,
  same `aoc`, same zone.
- **The four critters of §3.0** (added 2026-08-08) were all authored at
  the WP6-style **interval 20 / chance 2200 / aoc 2**. The table above
  prints them **split by zone**, because the 0.75 density cut is a
  *surface* rule: the two surface rows (**Bone Weevil**, **Bog Fowl** — day,
  `min 10`, y 0…200) ship at **2933** since Round 26 (2200 ÷ 0.75), while
  the two `underground`-only rows (**Cave Bat**, **Cave Crawler**) keep their
  shipped **2200**, since they are excluded from the cut for the same reason the Giant Spider and
  the Golems are (see the header: cave pressure belongs to §4.1's depth
  pulse). There is also **one exception that is pure arithmetic**: the
  **Cave Crawler ships at `aoc` 1**. The underground cell was
  Zombie 4 + Giant Spider 4 + one Golem 1 = **9 / 9**; two cave critters
  at 2 each would make it 13 / 13, one over the world night peak of 12,
  so 2 + 1 lands it exactly on **12 / 12**. The two surface critters
  raise no cell above 14 against the day peak of 16
  (`wp6_spawn_budget.md` §2.2). The **Bone Weevil is deliberately ONE
  entity name with two spawn rows** — `aoc` counts per name, so the bone
  forest and the blight share its budget of 2 the way the Skeleton
  Archer's two node lists share theirs, while an `on_spawn` stamp still
  gives each biome its own tint. Two registrations would have been two
  budgets.
