# WP40 simple-map V1e focused R2 refresh contract

**Status (2026-08-27): completed and accepted. Every gate in Section 5 is
green, including independent implementation review and the user's explicit
approval of the final V1e SVG. The V1e artifact at the sole live R2 path is
authoritative; V1d remains reproducible history at commit `d337160`.**

## 1. Reason and boundary

The accepted V1d layout is visually sufficient, but the first real R3
construction exposed one remaining horizontal/vertical mismatch. Its 84
secondary anchors still choose among three positions from the full seed even
though WP40 now owns one fixed, visually reviewed 2D layout. The corresponding
independently graded spur variants create path-surface overlaps that cannot be
made one-Lipschitz by a local priority rule, an endpoint apron or a shared
network closure without moving exact anchor, hub, ford or tunnel pins.

This refresh deliberately reopens two closed, bounded omissions:

1. secondary-anchor selection changes from a per-full-seed bounded candidate
   choice to the frozen positions already shown in the accepted V1d preview;
   and
2. the three unequal-level wet-reach contacts proved in Section 4.1 receive
   exact named waterfall interfaces without moving any reach footprint, and
   the existing abstract `surface_water` semantic of named WP40 hydrology is
   materialized as Luanti's non-renewable river water so those fall faces stay
   stable under native liquid simulation.

It corrects only the proven conflicting path approaches, those three missing
vertical interfaces and that one liquid-material binding. It does not reopen
land, zones, bays, any of the 25 hydrology reach geometries or records, housing
policy, the route graph, difficulty or protection. It adds no route search,
graph solver or query-time repair.

V1d remains accepted and reproducible while V1e is prepared. V1e supersedes it
only after a new SVG approval, complete R2 artifact, focused independent R2
review and the four-seed vertical preflight below.

The one live artifact path remains
`docs/research/wp40-simple-map-r2-artifact.tsv`. During implementation that
working-tree path may contain uncommitted V1e candidate bytes so the existing
writer, R3 preflight and reviewer all inspect the same file. Until every gate
is green and the candidate artifact plus review record are committed, the
semantic project authority remains accepted V1d at Git commit `d337160`, not
the dirty working-tree candidate. The accepting commit promotes the reviewed
bytes at the existing path and all live R3 tooling continues to read it. The
exact V1d bytes remain historical evidence at `d337160` and through the old
body/file hashes below; they are not copied into a second live artifact. The
historical V1d review record remains unchanged apart from an optional explicit
supersession pointer to the new review.

The additional committed evidence paths are exact:

- `docs/research/wp40-simple-map-v1e-anchor-migration.tsv`;
- `docs/research/wp40-simple-map-v1e-baseline-diagnosis.tsv`;
- `docs/research/wp40-simple-map-v1e-r3-preflight.tsv`;
- `docs/research/wp40-simple-map-v1e-preview.svg`; and
- `docs/research/wp40-simple-map-v1e-r2-review.md`.

The two identities are deliberately separate. `source.layout_id` remains
exactly `wp40-simple-map-v1d`: it is the geometry/hash-domain id used by the
accepted warp and may not change. V1e adds
`source.layout_revision_id = "wp40-simple-map-v1e"` for the anchor/path source
revision, artifact and SVG. The new artifact binds both fields explicitly;
keeping only one of them is a failure. Existing horizontal hash inputs continue
to use `layout_id`, never `layout_revision_id`.

The breaking record change is versioned explicitly. V1e changes
`source.schema` and `schemas.simple_map_source` from
`grug_wp40_simple_map_source_v1` to
`grug_wp40_simple_map_source_v2`, and the live R2 artifact schema from
`grug_wp40_simple_map_r2_artifact_v1` to
`grug_wp40_simple_map_r2_artifact_v2`. `schemas.simple_map` remains exactly
`grug_wp40_simple_map_v1`, `layout_id` remains V1d as above, and the accepted
warp/hash domains do not change. The R2 writer, R3 common loader and V1e
preflight bind and reject anything other than the new source/artifact schema
tokens; the migration extractor alone deliberately reads the verified V1
source and artifact.

## 2. Freeze the approved anchor layout

Before editing any R2-bound input,
`tools/wp40/simple_map_v1e_anchor_migration.lua` must load the accepted V1d
evaluator with full seed `"0"`, after verifying the accepted
R2 artifact body and file hashes. Before loading any evaluator input, it also
verifies every one of the artifact's 14 embedded `input_sha256` rows against
the working tree, then requires `layout_id = "wp40-simple-map-v1d"` and the
accepted seed-zero canonical KAT digest
`0a945840673d3170ce545c3c12af1422dcd12da5398a88faaf39c42d5346056d`.
Any mismatch fails closed. For all 100 anchors it records one geometry row in
stable anchor-id order:

