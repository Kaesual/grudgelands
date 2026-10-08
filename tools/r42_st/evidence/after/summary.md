# ST evidence (Round 42 lane ST)

Scenes: `NV0_MOVERS=villager,post_guard tools/r42_nv0/run.sh OUT st scenes` (seed 12345), after the change. Before: the newest evidence of each mover and scene: the post guard in NV2's, the villager in NV3's `evidence/after/scenes.json`, the two door scenes in DR's. Tables: `python3 tools/r42_nv0/summarize.py BEFORE.json tools/r42_st/evidence/after/scenes.json`.

Before: `tools/r42_nv2/evidence/after/scenes.json`

| mover | scene | reached | t goal s | searches | search ms | largest us |
|---|---|---|---|---|---|---|
| post_guard | open | yes / yes | 11.1 / 11.1 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| post_guard | trunk | yes / yes | 18.5 / 13.8 | 1 / 1 | 0.03 / 0.03 | 31 / 33 |
| post_guard | trunk_near | yes / yes | 19.5 / 13.9 | 1 / 1 | 0.02 / 0.02 | 21 / 21 |
| post_guard | row | yes / yes | 13.9 / 13.7 | 1 / 1 | 0.03 / 0.03 | 31 / 25 |
| post_guard | doorway | yes / yes | 21.6 / 17.2 | 1 / 1 | 0.05 / 0.05 | 52 / 48 |
| post_guard | lcorner | yes / yes | 21.5 / 20.0 | 1 / 1 | 0.09 / 0.06 | 85 / 58 |
| post_guard | fence | no / no | - / - | 5 / 6 | 0.63 / 0.77 | 144 / 170 |
| post_guard | fence_low | yes / yes | 12.4 / 12.3 | 1 / 1 | 0.02 / 0.01 | 16 / 10 |
| post_guard | pillar | yes / yes | 14.9 / 14.6 | 1 / 1 | 0.05 / 0.04 | 48 / 42 |
| post_guard | ditch | yes / yes | 18.5 / 16.1 | 1 / 1 | 0.09 / 0.07 | 91 / 74 |
| post_guard | step | yes / yes | 13.3 / 11.1 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| post_guard | lowgap | yes / yes | 43.4 / 39.1 | 6 / 6 | 0.09 / 0.14 | 18 / 58 |
| post_guard | pond | yes / yes | 21.8 / 15.3 | 1 / 1 | 0.14 / 0.15 | 137 / 154 |
| post_guard | door_closed | no / yes | - / 12.8 | 5 / 1 | 0.31 / 0.06 | 64 / 60 |
| post_guard | door_open | yes / yes | 15.5 / 11.1 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |

Before: `tools/r42_nv3/evidence/after/scenes.json`

| mover | scene | reached | t goal s | searches | search ms | largest us |
|---|---|---|---|---|---|---|
| villager | open | yes / yes | 22.2 / 12.4 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| villager | trunk | yes / yes | 18.1 / 14.5 | 1 / 1 | 0.04 / 0.03 | 36 / 30 |
| villager | trunk_near | yes / yes | 21.1 / 15.6 | 1 / 1 | 0.02 / 0.02 | 21 / 24 |
| villager | row | yes / yes | 17.9 / 14.5 | 1 / 1 | 0.02 / 0.02 | 23 / 20 |
| villager | doorway | yes / yes | 21.8 / 18.5 | 1 / 1 | 0.05 / 0.05 | 51 / 48 |
| villager | lcorner | yes / yes | 24.1 / 21.4 | 1 / 1 | 0.08 / 0.07 | 80 / 68 |
| villager | fence | no / no | - / - | 3 / 3 | 0.37 / 0.39 | 139 / 131 |
| villager | fence_low | yes / yes | 16.9 / 13.6 | 1 / 1 | 0.01 / 0.01 | 12 / 7 |
| villager | pillar | yes / yes | 21.6 / 16.8 | 1 / 1 | 0.03 / 0.03 | 33 / 34 |
| villager | ditch | yes / yes | 20.0 / 17.3 | 1 / 1 | 0.1 / 0.1 | 97 / 104 |
| villager | step | yes / yes | 17.8 / 12.4 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| villager | lowgap | no / no | - / - | 3 / 3 | 0.03 / 0.04 | 12 / 18 |
| villager | pond | yes / yes | 20.1 / 16.8 | 1 / 1 | 0.14 / 0.15 | 145 / 146 |
| villager | door_closed | no / yes | - / 13.6 | 3 / 1 | 0.23 / 0.06 | 79 / 61 |
| villager | door_open | yes / yes | 18.9 / 12.4 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |

Before: `tools/r42_dr/evidence/after/scenes.json`

| mover | scene | reached | t goal s | searches | search ms | largest us |
|---|---|---|---|---|---|---|
| post_guard | door_closed | yes / yes | 17.1 / 12.8 | 1 / 1 | 0.09 / 0.06 | 86 / 60 |
| post_guard | door_open | yes / yes | 19.8 / 11.1 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| villager | door_closed | yes / yes | 13.6 / 13.6 | 1 / 1 | 0.07 / 0.06 | 68 / 61 |
| villager | door_open | yes / yes | 14.5 / 12.4 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |

