# NV0 probe summary (scenes.json)

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

## Before / after

| mover | scene | reached | t goal s | searches | search ms | largest us |
|---|---|---|---|---|---|---|
| villager | open | yes / yes | 15.7 / 22.2 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| villager | trunk | no / yes | - / 18.1 | 0 / 1 | 0.0 / 0.04 | 0 / 36 |
| villager | trunk_near | no / yes | - / 21.1 | 0 / 1 | 0.0 / 0.02 | 0 / 21 |
| villager | row | no / yes | - / 17.9 | 0 / 1 | 0.0 / 0.02 | 0 / 23 |
| villager | doorway | no / yes | - / 21.8 | 0 / 1 | 0.0 / 0.05 | 0 / 51 |
| villager | lcorner | no / yes | - / 24.1 | 0 / 1 | 0.0 / 0.08 | 0 / 80 |
| villager | fence | no / no | - / - | 0 / 3 | 0.0 / 0.37 | 0 / 139 |
| villager | fence_low | no / yes | - / 16.9 | 0 / 1 | 0.0 / 0.01 | 0 / 12 |
| villager | pillar | no / yes | - / 21.6 | 0 / 1 | 0.0 / 0.03 | 0 / 33 |
| villager | ditch | no / yes | - / 20.0 | 0 / 1 | 0.0 / 0.1 | 0 / 97 |
| villager | step | yes / yes | 18.9 / 17.8 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
| villager | lowgap | no / no | - / - | 0 / 3 | 0.0 / 0.03 | 0 / 12 |
| villager | pond | no / yes | - / 20.1 | 0 / 1 | 0.0 / 0.14 | 0 / 145 |
| villager | door_closed | no / no | - / - | 0 / 3 | 0.0 / 0.23 | 0 / 79 |
| villager | door_open | yes / yes | 20.0 / 18.9 | 0 / 0 | 0.0 / 0.0 | 0 / 0 |
