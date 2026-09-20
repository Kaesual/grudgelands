# Round 12 UI, art, recipes and original-class talents plan

## Scope and ordering

This plan is implementation-ready but does not authorize implementation. It covers four bounded delivery lanes and one report-only lane. Farming, the Skills inventory/tab, held-item fallback rotation and the global five-minute food duration are coordinated elsewhere.

1. **R12-R — Basics discovery, recipe presentation and Help onboarding.** Freeze the accepted visibility contract, replace all-input discovery with explicit main-material discovery, and repair the recipe/Help presentation.
2. **R12-U — Character and talent readability.** Fix verified overlap and wrapping failures without changing the shared inventory boundary or talent semantics.
3. **R12-T — WP11 X3 for Warrior, Mage and Priest.** Implement the remaining original-class keystones, capstones, replacements and four new abilities. Preserve the delivered Scout trees and Ironbound/Unbroken code.
4. **R12-A — Food, wand and Greataxe art.** Replace weak result icons and the two rejected weapon silhouettes through one licensed, cross-tier-consistent art pass.
5. **R12-Q — independent UI/UX walkthrough, report only.** Return findings for later user selection; this lane may not change game files.

R12-R and R12-U may run in parallel only with explicit ownership of `grug_jobs/ui.lua` versus `grug_inventory/pages.lua` and `grug_classes/talents_ui.lua`. R12-T must not share `talents_ui.lua`; it should consume the existing talent model and change runtime consumers. R12-A can run independently after its source/licence inventory is frozen. Integrate R12-R before the report-only walkthrough so the walkthrough assesses the intended onboarding.

## R12-R: exact Basics visibility contract

Authoritative design: `docs/design/items_crafting.md` §2.2 and `docs/design/inventory_equipment.md` §4.

### Starter set (visible for a new character)

Use an explicit output allowlist, not `tier == 1` as an implicit shortcut:

- bootstrap conversions and stations: wooden planks where a reversible wood conversion exists, `default:stick`, `default:torch`, `default:chest`, `default:furnace` and the actual wooden hoe id `grug_farming:hoe`;
- every T1 Bronze universal base weapon, tool, shield and metal armor recipe;
- every T1 Patch cloth armor and Light leather armor recipe;
- T1 Seasoned Wood, Thread, Patch Bolt and other profession-free T1 feedstock preparations needed by the T1 wand/staff/bow/cloth routes;
- the universal arrow recipe. Cooking-owned dishes/refinements, including Bread, remain solely in Cooking and can never enter Basics through this starter allowlist.

This set gives a first-session player useful goals and lets them inspect the complete first material band before acquiring every component. It does not grant ingredients or crafting permission. Do not expose all T2-T6 recipes as a preview.

### Main-material attribution

Add an explicit Basics-presentation registry owned by `grug_jobs`, keyed by the complete route identity (`station`, output name, method/shape/input signature). Each entry declares either `starter = true` or exactly one `main_material` token. Duplicate routes may share an output but retain separate declarations. Catalog construction must reject a missing or ambiguous declaration in a deterministic audit; it must not guess from input order.

Content owners declare the following rule per route:

- metal weapon/tool/rod/metal-armor/shield route: that route's tier metal bar;
- cloth armor: its tier bolt; leather armor: its tier leather/hide;
- wand, staff and bow: their tier processed wood;
- arrow: iron bar;
- material conversion: the unprocessed material that the route transforms (ore for a bar, raw wood for processed wood, fibre for thread/bolt, raw hide for leather); alloy/dual-furnace routes use the tier-defining metal input rather than fuel or the lower-tier carrier;
- ordinary construction/decor/storage output: the material that defines the output's visible substance (wood, stone, glass, metal, wool, etc.); furnace food: its raw food;
- group material declarations remain group tokens. Acquiring any concrete matching item reveals the route.

“Acquire” means an item first appears in any player-owned inventory list, including `main`, crafting grid, bag contents and quiver where type-valid, or is delivered by crafting, trade or container transfer. Scan inventory changes through existing inventory/action seams where available and retain a slow reconciliation scan for engine/foreign writes; do not use a ground-pickup-only callback. Persist concrete seen item names in the existing sorted meta list. A newly seen material refreshes an open book once, without per-step formspec churn. Discovery only filters display; it never vetoes engine crafting.

