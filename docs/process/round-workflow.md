# Round workflow

How work runs since 2026-09-20: in **rounds** planned with the user, split
into **lanes** that agents implement in their own git worktrees, each lane
independently reviewed and merged, then the round-end gates; the user
pushes. Written 2026-10-05 (Round 37 lane DB) from the practice of Rounds
24–37; it replaces the per-WP workflow
([archived](../archive/process/wp-workflow.md)). Model choice:
[agent model policy](agent-model-policy.md) (the user decides the routing
per session). Astra lanes through the Codex CLI:
[cross-CLI orchestration](cross-cli-orchestration.md). Project rules:
[AGENTS.md](../../AGENTS.md).

## 1. Roles

- **The user** decides the plan, every ruling, the model routing of the
  session, picks on review pages (sounds, art, texts, POIs), tests in the
  game when they choose (human tests on demand, §2) and pushes. Nothing else
  authorizes a push.
- **The coordinator** plans the round with the user, writes the briefs,
  creates the worktrees, starts implementers and reviewers, verifies their
  reports against the code, merges in the plan's order and runs the
  round-end gates. It may implement small things itself but never approves
  its own non-trivial change.
- **An implementer** owns one lane: its worktree and branch, the files its
  brief hands it. It never pushes, merges, syncs to Luanti, touches the main
  checkout or another lane, or launches agents.
- **A reviewer** works read-only on the lane's worktree in a fresh context
  that wrote none of the change.
- **Models** follow the [agent model policy](agent-model-policy.md): Opus
  implements and reviews where possible; a Fable lane needs the user's
  approval per lane. The coordinator sets the model of every subagent it
  starts explicitly, because a session running on Fable passes Fable on to
  subagents started without an override.

## 2. A round, step by step

1. **Plan.** The coordinator drafts `docs/planning/round<NN>-plan.md` with
   the user: §1 lanes and waves (a table), §2 the user's rulings, §3 shared
   conventions, §4 one goal paragraph per lane (the briefs add file facts),
   §5 rules, §6 verification (the checks; a human-test proposal only when
   one is sensible, see "Human tests on demand" below), §7 orchestration
   notes (start state, process budget, shared files and merge order,
   compaction checkpoints, what is decided during the round). Read-only
   studies or an audit may come first; their findings are proposals until the user rules. Questions that block
   a lane go to the user before the start; the round starts on the user's
   "go".
2. **Rulings.** The plan's §2 records them. A lane meets a case the rulings
   do not cover by the ruling's reason; if that does not decide it, it stops
   that path and reports. Defaults the coordinator sets are marked as such
   and the user may overrule them.
3. **Worktrees and briefs.** Per lane:
   `git worktree add .claude/worktrees/r<NN>-<lane> -b r<NN>-<lane> round<NN>`
   (the round branch `round<NN>` comes from main in its own worktree,
   `.claude/worktrees/round<NN>`; a one-lane round may work on it directly),
   then copy `tools/bin/` from the main checkout (gitignored; `lua51` and
   `luac51` come from `tools/build_lua51.sh`). Briefs, reports, pages and the
   handover log live in the private folder
   `~/projects/grudgelands-orchestration/r<NN>/`: the common brief and the
   review brief from the [templates](#7-templates), one lane brief each
   (goals, inputs, files the lane may edit, file facts, checks), and the
   lane-merge script; every lane uses the one shared Lua queue (§7). Waves
   start when the lanes they wait for have merged.
4. **Lane work.** Re-check first: every finding or claim the lane acts on is
   checked against the code at the base commit and reported as confirmed,
   changed or refuted; a refuted finding is not fixed. Then small commits,
   the per-lane gates (§3) and the final report with
   `## Blockers / questions`.
5. **Independent review** per non-trivial lane, with the review brief and
   the checklist in §5. Verdict `MERGE`, `MERGE AFTER FIXES` or `REJECT`;
   findings with file:line and a failure scenario. Fixes go back to the
   implementer's context; a Critical or High fix gets a focused re-review.
   **Every fix delta that changes game logic gets an independent delta
   review** by a separate reviewer, however small (user, 2026-10-13); only a
   pure text, colour or display delta may be checked by the coordinator
   alone.
6. **Merge.** The coordinator verifies the report and the fix round, then
   `git merge --no-ff` into the round branch in the plan's order (the
   [lane-merge template](templates/lane_merge.sh)). When a
   shared file changed on the round branch since the lane started, the
   round branch is merged into the lane (conflicts resolved there) before its
   review, so the reviewer sees the integrated result. **A lane whose
   screenshots go to the user** for look and feel is merged, even into the
   round branch, only after the user's explicit go; a review verdict `MERGE`
   is not enough, and look fixes go back to the lane first (user,
   2026-11-11).
