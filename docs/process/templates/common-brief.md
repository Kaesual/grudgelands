## Common rules for every Round <NN> lane (read first)

<!-- Template (docs/process/round-workflow.md "Templates"), resynced with the
practised Round 79 brief. Copy to
~/projects/grudgelands-orchestration/r<NN>/common-brief.md, replace <NN>, the
round summary, the plan sections and the lists marked <...>, delete what the
round does not use (contract, release details, vendored code, sound,
art, measuring runs) and this comment.
The paths are the user's workstation layout: the repository at
~/projects/grudgelands, the private orchestration folder at
~/projects/grudgelands-orchestration (AGENTS.md "Lua & Luanti environment");
replace both on another machine. -->

Project: Grudgelands, an MMO-inspired Luanti game in Lua. Round <NN> is **<the
round in one sentence>**. Lanes: <lanes and waves>. Release **0.<NN>.0**,
expected <compatible | map reset | migrate>. Words: **Expedition** (never
"instance").

Read whole: `docs/planning/round<NN>-plan.md` (lanes §1, the user's rulings §2,
coordinator defaults, shared files, your lane's goal in §4, rules §5, checks
§6). Read the other documents the plan points to <and the contract, whole, if
your lane touches it> <for an audit round: every finding ID's row, evidence,
**Impact**, **Better** and verification line>. The user's rulings outrank a
brief.

<**The contract binds <the other side>.** Build exactly to it. If you find it
wrong, incomplete or contradictory, **stop and report** (in
`## Blockers / questions`, with the option you recommend); never change it or
build around it silently: a change goes through the user.>

Your worktree is `~/projects/grudgelands/.claude/worktrees/r<NN>-<lane>` on
branch `r<NN>-<lane>` (from the integration branch `round<NN>`, never from
main; the plain-5.1 tools are in `tools/bin/`). Work **only** there (`cd` into
it first; absolute paths under it). Read `AGENTS.md` and
`docs/process/round-workflow.md`, then the code your brief names.

