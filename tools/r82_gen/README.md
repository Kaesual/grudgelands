# tools/r82_gen — Round 82 world generation yardstick

Round 82 ([plan](../../docs/planning/round82-plan.md) §4 BASE) makes world
generation faster with byte-identical output as the proof. These tools hold
the proof and the time.

## The fleet compare (every wave-1 lane, the round end)

```sh
tools/r82_gen/compare.sh            # about 2.5 minutes at eight in parallel, through the queue
```

Runs the 20 seeds of `seeds.txt` through the seed fleet in digest mode with
the dense chunks (`tools/seed_fleet/seed.lua`, arguments `DIGEST_FILE dense`)
on the current tree and compares each seed's digest with `reference/<seed>.txt`
(captured at 7bb0cec0, main 0.81.0 plus the round plan). Per seed it prints
`identical` or the first item that differs, and a summary line; the exit status
is 0 only when every seed is identical. A digest holds, in this order: the
anchor roster, the tree roll-up, the world layouts (water, roads, capitals,
placement), every settlement's prepared handover, sockets and blueprint
identities, then per chunk (14 per seed, 16 for the production seed) the
written nodes with param2, the light the writer set (with every
`calc_lighting`/`update_liquids` call and the light and content it starts from) and the
waypost texts main writes into the chunk. `info` lines are not compared: the
manifest digest (a difference is printed as a note) and each chunk's coverage
counters (`info cover`: what the chunk reaches, its plan and write seconds).

On a difference the run directory is kept and printed; compare it again
without a new run with
`luajit tools/r82_gen/compare.lua tools/r82_gen/reference RUN/digests tools/r82_gen/seeds.txt`.
`compare.sh --capture` rewrites the reference: only after an output change
the user accepted (plan §2 ruling 2), as its own commit.

## The engine region (BASE and the coordinator only)

```sh
tools/r82_gen/region.sh OUT         # one measuring boot through engine_run.sh, about 2.5 minutes
```

A fresh world on seed 12345 with the probe `grug_probe_r82_region` (staged
only): the time to a ready world (the starts preparation), then the 258
chunks of `region.txt` generated one at a time (wall and CPU per chunk and in
total), then every chunk read back and hashed (nodes by name with param2,
light, metadata). `region.txt` comes from `pick_region.lua` (six 3 x 3
chunk-column patches: a coast, the highest mountain, the longest river, the
longest road, a village, a start's edge). `engine/baseline` and
`engine/repeat` are the two captures at 7bb0cec0; their region hashes agree.
Compare a later run's hashes with
`diff <(grep '^hash' engine/baseline/summary.txt) <(grep '^hash' OUT/summary.txt)`.
