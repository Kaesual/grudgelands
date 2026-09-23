# Round 18 H1 — active-skill action artwork

Date: 2026-09-23. Author: native Astra art lane. Independent visual review
is pending and is owned by the coordinator; this is an author handoff, not
an acceptance report.

## Deliverables

22 opaque 64×64 RGB PNGs in `mods/PLAYER/grug_abilities/textures/`, named
`grug_abilities_skill_<id>.png`. The complete ID/filename mapping, exact
per-image generation prompts, original built-in output paths and final-file
SHA-256 hashes are in [manifest.json](../../tools/r18_art/manifest.json).
All generated project assets are copied into the repository; runtime needs
neither the original generation directory nor a network service.

[Gallery](../../tools/r18_art/gallery.html) shows actual 32 CSS pixel and
128 pixel images. [Contact sheet](../../tools/r18_art/contact-sheet.png)
shows all 22 before/after entries, including 32px normal, illustrative
cooldown and illustrative charge states and 128px enlarged art. Browser
zoom must be 100% for the gallery's actual-size check. The sheet and HTML
are offline review aids, **not live-engine GUI screenshots**. The old images
are representative reconstructions of the old tinted orb plus equipped
weapon scheme (iron sword / wood staff / wood bow), not claims about a
particular player loadout. Both bar states are shown for every icon to
stress visibility; this does not claim every skill has both mechanics.

`tools/r18_art/build_gallery.py` rebuilds the evidence from final assets;
Pillow is required. Existing packaged PNGs are not overwritten. The original
local generation path is used only to package a missing final PNG.

## Reference-first assessment

Inspected VoxeLibre's pinned reference checkout
`c2dbc520ff4e1637072d33b06c3a2404e0f08df7`, including the actual raster files
`mcl_fire_fire_charge.png`, `mcl_bows_arrow_inv.png`,
`mcl_potions_effect_strength.png`, `heart.png`,
`weather_pack_snow_snowflake1.png` and `mcl_shield_base_nopattern.png`.
These are recognizable inventory objects or tiny status/effect marks, but
do not provide a complete semantic action family for the approved 22 skills.
The shield is also a model-layout texture, unsuitable as this action icon.
Existing Lord of the Test search results were principally equipment shields
and magical arrows. Recoloring such objects would repeat the exact weakness
this lane must fix. Therefore no reference artwork was imported, modified
or supplied to generation. No new third-party license obligations arise.
The reference checkout and its pins were not changed.

## Generation and composition

Used the authorized built-in **image_gen.imagegen** tool, one new-image
call per skill; 22 calls, no discarded variants or regeneration loop.
No CLI, API key, separate provider or programmatic drawing replacement was
used for the artwork. Packaging uses only RGB conversion and Lanczos
downscaling. The precise prompts and original output locations are retained
in the manifest. The project license dedication is recorded in
`mods/PLAYER/grug_abilities/LICENSE-media.md`.

The common visual treatment is a large bright action silhouette on a dark
charcoal-blue square. Semantics come from shape rather than palette alone:
single fireball versus raining meteors; radial frost burst versus icicle
shield; healing hands/cross versus renewing heart/leaves; free arrow versus
rope snare versus pinned boot. Sideways evasion uses one boot and a curved
side arrow; sprint uses a forward running stride and speed lines. Ordinary
strike is a sweeping blade, heavy blow an impact hammer, and Opening a
dagger exploiting an armor gap. The latter two are action metaphors rather
than a claim that a particular weapon is equipped.

H2 must use the PNG unchanged for inventory, hotbar and Skills catalogue:
no weapon overlay, per-class multiply or orb underneath. Keep equipped-weapon
wield/third-person images independent, including draw stages and empty-slot
behavior. Keep the engine's existing wear/charge bar above the image; the
illustrative evidence places the bar in the lower three pixels of a 32px
cell. No mechanic or real wear color is changed by these art files.

## Author inspection and remaining validation

The author visually inspected the generated series in the contact sheet at
32px and enlarged size, including both bar overlays. The series has 22
distinct action compositions. All files decode as 64×64 RGB PNG, all IDs
are unique and match the frozen requested roster, and hashes are recorded.
No Lua, accepted equipment, mount, crop or reference files were edited.

Independent visual review remains required. After H2 integration the user
runtime check is: compare Warrior, Mage, Priest and Scout Skills catalogue
to their hotbar; activate a cooldown and charge a swing/bow; swap equipped
weapons and confirm the action icon stays while the held weapon changes.
Check the talent actives and empty weapon slot as well.
