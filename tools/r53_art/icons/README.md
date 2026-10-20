# Round 53 ICONS — clarity redraw proposals

Prepared 2026-10-20 by GPT-6 Astra on `r53-icons`.
This drop contains **108 proposals: three variants for each of 26 skill icons
and 10 talent icons**. They await the user's selection.

Upgrade classification: **compatible**. This is staged media and its packaging.
No shipped assets, Lua or earlier drops change. No fixtures, engine runs,
subagents, merge or push are part of this lane.

The user's 2026-10-20 brief asks for the clarity of the project's 0.51 icons
inside style A / Painted embers: fewer, larger painted masses, natural object
colours, a quiet tree-coloured field and a separate effect accent.
Skills have no frame; talents retain the circular bronze medallion.

- [Manifest and exact prompts](drop-01/manifest.json): key, variant, tree,
  final path and SHA-256, exact individual prompt, processing, original tool
  output path/hash, supplied reference path/hash/git blob, and comparison
  provenance, including `previous_versions` for the 19 targeted refinements.
  Final paths resolve from `drop-01/`; project reference paths resolve from
  the repository root. Absolute reference paths identify unchanged original
  paintings at the tool's output location.
- [Preview 1](drop-01/preview-1.png), [2](drop-01/preview-2.png),
  [3](drop-01/preview-3.png), [4](drop-01/preview-4.png),
  [5](drop-01/preview-5.png), [6](drop-01/preview-6.png): one row per icon,
  showing 0.51 where present, the current snapshot and v1–v3, each at actual
  64, 32 and 16 px, with a 32 px greyscale check below. View at 100%.
- [Composition briefs](briefs.json) preserve the intended differences.
  [Packaging script](build_drop.py) runs with `python3 -I`.

Every proposal uses the **built-in `image_gen.imagegen` tool**, one separate
prompt and call per image. No third-party images were supplied. The 0.51
and current icons were inspected side by side before generation. Matching
Strike masters were supplied for Retort; matching Mighty Blow masters were
supplied for Broadstroke; Taunt v1 was supplied for Bellow v1. The latter
keeps the same helmet, shoulder armour and bust design while changing from
profile to near-frontal as the brief requests.
Nineteen additional focused edit calls simplify the initial renderings or
make the composition differences clearer; all earlier prompts, source
hashes and final-image receipts remain in `previous_versions`.

Pillow converts the entire square source to RGB and reduces it to 64 × 64
with `Image.Resampling.LANCZOS`, without cropping, recolouring, compositing
or sharpening. Final PNGs are opaque 8-bit RGB. Only comparison sheets
combine images and labels. Source paintings stay at their original tool
locations; their immutable receipts remain in the manifest.

Exactly one Heal proposal retains teal light (v2), one Mend proposal retains
natural green leaves (v1), and one Word of Ruin proposal retains a
violet-magenta crack (v2); the skull itself remains ivory. The specific
multi-part motifs requested in the brief (portal afterimage, splitting shot,
crossed blades, healing hands, paired boots) are treated as single action
emblems. Healing crosses, return arrows and simple target rings are the
explicitly requested semantic shapes; no lettering or decorative glyphs
are added.

All 108 final proposals were visually inspected at actual 64/32/16 px,
in greyscale at 32 px and beside retained icons of their tree.
The packaging audit passed: complete 36 × 3 roster, 108 unique final
hashes, 64 × 64 opaque 8-bit RGB PNGs, exact prompts, source/reference
hashes, six comparison sheets and 114 media rows. The current comparison
textures were also checked against `main` and matched.
The user makes the final selection; later integration owns desktop and
web runtime checks.

## Reproducing packaging

`python3 -I tools/r53_art/icons/build_drop.py check` audits committed
deliverables without regenerating art and also checks cached originals
when available. `preview` rebuilds comparison sheets
from the manifest and the recorded git revisions. `references` and `prepare`
create the original study inputs and generation jobs in
`/tmp/grudgelands-r53-icons`; `package` consumes generation receipts there.
The built-in generator is invoked separately, not by the Python script.
`context` creates scratch comparisons with retained tree icons at 32 px.
Do not rerun `references` to replace the recorded current snapshot after
the branch changes.

## Media

Paths are relative to this folder. **CC0-1.0** means the project dedicates
any rights it holds in these images to CC0-1.0, to the extent such rights
exist. Comparison sheets include this project's existing CC0 icons.

| File | Author | Date | Source / method | License |
|---|---|---|---|---|
| `drop-01/skill__strike_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__strike_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__strike_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__charge_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__charge_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__charge_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__hold_ground_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__hold_ground_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__hold_ground_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__taunt_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__taunt_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__taunt_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__bellow_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__bellow_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__bellow_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__retort_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__retort_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__retort_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__bulwark_halt_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__bulwark_halt_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__bulwark_halt_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__bulwark_enduring_stand_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__bulwark_enduring_stand_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__bulwark_enduring_stand_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__mighty_blow_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__mighty_blow_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__mighty_blow_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__broadstroke_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__broadstroke_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__broadstroke_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__hamstring_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__hamstring_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__hamstring_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__ruination_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__ruination_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__ruination_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__ruin_stoke_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__ruin_stoke_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__ruin_stoke_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__ruin_finisher_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__ruin_finisher_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__ruin_finisher_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__ruin_relentless_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__ruin_relentless_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__ruin_relentless_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__blink_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__blink_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__blink_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__heal_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__heal_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__heal_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__mend_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__mend_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__mend_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__shield_spell_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__shield_spell_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__shield_spell_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__mercy_clear_conscience_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__mercy_clear_conscience_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__mercy_clear_conscience_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__mercy_lasting_haven_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__mercy_lasting_haven_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__mercy_lasting_haven_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__rebuke_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__rebuke_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__rebuke_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__word_of_ruin_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__word_of_ruin_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__word_of_ruin_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__censure_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__censure_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__censure_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__reckoning_long_reach_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__reckoning_long_reach_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__reckoning_long_reach_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__loose_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__loose_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__loose_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__sidestep_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__sidestep_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__sidestep_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__sprint_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__sprint_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__sprint_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__true_draw_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__true_draw_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__true_draw_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__split_shot_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__split_shot_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__split_shot_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__opening_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__opening_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__opening_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__parry_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__parry_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__parry_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__flourish_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__flourish_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__flourish_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__close_dance_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__close_dance_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/skill__close_dance_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__veil_shake_loose_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__veil_shake_loose_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__veil_shake_loose_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__veil_travel_worn_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__veil_travel_worn_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/talent__veil_travel_worn_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-01/preview-1.png` | GPT-6 Astra | 2026-10-20 | Pillow comparison of listed proposals and project-owned CC0 icons | **CC0-1.0** |
| `drop-01/preview-2.png` | GPT-6 Astra | 2026-10-20 | Pillow comparison of listed proposals and project-owned CC0 icons | **CC0-1.0** |
| `drop-01/preview-3.png` | GPT-6 Astra | 2026-10-20 | Pillow comparison of listed proposals and project-owned CC0 icons | **CC0-1.0** |
| `drop-01/preview-4.png` | GPT-6 Astra | 2026-10-20 | Pillow comparison of listed proposals and project-owned CC0 icons | **CC0-1.0** |
| `drop-01/preview-5.png` | GPT-6 Astra | 2026-10-20 | Pillow comparison of listed proposals and project-owned CC0 icons | **CC0-1.0** |
| `drop-01/preview-6.png` | GPT-6 Astra | 2026-10-20 | Pillow comparison of listed proposals and project-owned CC0 icons | **CC0-1.0** |