The implementation must inventory every current **general/non-profession** recipe and land a declaration for every route in the same package. A fixture must compare the runtime Basics catalog against the declaration registry and fail on uncovered, stale or multiply matched routes. Its provenance cases must explicitly prove that Cooking Bread and every other professional route remain excluded before starter/discovery filtering is applied.

### Recipe book and Help UI

- Preserve real 3x3 shapes. Furnace recipes show one input, the input-to-output arrow, and the furnace as a clearly labelled station indicator below that relationship; the furnace is never drawn as an ingredient. Keep dual-furnace and custom-station layouts distinct.
- Replace long one-line group-alternative tooltips with explicit line breaks and a bounded number of alternatives plus a count/continuation line when needed.
- Keep undiscovered counts by tier, but explain “Acquire the main material to reveal more recipes.” Never imply permission is unlocked.
- Put a short first-session route at the beginning of Help: gather materials; open Crafting > Basics; craft/equip a weapon; put a combat skill on the hotbar; fight and recover; then visit city services and profession trainers. Mention that starter recipes are visible immediately, main-material acquisition reveals later Basics recipes, and visibility is separate from permission. Do not mention quests or Housing as playable goals.
- Add a **Food** tab/category to Creative beside All/Nodes/Tools/Items. Derive its contents from the authoritative registered food API/groups so all edible raw ingredients and cooked results appear even when an item has no recipe in the selected recipe book; do not maintain a hand-written item list. Creative text search and paging continue to work within Food. A recipe-book food filter is optional and cannot substitute for this Creative category.

Owned files: `mods/PLAYER/grug_jobs/discovery.lua`, `mods/PLAYER/grug_jobs/ui.lua`, `mods/PLAYER/grug_jobs/registry.lua` (or one new small Basics presentation module), content registration files that own Basics recipes, `mods/BASE/creative/inventory.lua` with a `-- GRUG PATCH:` marker (or a wrapper seam if load order permits), `mods/PLAYER/grug_inventory/pages.lua`, focused quality fixtures, and the two living design sections. Avoid changing crafting authority.

Acceptance: fresh player sees the explicit starter set; acquiring only the declared main material reveals every route attached to it; auxiliary handles/thread do not gate visibility; bag/container/craft/trade acquisition is observed; relog preserves discovery; a player can craft a still-hidden recipe if they know it and own inputs; every current Basics route has exactly one declaration; furnace/station visuals are semantically correct; Help and Food filtering work at the default formspec size.

## R12-U: Character and talent readability

The current shared form is `size[8,9.1]` with inventory beginning at `y=5.2`; this is evidence for the defect, not a frozen constraint. The UI owner may enlarge/recompose the shared page geometry coherently when that gives wrapped content enough room. Character, Bags, Talents, Crafting, Help and the new Skills page must use the same resulting inventory boundary and remain navigable at default scale.

- Recompose Character so the player preview and Dodge/stat text never share a rectangle. Put concise live values in fixed columns and move long derivations into bounded wrapped text/tooltip/help content. Check long localized labels at the default UI scale.
- Keep both talent chains and all four tiers above the shared inventory boundary, but shorten row labels to stable names/ranks and move descriptions/status into a materially taller wrapped `textarea` footer. Tooltips may contain concise multi-line summaries, with explicit newlines; never concatenate the full description and lock reason into a single unwrapped line.
- Locked and available rows must have the same visual geometry and a clear locked state. Preserve select-then-click-again purchase semantics, respec confirmation, tree gates, stat values and tab ordering.
- Apply the same bounded-tooltip helper to group alternatives in R12-R rather than inventing two wrapping algorithms.

Owned files: `mods/PLAYER/grug_inventory/pages.lua`, `mods/PLAYER/grug_classes/talents_ui.lua`, optionally one formspec text helper in the owning mod, and focused formspec fixtures. Do not edit talent definitions or effects in this lane.

Acceptance: no generated element crosses the preview/equipment/shared-inventory bounds; longest current talent and lock reason fit or scroll in a wrapped control; every talent remains selectable/purchasable under the same rules; Character and Talents render with no truncation-dependent information loss.

