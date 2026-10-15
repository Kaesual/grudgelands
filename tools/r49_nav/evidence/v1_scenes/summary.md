# Round 49 NAV probe summary

Seed 12345, navigation {"CLOSE": 16, "GIVE_UP_AFTER": 3, "LOCKOUT": 1, "PADDING": 6, "PADDING_STEPS": [6, 12, 16], "STUCK_RATIO": 0.3, "WINDOW": 0.5}, probe CPU 29.2 s.

| mover | entity | width | height | run | reach | step | attack |
|---|---|---|---|---|---|---|---|
| archer | grug_mobs:skeleton_archer | 0.6 | 1.99 | 4 | 3 | 1.100000023841858 | dogshoot |
| rat | grug_mobs:giant_rat | 1.28 | 0.97 | 4.6 | 3 | 1.100000023841858 | dogfight |
| zombie | grug_mobs:zombie | 0.6 | 1.9 | 4.6 | 3 | 1.100000023841858 | dogfight |

- batch lanes_zombie: 20.04 s, CPU 20.37 s, searches 17 (found 16), largest so far 138 us
- batch lanes_rat: 20.08 s, CPU 5.96 s, searches 20 (found 19), largest so far 146 us
- batch lanes_archer: 12.09 s, CPU 0.11 s, searches 16 (found 15), largest so far 158 us

## zombie

| scene | target u,v,h | result | t hit | hit at u,v,h | min d | line0 | p6 | p12 | windows stuck/free | searches/found | fails | sequence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| flat_bush_d4 | 4,0,1 | reached after stuck | 1.81 | 3.54,1.99,1.01 | 1.39 | False | 9 | 9 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.81 |
| t1_bush_d5 | 5,0,2 | reached (from below) after stuck | 1.72 | 3.12,1.99,1.01 | 1.15 | False | 10 | 10 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.72 |
| t1_bush_d8 | 8,0,2 | reached (from below) after stuck | 2.27 | 6.12,1.99,1.01 | 1.15 | False | 13 | 13 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.27 |
| t1_bushtop_d6 | 6,0,2 | reached after stuck | 2.36 | 5.54,2,2.01 | 1.39 | False | 11 | 11 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.36 |
| t1_blue_d4 | 4,0,2 | reached after stuck | 2.36 | 1.86,1.96,2.01 | 1.23 | False | 9 | 9 | 2/2 (free<0.6: 1) | 2/2 | path_stuck=1 | stuck@0.54 found@0.54 leave_stuck@1.63 path_stuck@1.63 found@1.72 hit@2.36 |
| t1_blue_d7 | 7,0,2 | reached after stuck | 2.9 | 4.86,1.96,2.01 | 1.23 | False | 12 | 12 | 2/3 (free<0.6: 1) | 2/2 | path_stuck=1 | stuck@1.09 found@1.09 leave_stuck@2.18 path_stuck@2.18 found@2.27 hit@2.9 |
| t2_open_d4 | 4,0,3 | reached (from below) | 1 | 2.2,0,1.01 | 1.8 | False | 13 | 13 | 0/0 (free<0.6: 0) | 0/0 | - | hit@1 |
| t2_bush_d5 | 5,0,3 | reached after stuck | 2.27 | 4.82,2.67,3.01 | 1.42 | False | 14 | 14 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 leave_line@2.18 hit@2.27 |
| t2_bush_d8 | 8,0,3 | reached after stuck | 2.72 | 7.16,2.8,3.01 | 1.67 | False | 17 | 17 | 1/4 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.72 |
| t2_bush_d6_far | 6,0,3 | reached after stuck | 5.71 | 5.61,2.67,3.01 | 1.45 | False | 0 | 25 | 3/7 (free<0.6: 1) | 2/1 | search_fail=1 | stuck@1.09 no_path@1.09 search_fail@1.09 found@2.18 leave_line@4.35 hit@5.71 |
| t2_blue_d5 | 5,0,3 | reached after stuck | 2.63 | 3.95,2.64,3.01 | 1.17 | False | 14 | 14 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@2.63 |
| trunk_d3 | 3,0,1 | reached after stuck | 1.54 | 2.27,0.98,1.01 | 1.22 | False | 6 | 6 | 1/1 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@1.54 |
| trunk_d5 | 5,0,1 | reached after stuck | 1.54 | 4.27,0.98,1.01 | 1.22 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.54 |
| trunk_d8 | 8,0,1 | reached after stuck | 1.99 | 5.87,0.87,1.01 | 1.58 | False | 11 | 11 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.63 found@1.63 hit@1.99 |
| trunk_off_d5 | 5,1,1 | reached | 1 | 3.2,0.84,1.01 | 1.39 | False | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | hit@1 |
| tree_d6 | 6,0,1 | reached after stuck | 1.45 | 3.87,0.87,1.01 | 1.58 | False | 9 | 9 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.45 |
| trunks_gap_d6 | 6,0,1 | reached | 1 | 4.59,0,1.01 | 1.41 | True | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | hit@1 |

