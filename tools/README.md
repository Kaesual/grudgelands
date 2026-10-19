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
  the "(R)" legend); `r46_cb` rage by weapon speed and the spell base
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
- **Round 51 lane NAMES** (`r51_names`, design only, no fixture): the water
  families' ladders and names. `survey.sh` (through the Lua queue, 4
  processes) runs `water_survey.lua` per seed: the game's region builder
  counts per zone belt the cells near sea water and near lakes and rivers
  (`survey/seed_<seed>.json`); `build.py [--check]` expands `design.json`
  over the belts into `draft.json` (sub-type rows, world slots, zone slots
  in the Round 38 proposal format) and the preview page `page.html`
  (`page_local.html` for file://); `check_draft.py` runs the Round 38 name
  gates over today's names plus the draft.
- **Round 51 lane WRECK** ([`r51_wreck`](r51_wreck/DESIGN.md)): the shipwreck design: four shapes as data (`shapes.py` writes `shapes/*.json` and the node list, `--check`), the preview page (`build.py` writes `wreck.html`, `--check`) and the placement sketch for the build step.
- **Round 51 lane LK** (`r51_lk`): the land kit: `gen_props.py` writes the prop nodes' data and tiles from `tools/r51_land/props` (`--check`), `portable_test.lua` the fixture (props, drops, kit rows against the viewer, variants, roster, town graves and bones, one seed's chunks with no floating cell), `region.lua REPO SEED [N]` the plan and write seconds and kit counts in fixed chunks (before/after), `capture.sh OUT_DIR` (`XVFB=`) with `grug_probe_r51_lk` the engine counts and screenshots per kit biome and Stillgrave.
- **Round 51 lane LG** (`r51_lg`): the land grounds and nodes. `portable_test.lua` (r24 mining harness): every 32 px world-aligned and 16 px face, the shipped files against the picked art of `tools/r51_land`, the swamp moss and the clay bands with their host lists, the sand override, the hanging moss strand/end dig rule and the world's moss runs, the closed node roster; `capture.sh OUT_DIR` (`XVFB=`) with `grug_probe_r51_lg` the engine look once: a sky test patch of the 2 × 2 grounds, the clay band wall, a sand basin with water and a hanging moss run before and after its end is dug.
- **Round 51 lane MOBS** (`r51_mobs`): step M1, the water mobs
  (`portable_test.lua`: the sub-types, fish drops and names against the
  NAMES draft, sub-type selection at every ladder edge with level 20 by its
  belt, the real registrations, and the swimmer reset in the real leash
  tick with the reach veto). `probe.sh OUT_DIR` (one queue slot) with
  `grug_probe_r51_mobs`: every new mob spawned by command in an arena,
  frog and tortoise chasing a probe player ashore and back, the stingray's
  reset, one kill per family and its fish. `capture.sh OUT_DIR` (`XVFB=`,
  two queue slots) with `grug_probe_r51_shots`: screenshots of the
  line-ups.
