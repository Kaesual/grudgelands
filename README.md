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
  coasts 45–60. Every capital sits in a **level-1 bubble** 40 nodes wide
  that fades back into the field over the next 200, so wherever you wake
  up, the first animal you meet is a level-1 one. Caves add a depth axis
  (3 levels per 50 nodes down, −500 = level 30, −1000 = the level-60
  cap) — and the bubble does not reach down there, so mining deep is an
  alternative to travelling out even under your own city.
- **The war coast is capped at 20–30** — the strait-facing band is the PvP
  stage, and the first PvP quests arrive around level 20. Nobody is forced
  into PvP before that.
- **Guard strength runs inverse**: the capital watch is elite, war-coast
  guards are only local level +5. Invading is funnelled to where PvP is
  meant to happen; landing anywhere else means facing level-60 wildlife.
- **Controlled destructibility**: build and dig freely at home, never in
  enemy territory (not even a torch), never in the ocean. Nothing regrows:
  a mined-out vein is gone for good, and the world stays supplied by going
  deeper rather than by waiting. The one exception is a **guarded mining
  camp**, where a handful of nodes refill over hours — you cannot build a
  farm around them, because you cannot dig the walls.
- **Depth is a ladder, not a chore**: the stone below you is six rock
  strata (−100 / −300 / −500 / −700 / −1000 / bedrock), and each one can
  only be broken by a tool of its own tier. How deep you can mine is the
  same statement as what you can wear. Cave walls carry their layer too,
  so a deep cave is no shortcut past the gate — and every stratum drops
  ordinary cobble, because what is gated is access, not building
  material. A better pick also digs **faster**, not only deeper. The
  bottom layer, **below −1000**, is endgame territory in its own right:
  lava lakes and a level-appropriate roster behind the last pick on the
  ladder.
- **The deep has no safe places.** Below −300 the dark starts sending
  things after you at a rate that grows with depth — light does not stop
  it, and neither does walling yourself in, though you always get about
  two seconds of warning. Nothing down there hits harder than a level-60
  mob; what makes it dangerous is that it never quite stops arriving.
  What the depth pays out is raw material — there is no special gear
  layer down there, because the best gear is made, not found.
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
  **six purchased depth rights**, one per rock stratum, from 50c to a
  full gold (≈ 1.9g for the lot). Each step hides a finite, deliberately
  generous set of treasure clusters you hunt with a dowsing rod —
  filled in that step's own rock tier — plus **one rare material that
  exists nowhere else in the world**, six in all up the ladder. Nothing
  regrows, so the next payout is the next step. That ladder is the game's
  central gold sink. Guild members may visit; a per-character trust list
  decides who may dig and open your chests.

### Biomes & mobs — [`biomes_mobs.md`](docs/design/biomes_mobs.md)

13 mirrored biome bands (20 registrations), each race band tipping from
its settled variant into its wild nature variant as you move outward. Identical base drops on both
continents ("same loot, different look"), a full mob roster per biome
group, spawn parameters, per-race woods and the base-material map.
Animals come in **three classes**: *critters* are scenery with a use
(always level 1, food drops only, so a full larder ends the hunt by
itself), *passive prey* are the large grazers — they never attack on
sight, but a punched stag fights back, which is what keeps the leather
tiers behind a real fight — and *enemies* are everything else.

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
  abilities each as hotbar items. Enemy target memory feeds the Target Frame
  only; ally memory remains a heal/shield fallback. Talent trees add the rest.
- **Skills never slow your swing** (WP38 base, WP39 targeting revision).
  Swing skills keep Luanti's fast native weapon animation while one
  server-authoritative weapon clock permits a full hit at the equipped
  interval. WP39 makes the current crosshair ray authoritative: a ready attack
  waits without being consumed while aim is empty/blocked, then fires on the
  first held pass that sees a valid hostile. Click spam cannot outrun hold. A
  fresh Swing click also restores dropped-loot pickup through one
  blocked-by-world 4 m server ray where the no-dig item pointabilities hide a
  ground-level drop. Even ordinary tool/fist combat pushes the next full skill
  swing out. Melee timing and skill timing are independent: every melee skill is
  the ordinary weapon attack **plus** an effect that fires when that
  skill's own charge is full — shown as a bar under the icon that fills
  red→yellow→green and disappears when the skill is ready. Rotation is the
  hotbar: keys 1–8 pick which effect is armed next, without ever
  interrupting the attack. A small gold crosshair ring shows binary weapon
  readiness. Hostile casts require current aim, while Fireball travels straight
  from the cast-time crosshair and can miss; heals and shields retain ally
  target memory.
- **Your weapon lives in a slot, not in the hotbar** — and it is the only
  thing that decides what a skill hits for and what it looks like. Every
  ability shows your own sword, in the bar and in your hand, and swapping
  the weapon reskins all of them at once; an empty slot means bare fists,
  never a blocked button. **Strike is the universal swing skill**: click or
  hold LMB for a clocked full swing at the hostile currently under the
  crosshair, and release stops it. A
  two-handed weapon costs you the offhand, so a greataxe and a carried
  torch are a choice between the two.
