# TODO — Round 9: terrain (MAP-C), plant placement, the five primary profession catalogs, mob wave 2, farming, enchant rolls, mounts

Written 2026-09-18 (evening) while Round 8 was closing; **DECIDED with the
user the same evening** (§4 holds the rulings). Round 9 starts after
Playtest 11 and the user's Go. Working
rules as in rounds 5–8 (Codex GPT-5.6 Sol implements and reviews, the
orchestrator runs every gate, `--no-ff` merges, sync only through
`tools/sync_to_luanti.sh`, push only on the user's word; mechanics and
pitfalls in `docs/process/cross-cli-orchestration.md`). Review scope per the
2026-09-18 ruling: own-code defects and decided rules, no hardening against
hypothetical third-party mods; the orchestrator escalates instead of
escalating complexity.

## 1. Carried over from Round 8 (no new decision needed)

- **R8-MAP-B** (moved 2026-09-18 evening): P9G-2 open manifest with a
  cave-air host mode; world placement of the 15 plant items Cooking v1
  already ships (`grug_cooking:*`, tiers decided), zones and bands per
  `docs/research/cooking-alchemy-plan.md` §3.2/§3.3; second soil per zone;
  tilled crop soil at village fields (scenery). WP40 lane, exclusive on the
  mapgen fixtures. Harness: the standard gates, both interpreters, the final
  micro pair, six-start gate and six capitals after the merge, plus a light
  placement count per plant in a few headless regions; NOT MAP-A's baseline
  world campaign (that was specific to the cave-mouth proof).
- **Bog Witch** (deferred: the pinned mesh lacks the shooting/death frames):
  ship with a licensed mesh that has the frames, or a retint of a shipped
  humanoid with `shoot_*` mapped to real frames.
- **Sovereign's Flask** (T6 utility elixir) once the Human signature effect
  exists.
- **Micro fixture receipt** (`tools/wp40/r7/micro_kat_fixture.lua` still
  builds the manifest receipt itself instead of calling `r7_manifest.new`).
- ~~`final_micro.sh` order~~ delivered by R8-DOCS (LuaJIT first, PUC only
  after a LuaJIT pass).
- Mob packages 6–8 of `docs/research/mob-worlds-plan.md` §9 (underground,
  deep, front/coast).
- ~~**Cave-mouth writer exactness**~~ (R8-MAP-A one-voxel deviation in
  seed 1): superseded 2026-09-19. R9-MAP-C switches the MAP-A cave-mouth
  writer off (`grug_mapgen_r8_cave_writer_disabled`) and replaces it with
  the surface-skin rule below; the committed seed-1 checker run and the
  evidence under `tools/r8_map_a/evidence/` become historical and leave the
  gates. No exactness fix is needed.

## 2. Lanes (decided 2026-09-18; the cut is the orchestrator's)

Wave 1 (parallel, disjoint code areas; MAP-B follows MAP-C, see there):

