# NV0 probe summary (nv0_results.json)

Seed 12345, settings {"dedicated_server_step": "0.09", "mob_pathfinding_searchdistance": "24", "mob_pathfinding_stuck_path_timeout": "3.0", "mob_pathfinding_stuck_timeout": "2.0"}, A* budget 3000 us/step.

## Movers

| mover | entity | kind | width | height | walk | run | step | fear | floats | tier | trial s |
|---|---|---|---|---|---|---|---|---|---|---|---|
| bandit | grug_mobs:bandit | combat | 0.6 | 1.7 | 1 | 4.6 | 1.1 | 6 | yes | normal | 20 |
| bear | grug_mobs:bear | combat | 1.4 | 1.4 | 1 | 4.6 | 1.1 | 6 | yes | normal | 20 |
| boar | grug_mobs:boar | combat | 0.9 | 0.9 | 1 | 4.6 | 1.1 | 6 | yes | normal | 20 |
| post_guard | grug_mobs:guard_accord | post | 0.6 | 1.7 | 1.2 | 4.6 | 1.1 | 4 | yes | normal | 45 |
| royal_guard | grug_mobs:royal_guard_human | follow | 0.8 | 2.4 | 1.2 | 4.6 | 1.1 | 4 | yes | elite | 30 |
| villager | grug_mobs:villager_human | villager | 0.6 | 1.7 | 1.1 | 1.1 | 1.1 | 4 | yes | - | 30 |
| wolf | grug_mobs:wolf | combat | 0.6 | 0.8 | 1.5 | 4.6 | 1.1 | 6 | yes | normal | 20 |

## Scenes per mover (today's code)

### boar

| scene | reached | t goal s | min dist | searches | found | search ms | largest us | stuck triggers / events |
|---|---|---|---|---|---|---|---|---|
| open | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| trunk | yes | 5.3 | 1.5 | 1 | 1 | 0.0 | 32 | chase_attempted 1 |
| trunk_near | yes | 4.1 | 1.7 | 1 | 1 | 0.0 | 12 | close_attempted 1 |
| row | yes | 5.3 | 1.8 | 1 | 1 | 0.0 | 21 | chase_attempted 1 |
| doorway | yes | 6.3 | 1.4 | 1 | 1 | 0.1 | 50 | chase_attempted 1 |
| lcorner | yes | 7.5 | 1.7 | 1 | 1 | 0.1 | 66 | chase_attempted 1 |
| fence | no | - | 4.6 | 5 | 0 | 2.5 | 532 | chase_attempted 5, chase_backoff 22, chase_give_up 1, give_up 1, leash_reset 1 |
| fence_low | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| pillar | yes | 5.7 | 1.5 | 1 | 1 | 0.1 | 46 | chase_attempted 1 |
| ditch | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| step | yes | 2.5 | 1.4 | 0 | 0 | 0.0 | 0 | none |
| lowgap | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| pond | yes | 3.0 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| door_closed | no | - | 8.0 | 6 | 0 | 1.4 | 244 | chase_attempted 6, chase_backoff 22, chase_give_up 1, give_up 1, leash_reset 1 |
| door_open | no | - | 8.0 | 0 | 0 | 0.0 | 0 | chase_visible 183 |

### wolf

| scene | reached | t goal s | min dist | searches | found | search ms | largest us | stuck triggers / events |
|---|---|---|---|---|---|---|---|---|
| open | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| trunk | yes | 5.0 | 1.5 | 1 | 1 | 0.0 | 30 | chase_attempted 1 |
| trunk_near | yes | 3.8 | 1.6 | 1 | 1 | 0.0 | 13 | close_attempted 1 |
| row | yes | 5.1 | 1.8 | 1 | 1 | 0.0 | 24 | chase_attempted 1 |
| doorway | yes | 6.1 | 1.6 | 1 | 1 | 0.1 | 50 | chase_attempted 1 |
| lcorner | yes | 7.2 | 1.7 | 1 | 1 | 0.1 | 70 | chase_attempted 1 |
| fence | no | - | 4.4 | 0 | 0 | 0.0 | 0 | chase_attempted 8 |
| fence_low | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| pillar | yes | 5.3 | 1.7 | 1 | 1 | 0.0 | 43 | chase_attempted 1 |
| ditch | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| step | yes | 2.5 | 1.4 | 0 | 0 | 0.0 | 0 | none |
| lowgap | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| pond | yes | 3.1 | 1.7 | 0 | 0 | 0.0 | 0 | none |
| door_closed | no | - | 7.8 | 6 | 0 | 1.5 | 280 | chase_attempted 6, chase_backoff 22, chase_give_up 1, give_up 1, leash_reset 1 |
| door_open | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |

