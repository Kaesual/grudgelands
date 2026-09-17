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
cores — capitals and starting settlements as whole build envelopes with
10-node aprons — small functional NPC/resource anchors and irreplaceable
route pieces are hard-protected and fail closed against indirect mutation;
roads, villages, outpost/camp shells and battlefield dressing remain mutable
but claim-excluded. Planned mainland water stays part
of its zone, an editable 80-node shelf follows the outer coast, deep ocean is
immutable, and full-column dragon channels keep the offshore islands boat-only.
Natural resources exist under land and zone-owned planned water; the six-race
supply gate compares all-resource deposit opportunities by exact host volume.
Playable-boat behavior is decided in [boats.md](docs/design/boats.md).
[Settlement design](docs/design/settlements.md) begins with the six race
starts, each built from the same library and its own palette: Hearthpine Vale
(dwarf, pine and stone), Dawnmere Fields (human, half-timbered loam on a
village green), Silverleaf Glade (elf, slate and marble under columnar
silverwoods), Stillgrave Hollow (undead, gravewood and obsidian round two
burial grounds), Sunscar Camp (orc, adobe behind crenellated breastworks) and
Kapok Cradle (troll, a plank village on stilts over a basin).

[Character visuals](docs/design/character_visuals.md) give the six peoples
recognisably different skins and a visual-only stature between 0.85 and 1.12 —
the collision box and eye height never change, so a troll fits through a
dwarf's door. Armor is visible: two lines, four slots, tinted with the same six
bracket colours the vendor icons use, and a character holds the weapon it has
equipped. Players and the humanoid NPCs on the same model — guards, bandits,
vendors — go through one composition function.

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
played hours, with **one talent point every two levels** — thirty by level 60,
enough to fill one whole tree — and a new active skill from a tree's
keystone.

The trees those points are spent in are still a proposal:
[skill_trees.md](docs/design/skill_trees.md) gives every class two trees of
two chains, twenty-eight ranks each, and lists all sixty-four talents. A
tree's
keystone either adds one new button or **replaces** one the player already
has, so no build ever carries more than two extra keys, and nine talents
deliberately break a cap or a control rule — each paying for it with a stated
cooldown. A fourth class, the [Scout](docs/design/scout.md) — leather, a bow
and a blade — is designed there too, planned now and built later. Both files
carry a **PROPOSAL** banner; as of 2026-09-16 the user has answered every
open question in them, and nothing in them is implemented yet.

Death returns a player to their race's starting settlement with inventory
intact; the decided PvE penalty removes 25% of current-level XP progress
without de-leveling, while a death authoritatively attributed to an eligible
hostile player by the PvP transaction costs no XP.

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
dismount over exterior ocean columns. Riding is taught by the capital job
trainers. Asset selection, mount attackability, mounting in combat,
underground flight, ceiling/drift, swimmer exhaustion and variants remain
open in [TODO-design-crafting-rework.md](TODO-design-crafting-rework.md).

[Boats](docs/design/boats.md) are specified but not built, and they are
deliberately not an earned unlock: the base boat is five wood on any
character's first day, moving at the player's own 4 nodes per second. A
shipwright on each continent teaches the improved boat once from level 30 —
paid in exactly one boat's worth of materials, rewarded with that boat — and
it matches the 8 nodes per second of the land mount unlocked at the same
level. One player per boat, never a mob; an empty boat may be picked up by
anyone and disappears after 24 unused hours; any hit ejects the rider while
the boat itself is indestructible. The open sea stays lethal through the
Kraken Guard rather than through boat damage, and the dragon channels carry
none.

Full milestone view: [ROADMAP.md](ROADMAP.md).

## Current State

*Last updated: 2026-09-17. Derived from [BACKLOG.md](BACKLOG.md) and
[ROADMAP.md](ROADMAP.md); those are the status sources of truth.*

**Shipped (22 of 49 work packages):** WP0–WP4, WP6, WP7, WP15, WP18, WP19,
WP25, WP26, WP33, WP35, WP36, WP38, WP39, WP40, WP43, WP45, WP-HUD and
WP-Speed provide the playable foundation: three classes, combat, mobs,
equipment/bags, currency,
canonical materials, gathering, exact life/resource bars, unified movement
effects and the named-zone world. New characters remain
protected behind character creation until the server has prepared all six
start areas, which it emerges once at startup. WP40's
[development acceptance](docs/research/wp40-completion.md) now includes the first
terrain/performance correction round and green native plus browser-local
Lua-5.1 user tests; slower browser generation is accepted for this server game.
WP16 is canceled and is not counted as shipped. WP-Scout, WP-HUD and WP-Speed
are counted in the 49; only WP-Scout remains open.

**Not in the game yet:** quests, professions/recipes, talent-tree keystones,
capstones and the Talents page, parties, recovery, offhand items, affixes,
durability, final structures, travel/map,
Claim Stone housing, mounts and bosses remain unbuilt. Geographic PvP,
bounded war-front life and the rebased economy are also pending. Remaining
mount and deep-content decisions live in [the crafting/mount TODO](TODO-design-crafting-rework.md)
and [the depth TODO](TODO-design-depth.md); the [boat contract](docs/design/boats.md)
and [PvP-death XP exemption](docs/design/progression.md) are already decided.

