AUDIT COMPLETE

Baseline: `2a3088917b10f047dea9561b9f3fd36717619fff` (`2a308891`, 2026-09-19)
Scope: Lane B — world/mapgen, settlements, protection, housing boundaries, resources, and zone/difficulty authority.

This was a strictly read-only source audit. No engine, Lua runtime, census, test suite, network, migration, or personal Luanti data was used. “Complete” means the requested source and call-chain review is complete; it does not imply runtime or full-game conformance.

## Summary

- **A:** 1 material implementation mismatch.
- **B:** 0 missing features from packages claimed complete.
- **D:** 2 unresolved authority/integration conflicts.
- No Critical or High finding was confirmed.
- Current demand-driven resource sampling, depth/harvest gates, direct player protection, difficulty projection, and mapgen bootstrap all matched their governing rules.
- The recorded Dawnmere cave-roof case is source-explained but remains an unresolved boundary decision, not a confirmed implementation defect.
- CAP, MAP-B, WP24, WP34, WP41, WP46 and WP49 omissions are open work, classified E.

## Coverage matrix

| Area | Governing authority | Responsible implementation and check | State |
|---|---|---|---|
| Native terrain and writer ownership | Ruling 35 withdrew the plateau; ruling 40 enabled the coast band | Native noise and `caverns,mountains,ridges` are restored in `mods/MAPGEN/grug_mapgen/wp40/r7_native.lua:180` and `mods/MAPGEN/grug_mapgen/wp40/mapgen_manifest.lua:44`. The loader completes validation before registering the sole mapgen script and publishing authority at `mods/MAPGEN/grug_mapgen/wp40/r7_loader.lua:25` and `mods/MAPGEN/grug_mapgen/wp40/r7_loader.lua:130`. | Match |
| Surface skin, natural openings and stone plate | Ruling 9, 2026-09-19, `audit-input/session-rulings.md:111`; plate ruling at `audit-input/session-rulings.md:504` | The pure `r >= 4`, neighbor/3×3 decision is at `mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua:34`; the old writer defaults off at `mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua:691`; the skin runs after P7 at `mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua:2318`. Anchor opcode 21 now preserves native cave air at `mods/MAPGEN/grug_mapgen/wp40/map_adapter.lua:61`. | Algorithm match; exclusion extent is **LB-D-01** |
| Coast geometry, lake rims and materials | Ruling 10, `audit-input/session-rulings.md:138` | Width/rise/blend, relief shares, lattice radius and tie ordering match at `mods/MAPGEN/grug_mapgen/wp40/height.lua:104`, `mods/MAPGEN/grug_mapgen/wp40/height.lua:139`, and `mods/MAPGEN/grug_mapgen/wp40/height.lua:172`. The band defaults on at `mods/MAPGEN/grug_mapgen/wp40/height.lua:218`. | Shape match; material mismatch **LB-A-01**, integration conflict **LB-D-02** |
| Starts, capitals and direct protection | `docs/design/world.md:130`, `docs/design/world_zones.md:1255`, `docs/design/world_zones.md:1350` | Source defines 532-wide capital, 148-wide start, 128-wide ingress and apex-column volumes at `mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua:1078`. Territory tests hard protection before ordinary ownership at `mods/MAPGEN/grug_mapgen/wp40/zones.lua:1211`. The one `core.is_protected` wrapper is fail-closed for empty actors and delegates previous handlers at `mods/CORE/grug_core/protection.lua:1`. | Direct player path matches; indirect mutation remains E/WP46 |
| Ordinary routes, structures and housing masks | `docs/design/world.md:139`; WP24 open | Route corridors and complete anchor blends are claim exclusions at `mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua:1131`; only capital ingress corridors become hard-protected. Ten housing masks exist at `mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua:569`, with public point validation at `mods/MAPGEN/grug_mapgen/wp40/simple_map.lua:2343`. | Match for shipped authority; mechanics E/WP24 |
| Territory, faction and PvP projection | Exact R4 contract `docs/research/wp40-simple-map-r4-contract.md:452` | Terrain protection and PvP remain separate: `territory_rule_at` checks hard volumes while `pvp_rule_at` does not at `mods/MAPGEN/grug_mapgen/wp40/zones.lua:1211`. This is correct: hard protection changes terrain, not combat. Spawn-domain code consumes the PvP projection at `mods/ENTITIES/grug_mobs/spawn_policy.lua:545`. | Match; player-PvP transaction remains E/WP41 |
| Difficulty and depth transitions | `docs/design/world_zones.md:80` | Start bubbles use squared 100/150-node radii at `mods/MAPGEN/grug_mapgen/wp40/zones.lua:697`; depth takes `max(surface, depth)` and y ≤ −701 is contested at `mods/MAPGEN/grug_mapgen/wp40/zones.lua:1225`. Mob levels consume the APIs at `mods/ENTITIES/grug_mobs/levels.lua:333`; fishing consumes `mob_level_at` at `mods/ITEMS/grug_fishing/catch.lua:50`. | Match |
| Natural resources and root authority | `docs/design/world_zones.md:1089`; finite-resource rule `docs/design/world.md:199` | The Park–Miller demand sampler is implemented at `mods/MAPGEN/grug_mapgen/wp40/r6_hash.lua:183`. Census and live writer both call the same helper at `mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua:1836` and `mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua:2601`. Host, exclusion and land/planned-water checks are applied before placement at `mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua:2478`. No natural-resource respawn path remains. | Match; current supply/access certification remains an open release gate |
| Depth and harvest consumer | `docs/design/world.md:239` | T1–T6 boundaries and resources match at `mods/ITEMS/grug_materials/registry.lua:7` and `mods/ITEMS/grug_materials/registry.lua:115`. Mining checks protection, depth and resource tier in that order at `mods/ITEMS/grug_materials/mining.lua:185`. | Match |
| Gathering placement | Exact source and host rules at `docs/design/world_zones.md:1209` | Catalog rows match the closed source sets at `mods/ITEMS/grug_gathering/catalog.lua:81`. P9G validates zone, biome, shore and exact P7 support at `mods/MAPGEN/grug_mapgen/wp40/r7_p9g.lua:272`, and records authoritative surface-level brackets at `mods/MAPGEN/grug_mapgen/wp40/r7_p9g.lua:259`. | Match except Rock Salt conflict **LB-D-02** |

