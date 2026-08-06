# Autonomous WP Workflow

Decided 2026-08-06. How a work package (WP) gets implemented
autonomously. AGENTS.md links here; this file is the detailed contract.

## Roles (revised 2026-08-06: Fable orchestrates only — credit budget)

- **Fable = orchestrator, architect and judge — it does NOT implement.**
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
   `luajit -e "assert(loadfile(...))"` per changed file, commits in
   coherent steps. Do NOT run `tools/sync_to_luanti.sh` from a branch
   unless the user asked to runtime-test that branch — the sync
   overwrites the shared Luanti install.
4. **Self-check** before review: grep sweep against the
   `docs/research/luanti-lua.md` do-not-write list (plain-Lua-5.1
   fallback is a HARD requirement), AGENTS performance rules
   (globalstep throttling, inventory churn, 100-player target).
5. **Mandatory code review**: at least **one full Opus code review of
   the WP diff** using the checklist below. **Run review/research
   subagents SYNCHRONOUSLY** (`run_in_background: false`) — pilot
   lesson from WP19: background-subagent results can route to the main
   session instead of the orchestrator, which then stalls waiting for
   a notification that never arrives. Larger WPs: split lenses
   across 2–3 Opus agents (correctness / Lua+perf / design-adherence)
   and adversarially verify High findings. Findings are fixed on the
   branch; High/Critical fixes get a focused re-review.
6. **Docs**: BACKLOG row → ✅ with summary; ROADMAP checkboxes; new
   insights → AGENTS.md or docs/; design-doc deltas folded in.
7. **Merge to main** after the review is clean (merge commit, no
   squash — keep the step history). Then sync to Luanti.
8. **Completion summary to the user** always includes a **runtime test
   plan**: the 5-minute checklist of what to click/verify in-game
   (agents cannot run the Flatpak GUI — the user is the runtime
   tester). Regressions found there become fix commits on main.

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
   no `\u{}`/`\x`/`\z` escapes; no goto; strict.lua global leaks —
   verify via `luajit -bl` GSET when in doubt).
3. **Performance** (100-player design target): globalstep accumulators;
   no per-tick inventory writes; `get_objects_inside_radius` frequency;
   ABM/LBM budgets; mod-storage access patterns.
4. **Design-doc adherence**: numbers/formulas vs `docs/design/*` (the
   docs are the spec — deviations are findings, either fix the code or
   flag the doc); conventions (wob_ namespace, one global per mod,
   `_wob_` fields, groups dispatch).
5. **Protection/exploits**: `is_protected` paths, ability/resource
   bypasses, PvP flag rules, relog resets.
6. **Report format**: severity-ranked (Critical/High/Medium/Low),
   file:line, one-sentence defect + concrete failure scenario; verified
   against the actual code — no speculative findings.
