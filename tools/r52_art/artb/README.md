# Round 52 ARTB — talent and skill icons

## Pass 2 — full set in style A / Painted embers

Completed 2026-10-20 by GPT-6 Astra on `r52-artb`; started 2026-10-19.
The user's 2026-10-19 selection is extended to **118 icons: 74 talents and
44 skills**, including redraws for all 19 shipped skill IDs. All twelve
picked A samples are reused byte-for-byte, with the six talent filenames
changed to the requested name-derived keys. **No picked sample was redrawn.**
The complete set awaits the user's pick and later integration.

Upgrade classification: **compatible**. These are staged media and Python
packaging files. No Lua, `mods/`, shipped icons or `drop-01/` files changed.
No fixtures, engine runs, agents, merge or push were used.

### Files and coverage

- [Manifest](drop-02/manifest.json): every key, kind, tree/family, node or
  ability ID, motif, final path and SHA-256, exact individual prompt,
  original tool output path/hash, processing and `reused_from` receipt.
- `drop-02/talents/talent.<name_in_snake_case>.png`: all 71 modifier and
  three window nodes from node-list section 2, each exactly once.
- `drop-02/skills/skill.<ability_id>.png`: all 44 skills from section 3,
  each exactly once; Shield keeps `shield_spell` and all other shipped IDs
  are retained. Every icon is an opaque **64 × 64 RGB PNG**.
- Eight contact sheets below show each tree's talent icons and skills at
  actual **64 px and 32 px**, both on dark strips and on the picked ARTA
  crop. Strike is neutral steel and appears on the Bulwark sheet, labelled
  universal/neutral. View at 100% for native pixel sizes.
- [Hotbars](drop-02/hotbars.png): four labelled eight-slot class mockups,
  **48 px** per icon, with starters and a selection of tree skills. These
  are art comparisons, not proposed builds or client screenshots.
- [Packaging and sheet script](build_full_set.py): roster parsing, prompt
  preparation, Lanczos reduction, contact sheets and read-only audit.
- `drop-02/background-crops/`: exact native-pixel crops of the eight
  selected ARTA backgrounds. Their pinned git commit, source path/hash,
  crop box and output hash are in the manifest, so sheet rebuilding does
  not depend on another worktree or branch being present.

| Tree / sheet | Talents | Tree skills | Picked background |
|---|---:|---:|---|
| [Ember](drop-02/sheet-ember.png) | 9 | 5 | ember v3 |
| [Rime](drop-02/sheet-rime.png) | 9 | 6 | rime v1 |
| [Bulwark](drop-02/sheet-bulwark.png) | 9 | 5 + neutral Strike | bulwark v3 |
| [Ruin](drop-02/sheet-ruin.png) | 10 | 5 | ruin v1 |
| [Mercy](drop-02/sheet-mercy.png) | 9 | 5 | mercy v1 |
| [Reckoning](drop-02/sheet-reckoning.png) | 10 | 5 | reckoning v1 |
| [Quarry](drop-02/sheet-quarry.png) | 9 | 7 | quarry v1 |
| [Veil](drop-02/sheet-veil.png) | 9 | 5 | veil v3 |
| **Total** | **74** | **44** | **8 crops** |

### Method and visual inspection

The [node list](../../../docs/planning/class-redesign/node-list.md) owns
the names, types and motifs. The picked
[style rules](drop-01/STYLE.md) supply broad painted facets, luminous
cores, matte shadows, upper-left light, the bronze talent medallion and
palette anchors. The user's pass-2 ruling supersedes pass 1's broad skill
families: one palette per tree, including steel/bronze for Bulwark and
separate Mercy/Reckoning palettes; Strike is neutral steel.

The 106 newly delivered icons use built-in `image_gen.imagegen`, with one
separate prompt and call per image: 101 fresh generations and five edits
of this project's own base skill images. No third-party image was supplied.
Two additional edit calls refined Bellow's visible helmet and Broadstroke's
three target silhouettes after the 32 px review; their superseded receipts
remain in `previous_versions`. The twelve reused files retain their pass-1
prompts and processing, including the already paired Fiery/Cold Spark.

