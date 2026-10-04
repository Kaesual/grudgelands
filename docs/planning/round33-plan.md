# Round 33 — Items, professions and achievements: round plan

Coordinator: Claude (Opus 5.5), 2026-10-04. Status: **complete locally
2026-10-04** ([completion and GUI checklist](#completion-2026-10-04));
approved by the user 2026-10-04. The in-round rulings (crit and Dexterity,
profession families, the achievement picks, every DS option) are in §2.9a,
[item_tiers.md](../design/item_tiers.md) and the completion section; where
they differ from §2 and §3, they win.

The items and professions revision the Round 32 study R3
([items-professions-analysis-2026-10.md](../research/items-professions-analysis-2026-10.md))
prepared, settled in a design session with the user (2026-10-03/04, §2), plus
a cosmetic cloak and achievement system. Routing as before: Claude
orchestrates, Opus implements and reviews (independent review per code lane),
GPT-6 Astra writes the achievement and cloak proposals and paints the cloak
textures.

Not in this round: sound (Round 34; the seven open decisions in the BACKLOG
"Sound (V1)"), WP9 (a round of its own after that), a player market, quest
gear rewards.

## 1. Lanes and waves

| Lane | Wave | Kind | Content |
|---|---|---|---|
| **DS** Item data design | 1 | design (data, no game code) | signature → enchant and upgrade mapping, stat value table, potion and elixir list, prices, upgrade and crown costs (§3); German preview page for the user's approval |
| **C1** Drops | 1 | code | drop rates and quality, boss double drops, item pool incl. shields, spellbooks and trinkets, bag world drops, level requirement for all gear (§2.1, §2.2, §2.6) |
| **C2** Profession restructure | 1 | code | Alchemy becomes a secondary profession with its own book slot; progression only from real recipes; removals (§2.7, §2.8) |
| **C3** Cloaks and achievements | 1 | code + art | cloak rendering (technique from VoxeLibre), per-character achievements, Character page "Achievements" tab and cloak picker; Astra proposals and textures (§2.10) |
| **C4** Enchant tiers and upgrades | 2 | code | enchant strength by item level with a tier cap, tier in the tooltip, overwrite warning, profession upgrades, the crown operation (§2.3–2.5) — data from DS |
| **C5** Vendors, capitals and economy | 2 | code | vendors sell T1 bases only, sell values, repair cost, culture vendor, crown NPC in every capital, fixed potions T1–T6, the stat value pass, income model recalibrated (§2.5, §2.6, §2.9) — data from DS |
| **D** Documentation | 3 | docs | completion, design docs, BACKLOG/ROADMAP/STATUS |

Wave 1 starts together. Wave 2 starts after the user approves DS's preview
and after C1 (C4 shares `grug_quality`) and C2 (C5 shares the profession and
alchemy data) are merged. D last.

## 2. User rulings (design session, 2026-10-03/04)

### 2.1 Quality and drops
- **Quality stays as built:** the number of enchantments sets it — none =
  Common (white), one = Uncommon (blue), two = Rare (gold). Trinkets roll
  0/1/2 like every other item (today a rolled trinket always gets two).
- **Item level of a drop = the mob's level.** Drop enchantments roll the
  item's tier (§2.3).
- **Kraken Guard** (ruling 2026-10-04): a level-70 elite instead of the
  hand-set level 100 (the dragons are 70 too); still no XP and no drops, no
  bag either.
- **Pool:** everything equippable of the tier — weapons, armour, shields,
  spellbooks, trinkets.
- **Chances per kill, at most one item per kill:**

  | Source | White | Blue | Gold | Total |
  |---|---:|---:|---:|---:|
  | Normal mob | 5 % | 2 % | 1 % | 8 % |
  | Named mob and elite | 10 % | 10 % | 5 % | 25 % |

- **Bosses** (Kings, dragons, the PvP General) always drop **two** items, each
  50 % blue / 50 % gold. Kings and the General drop item level 65, dragons
  item level 70 (today Kings 70, dragons 75). Their other loot (Fallen Crown,
  Scaled Hide) stays.
- **Bags as world drops:** any mob, 0.1 % per kill, size by mob level: 1–15 →
  8 slots, 16–30 → 16, 31–45 → 24, 46+ → 32. The 8-slot bag stays on sale;
  larger bags come only from drops, the Tailor or the Leatherworker.
- **Sale value:** blue ×3, gold ×6 of today's Common buy-back.

### 2.2 Level requirement
Item level = minimum character level, capped at 60, for **all** equipment
(today only weapons). A level-60 player may wear item level 65/70.

### 2.3 Enchant strength and tiers
- Enchant strength grows **continuously with item level** instead of today's
  four flat bands (`grug_quality` `BANDS`), **capped at its tier's top**:
  value = f(min(item level, 10 × tier)). A T5 enchant is full at item level
  50; on an item-level-60 item it stays at its item-level-50 value.
- The enchant's **tier shows in the tooltip.**
- **Crafted** enchants have the recipe's tier; **dropped** enchants the
  item's tier (item level 1–10 → T1 … 51–60 → T6). Boss drops above item
  level 60 roll **T7** enchants (coordinator proposal, accepted), so their
  extra item level counts.
- **T7** exists only as a number: no T7 recipes. It comes from boss drops and
  the crown (§2.5).
- **Overwriting stays allowed** (a channel's enchant replaces the old one, as
  today). The station preview warns when the new enchant is weaker, e.g.
  "replaces T7 Strength with T6 Strength".

### 2.4 Profession upgrades
- The crafting professions upgrade items of their families: Weaponsmith
  (metal weapons), Armorsmith (metal armour, shields), Woodcarver (bows,
  staves, wands), Leatherworker (leather armour), Tailor (cloth armour),
  Goldsmith (trinkets; spellbooks if DS finds it fits).
- An upgrade sets the item level to its **tier's top** (10/20/…/60) — a
  fixed target, never lowering. Inputs: the profession's material and
  **signature loot of that tier** (DS maps them).
- The crafter's own level does not cap the upgrade (§2.2 decides who may wear
  it); the profession tier is capped by the character band as today.

### 2.5 The crown
- An **NPC in every capital** (not an altar; Astra names it) applies a Fallen
  Crown to one item: its item level becomes its **tier's top + 5** (a T5
  Embersteel sword → 55, a T6 Abyssal sword → 65, whatever its item level was
  before), and every enchant on it gains **+1 tier** (T6 → T7, so it scales
  on to item level 70). Enchants keep their stats.