- **Pace**: level 60 in ~10–20 hours. The endgame is the game. Death costs
  25% of the current level's progress and a walk back — never items.
- Group content is sized for **2–3 players** and everything is
  **beatable without a healer**.

### Items, loot & crafting — [`items_crafting.md`](docs/design/items_crafting.md) · [`inventory_equipment.md`](docs/design/inventory_equipment.md)

- **Two ladders, and they never mean the same thing.** T1–T6 is the
  *material* ladder — Bronze, Iron, Steel, Silversteel, Embersteel,
  Grudgesteel, one per ten levels, with gems at T2/T4/T6 and alloys
  smelted in a two-slot furnace. Apprentice / Journeyman / Expert /
  Master is the *mastery* ladder, a property of the crafter.
- **One item per concept.** The vendor catalog and the base craft ladder
  are the same material-named items (Bronze Sword, Steel Chestplate),
  and **everyone can craft the base tier** — the deliberate Minecraft
  feel. A profession never makes a parallel item.
- **What a profession is for is making an item better**: it **refines**
  it (+15 % damage, +100 % durability — Honed, Reinforced, Ornate), and
  only a refined item can be **enchanted**. Enchants are written into
  the name as **max 2 prefixes + 2 suffixes** — *Heavy Lucky Stone Sword
  of Bear and Ox* is a full four-slot Master piece — and your mastery
  tier decides how many of those slots you can fill.
- Quality tiers **Common / Uncommon / Rare** (Unique reserved) follow
  straight from the affix count: 0, 1–2, 3–4. Values are rolled from
  ranges into item meta; the harder the enemy, the better the *roll
  window* — same mechanic everywhere.
- **The best gear comes from crafting or hard bosses**, never from
  vendors: the two top roll windows belong to masterwork recipes and boss
  loot, and no vendor ever sells a refined or enchanted item.
- **One recipe book per profession**, six T1–T6 groups in one list:
  your level makes a group visible, a **tier keystone** from the ring
  you just reached unlocks it. One mechanism, no skill-up grind.
- **Race-exclusive signature recipes** at the top end: production is
  race-locked, the item is tradeable — every race+profession combination
  becomes a market niche.
- Everything is crafted in the 3×3 grid, multi-stage, gated by a recipe
  unlock plus workbench proximity. Character screen on sfinv pages,
  equipment slots — armor, trinkets, and the weapon/offhand pair that
  decides what your skills hit for — and Tailor-made bags in four sizes
  up to 32 slots.

### Professions & economy — [`professions.md`](docs/design/professions.md) · [`economy.md`](docs/design/economy.md)

Two freely chosen main professions per character, **cut by material and
never by class** so the roster does not grow every time a class does:
Blacksmith, Leatherworker, Tailor, Woodcarver (staves, wands, scepters,
orbs — casters had no craftable weapon before), Goldsmith (both trinket
slots, gem refinement) and Alchemist, who gathers its own herbs. Cooking
and First Aid stay free for everyone, and Cooking gets a recipe book of
its own without costing a slot. Currency is copper/silver/gold stored as
one integer; **a full gold is a fortune**, reserved for guild founding
and the deepest housing step. Vendors buy every mob drop (at a quarter of
what they charge), but what they sell is a floor rather than a shop: six
catalogs of ten levels each, offering roughly what a normal mob of that
bracket drops — always Common and therefore **always without
enchantments**, which is what keeps crafters ahead. Each race also has
its own vendor, open only to that race and 10 % cheaper for them. Every
item carries a level requirement, so gear you cannot use yet is loot to
trade, not to wear.

### Guilds — [`guilds.md`](docs/design/guilds.md)

A **social and access layer**: one shared bank account — 6 tabs and two
purses, reachable at the capital or from a terminal on any member's
isle — plus mutual isle visiting, three fixed roles and guild chat. A
guild owns **no ground**; the contested mining claims were designed and
then cut, so there is no land purchase anywhere in the game.
Deliberately no guild levels, perks or wars.

### Mounts — [`mounts.md`](docs/design/mounts.md)

Specced, not built. Riding is a **universal skill** on the same four
mastery tiers, and mounts are **bought with gold, never tamed**: slow
land, fast land, slow flying, fast flying at 1s / 8s / 30s / 60s — about
one gold for the whole ladder, and the second-largest thing to save
towards after housing. The first flight buys *terrain*, not speed.
**Taking damage throws you off** — a mount is faster than every mob in
the game, so it buys travel between fights, never an exit from one.
Three places refuse you as well: out over the open sea an
**"Exhausted"** debuff drops a rider into the water after ten seconds,
on a housing isle there is no riding and no flying at all, and in enemy
territory a land mount is fine while a flying one is not.

### Where the journey goes

