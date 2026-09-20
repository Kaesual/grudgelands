# R10 nonweapon visual correction record

Date: 2026-09-20. This record covers the accepted representative armor, animal
loot, crop and mount pass. Weapon media is unchanged.

## Armor

All three armor lines now have separate inventory and worn media for four slots
and six material tiers. `tools/r10_art/build_armor_assets.sh` is the exact source
map and deterministic build recipe. Metal and leather use the pinned VoxeLibre
armor/trim families; cloth uses coherent complete Lord of the Test outfits.
Bronze and Embersteel have baked copper and red grades and are no longer
byte-identical Gold copies. Leather inventory icons use the dedicated 16x16
inventory trims; worn UVs use the separate 64x32 piece trims.

Proof:

- `r10-visuals/armor-inventory-sheet.png`: line/tier/slot labels, with each
  16x16 icon at exact size beside a nearest-neighbour inspection enlargement.
- `r10-visuals/worn-model-sheet.png`: all 18 full sets rendered on the shipped
  `character.b3d`, plus front/back/side and a true imported walk-frame leather view, and the six accepted
  uniform race stature scales. The Blender material honors source alpha. These are offline native Blender/Eevee renders,
  not engine screenshots; they validate the shipped mesh UV and alpha seams.

## Animal loot

Rotting Flesh, Feather and Slime Gel now use their corresponding VoxeLibre
sprites. Light Leather uses Animalia leather; Heavy Leather and Sleek Pelt use
Animalworld bear/boar pelts. The old leather-tinted Boar Tusk was replaced by a
single curved ivory sprite authored through OpenAI image generation, then
mechanically downsampled to 16x16. The generation prompt requested one curved
ivory boar tusk, transparent background, high-contrast pixel-art shading and
readability at 16x16. The immutable original and exact prompt are stored under
`r10-visuals/sources/`; `tools/r10_art/build_boar_tusk.sh` records the
point-filter trim, downsample and centered extent operation. The manifest
records source, prompt and output hashes, so the result no longer depends on a
machine-local generated-image path.

The rest of the nonweapon item registrations were reviewed by texture-expression
family. Existing readable cooking dishes, alchemy containers, metal bars,
profession components, fish and trinket art remain in place; this pass changes
only the observed wrong-object or generic-harvest placeholders.

Fire Pepper likewise uses a project-owned image-generation source rather than
the earlier red carrot substitution. Its prompt asks for one curved red chili
with a green stem, transparent background and readable 16x16 pixel-art form.
The immutable original and prompt live under `r10-visuals/sources/`;
`tools/r10_art/import_harvest_icons.sh` performs only the deterministic
point-filter trim, 14x14 downsample, centered 16x16 extent and metadata strip.
The source manifest records all three hashes.

## Farming

All 17 registered crop families now bind four actual growth textures via
`grug_farming_<crop>_<stage>.png`; the previous system tinted and scaled the
harvest inventory item for every world stage. The stage source map is
`tools/r10_art/import_crop_stages.sh`; the separate exact harvest-icon map is
`tools/r10_art/import_harvest_icons.sh`. Their strict allow-lists and authorship
are in the owning media ledgers. No foreign node logic, recipes, sounds or IDs
were imported. Sugar cane and bamboo keep the local plantlike nodes with visible
stage scale. Salt crust alone uses the source's animated crystal tops and a
four-step shallow nodebox silhouette; its local IDs, timer, soil requirement,
walkability and drops are unchanged. `r10-visuals/crop-stages-sheet.png` shows
the full 17x4 texture result, while `r10-visuals/crop-node-visual-proof.png`
shows the effective cane, bamboo and salt geometry at every stage.
For MAP-B wild placement, reuse each mature stage-4 tile only where the plant's
accepted biome/soil table already permits the item; do not import upstream spawn
rules or add new wild populations as an art side effect.

## Mount icons

The twelve `grug_mounts_icon_*.png` files are 64x64 one-time Eevee bind-pose renders of
the exact shipped animated B3D model, texture and catalog tint. They are inventory portraits, not rest-pose clearance evidence. The deterministic
bounded pipeline is `tools/r10_art/render_mount_icons.sh`; it uses 20-second
Assimp bounds and a 90-second Blender bound with cleanup. Horse blank/body/blank
buffers and boar Skin/blank-Saddle slots remain transparent as in the runtime
catalog. Wolf and tiger use a face/profile azimuth. The Orc mount faithfully
renders the currently shipped VoxeLibre pig-derived `grug_mobs_boar.b3d`; the
mesh has no tusk geometry, so inventing tusks in the inventory render would
misrepresent the in-world mount. `r10-visuals/mount-icons-sheet.png` labels all
12 renders at inspection scale; the files themselves remain normal 64x64 PNGs.

Every mount catalog entry points to its own render. The four generic tier items
use the Accord representative for each tier until owner metadata selects the
actual racial appearance. Model animation and runtime geometry are unchanged.

## Source pins and licenses

- VoxeLibre `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`
- Lord of the Test `f164140154945f0b356521ae721a86e9c7a0e0cf`
- farming `1a918c7ae3778c3406ad91de6b83a174facad8f0`
- x_farming `ac5f69d5103d4af841b1a5ed3a0b49a4e19d0c84`
- goblins `ce27b15f87452c9614b515b8a9b53af5d0e8e276`
- animalworld `ac835da96681774679ace90656812aab67e25b5c`
- animalia `5895f403fd43a9464e06b3675af3495f50565a3f`

Per-file authorship, license and modification details live in each owning mod's
`LICENSE-media.md`. Reference pins were read only and were not moved.
