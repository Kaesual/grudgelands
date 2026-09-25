# Round 22 Phase 3b: stale-rule audit

Date: 2026-09-25. Read-only audit for
[the Round 22 plan](../planning/round22-natural-world-plan.md), Phase 3b
item 5. Base: `main` at `ea05b045`, which is Phase 3 merged, with coast
profiles, capital terraces and the map relief budget still in the code. It
builds on [the Phase 0 audit](round22-audit.md) and does not repeat it. No
repository file was changed apart from this document.

Terms:

- **Verdicts:** keep; relax (to a rough target); remove; defer (to phase N).
- **Effort:** S is under half a day, M is about a day, L is several days.
- **P5 / P4 / P6:** the finding blocks (**B**) or shapes (**S**) that phase.
  Water runs before roads (D30), so P5 comes first.
- **"3b-n":** already handled by the running Phase 3b lane n (coast,
  capital surroundings, map relief, alley stubs). These rows are listed only
  so that nothing is missed.

## Summary

1. **The planner's hydrology and road contract blocks Phase 5 and Phase 4
   (R1, R2, R3).** Phase 3 switched roads and water off by data. It did not
   touch the R5 planner contract (`r5.lua`, `planner.lua`), which:
   - interns every water and road feature ID from the static `source`
     tables when the session is built;
   - requires a registered relation (rapid, waterfall or confluence) for
     every step between reaches, plus at least one hydrology interface;
   - writes range-2 river water only for *named* hydrology.

   Per-seed rivers and pathfound roads cannot pass it unchanged. The retired
   tables in `source/simple_map.lua` are still load-bearing only because this
   chain of checks and load asserts needs them. They have to go in one commit
   together with the checks, at the start of Phase 5.
2. **Old POI placements carve square plates into the new terrain (R4).** This
   is the biggest remaining "stamp". Every anchor except starts and capitals
   flattens an axis-aligned square core with a square smootherstep collar, at
   a fixed x/z inherited from the flat world. Measured:
   - 41, 44 and 47 of 88 POI anchors (on 3 seeds) cut or fill **16 nodes or
     more**;
   - the worst cases reach 119 (a clash site), 116 (a dragon), 93 (an
     outpost) and 80 (an apex mine);
   - the nominal `max_cut 8 / max_fill 6` quietly falls back to the midpoint.

   Roads end at these POIs (D18, D19), so this shapes Phase 4.
3. **Capital civic water is tied to frozen WP13 footprints and old fixed
   heights (R6, D7, D8).** Examples: the Kezamba cenote surface is +64 while
   the capital's ground target is 10–36; the Lethariel NE "mere" quarter; the
   Highcourt SW lots staggered around two river arms. Phase 5 has to fit
   these masks or re-cut the blueprints. D26's "one real river through
   Highcourt" conflicts with lots laid out for a fork.
4. **Absolute-height rules from the flat world now cut out large areas
   (D10, D11).** Measured on the natural field:
   - 7.5 % of land is above y 200, where every surface mob spawn row stops
     (50 rows cap at 200). That includes 55 % of Wyrmglass, 50 % of Stormvault
     and 38 % of Stormscale.
   - 41 % of land is above y 80, the Reed Angelfish cap.
   - Only 20 % of jungle land is at y 32 or below, the cap for emergent
     jungle trees.
   - Native caves are kept only below v7's own heightmap, so high relief is
     probably solid stone. This is structural, and not measured in-game.
5. **Design text still carries WP40 proof language and old fixed geometry
   (D1–D18).** Examples:
   - the 32-seed exact-rational resource parity;
   - the 10 % boat-route parity rule and fixed approach coordinates;
   - "no adequate alternate crossing" bridge protection, which is a graph
     property D14 forbids;
   - station floors, gate stations, the 144-node straight approach, and the
     Battlegrounds causeway, aqueduct and war-road routes;
   - hard coastal-housing minima in `world.md`.

   Most of it is S-effort text relaxation.
6. **Hot path: the old 3–4 ms scattered `terrain_height_at` is gone (H1–H4).**
   - Scattered queries now average 0.18 ms, 0.42 ms on the coast and 0.65 ms
     in a capital envelope. Removing the coast profiles cuts land queries by
     another 43 %.
   - Dense planning costs 86–216 ms per cold chunk (height and
     classification), within the lane B total of 252 ms per tile.
   - The one cost that Phase 4 and Phase 5 will hit is the **whole-map
     grids**. At an 8-node spacing the natural field alone costs about 13 s per
     session, and final heights about 45 s. The session is built in both the
     main and the emerge environment. Route and river layouts should
     therefore be computed once, in main, and handed to emerge over the
     existing `ipc_set` channel or through a world cache.

## 1. Design rules

Line numbers refer to `ea05b045`.

