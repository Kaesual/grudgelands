# Media Origin & Licenses (grug_classes)

## Round 26 class icons — CC0

All four class icons below were generated for Grudgelands on 2026-09-29
with OpenAI's built-in `image_gen.imagegen` tool, one separate prompt/call
per asset. No third-party image was supplied to the tool. The project
dedicates any rights it holds in these generated images to **CC0-1.0**,
to the extent such rights exist. They are not imported game art.

Final files are opaque 64×64 RGBA PNGs without a frame. Pillow reduces the
originals with Lanczos, normalizes border-connected near-background pixels
to the Round 18 sampled charcoal-blue `#151f2d`, and centers the result on a
matching plate with a 4 px margin. The class accents are brown (Warrior),
blue (Mage), white (Priest), and olive (Scout).

Exact prompts, local source output paths, source and final SHA-256 hashes:
`tools/r26_icons/manifest.json` at the repository root. Reproduce exports
and the 64/32 px contact sheet with `python3 tools/r26_icons/prepare.py`
when those originals are present. AI generation itself is not deterministic.
`python3 tools/r26_icons/prepare.py --check` validates committed files without
the originals. The manifest records the Pillow version.

| File | Origin / treatment | License |
|---|---|---|
| `textures/grug_class_warrior.png` | Own work; OpenAI-generated; export treatment above | CC0-1.0 |
| `textures/grug_class_mage.png` | Own work; OpenAI-generated; export treatment above | CC0-1.0 |
| `textures/grug_class_priest.png` | Own work; OpenAI-generated; export treatment above | CC0-1.0 |
| `textures/grug_class_scout.png` | Own work; OpenAI-generated; export treatment above | CC0-1.0 |

## Round 52 talent-tree backgrounds — CC0

The eight `textures/grug_classes_tree_<tree>.png` backgrounds of the new
Talents page (round52-class-plan.md C6, D5, D7): own work by GPT-6 Astra for
Grudgelands, Round 52 lane ARTA drop 01 (2026-10-19). Each was one separate
call of the built-in `image_gen.imagegen` tool (no third-party image
supplied), then fitted to 1040 × 440 by `tools/r52_art/arta/arta_bg.py`
(centred Lanczos fit, a smooth mask that softly blurs and darkens the centre,
an opaque 256-colour palette PNG). Prompts, source hashes and the exact recipe:
`tools/r52_art/arta/README.md` and `drop-01/manifest.json`. The project
dedicates any rights it holds in these images to **CC0-1.0**, to the extent
such rights exist. Each file is a byte-identical renamed copy of the variant
the user picked on 2026-10-19 (`r52/picks/arta/picks.md`).

| Local file | Source (`tools/r52_art/`) | Pick | Bytes | SHA-256 |
|---|---|---|---:|---|
| `textures/grug_classes_tree_ember.png` | `arta/drop-01/bg/ember_v3.png` | bg.ember.v3 | 193236 | `7174d434a32e245e6ab62d18da2576b6b3ebc287b8c468cff95876dd2251da8c` |
| `textures/grug_classes_tree_rime.png` | `arta/drop-01/bg/rime_v1.png` | bg.rime.v1 | 178498 | `c3607478551c977a3ae3645d6719a3fb4284177458cc4e4da29847872412b96a` |
| `textures/grug_classes_tree_bulwark.png` | `arta/drop-01/bg/bulwark_v3.png` | bg.bulwark.v3 | 180251 | `004030964837e72b4649306a421c23107a710388587048fdc09c1057c22d5ae7` |
| `textures/grug_classes_tree_ruin.png` | `arta/drop-01/bg/ruin_v1.png` | bg.ruin.v1 | 180673 | `0288bce9bae1ac86dae554c8d4add740e992415d317dc70232bedb9c6723fece` |
| `textures/grug_classes_tree_mercy.png` | `arta/drop-01/bg/mercy_v1.png` | bg.mercy.v1 | 180950 | `7f3ef8b32c9391e49e934cf1baffd3ba2b32a725fe88d61a459bc0fa69efba1b` |
| `textures/grug_classes_tree_reckoning.png` | `arta/drop-01/bg/reckoning_v1.png` | bg.reckoning.v1 | 177017 | `efcd090cfdbc68f6c6c0042daa33e56a67603aa7d6237e2237c45c0100f600ae` |
| `textures/grug_classes_tree_quarry.png` | `arta/drop-01/bg/quarry_v1.png` | bg.quarry.v1 | 198429 | `56decdc475d9a7a86f36c4cdc2d3b9085223b846bd443615bcb7958e619c96d1` |
| `textures/grug_classes_tree_veil.png` | `arta/drop-01/bg/veil_v3.png` | bg.veil.v3 | 207612 | `82cc587a8121489e8ac2590bbf7407fe21d5a10918605a955f7f9296b75f19c4` |

