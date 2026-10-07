# NV0 probe summary (nv0_results.json)

Seed 42, settings {"dedicated_server_step": "0.09", "mob_pathfinding_searchdistance": "24", "mob_pathfinding_stuck_path_timeout": "3.0", "mob_pathfinding_stuck_timeout": "2.0"}, A* budget 3000 us/step.

## Settlement legs (one search per distinct leg)

| settlement | mover | legs | d p50 | d max | legs > 32 | line blocked | found pad4 | found pad24 | pad4 ms total | pad4 max us | pad24 ms total | pad24 max us |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| capital | walker | 53 | 11 | 36.4 | 1 | 37 | 34 | 34 | 4.1 | 706 | 24.3 | 4186 |
| capital | patrol | 46 | 67.4 | 262.2 | 35 | 41 | 34 | 35 | 103.9 | 18531 | 203.8 | 62221 |
| start | walker | 5 | 19.1 | 22.1 | 0 | 5 | 5 | 5 | 0.3 | 92 | 0.3 | 74 |
| start | patrol | 5 | 23.8 | 50.8 | 1 | 4 | 5 | 5 | 0.8 | 421 | 0.5 | 257 |
