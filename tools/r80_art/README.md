# The donor cloaks (Round 80)

The six donor cloaks the game ships as website-account rewards, and where they come from. Lane REWARDS
of Round 80 ([plan](../../docs/planning/round80-plan.md) §2 rulings 4–6, §4 REWARDS).

- `src/drop-01/paint.py` and `src/drop-02/paint.py`: the painters of the two cloak drops, unchanged as
  delivered, with each drop's `LICENSE.txt`. Drop 01 painted eighteen first drafts; Drop 02 refines six of
  them twice (`r1`, `r2`), every refinement with wings. Drop 02 imports Drop 01's painting helpers and reads
  Drop 01's `catalog.json` and one of its cloaks, so both painters run, in that order.
  **Licence:** own work, AI-assisted, by **GPT-6 Astra**, **CC0 1.0**
  (<https://creativecommons.org/publicdomain/zero/1.0/>): deterministic Python/Pillow pixel authorship, no
  image-generation service, downloads or third-party source pixels.
- `picks.json`: the user's picks of 2026-11-16 (the drop and, per cloak id, the painted art id):

  | Cloak id | Name | Pick |
  |---|---|---|
  | `emberwake` | Emberwake | `hearthkeeper_1_r1` |
  | `veilstream` | Veilstream | `aurora_1_r2` |
  | `pearlwing` | Pearlwing | `moonsilk_2_r1` |
  | `moonfall` | Moonfall | `moonsilk_3_r2` |
  | `wintercourt` | Wintercourt | `royal_ermine_1_r2` |
  | `frost_regent` | Frost Regent | `royal_ermine_3_r2` |

- `assemble.py`: runs both painters on a copy in a temporary directory and copies each pick's
  `cloak_<art id>.png` and `wings_<art id>.png` into `mods/PLAYER/grug_achievements/textures` as
  `grug_achievements_cloak_<id>.png` and `grug_achievements_cloak_<id>_wings.png` (the cloak format of
  [character_visuals.md](../../docs/design/character_visuals.md) §5b, the wings of
  [offhand-format.md](../../docs/technical/offhand-format.md) §6). Every pick needs its wings (reward cloaks
  always have wings, the user's ruling of 2026-11-16). On 2026-11-16 the twelve textures were byte-identical
  to the delivered PNGs of Drop 02.

```sh
python3 tools/r80_art/assemble.py --check   # the shipped textures equal painters + picks (pixels); exit 1 if not
python3 tools/r80_art/assemble.py           # rewrite them
```

The game side: the six rows in `grug_achievements/catalog.lua` (`account = true`, no achievement), each the
website-account reward `cloak:<id>`; their licence rows in `grug_achievements/LICENSE-media.md`.
