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
| after | capital dur_brannoc | 120 s | 57 (28.5/min; per 30 s 32/5/10/8/2) | 230 us (d 18.0) | 57 | 98/20/0 | 53 / 36 | 485 | 0 | 0 | legs 55 (ok 41, none 14, street 6), searches 84 (7.5 ms, max 270 us), smoothing 5.7 ms, corners 338, streets read 4.7 ms |
| after | capital_steady dur_brannoc | 60 s | 11 (11.0/min; per 30 s 4/5/2) | 134 us (d 16.3) | 11 | 98/20/0 | 36 / 19 | 242 | 0 | 0 | legs 198 (ok 152, none 46, street 28), searches 297 (28.4 ms, max 498 us), smoothing 16.5 ms, corners 1190, streets read 4.7 ms |

## Census (every leg of the settlement's walkers and patrols)

- after start_village.json: 14 distinct legs (directed) through the cache in 0.2 s: walkers 9 (ok 9, no route 0), patrols 5 (ok 5, no route 0, over the streets 0); this pass 9 searches, 0.8 ms; the whole cache 15 legs, 19 searches, 1.5 ms searching (largest 204 us), 2.3 ms smoothing, 0.0 ms reading the streets, 78 corners, Lua heap +20 KiB over the pass
- after capital.json: 180 distinct legs (directed) through the cache in 13.3 s: walkers 130 (ok 93, no route 37), patrols 50 (ok 46, no route 4, over the streets 28); this pass 211 searches, 20.7 ms; the whole cache 196 legs, 295 searches, 28.2 ms searching (largest 498 us), 16.3 ms smoothing, 4.7 ms reading the streets, 1180 corners, Lua heap +277 KiB over the pass

## Street data

- before dur_brannoc: road layout 231909 bytes, module load 1484 us, deserialize 2070 us, 19 streets (2240 points) of this capital, +3297 KiB while the whole layout is held, +272 KiB after it is dropped
