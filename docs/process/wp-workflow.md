# Autonomous WP Workflow

Decided 2026-08-06. How a work package (WP) gets implemented
autonomously. AGENTS.md links here; this file is the detailed contract.

## Roles (revised 2026-08-06: the orchestrator orchestrates only)

The orchestrator may be Fable (cheaper) or Opus (stronger judgment on
contested findings) — the role is the same either way; pick per WP.

- **The orchestrator is architect and judge — it does NOT implement.**
  It reads the specs, writes the implementation plan (task
  decomposition, ordering, interfaces — mandatory for large WPs like
  mapgen reworks), authors a tight **per-task brief** for every
  implementation subagent (spec sections, files to touch, engine
  contracts/gotchas to respect from luanti-lua.md + the checklist
  below, acceptance criteria), reads every returned diff, decides
  contested review findings, and does the final integration pass
  before merge. Exception: trivial glue/one-line fixes where
  delegation overhead exceeds doing it.
- **Opus subagents implement everything** from those briefs — features,
  fixes, assets, doc updates, searches.
- **Opus review agents = mandatory quality gate** (see below). The
  reviewer is always a DIFFERENT agent than the implementer.

## Flow per WP

1. **Preflight**: read AGENTS.md, BACKLOG.md (the WP row IS the
   acceptance contract — if it is vague, sharpen it first and commit
   that), the spec docs it references, and check for blocking
   `TODO-design-*.md`. A WP with an unresolved design blocker is not
   started.
2. **Branch**: `wp<NN>-<slug>` off current `main` (e.g. `wp18-continents`).
3. **Implement** on the branch — via Opus subagents working from the
   orchestrator's briefs (roles above); the orchestrator reviews each
   returned diff before building on it. Project conventions (AGENTS.md),
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
   intermediate milestones. For WP40, reserve comprehensive PUC rounds for
   T2-final and T9-final and parallelize independent seed ranges or test
   groups with exact-cover evidence. Exhaustive iteration before those final
   gates belongs under LuaJIT. Also check the AGENTS performance rules
   (globalstep throttling, inventory churn, 100-player target).
5. **Mandatory code review**: at least **one full Opus code review of
   the WP diff** using the checklist below. **Run review/research
   subagents SYNCHRONOUSLY** (`run_in_background: false`) — pilot
   lesson from WP19: background-subagent results can route to the main
   session instead of the orchestrator, which then stalls waiting for
   a notification that never arrives. Larger WPs: split lenses
   across 2–3 Opus agents (correctness / Lua+perf / design-adherence)
   and adversarially verify High findings. Findings are fixed on the
   branch; High/Critical fixes get a focused re-review. A reviewer does not
   automatically duplicate an identical long PUC suite: inspect immutable
   artifacts, logs, interpreter evidence and hashes, then run targeted
   independent PUC KATs. For WP40 outside T2-final and T9-final, missing
   evidence or a finding blocks the milestone and must be closed with targeted
   PUC KATs and newly bound immutable evidence; it never authorizes another
   comprehensive PUC round.
6. **Docs**: BACKLOG row → ✅ with summary; ROADMAP checkboxes; new
   insights → AGENTS.md or docs/; design-doc deltas folded in.
7. **Merge to main** after the review is clean (merge commit, no
   squash — keep the step history). Then sync to Luanti.
8. **Completion summary to the user** always includes a **runtime test
   plan**: the 5-minute checklist of what to click/verify in-game
   (agents cannot run the Flatpak GUI — the user is the runtime
   tester). Regressions found there become fix commits on main.
   A real fallback-engine run is a separate runtime gate and is never inferred
   from standalone LuaJIT/PUC equality.

## Code review checklist (for the Opus reviewers)

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