- anchor id, zone id, slot id and exact x/z;
- source mode `authored_fixed` plus approved index `0` for all 16 existing
  fixed rows, or source mode `candidate_selected` plus the selected index
  `1..3` for all 84 current candidate rows;
- for each of the 74 migrated anchors that owns a POI spur, the exact selected
  candidate spur centreline; the ten migrated rare-route anchors record that
  no spur exists; the 16 authored-fixed rows own no POI-spur migration row; and
- one canonical digest of the complete table.

The extractor's canonical TSV is durable migration evidence and becomes an
input of the new R2 artifact. Its header binds a migration schema, seed `0`,
the accepted old body and file hashes, the canonical KAT digest and a canonical
roster digest of all 14 verified input paths and hashes. It must describe
exactly 100 anchor-geometry rows split into 16 authored-fixed and 84 migrated
rows, with exactly 74 spur-bearing and ten migrated rare/no-spur rows. It may
not infer positions from the SVG or copy values from an R3 draft. The new
artifact binds both the complete
migration-TSV SHA-256 and the extractor-script SHA-256, not only a digest
reported inside the TSV.

The same verified V1d extraction records the complete geometry of all 139
selected paths (57 land routes, 74 selected spurs and eight island routes),
not only their ids, and a canonical digest of that complete baseline source
view. Together with the 100 anchor positions, this is sufficient for the
final V1e diagnostic tool to reconstruct the pre-waypoint-edit x/z view
without retaining candidate arrays or loading an untracked pre-refresh R3
implementation. The extraction also records the canonical baseline
geometric-contact roster. For path ids `A < B`, `overlap_count` is the number
of integer x/z columns in both complete full-weight visible surfaces.
`touch_count` is the number of canonical orthogonal grid edges with one
endpoint in `A` only and the other in `B` only; an endpoint in the overlap set
does not count again as a touch. A pair is present when either count is
positive. Each row binds both ids, both counts, bounds over all contact
endpoints and the lexicographically first witness tuple
`kind,x1,z1,x2,z2`; an overlap repeats x/z in both endpoints. The sorted
complete roster has its own digest. This evidence is geometric only and never
creates a route-graph edge.

V1e then replaces every one of those 84 `candidate_set` rows with one
`layout_fixed` position equal to that migration row. The old selected index is
retained only as `approved_candidate_index` provenance. It is not a live
choice. The 16 already-authored fixed anchors remain distinct; stable anchor,
zone, slot and template ids do not change.

`selected_anchor_2d` and `selected_anchor_by_id` remain the compatibility query
names but become seed-independent. Their defensive result has exactly `x`,
`z`, `anchor_id`, `selection_mode` and `approved_candidate_index`:

- an authored-fixed anchor returns `selection_mode = "authored_fixed"` and
  `approved_candidate_index = 0`;
- a migrated anchor returns `selection_mode = "frozen_layout"` and its
  provenance value `approved_candidate_index = 1..3`.

The old `candidate_index` result field is removed from both 2D and 3D anchor
records and every consumer. A single-centreline POI spur is read directly and
is never selected by an index. Candidate arrays, candidate-path arrays,
candidate-selection hash domains and fallback/reselection behavior are removed
rather than retained as a second authority. The R2 artifact and canonical KAT
bind both exact result modes; R3 evidence mirrors and compares
`selection_mode` and `approved_candidate_index` without inventing a live
choice.

Each of the 74 POI spurs keeps one frozen centreline beginning at its frozen
anchor and ending at its existing zone hub. POI spurs remain independently
graded secondary roads or trails in R3; this refresh does not defer their
traversability to R5.

## 3. Selected-only exclusions and housing

Static POI and path exclusions use exactly the 16 authored-fixed plus 84
layout-fixed anchor envelopes (100 actual anchor exclusions), and exactly the
57 land-route, 74 single-spur and eight island-route corridors (139 path
exclusions). The two unused anchor alternatives per migrated anchor cease to
exclude claims; exactly 168 obsolete alternative envelopes are removed. Each
old multi-alternative spur row is reduced to its one frozen corridor rather
than retained as an invisible reserve. Together with the unchanged 29 water,
four coast and 42 active-protection exclusions, the canonical claim-exclusion
population is exactly 314. Its recipe counts, complete stable-id roster and
digest are artifact-bound. Housing POI bias likewise uses all 100 actual
anchors and no retired alternatives; the exact source token is
`all_actual_anchor_positions_v1`.

Anchor-exclusion identities preserve the corresponding real V1d footprint
rather than being renumbered. An authored-fixed anchor keeps
`exclude:anchor:<anchor-id>:01`. A migrated anchor keeps the one old
`exclude:anchor:<anchor-id>:NN` whose two-digit suffix equals its
`approved_candidate_index`. The exclusion record contains no live
`candidate_index` field and the two retired alternative ids disappear. This
preserves stable references to the approved physical footprint while making
the selected-only population unambiguous.