## A/B/D findings

### LB-A-01 — Mountain and high freshwater surfaces do not enforce the decided material rule

- **Class / severity:** A / Medium.
- **Requirement:** The 2026-09-19 coast ruling requires mountain coasts—including both dragon islands—to have no sand, and plateau/highland/mountain freshwater rims to use stone or gravel (`audit-input/session-rulings.md:163`).
- **Implementation:** Both mountain islands deliberately retain a 15% `grug_beach` logical-biome share (`mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua:115`). Their complete polygons and projections are static coast exclusions (`mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua:1196`), causing `coast_profile_at` to return before mountain profile selection (`mods/MAPGEN/grug_mapgen/wp40/height.lua:5330`). The ordinary `grug_beach` surface remains sand (`mods/MAPGEN/grug_mapgen/wp40/r6_content.lua:86`, `mods/MAPGEN/grug_mapgen/wp40/r6_content.lua:743`).
- **Secondary occurrence:** High freshwater non-beach profiles use `biome_lip`, which can be dirt or mud rather than mandatory stone/gravel (`mods/MAPGEN/grug_mapgen/wp40/r6_content.lua:632`, `mods/MAPGEN/grug_mapgen/wp40/r6_content.lua:688`); Frostbarrow’s plateau tarn is one relevant authored water body (`mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua:1034`).
- **Player outcome:** Sand patches can remain on the two mountain dragon islands. Some high freshwater rims can retain ordinary soil rather than a stone/gravel lip.
- **Confidence / reproduction:** High confidence in the source mapping. Historical immutable population artifacts record substantial island `grug_beach` land, but no current MAP-C census or engine coordinate was reproduced.
- **Existing tracking:** None found; MAP-C is recorded as complete.
- **Recommended correction and scope:** Make the surface-material selector relief- and freshwater-aware, including columns exempt from coast shaping. Do not change coast geometry or static-exclusion ownership. Coordinate this with LB-D-02 before editing.

