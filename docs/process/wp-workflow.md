# Autonomous WP Workflow

Decided 2026-08-06. How a work package (WP) gets implemented
autonomously. AGENTS.md links here; this file is the detailed contract.

## Roles (revised 2026-08-22)

All model selection follows the sole project-wide authority,
[agent-model-policy.md](agent-model-policy.md). A WP, research note, or package
contract must not invent a local model priority.

- **The coordinator is architect, tracker, and integration judge.** Its model
  is selected under [agent-model-policy.md](agent-model-policy.md). It
  maintains the task graph, writes implementation plans (mandatory for large
  WPs) and tight per-task briefs, tracks dependencies and worktree ownership,
  reads every returned diff and its evidence, decides accepted findings, and
  performs final integration.
- **Implementation and review models follow the model policy.** Select them
  under [agent-model-policy.md](agent-model-policy.md); this process document
  does not restate its routing table.
- **Independent strong-agent review is the mandatory quality gate.** The
  policy defines the trigger, independence, and model route; the checklist
  below defines the technical review.

Historically the coordinator was required to orchestrate only. The current
rule preserves independent review while allowing the coordinator to implement
when the model policy makes that coherent and a separate handoff would add cost
without adding independence. The coordinator never self-approves a non-trivial
change.

Older project documents may use *orchestrator* as a synonym for *coordinator*.
That vocabulary does not create a separate role or model-routing rule.

Every implementation brief identifies the authoritative spec sections, files
to touch, frozen interfaces, engine contracts and gotchas from
`luanti-lua.md` plus the checklist below, acceptance criteria, non-goals, test
budget, and stop conditions.

## Flow per WP

1. **Preflight**: read AGENTS.md, BACKLOG.md (the WP row IS the
   acceptance contract), the spec docs it references, and check for blocking
   `TODO-design-*.md`. If the row is vague, draft the sharpened wording before
   implementation, land it on the WP branch created in step 2, and cover it in
   the step-5 review. A WP with an unresolved design blocker is not started.
2. **Branch**: `wp<NN>-<slug>` off current `main` (e.g. `wp18-continents`).
3. **Implement** on the branch with the model selected by
   [agent-model-policy.md](agent-model-policy.md), working from the
   coordinator's brief; the coordinator reviews each returned diff before
   building on it. Project conventions (AGENTS.md),
   syntax check per changed file with **`tools/bin/luac51 -p`** (the
   engine's own bundled 5.1.5 — build once via `tools/build_lua51.sh`;
   `luajit` is a superset and green-lights `goto`, see "Verifying a
   change" in `docs/research/luanti-lua.md`). Use LuaJIT for exhaustive
   development loops where the harness supports it; this changes test cost,
   never the accepted language. Commit in coherent steps. Do NOT run
   `tools/sync_to_luanti.sh` from a branch unless the
   user asked to runtime-test that branch — the sync overwrites the
   shared Luanti install.
4. **Self-check** before review: run the five grep sweeps from
   "Verifying a change" in `docs/research/luanti-lua.md` (they cover the
   do-not-write list; plain-Lua-5.1 fallback is a HARD requirement),
   inspect `SETGLOBAL` for every changed mod file, and run representative
   PUC-5.1 KATs with byte-identical canonical digest/artifact comparison at
   intermediate milestones. For WP40, exhaustive populations always run under
   LuaJIT. At T2-final and T9-final, run exactly the checksum-pinned PCC plus
   retained F1/F2 defined by `docs/research/wp40-t2-contracts.md` Section
   14.7; do not widen it ad hoc. The full-`W` merge retains exact LuaJIT/PUC
   artifact parity. Also check the AGENTS performance rules
   (globalstep throttling, inventory churn, 100-player target).
5. **Mandatory code review**: under **Independent review** in
   [agent-model-policy.md](agent-model-policy.md), run at least one full
   independent strong-agent review of the WP diff using the checklist below.
   **Run review/research subagents SYNCHRONOUSLY**
   (`run_in_background: false`) — pilot
   lesson from WP19: background-subagent results can route to the main
   session instead of the coordinator, which then stalls waiting for
   a notification that never arrives. Larger WPs: split lenses
   across 2–3 independent strong agents (correctness / Lua+perf /
   design-adherence) and adversarially verify High findings. Findings are
   fixed on the branch; High/Critical fixes get a focused re-review. A
   reviewer does not
   automatically duplicate an identical long PUC suite: inspect immutable
   artifacts, logs, interpreter evidence and hashes, then run targeted
   independent PUC KATs. For WP40 outside T2-final and T9-final, missing
   evidence or a finding blocks the milestone and must be closed with targeted
   PUC KATs and newly bound immutable evidence; it never authorizes widening
   the final PCC or running an exhaustive population under PUC.
6. **Docs**: BACKLOG row → ✅ with summary; ROADMAP checkboxes; new
   insights → AGENTS.md or docs/; design-doc deltas folded in. The durable
   completion record also carries the model and review calibration fields
   required by **Calibration and policy maintenance** in
   [agent-model-policy.md](agent-model-policy.md).
7. **Merge to main** after the review is clean (merge commit, no
   squash — keep the step history). Then sync to Luanti.
8. **Completion summary to the user** always includes a **runtime test
   plan**: the 5-minute checklist of what to click/verify in-game
   (agents cannot run the Flatpak GUI — the user is the runtime
   tester). Regressions found there become fix commits on main.
   A real fallback-engine run is a separate runtime gate and is never inferred
   from standalone LuaJIT/PUC equality.

## Code review checklist (for independent reviewers)

Point reviewers at this section verbatim.

1. **Engine callback contracts**: `register_on_player_hpchange`
   modifier vs non-modifier semantics; `allow_player_inventory_action`
   OR-combine (nil when unconcerned); mobs_redo `do_punch` — any truthy
   return CANCELS the punch; entity fields persist via staticdata
   (`self.temp` is the only non-serialized store); ObjectRef validity
   after `core.after`/emerge callbacks (re-fetch by name); ItemStack
   copy semantics (`set_stack` needed after mutation).
2. **Lua rules**: full sweep against `docs/research/luanti-lua.md`
   (do-not-write list; vector `==` trap; `unpack` not `table.unpack`;
   no `\u{}`/`\x`/`\z` escapes — these do not error, they silently mean
   something else on the fallback build; no goto; strict.lua global
   leaks — verify via `tools/bin/luac51 -l -p … | grep SETGLOBAL` when
   in doubt). The engine version pin
   (5.17.0-dev) never relaxes this: the language stays plain Lua 5.1.
   Engine behaviour is not guessed — it is read in
   `reference_projects/luanti` (`builtin/` → `src/script/lua_api/`) and
   quoted as `file:line`.
3. **Performance** (100-player design target): globalstep accumulators;
   no per-tick inventory writes; `get_objects_inside_radius` frequency;
   ABM/LBM budgets; mod-storage access patterns.
4. **Design-doc adherence**: numbers/formulas vs `docs/design/*` (the
   docs are the spec — deviations are findings, either fix the code or
   flag the doc); conventions (grug_ namespace, one global per mod,
   `_grug_` fields, groups dispatch).
5. **Protection/exploits**: `is_protected` paths, ability/resource
   bypasses, PvP flag rules, relog resets.
6. **Report format**: severity-ranked (Critical/High/Medium/Low),
   file:line, one-sentence defect + concrete failure scenario; verified
   against the actual code — no speculative findings.
