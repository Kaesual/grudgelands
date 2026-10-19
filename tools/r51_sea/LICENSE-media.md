# Round 51 ARTS — Media provenance

## Original textures

Author: **GPT-6 Astra**, 2026-10-19, for Grudgelands. Original pixel grids,
palettes and deterministic grain; no downloaded, traced or recoloured source
pixels. The project dedicates any rights it holds in these files and the
original generator and lettering to **CC0 1.0 Universal (CC0-1.0)**:
<https://creativecommons.org/publicdomain/zero/1.0/>.

| File | Author | Source | Exact license | Modifications |
| --- | --- | --- | --- | --- |
| `seagrass_1.png` | GPT-6 Astra | [sea_art.py](sea_art.py) | CC0-1.0 | Original fine-bladed bunch |
| `seagrass_2.png` | GPT-6 Astra | [sea_art.py](sea_art.py) | CC0-1.0 | Original low swept bunch |
| `seagrass_3.png` | GPT-6 Astra | [sea_art.py](sea_art.py) | CC0-1.0 | Original open fan |
| `wreck_planks.png` | GPT-6 Astra | [sea_art.py](sea_art.py) | CC0-1.0 | Original opaque plank texture |
| `wreck_planks_algae.png` | GPT-6 Astra | [sea_art.py](sea_art.py) | CC0-1.0 | Original algae painted onto the original planks |
| `wreck_log.png` | GPT-6 Astra | [sea_art.py](sea_art.py) | CC0-1.0 | Original hewn timber side |
| `wreck_log_top.png` | GPT-6 Astra | [sea_art.py](sea_art.py) | CC0-1.0 | Original end grain and splits |
| `wreck_mast.png` | GPT-6 Astra | [sea_art.py](sea_art.py) | CC0-1.0 | Original four-pixel pole, vertically periodic |
| `wreck_rope.png` | GPT-6 Astra | [sea_art.py](sea_art.py) | CC0-1.0 | Original coil and frayed tail |
| `wreck_sail.png` | GPT-6 Astra | [sea_art.py](sea_art.py) | CC0-1.0 | Original ragged canvas and peg |
| `wreck_algae.png` | GPT-6 Astra | [sea_art.py](sea_art.py) | CC0-1.0 | Original branching tuft |

## Comparison only

| File | Authors | Source | Exact license | Modifications |
| --- | --- | --- | --- | --- |
| `preview.png` | GPT-6 Astra (original artwork, layout and pixel lettering); VanessaE, tobyplowy, Topywo, Cisoun (references below) | [sea_art.py](sea_art.py) and local references below | CC BY-SA 3.0 Unported for the composite | Nearest-neighbour scaling, repetition, alpha compositing, RGB tinting and light multiplication, labels; water reduced to its mean RGB |

The comparison contains references under **CC BY-SA 3.0 Unported**:
<https://creativecommons.org/licenses/by-sa/3.0/>. Its original contributions
are also offered under that licence for distribution of the composite.
The eleven separate new textures remain CC0-1.0.

Each reference is read from `mods/BASE/default/textures/` in this checkout.
Attribution and licences were verified in the vendored source's
[README.txt](../../mods/BASE/default/README.txt) and
[license.txt](../../mods/BASE/default/license.txt); the pinned revision is
recorded in [VENDOR.md](../../VENDOR.md). These are existing project media,
not new imports. The authors are covered by the vendored contributors entry
in [CREDITS.md](../../CREDITS.md#textures-and-models).

| Local filename | Author | Pinned source URL | Exact license | Preview use |
| --- | --- | --- | --- | --- |
| `default_sand.png` | VanessaE | [Source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_sand.png) | CC BY-SA 3.0 Unported | Repeated meadow bases, scaled and tinted |
| `default_kelp.png` | tobyplowy | [Source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_kelp.png) | CC BY-SA 3.0 Unported | Two-node repetitions beside seagrass, scaled and tinted |
| `default_coral_green.png` | Topywo | [Source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_coral_green.png) | CC BY-SA 3.0 Unported | Coral beside seagrass, scaled and tinted |
| `default_tree.png` | Cisoun | [Source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_tree.png) | CC BY-SA 3.0 Unported | Unmodified bark sample, enlarged 4× |
| `default_tree_top.png` | Cisoun | [Source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_tree_top.png) | CC BY-SA 3.0 Unported | Unmodified cut-end sample, enlarged 4× |
| `default_water.png` | Cisoun | [Source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_water.png) | CC BY-SA 3.0 Unported | Mean RGB used for three illustrative depth tints |
