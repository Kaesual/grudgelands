# Project status

Snapshot of 2026-11-18. This file is replaced, not extended: a round's end adds its row
at the top of the table, drops the oldest row and replaces the lines that changed. Check the live state with `git status -sb`,
`git log --oneline -5` and `git tag -l`. History through Round 79 is in the
[archive](archive/status-through-round-79.md).

## Now

- **Game:** 0.83.0 (`game.conf`), Round 83 (the bridge command `character.delete`: the website
  erases a character on request, compatible), `53d17e9b`, tag `round-83`, not pushed. Before
  it: 0.82.0, Round 82 (world generation speed), `8fd02cb1`, tag `round-82`, pushed.
- **Production:** 0.78.0 (the user, 2026-11-16).
- **Last change besides rounds:** the read-only code audit of 2026-11
  ([audit](audit-2026-11/README.md)), whose findings Rounds 81 and 82 fixed or left as
  carry-overs.
- **Next:** no round planned yet; the platform's side of Round 80 (the pin, `emote:cheer`
  for every account, the six donor cloaks), of Round 80.1 (the website reads the new
  `creation` key) and of Round 83 (the website sends `character.delete`; the game's answer
  is in the round's Completion).
- **Other branches:** `town-viewer` (kept on purpose: the three.js town viewer for design
  feedback); `study-dwarf-architecture` and `study-website-screenshots` (unmerged studies
  of 2026-11-11; the second has its own worktree).
- **GUI acceptance is not tracked** (the user, 2026-11-16): an agent proposes a human test
  when it is unsure that something works as planned.

## Open for the user

- The end-to-end account test on the rehearsal realm once the platform side is ready
  (Round 79; [contract §9](technical/web-accounts.md#9-testing)).

## Last five rounds

| Round | Version | Upgrade | Pushed | Completion |
|---|---|---|---|---|
| 83 | 0.83.0 | compatible | no | [Round 83](planning/round83-plan.md#completion-2026-11-18) |
| 82 | 0.82.0 | compatible | yes | [Round 82](planning/round82-plan.md#completion-2026-11-18) |
| 81 | 0.81.0 | compatible | yes | [Round 81](planning/round81-plan.md#completion-2026-11-17) |
| 80 | 0.80.0–0.80.1 | compatible | yes | [Round 80](planning/round80-plan.md#completion-2026-11-16), [80.1](planning/round80.1-plan.md#completion-2026-11-16) |
| 79 | 0.79.0 | compatible | yes | [Round 79](planning/round79-plan.md#completion-2026-11-15) |

Round 77 (a keep-claims map reset) was discarded; the number is not reused. The upgrade
kinds come from `tools/web_data/upgrade.json` and the
[upgrade contract](technical/upgrade-contract.md).

## Where things are

- What shipped: [CHANGELOG](../CHANGELOG.md).
- Open work: [BACKLOG](../BACKLOG.md).
- Goals: [ROADMAP](../ROADMAP.md).
- Round history, production deploys and push claims through Round 79:
  [archive](archive/status-through-round-79.md).
