# Round 65 — quest lists without locked rows, one acceptance rule, a boxed quest HUD

Planned with the user on 2026-10-27 after a first play session on the
reworked quest system. **Started on the user's "go" the same day; Claude coordinates.**
Version: **0.65.0**. Expected classification: **compatible** (no saved
state, map data or world generation changes; quest definitions are read at
load). Delivery state: [STATUS](../STATUS.md).

## Why

The quest rework (Round 57 ruling 10) made every free quest independent: it
requires nothing but a level, and "a place offers its free quests at once".
The older rule ([quests.md](../design/quests.md#accepted-defaults): "once
its prerequisites pass, a level-locked quest is visible with its required
level") was written for chains, where at most one successor per chain was
grey. Without chains every free quest of a giver passes at once, so every
quest above the player's level is listed grey. The giver dialog also sorts
by quest id, not by status (`Q.npc_quests`, `grug_quests/state.lua`).

Measured on 0.64.0 (390 quests, 136 givers; read-only study 2026-10-27):

- Dawnmere's elder at level 1: 7 rows, 2 acceptable (before Round 57: 2
  rows, both acceptable). All six start elders list 5–6 locked rows.
- First visit at a giver: locked rows outnumber acceptable ones at 66 of
  136 givers; 40 givers list 3 or more locked rows. Worst: the capital
  envoys at 19 (up to 13 rows, 2 acceptable, locked rows up to level 60),
  several front hosts (9–10 locked), the `foreman_t6` role at 11 (8 locked).
- A completionist proxy (at level L every quest below L done): in 194 of
  444 dialogs with something to accept the locked rows are the majority;
  2.15 locked rows per dialog on average.

Acceptance today: `level − min_level` is 1 for 264 quests, 2 for 68, 0 for
57 and 4 for one.

## 1. Lanes and order

| Wave | Lane | Worktree / branch | Result | Depends on |
|---|---|---|---|---|
| 1 | Q — acceptance rule, giver dialog, markers | `r65-quest` | `min_level` derived as `level − 2` everywhere; dialog without locked rows, sorted, one hint line; grey "!" only for "next quest in 1–2 levels" | — |
| 1 | H — boxed quest HUD | `r65-hud` | One box per tracked quest (title, level, objective), sorted by quest level | — |
| 2 | D — delivery documentation | coordinator | Completion, version and upgrade declaration, status owners, GUI checklist | Q and H merged |

Q and H run in parallel. Merge order: **Q, then H** (H merges main into its
branch first when a shared file moved; see §7).

## 2. The user's rulings (2026-10-27)

1. **No locked rows in the giver dialog.** A quest the player may not yet
   accept because of the level is not listed. Instead, **one grey hint
   line** names the level at which this giver's next quests open.
2. **Grey "!" means "next quest in one or two levels".** A giver with
   nothing to complete, accept or continue shows the grey "!" only when its
   next quest opens at most two levels above the player; further away it
   shows no marker. World marker, minimap and map window alike.
3. **One acceptance rule: a quest is accepted from its quest level − 2**
   (at least 1), uniformly, story quests and departures included. The
   authored `min_level` goes; the quest level (`level`, the number the
   quest log shows) is the one source.
4. **Boxed quest HUD.** Each tracked quest is a box with high transparency
   (about 70 %, the box only, never the text). Top row: the title left
   aligned, cut with "..." when too long, and the level right aligned
   (`[lv 31]`). Below it: the objective. The HUD is **sorted by quest
   level**, so players see at once which quests are easy and which harder.
5. From the first feedback, accepted with ruling 1: the dialog **sorts by
   status** (ready, then acceptable, then in progress) instead of by id.

Consequences the lanes carry out and report, not new decisions:

- The main line's chapter gates (41, 46, 53, finale 60;
  [story.md](../design/story.md), [progression.md](../design/progression.md))
  open two levels earlier, as their quest levels minus two.
- Start-zone departures open two levels before their quest level; the one
  quest with a gap of 4 opens two levels later than today; the 57 with gap
  0 open two levels earlier.
- Ruling 4 replaces Round 24 ruling 23 ("the objective only, no title").

**Coordinator defaults** (the user may overrule them; look and feel is
tuned after the first in-game look):

- The level label reads `[Lv 31]` and is coloured with the target frame's
  difficulty gradient (grey, green, yellow, red relative to the player's
  level; `con_gradient` in `grug_mobs/target_frame.lua`), so difficulty
  reads without the sort. It updates on a level change.