| # | Finding | Where | Why stale or costly | Recommendation | Consumer / code | Phase | Effort |
|---|---|---|---|---|---|---|---|
| D1 | Coast profiles are still the design rule: 40/25/20/15 % beach, bluff, cliff and terraced cliff, 1:4–1:8 beach ramps, and relief-keyed "mountain coasts have no sand" | `world_zones.md` §7.4 L422–438 | D27 | remove; replace with the D27 material rule based on actual shore slope | Code live in `height.lua` L44–188, 710–835; `r6_content.lua` L690–780 picks material by profile name; `planner.lua`, `r6_planner.lua` and `r6_settlement.lua` hard-require the `coast_profile_at` seam | **3b-1**. P5 S: the freshwater branch of `coast_profile_applies` must not survive into lake shores | M |
| D2 | The Round 21 note keeps the lake-edge and beach/cliff rules, and fixed Frostbarrow/Moonfall lake levels | `world_zones.md` L1548–1561 | D26, D27; `hydrology_edge_at` is already retired | remove those items from the "remain" list; coral stays; waterweed, lily and fish move under P5 | none | P5 S | S |
| D3 | Shore rule "first dry column exactly at water y" has no case for stepped reaches | §2 L108–113, §7.4 L439–442 | A bank beside a fall or rapid touches two water levels | keep, and add one exception: step, fall and rapid faces are transitions, and the lower reach decides the bank. Drop "route-deck/culvert" | planner shore checks | **P5 B** (as text) | S |
| D4 | Island approaches fixed at z = ±125, 96 wide; boat routes differ by at most 10 % in length | §7.4 L401–404, §9.4, `world.md` §2b/§4b, `boats.md` L165 | (a), and against D24. The 10 % rule is unread data (`boat_parity_policy`: 0 readers) | relax to "one northern and one southern approach, roughly equal". Keep the fixed landings: they are measured on land on 4 seeds and damped in the warp | `height.lua` boat floor, `zone_field.lua` L521 | — | S |
| D5 | Dragon channel "at least 200 water nodes, 104 hard no-flight"; `mounts.md` "certified" strip | §7.4 L397, `mounts.md` L315 | Code enforces only `min_strait = 104` | state one rough target (about 200) with the self-check floor at 104; drop "certified" | `zone_field.lua` L816 | — | S |
| D6 | Legacy hydrology rows kept "as legacy data", with fixed `water_surface_offset` (cenote +64, Lethariel +34, Highcourt arms +34, Raincall +72, tarns +62), seal profiles and waterfall omission rows | §7.4 L393; `source/simple_map.lua` L1071–1143 | Heights from the old world. Capital targets are now 10–55 | P5 takes surfaces from the terrain, reuses at most the centrelines as hints, then deletes the rows (with R3) | read only by the R1 validation chain | **P5 S** | M |
| D7 | Capital blueprints are cut around the old civic water: Lethariel NE mere (3 lots), Kezamba districts "pinned to the ground that exists", Highcourt "between two river arms" | `settlements.md` L184, L321–395; §8.4 L741 | Against D26 ("a real river through Highcourt") | treat the committed footprints as keep-out and water envelopes; add natural shores only outside plots; decide fork versus single river for Highcourt together with its blueprint | `wp13/lethariel_quadrants.lua` L13–40, `kezamba_lots.lua`, `kezamba_lagoon.lua` (30,354-column mask), `highcourt_quadrants.lua` L14–26 | **P5 B** | M |
| D8 | Freshwater content with no host until P5: wild Frost Melon, Reed Angelfish, waterweed, lily; shipwright display boat "floating in the adjacent water" | Round 10 L1505, Round 21 L1562–1575; `boats.md` L45–65; `settlements.md` L536 | D26; allowed as a temporary state under D31 | P5 gives Frostbarrow/Whitebridge freshwater shores and water beside the two shipwright villages, or relaxes the boat text | `world_content_catalog.lua` L38, `grug_gathering/catalog.lua` L66–70, `reed_angelfish.lua` L6 | **P5 S** | S |
| D9 | 600×500 "dry start core"; `world.md` R1 says a flooded start "cannot generate" by construction of it | §7.1 L311, `world.md` §2 L155 | The fixed core no longer owns anything (`simple_map.lua` L184–205) | replace with "no river or lake within the start's calm radius (about 300) except its civic pond" | none | P5 S (exclusion) | S |
| D10 | `world.md` §2b fixes the old waterfall mechanics (named reaches, one-node receiver opening, no falling-liquid columns) | `world.md` L306–315 | (c); only source data today | defer to P5, which picks few and simple step types. Keep the river-water material rule | none | P5 S | S |
| D11 | Spawn caps: `max_height 200` on all surface rows (50 rows), 300 on crags rows (9), Reed Angelfish 80 | `biomes_mobs.md` §4 L787–789; `boar.lua` L158 and others | Measured: 7.5 % of land above 200 (up to 55 % in Wyrmglass), 41 % above 80 | relax: raise the surface caps to the flight ceiling (600) or drop them, since zone palettes already gate spawns; set the angelfish cap relative to the water body | 59 spawn rows | P5 S, P6 | S |
| D12 | Absolute y decoration gates: snowy pine ≥ 60, emergent jungle ≤ 32, papyrus 1..4, "snow above y 80" | `biomes_mobs.md` §2.1 L193–240 | Measured: 20 % of jungle land is at or below 32. Papyrus only at sea level. The y-80 snow rule is not in code | relax: relative or slope/water-based gates; tie papyrus to water adjacency (P5); delete the snow text | `r6_planner.lua` L557–562 (verified) | P5 S, P6 | S |
| D13 | Gravesalt Rock Salt needs `grug_beach` biome **and** `default:sand` shore; Gravesalt is a highland escarpment | `biomes_mobs.md` §2.2 L274; §11 L1063–1073 | D27 puts sand only on low, gentle shores, so the only mainland Rock Salt could vanish | relax: accept gravel or stone in Gravesalt; count sources after 3b-1 | `grug_gathering/catalog.lua` L181 | 3b-1 follow-up | S |
| D14 | Surface stone-exposure thresholds ("rise ≥ 12 over 8 nodes, patch > 760", 300/440/780/880) tuned on the flat world | §7.6 L558–571 | (a) | defer to P6 (rock and scree); guide values | `r6_content.lua` L795–815 | P6 | S |
| D15 | Resource parity: "strict 5 % … fixed 32-seed corpus … exact rational … exactly 384" | §11 L947–962 | (b); contradicts the Round 22 note above it and D5/D21 | relax: "race regions within about 5 %, spot-checked" | tools fixture seam only (`r6_settlement.lua` L1669) | — | S |
| D16 | Byte-level algorithms in the design (`resource_root_shuffle_v1` SHA-256 frame, Lehmer stream, canonical candidate rank, "fails closed … frozen R6 slot API") | §11 L925–993; `biomes_mobs.md` §2.1 L255–262 | (b). Cost: `r6_hash` builds a framed string plus `core.sha256` per eligible column and decoration row | remove from the design doc (the code is the spec). P6 swaps in a cheap integer hash if a chunk profile shows the cost | `r6_planner.lua` L570, `r6_settlement.lua` L1446, 1854, 2623, 2743 | P6 | M |
| D17 | Capital terraces (steps 4/2/3, a 32 blend, a 96-node collar); walls "follow the terraces"; station floors as a hard lower bound; calm radius stated as both "about 500" and 260/520 | §12 L1095–1103, L1136; §7.6 L517; `settlements.md` L153 | D28. Stations are retired (`grep station height.lua` gives 0) | remove terraces and station floors; state one calm radius guide value | `height.lua` L313–331, 568–600 | **3b-2** | M |
| D18 | §13.1 R7 cutover and "exact authenticated native baseline"; substrate rule keeps native caves only at y ≤ the v7 heightmap | §13.1 L1200–1229, §7.6 L572–579 | (b), and a P6 risk: highland relief above v7's own surface has no native caves. Structure verified at `map_adapter.lua` L66–71; the in-game effect is not measured | drop the cutover and authentication text. P6 decides: accept solid mountains, or relax the manifest pins (`mgv7_spflags` string, floor −37) to steer v7 | `map_adapter.lua` L329–339, `planner.lua` L498 | P6 | M |
| D19 | §13 input rules ("exact safe-integer … half-away-from-zero … programmer errors") and "a 128-node index serves route, hydrology" | §13.2 L1253–1260, §13.3 L1295–1299 | (b); dead reference | relax to "integer coordinates"; P4 and P5 choose their own spatial index | `zones.lua` L701–745 builds a hydrology index that is always nil | P4/P5 S | S |
| D20 | Routing "found once, when the world session is built … cached for the session" | §9.2 L811–815 | The session is built in main **and** in emerge; see H5 for the cost | route once in main and pass the polylines through `ipc_set` (already used, `r7_loader.lua` L132), or cache per world like the map relief | none yet | **P4 S** | S (text) |
| D21 | Only a bridge "without an adequate alternate crossing" may be hard-protected | §7.5 L452, §11 L1005, L1012; `world.md` L151; `housing.md` L603, L630 | A connectivity property to prove, which D14 forbids. Not built (`grep irreplaceable\|alternate_route\|critical_bridge` gives 0) | remove; all open-world bridges are mutable, and the WP46 guard covers explosions | none | **P4 S** | S |
| D22 | Start roads end at the "authored gate station … part of the route's authored geometry"; capitals contract: "exactly four routes reach a capital … dead straight for the last 144 nodes", `route_gates_kat` acceptance, ingress, "both interpreters", "digest continuity" | `settlements.md` L83–90; `wp13-capitals-pois-contract.md` §2.1.1 L97–137, L24, L149, L164 | D9, D1, D3 | keep "road arrives at the gate's own ground, passage ≥ 7 wide, centred" and a short gate-axis approach (about 16–32 nodes); P4 pathfinding does the rest; mark the rest historical | blueprint `GATE_OUT` 261/256 are the real gates; `source.capital_gates` has 0 runtime readers | **P4 S** | S |
| D23 | Housing road exclusions "exactly the three fixed classes"; "deterministic road meanders move the analytic corridor" | `housing.md` §6 L473–477 | P4 roads are pathfound and cached; trails may be dropped (D19) | relax: corridor is the distance to the routed path | see R5 | P4 S | S |
| D24 | Battlegrounds identity promises "raised causeway, ford and aqueduct path form three routes", trenches, siege ramp, two high approaches, a coastal war road | `world_zones.md` L699–702, §11 L1028, L1072; `housing.md` L624 | D8, D9, D13 | reword as flavour that "may appear as POI or dressing"; P4 owes none of it | none | P4 S | S |
| D25 | Route, hub and "zone graph" wording: "enforce authored routes", "road patrol legs", "authored travel hubs … every progression route must connect", "authored zone graph fixes cultural routes" | `world.md` L452, L483, §6, L884, L979 | D9, D14. Outpost patrols are straight lines between outposts (`camps.lua` L315–345) and may be blocked by the new relief | reword; optionally let P4 trails carry the patrols | `grug_mobs/camps.lua` | P4 S | S |
| D26 | Coastal housing hard minima: "at least 600 … at least 300 … at most 12 nodes of relief in every 101×101"; "audited … over 32 seeds" | `world.md` §5.1 L689–695; `housing.md` §6 L471 | Contradicts D21 and `world_zones.md` §7.5. `relief_max`, `frontage_min` and `inland_depth_min` have 0 readers | relax to "roughly"; delete the 32-seed audit | data only | — | S |
| D27 | R1 "fail that seed's generation audit … a mandatory graph/POI anchor may never disappear" | `world.md` §2 L178–184 | (b); no generation audit exists (`grep` gives 0). The zone-field self-check already covers anchor in zone and on land | point to the self-check; drop "graph" | `zone_field.lua` L669–838 | — | S |
| D28 | "Coastal housing" listed as a grading step | `world_zones.md` §7.6 L523; `world.md` §1 L111 | Dead: `compose_land` has no housing grade | remove from the grading order | none | — | S |
| D29 | Deep forest capped at "x 1250", east flank strip "x 1251..1500" | `biomes_mobs.md` L314–317, L1119 | Axis cuboid from the old world; `grep '\b1250\b'` finds only POI coordinates | remove | none | — | S |
| D30 | Map relief "where the height query is cheap enough" | `world_map.md` L16–18 | D29 | fixed resolution | `grug_map/base.lua` budget | **3b-3** | S |
| D31 | POI compact cores: square core plus square collar with `max_cut 8 / max_fill 6` | `world_zones.md` §7.5 L455–462 | The design-doc agent rated this as keep. **Overruled by the measurement in R4**: on the new relief the rule produces square cuts up to 119 nodes | see R4 | `height.lua` fittings | **P4 S** | see R4 |

