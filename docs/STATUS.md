# Project status

Snapshot of 2026-11-22. This file is replaced, not extended: a round's end adds its row
at the top of the table, drops the oldest row and replaces the lines that changed. Check the live state with `git status -sb`,
`git log --oneline -5` and `git tag -l`. History through Round 79 is in the
[archive](archive/status-through-round-79.md).

## Now

- **Game:** 0.87.0, compatible with 0.86.1, squash commit `7e2fa97b`, tag
  `round-87`, synced to the user's game and awaiting the user's push. Housing
  records road occupancy. The occupied-home routing comparison runs offline.
- **Production:** 0.83.0; to be upgraded to 0.86.1 in one step with 0.86.0's map reset,
  which covers 0.85.0's (Round 86 ruling 5).
- **Last change besides rounds:** the read-only code audit of 2026-11
  ([audit](audit-2026-11/README.md)), whose findings Rounds 81 and 82 fixed or left as
  carry-overs.
- **Next:** the next round is open. Road selection for a future soft map reset
  and home preservation are in [Round 87](planning/round87-plan.md#carry-overs)
  and [BACKLOG](../BACKLOG.md). The platform follow-ups of Rounds 80, 80.1 and
  83 remain in their Completions.
- **Other branches:** `town-viewer` (kept on
  purpose: the three.js town viewer); `study-dwarf-architecture` and
  `study-website-screenshots` (unmerged studies of 2026-11-11).
- **GUI acceptance is not tracked** (the user, 2026-11-16): an agent proposes a human test
  when it is unsure that something works as planned.

## Open for the user

- Push main and `round-87` when ready.

- The production upgrade to 0.86.1 (0.86.0's map reset); the platform's note and the
  website's note on `default_rewards` are forwarded, the website's side is built and waits
  for its rehearsal run on 0.86.1.
- The end-to-end account test on the rehearsal realm once the platform side is ready
  (Round 79; [contract §9](technical/web-accounts.md#9-testing)).

## Last five rounds

| Round | Version | Upgrade | Pushed | Completion |
|---|---|---|---|---|
| 87 | 0.87.0 | compatible | no | [Round 87](planning/round87-plan.md#completion-2026-11-22) |
| 86 | 0.86.0–0.86.1 | map reset | yes | [Round 86](planning/round86-plan.md#completion-2026-11-22), [86.1](planning/round86-plan.md#follow-up-0861-2026-11-22) |
| 85 | 0.85.0 | map reset | yes | [Round 85](planning/round85-plan.md#completion-2026-11-22) |
| 84 | 0.84.0–0.84.1 | compatible | yes | [Round 84](planning/round84-plan.md#completion-2026-11-21), [84.1](planning/round84-plan.md#follow-up-0841-2026-11-21) |
| 83 | 0.83.0 | compatible | yes | [Round 83](planning/round83-plan.md#completion-2026-11-18) |

Round 77 (a keep-claims map reset) was discarded; the number is not reused. The upgrade
kinds come from `tools/web_data/upgrade.json` and the
[upgrade contract](technical/upgrade-contract.md).

## Where things are

- What shipped: [CHANGELOG](../CHANGELOG.md).
- Open work: [BACKLOG](../BACKLOG.md).
- Goals: [ROADMAP](../ROADMAP.md).
- Round history, production deploys and push claims through Round 79:
  [archive](archive/status-through-round-79.md).
