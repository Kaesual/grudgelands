# Round 49 NAV probe summary

Seed 12345, navigation {"CLOSE": 16, "GIVE_UP_AFTER": 3, "LOCKOUT": 1, "PADDING": 6, "STUCK_RATIO": 0.3, "WINDOW": 0.5}, probe CPU 37.38 s.

| mover | entity | width | height | run | reach | step | attack |
|---|---|---|---|---|---|---|---|
| archer | grug_mobs:skeleton_archer | 0.6 | 1.99 | 4 | 3 | 1.100000023841858 | dogshoot |
| rat | grug_mobs:giant_rat | 1.28 | 0.97 | 4.6 | 3 | 1.100000023841858 | dogfight |
| zombie | grug_mobs:zombie | 0.6 | 1.9 | 4.6 | 3 | 1.100000023841858 | dogfight |

- batch zombie: 20.02 s, CPU 20.38 s, module counters {"cap_waits": 0, "found": 15, "largest_us": 133, "searches": 27}
- batch rat: 20.04 s, CPU 14.13 s, module counters {"cap_waits": 0, "found": 37, "largest_us": 133, "searches": 61}
- batch archer: 12.06 s, CPU 0.11 s, module counters {"cap_waits": 0, "found": 37, "largest_us": 133, "searches": 61}

## zombie

| scene | target u,v,h | result | t hit | hit at u,v,h | min d | line0 | p6 | p12 | windows stuck/free | searches/found | fails | sequence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| flat_bush_d4 | 4,0,1 | reached after stuck | 1.82 | 3.55,1.99,1.01 | 1.39 | False | 9 | 9 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.82 |
| t1_bush_d5 | 5,0,2 | reached (from below) after stuck | 1.72 | 3.11,1.99,1.01 | 1.15 | False | 10 | 10 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.72 |
| t1_bush_d8 | 8,0,2 | reached (from below) after stuck | 2.27 | 6.13,1.99,1.01 | 1.15 | False | 13 | 13 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.27 |
| t1_bushtop_d6 | 6,0,2 | reached after stuck | 2.36 | 5.55,2,2.01 | 1.39 | False | 11 | 11 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.36 |
| t1_blue_d4 | 4,0,2 | reached after stuck | 2.36 | 1.86,1.96,2.01 | 1.23 | False | 9 | 9 | 2/2 (free<0.6: 1) | 2/2 | path_stuck=1 | stuck@0.54 found@0.54 leave_stuck@1.63 path_stuck@1.63 found@1.72 hit@2.36 |
| t1_blue_d7 | 7,0,2 | reached after stuck | 2.9 | 4.86,1.96,2.01 | 1.23 | False | 12 | 12 | 2/3 (free<0.6: 1) | 2/2 | path_stuck=1 | stuck@1.09 found@1.09 leave_stuck@2.18 path_stuck@2.18 found@2.27 hit@2.9 |
| t2_open_d4 | 4,0,3 | reached (from below) | 0.99 | 2.2,0,1.01 | 1.8 | False | 13 | 13 | 0/0 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| t2_bush_d5 | 5,0,3 | reached after stuck | 2.27 | 4.83,2.67,3.01 | 1.43 | False | 14 | 14 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 leave_line@2.18 hit@2.27 |
| t2_bush_d8 | 8,0,3 | reached after stuck | 2.81 | 7.82,2.67,3.01 | 1.43 | False | 17 | 17 | 1/4 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 leave_line@2.72 hit@2.81 |
| t2_bush_d6_far | 6,0,3 | stuck -> no path -> give up |  |  | 4.8 | False | 0 | 25 | 24/1 (free<0.6: 1) | 12/0 | search_fail=12 give_up=4 stop_attack=4 | stuck@1.09 no_path@1.09 search_fail@1.09 no_path@2.18 search_fail@2.18 no_path@4.26 give_up@4.26 search_fail@4.26 stop_attack@4.26 re_engage@5.34 stuck@5.89 no_path@5.89 search_fail@5.89 no_path@6.97 search_fail@6.97 no_path@9.06 give_up@9.06 search_fail@9.06 stop_attack@9.06 re_engage@10.14 stuck@10.68 no_path@10.68 search_fail@10.68 no_path@11.77 search_fail@11.77 no_path@13.86 give_up@13.86 search_fail@13.86 stop_attack@13.86 re_engage@14.95 stuck@15.49 no_path@15.49 search_fail@15.49 no_path@16.58 search_fail@16.58 no_path@18.66 give_up@18.66 search_fail@18.66 stop_attack@18.66 re_engage@19.75 |
| t2_blue_d5 | 5,0,3 | reached after stuck | 2.63 | 3.94,2.65,3.01 | 1.18 | False | 14 | 14 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@2.63 |
| trunk_d3 | 3,0,1 | reached after stuck | 1.54 | 2.27,0.98,1.01 | 1.22 | False | 6 | 6 | 1/1 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@1.54 |
| trunk_d5 | 5,0,1 | reached after stuck | 1.54 | 4.27,0.98,1.01 | 1.22 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.54 |
| trunk_d8 | 8,0,1 | reached after stuck | 1.9 | 5.45,0.86,1.01 | 1.6 | False | 11 | 11 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.63 found@1.63 hit@1.9 |
| trunk_off_d5 | 5,1,1 | reached | 0.99 | 3.2,0.84,1.01 | 1.39 | False | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| tree_d6 | 6,0,1 | reached after stuck | 1.45 | 3.87,0.87,1.01 | 1.59 | False | 9 | 9 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.45 |
| trunks_gap_d6 | 6,0,1 | reached | 0.99 | 4.57,0,1.01 | 1.43 | True | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | hit@0.99 |

