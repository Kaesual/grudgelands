# Media licenses — grug_signs

## The signs (Round 68)

Lane ART's picked candidates (the user's picks of 2026-10-31: standing sign
A, waypost B, notice board B; their wood texture set B, warm heartwood,
from ART's pass 3; the notice board in two node halves from pass 4),
original work authored for Grudgelands by
**GPT-6 Astra** in Round 68 and drawn entirely by
`tools/r68_art/generate.py` (GPL-3.0-or-later) with Python, Pillow and
numpy; no source image pixels, external images or fonts enter them
(`tools/r68_art/LICENSE-media.md`). The project dedicates any rights it
holds in them to **CC0-1.0**
(<https://creativecommons.org/publicdomain/zero/1.0/>).

Copied byte for byte from `tools/r68_art/candidates/` and renamed under the
mod prefix. The models keep their `mtllib` line; the engine ignores it and
the MTL files are not shipped. Luanti's OBJ loader mirrors x on load, so
the game shows each model mirrored (see `init.lua`).

| File | Source in `tools/r68_art/candidates/` | License |
|---|---|---|
| `models/grug_signs_standing.obj` | `sign_standing_a.obj`, unchanged | CC0-1.0 |
| `textures/grug_signs_standing.png` | `sign_standing_wood_b.png`, unchanged | CC0-1.0 |
| `textures/grug_signs_standing_inv.png` | `sign_standing_wood_b_inv.png`, unchanged | CC0-1.0 |
| `models/grug_signs_waypost.obj` | `waypost_b.obj`, unchanged | CC0-1.0 |
| `textures/grug_signs_waypost.png` | `waypost_wood_b.png`, unchanged | CC0-1.0 |
| `textures/grug_signs_waypost_inv.png` | `waypost_wood_b_inv.png`, unchanged | CC0-1.0 |
| `models/grug_signs_notice_board_main.obj` | `notice_board_b_left.obj`, unchanged (the board's node) | CC0-1.0 |
| `models/grug_signs_notice_board_part.obj` | `notice_board_b_right.obj`, unchanged (the part's node) | CC0-1.0 |
| `textures/grug_signs_notice_board.png` | `notice_board_wood_b.png`, unchanged | CC0-1.0 |
| `textures/grug_signs_notice_board_inv.png` | `notice_board_wood_b_inv.png`, unchanged | CC0-1.0 |
