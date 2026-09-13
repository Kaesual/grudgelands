# WP40 local terrain quality follow-up

Status: implementation and independent review complete on `wp40-mapgen-quality`,
2026-09-13; final integration evidence below. WP40 R8 visual acceptance remains open.
Baseline: `0d06276`. Classification: non-trivial correctness, geometry and
performance change. The user authorized implementation after the local
playtest diagnosis in `wp40-mapgen-profile-tree-fix.md`.

## Scope and invariants

- Natural ore stays removed after mining or shattering. The obsolete global
  replenishment hook and depleted-node registration are removed completely.
  The user explicitly declined legacy cleanup because there are no old
  servers to migrate: no LBM, compatibility timer or replacement alias.
  Protected mining-camp sockets remain the sole separately specified
  renewable exception.
- Improve capital fitting, landmark transitions and road terrain following;
  add small-scale relief, coherent surface material patches and bounded
  surface cave openings. Fixed R2 horizontal geography, zone ownership,
  anchor positions, protected envelopes, water routing and gameplay tiers
  remain authoritative. The 512 by 512 capital build envelope is not a
  requirement to flatten its entire area; its civic core remains usable.
- Resource performance changes initially preserve complete generated output.
  Geometry/material changes deliberately change fresh-world output. Neither
  class of change rewrites existing terrain or resets any user world.
- One globally queryable height authority and one consolidated VoxelManip
  writer remain. Surface selection must agree across planning, settlement and
  prospective decoration support; cave cuts must not open engineered seals,
  protected functional volumes or water containment.

Implementation formulas and their targeted evidence are recorded below before
integration. Historical R3/R6 artifacts remain historical evidence and are not
rewritten to make the new output appear unchanged.

## Verification and delivery

Use LuaJIT for development and bounded geometry/resource comparisons. Run the
plain-5.1 parser, SETGLOBAL inspection and all five source sweeps, including
changed tool Lua explicitly. On frozen final bytes run one compact PUC 5.1
fixture and the same fixture once under LuaJIT, with byte-identical canonical
output. No intermediate PUC runtime or retired full-W/T2 populations. Respect
the workstation-wide seven-process cap and idle scheduling.

Measure fresh-world callback costs in the existing isolated Rehearsal harness,
with engine, seed, corpus and container limits held fixed. Require full output
parity for the resource-only change and successful disk-only reloads. Geometry
acceptance includes reproducible height/material views around the dwarf start
and the road near `(1000, 1000)` for seed string `13191094842853985814`, plus
targeted water, anchor and cross-slice regressions. Visual quality remains a
user GUI gate; numerical validity alone is not acceptance of appearance.

Integrate only after independent strong-agent review, then sync from main to
the local Luanti installation. No Production deployment is part of this work.

## Delivered behavior

The implementation is split into the [height/road semantic record](wp40-quality-geometry.md),
[surface cave record](wp40-quality-caves.md), and
[fresh material cleanup](fresh-server-cleanup-materials.md).
The decided vertical/material/cave rules now also live in
`docs/design/world_zones.md` §§7.6/12. The global fresh-server rule is recorded
near the top of `AGENTS.md` and overrides old development-era migration plans.

The 512-node capital slab is replaced by a fixed 96-node civic core and
terrain-adapted terraces. Routes project local terrain into existing exact
pin, water and grade constraints. Broad relief gains 32/64-node detail;
landmark influence feathers across its owner's coarse boundary. A shared
surface selector adds coherent soil/grass/gravel/stone patches and filler
variation. Sparse dry hillside tubes are cut through the existing writer and
excluded from later vegetation support.

All old-world material aliases, old ore/depleted behavior and vendored format
conversions/API shims identified by the repository audit are removed. Current
content curation explicitly removes 53 unwanted loaded vendor registrations,
retains 22 canonical derivatives and uses canonical recipe ingredients.
Normal same-version save/reload, current camp activation LBMs, sapling timers,
opened-chest recovery and native engine mapgen aliases remain required.
`tools/check_fresh_server.py` guards the removed mechanisms without adding any
runtime world-migration check.

## Real engine measurements

Raw logs, harness/source hashes, environment and summaries are in
[wp40-quality-evidence/](wp40-quality-evidence/). Every successful run used
Luanti 5.17.0 with LuaJIT in the same isolated Rehearsal container image
`afec763ab3efa150171f4a024b036145bab419cf9ee6921a3cd0c76432c1f780`,
3 GiB memory and 2.5 CPU limit. No managed service or existing world was changed.

| Run | Plan total | Writer total | Callback total | Slowest callback |
|---|---:|---:|---:|---:|
| Baseline, `quality-before-2` | 3.403 s | 12.349 s | 15.752 s | 7.470 s |
| Resource-only, `quality-resource-1` | 3.535 s | 11.205 s | 14.740 s | 6.890 s |
| Integrated, `quality-final-1` | 3.998 s | 10.114 s | 14.113 s | 6.430 s |

The resource-only change reduces aggregate callback time by about 6.4% in
**one matched pair**, with the same complete 5,120,000-voxel content/param2/light
digest `cf1d61f5cfd6355988bccd93a5c98ea8dbb8379a456fc3efe7872903c5e6466d`.
It computes horizontal eligibility once per column and skips root hashing and
ranking whenever the eligible population produces a zero budget. This is a
bounded observation, not a stable median or a v7 comparison.

