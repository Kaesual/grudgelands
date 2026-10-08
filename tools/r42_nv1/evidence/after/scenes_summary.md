# NV0 probe summary (nv0_results.json)

Seed 12345, settings {"dedicated_server_step": "0.09", "mob_pathfinding_searchdistance": "24", "mob_pathfinding_stuck_path_timeout": "3.0", "mob_pathfinding_stuck_timeout": "2.0"}, A* budget 3000 us/step.

## Movers

| mover | entity | kind | width | height | walk | run | step | fear | floats | tier | trial s |
|---|---|---|---|---|---|---|---|---|---|---|---|
| bandit | grug_mobs:bandit | combat | 0.6 | 1.7 | 1 | 4.6 | 1.1 | 6 | yes | normal | 20 |
| bear | grug_mobs:bear | combat | 1.4 | 1.4 | 1 | 4.6 | 1.1 | 6 | yes | normal | 20 |
| boar | grug_mobs:boar | combat | 0.9 | 0.9 | 1 | 4.6 | 1.1 | 6 | yes | normal | 20 |
| post_guard | grug_mobs:guard_accord | post | 0.6 | 1.7 | 1.2 | 4.6 | 1.1 | 4 | yes | normal | 45 |
| royal_guard | grug_mobs:royal_guard_human | follow | 0.8 | 1.9 | 1.2 | 4.6 | 1.1 | 4 | yes | elite | 30 |
| villager | grug_mobs:villager_human | villager | 0.6 | 1.7 | 1.1 | 1.1 | 1.1 | 4 | yes | - | 30 |
| wolf | grug_mobs:wolf | combat | 0.6 | 0.8 | 1.5 | 4.6 | 1.1 | 6 | yes | normal | 20 |

## Scenes per mover (today's code)

### boar

| scene | reached | t goal s | min dist | searches | found | search ms | largest us | stuck triggers / events |
|---|---|---|---|---|---|---|---|---|
| open | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| trunk | yes | 3.8 | 1.8 | 1 | 1 | 0.0 | 30 | nav_found 1, nav_leave_line 1, nav_stuck 1 |
| trunk_near | yes | 3.8 | 1.7 | 1 | 1 | 0.0 | 20 | nav_found 1, nav_stuck 1 |
| row | yes | 3.8 | 1.8 | 1 | 1 | 0.0 | 21 | nav_found 1, nav_leave_line 1, nav_stuck 1 |
| doorway | yes | 4.6 | 1.7 | 1 | 1 | 0.1 | 48 | nav_found 1, nav_leave_line 1, nav_stuck 1 |
| lcorner | yes | 5.5 | 1.8 | 1 | 1 | 0.1 | 58 | nav_found 1, nav_leave_line 1, nav_stuck 1 |
| fence | no | - | 4.6 | 11 | 0 | 1.3 | 136 | nav_give_up 3, nav_no_path 11, nav_stuck 4, give_up 3, leash_reset 3 |
| fence_low | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| pillar | yes | 3.8 | 1.4 | 1 | 1 | 0.0 | 45 | nav_found 1, nav_leave_line 1, nav_stuck 1 |
| ditch | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| step | yes | 2.5 | 1.4 | 0 | 0 | 0.0 | 0 | none |
| lowgap | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| pond | yes | 3.0 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| door_closed | no | - | 8.0 | 12 | 0 | 0.8 | 84 | nav_give_up 4, nav_no_path 12, nav_stuck 4, give_up 4, leash_reset 4 |
| door_open | no | - | 8.0 | 12 | 0 | 0.7 | 67 | nav_give_up 4, nav_no_path 12, nav_stuck 4, give_up 4, leash_reset 4 |

### wolf

| scene | reached | t goal s | min dist | searches | found | search ms | largest us | stuck triggers / events |
|---|---|---|---|---|---|---|---|---|
| open | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| trunk | yes | 3.5 | 1.8 | 1 | 1 | 0.0 | 29 | nav_found 1, nav_leave_line 1, nav_stuck 1 |
| trunk_near | yes | 3.6 | 1.6 | 1 | 1 | 0.0 | 19 | nav_found 1, nav_stuck 1 |
| row | yes | 3.5 | 1.8 | 1 | 1 | 0.0 | 24 | nav_found 1, nav_leave_line 1, nav_stuck 1 |
| doorway | yes | 4.5 | 1.4 | 1 | 1 | 0.1 | 57 | nav_found 1, nav_leave_line 1, nav_stuck 1 |
| lcorner | yes | 5.2 | 1.6 | 1 | 1 | 0.1 | 65 | nav_found 1, nav_leave_line 1, nav_stuck 1 |
| fence | no | - | 4.4 | 11 | 0 | 1.5 | 158 | nav_give_up 3, nav_no_path 11, nav_stuck 4, give_up 3, leash_reset 3 |
| fence_low | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| pillar | yes | 3.5 | 1.4 | 1 | 1 | 0.1 | 53 | nav_found 1, nav_leave_line 1, nav_stuck 1 |
| ditch | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| step | yes | 2.5 | 1.4 | 0 | 0 | 0.0 | 0 | none |
| lowgap | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| pond | yes | 3.1 | 1.7 | 0 | 0 | 0.0 | 0 | none |
| door_closed | no | - | 7.8 | 12 | 0 | 0.9 | 91 | nav_give_up 4, nav_no_path 12, nav_stuck 4, give_up 4, leash_reset 4 |
| door_open | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |

