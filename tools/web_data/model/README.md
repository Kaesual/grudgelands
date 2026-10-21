# The player model as glTF

`grug_visuals_character.glb` is the player model of the game
(`mods/PLAYER/grug_visuals/models/grug_visuals_character.b3d`: player_api's
`character.b3d` with the Round 33 cloak, the Round 54 armor boxes and
weapon card, and the Round 55 offhand, back card and cloak wings) converted to binary glTF 2.0 for the
realm website (Round 39, [plan](../../../docs/planning/round39-web-data-plan.md)
§4.3). The game itself keeps using the `.b3d`. The armored NPCs' model
(`grug_visuals_npc.b3d`, Round 54) is not converted: the website shows
player characters only. Licence and authors:
[LICENSE-media.md](LICENSE-media.md) (CC BY-SA 3.0).

| File | What |
|---|---|
| `grug_visuals_character.glb` | the model (committed output) |
| `build_glb.py` | the converter; `--check` exits 1 when the committed file is stale |
| `check_glb.py` | the test: the `.glb` against the `.b3d` |
| `probe/` | a GUI probe mod for Luanti (below) |

```sh
python3 tools/web_data/model/build_glb.py           # rewrite the glb
python3 tools/web_data/model/build_glb.py --check   # is it current?
python3 tools/web_data/model/check_glb.py           # does it match the b3d?
```

Both are Python 3 standard library. Rerun the converter whenever the `.b3d`
(`tools/r33_c3/gen_cloak_model.py`) or player_api's animation table changes.

## What the file contains

- **Coordinates.** glTF's own: right-handed, +y up, the feet on y = 0,
  **10 units = 1 node** (the character is 17.0 units tall without the
  race's visual size; the armor boxes reach from 0.26 below the soles to
  17.19), the character **faces −z** (turn it 180° about y to
  face a camera on +z). Luanti's glTF loader mirrors z, so in the engine
  this file is exactly the `.b3d`: any engine-space point, also one given in
  a bone's local frame (an attachment offset), is `(x, y, −z)` here, and an
  engine rotation matrix `R` is `S·R·S` with `S = diag(1, 1, −1)`.
- **Mesh.** One skinned mesh `Character` on the root node `Player` with seven
  primitives in the game's texture order (a stock loader such as three.js
  makes seven meshes of them):

  | # | Material | Vertices | Triangles | Texture (`grug_visuals:appearance`) |
  |---|---|---|---|---|
  | 0 | `skin` | 168 | 84 | `textures.body`, 64×32 |
  | 1 | `cloak` | 24 | 12 | `textures.cloak`, 32×32; `none` = hide the primitive |
  | 2 | `armor` | 672 | 336 | `textures.armor`, the armor atlas, 128×64; `none` (or a version 1 value, which has no `textures.armor`) = hide the primitive |
  | 3 | `weapon` | 8 | 4 | the weapon card: not stored; hide the primitive (below) |
  | 4 | `offhand` | 316 | 158 | the offhand atlas, 64×64 (three shield copies and the open book); **transparent by default** (below) |
  | 5 | `back` | 8 | 4 | the back card, an item image; **transparent by default** |
  | 6 | `wings` | 28 | 12 | a cloak's wing texture, 16×32; **transparent by default** |

  The file holds **no images**: Luanti warns on them, and the website
  composes the textures itself. Draw them with nearest filtering, UV origin
  top left (in three.js `flipY = false`, as for any glTF texture) and alpha
  test 0.5 (every material is `alphaMode: MASK`, cutoff 0.5: a hard cut-out,
  no blending); the transparent pixels are holes (the hat layer, an empty
  cloak, every armor box the worn pieces do not use).

  The **armor** primitive is every box of the armor catalog
  (`tools/r54_armor/data/catalog.json`, 28 boxes of 24 vertices) at once,
  each rigid on its bone; the atlas decides which show (a box a worn piece
  does not use is transparent), so the mesh never changes with the gear.
  The layout of the atlas is
  [armor-format.md](../../../docs/technical/armor-format.md) §3. The
  **weapon** primitive is a two-sided square on `Arm_Right` where the game's
  hand entity holds a diagonal tool at stature 1, UV 0..1 over the whole
  image; the game leaves it transparent in the world (the hand entity draws
  the weapon) and fills it only in the inventory's 3D view, which cannot
  attach entities. A website keeps drawing the weapon with the hand
  attachment of `web_data.json` (`wield`, per race and pose) and **hides the
  card** (or gives it a transparent texture); putting the hand image on the
  card as well would show the weapon twice, and the card is right only for
  the `tool` pose at stature 1.

  The three Round 55 primitives ([offhand-format.md](../../../docs/technical/offhand-format.md))
  are **transparent by default**: their materials' `baseColorFactor` alpha
  is 0, so a site that does not know them draws nothing (alpha test 0.5).
  The **offhand** primitive is the shield three times, one copy per size
  step, each sampling its own region of the offhand atlas, and the open
  spellbook, on the bones `Offhand_Shield` and `Offhand_Book`; the texture
  (a baked layer, format doc §7) paints only the copy of its size, the
  rest of the atlas is transparent. The **back** card is a two-sided
  square on `Body` (UV 0..1 over an item image), the **wings** two
  triangles on `Cloak`. To show one, give it its texture **and** set its
  material's base colour alpha to 1 (in three.js:
  `mesh.material.map = texture; mesh.material.opacity = 1;
  mesh.material.needsUpdate = true`, the GLTFLoader puts that alpha into
  `opacity`). Luanti reads only a material's texture index, so these
  factors change nothing in the game.
