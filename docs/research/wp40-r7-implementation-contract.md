# WP40 R7 Implementation Contract

Status: **ratified and implementation-ready; production writer still disabled**

Decision date: 2026-08-31 (Europe/Berlin)  
Reviewed technical source: `acf16c156416ad47df70c8ff3278211fcbd3978c`

This document is the coordinator's execution contract for R7. The complete
field-level rules remain in:

- `wp33-gathering-contract-candidate.md`, whose recommended D1--D6 decisions
  the user ratified on 2026-08-31;
- `wp40-r7-native-contract-candidate.md`, the native/input/cutover contract;
- `wp40-r7-cutover-preflight.md`, the writer and consumer inventory; and
- `wp33-r7-contract-candidate-review.md`, the clean independent review record.

The authoritative player-visible rules are folded into
`docs/design/biomes_mobs.md` Section 2.2,
`docs/design/world_zones.md` Sections 11 and 13.1, and
`docs/design/items_crafting.md` Section 4.1. `BACKLOG.md` owns the WP28, WP29,
WP33 and WP40 delivery boundaries. If this summary and a detailed contract
differ, implementation stops for contract correction; it does not choose a
convenient interpretation.

## 1. R7 outcome

R7 makes the accepted R0--R6 world pipeline production-active in one reviewed
cutover and adds WP33 gathering through the same transaction. The resulting
system has:

- one mapgen-environment callback and one VoxelManip transaction;
- R6 P2--P9 followed by the reject-only P9G successor and the fixed activation
  suffix in the same private buffers, run derivation, replay and commit;
- zero Lua biomes, exactly one retained native gravel blob, five retained
  strata and zero engine decorations;
- one stable public `grug_zones` authority and one fail-closed protection
  policy; and
- no legacy ocean, healer, structure, capital-repair, biome, ore or decoration
  writer path.

R7 acceptance is offline and mocked-engine evidence. It does not claim a real
Luanti world, a visual pass or production performance; those are R8 gates.

## 2. Frozen identities

The implementation must keep these identities separate and authenticated:

1. the accepted R6 evidence table with exactly 77 ASCII-ordered content rows
   and six synthetic Cultural targets at `grug_nodes:bone_pile`;
2. `grug_wp40_r7_production_r6_content_v1`, exactly those 77 names plus the six
   real Cultural source nodes, for 83 ASCII-ordered rows using the normal R6
   capability-16 resolver;
3. `grug_wp40_r7_p9g_content_v1`, exactly twelve ASCII-ordered P9G target rows
   with local refs 1..12, capability 8 and successor run refs 84..95; and
4. `grug_wp33_gathering_catalog_v1`, exactly 12 `new_p9g_source`, 8
   `reuse_r6_source` and 6 `r6_cultural_slot` records.

The narrow activation correction ratified on 2026-09-01 adds two identities
without reopening the accepted R6 source projection:

5. `grug_wp40_r7_anchor_content_v1`, exactly the ASCII-ordered nodes
   `grug_nodes:camp_fire` (local ref 1, successor ref 96) and
   `grug_nodes:guard_banner` (local ref 2, successor ref 97); and
6. `grug_wp40_r7_anchor_roster_v1`, exactly 42 stable R4 anchors: capitals
   007--012 and outposts 025--048 use the banner, while bandit camps 049--060
   use the fire.

Each activation root is exactly `(anchor.x, anchor.y + 1, anchor.z)` and its
support is exactly `(anchor.x, anchor.y, anchor.z)`. R4's authenticated fixed
anchor exclusions intentionally suppress analytic P7 at all 42 of these
columns, including outposts and bandit camps as well as capitals. Support must
therefore equal the unchanged original solid, non-liquid map input. Reopening
P7 beneath those exclusions is outside this narrow correction. The root must
still be air, and the suffix never overwrites.
It uses opcode/class/policy 36/12/12 after P9G and before shared run derivation,
replay and the one commit. It creates no platform, pad, clearing, shell or
second writer. Capital roots use the current exact center; the historical
`+11,+11` offset belonged to the removed legacy platform and is retired.

The 24 outpost and 12 bandit root columns are hard-protected at `y >= -700`.
Their `y <= -701` cells remain governed by the predecessor authority. Capitals
continue to rely on the existing R4 hard volumes. These are exactly 36 added
columns and 42 mutable mapgen root cells; the protection overlay does not grant
mapgen permission to change any neighboring cell. `grug_nodes:camp_fire` owns
the lower-load-order node identity; `grug_mobs` attaches its timer/meta behavior
and retains only the compatibility alias `grug_mobs:camp_fire`.

