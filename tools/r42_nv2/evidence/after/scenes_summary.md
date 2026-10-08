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
| trunk | yes | 18.5 | 1.2 | 1 | 1 | 0.0 | 31 | nav_found 1, nav_stuck 1 |
| trunk_near | yes | 19.5 | 1.3 | 1 | 1 | 0.0 | 21 | nav_found 1, nav_stuck 1 |
| row | yes | 13.9 | 0.8 | 1 | 1 | 0.0 | 31 | nav_found 1, nav_stuck 1 |
| doorway | yes | 21.6 | 1.6 | 1 | 1 | 0.1 | 52 | nav_found 1, nav_stuck 1 |
| lcorner | yes | 21.5 | 0.8 | 1 | 1 | 0.1 | 85 | nav_found 1, nav_stuck 1 |
| fence | no | - | 4.4 | 5 | 0 | 0.6 | 144 | nav_no_path 5, nav_stuck 2 |
| fence_low | yes | 12.4 | 1.2 | 1 | 1 | 0.0 | 16 | nav_found 1, nav_stuck 1 |
| pillar | yes | 14.9 | 1.1 | 1 | 1 | 0.1 | 48 | nav_found 1, nav_stuck 1 |
| ditch | yes | 18.5 | 1.5 | 1 | 1 | 0.1 | 91 | nav_found 1, nav_stuck 1 |
| step | yes | 13.3 | 0.9 | 0 | 0 | 0.0 | 0 | none |
| lowgap | snap | 43.4 | 0 | 6 | 6 | 0.1 | 18 | nav_rejected 6, nav_stuck 1, snap 1, teleport 1 |
| pond | yes | 21.8 | 0.8 | 1 | 0 | 0.1 | 137 | nav_no_path 1, nav_stuck 1 |
| door_closed | no | - | 7.8 | 5 | 0 | 0.3 | 64 | nav_no_path 5, nav_stuck 1 |
| door_open | yes | 15.5 | 1.0 | 0 | 0 | 0.0 | 0 | none |

### royal_guard

| scene | reached | t goal s | min dist | searches | found | search ms | largest us | stuck triggers / events |
|---|---|---|---|---|---|---|---|---|
| open | yes | 8.6 | 0.1 | 0 | 0 | 0.0 | 0 | none |
| trunk | yes | 11.9 | 1.7 | 1 | 1 | 0.0 | 31 | nav_found 1, nav_stuck 1 |
| trunk_near | yes | 8.6 | 1.1 | 0 | 0 | 0.0 | 0 | none |
| row | yes | 11.9 | 0.7 | 1 | 1 | 0.0 | 23 | nav_found 1, nav_stuck 1 |
| doorway | yes | 15.5 | 0.4 | 2 | 2 | 0.1 | 61 | nav_found 2, nav_leave_stuck 1, nav_stuck 1 |
| lcorner | yes | 18.4 | 0.5 | 1 | 1 | 0.1 | 64 | nav_found 1, nav_stuck 1 |
| fence | yes | 8.6 | 4.9 | 0 | 0 | 0.0 | 0 | none |
| fence_low | yes | 8.6 | 4.9 | 0 | 0 | 0.0 | 0 | none |
| pillar | yes | 12.7 | 1.8 | 1 | 1 | 0.0 | 45 | nav_found 1, nav_stuck 1 |
| ditch | yes | 14.3 | 1.1 | 1 | 1 | 0.1 | 51 | nav_found 1, nav_stuck 1 |
| step | yes | 8.6 | 2.9 | 0 | 0 | 0.0 | 0 | none |
| lowgap | snap | 27.6 | 0 | 4 | 4 | 0.1 | 17 | nav_rejected 4, nav_stuck 1, teleport 1 |
| pond | yes | 11.0 | 0.0 | 0 | 0 | 0.0 | 0 | none |
| door_closed | snap | 27.6 | 0 | 4 | 0 | 0.3 | 68 | nav_no_path 4, nav_stuck 1, teleport 1 |
| door_open | snap | 27.6 | 0 | 4 | 0 | 0.2 | 51 | nav_no_path 4, nav_stuck 1, teleport 1 |

## Batches (all lanes of one mover at once; wall-clock us, noisy)

