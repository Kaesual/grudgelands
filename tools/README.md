# tools

Development tools; nothing here ships with the game. Each `tools/r<NN>_<lane>/`
folder belongs to the round lane (or older work package) that wrote it; the
shared entry points are below and the per-round folders at the end
("Lane folders"). Which checks a lane or a round end must run:
[round workflow](../docs/process/round-workflow.md#3-gates).

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
fake VoxelManip, about 25 s per seed. It runs eight seeds at a time under idle
scheduling and without a wall-clock limit, prints each failed seed with its
error (a chunk failure names the chunk and keeps the traceback) and a summary,
and exits 1 on any failure. A seed may name further chunks of its own in
`seed_fleet/chunks.txt` (Round 41: the production crash chunks), written
after its sample. The
[round workflow](../docs/process/round-workflow.md#3-gates) says when each
size is required.

```sh
tools/seed_fleet/run.sh quick         # the first 100 seeds (about 6 minutes at 6-8 parallel)
tools/seed_fleet/run.sh full          # every seed, about 300 (about 17 minutes)
tools/seed_fleet/run.sh quick 20      # plus 20 random seeds (printed)
RESULTS=/tmp/r.tsv tools/seed_fleet/run.sh quick   # also every seed's result line
```

## Other checks

- `tools/check_lua.sh <files>`: plain Lua 5.1 parser, `SETGLOBAL` list and the
  sweeps of [docs/technical/luanti-lua.md](../docs/technical/luanti-lua.md)
  (needs ripgrep).
- `python3 tools/check_fresh_server.py`: the source audit of the removed
  development-era compatibility mechanisms (release mode allows `register_alias`
  for a renamed item; migration markers only in grug_core's runner); since
  Round 44 also that `grug_map/baked_art.lua` is
  current with `grug_map/art/` (`tools/r44_mb/gen_baked_art.py --check`)
  and the generator's PNG decoder self-test (`--self-test`).
- `python3 tools/check_upgrade.py`: the upgrade declaration
  (`web_data/upgrade.json`, schema 3) against the last pushed commit, the
  game's step registry (`grug_core/migrations.lua`) against its `migrate`
  list and the declared step files, after its own self-test (`--self-test`
  alone; [upgrade contract](../docs/technical/upgrade-contract.md)).
- `tools/luanti_headless.sh`: an isolated headless engine boot (never the
  personal Luanti folder; options in the script header). Its world.mt names
  no `mod_storage_backend`, so its worlds keep mod storage in files.
- `python3 tools/migrate.py --world <dir> [--check]`: the world-migration
  tool ([below](#the-migration-tool)).
- `tools/r35_t/upstream_check.sh`: whether the installed engine still
  misreads rotated selection boxes (prints `FIXED` or `BUG PRESENT`); run it
  at every engine version change with the rest of
  `docs/technical/upstream-workarounds.md`.
- `python3 tools/r36_p/render.py OUT_DIR`: renders every POI as the runtime
  builds it (isometric view, top-down plan, two other race palettes;
  `page.py` makes the review page); `tools/r36_w/render.py` and `page.py`
  the before/after pages of a decor change.

## The migration tool

`tools/migrate.py` (code in `tools/migration/`) migrates a **stopped** world
to the version of the checkout it runs from (`game.conf`): every step of the
declaration's `migrate` list (`tools/web_data/upgrade.json`) above the
world's version, in ascending order, each in one write transaction per
database backend; the world version (`grug_core` mod storage
`world_version`) is written with each step. Run it from the repository root
of a full checkout; Python 3.13 or newer, and for a PostgreSQL world
psycopg 3 (`tools/migration/requirements.txt`; Debian: `python3-psycopg`).
The tool cannot detect a running server (Luanti holds no lasting SQLite lock,
PostgreSQL has none): stop the server and back the world up first (its
directory and, for PostgreSQL, its databases).

```
python3 tools/migrate.py --world <dir>                       # migrate
python3 tools/migrate.py --world <dir> --check               # report, change nothing
python3 tools/migrate.py --world <dir> --map-reset           # pre-reset pass, then migrate
python3 tools/migrate.py --world <dir> --check --map-reset   # the pass's dry run
```

`--check` reports the world version and the due steps and proves write
access: on every backend a real write under the write lock (SQLite `BEGIN
IMMEDIATE`, PostgreSQL at most 5 s for a row lock), rolled back.

`--map-reset` (since 0.50.0) is the **pre-reset pass**, run before the map
is emptied ([upgrade contract §3.5](../docs/technical/upgrade-contract.md#35-the-pre-reset-pass)):
it reads the map (world.mt's `backend`, a missing key meaning `sqlite3`,
and `pgsql_connection`; `map.sqlite` opened read-only, PostgreSQL in a
read-only session; never a map write), packs every item-holding node of
every housing claim for the claim's owner, adds the Claim Stone's remaining
fuel as charcoal, commits that in one mod-storage transaction and then runs
the due steps as without it. A world at the target with nothing due still
packs and exits 0 (`"applied": []`). Map blocks need zstd: Python 3.14's
`compression.zstd`, else `zstandard` (Debian: `python3-zstandard`).
`--check --map-reset` is the pass's complete dry run (since 0.50.1): the
pass's own code up to its transaction, so every claim block is read and
decoded and every refusal of the pass comes with the same reason; it
writes nothing and reports in `done` what the pass would write (`pack`:
`seq`, `counts`, `nodes`, `empty` as in `pack_done`, and `seconds`). It
also selects one map block, decodes it and proves zstd importable
(`map_checked`: 1, or 0 for an empty map). Code:
`tools/migration/mapblock.py` (the map and the decoder) and `pack.py`.

The world is found from `world.mt` only: `player_backend`, `auth_backend`
and `mod_storage_backend`, each `sqlite3` or `postgresql`, and the matching
`pgsql_player_connection`, `pgsql_auth_connection`,
`pgsql_mod_storage_connection` strings, handed to libpq as they stand (a
password may come from `PGPASSFILE`). A missing key means the engine's
`files` backend and is refused like any other. A missing `players.sqlite`
or `auth.sqlite` (nobody ever joined) counts as empty; a missing
`mod_storage.sqlite` is refused. A world without a record is at 0.41.0
unless it is new (no character, no mod storage, no `env_meta.txt`, no
`players.sqlite`, no `players/`): then nothing is due and the game records
its version at the first start.

**Exit codes:** `0` migrated, nothing to do, or checked; `2` refused or
failed before anything was written (the world is unchanged); `1` failed
after the first step began: the world is undefined, restore the backup.

**Output:** stdout carries one JSON object per line, the last one is the
result; stderr carries the same as text. Strings are JSON with non-ASCII
escaped.

| Event | Fields | When |
|---|---|---|
| `start` | `mode` (`migrate` or `check`), `world` (absolute directory) | first (a usage refusal comes alone) |
| `pack_start` | `seq` (the pass number), `claims` (claim records read) | `--map-reset`: the pass begins |
| `pack_done` | `seq`, `counts`: `claims`, `players` (owners given entries), `containers` (packed items), `items` (non-empty stacks inside them), `charcoal` (pieces), `blocks_read`; `nodes` (packed containers by node name, empty ones included; `workspace record` for personal workspace records) and `empty` (the empty ones among them, by node name), `seconds` | the pass committed |
| `step_start` | `step` (its version), `from` (the world's version before it) | a step begins |
| `step_done` | `step`, `counts`: `characters`, `player_meta`, `inventories`, `positions`, `privileges`, `mod_storage`, `markers` (writes of that step) | a step committed |
| `done` | `mode`, `world_version` (before the run; `null` for a new world), `record` (the stored record or `null`), `new_world`, `target` (game.conf), `due` (step versions), `backends` (per kind: `sqlite3`, `postgresql` or `absent`; with `--map-reset` also `map`), and `applied` (migrate) or `write_checked` (check); with `--map-reset` also `map_reset` (`true`) and `pack_seq` (migrate) or `map_checked` and `pack` (check: the dry run's `seq`, `counts`, `nodes`, `empty`, `seconds`) | exit 0 |
| `refusal` | `reason`, `message` | exit 2 |
| `failed` | `step` (or `null`), `reason`, `message` | exit 1 |

Refusal reasons: `usage`, `checkout` (game.conf, the declaration or a step
file), `world_mt`, `backend`, `database_missing`, `connection`, `layout`
(not the engine's table layout), `lock`, `write_access`, `record` (no
`major.minor.patch`), `world_newer`, `internal`, and for `--map-reset`:
`pack_baseline` (the world is below 0.48.0), `pack_pending` (the marker of
an earlier pass that the game never loaded: restore the backup taken before
it), `map_block` (a block in a claim the decoder cannot read, a format other
than 29 included), `map_empty` (claims but no map block: the map was
emptied before the pass). Failure reasons: `lock` (a later step's lock),
`step` (the step raised), `rule` (the step broke a limit of the data API),
`commit`, `pack` (the pass's transaction failed).

**Steps** live in `tools/migration/steps/v<major>_<minor>_<patch>.py` and
export `migrate(world)` (the data API: `tools/migration/data.py`; codecs:
`codec.py`). Online work is left with `world.mark_world()` (grug_core mod
storage `migrate_world:<version>`, the game's next load) and
`world.mark_character(name)` (player meta `grug_core:migrate:<version>`,
that character's next join). Tests run undeclared steps through
`migration.cli.main(argv, test_steps={version: module})`, which the command
line cannot reach.

## Web data

`tools/web_data/` (Round 39) is what a website hosting a realm reads at the
realm's commit, never running game code
([README](web_data/README.md); the player-meta contract it describes is in
the [module guide](../docs/technical/module-guide.md#player-meta-read-by-external-tools)):

- `export.lua` and `build.lua`: the exporter (LuaJIT over the real
  registration files on stubs) writes the committed `web_data.json`;
  `--check` exits 1 when it is stale. Its fixture
  `web_data/portable_test.lua` runs under `run_fixtures.sh`.
- `model/` ([README](web_data/model/README.md)): the player model as
  glTF, `grug_visuals_character.glb`, written by `build_glb.py` from the
  `.b3d` and tested against it by `check_glb.py` (both Python standard
  library); `probe/` is the GUI probe mod (`/glb_probe`) for a test world.

The model's checks are Python, not portable fixtures (a LuaJIT wrapper
would need `io.popen`, which check_lua's sweep 5 flags), so a round end, and
a change to the `.b3d` or player_api's animations, runs them explicitly:

```sh
luajit tools/web_data/export.lua --check            # web_data.json is current
python3 tools/web_data/model/build_glb.py --check   # the glb is current
python3 tools/web_data/model/check_glb.py           # the glb matches the b3d
```

## Lane folders

Fixtures and probes by round (moved from AGENTS.md on 2026-10-05). A
`portable_test.lua` runs under `run_fixtures.sh`; an `engine.sh` is a
headless probe with a throwaway probe mod (`grug_probe_*`, never shipped).
Older folders (`r10_*` … `r28_*`, `wp13`, `wp26`, `wp40`) follow the same
pattern; the shared Round 28 tools are `r28_design`, `r28_regions` and
`r28_world` (their uses are in AGENTS.md "Zone content") and
`r28_zone_atlas` (the portable world the seed fleet builds); `r28_names`
is retired since Round 38 (the naming gate is `r38_names/check_rules.py
--shipped`).

- **Round 29** (`r29_<lane>`): `b` boats, `w` waystones, `e1` prices and
  `band_payout.sh`, `e4` income (`income.py`), `mres` gems, `mgeo` bands and
  middle road, `q1` placeholders, `t` the tests of
  `r28_regions/quest_targets.py`, `p` playtest fixes.
- **Round 30** (`r30_<lane>`): `p1` quest state, tracker, Map tab, minimap and
  Character page; `p2` pathing, give-up, collision boxes, merged spawn ABMs;
  `p3` region-map cache incl. input coverage and corruption cases, `run.sh`;
  `p4` crosshair, carriers, flight sweep, farming (its crafting index and
  recipe corpus were retired in Round 45 with the grid); `l` island landings, `engine.sh`; `c` start-NPC
  duplication.
- **Round 31** (`r31_<lane>`): `pvp` flag core and engine probe, `p2` PvP UI,
  `p1b` support refusal and mount boxes, `n` faction filter, `c` clean-up,
  `a` looks and `engine.sh`, `b` enchant colours, masks and `engine.sh`, `s`
  PvP blueprints, `m` placement, `spacing_check.lua` and `engine.sh`, `g`
  garrisons, `q` fortress quests and `run.sh`, `da2` dragon arenas.
- **Round 32** (`r32_<lane>`): `f1` territory line and hostile camps,
  `engine.sh` the minimap traffic and location probe; `f2` the hold machine
  and the quest labels; `f4` the Map tab poll budget and party HUD slots; the
  zoom geometry is checked in `r27_minimap`, the spawner's zone slices in
  `r28_s1`.
- **Round 33** (`r33_<lane>`): `ds` the value rule against the doc
  (`build_doc.py`), `c1` drops, bosses, bags, requirement and
  `drop_income.py`, `c2` professions and progress, `c3` achievements, cloaks
  and the cloak model, `c4` enchant tiers, upgrades, crown and families, `c5`
  crit, vendors, repair, potions and the capital services.
- **Round 34** (`r34_<lane>`): `s1a` events, specs, call sites and the
  approval list; `s1b` voices, ability cues and its approval list; `s2`
  ambience and music rules, the approval list and `engine.sh`, the pass cost
  and flowing-water census; `f1` the wading rule and `engine.sh`, a mob at
  real water crossings; `f2` the Bag of Coins, the sell refusal, the damage
  fit, the cooking order and `render_icons.py`; `f3` rivers never cover a
  POI core; `wisp` the Wisp's blink never lands in a liquid.
- **Round 35** (`r35_<lane>`): `t` the rotated boxes, `engine.sh` the
  turning-mob sweep and ray cost, `upstream_check.sh` the engine bug (FIXED or
  BUG PRESENT); `f` the break hook, broken look, empty hand, dig sounds,
  flint and quest lists, its approval list `approved.txt` and `engine.sh`;
  `m` the capital scheduler and either/or rule, `engine.sh` the location and
  ambience passes; `c` the creation draft and window geometry, `engine.sh` a
  creation through the real receive-fields chain; `e` the dawn rule,
  `engine.sh` rats across a dawn; `b` (the level-proof talents of the old
  trees and their `numbers.py`) retired in Round 53 with those trees.
- **Round 36** (`r36_<lane>`): `f` the target predicate, evade rule, banner
  and timing line, `engine.sh` a reset inside and outside the wander radius;
  `f2` the held button across a hotbar switch, `engine.sh` a held dig across
  wield switches; `k` the support factor, Dexterity curve and spell
  rounding (its old talent `numbers.py` retired in Round 53); `e` the use objective, objects,
  hook and tags, `engine.sh` a quest object; `r` the rift, boss, lockout,
  leash and commanders, `numbers.py` the boss's time to kill, `engine.sh` the
  site; `g` the arena hazards, refreeze and gust, `engine.sh`; `q0` the shared
  data against the bible, `engine.sh`; `qa`, `qt` each faction's line; `w`
  the decor rules and the composition record, `render.py`/`page.py`
  before/after pages, `author.lua` row proposals; `w2` every bench faces out,
  `engine.sh` the measured seat halves; `w3` ground cover in the band round
  starts and capitals, `engine.sh` the band on a fresh world; `p` the POI
  renders and review page (`dump.lua`, `render.py`, `page.py`); `a`
  `paint_art.py`, the reproducible textures. Lane RD (roads) added no folder.
- **Round 37** (`r37_<lane>`): `cb` durability, the max-HP clamp, the PvP
  Strike fallback, knockback per source and no WP38 caller left,
  `engine.sh` the cost of a wear event and a taken hit; `mb` threat-only
  retargeting, the held punch clip, the wind-up freeze, the follow scan,
  staticdata and the pathfinding switch; `ix` right-click routing, tall
  crops, the furnace form, ground growth, the water barrier and slabs,
  `engine.sh` the water guard's reverts at a capital edge and a coast;
  `po` the minimap change test, quest markers, tracker, discovery, the
  Claim Stone scan cache and the weapon hint, `engine.sh` the crowd probe
  at 50 and 100 stand-ins, `texture_growth.lua` the minimap's client
  textures per quality; `mg` a chunk's own cells, the halo-free writer and
  the wrappers' tracebacks, `halo_evidence.lua` and `engine.sh` the
  before/after pair; `sn` the three cues, the approval list `approved.txt`
  and the `cast_ice_nova` rename, `engine.sh` every spec names a shipped
  file; `dc` the version, the New World keys, Help → About, the settings
  lines and the README and CHANGELOG links, `engine.sh` the smoke boot and
  the first-start wait; `dd` `zone_mobs.lua`, the generator of
  `docs/design/zone_mobs.md` (`--check`), and its fixture; `mp` the mob
  limit and authored actors, shutdown, rare and dragon liveness, Bone
  Call, royal guards, the fan's shots and the patches, `engine.sh` a
  two-boot restart test; `f` the start-zone alert rule, the Reef Lurker's
  shore kind and the minimap's normal base.
- **Round 38** (`r38_<lane>`):
  - `names`: lane I's slot inventory (`inventory.py`), the name-rule
    checker (`check_rules.py --shipped`, the naming gate; its test
    `test_rules.py`), the quest-name guarantee (`guarantee.py --check`,
    `--self-test`) and the zones' neighbours (`neighbours.lua`).
  - `b1`: `gen_names.py` writes and `--check`s `grug_mobs/data/names.json`
    (`--proposals` lays the picks over today's names), `names_stub.lua`
    for fixtures, and the portable test of names by slot, the Stillgrave
    kill credit, garrisons and the kill path's cost.
  - `b2`: the portable test of the accepted names in the game (code-built
    names equal `names.json`, single-named entities register under it,
    the whelps at level 60).
  - `wc`: the portable test of the welcome window (its text, link buttons
    and Got it; the arrival callbacks run once, after the arriving mark is
    cleared).
- **Round 39** (`r39_<lane>`): `wm` the player meta (`grug_xp:level` on
  XP changes, join and the cap; the appearance for every loadout, its
  writes, and every texture string within the caps and the closed
  grammar; `examples` prints two values); `wg` the glTF probe mod on a
  fake engine. Lane WE's fixture is `web_data/portable_test.lua` (above).
- **Round 40** (`r40_<lane>`; V2's pose table is `r40_an`, V3's catalogue
  `r40_v3`, V4's probe `r40_probe`): `r40_probe` the GUI probe mod
  `grug_r40_probe` (Charge variants on test courses, the cooldown overlay on
  the hotbar, server-side timings; never shipped, see its
  [README](r40_probe/README.md)); its `portable_test.lua` covers the path
  planner, the overlay arithmetic and the cooldown number, and
  `gen_textures.py` (`--check`) draws its pie frames and digits.
  `r40_an` the pose proposals (`make_poses.py` bakes the readable spec into
  per-frame B3D keys, `poses.json`, `--check`), the table lane AN1 bakes into
  the player model. `r40_an1` the pose clips' triggers on the real
  player_api, poses.lua and the cut trigger sites (`portable_test.lua`: pose
  per skill, never on a refusal or the Strike fallback, the walking twin
  and its walk phase, hold times, one-shot restart, the flinch's rate limit
  and precedence; its `bench_hook.lua`, which timed the Scout's bow-draw
  hook, was retired with the draw in Round 53).
  `r40_v3` the accepted particle effect catalogue
  (`effects.py`, the emitters in engine terms; `cost_model.py`, the server
  cost from the engine's serialization; `data.json`, their output;
  `particle_cost_probe/`, the headless timing of the particle API calls).
  `r40_cd` the cooldown overlay: `gen_cooldown_textures.py` (the 72 cover
  frames and the image digits in `grug_abilities/textures`, `--check`),
  `portable_test.lua` (number, frame, the slot geometry against the
  engine's pixel arithmetic, slot tracking, writes only on change, the
  pass), `bench/` (a headless probe mod: the wear bar's Lua cost before and
  the overlay's after, `PROBE=tools/r40_cd/bench tools/luanti_headless.sh
  150`).
  `r40_px` the particle helper's fixture (`portable_test.lua`: the scale
  arithmetic, exact rings, the budget of every catalogue effect, the
  fallback rule on the real kits, settlement and cast dispatcher), the
  busy-fight cost of the built effects (`costs.py`, reads `r40_v3`'s
  `data.json`) and `bench/`, a disposable probe timing each skill's effect
  calls before and after the helper (`PROBE=tools/r40_px/bench`).
  `r40_pm` the boss and mob-special effects' fixture (`portable_test.lua`:
  each effect at its moment and only then, on the real catalogue and the
  real mob code, the rings and the counts under the scale), `helper_stub.lua`
  (the real particle helper for a fixture's fake engine, which the older mob
  fixtures load too), the per-boss and per-mob cost of the build
  (`costs.py`, reads `r40_v3`'s `data.json`) and `bench/`, a disposable probe
  timing the effects' Lua before and after the helper
  (`PROBE=tools/r40_pm/bench`).
  `r40_ch` Charge's dash (`portable_test.lua`: the shipped planner on the
  probe's courses and the hole rule's lanes, the dash on a fake engine --
  arrival and miss, cancellations, punch forwarding, the hold and the
  placement on the stop, lead, FOV, pose and dust -- and the kits.lua cast's
  refusals) and `bench/`, a disposable probe timing the cast's map work and
  the carrier per step on natural terrain (`PROBE=tools/r40_ch/bench`, run
  on the base and the branch); `lag_replay.py` replays the client's drawn
  carrier to size the arrival hold (the forward snap at each hold length).
  `r40_an2` the head look's fixture (`portable_test.lua`: the sign proven
  on the model file with the engine's override composition, the 5° steps
  and the clamp, the epsilon, the rate cap, the spread pass, death and the
  Charge holds),
  `bench_pass.lua`, the pass for 100 stand-in players, and `engine.sh` with
  the disposable probe `grug_probe_r40_an2`, the engine cost of the look
  read and the override write.
  `r40_ore` (fix lane ORE, resources and gatherables wherever digging is
  allowed): `run.sh OUT_DIR [TIMEOUT]` boots the disposable probe
  `grug_probe_r40_ore` (resources and gatherables inside the human start
  town, in its graded ring and in the nearest human village's envelope,
  against reference boxes); `evidence/` keeps its run on seed
  5626331914247410985. Its portable checks live in `r24_protection_depth`
  (the P8 floor against the hard protection), `r24_fill` (the host rule)
  and `r23_renewal` (gatherables in an envelope).
- **Round 41** (`r41_<lane>`): `r41_cr` the production mapgen crash
  (`portable_test.lua`: on the production seed's crash chunk, a water
  barrier in the top layer is filled like air, a foreign node and an unknown
  id fail the writer and degrade on the engine path with one `[GRUG-SEVERE]`
  line and one chat message per chunk, a late failure restores the engine's
  bytes; the severe-error helper), `engine.sh PLAN [TIMEOUT]` with the
  disposable probe `grug_probe_r41_cr` (generate chunks in order, census a
  layer, place nodes, record severe reports) and its plans (`plan_*.txt`,
  runs 1–5 of the lane's diagnosis and the final region run); `r41_sc` (the
  bow's missed release) was retired with the bow draw in Round 53; `r41_up` the platform's upgrade contract
  ([upgrade contract](../docs/technical/upgrade-contract.md)):
  `portable_test.lua` (the world and character records and the trigger, the
  idempotent clears of the preparation, grug_mobs and housing state, the
  relocation on the real character creation with its hold, failure and
  retry, new characters, unknown quest, waypoint and achievement ids, the
  committed declaration) and `engine.sh OUT_DIR [TIMEOUT]`, two boots of one
  world with the disposable probe `grug_probe_r41_up`: a fresh world with a
  Claim Stone, then what the platform does (map database deleted,
  `grug_reset_world` raised through a disposable patch of the staged game)
  and the reset boot with an old and a new character. The declaration's
  rules are `check_upgrade.py`'s own self-test (above).
- **Round 42** (`r42_<lane>`): `r42_nv0` the navigation test scene, which
  NV1–DR rerun for their before/after numbers
  ([round plan](../docs/planning/round42-plan.md) §4.1). `run.sh OUT_DIR
  LABEL [PHASES] [TIMEOUT]` boots the disposable probe `grug_probe_r42_nv0`
  (through the round's measuring queue when it exists; `SEED` default 12345;
  `NV0_MOVERS`/`NV0_SCENES` restrict a debug run) and copies
  `nv0_results.json` and the `[nv0]` log lines to `OUT_DIR`; one phase per
  boot fits the default timeout of 360 s (or raise `TIMEOUT`). Phase `scenes`
  (about 4 minutes) builds fifteen scenes (`grug_probe_r42_nv0/scenes.lua`:
  open ground, a trunk, a trunk right before the target, a row of trees, a
  wall with a doorway, an L-corner, a 2-high and a 1-high fence ring, a
  pillar, a ditch, a step, a wall with a 1-high hole and a 2-high gap, a
  pond, a closed and an open wooden door) as lanes on a forceloaded floor
  above deep ocean and drives real mobs on the real code through all of them
  at once, one mover per batch: boar, wolf, bear (wide), bandit (tall) forced
  onto a punchable dummy, a post guard walking back to its post, a royal
  guard following a leader stand-in, a villager walker. Per trial: reached
  and when, every `core.find_path` call (count, found, cost, the largest),
  the stuck triggers (since NV1 the navigation module's events, `nav_*`)
  and a per-step track; each batch logs its three slowest steps with the
  costliest mob in them. Phase `calib` measures
  `find_path` against padding and distance (the scenes, a flat field with
  and without a path, natural-terrain samples), the candidate fan and a
  walkable-line prototype; `chasers40` is Round 30's stress (40 chasers round
  an enclosed target); `settle` measures the walker and patrol legs the real
  NPC placement gives the first start town and its capital (one search per
  leg; `SEED=42` is the plan's seed). `summarize.py RESULTS.json
  [AFTER.json]` prints the tables (self-movement ratios, before/after;
  `--compact` drops the tracks); `portable_test.lua` pins the scene layouts
  with an engine-like grid search; `evidence/before/` keeps the lane's
  before-runs (scenes and calib on seed 12345, settle on 42, the PvE micro
  run). The PvE micro run itself is `r31_pvp/run.sh` with
  `ENGINE_RUN=<the round's engine_run.sh>`. `r42_nv1`: `portable_test.lua`
  loads the real `mobs/grug_nav.lua` and `grug_obstacle.lua` on a fake node
  grid with an engine-like search (the stuck detector, candidates, the
  follower, lockout and cap, head room and width, give-up and veto, the
  physics box); `evidence/after/` keeps NV1's after-runs of the scenes, the
  40 chasers (seed 12345) and the PvE micro run (`scenes_summary.md` ends
  with the before/after table against `r42_nv0/evidence/before`). `r42_nv2`:
  `portable_test.lua` drives real fixed walks (the real `patrol.lua` and
  `aggro.lua`, the post tick, royal follow and rift way home cut out of
  their files, the real navigation) through a node grid with a colliding
  body and mobs_redo's cliff and fence holds: patrols, posts, held walkers,
  the evade, the royal follow, the rift boss, the later stages;
  `evidence/after/` keeps NV2's scenes run of the post guard and the royal
  guard (seed 12345; the before/after table against
  `r42_nv1/evidence/after`). `r42_nv3`: `portable_test.lua` drives real
  villager and patrol walks (the real `patrol.lua`, `routes.lua` and
  navigation, the amble and work ticks and the rings cut out of
  `start_villagers.lua` and `start_npcs.lua`, a capital's streets written by
  the real `road_layout.lua`) through tools/r42_nv2's world model: the route
  cache, the street legs, following and the return to a route, the next-spot
  stage, the one-spot walkers, residents that ask nothing. `run.sh OUT_DIR
  LABEL [TARGETS] [TIMEOUT]` (probe mod `grug_probe_r42_nv3`, seed 42, one
  boot through the round's measuring queue) watches the real placement and
  movement of one settlement at a time with no player for `OBS` seconds
  (default 90): every `core.find_path` call, the navigation's counters,
  walker arrivals and spots given up, patrol advances, snaps, one-spot
  walkers, the route cache's statistics; targets `start`, `village`,
  `capital`, `capital_partial` (after the placement only a 96-node box round
  one district patrol guard stays loaded: legs with unloaded ends) and
  `streets` (the capital's streets read from the road layout
  as the runtime does). `summarize.py RESULTS.json [MORE.json ...]` prints
  the table; `evidence/before/` and `evidence/after/` keep the lane's runs.
  Since Round 42 DR the probe also counts the doors NPCs open and close and
  the doors standing open before and after each window, and the NV0 probe
  re-places a scene's door before each trial and records whether it is open
  at the trial's end (`door_open_end`). `r42_dr`: `portable_test.lua`
  drives real walkers, post guards and patrols (the real `npc_doors.lua`,
  `patrol.lua`, `routes.lua`, navigation and amble tick, and the vendored
  `doors.get`/`door_toggle` cut out of `doors/init.lua`) through doors in
  tools/r42_nv3's world model: door legs, open/pass/close, the NPC right
  behind, unloaded in the doorway, open doors, owned doors and trapdoors,
  gates, fixed-walk door detours; `evidence/after/` keeps the lane's capital
  run (NV3's probe) and NV0's door scenes. `r42_st`: `portable_test.lua`
  cuts the vendored walk state, `get_nodes` and `do_jump` out of
  `mobs/api.lua` and drives them with the real `grug_nav.lua` steer mark and
  `patrol.lua` (`walk_toward`, `route_tick`): no random stop for a driven
  walker at any phase, free wanderers keep it, `facing_fence` only for
  blocking nodes, the jump logic at real fences unchanged;
  `evidence/after/` keeps NV0's villager and post-guard scenes.
- **Round 43** (`r43_<lane>`): `r43_gs` the game side of world migrations
  ([round plan](../docs/planning/round43-plan.md) §4.1):
  `portable_test.lua` (the real `grug_core/world_version.lua` and
  `migrations.lua` on stubs: the start guard's decision and refusals, the
  record at load, new-world recognition, the online-work runner's order and
  failures, the character work before the map reset's relocation, the test
  hook `grug_test_migrations`) and `refusal_boot.sh OUT_DIR [TIMEOUT]`, two
  boots of one world: a fresh world records its version, then the record is
  raised above the game's and the second boot must refuse; the world
  directory is listed before and after it (`evidence/`).
  `r43_mt` the migration tool's tests,
  `test_migrate.py` (Python unittest: the codecs against an engine-written
  world, opening and refusals, locks, check mode, events, test-only steps
  through `cli.main(test_steps=...)`, against a copy of the declaration with
  an empty `migrate` list), run where the platform runs the tool
  by `container_test.sh [COMMIT]` (debian:trixie, Debian's python3,
  python3-psycopg and python3-zstandard, a `git archive` export).
  `world/` is that engine-written world, built by `make_world.sh OUT_DIR`
  with the disposable probe `grug_probe_r43_mt` (two launcher runs on a
  world folder of its own: the game with SQLite mod storage, then
  `--migrate-players sqlite3`); IT builds its worlds the same way.
  `r43_it` the migration path end to end
  ([round plan](../docs/planning/round43-plan.md) §4.3): `run.sh
  [EVIDENCE_DIR]` (default `evidence/`) runs `it.py`, which prints a PASS/FAIL
  table: real engine boots of two test worlds through `luanti_headless.sh`
  with the probe `grug_probe_r43_it`, real joins by `client.py` (a minimal
  protocol client), the tool with the undeclared test steps of `steps.py`
  (`tool_run.py`, the tool's Python hook) and the game's test hook naming the
  same steps (`grug_test_migrations.lua`; the declared steps run with them
  and the guard names them, their own markers left out of the test steps'
  marker checks, and when the last declared step is the game's
  own version the compatible-move boots stage a game.conf one patch version
  above it): offline writes, world and
  character online work in step order, the start guard's refusals and record,
  new-world agreement of tool and game, a map reset combined with a step, and
  PostgreSQL (`pg_test.py`: a throwaway server inside the container, tables
  seeded from the engine-written SQLite world). Needs podman and the Flatpak
  Luanti; the first run builds the image `localhost/grudgelands-r43-it:trixie`
  from `Containerfile` (Debian trixie's python3, psycopg, zstandard and
  PostgreSQL; network for apt). About 5 minutes; one queue slot (boots and
  containers run one at a time).
- **Hotfix 0.43.1** (`hf_0431`): `portable_test.lua` drives the real
  `routes.lua`, navigation and amble tick in tools/r42_nv3's world model on
  legs whose two ends share one search cell (two spots on one position, one
  node apart in height on a block, a stand-in start), and an "ok" route
  without points through `route_walk` and `route_follow`: no crash, the
  walker arrives. `same_cell.lua` lists the start and capital blueprints'
  idle-spot pairs and patrol neighbours in one cell (offline, no engine).
- **Round 44** (`r44_<lane>`): `r44_fr` the inventory window
  (`portable_test.lua`, the real vendored sfinv and `grug_inventory`'s
  `ui.lua` and `pages.lua` under a stub `core`): the fixed tab order, the
  frame (formspec_version 6, the old window size), the full and short
  inventory views with 0–4 bags of mixed sizes, the scrollbar echo and no
  resend on a pure scrollbar event, the Sort cooldown, the refresh rules;
  it prints the Inventory and Character pages' bytes with four 32-slot bags.
  `r44_ih`: `portable_test.lua` loads the real
  `grug_inventory/bags.lua` (and `storage.lua`) with an engine move and drop
  model and metadata-aware stacks: the give helper's order (quiver,
  `main[9..]`, bags, hotbar, leftover; soulbound in `main` only; pickup and
  dug drops), the fit check, bag swaps and removals with and without room
  (no item lost or duplicated), bags in bags, the sort (categories, tier,
  name, quality, merging, the hotbar untouched), the potion belt's allow
  rule and ammo from a bag.
  `r44_ch`: the Character tab. `harness.lua` loads the real vendored sfinv,
  `grug_inventory`'s `equipment.lua`, `bags.lua` (with `storage.lua`),
  `ui.lua` and `pages.lua`, the real `grug_gear` permissions,
  `grug_achievements` (and, before Round 45, `grug_jobs/character_tab.lua`)
  under a stub `core`,
  with an engine move model whose shift-click follows the page's own
  listring. `portable_test.lua`: each mode renders inside its box, the gear
  box's slots and hand labels per class, the arrow slot only for Scouts,
  Return home and Withdraw, and the shift-click routing (gear into its slot
  or swapped, back out in the give order, arrows into and out of the
  quiver, the refusals); it prints the page's bytes per mode.
  `luajit tools/r44_ch/bytes.lua [repo]` prints the bytes per mode for a
  Scout with four 32-slot bags against any tree (before and after).
  `r44_ts`: `harness.lua` loads the real vendored sfinv, `grug_inventory`'s
  `ui.lua`, the talent files (since Round 53 the graph talents) with
  `talents_ui.lua`, `talent_graph_ui.lua` and `grug_skills` under a stub
  `core`, with an optional list of texture files to hide;
  `portable_test.lua` checks the class's graph trees on the page (tabs,
  connectors under the nodes, node states, buy on click, a refused click's
  reason, the respec), the one Talents & Skills tab and its catalog row,
  the hotbar-only rule for every target list with an engine move model
  (catalog to hotbar, drag back removes) and the grants with a free and a
  full hotbar (the grant code cut out of `grug_abilities/init.lua`);
  `page_bytes.lua [repo]` prints the page's formspec bytes for a level-30
  Scout with 15 ranks (the Round 52 page: 7138 bytes).
  `r44_ar`: `paint_art.py` (Python 3 with Pillow) paints the map and
  trainer art (trainer icons, baked map icons with their 6 × 6 minimap
  drawings, the pixel font, the crosshair and the ring) in three variants
  A, B and C with a contact sheet each under `variants/`; `--install`
  also copies the user's picks (`PICKS`: A for every file, the font from
  C) to `mods/PLAYER/grug_map/art/` and `textures/`, and `--check` (with
  `--install`, also the installed files) verifies them without writing.
  After an install, rerun `r44_mb/gen_baked_art.py`.
  `r44_mb`: `gen_baked_art.py [--art DIR]
  [--check]` turns the baked map icons and the pixel font
  (`mods/PLAYER/grug_map/art/`) into `mods/PLAYER/grug_map/baked_art.lua`
  (standard library PNG decoding; `--check` exits 1 on a stale copy,
  `--self-test` decodes small PNGs of every transparency form; both run in
  `tools/check_fresh_server.py`, so changed art must be regenerated);
  `portable_test.lua` checks the kind mapping, the items, the glyph layout,
  the drawing, the cache key text and the minimap's marker kinds; the
  disposable probe `grug_probe_r44_mb` (staged with `PROBE=` through
  `luanti_headless.sh`; `high_quality.patch` as `GAME_PATCH=` for a second
  boot at high quality) logs the Map tab's formspec bytes per faction, the
  minimap's densest capital window and each king's place in its capital.
  `r44_pp`: `portable_test.lua` loads the real sfinv, `grug_inventory`'s
  `ui.lua`, `help.lua` and `welcome.lua`, `grug_parties/ui.lua` and
  `grug_pvp/page.lua`: the one Party & PvP tab in and out of a party (both
  sections, no inventory view, inside the window), every party and PvP field
  still handled, the PvP 1 s check, Help without a view, the new tab and key
  names in Help and the welcome window, and a scan of every Lua string
  literal and JSON line under `mods/` for a removed tab name; it prints the
  page's bytes.
  `r44_mq`: `portable_test.lua` loads the real `grug_keys` and
  `grug_map`'s `atlas.lua`, `providers.lua`, `page.lua` and `window.lua`
  (with `targets.lua`, `quest_box.lua` and, since Round 47, `layers.lua`
  and `zone_labels.lua`) under a stub `core`: the key
  edges, the window size and layout (Round 47: the layer button rows), the
  overlay per layer, faction and quest mode (Round 47: one layer at a time,
  the tooltips topmost first, the deselection on a layer click, the zone
  labels, the layer icons), the quest target index and the crosshair-before-rings rule with
  the five-ring cap (garrison camps and the rift boss as crosshairs), the
  refresh rule (throttle, trailing send, party checks, the pass budget, the
  0.5 s scroll pause, a send that crossed a close), the quest boxes (no
  preselection), zoom and the Map tab; it prints
  the sends per minute alone and in a party. The disposable probe
  `grug_probe_r44_mq` (staged with `PROBE=`) logs the map formspec's bytes
  per faction at zoom 1x and 8x (the Map and Quests tabs before Round 44 MQ,
  the map window after, since Round 47 per marker layer and in quest mode
  with the drawn markers and tooltips, the layers' rows, the zone labels'
  placement and the overflowing quest texts), the target index's size and
  build time and how many quest objectives the targets mark.
  `r44_qb`: `portable_test.lua` loads the real `grug_keys`,
  `grug_quickbar`, `grug_mounts` (catalog, state, entity, items, trainer,
  shipwright), `grug_traders/potion.lua`, `grug_alchemy/effects.lua` and
  `grug_home/travel.lua` under a stub `core`: the quickbar's content per
  owned tiers and belt contents, opening on aux1's rising edge only, a belt
  click drinking once through the potion's `on_use` and the shared
  cooldown, summon and dismount with their gates, Return home with its
  gates, no mount item on purchase or join and the "Press E" tip in both
  stable dialogues; it prints the window's bytes.
  `r44_ms` the test of the migration step 0.44.0 (mount items and skills
  outside the hotbar; [upgrade contract](../docs/technical/upgrade-contract.md)
  §5.8): `run.sh [EVIDENCE_DIR]` (default `evidence/`; one queue slot, about
  3 minutes) runs `test_step.py` (Python unittest on the Round 43 MT world,
  the tool pinned to the 0.44.0 checkout) in IT's runner image, then
  `e2e.py`, which reuses `r43_it/it.py` and `client.py`: the 0.43.0 game
  (a `git archive` of `9dc2fad5`) builds two characters with the probe
  `grug_probe_r44_ms` and lists its registrations (the step's frozen names
  are checked against them), this game refuses the world, the shipped tool
  (`--check`, migrate, `--check`) runs in the container, and this game boots
  and both characters join again; a PASS/FAIL table. The exact checks of the
  step read a copy migrated by 0.44.0 alone (the tool in-process, pinned to
  the 0.44.0 checkout), since the shipped run also runs the later declared
  steps (Round 45); it also checks the chain: the 0.43.0 world crosses
  0.44.0 and 0.45.0 in one shipped run, and a record-less copy (0.41.0, the
  production server's version) gets the same rows from one run.
- **Round 45** (`r45_<lane>`): `r45_il` the item level ladder
  (`portable_test.lua`, the real `grug_gear` with its trinkets,
  `grug_quality` and grug_core's level gate under a stub `core`): the
  brackets (base item level 1/11/21/31/41/51, cap 10 × tier), every gear
  definition and trinket at its bracket's level and requirement with the
  baked tooltip lines, the requirement rule (the item level from level 1,
  capped at 60, no first-bracket exception) for drops and crafted bases,
  consumables off the ladder, and a stack pinned at the old ladder's
  `grug_ilvl` / `grug_req_level` (lane MS's 0.45.0 step) keeping its level,
  requirement, tooltip, armor and enchant values.
  `r45_rg` the recipe registry: `dump_corpus.sh`
  boots the game once with the disposable probe `grug_probe_r45_rg` and dumps
  the engine's grid routes, the registry, the gear families and the vendor
  payouts (`corpus_base.lua` is the base commit's dump, the generator's input);
  `gen_basic_recipes.lua` converts it into `grug_jobs/basic_recipes.lua`
  (`--check`, `--report`), applying the later edits of `edits.lua` (Round 46:
  one torch recipe, 10 per coal or charcoal); `portable_test.lua` loads the real registry, the
  Basic catalog and the profession catalogs under a stub engine: the record
  shape, queries and refusals, the conversion of every grid route, gear in
  its profession, durations, stations, the craft list at a join and the
  removed APIs. The recipe-book probe `pt_fixes/lane_d` is retired with the
  books.
  `r45_jb` crafting jobs (`portable_test.lua`, the real `grug_inventory`
  give helper and fit check, the registry, `state.lua` and `jobs.lua` under
  a stub engine with a wall clock and `core.after`): the start checks, the
  consumption order and the metadata rule, completion by the online timer,
  at login and on opening the tab (a server restart in the middle of a job
  included), gear through `crafted_output`, several output stacks above
  `stack_max`, XP per job and after an unlearn, cancel with and without room,
  Stop after the end, the take-only output area and Take all; since Round 47
  the room check for the whole order, per-craft delivery into the inventory,
  the refund of unfinished crafts, the overflow and its drain.
  `grug_probe_r45_jb` is the smoke boot's disposable probe (registry facts
  the fixture relies on).
  `r45_st` stations, cooking and alchemy (`portable_test.lua`, the real
  `grug_brewing`, the `grug_jobs` registry, state, jobs, trainers, station
  nodes, workspaces and automatic files, `grug_cooking`, `grug_alchemy`
  recipes, `grug_mobs/start_npcs.lua`, the map and repair providers under one
  stub engine): proximity stations without `on_rightclick` or lists, the dig
  and blast refund of old station contents, Cooking learned at join and
  arrival, the Cooking trainer mapping in each trainer-role reader (Grudge-Free
  Repairs: repair only, under the trainers' rules), an
  alchemy job making finished potions at the brewing stand (refused without
  one), inert mixtures, and the 163 quest item objectives.
  `r45_ui` the Crafting tab (`portable_test.lua`, the real vendored sfinv,
  `grug_inventory`'s `bags.lua` and `ui.lua`, the registry, `state.lua`,
  `jobs.lua`, `overview.lua`, `ui.lua` and `craft_box.lua` under a stub
  engine with a wall clock): the page inside the frame and its columns, the
  area tabs and tier progress, paging, the search and its once-a-second
  throttle, ×N and Craftable only against the job's ingredient rule (one
  inventory pass per build), the quantity-field rules, the station hint with
  the disabled button, the XP hint, the progress bar's `frame_start`, the
  sends per job (start, end, cancel; none on a pure scrollbar event), the
  overview in the box and gone from the Character tab, since Round 47 the
  overflow shown only while it holds something and Basic's held-once
  listing; it prints the page's
  bytes. `gen_progress_bar.py` writes the bar texture (Python standard
  library; `--check` compares its pixels). `grug_probe_r45_ui` is the smoke
  boot's disposable probe (the page's bytes with the real registry, list
  facts, a job's sends).
  `r45_eu` enchants and upgrades as jobs (`portable_test.lua`, the real
  `grug_gear`, `grug_quality`, vendored sfinv, `grug_inventory`'s `bags.lua`
  and `ui.lua`, the `grug_jobs` registry, state, jobs, overview, ui, craft
  box, `operation_jobs.lua`, `operation_box.lua` and `station_operations.lua`
  and the real enchant and upgrade registrations under a stub engine with a
  wall clock): the data (588 enchants, 36 upgrades, progress only for
  enchants, one own material per level and a Stick for weapons), the target
  slot, the enchant list filtered to the valid enchants, the preview equal
  to the result, 5 s, cancel returning the exact item, a changed target
  judged again, a refused begin, XP, a restart in the middle of a job; +N
  and Max to the cap, the profession-tier rule, the cost per level, the
  warning's two-step, "Already at the cap", no XP; the boxes' geometry and
  bytes against the recipe box.
  `r45_ms` the test of the migration step 0.45.0 (mixtures, the craft grid,
  the item level pin; [upgrade contract](../docs/technical/upgrade-contract.md)
  §5.8): `run.sh [EVIDENCE_DIR]` (default `evidence/`; one queue slot, about
  3 minutes) runs `test_step.py` (Python unittest on the Round 43 MT world,
  the tool pinned to the 0.45.0 checkout: the move order, leftovers, size 0,
  the pin only without an item level, the tables) in IT's runner image, then
  `e2e.py`, which reuses `r43_it/it.py` and `client.py`: the 0.44.0 game (a
  `git archive` of `c913dbbe`) builds three characters with the probe
  `grug_probe_r45_ms` and lists its registrations (the step's frozen gear
  table, bag sizes and mixture prefix are checked against them), this game
  refuses the world, the shipped tool (`--check`, migrate, `--check`) runs in
  the container and every slot of every list is compared with what the step
  must leave; `pg_check.py` repeats that run on PostgreSQL in the container
  (r43_it's `pg_test.py` helpers; all three backends and the platform's
  layout, seeded from the 0.44.0 world, every row equal to the SQLite
  result: the size-0 grid, the pin, mixtures, the seen-items key); and this
  game boots and two characters join (craft and
  `craftresult` leftovers through the give helper, the output area and the feet; old item levels,
  requirements, tooltips, armour and first-tier damage; the offline
  character keeps its marker); a PASS/FAIL table. `portable_test.lua` is the
  join part's fixture (the real `grug_gear`, `grug_quality` and
  `grug_core/migrations.lua` under a stub engine): the leftover order, a
  failing drop without copies, the capabilities refresh (station-enchanted,
  upgraded and crowned weapons untouched), the tooltips, a rerun; it stays in `run_fixtures.sh` for good.
  The playtest fixes (`portable_test.lua` each, real game files under a
  stub engine): `r45_pt5` the shift-click inbox (creative, chest, partial
  fit, `main` full, the give order, everything full, the output area and
  target slot, guarded items, `room_for` against `give`, the rings of every
  patched page and the bag rings, the creative page without its trash
  ring); `r45_pt6` mounts (the first-person attach, ride sounds from the
  mount's step, the water and lava dismount and summon refusals, fall
  damage by height, solid ground for ground mounts); `r45_pt7` mobs (the
  fliers' fly clip, the shore crab's stepheight and every stepheight being
  0 or above 1, the dawn cube; `grug_probe_r45_pt7` is its engine probe);
  `r45_pt8` station sounds (no idle loop, the queue rule also under a
  coarse `core.after`, which stations sound); `r45_pt9` the Claim Stone as
  a waypoint (the list entry, travel both ways, the map marker).
  `r45_art` the user's art picks in the game (the five station node boxes
  and tiles against the picked designs, a jewellery icon per trinket and
  tier, no removed texture named). `r45_a1` (jewellery icons) and `r45_a2`
  (station designs) are the GPT-6 Astra generators with their proposal
  sheets and `final_sheet.png`; `--check` byte-compares the shipped files
  (Python with Pillow, an installed tool for generating art).
- **0.45.1** (`r451_<lane>`, the fix round after the 0.45.0 playtest;
  `portable_test.lua` each, real game files under a stub engine):
  `r451_ch` Charge down and up stairs and slopes (the real planner
  `charge_path.lua` with `blink.lua`'s destination on built terrain: never
  cut, the straight drop off a flush last step, the last clearable edge on
  a blocked flight; an optional second argument loads another planner for a
  before/after comparison); `r451_cu` the Crafting tab's fixes and the tab
  order (group ingredient labels and the owned icon, − and +, the search
  clear, the focus line and its resend, Map & Quests before Help);
  `r451_kf` the inventory key closing every window (`focus.lua` models the
  engine's initial focus after `guiFormSpecMenu.cpp`; the inventory pages,
  the Character and Inventory tabs' harmless focus, the other windows and
  a scan of every `set_focus` target); `r451_mc` the riding camera, seats
  and sizes per mount, the Dismount button, the first-mount banner, the
  flyers' ground frame and flight loop, the ride-only bat mesh and the
  boat's surface rule; `r451_mc/gen_bat_ride_mesh.py` writes the ridden
  bats' mesh `grug_mounts_bat_ride.b3d` from the cave bat's (the body bone
  held at frame 1; stdlib Python, `--check` byte-compares the shipped
  file); `r451_mc_probe` the never-shipped `/mountcam` mod the user copied
  into a world's `worldmods/` to tune camera, seat and size (its README
  has the commands and the values table); `r451_mu` the "Now playing" box
  (titles and artists against `LICENSE-media.md`, the playing track through
  the scheduler, the box geometry over desktop and web windows; the
  minimap's drawing is in `r27_minimap` block P); `r451_mz` the map window's zoom with the
  soft lock on the player (the real `grug_map`
  `atlas.lua`: centring on the player, clamped at the edges without drift,
  the player's scrolling breaking the lock, 1x restoring it, values of an
  older form read at its zoom); the window's wiring and its focus are in
  `r44_mq` (section M); `r451_nq` the quest giver's preselection and the
  town NPCs' standing room and re-seat (`engine.sh` with
  `grug_probe_r451_nq` is the capital NPC socket audit on a seed, one
  queue slot); `r451_sc` the tap window of self and support skills and the
  right-click food tap (the real `input.lua` driven at the engine's step);
  `r451_tr` the trainer window's bottom row, the greetings and the
  mender's "Grudge-Free Repairs" form; `r451_tx` GPT-6 Astra's proposals
  (trainer greetings, music-note icons, `paint_art.py`, the offline
  `review.html`), provenance for the user's picks, not a fixture.
- **Round 46** (`r46_<lane>`): `r46_wt` the waiting point
  (`portable_test.lua`, the real vendored sfinv, `grug_core`'s
  `map_reset.lua`, `grug_factions` and `grug_classes/selection.lua` under a
  stub engine with reset 1 applied): the rule matrix at the start of a
  session (new, mid-draft, created but not arrived and backlog players moved
  to (0, 31000, 0) once; a complete character without a backlog held where
  it stands; no session when ready), the arrival and relocation teleports,
  disconnects at the waiting point, the constant and its place in
  `lock_player`, and the chunk edge y = 30927 from the game's
  `minetest.conf`. `engine.py OUT_DIR` is the engine run (one queue slot
  through the round's `engine_run.sh`, about 3 minutes): one boot of a fresh
  world (seed 42, reset 1 staged) with the disposable probe
  `grug_probe_r46_wt` and real protocol clients (`r43_it/client.py`, with
  block acknowledgements and position reports like a standard client);
  characters saved at old positions rejoin during the preparation, the probe
  counts the generated chunks near each old position, the engine spawn and
  the waiting point, and checks the teleports and the disconnects;
  `evidence/` holds the run's receipts;
  `r46_ck` cooking for every start zone:
  `locality.lua` reads the shipped world data (zone biomes and level bands,
  the wild plant and gathering catalogs, the catch tables, the mobs' meat
  drops) and the real cooking catalog, and says which Cooking recipes each
  zone can make from its own ingredients; `cook_local.lua [REPO] [--before
  OLD_REPO] [--all | --recipes]` prints them per race (before and after
  against a `git archive` of an older commit) or per recipe;
  `portable_test.lua` checks the plain food role (weaker than every role per
  tier), the six plain dishes, the staple and raw fish groups, and the
  coverage (two T1 recipes in every start zone, the T1 and T2 plain dishes in
  every 11-20 zone, every zone its band's plain dish, a T3 recipe in
  Frostbarrow), that ×N equals what a job can take for every Cooking recipe
  on many inventories (overlapping groups included; `jobs_harness.lua`
  loads the real `grug_jobs` registry and jobs under a stub engine), the
  plain furnace foods and the four ingredient swaps; `bench_count.lua [REPO]
  [ROUNDS]` (LuaJIT, also `-joff`) times that count per page view on the
  review's worst case and a realistic inventory;
  `r46_uw` underground spawns and torches
  (`portable_test.lua` on the real spawn roster of
  `r24_density_xp/roster.lua`: every underground row from y −1, light 7 or
  any, its `on_spawn`; the policy at the boundary, the start footprint and
  the elite floor; the sight and the 4 % elite roll of
  `underground_spawned`; `pending_level`; the torch row). `evidence/` holds
  the depth probe's before/after logs (`r24_density_xp/run.sh` with
  `POINTS=depth`: three points at y −30, −300 and −900 under Hearthpine and
  a torch room);
  `r46_id` the kind per group ingredient in the crafting box
  (`portable_test.lua`, `r45_ui`'s stubs with the real `grug_jobs` page and
  box: the dropdown only with two or more kinds carried, the choice changing
  Max, ×N and the take, the fallback to Automatic, no resend on unchanged
  values or a scroll, the dropdown inside the box; then on the real Basic
  and Cooking catalogs through `r46_ck/jobs_harness.lua` that ×N equals what
  the take takes for every recipe with a group entry, with and without a
  choice, and the one torch recipe; `--bytes` prints only the page bytes, also
  against a `git archive` of an older commit); `bench_picks.lua [REPO]
  [ROUNDS]` times the count with a choice next to `r46_ck/bench_count.lua`;
  `r46_dp` the depth pulse (`portable_test.lua`: the real
  `grug_mobs/depth_pulse.lua` on a voxel stub with a stepping raycast and
  the real particle helper and catalogue: the curve, caps and roster, the
  placement cases (open cave, corridor, sealed 7×7 room, 3×3 bunker, 1×2
  pocket, ground arrivals, water and lava), the refusals and the owed
  arrival, the 2 s warning and its 32 particles, the arrival's fields, the
  fade, the slicing and the data around the module); `pulse_curves.py`
  the design note's offline estimates (the note's options, not the decided
  curve); `probe_physical.sh` with `grug_probe_r46_dp` the engine probe
  that the cave flyers are physical; `evidence/` the depth probe's
  before/after logs (`r24_density_xp/run.sh` with `POINTS=pulse`: rooms at
  y −400, −1000 and −1500 with stand-in players);
  `r46_pl` seed-dependent POI placement: `portable_test.lua` (seed 42's
  real world: determinism and the placement text, the fixed/placed split,
  every rule on every placed anchor, the last resort, an underground
  reservation row, the zones session's anchors and the layout cache's
  placement section); `overview.lua REPO SEED PREFIX` and `render.py PREFIX
  OUT_DIR NAME` draw the whole map with zones, water, roads and every anchor
  by kind plus three 2x crops and a facts file (the user's review page);
  `bands.lua` is the record of how each placed anchor's `band` was taken
  from its pre-Round-46 position (it needs those coordinates and no longer
  runs). The Round 31 pick tools (`r31_m/candidates.lua`, `pick.lua`) are
  retired; `r31_m/spacing_check.lua` checks the placed PvP POIs per seed;
  `r46_or` the ore, gem and coal census: `run.sh OUT_DIR [TIMEOUT]` (one
  engine boot with the disposable probe `grug_probe_or`, `SEED=`) counts
  every resource per tier band in one 80 × 80 chunk column from y +127 to
  −1312 against the band's host rock (since Round 47 split at each band's
  lower-half boundary: a `lower_half_of` ore must be absent above it);
  `evidence/` holds seed 12345's Round 46 census (the rule and its pins are
  checked by `r29_mres` and `r24_mining`);
  `r46_xp` kill XP by level difference (`portable_test.lua`: the factor
  at every d from −8 to +8 and the XP table, the target frame's gradient
  and gray for every mob that pays the viewer no XP, no repeatable quest
  left and every hub line with a quest, saved state with removed quest ids,
  no "(R)" legend and a repeatable quest refused since Round 57); `r46_cb` rage by weapon speed and the spell base
  (`portable_test.lua`: rage per swing by the base interval for every
  family and the hand, the swing path's grants, the Strike tooltip, the
  spell base with an own-level, a first-tier and no caster weapon, the
  spell sites and tooltips, the caster talent amounts); `r46_lt` loot,
  coin bags and cloth (`portable_test.lua`: no sell-only drop in any row,
  the tier cloth rows, the spider band 5, the coin bag's band amounts and
  roll, the automatic deposit on pickup and its fallbacks;
  `names_proposal.json` the two new spider names); `r46_rp` repair only in
  towns (`portable_test.lua`: the trainer as the only repair provider, the
  mender's map marker and icon without a tooltip, the Help line, no
  furnace repair path); `r46_art` GPT-6 Astra's repair marker proposals
  (`paint_art.py`, `--check` verifies every PNG; `repair/` with every take
  and the user's pick A1c; the offline `review.html`), provenance for the
  user's pick, not a fixture.
  `r46_tree/concept` the approved Round 46 tree concept viewer (browser only,
  no engine work; handoff: `docs/planning/tree-rework-handoff.md`): `treegen.js` the seeded generator for all eight species (integer
  maths, written to be ported to Lua line by line), `shapes.js` the wood
  shapes (trunk quarter mesh, limb base, branch, twig; `node shapes.js`
  writes `models/*.obj`), `viewer.js` the three.js side that meshes nodes the
  way the client does, `DESIGN.md` the growth concept per species and the
  engine facts; `build.py` (`--check`, `--bark-dir`) inlines them, the repo's
  textures, today's schematics (`mts.py`) and any jungle bark candidates into
  `trees.html`; `node check.js [seeds]` checks determinism, the 16 x 16 x 32
  box, one wood piece, clean joins at the slanted trunk pieces, leaf decay
  reach for 500 seeds per species, that the .obj files are current and that
  the page's scripts parse.
- **Round 47** (`r47_<lane>`): `r47_ta` the tree shape nodes
  (`portable_test.lua`: the 28 `grug_trees:<wood>_quarter|base|branch|twig`
  nodes against `r46_tree/concept/shapes.js`, drops, groups, sounds,
  connects, placement refusal, the leaf and ground `connect_sides`
  overrides and that they change nothing else, leaf decay in radius 3,
  jungle bark M and the mesh byte-equal to their Round 46 sources, and the
  real `wp40/r6_templates.lua` turning quarters and limb grain for all four
  rotations); `capture.sh` with `grug_probe_r47_ta` the engine captures of
  a test patch (the Round 46 TREE capture brought back: Xvfb and one real
  client; bark grain, quarter lighting, seams and mirroring, template
  rotation; `SMOOTH=0`, `SHOTS=`, `SUFFIX=`), one queue run of two slots;
  `r47_tb` the Lua port of the tree generator
  (`mods/MAPGEN/grug_mapgen/wp40/treegen.lua`, pure Lua for the main and
  the mapgen environment): `write_reference.js` (`--check`) writes
  `reference.lua` from `r46_tree/concept/treegen.js` (per-seed digests of
  300 seeds per species on flat and, for the rooted species, bumpy ground,
  the root study, nine full node lists and the digest of `treegen.js`);
  `portable_test.lua` checks the port against it (and that it is pure), with
  `time` as a second argument also the time per tree per species. After a
  change to `treegen.js`, port it and rerun the writer;
  `r47_cr` the Basic recipe unlock
  (`portable_test.lua`, the real `grug_jobs` registry with the real Basic
  catalog and `basic_unlock.lua` under a stub engine): the starter set, the
  silent first scan, groups by any member, the feed line with its count,
  when the scan runs (an action or a dug node within 0.5 s, the 10 s
  sweep, one slot per step); it prints the stored set's size for a
  character that held 300 items and a scan's cost. `grug_probe_r47_cr` is
  the UI probe (formspec dumps of a fresh character's Basic list and of the
  overflow shown and hidden);
  `r47_or` the lower-half rule and the Bronze gate
  (`portable_test.lua`: the level scale, every dig time of the mining
  harness against `evidence/dig_matrix_before.tsv`, the WP43 projection pin
  moving by the two new fields only, the lower-half rows and the R6 content
  refusals, the real writer on seed 12345 across the four half boundaries);
  `run_dig.sh OUT_DIR [TIMEOUT]` with `grug_probe_dig` the engine's dig
  matrix of every pick, axe and shovel over every node a tool digs or that
  carries a level, `dig_table.py BEFORE AFTER` the before/after table
  (`evidence/`: both matrices, the table, the seed 12345 census of
  `r46_or/run.sh`); `r47_ms` the test of the migration step 0.47.0 (the
  tool capabilities stored on crafted and broken tools rebuilt at the join):
  `run.sh [EVIDENCE_DIR]` runs `test_step.py` (the offline step: markers
  only) in the runner's container and `e2e.py` (a 0.45.1 world built by the
  0.45.1 game with `grug_probe_r47_ms`, the guard's refusal, the tool, a
  boot and a join of this checkout, through the shipped `migrate.py`; before
  0.47.0 was declared it staged the game as 0.47.0 and ran the tool through
  `tool_run.py`); `portable_test.lua` the join part (stays in
  `run_fixtures.sh`); `evidence/` the last run;
  `r47_an` Anthracite (`portable_test.lua`: the ore row and node, the WP40
  rows (no Coal below T2, the T2 lower half, never rarer than Iron from
  T3), Steel only from Anthracite and the 10 s alloys with the smelting
  audit, the furnace fuels, the Claim Stone's time cap, fit refusal and
  refund through the real api, the torch triple and its Basic row, the
  enchant inputs and group tokens; `evidence/` the seed 12345 census of
  `r46_or/run.sh` before and after lane OR's merge);
  `r47_ml` the map window's marker layers (the fixture is `r44_mq`'s):
  `capture.sh OUT_DIR` with `grug_probe_r47_ml` the engine screenshots of
  every layer, the zone layer at 1x and 4x and quest mode (the TA method:
  Xvfb and one real client; `WIDTH`/`HEIGHT`, `SEED`, `SUFFIX=`), the
  pointer put over a marker by `warp.py` so each shot shows a tooltip; one
  queue run of one slot;
  `r47_tc` the trees in the world (`portable_test.lua`: the real template
  expander's variants for six sample world seeds pinned as one roll-up each,
  among them seeds above 2^53 and the u64 maximum, the seed string used
  exactly, two independent loads equal; every variant's seed, trunk foot,
  box, roots and turned bounds; the roots pass's rule; sapling growth on a
  stub world; the town trees of `wp13/dressing.lua`; the trunk markers of
  `vegetation_density.lua`; the node names against the registry). After a
  change to the generator or the species table, rerun it and renew the
  pins it prints. `forest.lua REPO SEED [CHUNKS_PER_BIOME]` writes forest
  chunks of one seed through the seed fleet's runtime and prints the
  writer's template counts (candidates, owner clips, accepted, root runs)
  and the construction's CPU seconds; `town_trees.lua REPO [all]` the
  trees each composition's dressing plants, per town; `city_trees.lua REPO
  SEED` the capitals' city trees of one seed and the CPU of deciding them;
  `city_memory.lua REPO SEED` what one capital's city trees hold and that
  their chunks come out the same in reverse order and after the idle
  release; `capital_chunks.lua REPO SEED [N]` the write time of the
  mapchunks round each capital; `capture.sh` with `grug_probe_r47_tc` the
  engine captures of forests, a grown sapling, a town and the greened
  capitals;
  `r47_fs` the furnace loop (`portable_test.lua`: the real
  `grug_ambience` on a fake engine: both burning furnaces in the `furnace`
  kind at 60 % of the fire gain, the stop on dig or blast for every
  listener with its fade, camp fires and a furnace that goes out
  unchanged); `engine.sh OUT_DIR [TIMEOUT]` with `grug_probe_r47_fs` the
  same on the real engine paths (a dig and a blast);
  `r47_nz` NPC facing and zone discovery (`portable_test.lua`: `facing.lua`
  over every composition with NPC sockets, no NPC facing a wall within two
  nodes without a work feature; the banner's 4 s; the first-entry XP, the
  single level-up sound, the visited set and its silent marks through the
  real `grug_xp` and `location.lua`);
  `r47_sw` the swamp (`portable_test.lua`: the swamp nodes, their groups,
  drops, dig times and leaf decay through the r24 mining harness; the pool
  rule of `wp40/swamp_pools.lua` and the swamp pass); the browser concept
  `swamp.html` built by `build.py` (`--check`, `--art-dir`) from
  `page.html`, `patch.js`, `mesh.js`, `view.js` and the tree concept,
  `node check.js` its patch and tree rules, `node digest.js` that the eight
  approved species stay unchanged (`species_digest.txt`); the Round 51 land
  viewer `land.html` (page content only; `--local FILE` a wrapped copy for
  `file://`) from `land_page.html`, `land.js`, `land_view.js` and the art of
  `tools/r51_land`, `node land_check.js` its patches, kit and page;
  `DESIGN.md` the swamp as built and the land viewer; `world_probe.lua REPO SEED [CHUNKS] [GRID]` the ground mix, pools
  (no water that can flow), plants and trunks through the seed fleet's
  writer; `capture.sh` with `grug_probe_r47_sw` the in-engine pool check
  and the swamp screenshots on a seed;
  `r47_art` GPT-6 Astra's swamp and Anthracite textures (`swamp/` and
  `anthracite/` with their generators and preview sheets, provenance in
  `LICENSE-media.md`; the user's picks ship in `grug_nodes`, `grug_trees`
  and `grug_materials`), provenance, not a fixture;
  `r47_td` forest render cost (a measurement, no fixture):
  `density.lua REPO SEED [CHUNKS_PER_BIOME]` counts the standing trees per
  biome and species in forest chunks written by the seed fleet's runtime
  (run it on this tree and on an export of an older commit to compare);
  `measure.sh OUT_DIR` (`MODE=forest SPECIES=<key>` or `MODE=capital`) with
  `grug_probe_r47_td` builds test forests on a sky platform (today's
  schematics, copied into the probe's `schematics/` from
  `mods/BASE/default/schematics`, LGPL-2.1+ / CC BY-SA 3.0 unmodified,
  and the game's own old gravewood from the concept's `today/`; the
  generated trees; trimmed crowns; a dense grove)
  or shows a capital, and records in one real client on Xvfb the frame
  times (Mesa's Gallium HUD dump, llvmpipe), the client profiler's draw
  calls and vertices, and the client's memory, through `drive.py`;
  `report.py RUN_DIR...` prints the tables. One measuring run per boot,
  about 4 minutes.
- **Round 48** (`r48_<lane>`): `r48_world` the mailbox on the waystone
  pads (`portable_test.lua`: the node through the real `world_nodes.lua` on
  a fake engine, its right-click with and without `grug_mail`; one mailbox
  on each of the twelve pads, off the cross arms, not beside the stone, on
  the pad, front toward the stone; none in any other composition or capital
  plot; each resolving through the real socket registry to its
  settlement's label; the mailbox art is pick A from
  `r48_artm/generate.py`); `capture.sh OUT_DIR` with
  `grug_probe_r48_world` the in-engine check of the twelve pads and one
  screenshot per pad;
  `r48_hud` the minimap's side elements (`portable_test.lua`: the daytime
  band's position over the two clock speeds, the mail badge per count,
  the one row of band and mail icon (equal drawn heights, centred) beside
  the bezel and in the corner over desktop and web windows at GUI scaling
  1 and 2, the runtime with the minimap unavailable; the
  minimap-shown runtime is `r27_minimap` block H); `gen_hud_textures.py`
  (`--check`) composes the 40 band and 10 mail images from ARTM's picked
  `parts/` and the cooldown digits; `capture.sh OUT_DIR` with
  `grug_probe_r48_hud` the engine screenshots (minimap shown and hidden,
  mail 0, 3 and 9+, day and night, with "Now playing"; `GUI=`, `SUFFIX=`;
  the r47_ml method), one queue run of one slot;
  `r48_farm` plants, light, salt and fuel (`portable_test.lua`: the real
  `grug_farming` with `default.plant_lit` on a fake engine: crops pausing
  in the dark and resuming with their progress kept, also through the
  engine's timer expiry order, the three light-exempt families, Melon and
  Mushroom with seeds and spores, the 18 families and the Basic seed rows,
  the Salt Pan (placement, filling, scrape, drops, the plain Water Bucket
  it consumes), salt renewal, papyrus, cactus and saplings, the wild looks
  and the art plan's file names, the tooltips; the fuels are in `r47_an`);
  `grug_probe_farm` the engine probe (`PROBE=` of `luanti_headless.sh`:
  noon light in a dark box, by a torch and under glass, the Salt Pan
  recipe, tooltips and wild looks);
  `r48_mail` mail (`portable_test.lua`: the pure model
  `grug_mail/model.lua`, then the real `grug_mail` with the real
  `grug_money`, the give and fit helpers of `grug_inventory` and the guards
  `grug_skills/bound_items.lua` and `grug_housing/soulbound.lua` on a stub
  engine: postage and the attachment slots in one step, the slots charged
  as they are at Send (Round 49), the guards, closing, item meta, Take all,
  refusals, `send_system` with stacks, tickets, reports, answers,
  broadcasts, expiry and the window's tabs, dialogs, reach and stale
  clicks; the admin badge and NPC seal come from `r48_artm/generate.py`);
  `capture.sh OUT_DIR` with `grug_probe_r48_mail` the engine screenshots of
  every tab and dialog of the mailbox window and Help → Mail (a stand-in
  mailbox beside the human start's waystone; the TA method: Xvfb and one
  real client; `GUI_SCALE`, `SUFFIX=`), one queue run of one slot;
  `r48_artp` GPT-6 Astra's plant art (`generate.py`, `--check`: three
  drafts for each of nine plant items, the comparison sheets in
  `previews/`, and a check that the 29 shipped files equal the user's
  picks byte for byte; `drafts/manifest.json` the picks and hashes,
  `README.md` the picks and provenance), provenance, not a fixture;
  `r48_artm` GPT-6 Astra's mail and daytime art (`generate.py`, `--check`,
  with `final_art.py`: the original proposals and the user's picks,
  mailbox A, envelope B and daytime band A, with the derived admin shield
  and NPC seal; it writes the HUD parts, calls HUD's compositor for the
  finished images and records every shipped path, size and hash in
  `drafts/manifest.json`; `previews/final.png` the final sheet at native
  and integer scales), provenance, not a fixture;
  `r48_sell` the vendor's sell side (`portable_test.lua`: lot rows over the
  carried lists, All over several slots, the greyed row below the lot
  size, a moved stack refused without loss, the money ceiling before any
  removal, the pack rule on the real `prices.lua`, each row's item tooltip
  (Round 49); the price rules and the milli-copper second pass are in
  `r29_e1`);
  `r48_admin` the Admin Mail tab (`portable_test.lua`: `grug_mail/admin.lua`
  with the real `grug_mail`, the real sfinv and `grug_inventory/ui.lua` on a
  stub engine: the privilege gates the tab and its place after Help, grant
  and revoke, the header with version and mailbox, a report's copy, Send
  answer, Close, Delete, double and stale clicks, admin letters, an
  announcement stored once and read per player, a non-admin's submission
  refused); `capture.sh OUT_DIR` with `grug_probe_r48_admin` the engine
  screenshots of the tab (the r48_mail method; `GUI_SCALE`, `SUFFIX=`);
  `r48_quest` the system quest and the game's letters (`portable_test.lua`:
  the real `grug_quests` registry, state, labels and hud, `grug_map`'s
  quest box and the real `grug_mail` with `grug_money` on the `r48_mail`
  stub engine: the system quest kind and its refusals, the starter quest's
  grant at arrival and join once, the full log skipping it, the tracker and
  log text, the turn-in by opening a mailbox with XP, 25c, the turn-in hook
  and the completion line, the welcome letter once, the level letters with
  their conditions, a jump 14 → 21 and the filled placeholders);
  `r48_bags` the bags at half size and the migration step 0.48.0
  (`portable_test.lua`: the eight bags' sizes and descriptions, the sort
  without and with target sizes (order, merge, leftovers from the end in
  the cells beyond the targets, soulbound and bound stacks never left
  over, the hotbar untouched), the join part with a
  `grug_mail.send_system` stand-in: four full 32-slot bags into 4 × 16 and
  16 letters of four stacks, a second run changing nothing, a failing send
  that loses nothing and a rerun; stays in `run_fixtures.sh`); `run.sh
  [EVIDENCE_DIR]` runs `test_step.py` (the offline step: markers only) in
  the runner's container and `e2e.py` (a 0.47.0 world built by the 0.47.0
  game with `grug_probe_r48_bags`, the guard's refusal, the shipped tool,
  boots and joins of this checkout: the sort into the new sizes, the
  letters read back from `grug_mail`'s storage, a second join); `evidence/`
  the last run.
- **Lane MGPROF** (`mgprof`, a post-round measurement, 2026-10-15): the
  per-stage Lua time of the R7 generated callback for a few chunks
  ([profile](../docs/research/mapgen-chunk-profile-2026-10.md)), no fixture.
  `run.sh stages|totals OUT [ROOT]` boots the headless server on seed 12345
  with `stages.patch` (a flat stage timer in the staged game copy only;
  replaces the stale `wp40/profile/instrument-settlement-stages.patch`) and
  `grug_probe_mgprof` (generates the pinned chunks one at a time with the
  engine profiler on, then stops); `reset_columns.py ROOT` makes a kept
  world's measured columns generate fresh again; `summarize.py [--pct]
  BOOT_DIR...` the tables (`--hash`: SHA-256 per stage); `evidence/` the
  extracted lines of boots 1–6. `INSECURE=1 run.sh ...` (follow-up 2) adds
  `insecure.patch` to the staged game, so only that run's throwaway
  server config disables mod security and the timer logs LuaJIT trace
  aborts, flushes and machine code (`GRUG_MGPROF_JIT*`).
  Since Round 49 (lane JIT) the R5 adapter has one pass: its
  `r5a_replay` mark follows `r5a_resolve_validate` directly. Round 49
  added: lane MEAS `summarize.py --first-start BOOT_DIR` (the first start
  of a fresh world from the probe's loaded, first-step and
  preparation-complete lines; `run.sh totals`, `evidence/meas-first-start`);
  lane ORE the probe's ore census; lane SKIP the `deep_skip` label; lane V7
  `EXTRA_PATCHES` and `PROBE_EXTRA` in `run.sh` and extra columns from the
  probe's config; lane MEAS2 the refreshed `stages.patch` (it applies with
  `git apply --check` again), `meas2_extra.lua` (19 extra chunks: air over
  both columns and the cave-plant bands), the census per band's lower half
  with in-range cave floors, `summarize.py --compare BEFORE... --vs
  AFTER...`, `--rates` (chunks per second by chunk type) and `--census`,
  and `evidence/meas2-boot1`, `meas2-boot2` and `meas2-first-start`
  ([before/after](../docs/research/mapgen-chunk-profile-2026-10.md#round-49-beforeafter-lane-meas2)).
  The older `wp40/profile` harness's stage patch is stale since Round 22;
  per-stage profiles use `mgprof`.
- **Round 49 lane UI** (`r49_ui`, no fixture; its checks are in
  `r48_mail` and `r48_sell`): `capture.sh OUT_DIR` with
  `grug_probe_r49_ui` shows the mailbox Write tab with the
  postage rule, the result line of a Send and the vendor's Sell tab with a
  row's tooltip (the r48_mail method; `warp_pointer.py` moves the Xvfb
  pointer onto a form position with ctypes and libX11, so the tooltip
  shows), one queue run of one slot.
- **Round 49 lane NAV** (`r49_nav`, diagnosis only, no fixture): the
  short-range chase probe `grug_probe_r49_nav` (disposable, staged with
  `PROBE=`). `run.sh OUT LABEL [TIMEOUT]` boots it through the shared queue
  (seed 12345); `R49NAV_PHASES=scenes,extra,real` picks the main scene list
  (bushes on flat ground and at or on 1- and 2-high terraces, trunks,
  distances 3–8), the second list (a strafing target, a target on a bush, a
  grove, a trunk with stubs) and natural trials on the seed's first meadows,
  deep forest and pine hills sites (bushes, blueberry bushes and trunks found
  there; the geometry round each trial is saved); `R49NAV_MOVERS` the movers
  (`zombie`, `rat`, `archer`, and `rat_narrow` = a 0.98-wide rat applied by
  the probe only; phase 1's `zombie_fix`/`rat_fix` candidates, padding
  escalation and path repair, are the real code since Round 49 NAV2);
  `R49NAV_SCENES` filters lanes. It records the navigation events (also
  `repaired`), the detector windows, the counted failures and why, the line
  tests, the engine searches, the rejected waypoints, a ranged mover's shots
  with its sight of the target, and every registered `dogshoot` mob (flier
  or ground, `pathfinding`). `summarize.py RESULTS.json` (`--events SCENE
  MOVER`, `--geometry SCENE`; a totals line per mover and phase);
  `evidence/boot1..3` the phase 1 runs; Round 49 NAV2's runs of the real
  code: `evidence/v1_scenes` and `v1_real` its first repair rule,
  `evidence/final` the merged one (every phase and mover).
- **Round 49 lane VIS** (`r49_vis`): node items in the third-person
  hand (`portable_test.lua`: the real `grug_visuals` and `player_api` on a
  stub engine: which items the engine draws as blocks, the transform at
  70 % for every pose and stature with its anchor in the fist, the player
  path through `apply` with dirt, a slab and a mesh at 70 % and a pickaxe,
  an axe, a torch and a sapling unchanged, the re-attach on a block-to-flat
  swap, an NPC holding a block); `capture.sh OUT_DIR` with
  `grug_probe_r49_vis` the engine screenshots (dirt and pickaxe in the
  third-person hand front and back, dirt in first person, the wild and field
  onions; the r48_hud method, `SUFFIX=`), one queue run of one slot; the
  onion art is `r48_artp/generate.py`.
- **Round 49 lane INV** (`r49_inv`): the Claim Stone in the carried
  lists, the Housing Steward's button, the starter kit and a granted skill
  making room (`portable_test.lua`: the real `grug_inventory/storage.lua`,
  `grug_housing` api.lua and soulbound.lua, the starter kit cut from
  `grug_factions/init.lua` and `place_on_hotbar` from
  `grug_abilities/init.lua`: the stone into `main` and every bag and refused
  elsewhere, the give helper and the sort, `can_receive_stone` per case and
  `issue_stone` on a full inventory, apples on hotbar 7 and torches on 8,
  the rightmost non-skill item making room and the no-room case);
  `capture.sh OUT_DIR` with `grug_probe_r49_inv` the engine screenshots of
  the starter hotbar, the Inventory tab with the stone in a bag and the
  Steward's window in each state (the r48_mail method).
- **Round 49 lane ORE** (`r49_ore`): ores, gems and cave plants from native
  v7 (`portable_test.lua`: the 84 native scatter rows derived from the
  resource table and the tiers, lower-half rows, the T6 split, the
  scarcity and shapes, registered after the strata; the fill ores of
  `r49_fill_ores_new` at rough rates with gems mostly singles and pairs;
  the two cave decorations); `fill_digest.lua REPO` the fill-ore
  choice over a fixed volume as one line, LuaJIT against
  `tools/bin/lua51`; `evidence/boot1..2` the lane's mgprof stage boots.
- **Round 49 lane PROT** (`r49_prot`): the protection depth under towns
  and the preparation bottom (`portable_test.lua`: the one depth constant in
  every consumer of one world, the fill-floor bottom of a high, an ordinary
  and a boundary tile); `measure_depth.lua REPO [seed ...]` the deepest
  place a player stands in a town below its placement height and the city
  edge's reach (what the depth is sized from; about 40 s per seed);
  `count_tiles.lua REPO [seed ...]` the full-preparation tiles and extra
  chunks the fill-floor bottom changes, from the real preparation authority
  without generating (about 75 s per seed).
- **Round 49 lane SKIP** (`r49_skip`): no Lua for chunks below every
  writer (`portable_test.lua [SEED]`: the rock-below test's bounds on a
  synthetic envelope, the air test's owner-first order against a verbatim
  copy of the Round 23 code, and the real runtime of one seed: chunks under
  every settlement, the lowest fitted box, the highest mountain, a dragon
  channel, a deep ocean and the corpus columns); `run_verify.sh OUT` one
  verification boot with `verify_patch.py`'s disposable patch (the full
  writer on every chunk, the VoxelManip compared on each chunk a test would
  skip: content, param2 and light of the chunk and its shell) and the probe
  `grug_probe_r49skip`; `evidence/mgprof` and `evidence/verify` the lane's
  boots.
- **Round 49 lane JIT** (`r49_jit`): the R5 adapter's one compilable pass
  (`portable_test.lua`: on seed 12345 with v7's stand-in ground moved
  off the plan, the runtime adapter with its classification memo and the
  validating adapter write the same bytes, result and dirty counts, also
  with flowing water of every level; an out-of-range param2 still fails in
  the classifier); `fleet_digest.sh TREE OUT [perturb]` (through
  `fleet_digest.lua`) the bytes of every chunk the seed fleet's quick seeds
  write, for comparing two trees (`JOBS`, `COUNT`; `perturb` moves the
  ground as the fixture does); `evidence/` the lane's receipts: `boot1`
  (the one-pass adapter before the zones key fix) and `boot2` (the lane's
  final state), each `INSECURE=1 tools/mgprof/run.sh stages` like MGPROF's
  boots 5 and 6 (`summarize.py`), and `digest/` the chunk bytes of main
  `f8f2d134` and of the branch (the 100 quick seeds, and 40 with `perturb`),
  and the same for main `1b965ec4` and the branch merged with it.
- **Round 49 lane V7** (`r49_v7`, measurement only, no fixture): the v7
  flags `nomountains` and `noridges` one at a time against main.
  `grug_probe_v7pick` (disposable, staged with `PROBE=`, no generation)
  ranks every land chunk column of the seed by v7's own noise (mountain
  stone above our surface, mountain stone under it, river channels under our
  land) and checks the best ones for ordinariness; `columns.lua` pins its
  picks as extra chunk columns of the mgprof probe (`config.extra`);
  `run.sh baseline|nomountains|noridges OUT` is one fresh-world
  `tools/mgprof/run.sh stages` boot with `tally.patch` (the R5 voxel tally:
  cleared v7 rock, filled void, kept native cave content) and, for a variant,
  `flags-<variant>.patch` (the staged `minetest.conf` and the live flag
  check of `r7_runtime.lua`); `summarize.py [--compact] NAME=OUT ...` the
  side-by-side tables; `evidence/` the picker log and the five boots
  (`baseline`, `baseline2`, `nomountains`, `nomountains2`, `noridges`).
  Since lane V7A adopted `nomountains` (Round 49) `baseline` runs the game's
  own flags, `nomountains, ridges`, and the two flag patches no longer
  apply; `evidence/v7a` is V7A's boot of the adopted flag, `evidence/v7a-reset`
  a simulated map reset (a fresh world, then its `map_meta.txt` set back to
  `mountains`, the map emptied and `grug_reset_world = 1` via `reset.patch`):
  it boots and `map_meta.txt` holds `nomountains` again (r7_native forces it).
- **Round 49 lane CACHE** (`r49_cache`): P9G's 2-D result per chunk column
  and the mapgen column cache (`portable_test.lua`: on two real runtimes of
  seed 12345 with moved ground, a hit writes the same bytes as a miss,
  misses and evictions counted, the key covers its inputs);
  `run_probe.sh OUT` one shell-order probe boot (`grug_probe_r49cache`:
  chunks in the order a walking, riding and a second far player emerge
  them) with `stages.patch` and `counters.patch` (cache hits, misses and
  evictions), summarized by `analyze.py`; `fleet_stack.sh TREE OUT
  [perturb]` (through `fleet_stack.lua`) the quick seeds' chunks with the
  chunks above and below them, for comparing two trees; `evidence/` the
  probe before and after, the mgprof boots and the digests.
- **Round 49 lane HASH** (`r49_hash`): the integer placement hash
  (`portable_test.lua`: the same draws under LuaJIT and `tools/bin/lua51`
  over `sample.lua`'s sample, uniformity, neighbour correlation, stream
  and seed independence, no grid or diagonal artefacts, distinct salts,
  the catalog rates, no lattice period and no point mirror; section J the
  P8 follow-up's per-chunk cube decisions against a reference without
  memo); `density.lua REPO [SEED]` decoration, tree and gathering counts
  per chunk through the seed fleet's harness, compared with
  `density_compare.py`; `topview.lua REPO SEED X Z` a letter map of a
  3 × 3 chunk area, `topview_png.py` its image (`shots/` the lane's views);
  `evidence/` the densities, the quick fleet and the mgprof boots (before,
  the first mix, the cube mix).
- **Round 49 P8 follow-up** (`r49_p8`, evidence only; its test is
  `r49_hash` section J): `evidence/README.txt` the fill-ore pass's time
  per corpus boot before HASH, with HASH's two mixes and with the
  per-chunk cube decisions, `mgprof-after` its stage boot and
  `fleet-digest-quick.txt` the quick seeds' chunk bytes (identical to main
  `62123545`).
- **0.49.1 study HKEEP** (`r491_hkeep`, study only, no fixture): keeping the
  chunk columns of player claims at a map reset
  ([study](../docs/research/housing-keep-reset-study.md)). `run.sh OUT` three
  boots of the disposable probe `grug_probe_hkeep` on throw-away worlds
  (seed 12345, a kept column and its 3 × 3 neighbours over three layers):
  a fresh world with markers, then the same seed and a changed seed after
  `keep_columns.py` deleted every block outside the kept column; each boot
  one queue slot; `evidence/` the three boots and the summary.
- **0.49.1 lane VIEW** (`r491_view`): the combined bag in every station
  form (`portable_test.lua`: furnace, workspace furnaces, chest and locked
  chest, bookshelf, vessels shelf and Claim Stone built for a player with
  0, 1 and 4 bags: the lists, the shift-click rings, the scroll container,
  the scroll position across re-shows, per viewer); `capture.sh OUT_DIR`
  with `grug_probe_r491_view` the engine screenshots of each form with four
  bags and of a burning furnace, scrolled (the r48_mail method).
- **0.49.1 lane DOOR** (`r491_door`): doors before NPCs
  (`portable_test.lua`: the real `grug_mobs/door_click.lua` on a box world
  whose ray orders hits like the engine's RaycastSort; wherever the engine
  points at a dialog NPC behind a closed door, in both halves and from both
  sides, the door takes the click; an open door, no door, an NPC in front,
  a sneak click, another node and a server ray that misses the NPC (a touch
  tap off the crosshair) leave it to the NPC; every dialog NPC asks the
  helper first);
  `probe.sh [OUT]` one probe boot (`grug_probe_r491_door`: the engine's
  first hit with an NPC behind a closed door, an open door and no door,
  then the helper on the same rays and one click per real dialog NPC kind);
  `evidence/` the probe before and after the fix.
- **0.49.1 lane DROP** (`r491_drop`): drops a client draws sliding and
  cannot pick up (`portable_test.lua`: A the real vendored
  `default/item_entity.lua` over a fake builtin item, the resting position
  sent again 0.5 s and 2 s after a landing or an ice slide and never for an
  item lying still; B the real `grug_abilities/input.lua`, the plain pickup
  at once, the punched drop the server ray misses, the reach, a combat press
  through the loot, held and punch-less presses). `repro.sh OUT` (`XVFB=`,
  `LOSS=`, `WAVES=`, `SEED=`; two queue slots) the reproduction: the server
  with `grug_probe_r491_drop` and one real Flatpak client in a private
  unprivileged network namespace whose loopback drops LOSS % of the packets
  (netem), the client mod `r491scan` logging where the client draws each
  object, mob-style drops thrown at Bannerbreak Warhold, plus server-side
  cases against and inside walls and on steps; `analyze.py OUT` the
  comparison (sliders, their client speed against the server's last flight
  speed, the lead cases).
- **0.49.1 lane ANIM** (`r491_anim`): the furnace's fire and arrow as
  animated images, the form re-sent only at a change of state
  (`portable_test.lua`: the frame starts and the buffer of
  `grug_inventory/furnace_progress.lua`, its change check, scripted burns
  through the plain furnace's timer and the workspace furnace and dual
  furnace's one-second pass with the re-send points, no animation running
  out before a re-send and the cooking results; `portable_test.lua REPO
  measure` the formspec bytes of a burning minute, also against an older
  tree); `gen_furnace_strips.py [--check]` the two frame strips from the
  minetest_game furnace textures; `capture.sh OUT_DIR` with
  `grug_probe_r491_anim` the engine screenshots of a burning workspace
  furnace a few seconds apart and the re-sends counted (the r491_view
  method).
- **Round 50 lane PACCEPT** (`r50_paccept`): the map-reset packing end to
  end. `run.sh [EVIDENCE_DIR]` (one queue slot; `e2e.py`, its header): the
  real 0.48.1 game (`OLD_GAME`, default the worktree `r50-v0481` at
  1ef11b5e) builds a world with the probe `grug_probe_r50_paccept` (created
  characters keeper, neighbor and drifter; two fuelled claims; a chest with
  a quality sword, a locked chest, a lit furnace, a bookshelf and a vessels
  shelf with written books, a chest holding the probe's own item, an empty
  chest and an empty furnace, a cellar chest, a chest outside the claims)
  and writes the receipt at the shutdown; the shipped tool `--check
  --map-reset` and `--map-reset` in the runner's image on SQLite and, with
  `pg_pass.py`, on PostgreSQL in the platform's layout (seeded from that
  world, `pg_dump`, `TRUNCATE public.blocks`); the map emptied and
  `grug_reset_world` raised; two boots of this checkout per backend with
  joins: notices, the first-start clean-up (contents in `packed:*`, the
  empties as plain stacked items), the draft and active stone forms, every
  entry taken and every packed container placed (its stored contents
  deleted) and read back against the receipt, the charcoal, and a second
  boot that changes nothing. `FIXTURE=<dir>` packages the 0.48.1 world for the platform.
  `reset_like_platform.sh <world dir> [SERVER_CONF]`: a local SQLite test
  world reset the platform's way (backup, the tool, the map rows emptied,
  `grug_reset_world` raised above the world's record in SERVER_CONF); it
  refuses the personal Luanti folder, a non-SQLite world, an unwritable
  config and a running server. `test_reset_like_platform.sh`: its checks
  on copies of `r50_ptool/world` (the refusals, a world reset before, a
  rerun, no config), no engine run.
- **Round 50 lane PGAME** (`r50_pgame`): packed containers and the Claim
  Stone inventory (`portable_test.lua`: the tool's pass written as the
  plan's §3 describes before the load, cleaned by the real grug_core runner
  and `recovered.lua`: unknown items, an unknown node and a shrunken list
  into extra packed chests, a split charcoal stack, the descriptions and
  images, an older pass untouched, a rerun and a half-done rerun; the
  entries across `M.map_reset`; `CONTAINER_LISTS` against the vendored
  `set_size` calls; the soulbound guards and the refused drop; the
  Belongings tab of the active stone only, take-only, stale slots, a closed
  form, a full slot, pick-up and loss; every kind placed with exact
  contents through the real chest code and stand-ins; the join notice and
  the Steward's line). `capture.sh OUT_DIR` (`XVFB=`) with
  `grug_probe_r50_pgame` the engine screenshots of the draft form, the
  Belongings tab, two packed tooltips (the pointer moved by
  `r49_ui/warp_pointer.py`) and two restored containers, and an in-engine
  check of every placement ("place ... ok" in `probe.txt`).
- **Round 50 lane HOTBAR** (`r50_hotbar`): the two hotbar layouts A and B
  (`portable_test.lua` on the `r44_ch` harness: joins, the swap with wear
  and metadata, the anti-spam limit, a failing switch callback, the hidden
  list's guard before equipment, bags and quiver, give/fits/sort never
  reaching it, the soulbound rule, every consumer of the study in its order
  (crafting, ammunition, quests, Claim Stone fuel, Fallen Crown, vendor,
  repair), `normalize_kit` per layout and the kit on the shown layout, the
  switch callback with the real cooldown overlay, death and the map reset,
  and the switch in the inventory pages, a node form, a chest and the
  quickbar; the workspace, the Claim Stone form, its Belongings tab and the
  mail's Write tab are in `r491_view`, `r50_pgame` and `r48_mail`).
  `capture.sh OUT_DIR` (`XVFB=`) with `grug_probe_r50_hotbar` the engine
  screenshots of the Inventory page, a chest and the quickbar with B shown.
- **Round 50 lane PTOOL** (`r50_ptool`): the migration tool's pre-reset pass
  (`--map-reset`). `test_pack.py` (Python unittest, locally on Python 3.14
  and in the runner's image on 3.13 with python3-zstandard): the block
  decoder against `world/`, a world the engine wrote (every block decodes;
  every placed container's node name, lists and slots; node fields and
  private flags; refusals), the pass on copies (events and counts, every
  entry against the probe's record, charcoal rounded up, the area's border
  and MIN_Y, two passes appending, the pending-marker refusal, a restored
  backup, the game's `recovered:…:<n>.<k>` keys kept, `pack_baseline`, steps
  after the pass, `--check --map-reset` as the dry run (its counts equal the
  pass's, every refusal reproduced, nothing written), a bad block, an
  emptied map, odd claim records, the pre-5.12 SQLite layout, backends, the
  read-only map, the lock), and the game facts pack.py freezes
  (registry.lua, api.lua, workspaces.lua). `pg_test.py` (in the image,
  through Round 43 IT's helpers): the map and the backends on PostgreSQL and
  in the platform's layout, every recovered row equal to SQLite's, the
  shipped command line, the map rows unchanged, the read-only session.
  `run.sh [EVIDENCE_DIR]` (one queue slot): both in the image, then a boot
  whose probe reads every packed entry back with `ItemStack` and
  `core.deserialize`. `world/` was built by `make_world.sh OUT_DIR` with the
  probe `grug_probe_r50_ptool` (two claims of grug_housing's model, a chest,
  a locked chest, a lit furnace with a workspace record, a bookshelf with
  written books, a vessels shelf, a chest of 32 long books, an empty chest,
  border chests) and trimmed to the claims' blocks by `trim.py`.
- **0.50.2 lane CMAP** (`r502_cmap`): the Claim Stone preview on the
  minimap (`portable_test.lua`: a claim's rectangle in a cell texture
  rounded outward and clipped at every edge, fully outside, on an edge and
  of zero size, and every `[fill` of a recipe and of the player's square
  inside the engine's limits; the claim-set version and `claims_in` of the
  real registry, `column_problem` against validate; the real render's
  overlays on a small synthetic world at normal and a reduced "high" size:
  refused pixel centres red and widened, the settlement margin red, no
  square that touches no red refused; the real minimap.lua in claim mode:
  the overlay tiles and fills, the same string for the same claims, a draft
  shown and gone without re-selecting the stone, another item, no faction,
  the switched-off minimap and its side row). `render_overlay.lua <repo>
  <seed> <out> [quality]` renders the overlays on the real world of one
  seed (`tools/r25_road_poi/world.lua`), times them and checks that random
  squares touching no red pass validate; `bench_claim.lua <repo>` the
  packets, bytes and µs per step with and without the stone, and the cell
  textures of an hour's walk. `capture.sh OUT_DIR` (`XVFB=`) with
  `grug_probe_r502_cmap` the engine screenshots (a border, a settlement, a
  draft in view, the switched-off minimap) on a fresh world, so it is also
  the smoke boot that renders the base and both overlays.
- **0.50.2 lane HOME** (`r502_home`): claims named in the location line and
  banner and framed on the minimap (`portable_test.lua`: the banner rule,
  a change replacing a running display and restarting its time; through the
  real location.lua and registry "Your Home" and "<owner>'s Home" in every
  claim state, y −100 in and −101 out, the edge node in and the next out,
  the territory line and the discovery's zone unchanged, a zigzag across a
  claim's edge; the frames' geometry, the outward-rounded box's border one
  pixel wide, clipped exactly at every edge with valid fills; the real
  minimap.lua: the plain string with no claim near, own green and others
  yellow, every state, the same string for the same claims, claim mode
  unchanged). `bench_sample.lua <repo>` the location sample's µs with and
  without the claim lookup; the minimap's packets, bytes, µs and textures
  come from `tools/r502_cmap/bench_claim.lua` run before and after.
  `capture.sh OUT_DIR` (`XVFB=`) with `grug_probe_r502_home` the engine
  screenshots (both frames, "Your Home" and "<name>'s Home" with their
  banners, the stone held) on a fresh world, the smoke boot, and the
  sample's engine cost. It sets each draft's stone only after
  `core.emerge_area` generated its area (a node set into a chunk not yet
  generated makes the refinement refuse the chunk).
- **Round 51 lanes SWART and ARTL** ([`r51_land`](r51_land/README.md), art only, no fixture): original CC0 land art by GPT-6 Astra, deterministic Pillow generators: `swamp_calm.py` and `swamp_art.py` the calm swamp grounds of the texture lab, `land_art.py` (`--check`) the 32 px grounds and the plants, `props_art.py` (`--check`) the props in lane VIEW's prop format (`prop.json` plus six 16 px tiles per prop, the format in the README), with preview sheets and check records; the user's picks ship in `grug_nodes` and `grug_trees`.
- **Round 51 lane ARTS** ([`r51_sea`](r51_sea/README.md)): original CC0 seagrass and wreck textures, deterministic Pillow generator (`python3 -I tools/r51_sea/sea_art.py`, `--check`), and the attributed sea-art comparison sheet.
- **Round 51 lane TERRAIN** (`r51_terrain`): T1, the larger world
  (`portable_test.lua`: the bounds agree in every place and the new ring
  reads as open sea; `compare.lua REPO SEED OUT` dumps the world inside the
  old bounds for a before/after diff, `diff_dumps.py BEFORE AFTER` summarises
  two dumps, `grid_cost.lua REPO SEED [N]` the terrain grids' build time and
  heap; `mgprof_extra.lua` the edge and ring chunks for `tools/mgprof/run.sh`
  (`PROBE_EXTRA=`); `grug_probe_r51_terrain` reads the new ring in the engine,
  `PROBE=` of the smoke boot). T2, the sea's shape: the fixture's part C (the
  water query, bay rims, the belt, the channels and a boat's path, protected
  water at 23/24/25 nodes off the coast, Stormkelp's shore);
  `diff_land.py BEFORE AFTER` compares two `compare.lua` dumps on land only;
  `sea_survey.lua REPO SEED` the bay rims (before/after), the belt's width,
  the depth profile, the wreck band, brightness, protection and the channels;
  `mgprof_t2_extra.lua` the coastal and channel chunks; the probe (boot it
  with `SEED=12345`) also reads the query and the protection in the engine.
  T3, seabed growth: the fixture's part D (the rule's depths, written chunks,
  the water-plant exception, seagrass and kelp regrowth through the real
  renewal); `seabed_survey.lua REPO SEED [CHUNKS]` the shares of coral, kelp
  and seagrass per water class from chunks written by the real writer.
- **Round 51 lane NAMES** (`r51_names`, design only, no fixture): the water
  families' ladders and names. `survey.sh` (through the Lua queue, 4
  processes) runs `water_survey.lua` per seed: the game's region builder
  counts per zone belt the cells near sea water and near lakes and rivers
  (`survey/seed_<seed>.json`); `build.py [--check]` expands `design.json`
  over the belts into `draft.json` (sub-type rows, world slots, zone slots
  in the Round 38 proposal format) and the preview page `page.html`
  (`page_local.html` for file://); `check_draft.py` runs the Round 38 name
  gates over today's names plus the draft.
- **Round 51 lane WRECK** ([`r51_wreck`](r51_wreck/DESIGN.md)): the shipwreck design: four shapes as data (`shapes.py` writes `shapes/*.json` and the node list, `--check`), the preview page (`build.py` writes `wreck.html`, `--check`) and the placement sketch; the build step: `to_lua.py` (`--check`) turns the shapes into `wp40/wreck_shapes.lua`, `portable_test.lua` (the nodes, the data, the placement on a synthetic sea, the pass on a fake successor context), `count.lua REPO SEED [N]` (the wrecks of a seed per shape and zone, and the real write of the first N wrecks' chunks with and without the pass) and `capture.sh` with `grug_probe_r51_wreck` (the in-game test and the screenshots).
- **Round 51 lane LK** (`r51_lk`): the land kit: `gen_props.py` writes the prop nodes' data and tiles from `tools/r51_land/props` (`--check`), `portable_test.lua` the fixture (props, drops, kit rows against the viewer, variants, roster, town graves and bones, one seed's chunks with no floating cell), `region.lua REPO SEED [N]` the plan and write seconds and kit counts in fixed chunks (before/after), `capture.sh OUT_DIR` (`XVFB=`) with `grug_probe_r51_lk` the engine counts and screenshots per kit biome and Stillgrave.
- **Round 51 lane LG** (`r51_lg`): the land grounds and nodes. `portable_test.lua` (r24 mining harness): every 32 px world-aligned and 16 px face, the shipped files against the picked art of `tools/r51_land`, the swamp moss and the clay bands with their host lists, the sand override, the hanging moss strand/end dig rule and the world's moss runs, the closed node roster; `capture.sh OUT_DIR` (`XVFB=`) with `grug_probe_r51_lg` the engine look once: a sky test patch of the 2 × 2 grounds, the clay band wall, a sand basin with water and a hanging moss run before and after its end is dug.
- **Round 51 lane MAP** (`r51_map`): the sea coloured by depth, the larger atlas and the map qualities. `portable_test.lua`: colour per class and depth on a synthetic world through the real render (lakes, bays, belt, channel, open sea, the soft edge, pockets, coast lines), the atlas geometry at the new edges, the quality sizes, the cache key; `capture.sh OUT_DIR` (`XVFB=`, `QUALITY=normal|high`) with `grug_probe_r51_map` the map window at 1x and at 4x on a bay, a channel and the belt's edge and the minimap at a coast. Offline renders: `tools/r27_minimap/render_base.lua` (atlas from `atlas.lua`, `R27_ATLAS=` for an older tree's bounds).
- **Round 51 lane TERRAIN, step T4** (`r51_t4`): the land surfaces after the picks. `portable_test.lua` (the r23 tree-line harness and the real strata pass): the swamp moss in every swamp mapgen place and the moss soil in the elf forest, the clay bands on stepped badlands slopes and laid by height down a face, the ice and pebble patch shares, the roster and the spawn-region ground; `compare.lua REPO SEED OUT [time]` dumps fixed swamp, steep badlands, snowy crags and coast chunks through the real writer (or times 3 × 3 chunks round each) and `diff_dumps.py BEFORE AFTER` checks that only the expected surface nodes change and no ground height moves; `capture.sh OUT_DIR` (`XVFB=`, `SEED=` default 12345, `SPOTS=`) with `grug_probe_r51_t4` the closing engine run: the surface nodes round a swamp, steep badlands, snowy crags and a coast spot and a wide and a close screenshot of each.
- **Round 51 lane MOBS** (`r51_mobs`): step M1, the water mobs
  (`portable_test.lua`: the sub-types, fish drops and names against the
  NAMES draft, sub-type selection at every ladder edge with level 20 by its
  belt, the real registrations, and the swimmer reset in the real leash
  tick with the reach veto). `probe.sh OUT_DIR` (one queue slot) with
  `grug_probe_r51_mobs`: every new mob spawned by command in an arena,
  frog and tortoise chasing a probe player ashore and back, the stingray's
  reset, one kill per family and its fish. `capture.sh OUT_DIR` (`XVFB=`,
  two queue slots) with `grug_probe_r51_shots`: screenshots of the
  line-ups. Step M2: `water_kinds.py [--check]` writes the recipes' water
  kinds from the NAMES draft; the fixture adds the recipes' water kinds,
  the water attempt (cut out of spawn_regions.lua) and the shark and goby
  rows; `bands.sh OUT_DIR` (one queue slot, the production seed) with
  `grug_probe_r51_bands` counts the water spawns per band at stand-in
  players over each band and the world rows' attempts. Follow-up FM: the
  fixture adds the steady swimming height (part H, `falling()` cut out of
  `mobs/api.lua` and simulated with the quarter-second `standing_in`), the
  frog's swim clip (part I) and the lake fish (part F); `probe.sh` also
  samples the float height of idle water mobs in a deep pool and chases
  over a one-node bank; `lakes.sh OUT_DIR` (one queue slot, the production
  seed) with `grug_probe_r51_lakes` checks every capital's own lakes for
  columns open to a tortoise or a frog and counts the fish and the spawns
  at the capitals' lakes and three wild lakes.
- **Round 51 lane LP** (`r51_lp`): the land plants. `portable_test.lua` (the seed fleet runtime of seed 12345, built as the engine builds it): the plant nodes (drawtype, alpha, no glow, no drops, the picked art byte for byte, decay, the liana pair), every LP row and its hosts and density in the vegetation authority, the plants on written jungle, elf forest, crags and warm-beach chunks (papyrus stacks at the water, marram on dry sand, lichen patches, lianas), their regrowth through renewal, the template lianas, the node roster; `density.lua REPO [SEED] [PER]` counts the plants and the plan and write seconds of the same chunks on any checkout, for before/after comparisons. `capture.sh OUT_DIR` (`XVFB=`) with `grug_probe_r51_lp` the engine look once: sky strips of the plants beside their zones' gathering sources, then the nearest generated jungle, elf forest, crags and warm beach, each counted and shot.
- **Round 51 follow-up FW** (`r51_fw`): the water plants after the user's GUI look. `portable_test.lua` (pure seabed rule plus the seed fleet runtime of seed 12345): meadows and coral patches fade out (fill by distance from the old outline, tufts beyond, variants mixed, a coral rim across the cell side), the wild lakes' lily and weed rule, writer and vegetation authority agree on a belt and a lake chunk (Lethariel's lake stays bare), lake regrowth through renewal, the animated tiles and the picked strips byte for byte. `meadow_edge.lua REPO [SEED] [DEPTH] [SIZE]` measures the edges on any checkout, `lake_survey.lua REPO SEED [CHUNKS]` the lake plants, beds and writer/renewal agreement, `chunk_cost.lua REPO [ROUNDS]` the CPU time of sea and lake chunks; `capture.sh OUT_DIR` (`XVFB=`) with `grug_probe_r51_fw` the engine look once (a meadow's edge from above and under water, a kelp stalk twice, a lake's lilies).
- **Round 51 follow-up lane FT** (`r51_ft`): the towns after the user's GUI look. `portable_test.lua`: the six starts' trees halved with every quarter kept, the capitals' trees unchanged, Stillgrave's burial grounds unchanged and its outside bones sparse, the capital cores' cover cut and patchy, the city ground cover and lake plants on a synthetic city (open ground only, the seam rule) and on seed 12345's real capitals (the overlay palette); `city_cover.lua REPO SEED` counts each capital's city cover, bones, lily pads and weeds and the CPU of trees and cover; `capture.sh OUT_DIR` with `grug_probe_r51_ft` the engine look (a start, Stillgrave, the cores, an outskirt, the lakes).
- **Round 52 lanes ARTA and ARTB** ([`r52_art/arta`](r52_art/arta/README.md), [`r52_art/artb`](r52_art/artb/README.md), art only, no fixture): the class rework's staged art by GPT-6 Astra, CC0, in numbered drops with previews and manifests: the tree backgrounds (image generation, post-processed by `arta_bg.py`) and the weapon overlay strips (Pillow generators `arta_fx*.py`), the talent and skill icons (image generation, packaged by `build_drop.py` and `build_full_set.py`). The picked files ship through GRAPH and WFX (`grug_classes`, `grug_abilities` `LICENSE-media.md`); the 25 icons of round K's new skills wait here. About 40 MB.
- **Round 52 lane SPLIT** (`r52_split`): the per-class kit and talent files' registration dump against main `7813165e`; its job ended in Round 52, retired in Round 53.
- **Round 52 lane SND** (`r52_snd`): the ambience cuts for the biome groups, staged and not shipped. `cut.py [scan|build] [--only KEY]` (ffmpeg with libvorbis) measures each picked source's momentary loudness, picks the loop window (no bursts, nothing loud in the crossfade zones, both ends level, near the excerpt the user heard) and writes `out/` (beds: 2 s loop crossfade, 60 Hz high-pass, -20 LUFS, Vorbis q1; calls: trimmed, -3 dBFS peak, q3), `windows.json`, `picks.md` and `license-rows.md`; `build_page.py` writes the listening page `page/index.html` with the audio inlined (`page/local.html`, gitignored, for file://).
- **0.52.1 lane UW** (`r52_uw`): the underwater bed candidates, staged and not shipped. `search.sh` and `fetch.py` (serially through `r34/fs_run.sh`) find and download CC0 Freesound previews into the orchestration folder `sound-r52u/`; `cut.py [scan|build]` (ffmpeg with libvorbis, reuses the `r52_snd` cut functions) picks each loop window by a loudness scan (plus level spread and high-band clicks) and writes `out/uw_<n>_<source>.ogg` (30 s loop, 2 s crossfade, 60 Hz high-pass, -20 LUFS), `windows.json`, `picks.md` and `license-rows.md`; `build_page.py` writes the listening page `page/index.html` with the audio inlined (`page/local.html`, gitignored, for file://).
- **Round 52 lane CORE-B** (`r52_core`): the area helpers and readiness windows of the class rework. `portable_test.lua` loads the real `grug_core/area.lua`, `particles.lua`, `particle_effects.lua`, `status.lua` and `grug_classes/talent_windows.lua` on a fake node map with a stepping raycast: the ground search and anchor (steps, stacked floors, caves, shallow and deep water, plants, flying mobs), the area query (radius, ±3 band, walkable-only line of sight, order, cap), the delayed impact (particles, leave and death), the group helper, an area heal's status ticking outside the area, and the windows (consume once, monotonic ICD, icons, today's trigger clock untouched). `probe.sh OUT_DIR` (one measuring-queue slot) with `grug_probe_r52_core` casts a probe-only area ability on built scenes and logs anchors, refusals, hits and particles per cast.
- **Round 52 lane GRAPH** (`r52_graph`, live since Round 53): the graph talent trees and the scrolling skill row. `portable_test.lua` (on the `r44_ts` stub world, which loads the real graph files through `talents.lua`) checks the registry against the node list (ids `<tree>_<name>`, Warding Faith at 5 ranks, no unit letters in the node texts, icons by the name part), the audit's refusals and the `reach_cost` filler, the candidates' worked 30-point builds adapted to the node list, the gates on the spend and read paths with the same texts (a 0.52 string reads as zero ranks), refunds and the full reset, the live Talents page (tabs in the sfinv context, background or plain fallback, connectors, icon or text nodes, the sample builds' node states, a refused click's text, the armor and pool amounts at the level, no class), the layout of all eight trees, and the skill row's scrolling (C13); it prints the page content's bytes per tree. `capture.sh OUT_DIR` (`XVFB=`) with `grug_probe_r52_graph` the engine screenshots of the live page (a level-60 Scout's two tabs) and the scrolled skill row.
- **Round 52 lane AMB** (`r52_amb`): ambience by biome and height. `portable_test.lua`: the biome groups against the world's surface rows, the sound key, the layer curves at the ruling points, a layer's steps (start at 3 %, dead band, 0.01 floor, stop after three passes), the cave verdict and the probe's reuse, the depth helper and its column memo and the atmosphere's underground band on a fake engine (`grug_core/atmosphere_zones.lua`), calls by sound key; the runtime of the layers is in `tools/r34_s2`. `engine.sh walk|calib OUT_DIR` with `grug_probe_r52_amb` (`REPO=` another tree for the before numbers): the passes on a scripted walk (surface, a busy mine, a tower, a fast flight), or the cave-probe calibration (natural v7 caves against dug tunnels, the probe's cost) and the peak heights; `capture.sh OUT_DIR` (`XVFB=`) the debug-line screenshots of each calibration case.
- **Round 52 lane CORE-A** (`r52_bench`): the action clock, the transformation field and Mend on statuses. `portable_test.lua` loads the real `grug_abilities/init.lua` with its whole dofile chain in a sandbox: `normalize_kit`, `is_unlocked` and `unlocked_ids` against a frozen copy of main's for every shipped kit and talent state, the in-place swap with probe definitions, the clock's three directions, Mend's ticks through the real `grug_core/status.lua`; `run.sh OUT_DIR [TREE]` (`LAUNCHER=`) with `grug_probe_r52_bench` the PvE bench, each class against a passive dummy through the real input, cast and swing paths, logging every action (crit and dodge 0, seeded); `compare.py BEFORE AFTER` compares two logs exactly, cadence within one server step, Mend's ticks apart.
- **Round 52 lane WFX** (`r52_wfx`): the element overlay on the first-person weapon. `portable_test.lua` loads the real `grug_abilities/init.lua` with its dofile chain in a sandbox, as shipped and with a test animation table and test strips patched in: the family of every skill, the overlay off without picked strips, the strip name per family and weapon type through the real skin pass (the bow draw stages were retired with the draw in Round 53), the transparent override for the empty slot, Strike and unpicked strips, the third-person holder (`grug_visuals/apply.lua`) and every shipped strip's name, size, animation and licence row. `capture.sh OUT_DIR` (`XVFB=`) with `grug_probe_r52_wfx` and a throwaway strip from `make_strip.py`: the engine screenshots proving the definition's animation applies to a meta-overridden overlay name, the empty slot and third person.
- **Round 52 lane PFX** (`r52_pfx`): the particle effect cards for the 44 reworked skills (design only, nothing in `mods/`). `effects.py` holds every card in `particle_effects.lua`'s emitter format (keep, retint, new or none; hook, frame fields, sprite proposals) and writes `data.json` (costs and the 5/20/50-player fights, through `cost.py`, which extends `r40_v3/cost_model.py`) and `emitters.lua`; `check_limits.lua` (luajit, from the repo root) runs the real `particles.check` on every card and compares keep and retint cards with the shipped catalogue; `build_page.py [--check]` writes the German preview page `page/index.html` (animated previews, the fight calculator, ratings; `page/local.html`, gitignored, for file://).
- **Round 53 lane LIVE** (`r53_live`): the graph talents as the live talent engine. `portable_test.lua` (on the `r44_ts` stub world) buys every tree's sample build through `spend_talent` and through page clicks, checks illegal spends on the spend path (with the page's strip) and the read path with the same texts, a 0.52 string reading as zero ranks with the old registry loaded and inert, `get_talent_bonus` over shared, class and family keys (`armor_percent_add` at levels 10 and 60), the talents-changed callbacks, the respec prices, the level-drop reset and its feed line, `/talents` and the Mercy sample for 33 ranks; it prints the page's bytes per class.
- **Round 53 prep lane SKS** (`r53_sks`): cast-cue candidates for the new class skills, staged and not shipped (sound gate). `sources.py` resolves each source (local packs and Freesound HQ previews in the orchestration folder, read only) to its author and licence; `scan.py` measures the source pool into `pool.json`; `fs.py search|fetch` (only through `r34/fs_run.sh`, serial) found and fetched the missing Freesound previews; `cut.py [--only ROW]` (ffmpeg with libvorbis) writes `out/<skill>_<n>_<source>.ogg` (candidate 1 the shipped cue the round plan reuses, copied unchanged; the rest mono Ogg q3, trimmed, faded, -3 dBFS peak), `cuts.json`, `picks.md` and `license-rows.md`; `build_page.py` writes the German listening page `page/index.html` with the audio inlined (`page/local.html`, gitignored, for file://). Round 2 (the user's ratings, snapshot `ratings-r1.json`): `assign.py` turns them into `assignments.json`/`assignments.md` (per row the chosen sound and the quote that justifies it, plus the open questions), `annotations.md` (every note, kept for later) and `rejected.json`/`rejected.md` ("raus": never cut or fetched again); `build_control.py` writes the German control page `page-control/index.html` (`page-control/local.html` gitignored).
- **Round 53 lane HOOKS** (`r53_hooks`): the shared seams, tables, art and effects of round K. `portable_test.lua`: every new and retinted particle card of `r52_pfx` against the catalogue, the 25 skill icons and their licence rows, the status and window rows, the K6 table rows, and on probe definitions in the real `grug_abilities/init.lua` sandbox the family keys (cast and swing path, tooltip), the swing callback, the clock function seams, K9, the refusal reasons and K7; K8's held fallback per class through the real `input.lua`; the real `grug_core/area.lua`'s facing cone and sampled fall height on a fake node map.
- **Round 53 lane PRIEST** (`r53_priest`): the new Priest kit. `portable_test.lua` loads the real `grug_abilities/init.lua` (the `r53_hooks` sandbox), the real priest talent graph, readiness windows and `grug_core/area.lua` on a fake node map, with the level formulas cut from `combat.lua`, and checks against the calculator's formulas: the kit order and node links, damage, support amounts, costs, cooldowns, occupied times and ranges at levels 10, 30 and 60 untalented and in both sample builds, each talent at rank 1 and full (Steady Word and Sharpened Word max-combined), Smite in Strike's place on both layouts and the starter hotbar, the clock, Clear Conscience's window and ICD, Censure's ground anchor (no ground, a stair, a cave), its 4 nearest and the PvP filter, Hearten's and Haven's recipients, Word of Ruin's capped heal. `run.sh OUT_DIR` boots the disposable engine probe `grug_probe_r53_priest` (K13): a level-31 Priest casts each skill once at a passive dummy through the real input and cast paths, Censure also on a stair and in a cave the probe builds, and logs each action beside the calculator's value.
- **Round 53 lane MAGE** (`r53_mage`): the new Mage kit (`kits_mage.lua`) on the real `grug_abilities/init.lua` sandbox with the real Mage talent graph answering the bonuses. `portable_test.lua`: registration (order, gates against the granting nodes, transforms, tags, clocks, the K6 rows, the projectiles and their cues), the numbers against the calculator at levels 10/30/60 and for both full builds, every talent at rank 1 and full, casts through `try_cast` (refusals cost nothing, the shared spark interval, the action clock), the projectile hits, the ground areas (the "No ground found." refusal, `area.delayed`, the impact cue at the anchor), the cone and the circle, the PvP filter, Cold Shock, Rime Mantle, the transforms on both layouts and the new Mage's hotbar. `probe.sh OUT_DIR` stages the disposable engine probe `grug_probe_r53_mage` (plan K13): a level-60 probe Mage casts each skill once at a passive dummy with the calculator's full Ember and Rime builds, the areas also on stairs and in a cave, and logs each hit as a coefficient of D beside the calculator's, the anchors, the delayed impacts with their fall height, the effects and the cues (`OUT_DIR/probe.txt`).
- **Round 53 lane WARRIOR** (`r53_warrior`): the Bulwark and Ruin kits. `portable_test.lua`: the real `talent_graph.lua` with the Warrior's data (the audit, the vocabulary, the full-rank values against the calculator's frozen totals) and, in the real `grug_abilities/init.lua` sandbox with the real windows and `area.lua`, the kit's shape, the transforms on both layouts, the damage and amounts at levels 10, 30 and 60, each talent at rank 1 and full, Retort's and Ruination's windows, Broadstroke's arc, Bellow's circle and the PvP area refusals. `run.sh OUT_DIR` boots the disposable engine probe `grug_probe_r53_warrior` (a level-60 Warrior casts each skill on passive dummies, flat, on stairs and in a cave) and keeps its log as `probe.txt`.
- **Round 53 lane SCOUT** (`r53_scout`): the Scout's new kit and the deleted bow draw. `portable_test.lua`: no draw code, textures or strips left; the Quarry and Veil node effects and class keys; in the real `grug_abilities/init.lua` sandbox (with the real graph, `talent_windows.lua` and `grug_classes/scout.lua`) every skill's damage share, cost, cooldown and occupied time at levels 10, 30 and 60 against the balance calculator, each talent at rank 1 and full, Loose's cadence, Bladecraft on both layouts and its right-click shot, the three windows, the refusals that pay nothing, the PvP target check of the splash and the cone, and the real `input.lua` (Loose on LMB, the empty quiver's Strike, Bladecraft's LMB and RMB). `run.sh OUT_DIR` with the disposable probe `grug_probe_r53_scout`: each skill cast once on a passive dummy, the areas also on stairs and in a cave, every action logged beside its share of R, M or P.
- **Round 53 lane INTEG** (`r53_ms`): the migration step 0.53.0 and the class HP factors. `portable_test.lua` (stays in `run_fixtures.sh`): the registry (0.53.0 last, a character handler only), the join part's one chat line "Your talent points have been reset." for a character with a class and nothing else, the factors 1.2 / 1.0 / 0.8 / 0.8 and the maximum HP of the real `stats.lua` at levels 1, 30 and 60, a joining Mage's HP clamped; `run.sh [EVIDENCE_DIR]` runs `test_step.py` (the offline step: talent keys, the retired skills in every list, markers, a rerun) in the runner's container and `e2e.py` (a 0.52.1 world built by the 0.52.1 game with `grug_probe_r53_ms`: one character per class at level 30 with spent talents, stored windows, the retired skills on both layouts and in a bag; the guard's refusal, the shipped tool, boots and joins of this checkout: the chat line, the free points, no retired or locked skill, the lower HP, the kit swaps once the class lanes have merged, a second join); `GUI_WORLD=<dir>` keeps that 0.52.1 world for the GUI test (log in with the password `it-<name>`); `evidence/` the last run.
- **0.53.1 lane ART** (`r531_art`, no fixture): ships the 36 icons the user picked from the Round 53 clarity redraw (`r53_art/icons`, drop-01/drop-02; eight `old` picks are the 0.51 files at `dea1d163`). `ship_icons.py apply` copies the picks byte for byte over the game files, `check` verifies them (byte identity, 64 × 64 PNG, the licence rows of `grug_abilities` and `grug_classes` with bytes and SHA-256, every shipped skill/talent icon has a row and no row names a missing file, the retired icons stay deleted), `rows` prints the licence rows, `sheet OUT` writes a 32 px before/after contact sheet (Pillow).
- **0.53.1 lane FLIGHT** (`r531_flight`): the 40-node flight warning band and the minimap's no-fly overlay. `portable_test.lua` (real `grug_mounts/flight.lua` and `entity.lua`, `grug_map` `base.lua`, `minimap_view.lua` and `minimap.lua` on a fake engine): the band (a walk toward a border from 16 headings: shown at every position within 39 nodes, never beyond 40; both HUD texts take `WARNING_WIDTH`), the overlay red exactly where the dismount rule refuses a pixel centre (normal and a reduced "high" render, sample points in every outcome), install with both factions' tiles and a failing rule, and the minimap's flight mode (only on a flyer, under the claim layer, nothing sent while still, a switched-off minimap stays off). `capture.sh OUT_DIR` (the r502_cmap method) boots the disposable probe `grug_probe_r531_flight` and screenshots a flyer near an enemy border and near the coast, a ground mount and on foot; `probe.txt` keeps the render lines (overlay times and sizes).
- **0.53.1 lane SKILLS** (`r531_skills`): areas, cones and groups without line of sight, and the "Range: N m" tooltip line. `portable_test.lua`: the real `grug_core/area.lua` on a fake node map (behind a wall and a step edge reached, 4 above not, the group a cylinder, no ray cast) and, in the real `grug_abilities/init.lua` sandbox, every skill's tooltip head (the range line from `get_range` with a range talent and the elf's bonus read from the race definition, none on self-kind skills except the ground areas) and no hard-coded pointing range left in the kit texts. `probe.sh OUT_DIR [LABEL]` boots the disposable engine probe `grug_probe_r531_skills`: who `area.query`, `area.cone` and `area.group` reach on a built scene (walls, a ledge, a pillar) and their microseconds per call (the before/after comparison).
- **0.53.1 lane GEAR** (`r531_gear`): hand tooltips and the same trinket twice. `portable_test.lua`: through `r44_ch/harness.lua` (the real permissions and `equipment.lua`) "Usable by" for shields, spellbooks, every weapon family, armour and trinkets cross-checked against `hand_accepts`, the twin trinket by drag and shift-click without a refusal; the real `grug_gear/trinkets.lua` and `grug_trinkets/init.lua`: additive specials doubling to their caps, Last Light and Reclaimer's Mark for all 36 tier pairings (the stronger copy times 1 + the other's tier share) with one shared cooldown, the "Worn twice" tooltip line.
- **0.53.1 lane RACE** (`r531_race`): the racials, the skeleton bows and right-click picking. `portable_test.lua`: the undead truce (the cut `truce_active`: spared by day and night, a provoked zombie fights back, other races never spared), the flag on the Zombie and Sun-Dried Husk bases and every zombie-family sub-type copying one, the Elf's +3 m and the Dwarf's Thick Skin (the cut `raw_armor`, no fall perk left), the bow in slot 3 of the three bow skeletons (a zone tint leaves it), and `grug_gathering/pick.lua` (exactly the apple and the ripe blueberry bush, one `core.node_dig` per pick). `capture.sh OUT_DIR` (`XVFB=`) with `grug_probe_r531_race`: the three skeletons held in the shoot and stand clips from the side, the front and three-quarters.
- **Round 54 lane CONTRACT** ([`r54_armor`](r54_armor/README.md), the armor contract, no fixture): the frozen box catalog (`catalog.py`, `zfight.py`), the 128 × 64 atlas packing (`atlas.py`, `--check`), the exported data (`export.py`, `--check`), and the render/check tool for the painted armor art (`check.py`, `render.py` with a pure-Python software renderer, templates, `test_art/`); format in [armor-format.md](../docs/technical/armor-format.md).
- **Round 54 lane BAKE** ([`r54_armor`](r54_armor/README.md#bake-art-to-game-textures), no Lua fixture): `bake.py` bakes the painted armor art (reference palette, `tiers.json`, palettes, the atlas) into the 72 atlas layers `grug_armor_<line>_<grade>_<slot>.png`, the 54 skin layers and their enchant masks in `grug_visuals/textures` (and with `--icons-out` the 72 item icons and masks), deterministic, `--check` the gate, `--sheet` a contact sheet; `test_bake.py` checks it on a tiny synthetic art set (texels, mirrored box once, unworn boxes, mask frames, skin clipping, the check's missing/extra/changed files, broken art).
- **Round 54 lane MODEL** (`r54_model`): `portable_test.lua` (the bones, buffers, swing signs and weapon card of `grug_visuals_character.b3d` and `grug_visuals_npc.b3d`, both written by `r33_c3/gen_cloak_model.py`), `naive_atlas.py` (stand-in armor atlas and skin from an art directory, not the bake) and `capture.sh` with the probe `grug_probe_r54_model` (models in a studio, real-client screenshots; another lane passes its own `SCENE`, and `MODELS` for extra meshes).
- **Round 54 lane GAME** (`r54_game`): the armor boxes in the game. `portable_test.lua` loads the real `grug_gear`, `grug_quality`, `grug_repair` and `grug_visuals` (with player_api's registration) on a stub engine: the baked file names of the armor format and that each file and mask exists, a player's four textures (metal T6, cloth T1, an enchanted and a broken piece, the hair under a helmet, the empty weapon card), the preview seam `grug_visuals.preview`, armored NPCs' three textures and the key write guard, the definitions' meshes, the royal armour of kings and royal guards, the stored appearance version 2 and the leather tier 4 name Hardened (a stored old name renamed on rebuild); it prints the texture bytes a client receives per character. `scene.lua` is the in-game scene for `tools/r54_model/capture.sh` (`SCENE=tools/r54_game/scene.lua`): players composed by the real `compose` (metal T6 and cloth T1 on three races each, an enchanted and a broken piece), the real NPC entities' drawn looks (guard, bandit, War Commander, king, royal guards), the elite and rare tints over a guard and the capture player after the real equip and apply, standing and walking.
- **Round 54 lane VIEW** (`r54_view`): the Character tab's 3D view and the creation preview. `portable_test.lua`: through `r44_ch/harness.lua` (the real sfinv and `grug_inventory` pages) the preview seam `grug_visuals.preview` used when present (mesh and four textures read back the way the engine parses `model[]`, each texture escaped once), the weapon card (a sword, the Scout's bow, blank bare-handed, never the off-hand), the re-send on an equipment change, the fallback to the live properties, and the load order the refresh relies on. `capture.sh OUT_DIR` (`XVFB=`, the r49_inv method) with `grug_probe_r54_view`: the creation preview and the Character tab in metal T6 with a sword, cloth T1 bare-handed and leather T3 with a bow, each also at a second camera rotation (`ALT=`).
- **Round 54 lane WEB** (`r54_web`): version 1 appearances on the website. `gen_v1_samples.lua` runs the old game (an extracted 0.53.1 tree) and writes `v1_samples.lua`, the bodies and values it composed; `portable_test.lua` checks the export's `appearance_v1` block and the README's rule against them (the result is the race look the game composes today, valid under the current grammar), the races' `bare_body` and that version 2 never names an old armour file. `gen_test_character.lua` writes the kaesual handoff's test character (`test_character.json`, the stored value) and `scene.lua`, the capture scene that shows the exported `.glb` beside the `.b3d` (`r54_model/capture.sh` with `MODELS`).
- **Round 54 lane INTEG** ([`r54_art`](r54_art/README.md), no Lua fixture): the picked armor art the game ships (`art/`, `bake.py`'s default), the three drops' painters (`src/`), the user's picks (`picks.json`), since Round 55 lane ICONS the two armor-icon drops' painters (`src/icons-*`) and the icon picks (`picks.json` `icons`), and `assemble.py` (`--check`: `art/` equals painters plus picks), `ghosts.py` (the Character page's four slot ghosts, copies of the metal T3 icons, `--check`); `scene.lua` is its capture scene for `r54_model/capture.sh`. The old armor overlays and their builder `r10_art/build_armor_assets.sh` are gone; `r31_b/gen_enchant_masks.py` covers weapons, bows, shields and the spellbook only.
- **0.54.1 particle look** (`r541_glow`): the user's pick on the R52 particle page (2026-10-21), "glowing and vivid" for every skill effect (and then for the boss and mob effects), Smite as a small Final Word, faster Meteor and Censure falls. `tools/r52_pfx/effects.py` carries the look pass (`look()`, `VIVID`, `MATTE`) and the changed cards, so `r53_hooks` and `r52_pfx/check_limits.lua` still compare every card with the catalogue. `portable_test.lua`: the real `particles.lua` on a fake engine (`mote`, `blend`, `after` and their checks), every skill effect on the mote and lit or plain by its colour, every boss, mob and other effect lit or plain as listed (material textures unchanged), the vivid window and arrow-trail tints, the falls over heights and delays (late start, 14 and 12 m/s, no fade, landing on the anchor), Smite against Final Word, and the mote texture with its licence entry.
- **Round 55 lane GAME** (`r55_game`): the offhand look in the game. `portable_test.lua` (the r54_game stub) checks the offhand layer names and the per-tier spellbook icons, the composition with the look on and off (0.54.1's lists plus blank slots), the Scout's back card through the real wield poll (one rewrite per change), the wings, the Character tab's seven textures and the stored appearance version 3, and prints the texture bytes per slot. Its `book_icons.py`, the stand-in per-tier spellbook icons, was retired by the finish, whose bake writes the picked icons. `capture.sh OUT_DIR` (`XVFB=`, `OFFHAND=true|false`, `ONLY=<prefix>`, `SCENE=<file>` another lane's shots; the r54_model method) with `grug_probe_r55_game`: the test art baked by `r55_offhand/bake.py` into the staged probe only, figures wearing what the real `apply` gives the capture player (shields T1/T3/T6, books, a Scout's back cards with and without a cloak, test wings) and the Character tab.
- **Round 55 lane BAKE** ([`r55_offhand`](r55_offhand/README.md#bake-art-to-game-textures), no Lua fixture): `bake.py` validates painted offhand art (the offhand format's layout, reference palette, opaque shield and book, zone minimums, `tiers.json`, the cloak and wing textures' sizes) and bakes it into the per-grade atlas layers `grug_offhand_shield|book_<grade>.png` and their enchant masks (with `--icons-out` the shield and spellbook icons and masks), `--check` the gate, `--sheet` a contact sheet; `test_bake.py` checks it on `test_art/` (rectangles per size step and book box, glyphs, mask zones, palettes, the check's missing/extra/changed files) and against `test_art_broken/` (written by `make_broken_art.py`, `--check`), with every position derived from the live `params.json`.
- **Round 55 lane VIEWER** ([`r55_offhand`](r55_offhand/README.md#for-the-painter-what-to-paint-the-check-the-look), no Lua fixture): `render.py` renders painted offhand art on the shipped player model (pure Python, Pillow, numpy; the b3d through `r33_c3/gen_cloak_model.py`'s parser and rig, `r54_armor/softrender.py`'s rasteriser, the layers from `bake.py`'s functions): contact sheets per item, `--detail` sheets, a cloak sheet, missing art as a checker; `templates.py` writes `templates/` (shield, book boxes, wings, cloak at 8x, blanks, palette; `--check`); `test_render.py` checks the render on `test_art/`.
- **Round 55 lane SUPPORTER** (`r55_supporter`): manual achievements. `portable_test.lua` loads the real `grug_achievements` with a stub catalogue (seven automatic rows and one manual row whose cloak has wings): the catalogue validation of `manual`, the `server` privilege of `/achievement`, hidden until granted (tab rows and pages), grant and revoke online (tier, cloak, a worn cloak back to No cloak, feed and log lines, twice harmless), the refusals, and the offline queue applied once at the next join.
- **Round 55 lane MODEL** (`r55_model`): the offhand parts in the character models (`r33_c3/gen_cloak_model.py` with `r33_c3/offhand_model.py`, from `r55_offhand/params.json`). `portable_test.lua` (the bones `Offhand_Shield`/`Offhand_Book` under `Arm_Left`, the buffer order of both models, the offhand, back-card and wing buffers and their bones and UVs, a key in every frame, the Block key's sign); `test_frames.py` (Python: the format doc's §9 reference points on a model built from its own copy of the contract's parameters, keyed entries, steadiness, identity without an entry); `stand_in.py` (stand-in offhand textures from an art directory, not the bake), `scene.lua` and `capture.sh` (real-client screenshots through `r54_model/capture.sh`, the textures passed in `MODELS`).
- **Round 55 lane WEB** (`r55_web`): appearance version 3 for the realm website ([web export](web_data/README.md#the-offhand-look)). `portable_test.lua` (the export's `offhand_look`: the setting's default against `settingtypes.txt`, the baked layer names per bracket, all or none of them listed and all once enabled, the back card's class and halves, 16 x 16 hand images; the version 2 rule against the value 0.54.1 wrote, `v2_sample.json`; the test characters current); `gen_test_characters.lua` (`--check`) writes the addendum's Warrior and Scout with the offhand look on (`test_warrior.json`, `test_scout.json`) and `scene.lua`; `capture.sh OUT_DIR` (`XVFB=`; through `r54_model/capture.sh`, the test art baked into the staged probe only): the `.glb` beside the `.b3d` with the seven textures a website draws.
- **Round 55 lane FINISH** ([`r55_art`](r55_art/README.md), no Lua fixture of its own): the picked offhand art the game ships (`art/`, `r55_offhand/bake.py`'s default; the drop's painter in `src/`, the user's picks in `picks.json`) and `assemble.py` (`--check`: `art/` and the Supporter Cloak's two textures in `grug_achievements` equal painter plus picks; palettes prefixed per proposal, `icon_palette` where the icon is the other proposal's); `scene.lua` is its capture scene for `r55_game/capture.sh` (`SCENE=`, `ART=tools/r55_art/art`, `OFFHAND=true|false`; real cloaks, the Supporter granted through the real `/achievement`, the icon grid). Since then `r31_b/gen_enchant_masks.py` covers weapons, bows and the shared spellbook image; the shield and spellbook icons and masks come from `r55_offhand/bake.py --icons-out`.
- **Round 55 lane STACKS** (`r55_stacks`): old offhand stacks show the current art. `portable_test.lua` loads the real `grug_gear`, `grug_quality` and `grug_repair` and builds shields and spellbooks enchanted or broken under 0.54.1's tinted icons (Iron, Embersteel, the shared book): `grug_gear.initialize_weapon_tooltip` gives each the images, broken base and drawn keys of a fresh stack and returns true, a second call nothing; current stacks return false; the join path (grug_gear's equipment-change consumer) writes back exactly the old stacks and names the offhand list once.
- **0.55.1 `/prof` debug command** (`r551_prof`): `portable_test.lua` loads the real `grug_jobs` registry, `state.lua` and `admin.lua` on a stub engine: the `server` privilege and online targets, `set` (a slot at a tier capped at the character's band with the eligibility note, the replaced primary dropped as by unlearn, the other slot's profession refused, secondaries without a slot, bad slots, tiers and names), `learn`, `unlearn` (secondaries too), `clear`, the show line, the target's chat line and the action log.
- **Round 56 lane SMALL** (`r56_small`): `portable_test.lua` loads the real `grug_inventory/storage.lua`, `grug_traders` `trade.lua` and `prices.lua` (with the access and discount functions cut out of `vendors.lua` and `stock.lua`), `grug_factions/service.lua`, `grug_food`, `grug_alchemy/effects.lua` and `grug_classes.get_max_mana` on a stub engine: the sell list with items only on the inactive hotbar layout (listed unmarked, sold from their slot, a lot counted over main and the layout and taken main first), a race's Quartermaster serving another race of its faction at the full price and its own race at 10 % off, the other faction refused and a faction change while the form is open, a Warrior eating a Caster dish (eaten, no mana restored, the status detail without the mana parts, the item tooltip unchanged) and a mana potion still refused.
- **Round 56 lane QUESTMAP** (`r56_questmap`): `questmap.lua [REPO] [--out FILE] [--data DIR]` writes one self-contained HTML page of every shipped quest (zones, hubs, givers, lines as chain trees, a chains view across zones, a repeats view, filters and search) from the real `grug_quests` loader over the shipped zone files (`model.lua`: real spawn recipes, mob names, PvP garrisons, zone records, XP and copper formulas under a small stub) with the rework flags of `flags.lua` (same objectives in start towns or across zones, a reward that is a requested item, long kill-only runs, many prerequisites); `page.html` is the page's CSS and JS. `portable_test.lua` checks the flags on a hand-made set, the model against the formulas and the page build. Since Round 57 a quest row carries its variants (zone, givers, hub, objectives, text), story, completion text and choices, the zone view lists a shared quest in every zone it is given in, and `--data DIR` reads `DIR/data/zones` instead of the shipped files (the test runs it on `r57_qsys/samples`).
- **Round 57 lane QSYS** (`r57_qsys`): the quest system's new foundation. `portable_test.lua` runs `quality_test.lua` (the real `grug_gear` and `grug_quality` on the r56_affix stub: `grug_items.check_affixes`, `make_stack` at an item level with fixed enchants, the shared `tooltip_text` helper) and `quest_test.lua` (the real `grug_quests` on the two-zone sample of `samples/`), each in its own process; `samples/` holds that sample (two zones of both factions, flagged reworked) and `render_story_icons.py` (`--check`) the map's story quest icons. `capture.sh OUT_DIR` (`XVFB=`, `WIDTH`/`HEIGHT`, `SUFFIX=`; the r48_mail method) with `grug_probe_r57_qsys`: probe quests at Dawnmere for screenshots of the story marker, the offer with a choice, the turn-in without and with a pick, the map's story icons and the quest log's Story category.
- **Round 57 lane VENDORMAT** (`r57_vendormat`): no vendor sells leather, cloth, ores or bars (ruling 28). `portable_test.lua` loads the real `stock.lua` (with the three job supplies) and walks the core stock, the thirteen profession shelves and every vendor shape's gear tab in every bracket against the four retired items and every ore, bar, leather and cloth of the material registry and the loot catalogue, Thread on every trade's shelf and the tailor's two wools, then `prices.lua` under registry stubs: Leather, Light Leather and Linen Scrap buy back at 2c, 2c and 1c as with the old shelves, the Bronze Bar at its inputs (2c, the old shelf capped it at 1c). `probe.sh OUT_DIR` (one boot through the queue) with `grug_probe_r57_vendormat`: the same walk over the real registry and every registered vendor, and every item's value with the old shelves and without (the three loot-class items must not differ; the Bronze Bar and the goods made from it are listed). `start_zone_sources.py`: the level 1–10 mobs of the six start zones that drop Leather, Light Leather and Linen Scrap, and the T1 band of copper and tin.
- **Round 58 lane CAMPS** (`r58_camps`): the Miner's Guild's camps. `portable_test.lua` places three seeds through the real world assembly (42 camps in their zones, factions and tiers, `camps()` 36 with lifts and 148 levels, town and anchor gaps, spacing, bands), the camp module's determinism, every camp blueprint's socket contract (lift on the lift node, foreman, camp vendor; a camp under construction's garrison and nothing else), the real runtime of seed 42 (registry, the 42-row activation roster, the lift node written by the writer) and the classification (protection, map, garrison, `index.get`/`near`). `capture.sh OUT_DIR` (one boot through the queue) with `grug_probe_r58_camps`: shots of a T2 and a T4 mining camp, a war camp and a camp under construction.
- **Round 56 HOODPAGE** ([`r56_hood`](r56_hood/README.md), no Lua fixture): `hood.json`, the hood polygon part in the schema of armor-format.md §1a, exported by the hood workshop page with the shape the user accepted.
- **Round 56 lane MOUNT** (`r56_mount`): land mounts fall and jump like a player. `portable_test.lua` loads the real `grug_mounts` controller and the fall branch of `grug_core/combat.lua`'s HP modifier: the gravity (19.62 for both land tiers, a boat off the water 9.81, a flyer none), the jump (impulse and apex, the integrated flight), the damage table (5, 10, 11, 13, 20, 30 nodes: 0, 0, 5, 20, 50, 85 % of two pools), no dismount on a fall, a dismount on a punch and other damage. `run.sh OUT_DIR` (one boot through the queue): the disposable probe `grug_probe_r56_mount` with one protocol client as the rider (drops from 11 and 20 nodes, a jump in place, a run at a 2-node step without and with jump, a punch).
- **Round 56 lane VIEWER** ([`building_templates`](building_templates/README.md), shared with FREEZE-TOWNS and EDITOR): `nodes.json`, the node registry the template tools read (refreshed by `node_dump/refresh.sh`, one headless boot with a disposable probe); `viewer/`: the shared three.js node renderer (`renderer.js`), the town viewer moved from branch `town-viewer` (`build_viewer.py`) with noclip, and the template gallery (`build_gallery.py`, `test_templates.py` tests its reader and the pane port against `parts.lua`; no Lua fixture).
- **Round 56 lane AFFIX** (`r56_affix`): the enchant lines name their channel. `portable_test.lua` (the `r33_c4` stub with the real `grug_gear`, `grug_quality` and the enchant registrations): the tooltip with a prefix only, a suffix only, both (prefix first, whatever the stored order) and none, the amount at the level inside the brackets, a trinket's suffix; the enchant plan's `replaces` line ("Replaces prefix: +5 Strength (T3)") for a filled channel, none for an empty one, beside the higher-tier warning. The enchant box itself (the line, its geometry at and away from the forge) is in `r45_eu`.
- **Round 56 lane FLOAT** (`r56_float`): items in water rise to the surface. `portable_test.lua` runs the real `mods/BASE/default/item_entity.lua` over a fake builtin item in a stub world with a small physics step: an item at the floor of a 3-deep pool and one thrown in rest at the surface without drifting (velocity and acceleration zero, the settle and the 0.49.1 resends once), an item on land unchanged with no node lookup while it lies still, flowing and river water at their drawn level, lava unchanged, a drained pool, a 10-deep lake, a stone roof and a thin film. `probe.sh OUT_DIR` (`GAME_PATCH=` for a before run) boots the disposable probe `grug_probe_r56_float`: a pool, a land platform and a lava basin in the sky, 40 items each on land, dropped in and spawned at the floor, their heights over time, the node lookups and microseconds per `on_step`, the `set_pos` calls, then the pool drained.
- **Round 56 lane MOBAI** (`r56_mobai`): ranged mobs close in, aggro by level, the hit alert. `portable_test.lua` cuts `general_attack`, the shot-range helpers, the attack branches, `do_attack` and the hit alert out of `mobs/api.lua` and the radius section out of `grug_mobs/aggro.lua`, and loads the real `grug_core/homing.lua` and `mobs/grug_obstacle.lua` on a node grid with a sampling raycast: the radius table, the filter (monsters only, player targets only, before the sight ray), the probe numbers (scans, objects, sight rays before and after), the alert around the hit mob without a cascade, the shot range and the approach (walk beyond, stop 3 m inside, no hovering; kings, fliers), the lock agreeing with the sight check, the Bandit Archer's shoot clip. `grug_probe_r56_mobai/` with `probe.sh` is the in-game proof (an archer closing on a player 22 m away, a mob 10 levels below at 3 m and at 0.9 m).
- **Round 56 lane HOOD** ([`r56_hood`](r56_hood/README.md)): polygon parts in the armor pipeline (`r54_armor/polypart.py` validates a schema file; catalog, atlas, checks, z-fight, bake, renders, templates, test art), the hood in the player and NPC models (`r33_c3/gen_cloak_model.py`, `--report` prints its distance to the back cards), the chin strip (`r54_art/assemble.py`). `portable_test.lua`: the hood's atlas place, the hood in both models' armor buffers (points, normals, UVs, Head bone, outward fans), the shipped selection (no hood on metal, never without the helm).
- **Round 56 lane HOODPAINT** ([`r56_hood`](r56_hood/README.md#painting-in-views), no Lua fixture): `views.py` paints the hood in three views (side, back, top) and projects them onto its faces (templates and guides, the palette-checked 64 × 12 sheet, a preview with the round trip, an example; `--selftest`: seams, mirror, uniform views, refusals, round trip, `check.py`).
- **Round 56 lane HOODFINISH** ([`r54_art`](r54_art/README.md), [`r56_hood`](r56_hood/README.md), no new fixture): the picked hood art (0.56.1): the hood drop's painter `r54_art/src/hood-drop-02/` (whole cloth and leather tiers in `picks.json`, its kept views checked by `assemble.py --check`); `r56_hood/finish_scene.lua`, the capture scene of the shipped hood.
- **Round 56 lane VIEWER** ([`building_templates`](building_templates/README.md), shared with FREEZE-TOWNS and EDITOR): `nodes.json`, the node registry the template tools read (refreshed by `node_dump/refresh.sh`, one headless boot with a disposable probe).
- **Round 56 lane AFFIX** (`r56_affix`): the enchant lines name their channel. `portable_test.lua` (the `r33_c4` stub with the real `grug_gear`, `grug_quality` and the enchant registrations): the tooltip with a prefix only, a suffix only, both (prefix first, whatever the stored order) and none, the amount at the level inside the brackets, a trinket's suffix; the enchant plan's `replaces` line ("Replaces: Prefix: +5 Strength (T3)") for a filled channel, none for an empty one, beside the higher-tier warning. The enchant box itself (the line, its geometry at and away from the forge) is in `r45_eu`.
- **Round 56 lane EDITOR** ([`building_templates`](building_templates/README.md#the-editor-editor-lane-editor-round-56) and `r56_editor`, no Lua fixture): `building_templates/editor/serve.py`, the local building template editor (127.0.0.1 only; writes only existing template files, through the validator, atomically). `r56_editor/test_editor.py` tests the server, the writer's byte round trip on every template, the save gate, fixed size, move-only points and path confinement; `gui_run.py [SHOT_DIR]` drives the GUI checklist path in a headless Chromium (`cdp.py`, a small DevTools client) with screenshots; both on a disposable shared clone (`common.py`).
- **Round 56 lane FREEZE-TOWNS** ([`building_templates`](building_templates/README.md) and `r56_freeze_towns`): the start towns' buildings as building templates. `building_templates/export.py` (`--check`) freezes them from the pre-freeze generators, `check.py` is the template gate (`--self-test`), `town_identity.lua` prints what the towns build (identities, point digests, capital build digests, `--load` numbers; `check_upgrade.py` compares it with the pushed commit). `r56_freeze_towns/portable_test.lua`: the loader (layouts, templates, malformed files with file and line, resolution per race, `{id}`, sockets) and the six frozen identities and point digests pinned. `r56_freeze_towns/run.sh OUT_DIR` (one boot through the queue): the disposable probe `grug_probe_r56_freeze` emerges the Dawnmere and Sunscar pads of a fresh world (seed 42) and counts their nodes; `compare.lua` holds every building node to the blueprint.
- **Round 56 lane TREES** ([`building_templates`](building_templates/README.md) and `r56_trees`): the groves, orchards, copses and boughs as planted templates (format doc §4.2), re-cut by `export_capitals.lua` from the planting `freeze_build.lua` records. `r56_trees/portable_test.lua`: exactly the planting parts are planted templates and hold no tree cell, the loader plants at the stems in order with the main palette, spacing and undergrowth, `late` cells come after the trees, malformed planted templates stop at load.
- **Round 56 lane FREEZE-CAPITALS** ([`building_templates`](building_templates/README.md) and `r56_freeze_capitals`): the six capitals' buildings as building templates with one roster per capital. `building_templates/export_capitals.lua` (run by `export.py`) freezes them from the pre-freeze generators, `loader_check.lua` runs the game's loader and builds every town and capital for `check.py`. `r56_freeze_capitals/run.sh OUT_DIR` (one boot through the queue): Highcourt's core and Dawnmere emerged and their building nodes counted against the blueprints. `portable_test.lua`: the rosters and their templates (with the `extent`/`top` measurements), what a roster allows, the stamped town points, and every capital's identity, point and build digests pinned with its roster counts against the build.
- **Round 57 lane CHAINDEPTH** ([`r57_chains`](r57_chains/README.md)): the recipe chain depth report (ruling 8). `run.sh OUT_DIR` (one boot through the queue): the disposable probe `grug_probe_r57_chains` dumps every registered recipe (registry, furnace, dual furnace, enchants and upgrades), `generate.lua` writes `report.txt` and a self-contained `index.html`; `chains.lua` is the pure walk (depth, steps, Basic list, the loop rules) for the recursive Basic unlock. `portable_test.lua`: a synthetic set (chain, loops per rule, group, alternatives) and the real registry and smelting recipes on a stub engine.
- **Round 57 lane FIX56** (`r57_fix56`): bays are not ocean, and the chin strip's underside. `portable_test.lua` builds the zones session of two fleet seeds (12345, 6866842473207) and the user's world "test" (476085000009918749, the example column (-609, -2285) of ruling 23) and asks the real `grug_mounts` flight rule: bay shore columns of the belt (generation and the planner's tuple unchanged, the gameplay class planned water, the water query "bay") fly under their zone's rule, an open-sea column and bay-mouth caps stay "ocean". `bay_scan.lua REPO SEED [STEP] [GRID_OUT]` counts per bay the columns the fix moves, the no-fly sea next to bay water before and after and the enclosed no-fly pockets; `bay_png.py GRID_OUT` draws its grids. `test_chin.py` (Python): the underside texels, the hood clear of the chin, `check.py` on the shipped art and its refusals (the underside open on leather T6 or metal, a texel under the neck). `chin_shots.py BEFORE_ART AFTER_ART OUT`: head pieces from below and at a low front angle, offline.
- **Round 57 lane CRAFT** (`r57_craft`): the crafting queue, layout C, favourites and the recursive Basic unlock. `portable_test.lua` (`r45_ui`'s stub with the real `grug_jobs` page, jobs, queue view and Basic unlock, a stand-in enchant): five jobs with an enchant and the sixth refused, cancels (✕, a refused one, a stale one, the stop button), a Round 56 save, the offline catch-up into a full inventory (the grown overflow), layout C's buttons and job strip under every box, favourites and both filters, the tier unlock at learn, advance, `/prof` and join. `XVFB=… capture.sh OUT_DIR` (one boot through the queue; `WIDTH`/`HEIGHT`, `SUFFIX`) with `grug_probe_r57_craft`: the page idle, running with a queue of three, the queue view, the enchant box and the overflow, plus the tier unlock's numbers on the real data.
- **Round 57 lane ALLOY** (`r57_alloy`): `portable_test.lua` loads the real `grug_jobs` registry and Basic catalog and the real `grug_smelting` recipes on a stub engine: the five alloys (Embersteel and Abyssal Steel from Steel, the old pairs refused), the six flat wood grades (2 planks + the tier's ingredient, no grade from a grade), the Steel Bars recipe, only dye mixes and wool taking White or Yellow Dye, the item ids, and the chain depth through `r57_chains`.
- **Round 57 lane DYES** (`r57_dyes`): `portable_test.lua` loads the real `grug_jobs` registry and Basic catalog on a stub engine: the four new plain dye sources (Bone, Sunleaf, Apple, Marshbloom), their raws gathered by everyone, all 15 dyes and wools reachable from gathered raws and White Wool, and the dye rows exactly the six plain sources and the 19 mixes.
- **Round 57 lane STARTQUESTS** (`r57_startquests`): the six start zones on the Round 57 quest foundation (quests.md "The start zones"). `build_structure.py` (`--check`) wrote the structure with placeholder texts (it overwrites texts: the JSON files are the source once the texts land); `report.py [--before REF]` prints the quests, weights and quest copper per zone before and after and the reward table; `portable_test.lua` (the real `grug_gear` and `grug_quality` on the r56_affix stub) checks the shipped files: shared variants, free play, the boars and rats at once with counts by phase, no reward as a request, the reward pattern with every stack at its item level and enchants, the departures and their level-11 dependants.
- **Round 57 lane DETAILS** (`r57_details`): the recipe details page (`grug_jobs/details.lua`) and its ingredient source index (`grug_jobs/sources.lua`). `game_harness.lua` loads the whole game in the engine's mod order under a permissive stub (every registration real; the world construction, the minimap bake and the files that want the world skipped), for fixtures that need the registered data. `portable_test.lua`: the pure build on synthetic data (every source kind), `grug_mobs.drop_tables`, and the index on the real data (every recipe ingredient and enchant input has a source but the listed gaps; bars, Linen Scrap, Gravemoss, Thread); it prints the gaps and a digest of every source line, which the disposable engine probe `grug_probe_r57_details` (staged with `tools/luanti_headless.sh` `PROBE=`) logs for the real engine. Part P: the details page (details.lua) on the real Crafting page (Recipe details, Open ▶, ◀ Back, Kinds ▶, Select this recipe, the enchant and upgrade Details, the job strip under it). `capture.sh OUT_DIR` (`XVFB=`, one boot with a client, the method of `r57_craft/capture.sh`) with `grug_probe_r57_details_shots`: screenshots of the page with two ingredient boxes, a group page and an enchant page while a job runs.
- **Round 58 lane GUILDSPEC** (`r58_guildspec`): the Miner's Guild numbers and contract ([miners_guild.md](../docs/design/miners_guild.md)). `model.lua` is the mining yield model (a model, not a measurement: the tier pick's dig time, the ore rows, the vendor payouts, stated assumptions) behind the ranks, prices and loot; `write_doc.lua REPO [--check]` writes its tables into the spec; `build_page.lua REPO OUT_HTML` builds the German tuning page (`page.html`: every catalogue number, live derived lines, saves `picks/tuning`); `apply_tuning.py PICKS.json [--dry-run]` writes the accepted values into `grug_guild/catalog.lua`. `portable_test.lua`: the catalogue's shape, Round 58 §2a on the real game (the r57_details harness and Round 57's source index: no exchanged item has a vendor source; `pending` rows are exactly the mason's two), no copper loop through the consumables or the Remains, the spec's tables current and the page's keys.
- **Round 58 lane CONSUME** (`r58_consume`): Ore Sense, Treasure Hunt and the Miner's Remains. `portable_test.lua`: the real `grug_core` status files, `grug_materials` registry and `grug_guild` effect and items on a fake engine with a clock, node timers, unloadable blocks and restarts (the items and nodes, the refusals, persistence across leave, death and a crash, one search per mark, the placement rules, the markers per player, removal by distance and by the owner going offline, the token case, the loot ranges). `art/ship.py [--check]` repaints the picked guild art of drop 01 (`art/paint.py`, the drop's painter) and writes or compares the shipped textures. `capture.sh OUT_DIR` (`XVFB=`, the r49_inv method, one queue run of two slots) with `grug_probe_r58_consume` the engine screenshots (the Ore Sense marker and status, the Remains in T1 and T5 rock, the Treasure Hunt marker, the item icons) and the search costs (`COST` lines in `probe.txt`).
- **Round 58 lane LIFT** (`r58_lift`): the Miner's Guild lift ([miners_guild.md](../docs/design/miners_guild.md) §3) and the picked guild art of drop 02. `portable_test.lua`: the lift's registration on the r57_details game harness (the picked node box and faces, the digest's static fields, the right-click), the shipped art against `art/picks.txt`, the reputation icon and the map markers; then the real camp and room modules, `grug_home/travel.lua` and the camp blueprints on a fake engine: the camp from every lift, the level list, the faction refusal, safe arrivals in every room and in front of every surface lift, the waystones' travel rules, a T4 and a T6 camp ridden to every level and back, nothing saved. `art/ship.py --from DROP_02_P1 | --check` copies the picked files byte for byte and checks them by SHA-256. `capture.sh OUT_DIR` (one boot through the queue) with `grug_probe_r58_lift`: the engine ride and the shots.
- **Round 58 lane REP** (`r58_rep`): reputation, the trade-in and the Miner's Guild cloaks ([miners_guild.md](../docs/design/miners_guild.md) §4–§6). `portable_test.lua` (on the r57_details game harness with fake players): the store (thresholds, spend never touching the lifetime, bad amounts, no faction, the clamp, the per-faction keys across an admin faction switch, the callbacks once per change and the rank callback only on a rise), the trade-in over main, a bag and the inactive hotbar (whole lots, refusals take nothing), the vendor window's Trade-in mode at a test vendor with `guild = true`, the achievement series unlocking the cloaks at 3, 6 and 10, the mason's shelf (§2a) and the consumables' payout. `scene.lua`: the scene for `tools/r55_game/capture.sh` (`SCENE=tools/r58_rep/scene.lua`): the Trade-in mode at a test vendor, the Character page's guild lines, the three cloaks and the winged one, set through the real `/guild_rep`.
- **Round 58 lane HALLS** (`r58_halls`): the Miner's Guild house in the six capitals' civic cores (settlements.md "The Miner's Guild houses"). `make_halls.py` (`--check`) writes the six `<capital>_miners_guild.tpl` templates from one parametric design (edit the script, not the files); `portable_test.lua`: one house per capital (roster, core, no district plot), the hall socket contract (`capital_services.lua` `GUILD_HALL`) and every hall socket reachable from the core's arrival over the finished core; `view/<capital>_core_blueprint.lua` hand the town viewer (`building_templates/viewer/build_viewer.py`) a capital's civic core; `build_pages.py OUT_DIR [--standalone]` writes the review pages (the six houses' template gallery, the six cores in the town viewer); `capture.sh OUT_DIR` (`XVFB=`, one boot with a client, the method of `r51_ft/capture.sh`) with the disposable probe `grug_probe_r58_halls` the engine shots of three houses outside and inside and an in-world check of each frieze and plaque.
- **Round 58 lane TOWNFIX** (`r58_townfix`): the Round 56 town fixes. `portable_test.lua` builds the parts, capital cores and start towns through the game's loader and compositions and walks them with a small player model (half-node steps, a 1.7-node body clearing every walkable node of the column it stands in and leaves, the node registry's walkability): Lethariel's bough platforms from the stair's foot to the hall door, the five core gatehouses' inner stair from the east door to the first floor (every tread along its axis, the turn on a landing) and on to the deck, their doors, idle posts, deck opening and closed walls, the throne guards' posts within 5 m of the king in the six halls, every core gate's watch (no passage posts or tower loop, the deck post, two counter-rotating loops of one rectangle on open city-side ground, the small loop's reach, three guards), the terrace stair for lifts 1 to 5 and Silverleaf's two terrace houses, and the six start towns' waystone and mailbox at the centre next to the Quartermaster. The throne guards' post and no-wander behaviour is `r41_mob`'s case P. `XVFB=… capture.sh OUT_DIR` (one boot through the queue; the method of `r57_qsys/capture.sh`) with `grug_probe_r58_townfix`: Silverleaf's centre and terrace stair, Lethariel's gatehouse stair, deck and watch, a bough platform and the king with his throne guards. `lethariel_core.lua` is Lethariel's core as a blueprint chunk for the town viewer (`building_templates/viewer/build_viewer.py`).
- **Round 58 lane ROOMS** (`r58_rooms`): the Miner's Guild lift rooms (`wp40/guild_rooms.lua`, the room step `wp40/guild_room_writer.lua`, `wp40/guild_room_protection.lua`, `guild_room_nodes.lua`). `portable_test.lua` (stub camps): the rooms at their tiers' floors and their shape, a box split over chunk edges written the same in any chunk order, the room step in the early-out chunks and after a writer veto (the real `air_chunks.lua` and `degrade.lua`), liquids round the boxes, the protection wrapper, the real spawn policy and depth pulse refusing a room, the fill's definition and the real `grug_home/travel.lua` `passable()`/`safe_arrival()` on the arrival. `grug_probe_r58_rooms` (staged with `tools/luanti_headless.sh` `PROBE=`, one boot through the queue; settings `r58rooms_max`, `r58rooms_camps`): emerges only the room boxes and logs a `CHECK` line per room (every node, no liquid or ground content, light, protection, spawn refusal, the liquids round the box).
