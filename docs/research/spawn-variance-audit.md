# Spawn variance audit — round 5 baseline

Preparatory audit for the round 6 mob imports. It records the shipped palette
only; round 5 does not add, remove or retune a mob family.

## Method and scope

The zone rows and closed palette tags come from
`mods/ENTITIES/grug_mobs/spawn_policy.lua:11-108`. Day/night roles come from
`docs/design/biomes_mobs.md` §3.1, and the existing `mobs:spawn` node lists
remain the narrower habitat selector. Consequently a family in a mixed zone is
spawnable only on its matching surface: for example, Skeleton Archer can use
bone/blight surfaces or its explicit war-row settled tops, while a mountain tag
does not make it spawn on forest soil.

This is an ambient surface-spawn audit. It excludes underground rows, the
open-sea Kraken, scheduled named rares, camp-slot Bandits/Mirefolk and placed
guards/NPCs. `24 h` families appear in both columns. “Gap” means either an empty
period or a period carried by only one narrow fallback family; it does not
authorize a round 5 palette edit. The round 6 column names only the approved
source family that should be inspected first; it does not select an asset.

Palette legend:

- `S` settled; `F` forest; `M` mountain; `V` savanna; `E` jungle edge;
  `J` jungle; `W` swamp; `R` war; `X` exact-mob override; `—` empty capital.
- Slash names are continent or habitat variants of one mechanical family.
- Gull is noted only where the catalog explicitly includes beach patches; its
  beach authority is independent of the named-zone palette.

## Zone × day/night baseline

