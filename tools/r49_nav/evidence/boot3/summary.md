# Round 49 NAV probe summary

Seed 12345, navigation {"CLOSE": 16, "GIVE_UP_AFTER": 3, "LOCKOUT": 1, "PADDING": 6, "STUCK_RATIO": 0.3, "WINDOW": 0.5}, probe CPU 28.96 s.

| mover | entity | width | height | run | reach | step | attack |
|---|---|---|---|---|---|---|---|
| rat_fix | grug_mobs:giant_rat | 1.28 | 0.97 | 4.6 | 3 | 1.100000023841858 | dogfight |
| rat_narrow | grug_mobs:giant_rat | 0.98 | 0.97 | 4.6 | 3 | 1.100000023841858 | dogfight |
| zombie_fix | grug_mobs:zombie | 0.6 | 1.9 | 4.6 | 3 | 1.100000023841858 | dogfight |

- batch zombie_fix: 20.01 s, CPU 20.31 s, module counters null
- batch rat_fix: 20.01 s, CPU 4.47 s, module counters null
- batch rat_narrow: 20.02 s, CPU 0.14 s, module counters null
- batch zombie_fix: 20 s, CPU 0.38 s, module counters null
- batch rat_fix: 20.07 s, CPU 0.29 s, module counters null
- batch rat_narrow: 20.09 s, CPU 0.41 s, module counters null

## zombie_fix