The activation delta is independently removed first. Stage A then removes the
complete P9G delta from private buffers and proves equality with a direct
authenticated 83-row production-R6 run. Stage B maps the 83-row
run by node name to the accepted 77-row evidence namespace, permits the six
real-to-synthetic substitutions only on matching Cultural operations, then
rederives refs, CIDs, aux values, runs, checksums and evidence. Any other
difference reopens R6 and stops R7.

## 3. Ratified WP33 content

Every accepted P9G source is one low, hand-gathered cell, preserves P7 and
drops exactly one raw item. The exact opportunity densities are:

| Denominator | Sources |
|---:|---|
| 256 | Potato, Corn |
| 384 | Sunleaf, Mushroom |
| 512 | Gravemoss, Marshbloom, Melon |
| 768 | Dragonweed |
| 1024 | Crimson Lotus, Stormkelp, Wild Cocoa, Rock Salt |

The exact zone and host sets are the closed tables in `world_zones.md` Section
11. In particular, Marshbloom uses Ossuary Reach instead of Mournfen for the
paired level-21--30 roster; Stormkelp uses cardinal dry-shore adjacency without
requiring `grug_beach`; Rock Salt additionally requires beach/sand.

P9G's coast handling has one closed correction for the dragon islands. If the
already ordered static-exclusion query returns exactly
`exclude:coast:island_wyrmglass` or
`exclude:coast:island_stormscale`, P9G alone treats that result as nonblocking
when authenticated `column_values_at(x, z)` has
`water_class == "land"`. These two coast records are claim envelopes over their
complete islands, not occupied cells. Every other coast result still rejects;
earlier anchor, route and authored-water results retain priority; and fixed
protection, housing, P7 support, predecessor, clearance, R6 occupancy,
non-overwrite, no-retry and one-transaction gates are unchanged. No other
consumer receives this exception.

The six Cultural sources retain one item per node. Ordinary density is 1/4096
and concentrated density 1/1024. Concentrated tool families are Gravesalt and
Runeslate `pick`, Moonresin/Spirit Resin/Sunwax `axe`, and Red Ochre `shovel`,
all at tier 4 or higher. `grug_materials.tool_tier_for_stack` is the sole
family/tier resolver. Missing WP29 axe/shovel/pick tier authority fails harvest
closed and does not block deterministic placement.

WP33 owns one single-registration healing-herb authorizer. Before WP10, herbs
are visible scenery and cannot be removed. Later only `grug_jobs` supplies
profession/book authorization. WP33 never duplicates profession state.

## 4. Implementation sequence

Intermediate commits may keep new code disabled, but no intermediate shipped
state may enable two writers or partially remove the old authority.

### R7-A -- WP33 registration and behavior

- Add the `grug_gathering` owner mod and its eighteen new nodes: six Cultural
  targets followed by twelve P9G targets after all existing target-owner mods.
- Add the immutable 26-row manifest, twelve P9G records, eight reuse audits and
  six exact R6 Cultural registration records/digests.
- Implement one-item harvest, exact source groups, the fail-closed herb
  authorizer and the `grug_materials` tool-family resolver seam.
- Register no decoration, mapgen callback, LBM, `set_node` or VoxelManip writer.

### R7-B -- native inputs and successor settlement

- Add the one native-input module with the exact six retained NoiseParams and
  the closed six-record native ore allowlist from the native contract.
- Validate identical effective NoiseParams in main and emerge environments
  before publication or callback registration.
- Build/authenticate the 83-row production-R6 resolver and the separate
  twelve-row P9G resolver; add P9G-only opcode, class, policy, ledger and
  metrics branches without changing any existing R6 opcode semantics.
- Build/authenticate the separate two-row activation resolver and exact 42-row
  roster; append its opcode-36 delta after P9G in the same successor tail.
- Execute P9G and then activation after R6 P9 and before shared run
  derivation/replay/commit.

### R7-C -- atomic loader and consumer cutover

- Remove the ocean-mapgen IPC/callback, ocean-healing LBM, structures
  `register_on_generated` writer and capital repair/persistence state machine.
- Stop loading the legacy biome/ore/decoration registrations and load only the
  closed native-input module.
- Enable exactly one production mapgen script/callback after every manifest,
  content, node, CID, param2, template and NoiseParams check passes.
- Publish one immutable `grug_zones` session and redirect every existing
  terrain-height, difficulty, open-sea, spawn, protection, mob, Kraken, rare
  and gathering consumer to its stable queries and anchors. Publish the
  contracted map/mount/housing/travel API for their future WPs; R7 does not
  invent absent production mods or consumers.
