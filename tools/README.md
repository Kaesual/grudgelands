# tools

Development tools; nothing here ships with the game. Each `tools/<round>_<lane>/`
folder belongs to the work package that wrote it (see AGENTS.md); the shared
entry points are below.

## Fixtures

`tools/run_fixtures.sh` runs every portable fixture (`tools/*/portable_test.lua`
and `tools/*/fixture.lua`) under LuaJIT with the repository path as its
argument, four at a time under idle scheduling, and prints one line per fixture
and a summary; it exits 1 when any fixture fails and shows the end of that
fixture's output.

```sh
tools/run_fixtures.sh                 # every fixture (about 2-3 minutes)
tools/run_fixtures.sh r30_p1 r31_c    # only these folders
JOBS=6 tools/run_fixtures.sh          # more processes at once
```

Two kinds run differently: a `fixture.lua` that returns a function runs through
the `micro.lua` beside it (`r23_full_column`, `r24_fill`), and `r30_p3` runs
through its `run.sh` (seeds 12345 and 42, two processes, a scratch world each).
A new fixture follows the same contract: it takes the repository path as
`arg[1]` and exits non-zero on failure.

## Seed fleet

`tools/seed_fleet/run.sh` builds, for the fixed seeds of
`tools/seed_fleet/seeds.txt`, the real mapgen runtime as main builds it on a
world's first start (`seed_fleet/runtime.lua`: `r7_runtime.lua` and its
`build`, up to the R7 anchor roster and every settlement's configuration) and
plans and writes five chunks per seed (a corner, a coast, a river mouth, a
capital edge, a settlement collar) through the real per-chunk path against a
fake VoxelManip. It runs eight seeds at a time under idle scheduling and
without a wall-clock limit, prints each failed seed with its error (a chunk
failure names the chunk and keeps the traceback) and a summary, and exits 1 on
any failure (AGENTS.md says when each size is required).

```sh
tools/seed_fleet/run.sh quick         # the first 100 seeds (about 4 minutes)
tools/seed_fleet/run.sh full          # every seed, about 300 (about 13 minutes)
tools/seed_fleet/run.sh quick 20      # plus 20 random seeds (printed)
```

## Other checks

- `tools/check_lua.sh <files>`: plain Lua 5.1 parser, `SETGLOBAL` list and the
  sweeps of `docs/research/luanti-lua.md` (needs ripgrep).
- `python3 tools/check_fresh_server.py`: the fresh-server source audit.
- `tools/luanti_headless.sh`: an isolated headless engine boot (never the
  personal Luanti folder; options in the script header).
- `tools/r35_t/upstream_check.sh`: whether the installed engine still
  misreads rotated selection boxes (prints `FIXED` or `BUG PRESENT`); run it
  at every engine version change with the rest of
  `docs/technical/upstream-workarounds.md`.
- `python3 tools/r36_p/render.py OUT_DIR`: renders every POI as the runtime
  builds it (isometric view, top-down plan, two other race palettes;
  `page.py` makes the review page); `tools/r36_w/render.py` and `page.py`
  the before/after pages of a decor change.