### bear

| scene | reached | t goal s | min dist | searches | found | search ms | largest us | stuck triggers / events |
|---|---|---|---|---|---|---|---|---|
| open | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| trunk | yes | 3.7 | 1.7 | 1 | 1 | 0.0 | 29 | nav_found 1, nav_leave_line 1, nav_stuck 1 |
| trunk_near | yes | 3.8 | 1.8 | 1 | 1 | 0.0 | 19 | nav_found 1, nav_stuck 1 |
| row | no | - | 8.2 | 12 | 12 | 0.3 | 41 | nav_give_up 4, nav_rejected 12, nav_stuck 4, give_up 4, leash_reset 4 |
| doorway | no | - | 8.2 | 12 | 12 | 0.6 | 56 | nav_give_up 4, nav_rejected 12, nav_stuck 4, give_up 4, leash_reset 4 |
| lcorner | yes | 5.7 | 1.6 | 1 | 1 | 0.1 | 59 | nav_found 1, nav_leave_line 1, nav_stuck 1 |
| fence | no | - | 4.8 | 11 | 0 | 1.4 | 182 | nav_give_up 3, nav_no_path 11, nav_stuck 4, give_up 3, leash_reset 3 |
| fence_low | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| pillar | yes | 3.7 | 1.6 | 1 | 1 | 0.0 | 39 | nav_found 1, nav_leave_line 1, nav_stuck 1 |
| ditch | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| step | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| lowgap | no | - | 8.2 | 12 | 12 | 0.2 | 24 | nav_give_up 4, nav_rejected 12, nav_stuck 4, give_up 4, leash_reset 4 |
| pond | yes | 3.0 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| door_closed | no | - | 8.2 | 12 | 0 | 0.9 | 95 | nav_give_up 4, nav_no_path 12, nav_stuck 4, give_up 4, leash_reset 4 |
| door_open | no | - | 8.2 | 12 | 0 | 0.7 | 70 | nav_give_up 4, nav_no_path 12, nav_stuck 4, give_up 4, leash_reset 4 |

### bandit

| scene | reached | t goal s | min dist | searches | found | search ms | largest us | stuck triggers / events |
|---|---|---|---|---|---|---|---|---|
| open | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| trunk | yes | 3.5 | 1.8 | 1 | 1 | 0.0 | 36 | nav_found 1, nav_leave_line 1, nav_stuck 1 |
| trunk_near | yes | 3.6 | 1.6 | 1 | 1 | 0.0 | 33 | nav_found 1, nav_stuck 1 |
| row | yes | 3.5 | 1.8 | 1 | 1 | 0.0 | 23 | nav_found 1, nav_leave_line 1, nav_stuck 1 |
| doorway | yes | 4.4 | 1.4 | 1 | 1 | 0.1 | 55 | nav_found 1, nav_leave_line 1, nav_stuck 1 |
| lcorner | yes | 5.2 | 1.6 | 1 | 1 | 0.1 | 61 | nav_found 1, nav_leave_line 1, nav_stuck 1 |
| fence | no | - | 4.4 | 11 | 0 | 1.4 | 150 | nav_give_up 3, nav_no_path 11, nav_stuck 4, give_up 3, leash_reset 3 |
| fence_low | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| pillar | yes | 3.6 | 1.8 | 1 | 1 | 0.1 | 46 | nav_found 1, nav_leave_line 1, nav_stuck 1 |
| ditch | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| step | yes | 2.5 | 1.4 | 0 | 0 | 0.0 | 0 | none |
| lowgap | no | - | 7.8 | 12 | 12 | 0.3 | 36 | nav_give_up 4, nav_rejected 12, nav_stuck 4, give_up 4, leash_reset 4 |
| pond | yes | 3.1 | 1.7 | 0 | 0 | 0.0 | 0 | none |
| door_closed | no | - | 7.8 | 12 | 0 | 0.8 | 89 | nav_give_up 4, nav_no_path 12, nav_stuck 4, give_up 4, leash_reset 4 |
| door_open | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |

