# Round 12 execution checkpoint

Date: 2026-09-20. User explicitly said **Go** after the independent plan review.
Status: ACTIVE. Integration branch `wp12-round12`, starting main `3fdd6b35`.
Authority: `round12-plan/README.md`, three package annexes and corrected review.
Frozen planning hashes remain historical and must not be rewritten during work.

## Session contract

Root Astra orchestrates; native Sol workers and independent reviewers. No
Claude, no own-provider CLI. At most three active workers beside root. No PUC
runtime, seed fleets or broad PERF/mapgen suites; mandatory Lua-5.1 parser,
SETGLOBAL/five sweeps plus bounded relevant LuaJIT checks. Native probes only
in disposable isolated test worlds, never the user's world. Fresh-development
mode, no migrations. Existing push/sync authorization persists; sync only the
reviewed integrated main build at final delivery.

## Work ownership and state

| Package | Worker / branch / checkout | State |
|---|---|---|
| FARM | native Sol / `wp32-r12-farm` / `/tmp/grug-r12-farm` | queued |
| SKILLS | native Sol / `wp47-r12-skills` / `/tmp/grug-r12-skills` | queued |
| ART | native Sol / `wp29-r12-art` / `/tmp/grug-r12-art` | queued |
| TALENTS | native Sol; consumes frozen Skills eligibility seam | queued |
| UI / RECIPES / FOOD | native Sol; shared page/Creative owner | queued |
| POSE | root or native Sol after ART grip conventions | queued |
| Independent code/visual reviews | separate non-author agents | queued |
| UX | independent report-only integrated-candidate audit | queued |

Workers first fold their approved rules into assigned living design sections,
then implement. Root owns cross-package integration, checkpoint/status docs and
shared-file handoffs. Do not let both Skills and Talents edit abilities init;
Creative guard patches land before UI Food filtering. Existing reference source
checkouts and luac51 binaries are read from the primary checkout, not repinned
or copied into worker commits. Worktree reference gitlinks remain untouched.

## Completion checklist

- [ ] Living specifications reflect the approved round and TODO is closed.
- [ ] All package implementations and focused evidence complete.
- [ ] Independent reviews and visual acceptance complete, no open blockers.
- [ ] Integrated startup/consumer checks pass on final bytes.
- [ ] UX findings returned as report, without unapproved scope expansion.
- [ ] Main merge, runtime sync, GitHub push, art gallery, next-playtest checklist.

Next: dispatch first-wave workers; root freezes UI/Skills seams, folds shared
specs, then advances remaining packages as worker slots free. Persist exact
heads, findings and next actions here at every significant handoff.
