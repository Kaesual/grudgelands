# Round 68 ICONS — installation handoff

**Picked by the user on 2026-10-31:** bars and metal blocks A,
settings B, cut gems and gem blocks D (Abyssal Crystal block unchanged).
`gems_final/` combines D with the eight larger pass-3 raw specimens.

**Compatible presentation change; no migration or map reset.** This
art lane installs nothing. The later installation lane copies the
47 picked PNGs below byte for byte, adds the mod prefix shown below,
and changes the corresponding inventory image or all-six-face tile.
All files are 16 × 16 RGBA: 30 transparent items and 17 opaque faces.

Copy all 21 files from `candidates/gems_final/` as one gem group,
all 20 from `candidates/bars_a/`, and all 6 from `candidates/settings_b/`.
Keep A/B/C/D here as the art record; do not ship the comparison images.

The destination column is relative to `mods/ITEMS/`. The current
expression column is fully expanded from the Lua data; citations name
both the data and the registration that consumes it. Check these
against the installation branch if its source lines have moved.

| Picked candidate (relative to this directory) | Item or node id | Destination | Current image expression replaced | Source and use |
|---|---|---|---|---|
| [candidates/bars_a/copper_bar.png](candidates/bars_a/copper_bar.png) | `grug_materials:copper_bar` | `grug_materials/textures/grug_materials_copper_bar.png` | `default_copper_ingot.png` | [ores.lua:92](../../mods/ITEMS/grug_materials/ores.lua#L92), [ores.lua:119](../../mods/ITEMS/grug_materials/ores.lua#L119) |
| [candidates/bars_a/tin_bar.png](candidates/bars_a/tin_bar.png) | `grug_materials:tin_bar` | `grug_materials/textures/grug_materials_tin_bar.png` | `default_tin_ingot.png` | [ores.lua:93](../../mods/ITEMS/grug_materials/ores.lua#L93), [ores.lua:119](../../mods/ITEMS/grug_materials/ores.lua#L119) |
| [candidates/bars_a/bronze_bar.png](candidates/bars_a/bronze_bar.png) | `grug_materials:bronze_bar` | `grug_materials/textures/grug_materials_bronze_bar.png` | `default_bronze_ingot.png` | [ores.lua:94](../../mods/ITEMS/grug_materials/ores.lua#L94), [ores.lua:119](../../mods/ITEMS/grug_materials/ores.lua#L119) |
| [candidates/bars_a/iron_bar.png](candidates/bars_a/iron_bar.png) | `grug_materials:iron_bar` | `grug_materials/textures/grug_materials_iron_bar.png` | `default_steel_ingot.png` | [ores.lua:95](../../mods/ITEMS/grug_materials/ores.lua#L95), [ores.lua:119](../../mods/ITEMS/grug_materials/ores.lua#L119) |
| [candidates/bars_a/steel_bar.png](candidates/bars_a/steel_bar.png) | `grug_materials:steel_bar` | `grug_materials/textures/grug_materials_steel_bar.png` | `default_steel_ingot.png^[colorize:#34404a:75` | [ores.lua:96](../../mods/ITEMS/grug_materials/ores.lua#L96), [ores.lua:119](../../mods/ITEMS/grug_materials/ores.lua#L119) |
| [candidates/bars_a/silver_bar.png](candidates/bars_a/silver_bar.png) | `grug_materials:silver_bar` | `grug_materials/textures/grug_materials_silver_bar.png` | `default_tin_ingot.png^[colorize:#f4f6fa:90` | [ores.lua:98](../../mods/ITEMS/grug_materials/ores.lua#L98), [ores.lua:119](../../mods/ITEMS/grug_materials/ores.lua#L119) |
| [candidates/bars_a/silversteel_bar.png](candidates/bars_a/silversteel_bar.png) | `grug_materials:silversteel_bar` | `grug_materials/textures/grug_materials_silversteel_bar.png` | `default_steel_ingot.png^[colorize:#b7c9df:95` | [ores.lua:100](../../mods/ITEMS/grug_materials/ores.lua#L100), [ores.lua:119](../../mods/ITEMS/grug_materials/ores.lua#L119) |
| [candidates/bars_a/embersteel_bar.png](candidates/bars_a/embersteel_bar.png) | `grug_materials:embersteel_bar` | `grug_materials/textures/grug_materials_embersteel_bar.png` | `default_steel_ingot.png^[colorize:#b94b24:110` | [ores.lua:102](../../mods/ITEMS/grug_materials/ores.lua#L102), [ores.lua:119](../../mods/ITEMS/grug_materials/ores.lua#L119) |
| [candidates/bars_a/abyssal_steel_bar.png](candidates/bars_a/abyssal_steel_bar.png) | `grug_materials:abyssal_steel_bar` | `grug_materials/textures/grug_materials_abyssal_steel_bar.png` | `default_steel_ingot.png^[colorize:#3a245d:135` | [ores.lua:104](../../mods/ITEMS/grug_materials/ores.lua#L104), [ores.lua:119](../../mods/ITEMS/grug_materials/ores.lua#L119) |
| [candidates/bars_a/gold_bar.png](candidates/bars_a/gold_bar.png) | `grug_materials:gold_bar` | `grug_materials/textures/grug_materials_gold_bar.png` | `default_gold_ingot.png` | [ores.lua:106](../../mods/ITEMS/grug_materials/ores.lua#L106), [ores.lua:119](../../mods/ITEMS/grug_materials/ores.lua#L119) |
| [candidates/bars_a/copper_block.png](candidates/bars_a/copper_block.png) | `grug_materials:copper_block` | `grug_materials/textures/grug_materials_copper_block.png` | `default_copper_block.png` | [ores.lua:92](../../mods/ITEMS/grug_materials/ores.lua#L92), [ores.lua:128](../../mods/ITEMS/grug_materials/ores.lua#L128) |
| [candidates/bars_a/tin_block.png](candidates/bars_a/tin_block.png) | `grug_materials:tin_block` | `grug_materials/textures/grug_materials_tin_block.png` | `default_tin_block.png` | [ores.lua:93](../../mods/ITEMS/grug_materials/ores.lua#L93), [ores.lua:128](../../mods/ITEMS/grug_materials/ores.lua#L128) |
| [candidates/bars_a/bronze_block.png](candidates/bars_a/bronze_block.png) | `grug_materials:bronze_block` | `grug_materials/textures/grug_materials_bronze_block.png` | `default_bronze_block.png` | [ores.lua:94](../../mods/ITEMS/grug_materials/ores.lua#L94), [ores.lua:128](../../mods/ITEMS/grug_materials/ores.lua#L128) |
| [candidates/bars_a/iron_block.png](candidates/bars_a/iron_block.png) | `grug_materials:iron_block` | `grug_materials/textures/grug_materials_iron_block.png` | `default_steel_block.png` | [ores.lua:95](../../mods/ITEMS/grug_materials/ores.lua#L95), [ores.lua:128](../../mods/ITEMS/grug_materials/ores.lua#L128) |
| [candidates/bars_a/steel_block.png](candidates/bars_a/steel_block.png) | `grug_materials:steel_block` | `grug_materials/textures/grug_materials_steel_block.png` | `default_steel_block.png^[colorize:#34404a:75` | [ores.lua:97](../../mods/ITEMS/grug_materials/ores.lua#L97), [ores.lua:128](../../mods/ITEMS/grug_materials/ores.lua#L128) |
| [candidates/bars_a/silver_block.png](candidates/bars_a/silver_block.png) | `grug_materials:silver_block` | `grug_materials/textures/grug_materials_silver_block.png` | `default_tin_block.png^[colorize:#f4f6fa:90` | [ores.lua:99](../../mods/ITEMS/grug_materials/ores.lua#L99), [ores.lua:128](../../mods/ITEMS/grug_materials/ores.lua#L128) |
| [candidates/bars_a/silversteel_block.png](candidates/bars_a/silversteel_block.png) | `grug_materials:silversteel_block` | `grug_materials/textures/grug_materials_silversteel_block.png` | `default_steel_block.png^[colorize:#b7c9df:95` | [ores.lua:101](../../mods/ITEMS/grug_materials/ores.lua#L101), [ores.lua:128](../../mods/ITEMS/grug_materials/ores.lua#L128) |
| [candidates/bars_a/embersteel_block.png](candidates/bars_a/embersteel_block.png) | `grug_materials:embersteel_block` | `grug_materials/textures/grug_materials_embersteel_block.png` | `default_steel_block.png^[colorize:#b94b24:110` | [ores.lua:103](../../mods/ITEMS/grug_materials/ores.lua#L103), [ores.lua:128](../../mods/ITEMS/grug_materials/ores.lua#L128) |
| [candidates/bars_a/abyssal_steel_block.png](candidates/bars_a/abyssal_steel_block.png) | `grug_materials:abyssal_steel_block` | `grug_materials/textures/grug_materials_abyssal_steel_block.png` | `default_steel_block.png^[colorize:#3a245d:135` | [ores.lua:105](../../mods/ITEMS/grug_materials/ores.lua#L105), [ores.lua:128](../../mods/ITEMS/grug_materials/ores.lua#L128) |
| [candidates/bars_a/gold_block.png](candidates/bars_a/gold_block.png) | `grug_materials:gold_block` | `grug_materials/textures/grug_materials_gold_block.png` | `default_gold_block.png` | [ores.lua:106](../../mods/ITEMS/grug_materials/ores.lua#L106), [ores.lua:128](../../mods/ITEMS/grug_materials/ores.lua#L128) |
| [candidates/settings_b/setting_tin.png](candidates/settings_b/setting_tin.png) | `grug_artisans:setting_tin` | `grug_artisans/textures/grug_artisans_setting_tin.png` | `default_gold_ingot.png^[colorize:#b7a289:100` | [goldsmith.lua:27](../../mods/ITEMS/grug_artisans/goldsmith.lua#L27), [goldsmith.lua:53](../../mods/ITEMS/grug_artisans/goldsmith.lua#L53), [goldsmith.lua:54](../../mods/ITEMS/grug_artisans/goldsmith.lua#L54) |
| [candidates/settings_b/setting_iron.png](candidates/settings_b/setting_iron.png) | `grug_artisans:setting_iron` | `grug_artisans/textures/grug_artisans_setting_iron.png` | `default_gold_ingot.png^[colorize:#8c8c86:100` | [goldsmith.lua:28](../../mods/ITEMS/grug_artisans/goldsmith.lua#L28), [goldsmith.lua:53](../../mods/ITEMS/grug_artisans/goldsmith.lua#L53), [goldsmith.lua:54](../../mods/ITEMS/grug_artisans/goldsmith.lua#L54) |
| [candidates/settings_b/setting_copper_inlaid_steel.png](candidates/settings_b/setting_copper_inlaid_steel.png) | `grug_artisans:setting_copper_inlaid_steel` | `grug_artisans/textures/grug_artisans_setting_copper_inlaid_steel.png` | `default_gold_ingot.png^[colorize:#6f7781:100` | [goldsmith.lua:29](../../mods/ITEMS/grug_artisans/goldsmith.lua#L29), [goldsmith.lua:53](../../mods/ITEMS/grug_artisans/goldsmith.lua#L53), [goldsmith.lua:54](../../mods/ITEMS/grug_artisans/goldsmith.lua#L54) |
| [candidates/settings_b/setting_gold.png](candidates/settings_b/setting_gold.png) | `grug_artisans:setting_gold` | `grug_artisans/textures/grug_artisans_setting_gold.png` | `default_gold_ingot.png^[colorize:#ddb64d:100` | [goldsmith.lua:31](../../mods/ITEMS/grug_artisans/goldsmith.lua#L31), [goldsmith.lua:53](../../mods/ITEMS/grug_artisans/goldsmith.lua#L53), [goldsmith.lua:54](../../mods/ITEMS/grug_artisans/goldsmith.lua#L54) |
| [candidates/settings_b/setting_gold_filigreed_embersteel.png](candidates/settings_b/setting_gold_filigreed_embersteel.png) | `grug_artisans:setting_gold_filigreed_embersteel` | `grug_artisans/textures/grug_artisans_setting_gold_filigreed_embersteel.png` | `default_gold_ingot.png^[colorize:#9e633e:100` | [goldsmith.lua:32](../../mods/ITEMS/grug_artisans/goldsmith.lua#L32), [goldsmith.lua:53](../../mods/ITEMS/grug_artisans/goldsmith.lua#L53), [goldsmith.lua:54](../../mods/ITEMS/grug_artisans/goldsmith.lua#L54) |
| [candidates/settings_b/setting_gold_filigreed_abyssal_steel.png](candidates/settings_b/setting_gold_filigreed_abyssal_steel.png) | `grug_artisans:setting_gold_filigreed_abyssal_steel` | `grug_artisans/textures/grug_artisans_setting_gold_filigreed_abyssal_steel.png` | `default_gold_ingot.png^[colorize:#59436f:100` | [goldsmith.lua:34](../../mods/ITEMS/grug_artisans/goldsmith.lua#L34), [goldsmith.lua:53](../../mods/ITEMS/grug_artisans/goldsmith.lua#L53), [goldsmith.lua:54](../../mods/ITEMS/grug_artisans/goldsmith.lua#L54) |
| [candidates/gems_final/rough_citrine.png](candidates/gems_final/rough_citrine.png) | `grug_materials:rough_citrine` | `grug_materials/textures/grug_materials_rough_citrine.png` | `default_diamond.png^[colorize:#d9a21b:190` | [ores.lua:22](../../mods/ITEMS/grug_materials/ores.lua#L22), [ores.lua:61](../../mods/ITEMS/grug_materials/ores.lua#L61) |
| [candidates/gems_final/cut_citrine.png](candidates/gems_final/cut_citrine.png) | `grug_materials:cut_citrine` | `grug_materials/textures/grug_materials_cut_citrine.png` | `default_diamond.png^[colorize:#d9a21b:190^[brighten` | [ores.lua:22](../../mods/ITEMS/grug_materials/ores.lua#L22), [ores.lua:67](../../mods/ITEMS/grug_materials/ores.lua#L67) |
| [candidates/gems_final/rough_jade.png](candidates/gems_final/rough_jade.png) | `grug_materials:rough_jade` | `grug_materials/textures/grug_materials_rough_jade.png` | `default_diamond.png^[colorize:#3d9b65:190` | [ores.lua:24](../../mods/ITEMS/grug_materials/ores.lua#L24), [ores.lua:61](../../mods/ITEMS/grug_materials/ores.lua#L61) |
| [candidates/gems_final/cut_jade.png](candidates/gems_final/cut_jade.png) | `grug_materials:cut_jade` | `grug_materials/textures/grug_materials_cut_jade.png` | `default_diamond.png^[colorize:#3d9b65:190^[brighten` | [ores.lua:24](../../mods/ITEMS/grug_materials/ores.lua#L24), [ores.lua:67](../../mods/ITEMS/grug_materials/ores.lua#L67) |
| [candidates/gems_final/rough_garnet.png](candidates/gems_final/rough_garnet.png) | `grug_materials:rough_garnet` | `grug_materials/textures/grug_materials_rough_garnet.png` | `default_diamond.png^[colorize:#9e1526:210` | [ores.lua:23](../../mods/ITEMS/grug_materials/ores.lua#L23), [ores.lua:61](../../mods/ITEMS/grug_materials/ores.lua#L61) |
| [candidates/gems_final/cut_garnet.png](candidates/gems_final/cut_garnet.png) | `grug_materials:cut_garnet` | `grug_materials/textures/grug_materials_cut_garnet.png` | `default_diamond.png^[colorize:#9e1526:210^[brighten` | [ores.lua:23](../../mods/ITEMS/grug_materials/ores.lua#L23), [ores.lua:67](../../mods/ITEMS/grug_materials/ores.lua#L67) |
| [candidates/gems_final/rough_sapphire.png](candidates/gems_final/rough_sapphire.png) | `grug_materials:rough_sapphire` | `grug_materials/textures/grug_materials_rough_sapphire.png` | `default_diamond.png^[colorize:#235ac7:190` | [ores.lua:27](../../mods/ITEMS/grug_materials/ores.lua#L27), [ores.lua:61](../../mods/ITEMS/grug_materials/ores.lua#L61) |
| [candidates/gems_final/cut_sapphire.png](candidates/gems_final/cut_sapphire.png) | `grug_materials:cut_sapphire` | `grug_materials/textures/grug_materials_cut_sapphire.png` | `default_diamond.png^[colorize:#235ac7:190^[brighten` | [ores.lua:27](../../mods/ITEMS/grug_materials/ores.lua#L27), [ores.lua:67](../../mods/ITEMS/grug_materials/ores.lua#L67) |
| [candidates/gems_final/rough_ruby.png](candidates/gems_final/rough_ruby.png) | `grug_materials:rough_ruby` | `grug_materials/textures/grug_materials_rough_ruby.png` | `default_diamond.png^[colorize:#c51d35:195` | [ores.lua:28](../../mods/ITEMS/grug_materials/ores.lua#L28), [ores.lua:61](../../mods/ITEMS/grug_materials/ores.lua#L61) |
| [candidates/gems_final/cut_ruby.png](candidates/gems_final/cut_ruby.png) | `grug_materials:cut_ruby` | `grug_materials/textures/grug_materials_cut_ruby.png` | `default_diamond.png^[colorize:#c51d35:195^[brighten` | [ores.lua:28](../../mods/ITEMS/grug_materials/ores.lua#L28), [ores.lua:67](../../mods/ITEMS/grug_materials/ores.lua#L67) |
| [candidates/gems_final/rough_diamond.png](candidates/gems_final/rough_diamond.png) | `grug_materials:rough_diamond` | `grug_materials/textures/grug_materials_rough_diamond.png` | `default_diamond.png^[colorize:#ffffff:20` | [ores.lua:26](../../mods/ITEMS/grug_materials/ores.lua#L26), [ores.lua:61](../../mods/ITEMS/grug_materials/ores.lua#L61) |
| [candidates/gems_final/cut_diamond.png](candidates/gems_final/cut_diamond.png) | `grug_materials:cut_diamond` | `grug_materials/textures/grug_materials_cut_diamond.png` | `default_diamond.png^[colorize:#ffffff:20^[brighten` | [ores.lua:26](../../mods/ITEMS/grug_materials/ores.lua#L26), [ores.lua:67](../../mods/ITEMS/grug_materials/ores.lua#L67) |
| [candidates/gems_final/quartz.png](candidates/gems_final/quartz.png) | `grug_materials:quartz` | `grug_materials/textures/grug_materials_quartz.png` | `default_diamond.png^[colorize:#eaf6ff:120` | [ores.lua:20](../../mods/ITEMS/grug_materials/ores.lua#L20), [ores.lua:61](../../mods/ITEMS/grug_materials/ores.lua#L61) |
| [candidates/gems_final/abyssal_crystal.png](candidates/gems_final/abyssal_crystal.png) | `grug_materials:abyssal_crystal` | `grug_materials/textures/grug_materials_abyssal_crystal.png` | `default_diamond.png^[colorize:#3a1f6e:210` | [ores.lua:29](../../mods/ITEMS/grug_materials/ores.lua#L29), [ores.lua:61](../../mods/ITEMS/grug_materials/ores.lua#L61) |
| [candidates/gems_final/citrine_block.png](candidates/gems_final/citrine_block.png) | `grug_materials:citrine_block` | `grug_materials/textures/grug_materials_citrine_block.png` | `default_diamond.png^[colorize:#d9a21b:190` | [ores.lua:22](../../mods/ITEMS/grug_materials/ores.lua#L22), [ores.lua:73](../../mods/ITEMS/grug_materials/ores.lua#L73) |
| [candidates/gems_final/jade_block.png](candidates/gems_final/jade_block.png) | `grug_materials:jade_block` | `grug_materials/textures/grug_materials_jade_block.png` | `default_diamond.png^[colorize:#3d9b65:190` | [ores.lua:24](../../mods/ITEMS/grug_materials/ores.lua#L24), [ores.lua:73](../../mods/ITEMS/grug_materials/ores.lua#L73) |
| [candidates/gems_final/garnet_block.png](candidates/gems_final/garnet_block.png) | `grug_materials:garnet_block` | `grug_materials/textures/grug_materials_garnet_block.png` | `default_diamond.png^[colorize:#9e1526:210` | [ores.lua:23](../../mods/ITEMS/grug_materials/ores.lua#L23), [ores.lua:73](../../mods/ITEMS/grug_materials/ores.lua#L73) |
| [candidates/gems_final/sapphire_block.png](candidates/gems_final/sapphire_block.png) | `grug_materials:sapphire_block` | `grug_materials/textures/grug_materials_sapphire_block.png` | `default_diamond.png^[colorize:#235ac7:190` | [ores.lua:27](../../mods/ITEMS/grug_materials/ores.lua#L27), [ores.lua:73](../../mods/ITEMS/grug_materials/ores.lua#L73) |
| [candidates/gems_final/ruby_block.png](candidates/gems_final/ruby_block.png) | `grug_materials:ruby_block` | `grug_materials/textures/grug_materials_ruby_block.png` | `default_diamond.png^[colorize:#c51d35:195` | [ores.lua:28](../../mods/ITEMS/grug_materials/ores.lua#L28), [ores.lua:73](../../mods/ITEMS/grug_materials/ores.lua#L73) |
| [candidates/gems_final/diamond_block.png](candidates/gems_final/diamond_block.png) | `grug_materials:diamond_block` | `grug_materials/textures/grug_materials_diamond_block.png` | `default_diamond.png^[colorize:#ffffff:20` | [ores.lua:26](../../mods/ITEMS/grug_materials/ores.lua#L26), [ores.lua:73](../../mods/ITEMS/grug_materials/ores.lua#L73) |
| [candidates/gems_final/abyssal_crystal_block.png](candidates/gems_final/abyssal_crystal_block.png) | `grug_materials:abyssal_crystal_block` | `grug_materials/textures/grug_materials_abyssal_crystal_block.png` | `default_diamond.png^[colorize:#3a1f6e:210` | [ores.lua:29](../../mods/ITEMS/grug_materials/ores.lua#L29), [ores.lua:73](../../mods/ITEMS/grug_materials/ores.lua#L73) |

## Registration details

- Use the new files directly: do not retain `colorize` or `brighten`
  on a replacement. Each candidate already contains its final colours.
- Raw, cut and block images must resolve separately. Today the cut
  image appends `brighten` to the raw expression, and the gem block
  tiles that raw expression. D supplies dedicated cuts and opaque faces.
- Leave ore overlays and natural-node tiles alone. Only the item and
  storage-block registrations in the table are covered by these picks.
- Existing ids, tiers, recipes, drops, prices and saved state remain
  unchanged; Abyssal Crystal remains a raw mineral with no cut item.

## Licence rows for the shipped files

Add the following inventory rows to each owning mod’s
`LICENSE-media.md` (create that file for `grug_artisans`, which has
none in this worktree). Expand the sets using the exact destination
filenames in the table above. All are original coordinate drawings
by **GPT-6 Astra, 2026-10-31**, dedicated by the project to **CC0-1.0**,
to the extent rights exist. The PNG copies have no modifications;
only their filenames gain the owning mod’s prefix.

| Owning mod / shipped files (under textures/) | Count | Art source | Author and licence |
|---|---:|---|---|
| `grug_materials`: `grug_materials_<metal>_bar.png` (10 metals above) | 10 | `tools/r68_icons/candidates/bars_a/*_bar.png` | GPT-6 Astra — CC0-1.0 |
| `grug_materials`: `grug_materials_<metal>_block.png` (10 metals above) | 10 | `tools/r68_icons/candidates/bars_a/*_block.png` | GPT-6 Astra — CC0-1.0 |
| `grug_materials`: `grug_materials_rough_<gem>.png` (six gems above) | 6 | `tools/r68_icons/candidates/gems_final/rough_*.png`, pass-3 redraws | GPT-6 Astra — CC0-1.0 |
| `grug_materials`: `grug_materials_cut_<gem>.png` (six gems above) | 6 | `tools/r68_icons/candidates/gems_final/cut_*.png`, unchanged D | GPT-6 Astra — CC0-1.0 |
| `grug_materials`: `grug_materials_quartz.png`, `grug_materials_abyssal_crystal.png` | 2 | `tools/r68_icons/candidates/gems_final/{quartz,abyssal_crystal}.png`, pass-3 redraws | GPT-6 Astra — CC0-1.0 |
| `grug_materials`: `grug_materials_<gem>_block.png` (six gems), `grug_materials_abyssal_crystal_block.png` | 7 | `tools/r68_icons/candidates/gems_final/*_block.png`, unchanged D (crystal originally A) | GPT-6 Astra — CC0-1.0 |
| `grug_artisans`: `grug_artisans_setting_<key>.png` (six keys above) | 6 | `tools/r68_icons/candidates/settings_b/setting_*.png` | GPT-6 Astra — CC0-1.0 |

The source ledger is [LICENSE-media.md](LICENSE-media.md); the generator
and drawing code remain GPL-3.0-or-later. In the materials ledger,
update the stored-file count (36 + 41 = 77) and replace only the
runtime-attribution descriptions for these 41 selected images.
Keep the existing attribution for unchanged ore overlays, Emberglass,
tool sprites and other registrations. The old comparison derivatives
here retain CC BY-SA 3.0 and are never copied into the game.

## Verification and client checklist

Before copying: `python3 tools/r68_icons/generate.py --check`.
After copying, compare each shipped PNG byte for byte with the table’s
candidate, then run the installation lane’s required Lua/art checks.
The generator currently reconstructs the pre-installation expressions;
if those expressions change, preserve this comparison source snapshot
when adapting the generator for the installation commit.

User GUI check on **desktop and web**: read the shared 16/32 px family;
compare rough/cut for each gem, Garnet/Ruby and Quartz/Diamond; inspect
a repeated wall and mixed row of the metal and gem blocks. The offline
page is a software study, not a client capture or GUI acceptance.