**Fixtures: run only the fixtures that are strictly needed, your own and those
that really test the behaviour you change, as few times as possible; no full
run (the coordinator runs it once at the round's end); name what you ran and
why.** (User: LuaJIT runs sparingly and aimed. Not after every edit, not "to be
safe", never the whole set. Debug a failing fixture by reading before
re-running. Put many cases into one fixture run rather than many runs.)
<For a lane that changes no Lua: No Lua and nothing under `mods/` changes: run
no fixtures except those that read a document you change (found by grep).>

- **Re-check first:** the plan and the briefs cite code and engine facts found
  by the coordinator's reading. Before changing code, re-check each fact you
  rely on at your base commit and list it in your report as *confirmed*,
  *changed* (what differs) or *refuted* (with evidence). A refuted lead is not
  built. Cited line numbers may have moved.
- **Decisions:** the user's rulings are fixed; the coordinator defaults are the
  plan unless you find a reason against one (then report it). A case the
  rulings do not cover is decided by the ruling's reason; anything still open
  goes to `## Blockers / questions` with your recommended option instead of
  being decided silently; if it blocks you, build the recommended option and
  flag it clearly. A lane never cuts scope on its own; if the package grows
  clearly bigger than planned, or noticeably slower or more complex at
  runtime, report it.
- **Small and focused.** The user strongly prefers small, cheap mechanisms over
  clever ones; no new frameworks.
- **Commits:** small, meaningful commits on your branch; messages end with the
  co-author line your agent uses. Never push, never merge to main or
  `round<NN>`, never touch the main checkout or another lane's worktree, never
  run `tools/sync_to_luanti.sh`. Scratch files go into a per-lane folder
  (`mktemp -d`), never a shared name. Never a bare `git stash` (the stash stack
  is shared by every worktree); set work aside with a WIP commit.
- **File ownership:** keep to the files your brief gives you and the plan's
  shared-file list (<plan section>). Any other change to a file outside that
  list goes to the coordinator first; name every shared function or file
  outside your list you changed. Add new helpers instead of reshaping shared
  ones. Only the lane the plan names changes world generation (`mods/MAPGEN`).
- **Do not edit** BACKLOG.md, README.md, CHANGELOG.md, ROADMAP.md, AGENTS.md,
  docs/STATUS.md, docs/planning/*.md <, the round's other reserved files>
  unless your brief hands you one. Do update the `docs/design/` and
  `docs/technical/` files and VENDOR.md entries your change makes wrong
  (English), keeping those edits to what your change falsifies. A new tools
  folder gets one line in `tools/README.md`.
- **Release mode** (AGENTS.md, the
  [upgrade contract](../../technical/upgrade-contract.md)): your report
  classifies your change as *compatible* (a world of the previous version
  boots and plays on), *map reset* (map-bound state or world generation
  changed), *migrate* (saved state the new code cannot read, converted by a
  declared step of `tools/migrate.py` with its test; online work only through
  grug_core's runner) or *new server*, with the reason, and lists every saved
  key the new code reads or writes (mod storage, player meta). Anything that
  would need a migration, a map reset or a new server is reported **before**
  it is built. No compat code, no placeholders for removed things; ids of
  items, achievements and waypoints stay stable (a renamed item may use
  `register_alias`), and a quest whose objectives change takes a new id. New
  map-bound state gets its map-reset clear in the same change. A step keeps
  the baseline rule and never changes once pushed.
- **Code style:** match the surrounding code (comment density, naming,
  idioms). English. Lua 5.1 compatible. No new globals except the mod's own
  table (`tools/check_lua.sh` flags SETGLOBAL per file).
- **Vendored code** (`mods/BASE/*`, the mobs_redo fork in
  `mods/ENTITIES/mobs`): every change carries a `-- GRUG PATCH:` marker at the
  change site and an entry in the matching VENDOR.md.
- **Performance** (100-player design target): no new per-tick work over all
  players; prefer events and `core.after`. Numbers are before/after
  comparisons on the same seed, area and probe, never targets; take the
  "before" on your unchanged base first.
- **Engine workarounds:** follow `docs/technical/upstream-workarounds.md`
  (every server aiming ray goes through `grug_core.aim_raycast` while its §1
  is open). A new engine workaround gets an entry there.
- **Terrain-damage guard:** towns and POIs are never damaged; anything that
  writes nodes from mobs, combat, fire or explosions respects
  `grug_core.world_alterable` and the existing guards.
- **Effects:** particles stay in the hundreds at once, never thousands (the web
  build); every spawner has a bounded amount and lifetime.
- **Sounds:** no new sound file ships without the user's pick on a listening
  page. Downloaded sound folders in the orchestration folder are read-only:
  copy, never delete, move or rewrite. <Or: No sound. No new art.>
- **Checks:** `bash tools/check_lua.sh <changed .lua files>`,
  `python3 tools/check_fresh_server.py`, a fixture for new logic
  (`tools/r<NN>_<lane>/portable_test.lua`, repository path as `arg[1]`;
  `run_fixtures.sh` picks it up; `tools/run_fixtures.sh <names...>` runs a
  selection). Fixtures that pin values you deliberately change are updated
  with a one-line reason, never bypassed. Lanes that touch quest or mob data
  also run `python3 tools/r28_design/validate.py --game`; the other checks of
  the round workflow's gates table where your change touches them. One smoke
  boot of your final branch. No PUC runtime runs. <Seed fleet: quick | none.>
- **Process budget (at most 8 Lua processes workstation-wide, shared with
  other sessions):** every Lua run longer than about 30 s and every engine boot
  goes through the shared queue
  `~/projects/grudgelands-orchestration/r45/lua_run.sh <label> <slots>
  <command...>` (a fixture selection: 2 slots with `env JOBS=2`; one boot: 1; a
  container counts as one). Waiting is normal; never work around it. A short
  single fixture may run directly.
- **Engine runs:** only those your brief lists, only
  `tools/luanti_headless.sh` from your worktree with `LC_ALL=C` (free port, own
  run root; `KEEP=1`/`ROOT=` for a second boot of the same world, `PROBE=<dir>`
  for a disposable probe mod, `SEED=` to pin the seed), through `lua_run.sh`;
  measuring runs through `~/projects/grudgelands-orchestration/r45/engine_run.sh
  <label> [args]` (at most two at once). Each with a clear question and at
  most about 5 minutes; no repeats; never a wall-clock kill of a slow run.
  **Never generate the whole world.** Kill only your own run; finish with
  `pgrep -af '^luanti.bin'` showing no server of yours (a `luanti.bin` without
  arguments is the user's GUI client: never touch it). Never `rm` a glob under
  `/tmp`. **Never use the user's personal Luanti folder**
  (`~/.var/app/org.luanti.luanti`), not even to read.
- **Engine source:** read `/home/jan/projects/grudgelands/reference_projects/luanti`
  read-only and quote file:line. The user plays on Luanti <version>.
- **Naming:** the factions are The Accord and The Throng. No references to
  existing games or their makers (titles, studios, their faction, class or
  ability names) anywhere in the repository, briefs, reports or pages;
  describe mechanics in neutral words. Code and licence provenance is not a
  reference.
- **Never touch** other worktrees or branches (`main`, `round<NN>`, any other
  `r<NN>-*`, <long-lived branches>).
- **Never launch** other agents, Codex or Claude CLIs; an independent reviewer
  checks your branch afterwards.
- **Final report** (your last message, ≤ 900 words; also write it to
  `~/projects/grudgelands-orchestration/r<NN>/reports/<lane>-report.md`): the
  re-check list, the classification with its reason and the saved-key list,
  what changed (files), how each goal is met, checks run with results
  (fixtures and engine runs named with why), before/after numbers, a short
  human-test proposal only if you are unsure something works as planned or a
  human test is otherwise sensible, backlog notes, anything deliberately left
  out, `## Blockers / questions` (empty if none: each with what you tried and
  the option you recommend), branch, final commit hash, and
  `git status --porcelain` empty.