- Preserve `grug_core.surface_level_at(x,z)` as terrain-height compatibility;
  no compatibility helper may recompute old geometry or consult old platform
  state.

### R7-D -- evidence and promotion

- Prove closed manifest populations/digests, exact native registration counts,
  one loader/callback/writer/transaction and zero legacy paths.
- Exercise every P9G source and rejection reason, all 42 activation roots,
  both node identities, the exact 6/24/12 partition, root/support semantics,
  independent opcode-36 removal, the 36-column protection boundary, both R6 projections,
  ownership/support boundaries, protection/query adapters, replay and
  fail-closed initialization.
- Run the changed R7 resource/content delta over the frozen 32-seed corpus;
  preserve accepted R6 decisions under Stage B and record separate P9G supply,
  collision, parity and access ledgers.
- Run the separately scoped static frontier-access roster through authentic R7
  successor settlement only; keep its access ledger separate from the
  three-projection sample and its Stage A/B and parity ledgers.
- Promote canonical artifacts, run receipts, logs and hashes to
  `docs/research/`; no acceptance evidence may remain only under `/tmp`.

## 5. Verification schedule

LuaJIT owns development, mocked-engine integration, fixed-layout checks and the
32-seed delta fleet. PUC 5.1 owns syntax/static checks and, only after all
relevant Lua bytes freeze, one compact runtime micro-KAT also run once under
LuaJIT with byte-identical canonical output. A relevant byte change replaces
that pair. There is no intermediate PUC runtime suite or PUC fleet.

Independent workers use immutable inputs, separate scratch/output paths,
idle scheduling and at most seven simultaneous Lua processes workstation-wide.
A deterministic finalizer orders and checks every result.

Before any long fleet, run the representative LuaJIT pilot set defined by the
active acceptance amendment. For the current schedule this is the concurrent
combined slot-17 and main-only slot-18 pair. Record their input/roster hashes,
elapsed time, peak RSS, output/scratch bytes and projected maximum-worker cost,
then stop unconditionally. The fleet starts only after the user approves that
exact measured SHA-256 projection. An earlier R6 or superseded R7 fleet
approval does not silently approve a changed projection.

## 6. Review and stop conditions

The final R7 diff and immutable evidence require a full independent strong-agent
review under `docs/process/wp-workflow.md`; any Critical or High fix receives a
focused re-review. During this session GPT-5.6 Sol is the reviewer, following
the user's instruction not to spend further Opus credits.

Stop and escalate instead of guessing if implementation would:

- change an accepted R0--R6 geometry, height, biome, surface, resource or
  settlement decision outside the two explicit projections;
- change a ratified D1--D6 density, zone/host roster, yield, tool family,
  resolver owner or one-cell placement;
- require a second writer/transaction, native decoration, Lua biome, repair
  LBM, retry/refill or live-VM halo authority;
- leave any required target node, manifest, NoiseParams or content identity
  unauthenticated; or
- require an intermediate/exhaustive PUC runtime or more than seven concurrent
  Lua processes without a new concrete compatibility finding and user ruling.

## 7. R8 handoff

After R7 is independently accepted, R8 generates the first real fresh v7
world that the user can inspect in Luanti. It validates native caves, dungeons,
strata, liquids, lighting, mapchunk order, one-writer behavior, representative
content/access, visual quality, generation time and RSS, followed by the
separate user-run fallback-engine/runtime checklist. R7 itself does not make a
visual or runtime acceptance claim.

## 8. Pragmatic acceptance amendment (2026-09-01)

This section supersedes only the exhaustive spatial population in sections 5
and 6. It does not weaken the production contract, final LuaJIT/PUC parity,
source/configuration gates, real VM integration proof, Stage A/B equality,
transaction/replay, non-overwrite, protection or fail-closed requirements.

At the user's release-scope decision, the 32-seed R7 delta acceptance is a
closed stratified sample rather than a scan of all 8,075 owners per seed. Each
seed evaluates exactly 128 owners: 104 fixed interior owners on a 13-by-8
spatial lattice and 24 fixed risk owners covering Cultural witnesses, clipped
corners, Stage-A/B and multi-y owners, both apex sides, route/water interfaces
and coastal housing. The broader connection channels remain protected by the
already-binding focused/integration gates, not by a sampled-owner claim. The
canonical 32-seed population is therefore
4,096 `(seed, owner)` cases. Every selected owner still runs the R7 successor,
independent direct-83 settlement and independent accepted-77 authority.

