# Media Origin & Licenses (grug_fishing)

One imported PNG and one runtime derivative. Nothing else in this mod is art.

## The rod — CC BY-SA 4.0

The player asked for this sprite by name in playtest round 5 ("VoxeLibre has a
rod that looks good, we should take it into the game"), and
`docs/research/licensing.md` §2/§3.2 allows it: CC BY-SA 4.0 media may be
reused as long as it stays under CC BY-SA 4.0 and carries the attribution the
licence asks for — creator, licence with its URL, a link to the original and an
indication of whether we changed it.

* Upstream project: VoxeLibre, <https://git.minetest.land/VoxeLibre/VoxeLibre>
* Commit (the submodule pin this row quotes):
  `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`
* Licence evidence: VoxeLibre's `LEGAL.md` — "The textures, unless otherwise
  noted, are based on the Pixel Perfection resource pack for Minecraft 1.11,
  authored by XSSheep … License: CC BY-SA 4.0". `mods/ITEMS/mcl_fishing`'s own
  `README.txt` names authors for its **sounds** only (CC0), so its textures
  fall under that default.
* Base pack: "Pixel Perfection" by
  [XSSheep](https://www.planetminecraft.com/member/xssheep/),
  <https://www.planetminecraft.com/texture_pack/131pixel-perfection/>
* Licence: [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)

| File | Upstream | Author chain | Modifications |
|---|---|---|---|
| `grug_fishing_rod.png` | `= textures/mcl_fishing_fishing_rod.png` (used by `mods/ITEMS/mcl_fishing/init.lua`) | XSSheep | **none** — byte-identical copy, renamed. sha256 `c1298c45d084302cec4aa32d0c3caeb973c1ec1291442f29bdb2bc880e37eb3d` |

The sprite is kept unmodified on purpose: it is already drawn in this game's
one held-item convention — long axis on the image's anti-diagonal, grip at the
bottom-left, an opaque pixel under the fist at (3, 12) — with the line and the
float hanging off the down-right side, which is the side
`mods/PLAYER/grug_visuals/wield_geometry.lua` turns into "downwards" in a hand.
Rotating or mirroring it would move the grip out from under the fist, which is
exactly the defect `grug_materials/overrides.lua` clears for `default`'s
shovels.

VoxeLibre's `mcl_fishing_fish_raw.png` and `mcl_fishing_fish_cooked.png` were
**not** imported; see below.

## The cooked fish — no new file

`grug_fishing:cooked_fish` ships **no PNG**. Its inventory image is the raw
fish this game already has, tinted at load time:

```
grug_mobs_item_raw_fish.png^[multiply:#d59a5a
```

That is the same runtime-derivative pattern `grug_gear` uses for its cloth line
and `grug_gathering` uses for its whole catalog. The source art is
`grug_mobs_item_raw_fish.png` — this project's own CC0 1.0 pixel art, generated
by `tools/gen_mob_item_textures.py` and documented in
[`mods/ENTITIES/grug_mobs/LICENSE-media.md`](../../ENTITIES/grug_mobs/LICENSE-media.md);
the derivative keeps that licence.

## Sounds

None of our own. The cast and the catch play `default_water_footstep`, the
unchanged vendored minetest_game sound whose notice stays in
`mods/BASE/default/license.txt`.
