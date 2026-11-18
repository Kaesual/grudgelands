# Round 82 — World generation speed

Planned with the user on 2026-11-17. Source: lanes 5 and 6 of the read-only audit
[docs/audit-2026-11/](../audit-2026-11/README.md#5-world-generation-speed-medium-mind-the-upgrade-class);
its `findings/<id>.md` files are the authority for every finding id this plan cites. Routing
(user, 2026-11-17): the coordinator runs on Opus 5.5, Opus implements and reviews; every lane
gets an independent review. Version **0.82.0**, expected **compatible** with the server admins'
note for worlds in full preparation mode (§3.2).

## How to add to this document

- A new ruling goes to §2 with its date. A lane goal changes in §4, a row in §1.
- A **ruling** is the user's, with its date. A finding is a proposal until a ruling or a lane's
  re-check confirms it; a coordinator default is marked as such.
- Name functions rather than line numbers.

## Why

The audit found about five full passes per chunk over the emerged volume that carry no
information, per-column samplers that walk every river and road segment, a settlement ledger
rebuilt on every chunk transaction, and capital templates parsed up to ten times per server
process. None of it is measured. This round measures world generation once, removes that work,
with **byte-identical output** as the proof (ruling 2), and merges the six copied capital plot engines into one (lane 6, ruling 4).

## 1. Lanes and order

Start state: main at the commit that adds this plan (0.81.0). Integration branch `round82` in
`.claude/worktrees/round82`; every lane branches from it.

| Lane | Goal (§4) | Wave | Merge order | Review |
|---|---|---|---|---|
| BASE | The measuring and comparing tools, the baseline and the reference on the round's base | 0 | 1 | independent |
| BOOT | Template, palette, dressing and buffer work at boot (W1-01..W1-05) | 0 | 2 | independent |
| CAPITAL | One capital plot engine instead of six copies (W2-01..W2-11) | 0 | 3 | independent |
| R6 | The per-chunk writer and planner (M3-02..M3-07), its dead code | 1 | 4 | independent |
| R7 | The per-chunk settlement transaction and P9G scan (M4-01, M4-02), the blueprint rebuild at boot (M4-03), their dead code | 1 | 5 | independent |
| COLUMN | The per-column samplers (M1-01, M2-01, M2-02), their dead code | 1 | 6 | independent |
| LOADER | One shared wp13 loader context per build (follow-up lane, ruling 7) | after R7 | 7 | independent |
| D | Release 0.82.0 and the round's end records | after every merge | — | coordinator |

Wave 0 starts at once: BOOT and CAPITAL prove identity with pure-Lua layout dumps they make
themselves and do not wait for BASE. Wave 1 starts when BASE is merged, because its lanes
compare against BASE's reference. Inside a wave the files are disjoint apart from the named
exceptions (§3.3).

## 2. User rulings

From the conversation of 2026-11-17:

1. **Full preparation mode.** No world on production uses `grug_prepare_full_world`. Files in
   the preparation digest may change; 0.82.0 carries the server admins' note in its CHANGELOG
   section (`check_upgrade.py`'s full-preparation gate accepts it).
2. **Byte-identical is the proof, not a goal for the world.** Small deviations would not matter
   to players, but byte identity makes every lane's check a cheap yes or no: a different hash is
   a bug. A lane that finds a clearly faster variant which changes the output slightly does not
   build it in; it reports the speed gain and what changes (how many nodes, where), and the user
   decides. An accepted change lands as its own commit, and the reference is captured again after
   it. **M3-01 is out** (2026-11-17, the coordinator's recommendation after the user's question):
   it is hygiene with no player-visible gain, and the fleet comparison is deterministic without
   it; it waits for the next round with a map reset (BACKLOG).
3. **Baseline measurement first.** World generation time is measured once on main before any
   change and once at the end on the same region; the numbers are reported, not targets
   ([round workflow §6](../process/round-workflow.md#6-writing-briefs)).
4. **The capital plot engine (W2-01..W2-11) is in.** Every capital in the production world is
   generated already, so the refactor does not change it; the layouts and the socket data the
   game reads at run time (waystones, NPCs, stations) stay byte-identical (§4 CAPITAL).
5. **Runs kept small.** Pure-LuaJIT comparisons per lane, engine runs only for the measurement
   and the smoke boots, one full fixture run and one full seed fleet at the end (§5).
6. **Parallel lanes** wherever the files allow.

From the compaction checkpoints of 2026-11-18:

7. **LOADER is in** (checkpoint 1): a follow-up lane after R7's merge shares one wp13 loader
   context per build through the digested `r7_capital_blueprint.kit` (BOOT's W1-01 and W1-04,
   CAPITAL's W2-07 rest), byte-identical like every lane.
8. **M4-07 goes to BACKLOG** (checkpoint 2): the protection miss at x or z in (−0.5, 0)
   touches only float positions at the 36 functional anchor columns on x = 0 or z = 0;
   digging and placing use integer node positions, and the fix changes protection there.
9. **The per-environment loader context goes to BACKLOG** (checkpoint 2): about 0.2 s CPU per
   environment against two more digested files and five POI blueprints.

## 3. Shared conventions

### 3.1 Coordinator defaults (the user may overrule)

- **Byte-identical is the gate** (ruling 2). Every change keeps the written nodes, param2,
  metadata, the layouts, the roster, the protection shapes and the socket data identical. A
  proposal that would change any of it is reported, not built. The audit's verifiers already
  corrected three such proposals; a lane re-checks the maths of each finding before building.
- **Drift is kept, not fixed.** Where the copies have drifted (W2-02 Kezamba's unread garden
  flag, W2-03 the prop guards, W2-05 the plot airspace, W2-06 the socket fields), the merged
  engine reproduces each capital's current behaviour as a named per-capital option. Fixing a
  drift would change new worlds' capitals; the lane lists each one for the user, and that is a
  later decision.
- **Low findings.** A lane fixes the Lows this plan lists for it; other Lows in its own files only
  when the fix is a few lines and the finding is CONFIRMED or CORRECTED. Helpers copied across
  several lanes' files (M2-04, M3-16, M4-15, M5-09) are not merged in this round.
- **Measurements.** The cost change of a finding is shown with call counts or a pure-LuaJIT micro
  measurement inside the lane's fixture (before on the base, after on the branch, one run each).
  The engine measurement is BASE's and the coordinator's alone (§5).
- **API stability across lanes.** BOOT keeps the signatures of `templates.capital`,
  `templates.town`, `templates.part`, the palette handle, `dressing`, `city_green` and the
  `parts` buffer; CAPITAL uses them unchanged. COLUMN keeps the signatures of the height, zone,
  water and road sampler entry points; R6 and R7 call them unchanged.

### 3.2 Release

Compatible for every world not in full preparation mode. A world made with
`grug_prepare_full_world` stops at its next start because digested files change (ruling 1); the
CHANGELOG section of 0.82.0 says so in one admin line naming `grug_prepare_full_world`. D sets
0.82.0 in `game.conf` and `tools/web_data/upgrade.json`. The cached capital layouts rebuild
once at the first start (identical content).

### 3.3 Shared files

| File or folder | Owner |
|---|---|
| New `tools/r82_gen/` (digest mode, region measurement, reference files), `tools/seed_fleet/` (opt-in digest output only) | BASE |
| `wp13/templates.lua`, `palette.lua`, `dressing.lua`, `city_green.lua`, `parts.lua`, `layout.lua`, `plot_approach.lua`, `city_edge.lua`, `troll_palette.lua`, `dwarf_dressing.lua`, `precinct_ring.lua` | BOOT |
| `wp13/*_plot.lua`, the six capital core files (`highcourt.lua`, `dur_brannoc.lua`, `nhal_veyr.lua`, `gor_drazhak.lua`, `lethariel.lua`, `kezamba.lua`), `*_districts.lua`, `kezamba_lots.lua`, a new shared plot engine in `wp13/` | CAPITAL |
| `wp40/r6_settlement.lua`, `r6_content.lua`, `r6_planner.lua`, `r6_templates.lua`, `r6.lua`, `r5.lua`, `planner.lua`, `r6_hash.lua`; the surface-cave stubs in `zones.lua` and `height.lua` (M1-08, the named lines only) | R6 |
| `wp40/r7_*.lua` (including `r7_content.lua`, so M3-02's counter there too), `world_assembly.lua`, `city_decor*.lua`, `capital_planner.lua`, `r14_poi_blueprint.lua`, `r58_camps.lua`, `r20_*.lua`, `r31_pvp_poi_blueprint.lua`, `world_content.lua`, `mapgen_manifest.lua`, `schemas.lua`, `wp43_handoff.lua` | R7 |
| `wp40/height.lua`, `zones.lua`, `index128.lua`, `deterministic.lua`, `simple_map.lua`, `zone_field.lua`, `terrain_field.lua`, `source/simple_map.lua`, `water_layout.lua`, `road_layout.lua`, `habitat_registry.lua`, `vegetation_density.lua`, `map_adapter.lua`, `counting_allocator.lua`; `grug_core/zone_authority.lua` (M1-07 only) | COLUMN |
| `docs/technical/modules/mapgen.md`, `docs/design/world_zones.md`, `docs/design/settlements.md` | each lane its own sections; the coordinator resolves at merge |
| `CHANGELOG.md`, `game.conf`, `tools/web_data/upgrade.json`, `docs/STATUS.md`, `README.md`, `BACKLOG.md`, this plan's Completion | D |

`tools/README.md` is append-only for every lane. All mapgen paths are under
`mods/MAPGEN/grug_mapgen/`.

## 4. Lane goals

Every lane: the verified text in `docs/audit-2026-11/findings/<package>.md` is the starting point;
re-check each finding at the base commit before building on it (round workflow §2 step 4).

### BASE

1. **Tools.** An opt-in digest mode for the seed fleet: for every planned and written chunk a hash
   of the written content (nodes, param2, metadata), plus the roster and the generated layouts,
   so two commits compare seed by seed in pure LuaJIT. A region measurement for the engine: a
   fixed small region (coast, mountain, a river, a road, a village or POI, one start), generated
   headless, chunk generation time per chunk and in total, and a hash of the generated region.
2. **Baseline and reference** on the round branch's base, before any change: the engine
   measurement (one run, at most about 5 minutes) with the region hash, and the fleet digests of
   the reference seed set (§5), committed under `tools/r82_gen/`. Every later lane and the round
   end compare against them.

The report states how stable the engine region hash is: a second capture of the same commit must
agree (that is the one extra run). If it does not, BASE reports it and the engine hash is left out
of the round-end comparison; the fleet digests stay the gate.

### BOOT

W1-01 (each capital's roster and templates parsed once per Lua state), W1-02 (memoised template
cell resolution, no linear role scan), W1-03 (the tree fitters stop scanning candidates they can
no longer accept), W1-04 (tree pools built once), W1-05 (numeric buffer keys). Lows: W1-06,
W1-07 and M5-04 (`troll_palette.lua` leaves the game mod if only tools load it; the tools then
load it from its new place), W1-08, W1-09, W1-10, W1-11. Identity: a pure-Lua dump of every
town and capital layout with its sockets, made on the base and on the branch, byte-identical;
`tools/building_templates/check.py` once on the final branch.

### CAPITAL

W2-01 and W2-04: one plot engine and one composition skeleton for the six capitals; each capital
keeps a short configuration file. W2-02, W2-03, W2-05, W2-06 as named per-capital options (§3.1),
listed in the report with what fixing each would change. W2-07 goes with BOOT's W1-01 (the plot
modules use the parsed roster). Lows: W2-08, W2-09, W2-10, W2-11. Identity as BOOT's, with the
same dump; the lane makes its own dump on the base and does not wait for BOOT.
`tools/building_templates/check.py` once on the final branch. CAPITAL merges after BOOT and merges
the round branch in before its review.

### R6

M3-02 (the commit scan classifies only what production reads), M3-03 (one surface selector per
chunk), M3-04 (the empty passes over the emerged volume go), M3-05 (the strata pass skips columns
it cannot touch, one hash per depth where the maths allows), M3-06 (the planner computes only the
answers it returns), M3-07 (cheap rejections before building decoration cells). Dead code: M3-08,
M3-11 with M1-08 (the surface-cave writer, its planner branches and the always-nil stubs), M3-13,
M3-14. Lows: M3-10, M3-12, M3-15. M3-09 (the writer's own copy of the planner's surface rule)
only if it stays byte-identical and small; otherwise reported as a carry-over. Identity: the fleet
digests against BASE's reference.

### R7

M4-01 (the race palette, closures and ledger built once per settlement, not per chunk
transaction), M4-02 (one P9G scan pass per column), M4-03 (no blueprint rebuild when the layout
cache hit). Dead code: M4-13, M4-14, M4-17, M5-05, M5-06, M5-11. Lows: M4-04, M4-05, M4-06,
M4-07, M4-08, M4-09, M4-10 (byte-order sort; check it changes nothing on the reference seeds),
M4-11, M4-12, M4-16, M5-08, M5-10. Identity: the fleet digests against BASE's reference; the
roster hash unchanged.

### COLUMN

M1-01 (plain bucket indexing on the per-column path), M2-01 (the water sampler skips the segment
walk and blend where the result is discarded), M2-02 (the road sampler's per-column segment walk
through a spatial index). Dead code: M1-04, M1-05, M1-06, M1-07 (the unused `grug_core` zone
adapters), M1-14, M2-06. Docs: M1-02, M1-03, M1-11, M1-12. Lows: M1-09, M1-10, M1-13, M2-03,
M2-05, M2-07, M2-08, M2-09. Identity: the fleet digests against BASE's reference, plus a pure-Lua
sample of the column samplers on many columns per seed (before on the base, after on the branch).

### D

Release 0.82.0 and the round's three end records ([round workflow §4](../process/round-workflow.md#4-lane-d-and-the-post-merge-status-step)):
the CHANGELOG entry (with the admin line of ruling 1 and the measured before and after times),
this plan's Completion and Carry-overs, the STATUS row. BACKLOG in place: the world generation
speed item and the capital plot engine item are deleted; what remains (M3-01 for the next round
with a map reset, M3-09 if left, M5-07, the cross-lane helper copies, the capital drifts of §3.1)
becomes one-line items.

## 5. Rules

[Round workflow](../process/round-workflow.md), [AGENTS.md](../../AGENTS.md), Lua 5.1.

**Fixtures** (Round 81 ruling 15, standing): a lane runs only its own fixture and the fixtures that
really test what it changes, as few times as possible; no lane and no reviewer runs the full set;
the coordinator runs it once, at the very end.

**Runs** (ruling 5). The engine measuring runs are BASE's (baseline, plus one repeat for the
stability check) and the coordinator's at the end; no lane and no reviewer runs another one,
except one smoke boot per code lane on its final branch. Engine runs stay within the
engine-run budget ([AGENTS.md](../../AGENTS.md)): bounded by region, never the whole
world, stopped by a normal shutdown. Each lane compares its fleet digests once on its final
branch over the reference seed set BASE fixes (about 20 seeds, about a minute at eight in
parallel). The full seed fleet runs once, at the round end, by the coordinator, with the digest
comparison. At most eight Lua processes through the shared queue; headless runs only through
`tools/luanti_headless.sh` with `LC_ALL=C`. No sync and no push by any lane.

## 6. Verification and human tests

**Lanes:** the changed-file Lua check, their fixtures, the digest or layout comparison, one smoke
boot; BOOT and CAPITAL also `tools/building_templates/check.py`.

**Round end (coordinator):** the full fixture run; the full seed fleet with the digest comparison
against BASE's reference (every seed identical); the engine measurement on the same region with
the region hash (equal to the reference) and the time against the baseline; `check_upgrade.py`
(the admin line present), `check_fresh_server.py`; one smoke boot of the round branch.

**Human-test proposal** (an offer): after the sync, start a new local world and travel a few
minutes in one direction; the world looks as before, and new ground appears at least as fast.

## 7. Orchestration notes

- **Start:** on the user's go. Wave 0: BASE, BOOT, CAPITAL. Wave 1 (R6, R7, COLUMN) after BASE's
  merge.
- **Compaction checkpoints:** (1) BASE merged and wave 1 launched; (2) every lane merged, before
  D; (3) D merged and the round-end gates run, before the squash.
- **Handover:** `~/projects/grudgelands-orchestration/r82/HANDOVER.md`.

## Completion (2026-11-18)

All six planned code lanes and one unplanned follow-up lane (LOADER, ruling 7) are merged
into `round82`, wave by wave (BOOT, BASE, CAPITAL; then R6, R7, COLUMN; then LOADER); this
lane D runs on it. Nothing is on main and nothing is pushed:
`round82` lands on main as one squash commit (0.82.0), tagged `round-82`, after the round-end
gates. Every lane had an independent review; BASE (two Lows) and R7 (one High in tools) had a
fix round whose tool-only delta the coordinator checked. The lanes' reports and reviews are in
the coordinator's orchestration folder (`r82/reports/`); this record names lanes and finding
ids, not lane commits (Round 81 ruling 14).

Round-end gates (coordinator, §6), all passed on the merged round branch: the full seed fleet
(304 of 304 seeds build); the digest comparison (20 of 20 seeds identical with BASE's
reference); the engine measurement above (region hashes equal to the baseline);
`check_upgrade.py` (the 16 digested files declared) and `check_fresh_server.py`; the full
fixture run (375 of 375, after one fixture fix: `r49_jit` pinned the runtime classifier's
param2 range check that R7 removed on purpose (M4-06; the engine's param2 is a byte), so it now
plants the bad param2 under the validating adapter, which still refuses it); one smoke boot.

**0.82.0 is compatible** for every world not in full preparation mode: every lane report says
compatible and every review agrees. No saved key is read or written anew and no step is
declared. Two things change for a host:

- the world-folder layout cache `grug_world_layouts.txt` goes from format 2 to format 3 (R7,
  M4-03: a new `prepared` section holds the settlements' prepared handover, about 1 MB more,
  1,485,554 bytes on seed 12345); its key covers every `.lua`, `.tpl`, `.layout` and `.roster`
  file of the mapgen mod, so the first start rebuilds it once with the same content, and an
  old file reads as "format differs";
- 16 files of the full-preparation digest (`wp40/preparation_identity.lua`) changed: `r5.lua`,
  `r6.lua`, `zones.lua`, `height.lua` (R6); `r7_runtime.lua`, `capital_planner.lua`,
  `schemas.lua` (R7); `source/simple_map.lua`, `zone_field.lua`, `deterministic.lua`,
  `index128.lua`, `simple_map.lua`, `height.lua`, `terrain_field.lua`, `water_layout.lua`,
  `road_layout.lua`, `zones.lua` (COLUMN; `height.lua` and `zones.lua` changed in both lanes);
  `r7_capital_blueprint.lua` (LOADER). A world made
  with `grug_prepare_full_world` stops at its next start; no production world uses that mode
  (ruling 1), and the CHANGELOG's admin line names the setting.

The new caches (R6's surface selector and commit-scan memos, COLUMN's road index, LOADER's
shared loader context) live in memory only.

### Lanes

| Lane | Wave | What | Review |
|---|---|---|---|
| BASE | 0 | `tools/r82_gen/`: the opt-in fleet digest mode (layouts, roster, sockets, blueprint identities, per chunk nodes with param2, light with its call log, the waypost metadata; 14 chunks per seed with the dense set), the 20-seed reference, the engine region measurement (seed 12345, six patches, 258 chunks) | MERGE with two Lows (the light log without the content state, no chunk on the fill floor); fix round, checked by the coordinator |
| BOOT | 0 | W1-02, W1-03, W1-05, W1-06, W1-07 with M5-04 (`troll_palette.lua` to `tools/building_templates/`), W1-08, W1-11; half of W1-04 | MERGE |
| CAPITAL | 0 | W2-01 and W2-04 for the six capitals (`wp13/capital_plot.lua`, `composition.lua`, `capital_districts.lua`), W2-02/03/05/06 as named per-capital options, W2-07 (each districts module loads its plot module once), W2-08..W2-11, X2-05 | MERGE |
| R6 | 1 | M3-02, M3-03, M3-04 (a), M3-05, M3-06, M3-07, M3-08, M3-10, M3-11 with M1-08, M3-12..M3-15 | MERGE |
| R7 | 1 | M4-01, M4-02, M4-03 (the prepared handover in the layout cache), M4-04 (18 wrapper files into `r14_poi_blueprint.lua`), M4-05, M4-06, M4-08, M4-09, M4-10, M4-12 (3), M4-13, part of M4-16 and M4-17, M5-05, M5-06, M5-08, M5-10, M5-11 | MERGE AFTER FIXES (three tools still selected the Round 14 rows by the old file names; one README word); fix round, checked by the coordinator, `r36_w` PASS |
| COLUMN | 1 | M1-01, M2-01 (an exact variant), M2-02 (a column index), M1-04..M1-07, M1-09 (a), M1-10..M1-14, M2-03 (the memo), M2-06, M2-07, M2-09 | MERGE (one Low docs clause, fixed by D) |
| LOADER | after R7 | One shared wp13 loader context per build (BOOT's W1-01/W1-04 blocker, CAPITAL's W2-07 rest): `kit(key, context)` shares parsed templates and rosters, tree pools and the tree generator between a capital's core and districts | MERGE |
| D | after | Release 0.82.0, CHANGELOG, this Completion, the STATUS row, BACKLOG, the dead cave-writer switch, the `relief_profiles` clause, the fleet timing note | coordinator |

### Identity proof

Byte identity was the gate of every lane (ruling 2), and every comparison is equal:

- **The fleet digests** (BASE's reference on the round's base, 20 seeds, 14 chunks each, 16 for
  the production seed): 20 of 20 identical on R6's, R7's, COLUMN's and LOADER's final
  branches and on the merged round branch before LOADER, with no manifest note.
- **The layouts:** BOOT's dump of every town and capital layout with its sockets, every
  palette answer and each capital's city green prints the same 1582 lines on the base, on
  BOOT's branch and on LOADER's (sha256 `a6e34410…afb3`); CAPITAL's dump of 316 blueprints (6
  cores, 310 plots, every field) is 316 of 316 identical to its base capture after every step
  and after LOADER.
- **The samplers:** COLUMN's comparison of 36 entry points on about 153,000 columns per seed
  (6 seeds) is identical, and its fixture checks 1.03 million road answers and 449,000 river
  columns against the old walk.
- **The engine:** the region hash at the round's end equals the baseline's (nodes and metadata
  `abb247aa…`, light `cf2b951e…`, and all 258 per-chunk hashes); BASE's repeat on the base had
  shown the hash stable.

### What shipped, with numbers

Every number is one run on the base and one on the branch, a comparison and not a target
(ruling 3). The engine numbers are one run each on a shared workstation; BASE's repeat of the
baseline measured 76 s ready and 43.0 s chunk sum, so a few seconds are noise.

- **Engine region** (seed 12345, 258 fresh chunks: coast, mountain, river, road, village, start
  edge), baseline on the base → the merged round branch: ready world from launch 78 → 64 s;
  preparation after the first server step 23.9 → 20.1 s (its CPU at ready 76.2 → 63.5 s);
  chunk generation summed over the 258 chunks 39.0 → 35.4 s wall (38.8 → 35.7 s CPU), span
  50.3 → 48.8 s.
- **BOOT** (Highcourt build): role lookups 76,168 → 28,934, buffer string keys built 1,235,978
  → 0, CPU 0.96 → 0.91 s; two city greens 48 → 24 tree generations.
- **CAPITAL:** the six plot modules went from 2,895 lines to a 557-line engine and 192 lines of
  configuration (net −3,210 lines under `mods/`); W2-07 cut the capitals' template parses
  1018 → 490 and tree generations 1272 → 720 (construction CPU 3.96 → 3.28 s).
- **R6** (seed 12345, its 14 digest chunks): plan 1.62 → 1.42 s, write 2.62 → 2.17 s, surface
  rows computed 290,094 → 82,700, content classifications 1,192,164 → 202,966; the fleet's
  plan and write over 282 chunks 114.2 → 99.3 s (eight in parallel, noisy). About 900 lines
  of evidence, capture and replay paths and the surface-cave writer went.
- **R7** (seed 12345, 7 surface chunks): column queries in the writes 1,621,677 → 591,277,
  write CPU 2.46 → 1.98 s; main's construction on a cache hit in the LuaJIT harness 10.75 →
  5.68 s (a smoke boot's hit logs "runtime construction 2.6 s" against 26.8 s at the
  world's first start: a hit against a miss on the same branch, not a before/after, since
  0.81.0 already restarted from the cache); the handover of 420 blueprints encodes in 0.016 s and decodes in
  0.014 s.
- **COLUMN** (three seeds): the road sampler's `column` 1.30/1.60/1.48 → 0.93/0.93/1.05 µs,
  the water sampler in river bands 1.42/1.21/1.14 → 0.96/0.97/0.91 µs, the vegetation
  `factors` 0.23 → 0.05 µs per column; the road index costs about 4 MiB per Lua state
  (5.3 → 9.4 MiB on seed 12345) and 0.025 → 0.074 s to build.
- **LOADER** (one build of every profile, per environment): template parses 583 → 338, tree
  generations 944 → 440, construction CPU 4.48 → 3.71 s, allocation 2.70 → 2.38 GB; memory kept
  after building every capital kit and start town once about 102–107 → 58–64 MB.
- Six new fixtures (`r82_boot`, `r82_capital`, `r82_r6`, `r82_r7`, `r82_column`,
  `r82_loader`).

### The user's decisions during the round

Rulings 7–9 (§2), all 2026-11-18 at the compaction checkpoints: LOADER as a follow-up lane
(from R7's account of what it takes), M4-07 and the per-environment loader context to BACKLOG
(LOADER's review also recommended the latter not now).

The coordinator accepted BASE's compare time of about 2.5 minutes (the plan said about one),
R7's edit of `layout_cache.lua` (no owner; the verified M4-03 needs it) and CAPITAL's one
comment line in BOOT's `wp13/parts.lua`.

### Deviations

- **BOOT:** W1-01 could not be built as planned: every `dofile` of `templates.lua` or
  `dressing.lua` makes a fresh loader, so a memo inside one instance helps no caller. CAPITAL's
  W2-07 and the LOADER lane took it instead. W1-04 is half done (the city green keeps its pool
  per capital, about 7.5 MB in emerge); W1-09 is left; W1-10 was already fixed in Round 81.
- **CAPITAL:** W2-04 covers the six capitals; the start towns stay on their own skeleton. The
  natural-ground prop of Highcourt, Dur Brannoc and Lethariel was never called, so W2-03 leaves
  one shared `paved_prop`. Drifts kept as options: `garden_ignored` (W2-02), `clear_to_top`
  (W2-05), the core's `activity` policy and `extra_group_order` (W2-06).
- **R6:** M3-04 (b) is left (about 1 ms a chunk, needs COLUMN's `map_adapter.lua`); M3-08 keeps
  `r6_planner.new` and `r5.new` (tools use them); M3-11 keeps the always-nil
  `surface_cave_run_at` and `run_at` (other lanes' readers and about 11 fixtures); M3-09 is a
  carry-over.
- **R7:** M4-07 not built (above); M4-14 partly refuted (`first_tier` is read) and the rest
  needs R6's validator; M4-16 and M4-17 partly (the remaining sites and the catalogue rows are
  other owners' or generated); M4-11 and most of M4-12 were already fixed.
- **COLUMN:** M2-01's planned steps gave nothing measurable or changed an unread return, so an
  exact variant was built (squared distances, a root only near the blend range). M2-02 keeps
  the `extra` return (§3.1 signature), M2-03 builds only the memo, M1-13's start-gradient tail
  rounds differently and stays, and M1-09 (b), M2-05 and M2-08 are left (other owners' files).
  M1-02 and M1-03 were already fixed in Round 81.
- **LOADER** was not planned. It shares one context per build, not per environment.
- **BASE:** the dense chunk set and the fill-floor chunk (fix round) make 14 digested chunks a
  seed; the compare takes about 2.5 minutes.
- The coordinator wrapped `compare.sh` in the shared queue once, which deadlocked the queue for
  half an hour (the script queues itself); it now runs unwrapped.

### Human-test proposal

An offer; nothing waits on it.

1. After the sync, start a new local world and travel a few minutes in one direction: the world
   looks as before, and new ground appears at least as fast.
2. Restart that world's server: it starts without an error and the world looks the same (the
   settlements now come from the layout cache's new section).

## Carry-overs

Each line names where it came from; the ones that are still wanted work have a BACKLOG line.

- **M3-01** (the surface-skin opening reads the VoxelManip shell): the next round with a map
  reset (ruling 2; BACKLOG, World and mapgen).
- **The capital drifts** kept as options wait for the user: aligning W2-05 to `top` changes 13
  plots, to `peak + 2` 4 plots (each a map reset); planting W2-02's four Kezamba gardens is a
  map reset, dropping the flags is not; W2-06 everywhere changes no blueprint (CAPITAL; BACKLOG,
  Open questions).
- **M4-07**, the −0 protection miss (R7; ruling 8; BACKLOG, World and mapgen).
- **The per-environment loader context:** 338 → 283 parses and 440 → about 200 tree
  generations, about 0.2 s CPU per environment; needs `world_assembly.lua`, `r7_runtime.lua`,
  the start wrappers and five POI blueprints (LOADER; ruling 9; BACKLOG, Performance).
- **Small speed leftovers:** M3-04 (b), M1-09 (b), M2-01's regional lists (−8 %, changes an
  unread return), M2-02's `extra` as plain values (changes the sampler's return), M2-03's
  zone-scale cache, W1-09, M5-07 (R6, COLUMN, BOOT; BACKLOG, Performance).
- **Mapgen duplicates:** M3-09 (needs a load path into `r6_settlement.lua`), M2-05, M2-08 and
  the helper copies of M2-04, M3-16, M4-15, M5-09 (§3.1) (R6, COLUMN; BACKLOG, Code hygiene).
- **The start towns on `composition.lua`** (W2-04's rest, with the towns' W2-03 prop guards)
  and the lost Kezamba building-row count guard in `capital_plot.lua` (CAPITAL and its review;
  BACKLOG, Code hygiene).
- **Mapgen dead code left:** the `surface_cave_run_at` and `run_at` stubs (readers in
  `vegetation_density.lua`, `swamp_pools.lua`, `r7_runtime.lua` and fixtures); R7's
  `replay_fixture` branches (`r7_settlement.lua`, `r7_p9g.lua`, `r7_anchor_activation.lua`) and
  `r6.lua`'s slot-4 comment; M4-14; M4-16's
  rest; M4-17's empty catalogue rows; the `grug_nodes/init.lua:311` comment naming
  `grug_core.territory_at` (R6, R7, COLUMN reviews; BACKLOG, Code hygiene).
- **Tools:** three tool hooks drop the loader context (`freeze_build.lua`,
  `r70_design/export.lua`, `r36_w/portable_test.lua`; sharing only); `tools/r36_w/baseline.tsv`
  is stale for the six capital cores since before this round; `tools/mgprof/stages.patch` and
  `tools/wp40/profile/instrument-settlement-stages.patch` are stale (LOADER review, R7, R6;
  BACKLOG, Code hygiene).
- Noted, no BACKLOG line:
  - the road sampler's cell key is collision-free only while |x| < 16384 (world ±4190);
    `index128.footprint_candidates` answers NaN or floats leniently (COLUMN review);
  - a zero-cell part would pass `box = nil` to the Kezamba and Lethariel checks (theoretical);
    the city green's pool stays in memory for the process (about 7.5 MB in emerge) (CAPITAL
    review, BOOT);
  - the strata pass reads `terrain_y` before the land test; `scan_pairs` grows with the
    content-id pairs met (R6 review);
  - on a cache hit the decoded handover tables are shared between the runtime and the payload;
    the `city_decor` numeric key merges −0 and 0 (R7 review);
  - the fleet digest does not cover the protection shapes or `zone_authority` (COLUMN proved
    M1-07 on its own), and the engine region has no metadata (BASE review).
