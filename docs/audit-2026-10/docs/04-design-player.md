# D4 — Player-system design documents vs code

**Scope.** `docs/design/classes.md`, `skill_trees.md`, `combat_stats.md`,
`progression.md`, `parties.md`, `pvp.md`, `quests.md`, `housing.md`,
`character_visuals.md`, `sound.md`, `playtest_quality_revision.md`; plus
`docs/planning/pvp-plan.md` (only to check that `pvp.md` reflects what was
built). Code: `mods/PLAYER/grug_abilities`, `grug_classes`, `grug_xp`,
`grug_skills`, `grug_pvp`, `grug_parties`, `grug_factions`, `grug_quests`,
`grug_housing`, `grug_visuals`, `grug_trinkets`, `grug_achievements` (for
`character_visuals.md` §5b); `mods/CORE/grug_sounds`, `grug_ambience`; and
`grug_core` where the documents name it as the owner (pools, damage fit,
threat, status keys).

**Baseline.** `0f169898` (main), read-only.

**Method.** Every number in the class tables, talent tables, XP curve, PvP
timers, housing constants, party limits, quest limits, look-option counts,
stature values, achievement tiers and the sound approval lists was compared
with its code constant. The XP curve was recomputed in Python from
`grug_xp/init.lua`. Quest counts were taken from the JSON files, against the
commit before Round 36 Lane E (`7041baad^`). Shipped `.ogg` files were
compared with every `tools/r3*/approved.txt`. Each "absent" claim was checked
by grep under several names. Gaps already recorded in
`docs/maintenance/findings.md` and `BACKLOG.md` (WP34, WP42 battles,
friendly-guard healing, the removed systems) are not reported again.

## Verdict

| Document | Verdict |
|---|---|
| `classes.md` | **mostly current.** Every kit number matches the code. A few WP4/WP6/WP14 status phrases are stale, and there is one WoW name. |
| `skill_trees.md` | **mostly current in §1–§2; stale elsewhere.** All 64 talent values match the code. The respec price, about 178 pinned line citations, the "tasks" table, the old status prose and the WoW names are out of date or break project rules. |
| `combat_stats.md` | **mostly current.** Every formula checked matches the code. About 50 line citations are stale. A few old WP labels remain. The Scout is missing from §1/§2, and the trinket regen and rage sources are not mentioned. |
| `progression.md` | **current.** XP curve, bands and kill and gathering XP are exact. One wording slip ("one data file per zone"). |
| `parties.md` | **current.** The minimap party markers are not mentioned. |
| `pvp.md` | **current.** It reflects the Round 31 build, including the round31-plan changes to pvp-plan.md, and the Round 36 commanders. |
| `quests.md` | **current.** 540 quests, 20 active, 10 tracked, use-at-a-place, copper formula and fortress quests all match. |
| `housing.md` | **current.** Every constant matches. |
| `character_visuals.md` | **current.** Look counts, stature and the 20 achievements all match. |
| `sound.md` | **mostly current.** Every `grug_*` sound file is approved. The gate text does not say that inherited base sounds were exempted, and two PvP wordings are stale. |
| `playtest_quality_revision.md` | **current but bloat.** It is a link index with no rules. |

Summary:

- The **gameplay numbers are in very good shape**. Every Warrior, Mage and
  Priest base ability (cost, cooldown, range, damage formula) matches
  `grug_abilities/kits.lua`. All 64 talent rows match `grug_classes/talents.lua`
  and `scout_talents.lua`. The XP table matches `grug_xp` level for level.
- **One real number drift:** `skill_trees.md` still gives the 51–60 respec
  price as 6s. Code and `economy.md` say 5s25c (changed in `8f4d5638` on
  2026-10-05 without touching `skill_trees.md`).
- **The worst agent trap is pinned citations.** `skill_trees.md` has about
  178 `file:line` citations frozen at `70dda602`, and `combat_stats.md` has
  about 50. Spot checks show they point at unrelated lines.
- `skill_trees.md` §7 "tasks" and §1.1 present work as open that is long
  done: the Holy rename, the rage retune, the removal of `/class`, the
  Sprint text in `mounts.md`.
- **WoW references in living design docs** break the project rule:
  "Power Word: Shield" (twice in `skill_trees.md`), "Battle Shout"
  (`classes.md`), §2.11's list of that MMO's spell and talent names, and the
  code id `cast_frost_nova`.