### post_guard

| scene | reached | t goal s | min dist | searches | found | search ms | largest us | stuck triggers / events |
|---|---|---|---|---|---|---|---|---|
| open | yes | 14.4 | 1.0 | 0 | 0 | 0.0 | 0 | stall_max 2s |
| trunk | yes | 36.6 | 0.9 | 2 | 2 | 0.1 | 40 | nudge_path 2, stall_max 21s |
| trunk_near | yes | 43.5 | 1.0 | 4 | 4 | 0.1 | 24 | nudge_path 4, stall_max 23s |
| row | yes | 38.6 | 0.7 | 4 | 4 | 0.1 | 36 | nudge_path 4, stall_max 23s |
| doorway | yes | 44.1 | 1.5 | 8 | 8 | 0.4 | 62 | nudge_path 8, stall_max 27s |
| lcorner | no | - | 3.7 | 9 | 9 | 0.5 | 100 | nudge_path 9, stall_max 28s |
| fence | no | - | 4.9 | 4 | 0 | 2.1 | 595 | nudge_nopath 11, stall_max 30s |
| fence_low | no | - | 4.9 | 9 | 9 | 0.1 | 19 | nudge_path 9, stall_max 28s |
| pillar | no | - | 2.2 | 7 | 7 | 0.2 | 48 | nudge_path 7, stall_max 26s |
| ditch | no | - | 9.1 | 13 | 13 | 1.1 | 110 | nudge_path 13, stall_max 32s |
| step | yes | 13.3 | 0.9 | 0 | 0 | 0.0 | 0 | stall_max 3s |
| lowgap | no | - | 7.8 | 14 | 14 | 0.1 | 15 | nudge_path 14, stall_max 33s |
| pond | no | - | 9.7 | 11 | 11 | 1.4 | 220 | nudge_path 11, stall_max 30s |
| door_closed | no | - | 7.8 | 4 | 0 | 0.9 | 241 | nudge_nopath 10, stall_max 29s |
| door_open | yes | 20.9 | 1.0 | 0 | 0 | 0.0 | 0 | stall_max 7s |

### royal_guard

| scene | reached | t goal s | min dist | searches | found | search ms | largest us | stuck triggers / events |
|---|---|---|---|---|---|---|---|---|
| open | yes | 8.7 | 0.0 | 0 | 0 | 0.0 | 0 | none |
| trunk | snap | 28.2 | 0 | 1 | 1 | 0.0 | 33 | nudge_path 1, teleport 1, stall_max 22s |
| trunk_near | yes | 8.7 | 0.8 | 0 | 0 | 0.0 | 0 | none |
| row | snap | 28.2 | 0 | 1 | 1 | 0.0 | 23 | nudge_path 1, teleport 1, stall_max 22s |
| doorway | snap | 28.2 | 0 | 1 | 1 | 0.1 | 54 | nudge_path 1, teleport 1, stall_max 22s |
| lcorner | snap | 28.2 | 0 | 1 | 1 | 0.1 | 72 | nudge_path 1, teleport 1, stall_max 22s |
| fence | yes | 8.7 | 4.9 | 0 | 0 | 0.0 | 0 | none |
| fence_low | yes | 8.7 | 4.9 | 0 | 0 | 0.0 | 0 | none |
| pillar | snap | 27.1 | 0 | 1 | 1 | 0.1 | 47 | nudge_path 1, teleport 1, stall_max 22s |
| ditch | no | - | 6.9 | 0 | 0 | 0.0 | 0 | stall_max 18s |
| step | yes | 8.6 | 0.0 | 0 | 0 | 0.0 | 0 | none |
| lowgap | snap | 28.2 | 0 | 1 | 1 | 0.0 | 10 | nudge_path 1, teleport 1, stall_max 22s |
| pond | yes | 13.0 | 0.0 | 0 | 0 | 0.0 | 0 | none |
| door_closed | snap | 27.1 | 0 | 1 | 0 | 0.2 | 254 | nudge_nopath 1, teleport 1, stall_max 21s |
| door_open | snap | 27.1 | 0 | 1 | 0 | 0.2 | 236 | nudge_nopath 1, teleport 1, stall_max 21s |

### villager

