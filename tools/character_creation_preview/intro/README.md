# Opening study 03 — Choose your fate

Browser proposal requested on 2026-11-09. Open `preview.html` directly; it is
self-contained and makes no network requests. Select any race to enter the
accepted character layout. Classes, appearance, descriptions and Create are
hidden beforehand. The first race selects Warrior; later race changes retain
the selected class. There is no return to the opening state after a selection;
reload the page to review it again. The user approved native integration on
2026-11-10; the same scene is now installed in the game UI in this worktree.

Classification: **compatible**. No migration, world generation, personal profile
writes, merge or push. The native opening uses one static wide image with a
clipped, aspect-preserving cover placement and native text; no live effects.
It spans the centre and right columns until the first valid race selection.
There is no path back within that draft; Esc/I preserves it, while disconnect
still discards an unconfirmed draft as documented in `docs/design/world.md`.
The native copy is installed and checked with:

```sh
python3 tools/character_creation_preview/install-opening.py
python3 tools/character_creation_preview/install-opening.py --check
```

Native client captures and checks are recorded in `../native/opening/` and
linked from `../native/index.html`. Interactive desktop/web acceptance remains
the user's; browser preview checks do not constitute web-client acceptance.

## Background follow-up — 2026-11-10

The user approved the fortifications and foreground of study 02 and requested
only distant trees in place of the plain stone terrace. Study 03 adds nine
seeded pine/aspen trees in loose groups, using the exact shipped generator via
`../export-trees.lua`. Shapes, node sizes and facedirs are unchanged. Saved tree
positions/species/seeds are in `scene.json`. The selected root-free variants
stand on gently undulating soil beyond z=60; solid collisions fail the build.
The far ground extends to z=136 and uses grass-covered soil rather than the
old straight stone steps. Existing fog separates the background from the front.

`previous-v2/` preserves the approved view, settings and a foreground digest.
`background-check.json` confirms that every node at z<=60 is unchanged, along
with camera, fog, tint, fortress geometry, banners, smoke and fire settings.
The 17 browser checks and review captures are refreshed for the new picture.
Tree source hashes are recorded in `scene-build.json`; the tree media retain
their notices in `mods/ITEMS/grug_trees/LICENSE-media.md` and the default ledger.

## Scene and sources

The Accord occupies the left side, The Throng the right. A common approach
separates the two fortified compounds. The camera is low; the existing camp
standards are hung prominently on the front towers. The text is a UI overlay,
not baked into the image. In the opening state the stage spans the centre and
the otherwise unused right column.

The first proposal reused the same civic castle form on both sides. The user
rejected its mirrored, church-like appearance. `previous-v1/` preserves its
recipe, builder, review image and documentation for comparison.

`scene.json` saves the camera, colours, seed, different fortress dimensions,
banner placements/scale and smoke/fire positions. `../intro.py` authors two
independent silhouettes from shipped nodes: The Accord has massive stone
bastions, arrow slits, buttresses, a damaged curtain and an offset flat-roof
keep. The Throng has unequal timber fighting platforms, open diagonal braces,
metal collars and irregular palisades over basalt plinths. No civic castle
template is stamped. The churned ground has a shallow trench, broken route
fragments, damaged barricades, rubble, supplies and scorched patches.

`../intro-atmosphere.js` adds deterministic, static smoke and flame sprites
using the existing `default_item_smoke.png` (neutral colour modifier) and `mobs_fire_particle.png` textures.
These are baked into the rendered image, not live game/UI particle effects.
The banner mesh and textures are unchanged from the camps, at three times
camp scale. Their B3D export uses the same unit/material correction as
`tools/r69_camp_art/build.py`. This authored scene is a proposal, not a generated
location in the world.

The shared `tools/building_templates/viewer/renderer.js` renders all geometry.
Texture filtering is nearest, with no mipmaps or anisotropy. The viewer
`scenes.html` contains the actual node geometry, textures and saved camera.
`scene-build.json` records the recipe and render digest (including packed
geometry, media, scene page, atmosphere code and builder);
`renders/intro.json` records the PNG hash, camera and dimensions (1920 × 1080).
The original six race backgrounds and accepted browser/native previews are
preserved.

