# R8-MAP-A fix round 3 cave evidence (2026-09-19)

This directory binds the exact single-lumen audit in commits `c4b07e45` and
`1783bcc4` to the unchanged candidate revision `de5af57f`. It reuses the
candidate files plus native-v7 and cave-writer-disabled snapshots committed in
`../20260919-fix-round-2/`; `inputs.sha256` binds those inputs and the final
checker sources. The normal worlds from that evidence run were read again, so
no map generation or production behavior changed during this measurement.

For each candidate, the checker compares every writer-disabled solid-to-air
change with all complete native-connected lumina. It selects at most one lumen
per candidate. An overlap is excused only when the voxel belongs to a lumen
selected for a different candidate. Partial lumina and two alternatives of one
candidate therefore remain unexpected.

The columns are candidates / carved / connected / native-eligible /
unexpected candidate carves / unexpected voxels.

| seed | region | exact audit |
|---|---|---:|
| 0 | Hearthpine start 1 km | 58 / 9 / 9 / 9 / 0 / 0 |
| 0 | Lethariel capital 1 km | 35 / 0 / 0 / 0 / 0 / 0 |
| 1 | Hearthpine start 1 km | 58 / 8 / 8 / 9 / 1 / 1 |
| 1 | Lethariel capital 1 km | 32 / 2 / 2 / 2 / 0 / 0 |

The seed totals are `93 / 9 / 9 / 9 / 0 / 0` and
`90 / 10 / 10 / 11 / 1 / 1`. Every accepted mouth connects, so
connected/carved is 100%. Against the committed main-before totals of two
seed-0 mouths and one seed-1 mouth, accepted carved density remains 4.5x and
10x.

The expected zero-unexpected result did not hold honestly on seed 1. Candidate
`hearthpine_start_1000/368/354/-1424/30/-2563` changes 116 writer-baseline
solid voxels. Its closest complete connected lumen accounts for 115; voxel
`-1422/30/-2563` belongs only to another alternative of the same candidate.
The candidate is therefore not counted as carved, the extra voxel is reported,
and the checker's hard zero assertion deliberately makes that launch exit 1.
Seed 0 exits 0. This is evidence-tooling only; the round explicitly forbade a
production behavior change.

## Exact commands

The final checker re-read the two retained normal worlds in parallel:

```sh
KEEP=1 ROOT=/tmp/grudgelands-headless.SkVIQS PORT=31075 SEED=0 PROBE=/tmp/r8-map-a-round2-evidence/probe-seed0-after nice -n 19 bash tools/luanti_headless.sh 1800
KEEP=1 ROOT=/tmp/grudgelands-headless.dGxA6M PORT=31076 SEED=1 PROBE=/tmp/r8-map-a-round2-evidence/probe-seed1-after nice -n 19 bash tools/luanti_headless.sh 1800
```

Before launch, each probe received the final committed
`engine_probe/{init,volume}.lua`; its cases and two baseline snapshots remained
byte-identical to fix round 2. `seed-0-after.server.log` contains no `ERROR`.
`seed-1-after.server.log` contains the intentional
`R8-MAP-A unexpected cave carve detected` assertion after writing all counts.

The portable lane KAT is byte-identical under LuaJIT and PUC 5.1 with SHA-256
`efb8a71b19dcd66b9e176c4b85c707565be1a33b89bddc5434f4564c05282e24`.
`mutations.log` records rejection of all nine mutations, including the new
partial-lumen and dual-alternative cases.
