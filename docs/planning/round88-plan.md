# Round 88 — Player feedback of 2026-11-26

**Completed 2026-11-27** ([Completion](#completion-2026-11-27)). Release 0.88.0, **compatible** with 0.87.0.
The round answers the user's batch of player feedback: one map filter less,
faster Swiftness and Sprint, professions that advance on the level-up, quest
markers that show what is worth walking to, gathering in enemy territory,
knockback that belongs to the attack, a new Character page and an icon of its
own for every potion family.

## 1. Lanes and waves

| Wave | Lane | Deliverable |
|---|---|---|
| 1 | QOL | One map filter less (PvP into Places), Swiftness +30 % for 5 s, Sprint cooldown 180 s, the profession tier on the level-up, the "Prepared" mixtures gone. |
| 1 | QUEST | The quest markers of §2.5: grey for low givers, no marker for quests not yet acceptable. |
| 1 | GATHER | Herbs and food can be gathered in enemy home territory; everything else stays refused. |
| 1 | KNOCK | Knockback on players from the attack's weight class, never from its damage, and no stacking. |
| 1 | STATS-M | The Character page mockup (artifact) for the user's go. |
| 1 | ICONS-C | Astra's design concept for the potion and elixir icons, for the user's approval. |
| 2 | STATS | The Character page as approved (UI lane: merged only after the user's go on its screenshots). |
| 2 | ICONS-P | Two or three proposals per potion family on a pick page. |
| 3 | ICONS | The picked icons, every tier, in the game (or a follow-up 0.88.1 when the picks come late). |
| last | D | The round's records. |

Auto-forward on a mount is not part of the round: it works in the user's own
test (2026-11-27), so there is no known bug. The user asks the reporting player
for the exact circumstances; should a case turn up, the mount could also read
`control.movement_y` beside `control.up` (`grug_mounts/entity.lua`
`horizontal_input`).

## 2. User rulings

1. **Map filter.** The PvP filter goes. The fortresses, the Battlegrounds camps,
   the camps under construction and the arena move to Places. A Battlegrounds
   camp's tooltip names that it is also a mining camp.
2. **Potions.** Every potion and elixir family gets an icon of its own. Astra
   first writes a design concept the user approves, then two or three proposals
   **per family** (not per tier). The "Prepared … Mixture" items leave the game.
   After two concept rounds (the user, 2026-11-27): every potion is a bottle,
   roughly mirror-symmetric; the tier shows through a combination of the
   bottle's material (a few steps, not a new form at every tier) and the
   stopper, which tells neighbouring tiers apart; no numerals or studs.
3. **Swiftness Draught: +30 % movement speed for 5 s.** The user accepts the
   break of the speed pillar (player 4.0 × 1.3 = 5.2 > 4.6, the ordinary mob
   band) as a named exception, like Sprint. **Sprint's cooldown drops from 300 s
   to 180 s** (+50 % for 10 s unchanged).
4. **Professions.** A profession whose crafts for the next tier are complete
   advances as soon as the character reaches the tier's level, without another
   craft. The hint texts change with it.
5. **Quest markers** (the giver's head and both maps):
   - a giver whose acceptable quests are all **10 or more levels below** the
     player's level shows a **grey "!"**; story quests never turn grey;
   - a quest that cannot be accepted yet gets **no marker** (the grey "soon" "!"
     of Round 65 ruling 2 goes; the giver's dialog keeps its "next quest at
     level X" hint);
   - acceptable quests above the player's level stay **yellow**; no orange;
   - "ready" (yellow "?"), "in progress" (grey "?") and the story colour stay;
     "in progress" outranks the low grey "!" (the user, 2026-11-27, after the
     lane's question).
6. **Gathering in enemy territory.** Herbs, apples, berries, ground plants and
   the wild cooking and alchemy ingredients can be gathered in enemy home
   territory. Trees, blocks and placing stay refused. Grass, ferns and
   flowers (the decoration plants) may be dug there too, for consistency
   (the user, 2026-11-27, after the lane's question).
7. **Knockback** (on players):
   - it is a property of the attack, **never of its damage**, and **not of the
     level**;
   - an ordinary mob's melee hit pushes by its family's **weight class**:
     none / light / medium / heavy;
   - an **elite** pushes more than its class (a factor, about ×1.25); rares and
     bosses are set one by one;
   - **projectiles push nothing**;
   - pushes do not add up (§3);
   - a knockback skill for the Warrior is **not** part of this round; the user
     thinks about it further (§7).
8. **Character page.** A mockup first. Str, Int and Dex appear on the page, with
   their effect on hover. The cloak picker moves under the 3D model. The stats
   are a styled clickable list (name left, value right); a click opens a
   scrollable detail box on the right that is ordered by relevance: first the
   stat's direct effects, then, smaller, where the value comes from (for
   example "+4 from Boots"). After the mockup (the user, 2026-11-27): Maximum
   HP and Mana (or Rage) head the list and Maximum HP is selected whenever
   the page opens; the Damage reduction row goes, the Armor detail shows the
   reduction against enemies of several levels; the pools' detail shows the
   calculation (base × class factor × percentages).
9. **Respawn lock.** No change: the report of a respawn by Enter is taken as a
   lock that ended with the fight (Enter sends the same `quit` as Esc, which
   the lock answers).

## 3. Shared conventions

- **Knockback window** (coordinator default). Per player one window of
  0.5–0.75 s from the first push: inside it a further push applies only by the
  amount it is stronger than the strongest push so far. The direction is
  horizontal with a small fixed lift, the same for every source, so no push
  points into the floor (the reason the Expedition packs flatten theirs today).
- **Starting values by feel** (coordinator default, tuned after the user's
  test): light about 2.5, medium about 4, heavy about 6 m/s (today about 8.8
  for almost every hit from level 20 on). The four classes and the elite factor
  live in one place.
- **"Prepared" mixtures** (coordinator default): each id becomes an alias of
  `vessels:glass_bottle` instead of a registered item, so a stray leftover is a
  bottle and the release stays compatible without a migration step. The
  user may ask for a deleting step instead.

## 4. Lane goals

**QOL.** *Map:* drop the PvP layer in `grug_map/layers.lua` and move its kinds
to Places in `settlement_icons.lua`; a Battlegrounds camp's tooltip reads as a
war camp and a mining camp. *Swiftness:* `grug_alchemy` (effect, item text),
the status icon's text, and the design documents that state +10 % for 5 s and
the 4.4 < 4.6 arithmetic (`mounts.md`, `combat_stats.md`, `item_tiers.md`),
which name the draught as the second named exception. *Sprint:* the 180 s
cooldown in `grug_abilities/scout.lua` and every document that states 300 s.
*Professions:* a level-change hook (and the join, for a character that is
already saturated) advances every saturated profession the new level allows,
with the existing message, sound and basic-tier unlock; the Crafting tab's and
the craft message's hint stop asking for one more craft. *Mixtures:* the
registrations in `grug_alchemy/recipes.lua` go, the aliases of §3 replace them.

**QUEST.** The marker states in `grug_quests/state.lua` (`Q.marker_states`)
gain the low status and lose the "soon" one; the head marker (`npc.lua`), the
world map's Quests layer and the minimap follow from the state. "Low" reads the
quest's level, not its acceptance level. A giver with a ready or story quest is
never grey.

**GATHER.** A world exception (`grug_core.register_world_exception`) lets a
player dig a gathering source when the world rule refuses the place only as the
other faction's home territory; towns, roads, bridges, settlement and POI cores,
guild rooms and the sea stay refused, and claims stay with `grug_housing`. The
lane names the allowed nodes from the gathering and cooking catalogues (herbs,
spices, found food, apples, berries, the wild ingredients), never trees, logs,
leaves, ores, stone or soil. Right-click picking follows, since a pick is a dig.

**KNOCK.** Replace the damage-based push in the one knockback override
(`grug_core/combat.lua`) with §2.7: a weight class per mob family (a table
beside the families' run speeds), the tier factor, zero for projectiles, the
window and the direction of §3. The Expedition packs' own push and the
dragon's slam go through the same rule or keep their own zero. PvP melee keeps a
small fixed push. The lane reports the family table for the user to read.

**STATS-M / STATS.** The mockup shows the page at the user's window size with
real numbers of one character per class. The build uses the existing accessors
(`grug_classes` attributes, pools, crit and dodge; `grug_quality`'s equipment
totals) and adds a per-slot source breakdown; it reads every number from the
same accessors combat uses.

**ICONS-C / ICONS-P / ICONS.** Ten families: Healing, Mana, Vigor, Focus,
Precision, Stoneskin, Antivenom, Swiftness, Cave, Deepwater (plus the
merchant's healing potion). Readable at 32 and 16 px, the elixirs in line with
their status icons, a tier scheme that is not a Roman numeral. Design goals,
not permission lists, for Astra.

**D.** CHANGELOG, STATUS, the design documents the lanes did not own, and the
Completion. BACKLOG gains the Warrior knockback skill (§7) as an open idea for
a later class round.

## 5. Rules

Every lane states its upgrade classification. The planned outcome is
compatible: no saved state changes shape, the mixtures become aliases. A lane
that finds otherwise reports before it builds. No lane changes the class
balance beyond the Sprint cooldown.

## 6. Verification

- Fixtures per lane for its logic: the marker states (low, story, ready,
  none for not acceptable), the profession advance on a level change and at a
  join, the gathering exception (each refusal kind, allowed and refused nodes,
  placing), the knockback rule (classes, elite factor, projectile, window,
  direction).
- **Human tests offered:** knockback by feel (light, medium, heavy; a pack;
  an elite), on desktop and web; the Character page on both clients.

## 7. Orchestration and open points

- Start from main 0.87.0. The model routing is the user's for the session:
  the coordinator runs on Opus, the lanes and reviewers on Opus, ICONS-* on
  GPT-6.2 Astra.
- **Landing** (the user, 2026-11-27, for this and every later round, now
  in the [round workflow](../process/round-workflow.md) §2 steps 8–10). All work happens on the
  local round branch `round88`. When the round is complete (lane D merged, the
  round-end gates passed), the whole round branch gets one independent review
  against main; then the coordinator syncs the round branch into the user's
  Luanti and the user tests and accepts it. Only after the user's release does
  the round land on main as one squash commit with its tag. The round branch
  itself stays local and is **not** deleted (its lane worktrees may go).
- **Compaction checkpoints:** C1 when wave 1 has merged and the mockup and the
  concept wait for the user; C2 when wave 2 has merged; C3 after lane D, the
  round-end run and the whole-round review, before the sync for the user's
  test.
- **Shared files and merge order:** QOL, QUEST, GATHER, KNOCK. QOL and QUEST
  both reach into `grug_map` (QOL the layers and settlement icons, QUEST only
  the marker display), and QOL and KNOCK both edit `combat_stats.md` (QOL the
  Swiftness and Sprint lines, KNOCK the knockback text); each keeps to its own
  lines.
- Open with the user: the **story purple**, which the user checks in the game;
  the **Warrior knockback skill**, for a later class round. For that skill: the
  mob displacement it would use (`grug_mobs.displace_mob`) already refuses a
  destination in lava or fire, without a floor under it or inside a block, and
  elite, rare and boss mobs are never pushed. It checks the destination only,
  not the way there, so a long push could cross a narrow gap.
- STATS and ICONS wait for the user's go on the mockup and the concept; the
  round may land without ICONS, which then follows as 0.88.1.

## Completion (2026-11-27)

Eight lanes in three waves plus the mockup, each code lane independently
reviewed (display-only fix deltas checked by the coordinator; the art steps
ICONS-C and ICONS-P approved by the user on their pages): QOL, QUEST, GATHER, KNOCK (Opus
each), STATS-M (the coordinator's mockup), STATS (Opus), ICONS-C, ICONS-P and the art of
ICONS (GPT-6.2 Astra) with its wiring ICONS-W (Opus), then lane D. Release **0.88.0**,
**compatible** with 0.87.0 (`tools/web_data/upgrade.json` gains no entry; every lane
reported compatible, `check_upgrade.py` PASS). Merge order into `round88`: GATHER, QUEST,
QOL, KNOCK, the GATHER follow-up, ICONS (with ICONS-W), STATS, then lane D. Auto-forward
on a mount stayed out (§1).

**Saved keys:** none new and none changed in shape. QOL reads and writes the existing
player meta `grug_jobs:level:<prof>`, `grug_jobs:crafts:<prof>` and
`grug_jobs:basic_unlocked`, and reads `grug_jobs:primary:<n>` and
`grug_jobs:learned:<prof>`; QUEST reads `grug_quests:state` as before. The Character
page's selection (`context.grug_stat`), the map layer and the knockback window live only
in memory. The 40 `grug_alchemy:mixture_*` ids are aliases of `vessels:glass_bottle`; the
engine resolves an alias whenever a stack is loaded, so a stored mixture comes back as a
bottle without a migration step (§3).

**What shipped:**

- **QOL** (rulings 1–4, §3 "Prepared mixtures"): the PvP map layer is gone; the
  fortresses, the war camps, the camps under construction and the arena are Places rows
  (`grug_map/settlement_icons.lua`, `layers.lua`, `minimap.lua`), seven layer buttons; a
  war camp's tooltip reads "War camp and mining camp: <name>". The Swiftness Draught gives
  +30 % for 5 s (`grug_alchemy/effects.lua`, the item and status texts), the second named
  exception to the speed pillar (4.0 × 1.3 = 5.2 > 4.6); with Sprint the aggregator's
  clamp keeps 1.5 (6.0 nodes/s). Sprint's cooldown is 180 s (`grug_abilities/scout.lua`).
  A saturated profession advances on the level change and at the join
  (`grug_jobs.advance_professions` through `grug_xp.register_on_level_change`, which also
  runs at the join), one tier per change, since an advance clears the next tier's count;
  new texts "Capped by your level: tier N+1 comes at level M." and "… tier progress is
  complete; tier N+1 comes at character level M.". The mixtures are aliases. Fixture
  `tools/r88_qol` (67 checks); nine fixtures updated with a reason each.
- **QUEST** (ruling 5): `Q.LOW_LEVELS = 10` replaces `Q.SOON_LEVELS`; a quest the level
  still holds back gives no marker; an available side quest at `def.level <= level − 10`
  is `low`, a grey "!" (#c0c0c0); precedence ready > available > active > low, so a story
  flag never lands on `low`. The head marker, the minimap and the map window share
  `grug_map/markers.lua` `quest_texture` (`low` draws the existing
  `grug_map_quest_locked.png`). Help → Quests rewritten. Fixture `tools/r88_quest` (56
  checks); eight fixtures updated.
- **GATHER** (ruling 6): one world exception (`grug_gathering/territory.lua`) opens only
  the other faction's home territory, and only where the home's own faction could change
  the place, so roads, bridges, settlement and POI cores, towns, landmarks, guild rooms,
  the sea and protected water keep their refusal and hint, and claims stay with
  `grug_housing`. Allowed: the **29** gathering sources (12 catalogue sources and 15 wild
  cooking and alchemy sources by the group `grug_gathering_source`, plus `default:apple`
  and the ripe blueberry bush), then in the follow-up **31** ground plants (grass, dry
  grass, jungle grass, ferns, marram grass, the dry shrub, six flowers, two alpine plants,
  lichen and moss carpets, cattails, reeds). Right-click picking follows, since a pick is a
  dig. Fixture `tools/r88_gather` (210 checks, 385 after the follow-up). Two engine boots
  with throwaway probes (27 nodes in the group; the 31 plants and 14 refused group members
  from the real registry).
- **KNOCK** (ruling 7, §3): one `core.calculate_knockback` override
  (`grug_core/knockback.lua`) hands builtin no push and pushes by the attack: the numbers
  in `grug_core.KNOCKBACK` (none 0, light 2.5, medium 4, heavy 6 m/s, elite ×1.25, PvP
  melee 2, lift 1.5, window 0.6 s); the family table, rares and bosses in
  `grug_mobs/knockback.lua` (the Kings, Generals, dragons, Kraken, rift boss, Duewarden and
  Flintback heavy ×1.25 = 7.5, Auditor Nemm 5; six rares heavy 6, four medium 4; people fall
  to medium). Projectiles push nothing (`knockback_pushes` asks `_cmi_is_mob`). The packs'
  flattening wrapper is gone; the kings' Shatter (8, lift 4) and the rift pulse (7) go
  through `grug_core.push_player` and share the window; the dragon slam keeps its own zero
  and arena push. The smoke boot classified 372 mob entities: 51 heavy, 92 light, 194
  medium, 35 none. Fixture `tools/r88_knock` (608 checks); four fixtures updated. The
  family table is in the lane report for the user.
- **STATS-M / STATS** (ruling 8): the mockup with real numbers per class, then the Stats
  mode (`grug_inventory/stats.lua`, `pages.lua`): the list Maximum HP, Maximum mana or rage,
  Str, Int, Dex, Armor, Dodge, Crit with separators, a clear button per row with a
  right-aligned value, a scrolling detail (effect, then "Where it comes from" smaller,
  then the rule), HP selected on open and after a close, the pools' calculation, Armor's
  reduction at −5, 0, +5 and +10 levels, no Damage reduction row, the cloak picker under
  the model in every mode (model height 6.58 → 5.55). New seams:
  `grug_items.get_equipment_slot_sources` (filled in grug_quality's totals pass),
  `grug_inventory.equipped_armor_pieces` (from `armor_pieces_cache` beside `armor_cache`
  after fix round 1), an optional height for `grug_achievements.cloak_dropdown`. The
  inventory view is untouched (the user). Fixture `tools/r88_stats` (306 checks at the
  first build, more pins in the fix rounds); 18 × "SUMS ok" on real enchanted level-30
  gear at both window sizes. Stats mode form 8967 → 14480 bytes (Scout; Effects 9193 →
  9338).
- **ICONS** (ruling 2): two concept rounds by Astra, two proposals per family on a pick
  page, the user's eleven picks, then **41** CC0 textures (`grug_alchemy/textures/`, 40
  items, plus the merchant's `grug_traders_potion_healing_weak_bottle.png`) with a manifest
  (`tools/r88_icons/game_textures.json`, `check_game_textures.py` 41/41). Tier by the
  bottle and its stopper: earthenware with cork and wax (I–II), blown glass with a silver
  disc and a gem point (III–IV), cut crystal with a winged clasp and an amber sun (V–VI).
  ICONS-W: one `image(family, tier)` helper in `recipes.lua`, the tint fields gone,
  `register_consumable` asserts an image; in the follow-up the potion cooldown icon shows
  the merchant bottle and the alchemist's sign the Healing Potion I
  (`tools/building_templates/nodes.json` edited by hand to match). Fixture
  `tools/r88_icons_w` (291 checks; 164 fail on the base commit).
- **Lane D:** the version, this section, CHANGELOG, STATUS, README's current state,
  BACKLOG lines, the two comments that still described builtin's damage-based push
  (`grug_abilities/init.lua`, `grug_mobs/boss_dragons.lua`), professions.md §1's "before
  Round 88" and the design and technical lines that still named the PvP layer or the
  engine's punch knockback (`world_zones.md`, `world.md`, `modules/mapgen.md`).

All six `r88_*` fixtures passed together on `round88` after the last merge.

**Reviews:** QOL MERGE (one nit, the professions.md wording, done by lane D). QUEST MERGE
(no findings; the precedence question was already answered by the brief). GATHER MERGE (no
findings); follow-up delta review MERGE. KNOCK MERGE (Low: two stale comments, done by lane
D; notes on weaker boss pushes and the dragon's lightning). STATS MERGE (two Minor: the
armor slots re-read per build, a weakened `r28_a6_ui` pin; both fixed in fix round 1, delta
review MERGE); fix round 2 (Home right-aligned) display only, checked by the coordinator.
ICONS MERGE (all 41 files md5-identical to the picks, licence hashes recomputed); the
follow-up (cooldown icon, sign) display only, checked by the coordinator.

**The user's choices during the round (2026-11-27):** after the mockup the Damage reduction
row goes into the Armor detail, HP and the pool head the list, HP is selected on open and
the pool formula stays (ruling 8); STATS must not touch the inventory view; the Scout's
quiver and Home on one row, then Home right-aligned; grass, ferns and flowers may be dug
too (ruling 6); "in progress" outranks the low "!" (ruling 5); on the first icon concept:
every potion a bottle (no vials), a straighter Healing, the missing Mana family added,
potency through the bottle instead of a studded neckband; on the second: the combination
of bottle material and stopper, roughly mirror-symmetric (ruling 2); the picks healing A, vigor A, mana A,
focus A, precision A, stoneskin B, antivenom B, swiftness A, cave A, deepwater A, merchant
B; the cooldown icon and the alchemist's sign switch to the new bottles; the dragon's
lightning keeps its push (wanted); the go for the STATS and ICONS merges; the landing rule
for every round ([round workflow](../process/round-workflow.md) §2 steps 8–10).

**Deviations from the plan:**

- GATHER's ground plants are its own rule, not the group `grug_decor_plant` (that group
  also holds decoration leaves, corals, water and hanging plants and misses default's
  grasses): an attached `flora` or `grug_decor_plant` node that is no sapling or leaves,
  the variants that drop one, and four plants by name. Since grass and flowers are
  `buildable_to`, a placing guard allows such a plant only inside its own `on_dig` or
  `on_punch` at that position (the context pattern of `grug_housing/protection.lua`), so
  nobody builds into enemy grass; one accessor `grug_gathering.enemy_home_gatherable` was
  added.
- STATS corrected mockup texts against the code (HP "before you die"; Int's spell power
  "–" for Warrior and Scout; Armor's rule names falls, lava and drowning and "+85 per level
  above 60") and, at the user's request, put the Scout's "Quiver N/500" and Home on one
  row, Home right-aligned (a 27-letter default name wraps in its box, never overlaps).
- QUEST reached `grug_map/markers.lua`'s own rank table and `grug_inventory/help.lua`,
  outside its brief's list. KNOCK added a loader line each to `grug_core/init.lua` and
  `grug_mobs/init.lua`, and its own rider check (no fixed load order with `player_api`).
- Plan facts refuted by the lanes: no map filter hid the "soon" markers; "several tiers at
  once" cannot happen (an advance clears the next count); `pvp.md` and `classes.md` had no
  text on knockback on players; `item_tiers.md` §5 never described tinted bottles.

**Human tests proposed by the lanes:** knockback by feel on desktop and web (a fox, a
wolf, a bear; a pack of three or more wolves pushing once; an elite golem or the construct;
a King's Shatter, and whether the rift pulse still reads as its own attack); gathering in
enemy home land (an Accord player in Throng land digs a herb, a wild crop, grass and a
flower bare-handed and with a skill selected, right-clicks an apple and a ripe bush, and
fails to dig a tree or dirt and to place a block or torch into grass, onto a flower or water
into grass); the Character page on desktop and web (click through the rows, hover Str, Int
and Dex, close and reopen for HP, change the cloak in Effects mode).

**Round-end gates** (round88, 2026-11-27): the full fixture set 402 of 402 after one
fixture-setup fix (`r37_cb` and `r81_bugs` cut `equipment_changed` and lacked STATS's new
per-slot armor cache); `check_fresh_server.py`, `check_upgrade.py` (0.88.0, compatible),
`r28_design/validate.py --game` (0 errors), `r29_e4/income.py --check`, the bat mesh check and
`building_templates/check.py` (286 templates, 0 errors) pass; the smoke boot on seed 88 is
clean (the random-seed boot hit the pre-existing arena grade fallback, Carry-overs). The
whole-round review against main: LAND, two stale texts fixed by the coordinator.

## Carry-overs

- **The arena's grade fallback** (found at the round end, not caused by the round): the
  smoke boot on the random seed 9131126853283075236 logged `[GRUG-SEVERE]` "the arena's ground
  is steeper than its grade rule | breach_site.lua fallback needs 198 nodes of blend, at most
  128 are built"; main 0.87.0 logs the same on that seed. The round-end boot on seed 88 was
  clean. For a later mapgen round (BACKLOG "Other world work").
- **The Warrior's knockback skill** (ruling 7, §7) is open for a later class round. The
  mob displacement it would use (`grug_mobs.displace_mob`) refuses a destination in lava or
  fire, without a floor or inside a block, and never pushes elite, rare or boss mobs, but
  checks only the destination, not the way there: a long push could cross a narrow gap.
  The user worries about pushing mobs into lava in Expeditions.
- **Knockback values** are starting values by feel, tuned after the user's test. Some boss
  pushes are weaker than before: a King's Shatter totals 8 m/s where builtin used to add
  about 8.8 on top, and the rift pulse (7) is below the rift boss's own class (7.5), so it
  adds only lift. An Expedition pack's rock no longer pushes; The Last Mint's lava seeps
  push light (2.5) instead of about 8.8. Window entries are not cleared on leave (weak
  keys; one per session), and the Kraken's downward drag stays a mechanic of its own.
- **The story purple** of the quest markers stays open with the user, who checks it in the
  game.
- **Unused art left in place:** `grug_map_quest_story_locked.png` (named by the art
  generators `r57_qsys/render_story_icons.py`, `map_icon_rework`, `r67_art`) and
  `grug_traders_item_potion_healing_weak.png` (named by `tools/gen_mob_item_textures.py`,
  `tools/r88_icons/draw_sheet.py` and `tools/ui_polish_review/assets.py`, which still maps
  the merchant potion to it). The `low` marker draws the file named
  `grug_map_quest_locked.png`; a rename would touch the art pipeline.
- **Engine probes still naming the PvP layer** (historical receipts, not fixtures):
  `r47_ml`, `r64_map/bench_window.lua`, `r66_map`, `r44_mq`'s probe, `r58_lift`,
  `r85_territory`; rerun, they fall back to Quests or find no rows. world_map.md's Round 47
  size comparison ("PvP 4.9 KB") is a historical measurement.
- **Help text:** Help → Quests' "the map (Z) shows a ? only for your active quests" has been
  out of date since the Round 47 Quests layer.
- **GATHER notes:** `with_digging` has no restore on error (as in
  `grug_housing/protection.lua`; harmless while a Lua error stops the server, but a future
  `pcall` around a dig could leave one grass cell placeable for that player until leave);
  `grug_gathering.enemy_home_gatherable` has no caller and does not know the dig context; a
  visitor may take player-placed apples outside a claim; a source inside a claim in enemy
  home land shows the territory hint rather than the claim hint (unchanged); the berry
  bush counts as leaves but puts back the bare bush.
- **STATS notes:** a bag resize while the page is open resets the selection to HP; a window
  closed without `quit` (another mod's form) keeps the cached selection until the next
  build; the Int tooltip with gear Int and the Scout's Dex tooltip have two lines; the
  Effects mode's once-a-minute re-send closes an open cloak dropdown; a row's text does not
  recolour on hover (only the fill shows).
- **QOL notes:** when an advance unlocks Basic recipes the Crafting tab can be resent twice
  (harmless); the advance at the join is not silent (chat line, sound, feed line).
- **ICONS notes:** Mana (swirl) and Focus (star) are both blue bottles that differ only by
  the emblem; `nodes.json`'s two alchemist tiles were edited by hand, not regenerated by an
  engine run.
