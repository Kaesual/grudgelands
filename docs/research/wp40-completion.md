# WP40 completion record — 2026-09-13

**Status: WP40 development delivery accepted and completed on 2026-09-13;
independent documentation closeout review clean.**

This record consolidates the current development acceptance of the named-zone
world foundation. It does not rewrite immutable R2–R7 contracts or turn earlier
algorithm-specific evidence into evidence for current output. The user explicitly approved the development/release boundary below with
“Ja, WP40 so abschließen” after the native and browser acceptances.

## Candidate and delivered scope

Game candidate: `91882c8468b621d649bb83341ba1ba58e6103df7`, merged and
synchronized before the user's final native GUI acceptance. The user reports
having pushed it. This closeout changes documentation only.

WP40 delivers the fixed 38-zone horizontal world, deterministic terrain,
logical biomes and material/vegetation palettes, fixed start/capital anchors
with terrain-fitted pads and terraces,
POI foundations, roads and water crossings, caves, named hydrology, resource
placement and the zone/height/protection APIs used by existing consumers. One
production VoxelManip writer remains authoritative. WP33's gathering layer
shipped with R7. Building the final settlements and their full civic content
belongs to WP13, not to this map foundation.

The accepted first correction round includes intact tree slices, biome-native
cover on varied surfaces, fitted road junctions and POIs, knotted sparse-leaf
Gravewood, improved terrain/water beds, stable startup/hydrology validation,
demand-driven resource roots, bounded planner reuse, closed Kezamba banks and
correct banner face textures. Natural map ores are finite. No old-world
migration, compatibility alias or repair path is introduced.

The round's individual implementation records remain available: [tree slices
and profiling](wp40-mapgen-profile-tree-fix.md), [terrain quality and fresh-server
cleanup](wp40-mapgen-quality.md), [biome cover and junctions](wp40-biome-cover-junctions.md),
[terrain life](wp40-terrain-life-polish.md), [startup manifest](wp40-startup-manifest-fix.md)
and [hydrology depth](wp40-hydrology-depth-fix.md). Their old pending-acceptance
wording describes their dates; this completion record owns current status.

## Evidence and its exact limits

| Evidence | What it establishes | Limit |
| --- | --- | --- |
| [R7 independent acceptance](wp40-simple-map-r7-review.md) | Historical writer cutover and resource/access populations | Earlier algorithm/source identities; not final-byte recertification |
| [R8 pilot history](wp40-r8-pilot.md) | Historical native/feature order checks on their recorded candidates | Seed 0 and older production bytes; not a current-candidate order certificate |
| [Resource sampler adoption](wp40-resource-sampling-integration.md) and [prototype comparison](wp40-resource-sampling-prototype.md) | Adopted writer/census selection; 50-owner, three-seed comparison retains all 54,131 eligible/budget/planned rows and 100,417 planned and accepted veins | Exact ore placement may differ; no complete current 32-seed supply/access claim |
| [Planner throughput](wp40-planner-throughput.md) | Three alternating local runs per variant, 8.8% median callback improvement, full tested output/persistence parity | Earlier candidate; local bounded workload, not a universal speedup |
| [Final water/road/banner package](wp40-water-road-polish.md) and its [review](wp40-water-road-polish-evidence/review.md) | Final candidate shore fixes, modest road-cut bias, banner correction, parser/static checks, actual constructor and engine persistence | Targeted fixtures, not exhaustive continent coverage |
| Final compact PUC/LuaJIT pair in [the evidence directory](wp40-water-road-polish-evidence/) | 264 byte-identical rows, 1,794 input bindings; SHA-256 `936a0e440d7ef22bea9ceb76a59a4bb5d29ae3e206f693babb1a15118b845b22` | Standalone parity is not a real fallback-engine run |
| User's fresh native GUI acceptance | User reported “Alles grün”, pushed the changes and declared the first correction round finished | Exploratory playtest, not a claim that every old 15-point itinerary assertion was individually recorded |

The final user-seed engine fixture generates ten owners/5,120,000 voxels,
reloads 1,250 stored mapblocks with zero generation callbacks, and preserves
full digest `a836b34aaa82f0d5a0350e9a244831d83db091fa3bd2db986c19fc0646c98f84`.
Both the reported-seed and seed-0 shore scans find zero low wet/dry contacts in
the tested basin. Final cached single-run callback control is 6.80 seconds
against 6.50 before the water/road correction; modest overhead remains possible.

The recovered historical G3 receipt explicitly reports `dungeon_status =
not_observed` and `dungeon_preservation_proven = false`. Its accepted pragmatic
PASS must not be described as a witnessed native-dungeon preservation proof.
The old fixed seed-0 ruby root and retired per-host hash ranking are not current
resource output oracles.

## Runtime acceptance