- The hint line reads "More quests at level N." It is never selectable.
- Box: the shared UI theme's dark panel colour at 30 % opacity; title in the
  light text colour, objective in today's quest yellow (`0xffe080`).
- Ties in the HUD sort: title, then id. In the dialog: quest level, then
  title, inside each status group; the Story category stays on top.
- When not all boxes fit beside the minimap block and the screen bottom,
  the HUD shows as many as fit and one line "+N more" (the quest log has
  them all). Ten tracked quests stay the maximum.

## 3. Shared conventions

- The quest level is `def.level` everywhere a level is shown: HUD, quest
  log, hint line (as the acceptance level, `level − 2`, since the hint
  names when a quest can be taken).
- The acceptance level has one function in `grug_quests` (registry); the
  validators and `tools/r28_design/ledger.py` compute the same rule and a
  fixture pins both to agree.
- Quests whose prerequisites are unmet stay invisible, in the list, the hint
  and the markers (unchanged rule).
- English UI strings; Help → Quests is updated by lane Q for both lanes'
  player-visible changes (H hands its line to Q's brief via the coordinator
  if Q has not merged; otherwise H edits it after merging main).
- No new engine or client requirement. The web client must render the HUD
  boxes (HUD `image` with alpha), checked in the GUI test.

## 4. Lane goals

### Q — acceptance, dialog, markers