Still right despite their age (keep):

- the shore rule itself;
- bays at least 64 wide;
- river water (range 2) for river reaches and ordinary water for lakes, bays
  and the sea;
- `planned_water` classified in x/z (3 gameplay consumers);
- the depth and protection boundaries;
- fail-closed hard protection (security, not proof culture);
- the start-pad 9×9 lower-median fit;
- road widths 7/16, 5/12 and 3/8 as guide values, with a step of at most one
  node;
- the 96 civic core and gates at ±256 (blueprints depend on them);
- levels by zone;
- the zone-field self-check with its weaker-warp fallback;
- the flight ceiling at 600 (measured natural maximum: 511);
- the authored floor at −37 (Phase 5 river beds must stay above it);
- the preparation resume digest.

## 2. Runtime mapgen code

| # | Finding | Where | Why stale, wrong or costly | Recommendation | Consumer impact | Phase | Effort |
|---|---|---|---|---|---|---|---|
| R1 | **Named-hydrology planner contract** (details below the table) | `r5.lua` L131–448; `planner.lua` L591–744, 889–1000, 1209–1275, 1468, 1494; `r7_content.lua` L295 | Built for 25 hand-authored reaches with pre-registered steps. Today it is dead but still validated (0 of 25 rows carry `civic_core_zone_numeric_id`, verified) | relax early (the Phase 5 watch point): choose the river-water role per column (`planned_water` plus surface). Keep bed and bank seal geometry. Drop the ID and relation checks, or intern them at construction from Phase 5's own reach list (seam change: r5 reads the static `source`) | mapgen only; keep `planned_water` for its 3 gameplay mods | **P5 B** | M–L |
| R2 | **Road feature IDs must be interned** | `planner.lua` L791–803, 952–959; `r5.lua` L216–276 | The static lookup holds 296 refs (maximum 512). Only the 100 anchor IDs are used; 196 are retired-feature IDs. Unnamed `bridge_deck` (clearance ≥ 2) and unnamed `ford` already pass (`planner.lua` L1397–1415) | intern a few generic IDs at construction (one per road class plus `bridge`), or map unknown IDs to 0; use unnamed bridges and fords | mapgen only | **P4 B** | S |
| R3 | **Retired tables cannot be deleted one at a time** (list of load asserts and fail-closed checks below the table) | `source/simple_map.lua`; `r5.lua`; `planner.lua`; `r6_settlement.lua` | Each assert trips on its own | **one mechanical commit at the start of Phase 5** removes routes, spurs, island routes, crossings, ingresses, gates, stations and old hydrology together with these checks and the R1/R2 changes | mapgen only | **P5/P4 S** | M |
| R4 | **POI fittings are square stamps at old fixed x/z.** Every non-start, non-capital anchor flattens a square core (12–32 nodes) with a square smootherstep collar (64–160 envelope). When `[natural−8, natural+6]` is infeasible it uses the midpoint without clamping | `height.lua` L525–567, 616–666 (`half_open_square_excess`); profiles in `source/simple_map.lua` L941–950 | **Measured** (natural core relief 12–127 nodes):<br>• 41/44/47 of 88 anchors cut or fill ≥ 16 nodes (3 seeds)<br>• clash sites: 16 of 16 ≥ 8, maximum −119<br>• dragon −116, outpost −93, apex mine −80<br>• an ASCII delta map shows a square plate cut into a hillside<br>Straight edges and square plates are what goal §1 forbids | relax. Options, cheapest first: (a) small damping bowls around POIs in `terrain_field` (the same mechanism as starts, with a radius of about 40–120); `damp()` then loops over ~100 anchors, so bucket it; (b) round or noise-warped fitting outline, as the start pad already does; (c) a per-seed local site search for the flattest spot within a radius (`approved_candidate_index` exists but is fixed) | Blueprints stand on the core; P4 road and trail endpoints (D18, D19) | **P4 S**, P6 | M |
| R5 | **No road or water claim exclusion exists any more.** The shape dispatch has no `exclude_route_corridor_v1` case (139 rows fall through); the 25 hydrology rows need the civic field (0 have it). Both are dropped silently. The reason map fails closed on unknown IDs | `simple_map.lua` L483–527; `r6_settlement.lua` L782–806 | Resources, gathering sources, POIs and claims will land on new roads and banks | add road-corridor and water-bank kinds computed from the P4/P5 overlay, mapped to `route_or_water` by kind, not by source row | resources, P9G, claims | **P5/P4 S** (B if new IDs reach the reason map) | S–M |
| R6 | **Frozen WP13 civic-water geometry** | `wp13/kezamba_lagoon.lua` (30,354-column mask in ±256; 2,645 core columns unbuilt; decks, piers and three anglers face it: `kezamba.lua` L332–420, 848); `lethariel.lua` L84–95 `MERE`; `lethariel_quadrants.lua` L13–40; `highcourt_quadrants.lua` L14–26, 248, 293 | Dry basins with decks over dry ground are accepted until P5 (D26, D31). The generators (`tools/wp13/kezamba_water.lua`, `lethariel_plots.lua`) were deleted in 66e3832e | inside the civic core, P5 uses the committed masks as the water footprint and shapes a natural shore outside it; route the Highcourt river through the lot-free SW corridor. Restore the generators from git only if the masks must be re-cut | capitals | **P5 B** | M |
| R7 | Civic water is answered only inside axis-aligned fixed cores (start 600×500, capital 512); the hydrology index is filtered on the civic field (0 rows qualify, so the index is nil) | `simple_map.lua` L196–231; `zones.lua` L701–745 | Inert today. If reused, rivers stop at square edges | remove; replace with the P5 water function | none | P5 S | S |
| R8 | P5 switch points in `height.lua`: `column_class` turns hydrology into LAND (L348); single `WATER_LEVEL` (L470); stubbed `hydrology_transition_values_at` (L993); `exposed_shore_at` checks only SEA and BAY (L849); floored heights (L455) | `height.lua` | These are the seams P5 opens | keep the seams. Carving must also floor, to keep the `integer(terrain_height_at)` check in `zone_authority.lua`. **Ask 3b-1** to leave a bank-material hook that takes a water-surface y: the only freshwater-shore material path (`r6_content.lua` L748–770) is fed by the coast profiles it removes | `zone_authority.lua` L289 | **P5 S** | S |
| R9 | Dead per-column work every chunk: `scan_bank_samples` plus `named_wet_values` (12 neighbour reads and an extra tuple per 84×84 halo column); the transition stub validated on every cache miss; `fixed_core_member` for every land column (its `fixed` result has no consumer); `analytic_hydrology_seal` (12 queries, always nil) | `planner.lua` L1046, 1209; `zones.lua` L1155; `simple_map.lua` L423; `r6_settlement.lua` L977–1025 | Cost not measured (the planner cannot be built offline without the engine content contract) | remove together with R1 | none | P5 S | S |
| R10 | Square anchor-blend exclusions: the 6×704² capital and 6×256² start squares exclude **12.4–12.8 % of all land** (measured, 4 seeds) from resources, cultural candidates, P9G and claims; other anchors add 4.6 %; vegetation is exempt | `simple_map.lua` L483–490, 529–533 | The terrain now uses radial bowls (520 and 300); D28 wants an irregular edge | relax: key them to the build footprint or the civic core plus plots | resources, claims | 3b-2 or §11 | S |
| R11 | Load asserts on the old road graph: square gates (L310); start and capital anchors exactly on the zone hub (L780–806); capital reached by exactly 4 routes (L808–827, verified) | `source/simple_map.lua` | `source.capital_gates` has 0 runtime readers; the real gates are blueprint `GATE_OUT`. All 24 hub ±256 gate points are land in their own zone on 4 seeds. The hub assert also blocks D7-style anchor nudges | delete with R3. P4 takes capital endpoints from the blueprint gates and reuses `avenue.lua`'s 1-Lipschitz envelope as a grader of at most one step | none | **P4 S** | S |
| R12 | Coast profiles: 48-node runs, lateral blend, 4-node shore lattice (a cost as well as a look problem, see H1) | `height.lua` L14–188, 668–832 | D27 | remove | the seam is required by 3 modules; stub it | **3b-1** | M |
| R13 | Capital terrace band: `band_value` reads (2r+1)² natural heights per envelope column (up to 49) | `height.lua` L313–331, 568–666 | D28; measured cost in H3 | remove the terraces; keep the 96 flat core plus a blend | capitals | **3b-2** | M |
| R14 | Channel coast exclusion is a fixed rectangle plus 80 (0.52–0.66 % of land, measured) | `simple_map.lua` L511–518 | (a) | relax to a coast-distance shape, like `island_coast` | claims | — | S |
| R15 | `preparation_identity.lua` L4–9 hashes a fixed file list read with `assert(io.open)` | — | New P4/P5 modules must be added (or pregen output is not invalidated); deleted files must be removed (or game load aborts) | keep; add it to every P4/P5 lane checklist | pregen | P4/P5 S | S |
| R16 | Uncalled APIs: `landmark_excluded_at` (still type-checked at `planner.lua` L332 and `r6_settlement.lua` L711); `hydrology_edge_at`, `warp_proof`, `expanded_land_at`, `zone_detail_at`, `coast_signed_at`, `macro_region_at` (grep: definitions only) | `height.lua`, `simple_map.lua` | Harmless | remove in the D4 cleanup | none | — | S |
| R17 | Boat paths and landings at fixed coordinates | `height.lua` L370–411, `zone_field.lua` L273–283 | Still meaningful: measured land/channel/land on 4 seeds. `island_routes` is dead (R5 stable refs only) | keep | channel depth | — | — |
| R18 | Count pins that P4/P5 do not trip: 100 anchors, 38 zones, 42 roster rows, 36 protected columns, 24 apex sockets, 6 start-level anchors | `r7_consumer_payload.lua` L22, `r6_settlement.lua` L835, `zones.lua` L622 | Phase 4 endpoints and trails use existing anchors | keep | — | — | — |

