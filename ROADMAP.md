# Roadmap — Grudgelands

A Luanti game that captures the game mechanics, story and character of
World of Warcraft as well as possible in a voxel world — as a standalone
game (not a mod pack), written in Lua.

## Vision

- Two factions — **The Throng** and **The Accord** — each with **its own
  huge continent** (multi-biome): the Throng holds **Kragmar** in the
  north, the Accord **Elandor** in the south, separated by an ocean
  strait at z=0; everything beyond the continents is ocean, deadly far
  offshore (`docs/design/world.md` §0/§1/§2b).
- **Races, kept deliberately simple**: each faction consists of several
  races. **Three race capitals per continent** in the safe-core belt
  (players spawn in their race's capital); the central one doubles as
  the faction seat (King, guild services). The faction territory is
  divided into race-flavored regions (mountains = dwarves, forests =
  elves, …) with additional patch villages and settlements.
  Race perks: vendor discounts among your own race, race-exclusive
  vendors, race-exclusive professions/recipes (Phase 2). Details:
  `docs/design/world.md`.
- Classes with XP, levels and simplified skill trees.
- Quests that drive progression and deliberately force PvP and exploration.
- Professions ("jobs"), a gold economy and trader NPCs.
- Difficulty scales spatially ("safe core + war coast",
  `docs/design/world.md` §1): capital + starter villages in the safe
  continent center, mob levels grow toward the coasts; only the
  strait-facing **war coast is capped mid-level** as the PvP stage
  (first PvP quests ~lvl 20–30 — no forced early PvP). **Guard strength
  runs inverse** (elite in the core): military outposts and ambient
  patrols gate invaders in both directions.
- **Controlled destructibility**: digging/building is free only inside
  your own faction's territory (outside protected zones such as capitals,
  outposts and quest structures); enemy territory and the border zone
  cannot be modified. Ores respawn so a persistent world does not run dry.
- **Player housing**: guild-owned areas in the safe ocean behind the own
  continent (island model in design), with separately purchasable build
  (x/z) and mining (depth) rights and depth treasures — the main outlet
  for free building and the central gold sink (`docs/design/world.md`
  §5, layout: `TODO-design-housing.md`).
- **Travel**: waypoint network (Diablo/PoE style — teleport only from
  waypoint to waypoint, unlocked by visiting, none in enemy territory)
  + a Home Stone to the own capital (10 s cast, damage interrupts,
  60 min cooldown) as emergency valve (`docs/design/world.md` §6).
- Class-specific points of interest (trainers, special quest NPCs) in the
  capitals and out in the world.
- A global per-player map with fog of war (everyone uncovers it
  themselves).
- Item quality tiers **Common/Uncommon/Rare/Unique** (white/blue/yellow/
  orange; Uniques post-MVP); better gear comes from crafting and hard
  bosses, not vendors — "the harder the enemy, the better the loot".
