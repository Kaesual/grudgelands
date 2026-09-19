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

## 2. Lanes (decided 2026-09-18, extended 2026-09-19; the cut is the orchestrator's)

Wave 1 (parallel, disjoint code areas; MAP-B follows MAP-C, see there).
Seven lanes; the orchestrator serialises the gates and gives every headless
boot its own port block (≥ 32160, spacing 5).

- **R9-MAP-C — terrain: v7 plateau, wide coast band, surface skin with
  natural cave openings** (added 2026-09-19 after the Playtest 11 mapgen
  findings; user rulings in §4.7–§4.12). Note for fresh worlds only: the
  mgv7 flags and noise params live in the game's `minetest.conf` and are
  applied by `r7_native.lua`; existing worlds keep their `map_meta.txt`. WP40 lane, exclusive on the mapgen
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
    (d) **Stone plate at y = −34/−35** (Playtest 11: every cave is crossed
    by a one-node stone layer there): find which pass writes host rock into
    native cave air at that row (suspects: the R8 strata pass, depth band
    40 nodes below the surface; the fill floor at y = −37) and fix it in
    this lane; the new skin rule must not add a second plate. **Step 0 is
    its own short read-only Codex run; its report goes to the user before
    the implementation run starts** (design may change on (a)).
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
    Column-local, deterministic, no flood fill. Precise form: let `r` be the
    number of consecutive native-air voxels from `H − 1` downward in the
    immutable input. Skin band = `[H − 3, H − 1]`; every native-air voxel in
    the band becomes host rock ("skin") unless the column opens. The column
    opens (no surface node at `H`, no skin, the hole leads into the cave)
    when `r ≥ 4` AND (a cardinal neighbour's `H` is at least 2 lower, OR all
    nine columns of the 3×3 have `r ≥ 4`). Air runs that start deeper than
    the band are untouched (their roof is already ≥ 3). **Water columns
    (sea, lake, river: `T` is a bed) get the skin below the bed and never
    open**, so no lake drains into a cave. The band is clipped at y = −37
    (broad writes never go below it, contract §7.6); columns with `H ≤ −34`
    keep today's behaviour. **Never inside start
    aprons, capital rings and precincts, settlements, POIs, landmarks,
    routes and their corridors, functional surfaces, foundations, housing
    and static exclusions: there the skin always stays** (user ruling
    2026-09-19). The MAP-A mouth writer stays off behind its setting; a
    later DOCS lane may delete it.
  - **Coast band:** per shore run (existing 48-node runs) a beach 20–28
    nodes deep rising one node every 2–5 nodes, then a 16–24 node linear
    blend into the relief so the terrain falls towards the beach as a
    natural hill; no slope cap. Sand (with sandstone beneath, as today)
    covers the whole beach depth; the blend zone carries the ordinary
    biome surface. Distance to water for the far band comes
    from a world-aligned 4-node lattice (chunk-independent, integral), not
    from per-column rays; the exact near search stays only for the bank
    rule and the first beach steps. Inland columns must do less work than
    today, not more. Exempt columns (static exclusions, housing, landmark
    footprints, functional grades, routes and their corridors, start and
    capital fittings) keep their height exactly as today; the band blends
    towards them with the existing collar/grade rules and must not open a
    cliff at an exemption edge. If that blending turns out to need a new
    mechanism, stop and escalate instead of inventing one.
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
    `noridges` save 3D noise) — gate: not slower than main, target faster.
    Emerge timer: reuse `tools/r8_map_a/engine_probe` or the six-start
    launcher if either can time a fixed emerge; otherwise add one small
    headless script (a bounded `core.emerge_area` with a completion
    callback that logs the elapsed time; under 40 lines), same region and
    seed on both sides, fresh world each time;
    `final_micro.sh` (LuaJIT first); PUC only the named KATs, once, last;
    six-start gate and six capitals after the merge. One review at xhigh,
    at most one fix round under the Augenmaß rule; a second is escalated.
  - **Model:** GPT-5.6 Sol (the user allowed GPT Astra 6 for this lane on
    2026-09-19, but the Codex CLI rejects `gpt-astra-6` under the ChatGPT
    account: "model is not supported", probed 2026-09-19); review on Sol.
  - **Profiler patch:** run `tools/wp40/profile/run.sh` on main BEFORE the
    first change to record the baseline and to confirm the instrumentation
    patch still applies; if the lane moves the anchored function, refresh
    `tools/wp40/profile/instrument-mapgen.patch` as R8-HARNESS did.
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

