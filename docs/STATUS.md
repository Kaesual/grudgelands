# Project status

Snapshot of 2026-11-22. This file is replaced, not extended: a round's end adds its row
at the top of the table, drops the oldest row and replaces the lines that changed. Check the live state with `git status -sb`,
`git log --oneline -5` and `git tag -l`. History through Round 79 is in the
[archive](archive/status-through-round-79.md).

## Now

- **Game:** 0.85.0 (`game.conf`): Round 85 (the arena Breach Road, claims by map chunk;
  **map reset**), squash commit and tag set after the squash. Round 84 (`78b787a6`, tag
  `round-84`) and 0.84.1 (`b4540eba`, `round-84.1`) not pushed (only the user pushes).
- **Production:** 0.83.0 (the user, 2026-11-22); upgraded only after Round 86 (ruling 23).
- **Last change besides rounds:** the read-only code audit of 2026-11
  ([audit](audit-2026-11/README.md)), whose findings Rounds 81 and 82 fixed or left as
  carry-overs.
- **Next:** Round 86: the claim preview by chunks, the account Claim Stone, home names and
  the Account page ([concept](planning/housing-rework-concept.md) Part B); the platform's
  side of Rounds 80, 80.1 and 83 as listed in their Completions.
- **Other branches:** `town-viewer` (kept on
  purpose: the three.js town viewer); `study-dwarf-architecture` and
  `study-website-screenshots` (unmerged studies of 2026-11-11).
- **GUI acceptance is not tracked** (the user, 2026-11-16): an agent proposes a human test
  when it is unsure that something works as planned.

## Open for the user

- **Known defect in 0.85.0:** the Claim Stone's minimap preview still shows the old
  per-column red and a square centred on the player, not the chunk rule; placement decides
  correctly; Round 86 fixes it ([carry-overs](planning/round85-plan.md#carry-overs)).
- The Round 86 plan, and the platform's note for 0.85.0 (an ordinary map reset).
- The end-to-end account test on the rehearsal realm once the platform side is ready
  (Round 79; [contract §9](technical/web-accounts.md#9-testing)).

## Last five rounds

| Round | Version | Upgrade | Pushed | Completion |
|---|---|---|---|---|
| 85 | 0.85.0 | map reset | no | [Round 85](planning/round85-plan.md#completion-2026-11-22) |
| 84 | 0.84.0–0.84.1 | compatible | no | [Round 84](planning/round84-plan.md#completion-2026-11-21), [84.1](planning/round84-plan.md#follow-up-0841-2026-11-21) |
| 83 | 0.83.0 | compatible | yes | [Round 83](planning/round83-plan.md#completion-2026-11-18) |
| 82 | 0.82.0 | compatible | yes | [Round 82](planning/round82-plan.md#completion-2026-11-18) |
| 81 | 0.81.0 | compatible | yes | [Round 81](planning/round81-plan.md#completion-2026-11-17) |

Round 77 (a keep-claims map reset) was discarded; the number is not reused. The upgrade
kinds come from `tools/web_data/upgrade.json` and the
[upgrade contract](technical/upgrade-contract.md).

## Where things are

- What shipped: [CHANGELOG](../CHANGELOG.md).
- Open work: [BACKLOG](../BACKLOG.md).
- Goals: [ROADMAP](../ROADMAP.md).
- Round history, production deploys and push claims through Round 79:
  [archive](archive/status-through-round-79.md).