All ten housing masks therefore rerun the complete accepted R2 packing
portfolio and its exact erosion/conflict rules. No old capacity count is
carried forward. Every decided per-mask minimum must remain satisfied, and the
new artifact binds the complete counts, extrema, witnesses and digests.

## 4. Bounded authored path corrections

The diagnostic sequence is deliberately ordered in four reproducible stages:

1. Section 2 freezes the complete V1d seed-zero anchor and 139-path baseline
   before any R2-bound edit.
2. The anchor/API migration and the final V1e-compatible `height.lua`, R3
   loader and validator are completed, but no path waypoint is changed yet.
3. `tools/wp40/simple_map_v1e_baseline_diagnosis.lua` reconstructs a read-only
   baseline source view from the committed migration TSV and the otherwise
   final V1e source. It replaces all 139 live path centrelines and all anchor
   positions with their recorded baseline values, verifies the baseline-view
   digest, and runs the final R3 implementation against that view.
4. Only after that diagnosis is frozen may the bounded waypoint edits begin.

The diagnostic writes a canonical TSV with every final adjacent-axis
violation, including losing path/run, both x/z columns and heights, selected
winner path/run and the unordered path pair. It calls one read-only diagnostic
seam in the final bound `height.lua`; it may not reimplement height, path
selection or projection. Its header binds the accepted V1d R2 body/file
hashes, verified 14-input roster digest, complete migration-TSV SHA-256,
baseline-source-view digest, seed `0`, SHA-256 of
the final `mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua`, SHA-256 of the
final `mods/MAPGEN/grug_mapgen/wp40/height.lua`, its own file SHA-256 and
SHA-256 of the final `tools/wp40/simple_map_r3_validate.lua`. It also records
the non-cyclic semantic base as accepted Git commit `773387a54cdf` and the
then-current R3-contract SHA-256
`e02b51a89d42deb2be71a3524df444390a06ad31bb3a5c6347919f777d6a16b8`.
It does **not** hash the later V1e-amended R3-contract bytes: that amendment
binds the finished R2 artifact in the downstream direction and is not an
artifact input. The TSV must contain exactly 40 witness rows and exactly 14
unique sorted pairs matching the list below. A count, pair or hash mismatch
stops the refresh. The new V1e artifact binds the complete diagnosis-TSV and
diagnosis-tool hashes. The union of path ids in those 14 proven pairs is the
closed waypoint-edit authority. A SHA alone never stands in for unavailable
pre-refresh code: every executable implementation byte bound by this
diagnosis is part of the final reviewed V1e change set.

The seed-zero R3 diagnosis found these 14 path pairs:

1. `poi_spur_013` / `route_001`;
2. `poi_spur_023` / `route_016`;
3. `poi_spur_025` / `route_001`;
4. `poi_spur_029` / `poi_spur_051`;
5. `poi_spur_036` / `route_048`;
6. `poi_spur_045` / `route_016`;
7. `poi_spur_050` / `route_043`;
8. `poi_spur_060` / `route_054`;
9. `poi_spur_069` / `route_010`;
10. `poi_spur_077` / `route_055`;
11. `poi_spur_081` / `route_052`;
12. `poi_spur_086` / `island_route_stormscale_junction_apex`;
13. `route_051` / `route_056`; and
14. `route_052` / `route_056`.

V1e may add or move authored intermediate x/z waypoints only on paths named in
that closed list. Endpoints, path ids, station ids, route graph edges, classes,
surface/corridor widths and named interface positions do not move. A correction
may remove a coincident approach, near-pass or unintentional crossing; it may
not create a new named grade-separated operation.

The post-refresh full-weight overlap/orthogonal-touch roster is derived with
the exact V1d contact predicate and bound in V1e evidence. Every post-refresh
unordered pair must already exist in the verified baseline roster; a newly
contacting pair is a failure. Removed pairs and reduced contacts are allowed.
For retained pairs, post-refresh counts, bounds and first witnesses are
reported rather than treated as graph edges. The authored 57-edge route graph
is checked separately and remains byte-for-byte identical in ids and endpoint
pairs.

The complete frozen path set is rescanned after every correction. A new
forbidden-water, exterior, endpoint, interface, route-class, owner or final
vertical violation is a failure, not authority to edit another path. If a
necessary correction falls outside the closed list or needs a new interface,
this contract stops and must be amended and independently reviewed first.

The correction is deliberately authored and small. There is no candidate
search, overlap optimizer, automatic rerouter, seed-dependent waypoint or
runtime repair pass.

### 4.1 Exhaustive R3 hydrology-contact closure

The first exhaustive fixed-layout, seed-zero R3 extent scan exposed a separate
frozen-source omission after the bounded path correction was complete. Its
closed unordered reach-pair roster contains four unequal-level Raincall pairs
that already have exact named rapid or waterfall records and exactly three
pairs without a named level-transition interface:

1. `hydro_highcourt_fork_west` (+34) /
   `hydro_goldmead_millriver` (+16);