| scene | reached | t goal s | min dist | searches | found | search ms | largest us | stuck triggers / events |
|---|---|---|---|---|---|---|---|---|
| open | yes | 15.6 | 0.9 | 0 | 0 | 0.0 | 0 | stall_max 1s |
| trunk | no | - | 7.8 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| trunk_near | no | - | 2.8 | 0 | 0 | 0.0 | 0 | stall_max 13s |
| row | no | - | 7.8 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| doorway | no | - | 7.8 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| lcorner | no | - | 7.8 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| fence | no | - | 4.5 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| fence_low | no | - | 4.5 | 0 | 0 | 0.0 | 0 | stall_max 13s |
| pillar | no | - | 8.8 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| ditch | no | - | 9.2 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| step | yes | 14.5 | 0.9 | 0 | 0 | 0.0 | 0 | stall_max 1s |
| lowgap | no | - | 7.8 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| pond | no | - | 11.0 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| door_closed | no | - | 7.8 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| door_open | yes | 21.0 | 0.9 | 0 | 0 | 0.0 | 0 | stall_max 2s |

## Batches (all lanes of one mover at once; wall-clock us, noisy)

| mover | steps | mob step us p50 | p99 | max | find_path calls | find_path ms | largest step fp us |
|---|---|---|---|---|---|---|---|
| boar | 221 | 345 | 719 | 1017 | 41 | 3.0 | 271 |
| wolf | 221 | 299 | 777 | 1255 | 29 | 2.6 | 234 |
| bear | 221 | 341 | 815 | 1175 | 75 | 4.2 | 282 |
| bandit | 221 | 310 | 2998 | 3639 | 41 | 2.8 | 244 |
| post_guard | 498 | 35 | 921 | 1484 | 89 | 7.1 | 1132 |
| royal_guard | 333 | 42 | 434 | 1223 | 8 | 0.7 | 682 |
| villager | 333 | 11 | 277 | 379 | 0 | 0.0 | 0 |

## Self-movement ratio (moved / commanded speed x window)

Windows end at every server step; only windows in which the mob wanted to move the whole time, outside its reach or arrival radius and before reaching the goal. free = no horizontal node collision in the window or the second before it; contact = a collision in the window; after contact = none in the window but one in the second before (a walker resting against an obstacle between its 1 Hz nudges). The open scene is the clean free-walking sample.

| kind | speed | window s | free n | free p1 | free p5 | free p50 | open n | open p1 | contact n | contact p50 | contact p90 | after n | after p50 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| combat | run 4.6 | 0.5 | 954 | 0.5 | 0.8 | 1.0 | 84 | 0.8 | 2564 | 0.0 | 0.5 | 225 | 1.0 |
| combat | run 4.6 | 1.0 | 653 | 0.6 | 0.7 | 1.0 | 64 | 0.9 | 2541 | 0.1 | 0.7 | 53 | 1.0 |
| walk | walk 1.1 | 0.5 | 1169 | 0.8 | 1.0 | 1.0 | 105 | 0.8 | 404 | 0.0 | 0.1 | 440 | 0.0 |
| walk | walk 1.1 | 1.0 | 875 | 0.9 | 0.9 | 1.0 | 83 | 0.9 | 707 | 0.0 | 0.0 | 6 | 0.0 |
| walk | walk 1.2 | 0.5 | 2294 | 0.5 | 0.8 | 1.0 | 174 | 0.8 | 1729 | 0.0 | 0.0 | 1832 | 0.0 |
| walk | walk 1.2 | 1.0 | 1897 | 0.5 | 0.9 | 1.0 | 151 | 0.9 | 3176 | 0.0 | 0.0 | 200 | 0.2 |

Flagged windows per threshold (free and open scene: false alarms; contact and after contact: detections):

