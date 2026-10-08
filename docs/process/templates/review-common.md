## Independent review of a Round <NN> lane (read first)

<!-- Template (docs/process/round-workflow.md "Templates"). Copy to
~/projects/grudgelands-orchestration/r<NN>/review-common.md, replace <NN>
and the inputs, and delete this comment. -->

You review another agent's branch; you did not write it. Repository:
`~/projects/grudgelands`. Review the branch diff against its base
(`git merge-base main <branch>`) in the lane's worktree
`~/projects/grudgelands/.claude/worktrees/r<NN>-<lane>` — **read-only**: do
not edit, commit, reset or checkout anything there. Scratch work goes to a
temp dir of your own (e.g. `mktemp -d`); never `rm` anything you did not
create yourself (no globs under `/tmp`).

Read AGENTS.md, `docs/process/round-workflow.md` (its review checklist),
`docs/planning/round<NN>-plan.md`,
`~/projects/grudgelands-orchestration/r<NN>/common-brief.md`, the lane's
brief (path given), the lane's final report (given), and the inputs it
implements (for an audit round: the finding IDs in the brief).

Goal: find what would break the game or a user rule, not style nits.
- Correctness: logic bugs, nil indexes, wrong edge cases, the seams the
  brief names. Verify each claim of the lane's report you rely on; "X is
  missing in Y" claims especially need proof. Check the lane's re-check
  list: a finding marked refuted must really be refuted, a confirmed one
  must really be fixed.
- Rules: the plan's rulings (§2, number by number where the lane implements
  them) and the brief; release mode (no data migrations or placeholders,
  stable ids; the lane's upgrade classification — compatible, map reset or
  new server — is right and new map-bound state has its clear); docs updated where the change makes them wrong; no edits to
  files the brief forbids; vendored patches marked `-- GRUG PATCH` with a
  VENDOR.md entry; no scope creep beyond the brief's items and the size-S
  Lows the report lists.
- Tests: run the lane's portable fixture, `bash tools/check_lua.sh` on
  changed Lua, `python3 tools/check_fresh_server.py`, and
  `python3 tools/r28_design/validate.py --game` where quest or mob data
  changed; the fixtures that load the changed files through the Lua queue:
  `~/projects/grudgelands-orchestration/r<NN>/lua_run.sh review-<lane> 4
  tools/run_fixtures.sh <fixtures...>` (waiting is normal); the full
  `tools/run_fixtures.sh` only if you doubt the lane's full-run receipt or
  main was merged into the lane after it. A headless boot only if you
  doubt the lane's boot claim (through
  `~/projects/grudgelands-orchestration/r<NN>/lua_run.sh <label> 1 env
  LC_ALL=C tools/luanti_headless.sh` from the worktree, own run root,
  ≤ 5 min, pgrep clean afterwards, never touch other servers, never the
  user's Luanti folder). Measuring runs of your own go through
  `~/projects/grudgelands-orchestration/r<NN>/engine_run.sh`. Do not repeat
  a lane's long runs; read its receipts. No PUC runtime runs.
- Docs lanes: check every rule and number the lane writes against the code
  (no rule or number change without a code source or a user ruling) and the
  links it touches.
- Proportion (user ruling): report theoretical issues (hypothetical foreign
  mods, impossible states, load-order constructions) as "Backlog notes"
  without severity, never as blockers.

Final message (≤ 500 words): verdict `MERGE` / `MERGE AFTER FIXES` /
`REJECT`; findings ranked by severity, each with file:line, a concrete
failure scenario, and a suggested fix; checks you ran with results. Never
launch other agents or CLIs. No references to existing games in anything
you write.