R1 details: the contract has four parts.

- **Lookup at construction.** `build_relational_lookup` builds its lookup from
  `source.hydrology`, the profile tables and `hydrology_interfaces`.
- **Fixed depths and seals.** Depth may vary only for nominal depths 2, 4, 8
  and 12. Seals are fixed at 3 bed layers and 2 bank nodes.
- **Registered relations.** Neighbouring wet columns of different reaches and
  surfaces must be joined by a registered rapid, waterfall or confluence;
  otherwise the planner fails with "bank samples lack one accepted relation".
  Waterfall contact faces require terrain to equal the lower bed exactly.
- **Named water only.** Range-2 river water is written only for named
  hydrology. Unnamed wet columns get `default:water_source`, which spreads 8
  nodes and spills over steps.

R3 details: these checks trip when a single table is removed on its own.

- `source/simple_map.lua` L780–827: the hub and 4-route asserts (R11).
- `r5.lua` L224–229: each crossing must name an existing route.
- `r5.lua` L270–276: each bridge, ford or causeway interface must name its
  crossing.
- `planner.lua` L659: at least one hydrology interface must exist (verified).
- `r6_settlement.lua` L782–806: the exclusion reason map is keyed by the IDs
  in `source.claim_exclusions`.

Tables in `source/simple_map.lua` and who reads them now ("once" means once
per session construction, i.e. once in main and once in emerge):