The other pairs retain their identifying base form: Ice Nova extends Ice
Wave's foreground ice fan into a ring; Retort retains Strike's sword;
Bellow retains Taunt's gauntlet; Broadstroke retains Mighty Blow's sword
and hands. Loose was derived from the picked Bladecraft source, retaining
the bow's placement and replacing the diagonal blade with an arrow.
Unfinished Sentence uses light ribbons instead of writing; Word of Ruin
uses a cracked non-alphabetic seal. No icon contains text or letters.

Pillow converts each original to RGB, reduces the whole square with
`Image.Resampling.LANCZOS`, and writes an optimized PNG without source
metadata. Final icons have no crop, recoloring, compositing or sharpening.
Only review sheets combine labels, backgrounds, frames and icon copies.
Original tool outputs remain at the local paths in the manifest; all
final icons and sheet inputs are committed in this drop.

All eight sheets were visually inspected at 64 px and 32 px, all four
hotbars at 48 px, and the transform pairs together. The file audit checks
exact node-list coverage, names and family mapping, 118 unique hashes,
RGB/size/PNG format, complete receipts, byte-identical reuse, the eight
picked background variants, preview hashes and per-file CC0 media rows.
Nothing is uncovered. User selection and desktop/web runtime checks are
part of the later integration lane.

### Rebuild and audit

Requires Python 3.9+ and Pillow 10.1+. Run from the repository root:

```sh
python3 -I tools/r52_art/artb/build_full_set.py
python3 -I tools/r52_art/artb/build_full_set.py --check
```

The first rebuilds the nine review images from committed icons/crops and
updates their hashes; the second reads only. `--pending` prints the exact
prompts for unfinished entries. The initial setup used `--init`, then one
built-in generation call per pending entry, followed by:

```sh
python3 -I tools/r52_art/artb/build_full_set.py --record-source KEY /absolute/tool/output.png
```

`--record-source` refuses to overwrite an existing final. A reviewed new
icon can be refined with `--revise-source KEY SOURCE PROMPT_FILE`; this
keeps its previous receipt and refuses to alter a picked sample. Built-in
image generation is called by the agent; the Python script has no API or
network dependency. Generated source images are needed only when packaging
an icon again, not when rebuilding the sheets.

### Pass-2 media

Paths are relative to this folder. **CC0** means **CC0-1.0**, the project's
dedication of any rights it holds, to the extent such rights exist. New
icons were generated on 2026-10-19–20; reused samples and source ARTA
backgrounds are dated 2026-10-19. Packaging and sheets finished 2026-10-20.
Each icon's exact source and changes are recorded in the manifest. ARTA's
source README verifies CC0-1.0 for all eight selected backgrounds.

