# Grudgelands

Final integrated status and exact gate identities: [Round 11 completion](docs/research/round11-completion.md).
Final technical gates PASS. The reviewed changes are delivered on main, synchronized
and pushed; GUI acceptance remains pending.

**A WoW-inspired voxel RPG for [Luanti](https://www.luanti.org/)** — factions,
classes, XP, quests, professions, housing, an item economy and geographic PvP,
built as a standalone Lua game rather than a mod pack.

> **Status: in development.** The world, mobs, four classes, combat,
> equipment, XP, money/vendors, Cooking, Alchemy and the integrated seven-primary
> profession/equipment work are delivered and playable.
> The named-zone world is implemented and still has explicit release/runtime gates;
> quests, open-world housing and geographic PvP are not built. See
> [Current State](#current-state).

## The story

> **"A darkness has befallen the land."**

The **Accord** holds southern **Elandor** and the **Throng** northern
**Kragmar**. Their war over territory and pride is generations old. What is
new is the ancient demonic threat reaching upward through the Nether: V1
foreshadows it, while the walkable Nether is the main V2 content update. It
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
frontier, Battlegrounds and dragon zone is contested. Surface difficulty rises
through three integer bands along the continent axis inside every published
zone range; Accord runs toward +z, Throng toward -z, the shared front toward
z=0 and the two dragon summits remain flat level 60.

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
dwarf's door. Visible armor has dedicated cloth, leather and metal art across
four slots and six material tiers, with matching inventory and worn designs.
A character holds the weapon it has equipped. Players and the humanoid NPCs on the same model — guards, bandits,
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
slots, an offhand, two trinkets and four bags; the approved Round-11 catalog
adds equivalent cloth and leather bag lines.

[Farming](docs/design/farming.md) defines crop cultivation, tiered hoe lifetime,
water-only buckets and slow bounded renewal of depleted wild plants.
[Durability and repair](docs/design/durability_repair.md) keeps broken gear and
lets every city profession trainer repair it for copper, with a maximum price
of 20% of its reference purchase price. Both are delivered in Round 11.

[Seven primary professions](docs/design/professions.md) are cut by material:
Weaponsmith, Armorsmith, Leatherworker, Tailor, Woodcarver, Goldsmith and
Alchemist. Characters choose two; Cooking is an unlimited secondary and First
Aid stays universal. Profession level advances independently through six
material tiers, while four mastery bands control improvement slots and selected
exclusive recipes.

Plain feedstocks and familiar base weapons, tools and metal, leather and cloth
armor belong exclusively to **Basics** and require no profession. Each
profession owns only its improvement and specialist routes; Weaponsmith and
Armorsmith share the Forge with separate authorization. Cooking keeps its
ordinary grid and furnace routes. The integrated, independently reviewed equipment work completes these catalogs,
terminal refinement, direct affix application and the retained kit model. MAP-B is
integrated and independently reviewed. Final interpreter parity and delivery
are complete; GUI acceptance remains pending.

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

[Combat](docs/design/combat_stats.md) uses one level-scaled pool curve, three
secondary attributes, threat and the tank/healer/damage trinity while keeping
all group content beatable without a healer. Mobs outrun an unmounted player, switch
targets only at 120% threat and use a 25 m soft de-aggro plus 40 m leash.
Elites/rares telegraph their strongest attack so movement, not gear alone,
answers it.

The [MVP class kits](docs/design/classes.md) are Warrior, Mage, Priest and
[Scout](docs/design/scout.md), whose bow arrows use held draw and ballistic flight.
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

The talent design is decided:
[skill_trees.md](docs/design/skill_trees.md) gives every class two trees of
two chains, twenty-eight ranks each, and lists all sixty-four talents. A
tree's
keystone either adds one new button or **replaces** one the player already
has, so no build ever carries more than two extra keys, and nine talents
deliberately break a cap or a control rule — each paying for it with a stated
cooldown. Scout's two complete trees and four base abilities are implemented,
alongside WP11's X1, X2 and X4 foundations. The original three classes still
await most X3 keystones and capstones; Round 11 supplies the targeted
Ironbound/Unbroken armor consumers without closing that wider work.

Death returns a player to their race's starting settlement with inventory
intact; the decided PvE penalty removes 25% of the whole current-level XP span,
floored at the level start, while a death authoritatively attributed to an
eligible hostile player by the PvP transaction costs no XP.

### Biomes, mobs and mounts

The [biome and mob catalog](docs/design/biomes_mobs.md) assigns final palettes,
resource sources and named-rare routes to the 38 zones while retaining the
running WP18/WP36 tables as an explicit migration baseline. Critters are
level-1 scenery with food-only drops, passive prey retaliate without aggroing
on sight, and enemies use the threat/chase model. Both factions receive every
universal input; race woods and cultural materials stay intentionally
asymmetric.

[Mounts](docs/design/mounts.md) have integrated, independently reviewed Round-10
runtime, capital-service and art changes. Final interpreter parity and delivery
are complete; GUI acceptance remains pending. Riding unlocks at levels 15/30/45/60; T1
moves at 6.4 nodes/s (+60%), while later land/flight tiers retain 8/7/10. The
owner's mesh is hidden only in first person, an untimed status shows tier and
actual speed, land mounts step over half/full blocks, and all mounted attacks are
refused. Capital-only Riding Trainers, twelve rendered icons and all six stable layouts
are delivered on main.

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

*Last updated: 2026-09-20. Derived from [BACKLOG.md](BACKLOG.md) and
[ROADMAP.md](ROADMAP.md); Round 11 technical delivery is complete;
the first playtest and focused followup checks remain the GUI acceptance gate.*

**Shipped foundation:** 23 of 53 tracked identities are complete: WP0–WP4,
WP6, WP7, WP15, WP18, WP19, WP25, WP26, WP33, WP35, WP36, WP38, WP39, WP40,
WP43, WP45, WP-HUD, WP-Speed and WP-Scout. The denominator includes numbered
WP0–WP49 and the three named packages; canceled WP16 is tracked but not shipped.
These foundations provide four classes, combat, mobs, the named-zone world,
materials, gathering, equipment, currency, Cooking/Alchemy and safe character creation.

**Delivered Round 11:** the independently reviewed build adds Scout and both
trees, live shields/books/quivers, family-filtered affixes, attacker-level armor,
slow equipment wear and money-only repair. Farming gains distinct seed art,
seven hoes, water buckets and bounded wild-plant renewal at lower initial density.
Reported beach columns, dragon persistence, mount orientation, station windows
and book refresh are corrected; open animated stables and profession displays
extend all six capitals. Targeted LuaJIT, plain-5.1 static and isolated native
engine checks pass; PUC runtime was explicitly waived for this round.

The first-playtest [followups](docs/research/round11-playtest-followups.md) add
directional arrow meshes, bow draw stages, reliable outer-district trainers and
the requested Sprint/mount speeds. Arrows stack to 200 and new Scouts receive
200. The beach fix is user-accepted; bow feel still needs GUI confirmation,
including the documented initial LMB camera gesture. The subsequent
[vegetation fix](docs/research/round11-vegetation-chase-fix.md) restores mob
pursuit through harmless plants while preserving cliff protection. The user
accepted that fix. Reviewed [interaction corrections](docs/research/round11-interaction-followups.md)
now limit ability pickup to 4 m, add mounted A/D and prevent simultaneous NPC
interaction and mount activation. [Round 12](docs/research/round12-plan/README.md) now plans the expanded farming,
Skills, art/UI and original-class talent work; implementation awaits the final
round Go.

**In progress:** WP11 still owns the original three classes' remaining X3
abilities and capstones; Scout completion does not close that broader package.
WP13 has six starts and capitals but still owns most of the 100-anchor POI roster.
WP10/WP29 retain broader catalog/economy work, WP14 retains carried light, and
WP22 retains six-pick runtime calibration and the deferred repair redesign.
Ordinary farming is delivered independently of future Claim Stone integration.

**Not yet:** quests, parties, remaining recovery work, Housing, geographic PvP,
war fronts and the first-public-release gates remain open. WP44 owns the full
economy rebase, while WP46's general explosion/fire/lava protection extends beyond
the delivered water guard. GUI acceptance remains required for the new gameplay
and visual changes; use the [Round-11 fresh-world checklist](docs/research/round11-next-playtest.md).

Historical Round-7 through Round-10 decisions are archived under
[docs/research/](docs/research/); current rules live only in `docs/design/`, and
remaining work lives in BACKLOG/ROADMAP or focused topic TODOs.

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

`reference_projects/` contains thirteen pinned, read-only upstream sources. The
game builds and runs without them; they exist for engine/source verification,
licensing and stable `file:line` citations. See
[docs/reference_projects.md](docs/reference_projects.md).

## Repository layout

| Path | Contents |
|------|----------|
| [mods/](mods/) | Game code in `CORE`, `PLAYER`, `ENTITIES`, `ITEMS`, `MAPGEN` and `BASE` modpacks. |
| [docs/design/](docs/design/) | Decided game design — the living specification. |
| `TODO-*.md` | Open design questions awaiting a decision. |
| [docs/research/](docs/research/) | Engine/API briefings, reference studies and asset research, including the Round 7 planning set: the [plants and potions reference survey](docs/research/plants-and-potions-reference.md), the [mob candidate evidence](docs/research/mob-candidates-evidence.md) and [game inventory extract](docs/research/round7-inventory-extract.md), and the two creative plans for the user's ruling, [Cooking and Alchemy](docs/research/cooking-alchemy-plan.md) and [the mob worlds](docs/research/mob-worlds-plan.md). |
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