- `sound.md`'s gate says no file ships without a listening-page pick. About
  95 inherited files (minetest_game, doors, xpanes, mobs_redo, the eat and
  drink cues) ship without one, by an unwritten Round 34 exemption, and
  `bosses.lua` plays `mobs_spell` at gain 1.0 out to 160 m outside
  `grug_sounds`.
- Faction naming is clean: only "The Accord" and "The Throng" appear in the
  documents in scope and in the code.
- `docs/planning/pvp-plan.md` is **tracked** in git, not untracked as the
  brief says. `pvp.md` cites it correctly.

### Comparison tables

**Base kits (doc vs code).** Doc: `classes.md` §2b–§5. Code:
`grug_abilities/kits.lua`. All match.

| Class | Ability | Cost doc / code | Cooldown or charge doc / code | Range | Effect formula |
|---|---|---|---|---|---|
| all | Strike | free / `{}` | none / none | 3 / 3 | weapon + melee attr/10 ✓ |
| Warrior | Charge | +15 rage / `add_rage 15` | 10 s / 10 | 12 / 12 | 12 % of `B(L)`, 1.5 s stun ✓ |
| Warrior | Mighty Blow | 25 rage / 25 | swing, none / none | 3 / 3 | floor(w×1.5)+melee ✓ |
| Warrior | Hamstring (talent) | 10 rage / 10 | 6 s charge / `charge = 6` | 3 / 3 | 50 % slow 5 s ✓ |
| Warrior | Taunt | free / `{}` | 8 s / 8 | 8 / 8 | forced 3 s, top×1.1 ✓ |
| Mage | Fireball | 6 % / 6 | 1 s interval / `cast_interval = 1` | 20 / 20 | baseline + SP, 20 m/s, max 8 active ✓ |
| Mage | Ice Nova | 10 % / 10 | 12 s / 12 | radius 5 / 5 | ¼(baseline+SP), root 4 s, slow 3 s ✓ |
| Mage | Blink | 8 % / 8 | 15 s / 15 | 10 m / 10 | min 1.5 m move ✓ |
| Priest | Smite | 5 % / 5 | 2 s / 2 | 20 / 20 | 1.5×(baseline+SP) ✓ |
| Priest | Heal | 8 % / 8 | 4 s / 4 | 15 / 15 | 25 % pool × support ✓ |
| Priest | Shield | 8 % / 8 | 10 s / 10 | (15) / 15 | 25 % pool × support, 15 s ✓ |
| Priest | Mend (talent) | 6 % / 6 | 8 s / 8 | 15 / 15 | 8 % every 3 s × 4 ticks ✓ |

Resource ledger: rage +8 per swing, +3 per hit taken and −5/s out of combat
match `init.lua:93-95`; the orc +1 matches `grug_classes/init.lua:192`. The
mana pool `round(20+5L+0.66L²)` matches `grug_core/combat.lua:85-88`; regen
matches `init.lua:131-144`. The cast counts in `classes.md:125-128` were
recomputed and match.

**Talents.** All 64 rows in `skill_trees.md` §2.1–§2.8 match the code
`effects` tables: ranks, per-rank values, keys, tier gates `{0,5,12,20}` and
rank shape `{5,4,3,3}` (`talents.lua:30-32`). Unbroken ×1.65 is
`grug_core.PROTECTION_ARMOR_MULTIPLIER`, Cold Focus `1 + 2×bonus` is
`init.lua:141`, and the Whitehot and Recompense cost overrides are
`init.lua:150-162`.

**XP curve.** Recomputed from `grug_xp/init.lua:20-44`. Every band matches
`progression.md:35-43`: 4,200 / 11,750 / 21,960 / 35,100 / 51,140 / 70,070,
194,220 in total. The spot rows L1, 2, 10, 20, 21, 30, 40, 41 and 59 also
match. Kill tiers ×1/×4/×6, boss ×1 and critter 0 match `grug_mobs/levels.lua:70-86`;
the gather ratios 0.10/0.20/0.33 match `grug_xp` `GATHER_XP_RATIO`.

**Quests.** 42 files (32 zone files plus 10 `.front` files), 540 quests: 515
before Round 36 plus 25 new, so 491 + 24 + 25 ✓. Per faction there are 12
fortress quests (call, steel, trophies, scouting and 8 raids) ✓. Tags:
`accord_main` 17 and `throng_main` 14 (existing front climaxes folded in).
There are 55 repeatables and 18 use-at-a-place objectives. The 20-quest cap
(`state.lua:282`), 10 tracked (`state.lua:5`) and the copper `P` table
(`registry.lua:99`) all match.

