# Media Origin & Licenses (grug_gear)

## Own pixel art — CC0 1.0

Original 16×16 art of this project, **not** derived from any vendored or
third-party asset. Authored as ASCII maps plus a palette in
`tools/gen_mob_item_textures.py` (list `GEAR_ICONS`) and generated
deterministically — re-running the script reproduces every PNG byte for byte.

**License: CC0 1.0 Universal** (<https://creativecommons.org/publicdomain/zero/1.0/>).

Only eight base arts exist: the four weapon families and the four metal armor
slots. The cloth line **reuses the metal arts with a cloth palette** (same
trick as `FEATHER`/`BOLT` in the mob icons), and the six brackets are
differentiated at runtime by a `^[multiply:<tint>` modifier — one PNG per
family, not one per bracket.

| File | Author | License | Notes |
|------|--------|---------|-------|
| `grug_gear_item_sword.png` | Grudgelands project | CC0 1.0 | generator, art `SWORD`, steel + brass guard |
| `grug_gear_item_dagger.png` | Grudgelands project | CC0 1.0 | generator, art `DAGGER` (short blade, same steel palette) |
| `grug_gear_item_greataxe.png` | Grudgelands project | CC0 1.0 | generator, art `GREATAXE`, dark iron head on an ash haft |
| `grug_gear_item_staff.png` | Grudgelands project | CC0 1.0 | generator, art `STAFF`, wooden shaft with metal bands and a blue focus crystal |
| `grug_gear_item_head_metal.png` | Grudgelands project | CC0 1.0 | generator, art `ARMOR_HEAD`, metal palette |
| `grug_gear_item_chest_metal.png` | Grudgelands project | CC0 1.0 | generator, art `ARMOR_CHEST`, metal palette |
| `grug_gear_item_legs_metal.png` | Grudgelands project | CC0 1.0 | generator, art `ARMOR_LEGS`, metal palette |
| `grug_gear_item_feet_metal.png` | Grudgelands project | CC0 1.0 | generator, art `ARMOR_FEET`, metal palette |
| `grug_gear_item_head_cloth.png` | Grudgelands project | CC0 1.0 | generator, art `ARMOR_HEAD`, cloth palette (violet) |
| `grug_gear_item_chest_cloth.png` | Grudgelands project | CC0 1.0 | generator, art `ARMOR_CHEST`, cloth palette |
| `grug_gear_item_legs_cloth.png` | Grudgelands project | CC0 1.0 | generator, art `ARMOR_LEGS`, cloth palette |
| `grug_gear_item_feet_cloth.png` | Grudgelands project | CC0 1.0 | generator, art `ARMOR_FEET`, cloth palette |
