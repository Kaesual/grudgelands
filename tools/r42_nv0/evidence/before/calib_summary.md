# NV0 probe summary (nv0_results.json)

Seed 12345, settings {"dedicated_server_step": "0.09", "mob_pathfinding_searchdistance": "24", "mob_pathfinding_stuck_path_timeout": "3.0", "mob_pathfinding_stuck_timeout": "2.0"}, A* budget 3000 us/step.

## find_path on the flat field (median of 5, us)

| d | pad | box cells | found | found max | diagonal | no path | no path max | found ok | no path ok |
|---|---|---|---|---|---|---|---|---|---|
| 8 | 2 | 65 | 5 | 13 | 21 | 15 | 30 | yes | yes |
| 8 | 4 | 153 | 5 | 7 | 24 | 66 | 88 | yes | yes |
| 8 | 6 | 273 | 5 | 7 | 25 | 157 | 159 | yes | yes |
| 8 | 8 | 425 | 6 | 8 | 20 | 351 | 357 | yes | yes |
| 8 | 12 | 825 | 4 | 8 | 19 | 639 | 660 | yes | yes |
| 8 | 16 | 1353 | 5 | 8 | 20 | 1127 | 1156 | yes | yes |
| 8 | 24 | 2793 | 4 | 10 | 19 | 2622 | 2638 | yes | yes |
| 12 | 2 | 85 | 8 | 12 | 30 | 19 | 33 | yes | yes |
| 12 | 4 | 189 | 7 | 10 | 31 | 86 | 109 | yes | yes |
| 12 | 6 | 325 | 7 | 15 | 29 | 200 | 210 | yes | yes |
| 12 | 8 | 493 | 7 | 12 | 32 | 321 | 331 | yes | yes |
| 12 | 12 | 925 | 6 | 11 | 29 | 715 | 758 | yes | yes |
| 12 | 16 | 1485 | 7 | 12 | 28 | 1270 | 1332 | yes | yes |
| 12 | 24 | 2989 | 7 | 13 | 29 | 2813 | 2855 | yes | yes |
| 16 | 2 | 105 | 10 | 17 | 49 | 24 | 38 | yes | yes |
| 16 | 4 | 225 | 9 | 15 | 48 | 124 | 135 | yes | yes |
| 16 | 6 | 377 | 10 | 14 | 48 | 232 | 244 | yes | yes |
| 16 | 8 | 561 | 10 | 16 | 50 | 380 | 390 | yes | yes |
| 16 | 12 | 1025 | 10 | 16 | 65 | 880 | 959 | yes | yes |
| 16 | 16 | 1617 | 9 | 17 | 72 | 1481 | 1597 | yes | yes |
| 16 | 24 | 3185 | 10 | 18 | 51 | 3043 | 3144 | yes | yes |
| 24 | 2 | 145 | 15 | 28 | 104 | 37 | 57 | yes | yes |
| 24 | 4 | 297 | 15 | 24 | 103 | 174 | 190 | yes | yes |
| 24 | 6 | 481 | 14 | 24 | 107 | 332 | 365 | yes | yes |
| 24 | 8 | 697 | 15 | 25 | 124 | 543 | 562 | yes | yes |
| 24 | 12 | 1225 | 16 | 27 | 114 | 1288 | 1338 | yes | yes |
| 24 | 16 | 1881 | 15 | 27 | 109 | 1651 | 1703 | yes | yes |
| 24 | 24 | 3577 | 15 | 26 | 123 | 3537 | 3852 | yes | yes |
| 32 | 2 | 185 | 22 | 35 | 166 | 54 | 76 | yes | yes |
| 32 | 4 | 369 | 21 | 33 | 183 | 284 | 294 | yes | yes |
| 32 | 6 | 585 | 22 | 374 | 170 | 422 | 458 | yes | yes |
| 32 | 8 | 833 | 22 | 35 | 173 | 650 | 742 | yes | yes |
| 32 | 12 | 1425 | 21 | 34 | 171 | 1296 | 1788 | yes | yes |
| 32 | 16 | 2145 | 23 | 35 | 205 | 2000 | 2406 | yes | yes |
| 32 | 24 | 3969 | 26 | 37 | 166 | 4200 | 4808 | yes | yes |

## Scenes: smallest padding, path checks, fan radius

From the start (0,0) or the blocked cell to the goal; head2/head3 = waypoints without head room for a 2/3-node mob, wide = waypoints a mob wider than one node scrapes; fan r = smallest radius of a candidate (toward the goal, height band 2, path at padding 4) with a walkable line on to the goal (narrow: half width 0.3, wide: 0.7).