| Table | Readers now | Verdict |
|---|---|---|
| `routes`, `route_profiles`, `route_curve`, `route_stations`, `capital_gates`, `crossing_interfaces` | `r5.lua` L155–230 (stable refs, crossing validation), once; the rest source-internal | inert but load-bearing (R3); remove at the start of P5 |
| `poi_spurs`, `island_routes`, `coastal_housing_cores` | `r5.lua` L191–204 stable refs only | dead; remove |
| `boat_parity_policy`, `capital_ingresses`, `relief_profiles`, `landmarks`, `claim_exclusion_recipes`, `region_resources` | 0 readers (grep; the 6 ingress hard rows are skipped at `zones.lua` L757 and `simple_map.lua` L519) | dead; remove |
| `hydrology`, `hydrology_profiles`, `hydrology_transition_profiles`, `hydrology_interfaces` | `r5.lua` L132–448, `zones.lua` L696–733, `simple_map.lua` L210–231, `r6_planner.lua` L175–183, `r6_settlement.lua` L842–850 | inert, but at least one interface is required (R1); replace in P5 |
| `claim_exclusions` | `simple_map.lua` L478 (shapes), `r6_settlement.lua` L782 (reason map) | mechanism live; 164 of 314 rows (routes, hydrology, ingress) produce no shape. Keep the mechanism, re-derive the rows (R5) |
| `hard_protection` (+ recipes), `boat_paths`, `island_landings`, `land_primitives`, `bays`, `islands`, `channels`, `housing_masks`, `housing_policy`, `zones`, `anchors`, `anchor_profiles`, `apex_sockets` | live | keep (drop the 6 ingress hard rows; `island_landings` out of r5 refs) |
| `start_core`, `capital_core` | `simple_map.lua` L190, fixed cores, per land column | inert; remove with R7 and R9 |
| `source/catalog.lua` (3,058 lines) | `r7_consumer_payload.lua` L78: 30 rare patrol offsets | keep until D4 (move the offsets) |

