# Armor redesign — shapes, layouts and enchant zones

Coordinator: Claude, 2026-10-20, from the user's review of the armor overview page (all 72 pieces, worn and as
icons). Status: **phase 1 running** (the user's go, 2026-10-20): the three.js prototype for metal is published
(builder `~/projects/grudgelands-orchestration/armor/proto/build.py`, catalog `catalog.py`, z-fight check `check.py`).
Placeholder colours only, no art lane until the shapes are settled (the user, 2026-10-20).

Not part of this plan: the particle colour pass (the user reviews the particle page later) and the 0.53.0/0.53.1
push (after the user's GUI test).

## 1. Why

The user (2026-10-20): "Die Lederrüstungen sehen alle gleich aus, und die Stoffrüstungen sind ein einziges, wildes
Chaos." "Viele von den Rüstungen haben eigentlich gute Farben, Formen und Akzente, aber so wie wir sie gerade in
Grudgelands verwenden ergibt sich kein klares, sinnvolles Bild."

What the coordinator found on the 18 sets (front/back, icons, the raw sources):

- **Metal:** six sets from five unrelated sources (VoxeLibre gold, recoloured twice for bronze and embersteel; iron;
  chain with a red/white tabard; the striped diamond set, desaturated for silversteel; netherite). No progression
  over the tiers.
- **Leather:** one VoxeLibre cut with an 18 % tint and a trim pattern that is noise at 8×12 pixels; all six read as
  the same khaki, nightscale is not dark.
- **Cloth:** Lord of the Test pieces mixed per slot across outfits (a white robe with green hobbit trousers); the T6
  chest is a cape texture and shows nothing on the body; several icons are unreadable at 16 px.
- **Enchant masks:** generated (`tools/r31_b/gen_enchant_masks.py`), so prefix and suffix colour scattered dots with
  no relation to the design.
- **Draw order bug (in the game, not only the preview):** VoxeLibre's leggings carry a waistband in the torso region
  (in VoxeLibre it sits on a smaller inner layer under the chestplate). We flatten all layers onto one skin in the
  order chest, legs, feet, so the band covers the lower chestplate on every metal and leather set (60–119 pixels).
  The redesign removes it through fixed slot regions (§4.3); no separate fix.
- **The canvas:** today armor is paint on the 64×32 skin (torso front 8×12, arm and leg 4×12); only the head has a
  second, larger layer. Shoulder plates, skirts and collars can only be painted, so tiers cannot differ in shape.

## 2. The user's rulings so far (2026-10-20)

1. **Own designs.** The existing sets are a starting point only; we design our own pieces.
2. **Clear design language per line** (metal, leather, cloth), clearly apart from each other.
3. ~~Three layouts per line, one per tier pair~~ — **superseded the same day:** the user picks the visible shapes
   **per tier** ("dann kann ich auch eine pro Tier festlegen"). A tier is a **selection of catalog shapes plus a
   palette**; each shape of a line is painted once (one or two paint variants, e.g. half or full breastplate) and
   shared by every tier that shows it. Guideline, not a rule: a tier shows at least what the tier below shows.
   The three proposals (Mercenary, Knight, Champion) remain starting points.
4. **Enchant colours are designed with the armor:** every layout has a placement target for prefix and suffix.
   Rule: **the prefix colours the cloth, the suffix colours the fittings.**
5. **Cloth legs from layout 2 on are the robe's skirt**, not trousers.
6. **Leather T4 "scaled" is renamed** (scales belong to the top layout); the new name comes with the style bible.
7. **Real 3D shapes instead of paint only** ("Wenn wir es eh machen, dann richtig"), but **low poly and cheap**:
   "Einer der großen Vorteile von Luanti ist ja, dass es auf jedem alten Rechner läuft".
8. **A small catalog that does a lot:** one base shape per body area with optional reinforcements, different looks
   through which parts are shown and through transparent texture; "lieber klein anfangen und später erweitern".
9. **Not every humanoid needs the same model:** guards and NPCs get a much smaller catalog.
10. **Iterate in three.js first, not in the game, and metal first.** Then extend the system to leather and cloth
    with as few new shapes as possible.

## 3. Engine facts (checked in the Luanti 5.17 source, the user's client)

- **Hardware skinning since Luanti 5.16** (commit `5feb60e1e`, 2025-12-01, "Optimize: Use hardware skinning for
  mesh animation"). With the default OpenGL 3 driver (needs OpenGL ≥ 3.2, tried first) the CPU computes one matrix
  per joint per frame; vertices are moved by the vertex shader. At least 256 joints fit (16 KiB minimum uniform
  block); we need a few dozen.
- **Software skinning (per vertex, on the CPU, every frame) remains** for the legacy OpenGL driver (old GPUs or a
  manual setting), OpenGL ES 2 (Android, some ARM boards), clients before 5.16, and meshes with more joints than
  the driver takes. Hidden geometry is skinned too. This is the case the shape budget protects.
- **Draw calls:** every mesh buffer is one draw call. All armor shapes share **one buffer and one atlas texture**,
  so armor adds one draw call per character however many shapes it has.
- **Shadows:** the shadow depth pass discards pixels with alpha < 0.7 (`client/shaders/shadow/pass1`). Transparent
  parts of a shape cast no shadow.
- **The inventory preview** (`model[]`) renders the same mesh with skinning, but has **no bone overrides**. Hiding a
  shape by scaling its bone to 0 would not work there, so **shapes are hidden through the texture** (transparent in
  the atlas), as "no cloak" works today. This works in the world, in the preview and on NPCs alike, and needs no
  bone per shape.
- **Reference sizes** (vertices, counted in our models): character 168 (player with cloak 192), spider 648,
  skeleton 832, ice dragon 1,272, horse 1,336. A mounted player is about 1,500 today.

## 4. The design system

### 4.1 Two axes

- **Layout** (cut and shapes): changes every two tiers. Drawn once in **palette indices** (material dark/mid/light,
  edge, outline, zone A, zone B), not in final colours.
- **Palette** (material): changes every tier. A tier is a palette applied to its layout. No per-grade recolour
  hacks (the silversteel `^[hsl` goes away).

### 4.2 Design language per line (first proposal, refined in phase 1–2)

| | Metal (Warrior) | Leather (Scout) | Cloth (Mage, Priest) |
|---|---|---|---|
| Form | horizontal plate bands, hard light edges, rivets | diagonal straps, buckles, layers, asymmetric | vertical panels, hems, sash, long surfaces |
| Contrast | hard, cool (bronze and ember warm) | soft, warm, matte | calm, large colour area, embroidery |
| Layout 1 (T1–2) | Mercenary: breastplate over gambeson, sleeves and thighs uncovered, shin guards only, open helm with nasal | Woodward: vest over shirt, wrapped forearms, knee patches, wrapped shoes, leather cap | Novice: tunic with cord belt, hood down, plain trousers, wrapped feet |
| Layout 2 (T3–4) | Knight: full torso, shoulder plates, plate skirt, full greaves, sabatons, visored helm | Pathfinder: laced jerkin, bracers, chaps, tall boots, hood up | Scholar: long robe with embroidered hem and chest panel, robe skirt, hood up |
| Layout 3 (T5–6) | Champion: gorget, layered shoulder plates with reinforcement or spikes, knee cops, crest | Shadowhunter: scale lamellae, shoulder mantle, half mask, plated boots | Archmage: robe with collar mantle, ornate trim, gem clasp, tall hood or circlet |
| Palettes | bronze, iron; steel, silversteel (brighter); embersteel (glow in the seams), abyssal steel (black-violet, noble, little shine) | light, cured; heavy, *T4 renamed*; sleek (slate), nightscale (indigo-black) | patch, woven; heavy, silkweave; silk, stormweave (deep blue, silver embroidery) |

The user's first metal idea (the cheap set without shoes and shoulders for T1–2, shoulder plates for T3–4, the
noble set for T5–6; ember "like fire", abyssal black/violet but noble) is the target, drawn new.

### 4.3 Inner paint and outer shapes

Every piece has two parts:

- **Inner:** paint on the 64×32 skin (gambeson, shirt, trousers, the base of the plate). Each slot owns fixed skin
  regions, so draw order no longer matters: **chest** torso, arms and belt; **legs** the legs down to mid-calf;
  **feet** the lowest four rows; **head** head and hat layer.
- **Outer:** zero or more catalog shapes (§5), painted in the armor atlas. Low layouts are mostly inner paint; high
  layouts add shapes.

### 4.4 Enchant zones

- **Zone A (prefix, a large area, "the cloth"):** metal tabard, plume, under-skirt; leather scarf or sash, hood
  lining; cloth stole or chest panel, hood lining.
- **Zone B (suffix, small and strong, "the fittings"):** metal enamel on buckle and rivets; leather buckles and
  seams; cloth hem border and gem.
- Every slot carries both zones with a minimum visible size on the front (proposal: A ≥ 6 pixels, B ≥ 3), so one
  enchanted piece shows its colour. Unenchanted, a zone keeps a neutral base (undyed linen, bare metal).
- The masks are drawn with the layout (inner and outer), not generated. The 50 % opacity rule stays.

### 4.5 Icons

Icons stay 2D, 16 px, by the icon style rule: one clear silhouette, readable at 32 and 16 px, few details. An icon
**need not copy the 3D piece**; it only has to be recognisably the same intended piece (the user, 2026-10-20). One
icon per piece and tier (72), palette-swapped where the shape repeats.

## 5. The shape catalog

### 5.1 Rules

- Shapes are **boxes in pixel units** (one skin texel: 0.525 model units, 32 px = the 1.68-node character). A box is 24 vertices whatever is
  painted on it; holes, notches and spikes painted with transparency are free. The budget counts boxes.
- Boxes may be **rotated in fixed steps** (22.5°) for spikes, slanted skirts and collars.
- **Sizes are nested boxes, not cut-outs:** a cut-out edge has no thickness and looks hollow from an angle, so a
  base shape is two or three nested boxes (core, reinforcement, rim/spike), each fully on or fully off. Cut-outs
  only for details within a box.
- **Hard alpha only** (0 or 255).
- **At least 0.25 px between nested faces** (no z-fighting); the generator checks it.
- Every box is **rigid on an existing bone** (Head, Body, Arm_Left/Right, Leg_Left/Right). Hip panels (skirt, robe)
  hang on **swing bones** keyed like the cloak (`tools/r33_c3/gen_cloak_model.py`) with its clearance check
  against the legs.
- Every box has a **fixed place in the atlas**, the same in every model, so one composition serves all models.
- **Cloak clearance:** back plates must clear the cloak, or the cloak bone is moved back while they are worn
  (decided in phase 1).

### 5.1a Overlaps the painter must know

Nested and stacked boxes cover each other, so their paint has to agree. The painter's brief lists, per line and
tier, which box covers which, e.g. **Schulter Verstärkung over Schulter Kern** (metal T5–T6, leather T6), Armschiene
over Ärmelschale, Kniekachel over Oberschenkel/Stiefel, Zehenkappe over Stiefel, Visier over Helmschale, Gürtel over
Brustschale. The list is generated from
the catalog geometry and the tier selections, not written by hand (the render tool, §6 phase 3).

**Swing bones (measured, 2026-10-20):** with the game's 45° leg swing, the front panel needs 1.2× and the back panel
1.1× the leg angle (+0.06 rad) so no leg armor pokes through; the cloak never swings less than a worn back panel.

### 5.2 Budget

| Model | Armor | Total, about |
|---|---|---|
| Player (full catalog, cloak) | ≤ 45 boxes (≈ 1,100 vertices); start ≈ 30 | ≤ a horse |
| NPC armor (guards, bandits) | only what they wear, ≤ 15 boxes | ≤ a spider |
| Unarmored humanoids (villagers, traders) | none, today's `character.b3d` | 168 |

A fixture holds the limits.

### 5.3 Starter catalog (to be shaped in phase 1)

| Area | Base shapes | Boxes |
|---|---|---|
| Head | helm shell, visor or brim, crest or plume, hood peak | 4 |
| Torso | chest shell, gorget or collar, belt | 3 |
| Shoulders | per side: core, reinforcement, rim or spike | 6 |
| Arms | per side: sleeve shell, bracer | 4 |
| Hip | front and back panel (swinging; also the robe), side tassets | 4 |
| Legs | per side: thigh shell, knee cop | 4 |
| Feet | per side: boot shell, cuff | 4 |
| **Sum** | | **≈ 29 (≈ 700 vertices)** |

## 6. Phases

**Phase 1 — three.js shape prototype, metal only (coordinator).**
- The catalog as data (a JSON box list per shape: bone, position, size, rotation, nesting), the same data the model
  generator later reads.
- An artifact page:
  - the character in Luanti's proportions with a race skin;
  - stand and walk loops;
  - every box switchable;
  - presets for the three metal layouts;
  - **placeholder** textures (flat palette shading, generated, never shipped);
  - the vertex count against the budget;
  - notes per shape and layout in the page's db.
- Iterate with the user until the three metal layouts read right as shapes (e.g. shoulder reinforcement and spikes).

**Phase 2 — extend to leather and cloth.**
- The same prototype; reuse the metal shapes first.
- Add a shape only where a layout cannot be made from the catalog.
- Freeze the catalog and its budget.

**Metal result of phase 1 (the user's saved selection, 2026-10-20;
`~/projects/grudgelands-orchestration/armor/proto/metal_tiers.json`):** T1 helm cap, breastplate, thighs, boots (belt removed later the same day);
T2 + shoulder core; T3 + front/back skirt, sleeves; T4 + tassets, bracers, toe caps; T5 + visor, shoulder
reinforcement and flare, knees; T6 + crest, spikes (the whole catalog). Gorget and brim were dropped. The catalog
grew to 31 boxes in phase 2 with a hood point and a mantle/collar (both dropped again) (a quiver was tried and dropped: "das ist aus meiner Sicht
kein Rüstungsteil").

**Phases 1–2 result (the user, 2026-10-20; `~/projects/grudgelands-orchestration/armor/proto/tiers.json`):** one
shared tier progression for all three lines, then thinned out per line so **metal is the bulkiest, leather less,
cloth smooth**. Metal keeps the whole selection above minus the crest. Leather drops the shoulder reinforcement,
flare, spikes and toe caps (keeps shoulder core, bracers, knee cops). Cloth also drops the shoulder core, bracers and
knee cops. Crest, hood point and mantle/collar left the catalog: **28 boxes, 864 vertices** with the body. Tassets on T4 for
metal only (deliberate).

**Ruling after phases 1–2 (the user, 2026-10-20):** "Alle sollten verfügbar sein, und Astra sollte sie auf allen
Tiers einsetzen dürfen. Das Ziel muss stattdessen ein Design-Ziel sein." Every box is available on every tier of
every line; the painter chooses per tier, guided by design goals (metal bulkier with each tier, leather layered,
cloth smooth and noble through ornament; at the same tier metal > leather > cloth; every tier visibly more). The
selections above are orientation, not rules. Alpha shaping (rounded corners, chamfers, filigree) is wanted; light
ornament on low tiers is allowed. Contract: `~/projects/grudgelands-orchestration/armor/spec/texture-format.md`;
style bible `spec/bible.py`, page https://claude.ai/artifact/5enZC9GDvdTiqPxMYKfyBF. Cross-bone z-fighting found by
the tool was fixed (chest, sleeve, bracer, leg pieces); `proto/check.py` now checks all bones in the rest pose.

**Game lane additions (the user, 2026-10-20):** the inventory 3D preview shows the new shapes and the equipped
weapon (a weapon card in the model on the right hand, transparent in the world where the wield entity is shown);
the web export for kaesual-stack (appearance version 2: armor atlas texture, new `.glb`, a handoff document for
the kaesual agent with a test character and a reference render); guards and kings use the same generated model,
filtered to the boxes NPCs wear (one generator, no second model to maintain).

**Phase 3 — style bible, templates and the render tool (coordinator, no art).** The render tool is the prototype's
three.js scene run headless (three.js vendored, no CDN): GPT-6 Astra calls it in its lane on its own textures and
gets front/back/side/three-quarter views at rest and walking, the icons at 16 and 32 px, and checks (hard alpha only,
zones A/B present and large enough, only the allowed palette indices, the overlap list of §5.1a).
- Per layout: which boxes are on, inner versus outer coverage, zones A/B.
- The index palette and the 18 palettes.
- UV templates for the skin and the atlas, labelled.
- The leather T4 name.
- The user reviews it before any pixel is drawn.

**Phase 4 — art (GPT-6 Astra, pick pages).**
- The 9 layouts in palette indices (inner paint, atlas paint, zone masks), two proposals each, picked on the 3D try-on
  page (rotate, walk, race, mixed slots, prefix and suffix colour).
- Then the 36 icon shapes. Palettes are tuned with the user on the page.
- Nothing unpicked ships.

**Phase 5 — game lanes (Opus, independent reviews).**
- **Model:** the generator from the catalog (Blockbench-compatible source is an option, §7) to the player and NPC
  `.b3d`, a glTF for the try-on page, the atlas layout, the checks (budget, spacing, cloak and leg clearance, pose
  clips from Round 40 unchanged).
- **Game:**
  - composition of skin and atlas;
  - a new appearance format version, with stored appearances rebuilt at login;
  - NPC models, the inventory preview, character creation;
  - enchant and broken layers on both parts;
  - the leather T4 rename;
  - removal of the old armor media and `tools/r10_art/build_armor_assets.sh`;
  - licence rows, fixtures.
- Item ids stay, so the release is compatible.

## 7. Open questions

1. **Shape source format:**
   - Our own JSON is enough for the prototype.
   - Blockbench (`.bbmodel`) would let the user reshape boxes in a free editor; worth it later?
2. **Rotation steps:** 22.5° only, or also 45°/90° only?
3. **Cloak and back plates:** move the cloak back while back plates are worn, or keep back shapes flat?
4. **NPC catalog:** which NPCs wear which layouts (guards T3–4 metal, bandits T1–2 leather/metal?), decided after
   phase 2.
