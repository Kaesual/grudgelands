# Round 48 — Mail, plants and light, selling, smaller bags

Coordinator: Claude (Opus 5.5), drafted 2026-10-14 from the user's three
partial plans of the same day and the user's decisions in this session.
Status: **complete on main** (2026-10-14, not pushed; GUI test open;
[completion](#completion-2026-10-14)).

The round folds four partial plans into one round. They stay the detailed
specification of their lanes; this plan sets the lanes, the waves, the
rulings made while merging them, where it overrides them (§2), and the
interfaces between the lanes (§3):

- [mail-plan.md](mail-plan.md): mailboxes on the waystone pads of the
  capitals and starting villages, letters with attachments, postage,
  tickets to the admin, the Admin Mail tab, broadcasts, a starter quest,
  welcome and level letters.
- [plant-growth-plan.md](plant-growth-plan.md): one light rule for plants
  (light 8; fungi and cave plants exempt; trees only in daylight), papyrus
  and cactus on their wild ground and indoors, Melon and Mushroom as
  crops, spores, the salt pan, salt regrows in the wild, plant tooltips.
- [plant-art-plan.md](plant-art-plan.md): nine plant items, three drafts
  each, for the user's pick.
- [sell-fuel-daytime-plan.md](sell-fuel-daytime-plan.md): selling almost
  everything (lots for cheap goods), leaves and cactus as fuel, the
  daytime band beside the minimap, bags at half size with a migration.

Release **0.48.0**: a **map reset** (the mailboxes are placed by world
generation) **plus the migration step 0.48.0** (the bags shrink; what no
longer fits arrives by mail). Push only on the user's word.

Routing (the user, 2026-10-14, as in Round 47):
- Claude coordinates.
- Opus implements and reviews.
- GPT-6 Astra makes the art (ARTP, ARTM) and writes the letter and quest
  texts (TEXT), followed by an Opus text review round.

## 1. Lanes and waves

| Lane | What | Wave | Kind | Spec | Merge waits for |
|---|---|---|---|---|---|
| HUD | The minimap side elements: the mail icon slot, the daytime band, and the corner layout with the minimap hidden (with "Now playing") | 1 | code + generator | sell plan §3.6, §4.3; §2.1 here | — |
| MAIL | `grug_mail`: model, storage, API, the mailbox window, attachments, Help page | 1 | new mod | mail plan §3, §4.1 | HUD (or a guarded call) |
| WORLD | The mailbox node and its placement through `dressing.waystone` | 1 | node + world generation | mail plan §4.4 | — |
| FARM | Light rule, papyrus, cactus, saplings, Melon and Mushroom crops, spores, salt pan, salt renewal, wild looks, tooltips; **plus FUEL** (cactus and leaves) | 1 | code + data | plant plan §4.1; sell plan §4.2 | — |
| SELL | Prices in lots, crafted goods at half value, the sell window | 1 | code | sell plan §3.2–3.5, §4.1; §2.2 here | FARM (its price comparison runs on FARM's item set) |
| BAGS | Bags at half size, the sort into target sizes, migration 0.48.0, Small Bag 20c | 1 | code + migration | sell plan §3.7, §4.4 | MAIL (the migration's end-to-end test sends letters) |
| ARTP | Plant art: 9 items × 3 drafts, the pick page, final files | 1 | art (Astra) | plant art plan | FARM (final files only replace FARM's placeholders) |
| ARTM | Mailbox block, mail icon, admin shield and NPC seal, the daytime band's sun, moon, colours, frame and marker | 1 | art (Astra) | mail plan §4.5; sell plan §3.6.6 | MAIL, WORLD, HUD |
| TEXT | Welcome letter, Riding Trainer and Housing Steward letters, the starter quest's text; then an Opus text review round and a proposal page | 1 | texts (Astra, then Opus) | mail plan §4.6 | QUEST (or a text-only commit after it) |
| ADMIN | `mail_admin`, the Admin Mail tab, answers and closing, broadcasts, logging | 2 | code + UI | mail plan §4.2 | starts after MAIL merged |
| QUEST | The system quest kind, the starter quest, welcome and level letters | 2 | code | mail plan §4.3 | starts after MAIL merged |
| D | CHANGELOG, STATUS, README, BACKLOG, the plan's completion and GUI checklist | 3 | docs | §4.12 | the last merge |

Wave 1 runs six Opus lanes and three Astra lanes side by side; every Lua
process goes through the shared queue (at most 8). MAIL is the largest
lane and the critical path: ADMIN and QUEST start once it is merged, and
BAGS and ARTM merge after it.

## 2. Rulings (the user, 2026-10-14, this session)

The rulings of the partial plans (§2 in each) stand, except where this
section changes them.

1. **The minimap hidden or unavailable:** the mail icon, the daytime band
   **and the "Now playing" box** move together into the **top-right
   corner** and stay visible there, stacked so that none overlaps another
   ("passend aufrücken"). The stack stays inside the minimap's box
   (`grug_core.hud_layout.minimap_box`), so the quest tracker and the
   other elements laid out around that box keep their places. With the
   minimap shown, the mail icon stands left of the bezel, top-aligned,
   and the band left of the bezel, bottom-aligned (sell plan §3.6.5);
   "Now playing" stays where it is today. "Unavailable" is the case in
   which the minimap's globalstep returns at once today (no world map
   base, `minimap.lua:647`); the side elements must work there too. This replaces the mail plan's ruling 14 sentence "It always
   stands at the same place, also with the minimap hidden" and its §3.13
   placement, and extends the sell plan's ruling 5 to "Now playing",
   which today is not drawn with the minimap hidden
   (`grug_map/minimap.lua` `M.set_now_playing`).
2. **Today's payouts win by construction.** Today's resolver
   (`price_rules.resolve`, whole copper, the free world materials at 0)
   runs unchanged and yields today's payout for every item that has one.
   A second pass in milli-copper (sell plan §3.2–3.3: the bulk table,
   material values, the halving, storage blocks, lots) prices **only the
   items that have no payout today** and that the sell plan's rules price
   (the bulk table, crafted goods, storage blocks); vendor goods keep
   today's buy-back rule (a 1–2c supply stays unsellable, sell plan
   §3.3.5) and the never list stays unsellable (§3.4 there). Reason: today's walk floors to whole
   copper at every recipe step and counts sand, stone and wood as 0, so a
   single milli-copper walk would raise chained and bulk-containing
   payouts and break the sell plan's ruling 2. The one-time before/after
   comparison (sell plan §4.1) then must show **no difference** for items
   priced today, except the Small Bag's buy-back (4c → 1c, which follows
   its new vendor price through the unchanged buy-back rule). The loop
   audits run over the combined table. This replaces the sell plan's
   §3.3.2 sentence "There is no second value track".
3. **Lane cut** as in §1:
   - the HUD lane owns `grug_map/minimap.lua` and `minimap_view.lua`;
     MAIL only calls the HUD lane's API (§3.1);
   - SELL and BAGS start in wave 1; SELL's price comparison runs once
     FARM is merged into its branch, and BAGS's end-to-end migration test
     once MAIL is;
   - **every lane updates the design documents whose rules it changes**
     (as in Round 47), so the reviewer checks code and doc together; lane
     D writes only CHANGELOG, STATUS, README, BACKLOG, the AGENTS pointer
     and the plan's completion. The partial plans' "Docs" sections (mail
     plan §4.7, plant plan §4.3, sell plan §4.5) become each lane's doc
     list (§4).
4. **Routing** as in Round 47 (above).

**Coordinator choices** (details the user did not rule on; a lane may
propose otherwise in its report):
- The mail icon's digit badge is a set of **finished images** (no badge,
  1–9, 9+) composed by the HUD lane's generator, like the band's 40
  images, instead of a `[combine` at runtime (mail plan §3.13). One
  approach for both side elements. The digits are the existing cooldown
  digits; the "+" glyph is added to their generator
  (`tools/r40_cd/gen_cooldown_textures.py`) by the HUD lane, so it
  matches them (mail plan §3.13), not drawn by ARTM.
- FUEL rides with FARM (sell plan §4.2 suggests it); its fixture is
  `tools/r47_an/portable_test.lua` extended, as planned there.
- One pick page per art lane (ARTP plants; ARTM mail and band); TEXT gets
  its proposal page after the Opus text review.
- The "Lost and Found" letter text (sell plan §3.7.2) is written by the
  coordinator, not by TEXT (not a quest text).

## 3. Interfaces between the lanes

These are contracts; the briefs repeat them.

1. **HUD → MAIL:** `grug_map.minimap.set_mail_count(name, n)` (`n = 0`
   hides the icon). HUD builds the element, the images and the placement
   in both modes (§2.1); MAIL calls it on every unread change and at join.
   If MAIL merges before HUD, its call is guarded by the function's
   existence and the icon appears when HUD merges.
2. **MAIL → BAGS:** `grug_mail.send_system(to_name, kind, from_label,
   subject, body, stacks)` with an **optional `stacks`** argument (up to
   four `ItemStack` strings), stored and taken exactly like player
   attachments (sell plan §3.7.3). Only the migration uses it; admin
   letters keep carrying no items (mail plan ruling 5). The 0.48.0
   handler in `grug_core/migrations.lua` looks `grug_mail` up at the join
   (as the 0.45.0 handler looks up `grug_inventory` and `grug_jobs`).
3. **MAIL → QUEST:** `grug_mail.register_on_mailbox_open(fn(player,
   pos))` and `send_system` (mail plan §4.1).
4. **MAIL → ADMIN:** the ticket store with `close_ticket(id,
   admin_name)`, the broadcast store and `send_system` (mail plan §4.1).
5. **MAIL → WORLD:** `grug_mail.open_mailbox(player, pos)`, looked up at
   runtime from the node's right-click (`grug_mapgen` loads first).
6. **FARM → ARTP:** FARM wires the art plan's target file names (its §6)
   with placeholder PNGs; ARTP's final step only replaces PNGs and
   ledger rows (art plan §7).
7. **MAIL, WORLD, HUD → ARTM:** each ships placeholders under fixed file
   names that its brief lists; ARTM's final step only replaces PNGs (and
   the mailbox's node textures or mesh, if the pick needs a mesh) and
   ledger rows; HUD's generator recomposes the band and badge images from
   ARTM's parts with `--check`.
8. **QUEST ← TEXT:** QUEST keeps the letter and quest texts in one data
   file with placeholder texts; the picked texts replace them (by QUEST
   if it is still open, otherwise as a text-only commit the coordinator
   checks).
9. **The mail attachment list** `grug_mail_out` is **not** a carried list
   (`grug_inventory.carried_lists` stays `main` plus the bags), so
   selling, crafting, the sort and the migration never touch it.

## 4. Lanes (goals; the briefs add file facts)

Every lane:
- re-checks the partial plan's file facts at its base and reports each
  as confirmed, changed or refuted;
- classifies its change (compatible, map reset, migrate, new server);
- updates the design documents whose rules it changes (§2.3).

### 4.1 HUD — the minimap side elements
**Goal:** the daytime band (sell plan §3.6 and §4.3: the pure position
function, 40 finished images, the update on the minimap's slow tick, no
new globalstep) and the mail icon element with its badge images (§3.1),
placed beside the minimap, and the corner layout of §2.1 for the mail
icon, the band and "Now playing" whenever the minimap is hidden or
unavailable. The slow tick must run for the side elements while the
minimap is hidden or unavailable (today `update` removes everything when
hidden, and the globalstep returns at once without `view`). One
generator writes the band and badge images from placeholder parts until
ARTM delivers; the "+" glyph joins the cooldown digit generator (§2,
coordinator choices). The lane proposes sizes and the corner stacking with
screenshots (desktop; the web build at the GUI test); the user can change
them in the GUI test.
**Docs:** `world_map.md` (the minimap section), the module guide's
minimap seam.
**Proof:** the position function's fixture (sell plan §6, DAY), the
generator's `--check`, captures of both layouts.

### 4.2 MAIL — `grug_mail`
**Goal:** mail plan §4.1 with its defaults §3.1–§3.12, §3.16 (the
mailbox name), §3.17 (no map marker) and §3.21, the optional `stacks` of
§3.2 here, and the call of §3.1 instead of its own HUD element (§3.13
is HUD's). The feed notice and the Help page are MAIL's.
**Docs:** the new `docs/design/mail.md` (rules of the mail plan §2 and §3
as built) with its design-tour entry; `quests.md:107`, `parties.md:50`,
`economy.md` §4 (postage as a sink); the module guide's "Mail" section
and mod map row; the upgrade contract's note that a future item-removal
step also scans mail storage and `grug_mail_out` (mail plan §4.7).
**Proof:** the model and sending fixtures (mail plan §6, MAIL).

### 4.3 WORLD — the mailbox
**Goal:** mail plan §4.4: the node, one offset on every one of the twelve
pads (a capital may pass its own), the decor-kit rules, `tools/r36_w`
with its baseline. Screenshots of all twelve pads for the review and the
user.
**Docs:** `settlements.md` (the mailbox on the waystone pad).
**Proof:** twelve mailboxes on the twelve pads, none elsewhere, each
resolving to its settlement's label.

### 4.4 FARM — plants, light, salt, tooltips, fuel
**Goal:** plant plan §4.1 with its defaults §3.1–§3.14, and sell plan
§4.2 (cactus 15 s, `group:leaves` 2 s in both furnaces; the shift-click
check reported). The tooltip lines are proposals (plant plan §4.1); the
coordinator checks them, the user may change them in the GUI test.
**Docs:** plant plan §4.3 (`farming.md`, `world.md` R4,
`biomes_mobs.md` §2, `items_crafting.md` §3.7, `world_zones.md:2129`) and
`items_crafting.md` §3.0.2 (the fuels).
**Proof:** plant plan §6 fixtures, the FUEL fixture (sell plan §6), and a
`quick` seed fleet before the merge (the lane touches
`habitat_registry.lua`; world generation must not change).

### 4.5 SELL — selling almost everything
**Goal:** sell plan §3.2–§3.5 and §4.1 with §2.2 here: today's resolver
as the first pass, the milli-copper pass for items without a payout
today, the lot ladder, the never list, the sell window. The price
comparison runs from SELL's branch with FARM merged in; its report lists
every new payout and proves "no change" for every old one (Small Bag
excepted once BAGS is merged).
**Docs:** `economy.md` §2 (sell plan §4.5).
**Proof:** sell plan §6 (SELL); `income.py --check` and
`band_payout.sh` unchanged.

### 4.6 BAGS — half-size bags and migration 0.48.0
**Goal:** sell plan §3.7 and §4.4: sizes, descriptions, the sort into
target sizes with leftovers through the one sort path, the 0.48.0
character handler and the offline step, Small Bag 20c, the regenerated
web data and item-tier tables. The handler calls MAIL's `send_system`
with `stacks` (§3.2). Its end-to-end test (four full 32-slot bags → 16
letters, nothing lost, a second join changes nothing) runs once MAIL is
merged into the lane.
**Docs:** `inventory_equipment.md` §3, `item_tiers.md` (through
`tools/r33_ds`), the upgrade contract's step list (0.48.0).
**Proof:** sell plan §6 (BAGS); `check_upgrade.py`.

### 4.7 ARTP — plant art (Astra)
**Goal:** the plant art plan: 9 items × 3 drafts with a generator, the
pick page (the coordinator publishes it), the fix round, then the final
files under the target names. No fixtures, nothing under `mods/` in the
draft step.

### 4.8 ARTM — mail and daytime art (Astra)
**Goal:** three proposals each for the mailbox block and the HUD mail
icon (mail plan §4.5), and for the daytime band's parts (sun, moon, day
and night colours, frame, "now" marker; sell plan §3.6.6); derived from
the picks: the admin shield badge and the NPC seal. The coordinator
publishes the pick page. Then the final files under the
names the MAIL, WORLD and HUD briefs fix. No sound (mail plan ruling 19).

### 4.9 TEXT — letters and the starter quest (Astra, then Opus)
**Goal:** mail plan §4.6: the welcome letter, the two level letters and
the starter quest's text, with the quest-text rules (placeholders for the
player's name and the capital, no fixed places or directions, no tooltip
texts, no reference to existing games), about 600 characters per letter.
Then an Opus review round with complete replacement proposals and a
proposal page for the user.

