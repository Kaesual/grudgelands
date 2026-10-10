<p align="center">
  <img src="menu/icon.png" alt="Grudgelands crest" width="96" height="96">
</p>

# Grudgelands

**Choose a faction. Grow into a hero. Build a place to call home.**

Grudgelands is an open-source fantasy RPG for [Luanti](https://www.luanti.org/),
combining MMO-inspired classes, quests and progression with the freedom to
gather, craft and build in a shared voxel world.

Follow your faction's story, develop your talents and team up for dangerous
bosses. Between adventures, improve your equipment, tend your crops and
return to a home you built yourself.

**2 factions · 6 peoples · 4 classes · 500+ quests · Progression to level 60**

**[Play in your browser](https://kaesual.com)** ·
[Join our Luanti server](#play-with-luanti) ·
[Discord](https://discord.gg/M4auM7yunk) · [Changelog](CHANGELOG.md)

> **Playable and actively developed.** Expect rough edges and changing
> balance. Feedback from your adventures helps shape the next update.

## What you can play today

- **Make your character your own.** Join The Accord as a Human, Dwarf or
  Elf, or The Throng as an Orc, Troll or Undead. Play a Warrior, Mage,
  Priest or Scout, shape your abilities through two talent trees per class
  and earn cloaks through achievements.
- **Follow a story across the world.** Start with the people of your home
  town, travel to your capital and follow quests through forests, mountains
  and contested borderlands. Each faction has its own main story, leading
  toward a finale for a small party. Your map and quest log help you find
  the next step.
- **Face greater dangers together.** Form a party to challenge bosses,
  raid enemy war camps or sail to distant dragon islands. Contested lands
  and enemy territory automatically flag you for faction PvP; you can also
  flag yourself elsewhere. Fighting other players requires both sides to
  be flagged.
- **Make the gear for your next adventure.** Choose two of six primary
  professions to craft weapons, armour, bags and jewellery. Improve your
  equipment with enchantments and upgrades, or hunt for better loot.
  Search recipes and start crafting jobs that keep progressing while you
  are offline. Everyone starts with Cooking; Alchemy adds potions and elixirs.
- **Build a home between journeys.** From level 20, claim a protected plot
  in your faction's homelands and decide which friends can use it. Build,
  grow crops, go fishing and prepare supplies. Your activated Claim Stone
  connects your home to the waystone network.
- **See more of the world.** Ride from level 15, take a boat across the sea
  or unlock flying mounts at level 45. Explore caves for resources and
  stronger creatures, then return to towns with wandering inhabitants,
  ambient sounds and music in each capital.

The Accord and The Throng have their own reasons to fight. But something
beneath the world is beginning to profit from both sides.

## Play with Luanti

**In your browser:** visit [kaesual.com](https://kaesual.com) to play.

**With the Luanti client:** open **Join Game**, search the public server
list for **Grudgelands**, select the server and register or log in.
The server supplies the game content; you do not need to install this
repository or any client mods to join.

To create a local world or host a server, see
[Your own world or server](#your-own-world-or-server) below.

## Getting started

1. **Create your character:** choose your faction, people, class and look.
2. **Meet your first quest giver:** a yellow `!` means a new quest;
   a yellow `?` means one is ready to hand in. Right-click to talk.
3. **Choose a combat skill:** your starter weapon is already equipped.
   Open **Talents & Skills** in your inventory, drag a skill onto the
   hotbar, select it and left-click a creature.
4. **Find your way:** press `Z` for **Map & Quests** and select a quest
   to see its targets. Press `E` for the quickbar: mounts, boats, your
   potion belt and Return home.
5. **Set a home at an innkeeper:** Return home brings you back after a
   journey. Death costs no items, money or XP; you respawn at your bound
   innkeeper.

Press `I` for your inventory. Its **Help** tab explains equipment, crafting,
professions, travel and combat, and includes the sound controls.
Around level 10, your starting quests lead you toward your people's capital
and its profession trainers.

## Current state

**0.45.1** improves riding cameras, combat input, crafting controls and
quest interactions. Recent updates rebuilt crafting around searchable
recipes and timed jobs, brought bags into one inventory, and added a
combined map and quest window plus the quickbar for mounts and potions.

Read the [changelog](CHANGELOG.md) for changes and upgrade requirements,
and the [project status](docs/STATUS.md) for delivery and playtest progress.

**What I want to improve next:** the foundations are playable, but classes
and talents still feel like a first draft, and leveling needs more meaningful
choices. I'm working toward stronger class identities and better group and
PvP balance, richer sound and scenery, more varied and useful crafting, and
quests that teach the game more naturally. These are the next priorities;
the [roadmap](ROADMAP.md#next-priorities--deepening-the-playable-game) has the
direction and planned follow-up work.

## Feedback and contributions

Try a class, follow a few quests or explore with a friend. Tell us what
made you want to keep playing and where you got stuck.
Join the **[Grudgelands Discord](https://discord.gg/M4auM7yunk)** for
questions, stories, ideas and feedback.

For a bug, open a [GitHub issue](https://github.com/Kaesual/grudgelands/issues)
with what you were doing, the version shown in **Help → About** and whether
you used the browser or a native Luanti client. For a local checkout,
include the commit too.

Code, artwork, sound and design feedback are welcome. For a larger change,
start with a discussion and check the [design documents](docs/design/README.md)
and [backlog](BACKLOG.md).

## The person and tools behind it

I'm Jan, the designer behind Grudgelands. I use AI extensively for development
and some artwork, and guide the game through hands-on design, playtesting
and review. Making sandbox freedom and RPG progression work together takes
many small decisions and experiments. Player feedback helps me decide what
to improve next.

## Your own world or server

Grudgelands is a standalone game with its dependencies bundled. For local
play and hosting, it is tested with Luanti **5.17.0**; older versions are
untested.

<details>
<summary>Create a world, configure a server or update an existing world</summary>

For a local world, place this repository in your Luanti `games/` directory
as `grudgelands`, then select it when creating a **new world**. The game
uses mapgen **v7** and brings its own map settings.

> **Keep the map generator settings at their defaults.** The game's world
> generator accepts only its own values and stops the world from loading
> with an error otherwise. The New World dialog hides the map generator
> checkboxes for this game, but it still writes the flags saved in your
> Luanti settings: if you ever changed `mg_flags` or `mgv7_spflags`
> (Caves, Dungeons, Decorations, Mountains, Rivers, Caverns, Floatlands),
> set them back to their defaults first. They are in Luanti's settings
> with *Show advanced settings* ticked, on the pages *Mapgen* ("Mapgen
> flags") and *Mapgen V7* ("Mapgen V7 specific flags"); the reset button
> beside a changed setting restores its default. Do not set `chunksize`,
> `water_level`, `mapgen_limit`, `mgv7_dungeon_ymin`, `mgv7_dungeon_ymax`
> or `num_emerge_threads` in your own `minetest.conf` either; none of them
> is in the dialog.

**The first start of a new world takes a while.** The game prepares the six
starting areas before anyone can enter: about a minute and a half from the
server's start on a desktop PC (measured headless, 2026-10-05). A window
shows the progress and the time left; you may disconnect and come back
later. Later starts of the same world are much faster.

**Hosting a server.** The game's settings are in Luanti's settings menu
under *Content: Games → Grudgelands*. The ones that matter most: the world map
quality (normal or high), *Prepare full world before entry* (off by
default; on, the first start prepares the whole world and takes several
hours), the damage multiplier for creatures and NPCs (1.5 by default), the
particle amount of the combat effects (1.0 by default, the same for every
player) and tree regrowth. Damage is always on and creative mode is off. Details:
[world preparation](docs/design/world_preparation.md).

**Updating a hosted world.** Each [changelog](CHANGELOG.md) entry says
whether an existing world plays on, needs a map reset, a migration or a
new server. A migration runs offline with the tool that comes with the
game, from the root of the new version's repository checkout (Python 3.13
or newer; a PostgreSQL world also needs psycopg 3, Debian's
`python3-psycopg`):

1. Stop the server. The tool cannot tell whether a server is running.
2. Back up the world: its directory and, for PostgreSQL, its databases.
3. `python3 tools/migrate.py --world <world directory> --check` shows the
   world's version and the due steps and changes nothing.
4. `python3 tools/migrate.py --world <world directory>` runs the due steps.
5. Start the server with the new version.

Exit code `0`: migrated, or nothing to do. `2`: refused before anything was
written, so the world is unchanged; the last line on standard output says
why. `1`: it failed while writing: restore the backup. A server refuses to
start a world that still needs the tool, and names the command. Details:
[the migration tool](tools/README.md#the-migration-tool) and the
[upgrade contract](docs/technical/upgrade-contract.md#5-migrations).

</details>

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
them. Contributors start with the [project conventions](AGENTS.md) and the
[reference-project guide](docs/reference_projects.md).

</details>

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
| Items and crafting | [Items](docs/design/items_crafting.md): materials and recipes; [item tiers](docs/design/item_tiers.md): enchant values, upgrades, the crown, potions and drop prices; [professions](docs/design/professions.md): trades, station recipes and production; [enchanting](docs/design/items_crafting.md#6b-enchantments): enchantments and their inputs; [equipment](docs/design/inventory_equipment.md): slots, bags and crafting stations; [durability](docs/design/durability_repair.md): wear and repair; [economy](docs/design/economy.md): money, prices and services. |
| Wildlife and everyday life | [Biomes and mobs](docs/design/biomes_mobs.md): habitats and creatures; [spawn regions](docs/design/spawn_regions.md): where each zone's creatures live and at which level; [farming](docs/design/farming.md): crops; [housing](docs/design/housing.md): Claim Stone homes. |
| Travel and playing together | [Mounts](docs/design/mounts.md): riding; [boats](docs/design/boats.md): water travel and the way to the dragon islands; [home travel](docs/design/home_travel.md): innkeepers and return; [parties](docs/design/parties.md): playing in a party; [atlas](docs/design/world_map.md): maps, minimap and markers. |
| Sound | [Sound](docs/design/sound.md): effects, creature voices, ambience, music and the sound settings. |
| Hosting | [World preparation](docs/design/world_preparation.md): generating starting areas or the full world. |

</details>

## License

Grudgelands' own code is **GPL-3.0-or-later** ([LICENSE.txt](LICENSE.txt)).
The combined game is **GPL-3.0-only** because it includes GPL-3.0-only code
from cottages; see the [license overview](docs/research/licensing.md).

Media retain their individual licenses, documented per mod: CC0, CC BY,
CC BY-SA or GPL, as applicable. The
[Grudgelands crest](menu/LICENSE-media.md) is CC0.