### LB-D-01 — Cave skin/opening exclusion scope is unresolved at Dawnmere

- **Class / severity:** D / Medium.
- **Requirement and conflict:** MAP-C says skin/openings never operate inside exclusions (`audit-input/session-rulings.md:129`). The later 2026-09-20 ruling explicitly asks whether that means the visible settlement footprint or the wider fitting/blend envelope and authorizes no output change yet (`audit-input/session-rulings.md:734`).
- **Implementation:** Start fitting width is 128 but blend width is 256 (`mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua:864`). The claim exclusion deliberately covers the complete blend envelope (`mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua:1148`). `surface_skin_excluded` consumes the default static exclusion and suppresses both skin and openings (`mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua:2158`, `mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua:2221`).
- **Concrete lead:** At seed `4151598227737528026`, approximately `(-71,19,-2458)`, the source query resolves the 256-node `anchor_002` Dawnmere blend exclusion. That point lies outside the 128-node build square but inside the blend.
- **Player outcome:** Native thin roof can remain there because neither opening nor three-node skin filling is allowed. Whether that is correct is the unresolved decision.
- **Confidence / reproduction:** High confidence in the exclusion call chain; no engine-output reproduction of the reported roof.
- **Existing tracking:** Ruling 56 and `audit-input/planning-draft.md:74`.
- **Recommended correction and scope:** First decide whether cave exclusion is a purpose-specific visible/functional footprint or the full claim/fitting envelope. If narrowed, preserve foundations, build square/apron, routes, water, functional surfaces and POIs; do not alter protection or claim exclusion geometry as a side effect.

### LB-D-02 — “No mountain sand” conflicts with Rock Salt’s exact island host

- **Class / severity:** D / Medium.
- **Conflicting authority:** The latest ruling forbids sand on both mountain dragon islands. The still-recorded gathering contract places Rock Salt in Gravesalt, Stormscale and Wyrmglass and requires logical `grug_beach` on `default:sand` (`docs/design/world_zones.md:1226`, `docs/design/world_zones.md:1240`).
- **Implementation:** The catalog encodes the exact sand host (`mods/ITEMS/grug_gathering/catalog.lua:153`). P9G explicitly bypasses the islands’ broad coast claim envelopes so dry island support remains usable (`mods/MAPGEN/grug_mapgen/wp40/r7_p9g.lua:301`).
- **Player outcome:** Preserving the current Rock Salt host preserves forbidden mountain sand. A surface-only no-sand correction would silently remove the two island Rock Salt endpoints, leaving Gravesalt as the only valid source.
- **Confidence / reproduction:** High confidence from the exact host predicate and consumer chain. Historical ledgers contain accepted island Rock Salt records; no current-seed census was run.
- **Existing tracking:** None found.
- **Recommended correction and scope:** Obtain an explicit resource ruling. The least disruptive option is to retain all three named-zone endpoints but give island Rock Salt a stone/gravel-compatible support predicate. Update the gathering contract, catalog, P9G checks and endpoint-access fixture together.

## Stale/superseded documentation — Class C

