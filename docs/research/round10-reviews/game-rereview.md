# Focused independent GAME re-review

- Reviewed candidate: `d4138bf0c0d7cb0722bd1e9470d74e523a40f3aa`
- Production/test freeze: `7a4a4c4e6bbb848eec1d9eb947d8e3b14f072609`
- Previous candidate: `99a274a32a9173cd11e84da53f8c18ac25d5794c`
- Reviewer: GPT-5.6 Sol, native agent
- Independence: the reviewer did not author GAME; its implementation work was
  the separate EQUIP package.
- Mode: read-only; no candidate edits, personal-world access or PUC rerun.
- Result: **0 Critical / 0 High / 1 Medium / 0 Low.**

## Medium — signed half-boundary permits a two-node descent

`tools/r10_gameplay/cliff_kat.lua:26-52` does not prove the claimed
one-node/two-node boundary. Its `line_of_sight` stub
returns a preselected boolean and blocker and only checks that the Lua caller
passes Y endpoints 9 and 7. It never models which voxel the engine visits or
places support at the one- and two-node depths. Consequently the assertion
labelled `walkable one-node support` would pass with the blocker at any depth,
and `deep all-air drop` is merely the stub's `true` branch.

Pinned engine source also proves this is an actual boundary defect, rather than
only missing evidence. Luanti collision resolves exact floor contact at a
half-node boundary (`reference_projects/luanti/src/collision.cpp:374-389`).
For representative feet Y `0.5`, the ambient probe ends at `-1.5`.
Luanti constructs its
`VoxelLineIterator` from positions divided by `BS`
(`reference_projects/luanti/src/environment.cpp:63-77`) and rounds the start
and end with `floatToInt` (`src/voxelalgorithms.cpp:1243-1249`), whose signed
half-unit rule is in `src/util/numeric.h:345-352`. That rule maps `-1.5` to
voxel `-2`; the inclusive vertical line therefore accepts walkable support two
nodes below the current ground. Concrete trigger: a roaming ground mob whose
feet rest at Y `0.5` approaches a column whose first support is at node Y `-2`;
the current `fear_height = 2` probe reports support and permits the step,
violating the maximum-one-node rule. The bounded fix needs an engine-derived
positive/negative half-boundary oracle, rather than another preselected LoS
boolean.

## Closed previous findings

- **Cliff predicate:** closed. `mods/ENTITIES/mobs/api.lua:1021-1024` now
  returns true for a missing definition or a registered non-walkable blocker.
  The focused fixture covers the predicate branches, danger, missing nodes,
  flight and non-ambient combat exceptions.
- **Fall matrix:** closed. `tools/r6_food_buffs/kat.lua:155-181` now covers
  native zero, fractional ceiling, low/high pools, uncapped lethal severity,
  Dwarf ordering, and confirms armor/dodge accessors are untouched.
- **Mount lifecycle:** closed. `tools/r9_mounts/mounts_kat.lua:450-484` drives
  death, leave, shutdown and external-detach paths twice and verifies one
  status clear and one removal of each controller/visual. The external-detach
  production path now delegates through the shared dismount transaction at
  `mods/PLAYER/grug_mounts/entity.lua:287-299`.

## Evidence verification

The authoritative post-review outputs
`/tmp/grudgelands-r10/game/final/{puc51,luajit}-reviewfix.txt` are byte-identical,
1,134 bytes each, SHA-256
`42dc5b50285b03c8d4228eecd209f2579a92e0539e33a50a005d8d2079074f67`.
The runner SHA-256 is
`fce0e01796b6f0bf120072ce2c2f5caa19a9f7c5f90d65c422ef5d55d8e4adc7`;
the cliff fixture SHA-256 is
`4a2f427609e2dc52f2d09a72c15a915090a3711ce3546e5855374e27d21c8fca`.
The worktree was clean at the reviewed commit. I did not rerun PUC.
