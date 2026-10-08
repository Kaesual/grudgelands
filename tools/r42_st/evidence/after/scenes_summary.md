# NV0 probe summary (nv0_results.json)

Seed 12345, settings {"dedicated_server_step": "0.09", "mob_pathfinding_searchdistance": "24", "mob_pathfinding_stuck_path_timeout": "3.0", "mob_pathfinding_stuck_timeout": "2.0"}, A* budget 3000 us/step.

## Movers

| mover | entity | kind | width | height | walk | run | step | fear | floats | tier | trial s |
|---|---|---|---|---|---|---|---|---|---|---|---|
| post_guard | grug_mobs:guard_accord | post | 0.6 | 1.7 | 1.2 | 4.6 | 1.1 | 4 | yes | normal | 45 |
| villager | grug_mobs:villager_human | villager | 0.6 | 1.7 | 1.1 | 1.1 | 1.1 | 4 | yes | - | 30 |

## Scenes per mover (today's code)

### post_guard

| scene | reached | t goal s | min dist | searches | found | search ms | largest us | stuck triggers / events |
|---|---|---|---|---|---|---|---|---|
| open | yes | 11.1 | 1.0 | 0 | 0 | 0.0 | 0 | none |
| trunk | yes | 13.8 | 0.9 | 1 | 1 | 0.0 | 33 | nav_found 1, nav_stuck 1 |
| trunk_near | yes | 13.9 | 1.3 | 1 | 1 | 0.0 | 21 | nav_found 1, nav_stuck 1 |
| row | yes | 13.7 | 0.7 | 1 | 1 | 0.0 | 25 | nav_found 1, nav_stuck 1 |
| doorway | yes | 17.2 | 1.6 | 1 | 1 | 0.1 | 48 | nav_found 1, nav_stuck 1 |
| lcorner | yes | 20.0 | 0.9 | 1 | 1 | 0.1 | 58 | nav_found 1, nav_stuck 1 |
| fence | no | - | 4.4 | 6 | 0 | 0.8 | 170 | nav_no_path 6, nav_stuck 2 |
| fence_low | yes | 12.3 | 1.1 | 1 | 1 | 0.0 | 10 | nav_found 1, nav_stuck 1 |
| pillar | yes | 14.6 | 0.8 | 1 | 1 | 0.0 | 42 | nav_found 1, nav_stuck 1 |
| ditch | yes | 16.1 | 1.3 | 1 | 1 | 0.1 | 74 | nav_found 1, nav_stuck 1 |
| step | yes | 11.1 | 0.9 | 0 | 0 | 0.0 | 0 | none |
| lowgap | snap | 39.1 | 0 | 6 | 6 | 0.1 | 58 | nav_rejected 6, nav_stuck 1, snap 1, teleport 1 |
| pond | yes | 15.3 | 0.7 | 1 | 0 | 0.1 | 154 | nav_no_path 1, nav_stuck 1 |
| door_closed | yes | 12.8 | 0.8 | 1 | 0 | 0.1 | 60 | nav_no_path 1, nav_stuck 1 |
| door_open | yes | 11.1 | 1.0 | 0 | 0 | 0.0 | 0 | none |

### villager

| scene | reached | t goal s | min dist | searches | found | search ms | largest us | stuck triggers / events |
|---|---|---|---|---|---|---|---|---|
| open | yes | 12.4 | 0.9 | 0 | 0 | 0.0 | 0 | none |
| trunk | yes | 14.5 | 0.8 | 1 | 1 | 0.0 | 30 | nav_found 1, nav_stuck 1 |
| trunk_near | yes | 15.6 | 0.8 | 1 | 1 | 0.0 | 24 | nav_found 1, nav_stuck 1 |
| row | yes | 14.5 | 0.8 | 1 | 1 | 0.0 | 20 | nav_found 1, nav_stuck 1 |
| doorway | yes | 18.5 | 0.5 | 1 | 1 | 0.1 | 48 | nav_found 1, nav_stuck 1 |
| lcorner | yes | 21.4 | 1.2 | 1 | 1 | 0.1 | 68 | nav_found 1, nav_stuck 1 |
| fence | no | - | 4.4 | 3 | 0 | 0.4 | 131 | nav_no_path 3, nav_stuck 1, villager_next_spot 1 |
| fence_low | yes | 13.6 | 1.0 | 1 | 1 | 0.0 | 7 | nav_found 1, nav_stuck 1 |
| pillar | yes | 16.8 | 1.0 | 1 | 1 | 0.0 | 34 | nav_found 1, nav_stuck 1 |
| ditch | yes | 17.3 | 1.6 | 1 | 1 | 0.1 | 104 | nav_found 1, nav_stuck 1 |
| step | yes | 12.4 | 0.9 | 0 | 0 | 0.0 | 0 | none |
| lowgap | no | - | 7.8 | 3 | 3 | 0.0 | 18 | nav_rejected 3, nav_stuck 1, villager_next_spot 1 |
| pond | yes | 16.8 | 1.0 | 1 | 0 | 0.1 | 146 | nav_no_path 1, nav_stuck 1 |
| door_closed | yes | 13.6 | 0.9 | 1 | 0 | 0.1 | 61 | nav_no_path 1, nav_stuck 1 |
| door_open | yes | 12.4 | 0.9 | 0 | 0 | 0.0 | 0 | none |

## Batches (all lanes of one mover at once; wall-clock us, noisy)

| mover | steps | mob step us p50 | p99 | max | find_path calls | find_path ms | largest step fp us |
|---|---|---|---|---|---|---|---|
| post_guard | 498 | 69 | 757 | 1278 | 22 | 1.4 | 234 |
| villager | 333 | 29 | 517 | 1119 | 16 | 1.0 | 271 |

