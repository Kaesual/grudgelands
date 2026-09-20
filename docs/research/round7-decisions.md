# Round 7 historical decisions

> **Historical archive:** This file preserves the Round-7 rulings and execution
> plan as written. Current authority lives in `docs/design/`, BACKLOG and the
> active execution record. Old lane, model, CLI, approval and gate instructions
> below are not current process instructions.

Decided with the user on 2026-09-18 after Playtest 9 (main `070abcae`, round 6
complete). Round 7 starts on 2026-09-19. It is a **planning round with a
small implementation tail**: the creative plans it produces are the input of
[Round 8](round8-decisions.md), whose goal is a first complete version of Cooking
and Alchemy. Nothing in this file overrides a decided rule in `docs/design/`;
where a plan below wants to change one, the plan says so and the user rules
before Round 8 implements it.

**Status 2026-09-18 (evening):** Round 7 is delivered on main. All lanes
merged with independent Sol reviews and fix rounds: R7-REF
(`plants-and-potions-reference.md`), R7-EVID (`mob-candidates-evidence.md`,
`round7-inventory-extract.md`), R7-UI, R7-FOOD (with R7-MISC and R7-CITE
folded in), R7-LVL, and the two orchestrator-authored plans
(`cooking-alchemy-plan.md`, `mob-worlds-plan.md`). Round-end validation on
the merge HEAD: full gates, WP40 final micro pair, six-start digest gate,
six capitals — all PASS. What remains for the user: the decision lists in
both plans (§10 / §11) and Playtest 10 (§5 below); those rulings open
Round 8.

Working rules stay as in rounds 5 and 6: Codex GPT-5.6 Sol implements and
reviews in separate contexts, the orchestrator runs every gate, merges with
`--no-ff`, syncs only through `tools/sync_to_luanti.sh`, pushes only on the
user's word. Mechanics: `docs/process/cross-cli-orchestration.md`.

## 1. User rulings recorded in this round (2026-09-18)

