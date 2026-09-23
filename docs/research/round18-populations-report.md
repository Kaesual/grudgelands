# Round 18 population and quest audit

Date: 2026-09-23. Scope: Round 18 package C. This report records the observed
pre-change behavior and the implemented spawn-policy/quest result; it does not
change the living world geometry.

## Authority and projection

Surface eligibility is the intersection of the mobs_redo host-node row,
`grug_zones.id_at`, the closed named-zone palette, the species clock, and now
`grug_zones.mob_level_at(pos) >= _grug_min_level`. The six starting settlements
remain protected by the existing 148 x 148 hostile-spawn refusal. That refusal
only rejects a spawn candidate; it does not stop an already-live mob from
walking or chasing into town.

The audited starting-zone sub-bands are levels 1-3, 4-9, and 10. These are
level-field bands inside each 1-10 named start, not new zones or geometry.

## Before and after: six starts

Entries list the ordinary local day/night identities relevant to the start
quests. A host node still has to match. `L3+`, `L4+`, and `L10` are natural
minimums at the sampled point.

| Named zone | Levels | Before | After |
| --- | ---: | --- | --- |
| Hearthpine Vale | 1-3 | day Boar; night Giant Rat and clamped L3 Zombie | day Boar; night Giant Rat, Zombie only at L3+ |
| Hearthpine Vale | 4-9 | day Boar/Fox/Ibex; night Giant Rat/Zombie | unchanged roster |
| Hearthpine Vale | 10 | day Boar/Fox/Ibex; night Giant Rat/Zombie | unchanged roster |
| Dawnmere Fields | 1-3 | day Boar/Wild Turkey; night Giant Rat and clamped L3 Zombie | day Boar/Wild Turkey; night Giant Rat, Zombie only at L3+ |
| Dawnmere Fields | 4-9 | day Boar/Fox/Wild Turkey; night Giant Rat/Zombie | unchanged roster |
| Dawnmere Fields | 10 | day Boar/Fox/Wild Turkey; night Giant Rat/Zombie | unchanged roster |
| Silverleaf Glades | 1-3 | day Boar/Song Bird; night Giant Rat and clamped L3 Zombie/Poacher where hosted | day Boar/Song Bird; night Giant Rat, Zombie only at L3+; Poacher unchanged |
| Silverleaf Glades | 4-9 | day Boar/Fox/Song Bird; night Giant Rat/Zombie/Poacher | unchanged roster |
| Silverleaf Glades | 10 | day Boar/Fox/Song Bird; night Giant Rat/Zombie/Poacher | unchanged roster |
| Stillgrave Hollow | 1-3 | Plague Boar on blight only; night Giant Rat and clamped L3 Zombie | Plague Boar across accepted local blight/bone-litter/mud hosts; Zombie only at L3+ |
| Stillgrave Hollow | 4-9 | day Plague Boar; night Giant Rat/Zombie | same identities; broader local boar host coverage |
| Stillgrave Hollow | 10 | day Plague Boar; night Giant Rat/Zombie | same identities; broader local boar host coverage |
| Sunscar Flats | 1-3 | day Boar/Plains Runner; night Giant Rat and clamped L3 Zombie/Husk, Scorpion from L4 | day Boar/Plains Runner; night Giant Rat; no Zombie/Husk before their local gates |
| Sunscar Flats | 4-9 | day Boar/Plains Runner; night Giant Rat/Zombie/Husk/Scorpion | day Boar/Plains Runner; night Giant Rat/Scorpion and Husk from L7; no duplicate Zombie look |
| Sunscar Flats | 10 | day Boar/Plains Runner; night Giant Rat/Zombie/Husk/Scorpion | day Boar/Plains Runner; night Giant Rat/Husk/Scorpion |
| Kapok Cradle | 1-3 | Jungle Boar on jungle hosts; night Giant Rat and clamped L3 Zombie; Viper from L4; Lynx could spawn clamped to L10 | Jungle Boar across accepted jungle/mud hosts; night Giant Rat, Zombie only at L3+; no Lynx |
| Kapok Cradle | 4-9 | day Jungle Boar/Tapir and clamped L10 Lynx; night Giant Rat/Zombie/Viper | day Jungle Boar/Tapir; night Giant Rat/Zombie/Viper; no Lynx |
| Kapok Cradle | 10 | day Jungle Boar/Tapir/Lynx; night Giant Rat/Zombie/Viper | unchanged roster |

The same natural-minimum rule applies at every 11-20, 21-30, and 31-60 named
zone boundary. Species with no authored minimum remain eligible; L10 Wolf,
Blightfang Wolf, Hyena, and Jungle Lynx no longer enter a lower point and get
clamped upward. Fixed bosses, guards, depth rows and encounter-owned actors do
not use this generic surface decision.

## Zone-fixed lookalike variants

