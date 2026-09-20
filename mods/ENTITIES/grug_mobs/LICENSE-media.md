# Media Origin & Licenses (grug_mobs)

Every file in `models/` and `textures/` has a row below: our file name,
`= upstream file name`, the author chain, the exact license (+ version) and
the modification we made. Sources are grouped per upstream repo; each group
names the **commit** the files were taken from and the in-repo file that
carries the license statement (AGENTS.md rule: verify in the source repo,
never on ContentDB).

**No sounds are vendored** (WP6/T4 decision): the freesound-derived audio of
`animalworld` / `mobs_mc` needs per-file license verification, which is
deferred to a later work package.

**Re-verified 2026-08-08 (WP36/0b)** against the `reference_projects/`
submodules, now that they pin exactly the commits quoted below: every one of
the 21 `.b3d` files in `models/` is **byte-identical** (`cmp`) to the upstream
file its row names, so every "Modifications: none" claim in §1.1/§3/§4/§5 is
proven, not asserted; the five license statements were re-read in the source
repos. See §8 for the animation audit of the same 21 meshes.

**Three meshes added 2026-08-08 (WP36 item 4, the critter round):**
`grug_mobs_cave_bat.b3d`, `grug_mobs_cave_crawler.b3d` and
`grug_mobs_bog_fowl.b3d`, all from the same VoxeLibre commit §1 already
pins, all verified the same way — `cmp` byte-identical to their upstream
files, animation chunks and real frame ranges measured out of the binary
(§8's table, which that round brought to 24 meshes), and their two license statements
(`mods/ENTITIES/mobs_mc/LICENSE-media.md` for models and textures,
top-level `LEGAL.md`) re-read at that commit. **Zero download**: the files
were already on disk in the pinned submodule.

## Retint recipe `R`

All pre-baked tint variants below were produced with ImageMagick 7 using one
recipe — a **multiply** blend (keeps the pixel-art shading, adds no
smoothing) plus a `CopyOpacity` pass that restores the source alpha channel
byte-for-byte (a plain multiply would also multiply the alpha):

```sh
# R(SRC, OUT, MODULATE, COLOUR)   — MODULATE is optional
magick SRC.png [-modulate MODULATE] \
  \( +clone -alpha off -fill 'COLOUR' -colorize 100 \) -compose Multiply -composite \
  SRC.png -compose CopyOpacity -composite OUT.png
```

Rows say e.g. `R, modulate 85,110,100, #8FA07A`; rows without a modulate
value omit that flag. Grayscale-PNG sources need `-colorspace sRGB` right
after the source (noted where it applies), otherwise ImageMagick keeps the
result gray. Any deviation from `R` is spelled out in full.

---

## 1. VoxeLibre (`mods/ENTITIES/mobs_mc` + top-level `textures/`)

* Repo: <https://git.minetest.land/VoxeLibre/VoxeLibre>
* Commit: `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`
* License evidence: `mods/ENTITIES/mobs_mc/LICENSE-media.md` — "All models
  were done by 22i and are licensed under GPLv3"; "Mob and item textures are
  heavily based on Pixel Perfection … Original author: XSSheep … License (if
  not mentioned otherwise): CC BY-SA 4.0", with an explicit list of the
  textures modified by MysticTempest. Top-level `LEGAL.md` confirms
  GPL-3.0-or-later code / CC BY-SA media, "no non-free licenses are used".

### 1.1 Models — GPL-3.0-or-later, by [22i](https://github.com/22i)

Blender sources: <https://github.com/22i/minecraft-voxel-blender-models>

| File | Upstream | Modifications |
|------|----------|---------------|
| `grug_mobs_boar.b3d` | `= models/mobs_mc_pig.b3d` | none |
| `grug_mobs_zombie.b3d` | `= models/mobs_mc_zombie.b3d` | none |
| `grug_mobs_kraken.b3d` | `= models/mobs_mc_squid.b3d` | none |
| `grug_mobs_rabbit.b3d` | `= models/mobs_mc_rabbit.b3d` | none |
| `grug_mobs_parrot.b3d` | `= models/mobs_mc_parrot.b3d` | none |
| `grug_mobs_skeleton.b3d` | `= models/mobs_mc_skeleton.b3d` | none |
| `grug_mobs_wolf.b3d` | `= models/mobs_mc_wolf.b3d` | none |
| `grug_mobs_bear.b3d` | `= models/mobs_mc_polarbear.b3d` | none |
| `grug_mobs_bog_ooze.b3d` | `= models/mobs_mc_slime.b3d` | none |
| `grug_mobs_ram.b3d` | `= models/mobs_mc_sheepfur.b3d` | none |
| `grug_mobs_cave_bat.b3d` | `= models/mobs_mc_bat.b3d` | none |
| `grug_mobs_cave_crawler.b3d` | `= models/mobs_mc_silverfish.b3d` | none (also serves the Bone Weevil, `bone_weevil.lua`) |
| `grug_mobs_bog_fowl.b3d` | `= models/mobs_mc_chicken.b3d` | none |
| `grug_mobs_wisp.b3d` | `= models/mobs_mc_vex.b3d` | none (`cmp` byte-identical) |

### 1.2 Textures — CC BY-SA 4.0

Base pack "Pixel Perfection" by [XSSheep](https://www.planetminecraft.com/member/xssheep/);
the files marked *(MysticTempest)* were modified by MysticTempest inside
VoxeLibre, and the ones marked *(kingoscargames)* were **added** by
kingoscargames there — both lists are explicit in `LICENSE-media.md` of
`mobs_mc`, whose default for every mob texture it does not name otherwise is
"Original author: XSSheep … License (if not mentioned otherwise):
CC BY-SA 4.0". Our own changes are in the last column and are published under
the same CC BY-SA 4.0.

| File | Upstream | Author chain | Modifications |
|------|----------|--------------|---------------|
| `grug_mobs_boar.png` | `= mobs_mc_pig.png` | XSSheep | none |
| `grug_mobs_zombie.png` | `= mobs_mc_zombie.png` | XSSheep → MysticTempest | none |
| `grug_mobs_kraken.png` | `= mobs_mc_squid.png` | XSSheep → MysticTempest | squid blue → abyssal purple: `magick mobs_mc_squid.png -modulate 70,150,167 grug_mobs_kraken.png` |
| `grug_mobs_rabbit.png` | `= mobs_mc_rabbit_brown.png` | XSSheep | none |
| `grug_mobs_hare_dust.png` | `= mobs_mc_rabbit_brown.png` | XSSheep | "Dust Hare" sand tint: `magick mobs_mc_rabbit_brown.png -modulate 125,70,115 grug_mobs_hare_dust.png` |
| `grug_mobs_parrot.png` | `= mobs_mc_parrot_red_blue.png` | XSSheep → MysticTempest | none |
| `grug_mobs_skeleton.png` | `= mobs_mc_skeleton.png` | XSSheep → MysticTempest | none |
| `grug_mobs_skeleton_raider.png` | `= mobs_mc_skeleton.png` | XSSheep → MysticTempest | war-coast "Skeleton Raider", grimy bone: `R, modulate 85,100,100, #8A8574` |
| `grug_mobs_wolf.png` | `= mobs_mc_wolf.png` | XSSheep | none |
| `grug_mobs_wolf_blightfang.png` | `= mobs_mc_wolf.png` | XSSheep | "Blightfang" sickly green-grey: `R, modulate 85,110,100, #8FA07A` |
| `grug_mobs_bear.png` | `= mobs_mc_polarbear.png` | XSSheep | polar white → brown Bear: `R, #9C6B3C` |
| `grug_mobs_bear_plaguehide.png` | `= mobs_mc_polarbear.png` | XSSheep | "Plaguehide" grey-green: `R, #7F8F6B` |
| `grug_mobs_bog_ooze.png` | `= mobs_mc_slime.png` | XSSheep → MysticTempest | slime green → murky bog green: `R, modulate 80,90,100, #6E7A4A` |
| `grug_mobs_ram.png` | `= mobs_mc_sheep.png` | XSSheep | none (body/face layer, texture slot 2 of the sheepfur mesh) |
| `grug_mobs_ram_fur.png` | `= mobs_mc_sheep_fur.png` | XSSheep | Mountain-Ram fleece, white → dusty grey-brown: `R, #B9A98C` (texture slot 1) |
| `grug_mobs_cave_bat.png` | `= mobs_mc_bat.png` | XSSheep | none |
| `grug_mobs_cave_crawler.png` | `= mobs_mc_silverfish.png` | XSSheep | none |
| `grug_mobs_bone_weevil.png` | `= mobs_mc_silverfish.png` | XSSheep | Bone Weevil, bone-forest variant — bleached bone: `R, modulate 118,30,100, #EDEAE0` |
| `grug_mobs_bone_weevil_blight.png` | `= mobs_mc_silverfish.png` | XSSheep | Bone Weevil, blight variant — sickly olive: `R, modulate 110,110,100, #8FA85E` |
| `grug_mobs_bog_fowl.png` | `= mobs_mc_chicken.png` | XSSheep → *(kingoscargames)* | Bog Fowl, marsh olive-brown: `R, modulate 100,70,100, #A3B184` |
| `grug_mobs_wisp.png` | `= mobs_mc_vex.png` | XSSheep → kingoscargames (addition) | none (`cmp` byte-identical); the mesh's sword slot uses the already shipped `default_tool_steelsword.png` from `default` |

### 1.3 Derived from the vendored boar texture (CC BY-SA 4.0)

Per-biome boar tints (biomes_mobs.md §3.1). Source is our own
`grug_mobs_boar.png`, i.e. the attribution chain of the row above
(XSSheep, CC BY-SA 4.0) carries over.

| File | Upstream | Modifications |
|------|----------|---------------|
| `grug_mobs_boar_plague.png` | `= grug_mobs_boar.png` (`= mobs_mc_pig.png`) | Plague Boar, grey-violet: `R, modulate 80,25,100, #8478A0` |
| `grug_mobs_boar_jungle.png` | `= grug_mobs_boar.png` (`= mobs_mc_pig.png`) | Jungle Boar, dark red-brown: `R, modulate 75,110,100, #7A4632` |

---

## 2. Lord of the Test (LotT), `mods/lottmobs/textures`

* Repo: <https://github.com/minetest-LOTR/Lord-of-the-Test>
* Commit: `f164140154945f0b356521ae721a86e9c7a0e0cf`
* License evidence: `mods/lottmobs/license.txt`, section "Authors of media
  files": **Amaz (CC BY-SA 3.0)** — `lottmobs_dunlending_*.png`,
  `lottmobs_gondor_guard_*.png`; **fishyWET (CC BY-SA 3.0)** —
  `lottmobs_orc*.png`; closing line "Otherwise: (CC BY-SA 3.0)".

64×32 humanoid skins for `character.b3d` (the mesh itself is
`mods/BASE/player_api`, LGPL 2.1+, not duplicated here).

| File | Upstream | Author | License | Modifications |
|------|----------|--------|---------|---------------|
| `grug_mobs_bandit_1.png` | `= lottmobs_dunlending_1.png` | Amaz | CC BY-SA 3.0 | none |
| `grug_mobs_bandit_2.png` | `= lottmobs_dunlending_2.png` | Amaz | CC BY-SA 3.0 | none |
| `grug_mobs_guard_accord.png` | `= lottmobs_gondor_guard_3.png` | Amaz | CC BY-SA 3.0 | none |
| `grug_mobs_guard_throng.png` | `= lottmobs_orc_1.png` | fishyWET | CC BY-SA 3.0 | none |

---

## 3. animalworld (mt-mods / Wilhelmine)

* Repo: <https://github.com/mt-mods/animalworld>
* Commit: `ac835da96681774679ace90656812aab67e25b5c`
* License evidence: `LICENSE` — MIT (Copyright (c) 2021 Skandarella) plus the
  explicit media clause "**Textures, Models and Animation by
  Liil/Wilhelmine/Liil under (MIT) License (c) 2022**". Sounds are the only
  unclear part of that repo ("Other sounds are from freesound.org under
  Creative Commons License") — **no sounds were taken**.

All files MIT, author **Liil/Wilhelmine** (models, textures, animation).

| File | Upstream | Modifications |
|------|----------|---------------|
| `grug_mobs_hyena.b3d` | `= models/Hyena.b3d` | none |
| `grug_mobs_zebra.b3d` | `= models/Zebra2.b3d` | none |
| `grug_mobs_eagle.b3d` | `= models/Stellerseagle.b3d` | none |
| `grug_mobs_panther.b3d` | `= models/Snowleopard.b3d` | none (also serves the Jungle Lynx and Snow Leopard) |
| `grug_mobs_serpent.b3d` | `= models/Kobra.b3d` | none |
| `grug_mobs_crocodile.b3d` | `= models/Crocodile.b3d` | none |
| `grug_mobs_jungle_ape.b3d` | `= models/Monkey.b3d` | none |
| `grug_mobs_ibex.b3d` | `= models/Ibex.b3d` | none (`cmp` byte-identical) |
| `grug_mobs_plains_runner.b3d` | `= models/Nandu.b3d` | none (`cmp` byte-identical) |
| `grug_mobs_tapir.b3d` | `= models/Tapir.b3d` | none (`cmp` byte-identical) |
| `grug_mobs_giant_rat.b3d` | `= models/Rat.b3d` | none (`cmp` byte-identical) |
| `grug_mobs_scorpion.b3d` | `= models/Scorpion.b3d` | none (`cmp` byte-identical) |
| `grug_mobs_viper.b3d` | `= models/Viper.b3d` | none (`cmp` byte-identical) |
| `grug_mobs_hyena.png` | `= textures/texturehyena.png` | none |
| `grug_mobs_zebra.png` | `= textures/texturezebra.png` | none |
| `grug_mobs_eagle.png` | `= textures/texturestellerseagle.png` | none |
| `grug_mobs_vulture.png` | `= textures/texturestellerseagle.png` | Throng mirror of the Crag Eagle, dark carrion-brown: `R, modulate 70,80,100, #6B5B4A` |
| `grug_mobs_crocodile.png` | `= textures/texturecrocodile.png` | none |
| `grug_mobs_serpent.png` | `= textures/texturekobra.png` | none |
| `grug_mobs_jungle_ape.png` | `= textures/texturemonkey.png` | none |
| `grug_mobs_panther.png` | `= textures/texturesnowleopard.png` | snow leopard → black panther: `R, modulate 60,30,100, #3C3C48` |
| `grug_mobs_jungle_lynx.png` | `= textures/texturesnowleopard.png` | Raptor replacement (§8 fallback, see note 7), tawny-green jungle camo: `R, modulate 90,80,100, #8A8A50` |
| `grug_mobs_ibex.png` | `= textures/textureibex.png` | none (`cmp` byte-identical) |
| `grug_mobs_plains_runner.png` | `= textures/texturenandu.png` | none (`cmp` byte-identical) |
| `grug_mobs_tapir.png` | `= textures/texturetapir.png` | none (`cmp` byte-identical) |
| `grug_mobs_giant_rat.png` | `= textures/texturerat.png` | none (`cmp` byte-identical) |
| `grug_mobs_scorpion.png` | `= textures/texturescorpion.png` | none (`cmp` byte-identical) |
| `grug_mobs_viper.png` | `= textures/textureviper.png` | none (`cmp` byte-identical) |
| `grug_mobs_snow_leopard.png` | `= textures/texturesnowleopard.png` | none (`cmp` byte-identical) |

---

## 4. animalia (ElCeejo)

* Repo: <https://github.com/ElCeejo/animalia>
* Commit: `5895f403fd43a9464e06b3675af3495f50565a3f`
* License evidence: `LICENSE` — MIT (Copyright (c) 2022 ElCeejo), repo-wide.
  The repo carries **no** second license file and no per-file media clause,
  i.e. the single MIT license covers models and textures as well; checked for
  `licen*`/`credit*`/`copyright` files, only `LICENSE` exists.

All files MIT, author **ElCeejo**.

| File | Upstream | Modifications |
|------|----------|---------------|
| `grug_mobs_stag.b3d` | `= models/animalia_reindeer.b3d` | none |
| `grug_mobs_gull.b3d` | `= models/animalia_bird.b3d` | none (also serves the Carrion Crow) |
| `grug_mobs_fox.b3d` | `= models/animalia_fox.b3d` | none (`cmp` byte-identical) |
| `grug_mobs_wild_turkey.b3d` | `= models/animalia_turkey.b3d` | none (`cmp` byte-identical) |
| `grug_mobs_stag.png` | `= textures/reindeer/animalia_reindeer.png` | none |
| `grug_mobs_stag_gaunt.png` | `= textures/reindeer/animalia_reindeer.png` | "Gaunt Stag", bleached pale: `magick animalia_reindeer.png -modulate 100,20,100 -channel RGB +level 45%,100% \( +clone -alpha off -fill '#CFCBB8' -colorize 100 \) -compose Multiply -composite animalia_reindeer.png -compose CopyOpacity -composite grug_mobs_stag_gaunt.png` (recipe `R` plus a black-point lift, otherwise the dark hide stays dark) |
| `grug_mobs_gull.png` | `= textures/birds/animalia_bluebird.png` | song bird → white/grey gull: `R, modulate 130,8,100, #E6E9EE` |
| `grug_mobs_crow.png` | `= textures/birds/animalia_bluebird.png` | song bird → black Carrion Crow: `R, modulate 45,10,100, #2A2A30` |
| `grug_mobs_fox.png` | `= textures/fox/animalia_fox_1.png` | none (`cmp` byte-identical) |
| `grug_mobs_wild_turkey.png` | `= textures/turkey/animalia_turkey_hen.png` | none (`cmp` byte-identical) |

---

## 4.1 goblins (FreeLikeGNU)

* Repo: <https://gitlab.com/freelikegnu/goblins>
* Commit: `ce27b15f87452c9614b515b8a9b53af5d0e8e276`
* License evidence: `README.md`, "Licenses of Source Media Files" — the
  goblin mesh, gobdog mesh and both named texture patterns are copyright
  Francisco Athens and **CC BY-SA 3.0 Unported**. The humanoid mesh is based
  on MirceaKitsune's WTFPL character. The unattributed `goblins_blood.png`
  and every sound are excluded.

| File | Upstream | Author chain | License | Modifications |
|------|----------|--------------|---------|---------------|
| `grug_mobs_goblin.b3d` | `= models/goblins_goblin.b3d` | Francisco Athens, based on MirceaKitsune | CC BY-SA 3.0 / WTFPL basis | none (`cmp` byte-identical) |
| `grug_mobs_goblin_hound.b3d` | `= models/goblins_goblin_dog.b3d` | Francisco Athens | CC BY-SA 3.0 | none (`cmp` byte-identical) |
| `grug_mobs_goblin_raider.png` | `= textures/goblins_goblin_cobble1.png` | Francisco Athens | CC BY-SA 3.0 | none (`cmp` byte-identical) |
| `grug_mobs_goblin_slinger.png` | `= textures/goblins_goblin_cobble2.png` | Francisco Athens | CC BY-SA 3.0 | none (`cmp` byte-identical) |
| `grug_mobs_goblin_hound.png` | `= textures/goblins_goblin_dog.png` | Francisco Athens | CC BY-SA 3.0 | none (`cmp` byte-identical) |

The goblin mesh has no separately authored ranged clip. Goblin Slinger maps
`shoot` explicitly to the real keyed attack range 200..219; this is the same
range its melee Raider sibling uses, rather than an unanimated projectile.

---

## 4.2 draconis (ElCeejo)

* Repo: <https://github.com/ElCeejo/draconis>
* Commit: `5ad66e400ec31aa8c6ca33e8a8c2510b6fa5d6fd`
* License evidence: repository-root `LICENSE`, MIT, Copyright (c) 2022
  ElCeejo. Round 8 decision R8-MOB1 explicitly accepts this repo-wide grant
  for the dragon media, matching the reading already used for animalia.

All five files are MIT by **ElCeejo**. No upstream sound was copied.

| File | Upstream | Modifications |
|------|----------|---------------|
| `grug_mobs_ice_dragon.b3d` | `= models/draconis_ice_dragon.b3d` | none (`cmp` byte-identical) |
| `grug_mobs_jungle_wyvern.b3d` | `= models/draconis_jungle_wyvern.b3d` | none (`cmp` byte-identical) |
| `grug_mobs_dragon_shading.png` | `= textures/draconis_baked_in_shading.png` | none (`cmp` byte-identical) |
| `grug_mobs_ice_dragon.png` | `= textures/ice_dragon/draconis_ice_dragon_sapphire.png` | none (`cmp` byte-identical) |
| `grug_mobs_jungle_wyvern.png` | `= textures/jungle_wyvern/draconis_jungle_wyvern_jade.png` | none (`cmp` byte-identical) |

---

## 5. mobs_monster (TenPlus1)

* Repo: <https://codeberg.org/tenplus1/mobs_monster>
* Commit: `adc76336bf596ea49b86cb45b852848f108e1ebd`
* License evidence: `license.txt` — MIT for the code (TenPlus1) plus a
  **per-file** media list: "Textures created by wwar (CC0): …
  mobs_stone_monster.png"; "AspireMint (CC BY-SA 3.0): mobs_spider.b3d,
  mobs_spider_grey.png, … mobs_spider_dark.png [edited by SkyBuilder1717]";
  "Pavel_S and PilzAdam (WTFPL): … mobs_stone_monster.b3d [edited by
  SirrobZeroone]". WTFPL is a free, GPL-compatible license (FSF list) — not
  NC, not ND.

| File | Upstream | Author chain | License | Modifications |
|------|----------|--------------|---------|---------------|
| `grug_mobs_spider.b3d` | `= models/mobs_spider.b3d` | AspireMint | CC BY-SA 3.0 | none |
| `grug_mobs_stone_golem.b3d` | `= models/mobs_stone_monster.b3d` | Pavel_S / PilzAdam, edited by SirrobZeroone | WTFPL | none |
| `grug_mobs_treant.b3d` | `= models/mobs_tree_monster.b3d` | Pavel_S / PilzAdam | WTFPL | none (`cmp` byte-identical) |
| `grug_mobs_spider.png` | `= textures/mobs_spider_dark.png` | AspireMint, edited by SkyBuilder1717 | CC BY-SA 3.0 | none (forest/cave Giant Spider) |
| `grug_mobs_spider_pale.png` | `= textures/mobs_spider_grey.png` | AspireMint | CC BY-SA 3.0 | none (bone-forest "bone-pale" variant — the upstream grey skin already is the pale one; grayscale PNG, Luanti loads it fine) |
| `grug_mobs_spider_jungle.png` | `= textures/mobs_spider_grey.png` | AspireMint | CC BY-SA 3.0 | jungle-green variant: `R, modulate 90,100,100, #5C7A3A`, with `-colorspace sRGB` inserted directly after the source (the upstream PNG is grayscale) |
| `grug_mobs_stone_golem.png` | `= textures/mobs_stone_monster.png` | wwar | CC0 1.0 | none |
| `grug_mobs_mesa_golem.png` | `= textures/mobs_stone_monster.png` | wwar | CC0 1.0 | Throng "Mesa Golem", red mesa rock: `R, modulate 100,130,100, #C4643C` |
| `grug_mobs_treant.png` | `= textures/mobs_tree_monster.png` | Pavel_S / PilzAdam, edited by TenPlus1 | WTFPL | none (`cmp` byte-identical); Ashen/Gravewood colours are runtime multiply modifiers |

---

## 6. Grudgelands original work

### Runtime-only Round 8 variants (no new media file)

The Poacher, Frost Stray, Sun-Dried Husk, Song Bird, Spiderling, Blood Bat
and Stone Mite add no model or texture file. Their definitions use Luanti
`^[multiply` modifiers over the already listed Bandit, Skeleton, Zombie,
Gull, Giant Spider, Cave Bat and Cave Crawler files respectively; their scale
changes are object properties. The original file rows and licences above
therefore remain the complete per-file ledger for this package. The Poacher's
`character.b3d` source has no bow clip, so its `shoot` animation explicitly
uses the keyed mine/punch range 189..198 instead of firing from a static pose.

| File | Author | License | How it was made |
|------|--------|---------|-----------------|
| `grug_mobs_mirefolk.png` | Grudgelands project | CC0 1.0 | Original 64×32 `character.b3d` skin, **not** derived from any existing skin: colour-blocked fish-folk (murky green scales with a deterministic speckle pattern, pale belly plate, gill slits, teal dorsal crest painted into the hat layer, webbed hands/feet). Generated by the Python/PIL script printed in `docs/research/assets/wp6_model_notes.md` §Mirefolk (seed 20260806) — the seed makes the speckle pattern deterministic, so
re-running the script reproduces the same pixels. |
| `grug_mobs_blank.png` | Luanti engine | LGPL 2.1+ | 1×1 fully transparent PNG, taken from the engine; used for empty texture slots (skeleton armour/wield slots, sheared-fur slot). |

### Round 8 royal art — CC0 1.0

The six crowned race skins and Fallen Crown icon are deterministic original
pixel art generated by `tools/r8_mob1/gen_boss_art.py`. The skins use the
project's own CC0 race skins as their base and add a race-coloured tabard and
gold crown on the established `character.b3d` UV layout.

| File | Author | License | How it was made |
|------|--------|---------|-----------------|
| `grug_mobs_royal_dwarf.png` | Grudgelands project | CC0 1.0 | generator, dwarf base + blue tabard + crown |
| `grug_mobs_royal_human.png` | Grudgelands project | CC0 1.0 | generator, human base + blue tabard + crown |
| `grug_mobs_royal_elf.png` | Grudgelands project | CC0 1.0 | generator, elf base + green tabard + crown |
| `grug_mobs_royal_undead.png` | Grudgelands project | CC0 1.0 | generator, undead base + violet tabard + crown |
| `grug_mobs_royal_orc.png` | Grudgelands project | CC0 1.0 | generator, orc base + red tabard + crown |
| `grug_mobs_royal_troll.png` | Grudgelands project | CC0 1.0 | generator, troll base + teal tabard + crown |
| `grug_mobs_item_fallen_crown.png` | Grudgelands project | CC0 1.0 | generator, 16×16 gold crown with ruby insets |

### 6.1 Item icons, projectile sprites and node tiles (WP6/T5–T7, WP7) — CC0 1.0, Grudgelands project

All 28 files below are **original 16×16 pixel art of this project**, not
derived from any vendored or third-party asset, and are published under
**CC0 1.0**. They are produced by one deterministic generator (no randomness
— re-running reproduces every file byte-for-byte):

```sh
python3 tools/gen_mob_item_textures.py mods/ENTITIES/grug_mobs/textures
```

Each icon is authored inside that script as a 16×16 ASCII map plus a hex
palette, so the art is reviewable in the source instead of only as a binary.
The `_item_` files are the inventory images of the shared mob materials
registered in `items.lua` (`docs/design/biomes_mobs.md` §6 base-material
map); `grug_mobs_arrow.png` and `grug_mobs_rock.png` are the projectile
sprites of `grug_mobs:arrow_entity` (skeleton archer) and
`grug_mobs:rock_entity` (stone/mesa golem); `grug_mobs_camp_fire.png` is served
from this media directory for the lower-layer node `grug_nodes:camp_fire`.

| File | Author | License | How it was made |
|------|--------|---------|-----------------|
| `grug_mobs_item_light_leather.png` | Grudgelands project | CC0 1.0 | generator, art `HIDE`, tan palette |
| `grug_mobs_item_heavy_leather.png` | Grudgelands project | CC0 1.0 | generator, art `HIDE_STACK`, dark-brown palette |
| `grug_mobs_item_scaled_hide.png` | Grudgelands project | CC0 1.0 | generator, art `SCALED`, green palette |
| `grug_mobs_item_sleek_pelt.png` | Grudgelands project | CC0 1.0 | generator, art `PELT`, near-black palette |
| `grug_mobs_item_linen_scrap.png` | Grudgelands project | CC0 1.0 | generator, art `SCRAP`, linen palette |
| `grug_mobs_item_linen_cloth.png` | Grudgelands project | CC0 1.0 | generator, art `BOLT`, pale-linen palette |
| `grug_mobs_item_heavy_cloth.png` | Grudgelands project | CC0 1.0 | generator, art `BOLT`, olive-drab palette |
| `grug_mobs_item_spider_silk.png` | Grudgelands project | CC0 1.0 | generator, art `SKEIN`, white palette |
| `grug_mobs_item_venom_gland.png` | Grudgelands project | CC0 1.0 | generator, art `ORGAN`, toxic-green palette |
| `grug_mobs_item_venom_sac.png` | Grudgelands project | CC0 1.0 | generator, art `TEARDROP`, violet palette |
| `grug_mobs_item_fang.png` | Grudgelands project | CC0 1.0 | generator, art `FANG`, ivory palette |
| `grug_mobs_item_croc_tooth.png` | Grudgelands project | CC0 1.0 | generator, art `TOOTH`, yellowed-ivory palette |
| `grug_mobs_item_raptor_claw.png` | Grudgelands project | CC0 1.0 | generator, art `HOOK_CLAW`, black palette |
| `grug_mobs_item_bear_claw.png` | Grudgelands project | CC0 1.0 | generator, art `FUR_CLAW`, bone claw + brown fur |
| `grug_mobs_item_feather.png` | Grudgelands project | CC0 1.0 | generator, art `FEATHER`, white palette |
| `grug_mobs_item_sharp_feather.png` | Grudgelands project | CC0 1.0 | generator, art `FEATHER`, steel-slate palette |
| `grug_mobs_item_stone_core.png` | Grudgelands project | CC0 1.0 | generator, art `GEODE`, grey rock + amber core |
| `grug_mobs_item_slime_gel.png` | Grudgelands project | CC0 1.0 | generator, art `BLOB`, bog-green palette |
| `grug_mobs_item_shiny_scale.png` | Grudgelands project | CC0 1.0 | generator, art `SCALE`, teal palette |
| `grug_mobs_item_ape_hair.png` | Grudgelands project | CC0 1.0 | generator, art `TUFT`, dark-brown palette |
| `grug_mobs_item_bone.png` | Grudgelands project | CC0 1.0 | generator, art `BONE`, bone-white palette |
| `grug_mobs_item_arrow.png` | Grudgelands project | CC0 1.0 | generator, art `ARROW_BUNDLE` (three bound arrows) |
| `grug_mobs_arrow.png` | Grudgelands project | CC0 1.0 | generator, art `ARROW_PROJECTILE`, projectile sprite |
| `grug_mobs_rock.png` | Grudgelands project | CC0 1.0 | generator, art `ROCK_PROJECTILE`, grey-boulder projectile sprite (WP6/T6, golem "hurls rocks"); **not** derived from `default_cobble.png` or any other vendored tile |
| `grug_mobs_item_raw_fish.png` | Grudgelands project | CC0 1.0 | generator, art `FISH`, blue-grey palette (WP6/T7, Mirefolk drop `grug_mobs:raw_fish`) |
| `grug_mobs_camp_fire.png` | Grudgelands project | CC0 1.0 | generator, art `CAMP_FIRE`, ash/stone/ember palette — top-down fire pit, fully opaque (a node tile must not have holes); served game-wide for `grug_nodes:camp_fire` (WP6/T7 camp anchor), **not** derived from `default_fire*` or any other vendored tile |
| `grug_mobs_item_stolen_purse.png` | Grudgelands project | CC0 1.0 | generator, art `STOLEN_PURSE`, drawstring coin pouch in a leather-brown palette (WP7, bandit trash drop `grug_mobs:stolen_purse` — items_crafting.md §8.1) |
| `grug_mobs_item_war_trophy.png` | Grudgelands project | CC0 1.0 | generator, art `WAR_TROPHY`, torn crimson pennant on a snapped pole (WP7, faction-guard PvP drop `grug_mobs:war_trophy` — items_crafting.md §5.6) |

---

## 7. Note: paleotest was NOT used (Raptor → Jungle Lynx)

`docs/design/biomes_mobs.md` §8.2 made the Raptor conditional on a clean
media license in [paleotest](https://github.com/ElCeejo/paleotest)
(commit `7f3c5fae2b558a0c1115df88870234be8503561d`, the repo HEAD as of
2026-08-06). Checked in the clone: the repo contains **only** `LICENSE`
(verbatim GNU GPL v3 text, no "or later" wording), **no** README, **no**
credits/attribution file, and `mod.conf` names no license; a case-insensitive
search for `licen*` / `credit*` / `copyright` / `CC0` / `CC BY` over every
`.md`, `.txt`, `.conf` and `.lua` file matches nothing but that `LICENSE`.
A code-only GPL-3.0 text with no media statement does not clearly license the
`.b3d`/`.png` files, so **no paleotest media was imported**. The decided
fallback applies: the Raptor family is served by the **Jungle Lynx**
(`grug_mobs_jungle_lynx.png` on `grug_mobs_panther.b3d`, §3 above).

---

## 8. Animation audit of every vendored `.b3d` (WP36/0b, 2026-08-08)

AGENTS.md "Project structure": **imported meshes must be animated** — a mesh
without `ANIM`/`BONE`/`KEYS` chunks slides instead of moving. This section is
the evidence that the rule holds for everything the game ships, so a future
session does not have to re-derive it.

**Result: all 38 meshes in `models/` are animated** (plus `character.b3d`
from `player_api`, listed for completeness — its license lives in that mod's
own `README.txt`: model by MirceaKitsune with later fixes, CC BY-SA 3.0).
Nothing had to be replaced, so no new media was imported and no license row
below §7 changed. The `.obj` files in `mods/BASE/default/models/` (torch,
open chest) are static **node** models — the rule does not apply to them.

**How to reproduce**: B3D is a chunked binary format (`BB3D` → `NODE` →
`BONE`/`KEYS`/`ANIM`/`MESH`), so it must be parsed, not grepped. Walk the
chunk tree reading `<4-byte tag><int32 size>`; note the two traps —
`NODE` is followed by a zero-terminated name plus 10 floats (position,
scale, quaternion) before its subchunks, and `MESH` is followed by an
`int32 brush_id` before *its* subchunks. `KEYS` has a flag word
(1 = position, 2 = scale, 4 = rotation) that fixes the per-key stride.

**The frame count comes from the keys, not from `ANIM`.** The engine's B3D
reader parses the `ANIM` chunk's frame count into a local variable that is
explicitly marked *"not stored/used"* and discards it
(`reference_projects/luanti/irr/src/CB3DMeshFileLoader.cpp:615-641`);
`SkinnedMesh::getMaxFrameNumber` answers from the animation's `end_frame`
(`irr/src/SkinnedMesh.cpp:43-46`), i.e. the last keyframe. Several
`animalworld` meshes carry a *lower* `ANIM` count than they have keys
(Kobra says 249, keys run to 350) — trusting `ANIM` would have produced
false positives here.

| Mesh | Chunks | Keyed joints | Weights | Keyframes | Frame range | Def(s) using it | Def range | Verdict |
|------|--------|--------------|---------|-----------|-------------|-----------------|-----------|---------|
| `character.b3d` | ANIM+BONE+KEYS | 6 | 1008 | 1326 | 1..221 | `bandit.lua`, `guard.lua`, `mirefolk.lua`, `grug_traders/vendors.lua` | 0..198 | animated, in range |
| `grug_mobs_bear.b3d` | ANIM+BONE+KEYS | 11 | 2400 | 891 | 1..81 | `bear.lua` | 0..40 | animated, in range |
| `grug_mobs_boar.b3d` | ANIM+BONE+KEYS | 8 | 1344 | 656 | 1..82 | `boar.lua`, `boar_variants.lua` | 0..40 | animated, in range |
| `grug_mobs_bog_fowl.b3d` | ANIM+BONE+KEYS | 11 | 1760 | 638 | 1..58 | `bog_fowl.lua` | 1..20 | animated, in range |
| `grug_mobs_bog_ooze.b3d` | ANIM+BONE+KEYS | 2 | 120 | 40 | 1..20 | `bog_ooze.lua` | 1..20 | animated, in range |
| `grug_mobs_cave_bat.b3d` | ANIM+BONE+KEYS | 7 | 952 | 567 | 1..81 | `cave_bat.lua` | 1..40 | animated, in range |
| `grug_mobs_cave_crawler.b3d` | ANIM+BONE+KEYS | 7 | 1456 | 147 | 1..21 | `cave_crawler.lua`, `bone_weevil.lua` | 1..20 | animated, in range |
| `grug_mobs_crocodile.b3d` | ANIM+BONE+KEYS | 15 | 360 | 6750 | 1..500 | `crocodile.lua` | 0..350 | animated, in range |
| `grug_mobs_eagle.b3d` | ANIM+BONE+KEYS | 18 | 432 | 6300 | 1..350 | `eagle.lua` | 0..350 | animated, in range |
| `grug_mobs_fox.b3d` | ANIM+BONE+KEYS | 9 | 2376 | 540 | 1..60 | `start_zone_families.lua` | 1..59 | animated, in range |
| `grug_mobs_giant_rat.b3d` | ANIM+BONE+KEYS | 15 | 360 | 5250 | 1..350 | `start_zone_families.lua` | 1..350 | animated, in range |
| `grug_mobs_goblin.b3d` | ANIM+BONE+KEYS | 7 | 2352 | 1547 | 1..221 | `night_families.lua` (Raider, Slinger) | 1..219 | animated, in range |
| `grug_mobs_goblin_hound.b3d` | ANIM+BONE+KEYS | 22 | 8272 | 4202 | 1..191 | `night_families.lua` | 1..140 | animated, in range |
| `grug_mobs_gull.b3d` | ANIM+BONE+KEYS | 12 | 1984 | 1920 | 1..160 | `carrion_crow.lua`, `gull.lua` | 1..160 | animated, in range |
| `grug_mobs_hyena.b3d` | ANIM+BONE+KEYS | 16 | 384 | 5600 | 1..350 | `hyena.lua` | 0..350 | animated, in range |
| `grug_mobs_ibex.b3d` | ANIM+BONE+KEYS | 17 | 408 | 6800 | 1..400 | `start_zone_families.lua` | 1..400 | animated, in range |
| `grug_mobs_ice_dragon.b3d` | ANIM+BONE+KEYS | 40 | 36888 | 25600 | 1..640 | `bosses.lua` | 1..579 | animated, in range |
| `grug_mobs_jungle_ape.b3d` | ANIM+BONE+KEYS | 20 | 480 | 9402 | 1..700 | `jungle_ape.lua` | 0..450 | animated, in range |
| `grug_mobs_jungle_wyvern.b3d` | ANIM+BONE+KEYS | 40 | 36168 | 12000 | 1..300 | `bosses.lua` | 1..299 | animated, in range |
| `grug_mobs_kraken.b3d` | ANIM+BONE+KEYS | 9 | 1944 | 369 | 1..41 | `kraken.lua` | 1..41 | animated, in range **(def fixed, see below)** |
| `grug_mobs_panther.b3d` | ANIM+BONE+KEYS | 17 | 408 | 5950 | 1..350 | `jungle_lynx.lua`, `panther.lua` | 0..350 | animated, in range |
| `grug_mobs_parrot.b3d` | ANIM+BONE+KEYS | 11 | 3200 | 1661 | 1..151 | `parrot.lua` | 0..120 | animated, in range |
| `grug_mobs_plains_runner.b3d` | ANIM+BONE+KEYS | 16 | 384 | 4800 | 1..300 | `start_zone_families.lua` | 1..200 | animated, in range |
| `grug_mobs_rabbit.b3d` | ANIM+BONE+KEYS | 13 | 3456 | 546 | 1..42 | `rabbit.lua` | 0..20 | animated, in range |
| `grug_mobs_ram.b3d` | ANIM+BONE+KEYS | 7 | 2016 | 1134 | 1..162 | `ram.lua` | 0..40 | animated, in range |
| `grug_mobs_serpent.b3d` | ANIM+BONE+KEYS | 15 | 360 | 4550 | 1..350 | `serpent.lua` | 0..350 | animated, in range |
| `grug_mobs_scorpion.b3d` | ANIM+BONE+KEYS | 26 | 624 | 6600 | 1..300 | `start_zone_families.lua` | 1..300 | animated, in range |
| `grug_mobs_skeleton.b3d` | ANIM+BONE+KEYS | 8 | 5824 | 1376 | 1..172 | `skeleton_archer.lua`, `skeleton_raider.lua` | 0..90 | animated, in range |
| `grug_mobs_spider.b3d` | ANIM+BONE+KEYS | 11 | 7128 | 506 | 1..46 | `spider.lua` | 0..45 | animated, in range |
| `grug_mobs_stag.b3d` | ANIM+BONE+KEYS | 13 | 4420 | 1950 | 1..150 | `stag.lua` | 1..119 | animated, in range |
| `grug_mobs_stone_golem.b3d` | ANIM+BONE+KEYS | 6 | 1440 | 384 | 1..64 | `golem.lua` | 0..63 | animated, in range |
| `grug_mobs_tapir.b3d` | ANIM+BONE+KEYS | 13 | 312 | 5200 | 1..400 | `start_zone_families.lua` | 1..400 | animated, in range |
| `grug_mobs_treant.b3d` | ANIM+BONE+KEYS | 6 | 2376 | 378 | 1..63 | `night_families.lua` (two tints) | 1..62 | animated, in range |
| `grug_mobs_viper.b3d` | ANIM+BONE+KEYS | 14 | 336 | 5880 | 1..420 | `start_zone_families.lua` | 1..420 | animated, in range |
| `grug_mobs_wild_turkey.b3d` | ANIM+BONE+KEYS | 8 | 1904 | 1520 | 1..190 | `start_zone_families.lua` | 1..60 | animated, in range |
| `grug_mobs_wisp.b3d` | ANIM+BONE+KEYS | 14 | 7112 | 1134 | 1..81 | `night_families.lua` | 1..80 | animated, in range |
| `grug_mobs_wolf.b3d` | ANIM+BONE+KEYS | 12 | 2904 | 1104 | 1..92 | `wolf.lua` | 0..40 | animated, in range |
| `grug_mobs_zebra.b3d` | ANIM+BONE+KEYS | 11 | 264 | 2200 | 1..200 | `zebra.lua` | 0..200 | animated, in range |
| `grug_mobs_zombie.b3d` | ANIM+BONE+KEYS | 7 | 2160 | 847 | 1..121 | `zombie.lua` | 0..59 | animated, in range |

### 8.1 The one defect the cross-check found: the Kraken

A def pointing at frames the mesh does not have is the same visible bug as an
unanimated mesh, so the audit compared every `animation` table against the
mesh's real key range. One mismatch: `kraken.lua` used **1..60** on a mesh
whose nine joints each carry exactly 41 keys (`frames=1..41`) — the def was
copied from VoxeLibre's `mobs_mc/squid.lua:36-43`, which has the same
mistake. Frames 42..60 do not exist, so the client clamped to the last key
and the tentacles froze for the tail third of every loop. Fixed to **1..41**
in all four clips (stand/walk/run/punch); playback speeds unchanged, so the
swim cycle is now continuous instead of stuttering.

### 8.2 The Lord-of-the-Test rat remains excluded

`docs/reference_projects.md` records the LotT rat as the known unanimated
case. That asset remains absent. Round 8's Giant Rat instead uses
animalworld's animated `Rat.b3d` (real keyed range 1..350) and its matching
MIT texture; the byte-identical rows are in §3 and the measured animation row
is above. No compatibility alias or fallback to the unusable LotT mesh exists.

### 8.3 The critter round (WP36 item 4) measured, did not copy

The three meshes added on 2026-08-08 went through the audit *before* their
defs were written, which is the rule §8.1 exists for. Measured out of the
binaries (the parser above), not read out of `mobs_mc/*.lua`:

| Mesh | Keyed joints | Keys | Real frame range | Upstream def says | What we ship |
|------|--------------|------|------------------|-------------------|--------------|
| `grug_mobs_cave_bat.b3d` | 7 | 567 | **1..81** | flight 0..40, death 40..80 | 1..40 on stand/walk/run/fly |
| `grug_mobs_cave_crawler.b3d` | 7 | 147 | **1..21** | one loop 0..20 | 1..20 on stand/walk/run |
| `grug_mobs_bog_fowl.b3d` | 11 | 638 | **1..58** | idle 0..0, walk 0..20, flap 20..26, chick 31+ | 1..1 stand, 1..20 walk/run |

Two deliberate deviations from upstream, both harmless and both worth
stating: every clip **starts at 1, not 0** (0 is below the first real
keyframe — the engine clamps, but there is no reason to ask it to), and no
death clip is used, because mobs_redo plays none for our mobs (both of its
death hooks skip the animation, `grug_mobs/init.lua`). The chicken's chick
range 31+ is unreachable for us: breeding is not registered.

The **Carrion Crow** also gained a clip in this round without touching its
mesh: `punch` aliased onto the fly range 140..160 of `grug_mobs_gull.b3d`
(measured 1..160, §8's table), so its retaliation as passive prey reads.

---

## 9. Round 9 mob packages 6–8

No upstream sound was copied. All source paths below are inside the pinned
`reference_projects/` checkout and every imported file is byte-identical to
that source. Ember Wisp, Bog Witch and both Goblin Miner roles are runtime
retints/reuses of media already listed above and add no file.

### 9.1 mobs_monster — commit `adc76336bf596ea49b86cb45b852848f108e1ebd`

License evidence: `license.txt:23-86`, the per-file rows summarized in §5.

| File | Source path | Author | License |
|------|-------------|--------|---------|
| `grug_mobs_oerkki.b3d` | `models/mobs_oerkki.b3d` | Pavel_S / PilzAdam | WTFPL |
| `grug_mobs_oerkki.png` | `textures/mobs_oerkki.png` | Pavel_S / PilzAdam | WTFPL |
| `grug_mobs_oerkki4.png` | `textures/mobs_oerkki4.png` | SkyBuilder1717 | CC BY-SA 4.0 |
| `grug_mobs_crystal_shard.b3d` | `models/mobs_mese_monster.b3d` | SirrobZeroone | CC0 1.0 |
| `grug_mobs_crystal_shard.png` | `textures/mobs_mese_monster_purple.png` | SirrobZeroone | CC0 1.0 |
| `grug_mobs_dungeon_master.b3d` | `models/mobs_dungeon_master.b3d` | Pavel_S / PilzAdam | WTFPL |
| `grug_mobs_dungeon_master.png` | `textures/mobs_dungeon_master.png` | Pavel_S / PilzAdam | WTFPL |
| `grug_mobs_dungeon_master2.png` | `textures/mobs_dungeon_master2.png` | wwar | CC0 1.0 |
| `grug_mobs_dungeon_master4.png` | `textures/mobs_dungeon_master4.png` | SkyBuilder1717 | CC BY-SA 4.0 |
| `grug_mobs_lava_flan.b3d` | `models/zmobs_lava_flan.b3d` | AspireMint | CC BY-SA 3.0 |
| `grug_mobs_lava_flan.png` | `textures/zmobs_lava_flan.png` | AspireMint | CC BY-SA 3.0 |
| `grug_mobs_lava_flan2.png` | `textures/zmobs_lava_flan2.png` | AspireMint | CC BY-SA 3.0 |
| `grug_mobs_lava_flan3.png` | `textures/zmobs_lava_flan3.png` | AspireMint | CC BY-SA 3.0 |
| `grug_mobs_land_guard.png` | `textures/mobs_land_guard.png` | wwar | CC0 1.0 |
| `grug_mobs_land_guard2.png` | `textures/mobs_land_guard2.png` | wwar | CC0 1.0 |
| `grug_mobs_land_guard3.png` | `textures/mobs_land_guard3.png` | wwar | CC0 1.0 |

### 9.2 animalworld — commit `ac835da96681774679ace90656812aab67e25b5c`

License evidence: `LICENSE:24-27`; models, textures and animation are MIT by
Liil/Wilhelmine. The unclear sound set was excluded.

| File | Source path | Author | License |
|------|-------------|--------|---------|
| `grug_mobs_glowwing.b3d` | `models/Dragonfly.b3d` | Liil/Wilhelmine | MIT |
| `grug_mobs_glowwing.png` | `textures/texturedragonfly.png` | Liil/Wilhelmine | MIT |
| `grug_mobs_speargrass_tiger.b3d` | `models/Tiger.b3d` | Liil/Wilhelmine | MIT |
| `grug_mobs_speargrass_tiger.png` | `textures/texturetiger.png` | Liil/Wilhelmine | MIT |
| `grug_mobs_shore_crab.b3d` | `models/Crab.b3d` | Liil/Wilhelmine | MIT |
| `grug_mobs_shore_crab.png` | `textures/texturecrab.png` | Liil/Wilhelmine | MIT |

### 9.3 VoxeLibre — commit `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`

License evidence: `mods/ENTITIES/mobs_mc/LICENSE-media.md:16-79` and top-level
`LEGAL.md`: models by 22i are GPL-3.0-or-later; the mob textures use the
ledger's default Pixel Perfection/XSSheep CC BY-SA 4.0 grant.

| File | Source path | Author | License |
|------|-------------|--------|---------|
| `grug_mobs_war_construct.b3d` | `mods/ENTITIES/mobs_mc/models/mobs_mc_iron_golem.b3d` | 22i | GPL-3.0-or-later |
| `grug_mobs_war_construct.png` | `textures/mobs_mc_iron_golem.png` | XSSheep / VoxeLibre contributors | CC BY-SA 4.0 |
| `grug_mobs_rift_spawn.b3d` | `mods/ENTITIES/mobs_mc/models/vl_stalker.b3d` | 22i | GPL-3.0-or-later |
| `grug_mobs_rift_spawn.png` | `textures/vl_stalker_default.png` | XSSheep / VoxeLibre contributors | CC BY-SA 4.0 |
## 9. Round 9 crownless royal guards

Deterministic project-original derivatives generated by
`tools/r9_boss/gen_guard_skins.py` from the existing CC0 Grudgelands race
skins. All files are CC0 1.0 by the **Grudgelands project**.

| File | Source | Modifications |
|------|--------|---------------|
| `grug_mobs_royal_guard_dwarf.png` | `grug_visuals_skin_dwarf.png` | blue tabard; no crown |
| `grug_mobs_royal_guard_human.png` | `grug_visuals_skin_human.png` | blue tabard; no crown |
| `grug_mobs_royal_guard_elf.png` | `grug_visuals_skin_elf.png` | green tabard; no crown |
| `grug_mobs_royal_guard_undead.png` | `grug_visuals_skin_undead.png` | violet tabard; no crown |
| `grug_mobs_royal_guard_orc.png` | `grug_visuals_skin_orc.png` | red tabard; no crown |
| `grug_mobs_royal_guard_troll.png` | `grug_visuals_skin_troll.png` | teal tabard; no crown |

## 9. R10 inventory loot corrections

| File | Pinned source / author | License | Modification |
|---|---|---|---|
| `grug_mobs_item_zombie_flesh.png` | VoxeLibre `c2dbc520`, `mcl_mobitems_rotten_flesh.png`, XSSheep chain | CC BY-SA 4.0 | renamed, byte-identical |
| `grug_mobs_item_feather.png` | VoxeLibre `c2dbc520`, `mcl_mobitems_feather.png`, XSSheep chain | CC BY-SA 4.0 | renamed, byte-identical |
| `grug_mobs_item_slime_gel.png` | VoxeLibre `c2dbc520`, `mcl_mobitems_slimeball.png`, XSSheep chain | CC BY-SA 4.0 | renamed, byte-identical |
| `grug_mobs_item_light_leather.png` | animalia `5895f403`, `animalia_leather.png`, ElCeejo | MIT | renamed, byte-identical |
| `grug_mobs_item_heavy_leather.png` | animalworld `ac835da9`, `abearpelt.png`, Liil/Wilhelmine | MIT | renamed, byte-identical |
| `grug_mobs_item_sleek_pelt.png` | animalworld `ac835da9`, `aboarpelt.png`, Liil/Wilhelmine | MIT | renamed, byte-identical |
| `grug_mobs_item_boar_tusk.png` | persistent source `docs/research/r10-visuals/sources/boar-tusk-imagegen.png`; prompt beside it | CC0 1.0, Grudgelands project | deterministic point-filter trim/downsample/14×14-centering via `tools/r10_art/build_boar_tusk.sh` |
