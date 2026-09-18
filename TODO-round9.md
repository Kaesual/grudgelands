# TODO — Round 9: plant placement, the five primary profession catalogs, mob wave 2, farming, enchant rolls

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
  mapgen fixtures.
- **Bog Witch** (deferred: the pinned mesh lacks the shooting/death frames):
  ship with a licensed mesh that has the frames, or a retint of a shipped
  humanoid with `shoot_*` mapped to real frames.
- **Sovereign's Flask** (T6 utility elixir) once the Human signature effect
  exists.
- **Micro fixture receipt** (`tools/wp40/r7/micro_kat_fixture.lua` still
  builds the manifest receipt itself instead of calling `r7_manifest.new`).
- **`final_micro.sh` order**: run LuaJIT first, PUC only when LuaJIT passed
  (same byte comparison, earlier failure signal). Tools-only change.
- Mob packages 6–8 of `docs/research/mob-worlds-plan.md` §9 (underground,
  deep, front/coast).

## 2. Proposed lanes (orchestrator's cut)

Wave 1 (parallel, disjoint code areas):

- **R9-MAP-B** — as carried (WP40 only).
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
- **R9-DOCS** at the end, as always.

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

Not in Round 9: housing (WP24, Round 10), Scout (Round 10), **Nether (V2:
user decision 2026-09-18, the Nether is the main part of the first big
content update after V1, with its own mapgen and story; no V1 lane builds
Nether seams)**.

## 3. Playtest 12 (after Round 9, fresh world)

Plants growing in their zones; learn Blacksmith and Tailor, craft one item
per reachable tier at the capital stations, refine and enchant it; a night
underground at three depth bands; a farm plot from seed to harvest; the
Bog Witch.

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
