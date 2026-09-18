# Creative plan: mobs and spawns — three worlds (Round 7 deliverable R7-MOB)

Author: the Round 7 orchestrator (Claude Fable), 2026-09-18, on the user's
request. Evidence: [mob-candidates-evidence.md](mob-candidates-evidence.md)
(every candidate's mesh, animation and licence facts, per file) and
[round7-inventory-extract.md](round7-inventory-extract.md) (today's roster,
zones, palettes, clock). This plan **proposes**; the user decides per family
(§11). Round 8 lane R8-MOB1 implements the approved packages in the order of
§9. Nothing here changes the decided stat model, verbs-per-family rule,
view-range rule, drop-table symmetry or critter/prey/enemy classes of
`biomes_mobs.md` §0/§3; it fills zones that Playtest 9 found thin and adds
the day/night clock the user asked for.

Inputs: R7.6 (three level bands per zone), R7.7 (surface, underground and
Nether keep their own families; underground leans flying and ranged;
underground fliers skip the near-ground rule), the spawn-variance audit
(`spawn-variance-audit.md`), the media audit
(`reference-media-candidates.md`), `world.md` §4b (apex bosses) and
`items_crafting.md` §5.4 (six kings).

## 1. Principles

1. **Three worlds, three progressions.** Surface levels come from the zone
   bands; underground from the depth term (`max(surface, depth)` stays);
   the Nether is reserved and gets nothing built in Round 8.
2. **Each world reserves species.** A family lives in one world unless a
   row says otherwise. Shared today: Zombie, Giant Spider, Stone/Mesa Golem
   (surface + caves); they stay shared, everything new is single-world.
3. **Every zone has a day cast and a night cast.** Target per surface zone:
   three to four day families (one or two of them 24 h animals or prey),
   two to three night families, one rare where the catalog has one. Night
   is the dangerous half of the day, not a reskin.
4. **One verb per family, one asset per family, one licence line per
   file.** New families reuse a shipped mesh where a retint tells the story
   (marked *retint*), otherwise they take one animated mesh from a pinned
   reference project with a per-file licence row in `LICENSE-media.md`.
5. **Bands, not cliffs.** Inside a start zone, band 1 (levels 1–3) carries
   only the gentlest families; band 2 adds the zone's hunter; band 3 adds
   the night predator. The 100/150 m start band stays on top.

## 2. The day/night spawn clock

What exists (evidence doc §6): mobs_redo already filters spawns by the
clock when a row carries `day_toggle` (`mods/ENTITIES/mobs/api.lua:4364-4379`,
daylight = 4500..19500 of the 24000-unit day, i.e. `timeofday` 0.1875 to
0.8125), and Grudgelands' convention is day rows `min_light = 10`, night
rows `max_light = 5` plus `day_toggle = false`, 24 h rows neither
(`biomes_mobs.md` §4). `grug_mobs.is_night` uses the same 0.1875 / 0.8125
thresholds (`grug_mobs/init.lua:381-386`). So the clock is not missing;
what is missing is a **family-level role** (today each spawn row repeats
the gate by hand, and a zone with no night family simply has an empty
night), the fallback rule, and a test that reads the casts per zone. The
plan adds, in `grug_mobs/spawn_policy.lua`:

- `clock = "day" | "night" | "any"` on `grug_mobs.register_spawn_role`,
  which stamps the row convention (`min_light` / `max_light` +
  `day_toggle`) onto every spawn row of that family, so a family's clock
  is declared once and cannot drift between rows. Thresholds stay the
  engine's 0.1875 / 0.8125, shared with `is_night`.
- **Above ground the clock is the authority, the light test the filter**
  (no night spawns inside a torch-lit village square). Below y = −40 (the
  existing `UNDERGROUND_MOBS` list) rows carry no `day_toggle`: caves are
  light-driven, as Cave Bat and Cave Crawler already are.
- **Nothing despawns at dawn or dusk.** A day mob met at night is a
  leftover, a night mob met at noon is a straggler; the ordinary unload
  distances (`biomes_mobs.md` §3) handle population. No burning.
- **Night respawn is denser**: night roles run at 1.25 × their day `aoc`
  budget so a night walk meets something every 12–15 m instead of 15–20
  (decision §11.1).
- **Fallbacks** (R7.7): a zone whose night cast resolves to fewer than
  two families receives the palette family's fallback automatically —
  Zombie for settled and war palettes, Skeleton Archer for forest and
  mountain, Jungle Spider for jungle, Bog Ooze for swamp — so no zone has
  an empty night before its own night family is imported.
- KAT: for every zone, the day and night casts resolved by the policy at
  the band midpoints, with a stubbed clock on both sides of 0.8125;
  mutation: flip one family's clock, show the KAT fails.

## 3. Surface casts by zone column

Notation: **existing** family in plain text; **NEW** family in bold with its
source in §8; *retint* = shipped mesh, new tint/skin; (P) passive prey;
(C) critter; (24 h) all day; (E) elite; ranged = `dogshoot`. Bands are the
thirds of the zone along the axis (R7.6); a family listed for band 2 also
spawns in band 3.

### 3.1 Dwarf column — pine hills / crags (Accord, x ≈ −1800)

| Zone (levels) | Day | Night | Rare / 24 h |
|---|---|---|---|
| Hearthpine Vale (1–10) | b1: Boar, Rabbit (C); b2: **Ibex** (P, *animalworld*), **Fox** (*animalia*); b3: Crag Eagle | b1: **Giant Rat** (*animalia*, universal start night); b2: Zombie; b3: Wolf (24 h) | — |
| Copperfell Foothills (11–20) | Boar, Ibex (P), Fox, Crag Eagle; Bandit camp (24 h) | Wolf (24 h), Giant Spider, **Goblin Raiders** (*goblins*, roaming group with **Goblin Slinger** ranged) | — |
| Frostbarrow Shelf (21–30) | Mountain Ram (P), Crag Eagle, Stone Golem (E, 24 h), **Ibex** | **Snow Leopard** (*animalworld*, stalker), Goblin Raiders, Giant Spider | — |
| Stormvault Heights (31–40) | Crag Eagle, Stone Golem (E, 24 h), Ibex (P); Bandit camp | Snow Leopard, **Frost Stray** (*retint* Skeleton Archer, ranged), Goblin Raiders | Korgan's Bane |
| The Wyrmglass Crown (60) | Stone Golem (E), Crag Eagle, Carrion Crow (P) | Frost Stray, Snow Leopard, **Rift Spawn** (*mobs_mc* stalker, bursts) | **Ice Dragon** (§7) |

### 3.2 Human column — meadows / deep forest / swamp (x ≈ 0)

| Zone (levels) | Day | Night | Rare / 24 h |
|---|---|---|---|
| Dawnmere Fields (1–10) | b1: Boar, Rabbit (C), **Wild Turkey** (C, *animalia*); b2: Stag (P), Fox; b3: Wolf (24 h) | b1: Giant Rat; b2: Zombie; b3: Giant Spider | — |
| Goldmead Vale (11–20) | Boar, Stag (P), Fox, Wild Turkey (C); Bandit camp | Wolf (24 h), Giant Spider, **Poacher** (*retint* Bandit Archer, roaming, ranged) | Grimtusk |
| Whitebridge Shire (21–30) | Bear, Stag (P), Wolf (24 h); Mirefolk camp (24 h) | Giant Spider, **Wisp** (*mobs_mc* vex, swamp flier), Poacher | — |
| Ashenward March (31–40) | Bear, Wolf (24 h), Bandit + Bandit Archer camp | Skeleton Archer, **Ashen Treant** (*mobs_monster* tree monster, burned wood), Wisp | Old Whitefang |
| The Broken Causeway (31–40) | Carrion Crow (P), Crocodile (24 h), **War Construct** (E, 24 h, *mobs_mc* iron golem) | Skeleton Raider, **Bog Witch** (*mobs_mc* witch, ranged), Wisp | Captain Bonerattle |

### 3.3 Elf column — elf forest / deep forest (x ≈ +1800)

| Zone (levels) | Day | Night | Rare / 24 h |
|---|---|---|---|
| Silverleaf Glades (1–10) | b1: Boar, Rabbit (C), **Song Bird** (C, *retint* gull mesh); b2: Stag (P), Fox; b3: Wolf (24 h) | b1: Giant Rat; b2: Giant Spider; b3: Poacher | — |
| Starbough Vale (11–20) | Boar, Stag (P), Fox; Bandit camp | Wolf (24 h), Giant Spider, Poacher | — |
| Lethariel's neighbours Lorindor / Moonfall Wood (21–30) | Stag (P; Lorindor keeps its exact-mob rule), Bear, Wolf (24 h); Mirefolk camp (Lorindor) | Giant Spider, Wisp, Poacher | — |
| Glassroot Wilds (31–40) | Bear, Jungle Lynx, Serpent; Bandit camp | Panther, Jungle Spider, Wisp | — |
| The Skyglass Canopy (51–59) | Jungle Ape, Serpent, Crag Eagle | Panther, Silkfang's kin (Jungle Spider), Rift Spawn | Silkfang |

### 3.4 Undead column — blight / bone forest / swamp (Throng, x ≈ −1800)

| Zone (levels) | Day | Night | Rare / 24 h |
|---|---|---|---|
| Stillgrave Hollow (1–10) | b1: Plague Boar, Hare (C), Bone Weevil (C); b2: Gaunt Stag (P); b3: Blightfang Wolf (24 h) | Zombie (24 h in blight — identity, kept); b2: Giant Rat; b3: Skeleton Archer | — |
| Mournfen (11–20) | Plague Boar, Gaunt Stag (P), Bog Fowl (C), Crocodile (24 h); Bandit camp, Mirefolk camp | Zombie (24 h), Skeleton Archer, Wisp | — |
| Ossuary Reach (21–30) | Plaguehide Bear, Gaunt Stag (P), Blightfang Wolf (24 h) | Skeleton Archer, Pale Spider, **Gravewood Treant** (*mobs_monster* tree monster, bone tint) | — |
| Blackwind Rise (31–40) | Plaguehide Bear, Blightfang Wolf (24 h); Bandit camp | Skeleton Archer, Gravewood Treant, Pale Spider | Marrowclaw |
| Gravesalt Escarpment (51–59) | Plaguehide Bear, Carrion Crow (P), Crocodile (24 h) | Skeleton Raider, Bog Witch, Rift Spawn | — |

### 3.5 Orc column — savanna / badlands (x ≈ 0)

| Zone (levels) | Day | Night | Rare / 24 h |
|---|---|---|---|
| Sunscar Flats (1–10) | b1: Boar, Hare (C), **Plains Runner** (C, *animalworld* nandu); b2: Zebra (P); b3: Hyena (24 h) | b1: Giant Rat; b2: **Scorpion** (*animalworld*, poison); b3: **Sun-Dried Husk** (*retint* Zombie) | — |
| Redtusk Savanna (11–20) | Boar, Zebra (P), Hyena (24 h); Bandit camp | Scorpion, Sun-Dried Husk, Hyena (24 h) | Ashmaw |
| Speargrass Reach (21–30) | Hyena (24 h), Vulture, Zebra (P), **Speargrass Tiger** (*animalworld*, day stalker) | Scorpion, Mesa Golem (E, 24 h), Goblin Raiders | — |
| Bannerbreak Mesa (31–40) | Vulture, Mesa Golem (E), Bandit + Bandit Archer camp | Scorpion, Skeleton Raider, Goblin Raiders | Dustwing |
| The Shattered Line (41–50) | Vulture, Speargrass Tiger, War Construct (E, 24 h) | Skeleton Raider, Scorpion, Sun-Dried Husk | Captain Bonerattle |

### 3.6 Troll column — jungle edge / deep jungle / swamp (x ≈ +1800)

| Zone (levels) | Day | Night | Rare / 24 h |
|---|---|---|---|
| Kapok Cradle (1–10) | b1: Jungle Boar, Parrot (C); b2: **Tapir** (P, *animalworld*); b3: Jungle Lynx | b1: Giant Rat; b2: **Viper** (*animalworld*, poison); b3: Jungle Spider | — |
| Raincall Basin (11–20) | Jungle Lynx, Tapir (P), Serpent; Bandit camp | Viper, Jungle Spider, Panther | — |
| Whispering Reedlands / Totemwater Reach (21–30) | Crocodile (24 h), Serpent, Jungle Ape, Tapir (P); Mirefolk camp | Panther, Jungle Spider, Wisp | — |
| Thunderroot Wilds (31–40) | Jungle Ape, Jungle Lynx, Serpent; Bandit camp | Panther, Jungle Spider, Bog Witch | — |
| Stormscale Summit (60) | Jungle Ape, Serpent, Vulture | Panther, Rift Spawn, Bog Witch | Emerald Coil; **Jungle Wyvern** (§7) |

Coast and beaches (all zones with `grug_beach`, both islands, Gravesalt):
**Shore Crab** (P, neutral, *animalworld* crab — the deferred §8.3 family
finally has a candidate source) at 1–5 neutral beaches and its elite
**Reef Lurker** (×1.6) on 45–60 beaches, Gull (C) everywhere. The Kraken
Guard is unchanged.

## 4. Underground casts by depth band

Depth levels: `min(60, max(1, round(−3y/50)))`, so every 50-node stratum is
three integer steps (R7.6's "three sub-bands" is what the existing term
already does; R7-LVL verifies and documents it). Families are gated by y
range as today (`UNDERGROUND_MOBS`), the clock is ignored, light drives
spawning. Underground fliers get no near-ground bias (R7.7).

| Depth (levels) | Cast | Tendency |
|---|---|---|
| 0 to −100 (1–6) | Cave Bat (C), Cave Crawler (C), Giant Rat, **Spiderling** (*retint* Giant Spider ×0.5) | the entrance caves: quiet, food-bearing |
| −100 to −300 (6–18) | Giant Spider, Zombie (*retint* "Lost Miner"), **Blood Bat** (hostile *retint* of the Cave Bat, swarm flier), **Goblin Miners** (*goblins*, with Slinger) | first fliers and first ranged |
| −300 to −500 (18–30) | Stone Golem (E), **Oerkki** (*mobs_monster*, blink-melee), **Glowwing** (*animalworld* dragonfly, hostile flier), **Crystal Shard** (*mobs_monster* mese monster, ranged shooter) | ranged + flying majority |
| −500 to −700 (30–42) | **Dungeon Master** (*mobs_monster*, ranged fireball — the classic), Crystal Shard, Oerkki, Stone Golem (E) | ranged-heavy |
| −700 to −1000 (42–60, contested T5) | **Lava Flan** (*mobs_monster*), **Ember Wisp** (*retint* of the Wisp, fire flier), Dungeon Master, **Stone Mite** swarm (*retint* Cave Crawler, hostile) | fire, fliers, swarms |
| below −1000 (60, T6) | Lava Flan, Ember Wisp, **Land Guard** (E, *mobs_monster*), Rift Spawn (shared with the 51–60 surface) | the depth-arrival pulse of `biomes_mobs.md` §4.1 stays |

Cave Cap and Ember Moss (cooking plan §3.2) give these bands a reason to be
visited beyond ore.

## 5. Nether reserve (built later, never spawned in Round 8)

Reserved so no surface or underground package takes them: **Ghast**,
**Magma Cube**, **Wither Skeleton**, **Piglin**, **Hoglin / Zoglin**,
**Strider**, **Blaze** (all VoxeLibre `mobs_mc`), **Wither** (boss) and the
draconis **Fire Dragon** as the Nether dragon lord (`world.md` §4b Phase 3).
Lava Flan and the Ember Wisp stay underground (deep T5/T6), so the
Nether's fire cast is distinct from the mine's.

## 6. Day/night per family (reference)

| Clock | Families |
|---|---|
| day | Boar and tints, Rabbit/Hare, Fox, Ibex, Stag/Gaunt Stag, Zebra, Tapir, Mountain Ram, Crag Eagle/Vulture, Bear/Plaguehide Bear, Jungle Ape, Jungle Lynx, Serpent, Speargrass Tiger, critters (Turkey, Song Bird, Plains Runner, Bone Weevil, Bog Fowl, Parrot, Gull) |
| night | Giant Rat, Zombie outside blight, Giant/Pale/Jungle Spider, Skeleton Archer, Frost Stray, Poacher, Goblin Raiders, Snow Leopard, Panther, Scorpion, Sun-Dried Husk, Viper, Wisp, Bog Witch, Ashen/Gravewood Treant, Skeleton Raider, Rift Spawn |
| any | Wolf/Blightfang Wolf (24 h, `biomes_mobs.md` §3.1, unchanged), Hyena (24 h at every level, unchanged), Zombie in blight, Crocodile, Bog Ooze, Mirefolk, Bandit camps, Stone/Mesa Golem, War Construct, Carrion Crow, Shore Crab/Reef Lurker, Kraken, all rares, all underground, kings, dragons |

A family may need more than one clock: Zombie is `night` in settled and war
palettes and `any` in blight. The role field therefore accepts either one
value or a table keyed by palette family (`clock = {settled = "night",
war = "night", blight = "any"}`); the policy stamps the matching row. Wolf
and Hyena stay 24 h everywhere; §3 marks them `(24 h)` wherever they
appear, and a 24 h family listed in one column of a zone is part of that
zone's cast around the clock.

## 7. Boss tier

**Two overworld dragons** (`world.md` §4b, one chassis, two variants):
the draconis **Ice Dragon** on The Wyrmglass Crown (snowy crags island) and
the draconis **Jungle Wyvern** on Stormscale Summit (jungle island). Only
their meshes, textures and sounds are harvested (MIT code; media D-UNCLEAR in
the evidence doc, decision §11.7); behaviour is ours on
mobs_redo: stationary arena with three perches, telegraphed **breath line**
(`dogshoot` with a projectile entity, 2 s wind-up) and **ground slam** AoE,
level 60 boss tier (×20 HP), 30-min wall-clock respawn with the 60 s
warning, personal loot ledger per §4b. The Fire Dragon is reserved (§5).

**Six kings** (`items_crafting.md` §5.4, `world.md` §3): one per capital,
level 65 elite, four level-60 elite royal guards, on the authored `king`
socket. Asset: `character.b3d` with a crowned royal variant of each race
skin (2D work, the Bandit/Mirefolk pattern) at ×1.15 scale; guards reuse
`guard.lua` with a royal tabard skin. Kits, one per race so each fight
reads differently, all built from existing verbs plus the elite telegraph:

| King | Weapon / kit | Signature (telegraphed) |
|---|---|---|
| Dwarf (Dur Brannoc) | hammer, melee | Ground Shatter (slam AoE, knock-back) |
| Human (Highcourt) | sword and shield | Rally (guards return to formation and heal 20 %) |
| Elf (Lethariel) | bow, **ranged** | Volley (three-arrow spread) |
| Undead (Nhal Veyr) | lich staff, **ranged caster** | Bone Call (raises two Skeleton Raiders) |
| Orc (Gor Drazhak) | great axe | Cleave (frontal cone ×3) |
| Troll (Kezamba) | totem, caster | Regrowth (self-heal channel, interruptible) |

Fallen Crown per §5.4; the ledger and lockout code is shared with the
dragons.

## 8. Candidate families with sources (evidence rows in `mob-candidates-evidence.md`)

| Family (Grudgelands name) | Source project → mob | World / zones | Verb | Asset work | Licence (project level; per file in the evidence doc) |
|---|---|---|---|---|---|
| Fox | animalia `fox` | surface starts + 11–20 | darts (hit, retreat 6 m, 4 s) | port to mobs_redo, frame remap | A-UNCLEAR in the evidence doc: repo-wide MIT grant without a media table; the shipped ledger already accepted this reading for Stag and Gull (`grug_mobs/LICENSE-media.md` §4) — decision §11.7 |
| Ibex | animalworld `ibex` | Dwarf column | grazes (P) | mobs_redo-native | AW-MEDIA-MIT: models, textures, animation MIT (`animalworld/LICENSE:24-27`); sounds UNCLEAR (`:33-41`) → import without upstream sounds |
| Wild Turkey | animalia `turkey` | Human starts | flees (C) | port | A-UNCLEAR in the evidence doc: repo-wide MIT grant without a media table; the shipped ledger already accepted this reading for Stag and Gull (`grug_mobs/LICENSE-media.md` §4) — decision §11.7 |
| Song Bird | shipped gull mesh (animalia song bird) | Elf starts | flees (C) | retint | already licensed |
| Giant Rat | animalia `rat` (or animalworld `rat`) | all six starts b1–2; caves 0 to −300 | swarms (group rush) | port, ×1.6 | A-UNCLEAR in the evidence doc: repo-wide MIT grant without a media table; the shipped ledger already accepted this reading for Stag and Gull (`grug_mobs/LICENSE-media.md` §4) — decision §11.7; animalworld `rat` is the AW-MEDIA-MIT alternative |
| Goblin Raiders + Slinger | goblins `goblins_goblin.b3d`, `goblins_goblin_dog.b3d` | Dwarf/Orc mountains at night; caves −100 to −300 | raids (group, leashless roam) + dogshoot | port; stone projectile from Golem | MIT code (`goblins/LICENSE`); both meshes and the named textures CC BY-SA 3.0 per file (`goblins/README.md:55-74`); sounds name authors but map no file to an author, and `goblins_blood.png` is unattributed → import meshes and named textures only, own blood particle, sounds later |
| Snow Leopard | animalworld `snowleopard` | crags/snowy crags night | stalks (panther verb) | mobs_redo-native | AW-MEDIA-MIT: models, textures, animation MIT (`animalworld/LICENSE:24-27`); sounds UNCLEAR (`:33-41`) → import without upstream sounds |
| Frost Stray | shipped Skeleton Archer | snowy crags night | dogshoot | retint | already licensed |
| Poacher | shipped Bandit Archer | Human/Elf forests night, roaming | dogshoot, no camp | skin variant | already licensed |
| Wisp | mobs_mc `vex` | swamps, elf forest night, flier | flickers (short blink toward target, melee) | mcl_mobs → mobs_redo port | VL-MODEL: model GPLv3 (22i), textures CC BY-SA 4.0 / MIT, sounds per file (`mobs_mc/LICENSE-media.md`) — the classes the shipped Zombie, Skeleton and Wolf already use |
| Ashen / Gravewood Treant | mobs_monster `tree_monster` | Ashenward; bone forest night | roots (slow aura 30 %, radius 3) | drop-in, two tints | MM-PER-FILE: mesh and both textures WTFPL (Pavel_S/PilzAdam, `mobs_monster/license.txt:52-66`), sound WTFPL (`:88-96`); `default_wood.png` is minetest_game CC BY-SA 3.0 (evidence doc) |
| War Construct | mobs_mc `iron_golem` | Broken Causeway, Shattered Line, 24 h elite | slams (telegraphed) | port | VL-MODEL: model GPLv3 (22i), textures CC BY-SA 4.0 / MIT, sounds per file (`mobs_mc/LICENSE-media.md`) — the classes the shipped Zombie, Skeleton and Wolf already use |
| Bog Witch | mobs_mc `witch` | swamps 21+, front, night | hexes (dogshoot bottle: poison or 30 % slow 4 s) | port + bottle projectile | VL-MODEL: model GPLv3 (22i), textures CC BY-SA 4.0 / MIT, sounds per file (`mobs_mc/LICENSE-media.md`) — the classes the shipped Zombie, Skeleton and Wolf already use; `shoot` animation and a potion projectile exist upstream |
| Rift Spawn | mobs_mc `stalker` (VoxeLibre's creeper: `fuse` animation, `explode` attack) | 51–60 zones night; below −1000 | hisses (2 s telegraph) and bursts (AoE, no terrain damage) | port; mobs_redo `explode` with terrain damage off | VL-MODEL: model GPLv3 (22i), textures CC BY-SA 4.0 / MIT, sounds per file — the classes the shipped Zombie, Skeleton and Wolf already use |
| Plains Runner | animalworld `nandu` | Orc starts | flees (C) | mobs_redo-native | AW-MEDIA-MIT: models, textures, animation MIT (`animalworld/LICENSE:24-27`); sounds UNCLEAR (`:33-41`) → import without upstream sounds |
| Scorpion | animalworld `scorpion` | savanna/badlands night | poisons (serpent verb) | mobs_redo-native | AW-MEDIA-MIT: models, textures, animation MIT (`animalworld/LICENSE:24-27`); sounds UNCLEAR (`:33-41`) → import without upstream sounds |
| Sun-Dried Husk | shipped Zombie | savanna/badlands night | never leashes | retint | already licensed |
| Speargrass Tiger | animalworld `tiger` | savanna 21–50 day | stalks | mobs_redo-native | AW-MEDIA-MIT: models, textures, animation MIT (`animalworld/LICENSE:24-27`); sounds UNCLEAR (`:33-41`) → import without upstream sounds |
| Tapir | animalworld `tapir` | jungle edge (P) | grazes | mobs_redo-native | AW-MEDIA-MIT: models, textures, animation MIT (`animalworld/LICENSE:24-27`); sounds UNCLEAR (`:33-41`) → import without upstream sounds |
| Viper | animalworld `viper` | jungle edge night | poisons | mobs_redo-native | AW-MEDIA-MIT: models, textures, animation MIT (`animalworld/LICENSE:24-27`); sounds UNCLEAR (`:33-41`) → import without upstream sounds |
| Shore Crab / Reef Lurker | animalworld `crab` | beaches (P neutral) / 45–60 elite | retaliates | mobs_redo-native | AW-MEDIA-MIT: models, textures, animation MIT (`animalworld/LICENSE:24-27`); sounds UNCLEAR (`:33-41`) → import without upstream sounds |
| Spiderling | shipped Giant Spider | caves 0 to −100 | webs (weak) | ×0.5 scale | already licensed |
| Blood Bat | shipped Cave Bat | caves −100 to −300, flier | swarms (dive) | hostile variant, tint | already licensed |
| Oerkki | mobs_monster `oerkki` | −300 to −700 | blinks (short) | drop-in | MM-PER-FILE: mesh + `mobs_oerkki.png` WTFPL, `mobs_oerkki4.png` CC BY-SA 4.0, sound WTFPL; `mobs_oerkki2.png`/`3.png` UNCLEAR → use the two cleared textures only |
| Glowwing | animalworld `dragonfly` | −300 to −500 flier | dives | mobs_redo-native, glow tint | AW-MEDIA-MIT: models, textures, animation MIT (`animalworld/LICENSE:24-27`); sounds UNCLEAR (`:33-41`) → import without upstream sounds |
| Crystal Shard | mobs_monster `mese_monster` | −300 to −700 | dogshoot (shard) | drop-in, retint | MM-PER-FILE: mesh + `mobs_mese_monster_purple.png` CC0 (SirrobZeroone), sound WTFPL; `zmobs_mese_monster.png` UNCLEAR → purple texture only, own shard projectile texture |
| Dungeon Master | mobs_monster `dungeon_master` | −500 to −1000 | dogshoot (fireball) | drop-in with three of its four textures | MM-PER-FILE: mesh + `mobs_dungeon_master.png` WTFPL, `_2.png` CC0, `_4.png` CC BY-SA 4.0, fireball sound WTFPL; `mobs_dungeon_master3.png` is UNCLEAR and excluded |
| Lava Flan | mobs_monster `lava_flan` | −700 and below | engulfs (ooze verb, fire) | drop-in | MM-PER-FILE: mesh + three textures CC BY-SA 3.0 (AspireMint), sound WTFPL; `fire_basic_flame.png` and `tnt_smoke.png` are minetest_game media, cleared per the evidence doc |
| Ember Wisp | retint of the Wisp (mobs_mc `vex`) | −700 and below, flier | dogshoot (ember) | tint + projectile; replaces mobs_monster's Fire Spirit, which has no mesh and UNCLEAR textures (evidence doc) | as Wisp |
| Stone Mite | shipped Cave Crawler | −700 and below | swarms | hostile variant | already licensed |
| Land Guard | mobs_monster `land_guard` | below −1000, elite | slams | drop-in | MM-PER-FILE: reuses the Dungeon Master mesh (WTFPL) with three CC0 textures (wwar), sound WTFPL |
| Ice Dragon, Jungle Wyvern | draconis `ice_dragon`, `jungle_wyvern` | the two islands | boss kit (§7) | mesh/texture/sound harvest, own behaviour | D-UNCLEAR in the evidence doc: repo-wide MIT grant; `docs/reference_projects.md:95` records draconis as MIT code and media — decision §11.7. Animation tables are rich (ice dragon: stand_fire, slam, hover_fire, fly_fire, sleep, death; wyvern: bite, dive, fly_punch) |
| Six kings + royal guards | `character.b3d` + skins | capitals | §7 kits | 2D skins (user or lane), guard reuse | LGPL 2.1 mesh; skins ours |

Not proposed, and why: pillager/vindicator/evoker (Minecraft illager
silhouette, bandits cover the role), llama/horse/cow/pig (farm animals wait
for WP32 farming and housing), shark and other marine families (no water
world in Round 8), animalia `frog` (only a `swim` animation), mobs_monster
`fire_spirit` (no mesh, UNCLEAR textures), mobs_mc `rover` (VoxeLibre's
teleporting enderman replacement — a possible later "Rift Walker"), and the
wildlife / forgotten_monsters rows (their sources were rejected by the media
audit, whose recommendations were never recorded as user decisions —
evidence doc, last section).

## 9. Packages and rolling order for R8-MOB1

Each package is one lane-sized unit: registrations, spawn rows, clock
roles, LICENSE-media rows, one headless boot, KAT rows for the policy.

1. **Clock and fallbacks** (no new assets): the predicate, the `clock`
   field on every existing family per §6, the fallback table, the night
   `aoc` factor, the KAT. Ships first so every later package is one row.
2. **Zero-asset variants**: Giant Rat needs a mesh, so it is package 3;
   this one is Poacher, Frost Stray, Sun-Dried Husk, Song Bird, Spiderling,
   Blood Bat, Stone Mite (retints and scales of shipped meshes).
3. **Start-zone day and night** (six starts feel different): Fox, Ibex,
   Wild Turkey, Plains Runner, Tapir, Giant Rat, Scorpion,
   Viper.
4. **Night families 11–40**: Goblin Raiders + Slinger, Snow Leopard, Wisp,
   Treant (two tints), Bog Witch.
5. **Dragons** (both islands) and **kings** (six capitals) — the boss tier
   the user asked for after Round 7; kings need the six royal skins.
6. **Underground wave**: Goblin Miners (shares package 4's port), Oerkki,
   Glowwing, Crystal Shard, Dungeon Master.
7. **Deep wave**: Lava Flan, Ember Wisp, Land Guard, Rift Spawn.
8. **Front and coast**: War Construct, Speargrass Tiger, Shore Crab / Reef
   Lurker.

Rolling: packages 1–3 are the Round 8 minimum; 4 and 5 are the goal; 6–8
continue as long as the round runs.

## 10. Proposed changes to decided rules

| Decided rule | Where | Change | Why |
|---|---|---|---|
| Night rows carry `max_light = 5` + `day_toggle = false` by hand, per row | `biomes_mobs.md` §4 | one family-level `clock` role stamps the convention; fallbacks per palette; night `aoc` factor (§2) | a zone with no night family has an empty night today; per-row gates drift |
| Shore Crab "deferred until a licensed model is sourced" | §3.1, §8.3 | animalworld `crab` as the source (pending per-file check) | the source now exists in a pinned project |
| Zombie is the settled night family everywhere | §3.1 | Zombie stays as fallback; starts get Giant Rat at band 1 | a start zone's first night should be survivable at level 1–3 |
| Hyena is 24 h from L10; Wolf is 24 h | §3.1 | unchanged (both `any` in §6) | listed because §3 shows them in both casts |
| About three to four day families per zone (`TODO-round7.md` R7-MOB) | §1 of this plan | five to six across a start zone's three bands, three to four per band | the bands are the unit a player experiences; decision §11.8 |
| Zombie: night; 24 h in blight | §3.1 | unchanged; expressed as a per-palette clock table (§6) | one family, two clocks |
| "One dragon per continent" retired → two islands | `world.md` §4b | unchanged; names the draconis variants per island | asset decision |

## 11. Decisions for the user

1. Night density factor 1.25 × (or 1.0).
2. Giant Rat as the universal band-1 night family (needs one mesh) or the
   zero-asset Spiderling instead.
3. Per family, yes / no / later, in the order of §8 (33 rows). The table
   in `mob-candidates-evidence.md` gives each row's per-file licence
   verdict; a row whose media is UNCLEAR is "later" until cleared.
4. Kings' royal skins: user-made or lane-made placeholder (tabard tint on
   the race skin) for Round 8.
5. Dragon variants: Ice Dragon on Wyrmglass, Jungle Wyvern on Stormscale,
   Fire Dragon reserved for the Nether.
6. Package order of §9, and how many packages Round 8 commits to (1–3
   minimum, 4–5 goal).
8. Start zones carry five to six day families over their three bands
   (three to four per band) — accept, or cut to four per zone.
7. The repo-wide MIT reading for animalia and draconis media (no per-file
   table upstream): the ledger already relies on it for Stag, Gull and
   Carrion Crow; confirm it for Fox, Turkey, Rat and both dragons, or ask
   upstream (ElCeejo) for an explicit media line first.