### bear

| scene | reached | t goal s | min dist | searches | found | search ms | largest us | stuck triggers / events |
|---|---|---|---|---|---|---|---|---|
| open | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| trunk | no | - | 8.2 | 3 | 3 | 0.1 | 29 | chase_attempted 3, chase_visible 6 |
| trunk_near | no | - | 3.2 | 5 | 5 | 0.1 | 20 | chase_attempted 5 |
| row | no | - | 8.2 | 3 | 3 | 0.1 | 29 | chase_attempted 3, chase_visible 6 |
| doorway | no | - | 8.2 | 6 | 6 | 0.2 | 50 | chase_attempted 6 |
| lcorner | no | - | 8.2 | 5 | 5 | 0.3 | 69 | chase_attempted 5 |
| fence | no | - | 4.8 | 5 | 0 | 2.8 | 614 | chase_attempted 5, chase_backoff 22, chase_give_up 1, give_up 1, leash_reset 1 |
| fence_low | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| pillar | no | - | 9.2 | 6 | 6 | 0.2 | 41 | chase_attempted 6 |
| ditch | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| step | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| lowgap | no | - | 8.2 | 6 | 6 | 0.1 | 39 | chase_attempted 6, chase_backoff 22, chase_give_up 1, give_up 1, leash_reset 1 |
| pond | yes | 3.0 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| door_closed | no | - | 8.2 | 6 | 0 | 1.6 | 317 | chase_attempted 6, chase_backoff 22, chase_give_up 1, give_up 1, leash_reset 1 |
| door_open | no | - | 8.2 | 0 | 0 | 0.0 | 0 | chase_visible 184 |

### bandit

| scene | reached | t goal s | min dist | searches | found | search ms | largest us | stuck triggers / events |
|---|---|---|---|---|---|---|---|---|
| open | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| trunk | yes | 5.0 | 1.5 | 1 | 1 | 0.0 | 26 | chase_attempted 1 |
| trunk_near | yes | 3.8 | 1.6 | 1 | 1 | 0.0 | 11 | close_attempted 1 |
| row | yes | 5.1 | 1.4 | 1 | 1 | 0.0 | 21 | chase_attempted 1 |
| doorway | yes | 6.1 | 1.6 | 1 | 1 | 0.1 | 47 | chase_attempted 1 |
| lcorner | yes | 7.3 | 1.7 | 1 | 1 | 0.1 | 67 | chase_attempted 1 |
| fence | no | - | 4.4 | 0 | 0 | 0.0 | 0 | chase_attempted 8 |
| fence_low | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| pillar | yes | 5.4 | 1.7 | 1 | 1 | 0.0 | 39 | chase_attempted 1 |
| ditch | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| step | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |
| lowgap | no | - | 7.8 | 6 | 6 | 0.1 | 25 | chase_attempted 6, chase_backoff 22, chase_give_up 1, give_up 1, leash_reset 1 |
| pond | yes | 3.1 | 1.7 | 0 | 0 | 0.0 | 0 | none |
| door_closed | no | - | 7.8 | 6 | 0 | 1.5 | 273 | chase_attempted 6, chase_backoff 22, chase_give_up 1, give_up 1, leash_reset 1 |
| door_open | yes | 2.5 | 1.5 | 0 | 0 | 0.0 | 0 | none |

### post_guard

