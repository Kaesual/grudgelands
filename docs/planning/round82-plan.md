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
