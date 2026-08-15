# WP40 T2 execution plan and state

Status: **living plan. Supersedes any ordering stated elsewhere.**

The other WP40 documents each own one thing and none owns this:
[wp40-engineering-brief.md](wp40-engineering-brief.md) is the contract,
[wp40-source-authority.md](wp40-source-authority.md) the compiler algorithm,
[wp40-reality-corrections.md](wp40-reality-corrections.md) the evidence
history, [wp40-t2-degeneracy-completeness.md](wp40-t2-degeneracy-completeness.md)
the bound on what remains open, and
[wp40-t2-handover.md](wp40-t2-handover.md) a factual snapshot. This file holds
what is being done next, in what order, and why — the part that was living only
in a chat session until 2026-08-16.

## 1. Where T2 actually stands

`compiler.lua` builds 20 named geometry buckets. Their status:

| group | buckets | state |
|---|---|---|
| boundary topology | `land_boundaries`, `perimeters`, `bays`, `mouth_apertures`, `closure_wings`, `dry_faces` | computed and verified **offline only** |
| local pure fields | `relief_fields`, `templates`, `route_profiles`, `hydrology` | not started |
| downstream of a frozen perimeter | `coast_shelf`, `islands`, `channels`, `hard_protection`, `claim_exclusions`, `housing_masks` | not started |
| downstream of zone faces | `anchors` | not started |
| other | `zones`, `land_routes`, `boat_routes` | source records exist; not compiled |

Plus three selectors — logical biomes, nearest-feature, housing-centre — all
unstarted.

**The production path is not wired.** `compiler.lua:77` loads
`geometry/compiler_impl.lua`; that file does not exist, so the production entry
fails closed with `compiled_geometry_unavailable`. Everything achieved so far
runs through the offline harness driving `geometry/partition.lua` directly.
Creating `compiler_impl.lua` is a required step that appears in no task list;
it belongs immediately after the boundary geometry is final, not before, since
until then it would track a moving target.

T0 and T1 are complete. T3 through T9 have not started.

## 2. Ordering, and why census comes before conformance

**Run the census scans before the C1 selected-four conformance.** Not the other
way round.

C1 conformance is historically the generator of Reality corrections. Per
[wp40-t2-handover.md](wp40-t2-handover.md) section 3, R18 was found by the
first selected-four C1 PUC attempt, in slots 29 and 30; R19 by the subsequent
targeted Slot-29 compiler diagnostic against the frozen R18 Source. Running C1
first means re-entering the reproduce-diagnose-refreeze loop that costs roughly
a day per finding.

The census answers the same question structurally: which reject classes does
any wanted seed occupy, across the whole finite trigger universe of about 4,130
seeds, on paper rather than one failure at a time. Any occupied class it finds
must be closed before C1 could pass anyway, because the four winners are
members of that same universe.

Resulting order:

1. **Census scans 1 and 2** — interval/attachment/junction and R19 tuple
   occupancy. Scan-1 has a seed-independent prefilter that permanently
   discharges most ordinary edges.
2. **One collected correction** closing every occupied reject class plus U1,
   U2 and O1, followed by **one** compiler reproduction.
3. **Census scans 3 and 4** — terminal/wing/trace, then Face/Whole on the
   flagged, extremal and winner seeds only.
4. **C1 conformance migrated to v3** against the artifacts the pool run
   produced.
5. **`geometry/compiler_impl.lua`** — wire the verified geometry into the
   production compiler.

**Class B runs in parallel throughout.** The relief field `H`, the template
catalog and the one blend operator depend on nothing above; they sit on T1's
green arithmetic primitives.

## 3. Locked surfaces

These six files are covered by the stage-S1 authority digest that pins the
measured 4,096-candidate pool:

```
tools/wp40/t2_s1_authority.lua
mods/MAPGEN/grug_mapgen/wp40/geometry/boundary.lua
mods/MAPGEN/grug_mapgen/wp40/canonical.lua
mods/MAPGEN/grug_mapgen/wp40/deterministic.lua
mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua
mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua
```

Editing any of them invalidates the pool and its four winner seeds, costing a
fresh ~91-minute measurement and a new winner determination. **No work package
may touch them as a side effect.** "I need a new arithmetic primitive" is an
escalation, not a local decision — which matters because Class B builds
directly on `deterministic.lua` and will be tempted.

The v3 winners are candidates 2192, 1713, 1047 and 3438 — the same four the
pre-R16 pool ranked, which is the measured evidence that R16 through R19 really
did change no scalar. They are printed by the merge and recorded in commit
`527b3a5`, but they are not yet a committed artifact row: that row is written
by the C1 conformance step, which is still on v2.

The pool's Source side is pinned by projection, not by file bytes, so
`source/catalog.lua` and `geometry/partition.lua` may change freely; that is
the whole point of the S1 scoping and it is verified by control experiment.

## 4. Measured cost anchors

Use these instead of extrapolating. Every figure below was measured on the
target host; where a ratio is inferred from two of them, it says so.

| operation | cost |
|---|---|
| S1 scalars, one seed | **10.7 s** (4,096 candidates / 91 min / 8 LuaJIT workers) |
| seed-0 compile, LuaJIT, uncached | **32.7 s** |
| seed-0 compile, PUC 5.1, uncached | **868 s** |
| seed-0 + max-u64 + traversal, PUC, uncached | **3,091 s** |
| payload cache hit | **0.37 s** LuaJIT / **1.03 s** PUC |
| full partition gate, PUC, 8-way sharded | **~62 min** wall |
| 4,096-candidate pool, 8 LuaJIT workers | **91 min** wall |
| `run_t1.sh` | 0.18 s |
| `luac51 -p` plus the five grep sweeps, whole owned set | 0.007 s |

PUC-to-LuaJIT ratio is **not** a single number: measured 2.8x on
validation-heavy paths, 16.2x on an exhaustive numeric sweep, and 26.5x on a
full seed-0 compile (868/32.7). Any plan resting on one extrapolated ratio has
been wrong before.

## 5. Open items not owned by a package

- **U1, U2, O1** — the complete undecided set from the completeness analysis;
  U1 is a directly observable contradiction between two policy strings.
- **A targeted `pairs()`-order divergence test**, as the cheap substitute for a
  full PUC gate at every stage freeze. The canonical encoder sorts before
  emission, so serialisation is provably runtime-independent; control flow that
  depends on iteration order is the residual risk and can be tested directly.
- **The invariant review** named in the completeness analysis section 7 — the
  only bound against silent wrongness, the mechanism behind seven of the
  thirteen corrections so far, and behind three defects found on 2026-08-15
  alone: the vacuous ripgrep gate, the payload-cache regression, and a
  verification run that reported success with zero workers started.