- **R9-BOSS — dragons and royal groups** (added 2026-09-19 from Playtest
  11; `grug_mobs/bosses.lua` only, plus licence rows and textures). User
  rulings §4.13–§4.16.
  - **Dragons move.** Both dragons walk and fly at their own discretion
    through mobs_redo (`fly` toggled per state in `do_custom`, `fly_in`
    air; if mobs_redo cannot switch `fly` at runtime, keep permanent flight
    with a low hover for "walking" and say so in the lane notes), flight faster than walking, both faster than
    any player movement including sprint so nobody simply outruns them;
    leash stays 36. Takeoff when the target is farther than about 12
    nodes; **dive slam**: short telegraph, velocity onto the target, impact
    with the existing knockback.
  - **Visible breath as a cone:** three projectiles with spread, each with a
    particle trail. Impact leaves a **ground effect**: the ice dragon lays
    rime patches (short-lived node with a node timer, slows), the wyvern
    strikes lightning with a scorch mark. Temporary nodes plus particles,
    no new system.
  - **Telegraphed lightning** (wyvern): particle ring at the player's
    position, impact about 1.5 s later; dodgeable.
  - **Wing gust** about every 12 s: knockback plus a short slow for
    everything in melee range (reuse the slam knockback).
  - **Enrage at 50 % HP:** roar, glow, shorter cooldowns, and **at most two
    adds**: whelps, i.e. the boss mesh scaled to roughly a third with low HP
    and low damage, no skills, same walk-and-fly movement (flight faster),
    despawn when the boss dies. Fallback if the scaled mesh looks wrong:
    two existing mobs (Frost Stray / Emerald Coil).
  - **Size doubled** with the collision box scaled to the visual; **HP 54 000
    → 18 000**; kill and respawn announcements as today.
  - **Particle budget** (user 2026-09-19, web build): hundreds of particles
    at once are fine, thousands are not; every spawner has a bounded count
    and lifetime, no per-tick unbounded spawns.
  - **Royal groups:** guards without crowns (only the king wears one); two
    royal guards instead of four; nothing else changes.
  - No boss HUD (the nametag already shows HP).
  - Harness: `final_micro.sh` (load-time registrations), headless boot,
    a committed evidence note of one dragon fight from a headless probe or
    the user's playtest; review Sol.
- **R9-CAP — capital core fixes** (added 2026-09-19; WP13 code only,
  `mods/MAPGEN/grug_mapgen/wp13/`): (a) Undead capital walls: the iron bars
  on the battlements of the z-oriented segments are rotated 90° wrong
  (param2), the x-oriented segments are right; (b) **core ring and its gates
  move two nodes outward** so walls no longer cut through the core
  buildings (user ruling: the core ring is not connected to the WP40 route
  pins; the only routes into the core are the outer ring's straightforward
  alleys). Verify with the six-capitals gate and a screenshot-free headless
  count of wall/building overlaps per capital (before > 0, after = 0).
