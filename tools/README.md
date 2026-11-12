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
after its sample. Since Round 60 every seed also builds the spawn regions of
the zones whose recipes have quest places (offline, the game's
`spawn_regions_core.lua` on the runtime's zones and planner) and fails when
one is not placed (about 4 s of a seed's time, reported as `place_seconds`). The
[round workflow](../docs/process/round-workflow.md#3-gates) says when each
size is required.

```sh
tools/seed_fleet/run.sh quick         # the first 100 seeds (about 6 minutes at 6-8 parallel)
tools/seed_fleet/run.sh full          # every seed, about 300 (about 17 minutes)
tools/seed_fleet/run.sh quick 20      # plus 20 random seeds (printed)
RESULTS=/tmp/r.tsv tools/seed_fleet/run.sh quick   # also every seed's result line
```

## Other checks

- [Round 69 camp art](r69_camp_art/README.md): three construction-camp candidates for six races, an offline 3D comparison, PNG views and reproducible templates.
- [Round 70 castle art](r70_castle/README.md): three shared castle forms, a multi-block throne, six capital palettes, an offline comparison and reproducible templates.
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
  `grug_pvp/page.lua`: the one Party & PvP tab (Social since Round 67) in
  and out of a party (all sections, no inventory view, inside the window,
  no controls overlapping), every party and PvP field
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
- **Round 56 lane EDITOR** ([`building_templates`](building_templates/README.md#the-editor-editor-lane-editor-round-56) and `r56_editor`, no Lua fixture): `building_templates/editor/serve.py`, the local building template editor (127.0.0.1 only; writes only existing template files, through the validator, atomically). `r56_editor/test_editor.py` tests the server, the writer's byte round trip on every template, the save gate, fixed size, move-only points, path confinement and flipped cells (the Flip tool's upside-down stairs and a wagon wheel on the ceiling) through the gate; `gui_run.py [SHOT_DIR]` drives the GUI checklist path (the edit rules of `model.js`, Rotate and Flip among them) in a headless Chromium (`cdp.py`, a small DevTools client) with screenshots; both on a disposable shared clone (`common.py`).
- **Round 56 lane FREEZE-TOWNS** ([`building_templates`](building_templates/README.md) and `r56_freeze_towns`): the start towns' buildings as building templates. `building_templates/export.py` freezes them from the pre-freeze generators (its `--check` is retired since Round 58: it prints RETIRED and passes, `check.py` is the gate), `check.py` is the template gate (`--self-test`), `town_identity.lua` prints what the towns build (identities, point digests, capital build digests, `--load` numbers; `check_upgrade.py` compares it with the pushed commit). `r56_freeze_towns/portable_test.lua`: the loader (layouts, templates, malformed files with file and line, resolution per race, `{id}`, sockets) and the six frozen identities and point digests pinned. `r56_freeze_towns/run.sh OUT_DIR` (one boot through the queue): the disposable probe `grug_probe_r56_freeze` emerges the Dawnmere and Sunscar pads of a fresh world (seed 42) and counts their nodes; `compare.lua` holds every building node to the blueprint.
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
- **Round 58 lane CAMPNPC** (`r58_campnpc`): the Miner's Guild's people and the camp vendor ([miners_guild.md](../docs/design/miners_guild.md) §5.2, §10.7; [quests.md](../docs/design/quests.md) "The Miner's Guild givers"). `portable_test.lua`: the 36 foremen and six guild leaders on seed 42's real sockets (`tools/seed_fleet/runtime.lua`, the camp index, `capital_services.GUILD_HALL`) with their roles and factions, the exchange socket taken as `guild_exchange`, the tier roles binding a probe quest in one variant per foreman; on the r57_details game harness the camp vendor's and the exchange counter's definitions, `grug_guild.vendor_rows`/`buy` (rank, balance, full bag, no faction: nothing spent; the balance spent, never the lifetime), the reputation page in the window (locked rows, forged clicks), the exchange counter without a page, and the camp vendor's repair (its provider's faction, range and socket checks, a worn item repaired through the Repair button). `scene.lua`: the scene for `tools/r55_game/capture.sh` (`SCENE=tools/r58_campnpc/scene.lua`): the reputation page at rank 0 and 3, a purchase, the camp vendor's Trade-in and Repair, the exchange counter, a foreman's and a guild leader's dialog (a probe quest in the disposable world).
- **Round 58 lanes HALLS, HALLS2** (`r58_halls`): the Miner's Guild house in the six capitals, on a district plot `miners_guild` with its ore yard and headframe (settlements.md "The Miner's Guild houses"). `make_halls.py` (`--check`) writes the six `<capital>_miners_guild.tpl` templates from one parametric design (edit the script, not the files); `portable_test.lua [REPO] [SEEDS]`: one house per capital (roster, the plot in its district, no hall socket in the core or another plot), the hall socket contract (`capital_services.lua` `GUILD_HALL`, the plot-prefixed ids), the picked banner and emblem nodes in each template, every hall socket reachable from the plot's arrival, and the planner placing the house in every capital for the seeds given (default 1,7,58; about 17 s a seed); `plan_layout.lua REPO SEED` prints one seed's capital plans as data; `view/capital.lua` composes a capital (or with `"district"` only the house's district) from such a plan for the town viewer, `view/<capital>_district_blueprint.lua` hand it to `building_templates/viewer/build_viewer.py` (`R58_HALLS_LAYOUT=` names the plan); `build_pages.py OUT_DIR [--standalone] [--seed=N]` writes the review pages (the six houses' template gallery; the six houses in their districts in the town viewer); `capture.sh OUT_DIR` (`XVFB=`, one boot with a client, the method of `r51_ft/capture.sh`) with the disposable probe `grug_probe_r58_halls` the engine shots of three houses outside and inside and an in-world check of each frieze, emblem sign, banners, rail and sheave wheels.
- **Round 58 lane TOWNFIX** (`r58_townfix`): the Round 56 town fixes. `portable_test.lua` builds the parts, capital cores and start towns through the game's loader and compositions and walks them with a small player model (half-node steps, a 1.7-node body clearing every walkable node of the column it stands in and leaves, the node registry's walkability): Lethariel's bough platforms from the stair's foot to the hall door, the five core gatehouses' inner stair from the east door to the first floor (every tread along its axis, the turn on a landing) and on to the deck, their doors, idle posts, deck opening and closed walls, the throne guards' posts within 5 m of the king in the six halls, every core gate's watch (no passage posts or tower loop, the deck post, two counter-rotating loops of one rectangle on open city-side ground, the small loop's reach, three guards), the terrace stair for lifts 1 to 5 and Silverleaf's two terrace houses, and the six start towns' waystone and mailbox near the centre. The throne guards' post and no-wander behaviour is `r41_mob`'s case P. `XVFB=… capture.sh OUT_DIR` (one boot through the queue; the method of `r57_qsys/capture.sh`) with `grug_probe_r58_townfix`: Silverleaf's centre and terrace stair, Lethariel's gatehouse stair, deck and watch, a bough platform and the king with his throne guards. `lethariel_core.lua` is Lethariel's core as a blueprint chunk for the town viewer (`building_templates/viewer/build_viewer.py`).
- **Round 58 lane GUILDQUESTS** (`r58_guildquests`): the Miner's Guild's quests ([miners_guild.md](../docs/design/miners_guild.md) §11). `build_structure.py` (`--check`) writes the structure with placeholder texts (it overwrites texts: the JSON files are the source once the texts land); `report.py` prints the reward table and the per-camp numbers; `questmap.py [--out FILE]` writes the structure page (the questmap on a draft of the guild's quests alone); `guild_world.lua` gives a portable harness the camps and capitals whose foremen and leaders `npcs.lua` registers; `names_proposals.json` names the camps-under-construction's guards (`tools/r38_b1/gen_names.py --proposals`); `portable_test.lua`: the shipped files' structure and, on seed 42's real sockets through the real loader, the role binding and the offers (tier ≥ k, the follow-up after both gathers at its leader, the hunts and the raid at their foremen), and `validate.py --game`.
- **Round 58 lane ROOMS** (`r58_rooms`): the Miner's Guild lift rooms (`wp40/guild_rooms.lua`, the room step `wp40/guild_room_writer.lua`, `wp40/guild_room_protection.lua`, `guild_room_nodes.lua`). `portable_test.lua` (stub camps): the rooms at their tiers' floors and their shape, a box split over chunk edges written the same in any chunk order, the room step in the early-out chunks and after a writer veto (the real `air_chunks.lua` and `degrade.lua`), liquids round the boxes, the protection wrapper, the real spawn policy and depth pulse refusing a room, the fill's definition and the real `grug_home/travel.lua` `passable()`/`safe_arrival()` on the arrival. `grug_probe_r58_rooms` (staged with `tools/luanti_headless.sh` `PROBE=`, one boot through the queue; settings `r58rooms_max`, `r58rooms_camps`): emerges only the room boxes and logs a `CHECK` line per room (every node, no liquid or ground content, light, protection, spawn refusal, the liquids round the box).
- **Round 59 lane QSYS3** (`r59_qsys3`): the quest-system changes of the band 11–20 ([quests.md](../docs/design/quests.md) "Story and free play", "Town places"). `socket_places.lua` builds the sockets of named settlements from their templates and blueprints as the mapgen does (a capital's core and plots, a plot's socket ids with their plot id and whether every world builds the plot; every other settlement's blueprint): a command for `tools/r28_design/validate.py`'s town places (`--templates DIR` builds from a copy) and a module for the portable quest harnesses (`extend` adds the town places the quest files name to a harness's registry stand-in; `tools/r28_q0`, `tools/r56_questmap`). `portable_test.lua` pins the contract: the registry's `quest_place` role, the tool on the real templates and on fixture sockets read through `io.open`, the town place's resolution and its refusals (`labels.lua` `Q.use_place`), the object's stand in the socket's cell (`use.lua`), `E-use-place` and the per-faction `E-free-follow-ups`. `engine.sh OUT_DIR` (one boot through the queue) with `grug_probe_r59_qsys3`: a probe settlement's `quest_place` socket on a free cell inside Highcourt's Miner's Guild house (under its roof), a probe quest through the real loader and checks, a player stand-in's hold credited.
- **Round 59 lane BANDQUESTS** (`r59_bandquests`): the band 11–20 on the Round 57 quest foundation (quests.md "The band 11–20"). `build_structure.py` wrote the six zones' structure once with placeholder texts (the texts are BANDTEXT's and the JSON files their source; a rerun writes the placeholders back), and its `--check` compares the structure only, everything but the texts; `report.py [--before REF]` prints the quests per zone, the objective kinds, the mob names the kills count and the reward table; `portable_test.lua` (the real `grug_gear` and `grug_quality` on the r57 stub) checks the shipped files: shared variants, free play, the departures, the witness and the perpetrator local, no reward as a request, the reward pattern with every stack at its item level and enchants, the use places (the camps' `quest_place` sockets through `tools/r59_qsys3/socket_places.lua`, the recipe places). The offers through the real grug_quests are `tools/r28_q0`'s section 5.
- **Round 60 lane BANDQUESTS** (`r60_bandquests`): the band 21–30 on the Round 57 quest foundation (quests.md "The band 21–30"). `build_structure.py` wrote the eight zones' structure once with placeholder texts (a rerun writes the placeholders back; `--check` compares the structure only); `portable_test.lua` (the real `grug_gear`, `grug_quality`, `grug_mobs/subtypes.lua` and `grug_housing/soulbound.lua` on stubs) checks the shipped files: shared variants, free play and chapter 2's three band steps, the kept ids, few mobs, the reward pattern, the use places, the line plan and the soulbound Dispatch Folio. The seed fleet checks the recipe quest places on every seed (`seed_fleet/seed.lua`).
- **Round 61 lane BANDQUESTS** (`r61_bandquests`): the band 31–40 on the Round 57 quest foundation and chapter 3 (quests.md "The band 31–40"). `build_structure.py` wrote the six contested zones' structure once with placeholder texts (the 41–60 main line copied as shipped, marked `story`; a rerun writes the placeholders back; `--check` compares the structure only); `portable_test.lua` (the real `grug_gear`, `grug_quality`, `grug_mobs/subtypes.lua` and `grug_housing/soulbound.lua` on stubs) checks the shipped files: shared variants, free play and chapter 3 (A5/A6, T4/T5 with Scrip's, Rattle's and the raid's free quests), the kept ids, the main line kept and marked, the optional group quests, few mobs, the reward pattern, the use places, the line plan, the soulbound Runner's Packet and the leaders. `questmap.py [--out FILE]` writes the band's structure page (a draft folder for `tools/r56_questmap/questmap.lua --data`, with the ledger 30→40 in its intro).
- **Round 59 lane STORYQUESTS** (`r59_storyquests`): chapter 1's story quests in the six capitals ([quests.md](../docs/design/quests.md) "Chapter 1 in the capitals"). `build_structure.py` wrote the four quests, the leaders' hubs and the envoys' common line once with placeholder texts (the texts are BANDTEXT's and the JSON files their source; a rerun writes the placeholders back), and its `--check` compares the structure only, everything but the texts; `portable_test.lua`: the files, the six town places in their plots as the mapgen builds them, the real loader on seed 42 (the offers at the envoys and leaders, the turn-ins, the use at the right capital's town place, the guild reports still at the leaders), the places' cells on seed 42's own chunks, and `validate.py --game`. `engine.sh OUT_DIR` (one boot through the queue) with `grug_probe_r59_storyquests`: the six town places' cells on the running world and one hold of `story_accord_02`'s object at Highcourt by a player stand-in. `questmap.py [--out FILE]` writes the joint structure page of the band 11–20 and chapter 1 (both Round 59 lanes; a draft folder for `tools/r56_questmap/questmap.lua --data`, with the ledger 10→20 in its intro).
- **Round 60 lane CAPITALS** (`r60_capitals`): the six capital files on the Round 57 quest foundation ([quests.md](../docs/design/quests.md) "The capitals"). `build_structure.py` wrote their structure once with placeholder texts (chapter 1 copied as shipped; a rerun writes the placeholders back), and its `--check` compares the structure only, everything but the texts; `portable_test.lua`: the files (flagged, free play, the hubs and lines, the kept ids, T3's prerequisites and place, the shared quests, the Alchemy quest never a reward), the Alchemy quest's ingredients, T3's town place in its plot as the mapgen builds it, the real loader on seed 42 (the foremen's titles, the offers and turn-ins, T3 hidden until its prerequisites), the place's cells on seed 42's own chunks and `validate.py --game`. `engine.sh OUT_DIR` (one boot through the queue) with `grug_probe_r60_capitals`: the public register's cell and a top view of the forecourt on the running world, the two named foremen, and one hold of T3's claim notice by a player stand-in. `questmap.py [--out FILE]` writes the joint structure page of the band 21–30 and the six capitals (both Round 60 lanes; a draft folder for `tools/r56_questmap/questmap.lua --data`, with the ledger 20→30 in its intro).
- **Round 59 lane STORYART** (`r59_storyart`): GPT-6 Astra's four quest objects of the band 11–20 and chapter 1, the user's picks (`dispatch_record`, `witness_record`, `snare_bundle`, `held_supplies`; `grug_quests/LICENSE-media.md` "Round 59"). `paint_art.py` (Python 3 with Pillow) paints them into `mods/PLAYER/grug_quests/textures/`, `--check` verifies the shipped PNGs byte for byte; `drop01.py` and `drop01b.py` are the drops' generators trimmed to the picks. Provenance, not a fixture.
- **Round 60 lane STORYART** (`r60_storyart`): GPT-6 Astra's four quest objects of the band 21–30 and chapter 2 and three quest item icons, the user's picks (`signal_lantern`, `sighting_frame`, `reading_knots`, `claim_notice`; the Dispatch Folio and both Captain's Orders; `grug_quests/LICENSE-media.md` and `grug_mobs/LICENSE-media.md` "Round 60"). `paint_art.py` (Python 3 with Pillow) paints them into `mods/PLAYER/grug_quests/textures/` and `mods/ENTITIES/grug_mobs/textures/`, `--check` verifies the shipped PNGs byte for byte; `drop02.py` and `drop02b.py` are the drops' generators trimmed to the picks. Provenance, not a fixture.
- **Round 62 lane BAGS** (`r62_bags`, no Lua fixture: the bag pins live in `r48_bags`, `r44_ih` and `r33_c1`): `capture.sh OUT_DIR` (`XVFB=`) with `grug_probe_r62_bags` the engine screenshots of the Inventory page with four 20-slot bags (two Great Cloth Bags, two Leather Rucksacks), at the top and scrolled to the end; `probe.txt` names each list's size, the grid's rows and the scrollbar's maximum (the r50_hotbar method).
- **Round 61 lane STORYART** (`r61_storyart`): GPT-6 Astra's quest object of the band 31–40 and chapter 3 and one quest item icon, the user's picks (`storm_vessel`; the Runner's Packet; `grug_quests/LICENSE-media.md` and `grug_mobs/LICENSE-media.md` "Round 61"). `paint_art.py` (Python 3 with Pillow) paints them into `mods/PLAYER/grug_quests/textures/` and `mods/ENTITIES/grug_mobs/textures/`, `--check` verifies the shipped PNGs byte for byte; `drop03.py` is the drop's generator trimmed to the picks. Provenance, not a fixture.
- **Round 60 lane HERBS** (`r60_herbs`): the Alchemy herbs in their tiers' level bands ([world_zones.md](../docs/design/world_zones.md) §11). `reach.lua` indexes where every Alchemy ingredient comes from per zone (the Round 46 locality index plus mob loot by drop band, the real recipes under stubs) and names the zones a race checks per tier; `portable_test.lua` checks the gates, every listed zone's hosts, every herb and cooking input of every tier in each race's band zones, and the gathering digest with its mapgen pin (`--table` prints the herb table and the mob-loot gaps); `count.lua REPO SEED ZONE ...` counts the sources the real writer places in four surface chunks per zone (the seed fleet runtime, with CPU seconds), to compare two trees.
- **Round 62 lane TEMPLATEFIX** (`r62_templatefix`): the building-template defects fixed before the deploy's map reset, and the points `building_templates/check.py` still reports unreachable, walked in the towns the game's loader and compositions build with `r58_townfix`'s player model (loaded from that fixture's text before its section B). `portable_test.lua`: Kezamba's moot-house double door with both upper cells and its inside point reached from the porch, both Lethariel mere shrines' inside point on the floor and reached from the box edge and (core) the street, Sunscar's warlord platform reached from the street by the town's outer stair, and the five core gatehouses' passage posts reached from both passage mouths and the city side and kept as no socket by any core (the checker's walker starts only at the chamber doors). `XVFB=… capture.sh OUT_DIR` (one boot through the queue; the method of `r58_townfix/capture.sh`) with `grug_probe_r62_templatefix`: the moot-house double door from the porch and from inside and both mere shrines, with the door cells and the cells at the shrines' inside points logged.
- **Round 62 lane FRONTQUESTS** (`r62_frontquests`): the front 41–60 on the Round 57 quest foundation (quests.md "The front 41–60"). `build_structure.py` writes the ten `.front` files, the four Battlegrounds files (flagged, their guild content as shipped), the four contested host base files' main-line steps (story, placeholder completions, rewards) and the shared front quests homed there, with placeholder texts (the spine and the fortress quests keep theirs; a rerun writes the placeholders back; `--check` compares the structure only); `portable_test.lua` (the real `grug_gear` and `grug_quality` on stubs) checks the 48 flagged files, the spine chained only on itself, free play, the group quests below 51, the ten shared front quests, the departures, the island pairs, the reward pattern per faction and band, the places, names and kill share, the line plan and `--check`. `questmap.py [--out FILE]` writes the front's structure page (a draft folder for `tools/r56_questmap/questmap.lua --data`, with the ledger 40→50 and 50→60 in its intro).

- **Round 63 mining camps** (`r63_camps`): `build_templates.py [--check]` freezes the accepted browser composition into twelve ordinary templates, keeping race material roles and capital headframes. `portable_test.lua` covers all 72 race/kind/rotation combinations: gate access, actor clearance and reachability, lift approach, central yard and the mirrored war commander.
- **Round 63 camp art** (`r63_camp_art`): `build.py [--check]` generates the canvas PNGs and animated B3D meshes (the faction banners and inventory heraldry come from `r67_emblem` since Round 67); it validates the engine's chunk hierarchy, mesh indices and UV convention. `portable_test.lua` checks the 18 protected art nodes.
- **Round 65 lane QUEST** (`r65_quest`): one acceptance rule (a quest is accepted from its level − 2), the giver dialog without locked rows and the grey "!" for a next quest one or two levels away. `portable_test.lua` (the real registry, state, labels, npc and validate files on a fake engine, the Dawnmere elder's quests from the shipped file) checks the acceptance levels and that `r28common.acceptance_level` and the ledger agree, the elder's rows and hint at levels 1, 3 and 7, the status order, the hint-only dialog, the marker at L+1, L+2 and L+3, unmet prerequisites, the stale-`min_level` error and Help → Quests.
- **Mining camp visual review** (`mining_camp_review`): the approved side-by-side browser study, using the shared building viewer; its stored HTML is the design-approval snapshot, while a rebuild reads the current game. Runtime integration is described in [the Round 63 plan](../docs/planning/round63-plan.md).
- **Round 66 lane MAP** (`r66_map`): marker size by the map's pixel size and the camps' faction icons ([world_map.md](../docs/design/world_map.md) "Icons"). `recolor.py [--preview OUT.png]` recolours the war camp and construction camp masters by palette into the faction variants (`tools/r64_map/ship.py` ships them and their masks; `--check` there compares their pixels); `portable_test.lua` (the real `markers.lua`, `window.lua`, `minimap_view.lua`, `settlement_icons.lua`, `hud_layout.lua` and `ui_window.lua` on a permissive fake engine) checks the size rule, the map window's and the minimap's marker sizes per window profile (1920×1080 unchanged; it prints the table), the drawn size in `W.formspec`, the map window's body text growth on a grown viewport (G) and the camps' icons by faction. `XVFB=… capture.sh OUT_DIR` (one boot through the queue; `WIDTH`/`HEIGHT`/`GUI_SCALE`, which sets HUD scaling too; a copy of `r65_hud/capture.sh`) with `grug_probe_r66_map`: the minimap over the Accord war camp nearest the middle and the map window's PvP layer.
- **Round 65 lane HUD** (`r65_hud`): the boxed quest HUD ([quests.md](../docs/design/quests.md) "Accepted defaults"). `portable_test.lua` (the real `grug_xp`, `hud_layout.lua`, `minimap_view.lua` and `grug_quests/hud.lua` on stubs) checks the shared difficulty gradient against the target frame's previous colours, the boxes' sort, labels and title cut, `hud_layout.quest_boxes` (box count and "+N more" per window and scaling, clear of the minimap block and the bottom-centre column; it prints the numbers) and the element diff on track, untrack, progress, level and window changes. `XVFB=… capture.sh OUT_DIR` (one boot through the queue; `WIDTH`/`HEIGHT`/`GUI_SCALE`; a copy of `r62_templatefix/capture.sh`) with `grug_probe_r65_hud`: ten tracked quests of mixed levels at level 20 over a bright sky, then level 30 with three untracked.
- **Round 66 lane UI** (`r66_ui`): the viewport ceiling that grows to two thirds of a tall screen and the form text that grows with it ([ui-presentation.md](../docs/technical/ui-presentation.md)), and the creation window's faction buttons. `portable_test.lua` (the real `ui.lua` and `ui_window.lua` against the engine's fitting equations and a verbatim copy of the 0.65.0 functions; `selection.lua`'s faction style read from the file) checks the ceiling, that every result up to 1620 px screen height equals 0.65.0's, the text proportion where it grew, the faction buttons' states, and prints the screen table. `bytes.lua REPO [map]` prints a length and hash per screen profile of the inventory pages (the `r44_ch` harness) or the map window (the `r44_mq` scene), so a base tree and the branch can be compared.
- **Round 66 lane MAIL** (`r66_mail`): the read-only Sent tab ([mail.md](../docs/design/mail.md) §3). `portable_test.lua` (the real `grug_mail` model, store, api and window and the real `grug_core` ui and ui_rows on a fake engine) checks the sender's text copy (names and counts, never item strings), the 50-cap and the 30-day expiry of `sent:<name>`, no copy for refusals, admin and NPC letters, tickets and announcements, the unchanged letter fields, and the Sent tab (five caption-weighted tabs, the list, the reading pane, Delete without a dialog). `measure.lua [REPO] [LUANTI_SOURCE]` prints the sent list's serialised size at the cap and the storage work a send adds (the engine's own `core.serialize`); `caption_widths.py [LUANTI_SOURCE]` reproduces the engine's form fitting for a few screen profiles and measures the tab captions in Arimo against their buttons (exit 1 if one clips).
- **Round 66 lane EQUIP** (`r66_equip`): the two-handed shift-click swap, the blocked offhand and the equip refusal on the Character page. `portable_test.lua` (through `r44_ch/harness.lua`: the real sfinv, `grug_inventory` equipment, storage and pages) checks the swap with one free slot, without room and with an empty Weapon slot against the two separate moves (hands, caches, items, one notification), the drag refusals in both directions, the blocked offhand per class and the page notice (shown, re-sent without moving an item, gone after 6 s). `XVFB=… capture.sh OUT_DIR` (one boot through the queue; a copy of `r62_bags/capture.sh`, 1920×1080 by default) with `grug_probe_r66_equip`: a feed line with no window and under the Character page, a drag refusal's notice and the swap with the blocked offhand.
- **Round 66 lane ART** (`r66_art`): `generate.py [--check]` reproduces the current 64px RGBA priest-symbol candidates, their local additive/plain review page and contact sheet; [current picks and report](r66_art/REPORT.md), [preview](r66_art/preview/index.html). The FX lane ships the user's picks.
- **Round 66 lane FX** (`r66_fx`): the priest's symbols (the hammer of Smite and Final Word, the book of Censure; `grug_core_fx_hammer.png`, `grug_core_fx_book.png`). `portable_test.lua` (the real `particles.lua` and catalogue on a fake engine): Smite's size-7 hammer from 3.2 m in 0.15 s with the ring after the fall, Final Word's size-12 hammer inside the column in its 0.1 s, Censure's size-16 book with the seal's timing, all untinted, added with glow 14 and unfaded, the particle counts, both textures with their licence rows, and the damage still instant. `XVFB=… capture.sh OUT_DIR` (one boot through the queue; a copy of `r66_equip/capture.sh`, 1280×720, `FRAMES` shots per view) with `grug_probe_r66_fx`: each effect replayed on a platform on grass, on snow and at night. The cards in `r52_pfx/effects.py` carry the same numbers (`r53_hooks` compares them).
- **0.69.1 web bridge** (`r691_bridge`): `grug_bridge` ([contract](../docs/technical/web-bridge.md)). `portable_test.lua` runs the mod's real files and grug_mail's real model, store and API on a stub engine (the exchange, the queue, at most once, every command type, the mail mirror, bans, `init.lua` inert and active). `fake_bridge.py` speaks `/v1/sync`, also by hand (`python3 tools/r691_bridge/fake_bridge.py PORT TOKEN`). `run.sh OUT_DIR` (one queue slot, `XVFB=` an Xvfb binary) runs `scenario.py`: three boots of one world with one real client and the disposable `grug_probe_r691_bridge`; `results.json` holds one row per check.
- **0.66.1 lane PERF** (`r661_perf`): the `[GRUG-PERF]` lines of `grug_perf` ([module guide](../docs/technical/module-guide.md#performance-log-lines)). `portable_test.lua` loads the real `lines.lua`, `monitor.lua` and `init.lua` (on a stub engine) and checks the percentiles, the rounding, every line against the platform parser's rules (marker, one JSON object, finite numbers ≥ 0, integers, the boolean, absent round trips, the size, the `file` pattern, the field set), one minute line per 60 s, the spike threshold and the 10 s spacing, the parser's per-minute caps, no allocation per step, the profile file detection, the census and the periodic save (only with `profiler.load`, warning once per failure streak). `run.sh OUT_DIR LABEL 0|1 [TIMEOUT]` (one boot through the queue; `ROOT`/`KEEPROOT` to re-use a world, `OBS`, `SEED`, `TARGET`) with `grug_probe_r661_perf`: keeps the first identity's capital active, observes the server step, times `grug_perf`'s globalstep in place, reads the process's and Server thread's CPU ticks at the window's edges and benchmarks the real parts; `1` boots with `profiler.load`, `instrument.profiler` and a profile save every minute.
- **Round 67 lane MAP** (`r67_map`): the map window at 90 % of the screen, markers at their anchors at 21 px, the flat layer buttons, the compact quest list and one quest order for the list and the HUD ([world_map.md](../docs/design/world_map.md) "Markers at their anchors", "Map window"). `portable_test.lua` (the real `grug_core` ui, ui_window, ui_rows and hud_layout, `grug_map` atlas, markers, window, layers and quest_box, `grug_quests` hud.lua and npc.lua's `category_list`, on a permissive fake engine) checks the window size per profile (it prints the table: window, map view and marker pixels against 0.66.1's), markers at their anchors and their order, the sizes, the buttons, the compact rows and the shared order, and that today's rows keep their bytes. `bytes.lua REPO` prints the window's bytes per send in a party of five (the `r44_mq` scene of REPO) at 1920×1080 and 3840×2160, so a base tree and the branch can be compared. `XVFB=… capture.sh OUT_DIR` (one boot through the queue; a copy of `r66_map/capture.sh`, 1920×1080 by default) with `grug_probe_r67_map`: the minimap at an Accord capital and the map window's Quests layer and Travel layer at 2× for a level-45 character with story and side quests.
- **Round 67 lane WORLD** (`r67_world`): flight underground with the flyer's room check, the vertical flight speed per tier, nametags only on NPCs with a function, wide mobs with room ([mounts.md](../docs/design/mounts.md) §3.2, [combat_stats.md](../docs/design/combat_stats.md) §4 and §6). `portable_test.lua` (the real `grug_mobs` `room.lua`, `dawn.lua` and `levels.lua`, mobs_redo's `scale_mob`, and the real `grug_mounts` catalog, flight rule and entity on a node map with real collision boxes) checks the room test (a spider in a pocket and in rock; snow, slab and stair footing), the wide spawn rows, the elite/rare scale re-check, the stuck cleanup, the nametag decision per role and disposition, the flyer's summon underground, in a no-fly column and without room, and the vertical speed. `run.sh OUT_DIR [TIMEOUT]` (one boot through the queue; `SEED`, `WINDOW`, `SPIDER_CHANCE` for a larger sample) with `grug_probe_r67_world`: the socket census of idle/work residents, a cave volume's spawn spots by the old and new rule, the wide mobs' underground spawns with the room check recording and then refusing, the stuck cleanup after a give-up, and a start town's NPC carriers by role.
- **Round 67 lane SOCIAL** (`r67_social`): the Social tab, the invitation box and the favourites ([parties.md](../docs/design/parties.md) "The Social tab"). `portable_test.lua` (the real `grug_parties` init, ui and hud, the vendored sfinv api and `grug_core`'s ui, hud_layout and status_icons on a fake engine with a clock and `core.after`) checks the list's order (faction, favourite, name), the invite button for every case of the rulings, the party box with and without a party and its count label, the HUD box (shown, "+N more", the seconds, hidden on expiry, decline and accept, both players cleared when a party forms), the favourites in player meta and the coalesced refresh (a burst one send, the 2 s gap, the scroll hold, the kept scroll value); it prints the tab's bytes with 1, 10 and 50 players. `XVFB=… capture.sh OUT_DIR` (one boot through the queue; a copy of `r62_bags/capture.sh`, 1920×1080 by default) with `grug_probe_r67_social`: the tab with 32 stand-in players (top and scrolled to the end, with invitations and in a party) and the invitation box.
- **Round 67 lane CRAFT** (`r67_craft`): recipe variants, fewer recipes, the craft box, the Materials help page, half fuel times, the Creative row and the migration step 0.67.0 (metal rods refunded as bars; [upgrade contract](../docs/technical/upgrade-contract.md) §5.8). `portable_test.lua` (the whole game's registrations through `r57_details/game_harness.lua`) checks the Creative category row only on a Creative page, no rod, no route from stairs or slabs back to a block, no stem recipe, the stems' plank drop, the outputs that keep several recipes (printed), one list row per output with the variant switch and its default, the plain Craft button with "×N per craft", Details with its info icon left of the star, favourites by output (a stored recipe id read as its output), the fuel times and the Materials page through its own handler (its item count and bytes printed); `run.sh [EVIDENCE_DIR]` (one queue slot) runs `test_step.py` (the offline step in every store, a rerun) in the runner's container and `e2e.py` (a 0.66.1 world built by the 0.66.1 game with `grug_probe_r67_craft`: rods in the lists, the jobs, a letter and Claim Stone entries; the guard's refusal, the shipped tool, a boot and join of this checkout: the jobs return bars); `evidence/` the last run.
- **Round 67 lane CONTAINERS** (`r67_containers`): the storage containers' tiers, labels, Sort and Upgrade ([inventory_equipment.md](../docs/design/inventory_equipment.md) "Storage containers"). `portable_test.lua` (through `r44_ch/harness.lua`: the real `grug_inventory`, plus the real `default/node_formspec.lua`, `containers.lua`, `chests.lua`, `nodes.lua`, `vessels/init.lua`, the claim model and the interaction guard on a fake engine) checks the player's sort against the base commit's digest (`sort_cases.lua`, 60 seeded cases with metadata, the 0.48.0 `sizes` included), a chest's Sort and its cooldown, the label's rights (open world, own claim, foreign claim with and without Everything, a draft claim, locked chests) and hover text, the upgrade (bars charged, contents kept, an open chest with a second viewer, the scroll position, a shelf's open form), the form (rows, scrollbar, rings, slot pictures; it prints the chest forms' bytes), the shelves' growth from 16 to 32, the recipes and the drops. `grug_probe_r67_containers` is a disposable engine probe (staged with `PROBE=` on `tools/luanti_headless.sh`): the tiers' registrations, recipes and prices, the guard on the shelves' fields, a 16-slot shelf's growth and an upgrade on a real node.
- **Round 67 lane ART** (`r67_art`): `python3 tools/r67_art/generate.py [--check]` builds or verifies 12 race-icon and 32 container-texture candidates plus the offline [preview](r67_art/preview/index.html); [recommendations and handoff](r67_art/REPORT.md).
- **Round 67 lane EMBLEM** (`r67_emblem/`): `python3 tools/r67_emblem/generate.py [--check]` builds Pass 4: three pairs of frontal hart/boar heads, each with a muted heraldic UI icon and UV-preserving banner; offline [preview](r67_emblem/preview/index.html), 300 px drawing studies, unchanged Pass 3 A1/B3/current-art comparisons and [recommendation](r67_emblem/REPORT.md).
- **Round 68 lane TEXT** (`r68_text`): text in the world ([module guide](../docs/technical/module-guide.md#text-in-the-world)). `python3 tools/r68_text/import_font.py [--source DIR] [--check]` imports (or verifies) the CC0 sign font from a VoxeLibre checkout into `mods/CORE/grug_text`. `portable_test.lua` (the real `grug_text` and `default/containers.lua` on a fake engine with objects and the builtin vector rotation) checks the wrapping, the texture strings (it prints their lengths for a full wall sign, chest label and 7 × 30 notice board), the font files, the entity's position and turn per wallmounted orientation and chest facing, and the lifecycle (write, rewrite, clear, dig, the LBM without duplicates, label save, open/close, upgrade, two faces, several surfaces). `XVFB=… capture.sh OUT_DIR` (one boot through the queue; a copy of `r67_social/capture.sh`) with `grug_probe_r68_text`: written wall signs on a wall, on every side, on the floor and the ceiling, labelled chests of every tier closed and open. `grug_probe_r68_lbm` (two boots on one world: `KEEP=1 PROBE=… tools/luanti_headless.sh`, then `ROOT=<kept> PROBE=…`): a sign text and a chest label written as meta only, like a 0.67.0 world, get their entities from the LBM on the second boot.
- **Round 68 lane ART** (`r68_art/`): `python3 tools/r68_art/generate.py [--check]` builds six sign-model candidates with textures, 16px icons and text-area specs, plus two calm wall-sign textures; offline [preview](r68_art/preview/index.html), [picks and handoff](r68_art/REPORT.md).
- **Round 68 lane SIGNS** (`r68_signs`): the standing sign, the waypost and the notice board ([module guide](../docs/technical/module-guide.md#text-in-the-world)). `portable_test.lua` (the real `grug_text` and `grug_signs` on a fake engine) checks the models against lane ART's spec (mirrored in x by the OBJ loader; the turned models inside their unrotated boxes; the board's boxes), every text entity's position and facing under the engine's mesh turn, placement (facing the placer, the arrow along the look, stacking from the right-click), the notice board's two-node placement, refusals and digging (its two half meshes are ART's pass-4 halves and rejoin into the one-piece model, positions and texture coordinates; no half left and exactly one board dropped after a dig, a support loss or a removal of either half at every turn, on the builtin dig and attached-node walk transcribed), writing (quit, protection, 512 bytes, control characters, newlines, clearing, the LBM), the recipes, the reading exemption and Help's line; it prints the board's texture string length. `XVFB=… capture.sh OUT_DIR` (one boot through the queue; a copy of `r68_text/capture.sh`) with `grug_probe_r68_signs`: the three signs with text beside a wall sign, a chest and planks, front and back, the board front and at an angle, turned standing signs, a stack of three wayposts, a turned board; `MODE=compare` shoots the board's two halves and ART's one-piece model (staged into a temp copy of the probe) at each turn, front and angle, under a fixed sky, for a pixel comparison.
- **Round 68 lane ICONS** (`r68_icons/`): `python3 tools/r68_icons/generate.py [--check]` builds 141 material-icon and storage-block candidates, the offline [comparison page](r68_icons/preview/index.html), pairwise CIE76 measurements and [installation mapping](r68_icons/INSTALL.md); tools only; all groups picked: bars/metal blocks A, settings B, cuts/blocks D with larger raw specimens in `gems_final/` ([report](r68_icons/REPORT.md)).
- **Round 68 follow-up INSTALL** (`r68_install`): `portable_test.lua` (the real `grug_materials/ores.lua` and `grug_artisans/goldsmith.lua` on engine stubs) checks that each of the 47 ids in [INSTALL.md](r68_icons/INSTALL.md) draws its own file, byte-identical to its candidate, cut gems not derived from the raw image, no `default_*_ingot/block.png` or `default_diamond.png` left, Silver, Emberglass, Anthracite and the ore tiles unchanged, an unknown bar failing loudly; section S (follow-up STAIRS, with the vendored stairs and `derivatives.lua`): the 20 metal stairs and slabs draw their block's face with the vendored tile settings. `XVFB=… capture.sh OUT_DIR` (one boot through the queue; a copy of `r68_signs/capture.sh`) with `grug_probe_r68_install`: the 47 items in inventory slots and as 32/16 px images, walls and 3 x 3 patches of the metal and gem blocks; `SCENE=stairs`: each metal block beside its stair, inner and outer stair and slab.
- **Round 69 lane CAMP** (`r69_camp`): the camp sites' templates and the box rewrite of the migration 0.69.0 ([upgrade contract](../docs/technical/upgrade-contract.md) §5.9). `install_pick.py [--check]` installs the user's pick from `r69_camp_art/candidates/wallwright/`; `check_escape.py` finds a way out from every cell-centred body position in the composition (no engine test); `portable_test.lua` checks the six races in four turns through the real blueprint and the job with a recording engine; `run.sh` (`e2e.py`, the probe `grug_probe_r69_camp`) is the step's test and the two-boot proof.
- **Round 69 lane UI** (`r69_ui`): `portable_test.lua` (the real `grug_inventory` through `r44_ch/harness.lua` with the real `grug_housing/soulbound.lua` and `grug_skills/bound_items.lua` guards) checks the Trash box: its place, the texts in their room, discards, Undo with meta and wear, no room, the refusals with their hint, the bag rules, and the exploits (owner only, nothing to take, double click, leave and relog). The real-client states are `ui_dialogs` scenes (`inventory_trash*`, its README).
- **Round 69 lane QUESTMAP** (`r69_questmap`): quest-drop markers ([world_map.md](../docs/design/world_map.md#quest-targets)). `portable_test.lua` (the real loader through `r56_questmap/model.lua`, the real `state.lua`, `hud.lua`, `targets.lua` and `quest_box.lua`) checks the fourteen quests with a named source in every variant, their targets over the shipped recipes, that every other item objective marks nothing, the marker going when the item is carried, and the objective lines with their width (it prints the HUD lines that get cut). `grug_probe_r69_questmap` is a disposable engine probe (staged with `PROBE=`): the same on a booted world's real index, with each variant's lines.
- **Round 69 lane HOME** (`r69_home`): respawn goes where the home teleport goes ([home travel](../docs/design/home_travel.md)). `portable_test.lua` (the real `grug_home` and the `grug_factions` respawn hook on a fake engine, with fake claims) logs every teleport and the hold's release and checks one resolver for claim, unfuelled claim, innkeeper and no binding; no cooldown and no combat rule; the arrival on the stone in one teleport, an unloaded cube included; a cube blocked before or during the respawn; failed and stalled areas down to the start pocket; a claim lost while dead or on the way; death, leave and rejoin on every leg; no faction and creation stasis. The Round 25 engine probe (`r25_home_stone/engine/run.sh`) gained the respawn steps on the real emerge path.
- **Round 70 lane TOWNS** (`r70_towns`): the reworked start towns and the road wayposts. `portable_test.lua` builds the six towns through the game's compositions: every socket where the land-use study's schedule (`r70_design/data/socket-schedules.json`) says, the 13 × 13 waystone pocket clear, every socket, door front, patrol waypoint and arrival side reached on foot from the spawn; and `wp40/wayposts.lua` on a small road network (which junctions get a stack, its column, the arrows' turns, the names). `seed_fleet/seed.lua` checks the wayposts on every seed. `XVFB=… capture.sh OUT_DIR` (one boot through the queue; the method of `r58_townfix/capture.sh`) with `grug_probe_r70_towns`: two views of each town from its arrival and one generated waypost with its nodes, text and text entities logged.
- **Round 69 lane PUSH** (`r69_push`): idle aggressive mobs walk away from active claims ([combat_stats.md](../docs/design/combat_stats.md)). `portable_test.lua` (the real `aggro.lua`, `roam_avoid.lua` and `grug_housing/registry.lua`, with `SR.in_drift` and `claim_refuses_spawn` cut from their files) checks that a claim leaves `roam_avoid_hit` and the drift band alone, the same active test as a spawn refusal, who is pushed, a claim over a mob's home, and prints the cost of a probe with no claim near.
- **Round 69 lane SKILLS** (`r69_skills`): the exact numbers in the skill tooltips ([classes.md](../docs/design/classes.md) "Numeric ability tooltips"). `portable_test.lua` (the real `grug_abilities` with its kits, `talent_windows.lua`, `area.lua`, the real talent graph and `talent_graph_ui.lua` in a sandbox, then the page through `r44_ts/harness.lua`) checks every "N damage" of every class at levels 10, 30 and 60, untalented and at full ranks, against what a real swing, shot or cast computes; the refresh on level, talent, equipment and status changes; the granting nodes' text against the hotbar stack's, learned or not, and the longest node tooltip (printed); the strip's order and the open page's re-render.
- **Round 70 lane SPAWN** (`r70_spawn`): the source rules of [round70-plan.md](../docs/planning/round70-plan.md) §2.1. `portable_test.lua` checks the water predicates, the six rows, that the real writer's decision and the real renewal authority accept the same columns, and renewal's band and shore chance. `census.lua REPO SEED` (a whole world on the seed fleet's harness: about 20 minutes, through the queue) counts eligible columns and written nodes per source and zone and that the renewal authority accepts every written node; `table.py` prints the runs side by side; `chunk_cost.lua REPO SEED` compares the writer's seconds on chunks of the five Stormkelp zones between two trees.
- **Round 70 lane PLANTS** (`r70_plants`): decorative plants drop themselves ([biomes_mobs.md](../docs/design/biomes_mobs.md) §1.3). `portable_test.lua` (the whole game's registrations through `r57_details/game_harness.lua`, with a small fake world) checks each plant's drop, tooltip, tier and sale, the placement of the waterlily, the rooted water plants and the hanging plants (refusals and protection included), digging, and that leaf decay drops nothing. `grug_probe_r70_plants` (`PROBE=… tools/luanti_headless.sh`) runs the same placements through the engine's own `core.item_place` and `core.node_dig`.
- **Round 70 lane FARMFIX** (`r70_farmfix`): varied growth (`r48_farm` section V), belt first and usable pickup (`r44_ih` sections G and I), the belt in quests (`r50_hotbar`). `capture.sh OUT_DIR` with `grug_probe_r70_farmfix` shows corn stages 2, 3, 4 and wild corn in a real client and logs the CHECK lines on real engine objects: a hoe at a real drop, a broken hoe, the belt, tilling, a planted row's timers, the list of usable items.
- **Round 70 lane DEATH** (`r70_death`): the death penalty ([durability and repair](../docs/design/durability_repair.md)). `portable_test.lua` (the real `grug_core` combat seam, `hud_layout`, `grug_pvp` and `grug_repair` through its `init.lua`) checks the 10 % at every tier and slot, trinkets and hotbar tools untouched, ten deaths to the break, the 30 s PvP window beside the 15 s credit (fall, drowning, a mob inside it; own-faction and mob hits outside it; an enemy gone offline), the logout death decided at leave and a 0.69.0 mark, the two HUD hints on every event, a use reading one slot, and the placement over desktop and web windows. `XVFB=… capture.sh OUT_DIR` (one boot through the queue; a copy of `r65_hud/capture.sh`) with `grug_probe_r70_death`: the two hints over the real HUD.
- **Round 70 lane LEVELS** (`r70_levels`): boss levels and item levels ([round 70 plan](../docs/planning/round70-plan.md) §2.10). `portable_test.lua` (the real `levels.lua` on a stub, the fixed levels at their definitions; the item levels and the crown live in `r33_c1` and `r33_c4`), `numbers.py` (King, General and dragon fights and a mob 3 levels above the player, before and after the Round 70 malus, on the `r36_r` model).
- **Round 72 lane WAYTAB** (`r72_waytab`): `portable_test.lua` (the real `grug_home` and `grug_expeditions` on one fake engine, preparation and template faked) checks the Expeditions tab of the waystones and the Claim Stone (owner, party member, stranger, the level refusal, being prepared, combat and the stone's reach), entering from it, the stones inside opening the ordinary waystone window without the tab, and a trip out and back in. The Claim Stone form's tab is in `r25_interfaces`, the Registrar's letter in `r48_quest`. `XVFB=… capture.sh OUT_DIR` (one boot through the queue, 2 slots; `tools/r71_ui`'s method) with the disposable probe `grug_probe_r72_waytab`: the tab with nothing to enter and with a run, entering, the window of a stone inside, a trip out to Dawnmere and back in by its tab.
- **Round 73 lane TOOLS** (`r73_tools`): the authoring helpers beside `expedition_templates/shaping.py` for the Expedition sources ([format](../docs/technical/expedition-template-format.md#authoring-helpers-round-73)): `relief.py` (the only writer of floor stairs: height map to stairs and param2, every refusal, seeded uneven pits, rises and terraces), `passages.py`, `light.py`, `dressing.py`, `hazards.py` (the lava fall, ambush alcoves), `registry.py`; `expedition_templates/proofs.lua` is now the one shared proof (concept section 7, items 1-11: the floor as a height map from the written file, rules by id, a per-rule report switch), run by `r71_l20`, `r72_shift` and `r72_mint`; `preview.py` draws relief, light zones, ambush, lava, critters, particles and a section through every stair run (`--name`, `--file`). `portable_test.lua` runs `cases.py` (the helpers on hand-made maps, every relief refusal) and proves its small templates: one meeting every rule, one per rule breaking it; then lane GAME's `test_vault` with every rule on, its known gaps reported.
- **Round 73 lane HPCAP** (`r73_hpcap`): mobs keep health above 65,535, the engine's `hp_max` limit ([expeditions.md](../docs/design/expeditions.md) §13-15 bosses, the dragons). `portable_test.lua` loads the real `levels.lua` with cut-outs of `mobs/api.lua` (check_for_death, update_tag, staticdata, activation, feeding), the leash reset's heal, the health bar and the Warrior's below-30 % test, on a fake object that clamps `hp_max` as the engine does. It checks Auditor Nemm at level 60 after a hit (property 65,535, the game's max kept; nametag, infotext and bar), heals to the design max (reset, feeding), the wounded fraction kept on a level change, save and reload (old saves without the max too), the Warrior's share, a dragon on the flat boss tier (100,000) and its enrage line, a mob below the limit as before, and the bosses above the limit with their numbers (Round 73 BOSSHP).
- **Round 72 lane PROOF**: `expedition_templates/proofs.lua`, the user's room rules over a written Expedition template, used by the fixtures `r71_l20`, `r72_shift` and `r72_mint`: free height over every floor cell (three nodes in Round 72), no perch (a walk, jump, leap and fall search over node tops finds no place off the floor but waystones and the chest, and no rope in reach), every floor cell of a pack room noticed by its pack, and no walk from a pack room's way in to its way on or its ore that keeps out of every cell the pack notices. Each fixture brings its rooms, packs and ways (Round 73 TOOLS: sight, light and the floor's height map moved into the proof); the probes of the three `run.sh` shoot one PNG per room.
- **Round 72 STYLE**: `python3 tools/expedition_templates/preview.py` renders the written Expedition files as plans and two sections per room into uncommitted `style-previews/` (Round 73 TOOLS: relief and light plans).
- **Round 71 lane REWORK** (`r72_rework`, planning only): `python3 tools/r72_rework/floorplan.py` (`--grid`, `--check`; Pillow) draws the floor plans, tables and four-node grids of the Round 72 build plans [The Second Shift](../docs/planning/round72-second-shift.md) and [The Last Mint](../docs/planning/round72-last-mint.md) into `docs/planning/round72-expeditions/`; proposals, not game templates (those are `expedition_templates/sources/`).
- **Round 71 lane FRAME** ([`expedition_templates`](../docs/technical/expedition-template-format.md) and `r71_frame`): `expedition_templates/build.py` (`--check`) writes the Expedition templates from `sources/*.py`. `r71_frame/portable_test.lua`: the catalogue, the template reader, the preparation on a fake map that generates whole chunks as the engine does (order, budget per step, the gate), and the rules of a run (create, enter, owner changes, release, login, the way out). `XVFB=… SCENARIO=<name> r71_frame/run.sh OUT_DIR` (through the queue, 2 slots; lane SPIKE's method): one real client at a real viewing range (`VIEWING_RANGE`, default 190) and the disposable probe `grug_probe_r71_frame`; scenarios `basic`, `move` (the job time per step and the chunks generated, walking over fresh land), `life` (create to end, the clock, a rewrite over planted leftovers), `restart1` then `restart2` (`KEEP_WORLD=1`, then `WORLD=<root>`), `tag` (a player's attachments survive a run's end and a preparation; lane FOLLOW).
- **Round 71 lane SPIKE** (`r71_spike`): measures clearing and writing an Expedition box off the map, with one real client on Xvfb. `XVFB=… SCENARIO=<name> run.sh OUT_DIR` (2 slots of the shared queue; `KEEP_WORLD=1`, `WORLD=<root>` for a second run on one world) stages the disposable probe `grug_probe_r71_spike` (`sizes`, `methods`, `emerge`, `visit`, `left1` then `left2`, `left3a` then `left3b`, `queue`, `shell`, `spawns`, `seal`, `final`) and writes `probe.txt` (phases with step intervals, verification against the template and a computed light), `load.txt` (to tell contended runs) and `db.txt` (`db_census.py`: what the run left in the map database). Nothing under `mods/` changes.
- **Round 71 lane UI** (`r71_ui`): the registrar. `portable_test.lua` (the real `runs.lua`, catalogue, socket registry, toolkit and `registrar.lua`) checks the socket, the window's rows (the two-step tier and level dropdowns of lane RANGE), the refusals, the notices, the invitation warning and the maps off the map; the role change itself is `r451_nq` section S. `old_world.sh` (twice through the queue, with `KEEP=1` and then `ROOT=`) proves on a kept world that the registrar replaces the clerk with no map reset. `XVFB=… capture.sh OUT_DIR` (one boot through the queue) with `grug_probe_r71_ui`: the window, the warning, the arrival and the maps in a real client.
- **Round 71 lane MOBS** (`r71_mobs`): `portable_test.lua` (the real `encounters.lua`, `chest.lua` and `loot.lua` on stubs) checks rooms, no respawn, the boss's credit, the door, the per-player chest, the Expedition's drop filter and the load checks; item levels above 60 are in `r33_c1`. `XVFB=… r71_mobs/run.sh OUT_DIR` (through the queue, 2 slots): one real client and the disposable probe `grug_probe_r71_mobs` on `test_vault`, at an active-mob limit of 1 and a short block unload.
- **Round 71 lane PACK** (`r71_pack`): `portable_test.lua` (the real `packs.lua` and `aggro.lua` on stubs) checks the pull, no de-aggro, combat through a pause, jumps, a new body for an inactive member, the wipe, the boss, the logout rule, and proves on 300 seeded worlds that nobody is held with nothing able to reach them. Section I idles The Stilled Seam's real markers for an hour; the capital after a logout death runs the real `travel.lua` in `r69_home` section G. `XVFB=… r71_pack/run.sh OUT_DIR` (through the queue, 2 slots): one real client, restarted at each `RELOGIN` line, and the disposable probe `grug_probe_r71_pack` on `test_vault` with its markers replaced.
- **Round 71 lane L20** (`r71_l20`): `portable_test.lua` checks The Stilled Seam's catalogue row, its loot table and, over the written template's cells, the plan's grid, the eight marked nodes, the route for a player and a mob, the sealed store, the packs (no two link, no floor cell in two packs' sight) and the light; lane RANGE's section J the tiers over 20-69 (each tier's ore and gem in the template's places, the dig marks), the chest's materials by band and every mob's name at every level. `balance.py` models three players at the run's level, 20 to 69 (60 with the level malus above): time and damage per pack, Flintback, XP per run, the chest's coins, and an estimate of the tier's ore and gem per player against the same time of mining. `XVFB=… r71_l20/run.sh OUT_DIR` (through the queue, 2 slots): one real client and the disposable probe `grug_probe_r71_l20`, a run from create to the store at level 20 with the quest, and the rooms at 29; one shot per room.
- **Round 71 lane L20DOC** (`r71_l20doc`): `floorplan.py` (Pillow) writes the plan of [The Stilled Seam](../docs/planning/round71-l20-description.md); `--grid` prints the matching text grid.
- **Round 71 lane OUTLINE** (`r71_outline`): `sketch.py` (`--check`) draws the route sketches of the [four proposals](../docs/planning/round71-expeditions-outline.md).
- **Round 72 lane TRAPS** (`r72_traps`): `portable_test.lua` (the template's `trap` lines and the real `traps.lua` on a fake engine whose map is `test_vault`, with the real particle path counting what is sent) checks the choice per creation, the floor trap's trigger, ring, hit, mark and rearm, the wall's period, offset, flight, stone and burst, the strike helper and the run's end, players only. `XVFB=… r72_traps/run.sh OUT_DIR` (through the queue, 2 slots): one real client and the disposable probe `grug_probe_r72_traps` in `test_vault`'s trap gallery; `ring.png` and `fireball.png`.
- **Round 72 lane MINT** (`r72_mint`): The Last Mint ([expeditions.md](../docs/design/expeditions.md) §15). `portable_test.lua` proves the written template cell by cell (the grid, ore and gem with T6's swap, the floor's height map with its stairs (flat in Round 72), the free height, the routes for a player and a mob, the sealed store and hull; the lake: lava enclosed, pillars, six level gaps, the jump, no ledge, no Blink out; the shot lines open and every top clear; the roster; no pack walked round, none linked, the arrival out of sight; the light), the catalogue row and who may create and enter at 60 and 69 on the real `runs.lua`, the chest, the real `traps.lua` on this map (chosen per creation, a floor trap's hit, nobody waiting on a top hit, a jumper hit), lava's five ticks and the Return Home refusal on the real `travel.lua` and `guard.lua`, `grug_core/lava_guard.lua`, Duewarden, the names through 69 and the quest. `balance.py` models four players at 60-69 (the roster and Duewarden's HP factor read from the shipped files). `XVFB=… r72_mint/run.sh OUT_DIR` (through the queue, 2 slots): one real client and the disposable probe `grug_probe_r72_mint`, a run from create to the chest at 60 with the six jumps both ways by real key presses (`keys.py`), the lava's ticks and the refusal, and the rooms and Duewarden at 69; `evidence/probe.txt` holds the lane's run.
- **Round 71 lane GUARD** (`r71_guard`): `portable_test.lua`: the world exception, the spawn-free field, `guard.lua`'s answers and the template's `dig` line (the respawn row: `r69_home`). `XVFB=… SCENARIO=rules|spawns|wander r71_guard/run.sh OUT_DIR` (through the queue, 2 slots; `CONF=<file>` with `r71guard_gate = off` runs without the field): one real client and the disposable probe `grug_probe_r71_guard`.
- **Round 72 lane SHIFT** (`r72_shift`): The Second Shift ([expeditions.md](../docs/design/expeditions.md) §14). `portable_test.lua` checks the catalogue row and the entry rules at 40 and 69 (the real `runs.lua` on stubs), the chest by band, and over the written template's cells the plan's places, rooms and passages, the floor's height map (flat in Round 72) and head room, the eight marked nodes, the route for a player and a mob, the sealed store, the packs and their places, "no pack can be walked round" (every floor cell of a pack room noticed by a mob of it, by view range and sight), the sight between packs and the light; the real `traps.lua` on this template (the picks per creation, every floor trap and the wall at a player) and Auditor Nemm's marked spot; Nemm's definition and clock (the real `skeleton_raider.lua` on stubs); the quest and the names. `balance.py` models four players at 40-69 from the template's counts: packs, Nemm, the run, XP, coins and the ore against mining. `XVFB=… r72_shift/run.sh OUT_DIR` (through the queue, 2 slots): one real client and the disposable probe `grug_probe_r72_shift`, a run from create to the chest at 40 with the quest and at 69.
- **Round 72 lane TAGS** (`r72_tags`): friend and foe nametags ([combat_stats.md](../docs/design/combat_stats.md) "Nametag categories"). `portable_test.lua` (the real `grug_core/tag_carrier.lua` on a stub) checks a guard, an NPC, a King and players seen by a friend, a foe, both and a viewer without a faction; the foe carrier made on approach and removed when the foe leaves; the text, the HP bar and the visibility callbacks over both sides; the colours kept by mobs without a faction and by capital displays; and prints the carrier count with and without a foe nearby. `run.sh OUT_DIR` (one boot through the queue) with `grug_probe_r72_tags`: a start town force-loaded with nobody connected; every guard's tag resolves to the friend green, every other tagged NPC's to the light green, one carrier each.
- **Round 72 lane RANGED** (`r72_ranged`): the ranged kings shoot, navigate and seek sight ([combat_stats.md](../docs/design/combat_stats.md) §4). `portable_test.lua` (the real king definitions, `do_states`' branch decisions cut out of `mobs/api.lua`, the real `grug_nav.lua` and `grug_obstacle.lua` on a fake engine) checks the definitions, that every ground `dogshoot` mob has a ranged phase, and each ranged king in the open, behind cover, against a ledge and far away, before and after. `run.sh OUT_DIR` (one boot through the queue) with `grug_probe_r72_ranged`: the Elf King against a standing dummy in the same four lanes, shots and their hits on the dummy, sight, movement and the navigation's searches logged; `evidence/probe.txt` holds the lane's two runs.
- **Round 70 lane GUILD** (`r70_guild`): the Stonewright ([miners_guild.md](../docs/design/miners_guild.md) §5.3). `portable_test.lua` (the recipes of plan §2.6, the blocks and machines, prices and the audit, the conversion with fake players, the window, the socket and the templates), `make_machines.py` (`--check`; lane ART's picked PNGs into the mods, its JSON records into `grug_guild/machines_data.lua`), `scene.lua` (the window, `SCENE=… tools/r55_game/capture.sh`). The hall shots are `tools/r58_halls/capture.sh`, whose probe checks the work bay in all six houses.
- **Round 70 capitals** (`r70_cap`): [CAPITAL-GUIDE.md](r70_cap/CAPITAL-GUIDE.md) is the five capital lanes' recipe. `portable_test.lua [REPO] [CAPITAL]` builds the six cores through the real compositions: the one source of the core's size, the bounds, every socket; for a finished capital (`DONE`) the closed ring, every socket reached on foot from the crossing, the castle's guards, the king's real body from his seat to the great door and over the dais, and every socket on its row of the study's schedule. `XVFB=… CAPITAL=… capture.sh OUT_DIR` (one boot through the queue) with `grug_probe_r70_cap`: the approach, hall and throne by day and at night, every patrol leg through the real route cache, the king's sockets and the engine's path to the door. `plan_seeds.sh OUT_DIR` and `plan_summary.py`: the real planner on 40 fleet seeds against the study. `lake_table.py`: the two lakes' core tables from the study's masks. `kezamba_mask.lua [REPO] [--verify]`: Kezamba's `LAGOON` rows from the real water, or the committed mask against it.
- **Round 72 lane BOSSRESET** (`r72_bossreset`): kings, Generals and bosses reset by the boss floor, the one-way window and the 15 s rule ([combat_stats.md](../docs/design/combat_stats.md) §4 "Kings and bosses"). `portable_test.lua` (the real `grug_nav.lua`, `grug_obstacle.lua`, `grug_core/combat.lua`, `aggro.lua`, `boss_floor.lua` and `packs.lua` on a fake engine) checks the floor's fill, the ledge and range resets of a melee and a ranged king, the leash line, the 15 s rule, a tank swap by Taunt, logout and death, a General and an Expedition boss in their rooms, and counts searches (`--before=FILE` runs the count on an older `aggro.lua`). `run.sh OUT_DIR` (one boot through the queue) with `grug_probe_r72_bossreset`: the floor of every King's and General's seat on real ground, its cells, steps and time and the floor test's cost; `evidence/probe.txt` holds the run.
- **Round 72 lane GUARDNAV** (`r72_guardnav`): guards, captains and the other mobs of "Out of reach, reset at once" ([combat_stats.md](../docs/design/combat_stats.md) §4). `portable_test.lua` (the real `grug_nav.lua`, `grug_obstacle.lua`, `grug_core/combat.lua`, `aggro.lua` and `boss_floor.lua` on a fake engine whose pathfinder lowers a hovering goal as the engine's does, a simple walker for the dogfight branch) checks a reachable target in the open and behind a wall, a guard and a captain against a target on a pillar, at a ladder's top and in a ladder's top node (the reset a second after the hit, healed, the evade untouchable, attackable at home, before and after), a found path ending out of reach, who is switched on, the patroller, and the Return Home loop of a guard that sees a player it cannot reach; prints the comparisons. `XVFB=… run.sh OUT_DIR` (through the queue, 2 slots): one real client and the disposable probe `grug_probe_r72_guardnav` on a floor over deep ocean, a level 40 guard and captain hit once a second from 17-19 nodes (open, pillar, ladder top, on a ladder), every search, give-up, reset and hit logged, and the cost of one search at 17, 20 and 24 nodes at padding 6, 12 and 16; `evidence/` holds the runs before and after. `PROBE=tools/r72_guardnav/grug_check_r72_guardnav tools/luanti_headless.sh 150` (one boot through the queue): which registered mobs carry the switch, the leader sub-types among them, and that the strict rule is installed.
- **Round 72 lane FIGHT** (`r72_fight`): combat starts at targeting ([combat_stats.md](../docs/design/combat_stats.md) "Combat state"). `portable_test.lua` (the `do_attack` wrapper of `grug_mobs/init.lua` and the real `grug_core/combat.lua` on a stub) checks a target taken without a hit or threat puts the player in combat (T), a King targeting from out of reach (K), leaving combat on drop, death and reset (L), Expedition packs (P) and that the seam adds no per-tick work (C).
- **Round 72 lane MOUNTS** (`r72_mounts`): no mount or boat in an enemy start town or capital ([mounts.md](../docs/design/mounts.md) §4.4). `portable_test.lua` (the real `grug_mounts` catalog, flight rule and controller on a small world of four towns, a village and two lakes): summons refused in enemy towns for land tiers and boats and allowed in own towns, outside the line and for a factionless character; a horse, a boat and an improved boat dismounted at the first town column with one feed line (the boat's rider in the water); rides through own towns and along the line untouched; one footprint query per column entered. `PROBE=tools/r72_mounts/grug_probe_r72_mounts tools/luanti_headless.sh 150` (one boot through the queue): the rule on the real world authority (every start town and capital, its faction against its zone's territory, the six start positions, the line east of each anchor, the cost of one question).
- **Round 72 lane BLADECRAFT** (`r72_bladecraft`): Bladecraft shows the weapon of its last real attack ([character_visuals.md](../docs/design/character_visuals.md) §4). `portable_test.lua` (the real `grug_abilities` with its kits and `input.lua`, the real display state cut from `grug_visuals/apply.lua`): a shot that flew shows the bow on both hotbar layouts (the held stack without the re-raise), a refused shot, an air click and the held fallback switch nothing, a swing at a foe shows the blade, damage and both clocks unchanged, no timeout, a relog shows the blade. The third-person hand and the back card: `r55_game` section S.
- **Round 72 lane PLACE** (`r72_place`): the placement rules in combat and around bodies ([combat_stats.md](../docs/design/combat_stats.md) "Placement in combat and around bodies"). `portable_test.lua` (the whole game's registrations and placement code through `r57_details/game_harness.lua`, the real `grug_core/placement.lua` over a transcription of builtin `item_place`/`item_place_node` and the falling node's `try_place`): placement out of and in combat (a block, a ladder, water from the bucket, a door, a bed, the notice board, the Claim Stone, torches, a plant, a right-click), a block into a mob's and a player's cells, partly covered cells and the placer's own, falling sand onto bodies, protection unchanged, and one area query per walkable placement or landing. `PROBE=tools/r72_place/grug_probe_r72_place tools/luanti_headless.sh 150` (one boot through the queue): the seam, the falling sand and the query's cost on the real engine.
- **Round 72.1 lane FINISH** (`r721_finish`): finishing and cancelling an Expedition and the Deserter's Mark ([expeditions.md](../docs/design/expeditions.md) §3-5). `portable_test.lua` (the real `grug_home` and `grug_expeditions` with the Registrar on one fake engine with a clock, preparation and template faked, `rewards_open` a switch per run) checks who may finish or cancel and when, the countdown banner (30 s since Round 74), entry at T-11 and its refusal at T-10 on the click and on arrival, the end sending everyone out, Cancel's confirmation at the Registrar and on the tab, the stones inside, the mark's rules, status, logout and login and expiry, a solo owner joining a foreign party, the lapse without a mark and a leader handing on. The Claim Stone form's actions are in `r25_interfaces`.
- **Round 73 lane GAME** (`r73_game`): the template's `ambush`, `critter` and `particles` lines and their game side ([expeditions.md](../docs/design/expeditions.md) §7, §8, "Traps"). `portable_test.lua` (with `writers_test.py`, the Python writers and refusals, run from it) checks the format and every refusal, the ambush in the real `traps.lua` (a walk, a sprint, a jump, a Blink, a Charge and a knockback across, any height in the passage, never a teleport, a dead player or a long move, once per run, pick 1 of 2), the real `encounters.lua` (an ambush room waits and springs once, critters outside the packs, no drop, the load checks), `packs.lua` (lava immunity at spawn and activation, a critter, no fight with it, the pull, a jump to a player in lava lands on the rim), a critter's death in `grug_mobs` settling nothing, `particles.lua` (one spawner per line and run player, within its amount, gone on leaving and at the end) and lava as a boundary at `lava_damage` 0 (`is_node_dangerous`, `grug_nav`, the boss floor over stairs and a basin). `XVFB=… run.sh OUT_DIR` (through the queue, 2 slots; `TIMEOUT`, default 290): one real client and the disposable probe `grug_probe_r73_game` on `test_vault`: the written lava fall, the particles, critters, the stairs for a player and a mob, a basin, the ambush (one run per way across); `dust.png`, `fall.png`, `ambush.png`.
- **Round 74 lane CAST** (`r74_cast`): a self or support skill pressed while the action clock is busy waits for it ([classes.md](../docs/design/classes.md) §2b). `portable_test.lua` (the real `input.lua` on a fake engine whose clocks follow the action clock, 0.09 s input passes; every case prints a `CASE` line, so a run on an older `input.lua` gives the before column): Ruination and Hold Ground pressed mid-swing at a mob (held, clicked once, carried across a switch), a sweep of click series over weapon intervals, click lengths and phases, Ice Nova, Blink and a Heal after a cast, and the wait's limits (cost and cooldown at once, the timeout, a switch, a row switch, death, a stun, a new refusal, a new press, a hostile-target skill).
- **Round 74 lane TRAIL** (`r74_trail`): the evade seam and the evader's trail ([combat_stats.md](../docs/design/combat_stats.md) §4 "The way home"). `portable_test.lua` (the real `grug_nav.lua`, `grug_obstacle.lua`, `patrol.lua` and `aggro.lua` on tools/r42_nv2's world model, a scripted chase): the seam with fixture guides, the recording (spacing, the first point, ground only, a detour, the loop cut, the cap and its corners, clearing), the walk back (a guard pulled round a long wall's end home over its trail where the straight walk needs the teleport, a ledge point skipped); prints the comparison. `run_probe.sh OUT_DIR [branch|base]` (one boot through the queue, 1 slot, no client): the disposable probe `grug_probe_r74_trail` builds an arena in the air (forceloaded), twelve Bandits each chase a decoy round a wall, a pen, a house, a ridge, a kite and a ledge, get the reset and evade; one `RESULT` line per cell (home, teleport, time); `base` stages the base commit's `aggro.lua` (GAME_PATCH); `evidence/` holds both runs (seed 42).
- **Round 74 lane MOUNT** (`r74_mount`): flight over the coastal belt in front of the own and contested land, and the ride restored at login ([mounts.md](../docs/design/mounts.md) §3, §4.1). `portable_test.lua` (the real `grug_mounts` catalog, state, flight rule, controller and `restore.lua` on a fake engine with a clock): the rule per water class and owning zone (the belt in front of the own home and contested land flyable, of the enemy home and a dragon island not, the open sea and channels never asked for a zone); the tier saved by a logout and a shutdown with the teardown dismount kept; the join's hold until the block is active, then the same flyer, ground mount or boat at the saved seat; a refused flyer set down on the ground below its emerged column, a block not active within 5 s, an enemy town, a boat off the water, a dead player, a tier not owned, a leave while held. `coast.lua REPO OLD_FLIGHT_LUA [SEED ...]` (not a fixture; through the queue): the belt's width along 64 rays from the centre per seed and the rule's cost per call, old against new. `XVFB=… run.sh OUT_DIR` (through the queue, 2 slots): one real client stopped and started again by the probe `grug_probe_r74_mount`: a flyer 40 nodes up restored at the rejoin without a fall, and set down when the rule refuses.
- **Round 74 lane NAV** (`r74_nav`): the walk grid of every Expedition template and the mobs' way over it ([format](../docs/technical/expedition-template-format.md), [combat_stats.md](../docs/design/combat_stats.md) "Expedition packs"). `expedition_templates/walkgrid.py`, called by `build.py`, derives and writes each template's grid section and holds what `build.py` refuses of it (`problems`: a grid off the re-derived height map, a one-way move or a step over one, a cut corner, an encounter, ambush or place off the grid, a room's markers in two walk components). `portable_test.lua` (about 6 s, one run, many cases): the grid of each written `.exp` against `proofs.lua`'s height map cell by cell (heights, moves, door cells, clearance, 2 x 2 blocks derived again) and against the real `grug_nav.lua`'s node model on a fake world; A* against its own breadth-first search for thousands of pairs and three body classes; every field of every home, exhaustively, and the evade guide from every cell; two slots; off the grid, the door, a wide body; the chase over grug_nav round walls; the reader's grid section; prints the timings. `plan.py OUT.lua` writes the engine run's cells (drags behind corners and across stairs, chase cells). `XVFB=… EXPEDITION=<id> [MODE=evade] [GAME=<checkout>] run.sh OUT_DIR` (through the queue, 2 slots): one real client and the disposable probe `grug_probe_r74_nav`: every pack mob dragged and sent home in waves, then each pack pulled round a corner; `GAME` an extracted 0.73.1 tree with `MODE=evade` is the baseline. `evidence/` holds the runs.
- **Round 74 lane HUD** (`r74_hud`): the action clock's cover and the waiting cast's marker on the hotbar ([classes.md](../docs/design/classes.md) "The cooldown overlay"). `portable_test.lua` (the real `cooldown_math.lua` and `cooldown_hud.lua` with a stand-in warrior and fake clocks): the clock steps and textures, the marker's fills, a swing covering the free casts at the next pass (never a swing skill, never a number), the steps, a cooldown's precedence, a cast interval's own cover, a cleared clock, the elements kept through a held fight and gone `LINGER` after the last block, the marker over the cover and alone; source checks of the seams in `init.lua` and `input.lua` (the accessor's behaviour is `r74_cast` section W); prints the HUD writes per second in a held melee fight, today and at 2 to 8 steps, per weapon interval. `XVFB=… capture.sh OUT_DIR` (one boot through the queue, 2 slots) with `grug_probe_r74_hud`: one client, desktop then web scaling (stopped and started by the probe), the cover at two steps beside a real cooldown and the waiting marker, the clock frozen through the overlay's seam.
- **Round 76 lane CLAN** (`r76_clan`): clans (`grug_clans`, [clans.md](../docs/design/clans.md)), the `/c` clan chat and the `/p` party chat ([parties.md](../docs/design/parties.md) "Party chat"). `portable_test.lua` (the real `grug_parties/init.lua` without its UI files and the real `grug_clans/init.lua` on a fake engine with a clock, `core.after`, mod storage, chat and the join, leave and shutdown hooks): forming, the 100 limit, every role permission for every pair of roles both ways, succession, dissolving by leave, kick and faction change, invitation expiry, rate limit, the 10-pending cap and the switch, an offline kick, `last_online`, persistence through a fresh module load and validation at load, the recipients, colours and log lines of `/c` and `/p`, the presence lines, and a party and a clan kept independent.
- **Round 76 lane SOCIAL** (`r76_social`): the Social tab in four cards and the clan card ([parties.md](../docs/design/parties.md) "The Social tab"). `portable_test.lua` (the real `grug_parties` init, ui and hud, the real `grug_clans` init and `social.lua`, the real `grug_pvp/page.lua`, the vendored sfinv api and `grug_core`'s ui, hud_layout and status_icons on a fake engine with a clock): the four cards' places and their elements inside them, the shared row style (tints, the selected row's frame, the invisible pick buttons), the clan card without a clan (hint, pending invitations), the buttons per role against the clan API, the online rows' Party and Clan buttons and the clan mark, the Online/Offline tabs and the pages (only the shown page sent, inactive arrows, the selection cleared), the member order and ages, 100 members, every button press and the refresh; it prints the tab's bytes for a 100 member clan. `clan_mark.py` draws `grug_clans_mark.png`. `XVFB=… capture.sh OUT_DIR` (one boot through the queue; a copy of `r67_social/capture.sh`) with `grug_probe_r76_social`: no party and no clan, leader, captain and member of a stand-in clan of 23, the clan invitations, the list scrolled, the offline tab's page 2.
- **Round 76.2** (`r762_home`): the `/home` chat command ([home_travel.md](../docs/design/home_travel.md)). `portable_test.lua` (the real `grug_home/home_command.lua` with a stubbed `grug_home`): registered without a privilege, `grug_home.return_home` called exactly when the button could be used and its answers passed on without a second line, character creation's stasis refused, one line each for no home, a trip under way and a dead player.
- **Round 78 lane ARMOR** (`r78_armor`): armor ratings with one decimal inside, shown ×10 ([combat_stats.md](../docs/design/combat_stats.md) §2). `portable_test.lua` (the real `grug_gear` and `grug_quality` init on the r45_il engine stub, `armor_k` and `armor_reduction` cut out of `combat.lua`): the display helper, every piece and shield against the formula (0.1, floor 1.0) and their baked lines, the per-stack path at item levels 1–70, the plan's expected sets and reductions, every line at each tier's base and cap and at 65/70 against 0.76.2 within rounding (`--table` prints that table), the enchant values and tooltip, the display sites through the helper and the Help formula in shown units. `format_armor.lua` cuts `grug_gear.format_armor` for fixtures that run a text site without the real `grug_gear`.
- **Round 78 lane EMOTE** (`r78_emote`): Wave, the seated Wave and Dance from the quickbar ([character_visuals.md](../docs/design/character_visuals.md#emotes-round-78)). `portable_test.lua` (the real player_api, grug_visuals' registration and `poses.lua`, `grug_core/ui.lua` and `grug_quickbar` on a fake engine with a clock and `core.after`): the clip registration, one play and its end, every interrupt (moving, jumping, LMB/RMB, a cast's pose, a mount; never a flinch), the seated Wave on a mount and `sit` after it, no Dance mounted, the rate limit and repeats, the quickbar's buttons with Dance greyed while riding. `XVFB=… capture.sh OUT_DIR` (one boot through the queue; a copy of `r67_social/capture.sh`) with `grug_probe_r78_emote`: the window on foot and riding, third-person front frames of the seated Wave, the Wave and the Dance.
