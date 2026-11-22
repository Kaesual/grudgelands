# Round 86 ART · Claim Stone drafts

I recommend **Under One Roof**. One lit doorway reads as home at 16 px. Two gables over a continuous threshold make the account stone recognisable even when both shutters are closed. [Open the offline pick page](index.html).

| Design | Personal and account | Fixed boxes, active → empty (personal / account) | Distinct 16 px face PNGs |
|---|---|---|---:|
| [Under One Roof](renders/roof.png) | One terracotta gable with a chimney / two slate gables. The windows go dark behind closed shutters. | 9 → 9 / 11 → 11 | 19 |
| [Supper Lights](renders/lights.png) | One beeswax candle in an ochre holder / three ivory candles on a blue stone saucer. Spent candles leave short stubs with black wicks. | 14 → 11 / 27 → 18 | 20 |
| [The Pear Tree](renders/pear.png) | One gold pear above an ochre planter / two fruiting boughs growing from one root above blue stone. The empty trees keep their bare branches. | 24 → 15 / 38 → 20 | 23 |

Each count covers both variants and all states. Each design adds two outlined active-item sprites for the hand and inventory. The personal front tile also serves as the flat `STONE_TEXTURE` waypoint. I drew one ochre [house icon](art/home_name.png) for the HUD and map name lines. Its chimney, open doorway and dark rim survive at 16 px on both grounds. The shipped cottage carries finer roof detail, and the purple claim marker depicts a stone.

The three proposals use fixed node boxes throughout. Each [art folder](art/) holds a `nodes.json` with signed sixteenths, face order, filenames and state settings. The drawing, selection and collision fit in one node. The draft uses the active boxes and tiles with a pale stone wash and the existing 150/255 opacity. Light levels are 2 for draft, 4 for active and 0 for empty. Shared face UVs constrain the painting on overlapping shapes, especially the tree crowns and planter rims. The original art is CC0 1.0.

I built the plates with `python3 -B tools/r86_stone_art/build.py`, inspected all three and checked the 16 px silhouettes after revising the flames and fruit. I opened the offline page at desktop and phone widths and verified all 18 world views, the three embedded PNG downloads, the tile sizes and the connected, in-bounds geometry. The lighting and translucency are software previews. Fixture runs were zero. A source search found no fixture reading either changed document. Upgrade classification is **compatible**.

## Blockers / questions

Which stone should the art lane take forward? May NAMES use the ochre doorway for home names?

The art and pick page are at `bb6b57191059345467e70ae2df4ead40ab56bbde`. The final report commit on this lane resolves with `git log -1 --format=%H -- tools/r86_stone_art/REPORT.md`. The handoff has an empty `git status --porcelain`.

## Step 2 · Under One Roof

All six views rendered from the game files match the selected sheet pixel for pixel. Joining adjacent roof courses reduced the personal stone to eight boxes and the account stone to nine. [Game-file render](renders/game_files.png)

The housing mod contains 19 face textures and two hand/inventory sprites at 16 × 16. Each active front face doubles as its kind’s flat marker. The ochre doorway for home names (`art/home_name.png`) was not taken into the game: home names keep the shipped cottage (ruling 19), so `grug_map_home_name.png` was removed again. The housing mod records CC0-1.0 in its media licence note.

**Builder handoff.** Load `grug_housing/stone_art.lua` with `dofile`. Read `art[kind][state]` for `node_box`, `tiles`, `selection_box` and `collision_box`. Kind is `""` (personal) or `"account"`. State is `active`, `empty` or `draft`. Copy `inventory_image` and `wield_image` from `art[kind]` onto the active item. Set `grug_housing.STONE_TEXTURE` to `art[""].marker_texture`.

Set `drawtype = "nodebox"` and `paramtype = "light"` for all six nodes. The preview uses unit scale and doors facing −Z. Active uses light level 4, empty uses 0, and both use opaque texture rendering. Draft uses level 2, `sunlight_propagates = true` and `use_texture_alpha = "blend"`. Its tiles already include the pale wash and 150/255 opacity.

**Verification.** `bash tools/check_lua.sh mods/PLAYER/grug_housing/stone_art.lua` passed. `python3 -B tools/r86_stone_art/check_game.py` loaded the table with plain Lua 5.1 and verified geometry, all six faces, sprites, licence entries and the six rendered views. This was the only art fixture run. Existing map fixtures read older licence entries. Lighting and transparency were checked in the software preview. Upgrade classification is **compatible**.

Final art and verification commit `db481c8f735ecd0fb2a8b408f0de483739e4f051`. The report commit is available with `git log -1 --format=%H -- tools/r86_stone_art/REPORT.md`. At handoff, `git status --porcelain` is empty.
