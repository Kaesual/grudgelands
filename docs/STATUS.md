# Project status

Snapshot of 2026-11-28. This file is replaced, not extended: a round's end adds its row
at the top of the table, drops the oldest row and replaces the lines that changed. Check the live state with `git status -sb`,
`git log --oneline -5` and `git tag -l`. History through Round 79 is in the
[archive](archive/status-through-round-79.md).

## Now

- **Game:** 0.89.0 (Round 89), **migrate** from 0.88.0, on the local branch `round89`,
  awaiting the user's test; no squash, tag or push yet. main is 0.88.0, squash commit
  `749f7dd5`, tag `round-88`, pushed with the tag `round-87` on 2026-11-28.
- **Production:** 0.87.0 on the map of 0.86.0 (the user, 2026-11-28).
- **Last change besides rounds:** the read-only code audit of 2026-11
  ([audit](audit-2026-11/README.md)), whose findings Rounds 81 and 82 fixed or left as
  carry-overs.
- **Next:** the user's test of [Round 89](planning/round89-plan.md#completion-2026-11-28)
  (effect timers on the icons, the shield bubble, home names, the arena's balconies), then
  its squash and tag. Road selection and home preservation:
  [Round 87](planning/round87-plan.md#carry-overs), [BACKLOG](../BACKLOG.md); the
  platform follow-ups of Rounds 80, 80.1 and 83 remain in their Completions.
- **Other branches:** `round89` and its lane worktrees `r89-*`; `round88` (kept local) and
  its lane worktrees `r88-*`; `town-viewer` (kept on purpose: the three.js town viewer);
  `study-dwarf-architecture` and `study-website-screenshots` (unmerged studies of
  2026-11-11).
- **GUI acceptance is not tracked** (the user, 2026-11-16): an agent proposes a human test
  when it is unsure that something works as planned.

## Open for the user

- The end-to-end account test on the rehearsal realm once the platform side is ready
  (Round 79; [contract §9](technical/web-accounts.md#9-testing)).
- Moving production to 0.89.0 means running the migration tool once on the stopped world
  before the start ([CHANGELOG](../CHANGELOG.md), 0.89.0).

## Last five rounds

| Round | Version | Upgrade | Pushed | Completion |
|---|---|---|---|---|
| 89 | 0.89.0 | migrate | no | [Round 89](planning/round89-plan.md#completion-2026-11-28) |
| 88 | 0.88.0 | compatible | yes | [Round 88](planning/round88-plan.md#completion-2026-11-27) |
| 87 | 0.87.0 | compatible | yes | [Round 87](planning/round87-plan.md#completion-2026-11-22) |
| 86 | 0.86.0–0.86.1 | map reset | yes | [Round 86](planning/round86-plan.md#completion-2026-11-22), [86.1](planning/round86-plan.md#follow-up-0861-2026-11-22) |
| 85 | 0.85.0 | map reset | yes | [Round 85](planning/round85-plan.md#completion-2026-11-22) |

Round 77 (a keep-claims map reset) was discarded; the number is not reused. The upgrade
kinds come from `tools/web_data/upgrade.json` and the
[upgrade contract](technical/upgrade-contract.md).

## Where things are

- What shipped: [CHANGELOG](../CHANGELOG.md).
- Open work: [BACKLOG](../BACKLOG.md).
- Goals: [ROADMAP](../ROADMAP.md).
- Round history, production deploys and push claims through Round 79:
  [archive](archive/status-through-round-79.md).