| scene | reached | t goal s | min dist | searches | found | search ms | largest us | stuck triggers / events |
|---|---|---|---|---|---|---|---|---|
| open | yes | 13.3 | 1.0 | 0 | 0 | 0.0 | 0 | stall_max 1s |
| trunk | yes | 37.5 | 0.8 | 3 | 3 | 0.1 | 31 | nudge_path 3, stall_max 22s |
| trunk_near | yes | 39.0 | 0.9 | 2 | 2 | 0.0 | 22 | nudge_path 2, stall_max 21s |
| row | yes | 38.5 | 0.7 | 4 | 4 | 0.1 | 34 | nudge_path 4, stall_max 23s |
| doorway | no | - | 2.1 | 8 | 8 | 0.4 | 59 | nudge_path 8, stall_max 27s |
| lcorner | no | - | 4.2 | 12 | 12 | 0.7 | 78 | nudge_path 12, stall_max 31s |
| fence | no | - | 4.9 | 4 | 0 | 2.2 | 585 | nudge_nopath 12, stall_max 31s |
| fence_low | no | - | 4.9 | 12 | 12 | 0.1 | 20 | nudge_path 12, stall_max 31s |
| pillar | yes | 40.6 | 0.9 | 4 | 4 | 0.1 | 32 | nudge_path 4, stall_max 23s |
| ditch | no | - | 9.1 | 14 | 14 | 1.1 | 101 | nudge_path 14, stall_max 33s |
| step | yes | 15.5 | 0.9 | 0 | 0 | 0.0 | 0 | stall_max 2s |
| lowgap | no | - | 7.8 | 12 | 12 | 0.1 | 14 | nudge_path 12, stall_max 31s |
| pond | no | - | 9.6 | 11 | 11 | 1.5 | 233 | nudge_path 11, stall_max 30s |
| door_closed | no | - | 7.8 | 4 | 0 | 1.0 | 269 | nudge_nopath 14, stall_max 33s |
| door_open | yes | 16.6 | 1.0 | 0 | 0 | 0.0 | 0 | stall_max 2s |

### royal_guard

| scene | reached | t goal s | min dist | searches | found | search ms | largest us | stuck triggers / events |
|---|---|---|---|---|---|---|---|---|
| open | yes | 8.6 | 1.2 | 0 | 0 | 0.0 | 0 | none |
| trunk | snap | 28.2 | 0 | 1 | 1 | 0.0 | 33 | nudge_path 1, teleport 1, stall_max 22s |
| trunk_near | yes | 8.6 | 2.6 | 0 | 0 | 0.0 | 0 | none |
| row | snap | 28.2 | 0 | 1 | 1 | 0.0 | 20 | nudge_path 1, teleport 1, stall_max 22s |
| doorway | snap | 28.2 | 0 | 1 | 1 | 0.1 | 50 | nudge_path 1, teleport 1, stall_max 22s |
| lcorner | snap | 28.2 | 0 | 1 | 1 | 0.1 | 72 | nudge_path 1, teleport 1, stall_max 22s |
| fence | yes | 8.6 | 4.9 | 0 | 0 | 0.0 | 0 | none |
| fence_low | yes | 8.6 | 4.9 | 0 | 0 | 0.0 | 0 | none |
| pillar | snap | 27.1 | 0 | 1 | 1 | 0.1 | 53 | nudge_path 1, teleport 1, stall_max 22s |
| ditch | no | - | 6.9 | 0 | 0 | 0.0 | 0 | stall_max 18s |
| step | yes | 8.6 | 0.2 | 0 | 0 | 0.0 | 0 | none |
| lowgap | snap | 28.2 | 0 | 1 | 1 | 0.0 | 9 | nudge_path 1, teleport 1, stall_max 22s |
| pond | yes | 12.9 | 0.5 | 0 | 0 | 0.0 | 0 | none |
| door_closed | snap | 27.1 | 0 | 1 | 0 | 0.3 | 259 | nudge_nopath 1, teleport 1, stall_max 21s |
| door_open | snap | 27.1 | 0 | 1 | 0 | 0.2 | 239 | nudge_nopath 1, teleport 1, stall_max 21s |

### villager

| scene | reached | t goal s | min dist | searches | found | search ms | largest us | stuck triggers / events |
|---|---|---|---|---|---|---|---|---|
| open | yes | 15.7 | 0.9 | 0 | 0 | 0.0 | 0 | stall_max 2s |
| trunk | no | - | 7.8 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| trunk_near | no | - | 2.8 | 0 | 0 | 0.0 | 0 | stall_max 12s |
| row | no | - | 7.8 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| doorway | no | - | 7.8 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| lcorner | no | - | 7.8 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| fence | no | - | 4.5 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| fence_low | no | - | 4.5 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| pillar | no | - | 8.8 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| ditch | no | - | 9.2 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| step | yes | 18.9 | 0.9 | 0 | 0 | 0.0 | 0 | stall_max 2s |
| lowgap | no | - | 7.8 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| pond | no | - | 11.0 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| door_closed | no | - | 7.8 | 0 | 0 | 0.0 | 0 | villager_next_spot 1, stall_max 15s |
| door_open | yes | 20.0 | 0.9 | 0 | 0 | 0.0 | 0 | stall_max 3s |

