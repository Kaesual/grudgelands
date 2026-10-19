# Round 52 ARTA — art drops

## Drop 04 — the picked overlays under the engine alpha rule

Delivered 2026-10-20 by GPT-6 Astra on `r52-arta`. **Compatible:** staged
art and a Python generator only. This pass reworks exactly the user's
24 family/weapon picks from drop 03 (`94bbadbd`), plus the six picked bow
draw stages: **30 strips** under their final game filenames. The
coordinator's WFX lane integrates them after the user's look. No `mods/`
or Lua changes; no fixtures, engine runs, agents, merge or push.

- [Preview](drop-04/preview.png): one band per class, all 30 strips at
  exactly 8×, labelled active phases, **old left / new right** for each
  comparison. The idle bow shows both silhouettes.
- [Manifest](drop-04/manifest.json): filenames, family, weapon, stage,
  exact source pick and SHA-256, frames, frame length, old/new visible
  pixels and empty frames; preview input hashes and media licences.
- Each PNG has a matching GIF: old/new side by side over every existing
  material and one enchanted example, at exactly 8× and real speed.
  Idle bows show alder, wood and enchanted alder. Draw stages show their
  own sprite and the identical enchanted draw sprite, following the
  existing preview convention documented below.
- [Media checks](drop-04/checks.json): per-frame counts, grip/string
  exclusions, loop seams, contrast observations and exact GIF roundtrips.
- [Generator](arta_fx4.py): Python/Pillow, reading the actual selected
  drop-03 PNGs and reusing the frozen pass-3 geometry, masks and preview
  helpers. All three earlier drops are unchanged.

### Opaque shading and preserved motion

The PNGs contain only alpha **0 or 255**, with zero RGB under transparency.
Both sides of every preview apply the same rule **before** compositing
over the weapon: alpha below 128 disappears, alpha at least 128 becomes
255. The old side reads the actual picked PNG, without palette changes.
No preview uses the old soft alpha blending. GIFs have an exact shared
palette, with no dithering or colour approximation.

The new strips replace soft alpha with explicit colour ramps: dark and
muted family shades beneath brighter crests. Every original motion pixel
retains its position and phase. Small fixed shoulders reinforce Ember's
wand/dagger, Rime's crystal, Bulwark's edges, Reckoning's seal and Quarry's
sword/dagger. These use pixels already visited by the chosen animation.
Veil's dagger had its silver point overwritten by its smoke base at
`(9, 5)`; its fixed silver point now sits on the adjacent blade pixel
`(8, 6)`. That is the only extension of a source strip's total footprint.
There is no rotation, new particle path, grip or string coverage.

Each frame now has **2–7 effect pixels**; quiet phases hold a restrained
coloured mark. Every last frame equals the first frame exactly. The
selected motion, family frame count and frame length remain unchanged.
Visibility below means effect pixels after the alpha test, summed over
all frames of all strips in the family; empty counts use the same frame
instances, including bow draw stages.

| Family | Picked variants | Strips | Frames × seconds | Visible pixels old → new | Empty frames old → new / total |
|---|---|---:|---|---:|---:|
| ember | staff v1, wand v1, dagger v1 | 3 | 8 × 0.12 | 41 → 77 | 6 → 0 / 24 |
| rime | staff v1, wand v1, dagger v1 | 3 | 12 × 0.26 | 76 → 121 | 15 → 0 / 36 |
| mercy | staff v2, wand v1, dagger v1 | 3 | 12 × 0.28 | 48 → 124 | 18 → 0 / 36 |
| reckoning | staff v1, wand v2, dagger v2 | 3 | 12 × 0.16 | 25 → 82 | 27 → 0 / 36 |
| bulwark | sword v2, dagger v1, greataxe v1 | 3 | 12 × 0.18 | 22 → 97 | 21 → 0 / 36 |
| ruin | sword v1, dagger v1, greataxe v1 | 3 | 10 × 0.16 | 57 → 135 | 15 → 0 / 30 |
| quarry | bow and draw0/1/2 v1, sword v1, dagger v1 | 6 | 12 × 0.26 | 82 → 242 | 30 → 0 / 72 |
| veil | bow and draw0/1/2 v1, sword v1, dagger v1 | 6 | 12 × 0.28 | 51 → 272 | 30 → 0 / 72 |
| **Total** | | **30** | | **402 → 1,150** | **162 → 0 / 342** |

### Reproduction and media checks

From the repository root, with Python 3 and Pillow:

```sh
python3 -I tools/r52_art/arta/arta_fx4.py --out /tmp/arta-fx4-rebuild
```

The default output is `drop-04/`. Identical existing bytes are accepted;
different bytes are refused. Output under `mods/` or an earlier drop is
rejected. The same inputs and Pillow reproduce every output byte.

All 30 PNGs and 30 GIFs pass the generator's media checks: dimensions,
binary alpha, pick hashes, unchanged timing, fewer than one third empty
frames in every strip (actually zero), no grip/string intersections,
retained motion pixels, monotone source paths and zero-delta loop seams.
Every GIF is decoded and compared with its exact rendered RGB frames,
including every hold frame, duration and infinite-loop flag. The weakest
frame's strongest channel difference against each material is recorded
as a contrast observation, not a gameplay or accessibility standard.
The class sheet, all animation phases and the wood, Embersteel and
enchanted-material comparisons were visually inspected. A separate
rebuild matches the deliverable byte for byte. Desktop/web appearance
remains for the user's look and WFX's later integration.

### Drop 04 media

All 30 overlay PNGs are original art by **GPT-6 Astra (Grudgelands)**,
dated **2026-10-20**, dedicated to **CC0 1.0 Universal**, to the extent the
project holds rights in them:
<https://creativecommons.org/publicdomain/zero/1.0/>.
The generator is **GPL-3.0-or-later**. `FX4` below means the picked CC0
pass-3 strip reworked by `arta_fx4.py` with opaque RGB shading and the
small fixed marks described above. `composite` means both versions under
the alpha rule, above the source weapon/enchant samples, with labels,
8× nearest-neighbour scaling and an exact GIF palette.