2. `hydro_gravesalt_pans` (+100) / `hydro_broken_marsh` (+8); and
3. `hydro_raincall_plunge` (+44) /
   `hydro_whispering_reedmaze` (+8).

The R2 water validator derives the final seed-zero contact evidence solely from
the authoritative horizontal evaluator and the finished source. The R2 writer
serializes its deterministic scan order, every pair's count, bounds and
lexicographically first edge witness into the live R2 artifact, whose ordinary
input roster binds the source, evaluator, water validator and writer bytes. It
does not load or hash `height.lua` or R3 tooling. The fixed horizontal layout
makes this roster seed-independent; the expensive complete extent contact scan
is therefore run once at seed zero. During the later four-seed vertical
preflight, the R3 validator independently reconstructs the same roster and the
preflight TSV binds the final source, `height.lua` and R3-validator SHA-256
values plus the R2 roster digest. No additional contact-evidence file and no
R2-to-R3 hash cycle is introduced.

V1e may close only those three pairs. They are contact-face waterfalls rather
than broad rapids or interpolated drop corridors: a rapid promises a
traversable sloped water surface, while these 18-, 92- and 36-node level
changes are intentional vertical fall faces at the already frozen boundary
between two planned-water reaches. Their complete source values are:

| interface id | upper / lower reach and offsets | marker position | drop | contact edges | upper-lip columns | lower-face columns |
|---|---|---:|---:|---:|---:|---:|
| `highcourt_goldmead_fall` | `hydro_highcourt_fork_west` +34 / `hydro_goldmead_millriver` +16 | `(-100,-1780)` | 18 | 13 | 13 | 13 |
| `gravesalt_broken_fall` | `hydro_gravesalt_pans` +100 / `hydro_broken_marsh` +8 | `(-1700,80)` | 92 | 163 | 114 | 114 |
| `raincall_reedmaze_fall` | `hydro_raincall_plunge` +44 / `hydro_whispering_reedmaze` +8 | `(2100,1900)` | 36 | 109 | 66 | 65 |

Every row has `kind="waterfall"`,
`transition_profile_id="waterfall_drop"`,
`transition_scope_id="orthogonal_reach_contact_face_v1"`,
both `drop` and `drop_height` equal to the literal drop in the table above,
`bed_seal_layers=3`, `bank_seal_nodes=2`,
`receiver_source_omission_nodes=1`, and `sealed=true`. The marker position is
SVG and human-inspection metadata only;
it has no membership, orientation or height authority. These rows have no
`axis_start`, `axis_end`, `run`, `width`, `drop_mask_width`,
`drop_mask_length`, `plunge_width` or `plunge_length` field. Their exact
secondary identities are:

| interface id | lip id | drop id | plunge id | plunge profile |
|---|---|---|---|---|
| `highcourt_goldmead_fall` | `highcourt_goldmead_lip` | `highcourt_goldmead_drop` | `highcourt_goldmead_plunge` | `river` |
| `gravesalt_broken_fall` | `gravesalt_broken_lip` | `gravesalt_broken_drop` | `gravesalt_broken_plunge` | `ordinary_lake` |
| `raincall_reedmaze_fall` | `raincall_reedmaze_lip` | `raincall_reedmaze_drop` | `raincall_reedmaze_plunge` | `shallow_marsh` |

The footprint is derived from authoritative horizontal classification, not
from authored centreline overlap or an invented diagonal axis. For one row,
let `C` be the set of ordered orthogonal grid edges `(u,l)` for which `u`
classifies as `planned_water` owned by `upper_id` and `l` classifies as
`planned_water` owned by `lower_id`. Construction scans the inclusive integer
intersection of the two conservative reach-support bounds, each formed from
the extrema of every centreline point plus its `half_width` and expanded by
one node. It checks the four neighbours of every upper column and then sorts
`C` by `(upper_z,upper_x,lower_z,lower_x)`. The deduplicated upper endpoints,
sorted by `(z,x)`, are the upper-lip set; the deduplicated lower endpoints are
the lower-face set. The source count table above is binding, every set is one
8-connected component, and an empty, extra or differently ordered contact is
a failure.