## R12-T: WP11 lane X3 completion

Authoritative scope is `docs/design/skill_trees.md` §2.1-2.6, §3 and the X3 row in §4, as amended by WP47's Skills-inventory contract. Implement the four new registrations Hold Ground, Cinderfall, Glacial Ward and Word of Ruin; expose eligibility for talent-gated Renew and Hamstring; implement Bellow, Broadstroke, Brand, Frostbind, Turn Aside, Recompense and Hearten inside the owning ability settlement paths; implement Tendon Cut and the remaining Ruination, Whitehot, Rimebite and Last Word windows/cap override. Preserve Round 11's Ironbound/Unbroken and Scout consumers. X3 publishes current eligibility to the WP47 seam; it does not auto-grant, append, or recreate a missing skill item except for WP47's agreed character-creation default behavior.

Likely owned files are `mods/PLAYER/grug_abilities/kits.lua`, a bounded new original-class X3 module if that keeps `kits.lua` reviewable, `mods/PLAYER/grug_classes/stats.lua`, `mods/PLAYER/grug_classes/talents.lua` only where lifecycle/window APIs need extension, `mods/CORE/grug_core/combat.lua` only for an already-specified shared absorb/settlement seam, and focused ability/talent KAT fixtures. Treat `grug_mobs` threat and movement APIs as dependencies, not rewrite targets. WP47 exclusively owns shared Skills-page/eligibility integration and any concurrent `grug_abilities/init.lua` edit; coordinate through its frozen seam rather than editing that file from X3.

Acceptance is one deterministic probe per replacement/new ability/finisher, plus lifecycle probes for death/leave/respec, exact-once costs and cooldowns, hostile current-ray authority, friendly target fallback, cap restoration after windows, eligibility appearing/disappearing through the WP47 seam without recreating player-deleted stacks, and preservation of Scout plus Unbroken behavior. Headless engine runtime remains required by the WP11 design after standalone checks.

## R12-A: careful art pass

The source audit confirms the structural issue: all 18 Cooking dishes are only three borrowed silhouettes (clay lump, apple, raw fish) recolored by tier; six raw assemblies are one recolored clay lump; bread is also a clay lump; every wand is a recolored Mese fragment; and all six Greataxes share a narrow single-bit bearded-axe silhouette. I also viewed a nearest-neighbour contact sheet containing the three base silhouettes and all six current Greataxes; it confirms the Greataxe's narrow single-bit form. Jungle Cocoa uses the apple source silhouette. These are all replacement candidates. Accepted crop ingredients, swords, one-handed axes and armor are frozen and must not be altered.

### Asset checklist

1. Build a labelled contact sheet at native 16x16 and nearest-neighbour 8x scale for every cooked/refined food result: 18 dishes, six raw assemblies, bread, cooked meat and cooked fish. Judge silhouette at native size, recipe recognition, uniqueness among adjacent inventory entries, palette separation, transparency and outline readability.
2. Give each cooked result a recipe-appropriate silhouette. Reuse a coherent vessel/plate vocabulary where appropriate, but vary visible contents and garnish: stew/pot, mash/bowl, crusted fish, preserve/jar, roast/platter, skewer, chowder/bowl, feast/platter, broth/cup, etc. Raw assemblies must visibly read as uncooked preparations and remain distinguishable from their finished output.
3. Jungle Cocoa must read as a prepared cocoa drink or bowl/cup of cocoa with a brown cocoa palette and optional steam/highlight; it must not use a round red fruit silhouette. Cocoa-Rubbed Game and Grand Feast must remain distinct from it.
4. Create a real wand silhouette: short grip/shaft plus an intentional magical focus, clearly different from a loose crystal, dagger and staff. Produce all six material tiers with stable geometry and the existing tier palette language. Inspect inventory icon and held silhouette.
5. Replace the Greataxe with a large, symmetric or near-symmetric **double-bit axe**: two broad opposing blades, a centered eye and a long haft. It must read as an axe rather than a halberd/spear, remain diagonal grip-bottom-left/business-end-top-right, and preserve one shared silhouette across all six tier palettes.
6. Cross-tier check: geometry and occupied-pixel mass remain stable; tier identity comes from controlled material palette/detail, not silhouette drift. Compare beside accepted swords, one-handed axes, armor and the generated quiver for style/scale only; do not modify those families.
7. Source/licence gate precedes import. Prefer compatible assets already pinned in `reference_projects/` when their exact media licence and attribution are verifiable; otherwise create original project art (image generation may be used as concept input, but final 16x16 sprites need deliberate pixel cleanup and provenance). Do not copy unverified web images. Record every source path, pinned commit, author/licence, modifications and output mapping in the owning `LICENSE-media.md`; update `VENDOR.md` only if shipped foreign source/code requires it. Generated/original outputs must be labelled as such rather than attributed to an unrelated base sprite.
8. Use deterministic scripts for palette variants and byte reproduction where practical. Final assets require alpha/dimension checks, filename/media audit, registration coverage, native/8x contact sheets, and in-game inventory plus held-item inspection. A fresh independent visual reviewer assesses the final contact sheets against this checklist; delivery includes labelled before/after galleries for the user.

