# Opening study 02 — Choose your fate

Browser proposal requested on 2026-11-09. Open `preview.html` directly; it is
self-contained and makes no network requests. Select any race to enter the
accepted character layout. Classes, appearance, descriptions and Create are
hidden beforehand. The first race selects Warrior; later race changes retain
the selected class. There is no return to the opening state after a selection;
reload the page to review it again. The native game files remain unchanged.

Classification: **compatible, tools only**. No migration, world generation,
personal profile writes, merge or push. Native integration awaits the user's
visual review. The opening can use one static wide image in a formspec; no new
engine feature or effect is required.

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
17/17 at both recorded viewport sizes. No native game change is included.
