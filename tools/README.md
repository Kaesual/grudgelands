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
  `p4` crafting index with the shipped recipe corpus, crosshair, carriers,
  flight sweep, farming; `l` island landings, `engine.sh`; `c` start-NPC
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
  is a case in `pt_fixes/lane_a`'s probe, the quiver total in `r28_a6_ui`.
