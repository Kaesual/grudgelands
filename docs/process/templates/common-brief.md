## Common rules for every Round <NN> lane (read first)

<!-- Template (docs/process/round-workflow.md "Templates"). Copy to
~/projects/grudgelands-orchestration/r<NN>/common-brief.md, replace <NN>,
<BASE>, the inputs and the shared-file list from the plan's §7, delete what
the round does not use (audit lines, Astra, measuring runs) and this comment. -->

Project: Grudgelands, an MMO-inspired Luanti game in Lua. Your worktree is
`~/projects/grudgelands/.claude/worktrees/r<NN>-<lane>` on branch
`r<NN>-<lane>` (created from main <BASE>; the plain-5.1 tools are already in
`tools/bin/`). Work **only** there (`cd` into it first; use absolute paths
under it).

Read `AGENTS.md`, `docs/process/round-workflow.md` and the round plan
`docs/planning/round<NN>-plan.md` (all of it: §2 rulings, §3 conventions,
your lane in §4, §5–§7), then the inputs your lane brief names (for an audit
round: every finding ID's row, evidence, **Impact**, **Better** and
verification line). The plan's rulings decide where an input offered
options; when a case is not covered, decide by the ruling's reason; if that
does not decide either, stop that path and report it. The user's rulings are
fixed; a lane never cuts scope on its own — if your package grows clearly
bigger than planned, report it (the coordinator splits it with the user).

- **Re-check first (plan §3):** before changing code, re-check each finding
  or claim of your lane against the code at your base commit and list each
  as *confirmed*, *changed* (what differs) or *refuted* (with evidence) in
  your report. A refuted finding is not fixed. Cited line numbers may have
  moved.
- **Commits:** small, meaningful commits on your branch; every message ends
  with the co-author line your agent uses. Never push, never merge to main,
  never touch the main checkout or another lane's worktree, never run
  `tools/sync_to_luanti.sh`.
