# Review 2026-11: plan for the code and documentation audit

A read-only audit of the code that runs on the game server, requested by the
user on 2026-11-17 to use the remaining weekly model quota. It changes no
code; its findings are proposals until the user rules
([round workflow §2](../process/round-workflow.md#2-a-round-step-by-step),
step 1). Results: [docs/audit-2026-11/](../audit-2026-11/README.md).

## 1. Frame (the user's rulings, 2026-11-17)

1. **Topics:** performance without loss of function; duplicated code;
   simplification and dead code; documentation that no longer matches the
   implementation; bugs and unpleasant edge cases. Added by the coordinator
   and accepted: persistence and upgrade safety, multiplayer robustness and
   exploits, scaling to 100 players, mapgen determinism, callback lifetimes,
   module boundaries, small consistency checks (settings, translations,
   vendored patches).
2. **Scope:** only the code the game server runs (`mods/`, `menu/`,
   `game.conf`, `minetest.conf`, `settingtypes.txt`; what
   `tools/sync_to_luanti.sh` copies). `tools/` gets an inventory only (alive
   or dead, duplicates), no content review.
3. **No performance runs.** The audit machine is small (4 slow cores,
   16 GB). No LuaJIT, engine, fixture or benchmark run at all; performance
   findings are static, marked "unmeasured" and carry the measurement to run
   later on a larger machine.
4. **Routing:** Opus for the broad passes; Fable for the hard cores
   (grug_core with combat and migrations, the persistence and upgrade pass,
   the two settlement and capital planner packages), for the coordinator's
   re-check of Critical and High findings and for the synthesis. The Fable
   lanes are marked in §3; the user approved this split.
5. **Result:** English Markdown under `docs/audit-2026-11/`, committed on the
   local branch `audit-2026-11` (worktree `.claude/worktrees/audit-2026-11`).
   No push: origin is read-only from this machine, and only the user pushes.
   The user copies the folder to another machine.
6. **Autonomous run.** The user is away; the coordinator asks nothing and
   decides open points by these rulings and the project rules.
7. **Deadline: 06:45 CET on 2026-11-17.** By then the audit is finished or
   interrupted. Start of planning: 01:53.

## 2. Schedule and timers

| Time (CET) | Step |
|---|---|
| 01:53–02:25 | Plan, package cut, briefs, model-override test (Opus override confirmed) |
| 02:25–about 05:00 | Finders, each followed by its verifier, about 12 agents at once |
| as packages finish | Coordinator re-checks confirmed Critical and High findings |
| by 05:45 | Index, topic tables, README with the ranked top findings; commit |
| **06:10** | **Soft cutoff (timer 1):** no new agent; stop what cannot finish by 06:30; write the coverage table honestly; commit |
| **06:38** | **Hard stop (timer 2):** stop every agent, commit what exists, final report |
| 06:45 | The user's deadline: nothing runs |

Both timers are one-shot scheduled prompts in the coordinator's session
(06:10 and 06:38), each with the full instruction of what to do. Agents
write their files early and append, so a stop loses little. Intermediate
commits are made as packages complete.

## 3. Packages

Code packages come from `docs/audit-2026-11/packages/make_packages.py`
(first matching path rule wins; the file lists lie beside it). Each finder
reads its package in full and checks all topics of §1 in it, including its
section of the module guide.

| Id | Scope | Lua lines | Model |
|---|---|---|---|
| C1 | `grug_core` (combat, movement, zones, protection, world version, migrations) | 12,400 | **Fable** |
| C2 | `grug_abilities` | 9,000 | Opus |
| C3 | `grug_classes`, `grug_skills`, `grug_xp`, `grug_pvp`, `grug_factions` | 5,800 | Opus |
| M1 | mapgen wp40: terrain, height, zone fields, map adapter, determinism helpers | 11,400 | Opus |
| M2 | mapgen wp40: water, roads, vegetation, trees, swamp, wrecks | 10,200 | Opus |
| M3 | mapgen wp40: R5/R6 settlements, planner, placement, kit templates | 9,700 | **Fable** |
| M4 | mapgen wp40: R7, capital planner and protection, POI blueprints, decor catalogue | 16,100 | **Fable** |
| M5 | mapgen wp40 rest (assembly, caches, world protection) and the mod's top level | 3,300 | Opus |
| W1 | mapgen wp13 engine: dressing, parts, palettes, templates loader, city green and edge | 8,100 | Opus |
| W2 | mapgen wp13 cities: per-capital layouts, districts, plots (mostly data: duplication, dead data) | 18,900 | Opus |
| MOB1 | `grug_mobs` runtime: init, aggro, verbs, routes, patrol, separation, levels, guards, doors | 10,500 | Opus |
| MOB2 | `grug_mobs` spawning: spawn regions, policy, ABMs, camps, rares, start NPCs and villagers | 11,700 | Opus |
| MOB3 | `grug_mobs` bosses, dragons, rift, depth pulse and the species files | 9,900 | Opus |
| E1 | `grug_traders`, `grug_projectiles`, and every `GRUG PATCH` site in `mods/ENTITIES/mobs` and `mods/BASE` against VENDOR.md | 4,600 + patches | Opus |
| P1 | `grug_map`, `grug_visuals`, `grug_displays`, `grug_quickbar`, `grug_keys` | 14,000 | Opus |
| P2 | `grug_jobs`, `grug_guild`, `grug_achievements` | 11,700 | Opus |
| P3 | `grug_inventory`, `grug_quests`, `grug_trinkets`, `grug_money` | 10,400 | Opus |
| P4 | `grug_expeditions`, `grug_housing`, `grug_home`, `grug_mounts` | 12,000 | Opus |
| P5 | `grug_mail`, `grug_parties`, `grug_clans`, `grug_accounts`, `grug_bridge` (the web trust boundary) | 7,400 | Opus |
| I1 | `grug_decor`, `grug_materials`, `grug_nodes`, `grug_trees`, `grug_signs`, `grug_farming` | 9,500 | Opus |
| I2 | the other `mods/ITEMS` mods (quality, gear, gathering, repair, professions, food, stations) | 7,200 | Opus |
| X1 | `grug_ambience`, `grug_text`, `grug_sounds`, `grug_perf`; plus `settingtypes.txt` against the settings read, `mod.conf` depends against real use, locale files against the strings used | 3,400 + checks | Opus |

Cross-cutting packages (the whole of `mods/`, one lens each):

| Id | Lens | Model |
|---|---|---|
| X2 | Duplication across mods: helpers written several times (clamp, round, copy, distance, formspec escaping, serialisation wrappers, timers, cooldown tables, zone lookups) and near-copies between mods | Opus |
| X3 | Dead code across mods: Lua files no `dofile` reaches, public functions with no caller, unused registrations, media files (textures, sounds, models) no code or model references, stale settings | Opus |
| X4 | Server tick at 100 players: an inventory of every `register_globalstep`, ABM, LBM, node timer, entity `on_step`, `get_objects_inside_radius` and all-players loop, with its throttle and cost class; the worst offenders as findings | Opus |
| X5 | Persistence and upgrade safety: every saved-state writer and reader (player meta, mod storage, node meta, staticdata, world-folder caches) against the upgrade contract, the migration runner and the map reset | **Fable** |
| X6 | Security and exploits: every `register_on_player_receive_fields` handler, chat command and privilege, inventory `allow_*` callback, protection path and trade or mail flow that moves value | Opus |
| DD1 | `docs/design` world: world, world_zones, world_map, world_preparation, settlements, spawn_regions, biomes_mobs, zone_mobs, story, against the code | Opus |
| DD2 | `docs/design` combat and character: combat_stats, classes, skill_trees, ability_targeting, progression, pvp, character_visuals, accounts, scout | Opus |
| DD3 | `docs/design` items and economy: items_crafting, item_tiers, economy, professions, farming, durability_repair, inventory_equipment, decorations, miners_guild | Opus |
| DD4 | `docs/design` systems: quests, expeditions, housing, home_travel, mail, parties, clans, mounts, boats, sound | Opus |
| DT1 | `docs/technical/module-guide.md`, `modules/*`, `mod-map.md` against the code (seams, file names, function names, rules) | Opus |
| DT2 | The other `docs/technical` files (formats, upgrade contract, web bridge and accounts, luanti-lua, UI presentation, upstream workarounds) against the code | Opus |
| DP1 | AGENTS.md, README, ROADMAP, BACKLOG, STATUS, the newest CHANGELOG entries, `docs/README.md`, `docs/process/*`, `docs/maintenance/*`: wrong statements, dead links and anchors, contradictions between owners; and which findings of `docs/audit-2026-10/` are still open | Opus |
| T1 | `tools/` inventory only: which folders a gate, `run_fixtures.sh`, `checks.md` or another tool still uses, which are dead, large tracked capture and candidate folders, duplicated helpers | Opus |

**Deviation from the estimate given to the user** (25 to 35 agents): reading
every server-side file properly at about 10,000 lines per reader needs 22
code packages, and the documentation (1.7 MB of design files, 0.6 MB of
technical files) needs seven readers. With 14 cross-cutting and
documentation packages that is 36 finders. The user questioned the first
projection of about 70 runs (one verifier per package), so verification is
bundled: one verifier for two or three packages, checking Critical, High and
Medium findings only; Low findings stay UNVERIFIED. That gives about 50
runs. The deadline bounds the spend; packages run in order of value, so a
cut leaves the least important ones open.

## 4. Method

1. **Find.** One agent per package with
   [BRIEF-finder.md](../audit-2026-11/BRIEF-finder.md): static reading, one
   output file `raw/<id>.md` in a fixed format, every finding with
   file:line evidence.
2. **Verify.** A second agent in a fresh context for two or three packages with
   [BRIEF-verifier.md](../audit-2026-11/BRIEF-verifier.md): it tries to
   refute each finding at the cited place and writes `findings/<id>.md` with
   a verdict per finding (CONFIRMED, CORRECTED, REFUTED, UNVERIFIED).
   Same-model review is valid (agent model policy).
3. **Re-check.** The coordinator (Fable) reads the cited code of every
   confirmed Critical and High finding itself before it enters the top list.
4. **Synthesis.** A script builds the topic tables in `by-topic/` from the
   finding headings; the coordinator writes the README: coverage table,
   ranked top findings, proposed lanes, open questions for the user.

Rules for every agent: read-only; no LuaJIT, engine, fixture or benchmark
run; "scope with judgement" (theoretical issues become backlog notes
without severity); engine behaviour cited from `reference_projects/luanti`
or marked unchecked; English; no existing game named as a reference.

## 5. Deliverable

```
docs/audit-2026-11/
  README.md           overview, method, coverage, top findings, proposed lanes
  by-topic/*.md       one table per topic, linking into findings/
  findings/<id>.md    verified findings per package (the authority)
  raw/<id>.md         the finders' unverified output (audit trail)
  packages/           the package cut and its script
  BRIEF-finder.md, BRIEF-verifier.md
```

Each finding: stable id, severity, category, where, what, evidence,
proposal, effort, risk, guessed upgrade classification, for performance the
measurement to run, confidence, and the verifier's verdict.

## 6. Completion

Written by the coordinator at the end of the run: see the README's
"Coverage" and "Run record" sections.
