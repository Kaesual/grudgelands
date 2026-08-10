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
- **Player housing — the King's isles**: beyond the coastal sea behind
  each continent lies a chain of unspoiled isles; the **King grants one
  per character** for merit (questline, level 30). A 100×100 build box,
  free digging down to the seabed, and below it a **ladder of six
  purchased depth rights** — one per rock stratum, 50c/2s/6s/20s/60s/1g
  ≈ 1.9g — whose finite treasure clusters (no respawn, detector items to
  find them) are the central gold sink. The main outlet for
  free building, and the only place a player meets their own King as an
  ally (`docs/design/world.md` §5).
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
- **One material ladder, six tiers** (decided 2026-08-07,
  `docs/design/items_crafting.md` §3.0): Bronze → Iron → Steel →
  Silversteel → Embersteel → Grudgesteel, one per ten character levels,
  with gems at T2/T4/T6 and alloys smelted in a two-slot furnace. Six
  **rock strata** gate digging by tool tier, so how deep you can mine is
  the same statement as what you can wear. **One item per concept**:
  the vendor catalog and the base craft ladder are the *same*
  material-named items, everyone can craft the base tier, and what a
  profession adds on top is **refinement** (+15 % damage, +100 %
  durability) and **prefix/suffix enchants** — never a parallel item.
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
- **Guilds as a pure social and access layer** (a shared bank account
  reachable from members' isles, mutual isle visiting, fixed roles,
  guild chat): `docs/design/guilds.md`. **Continental mining claims were
  removed on 2026-08-07** — a guild owns no ground, so there is no land
  purchase in the game at all. Deliberately NO guild levels/perks/wars —
  Luanti is not MMORPG enough for that.
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
      wall), mirrored biome bands per
      `docs/design/biomes_mobs.md` §1.3 (20 registrations after the
      2026-08-08 capital-biome carve and WP36's `grug_badlands_east`),
      guaranteed strait and coastal ocean, deep-sea guard mob. WP36
      finished the coastline: the mask carves to `emax.y` (no more
      floating tree crowns over the water), runs in the mapgen
      environment, and a `run_at_every_load` LBM heals older worlds
- [x] Difficulty gradient: `grug_core.difficulty_at/mob_level_at` radial
      field + `guard_level_at` (mobs and guards actually scale with them
      since WP6; WP36 added the level-1 bubble at every race capital, so
      the four side capitals no longer start a fresh player against
      level-8 wildlife)
- [x] Faction spawn points: walkable camp platforms at the three race
      capitals per continent (players spawn in their own race's capital;
      real capital structures follow with WP13). WP36 made the platform
      height a single decider that is forced when undecided, instead of
      an invented fallback that read differently in two sessions
- [x] Build/dig restrictions per territory (own continent free, enemy
      continent and the whole ocean locked; capital protected zones +
      the WP6 POI registry for outposts; R4 ore respawn shipped with WP6)
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
- [x] **Weapon slot, and auto-attack as a skill** (WP35): one equipment
      slot whose item is the single source of damage *and* appearance for
      every skill of its type — no fallback to whatever is in the hand.
      Every ability item wears the equipped weapon's skin on its own color
      orb (which retires the deferred "own ability icons"), and the held
      attack button becomes a universal ability, **Strike**, swinging at the
      weapon's own speed (WP35's original toggle was replaced by native
      interaction plus an authoritative held clock in WP38's 2026-08-10
      correction; WP39 has since replaced only that correction's enemy-lock
      target authority with current crosshair aim)
      (`docs/design/inventory_equipment.md` §2, `combat_stats.md` §2,
      `classes.md` §2b/§2c). Two-handed weapons declare their hand count
      here, but the rule stays dormant until WP14 ships an offhand item.
      **Not runtime tested**
- [x] **Swing timing and skill timing become independent** (WP38, corrected
      2026-08-10): swing items retain Luanti's native animation and direct
      object input/interaction; a bounded fresh-press server ray restores
      dropped-loot pickup where no-dig pointabilities mask it. Native enemy
      packets carry zero damage
      and one server-authoritative clock attacks only the current hostile under
      the server eye/look ray while LMB is held (plus one direct-click latch
      consumed on the next throttled attack pass; 0.05 s threshold, scheduled
      on the actual engine step).
      Release stops
      held repeats; click spam and ordinary tool/fist packets share the same
      equipped-weapon cadence bound. Every due ability attack is one full swing,
      and every skill is that ordinary weapon attack
      **plus** an effect that fires when its own charge is full — shown as
      a bar that fills red→yellow→green and vanishes when ready. That
      closes the old competing damage streams and ungated PvP punch, and
      **retires the 1 s global cooldown** of WP19:
      per-skill charges and resource costs are the limiters now. A separate
      accepted-hit transaction fires at most one selected proc per due landed
      full swing
      (`docs/design/combat_stats.md` §2, `classes.md` §2b/§2c)
