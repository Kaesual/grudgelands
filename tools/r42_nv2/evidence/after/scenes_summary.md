# NV0 probe summary (nv0_results.json)

Seed 12345, settings {"dedicated_server_step": "0.09", "mob_pathfinding_searchdistance": "24", "mob_pathfinding_stuck_path_timeout": "3.0", "mob_pathfinding_stuck_timeout": "2.0"}, A* budget 3000 us/step.

## Movers

| mover | entity | kind | width | height | walk | run | step | fear | floats | tier | trial s |
|---|---|---|---|---|---|---|---|---|---|---|---|
| post_guard | grug_mobs:guard_accord | post | 0.6 | 1.7 | 1.2 | 4.6 | 1.1 | 4 | yes | normal | 45 |
| royal_guard | grug_mobs:royal_guard_human | follow | 0.8 | 1.9 | 1.2 | 4.6 | 1.1 | 4 | yes | elite | 30 |

## Scenes per mover (today's code)

### post_guard

| scene | reached | t goal s | min dist | searches | found | search ms | largest us | stuck triggers / events |
|---|---|---|---|---|---|---|---|---|
| open | yes | 11.1 | 1.0 | 0 | 0 | 0.0 | 0 | none |
| trunk | yes | 18.5 | 0.7 | 1 | 1 | 0.0 | 31 | nav_found 1, nav_stuck 1 |
| trunk_near | yes | 19.5 | 1.3 | 1 | 1 | 0.0 | 23 | nav_found 1, nav_stuck 1 |
| row | yes | 13.9 | 0.8 | 1 | 1 | 0.1 | 68 | nav_found 1, nav_stuck 1 |
| doorway | yes | 21.7 | 1.7 | 1 | 1 | 0.1 | 52 | nav_found 1, nav_stuck 1 |
| lcorner | yes | 21.5 | 0.8 | 1 | 1 | 0.1 | 71 | nav_found 1, nav_stuck 1 |
| fence | no | - | 4.4 | 5 | 0 | 0.7 | 161 | nav_no_path 5, nav_stuck 2 |
| fence_low | yes | 12.4 | 1.2 | 1 | 1 | 0.0 | 17 | nav_found 1, nav_stuck 1 |
| pillar | yes | 14.8 | 1.0 | 1 | 1 | 0.0 | 45 | nav_found 1, nav_stuck 1 |
| ditch | yes | 18.5 | 0.7 | 1 | 1 | 0.1 | 77 | nav_found 1, nav_stuck 1 |
| step | yes | 13.2 | 0.9 | 0 | 0 | 0.0 | 0 | none |
| lowgap | snap | 43.4 | 0 | 6 | 6 | 0.1 | 22 | nav_rejected 6, nav_stuck 1, snap 1, teleport 1 |
| pond | yes | 23.4 | 1.4 | 1 | 0 | 0.1 | 143 | nav_no_path 1, nav_stuck 1 |
| door_closed | no | - | 7.8 | 5 | 0 | 0.4 | 84 | nav_no_path 5, nav_stuck 1 |
| door_open | yes | 15.5 | 1.0 | 0 | 0 | 0.0 | 0 | none |

### royal_guard

| scene | reached | t goal s | min dist | searches | found | search ms | largest us | stuck triggers / events |
|---|---|---|---|---|---|---|---|---|
| open | yes | 8.6 | 0.1 | 0 | 0 | 0.0 | 0 | none |
| trunk | yes | 11.9 | 0.8 | 1 | 1 | 0.0 | 33 | nav_found 1, nav_stuck 1 |
| trunk_near | yes | 8.6 | 0.0 | 0 | 0 | 0.0 | 0 | none |
| row | yes | 11.9 | 0.0 | 1 | 1 | 0.0 | 21 | nav_found 1, nav_stuck 1 |
| doorway | yes | 15.6 | 0.3 | 2 | 2 | 0.1 | 48 | nav_found 2, nav_leave_stuck 1, nav_stuck 1 |
| lcorner | yes | 18.4 | 0.9 | 1 | 1 | 0.1 | 56 | nav_found 1, nav_stuck 1 |
| fence | yes | 8.6 | 4.9 | 0 | 0 | 0.0 | 0 | none |
| fence_low | yes | 8.6 | 4.9 | 0 | 0 | 0.0 | 0 | none |
| pillar | yes | 12.8 | 1.3 | 1 | 1 | 0.0 | 43 | nav_found 1, nav_stuck 1 |
| ditch | yes | 14.3 | 1.4 | 1 | 1 | 0.1 | 55 | nav_found 1, nav_stuck 1 |
| step | yes | 8.6 | 0.2 | 0 | 0 | 0.0 | 0 | none |
| lowgap | snap | 27.6 | 0 | 4 | 4 | 0.1 | 28 | nav_rejected 4, nav_stuck 1, teleport 1 |
| pond | yes | 10.9 | 0.6 | 0 | 0 | 0.0 | 0 | none |
| door_closed | snap | 27.6 | 0 | 4 | 0 | 0.3 | 68 | nav_no_path 4, nav_stuck 1, teleport 1 |
| door_open | snap | 27.6 | 0 | 4 | 0 | 0.2 | 50 | nav_no_path 4, nav_stuck 1, teleport 1 |