- **R9-MAP-C — terrain: v7 plateau, wide coast band, surface skin with
  natural cave openings** (added 2026-09-19 after the Playtest 11 mapgen
  findings; user rulings in §4.7–§4.12). WP40 lane, exclusive on the mapgen
  fixtures; MAP-B starts only after its merge. Goal: fast progress and
  *less* mapgen complexity, no new performance cost; larger problems are
  escalated to the user instead of solved by invention.
  - **Step 0 (read-only, minutes, before any change):** (a) are seas and
    lakes written completely by our layer, or does native v7 ocean survive
    as "native liquid at or below the datum"? If the latter, the water
    writer must fill that gap before the plateau; (b) maximum `H` over the
    seed corpus regions, to size the plateau with a small margin; (c) from
    the MAP-A evidence files confirm the diagnosis: cave-mouth successes
    cluster where our `H` lies far below v7's own height (native cave air
    survives only below v7's height; above it our fill is cave-free), which
    also explains the one-node lids of Playtest 11 and the holes in the
    lowered coast cliffs. If (c) does not confirm, stop and report.
  - **v7 plateau:** v7 terrain as a flat plate above our maximum `H`
    (terrain noise amplitude 0, offset = max `H` + margin), so our layer
    always cuts and never fills, and native cave density under our surface
    is uniform. `mgv7_spflags` drops `mountains` and `ridges` (3D noise and
    v7 rivers we only remove); `caverns` may stay. The six native
    NoiseParams and their authenticated baseline bytes are updated once.
  - **Surface skin with natural openings:** at least 3 solid nodes under
    `H`; native air inside the skin becomes host rock. The skin is omitted
    where the native air run directly below it is at least 4 nodes tall
    AND the column is on a slope (a cardinal neighbour at least 2 nodes
    lower); on flat ground the skin stays unless the void is open across
    the 3×3 neighbourhood (a visible sinkhole, never a one-column shaft).
    Column-local, deterministic, no flood fill. **Never inside start
    aprons, capital rings and precincts, settlements, POIs, landmarks,
    routes and their corridors, functional surfaces, foundations, housing
    and static exclusions: there the skin always stays** (user ruling
    2026-09-19). The MAP-A mouth writer stays off behind its setting; a
    later DOCS lane may delete it.
  - **Coast band:** per shore run (existing 48-node runs) a beach 20–28
    nodes deep rising one node every 2–5 nodes, then a 16–24 node linear
    blend into the relief so the terrain falls towards the beach as a
    natural hill; no slope cap. Distance to water for the far band comes
    from a world-aligned 4-node lattice (chunk-independent, integral), not
    from per-column rays; the exact near search stays only for the bank
    rule and the first beach steps. Inland columns must do less work than
    today, not more.
  - **Beach and rim shares by relief profile, no forced numbers:** wetland
    and lowland mostly beach, rolling hills medium, plateau and highland
    little, mountain none (bluff/cliff/terraced with gravel or shingle
    fronts, no sand: the dragon islands are mountains). The same rule
    selects the freshwater rim: sand rim 2–4 nodes with the bank rule in
    wetland/lowland/rolling zones, stone or gravel rim in plateau, highland
    and mountain zones (the Troll capital's mountain lake keeps its stone
    rim; capital precincts are exempt from profiles anyway). Beaches must
    remain a recurring pattern; the exact shares are the implementer's
    shortcut choice.
  - **Harness (lean, target under five hours wall time):** LuaJIT KATs
    while working (`writer_kat`, r6/r7/r8 KATs); **never `tools/wp40/r6/run.sh`**;
    ONE fixture pin refresh at the end; one engine witness (seed 0 region 0,
    seed 1 region 2: coast band width, beach share per relief profile, no
    holes in cliff faces, openings only on slopes and never in exclusions);
    the WP40 profiler (`tools/wp40/profile/run.sh`, Lua share) AND the
    wall-clock emerge of a fixed region before/after (engine share: the
    plateau adds stone, caves and ores up to the plate; `nomountains` and
    `noridges` save 3D noise) — gate: not slower than main, target faster;
    `final_micro.sh` (LuaJIT first); PUC only the named KATs, once, last;
    six-start gate and six capitals after the merge. One review at xhigh,
    at most one fix round under the Augenmaß rule; a second is escalated.
  - **Model:** GPT Astra 6 for implementation if the model id exists in
    the Codex CLI (user allowance 2026-09-19, this lane only); review on
    Sol.