## Batches (all lanes of one mover at once; wall-clock us, noisy)

| mover | steps | mob step us p50 | p99 | max | find_path calls | find_path ms | largest step fp us |
|---|---|---|---|---|---|---|---|
| boar | 221 | 367 | 974 | 1058 | 17 | 4.2 | 532 |
| wolf | 221 | 317 | 681 | 942 | 12 | 1.7 | 431 |
| bear | 221 | 274 | 889 | 974 | 44 | 5.5 | 614 |
| bandit | 221 | 265 | 592 | 863 | 18 | 1.9 | 432 |
| post_guard | 498 | 50 | 936 | 1511 | 90 | 7.4 | 1108 |
| royal_guard | 332 | 66 | 528 | 1201 | 8 | 0.7 | 682 |
| villager | 332 | 20 | 298 | 359 | 0 | 0.0 | 0 |

## Self-movement ratio (moved / commanded speed x window)

Windows end at every server step; only windows in which the mob wanted to move the whole time, outside its reach or arrival radius and before reaching the goal. free = no horizontal node collision in the window or the second before it; contact = a collision in the window; after contact = none in the window but one in the second before (a walker resting against an obstacle between its 1 Hz nudges). The open scene is the clean free-walking sample.

| kind | speed | window s | free n | free p1 | free p5 | free p50 | open n | open p1 | contact n | contact p50 | contact p90 | after n | after p50 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| combat | run 4.6 | 0.5 | 974 | 0.5 | 0.8 | 1.0 | 84 | 0.8 | 4067 | 0.0 | 0.2 | 201 | 1.0 |
| combat | run 4.6 | 1.0 | 658 | 0.5 | 0.7 | 1.0 | 64 | 0.9 | 4146 | 0.0 | 0.5 | 96 | 0.9 |
| walk | walk 1.1 | 0.5 | 1235 | 0.8 | 1.0 | 1.0 | 110 | 0.8 | 448 | 0.0 | 0.1 | 481 | 0.0 |
| walk | walk 1.1 | 1.0 | 983 | 0.9 | 0.9 | 1.0 | 94 | 0.9 | 775 | 0.0 | 0.0 | 26 | 0.0 |
| walk | walk 1.2 | 0.5 | 2237 | 0.5 | 0.8 | 1.0 | 174 | 0.8 | 1833 | 0.0 | 0.0 | 1916 | 0.0 |
| walk | walk 1.2 | 1.0 | 1790 | 0.5 | 0.9 | 1.0 | 152 | 0.9 | 3336 | 0.0 | 0.0 | 286 | 0.1 |

Flagged windows per threshold (free and open scene: false alarms; contact and after contact: detections):

