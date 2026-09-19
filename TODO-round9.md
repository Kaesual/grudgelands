# TODO — Round 9: terrain (MAP-C), plant placement, the five primary profession catalogs, mob wave 2, farming, enchant rolls, mounts


Written 2026-09-18 (evening) while Round 8 was closing, **DECIDED with the
user the same evening** (§4.1–§4.6); **extended 2026-09-19 after Playtest
11** with lane MAP-C, BOSS, CAP and UI (§4.7–§4.20, §5). Round 9 starts
after the user's Go; the remaining Playtest 11 points are settled. Working
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

## 2. Lanes (decided 2026-09-18, extended 2026-09-19, reviewed 2026-09-19; the cut is the orchestrator's)

Wave 1 (parallel, disjoint code areas): **MAP-C, PROF-A (substrate first),
PROF-B, MOB2, BOSS, UI**. Serial mapgen chain after MAP-C merges:
**CAP, then MAP-B** (every link changes the WP40 source projection, so each
runs `final_micro.sh` at its end and the merge re-measures the literal as
R8-MAP-A did). The orchestrator serialises the gates and gives every
headless boot its own port block (≥ 32160, spacing 5). A Sol plan review
(read-only, 2026-09-19) produced 18 findings; they are folded in below.

- **R9-MAP-C — terrain: v7 plateau, wide coast band, surface skin with
  natural cave openings** (added 2026-09-19 after the Playtest 11 mapgen
  findings; user rulings §4.7–§4.12). WP40 lane, exclusive on
  `mods/MAPGEN/grug_mapgen/wp40/`, `tools/wp40/`, `tools/r8_map_a/` and the
  fixtures while it runs. Goal: fast progress and *less* mapgen complexity,
  no new performance cost; larger problems are escalated to the user
  instead of solved by invention. Fresh worlds only: flags live in the
  game's `minetest.conf` (validated by `r7_runtime.lua`), the six
  NoiseParams are applied by `r7_native.lua`; existing worlds keep their
  `map_meta.txt`.
  - **How the two layers relate (verified in code, plan review 2026-09-19):**
    for the ordinary terrain fill (opcode 27) native air or liquid is
    preserved only where the pre-cave v7 heightmap exists and
    `y <= native_heightmap` (`map_adapter.lua` ~869–918); above that datum
    the fill overwrites it (`planner.lua` ~1490–1513). Exact surface,
    water, foundation and sky-normalisation writes stay authoritative; the
    authored sea/lake volume is written completely by our layer from `T+1`
    to `water_y` (`planner.lua` ~1479–1487), native liquid can survive only
    below the bed. So: our fill above v7's height is cave-free, v7 caves
    survive below it, and with the plateau the ordinary fill stops
    happening (exact writes still fill).
  - **Step 0 (its own short read-only Codex run; report to the user before
    the implementation run):** (a) confirm the diagnosis from the MAP-A
    evidence files: mouth successes cluster where `T` lies far below v7's
    height; stop and report if not; (b) **stone plate at y = −34/−35**: do
    not presume a pass (the R8 strata pass replaces only native stone,
    `r6_settlement.lua` ~118, so it cannot fill cave air); at one
    reproduced coordinate trace immutable native CID, native heightmap
    value, winning opcode/policy and target CID for y = −37..−33 and name
    the pass; if no single pass explains it, stop before touching caves;
    (c) plateau height: derive a bound for the maximum authored final
    height `T` including landmark and fitting raises from the design
    constants if that is cheap, otherwise the measured maximum over the
    seed corpus plus a named margin of 32; exceeding the plateau somewhere
    is benign (that column falls back to today's cave-free fill), so no
    proof is required; (d) enumerate every active production literal,
    source-projection pin, fixture and validator for the six NoiseParams
    and the v7 flags before editing (known: `r7_native.lua` (defs,
    canonical bytes, token, identities), `r7_manifest.lua` (literal pin +
    source rollup), `mapgen_manifest.lua`, `map_adapter.lua` ~305–327,
    `planner.lua` ~475–490, `r7_r6_manifest.lua` ~205–216, `r7_runtime.lua`
    ~57–69, `tools/wp40/r7/native_inputs_kat.lua`, `r7/runtime_fixture.lua`,
    `r7/micro_kat_fixture.lua`, `r7/source_audit.sh`, `r6/fixtures.lua`,
    `fixtures/headless-baseline.conf`, `profile/run.sh`; R5–R8 contracts,
    TSVs and evidence directories are immutable history and are NOT
    rewritten); (e) the analytic test helper models a plateau above the
    owner slice as a sentinel (`tools/wp40/r7/runtime_adapter.lua`
    ~1779–1797) while the engine reports `maxp.y` for a fully solid slice:
    an engine-faithful KAT case for plateau below, inside and above the
    slice is part of the lane.
  - **v7 plateau:** set `mgv7_np_terrain_base` AND `mgv7_np_terrain_alt`
    to identical constant NoiseParams (`scale = 0`, `offset = PLATEAU_Y`);
    the four climate NoiseParams stay. Flags in `minetest.conf`:
    `mgv7_spflags = caverns,nofloatlands` (drop `mountains` and `ridges`);
    the canonical enabled-feature token becomes `caverns`. Native cave
    density under our surface is then uniform.
  - **Surface skin with natural openings** (all heights are the final
    per-column authored height `T`, never raw `H`): skin band
    `T−3..T−1`; every voxel there whose immutable native CID is air (and
    whose planned outcome is preserved native air) becomes host rock. Let
    `r` = consecutive native-air voxels from `T−1` downward in the
    immutable input. The column **opens** (no surface node at `T`, no
    skin, the hole leads into the cave) when `r ≥ 4` AND (a cardinal
    neighbour's `T` is at least 2 lower OR all nine columns of the 3×3
    have `r ≥ 4`). Air runs starting below the band are untouched.
    **Water columns (`T` is a bed) get the skin and never open.** Band
    clipped at y = −37. Data: the settlement writer's immutable
    `original_data` (emerged area + 16-node halo, `original_at`) and
    `column_values_at` for neighbour heights; no flood fill; if the pass
    is not implemented inside R6, expose one read-only predicate through
    the successor context. Pass order: the opening decision is taken from
    immutable data before the P7 surface write (an opening column skips
    its surface node); the skin write runs after P7 surface and before R8
    strata, and never overrides an exact authored operation
    (foundations, water, routes). **Never inside exclusions**: each label
    (start apron, capital ring and precinct, settlement, POI, landmark,
    route and corridor, functional surface, foundation, housing, static
    exclusion) is mapped in the lane notes to ONE existing authoritative
    claim/exclusion/fitting predicate; no new name lists. The portable
    fixture (today: native air everywhere) gains mixed stone/air 3×3
    columns, owner-edge cases and negative controls. The MAP-A mouth
    writer stays off behind `grug_mapgen_r8_cave_writer_disabled`; a later
    DOCS lane may delete it.
  - **Coast band:** per shore run (existing 48-node runs) a beach 20–28
    nodes deep rising one node every 2–5 nodes, then a 16–24 node linear
    blend into the relief; no slope cap. Sand (sandstone beneath, as today)
    over the whole beach depth, ordinary biome surface in the blend zone.
    Every existing coast exemption stays exactly as today (`coast_profile_at`
    already returns nil for non-land, missing owner, static exclusions,
    housing and landmark footprints; the caller skips fittings, landings,
    functional/path/corridor/coastal grades and start/capital fittings);
    if blending towards an exempt column needs a new mechanism, stop and
    escalate. **Far-band distance from a lattice, specified:** world-
    anchored lattice with origin (0, 0) and period 4; cached value per
    lattice point = water class and level of that column
    (`classified_values`); maximum search radius 52 nodes = 13 lattice
    steps; nearest water lattice point by integer squared distance; ties
    by the smallest (dx, dz) in row-major order; orientation = the
    dominant axis of the vector to that point (ties: x); run identity as
    today from the coordinate along the other axis (`floor(axis / 48)`);
    the exact cardinal search stays for distances 1–16 (bank rule and first
    beach steps) and the lattice serves beyond. Work bound: an inland
    column costs at most one lattice lookup after the per-chunk lattice
    build of at most 46² classifications; today's 64 ray classifications
    per column disappear. One pure deterministic KAT case per relief
    profile (six); engine witnesses on representative wet, rolling and
    mountain regions; the profile comparison is one predeclared paired run
    (same region, same seed, before/after), no seed or repeat search.
  - **Beach and rim shares by relief profile, no forced numbers:** wetland
    and lowland mostly beach, rolling hills medium, plateau and highland
    little, mountain none (bluff/cliff/terraced with gravel or shingle
    fronts, no sand: the dragon islands are mountains). The same rule
    selects the freshwater rim: sand rim 2–4 nodes with the bank rule in
    wetland/lowland/rolling zones, stone or gravel rim in plateau, highland
    and mountain zones (the Troll capital's mountain lake keeps its stone
    rim; capital precincts are exempt anyway). Beaches must remain a
    recurring pattern; the exact shares are the implementer's choice.
  - **Pin refresh, prerequisite:** there is no current documented R7
    native-input pin-refresh procedure (`tools/wp40/README.md` "Extreme-
    evidence regeneration" is historical T2 evidence). Before changing
    native inputs the lane adds the README section "Current R7 native-
    input pin refresh": one exact command sequence, generated outputs vs.
    manually reviewed literals, the source audit and the final micro
    comparison, and the statement that R5–R8 evidence is immutable. The
    R8-MAP-A lane commits (merge 1e165a0a) show how the last refresh was
    done. ONE refresh, at the end, creating a new R9 witness.
  - **Harness (lean, target under five hours wall time):** all development
    and named functional KATs under LuaJIT only (`writer_kat`, r6/r7/r8
    KATs, wp39, wp45); **never `tools/wp40/r6/run.sh`**; engine witness
    and profiling BEFORE freezing the bytes; then `tools/wp40/quality/final_micro.sh`
    exactly once as the final conformance gate (it already contains the
    single PUC-5.1 run and the digest comparison; no other PUC runtime is
    scheduled; `luac51 -p` and the static Lua 5.1 gates stay). Profiler:
    `bash tools/wp40/profile/run.sh <engine-or-launcher>` per
    `tools/wp40/profile/README.md`, on main before the first change
    (baseline; confirms `instrument-mapgen.patch` applies; refresh the
    anchor if the lane moves the function, as R8-HARNESS did) and on the
    result. Engine share: wall-clock of one fixed emerge before/after
    (reuse `tools/r8_map_a/engine_probe` or the six-start launcher if
    either can time a bounded emerge; otherwise one headless script under
    40 lines with `core.emerge_area` and a completion callback), same
    region and seed, fresh world each time. Gate: not slower than main,
    target faster. Six-start gate and six capitals after the merge. One
    Sol review at xhigh, at most one fix round under the Augenmaß rule; a
    second is escalated. Model: GPT-5.6 Sol (the user allowed GPT Astra 6
    on 2026-09-19, but the Codex CLI rejects `gpt-astra-6` under the
    ChatGPT account, probed the same day).
- **R9-CAP — capital core fixes** (added 2026-09-19; **runs after the MAP-C
  merge, before MAP-B**, because it changes the WP13 core templates and the
  R7 capital-core bounds and therefore the source projection). Ownership:
  `wp13/precinct_ring.lua` (`RADIUS` 46 → 48 and the gate mask), the four
  gatehouse anchors per capital (own asymmetric anchors, e.g.
  `wp13/highcourt.lua` ~240–255), `wp40/r7_settlement.lua` `BOUNDS.capital_core`
  ±47 → ±48, and the resulting current R7 manifest/micro pins. (a) Undead
  capital: the iron bars on the battlements of the z-oriented segments are
  rotated 90° wrong (param2); (b) **core ring and gates two nodes outward**
  (user ruling: the core ring is not connected to the WP40 route pins; the
  only routes into the core are the outer ring's alleys). Verification:
  record each capital's before count of wall/building overlaps (may be
  zero) and require after = 0 for all six; six-capitals gate;
  `final_micro.sh` once at the end.
- **R9-MAP-B** — as carried (WP40 only), **starts after CAP**, rebases on
  MAP-C + CAP: the cave-air host mode of P9G-2 needs the new cave model.
  Adds **coral sprinkles** (user request 2026-09-19): in sea columns (not
  lakes) with bed depth 2–10 below the water surface, one coarse 16-node
  cell hash (reef patches) then one column hash; palette the six
  `default:coral_*` nodes plus `default:sand_with_kelp`, colour by hash;
  decoration on top in our own surface pass (engine decorations are
  impossible: they run on v7's terrain before ours). No target densities,
  one function, deterministic. Same lean harness as MAP-C plus the light
  placement counts already planned; `final_micro.sh` once at the end.
- **R9-PROF-A — Blacksmith + Leatherworker + Tailor catalogs** on the
  `grug_jobs` framework (`items_crafting.md` §3.3–§3.5: the T1–T6 chains,
  stations forge / tanning rack / tailor bench as nodes with the book
  button, placed in every capital beside their trainer like the brewing
  stand; metal ingots stay in the furnace/dual furnace; refinements in the
  grid). Tier-N ingredient rule, profession level v1, in-place refinement of
  the universal base items (§6b). **Shared substrate first (plan review
  2026-09-19):** the station whitelist is central (`registry.lua`
  `grug_jobs.STATIONS`, today grid/furnace/dual_furnace/brewing_stand) and
  public capital stations are placed centrally in WP40
  (`r7_settlement.lua` ~693–781). PROF-A's FIRST commit is therefore the
  substrate for all five professions: the five station kinds in the
  whitelist with station metadata and adapters, reserved non-overlapping
  capital coordinates for all five stations beside their trainers, the
  placement of all five public stations in `r7_settlement.lua`, and the
  rule that every T3 station item is made through a named non-circular
  grid recipe (never at its own station). That commit runs
  `final_micro.sh` and lands on main on its own before PROF-B starts; the
  MAP-C/CAP/MAP-B merges re-measure the projection literal afterwards.
  After the substrate, PROF-A touches only its catalog/content files.
- **R9-PROF-B — Woodcarver + Goldsmith catalogs** (`items_crafting.md`
  §3.6a/§3.6b: carving bench, jeweller's bench, wood grades, gem cutting,
  settings, both trinket slots, the Blacksmith fitting cross-buy). Starts
  once the PROF-A substrate commit is on main; touches only its own
  catalog/content files, never `registry.lua` or WP40.
- **R9-MOB2** — packages 6–8 (underground casts of the mob plan §4, deep
  wave, front and coast) plus Bog Witch; same package discipline as MOB1
  (registrations, spawn rows, licence rows, KAT, headless boot, committed
  spawn evidence; `final_micro.sh` mandatory because of load-time
  registrations). Shares `grug_mobs/LICENSE-media.md` with BOSS: the
  orchestrator merges the ledger rows (append-only rows, no reformatting).
- **R9-BOSS — dragons and royal groups** (added 2026-09-19 from Playtest
  11). Ownership: `grug_mobs/bosses.lua`, `grug_mobs/levels.lua` (boss tier
  HP), `grug_mobs/start_npcs.lua` (guard sockets, ~313–316 and ~675–692),
  `tools/r8_mob1/bosses_kat.lua`, textures and the media ledger (shared
  with MOB2, see there). User rulings §4.13–§4.16.
  - **Dragons move.** Both dragons walk and fly at their own discretion
    through mobs_redo (`fly` toggled per state in `do_custom`, `fly_in`
    air; if mobs_redo cannot switch `fly` at runtime, keep permanent flight
    with a low hover for "walking" and say so in the lane notes). Defaults
    (implementer may tune, must record): walk 3, run 6, fly 8 nodes/s;
    every value above player sprint; leash 36 → 64 and view range 32 → 48
    (orchestrator's choice, user may veto), HP reset on leash as today.
    Takeoff when the target is farther than about 12 nodes; **dive slam**:
    1 s telegraph, velocity onto the target's snapshot position, impact
    with the existing knockback; cancelled on target loss or leash, then
    the dragon settles to the ground.
  - **Ability table (defaults):** target set = hostile players in view
    range with vertical tolerance 8 (never friendly mobs, never
    non-combatant NPCs). **Cone breath:** three projectiles at ±15°, each
    with a bounded particle trail; impact ground effect: ice dragon
    **rime** patch (temporary node, 8 s node timer, slows 40 %, refresh
    resets the timer, no stacking), wyvern **scorch** (temporary node,
    6 s, 2 damage per second to players standing on it, cleaned by its
    timer). **Telegraphed lightning** (wyvern): particle ring at the
    target's snapshot position, impact 1.5 s later in radius 2; a player
    who left the ring is missed. **Wing gust** every ~12 s: knockback plus
    a 2 s slow for hostile players within 5 nodes (reuse the slam
    knockback). **Enrage at 50 % HP:** "roar" as a chat line to players in
    range plus one bounded particle burst (no sounds are vendored, WP6/T4
    decision), glow, cooldowns −30 %, and **at most two adds**: whelps =
    the boss mesh scaled to about a third, low HP and damage via the
    central level model, no skills, same walk-and-fly movement (flight
    faster), despawn when the boss dies. Fallback only if the lane finds
    the scaled mesh technically broken (animation or scale): two existing
    mobs (Frost Stray / Emerald Coil). The user judges the look in
    Playtest 12.
  - **Size doubled** with the collision box scaled to the visual. **HP:**
    decided centrally in `levels.lua` (`hp_flat` for the boss tier =
    18 000); `bosses.lua` never hand-sets HP (`grug_mobs.register_mob`
    forbids it). Kill and respawn announcements as today.
  - **Particle budget** (user 2026-09-19, web build): hundreds of particles
    at once are fine, thousands are not; every spawner has a bounded count
    and lifetime, no per-tick unbounded spawns.
  - **Royal groups:** guards without crowns (only the king wears one);
    exactly two guards using the sockets `throne_guard_west` and
    `throne_guard_east` (the other two socket ids stay authored in WP13
    but unresolved); the boss KAT receipt changes from `royal_guards=24`
    to 12.
  - No boss HUD (the nametag already shows HP).
  - Harness: `final_micro.sh` (load-time registrations), headless boot,
    the boss KAT, a committed evidence note of one dragon fight from a
    headless probe or the user's playtest; review Sol.
- **R9-UI — recipe books, trainers, discovery, brewing stand** (added
  2026-09-19). Ownership: `grug_jobs/ui.lua`, `grug_jobs/state.lua`
  (discovery), the trainer-name seam in `grug_mobs/start_npcs.lua`
  (~1101, where `_grug_profession` is attached; the generic name is set
  earlier in `start_villagers.lua`), `grug_brewing/node.lua` + media. User
  rulings §4.17–§4.19.
  - **Book rebuilt in the VoxeLibre craft-guide layout** as an independent
    reimplementation in our formspec style (no third-party code copied, so
    no `VENDOR.md` entry; if the lane does copy or adapt `mcl_craftguide`
    code after all, AGENTS.md third-party rules apply: `VENDOR.md` with
    upstream, pinned commit, licence and patch list, `-- GRUG PATCH`
    markers). Top: the list of craftable items with a text search; bottom:
    the 3×3 grid with the arrow and the output showing the exact
    placement, the station as an icon beside the grid; left/right arrows
    cycle alternative recipes of the same output. The UI cache must keep
    recipe width, method and shapeless metadata (today's cache drops the
    grid width for engine recipes) so exact grids can be rendered; display
    rules for furnace, dual furnace, brewing stand and profession stations
    (single-slot or station icon instead of a 3×3). The `grug_jobs`
    registry, tier rule and craft gate stay.
  - **Close returns to the crafting UI** via the existing sfinv page
    (`sfinv.set_page(player, "sfinv:crafting")`), never `button_exit`.
  - **Trainers carry their profession** ("Cook", "Cooking Trainer"): the
    retag happens where the profession is attached to the entity, read from
    the profession's registered name, so PROF-A/B trainers get it for free.
  - **Recipe discovery:** persistence = a per-player set of seen item
    names in player meta; scanned lists: `main` and `craft`, every ~2 s
    (code-side pickups bypass the inventory-action callback); a group token
    (`group:...`) counts as seen when any member of the group was seen; a
    recipe is *listed* when its tier is unlocked AND every input token is
    seen; learning a profession marks its T1 recipes seen; unlearning keeps
    the seen set; general engine recipes are not part of the profession
    book; each tier shows the count of undiscovered recipes; crafting
    itself stays gated by tier only; search covers listed recipes.
  - **Brewing stand node replaced by VoxeLibre's brewing stand look:**
    textures vendored with `LICENSE-media.md` rows (CC BY-SA 4.0 verified
    in the source repo per AGENTS.md), the nodebox re-authored by us;
    formspec and recipe logic unchanged (two reagents + vial; catalysts are
    backlog). Every new texture gets a ledger row.
  - Shared-file rule: PROF-A/PROF-B do not touch `ui.lua`; UI does not add
    catalog rows; BOSS and UI both edit `start_npcs.lua` in different
    regions (sockets vs. trainer retag), the orchestrator merges.
  - Harness: gates, `final_micro.sh`, headless boot, review Sol.

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
- **R9-DOCS** at the end, as always: contract text for MAP-C (world_zones.md
  §7.6 cave-mouth paragraph shrinks to the skin rule; §13.1 plateau and
  flags), ROADMAP, AGENTS.md paragraphs for BOSS/UI, deletion of the MAP-A
  mouth writer if MAP-C left it behind its switch.

Not in Round 9: housing (WP24, Round 10), Scout (Round 10), brewing
catalysts (backlog), fishing changes (feedback from the friends' playtest
evenings), **Nether (V2: user decision 2026-09-18, the Nether is the main
part of the first big content update after V1, with its own mapgen and
story; no V1 lane builds Nether seams)**.

## 3. Playtest 12 (after Round 9, fresh world)

Terrain first: coasts with wide beaches that the land falls towards, no
sand on mountain coasts or the Troll capital's lake, cliffs without holes,
caves with three-node walls that open on hillsides and never inside a city
or POI, no stone plate at y = −35, corals in shallow sea. Then: plants
growing in their zones; the rebuilt recipe book (search, grid placement,
alternative recipes, Close back to crafting, discovery counts); learn
Blacksmith and Tailor, craft one item per reachable tier at the capital
stations, refine and enchant it; Cooking through both routes (deferred from
Playtest 11); a night underground at three depth bands; a farm plot from
seed to harvest; the Bog Witch; a dragon fight (movement, visible breath,
ground effects, lightning telegraph, gust, enrage with two whelps) and a
king with two guards; capital walls clear of the core buildings; the
VoxeLibre brewing stand; buy the T1 mount at the trainer, ride, reach
level 30 in a test world for the race mount, and test a flying tier at the
ocean edge and the enemy border (warning band, hard dismount).

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
13. **Dragons** (2026-09-19): all six proposals accepted (movement and
    flight, dive slam, cone breath with ground effects, telegraphed
    lightning, wing gust, enrage with adds); boss HUD dropped; adds at most
    two, no skills, clearly smaller and weaker, walk and fly with flight
    faster; size doubled with the hitbox; HP 18 000 for V1.
14. **Particle budget** (2026-09-19): particles are welcome; keep the total
    in the hundreds, never thousands (web build).
15. **Royal groups** (2026-09-19): guards without crowns, two guards.
16. **Capital walls** (2026-09-19): core ring and gates two nodes outward;
    Undead z-wall bars rotation fixed.
17. **Recipe book** (2026-09-19): VoxeLibre craft-guide layout; Close
    returns to the crafting UI; trainers named after their profession.
18. **Recipe discovery** (2026-09-19): listed when tier unlocked AND every
    ingredient held once; tier unlock stays as built (current-tier crafts
    only, automatic at the threshold `CRAFTS_TO_ADVANCE`, capped by the
    character band).
19. **Brewing** (2026-09-19): VoxeLibre brewing stand node; two reagents
    stay; catalysts are backlog. Fishing: no separate test.
20. **Models** (2026-09-19): the user allowed GPT Astra 6 for MAP-C; the
    Codex CLI rejects `gpt-astra-6` under the ChatGPT account (probed
    2026-09-19), so every lane and every review runs on GPT-5.6 Sol.

## 5. MAP-C protocol: what must not repeat from Round 8

The MAP-A lane took about 16 hours; almost none of it was implementation.
The following are binding for MAP-C, CAP and MAP-B (orchestrator and
worker):

1. **Forbidden commands in briefs and lanes:** `tools/wp40/r6/run.sh` (the
   full census; a brief line naming it cost hours), any baseline world
   campaign, any PUC run other than the single one inside
   `final_micro.sh`. The brief lists these verbatim.
2. **No single tool run longer than 20 minutes** without the orchestrator's
   explicit OK in the thread; the worker names what it is about to run and
   the expected duration first.
3. **Step 0 as its own read-only run** with a report to the user
   (diagnosis confirmed? stone-plate pass found? plateau bound? pin
   surface enumerated?). No implementation until the user has seen it.
4. **One pin refresh**, at the end, following the README section the lane
   writes first ("Current R7 native-input pin refresh"); never ad hoc,
   never twice; R5–R8 evidence immutable; a new R9 witness.
5. **`final_micro.sh` is the only accepted micro gate and the only PUC
   run** (a direct `luajit tools/wp40/r7/micro_kat.lua <root>` is a false
   pass); it runs once, last, after witnesses and profiling.
6. **Gate order for the orchestrator:** the scratchpad gate script
   (`w9/gates.sh <repo>`: `tools/static.sh`, `python3 tools/check_fresh_server.py`
   as its own step, every function-style KAT under LuaJIT including
   `tools/r6_*/kat.lua tools/r7_*/kat.lua tools/r8_*/*_kat.lua tools/r8_*/kat.lua`,
   wp39, wp45, a 60 s headless boot on the lane's port; `static.sh` has no
   `set -e`, so the script checks each exit code), then the engine
   witness, then profiler + emerge wall-clock, then `final_micro.sh`, then
   merge, then six-start gate and six capitals. Six-start runs from a
   script whose command line does not name the output directory (pgrep
   self-match, exit 144).
7. **Review:** one Sol review at xhigh with the Augenmaß scope; at most one
   fix round; a second means the orchestrator stops and reports to the user
   with the finding list. Model-capacity failures (`turn.failed`) are
   relaunched, not counted.
8. **Shared files:** MAP-C, CAP and MAP-B are the only lanes touching
   `mods/MAPGEN/grug_mapgen/wp40/`, `wp13/`, `tools/wp40/`, `tools/r8_map_a/`
   and the fixtures, in that serial order; the PROF-A substrate commit is
   the one exception (`r7_settlement.lua` station placement) and lands
   first. New palette nodes need `node_semantics_fixture` entries. Every
   WP40-touching merge re-measures the source-projection literal with
   `final_micro.sh` (R8-MAP-A precedent).
9. **Escalation over invention:** any of these stops the lane with a report
   instead of a workaround: the coast band needs a new exemption-blend
   mechanism; the plateau slows emerge; the skin rule needs a flood fill;
   the stone plate has no single explaining pass; a pin that cannot be
   refreshed with the documented procedure.
10. **Time budget:** step 0 under 30 minutes; implementation run under
    3 hours of wall time; gates and witness under 1 hour; review under
    1 hour. The orchestrator checks the thread at each boundary.