## rat

| scene | target u,v,h | result | t hit | hit at u,v,h | min d | line0 | p6 | p12 | windows stuck/free | searches/found | fails | sequence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| flat_bush_d4 | 4,0,1 | reached after stuck | 1.81 | 3.19,2.49,1.01 | 2.14 | False | 9 | 9 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.81 |
| t1_bush_d5 | 5,0,2 | reached after stuck | 1.9 | 3.6,2.49,2.01 | 1.18 | False | 10 | 10 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.9 |
| t1_bush_d8 | 8,0,2 | reached after stuck | 2.44 | 6.61,2.49,2.01 | 1.19 | False | 13 | 13 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.44 |
| t1_bushtop_d6 | 6,0,2 | reached after stuck | 2.35 | 5.2,2.49,2.01 | 2.14 | False | 11 | 11 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.35 |
| t1_blue_d4 | 4,0,2 | reached after stuck | 1.63 | 2.36,2.46,2.01 | 1.3 | False | 9 | 9 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.63 |
| t1_blue_d7 | 7,0,2 | reached after stuck | 2.17 | 5.35,2.46,2.01 | 1.29 | False | 12 | 12 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.17 |
| t2_open_d4 | 4,0,3 | reached after stuck | 2.26 | 2.76,2.29,3.01 | 1.77 | False | 13 | 13 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 leave_line@2.17 hit@2.26 |
| t2_bush_d5 | 5,0,3 | reached after stuck | 2.26 | 4.37,2.67,3.01 | 1.5 | False | 14 | 14 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 leave_line@2.17 hit@2.26 |
| t2_bush_d8 | 8,0,3 | reached after stuck | 2.62 | 6.77,2.46,3.21 | 1.5 | False | 17 | 17 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.62 |
| t2_bush_d6_far | 6,0,3 | stuck -> no path -> give up |  |  | 5.14 | False | 0 | 25 | 24/1 (free<0.6: 1) | 12/0 | search_fail=12 give_up=4 stop_attack=4 | stuck@1.09 no_path@1.09 search_fail@1.09 no_path@2.17 search_fail@2.17 no_path@4.26 give_up@4.26 search_fail@4.26 stop_attack@4.26 re_engage@5.34 stuck@5.89 no_path@5.89 search_fail@5.89 no_path@6.98 search_fail@6.98 no_path@9.07 give_up@9.07 search_fail@9.07 stop_attack@9.07 re_engage@10.06 stuck@10.61 no_path@10.61 search_fail@10.61 no_path@11.7 search_fail@11.7 no_path@13.78 give_up@13.78 search_fail@13.78 stop_attack@13.78 re_engage@14.87 stuck@15.42 no_path@15.42 search_fail@15.42 no_path@16.5 search_fail@16.5 no_path@18.59 give_up@18.59 search_fail@18.59 stop_attack@18.59 re_engage@19.68 |
| t2_blue_d5 | 5,0,3 | reached after stuck | 2.62 | 4.17,2.81,3.01 | 1.26 | False | 14 | 14 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@2.62 |
| trunk_d3 | 3,0,1 | reached after stuck | 1.63 | 1.67,1.45,1.01 | 1.55 | False | 6 | 6 | 1/2 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@1.63 |
| trunk_d5 | 5,0,1 | reached after stuck | 1.63 | 3.67,1.45,1.01 | 1.55 | False | 8 | 8 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.63 |
| trunk_d8 | 8,0,1 | reached after stuck | 2.17 | 5.67,1.43,1.01 | 1.71 | False | 11 | 11 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.63 found@1.63 hit@2.17 |
| trunk_off_d5 | 5,1,1 | reached | 0.99 | 2.86,0.82,1.01 | 2.14 | False | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| tree_d6 | 6,0,1 | reached after stuck | 1.63 | 3.67,1.43,1.01 | 1.71 | False | 9 | 9 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.63 |
| trunks_gap_d6 | 6,0,1 | reached after stuck | 6.52 | 3.68,2.43,1.01 | 1.71 | False | 7 rej | 7 rej | 7/2 (free<0.6: 0) | 4/4 | search_fail=3 give_up=1 stop_attack=1 | stuck@1.09 rejected@1.09 search_fail@1.09 rejected@2.17 search_fail@2.17 rejected@4.26 give_up@4.26 search_fail@4.26 stop_attack@4.26 re_engage@5.34 stuck@5.89 found@5.89 hit@6.52 |