| kind | speed | window s | threshold | free flagged | open-scene flagged | contact flagged | after-contact flagged |
|---|---|---|---|---|---|---|---|
| combat | run 4.6 | 0.5 | 0.2 | 0/954 | 0/84 | 2181/2564 | 15/225 |
| combat | run 4.6 | 0.5 | 0.3 | 0/954 | 0/84 | 2209/2564 | 26/225 |
| combat | run 4.6 | 0.5 | 0.4 | 0/954 | 0/84 | 2269/2564 | 30/225 |
| combat | run 4.6 | 0.5 | 0.5 | 14/954 | 0/84 | 2322/2564 | 30/225 |
| combat | run 4.6 | 1.0 | 0.2 | 0/653 | 0/64 | 1927/2541 | 2/53 |
| combat | run 4.6 | 1.0 | 0.3 | 0/653 | 0/64 | 1989/2541 | 2/53 |
| combat | run 4.6 | 1.0 | 0.4 | 0/653 | 0/64 | 2051/2541 | 2/53 |
| combat | run 4.6 | 1.0 | 0.5 | 2/653 | 0/64 | 2139/2541 | 2/53 |
| walk | walk 1.1 | 0.5 | 0.2 | 0/1169 | 0/105 | 368/404 | 440/440 |
| walk | walk 1.1 | 0.5 | 0.3 | 0/1169 | 0/105 | 375/404 | 440/440 |
| walk | walk 1.1 | 0.5 | 0.4 | 0/1169 | 0/105 | 382/404 | 440/440 |
| walk | walk 1.1 | 0.5 | 0.5 | 0/1169 | 0/105 | 386/404 | 440/440 |
| walk | walk 1.1 | 1.0 | 0.2 | 0/875 | 0/83 | 647/707 | 6/6 |
| walk | walk 1.1 | 1.0 | 0.3 | 0/875 | 0/83 | 658/707 | 6/6 |
| walk | walk 1.1 | 1.0 | 0.4 | 0/875 | 0/83 | 665/707 | 6/6 |
| walk | walk 1.1 | 1.0 | 0.5 | 0/875 | 0/83 | 674/707 | 6/6 |
| walk | walk 1.2 | 0.5 | 0.2 | 0/2294 | 0/174 | 1633/1729 | 1756/1832 |
| walk | walk 1.2 | 0.5 | 0.3 | 0/2294 | 0/174 | 1638/1729 | 1761/1832 |
| walk | walk 1.2 | 0.5 | 0.4 | 0/2294 | 0/174 | 1657/1729 | 1769/1832 |
| walk | walk 1.2 | 0.5 | 0.5 | 31/2294 | 0/174 | 1660/1729 | 1775/1832 |
| walk | walk 1.2 | 1.0 | 0.2 | 0/1897 | 0/151 | 3003/3176 | 105/200 |
| walk | walk 1.2 | 1.0 | 0.3 | 0/1897 | 0/151 | 3026/3176 | 112/200 |
| walk | walk 1.2 | 1.0 | 0.4 | 0/1897 | 0/151 | 3045/3176 | 121/200 |
| walk | walk 1.2 | 1.0 | 0.5 | 12/1897 | 0/151 | 3060/3176 | 130/200 |

Per trial: first horizontal collision, first window under 0.3 (0.5 s in combat, 1 s otherwise) and the time spent under it:

