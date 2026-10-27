# Round 65 — quest lists without locked rows, one acceptance rule, a boxed quest HUD

Planned with the user on 2026-10-27 after a first play session on the
reworked quest system. **Started on the user's "go" the same day; Claude coordinates.**
**Complete on 2026-10-27:** both lanes reviewed and merged locally, not
pushed; GUI test pending; one user question open
([completion](#completion-2026-10-27)).
Version: **0.65.0**. Classification: **compatible** (no saved
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
  open at their quest levels minus two: **40, 45, 53, 58** (corrected in
  the [completion](#deviations-from-the-plan); this bullet first said "two
  levels earlier" throughout, but the gates' old acceptance gaps were 1, 1,
  2 and 0).
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

Refined by lane D from both lanes' excerpts and the reviewers' notes. Each
item on the desktop client and on the web client. The marker the plan calls
the grey "!" is the **silver "!"** in game (marker value `locked`).

1. New character, level 1: the start elder lists two quests, both
   acceptable, and below them one grey line "More quests at level 3.";
   no grey rows; the hint line cannot be selected.
2. The cook likewise (two quests and the hint); both givers show the
   yellow "!".
3. A giver with nothing to accept, hand in or continue (accepted quests it
   takes back still list as in progress and show the silver "?") shows the
   silver "!" when its next quest opens one or two levels above you, e.g.
   the elder after you handed in its two level-1 quests while still below
   level 3; a giver whose next quest is three or more levels away shows no
   marker. Such a giver still opens its dialog: the hint line, a detail pane
   "Come back later" with "<giver> has more quests for you at level N.", no
   Accept.
4. When the last row of a dialog goes (handed in, or accepted with its
   turn-in at another NPC), the dialog redraws as the hint-only dialog of
   item 3 (checked by hand in review; no fixture pins it).
5. The capital envoy at about level 17–19: a short list, one hint line, no
   level-60 rows.
6. A quest two levels above you can be accepted (level 3 accepts a
   level-5 quest); three levels above cannot (a level-6 quest is not
   listed; at level 3 the hint reads "More quests at level 4.", its
   acceptance level).
7. Dialog order: ready first, then new, then in progress; Story on top;
   inside a group by quest level, then title.
8. Quest HUD: one box per tracked quest, title left, `[Lv N]` right in the
   difficulty colour (grey at ten or more levels below, green, yellow at
   your level, red from five above), the objective below in quest yellow;
   the box clearly transparent, the text fully opaque; readable over snow
   and bright sky.
9. A long title ends with "..." well before the level label.
10. The HUD is sorted by level; it reorders on accept, abandon, untrack.
11. Ten tracked quests: all ten boxes at 1920×1080; at 1280×720 seven boxes
    and "+3 more". Nothing overlaps the minimap, its location line, the
    "Now playing" box, the XP label, the status icons or the feed.
12. "Now playing" (entering a capital with ten tracked at 1280×720): one box
    drops at once (six and "+4 more"), without a moment of overlap, and
    comes back when the music box goes.
13. Web client: does it report its window size? If it does, the box count
    follows the browser window as on desktop; if not, the HUD falls back to
    the 1280×720 layout (seven boxes and "+3 more" with ten tracked). Note
    which. The boxes (a HUD image with alpha) render transparent there too.
14. GUI scale 1.5 in a 1280×720 window shows 0–1 box and "+N more" (kept
    on purpose until this look); say whether that is acceptable.
15. Level up: the level labels change colour at once; silver "!" markers
    appear two levels before a giver's next quest and vanish once it is
    acceptable (then yellow).
16. Minimap and map window show the same markers as above the givers.
17. Help → Quests: silver "!" = a new quest in one or two levels; you can
    accept a quest from two levels below its level; the grey hint line; up
    to ten tracked on screen as boxes sorted by quest level (a small window
    shows "+N more").

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

## Completion (2026-10-27)

Both code lanes are merged on main, each independently reviewed (Opus):
QUEST MERGE without findings; HUD MERGE with one Low finding, fixed in a
fix round that the delta review passed (MERGE). This lane D (the version,
the declaration, this section, the GUI checklist, the status owners) follows
on main `6a9db45a`. **0.65.0 is compatible:** quest definitions are read at
load, the saved quest state (`grug_quests:state`) is read and written as
before, nothing new is stored; an active quest whose acceptance level moved
later stays active (only Accept is gated). No reset, no migration step.
**Push:** not pushed; production is still 0.55.1. **GUI test:** pending; it
joins the joint GUI test of 0.57–0.64 ([checklist](#gui-checklist-desktop-and-web)).
**Sync:** by the coordinator after each merge.

### Lanes

Main's first-parent commits from the plan `5581ed98` (lane tip in brackets):

| Lane | Commit | What | Review |
|---|---|---|---|
| QUEST | `c0be940a` (`ac153f84`; `60b0f7fd`, `508e8c95`, `77d6383e`) | `grug_quests.acceptance_level(level)` = max(1, level − 2) in the registry derives `def.min_level` and refuses a given one; 390 `min_level` keys removed from 45 of the 48 quest files (the other three list no quests) and from `grug_mail`'s system quest; both validators report a stale key as `E-levels`, `W-level-order` and `W-chain-gate` removed; `r28common.acceptance_level`, `ledger.py` on the same rule. `npc_quests` returns ready, acceptable and in-progress rows sorted by status, level, title plus the hint level; the dialog's grey hint line, the hint-only dialog ("Come back later", no Accept), legend and tooltip without "Locked". `marker_states`: `locked` only without rows and with the next quest at most `Q.SOON_LEVELS` (2) above. Help → Quests; the generators r59–r62 strip `min_level`; quests.md, story.md, progression.md, module-guide.md; fixture `tools/r65_quest` | MERGE, no findings |
| HUD | `6a9db45a` (`b90d3bd9`; `5917817c`, `45e4928b`, `48eff62c`, `d3cfac92`, main merged in `87ee37c2`) | `grug_xp.con_gradient` / `con_color` shared by the target frame (colours unchanged) and the HUD; `hud_layout.quest_boxes(window, count, playing)`; `grug_quests/hud.lua` draws one box per tracked quest (a `[fill` image at 30 % opacity, title, `[Lv N]`, objective; four elements per box, diffed `hud_change`), sorted by level, title, id; "+N more"; redraw on level change; `grug_map.minimap.now_playing` getter. Fix round: the `r27_minimap` probe, `set_now_playing` calls `grug_quests.hud_refresh` when the box comes or goes, the Help line. Fixture `tools/r65_hud`; eleven fixtures fitted to the boxed tracker | MERGE (Low: the r27 probe called the removed `hud_text`); fix round: delta review MERGE |
| D | this section | version 0.65.0, the declaration, this completion, the GUI checklist, STATUS, AGENTS, BACKLOG, README, CHANGELOG, the `world_map.md` gloss | independent review |

Main has **286** portable fixtures (2 new: `r65_quest`, `r65_hud`). `mods/`
against 0.64.0 (measured, `git diff 91c128cd 6a9db45a -- mods`): 57 files,
+409 −509 lines: 45 quest files and twelve Lua files.

### Decisions during the round

**The user:** the rulings of §2 (1–5), unchanged.

**The coordinator** (answers to lane questions and reviews; each built as
stated):

- HUD Q1: narrow windows at GUI 1.5 keep "+N more" (0–1 box, nothing
  overlaps) until the user's first look (checklist item 14).
- HUD Q2: the level label stays grey at ten or more levels below (the mob
  gray line), read as "trivial".
- HUD Q3: the Help line on the boxed HUD was written by lane HUD after
  QUEST had merged (its fix round).
- QUEST Q2: Potion IV/V reward quests (for example `border_meal` at 32,
  `front_potatoes` at 42) open one level before the potion is usable;
  accepted.
- QUEST Q3: `archshadow_front_03` (level 48) opens at 46, one level after
  chapter 2's gate 45, which still follows it in the chain; accepted.
- The HUD review's backlog note became a fix: `set_now_playing` triggers a
  quest HUD refresh, so a box drops at once when "Now playing" appears
  instead of up to 0.5 s later.

**Open user question** (the coordinator updates this after the answer):

- **QUEST Q1, PvP ruling 15** ("PvP quests from level 40", Round 31): four
  level-41 fortress quests (both factions' entry calls and steel supplies)
  are now accepted at 39. **Recommended:** accept (ruling 3 is uniform).
  **Alternative:** raise them to level 42 (a data change in a later lane;
  `quests.md` and `progression.md` state the opening at 39 and would change
  with it).

### Deviations from the plan

- **Chapter gates 40 / 45 / 53 / 58**, not "two levels earlier" throughout
  (the §2 consequence first implied 39 / 44 / 51 / 58; corrected there): the
  gates' quest levels are 42, 47, 55 and 60 and the old acceptance gaps were
  1, 1, 2 and 0. `accord_main_roll` and `throng_main_06` (level 55) stay at
  53.
- **`W-level-order` and `W-chain-gate` removed**, not reduced (§4 Q): with
  one number they compared nothing; a quest behind an unmet prerequisite
  shows nothing, so no wrong gate can show. `r36_qa` / `r36_qt` dropped
  their prerequisite-order checks with them.
- **Outside the lane lists:** HUD added `grug_map.minimap.now_playing` and,
  in the fix round, the call from `set_now_playing` to the exported
  `grug_quests.hud_refresh` (`mod-map.md` names both); `hud_layout`'s unused
  `alignment` went.
- **The quest description** still reads "Minimum level: N"; N is now
  level − 2.

### Numbers worth keeping

From the lanes' reports (measured there); the acceptance moves re-measured
by this lane over the quest files at `91c128cd`.

- **Acceptance moves** (390 quests): **1 later** (`camp_site_raid` 36 → 38),
  **317 earlier**, 72 unchanged.
- **Giver first visit** (136 givers): rows 632 (mean 4.65, max 13) → **260**
  (1.91, max 6); acceptable 290 → 260 (the first level is lower now); 94
  givers show a hint. Dawnmere's elder: 7 rows / 2 acceptable → 2 rows and
  "More quests at level 3."
- **Silver "!" for a completionist** (givers with the marker):

  | Level | 1 | 10 | 20 | 30 | 40 | 50 |
  |---|---:|---:|---:|---:|---:|---:|
  | before | 118 | 112 | 67 | 42 | 30 | 20 |
  | after | **0** | **20** | **21** | **8** | **7** | **6** |

- **Ledger, solo, free play before quests** (`ledger.py`; a comparison,
  not a target): human 83 610 → **74 297** XP, orc 89 614 → **79 869**.
  Per zone, for example Dawnmere 654 → 139, Goldmead 3 238 → 1 877,
  Highcourt 15 143 → 12 904, Ashenward contested 12 655 → 14 473 (arrives
  a level earlier); Sunscar 128 → 0, Redtusk 4 291 → 2 985, Gor Drazhak
  14 319 → 10 595.
- **HUD boxes shown with ten tracked** (no music / with "Now playing"; box
  48 px at GUI 1, 72 at 1.5, gap 4 px, width 350 px = 38 characters, title
  room 30 characters with a two-digit label; 26 of 390 titles are cut):

  | Window | Boxes |
  |---|---|
  | 1920×1080 | 10 / 10 |
  | 1280×720 | 7 / 6 |
  | 1920×1080, GUI 1.5 | 8 / 7 |
  | 1280×720, GUI 1.5 | 1 / 0 |
  | 1024×768 | 4 / 3 |
  | 2560×1440, HUD and GUI 1.5 | 10 / 10 |

- **HUD elements** at ten tracked: **40** (+1 for "+N more"); before 1.
  Refresh work (stub engine, a comparison): the idle poll adds one
  `string.format` and a table lookup (0.06 → 0.16 µs); an objective change
  stays one `hud_change` (3.8 → 8.5 µs); join with ten 1 add + 1 change →
  40 adds; tracking a fourth 1 change → 4 adds + 20 changes; untracking
  one → 4 removes + 24 changes; a level-up at most one `number` change per
  box. No new globalstep.

### Checks

- QUEST: full run 285/0; `validate.py --game` 0 errors / 17 warnings
  (unchanged); validator and ledger self-tests, six `build_structure.py
  --check` (0 differ), `quest_kinds.py --check`, `income.py --check`, smoke
  boot PASS. Review: r65_quest (80 checks) and 18 behaviour fixtures PASS.
- HUD: full run after merging main 286/0; smoke boot PASS; captures
  `r65/shots/hud`. Reviews: 17 fixtures (r65_hud 1 728 checks) and the
  delta's 3 PASS; the space rule swept over 17 280 window cases.
- Main: `check_fresh_server.py` and `check_upgrade.py` PASS after each
  merge. This lane: `check_upgrade.py`, `check_fresh_server.py`, `r37_dc`
  and `r43_gs` (they pin the version, the changelog, the README and
  CHANGELOG links and the declaration), the link check of the touched
  documents.