| mover | steps | mob step us p50 | p99 | max | find_path calls | find_path ms | largest step fp us |
|---|---|---|---|---|---|---|---|
| post_guard | 498 | 66 | 567 | 944 | 25 | 1.5 | 204 |
| royal_guard | 333 | 54 | 455 | 771 | 19 | 0.8 | 296 |

## Self-movement ratio (moved / commanded speed x window)

Windows end at every server step; only windows in which the mob wanted to move the whole time, outside its reach or arrival radius and before reaching the goal. free = no horizontal node collision in the window or the second before it; contact = a collision in the window; after contact = none in the window but one in the second before (a walker resting against an obstacle between its 1 Hz nudges). The open scene is the clean free-walking sample.

| kind | speed | window s | free n | free p1 | free p5 | free p50 | open n | open p1 | contact n | contact p50 | contact p90 | after n | after p50 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| walk | walk 1.2 | 0.5 | 2504 | 0.5 | 0.8 | 1.0 | 184 | 0.8 | 1788 | 0.0 | 0.4 | 244 | 1.0 |
| walk | walk 1.2 | 1.0 | 2079 | 0.5 | 0.7 | 1.0 | 173 | 0.9 | 1638 | 0.0 | 0.6 | 179 | 1.0 |

Flagged windows per threshold (free and open scene: false alarms; contact and after contact: detections):

| kind | speed | window s | threshold | free flagged | open-scene flagged | contact flagged | after-contact flagged |
|---|---|---|---|---|---|---|---|
| walk | walk 1.2 | 0.5 | 0.2 | 0/2504 | 0/184 | 1534/1788 | 54/244 |
| walk | walk 1.2 | 0.5 | 0.3 | 0/2504 | 0/184 | 1557/1788 | 54/244 |
| walk | walk 1.2 | 0.5 | 0.4 | 0/2504 | 0/184 | 1603/1788 | 60/244 |
| walk | walk 1.2 | 0.5 | 0.5 | 44/2504 | 0/184 | 1627/1788 | 61/244 |
| walk | walk 1.2 | 1.0 | 0.2 | 0/2079 | 0/173 | 1256/1638 | 14/179 |
| walk | walk 1.2 | 1.0 | 0.3 | 0/2079 | 0/173 | 1302/1638 | 20/179 |
| walk | walk 1.2 | 1.0 | 0.4 | 0/2079 | 0/173 | 1338/1638 | 26/179 |
| walk | walk 1.2 | 1.0 | 0.5 | 21/2079 | 0/173 | 1379/1638 | 35/179 |

Per trial: first horizontal collision, first window under 0.3 (0.5 s in combat, 1 s otherwise) and the time spent under it:

| mover | scene | reached | first collision s | first flag s | flagged s |
|---|---|---|---|---|---|
| post_guard | trunk | yes | 10.7 | 11.3 | 1.0 |
| post_guard | trunk_near | yes | 14.8 | 17.2 | 2.5 |
| post_guard | row | yes | 6.3 | 7.1 | 0.9 |
| post_guard | doorway | yes | 10.7 | 11.3 | 1.0 |
| post_guard | lcorner | yes | 6.3 | 8.6 | 2.5 |
| post_guard | fence | no | 15.8 | 19.5 | 26.0 |
| post_guard | fence_low | yes | - | - | 0.0 |
| post_guard | pillar | yes | 5.4 | 6.2 | 0.7 |
| post_guard | ditch | yes | - | - | 0.0 |
| post_guard | step | yes | - | - | 0.0 |
| post_guard | lowgap | yes | 10.7 | 11.3 | 32.1 |
| post_guard | pond | yes | - | - | 0.0 |
| post_guard | door_closed | no | 13.9 | 14.6 | 29.9 |
| post_guard | door_open | yes | - | - | 0.0 |
| royal_guard | trunk | yes | 6.2 | 6.9 | 1.7 |
| royal_guard | trunk_near | yes | 10.4 | - | 0.0 |
| royal_guard | row | yes | 6.2 | 6.9 | 1.7 |
| royal_guard | doorway | yes | 6.2 | 6.9 | 1.7 |
| royal_guard | lcorner | yes | 6.2 | 6.9 | 1.7 |
| royal_guard | fence | yes | - | - | 0.0 |
| royal_guard | fence_low | yes | - | - | 0.0 |
| royal_guard | pillar | yes | 5.3 | 6.1 | 1.3 |
| royal_guard | ditch | yes | 7.0 | 7.8 | 1.3 |
| royal_guard | step | yes | - | - | 0.0 |
| royal_guard | lowgap | yes | 6.2 | 6.9 | 20.7 |
| royal_guard | pond | yes | - | - | 0.0 |
| royal_guard | door_closed | yes | 6.2 | 6.9 | 20.7 |
| royal_guard | door_open | yes | 6.2 | 6.9 | 20.7 |

