# Round 21: terrain integration and playtest fixes

Date: 2026-09-24. Coordinator: GPT-6 Astra.
Status: **delivered locally, 2026-09-24; user playtest pending**.
[Completion receipt](../research/round21-completion.md).
Execution ledger: [Round 21 state](round21-state.md).
Baseline: local `main` at `b5cf84d0`, Round 20 delivered.

Latest follow-up: [mining and furnace discussion](round21-mining-furnaces.md)
contains the current/proposed full T1–T6 density tables, verified pick progression
and added F4 furnace package. Starter coal quests remain; their replacement with
logs was declined. Density choices and 10-second normal metal smelts are
accepted. The corrected Gold row and Bronze-only arrows are approved with the round Go.

## Authority and scope

This plan records the approved playtest fixes and source investigation. Final
decisions are in [the execution record](round21-state.md#approved-decisions) and
the living design owners. Baseline tables below preserve the planning evidence;
they do not override the approved replacement matrix in the mining supplement.

Read `AGENTS.md`, `docs/process/wp-workflow.md`,
`docs/process/agent-model-policy.md`, `docs/research/luanti-lua.md` (especially
Interpreter and test strategy), and relevant sections of
`docs/technical/module-guide.md`. Design owners: `world_zones.md`,
`settlements.md`, `items_crafting.md`, `quests.md`, `biomes_mobs.md` under
`docs/design/`. Existing depth/Nether/Housing questions do not block this round;
none of those broader systems is added here.

Native agents only. Root Astra orchestrates; Astra handles shared geometry and
terrain semantics, Sol handles bounded feedback/content work. No Claude task,
provider CLI, client fork, reference-pin update or remote push. Four currently
available concurrent slots mean root plus three workers, not a project-wide
limit on package count. Independent reviewers must not author their reviewed
implementation. Separate worktrees and explicit file ownership.

Fresh worlds remain required. Current-version persistence must work; no repair
LBMs, old-world migration or retroactive reshaping. Do not modify the user's
`test` world or launch a server against their personal Luanti directory.

## Playtest evidence and reproducibility

- User accepts new contextual LMB behavior; preserve its input contract.
- Screenshot 1: capital L junction has an uncovered corner and inconsistent
  paving/edging.
- Screenshot 2: Kezamba inner-core stair at approximately `(1800,66,1448)`
  terminates against an impassable two-node lip.
- Screenshot 3: Kezamba east exit at `(2056,40,1499)` has a similar lip.
- Screenshot 4: Nhal Veyr plots include both buried and raised building edges.
  No exact coordinates supplied; use representative plots, not a fabricated
  reproduction coordinate.
- Screenshot 5: high sand sheets at beach/cliff ends near
  `(-1680,24,-2932)`, with correlated coral strips nearby.
- Local `test/map_meta.txt` currently records world seed
  **`7354267267733045968`** (read-only observation on 2026-09-24). Save this
  string exactly; never round through a Lua number. This links the local report
  to a reproducible seed, not to the separate unavailable production-world case.
- Screenshots are evidence of symptoms, not proof that all stair defects share
  one overwrite cause. No mapgen execution was performed during planning.

## Current ore numbers: decision baseline

Production rows: `mods/MAPGEN/grug_mapgen/wp40/r7_r6_manifest.lua:67–83`.
Strict consumer mirrors them in `r6_content.lua:113–129,295–320`.
Placement uses eligible-host budgets in `r6_settlement.lua:2502–2612`.

| Resource | Eligible host nodes per target ore node | Nominal share | Nominal target in 4,096 fully eligible host nodes | Maximum nodes per vein |
|---|---:|---:|---:|---:|
| Coal | 128 | 0.78125% | 32 | 8 |
| Copper | 256 | 0.390625% | 16 | 8 |
| Tin | 384 | 0.260417% | 10 or 11 (10.67 nominal mean) | 8 |
| Quartz | 256 | 0.390625% | 16 | 8 |
| Iron | 128 | 0.78125% | 32 | 8 |

These five currently have the **same base density in T1 through T6**, across
all eligible race regions. They are not start-zone-only ores. Budgets use
deterministic remainder rounding and balanced vein targets within 16-node
cells/host/tier/deep-band groups. For example, 32 coal target nodes normally
form four targets of eight nodes, not 32 independent surface discoveries.
Exclusions, unavailable hosts and competing placement can reduce actual output.
The table is configuration arithmetic, not a measured world yield or expected
number of blocks a tunneling player must mine before finding a vein.

Depth/host tiers are absolute world Y, not depth below local terrain
(`grug_materials/registry.lua:7–33`):

| Tier | Y range | Host |
|---|---|---|
| T1 | -100 through upper map limit | Stone |
| T2 | -300 to -101 | Slate |
| T3 | -500 to -301 | Basalt |
| T4 | -700 to -501 | Granite |
| T5 | -1000 to -701 | Emberrock |
| T6 | -31000 to -1001 | Abyssal rock |

The shared deep multiplier is 1.25 at Y=-1500…-1999, and 1.5 at Y<=-2000.
Ordinary T6 above that has no extra multiplier. Natural ores are finite.
Land and eligible planned inland-water geology admit ores; coastal shelf,
deep ocean, foreign/constructed material, protected exclusions and unsuitable
hosts do not. Dirt near the surface is not an ore host.

**Current proposal:** use the full per-material T1–T6 matrix in
[the mining discussion](round21-mining-furnaces.md), replacing the initial
blanket shallow doubling. It gives copper/tin equal density, material peaks and
a lower-density floor at depth while preserving next-pick access. The matrix
and corrected Gold row are accepted; implementation is underway.

Six starter cook quests ask for three `default:coal_lump`; two capital tasks
ask for eight and two regional tasks for six. Starter descriptions incorrectly
recommend bronze-or-better despite Wood/Stone picks also being T1
(`grug_materials/overrides.lua:131–151`). User follow-up keeps these as mining
quests; correct that misleading text. F4 now includes renewable charcoal as
fuel, but not coal substitution in Steel or automatic acceptance by coal quests.
No renewable natural ore spawning. Density alone cannot guarantee a quick find.

## Packages and model assignment

| ID | Owner | Scope | Independent reviewer | Dependency |
|---|---|---|---|---|
| F1 | Sol | Eating sound and modest HUD food motion | Astra | Existing input contract |
| F2 | Sol | Boar targeting box | Astra | None |
| F3 | Sol | Authoritative POI names on atlas | Astra | None; coordinate socket seam with G1 |
| F4 | Sol | Common furnace fuel policy, charcoal, flame/arrow UI and continuous burning | Astra | Furnace timing clarification; see linked follow-up |
| G1 | Astra | POI ground, street junctions/landings, plot approaches | Other Astra | Terrain interface agreement |
| G2 | Astra | Terrain scale/transition, lake geometry, beach materials | Other Astra | Shared geometry interface frozen first |
| G3 | Sol | Aquatic plants, coral patches, ambient fish | Astra | G2 water classification contract |
| F5 | Sol | Cheap basic-arrow recipe and Basics entry | Astra | Approved |
| R1 | Sol | Approved full-tier ore/gem numbers and starter quest wording | Astra | Approved |
| I1 | Root Astra | Integration, living docs, minimal gates, playtest guide | Non-author Astra/Sol | All accepted packages |

F1–F3 may share one Sol worker but remain independently reviewable commits.
All listed packages are authorized by the Round 21 Go.

### F1 — Immediate eating feedback

`grug_abilities/input.lua` owns the 1.5-second hold and cancellation;
`grug_food/init.lua:206–236` currently plays sound only after consumption.
Keep one portion per press, RMB interaction priority and all existing cancel
rules. Start feedback immediately on a valid food hold; sustain bite feedback
through the wait, stop on release, completion, slot/item change, death and
interaction cancellation. No consumption or benefit before the deadline.

Reuse the existing three licensed `grug_food_eat` variants at gain 0.5
(`grug_food/LICENSE-media.md`, Lord of the Test sources). Schedule bounded
repeated bites or one stoppable loop according to clip duration; avoid layering
many overlapping sounds or an extra loud completion sound. Actor-local playback
is sufficient. No separate nearby-player sound simulation is required.

VoxeLibre reference `mods/PLAYER/mcl_hunger/init.lua:246–255,447–482,505–513`
uses a HUD image with small vertical movement while hiding the native wield
image. This works on stock clients; it is a visual substitute, not movement of
the engine's actual first-person mesh. Reuse that small presentation approach
with our food textures, license attribution if code is copied, conservative
motion and proper restoration of owned HUD state. If a usable image is absent,
fall back to sound. Do not build a general held-item animation framework or
camera-mode synchronization. Escalate rather than expanding this polish task.

### F2 — Boar targetability, not movement inflation

`grug_mobs/boar.lua:44–58` and `boar_variants.lua:38–45` use collision bounds
`{-0.45,-0.01,-0.45,0.45,0.86,0.45}` and no separate selection box. Mobs_redo
therefore inherits this small box for targeting. Add a separately padded,
yaw-following selection box, shared by base and variants, keeping collision
geometry unchanged. Confirm model forward axis/scale before choosing extents.

A cheap one-family rest-pose B3D bounds read plus visual inspection is useful;
do not treat raw vertex bounds as animated silhouettes. No full roster scan,
automatic animated-envelope computation or per-frame hitboxes. User reports
other families as found; a later targeted fix follows the same method.

### F3 — Preserve the existing authored POI names

Names already exist in `wp40/r20_poi_catalog.lua` and roster `profile.label`.
They are discarded through `r7_runtime.lua:473–485`, `r7_loader.lua:80–93`
and `grug_core/settlement_sockets.lua:241–275`. Atlas `grug_map/page.lua:16–58`
then humanizes internal keys into “R20 Anchor 014”. Carry the existing label
through this real projection/registry seam and use it on the atlas. Do not
invent 70 replacement names or maintain another name table. Keep IDs, positions
and questgiver identities stable. One real-registry example must retain
“Tarnwatch Fold”; include ordinary older profiles as well.

### G1 — One owner for constructed-ground integration

Confirmed findings:

- `height.lua:2737–2772,5134–5142` emits anchor `land_grade` through the blend
  envelope; `planner.lua:1369–1382` treats it like paved path ground with
  clearance. This conflates terrain fitting and visible paving. Village
  core/fitting/blend widths are 24/96/160; outposts 16/64/112. Simply changing
  the POI's central art cannot remove the broad stone apron.
- `wp13/street_plan.lua:70–76,130–159` intersects finite run rectangles;
  a right-angle endpoint lacks the outside quarter. `avenue.lua:394–510`
  already solves common junction heights.
- `r7_settlement.lua:1385–1413,1461–1477,1553–1561` writes core/plots then
  overlays and uses **first-run-wins per voxel**, not last-run-wins. This still
  permits inconsistent different-height surfaces.
- Nhal Veyr plot fitting builds skirts and clears inside the plot, without an
  outside terrain apron (`wp13/nhal_veyr_plot.lua:12–35,61–75`). Current living
  design describes that older behavior and must be revised after approval.
- Kezamba separately composes avenue, core threshold and gate ramp
  (`kezamba.lua:235–243,1118–1133`, `kezamba_ramp.lua:193–265`). Treat their
  endpoints as additional seams; do not assume the L-junction fix covers them.

Implementation direction:

1. Preserve reservation/exclusion extents and anchor coordinates. Distinguish
   natural fitted terrain from actual foundations/paving. Use local biome or
   cultural ground and natural edge blending around POIs; avoid gratuitous
   clearance outside the actual structures, paths and access area.
2. Emit one explicit complete junction footprint and height, using the existing
   height solver. Trim incident segments to its ports. Suppress rails, kerbs
   and lamps across connected openings. No new global route/pathfinding solver.
3. Use the same explicit endpoint-height/ownership discipline for core/gate
   landings and door approaches. Compose final traversable surfaces deliberately
   rather than relying on arbitrary overlapping voxel writes.
4. Fit a bounded natural collar with uphill cuts and downhill fill around
   building plots. Guarantee each intended entrance has a traversable street
   connection and headroom. Retaining walls may remain elsewhere; do not
   require the entire perimeter to be equally accessible.
5. Calculate fitting before final street emission; later fitting must not cut
   a finished staircase. Actor socket heights, protective roots and chunk
   clipping use the same final placement. Reuse shared helpers across all six
   capitals; check race-specific endpoint exceptions explicitly.

Owner files: `wp13/street_plan.lua`, `avenue.lua`, relevant capital/ramp/plot
files, `wp40/r7_settlement.lua`, planner grading material consumer. G2 owns
`height.lua`; G1 submits its small producer change to that owner, avoiding
parallel writers. Do not shrink reserved masks or expand the known frontier
bandit 16/24-width discrepancy as a shortcut.

If shared six-capital fitting grows unexpectedly, prioritize complete junctions,
the two verified Kezamba landing seams and bounded entrance collars. Escalate
any required universal refit; do not silently drop other access defects or
replace this package with a new street architecture.

### G2 — More natural terrain, inland water and coast transitions

The current system is not just two noise functions. `source/simple_map.lua:805`
defines broad profiles; `height.lua:1189–1287` samples them on a 64-node grid
with bilinear interpolation. Ordinary profiles have two broad octaves,
mountains three, plus two detail octaves at periods 64 and 32.

| Profile | Broad elevation range above water | Detail amplitude |
|---|---:|---:|
| Wetland/delta | 2–24 | 3 |
| Lowland | 8–56 | 6 |
| Rolling hills | 24–96 | 9 |
| Plateau | 56–144 | 10 |
| Highland | 96–224 | 12 |
| Mountain | 160–360 | 16 |

Broad periods span 256–1280 nodes. Owner/profile changes interpolate within
64-node cells; landmarks additionally blend profiles. Settlement/housing/road
grading can flatten the visible result. Thus two visually separated scales are
plausible despite more than two functions.

Recommendation: preserve continental geography and tall mountain regions;
improve ordinary transition smoothness and redistribute detail toward a missing
128–192-node hill scale. Reuse or retune an existing octave first. One extra
bounded 2D octave is acceptable if necessary; it is constant local sampling
work, not erosion/simulation, but no runtime percentage is promised. No
per-column neighbor search or large new cache without justification.

Approval grants root bounded visual authoring discretion: choose tuning values
within existing broad profile roles/ranges and fixed functional masks, then
freeze them before delegation. Retune existing scales first; at most one new
128–192-node octave. Exact hill shapes and modest lake-edge offsets are visual
iteration choices, not authorization for a geography redesign.

Inland water currently unions discs and straight varying-width segments
(`simple_map.lua:286–308,1834–1854`). Existing depth variation already spans
1–3, 2–6, 5–11 or 8–15 nodes by nominal depth class
(`height.lua:1333–1348,1550–1577`); it lacks a continuous shallow-margin/bowl
profile. Add bounded deterministic shore irregularity and shallow-to-deep
cross-sections, retaining fixed water levels and reach connectivity. Reuse
existing bed-material choices and add modest spatial variation where needed.

Classification, banks, bottom and spatial candidate bounds must use the same
perturbation. Fade it out near narrow reach connections, fords, roads, authored
civic water and waterfall joins. Natural ordinary lakes get variation; no
requirement to deform every protected lake edge. Do not build watershed or
erosion simulation, arbitrary new lakes or a second water authority.

Beach/cliff runs currently have length 48 and only four-node lateral blending;
material remains the selected run's profile during height blending
(`height.lua:5354–5490`, `r6_content.lua:743–770`). This is a credible surviving
cause of high sand sides; exact seed cells remain to verify. Widen bounded
lateral transitions where needed, and restrict sand to low/gentle shore
surfaces; expose local rock/soil on high steep sides. Preserve deliberate cliffs
and established beach shape. This is not proof that the earlier fix regressed.

`preparation_source.lua:70–85` already consumes final surface heights and
functional extents. Verify changed terrain remains covered by surface pregen;
do not change scheduling or run full-world throughput measurements. Deep water
currently contributes only its upper eight visible nodes when the bed is deeper;
this round does not promise full pre-generation of all underwater volumes.

### G3 — Water decoration and a small ambient fish increment

Separate static mapgen plants/coral from runtime fish. Use suitable existing
licensed lilies/submerged plants with local water-depth and biome predicates.
Do not place on reserved travel/structure cells or above the water surface.

`world_content.lua:13–16,106–127` uses a linear modular hash and reef gates of
1/8 of 16x16 cells, then 1/16 of columns at depths 2–10. There is no authored
directional coral-strip template; correlated sampling is the first suspect.
Use a reef-specific well-mixed deterministic stream and small irregular patch
footprints with gaps/species/size variation. Keep approximate density, do not
merely rotate single coral cubes. Avoid changing unrelated plants' streams.

Fish proposal: one suitable licensed animated passive fish family, zero XP and
no loot, using existing runtime spawn/cap infrastructure and underwater support
checks. No schools, breeding, new fish economy, fishing rewards, predator AI or
ecology simulation. The current game has fishing food but this investigation
found no existing live fish entity to simply enable. If an acceptable asset or
bounded water movement is unavailable, pause this subtask rather than expanding
the whole round. Static water improvements can still finish.

Approval of D4 grants root bounded asset/spawn selection after a small
license/animation/movement preflight. Record species/source, scale, freshwater
habitat/depth and cap before delegation, within the existing ambient critter
budget. No worker invents a new uncapped population. If simple aquatic movement
does not fit, bring the candidate and added cost back to the user.

Owner files: world content catalog/decorator, its strict content projection,
and fish registration/spawn/media. G2 supplies stable water semantics first. Root
serializes shared `r6_content.lua` edits with G2/R1.

### R1 — Resource tuning and approachable first cook quests

Apply only approved density/depth choices from the decision sheet and follow-up.
Keep the demand-driven root sampler, each resource's existing vein cap,
exclusions and regional gem rules.
Update production manifest rows and strict expected rows together; update
living design. Do not restore per-host SHA ranking or rerun a historical full
census. A small deterministic eligible-host budget and real writer sample
checks the change; it does not certify six-race parity for a new release.

Starter quests retain mined coal and their existing counts; correct misleading
bronze-only text. Quest IDs, rewards, later mining quests and protected scenery
remain untouched unless explicitly approved.

## Parallel schedule and integration ownership

1. After Go, root records decisions and freezes the small shared geometry
   interfaces (grade vs paving, junction/landing ownership, water classification).
2. Wave A: Astra G1, Astra G2, Sol F1–F3 in three worker slots. Root coordinates
   overlapping file handoffs, docs and review scheduling.
3. As the Sol slot frees, R1 can proceed independently. G3 static work starts
   against the frozen water interface; final integration follows G2. Fish can
   proceed without waiting for water geometry if its predicates are unchanged.
   F4 is an additional independent Sol lane, queued into a free slot; its
   common station transaction/UI changes receive independent Astra review.
4. Independent review on immutable candidates; G1/G2 cross-review only code
   they did not author. Review the combined seams again after integration.
5. Merge locally and sync from main after the approved gates. No remote push.
   Deliver one short fresh-world playtest guide and remaining observations.

## Minimal verification budget

The user explicitly prioritizes playable iteration over extensive mapgen
test campaigns. The completed planning phase ran no Lua or engine tests. Implementation:

- Mandatory changed-file Lua 5.1 parser, SETGLOBAL inspection and all five
  source sweeps; include changed tools code explicitly.
- Cheap focused development fixtures under LuaJIT only. No full-world runs,
  seed fleets, exhaustive capital/roster VM populations, resource census,
  repeated startup audits, PUC development loops or new visual-test framework.
- Geometry micro-cases: L/T/X junction coverage, sloped port, core/gate
  threshold, uphill/downhill entrance, clear headroom and chunk-split agreement.
  Test final walkable cells, not just abstract equal heights.
- Changed terrain/content projection must exercise real `r7_manifest.new`
  and `planner.plan_slice` plus relevant final writer, not a synthetic receipt.
  Reuse existing scaffolding with a bounded input list; do not run its entire
  historical corpus merely because it is available.
- Target at most **eight representative 80³ owner chunks in total** for
  integrated writer checks, chosen to cover reported stair/beach seams, a POI
  apron and inland-water boundary. Use scalar profile/placement micro-cases for
  other variations. Sharing samples across packages is preferred.
- Round-wide test parallelism is capped at **six CPU workers** by the latest
  user instruction. Each heavy command has a **120-second timeout**. Stop and report a budget
  overrun; do not silently expand the fixture fleet or repeat a timeout. One
  short matched timing comparison only if additional noise/query work is added,
  preferably using the same already-required samples.
- On frozen final Lua bytes, one small PUC-5.1 micro-KAT and the identical
  LuaJIT fixture with equal canonical digest. Keep expensive geometry population
  in JIT-only samples; final portable conformance targets changed arithmetic,
  ordering and control-flow seams. No reviewer rerun of accepted artifacts.
- GUI/visual acceptance belongs to the user's fresh-world playtest. No lengthy
  agent engine run is scheduled. A specific unresolved runtime blocker may
  justify one bounded isolated probe after root review, never the personal
  world. No additional broad tests without a concrete failure or agreed need.

These scoped checks do not replace outstanding public-release census/parity
gates. Record that limit, rather than claiming new world-wide certification.

## Escalation and completion

Pause only the affected lane if it needs a new terrain/road architecture,
unbounded route fitting, reservation relocation, a general animation system,
fish simulation, broad measurements, engine/client changes, or an unapproved
economy decision. Explain a smaller useful alternative to the user.

Completion needs clean independent review, bounded evidence, updated living
design and status, local commits/merge/sync, and a short route covering eating
cancel feedback, boar aim from the side, atlas names, city entrances/stairs,
POI ground, hills/lakes/beaches/coral and shallow mining. Visual quality is
accepted through that playtest, not inferred from passing code fixtures.
