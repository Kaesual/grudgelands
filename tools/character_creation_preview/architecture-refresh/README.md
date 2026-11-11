# Character creation: architecture refresh and opening crest

Prepared on 2026-11-11 after architecture commit `f785176e`, then refreshed
through the approved special-building pass. The user accepted the comparison
and requested complete game integration and main merge on 2026-11-11. All six
backdrops and the small recommended opening crest are now adopted into the
round's game files. The art/UI change is compatible; the encompassing building
release remains a map reset. This browser acceptance is not a native desktop/web
GUI test. Delivery status belongs to [STATUS](../../../docs/STATUS.md).

Open [index.html](index.html), or serve the **repository root** (the page uses
relative links to existing assets):

```sh
python3 -m http.server 8876 --bind 127.0.0.1
# http://127.0.0.1:8876/tools/character_creation_preview/architecture-refresh/
```

## Findings and recommendation

The existing scene builder reads real building templates with their start-town
palette bindings. No manual facade repainting is necessary. The saved native
scene recipes and cameras are identical after rebuilding, including each
character's calibrated standing point. Six 1540 × 1400 renders were checked;
**all six are adopted**. The initial undead chapel/ruin scene was
unchanged, but the user's subsequent approval of the remaining city proposals
includes both buildings. Its updated image now matches their dark frame/roof
and preserved ruin silhouette. The elf shrine also uses the revised marble
piers, silverwood, green course and original pale roof. See the
[special-building follow-up](../../city_architecture_specials/README.md).

The before images are the archived PNGs shipped before this integration. Their historical render
predates some 0.73.1/0.75.1 adjustments, so the rebuild also includes such fixes
as thin tables and opened human shutters. `comparison.json` records changes,
removed/added cells and PNG hashes; it does not claim pure material replacement
relative to those older screenshots. Terrain, trees, props, camera and scene
placements retain their authored settings.

The opening scene uses separately authored military fortifications rather than
the ordinary-house templates. Keep it. Use the approved transparent
[`plain_512.png`](../../branding/exports/plain_512.png) crest as a separate UI
image, centered in the lower part of the opening scene above “Choose your fate”.
The smaller proposal is about 128 px square in a 1600 px-wide mockup; the larger
comparison is about 176 px. Size should follow the native UI scale in actual
integration. Keep title/hint as native text and hide the crest after race
selection. No raster logo redesign, background bake or animation is needed.

The opening mockup approximates the current native composition but is not a
Luanti capture; the sidebar is illustrative. Original/small/large can be switched
on the page. The scene comparisons show the actual native-camera background
PNGs without a character overlay, to expose the architecture clearly.

## Rebuild and evidence

```sh
python3 tools/character_creation_preview/architecture-refresh/build-scenes.py
node tools/character_creation_preview/render-scenes.mjs \
  --directory tools/character_creation_preview/architecture-refresh/native \
  --width 1540 --height 1400
python3 tools/character_creation_preview/architecture-refresh/build-page.py
node tools/character_creation_preview/architecture-refresh/check.mjs
```

`CHROME_BIN` selects Chromium. Each browser process has its own disposable
profile. The script writes only isolated proposal files. `scenery.main()` and
`native.build()` gain optional output arguments while their existing default
entry points retain their behavior; this proposal explicitly disables the
native camera Lua write. `preparation.json` checks the source recipes and pins
all creation Lua/PNG hashes before and after building. Native render receipts
bind source digests, PNG hashes, cameras and dimensions.

`browser-check.json` records 28 passing checks, zero JavaScript errors and
15 captured comparisons/variants at 1600, 1366 and 390 px viewport widths.
The coordinator visually inspected all six comparisons and both logo sizes.
The initial source/provenance/visual review passed with five changed images.
The subsequent approved special-building pass also updates the undead scene;
current browser checks cover all six replacements. The original browser-only
preparation needed no extra game boot. The adopted native integration now runs
character-creation fixtures, Lua checks and the final main gates recorded in
the round plan, including an isolated engine boot.

Adopted assets and source hashes: [installation.json](installation.json).
The images are copied byte-identically; the crest remains transparent and is
shown only on the opening screen. The source renders under `../native` stay
archived as the before-comparison baseline; current installed art is sourced
from this directory's `native/renders`. Future refreshes should preserve that
baseline and update the mod's media ledger. Native desktop/web acceptance still
checks crest spacing and the six backdrop/character combinations.

Scene media retain the source licences documented by the parent
[scene study](../README.md) and [opening study](../intro/README.md). The crest
uses the approved branding export and its [media record](../../../menu/LICENSE-media.md).
The new HTML/authoring arrangement introduces no replacement artwork.
