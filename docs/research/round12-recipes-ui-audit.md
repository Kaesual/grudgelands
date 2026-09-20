# Recipes and UI audit (read-only)

Baseline: `cca8b7ce`, branch `wp11-interaction-followups`. No source changes or runtime tests.

Coordinator update after this baseline audit: the user chose starter recipes visible
immediately, with other universal recipes revealed by first acquisition of their
main material. This is now recorded in living design; runtime implementation is
next-round work. The contradictions below describe the baseline before that
choice, not the amended contract. Crafting permission remains independent.

## Basics: shipped behavior versus living design

The living contract says Basics is the exclusive profession-free category, everyone may craft plain weapons/tools/armor, universal Basics routes have no profession gate, and `_grug_ilvl` is independently the use/equip gate (`docs/design/inventory_equipment.md:243-260`; `docs/design/items_crafting.md:293-303, 856-858`). It also explicitly rejects ingredient-discovery as an unlock system (`docs/design/items_crafting.md:217-218, 326-334`).

Production registration does contain all six tiers of every universal base weapon family: sword, dagger, greataxe, wand, staff, bow and shield, plus tools and all three armor lines (`mods/ITEMS/grug_professions/base_recipes.lua:1-126`). The loop has no character-level condition. Therefore, if a level-1 player physically has Abyssal materials, the engine grid recipe is craftable; the resulting `_grug_ilvl` prevents use/equip until its level floor. This matches the current “materials gate crafting, item level gates use” design. Choosing all-visible versus a T2-and-up reveal rule would be a new UI/design decision, not a correction to the craft authority.

The Basics book is derived at runtime from every registered engine grid/furnace recipe (`mods/PLAYER/grug_jobs/ui.lua:107-173`). It does not re-register or authorize them. General records are always progression-unlocked (`ui.lua:235-238`), but the visible list then requires `recipe_discovered` (`ui.lua:240-264`). Discovery requires **every non-empty input token** to have appeared in `main` or `craft`; the inventory scan runs every two seconds (`mods/PLAYER/grug_jobs/discovery.lua:1-92, 116-146`). Group inputs become visible after any seen item matching the group.

That filter explains missing base weapons without missing registrations: a sword needs its tier bar plus a seen stick/rod route; wand/staff/bow need the processed wood, and bow also needs thread. A player who has seen the metal but not the handle/thread remains told only that undiscovered recipes exist. The UI shows per-tier undiscovered counts but no identities (`ui.lua:459-491`). Discovery affects visibility only; engine Basics crafting is not vetoed by it. This shipped hidden-input model conflicts with the living design’s “no ingredient-discovery unlocks” statement. The current Help page also does **not** explain recipe discovery or material pickup; it contains combat formulas only (`mods/PLAYER/grug_inventory/pages.lua:199-227`).

Output provenance is sound: profession registrations are excluded from the inferred Basics list through the real `recipe_for_craft` input-language lookup (`ui.lua:137-141`; `registry.lua:690-739`). The missing entries arise after catalog construction, in the discovery filter.

## Inventory and talent layout

All sfinv pages use the default `size[8,9.1]`; the shared inventory begins at y=5.2 (`mods/BASE/sfinv/api.lua:45-59`).

The Character page places its preview at x=0..2.4, y=0.85..4.85 while the third stat label starts at x=0, y=1.0 (`mods/PLAYER/grug_inventory/pages.lua:145-156`). This is a real overlap hotspot: Dodge text occupies the model rectangle. Long HP/Mana/Armor derivation labels are unbounded `label[]` elements; pinned Luanti does not automatically wrap this label form (`reference_projects/luanti/doc/lua_api.md:3417-3436`). They can run beneath the equipment columns at x=6/7 (`pages.lua:59-68, 145-164`).

The Talents page fits vertically: talent rows end near y=4.33 and the selected description starts at y=4.35, above the shared inventory at y=5.2 (`mods/PLAYER/grug_classes/talents_ui.lua:178-232`). Horizontally, each chain occupies 3.75 units at x=0 and x=4, fitting within width 8. The crowded behavior comes from long button labels and tooltips, not coordinate overlap. Locked talents use plain labels rather than buttons, while every row adds an area tooltip. Tooltip strings concatenate name, full talent description and lock reason into one line (`talents_ui.lua:201-224`).

Pinned Luanti creates the single shared tooltip element with `setWordWrap(false)` and sizes it from the full text width (`reference_projects/luanti/src/gui/guiFormSpecMenu.cpp:3228-3240, 3885-3932`). Newlines can increase text height, but there is no automatic wrapping. Several talent descriptions are long enough to create very wide tooltips (for example `mods/PLAYER/grug_classes/talents.lua:347-365, 482-492, 545-578` and `scout_talents.lua:114-124`). By contrast, the selected-talent footer is a read-only `textarea`; the engine explicitly wraps text and adds a scrollbar on overflow (`lua_api.md:3408-3416`). Its 0.55 height is still visually tight for multi-line copy, but it has the correct widget semantics.

## Recipe-book layout and furnace arrow

The standalone recipe book is `size[10,9.8]` and does not embed the normal inventory (`mods/PLAYER/grug_jobs/ui.lua:446-496`). Fourteen result buttons occupy y=1.45 and 2.70; the separator is y=4.65, leaving clear space. The recipe grid begins at x=1.25, y=5.65. The rotated furnace-arrow image is at x=4.15, y=6.55 with size 0.9×0.7, and output is at x=5.25, y=6.35 (`ui.lua:389-445`). It is horizontally between the input grid (right edge 3.87) and output (left edge 5.25), not below the recipe. For a furnace recipe the sole input is deliberately centered at column 2/row 2, y=6.55, so arrow and input share a vertical center. The station icon at x=0.25 is separate. I found no coordinate collision here.

The recipe hint at y=8.52 is an unbounded `label[]`; long future hints could collide with the Close button at y=8.92, but current hints are short fixed station names. Group-input tooltips can become very wide because every matching item label is joined with “or” and tooltips do not wrap (`ui.lua:406-428` plus the engine behavior above).

## Discussion boundaries

The code currently implements: all universal base gear registered at every tier; no Basics craft-level gate; use/equip gated by item level; visibility hidden until every input has been observed. The last behavior is the material-pickup discovery system and is the source of apparently missing base weapons. The living docs instead call for an always-open Basics catalog without ingredient-discovery unlocks. Resolving that contradiction should precede choosing whether higher tiers are all visible or revealed by character/material band.
