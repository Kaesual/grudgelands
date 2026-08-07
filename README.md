# Grudgelands

**A WoW-inspired voxel RPG for [Luanti](https://www.luanti.org/)** —
factions, classes, XP, quests, professions, gold and PvP, built as a
standalone game (not a mod pack) in Lua.

> **Status: in development.** The world, mobs, classes, combat and the
> money/vendor economy are playable; quests, professions and the map are
> not built yet.
> See [Current State](#current-state).

---

## The story

> **"A darkness has befallen the land."**

Two peoples share a world and hate each other for it. **The Accord** holds
the southern continent of **Elandor**, **The Throng** the northern
**Kragmar**; between them lies nothing but a strait of open water. The war
over territory and pride is generations old, and it is not going to end.

What is new is what comes from below. The **Nether** — this world's hell of
lava and demons — has opened portals into the overworld, and they were not
opened from our side. Something ancient and demonic is reaching up, and it
threatens both factions equally. It does not unite them. Each side fights
the darkness alone, in parallel, in competition — while still raiding the
other's coast.

You pick a faction, a race and a class, wake up in your race's capital, and
the world gets more dangerous the further you walk from it. Boars and
bandits at home; corrupted outposts, named beasts and elite packs further
out; a dragon on the mountain you can see at level 8 and only kill at 50;
and across the strait an enemy king in a guarded throne room whose crown is
a crafting ingredient.

Your own king, meanwhile, is the one who rewards you. Behind each continent,
past the deadly open sea, lies a chain of unspoiled isles — barren above the
rock and rich below it. Serve the realm well enough and the crown grants you
one: your isle, your build, and a shaft going down as deep as you can afford
to buy the rights.

Full premise: **[docs/design/story.md](docs/design/story.md)**.

---

## The design

The game design is a living specification under
**[docs/design/](docs/design/)** — only *decided* rules, numbers and lists
live there. This section is the tour; the docs are the truth.

### The world — [`world.md`](docs/design/world.md)

- **Two continents, one per faction**, mirrored at z=0, 3000×1600 nodes
  each, with soft noisy coastlines and a guaranteed 200-node strait.
  Everything else is ocean.
- **Difficulty is geography.** Mob level grows radially outward from your
  capital: safe core 1–10, inner ring 10–25, outer ring 25–45, the far
  coasts 45–60. Caves add a depth axis (~+1 level per 20 nodes down), so
  mining deep is an alternative to travelling out.
- **The war coast is capped at 20–30** — the strait-facing band is the PvP
  stage, and the first PvP quests arrive around level 20. Nobody is forced
  into PvP before that.
- **Guard strength runs inverse**: the capital watch is elite, war-coast
  guards are only local level +5. Invading is funnelled to where PvP is
  meant to happen; landing anywhere else means facing level-60 wildlife.
- **Controlled destructibility**: build and dig freely at home, never in
  enemy territory (not even a torch), never in the ocean. Ores respawn so
  a persistent world doesn't run dry.
- **Three race capitals per continent** (you spawn in your own race's),
  24 deterministic military outposts, ambient patrols between them,
  villages and flavor camps.
- **Apex world bosses**: one visible dragon POI per continent first, the
  enemy's dragon as the flagship PvP raid later.
- **Travel** is a Diablo-style waypoint network (unlocked by visiting,
  teleport only waypoint-to-waypoint, none in enemy land) plus a Home
  Stone with a 10 s cast and a 60 min cooldown.
- **Housing is a royal grant, not a purchase**: a questline at level 30
  earns you one of the King's isles behind your continent — a 100×100
  build box, free digging down to the seabed, and below that a ladder of
  **purchased depth rights**. Each step hides a finite set of treasure
  clusters you hunt with a dowsing rod; nothing regrows, so the next
  payout is the next step. That ladder is the game's central gold sink.
  Guild members may visit; a per-character trust list decides who may
  dig and open your chests.

### Biomes & mobs — [`biomes_mobs.md`](docs/design/biomes_mobs.md)

17 mirrored biomes, each race band tipping from its settled variant into
its wild nature variant as you move outward. Identical base drops on both
continents ("same loot, different look"), a full mob roster per biome
group, spawn parameters, per-race woods and the base-material map.

### Combat & character — [`combat_stats.md`](docs/design/combat_stats.md) · [`classes.md`](docs/design/classes.md) · [`progression.md`](docs/design/progression.md)

- **Small, readable numbers**: 20 HP as the Luanti anchor, ~×10 growth
  over 60 levels. Three attributes (Str/Int/Dex), automatic per-class
  growth; items carry the enchantments.
- **Threat, not proximity** — mobs pick targets by aggro (damage, plus
  0.5× healing), tank abilities generate ×3, taunt exists, and target
  switches need 120% of the current threat. The trinity works; it is never
  mandatory.
- **Mobs are faster than players** (4.4 vs 4.0) with a soft de-aggro at
  25 m and a leash at 40 m of drag — fleeing is hard, not impossible.
- **Elites and rares telegraph**: 2 s wind-up, then a ×3 hit into a 90°
  frontal cone that requires line of sight. Stepping aside is a clean
  miss. Named rares broadcast their spawn faction-wide.
- **MVP classes**: Warrior (rage), Mage and Priest (mana), 3–4 instant
  abilities each as hotbar items with cooldowns and a 1 s global cooldown,
  plus a soft target lock. Talent trees add the rest.
- **Pace**: level 60 in ~10–20 hours. The endgame is the game. Death costs
  25% of the current level's progress and a walk back — never items.
- Group content is sized for **2–3 players** and everything is
  **beatable without a healer**.

### Items, loot & crafting — [`items_crafting.md`](docs/design/items_crafting.md) · [`inventory_equipment.md`](docs/design/inventory_equipment.md)

- Quality tiers **Common / Uncommon / Rare** (Unique reserved), with
  enchantments rolled from ranges into item meta and shown in the
  description. The harder the enemy, the better the *roll window* — same
  mechanic everywhere.
- **The best gear comes from crafting or hard bosses**, never from
  vendors: the two top roll windows belong to masterwork recipes and boss
  loot.
- Four profession tiers gated by a **tome chain** (each tome consumes the
  previous one plus a keystone from the ring you just reached) — one
  mechanism, no skill-up grind.
- **Race-exclusive signature recipes** at the top end: production is
  race-locked, the item is tradeable — every race+profession combination
  becomes a market niche.
- Everything is crafted in the 3×3 grid, multi-stage, gated by a recipe
  unlock plus workbench proximity. Character screen on sfinv pages,
  equipment slots, Tailor-made bags.

### Professions & economy — [`professions.md`](docs/design/professions.md) · [`economy.md`](docs/design/economy.md)

Two freely chosen main professions per character (Blacksmith,
Leatherworker, Tailor, Alchemist, Herbalism, Gem Hunter) plus Cooking and
First Aid for everyone. Currency is copper/silver/gold stored as one
integer; **a full gold is a fortune**, reserved for guild founding,
housing and mining claims. Vendors buy every mob drop (at a quarter of
what they charge), but what they sell is a floor rather than a shop: six
catalogs of ten levels each, offering roughly what a normal mob of that
bracket drops — always Common and therefore **always without
enchantments**, which is what keeps crafters ahead. Each race also has
its own vendor, open only to that race and 10 % cheaper for them. Every
item carries a level requirement, so gear you cannot use yet is loot to
trade, not to wear.

### Guilds — [`guilds.md`](docs/design/guilds.md)

An **ownership and access layer**: one shared bank account — 6 tabs and
two purses, reachable at the capital or from a terminal on any member's
isle — plus contested mining claims out in the open world, mutual isle
visiting, three fixed roles and guild chat. Deliberately no guild levels,
perks or wars.

### Where the journey goes

- **Phase 1 (MVP)** — the loop above end to end: world, classes, mobs,
  quests with level gates, professions, gold and traders, the map.
- **Phase 2** — four more classes (Paladin, Rogue, Warlock, Shaman),
  the housing isles (a strong candidate to move into Phase 1, since
  nothing else gives gold a purpose), the walkable Nether with crossings
  into enemy land, dungeons, apex bosses per region, the reef band,
  mounts, reputation, player trading.
- **Phase 3** — own textures/models/sounds, localization (German first),
  balancing, server performance, onboarding.

Deliberately **not** planned: guild progression, battlegrounds, flying
mounts.

Full plan with checkboxes: **[ROADMAP.md](ROADMAP.md)**.

---

## Current State

*Last updated: 2026-08-07. Derived from [BACKLOG.md](BACKLOG.md) and
[ROADMAP.md](ROADMAP.md) — those are the source of truth; this is the
summary.*

**Shipped (10 of 25 work packages):** the foundation, the whole
world/combat layer, and the money economy.

- **World**: two ocean-separated continents with soft coasts, 17 mirrored
  biomes, six race-capital spawn platforms, the radial mob-level field
  plus the inverse guard field, the ocean build lock and the deep-sea
  Kraken Guard (WP2, WP18).
- **Mobs & combat feel**: 38 mobs on a level/tier engine, 10 named rares
  with faction broadcast, faction guards on 24 deterministic outposts with
  hourly patrol legs, 12 bandit camps, the threat table, leash/evade, the
  elite/rare telegraph, nametags and the con-color target frame, ore
  respawn, and a pathfinding/density pass (WP1, WP6).
- **Character**: faction → race → class creation, Warrior/Mage/Priest with
  attribute and HP formulas, the XP curve to 60 with death penalty, 3
  abilities per class with cooldowns, global cooldown and soft target
  lock, visible race passives, and the character screen with equipment
  slots and bags (WP3, WP4, WP15, WP19).
- **Money & vendors**: copper/silver/gold as one integer with a HUD
  line, eight vendor NPCs at the six race capitals (two faction
  Quartermasters, six race-exclusive ones with a 10 % discount), six
  generated gear catalogs of ten levels each on an hourly rotation, a
  weak healing potion, and armor that finally mitigates damage — with
  cloth and plate bound to the character class (WP7).

**Not in the game yet:** quests and quest NPCs, professions and crafting
recipes, talent trees, the fog-of-war map, guilds, housing isles,
travel/waypoints, offhand and shields, loot rolls on class items,
durability and repair, parties, food and rest, apex bosses, and the real
capital/outpost structures (WP6 ships anchors and banners, not
buildings).

**Ready to start next** (no design blockers): loot & enchantments (WP5),
professions (WP10), talent trees (WP11), world structures (WP13),
offhand (WP14), guilds (WP16), travel (WP17), party system (WP20),
recovery & innkeeper (WP21), apex world bosses (WP23).

**Caveats:** every shipped work package has been runtime-tested
(2026-08-07 — six findings on the WP1–WP19 pass, all fixed; WP7 passed
without findings). One known defect remains: melee auto-attacks against *players* still use the engine's raw
scaling, so a held button can deal 0 damage in PvP — the mob-side fix is
in, the PvP port is queued. Mapgen changed in WP18, so **existing worlds
are incompatible; always start a fresh one**. All art is currently
vendored from reference projects (vendors still look like faction
guards); own assets are Phase 3.

---

## Running it

Luanti 5.x with mapgen **v7** (pinned in `game.conf`). Copy or symlink the
repo into your Luanti `games/` directory, then create a **new** world with
the Grudgelands game.

For the Flatpak install used in development:

```sh
tools/sync_to_luanti.sh   # copies the game into ~/.var/app/org.luanti.luanti/...
```

Engine log for diagnosis:
`~/.var/app/org.luanti.luanti/.minetest/debug.txt`.

---

## Repository layout

| Path | Contents |
|------|----------|
| [mods/](mods/) | the game: `CORE`, `PLAYER`, `ENTITIES`, `ITEMS`, `MAPGEN`, `BASE` modpacks (our mods use the `grug_` prefix) |
| [docs/design/](docs/design/) | the decided game design — the living spec |
| `TODO-*.md` | open design questions, folded into `docs/design/` once decided |
| [docs/research/](docs/research/) | engine/API briefings, reference-project studies, asset shopping lists |
| [docs/process/](docs/process/) | the work-package workflow |
| [ROADMAP.md](ROADMAP.md) · [BACKLOG.md](BACKLOG.md) | goals and phases · work packages with status |
| [AGENTS.md](AGENTS.md) | conventions, Lua/Luanti rules, patterns — read this first before contributing |
| [VENDOR.md](VENDOR.md) | vendored third-party mods: upstream commit, license, patch inventory |
| `reference_projects/` | read-only references (the engine, Lord of the Test, VoxeLibre, minetest_game, mobs_redo) |

## License

- **Code: GPL-3.0-or-later** — full text in [LICENSE.txt](LICENSE.txt),
  compatibility matrix in
  [docs/research/licensing.md](docs/research/licensing.md).
- **Media: each file keeps its original license** (CC0 / CC BY / CC BY-SA
  / GPL), documented per mod in a `LICENSE-media.md` table. Never NC or ND.
- Inspired by World of Warcraft; **no Blizzard assets or names are used**.
  Own names, own assets, recognizable character.
