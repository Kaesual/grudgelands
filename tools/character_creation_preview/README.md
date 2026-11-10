# Character creation layout and backdrop study

The separate `character-creation` branch contains the approved browser design
and its native Luanti implementation. The user approved implementation on
2026-11-09. Game files are changed only in this worktree; nothing has been
merged, pushed or synced into the personal game. Classification: **compatible**
(presentation and draft defaults; no saved-state or world-generation change).

**Opening study 03:** [intro/preview.html](intro/preview.html) adds the requested
two-fortress opening as a separate browser proposal. Iteration 02 replaces
the matching civic castles with distinct military silhouettes and a scarred front.
Iteration 03 adds distant generated tree groups while preserving that approved front. Its editable scene, rebuild
steps and evidence are in [intro/README.md](intro/README.md). The user approved
native integration on 2026-11-10; the same image is installed in the opening
view, with classes and right-hand cards hidden until the first race selection.

**Native review:** open [native/index.html](native/index.html) for actual Luanti
5.18 client captures. The original browser proposal remains in `preview.html`.
The native implementation and its limits are documented at the end below.

Open `preview.html` directly in a browser. It contains all images, UI assets,
character texture layers and its renderer, with no network dependencies.
`scenes.html` is the separate interactive scene viewer. The contact sheet is
`renders/contact-sheet.png`; the six source-resolution images are
`renders/<race>.png` (1200 × 1400).

## Editable sources

- `scenes/<race>.json`: composition, deterministic seed, camera, sky/fog/tint,
  materials, existing building placements, trees, plants and small props.
- `scenery.py`: constructs the bounded block scenes and calls the existing
  template readers and `build_viewer` helpers. Each building uses its actual
  start-town layout's material bindings, including roof overrides. The
  placement is centered on the template's cell bounds, at `at`; the templates
  keep their unrotated orientation. Tree placements are authored; their shapes
  come directly from the shipped tree generator, without scaling or reshaping.
- `export-trees.lua`: a LuaJIT adapter for `wp40/treegen.lua` and
  `wp40/tree_templates.lua`. Each tree saves `species`, `seed` and `at` in its
  scene JSON. The adapter exports the game's nodes, facedirs, roots and hanging
  vegetation; the scene builder places them one node above the local ground.
- `scenes.html.in`: the capture/viewer page. It embeds the unchanged shared
  `tools/building_templates/viewer/renderer.js`, the existing offline orbit
  controller and vendored Three.js, using the castle tool's colour-space
  adapter for that vendored revision.
- `layout.html.in`: UI layout and the browser approximation of the character,
  using the existing body-preview catalogue and actual look texture layers.
- `build.py`: reads the look catalogue and icons, checks background receipts,
  encodes the PNG captures as WebP and embeds them in the offline UI preview.

The six compositions are proposals, not accepted game design:

| Race | Saved scene |
| --- | --- |
| Human | Bending orchard lane, garden fence, bench, workbench and barrels |
| Dwarf | Pine workshop, quenching tub, coal and iron stone, stacked timber and stone stock |
| Elf | Silverwood/aspen garden, reflecting pool, planted borders, ferns and quiet seating |
| Orc | Acacia courtyard, cooking corner, drying hides, straw, timber and stores |
| Troll | Jungle landing, mooring post, hanging rope, stores, reed islands and distant kapok |
| Undead | Bent gravewoods, slate walk, kneeling mourner, candles and broken grave enclosures |

## Rebuild

From the repository root, with Python 3 + Pillow, LuaJIT, Node.js 24 and a
Chromium executable:

```sh
python3 tools/character_creation_preview/scenery.py
node tools/character_creation_preview/render-scenes.mjs --chrome /path/to/chrome
python3 tools/character_creation_preview/build.py
```

`CHROME_BIN` also selects the executable. `--race human` captures just one
scene; without it all six are considered. Current captures are reused when
their scene/render-source digest, dimensions and PNG hash agree. Editing a
scene and rebuilding never requires a game boot. The capture uses its own
temporary browser profile and closes that browser when finished.

To adjust a camera, open `scenes.html`, select the race, drag and zoom, then
use **Copy camera** and put the resulting `eye`, `target` and `fov` into that
race's JSON. **Saved camera** restores the source camera. After an edit, run
the three commands above. The first produces `scene-build.json`, and the
second writes a capture receipt in `renders/<race>.json`.

## Scope and evidence