## Rebuild

From the worktree root:

```sh
python3 tools/character_creation_preview/intro.py
node tools/character_creation_preview/render-scenes.mjs \
  --directory "$PWD/tools/character_creation_preview/intro" --width 1920 --height 1080
python3 tools/character_creation_preview/intro-preview.py
node tools/character_creation_preview/intro-check.mjs
```

`CHROME_BIN` selects Chromium. Each capture/check launches and closes its own
temporary browser profile. `intro-preview.py` layers this proposal onto the
existing self-contained `../preview.html`, preserving its race/class/model
behaviour. The rendered image is verified against its receipt before embedding.

Review captures: `preview-1600.png` and `preview-1366.png`; selected-state
comparisons: `selected-1600.png` and `selected-1366.png`. `browser-check.json`
records 17 checks: starting state, image decoding, hidden/restored controls,
Warrior default, class retention across factions, no return, no page overflow
at 1600 × 1000 / 1366 × 768, and no JavaScript errors. Independent read-only
review covered source reuse, export correction, receipt integrity and UI flow.

## Media provenance

No external illustration or generated raster artwork is used. The PNG is a
rendered composite of shipped project assets; new scene arrangement is CC BY-SA
3.0 without relicensing incorporated components. Source notices remain in
`mods/BASE/default/license.txt`, `mods/BASE/default/LICENSE-media.md`, and the
media ledgers of `grug_decor`, `grug_materials`, `grug_nodes`, `grug_guild` and
`grug_mapgen` under `mods/`. Those include the original GPLv3 barrel source mesh
and the CC0 faction standards. Editable source assets remain in their owning
mods. Particle-image provenance remains in `mods/ENTITIES/mobs/license.txt`
and the repository `VENDOR.md`. Three.js retains its embedded MIT notice. This proposal's PNG is not
represented as wholly CC0 or wholly under the arrangement's license.

Iteration-02 independent review: **MERGE**, no remaining findings. The initial
large dithered smoke sprites were replaced with smaller overlapping default
smoke sprites; the final render has no checkerboard-column artifact. Final
PNG, embedded preview image and receipt hashes agree. Browser checks pass
17/17 at both recorded viewport sizes. That study-only review preceded the native integration below.

Study-03 independent review: **MERGE**, no findings (2026-11-10). The 84,031
approved foreground/fortification cells and original scene settings match
study 02; generated trees are grounded and confined to the background. Final
render/embedded-image receipts agree, browser checks pass 17/17, and both
viewport captures were visually inspected. Compatible, tools only.


Native integration review — 2026-11-10: **MERGE**. The installer verifies the
current build-input hashes before accepting the render; adding those receipts
and rerendering produced the same approved image bytes. Focused portable
suites pass (272 creation checks), actual engine probe passes 78/78, and native
opening captures at 1600 × 1000 and 1366 × 768 were visually inspected. Exact
results and the interactive desktop/web checklist are in the parent README's
"Native opening integration" section. No merge, push or personal sync.

## Website opening — Round 80.1

[Preview](wide/index.html): the website image beside the unchanged game opening,
a 1366 × 768 view, an expandable 2560 × 1440 view, and a switch for the right-quarter
panel, bottom-left prompt and 30% horizon guide. `wide/preview.png` (regenerated by `--preview`, not committed)
is the 1600-pixel-wide page capture with the overlay enabled. The clean image has
no figure, text, HUD or watermark. Visual acceptance belongs to the user before merge.

`wide.json` is the separate website layer. Its camera stands at `[-10,5,-48]`,
looks at `[13,10,20]`, and uses a vertical field of view of 50°. The low, close
view makes the keeps, fires, smoke and trench fill the frame. Both faction
banners remain left of the right-quarter list panel. The optical horizon is
around 57%, close to the game's low viewpoint rather than the rough 30% guide;
the outer left bastion is cropped to keep the foreground and main towers large.
The lower-left prompt rests over low stone debris and fallen timber on the
trampled ground.