| scene | target u,v,h | result | t hit | hit at u,v,h | min d | line0 | p6 | p12 | windows stuck/free | searches/found | fails | sequence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| t1_bush_d5 | 5,0,2 | reached (from below) after stuck | 1.72 | 3.12,1.99,1.01 | 1.15 | False | 10 | 10 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.72 |
| t2_bush_d6_far | 6,0,3 | reached after stuck | 5.71 | 5.61,2.67,3.01 | 1.45 | False | 0 | 25 | 3/7 (free<0.6: 1) | 2/1 | search_fail=1 | stuck@1.09 no_path@1.09 search_fail@1.09 found@2.18 leave_line@4.35 hit@5.71 |
| trunk_d5 | 5,0,1 | reached after stuck | 1.54 | 4.27,0.98,1.01 | 1.22 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.54 |
| trunks_gap_d6 | 6,0,1 | reached | 1 | 4.59,0,1.01 | 1.41 | True | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | hit@1 |
| bushtop_d3 | 3,0,3 | reached (from below) | 1 | 1.2,0,1.01 | 1.8 | False | 0 | 0 | 0/0 (free<0.6: 0) | 0/0 | - | hit@1 |
| grove_d7 | 7,0,1 | reached after stuck | 1.9 | 4.2,0.25,1.01 | 1.56 | False | 10 | 10 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.9 |
| meadows_bush1 (bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 2.98 | 1.99,-3.28,3.01 | 0.94 | False | 10 | 10 | 2/3 (free<0.6: 2) | 2/2 | path_stuck=1 | stuck@1.08 found@1.08 leave_stuck@2.17 path_stuck@2.17 found@2.26 hit@2.98 |
| meadows_bush2 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 2.44 | 4.56,1.99,2.53 | 1.39 | False | 10 rej | 10 rej | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.08 found@1.08 hit@2.44 |
| meadows_bush3 (bush_stem, d 5, dh 1) | 5,0,2 | reached | 0.99 | 3.74,0,3.01 | 1.26 | True | 6 | 6 | 0/0 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| meadows_bush4 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 2.44 | 4.52,1.99,2.01 | 1.39 | False | 10 rej | 10 rej | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.08 found@1.08 hit@2.44 |
| meadows_bush5 (bush_stem, d 5, dh 1) | 5,0,2 | reached | 0.99 | 4.16,0,4.01 | 0.84 | True | 6 | 6 | 0/1 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| meadows_bush6 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 1.36 | 2.35,-0.17,3.01 | 1.41 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.36 |
| meadows_trunk1 (tree, d 5, dh 0) | 5,0,1 | reached after stuck | 1.54 | 4.27,0.98,1.01 | 1.22 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.08 found@1.08 hit@1.54 |
| meadows_trunk2 (aspen_tree, d 5, dh 0) | 5,0,1 | reached after stuck | 1.54 | 4.27,0.98,1.01 | 1.22 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.08 found@1.08 hit@1.54 |
| meadows_trunk3 (tree, d 5.66, dh 1) | 4,4,2 | reached | 1.08 | 3.01,1.58,2.01 | 1.78 | False | 9 | 9 | 0/2 (free<0.6: 1) | 0/0 | - | hit@1.08 |
| meadows_trunk4 (aspen_tree, d 5, dh 0) | 0,5,1 | reached after stuck | 1.54 | -0.98,4.27,1.01 | 1.22 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.08 found@1.09 hit@1.54 |
| meadows_trunk5 (tree, d 4.24, dh 0) | 3,-3,1 | reached | 0.99 | 2.2,-2.61,1.01 | 0.89 | False | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| deep_forest_trunk1 (apple_quarter, d 5, dh 0) | 0,5,1 | stuck on path -> give up |  |  | 3.8 | False | 8 rej | 8 rej | 23/1 (free<0.6: 1) | 14/14 | path_stuck=13 give_up=4 stop_attack=4 | stuck@1.08 found@1.09 leave_stuck@1.63 path_stuck@1.63 found@2.17 leave_stuck@2.71 path_stuck@2.71 found@3.26 leave_stuck@3.8 give_up@3.8 path_stuck@3.8 stop_attack@3.8 re_engage@4.89 stuck@5.43 found@5.43 leave_stuck@5.98 path_stuck@5.98 found@6.52 leave_stuck@7.06 path_stuck@7.06 found@7.6 leave_stuck@8.15 give_up@8.15 path_stuck@8.15 stop_attack@8.15 re_engage@9.23 stuck@9.78 found@9.78 leave_stuck@10.32 path_stuck@10.32 found@10.86 leave_stuck@11.4 path_stuck@11.4 found@11.95 leave_stuck@12.49 give_up@12.49 path_stuck@12.49 stop_attack@12.49 re_engage@13.58 stuck@14.13 found@14.13 leave_stuck@14.67 path_stuck@14.67 found@15.21 leave_stuck@15.75 path_stuck@15.75 found@16.29 leave_stuck@16.84 give_up@16.84 path_stuck@16.84 stop_attack@16.84 re_engage@17.92 stuck@18.46 found@18.46 leave_stuck@19.01 path_stuck@19.01 found@19.55 |
| deep_forest_trunk2 (aspen_tree, d 5, dh 0) | 0,5,1 | reached after stuck | 1.54 | -0.98,4.27,1.01 | 1.22 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.08 found@1.08 hit@1.54 |
| deep_forest_trunk3 (tree, d 5, dh 1) | 5,0,2 | reached after stuck | 1.54 | 4.2,0.98,2.01 | 1.27 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.08 found@1.08 hit@1.54 |
| deep_forest_trunk4 (tree, d 5, dh 0) | 0,5,1 | reached after stuck | 1.54 | -0.98,4.27,1.01 | 1.22 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.08 found@1.08 hit@1.54 |
| deep_forest_trunk5 (tree, d 5, dh 0) | 0,-5,1 | reached | 0.99 | 0,-4.19,2.14 | 0.81 | True | 6 | 6 | 0/1 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| deep_forest_trunk6 (tree, d 5, dh 2) | 5,0,3 | reached after stuck | 1.53 | 4.27,0.98,3.01 | 1.22 | False | 8 | 8 | 1/1 (free<0.6: 0) | 1/1 | - | stuck@1.08 found@1.08 hit@1.53 |
| pine_hills_bush1 (pine_bush_stem, d 5, dh 2) | 0,5,3 | reached (from below) after stuck | 2.44 | -1.99,4.69,1.01 | 1.39 | False | 8 | 8 | 1/3 (free<0.6: 2) | 1/1 | - | stuck@1.08 found@1.09 hit@2.44 |
| pine_hills_bush2 (bush_stem, d 5, dh 1) | 0,5,2 | reached (from below) after stuck | 2.44 | -1.8,4.61,1.01 | 1.39 | False | 8 rej | 8 rej | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@2.44 |
| pine_hills_bush3 (pine_bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 1.9 | 3.95,-0.98,3.01 | 1.44 | False | 8 | 8 | 1/2 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@1.9 |
| pine_hills_bush4 (pine_bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 2.35 | -2,-4.53,3.01 | 1.39 | False | 10 rej | 10 rej | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@2.35 |
| pine_hills_bush5 (bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 1.72 | 1.09,-2.58,4.01 | 1.39 | False | 10 | 10 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.72 |
| pine_hills_bush6 (bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 1.53 | -0.89,-2.28,3.01 | 1.19 | False | 8 | 8 | 1/1 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@1.53 |
| pine_hills_blue1 (blueberry_bush_leaves_with_berries, d 5, dh 2) | 0,5,3 | stuck -> no path -> give up |  |  | 3.8 | False | 10 rej | 10 rej | 24/1 (free<0.6: 1) | 12/12 | search_fail=12 give_up=4 stop_attack=4 | stuck@1.09 rejected@1.09 search_fail@1.09 rejected@2.17 search_fail@2.17 rejected@4.25 give_up@4.25 search_fail@4.25 stop_attack@4.25 re_engage@5.34 stuck@5.88 rejected@5.88 search_fail@5.88 rejected@6.97 search_fail@6.97 rejected@9.05 give_up@9.05 search_fail@9.05 stop_attack@9.05 re_engage@10.13 stuck@10.68 rejected@10.68 search_fail@10.68 rejected@11.77 search_fail@11.77 rejected@13.85 give_up@13.85 search_fail@13.85 stop_attack@13.85 re_engage@14.93 stuck@15.48 rejected@15.48 search_fail@15.48 rejected@16.56 search_fail@16.56 rejected@18.64 give_up@18.64 search_fail@18.64 stop_attack@18.64 re_engage@19.73 |
| pine_hills_trunk1 (tree, d 5.66, dh 0) | 4,4,1 | reached | 1.17 | 2.2,3.44,0.57 | 1.39 | False | 9 | 9 | 0/2 (free<0.6: 0) | 0/0 | - | hit@1.17 |
| pine_hills_trunk2 (pine_tree, d 5.66, dh 0) | -4,4,1 | reached | 1.17 | -2.2,3.45,2.11 | 1.39 | False | 9 | 9 | 0/2 (free<0.6: 0) | 0/0 | - | hit@1.17 |
| pine_hills_trunk3 (apple_quarter, d 5.66, dh 0) | 4,-4,1 | reached | 1.17 | 2.2,-3.44,1.01 | 1.39 | False | 9 | 9 | 0/2 (free<0.6: 0) | 0/0 | - | hit@1.17 |
| pine_hills_trunk4 (apple_quarter, d 5, dh 2) | -5,0,3 | reached (from below) after stuck | 1.81 | -4.28,-0.96,2.01 | 1.2 | False | 8 | 8 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.81 |

## rat_fix

| scene | target u,v,h | result | t hit | hit at u,v,h | min d | line0 | p6 | p12 | windows stuck/free | searches/found | fails | sequence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| t1_bush_d5 | 5,0,2 | reached after stuck | 1.9 | 3.61,2.49,2.01 | 1.19 | False | 10 | 10 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.9 |
| t2_bush_d6_far | 6,0,3 | reached after stuck | 5.53 | 5.47,2.73,3.01 | 1.53 | False | 0 | 25 | 3/7 (free<0.6: 1) | 2/1 | search_fail=1 | stuck@1.09 no_path@1.09 search_fail@1.09 found@2.17 leave_line@4.35 hit@5.53 |
| trunk_d5 | 5,0,1 | reached after stuck | 1.63 | 3.67,1.45,1.01 | 1.55 | False | 8 | 8 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.09 found@1.09 hit@1.63 |
| trunks_gap_d6 | 6,0,1 | reached after stuck | 5.98 | 3.65,2.39,1.01 | 1.72 | False | 7 rej | 7 rej | 6/2 (free<0.6: 0) | 4/4 | path_stuck=3 give_up=1 stop_attack=1 | stuck@1.09 found@1.09 leave_stuck@1.63 path_stuck@1.63 found@2.17 leave_stuck@2.72 path_stuck@2.72 found@3.26 leave_stuck@3.8 give_up@3.8 path_stuck@3.8 stop_attack@3.8 re_engage@4.89 stuck@5.44 found@5.44 hit@5.98 |
| bushtop_d3 | 3,0,3 | stuck -> no path -> give up |  |  | 2.14 | False | 0 | 0 | 24/2 (free<0.6: 2) | 12/0 | search_fail=12 give_up=4 stop_attack=4 | stuck@1.09 no_path@1.09 search_fail@1.09 no_path@2.17 search_fail@2.17 no_path@4.26 give_up@4.26 search_fail@4.26 stop_attack@4.26 re_engage@5.34 stuck@5.89 no_path@5.89 search_fail@5.89 no_path@6.98 search_fail@6.98 no_path@9.06 give_up@9.06 search_fail@9.06 stop_attack@9.06 re_engage@10.14 stuck@10.69 no_path@10.69 search_fail@10.69 no_path@11.77 search_fail@11.77 no_path@13.85 give_up@13.85 search_fail@13.85 stop_attack@13.85 re_engage@14.94 stuck@16.03 no_path@16.03 search_fail@16.03 no_path@17.11 search_fail@17.11 no_path@19.2 give_up@19.2 search_fail@19.2 stop_attack@19.2 |
| grove_d7 | 7,0,1 | stuck -> no path -> give up |  |  | 5.14 | False | 10 rej | 10 rej | 24/1 (free<0.6: 0) | 12/12 | search_fail=12 give_up=4 stop_attack=4 | stuck@1.09 rejected@1.09 search_fail@1.09 rejected@2.17 search_fail@2.17 rejected@4.26 give_up@4.26 search_fail@4.26 stop_attack@4.26 re_engage@5.34 stuck@5.89 rejected@5.89 search_fail@5.89 rejected@6.98 search_fail@6.98 rejected@9.06 give_up@9.06 search_fail@9.06 stop_attack@9.06 re_engage@10.14 stuck@10.69 rejected@10.69 search_fail@10.69 rejected@11.77 search_fail@11.77 rejected@13.85 give_up@13.85 search_fail@13.85 stop_attack@13.85 re_engage@14.94 stuck@15.48 rejected@15.48 search_fail@15.48 rejected@16.57 search_fail@16.57 rejected@18.65 give_up@18.65 search_fail@18.65 stop_attack@18.65 re_engage@19.74 |
| meadows_bush1 (bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 2.17 | 2.46,-3.35,3.01 | 1.3 | False | 10 | 10 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.08 found@1.08 hit@2.17 |
| meadows_bush2 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 2.26 | 4.31,2.27,2.01 | 2.14 | False | 10 | 10 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.08 found@1.08 hit@2.26 |
| meadows_bush3 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 1.54 | 2.48,-0.35,3.01 | 1.3 | False | 6 | 6 | 1/1 (free<0.6: 1) | 1/1 | - | stuck@1.08 found@1.08 hit@1.54 |
| meadows_bush4 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 2.44 | 4.64,1.44,2.01 | 1.49 | False | 10 | 10 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.08 found@1.08 hit@2.44 |
| meadows_bush5 (bush_stem, d 5, dh 1) | 5,0,2 | reached | 0.99 | 3.74,0,4.01 | 1.26 | True | 6 rej | 6 rej | 0/1 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| meadows_bush6 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 1.54 | 2.74,-1.49,3.01 | 1.46 | False | 8 rej | 8 rej | 1/1 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.54 |
| meadows_trunk1 (tree, d 5, dh 0) | 5,0,1 | reached after stuck | 1.63 | 3.73,1.46,1.01 | 1.51 | False | 8 rej | 8 rej | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.08 found@1.08 hit@1.63 |
| meadows_trunk2 (aspen_tree, d 5, dh 0) | 5,0,1 | reached after stuck | 1.63 | 3.67,1.45,1.01 | 1.55 | False | 8 | 8 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.08 found@1.08 hit@1.63 |
| meadows_trunk3 (tree, d 5.66, dh 1) | 4,4,2 | reached (from below) | 1.45 | 1.66,3.38,1.01 | 1.59 | False | 9 | 9 | 0/2 (free<0.6: 1) | 0/0 | - | hit@1.45 |
| meadows_trunk4 (aspen_tree, d 5, dh 0) | 0,5,1 | reached after stuck | 1.63 | -1.46,3.73,1.01 | 1.51 | False | 8 | 8 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.08 found@1.08 hit@1.63 |
| meadows_trunk5 (tree, d 4.24, dh 0) | 3,-3,1 | reached | 0.99 | 0.86,-2.51,1.01 | 2.14 | False | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| deep_forest_trunk1 (apple_quarter, d 5, dh 0) | 0,5,1 | reached after stuck | 6.87 | -2.14,2.57,1.97 | 1.44 | False | 8 rej | 8 rej | 6/3 (free<0.6: 2) | 4/4 | path_stuck=3 give_up=1 stop_attack=1 | stuck@1.08 found@1.08 leave_stuck@1.63 path_stuck@1.63 found@2.17 leave_stuck@2.71 path_stuck@2.71 found@3.25 leave_stuck@3.8 give_up@3.8 path_stuck@3.8 stop_attack@3.8 re_engage@4.88 stuck@5.42 found@5.42 hit@6.87 |
| deep_forest_trunk2 (aspen_tree, d 5, dh 0) | 0,5,1 | reached after stuck | 1.63 | -1.46,3.73,1.01 | 1.51 | False | 8 rej | 8 rej | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.08 found@1.08 hit@1.63 |
| deep_forest_trunk3 (tree, d 5, dh 1) | 5,0,2 | reached after stuck | 1.63 | 3.67,1.45,2.01 | 1.37 | False | 8 rej | 8 rej | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.08 found@1.08 hit@1.63 |
| deep_forest_trunk4 (tree, d 5, dh 0) | 0,5,1 | reached after stuck | 1.63 | -1.37,3.76,1.01 | 1.49 | False | 8 rej | 8 rej | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.08 found@1.08 hit@1.63 |
| deep_forest_trunk5 (tree, d 5, dh 0) | 0,-5,1 | reached | 0.99 | 0,-3.78,2.14 | 1.22 | True | 6 | 6 | 0/1 (free<0.6: 0) | 0/0 | - | hit@0.99 |
| deep_forest_trunk6 (tree, d 5, dh 2) | 5,0,3 | reached after stuck | 1.63 | 3.78,1.47,3.01 | 1.5 | False | 8 rej | 8 rej | 1/2 (free<0.6: 0) | 1/1 | - | stuck@1.08 found@1.08 hit@1.63 |
| pine_hills_bush1 (pine_bush_stem, d 5, dh 2) | 0,5,3 | reached (from below) after stuck | 4.43 | -2.18,4.59,1.01 | 1.63 | False | 8 | 8 | 3/5 (free<0.6: 4) | 3/3 | path_stuck=2 | stuck@1.08 found@1.08 leave_stuck@1.63 path_stuck@1.63 found@2.17 leave_stuck@3.8 path_stuck@3.8 found@3.89 hit@4.43 |
| pine_hills_bush2 (bush_stem, d 5, dh 1) | 0,5,2 | reached (from below) after stuck | 2.44 | -1.24,4.5,1.01 | 1.34 | False | 8 | 8 | 1/3 (free<0.6: 2) | 1/1 | - | stuck@1.08 found@1.08 hit@2.44 |
| pine_hills_bush3 (pine_bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 2.44 | 3.74,-1.49,3.01 | 1.12 | False | 8 | 8 | 1/3 (free<0.6: 2) | 1/1 | - | stuck@1.08 found@1.08 hit@2.44 |
| pine_hills_bush4 (pine_bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 2.35 | -2.22,-4.39,3.01 | 1.31 | False | 10 rej | 10 rej | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.08 found@1.08 hit@2.35 |
| pine_hills_bush5 (bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 1.81 | 1.26,-2.47,4.01 | 1.16 | False | 10 | 10 | 1/2 (free<0.6: 0) | 1/1 | - | stuck@0.54 found@0.54 hit@1.81 |
| pine_hills_bush6 (bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 1.81 | -1.48,-2.49,3.01 | 1.25 | False | 8 rej | 8 rej | 1/2 (free<0.6: 1) | 1/1 | - | stuck@1.08 found@1.08 hit@1.81 |
| pine_hills_blue1 (blueberry_bush_leaves_with_berries, d 5, dh 2) | 0,5,3 | stuck on path -> give up |  |  | 2.14 | False | 10 | 10 | 22/2 (free<0.6: 1) | 14/14 | path_stuck=13 give_up=4 stop_attack=4 | stuck@0.54 found@0.54 leave_stuck@2.17 path_stuck@2.17 found@2.26 leave_stuck@2.71 path_stuck@2.71 found@3.34 leave_stuck@3.8 give_up@3.8 path_stuck@3.8 stop_attack@3.8 re_engage@4.88 stuck@5.42 found@5.42 leave_stuck@5.96 path_stuck@5.96 found@6.51 leave_stuck@7.05 path_stuck@7.05 found@7.59 leave_stuck@8.13 give_up@8.13 path_stuck@8.13 stop_attack@8.13 re_engage@9.22 stuck@9.76 found@9.76 leave_stuck@10.3 path_stuck@10.3 found@10.85 leave_stuck@11.39 path_stuck@11.39 found@11.93 leave_stuck@12.47 give_up@12.47 path_stuck@12.47 stop_attack@12.47 re_engage@13.56 stuck@14.1 found@14.1 leave_stuck@14.64 path_stuck@14.64 found@15.19 leave_stuck@15.73 path_stuck@15.73 found@16.27 leave_stuck@16.81 give_up@16.81 path_stuck@16.81 stop_attack@16.81 re_engage@17.9 stuck@18.44 found@18.44 leave_stuck@18.99 path_stuck@18.99 found@19.53 |
| pine_hills_trunk1 (tree, d 5.66, dh 0) | 4,4,1 | reached | 1.17 | 1.86,3.34,1.01 | 2.14 | False | 9 rej | 9 rej | 0/2 (free<0.6: 1) | 0/0 | - | hit@1.17 |
| pine_hills_trunk2 (pine_tree, d 5.66, dh 0) | -4,4,1 | reached | 1.17 | -1.86,3.35,2.01 | 2.14 | False | 9 | 9 | 0/2 (free<0.6: 1) | 0/0 | - | hit@1.17 |
| pine_hills_trunk3 (apple_quarter, d 5.66, dh 0) | 4,-4,1 | reached | 1.17 | 1.86,-3.34,1.01 | 2.14 | False | 9 | 9 | 0/2 (free<0.6: 1) | 0/0 | - | hit@1.17 |
| pine_hills_trunk4 (apple_quarter, d 5, dh 2) | -5,0,3 | reached (from below) after stuck | 2.44 | -3.93,-1.45,2.01 | 1.41 | False | 8 | 8 | 2/2 (free<0.6: 0) | 1/1 | - | stuck@1.08 cap_wait@1.08 found@1.63 hit@2.44 |

## rat_narrow

| scene | target u,v,h | result | t hit | hit at u,v,h | min d | line0 | p6 | p12 | windows stuck/free | searches/found | fails | sequence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| t1_bush_d5 | 5,0,2 | reached after stuck | 2.26 | 3.31,2,2.01 | 1.37 | False | 10 | 10 | 2/2 (free<0.6: 0) | 2/2 | path_stuck=1 | stuck@0.54 found@0.54 leave_stuck@1.63 path_stuck@1.63 found@1.72 hit@2.26 |
| t2_bush_d6_far | 6,0,3 | stuck -> no path -> give up |  |  | 4.99 | False | 0 | 25 | 24/1 (free<0.6: 1) | 12/0 | search_fail=12 give_up=4 stop_attack=4 | stuck@1.09 no_path@1.09 search_fail@1.09 no_path@2.17 search_fail@2.17 no_path@4.26 give_up@4.26 search_fail@4.26 stop_attack@4.26 re_engage@5.34 stuck@5.89 no_path@5.89 search_fail@5.89 no_path@6.97 search_fail@6.97 no_path@9.06 give_up@9.06 search_fail@9.06 stop_attack@9.06 re_engage@10.14 stuck@10.69 no_path@10.69 search_fail@10.69 no_path@11.78 search_fail@11.78 no_path@13.86 give_up@13.86 search_fail@13.86 stop_attack@13.86 re_engage@14.95 stuck@15.49 no_path@15.49 search_fail@15.49 no_path@16.58 search_fail@16.58 no_path@18.66 give_up@18.66 search_fail@18.66 stop_attack@18.66 re_engage@19.75 |
| trunk_d5 | 5,0,1 | reached after stuck | 2.17 | 4.26,1,1.01 | 1.24 | False | 8 | 8 | 1/3 (free<0.6: 2) | 1/1 | - | stuck@1.09 found@1.09 hit@2.17 |
| trunks_gap_d6 | 6,0,1 | reached | 1 | 4.58,0,1.01 | 1.42 | True | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | hit@1 |
| bushtop_d3 | 3,0,3 | stuck -> no path -> give up |  |  | 1.99 | False | 0 | 0 | 24/2 (free<0.6: 2) | 12/0 | search_fail=12 give_up=4 stop_attack=4 | stuck@1.09 no_path@1.09 search_fail@1.09 no_path@2.17 search_fail@2.17 no_path@4.26 give_up@4.26 search_fail@4.26 stop_attack@4.26 re_engage@5.34 stuck@5.89 no_path@5.89 search_fail@5.89 no_path@6.97 search_fail@6.97 no_path@9.06 give_up@9.06 search_fail@9.06 stop_attack@9.06 re_engage@10.14 stuck@11.23 no_path@11.23 search_fail@11.23 no_path@12.32 search_fail@12.32 no_path@14.4 give_up@14.4 search_fail@14.4 stop_attack@14.4 re_engage@15.49 stuck@16.03 no_path@16.03 search_fail@16.03 no_path@17.12 search_fail@17.12 no_path@19.2 give_up@19.2 search_fail@19.2 stop_attack@19.2 |
| grove_d7 | 7,0,1 | reached after stuck | 3.08 | 4.01,0.22,1.01 | 1.74 | False | 10 | 10 | 2/3 (free<0.6: 2) | 2/2 | path_stuck=1 | stuck@1.09 found@1.09 leave_stuck@2.72 path_stuck@2.72 found@2.81 hit@3.08 |
| meadows_bush1 (bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 2.45 | 2,-3.09,3.01 | 1.07 | False | 10 | 10 | 1/3 (free<0.6: 2) | 1/1 | - | stuck@1.09 found@1.09 hit@2.45 |
| meadows_bush2 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 2.63 | 4.42,2,2.01 | 1.57 | False | 10 | 10 | 2/2 (free<0.6: 0) | 2/2 | path_stuck=1 | stuck@1.09 found@1.09 leave_stuck@2.17 path_stuck@2.17 found@2.26 hit@2.63 |
| meadows_bush3 (bush_stem, d 5, dh 1) | 5,0,2 | reached | 1 | 3.75,0,3.01 | 1.25 | True | 6 | 6 | 0/1 (free<0.6: 0) | 0/0 | - | hit@1 |
| meadows_bush4 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 2.54 | 4.51,2,2.01 | 1.64 | False | 10 | 10 | 1/3 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@2.54 |
| meadows_bush5 (bush_stem, d 5, dh 1) | 5,0,2 | reached | 1 | 3.75,0,4.01 | 1.25 | True | 6 | 6 | 0/1 (free<0.6: 0) | 0/0 | - | hit@1 |
| meadows_bush6 (bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 1.99 | 2.35,-0.18,3.01 | 1.41 | False | 8 | 8 | 1/2 (free<0.6: 2) | 1/1 | - | stuck@0.54 found@0.54 hit@1.99 |
| meadows_trunk1 (tree, d 5, dh 0) | 5,0,1 | reached after stuck | 2.17 | 4.26,1,1.01 | 1.24 | False | 8 | 8 | 1/3 (free<0.6: 2) | 1/1 | - | stuck@1.09 found@1.09 hit@2.17 |
| meadows_trunk2 (aspen_tree, d 5, dh 0) | 5,0,1 | reached after stuck | 2.17 | 4.26,1,1.01 | 1.24 | False | 8 | 8 | 1/3 (free<0.6: 2) | 1/1 | - | stuck@1.09 found@1.09 hit@2.17 |
| meadows_trunk3 (tree, d 5.66, dh 1) | 4,4,2 | reached | 1.27 | 3.21,1.41,2.01 | 1.46 | False | 9 | 9 | 0/2 (free<0.6: 1) | 0/0 | - | hit@1.27 |
| meadows_trunk4 (aspen_tree, d 5, dh 0) | 0,5,1 | reached after stuck | 2.17 | -1,4.26,1.01 | 1.24 | False | 8 | 8 | 1/3 (free<0.6: 2) | 1/1 | - | stuck@1.09 found@1.09 hit@2.17 |
| meadows_trunk5 (tree, d 4.24, dh 0) | 3,-3,1 | reached | 1 | 1.01,-2.56,1.01 | 1.57 | False | 7 | 7 | 0/1 (free<0.6: 0) | 0/0 | - | hit@1 |
| deep_forest_trunk1 (apple_quarter, d 5, dh 0) | 0,5,1 | reached after stuck | 2.26 | -1,2.68,2.01 | 1.33 | False | 8 | 8 | 1/3 (free<0.6: 3) | 1/1 | - | stuck@1.09 found@1.09 hit@2.26 |
| deep_forest_trunk2 (aspen_tree, d 5, dh 0) | 0,5,1 | reached after stuck | 2.17 | -1,4.26,1.01 | 1.24 | False | 8 | 8 | 1/3 (free<0.6: 2) | 1/1 | - | stuck@1.09 found@1.09 hit@2.17 |
| deep_forest_trunk3 (tree, d 5, dh 1) | 5,0,2 | reached after stuck | 2.17 | 4.26,1,3.01 | 1.22 | False | 8 | 8 | 1/3 (free<0.6: 2) | 1/1 | - | stuck@1.09 found@1.09 hit@2.17 |
| deep_forest_trunk4 (tree, d 5, dh 0) | 0,5,1 | reached after stuck | 2.17 | -1,4.26,1.01 | 1.24 | False | 8 | 8 | 1/3 (free<0.6: 2) | 1/1 | - | stuck@1.09 found@1.09 hit@2.17 |
| deep_forest_trunk5 (tree, d 5, dh 0) | 0,-5,1 | reached | 1 | 0,-3.79,2.13 | 1.21 | True | 6 | 6 | 0/1 (free<0.6: 0) | 0/0 | - | hit@1 |
| deep_forest_trunk6 (tree, d 5, dh 2) | 5,0,3 | reached after stuck | 2.08 | 4.26,1,3.01 | 1.24 | False | 8 | 8 | 1/2 (free<0.6: 1) | 1/1 | - | stuck@1.09 found@1.09 hit@2.08 |
| pine_hills_bush1 (pine_bush_stem, d 5, dh 2) | 0,5,3 | stuck on path -> give up |  |  | 0.99 | False | 8 | 8 | 21/3 (free<0.6: 3) | 13/13 | path_stuck=13 give_up=4 stop_attack=4 | stuck@1.09 found@1.09 leave_stuck@2.72 path_stuck@2.72 found@2.81 leave_stuck@3.26 path_stuck@3.26 found@3.89 leave_stuck@4.35 give_up@4.35 path_stuck@4.35 stop_attack@4.35 re_engage@5.43 stuck@5.98 found@5.98 leave_stuck@6.52 path_stuck@6.52 found@7.06 leave_stuck@7.61 path_stuck@7.61 found@8.16 leave_stuck@8.7 give_up@8.7 path_stuck@8.7 stop_attack@8.7 re_engage@9.78 stuck@10.32 found@10.32 leave_stuck@10.86 path_stuck@10.86 found@11.41 leave_stuck@11.95 path_stuck@11.95 found@12.49 leave_stuck@13.03 give_up@13.03 path_stuck@13.03 stop_attack@13.03 re_engage@14.12 stuck@14.66 found@14.66 leave_stuck@15.21 path_stuck@15.21 found@15.75 leave_stuck@16.29 path_stuck@16.29 found@16.83 leave_stuck@17.38 give_up@17.38 path_stuck@17.38 stop_attack@17.38 re_engage@18.46 stuck@19 found@19 leave_stuck@19.54 path_stuck@19.54 |
| pine_hills_bush2 (bush_stem, d 5, dh 1) | 0,5,2 | reached (from below) after stuck | 2.72 | -1,4.76,1.01 | 1.03 | False | 8 | 8 | 1/4 (free<0.6: 3) | 1/1 | - | stuck@1.09 found@1.09 hit@2.72 |
| pine_hills_bush3 (pine_bush_stem, d 5, dh 1) | 5,0,2 | reached after stuck | 2.63 | 4.34,-1,3.01 | 1.2 | False | 8 | 8 | 1/3 (free<0.6: 3) | 1/1 | - | stuck@1.09 found@1.09 hit@2.63 |
| pine_hills_bush4 (pine_bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 3.35 | -2,-4.68,3.01 | 1.57 | False | 10 | 10 | 1/5 (free<0.6: 5) | 1/1 | - | stuck@1.09 found@1.09 hit@3.35 |
| pine_hills_bush5 (bush_stem, d 5, dh 2) | 0,-5,3 | reached (from below) after stuck | 3.26 | -2.01,-3.26,2.01 | 1.39 | False | 10 | 10 | 2/4 (free<0.6: 4) | 2/2 | path_stuck=1 | stuck@1.09 found@1.09 leave_stuck@2.72 path_stuck@2.72 found@2.81 hit@3.26 |
| pine_hills_bush6 (bush_stem, d 5, dh 2) | 0,-5,3 | reached after stuck | 2.17 | -1,-2.26,3.01 | 1.25 | False | 8 | 8 | 1/3 (free<0.6: 3) | 1/1 | - | stuck@1.09 found@1.09 hit@2.17 |
| pine_hills_blue1 (blueberry_bush_leaves_with_berries, d 5, dh 2) | 0,5,3 | stuck on path -> give up |  |  | 1.99 | False | 10 | 10 | 21/3 (free<0.6: 2) | 13/13 | path_stuck=13 give_up=4 stop_attack=4 | stuck@1.09 found@1.09 leave_stuck@2.72 path_stuck@2.72 found@2.81 leave_stuck@3.26 path_stuck@3.26 found@3.89 leave_stuck@4.35 give_up@4.35 path_stuck@4.35 stop_attack@4.35 re_engage@5.43 stuck@5.98 found@5.98 leave_stuck@6.52 path_stuck@6.52 found@7.06 leave_stuck@7.61 path_stuck@7.61 found@8.16 leave_stuck@8.7 give_up@8.7 path_stuck@8.7 stop_attack@8.7 re_engage@9.78 stuck@10.32 found@10.32 leave_stuck@10.86 path_stuck@10.86 found@11.41 leave_stuck@11.95 path_stuck@11.95 found@12.49 leave_stuck@13.03 give_up@13.03 path_stuck@13.03 stop_attack@13.03 re_engage@14.12 stuck@14.66 found@14.66 leave_stuck@15.21 path_stuck@15.21 found@15.75 leave_stuck@16.29 path_stuck@16.29 found@16.83 leave_stuck@17.37 give_up@17.37 path_stuck@17.37 stop_attack@17.37 re_engage@18.46 stuck@19 found@19 leave_stuck@19.54 path_stuck@19.54 |
| pine_hills_trunk1 (tree, d 5.66, dh 0) | 4,4,1 | reached | 1.18 | 2.01,3.39,0.56 | 1.16 | False | 9 | 9 | 0/2 (free<0.6: 0) | 0/0 | - | hit@1.18 |
| pine_hills_trunk2 (pine_tree, d 5.66, dh 0) | -4,4,1 | reached | 1.18 | -2.01,3.39,2.01 | 1.16 | False | 9 | 9 | 0/2 (free<0.6: 0) | 0/0 | - | hit@1.18 |
| pine_hills_trunk3 (apple_quarter, d 5.66, dh 0) | 4,-4,1 | reached | 1.18 | 2.01,-3.39,1.01 | 1.57 | False | 9 | 9 | 0/2 (free<0.6: 0) | 0/0 | - | hit@1.18 |
| pine_hills_trunk4 (apple_quarter, d 5, dh 2) | -5,0,3 | reached (from below) after stuck | 2.35 | -4.09,-1,2.01 | 1.35 | False | 8 | 8 | 1/3 (free<0.6: 2) | 1/1 | - | stuck@1.09 found@1.09 hit@2.35 |

## Scenes

- `t1_bush_d5`: 1-high terrace from u 4, a bush at its foot, target on top
- `t2_bush_d6_far`: 2-high terrace from u 5, the step up at v 9-10 (outside a padding-6 box), a bush at its foot
- `trunk_d5`: a trunk at u 4, the target right behind it
- `trunks_gap_d6`: two trunks at u 4, v -1 and +1 (a 1-wide gap on the line)
- `bushtop_d3`: the target on top of a 2-high bush (u 2..4) on flat ground
- `grove_d7`: a grove: trunks at u 3 (v -4,-2,0,2,4) and u 5 (v -3,-1,1,3), target at u 7
