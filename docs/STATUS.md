# Project status

Snapshot of 2026-11-27. This file is replaced, not extended: a round's end adds its row
at the top of the table, drops the oldest row and replaces the lines that changed. Check the live state with `git status -sb`,
`git log --oneline -5` and `git tag -l`. History through Round 79 is in the
[archive](archive/status-through-round-79.md).

## Now

- **Game:** main is 0.87.0, squash commit `7e2fa97b`, tag `round-87` (0.87.0 pushed;
  the tag and main's two Round 88 plan commits not). **0.88.0** (Round 88, compatible) is on the local branch `round88`,
  past the round-end gates and the whole-round review, awaiting the user's test; no squash
  or tag yet ([round workflow](process/round-workflow.md) §2 steps 8–10).
- **Production:** 0.87.0 (the user, 2026-11-27).
- **Last change besides rounds:** the read-only code audit of 2026-11
  ([audit](audit-2026-11/README.md)), whose findings Rounds 81 and 82 fixed or left as
  carry-overs.
- **Next:** after the user's release Round 88 lands on main (squash, tag `round-88`);
  `round88` stays local. Road selection and home preservation:
  [Round 87](planning/round87-plan.md#carry-overs), [BACKLOG](../BACKLOG.md); the
  platform follow-ups of Rounds 80, 80.1 and 83 remain in their Completions.
- **Other branches:** `round88` and its lane worktrees `r88-*`; `town-viewer` (kept
  on purpose: the three.js town viewer); `study-dwarf-architecture` and
  `study-website-screenshots` (unmerged studies of 2026-11-11).
- **GUI acceptance is not tracked** (the user, 2026-11-16): an agent proposes a human test
  when it is unsure that something works as planned.

## Open for the user

- Test and release Round 88 (`round88` synced into the user's game on 2026-11-27); push
  the tag `round-87`.
- The end-to-end account test on the rehearsal realm once the platform side is ready
  (Round 79; [contract §9](technical/web-accounts.md#9-testing)).

## Last five rounds

| Round | Version | Upgrade | Pushed | Completion |
|---|---|---|---|---|
| 88 | 0.88.0 | compatible | no | [Round 88](planning/round88-plan.md#completion-2026-11-27) |
| 87 | 0.87.0 | compatible | yes | [Round 87](planning/round87-plan.md#completion-2026-11-22) |
| 86 | 0.86.0–0.86.1 | map reset | yes | [Round 86](planning/round86-plan.md#completion-2026-11-22), [86.1](planning/round86-plan.md#follow-up-0861-2026-11-22) |
| 85 | 0.85.0 | map reset | yes | [Round 85](planning/round85-plan.md#completion-2026-11-22) |
| 84 | 0.84.0–0.84.1 | compatible | yes | [Round 84](planning/round84-plan.md#completion-2026-11-21), [84.1](planning/round84-plan.md#follow-up-0841-2026-11-21) |

Round 77 (a keep-claims map reset) was discarded; the number is not reused. The upgrade
kinds come from `tools/web_data/upgrade.json` and the
[upgrade contract](technical/upgrade-contract.md).

## Where things are

- What shipped: [CHANGELOG](../CHANGELOG.md).
- Open work: [BACKLOG](../BACKLOG.md).
- Goals: [ROADMAP](../ROADMAP.md).
- Round history, production deploys and push claims through Round 79:
  [archive](archive/status-through-round-79.md).