The existing renderer draws real node geometry and textures with its normal
face shading and ambient occlusion. Fog and tint are scene art direction.
These are web-renderer captures, not Luanti screenshots: engine lighting,
particles, shaders and animation are not reproduced. Rendered backgrounds are
static images in the character UI; only the character remains interactive.

The browser layout check is recorded in `verification.json`; it does not
constitute desktop/web game acceptance. The scene builder refuses missing
nodes, meshes, textures and unresolved template cells, and checks the central
standing space. The only offline texture substitution is the engine's
`blank.png`, replaced with the project's fully transparent tile. Provenance
and licences remain with the source mods; the embedded Three.js licence is
included in the generated pages.

Independent tooling review on 2026-11-08: **MERGE** after fixing render-cache
source coverage and browser failure cleanup. The review also checked the
actual town-palette bindings, capture receipt validation and UI embedding.

## Shutdown checkpoint — 2026-11-09

All scene sources, captures, generated previews and verification results are
stored in this worktree. `browser-check.mjs` preserves the exact ad hoc browser
check previously kept in `/tmp` (subsequently extended for the perspective
study); it expects a dedicated Chromium debugging session on port 9237 and
resolves the preview relative to the script. Browser
profiles in `/tmp` are disposable and are not needed to resume.

The preview is ready for the user's next design feedback. Game integration
has not started; nothing has been merged or pushed from this branch.

## Human perspective study — 2026-11-09

The user requested a first Human before/after comparison because the character
looked oversized among the houses. Open `comparison.html` to move the divider
or select either complete image. `preview-before.html` and `human-before.json`
preserve the preceding proposal; `preview.html?race=human` opens the new one.
Both comparison screenshots use the same viewport and appearance options.
The other five backgrounds and their portrait presentation remain unchanged.

The Human camera is now at `[0, 2.05, -13]`, targeting `[0, 1.34, -9.5]` at
55 degrees vertical FOV. Feet stand at `[0, 0.5, -9.5]`. The existing body
catalogue uses 0.0525 nodes per pixel, making the Human 1.68 nodes tall
([armor format](../../docs/technical/armor-format.md)). `portrait.js` shares
the placement and camera conversion. The UI uses the full background viewport
and adjusts its camera for the centered `object-fit: cover` crop of the saved
1200 × 1400 image. A soft transparent ground-plane shadow follows the same
projection. Buildings, vegetation and terrain placement have not changed.

In `scenes.html`, **Reference figure (Human)** toggles the catalogue's body
geometry as a wireframe at that same standing point. Every scene selection
resets it off, including automated background captures. The calibration
capture is `renders/human-reference.png`.

After starting a dedicated Chromium with remote debugging on port 9237, run:

```sh
node tools/character_creation_preview/browser-check.mjs
node tools/character_creation_preview/capture-comparison.mjs
node tools/character_creation_preview/browser-check.mjs --close
```

The first updates screenshots and `verification.json` (41 checks passed),
including independent source-image/crop projection comparisons within 0.1 px
at four viewport sizes, visible head/feet and the ground shadow. The second
captures the matching baseline and reference figure, and checks the comparison
controls and absence of the reference in ordinary background captures.
Independent perspective review: **MERGE**. This is a browser proposal awaiting
the user's visual decision, not game integration or engine GUI acceptance.

### Road-material follow-up — 2026-11-09

The user accepted the improved Human perspective and requested a street-like
surface, checking all six peoples. The Human path now uses the shipped
`grug_decor:castle_pavement_brick` paving stone instead of loose gravel.
Elf and Orc paths use `default:silver_sandstone_brick` and
`default:desert_sandstone_brick`, respectively, instead of uncut sandstone.
The existing Dwarf and Undead stone-brick paths and the Troll junglewood
boardwalk already read as constructed surfaces and retain their materials.
All cameras, terrain shapes, buildings and vegetation remain unchanged by
this follow-up. The six renders, contact sheet, preview and comparison are
rebuilt from these source materials; the frozen before proposal stays intact.
Independent material review: **MERGE**, tools-only and compatible. All six
rendered paths were visually checked; the existing browser checks pass.

## All-six perspective follow-up — 2026-11-09

The user requested the same perspective correction for the other five peoples.
This supersedes the Human-only scope above. `portraits.html` now shows all six
figures together, with links into each interactive selection. Its images in
`portraits/` are stage captures from the actual browser preview, not separate
character compositions. The six source backdrops and reference captures remain
in `renders/`.