The upper-lip columns keep their ordinary upper-reach bed and water surface.
The lower-face columns keep their ordinary lower-reach bed, but
`water_surface_at` is `nil` there and
`hydrology_transition_values_at` returns the named waterfall, its exact upper
and lower surface y values, `progress_q=nil`, and a scalar `face_mask`. The
mask is the sum of bit 1 for an upper neighbour at `(x-1,z)`, bit 2 for
`(x+1,z)`, bit 4 for `(x,z-1)` and bit 8 for `(x,z+1)`; at least one bit is
set. Existing callers may ignore the appended scalar. No other column changes
terrain, water or functional classification. R5 does not author a vertical
water column. Let `lower_bed_y = lower_y - lower_profile.depth`. An ordinary
lower-pool column contains source liquid at every integer y from
`lower_bed_y + 1` through `lower_y`, inclusive. In a lower-face column R5
instead writes source liquid only from `lower_bed_y + 1` through
`lower_y - 1`, omits exactly the top source at `y=lower_y`, and leaves the bed
at `lower_bed_y` unchanged. The interval is empty when the lower profile has
depth one; in that case the solid bed remains at `lower_y - 1` and native
falling liquid settles into the single receiver node at `lower_y`. Air remains
from that one-node-deep receiver through the upper fall height, and the named
bed/bank seals remain binding. The omission never excavates or lowers the
ordinary lower bed. This receiver prevents the falling liquid from treating
the pool's top source as a solid support and spreading one node above the
intended pool surface.

The source records retain their existing abstract
`water_node_semantic="surface_water"` value. For WP40 materialization that
semantic has one exact context-dependent binding: every wet named hydrology
reach and every flowing node produced from it uses
`default:river_water_source` / `default:river_water_flowing`; the dry channel
materializes no liquid. Base oceans, bays and other non-hydrology surface
water continue to use `default:water_source` / `default:water_flowing`.
The pinned game registration proves river water is non-renewable and has
`liquid_range=2`; those properties are required, not incidental.
Non-renewability prevents two same-level neighbours from recreating an omitted
receiver source or a hanging source sheet across the open fall face. The
two-node range separately bounds lateral flowing spread at fall landings and
at frozen reach-to-bay mouths. R5 fails closed if either node is absent or its
registered source/flowing alternatives, renewability or range do not match
this rule. This material binding changes no horizontal ownership, reach
footprint, bed, surface-y query or logical biome.

Every face column has an orthogonally adjacent upper river-water source column,
so Luanti's ordinary liquid simulation creates the falling water naturally.
Because WP40's R5 pass writes these
source/air boundaries after the native mapgen liquid scan, R5 must call
`VoxelManip:update_liquids()` exactly once after its final liquid-buffer update
and before the generation callback returns. R5 never hand-authors a vertical
falling-water column. Thus any large terrain-height change occurs only across
one of the named upper/lower contact edges; every same-reach edge on the
operation boundary has zero bed-height change. There is no arbitrary side or
end of a broad transition corridor and no separately materialized waterfall
geometry.

For this scope, `plunge_id` is stable operation identity and
`plunge_profile_id` must equal the lower reach profile; there is no separate
plunge rectangle. The unchanged lower reach remains the plunge/outflow water,
including every `hydro_raincall_plunge` column belonging to the existing
`raincall_lower_fall`. The accepted two Raincall rapids and two cardinal
Raincall waterfalls keep their current axis, mask and plunge geometry
byte-for-byte; their later voxel materialization follows the same common
river-water binding as every other wet named reach. The new contact-face branch
is selected only by the exact scope token above, so neither their
transition-only masks nor their plunge reaches are drained or reinterpreted.

The independently reproduced frozen populations are:

| interface id | first ordered edge `(upper)->(lower)` | upper bounds | lower bounds | uncovered pair edges | path-surface / path-corridor columns |
|---|---|---|---|---:|---:|
| `highcourt_goldmead_fall` | `(-106,-1756)->(-106,-1757)` | `(-106,-1756)..(-94,-1756)` | `(-106,-1757)..(-94,-1757)` | 0 | 0 / 0 |
| `gravesalt_broken_fall` | `(-1713,21)->(-1712,21)` | `(-1713,21)..(-1650,110)` | `(-1712,21)..(-1649,110)` | 0 | 0 / 0 |
| `raincall_reedmaze_fall` | `(2070,1864)->(2069,1864)` | `(2026,1864)..(2070,1929)` | `(2026,1864)..(2069,1928)` | 0 | 0 / 0 |

The validator independently reconstructs the complete edge and endpoint
sets, direction masks, counts, bounds, first witnesses and canonical digests.
It proves that every unequal upper/lower contact edge for the three newly
closed pairs belongs to exactly one of the three contact-face falls, every
lower-face column has the recorded nonzero mask, every same-reach boundary
edge keeps the ordinary reach bed, and no lower-face
column overlaps an existing rapid/cardinal-waterfall transition-only mask or
any route surface, route corridor or named route operation.

The only protection/fitting intersections are also frozen and explicit. For
`highcourt_goldmead_fall`, all 13 upper-lip columns lie in `anchor_008`'s
full-weight fitting square and all 26 lip/face columns lie in its blend square
and `hard:anchor_008`; no lower-face column lies in the full-weight square.
For `gravesalt_broken_fall`, one upper-lip column lies in `anchor_077`'s blend
square and none lies in its full-weight square; there is no hard-protection
intersection. Raincall/Reedmaze has no anchor fitting or hard-protection
intersection. This is not a protection exception: world generation creates
the Highcourt civic water and fall first, and the existing hard volume then
protects the generated result from later player mutation. The live design text
must state that ruling explicitly.