## Round 52 talent icons — CC0

The 74 `textures/grug_classes_talent_<node id>.png` icons (one per modifier
and window node of the node list; granting nodes show their skill's icon):
own work by GPT-6 Astra for Grudgelands, Round 52 lane ARTB, style A "Painted
embers" (drop 02, 2026-10-19/20; Measured Breath redrawn in drop 03,
2026-10-20, picked v2). Each was one separate call (or an edit of the
project's own image) of the built-in `image_gen.imagegen` tool, no
third-party image supplied, reduced with Pillow's Lanczos filter to an opaque
64 × 64 RGB PNG without crop, recolouring or compositing. Prompts, source
paths and hashes: `tools/r52_art/artb/README.md`, `drop-02/manifest.json` and
`drop-03/manifest.json`. **CC0-1.0**, as above. Byte-identical renamed copies
of the user's picks (2026-10-20). 0.53.1 replaced 10 of these 74 files with
Round 53 redraws (see "Round 53 redrawn talent icons" below); the 64 still
shipped are listed here.

| Local file | Source (`tools/r52_art/`) | Pick | Bytes | SHA-256 |
|---|---|---|---:|---|
| `textures/grug_classes_talent_fire_mastery.png` | `artb/drop-02/talents/talent.fire_mastery.png` | talent.fire_mastery | 8253 | `8e05cdb0a9fc0d5bcce9c314de39dffa03b0edc707e16f989e1cefc1b09fd5ed` |
| `textures/grug_classes_talent_measured_fuel.png` | `artb/drop-02/talents/talent.measured_fuel.png` | talent.measured_fuel | 7206 | `a2cf374cf8de5c8700faf4530065aaa083f70906b96d23608e8912d1b6c96b76` |
| `textures/grug_classes_talent_far_cast.png` | `artb/drop-02/talents/talent.far_cast.png` | talent.far_cast | 7555 | `2067879cb5c332b521ec0f8b075b12d920bc89252ed1469d6b459df113c3e012` |
| `textures/grug_classes_talent_heat_focus.png` | `artb/drop-02/talents/talent.heat_focus.png` | talent.heat_focus | 7821 | `2aedde433acdbeeddacb44d1b629b73df6f80b5544d5513dfa19acc8853abbc3` |
| `textures/grug_classes_talent_afterglow.png` | `artb/drop-02/talents/talent.afterglow.png` | talent.afterglow | 7911 | `6c7186d4a798b9ce2d2b58e87fafcddde7793172d7905e6b45dcd31b36c858b1` |
| `textures/grug_classes_talent_wide_ember.png` | `artb/drop-02/talents/talent.wide_ember.png` | talent.wide_ember | 8447 | `5ec9c8d7a9105ac12ff628cc336de914969f412baf96a4192937013774e8579f` |
| `textures/grug_classes_talent_broad_impact.png` | `artb/drop-02/talents/talent.broad_impact.png` | talent.broad_impact | 8030 | `c3cebeba59918e53da792a3b5e4890851ef1bc65a5e6e4c445e56a1fafb24c08` |
| `textures/grug_classes_talent_controlled_burn.png` | `artb/drop-02/talents/talent.controlled_burn.png` | talent.controlled_burn | 7708 | `33957ea72625c82f14cbf529976291990f4db3c3124254edeaee316ed2d4f35b` |
| `textures/grug_classes_talent_spreading_rain.png` | `artb/drop-02/talents/talent.spreading_rain.png` | talent.spreading_rain | 7994 | `8a531da8c70e7ad2cfde8d4fba3133f8736590146eb7089ebac8e2c61baefe48` |
| `textures/grug_classes_talent_mana_reserve.png` | `artb/drop-02/talents/talent.mana_reserve.png` | talent.mana_reserve | 8358 | `8d146bb6717b25e2692ae2e436c72980c9a53951b8381ceb092391d3f47c6077` |
| `textures/grug_classes_talent_keen_cold.png` | `artb/drop-02/talents/talent.keen_cold.png` | talent.keen_cold | 7517 | `85e19836739f298105c989b9126e77fa35f7eadaaa8ad6bd1ad73caea0cabc61` |
| `textures/grug_classes_talent_clear_thought.png` | `artb/drop-02/talents/talent.clear_thought.png` | talent.clear_thought | 8582 | `504cd9b99b4d0ba0d0d609c535a935137d192c199b9469bf98ae90aa74eb78ab` |
| `textures/grug_classes_talent_quick_step.png` | `artb/drop-02/talents/talent.quick_step.png` | talent.quick_step | 8226 | `83727317f484fe3e766604804539e41e6b1ec0f89ecc685ac717de05b5934f9d` |
| `textures/grug_classes_talent_thick_ice.png` | `artb/drop-02/talents/talent.thick_ice.png` | talent.thick_ice | 8453 | `f2584f172951149e2e11909846a7959712321482b12a32174161f00173d5d61f` |
| `textures/grug_classes_talent_cold_shock.png` | `artb/drop-02/talents/talent.cold_shock.png` | talent.cold_shock | 8610 | `02033b85bbf58ace2b9a7921d36aeaf12a170ead7272541f8ad3e335d71d9689` |
| `textures/grug_classes_talent_returning_cold.png` | `artb/drop-02/talents/talent.returning_cold.png` | talent.returning_cold | 8508 | `51bb022fa81213613d0a168e192eb78f8963aede5ebda15974fe8401ae700e43` |
| `textures/grug_classes_talent_far_frost.png` | `artb/drop-02/talents/talent.far_frost.png` | talent.far_frost | 8855 | `02512bd0dfc1767f8e406bdfd0a13c6bf45c345a7710e4c96f64b404f6972205` |
| `textures/grug_classes_talent_lasting_armor.png` | `artb/drop-02/talents/talent.lasting_armor.png` | talent.lasting_armor | 8958 | `86122eb6c8df8160fea20169da316ef46aed8559c07b0683dbf37fea6177c3c9` |
| `textures/grug_classes_talent_ironbound.png` | `artb/drop-02/talents/talent.ironbound.png` | talent.ironbound | 8414 | `f3e5bf3cb2737459096ac88d78ebdcbf9ec34cb551d52b6b4b6d46a31975b8de` |
| `textures/grug_classes_talent_weathered.png` | `artb/drop-02/talents/talent.weathered.png` | talent.weathered | 8497 | `3935ee1cfe9478488e0f6c6f268757f04505f67bfdf7a62acff9daa6737e7374` |
| `textures/grug_classes_talent_measured_answer.png` | `artb/drop-02/talents/talent.measured_answer.png` | talent.measured_answer | 8315 | `d6787271c1f74e118ab0aba527ee16db0024adc571efec61d1dc2a7fe7b2951f` |
| `textures/grug_classes_talent_turn_the_edge.png` | `artb/drop-02/talents/talent.turn_the_edge.png` | talent.turn_the_edge | 7728 | `0f86d41bbe0aea44008ffcbdec59e4904d013ca6831b639d44ab01281d35de1e` |
| `textures/grug_classes_talent_recover.png` | `artb/drop-02/talents/talent.recover.png` | talent.recover | 7631 | `d96e1865164f57b7c616d5f5b1b98f0d6da8fa0fd408a269aaab5b233bf3d1b7` |
| `textures/grug_classes_talent_layered_guard.png` | `artb/drop-02/talents/talent.layered_guard.png` | talent.layered_guard | 7787 | `3bb4fb1aab96f02dff802e994d1b2f90027ccb9c234259cf7b0505e29d601f4f` |
| `textures/grug_classes_talent_gather_yourself.png` | `artb/drop-02/talents/talent.gather_yourself.png` | talent.gather_yourself | 8177 | `c88570a367d4e39b935eaee4e9a4eb0f09ac18234939396baa073153865f5e71` |
| `textures/grug_classes_talent_heavy_hand.png` | `artb/drop-02/talents/talent.heavy_hand.png` | talent.heavy_hand | 7714 | `31a5219090b6822907d2026702ec5214230b22266d195efda6082e5ff0815334` |
| `textures/grug_classes_talent_keen_edge.png` | `artb/drop-02/talents/talent.keen_edge.png` | talent.keen_edge | 7221 | `c432499e2c5507a833c7462614c289dab0060ba7bca7b600dc873f3f009f98e1` |
| `textures/grug_classes_talent_onset.png` | `artb/drop-02/talents/talent.onset.png` | talent.onset | 8186 | `f76c05a06e11aca584fc634da610af3956efeb47541c04344088d5736731be8e` |
| `textures/grug_classes_talent_follow_through.png` | `artb/drop-02/talents/talent.follow_through.png` | talent.follow_through | 7488 | `a58887ff6fef737d14b632d239ca9e9d5590b397b5023ef6ede929602441cbd6` |
| `textures/grug_classes_talent_clean_cut.png` | `artb/drop-02/talents/talent.clean_cut.png` | talent.clean_cut | 7278 | `aa9dc27b13cad08f6ae35405a60a44febf71a984cbfd231110c3184b098336bf` |
| `textures/grug_classes_talent_long_fury.png` | `artb/drop-02/talents/talent.long_fury.png` | talent.long_fury | 7227 | `5a407c60b283f771cd87ba27d41dd845af0dddc3e698106c96e838444fd9621d` |
| `textures/grug_classes_talent_reach_the_fight.png` | `artb/drop-02/talents/talent.reach_the_fight.png` | talent.reach_the_fight | 7976 | `3542ef6cee0171c91bbb2dbe9121cb2c817c4622a114a6ecd2e90557be1c46ca` |
| `textures/grug_classes_talent_steady_word.png` | `artb/drop-02/talents/talent.steady_word.png` | talent.steady_word | 7754 | `b0f30c968b3f067bc97f615dde4109a912504aaf1ed3ff0a31fbdbea5bcfa82b` |
| `textures/grug_classes_talent_measured_care.png` | `artb/drop-02/talents/talent.measured_care.png` | talent.measured_care | 7702 | `68dfc129783ccaaa16780153a556b901a640c48f7bc808b82b97fa5749c90d85` |
| `textures/grug_classes_talent_gentle_hand.png` | `artb/drop-02/talents/talent.gentle_hand.png` | talent.gentle_hand | 7547 | `0c5f723e9183c64cc766383bf73b332d64518a0197f7af35bec8d9835afe1a98` |
| `textures/grug_classes_talent_warding_faith.png` | `artb/drop-02/talents/talent.warding_faith.png` | talent.warding_faith | 7564 | `b8590631fc9bcd0933ab7cda2e2c152ecb16383d130881b3d73e1251793a4252` |
| `textures/grug_classes_talent_patient_care.png` | `artb/drop-02/talents/talent.patient_care.png` | talent.patient_care | 8468 | `d604d083ea53ff166042f11bd5139fc03b4217c2b9cea9626a23783a4c01c75e` |
| `textures/grug_classes_talent_deep_reserve.png` | `artb/drop-02/talents/talent.deep_reserve.png` | talent.deep_reserve | 7261 | `bae40a4f34df9c622c1a95cc1e27f7ec891dadcba95284119bc454a427f23d71` |
| `textures/grug_classes_talent_quiet_care.png` | `artb/drop-02/talents/talent.quiet_care.png` | talent.quiet_care | 7339 | `a1c60f3cc9c8c53dca0764359f2146b260899eb676efb9a1f168187890953949` |
| `textures/grug_classes_talent_sharpened_word.png` | `artb/drop-02/talents/talent.sharpened_word.png` | talent.sharpened_word | 7991 | `173a1b8fe5899954e1677c8ad44d14b13533d6c8be50053deb22b1be3e2265cc` |
| `textures/grug_classes_talent_measured_judgment.png` | `artb/drop-02/talents/talent.measured_judgment.png` | talent.measured_judgment | 7905 | `5d25dab4759935c8e056493631b00938ceae00f0de8a4ab0496b7058dc930835` |
| `textures/grug_classes_talent_firm_rebuke.png` | `artb/drop-02/talents/talent.firm_rebuke.png` | talent.firm_rebuke | 8818 | `73375d1b9fccd46e659c55764ad2353be488968568c8d48ad9217aa33444a23c` |
| `textures/grug_classes_talent_resolute_word.png` | `artb/drop-02/talents/talent.resolute_word.png` | talent.resolute_word | 8137 | `6e370e25e1018586f06042526b3ee5b8150d055bfe155c2ce2d4969fea504ab4` |
| `textures/grug_classes_talent_hard_faith.png` | `artb/drop-02/talents/talent.hard_faith.png` | talent.hard_faith | 8204 | `5e0fc254f03d5d57d6d050e912a241b8bc045061a67c76f5a5dba8db5a9fa944` |
| `textures/grug_classes_talent_broad_judgment.png` | `artb/drop-02/talents/talent.broad_judgment.png` | talent.broad_judgment | 8299 | `1c29cc3945a4a2988924c052c8097a490cc11fe318f3766d31f571a2d91ca969` |
| `textures/grug_classes_talent_deep_resolve.png` | `artb/drop-02/talents/talent.deep_resolve.png` | talent.deep_resolve | 8079 | `f612f3337dd9c5bccf1dae0389b45c27a257d063e99d934b9b81484982701efc` |
| `textures/grug_classes_talent_press_the_verdict.png` | `artb/drop-02/talents/talent.press_the_verdict.png` | talent.press_the_verdict | 8228 | `5e02c60a5e3102ccb7c1f2c518b8a29602c113b015f63096aa2e35c800df1697` |
| `textures/grug_classes_talent_unfinished_sentence.png` | `artb/drop-02/talents/talent.unfinished_sentence.png` | talent.unfinished_sentence | 8140 | `307332733b7ff21856b98e9bccf099ba4656abd72d331bcad823ebefa0ee4153` |
| `textures/grug_classes_talent_bowcraft.png` | `artb/drop-02/talents/talent.bowcraft.png` | talent.bowcraft | 7378 | `42c375a48b5addab4416e01120c3610cae65aabeba14a3051c7bd9c25c89d8f5` |
| `textures/grug_classes_talent_quiver.png` | `artb/drop-02/talents/talent.quiver.png` | talent.quiver | 7927 | `e58cc1e23aca3be79b5723a349dbab37405bf5c975b705b830eddab49a38a08c` |
| `textures/grug_classes_talent_measured_breath.png` | `artb/drop-03/talent.measured_breath_v2.png` | talent.measured_breath.v2 | 7813 | `c0cfd7817b4726f997a3b9920beb6ef1d973eb796801534ca3619b4e00ca7656` |
| `textures/grug_classes_talent_firm_aim.png` | `artb/drop-02/talents/talent.firm_aim.png` | talent.firm_aim | 8030 | `7987bd160fb0aacbe27dca08ef7486e7be95d21ea582d30250e4a941190b2875` |
| `textures/grug_classes_talent_long_view.png` | `artb/drop-02/talents/talent.long_view.png` | talent.long_view | 8357 | `1bba323f37320107c9430031b847da194c8b5e7e5ce78e3e67196260a9945372` |
| `textures/grug_classes_talent_broad_shot.png` | `artb/drop-02/talents/talent.broad_shot.png` | talent.broad_shot | 8244 | `1ab666a54b2bc9be5e74c88bda98e14e9dc9682923b5b03b6f511992d237d282` |
| `textures/grug_classes_talent_light_recovery.png` | `artb/drop-02/talents/talent.light_recovery.png` | talent.light_recovery | 7850 | `4f0c27edb587a933ada47ff2ae73d21e6ffd3050185aadf7bedb0fcaff90d846` |
| `textures/grug_classes_talent_follow_the_line.png` | `artb/drop-02/talents/talent.follow_the_line.png` | talent.follow_the_line | 7523 | `cb1f0485f8d4e382b00b542e88e1e60f703a9bc5318ab3ada2ee0b65f4560191` |
| `textures/grug_classes_talent_iron_hail.png` | `artb/drop-02/talents/talent.iron_hail.png` | talent.iron_hail | 8101 | `1cc5d0beb91a7f46691bb2f02945b65e0e649f5ed93576437c80a388cb914097` |
| `textures/grug_classes_talent_fine_edge.png` | `artb/drop-02/talents/talent.fine_edge.png` | talent.fine_edge | 7162 | `a13d1e1bc81cd09b1566a39bea4cba6dba400de873e6b6a7cc95ae3b233ab277` |
| `textures/grug_classes_talent_light_step.png` | `artb/drop-02/talents/talent.light_step.png` | talent.light_step | 7689 | `77de7d26fa313a15033dfa3a28ee398a67212d8fab031985458641d94ec44ce3` |
| `textures/grug_classes_talent_deep_focus.png` | `artb/drop-02/talents/talent.deep_focus.png` | talent.deep_focus | 8201 | `2c2adfde46dbe2013e9bc172b9db1359c6cb81367d1b8a5efb429452a8429dee` |
| `textures/grug_classes_talent_held_guard.png` | `artb/drop-02/talents/talent.held_guard.png` | talent.held_guard | 8710 | `e1495da91b3cf535b5f7287575d2a69958d02c7176308ca82f773647e24f9663` |
| `textures/grug_classes_talent_wide_edge.png` | `artb/drop-02/talents/talent.wide_edge.png` | talent.wide_edge | 7702 | `03b2b0532f2262e10a10d29fa9dbf32adc1b8eaedb49567e3a6273d0025801b8` |
| `textures/grug_classes_talent_turn_the_blade.png` | `artb/drop-02/talents/talent.turn_the_blade.png` | talent.turn_the_blade | 8037 | `fc7abde661bcb8e1cfeb65a71ff81a7cd5ed37792c996ac2495f15d290f8d572` |
| `textures/grug_classes_talent_cutting_rhythm.png` | `artb/drop-02/talents/talent.cutting_rhythm.png` | talent.cutting_rhythm | 8292 | `11bdb2377baf99a739c18d3a516e39a7ec97d559994ee6c1a70a92b7d9d17ed9` |

## Round 53 redrawn talent icons (0.53.1) — CC0

10 talent icons redrawn for clarity in Round 53 (lane ICONS) and picked by the
user on 2026-10-20 (pass 1: drop-01; pass 2: drop-02 for Halt and Finisher),
with the skill icons of the same pass (`grug_abilities/LICENSE-media.md`,
"Round 53 redrawn icons"). Own work by GPT-6 Astra for Grudgelands, style A
"Painted embers" simplified, keeping the circular bronze medallion. Each
proposal was one separate call (or a focused edit of the project's own image)
of the built-in `image_gen.imagegen` tool, no third-party image supplied,
reduced with Pillow's Lanczos filter to an opaque 64 × 64 8-bit RGB PNG
without crop, recolouring, compositing or sharpening. Exact prompts, source
paintings, supplied references, refinement history and hashes:
`tools/r53_art/icons/README.md`, `drop-01/manifest.json` and
`drop-02/manifest.json`. The project dedicates any rights it holds in these
images to **CC0-1.0**, to the extent such rights exist. Each file is a
byte-identical renamed copy of the user's pick (`tools/r531_art/ship_icons.py`
copies and checks them).

| Local file | Source (`tools/r53_art/icons/`) | Pick | Bytes | SHA-256 |
|---|---|---|---:|---|
| `textures/grug_classes_talent_enduring_stand.png` | `drop-01/talent__bulwark_enduring_stand_v3.png` | talent:bulwark_enduring_stand pass 1 v3 | 8587 | `c3106d7796b42ee4051356b127c884f3cf457d158161360e51b7dbaf2971a891` |
| `textures/grug_classes_talent_halt.png` | `drop-02/talent__bulwark_halt_v1.png` | talent:bulwark_halt pass 2 v1 | 7610 | `f80469b2da19221a23c3f3f70b7bc546c80c8b679686118abc4250caef966f06` |
| `textures/grug_classes_talent_finisher.png` | `drop-02/talent__ruin_finisher_v2.png` | talent:ruin_finisher pass 2 v2 | 7754 | `0e424c2d12694668d6171be3f27cff0bae34d75162caf83051c9189a6a84a340` |
| `textures/grug_classes_talent_relentless.png` | `drop-01/talent__ruin_relentless_v3.png` | talent:ruin_relentless pass 1 v3 | 8574 | `81f986ef8bce88e2a68d8ba68b29bb011026e1bde19509aa445dec1193312d02` |
| `textures/grug_classes_talent_stoke.png` | `drop-01/talent__ruin_stoke_v3.png` | talent:ruin_stoke pass 1 v3 | 7342 | `513ddb13c5c93651c37b4e671a05959b693f186421fb993bc4a0eb9a3976e893` |
| `textures/grug_classes_talent_clear_conscience.png` | `drop-01/talent__mercy_clear_conscience_v1.png` | talent:mercy_clear_conscience pass 1 v1 | 7271 | `0fe49e9b92d39babc7c3fadfe2fb0224ca8b9103eceab9c2d44f3ec31dfc4d2e` |
| `textures/grug_classes_talent_lasting_haven.png` | `drop-01/talent__mercy_lasting_haven_v1.png` | talent:mercy_lasting_haven pass 1 v1 | 8048 | `111ede38bbf80553f69f629201a38b2dc2ee49a8578627d8dfc146e0757e42c1` |
| `textures/grug_classes_talent_long_reach.png` | `drop-01/talent__reckoning_long_reach_v3.png` | talent:reckoning_long_reach pass 1 v3 | 7563 | `084bcb42dd1144f5ee934f31b269425b81473826ff46005cf066e2fd3e756e00` |
| `textures/grug_classes_talent_shake_loose.png` | `drop-01/talent__veil_shake_loose_v1.png` | talent:veil_shake_loose pass 1 v1 | 7743 | `d3c95edbe74eeddaf66c30cd396db2c27ca4a768a32a9dec14fd05be22a83c67` |
| `textures/grug_classes_talent_travel_worn.png` | `drop-01/talent__veil_travel_worn_v1.png` | talent:veil_travel_worn pass 1 v1 | 8153 | `11c89c58dbd7fd206598f4648511238518bb3815544bb2e58435483780adb6fc` |

## Round 67 race icons — CC0

The six race icons of the Social tab's player list
(`grug_core.status_icons.RACE_ICONS`): the user's pick of set A (coloured
heads) from Round 67 lane ART, original 32 px pixel drawings exported at
64 × 64 RGBA with nearest-neighbour sampling, authored for Grudgelands by
GPT-6 Astra on 2026-10-30 and drawn entirely by `tools/r67_art/generate.py`
(Pillow and numpy; no source image pixels, external images or fonts). The
project dedicates any rights it holds in them to **CC0-1.0**, to the extent
such rights exist. Each file is a byte-identical renamed copy of its
candidate; provenance: `tools/r67_art/LICENSE-media.md`.