### 4.10 ADMIN — the admin side
**Goal:** mail plan §4.2 with its defaults §3.6, §3.14, §3.15.
**Docs:** `mail.md` (the admin side), the module guide's "Mail" section.
**Proof:** mail plan §6 (ADMIN).

### 4.11 QUEST — the system quest and the letters
**Goal:** mail plan §4.3 with its defaults §3.18–§3.20; the texts through
§3.8 here. The starter quest's 25c and XP are quest copper:
`income.py --check`.
**Docs:** `quests.md` (the system quest kind), the module guide's quests
section, `mail.md` (welcome and level letters).
**Proof:** mail plan §6 (QUEST); `validate.py --game`.

### 4.12 D — documentation
- The CHANGELOG entry (the placeholder the coordinator adds at the
  version bump), STATUS, README's current state, the AGENTS pointer,
  BACKLOG carry-overs.
- The plan's completion with the combined GUI checklist (§6).
- The partial plans' status lines: done, with a pointer to the
  completion.

## 5. Rules

- The partial plans' §5 rules hold for their lanes.
- **Clients and budgets:** stock clients only; plain Lua 5.1; the web
  build is a target; no new globalstep for the HUD; performance numbers
  are comparisons, never targets; a lane that gets noticeably slower or
  more complex reports to the coordinator, who asks the user.