| Zone | Tags | Day families currently spawnable | Night families currently spawnable | Gap and round 6 first source |
|---|---|---|---|---|
| Hearthpine Vale | S | Boar; Rabbit | Zombie | Night is Zombie-only; `wildlife` adds daytime variance first. |
| Copperfell Foothills | S | Boar; Rabbit | Zombie | Night is Zombie-only; `wildlife`. |
| Dur Brannoc | — | **None** | **None** | Both periods are intentionally empty today; `wildlife` is the non-civic-hostile candidate. |
| Frostbarrow Shelf | M | Crag Eagle; Stone Golem; Mountain Ram | Stone Golem | Night is Golem-only; `draconis`. |
| Stormvault Heights | M | Crag Eagle; Stone Golem; Mountain Ram | Stone Golem | Night is Golem-only; `draconis`. |
| Dawnmere Fields | S | Boar; Rabbit | Zombie | Night is Zombie-only; `wildlife`. |
| Goldmead Vale | S | Boar; Rabbit | Zombie | Night is Zombie-only; `wildlife`. |
| Highcourt | — | **None** | **None** | Both periods are intentionally empty today; `wildlife` is the non-civic-hostile candidate. |
| Whitebridge Shire | S+F | Boar; Rabbit; Wolf; Bear; Stag | Zombie; Wolf; Giant Spider | Mixed palette is healthy but repeats the forest quartet; `wildlife`. |
| Ashenward March | F+R | Wolf; Bear; Stag; Carrion Crow | Wolf; Giant Spider; Zombie; Skeleton Archer; Skeleton Raider | War day is Crow plus the ordinary forest set; `goblins`. |
| Silverleaf Glades | S | Boar; Rabbit | Zombie | Night is Zombie-only; `wildlife`. |
| Starbough Vale | S | Boar; Rabbit | Zombie | Night is Zombie-only; `wildlife`. |
| Lethariel | — | **None** | **None** | Both periods are intentionally empty today; `wildlife` is the non-civic-hostile candidate. |
| Lorindor | X: Stag | Stag | **None** | Exact palette creates the clearest night hole; `forgotten_monsters_reworked`. |
| Moonfall Wood | F | Wolf; Bear; Stag | Wolf; Giant Spider | Two repeated forest families carry night; `forgotten_monsters_reworked`. |
| Glassroot Wilds | F+J | Wolf; Bear; Stag; Jungle Lynx; Serpent; Jungle Ape | Wolf; Giant/Jungle Spider; Panther | Broad union, but the night side still collapses around spider/panther; `wildlife`. |
| Stillgrave Hollow | S | Plague Boar; Hare; Zombie on blight | Zombie | Night is Zombie-only and the same family already occupies blight by day; `forgotten_monsters_reworked`. |
| Mournfen | S+W | Plague Boar; Hare; Zombie on blight; Crocodile; Bog Ooze; Bog Fowl | Zombie; Crocodile; Bog Ooze | No empty period, but one settled fallback repeats through it; `wildlife`. |
| Nhal Veyr | — | **None** | **None** | Both periods are intentionally empty today; `goblins` is the first urban-family audit. |
| Ossuary Reach | F | Blightfang Wolf; Plaguehide Bear; Gaunt Stag; Bone Weevil | Blightfang Wolf; Pale Spider; Skeleton Archer | Forest roster is complete but narrow; `forgotten_monsters_reworked`. |
| Blackwind Rise | F | Blightfang Wolf; Plaguehide Bear; Gaunt Stag; Bone Weevil | Blightfang Wolf; Pale Spider; Skeleton Archer | Forest roster is complete but narrow; `forgotten_monsters_reworked`. |
| Sunscar Flats | S | Boar; Hare | Zombie | Night is Zombie-only; `goblins`. |
| Redtusk Savanna | S+V | Boar; Hare; Hyena; Zebra | Zombie; Hyena | Night has only the settled fallback and one 24 h hunter; `wildlife`. |
| Gor Drazhak | — | **None** | **None** | Both periods are intentionally empty today; `goblins` is the first urban-family audit. |
| Speargrass Reach | V+M | Hyena; Zebra; Vulture; Mesa Golem | Hyena; Mesa Golem | No night-only identity; `draconis`. |
| Bannerbreak Mesa | M+R | Vulture; Mesa Golem; Hyena; Carrion Crow | Mesa Golem; Hyena; Zombie; Skeleton Archer; Skeleton Raider | Day war identity is still Crow-only over the mountain set; `goblins`. |
| Kapok Cradle | S+E | Jungle Boar; Hare; Jungle Lynx; Parrot | Zombie | Jungle-edge has no night family of its own; `forgotten_monsters_reworked`. |
| Raincall Basin | S+E | Jungle Boar; Hare; Jungle Lynx; Parrot | Zombie | Jungle-edge has no night family of its own; `wildlife`. |
| Kezamba | — | **None** | **None** | Both periods are intentionally empty today; `wildlife` is the first tropical urban audit. |
| Whispering Reedlands | E+W | Jungle Lynx; Parrot; Crocodile; Bog Ooze; Bog Fowl | Crocodile; Bog Ooze | Jungle-edge contributes nothing at night; `forgotten_monsters_reworked`. |
| Totemwater Reach | E+W | Jungle Lynx; Parrot; Crocodile; Bog Ooze; Bog Fowl | Crocodile; Bog Ooze | Jungle-edge contributes nothing at night; `wildlife`. |
| Thunderroot Wilds | J | Jungle Lynx; Serpent; Jungle Ape | Panther; Jungle Spider | Complete day/night split, but only two night silhouettes; `wildlife`. |
| The Wyrmglass Crown | M+R | Crag Eagle; Stone Golem; Mountain Ram; Carrion Crow; Gull on beach | Stone Golem; Zombie; Skeleton Raider | Dragon endpoint has no dragon-family ambient member; `draconis`. |
| Gravesalt Escarpment | F+R | Blightfang Wolf; Plaguehide Bear; Gaunt Stag; Bone Weevil; Carrion Crow; Gull on beach | Blightfang Wolf; Pale Spider; Zombie; Skeleton Archer; Skeleton Raider | Broad union still reuses inland forest/war families; `forgotten_monsters_reworked`. |
| The Broken Causeway | R | Carrion Crow | Zombie; Skeleton Archer on settled tops; Skeleton Raider | Day is exactly one family; `goblins`. |
| The Shattered Line | M+R | Vulture; Mesa Golem; Hyena; Carrion Crow | Mesa Golem; Hyena; Zombie; Skeleton Archer; Skeleton Raider | Day war identity is Crow-only over the mountain set; `goblins`. |
| The Skyglass Canopy | J+R | Jungle Lynx; Serpent; Jungle Ape; Carrion Crow | Panther; Jungle Spider; Zombie; Skeleton Archer; Skeleton Raider | Broad union lacks a distinct high-jungle imported family; `forgotten_monsters_reworked`. |
| Stormscale Summit | J+R | Jungle Lynx; Serpent; Jungle Ape; Carrion Crow; Gull on beach | Panther; Jungle Spider; Zombie; Skeleton Archer; Skeleton Raider | Dragon endpoint has no dragon-family ambient member; `draconis`. |

## Round 6 hand-off

Round 6 starts from this table and re-evaluates every row after imports. It
must preserve the closed named-zone authority, the node-list intersection and
the existing start-footprint hostile refusal. Zombie and skeleton families are
the default night fallback where a new zone-specific family is unavailable;
they are not added to any palette by this audit. Spawn chances, `aoc`, levels,
drops and day/night gates remain unchanged in round 5.