Crashes, invalid identities, nondeterminism, Stage A/B differences, illegal
overwrite/overlap/retry, owner/protection errors, transaction/replay mismatch,
missing E/B/acceptance for any of the eight non-frontier P9G sources in the
main sample, lost Cultural identity, paired access owned by the main sample,
sample-roster gaps or duplicates, and any failed frontier source-by-faction
gate below remain hard blockers.
Exact whole-world density, the global 10% parity inequality and proof of every
query column become measured advisory results. Artifacts and completion prose
must say `32-seed stratified sample`, never `full` or `exhaustive` fleet.
The sample receipt distinguishes all clipped query-column visits from the
subset that emits a zone/logical-biome surface classification; water and
other non-surface columns are not falsely counted as biome coverage.

The existing Stage-B v1 field names remain byte-compatible: their normalized
and accepted projection digests cover the selected owners, while the immutable
accepted R6 artifact retains its separate SHA-256 identity. R7 does not claim
that the sampled run regenerated the complete R6 aggregate artifact.

The four sparse frontier sources receive a second, strictly separate evidence
lane rather than post-outcome additions to the 128-owner sample. Its literal
seed-independent roster is the complete 80-by-80-owner intersection with these
four inclusive conservative land envelopes:

| Scope | Inclusive envelope | Aligned owner origins | Owners/seed |
|---|---|---|---:|
| Gravesalt | `x=-2500..-1200`, `z=-250..250` | `x=-2512..-1232`, `z=-272..208`, step 80 | 119 |
| Skyglass | `x=1200..2500`, `z=-250..250` | `x=1168..2448`, `z=-272..208`, step 80 | 119 |
| Wyrmglass | `x=-3500..-2800`, `z=-390..380` | `x=-3552..-2832`, `z=-432..368`, step 80 | 110 |
| Stormscale | `x=2800..3500`, `z=-400..390` | `x=2768..3488`, `z=-432..368`, step 80 | 110 |

The disjoint union is exactly 458 full owners and 2,931,200 columns per selected
seed. The predeclared, evenly distributed frozen seed slots are exactly
`1, 6, 11, 17, 22, 27, 32`, giving 3,206 `(seed, owner)` cases and 20,518,400
columns. The 32-seed main sample is unchanged; only this separate access lane
uses the seven-seed scope.
The Holy Grounds bounds derive only from the fixed rectangle, unbiased frontier
hubs and maximum 60-node warp; the island bounds are the two authored polygon
bounding boxes expanded by the same warp maximum. Canonical order is owner z,
then owner x. The literal roster and its SHA-256 freeze before the first
successor outcome; no biome, candidate, eligible, budgeted, accepted, ledger or
source-density result may select, remove or stop an owner or seed.

Each frontier owner runs authentic successor settlement, but not the independent
direct-83 or accepted-77 projections. Across the complete lane, nonzero
eligible, budgeted and accepted populations are hard gates for exactly eight
pairs: Crimson Lotus/Accord, Crimson Lotus/Throng, Stormkelp/Accord,
Stormkelp/Throng, Wild Cocoa/Accord, Wild Cocoa/Throng, Rock Salt/Accord and
Rock Salt/Throng. The only in-scope zones are
`front_gravesalt_escarpment`, `front_skyglass_canopy`,
`front_stormscale_summit` and `front_wyrmglass_crown`. Zero rows are retained;
all owners run for all seven selected seeds even after a pair passes; a failure
cannot be repaired by changing the roster or seed slots after observing
outcomes.

This frontier access ledger is never pooled into the 128-owner sample. The main
sample and integration gate remain the sole owners of Stage A, Stage B, exact
tuple parity and their existing transaction/replay claims. Density and faction
parity remain measured on the main sample only and retain their pragmatic
advisory status; the frontier lane makes no density or parity claim.

The pilot runs one combined representative slot (`17`) and one main-only slot
(`18`) concurrently. Its projection binds both results, the exact assignments,
measured resources and the maximum worker schedule of one access seed plus four
main-only seeds. The fleet may start only after explicit approval of that exact
projection SHA-256. A projection above two hours of fleet wall time is a
stop/reconsider result rather than an automatic launch.

This seven-seed amendment was approved on 2026-09-01 after the complete
32-seed Access proposal stopped at its pilot boundary. That pilot measured
2,981.65 seconds for one combined seed and projected 14,908.25 seconds
(4 h 08 min) for the fleet; its projection SHA-256 was
`30d6912f53983bf292081a2cb441fac81c1e4092dabe477263313be78db6d033`.
The failed budget projection is decision rationale, not accepted fleet
evidence. No 32-seed Access fleet was started from it.
