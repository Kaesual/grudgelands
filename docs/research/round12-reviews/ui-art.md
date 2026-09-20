# Round 12 UI and ART independent review

## Scope and provenance

- UI candidate: `562c1e48` against `63ef0faf` in `/home/jan/projects/grudgelands`.
- ART correction: `976d293f` against `b44093bd` in `/tmp/grug-r12-art`.
- This review excludes the Recipes and Skills implementations, which I authored.
- Read-only review. No candidate files or user worlds were changed. No PUC runtime or broad suite was run.

## UI verdict: PASS

No blocking, high, medium, or low findings.

The shared `sfinv.make_formspec` override retains the vendored API signature and navigation call while moving the 8-slot hotbar and 24-slot main inventory to the documented `10.4 x 11.1` boundary (`mods/PLAYER/grug_inventory/ui.lua:26-37`). Existing Creative content stays within x=8.05/y=5.0, the Skills catalog within x=8.35/y=5.65, Bags including the 2x2 quiver within x=10.3/y=5.35, and the Character/Talents content ends before y=7.0. The new rightmost equipment and quiver cells end at x=10.3, leaving the intended margin. I found no overlap with the inventory beginning at y=7.2.

The Talents page retains the original field names and receive-fields paths for tree selection, two-click purchase, confirmation/cancellation and respec. The two 4.95-wide chains fit the form, and wrapped tooltips plus the 10.1x1.85 selected-description area address the reported single-line overflow (`mods/PLAYER/grug_classes/talents_ui.lua:183-232`). The committed focused fixtures report PASS for all four classes at levels 1 and 60 and for the interaction paths; GUI rendering remains correctly identified as a user playtest gate rather than fixture evidence.

The Help introduction accurately describes the implemented starter loop, Basics material discovery, Skills recovery/duplicate rule, equipment, food duration, trainers and separate Cooking book (`mods/PLAYER/grug_inventory/pages.lua:208-214`). Its statement about no character-level restriction occurs specifically in the Basics paragraph and matches `docs/design/inventory_equipment.md` section 6.

The Food tab is registered after all mods load, snapshots every registered item with `groups.grug_food > 0`, and passes the table shape expected by Creative's existing searchable/paged `register_tab` API (`mods/PLAYER/grug_inventory/ui.lua:40-49`; `mods/BASE/creative/inventory.lua:147-255`). `creative` is an optional dependency, so it is loaded first when present; raw gathering/cooking ingredients and cooked dishes receive the same marker through `grug_food.register_item`. The absent-Creative branch is safe.

Evidence inspected: committed layout/talent logs, static summary, source hashes, upstream sfinv/Creative implementations, all `sfinv.make_formspec` call sites, and relevant group registration paths. The evidence reports `luac51 -p`, SETGLOBAL, five sweeps, diff-check and reference-pin checks passing on the frozen source set.

## ART verdict: PASS

The two prior Medium findings are resolved.

- The six Greataxes now have two equal broad blade polygons reflected around the diagonal haft with a centered eye. At native size they read as double-bit axes rather than halberds; at 10x nearest-neighbour scale the geometry is balanced and the grip/upper-right business-end convention remains intact.
- The food review set now contains 27 entries and visibly includes Cooked Meat and the resolved Cooked Fish texture in both native and enlarged galleries. Jungle Cocoa remains a distinct brown steaming drink. The authored dish silhouettes and palettes remain distinguishable at native scale, while the enlarged plate exposes the intended ingredient cues.

Mandatory visual inspection covered `food-before-after-native.png`, `food-after-8x.png`, `weapons-before-after-native.png`, and `weapons-after-10x.png`. `sha256sum -c tools/r12_art/evidence/assets.sha256` passed for all 39 listed shipped/source assets. The README records deterministic Pillow regeneration, the non-shipping concept-sheet role, and the correction provenance. Other accepted asset families are unchanged by `b44093bd..976d293f`.
