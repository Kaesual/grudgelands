# Media Origin & Licenses (grug_artisans)

**Six stored files: the jewellery setting icons of Round 68 (§1).** The six
wood grades (`woodcarver.lua`) draw vendored minetest_game media with a
runtime tint (§2); the mod stores no other media.

## 1. Round 68 jewellery setting icons — CC0 1.0

Original pixel drawings made by **GPT-6 Astra**, 2026-10-31, for
Grudgelands (Round 68 follow-up ICONS; the user picked settings B the same
day). They are drawn entirely by `tools/r68_icons/art.py` and `generate.py`
(GPL-3.0-or-later) with Python, Pillow and numpy; no source sprite pixels,
external images or fonts enter them (the lane's own ledger
`tools/r68_icons/LICENSE-media.md`). The project dedicates any rights it
holds in them to **CC0 1.0 Universal**
(<https://creativecommons.org/publicdomain/zero/1.0/>), to the extent such
rights exist. The files are copied byte for byte from
`tools/r68_icons/candidates/settings_b/`, unmodified, and renamed with this
mod's prefix (`tools/r68_install/portable_test.lua` checks the copies).

| File | Source in `tools/r68_icons/` | Use | Author and licence |
|---|---|---|---|
| `grug_artisans_setting_tin.png` | `candidates/settings_b/setting_tin.png` | `grug_artisans:setting_tin` inventory image | GPT-6 Astra — CC0-1.0 |
| `grug_artisans_setting_iron.png` | `candidates/settings_b/setting_iron.png` | `grug_artisans:setting_iron` inventory image | GPT-6 Astra — CC0-1.0 |
| `grug_artisans_setting_copper_inlaid_steel.png` | `candidates/settings_b/setting_copper_inlaid_steel.png` | `grug_artisans:setting_copper_inlaid_steel` inventory image | GPT-6 Astra — CC0-1.0 |
| `grug_artisans_setting_gold.png` | `candidates/settings_b/setting_gold.png` | `grug_artisans:setting_gold` inventory image | GPT-6 Astra — CC0-1.0 |
| `grug_artisans_setting_gold_filigreed_embersteel.png` | `candidates/settings_b/setting_gold_filigreed_embersteel.png` | `grug_artisans:setting_gold_filigreed_embersteel` inventory image | GPT-6 Astra — CC0-1.0 |
| `grug_artisans_setting_gold_filigreed_abyssal_steel.png` | `candidates/settings_b/setting_gold_filigreed_abyssal_steel.png` | `grug_artisans:setting_gold_filigreed_abyssal_steel` inventory image | GPT-6 Astra — CC0-1.0 |

## 2. Runtime registrations — CC BY-SA 3.0 Unported

The six wood grades (`grug_artisans:seasoned_wood` ... `heartwood_wood`)
use the vendored `default_wood.png` with `^[colorize:#<tint>:90`, a runtime
derivative under the original's licence. The original lives in
`mods/BASE/default`, vendored from minetest_game
<https://github.com/luanti-org/minetest_game> at commit `b5243f3` (see
[VENDOR.md](../../../VENDOR.md)); licence text
<http://creativecommons.org/licenses/by-sa/3.0/>; © 2010–2023 the
minetest_game contributors listed in `mods/BASE/default/license.txt`.