## 3. Hot-path cost

**Method.** An offline LuaJIT harness builds the real horizontal and height
sessions, and the `zones` planner source, exactly as `r7_runtime.lua` wires
them.

- Seed `15140735923413111218` unless stated.
- Run under `chrt --idle` on a desktop with light load.
- A copy of `height.lua` without the coast-profile call stands in for the
  3b-1 result.
- Numbers are single runs; allow about ±15 %.
- These are reports, not targets (D32).

The harness scripts live in the session scratchpad and are not in the repo.

| Quantity | Measured | Note |
|---|---|---|
| Construction: horizontal + height | 0.6 s + 1.6 s | Old stack: 9–11 s |
| `zones` planner-source session | 2.5 s, 35 MB retained Lua heap | built in main and in emerge |
| `field.height_at` (noise field), land | 14–25 µs/column | Plan §2.3 quoted ~3 µs for the old noise |
| Horizontal classification | 2–4.5 µs/column | |
| Dense 80×80 chunk, `terrain_height_at`, cold | 48–173 ms (median: random 68, capital 84, start 56) | warm (memo) < 1 ms |
| Dense chunk, planner `column_values_at`, cold | 86–216 ms, including the height | warm < 1 ms |
| Dense chunk split | classification 14 ms, biome lookup 15 ms, field height 33 ms | |
| Zone-field samples per planner column | 2.28 | about 1–1.2 would do |
| Scattered `terrain_height_at` | 0.18 ms average (land 0.29, water 0.05); coastal 0.42; capital envelope 0.65 | old code: 3–4 ms |
| Scattered land query without coast profiles | 0.17 ms (−43 %); coastal: 38 → 8 classifications per query | |
| Whole map, 16-node grid | classify + natural 2.8–3.4 s; final `terrain_height_at` 11.2–11.4 s | same with and without coast profiles |
| Whole map, 32-node grid | 0.8 s; final 3.1–4.1 s | |
| 8-node grid (P4 cost grid), extrapolated | about 13 s natural, about 45 s final, **per session** | ×2 across main and emerge |
| End-to-end chunk time | 252 ms/tile against the 233–241 baseline | lane B, fullspeed method; not re-measured |