| File | Author | Source / method | License |
|---|---|---|---|
| `drop-02/talents/talent.fire_mastery.png` | GPT-6 Astra | Exact copy of `drop-01/A/talent.f1.png`; original imagegen receipt retained | **CC0-1.0** |
| `drop-02/talents/talent.measured_fuel.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.far_cast.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.heat_focus.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.afterglow.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.wide_ember.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.broad_impact.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.controlled_burn.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.spreading_rain.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.mana_reserve.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.keen_cold.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.clear_thought.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.quick_step.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.thick_ice.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.cold_shock.png` | GPT-6 Astra | Exact copy of `drop-01/A/talent.r10.png`; original imagegen receipt retained | **CC0-1.0** |
| `drop-02/talents/talent.returning_cold.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.far_frost.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.lasting_armor.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.ironbound.png` | GPT-6 Astra | Exact copy of `drop-01/A/talent.b2.png`; original imagegen receipt retained | **CC0-1.0** |
| `drop-02/talents/talent.weathered.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.measured_answer.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.turn_the_edge.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.recover.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.layered_guard.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.halt.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.enduring_stand.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.gather_yourself.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.heavy_hand.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.stoke.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.keen_edge.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.onset.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.follow_through.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.clean_cut.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.finisher.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.relentless.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.long_fury.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.reach_the_fight.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.steady_word.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.measured_care.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.gentle_hand.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.warding_faith.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.patient_care.png` | GPT-6 Astra | Exact copy of `drop-01/A/talent.m7.png`; original imagegen receipt retained | **CC0-1.0** |
| `drop-02/talents/talent.clear_conscience.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.deep_reserve.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.quiet_care.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.lasting_haven.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.sharpened_word.png` | GPT-6 Astra | Exact copy of `drop-01/A/talent.rk1.png`; original imagegen receipt retained | **CC0-1.0** |
| `drop-02/talents/talent.measured_judgment.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.firm_rebuke.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.long_reach.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.resolute_word.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.hard_faith.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.broad_judgment.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.deep_resolve.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.press_the_verdict.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.unfinished_sentence.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.bowcraft.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.quiver.png` | GPT-6 Astra | Exact copy of `drop-01/A/talent.q2.png`; original imagegen receipt retained | **CC0-1.0** |
| `drop-02/talents/talent.measured_breath.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.firm_aim.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.long_view.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.broad_shot.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.light_recovery.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.follow_the_line.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.iron_hail.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.fine_edge.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.light_step.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.deep_focus.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.held_guard.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.wide_edge.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.turn_the_blade.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.shake_loose.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.cutting_rhythm.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/talents/talent.travel_worn.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.fiery_spark.png` | GPT-6 Astra | Exact copy of `drop-01/A/skill.fiery_spark.png`; original imagegen receipt retained | **CC0-1.0** |
| `drop-02/skills/skill.ice_wave.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.fireball.png` | GPT-6 Astra | Exact copy of `drop-01/A/skill.fireball.png`; original imagegen receipt retained | **CC0-1.0** |
| `drop-02/skills/skill.flame_lance.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.meteor.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.fire_rain.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.cold_spark.png` | GPT-6 Astra | Exact copy of `drop-01/A/skill.cold_spark.png`; original imagegen receipt retained | **CC0-1.0** |
| `drop-02/skills/skill.blink.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.rime_mantle.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.ice_nova.png` | GPT-6 Astra | Built-in imagegen edit of own `skill.ice_wave`; RGB + Lanczos; manifest prompt/receipt | **CC0-1.0** |
| `drop-02/skills/skill.winter_field.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.strike.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.charge.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.retort.png` | GPT-6 Astra | Built-in imagegen edit of own `skill.strike`; RGB + Lanczos; manifest prompt/receipt | **CC0-1.0** |
| `drop-02/skills/skill.hold_ground.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.taunt.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.bellow.png` | GPT-6 Astra | Built-in imagegen edit of own `skill.taunt`; RGB + Lanczos; manifest prompt/receipt | **CC0-1.0** |
| `drop-02/skills/skill.unbroken.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.mighty_blow.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.hamstring.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.broadstroke.png` | GPT-6 Astra | Built-in imagegen edit of own `skill.mighty_blow`; RGB + Lanczos; manifest prompt/receipt | **CC0-1.0** |
| `drop-02/skills/skill.ruination.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.smite.png` | GPT-6 Astra | Exact copy of `drop-01/A/skill.smite.png`; original imagegen receipt retained | **CC0-1.0** |
| `drop-02/skills/skill.heal.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.shield_spell.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.mend.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.hearten.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.haven.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.rebuke.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.word_of_ruin.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.censure.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.final_word.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.loose.png` | GPT-6 Astra | Built-in imagegen edit of own `skill.bladecraft`; RGB + Lanczos; manifest prompt/receipt | **CC0-1.0** |
| `drop-02/skills/skill.sidestep.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.sprint.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.true_draw.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.snare_shot.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.split_shot.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.arrowfall.png` | GPT-6 Astra | Exact copy of `drop-01/A/skill.arrowfall.png`; original imagegen receipt retained | **CC0-1.0** |
| `drop-02/skills/skill.bladecraft.png` | GPT-6 Astra | Exact copy of `drop-01/A/skill.bladecraft.png`; original imagegen receipt retained | **CC0-1.0** |
| `drop-02/skills/skill.opening.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.parry.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.flourish.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/skills/skill.close_dance.png` | GPT-6 Astra | Built-in imagegen, individual prompt; RGB + Lanczos; manifest receipt | **CC0-1.0** |
| `drop-02/background-crops/ember.png` | GPT-6 Astra / ARTA | Exact crop of `tools/r52_art/arta/drop-01/bg/ember_v3.png` at `94bbadbd`; manifest source/hash | **CC0-1.0** |
| `drop-02/background-crops/rime.png` | GPT-6 Astra / ARTA | Exact crop of `tools/r52_art/arta/drop-01/bg/rime_v1.png` at `94bbadbd`; manifest source/hash | **CC0-1.0** |
| `drop-02/background-crops/bulwark.png` | GPT-6 Astra / ARTA | Exact crop of `tools/r52_art/arta/drop-01/bg/bulwark_v3.png` at `94bbadbd`; manifest source/hash | **CC0-1.0** |
| `drop-02/background-crops/ruin.png` | GPT-6 Astra / ARTA | Exact crop of `tools/r52_art/arta/drop-01/bg/ruin_v1.png` at `94bbadbd`; manifest source/hash | **CC0-1.0** |
| `drop-02/background-crops/mercy.png` | GPT-6 Astra / ARTA | Exact crop of `tools/r52_art/arta/drop-01/bg/mercy_v1.png` at `94bbadbd`; manifest source/hash | **CC0-1.0** |
| `drop-02/background-crops/reckoning.png` | GPT-6 Astra / ARTA | Exact crop of `tools/r52_art/arta/drop-01/bg/reckoning_v1.png` at `94bbadbd`; manifest source/hash | **CC0-1.0** |
| `drop-02/background-crops/quarry.png` | GPT-6 Astra / ARTA | Exact crop of `tools/r52_art/arta/drop-01/bg/quarry_v1.png` at `94bbadbd`; manifest source/hash | **CC0-1.0** |
| `drop-02/background-crops/veil.png` | GPT-6 Astra / ARTA | Exact crop of `tools/r52_art/arta/drop-01/bg/veil_v3.png` at `94bbadbd`; manifest source/hash | **CC0-1.0** |
| `drop-02/sheet-ember.png` | GPT-6 Astra | Pillow composition of the listed CC0 icons and background crops; labels and mock frames | **CC0-1.0** |
| `drop-02/sheet-rime.png` | GPT-6 Astra | Pillow composition of the listed CC0 icons and background crops; labels and mock frames | **CC0-1.0** |
| `drop-02/sheet-bulwark.png` | GPT-6 Astra | Pillow composition of the listed CC0 icons and background crops; labels and mock frames | **CC0-1.0** |
| `drop-02/sheet-ruin.png` | GPT-6 Astra | Pillow composition of the listed CC0 icons and background crops; labels and mock frames | **CC0-1.0** |
| `drop-02/sheet-mercy.png` | GPT-6 Astra | Pillow composition of the listed CC0 icons and background crops; labels and mock frames | **CC0-1.0** |
| `drop-02/sheet-reckoning.png` | GPT-6 Astra | Pillow composition of the listed CC0 icons and background crops; labels and mock frames | **CC0-1.0** |
| `drop-02/sheet-quarry.png` | GPT-6 Astra | Pillow composition of the listed CC0 icons and background crops; labels and mock frames | **CC0-1.0** |
| `drop-02/sheet-veil.png` | GPT-6 Astra | Pillow composition of the listed CC0 icons and background crops; labels and mock frames | **CC0-1.0** |
| `drop-02/hotbars.png` | GPT-6 Astra | Pillow composition of the listed CC0 icons and background crops; labels and mock frames | **CC0-1.0** |