Owned files: `mods/ITEMS/grug_cooking/textures/` (new result sprites), `mods/ITEMS/grug_cooking/init.lua`, its `LICENSE-media.md` (create if absent), `mods/ITEMS/grug_gear/textures/grug_gear_item_greataxe_*.png`, new wand textures, `mods/ITEMS/grug_gear/init.lua`, `mods/ITEMS/grug_gear/LICENSE-media.md`, and deterministic art scripts under `tools/r12_art/` if used. The lane is autonomous: the coordinator and independent visual reviewer select the strongest compliant result against the checklist and do not require a mid-round user gallery. Escalate only if no licence-cleared source or generated/original direction meets native-scale recognition after two concrete iterations.

## R12-Q: independent UI/UX report only

Use a fresh reviewer who did not implement R12-R/U/T. Walk character creation through first gathering, Basics discovery, crafting/equipping, skill placement, combat/recovery, Cooking discovery, Talents at locked and spendable states, bags, trader/profession UI and the revised art at inventory/held scale. Report severity, exact reproduction, screenshot/contact-sheet reference, player consequence and one proposed correction. Separate defects from preferences. Do not edit code, docs or assets; the coordinator returns the report to the user for scope selection.

## Verification budget and review

Current session override: **no PUC runtime and no broad suites**. During implementation, run `tools/bin/luac51 -p` on each changed Lua file, inspect `SETGLOBAL` for changed mod Lua, and run all five required source sweeps. Use LuaJIT for focused discovery/formspec/talent fixtures and the bounded headless X3 engine test; do not run mapgen, seed, VM, full performance or unrelated package suites. Asset checks use deterministic hashes, dimensions/alpha validation, registration coverage and contact sheets. Because all four implementation lanes are non-trivial, each receives an independent native Sol review under `docs/process/wp-workflow.md`; a fresh native Astra reviewer is appropriate for X3 if its cross-settlement state proves difficult. Claude/CLI/Opus/Fable are excluded by the current session rule.

The standing final-micro-KAT policy normally pairs one frozen-byte PUC run with LuaJIT. The explicit session override forbids PUC runtime here, so record that exception rather than substituting repeated LuaJIT runs or claiming interpreter parity. User runtime testing remains a separate final gate: default UI-scale page walkthrough, recipe acquisition paths, every X3 ability/replacement, food icon recognition, and wand/Greataxe inventory plus first/third-person held silhouettes.

## Documentation and integration

Before implementation, fold the now-decided starter/main-material and autonomous-art acceptance rules into living design. On completion update WP11 X3 status in `BACKLOG.md`/`ROADMAP.md`, update README Current State in the same commit, add art provenance, and remove `TODO-round12-planning.md` only when farming/Skills and every remaining question owned by that TODO are also resolved. Do not mark WP11 complete while placeholder respec prices remain unless the backlog continues to state that independent WP44 dependency explicitly.

## User questions

No user decision is required for these lanes. The starter set and main-material mapping above make the accepted rule concrete; the art brief supplies autonomous selection criteria; and the UI/UX audit is report-only. The coordinator can start after the user gives the requested green light for the round.
