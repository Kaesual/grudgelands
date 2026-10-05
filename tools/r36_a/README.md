# Round 36 main questline art

GPT-6 Astra, 2026-10-05. Original, AI-assisted pixel art, CC0-1.0.
The approved [story bible](../../docs/planning/round36/story-bible.md)
owns the palettes and motifs. This package contains art and its provenance;
the coordinator owns game integration and independent review.

Run `python3 tools/r36_a/paint_art.py` with Python 3 and Pillow. It writes
the 21 textures directly to their final paths and puts the contact sheet,
UV preview and SHA-256 validation manifest in uncommitted `astra_out/`.
It does not modify any gameplay code, data or existing texture. No external
images or image-generation service are used. Existing textures are read
only for the uncommitted comparisons; no reference pixels enter the new art.

| Folder | Files (all RGBA) | Size |
|--------|------------------|------|
| `mods/PLAYER/grug_achievements/textures/` | `grug_achievements_cloak_{unburnt_roll,unbought_banner,broken_due}.png` | 32×32 each |
| `mods/ENTITIES/grug_mobs/textures/` | `grug_mobs_rift_void.png`, `grug_mobs_rift_bolt.png` | 16×16 each |
| `mods/ENTITIES/grug_mobs/textures/` | `grug_mobs_rift_particle.png` | 8×8 |
| `mods/ENTITIES/grug_mobs/textures/` | `grug_mobs_isquarre.png` | 62×78 |
| `mods/ENTITIES/grug_mobs/textures/` | `grug_mobs_commander_{accord,throng}_overlay.png` | 64×32 each |
| `mods/PLAYER/grug_quests/textures/` | `grug_quests_obj_{impounded_pay,false_requisition,brand_rubbing,ash_slab,toll_box,courier_ledger,branded_pay_pit,pledged_standard,tally_stone,rootmark,survey_cairn,wreck_pay_chest}.png` | 32×32 each |

## UV and design notes

- Cloaks use the exact four outer-face palette colours from the bible and
  one flat darker lining tone. All pixels are opaque. The left 16 columns
  carry the motif and an uninterrupted one-pixel border; the right half is
  lining. The Broken Due's two hooks are detached from the severed ring.
- Commander masks cover only torso front/back/top, arm top and the first
  three rows of the arm sides. Head, hair, hands, legs and all other UV
  regions are completely transparent, including their RGB channels.
  **One adaptation to the bible:** Greyvow's pale brow stripe is omitted
  because the task explicitly limits these overlays to torso and shoulders.
  Stonegrudge has a split stone and exactly three cords, without hooks.
- Isquarre is newly painted on a 62×78 canvas, exactly twice the original
  Dungeon Master's 31×39 atlas. No UV island moves. The B3D's front and back
  torso share an island, and sides overlap that island too; this is retained.
  The painted brand is compressed vertically in texture space to appear
  approximately circular on the tall torso. The mouth stays in the original
  head-face region. Sparse derived kiln-black shades retain the bible's
  four colour anchors. The original mesh and texture credits remain in the
  existing `grug_mobs/LICENSE-media.md`; no source pixels are reused.
- The void has identical opposite-edge samples and wrapped, branching
  ember veins. The particle uses graded alpha for softness. The bolt has a
  dark opaque core, ember fissure and faint translucent outer ash.
- Quest objects share restrained material colours, the Undertithe's heat
  colours and one open-bottom circle with inward-curling hooks. The small
  survey coin retains a reduced seven-pixel form of the mark. Other markings
  are abstract stitching or account strokes, never lettering.

## Validation and previews

The generator asserts all 21 exact sizes and RGBA modes, opaque cloaks and
boss/void textures, flat cloak linings and border colours, commander alpha
restricted to the documented UV mask, quest-object bases reaching the
bottom rows, and identical opposite void edges. The validation manifest
records dimensions, alpha extrema and SHA-256 for every texture. A second
generation pass reproduced all 21 PNG hashes exactly.

`astra_out/sheet.png` shows every texture at exactly ×4 nearest-neighbour,
including separate outer cloak faces, both overlays on
`grug_mobs_guard_accord.png`, Isquarre beside the original Dungeon Master,
and a 3×3 repeat of the void. The reference guard remains credited to Amaz,
CC BY-SA 3.0, in the existing mob media ledger; the comparison is uncommitted.

`astra_out/uv_preview.png` checks Isquarre's placement by reading and
rasterizing the actual shipped Dungeon Master B3D triangles with nearest
texture samples. It shows the unlit mesh-local bind pose, not gameplay.
The commander previews beside it assemble the front skin faces. The visual
checks verify chest, mouth, tabards, marks and object silhouettes at their
intended pixel scale. No runtime code changed; no Lua checks apply here.

After coordinator integration, the user's Luanti GUI check should inspect
the three cloaks from behind and in movement, both commander overlays on
several camp races, Isquarre from front/back/sides, the rift's repeated floor
and effects, and all twelve quest sprites at 1–1.4 nodes wide on the ground.
