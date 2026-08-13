# WP37 Task Card — Apply the 0.75 Surface-Density Multiplier

Status: **Executable task card, authored 2026-08-13 (post-WP40 planning
pass). The number decision is closed (2026-08-08); nothing here reopens it.**

WP37 needs no engineering brief. The decided target values are already
printed in [`biomes_mobs.md` §4](../design/biomes_mobs.md)'s spawn table;
the shipped roster still passes the pre-multiplication WP6 numbers. This
card only sequences the mechanical work, fixes its acceptance gates and
states how the task composes with WP40.

## 1. Scope and non-goals

- Multiply the `chance` of every non-excluded **surface** `mobs:spawn` row
  in `mods/ENTITIES/grug_mobs/*.lua` by 0.75 — i.e. set each row to exactly
  the value `biomes_mobs.md` §4 already prints.
- **`aoc` does not move, on any row.** It is the per-entity-name ceiling the
  100-player calibration in
  [`wp6_spawn_budget.md`](wp6_spawn_budget.md) rests on; more attempts fill
  the same budget faster, they never raise it, so no cell's peak Σaoc moves.
- **No roster change**: no new mob, no zone/node list edit, no interval
  change, no tier change. Camps, rares and the depth pulse are out of scope
  (camps/rares are not ABM rows; the pulse is WP34).
- **No re-decision**: the 0.75 factor, the five exclusions and the
  exclusion rationale are decided design (`biomes_mobs.md` §4 header).

## 2. Exact row inventory

Shipped → target `chance` (target = §4 table value; shipped = target ÷ 0.75):

| Row (entity family) | Shipped | Target |
|---|---:|---:|
| Boar (all tints) | 1500 | 1125 |
| Rabbit/Hare | 1800 | 1350 |
| Zombie | 1600 | 1200 |
| Wolf/Blightfang | 1500 | 1125 |
| Hyena | 1500 | 1125 |
| Jungle Lynx | 1500 | 1125 |
| Bear/Plaguehide | 2800 | 2100 |
| Jungle Ape | 2800 | 2100 |
| Stag/Gaunt Stag/Zebra | 1800 | 1350 |
| Skeleton Archer | 2000 | 1500 |
| Skeleton Raider | 2000 | 1500 |
| Crag Eagle/Vulture | 2000 | 1500 |
| Ram | 2200 | 1650 |
| Panther | 1800 | 1350 |
| Serpent | 1800 | 1350 |
| Crocodile | 1800 | 1350 |
| Bog Ooze | 2000 | 1500 |
| Parrot | 2500 | 1875 |
| Carrion Crow | 2500 | 1875 |
| Gull | 2500 | 1875 |
| Bone Weevil (surface critter) | 2200 | 1650 |
| Bog Fowl (surface critter) | 2200 | 1650 |

**Excluded, must remain byte-identical** (all five already match code):

| Excluded row | Shipped = target | Reason |
|---|---:|---|
| Giant Spider | 1800 | one row serves surface and caves; cave pressure belongs to §4.1's pulse (WP34) |
| Stone/Mesa Golem | 9000 | same shared surface/cave row |
| Cave Bat | 2200 | `underground`-only, no surface half |
| Cave Crawler | 2200 | `underground`-only; also the 12/12 night-cell calibration |
| Kraken Guard | 12000 | deterrent, not density |

Shore Crab (1650) and Reef Lurker rows are **spec-only** — neither is
registered (`biomes_mobs.md` §8.3) — and are untouched by this WP.

## 3. Tasks

1. **T1 — roster edit**: apply the table above in
   `mods/ENTITIES/grug_mobs/*.lua`. Mechanical: every non-excluded
   `mobs:spawn` row whose zone/height/light signature marks it a surface
   row gets its §4 target `chance`.
2. **T2 — comment re-sync**: every `-- §4 row …` quotation in the same
   files quotes the shipped number today and reads as a false citation of
   §4; re-sync each to the value the row now passes.
3. **T3 — spec header**: drop `biomes_mobs.md` §4's
   "DECIDED, NOT YET IMPLEMENTED" caveat and its "shipped = table ÷ 0.75"
   explanation; the table becomes a plain description of code again. Update
   the WP37 row in BACKLOG.md to ✅ with a one-liner, tick ROADMAP, refresh
   the README Current State in the same commit (AGENTS.md rule).
4. **T4 — budget audit re-run**: re-run the `wp6_spawn_budget.md` §2 cell
   arithmetic against the new values, as §4 promises. Assert: no cell's
   Σaoc moved (T1 touched only `chance`); day peak 16 / night peak 12
   unchanged; the three documented day-only cells unchanged. Record the
   re-run in `wp6_spawn_budget.md` (appendix section, do not rewrite the
   original audit).

## 4. Sequencing against WP40

- WP37 depends only on WP6 (✅) and is executable against the shipped
  WP18/WP36 roster today. The recommended post-WP40 order runs it first
  after WP40 lands because it is small, mechanical and re-baselines
  density before WP13/WP33 add content.
- The 0.75 decision is keyed to **mob families**, not to the ring
  vocabulary. If WP40's consumer migration (T8) has already moved the
  spawn rows onto named-zone spawn cells, the same table applies row for
  row; only T4's audit then re-derives the **cell inventory** against the
  WP40 `logical biome × zone` cells instead of the WP18
  `top-node × _grug_spawn_zones` matrix. WP40's own acceptance gate
  (`world_zones.md` §14 "Biomes/content") guarantees every cell has a row
  or an explicit civic/no-hostiles mark; WP37's re-run verifies the peaks
  on top of that inventory.
- If WP37 runs **before** WP40 instead, WP40's T8 must carry the
  multiplied values through migration unchanged; its §14 spawn-coverage
  proof then already uses the target numbers. Either order is legal; do
  not run the multiplication twice (the acceptance gate below is
  idempotence-safe because it checks absolute values, not factors).

## 5. Acceptance gates

1. Every non-excluded surface row's registered `chance` equals its §2
   target **exactly**; every excluded row is byte-identical.
2. `grep -n "§4 row" mods/ENTITIES/grug_mobs/*.lua` quotes only values
   equal to the registered ones.
3. No `aoc`, `interval`, `nodes`, zone, light or height field differs from
   the pre-WP37 tree (diff audit).
4. T4's audit re-run is recorded and shows unchanged Σaoc peaks
   (16 day / 12 night) and unchanged day-only exceptions.
5. `tools/bin/luac51 -p` passes on every touched file; the five
   luanti-lua.md grep sweeps stay clean.
6. Runtime test plan for the user (5 min): fresh or existing world, walk a
   settled band and a wild band, confirm visibly busier surface (~1 mob
   per 15–20 m target in wilderness), confirm cave density unchanged, no
   spawn-related warnings in debug.txt.