## Self-movement ratio (moved / commanded speed x window)

Windows end at every server step; only windows in which the mob wanted to move the whole time, outside its reach or arrival radius and before reaching the goal. free = no horizontal node collision in the window or the second before it; contact = a collision in the window; after contact = none in the window but one in the second before (a walker resting against an obstacle between its 1 Hz nudges). The open scene is the clean free-walking sample.

| kind | speed | window s | free n | free p1 | free p5 | free p50 | open n | open p1 | contact n | contact p50 | contact p90 | after n | after p50 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| walk | walk 1.1 | 0.5 | 1837 | 0.5 | 0.8 | 1.0 | 120 | 1.0 | 343 | 0.0 | 0.8 | 189 | 1.0 |
| walk | walk 1.1 | 1.0 | 1671 | 0.5 | 0.9 | 1.0 | 115 | 1.0 | 387 | 0.5 | 0.9 | 144 | 1.0 |
| walk | walk 1.2 | 0.5 | 1564 | 0.5 | 0.8 | 1.0 | 106 | 1.0 | 687 | 0.0 | 0.5 | 169 | 0.9 |
| walk | walk 1.2 | 1.0 | 1403 | 0.5 | 0.8 | 1.0 | 100 | 0.9 | 603 | 0.0 | 0.7 | 130 | 1.0 |

Flagged windows per threshold (free and open scene: false alarms; contact and after contact: detections):

| kind | speed | window s | threshold | free flagged | open-scene flagged | contact flagged | after-contact flagged |
|---|---|---|---|---|---|---|---|
| walk | walk 1.1 | 0.5 | 0.2 | 0/1837 | 0/120 | 203/343 | 46/189 |
| walk | walk 1.1 | 0.5 | 0.3 | 0/1837 | 0/120 | 211/343 | 46/189 |
| walk | walk 1.1 | 0.5 | 0.4 | 0/1837 | 0/120 | 228/343 | 52/189 |
| walk | walk 1.1 | 0.5 | 0.5 | 13/1837 | 0/120 | 247/343 | 58/189 |
| walk | walk 1.1 | 1.0 | 0.2 | 0/1671 | 0/115 | 157/387 | 10/144 |
| walk | walk 1.1 | 1.0 | 0.3 | 0/1671 | 0/115 | 166/387 | 16/144 |
| walk | walk 1.1 | 1.0 | 0.4 | 0/1671 | 0/115 | 176/387 | 22/144 |
| walk | walk 1.1 | 1.0 | 0.5 | 15/1671 | 0/115 | 188/387 | 28/144 |
| walk | walk 1.2 | 0.5 | 0.2 | 0/1564 | 0/106 | 572/687 | 54/169 |
| walk | walk 1.2 | 0.5 | 0.3 | 0/1564 | 0/106 | 572/687 | 54/169 |
| walk | walk 1.2 | 0.5 | 0.4 | 0/1564 | 0/106 | 595/687 | 60/169 |
| walk | walk 1.2 | 0.5 | 0.5 | 26/1564 | 0/106 | 608/687 | 63/169 |
| walk | walk 1.2 | 1.0 | 0.2 | 0/1403 | 0/100 | 417/603 | 13/130 |
| walk | walk 1.2 | 1.0 | 0.3 | 0/1403 | 0/100 | 426/603 | 19/130 |
| walk | walk 1.2 | 1.0 | 0.4 | 0/1403 | 0/100 | 435/603 | 25/130 |
| walk | walk 1.2 | 1.0 | 0.5 | 22/1403 | 0/100 | 448/603 | 34/130 |

Per trial: first horizontal collision, first window under 0.3 (0.5 s in combat, 1 s otherwise) and the time spent under it:

| mover | scene | reached | first collision s | first flag s | flagged s |
|---|---|---|---|---|---|
| post_guard | trunk | yes | 6.3 | 7.0 | 1.0 |
| post_guard | trunk_near | yes | 10.5 | 11.1 | 1.2 |
| post_guard | row | yes | 6.3 | 7.0 | 1.0 |
| post_guard | doorway | yes | 6.3 | 7.0 | 1.0 |
| post_guard | lcorner | yes | 6.3 | 7.0 | 1.0 |
| post_guard | fence | no | 10.3 | 12.9 | 34.8 |
| post_guard | fence_low | yes | - | - | 0.0 |
| post_guard | pillar | yes | 5.4 | 6.2 | 0.6 |
| post_guard | ditch | yes | - | - | 0.0 |
| post_guard | step | yes | - | - | 0.0 |
| post_guard | lowgap | yes | 6.3 | 7.0 | 32.1 |
| post_guard | pond | yes | - | - | 0.0 |
| post_guard | door_closed | yes | 6.3 | 7.0 | 1.3 |
| post_guard | door_open | yes | - | - | 0.0 |
| villager | trunk | yes | 6.8 | 7.5 | 0.5 |
| villager | trunk_near | yes | 11.3 | 12.1 | 1.3 |
| villager | row | yes | 6.8 | 7.5 | 0.5 |
| villager | doorway | yes | 6.8 | 7.5 | 0.5 |
| villager | lcorner | yes | 6.8 | 7.5 | 0.5 |
| villager | fence | no | 11.0 | 12.9 | 9.8 |
| villager | fence_low | yes | - | - | 0.0 |
| villager | pillar | yes | 5.9 | 6.6 | 1.4 |
| villager | ditch | yes | - | - | 0.0 |
| villager | step | yes | - | - | 0.0 |
| villager | lowgap | no | 6.8 | 7.5 | 10.9 |
| villager | pond | yes | - | - | 0.0 |
| villager | door_closed | yes | 6.8 | 7.5 | 0.7 |
| villager | door_open | yes | - | - | 0.0 |