**In progress:** WP11 phase 1 has shipped its talent registry, 48 talents,
point/gate/persistence model and thirty numeric consumers; round-5 Lane U is
building X4's Talents page, respec price and level-up flow, while X3's
keystones, capstones and four abilities follow in round 6. WP13 has built
**all six start settlements and all six capitals**. The starts share one reusable building library with per-race
palettes -- small dense houses with doors, pane windows, stair roofs,
furnished interiors and exterior dressing -- and each is a different
settlement out of it: a dwarf craft village in a pine clearing, a human
farming hamlet on a green, an elf glade under columnar silverwoods, an undead
hollow round two walled burial grounds, an orc war camp behind a stake
palisade, and a troll stilt village on boardwalks over a basin. The package
also adds a server-side atmosphere layer (shadows, bloom, saturation, waving)
with per-zone fog, sky and light, seven vendored minetest_game building mods,
a curated 333-node decorative kit from castle_masonry, cottages, darkage and
xdecor-libre, and a textured isometric renderer used to review buildings
before playtests. The six start areas are emerged once at server start and no
hostile mob spawns inside their protected footprints.

The capitals were built out of the same library plus eighteen capital parts --
a basilica king's hall with a throne room, curtain wall, corner tower and
gatehouse, market square, colonnade, temple, barracks, scriptorium, granary,
stable, statue, and hedge, grove, stilt and water edge pieces. The four walled
capitals are **Highcourt, Dur Brannoc, Gor Drazhak and Nhal Veyr**; the two
open capitals are **Lethariel and Kezamba**. **Highcourt**
(human) was the pilot and put the seam in place: a settlement owns several
blueprints, a district plot levels itself onto the ground under its own
reference column, the avenues and the city wall are computed per mapchunk from
the ground the map actually has, and a capital's buildings are constructed only
when somebody goes there. Then came **Dur Brannoc** (dwarf, stair streets down
forty-four nodes of hillside), **Gor Drazhak** (orc, a stake palisade on an
earth rampart and a sunken fighting arena), **Lethariel** (elf, a planted belt
instead of a wall and a lore precinct on a lake), **Kezamba** (troll, boardwalks
on basalt piers round a cenote) and **Nhal Veyr** (undead, grave fields and a
walk-in mausoleum). Each has four districts of nine plots plus four pieces of
open ground -- a field, a pasture, a yard, a green -- and which district stands
in which quarter is decided by the world seed. Every street in every capital
now follows one rule: a flat cross profile, a levelled plateau where two
streets cross, open air and pillars under a street raised three nodes or more,
and a railed bridge, in that race's own palette, wherever one crosses water.
Their people stay put rather than mill about: most residents keep to one spot,
one in four works a craft with its own animation (smith, fisher, farmer, miner,
brewer, carver, mourner, sparring pair, forager), and only a minority walk a
short ring -- in Highcourt, 36 workplaces and 22 walkers among 144 residents.
A district reads as lived in because a butcher's house has a butcher in it --
twelve profession shops in all. WP13's round-2 merge also shipped the **one
weapon ladder**: vendor gear and the base craft ladder are now the same
material-named items (Bronze Sword, Silkweave Cowl), merged with `default`'s
tool ladder.

**Every start and every capital still awaits the user's GUI playtest**, and
the rest of WP13's 100-anchor roster is unbuilt: twelve villages (two of them
with a shipwright's plot), 24 outposts, 12 bandit camps, 6 mining camps, 4
mirefolk camps, 16 clash anchors, 2 dragon arenas, 2 apex camps and 10
rare-route pads. The mirefolk camps, clash anchors and dragon arenas are
dressing only here -- WP42 and WP23 own what happens in them -- and the apex
camps' twelve renewable sockets are WP34's. The six kings and their royal
guards are unbuilt too.

**Fishing** arrived with the same round: `grug_fishing` adds a craftable rod
that lasts 64 catches, a furnace-cooked fish and one catch table for the whole
world — right-click water, wait a few seconds, and the water gives something
back. Kezamba's anglers work its cenote, its fields grow papyrus in tilled
furrows, and its two vineyards are planted beds rather than bare kerbs.

**WP26 is shipped** (2026-09-16): a new `grug_smelting` mod adds the two-slot
dual furnace next to the ordinary one, the five lump-to-bar smelts, the five
alloys of the Bronze-to-Abyssal-Steel ladder, the twelve storage pack/unpack
pairs and the furnace's own T1 recipe, with the trader audit extended to the
alloy chain the engine itself cannot see. It still awaits the user's own
~10-minute runtime test. WP5, WP44, WP37, WP11, WP14, WP20, WP21 and WP8 are
also ready behind shipped prerequisites. WP34 still needs structures and
economy.

**Release boundary:** WP40 is completed as development work; it does not declare
our first public release or end fresh-server mode. Current-candidate resource
supply/access, feature/native/generation-order, runtime/RSS and release-engine
checks remain explicit [first-public-release work](BACKLOG.md#first-public-release-gates).
Historical results retain their own source identities; the accepted browser
playtest has no visible build ID. Old-world and old-item migrations remain absent.

**Other runtime caveats:** WP7 retains its old prices and 25% buy-back until
WP44, and WP39's recorded GUI combat test remains outstanding. WP43 has
headless/review evidence but no separate material-focused GUI acceptance;
WP25, WP35 and WP36 retain their historical untested labels. WP45's existing-
and new-character flows are green, while mid-creation reconnect is covered
headlessly. These unrelated gates are not closed by the map playtests.

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

- **Code: GPL-3.0** — our own files are GPL-3.0-or-later ([LICENSE.txt](LICENSE.txt)), but the combined game is GPL-3.0-only since the `grug_decor` kit includes GPL-3.0-only code from cottages (2026-09-14); with the
  compatibility matrix in
  [docs/research/licensing.md](docs/research/licensing.md).
- **Media:** original CC0 / CC BY / CC BY-SA / GPL terms, documented per mod;
  never NC or ND.
- Inspired by World of Warcraft, using original names and assets rather than
  Blizzard material.