7. **Lane D** (§4) writes the round's end records on its own branch and is
   merged into the round branch like any lane.
8. **Round-end gates** (§3) on the round branch after lane D's merge,
   including the one full fixture run. Then the coordinator lands the round
   on main as **one squash commit** (`git merge --squash round<NN>`, a message describing the round: release
   and classification, what shipped, review verdicts, gates), tags **that
   squash commit** `round-<NN>` and deletes the branch and its worktrees
   (user, 2026-11-09; the tag on the squash commit: Round 81 ruling 14,
   2026-11-17). Main gets one commit per round, and the lane commits go with
   the branch: no lane tags are made, and plans, reports and the Completion
   name a lane's work by lane and finding id, never by a lane commit hash as
   a lasting reference (a hash is a working note while the round runs). A
   follow-up (for example after a playtest) is its own small round with its
   own squash commit and tag.
9. **Sync and push.** The coordinator syncs main to the user's game
   (`tools/sync_to_luanti.sh`) and reports a sync only when it ran. The user
   pushes main and the round's tag (tags are pushed from 2026-11-16 on; the
   older round tags `round-72.1` to `round-76.2` stay local, Round 81 ruling
   14). The lane hashes the plans of Rounds 72 to 80.1 cite therefore
   resolve only in the user's workstation checkout (those of Rounds 79 to
   80.1, whose pushed tags sit on the squash commits, only while git keeps
   the unreferenced commits). Findings from the user's or the community's playtests become the
   next round's fix lane or a follow-up round; a lane merged after lane D
   triggers the post-merge status step (§4).

**Human tests on demand** (user, 2026-11-16). A round does not end with a
GUI checklist, and nothing waits for a GUI acceptance; the user tests a
little, the community tests most. An agent proposes a short human test (what
to do in the game, what should happen, desktop or web) when it is unsure
whether something works as planned, or when a human test is otherwise
sensible, important or helpful, for example a look-and-feel change or
something no fixture or headless boot can see. The proposal goes in the
report and, when the coordinator takes it up, in the plan's §6 or
"Completion"; it is an offer, never an open item in a status file.

**Compaction checkpoints** (user, 2026-11-08). The user compacts the
coordinator's context during a round to save tokens. The plan's §7 sets the
checkpoints (for example the middle of the first wave, the end of each wave,
after lane D and the round-end run). At a checkpoint the coordinator
launches nothing and merges nothing, brings the handover log up to date,
gives the user a compaction prompt (English, in a code block, naming every
running lane with its branch, worktree and brief) and waits for the user.
Running lanes go on.

## 3. Gates