## Batches (all lanes of one mover at once; wall-clock us, noisy)

| mover | steps | mob step us p50 | p99 | max | find_path calls | find_path ms | largest step fp us |
|---|---|---|---|---|---|---|---|
| post_guard | 498 | 79 | 637 | 1238 | 25 | 1.7 | 243 |
| royal_guard | 332 | 81 | 787 | 3058 | 19 | 0.8 | 275 |

## Self-movement ratio (moved / commanded speed x window)

Windows end at every server step; only windows in which the mob wanted to move the whole time, outside its reach or arrival radius and before reaching the goal. free = no horizontal node collision in the window or the second before it; contact = a collision in the window; after contact = none in the window but one in the second before (a walker resting against an obstacle between its 1 Hz nudges). The open scene is the clean free-walking sample.

| kind | speed | window s | free n | free p1 | free p5 | free p50 | open n | open p1 | contact n | contact p50 | contact p90 | after n | after p50 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| walk | walk 1.2 | 0.5 | 2506 | 0.5 | 0.8 | 1.0 | 184 | 0.8 | 1853 | 0.0 | 0.4 | 243 | 1.0 |
| walk | walk 1.2 | 1.0 | 2085 | 0.5 | 0.7 | 1.0 | 173 | 0.9 | 1759 | 0.0 | 0.6 | 176 | 1.0 |

Flagged windows per threshold (free and open scene: false alarms; contact and after contact: detections):

| kind | speed | window s | threshold | free flagged | open-scene flagged | contact flagged | after-contact flagged |
|---|---|---|---|---|---|---|---|
| walk | walk 1.2 | 0.5 | 0.2 | 0/2506 | 0/184 | 1601/1853 | 54/243 |
| walk | walk 1.2 | 0.5 | 0.3 | 0/2506 | 0/184 | 1622/1853 | 54/243 |
| walk | walk 1.2 | 0.5 | 0.4 | 0/2506 | 0/184 | 1667/1853 | 60/243 |
| walk | walk 1.2 | 0.5 | 0.5 | 43/2506 | 0/184 | 1691/1853 | 60/243 |
| walk | walk 1.2 | 1.0 | 0.2 | 0/2085 | 0/173 | 1368/1759 | 17/176 |
| walk | walk 1.2 | 1.0 | 0.3 | 0/2085 | 0/173 | 1418/1759 | 23/176 |
| walk | walk 1.2 | 1.0 | 0.4 | 0/2085 | 0/173 | 1452/1759 | 29/176 |
| walk | walk 1.2 | 1.0 | 0.5 | 28/2085 | 0/173 | 1492/1759 | 38/176 |

Per trial: first horizontal collision, first window under 0.3 (0.5 s in combat, 1 s otherwise) and the time spent under it:

| mover | scene | reached | first collision s | first flag s | flagged s |
|---|---|---|---|---|---|
| post_guard | trunk | yes | 10.7 | 11.3 | 1.0 |
| post_guard | trunk_near | yes | 14.8 | 17.2 | 2.5 |
| post_guard | row | yes | 6.3 | 7.0 | 1.0 |
| post_guard | doorway | yes | 10.7 | 11.3 | 1.0 |
| post_guard | lcorner | yes | 6.3 | 8.5 | 2.5 |
| post_guard | fence | no | 15.8 | 19.4 | 26.0 |
| post_guard | fence_low | yes | - | - | 0.0 |
| post_guard | pillar | yes | 5.4 | 6.2 | 0.7 |
| post_guard | ditch | yes | - | - | 0.0 |
| post_guard | step | yes | - | - | 0.0 |
| post_guard | lowgap | yes | 10.7 | 11.3 | 32.0 |
| post_guard | pond | yes | - | - | 0.0 |
| post_guard | door_closed | no | 13.9 | 14.6 | 30.5 |
| post_guard | door_open | yes | - | - | 0.0 |
| royal_guard | trunk | yes | 6.2 | 7.0 | 1.6 |
| royal_guard | trunk_near | yes | 10.4 | - | 0.0 |
| royal_guard | row | yes | 6.2 | 7.0 | 1.6 |
| royal_guard | doorway | yes | 6.2 | 7.0 | 1.7 |
| royal_guard | lcorner | yes | 6.2 | 7.0 | 1.7 |
| royal_guard | fence | yes | - | - | 0.0 |
| royal_guard | fence_low | yes | - | - | 0.0 |
| royal_guard | pillar | yes | 5.3 | 6.1 | 1.4 |
| royal_guard | ditch | yes | 7.0 | 7.7 | 1.3 |
| royal_guard | step | yes | - | - | 0.0 |
| royal_guard | lowgap | yes | 6.2 | 7.0 | 20.6 |
| royal_guard | pond | yes | - | - | 0.0 |
| royal_guard | door_closed | yes | 6.2 | 7.0 | 20.6 |
| royal_guard | door_open | yes | 6.2 | 7.0 | 20.6 |

