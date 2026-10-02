# Media Origin & Licenses (grug_mapgen)

## Minetest Game flowers

* Repo: <https://github.com/minetest/minetest_game>
* Commit: `b5243f3e42410ae3ca85ead795149406fa654538`
* License evidence: `mods/flowers/README.txt` and top-level `LICENSE.txt`,
  CC BY-SA 3.0.

| File | Upstream | Author | License | Modifications |
|------|----------|--------|---------|---------------|
| `grug_mapgen_waterlily.png` | `mods/flowers/textures/flowers_waterlily.png` | Gambit | CC BY-SA 3.0 | renamed only; byte-identical |
| `grug_mapgen_waterlily_bottom.png` | `mods/flowers/textures/flowers_waterlily_bottom.png` | yyt16384, derived from Gambit | CC BY-SA 3.0 | renamed only; byte-identical |

## Waystone (Round 29)

Original art generated with OpenAI's built-in `image_gen.imagegen`; no
third-party source images. Central texture crops are exported as 16×16 RGBA
with nearest-neighbour sampling and palette reduction without dithering.
The stone surfaces fill every pixel, with opaque alpha and no border, so they
can repeat over the tall nodebox. The project dedicates any rights it holds
in these originals to CC0-1.0.

| File | Author | Source / design | Licence |
|---|---|---|---|
| `grug_mapgen_waystone.png` | GPT-6 Astra (Grudgelands) | Own work; weathered cool-grey stone with a faint carved blue rune | CC0-1.0 |
| `grug_mapgen_waystone_top.png` | GPT-6 Astra (Grudgelands) | Own work; matching stone grain with a small blue inset glint, for top and bottom | CC0-1.0 |
