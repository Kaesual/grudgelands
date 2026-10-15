# Round 49 NAV probe summary

Seed 12345, navigation {"CLOSE": 16, "GIVE_UP_AFTER": 3, "LOCKOUT": 1, "PADDING": 6, "PADDING_STEPS": [6, 12, 16], "STUCK_RATIO": 0.3, "WINDOW": 0.5}, probe CPU 31.09 s.

| mover | entity | width | height | run | reach | step | attack |
|---|---|---|---|---|---|---|---|
| archer | grug_mobs:skeleton_archer | 0.6 | 1.99 | 4 | 3 | 1.100000023841858 | dogshoot |
| rat | grug_mobs:giant_rat | 1.28 | 0.97 | 4.6 | 3 | 1.100000023841858 | dogfight |
| zombie | grug_mobs:zombie | 0.6 | 1.9 | 4.6 | 3 | 1.100000023841858 | dogfight |

- batch lanes_zombie: 20.02 s, CPU 20.4 s, searches 21 (found 20), largest so far 144 us
- batch lanes_rat: 20 s, CPU 6.62 s, searches 58 (found 45), largest so far 421 us
- batch lanes_archer: 12.06 s, CPU 0.15 s, searches 29 (found 21), largest so far 424 us
- batch real_zombie: 20 s, CPU 0.31 s, searches 45 (found 45), largest so far 424 us
- batch real_rat: 20.07 s, CPU 0.3 s, searches 36 (found 36), largest so far 424 us
- batch real_archer: 12.04 s, CPU 0.16 s, searches 43 (found 43), largest so far 424 us

## zombie