## Pass 1 archive — three style samples

Author: GPT-6 Astra. Date: 2026-10-19. Branch: `r52-artb`.

**Style A / Painted embers selected by the user on 2026-10-19.** The
archived drop contains three alternatives with the same six skills and six
talents in each. Its files and original selection-time receipts are unchanged.

Upgrade classification: **compatible**. This is staged media and its
packaging documentation; no game content, Lua, persistence or shipped
icons change.

## Files

- [Comparison sheet](drop-01/preview.png): all 36 samples at actual 32 px
  and 64 px on both dark and light strips, plus today's Fireball and Smite
  alongside each style; an eight-slot mock hotbar per style uses six
  48 px skill samples and two empty slots.
- [Manifest](drop-01/manifest.json): one asset entry per final icon, with
  key, style, final path and SHA-256, exact prompt, local tool output path
  and source SHA-256, source dimensions/mode and processing receipt.
  Comparison sources and the preview have their own hash records.
- [Style rules](drop-01/STYLE.md): framing, lighting, line weight and
  palette anchors for the eventual set.
- `drop-01/{A,B,C}/skill.<id>.png` and
  `drop-01/{A,B,C}/talent.<node id>.png`: 36 opaque 64 × 64 RGB PNGs.
- [Packaging script](build_drop.py): local image packaging, preview
  rebuilding and a read-only file audit.

