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

### 1.2 Textures — CC BY-SA 4.0

Base pack "Pixel Perfection" by [XSSheep](https://www.planetminecraft.com/member/xssheep/);
the files marked *(MysticTempest)* were modified by MysticTempest inside
VoxeLibre (per `LICENSE-media.md` of `mobs_mc`). Our own changes are in the
last column and are published under the same CC BY-SA 4.0.

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
| `grug_mobs_panther.b3d` | `= models/Snowleopard.b3d` | none (also serves the Jungle Lynx) |
| `grug_mobs_serpent.b3d` | `= models/Kobra.b3d` | none |
| `grug_mobs_crocodile.b3d` | `= models/Crocodile.b3d` | none |
| `grug_mobs_jungle_ape.b3d` | `= models/Monkey.b3d` | none |
| `grug_mobs_hyena.png` | `= textures/texturehyena.png` | none |
| `grug_mobs_zebra.png` | `= textures/texturezebra.png` | none |
| `grug_mobs_eagle.png` | `= textures/texturestellerseagle.png` | none |
| `grug_mobs_vulture.png` | `= textures/texturestellerseagle.png` | Throng mirror of the Crag Eagle, dark carrion-brown: `R, modulate 70,80,100, #6B5B4A` |
| `grug_mobs_crocodile.png` | `= textures/texturecrocodile.png` | none |
| `grug_mobs_serpent.png` | `= textures/texturekobra.png` | none |
| `grug_mobs_jungle_ape.png` | `= textures/texturemonkey.png` | none |
| `grug_mobs_panther.png` | `= textures/texturesnowleopard.png` | snow leopard → black panther: `R, modulate 60,30,100, #3C3C48` |
| `grug_mobs_jungle_lynx.png` | `= textures/texturesnowleopard.png` | Raptor replacement (§8 fallback, see note 7), tawny-green jungle camo: `R, modulate 90,80,100, #8A8A50` |

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
| `grug_mobs_stag.png` | `= textures/reindeer/animalia_reindeer.png` | none |
| `grug_mobs_stag_gaunt.png` | `= textures/reindeer/animalia_reindeer.png` | "Gaunt Stag", bleached pale: `magick animalia_reindeer.png -modulate 100,20,100 -channel RGB +level 45%,100% \( +clone -alpha off -fill '#CFCBB8' -colorize 100 \) -compose Multiply -composite animalia_reindeer.png -compose CopyOpacity -composite grug_mobs_stag_gaunt.png` (recipe `R` plus a black-point lift, otherwise the dark hide stays dark) |
| `grug_mobs_gull.png` | `= textures/birds/animalia_bluebird.png` | song bird → white/grey gull: `R, modulate 130,8,100, #E6E9EE` |
| `grug_mobs_crow.png` | `= textures/birds/animalia_bluebird.png` | song bird → black Carrion Crow: `R, modulate 45,10,100, #2A2A30` |

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
| `grug_mobs_spider.png` | `= textures/mobs_spider_dark.png` | AspireMint, edited by SkyBuilder1717 | CC BY-SA 3.0 | none (forest/cave Giant Spider) |
| `grug_mobs_spider_pale.png` | `= textures/mobs_spider_grey.png` | AspireMint | CC BY-SA 3.0 | none (bone-forest "bone-pale" variant — the upstream grey skin already is the pale one; grayscale PNG, Luanti loads it fine) |
| `grug_mobs_spider_jungle.png` | `= textures/mobs_spider_grey.png` | AspireMint | CC BY-SA 3.0 | jungle-green variant: `R, modulate 90,100,100, #5C7A3A`, with `-colorspace sRGB` inserted directly after the source (the upstream PNG is grayscale) |
| `grug_mobs_stone_golem.png` | `= textures/mobs_stone_monster.png` | wwar | CC0 1.0 | none |
| `grug_mobs_mesa_golem.png` | `= textures/mobs_stone_monster.png` | wwar | CC0 1.0 | Throng "Mesa Golem", red mesa rock: `R, modulate 100,130,100, #C4643C` |

---

## 6. Grudgelands original work

| File | Author | License | How it was made |
|------|--------|---------|-----------------|
| `grug_mobs_mirefolk.png` | Grudgelands project | CC0 1.0 | Original 64×32 `character.b3d` skin, **not** derived from any existing skin: colour-blocked fish-folk (murky green scales with a deterministic speckle pattern, pale belly plate, gill slits, teal dorsal crest painted into the hat layer, webbed hands/feet). Generated by the Python/PIL script printed in `docs/research/assets/wp6_model_notes.md` §Mirefolk (seed 20260806) — the seed makes the speckle pattern deterministic, so
re-running the script reproduces the same pixels. |
| `grug_mobs_blank.png` | Luanti engine | LGPL 2.1+ | 1×1 fully transparent PNG, taken from the engine; used for empty texture slots (skeleton armour/wield slots, sheared-fur slot). |

### 6.1 Item icons + projectile sprites (WP6/T5, T6) — CC0 1.0, Grudgelands project

All 24 files below are **original 16×16 pixel art of this project**, not
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
`grug_mobs:rock_entity` (stone/mesa golem).

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