The integrated run uses the same ten horizontal waypoints, resolving their
surface owners from the revised geometry. Changed terrain changes the workload
and may change an owner's vertical coordinate; its timing is therefore not an
output-preserving speed comparison. Its complete owner digest is
`19813420450830ff7049efb436d3f45bfd35694a0a1cb66bb6235c9edb682225`.
The resource-heavy deep slice remains the largest measured cost. Further work
should target that writer path rather than promise that extra mapgen threads
alone make this Lua pipeline as fast as native v7.

Every successful restart loaded 1,250 mapblocks from disk, with zero mapgen
callbacks and matching complete owner digests. `quality-integrated-1` initially
failed only the smaller diagnostic sample: it read outside requested owners,
where cold generation had transient neighbouring halos. Its full owner digest
already matched cold/disk. The v2 owner-bounded sample fixes that test; the
unmodified stronger digest also passes in `quality-final-1`.

The separate `quality-caves-1` corpus checks all **416 actual air voxels** of a
32-node tube crossing two owners at `(1643,72,-1983)` in seed `0`, after the
complete P5/P7/P8/P9 writer and again on restart. Both phases report
`expected_nodes=416`; full digest
`3760eaedffd6c1408eb2ad06ca559210fe5639c24d7ecfbf226bd764681168a5`
is identical. The corpus is selected reproducibly through
`WP40_PROFILE_CASES` and bound in the harness/snapshot manifests.

## Geometry and remaining limits

[Before/after relief](wp40-quality-evidence/terrain-before-after.png) and
[cross-sections](wp40-quality-evidence/terrain-cross-sections.png) use the real
height authority at 84,211 identical four-node sample positions for full seed
string `13191094842853985814`. Their compressed TSV inputs, hashes and
sampling/plotting scripts are retained. These are authoritative terrain
surfaces, not screenshots and not proof of client-visible appearance.

The local road five-point probe changes from y=9..40 to y=16..17; the broader
road sample's 95th-percentile adjacent grade drops from 2.5 to 0.25. Dwarf
capital and start regions show finer relief and reduced abrupt grading, but
large authored landmarks, waterways and fixed hubs can still produce steep
features. In particular, the fixed Kezamba civic core cannot meet the 24/16
cut/fill target on either tested seed; its existing station floor produces
explicit excesses of 30/31 nodes. This is recorded rather than hidden by a
fallback or a moved core. Cave openings are sparse and may end blindly; no
native-network connection is promised.

The integrated bounded search finds 23 hillside entrances for the user seed
and 17 for seed `0`. The user-seed cross-owner witness is `(2010,75,-1098)`,
heading in positive z. Independent geometry tests passed both seeds, all six
capital constraints, road pins/grade, repeated-query order and ordinary water
constraints. Historical R3–R7 evidence remains historical; full current R8
visual and release acceptance is still open.

## Verification and review

[Independent review record](wp40-quality-review.md) covers every non-trivial
scope and the resolved findings. Changed Lua passes the plain-5.1 parser,
expected-global inspection and all five sweeps, including tool Lua. The only
sweep hits are comments, a literal delimiter and explicit host-only SHA/git
commands in offline tools. Source and material audits pass; the prior tree
slice and resource-order regressions remain in the combined fixture.

The original final parity attempt is retained as a failed **test-tool** gate:
its surface catalog setup called an FFI MTS decoder under PUC. A reviewed
header-only catalog fixture removes that dependency without changing game
bytes. The replacement pair binds 1,753 inputs and exercises the same compact
fixtures under PUC 5.1 and LuaJIT, including 73 actual R7 production modules,
current vendor/player/book/chest/mob state, natural ore removal, material
curation, surface selection, cave decisions, geometry arithmetic and resource
ordering.

The replacement final pair **passes** on candidate `f5e9a1c` (game bytes
unchanged from `5a61b63`): PUC 5.1 and LuaJIT 2.1.1767980792 each produce
8,828 byte-identical bytes, SHA-256
`c577859417107480fdbdab8d3fec25fafa5e486a1775df05030a21a4f0cb63dd`.
All 1,753 bound inputs pass the post-run unchanged-hash check. The
[final parity receipts](wp40-quality-evidence/final-parity/output.sha256),
interpreter hashes/logs and original failed test attempt are retained alongside
the engine evidence. The independent reviewer inspected these immutable
artifacts and issued unconditional ACCEPT with zero open findings. No further
PUC execution was needed. This standalone parity gate does not substitute for
a real fallback-engine runtime test.

## User runtime test plan

Restart the local Luanti process after sync and create a fresh world, optionally
with seed `13191094842853985814`. Select a dwarf and inspect the start and
capital; fly through the road area near `(1000,1000)` and the hillside entrance
near `(2010,75,-1098)`. Look for material patches, continuous tree trunks,
terrain-following roads and open cave mouths. Mine an ordinary natural ore,
leave and reload the same current-version world: the removed node must stay
air. Check one vendor/current mob and the character appearance after joining.
A separate real fallback-engine GUI test remains user-owned.