| Check | Every Lua change | Code or data lane | Docs lane | Round end |
|---|---|---|---|---|
| `bash tools/check_lua.sh <changed .lua>` (Lua under `tools/` too) | yes | yes | — | — |
| `python3 tools/check_fresh_server.py` | — | yes | — | yes |
| Upgrade classification (below): the report states it, the reviewer checks it | — | yes | — | the declaration follows from it |
| `python3 tools/check_upgrade.py` (the upgrade declaration against `origin/main`) | — | when `game.conf`'s version or `tools/web_data/upgrade.json` changed | — | yes |
| Each declared migration step has its test (below) | — | a lane that adds a step | — | yes |
| The test of **every** declared step in the `debian:trixie` container | — | when `tools/migrate.py` or `tools/migration/` changed | — | — |
| A fixture for new logic, `tools/r<NN>_<lane>/portable_test.lua` (repository path as `arg[1]`, non-zero exit on failure) | — | yes | — | — |
| LuaJIT fixtures (rule below): a lane runs only the strictly needed selection (`tools/run_fixtures.sh <names...>`); the full `tools/run_fixtures.sh` runs once, at the round's end | — | the selection | the fixtures that read a changed document | the full set, once |
| `python3 tools/r28_design/validate.py --game` | — | when quest, mob or catalogue data changed | — | yes |
| `python3 tools/r29_e4/income.py --check` | — | when loot, repair, quest copper or a price changed | — | yes |
| The topic checks [checks.md](checks.md) names for what the lane changed | — | when that topic changed | — | — |
| `python3 tools/building_templates/check.py` (the building templates' hard gate, Round 56 ruling 33; it runs the game's loader and builds every town and capital; the other template checks in [checks.md](checks.md)) | — | when templates, layouts, rosters, palettes or the loader (`wp13/templates.lua`) changed | — | yes |
| `python3 tools/r451_mc/gen_bat_ride_mesh.py --check` (the ridden bats' mesh against its source; 0.45.1) | — | when the bat models or the tool changed | — | yes |
| One smoke boot of the final branch (`tools/luanti_headless.sh`) | — | yes | — | one boot of the round branch before the squash (§2 step 8; the squash gives main the same tree) |
| Seed fleet (below) | — | `quick` for world-generation changes (a batch of similar lanes: once after the batch) | — | `full` when owed |
| Before/after numbers on the same seed, area and probe | — | when the lane touches a hot path | — | — |
| Link check of every touched link and anchor | — | — | yes | — |
| Independent review | — | every non-trivial lane | every non-trivial lane, against the code | — |
| `tools/sync_to_luanti.sh` (coordinator, from main) | — | — | — | after the squash (§2 step 9) |

**Fixture runs, only the necessary ones** (the user, 2026-10-08, tightened
2026-10-09, 2026-11-08 and 2026-11-11; this paragraph is the one owner of the
rule). LuaJIT runs are sparing and aimed: as few as possible, never "to be
safe".

- **Lanes** run only their own fixture plus the fixtures that actually test
  the behaviour they change (the lane brief may name a standing selection,
  such as the fixtures of the mob movement code). A fixture that merely
  loads a changed file but checks something else does not count: widely
  loaded files pull in dozens of unrelated old fixtures. In fix rounds: the
  own fixture plus the fixtures that failed or that test the fixed
  behaviour. Debug a failing fixture by reading before re-running; put many
  cases into one run rather than many runs. A lane that changes no Lua and
  nothing under `mods/` (docs, art, concepts, measurements) runs only the
  fixtures that read or pin a document it changes (found by grep:
  `grep -rln <file> tools --include=*.lua --include=*.py`), nothing else,
  and its brief says so. A lane given several follow-up steps runs its selection
  once after the last step, not per step.
- **Reviewers** run the lane's own fixtures once, plus another only for a
  concrete doubt it names; they never repeat a lane's long runs.
- **The coordinator** runs the full `tools/run_fixtures.sh` once, at the
  round's end: never per lane, per reviewer or per wave. After a merge
  without conflicts in game code it runs at most the merged lanes' fixtures;
  the full set again only after a conflict merge into game code.
- **A batch of similar lanes** on one shared change runs its seed fleet (and
  any wider selection) once on the round branch after the batch, not per
  lane (user, 2026-11-07).
- **A small follow-up round** (0.NN.x) clearly limited to one area ends with
  the targeted selection of the fixtures that render or test that area,
  found by grep, instead of the full run (user, 2026-11-11).

Every report names each LuaJIT and engine run it made, with the reason.

**Upgrade classification** (release mode since 0.41.0, Round 41 ruling 10;
four outcomes since Round 43;
[upgrade contract](../technical/upgrade-contract.md)). Every code or data
lane's report says whether its change is *compatible* (a world of the version
before boots and plays on), needs a *map reset* (map-bound state or world
generation changed), *migrate* (saved state the new code cannot read,
converted by a declared step of `tools/migrate.py`: a removed item,
restructured character state) or a *new server* (such state the round
decides not to migrate, or a validated world-creation scalar the game does
not force over `map_meta.txt`), with the
reason; a new-server change is reported before it is built. The reviewer
checks the statement. The round's declaration follows from the
classifications: `tools/web_data/upgrade.json` carries the version
`game.conf` names, and the round's version goes into `map_reset`,
`migrate` or `new_server` when a lane needs it (new server wins; map reset
and migrate combine). The coordinator runs `tools/check_upgrade.py` at the
round end.

