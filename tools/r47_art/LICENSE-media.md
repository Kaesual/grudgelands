# Round 47 ART — Media provenance

## Original swamp textures

Made by **GPT-6 Astra**, 2026-10-13, for Grudgelands, from independently
authored pixel grids, palettes and deterministic material grain.
The project dedicates any rights it holds in these original assets and
their generator to **CC0 1.0 Universal (CC0-1.0)**:
<https://creativecommons.org/publicdomain/zero/1.0/>.
No downloaded material or third-party source pixels are used in them.

The complete source is
[`tools/r47_art/swamp/generate.py`](swamp/generate.py), executed with
`python3 tools/r47_art/swamp/generate.py` using installed Pillow 12.3.0.

| File | Author | Source / generator | License | Modifications |
| --- | --- | --- | --- | --- |
| `swamp/mud_dry_top.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |
| `swamp/mud_dry_side.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |
| `swamp/mud_mottled_top.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |
| `swamp/mud_mottled_side.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |
| `swamp/wet_grass_top.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |
| `swamp/wet_grass_side.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |
| `swamp/moss_carpet_top.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |
| `swamp/reeds.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |
| `swamp/cattails.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |
| `swamp/hanging_moss.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |

## Comparison sheet

| File | Author | Source / generator | License | Modifications |
| --- | --- | --- | --- | --- |
| `swamp/preview.png` | GPT-6 Astra (layout, font and new artwork); Calinou (papyrus); random-geek and Neuromancer (source dirt), Grudgelands contributors (mud recolour) | [generate.py](swamp/generate.py), with the two local references below | CC BY-SA 3.0 Unported for the comparison; the separately supplied original textures remain CC0-1.0 | Nearest-neighbour enlargement, repetition, alpha compositing on plain backgrounds and labels |

The comparison includes existing media under **CC BY-SA 3.0 Unported**
(<https://creativecommons.org/licenses/by-sa/3.0/>); it is not entirely
CC0. The original work contributed to the comparison is also offered
under that licence to distribute the combined sheet.

- **Papyrus:** Calinou,
  [`default_papyrus.png`](../../mods/BASE/default/textures/default_papyrus.png),
  CC BY-SA 3.0, source:
  <https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_papyrus.png>;
  nearest-neighbour scaling and compositing only.
- **Current mud:** Grudgelands contributors' olive recolour of
  `default_dirt.png`, by random-geek, derived from Neuromancer,
  CC BY-SA 3.0; local reference:
  [`grug_nodes_mud.png`](../../mods/ITEMS/grug_nodes/textures/grug_nodes_mud.png),
  original source:
  <https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_dirt.png>;
  the comparison only scales and repeats the existing recoloured asset.

Attribution and licence checked in the vendored
[`default/README.txt`](../../mods/BASE/default/README.txt),
[`default/license.txt`](../../mods/BASE/default/license.txt) and the
[`grug_nodes` media ledger](../../mods/ITEMS/grug_nodes/LICENSE-media.md).
Existing project attribution is also in [CREDITS.md](../../CREDITS.md).