The layer continues the original rolling ground to the right, x=76…240 and
z=−65…210, with the same seed and dirt/gravel/basalt/grass palette. Eleven
pine/aspen trees continue the far line through the right edge; their complete
shapes are translated copies of three isolated trees already packed in the
base page by the shipped generator. Three timber barricades, scattered rubble,
four fallen logs and thirteen foreground stones continue the camp outside the
game view. The second look fix adds two short fallen timbers and eight scattered
stones at x=−17…−9, z=−36…−29 in the lower-left foreground, all one node high.
They reuse the camp's bark, stone and basalt palette, with gaps between the
groups so the name/prompt stays readable. Each foreground stone row names its
existing packed node material. The camera and the rest of the first fix's
layer are unchanged. No new fire or smoke is needed: the closer camera gives
the existing four fires and three plumes their prominence back. The layer adds 178,118 cells;
all 136,574 original cells and all banners, smoke, fires, tint and fog remain.
The additions contribute no visible pixels to the game view (proof below).

`wide-build.py` uses the committed `scenes.html` as the packed base from
`../intro.py`, including its embedded shared renderer, media and atmosphere.
It checks the embedded specification against `scene.json`, the recipe digest
and the base build receipt, then appends the layer and applies the camera to
a copy. Thus the website build needs no Lua run and cannot overwrite the
game recipe, packed base page, original receipts or anything under `mods/`.
To adopt a future game scene, rebuild that base separately through the existing
pipeline before rebuilding the website layer.

From the repository root (Node 24, Python with Pillow, Chromium):

```sh
python3 tools/character_creation_preview/intro/wide-build.py
python3 tools/character_creation_preview/intro/wide-build.py --check
node tools/character_creation_preview/intro/wide-capture.mjs --preview
```

Both capture paths default to `/usr/bin/chromium-browser`; `--chrome PATH` or
`CHROME_BIN` overrides it. They use disposable profiles. The builder renders
2560 × 1440 directly, removes Chromium's uniformly opaque alpha channel without
changing any RGB sample, and writes an explicit PNG `sRGB` chunk. The shipped
`tools/web_data/media/grug_creation_intro_wide.png` is **RGB, no alpha**, 1,990,719
bytes. `wide/intro.json` records camera, dimensions, mode, colour space, input
hashes, cell counts, browser version, capture settings, byte size and output
SHA-256. `--check` verifies that media file against the receipt, and checks the
committed difference image against its hash and pixel counts. Stale inputs,
wrong dimensions/mode/colour declaration or a changed output fail with exit 1.

Only the website media PNG, small JSON receipts, `wide/diff.png`, preview page,
layer, scripts and documentation are committed. The duplicate `wide/intro.png`,
`wide/game-base.png`, `wide/game-layer.png` and `wide/preview.png` are ignored
build output. The commands above regenerate all four; neither `--check` nor the
preview page requires them. The page loads the wide image from its website media
path and the game's image directly from its unchanged `mods/` path. The preview
command checks both display sizes, image decoding, overlay toggling, page
overflow and browser errors, then writes `wide/browser-check.json` and a fresh
1600-pixel-wide `wide/preview.png` with the overlay enabled.

**Ruling 5 proof:** the builder freshly renders `wide/game-base.png` and
`wide/game-layer.png` at the original 1920 × 1080 camera, respectively without
and with the entire wide layer. `wide/proof.json` records both output hashes
and **0 differing pixels, maximum per-channel difference 0**, with no differing
region; the committed `wide/diff.png` is black. The comparison is between those
two fresh renders, not against an older browser's PNG. The ignored comparison
captures are needed only to recompute the proof, not to check the delivered
files. No extent-dependent lighting adjustment is necessary: the embedded
renderer uses fixed face shading, local neighbour-based ambient occlusion and
`MeshBasicMaterial`; shadow maps are disabled. Fog remains the explicit
100…210 range in `scene.json`, independent of the scene bounds. The base recipe,
packed page, game camera and installed game picture are unchanged.

Classification: **compatible**; website tooling/media only, no saved keys read
or written. The website image's notice, provenance and SHA-256 are in its
[media ledger](../../web_data/media/LICENSE-media.md#wide-character-creation-opening--rendered-composite).