**PvP / housing / parties / visuals.** All constants checked match:
`grug_pvp/rules.lua:11-14` (60/60/10/15 s, y −501); `grug_housing/registry.lua:33-50`
(radius 50, y −100, 26,160 s, 99, 300 s, 5 lumps, 43,200 s, margin 16) and
`stone.lua:23` dig times; `grug_parties` (10 members, 120 s invitations,
1 s rate, 10 pending, class colours); `grug_visuals/looks.lua` option counts
per race and `compose.lua:44-51` stature values; the
`grug_achievements/catalog.lua` tiers, faction rows and cloak ids.

## Mismatch table

| ID | Sev | Category | Direction | Doc location | Short description |
|---|---|---|---|---|---|
| DP-01 | Medium | Outdated / Contradiction | doc stale → fix doc | skill_trees.md:240 | 51–60 respec is "6s"; code and economy.md say 525c (5s25c) |
| DP-02 | Medium | Unclear/Agent-trap | doc stale → fix doc | skill_trees.md:58-62 (~178 cites); combat_stats.md (~50 cites) | `file:line` citations pinned to `70dda602` point at unrelated lines today |
| DP-03 | Medium | Outdated / Agent-trap | doc stale → fix doc | skill_trees.md:98-104, :1603-1617 | "Tasks" and "remaining Holy sites" listed as open are done |
| DP-04 | Medium | Wrong (project rule) | doc stale → fix doc (§2.11: Jan decides) | skill_trees.md:309-310, :1255-1256, :616-723; classes.md:725 | WoW names in living docs (Power Word: Shield, Battle Shout, the §2.11 MMO name list); code id `cast_frost_nova` |
| DP-05 | Medium | Unclear/Agent-trap | unclear → Jan decides | sound.md:18-30, §3.5 | The gate says no unapproved file ships; ~95 inherited files ship unlisted; `mobs_spell` used as an uncatalogued dragon-return cue |
| DP-06 | Low | Unclear | unclear → Jan decides | skill_trees.md:703-713 | An open "question for the user" sits in a design doc that should hold decided rules only |
| DP-07 | Low | Outdated / Contradiction | doc stale → fix doc | skill_trees.md:347-348 | Charge said to deal "3 damage"; it is 12 % of a base hit since Round 35 |
| DP-08 | Low | Wrong | doc stale → fix doc | skill_trees.md:247-253 | "`/xp` can lower a level": `/xp` only grants a positive amount |
| DP-09 | Low | Outdated | doc stale → fix doc | classes.md:164-168, :616; combat_stats.md:779-781 | "Stubs until WP6", "until WP20 ships parties": both delivered; the heal-threat group is still healer + target |
| DP-10 | Low | Unclear | unclear → Jan decides | classes.md:724 | "Warrior shield abilities → after WP14": WP14 is delivered and no such ability exists or is scheduled |
| DP-11 | Low | Missing | doc stale → fix doc | classes.md:636-642; combat_stats.md:1048-1054 | Trinket rage, regen, heal and kill effects are missing from the "ledger" sections |
| DP-12 | Low | Missing | doc stale → fix doc | combat_stats.md:39-49 | No Scout growth or HP factor in §1/§2; code uses an implicit fallback of 1.0 |
| DP-13 | Low | Outdated | doc stale → fix doc | combat_stats.md:1127-1129 | "we build `grug_offhand` (list "offhand" + HUD slot)": it is a list in `grug_inventory`, not a mod |
| DP-14 | Low | Outdated | doc stale → fix doc | sound.md:107, :124 | "Enable PvP button" and "PvP off": the button is "Flag me for PvP" and there is no unflag |
| DP-15 | Low | Missing | doc stale → fix doc | parties.md:68-69 | The minimap (WP50) also shows party members; only the atlas is named |
| DP-16 | Low | Outdated | doc stale → fix doc | progression.md:5 | "one data file per zone": 32 zone files plus 10 `.front` files |
| DP-17 | Low | Outdated | doc stale → fix doc | skill_trees.md:289-292, :437-439; design/README.md:29 | Stale status prose ("X3 not authorized", "no code exists yet", "skill trees follow with WP11") |
| DP-18 | Low | Unclear | unclear → Jan decides | character_visuals.md:309; skill_trees.md:419 | "Last Word" is both an achievement and the Priest capstone |
| DP-19 | Low | Bloat | doc stale → archive | skill_trees.md:725-1617 | About 900 lines of implementation plan, KAT, lane cut, rulings and supersession history inside the design doc |
| DP-20 | Low | Bloat | doc stale → archive | playtest_quality_revision.md | A pure link index, no rules |

