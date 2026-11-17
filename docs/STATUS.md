# Project status

Snapshot of 2026-11-17. This file is replaced, not extended: a round's end adds its row
at the top of the table, drops the oldest row and replaces the lines that changed. Check the live state with `git status -sb`,
`git log --oneline -5` and `git tag -l`. History through Round 79 is in the
[archive](archive/status-through-round-79.md).

## Now

- **Game:** 0.81.0 (`game.conf`), Round 81 (fixes from the 2026-11 code audit,
  compatible), `9ae6a090`, tag `round-81`; not pushed. Before
  it: 0.80.1, Round 80.1 (character-creation pictures for the website), `73b142c4`, tag
  `round-80.1`, pushed 2026-11-16.
- **Production:** 0.78.0 (the user, 2026-11-16).
- **Last change besides rounds:** the read-only code audit of 2026-11
  ([audit](audit-2026-11/README.md)), whose findings Round 81 fixed or left as carry-overs.
- **Next:** world generation speed (the audit's lane 5,
  [Round 81 §7](planning/round81-plan.md#7-orchestration-notes)); the platform's side of
  Round 80 (the pin, `emote:cheer` for every account, the six donor cloaks) and of Round
  80.1 (the website reads the new `creation` key).
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
| 81 | 0.81.0 | compatible | no | [Round 81](planning/round81-plan.md#completion-2026-11-17) |
| 80 | 0.80.0–0.80.1 | compatible | yes | [Round 80](planning/round80-plan.md#completion-2026-11-16), [80.1](planning/round80.1-plan.md#completion-2026-11-16) |
| 79 | 0.79.0 | compatible | yes | [Round 79](planning/round79-plan.md#completion-2026-11-15) |
| 78 | 0.78.0 | compatible | yes | [Round 78](planning/round78-plan.md#completion-2026-11-12) |
| 76 | 0.76.0–0.76.2 | compatible | yes | [Round 76](planning/round76-plan.md#completion-2026-11-11) |

Round 77 (a keep-claims map reset) was discarded; the number is not reused. The upgrade
kinds come from `tools/web_data/upgrade.json` and the
[upgrade contract](technical/upgrade-contract.md).

## Where things are

- What shipped: [CHANGELOG](../CHANGELOG.md).
- Open work: [BACKLOG](../BACKLOG.md).
- Goals: [ROADMAP](../ROADMAP.md).
- Round history, production deploys and push claims through Round 79:
  [archive](archive/status-through-round-79.md).
