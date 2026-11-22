# Round 87 — Road costs in housing areas

**Proposed release: 0.87.0, compatible.** Record the road chunks of the map people
will build on and compare two routing costs offline. The first production map after
the full reset gets the ordinary routes. The user approved trying two candidates with a one-time cost per distinct new
chunk. The study compares them on real world plans. Enabling it on a later map belongs to that map's reset.

## 1. Lanes and waves

| Wave | Lane | Deliverable |
|---|---|---|
| 1 | ROADS | Save the current map's road occupancy in housing areas. Use it in a small before-and-after routing study. |
| 2 | D | Record the storage contract, the measured trade-off and the user's decision in the usual round records. |

## 2. User rulings and open decision

- Terrain, water and good-looking roads take priority. A useful new route may cost a
  claim chunk. Fewer such changes are desirable. There is no survival quota.
- Apply the preference only within the geographic housing areas of both factions.
  Occupied homes and the final list of claimable chunks are not router inputs.
  The zone list belongs to [housing design §2](../design/housing.md).
- Keep the occupancy of the last actual map of the same world and seed. After a reset,
  the resulting map becomes the reference for the next reset. A compatible release or
  a restart of the same map does not advance the reference.
- Try the ordinary candidate first. Only when it touches new housing-area road
  chunks, search for one alternative guided by a fee on entry to such a chunk.
  Score both by their ordinary routing cost plus a fee per distinct newly used
  chunk in the finished corridor. Keep the ordinary candidate on ties. Only an
  accepted road makes a newly occupied chunk free for subsequent roads.

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
For later activation, preserve the input reference for the lifetime of the map
it generated, including a fresh cache build, separately from the resulting
occupancy for the *next* map. A retry must see the same input.

**ROADS — cost study.** Use the same seed, previous occupancy and changed map
inputs for ordinary routing and the two-candidate selection from §2. Distinguish
the entry fee during search from the exact activation fee during final choice.
Count distinct newly covered chunks over the final smoothed corridor. Keep the
ordinary candidate available if an alternative cannot connect or meet the grade
and junction checks. The experiment records when the second search is skipped,
where it wins and its cost in expansions and elapsed time.

**D.** Document the shipped reference and how a later reset would consume it.
The soft-reset procedure for retaining homes remains a separate
[housing work package](housing-rework-concept.md).

## 5. Rules

The production generator in this proposed release has the same output as 0.86.1.
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
