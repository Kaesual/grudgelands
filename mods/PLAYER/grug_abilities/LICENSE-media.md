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
Round 52 replaced 19 of these files with redrawn icons (the section "Round 52
redrawn skill icons" below); only `grug_abilities_skill_cinderfall.png`,
`_glacial_ward.png` and `_pinning_shot.png` are still the Round 18 art, and
the manifest's hashes hold for those three only.

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
for Grudgelands, Round 52 lane ARTA drop 03 (2026-10-19), drawn pixel by pixel by
the generator `tools/r52_art/arta/arta_fx3.py` on branch `r52-arta` (Python/Pillow,
explicit original geometry; no weapon pixels enter a strip), **CC0-1.0**.
Provenance and the full drop manifest: `tools/r52_art/arta/README.md` and
`drop-03/manifest.json` on that branch. Each file is a byte-identical renamed
copy of the strip the user picked on 2026-10-19 (`r52/picks/arta/picks.md`):
RGBA, 16 px wide, the family's frame count × 16 px high; the animation is on the
skill item's definition (`grug_abilities.WEAPON_FX_ANIMATION`).

| Local file | Source (drop-03 on r52-arta) | Pick | SHA-256 |
|---|---|---|---|
| `textures/grug_abilities_fx_bulwark_dagger.png` | `fx/warrior/bulwark_dagger_v1.png` | fx.warrior.bulwark.dagger.v1 "Measured edge" | `b4675aa7d2c2b62b0f3d8eafc151c9821147ddeeda8b914157b06507bc530ffa` |
| `textures/grug_abilities_fx_bulwark_greataxe.png` | `fx/warrior/bulwark_greataxe_v1.png` | fx.warrior.bulwark.greataxe.v1 "Measured edge" | `77e44d519cef2a24af2f8f16226b3bd191dae230adb6978a740b95602503b771` |
| `textures/grug_abilities_fx_bulwark_sword.png` | `fx/warrior/bulwark_sword_v2.png` | fx.warrior.bulwark.sword.v2 "Rivet glint" | `86c022ca9f5e05625db245110d7d692fec140f01c4606356d1fb91fdfaea4b3f` |
| `textures/grug_abilities_fx_ember_dagger.png` | `fx/mage/ember_dagger_v1.png` | fx.mage.ember.dagger.v1 "Candle tongue" | `28f88f808b188c6adbbf995ce2b5d532a83e35c9d1fd841bad71a5058a8b87bc` |
| `textures/grug_abilities_fx_ember_staff.png` | `fx/mage/ember_staff_v1.png` | fx.mage.ember.staff.v1 "Candle tongue" | `da6bb86a3702fb282b9372c6a455557c929bb3b66317f7c53b051e3c73375eb5` |
| `textures/grug_abilities_fx_ember_wand.png` | `fx/mage/ember_wand_v1.png` | fx.mage.ember.wand.v1 "Candle tongue" | `ab36fb3c11a112a8d5ef8450dfb50ed5bfa212402dd0419249c46f2b64bfdb33` |
| `textures/grug_abilities_fx_mercy_dagger.png` | `fx/priest/mercy_dagger_v1.png` | fx.priest.mercy.dagger.v1 "Quiet blessing" | `8e17aff736ebcfadca0387bf655247a7a528ffe334679b2dcbbd485c74d5ef30` |
| `textures/grug_abilities_fx_mercy_staff.png` | `fx/priest/mercy_staff_v2.png` | fx.priest.mercy.staff.v2 "Sheltered light" | `4b00c603fbd534e49649f46defd8ce2efb7e3e7fc237591cb994f10429b5b8dc` |
| `textures/grug_abilities_fx_mercy_wand.png` | `fx/priest/mercy_wand_v1.png` | fx.priest.mercy.wand.v1 "Quiet blessing" | `da02e8ad08e9fda7dd894c082e6ff4606c9ecc701919fad4013754acba388975` |
| `textures/grug_abilities_fx_quarry_bow.png` | `fx/scout/quarry_bow_v1.png` | fx.scout.quarry.bow.v1 "Passing breeze" | `313b1fa0b46e000735a712197b10eb6d5b902a32fa9250f0c4a491664656034f` |
| `textures/grug_abilities_fx_quarry_bow_draw0.png` | `fx/scout/quarry_bow_draw0_v1.png` | fx.scout.quarry.bow.draw0.v1 "Passing breeze" | `ab7f1a7c7ca0d306cc2391989cb08ce8ec8805becc4b8248194e08a3824aba0c` |
| `textures/grug_abilities_fx_quarry_bow_draw1.png` | `fx/scout/quarry_bow_draw1_v1.png` | fx.scout.quarry.bow.draw1.v1 "Passing breeze" | `8518c6677a34e03fbee56f3a9130a0aa683dc31363a36c8e57475401847c382e` |
| `textures/grug_abilities_fx_quarry_bow_draw2.png` | `fx/scout/quarry_bow_draw2_v1.png` | fx.scout.quarry.bow.draw2.v1 "Passing breeze" | `7a416f83079b0354765b752d153440356926f098dffd61928ac9d93599cc1869` |
| `textures/grug_abilities_fx_quarry_dagger.png` | `fx/scout/quarry_dagger_v1.png` | fx.scout.quarry.dagger.v1 "Passing breeze" | `41bf37af02d4cc9a9d717b7656afab479eafcb3f4ce6154a9cbb7cdd6dd1becc` |
| `textures/grug_abilities_fx_quarry_sword.png` | `fx/scout/quarry_sword_v1.png` | fx.scout.quarry.sword.v1 "Passing breeze" | `d8f5f67c284d2f44ff2c571cc86e7ac29e35db0f9a55d6cc87a976e5cd5a01ac` |
| `textures/grug_abilities_fx_reckoning_dagger.png` | `fx/priest/reckoning_dagger_v2.png` | fx.priest.reckoning.dagger.v2 "Golden seal" | `0230bae1264428314a03ba1d33ab8c499bc8c19cdfedb38477f62df26b2260dd` |
| `textures/grug_abilities_fx_reckoning_staff.png` | `fx/priest/reckoning_staff_v1.png` | fx.priest.reckoning.staff.v1 "White verdict" | `271202b65d7f59138993d468820fb0c035542de0e11f2292ec08032bc234e568` |
| `textures/grug_abilities_fx_reckoning_wand.png` | `fx/priest/reckoning_wand_v2.png` | fx.priest.reckoning.wand.v2 "Golden seal" | `fb356d488fc4018e7c5960c6ee0896a5419bb74399fad69599e4ac7e9b98c60b` |
| `textures/grug_abilities_fx_rime_dagger.png` | `fx/mage/rime_dagger_v1.png` | fx.mage.rime.dagger.v1 "Growing frost fern" | `dd0b68415d8868f98fb94091c729e7b6e7d4067087bbf55fb68bc93083aa0d3f` |
| `textures/grug_abilities_fx_rime_staff.png` | `fx/mage/rime_staff_v1.png` | fx.mage.rime.staff.v1 "Growing frost fern" | `69a72e3371b46915de1cc25e3aa07b58447bda331734d4848e7ee59d9e5ff0ab` |
| `textures/grug_abilities_fx_rime_wand.png` | `fx/mage/rime_wand_v1.png` | fx.mage.rime.wand.v1 "Growing frost fern" | `99bb5c35f1452c7386c46516c914477eac07213cfc434d1f64f9c852a81b51f3` |
| `textures/grug_abilities_fx_ruin_dagger.png` | `fx/warrior/ruin_dagger_v1.png` | fx.warrior.ruin.dagger.v1 "Hot cutting edge" | `8088c17ad1793d97eade76fd45292fb1a625f5dd1837a304f8946eedbb257fda` |
| `textures/grug_abilities_fx_ruin_greataxe.png` | `fx/warrior/ruin_greataxe_v1.png` | fx.warrior.ruin.greataxe.v1 "Hot cutting edge" | `ec88358112a94ffbf67df10b0be41ddb03e02663b8a438be9fc0720a781910b9` |
| `textures/grug_abilities_fx_ruin_sword.png` | `fx/warrior/ruin_sword_v1.png` | fx.warrior.ruin.sword.v1 "Hot cutting edge" | `84a2a0380096aef8376659fd29f3c0c7730802f83f29de046a3cbb2e84584ac9` |
| `textures/grug_abilities_fx_veil_bow.png` | `fx/scout/veil_bow_v1.png` | fx.scout.veil.bow.v1 "Fine smoke" | `6314d293e40596c4001a2b302cf7f887562d808d8221928fffac4276459500df` |
| `textures/grug_abilities_fx_veil_bow_draw0.png` | `fx/scout/veil_bow_draw0_v1.png` | fx.scout.veil.bow.draw0.v1 "Fine smoke" | `c5383fd986d26fc76ac27c29db12bd93f8835ef4d8e21a5bfe6aa37e2f23d67e` |
| `textures/grug_abilities_fx_veil_bow_draw1.png` | `fx/scout/veil_bow_draw1_v1.png` | fx.scout.veil.bow.draw1.v1 "Fine smoke" | `2d9b8defa53c8a9152484375af95c5a4abf0efbd04e522f86c42a6d7f36b465c` |
| `textures/grug_abilities_fx_veil_bow_draw2.png` | `fx/scout/veil_bow_draw2_v1.png` | fx.scout.veil.bow.draw2.v1 "Fine smoke" | `dca9f4b5bd745af20508ecf1cc57326e83a9b559898baf9c6100b1e1c79b0b31` |
| `textures/grug_abilities_fx_veil_dagger.png` | `fx/scout/veil_dagger_v1.png` | fx.scout.veil.dagger.v1 "Fine smoke" | `554be2b04f0e0d02c8be10ee3a0ce7485a0faf09c6c28390b8dcf3e0c5929cfe` |
| `textures/grug_abilities_fx_veil_sword.png` | `fx/scout/veil_sword_v1.png` | fx.scout.veil.sword.v1 "Fine smoke" | `5534f9229cc304326f4cdfcb491e4ef4e263488c2e30b67385698062b393e3e3` |

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
copies of the user's picks (2026-10-20). The 25 icons of skills that do not
exist yet stay staged under `tools/r52_art/artb/` for round K.

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
