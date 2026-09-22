# Round 17 execution ledger

Status: authorized, A/B/C running in parallel (2026-09-22).
Contract: [round17-plan.md](round17-plan.md). Base `2c0f4446`.
Integration branch: `wp17-home-combat-feedback`.

## Persistent decisions

All R17 decisions are in the plan and will be folded into living specs before
completion. Latest: colored default tags, six classes/twelve RGBA settings;
black 25% tag background; `grug_mob_damage_scale=1.5` covers all non-player
combat actors and their abilities. Immediate out-of-combat home return, 30min
persistent real-time cooldown. Fixed family dispositions. Standard client only.

## Lanes

| Lane | Model | Worktree | State |
|---|---|---|---|
| A HOME | Astra | /tmp/grug-r17-home | Running |
| B COMBAT | Astra | /tmp/grug-r17-combat | Running |
| C DISPOSITION | Sol | /tmp/grug-r17-disposition | Running |
| D DISPLAY | Sol | /tmp/grug-r17-display | Queued |
| E PARTY | Sol | /tmp/grug-r17-party | Queued |

Root owns integration, shared docs/settings reconciliation, final portable gates,
independent review routing and delivery. No implementation agent launches more
agents or provider CLIs. No PUC runtime in development; root final pair only.

Native agents: `/root/r17_home`, `/root/r17_combat`, `/root/r17_disposition`.
HOME calls COMBAT's `grug_core.invalidate_combat_identity` before teleport;
DISPOSITION owns mobs/init registration; COMBAT owns levels damage/verbs.
Root has folded accepted rules into living specs, including distinguishing
deferred housing Home Stone from current innkeeper homes.

## Next actions after compaction

Read this ledger and the plan, check native agents and worktree status; resume
existing work rather than duplicating it. Finish C then schedule D/E as slots
free. Review every lane before merging main. Update this ledger with actual
agent names, commits, findings, fixes and frozen gate evidence as work proceeds.