Development fixture seed: `531802985935182545`. Its SHA-256 is
`5f6e643f72114e25be865585d5aece42704df54f4cc288fa9caea6a6040b64f7` (UTF-8 decimal string without a newline).
It is not silently installed as a permanent public-server seed.

Native GUI result: accepted by the user after testing the synchronized current
game. Water at Kezamba, hillside roads and the banner were the final targeted
items; the preceding exploration accepted landscape variety and generation
responsiveness. Small road pits and grade-constrained embankments remain
non-blocking cosmetic limitations.

Browser fallback result: **user-accepted on 2026-09-13**. After receiving the
candidate commit above for the kaesual-stack integration and the manual “Local
game” test instructions, the user reported that the game runs and that server
startup and map generation work under browser Lua 5.1. They explicitly accept
the slower startup/generation as non-blocking: Grudgelands targets a server
running LuaJIT as the normal case. No new performance threshold or LuaJIT-only
language exception follows from this acceptance.

The browser build ID is **unknown**, and no deployed game-manifest digest or
engine log was supplied. The result is recorded as user acceptance of the
requested candidate's browser-local test, not an independently hash-bound
binary reproduction. The requested seed is the development fixture above;
the user's reply did not separately enumerate capital/restart observations,
so this record does not claim individually witnessed results for those steps.
The user explicitly declared the browser acceptance green despite the absent
build ID. There is no need to invent an identifier or repeat the accepted test
solely to obtain one.

Local source inspection supports using that engine: the external checkout
`/home/jan/projects/kaesual-stack/luanti` (not this repository's pinned
`reference_projects/luanti`) at `d9b04de06c717563d09eb986f3adeb7a8da08736` forces
`ENABLE_LUAJIT = FALSE` for Emscripten in `CMakeLists.txt:102–121` and
`web/emscripten-toolchain.cmake:242`; `lib/lua/src/lua.h:19–21` identifies bundled
Lua 5.1.5. This is a read-only source observation, not proof of the deployed
browser build or a substitute for the user's runtime result.

## Open first-public-release obligations

The user explicitly moved these obligations to the first public release. They
remain open and are not represented as passed or silently waived WP40 gates:

1. Freeze the intended release game, engine, mapgen settings and chosen seed.
2. Rebase current-sampler resource supply and regional access evidence onto that
   candidate; historical 32-seed artifacts retain their old algorithm identity.
3. Run the reviewed current-candidate feature/native, generation-order and
   runtime/RSS smoke, with exact source/corpus bindings and explicit limits for
   any native event not observed. Historical G3 does not certify later changes.
4. Confirm native and actual fallback-engine startup/generation/restart on that
   candidate, reusing unchanged evidence only where its input identity permits.

The amended [R8 contract](wp40-simple-map-r8-contract.md) and the visible
[BACKLOG release section](../../BACKLOG.md#first-public-release-gates) own this
boundary. Owner: the project coordinator preparing the first public release;
trigger: selection/freeze of that release candidate, before user release approval.
WP13 may consume the delivered geometry/APIs now. These obligations do not
require waiting for, or imply the start of, old-world compatibility work. WP completion does not announce a public release or
end the user's fresh-server development mode. The production Lua-5.1 requirement
remains binding for every later change.

## WP13 handoff

The user selected WP13 as next and agreed to begin with exactly one start
settlement, making the game's intended experience visible before multiplying
content across six races. This closeout does not choose the race or architectural
style and does not start implementation. A bounded first-settlement brief and
visual review come before wider rollout; the rest of WP13 retains its scope.
GPT-5.6 Sol is a proposed implementation route for settled, bounded tasks, with
independent review retained. No quota-saving percentage is assumed.

## Closeout checks and calibration

Classification: non-trivial documentation/acceptance-boundary change. Coordinator
session identity: GPT-6. Preliminary read-only evidence audit: configured
GPT-5.6 Sol, `/root/wp40_closeout_audit`, with no implementation ownership.
The same independent reviewer checked the actual final five-document delta,
user approvals and bounded evidence without rerunning Lua or engine populations.
Initial documentation findings: 0 Critical / 0 High / 1 Medium / 3 Low; one
documentation fix round clarified delivered pads versus future buildings,
historical evidence attribution, exact sampler-count qualifiers and external
engine-source provenance. Final verdict: **ACCEPT, 0 Critical / 0 High /
0 Medium / 0 Low**. Observed elapsed delivery time: unknown.

Closeout checks: all local completion links resolve, the authoritative table has
19 completed WPs among 46 stable numbers, `git diff --check` is clean, and all
1,794 archived final-micro input hashes still match. No earlier production
acceptance artifact was rewritten.
No production bytes or settings change; no new Lua runtime population is
justified by this documentation consolidation alone.

Ongoing runtime plan: fresh worlds after geometry/seed/settings changes; verify
race start, a capital and a road/water crossing, then save/restart/revisit. Report
new generation errors or unusable terrain. WP13's first settlement gets a new
focused visual/playability test when implemented.