- Once per item; refused where it would change nothing or lower the item
  level (boss drops at 65/70).
- A player can still re-enchant a crowned item, but only with T1–T6 recipes,
  so overwriting a T7 enchant loses it (the warning of §2.3 says so).

### 2.6 Vendors and money
- Vendors sell **T1 bases only** (weapons and armour). From T2 the bases come
  from Basics crafting (mined and gathered materials) or drops. The rotating
  weapon families above T1 and the rotating blue vendor item go.
- **Repair** becomes noticeably dearer (DS proposes the factor; today 0.6–1.8 %
  of income).
- **Culture vendor** in every capital: cosmetic, non-craftable blocks and
  lights (candles, lanterns, accent blocks) for money — a gold sink. Items
  may come from the reference projects when their licence fits, checked per
  file (`docs/research/licensing.md`), each with a `LICENSE-media.md` row.

### 2.7 Professions
- **Alchemy becomes a secondary profession** like Cooking: everyone can learn
  it without using a primary slot; a second fixed book slot on the crafting
  page, reserved for Alchemy. Six primaries remain (Weaponsmith, Armorsmith,
  Tailor, Leatherworker, Woodcarver, Goldsmith).
- **First Aid** is removed from the design (it never existed in code).
- **Progression:** only real recipes count — enchants, upgrades and the
  profession's own end products (potions, elixirs, dishes, bags, trinkets,
  spellbooks). Stations (Forge, Carving Bench, …) and intermediates
  (settings, bolts, cut gems) no longer count.
- **No fast path** for late starters.
- **Potions:** fixed-amount healing potions T1–T6, about 50 % of a Priest's
  base pool at the tier's top level, smoothed: **70 / 200 / 400 / 650 / 1000 /
  1350** HP (exact pools 68/192/382/638/960/1348). Mana potions likewise
  (same base pool) if DS confirms they fit the potion list.

### 2.8 Removed
Cultural finishes and the six cultural materials (items, gather nodes,
tables), the PvP weapon counter and the Warding Draught, Weapon Grips, the
Leatherworker's ×5 leather, First Aid bandages, apothecary gear, imbuing oils
and the Sovereign's Flask, universal reagents, the rotating blue vendor item.
The cut-gem storage blocks stay and get a simple 9 ↔ 1 recipe (building
accents). Fresh-server mode: removed means gone, no aliases.