**Migration steps** (contract R8; the user, 2026-10-08). Each declared step
has its test: a minimal world at the previous version, the step, a headless
boot of the new version, then the checks, its online work at load and at a
join included (pattern: `tools/r43_it/run.sh`). Whenever `tools/migrate.py`
or `tools/migration/` changes, the test of **every** declared step runs in
the `debian:trixie` container (old steps run on the shared helpers), with
the tool's unit tests (`tools/r43_mt/container_test.sh`). The online-work
fixtures of every declared step stay in `tools/run_fixtures.sh` for good
(old handlers run against new game code).

**No PUC runtime runs** at any stage: plain-5.1 syntax is the
`check_lua.sh` gate, and at most one optional PUC crash smoke test runs at
the end, once the mapgen is finished
([interpreter strategy](../technical/luanti-lua.md#interpreter-and-test-strategy)).

**Seed fleet** (user decisions 2026-10-04 and 2026-10-05; since Round 46
most POIs are placed per seed, and robustness across seeds still comes from
testing).
`tools/seed_fleet/run.sh` builds the real mapgen runtime (up to the R7
anchor roster) and plans and writes five chunks per seed for the fixed seeds
of `tools/seed_fleet/seeds.txt`, 8 in parallel under idle scheduling, never
with a wall-clock kill, prints every failed seed with its error and exits 1.
`quick` (100 seeds, about 6 minutes) runs before merge only for a change to the terrain, placement
(anchors, water, roads, capitals, zones), footprints (composition bounds,
plots, protection shapes) or the world writer's logic; a change that only
swaps or turns nodes (decor rows, a bench's facing, a material) needs no
run. `full` (about 300 seeds, about 17 minutes) runs at the end of a round
only when such a change merged since the last `full`. The reviewer checks
the run's summary line (all seeds build) and that a changed seed list is
explained.

**Docs-only changes** need no Lua, boot or sync gate and no human test, and
run only the fixtures that read a document they change (above), but a link
check and, when non-trivial, an independent review
against the code: no rule or number changes without a code source or a
user ruling.

## 4. Lane D and the post-merge status step

Lane D runs after the last planned merge, on its own branch, and is merged
into the round branch before the round-end gates (§2 step 7). **A round's
end writes three things** (user, 2026-11-16):

1. the round's entry in `CHANGELOG.md` (player-facing; its first `## `
   heading carries `game.conf`'s version);
2. the round plan's sections **"Completion"** (what shipped, by lane, with
   numbers; the user's choices; deviations; open notes; a human-test
   proposal when one was made) and, beside it, **"Carry-overs"** (what the
   round leaves behind, with its context);
3. **the round's row in `docs/STATUS.md`**: it is added at the top of the
   table of the last five rounds, the oldest row is dropped, and the lines
   the round makes wrong (the version, work in progress, open user actions)
   are replaced; the squash commit and tag follow in the post-merge status
   step. A follow-up round (0.NN.x) widens its round's row (version range,
   upgrade kind) instead of adding one. STATUS stays a snapshot of at most about 3 KB
   ([its shape](documentation.md#one-owner-per-fact)).

**The one exception:** in the same pass, lane D replaces README's short
"Current state" paragraph when the round changes what a visitor should read
there. It is replaced, never extended, and names no push or acceptance
state.

Nothing else gets a round entry. AGENTS.md, ROADMAP.md, BACKLOG.md and the
design files are never appended to at the round's end, and no heading
anywhere carries delivery, push or acceptance state. The owners stay current
through the lanes' own work instead, edited in place:

- a lane that changes a decided rule changes its design file (and the
  module guide where a seam moved), replacing the old text;
- BACKLOG holds only open work, by topic, with no per-round sections. A
  carry-over that is still wanted work also gets a one-line item under its
  topic, linking to the plan's "Carry-overs" section; a delivered item is
  deleted (its record is CHANGELOG and the plan's Completion), never marked
  done;
- ROADMAP holds goals and the next step; a reached goal is removed or
  rewritten, not annotated;
- AGENTS.md changes only when a working rule changes.

**Post-merge status step:** after the squash the coordinator sets the
STATUS lines that only exist then (the squash commit and tag), and after the
user's push the row's "pushed" cell, both read from git (`git log`,
`git tag -l`, `git status -sb`, `git ls-remote`), never from memory. A lane
merged after lane D (a late follow-up) updates the same places in place:
the plan's Completion (a "follow-up lanes" block), the CHANGELOG entry, the
round's STATUS row. The coordinator does it or starts a small docs lane for
it before the next round's plan.

## 5. Reviewing

Point reviewers at this section verbatim.

1. **Engine callback contracts:** `register_on_player_hpchange` modifier vs
   non-modifier semantics; `allow_player_inventory_action` OR-combine (nil
   when unconcerned); mobs_redo `do_punch` — any truthy return CANCELS the
   punch; entity fields persist via staticdata (`self.temp` is the only
   non-serialized store); ObjectRef validity after `core.after`/emerge
   callbacks (re-fetch by name); ItemStack copy semantics (`set_stack` after
   mutation).
2. **Lua rules:** the do-not-write list of
   [luanti-lua.md](../technical/luanti-lua.md) (vector `==`, `unpack` not
   `table.unpack`, no `\u{}`/`\x`/`\z` escapes, no goto, `x ^ 2` and `pairs`
   order in deterministic code, strict.lua global leaks; `tools/bin/luac51 -l
   -p … | grep SETGLOBAL` when in doubt). The engine version never relaxes
   plain Lua 5.1. Engine behaviour is read in `reference_projects/luanti`
   (`builtin/` → `src/script/lua_api/`) and quoted as `file:line`, never
   guessed.
3. **Performance** (100-player design target): globalstep accumulators; no
   per-tick inventory writes; `get_objects_inside_radius` frequency; ABM/LBM
   budgets; mod-storage access; no pass handles every player or zone in one
   step; particles in the hundreds, never thousands.
4. **Design adherence:** numbers and formulas against `docs/design/*` (the
   docs are the spec: a deviation is a finding, fix the code or flag the
   doc); the user's rulings in the plan; conventions (`grug_` namespace, one
   global per mod, `_grug_` fields, groups dispatch).
5. **Protection and exploits:** `is_protected` paths, the terrain-damage
   guard (`grug_core.world_alterable`), ability and resource bypasses, PvP
   flag rules, relog resets.
6. **Upgrade classification:** the lane's statement (compatible, map
   reset, migrate, new server) matches the change ([§3](#3-gates)); saved
   state keeps its ids and format or the statement says why not; new
   map-bound state has its map-reset clear
   ([upgrade contract](../technical/upgrade-contract.md) §3.4); a migration
   step keeps the baseline rule and the data API's limits, has its test and
   leaves online work only through grug_core's runner (upgrade contract
   §5).
7. **Report:** severity-ranked (Critical/High/Medium/Low), file:line, a
   one-sentence defect and a concrete failure scenario, verified against the
   code; no speculative findings.

**Scope with judgement** (user ruling 2026-09-18, "stay on the happy path"):
real bugs in our code and violations of decided rules are fixed. Theoretical
issues — conflicts only a foreign mod could cause, late runtime
registrations, constructed recipe collisions, impossible states — are noted
as "Backlog notes" without severity, never as blockers. When a second fix
round would only harden against hypotheses, stop and tell the user; they
decide between a fix and a BACKLOG note. Whoever adds a conflicting mod
opens an issue.

**Findings are hypotheses.** A finding from a review, a report or an error
message is checked at the cited place before anyone acts on it; "X is
missing in Y" is wrong more often than "X is in Y". A reviewer does not
rerun a lane's long runs; it reads the receipts.

## 6. Writing briefs

Rules for plans and briefs (from mistakes that cost hours of compute):

- **The launch sentence.** Every launch prompt (implementer, reviewer,
  resumed fix round, delta review, Astra lane) and the round's common brief
  carry this sentence verbatim (user, 2026-11-08):
  "Fixtures: run only the fixtures that are strictly needed, your own and
  those that really test the behaviour you change, as few times as possible;
  no full run (the coordinator runs it once at the round's end); name what
  you ran and why."
  A brief for a lane that changes no Lua adds "No Lua and nothing under
  `mods/` changes: run no fixtures except those that read a document you
  change (found by grep)."
- **This document is the rule set.** A private checklist in the
  orchestration folder may point here; it carries no rule of its own.
- **Goals, not mechanics.** State the property to prove and the limits, not
  the command or the environment variable; name forbidden *results*, not
  forbidden flags.
- **Measure before prescribing.** Every cost claim in a brief comes with
  its measurement or is marked unmeasured; no plan step rests on an
  extrapolated number.
- **Couple the verification to the change.** A refactor proves "no byte
  changed" with LuaJIT digests or fixtures; never add a heavier gate "to be
  safe".
- **Bound the runs.** A run over about 10 minutes needs a projection first,
  one over about 30 minutes the explicit approval of whoever wrote the brief
  (the coordinator), given on that projection, and every long run reports
  progress so silence can be told from a hang. Runs over about 8 minutes run
  detached and are polled.
- **Rough targets, not hard conditions** (user, 2026-09-25): write new rules
  as guide values; add a check only where gameplay would break (a spawn in
  water, an unwalkable road, an anchor outside its zone), not for things
  that suffice either way. In doubt, ask the user instead of adding a hard
  condition.
- **No wall-clock budgets in code:** nothing decides what it produces by
  elapsed time (output would depend on the hardware); fixed parameters
  instead, a cached one-off cost is fine. Performance numbers are
  before/after reports, never targets.
- **Escalate complexity.** A problem that makes the design clearly more
  complex or world generation noticeably slower goes to the user with
  options; a lane does not solve or accept it alone.
- **Name the standing budgets** where they apply: the Lua-process cap (at
  most 8 workstation-wide, through the shared queue, §7) and the mapgen
  engine-run budget (AGENTS.md), the particle budget, the terrain-damage
  guard, the sound approval gate.
- **Stop and report.** Every brief says that a decision it reserves, or a
  blocker outside the lane, ends in `## Blockers / questions` (what was
  tried, which option the lane would pick) instead of a silently narrowed
  scope.

## 7. Templates

Generalised copies of the files each round instantiates in its private
folder (replace `<NN>` and the round's specifics), resynced with the
practised Round 79 briefs:

- [templates/common-brief.md](templates/common-brief.md): the rules every
  lane reads first;
- [templates/review-common.md](templates/review-common.md): the
  independent-review brief;
- [templates/lane_merge.sh](templates/lane_merge.sh): merges a lane into the
  round branch with `--no-ff`, keeping both sides of line conflicts in
  append-only lists and stopping on any other conflict;
- [templates/lua_run.sh](templates/lua_run.sh): the one shared queue that
  keeps every lane, reviewer and fleet of every session inside the
  8-process cap; installed once (in use:
  `~/projects/grudgelands-orchestration/r45/lua_run.sh`), never copied per
  round;
- [templates/engine_run.sh](templates/engine_run.sh): measuring engine runs,
  at most two at once, beside the shared queue;
- [templates/run_astra.sh](templates/run_astra.sh): starts a GPT-6.2 Astra
  lane through Codex CLI (effort `xhigh`, never `ultra`;
  [Astra lanes](cross-cli-orchestration.md)).

The round's briefs, the reports, the review pages and the handover log stay
private in the orchestration folder; what a later round needs from them
goes into the plan's Completion or these documents.