| # | Finding | Where | Why it matters | Recommendation | Phase | Effort |
|---|---|---|---|---|---|---|
| H1 | The old scattered-query cost is resolved. The coast profiles are the largest remaining share | `height.lua` `coast_profile_at` | Spawning, NPC placement and mount checks are cheap now | nothing beyond 3b-1 | 3b-1 | — |
| H2 | Redundant zone-field sampling: 2.28 samples per planner column. Neighbour probes (`exposed_shore_at`, coast scans) defeat the one-entry memo in `simple_map.lua` L402; zones and height each classify | `zones.lua` L589, `height.lua` L343, `simple_map.lua` L731 | about 15 ms/chunk (~6 %), estimated from the split above, not measured directly | memo the classification per mapchunk block and share it between height and zones; do it when P5 touches classification | P5 S | S–M |
| H3 | Capital envelope costs about 25 % more per cold chunk (median 84 vs 68 ms) and 0.65 ms per scattered query because of `band_value` | `height.lua` L592–613 | goes with the terraces | 3b-2 | 3b-2 | — |
| H4 | The field is about 5× the old per-column noise cost (14–25 µs), which is most of a cold chunk | `terrain_field.lua` `natural` (8 hill octaves, 6 ridge octaves, warp) | Phase 5 carving adds per-column work on top. Keep it bucketed (distance to nearby reach segments only) and inside the per-chunk memo | report only (D32). If chunk loading is noticeable in play, drop 1–2 fine octaves first | P5 S | — |
| H5 | **Whole-map grids are the real P4/P5 cost.** An 8-node route cost grid costs about 13 s from the natural field, or about 45 s from final heights, per session, in both environments | `r7_loader.lua` (main) and `r7_mapgen.lua` (emerge) both build | Server start would grow by tens of seconds | (1) compute road and river layouts **only in main** and pass the polylines to emerge over the existing `ipc_set` payload (`r7_loader.lua` L126–132), or cache them in the world directory; (2) sample the natural field, not final heights; (3) sample lazily inside the A* frontier, or use a 16-node grid (about 3 s) | **P4 S, P5 S** | M |
| H6 | `r6_hash` + `core.sha256` per eligible column and decoration row | see D16 | not measured | measure with the per-chunk profiler before P6 | P6 | — |

