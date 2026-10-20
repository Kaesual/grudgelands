# Media Origin & Licenses (tools/web_data/model)

## Round 39 player model as glTF (Round 54: armor and weapon card) — CC BY-SA 3.0

| File | Author | License | Notes |
|------|--------|---------|-------|
| `grug_visuals_character.glb` | celeron55, MirceaKitsune, Jordach et al. (player_api `character.b3d`); cloak, armor boxes and weapon card by the Grudgelands project | CC BY-SA 3.0 (<https://creativecommons.org/licenses/by-sa/3.0/>), as its source | a format conversion of `mods/PLAYER/grug_visuals/models/grug_visuals_character.b3d` (itself derived from `mods/BASE/player_api/models/character.b3d`, licence `mods/BASE/player_api/license.txt`, by `tools/r33_c3/gen_cloak_model.py`: a cloak box and a `Cloak` bone appended (Round 33), the armor boxes, the swing bones `Panel_Front` and `Panel_Back` and the weapon card appended (Round 54); see `mods/PLAYER/grug_visuals/LICENSE-media.md`, "Player and NPC models") to binary glTF 2.0 by `tools/web_data/model/build_glb.py`: the same mesh, bones and skin with z mirrored for glTF's handedness, the player_api animations `stand` and `walk` as separate clips timed in seconds, four primitives (skin, cloak, armor, weapon card), no textures. The file's `asset.copyright` names the licence and authors |