The operations use the already frozen landscape authority rather than adding
three new landmark geometries: Highcourt/Goldmead binds the existing
`highcourt_riverfork` and `goldmead_millriver` landmarks; Gravesalt/Broken
binds `gravesalt_whitewall` and `broken_marsh`; Raincall/Reedmaze binds
`raincall_falls` and `whispering_reedmaze`. The live design text names each
fall under those landmark descriptions, and metadata/evidence proves the
two reach-to-landmark references for every operation.

All 25 reach records and all 12 existing interface records remain
byte-for-byte unchanged. The live simple-map source/evaluator assertions, R2
metadata roster, `height.lua`, R3 validator, R3 contract and evidence update
from 12 to exactly 15 total interfaces. Exactly seven of those 15 bind an
unequal-level upper/lower pair: two rapids and five waterfalls. The other
eight retain their confluence or route-operation meanings. The retired exact
T2 catalog validator at `mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua`
remains historical reproduction code with its historical population; it is
not a simple-map V1e consumer and is neither edited nor executed.

After the final source, height and validator bytes exist, the baseline
diagnosis is regenerated and additionally binds the complete final source-file
SHA-256. It must remain exactly 40 witnesses over the same 14 path pairs. The
path-contact roster may gain no pair, and every live R2/R3 gate is rerun. Any
fourth missing unequal-level pair, uncovered named pair edge, changed
diagnosis population, infeasible exact pin, new route violation or need to
modify a reach footprint stops this amendment rather than authorizing another
water edit.

## 5. Acceptance gates

V1e is accepted only when all of the following are true:

1. Before V1e supersession, current authority is reconciled with both bounded
   omissions. `docs/design/world_zones.md` binds all 84 secondary anchors
   to the seed-independent positions migrated from accepted V1d seed zero and
   selected-only exclusions. It also names the Highcourt-to-Goldmead fall,
   the Gravesalt Whitewall fall and the Raincall-to-Reedmaze outfall without
   changing any reach footprint. It binds named WP40 hydrology to
   non-renewable `default:river_water_source` while oceans, bays and other
   non-hydrology water retain `default:water_source`.
   `docs/design/world.md` Section 2b is amended to the same material rule;
   neither its lake/river/marsh/cenote sentence nor
   `docs/design/world_zones.md`'s two universal-default-water sentences may
   remain live. The current `wp40-engineering-brief.md` describes both that
   water-node rule and the fixed-anchor revision;
   `wp40-simple-map-rebase-plan.md`, `README.md` and `BACKLOG.md` describe the
   same fixed-anchor revision. The active
   sections of `wp40-simple-map-r3-contract.md` bind the reviewed V1e R2
   body/file/input hashes, both layout identities, seed-independent anchor
   result fields, single-centreline spur semantics, the orthogonal
   contact-face waterfall rule, its exact edge/endpoint derivation, the
   one-source-node lower receiver, the river-water material rule, the later R5
   liquid-queue obligation and the exact 15-interface population in the same
   change set. `height.lua` and the R3
   validator implement and independently reconstruct that same predicate;
   merely documenting the records is not sufficient.
   Historical V1d artifact bytes remain available at Git commit `d337160`, and
   the V1d R2 review plus historical R3 review narrative retain their
   then-correct candidate records as historical evidence; neither is rewritten
   to pretend V1e already existed. An uncommitted V1e candidate may occupy the
   live path only under the authority rule in Section 1. This R3-document
   amendment is downstream of the finished R2 artifact: neither the artifact
   nor its diagnosis transitively hashes the amended document bytes.
2. The old R2 body digest
   `73165e1ad9e9dd03bc608b544e5906a10df2bf7b2c23779b311ad3cbdadf4f7b`
   and complete-file SHA-256
   `02585d6644265e8889edb3311045d76c2dd7152700dff33563bd8daabc13c339`
   pass before migration extraction. All 14 embedded V1d input hashes match
   the working tree before load, and the V1d seed-zero canonical KAT and
   geometry layout id match the exact values in Section 2. The migration TSV
   binds the complete 139-path baseline source view and the exact
   `tools/wp40/simple_map_v1e_anchor_migration.lua` bytes.
3. The source contains exactly 16 authored-fixed and 84 layout-fixed anchors,
   zero candidate arrays, 74 single-centreline POI spurs, 57 unchanged
   land-route identities and eight unchanged island-route identities. Claim
   exclusions contain exactly 100 anchor, 139 path, 29 water, four coast and
   42 active-protection records, 314 total, with housing bias over the same 100
   actual anchors under token `all_actual_anchor_positions_v1`. The 100 anchor
   exclusions use the exact selected V1d identities defined in Section 3. No
   evaluator, R3 loader, validator or evidence record reads or emits the old
   `candidate_index` field. Source and artifact schemas are
   exactly `grug_wp40_simple_map_source_v2` and
   `grug_wp40_simple_map_r2_artifact_v2`; `schemas.simple_map` remains
   `grug_wp40_simple_map_v1`.
