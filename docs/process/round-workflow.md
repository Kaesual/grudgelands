# Round workflow

How work runs since 2026-09-20: in **rounds** planned with the user, split
into **lanes** that agents implement in their own git worktrees, each lane
independently reviewed and merged, then round-end gates and the user's GUI
test. Written 2026-10-05 (Round 37 lane DB) from the practice of Rounds
24–37; it replaces the per-WP workflow
([archived](../archive/process/wp-workflow.md)). Model choice:
[agent model policy](agent-model-policy.md) (the user decides the routing
per session). Cross-provider CLI mechanics:
[cross-CLI orchestration](cross-cli-orchestration.md) and
[Claude CLI review](claude-cli-review.md). Project rules: [AGENTS.md](../../AGENTS.md).

## 1. Roles

- **The user** decides the plan, every ruling, the model routing of the
  session, picks on review pages (sounds, art, texts, POIs), runs the GUI
  test and pushes. Nothing else ends fresh-server mode or authorizes a push.
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

## 2. A round, step by step

1. **Plan.** The coordinator drafts `docs/planning/round<NN>-plan.md` with
   the user: §1 lanes and waves (a table), §2 the user's rulings, §3 shared
   conventions, §4 one goal paragraph per lane (the briefs add file facts),
   §5 rules, §6 verification with the GUI checklist, §7 orchestration notes
   (start state, process budget, shared files and merge order, what is
   decided during the round). Read-only studies or an audit may come first;
   their findings are proposals until the user rules. Questions that block
   a lane go to the user before the start; the round starts on the user's
   "go".
2. **Rulings.** The plan's §2 records them. A lane meets a case the rulings
   do not cover by the ruling's reason; if that does not decide it, it stops
   that path and reports. Defaults the coordinator sets are marked as such
   and the user may overrule them.
