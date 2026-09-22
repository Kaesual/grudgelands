# Round 17 independent living-document drift review

Date: 2026-09-22. Reviewer: native Astra, independent of the implementation
and root documentation edits. Scope: approved `round17-plan.md` against the
integrated A–E production paths, their living design owners, AGENTS, README,
BACKLOG and ROADMAP; read-only inspection of `tools/r17_final` acceptance claims.
Production baseline: `d4853fa2`; the checkout advanced to `3deb8057` for the
test-only PARTY correction during review. Root's uncommitted living-document
edits were included. No production/test edits, interpreter execution, CLI
delegation or commits were performed by this reviewer.

Verdict: **documentation corrections required**. Initial findings: 0 Critical,
0 High, 2 Medium, 1 Low. Fix rounds: 0. Elapsed wall time: unknown.

## Findings

1. **Medium — `README.md:201`, `README.md:205`.** The current design tour still
   describes Scout arrows as ballistic and Fireball as a straight swept
   projectile that can miss. A reader planning or testing combat from this
   entry point receives the opposite of the approved release-target homing
   rule. `combat_stats.md:350` and `grug_projectiles/init.lua:211` instead
   require current valid release aim, then retain one target with no terrain
   interception. Replace these sentences with held-draw/release-target homing,
   initial range/LOS validation and mitigation-authoritative impact; distinguish
   impact cancellation or mitigation from geometric misses.

2. **Medium — `docs/design/skill_trees.md:368`, `:372`.** Far Cast still says
   maximum distance, followed by the explicit old claim that `lifetime = 2`
   and speed 20 permit 40 m of flight. There is no current Fireball lifetime
   registration supporting this explanation. `grug_projectiles/init.lua:206`
   uses max distance for release acquisition; `grug_core/homing.lua` derives
   a bounded duration and permits normal movement beyond the launch range.
   Specify initial acquisition range (the talent values remain unchanged),
   remove the lifetime-times-speed distance budget, and reference the common
   homing duration and no-postlaunch-range-expiry rule.

3. **Low — `docs/design/biomes_mobs.md:1010`.** The current behavior-class
   section ends with “Enemies — everything else, unchanged” after a narrow
   passive-prey list that omits Boars. This leaves the starter Boar implicitly
   aggressive in this section while the Round-17 matrix and
   `grug_mobs/disposition.lua` make every listed Boar variant neutral. Replace
   the exhaustive “everything else” claim with a reference to the fixed
   Round-17 family matrix, and identify the earlier prey list as examples
   rather than the complete neutral roster.

## Confirmed alignment and review limits

- The twelve-home registry, six per faction, authenticated binding, persistent
  thirty-minute return cooldown and separate death respawn have corresponding
  living HOME/world/progression/settlement/atlas rules. Deferred housing Home
  Stone rules are explicitly separate and do not add current home points.
- Global damage setting default/range/fallback and scope agree with the
  implementation. The six presentation categories, exact foreground/background
  defaults, HP-bar setting, observer hysteresis, fixed disposition matrix and
  party colors agree with the inspected production seams. Standard clients
  remain required; no client modification is introduced by these rules.
- Explicitly historical Scout/R11 ballistic passages and completed WP39
  receipts were treated as history, not new current behavior requirements.
  Unrelated older-document defects were outside this bounded audit.
- `tools/r17_final/probe.lua` asserts registration/socket/marker/disposition
  integration, not terrain population or user interaction. Its scratch-only
  preload scheduling stop is disclosed in `run_native.py`; separate production
  and executed manifests preserve that distinction. `micro.lua` executes the
  five bounded fixtures; its PASS wording does not claim GUI or fallback-engine
  acceptance. `static.py` explicitly leaves global-write/sweep-hit interpretation
  to the reviewer rather than claiming every textual match is harmless.
- Final PUC/JIT evidence and delivery receipts were pending during this audit.
  IN PROGRESS/Pending fields in execution/completion and unchanged shipped-WP
  counts are appropriate at this stage. This review does not certify pending
  interpreter evidence, GUI behavior, delivery, merge, synchronization or push.

Calibration: implementing models Astra (HOME/COMBAT/root docs) and Sol
(DISPOSITION/DISPLAY/PARTY); reviewing model native Astra; classification
non-trivial (living design/acceptance authority); initial Critical/High 0/0;
fix rounds 0; observed elapsed wall time unknown.
