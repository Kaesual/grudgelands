# The production deploy — starting list (stub)

Written 2026-10-25 by Round 62's lane D. Status: **not planned**. This stub gathers, as facts, what the deploy round
starts from; it holds no plan and decides nothing. The deploy round's coordinator turns it into the plan.

## What moves

- **The production world moves from 0.57.0 to 0.62.0 across one map reset.** origin/main is `69481ed1` (0.57.0,
  pushed 2026-10-23 without its GUI test); 0.58.0 to 0.62.0 are on main and not pushed
  ([STATUS](../STATUS.md)).
- **The declaration** (`tools/web_data/upgrade.json`, [upgrade contract §2](../technical/upgrade-contract.md#2-the-declaration)):
  `map_reset` entries 0.58.0, 0.59.0, 0.60.0, 0.61.0 and 0.62.0 above the pushed version, no `migrate` or
  `new_server` entry above it, `map_reset_pass` 0.50.0 (the pre-reset pass packs the claims' containers,
  [contract §3.5](../technical/upgrade-contract.md#35-the-pre-reset-pass)). Characters keep their items, levels,
  quests and money; position and home claim do not survive the reset
  ([contract §3.2](../technical/upgrade-contract.md#32-map-bound-state)); a quest whose id vanished is dropped
  ([contract §4](../technical/upgrade-contract.md#4-unknown-ids-in-saved-state)).
- **The rounds it carries:** the completions of [Round 58](round58-plan.md#completion-2026-10-24),
  [Round 59](round59-plan.md#completion-2026-10-24), [Round 60](round60-plan.md#completion-2026-10-24),
  [Round 61](round61-plan.md#completion-2026-10-25) and [Round 62](round62-plan.md#completion-2026-10-25), the UI
  modernization (0.60.1, [plan](ui-modernization-plan.md)) and the refreshed dialogs (0.61.1,
  [review](ui-dialog-review.md)).

## The gate

- **The user's joint GUI test of 0.57 to 0.62** (desktop and web build):
  [the checklist](round60-plan.md#gui-checklist-rounds-57-58-59-60-61-62-the-ui-and-0611), items (A) 1–9 and (B)
  1–122. A fix it needs becomes a small FIX lane that merges first.

## Open items the deploy round meets

- **The first-public-release gates** ([BACKLOG](../../BACKLOG.md#first-public-release-gates), open, owned by the
  coordinator preparing the first public release): freeze the game, engine and settings identity and choose the public
  seed; the Z-Image media gate for `menu/icon.png` (ContentDB's AI-generated media flag, the credit, CC0, the source
  record in `menu/LICENSE-media.md`). Checks with judgement, not gates: a native start, generation and restart of the
  candidate as deep as its changes warrant; an **optional** PUC Lua 5.1 crash smoke test; one spot check of resource
  supply and regional access on a few seeds.
- **Names nobody picked yet** (since Round 58, [BACKLOG](../../BACKLOG.md#round-58-carry-overs)): the three cloaks
  Lamp Badge Workcloth, Lamp and Pick Workcloth and Lamplight Mantle, and the achievement "Miner's Guild" I–III with
  its line.
- **A stale STATUS line:** [STATUS](../STATUS.md)'s introduction still says that 0.55.1 runs in production, while
  0.56.1 and 0.57.0 were pushed on 2026-10-23 after it; which version the production world runs is not recorded
  there (this round's plan assumes 0.57.0).
- **Server operations** (since Round 32, [BACKLOG](../../BACKLOG.md#round-32-carry-overs), R4 and R5): media through
  `remote_media` (about 13.8 MB per first join, measured then); at least 4 GB of RAM and swap for the server (2.9–3.3
  GB after the first mapgen, measured then).
- **`check_upgrade.py`** accepts a new entry below the pushed version together with a version bump
  ([BACKLOG](../../BACKLOG.md#round-41-carry-overs); the later rule: a new entry must exceed the pushed version).
