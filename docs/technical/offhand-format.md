# Offhand format (Round 55)

The contract between the offhand look, the model generator, the bake and the game, from Round 55
([plan](../planning/round55-plan.md)); the sister of [armor-format.md](armor-format.md). It covers the shield
and the open spellbook in the left hand, the Scout's back weapon card and the optional cloak wings. The files
live in [`tools/r55_offhand/`](../../tools/r55_offhand/README.md); `offhand.py` is this document in code
(validation, rotation convention, shapes, atlas, file names), and `params.json`, `offhand.py` and
`data/atlas.json` change only through the round's coordinator or the finish step.

## 1. What is where

| Part | Bone | Buffer (texture slot) | Shown when |
|---|---|---|---|
| shield, three size copies | `Offhand_Shield` (child of `Arm_Left`) | `offhand` | a Warrior's shield in the offhand slot; its texture paints only the copy of its size |
| open spellbook | `Offhand_Book` (child of `Arm_Left`) | `offhand` | a Mage's or Priest's spellbook in the offhand slot |
| back card, twice | one on `Cloak`, one on `Body` (§3.3) | `back` | a Scout: the weapon not in the hand (plan §4 GAME); on the cloak card when a cloak is worn, else on the body card |
| two wings | `Cloak` | `wings` | a cloak that has a wing texture (player model only) |

Every part is always in the model; an empty slot is `blank.png`, so nothing shows (the armor atlas trick). With
the setting `grug_offhand_visuals` off (on by default since 0.55.0), the game writes `blank.png` into all three new
slots.

## 2. `params.json`

Every number of the look, written by the preview page's export (the Offhand-Werkstatt) and read by the model
generator. `python3 tools/r55_offhand/offhand.py --check` validates it (unknown keys, ranges, clip names).

### 2.1 Frame and units

All positions are **skin pixels in the armor catalog frame at rest** ([armor-format.md](armor-format.md) §1):
right-handed, x = the character's **left**, y up from the soles, z forward (the face). The left arm's pivot
(`Arm_Left`) is (6, 22, 0), the body's (`Body`) (0, 12, 0); the arm's outer face is the plane x = 8.

**Rotations** are `rot = [x, y, z]` degrees with an `order` of three letters: order "ABC" means
R = R_A(rot_A) · R_B(rot_B) · R_C(rot_C), each the standard right-handed matrix acting on column vectors (the
same as a three.js `Euler` with that order string). The angles are always listed x, y, z. So `[90, 0, 0]` turns
+y (up) into +z (forward).

**Conversions** (the only two places frames change):

- **from the page** (glTF, model units, 10 per node, the character facing −z): a point (x, y, z) becomes
  (−x, y, −z) / 0.525. An **item** rotation becomes R_cat = R_y(180°) · R_glTF. A **bone key** rotation becomes
  R_cat = R_y(180°) · R_glTF · R_y(180°); in order XYZ that is (a, b, c) → (−a, b, −c).