- **Release mode:** 0.48.0 is a map reset plus the migration step 0.48.0.
  No compatibility code for the old map. Mail storage is not map-bound and
  survives map resets.
- **Sounds:** none new (mail plan ruling 19).
- **Texts:** item tooltips and window labels by Opus or the coordinator,
  never by Astra; letters and the quest text by Astra with the Opus round.
- **Reviews:** every code lane gets an independent Opus review; fix deltas
  with game logic are reviewed again; text, colour and display deltas the
  coordinator checks itself; theoretical concerns become backlog notes.
- **Push** only on the user's word.

## 6. Verification

Per lane the gates of the [round workflow](../process/round-workflow.md#3-gates)
and the fixtures named in each partial plan's §6.

- **Fixtures (every brief):** own fixture plus the fixtures that test the
  changed behaviour during development; the full run once before the
  report.
- **Seed fleet:** `quick` before merging FARM; `full` once at the round
  end on main (FARM and WORLD both touch world-generation code).
- **Upgrade:** `check_upgrade.py` after the version bump and at the round
  end; the 0.48.0 step's test, and the tests of every declared step in
  the `debian:trixie` container (BAGS changes `tools/migration/`).
- **Economy:** `income.py --check` after SELL, QUEST and BAGS.
- **Data:** `validate.py --game` after QUEST; `r33_ds/build_doc.py
  --check` after BAGS; `web_data/export.lua --check` in every lane that
  adds or changes items or textures (FARM, BAGS, ARTP, ARTM; regenerated
  when it reports the file stale) and at the round end. No zone spawn
  recipe changes, so `r28_regions` is not owed.

**GUI checklist** (desktop and web, a new world after the map reset; an
existing 0.47.0 character for the migration items): the lists of the
three partial plans — mail plan §6 items 1–10, plant plan §6 items 1–9,
sell plan §6 items 1–8 — with these changes:
- mail plan item 9 and sell plan item 6: hide the minimap — the mail
  icon, the band and "Now playing" stand together in the top-right corner
  and none overlaps another (§2.1);
- sell plan item 5: every item that sold in 0.47.0 sells for exactly the
  same price (§2.2).

Lane D merges them into one numbered checklist in the completion.

## 7. Orchestration notes

**Start state:** main after this plan's commit, which also commits the
four partial plans (worktrees do not see untracked files), on top of
`6a8afb9f` and the Round 47 status bookkeeping (the push and GUI
acceptance lines, done by the coordinator before the round starts).

**Before every lane start:**
- the lane-start checklist (`grudgelands-orchestration/LANE-START-CHECKLIST.md`);
- the fixture sentence in every Opus launch prompt;
- Astra briefs say "no fixtures";
- at most 8 Lua processes through the shared queue;
- engine runs only through `tools/luanti_headless.sh` with `LC_ALL=C`;
- never the user's Luanti folder.

**The version bump** (done by the coordinator before the worktrees, so every
lane starts from it): `game.conf` 0.48.0, 0.48.0 in `map_reset` of
`tools/web_data/upgrade.json`, the CHANGELOG placeholder. The `migrate` entry
comes with BAGS's merge, together with its step file and the handler
(`check_upgrade.py` requires the step file for every `migrate` entry and
the game's step registry to equal the list).

**File ownership (the briefs list exact files):**

| Lane | Files |
|---|---|
| HUD | `grug_map/minimap.lua`, `minimap_view.lua`, `grug_core.hud_layout` (`hud_layout.lua`) only if the corner layout needs it, the band and badge generator and its images, `tools/r40_cd/gen_cooldown_textures.py` (the "+" glyph) |
| MAIL | the new `mods/PLAYER/grug_mail`, `grug_housing/soulbound.lua:8` (comment), `grug_inventory/help.lua` (the Mail page), `mail.md` |
| WORLD | `grug_mapgen/world_nodes.lua` (the mailbox node), `wp13/dressing.lua` (`waystone`), capital files only if one needs its own offset, `tools/r36_w/baseline.tsv` |
| FARM | `grug_farming`, `grug_cooking` (the `PLANTS` skip, spores naming), `grug_nodes/crop_visual.lua`, `default/functions.lua`, `trees.lua`, `nodes.lua` (GRUG PATCH), `grug_jobs/automatic.lua` (fuel), `tools/r45_rg/edits.lua` and `basic_recipes.lua`, `grug_mapgen/wp40/habitat_registry.lua`, a new P9G presentation file, `grug_gathering` (overrides only, not `catalog.lua`) |
| SELL | `grug_traders/price_rules.lua`, `prices.lua`, `trade.lua`, `init.lua` audits, the price probes under `tools/` |
| BAGS | `grug_inventory/bags.lua`, `storage.lua` (the sort), `grug_core/migrations.lua`, `tools/migration/steps/v0_48_0.py`, `grug_traders/stock.lua:55`, `tools/r33_ds` outputs |
| ADMIN | `grug_mail` (admin files), `grug_inventory/ui.lua` (`TAB_ORDER`) |
| QUEST | `grug_quests` (registry, validate, state, hud, window), `grug_map/quest_box.lua`, `grug_mail` (the grant and the letters) |
| ARTP | textures and ledgers of `grug_farming` and `grug_gathering` (final step), its generator under `tools/` |
| ARTM | textures and ledgers of `grug_mail`, `grug_mapgen` (mailbox) and `grug_map` (band and badge parts), its generator under `tools/` |

**Merge order** (each lane merges when ready, within these constraints):
- HUD before MAIL, or MAIL with the guarded call (§3.1).
- FARM before SELL's comparison and before ARTP's final files.
- MAIL before BAGS, ADMIN and QUEST.
- MAIL, WORLD and HUD before ARTM's final files.
- `grug_quests` and `grug_map/quest_box.lua` belong to QUEST alone;
  `grug_mail` is shared by MAIL, ADMIN and QUEST: ADMIN and QUEST start
  from merged MAIL and the second of them merges main before its review.
- **Shared files:** `grug_inventory/help.lua` (MAIL's page; one-line
  additions by others), `economy.md` (MAIL's postage row, SELL's §2),
  `items_crafting.md` (FARM, one lane), `grug_traders` (SELL;
  BAGS only `stock.lua:55`), `world_nodes.lua` (WORLD's node; FARM's
  overrides live in their own file). The second lane to merge rebases.
- D last.

**The user's touchpoints:**
- the ARTP pick page (plants) and its fix round;
- the ARTM pick page (mailbox, mail icon, band parts);
- the TEXT proposal page;
- WORLD's twelve pad screenshots and HUD's layout screenshots (changes
  possible in the GUI test);
- FARM's tooltip lines (in the GUI test);
- the round's GUI test.

After merges: `tools/sync_to_luanti.sh`.

## 8. Open questions for the user

None before the start. Decided during the round: the art picks, the
letter texts, the mailbox offset, the HUD sizes and corner stacking, the
tooltip lines.

## Completion (2026-10-14)

Every build lane is merged on main; this lane D (this section and the
status owners) follows on main `a5b280e9` (ADMIN, merged last). **0.48.0
is a map reset plus a migration step:** world generation places the
mailboxes on the twelve waystone pads (and the Salt Crust crop nodes are
gone), and every bag holds half as much, so each character's inventory is
sorted into the new sizes at its next join and what no longer fits
arrives by mail (step 0.48.0). Mail lives in mod storage and survives map
resets. The production world (0.45.1) moves to 0.48.0 in one update and
crosses the map resets 0.46.0, 0.47.0 and 0.48.0 and the steps 0.47.0 and
0.48.0. **Push:** not pushed; origin/main stays at `6a8afb9f` (0.47.0)
until the user's word.

### Lanes

Main's first-parent merges from `c4a0a729` (the version bump: `game.conf`
0.48.0, 0.48.0 in `map_reset`, the CHANGELOG placeholder), in order:

| Lane | Merge (follow-ups) | What | Review |
|---|---|---|---|
| WORLD | `aac103a0` | the node `grug_mapgen:mailbox` and `dressing.waystone` placing it at (+2, +1) from the stone, facing it, on all twelve pads; one `PARAM2_KIND` row in `wp13/parts.lua` | MERGE |
| HUD | `a52a63a0` | the side elements beside the minimap: the daytime band (40 images), the mail icon with its badge (10 images), the corner stack with the minimap hidden or unavailable, `set_mail_count`; the "+" cooldown glyph | MERGE |
| FARM | `63181db8` | plant light 8 for crops, papyrus and cactus, saplings by daylight, Melon and Mushroom crops, spores, the Salt Pan, salt renewal, wild looks, tooltips; cactus and leaves as fuel; the plain Water Bucket and the River Water Bucket | MERGE AFTER FIXES (Medium: a crop whose timer expired after its light went out lost a stage's progress; the same twin for dry soil, pre-existing), fixed with the Salt Crust seed alias; delta MERGE |
| MAIL | `0f7d48e1` (`9389b7ae`) | `grug_mail`: model, storage, API, the mailbox window with four tabs, attachments, postage, tickets and broadcasts stores, Help → Mail; then the letter or ticket id on Delete and the confirm buttons | MERGE AFTER FIXES (a double-click Send, the shift-click ring into bag 1, the mailbox re-read after payment), fixed; delta MERGE; follow-up delta MERGE |
| ARTP | `8f55c033` | the user's nine plant picks, 29 files byte-identical to the drafts, FARM's placeholders retired | the user's picks; coordinator art check |
| ARTM | `9892063c` | mailbox A as a nodebox with four textures, icon B redrawn at 48 × 40, band A's parts at 160 × 40, the admin shield and NPC seal derived | the user's picks; coordinator art check |
| SELL | `567b741e` | the second pass in milli-copper for items without a payout, lots, crafted goods at half value, the pack rule, the sell window with one row per lot good | MERGE AFTER FIXES (wording only), fixed by the coordinator (`f94b879a`) |
| QUEST | `b8b741f8` (`3d76ceaf`) | the system quest kind, the starter quest `mailbox_visit`, the welcome and level letters with the picked texts; then the zone-atlas probe skipping system quests | MERGE (the probe fix a Low of the review, done by the coordinator) |
| BAGS | `fdd6268d` | bags of 4 / 8 / 12 / 16, the sort into target sizes, the step 0.48.0 with "Lost and Found" letters and its `migrate` entry, the Small Bag 20c; the earlier step tests `r45_ms` and `r47_ms` repaired (test-only) | MERGE |
| ADMIN | `a5b280e9` | the privilege `mail_admin`, the Admin Mail tab: inbox, answers, closing, deletion, admin letters, announcements | MERGE with two Lows (a stale click acting on a newly selected ticket; the empty-answer check), fixed before the merge; delta MERGE |
| TEXT | (in QUEST) | GPT-6 Astra's letters and quest text, three variants each, an Opus text review with revisions, the user's picks | the user's picks |
| D | this section | CHANGELOG, status owners, BACKLOG carry-overs, the tools index, the partial plans' status lines, the capital plaza comments | — |

Main has 189 portable fixtures (8 new: `r48_world`, `hud`, `farm`, `mail`,
`sell`, `bags`, `quest`, `admin`; FUEL extended `r47_an`, the price rules
`r29_e1`, the minimap `r27_minimap`); `mods/` +4,300 −220 lines in 138
files, twelve new Lua files (`grug_mail`'s `init`, `model`, `store`,
`api`, `window`, `admin`, `texts`, `letters` and `quest`,
`grug_farming/salt_pan.lua` and `tooltips.lua`,
`grug_gathering/presentation.lua`).

### Decisions during the round

The user's decisions of 2026-10-14, one line each (the coordinator log is
outside the repository):

1. **The §2 rulings:** with the minimap hidden or unavailable the mail
   icon, the daytime band and "Now playing" stack in the top-right corner
   inside the minimap's box (§2.1); today's payouts win by construction
   (§2.2); the lane cut with every lane owning its design documents
   (§2.3); routing as in Round 47 (§2.4).
2. **Texts:** welcome letter O (the Opus original), Riding Trainer A
   (GPT-6 Astra, kept by the Opus review), Housing Steward C+ (the Opus
   revision of C), the starter quest B+ (B without ", {player},", since a
   quest text takes no player placeholder; confirmed by the user).
3. **Mail art:** mailbox A (the wayside chest), icon B (the sealed
   envelope), band A (the brass channel).
4. **Plant art:** Cassava C, Wild Onion A, Pumpkin A, Melon B, Mushroom A,
   Sunleaf C, Gravemoss A, Wild Cocoa B, Salt Pan A; no change requests.

The coordinator decided, one line each:

- **`send_system`'s return contract:** `true, id` on success, `false,
  reason` on failure, never nil (BAGS clears a cell only on success).
- **The Salt Crust seed alias:** `grug_farming:seed_salt_crust` aliases to
  Salt Crust (no step; the engine resolves aliases in every inventory and
  attachment).
- **The pack-block rule:** a block that nine of one item make and that
  gives the nine back pays nine times its item (the twelve storage rows,
  Coal Block, the six cut-gem blocks); the one-way meat blocks stay
  crafted goods.
- **The loop audit** counts a consumed crafted good at its value before
  the halving (otherwise every reverse recipe failed: 50 errors).
- **The version bump before the worktrees,** so every lane started from
  0.48.0; the `migrate` entry came with BAGS's merge.
- **The zone-atlas probe** skips system quests (`3d76ceaf`).
- Also: the ordinary Water Bucket carries no metadata (a river bucket keeps
  its family and label), so the Salt Pan recipe takes it; FARM's tooltip
  lines as proposed; SELL's 306 new payouts and the honest bag values (not
  tuned); the Salt Pan stays unsellable for now; `give_to_singleplayer =
  false` for `mail_admin`; the Announcements filter with Delete; the
  "Lost and Found" letter text written by the coordinator; HUD's position
  35 for 00:00 (the plan's own rule, not the brief's 39); ARTM's picks
  adapted to HUD's part sizes.

### Deviations from the plan

- **SELL's second pass** settles by repeated lowering passes instead of a
  recursive walk: the walk went exponential on the recipe cycles
  (slab/block, pack/unpack) and the first boot hung.
- **FARM** changed `bucket.lua`: the plan's fact "the Water Bucket is a
  plain ingredient" was refuted (its metadata kept it out of every
  recipe). Overrides live in a new `grug_gathering/presentation.lua`,
  because `catalog.lua` hashes `nodes.lua`.
- **BAGS:** the web data needed no regeneration (it lists only equippable
  items); the bags' join callback now never shrinks a list over items, so
  a held character keeps its stacks.
- **QUEST:** `{capital}` is the display name of the race's capital
  settlement (no helper existed); the completion line goes to the feed.
- **WORLD** needed one row in `wp13/parts.lua` (facedir for the mailbox);
  **HUD** also corrected `sound.md` §5 ("Now playing" now shows with the
  minimap hidden).
- **ARTM** made the mailbox a nodebox (foot, post, box, lid) with four
  textures and redrew icon B at 48 × 40 for HUD's badge composition.

### Numbers worth keeping

Comparisons, not targets.

- **Prices** (a disposable probe, base main `63181db8` against SELL with
  FARM merged): 1,586 items in both; **393 priced before, 0 changed**;
  **306 new payouts**, 135 sold singly and 171 in lots (72 at 1c per 50,
  46 at 1c per 20, 20 at 1c per 2, 17 at 1c per 99, the rest per 5 or
  10). Examples: Healing Potion I 1c, VI 70c; Elixir of Vigor VI 4s;
  Grand Feast 71c; Iron Block 9c; Coal Block 9c; Steel pick 6c; Leather
  Rucksack 3s20c. `band_payout.sh` byte-identical; `resolve_prices` in
  single-digit milliseconds before and after.
- **Mailboxes:** 422 roster compositions diffed base against branch,
  exactly 12 cells changed (one mailbox per pad); in the engine 12 of 12
  pads with the stone, one mailbox at (+2, +1), param2 1 and the right
  label.
- **The migration** (e2e, a 0.47.0 character with four full 32-slot
  bags): 152 stacks → 88 kept (4 × 16 plus `main[9..]`, equal stacks
  merged) and 63 mailed in **16 letters** (15 × 4 + 1 × 3), counts, wear
  and meta equal (nothing lost or duplicated), 16 unread, one feed line;
  a second join changes nothing. The steps' container tests: `r43_mt` 38,
  `r43_it` 59, `r44_ms` 32, `r45_ms` 64, `r47_ms` 21, `r48_bags` 25.
- **Seed fleets:** FARM's `quick` 100/100 (8 min 45 s); the round-end
  `full` 304/304 (23 min 35 s, on `3d76ceaf`, whose world generation is
  final).
- **The HUD band and icon** (sizes in px; the band 45 % of the box at
  4 : 1, the icon 19 %):

  | Window | Box | Mail | Band | Hidden stack bottom |
  |---|---|---|---|---|
  | 720p, GUI 1 | 180 | 39 × 34 | 81 × 20 | 110 / 180 |
  | 1080p, GUI 1 | 270 | 59 × 51 | 122 × 31 | 138 / 270 |
  | 720p, GUI 2 | 180 | 39 × 34 | 81 × 20 | 158 / 180 |
  | 1080p, GUI 2 | 270 | 59 × 51 | 122 × 31 | 186 / 270 |

  Positions: 04:30 → 0, 19:29 → 29, 19:30 → 30, 00:00 → 35, 04:29 → 39.
  `bench_glide` bytes per second 382 → 383 walking, 1,122 → 1,124 flying;
  packets per second unchanged.
- **Plants:** one light read per growing crop per 15 s and one water
  search per Salt Pan per 15 s (none before); in the engine a closed box
  reads light 0, a Coal torch beside the crop 11 (also at midnight), two
  nodes away 9, a glass roof natural light 15; the salts' initial
  densities unchanged (27 rows).
- **Mail windows:** 1.4–2.4 KB per mailbox form, 1.8–2.8 KB per Admin Mail
  form; no globalstep.

### Classification

- **Map reset:** WORLD (the mailboxes placed by world generation); FARM's
  removed crop nodes `grug_farming:salt_crust_1..4` are map-bound.
- **Migrate:** BAGS's step 0.48.0 (`main[9..]` and the bags sorted into 4
  / 8 / 12 / 16 at the next join, the rest as "Lost and Found" letters;
  offline only the marker).
- **Compatible:** HUD, MAIL, FARM otherwise, SELL, QUEST, ADMIN, ARTP,
  ARTM. Saved state that is new or read differently: `grug_mail`'s mod
  storage (`box:<name>`, `tickets`, `broadcasts`, `factions`, `next_id`;
  not map-bound), the player meta `grug_mail:broadcasts_read`,
  `quest_granted`, `welcome_sent`, `letter_riding` and `letter_housing`,
  the player list `grug_mail_out` (sized at join), the quest id
  `mailbox_visit`; held Salt Crust Seeds become Salt Crust (alias); a 0.47
  Water Bucket with `water_family=ordinary` still pours but is no Salt Pan
  ingredient until refilled.
- **The declaration:**
  `{"schema": 2, "version": "0.48.0", "map_reset": ["0.40.1", "0.46.0", "0.47.0", "0.48.0"], "new_server": [], "migrate": ["0.44.0", "0.45.0", "0.47.0", "0.48.0"]}`.

### Open notes

The reviews' and reports' backlog notes are in the
[BACKLOG](../../BACKLOG.md#round-48-carry-overs).

### GUI checklist (Round 48)

Desktop (GUI scale 1 and 2) and the web build (about 1280 × 720), on a new
world after the map reset; an existing 0.47.0 character for the update
items. Built from the three partial plans' lists (mail plan §6, plant
growth plan §6, sell plan §6) with the plan's two changes (§6) and every
lane's and review's GUI items. Points marked **(decide)** are the lanes'
open questions for the user.

**The update:**

1. A 0.47.0 world taken to 0.48.0 with the map reset and the step; Help →
   About shows 0.48.0.
2. A 0.47.0 character with full bags joins: the inventory is sorted, the
   bags show 4 / 8 / 12 / 16 slots (a 4- or 12-slot bag leaves half a row
   empty), the hotbar and gear are unchanged, one feed line, the mail icon
   counts the "Lost and Found" letters; Take all brings the items back once
   there is room, and without room they stay in the letter.
3. The Sort button works as before.

**Mailboxes and letters:**

4. In a start village and a capital of each faction the mailbox stands two
   nodes east and one north of the waystone, its slot facing the stone, and
   does not block the walk to the stone; it reads as a mailbox from about
   ten nodes away, cannot be dug or blown up; in Silverleaf a silverwood
   post stands right beside it **(decide)**.
5. A right-click opens "Mailbox in <town>" with Letters, Announcements,
   Write and To the admin, the counts in the tab captions, the badge and
   seal icons.
6. Write to an offline character of the same faction and drag two stacks
   in: the first Send says the attachments changed and shows "Send
   (65c)", the second takes 65c and the stacks; judge the refusal's
   wording and the two clicks **(decide)**. The recipient sees the icon at
   login and takes the items with Take all.
7. Close the window (or Discard) with a stack in a slot: it comes back.
   Shift-click from the main inventory goes into the attachment slots,
   also with a bag equipped.
8. The other faction, an unknown name, yourself, a Claim Stone or a skill
   in a slot, a full inventory on Take all: each refused with a clear
   message, nothing lost. A double click on Send sends one letter.
9. Reply quotes the letter; Report a player letter (reason, note,
   confirm): it shows "Reported". Delete asks first when the letter holds
   items.
10. Help → Mail.

**The starter quest and the game's letters:**

11. A new character: the quest "Use a mailbox in one of the cities" in the
    log ("Rewards: 30 XP, 25c"), the tracker cut to "Open a mailbox beside
    the waystone..." **(decide: the short form "Open a mailbox at a
    waystone" fits)**, the mail icon "1".
12. Open the start village's mailbox: the quest completes (+25c, XP), the
    tracker line goes; the completion line lives 2.5 s in the feed while
    the mailbox window covers the screen **(decide)**. The welcome letter
    reads well and opens on click; the icon vanishes once it is read.
13. An existing 0.47.0 character's first join: the same quest and the
    welcome letter; at 15 or above without a riding tier the Riding
    Trainer's letter, at 20 or above never having had a Claim Stone the
    Housing Steward's, both naming the race's capital; on that first join
    the level letters arrive before the welcome letter.
14. `/xp` from 14 to 21: both level letters, once each. With 20 quests in
    the log at the first join: no starter quest, then or later.

**Writing to the admin and Admin Mail:**

15. To the admin with topic Bug report: the ticket shows Open; a sixth
    open message is refused.
16. `/grant <you> mail_admin`: "Admin Mail" appears after Help; with eight
    tabs the tab bar overflows into scroll arrows **(decide: the shorter
    title "Admin")**; `/revoke` removes the tab, also while it is open.
17. The ticket shows under Open with the version and "Sent from Mailbox in
    …"; Send answer and close: the player gets "Re: …" from Server Admin
    (the mail icon lights) and sees Answered; Close without answer: no
    letter, the player sees Closed; an answer that is only the quote is
    refused.
18. Report a letter: the admin sees its frozen copy.
19. A new admin letter to All players: both characters find it under
    Announcements with the shield badge, each with its own read state;
    Delete it from the Announcements filter.

**The mail icon, the daytime band and the corner:**

20. The band and the mail icon stand in one row left of the bezel (band,
    icon, minimap), the same height, their tops on the bezel's top (the
    user's variant A, follow-up lane HUD2); the sun section long, the moon
    section short, the next phase entering from the right; it moves about every 30 s, and
    after `/time 19:00` it shows night coming within about 5 s; no numbers.
21. More than nine unread letters: "9+".
22. Hide the minimap: the same row right-aligned in the top-right corner,
    "Now playing" (in a capital) right below it, none overlapping another,
    and the quest tracker stays in place. With no mail the icon's slot is
    kept, so the band does not move **(decide: close up instead)**; a wide
    "Now playing" grows to the left.
23. Resize the window and set GUI scaling 2: everything follows, nothing
    overlaps (also at 1024 × 600 with GUI scaling 2 next to a long target
    frame line). The band at 75 % (92 × 23 px at 1080p) and the icon at the
    same height; the count stands fully beside the envelope, "9+" included
    (the user's choice). At night the band's frame fades into the tan ends
    at this size (nearest scaling drops its inner line; the user: okay as
    is).

**Plants and light:**

24. In a closed, unlit room with farm soil and water: Carrot stays, Cave
    Cap grows. A Coal torch in the field: Carrots within about 4 blocks
    start growing.
25. Papyrus on mud beside water indoors with a torch grows (patience:
    about 16 min per piece); dig the second piece: everything above comes
    along and the bottom regrows; the same for cactus on sand.
26. A sapling under a glass roof grows; under stone with torches it does
    not.
27. Melon and Mushroom: craft seeds and spores, plant, harvest by
    right-click.
28. Craft a Salt Pan (the Water Bucket is used up), place it on stone next
    to water in a dark room, scrape a crust when it is full. A 0.47 Water
    Bucket must be poured and refilled before the recipe takes it; a
    bucket of river water reads "River Water Bucket" and goes into no
    recipe.
29. Hover over Carrot, Carrot Seeds, Mushroom Spores, Papyrus, Sunleaf and
    the Salt Pan: one readable line each (the Large Cactus Seedling has
    none); judge the tooltip lines.
30. Wild Potato and Corn in the meadows and Melon in the jungle look like
    grown plants; the new plant art in the world and the inventory.

**Selling and fuel:**

31. Cactus in a furnace smelts about 1.5 bars; leaves burn briefly (five
    per bar).
32. 143 Cobblestone in three stacks (main and a bag): one row "Cobblestone
    x143 · 1c per 50 · All (2c)"; All pays 2c and leaves 43. 30 Sand: a
    greyed "Need 50 to sell" row without a button. The two-line hint does
    not overlap the first row or the money line.
33. A Healing Potion, a dish, seeds, an Iron Block and a Steel pickaxe each
    show a price; a Bag of Coins, the Claim Stone and dirt do not show; the
    Salt Pan is not sellable.
34. Every item that sold in 0.47.0 sells for exactly the same price (the
    Small Bag's buy-back is now 1c). The Mason's cobblestone, gravel and
    bricks now sell in lots. All takes from the main inventory and the
    hotbar before the bags.
35. The vendor sells the Small Bag (4 slots) for 20c.

### Follow-up lanes

- **HUD2** (`2ad1a1b8`): after looking at screenshots and a wireframe, the user
  chose variant A: the mail icon and the daytime band in one row left of
  the minimap along its top edge (right-aligned in the corner with the
  minimap hidden, "Now playing" below), the band at 75 % (92 × 23 px at
  1080p, 4 : 1), the icon at the same height with the count beside the
  envelope (mail images recomposed). Review MERGE. Then the user's two
  answers: the count fully beside the envelope (mail images 87 × 28, the
  icon 72 × 23 at 1080p; a display delta checked by the coordinator), and
  the band's frame fading at night stays as is. Fixtures 189/189, smoke
  boot PASS.

### Round-end gates

**Round-end gates** (coordinator, 2026-10-14, on main `a5b280e9`): full
fixtures 189/189, the full seed fleet 304/304 (23 min 35 s, on
`3d76ceaf`, whose world generation is final: BAGS and ADMIN touch no
world generation), `check_upgrade.py` (0.48.0 against origin/main
`6a8afb9f`), `check_fresh_server.py`, `r28_design/validate.py --game` (0
errors, 5 warnings in untouched files), `income.py --check`, `build_doc.py
--check`, the names checks (`check_rules.py --shipped`, `guarantee.py
--check`), the bat, HUD texture, enchant-mask, cloak, Basic recipe and
web-data checks, every declared step's test in the `debian:trixie`
container and a smoke boot (90 s) PASS. On lane D's branch:
`tools/r37_dc` and `check_upgrade.py` (0.48.0 against origin/main) PASS.
