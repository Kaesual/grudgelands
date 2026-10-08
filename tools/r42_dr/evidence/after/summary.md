# DR evidence (Round 42 lane DR)

Capital: `OBS=120 STEADY=60 tools/r42_nv3/run.sh OUT dr capital` (seed 42). Scenes: `NV0_SCENES=door_closed,door_open NV0_MOVERS=villager,post_guard,royal_guard tools/r42_nv0/run.sh OUT dr scenes` (seed 12345). Before: NV3's `tools/r42_nv3/evidence/after/capital.json`, the villager in NV3's and the post and royal guard in NV2's `evidence/after/scenes.json`.


| run | settlement | watched | searches | largest | nav searches | ambling/walkers/one-spot | arrivals / spots given up | patrol advances | snaps | cap waits | route cache |
|---|---|---|---|---|---|---|---|---|---|---|---|
| before (NV3) | capital dur_brannoc | 120 s | 73 (36.5/min; per 30 s 40/4/17/8/4) | 236 us (d 18.0) | 73 | 98/20/0 | 52 / 57 | 485 | 0 | 0 | legs 55 (ok 41, none 14, street 6), searches 83 (7.1 ms, max 258 us), smoothing 2.6 ms, corners 345, streets read 4.6 ms |
| before (NV3) | capital_steady dur_brannoc | 60 s | 7 (7.0/min; per 30 s 2/5) | 121 us (d 16.3) | 7 | 98/20/0 | 34 / 44 | 242 | 0 | 0 | legs 197 (ok 151, none 46, street 28), searches 291 (27.5 ms, max 523 us), smoothing 7.8 ms, corners 1185, streets read 4.6 ms |
| after (DR) | capital dur_brannoc | 120 s | 185 (92.5/min; per 30 s 99/38/18/18/12) | 526 us (d 22.6) | 185 | 98/20/0 | 45 / 4 | 485 | 0 | 0 | legs 59 (ok 58, none 1, street 5), searches 203 (19.0 ms, max 532 us), smoothing 8.0 ms, corners 521, streets read 4.8 ms |
| after (DR) | capital_steady dur_brannoc | 60 s | 3 (3.0/min; per 30 s 1/2) | 122 us (d 16.3) | 3 | 98/20/0 | 38 / 2 | 242 | 0 | 0 | legs 201 (ok 190, none 11, street 28), searches 611 (54.2 ms, max 667 us), smoothing 24.4 ms, corners 1658, streets read 4.8 ms |

## Census (every leg of the settlement's walkers and patrols)

- before (NV3): 180 distinct legs (directed) through the cache in 12.7 s: walkers 130 (ok 93, no route 37), patrols 50 (ok 46, no route 4, over the streets 28); this pass 207 searches, 20.3 ms; the whole cache 196 legs, 290 searches, 27.4 ms searching (largest 523 us), 7.8 ms smoothing, 4.6 ms reading the streets, 1180 corners, Lua heap +291 KiB over the pass
- after (DR): 180 distinct legs (directed) through the cache in 34.4 s: walkers 130 (ok 120, no route 10), patrols 50 (ok 49, no route 1, over the streets 28); this pass 406 searches, 35.1 ms; the whole cache 199 legs, 609 searches, 54.0 ms searching (largest 667 us), 24.4 ms smoothing, 4.8 ms reading the streets, 1652 corners, Lua heap +483 KiB over the pass

## NPC door use (capital)

- LIVE doors: NPCs opened 19, closed 19; open before 1, after 1 of 62
- LIVE open door (-1820,69,-1413): grug_mobs:villager_dwarf d 1.1 holds -1820,69,-1413; grug_core:tag_carrier d 1.1; grug_mobs:villager_dwarf d 1.1; grug_core:tag_carrier d 1.1
- LIVE doors: NPCs opened 8, closed 8; open before 1, after 1 of 62
- LIVE open door (-1700,73,-1569): grug_core:tag_carrier d 0.9; grug_mobs:villager_dwarf d 0.9 holds -1700,73,-1569 heads -1700,73,-1569

## NV0 door scenes (before → after)

| mover | scene | reached | t goal s | searches | largest us | door open at the end |
|---|---|---|---|---|---|---|
| villager | door_closed | no → walk | – → 13.6 | 3 → 1 | 79 → 68 | – → no |
| villager | door_open | walk → walk | 18.9 → 14.5 | 0 → 0 | 0 → 0 | – → yes (found open) |
| post guard | door_closed | no → walk | – → 17.1 | 5 → 1 | 64 → 86 | – → no |
| post guard | door_open | walk → walk | 15.5 → 19.8 | 0 → 0 | 0 → 0 | – → yes (found open) |
| royal guard | door_closed | snap → snap | 27.6 → 27.5 | 4 → 4 | 68 → 121 | – → no |
| royal guard | door_open | snap → snap | 27.6 → 27.5 | 4 → 4 | 51 → 65 | – → yes |

## Fix round (review L1-L3), same probe and seed (`capital_fix.json`)

- Census: walkers 130 (ok 120, none 10), patrols 50 (ok 49, none 1); whole cache 558 searches (was 611), 51.8 ms (was 54.0), largest 612 us; smoothing 12.0 ms.
- Live 120 s: 166 searches (83/min, was 92.5), largest 534 us; NPC doors opened 17, closed 18. Steady 60 s: 7 searches, opened 11, closed 11; the two doors open at the end are held by walkers still in their doorway.
- Door finding (`npc_doors.near`, 41 x 9 x 41 `find_nodes_in_area` plus the door test per door found): 106 calls over the whole run, 10.1 ms in total, largest single call 316 us.
