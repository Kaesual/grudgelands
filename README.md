<p align="center">
  <img src="menu/icon.png" alt="Grudgelands crest" width="96" height="96">
</p>

# Grudgelands

**An open-source multiplayer voxel RPG for [Luanti](https://www.luanti.org/).**
Explore, build and craft in an open world, with classes, quests and character
progression inspired by classic MMORPGs. Grudgelands brings together ideas
from the Luanti community's games and mods into a shared fantasy adventure.

**[Play in your browser at kaesual.com](https://kaesual.com)** ·
[Install locally](#play-with-luanti) · [Roadmap](#whats-ahead) ·
[Discord](https://discord.gg/M4auM7yunk)

> **Playable and in active development.** The first release is still being
> built. Expect rough edges, changing balance and development-world resets.

## What you can play today

- **Four classes, different ways to fight.** Play a Warrior, Mage, Priest or
  Scout, with melee, spells, healing or a bow and blade. Each class has two
  talent trees to shape its abilities as you level toward 60.
- **An open world to explore and change.** Travel through named regions,
  forests, mountains and caves; gather resources, dig and build outside
  protected places. Six starting towns and six capitals give each people
  its own home, architecture and surroundings.
- **Quests and character progression.** Follow your starting town's stories,
  help local inhabitants and take on stronger enemies. More than 500 quests
  lead each people from its starting town through its homelands and the
  contested borderlands to the war front at level 60, with repeatable
  bounties, a journal, quest tracker, world atlas and minimap to help you
  find your way. From level 41 each faction's main story follows a
  burning debt across the front to a shared finale for a small group.
- **Crafting and equipment.** Make basic gear, choose two of six primary
  professions, and improve your equipment with enchantments and upgrades.
  Weaponsmith, Armorsmith, Tailor, Leatherworker, Woodcarver and Goldsmith
  each have their own recipes; Cooking and Alchemy are available alongside
  them. Creatures drop white, blue and gold gear, bosses always two pieces,
  and a Fallen Crown lifts an item beyond its tier.
- **Life between adventures.** Grow crops, go fishing, prepare food, visit
  vendors and save for a mount or a boat. Bind your home at an innkeeper so
  you can return after a journey, and travel between the waystones of your
  faction's towns.
- **Adventure together.** Choose one of two factions and six peoples, shape
  your character's look, earn cloaks through achievements, then form a
  party with up to ten players of your
  faction. Party health displays and atlas markers help you stay together
  while exploring and fighting.
- **A world you can hear.** Creatures, spells, crafting and the people you
  talk to have their own sounds; every region has a quiet ambience by day
  and night, forges ring and rivers run, and each capital has its own calm
  music, with volume settings for both.
- **Fight the other faction when you choose to.** Contested lands and enemy
  territory flag you for PvP, a button flags you anywhere, and only two
  flagged players can harm each other. Each faction holds a fortress at the
  front and sends its players to raid the enemy's war camps.

The Accord and the Throng live on rival continents, divided by an old
conflict. A rising threat beneath the world gives both sides something else
to fear: coins branded with its mark buy the dead of both armies, and each
faction hunts the payers on its own until the collector itself takes shape
at a rift on the front. What waits below is a story for a later expansion.

## Current State

*Last updated: 2026-10-05. Based on [BACKLOG.md](BACKLOG.md) and
[ROADMAP.md](ROADMAP.md).*

The systems above are implemented and installed in the local development build.
[Round 36](docs/planning/round36-plan.md#completion-2026-10-05), "The main
questline", is complete and pushed and awaits a playtest on a fresh world,
on desktop and in the browser. Each faction now has its main story from level
41 to 60: three chapters from its fortress's Warmaster that follow branded
pay through the front's worst villains, an errand behind enemy lines, a
traitor in its own ranks and a finale for two or three players against
Isquarre the Tithe-Eater at a burning crack in the ground, with an
achievement and a cloak for each faction's story and for the finale
([story](docs/design/story.md)). Some quest steps ask you to do something
at a place, such as breaking a seal or taking a rubbing, and their objects
appear only to players on that quest. Corrupted creatures with an ember
glow roam the front, and a war commander guards two enemy camps. Every
village, outpost, camp, mine, battlefield and lair got fitting decoration,
and every house in the towns and capitals small touches such as a torch by
the door or flowers under a window. Creatures running home can no longer be
mistaken for targets, priests heal more with Intelligence gear, and the
dragons push players away with a warning and have larger hazards.
[Round 35](docs/planning/round35-plan.md#completion-2026-10-05), "Fixes and
character creation", is complete and pushed; its first playtest findings
fed Round 36. Held spells and attacks no longer miss zombies,
crocodiles and other creatures that have turned away; gear that breaks makes
a sound and looks clearly broken, ores, gems and sand sound when you dig
them, and quest lists show each quest's state by colour. Music now plays
only in the six capitals, each with its own tunes, and takes the place of
the town ambience while it plays. You create your character in a single window, and nothing is
kept until you confirm it. Creatures of the night leave at dawn, a few
creatures drop less valuable loot, and talents keep their strength at
every level, with several talents rebalanced.
[Round 34](docs/planning/round34-plan.md#completion-2026-10-04), "Sound", is
complete and pushed; its listening playtest fed Round 35. The game now has
sound: clicks and cues when you talk to people,
trade, craft and level up, hits that sound like the weapon you swing, spells,
creature voices and roaring dragons, a quiet ambience for every region by
day and night, and calm music that is only
downloaded while music is on ([sound](docs/design/sound.md),
[credits](CREDITS.md)). Creatures now follow you across streams, a Bag of
Coins lets you hand money to another player, and the Crownbinder and Decor
Merchant show on the map.
[Round 33](docs/planning/round33-plan.md#completion-2026-10-04), "Items,
professions and achievements", is complete and pushed; its playtest on a
fresh world fed Round 34. Gear now drops in white, blue and gold, named creatures and
elites drop more, and every boss gives two blue or gold pieces; you can wear
gear only once you reach its level. Enchantments grow with the item's level and
show their tier, each profession can upgrade the items it makes, and a
Crownbinder in every capital crowns one item beyond its tier for a Fallen
Crown and a fee. Vendors sell only first-tier gear, repairs cost more,
potions heal a fixed amount per tier, critical hits deal double, and a Decor
Merchant sells blocks and lights for your home. Alchemy is learned next to
Cooking, and achievements unlock cloaks that swing on your character.
[Round 32](docs/planning/round32-plan.md#completion-2026-10-03), "Fixes,
preparation and research", is complete, pushed and accepted. The
minimap zooms in twice as far, so quest givers and trainers are easier to
tell apart, and hostile camps get their own red mark on the world map. Zone
names now show in green, yellow or red for friendly, contested or enemy
territory, with a line saying which. Holding the left mouse button while
mining now fights a creature that walks into your aim and goes back to
mining once it is gone, quest objectives name creatures as you meet them in
that zone, and short notices such as "You dodge!" or a refused potion
appear above your bars instead of in chat. The server also handles many
players at once more evenly, and three studies prepare the next steps:
performance with 50 to 100 players, sound and music for the first release,
and items and professions.
[Round 31](docs/planning/round31-plan.md#completion-2026-10-03), "PvP,
appearance and clean-up", is complete, pushed and accepted. Players of
the two factions can fight each other only when both are flagged: contested
lands and enemy territory flag you, and a button flags you for a minute
anywhere ([PvP rules](docs/design/pvp.md)). Each
faction has a fortress near the Battlegrounds with a General, a waystone
and quests to raid the enemy's war camps. You now choose your character's
face, hair and features at creation, townsfolk and guards look different
from each other, enchantments show as coloured accents on your gear, and
both dragons fight in round arenas with ice or ember hazards.
[Round 30](docs/planning/round30-plan.md#completion-2026-10-02), "Performance
and clean-up", is complete, pushed and accepted.
Quest markers, the world map, the minimap, crafting and the crosshair cost
the server much less, a second start of a world takes about half as long,
and mobs give up a player they cannot reach and walk home. Return home now
sits on the Character page, and each dragon island has a small beach and a
wooden pier at its boat landings.
[Round 29](docs/planning/round29-plan.md#completion-2026-10-02), "Economy and
travel", is pushed and was tested on a fresh world. New
quests take every people from its starting town to the war front, with
directions that fit each world and repeatable bounties at the front and on
the dragon islands. Vendors now buy loot and materials at prices set by tier,
and mounts, boats and talent resets cost what a player earns in a set time.
Boats, sold by a Shipwright in every capital, are the way to the dragon
islands, and waystones in every starting town and capital connect your
faction's homes; gems now lie at their own depth, and the Battlegrounds are
wider with a road across the middle.
[Round 28](docs/planning/round28-questing-leveling-plan.md#completion-2026-10-02)
places every zone's creatures by rules that read the world's own terrain,
with levels that rise toward the next zone, loot that matches their level
and named leaders at their camps; leveling follows a gentler curve, and a
message feed, per-class offhands and Scout slots ship alongside.
[Round 27](docs/planning/round27-minimap-plan.md#completion-2026-09-30)
is accepted. Our own round minimap
replaces the built-in one: north up, drawn from the world map, it shows quest
givers with their state, trainers, innkeepers, the Housing Steward, your home
and your party, with arrows on the rim for members out of view, and can be
switched off on the Map tab. The world map shows height more clearly with
stronger shading, contour lines and lighter high ground, and a server can
choose a sharper high-quality map.
[Round 26](docs/planning/round26-capitals-housing-cleanup-plan.md#completion-2026-09-29)
is accepted. A placed Claim Stone now starts as a draft that you activate with
five lumps of coal within five minutes, and the Housing Steward hands it out.
Buffs and debuffs show as icons above the skill bar, the combat state as an
icon next to the health bar, with a new Effects tab on the Character page and
class icons in the party display.
Old utility items and duplicate tool names are cleaned up. The six capitals
get more irregular walls and each its own character: a royal river city, an
angular mountain hold, a necropolis, a war camp, a lakeside city and a jungle
city round its cenote.
[Round 25](docs/planning/round25-housing-plan.md#completion-2026-09-29) adds
housing: from level 20 a Housing Steward in your capital hands out a Claim
Stone. Placed in your faction's level-11–30 lands and fuelled with coal or
charcoal, it protects a 101 × 101 home, lets you grant friends access and can
be your travel home. Roads and the cores of villages, camps and points of
interest are now protected for everyone.
[Round 24](docs/planning/round24-mining-underground-mobs-plan.md#completion-2026-09-29)
replaces fixed pick depths with stone that gets harder with depth: a pick that
is too weak cannot dig it, loose ground can be dug by hand or shovel, and
better tools need a minimum level. Shallow tunnels now find coal and other ores,
and mountains and cliffs show rock layers. Start zones get a gentle level
gradient and more mobs, which roam calmly near where they spawned. Mining ores
and gems and catching fish give XP, up to ten quests can be tracked, and lava
and drowning scale with health. Character creation can be paused.
[Round 23](docs/research/round23-completion.md) makes full-world preparation
cover everything players can see from the surface, underwater or in flight.
Wild plants, ground cover and trees now regrow around players up to their
natural density. Mountains get a tree line with shrubs, alpine meadows and snow caps,
and forests alternate with clearings. All six capitals get consistent walls. Round 21 improves terrain, POI ground and capital access, resource availability,
furnace feedback and fuel rules, inexpensive Bronze arrows, food feedback and
boar targeting. Lakes and coasts gain bounded visual variation, aquatic plants
and passive fish. The preceding Round 20 supplies 240 quests, the full 100-anchor
art roster and contextual combat/digging controls. In-game visual acceptance and
longer-term balancing remain ongoing. A [startup correction](docs/research/round21-startup-fix.md)
fixes the new fish registration and native arrow recipe binding; isolated server
startup and the 200-arrow Basics recipe are verified.

The scripted war-front battles are still unfinished; the story's
continuation below the world waits for the underworld expansion.

<details>
<summary>Development tracking and known caveats</summary>

**Delivered:** 47 of 54 tracked work-package identities are complete, 3 are
canceled and 4 are open, several with playable portions (after the
2026-09-29 [work-package audit](docs/planning/wp-audit-2026-09-29.md)). This
is a tracking count, not a percentage of game completion. The latest delivered
increment is
[Round 36](docs/planning/round36-plan.md#completion-2026-10-05)
(the main story from level 41 with its finale at the rift, quest objects,
the decor pass over every point of interest, the evading-mob and banner
fixes, Priest heals, the dragon arenas), independently reviewed, merged
and pushed, after Round 35 (aiming at turned creatures, capital music, small
item and quest fixes, the one-window character creation, night mobs at
dawn, level-proof talents), Round 34
(sound effects, creature voices, ambience and music, mobs in water, the Bag
of Coins), Round 33 (drops, enchant tiers and upgrades, the crown, vendors,
potions, cloaks and achievements), Round 32 (map and HUD fixes, the held
left click, notices in the feed), Round 31 (PvP, looks, dragon arenas) and
Round 30 (performance); everything up to Round 36 is pushed, Rounds 25–35
count as accepted and Round 36 awaits its playtest.
[Project status](docs/STATUS.md) records acceptance, and the
[Round 36](docs/planning/round36-plan.md#gui-playtest-checklist),
[Round 35](docs/planning/round35-plan.md#gui-playtest-checklist),
[Round 34](docs/planning/round34-plan.md#gui-playtest-checklist),
[Round 33](docs/planning/round33-plan.md#gui-playtest-checklist),
[Round 32](docs/planning/round32-plan.md#gui-playtest-checklist),
[Round 31](docs/planning/round31-plan.md#gui-playtest-checklist),
[Round 30](docs/planning/round30-plan.md#playtest-checklist),
[Round 29](docs/planning/round29-plan.md#playtest-checklist),
[Round 28](docs/planning/round28-questing-leveling-plan.md#playtest-checklist),
[Round 27](docs/planning/round27-minimap-plan.md#playtest-checklist) and
[Round 26](docs/planning/round26-capitals-housing-cleanup-plan.md#playtest-checklist-fresh-world)
playtests remain separate.

**Ready for further work:** with the main story in place, the first
release needs the playtests of the recent rounds, balance and the release
checks. A possible music tab, a few missing decoration pieces and the
main-menu background are noted, and the deep spawn pulse stays for later. Points of interest stay at fixed positions (per-world
placement set aside); the [roadmap](ROADMAP.md) records the V1 scope and order.

**Caveats:** Round 36 needs a fresh world (its decoration and the dragon
arenas are part of world generation);
sound volumes and the new looks are tuned from playtests. Quests never ask you to kill
players; PvP quests target enemy camp garrisons. The confusing Cooking feedback now has a distinct success message;
the trainer flows still need in-game acceptance. Friendly-guard healing remains
deferred. Round 32's [performance review](docs/research/perf-review-2026-10-r32.md)
measured 50 and 100 simulated players; a test with real clients and
first-release validation are still open. Optional
full-world preparation can take many hours; the atlas does not require it. See
the [latest playtest checklist](docs/planning/round36-plan.md#gui-playtest-checklist),
the [Round 35 checklist](docs/planning/round35-plan.md#gui-playtest-checklist),
the [Round 34 checklist](docs/planning/round34-plan.md#gui-playtest-checklist),
the [Round 33 checklist](docs/planning/round33-plan.md#gui-playtest-checklist),
the [Round 32 checklist](docs/planning/round32-plan.md#gui-playtest-checklist),
the [Round 31 checklist](docs/planning/round31-plan.md#gui-playtest-checklist),
the [Round 30 checklist](docs/planning/round30-plan.md#playtest-checklist),
the [Round 29 checklist](docs/planning/round29-plan.md#playtest-checklist),
the [Round 28 checklist](docs/planning/round28-questing-leveling-plan.md#playtest-checklist),
the [Round 27 checklist](docs/planning/round27-minimap-plan.md#playtest-checklist),
the [Round 26 checklist](docs/planning/round26-capitals-housing-cleanup-plan.md#playtest-checklist-fresh-world)
and the [Round 24 checks](docs/planning/round24-mining-underground-mobs-plan.md#completion-2026-09-29).

</details>

## What's ahead

The [full roadmap](ROADMAP.md) separates planned features from delivered work.
There are no fixed release dates yet.

- **Toward the first release:** playtests of the main story and its
  finale, performance with many players, balance and reliable everyday
  play.
- **Later adventures:** a walkable underworld expansion with its own story,
  creatures and terrain, and scripted faction clashes on the war front. Other
  plans include further classes, dungeons, regional bosses, reputation and
  player trading.
- **Continued refinement:** clearer onboarding, accessibility, localization,
  art and sound, and multiplayer performance.

## Play with Luanti

You can try the current version **[in your browser](https://kaesual.com)**,
or run the game locally with Luanti. Grudgelands is a standalone game with
its dependencies bundled; no client mod is required.

For a local world, place this repository in your Luanti `games/` directory
as `grudgelands`, then select it when creating a **new world**. The game uses
mapgen **v7**. Development uses Luanti **5.17.0-dev**; compatibility with older
versions has not been established.

<details>
<summary>Local development setup</summary>

For the Flatpak installation used in development, run this from the repository
root to copy the game into Luanti's game directory:

```sh
tools/sync_to_luanti.sh
```

For source-based development, also fetch the pinned reference projects:

```sh
git submodule update --init --recursive --depth 1
```

These reference checkouts are for development only; playing does not require
them. See the [reference-project guide](docs/reference_projects.md) and
[project conventions](AGENTS.md).

</details>

## Feedback and contributions

Try a class, follow a few quests or explore with a friend. Feedback about
confusing moments, combat, pacing and places worth exploring is especially
useful. Join the **[Grudgelands Discord](https://discord.gg/M4auM7yunk)** for
questions, ideas and quick feedback, or open a
[GitHub issue](https://github.com/Kaesual/grudgelands/issues) for a concrete
bug. When reporting a bug, include what you were doing, your game version
and whether you played through the browser or a native Luanti client.

Code, artwork, sound and design feedback are welcome. For a larger change,
start with a discussion of the idea and check the
[design documents](docs/design/README.md) and [backlog](BACKLOG.md).

## The person and tools behind it

I'm Jan, the designer behind Grudgelands. I use AI extensively for development
and some artwork, while shaping the game through hands-on planning,
playtesting, review and repeated iteration. Making sandbox freedom and RPG
progression work together takes many small decisions, experiments and
revisions. This is a project I care deeply about, and I remain responsible
for its direction and what goes into it.

## Built on community work

Grudgelands would not be possible without Luanti and the people who have
spent years building its games, mods and tools. Their care, creativity and
shared knowledge are a large part of its foundation. The project draws on
both reference implementations and openly licensed code and artwork from
projects such as Minetest Game, VoxeLibre, Lord of the Test,
Mobs Redo, Animalia, Animal World and many others.

The [reference-project list](docs/reference_projects.md) links to the projects
we study; [VENDOR.md](VENDOR.md) records the code we ship and our changes.
[CREDITS.md](CREDITS.md) thanks the composers, sound designers and artists
whose work the game uses; media authors, sources and licenses are documented
alongside the assets in per-mod license files.

## Support development

If you enjoy Grudgelands and would like to support its continued development,
you can **[buy me a coffee](https://buymeacoffee.com/kaesual)**. Thank you for
playing, sharing feedback or helping in whatever way suits you.

## Explore the design

The [design index](docs/design/README.md) contains the decided game rules; the
[documentation guide](docs/README.md) explains where everything else lives.
Some describe systems still being built; the [backlog](BACKLOG.md) tracks
implementation, and [research notes](docs/research/) retain the supporting
investigations and delivery records.

<details>
<summary>Browse the game design</summary>

| Area | Design documents |
|------|------------------|
| World and places | [World](docs/design/world.md): geography and world rules; [zones](docs/design/world_zones.md): regions and level ranges; [settlements](docs/design/settlements.md): towns and capitals; [story](docs/design/story.md): factions and the campaign. |
| Characters and combat | [Classes](docs/design/classes.md): abilities and resources; [Scout](docs/design/scout.md): bow and blade; [combat](docs/design/combat_stats.md): damage and defenses; [PvP](docs/design/pvp.md): the PvP flag, fortresses and war camps; [visuals](docs/design/character_visuals.md): peoples, equipment appearance, cloaks and achievements. |
| Progression and quests | [Progression](docs/design/progression.md): levels and rewards; [talents](docs/design/skill_trees.md): character builds; [quests](docs/design/quests.md): objectives, journal and credit. |
| Items and crafting | [Items](docs/design/items_crafting.md): materials and recipes; [item tiers](docs/design/item_tiers.md): enchant values, upgrades, the crown, potions and drop prices; [professions](docs/design/professions.md): trades; [stations and enchantments](docs/design/crafting_equipment_revision.md): current crafting rules; [equipment](docs/design/inventory_equipment.md): slots and bags; [durability](docs/design/durability_repair.md): wear and repair; [economy](docs/design/economy.md): money, prices and services. |
| Wildlife and everyday life | [Biomes and mobs](docs/design/biomes_mobs.md): habitats and creatures; [spawn regions](docs/design/spawn_regions.md): where each zone's creatures live and at which level; [farming](docs/design/farming.md): crops; [housing](docs/design/housing.md): Claim Stone homes. |
| Travel and playing together | [Mounts](docs/design/mounts.md): riding; [boats](docs/design/boats.md): water travel and the way to the dragon islands; [home travel](docs/design/home_travel.md): innkeepers and return; [parties](docs/design/parties.md): groups; [atlas](docs/design/world_map.md): maps, minimap and markers. |
| Sound | [Sound](docs/design/sound.md): effects, creature voices, ambience, music and the sound settings. |
| Decision routing | [Round 18 decisions](docs/design/playtest_quality_revision.md): where the Round 18 playtest-quality rules now live. |
| Hosting | [World preparation](docs/design/world_preparation.md): generating starting areas or the full world. |

</details>

## License

Grudgelands' own code is **GPL-3.0-or-later** ([LICENSE.txt](LICENSE.txt)).
The combined game is **GPL-3.0-only** because it includes GPL-3.0-only code
from cottages; see the [license overview](docs/research/licensing.md).

Media retain their individual licenses, documented per mod: CC0, CC BY,
CC BY-SA or GPL, as applicable. The
[Grudgelands crest](menu/LICENSE-media.md) is CC0.