| kind | speed | window s | threshold | free flagged | open-scene flagged | contact flagged | after-contact flagged |
|---|---|---|---|---|---|---|---|
| combat | run 4.6 | 0.5 | 0.2 | 0/974 | 0/84 | 3687/4067 | 1/201 |
| combat | run 4.6 | 0.5 | 0.3 | 0/974 | 0/84 | 3726/4067 | 5/201 |
| combat | run 4.6 | 0.5 | 0.4 | 0/974 | 0/84 | 3797/4067 | 6/201 |
| combat | run 4.6 | 0.5 | 0.5 | 12/974 | 0/84 | 3853/4067 | 9/201 |
| combat | run 4.6 | 1.0 | 0.2 | 0/658 | 0/64 | 3548/4146 | 0/96 |
| combat | run 4.6 | 1.0 | 0.3 | 0/658 | 0/64 | 3624/4146 | 0/96 |
| combat | run 4.6 | 1.0 | 0.4 | 0/658 | 0/64 | 3690/4146 | 0/96 |
| combat | run 4.6 | 1.0 | 0.5 | 2/658 | 0/64 | 3776/4146 | 0/96 |
| walk | walk 1.1 | 0.5 | 0.2 | 0/1235 | 0/110 | 410/448 | 481/481 |
| walk | walk 1.1 | 0.5 | 0.3 | 0/1235 | 0/110 | 418/448 | 481/481 |
| walk | walk 1.1 | 0.5 | 0.4 | 0/1235 | 0/110 | 426/448 | 481/481 |
| walk | walk 1.1 | 0.5 | 0.5 | 0/1235 | 0/110 | 427/448 | 481/481 |
| walk | walk 1.1 | 1.0 | 0.2 | 0/983 | 0/94 | 719/775 | 26/26 |
| walk | walk 1.1 | 1.0 | 0.3 | 0/983 | 0/94 | 725/775 | 26/26 |
| walk | walk 1.1 | 1.0 | 0.4 | 0/983 | 0/94 | 735/775 | 26/26 |
| walk | walk 1.1 | 1.0 | 0.5 | 0/983 | 0/94 | 741/775 | 26/26 |
| walk | walk 1.2 | 0.5 | 0.2 | 0/2237 | 0/174 | 1735/1833 | 1827/1916 |
| walk | walk 1.2 | 0.5 | 0.3 | 0/2237 | 0/174 | 1740/1833 | 1830/1916 |
| walk | walk 1.2 | 0.5 | 0.4 | 0/2237 | 0/174 | 1757/1833 | 1840/1916 |
| walk | walk 1.2 | 0.5 | 0.5 | 29/2237 | 0/174 | 1767/1833 | 1845/1916 |
| walk | walk 1.2 | 1.0 | 0.2 | 0/1790 | 0/152 | 3177/3336 | 162/286 |
| walk | walk 1.2 | 1.0 | 0.3 | 0/1790 | 0/152 | 3194/3336 | 172/286 |
| walk | walk 1.2 | 1.0 | 0.4 | 0/1790 | 0/152 | 3210/3336 | 182/286 |
| walk | walk 1.2 | 1.0 | 0.5 | 19/1790 | 0/152 | 3225/3336 | 193/286 |

Per trial: first horizontal collision, first window under 0.3 (0.5 s in combat, 1 s otherwise) and the time spent under it:

