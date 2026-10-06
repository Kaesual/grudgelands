# The player model as glTF

`grug_visuals_character.glb` is the player model of the game
(`mods/PLAYER/grug_visuals/models/grug_visuals_character.b3d`: player_api's
`character.b3d` with the Round 33 cloak) converted to binary glTF 2.0 for the
realm website (Round 39, [plan](../../../docs/planning/round39-web-data-plan.md)
§4.3). The game itself keeps using the `.b3d`. Licence and authors:
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
  race's visual size), the character **faces −z** (turn it 180° about y to
  face a camera on +z). Luanti's glTF loader mirrors z, so in the engine
  this file is exactly the `.b3d`: any engine-space point, also one given in
  a bone's local frame (an attachment offset), is `(x, y, −z)` here, and an
  engine rotation matrix `R` is `S·R·S` with `S = diag(1, 1, −1)`.
- **Mesh.** One skinned mesh `Character` on the root node `Player` with two
  primitives in the game's texture order (a stock loader such as three.js
  makes two meshes of them):

  | # | Material | Vertices | Triangles | Texture (`grug_visuals:appearance`) |
  |---|---|---|---|---|
  | 0 | `skin` | 168 | 84 | `textures.body`, 64×32 |
  | 1 | `cloak` | 24 | 12 | `textures.cloak`, 32×32; `none` = hide the primitive |

  The file holds **no images**: Luanti warns on them, and the website
  composes the textures itself. Draw them with nearest filtering, UV origin
  top left (in three.js `flipY = false`, as for any glTF texture) and alpha
  test 0.5 (both materials are `alphaMode: MASK`); the transparent pixels are
  holes (the hat layer, an empty cloak).
- **Skeleton.** `Body` (root) with `Head`, `Arm_Left`, `Arm_Right`,
  `Leg_Right`, `Leg_Left` and `Cloak`, names as in the game (`Arm_Right` is
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
  (sit, lay, mine, walk_mine) are one entry in `build_glb.py`'s `CLIPS` away.
- **Visual size.** The race's `visual_size` (in the appearance) scales the
  model per axis, as Luanti scales the mesh.

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
game). Copy it and the model into a **test world** (never a world you play):

```sh
W=~/.var/app/org.luanti.luanti/.minetest/worlds/<test world>
mkdir -p "$W/worldmods/grug_glb_probe/models"
cp tools/web_data/model/probe/mod.conf tools/web_data/model/probe/init.lua "$W/worldmods/grug_glb_probe/"
cp tools/web_data/model/grug_visuals_character.glb "$W/worldmods/grug_glb_probe/models/"
```

Join the world and type `/glb_probe` (needs the `server` privilege, which
singleplayer has). Three nodes ahead, facing you, stand the glTF model
(left, nametag `glb: …`) and the game's `.b3d` (right, `b3d: …`), both in
your current skin, cloak and size; every 4 seconds both switch between
stand and walk. They should look the same: body, cloak, both clips.
`/glb_probe clear` removes them; they are never saved. Remove the
`worldmods/grug_glb_probe` folder afterwards.
