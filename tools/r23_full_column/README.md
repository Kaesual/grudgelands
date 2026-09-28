# Round 23 full-column preparation (WP48)

Receipt: [round23-full-column-preparation.md](../../docs/research/round23-full-column-preparation.md).

## Portable fixture (main correctness proof)

```sh
luajit tools/r23_full_column/micro.lua "$PWD"
```

`fixture.lua` loads the production `preparation_plan.lua`, `starts_preload.lua`
(with a fake `core`) and `wp40/air_chunks.lua`. It restores the retired r19
scheduler fixture and adds the full-column rules: reach and window from the
generate distance, flight-ceiling top, neighbourhood peaks and troughs three
tiles away (four tiles are ignored), edge clamping, start envelopes, an
independent brute-force block-reach reference over rough terrain, batch-size
independence, the scanner's bounded window memory, restart selections, the
persisted reach, and the air-chunk classifier (water level, heightmap, envelope,
content reach, fitted boxes, bounded memo).

## Bounded engine runs

`run_region.sh REGION STOP_AFTER_S [--verify] [--geo]` boots one fresh isolated
world through `tools/luanti_headless.sh` (`LC_ALL=C`, own user path, idle
scheduling) with a disposable patch from `make_patch.py`: full-world mode on,
the plan's bounds replaced by REGION, one log line per committed tile and per
generated chunk. The `r23_region` probe requests a normal shutdown from a
server step after STOP_AFTER_S or when the region is complete; the launcher's
timeout is a safety net 150 s later. A background sampler records RSS and map
DB size every 5 s. `analyze.py OUT` prints the summary offline.

- `--verify` runs the full writer on every chunk and compares the whole
  VoxelManip (content, param2, light of chunk and shell) before and after it on
  every chunk the fast path would skip.
- `--geo` ranks candidate regions (ocean share, highest terrain, a start inside).
- `ROOT=<kept dir>` boots again on a kept world (resume); `KEEP=1` keeps it.

### Final measurement run (done 2026-09-28; evidence in `evidence/final-region/`)

Run once, after Lanes B and C are merged, from the merged tree:

```sh
SEED=10536739806879207652 OUT=/tmp/r23-final \
  tools/r23_full_column/run_region.sh -3072,-1473,-2672,-1073 840
```

Region: 20 x 20 tiles (1,600 x 1,600 nodes) ranked by `--geo` under that seed:
43% water (ocean and coast), terrain up to y 427 (mountain) and the dwarf start.
At the measured 2.06 s per tile the region needs about 14 minutes; the probe stops
at 840 s or when the region is complete. `summary.txt` records: chunks per
second overall and per class (air-fast, air-full, surface, underground) with
engine and Lua milliseconds, seconds per tile, chunks per tile and the tiles'
Y ranges, map DB bytes per committed tile, peak RSS, and the extrapolated
full-world chunk count, duration and map size (8,811 tiles). Afterwards
`pgrep -f '^luanti.bin'` must be empty; the world directory is deleted unless
`KEEP=1`.