### 2.9 Stat balance
The nine stats become **roughly** equal in value within their kind, not
exactly (the user: the mix matters — a tank's armour protects the healer's
mana; crit scales with base damage). Damage per slot: Strength (Dexterity for
Scouts), Crit and Attack speed close to each other; survival per slot: Dodge,
Armour and HP % close to each other. **Dexterity** gives crit and dodge, so
each half is about half a pure Crit or pure Dodge enchant. Casters: the same
principle for Intelligence, Crit and Mana. No stat should be the only sensible
pick (today Attack speed is: +4 to +14 % damage against Crit's +0.2 to +1.2 %).

### 2.9a Crit, Dexterity and profession families (rulings 2026-10-04)
- **Crit** = 5 % + 0.05 % per Dexterity point, **dodge** = 0.1 % per point
  (caps 30 % unchanged); a crit deals **×2** (damage and heals) instead of
  ×1.5. Crit enchants need fewer points, so the cap allows about four of them.
- **Two professions per class** cover armour, weapon and offhand:
  Leatherworker leather armour **and bows**; Tailor cloth armour **and
  spellbooks**; Woodcarver staves and wands only; Weaponsmith all metal
  weapons (incl. the Scout's melee weapon); Armorsmith metal armour and
  shields; Goldsmith trinkets for everyone. §2.4's families follow.
- **Zone leaders and war-camp captains** use the named/elite drop row
  (10 / 10 / 5 %).

### 2.10 Cloaks and achievements
- **Cloaks are cosmetic and not items:** each character has its own unlocked
  list (stored per character). The Character page shows a dropdown under the
  character model to pick the cloak. A new character has two: "No cloak" and
  "Plain grey cloak".
- **Only achievements unlock cloaks.** A new **Achievements** tab sits next to
  Stats and Effects on the Character page.
- **Technique from VoxeLibre** (GPLv3, code reuse fits): how the cloak sits on
  the model and moves. **Textures by Astra.**
- **First achievements (the user):** Hunter — kill 100 wild animals (plain
  dark green cloak); Kingslayer — first King kill (cloak with a crown);
  Wyvernslayer — kill the Stormscale Jungle Wyvern (green dragon-scale
  cloak); Dragonslayer — kill the Wyrmglass Ice Dragon (blue dragon-scale
  cloak); Honored — kill 50 guards of the enemy faction (red cloak with
  crossed swords).
- **More, as tiers:** wild animals 100 / 300 / 1000; a zombie slayer with
  tiers; Kings and dragons 1× / 5× / 20×; a few funny ones (e.g. a boar
  slayer with a boar on the cloak). **Astra proposes further achievements and
  cloaks** a player collects on the way to level 60 (cloak design round,
  §4.3); the user picks.
- "Wild animals" = every animal mob, critters and hostile beasts included, no
  humanoids (coordinator proposal); the Kraken Guard counts, dragons and young
  dragons do not (bosses and boss adds; the user, 2026-10-04).

## 3. Lane DS — item data design (wave 1)
Delivers data tables and a German preview page; the user approves before
wave 2. Inputs: R3's report, `grug_mobs/data/drops.json` (94 signatures, 24
generic items), today's enchant recipes, `combat_stats.md`.
1. **Enchant recipes T1–T6:** every enchant stat per channel and tier, each
   with materials of its tier; give as many of the 67 unused signatures a use
   as fits, by theme and tier (e.g. claws → Strength, feathers → Attack
   speed).
2. **Upgrade recipes** per profession and tier (§2.4), using the remaining
   signatures; list which signatures stay sell-only and why.
3. **Stat value table** (§2.9): values per stat and tier as functions of item
   level, the T7 extension, and a check per class and tier that no stat
   dominates (Warrior, Scout, Mage, Priest at band middle and top).
4. **Potions and elixirs** T1–T6 (§2.7): healing, mana, the existing elixirs
   re-tiered, ingredients per tier.
5. **Money:** blue/gold sale values, the repair factor, the culture vendor's
   price list, crown and upgrade costs; the income model
   (`tools/r29_e4/income.py`) shows the effect per band.
Preview page in German: decisions first, numbered.

## 4. Code lanes (goals; the briefs add file facts)

### 4.1 C1 Drops
§2.1, §2.2: the drop table, boss double drops at 65/70 with T7 enchants,
trinket rolls 0/1/2, the item pool, bag world drops, sale value by quality,
the level requirement for all gear (equip refusal already exists for
weapons). Fixture: drop rates over many simulated kills, boss drops, bag
sizes by level, requirement for armour/offhand/trinket.

### 4.2 C2 Profession restructure
§2.7, §2.8: Alchemy secondary with its book slot (Cooking is the template),
progression from real recipes only, the removals. Fixture: progression
counting, Alchemy learnable beside two primaries.

### 4.3 C3 Cloaks and achievements
§2.10, in stages: (1) the cloak technique study (VoxeLibre's capes vs our
character model: mesh, bone, texture layer, animation) and Astra's
achievement and cloak proposals → a German preview page for the user
(achievement list with tiers and conditions, cloak sketches); (2) after the
user picks: the achievement counters and storage, the Achievements tab, the
cloak picker, rendering for all races and both genders, Astra's textures
(each with a `LICENSE-media.md` row). Counters reuse what exists (guard kills
in `grug_pvp` stats, King and dragon kills in the boss ledger).

### 4.4 C4 Enchant tiers and upgrades (wave 2)
§2.3–2.5 with DS's tables: enchant value by item level with the tier cap,
tier in the tooltip and stored per enchant, T7, the overwrite warning,
profession upgrade operations, the crown operation (the NPC of C5 calls it).

### 4.5 C5 Vendors, capitals and economy (wave 2)
§2.5–2.7, §2.9 with DS's tables: vendor stock T1 only, culture vendor and
crown NPC sockets in every capital, sale values, repair factor, fixed potions
T1–T6, the stat value pass, `income.py --check` green again.

## 5. Rules
As Round 32: AGENTS.md; `tools/check_lua.sh` (via bash); headless only through
`LC_ALL=C tools/luanti_headless.sh` under `chrt --idle 0`, never the user's
Luanti folder; numbers are comparisons; fresh-server mode; agents never push;
no references to commercial games. Art: generator output or Astra, each file
with a `LICENSE-media.md` row; third-party code only GPL-compatible
(`docs/research/licensing.md`).

## 6. Verification
Each code lane: fixtures (`tools/run_fixtures.sh`), `validate.py --game`, one
engine boot, an independent review. The quest/XP ledger and the income model
are re-run after C1 and C5. End: one engine boot of main, sync, the user's GUI
check.

## 7. Orchestration notes (for the coordinator)
- **Start state:** main `31cdc647` or later (local; Rounds 30–32 not pushed).
  Worktrees `.claude/worktrees/r33-<lane>`, `tools/bin/` copied; briefs in
  `~/projects/grudgelands-orchestration/r33/` from `r32/common-brief.md` and
  `r32/review-common.md`; `r32/engine_run.sh` copied with its lock path
  changed. Log in `r28/HANDOVER.md` under "ROUND 33". Astra via
  `run_astra.sh 33 <lane>` (reasoning never "ultra").
- **Code facts** (verify, they are hints):
  - `grug_quality/init.lua`: `QUALITY` (1 white / 2 blue / 3 gold; quality =
    affix count, ~593 and ~677), `POOLS` per family, `BANDS` (four flat value
    bands, ~74–91), `WINDOWS`, `DROP_CHANCES` (normal/elite/rare/boss/general,
    ~102–111), `ENCHANT_VALUES` per tier (~113–119), `roll_enchants`,
    `operation_plan` (prefix/suffix channels; a channel's enchant overwrites,
    same stat on both channels refused), `write_item_level_meta` (requirement
    weapon-only, ~223–235), gear drops ~735–814, boss rolls ~748–751 and
    ~799–814.
  - `grug_gear/init.lua`: brackets ~44–49 (base item level 3/10/20/30/40/50,
    prices), `_grug_req_level` ~499, repair reference ~410–432;
    `grug_gear/trinkets.lua`: six identities × six tiers (Tin … Abyssal Steel,
    item level 3–50), a white trinket carries only its special.
  - Vendors: `grug_traders/stock.lua` ~94–99, 156–178, 230–244 (rotations, the
    blue item); buy-back `grug_traders/prices.lua` ~312–314; repair
    `grug_repair/service.lua` ~17–22.
  - Professions: `grug_jobs/registry.lua` (`PROFESSIONS`, Alchemist primary,
    Cooking the only secondary), progression `grug_jobs/state.lua` ~121–160,
    station crafts counting `grug_jobs/stations.lua` ~109–114; Alchemy
    effects `grug_alchemy/effects.lua`.
  - Bosses: `grug_mobs/bosses.lua` (loot ~164–227, Fallen Crown ~253–258;
    names "The Wyrmglass Ice Dragon", "The Stormscale Jungle Wyvern").
  - Cultural materials: `grug_materials/registry.lua` ~270–314,
    `grug_materials/ores.lua` ~133–148, `grug_gathering/catalog.lua` ~266–335.
  - Character page tabs: `grug_inventory/pages.lua` ~263–275 (Stats,
    Effects).
  - Guard kills: `grug_pvp` `stats`/`count_npc_kill`.
- **Previews and Astra:** DS and C3 stage 1 each write a German preview page
  (`r33/previews/<lane>/index.html`); the coordinator publishes them as
  private artifacts and collects the user's picks. Astra for C3 in two calls:
  first the achievement and cloak proposals (texts, conditions, tiers, cloak
  descriptions) for the preview, then — after the user's picks and the
  technique study fixed the texture format — the cloak textures. Astra also
  names the crown NPC (C5). The user's GUI tests of Rounds 30–32 are still
  open; findings may become a small fix lane.
- **Merge order:** C1, C2, C3 independent; C4 after C1; C5 after C2 (and after
  C4 where both touch prices); D last.
- **End:** `tools/run_fixtures.sh` on main, sync with
  `tools/sync_to_luanti.sh`, the user's GUI check; the user pushes.

## Completion (2026-10-04)

Every lane below is merged on local main (last lane C5, `16c498b9`); not
pushed. Each code lane was independently reviewed by Opus once: C1 and C4
merged after small fixes, C2 with its fixes in the merge commit, C3 after
stage 2 with three fixes, C5 after a fix the review verified (crowning a
worn item bypassed the level requirement). DS is design data, approved by
the user through its preview (version 2); it changes no game code. After
each merge the coordinator ran the portable fixtures
(`tools/run_fixtures.sh`, 72 of 72 on `16c498b9`), `validate.py --game` (0
errors), `check_fresh_server.py`, `tools/r29_e4/income.py --check` (PASS
since C5) and the DS document check, and booted main once (smoke, no ERROR
line, no new warning). **A fresh world is required:** C2 removes the six
cultural materials and their mapgen placement, and the capital services
take over gate residents of existing plots.

### Shipped, by lane

Numbers are each lane's own probe or fixture, same seed and method before
and after (comparisons, never targets).

- **DS item data design** (merge `6ee5f734`, approved `0812384a`;
  [item_tiers.md](../design/item_tiers.md), scripts and the two JSON data
  files in `tools/r33_ds/`): enchant value `a + bL + cL²` with
  L = min(item level, 10 × tier) up to 70, so one enchant gives about
  1.6 % + 0.04 % × L in its kind for the class that wants it; a class check
  over the shipped Strike, Mighty Blow, Loose, Fireball, Heal and Smite
  formulas keeps the damage and survival stats within ×1.35 of each other.
  Version 2 refitted Crit (`1.7 + 0.044 L`) and Dexterity
  (`0.8 + 0.13 L + 0.0019 L²`) to the crit rulings: a full damage set at
  level 60 gives a Warrior +47 %, a Scout +55 % and a Mage +45 % (item
  level 70: Warrior +69 %, Scout +82 %). Enchant loot per channel
  (`prefix_loot`, `suffix_loot`), one upgrade per profession and tier and
  the alchemy reagents give 68 of the 94 signatures a use (27 before, 41
  new); 26 stay sell-only with a reason (20 one-faction, 4 without a placed
  source, 2 scarce trophies). Money: the drop sale tables, repair ×1.00,
  the crown fee, the culture price bands, no upgrade fee. Fixture 1366
  checks.
- **C1 drops** (merge `b3b3cc71`; [items_crafting.md](../design/items_crafting.md)
  §5, §6): per kill at most one item, normal 5 / 2 / 1 % white / blue /
  gold, named and elite 10 / 10 / 5 % (measured over 200 000 simulated
  kills: 5.00 / 2.00 / 1.00 % and 10.00 / 10.00 / 5.00 %); Kings, dragons
  and the General two items each, blue or gold at even odds (49.6 / 50.4 %
  of 4000), item level 65 (Kings, General) or 70 (dragons) with T7
  enchants; a bag at 0.1 % by mob level (609 in 600 000 kills, 0.102 %).
  The pool is every equippable item of the tier (`grug_gear.drop_pool`, 26
  items: weapons, armour, shield, spellbook, six trinkets); trinkets roll
  0/1/2 enchants; the roll windows are gone. Every equipment definition and
  stack carries the requirement min(item level, 60), T1 bases level 1, with
  a "Requires level N" tooltip line, and every equipment slot refuses an
  item above the character's level. Vendors buy blue ×3 and gold ×6
  (`price_rules.QUALITY_FACTOR`). The Kraken Guard is a level-70 elite with
  0 XP and no drops. Gear sale income per band (`tools/r33_c1/drop_income.py`):
  0.6–0.8 % → 2.1–3.0 % of net income; a normal kill's gear is worth
  0.04c → 0.14c at band 1 and 2.44c → 9.58c at band 6. Fixture 690 checks.
- **C2 profession restructure** (merge `e301d002`;
  [professions.md](../design/professions.md)): **Alchemy** is a secondary
  profession beside Cooking (id `alchemist`, its own book slot on the
  crafting page, a fourth row on the Professions tab); progress comes only
  from real recipes (`register_recipe` derives `progress`;
  `grug_jobs.award_progress` is the one hook every craft path and station
  operation calls). Removed: the six cultural materials with their gather
  nodes and the WP40 R6 cultural mapgen slot (production rows 93 → 87,
  pinned digests recomputed; mapgen timing unchanged on the lane's region
  run), Weapon Grips, the ×5-leather drop hook, universal reagents, the
  apothecary gear reader, the Warding Draught. The cut-gem storage blocks
  pack and unpack 9 ↔ 1. Fixture 22 662 checks.
- **C3 cloaks and achievements** (merge `1028afb9`, Astra's second pass
  `dcd3a8ec`; [character_visuals.md](../design/character_visuals.md) §5b):
  players wear `grug_visuals_character.b3d` (`character.b3d` with a cloak
  box on a keyed `Cloak` bone and its own texture, generated by
  `tools/r33_c3/gen_cloak_model.py`, which proves the swing never crosses
  the legs in all 221 frames); `grug_achievements` keeps 17 achievements,
  their counters and the unlocked and chosen cloak per character; 41 cloaks
  painted by GPT-6 Astra (32 × 32, CC0), twelve repainted after the user's
  feedback; the Character page tabs Stats, Effects, Achievements,
  Professions and a cloak dropdown under the model. Return home counts in
  whole minutes, so the page is re-sent once a minute instead of every
  second (which had closed the dropdown). New seams:
  `grug_mobs.register_on_boss_kill`, `grug_pvp.register_on_stat`,
  `grug_jobs.register_on_award_progress`. Fixture 366 checks.
- **C4 enchant tiers and upgrades** (merge `d2dcec62`; item_tiers §1–§4,
  [crafting_equipment_revision.md](../design/crafting_equipment_revision.md)):
  `grug_items.enchant_value(stat, ilvl, tier)` replaces the four flat
  bands; every enchant stores its tier, found enchants take the item's tier
  without a roll, values are written by one store path; tooltips read
  "+15 Strength (T5)". Station operations "enchant" and "upgrade"; the
  preview warns "Replaces T7 Strength with T6 Strength." An upgrade lifts
  an item of the profession's families to 10 × tier. The crown
  (`grug_items.crown_item` / `crown_preview`): tier top + 5, every enchant
  +1 tier, once per item, refusals with a reason, a "Crowned" tooltip line.
  Families: bows to the Leatherworker, spellbooks (2 bolts + Parchment) to
  the Tailor, the Woodcarver keeps staves and wands
  (`grug_professions.FAMILY_OWNERS`). Ornament Components and the Cut
  Quartz recipe are gone; Cut Citrine is the T1 trinket gem. Zone leaders
  and war-camp captains roll the elite row (fixture: 9.98–10.00 /
  9.99–10.01 / 5.00–5.01 %). Fixture 1498 checks.
- **C5 vendors, capitals and economy** (merge `16c498b9`;
  [combat_stats.md](../design/combat_stats.md) §2,
  [economy.md](../design/economy.md)): Crit = 5 % + 0.05 % per Dexterity
  point, Dodge 0.1 % per point, a crit deals ×2 for damage and heals
  (`CRIT_MULTIPLIER` in `grug_core/combat.lua`); attribute fractions count
  (Strength/10 without the early floor). Vendors sell T1 bases only (no
  rotation, no blue item; the 8-slot bag stays); buy-back for every gear
  tier and for shields, spellbooks and trinkets; repair factor 0.20 →
  1.00. Healing and Mana Potions I–VI (70 / 200 / 400 / 650 / 1000 / 1350),
  elixirs I–VI at two enchants' worth, one shared 60 s potion cooldown, the
  Weak Healing Potion 35 HP at 8c. The **Crownbinder** (fee 1g 47s plus one
  Fallen Crown) and the **Decor Merchant** (culture shelf: accents 25c,
  lantern 1s, hanging lantern 10s, showpieces 1g, all from `grug_decor`)
  take the gate resident of every capital's goldsmith and woodcarver hall.
  `income.py --check` is green again: net per hour 1s77c → 1s72c (−3.1 %)
  at band 1 … 1g45s → 1g47s (+1.6 %) at band 6; repair takes 3.0–8.9 % of
  net income for blue gear (0.6–1.8 % before). Recalibrated: Apprentice
  Riding and the boat 1s10c → 1s5c, Expert Riding 1g37s → 1g32s, Master
  Riding 7g33s → 7g37s, respec 41–50 6s → 5s50c. Fixture 500 checks.
- **D:** this section, the status files, the design index and the as-built
  corrections, the module guide and AGENTS.

### Rulings made during the round

1. **Plan approval** with the coordinator's additions: boss drops above
   item level 60 roll T7 enchants, the crown is not for them; mana potions
   once DS confirmed they fit (it did).
2. **Kraken Guard:** a level-70 elite, no drops, no bag and **0 XP** (the
   user's correction of the first ruling).
3. **Wild animals** for Hunter count the Kraken Guard, not the dragons or
   the young dragons.
4. **Achievements:** the user's 17 picks with their tiers (Hunter and
   Honored 50 / 150 / 500, superseding §2.10's 100 / 300 / 1000 and 50;
   Kingslayer, Wyvernslayer and Dragonslayer 1 / 5 / 20; Grounded only for
   the first fall death); dishes and potions count when they are prepared.
   **One cloak per tier.** Astra repainted twelve cloaks after the user's
   feedback; the others were approved as painted.
5. **The crown NPC is the Crownbinder** (Astra's K1); the cloak technique
   T1–T3 of the C3 study accepted.
6. **Crit and Dexterity** (§2.9a): crit 5 % + 0.05 % per Dexterity point,
   dodge 0.1 % per point, a crit ×2 for damage and heals.
7. **Two professions per class** (§2.9a): bows to the Leatherworker,
   spellbooks to the Tailor, staves and wands stay with the Woodcarver.
8. **Zone leaders and war-camp captains** roll the named/elite row
   (10 / 10 / 5 %); C1 had read "named" as the rare tier.
9. **Every DS recommendation** (item_tiers status line): Dexterity on its
   own curve; Priest heals keep their weak Intelligence use (2A); attribute
   fractions count; repair ×1.0; crown fee one hour of band-6 income; no
   upgrade fee; elixirs worth two enchants; the Weak Healing Potion 35 HP;
   one-faction signatures stay sell-only; culture prices as proposed;
   Ornament Components removed (11A); Cut Citrine the T1 trinket gem (12A).
10. **Coordinator-accepted values** in C5: the crown fee **1g 47s** (the
    rule applied to the repaired income estimate; item_tiers' preview said
    1g 45s) and **Ridged Boar Tusk** for Elixir of Precision II
    (Dragonweed + Fang is the Swiftness Draught's recipe).
11. **T1 gear requires level 1** at item levels 1–3 (the starter kit; C1
    review, the user informed).
12. **Sound moves to Round 34**, WP9 to a round after it.

### Open items

In the [BACKLOG](../../BACKLOG.md#round-33-carry-overs): map and minimap
markers for the Crownbinder and the Decor Merchant; the Scout's full damage
set above the +50–60 % ceiling (+55 % at item level 60, +82 % at 70);
Priest heals barely use Intelligence (a heal-formula change, 2B, would be a
later round); the Ruination window under ×2 crits (+9 % → +18 % damage
while it lasts, a capped hit averages ×1.5 instead of ×1.25: a playtest
number); the damage-fit reference `baseline_melee_total` in
`grug_core/combat.lua` still floors Strength/10 while live damage keeps the
fraction (same-level damage about +1.6 % at level 60, up to about +5 % at
levels 2–9); the Decor Merchant's light bands hold one item each (no
Candle; the Embalmer sells one at 4c); the 20 one-faction signatures stay
sell-only; Slime Gel, Crocodile Tooth and Stone Core have no recipe use;
C3's theoretical notes (one small classification table per kill). The
Round 32 carry-overs that remain (R1's later list R6–R13, `remote_media`
and at least 4 GB RAM, the minimap bezel size) stay. Next: the user's GUI
test (with Rounds 30–32), then **Round 34, sound** (planned in a parallel
session on branch `r34-plan`, not merged yet), then WP9.

### GUI playtest checklist

One Flatpak client on a **fresh world** (two for item 3); helpers
`/xp give`, `/teleport`, `/giveme` (privileges `server`, `give`).

Cloaks and achievements (C3):

1. **Cloak on the model:** earn a few cloaks (e.g. kill 25 rats, fall to
   death once) and look in third person on several races: the cloak hangs from the shoulders to above the knee,
   sways standing, swings with the legs walking and never passes through
   them, rests over the seat when sitting; check the lining (the inside)
   and the thin edges.
2. **Dropdown and tab:** the cloak dropdown under the model on the Stats
   view lists the owned cloaks; long names ("Stormscale Mantle",
   "Second Helpings") are not cut off; the Achievements tab pages its
   achievements, the tooltip shows the flavour line; earning a tier posts
   one line in the message feed.
3. **Seen by others:** a second player sees the chosen cloak and its
   change at once.
4. **Return home:** during the 30-minute cooldown the Stats view shows
   whole minutes, and an open cloak dropdown stays open.

Items, enchants and the crown (C1, C4):

5. **Level gate:** armour, a shield or offhand and a trinket above your
   level are refused in their slot with a feed line; the tooltip reads
   "Requires level N"; T1 gear needs level 1.
6. **Enchant tiers:** tooltips read like "+15 Strength (T5)"; a found blue
   or gold item carries its own tier.
7. **Overwrite warning:** at a station, a T1–T6 enchant over a stronger one
   (a crowned or boss item's T7) shows "Replaces T7 Strength with T6
   Strength." before you confirm.
8. **Upgrades:** each profession's station offers an upgrade for its
   families (Forge for weapons and metal armour, Carving Bench for staves
   and wands, Tanning Rack for leather armour **and bows**, Tailor Bench
   for cloth armour **and spellbooks**, Jeweller's Bench for trinkets); the
   item level rises to the tier's top and enchant values follow.
9. **Crowning:** at a Crownbinder, crowning an item takes 1g 47s and one
   Fallen Crown, the item reads "Crowned" with item level tier top + 5 and
   its enchants one tier higher; refused with a reason for a second crown,
   a dragon drop (it would lower the level), a King drop that still has its
   T7 enchants (nothing would change) and a worn item you could no longer
   wear afterwards.
10. **Drops:** a boss (a King or a dragon) gives two blue or gold items;
    elites and named mobs drop noticeably more often than normal mobs.

Vendors, potions and capitals (C5, C2):

11. **Vendor shelves:** smiths and armourers sell T1 gear only; selling a
    blue or gold drop pays three or six times a white one; T2+ gear,
    shields, spellbooks and trinkets can be sold and bought back.
12. **Repair** costs about five times what it did; the quote matches the
    charge.
13. **Potions:** the Weak Healing Potion heals 35 HP; Healing and Mana
    Potions I–VI heal their fixed amount; any potion starts one shared
    60 s cooldown for all of them.
14. **Alchemy book slot:** Alchemy has its own book slot beside Cooking and
    can be learned next to two primaries.
15. **Capital services:** in every capital the Crownbinder stands at the
    goldsmith hall's gate and the Decor Merchant at the woodcarver hall's
    gate; the Decor Merchant's shelf sells and buys back as an ordinary
    vendor; both refuse the enemy faction.
16. **Cut-gem blocks:** 9 cut gems make one block and the block gives the
    9 back.

Combat (C1, C5):

17. **Kraken Guard:** shows as a level-70 elite, gives no XP and drops
    nothing.
18. **Crits:** crit numbers show doubled damage or healing; the Character
    page's crit chance follows 5 % + 0.05 % per Dexterity point.
19. **Ruination** (Warrior capstone): during its 10 s window crits come
    often and hit hard; say whether the burst feels too strong.
