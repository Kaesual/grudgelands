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
`_pinning_shot.png`, went with their retired skills in Round 53, so the
manifest's hashes hold for none of the files any more.

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
next section.

| Local file | Source (`tools/r52_art/`) | Pick | Bytes | SHA-256 |
|---|---|---|---:|---|
| `textures/grug_abilities_skill_strike.png` | `artb/drop-02/skills/skill.strike.png` | skill.strike | 8109 | `5666910678cc705e88fa839373aefa8001029671ebcf6630d2370d79d5ab0587` |
| `textures/grug_abilities_skill_charge.png` | `artb/drop-02/skills/skill.charge.png` | skill.charge | 9213 | `7a1dc99645ac99335658279640fce1fd64d394df1a8a2fce577b7e8068d6baf4` |
| `textures/grug_abilities_skill_hold_ground.png` | `artb/drop-02/skills/skill.hold_ground.png` | skill.hold_ground | 9024 | `5433f549236debd96fb6dd30f838f2db6bf01ea87430fad96e86d9f70afaca02` |
| `textures/grug_abilities_skill_taunt.png` | `artb/drop-02/skills/skill.taunt.png` | skill.taunt | 9188 | `5ed39b5b66ef222d8711869d8627598791ce79f60f9e309ea9359436cdf61a7c` |
| `textures/grug_abilities_skill_mighty_blow.png` | `artb/drop-02/skills/skill.mighty_blow.png` | skill.mighty_blow | 8683 | `7cda0edb066b8bdb20e082b897b3e301f54163a58a9af8042cfeceab23da8f87` |
| `textures/grug_abilities_skill_hamstring.png` | `artb/drop-02/skills/skill.hamstring.png` | skill.hamstring | 8113 | `8f233ce93b3e9343362755e1da1de12a508c2ff6b30f5ab99e21fba2799a9060` |
| `textures/grug_abilities_skill_fireball.png` | `artb/drop-02/skills/skill.fireball.png` | skill.fireball | 7055 | `2ae5bfafdf836ed39786f3a9a2f00e5138ceec5e7f5fc9c0da4f3aa86f650a6f` |
| `textures/grug_abilities_skill_ice_nova.png` | `artb/drop-02/skills/skill.ice_nova.png` | skill.ice_nova | 9041 | `92176404ec4d4d53b8749caa0a4c5f00e43fa8e290aa9361fc3b49848c7900d5` |
| `textures/grug_abilities_skill_blink.png` | `artb/drop-02/skills/skill.blink.png` | skill.blink | 9693 | `c57ee52e5b4a7fcb589753756ea20b4be2ea9863dde9ff35eeec8d11f0a2b879` |
| `textures/grug_abilities_skill_smite.png` | `artb/drop-02/skills/skill.smite.png` | skill.smite | 7323 | `6da52ab3175d0ee5f2b8754bf6e2457e84836d8239a673154cf42444f6e089a7` |
| `textures/grug_abilities_skill_heal.png` | `artb/drop-02/skills/skill.heal.png` | skill.heal | 8016 | `b5899864a8001a7c01a7153bb84aceddf68deb8f032a1b760b69a10f01f09368` |
| `textures/grug_abilities_skill_shield_spell.png` | `artb/drop-02/skills/skill.shield_spell.png` | skill.shield_spell | 7681 | `2a1f74181df7ee031a50304c9fd162e2d6fc16b5f324b4dc5f8d1f9de9489388` |
| `textures/grug_abilities_skill_mend.png` | `artb/drop-02/skills/skill.mend.png` | skill.mend | 8111 | `290145f4c0735a491dbe89d775232517a08aeafb92acfc0f6e629e30e297fd7d` |
| `textures/grug_abilities_skill_word_of_ruin.png` | `artb/drop-02/skills/skill.word_of_ruin.png` | skill.word_of_ruin | 8964 | `5fcf2834dc18993756ecb5b27137da26215a2230b08d985fbaee8c094d5b9baf` |
| `textures/grug_abilities_skill_loose.png` | `artb/drop-03/skill.loose_v1.png` | skill.loose.v1 | 7346 | `cde451eff5b15849cd0c510f115af743433291ecba64bb2c8572d482efe25717` |
| `textures/grug_abilities_skill_sidestep.png` | `artb/drop-02/skills/skill.sidestep.png` | skill.sidestep | 8810 | `335c9ac13b81ddfb326698726d4748d953207d6d36c2614f81d3443ae950f6f6` |
| `textures/grug_abilities_skill_sprint.png` | `artb/drop-02/skills/skill.sprint.png` | skill.sprint | 9022 | `56e9f05032fd61e85cc79f1da10fe8ce1dec8842ff2315a96e440297f905fb5a` |
| `textures/grug_abilities_skill_snare_shot.png` | `artb/drop-02/skills/skill.snare_shot.png` | skill.snare_shot | 8255 | `0ad0b911c343bfd7131453bb4366aa2e21b723be522c49c40f5cb25c21063362` |
| `textures/grug_abilities_skill_opening.png` | `artb/drop-02/skills/skill.opening.png` | skill.opening | 8800 | `a24d39906d16dc7a38e255691ee08465c6f7c584e3ff88e9f405332a931c0d02` |

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
(2026-10-20).

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
| `textures/grug_abilities_skill_retort.png` | `artb/drop-02/skills/skill.retort.png` | skill.retort | 9121 | `4ea839d0d79435890139f0ad82742321cb5e172600419093e3df68f91199c4cb` |
| `textures/grug_abilities_skill_bellow.png` | `artb/drop-02/skills/skill.bellow.png` | skill.bellow | 9894 | `813e3e0eab16e4515a016e7972be598b23ff5a39ee78b6864d1c180a145635a8` |
| `textures/grug_abilities_skill_unbroken.png` | `artb/drop-02/skills/skill.unbroken.png` | skill.unbroken | 9074 | `e54e52dfef3f9ac70e9fcb46397fcdc354fabdc5c1c60be0eb75a340fa275eb5` |
| `textures/grug_abilities_skill_broadstroke.png` | `artb/drop-02/skills/skill.broadstroke.png` | skill.broadstroke | 8785 | `60e797a57ee02b4a83238c238f2ae0517532f105ce29f74814b2d8ef13955793` |
| `textures/grug_abilities_skill_ruination.png` | `artb/drop-02/skills/skill.ruination.png` | skill.ruination | 9023 | `55411e82b6011b4119653d829c6521c3b6fbfa64777d7641326b2275ae2b23ff` |
| `textures/grug_abilities_skill_hearten.png` | `artb/drop-02/skills/skill.hearten.png` | skill.hearten | 8992 | `9bbd635b4ac006aab32ceb136007f5d7e9b28bb51737c3e88edec4a70c887ef3` |
| `textures/grug_abilities_skill_haven.png` | `artb/drop-02/skills/skill.haven.png` | skill.haven | 8711 | `0ab56c71d716dd8a48e42752f4550b7a7328f480a898703125cbf4165ff2da9f` |
| `textures/grug_abilities_skill_rebuke.png` | `artb/drop-02/skills/skill.rebuke.png` | skill.rebuke | 7789 | `075f07969436f0e5a9807ada4c3f99b68e688da7e4530f614f20b6b3600783a1` |
| `textures/grug_abilities_skill_censure.png` | `artb/drop-02/skills/skill.censure.png` | skill.censure | 9503 | `82d18d024841d3bae658b87f1e8d5b576bb2a17946c9fa0fc2652aa16d6e0b0b` |
| `textures/grug_abilities_skill_final_word.png` | `artb/drop-02/skills/skill.final_word.png` | skill.final_word | 8277 | `6db235c3b8f3303af6700f94389d353a30fb0909bf17bcd11baea8bba2e32af1` |
| `textures/grug_abilities_skill_true_draw.png` | `artb/drop-02/skills/skill.true_draw.png` | skill.true_draw | 8085 | `2ad411ad0749b4ed469f3c782242f449140b351cdd2857f762e1f5805e8cccf4` |
| `textures/grug_abilities_skill_split_shot.png` | `artb/drop-02/skills/skill.split_shot.png` | skill.split_shot | 8168 | `fdfb97d21bbf63e2df0b2780470e628eff525e6b5bbc345f2437cbe4a6d182da` |
| `textures/grug_abilities_skill_arrowfall.png` | `artb/drop-02/skills/skill.arrowfall.png` | skill.arrowfall | 7549 | `989391412d0ca4f5919f3f66e34178338f03696a1e43c5d684a6e380a17a4bc3` |
| `textures/grug_abilities_skill_bladecraft.png` | `artb/drop-03/skill.bladecraft_v3.png` | skill.bladecraft.v3 | 7401 | `d8a495a2ec2e48b33d5fabdb4bdddcbf8ee080a981d488d858dd1b1c679b86dc` |
| `textures/grug_abilities_skill_parry.png` | `artb/drop-03/skill.parry_v2.png` | skill.parry.v2 | 7144 | `361376923a107f287ad2f7ee57eaaef8566ca84da9c65bfe10af95b61973a33d` |
| `textures/grug_abilities_skill_flourish.png` | `artb/drop-03/skill.flourish_v1.png` | skill.flourish.v1 | 6062 | `a0c1d1115eda96fd215bdc342762e106d00887cdfb0439920dc955d57a02d3bf` |
| `textures/grug_abilities_skill_close_dance.png` | `artb/drop-02/skills/skill.close_dance.png` | skill.close_dance | 9882 | `7012b85adbff43758c2502fe824bc552a7b84223ef1bde84febc55df5fef478c` |
