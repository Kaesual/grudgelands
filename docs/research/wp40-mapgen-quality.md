# WP40 local terrain quality follow-up

Status: implementation in progress on `wp40-mapgen-quality`, 2026-09-13.
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
