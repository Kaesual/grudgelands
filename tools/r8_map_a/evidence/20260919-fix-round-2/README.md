# R8-MAP-A fix round 2 cave evidence (2026-09-19)

This directory binds the final cave audit to candidate revision `de5af57f`,
the complete-owner proof in `54c213dc`, the split native/writer baselines in
`8f2e9577`, and the observed-lumen proof in `8eed9296`. The candidates are
unchanged from fix round 1. The two native snapshots prove cave continuation;
the two cave-writer-disabled snapshots isolate writer changes from all other
authored terrain operations. The normal-world checker compares every
structurally valid lumen of every candidate and fails unless both
`unexpected_carves` and `unexpected_voxels` are zero.

The columns are candidates / carved / connected / native-eligible /
unexpected candidate carves / unexpected voxels.

| seed | region | final branch |
|---|---|---:|
| 0 | Hearthpine start 1 km | 58 / 9 / 9 / 9 / 0 / 0 |
| 0 | Lethariel capital 1 km | 35 / 0 / 0 / 0 / 0 / 0 |
| 1 | Hearthpine start 1 km | 58 / 8 / 8 / 9 / 0 / 0 |
| 1 | Lethariel capital 1 km | 32 / 2 / 2 / 2 / 0 / 0 |

The seed totals are therefore `93 / 9 / 9 / 9 / 0 / 0` and
`90 / 10 / 10 / 11 / 0 / 0`. Connected/carved remains 100%. Against the
committed main-before totals of two seed-0 mouths and one seed-1 mouth, carved
density is 4.5x and 10x. One seed-1 native-eligible candidate is not counted as
carved because the full writer-disabled comparison does not prove its exact
transaction; the evidence reports the lower honest number.

All 20 fix-round-1 native-positive targets are at least 15 nodes from every
owner boundary (the minimum is seed 1 target `-2257/-2/-2707`). Thus the new
complete target ±12 requirement invalidates none of those native proofs and an
engine regeneration was not needed for that rule alone. The normal worlds were
nevertheless regenerated because the new full-volume writer comparison is a
different measurement.

## Exact commands

The candidate files are the unchanged output of:

```sh
chrt --idle 0 ionice -c3 luajit tools/r8_map_a/candidate_export.lua "$PWD" 0 de5af57f > seed-0-cases.lua
chrt --idle 0 ionice -c3 luajit tools/r8_map_a/candidate_export.lua "$PWD" 1 de5af57f > seed-1-cases.lua
```

The native-v7 snapshots re-read the retained writer-disabled worlds from fix
round 1 with the final v3 checker:

```sh
KEEP=1 ROOT=/tmp/grudgelands-headless.AKo5Cr PORT=31073 SEED=0 R8_NATIVE_BASELINE=1 PROBE=/tmp/r8-map-a-round2-evidence/probe-seed0-baseline nice -n 19 bash tools/luanti_headless.sh 1800
KEEP=1 ROOT=/tmp/grudgelands-headless.fStkXJ PORT=31074 SEED=1 R8_NATIVE_BASELINE=1 PROBE=/tmp/r8-map-a-round2-evidence/probe-seed1-baseline nice -n 19 bash tools/luanti_headless.sh 1800
```

The cave-writer-disabled comparison worlds were fresh:

```sh
KEEP=1 PORT=31066 SEED=0 R8_CAVE_WRITER_DISABLED=1 PROBE=/tmp/r8-map-a-round2-evidence/probe-seed0-writer-baseline nice -n 19 bash tools/luanti_headless.sh 1800
KEEP=1 PORT=31067 SEED=1 R8_CAVE_WRITER_DISABLED=1 PROBE=/tmp/r8-map-a-round2-evidence/probe-seed1-writer-baseline nice -n 19 bash tools/luanti_headless.sh 1800
```

Fresh normal worlds were generated on ports 31071 and 31072. After the final
native-alternative checker bytes were frozen, those same worlds were re-read
without regeneration by these exact evidence commands:

```sh
KEEP=1 ROOT=/tmp/grudgelands-headless.SkVIQS PORT=31075 SEED=0 PROBE=/tmp/r8-map-a-round2-evidence/probe-seed0-after nice -n 19 bash tools/luanti_headless.sh 1800
KEEP=1 ROOT=/tmp/grudgelands-headless.dGxA6M PORT=31076 SEED=1 PROBE=/tmp/r8-map-a-round2-evidence/probe-seed1-after nice -n 19 bash tools/luanti_headless.sh 1800
```

Each committed final server log has zero `ERROR` lines. `SHA256SUMS` binds the
candidate inputs, both baseline layers, final normal logs, launch receipts and
portable KAT/mutation receipts.
