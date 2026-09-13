# WP40 resource-root ranking differential

The compact fixture runs the ordinary full-sort and runtime resource-settlement
paths from the same plan and deep VoxelManip population. It requires identical
content, param2, light and VoxelManip setter/liquid traces, as well as identical
canonical hash inputs. Its cases cover zero, one and 4096 eligible hosts, a
zero budget, equal root digests at negative coordinates, ordinary multi-node
veins, roots consumed by their own frontier, foreign collisions, an exhausted
root population, a short frontier, an inactive resource tier and a completely
disallowed region. It reuses each writer with changed predecessor content to
check that eligibility does not leak between transactions.

`run.sh` defaults to the compact, plain-Lua-5.1-compatible fixture used by the
final interpreter comparison. `run.sh expanded` adds a larger connected host
population and a 2048-host zero-budget group, and is a LuaJIT development
check.

`primitives.lua` compares exact full/prepared hash input bytes across all hash
domains, canonical boundary values, invalid inputs, prefix mutation/interleaving,
and cache saturation. It loads the private heap/sort functions directly from
production source for ordering, tie and scratch-permutation checks; the live
settlement and engine comparisons independently cover their integration.

Run `check_static.sh` for changed-file parser, SETGLOBAL and five source sweeps.
For final frozen bytes only, `final_micro.sh /tmp/ABSENT_RESULT_DIR` runs exactly
one compact PUC process and the same fixture once under LuaJIT, comparing their
complete output. It combines the tree witness, hash/heap primitives and compact
resource differential. Development continues to use LuaJIT; do not routinely
repeat this final-only interpreter pair.