Every scene now saves a `portrait` with feet, node units per skin pixel and
race stature. `scenery.py` checks that stature against the shipped
`grug_visuals/compose.lua`: Human 1, Dwarf 0.90, Elf 1.06, Orc 1.08, Troll 1.12,
Undead 0.94. Both the reference geometry and UI use these same values. The
32-pixel body height is 1.68 nodes before stature; the outer head layer extends
to 32.5 pixels and is included in the visible bounds checks.

Except for Troll, the camera eye remains `[0, 2.05, -13]`, the feet
`[0, 0.5, -9.5]`. The Troll stands inside the raised deck at `[0, 1.5, -6]`,
with the eye at `[0, 3.05, -9.5]`. Each camera targets the body's center,
`feet_y + 0.84 * stature`, at the standing point's x/z, with 55-degree FOV.
Human therefore retains its accepted camera. The Troll's extra block of
height comes from the physical deck; its body's 1.12 stature is independent.
Existing paving, buildings and vegetation are preserved.

The UI uses the exact background bounding rectangle, including fractional CSS
dimensions, to match its projection to the background crop. The browser check
covers all six races at five viewport sizes, including body geometry bounds,
standing point, ground shadow, label clearance and crop registration. Scene
capture verification checks all six reference sizes and that each is hidden
again for ordinary background captures. Runtime acceptance in Luanti remains
the user's; these tools do not change game code or worlds (**compatible**).

Final evidence: **93 browser checks passed**, including all 30 race/viewport
combinations. The complete projected mesh vertices (including the outer head
layer and yaw) stay clear of the heading and class area. Short/narrow windows
use compact heading/class spacing and hide the rotation hint to preserve that
space without changing the character/background scale. All six portrait
captures were visually reviewed; all six reference captures and the gallery
load successfully. Independent review: **MERGE** after correcting the bounds
test to include the outer head layer and fixing fractional viewport sizing.

## Scene and pixel-art refinement — 2026-11-09

The user accepted the proportions and requested more distinct, finished scenes,
no recurring gateway composition, crisp pixel textures, and corrected Undead
ground. Cameras and portrait records are unchanged from `art-before/*.json`.
That folder also preserves the previous overview for comparison.

The authored arch props are removed. Curving paths now use saved `[z, center_x,
half_width]` knots, ending within the scene rather than climbing the distant
rim. Building offsets and smaller, uneven tree groups break up the paired
portal silhouettes, especially in the grove. Near-path furnishings and small
material/plant groupings give each foreground its own setting (table above).
Troll railings are actual one-node-high junglewood fences above the deck.
Undead ground is the game's `grug_nodes:blight_dirt`, with ash and bone-litter
patches, instead of dry yellow grass; its walk uses dark slate blocks rather
than wall bricks or the visually busy slate-tile variant.

Pixel preservation is end to end: the local scene viewer overrides both map
filters to `NearestFilter`, disables mipmaps and anisotropy, and leaves the
shared renderer source unchanged. `build.py` encodes backgrounds as lossless
WebP; the UI displays them with `image-rendering: pixelated`. The overview uses
nearest-neighbour resizing and is saved as lossless `renders/contact-sheet.png`.
An updated JPEG copy keeps earlier review links useful, but the PNG is the
canonical art-review image. Geometry edge antialiasing, scene fog and the soft
contact shadow remain separate from texture sampling.

Validation: **99/99 browser checks passed**, with no JavaScript errors. All six
scene texture-map sets pass the nearest/no-mipmap/aniso-1 check; decoded WebP
pixels equal their source PNGs exactly. Camera and portrait records equal the
saved pre-refinement records for all six races. All six final portraits were
visually inspected. Two tree trunks were moved clear of building footprints,
and a waterlily was moved from a building footprint onto open water.
The six reference captures, their reset before background capture, and the
gallery load check pass. Independent refinement review: **MERGE**; tools-only,
compatible, with no game/world or shared-renderer source changes.

## Shipped trees and richer settings — 2026-11-09

The user requested trees close to the game's algorithm and more variety in the
five non-Human settings. The earlier `tools/r46_tree/concept/treegen.js` is the
prototype behind the shipped pure-Lua generator. The preview now calls that
generator directly through `export-trees.lua`, together with its production
node mapping and hanging-vegetation pass. No duplicate tree algorithm remains
in `scenery.py`. These source files also match current main.