- **R9-UI — recipe books, trainers, discovery, brewing stand** (added
  2026-09-19; `grug_jobs/ui.lua`, `trainers.lua` display only,
  `grug_brewing/node.lua` + media). User rulings §4.17–§4.19.
  - **Book rebuilt in the VoxeLibre craft-guide layout:** top the list of
    craftable items with a text search; bottom the 3×3 grid with the arrow
    and the output showing the exact placement, the station as an icon
    beside the grid; left/right arrows cycle alternative recipes of the same
    output. The project is GPLv3, VoxeLibre's `mcl_craftguide` is GPLv3:
    it may be studied or adapted with attribution (AGENTS.md third-party
    rules). The `grug_jobs` registry, tier rule and craft gate stay.
  - **Close returns to the crafting UI**, never closes the inventory.
  - **Trainers carry their profession** ("Cook", "Cooking Trainer"), read
    from the profession's registered name so PROF-A/B trainers get it for
    free.
  - **Recipe discovery:** a recipe is *listed* when its tier is unlocked
    AND the player has held every ingredient at least once (per-player
    "seen items" set from a periodic inventory scan, about every 2 s,
    because code-side pickups bypass the inventory-action callback).
    Learning a profession marks its T1 recipes discovered; each tier shows
    the count of undiscovered recipes. Crafting itself stays gated by tier
    only. Search covers discovered recipes.
  - **Brewing stand node replaced by VoxeLibre's brewing stand** (nodebox +
    textures of `mcl_brewing`, media CC BY-SA 4.0 to be verified in the
    source repo per AGENTS.md, `LICENSE-media.md` rows); formspec and
    recipe logic unchanged (two reagents + vial; catalysts are backlog).
  - Shared-file rule: PROF-A/PROF-B do not touch `ui.lua`; UI does not add
    catalog rows; the orchestrator merges UI first if both are ready.
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
The following are binding for MAP-C and MAP-B (orchestrator and worker):

1. **Forbidden commands in briefs and lanes:** `tools/wp40/r6/run.sh` (the
   full census; a brief line naming it cost hours), any baseline world
   campaign, any PUC run before the final LuaJIT pass. The brief lists
   these verbatim.
2. **No single tool run longer than 20 minutes** without the orchestrator's
   explicit OK in the thread; the worker reports what it is about to run
   and the expected duration first.
3. **Step 0 as its own read-only run** with a report to the user (seas
   written by us? max `H`? diagnosis confirmed? stone-plate pass found?).
   No implementation until the user has seen it.
4. **One pin refresh**, at the end, with the documented procedure in
   `tools/wp40/README.md`; never ad hoc, never twice. `SOURCE_PROJECTION_SHA256`
   and the fixture pins change once.
5. **`final_micro.sh` is the only accepted micro gate** (a direct
   `luajit tools/wp40/r7/micro_kat.lua <root>` is a false pass); LuaJIT
   first, PUC named KATs once at the very end.
6. **Gates order** for the orchestrator: `gates.sh` (static.sh, fresh-server
   check, all KATs under LuaJIT, 60 s headless boot on an own port), then
   `final_micro.sh`, then the engine witness, then profiler + emerge
   wall-clock, then PUC named KATs, then merge, then six-start gate and six
   capitals. Six-start runs from a script whose command line does not name
   the output directory (pgrep self-match, exit 144).
7. **Review:** one Sol review at xhigh with the Augenmaß scope; at most one
   fix round; a second means the orchestrator stops and reports to the user
   with the finding list. Model-capacity failures (`turn.failed`) are
   relaunched, not counted.
8. **Shared files:** MAP-C and MAP-B are the only lanes touching
   `mods/MAPGEN/grug_mapgen/wp40/`, `tools/wp40/`, `tools/r8_map_a/` and the
   fixtures; CAP touches only `wp13/`; nothing else in wave 1 touches
   mapgen. New palette nodes need `node_semantics_fixture` entries.
9. **Escalation over invention:** any of these stops the lane with a report
   instead of a workaround: seas depend on native ocean; the coast band
   needs a new exemption-blend mechanism; the plateau slows emerge; the
   skin rule needs a flood fill; a fixture that cannot be re-pinned with the
   documented procedure.
10. **Time budget:** step 0 under 30 minutes; implementation run under
    3 hours of wall time; gates and witness under 1 hour; review under
    1 hour. The orchestrator checks the thread at each boundary.