- **Skeleton.** `Body` (root) with `Head`, `Arm_Left`, `Arm_Right`,
  `Leg_Right`, `Leg_Left`, `Cloak` and the two swing bones `Panel_Front`
  and `Panel_Back` (hinged at the belt; the front and back armor panels
  swing with the legs, keyed in every clip), and under `Arm_Left` the two
  offhand bones `Offhand_Shield` and `Offhand_Book` (keyed in every clip
  from the offhand parameters), names as in the game (`Arm_Right` is
  the hand bone `grug_visuals/wield_geometry.lua` attaches to). Every vertex
  hangs on exactly one bone with weight 1.
- **Clips.** One named animation per player_api animation, each starting at
  0 s, linear keys on every bone:

  | Clip | Luanti frames | Keys | Duration |
  |---|---|---|---|
  | `stand` | 0–79 | 80 | 2.6333 s |
  | `walk` | 168–187 | 20 | 0.6333 s |

  glTF times are seconds, Luanti counts frames. player_api plays a range
  `x..y` at `animation_speed = 30` frames per second (15 while sneaking), so
  Luanti frame `f` of a clip is at `t = (f − x) / 30` s; each clip's `extras`
  repeats `luanti_frames` and `fps`. Looping, Luanti jumps from `y` straight
  back to `x` (no blend between them), which is what a repeating player does
  at the clip's end. In Luanti 5.17 the clips play by name:
  `obj:play_animation("walk", {speed = 1})`. The other player_api animations
  (sit, lay, mine, walk_mine) are one entry in `build_glb.py`'s `CLIPS` away,
  plus the same name in `tools/web_data/build.lua`'s animation list so the
  export carries its frame range.
- **Visual size.** The race's `visual_size` (in the appearance) scales the
  model per axis, as Luanti scales the mesh.
- **Head look.** In the game the head follows the player's look pitch
  ([character_visuals.md](../../../docs/design/character_visuals.md) §5d);
  the file has no clip for it, so a website head that follows the mouse
  rotates the `Head` node itself, on top of the playing clip. `Head` is a
  child of `Body`, which stands turned 180° about y, and its rest rotation
  under `Body` is the identity; its pivot is the neck. So the node's own +x
  points to the **character's left**, and a pitch `p` (radians, positive =
  looking up) is a rotation of **−p about the node's local x**, applied
  after the clip has set the frame: in three.js `head.rotateX(-p)` after
  `mixer.update()`. The game clamps `p` from **−50° (down) to +60° (up)**
  and moves in 5° steps; a website may move smoothly within the same clamp.
  (In the game's B3D frame the same pitch is +p about the Head bone's x: the
  glb mirrors z, which turns the sign of a rotation about x.) No head yaw:
  the game turns the whole character instead.

## How it was made and checked

`assimp` 6.0 was tried first (`assimp export … -fglb2`). `check_glb.py`
passes its geometry, skeleton, skin and poses but fails it on the clips —
one clip of all 221 frames on the file's own rate (60 fps, frame N at
N / 60 s) instead of player_api's named ranges at 30 fps — and on the
materials (one shared material for both buffers). Fixing that afterwards
means rewriting the glb, so `build_glb.py` writes it directly from the B3D
reader of `tools/r33_c3/gen_cloak_model.py`.

`check_glb.py` evaluates both files itself: the `.b3d` with the engine's B3D
rules (`irr/src/CB3DMeshFileLoader.cpp`, `SkinnedMesh`), the `.glb` with
plain glTF rules. It checks the glb's structure (chunks, buffer views,
accessor bounds and min/max, indices, the node tree, the skin, the
samplers, and what Luanti's loader refuses), the bone names and hierarchy,
vertex and triangle counts, positions, normals and UVs, the triangle winding
a culling viewer needs, the materials and their texture order, the weights,
the rest pose, and per clip the key count and duration against player_api
and the skinned bounding box and every skinned vertex at every frame and
half frame, within 0.001 units. The measured deviation is about 1e-6.

## The Luanti probe (GUI check)

A server does not decode meshes, so whether Luanti draws the glb is a check
in the client. `probe/` is a tiny mod (`grug_glb_probe`, not part of the
game). Copy it and the model into a **test world of the Grudgelands game**
(never a world you play; the probe needs the game's `grug_visuals`):

```sh
W=~/.var/app/org.luanti.luanti/.minetest/worlds/<test world>
mkdir -p "$W/worldmods/grug_glb_probe/models"
cp tools/web_data/model/probe/mod.conf tools/web_data/model/probe/init.lua "$W/worldmods/grug_glb_probe/"
cp tools/web_data/model/grug_visuals_character.glb "$W/worldmods/grug_glb_probe/models/"
```

Join the world and type `/glb_probe` (needs the `server` privilege, which
singleplayer has). Three nodes ahead, facing you, stand the glTF model
(left, nametag `glb: …`) and the game's `.b3d` (right, `b3d: …`), both in
your current textures (skin, cloak, armor, the empty weapon card) and size;
every 4 seconds both switch between stand and walk. They should look the
same: body, cloak, armor, the swinging panels, both clips. A headless shot
of the same comparison (Round 54, the test character of
`tools/r54_web/test_character.json`) is taken by `tools/r54_model/capture.sh`
with `SCENE=tools/r54_web/scene.lua` and `MODELS=` a folder holding this
`.glb` (`tools/r54_web/gen_test_character.lua` says how).
`/glb_probe clear` removes them; they are never saved. Remove the
`worldmods/grug_glb_probe` folder afterwards.