Unmeasured:

- full planner and writer per chunk (needs the engine content contract or a
  headless server);
- the dead bank and seal scans in R9;
- the SHA cost in H6;
- whether high relief really lacks caves in-game (D18).

## 4. What matters for Phase 5 (water) and Phase 4 (roads)

**Phase 5, blocking or first:**

1. R1 + R3 + R9: relax the named-hydrology planner contract and delete the
   retired tables with their checks in one commit.
2. R6 / D7: civic water inside the frozen blueprint masks. Decide the
   Highcourt fork now.
3. D3: shore-rule exception for reach steps.
4. D6: throw away the fixed old water heights.
5. R5: new water and bank exclusion kinds.
6. R8: seams, flooring, and the bank-material hook from 3b-1.
7. H5: river layout once, in main.

**Phase 5, shaped:**

- D8: freshwater content hosts (Frost Melon, angelfish, waterweed, lily,
  shipwright boats);
- D11 / D12: spawn and decoration height caps;
- D9: start keep-out;
- D10: step types.

**Phase 4, blocking or first:**

1. R2: generic road feature IDs.
2. H5 / D20: route once in main, with the natural field and a lazy or coarser
   grid.
3. R4: POI plates at road and trail endpoints.

**Phase 4, shaped:**

- R11 / D22: gate endpoints from the blueprints, with a short gate-axis
  approach;
- D21: no bridge protection by "alternate crossing";
- R5 / D23: road corridor exclusion from the routed path;
- D24 / D25: Battlegrounds routes and patrol wording.

## 5. Decisions for the user

1. **POI plates (R4).** Soften POIs by adding small damping bowls in the
   terrain field (recommended: cheap, and the same mechanism as starts), by
   round/warped fitting outlines, or by a per-seed site search? When: in
   Phase 3b now, or with Phase 4?
2. **Planner water contract (R1/R3).** Relax it to "river water by column"
   and drop the named-relation checks (recommended), or rebuild the interned
   relations from Phase 5's own reach list?
3. **Highcourt water (D7/R6).** Keep the two-arm fork that the lots are laid
   out for (recommended for this round), or one river with a lot rework in
   the capital follow-up?
4. **Route and river layout at startup (H5/D20).** Compute once in main and
   hand it to emerge over `ipc_set`, or use a per-world cache file? The
   recommendation is IPC: no file, no staleness.
5. **Height caps (D11/D12).** Raise surface spawn caps to 600 and make the
   jungle and papyrus gates relative or water-based (recommended), or keep
   the absolute values?
6. **High relief without native caves (D18).** Accept it for now and look in
   the Phase 6 playtest (recommended), or have an in-game probe confirm it
   first?
7. **Design-text cleanup (D2, D4, D5, D15, D16, D19, D21–D29).** Apply as one
   documentation commit before Phase 5 (recommended), or fold each item into
   the phase that touches it?
