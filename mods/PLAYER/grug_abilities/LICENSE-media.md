# Media Origin & Licenses (grug_abilities)

- `grug_abilities_orb.png`: 16×16 radial gradient orb, generated with
  ImageMagick for this project (own work), **CC0**. Historical ability
  backdrop; Round 18 replaces active-skill inventory art with the action
  icons below.
- `grug_abilities_weapon_ready.png`: 20×20 gold readiness ring generated for
  this project with OpenAI image generation, chroma-keyed and reduced to the
  final HUD sprite (own work), **CC0**.

- `crosshair.png`, `object_crosshair.png` (byte-identical 21×21),
  `grug_abilities_draw_ring_00.png` … `_15.png` and
  `grug_abilities_draw_ring_full.png` (35×35): crosshair and bow draw ring
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

All 22 `textures/grug_abilities_skill_*.png` files were generated for this
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

## Bow draw stages — CC BY-SA 4.0

The three draw-stage sprites are unchanged renamed copies from VoxeLibre
commit `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`. They are based on the
XSSheep / Pixel Perfection texture set and licensed CC BY-SA 4.0 under
VoxeLibre's top-level `LEGAL.md`; `mods/ITEMS/mcl_bows/README.txt` points its
textures to those license notes.

| Local file | Upstream source | Treatment |
|---|---|---|
| `textures/grug_abilities_bow_draw_0.png` | `textures/mcl_bows_bow_0.png` | unchanged renamed copy |
| `textures/grug_abilities_bow_draw_1.png` | `textures/mcl_bows_bow_1.png` | unchanged renamed copy |
| `textures/grug_abilities_bow_draw_2.png` | `textures/mcl_bows_bow_2.png` | unchanged renamed copy |

At runtime the Scout applies the equipped bow family's existing color grade
and any bracket modifier to the selected stage. Ending or cancelling the draw
restores that concrete bow's ordinary wield image.

## Round 52 weapon element overlays — CC0

The 30 `textures/grug_abilities_fx_<family>_<weapon>[_draw<n>].png` strips (the
first-person element overlay, round52-class-plan.md C7): own work by GPT-6 Astra
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
| `textures/grug_abilities_fx_quarry_bow_draw0.png` | `drop-04/grug_abilities_fx_quarry_bow_draw0.png` | opaque rework of the user's pick `fx/scout/quarry_bow_draw0_v1.png` | `3f8dc4063d740b9d8cfb85aa914f26e52e1e5f015178218be91a81b3f29e5596` |
| `textures/grug_abilities_fx_quarry_bow_draw1.png` | `drop-04/grug_abilities_fx_quarry_bow_draw1.png` | opaque rework of the user's pick `fx/scout/quarry_bow_draw1_v1.png` | `4027fbd9b02cc4cd1cdf89cb2cfcf5f1f56c7a9883da14aa251b9892d5daea9d` |
| `textures/grug_abilities_fx_quarry_bow_draw2.png` | `drop-04/grug_abilities_fx_quarry_bow_draw2.png` | opaque rework of the user's pick `fx/scout/quarry_bow_draw2_v1.png` | `c308d2200b4178b4f19f915529706af3e642a1c3ad66f01de6913ddbf1808465` |
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
| `textures/grug_abilities_fx_veil_bow_draw0.png` | `drop-04/grug_abilities_fx_veil_bow_draw0.png` | opaque rework of the user's pick `fx/scout/veil_bow_draw0_v1.png` | `ef7f579cb584a660dd80080050ee75b8d9b6afeb1803644ad4105c22247ed9c6` |
| `textures/grug_abilities_fx_veil_bow_draw1.png` | `drop-04/grug_abilities_fx_veil_bow_draw1.png` | opaque rework of the user's pick `fx/scout/veil_bow_draw1_v1.png` | `7da4a0ec83d60f65ed7b1a7e91f28c948c346faf5ce3fc0b9123b79f4a9348c2` |
| `textures/grug_abilities_fx_veil_bow_draw2.png` | `drop-04/grug_abilities_fx_veil_bow_draw2.png` | opaque rework of the user's pick `fx/scout/veil_bow_draw2_v1.png` | `5becc3e8329ffe449a9a320e041e3f9e3b674514c0e28304324bbe8559c26703` |
| `textures/grug_abilities_fx_veil_dagger.png` | `drop-04/grug_abilities_fx_veil_dagger.png` | opaque rework of the user's pick `fx/scout/veil_dagger_v1.png` | `81c3325b3eee9cae87ad67c02b2d03aec9b5cb250a0364eb6c71488b0c14d925` |
| `textures/grug_abilities_fx_veil_sword.png` | `drop-04/grug_abilities_fx_veil_sword.png` | opaque rework of the user's pick `fx/scout/veil_sword_v1.png` | `181bfdd2386974931aaf49a4e67131c1bee96ba567d4d46b12303a71e872d982` |