**Totals scenes:** 17 trials, reached 17, reached without a give-up 17, with a give-up 0, searches 17 (found 16), largest search 141 us.

## rat

| scene | target u,v,h | result | t hit | hit at u,v,h | min d | line0 | p6 | p12 | windows stuck/free | searches/found | fails | sequence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| flat_bush_d4 | 4,0,1 | reached after stuck | 1.81 | 3.2,2.49,1.01 | 2.14 | False | 9 | 9 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.81 |
| t1_bush_d5 | 5,0,2 | reached after stuck | 1.9 | 3.61,2.49,2.01 | 1.18 | False | 10 | 10 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.9 |
| t1_bush_d8 | 8,0,2 | reached after stuck | 2.45 | 6.62,2.49,2.01 | 1.18 | False | 13 | 13 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.45 |
| t1_bushtop_d6 | 6,0,2 | reached after stuck | 2.36 | 5.2,2.49,2.01 | 2.14 | False | 11 | 11 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.36 |
| t1_blue_d4 | 4,0,2 | reached after stuck | 1.63 | 2.37,2.46,2.01 | 1.29 | False | 9 | 9 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.63 |
| t1_blue_d7 | 7,0,2 | reached after stuck | 2.18 | 5.37,2.46,2.01 | 1.29 | False | 12 | 12 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.18 |
| t2_open_d4 | 4,0,3 | reached after stuck | 2.27 | 2.76,2.3,3.01 | 1.77 | False | 13 | 13 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 leave_line@2.18 hit@2.27 |
| t2_bush_d5 | 5,0,3 | reached after stuck | 2.09 | 3.77,2.46,3.21 | 1.49 | False | 14 | 14 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@2.09 |
| t2_bush_d8 | 8,0,3 | reached after stuck | 2.63 | 6.77,2.46,3.21 | 1.5 | False | 17 | 17 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.63 |
| t2_bush_d6_far | 6,0,3 | reached after stuck | 5.53 | 5.47,2.73,3.01 | 1.52 | False | 0 | 25 | 3/7 (free<0.6: 1) | 2/1 | search_fail=1 | stuck@1.09 no_path@1.09 search_fail@1.09 found@2.18 leave_line@4.35 hit@5.53 |
| t2_blue_d5 | 5,0,3 | reached after stuck | 2.63 | 4.17,2.81,3.01 | 1.26 | False | 14 | 14 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@2.63 |
| trunk_d3 | 3,0,1 | reached after stuck | 1.63 | 1.68,1.45,1.01 | 1.55 | False | 6 | 6 | 1/2 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@1.63 |
| trunk_d5 | 5,0,1 | reached after stuck | 1.63 | 3.68,1.45,1.01 | 1.55 | False | 8 | 8 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.63 |
| trunk_d8 | 8,0,1 | reached after stuck | 2.18 | 5.68,1.43,1.01 | 1.71 | False | 11 | 11 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.63 found@1.63 hit@2.18 |
| trunk_off_d5 | 5,1,1 | reached | 1 | 2.86,0.82,1.01 | 2.14 | False | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | hit@1 |
| tree_d6 | 6,0,1 | reached after stuck | 1.63 | 3.68,1.43,1.01 | 1.71 | False | 9 | 9 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.63 |
| trunks_gap_d6 | 6,0,1 | reached after stuck | 6.53 | 3.67,2.43,1.01 | 1.71 | False | 7 rej | 7 rej | 7/2 (free<0.6: 0) | 4/4 | search_fail=3 give_up=1 stop_attack=1 | stuck@1.09 rejected@1.09 search_fail@1.09 rejected@2.18 search_fail@2.18 rejected@4.26 give_up@4.26 search_fail@4.26 stop_attack@4.26 re_engage@5.35 stuck@5.89 found@5.89 hit@6.53 |

**Totals scenes:** 17 trials, reached 17, reached without a give-up 16, with a give-up 1, searches 20 (found 19), largest search 148 us.

## archer

