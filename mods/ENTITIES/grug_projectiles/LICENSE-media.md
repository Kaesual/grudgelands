# Media Origin & Licenses (grug_projectiles)

## Arrow projectile

The following files are unchanged renamed copies from VoxeLibre commit
`c2dbc520ff4e1637072d33b06c3a2404e0f08df7`. The `mcl_bows` README sends
textures to VoxeLibre's top-level license notes. Those notes identify textures
based on XSSheep / Pixel Perfection as CC BY-SA 4.0. The OBJ has no narrower
per-file notice, so it follows the same document's CC BY-SA 3.0 default for all
other media.

| Local file | Upstream source | Treatment |
|---|---|---|
| `models/grug_projectiles_arrow.obj` | `mods/ITEMS/mcl_bows/models/mcl_bows_arrow.obj` | CC BY-SA 3.0; unchanged renamed copy |
| `textures/grug_projectiles_arrow.png` | `textures/mcl_bows_arrow.png` | CC BY-SA 4.0; unchanged renamed copy |

The OBJ is static projectile geometry: crossed planes forming a shaft, head
and fletching. It is not a creature or character model and has no locomotion
state, skeleton or animation clips. Runtime code rotates the whole entity to
its current velocity, including its changing vertical component under gravity.
The animated-mesh requirement for imported creatures therefore does not apply
to this deliberately rigid projectile.