The 42 placed trees use saved species and seeds: apple, pine, aspen, silverwood,
acacia, jungle, kapok and gravewood. Shape, node size and facedir are preserved;
overlapping leaves may yield to existing geometry, but solid branch collisions
fail the build. Flat-ground roots require matching terrain height, actual
soil/sand/gravel underneath, and empty destination cells. The distant trees on
the rising rim use root-free seeds. Source hashes for the generator, mapping
and export adapter participate in render-cache invalidation.

The workshop has quenching and material supplies; the grove has flower/fern
borders and seating; the lodge yard has cooking and hide drying; the landing
has mooring details, stores and reed islands; the cemetery has a mourner,
candles and damaged grave enclosures. Distant tree groups give the woodland
settings depth. These remain authored preview compositions, not mapgen changes.

`trees-before/` preserves the six previous scene recipes and their overview;
the gallery links that overview for comparison. Cameras and portrait records
are identical to both `trees-before/` and `art-before/`. Layout study 06 includes
the new captures. All sources and outputs remain in the worktree.

Validation: the new Lua adapter passes `tools/check_lua.sh`; all six scenes
build without missing nodes, meshes or textures. **99/99 browser checks pass**
with no JavaScript errors. All six reference captures pass scale/reset checks,
and all texture sets retain nearest sampling without mipmaps or anisotropy.
Decoded WebP pixels equal their source PNGs. All six backgrounds and portraits
were visually inspected. Classification: **compatible, tools only**; game
integration and the user's Luanti GUI acceptance remain separate.
Independent review: **MERGE**, after closing the root collision/support finding;
the reviewer verified fresh receipts and PNG hashes for all six final captures.


## Native implementation — 2026-11-09

`grug_classes/creation_window.lua` owns layout; `selection.lua` keeps its existing
session draft, validation, stasis, final storage and arrival flow. The faction
comes from the selected race. Warrior is preselected; an explicitly selected
class survives every race change, including across factions. Changing race
rerolls appearance. Escape pauses creation and I resumes it. Appearance is
still supplied by `grug_visuals/creation.lua`, now as separate controls and
native model callbacks. Skill icons/names come from the actual class kits.

The panel fills the client with a dark backdrop and scales to its reported
formspec space. The centre keeps an 11:10 aspect so the background and model
share one projection on different screens; extra width goes to the side
columns. The two faction banners hang beside their race rows. The native
model uses the shipped animated mesh and appearance texture composition.

### Matching the native camera

Luanti's `GUIScene` uses a fixed 30-degree vertical field of view and automatically
fits the mesh bounding box. `native.py` reads that actual mesh's standing bounds
and mirrors the engine distance calculation: `height/(2*tan(15°)) + max(width,
depth)/2`. Mesh units convert to world nodes at 0.1 times race stature. The
model widget is 60% of the scene height times stature, with aspect 0.8 and a
12-degree downward camera inclination. The full backdrop's field of view is
`2*atan(tan(15°)/(0.6*stature))`. This retains the actual stature differences,
feet position and architectural proportions for all six races.

The native scenes reuse the same authored geometry as the approved browser
proposal, with a separate calibrated camera. Native backgrounds are 1540 × 1400.
To rebuild after a source scene change, first rebuild the original scenes as
above, then run:

```sh
python3 tools/character_creation_preview/native.py
node tools/character_creation_preview/render-scenes.mjs \
  --directory "$PWD/tools/character_creation_preview/native" --width 1540 --height 1400
python3 tools/character_creation_preview/native.py --install
```

The builder emits `native/calibration.json`, editable camera records in
`native/scenes/`, its self-contained viewer and `creation_camera.lua` together.
Camera changes belong in `native.py`; world composition changes belong in the
original `scenes/`. Installation verifies the render input digest, PNG hash and
dimensions before copying the six textures into `grug_classes/textures/`.
The class mod's media ledger records provenance and source licenses.

### Native evidence and remaining acceptance

The isolated Flatpak Luanti 5.18 client was captured at 1600 × 1000 (all six
races and the empty state) and 1366 × 768 (empty, Human and Troll). Captures,
exact formspecs, manifests and client/server logs are under `native/captures/`.
The game runs from a disposable staged worktree copy; personal profiles and
worlds are untouched. Reproduce with `tools/ui_dialogs/capture.sh`, setting
`XVFB`, `WIDTH`, `HEIGHT`, `SCENES=dark`, and
`ONLY=creation_start,creation_race_human,creation_race_dwarf,creation_race_elf,creation_race_orc,creation_race_troll,creation_race_undead`.