- **Phase 1 (MVP)** — the loop above end to end: world, classes, mobs,
  quests with level gates, professions, gold and traders, the map.
- **Phase 2** — four more classes (Paladin, Rogue, Warlock, Shaman),
  the housing isles (a strong candidate to move into Phase 1, since
  nothing else gives gold a purpose), the walkable Nether with crossings
  into enemy land, dungeons, apex bosses per region, the reef band,
  mounts, farming, reputation, player trading.
- **Phase 3** — own textures/models/sounds, localization (German first),
  balancing, server performance, onboarding.

Deliberately **not** planned: guild progression, guild-owned land,
battlegrounds, a separate Enchanter profession. (Flying mounts used to
be on this list; they came back as the two top riding tiers on
2026-08-07, fenced in by the open-sea and housing-isle rules above.)

Full plan with checkboxes: **[ROADMAP.md](ROADMAP.md)**.

---

## Current State

*Last updated: 2026-08-10. Derived from [BACKLOG.md](BACKLOG.md) and
[ROADMAP.md](ROADMAP.md) — those are the source of truth; this is the
summary.*

**Shipped (15 of 40 work packages):** the playable foundation now spans two
continents, 42 level-scaled mobs, three classes, equipment and bags, XP,
threat, money/vendors, the six rock strata and their ore bands. The weapon slot
is the sole source of skill damage and appearance, while native held animation,
one full slot-fed swing cadence and charged procs replace the old GCD-driven
melee. WP39 makes the current server eye/look ray the sole hostile ability aim,
with ready-until-aimed swings, exact-once PvE/PvP settlement, a binary
weapon-ready reticle and opt-in `/combatdebug`. It also ships reusable swept
projectiles and a straight, missable Fireball bounded to eight active shots per
owner/session.

**Not in the game yet:** quests and quest NPCs, professions, recipes, talent
trees, the fog-of-war map, guilds, housing, travel, offhand items, loot affixes,
durability, parties, recovery, bosses, mounts and real capital/outpost
structures remain unbuilt. The material ladder still lacks its two-slot
furnace, alloy bars, armor recipes, gathering nodes and material-name catalog
conversion. Loot/affixes and professions remain design-blocked by the affix
words, signature recipes, keystones, material grades and cooking lists in
`TODO-design-crafting-rework.md`.

**Ready to start next:** WP34 is first in the dependency/owner order and owns
the depth arrival pressure, corrected level curve, camp-only ore respawn, deep
lava and continental Abyssal Crystal. WP26 and WP37 follow as the alloy-chain
and surface-density increments. Guilds, trader rotation, gathering nodes,
talents, structures, offhand, travel, parties, recovery and apex bosses also
have no design blocker; their exact order remains in `BACKLOG.md`.

**Caveats:** WP39 passed its headless Lua 5.1 gates, a mandatory Full Review
with 0 findings after two Low fixes, and a clean Engine/Perf Review after one
Medium and one Low fix, but its GUI runtime plan is still user-owned and has
not been performed; WP25, WP35 and WP36 are likewise not runtime-tested. WP38's
native-animation/cadence base and bounded fresh-press loot bridge were tested
in game, but that does not validate WP39's current-ray targeting, binary HUD
reticle, hostile casts, projectile visuals/collision or session limit. The
jungle-fringe ground and WP36's extra Throng badlands band remain open design
questions, while the two-handed rule remains dormant until WP14 supplies an
offhand item. WP34 still owns the running game's stale world-wide ore respawn
and depth-level curve, WP37 owns the unshipped surface-density increase, and
`grug_core.open_sea_at` still starts too far out for housing and mounts.
Mapgen changes from WP18, WP25 and WP36 make existing worlds incompatible, so
runtime tests need a fresh world; the shipped bracket gear names and vendored
art are also still provisional.

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

### Reference projects (development only)

```sh
git submodule update --init --recursive --depth 1
```

`reference_projects/` holds the eight upstream sources this codebase is
developed against, as git submodules. **The game builds and runs without
them** — they are never loaded by the engine and nothing in `mods/` reads
them. They are needed to *develop* the codebase: every engine-behaviour
claim, licence verification and `file:line` citation in the design docs
points into them, pinned at the commit it was written against. Details and
the update discipline: [docs/reference_projects.md](docs/reference_projects.md).

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
| [docs/reference_projects.md](docs/reference_projects.md) · `reference_projects/` | the eight read-only upstream sources as git submodules — not part of the build |

## License

- **Code: GPL-3.0-or-later** — full text in [LICENSE.txt](LICENSE.txt),
  compatibility matrix in
  [docs/research/licensing.md](docs/research/licensing.md).
- **Media: each file keeps its original license** (CC0 / CC BY / CC BY-SA
  / GPL), documented per mod in a `LICENSE-media.md` table. Never NC or ND.
- Inspired by World of Warcraft; **no Blizzard assets or names are used**.
  Own names, own assets, recognizable character.