Before: tools/r42_nv1/evidence/after/scenes.json (NV1's after run, the base of NV2); after: this run. Columns read before / after.

## Before / after

| mover | scene | reached | t goal s | searches | search ms | largest us |
|---|---|---|---|---|---|---|
| post_guard | open | yes / yes | 14.4 / 11.1 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| post_guard | trunk | yes / yes | 36.6 / 18.5 | 2 / 1 | 0.07 / 0.03 | 40 / 31 |
| post_guard | trunk_near | yes / yes | 43.5 / 19.5 | 4 / 1 | 0.08 / 0.02 | 24 / 23 |
| post_guard | row | yes / yes | 38.6 / 13.9 | 4 / 1 | 0.11 / 0.07 | 36 / 68 |
| post_guard | doorway | yes / yes | 44.1 / 21.7 | 8 / 1 | 0.38 / 0.05 | 62 / 52 |
| post_guard | lcorner | no / yes | - / 21.5 | 9 / 1 | 0.49 / 0.07 | 100 / 71 |
| post_guard | fence | no / no | - / - | 4 / 5 | 2.12 / 0.68 | 595 / 161 |
| post_guard | fence_low | no / yes | - / 12.4 | 9 / 1 | 0.12 / 0.02 | 19 / 17 |
| post_guard | pillar | no / yes | - / 14.8 | 7 / 1 | 0.23 / 0.04 | 48 / 45 |
| post_guard | ditch | no / yes | - / 18.5 | 13 / 1 | 1.09 / 0.08 | 110 / 77 |
| post_guard | step | yes / yes | 13.3 / 13.2 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| post_guard | lowgap | no / yes | - / 43.4 | 14 / 6 | 0.14 / 0.1 | 15 / 22 |
| post_guard | pond | no / yes | - / 23.4 | 11 / 1 | 1.36 / 0.14 | 220 / 143 |
| post_guard | door_closed | no / no | - / - | 4 / 5 | 0.95 / 0.36 | 241 / 84 |
| post_guard | door_open | yes / yes | 20.9 / 15.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | open | yes / yes | 8.7 / 8.6 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | trunk | yes / yes | 28.2 / 11.9 | 1 / 1 | 0.03 / 0.03 | 33 / 33 |
| royal_guard | trunk_near | yes / yes | 8.7 / 8.6 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | row | yes / yes | 28.2 / 11.9 | 1 / 1 | 0.02 / 0.02 | 23 / 21 |
| royal_guard | doorway | yes / yes | 28.2 / 15.6 | 1 / 2 | 0.05 / 0.08 | 54 / 48 |
| royal_guard | lcorner | yes / yes | 28.2 / 18.4 | 1 / 1 | 0.07 / 0.06 | 72 / 56 |
| royal_guard | fence | yes / yes | 8.7 / 8.6 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | fence_low | yes / yes | 8.7 / 8.6 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | pillar | yes / yes | 27.1 / 12.8 | 1 / 1 | 0.05 / 0.04 | 47 / 43 |
| royal_guard | ditch | no / yes | - / 14.3 | 0 / 1 | 0.0 / 0.06 | 0 / 55 |
| royal_guard | step | yes / yes | 8.6 / 8.6 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | lowgap | yes / yes | 28.2 / 27.6 | 1 / 4 | 0.01 / 0.06 | 10 / 28 |
| royal_guard | pond | yes / yes | 13.0 / 10.9 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | door_closed | yes / yes | 27.1 / 27.6 | 1 / 4 | 0.25 / 0.26 | 254 / 68 |
| royal_guard | door_open | yes / yes | 27.1 / 27.6 | 1 / 4 | 0.24 / 0.2 | 236 / 50 |