The portable creation fixture covers the draft rules and 30 race/viewport
combinations, including GUI-density changes. The real engine probe exercises
creation, cancellation, draft reset on reconnect, storage and arrival. Logs
and the complete portable-suite result are stored in `native/`.

The native renderer provides simpler character lighting and native fonts;
these differ from the browser proposal. Mouse dragging rotates the model;
changing a selection rebuilds the form and restores the authored angle. A
vertical drag tilts the model camera away from its calibrated background view.
The backdrop remains a still image. These are normal engine-widget limits.
The user's interactive desktop and web acceptance is still pending:

- Switch through all six races and compare body/architecture proportions.
- Choose a different class, then change race across both factions: retain class.
- Cycle all appearance controls and Random; drag the model; scroll class skills.
- Resize the window and check the intended GUI scale on desktop and web.
- Pause with Escape, resume with I, then create once and verify arrival.


Final validation (2026-11-09): **MERGE**, independent read-only review with no
remaining findings. All six installed backdrop hashes match the render receipts
and media ledger. Lua 5.1 parsing/sweeps and the release-mode source audit pass.
The full portable run completed **319 passes / 1 failure**: `r41_up` had an old
harness that filtered out the newly extracted UI files. After updating that
harness, the focused rerun of all five affected fixture suites passes (including
`r35_c` **254 checks** and `r41_up` **107 checks**). Thus all 320 suites have a
passing result for the six-race implementation before the opening follow-up,
with the initial run preserved in
`native/fixtures.txt` and the correction in `native/fixtures-followup.txt`.
The real engine probe passes **74/74 checks**, including arrival and reconnect;
see `native/engine-result.txt`. The first engine attempt also exposed an old
hardcoded selected-row colour in its assertion; that now uses the shared theme
and additionally checks the race texture. Both client capture runs completed
without engine errors. Interactive desktop/web acceptance remains the user's.


### Native opening integration — 2026-11-10

The approved study 03 now fills the centre and right columns before the first
race selection. `creation_window.lua` uses a static clipping container to
cover that area without distorting the 16:9 render, native centred text and
one native gradient box. The class strip, appearance and descriptions, model
and Create are absent in that state. `selection.lua` also ignores submitted
class fields until a race exists. The first race starts as Warrior; later
class choices and Esc/I behaviour are unchanged. Disconnect still discards
an unconfirmed draft, as specified in `docs/design/world.md`.

`install-opening.py` verifies the scene recipe, source hashes, render receipt,
PNG dimensions/hash and installed copy. A review finding added source-hash
checks for the builder, atmosphere, capture, viewer and libraries. Rebuilding
and rendering with these extra receipts produced the exact approved PNG again
(SHA-256 `74291ece69c42c9c745023e390dcd88bbd069c9dabb1989a8a6c43cb1ef7805e`).
The six calibrated race backgrounds are unchanged.

Validation under `native/opening/`:

- Plain Lua 5.1 parser/sweeps pass (`lua-check.txt`).
- Five affected portable suites pass (`fixtures.txt`); creation has **272
  checks**, including opening geometry across five viewport/density reports.
- Actual engine probe **78/78 PASS** (`engine/probe.txt`): opening visibility,
  first Warrior, class retention, draft, creation, arrival and reconnect.
- Actual Luanti 5.18 client captures: opening/Human/Troll at 1600 × 1000,
  opening/Human at 1366 × 768. The initial gradient's separately rounded bands
  left thin lines; one native per-corner gradient replaces them. Final opening
  captures in `1600x1000-final/` and `1366x768-final/` were visually inspected
  and linked from `native/index.html`. Logs/formspecs/manifests are retained;
  the logged capture-complete disconnect is the harness's expected shutdown.
- Independent read-only review: **MERGE**, the source-receipt finding resolved.

Classification: **compatible**, no saved-state/world change, migration or reset.
Still in `character-creation`; no merge, push or personal installation sync.
Interactive desktop and web acceptance remains open. Check the opening, first
race, retained class across both factions, and Esc/I in each target client.


Opening focus correction — 2026-11-10: the user noticed that Human looked
selected before choosing a race. The draft was empty, but its forced keyboard
focus applied the theme's focus surface. The opening now targets a zero-size,
no-action focus button, following the existing inventory pattern. Once a race
is selected, focus still targets that race. Lua checks and the creation/focus
portable suites pass. Updated client captures are under
`native/opening/1600x1000-neutral/` and `1366x768-neutral/`.