4. Every existing R2 metadata, core, water, route, grid, topology, contact,
   difficulty, housing, portability and determinism gate is rerun against the
   new source. Removed candidate-population assertions are replaced by exact
   frozen-layout assertions; no unrelated gate is weakened. The warp digest,
   finite proof bounds and no-fold witnesses remain byte-for-byte identical to
   accepted V1d.
   The R3 hydrology-contact gate additionally proves that every adjacent
   unequal-level wet-reach pair is bound to one of the exact seven named
   upper/lower interfaces after Section 4.1. It separately proves the two
   existing rapid corridors and the two existing Raincall waterfall corridors
   under their unchanged rules, then reconstructs every edge, endpoint,
   direction mask, bound, classification digest and contact-closure witness
   for the three new contact-face waterfalls. The negative scope branch is
   explicit: none of the four accepted Raincall transitions may enter the new
   construction. The remaining eight interfaces retain their distinct
   meanings.
5. The new canonical artifact binds every executable input hash, the complete
   migration-TSV SHA-256, the extractor-script SHA-256,
   baseline-diagnosis-TSV SHA-256 and diagnosis-tool SHA-256,
   `layout_id = wp40-simple-map-v1d`,
   `layout_revision_id = wp40-simple-map-v1e`, the fixed-anchor/spur roster and
   complete new housing result. It also binds the verified baseline and final
   path-contact roster digests plus every final pair's counts, bounds and first
   witness, the seed-zero hydrology-contact roster and the three complete
   waterfall edge/endpoint/direction-mask proofs, and fails on a new path or
   unbound unequal-level pair. That roster is produced only by the R2 water
   validator from the horizontal evaluator; neither `height.lua` nor any R3
   executable is an R2-artifact input. The diagnosis header
   binds the final source-file SHA-256 in addition to its existing executable
   hashes. LuaJIT owns exhaustive populations;
   targeted PUC 5.1 reproduction remains byte-identical by canonical digest.
   The baseline diagnosis is reproducible from the committed migration TSV
   and final V1e implementation; it has no dependency on discarded or
   untracked pre-refresh R3 bytes.
6. With the final V1e candidate bytes, complete R3 sessions are constructed
   for full seeds `0`, `1`, `9223372036854775808` and
   `18446744073709551615`, then run through the accepted R3 evidence/API
   validator. The exhaustive pass covers every axis and complete visible
   surface of all 57 land routes, 74 POI spurs and eight island routes, every
   freshly constructed endpoint/ford/tunnel exact pin, all water operations
   and both complete 2D central-33 tunnel proofs. “Exact pin” here means that
   final composition and envelope closure leave each freshly constructed pin
   equal to its rule target; it is not a comparison with an old run index.
   Every final adjacent centreline step is at most one and every violation
   count is zero. The preflight independently reproduces the R2 contact-roster
   digest and binds the final source, `height.lua` and R3-validator SHA-256
   values that performed the reconstruction. The canonical per-seed evidence
   digest, all gated counts and extrema, the candidate R2 body/file hashes, and
   a sorted SHA-256 roster of
   `tools/wp40/run_simple_map_r3.sh` plus every downstream preflight Lua file
   it loads are committed in
   `docs/research/wp40-simple-map-v1e-r3-preflight.tsv`. The fresh V1e review
   record binds that TSV's complete SHA-256 and independently checks the
   executable roster. These downstream preflight hashes are review evidence,
   not R2-artifact inputs, so they introduce no artifact/document hash cycle.
   This is a vertical feasibility preflight for the refreshed x/z source, not
   R3 acceptance.
7. `docs/research/wp40-simple-map-v1e-preview.svg` is rendered from the
   provisional source with revision label `wp40-simple-map-v1e`. It shows the
   same land, zones, bays, hydrology, anchor positions and route graph as the
   approved V1d image, with only the bounded path-curve changes and the three
   newly named fall markers above. The preview is re-rendered after the
   hydrology amendment; the pre-amendment V1e preview is not acceptance
   evidence. V1e requires explicit user visual approval before the candidate
   R2 artifact is called accepted or committed.
8. A fresh read-only reviewer checks the authority/design diff, migration,
   R3-contract active-section amendment, source diff, SVG, R2 artifact,
   four-seed preflight TSV and its executable-hash roster, and
   interpreter/portability evidence. Any Critical,
   High, Medium or Low finding blocks acceptance until corrected and
   rereviewed. Its durable record is
   `docs/research/wp40-simple-map-v1e-r2-review.md`; acceptance names
   `docs/research/wp40-simple-map-r2-artifact.tsv` as the sole live R2 artifact
   and V1d at commit `d337160` as superseded history. The accepting commit must
   contain bytes identical to the artifact hash reviewed in that record and
   the reviewed R3 authority amendment; a post-commit hash check is part of the
   completion evidence.

