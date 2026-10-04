# Round 33 — Items, professions and achievements: round plan

Coordinator: Claude (Opus 5.5), 2026-10-04. Status: **approved by the user
(2026-10-04).**

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
- **Item level of a drop = the mob's level** (level-100 deep-sea enemies drop
  nothing). Drop enchantments roll the item's tier (§2.3).
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
  humanoids (coordinator proposal).

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