- **Combat rests on an aggro/threat system** (it shaped WoW's fights):
  groups play the tank/healer/damage trinity; solo players stay viable
  via food (out-of-combat recovery) and healing potions. Mobs are
  slightly faster than players — pulling several same-level mobs solo is
  dangerous.
- **Scaled for reality, built for headroom** (decided 2026-08-06): a
  Luanti server handles 100+ concurrent players and our Lua must too
  (performance rules in AGENTS.md) — but content assumes few: group
  content is sized for **2–3 players**, everything is **beatable
  without a healer**, and leveling is fast (**level 60 in ~10–20 h**,
  `docs/design/progression.md`) — the endgame is the game.
- **Apex world bosses**: one visible dragon POI per continent first
  ("see it at level 8, fight it at 50"), the enemy's dragon as the
  flagship PvP raid, later one apex creature per race region — same
  tech, distinct skill sets (`docs/design/world.md` §4b).
- A light layer of lore and story, delivered through quests, setting and
  environmental storytelling. Premise: **"A darkness has befallen the
  land"** — the Accord–Throng conflict is old, but a new demonic evil
  rises from the Nether and threatens both factions equally
  (`docs/design/story.md`).
- **Guilds as a pure ownership layer** (bank, housing, mining claims,
  fixed roles; even solo players found one): `docs/design/guilds.md`.
  Deliberately NO guild levels/perks/wars — Luanti is not MMORPG enough
  for that.
- **License: GPL** (non-commercial project) — so we can adopt and adapt
  code from all reference projects (incl. VoxeLibre).

---

## Phase 1 — MVP

### 1.1 Foundation
- [x] Game skeleton: `game.conf`, mod structure, namespace conventions (see AGENTS.md)
- [x] Base world: blocks/tools/crafting (BASE modpack from minetest_game)
- [x] Mob engine integrated (mobs_redo embedded; faction patch follows with 1.4)

### 1.2 Factions & world
- [x] Faction choice at character creation (Throng/Accord), persistent
- [x] World design spec decided (`docs/design/world.md`): geography/
      rings, destructibility rules, capitals/outposts, housing, races
- [x] Mapgen: two large contiguous faction territories (north/south), each
      composed of several race-flavored biome regions
- [x] Continent rework (WP18): two ocean-separated continents with soft
      noisy coastlines (continent ocean mask instead of the old mountain
      wall), 17 biomes (mirrored bands) per
      `docs/design/biomes_mobs.md` §1.3,
      guaranteed strait and coastal ocean, deep-sea guard mob
- [x] Difficulty gradient: `grug_core.difficulty_at/mob_level_at` radial
      field + `guard_level_at` (mobs actually scaling with them lands
      with 1.4/WP6)
- [x] Faction spawn points: walkable camp platforms at the three race
      capitals per continent (players spawn in their own race's capital;
      real capital structures follow with WP13)
- [x] Build/dig restrictions per territory (own continent free, enemy
      continent and the whole ocean locked; capital protected zones; ore
      respawn deferred to WP6/13)
- [x] PvP basis: friendly-fire protection within the faction;
      quest-driven PvP follows with 1.5

### 1.3 Classes & progression (MVP: 3 classes)
- [x] **Warrior** (melee, simple — reference class), **Mage**
      (ranged/caster), **Priest** (healer/support) — selection dialog
      (faction → race → class) and registry in `grug_classes`
- [x] XP system: level curve 1–60, XP loss on death (25% of level
      progress), HUD; XP sources (mob kills, quests) follow with 1.4/1.5
- [x] Level system with stat growth: attributes + HP via
      `register_on_level_change`; damage consumption follows with the
      WP4 damage pipeline
- [ ] Simplified skill trees: 2 trees × 5 talents × 3 ranks per class,
      1 point per 3 levels, capstones = new active main skills, respec
      for gold (`docs/design/progression.md` §2), formspec UI
- [x] 2–4 active abilities per class (hotbar/item based), cooldowns
      (`grug_abilities`, 3–4 per class; spec `docs/design/classes.md`)
- [x] Combat feel (WP19): global cooldown 1 s, soft target lock 8 s,
      kit tuning per classes.md tables (rage dump, Hamstring snare,
      Frost Nova root→slow, Power Word: Shield absorb), one visible
      passive per race (world.md §7)

### 1.4 Mobs & combat
- [ ] Faction guards (attack the enemy faction), spawned by military
      outposts + ambient patrols, levels scaling with territory depth
- [x] WoW-style starter-zone mobs: aggressive boar (day) and zombie
      (night, burns in daylight) with XP rewards and loot; more (wolves, …)
      follow with WP6
- [ ] Neutral/hostile mobs in tiers: safe core = weak, outer ring and
      coasts = strong, elite mobs that require groups; incl. neutral
      **bandit camps**
      (humanoid loot source — cloth — in both territories)
- [ ] **Aggro/threat system**: mobs pick targets by threat (damage +
      healing × factor); tank threat tools/taunt follow with class
      abilities (1.3)
- [ ] Food & recovery basics: slow natural HP regen, food for
      out-of-combat recovery, healing potions (alchemy, 1.6) for
      in-combat emergencies
- [ ] **Good pathfinding** — dangerous mobs must reliably reach their
      targets (not get stuck in ravines etc.); evaluate and if necessary
      improve the mob engine's pathfinding quality (quality criterion, not
      a nice-to-have). Mobs run slightly faster than players so evading
      is never trivially easy
- [ ] Loot drops (trash loot to sell, crafting materials)

### 1.4b Loot & enchantments
- [ ] Item quality tiers Common/Uncommon/Rare (color-coded; Unique
      reserved in the architecture, ships post-MVP)
- [ ] Class items as drops: wand, mage robe, warlock robe, iron armor,
      iron sword, dagger, … (a few items per class)
- [ ] Simple enchantment system with **roll ranges**: items drop with
      randomly rolled bonuses, e.g. strength +1 to +3, attack speed +5% to
      +20% (values in item meta, visible in the description)
