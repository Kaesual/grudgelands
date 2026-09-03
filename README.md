# Grudgelands

**A WoW-inspired voxel RPG for [Luanti](https://www.luanti.org/)** — factions,
classes, XP, quests, professions, housing, an item economy and geographic PvP,
built as a standalone Lua game rather than a mod pack.

> **Status: in development.** The world, mobs, three classes, combat,
> equipment, XP and the first money/vendor economy are playable. The final
> named-zone map is implemented and awaiting release/runtime gates; quests,
> professions, open-world housing and geographic PvP are not built. See
> [Current State](#current-state).

## The story

> **"A darkness has befallen the land."**

The **Accord** holds southern **Elandor** and the **Throng** northern
**Kragmar**. Their war over territory and pride is generations old. What is
new is the ancient demonic threat reaching upward through the Nether: it
endangers both factions without uniting them, so each side follows an
equivalent campaign in parallel and competition.

A new character chooses faction, race and class, wakes in one of six outer
starting settlements and travels through stable named regions toward a
central capital and the contested faction front. Local beasts, bandits and
corrupted sites give way to dangerous frontier warfare, the Battlegrounds and
two offshore level-60 dragon islands.

At level 20, a passive Housing Steward introduces the open-world Claim Stone
system. A home is protected inside eligible peaceful land, grows through four
claim tiers and becomes the only destination of the character's Home Stone.
It is neither a royal reward nor a private resource world; kings remain
killable high-end combatants whose Fallen Crowns are optional masterwork
trophies.

Full story frame: [docs/design/story.md](docs/design/story.md).

## The design

The authoritative game design lives in [docs/design/](docs/design/). Those
documents contain decided rules, numbers and lists; open questions stay in
focused `TODO-*.md` files until resolved.

### World, housing and PvP

[World design](docs/design/world.md) and the
[38-zone catalog](docs/design/world_zones.md) define two independently shaped
faction continents joined by the continuous four-zone Battlegrounds. Each zone
has a stable id, level range, race region, political terrain rule, PvP state,
biome palette, fixed hub and authored route neighbors. One fixed 2D layout
uses small land/water shapes, nearest-hub ownership and reliable independent
routes; seed variation begins with terrain, biome detail and content. Six
outer level-1–10 starts lead through home and heartland zones to six central
capitals; every level-1–30 zone is peaceful and every ordinary level-31–60
frontier, Battlegrounds and dragon zone is contested.

PvP state is one central transaction, not a combat-path exception. A valid
hostile action tags its initiator before resolution; safe→safe and
tagged→safe damage are blocked, while safe→tagged and tagged→tagged may
land. Effective PvP damage/support refreshes a 60-second tail, contested
ground forces the tag, disconnect preserves it and death clears it. At
y = −701 and below, non-ocean land is contested regardless of the peaceful
surface above.

Destructibility distinguishes actual anchors from scenery. Complete civic
cores, small functional NPC/resource anchors and irreplaceable route pieces
are hard-protected; roads, villages, outpost/camp shells and battlefield
dressing remain mutable but claim-excluded. Planned mainland water stays part
of its zone, an editable 80-node shelf follows the outer coast, deep ocean is
immutable, and full-column dragon channels keep the offshore islands boat-only.
Natural resources exist under land and zone-owned planned water; the six-race
supply gate compares all-resource deposit opportunities by exact host volume.
The still-open playable-boat behavior is isolated in
[TODO-design-boats.md](TODO-design-boats.md).

[Open-world housing](docs/design/housing.md) uses Claim Stones in exactly ten
peaceful level-11–30 zones. Four tiers protect cube radii 20/30/40/50, while
the first placement immediately reserves the complete future 101×101 x/z
footprint. Different owners use an exact one-sided expanded-AABB ten-node gap;
stable ids survive placement, recovery, dormancy, inactivity decay and
reissue. The Home Stone stores a bound claim id, channels for ten seconds and
has no capital fallback.

The Wyrmglass Crown and Stormscale Summit are equivalent contested offshore
dragon destinations. Each contains an apex camp whose shell, tents and
dressing remain mutable and claim-excluded. Only its small functional anchor
and twelve renewable sockets—two each of Citrine, Garnet, Jade, Diamond,
Sapphire and Ruby—are protected; both factions may use them and no player may
privatize them.

### Materials, items and professions

[Items and crafting](docs/design/items_crafting.md) distinguish the six-tier
material ladder from the four-tier profession-mastery ladder. Universal gear
progression is **Bronze → Iron → Steel → Silversteel → Embersteel →
Abyssal Steel**. Picks open exact natural depths of
−100/−300/−500/−700/−1000/map floor; resource harvesting has a
separate minimum tier, so a pick may reach an ore yet destroy it without a
drop when under-tier. The six strata remain visual depth language and ordinary
building stone rather than the access mechanism.

Quartz is universal. Citrine/Garnet/Jade form G1 and
Diamond/Sapphire/Ruby G2; every race region selects one G1, one G2, one
cultural material and one signature wood. The universal pick/bar spine never
requires a regional monopoly. Foreign G2 and optional target-race materials
come through contested and deep columns, the two apex camps and player trade.

There is [one item per concept](docs/design/inventory_equipment.md): the
vendor baseline and universal craft ladder are the same material-named items.
Professions improve them through refinement, ordinary affixes, one optional
cultural finish and a separate target-race PvP-special channel instead of
creating parallel catalogs. The equipped weapon slot is the sole source of a
skill's damage and appearance; the Character page also carries four armor
slots, an offhand, two trinkets and four Tailor-made bags.

[Six main professions](docs/design/professions.md) are cut by material rather
than class: Blacksmith, Leatherworker, Tailor, Woodcarver, Goldsmith and
Alchemist. Characters freely choose two; Cooking and First Aid are universal.
Goldsmith owns Quartz, the six regional gems, Rough-to-Cut processing,
Settings, both trinket slots and the exact natural-gem yield bonus. Mining,
smelting and universal base-item crafting remain open to everyone.

The gathering contract closes twelve one-cell herb, spice and food sources,
eight reused tree/food sources and six cultural sources. Healing herbs fail
closed to Alchemist authorization; ordinary plants drop one item, while
concentrated cultural sources differ by opportunity density and require their
ratified T4 pick, axe or shovel family.

### Economy

[Currency](docs/design/economy.md) is one ledger integer displayed as
copper/silver/gold; physical Gold is a separate material. The target Common
weapon axis is **25c / 65c / 1s60c / 4s / 10s / 25s**, with related slot
tables and ceiling-rounded **5% vendor buy-back**. Every mob drop has a
positive authored payout, but no mob or node directly drops ledger money.

A reproducible Income Ledger measures reliable tier-appropriate solo income
after routine repairs and consumables, excluding rare jackpots, bosses and an
assumed player market. Claim upgrades and the four mounts derive exact prices
from measured earning-time targets rather than stale fixed copper values. The
first Claim Stone is free; later tiers consume universal bars plus 30 minutes,
90 minutes and 3 hours of corresponding net income.

### Combat, classes and progression

[Combat](docs/design/combat_stats.md) uses small readable numbers, three
attributes, threat and the tank/healer/damage trinity while keeping all group
content beatable without a healer. Mobs outrun an unmounted player, switch
targets only at 120% threat and use a 25 m soft de-aggro plus 40 m leash.
Elites/rares telegraph their strongest attack so movement, not gear alone,
answers it.

The [MVP class kits](docs/design/classes.md) are Warrior, Mage and Priest.
The equipped weapon drives every swing skill while a server-authoritative
clock and current eye ray decide when and what it hits; click spam cannot
outrun hold. Enemy memory is Target-Frame state only, ally memory remains a
heal/shield fallback, and Fireball is a straight swept projectile that can
miss. Individual skill charges and resources replace the retired global
cooldown.

[Progression](docs/design/progression.md) targets level 60 in roughly 10–20
played hours, with one talent point every three levels and active capstones.
Death returns a player to their race's starting settlement with inventory
intact; the decided PvE penalty removes 25% of current-level XP progress
without de-leveling. The separate treatment of authoritatively attributed PvP
deaths remains in [TODO-design-pvp-death.md](TODO-design-pvp-death.md) before
WP9; no target-design document assumes an answer.

### Biomes, mobs and mounts

The [biome and mob catalog](docs/design/biomes_mobs.md) assigns final palettes,
resource sources and named-rare routes to the 38 zones while retaining the
running WP18/WP36 tables as an explicit migration baseline. Critters are
level-1 scenery with food-only drops, passive prey retaliate without aggroing
on sight, and enemies use the threat/chase model. Both factions receive every
universal input; race woods and cultural materials stay intentionally
asymmetric.

[Mounts](docs/design/mounts.md) are specified but not built. Universal riding
unlocks at levels 15/30/45/60: land mounts move at 6/8 nodes per second and
flyers at 7/10, with price targets of 15 minutes/45 minutes/2 hours/5 hours of
reliable net income. A permanent owner-bound item summons one ephemeral
entity; incoming damage dismounts. Battlegrounds allow flight, enemy territory
allows land mounts only, and an exact 48-node warning precedes forced flight
dismount over exterior ocean columns. Asset selection, mount attackability,
mounting in combat, underground flight, ceiling/drift, swimmer exhaustion,
variants and trainer presentation remain open in
[TODO-design-crafting-rework.md](TODO-design-crafting-rework.md).

Full milestone view: [ROADMAP.md](ROADMAP.md).

## Current State

*Last updated: 2026-09-03. Derived from [BACKLOG.md](BACKLOG.md) and
[ROADMAP.md](ROADMAP.md); those are the status sources of truth.*

**Shipped (18 of 46 work packages):** WP0–WP4, WP6, WP7, WP15, WP18,
WP19, WP25, WP33, WP35, WP36, WP38, WP39, WP43 and WP45 provide the playable
foundation, 42 mobs, three classes, equipment/bags, XP, threat, money/vendors,
the canonical six-tier material/depth/harvest contract, gathering sources and
current-ray combat/projectiles. New characters now remain frozen and immortal
behind the faction/race/class UI until their race start is loaded, then arrive
with one final teleport. WP16 is a canceled tombstone and is not shipped. WP43
supersedes WP25's running legacy while preserving saved-world migration.

**Not in the game yet:** quests, professions/recipes, talent trees, parties,
recovery, offhand items, affixes, durability, final structures, travel/map,
Claim Stone housing, mounts and bosses remain unbuilt. The 38-zone surface is
implemented but awaits R8's real-world/visual/runtime gates; geographic PvP,
bounded war-front life and the rebased economy are also pending. The
playable-boat contract, several mount details, deep-content
questions and PvP-death XP rule remain explicitly open in
[the boat TODO](TODO-design-boats.md),
[the crafting/mount TODO](TODO-design-crafting-rework.md),
[the depth TODO](TODO-design-depth.md) and
[the PvP-death TODO](TODO-design-pvp-death.md), respectively.

**In progress:** WP40, the named-zone map foundation, has been under
implementation since 2026-08-13 on branch `wp40-named-zone-world-foundation`.
The 2026-08-25 simple-map rebase deliberately retired its unfinished exact
partition/topology path. R0, R1, V1b, V1c and V1d are accepted history;
fixed-layout V1e R2 was independently and visually accepted on 2026-08-27.
Its current SVG has stronger single-warp border meanders, pinned curved routes,
tapered bays with deep-ocean mouth caps, coherent visible water and six
protected capital ingress corridors. Exhaustive V1e R2 validation freezes all
100 anchors, the 74 actual POI spurs, housing capacity and three exact
contact-face waterfalls without moving their reaches. The pure R3 vertical
implementation and canonical artifact and the complete R4 geography/policy
payload were independently accepted on 2026-08-27. The pure typed R5 Planner,
consolidated Adapter and canonical exhaustive artifact were independently
accepted on 2026-08-29. R6's frozen surface/resource catalogs, private
cultural-slot API, complete 32-seed evidence fleet and canonical artifact were
independently accepted on 2026-08-31. R7's single production writer, consumer
cutover, WP33 gathering payload, P9G successor and functional-anchor suffix
were independently accepted on 2026-09-02. Its release-oriented evidence is a
32-seed stratified main sample plus a separate seven-seed frontier-access lane,
not an exhaustive spatial claim.
The current [engineering contract](docs/research/wp40-engineering-brief.md)
and [R0–R8 plan](docs/research/wp40-simple-map-rebase-plan.md) preserve the 38
zones, routes, housing, policy and supply goals with a much smaller algorithm.
The accepted R2 artifact owns fixed-layout and once-per-layout capacity
evidence; the accepted R6 artifact owns 32-seed content/supply/access
evidence. R8 now owns the first real fresh Luanti world, visual quality,
production mapchunk performance and runtime evidence.

**Ready to start next:** WP26 and WP44 are the newly unblocked material and
economy roots. WP37, WP11, WP14, WP20, WP21 and WP8 are also ready behind shipped
dependencies; WP34 is not next because it still waits for map, structures and
economy.

**Caveats:** existing WP18/WP36 worlds retain already-generated rectangular
continents and are not WP40 migration targets; R8 must use a fresh v7 world.
WP7 still runs its old price curve and 25% buy-back until WP44. WP43 passed its
headless and independent-review gates but has not received a GUI/runtime pass;
validate migration only in a backed-up WP25 world. WP39 still needs its
recorded GUI combat test, and WP45's headless creation-flow review still needs
the short in-game first-character/reconnect pass at handoff. WP25, WP35 and WP36
retain their historical not-runtime-tested labels; WP40 remains
fresh-world-only.

## Running it

Use Luanti 5.x with mapgen **v7** (pinned in `game.conf`). Copy or symlink the
repository into the Luanti `games/` directory, then create a new world with
the Grudgelands game.

For the Flatpak installation used in development:

```sh
tools/sync_to_luanti.sh
```

Engine log: `~/.var/app/org.luanti.luanti/.minetest/debug.txt`.

### Reference projects (development only)

```sh
git submodule update --init --recursive --depth 1
```

`reference_projects/` contains nine pinned, read-only upstream sources. The
game builds and runs without them; they exist for engine/source verification,
licensing and stable `file:line` citations. See
[docs/reference_projects.md](docs/reference_projects.md).

## Repository layout

| Path | Contents |
|------|----------|
| [mods/](mods/) | Game code in `CORE`, `PLAYER`, `ENTITIES`, `ITEMS`, `MAPGEN` and `BASE` modpacks. |
| [docs/design/](docs/design/) | Decided game design — the living specification. |
| `TODO-*.md` | Open design questions awaiting a decision. |
| [docs/research/](docs/research/) | Engine/API briefings, reference studies and asset research. |
| [docs/process/](docs/process/) | Autonomous work-package workflow, the project-wide agent model policy, and the Claude CLI review procedure. |
| [ROADMAP.md](ROADMAP.md) · [BACKLOG.md](BACKLOG.md) | Goal-level plan and implementation packages/status. |
| [AGENTS.md](AGENTS.md) | Project conventions and Luanti/Lua contracts. |
| [VENDOR.md](VENDOR.md) | Vendored third-party code, commits, licenses and patch inventory. |
| [docs/reference_projects.md](docs/reference_projects.md) | Read-only source-submodule inventory and update discipline. |

## License

- **Code: GPL-3.0-or-later** — [LICENSE.txt](LICENSE.txt), with the
  compatibility matrix in
  [docs/research/licensing.md](docs/research/licensing.md).
- **Media:** original CC0 / CC BY / CC BY-SA / GPL terms, documented per mod;
  never NC or ND.
- Inspired by World of Warcraft, using original names and assets rather than
  Blizzard material.