- [x] **Crosshair-authoritative combat** (WP39, shipped 2026-08-10): WP38's
      fast cosmetic held animation and one full slot-fed swing per equipped
      weapon interval remain, while a ready attack waits until the current
      server eye ray finds a hostile in range. Aim misses preserve readiness; a
      valid attack consumes cadence even when later dodged or cancelled. Enemy
      target memory is Target-Frame/UI state only, ally memory remains a heal
      fallback, and a binary gold ring shows weapon readiness without inventory
      writes. Charge/Taunt/Smite require current aim; Fireball uses the reusable
      swept-projectile foundation to travel straight at 20 m/s for at most 20 m,
      spends mana on a miss and is bounded to eight active shots per owner/
      session. Permanent admin-only `/combatdebug` ships with it
      (`docs/design/combat_stats.md` §2, `classes.md` §2b; full shipped contract
      and outstanding GUI runtime plan in `BACKLOG.md` WP39).

### 1.4 Mobs & combat
- [x] Faction guards (attack the enemy faction), spawned by military
      outposts + ambient patrols, levels scaling with territory depth
      (WP6: 24 deterministic outposts, hourly patrol legs, `guard_level_at`
      with auto-elite ≥ 60; real outpost structures follow with WP13)
- [x] WoW-style starter-zone mobs: aggressive boar (day) and zombie
      (night, burns in daylight) with XP rewards and loot; more (wolves, …)
      follow with WP6
- [x] Neutral/hostile mobs in tiers: safe core = weak, outer ring and
      coasts = strong, elite mobs that require groups; incl. neutral
      **bandit camps**
      (humanoid loot source — cloth — in both territories)
      (WP6: 38 mobs on the level/tier engine, elite/rare telegraph,
      named rares with faction broadcast, 12 deterministic camps;
      WP36: **42 mobs** — a `critter` tier for the small animals plus
      four new ones for the caves, the bone forest and the swamp — and
      the large grazers became **passive prey**: they never attack on
      sight and they fight back when attacked)
- [x] **Aggro/threat system**: mobs pick targets by threat (damage +
      healing × factor); tank threat tools/taunt follow with class
      abilities (1.3) — WP6: threat table in `grug_core`, 120 %
      hysteresis, heal threat, taunt, leash/evade
- [ ] Food & recovery basics: slow natural HP regen, food for
      out-of-combat recovery, healing potions (alchemy, 1.6) for
      in-combat emergencies
- [x] **Good pathfinding** — dangerous mobs must reliably reach their
      targets (not get stuck in ravines etc.); evaluate and if necessary
      improve the mob engine's pathfinding quality (quality criterion, not
      a nice-to-have). Mobs run slightly faster than players so evading
      is never trivially easy (WP6-T10 + review: four `api.lua` fixes,
      the 45 m chase model, `fear_height` 6 cliff rule)
- [x] Loot drops (trash loot to sell, crafting materials) — WP6: the
      shared material/food items plus every family's drop table, gated by
      the player-tag rule

### 1.4b Loot, refinement & affixes
- [ ] Item quality tiers Common/Uncommon/Rare (color-coded; Unique
      reserved in the architecture, ships post-MVP) — quality now follows
      the **affix count**: 0 Common, 1–2 Uncommon, 3–4 Rare
- [ ] Class items as drops: wand, mage robe, warlock robe, iron armor,
      iron sword, dagger, … (a few items per class); **a drop's material
      tier matches the mob's tier** (a Steel item drops from level 21–30
      mobs and nowhere else)
- [ ] Simple enchantment system with **roll ranges**: items drop with
      randomly rolled bonuses, e.g. strength +1 to +3, attack speed +5% to
      +20% (values in item meta, visible in the description)
- [ ] **Refinement and the prefix/suffix system**
      (`docs/design/items_crafting.md` §6b): only a profession can refine
      a base item, only a refined item can be enchanted, and enchants are
      **max 2 prefixes + 2 suffixes** written into the item name
      ("Lucky Stone Sword of the Bear"). Mastery tier decides how many of
      the four slots a crafter can fill
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
      and spices for all, healing herbs need the Alchemist)
- [ ] MVP jobs — **six, cut by material and never by class** (re-cut
      2026-08-07): **Blacksmith**, **Leatherworker** (×5 leather via the
      player-tag loot hook), **Tailor** (bags), **Woodcarver** (staves,
      wands, scepters, orbs — casters had no craftable weapon before),
      **Goldsmith** (both trinket slots, gem refinement, Gem Detector),
      **Alchemist** (gathers its own herbs). Herbalism merged into the
      Alchemist, Gem Hunter into the Goldsmith; mining and smelting stay
      open to everyone, and so does crafting the base item of every tier
