# WP13: Highcourt's wall ring, its fill and its trades

Evidence for [docs/research/wp13-highcourt-fill.md](../../../../docs/research/wp13-highcourt-fill.md),
taken on `main` at `19abee02` on 2026-09-15 (playtest round 3, lane 4).

| Path | What it is |
| --- | --- |
| `static.sh`, `static.txt` | parser and SETGLOBAL per changed file and tree-wide, the five plain-5.1 sweeps scoped and tree-wide, the fresh-server audit |
| `kat.sh`, `kat/kat-luajit.txt`, `kat/kat-puc51.txt` | `highcourt_kat.lua` under both interpreters, byte-identical, plus the other five WP13 fixtures |
| `plots.txt` | the 36 lots, the 16 FILL lots and the 52 plots against the terrain of both gate seeds |
| `fill-derive.txt` | `--derive-fill`: the search that produced the committed fill grids, re-run |
| `final-micro.sh`, `final-micro/` | one bounded process over every WP13 fixture, LuaJIT and PUC 5.1, inputs hashed before and after |
| `identity.sh`, `identity.txt` | the six start identities and the Highcourt core digest, neither of which this package moves |
| `highcourt/avenue-digest-<seed>.txt` | the avenue overlay's BUILT geometry digest, this package's expectation; `run_highcourt.sh` gates on it |
| `engine-<seed>/probe.txt` | the engine pass: per-mapchunk timings, the plot surface report and the socket census |
| `engine-<seed>/audit-terrain-warnings.txt` | how many `r7_settlement` `audit_terrain` warnings the load produced (0 on both seeds) |
| `engine-<seed>/error-count.txt`, `moderror-count.txt` | 0 and 0 on both seeds |
| `renders/*.png` | Highcourt as built, drawn from the map read-back; `plan*.png` is the capital plan from above |
| `renders/tsv/*.tsv` | the read-back dumps themselves, anchor-relative, the renderer's input |
| `renders.sh` | the render commands |
| `files.sha256`, `files.sha256.sh` | the frozen-byte manifest of every input and every product above |

## How to re-run it

```bash
bash tools/wp13/evidence/20260915-highcourt-fill/static.sh
bash tools/wp13/evidence/20260915-highcourt-fill/kat.sh
bash tools/wp13/evidence/20260915-highcourt-fill/identity.sh
bash tools/wp13/evidence/20260915-highcourt-fill/final-micro.sh

# the engine, both gate seeds; OUTPUT_DIR must be absolute and absent
WP13_HIGHCOURT_PORT=31312 tools/wp13/run_highcourt.sh /tmp/hc-a full 531802985935182545
WP13_HIGHCOURT_PORT=31322 tools/wp13/run_highcourt.sh /tmp/hc-b full 8675309

bash tools/wp13/evidence/20260915-highcourt-fill/renders.sh
bash tools/wp13/evidence/20260915-highcourt-fill/files.sha256.sh
```

## The headline numbers

| | |
| --- | --- |
| capital cells | **376 274** against a budget of 400 000 (311 483 before) |
| blueprints | 54 (core + 36 district plots + 16 dressings + 1 overlay) |
| sockets | **256** (191 before) — 36 `work`, 7 `vendor` one per kind, 26 spare |
| residents / idle spawn sockets | 144 / 108, against §8.3's one per five |
| fill lots | 16, all dry, skirted and roofed on **both** gate seeds |
| engine | `exit=0 errors=0 complete=1`, **zero** `audit_terrain` warnings, zero submerged columns, on both seeds (rebased onto main 3a1e90c0) |
| per-mapchunk | steady mean 0.53 s (user seed) / 0.57 s (boundary), against a 2 × 0.5 s limit |
| the six start identities | unchanged |
| Highcourt core digest | unchanged at `187f79e0…` |
