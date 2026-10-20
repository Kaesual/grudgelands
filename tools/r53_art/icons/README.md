# Round 53 ICONS — clarity redraw proposals

Prepared 2026-10-20 by GPT-6 Astra on `r53-icons`.
The first drop contains **108 proposals: three variants for each of 26 skill
icons and 10 talent icons**. The user's selection and the eight remaining
redraws are recorded in the pass-2 section below.

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

## Pass 2 — eight redraws

Prepared 2026-10-20 by GPT-6 Astra. The user's comparison-page picks decided
28 of the 36 icons: 13 × pass-1 v1, 1 × v2, 6 × v3 and 8 × the 0.51 icon.
This second drop contains **24 new proposals, eight icons × v1–v3**, for the
remaining choices. These are proposals awaiting selection, not shipped art.
Upgrade classification: **compatible**; staged media and packaging only.

- [Pass-2 manifest and exact prompts](drop-02/manifest.json) record every
  final hash, source painting, supplied reference, processing step and
  `previous_versions` receipt.
- [Pass-2 comparison](drop-02/preview.png) has one row per icon: current
  snapshot, 0.51 for Blink and Charge, the three pass-1 references, then the
  three new proposals. Clearly separated group headers distinguish the two
  passes. Every image appears at actual 64, 32 and 16 px plus 32 px
  greyscale; view at 100%.
- [Pass-2 composition briefs](briefs-pass2.json) and
  [packaging/audit script](build_pass2.py) keep this pass separate.

| Icon | v1 | v2 | v3 |
|---|---|---|---|
| Bellow | Bronze shock ring at chest height | Connected bronze roar fan from the mouth | Broad bronze radial glow behind the bust |
| Blink | Pointed ice slits and a straight transit trail | Bevelled portals, curved ribbon, forward step | Jagged ice slits, low sweeping trail, rightward stride |
| Broadstroke | Sword at the left/start of a wide crimson sweep | Sword across the middle of the sweep | Sword finishing across the upper span, trail below |
| Charge | Nearly horizontal steel shoulder, crimson-dominant streaks | Upward rush, white-hot streak cores, small bronze trims | Downward rush, predominantly crimson streaks |
| Close Dance | Blade to the left, empty open hand to the right | Raised blade to the right, empty hand guarding the chest | Leftward lunge, one forward blade and empty trailing hand |
| Parry | Separate deflected blade and a curved redirect trail | Lit forearm with one dagger behind a violet light ward | Enemy blade knocked wide, clear central opening and dagger-tip glint |
| Halt | Right-facing side view, no effect | Left-facing side view with short shock arc | Forward right-facing side view with impact ring |
| Finisher | Axe splitting the last remnant of a wooden shield | Descending steel blade and almost-spent cracked heart crystal | Sword broken into two separated pieces |

The built-in `image_gen.imagegen` tool made **29 individual calls**: 24
initial paintings and five focused refinements (Bellow v2, Charge v2,
Parry v1/v3 and Finisher v2). Each call used one exact prompt for one image.
The refinements clarify the mouth origin of the roar, restore exactly three
Charge streaks and an upward rush, remove unintended arrowheads from Parry,
and simplify and brighten the heart silhouette for the greyscale check.
Earlier versions remain documented under `previous_versions`; their source
paintings remain at the tool's original output paths.

Only project-owned images were supplied: pass-1 Bellow v3, the corresponding
Close Dance variants, the current Halt icon, and Blink/Charge extracted with
`git show dea1d163:<path>`. Refinements used their own preceding generated
painting. Source and reference SHA-256 hashes and git blob identifiers are
recorded. The current comparison is pinned to `a53abbf2`; the pass-1 files
and all earlier drops remain unchanged.

Processing is whole-image RGB conversion and Lanczos reduction to 64 × 64,
with no crop, recolouring, compositing or sharpening. Only the comparison
sheet combines images and labels. Each final asset is opaque 8-bit RGB.
The requested teleport departure/arrival pair and finishing/deflection
motifs form single action emblems; no extra people or scene are introduced.
Every Scout figure holds exactly one weapon.

All 24 final icons were visually inspected at 64/32/16 px and in greyscale
at 32 px. The delivery audit checks the exact eight-by-three roster, PNG
IHDR/mode/opacity, unique hashes, source reductions, supplied references,
five refinement histories, comparison pixels and all 25 new media rows.
No fixtures, Lua, `mods/` edits, agents, merges or pushes belong to this pass.
The user chooses the final variants; integration owns later runtime checks.

Pass-2 commands, all with `python3 -I tools/r53_art/icons/build_pass2.py`:
`check` audits the committed delivery; `preview` rebuilds the comparison from
its manifest; `prepare` creates source references and jobs in
`/tmp/grudgelands-r53-icons-pass2`; `package` consumes the individually
recorded `receipt_*.json` files there. Generation itself is a separate
built-in-tool operation. Repackaging needs the original generated sources;
the audit still checks committed assets and immutable receipts if those
local sources are no longer available.

## Reproducing pass-1 packaging

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
| `drop-02/skill__bellow_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/skill__bellow_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/skill__bellow_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/skill__blink_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/skill__blink_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/skill__blink_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/skill__broadstroke_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/skill__broadstroke_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/skill__broadstroke_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/skill__charge_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/skill__charge_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/skill__charge_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/skill__close_dance_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/skill__close_dance_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/skill__close_dance_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/skill__parry_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/skill__parry_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/skill__parry_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/talent__bulwark_halt_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/talent__bulwark_halt_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/talent__bulwark_halt_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/talent__ruin_finisher_v1.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/talent__ruin_finisher_v2.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/talent__ruin_finisher_v3.png` | GPT-6 Astra | 2026-10-20 | Built-in imagegen; individual prompt in manifest; RGB + Lanczos | **CC0-1.0** |
| `drop-02/preview.png` | GPT-6 Astra | 2026-10-20 | Pillow comparison of listed proposals and project-owned CC0 icons | **CC0-1.0** |
