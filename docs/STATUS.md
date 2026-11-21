# Project status

Snapshot of 2026-11-21. This file is replaced, not extended: a round's end adds its row
at the top of the table, drops the oldest row and replaces the lines that changed. Check the live state with `git status -sb`,
`git log --oneline -5` and `git tag -l`. History through Round 79 is in the
[archive](archive/status-through-round-79.md).

## Now

- **Game:** 0.84.1 (`game.conf`): Round 84 (player feedback; compatible) as the squash
  commit `78b787a6`, tag `round-84`, and its follow-up 0.84.1 (with food in hand a short tap
  picks up a dropped item; compatible) as `b4540eba`, tag `round-84.1`. Synced to the user's
  game, not pushed (only the user pushes: `git push origin main round-84 round-84.1`).
- **Production:** 0.78.0 (the user, 2026-11-16).
- **Last change besides rounds:** the read-only code audit of 2026-11
  ([audit](audit-2026-11/README.md)), whose findings Rounds 81 and 82 fixed or left as
  carry-overs.
- **Next:** Round 85, the arena at the map's centre with a full map reset including claims
  (the user, 2026-11-21; [Round 84 plan](planning/round84-plan.md#round-85-the-users-rulings-of-2026-11-21));
  the platform's side of Rounds 80, 80.1 and 83 as listed in their Completions.
- **Other branches:** `town-viewer` (kept on
  purpose: the three.js town viewer); `study-dwarf-architecture` and
  `study-website-screenshots` (unmerged studies of 2026-11-11).
- **GUI acceptance is not tracked** (the user, 2026-11-16): an agent proposes a human test
  when it is unsure that something works as planned.

## Open for the user

- The Claim Stone rework for Round 85 (one map chunk per claim, a shared stone per account
  and faction): under discussion,
  [Round 84 plan](planning/round84-plan.md#round-85-the-users-rulings-of-2026-11-21).
- The end-to-end account test on the rehearsal realm once the platform side is ready
  (Round 79; [contract §9](technical/web-accounts.md#9-testing)).

## Last five rounds

| Round | Version | Upgrade | Pushed | Completion |
|---|---|---|---|---|
| 84 | 0.84.0–0.84.1 | compatible | no | [Round 84](planning/round84-plan.md#completion-2026-11-21), [84.1](planning/round84-plan.md#follow-up-0841-2026-11-21) |
| 83 | 0.83.0 | compatible | yes | [Round 83](planning/round83-plan.md#completion-2026-11-18) |
| 82 | 0.82.0 | compatible | yes | [Round 82](planning/round82-plan.md#completion-2026-11-18) |
| 81 | 0.81.0 | compatible | yes | [Round 81](planning/round81-plan.md#completion-2026-11-17) |
| 80 | 0.80.0–0.80.1 | compatible | yes | [Round 80](planning/round80-plan.md#completion-2026-11-16), [80.1](planning/round80.1-plan.md#completion-2026-11-16) |

Round 77 (a keep-claims map reset) was discarded; the number is not reused. The upgrade
kinds come from `tools/web_data/upgrade.json` and the
[upgrade contract](technical/upgrade-contract.md).

## Where things are

- What shipped: [CHANGELOG](../CHANGELOG.md).
- Open work: [BACKLOG](../BACKLOG.md).
- Goals: [ROADMAP](../ROADMAP.md).
- Round history, production deploys and push claims through Round 79:
  [archive](archive/status-through-round-79.md).
