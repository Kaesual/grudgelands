# Roadmap — "World of Blockcraft" (working title)

A Luanti game that captures the game mechanics, story and character of
World of Warcraft as well as possible in a voxel world — as a standalone
game (not a mod pack), written in Lua.

## Vision

- Two factions (**Horde** / **Alliance**), each with a large contiguous
  territory of its own (multi-biome region, north/south split).
- **Races, kept deliberately simple**: each faction consists of several
  races. One shared capital per faction (possibly with race districts);
  the faction territory is divided into race-flavored regions (e.g.
  mountains = dwarves, forests = elves) with small race villages.
  Race perks: vendor discounts among your own race, race-exclusive
  vendors, race-exclusive professions/recipes (Phase 2). Details:
  `docs/design/world.md`.
- Classes with XP, levels and simplified skill trees.
- Quests that drive progression and deliberately force PvP and exploration.
- Professions ("jobs"), a gold economy and trader NPCs.
- Difficulty scales spatially: safe starter zones at the faction border,
  deadly elite/raid areas in the heartland / far from spawn. **Military
  outposts** and ambient faction patrols enforce this gating — guard
  levels effectively limit how deep an enemy player can push.
- **Controlled destructibility**: digging/building is free only inside
  your own faction's territory (outside protected zones such as capitals,
  outposts and quest structures); enemy territory and the border zone
  cannot be modified. Ores respawn so a persistent world does not run dry.
- **Player housing**: frontier plots in a safe zone beyond the heartland
  with paid horizontal/depth expansion and depth treasures — the main
  outlet for free building and the central gold sink; a capital portal
  keeps city flair (`docs/design/world.md` §5). A **Home Stone**
  (teleport to capital/housing, 3–5 s cast, damage interrupts)
  guarantees nobody is trapped.
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
- A light layer of lore and story, delivered through quests, setting and
  environmental storytelling.
- No guild system (deliberate decision — Luanti is not MMORPG enough for
  that).
- **License: GPL** (non-commercial project) — so we can adopt and adapt
  code from all reference projects (incl. VoxeLibre).

---

## Phase 1 — MVP

### 1.1 Foundation
- [x] Game skeleton: `game.conf`, mod structure, namespace conventions (see AGENTS.md)
- [x] Base world: blocks/tools/crafting (BASE modpack from minetest_game)
- [x] Mob engine integrated (mobs_redo embedded; faction patch follows with 1.4)

### 1.2 Factions & world
- [x] Faction choice at character creation (Horde/Alliance), persistent
- [x] World design spec decided (`docs/design/world.md`): geography/
      rings, destructibility rules, capitals/outposts, housing, races
- [x] Mapgen: two large contiguous faction territories (north/south), each
      composed of several race-flavored biome regions
- [x] Difficulty gradient: `wob_core.difficulty_at/mob_level_at` ring
      functions (mobs actually scaling with them lands with 1.4/WP6)
- [x] Faction spawn points: walkable camp platforms at z = ±200
      (real capital structures follow with WP13)
- [x] Build/dig restrictions per territory (own land free, enemy land and
      border locked; camp protected zones; ore respawn deferred to WP6/13)
- [x] PvP basis: friendly-fire protection within the faction;
      quest-driven PvP follows with 1.5

### 1.3 Classes & progression (MVP: 3 classes)
- [ ] **Warrior** (melee, simple — reference class), **Mage**
      (ranged/caster), **Priest** (healer/support)
- [x] XP system: level curve 1–60, XP loss on death (25% of level
      progress), HUD; XP sources (mob kills, quests) follow with 1.4/1.5
- [ ] Level system with stat growth (HP, damage) —
      `register_on_level_change` pipeline already exists
- [ ] Simplified skill trees: 2 trees of ~5 talents per class, talent
      points per level, formspec UI
- [ ] 2–4 active abilities per class (hotbar/item based), cooldowns

### 1.4 Mobs & combat
- [ ] Faction guards (attack the enemy faction), spawned by military
      outposts + ambient patrols, levels scaling with territory depth
- [x] WoW-style starter-zone mobs: aggressive boar (day) and zombie
      (night, burns in daylight) with XP rewards and loot; more (wolves, …)
      follow with WP6
- [ ] Neutral/hostile mobs in tiers: border = weak, heartland = strong,
      elite mobs that require groups
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
- [ ] Quest framework (quest log UI, quest state in player meta)
- [ ] Quest-giver NPCs in the faction camps
- [ ] Mandatory questlines for level progression (level gates), including:
  - [ ] "Kill 5 guards at the enemy faction's border" (PvP trigger)
  - [ ] "Push into enemy territory and kill an elite mob" (exploration + risk)
  - [ ] Gather/kill quests across different biomes (forced exploration)

### 1.6 Professions & economy
- [ ] Job system: max. 2 jobs per player, chosen at job trainers
- [ ] MVP jobs: **Herbalism** (gather plants), **Alchemist** (potions),
      **Blacksmith** (weapons/armor), **Gem Hunter** (random gem drops
      while mining — mining itself is open to everyone)
- [ ] Gold system (currency, persistent)
- [ ] Trader NPCs: buy EVERY mob drop for gold, sell basic goods

### 1.7 Map
- [ ] Global map with fog of war, uncovered per player
      (evaluate existing map mods, e.g. mapserver/"map" mods; otherwise a
      custom solution via HUD/formspec)

---

## Phase 2 — Expansion (after MVP)

- [ ] More classes: **Paladin**, **Rogue**, **Warlock**, **Shaman**.
      Rogue stealth sketch (decided direction, details later): slower
      movement while stealthed (improvable via talents), opener bonus
      (crit/stun) only from stealth, no threat until the opener; NB
      engine visibility is global — no per-viewer invisibility, so
      stealth is semi-transparent/invisible for everyone
- [ ] More jobs: **Tailor**, possibly Enchanter
- [ ] **Player housing** (frontier plots with paid expansion + depth
      treasures, capital portal; spec: `docs/design/world.md` §5) — may
      be pulled into Phase 1 since it is the central gold sink; the
      **Home Stone** teleport may land earlier as a standalone
      convenience feature
- [ ] Race perks beyond the basics: race-exclusive professions/recipes,
      race-restricted classes (decide once more classes exist)
- [ ] More questlines, story arcs per faction (WoW-inspired lore adaption)
- [ ] Dungeon/instance-like structures (fixed elite areas with boss + loot)
- [ ] Raid bosses in the deepest heartland
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

- Guild system
- Battlegrounds/arenas (maybe much later)
- Flying mounts
