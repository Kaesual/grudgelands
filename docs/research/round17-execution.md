# Round 17 execution ledger

Date: 2026-09-22. Status: technical work complete; merge/sync/push pending.
Contract: [round17-plan.md](round17-plan.md). Base `2c0f4446`.
Integration branch: `wp17-home-combat-feedback`.
Final evidence, calibration and limitations: [completion](round17-completion.md).
Next user gate: [fresh-world playtest](round17-playtest.md).

## Persistent decisions

Current rules are folded into living specs. Colored default tags, six categories
and twelve RGBA settings; black 25% tag background; `grug_mob_damage_scale=1.5`
for all non-player combat actors and abilities. Immediate out-of-combat home
return, 30-minute persistent real-time cooldown; fixed family dispositions;
standard unmodified client. No new settlement geometry or spawn-weight tuning.

## Completed native lanes

| Lane | Agent/model | Worktree | Integration state |
|---|---|---|---|
| A HOME | r17_home / Astra | /tmp/grug-r17-home | 1858c469, independent MERGE |
| B COMBAT | r17_combat / Astra | /tmp/grug-r17-combat | 4cc9d126 + d4853fa2, correction review MERGE |
| C DISPOSITION | r17_disposition / Sol | /tmp/grug-r17-disposition | 148d2a4d, independent MERGE |
| D DISPLAY | r17_display / Sol | /tmp/grug-r17-display | 0f1d3293, independent MERGE |
| E PARTY | r17_disposition / Sol | /tmp/grug-r17-party | 5a085d06 + test-only 3deb8057, correction review MERGE |

A reviewer: native Astra r17_home_review. B reviewer: native Astra r17_home,
independent of B implementation. C/D/E reviewer: native Sol r17_ui_review.
Living-doc review: native Astra r17_docs_review. Zero open findings across all.
B fixed two Mediums (mounted velocity and zero-scale cone); E fixed one Low
(actual UI callback test); docs fixed two Mediums and one Low (stale descriptions).
No running implementation lane remains; no provider CLI was used.

## Frozen gates

Root tools: `tools/r17_final/`. Parser 48 Lua files, global-write audit, all five
sweeps, fresh-server audit and diff checks PASS. Exactly one final PUC process
and one LuaJIT process run all five fixtures with identical canonical digest;
see completion/evidence. Native isolated registration gate PASS (12 homes,
12 markers), all 2060 production hashes still match. No personal world writes,
full-world generation or performance campaign. GUI checks remain user-run.

## Resume / delivery

Do not re-run finished development/review work. Check git status/log and this
receipt before any operation. Commit final docs/evidence, merge the reviewed
round branch to main, run tools/sync_to_luanti.sh from main, verify installed
hashes and push origin main under existing user authorization. Record actual
merge/sync/push identities in completion and update README/BACKLOG/ROADMAP/AGENTS.