Before, boar identity followed the ground node, so one named settled zone could
admit Base, Plague, or Jungle Boar on different biome patches. After, each
settled named zone chooses one identity while all three keep the same chance,
active-object cap, disposition, behavior, and drops.

| Zones | Selected identity | Accepted local host families |
| --- | --- | --- |
| Hearthpine, Copperfell, Dawnmere, Goldmead, Silverleaf, Starbough, Sunscar, Redtusk | Boar | all already accepted settled/wild patch tops |
| Stillgrave, Mournfen | Plague Boar | blight, bone litter, mud |
| Kapok, Raincall | Jungle Boar | rainforest litter, canopy litter, mud |

Only the selected name reaches the spawn budget in a zone, so expanding its
host-node coverage does not stack independent per-name caps.

## Complete shared-model surface audit

The audit compared every ambient surface registration that names the same mesh
against all closed named-zone palettes. Underground-only reuse and authored
NPCs, guards, bosses, camps, and rares are outside the ordinary wildlife
policy. A shared imported mesh alone does not make two entities regional
lookalike variants when their scale, silhouette treatment, or combat role is
the visible identity (for example Gull/Carrion Crow/Song Bird, Wisp/Ember Wisp,
Goblin Raider/Slinger, and Skeleton Archer/Bog Witch). The actual same-form
regional tints are resolved as follows:

| Shared form | Overlap found before | Selection after |
| --- | --- | --- |
| Boar / Plague Boar / Jungle Boar | Any settled zone whose biome patches exposed more than one tint host | one boar identity for each of the 12 settled start/home zones, listed above |
| Zombie / Sun-Dried Husk | Sunscar Flats, Redtusk Savanna and Shattered Line admitted both through settled/war plus the explicit Husk palette | Husk only in those three desert zones; ordinary Zombie elsewhere |
| Giant / Bonelurker / Jungle Spider | Mixed forest+jungle palettes could admit forest and jungle tints in one named zone | Jungle Spider in Glassroot Wilds, Thunderroot Wilds, Skyglass Canopy and Stormscale Summit; node-exclusive forest tint elsewhere |
| Jungle Lynx / Panther / Snow Leopard | Jungle palettes admitted Lynx and Panther; Wyrmglass explicitly admitted Snow Leopard | Panther in the four mixed/high-jungle zones above, Lynx in jungle-edge start/home zones, Snow Leopard in Wyrmglass and its other explicitly named mountain zones |
| Skeleton Archer / Skeleton Raider / Frost Stray | War palettes admitted Archer and Raider; Wyrmglass also admitted Frost Stray | Raider in ordinary war zones, Frost Stray in Wyrmglass, Archer in forest/mountain fallback zones |
| Wolf / Blightfang Wolf | no named-zone overlap after host-node intersection | unchanged: Accord forest hosts versus Throng bone-forest hosts |
| Bear / Plaguehide Bear | no named-zone overlap after host-node intersection | unchanged: Accord forest hosts versus Throng bone/blight/savanna hosts |
| Stag / Gaunt Stag | no named-zone overlap after host-node intersection | unchanged: Accord forest/meadow hosts versus Throng bone-forest hosts |
| Stone / Mesa Golem | shared stone host, already split by stable race region inside each zone | unchanged; exactly one faction-region form remains eligible |
| Ashen / Gravewood Treant | explicit zone identities never overlap | unchanged |

Goblin Raider and Slinger deliberately remain together: they are melee/ranged
members of one authored Goblin Raid family rather than interchangeable regional
skins. Bog Witch remains beside a skeleton-family selection where named: its
visible bottle projectile, green skin, drops, and poison/slow role make it a
separate creature rather than another archer tint. Bird reuse remains separate
species with different scale/behavior and no regional-tint substitution.

## Quest and drop consistency

| Culture / stage | Before | After / local source |
| --- | --- | --- |
| Troll main quest 6, level 8 | Jungle Lynx, whose natural minimum is 10 | Tapir; starts at local L4 and drops raw meat/leather |
| Troll local village quest, level 10 | Jungle Lynx under the settlement | Tapir in Kapok/Raincall jungle-edge hosts |
| Troll outpost quests, level 11 | Viper and Jungle Lynx | unchanged; Raincall is 11-20, so Lynx meets L10 naturally |
| Orc main quest 4, level 4 | Zombie or Boar, but Sunscar's regional Husk duplicated the Zombie form | Sun-Dried Husk or Boar; Husk begins at the authored local L7 gate, while Boar keeps the quest achievable earlier |
| Six opening boar quests | zone-dependent node tint could split identity | each quest target matches its zone-fixed Boar, Plague Boar, or Jungle Boar |
| Raw meat / leather bring quests | ordinary local wildlife | unchanged; selected boars, Tapir, and other local prey retain the sources |
| Slime gel / linen cloth | Bog Ooze / authored camp bandits | unchanged and locally supplied |

Counts and rewards are unchanged. No custom drop, density retune, mapgen edit,
new asset, or safe-town movement rule was introduced.