- **R9-MAP-B** — as carried (WP40 only), **starts after the MAP-C merge**
  and rebases on it: the cave-air host mode of P9G-2 needs the new cave
  model. Adds **coral sprinkles** (user request 2026-09-19): in sea
  columns (not lakes) with bed depth 2–10 below the water surface, one
  coarse 16-node cell hash (reef patches) then one column hash; palette the
  six `default:coral_*` nodes plus `default:sand_with_kelp`, colour by
  hash; decoration on top in our own surface pass (engine decorations are
  impossible: they run on v7's terrain before ours). No target densities,
  one function, deterministic. Same lean harness as MAP-C plus the light
  placement counts already planned.
- **R9-PROF-A — Blacksmith + Leatherworker + Tailor catalogs** on the
  `grug_jobs` framework (`items_crafting.md` §3.3–§3.5: the T1–T6 chains,
  stations forge / tanning rack / tailor bench as nodes with the book
  button, placed in every capital beside their trainer like the brewing
  stand; metal ingots stay in the furnace/dual furnace; refinements in the
  grid). Tier-N ingredient rule, profession level v1, in-place refinement of
  the universal base items (§6b).
- **R9-PROF-B — Woodcarver + Goldsmith catalogs** (`items_crafting.md`
  §3.6a/§3.6b: carving bench, jeweller's bench, wood grades, gem cutting,
  settings, both trinket slots, the Blacksmith fitting cross-buy).
- **R9-MOB2** — packages 6–8 (underground casts of the mob plan §4, deep
  wave, front and coast) plus Bog Witch; same package discipline as MOB1
  (registrations, spawn rows, licence rows, KAT, headless boot, committed
  spawn evidence; `final_micro.sh` mandatory because of load-time
  registrations).

Wave 2 (after wave 1 merges):

- **R9-FARM (WP32)** — farming as a player activity: crop soil (from MAP-B)
  accepts seeds of the Cooking plants, growth timer per the `farming`
  reference (elapsed-time wet/dry soil), harvest/replant, hoe; fields at
  villages become real. Depends on MAP-B (soil) and COOK (items).
- **R9-ENCH (WP5)** — quality tiers and enchant rolls (`items_crafting.md`
  §6): `grug_quality`, affix table, description regeneration, drop and
  crafted-quality chances (§5.1, §6.4), refinement as the enchant
  prerequisite (§6b.3). Touches `grug_gear` and the loot path; meets the
  catalogs only at "a crafted item gets its quality roll".
- **R9-MOUNTS (WP31)** — wave 2, user ruling 2026-09-18 (see §4.5): riding
  mechanics (ephemeral mount entity as the player's mounted state, hotbar
  trigger, four tiers 15/30/45/60 taught and sold by the job trainers, T2
  replaces T1 and T4 replaces T3, land tiers everywhere, flight only at home
  and over the Battlegrounds, ocean and enemy-territory warning bands on the
  legal side of the line, forced dismount exactly at the line with NO slow
  descent (user ruling 2026-09-18: whoever flies on deliberately falls),
  damage dismounts) plus the
  models: T1 horse for both factions in faction colours, T2 one signature
  ground mount per race (Human horse, Dwarf ibex/ram, Elf stag, Orc boar,
  Undead wolf or skeletal horse retint, Troll tiger), T3/T4 scaled flying
  mobs per faction (Accord: eagle, then Steller's sea eagle; Throng: cave bat,
  then giant bat retint), the higher tier nobler in colour; no dragons as
  mounts (dragons stay rare bosses). Each mesh with a licence row and an
  animation audit as in MOB1.
- **R9-DOCS** at the end, as always.

Not in Round 9: housing (WP24, Round 10), Scout (Round 10), **Nether (V2:
user decision 2026-09-18, the Nether is the main part of the first big
content update after V1, with its own mapgen and story; no V1 lane builds
Nether seams)**.

## 3. Playtest 12 (after Round 9, fresh world)

Plants growing in their zones; learn Blacksmith and Tailor, craft one item
per reachable tier at the capital stations, refine and enchant it; a night
underground at three depth bands; a farm plot from seed to harvest; the
Bog Witch; buy the T1 mount at the trainer, ride, reach level 30 in a test
world for the race mount, and test a flying tier at the ocean edge and the
enemy border (warning band, hard dismount).

## 4. User rulings of 2026-09-18 (evening)

1. **Lane cut** as in §2: two profession lanes (PROF-A, PROF-B); farming and
   enchant rolls in wave 2 of this round.
2. **Stations**: one station per profession in every capital beside its
   trainer (as the brewing stand), every station craftable for housing from
   a T3 recipe of the owning profession.
3. **Farming scope**: every plant is farmable, including potato and corn
   (they keep their wild gathering rows and stay both food and ingredient);
   every plant appears in at least one recipe (already true for all 15 new
   plants and the staples).
4. **Enchant rolls v1**: crafted quality (§6.4) and drop quality (§5.1) in
   one lane on the shared item meta.
5. **Mounts in Round 9** (wave 2) with the rulings listed under R9-MOUNTS;
   the ephemeral-state model and the tier replacement rule are added to
   `mounts.md` by that lane; the warning band + hard dismount at the line
   stays as documented, without a slow descent.
6. **V1 boundary**: the Nether is V2 (see §2); V1 = rounds 1–9 plus housing,
   the release gates and polish.
7. **Mapgen rounds live inside Round 9** (2026-09-19): MAP-C then MAP-B, no
   separate package; parallelism comes from PROF-A/PROF-B/MOB2 running
   beside MAP-C.
8. **Simplify, do not measure first** (2026-09-19): the perceived MAP-A
   slowdown is accepted as plausible without a separate measurement; the
   lanes carry the perf gate instead. Mapgen performance is critical: any
   change that slows generation is delicate.
9. **Caves** (2026-09-19): the simplification path — v7 plateau (subject
   to step 0), 3-node skin, natural slope openings, MAP-A mouth writer off;
   no mouth-count targets. Never inside cities, capitals and POIs.
10. **Coast** (2026-09-19): terrain must fall towards beaches in a band
   that fits the terrain; "45°" was a rough hint, neither target nor cap;
   beach share is a shortcut choice as long as beaches recur; no sand on
   mountain coasts (dragon islands) or mountain lakes (Troll capital).
11. **Corals** as decoration on top, in MAP-B, sprinkles without forced
    frequencies.
12. **Escalation** (2026-09-19): larger problems in the mapgen lanes go to
    the user instead of being solved by an invented mechanism.
