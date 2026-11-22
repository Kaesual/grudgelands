# Round 87 — Road costs in housing areas

**Release 0.87.0 is compatible with 0.86.1.** Record the road chunks of the map people
will build on and compare two routing costs offline. The first production map after
the full reset gets the ordinary routes. The user approved trying two candidates with a one-time cost per distinct new
chunk. The study compares them on real world plans. Its final policy charges only occupied
home chunks. Enabling it on a later map belongs to that map's reset.

## 1. Lanes and waves

| Wave | Lane | Deliverable |
|---|---|---|
| 1 | ROADS | Save the current map's road occupancy in housing areas. Use it in a small before-and-after routing study. |
| 2 | D | Record the storage contract, the measured trade-off and the user's decision in the usual round records. |

## 2. User rulings and open decision

- Terrain, water and good-looking roads take priority. A useful new route may cost a
  claim chunk. Fewer such changes are desirable. There is no survival quota.
- Apply the preference only within the geographic housing areas of both factions.
  In the original comparison the old road chunks supply the cost input. The final
  user ruling below selects actual occupied homes for future reset routing.
  The zone list belongs to [housing design §2](../design/housing.md).
- Keep the occupancy of the last actual map of the same world and seed. After a reset,
  the resulting map becomes the reference for the next reset. A compatible release or
  a restart of the same map does not advance the reference.
- Try the ordinary candidate first. Only when it touches new housing-area road
  chunks, search for one alternative guided by a fee on entry to such a chunk.
  Score both by their ordinary routing cost plus a fee per distinct newly used
  chunk in the finished corridor. Keep the ordinary candidate on ties. Only an
  accepted road makes a newly occupied chunk free for subsequent roads.

- **Final ruling.** The sole purpose of the preference is preserving existing
  homes. Use frozen occupied claim chunks as the cost input for a future reset.
  Empty chunks cost zero regardless of any earlier road. Keep the all-road
  comparison as a historical control for the study.

## 3. Shared conventions

