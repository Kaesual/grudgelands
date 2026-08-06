# Media Origin & Licenses (grug_mobs)

Taken from [VoxeLibre](https://git.minetest.land/VoxeLibre/VoxeLibre)
(`mods/ENTITIES/mobs_mc` + top-level `textures/`), harvested at upstream
commit `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`:

## Models (GPLv3)
By [22i](https://github.com/22i), Blender sources:
<https://github.com/22i/minecraft-voxel-blender-models>

- `grug_mobs_boar.b3d` (= `mobs_mc_pig.b3d`)
- `grug_mobs_zombie.b3d` (= `mobs_mc_zombie.b3d`)
- `grug_mobs_kraken.b3d` (= `mobs_mc_squid.b3d`, unmodified)

## Textures (CC BY-SA 4.0)
Based on "Pixel Perfection" by XSSheep, modifications by
MysticTempest (from VoxeLibre):

- `grug_mobs_boar.png` (= `mobs_mc_pig.png`)
- `grug_mobs_zombie.png` (= `mobs_mc_zombie.png`)
- `grug_mobs_kraken.png` (= `mobs_mc_squid.png`), retinted from squid blue
  to abyssal purple via ImageMagick
  (`magick mobs_mc_squid.png -modulate 70,150,167 grug_mobs_kraken.png`)

## Other
- `grug_mobs_blank.png`: 1×1 transparent, from the Luanti engine (LGPL 2.1+).