| scene | target u,v,h | result | t hit | hit at u,v,h | min d | line0 | p6 | p12 | windows stuck/free | searches/found | fails | sequence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| flat_bush_d4 | 4,0,1 | reached after stuck | 2 | 3.47,1.99,1.01 | 1.45 | False | 9 | 9 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@2 |
| t1_bush_d5 | 5,0,2 | reached after stuck | 2 | 3.47,1.99,2.01 | 1.04 | False | 10 | 10 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@2 |
| t1_bush_d8 | 8,0,2 | reached after stuck | 3.09 | 6.47,1.99,2.01 | 1.04 | False | 13 | 13 | 1/4 (free<0.6: 1) | 1/1 | - | stuck@1.64 found@1.64 hit@3.09 |
| t1_bushtop_d6 | 6,0,2 | reached after stuck | 2.54 | 5.47,1.99,2.01 | 1.45 | False | 11 | 11 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.54 |
| t1_blue_d4 | 4,0,2 | reached after stuck | 2.27 | 3.31,0.23,3.01 | 0.73 | False | 9 | 9 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@0.54 found@0.54 leave_line@1.09 hit@2.27 |
| t1_blue_d7 | 7,0,2 | reached after stuck | 3.36 | 6.31,0.23,3.01 | 0.72 | False | 12 | 12 | 1/5 (free<0.6: 2) | 1/1 | - | stuck@1.64 found@1.64 leave_line@2.18 hit@3.36 |
| t2_open_d4 | 4,0,3 | reached after stuck | 10.36 | 2.93,2.46,3.01 | 1.59 | False | 13 | 13 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 shot@2.09x3 hit@10.36 |
| t2_bush_d5 | 5,0,3 | reached after stuck | 10.36 | 3.9,2.46,3.01 | 1.6 | False | 14 | 14 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 shot@2.18x3 hit@10.36 |
| t2_bush_d8 | 8,0,3 | reached after stuck | 10.36 | 6.91,2.46,3.01 | 1.6 | False | 17 | 17 | 1/5 (free<0.6: 1) | 1/1 | - | stuck@1.64 found@1.64 shot@3.27x3 hit@10.36 |
| t2_bush_d6_far | 6,0,3 | reached after stuck | 11.45 | 5.41,2.92,3.01 | 1.52 | False | 0 | 25 | 3/7 (free<0.6: 1) | 2/1 | search_fail=1 | stuck@1.09 no_path@1.09 search_fail@1.09 found@2.18 shot@4.73x2 hit@11.45 |
| t2_blue_d5 | 5,0,3 | reached after stuck | 10.09 | 4.32,2.77,3.01 | 1.4 | False | 14 | 14 | 1/4 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 shot@2.82x3 hit@10.09 |
| trunk_d3 | 3,0,1 | reached after stuck | 1.64 | 2.28,0.95,1.01 | 1.19 | False | 6 | 6 | 1/2 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@1.64 |
| trunk_d5 | 5,0,1 | reached after stuck | 2.18 | 4.28,0.95,1.01 | 1.19 | False | 8 | 8 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.64 found@1.64 hit@2.18 |
| trunk_d8 | 8,0,1 | reached after stuck | 2.54 | 5.55,0.9,1.01 | 1.64 | False | 11 | 11 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@2.18 found@2.18 hit@2.54 |
| trunk_off_d5 | 5,1,1 | reached | 10.91 | 3.2,0.71,1.01 | 1.44 | False | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | shot@1.36x4 hit@10.91 |
| tree_d6 | 6,0,1 | reached after stuck | 2 | 3.56,0.9,1.01 | 1.64 | False | 9 | 9 | 1/2 (free<0.6: 1) | 1/1 | - | stuck@1.64 found@1.64 hit@2 |
| trunks_gap_d6 | 6,0,1 | reached | 10.91 | 3.64,0,1.01 | 1.64 | True | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | shot@1.36x4 hit@10.91 |

**Totals scenes:** 17 trials, reached 17, reached without a give-up 17, with a give-up 0, searches 16 (found 15), largest search 162 us, trials with a seeing shot 7, blind shots 0.

## Registered dogshoot mobs

