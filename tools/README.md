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
  (`web_data/upgrade.json`, schema 2) against the last pushed commit, the
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
python3 tools/migrate.py --world <dir>           # migrate
python3 tools/migrate.py --world <dir> --check   # report, change nothing
```

`--check` reports the world version and the due steps and proves write
access: on every backend a real write under the write lock (SQLite `BEGIN
IMMEDIATE`, PostgreSQL at most 5 s for a row lock), rolled back.

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
| `step_start` | `step` (its version), `from` (the world's version before it) | a step begins |
| `step_done` | `step`, `counts`: `characters`, `player_meta`, `inventories`, `positions`, `privileges`, `mod_storage`, `markers` (writes of that step) | a step committed |
| `done` | `mode`, `world_version` (before the run; `null` for a new world), `record` (the stored record or `null`), `new_world`, `target` (game.conf), `due` (step versions), `backends` (per kind: `sqlite3`, `postgresql` or `absent`), and `applied` (migrate) or `write_checked` (check) | exit 0 |
| `refusal` | `reason`, `message` | exit 2 |
| `failed` | `step` (or `null`), `reason`, `message` | exit 1 |

Refusal reasons: `usage`, `checkout` (game.conf, the declaration or a step
file), `world_mt`, `backend`, `database_missing`, `connection`, `layout`
(not the engine's table layout), `lock`, `write_access`, `record` (no
`major.minor.patch`), `world_newer`, `internal`. Failure reasons: `lock`
(a later step's lock), `step` (the step raised), `rule` (the step broke a
limit of the data API), `commit`.

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
  `engine.sh` rats across a dawn; `b` the level-proof talents and the picks,
  `numbers.py` the conversion, review and decided tables.
- **Round 36** (`r36_<lane>`): `f` the target predicate, evade rule, banner
  and timing line, `engine.sh` a reset inside and outside the wander radius;
  `f2` the held button across a hotbar switch, `engine.sh` a held dig across
  wield switches; `k` the support factor, Dexterity curve and spell
  rounding, `numbers.py` the decision tables; `e` the use objective, objects,
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
  and precedence) and `bench_hook.lua`, the animation pass with the pose
  hooks for 100 stand-in players (run it on the base and the branch).
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
  runs 1–5 of the lane's diagnosis and the final region run); `r41_sc` the bow's missed release
  (`portable_test.lua`: the real `input.lua` and `scout.lua` on a fake
  engine; a new press during a live draw fires it and draws again, the
  0.2 s grace, node calls, the starting press's own call); the engine side
  is a case in `pt_fixes/lane_a`'s probe, the quiver total in `r28_a6_ui`; `r41_up` the platform's upgrade contract
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
  and the guard names them, and when the last declared step is the game's
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
  `grug_achievements` and `grug_jobs/character_tab.lua` under a stub `core`,
  with an engine move model whose shift-click follows the page's own
  listring. `portable_test.lua`: each mode renders inside its box, the gear
  box's slots and hand labels per class, the arrow slot only for Scouts,
  Return home and Withdraw, and the shift-click routing (gear into its slot
  or swapped, back out in the give order, arrows into and out of the
  quiver, the refusals); it prints the page's bytes per mode.
  `luajit tools/r44_ch/bytes.lua [repo]` prints the bytes per mode for a
  Scout with four 32-slot bags against any tree (before and after).
  `r44_ts`: `harness.lua` loads the real vendored sfinv, `grug_inventory`'s
  `ui.lua`, the talent files with `talents_ui.lua` and `grug_skills` under a
  stub `core` (it also loads the tree before lane TS);
  `portable_test.lua` checks the tree framework on a small tree with a
  branch (node rectangles, connectors), today's trees as two sections, the
  one Talents & Skills tab and its catalog row, the hotbar-only rule for
  every target list with an engine move model (catalog to hotbar, drag back
  removes) and the grants with a free and a full hotbar (the grant code cut
  out of `grug_abilities/init.lua`); `page_bytes.lua [repo]` prints the
  talent and skill pages' formspec bytes (before: a `git archive` export of
  the older tree as `repo`).
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
  (with `targets.lua` and `quest_box.lua`) under a stub `core`: the key
  edges, the window size and layout, the overlay per faction and quest
  state, the quest target index and the crosshair-before-rings rule with
  the five-ring cap (garrison camps and the rift boss as crosshairs), the
  refresh rule (throttle, trailing send, party checks, the pass budget, the
  0.5 s scroll pause, a send that crossed a close), the quest boxes (no
  preselection), zoom and the Map tab; it prints
  the sends per minute alone and in a party. The disposable probe
  `grug_probe_r44_mq` (staged with `PROBE=`) logs the map formspec's bytes
  per faction at zoom 1x and 8x (the Map and Quests tabs before Round 44 MQ,
  the map window after), the target index's size and build time and how
  many quest objectives the targets mark.
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
  and both characters join again; a PASS/FAIL table.
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
  (`--check`, `--report`); `portable_test.lua` loads the real registry, the
  Basic catalog and the profession catalogs under a stub engine: the record
  shape, queries and refusals, the conversion of every grid route, gear in
  its profession, durations, stations, the craft list at a join and the
  removed APIs. The recipe-book probe `pt_fixes/lane_d` is retired with the
  books.