## archer

| scene | target u,v,h | result | t hit | hit at u,v,h | min d | line0 | p6 | p12 | windows stuck/free | searches/found | fails | sequence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| flat_bush_d4 | 4,0,1 | never stuck |  |  | 3.8 | False | 9 | 9 | 0/0 (free<0.6: 0) | 0/0 | - |  |
| t1_bush_d5 | 5,0,2 | never stuck |  |  | 4.8 | False | 10 | 10 | 0/0 (free<0.6: 0) | 0/0 | - |  |
| t1_bush_d8 | 8,0,2 | never stuck |  |  | 4.8 | False | 13 | 13 | 0/0 (free<0.6: 0) | 0/0 | - |  |
| t1_bushtop_d6 | 6,0,2 | never stuck |  |  | 3.8 | False | 11 | 11 | 0/0 (free<0.6: 0) | 0/0 | - |  |
| t1_blue_d4 | 4,0,2 | never stuck |  |  | 3.8 | False | 9 | 9 | 0/0 (free<0.6: 0) | 0/0 | - |  |
| t1_blue_d7 | 7,0,2 | never stuck |  |  | 3.8 | False | 12 | 12 | 0/0 (free<0.6: 0) | 0/0 | - |  |
| t2_open_d4 | 4,0,3 | never stuck |  |  | 1.8 | False | 13 | 13 | 0/0 (free<0.6: 0) | 0/0 | - |  |
| t2_bush_d5 | 5,0,3 | never stuck |  |  | 4.8 | False | 14 | 14 | 0/0 (free<0.6: 0) | 0/0 | - |  |
| t2_bush_d8 | 8,0,3 | never stuck |  |  | 4.8 | False | 17 | 17 | 0/0 (free<0.6: 0) | 0/0 | - |  |
| t2_bush_d6_far | 6,0,3 | never stuck |  |  | 4.8 | False | 0 | 25 | 0/0 (free<0.6: 0) | 0/0 | - |  |
| t2_blue_d5 | 5,0,3 | never stuck |  |  | 3.8 | False | 14 | 14 | 0/0 (free<0.6: 0) | 0/0 | - |  |
| trunk_d3 | 3,0,1 | never stuck |  |  | 1.8 | False | 6 | 6 | 0/0 (free<0.6: 0) | 0/0 | - |  |
| trunk_d5 | 5,0,1 | never stuck |  |  | 1.8 | False | 8 | 8 | 0/0 (free<0.6: 0) | 0/0 | - |  |
| trunk_d8 | 8,0,1 | never stuck |  |  | 2.8 | False | 11 | 11 | 0/0 (free<0.6: 0) | 0/0 | - |  |
| trunk_off_d5 | 5,1,1 | reached | 10.97 | 3.2,0.77,1.01 | 1.45 | False | 7 | 7 | 0/0 (free<0.6: 0) | 0/0 | - | hit@10.97 |
| tree_d6 | 6,0,1 | never stuck |  |  | 2.8 | False | 9 | 9 | 0/0 (free<0.6: 0) | 0/0 | - |  |
| trunks_gap_d6 | 6,0,1 | reached | 10.97 | 3.99,0,1.01 | 1.64 | True | 7 | 7 | 0/0 (free<0.6: 0) | 0/0 | - | hit@10.97 |

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