- `grug_mobs:ash_writ_bowman`: ground, pathfinding 1
- `grug_mobs:bandit_archer`: ground, pathfinding 1
- `grug_mobs:barrow_skeleton_archer`: ground, pathfinding 1
- `grug_mobs:basket_poacher_thorn`: ground, pathfinding 1
- `grug_mobs:bog_witch`: ground, pathfinding 1
- `grug_mobs:bottle_keeper_zek`: ground, pathfinding 1
- `grug_mobs:bough_counter_rusk`: ground, pathfinding 1
- `grug_mobs:brandbound_collector`: ground, pathfinding 1
- `grug_mobs:causeway_aqueduct_bowman`: ground, pathfinding 1
- `grug_mobs:causeway_toll_skeleton`: ground, pathfinding 1
- `grug_mobs:crown_frost_stray`: ground, pathfinding 1
- `grug_mobs:crown_stone_golem`: ground, pathfinding 1
- `grug_mobs:crystal_shard`: ground, pathfinding 1
- `grug_mobs:dungeon_master`: ground, pathfinding 1
- `grug_mobs:ember_wisp`: flier, pathfinding False
- `grug_mobs:entrenched_bandit_archer`: ground, pathfinding 1
- `grug_mobs:frost_stray`: ground, pathfinding 1
- `grug_mobs:furtive_poacher`: ground, pathfinding 1
- `grug_mobs:goblin_miner_slinger`: ground, pathfinding 1
- `grug_mobs:goblin_slinger`: ground, pathfinding 1
- `grug_mobs:kiln_whisper_hexer`: ground, pathfinding 1
- `grug_mobs:king_elf`: ground, pathfinding 1
- `grug_mobs:king_troll`: ground, pathfinding 1
- `grug_mobs:king_undead`: ground, pathfinding 1
- `grug_mobs:last_pay_archer`: ground, pathfinding 1
- `grug_mobs:last_watch_skeleton_raider`: ground, pathfinding 1
- `grug_mobs:march_skeleton_raider`: ground, pathfinding 1
- `grug_mobs:marrow_archivist`: ground, pathfinding 1
- `grug_mobs:mesa_golem`: ground, pathfinding 1
- `grug_mobs:misguided_poacher_chief`: ground, pathfinding 1
- `grug_mobs:ore_factor_brakk`: ground, pathfinding 1
- `grug_mobs:poacher`: ground, pathfinding 1
- `grug_mobs:powder_counter_nib`: ground, pathfinding 1
- `grug_mobs:red_receipt_marshal`: ground, pathfinding 1
- `grug_mobs:reed_hex_witch`: ground, pathfinding 1
- `grug_mobs:rift_boss`: ground, pathfinding 1
- `grug_mobs:rime_bell_warden`: ground, pathfinding 1
- `grug_mobs:rime_skeleton_stray`: ground, pathfinding 1
- `grug_mobs:rubble_goblin_slinger`: ground, pathfinding 1
- `grug_mobs:salt_counter_witch`: ground, pathfinding 1
- `grug_mobs:salt_hex_witch`: ground, pathfinding 1
- `grug_mobs:seam_mesa_golem`: ground, pathfinding 1
- `grug_mobs:seam_stone_golem`: ground, pathfinding 1
- `grug_mobs:siege_deserter_archer`: ground, pathfinding 1
- `grug_mobs:siege_goblin_slinger`: ground, pathfinding 1
- `grug_mobs:siege_skeleton_raider`: ground, pathfinding 1
- `grug_mobs:skeleton_archer`: ground, pathfinding 1
- `grug_mobs:skeleton_raider`: ground, pathfinding 1
- `grug_mobs:snarekeeper_vetch`: ground, pathfinding 1
- `grug_mobs:snarewarden_bracken`: ground, pathfinding 1
- `grug_mobs:snaring_poacher`: ground, pathfinding 1
- `grug_mobs:split_seam_warden`: ground, pathfinding 1
- `grug_mobs:standard_bearer_ninepins`: ground, pathfinding 1
- `grug_mobs:stone_golem`: ground, pathfinding 1
- `grug_mobs:storm_bottle_witch`: ground, pathfinding 1
- `grug_mobs:toll_bandit_archer`: ground, pathfinding 1
- `grug_mobs:unlicensed_poacher`: ground, pathfinding 1
- `grug_mobs:vigilant_bandit_archer`: ground, pathfinding 1
- `grug_mobs:wartrail_poacher`: ground, pathfinding 1
- `grug_mobs:watch_captain_huskell`: ground, pathfinding 1

## Scenes

- `flat_bush_d4`: control: a bush on flat ground, the target right behind it
- `t1_bush_d5`: 1-high terrace from u 4, a bush at its foot, target on top
- `t1_bush_d8`: 1-high terrace from u 7, a bush at its foot, target on top
- `t1_bushtop_d6`: 1-high terrace from u 3, a bush on its edge, target behind it
- `t1_blue_d4`: 1-high terrace from u 1, a blueberry bush on its edge, target behind
- `t1_blue_d7`: 1-high terrace from u 4, a blueberry bush on its edge, target behind
- `t2_open_d4`: control: 2-high terrace from u 3, a step up at v 4-5, no bush
- `t2_bush_d5`: 2-high terrace from u 4, step up at v 4-5, a bush at its foot
- `t2_bush_d8`: 2-high terrace from u 7, step up at v 4-5, a bush at its foot
- `t2_bush_d6_far`: 2-high terrace from u 5, the step up at v 9-10 (outside a padding-6 box), a bush at its foot
- `t2_blue_d5`: 2-high terrace from u 2, step up at v 4-5, a blueberry bush on its edge
- `trunk_d3`: a trunk at u 2, the target right behind it
- `trunk_d5`: a trunk at u 4, the target right behind it
- `trunk_d8`: a trunk at u 6, the target 2 behind it
- `trunk_off_d5`: a trunk at u 4, the target behind it one node aside
- `tree_d6`: a tree (trunk at u 4, canopy from h 4), the target 2 behind it
- `trunks_gap_d6`: two trunks at u 4, v -1 and +1 (a 1-wide gap on the line)
