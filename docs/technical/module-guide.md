# Module implementation guide

Extracted from AGENTS.md during the 2026-09-23 documentation consolidation.
Read only the relevant module section. This guide describes implementation seams
and engine pitfalls; [living design](../design/README.md) owns game rules and
[BACKLOG](../../BACKLOG.md) owns remaining work. Historical WP names identify
origins, not permission to restore superseded behavior. Source paths in code
spans are repository-relative. This is not a fresh certification of every API.

Which mod owns what: the [mod ownership map](mod-map.md). Related technical
references: [Lua/engine constraints](luanti-lua.md),
[reference projects](../reference_projects.md), [vendor patches](../../VENDOR.md),
[upstream workarounds](upstream-workarounds.md).

The guide is split by area into the files under `modules/`; read only
the area you need, its **Rules** blocks first. Every `## ` heading below the
[shared core](#shared-core-grug_core) is a stub that keeps its old anchor (links
and code comments cite them) and points to the section's file.

| Area | File | Sections |
|---|---|---|
| Combat, classes and characters | [combat-classes.md](modules/combat-classes.md) | [Factions and character creation](modules/combat-classes.md#factions-and-character-creation), [PvP](modules/combat-classes.md#pvp), [XP and levels](modules/combat-classes.md#xp-and-levels), [Skills catalogue](modules/combat-classes.md#skills-catalogue), [Combat and classes](modules/combat-classes.md#combat-and-classes) |
| Mobs | [mobs.md](modules/mobs.md) | [Mobs](modules/mobs.md#mobs), [Mob sub-types, loot and spawn regions](modules/mobs.md#mob-sub-types-loot-and-spawn-regions), [PvP garrisons and dragon arenas](modules/mobs.md#pvp-garrisons-and-dragon-arenas), [The rift](modules/mobs.md#the-rift), [Mob voices](modules/mobs.md#mob-voices), [Dawn departure](modules/mobs.md#dawn-departure), [Room for a body](modules/mobs.md#room-for-a-body), [Flier clips](modules/mobs.md#flier-clips), [Mobs in water](modules/mobs.md#mobs-in-water) |
| Items, professions and economy | [items-professions.md](modules/items-professions.md) | [Professions](modules/items-professions.md#professions), [Crop registration](modules/items-professions.md#crop-registration), [Fishing](modules/items-professions.md#fishing), [Trinkets](modules/items-professions.md#trinkets), [Enchantments](modules/items-professions.md#enchantments), [Materials and tier-rock gating](modules/items-professions.md#materials-and-tier-rock-gating), [Traders and money](modules/items-professions.md#traders-and-money), [Miner's Guild](modules/items-professions.md#miners-guild) |
| Mapgen and world preparation | [mapgen.md](modules/mapgen.md) | [Mapgen and biomes](modules/mapgen.md#mapgen-and-biomes), [Preparation](modules/mapgen.md#preparation), [R7 audit boundary](modules/mapgen.md#r7-audit-boundary) |
| Player systems | [player-systems.md](modules/player-systems.md) | [Quests](modules/player-systems.md#quests), [Parties](modules/player-systems.md#parties), [Mail](modules/player-systems.md#mail), [Housing](modules/player-systems.md#housing), [Travel](modules/player-systems.md#travel), [Mount runtime](modules/player-systems.md#mount-runtime), [Atlas](modules/player-systems.md#atlas), [World atlas rules](modules/player-systems.md#world-atlas-rules) |
| Expeditions | [expeditions.md](modules/expeditions.md) | [Expeditions](modules/expeditions.md#expeditions) |
| UI and looks | [ui-looks.md](modules/ui-looks.md) | [UI and formspecs](modules/ui-looks.md#ui-and-formspecs), [Key presses](modules/ui-looks.md#key-presses), [Text in the world](modules/ui-looks.md#text-in-the-world), [Item displays](modules/ui-looks.md#item-displays), [Player model and skins](modules/ui-looks.md#player-model-and-skins), [Looks and enchant colours](modules/ui-looks.md#looks-and-enchant-colours), [Cloaks and achievements](modules/ui-looks.md#cloaks-and-achievements), [Sound](modules/ui-looks.md#sound) |
| Platform contracts | [platform.md](modules/platform.md) | [World version and migrations](modules/platform.md#world-version-and-migrations), [Player meta read by external tools](modules/platform.md#player-meta-read-by-external-tools), [Performance log lines](modules/platform.md#performance-log-lines), [Web bridge](modules/platform.md#web-bridge), [Website accounts](modules/platform.md#website-accounts) |
| Shared core (`grug_core`) | no file of its own | [Shared core](#shared-core-grug_core) |


## Shared core (grug_core)

`grug_core` is the lowest gameplay mod: shared constants and helpers that the
feature mods call. It declares no dependency on a player mod: a player-side
answer comes through a stub that the owning mod fills (such as
`grug_core.get_player_object_faction` from `grug_factions`), and its few
run-time calls into higher mods are in the mod map's coupling trap. What it owns and
its seams are the [mod map's row](mod-map.md); each helper is described where
its topic lives:

- the damage pipeline and combat state, the placement rules, aiming rays,
  the shared per-player reads (privilege cache, player body, join slots) and
  the identity cache, statuses and environment damage, particles, the area
  helpers: [combat and classes](modules/combat-classes.md#the-damage-pipeline-and-combat-state),
  [placement](modules/combat-classes.md#placement-in-combat-and-around-bodies),
  [aim rays](modules/combat-classes.md#aim-rays-and-the-held-attack),
  [per-player reads and passes](modules/combat-classes.md#shared-per-player-reads-and-passes),
  [pools, environment damage, statuses](modules/combat-classes.md#pools-environment-damage-statuses-and-food),
  [particle effects](modules/combat-classes.md#particle-effects),
  [area helpers](modules/combat-classes.md#the-class-reworks-building-blocks);
- the message feed, HUD layout and the raw form-field cut (`text.lua`):
  [UI and formspecs](modules/ui-looks.md#ui-and-formspecs); the presentation
  toolkit (`ui.lua`): [its contract](ui-presentation.md);
- tag carriers: [per-viewer nametags](modules/mobs.md#per-viewer-nametags);
- the zone authority and the water query:
  [zone and level queries](modules/mapgen.md#zone-and-level-queries),
  [the water query](modules/mapgen.md#the-water-query); the preparation plan
  and start preload: [preparation](modules/mapgen.md#preparation);
- the world version record, start guard, migration runner and map reset:
  [world version and migrations](modules/platform.md#world-version-and-migrations)
  and the [upgrade contract](upgrade-contract.md);
- world protection and the water and lava guards: the design rules R1 and R1b
  in [world.md](../design/world.md); the settlement service windows'
  permission check (`npc_window.lua`): the mod map's row.

## Factions and character creation

Moved to [Combat, classes and characters](modules/combat-classes.md#factions-and-character-creation).

## PvP

Moved to [Combat, classes and characters](modules/combat-classes.md#pvp).

## XP and levels

Moved to [Combat, classes and characters](modules/combat-classes.md#xp-and-levels).

## Professions

Moved to [Items, professions and economy](modules/items-professions.md#professions).

## Crop registration

Moved to [Items, professions and economy](modules/items-professions.md#crop-registration).

## Skills catalogue

Moved to [Combat, classes and characters](modules/combat-classes.md#skills-catalogue).

## Mount runtime

Moved to [Player systems](modules/player-systems.md#mount-runtime).

## R7 audit boundary

Moved to [Mapgen and world preparation](modules/mapgen.md#r7-audit-boundary).

## Trinkets

Moved to [Items, professions and economy](modules/items-professions.md#trinkets).

## Combat and classes

Moved to [Combat, classes and characters](modules/combat-classes.md#combat-and-classes).

## Mobs

Moved to [Mobs](modules/mobs.md#mobs).

## Mob sub-types, loot and spawn regions

Moved to [Mobs](modules/mobs.md#mob-sub-types-loot-and-spawn-regions).

## PvP garrisons and dragon arenas

Moved to [Mobs](modules/mobs.md#pvp-garrisons-and-dragon-arenas).

## The rift

Moved to [Mobs](modules/mobs.md#the-rift).

## Mob voices

Moved to [Mobs](modules/mobs.md#mob-voices).

## Dawn departure

Moved to [Mobs](modules/mobs.md#dawn-departure).

## Room for a body

Moved to [Mobs](modules/mobs.md#room-for-a-body).

## Flier clips

Moved to [Mobs](modules/mobs.md#flier-clips).

## Mobs in water

Moved to [Mobs](modules/mobs.md#mobs-in-water).

## Enchantments

Moved to [Items, professions and economy](modules/items-professions.md#enchantments).

## Materials and tier-rock gating

Moved to [Items, professions and economy](modules/items-professions.md#materials-and-tier-rock-gating).

## Traders and money

Moved to [Items, professions and economy](modules/items-professions.md#traders-and-money).

## Quests

Moved to [Player systems](modules/player-systems.md#quests).

## Parties

Moved to [Player systems](modules/player-systems.md#parties).

## Miner's Guild

Moved to [Items, professions and economy](modules/items-professions.md#miners-guild).

## Mail

Moved to [Player systems](modules/player-systems.md#mail).

## Web bridge

Moved to [Platform contracts](modules/platform.md#web-bridge).

## Website accounts

Moved to [Platform contracts](modules/platform.md#website-accounts).

## Housing

Moved to [Player systems](modules/player-systems.md#housing).

## Travel

Moved to [Player systems](modules/player-systems.md#travel).

## Expeditions

Moved to [Expeditions](modules/expeditions.md#expeditions).

## Atlas

Moved to [Player systems](modules/player-systems.md#atlas).

## Preparation

Moved to [Mapgen and world preparation](modules/mapgen.md#preparation).

## World version and migrations

Moved to [Platform contracts](modules/platform.md#world-version-and-migrations).

## Performance log lines

Moved to [Platform contracts](modules/platform.md#performance-log-lines).

## Fishing

Moved to [Items, professions and economy](modules/items-professions.md#fishing).

## Mapgen and biomes

Moved to [Mapgen and world preparation](modules/mapgen.md#mapgen-and-biomes).

## World atlas rules

Moved to [Player systems](modules/player-systems.md#world-atlas-rules).

## Sound

Moved to [UI and looks](modules/ui-looks.md#sound).

## UI and formspecs

Moved to [UI and looks](modules/ui-looks.md#ui-and-formspecs).

## Text in the world

Moved to [UI and looks](modules/ui-looks.md#text-in-the-world).

## Player model and skins

Moved to [UI and looks](modules/ui-looks.md#player-model-and-skins).

## Looks and enchant colours

Moved to [UI and looks](modules/ui-looks.md#looks-and-enchant-colours).

## Cloaks and achievements

Moved to [UI and looks](modules/ui-looks.md#cloaks-and-achievements).

## Player meta read by external tools

Moved to [Platform contracts](modules/platform.md#player-meta-read-by-external-tools).

## Key presses

Moved to [UI and looks](modules/ui-looks.md#key-presses).

## Item displays

Moved to [UI and looks](modules/ui-looks.md#item-displays).