Counts: High 0, Medium 5, Low 15.

## Details

### DP-01 — Respec price for 51–60 is stale

- **Doc says.** `skill_trees.md:239-240`: "The six bracket prices are WP44's
  income-derived `grug_classes.RESPEC_PRICES` (15c, 35c, 75c, 2s, 6s, 12s;
  `economy.md` §4)."
- **Code does.** `mods/PLAYER/grug_classes/talents_ui.lua:11`:
  `RESPEC_PRICES = {15, 35, 75, 200, 525, 1200}`. `economy.md:173-174` says
  "15c, 35c, 75c, 2s, 5s25c and 12s". Commit `8f4d5638` (2026-10-05, "the
  51-60 respec 525") updated the code, `economy.md`, `item_tiers.md` and
  `items_crafting.md`, but not `skill_trees.md`.
- **Impact.** Two documents disagree. An agent following `skill_trees.md`
  would "restore" 600c or write a wrong test.
- **Suggested fix.** In `skill_trees.md:240` drop the literal list and write
  "the six bracket prices are `grug_classes.RESPEC_PRICES`, listed in
  `economy.md` §4". `economy.md` is the price owner, so only one place
  changes next time.

### DP-02 — Pinned line citations are stale

- **Doc says.** `skill_trees.md:58-62`: "Everything this design says about
  the code is a `file:line` citation into `mods/` at **`70dda602`**". The file
  has about 178 such citations, and `combat_stats.md` has about 50 (counted
  with `grep -oE '[a-z_]+\.(lua|md):[0-9]+'`).
- **Code does.** Examples:
  - Grudge and Onset cite "`grug_abilities/init.lua:1566-1567`, the one
    effective cooldown arm" (`skill_trees.md:303, :332`).
    `effective_cooldown` is at `init.lua:969`; the arm is at `init.lua:1563-1564`.
  - Bellow cites `kits.lua:437-465`. That range is now the Hamstring proc;
    Taunt starts at about `kits.lua:456`.
  - Hamstring cites `kits.lua:403`, Mend `:812`.
  - `combat_stats.md:105-106` cites `grug_core/combat.lua:29-65` for the
    mob-level malus. Those lines are the mounted-combat comment; `level_malus`
    is at `combat.lua:118-127`.
  - `combat_stats.md:490` cites `grug_mobs/stag.lua:21` for a `run_velocity`
    site; that line is blank.
  - `skill_trees.md:46` cites `classes.md` "`:459`" for Mend; the row is at
    `classes.md:716`.
- **Impact.** An agent told to "edit the line the design cites" edits the
  wrong code. The note "nothing under `mods/` is changed by this lane" has
  not been true for 25 rounds.
- **Suggested fix.** Replace line numbers with symbol citations
  (`grug_abilities.effective_cooldown`, the `taunt` registration in
  `kits.lua`, `grug_core.level_malus`) and delete the `70dda602` paragraph.
  If citations must stay, mark the block "historical, at `70dda602`". Apply
  the same to `combat_stats.md` §3 (lines 489-493, 515-523, 106, 1076-1077).

### DP-03 — "Open" tasks and "remaining Holy sites" are done

- **Doc says.**
  - `skill_trees.md:98-104`: "Two sites in the repo still call the Priest
    healing tree 'the **Holy** tree' … `classes.md:464` and
    `kits.lua:650` … the rename has to reach the two that are left — §7, task 5."
  - §7 (`:1603-1617`) lists these as "tasks": 1 (mounts.md Sprint), 4
    (remove `/class`, fix comments), 5 (Holy rename), 8 (re-tune rage
    12→8, 4→3, decay 5/s), 9 (ranged bonus).
- **Code does.**
  - `grep -rn Holy docs/design mods/PLAYER` finds the word only inside
    `skill_trees.md` itself.
  - Rage is `RAGE_PER_SWING = 8`, `RAGE_PER_HIT_TAKEN = 3`,
    `RAGE_DECAY_PER_SECOND = 5` (`grug_abilities/init.lua:93-95`), and
    `classes.md:636-642` already carries the ledger.
  - No `/class` chat command is registered (`selection.lua:889, :953`
    register `char` and `race` only).
  - `mounts.md:293` carries the Sprint exception.
  - Task 9 says "Delivered". Some class-change comments remain:
    `grug_visuals/apply.lua:477`, `grug_abilities/init.lua:2070`,
    `grug_inventory/equipment.lua:703, :795`.
- **Impact.** An agent reads §7 as a work queue and re-applies the rage
  retune or hunts for a nonexistent "Holy" string.
- **Suggested fix.** Rewrite §1.1's paragraph as "Mercy, formerly Holy;
  renamed everywhere". Turn §7 into a closed record with a status per row
  (done / remaining: the four code comments), or move it to the archive
  (see DP-19).

### DP-04 — WoW references in living docs and code

- **Doc says.**
  - `skill_trees.md:309-310`: "a Priest's Power Word: Shield cast onto the
    Warrior overwrites Hold Ground".
  - `skill_trees.md:1255-1256`: "four sources write it: Power Word: Shield
    (Priest base kit), …".
  - `classes.md:725`: "Buffs/auras (e.g. Battle Shout)".
  - `skill_trees.md` §2.11 (`:616-723`) lists that MMO's names verbatim as
    the reasons for renames: Bloodthirst, Deep Freeze, Ice Ward / Ice
    Barrier, Frostbite, Tendon Rip, Binding Shot, Fiery Brand, Hawk Eye,
    Surefooted, Fervor, "Paladin/Priest", "Rogue", the Priest "… Word:"
    family, "Last Stand".
- **Code does.** The shipped Priest skills are named Shield, Heal and Mend
  (`kits.lua`). The project rule (memory "Fraktionsnamen, kein WoW") forbids
  WoW and Blizzard references in the repo. The code still carries the
  internal id `cast_frost_nova` and the file
  `grug_sounds_cast_frost_nova.ogg`: `grug_abilities/init.lua:716`,
  `grug_sounds/init.lua:64, :163`.
- **Impact.** Rule violation, and the docs keep naming the very spells the
  Round 31 rename removed. Agents copy names from docs.
- **Suggested fix.**
  - Replace "Power Word: Shield" with "the Priest's Shield" (twice).
  - Replace "e.g. Battle Shout" with "e.g. a party-wide war cry".
  - Move §2.11's rename table, second-pass table and medium-risk table to
    `docs/archive/design/` with neutral wording. Keep in the living doc only
    "all talent names passed the ruling-5/21 name audit (archive link)".
  - Optional code-lane item: rename the sound event id `cast_frost_nova` to
    `cast_ice_nova`. That is a new file name; under sound.md §1 a renamed
    file with identical bytes may need Jan's nod.

### DP-05 — Sound gate vs inherited and uncatalogued sounds

- **Doc says.** `sound.md:18-30`: "**No sound enters the game unless the
  user approved that exact file on a listening page** … Only listed files
  ship. Each lane's fixture fails on an `.ogg` its list does not name."
  §3.5 lists the boss cues.
- **Code does.**
  - All 145 `grug_sounds`/`grug_ambience` files, the music and
    `menu/theme.ogg` are in `tools/r34_s1a`, `r34_s1b`, `r34_s2` or
    `r35_f/approved.txt` ✓.
  - These ship without an entry:
    - 77 `mods/BASE/default/sounds/*.ogg`, including `player_damage.ogg`;
    - 8 `doors_*` and 2 `xpanes_*` files;
    - `mods/ENTITIES/mobs/sounds/mobs_punch|spell|swing.ogg`;
    - `grug_food_eat.1-3.ogg` and `grug_alchemy_drink.ogg`.
  - `round34-plan.md:9-11, :121` kept them by decision ("the minetest_game
    footsteps stay"), and Round 35 reused `default_dig_cracky` for ore digs
    without a page (`round35-plan.md:82, :194`;
    `grug_materials/dig_sounds.lua:9`).
  - `grug_mobs/bosses.lua:750` plays `core.sound_play("mobs_spell", {gain = 1.0, max_hear_distance = 160})`
    for the dragon-return warning, outside `grug_sounds` and not listed in
    §3.5. The farming hoe, planting and fishing code also play `default_*`
    sounds directly (`grug_farming/hoes.lua:41`, `init.lua:302`,
    `grug_fishing/init.lua:250`).
- **Impact.** Read literally, the gate makes every inherited file a
  violation. Read loosely, it lets a lane reuse an inherited file at a new
  event (as `bosses.lua` does, at full gain over 160 m) without a page. An
  agent cannot tell which reading is meant.
- **Suggested fix.** Add to §1: "Inherited set: the minetest_game, doors,
  xpanes and mobs_redo files and the pre-Round-34 eat/drink cues ship as
  accepted in Round 34. Reusing one at its original kind of event (digging,
  footsteps, doors) needs no page; using one at a new game event does."
  Then Jan decides whether the dragon-return `mobs_spell` cue stays
  (list it in §3.5), gets a page, or goes silent.

### DP-06 — Open question inside a design doc

- **Doc says.** `skill_trees.md:703-713`: "**A question for the user, not
  an automatic rename.** … the Priest's Sharpened Word / Swift Word / Word
  of Ruin / Last Word extend a well-known MMO's Priest '… Word:' spell
  family … Clean replacements if the user wants them …". `skill_trees.md:65-67`
  and `AGENTS.md` say design docs contain decided rules only.
- **Code does.** The talents ship with the Word names (`talents.lua:716-743`).
- **Impact.** The document carries an unresolved question, so it is unclear
  whether the names are final.
- **Suggested fix.** Jan rules (keep or rename). Record the ruling in one line
  and move the analysis to the archive with §2.11 (DP-04).

### DP-07 — Charge damage note contradicts classes.md

- **Doc says.** `skill_trees.md:347-348`: "Its 12 m reach, 3 damage and 15
  rage are still untouched by any talent."
- **Code does.** `kits.lua` Charge `values`:
  `0.12 * grug_core.baseline_melee_total(level)`, described as "12 % of a
  base hit before the damage scalar (Round 35): the former flat 3".
  `classes.md:613` and `skill_trees.md:291-292` say the same.
- **Impact.** Minor. An agent may look for a flat 3.
- **Suggested fix.** "Its 12 m reach, its 12 % of a base hit and its 15 rage
  are untouched by any talent."

### DP-08 — `/xp` can no longer lower a level

- **Doc says.** `skill_trees.md:247-253`: "`/xp` can lower a level
  (`grug_xp/init.lua:142-162`) … the talent state is wiped".
- **Code does.** `grug_xp/init.lua:268-290`: `/xp` only shows XP or runs
  `give <player> <positive amount>`. The free reset on a level drop still
  exists (`talents.lua:1224-1250`, `stats.lua:218`). Its only trigger now is
  a direct `grug_xp.set_xp` call.
- **Impact.** Low. An agent may try to test the reset through `/xp`.
- **Suggested fix.** "An administrative level drop (only through
  `grug_xp.set_xp`; the `/xp` command grants only) resets talents
  completely and for free." Jan decides whether the path is kept or dropped
  (code lane).

### DP-09 — Stale WP4/WP6/WP20 status phrases

- **Doc says.**
  - `classes.md:164-168`: "**Threat hooks are stubs in WP4** … WP6 replaces
    the stubs with the real threat table".
  - `classes.md:616`: "(… threat part + force duration land with WP6)".
  - `combat_stats.md:779-781`: "Until WP20 ships real parties, 'the group'
    is the MVP pair **healer + heal target**".
- **Code does.** The threat table is real (`grug_core/combat.lua`
  `add_threat`, `taunt`). Parties shipped, yet `add_heal_threat`
  (`combat.lua:900-928`) still credits mobs fighting the healer or the
  target only. `parties.md:24-26` rules out party-owned mechanics.
- **Impact.** "Until WP20" invites an agent to extend heal threat to the
  whole party, which no ruling asks for.
- **Suggested fix.** Write the current rule: "the group is the healer and
  the heal target; parties do not change it (`parties.md`)". Remove the
  WP4/WP6 future tense.

### DP-10 — Warrior shield abilities: deferral trigger passed

- **Doc says.** `classes.md:724`: "Warrior shield abilities → after WP14
  (offhand/shields)."
- **Code does.** WP14 is closed as delivered (`BACKLOG.md:15`,
  `findings.md`). No shield ability is registered (`grep -n shield kits.lua`
  finds only the Priest `shield_spell`). No BACKLOG item schedules one.
- **Impact.** It is unclear whether this is planned V1 work or post-V1.
- **Suggested fix.** Jan decides. Either "post-V1 (no WP)" or a BACKLOG entry.

### DP-11 — Trinket combat effects missing from the ledgers

- **Doc says.** `classes.md:636-642` is "The rage ledger", listing every
  source. `combat_stats.md:1048-1054` gives the full mana-regeneration
  formula.
- **Code does.** `grug_trinkets/init.lua`:
  - `accepted_weapon_hit` grants Battlebeat rage per weapon hit (:108-117);
  - `xp_eligible_kill` (Reclaimer) restores HP and mana or rage on a kill;
  - `after_player_hit` (Last Light) adds an absorb below 25 % HP;
  - outgoing-heal and potion percentages;
  - `grug_core.trinket_mana_regen`, added in `grug_abilities.mana_regen_rate`
    (`init.lua:134-143`).

  The owner is `items_crafting.md` §6.2.
- **Impact.** Low. A balance pass on rage or regen built from these
  sections misses a term.
- **Suggested fix.** One sentence in each section: "plus trinket specials
  (`items_crafting.md` §6.2: Battlebeat rage, Reclaimer, trinket mana
  regen)".

### DP-12 — Scout missing from combat_stats §1/§2

- **Doc says.** `combat_stats.md:41-42`: "Growth per level … Warrior …
  Mage … Priest" only. `:49`: "Class factors are Warrior 1.20, Priest 1.00,
  Mage 0.90."
- **Code does.** `grug_classes/scout.lua:12` sets `growth = {str = 1, int = 1, dex = 2}`.
  `stats.lua:7` has no `scout` in `HP_CLASS_FACTOR`, and
  `get_hp_class_factor` falls back with `or 1` (`stats.lua:29`). `scout.md:43`
  documents the growth; nothing documents the HP factor.
- **Impact.** The Scout's HP factor exists only as an implicit default.
- **Suggested fix.** Add the Scout row (growth +1/+1/+2, HP factor 1.00) to
  §1/§2 and to the anchors table. Optionally also add `scout = 1.00` to
  `HP_CLASS_FACTOR` (code lane).

### DP-13 — `grug_offhand` is not a mod

- **Doc says.** `combat_stats.md:1127-1129`: "we build `grug_offhand` after
  VoxeLibre's `mcl_offhand` pattern (inventory list `"offhand"` + HUD slot)".
- **Code does.** No `grug_offhand` mod exists (`find mods -name grug_offhand`
  finds nothing). The list is `OFFHAND_LIST = "grug_offhand"` in
  `grug_inventory/equipment.lua:23`, as `inventory_equipment.md:82` says.
- **Suggested fix.** "The offhand is the `grug_offhand` list of
  `grug_inventory` (`inventory_equipment.md` §2)."

### DP-14 — Stale PvP wording in sound.md

- **Doc says.** `sound.md:107`: "the **Enable PvP button**". `sound.md:124`:
  "PvP off and every automatic PvP flag change" are silent.
- **Code does.** The button is "Flag me for PvP" (`pvp.md:41`,
  `grug_pvp/page.lua`). The event is `pvp_on` (`grug_sounds/init.lua:144`).
  There is no manual unflag (`pvp.md:48-49`).
- **Suggested fix.** "the 'Flag me for PvP' button". Drop "PvP off".

### DP-15 — Party markers on the minimap

- **Doc says.** `parties.md:68-69`: "The atlas shows online member
  positions and headings".
- **Code does.** `grug_map/providers.lua:16-22` registers a `party` marker
  provider used by the Map tab and the round minimap (`minimap_view.lua:8`).
- **Suggested fix.** "The atlas and the minimap show …".

### DP-16 — "One data file per zone"

- **Doc says.** `progression.md:5`.
- **Code does.** `grug_quests/data/zones/` holds 32 `<zone>.quests.json` and
  10 `<zone>.front.quests.json` files (`quests.md:361-375` is correct).
- **Suggested fix.** "one data file per zone plus a front file per front
  host".

### DP-17 — Stale status prose

- `skill_trees.md:289-292`: "Round 11 implements only the armor-rating
  portion of lane X3 … does not authorize the other X3 keystones". The
  header (`:19-21`) says Round 12 completed X3.
- `skill_trees.md:437-439`: "because none of the code exists yet" (the
  Scout trees shipped in Round 11).
- `docs/design/README.md:29`: `classes.md` status "skill trees follow with
  WP11".
- Code comment `kits.lua:410-415`: "Until lane X3 wires the grant, NO
  Warrior has it" (it is granted through Ruin's keystone).
- **Suggested fix.** Delete or change these to past tense.

### DP-18 — "Last Word" name collision

- `character_visuals.md:309` defines the achievement Last Word ("kill
  Watch-Captain Huskell or Paymaster Chirr"; `grug_achievements/catalog.lua`
  `last_word`). `skill_trees.md:419` defines the Priest capstone Last Word
  (`talents.lua` `last_word`), which also has a talent-window id `last_word`
  (`kits.lua` Word of Ruin).
- **Impact.** Grep and agent confusion only. No functional clash: the
  namespaces are separate.
- **Suggested fix.** Jan decides whether to keep it. If renaming, the
  achievement is cheaper (its cloak "Final Seal" is unaffected).

### DP-19 — skill_trees.md carries the implementation plan

- `skill_trees.md` has 1617 lines. The living rules are §1–§2 (`:70-724`).
  §3 (data model, hook, persistence, UI mock-up, KAT, file table,
  aggregator prerequisite; `:725-1300`), §4 (lanes), §5 (rulings with
  "what each replaced" at `main:NNN`), §6 (closed decision record) and §7
  (tasks, DP-03) are delivery history.
- **Impact.** Most stale citations (DP-02) and the stale tasks (DP-03) live
  here. Agents load 1600 lines to find a talent value.
- **Suggested fix.** See the structure changes below.

### DP-20 — playtest_quality_revision.md is a link index

- `playtest_quality_revision.md:1-5` says it "defines no additional rules".
  Inbound links: `README.md:390`, `docs/design/README.md:56`, and the
  `docs/research/round18-*` and `docs20-play-audit.md` documents.
- **Suggested fix.** Move it to `docs/archive/design/` and repoint the two
  README links. The research links may keep pointing at the archived copy.

## Proposed structure changes

1. **Split `skill_trees.md`.** Keep §1 (shape, gates, arithmetic, respec)
   and §2 (talent tables, the level-proof rule, rule-breakers) as the living
   design, about 650 lines, with symbol citations only. Move §2.11 (name
   audit), §3.7–§3.10 (KAT, file table, aggregator, class-change removal),
   §4–§7 and the `70dda602` citation layer to
   `docs/archive/design/skill-trees-wp11-delivery.md`. Keep §3.2 (the hook
   and effect-key vocabulary), §3.3 (persistence), §3.4 (granting) and
   §3.11 (absorb stacking) only as current-rule summaries.
2. **Archive `playtest_quality_revision.md`** (DP-20).
3. **`combat_stats.md`:** replace the §3 line-citation lists (speed and
   reach sites) with "the `run_velocity`/`reach` fields of each
   `grug_mobs/<mob>.lua`". A fixture already owns the exact list.
4. **`sound.md` §1:** add the "inherited set" paragraph (DP-05) so the gate
   is checkable.
5. Optional: one sentence in `classes.md` and `combat_stats.md` pointing at
   `items_crafting.md` §6.2 for trinket combat effects (DP-11), instead of
   duplicating them.

## Open questions for Jan

1. **Sound gate (DP-05):** confirm that the inherited minetest_game,
   doors, xpanes and mobs_redo sounds and the old eat/drink cues are
   accepted as they are. Should the dragon-return warning keep `mobs_spell`
   (gain 1.0, heard to 160 m), get a listening page, or go silent?
2. **Name audit (DP-04, DP-06):** may §2.11 (which quotes that MMO's spell
   and talent names) move to the archive in neutral wording? And is the
   open "Word"-family question settled as "keep the names"?
3. **Warrior shield abilities (DP-10):** WP14 is delivered. Is a shield
   ability post-V1, or does it need a BACKLOG entry?
4. **Level-drop talent reset (DP-08):** `/xp` can no longer lower a level.
   Keep the reset code path for API callers, or remove it?
5. **"Last Word" (DP-18):** keep the shared name for the Priest capstone
   and the achievement?
6. **Scout HP factor (DP-12):** confirm 1.00 (the current implicit default)
   as the decided value.
