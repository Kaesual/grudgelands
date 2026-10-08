# NV3 probe summary (seed 42)

| run | settlement | watched | searches | largest | nav searches | ambling/walkers/one-spot | arrivals / spots given up | patrol advances | snaps | cap waits | route cache |
|---|---|---|---|---|---|---|---|---|---|---|---|
| before | start hearthpine | 75 s | 0 (0.0/min; per 30 s 0) | 0 us (d 0.0) | 0 | 3/1/0 | 1 / 0 | 4 | 0 | 0 | - |
| before | village copperfell_village | 75 s | 0 (0.0/min; per 30 s 0) | 0 us (d 0.0) | 0 | 1/1/0 | 2 / 0 | 0 | 0 | 0 | - |
| before | capital dur_brannoc | 120 s | 32 (16.0/min; per 30 s 15/10/2/3/2) | 268 us (d 30.5) | 32 | 98/20/2 | 50 / 17 | 492 | 2 | 0 | - |
| after | start hearthpine | 75 s | 8 (6.4/min; per 30 s 2/2/4) | 160 us (d 23.8) | 8 | 3/1/0 | 2 / 0 | 4 | 0 | 0 | legs 7 (ok 7, none 0, street 0), searches 10 (0.7 ms, max 204 us), smoothing 1.3 ms, corners 41, streets read 0.0 ms |
| after | start_steady hearthpine | 30 s | 0 (0.0/min; per 30 s 0) | 0 us (d 0.0) | 0 | 3/1/0 | 0 / 0 | 0 | 0 | 0 | legs 15 (ok 15, none 0, street 0), searches 19 (1.5 ms, max 204 us), smoothing 2.3 ms, corners 78, streets read 0.0 ms |
| after | village copperfell_village | 75 s | 0 (0.0/min; per 30 s 0) | 0 us (d 0.0) | 0 | 1/1/0 | 2 / 0 | 0 | 0 | 0 | - |
| after | village_steady copperfell_village | 30 s | 0 (0.0/min; per 30 s 0) | 0 us (d 0.0) | 0 | 1/1/0 | 1 / 0 | 0 | 0 | 0 | - |
| after | capital dur_brannoc | 120 s | 73 (36.5/min; per 30 s 40/4/17/8/4) | 236 us (d 18.0) | 73 | 98/20/0 | 52 / 57 | 485 | 0 | 0 | legs 55 (ok 41, none 14, street 6), searches 83 (7.1 ms, max 258 us), smoothing 2.6 ms, corners 345, streets read 4.6 ms |
| after | capital_steady dur_brannoc | 60 s | 7 (7.0/min; per 30 s 2/5) | 121 us (d 16.3) | 7 | 98/20/0 | 34 / 44 | 242 | 0 | 0 | legs 197 (ok 151, none 46, street 28), searches 291 (27.5 ms, max 523 us), smoothing 7.8 ms, corners 1185, streets read 4.6 ms |
| after | capital_partial dur_brannoc | 90 s | 3 (2.0/min; per 30 s 1/0/2) | 54 us (d 10.8) | 3 | 13/2/0 | 4 / 5 | 93 | 0 | 0 | legs 23 (ok 14, none 6, street 4), searches 37 (3.8 ms, max 259 us), smoothing 1.6 ms, corners 139, streets read 4.9 ms |

## Census (every leg of the settlement's walkers and patrols)

- after start_village.json: 14 distinct legs (directed) through the cache in 0.2 s: walkers 9 (ok 9, no route 0), patrols 5 (ok 5, no route 0, over the streets 0); this pass 9 searches, 0.8 ms; the whole cache 15 legs, 19 searches, 1.5 ms searching (largest 204 us), 2.3 ms smoothing, 0.0 ms reading the streets, 78 corners, Lua heap +20 KiB over the pass
- after capital.json: 180 distinct legs (directed) through the cache in 12.7 s: walkers 130 (ok 93, no route 37), patrols 50 (ok 46, no route 4, over the streets 28); this pass 207 searches, 20.3 ms; the whole cache 196 legs, 290 searches, 27.4 ms searching (largest 523 us), 7.8 ms smoothing, 4.6 ms reading the streets, 1180 corners, Lua heap +291 KiB over the pass

## Street data

- before dur_brannoc: road layout 231909 bytes, module load 1484 us, deserialize 2070 us, 19 streets (2240 points) of this capital, +3297 KiB while the whole layout is held, +272 KiB after it is dropped
