# Media Origin & Licenses (grug_traders)

## Own pixel art — CC0 1.0

Original 16×16 art of this project, **not** derived from any vendored or
third-party asset. Authored as an ASCII map plus a palette in
`tools/gen_mob_item_textures.py` (list `TRADER_ICONS`) and generated
deterministically — re-running the script reproduces the PNG byte for byte.

**License: CC0 1.0 Universal** (<https://creativecommons.org/publicdomain/zero/1.0/>).

| File | Author | License | Notes |
|------|--------|---------|-------|
| `grug_traders_item_potion_healing_weak.png` | Grudgelands project | CC0 1.0 | generator, art `POTION_FLASK`, corked round flask with red liquid |

## Reused media — no files in this mod

The vendor NPCs carry **no media of their own**. They reference, by name only
(Luanti's media namespace is flat), assets that live in other mods and are
licensed there:

| Asset | Lives in | Used for |
|-------|----------|----------|
| `character.b3d` | `mods/BASE/player_api/models` | vendor mesh |
| `grug_mobs_guard_accord.png` | `mods/ENTITIES/grug_mobs/textures` | Accord-side vendor skin |
| `grug_mobs_guard_throng.png` | `mods/ENTITIES/grug_mobs/textures` | Throng-side vendor skin |

This is a **placeholder**: a Quartermaster currently looks exactly like a
faction guard. Dedicated vendor art (and race-specific skins for the six race
vendors) is a WP13 asset task.