- **into the `.b3d`** (left-handed, model units, the character's left at −x): a point becomes
  0.525 · (−x, y, z) (`gen_cloak_model.to_model`), a rotation F · R · F with F = diag(−1, 1, 1), and every
  triangle's winding flips (armor-format.md §1).

### 2.2 Items

`shield.place`, `book.place` (`{bone, pos, rot, order}`) and `back.body`, `back.cloak` (`{pos, rot, order}`; their
bones are fixed, §3.3) are placements: an item point q in the item's
own frame (§3) lies at rest at `pos + R · (scale · q)`. The placement is **independent of the bone's pivot**:
moving a pivot changes how the item turns, never where it rests.

- `shield.sizes`: the three size steps (draft 0.85, 0.92, 1.0), each a copy of the shield scaled about its own
  origin; `shield.tier_step`: bracket "1" … "6" → step 0, 1 or 2.
- `back.size`: the edge of both cards in skin pixels; `back.body` places the card on `Body` (rigid on the back),
  `back.cloak` the card on `Cloak` (rides the cloak's swing, just outside the cloak).

### 2.3 Bones and clips

`bones.Offhand_Shield` and `bones.Offhand_Book`, each `{pivot, clips}`. `pivot` is a point (catalog frame, at
rest) that moves with `Arm_Left`. `clips` maps a clip name to an entry; a clip without an entry, and every
frame outside the named clips, holds the bone rigid on the arm (identity).

Clip names: `stand`, `sit`, `lay`, `walk`, `mine`, `walk_mine` (player_api's ranges; the NPC model has only
these) and `cast1`, `cast2`, `swing`, `bow`, `block`, `charge`, `flinch`, each also as `<name>_walk` (the
Round 40 pose clips, frames in `grug_visuals/apply.lua` POSE_CLIPS).

An entry is either **static** `{rot, pos, order, steady}` or **keyed** `{keys: [{frame, rot, pos}, …], order,
steady}`. `pos` defaults to [0, 0, 0], `steady` to 0. `frame` counts from the clip's first frame (0); keys are
interpolated per component, linearly, wrapping round a looping clip and holding the last key in a one-shot
clip, as the pose clips' own keys (`gen_cloak_model.spec_angle`).

**What a key does.** At a frame with key (R, t), the bone moves an item point v (at rest) to
`pivot + t + R · (v − pivot)`, and then `Arm_Left` (and everything above it) carries it as usual.

**Steadiness** `steady` = s in [0, 1] cancels that fraction of the arm's swing **relative to the clip's mean
pose**, not to the bind pose. Let A_f be `Arm_Left`'s rotation relative to `Body` at frame f (from rest) and Ā
the normalized mean of A_f over the clip's frames. The item's orientation then follows
`Body_f · slerp(A_f, Ā, s) · R` instead of `Body_f · A_f · R`, while the pivot point still follows the arm.
s = 0 is rigid on the arm; s = 1 keeps the item at the clip's mean angle (Block's raised arm stays raised;
Walk's swing is removed).

No scale keys: the glTF builder refuses them, and the size copies make them unnecessary.

## 3. Shapes (each in its own frame, skin pixels)

### 3.1 Shield (`shield.shape`, `shield.boss`)

Frame: x across the face (seen from the front, +x is to the right), y up, z out of the face; the origin lies on
the centre line in the plane of the back rim, at the grip.

- With W = width / 2, H = height: top T = top · H, point B = T − H, shoulder S = T − shoulder · H,
  waist M = (S + B) / 2. The outline, clockwise seen from the front:
  (−W, T), (0, T), (W, T), (W, S), (taper · W, M), (0, B), (−taper · W, M), (−W, S) (`offhand.shield_outline`).
- **Front** z = thick + ridge · (1 − |x| / W) (the ridge runs down x = 0); **back** = front − thick. Each half
  (x ≤ 0, x ≥ 0) of the front and of the back is one planar fan from (0, T) over the outline points of that half
  to (0, B): 3 triangles per half, 12 in all. The **rim**: one quad per outline edge (8 edges, 16 triangles),
  front point to back point. 28 triangles.
- **Boss** (optional, `null` = none): a square pyramid; base corners (±radius, by ± radius) on the front
  surface, by = (T + B) / 2 + lift · (T − (T + B) / 2); apex (0, by, front(0) + height). 4 triangles.

### 3.2 Spellbook (`book.shape`, `book.ribbon`)

Frame (the **closed** book): the spine along y at x = 0, the pages towards +x, the front half at z > 0, the back
half at z < 0, page tops at +y. With p = pages / 2, c = cover, w = width, h = height, i = inset,
t = max(c, spine_min), a = open / 2, b = (p + c) · sin a and d = max((p + c) · cos a, t / 2)
(`offhand.book_boxes`):

| Box | Extent (x0, y0, z0)–(x1, y1, z1) | Faces left out | Turned |
|---|---|---|---|
| `cover_f` | (0, −h/2, p)–(w, h/2, p + c) | | −open / 2 |
| `cover_b` | (0, −h/2, −p − c)–(w, h/2, −p) | | +open / 2 |
| `pages_f` | (0, −h/2 + i, 0)–(w − i, h/2 − i, p) | front (against the cover) | −open / 2 |
| `pages_b` | (0, −h/2 + i, −p)–(w − i, h/2 − i, 0) | back (against the cover) | +open / 2 |
| `spine` | (−b − t, −h/2, −d)–(−b, h/2, d) | | 0 |
| `ribbon` | (x0, −h/2 − below, −half_depth)–(x1, −h/2 + into, half_depth) | top | 0 |

"Turned" is a rotation about the y axis (order Y, §2.1) that opens the book: with open = 150 the halves stand
75° each side of the spread's centre, which faces +x. The readable pages are `pages_f`'s back face and
`pages_b`'s front face; seen by the reader (from +x, page tops up), `pages_f` is the left page and `pages_b` the
right page. The spine is not turned: it is the plate behind the open halves, t thick, that joins the two covers'
spine edges (they end at x = −b, z = ±(p + c) · cos a), so the gutter between the halves is closed from behind;
closed (open = 0) it is the closed book's spine, flat open (180) a strip t wide behind the join. The page blocks
keep their spine-side (right) faces, which close each block and line the groove between the halves. 66 triangles.

### 3.3 Back cards (`back`)

Two cards, the user's ruling of 2026-10-21: the **cloak card** on `Cloak` (placed by `back.cloak`) shows the weapon
when a cloak is worn, the **body card** on `Body` (placed by `back.body`) when none is; the texture decides which
(§5), as with the shield's size copies. The NPC model has no cloak and carries only the body card.

Each card is a square of `size` px centred on the card frame's origin, in its x–y plane: x = the image's u (to the
right), y = the image's up (v runs down). Two-sided like the weapon card (each pair of triangles a hair off the
plane to its own side, `gen_cloak_model.CARD_GAP`); the side facing +z shows the image unmirrored. UVs: the cloak
card samples the left half of the 32 × 16 `back` texture (u 0..0.5), the body card the right half (u 0.5..1),
v 0..1. Default: both centred on the upper back, rot [0, 180, 0], so the card faces backwards and a diagonal weapon
icon reads the right way from behind; the body card behind the chest armor and the belt, the cloak card just
outside the cloak's outer face at rest.

### 3.4 Wings (`wings`, player model only)

Each wing is a flat triangle hinged on a side edge of the cloak, on the `Cloak` bone. The hinge line runs
along the cloak's side in the cloak's middle plane (z = −2.524 px, the cloak box's centre), from the hem (y = 8) to
y = 24 − drop, **inset** into the cloak by e = thick / 2 · sin(angle) + 0.05 px: x = ±(3.905 − e) (3.905 px is the
cloak's half-width of 2.05 model units; `offhand.wing_hinge_x`). The third corner lies `width` + e px outwards from
the hinge's bottom. The wing is `thick` px thick about that plane (at most 0.65, inside the cloak's own 0.667 px):
an outer face, a lining, and two edge quads (the bottom edge and the slanted edge; none along the hinge), 6
triangles. It is then turned about the hinge line by `angle` degrees so that its outer edge moves **forwards**,
towards the body's side. The inset keeps the turned wing's hinge edge inside the cloak, so no gap opens between
cloak and wing and the cloak's side face covers the seam (the user's report of 2026-10-21: a hinge exactly on the
cloak's edge opens a thin wedge once the wing is turned). The right wing is the mirror image of the left.

## 4. The offhand atlas and the UVs

`data/atlas.json` (written by `offhand.py`, checked by `offhand.py --check`) places every sheet once in a
**64**-wide atlas, packed as the armor atlas: shelves, sorted by height, then width (descending), then id; no
gutter. Its height is the smallest power of two (at least 32) that holds every sheet: 64 × 64 for the current
parameters. Per sheet: `rect` = [x, y, w, h] and `faces` = its face rectangles in atlas texels, origin top left;
a UV is u = x / width, v = y / height.

| Sheet | Size (texels) | Content |
|---|---|---|
| `shield_0`, `shield_1`, `shield_2` | 2 · tex(width) × tex(height) | one per size step: `front` left, `back` right |
| `cover_f`, `cover_b`, `pages_f`, `pages_b`, `spine`, `ribbon` | box sheet | the classic box unwrap of armor-format.md §4, in the box's closed-frame axes (§3.2), before the turn |
| `card` | 16 × 16 | free, kept for a later off-hand weapon card |

tex(n) = floor(n + 0.5), at least 1. A face left out (§3.2) has no rectangle.

**Shield UVs.** The front samples its rectangle by orthographic projection onto the shield's x–y plane:
column = (x + W) / 2W across, row = (T − y) / H down (column 0 at −x, as seen from the front). The back is
seen from behind: column = (W − x) / 2W. The **rim** takes the front face's border texels: both ends of a rim
quad use the front UV of their outline point (as the cloak's edges), so it samples the texels the outline
crosses, which §6 therefore requires opaque. Edge UVs that would fall on a sheet's boundary (the rim along
the outline's outer columns and rows, the wings' edges) are pulled half a texel inwards, so nearest sampling
never picks the neighbouring sheet (the shield front's right edge would otherwise read the back sheet). The boss uses the front's projection. Each
size copy samples its own sheet, so the copy of a tier's size step shows and the others stay transparent.

**Book UVs.** Each box face samples its face rectangle in the orientation of armor-format.md §4
(`armorlib.face_point`), in the box's closed-frame axes.

## 5. Texture slots

| Model | Slots, in order |
|---|---|
| player | `skin`, `cloak`, `armor`, `weapon`, `offhand`, `back`, `wings` |
| NPC | `skin`, `armor`, `weapon`, `offhand`, `back` |

| Slot | Size | Content |
|---|---|---|
| `offhand` | the atlas, 64 × 64 | the shield's or spellbook's baked layer (§7) with its enchant overlay; `blank.png` when empty |
| `back` | 32 × 16 | the Scout's non-held weapon's 16 × 16 inventory image in the **left** half when a cloak is worn (the cloak card), in the **right** half otherwise (the body card), the other half transparent: `[combine:32x16:0,0=<image>` or `[combine:32x16:16,0=<image>` (the image escaped for `[combine`); `blank.png` when no card shows. NPCs: the right half |
| `wings` | 16 × 32 | the cloak's wing texture (§6); `blank.png` for a cloak without wings |

## 6. Painted art

The painter's files, in one art directory (the test set: `tools/r55_offhand/test_art/`):

| File | What | Size |
|---|---|---|
| `shield/<variant>.png` | a shield sheet: front left, back right | 2 · tex(width) × tex(height) (22 × 13 now) |
| `book/<box>_<variant>.png` | a book box sheet, `box` as in §3.2 | per box (`data/atlas.json` `rect`) |
| `icons/shield_<variant>.png`, `icons/book_<variant>.png` | inventory icons | 16 × 16 |
| `cloak_<id>.png` (optional) | a cloak texture in the cloak's own 32 × 32 format (outer face left, lining right; [character_visuals.md](../design/character_visuals.md) §5b), e.g. the Supporter cloak; size-checked, not baked | 32 × 32 |
| `wings_<id>.png` (optional) | the wing texture of the cloak with the same `<id>` (below); size-checked, not baked | 16 × 32 |
| `tiers.json` | per item and tier: palette, variant(s), icon | |
| `palettes.json` (optional) | proposed tier palettes, laid over the armor's `data/palettes.json` by name | |

```json
{"shield": {"T1": {"palette": "bronze", "variant": "a", "icon": "a"}},
 "book": {"T1": {"palette": "patch", "variant": {"cover_f": "a", "pages_f": "b"}, "icon": "a"}}}
```

A `variant` is one id for every sheet of the item or a map per book box (missing boxes mean `a`). An optional
`icon_palette` colours the tier's icon with another palette than its sheets (`palette`), for an icon picked from a
different proposal than the paint; without it the icon takes `palette`. Tier `T<n>`
is bracket n, whose item is `grug_gear:shield_<grade>` or `grug_gear:spellbook_<grade>`.

- **Palette and zones** as armor-format.md §6: the 13 reference colours plus full transparency, alpha 0 or
  255; zone A (A_LIGHT, A_DARK) takes the prefix colour, zone B (B_LIGHT, B_DARK) the suffix colour. Each
  item shows at least 6 zone A and 3 zone B texels on the faces it turns outwards: the shield's front; the
  book's `cover_f` front, `cover_b` back, `pages_f` back and `pages_b` front faces.
- **Opaque:** every shield texel (front and back) that the outline contains **or crosses** (any overlap with
  positive area; the rim and the slanted edges sample those) and every texel of a book face is opaque. Texels
  wholly outside the outline are never sampled; leave them transparent. Shape comes from the geometry and the
  paint, not from cut-outs.
- **Orientation:** the shield front as seen from the front, its back as seen from behind; book faces as
  armor-format.md §4 in the closed frame (the front cover's outside is `cover_f`'s front face, the back
  cover's `cover_b`'s back face, the spine's outside its right face).
- **Wings** (16 × 32, not baked; the texture belongs to a cloak): columns 0–7 the left wing's outer face seen
  from behind (the hinge at column 7, rows 0–31 top to hem, the outer corner at column 0, row 31); columns 8–15
  its lining seen from the front (the hinge at column 8, the outer corner at column 15, row 31). Only the
  triangle on and below the diagonal is sampled; the edges take the outer face's border texels; the right wing
  shows the same texels mirrored.

## 7. Baked game files

Written by `tools/r55_offhand/bake.py` from the art, the palettes, `tiers.json` and the atlas. `<grade>` is the
bracket's metal grade key (`grug_gear.MATERIALS`: bronze, iron, steel, silversteel, embersteel,
abyssal_steel; `offhand.grades()`).

| File | Where | Content |
|---|---|---|
| `grug_offhand_shield_<grade>.png` | `grug_visuals/textures` | atlas layer: the tier's shield sheet in the sheet of its size step, the rest transparent |
| `grug_offhand_book_<grade>.png` | `grug_visuals/textures` | atlas layer: the book's sheets, the rest transparent |
| `grug_gear_shield_<grade>.png` | `grug_gear/textures` | shield icon (today's names) |
| `grug_gear_spellbook_<grade>.png` | `grug_gear/textures` | spellbook icon, one per tier (the picked art since the finish; `--icons-out`) |
| `…_ench.png` next to each | | the enchant mask in the armor's format: grey + alpha, two frames stacked (frame 0 zone A, frame 1 zone B; light 255, dark 153) |

## 8. Checks

- `python3 tools/r55_offhand/offhand.py --check`: `params.json` valid, `data/atlas.json` current.
- `python3 tools/r55_offhand/make_test_art.py`: rewrites the test art (never shipped).
- The model's own `--check` (`gen_cloak_model.py`), `build_glb.py --check` and `bake.py --check` (Round 55
  MODEL and BAKE).

## 9. Reference points

From the contract's first `params.json` (2026-10-21, commit cf7c6ce3; `tools/r55_model/test_frames.py` keeps a
copy, since the live file changes with the user's tuning), the same numbers as the page's own transforms
(checked to 4 decimals). The
shield at step 2 (size 1.0), at rest, the front's top centre (0, T, front(0)) and its point (0, B, front(0)):
(10.849, 19.46, 0.855) and (10.849, 6.46, 0.855). With the Block key [90, 0, 0] (order XYZ) about the pivot
(8, 13, 0), before the arm moves: (10.849, 12.145, 6.46) and (10.849, 12.145, −6.54), the top forwards, so
the raised arm stands the shield upright. The book's front cover, outer top corner at the fore-edge (5.5, 3.5,
1.75) of the closed frame, turned −75° about y and placed: (10.652, 15.865, −5.766).