| ID | Stale statement | Current authority/result |
|---|---|---|
| LB-C-01 | `docs/design/world_zones.md:479` still specifies R8 coast widths/shares; `docs/design/world_zones.md:605` still specifies the R8 connected-mouth writer. | Superseded by 2026-09-19 MAP-C rulings; current code uses the wide band and natural surface skin. |
| LB-C-02 | `README.md:272` and `BACKLOG.md:386` still say connected cave mouths are live. | The old writer defaults off; surface skin/openings are live. |
| LB-C-03 | `docs/design/world_zones.md:1446` implies hard protection participates in `pvp_rule_at`. | The accepted exact R4 contract says hard protection affects terrain, not combat (`docs/research/wp40-simple-map-r4-contract.md:469`); current code is correct. |
| LB-C-04 | WP6’s completion prose still claims global 15–30 minute ore respawn at `BACKLOG.md:29`. | Superseded by the 2026-08-08 finite-resource rule at `docs/design/world.md:199`; no natural-resource respawn implementation remains. |
| LB-C-05 | The historical audit says plateau terrain was required and the old mouth writer was enabled (`docs/research/round9-design-drift.md:15`). | Superseded by ruling 35 and the `2a308891` baseline. It is historical evidence, not a current oracle. |

## Open or newly approved work — Class E

| ID | Scope and audit disposition |
|---|---|
| LB-E-01 | **Concrete indirect-protection bypass, tracked by WP46:** vendored lava cooling calls `set_node` directly without protection at `mods/BASE/default/functions.lua:155`. If cooling lava exists inside a protected volume, it can become obsidian/stone despite `docs/design/world.md:153`. No protected-volume trigger was reproduced, and buckets are absent. WP46 is explicitly open at `BACKLOG.md:184`, so this is existing debt rather than a historical regression. Its inventory should explicitly include this ABM. |
| LB-E-02 | CAP’s outward walls and other pending capital fixes are not shipped. |
| LB-E-03 | MAP-B’s 15-plant world placement, second soils, village crop soil and corals are not shipped (`TODO-round9.md:217`). |
| LB-E-04 | Housing claims, indirect claim mutation guards and Home integration remain WP24. The ten geometry masks are shipped; the mechanics are not. |
| LB-E-05 | Renewable ordinary/apex camp sockets, deep pulse and bounded T6 lava remain WP34. Natural resources correctly remain finite meanwhile. |
| LB-E-06 | Player PvP consumption of `pvp_rule_at` remains WP41; only the map authority and existing spawn-domain consumer were assessed here. |
| LB-E-07 | Current-sampler supply/access certification remains a first-release gate at `BACKLOG.md:329`. Historical 32-seed records were not treated as a current certificate. |
| LB-E-08 | Source-audit refreeze remains WP49 at `BACKLOG.md:305`. |

## Areas not examined

- No generated-world visual or voxel inspection, including the Dawnmere coordinate.
- No Lua KAT, resource census, current-seed supply/access run, parser/static suite or engine startup.
- Enemy spawning and encounter behavior beyond verifying zone API consumers; that belongs to Lane C.
- Recipe semantics and media/art; those belong to Lane A.
- Full WP13 blueprint-cell, NPC and art review; only terrain, foundation, route and protection boundaries were followed.
- PERF branch changes, because they are outside this frozen baseline.
- Open CAP, MAP-B, WP24, WP34, WP41, WP46 and WP49 implementations.

## Prioritized discussion questions

1. Should Rock Salt retain both dragon-island endpoints on stone/gravel support, or should its exact source set change when mountain sand is removed?
2. For cave skin/openings, should “settlement exclusion” mean the hard/visible functional footprint or the complete 256/704-node fitting-and-blend envelope?
3. Should WP46 explicitly adopt the already-shipped lava-cooling ABM as a required guarded mutation path, rather than treating lava only as a future placement/flow concern?
4. Should the DOCS lane correct the stale coast, cave, PvP-precedence and ore-respawn statements before they are used as authority by another package?

---
Archived from the independent audit; local source links and whitespace were normalized to
portable path citations. Baseline line numbers refer to `2a308891`.
Coordinator dispositions in [README.md](README.md) govern the combined inventory.