| Local file | Source (`tools/r67_art/`) | Bytes | SHA-256 |
|---|---|---:|---|
| `textures/grug_race_human.png` | `candidates/race_human_a.png` | 596 | `7cdc10b82b9088ff38f4426fc615f664bf646b87e3f3d397e5c54b4a2c532952` |
| `textures/grug_race_dwarf.png` | `candidates/race_dwarf_a.png` | 642 | `1db0936676dcee56f0b2689498f98c0d3c0fcdfe64de1e1a939c34c9a2018be8` |
| `textures/grug_race_elf.png` | `candidates/race_elf_a.png` | 699 | `3fa02c3bcc689641066e8a806ba0f4e2c97d310b1bc24c3a302d260944fc628b` |
| `textures/grug_race_orc.png` | `candidates/race_orc_a.png` | 661 | `c91a812d5c7a92b769d5d3dfe51ab1e8c72fae7977a4c44d8c9eabf0c2867bb6` |
| `textures/grug_race_troll.png` | `candidates/race_troll_a.png` | 739 | `d05649c29f5ba7be506250e4177229fd22a08282b78e1451129a552ed3011254` |
| `textures/grug_race_undead.png` | `candidates/race_undead_a.png` | 599 | `183780fcab073e93121e3c48b60e32eab8ff722b409ace7058dfc9cda469c2e6` |
