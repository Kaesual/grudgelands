# Round 57 — the crafting window, the quest foundation and the new start zones (0.57.0)

Coordinator: Claude, 2026-10-23. Status: **running** (the user's go 2026-10-23). The plan review (a fresh Opus, 2026-10-23) is folded in:
three blockers (the chain rules against unreworked files, zone-bound objectives in shared quests, the
`*_departure` ids) and the important findings.

The source is the discussion with the user on 2026-10-22 ([Round 56 plan §8](round56-plan.md#8-decided-for-later-rounds))
and 2026-10-23, which ordered the next rounds:

- **Round 57 (this plan, no map reset):**
  - the crafting window as decided;
  - the quest system's new foundation (shared quests, choice rewards, story marking, completion text, the
    free-play rules);
  - the six start zones rebuilt on it as the pilot;
  - the draft of the story arc;
  - in parallel, the art for Round 58.
- **Round 58 (the one map reset):** the Miner's Guild (mining camps, lifts, reputation, consumables, guild quests)
  and the town fixes ([§8](#8-decided-for-round-58)).
- **Round 59 and later:** the story arc and the quest rework of levels 11–60; then unique items
  ([§9](#9-later)).

Start state: main `2b4a3228` (0.56.0 + 0.56.1), GUI-accepted and pushed on 2026-10-23. The GUI test's two small
findings are lane FIX56.

## 1. Lanes and waves

| Wave | Lane | Who | Goal (one line) | Waits for |
|---|---|---|---|---|
| 0 | FIX56 | Opus | The 0.56 GUI findings: no-fly columns in bays; the chin strip's underside | the user's go |
| 0 | CHAINDEPTH | Opus | A generated report of the recipe chain depth per recipe | the user's go |
| 0 | STORYARC | Astra | The story arc draft for both factions, the two Miner's Guilds as political actors, choices for the user | the user's go |
| 0 | GUILDART | Astra | Art for Round 58: three guild cloaks (rank 10 with wings), 12 consumable icons, the Miner's Remains block | the user's go |
| 1 | CRAFT | Opus | The crafting queue (crafts, enchants, upgrades), layout C, favourites, recursive Basic unlocks | the user's go |
| 1 | DETAILS | Opus | The recipe details pages with their generated ingredient sources | the user's go (integrates after CRAFT merged) |
| 1 | QSYS | Opus | Shared quests with several givers and text variants, choice rewards, story marking, completion text, the free-play validator rules, `repeatable` removed | the user's go |
| 1 | DYES | Opus | Every dye reachable: sources for White and Yellow Dye (added during the round, ruling 29) | ALLOY merged |
| 1 | VENDORMAT | Opus | No vendor sells leather, cloth, ores or bars (added during the round, ruling 28) | the user's go |
| 1 | ALLOY | Opus | Flat alloy and wood chains, Steel Bars craftable (added during the round, rulings 25–27) | CHAINDEPTH merged |
| 2 | STARTQUESTS | Opus | The six start zones rebuilt on QSYS: structure, data and the reward pattern; placeholder texts | QSYS merged |
| 3 | STARTTEXT | Astra | The texts of the new start-zone quests | STARTQUESTS' structure accepted by the user |
| 3 | TEXTREVIEW | Opus | The text review with a suggestion page; the user picks | STARTTEXT |
| 4 | D | Opus | Docs, CHANGELOG, version 0.57.0, STATUS, GUI checklist | everything else |

Every non-trivial code lane gets an independent Opus review and a delta review for every logic fix. STORYARC is a
report for the user, read by an Opus reviewer with a suggestion page (as for quest texts). GUILDART ends on a
pick page; nothing of it ships before Round 58.

## 2. The user's rulings

### Crafting window (2026-10-22, Round 56 §8; queue state 2026-10-23)

1. **Layout C:**
   - the right column goes and the middle box widens;
   - the Craft/Queue button sits right-aligned next to "Max";
   - the progress bar sits at the bottom with a small stop button;
   - exactly one line below the bar names the current job ("Aspen Wood Planks ×40"). It shows **no countdown**:
     the bar is a client animation and the formspec is not refreshed every second;
   - "View Queue [N]" sits at the bottom right;
   - the output slots show only while filled;
   - the big button reads "Craft ×N" while nothing runs and "Queue ×N" while a job runs.
2. The bar, the stop button and "View Queue" stay when the player picks another recipe, and on the details page.
   [Wireframes](https://claude.ai/artifact/DPCAU1Ynp26U52cNSNHLcN) (private).
3. **Queue:**
   - crafts, enchants and upgrades are alike as queue items;
   - ingredients (and an enchant's target item) are taken when queued, and cancelling an entry returns them;
   - **no reordering**;
   - at most 5 entries;
   - **no automatic crafting of missing ingredients**.
4. **The queue keeps today's offline behaviour** (2026-10-23): today's single job runs on the wall clock and
   finishes while the player is offline (it catches up at login). The queue does the same: its entries run one
   after the other, offline too, so nothing gets worse than today.
5. **Recipe details:**
   - a page per recipe, enchant and upgrade;
   - one box per ingredient, with its source generated from the data (recipe, vendors, drops with level bands,
     herb zones);
   - item tooltips;
   - navigation only on this page ("Open ▸", "◂ Back");
   - a "select this recipe" button only for recipes the player knows;
   - group ingredients open a page of their kinds.
6. **Unlocks:** unlocking a profession tier also unlocks, recursively, every Basic recipe that the tier's recipes
   need (Thread, then Patch Bolt).
7. **Favourites:**
   - a "Favorites only" checkbox next to "Craftable only" (both on shows craftable favourites only);
   - a bookmark icon at the top right of the recipe box (not on the details page);
   - saved in player meta.
8. **First step:** an automatic report of the recipe chain depth per recipe, to see where to simplify.

### Quests (2026-10-23)

9. **As few quests as possible without losing depth;** fewer quests are less upkeep. A task that is the same in
   several places is **one quest**: one id, several givers (and turn-in NPCs), the same objectives, an optional
   text per giver (per race). Completing it once completes it for that player everywhere; no giver offers it
   again.
10. **Guided and free play:**
    - **Story quests** guide the player from A to B and may form chains.
    - **Every other quest is free play:** players explore their level band freely and take quests where they
      find them. A free quest requires nothing but a level. Free play is the main mode; guidance is mostly for
      story quests.
    - A free quest may have **at most one follow-up, and rarely**. Examples:
      - the zone's last quest leads to the next zone's quest giver, as today;
      - the Miner's Guild's small storyline (Round 58).
    - A place offers its free quests **at once**.
11. **No repeatable quests.** Every quest is done exactly once. The `repeatable` switch is removed from the code,
    the loader, the validator, the map and the docs.
12. **Kill counts follow the spawn phase.** A day lasts 15 real minutes and a night 5. A target that spawns only at
    night asks roughly a third of a comparable day target, so one normal night is enough while the player does
    the day quests. The first boar and rat quests are offered together, at once.
13. **Story quests are marked:**
    - their own marker at the giver;
    - a "Story" category with an accent in the quest list;
    - the status (available, active, ready, locked) stays visible on its own;
    - a giver with mixed quests still shows a ready side quest.
14. **Completion text:** a quest may carry a short closing paragraph, shown at the turn-in.
15. **Choice rewards:**
    - A quest may offer a choice of rewards. The offer dialog shows the choices without a click.
    - At the turn-in they are selectable icons or buttons with the item's tooltip, above the Complete button.
      Complete refuses until one is picked.
    - Every player sees the same choice and must be clever enough to pick what fits their class.
    - Equipment rewards carry author-fixed enchants, never random ones, and their item level is the quest's
      reward level.
16. **Equipment choices** offer one item per armor class: cloth, leather, metal (or one weapon per weapon line).
    Priest and Mage share their items, so a choice has three entries.
17. **Reward budget per zone** (capitals excepted, since story lines meet there):
    - at most **two equipment rewards with one enchant** and **one with two enchants**, spread over the zone at
      different item levels;
    - other quests may offer other choices: raw materials for professions (cloth pieces, leather, metal bars),
      cooking ingredients, healing or mana potions;
    - many quests give only XP and a little copper;
    - a reward is never the requested item (Round 56 §8).

    The point is that players must decide on a reward, and that quests feel worth doing.

    The validator checks the budget.
18. **The start zones' pattern** (for the start zones, not a rule for every zone):
    - an early quest: 2 small healing or 2 small mana potions;
    - a level-5 quest: an armor piece of item level 5 with one enchant (cloth, leather or metal);
    - a level-7 or 8 quest: another slot, one enchant, the same choice;
    - the zone's final quest (level 9 or 10): a weapon of item level 9–10 with prefix **and** suffix (yellow), one
      per weapon line.

    The start zones are where the player is rewarded with a "mighty item" at the end.
19. **Pilot scope:** this round rebuilds the six start zones (levels 1–10). The story arc is only drafted (both
    factions, the Miner's Guilds as an essential political part of each faction) and built in Round 59.
20. **Migration is a nice-to-have.** The new concept is not bound by old quest ids. Dropping old ids and making
    new quests the players have not done is fine. The minimum is that saved state stays readable (unknown quest
    ids are already dropped, upgrade contract §4); old → new mapping only where it comes free.
21. **"Quests keep their ids" is removed as a rule** (not only for this rework): quest ids change only for a good
    reason anyway. Items, achievements and waypoints keep theirs; unknown ids still never crash.

### Recipes (2026-10-23, during the round, after the CHAINDEPTH report)

25. **Alloys T4–T6 come straight from Steel:** Silversteel = Steel + Silver (as today), Embersteel = Steel +
    Emberglass, Abyssal Steel = Steel + Abyssal Crystal. The chain no longer runs through the tier below.
26. **The graded woods follow the same rule, with their item ids kept:** each grade is made from planks plus the
    tier's ingredient instead of the grade below; Heartwood (T6) = planks + Abyssal Crystal.
27. **Steel Bars (`xpanes:bar_flat`) become craftable from Steel Bars.** White and Yellow Dye get a source only if
    something reachable needs them. The Water Bucket stays as it is. Leather and cloth keep their recipes (their
    grades drop from the tier's own beasts already).
28. **No vendor sells leather, cloth, ores or metal bars** (Leather, Light Leather, Linen Scrap and the Bronze Bar
    leave every shelf). Thread stays as a job supply, and White and Brown Wool stay at the tailor (bed decor).
    Buy-back follows the general price rule: the Bronze Bar now pays its inputs (2c instead of 1c from its old
    shelf price; the Bronze Block and four bronze goods move with it; coordinator decision).
29. **Every dye becomes reachable** (2026-10-23), from existing items only: Bone → White, Sunleaf → Yellow, Apple →
    Red, Marshbloom → Cyan (after Blueberries → Violet); every other dye follows from the mixes.

### Process

22. **GUILDART runs in parallel** to this round; the picked art lands with Round 58's code (nothing unpicked ships,
    nothing picked ships without its code).

### GUI findings of 0.56 (2026-10-23)

23. **Bays are not ocean.** In places, bays still have no-fly columns. An example in the local world "test" is
    the area around (−609, 9, −2285): the minimap names it "Goldmead Vale", but the ocean no-fly rule applies
    there. Bays inherit their zone's flight rule (`mounts.md` §4.1); only the declared outer bay-mouth caps are
    deep ocean.
24. **The chin strip's underside.** On the head pieces whose chin strip was opened (cloth T1–T6, leather T1–T5;
    Round 56 ruling 17), only the strip facing the front was removed. Texture is still visible **under the
    chin**. It goes there too, only on those head pieces.

## 3. Shared conventions

- **Upgrade classification:** the round aims at **compatible**.
  - CRAFT keeps the running job under `grug_jobs:job` in today's format and puts only the waiting entries
    under a new key, so old saves read unchanged.
  - STARTQUESTS gives every quest whose objectives change a **new id**. A changed quest under its old id would
    be a migration (upgrade contract §1). Old ids are dropped (§4). The 92 start quests have no quest drops or
    quest-only items (plan review), so nothing players hold needs a step.
  - **New givers use free quest sockets** of the start towns. `check_upgrade.py` checks what the start towns
    build, sockets included, and a new socket would be a map reset.
  - The round's declaration follows in D.
- **The rework flag:** QSYS's new chain and follow-up rules apply only to quest files marked as reworked (this
  round the six start zones). The 370 shipped quests with `requires` stay valid until Round 59 reworks them; the
  loader stops the server on any finding, so the rules must not hit unreworked files.
- **The six `*_departure` ids stay:** ten quests in the level-11 zones (Copperfell, Goldmead, Starbough,
  Mournfen, Raincall, Redtusk) require them, and repointing them would lock existing characters out of their
  level-11 zone. They are the start zones' handover follow-ups (ruling 10).
- **Quest texts:**
  - places and directions only as placeholders;
  - items by name, never an item's tooltip text;
  - no existing game named;
  - the faction names are The Accord and The Throng.
- **Fixtures:** `tools/r57_<lane>/portable_test.lua` for new logic. A fixture asserting a retired rule (the
  repeatable cooldown, the single giver, the boar→rat chain) changes in the same lane, and the report names it.
- **Design docs are the spec:** CRAFT and DETAILS own `items_crafting.md` and `professions.md` (merged one after
  the other); QSYS owns `quests.md`; STARTQUESTS owns the start-zone sections; D owns STATUS, CHANGELOG, the
  version, ROADMAP and BACKLOG.

## 4. Lane goals (briefs add file facts)

**FIX56.** Rulings 23 and 24.
- **Bays:**
  - `grug_mounts.flight_rule` lets only `land` and `planned_water` columns fly, and every other water class
    counts as "ocean". The lane finds which class the bay columns at the example get (bay water, the coastal
    belt along a bay's shore, or the mouth cut), and fixes the rule or the class so that bay water inside the
    mainland footprint follows its zone. The outer bay-mouth caps and the open sea stay no-fly.
  - The minimap's no-fly overlay (`grug_map/base.lua` `flight_overlay`) shows the same.
  - A fixture on the example column and on one column each of the open sea and a mouth cap.
  - The water classification is analytic in x/z. If the example depends on the seed, the coordinator gives the
    lane the "test" world's seed; the lane never opens the user's Luanti folder.
- **Chin strip:**
  - The helm sheet's bottom face, under the chin, becomes transparent where it continues the open strip, on the
    same tiers; leather T6 and metal stay as they are.
  - The hood's polygon faces are checked the same way.
  - The texture tools are the precedent: `tools/r54_armor` and `tools/r54_art`; `check.py` allows the new open
    texels on exactly those sheets (`armor-format.md` §4).
  - Headless shots from below and from the front at a low angle, cloth and leather T1 and T6.
  - Only textures and the check change, so the change is compatible.

**CHAINDEPTH.** A tool (`tools/r57_chains/`) that reads the registered recipes and prints per recipe:
- the longest chain of crafted ingredients down to raw materials;
- the number of distinct crafted steps;
- the Basic recipes on the way.

It sorts the deepest first and writes a text report and a small HTML page.
- It includes the furnace and smelting recipes, otherwise every metal chain stops at bars.
- It breaks recipe cycles (block ↔ bar, sand ↔ sandstone, stairs) and reports them.

It is the basis of the recursive Basic unlock (ruling 6) and of later simplification. No recipe changes this
round.

**STORYARC (Astra, report).** A draft of the story arc for both factions from level 1 to the existing front story
at level 41:
- the inputs: the QUESTIDEAS report's strategy A + B, the [story bible](round36/story-bible.md),
  [story.md](../design/story.md), the zones and capitals;
- the Miner's Guild of each faction as a political actor: its name, its interests, its people in the capitals and
  camps, its tie to the supply of the front;
- the arc's chapters by level band, the capital entry at level 15–20, and where the start zones hand over;
- two or three alternatives where a real choice exists, for the user to pick.

The report is in German and private (orchestration folder). An Opus reviewer reads it against the story bible
and the rulings and adds a suggestion page. Nothing enters the repository before the user's pick.

**GUILDART (Astra).** Design goals, every element and the technical rules, no per-step permission lists:
- three cloak textures for the guild achievement (ranks 3, 6, 10), rank 10 with wings in the existing
  `wings` format (the Supporter cloak is the precedent);
- 12 icons for the consumables (Ore Sense and Treasure Hunt, T1–T6), readable at 32 and 16 px, the tier
  recognisable;
- the Miner's Remains block (bones and remains of a miner in rock).

The icon style rules hold (simple, few details). A pick page for the user; the picks wait in the orchestration
folder for Round 58.

**CRAFT.** Rulings 1–4, 6, 7.
- **The job becomes a queue** of at most 5 entries:
  - the running entry stays under `grug_jobs:job` in today's format; the waiting entries go under a new key;
  - crafts, enchants and upgrades share the entry format;
  - inputs are taken at queueing and returned on cancel or stop.
- **Refunds:** today a cancel refuses when the refund does not fit, and the overflow `grug_craft_out` has 4
  slots. The lane defines the path for five entries; nothing is ever lost.
  - *Default:* a cancel that does not fit refuses with a message, as today.
- **Offline** (ruling 4): the queue runs on the wall clock like today's job, and the login catch-up works off
  every entry that would have finished.
  - Therefore the station, profession, input and target checks run **when an entry is queued**. A waiting entry
    starts without the player standing at the station.
  - The lane defines where the outputs go when the inventory is full at completion, offline included, so that
    the outputs of all five entries are never lost (for example an overflow that holds them).
- **Layout C** on the existing `sfinv:crafting` page:
  - the bar stays a client animation;
  - the page refreshes on events as today;
  - `operation_box.lua` (enchants and upgrades) is part of it.
- **Favourites and the "Favorites only" filter.**
- **The recursive Basic unlock** at a tier unlock. Basic unlocks have no store of their own today (they follow
  "held once"), so this needs a new store plus a catch-up at join. It uses CHAINDEPTH's walk if it has merged,
  else its own.
- CRAFT does not change `grug_quality`; QSYS owns that file this round.

**DETAILS.** Ruling 5.
- An ingredient source index, built once at load from the registered data. A pure module with its own fixture.
  The sources:
  - recipes, smelting and furnaces;
  - vendor stock;
  - mob drops with their level bands (the bands sit in a local table today and need a public accessor);
  - herb zones, mining (ores and gems by tier), trees, fishing and farming.
- Item tooltips use QSYS's shared tooltip-text helper in `grug_quality`: one helper, one owner (QSYS).
- The details page (recipes, enchants, upgrades; group pages), navigation only on the page.
- It integrates into CRAFT's layout after CRAFT merged; main is merged into the lane before its review.

**QSYS.** Rulings 9–17, 21.
- **Shared quests across zones.** Today's kill objectives carry a zone-bound `area`, and their target names
  resolve per zone file: the start zones' boars and rats are Barley, Pine and Scrub Piglets, and Barn, Dust and
  Moss Rats. So a shared quest has **one variant per giver zone**:
  - its area, targets and map target, and optionally its text;
  - the counts and rewards are the quest's own, the same for every variant;
  - the active state stores the variant the player took;
  - QSYS decides where shared quests live in the data (their own file or the first zone's file) and writes it
    into `quests.md`.
- **Several givers and turn-in NPCs per quest:**
  - a list of NPC ids, and, for Round 58, a giver **role** with a faction filter (every NPC of the role offers
    and takes the quest);
  - an optional text per giver or race, with the quest's base text as the fallback;
  - the "one hub per giver" rule changes, so a shared quest may be given in several hubs;
  - shared start quests span both factions, so the turn-in faction check works per giver.
- **Quests without a dialog stay possible:** `mailbox_visit` is turned in without one, so a quest with no choice
  keeps that path.
- **The rework flag** (§3): a file-level marker that switches the new chain rules on.
- **The Python side mirrors the Lua rules:**
  - `tools/r28_design/validate.py`: today one giver, at most 2 givers per hub, and `repeatable`;
  - `ledger.py`, which routes per zone file, `income.py` and the other quest tools;
  - the QUESTMAP model `tools/r56_questmap`;
  - the Round 28 zone atlas with each NPC's quest ids.
- **Fixtures to change:** the fixtures asserting `repeatable` (about 8) and those asserting start-quest ids (3),
  named in the brief.
- **Hidden work the plan review found:**
  - **A giver must be a hub giver of its own zone file** (`E-giver-not-hub`, in Lua and in Python), and the
    title and text placeholders resolve from the giver's position. The variants per giver zone carry both.
  - **The consumers of "one giver":** the turn-in and accept checks in `npc.lua`, the HUD's and the quest
    box's "Return to <NPC>", the map's hand-in mark, the QUESTMAP model and page, the zone atlas, and the
    fixtures that read `q.giver`.
  - **Markers:** each NPC keeps one status string, memoised (`state.lua` `marker_states`). The story dimension
    reaches the marker entity, the map and minimap textures and the quest box, which has no categories today.
  - **Rewards:**
    - rewards are written with `set_stack`, past `grug_inventory.give`, so a reward weapon would miss its
      tooltip initialisation;
    - the dialog (`size[16,9.4]`) lists rewards as plain text today;
    - `grug_quests` gains a dependency on `grug_quality`, which publishes `grug_items` (no cycle).
  - **Name checks and counts:** `tools/r38_names/guarantee.py` checks quest texts against the counted names, and
    `check_rules` R3 is keyed to `*_hunt_01`. `r46_xp` asserts 485 quests. About 28 tools load the shipped quest
    data; the brief lists them and the lane re-runs those its change touches.
- **Choice rewards** in the data. The offer preview; the turn-in pick above Complete with the item tooltips (our
  own tooltip text, since item buttons do not show meta); Complete refuses without a pick. The preflight checks
  the picked reward.
- **Equipment rewards with fixed enchants:** a public function in `grug_quality` that makes a stack with given
  affixes at a given item level (the local `store_affixes` and `write_item_level_meta` are the start). The
  loader and validator pass the reward's affixes through.
- **The story category:** marker, list category and accent, status shown on its own.
- **The completion text** at the turn-in.
- **Validator rules:**
  - only story quests chain;
  - a free quest has at most one follow-up;
  - the zone's equipment reward budget;
  - a warning when a night-only target's count is not about a third of the zone's comparable day counts.
- **`repeatable` removed** everywhere (the list in the brief).
- **The stable-id rule** loses "quests" everywhere it is stated. In `upgrade-contract.md` §1, the row that
  calls a restructured quest a migration says instead that a reworked quest takes a new id. The other places:
  AGENTS.md, the
  review template `review-common.md`, `docs/design/README.md` and the `check_fresh_server.py` docstring. "Unknown
  ids never crash" (contract §4) stays.
- **Merge order:** QSYS merges before DETAILS, which uses its tooltip helper.

**STARTQUESTS.** Rulings 9–12, 15–18 in the six start zones.
- **Shared quests** with one id where the task is the same for all six towns, with race texts where wanted. Local
  quests only where a town's own story is the point.
- **The boar and rat quests** at once, with counts by phase.
- **The 12 tool-swap quests** get a new purpose: no more handing in tools and getting the same back.
- **The reward pattern** of ruling 18 and the zone's handover to the next zone. The six `*_departure` ids stay
  (§3), and the lane's scope includes the six level-11 files that require them, for reading only.
- **New ids** for every quest whose objectives change; givers only on free quest sockets (§3).
- **Placeholder texts.**
- **Reports:** the quest count before and after, and the XP and copper to level 10 on a plausible route
  (`tools/r28_design/ledger.py`), as numbers to compare, not targets.
- **The user's check:** the structure goes to the user as a QUESTMAP page (`tools/r56_questmap`) before
  STARTTEXT starts.

**STARTTEXT (Astra) and TEXTREVIEW (Opus).** The texts for STARTQUESTS' structure under the quest text rules
(§3); then the review with a suggestion page; the user picks; the coordinator or a short lane applies the picks.

**D.** The version 0.57.0, CHANGELOG, STATUS, ROADMAP, BACKLOG, AGENTS pointer, the round's classification, the GUI
checklist, the completion section.

## 5. Rules

The usual ones ([round workflow](../process/round-workflow.md)):
- one worktree and branch per lane;
- an independent Opus review per non-trivial lane, and a delta review for logic changes in a fix;
- the Lua queue at most 8 at once;
- no pushes, merges or syncs by lanes; the sync to the user's Luanti only after the round.

Fixtures: each lane runs only its own fixture plus the fixtures that test the behaviour it changes, and the full
run once before its report. Nothing unpicked ships.

## 6. Verification

- **Gates:**
  - the full fixtures, `check_fresh_server.py`, `check_upgrade.py`;
  - `tools/r28_design/validate.py --game` for every quest-data change;
  - the quest loader's own validation at boot;
  - one boot.
- **Headless shots:**
  - the crafting page: idle, running with a queue of 3, the queue view, a details page;
  - the quest dialog: offer with a choice preview, turn-in with nothing picked and with a pick;
  - a story marker next to a normal one.
- **GUI checklist** (D, draft):
  - **FIX56:**
    - fly over the bay at (−609, 9, −2285) in "test": allowed; the open sea and the bay mouths stay no-fly;
    - look at cloth and leather head pieces from below: no texture under the chin where the strip is open;
      leather T6 and metal unchanged.
  - **Crafting window:**
    - layout C: "Craft ×N" while idle and "Queue ×N" while a job runs; the bar, the stop button and "View Queue
      [N]" stay on another recipe and on a details page;
    - queue 5 jobs, of which one enchant; a sixth is refused;
    - cancel one: its ingredients come back; stop the running one;
    - queue three jobs, log out for longer than they take and back in: they have finished and their outputs are
      there (in the overflow if the inventory is full);
    - a details page names where each ingredient comes from; "Open ▸" and "◂ Back" walk the chain; group
      ingredients open a page of kinds;
    - favourites: bookmark two recipes, "Favorites only" with and without "Craftable only";
    - unlock a profession tier: its Basic recipes (Thread, Patch Bolt) are there.
  - **Start zones:**
    - a new character gets the boar and rat quests at once, and one night suffices for the rats;
    - the start town offers its free quests at once; a quest done in one town is not offered in another;
    - the potion choice, the level-5 and level-7/8 armor choices and the final weapon choice: icons with
      tooltips, Complete refused without a pick, the item has its enchants and the item level;
    - story quests have their own marker and list category; a ready side quest at a mixed giver is still visible;
    - a completion text at the turn-in;
    - the final quest leads to the next zone's quest giver;
    - an existing character above level 10 sees the new start quests offered (accepted, ruling 20) and can still
      take its level-11 zone's quests.
  - **The web build:** the same dialogs at the web client's size.

## 7. Orchestration notes

- **Merge order:**
  - FIX56 any time (it shares no file with the other lanes);
  - CHAINDEPTH early (CRAFT may use it);
  - CRAFT and QSYS → DETAILS (DETAILS needs CRAFT's layout and QSYS's tooltip helper);
  - QSYS → STARTQUESTS → STARTTEXT → TEXTREVIEW;
  - D last.
- STORYARC and GUILDART merge nothing (reports and picks in the orchestration folder).
- **Shared files:**
  - CRAFT and DETAILS share `grug_jobs/ui.lua`, `craft_box.lua` and `operation_box.lua`, so DETAILS integrates
    after CRAFT;
  - `grug_quality` belongs to QSYS alone;
  - QSYS and STARTQUESTS share `grug_quests` (STARTQUESTS only data, after QSYS);
  - `tools/README.md` appends with the merge helper.
- **Size:** 11 lanes; the coordinator staggers the starts within the process budget.
- **Decided during the round:**
  - the story arc pick (STORYARC);
  - the art picks (GUILDART);
  - the start-zone structure (the user on the QUESTMAP page);
  - the text picks (TEXTREVIEW).
- **Settled before the go (2026-10-23):**
  - offline crafting keeps today's behaviour (ruling 4);
  - the hosting platform's code reads no quest ids (checked in `~/projects/kaesual-stack`: no quest access in its
    reconciler, migrations or web code). The stable-id sentence in its upgrade task file was a rule for the
    game's side, so ruling 21 needs nothing from the platform. The task file outside this repository is not
    touched.

## 8. Decided for Round 58

Decided with the user on 2026-10-22 and 2026-10-23. Round 58 is the **one map reset**: the Miner's Guild and the
town fixes. Its own plan follows after this round; these are its rulings. They replace the mining-camp part of
[Round 56 §8](round56-plan.md#8-decided-for-later-rounds).

**The Miner's Guild**
- One guild per faction, an essential political actor of its faction: **The Charter of Stone** (The Accord) and
  **The Oathdelvers** (The Throng), the user's pick 2026-10-23; their role comes from STORYARC.
- A Miner's Guild building with NPCs stands in each of the six capitals (a template change).

**The camps**
- **20 new camps:** one in every T2, T3 and T4 zone outside the capital zones (6 T2, 8 T3, 6 T4), placed per seed
  in the part of the zone whose level fits. A T4 camp in a contested zone belongs to the faction whose half of the
  continent it lies on.
- **The 16 Battlegrounds war camps become mining camps too:** a double function. They are mining camps, guarded
  by faction guards, and the target of the enemy faction's raid quests (the existing fortress quests).
- **"Enemy camps under construction":** one in each own contested T4 zone. They have guards and a captain, no lift
  and nothing of use to the enemy faction. The foreman of the own T4 camp gives the quest against it. This
  introduces the raid mechanic gently; raid quests on real camps begin at T5. The 31–40 zones are the soft entry
  to PvP.
- **The lift** goes between the surface and every level of its camp (coordinator default).
- **Each camp** has:
  - a foreman (the guild's representative) as quest giver;
  - a vendor who buys like every vendor, trades mining materials for reputation, repairs (vendors do not repair
    today: a new provider) and sells **only** reputation goods: one page, no tabs, all consumables in 6 rows,
    each row marked "Reach Reputation Rank N" until reached. No torches or ladders.

**Lifts and rooms**
- **One lift point per tier depth** from T1 down to the camp's zone tier: a T2 camp has two (T1, T2), a T6 camp
  six; 148 rooms over the 36 camps.
- **A teleport lift** with no shaft, for members of the camp's faction only.
- **Rooms** at the tier's lowest y + 50: −50, −250, −450, −650, −950; T6 at −1050 (coordinator default).
- The rooms are written by the world generator, never stamped at first use.
- **Protection:** the rooms are protected, without guards and without mob spawns. Enemy players may enter but
  not use the lift.
- **Water and lava:**
  - a mantle around the room, with the liquids in it replaced;
  - the exits end blind in rock;
  - an invisible fill that players walk through and liquids cannot flow into, in the room and its openings. It
    sets `walkable = false`, `floodable = false`, `buildable_to = false` and `is_ground_content = false`
    explicitly;
  - the planned lava-lake pass (BACKLOG E3) spares the rooms.
- **Engine facts from the plan review** (for the Round 58 plan to verify):
  - A later neighbouring chunk's caves, flooded caves and dungeons reach about 14–16 nodes into an earlier chunk
    and spare only nodes with `is_ground_content = false`. The rooms at −50 and −450 sit 17 nodes below a chunk
    top, inside that reach. So the mantle uses non-ground-content nodes, or the room sits at least 16 nodes
    inside its chunk.
  - The deep depth-pulse spawner treats any non-walkable node as open and is stopped only by protection, so the
    rooms get a y-bounded protection box in the zone overlay.
  - The rooms are their own generation step, independent of the existing writer's rock-below early-out.
  - 148 rooms cost next to nothing in mapgen.

**Quests**
- **Guild quests are bound to the depth, not the camp:** one quest id per tier (T2–T6) for both factions, with a
  text per guild. They are taken and turned in only at camps of the own faction. Every own camp whose deepest lift
  reaches the tier offers it until it is done, so a missed T2 quest is offered in a T3 camp too.
  - 1–2 gather quests per tier.
  - When both gather quests of a tier are done, the foreman may give one follow-up ("tell the guild in the
    capital"), used rarely and to carry the guild's small storyline.
- **No T1 mining quest:** the start zones stay on the first ten levels.
- **Each camp also has 1–2 kill quests** on mobs near the camp; day or night spawns may be used ("at night" can be
  literal).
- **All of a camp's quests can be taken at once** on a visit; no chains beyond the one follow-up.
- No kill objectives in the depth (no mob density is promised there), and no repeatable quests.

**Reputation**
- A currency the player does not carry: one value per player, the same at every member of their faction's guild.
- **Where:** materials are traded for reputation at the guild in the capitals and at the camp vendors. This is a
  mechanism, not a repeatable quest. Players get rid of what they have mined, and every kind of mining is
  rewarded.
- **Two numbers:** the lifetime total (the rank) and the spendable balance. Spending never lowers the rank.
- **Ranks 0–10**, built over time; the last ranks are hard to reach. A new player is rank 0.
- **Ranks 1–6 unlock buying** the T1–T6 consumables.
- **An achievement series** "Reach Reputation Rank 3/6/10 with the Miner's Guild" with three cloaks; the rank-10
  cloak has wings (texture work only; the cloak model has wings already).
- **Exchange rates** by material (stone, sand, ores, gems and so on), with stone and sand very low. Selling ores
  and stone for money stays possible, as at every vendor.
  - Vendors sell no leather, cloth, ores or bars (ruling 28), so reputation cannot be bought with copper through
    vendor materials.

**Consumables**
- **Two kinds:**
  - **Ore Sense:** every 60–120 s it marks one ore deposit of its tier in range for 5 s, visible only to the
    user.
  - **Treasure Hunt:** it places one hidden block in solid rock (no air within 1, never in a protected area),
    marked for the user while they stay in range. The block is removed when they go too far (the block removes
    itself, so nothing stays behind after a crash or logout). Other players may mine it, without a marker.
- Each has a **fixed tier** and works only in its depth: 12 items. They are **expensive**.
- **Rank limits buying; level limits use:** 11 for T2, …, 51 for T6 (level 1 for T1, coordinator default). The
  items can be traded and stored in chests.
- **An own effect slot:** they do not share the elixir's slot, and only one of the two effects is active at a
  time.
- **The effect continues across logout and death** (the user, 2026-10-23: it is not combat-relevant). Statuses
  are runtime-only today and cleared at leave and death (`grug_core/status.lua`), so this effect saves its
  remaining time.
- **Miner's Remains** give copper and materials, worth more in deeper tiers. A material obtainable only this way
  waits for the unique items (§9).

**Towns** (Round 56 §8, unchanged)
- Lethariel's bough platforms and the five core gatehouses (in the templates);
- Lethariel's royal guards on posts by the king;
- the gate guards' two patrols and the tower post;
- the terrace stair's off-by-one;
- the waystone and mailbox at each start town's centre.

## 9. Later

- **Round 59 and later:** the picked story arc built; the quest rework of levels 11–60 on the Round 57 foundation,
  zone by zone, possibly over several rounds. Each zone file gets the rework flag when it is reworked.
- **Not needed for now:** a "visit place X" objective. The guild's gather quests do without one, and kill
  objectives in the depth are dropped. It comes when a story step needs it.
- **Then:** unique, non-craftable items. These are quest rewards that replace the crafted items in choice rewards,
  boss drops from fixed loot tables for the instances, and items found in the world. The armor redesign with
  several polygon groups per slot (for item variety) is planned separately and lands after Round 58, so it does
  not collide with this work in `grug_visuals` and the armor data.