- [ ] Crafting model: everything in the 3×3 grid, multi-stage,
      recipe-unlock gated + workbench proximity for profession recipes,
      **one recipe book per profession** with six T1–T6 groups — level
      controls visibility, the tier keystone controls the unlock
      (`docs/design/items_crafting.md` §2.2,
      `docs/design/inventory_equipment.md` §4). Cooking gets a book too,
      without keystones and without costing a main slot
- [x] Material ladder — world materials (WP25): the three new ore nodes
      (Silver, Quartz, Garnet) plus Abyssal Crystal, mese repurposed as
      Emberstone, and the **six rock strata with their digging gates** —
      five new nodes below `default:stone` (the T1 stratum), placed as
      `stratum` ores registered last so cave walls inherit their tier,
      and a re-parameterised pickaxe `maxlevel` ladder to open them
      (`docs/design/items_crafting.md` §3.0.1/§3.0.4, `world.md` §2 R6).
      Walkable to −500 with today's items; T4–T6 need the picks of
      WP26/WP29. **Needs a fresh world, not runtime tested yet**
- [ ] Material ladder — the two-slot furnace and the alloy chain on top
      of it (WP26, `docs/design/items_crafting.md` §3.0.2)
- [x] Gold system (currency, persistent) — WP7: one copper integer in
      player meta, 100c = 1s / 100s = 1g display-only, HUD + `/money`
      (`docs/design/economy.md` §1)
- [x] Trader NPCs: buy EVERY mob drop for gold; sell only the lowest
      tier per category (vendor floor rule, economy.md) — WP7: 8 vendors
      at the six race capitals, six bracket catalogs with the hourly
      rotation, race-exclusive vendors + 10 % same-race discount, 25 %
      buy-back (job supplies and the one 25c profession recipe book per
      profession follow with WP10; the rotating extras pool grows to four
      families with WP30, so casters can buy a floor weapon)

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
- [ ] Profession split once the population supports it: Blacksmith →
      Weapon-/Armorsmith (`docs/design/professions.md` §5). **The Bowyer
      and Enchanter splits are dropped** (2026-08-07): bows belong to the
      Woodcarver and the quiver to the Leatherworker, and enchanting is
      what every profession does to its own refined items rather than a
      seventh profession taking a cut of all six
- [ ] **Decide: bow/ranged-weapon system + a Hunter-like class** — not in
      the current class plan. The item half is already specced,
      licence-clean and owned (bows = Woodcarver, quiver = Leatherworker,
      `docs/design/items_crafting.md` §9), so only the class decision is
      missing
- [ ] **Player housing — the King's isles** (per-character grant at
      level 30, 100×100 build box, **six** purchased depth steps — one
      per rock stratum, ≈ 1.9g — with finite treasure clusters, isle
      styles, visitor/trusted access, guild-bank terminal; spec:
      `docs/design/world.md` §5, open tuning:
      TODO-design-housing.md) — **strong candidate to pull into Phase 1**:
      it is the central gold sink AND the only sink that opens before
      level 60, so Phase 1 without it has nowhere for gold to go
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
- [ ] **Mounts** (spec decided 2026-08-07: `docs/design/mounts.md`):
      riding is a universal skill on the same four mastery tiers,
      **bought with gold, never tamed** — slow land, fast land, slow
      flying, fast flying at 1s/8s/30s/60s ≈ 1g, a welcome second
      long-term sink next to housing. Open sea throws a rider off after
      10 s of "Exhausted"; housing isles forbid riding and flying
      outright
- [ ] **Farming** — Minecraft-like, adapted from VoxeLibre or Lord of the
      Test, together with the extra herbs and cooking recipes as one
      later expansion package. **Spices are farmable, healing herbs never
      are**, and the found-only cooking ingredients never become crops
      (`docs/design/biomes_mobs.md` §2)
- [ ] Reputation system (simplified)
- [ ] Auction-house-like trading between players
- [ ] **Ocean content**: the reef band around continents and housing
      isles (coral/kelp flora, fish, shore wildlife) — decided in
      `docs/design/world.md` §2b, catalog open (`biomes_mobs.md` §1.2)

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
  social and access layer
- Guild-owned land: continental mining claims were designed and then
  **removed** (2026-08-07) — there is no land purchase in the game
- Battlegrounds/arenas (maybe much later)
- A seventh "Enchanter" profession — enchanting belongs to all six

*(**Flying mounts left this list on 2026-08-07**: `docs/design/mounts.md`
makes the two flying tiers the travel milestone of the second half of the
game, fenced in by the open-sea "Exhausted" rule and the no-mount isles.)*
