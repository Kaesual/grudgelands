# Round 11 ART implementation evidence

Status: implemented on `wp29-r11-art`; independent review and integration remain
pending. No main merge, sync, push or GUI acceptance is claimed.

## Delivered presentation

- Seven bow identities use five visually inspected Lord of the Test arc sprites:
  plain wood for the starter, Lebethron for Bronze, Birch for Iron and the
  brighter Steel / violet Abyssal grades, Mallorn for Silversteel and warm Alder
  for Embersteel. Six shield identities use the matching Bronze, Copper, Steel,
  Silver, Gold and Galvorn shield silhouettes. All sources are pinned at
  `f164140154945f0b356521ae721a86e9c7a0e0cf`, CC BY-SA 3.0.
- The Goldsmith book and player arrow use VoxeLibre's enchanted-book and arrow
  inventory sprites at `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`, CC BY-SA
  4.0. Books retain one silhouette with restrained tier color grades.
- Cloth bags use LotT small, medium and large shapes; leather bags reuse those
  readable silhouettes with a brown material grade. The large bag is Brett
  O'Donnell's BSD-3-Clause work; small and medium are Amaz, CC BY-SA 3.0.
  The generated transparent quiver is registered directly and bounded through
  `^[resize:64x64`; it is no longer a tinted bag placeholder.
- Nine SaKeL `x_farming` seed sprites pinned at
  `ac5f69d5103d4af841b1a5ed3a0b49a4e19d0c84` cover all 17 crop identities via
  a pure map. Shared silhouettes receive fantasy-family color grades, and no
  seed reuses its harvest icon. Crop growth nodes and timing are unchanged.
- Silversteel weapon and gathering-tool metal ramps are now bright neutral
  silver with subtle cold shadows. Existing armor inventory and worn silhouettes
  receive the same neutral HSL treatment, preserving their accepted forms.
- Bow wielding dispatches through the `grug_bow` group before the general
  weapon group. The dedicated pose anchors the measured 16x16 arc midpoint in
  the fist and uses rotation `(90,45,-90)` so the arc stands upright and faces
  forward. Sword, staff, axe, tool and anonymous-icon transforms are unchanged.
- Station presentation from ART commit `c76e6bba` remains active: VoxeLibre
  anvil and loom media, four-box shared forge, muted-gold Goldsmith head with a
  dark base, cube loom and upright Woodcarver bench. Station behavior remains
  factory-owned.

Every imported file, author, pin, license and treatment is recorded in the
owning mod's `LICENSE-media.md`. No unwrapped model texture is used as an item
icon and no upstream code is imported.

## Focused checks and views

- `media_kat.lua` verifies 17 seed bindings and every expected bow, shield,
  book, arrow, bag and quiver file. `gear_catalogue_kat.lua` loads the real gear
  module and reports `PASS 0`, including exact registered bow, shield, book and
  starter images. `wield_transform_kat.lua` reports `PASS 0`, including bow
  group precedence, centre grip and exact pose rotation.
- Plain Lua 5.1 parsing passed for all changed Lua files. SETGLOBAL inspection
  finds only the declared `grug_gear` table. All five sweeps were inspected;
  hits are existing comments or string vocabularies. No PUC runtime was run.
- `evidence/media-sheet.png` is the enlarged actual-media inventory review.
  `evidence/wield-bow.png` is a live-transform side-view comparison: the old
  tool grip visibly hangs the bow by its end, while the Round 11 pose holds the
  arc midpoint through all four sampled arm angles.
- `source-inputs.sha256`, `media.sha256` and `views.sha256` bind production,
  fixtures, every changed/imported media file and both inspected views.

Final first-person/third-person appearance, runtime texture modifiers and the
inventory scale remain fresh-world GUI acceptance items.