| mover | scene | reached | first collision s | first flag s | flagged s |
|---|---|---|---|---|---|
| boar | trunk | yes | 1.4 | 1.8 | 0.6 |
| boar | trunk_near | yes | 2.5 | - | 0.0 |
| boar | row | yes | 1.4 | 1.8 | 0.6 |
| boar | doorway | yes | 1.4 | 1.8 | 0.6 |
| boar | lcorner | yes | 1.4 | 1.8 | 0.7 |
| boar | fence | no | 2.2 | 2.5 | 17.5 |
| boar | fence_low | yes | - | - | 0.0 |
| boar | pillar | yes | 1.3 | 1.6 | 0.3 |
| boar | ditch | yes | - | - | 0.0 |
| boar | step | yes | - | - | 0.0 |
| boar | lowgap | yes | - | - | 0.0 |
| boar | pond | yes | - | - | 0.0 |
| boar | door_closed | no | 1.4 | 1.8 | 14.7 |
| boar | door_open | no | 1.4 | 1.8 | 15.8 |
| wolf | trunk | yes | 1.4 | 1.9 | 0.5 |
| wolf | trunk_near | yes | 2.5 | - | 0.0 |
| wolf | row | yes | 1.4 | 1.9 | 0.5 |
| wolf | doorway | yes | 1.4 | 1.9 | 0.5 |
| wolf | lcorner | yes | 1.4 | 1.9 | 0.5 |
| wolf | fence | no | 2.2 | 2.6 | 17.4 |
| wolf | fence_low | yes | - | - | 0.0 |
| wolf | pillar | yes | 1.3 | 1.6 | 0.3 |
| wolf | ditch | yes | - | - | 0.0 |
| wolf | step | yes | - | - | 0.0 |
| wolf | lowgap | yes | - | - | 0.0 |
| wolf | pond | yes | - | - | 0.0 |
| wolf | door_closed | no | 1.4 | 1.9 | 16.7 |
| wolf | door_open | yes | - | - | 0.0 |
| bear | trunk | yes | 1.4 | 1.8 | 0.7 |
| bear | trunk_near | yes | 2.5 | 2.9 | 0.7 |
| bear | row | no | 1.4 | 1.8 | 18.0 |
| bear | doorway | no | 1.4 | 1.8 | 16.9 |
| bear | lcorner | yes | 1.4 | 1.8 | 0.6 |
| bear | fence | no | 2.2 | 2.5 | 16.2 |
| bear | fence_low | yes | - | - | 0.0 |
| bear | pillar | yes | 1.2 | 1.5 | 0.4 |
| bear | ditch | yes | - | - | 0.0 |
| bear | step | yes | - | - | 0.0 |
| bear | lowgap | no | 1.4 | 1.8 | 18.0 |
| bear | pond | yes | - | - | 0.0 |
| bear | door_closed | no | 1.4 | 1.8 | 16.9 |
| bear | door_open | no | 1.4 | 1.8 | 15.4 |
| bandit | trunk | yes | 1.4 | 1.9 | 0.5 |
| bandit | trunk_near | yes | 2.5 | - | 0.0 |
| bandit | row | yes | 1.4 | 1.9 | 0.5 |
| bandit | doorway | yes | 1.4 | 1.9 | 0.5 |
| bandit | lcorner | yes | 1.4 | 1.9 | 0.5 |
| bandit | fence | no | 2.2 | 2.6 | 17.4 |
| bandit | fence_low | yes | - | - | 0.0 |
| bandit | pillar | yes | 1.3 | 1.6 | 0.3 |
| bandit | ditch | yes | - | - | 0.0 |
| bandit | step | yes | - | - | 0.0 |
| bandit | lowgap | no | 1.4 | 1.9 | 17.9 |
| bandit | pond | yes | - | - | 0.0 |
| bandit | door_closed | no | 1.4 | 1.9 | 17.9 |
| bandit | door_open | yes | - | - | 0.0 |
| post_guard | trunk | yes | 8.5 | 9.1 | 21.6 |
| post_guard | trunk_near | yes | 12.7 | 13.3 | 21.8 |
| post_guard | row | yes | 7.4 | 8.1 | 21.7 |
| post_guard | doorway | yes | 9.6 | 10.3 | 21.1 |
| post_guard | lcorner | no | 8.5 | 9.1 | 19.1 |
| post_guard | fence | no | - | - | 0.0 |
| post_guard | fence_low | no | - | - | 0.0 |
| post_guard | pillar | no | 6.5 | 8.6 | 21.7 |
| post_guard | ditch | no | - | - | 0.0 |
| post_guard | step | yes | - | - | 0.0 |
| post_guard | lowgap | no | 8.5 | 9.1 | 35.9 |
| post_guard | pond | no | - | - | 0.0 |
| post_guard | door_closed | no | 12.8 | 13.5 | 31.0 |
| post_guard | door_open | yes | - | - | 0.0 |
| royal_guard | trunk | yes | 6.2 | 6.9 | 20.6 |
| royal_guard | trunk_near | yes | 14.7 | - | 0.0 |
| royal_guard | row | yes | 6.2 | 6.9 | 20.6 |
| royal_guard | doorway | yes | 6.2 | 6.9 | 20.6 |
| royal_guard | lcorner | yes | 6.2 | 6.9 | 20.6 |
| royal_guard | fence | yes | - | - | 0.0 |
| royal_guard | fence_low | yes | - | - | 0.0 |
| royal_guard | pillar | yes | 5.3 | 6.1 | 20.2 |
| royal_guard | ditch | no | 10.6 | 11.3 | 18.8 |
| royal_guard | step | yes | - | - | 0.0 |
| royal_guard | lowgap | yes | 6.2 | 6.9 | 21.3 |
| royal_guard | pond | yes | - | - | 0.0 |
| royal_guard | door_closed | yes | 6.2 | 6.9 | 20.2 |
| royal_guard | door_open | yes | 6.2 | 6.9 | 20.2 |
| villager | trunk | no | 7.9 | 8.5 | 16.2 |
| villager | trunk_near | no | 15.6 | 16.4 | 13.6 |
| villager | row | no | 11.1 | 11.8 | 14.2 |
| villager | doorway | no | 10.0 | 10.7 | 17.3 |
| villager | lcorner | no | 10.0 | 10.7 | 14.2 |
| villager | fence | no | - | - | 0.0 |
| villager | fence_low | no | - | - | 0.0 |
| villager | pillar | no | 9.1 | 9.8 | 15.1 |
| villager | ditch | no | - | - | 0.0 |
| villager | step | yes | - | - | 0.0 |
| villager | lowgap | no | 7.9 | 8.6 | 15.3 |
| villager | pond | no | - | - | 0.0 |
| villager | door_closed | no | 7.8 | 8.6 | 14.2 |
| villager | door_open | yes | - | - | 0.0 |

## Before / after (before: tools/r42_nv0/evidence/before/scenes.json)