| scene | target u,v,h | result | t hit | hit at u,v,h | min d | line0 | p6 | p12 | windows stuck/free | searches/found | fails | sequence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| flat_bush_d4 | 4,0,1 | reached after stuck | 1.81 | 3.52,1.99,1.01 | 1.39 | False | 9 | 9 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.81 |
| t1_bush_d5 | 5,0,2 | reached (from below) after stuck | 1.72 | 3.1,1.99,1.01 | 1.17 | False | 10 | 10 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.72 |
| t1_bush_d8 | 8,0,2 | reached (from below) after stuck | 2.26 | 6.11,1.99,1.01 | 1.16 | False | 13 | 13 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.26 |
| t1_bushtop_d6 | 6,0,2 | reached after stuck | 2.35 | 5.52,1.99,2.01 | 1.39 | False | 11 | 11 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.35 |
| t1_blue_d4 | 4,0,2 | reached after stuck | 2.35 | 1.86,1.96,2.01 | 1.24 | False | 9 | 9 | 2/2 (free<0.6: 1) | 2/2 | path_stuck=1 | stuck@0.54 found@0.54 leave_stuck@1.63 path_stuck@1.63 found@1.72 hit@2.35 |
| t1_blue_d7 | 7,0,2 | reached after stuck | 2.89 | 4.86,1.96,2.01 | 1.24 | False | 12 | 12 | 2/3 (free<0.6: 1) | 2/2 | path_stuck=1 | stuck@1.09 found@1.09 leave_stuck@2.17 path_stuck@2.17 found@2.26 hit@2.89 |
| t2_open_d4 | 4,0,3 | reached (from below) | 0.99 | 2.2,0,1.01 | 1.8 | False | 13 | 13 | 0/0 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| t2_bush_d5 | 5,0,3 | reached after stuck | 2.26 | 4.82,2.67,3.01 | 1.43 | False | 14 | 14 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 leave_line@2.17 hit@2.26 |
| t2_bush_d8 | 8,0,3 | reached after stuck | 2.8 | 7.83,2.68,3.01 | 1.43 | False | 17 | 17 | 1/4 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 leave_line@2.71 hit@2.8 |
| t2_bush_d6_far | 6,0,3 | reached after stuck | 5.7 | 5.61,2.68,3.01 | 1.46 | False | 0 | 25 | 3/7 (free<0.6: 1) | 2/1 | search_fail=1 | stuck@1.09 no_path@1.09 search_fail@1.09 found@2.17 leave_line@4.34 hit@5.7 |
| t2_blue_d5 | 5,0,3 | reached after stuck | 2.62 | 3.94,2.65,3.01 | 1.19 | False | 14 | 14 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@2.62 |
| trunk_d3 | 3,0,1 | reached after stuck | 1.53 | 2.27,0.98,1.01 | 1.23 | False | 6 | 6 | 1/1 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@1.53 |
| trunk_d5 | 5,0,1 | reached after stuck | 1.53 | 4.27,0.98,1.01 | 1.23 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.53 |
| trunk_d8 | 8,0,1 | reached after stuck | 1.99 | 5.87,0.87,1.01 | 1.59 | False | 11 | 11 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.62 found@1.63 hit@1.99 |
| trunk_off_d5 | 5,1,1 | reached | 0.99 | 3.2,0.84,1.01 | 1.39 | False | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| tree_d6 | 6,0,1 | reached after stuck | 1.44 | 3.87,0.87,1.01 | 1.59 | False | 9 | 9 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.44 |
| trunks_gap_d6 | 6,0,1 | reached | 0.99 | 4.57,0,1.01 | 1.43 | True | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| trunk_d5_strafe | 5,0,1 | reached | 0.99 | 3.58,1.05,1.01 | 0.1 | False | 8 | 8 | 0/1 (free<0.6: 0) | 0/0 | stop_attack=1 | hit@0.99 stop_attack@15.12 re_engage@16.21 |
| t1_bush_d5_strafe | 5,0,2 | reached (from below) after stuck | 1.53 | 2.63,2.38,1.01 | 0.01 | False | 10 | 10 | 1/1 (free<0.6: 0) | 1/1 | stop_attack=1 | stuck@0.54 found@0.54 leave_line@1.08 hit@1.53 stop_attack@15.12 re_engage@16.21 |
| t2_bush_d5_strafe | 5,0,3 | reached (from below) after stuck | 1.53 | 2.49,3.6,2.01 | 0.03 | False | 14 | 14 | 1/1 (free<0.6: 0) | 1/1 | stop_attack=1 | stuck@0.54 found@0.54 hit@1.53 stop_attack@15.12 re_engage@16.21 |
| bushtop_d3 | 3,0,3 | reached (from below) | 0.99 | 1.2,0,1.01 | 1.8 | False | 0 | 0 | 0/0 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| bluetop_d3 | 3,0,2 | reached | 0.99 | 1.25,0,2.01 | 1.75 | True | 4 | 4 | 0/0 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| grove_d7 | 7,0,1 | reached after stuck | 1.9 | 4.2,0.25,1.01 | 1.56 | False | 10 | 10 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.08 found@1.08 hit@1.9 |
| trunk_root_d5 | 5,0,1 | reached after stuck | 1.53 | 4.27,0.98,2.01 | 1.23 | False | 10 | 10 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.08 found@1.08 hit@1.53 |
| meadows_bush1 (bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 2.99 | 1.99,-3.27,3.01 | 0.94 | False | 10 | 10 | 2/3 (free<0.6: 2) | 2/2 | path_stuck=1 | stuck@1.09 found@1.09 leave_stuck@2.17 path_stuck@2.17 found@2.26 hit@2.99 |
| meadows_bush2 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 2.35 | 4.53,1.99,2.01 | 1.39 | False | 10 | 10 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 repaired@1.09 found@1.09 hit@2.35 |
| meadows_bush3 (bush_stem, d 5, dh 1) | 5,0,2 | reached | 0.99 | 3.75,0,3.01 | 1.25 | True | 6 | 6 | 0/0 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| meadows_bush4 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 2.26 | 4.16,1.99,2.61 | 1.39 | False | 10 | 10 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 repaired@1.09 found@1.09 hit@2.26 |
| meadows_bush5 (bush_stem, d 5, dh 1) | 5,0,2 | reached | 0.99 | 4.16,0,4.01 | 0.84 | True | 6 | 6 | 0/1 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| meadows_bush6 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 1.36 | 2.35,-0.17,3.01 | 1.41 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.36 |
| meadows_trunk1 (tree, d 5, dh 0) | 5,0,1 | reached after stuck | 1.54 | 4.27,0.98,1.01 | 1.23 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.54 |
| meadows_trunk2 (aspen_tree, d 5, dh 0) | 5,0,1 | reached after stuck | 1.54 | 4.27,0.98,1.01 | 1.23 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.54 |
| meadows_trunk3 (tree, d 5.66, dh 1) | 4,4,2 | reached | 1.09 | 3.01,1.58,2.01 | 1.78 | False | 9 | 9 | 0/2 (free<0.6: 1) | 0/0 | - | hit@1.09 |
| meadows_trunk4 (aspen_tree, d 5, dh 0) | 0,5,1 | reached after stuck | 1.54 | -0.98,4.27,1.01 | 1.23 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.54 |
| meadows_trunk5 (tree, d 4.24, dh 0) | 3,-3,1 | reached | 0.99 | 2.2,-2.62,1.01 | 0.89 | False | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| deep_forest_trunk1 (apple_quarter, d 5, dh 0) | 0,5,1 | stuck on path -> give up |  |  | 3.8 | False | 8 | 8 | 23/1 (free<0.6: 1) | 14/14 | path_stuck=13 give_up=4 stop_attack=4 | stuck@1.09 repaired@1.09 found@1.09 leave_stuck@1.63 path_stuck@1.63 repaired@2.17 found@2.17 leave_stuck@2.71 path_stuck@2.71 repaired@3.26 found@3.26 leave_stuck@3.8 give_up@3.8 path_stuck@3.8 stop_attack@3.8 re_engage@4.89 stuck@5.43 repaired@5.43 found@5.43 leave_stuck@5.97 path_stuck@5.97 repaired@6.52 found@6.52 leave_stuck@7.06 path_stuck@7.06 repaired@7.6 found@7.6 leave_stuck@8.15 give_up@8.15 path_stuck@8.15 stop_attack@8.15 re_engage@9.23 stuck@9.77 repaired@9.77 found@9.77 leave_stuck@10.32 path_stuck@10.32 repaired@10.86 found@10.86 leave_stuck@11.4 path_stuck@11.4 repaired@11.95 found@11.95 leave_stuck@12.49 give_up@12.49 path_stuck@12.49 stop_attack@12.49 re_engage@13.57 stuck@14.12 repaired@14.12 found@14.12 leave_stuck@14.66 path_stuck@14.66 repaired@15.2 found@15.2 leave_stuck@15.75 path_stuck@15.75 repaired@16.29 found@16.29 leave_stuck@16.83 give_up@16.83 path_stuck@16.83 stop_attack@16.83 re_engage@17.92 stuck@18.46 repaired@18.46 found@18.46 leave_stuck@19.01 path_stuck@19.01 repaired@19.55 found@19.55 |
| deep_forest_trunk2 (aspen_tree, d 5, dh 0) | 0,5,1 | reached after stuck | 1.54 | -0.98,4.27,1.01 | 1.23 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.54 |
| deep_forest_trunk3 (tree, d 5, dh 1) | 5,0,2 | reached after stuck | 1.54 | 4.2,0.98,2.01 | 1.27 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.54 |
| deep_forest_trunk4 (tree, d 5, dh 0) | 0,5,1 | reached after stuck | 1.54 | -0.98,4.27,1.01 | 1.23 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.54 |
| deep_forest_trunk5 (tree, d 5, dh 0) | 0,-5,1 | reached | 0.99 | 0,-4.2,2.14 | 0.8 | True | 6 | 6 | 0/1 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| deep_forest_trunk6 (tree, d 5, dh 2) | 5,0,3 | reached after stuck | 1.54 | 4.27,0.98,3.01 | 1.23 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.54 |
| pine_hills_bush1 (pine_bush_stem, d 5, dh 2) | 0,5,3 | reached (from below) after stuck | 2.35 | -1.99,4.69,1.01 | 1.39 | False | 8 | 8 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 repaired@1.09 found@1.09 hit@2.35 |
| pine_hills_bush2 (bush_stem, d 5, dh 1) | 0,5,2 | reached (from below) after stuck | 2.44 | -1.8,4.61,1.01 | 1.39 | False | 8 | 8 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 repaired@1.09 found@1.09 hit@2.44 |
| pine_hills_bush3 (pine_bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 1.9 | 3.95,-0.98,3.01 | 1.44 | False | 8 | 8 | 1/2 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@1.9 |
| pine_hills_bush4 (pine_bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 2.35 | -1.99,-4.53,3.01 | 1.39 | False | 10 | 10 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 repaired@1.09 found@1.09 hit@2.35 |
| pine_hills_bush5 (bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 1.72 | 1.09,-2.59,4.01 | 1.4 | False | 10 | 10 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.72 |
| pine_hills_bush6 (bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 1.54 | -0.89,-2.28,3.01 | 1.19 | False | 8 | 8 | 1/1 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@1.54 |
| pine_hills_blue1 (blueberry_bush_leaves_with_berries, d 5, dh 2) | 0,5,3 | stuck -> no path -> give up |  |  | 3.8 | False | 10 rej | 10 rej | 24/1 (free<0.6: 1) | 12/12 | search_fail=12 give_up=4 stop_attack=4 | stuck@1.09 rejected@1.09 search_fail@1.09 rejected@2.17 search_fail@2.17 rejected@4.25 give_up@4.25 search_fail@4.25 stop_attack@4.25 re_engage@5.34 stuck@5.88 rejected@5.88 search_fail@5.88 rejected@6.97 search_fail@6.97 rejected@9.05 give_up@9.05 search_fail@9.05 stop_attack@9.05 re_engage@10.14 stuck@10.68 rejected@10.68 search_fail@10.68 rejected@11.76 search_fail@11.76 rejected@13.85 give_up@13.85 search_fail@13.85 stop_attack@13.85 re_engage@14.93 stuck@15.47 rejected@15.47 search_fail@15.47 rejected@16.56 search_fail@16.56 rejected@18.64 give_up@18.64 search_fail@18.64 stop_attack@18.64 re_engage@19.73 |
| pine_hills_trunk1 (tree, d 5.66, dh 0) | 4,4,1 | reached | 1.18 | 2.2,3.44,0.56 | 1.39 | False | 9 | 9 | 0/2 (free<0.6: 0) | 0/0 | - | hit@1.18 |
| pine_hills_trunk2 (pine_tree, d 5.66, dh 0) | -4,4,1 | reached | 1.18 | -2.2,3.45,2.11 | 1.39 | False | 9 | 9 | 0/2 (free<0.6: 0) | 0/0 | - | hit@1.18 |
| pine_hills_trunk3 (apple_quarter, d 5.66, dh 0) | 4,-4,1 | reached | 1.18 | 2.2,-3.44,1.01 | 1.39 | False | 9 | 9 | 0/2 (free<0.6: 0) | 0/0 | - | hit@1.18 |
| pine_hills_trunk4 (apple_quarter, d 5, dh 2) | -5,0,3 | reached (from below) after stuck | 1.81 | -4.28,-0.96,2.01 | 1.2 | False | 8 | 8 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.81 |

**Totals scenes:** 17 trials, reached 17, reached without a give-up 17, with a give-up 0, searches 17 (found 16), largest search 147 us.

**Totals extra:** 7 trials, reached 7, reached without a give-up 7, with a give-up 0, searches 4 (found 4), largest search 37 us.

**Totals real:** 28 trials, reached 26, reached without a give-up 26, with a give-up 2, searches 45 (found 45), largest search 80 us.

## rat

| scene | target u,v,h | result | t hit | hit at u,v,h | min d | line0 | p6 | p12 | windows stuck/free | searches/found | fails | sequence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| flat_bush_d4 | 4,0,1 | reached after stuck | 1.81 | 3.18,2.49,1.01 | 2.14 | False | 9 | 9 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.81 |
| t1_bush_d5 | 5,0,2 | reached after stuck | 1.9 | 3.6,2.49,2.01 | 1.2 | False | 10 | 10 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.9 |
| t1_bush_d8 | 8,0,2 | reached after stuck | 2.44 | 6.6,2.49,2.01 | 1.19 | False | 13 | 13 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.44 |
| t1_bushtop_d6 | 6,0,2 | reached after stuck | 2.35 | 5.19,2.49,2.01 | 2.14 | False | 11 | 11 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.35 |
| t1_blue_d4 | 4,0,2 | reached after stuck | 1.63 | 2.35,2.46,2.01 | 1.3 | False | 9 | 9 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.63 |
| t1_blue_d7 | 7,0,2 | reached after stuck | 2.17 | 5.35,2.46,2.01 | 1.29 | False | 12 | 12 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.17 |
| t2_open_d4 | 4,0,3 | reached after stuck | 2.26 | 2.75,2.3,3.01 | 1.78 | False | 13 | 13 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 leave_line@2.17 hit@2.26 |
| t2_bush_d5 | 5,0,3 | reached after stuck | 2.17 | 3.73,2.3,3.13 | 1.79 | False | 14 | 14 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@2.17 |
| t2_bush_d8 | 8,0,3 | reached after stuck | 2.8 | 7.37,2.68,3.01 | 1.51 | False | 17 | 17 | 1/4 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 leave_line@2.71 hit@2.8 |
| t2_bush_d6_far | 6,0,3 | reached after stuck | 5.52 | 5.47,2.74,3.01 | 1.54 | False | 0 | 25 | 3/7 (free<0.6: 1) | 2/1 | search_fail=1 | stuck@1.09 no_path@1.09 search_fail@1.09 found@2.17 leave_line@4.34 hit@5.52 |
| t2_blue_d5 | 5,0,3 | reached after stuck | 2.62 | 4.16,2.81,3.01 | 1.27 | False | 14 | 14 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@2.62 |
| trunk_d3 | 3,0,1 | reached after stuck | 1.63 | 1.67,1.45,1.01 | 1.55 | False | 6 | 6 | 1/2 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@1.63 |
| trunk_d5 | 5,0,1 | reached after stuck | 1.63 | 3.67,1.45,1.01 | 1.55 | False | 8 | 8 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.63 |
| trunk_d8 | 8,0,1 | reached after stuck | 2.17 | 5.67,1.43,1.01 | 1.71 | False | 11 | 11 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.63 found@1.63 hit@2.17 |
| trunk_off_d5 | 5,1,1 | reached | 1 | 2.86,0.82,1.01 | 2.14 | False | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | hit@1 |
| tree_d6 | 6,0,1 | reached after stuck | 1.63 | 3.67,1.43,1.01 | 1.72 | False | 9 | 9 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.63 |
| trunks_gap_d6 | 6,0,1 | reached after stuck | 6.51 | 3.67,2.42,1.01 | 1.72 | False | 7 rej | 7 rej | 7/2 (free<0.6: 0) | 4/4 | search_fail=3 give_up=1 stop_attack=1 | stuck@1.09 rejected@1.09 search_fail@1.09 rejected@2.17 search_fail@2.17 rejected@4.25 give_up@4.25 search_fail@4.25 stop_attack@4.25 re_engage@5.34 stuck@5.88 found@5.88 hit@6.51 |
| trunk_d5_strafe | 5,0,1 | reached after stuck | 1 | 2.86,0.99,1.01 | 0.26 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | stop_attack=1 | hit@1 stuck@4.7 found@4.7 stop_attack@15.11 re_engage@16.2 |
| t1_bush_d5_strafe | 5,0,2 | reached (from below) after stuck | 1.63 | 2.41,2.64,1.01 | 0.03 | False | 10 | 10 | 1/2 (free<0.6: 0) | 1/1 | stop_attack=1 | stuck@0.54 found@0.54 leave_line@1.09 hit@1.63 stop_attack@15.11 re_engage@16.2 |
| t2_bush_d5_strafe | 5,0,3 | reached (from below) after stuck | 1.63 | 2.22,3.39,2.01 | 0.07 | False | 14 | 14 | 1/2 (free<0.6: 0) | 1/1 | stop_attack=1 | stuck@0.54 found@0.54 hit@1.63 stop_attack@15.11 re_engage@16.2 |
| bushtop_d3 | 3,0,3 | stuck -> no path -> give up |  |  | 2.14 | False | 0 | 0 | 24/1 (free<0.6: 1) | 12/0 | search_fail=12 give_up=4 stop_attack=4 | stuck@1.09 no_path@1.09 search_fail@1.09 no_path@2.17 search_fail@2.17 no_path@4.25 give_up@4.25 search_fail@4.25 stop_attack@4.25 re_engage@5.34 stuck@5.88 no_path@5.88 search_fail@5.88 no_path@6.97 search_fail@6.97 no_path@9.05 give_up@9.05 search_fail@9.05 stop_attack@9.05 re_engage@10.13 stuck@10.68 no_path@10.68 search_fail@10.68 no_path@11.68 search_fail@11.68 no_path@13.75 give_up@13.75 search_fail@13.75 stop_attack@13.75 re_engage@14.84 stuck@15.38 no_path@15.38 search_fail@15.38 no_path@16.47 search_fail@16.47 no_path@18.55 give_up@18.55 search_fail@18.55 stop_attack@18.55 re_engage@19.64 |
| bluetop_d3 | 3,0,2 | reached | 0.99 | 1.25,0,2.01 | 1.75 | True | 4 | 4 | 0/0 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| grove_d7 | 7,0,1 | stuck -> no path -> give up |  |  | 5.14 | False | 10 rej | 10 rej | 24/1 (free<0.6: 0) | 12/12 | search_fail=12 give_up=4 stop_attack=4 | stuck@1.09 rejected@1.09 search_fail@1.09 rejected@2.17 search_fail@2.17 rejected@4.25 give_up@4.25 search_fail@4.25 stop_attack@4.25 re_engage@5.34 stuck@5.88 rejected@5.88 search_fail@5.88 rejected@6.97 search_fail@6.97 rejected@9.05 give_up@9.05 search_fail@9.05 stop_attack@9.05 re_engage@10.13 stuck@10.68 rejected@10.68 search_fail@10.68 rejected@11.68 search_fail@11.68 rejected@13.75 give_up@13.75 search_fail@13.75 stop_attack@13.75 re_engage@14.84 stuck@15.38 rejected@15.38 search_fail@15.38 rejected@16.47 search_fail@16.47 rejected@18.55 give_up@18.55 search_fail@18.55 stop_attack@18.55 re_engage@19.64 |
| trunk_root_d5 | 5,0,1 | reached after stuck | 1.63 | 3.68,1.45,2.01 | 1.37 | False | 10 | 10 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.63 |
| meadows_bush1 (bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 2.17 | 2.46,-3.36,3.01 | 1.3 | False | 10 | 10 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@2.17 |
| meadows_bush2 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 2.26 | 4.31,2.27,2.01 | 2.14 | False | 10 | 10 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@2.26 |
| meadows_bush3 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 1.54 | 2.48,-0.35,3.01 | 1.3 | False | 6 | 6 | 1/1 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@1.54 |
| meadows_bush4 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 2.44 | 4.64,1.44,2.01 | 1.49 | False | 10 | 10 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@2.44 |
| meadows_bush5 (bush_stem, d 5, dh 1) | 5,0,2 | reached | 0.99 | 3.75,0,4.01 | 1.25 | True | 6 | 6 | 0/1 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| meadows_bush6 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 1.54 | 2.74,-1.49,3.01 | 1.46 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@0.54 repaired@0.54 found@0.54 hit@1.54 |
| meadows_trunk1 (tree, d 5, dh 0) | 5,0,1 | reached after stuck | 1.63 | 3.74,1.46,1.01 | 1.51 | False | 8 rej | 8 rej | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.63 |
| meadows_trunk2 (aspen_tree, d 5, dh 0) | 5,0,1 | reached after stuck | 1.63 | 3.67,1.45,1.01 | 1.55 | False | 8 | 8 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.63 |
| meadows_trunk3 (tree, d 5.66, dh 1) | 4,4,2 | reached (from below) | 1.45 | 1.66,3.38,1.01 | 1.58 | False | 9 | 9 | 0/2 (free<0.6: 1) | 0/0 | - | hit@1.45 |
| meadows_trunk4 (aspen_tree, d 5, dh 0) | 0,5,1 | reached after stuck | 1.63 | -1.46,3.74,1.01 | 1.51 | False | 8 | 8 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.63 |
| meadows_trunk5 (tree, d 4.24, dh 0) | 3,-3,1 | reached | 0.99 | 0.86,-2.51,1.01 | 2.14 | False | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| deep_forest_trunk1 (apple_quarter, d 5, dh 0) | 0,5,1 | reached after stuck | 2.08 | -1.68,3.23,2.01 | 1.43 | False | 8 | 8 | 1/2 (free<0.6: 1) | 1/1 | - | stuck@1.08 repaired@1.08 found@1.08 hit@2.08 |
| deep_forest_trunk2 (aspen_tree, d 5, dh 0) | 0,5,1 | reached after stuck | 1.63 | -1.46,3.74,1.01 | 1.51 | False | 8 rej | 8 rej | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.08 found@1.08 hit@1.63 |
| deep_forest_trunk3 (tree, d 5, dh 1) | 5,0,2 | reached after stuck | 1.63 | 3.67,1.44,2.01 | 1.37 | False | 8 | 8 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.08 repaired@1.08 found@1.08 hit@1.63 |
| deep_forest_trunk4 (tree, d 5, dh 0) | 0,5,1 | reached after stuck | 1.63 | -1.3,3.77,1.01 | 1.79 | False | 8 | 8 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.08 repaired@1.08 found@1.08 hit@1.63 |
| deep_forest_trunk5 (tree, d 5, dh 0) | 0,-5,1 | reached | 0.99 | 0,-3.79,2.14 | 1.21 | True | 6 | 6 | 0/1 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| deep_forest_trunk6 (tree, d 5, dh 2) | 5,0,3 | reached after stuck | 1.63 | 3.78,1.47,3.01 | 1.5 | False | 8 | 8 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.08 repaired@1.08 found@1.08 hit@1.63 |
| pine_hills_bush1 (pine_bush_stem, d 5, dh 2) | 0,5,3 | reached (from below) after stuck | 4.43 | -2.18,4.59,1.01 | 1.63 | False | 8 | 8 | 3/5 (free<0.6: 4) | 3/3 | path_stuck=2 | stuck@1.08 found@1.08 leave_stuck@1.63 path_stuck@1.63 found@2.17 leave_stuck@3.8 path_stuck@3.8 found@3.89 hit@4.43 |
| pine_hills_bush2 (bush_stem, d 5, dh 1) | 0,5,2 | reached (from below) after stuck | 2.44 | -1.24,4.5,1.01 | 1.34 | False | 8 | 8 | 1/3 (free<0.6: 2) | 1/1 | - | stuck@1.08 found@1.08 hit@2.44 |
| pine_hills_bush3 (pine_bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 2.44 | 3.74,-1.49,3.01 | 1.12 | False | 8 | 8 | 1/3 (free<0.6: 2) | 1/1 | - | stuck@1.08 found@1.08 hit@2.44 |
| pine_hills_bush4 (pine_bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 2.35 | -2.24,-4.38,3.01 | 1.31 | False | 10 | 10 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.08 repaired@1.08 found@1.08 hit@2.35 |
| pine_hills_bush5 (bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 1.81 | 1.26,-2.47,4.01 | 1.16 | False | 10 | 10 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.81 |
| pine_hills_bush6 (bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 1.8 | -1.48,-2.49,3.01 | 1.25 | False | 8 | 8 | 1/2 (free<0.6: 1) | 1/1 | - | stuck@1.08 repaired@1.08 found@1.08 hit@1.8 |
| pine_hills_blue1 (blueberry_bush_leaves_with_berries, d 5, dh 2) | 0,5,3 | stuck on path -> give up |  |  | 2.14 | False | 10 | 10 | 22/2 (free<0.6: 1) | 14/14 | path_stuck=13 give_up=4 stop_attack=4 | stuck@0.54 found@0.54 leave_stuck@2.17 path_stuck@2.17 found@2.26 leave_stuck@2.71 path_stuck@2.71 found@3.34 leave_stuck@3.79 give_up@3.79 path_stuck@3.79 stop_attack@3.79 re_engage@4.88 stuck@5.42 found@5.42 leave_stuck@5.96 path_stuck@5.96 found@6.51 leave_stuck@7.05 path_stuck@7.05 found@7.59 leave_stuck@8.13 give_up@8.13 path_stuck@8.13 stop_attack@8.13 re_engage@9.22 stuck@9.76 found@9.76 leave_stuck@10.3 path_stuck@10.3 found@10.85 leave_stuck@11.39 path_stuck@11.39 found@11.93 leave_stuck@12.47 give_up@12.47 path_stuck@12.47 stop_attack@12.47 re_engage@13.56 stuck@14.1 found@14.1 leave_stuck@14.64 path_stuck@14.64 found@15.19 leave_stuck@15.73 path_stuck@15.73 found@16.27 leave_stuck@16.81 give_up@16.81 path_stuck@16.81 stop_attack@16.81 re_engage@17.9 stuck@18.44 found@18.44 leave_stuck@18.99 path_stuck@18.99 found@19.53 |
| pine_hills_trunk1 (tree, d 5.66, dh 0) | 4,4,1 | reached | 1.17 | 1.86,3.34,1.01 | 2.14 | False | 9 | 9 | 0/2 (free<0.6: 1) | 0/0 | - | hit@1.17 |
| pine_hills_trunk2 (pine_tree, d 5.66, dh 0) | -4,4,1 | reached | 1.08 | -3.53,3.53,2.04 | 0.66 | False | 9 | 9 | 0/2 (free<0.6: 0) | 0/0 | - | hit@1.08 |
| pine_hills_trunk3 (apple_quarter, d 5.66, dh 0) | 4,-4,1 | reached | 1.17 | 1.86,-3.34,1.01 | 2.14 | False | 9 | 9 | 0/2 (free<0.6: 1) | 0/0 | - | hit@1.17 |
| pine_hills_trunk4 (apple_quarter, d 5, dh 2) | -5,0,3 | reached (from below) after stuck | 2.44 | -3.93,-1.45,2.01 | 1.41 | False | 8 | 8 | 2/2 (free<0.6: 0) | 1/1 | - | stuck@1.08 cap_wait@1.08 found@1.62 hit@2.44 |

**Totals scenes:** 17 trials, reached 17, reached without a give-up 16, with a give-up 1, searches 20 (found 19), largest search 144 us.

**Totals extra:** 7 trials, reached 5, reached without a give-up 5, with a give-up 2, searches 28 (found 16), largest search 426 us.

**Totals real:** 28 trials, reached 27, reached without a give-up 27, with a give-up 1, searches 36 (found 36), largest search 72 us.

## archer

| scene | target u,v,h | result | t hit | hit at u,v,h | min d | line0 | p6 | p12 | windows stuck/free | searches/found | fails | sequence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| flat_bush_d4 | 4,0,1 | reached after stuck | 2 | 3.46,1.99,1.01 | 1.45 | False | 9 | 9 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.55 found@0.55 hit@2 |
| t1_bush_d5 | 5,0,2 | reached after stuck | 1.99 | 3.46,1.99,2.01 | 1.05 | False | 10 | 10 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.55 found@0.55 hit@1.99 |
| t1_bush_d8 | 8,0,2 | reached after stuck | 3.08 | 6.45,1.99,2.01 | 1.05 | False | 13 | 13 | 1/4 (free<0.6: 1) | 1/1 | - | stuck@1.63 found@1.63 hit@3.08 |
| t1_bushtop_d6 | 6,0,2 | reached after stuck | 2.54 | 5.45,1.99,2.01 | 1.45 | False | 11 | 11 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@2.54 |
| t1_blue_d4 | 4,0,2 | reached after stuck | 2.27 | 3.29,0.23,3.01 | 0.74 | False | 9 | 9 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@0.55 found@0.55 leave_line@1.09 hit@2.27 |
| t1_blue_d7 | 7,0,2 | reached after stuck | 3.35 | 6.3,0.23,3.01 | 0.74 | False | 12 | 12 | 1/5 (free<0.6: 2) | 1/1 | - | stuck@1.63 found@1.63 leave_line@2.18 hit@3.35 |
| t2_open_d4 | 4,0,3 | reached after stuck | 10.34 | 2.93,2.45,3.01 | 1.58 | False | 13 | 13 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 shot@2.08x4 hit@10.34 |
| t2_bush_d5 | 5,0,3 | reached after stuck | 10.34 | 3.9,2.45,3.01 | 1.59 | False | 14 | 14 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@0.55 found@0.55 shot@2.18x3 hit@10.34 |
| t2_bush_d8 | 8,0,3 | reached after stuck | 10.34 | 6.9,2.45,3.01 | 1.6 | False | 17 | 17 | 1/5 (free<0.6: 1) | 1/1 | - | stuck@1.63 found@1.63 shot@3.26x3 hit@10.34 |
| t2_bush_d6_far | 6,0,3 | reached after stuck | 11.51 | 5.47,2.8,3.01 | 1.76 | False | 0 | 25 | 3/7 (free<0.6: 1) | 2/1 | search_fail=1 | stuck@1.09 no_path@1.09 search_fail@1.09 found@2.17 shot@4.71x2 hit@11.51 |
| t2_blue_d5 | 5,0,3 | reached after stuck | 10.06 | 4.31,2.78,3.01 | 1.41 | False | 14 | 14 | 1/4 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 shot@2.99x3 hit@10.06 |
| trunk_d3 | 3,0,1 | reached after stuck | 1.63 | 2.28,0.95,1.01 | 1.19 | False | 6 | 6 | 1/2 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@1.63 |
| trunk_d5 | 5,0,1 | reached after stuck | 2.17 | 4.27,0.95,1.01 | 1.2 | False | 8 | 8 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.63 found@1.63 hit@2.17 |
| trunk_d8 | 8,0,1 | reached after stuck | 2.54 | 5.55,0.9,1.01 | 1.65 | False | 11 | 11 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@2.17 found@2.17 hit@2.54 |
| trunk_off_d5 | 5,1,1 | reached | 10.97 | 3.2,0.77,1.01 | 1.45 | False | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | shot@1.36x4 hit@10.97 |
| tree_d6 | 6,0,1 | reached after stuck | 1.99 | 3.55,0.9,1.01 | 1.65 | False | 9 | 9 | 1/2 (free<0.6: 1) | 1/1 | - | stuck@1.63 found@1.63 hit@1.99 |
| trunks_gap_d6 | 6,0,1 | reached | 10.97 | 3.99,0,1.01 | 1.65 | True | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | shot@1.36x4 hit@10.97 |
| trunk_d5_strafe | 5,0,1 | reached | 3.62 | 3.2,-0.45,1.01 | 0.07 | False | 8 | 8 | 0/1 (free<0.6: 0) | 0/0 | - | shot@1.36 hit@3.62 |
| t1_bush_d5_strafe | 5,0,2 | reached after stuck | 5.89 | 3.49,1.99,2.01 | 0.15 | False | 10 | 10 | 2/2 (free<0.6: 1) | 2/2 | - | stuck@0.55 found@0.55 shot@1.36 stuck@3.08 found@3.08 shot@4.26 hit@5.89 |
| t2_bush_d5_strafe | 5,0,3 | reached (from below) after stuck | 1.72 | 2.61,3.7,2.25 | 0.03 | False | 14 | 14 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.55 found@0.55 hit@1.72 |
| bushtop_d3 | 3,0,3 | stuck -> no path -> give up |  |  | 1.8 | False | 0 | 0 | 14/2 (free<0.6: 2) | 7/0 | search_fail=7 give_up=2 stop_attack=2 | stuck@1.09 no_path@1.09 search_fail@1.09 no_path@2.17 search_fail@2.17 no_path@4.26 give_up@4.26 search_fail@4.26 stop_attack@4.26 re_engage@5.34 stuck@5.89 no_path@5.89 search_fail@5.89 no_path@6.98 search_fail@6.98 no_path@9.07 give_up@9.07 search_fail@9.07 stop_attack@9.07 re_engage@10.15 stuck@11.24 no_path@11.24 search_fail@11.24 |
| bluetop_d3 | 3,0,2 | reached | 10.97 | 1.45,0,2.01 | 1.55 | True | 4 | 4 | 0/0 (free<0.6: 0) | 0/0 | - | shot@1.36x4 hit@10.97 |
| grove_d7 | 7,0,1 | reached after stuck | 11.33 | 4.2,0.31,1.01 | 2.08 | False | 10 | 10 | 2/2 (free<0.6: 0) | 2/2 | - | stuck@1.09 found@1.09 shot@1.36x4 stuck@10.52 found@10.52 hit@11.33 |
| trunk_root_d5 | 5,0,1 | reached after stuck | 2.17 | 4.27,0.95,2.01 | 1.2 | False | 10 | 10 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.63 found@1.63 hit@2.17 |
| meadows_bush1 (bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 2.27 | 1.98,-3.37,3.01 | 1.48 | False | 10 | 10 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@2.27 |
| meadows_bush2 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 2.54 | 4.45,1.99,2.01 | 1.45 | False | 10 | 10 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 repaired@1.09 found@1.09 hit@2.54 |
| meadows_bush3 (bush_stem, d 5, dh 1) | 5,0,2 | reached | 1 | 3.63,0,3.01 | 1.37 | True | 6 | 6 | 0/1 (free<0.6: 0) | 0/0 | - | hit@1 |
| meadows_bush4 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 2.81 | 4.47,1.8,2.01 | 1.45 | False | 10 | 10 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 repaired@1.09 found@1.09 hit@2.81 |
| meadows_bush5 (bush_stem, d 5, dh 1) | 5,0,2 | reached | 1.09 | 4.35,0,4.01 | 0.08 | True | 6 | 6 | 0/2 (free<0.6: 0) | 0/0 | - | hit@1.09 |
| meadows_bush6 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 2.54 | 2.25,-0.26,3.01 | 1.31 | False | 8 | 8 | 3/1 (free<0.6: 0) | 2/2 | path_stuck=1 | stuck@0.54 found@0.54 leave_stuck@1.09 path_stuck@1.09 found@1.63 hit@2.54 |
| meadows_trunk1 (tree, d 5, dh 0) | 5,0,1 | reached after stuck | 2.18 | 4.28,0.95,1.01 | 1.19 | False | 8 | 8 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.63 found@1.63 hit@2.18 |
| meadows_trunk2 (aspen_tree, d 5, dh 0) | 5,0,1 | reached after stuck | 2.18 | 4.28,0.95,1.01 | 1.19 | False | 8 | 8 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.63 found@1.63 hit@2.18 |
| meadows_trunk3 (tree, d 5.66, dh 1) | 4,4,2 | reached | 10.33 | 3.03,1.54,2.01 | 1.56 | False | 9 | 9 | 0/1 (free<0.6: 0) | 0/0 | - | shot@1.36x4 hit@10.33 |
| meadows_trunk4 (aspen_tree, d 5, dh 0) | 0,5,1 | reached after stuck | 2.18 | -0.95,4.28,1.01 | 1.19 | False | 8 | 8 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.63 found@1.63 hit@2.18 |
| meadows_trunk5 (tree, d 4.24, dh 0) | 3,-3,1 | reached | 1 | 1.2,-2.44,1.01 | 1.45 | False | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | hit@1 |
| deep_forest_trunk1 (apple_quarter, d 5, dh 0) | 0,5,1 | stuck on path -> give up |  |  | 3.8 | False | 8 | 8 | 15/1 (free<0.6: 1) | 9/9 | path_stuck=8 give_up=2 stop_attack=2 | stuck@1.09 repaired@1.09 found@1.09 leave_stuck@1.63 path_stuck@1.63 repaired@2.18 found@2.18 leave_stuck@2.72 path_stuck@2.72 repaired@3.26 found@3.26 leave_stuck@3.81 give_up@3.81 path_stuck@3.81 stop_attack@3.81 re_engage@4.9 stuck@5.44 repaired@5.44 found@5.44 leave_stuck@5.98 path_stuck@5.98 repaired@6.53 found@6.53 leave_stuck@7.07 path_stuck@7.07 repaired@7.61 found@7.61 leave_stuck@8.16 give_up@8.16 path_stuck@8.16 stop_attack@8.16 re_engage@9.24 stuck@9.78 repaired@9.78 found@9.78 leave_stuck@10.33 path_stuck@10.33 repaired@10.87 found@10.87 leave_stuck@11.41 path_stuck@11.41 repaired@11.95 found@11.95 |
| deep_forest_trunk2 (aspen_tree, d 5, dh 0) | 0,5,1 | reached after stuck | 2.18 | -0.95,4.28,1.01 | 1.19 | False | 8 | 8 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.63 found@1.63 hit@2.18 |
| deep_forest_trunk3 (tree, d 5, dh 1) | 5,0,2 | stuck on path -> give up |  |  | 0.8 | False | 8 | 8 | 13/3 (free<0.6: 1) | 8/8 | path_stuck=8 give_up=2 stop_attack=2 | stuck@1.63 found@1.63 leave_stuck@2.72 path_stuck@2.72 found@2.81 leave_stuck@3.26 path_stuck@3.26 found@3.9 leave_stuck@4.35 give_up@4.35 path_stuck@4.35 stop_attack@4.35 re_engage@5.44 stuck@5.98 found@5.98 leave_stuck@6.53 path_stuck@6.53 found@7.07 leave_stuck@7.61 path_stuck@7.61 found@8.16 leave_stuck@8.7 give_up@8.7 path_stuck@8.7 stop_attack@8.7 re_engage@9.78 stuck@10.33 found@10.33 leave_stuck@10.87 path_stuck@10.87 found@11.41 leave_stuck@11.95 path_stuck@11.95 |
| deep_forest_trunk4 (tree, d 5, dh 0) | 0,5,1 | reached after stuck | 2.18 | -0.95,4.28,1.01 | 1.19 | False | 8 | 8 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.63 found@1.63 hit@2.18 |
| deep_forest_trunk5 (tree, d 5, dh 0) | 0,-5,1 | reached | 1 | 0,-4.02,2.01 | 0.98 | True | 6 | 6 | 0/1 (free<0.6: 0) | 0/0 | - | hit@1 |
| deep_forest_trunk6 (tree, d 5, dh 2) | 5,0,3 | reached after stuck | 2.18 | 4.28,0.95,3.01 | 1.19 | False | 8 | 8 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.63 found@1.63 hit@2.18 |
| pine_hills_bush1 (pine_bush_stem, d 5, dh 2) | 0,5,3 | reached (from below) after stuck | 2.45 | -1.99,4.37,1.01 | 1.45 | False | 8 | 8 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 repaired@1.09 found@1.09 hit@2.45 |
| pine_hills_bush2 (bush_stem, d 5, dh 1) | 0,5,2 | reached (from below) after stuck | 2.81 | -1.8,4.43,1.09 | 1.45 | False | 8 | 8 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 repaired@1.09 found@1.09 hit@2.81 |
| pine_hills_bush3 (pine_bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 2.09 | 4.09,-0.97,3.01 | 1.33 | False | 8 | 8 | 1/2 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@2.09 |
| pine_hills_bush4 (pine_bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 2.54 | -1.99,-4.45,3.01 | 1.45 | False | 10 | 10 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 repaired@1.09 found@1.09 hit@2.54 |
| pine_hills_bush5 (bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 2.36 | 1.01,-4.48,4.01 | 1.14 | False | 10 | 10 | 1/3 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@2.36 |
| pine_hills_bush6 (bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 2.27 | -0.2,-4.27,4.01 | 0.76 | False | 8 | 8 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 leave_line@2.18 hit@2.27 |
| pine_hills_blue1 (blueberry_bush_leaves_with_berries, d 5, dh 2) | 0,5,3 | stuck -> no path -> give up |  |  | 3.8 | False | 10 rej | 10 rej | 15/1 (free<0.6: 1) | 8/8 | search_fail=8 give_up=2 stop_attack=2 | stuck@1.09 rejected@1.09 search_fail@1.09 rejected@2.18 search_fail@2.18 rejected@4.26 give_up@4.26 search_fail@4.26 stop_attack@4.26 re_engage@5.35 stuck@5.89 rejected@5.89 search_fail@5.89 rejected@6.98 search_fail@6.98 rejected@9.06 give_up@9.06 search_fail@9.06 stop_attack@9.06 re_engage@10.14 stuck@10.69 rejected@10.69 search_fail@10.69 rejected@11.77 search_fail@11.77 |
| pine_hills_trunk1 (tree, d 5.66, dh 0) | 4,4,1 | reached (from below) | 1.54 | 2.2,3.44,0.03 | 1.45 | False | 9 | 9 | 0/2 (free<0.6: 0) | 0/0 | - | hit@1.54 |
| pine_hills_trunk2 (pine_tree, d 5.66, dh 0) | -4,4,1 | reached | 2.08 | -3.28,3.93,2.01 | 0.72 | False | 9 | 9 | 0/3 (free<0.6: 1) | 0/0 | - | hit@2.08 |
| pine_hills_trunk3 (apple_quarter, d 5.66, dh 0) | 4,-4,1 | reached | 1.36 | 2.2,-3.45,1.01 | 1.45 | False | 9 | 9 | 0/2 (free<0.6: 0) | 0/0 | - | hit@1.36 |
| pine_hills_trunk4 (apple_quarter, d 5, dh 2) | -5,0,3 | reached (from below) after stuck | 1.99 | -4.73,-0.99,2.01 | 1.03 | False | 8 | 8 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.99 |

**Totals scenes:** 17 trials, reached 17, reached without a give-up 17, with a give-up 0, searches 16 (found 15), largest search 170 us, trials with a seeing shot 7, blind shots 0.

**Totals extra:** 7 trials, reached 6, reached without a give-up 6, with a give-up 1, searches 13 (found 6), largest search 430 us, trials with a seeing shot 4, blind shots 0.

**Totals real:** 28 trials, reached 25, reached without a give-up 25, with a give-up 3, searches 43 (found 43), largest search 67 us, trials with a seeing shot 1, blind shots 0.

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
- `trunk_d5_strafe`: a trunk at u 4, the target behind it strafing v -2..2 every 6 s
- `t1_bush_d5_strafe`: as t1_bush_d5, the target strafing v -3..3 every 6 s
- `t2_bush_d5_strafe`: as t2_bush_d5, the target strafing v -3..3 every 6 s
- `bushtop_d3`: the target on top of a 2-high bush (u 2..4) on flat ground
- `bluetop_d3`: the target on top of a blueberry bush (u 2..4) on flat ground
- `grove_d7`: a grove: trunks at u 3 (v -4,-2,0,2,4) and u 5 (v -3,-1,1,3), target at u 7
- `trunk_root_d5`: a trunk at u 4 with 1-high stubs (roots) at u 3 and v +-1 round it