The comparison sheet is an offline mockup, not a desktop or web-client
screenshot. Both transform variants are shown together to compare the
artwork; the hotbar is not a proposed character build. View the sheet at
100% to assess native pixel sizes.

## Method and provenance

The motif source is the class redesign's
[node list](../../../docs/planning/class-redesign/node-list.md), with
[Round 52 C6, C9, C11 and D7](../../../docs/planning/round52-class-plan.md).
Today's skill images, the
[Round 18 manifest](../../r18_art/manifest.json),
[art report](../../../docs/research/round18-art-report.md) and
[media notes](../../../mods/PLAYER/grug_abilities/LICENSE-media.md)
were inspected for the existing visual language and packaging method.

All 36 images were made with the built-in `image_gen.imagegen` tool, one
separate prompt and call per final image: 33 fresh generations and three
edits of this drop's own matching Fiery Spark originals to produce Cold
Spark. No third-party image was supplied. The tool's original files remain
at the local output paths recorded in the manifest; all final deliverables
are committed here and need none of those external paths to be viewed or
to rebuild the sheet.

Pillow converts each square original to RGB and downsamples the whole
image to 64 × 64 with `Image.Resampling.LANCZOS`, then saves an optimized
PNG without source metadata. There is no crop, post-generation recoloring,
compositing or sharpening of the final icon files. Cold Spark's elemental
change is a recorded image-generation edit, not a Pillow recolor.
Only the review sheet composites icons, labels, strips and mock slots.

## Rebuild and inspection

Requires Python 3 and Pillow 10.1 or later; the exact packaging version is
recorded per image. From the repository root:

```sh
python3 -I tools/r52_art/artb/build_drop.py
python3 -I tools/r52_art/artb/build_drop.py --check
```

The first command rebuilds the sheet from committed finals and the two
shipped comparison icons, and updates its manifest hash. The second reads
only: it verifies the exact 36-file roster, PNG format, opaque RGB mode,
64 × 64 dimensions, complete prompt/processing fields, and the final,
preview and comparison hashes. If a local final is missing and its
recorded original is still available, `--package` can restore that final;
it never overwrites an existing image.

Author inspection: all 36 final icons and their 32 px and 64 px comparison
rows were visually inspected. The three Spark pairs retain the diagonal
dart family silhouette; Fireball remains round; Arrowfall has four
converging arrows in all variants; each talent has a distinct frame from
the skill images. The file audit passes for 36/36 images. The sample is
ready for the user's style comparison; independent selection and later
desktop/web integration checks remain with the coordinator and user.

No fixtures, Lua checks, engine runs or seed fleet were run, as requested
for this media-only sample. No agents were launched.

## Media

All paths below are relative to this folder. **CC0** means **CC0-1.0**:
the project dedicates any rights it holds in the generated images and
review composition to CC0-1.0, to the extent such rights exist.

| File | Author | Date | Method | License |
|---|---|---|---|---|
| `drop-01/A/skill.fiery_spark.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/skill.cold_spark.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation edit of own matching Fiery Spark; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/skill.fireball.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/skill.smite.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/skill.bladecraft.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/skill.arrowfall.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/talent.f1.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/talent.r10.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/talent.b2.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/talent.m7.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/talent.rk1.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/talent.q2.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/skill.fiery_spark.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/skill.cold_spark.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation edit of own matching Fiery Spark; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/skill.fireball.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/skill.smite.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/skill.bladecraft.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/skill.arrowfall.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/talent.f1.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/talent.r10.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/talent.b2.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/talent.m7.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/talent.rk1.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/talent.q2.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/skill.fiery_spark.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/skill.cold_spark.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation edit of own matching Fiery Spark; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/skill.fireball.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/skill.smite.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/skill.bladecraft.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/skill.arrowfall.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/talent.f1.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/talent.r10.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/talent.b2.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/talent.m7.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/talent.rk1.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/talent.q2.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/preview.png` | GPT-6 Astra; Grudgelands Round 18 art lane (comparison images) | 2026-10-19 | Pillow composition of the listed samples and the project's CC0 Fireball/Smite; labeled strips and mock hotbars | **CC0-1.0** |