The [existing source credits and provenance](#drop-02-media) apply to the
weapon composites; every input is recorded by path and hash in the new
manifest. No external media are imported. The original overlays remain
CC0; the GIFs and sheet retain the respective weapon-source licences.
Existing attribution is also retained in [CREDITS.md](../../../CREDITS.md).

| File (relative to drop-04) | Author | Source / modifications | Licence |
|---|---|---|---|
| `grug_abilities_fx_ember_staff.png` | GPT-6 Astra (Grudgelands) | FX4: ember, picked v1 | CC0-1.0 |
| `grug_abilities_fx_ember_staff.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-3.0 |
| `grug_abilities_fx_ember_wand.png` | GPT-6 Astra (Grudgelands) | FX4: ember, picked v1 | CC0-1.0 |
| `grug_abilities_fx_ember_wand.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC0-1.0 |
| `grug_abilities_fx_ember_dagger.png` | GPT-6 Astra (Grudgelands) | FX4: ember, picked v1 | CC0-1.0 |
| `grug_abilities_fx_ember_dagger.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-3.0 |
| `grug_abilities_fx_rime_staff.png` | GPT-6 Astra (Grudgelands) | FX4: rime, picked v1 | CC0-1.0 |
| `grug_abilities_fx_rime_staff.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-3.0 |
| `grug_abilities_fx_rime_wand.png` | GPT-6 Astra (Grudgelands) | FX4: rime, picked v1 | CC0-1.0 |
| `grug_abilities_fx_rime_wand.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC0-1.0 |
| `grug_abilities_fx_rime_dagger.png` | GPT-6 Astra (Grudgelands) | FX4: rime, picked v1 | CC0-1.0 |
| `grug_abilities_fx_rime_dagger.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-3.0 |
| `grug_abilities_fx_mercy_staff.png` | GPT-6 Astra (Grudgelands) | FX4: mercy, picked v2 | CC0-1.0 |
| `grug_abilities_fx_mercy_staff.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-3.0 |
| `grug_abilities_fx_mercy_wand.png` | GPT-6 Astra (Grudgelands) | FX4: mercy, picked v1 | CC0-1.0 |
| `grug_abilities_fx_mercy_wand.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC0-1.0 |
| `grug_abilities_fx_mercy_dagger.png` | GPT-6 Astra (Grudgelands) | FX4: mercy, picked v1 | CC0-1.0 |
| `grug_abilities_fx_mercy_dagger.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-3.0 |
| `grug_abilities_fx_reckoning_staff.png` | GPT-6 Astra (Grudgelands) | FX4: reckoning, picked v1 | CC0-1.0 |
| `grug_abilities_fx_reckoning_staff.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-3.0 |
| `grug_abilities_fx_reckoning_wand.png` | GPT-6 Astra (Grudgelands) | FX4: reckoning, picked v2 | CC0-1.0 |
| `grug_abilities_fx_reckoning_wand.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC0-1.0 |
| `grug_abilities_fx_reckoning_dagger.png` | GPT-6 Astra (Grudgelands) | FX4: reckoning, picked v2 | CC0-1.0 |
| `grug_abilities_fx_reckoning_dagger.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-3.0 |
| `grug_abilities_fx_bulwark_sword.png` | GPT-6 Astra (Grudgelands) | FX4: bulwark, picked v2 | CC0-1.0 |
| `grug_abilities_fx_bulwark_sword.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-3.0 |
| `grug_abilities_fx_bulwark_dagger.png` | GPT-6 Astra (Grudgelands) | FX4: bulwark, picked v1 | CC0-1.0 |
| `grug_abilities_fx_bulwark_dagger.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-3.0 |
| `grug_abilities_fx_bulwark_greataxe.png` | GPT-6 Astra (Grudgelands) | FX4: bulwark, picked v1 | CC0-1.0 |
| `grug_abilities_fx_bulwark_greataxe.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC0-1.0 |
| `grug_abilities_fx_ruin_sword.png` | GPT-6 Astra (Grudgelands) | FX4: ruin, picked v1 | CC0-1.0 |
| `grug_abilities_fx_ruin_sword.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-3.0 |
| `grug_abilities_fx_ruin_dagger.png` | GPT-6 Astra (Grudgelands) | FX4: ruin, picked v1 | CC0-1.0 |
| `grug_abilities_fx_ruin_dagger.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-3.0 |
| `grug_abilities_fx_ruin_greataxe.png` | GPT-6 Astra (Grudgelands) | FX4: ruin, picked v1 | CC0-1.0 |
| `grug_abilities_fx_ruin_greataxe.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC0-1.0 |
| `grug_abilities_fx_quarry_bow.png` | GPT-6 Astra (Grudgelands) | FX4: quarry, picked v1 | CC0-1.0 |
| `grug_abilities_fx_quarry_bow.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-3.0 |
| `grug_abilities_fx_quarry_bow_draw0.png` | GPT-6 Astra (Grudgelands) | FX4: quarry, picked v1 | CC0-1.0 |
| `grug_abilities_fx_quarry_bow_draw0.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-4.0 |
| `grug_abilities_fx_quarry_bow_draw1.png` | GPT-6 Astra (Grudgelands) | FX4: quarry, picked v1 | CC0-1.0 |
| `grug_abilities_fx_quarry_bow_draw1.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-4.0 |
| `grug_abilities_fx_quarry_bow_draw2.png` | GPT-6 Astra (Grudgelands) | FX4: quarry, picked v1 | CC0-1.0 |
| `grug_abilities_fx_quarry_bow_draw2.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-4.0 |
| `grug_abilities_fx_quarry_sword.png` | GPT-6 Astra (Grudgelands) | FX4: quarry, picked v1 | CC0-1.0 |
| `grug_abilities_fx_quarry_sword.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-3.0 |
| `grug_abilities_fx_quarry_dagger.png` | GPT-6 Astra (Grudgelands) | FX4: quarry, picked v1 | CC0-1.0 |
| `grug_abilities_fx_quarry_dagger.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-3.0 |
| `grug_abilities_fx_veil_bow.png` | GPT-6 Astra (Grudgelands) | FX4: veil, picked v1 | CC0-1.0 |
| `grug_abilities_fx_veil_bow.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-3.0 |
| `grug_abilities_fx_veil_bow_draw0.png` | GPT-6 Astra (Grudgelands) | FX4: veil, picked v1 | CC0-1.0 |
| `grug_abilities_fx_veil_bow_draw0.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-4.0 |
| `grug_abilities_fx_veil_bow_draw1.png` | GPT-6 Astra (Grudgelands) | FX4: veil, picked v1 | CC0-1.0 |
| `grug_abilities_fx_veil_bow_draw1.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-4.0 |
| `grug_abilities_fx_veil_bow_draw2.png` | GPT-6 Astra (Grudgelands) | FX4: veil, picked v1 | CC0-1.0 |
| `grug_abilities_fx_veil_bow_draw2.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-4.0 |
| `grug_abilities_fx_veil_sword.png` | GPT-6 Astra (Grudgelands) | FX4: veil, picked v1 | CC0-1.0 |
| `grug_abilities_fx_veil_sword.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-3.0 |
| `grug_abilities_fx_veil_dagger.png` | GPT-6 Astra (Grudgelands) | FX4: veil, picked v1 | CC0-1.0 |
| `grug_abilities_fx_veil_dagger.gif` | GPT-6 Astra; weapon authors | FX4 composite; source credits below | CC-BY-SA-3.0 |
| `preview.png` | GPT-6 Astra; weapon authors | Labelled FX4 old/new contact sheet; source credits below | CC-BY-SA-4.0 |

## Drop 03 — one overlay family per talent tree

Delivered 2026-10-19 by GPT-6 Astra on `r52-arta`. **Compatible:** staged
art proposals and their Python generator only. This pass follows the user's
eight-family ruling and the pass-2 feedback: small accents, distinct tree
language, slower frost and Scout effects, and no rotation or swirling.
The coordinator owns the pick page and integration; these proposals await
the user's picks. No Lua or `mods/` changes, fixtures, engine runs, agents,
merge or push. Both earlier drop folders are unchanged.

**Count clarification:** the brief's table specifies 24 family/weapon
combinations. With two variants and the additional three draw stages for
each of two bow families, that is **60 strips**, not the stated 52:
22 non-bow strips + 8 bow strips per variant. The smaller total would omit
the Scout's sword and dagger combinations. This drop follows the full
table, keeping all of them.

- [Preview](drop-03/preview.png): frame 1 at exactly 8×, one class band,
  one family row and three weapon columns; variants sit side by side.
  Bow idle and draw stages occupy four subcells in the bow column; idle
  shows both silhouettes. Every selection key and each family's clock
  are labelled. The first frame is intentionally quiet: use the GIFs to
  judge the motion and pauses.
- [Manifest](drop-03/manifest.json): 60 unique records with class, family,
  weapon, stage, variant, path, SHA-256, frame count, `frame_s` and
  `loop_s`. It also records the GIF paths, source image hashes, exact
  licences, enchant samples and generator hash. Paths are relative to
  the drop; source/code paths are relative to the repository. Stages use
  `null` for non-bows, `idle`, or `draw0` / `draw1` / `draw2`.
- [Media checks](drop-03/checks.json): dimensions, alpha, per-frame effect
  coverage, exclusion checks, seam deltas, encoded GIF frames and timing.
- [Generator](arta_fx3.py): standalone Python/Pillow; explicit original
  pixel geometry and open motion paths. No weapon pixels enter the
  overlay PNGs. The weapon files are read only for previews.

| Class | Families | Non-bow strips | Bow strips | Total |
|---|---|---:|---:|---:|
| Mage | ember, rime | 12 | 0 | 12 |
| Warrior | bulwark, ruin | 12 | 0 | 12 |
| Priest | mercy, reckoning | 12 | 0 | 12 |
| Scout | quarry, veil | 8 | 16 | 24 |
| **Total** | | **44** | **16** | **60** |

### Family clocks and motion

Every family shares **one frame count and frame length** across both
variants, all weapons and all bow stages. Strips are RGBA,
**16 × (16 × F)**, with alpha **0, 96, 176, 255** and zero RGB under zero
alpha. Each frame has only **1–7 effect pixels**. Stationary marks vary in
brightness or grow in place; free particles rise along open monotone paths,
fade out and restart only after a pause. Nothing orbits or reverses its path.
Last and first frames are identical quiet states, giving every strip an
exact zero-delta loop seam; repeated frames deliberately hold still.

| Family | F | Frame length | Loop | Motion | Variant 1 / Variant 2 |
|---|---:|---:|---:|---|---|
| ember | 8 | 0.12 s | 0.96 s | Small rising flame and warm spark. | Candle tongue / Split cinder |
| rime | 12 | 0.26 s | 3.12 s | A crystal forms, holds its glint and fades with cold mist. | Growing frost fern / Held crystal |
| bulwark | 12 | 0.18 s | 2.16 s | A short silver-blue glint slides along the edge, then rests. | Measured edge / Rivet glint |
| ruin | 10 | 0.16 s | 1.60 s | A fixed red-hot edge gives a double heartbeat; one ember rises. | Hot cutting edge / Tempered fracture |
| mercy | 12 | 0.28 s | 3.36 s | Soft gold-white breathing with one rising mote. | Quiet blessing / Sheltered light |
| reckoning | 12 | 0.16 s | 1.92 s | A hard gold-white beat and brief crimson point, then stillness. | White verdict / Golden seal |
| quarry | 12 | 0.26 s | 3.12 s | A short teal breeze or one green leaf drifts away and rests. | Passing breeze / Single leaf |
| veil | 12 | 0.28 s | 3.36 s | A thin violet-black wisp rises beside a fixed silver glint. | Fine smoke / Silver in shadow |

### Weapon compositions and previews

| Weapon | Composition |
|---|---|
| Sword | A diagonal rail follows the upper cutting edge; the alternate variant isolates the tip and a separate adjacent accent. |
| Dagger | A compact point and shoulder form a small fang or crystal, with room above the short blade for a mote; it is not a shortened sword strip. |
| Greataxe | Separate, simultaneous accents follow the two cutting edges, with the main glint on the upper bit and a smaller echo on the lower bit. |
| Staff | The head receives a small crown or fork; rising light uses the head's flanks because the crystal already touches the image's upper boundary. |
| Wand | One compact cap accent or short tongue sits on the tip, with one neighbouring spark and no shaft treatment. |
| Bow | Variant 1 uses the upper limb, variant 2 the lower limb; the opposite limb has a tiny supporting mark, and draw stages add a point on the arrow's forward end. |

Each matching GIF is enlarged by nearest-neighbour scaling at exactly 8×,
loops forever, and encodes all F frames at the family's real frame length.
A small frame counter preserves individually encoded hold frames and makes
the pauses inspectable. A shared palette prevents palette flicker.

Non-bow GIFs show every existing material sprite: bronze, iron, steel,
silversteel, embersteel and abyssal steel, plus wood for the staff, then an
enchanted iron sample. No stone weapon sprites exist. The two groups of
each enchant mask are static affix masks: Strength + Crit for sword/axe,
Intelligence + Mana for dagger/staff/wand, at the shipped 128 opacity.
Idle bows show both requested silhouettes, alder and wood, plus enchanted
alder with Dexterity + Crit. Every draw GIF shows its actual stage sprite
and the same sprite labelled `enchanted (same)`: the runtime explicitly
removes affix masks during drawing
([source](../../../mods/PLAYER/grug_abilities/scout.lua)), so no artificial
draw-stage enchant mask is invented. The effect is composited above each
weapon/enchant sample.

### Reproduction and validation

From the repository root, with Python 3 and Pillow:

```sh
python3 -I tools/r52_art/arta/arta_fx3.py --out /tmp/arta-fx3-rebuild
```

The default output is `drop-03/`. Identical existing bytes are accepted;
different bytes are refused. The generator explicitly rejects output into
`mods/`, `drop-01/` and `drop-02/`, including nested paths. It uses no
network, image-generation service, random input, Lua or game execution.
The same inputs and Pillow produce the same output.

The completed media checks pass for all 60 strips: correct sizes and alpha,
unique keys and PNG hashes, common timing per family, zero grip/string
intersections in every frame, and an exact last-to-first hold. The exclusion
regions are the independently traced pass-2 grip/string maps, inspected
against the actual source silhouettes; they validate the art and never
clip it into compliance. Free-particle paths are checked for monotone
coordinates. GIFs are decoded again to confirm every frame's displayed
pixels, duration and infinite loop. All family/weapon phase sheets,
preview labels and the material/enchant composites were visually inspected.
Desktop/web acceptance remains the user's pick and later runtime check.

### Drop 03 media

All 60 overlay PNGs are original art by **GPT-6 Astra (Grudgelands)**,
dated **2026-10-19**, dedicated to **CC0 1.0 Universal**, to the extent the
project holds rights in them:
<https://creativecommons.org/publicdomain/zero/1.0/>.
The generator is **GPL-3.0-or-later**. `FX3` below means the original pixel
coordinates and motion in `arta_fx3.py`; `composite` means alpha layering,
8× nearest-neighbour scaling, checker background, labels and GIF palette.

The [source credits and full provenance below](#drop-02-media) also apply
to this drop; per-file source paths and hashes are in the manifest. No new
external media are imported. Sword, dagger, staff and idle-bow GIFs retain
**CC BY-SA 3.0**; wand/greataxe GIFs are **CC0 1.0**; draw-stage GIFs retain
**CC BY-SA 4.0**. The mixed preview is a **CC BY-SA 4.0 adaptation**.
The original CC0 overlays remain separately available. Existing weapon
authors and attribution remain in [CREDITS.md](../../../CREDITS.md).

| File (relative to drop-03) | Author | Source / modifications | Licence |
|---|---|---|---|
| `fx/mage/ember_staff_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Candle tongue | CC0-1.0 |
| `fx/mage/ember_staff_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/mage/ember_staff_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Split cinder | CC0-1.0 |
| `fx/mage/ember_staff_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/mage/ember_wand_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Candle tongue | CC0-1.0 |
| `fx/mage/ember_wand_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC0-1.0 |
| `fx/mage/ember_wand_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Split cinder | CC0-1.0 |
| `fx/mage/ember_wand_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC0-1.0 |
| `fx/mage/ember_dagger_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Candle tongue | CC0-1.0 |
| `fx/mage/ember_dagger_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/mage/ember_dagger_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Split cinder | CC0-1.0 |
| `fx/mage/ember_dagger_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/mage/rime_staff_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Growing frost fern | CC0-1.0 |
| `fx/mage/rime_staff_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/mage/rime_staff_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Held crystal | CC0-1.0 |
| `fx/mage/rime_staff_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/mage/rime_wand_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Growing frost fern | CC0-1.0 |
| `fx/mage/rime_wand_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC0-1.0 |
| `fx/mage/rime_wand_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Held crystal | CC0-1.0 |
| `fx/mage/rime_wand_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC0-1.0 |
| `fx/mage/rime_dagger_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Growing frost fern | CC0-1.0 |
| `fx/mage/rime_dagger_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/mage/rime_dagger_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Held crystal | CC0-1.0 |
| `fx/mage/rime_dagger_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/warrior/bulwark_sword_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Measured edge | CC0-1.0 |
| `fx/warrior/bulwark_sword_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/warrior/bulwark_sword_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Rivet glint | CC0-1.0 |
| `fx/warrior/bulwark_sword_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/warrior/bulwark_dagger_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Measured edge | CC0-1.0 |
| `fx/warrior/bulwark_dagger_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/warrior/bulwark_dagger_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Rivet glint | CC0-1.0 |
| `fx/warrior/bulwark_dagger_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/warrior/bulwark_greataxe_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Measured edge | CC0-1.0 |
| `fx/warrior/bulwark_greataxe_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC0-1.0 |
| `fx/warrior/bulwark_greataxe_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Rivet glint | CC0-1.0 |
| `fx/warrior/bulwark_greataxe_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC0-1.0 |
| `fx/warrior/ruin_sword_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Hot cutting edge | CC0-1.0 |
| `fx/warrior/ruin_sword_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/warrior/ruin_sword_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Tempered fracture | CC0-1.0 |
| `fx/warrior/ruin_sword_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/warrior/ruin_dagger_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Hot cutting edge | CC0-1.0 |
| `fx/warrior/ruin_dagger_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/warrior/ruin_dagger_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Tempered fracture | CC0-1.0 |
| `fx/warrior/ruin_dagger_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/warrior/ruin_greataxe_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Hot cutting edge | CC0-1.0 |
| `fx/warrior/ruin_greataxe_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC0-1.0 |
| `fx/warrior/ruin_greataxe_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Tempered fracture | CC0-1.0 |
| `fx/warrior/ruin_greataxe_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC0-1.0 |
| `fx/priest/mercy_staff_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Quiet blessing | CC0-1.0 |
| `fx/priest/mercy_staff_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/priest/mercy_staff_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Sheltered light | CC0-1.0 |
| `fx/priest/mercy_staff_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/priest/mercy_wand_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Quiet blessing | CC0-1.0 |
| `fx/priest/mercy_wand_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC0-1.0 |
| `fx/priest/mercy_wand_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Sheltered light | CC0-1.0 |
| `fx/priest/mercy_wand_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC0-1.0 |
| `fx/priest/mercy_dagger_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Quiet blessing | CC0-1.0 |
| `fx/priest/mercy_dagger_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/priest/mercy_dagger_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Sheltered light | CC0-1.0 |
| `fx/priest/mercy_dagger_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/priest/reckoning_staff_v1.png` | GPT-6 Astra (Grudgelands) | FX3: White verdict | CC0-1.0 |
| `fx/priest/reckoning_staff_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/priest/reckoning_staff_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Golden seal | CC0-1.0 |
| `fx/priest/reckoning_staff_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/priest/reckoning_wand_v1.png` | GPT-6 Astra (Grudgelands) | FX3: White verdict | CC0-1.0 |
| `fx/priest/reckoning_wand_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC0-1.0 |
| `fx/priest/reckoning_wand_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Golden seal | CC0-1.0 |
| `fx/priest/reckoning_wand_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC0-1.0 |
| `fx/priest/reckoning_dagger_v1.png` | GPT-6 Astra (Grudgelands) | FX3: White verdict | CC0-1.0 |
| `fx/priest/reckoning_dagger_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/priest/reckoning_dagger_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Golden seal | CC0-1.0 |
| `fx/priest/reckoning_dagger_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/scout/quarry_bow_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Passing breeze | CC0-1.0 |
| `fx/scout/quarry_bow_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/scout/quarry_bow_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Single leaf | CC0-1.0 |
| `fx/scout/quarry_bow_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/scout/quarry_bow_draw0_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Passing breeze | CC0-1.0 |
| `fx/scout/quarry_bow_draw0_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-4.0 |
| `fx/scout/quarry_bow_draw0_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Single leaf | CC0-1.0 |
| `fx/scout/quarry_bow_draw0_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-4.0 |
| `fx/scout/quarry_bow_draw1_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Passing breeze | CC0-1.0 |
| `fx/scout/quarry_bow_draw1_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-4.0 |
| `fx/scout/quarry_bow_draw1_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Single leaf | CC0-1.0 |
| `fx/scout/quarry_bow_draw1_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-4.0 |
| `fx/scout/quarry_bow_draw2_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Passing breeze | CC0-1.0 |
| `fx/scout/quarry_bow_draw2_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-4.0 |
| `fx/scout/quarry_bow_draw2_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Single leaf | CC0-1.0 |
| `fx/scout/quarry_bow_draw2_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-4.0 |
| `fx/scout/quarry_sword_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Passing breeze | CC0-1.0 |
| `fx/scout/quarry_sword_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/scout/quarry_sword_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Single leaf | CC0-1.0 |
| `fx/scout/quarry_sword_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/scout/quarry_dagger_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Passing breeze | CC0-1.0 |
| `fx/scout/quarry_dagger_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/scout/quarry_dagger_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Single leaf | CC0-1.0 |
| `fx/scout/quarry_dagger_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/scout/veil_bow_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Fine smoke | CC0-1.0 |
| `fx/scout/veil_bow_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/scout/veil_bow_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Silver in shadow | CC0-1.0 |
| `fx/scout/veil_bow_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/scout/veil_bow_draw0_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Fine smoke | CC0-1.0 |
| `fx/scout/veil_bow_draw0_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-4.0 |
| `fx/scout/veil_bow_draw0_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Silver in shadow | CC0-1.0 |
| `fx/scout/veil_bow_draw0_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-4.0 |
| `fx/scout/veil_bow_draw1_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Fine smoke | CC0-1.0 |
| `fx/scout/veil_bow_draw1_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-4.0 |
| `fx/scout/veil_bow_draw1_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Silver in shadow | CC0-1.0 |
| `fx/scout/veil_bow_draw1_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-4.0 |
| `fx/scout/veil_bow_draw2_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Fine smoke | CC0-1.0 |
| `fx/scout/veil_bow_draw2_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-4.0 |
| `fx/scout/veil_bow_draw2_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Silver in shadow | CC0-1.0 |
| `fx/scout/veil_bow_draw2_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-4.0 |
| `fx/scout/veil_sword_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Fine smoke | CC0-1.0 |
| `fx/scout/veil_sword_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/scout/veil_sword_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Silver in shadow | CC0-1.0 |
| `fx/scout/veil_sword_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/scout/veil_dagger_v1.png` | GPT-6 Astra (Grudgelands) | FX3: Fine smoke | CC0-1.0 |
| `fx/scout/veil_dagger_v1.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `fx/scout/veil_dagger_v2.png` | GPT-6 Astra (Grudgelands) | FX3: Silver in shadow | CC0-1.0 |
| `fx/scout/veil_dagger_v2.gif` | GPT-6 Astra; weapon authors | FX3 composite; source credits below | CC-BY-SA-3.0 |
| `preview.png` | GPT-6 Astra; weapon authors | Labelled FX3 contact sheet; source credits below | CC-BY-SA-4.0 |

## Drop 02 — class and weapon overlays

Delivered 2026-10-19 by GPT-6 Astra on `r52-arta`. **Compatible:** staged
art proposals and their Python generator only; no runtime, Lua, saved-state
or `mods/` changes. The user picked the drop-01 tree backgrounds, but did
not pick its universal overlays. This pass follows the user's request for
class-specific and weapon-specific effects; `drop-01/` is unchanged.
The coordinator owns the pick page and later integration; these proposals
still await the user's picks.

- [Preview](drop-02/preview.png): frame 1 at exactly 8×, four class bands,
  one row per family and three permitted weapon columns per class. Variants
  are side by side, with their full selection keys. The bow column contains
  idle plus three draw-stage subcells within each family row; idle shows
  both silhouettes. Other columns show iron; their GIFs show every material.
- [Manifest](drop-02/manifest.json): **48 unique strip records**, each with
  key, class, family, weapon, stage, variant, path, SHA-256, frames and loop
  duration. Each record's `gif` object identifies the matching preview and
  its source images, hashes, licence and enchant sample. Paths are relative
  to the drop; source and generator paths are relative to the repository.
  `stage` is `null` for non-bows, `"idle"` or `"draw0"`/`"draw1"`/`"draw2"`
  for bows. Draw keys use `.bow.draw<n>.v<n>`.
- [Checks](drop-02/checks.json): media checks and observations for each of
  the 48 strips, including frame coverage, loop transitions and GIF timing.
- [Generator](arta_fx2.py): explicit original pixel coordinates and cyclic
  motion, Python/Pillow, with no copied weapon pixels in the overlay PNGs.

| Class | Families | Allowed weapons | Non-bow strips | Bow strips | Total |
|---|---|---|---:|---:|---:|
| Warrior | rage | sword, dagger, greataxe | 6 | 0 | 6 |
| Scout | wild, shadow | bow, sword, dagger | 8 | 16 | 24 |
| Mage | fire, frost | staff, wand, dagger | 12 | 0 | 12 |
| Priest | holy | staff, wand, dagger | 6 | 0 | 6 |
| **Total** | | | **32** | **16** | **48** |

### Animation and placement

Every strip has **8 vertical 16 × 16 frames**, **16 × 128 RGBA**, with a
**0.96 s** loop (**120 ms per frame**). All GIFs also encode exactly eight
120 ms frames and loop forever. Alpha levels are **0, 96, 176, 255**;
transparent pixels have zero RGB. Each phase has **4–15** visible effect
pixels. Palette values, geometry and motion are authored in the generator;
the weapon remains readable through the sparse, mostly translucent effect.

| Weapon | Placement |
|---|---|
| Sword | Along the upper blade toward its tip, with small nearby embers or motes; the guard and grip stay clear. |
| Dagger | A short stroke on the last few blade pixels and a compact tip effect, adapted to the shorter silhouette. |
| Greataxe | Two independently phased strokes follow the left-upper and right-lower cutting edges; no glow on the haft. |
| Staff | Around the top head/crystal, with at most a one-pixel descent beside the head; flames lick up its left flank because the head already reaches the top image border. |
| Wand | A small cluster on the tip, leaving the long lower grip and shaft clear. |
| Bow | Upper and lower limbs; draw stages also carry an effect on the arrow's forward end/arrowhead. The idle strip fits both silhouettes and contains no invented arrow. Each draw stage has its own placement, leaving all strings and central grips clear. |

| Family | Variant 1 | Variant 2 |
|---|---|---|
| rage | Ember edge: crimson edge glow with red embers. | Heartbeat embers: a concentrated pulse with a short ember trail. |
| wild | Wind and leaf: longer teal streaks with a small green leaf. | Turning leaves: shorter wind strokes and two drifting leaf accents. |
| shadow | Smoke ribbon: violet-black edge smoke with a faint silver glint. | Silver curls: a smaller edge stroke with a fuller curling smoke cluster. |
| fire | Flame tongues: two orange-red tongues and one warm spark. | Banked sparks: shorter flames, two sparks and a pulsing base. |
| frost | Creeping rime: pale-blue edge rime with staggered ice glints. | Crystal motes: rime with a small travelling ice cluster. |
| holy | Quiet radiance: gold-white motes over a soft pulsing edge. | Orbiting motes: three staggered motes around the head or tip. |

All material sprites, both groups of every `_ench.png`, the idle bows and
all three draw sprites were inspected. Non-bow GIFs show bronze, iron, steel,
silversteel, embersteel and abyssal steel side by side, plus the wooden staff
where it exists, followed by one enchanted iron example. No stone weapon
sprites exist here. The two-frame `_ench.png` files are **static affix masks**,
not two alternate full weapon images: both groups are tinted at the shipped
128 opacity over the base. Sword/greataxe show Strength + Crit; dagger,
staff and wand show Intelligence + Mana, valid affixes from the shipped
pools. This preserves the underlying silhouette. The element animation is
then composited above that enchanted example.

### Reproduction and checks

From the repository root, with Python 3 and Pillow:

```sh
python3 -I tools/r52_art/arta/arta_fx2.py --out /tmp/arta-fx2-rebuild
```

The default output is `drop-02/`. The script accepts identical existing
outputs but refuses different bytes, and explicitly refuses `drop-01/`.
All media and metadata are deterministic with the same inputs/Pillow.
No image-generation service, network input or Lua execution is needed.

The completed set was checked for dimensions, RGBA/alpha, eight frames,
GIF timing, 48 unique keys and the loop seam. Independent hand-traced grip
and string exclusion maps check every effect pixel in every phase; they
never clip a misplaced effect into compliance. Every loop is cyclic, with
no duplicated terminal frame; the last-to-first transition is no larger
than the largest internal transition in premultiplied RGB plus alpha.
Family/variant phase origins choose a quiet common transition across that
family's weapon types. The eight phases, loop boundary, class contact sheet
and all-material composites were also visually inspected. No fixtures or
engine runs, as requested; desktop/web acceptance stays with the user.

### Drop 02 media

All 48 new overlay PNGs are original art by **GPT-6 Astra (Grudgelands)**,
dated **2026-10-19**, dedicated to **CC0 1.0 Universal**, to the extent the
project holds rights in them:
<https://creativecommons.org/publicdomain/zero/1.0/>.
The generator is **GPL-3.0-or-later**. The per-file table below uses `FX2`
for original pixel geometry and eight-phase motion in `arta_fx2.py`;
`composite` means alpha layering over the credited sources, nearest-neighbour
8× scaling, checker background, labels and a fixed palette for each GIF.

Source credits are provenance, not design references:

- Sword, dagger and staff: the weapon-ladder derivations of
  **minetest_game contributors**, © 2010–2023, **CC BY-SA 3.0 Unported**;
  the full contributor attribution and source links are retained in the
  drop-01 media section below and [the source licence](../../../mods/BASE/default/license.txt).
  All six materials, the wooden staff and the derived enchant masks keep
  [their weapon provenance](../../../mods/ITEMS/grug_gear/LICENSE-media.md).
- Greataxe and wand: **Grudgelands**, original Round 12 pixel geometry,
  **CC0 1.0**, including their derived masks;
  [generator](../../r12_art/build_assets.py) and
  [media record](../../../mods/ITEMS/grug_gear/LICENSE-media.md#round-12-wand-and-greataxe-replacement--cc0-10).
- Idle alder and wood bows: **Lord of the Test contributors**,
  **CC BY-SA 3.0**, unchanged source sprites
  `lottthrowing_bow_wood_alder.png` and `lottthrowing_bow_wood.png`, from
  commit `f164140154945f0b356521ae721a86e9c7a0e0cf`;
  [source repository](https://github.com/minetest-LOTR/Lord-of-the-Test),
  [local provenance](../../../mods/ITEMS/grug_gear/LICENSE-media.md#round-11-bows-and-shields--cc-by-sa-30)
  and [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/).
- Bow draw 0–2: **XSSheep / Pixel Perfection and VoxeLibre contributors**,
  **CC BY-SA 4.0**, renamed `mcl_bows_bow_0.png` through `_2.png` from
  commit `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`;
  [source licence](https://git.minetest.land/VoxeLibre/VoxeLibre/src/commit/c2dbc520ff4e1637072d33b06c3a2404e0f08df7/LEGAL.md),
  [local provenance](../../../mods/PLAYER/grug_abilities/LICENSE-media.md#bow-draw-stages--cc-by-sa-40)
  and [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

Composites of sword/dagger/staff/bow, and the mixed `preview.png`, are
**CC BY-SA 4.0 adaptations**; their new overlay layers remain separately
available as CC0. Wand/greataxe-only GIFs are wholly **CC0** because those
source weapons are CC0. `Weapon authors` below means the credits above;
existing attribution remains in [CREDITS.md](../../../CREDITS.md).

| File (relative to drop-02) | Author | Date | Method | Licence | Bytes |
|---|---|---|---|---|---:|
| `fx/warrior/rage_sword_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Ember edge | CC0-1.0 | 196 |
| `fx/warrior/rage_sword_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 128879 |
| `fx/warrior/rage_sword_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Heartbeat embers | CC0-1.0 | 215 |
| `fx/warrior/rage_sword_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 129425 |
| `fx/warrior/rage_dagger_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Ember edge | CC0-1.0 | 218 |
| `fx/warrior/rage_dagger_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 117516 |
| `fx/warrior/rage_dagger_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Heartbeat embers | CC0-1.0 | 257 |
| `fx/warrior/rage_dagger_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 117996 |
| `fx/warrior/rage_greataxe_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Ember edge | CC0-1.0 | 336 |
| `fx/warrior/rage_greataxe_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC0-1.0 | 124040 |
| `fx/warrior/rage_greataxe_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Heartbeat embers | CC0-1.0 | 337 |
| `fx/warrior/rage_greataxe_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC0-1.0 | 123641 |
| `fx/scout/wild_bow_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Wind and leaf | CC0-1.0 | 283 |
| `fx/scout/wild_bow_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 57702 |
| `fx/scout/wild_bow_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Turning leaves | CC0-1.0 | 320 |
| `fx/scout/wild_bow_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 57923 |
| `fx/scout/wild_bow_draw0_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Wind and leaf | CC0-1.0 | 369 |
| `fx/scout/wild_bow_draw0_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 40777 |
| `fx/scout/wild_bow_draw0_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Turning leaves | CC0-1.0 | 386 |
| `fx/scout/wild_bow_draw0_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 41016 |
| `fx/scout/wild_bow_draw1_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Wind and leaf | CC0-1.0 | 388 |
| `fx/scout/wild_bow_draw1_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 40396 |
| `fx/scout/wild_bow_draw1_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Turning leaves | CC0-1.0 | 387 |
| `fx/scout/wild_bow_draw1_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 40515 |
| `fx/scout/wild_bow_draw2_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Wind and leaf | CC0-1.0 | 420 |
| `fx/scout/wild_bow_draw2_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 40751 |
| `fx/scout/wild_bow_draw2_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Turning leaves | CC0-1.0 | 390 |
| `fx/scout/wild_bow_draw2_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 41005 |
| `fx/scout/wild_sword_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Wind and leaf | CC0-1.0 | 219 |
| `fx/scout/wild_sword_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 129114 |
| `fx/scout/wild_sword_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Turning leaves | CC0-1.0 | 222 |
| `fx/scout/wild_sword_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 129737 |
| `fx/scout/wild_dagger_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Wind and leaf | CC0-1.0 | 276 |
| `fx/scout/wild_dagger_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 118492 |
| `fx/scout/wild_dagger_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Turning leaves | CC0-1.0 | 289 |
| `fx/scout/wild_dagger_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 118678 |
| `fx/scout/shadow_bow_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Smoke ribbon | CC0-1.0 | 243 |
| `fx/scout/shadow_bow_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 58604 |
| `fx/scout/shadow_bow_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Silver curls | CC0-1.0 | 281 |
| `fx/scout/shadow_bow_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 58215 |
| `fx/scout/shadow_bow_draw0_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Smoke ribbon | CC0-1.0 | 379 |
| `fx/scout/shadow_bow_draw0_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 41288 |
| `fx/scout/shadow_bow_draw0_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Silver curls | CC0-1.0 | 415 |
| `fx/scout/shadow_bow_draw0_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 41068 |
| `fx/scout/shadow_bow_draw1_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Smoke ribbon | CC0-1.0 | 379 |
| `fx/scout/shadow_bow_draw1_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 40802 |
| `fx/scout/shadow_bow_draw1_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Silver curls | CC0-1.0 | 458 |
| `fx/scout/shadow_bow_draw1_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 40681 |
| `fx/scout/shadow_bow_draw2_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Smoke ribbon | CC0-1.0 | 419 |
| `fx/scout/shadow_bow_draw2_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 41302 |
| `fx/scout/shadow_bow_draw2_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Silver curls | CC0-1.0 | 495 |
| `fx/scout/shadow_bow_draw2_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 41071 |
| `fx/scout/shadow_sword_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Smoke ribbon | CC0-1.0 | 222 |
| `fx/scout/shadow_sword_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 129655 |
| `fx/scout/shadow_sword_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Silver curls | CC0-1.0 | 234 |
| `fx/scout/shadow_sword_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 129930 |
| `fx/scout/shadow_dagger_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Smoke ribbon | CC0-1.0 | 262 |
| `fx/scout/shadow_dagger_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 118976 |
| `fx/scout/shadow_dagger_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Silver curls | CC0-1.0 | 296 |
| `fx/scout/shadow_dagger_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 118492 |
| `fx/mage/fire_staff_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Flame tongues | CC0-1.0 | 220 |
| `fx/mage/fire_staff_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 117539 |
| `fx/mage/fire_staff_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Banked sparks | CC0-1.0 | 252 |
| `fx/mage/fire_staff_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 117333 |
| `fx/mage/fire_wand_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Flame tongues | CC0-1.0 | 256 |
| `fx/mage/fire_wand_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC0-1.0 | 111691 |
| `fx/mage/fire_wand_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Banked sparks | CC0-1.0 | 285 |
| `fx/mage/fire_wand_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC0-1.0 | 111977 |
| `fx/mage/fire_dagger_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Flame tongues | CC0-1.0 | 245 |
| `fx/mage/fire_dagger_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 119228 |
| `fx/mage/fire_dagger_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Banked sparks | CC0-1.0 | 288 |
| `fx/mage/fire_dagger_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 119210 |
| `fx/mage/frost_staff_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Creeping rime | CC0-1.0 | 216 |
| `fx/mage/frost_staff_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 115713 |
| `fx/mage/frost_staff_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Crystal motes | CC0-1.0 | 272 |
| `fx/mage/frost_staff_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 116960 |
| `fx/mage/frost_wand_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Creeping rime | CC0-1.0 | 204 |
| `fx/mage/frost_wand_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC0-1.0 | 110232 |
| `fx/mage/frost_wand_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Crystal motes | CC0-1.0 | 294 |
| `fx/mage/frost_wand_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC0-1.0 | 111862 |
| `fx/mage/frost_dagger_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Creeping rime | CC0-1.0 | 200 |
| `fx/mage/frost_dagger_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 117358 |
| `fx/mage/frost_dagger_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Crystal motes | CC0-1.0 | 312 |
| `fx/mage/frost_dagger_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 118959 |
| `fx/priest/holy_staff_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Quiet radiance | CC0-1.0 | 266 |
| `fx/priest/holy_staff_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 116592 |
| `fx/priest/holy_staff_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Orbiting motes | CC0-1.0 | 282 |
| `fx/priest/holy_staff_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 117057 |
| `fx/priest/holy_wand_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Quiet radiance | CC0-1.0 | 225 |
| `fx/priest/holy_wand_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC0-1.0 | 111447 |
| `fx/priest/holy_wand_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Orbiting motes | CC0-1.0 | 254 |
| `fx/priest/holy_wand_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC0-1.0 | 112226 |
| `fx/priest/holy_dagger_v1.png` | GPT-6 Astra | 2026-10-19 | FX2; Quiet radiance | CC0-1.0 | 253 |
| `fx/priest/holy_dagger_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 118684 |
| `fx/priest/holy_dagger_v2.png` | GPT-6 Astra | 2026-10-19 | FX2; Orbiting motes | CC0-1.0 | 272 |
| `fx/priest/holy_dagger_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 composite | CC-BY-SA-4.0 | 119511 |
| `preview.png` | GPT-6 Astra; weapon authors | 2026-10-19 | FX2 class contact sheet | CC-BY-SA-4.0 | 76988 |

## Drop 01 — original delivery record

Delivered 2026-10-19 by GPT-6 Astra on `r52-arta`. **Compatible**: art
candidates and authoring tools only; no game behaviour, Lua, saved state or
`mods/` changes. No files are picked yet. The coordinator builds the selection
page; GRAPH and WFX take only the user's later picks. A later art revision
belongs in `drop-02/`, preserving this drop.

Inputs: [node list](../../../docs/planning/class-redesign/node-list.md)
§2 and §4; [class round plan](../../../docs/planning/round52-class-plan.md)
C6, C7, C11, D5 and D7. The brief's top accent overrides the older node-list
wording about light towards the ultimate: the ultimate is on the bottom row.

### Contents

- [Background contact sheet](drop-01/preview-bg.png): all 24 candidates, exactly
  520 × 220 per image, with a mock 7 × 5 grid, pale label proxies and a few
  orthogonal connections. The mock UI exists only on this sheet.
- [Overlay contact sheet](drop-01/preview-fx.png): all 12 candidates; a sample
  phase over an iron sword, an iron staff and a bow at 8×, plus the overlay
  alone and every phase at 4×. Each strip also has its own animated GIF,
  showing those three weapons side by side at 8×.
- [Manifest](drop-01/manifest.json): one record per media file, 50 total;
  paths are relative to the drop, `size` is `[width, height]`, and `bytes` is
  the exact file size. Primary files have role `background` or `overlay`;
  GIFs and contact sheets have role `preview`. A strip and its GIF share
  key/variant; select by role or extension as well.
- [Generation inputs](drop-01/sources.json): 24 independent prompts and
  their original generation output paths. No third-party image was sent
  to image generation. The manifest also records each source hash and size.
- [Check receipt](drop-01/checks.json): dimensions, alpha, hashes, per-frame
  coverage, loop seams, GIF duration checks and centre luminance observations.

### Backgrounds

All eight trees use restrained painterly surfaces, atmospheric depth and
edge silhouettes. Each variant is a separate image-generation call, not a
recolour of another draft. Each is an opaque 1040 × 440 palette PNG with
256 colours, no dithering and `optimize=True`. After centred Lanczos fitting,
a smooth horizontal mask softly blurs and darkens the central field; the
exact recipe and source image hash are recorded per file in the manifest.

| Tree | Idea |
|---|---|
| Ember | Cracked charcoal basalt, orange fissures and rising edge sparks carry the fire palette. |
| Rime | A frozen night lake lies between frost ferns under a pale upper-edge aurora. |
| Bulwark | Weathered ramparts, iron gate bands, rivets and a plain banner suggest a steady guard. |
| Ruin | Broken battlefield iron and scorched ground dissolve into deep crimson smoke. |
| Mercy | Warm stone arches and ivory lilies frame soft golden sanctuary light. |
| Reckoning | Stern tribunal columns and golden scales meet hard upper light and crimson cloth. |
| Quarry | A forest edge, grasses, shed antlers and feathers overlook a distant dawn ridge. |
| Veil | Moonlit alley walls and violet smoke surround a quiet indigo field below a silver crescent. |

### Overlays

All PNGs are **16 × 128 RGBA**, eight 16 × 16 frames from top to bottom.
Coordinates are authored directly; no pixels are copied from the weapon
sprites. Effects occupy x 7–15 and y 0–8 at most. The entire lower seven
rows stay transparent. Only 6–14 pixels are nontransparent in any phase.
Alpha is selected from **0, 96, 176, 255**: translucent trails and pulses
leave the weapon visible; a few frost/holy/rage highlights are opaque.
Every transparent pixel has zero RGB. There is no Strike strip.

| Key | Variant | Frames | Loop (s) | Frame duration (ms) | Alpha levels |
|---|---:|---:|---:|---:|---|
| `fx.fire` | 1 | 8 | 0.80 | 100 | 0, 96, 176 |
| `fx.fire` | 2 | 8 | 0.96 | 120 | 0, 96, 176 |
| `fx.frost` | 1 | 8 | 1.12 | 140 | 0, 96, 176, 255 |
| `fx.frost` | 2 | 8 | 0.96 | 120 | 0, 96, 176, 255 |
| `fx.holy` | 1 | 8 | 1.12 | 140 | 0, 96, 176, 255 |
| `fx.holy` | 2 | 8 | 0.96 | 120 | 0, 96, 176, 255 |
| `fx.rage` | 1 | 8 | 0.80 | 100 | 0, 96, 176 |
| `fx.rage` | 2 | 8 | 0.96 | 120 | 0, 96, 176, 255 |
| `fx.wild` | 1 | 8 | 0.96 | 120 | 0, 96, 176 |
| `fx.wild` | 2 | 8 | 1.12 | 140 | 0, 96, 176 |
| `fx.shadow` | 1 | 8 | 1.12 | 140 | 0, 96, 176 |
| `fx.shadow` | 2 | 8 | 0.96 | 120 | 0, 96, 176 |

The original phase sequence loops without a duplicated terminal frame;
phase 8 evaluates to phase 0. The transition from the last saved phase to
the first is no larger than the largest internal transition for every strip
(measured in premultiplied RGB, observations in `checks.json`). The end/start
phases were also visually inspected beside each other over the sword.
The GIFs loop forever at the exact proposed duration. `wild_v2.gif` has seven
encoded frames: two identical 140 ms phases become one 280 ms hold. Its PNG
still has eight phases; `gif_encoded_frames` records the distinction.

### Reproduction

From the repository root, with Python 3 and Pillow installed:

```sh
python3 -I tools/r52_art/arta/arta_bg.py --out /tmp/arta-rebuild
python3 -I tools/r52_art/arta/arta_fx.py --out /tmp/arta-rebuild
```

Both scripts locate repository inputs relative to themselves and work under
isolated Python. They accept identical existing media but refuse to replace
media with different bytes. Use a fresh output directory for revisions.
The background script needs the original generated files at the recorded
paths, or `--source-root <directory>` containing copies with those original
filenames. Originals remain in the local image-generation cache; the final
PNG assets are all committed in this drop. A new image-generation call is
not expected to reproduce the original pixels. The overlay script needs
only this repository's three preview weapon sprites and Pillow.

The manifest is assembled by the two scripts and includes their SHA-256
hashes. Each preserves the other script's entries. Code follows the
repository's GPL-3.0-or-later licence; original media is dedicated below.

### Checks and handoff

All 50 media records match their file sizes, dimensions and SHA-256 hashes;
all original generation files and generator hashes match. Dimensions, alpha,
lower-half clearance, the eight saved phases, the loop seam and GIF timings
were checked once for the completed drop. Both contact sheets and the seam
inspection were viewed. No fixtures or engine runs were performed, as the
brief requests. Desktop/web runtime acceptance and the art picks remain
with the user and coordinator.

Backgrounds total **4,553,267 bytes**, range **168,242–216,091 bytes** per PNG; the 12 overlay PNGs total **2,947 bytes**. Every background is below the approximate 300 KB guide.

### Media

The project dedicates rights it holds in the new background and overlay
art to **CC0 1.0 Universal**, to the extent such rights exist:
<https://creativecommons.org/publicdomain/zero/1.0/>.
All new art is by **GPT-6 Astra (Grudgelands)**, dated **2026-10-19**.
`BG` below means built-in `image_gen.imagegen`, followed by `arta_bg.py`;
`FX` means original pixel geometry and cyclic paths in `arta_fx.py`.

The **weapon composites cannot be wholly CC0**, because the required preview
weapons carry attribution/share-alike licences. Those GIFs and
`preview-fx.png` are distributed as CC BY-SA 4.0 adaptations; their newly
authored overlay layer remains separately available as CC0 PNGs. The
background contact sheet is wholly new art and CC0. No third-party pixels
occur in any deliverable background or overlay PNG.

Preview source credits (provenance only):

- Iron sword and iron staff: Grudgelands weapon ladder, derived from
  **minetest_game contributors**, © 2010–2023 (including celeron55, Cisoun,
  G4JC, VanessaE, RealBadAngel, Calinou, MirceaKitsune, Jordach, PilzAdam,
  jojoa1997, InfinityProject, Splizard, Zeg9, paramat, BlockMen, sofar,
  Neuromancer, Gambit, asl97, KevDoy, Mito551, GreenXenith, kaeza, kilbith,
  tobyplowy, CloudyProton, TumeniNodes, Mossmanikin, random-geek, Extex101,
  An0n3m0us and Lopano), **CC BY-SA 3.0 Unported**.
  [Source repository](https://github.com/luanti-org/minetest_game),
  [licence](https://creativecommons.org/licenses/by-sa/3.0/),
  [local attribution](../../../mods/BASE/default/license.txt),
  [weapon derivation](../../../mods/ITEMS/grug_gear/LICENSE-media.md).
- Bow: **XSSheep / Pixel Perfection and VoxeLibre contributors**,
  **CC BY-SA 4.0**, from `mcl_bows_bow_0.png` at commit
  `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`.
  [Source licence](https://git.minetest.land/VoxeLibre/VoxeLibre/src/commit/c2dbc520ff4e1637072d33b06c3a2404e0f08df7/LEGAL.md),
  [licence](https://creativecommons.org/licenses/by-sa/4.0/),
  [local provenance](../../../mods/PLAYER/grug_abilities/LICENSE-media.md).
- Preview modifications: alpha-composite our effect above each unchanged
  weapon, enlarge with nearest-neighbour scaling, add a checker background
  and labels, and encode animation with a common palette. Source file paths
  and SHA-256 hashes are in each composite's manifest entry. `Weapon authors`
  in the table refers to the credits above; existing repository attribution
  is also preserved in [CREDITS.md](../../../CREDITS.md).

| File (relative to drop-01) | Author | Date | Method | Licence | Bytes |
|---|---|---|---|---|---:|
| `bg/ember_v1.png` | GPT-6 Astra | 2026-10-19 | BG; Basalt embers | CC0-1.0 | 189696 |
| `bg/ember_v2.png` | GPT-6 Astra | 2026-10-19 | BG; Banked furnace | CC0-1.0 | 203933 |
| `bg/ember_v3.png` | GPT-6 Astra | 2026-10-19 | BG; Ash and cinder | CC0-1.0 | 193236 |
| `bg/rime_v1.png` | GPT-6 Astra | 2026-10-19 | BG; Aurora lake | CC0-1.0 | 178498 |
| `bg/rime_v2.png` | GPT-6 Astra | 2026-10-19 | BG; Blue stillness | CC0-1.0 | 185459 |
| `bg/rime_v3.png` | GPT-6 Astra | 2026-10-19 | BG; Winter breath | CC0-1.0 | 200685 |
| `bg/bulwark_v1.png` | GPT-6 Astra | 2026-10-19 | BG; Watch gate | CC0-1.0 | 191343 |
| `bg/bulwark_v2.png` | GPT-6 Astra | 2026-10-19 | BG; Iron threshold | CC0-1.0 | 190754 |
| `bg/bulwark_v3.png` | GPT-6 Astra | 2026-10-19 | BG; Rampart dusk | CC0-1.0 | 180251 |
| `bg/ruin_v1.png` | GPT-6 Astra | 2026-10-19 | BG; Broken iron | CC0-1.0 | 180673 |
| `bg/ruin_v2.png` | GPT-6 Astra | 2026-10-19 | BG; Red aftermath | CC0-1.0 | 203658 |
| `bg/ruin_v3.png` | GPT-6 Astra | 2026-10-19 | BG; Cinder steel | CC0-1.0 | 193378 |
| `bg/mercy_v1.png` | GPT-6 Astra | 2026-10-19 | BG; Quiet sanctuary | CC0-1.0 | 180950 |
| `bg/mercy_v2.png` | GPT-6 Astra | 2026-10-19 | BG; Lily alcove | CC0-1.0 | 182921 |
| `bg/mercy_v3.png` | GPT-6 Astra | 2026-10-19 | BG; Gentle vigil | CC0-1.0 | 174308 |
| `bg/reckoning_v1.png` | GPT-6 Astra | 2026-10-19 | BG; Severe tribunal | CC0-1.0 | 177017 |
| `bg/reckoning_v2.png` | GPT-6 Astra | 2026-10-19 | BG; Scales at dawn | CC0-1.0 | 168242 |
| `bg/reckoning_v3.png` | GPT-6 Astra | 2026-10-19 | BG; Judgment stone | CC0-1.0 | 195280 |
| `bg/quarry_v1.png` | GPT-6 Astra | 2026-10-19 | BG; Dawn ridge | CC0-1.0 | 198429 |
| `bg/quarry_v2.png` | GPT-6 Astra | 2026-10-19 | BG; Hunter's clearing | CC0-1.0 | 190381 |
| `bg/quarry_v3.png` | GPT-6 Astra | 2026-10-19 | BG; Feathers in mist | CC0-1.0 | 182117 |
| `bg/veil_v1.png` | GPT-6 Astra | 2026-10-19 | BG; Moonlit alley | CC0-1.0 | 216091 |
| `bg/veil_v2.png` | GPT-6 Astra | 2026-10-19 | BG; Silver passage | CC0-1.0 | 188355 |
| `bg/veil_v3.png` | GPT-6 Astra | 2026-10-19 | BG; Violet hush | CC0-1.0 | 207612 |
| `preview-bg.png` | GPT-6 Astra | 2026-10-19 | BG contact sheet with mock grid | CC0-1.0 | 2904336 |
| `fx/fire_v1.png` | GPT-6 Astra | 2026-10-19 | FX; Twin tongues | CC0-1.0 | 258 |
| `fx/fire_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 61527 |
| `fx/fire_v2.png` | GPT-6 Astra | 2026-10-19 | FX; Ember crown | CC0-1.0 | 300 |
| `fx/fire_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 62669 |
| `fx/frost_v1.png` | GPT-6 Astra | 2026-10-19 | FX; Rime needles | CC0-1.0 | 228 |
| `fx/frost_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 61611 |
| `fx/frost_v2.png` | GPT-6 Astra | 2026-10-19 | FX; Crystal breath | CC0-1.0 | 212 |
| `fx/frost_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 62601 |
| `fx/holy_v1.png` | GPT-6 Astra | 2026-10-19 | FX; Golden motes | CC0-1.0 | 222 |
| `fx/holy_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 61046 |
| `fx/holy_v2.png` | GPT-6 Astra | 2026-10-19 | FX; Quiet radiance | CC0-1.0 | 264 |
| `fx/holy_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 62337 |
| `fx/rage_v1.png` | GPT-6 Astra | 2026-10-19 | FX; Crimson edge | CC0-1.0 | 169 |
| `fx/rage_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 60737 |
| `fx/rage_v2.png` | GPT-6 Astra | 2026-10-19 | FX; Red heartbeat | CC0-1.0 | 234 |
| `fx/rage_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 62317 |
| `fx/wild_v1.png` | GPT-6 Astra | 2026-10-19 | FX; Teal slipstream | CC0-1.0 | 194 |
| `fx/wild_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 61547 |
| `fx/wild_v2.png` | GPT-6 Astra | 2026-10-19 | FX; Leaf drift | CC0-1.0 | 245 |
| `fx/wild_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 53967 |
| `fx/shadow_v1.png` | GPT-6 Astra | 2026-10-19 | FX; Violet curl | CC0-1.0 | 305 |
| `fx/shadow_v1.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 62178 |
| `fx/shadow_v2.png` | GPT-6 Astra | 2026-10-19 | FX; Silver smoke | CC0-1.0 | 316 |
| `fx/shadow_v2.gif` | GPT-6 Astra; weapon authors | 2026-10-19 | FX; animated weapon composite | CC-BY-SA-4.0 | 63958 |
| `preview-fx.png` | GPT-6 Astra; weapon authors | 2026-10-19 | FX contact sheet; weapon composites | CC-BY-SA-4.0 | 60878 |
