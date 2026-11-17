## Independent review of a Round <NN> lane (read first)

<!-- Template (docs/process/round-workflow.md "Templates"), resynced with the
practised Round 79 brief. Copy to
~/projects/grudgelands-orchestration/r<NN>/review-common.md, replace <NN> and
the inputs, delete the bullets the round does not use and this comment.
The paths are the user's workstation layout: the repository at
~/projects/grudgelands, the private orchestration folder at
~/projects/grudgelands-orchestration (AGENTS.md "Lua & Luanti environment");
replace both on another machine. -->

You review another agent's branch; you did not write it. Repository:
`/home/jan/projects/grudgelands`. Review the branch diff against its base
(`git merge-base round<NN> <branch>`) in the lane's worktree
`/home/jan/projects/grudgelands/.claude/worktrees/r<NN>-<lane>`: **read-only**:
do not edit, commit, reset or checkout anything there. Scratch work goes to a
temp dir of your own (`mktemp -d`); never `rm` anything you did not create (no
globs under `/tmp`).

Read AGENTS.md, the "Reviewing" section of `docs/process/round-workflow.md`,
`docs/planning/round<NN>-plan.md` (all of it), <the contract or design files
the lane builds on>, `~/projects/grudgelands-orchestration/r<NN>/common-brief.md`,
the lane's brief and the lane's report (paths given).

Goal: find what would break the game, a player's state, <a contract,> a ruling
of the plan or a user rule; not style nits.
- <**The contract:** the lane's side matches <the contract> exactly (field
  names, types and limits, states, result codes, order of events). Any
  deviation is a finding, even if it looks better: the other side builds on
  the text.>
- **Correctness:** logic bugs, nil indexes, edge cases (offline players, a
  player leaving or dying mid-action, a relog, a reload with saved data, the
  seams the brief names). Verify each report claim you rely on; "X is missing
  in Y" claims need proof (grep the whole tree). Engine claims are checked in
  `/home/jan/projects/grudgelands/reference_projects/luanti`. Check the lane's
  re-check list: a fact marked refuted must really be refuted, a confirmed
  finding must really be fixed.
- **The rulings met exactly** (not more, not less): the plan's §2 and the
  coordinator defaults as written; open points listed as questions rather
  than decided silently; no file outside the brief and the plan's shared-file
  list edited.
- **Rules:** release mode (the lane's classification, compatible, map reset,
  migrate or new server, is right; saved data keeps its format; the saved-key
  list checked against the diff; new map-bound state has its clear; a
  migration step has its test and keeps the baseline rule); docs updated
  where the change makes them wrong; no edits to forbidden files; vendored
  patches marked `-- GRUG PATCH` with a VENDOR.md entry; no scope creep; no new
  per-tick work over all players; no new globals.
- **Tests:** `bash tools/check_lua.sh` on changed Lua,
  `python3 tools/check_fresh_server.py`, `python3 tools/r28_design/validate.py
  --game` where quest or mob data changed, `python3 tools/check_upgrade.py`
  where the declaration or `game.conf`'s version changed, and the lane's own
  fixture(s) once, through the queue
  `~/projects/grudgelands-orchestration/r45/lua_run.sh review-<lane> 2 env
  JOBS=2 tools/run_fixtures.sh <fixtures...>`.
  **Fixtures: run only the fixtures that are strictly needed, your own and
  those that really test the behaviour you change, as few times as possible;
  no full run (the coordinator runs it once at the round's end); name what you
  ran and why.** For a reviewer that means: the lane's own fixtures once, plus
  another one only if you have a concrete doubt it names; nothing else. No
  engine run unless you doubt the lane's claim (then one, through
  `lua_run.sh <label> 1 ...` from the worktree with `LC_ALL=C`, ≤ 5 min,
  never generating the whole world, pgrep clean afterwards, never the user's
  Luanti folder). Never repeat a lane's long runs; read its receipts. No PUC
  runtime runs.
- **Docs lanes:** check every rule and number the lane writes against the code
  (no rule or number change without a code source or a user ruling) and the
  links it touches.
- **Proportion (user ruling):** theoretical issues (foreign mods, impossible
  states, load-order constructions) are "Backlog notes" without severity,
  never blockers. A question only a person in the game can answer goes to the
  coordinator as a proposed human test.

Final message (≤ 600 words; the coordinator saves it as
`~/projects/grudgelands-orchestration/r<NN>/reports/<lane>-review.md`): verdict
`MERGE` / `MERGE AFTER FIXES` / `REJECT`; findings ranked by severity, each
with file:line, a concrete failure scenario and a suggested fix; checks you ran
with results. Never launch other agents or CLIs. No references to existing
games in anything you write.