| scene | from | line clear | min pad | len | head2 | head3 | wide | pad4 us | pad4 found | pad24 us | fan r narrow | fan r wide |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| open | start | yes | 2 | 15 | 0 | 0 | 0 | 9 | yes | 8 | 2 | 2 |
| open | blocked | yes | 2 | 15 | 0 | 0 | 0 | 8 | yes | 12 | 2 | 2 |
| trunk | start | no | 2 | 17 | 0 | 0 | 2 | 19 | yes | 16 | 2 | 3 |
| trunk | blocked | no | 2 | 11 | 0 | 0 | 2 | 9 | yes | 9 | 2 | 2 |
| trunk_near | start | no | 2 | 17 | 0 | 0 | 2 | 17 | yes | 14 | 6 | 10 |
| trunk_near | blocked | no | 2 | 6 | 0 | 0 | 2 | 5 | yes | 5 | 2 | 2 |
| row | start | no | 2 | 17 | 0 | 0 | 2 | 15 | yes | 14 | 2 | 8 |
| row | blocked | no | 2 | 11 | 0 | 0 | 2 | 10 | yes | 10 | 2 | 2 |
| doorway | start | no | 6 | 23 | 0 | 1 | 5 | 42 | no | 51 | 8 | 10 |
| doorway | blocked | no | 6 | 17 | 0 | 1 | 5 | 17 | no | 21 | 2 | 2 |
| lcorner | start | no | 4 | 21 | 0 | 0 | 6 | 45 | yes | 31 | 6 | 8 |
| lcorner | blocked | no | 4 | 23 | 0 | 0 | 8 | 33 | yes | 30 | 2 | 2 |
| fence | start | no | - | - | - | - | - | 55 | no | 453 | - | - |
| fence | blocked | no | - | - | - | - | - | 19 | no | 444 | - | - |
| fence_low | start | yes | 2 | 15 | 0 | 0 | 0 | 12 | yes | 12 | 2 | 2 |
| fence_low | blocked | yes | 2 | 6 | 0 | 0 | 0 | 4 | yes | 4 | 2 | 2 |
| pillar | start | no | 2 | 19 | 0 | 0 | 5 | 32 | yes | 27 | 5 | 6 |
| pillar | blocked | no | 2 | 14 | 0 | 0 | 5 | 15 | yes | 15 | 3 | 3 |
| ditch | start | no | 6 | 23 | 0 | 0 | 4 | 57 | no | 71 | 10 | 10 |
| ditch | blocked | no | 6 | 17 | 0 | 0 | 4 | 8 | no | 20 | 2 | 2 |
| step | start | yes | 2 | 15 | 0 | 0 | 0 | 8 | yes | 14 | 2 | 2 |
| step | blocked | yes | 2 | 9 | 0 | 0 | 0 | 4 | yes | 4 | 2 | 2 |
| lowgap | start | no | 2 | 15 | 1 | 1 | 1 | 8 | yes | 7 | 8 | 8 |
| lowgap | blocked | no | 2 | 9 | 1 | 1 | 1 | 4 | yes | 4 | 2 | 2 |
| pond | start | no | 8 | 29 | 0 | 0 | 0 | 68 | no | 191 | - | - |
| pond | blocked | no | 8 | 26 | 0 | 0 | 0 | 48 | no | 103 | 10 | 10 |
| door_closed | start | no | - | - | - | - | - | 44 | no | 167 | - | - |
| door_closed | blocked | no | - | - | - | - | - | 16 | no | 202 | - | - |
| door_open | start | no | - | - | - | - | - | 39 | no | 165 | - | - |
| door_open | blocked | no | - | - | - | - | - | 21 | no | 175 | - | - |

## Natural terrain: found paths against distance

| d | targets | found pad4 | found pad24 | line walkable | pad4 found us p50 | max | pad4 fail us p50 | max | pad24 found us p50 | pad24 fail max | len/d p50 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 8 | 32 | 32 | 32 | 18 | 28 | 66 | - | - | 17 | - | 1.4 |
| 12 | 32 | 32 | 32 | 18 | 41 | 127 | - | - | 27 | - | 1.2 |
| 16 | 30 | 30 | 30 | 15 | 73 | 239 | - | - | 56 | - | 1.2 |
| 24 | 27 | 27 | 27 | 13 | 189 | 403 | - | - | 168 | - | 1.1 |
| 32 | 23 | 22 | 23 | 11 | 162 | 680 | 135 | 135 | 223 | - | 1.1 |

## Natural terrain: candidate fan (5 candidates at 0, +-20, +-40 deg per direction)

| ring r | band +- | directions | standable | path pad4 | path us p50 | path us max | check us p50 |
|---|---|---|---|---|---|---|---|
| 4 | 1 | 32 | 32 | 32 | 7 | 14 | 1 |
| 4 | 2 | 32 | 32 | 32 | 6 | 12 | 1 |
| 4 | 3 | 32 | 32 | 32 | 5 | 10 | 1 |
| 6 | 1 | 32 | 29 | 29 | 10 | 19 | 1 |
| 6 | 2 | 32 | 32 | 32 | 9 | 23 | 1 |
| 6 | 3 | 32 | 32 | 32 | 10 | 42 | 1 |
| 10 | 1 | 32 | 27 | 27 | 20 | 49 | 2 |
| 10 | 2 | 32 | 29 | 29 | 28 | 56 | 1 |
| 10 | 3 | 32 | 31 | 31 | 30 | 62 | 1 |
| 16 | 1 | 32 | 22 | 22 | 30 | 129 | 2 |
| 16 | 2 | 32 | 26 | 26 | 62 | 124 | 2 |
| 16 | 3 | 32 | 29 | 28 | 67 | 287 | 2 |

## Walkable-line prototype cost

| d | us per test | clear |
|---|---|---|
| 8 | 18.1 | yes |
| 16 | 35.5 | yes |
| 32 | 353.7 | yes |

## 40 blocked chasers (20 s)

| metric | value |
|---|---|
| budget_refused | 0 |
| chasers | 40 |
| cpu_s | 20.4 |
| fp_calls | 96 |
| fp_found | 0 |
| fp_max_us | 357 |
| fp_mean_us | 261.2 |
| fp_ms_per_s | 1.2 |
| fp_per_s | 4.8 |
| fp_step_us_max | 1673 |
| fp_step_us_p99 | 1232 |
| give_ups | 40 |
| mob_step_us_max | 4927 |
| mob_step_us_p50 | 542 |
| mob_step_us_p90 | 2397 |
| mob_step_us_p99 | 4393 |
| seconds | 20.0 |
| steps | 221 |
| smart_mobs | close_attempted 96, close_backoff 1117, close_give_up 40 |