- **Do not edit** BACKLOG.md, README.md, CHANGELOG.md, ROADMAP.md,
  AGENTS.md, docs/STATUS.md, docs/planning/*.md (the coordinator and the
  docs lanes do that) unless your brief explicitly hands you one of them. Do
  update the `docs/design/` and `docs/technical/` files and VENDOR.md
  entries that your change makes wrong (English), in-lane; keep those edits
  to what your change falsifies.
- **Release mode** (AGENTS.md, the
  [upgrade contract](../../technical/upgrade-contract.md)): data migrations
  only through the tool (`tools/migrate.py`, one declared step per
  `migrate` version, with its test; online work only through grug_core's
  runner), no compat code, no placeholders for removed things; ids of
  quests, items, achievements and waypoints stay stable (a renamed item may
  use `register_alias`). Your report classifies your change as
  *compatible*, *map reset* (map-bound state or world generation changed),
  *migrate* (saved state the new code cannot read, converted by a step) or
  *new server* (such state not migrated, or a validated world-creation
  scalar), with the reason; a new-server change is reported before it is
  built. New map-bound state gets its map-reset clear in the same change.
  A step keeps the baseline rule (it relies only on what the previous step
  or map reset left, never on lazy writes at a load or on earlier online
  work having finished) and never changes once pushed.
- **Code style:** match the surrounding code (comment density, naming,
  idioms). English. Lua 5.1 compatible. The user strongly prefers small,
  cheap mechanisms over clever ones; no new frameworks.
- **Vendored code** (`mods/BASE/*`, the mobs_redo fork in
  `mods/ENTITIES/mobs`): every change carries a `-- GRUG PATCH:` marker at
  the change site and an entry in the matching VENDOR.md.
- **Shared files (plan §7):** <the plan's shared files and their merge
  order>. Add new helpers instead of reshaping shared ones, keep edits in
  another lane's area to the minimum, and say in your report which shared
  functions you changed. Only the lane the plan names changes world
  generation (`mods/MAPGEN`).
- **Checks:** `bash tools/check_lua.sh <changed .lua files>`,
  `python3 tools/check_fresh_server.py`, and a fixture for new logic
  (`tools/r<NN>_<lane>/portable_test.lua`; make sure `run_fixtures.sh` picks
  it up). **Fixture runs, sized to the change:** while you work and in fix
  rounds run only your own fixture plus the fixtures that load the files you
  changed (`grep -l <file> tools/*/portable_test.lua tools/*/fixture.lua`);
  the full `tools/run_fixtures.sh` (all portable fixtures, LuaJIT) runs
  **once**, right before your final report, and again only if a later fix
  touches files outside that selection. Lanes that touch quest or mob data also run
  `python3 tools/r28_design/validate.py --game`. A lane that adds a
  migration step adds its end-to-end test (pattern `tools/r43_it/run.sh`);
  a lane that changes `tools/migrate.py` or `tools/migration/` runs the test
  of every declared step and the tool's unit tests in the `debian:trixie`
  container (a container counts as one Lua process). One smoke boot of your
  final branch. No PUC runtime runs.
- **Lua-process budget (at most 8 workstation-wide, shared by all lanes):**
  every Lua run longer than about 30 s and every engine boot goes through
  the shared queue `~/projects/grudgelands-orchestration/r<NN>/lua_run.sh
  <label> <slots> <command...>` (`<slots>` = Lua processes the command
  starts: `run_fixtures.sh` 4 with its default `JOBS=4`, one boot 1, the
  seed fleet its `JOBS`). It waits for free slots; waiting is normal, never
  work around it. Short single fixture runs may run directly.
- **Engine runs:** only `tools/luanti_headless.sh` from your worktree with
  `LC_ALL=C` (it picks a free port and its own run root; `KEEP=1`/`ROOT=`
  for a second boot of the same world, `PROBE=<dir>` for a disposable probe
  mod, `SEED=` to pin the seed), started through `lua_run.sh` (smoke boots)
  or, for **measuring runs** (before/after timings),
  `~/projects/grudgelands-orchestration/r<NN>/engine_run.sh <label> [args]`
  from your worktree root (at most two measuring runs at once). Runs of at
  most about 5 minutes each, few of them, no repeats, never a wall-clock
  kill of a slow fleet. Kill only your own run; finish with
  `pgrep -af '^luanti.bin'` showing no server of yours. Never touch other
  lanes' servers or run roots (never `rm` a glob under `/tmp` that could
  match another lane's files). Never use the user's personal Luanti folder.
  Mapgen: only small chosen regions, never a full world.
- **Numbers are comparisons, never targets.** Take a "before" on your
  unchanged base first, the "after" with the same seed, area and probe. If
  your change becomes clearly more complex or noticeably slower than
  planned, stop and report.
- **Engine workarounds:** follow `docs/technical/upstream-workarounds.md`
  (every server aiming ray goes through `grug_core.aim_raycast` while §1 is
  open). A new engine workaround gets an entry there.
- **Terrain-damage guard:** towns and POIs are never damaged; any change that
  writes nodes from mobs, combat, fire or explosions respects
  `grug_core.world_alterable` and the existing guards.
- **Effects:** particles stay in the hundreds at once, never thousands (the
  web build); every spawner has a bounded amount and lifetime.
- **Naming:** the factions are The Accord and The Throng. No references to
  existing games or their makers (titles, studios, their faction, class or
  ability names) anywhere in the repository, briefs, reports or pages;
  describe mechanics in neutral words. Provenance is not a reference (user
  ruling 2026-10-06): code and licence provenance (VENDOR.md,
  LICENSE-media.md, CREDITS.md, `docs/reference_projects.md`, source
  citations) names the Luanti projects we vendor or read; the rule covers
  design inspiration.
- **Sounds:** no new sound file ships without the user's pick on a listening
  page. Downloaded sound source folders in the orchestration folder are
  read-only for everyone: copy, never delete, move or rewrite.
- **Never launch** Codex, Claude CLI or any other agent yourself; an
  independent reviewer checks your branch after you finish.
- **Final report** (your last message, ≤ 700 words): the re-check list
  (ID → confirmed/changed/refuted), what you changed (files), how each item
  of your brief is met, checks run with results, before/after numbers, Lows
  you added, anything deliberately left out, and `## Blockers / questions`
  (empty if none: each item with what you tried and which option you would
  pick). Include branch name, final commit hash, and confirm
  `git status --porcelain` is empty.