The reviewed R3 authority amendment lands atomically with V1e supersession;
there is no interval in which V1e R2 is authoritative while the live R3
contract still binds V1d inputs or candidate-selection semantics. `height.lua`
and the R3 artifact remain separately unaccepted until their own gates pass.

## 6. Stop conditions

Stop rather than widening the refresh if:

- a land, zone, bay, hydrology, housing-policy, route-graph, hard-protection or
  difficulty decision beyond the exact three-interface closure and named
  hydrology river-water material binding in Section 4.1 must change;
- any endpoint, named interface or stable public id must move;
- a path outside the closed correction list must change;
- the four-seed vertical preflight requires a graph solver, per-seed geometry,
  endpoint reselection or relaxed one-node slope gate; or
- the visually reviewed macro layout changes beyond local path curvature.

## 7. Independent review record

The independently accepted anchor/path contract review used GPT-5.6 Sol at
xhigh effort in a fresh, read-only context. Across that complete review it
found 0 Critical, 7 High, 8 Medium and 0 Low issues; its final rereview returned
**ACCEPTED**, 0 Critical / 0 High / 0 Medium / 0 Low.

The later hydrology amendment received a separate Opus xhigh review. Its first
three drafts were rejected. The first two exposed the false assumption that a
narrow rapid corridor could represent the 92-node Gravesalt level change
without a large lateral water wall, plus scope, evidence and authority gaps.
The third draft's wide reach-clipped masks still created 25- to 77-node side
walls, drained part of the accepted Raincall plunge area and left diagonal
plunge construction undefined; its final review returned 1 Critical / 2 High /
3 Medium / 1 Low. The fourth draft replaced those masks with minimal
transition-only faces derived directly from the complete orthogonal
upper/lower contact edges; independent LuaJIT and PUC 5.1 reproduction found
the geometry exact, but review returned 0 Critical / 0 High / 3 Medium / 0 Low
for one overbroad edge statement, a missing liquid-queue trigger and cyclic
R2/R3 contact-evidence wording. The focused rereview closed those three issues
but returned 0 Critical / 2 High / 0 Medium / 2 Low: renewable ordinary water
would recreate receiver sources and hanging upper source sheets on the two
broad faces, while the row and depth-one receiver wording was incomplete.
Section 4.1 now scopes the edge claim, makes the evidence order acyclic, binds
`VoxelManip:update_liquids()`, defines the receiver interval at every depth,
sets both literal drop fields, and maps all wet named hydrology to Luanti's
non-renewable two-node-range river water. Oceans and bays keep ordinary water;
reach geometry, beds, surface-y authority, protection and path intersections
remain unchanged. The next focused rereview confirmed all four liquid/receiver
findings closed and reproduced the geometry under LuaJIT and PUC 5.1, but
returned 0 Critical / 0 High / 1 Medium / 1 Low because gate 1 omitted
`docs/design/world.md` and the engineering brief's water sentence, and because
the text attributed source-renewal prevention partly to liquid range. The
current draft names every conflicting live authority and assigns renewal
prevention solely to `liquid_renewable=false`; range two separately bounds
lateral flow. The final focused Opus xhigh rereview returned **ACCEPTED**,
0 Critical / 0 High / 0 Medium / 0 Low. This acceptance covered the refresh
contract only; implementation acceptance is recorded below.

## 8. Implementation completion record

The bounded refresh completed on 2026-08-27. The user explicitly approved
`docs/research/wp40-simple-map-v1e-preview.svg`, complete-file SHA-256
`5816941d7bb7524a653b7cbe6b471f842be8bdc89db5e18f9fbf2017555e8fdc`.
The artifact at the sole live R2 path is now V1e, with canonical body/file
SHA-256 values
`1a819192fa40254aa6da1ebf5f3fa5286790ef907abe09750455e5e24c881a8b` /
`ba6e684b232e963251c3582e521c46a9364d602256eba9b6115bd0575e4c9c4b`.
The four-seed vertical-feasibility preflight completed with body/file SHA-256
values
`de2e1d5a244785a3ca74e737e3848102f8b807d77043b058dc581a9f69d0898e` /
`f3ccf699df1d67083730ccade57ea829fb8a618a1ee8e93890d41a1548d840e3`.

The fresh implementation review and focused rereview are recorded in
[wp40-simple-map-v1e-r2-review.md](wp40-simple-map-v1e-r2-review.md). The
initial review found 0 Critical / 0 High / 1 Medium / 1 Low; one correction
round closed both findings, and the final verdict was **ACCEPTED** with zero
findings. V1d remains immutable historical evidence at `d337160`. This record
accepts V1e R2 only: the R3 implementation, production planner/materializer
and Luanti runtime world remain unaccepted later work.