**Acceptance (ruling 3).** `min_level` disappears from the 48 quest files and
from every registration (`grug_mail`'s system quest included); the registry
derives it as `max(1, level − 2)`. A stale `min_level` key in quest data is
an error in both validators, so no second source survives. The validators'
level checks (`E-levels`, `W-level-order`, `W-chain-gate` in
`tools/r28_design/validate.py` and `grug_quests/validate.lua`) are reduced
to what still means something with one number; the lane says what it
removed and why. Fixtures and data-building tools that assert `min_level`
values follow the rule; historic `build_structure.py` generators of earlier
rounds are only touched where a gate runs them. Mob, item and recipe
`min_level` fields (`grug_mobs`, `grug_traders`, `grug_gear`, …) are
unrelated and untouched.

**Dialog (rulings 1 and 5).** The giver dialog lists ready, acceptable and
in-progress quests only, sorted per §2, and below them the hint line with the
lowest acceptance level among this giver's quests that only the level holds
back. A giver that has only the hint for the player still opens its dialog
(today it does not open without rows): list with the hint, a detail pane
saying when to return, no Accept. A giver with neither rows nor hint behaves
as today. The status legend and tooltip of the giver dialog drop "Locked".

**Markers (ruling 2).** The marker value `locked` (and `story_locked`) is set
only when the giver has nothing ready, acceptable or in progress and its
next quest opens at player level + 1 or + 2. Precedence otherwise unchanged.
The memo still refreshes on a level change. Map window and minimap read the
same values and need no own logic.

**Docs.** [quests.md](../design/quests.md) (the dialog, marker and
visibility rules, the chapter-chain note), the level lines of
[story.md](../design/story.md) and [progression.md](../design/progression.md),
Help → Quests ("silver ! = a new quest in one or two levels").

**Report.** The list of quests whose acceptance level moved later; the
chapter gates before and after; `ledger.py` before and after for one Accord
and one Throng track ("free play before quests" per zone) as a comparison,
not a target; the giver statistics above recomputed (rows per first visit).

### H — boxed quest HUD

**Layout (ruling 4).** One box per tracked quest at the existing right-edge
anchor (`hud_layout.anchors.quest_list`): a semi-transparent HUD image as
the box, the title left and `[Lv N]` right in the top row, today's
objective line (`grug_quests.hud_line`: objective, "Return to …", "Travel
to …", a system quest's text) below. All boxes share one width derived from
`hud_layout.side_text_width`; the title is cut by the existing
character-count method with room reserved for the level label. Sorted by
quest level (§2 ties). The space rule and "+N more" per §2; the layout
comments in `hud_layout.lua` (minimap block, location line, "Now playing"
box) are updated with the new heights.

**Colour.** The difficulty gradient moves to one shared function both the
target frame and the HUD call, with the target frame's output unchanged
(fixture). The HUD refresh key includes the player's level.

**Cost.** Elements are created and removed only when the tracked set changes
and updated with `hud_change` only where a value changed; the per-player poll
stays. The report names the element count at ten tracked quests and the
refresh work before and after (a comparison, not a target).

**Docs.** The HUD rules in [quests.md](../design/quests.md#accepted-defaults)
and wherever the HUD layout is owned.

## 5. Rules

- [Round workflow](../process/round-workflow.md) and AGENTS.md apply; lanes
  never push, merge, sync or touch the main checkout.
- Re-check first: every claim of this plan a lane acts on is checked against
  the code at the base commit and reported as confirmed, changed or refuted.
- Fixtures: run only your own fixture plus the fixtures that actually test
  the behaviour you change (not every fixture that loads a changed file);
  the full run once before your report; name what you ran and why.
- Quest texts are not edited; no reward, objective or XP change.
- A case the rulings do not cover is decided by the ruling's reason (a short,
  actionable list; difficulty visible at a glance); otherwise stop that path
  and report.

## 6. Verification

Per lane (round workflow §3): `check_lua.sh` on changed Lua,
`check_fresh_server.py`, the lane fixture (`tools/r65_quest/portable_test.lua`,
`tools/r65_hud/portable_test.lua`), the full fixture run once,
`validate.py --game` with zero errors (lane Q), one smoke boot, the upgrade
classification in the report, independent review.

Lane Q's fixture covers at least: the derived acceptance level (1, 2, 3 and
a level-60 quest); dialog rows at the Dawnmere elder for levels 1, 3 and 7
(no locked rows, status order, hint level); a giver with only future quests
opens with the hint; the marker at next quest L+1, L+2 (grey "!") and L+3
(none); a quest with unmet prerequisites in neither list, hint nor marker.

Lane H's fixture covers the pure layout: sort order and ties, title cut with
the level label kept, the box count and "+N more" for small and large
windows, the element diff on track/untrack, and the shared gradient's
output against the target frame's previous values.

Round end on main: the gates of §3 of the round workflow, `check_upgrade.py`,
sync to Luanti.

### GUI checklist (desktop and web)

1. New character, level 1: the start elder lists two quests, both
   acceptable, and one grey line "More quests at level N."; no grey rows.
2. The cook likewise; both givers show the yellow "!".
3. After accepting everything at level 1: a giver with only future quests
   shows the grey "!" when its next quest is one or two levels away, else
   no marker; its dialog still opens with the hint.
4. The capital envoy at about level 19: a short list, one hint line, no
   level-60 rows.
5. A quest two levels above you can be accepted; three levels above
   cannot (its level appears only in the hint).
6. Dialog order: ready first, then new, then in progress; Story on top.
7. Quest HUD: one box per tracked quest, title left, `[Lv N]` right in the
   difficulty colour, objective below; the box clearly transparent, the
   text fully opaque; readable over snow and bright sky.
8. A long title ends with "..." and never runs into the level label.
9. The HUD is sorted by level; it reorders on accept, abandon, untrack.
10. Ten tracked quests: all boxes fit at full HD; a small window shows
    "+N more" and nothing overlaps the minimap, its location line or the
    "Now playing" box.
11. Level up: level colours change; grey "!" markers appear and vanish.
12. Minimap and map window show the same markers as above the givers.
13. Help → Quests describes the silver "!" correctly.

## 7. Orchestration notes

- **Start state:** main `91c128cd` (0.64.0, local, not pushed); GUI
  acceptance of 0.57–0.64 is pending and independent of this round.
- **Routing:** the user decides per session; latest: Claude coordinates,
  Opus implements and reviews. Every lane gets an independent review.
- **Process budget:** at most eight Lua processes through the shared queue;
  never the user's Luanti folder; no wall-clock kills.
- **Shared files:** `docs/design/quests.md` (Q: giver, marker, acceptance
  sections; H: the HUD default), `mods/PLAYER/grug_inventory/help.lua`
  (Q). Q merges first; H merges main into `r65-hud` before its review when
  either file moved.
- **Lane D:** version 0.65.0 in `game.conf` and `tools/web_data/upgrade.json`
  (compatible), the completion section with the lanes' numbers, STATUS,
  the AGENTS pointer, BACKLOG, README, CHANGELOG.
- **Decided during the round:** the coordinator defaults of §2 after the
  user's first in-game look (colours, transparency, box count, wording).