Before: tools/r42_nv1/evidence/after/scenes.json (NV1's after run, the base of NV2); after: this run (NV2 after its review fixes). Columns read before / after.

## Before / after

| mover | scene | reached | t goal s | searches | search ms | largest us |
|---|---|---|---|---|---|---|
| post_guard | open | yes / yes | 14.4 / 11.1 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| post_guard | trunk | yes / yes | 36.6 / 18.5 | 2 / 1 | 0.07 / 0.03 | 40 / 31 |
| post_guard | trunk_near | yes / yes | 43.5 / 19.5 | 4 / 1 | 0.08 / 0.02 | 24 / 21 |
| post_guard | row | yes / yes | 38.6 / 13.9 | 4 / 1 | 0.11 / 0.03 | 36 / 31 |
| post_guard | doorway | yes / yes | 44.1 / 21.6 | 8 / 1 | 0.38 / 0.05 | 62 / 52 |
| post_guard | lcorner | no / yes | - / 21.5 | 9 / 1 | 0.49 / 0.09 | 100 / 85 |
| post_guard | fence | no / no | - / - | 4 / 5 | 2.12 / 0.63 | 595 / 144 |
| post_guard | fence_low | no / yes | - / 12.4 | 9 / 1 | 0.12 / 0.02 | 19 / 16 |
| post_guard | pillar | no / yes | - / 14.9 | 7 / 1 | 0.23 / 0.05 | 48 / 48 |
| post_guard | ditch | no / yes | - / 18.5 | 13 / 1 | 1.09 / 0.09 | 110 / 91 |
| post_guard | step | yes / yes | 13.3 / 13.3 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| post_guard | lowgap | no / yes | - / 43.4 | 14 / 6 | 0.14 / 0.09 | 15 / 18 |
| post_guard | pond | no / yes | - / 21.8 | 11 / 1 | 1.36 / 0.14 | 220 / 137 |
| post_guard | door_closed | no / no | - / - | 4 / 5 | 0.95 / 0.31 | 241 / 64 |
| post_guard | door_open | yes / yes | 20.9 / 15.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | open | yes / yes | 8.7 / 8.6 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | trunk | yes / yes | 28.2 / 11.9 | 1 / 1 | 0.03 / 0.03 | 33 / 31 |
| royal_guard | trunk_near | yes / yes | 8.7 / 8.6 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | row | yes / yes | 28.2 / 11.9 | 1 / 1 | 0.02 / 0.02 | 23 / 23 |
| royal_guard | doorway | yes / yes | 28.2 / 15.5 | 1 / 2 | 0.05 / 0.09 | 54 / 61 |
| royal_guard | lcorner | yes / yes | 28.2 / 18.4 | 1 / 1 | 0.07 / 0.06 | 72 / 64 |
| royal_guard | fence | yes / yes | 8.7 / 8.6 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | fence_low | yes / yes | 8.7 / 8.6 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | pillar | yes / yes | 27.1 / 12.7 | 1 / 1 | 0.05 / 0.04 | 47 / 45 |
| royal_guard | ditch | no / yes | - / 14.3 | 0 / 1 | 0.0 / 0.05 | 0 / 51 |
| royal_guard | step | yes / yes | 8.6 / 8.6 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | lowgap | yes / yes | 28.2 / 27.6 | 1 / 4 | 0.01 / 0.06 | 10 / 17 |
| royal_guard | pond | yes / yes | 13.0 / 11.0 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | door_closed | yes / yes | 27.1 / 27.6 | 1 / 4 | 0.25 / 0.26 | 254 / 68 |
| royal_guard | door_open | yes / yes | 27.1 / 27.6 | 1 / 4 | 0.24 / 0.2 | 236 / 51 |