| mover | scene | reached | first collision s | first flag s | flagged s |
|---|---|---|---|---|---|
| boar | trunk | yes | 1.4 | 1.8 | 2.0 |
| boar | trunk_near | yes | 2.5 | - | 0.0 |
| boar | row | yes | 1.4 | 1.8 | 2.0 |
| boar | doorway | yes | 1.4 | 1.8 | 2.0 |
| boar | lcorner | yes | 1.4 | 1.8 | 2.1 |
| boar | fence | no | 2.2 | 2.5 | 17.5 |
| boar | fence_low | yes | - | - | 0.0 |
| boar | pillar | yes | 1.3 | 1.6 | 2.0 |
| boar | ditch | yes | - | - | 0.0 |
| boar | step | yes | - | - | 0.0 |
| boar | lowgap | yes | - | - | 0.0 |
| boar | pond | yes | - | - | 0.0 |
| boar | door_closed | no | 1.4 | 1.8 | 18.2 |
| boar | door_open | no | 1.4 | 1.8 | 18.2 |
| wolf | trunk | yes | 1.4 | 1.9 | 1.9 |
| wolf | trunk_near | yes | 2.5 | - | 0.0 |
| wolf | row | yes | 1.4 | 1.9 | 1.9 |
| wolf | doorway | yes | 1.4 | 1.9 | 1.9 |
| wolf | lcorner | yes | 1.4 | 1.9 | 1.9 |
| wolf | fence | no | 2.2 | 2.6 | 17.4 |
| wolf | fence_low | yes | - | - | 0.0 |
| wolf | pillar | yes | 1.3 | 1.6 | 2.0 |
| wolf | ditch | yes | - | - | 0.0 |
| wolf | step | yes | - | - | 0.0 |
| wolf | lowgap | yes | - | - | 0.0 |
| wolf | pond | yes | - | - | 0.0 |
| wolf | door_closed | no | 1.4 | 1.9 | 18.1 |
| wolf | door_open | yes | - | - | 0.0 |
| bear | trunk | no | 1.4 | 1.8 | 17.8 |
| bear | trunk_near | no | 2.5 | 2.9 | 16.7 |
| bear | row | no | 1.4 | 1.8 | 17.8 |
| bear | doorway | no | 1.4 | 1.8 | 17.1 |
| bear | lcorner | no | 1.4 | 1.8 | 16.7 |
| bear | fence | no | 2.2 | 2.5 | 16.3 |
| bear | fence_low | yes | - | - | 0.0 |
| bear | pillar | no | 1.2 | 1.5 | 17.8 |
| bear | ditch | yes | - | - | 0.0 |
| bear | step | yes | - | - | 0.0 |
| bear | lowgap | no | 1.4 | 1.8 | 17.0 |
| bear | pond | yes | - | - | 0.0 |
| bear | door_closed | no | 1.4 | 1.8 | 18.2 |
| bear | door_open | no | 1.4 | 1.8 | 18.2 |
| bandit | trunk | yes | 1.4 | 1.9 | 1.9 |
| bandit | trunk_near | yes | 2.5 | - | 0.0 |
| bandit | row | yes | 1.4 | 1.9 | 1.9 |
| bandit | doorway | yes | 1.4 | 1.9 | 1.9 |
| bandit | lcorner | yes | 1.4 | 1.9 | 1.9 |
| bandit | fence | no | 2.2 | 2.6 | 17.4 |
| bandit | fence_low | yes | - | - | 0.0 |
| bandit | pillar | yes | 1.3 | 1.6 | 2.0 |
| bandit | ditch | yes | - | - | 0.0 |
| bandit | step | yes | - | - | 0.0 |
| bandit | lowgap | no | 1.4 | 1.9 | 17.0 |
| bandit | pond | yes | - | - | 0.0 |
| bandit | door_closed | no | 1.4 | 1.9 | 18.1 |
| bandit | door_open | yes | - | - | 0.0 |
| post_guard | trunk | yes | 7.4 | 8.1 | 21.4 |
| post_guard | trunk_near | yes | 14.8 | 17.3 | 21.9 |
| post_guard | row | yes | 6.3 | 7.0 | 21.8 |
| post_guard | doorway | no | 7.4 | 8.1 | 21.4 |
| post_guard | lcorner | no | 6.3 | 9.7 | 20.5 |
| post_guard | fence | no | - | - | 0.0 |
| post_guard | fence_low | no | - | - | 0.0 |
| post_guard | pillar | yes | 7.6 | 9.7 | 21.9 |
| post_guard | ditch | no | - | - | 0.0 |
| post_guard | step | yes | - | - | 0.0 |
| post_guard | lowgap | no | 10.7 | 11.3 | 31.9 |
| post_guard | pond | no | - | - | 0.0 |
| post_guard | door_closed | no | 8.5 | 9.1 | 35.9 |
| post_guard | door_open | yes | - | - | 0.0 |
| royal_guard | trunk | yes | 6.2 | 6.9 | 20.6 |
| royal_guard | trunk_near | yes | 10.4 | - | 0.0 |
| royal_guard | row | yes | 6.2 | 6.9 | 20.6 |
| royal_guard | doorway | yes | 6.2 | 6.9 | 20.6 |
| royal_guard | lcorner | yes | 6.2 | 6.9 | 20.6 |
| royal_guard | fence | yes | - | - | 0.0 |
| royal_guard | fence_low | yes | - | - | 0.0 |
| royal_guard | pillar | yes | 5.3 | 6.2 | 20.3 |
| royal_guard | ditch | no | 10.6 | 11.3 | 18.7 |
| royal_guard | step | yes | - | - | 0.0 |
| royal_guard | lowgap | yes | 6.2 | 6.9 | 21.4 |
| royal_guard | pond | yes | - | - | 0.0 |
| royal_guard | door_closed | yes | 6.2 | 6.9 | 20.3 |
| royal_guard | door_open | yes | 6.2 | 6.9 | 20.3 |
| villager | trunk | no | 8.9 | 9.7 | 15.3 |
| villager | trunk_near | no | 16.7 | 17.5 | 10.7 |
| villager | row | no | 10.0 | 10.8 | 17.4 |
| villager | doorway | no | 6.8 | 7.5 | 15.3 |
| villager | lcorner | no | 7.9 | 8.6 | 14.2 |
| villager | fence | no | - | - | 0.0 |
| villager | fence_low | no | - | - | 0.0 |
| villager | pillar | no | 8.1 | 10.8 | 15.2 |
| villager | ditch | no | - | - | 0.0 |
| villager | step | yes | - | - | 0.0 |
| villager | lowgap | no | 7.9 | 8.6 | 13.1 |
| villager | pond | no | - | - | 0.0 |
| villager | door_closed | no | 10.0 | 10.8 | 15.3 |
| villager | door_open | yes | - | - | 0.0 |