Use the housing grid (80 nodes per side, origin −32) and the existing road-corridor
intersection, including half width plus the protection margin. Compute occupancy
from the finished road layout. The claim snapshot lists only claimable chunks, so
it cannot supply the old road set. The world-layout cache is replaceable.
[Claim snapshot format](../technical/claim-mask-format.md) and
[road network](../design/world_zones.md#92-road-network).

For mixed zone chunks the proposed convention is to record a chunk when its road
corridor touches housing-area ground. Charge only the part of a trial route in
the geographic housing area. A road wholly outside it has zero extra cost even
if a neighbouring column in the same chunk belongs to a housing zone.

## 4. Lane goals

**ROADS — reference.** Reuse the road intersection in
`mods/PLAYER/grug_housing/claim_mask.lua`. Save a deterministic set of chunk
coordinates with the full seed, grid, format version and map-reset identity.
Write it atomically once the map's finished layout is available. An existing
0.86.1 map can acquire its first reference on a compatible upgrade from the
same layout. A missing or invalid reference gives the ordinary routing costs.
The earlier road-cost experiment needs both generations for replay. The final
occupied-only rule takes a separate frozen set from the pre-reset claim registry.
A retry on the same map must see the same input.

**ROADS — cost study.** Use the same seed, previous occupancy and changed map
inputs for ordinary routing and the two-candidate selection from §2. Distinguish
the entry fee during search from the exact activation fee during final choice.
Count distinct newly covered chunks over the final smoothed corridor. Keep the
ordinary candidate available if an alternative cannot connect or meet the grade
and junction checks. The experiment records when the second search is skipped,
where it wins and its cost in expansions and elapsed time.

**D.** Document the road reference and the occupied-home input to a later reset.
The soft-reset procedure for retaining homes remains a separate
[housing work package](housing-rework-concept.md).

## 5. Rules

The production generator in this release has the same output as 0.86.1.
Keep the alternative costs in the study and leave hydrology and road cuts alone.
A future live routing input must enter the world-layout cache identity. A fresh
world with no history uses ordinary routing, so it can differ from an upgraded
world of the same seed. Review persistence and classification against the
[upgrade contract](../technical/upgrade-contract.md).

## 6. Verification

- Exercise geographic edges, negative chunk coordinates, a corridor grazing the
  adjacent chunk, re-entry and a diagonal step that crosses a chunk corner. Check
  first capture on an existing map, restart, interrupted write and reset rollover.
- Use the production seed (3684797457838814663) and one contrasting study seed.
  Replay a local road change such as the arena connection using a matched pair of
  world plans. Compare the actual smoothed corridors and claimable coordinate sets.
  Report newly occupied chunks, lost and gained claimable chunks separately, and
  surviving chunks with changed fingerprints by component. A changed road number
  alone is not evidence of changed ground.
- Inspect the most affected route for grid-following bends, detours, steep cuts,
  water crossings and missing connections. Report route length, search work and
  runtime on the same cases. Compare the ordinary production layout with 0.86.1.
  A weak or unattractive result is grounds to keep ordinary routing.
- Run the [topic checks](../process/checks.md) and [round gates](../process/round-workflow.md#3-gates)
  for the files actually changed. Independently review the lane before merge.

## 7. Orchestration

Start from tagged 0.86.1 and the subsequent status commit. Production and its
scheduled upgrade are recorded in [STATUS](../STATUS.md). The proposal works
whether 0.86.1 reaches production before or together with 0.87.0. One technical
lane owns the snapshot and the study, then D follows. Use the shared Lua queue
and existing `tools/r85_mask`, `tools/r85_world` and `tools/r86_roads` probes.
Record the capture format at the first handoff and the cost comparison at the
second. The user decides model routing, the round start and the cost policy.

## Measurements

An isolated Luanti boot on 3684797457838814663 wrote 633 current road chunks.
The complete file (4,421 bytes including identity and checksum) matched the
independent reconstruction from the archived Round 85 corridor and zone exports.
The claim mask contained 366 chunks for The Accord and 373 for The Throng.

The capture uses the same zone rules for both factions, including capital streets.
It runs before the spawn-region checks. A failed road-file write leaves housing
usable and the old bytes in place; the integration fixture exercised the retry.
An upgrade from 0.86.1 rebuilds the housing column cache once because its builder
files changed. The full-preparation source identity is unchanged.

### Replaying the arena change

The old road sets came from the Round 85 exports before the arena. Each replay
used the same full seed and the finished map with the arena. The ordinary replay
matched the live network byte for byte on all three seeds. The allocation charge
and proposal entry fee were both 80 ordinary path-cost units. This was a study
setting. The two complete map builds used the first study weight and included
trails and capital streets.

| Seed | New road chunks, ordinary → study | Roads taking an alternative | Extra search expansions | Claimable chunks, The Accord / The Throng |
|---|---:|---:|---:|---:|
| 3684797457838814663 (production) | 0 → 0 | 0 of 95 | 0 | 366 / 373 |
| 6410640627505506314 | 2 → 0 | 1 of 96 | 33,434 (+2.0%) | 362 / 312 |
| 6866842473207 | 1 → 0 | 1 of 96 | 20,019 (+1.5%) | 384 / 346 |

For both factions on every seed, the ordinary and study claim masks lost zero
chunks and gained zero. Their surviving chunks had zero changes in the height,
water, zone, road and place fingerprints with road numbers removed. Avoiding
three newly occupied road chunks produced no additional claimable land in these
maps. This comparison measures eligibility and the sampled fingerprints. It does
not measure survival of player structures.

On each affected map, only the arena's south approach to the same anchor changed.
Its length went from 1,505 to 1,497 nodes and from 1,374 to 1,376. The usual
route cost went from 2,829.92 to 2,834.39 and from 2,600.84 to 2,603.24.
The coarse turn counts went from 32 to 30 and from 16 to 16. The winning profiles
kept the same bridge, deep-cut and unsupported deck point counts in each pair
and the same maximum cut (39.7 and 5.0 nodes). The latter route had six fewer
deck points. Both networks kept their connections. In the full comparison the
ordinary and study network builds took 5.8 / 5.5, 6.4 / 6.7 and 5.5 / 5.5 CPU
seconds respectively in table order. The expansion counts are more reproducible
than that timing difference. These route assessments used the sampled geometry
and profile metrics.

The study checks pins and grade feasibility and rejects an alternative that
adds deep-cut or unsupported deck points to the ordinary route's provisional
profile. All three seeds repeated the same choices with that check. The full
map, including its final terrain contacts, is compared independently of the
per-route selection. An isolated synthetic route exercises both winning and
losing the decision, ties, re-entry and leaving occupancy unchanged on rejection.

### Choosing the activation fee

On the two affected seeds, a second sweep used the same value for the search
entry fee and the final activation price. The table counts newly occupied
housing-area road chunks on the two maps together.

| Weight | Ordinary | Selected routes |
|---|---:|---:|
| 1, 2 | 3 | 3 |
| 3, 4 | 3 | 2 |
| 8, 16, 32, 80 | 3 | 0 |

Eight is the smallest **tested** common value that found and selected both
useful alternatives. The offline tool now defaults to 8. Holding the candidates
fixed, the break-even final prices are about 2.24 (= 4.47 / 2 saved chunks)
and 2.40 (= 2.40 / 1). A smaller entry fee can fail to propose the good route
at all. Raising the price above 8 on these inputs produced the same sampled
network geometries. Changing the weight expresses how much ordinary route cost
can be traded for a chunk. These two observations do not establish a universal
price or a separate price for an occupied home.

The user's follow-up also considered charging only for homes actually present
before the reset. Every placed personal or account stone has a persistent
`claim:<id>` record with its centre. The registry derives an 80 × 80 chunk
per stone and indexes it. The offline pre-reset pass already reads the records
from the stopped world. The occupied-only study exports the
coordinates of every placed stone on a stopped v3 world and charges once per
such chunk touched by a finished corridor in the housing areas. Only the winning
road consumes that charge. The sealed list includes the seed and no owner
identifiers. Future live integration must include its digest in all generation
inputs. Candidates
on empty land incur zero additional cost. The normal placement and
fuel cycle would continue without rerouting an existing map. Which standing
claims to include (for example activated but currently unfuelled homes) belongs
to the preservation decision. A dry run should compare their eligibility and
border fingerprints as well as the road layout.
[Registry](../../mods/PLAYER/grug_housing/registry.lua) and
[pre-reset reader](../../tools/migration/pack.py).

### Occupied-home replay

Three full builds used snapshots exported by the stopped-world reader. These
were controlled test records on real terrain. No production player records
were used. Two coordinates were deliberately placed in the path of the arena
change to exercise a conflict regardless of past placement eligibility. The
records included a personal and an account stone. The offline study includes
every extant record, including a draft or an unfuelled home.

| Seed | Frozen claim chunks | Ordinary roads touching a test home → selected roads at weight 8 (distinct homes) |
|---|---:|---:|
| 3684797457838814663 | 0 | 0 → 0 (zero additional searches) |
| 6410640627505506314 | 2 | 1 → 1 |
| 6866842473207 | 1 | 1 → 0 |

For the third seed the two-node detour cost 2.40 extra. On the second seed
the proposed alternative still clipped the home with its finished corridor.
Weights 16, 32 and 80 reproduced those decisions. A proposal guided by cell
centres can miss an alternative that would avoid the home at its edge. Raising
the price alone cannot fix that. For the next reset use 8 as the initial soft
price and replay the newly planned terrain with the actual occupied coordinates.
The full claimable sets and sampled fingerprints for these three trials matched
the ordinary builds. Eligibility, border changes and other terrain features
still decide whether a real home can be kept.

## Completion (2026-11-22)

The game captures a sealed road reference on existing and fresh maps. Both an
independent reconstruction from the arena exports and a direct export on 0.86.1
reproduced the production-seed file emitted by Luanti. A second isolated boot
reused it. The offline router and its study are available in
[tools/r87_roads](../../tools/r87_roads). The live generator keeps the ordinary
routes. The release is **compatible** with 0.86.1.

The full portable suite passed all 396 fixtures. The road fixture also passed
59 targeted checks after review. The upgrade, fresh-server, design, economy,
building-template, ridden-bat and Lua checks passed. Independent review covered
reference rollover and failure handling, and the two-candidate decision including
rejected junctions, uncharged base cost and elevation constraints.

## Carry-overs

- At a later release that changes world generation and requires a map reset,
  integrate occupied-home selection with the pre-reset pass. Freeze the claims
  selected for preservation before the usual records clear, include the digest in
  the layout and preparation identities, use ordinary routing with no usable
  history, and repeat the comparison for that release's actual change.
- Preserving built homes through a reset belongs to
  [housing Part C](housing-rework-concept.md). Reducing road intersections is one input to this decision. The observations
  above give no survival rate for real homes.