- **R7.1 Food v2.** Every food has a **fixed instant HP value per tier** (the
  same for every food of one tier, never a percentage, HP only) and a
  **3-minute buff ticking every 5 s**. Raw, unprocessed edibles (apple,
  cocoa, meat, fish, catalog finds) are always the weakest food of their
  tier: the tier's instant value plus **1 % HP / 5 s**, identical across
  tiers. Cooking upgrades an ingredient into a dish with the real tier
  effects. Both the instant heal and the regeneration parts are inactive in
  combat: eating in combat is allowed, the buff starts, but regeneration only
  ticks and the instant heal only applies out of combat (combat healing is
  the potion's monopoly). Non-regeneration food bonuses (see R7.2) stay
  active in combat; the tooltip says so in one sentence.
- **R7.2 Food tiers.** T1–T2 dishes: regeneration only. T3–T4: regeneration
  plus one small bonus (about +2 % / +4 % HP pool or mana pool). T5–T6:
  regeneration plus a stronger, more specific bonus (about +6 % / +8 % pool,
  or +1 % crit). Role dishes exist (caster: HP + mana regen; melee/archer;
  tank). Exact tables are the output of the Round 7 cooking plan.
- **R7.3 Elixirs and potions.** Elixirs: stronger specific stat bonuses per
  tier (for example +20 % HP pool or +4 % crit at T6), **no regeneration**,
  higher-tier Alchemy recipes. Potions: instant effects (15 % HP or mana,
  +10 % movement speed for 5 s and similar), lower-tier Alchemy recipes,
  keep the in-combat monopoly and the shared 60 s cooldown. **Food buffs and
  elixirs stack, also on the same property.** Food's own secondary effect is
  deliberately weak; elixirs carry the strong bonuses.
- **R7.4 Minimum level for consumables.** Food, potions and elixirs enforce a
  minimum character level on use (a level-60 elixir is refused at level 1,
  nothing consumed), through the same item-level seam the weapon slot uses.
- **R7.5 Mana regeneration** grows clearly slower than the mana pool, so
  higher levels need food for a good regeneration. Proposal (orchestrator,
  confirm in the lane): out of combat `1 + 0.15 × level` mana per second
  (L1 1.15/s on a 26 pool, L60 10/s on a 2696 pool), in combat one quarter
  of that; talents that add regeneration keep their relative effect.
- **R7.6 Level bands.** Every zone becomes harder from the continent's outer
  side toward the faction front in **three bands** along that axis (start
  zones: 1–3 up to the start town, then 4–6, then 7–10 toward the capital;
  every other zone splits its range the same way). The 150 m start band from
  Round 6 stays as a safety net. Underground uses the same pattern: three
  sub-bands per depth step instead of a smooth ramp.
- **R7.7 Mob worlds.** Surface, underground and Nether keep **separate
  families and separate progressions**; overlaps are allowed but each world
  reserves its own species (Nether reserve from VoxeLibre: Ghast, Magma
  Cube, Wither Skeleton, Piglin/Hoglin, Strider, and similar). Underground
  leans toward flying (bats) and ranged families; underground fliers do not
  need the surface "fly close to the ground" rule.
- **R7.8 Professions order.** Scout moves to a later round. Round 8 delivers
  Cooking and Alchemy v1; Blacksmith, Tailor, Leatherworker, enchant rolls
  (WP5) and Goldsmith follow later, Scout with the leather/bow professions.
- **R7.9 Buff list text** names the effect ("Food +2% HP/5s",
  "Food +2% HP, +4% Mana/5s").
- **R7.10 Start preload** must not re-emerge finished start areas on every
  server start (persist a per-world marker; a fresh world has none).
- **R7.11 UI overlap** on the Character page (derivation lines over the
  equipment slots) and the Talents page (header over the T1 rows) is fixed.

## 2. Lanes

Merge order where it matters: docs/planning lanes are independent; the
implementation lanes merge in the order listed. Every lane: own worktree
under `.claude/worktrees/r7-<lane>`, own port block, KAT + mutation for
every behavioural change, independent review, gates by the orchestrator.

### Planning lanes (documentation only, no Lua)

Authorship (user request of 2026-09-18, "work out a creative plan
yourself"): the two creative plans R7-COOK and R7-MOB are authored by the
orchestrator (Claude Fable) as the design voice; Sol lanes supply the
evidence they build on (R7-REF, licence and asset tables, zone data
extracts) and review the finished plans for consistency with the code and
`docs/design/`. The user can reroute this per session
(`docs/process/agent-model-policy.md`).


- **R7-REF Reference projects for plants and potions.** Add
  `farming` (https://codeberg.org/tenplus1/farming.git) and `x_farming`
  (https://bitbucket.org/minetest_gamers/x_farming.git) as submodules under
  `reference_projects/` only if their code AND media licences are verified
  in the clone (no NC, no ND; per-file media rows where the project has
  them), and only for what VoxeLibre's `mcl_farming` / `mcl_potions` do not
  already cover. Deliverable: `docs/research/plants-and-potions-reference.md`
  with one table per project (crops, wild plants, cooked foods, potion
  mechanics, animated/textured assets, licence per file class) and a
  one-paragraph verdict per project on what we would harvest (assets,
  mechanics, nothing).
- **R7-COOK Creative plan: Cooking and Alchemy.** Deliverable:
  `docs/research/cooking-alchemy-plan.md`. Contents: the ingredient
  catalog per zone (gathered wild plants, crops for the later farming
  layer, found-only items, animal drops, fish), organised by the six tiers
  and the three bands of R7.6; the six cooking tiers with dishes per role
  (regen, caster, melee/archer, tank) and the raw-vs-cooked rule of R7.1;
  fixed instant values per tier (proposal: T1 +5, T2 +15, T3 +40, T4 +90,
  T5 +180, T6 +300 HP); the tick effects per tier (R7.2); Alchemy with
  potions at the low tiers and elixirs at the high tiers (R7.3), station
  and recipe-book structure (R22 of Round 5: player recipe book plus
  station books), minimum levels (R7.4), stacking rules, and what the
  mapgen must provide (R8 mapgen lane input: which plant grows where, sand
  and reeds at shores, crop soils). VoxeLibre's potion mechanics are
  orientation, not a template. Every decided number in `docs/design/`
  that the plan wants to change is listed in a "proposed changes to decided
  rules" section for the user's ruling.
- **R7-MOB Creative plan: mobs and spawns.** Deliverable:
  `docs/research/mob-worlds-plan.md`. Contents: three worlds (surface,
  underground, Nether reserve) with their own progressions; the target
  cast per zone under the three-band pattern (about three to four day
  families with one or two 24 h animals, two to three night families, the
  existing rare; underground two to three families per depth band with the
  flying/ranged tendency); the day/night spawn clock (night roles active
  after sunset, day roles not respawned at night, Zombie/Skeleton fallbacks
  where a zone has no night family); dragons (draconis, both dragon
  islands) and the six kings as boss-tier content; every candidate family
  with source project, mesh/animation evidence and licence line, drawn from
  animalia, animalworld, mobs_monster, goblins, draconis, VoxeLibre
  `mobs_mc` and the user-approved rows of
  `docs/research/reference-media-candidates.md`. The user decides per
  family; the plan ends with the decision list.

### Implementation lanes (small, independent of the plans)

- **R7-LVL Level bands (R7.6).** `mods/MAPGEN/grug_mapgen/wp40/zones.lua`
  and `simple_map.lua`'s difficulty field: replace the single hub target per
  zone by a three-band ramp along the continent axis (Accord toward +z,
  Throng toward −z, mirrored), bands at thirds of the zone's depth, start
  town inside the first band; underground three sub-bands per 50-node step.
  KAT over all 38 zones and the six starts; start identities and terrain
  digests must not move (the field is not geometry); engine validation by
  the orchestrator after the merge. `world_zones.md` §2 and
  `combat_stats.md` §"Position → mob level" follow.
- **R7-UI Layout (R7.11).** Character page: two short derivation lines,
  the rest on the Help page, equipment slots clear of text. Talents page:
  the crit/dodge/armor header on one line or moved to the Character page so
  the T1 row is free. UI KAT rows for the formspec geometry.
- **R7-FOOD Food v2 core (R7.1, R7.2 framework, R7.4, R7.5, R7.9).**
  `mods/ITEMS/grug_food`: fixed instant value per tier plus 5 s tick,
  regeneration parts paused in combat, raw items on the weakest rule,
  `grug_core.status` gains stat modifiers (HP/mana pool percent, crit,
  armor, spell damage) that the stats accessors read like talent bonuses,
  buff text with effect, consumable minimum level through the `_grug_ilvl`
  seam, mana regeneration curve. Today's foods keep their tiers; the dish
  tables of R7-COOK land in Round 8.
- **R7-CITE Stale Lua-comment citations.** Round 6's documentation lane
  listed 17 `api.lua:<line>` citations in Lua comments that moved
  (`grug_traders/vendors.lua`, `grug_mobs/rares.lua`, `init.lua`,
  `verbs.lua`, `crocodile.lua`, `skeleton_archer.lua`, `bandit.lua`,
  `start_villagers.lua`); retarget them (comments only) and run
  `tools/docs/check_api_citations.lua`. Fold into R7-MISC.
- **R7-MISC Start preload marker (R7.10)** in `grug_core/starts_preload.lua`
  (per-world mod storage; skip the emerge and log "start areas already
  generated"). May be folded into R7-FOOD or R7-UI if the orchestrator
  prefers fewer lanes.

## 3. Gates and validation

`tools/wp11/static.sh`, every function-style KAT under LuaJIT, the lane KATs
under PUC 5.1 with byte-identical output, `tools/wp39/*`, `tools/wp45/run.sh`,
`tools/wp13/*_kat.lua`, one headless boot per merge; for R7-LVL additionally
`tools/wp40/quality/final_micro.sh` on the merge HEAD and the six-start
digest gate `tools/wp13/run_engine.sh`. Orchestrator gate script pattern:
Round 6's `gates.sh` with an absolute repository root for every KAT.

## 4. Open decisions the plans must bring back to the user

- Per-family yes/no for every mob candidate (R7-MOB decision list).
- The cooking and alchemy tables and any decided-rule change (R7-COOK).
- The fixed instant HP values per tier and the mana regeneration curve
  (proposals above).
- Which of `farming` / `x_farming` become reference projects.

## 5. Playtest 10 (after Round 7, fresh world)

Level bands from a start toward the capital; Character and Talents pages;
eating raw food in and out of combat; buff list texts; the preload log line
on a second server start; mana regeneration at a low and a high level
(`/xp`).