3. **Worktrees and briefs.** Per lane:
   `git worktree add .claude/worktrees/r<NN>-<lane> -b r<NN>-<lane> main`,
   then copy `tools/bin/` from the main checkout (gitignored; `lua51` and
   `luac51` come from `tools/build_lua51.sh`). Briefs, reports, pages and the
   handover log live in the private folder
   `~/projects/grudgelands-orchestration/r<NN>/`: the common brief and the
   review brief from the [templates](#7-templates), one lane brief each
   (goals, inputs, files the lane may edit, file facts, checks), and the
   queue scripts. Waves start when the lanes they wait for have merged.
4. **Lane work.** Re-check first: every finding or claim the lane acts on is
   checked against the code at the base commit and reported as confirmed,
   changed or refuted; a refuted finding is not fixed. Then small commits,
   the per-lane gates (§3) and the final report with
   `## Blockers / questions`.
5. **Independent review** per non-trivial lane, with the review brief and
   the checklist in §5. Verdict `MERGE`, `MERGE AFTER FIXES` or `REJECT`;
   findings with file:line and a failure scenario. Fixes go back to the
   implementer's context; a Critical or High fix gets a focused re-review.
6. **Merge.** The coordinator verifies the report and the fix round, then
   `git merge --no-ff` on main in the plan's order. When a shared file
   changed on main since the lane started, main is merged into the lane
   (conflicts resolved there) before its review, so the reviewer sees the
   integrated result.
7. **Round-end gates** (§3) on main after the last merge.
8. **Lane D and the post-merge status step** (§4).
9. **The user's GUI test** (desktop and the web build) on the synced game,
   then the user pushes. GUI findings become the next round's fix lane or a
   late follow-up lane; a lane merged after lane D triggers the post-merge
   status step again.

## 3. Gates

| Check | Every Lua change | Code or data lane | Docs lane | Round end (main) |
|---|---|---|---|---|
| `bash tools/check_lua.sh <changed .lua>` (Lua under `tools/` too) | yes | yes | — | — |
| `python3 tools/check_fresh_server.py` | — | yes | — | yes |
| A fixture for new logic, `tools/r<NN>_<lane>/portable_test.lua` (repository path as `arg[1]`, non-zero exit on failure) | — | yes | — | — |
| `tools/run_fixtures.sh` (every portable fixture, LuaJIT) | — | yes | — | yes |
| `python3 tools/r28_design/validate.py --game` | — | when quest, mob or catalogue data changed | — | yes |
| `tools/r29_e4/income.py --check` | — | when loot, repair, quest copper or a price changed | — | yes |
| The topic checks AGENTS.md names (`r28_regions/run.sh` after a recipe change, `r33_ds/build_doc.py --check`, `r28_names/build_review.py --check`, `r31_b/gen_enchant_masks.py --check`, `r33_c3/gen_cloak_model.py --check`) | — | when that topic changed | — | — |
| One smoke boot of the final branch (`tools/luanti_headless.sh`) | — | yes | — | one boot of main |
| Seed fleet (below) | — | `quick` for world-generation changes | — | `full` when owed |
| Before/after numbers on the same seed, area and probe | — | when the lane touches a hot path | — | — |
| Link check of every touched link and anchor | — | — | yes | — |
| Independent review | — | every non-trivial lane | every non-trivial lane, against the code | — |
| `tools/sync_to_luanti.sh` (coordinator, from main) | — | — | — | yes |
| The user's GUI check | — | — | — | yes |

**No PUC runtime runs** at any stage: plain-5.1 syntax is the
`check_lua.sh` gate, and at most one optional PUC crash smoke test runs at
the end, once the mapgen is finished
([interpreter strategy](../technical/luanti-lua.md#interpreter-and-test-strategy)).

**Seed fleet** (user decisions 2026-10-04 and 2026-10-05; POIs stay at fixed
anchors, so robustness across seeds comes from testing).
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

**Docs-only changes** need no Lua, fixture, boot or sync gate and no GUI
test plan, but a link check and, when non-trivial, an independent review
against the code: no rule or number changes without a code source or a
user ruling.

## 4. Lane D and the post-merge status step

Lane D runs after the last planned merge: the round plan's completion
section (what shipped, by lane, with numbers; the user's choices; deviations;
open notes; the GUI checklist), then the status owners:

- `docs/STATUS.md`: the round's entry and its push and acceptance line;
- the one-line status pointer in AGENTS.md;
- ROADMAP (goals and milestones only), BACKLOG (WP rows, carry-overs,
  open questions);
- README's short current state and the player changelog
  (`CHANGELOG.md`);
- the status line of any audit or study the round closed.

**Post-merge status step:** every lane merged after lane D (late follow-ups
from the user's first look) and the user's push update the same places
again: the plan's completion (a "follow-up lanes" block and checklist
items), STATUS (push line, the follow-ups, any seed fleet owed), the AGENTS
pointer, ROADMAP, BACKLOG, README and CHANGELOG. The coordinator does it or
starts a small docs lane for it before the next round's plan.

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
6. **Report:** severity-ranked (Critical/High/Medium/Low), file:line, a
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
- **Name the standing budgets** where they apply: the Lua-process cap and
  the mapgen engine-run budget (AGENTS.md), the particle budget, the
  terrain-damage guard, the sound approval gate.
- **Stop and report.** Every brief says that a decision it reserves, or a
  blocker outside the lane, ends in `## Blockers / questions` (what was
  tried, which option the lane would pick) instead of a silently narrowed
  scope.

## 7. Templates

Generalised copies of the files each round instantiates in its private
folder (replace `<NN>` and the round's specifics):

- [templates/common-brief.md](templates/common-brief.md): the rules every
  lane reads first;
- [templates/review-common.md](templates/review-common.md): the
  independent-review brief;
- [templates/lua_run.sh](templates/lua_run.sh): the queue that keeps every
  lane, reviewer and fleet inside the 8-process cap;
- [templates/engine_run.sh](templates/engine_run.sh): measuring engine runs,
  at most two at once;
- [templates/run_astra.sh](templates/run_astra.sh): starts a GPT-6 Astra
  lane through Codex CLI (effort `xhigh`, never `ultra`).

The round's briefs, the reports, the review pages and the handover log stay
private in the orchestration folder; what a later round needs from them
goes into the plan's completion, STATUS or these documents.