| mover | scene | reached | t goal s | searches | search ms | largest us |
|---|---|---|---|---|---|---|
| boar | open | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| boar | trunk | yes / yes | 5.3 / 3.8 | 1 / 1 | 0.03 / 0.03 | 32 / 30 |
| boar | trunk_near | yes / yes | 4.1 / 3.8 | 1 / 1 | 0.01 / 0.02 | 12 / 20 |
| boar | row | yes / yes | 5.3 / 3.8 | 1 / 1 | 0.02 / 0.02 | 21 / 21 |
| boar | doorway | yes / yes | 6.3 / 4.6 | 1 / 1 | 0.05 / 0.05 | 50 / 48 |
| boar | lcorner | yes / yes | 7.5 / 5.5 | 1 / 1 | 0.07 / 0.06 | 66 / 58 |
| boar | fence | no / no | - / - | 5 / 11 | 2.52 / 1.28 | 532 / 136 |
| boar | fence_low | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| boar | pillar | yes / yes | 5.7 / 3.8 | 1 / 1 | 0.05 / 0.04 | 46 / 45 |
| boar | ditch | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| boar | step | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| boar | lowgap | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| boar | pond | yes / yes | 3.0 / 3.0 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| boar | door_closed | no / no | - / - | 6 / 12 | 1.42 / 0.84 | 244 / 84 |
| boar | door_open | no / no | - / - | 0 / 12 | 0.0 / 0.68 | 0 / 67 |
| wolf | open | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| wolf | trunk | yes / yes | 5.0 / 3.5 | 1 / 1 | 0.03 / 0.03 | 30 / 29 |
| wolf | trunk_near | yes / yes | 3.8 / 3.6 | 1 / 1 | 0.01 / 0.02 | 13 / 19 |
| wolf | row | yes / yes | 5.1 / 3.5 | 1 / 1 | 0.02 / 0.02 | 24 / 24 |
| wolf | doorway | yes / yes | 6.1 / 4.5 | 1 / 1 | 0.05 / 0.06 | 50 / 57 |
| wolf | lcorner | yes / yes | 7.2 / 5.2 | 1 / 1 | 0.07 / 0.07 | 70 / 65 |
| wolf | fence | no / no | - / - | 0 / 11 | 0.0 / 1.47 | 0 / 158 |
| wolf | fence_low | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| wolf | pillar | yes / yes | 5.3 / 3.5 | 1 / 1 | 0.04 / 0.05 | 43 / 53 |
| wolf | ditch | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| wolf | step | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| wolf | lowgap | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| wolf | pond | yes / yes | 3.1 / 3.1 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| wolf | door_closed | no / no | - / - | 6 / 12 | 1.51 / 0.91 | 280 / 91 |
| wolf | door_open | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| bear | open | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| bear | trunk | no / yes | - / 3.7 | 3 / 1 | 0.08 / 0.03 | 29 / 29 |
| bear | trunk_near | no / yes | - / 3.8 | 5 / 1 | 0.08 / 0.02 | 20 / 19 |
| bear | row | no / no | - / - | 3 / 12 | 0.07 / 0.29 | 29 / 41 |
| bear | doorway | no / no | - / - | 6 / 12 | 0.23 / 0.57 | 50 / 56 |
| bear | lcorner | no / yes | - / 5.7 | 5 / 1 | 0.28 / 0.06 | 69 / 59 |
| bear | fence | no / no | - / - | 5 / 11 | 2.84 / 1.42 | 614 / 182 |
| bear | fence_low | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| bear | pillar | no / yes | - / 3.7 | 6 / 1 | 0.21 / 0.04 | 41 / 39 |
| bear | ditch | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| bear | step | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| bear | lowgap | no / no | - / - | 6 / 12 | 0.14 / 0.18 | 39 / 24 |
| bear | pond | yes / yes | 3.0 / 3.0 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| bear | door_closed | no / no | - / - | 6 / 12 | 1.56 / 0.87 | 317 / 95 |
| bear | door_open | no / no | - / - | 0 / 12 | 0.0 / 0.7 | 0 / 70 |
| bandit | open | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| bandit | trunk | yes / yes | 5.0 / 3.5 | 1 / 1 | 0.03 / 0.04 | 26 / 36 |
| bandit | trunk_near | yes / yes | 3.8 / 3.6 | 1 / 1 | 0.01 / 0.03 | 11 / 33 |
| bandit | row | yes / yes | 5.1 / 3.5 | 1 / 1 | 0.02 / 0.02 | 21 / 23 |
| bandit | doorway | yes / yes | 6.1 / 4.4 | 1 / 1 | 0.05 / 0.06 | 47 / 55 |
| bandit | lcorner | yes / yes | 7.3 / 5.2 | 1 / 1 | 0.07 / 0.06 | 67 / 61 |
| bandit | fence | no / no | - / - | 0 / 11 | 0.0 / 1.44 | 0 / 150 |
| bandit | fence_low | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| bandit | pillar | yes / yes | 5.4 / 3.6 | 1 / 1 | 0.04 / 0.05 | 39 / 46 |
| bandit | ditch | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| bandit | step | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| bandit | lowgap | no / no | - / - | 6 / 12 | 0.11 / 0.3 | 25 / 36 |
| bandit | pond | yes / yes | 3.1 / 3.1 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| bandit | door_closed | no / no | - / - | 6 / 12 | 1.53 / 0.82 | 273 / 89 |
| bandit | door_open | yes / yes | 2.5 / 2.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| post_guard | open | yes / yes | 13.3 / 14.4 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| post_guard | trunk | yes / yes | 37.5 / 36.6 | 3 / 2 | 0.08 / 0.07 | 31 / 40 |
| post_guard | trunk_near | yes / yes | 39.0 / 43.5 | 2 / 4 | 0.04 / 0.08 | 22 / 24 |
| post_guard | row | yes / yes | 38.5 / 38.6 | 4 / 4 | 0.08 / 0.11 | 34 / 36 |
| post_guard | doorway | no / yes | - / 44.1 | 8 / 8 | 0.36 / 0.38 | 59 / 62 |
| post_guard | lcorner | no / no | - / - | 12 / 9 | 0.65 / 0.49 | 78 / 100 |
| post_guard | fence | no / no | - / - | 4 / 4 | 2.23 / 2.12 | 585 / 595 |
| post_guard | fence_low | no / no | - / - | 12 / 9 | 0.15 / 0.12 | 20 / 19 |
| post_guard | pillar | yes / no | 40.6 / - | 4 / 7 | 0.11 / 0.23 | 32 / 48 |
| post_guard | ditch | no / no | - / - | 14 / 13 | 1.15 / 1.09 | 101 / 110 |
| post_guard | step | yes / yes | 15.5 / 13.3 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| post_guard | lowgap | no / no | - / - | 12 / 14 | 0.11 / 0.14 | 14 / 15 |
| post_guard | pond | no / no | - / - | 11 / 11 | 1.46 / 1.36 | 233 / 220 |
| post_guard | door_closed | no / no | - / - | 4 / 4 | 0.99 / 0.95 | 269 / 241 |
| post_guard | door_open | yes / yes | 16.6 / 20.9 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | open | yes / yes | 8.6 / 8.7 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | trunk | yes / yes | 28.2 / 28.2 | 1 / 1 | 0.03 / 0.03 | 33 / 33 |
| royal_guard | trunk_near | yes / yes | 8.6 / 8.7 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | row | yes / yes | 28.2 / 28.2 | 1 / 1 | 0.02 / 0.02 | 20 / 23 |
| royal_guard | doorway | yes / yes | 28.2 / 28.2 | 1 / 1 | 0.05 / 0.05 | 50 / 54 |
| royal_guard | lcorner | yes / yes | 28.2 / 28.2 | 1 / 1 | 0.07 / 0.07 | 72 / 72 |
| royal_guard | fence | yes / yes | 8.6 / 8.7 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | fence_low | yes / yes | 8.6 / 8.7 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | pillar | yes / yes | 27.1 / 27.1 | 1 / 1 | 0.05 / 0.05 | 53 / 47 |
| royal_guard | ditch | no / no | - / - | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | step | yes / yes | 8.6 / 8.6 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | lowgap | yes / yes | 28.2 / 28.2 | 1 / 1 | 0.01 / 0.01 | 9 / 10 |
| royal_guard | pond | yes / yes | 12.9 / 13.0 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| royal_guard | door_closed | yes / yes | 27.1 / 27.1 | 1 / 1 | 0.26 / 0.25 | 259 / 254 |
| royal_guard | door_open | yes / yes | 27.1 / 27.1 | 1 / 1 | 0.24 / 0.24 | 239 / 236 |
| villager | open | yes / yes | 15.7 / 15.6 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| villager | trunk | no / no | - / - | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| villager | trunk_near | no / no | - / - | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| villager | row | no / no | - / - | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| villager | doorway | no / no | - / - | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| villager | lcorner | no / no | - / - | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| villager | fence | no / no | - / - | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| villager | fence_low | no / no | - / - | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| villager | pillar | no / no | - / - | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| villager | ditch | no / no | - / - | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| villager | step | yes / yes | 18.9 / 14.5 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| villager | lowgap | no / no | - / - | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| villager | pond | no / no | - / - | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| villager | door_closed | no / no | - / - | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| villager | door_open | yes / yes | 20.0 / 21.0 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
