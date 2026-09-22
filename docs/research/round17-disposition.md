# Round 17 disposition implementation

The fixed disposition is family-owned and independent of zone, faction,
current target and elite/rare promotion. `grug_mobs.disposition(subject)` is
the central lookup and accepts a registered name, luaentity or ObjectRef.
Registration writes the same `_grug_disposition` value into
the source definition and the canonical mobs_redo entity prototype, where live
entities inherit it for DISPLAY. Guards and peaceful NPCs retain their separate
role classification.

## Existing-family matrix

| Disposition | Existing families and named variants |
|---|---|
| Neutral | Boar, Plague Boar, Jungle Boar; Ibex, Tapir; Stag, Gaunt Stag, Zebra; Mountain Ram; Carrion Crow; Shore Crab, Reef Lurker |
| Aggressive | Fox; Giant Rat; Bear, Plaguehide Bear; Wolf, Blightfang Wolf; Hyena; Jungle Lynx, Panther, Snow Leopard, Speargrass Tiger; Crag Eagle, Vulture; Crocodile; Jungle Ape; Giant Spider, Jungle Spider, Pale Spider, Spiderling; Serpent, Viper, Scorpion; Blood Bat; Goblin Raider, Goblin Slinger, Goblin Hound, Goblin Miner, Goblin Miner Slinger; Bandit, Bandit Archer, Poacher; Mirefolk; Skeleton Archer, Skeleton Raider, Zombie, Frost Stray, Sun-Dried Husk; Stone Golem, Mesa Golem, Stone Mite, War Construct; Ashen Treant, Gravewood Treant; Bog Ooze, Bog Witch; Wisp, Glowwing, Ember Wisp; Crystal Shard, Lava Flan; Oerkki, Rift Spawn, Dungeon Master; Kraken; Ice Dragon, Jungle Wyvern, Ice Whelp, Storm Whelp; kings |
| Critter | Rabbit, Hare; Wild Turkey, Plains Runner; Parrot, Gull, Song Bird; Cave Bat, Cave Crawler; Bone Weevil, Bog Fowl |
| Independent role | Accord/Throng guards, land guards, royal guards and peaceful settlement NPCs |

Neutral definitions suppress unsolicited player/NPC acquisition and group
pulls while leaving mobs_redo's normal punch retaliation path active. The three ordinary Boar
definitions were the behavior delta: they previously initiated combat and now
retaliate. Giant Rats already initiate combat and remain fightable aggressive
mobs. Existing prey already used the same retaliation behavior, and existing
critters remain passive, fleeing, one-HP scenery/food creatures.

No roster or spawn-weight change was needed. Higher zones already draw mainly
from aggressive predator, hostile humanoid, undead and monster families, while
their few plausible neutral animals remain stable. Spawn density, ranges,
levels, HP, damage, drops and quest identifiers are unchanged.

## Validation

`tools/r17/disposition_test.lua` is a portable production-module fixture for
the neutral, aggressive, critter, guard and missing-classification contracts.
The full existing R7 registration fixture additionally loads the real mob
roster through `grug_mobs.register_mob`; this makes an omitted wrapped family a
startup failure and checks the canonical registration path. Root owns the final
compact PUC 5.1/LuaJIT parity run on integrated bytes.
