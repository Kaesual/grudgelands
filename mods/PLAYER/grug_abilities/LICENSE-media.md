# Media Origin & Licenses (grug_abilities)

- `grug_abilities_orb.png`: 16×16 radial gradient orb, generated with
  ImageMagick for this project (own work), **CC0**. Historical ability
  backdrop; Round 18 replaces active-skill inventory art with the action
  icons below.
- `grug_abilities_weapon_ready.png`: 20×20 gold readiness ring generated for
  this project with OpenAI image generation, chroma-keyed and reduced to the
  final HUD sprite (own work), **CC0**.

- `crosshair.png`, `object_crosshair.png` (byte-identical 21×21),
  `grug_abilities_draw_ring_00.png` … `_15.png` (35×35): crosshair and
  progress ring (the bow draw's full frame went with the draw in Round 53)
  drawn procedurally with Pillow by
  `tools/pt_fixes/lane_b/gen_crosshair_textures.py` (own work, 2026-09-28),
  **CC0**. Re-run the script to change them. The eating progress ring uses
  the same frames tinted at runtime (`^[multiply`, `crosshair.lua`).

- `grug_abilities_cd_pie_00.png` … `_71.png` (96×96, the cooldown overlay's
  72 cover frames, 50 % black clearing clockwise) and
  `grug_abilities_cd_digit_0.png` … `_9.png`, `grug_abilities_cd_digit_m.png`
  and `grug_abilities_cd_digit_p.png` (a "+", Round 48, for the mail icon's
  "9+" badge) (28×36, the overlay's image digits: 5×7 glyphs, white with a
  black outline): drawn procedurally by `tools/r40_cd/gen_cooldown_textures.py`
  (Python standard library; own work, Round 40, 2026-10-06), **CC0**. Re-run
  the script to change them (`--check` verifies them).

## Round 18 active-skill action icons — CC0

The 22 original `textures/grug_abilities_skill_*.png` files were generated for this
project on 2026-09-23 with OpenAI's built-in `image_gen.imagegen` tool, one
separate prompt/call per asset. No third-party image was supplied to the tool.
The project dedicates any rights it holds in these generated images to
**CC0-1.0**, to the extent such rights exist. They are not imported game art.
The final files are opaque 64×64 RGB PNGs, reduced with Pillow's Lanczos
filter from the generated originals. No recoloring or compositing was applied
to the new art. Full per-file IDs, source output paths, exact prompts and
final SHA-256 hashes: `tools/r18_art/manifest.json` at the repository root.
Design rationale and reference inspection: `docs/research/round18-art-report.md`.
Round 31 renamed four skills; their files are unchanged renamed copies
(same SHA-256), listed in the manifest under the new id with `renamed_from`:
`grug_abilities_skill_heal.png`, `_shield_spell.png`, `_mend.png` and
`_ice_nova.png`.
Round 52 replaced 19 of these files with redrawn icons (the section "Round 52
redrawn skill icons" below); the last three Round 18 icons,
`grug_abilities_skill_cinderfall.png`, `_glacial_ward.png` and
`_pinning_shot.png`, went with their retired skills in Round 53.
0.53.1 brings eight of them back (the user's picks of 2026-10-20, Round 53
icon review): each file below is a byte-identical copy of the 0.51 file at
commit `dea1d163`, and its SHA-256 is again the one the Round 18 manifest
records under the same id. The manifest's hashes hold for these eight files
only.

| Local file | Source | Pick | Bytes | SHA-256 |
|---|---|---|---:|---|
| `textures/grug_abilities_skill_strike.png` | 0.51 file at `dea1d163`; manifest id `strike` | skill:strike old | 8573 | `968807c4e730a4e07ba1d9a34271dac725def0ea24aa6765476fc223a08dc1e8` |
| `textures/grug_abilities_skill_hold_ground.png` | 0.51 file at `dea1d163`; manifest id `hold_ground` | skill:hold_ground old | 7848 | `d66bcf76ccba326fd0e8285be9d4f1c4859cb1176c0417cd1ae09895c9ee7fc6` |
| `textures/grug_abilities_skill_hamstring.png` | 0.51 file at `dea1d163`; manifest id `hamstring` | skill:hamstring old | 6445 | `95d2025c86e9aa5645899e0dfb1019b5c95413922238adfd7c329ff2d80896b2` |
| `textures/grug_abilities_skill_mend.png` | 0.51 file at `dea1d163`; manifest id `mend` | skill:mend old | 7625 | `ffb8e64c8183611707f7034a89e048f6d4d42424baf164f8bc37339a71e20c5e` |
| `textures/grug_abilities_skill_shield_spell.png` | 0.51 file at `dea1d163`; manifest id `shield_spell` | skill:shield_spell old | 8234 | `8b88365d5c085f40454edc27118cfd018bc039fdbfeaa48ea0ce1699ff035b6d` |
| `textures/grug_abilities_skill_word_of_ruin.png` | 0.51 file at `dea1d163`; manifest id `word_of_ruin` | skill:word_of_ruin old | 8932 | `4e26894c4cd55f9c6cdb21e12f32ae053ba4130c92bde1adadcefb7668d2127d` |
| `textures/grug_abilities_skill_sprint.png` | 0.51 file at `dea1d163`; manifest id `sprint` | skill:sprint old | 7217 | `10497be0c72168ccc0918d8bd3024f4de5fdc2bc17e1420c63009a218c6bcd8e` |
| `textures/grug_abilities_skill_opening.png` | 0.51 file at `dea1d163`; manifest id `opening` | skill:opening old | 9151 | `3b9ab486e2ed06981a8de9c17f71790fd45a75d6b73ab010184fc08f8c57f5f6` |

## Round 52 weapon element overlays — CC0

The 24 `textures/grug_abilities_fx_<family>_<weapon>.png` strips (the
first-person element overlay, round52-class-plan.md C7; Round 53 deleted the
six bow draw-stage strips with the draw): own work by GPT-6 Astra
for Grudgelands, Round 52 lane ARTA, **CC0-1.0**. Each is the opaque rework (ARTA
pass 4, drop 04, 2026-10-20; the user accepted all of them) of the strip the user
picked on 2026-10-19 from drop 03: the generator `tools/r52_art/arta/arta_fx4.py`
reworks the pick produced by `arta_fx3.py` with opaque pixels only (alpha 0 or
255; the wield mesh discards alpha below 0.5 and draws the rest opaque). Both
generators, the drops and their manifests are in `tools/r52_art/arta/`
(`README.md`). Each file is a byte-identical copy of
`tools/r52_art/arta/drop-04/<same name>`: RGBA, 16 px wide, the family's frame
count × 16 px high; the animation is on the skill item's definition
(`grug_abilities.WEAPON_FX_ANIMATION`).

| Local file | Source (`tools/r52_art/arta/`) | Rework of the pick (drop-03) | SHA-256 |
|---|---|---|---|
| `textures/grug_abilities_fx_bulwark_dagger.png` | `drop-04/grug_abilities_fx_bulwark_dagger.png` | opaque rework of the user's pick `fx/warrior/bulwark_dagger_v1.png` | `d2b0d0a9be545b16128f37d5b7981aecf64ea88221a703b08e97cab031e258a6` |
| `textures/grug_abilities_fx_bulwark_greataxe.png` | `drop-04/grug_abilities_fx_bulwark_greataxe.png` | opaque rework of the user's pick `fx/warrior/bulwark_greataxe_v1.png` | `45c85ebb08123bc18b3378817cc3b9bb35203b994c17c234c68299d37341f4c5` |
| `textures/grug_abilities_fx_bulwark_sword.png` | `drop-04/grug_abilities_fx_bulwark_sword.png` | opaque rework of the user's pick `fx/warrior/bulwark_sword_v2.png` | `10684401876e216e5cc0054faba1d9cad6e30cc207763483e4025e502e94b5e5` |
| `textures/grug_abilities_fx_ember_dagger.png` | `drop-04/grug_abilities_fx_ember_dagger.png` | opaque rework of the user's pick `fx/mage/ember_dagger_v1.png` | `2aeb862358dfe50cb93fe8e8d56adbba057a62c2a6b2bb6ac3850d90b2e88f43` |
| `textures/grug_abilities_fx_ember_staff.png` | `drop-04/grug_abilities_fx_ember_staff.png` | opaque rework of the user's pick `fx/mage/ember_staff_v1.png` | `20c5aba593ac462457c73b4a6b812957d2f84cc376ac2de9f952048bdef8cb69` |
| `textures/grug_abilities_fx_ember_wand.png` | `drop-04/grug_abilities_fx_ember_wand.png` | opaque rework of the user's pick `fx/mage/ember_wand_v1.png` | `04b3ac0b3a920ccb432d373554c28777bc6ac63b6daf27fd53a4d6efef33ce7c` |
| `textures/grug_abilities_fx_mercy_dagger.png` | `drop-04/grug_abilities_fx_mercy_dagger.png` | opaque rework of the user's pick `fx/priest/mercy_dagger_v1.png` | `1b788bc1a41152d17ff5ee82b747cde083804d38d7ae3015c6801abd4c0e74ce` |
| `textures/grug_abilities_fx_mercy_staff.png` | `drop-04/grug_abilities_fx_mercy_staff.png` | opaque rework of the user's pick `fx/priest/mercy_staff_v2.png` | `499ae487185231ba1a3389f59eef6e17464cd74474849152ada00059fe4be9c6` |
| `textures/grug_abilities_fx_mercy_wand.png` | `drop-04/grug_abilities_fx_mercy_wand.png` | opaque rework of the user's pick `fx/priest/mercy_wand_v1.png` | `06cef44d1e38a2a0ca0b361bb5ef5183818385aff200fd27ff3895499c693c51` |
| `textures/grug_abilities_fx_quarry_bow.png` | `drop-04/grug_abilities_fx_quarry_bow.png` | opaque rework of the user's pick `fx/scout/quarry_bow_v1.png` | `382012128cb753a682ad437a01de24dd25ccb0e78e683311a480529893dd386f` |
| `textures/grug_abilities_fx_quarry_dagger.png` | `drop-04/grug_abilities_fx_quarry_dagger.png` | opaque rework of the user's pick `fx/scout/quarry_dagger_v1.png` | `4d0f46b2db3ff534e94982bc4656ab386eb6035ebec14f0dd1ea01d0cc36c7d8` |
| `textures/grug_abilities_fx_quarry_sword.png` | `drop-04/grug_abilities_fx_quarry_sword.png` | opaque rework of the user's pick `fx/scout/quarry_sword_v1.png` | `2252106cfdd5c5641d8cfde2a1f5170b2eb5c3615156fcdc26883fb953bd55ce` |
| `textures/grug_abilities_fx_reckoning_dagger.png` | `drop-04/grug_abilities_fx_reckoning_dagger.png` | opaque rework of the user's pick `fx/priest/reckoning_dagger_v2.png` | `ea3868a8b9469e168ec3858178c4fde40a81a0b651f300284722f7894ff90c0a` |
| `textures/grug_abilities_fx_reckoning_staff.png` | `drop-04/grug_abilities_fx_reckoning_staff.png` | opaque rework of the user's pick `fx/priest/reckoning_staff_v1.png` | `f1625466a2278bacfa8a5eb411e9a034ea1666a8c5611577a30247b4b14c247c` |
| `textures/grug_abilities_fx_reckoning_wand.png` | `drop-04/grug_abilities_fx_reckoning_wand.png` | opaque rework of the user's pick `fx/priest/reckoning_wand_v2.png` | `5ab5ceb8ed42823819a33cb42e8d8808e61eda4458e0043dbe1d070062781235` |
| `textures/grug_abilities_fx_rime_dagger.png` | `drop-04/grug_abilities_fx_rime_dagger.png` | opaque rework of the user's pick `fx/mage/rime_dagger_v1.png` | `1fe7b9b312b361ce439166cd9feb2bf834d82e1597162d75e5e1ec8d4e10aa0d` |
| `textures/grug_abilities_fx_rime_staff.png` | `drop-04/grug_abilities_fx_rime_staff.png` | opaque rework of the user's pick `fx/mage/rime_staff_v1.png` | `53e0c93b9088569bc6cd785963553b1883ecef8f7f5c92537712066b74670132` |
| `textures/grug_abilities_fx_rime_wand.png` | `drop-04/grug_abilities_fx_rime_wand.png` | opaque rework of the user's pick `fx/mage/rime_wand_v1.png` | `621fc2b13c164a96d483bbd48dbaa59b4d0e535c34190f1b9ac8d9f0c2c662ce` |
| `textures/grug_abilities_fx_ruin_dagger.png` | `drop-04/grug_abilities_fx_ruin_dagger.png` | opaque rework of the user's pick `fx/warrior/ruin_dagger_v1.png` | `055fc5978f73fcea058532605e7360486f07bb1a9d7e561ed7543d7351920610` |
| `textures/grug_abilities_fx_ruin_greataxe.png` | `drop-04/grug_abilities_fx_ruin_greataxe.png` | opaque rework of the user's pick `fx/warrior/ruin_greataxe_v1.png` | `7c8788375b06212e05739ebd7a4b7f906f0c5b97311574b3b90b2d174927c11d` |
| `textures/grug_abilities_fx_ruin_sword.png` | `drop-04/grug_abilities_fx_ruin_sword.png` | opaque rework of the user's pick `fx/warrior/ruin_sword_v1.png` | `70e34967bcffba3f37c22dc0bd112304c238f73a4d8360899d06cdadb40d73fe` |
| `textures/grug_abilities_fx_veil_bow.png` | `drop-04/grug_abilities_fx_veil_bow.png` | opaque rework of the user's pick `fx/scout/veil_bow_v1.png` | `cf0fdd3a7bfd9428f378c551f8fec449de1389a792eb10060e1775da2d7ef000` |
| `textures/grug_abilities_fx_veil_dagger.png` | `drop-04/grug_abilities_fx_veil_dagger.png` | opaque rework of the user's pick `fx/scout/veil_dagger_v1.png` | `81c3325b3eee9cae87ad67c02b2d03aec9b5cb250a0364eb6c71488b0c14d925` |
| `textures/grug_abilities_fx_veil_sword.png` | `drop-04/grug_abilities_fx_veil_sword.png` | opaque rework of the user's pick `fx/scout/veil_sword_v1.png` | `181bfdd2386974931aaf49a4e67131c1bee96ba567d4d46b12303a71e872d982` |

## Round 52 redrawn skill icons — CC0

The 19 icons of the shipped skills, redrawn as one set with the new talent
icons (round52-class-plan.md C11, D7), replace the Round 18 files of the same
names: own work by GPT-6 Astra for Grudgelands, Round 52 lane ARTB, style A
"Painted embers" (drop 02, 2026-10-19/20; Loose redrawn in drop 03,
2026-10-20, picked v1). Each was one separate call (or an edit of the
project's own image) of the built-in `image_gen.imagegen` tool, no
third-party image supplied, reduced with Pillow's Lanczos filter to an opaque
64 × 64 RGB PNG without crop, recolouring or compositing. Prompts, source
paths and hashes: `tools/r52_art/artb/README.md`, `drop-02/manifest.json` and
`drop-03/manifest.json`. The project dedicates any rights it holds in these
images to **CC0-1.0**, to the extent such rights exist. Byte-identical renamed
copies of the user's picks (2026-10-20). The 25 icons of the skills round K adds follow in the
next section. 0.53.1 replaced 15 of these 19 files (eight with their Round 18
icon, see above; seven with Round 53 redraws, see "Round 53 redrawn icons"
below); the four still shipped are listed here.

| Local file | Source (`tools/r52_art/`) | Pick | Bytes | SHA-256 |
|---|---|---|---:|---|
| `textures/grug_abilities_skill_fireball.png` | `artb/drop-02/skills/skill.fireball.png` | skill.fireball | 7055 | `2ae5bfafdf836ed39786f3a9a2f00e5138ceec5e7f5fc9c0da4f3aa86f650a6f` |
| `textures/grug_abilities_skill_ice_nova.png` | `artb/drop-02/skills/skill.ice_nova.png` | skill.ice_nova | 9041 | `92176404ec4d4d53b8749caa0a4c5f00e43fa8e290aa9361fc3b49848c7900d5` |
| `textures/grug_abilities_skill_smite.png` | `artb/drop-02/skills/skill.smite.png` | skill.smite | 7323 | `6da52ab3175d0ee5f2b8754bf6e2457e84836d8239a673154cf42444f6e089a7` |
| `textures/grug_abilities_skill_snare_shot.png` | `artb/drop-02/skills/skill.snare_shot.png` | skill.snare_shot | 8255 | `0ad0b911c343bfd7131453bb4366aa2e21b723be522c49c40f5cb25c21063362` |

## Round 53 skill icons of the new skills — CC0

The 25 icons of the skills round K adds (round53-plan.md §4 HOOKS, file
facts §6), from the same Round 52 set as the redrawn icons above: own work
by GPT-6 Astra for Grudgelands, Round 52 lane ARTB, style A "Painted
embers" (drop 02, 2026-10-19/20; Bladecraft, Flourish and Parry redrawn in
drop 03, 2026-10-20, picked v3, v1 and v2). Each was one separate call (or
an edit of the project's own image) of the built-in `image_gen.imagegen`
tool, no third-party image supplied, reduced with Pillow's Lanczos filter to
an opaque 64 × 64 RGB PNG without crop, recolouring or compositing. Prompts,
source paths and hashes: `tools/r52_art/artb/README.md`,
`drop-02/manifest.json` and `drop-03/manifest.json`. The project dedicates
any rights it holds in these images to **CC0-1.0**, to the extent such
rights exist. Byte-identical renamed copies of the user's picks
(2026-10-20). 0.53.1 replaced 11 of these 25 files with Round 53 redraws
(see "Round 53 redrawn icons" below); the 14 still shipped are listed here.

| Local file | Source (`tools/r52_art/`) | Pick | Bytes | SHA-256 |
|---|---|---|---:|---|
| `textures/grug_abilities_skill_fiery_spark.png` | `artb/drop-02/skills/skill.fiery_spark.png` | skill.fiery_spark | 6527 | `c9d788e51ab2f50a26fefa7c508481a1a8d11476895658284662accf5d1d500f` |
| `textures/grug_abilities_skill_flame_lance.png` | `artb/drop-02/skills/skill.flame_lance.png` | skill.flame_lance | 7424 | `db6a8f593614ccdd96b290eb606788f92a62a0414b603dfdfedd4f2beb2e73a2` |
| `textures/grug_abilities_skill_meteor.png` | `artb/drop-02/skills/skill.meteor.png` | skill.meteor | 8156 | `9a10a03961c9849991092da608d7613c4e050876aa86aafa1ea30c484158d29d` |
| `textures/grug_abilities_skill_fire_rain.png` | `artb/drop-02/skills/skill.fire_rain.png` | skill.fire_rain | 9374 | `85547c03089ca39150f15b2155d052859ee23c4095f3fd0765d1d4dd405ffd26` |
| `textures/grug_abilities_skill_ice_wave.png` | `artb/drop-02/skills/skill.ice_wave.png` | skill.ice_wave | 8470 | `5be8a9ae1e82c149211cda09985532f549d9aae4e652fe103fccc6b0e5017a5a` |
| `textures/grug_abilities_skill_cold_spark.png` | `artb/drop-02/skills/skill.cold_spark.png` | skill.cold_spark | 8257 | `a2f782a6399d2e48fead4b4be213c822f85a27a1418621549130870f8ed36ecf` |
| `textures/grug_abilities_skill_rime_mantle.png` | `artb/drop-02/skills/skill.rime_mantle.png` | skill.rime_mantle | 9146 | `86bfaa5522d10359645175e6d9ef48ac467b150e5acd2940a428961ac997897f` |
| `textures/grug_abilities_skill_winter_field.png` | `artb/drop-02/skills/skill.winter_field.png` | skill.winter_field | 10163 | `a97191451f2cfc5323f8cd1d0117bf6343a666288e83813b974297c719c6882d` |
| `textures/grug_abilities_skill_unbroken.png` | `artb/drop-02/skills/skill.unbroken.png` | skill.unbroken | 9074 | `e54e52dfef3f9ac70e9fcb46397fcdc354fabdc5c1c60be0eb75a340fa275eb5` |
| `textures/grug_abilities_skill_hearten.png` | `artb/drop-02/skills/skill.hearten.png` | skill.hearten | 8992 | `9bbd635b4ac006aab32ceb136007f5d7e9b28bb51737c3e88edec4a70c887ef3` |
| `textures/grug_abilities_skill_haven.png` | `artb/drop-02/skills/skill.haven.png` | skill.haven | 8711 | `0ab56c71d716dd8a48e42752f4550b7a7328f480a898703125cbf4165ff2da9f` |
| `textures/grug_abilities_skill_final_word.png` | `artb/drop-02/skills/skill.final_word.png` | skill.final_word | 8277 | `6db235c3b8f3303af6700f94389d353a30fb0909bf17bcd11baea8bba2e32af1` |
| `textures/grug_abilities_skill_arrowfall.png` | `artb/drop-02/skills/skill.arrowfall.png` | skill.arrowfall | 7549 | `989391412d0ca4f5919f3f66e34178338f03696a1e43c5d684a6e380a17a4bc3` |
| `textures/grug_abilities_skill_bladecraft.png` | `artb/drop-03/skill.bladecraft_v3.png` | skill.bladecraft.v3 | 7401 | `d8a495a2ec2e48b33d5fabdb4bdddcbf8ee080a981d488d858dd1b1c679b86dc` |

## Round 53 redrawn icons (0.53.1) — CC0

18 skill icons redrawn for clarity in Round 53 (lane ICONS) and picked by the
user on 2026-10-20 (pass 1: drop-01, 108 proposals; pass 2: drop-02, 24
proposals for the eight icons pass 1 left open). Own work by GPT-6 Astra for
Grudgelands, style A "Painted embers" simplified. Each proposal was one
separate call (or a focused edit of the project's own image) of the built-in
`image_gen.imagegen` tool, no third-party image supplied, reduced with
Pillow's Lanczos filter to an opaque 64 × 64 8-bit RGB PNG without crop,
recolouring, compositing or sharpening. Exact prompts, source paintings,
supplied references, refinement history and hashes:
`tools/r53_art/icons/README.md`, `drop-01/manifest.json` and
`drop-02/manifest.json`. The project dedicates any rights it holds in these
images to **CC0-1.0**, to the extent such rights exist. Each file is a
byte-identical renamed copy of the user's pick (`tools/r531_art/ship_icons.py`
copies and checks them); the talent icons of the same pass are in
`grug_classes`.

| Local file | Source (`tools/r53_art/icons/`) | Pick | Bytes | SHA-256 |
|---|---|---|---:|---|
| `textures/grug_abilities_skill_charge.png` | `drop-02/skill__charge_v1.png` | skill:charge pass 2 v1 | 6514 | `151b59f336fd2fa8ef46043243611bf4b0e861bce9bc6de5309042b53e98f70d` |
| `textures/grug_abilities_skill_bellow.png` | `drop-02/skill__bellow_v3.png` | skill:bellow pass 2 v3 | 9208 | `00bd9b819ff19f0dfbbbac7a975e0faffb19daee5904f6d272e19542b4268c31` |
| `textures/grug_abilities_skill_retort.png` | `drop-01/skill__retort_v1.png` | skill:retort pass 1 v1 | 7151 | `16ab43c5a6143e56f69f710de1db91460d936f699e26ae484082c86736887f48` |
| `textures/grug_abilities_skill_taunt.png` | `drop-01/skill__taunt_v1.png` | skill:taunt pass 1 v1 | 8635 | `cde93edc415f4ecda6c663e8cd3650e7886d2296a05ce41a7030b91324f6481c` |
| `textures/grug_abilities_skill_broadstroke.png` | `drop-02/skill__broadstroke_v1.png` | skill:broadstroke pass 2 v1 | 5994 | `547434e5052c383d65e4a29a62a7f7b9fd2c0c5517f389f44e3415ab38c540c1` |
| `textures/grug_abilities_skill_mighty_blow.png` | `drop-01/skill__mighty_blow_v1.png` | skill:mighty_blow pass 1 v1 | 8327 | `2354539a99e2f679ea8b0fb87686a7e697d2d13e38d35447d0ba8bec5befbc07` |
| `textures/grug_abilities_skill_ruination.png` | `drop-01/skill__ruination_v1.png` | skill:ruination pass 1 v1 | 6373 | `acb896d26d5a78865933ef086e4118ed06014125f21ab2c7d3913e60b912318a` |
| `textures/grug_abilities_skill_blink.png` | `drop-02/skill__blink_v1.png` | skill:blink pass 2 v1 | 7282 | `6dde2149e70dda390b7a6eb4f7340d1851f0285a4d67c91e4f0eaf67ec066f7c` |
| `textures/grug_abilities_skill_heal.png` | `drop-01/skill__heal_v1.png` | skill:heal pass 1 v1 | 7562 | `b19f912faafc86cc94e143f2e33f0ceb4d5d39f7b6d157e4faa65bd30b78aeab` |
| `textures/grug_abilities_skill_censure.png` | `drop-01/skill__censure_v1.png` | skill:censure pass 1 v1 | 6329 | `cfc97841c7aee27db07534c7fd6b3f144383921b4e6e8b8fcbfd98788d444733` |
| `textures/grug_abilities_skill_rebuke.png` | `drop-01/skill__rebuke_v1.png` | skill:rebuke pass 1 v1 | 5763 | `871f99b24d2f6d9e9030a1e4802030b4769d95fb1527553b6349b5a2f35984b3` |
| `textures/grug_abilities_skill_loose.png` | `drop-01/skill__loose_v1.png` | skill:loose pass 1 v1 | 6452 | `7e6cae4ded82d2a6ef4f805fa926f7108b082c7d9094ca3c95efd0ba1a37f578` |
| `textures/grug_abilities_skill_sidestep.png` | `drop-01/skill__sidestep_v3.png` | skill:sidestep pass 1 v3 | 7834 | `6a0188078eb3e49e9493d6a846f7fe5f4156b1599bf75e8b296aa9b85bf0c106` |
| `textures/grug_abilities_skill_split_shot.png` | `drop-01/skill__split_shot_v1.png` | skill:split_shot pass 1 v1 | 6209 | `40983f5e12cbbd8d0afd8799ea3acea6ad639c6fd848571849ad283141c492f9` |
| `textures/grug_abilities_skill_true_draw.png` | `drop-01/skill__true_draw_v2.png` | skill:true_draw pass 1 v2 | 6428 | `3ee8705125b6b89ec65cb94cccb0b3df3651632823aee93a61d646c375776cfe` |
| `textures/grug_abilities_skill_close_dance.png` | `drop-02/skill__close_dance_v2.png` | skill:close_dance pass 2 v2 | 8950 | `400bfc30000cf07ea8a021357259b91eef9b6008a43d6c757726e5734787361a` |
| `textures/grug_abilities_skill_flourish.png` | `drop-01/skill__flourish_v3.png` | skill:flourish pass 1 v3 | 8066 | `81d1b3af0184308518cb3cac18ebb4b14505e894b7cd1fcfe05107817bd1654e` |
| `textures/grug_abilities_skill_parry.png` | `drop-02/skill__parry_v1.png` | skill:parry pass 2 v1 | 6626 | `0daf4dd1181c2238877762bbd12f4cc39f7f44a743206794abd685b407591813` |