- [ ] For each class item an improved variant that only drops from hard
      mobs (elite/heartland) — with better roll ranges

### 1.5 Quests (MVP: forced progression)
- [ ] Quest framework (quest log UI, quest state in player meta,
      **minimum level per quest** — main-questline beats use them as
      hard level gates, `docs/design/story.md` §2)
- [ ] Quest-giver NPCs in the faction camps
- [ ] Mandatory questlines for level progression (level gates), including:
  - [ ] "Kill 5 guards at the enemy war coast" (PvP trigger, min level ~20)
  - [ ] "Push into enemy territory and kill an elite mob" (exploration + risk)
  - [ ] Gather/kill quests across different biomes (forced exploration)

### 1.6 Professions & economy
- [ ] Job system (`docs/design/professions.md`): 2 main professions per
      player, freely chosen at job trainers; **Cooking + First Aid as
      universal secondaries** for everyone; gathering split (food plants
      for all, alchemy herbs need Herbalism)
- [ ] MVP jobs: **Herbalism**, **Alchemist**, **Blacksmith**,
      **Leatherworker** (dex gear; ×5 leather via player-tag loot hook),
      **Tailor** (bags), **Gem Hunter** (mining/smelting stay open to
      everyone)
- [ ] Crafting model: everything in the 3×3 grid, multi-stage,
      recipe-unlock gated + workbench proximity for profession recipes,
      recipe book UI (`docs/design/inventory_equipment.md` §4)
- [ ] Gold system (currency, persistent)
- [ ] Trader NPCs: buy EVERY mob drop for gold; sell only the lowest
      tier per category (vendor floor rule, economy.md)

### 1.7 Map
- [ ] Global map with fog of war, uncovered per player
      (evaluate existing map mods, e.g. mapserver/"map" mods; otherwise a
      custom solution via HUD/formspec); shows discovered waypoints
      (travel: `docs/design/world.md` §6)

---

## Phase 2 — Expansion (after MVP)

- [ ] More classes: **Paladin**, **Rogue**, **Warlock**, **Shaman**.
      Rogue stealth sketch (decided direction, details later): slower
      movement while stealthed (improvable via talents), opener bonus
      (crit/stun) only from stealth, no threat until the opener; NB
      engine visibility is global — no per-viewer invisibility, so
      stealth is semi-transparent/invisible for everyone
- [ ] Profession splits once population supports them: Blacksmith →
      Weapon-/Armorsmith, Tailor + Enchanter, Leatherworker + Bowyer
      (`docs/design/professions.md` §5)
- [ ] **Decide: bow/ranged-weapon system + a Hunter-like class**
      (prerequisite for Bowyer; not in the current class plan)
- [ ] **Player housing** (guild-owned ocean areas with separately paid
      build/mining rights + depth treasures; spec: `docs/design/world.md`
      §5, layout TODO-design-housing.md) — may be pulled into Phase 1
      since it is the central gold sink
- [ ] Race perks beyond the basics: race-exclusive professions/recipes,
      race-restricted classes (decide once more classes exist)
- [ ] More questlines, story arcs per faction (WoW-inspired lore adaption)
- [ ] Dungeon/instance-like structures (fixed elite areas with boss + loot)
- [ ] Apex world bosses stage 2/3: enemy-dragon PvP raid (head trophy +
      faction buff), one apex creature per race region with distinct
      skill sets (`docs/design/world.md` §4b)
- [ ] **The Nether**: farmable active zone with its own rules, story
      layer ("the world's magic created connections"), island crossings
      into enemy territory (mirror pairing), later world bosses behind
      challenges (spec in progress: TODO-design-nether.md)
- [ ] Mounts (incl. class-specific unlock quests as flavor)
- [ ] Reputation system (simplified)
- [ ] Auction-house-like trading between players

## Phase 3 — Polish

- [ ] Own textures/sounds/models (WoW character, but original assets!)
- [ ] Localization via Luanti's translation system (`locale/` files +
      `core.get_translator`); first target: German translation of all
      in-game texts
- [ ] Balancing pass (classes, mob tiers, economy)
- [ ] Server performance pass (active object limits, ABM budget)
- [ ] Onboarding/tutorial quests

## Deliberately NOT planned

- Guild progression (levels, perks, guild wars) — guilds stay a pure
  ownership layer
- Battlegrounds/arenas (maybe much later)
- Flying mounts
