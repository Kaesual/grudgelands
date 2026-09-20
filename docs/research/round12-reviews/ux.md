# Round 12 newcomer UI/UX audit — report only

## Scope, evidence and limits

Audited integrated candidate `d6d49147e1799b8e6606f5e28033ce92ea26e3c5` on branch `wp12-round12`. This is an independent, source-driven first-session walkthrough; I did not implement R12-R/U/T, edit game files, run Luanti, open a user world, or run tests. Formspec findings below are source/geometry findings, not claims from an observed live GUI. Visual findings come from rendered nearest-neighbour evidence plates, not from inventory or held-item screenshots.

The walkthrough covered character creation and arrival, gathering, Basics/material discovery, craft/equip, Skills/hotbar, combat/recovery, Cooking, locked and spendable Talents, Bags, traders, profession trainers, and the revised art. Recipes (`/tmp/grug-r12-recipes`) and X3 (`/tmp/grug-r12-talents`) were still awaiting correction/review and integration, so I do not report their known stale-baseline behavior as a candidate defect. A final-hash recheck should only verify that their integration did not alter the findings or cited seams below.

## Defects

### Q1 — Medium: the first Help objective asks the player to replace an already equipped starter weapon

**Evidence class:** source/flow inference; not observed GUI.

**Exact reproduction:** create any class, arrive at its start, open Inventory > Help, and follow the first paragraph. It says to inspect Basics, “craft a weapon and equip it on the Character page” (`mods/PLAYER/grug_inventory/pages.lua:208-214`). Character creation already grants a class-specific sword, staff, or bow and places it directly in `grug_weapon` (`mods/PLAYER/grug_inventory/equipment.lua:624-675`; class mapping at 661-666). The following Help paragraph again explains that weapons belong in the Weapon slot.

**Player impact:** the very first directed task presents an already-completed equipment step as a missing prerequisite. A newcomer can spend scarce early materials on a redundant weapon, or search for why combat supposedly is not ready even though the character is armed. This weakens the otherwise useful start route from gathering to Basics to combat.

**One correction:** change the first route to have the player inspect the equipped starter weapon, craft one useful Basics upgrade or tool, and then place a combat skill on the hotbar. Keep manual weapon equipping as a later explanatory sentence rather than the first required goal.

### Q2 — Medium: Skills combines abilities and mount tiers into one undifferentiated catalogue

**Evidence class:** source/geometry inference; not observed GUI.

**Exact reproduction:** open Inventory > Skills after owning at least one riding tier. `entries()` appends unlocked abilities and then mount tiers to one 16-slot list, while the form draws a single `8x2` catalogue under “Active skills and mounts” (`mods/PLAYER/grug_skills/page.lua:14-29,109-118`). There are no ability/mount section labels, row boundaries, or per-kind instructions. The only instruction says “Drag an unlocked skill,” even when the chosen entry is a mount. This also falls short of the approved R12 Skills presentation contract, which called for separate labelled ability and mount sections (`docs/research/round12-plan/skills-pose.md`, “Skills detached inventory”).

**Player impact:** an early player has to infer from icons/tooltips that some draggable objects cast abilities and others summon retained-speed mount tiers. As the catalogue grows, the transition from skills into mounts can occur mid-row, so scanning and recovery become less predictable.

**One correction:** retain the same detached-inventory transaction model but render two labelled catalogue rows/sections, “Abilities” and “Mounts,” and make the drag/delete instruction name both kinds.

### Q3 — Medium: the trader Sell instruction overstates what will be sold

**Evidence class:** source/interaction inference; not observed GUI.

**Exact reproduction:** put a vendor-buyable drop in a bag, keep `main` empty, open a trader, and switch to Sell. The page says “The vendor buys every drop you carry” (`mods/ENTITIES/grug_traders/trade.lua:221-240`), but `current_rows()` scans only the player's `main` list (`trade.lua:122-145`). The bag item is absent and the empty-state message says the player carries nothing the vendor wants.

**Player impact:** after Bags teaches the player that bag contents are carried inventory, the trader gives a contradictory result. A newcomer may conclude that the item is unsellable or the vendor is broken rather than moving it back to `main`.

**One correction:** change the Sell hint and empty state to say “main inventory” explicitly. This is the smallest correction and does not alter transaction scope.

### Q4 — Low: the profession unlearn warning is an unbounded line wider than its compact form

**Evidence class:** source/geometry heuristic; not observed GUI.

**Exact reproduction:** learn a profession, reopen its trainer, click Unlearn, and inspect the confirmation form at default scale. The `5.5x3.2` legacy form places `label[0.35,1.40;Unlearning permanently loses progression.]` without wrapping (`mods/PLAYER/grug_jobs/trainers.lua:19-27`). The available horizontal span is only 5.15 form units. Luanti `label[]` does not provide the bounded wrapping used by the R12 textarea/tooltip work.

**Player impact:** the irreversible-action warning is the text most likely to clip or extend outside the compact window, reducing confidence at the moment the player decides whether to erase progression.

**One correction:** place the warning in a small read-only wrapped textarea above the confirmation buttons, increasing the form height only if the default-scale render needs it.

## Preferences and later polish candidates

These are not established functional defects and should not expand the approved Round 12 implementation scope.

### P1 — Low preference: retained cooked meat and cooked fish no longer match the revised food vocabulary

**Evidence class:** rendered contact sheets only; not observed inventory UI.

**Reference:** `tools/r12_art/evidence/food-before-after-native.png`, final row, and `tools/r12_art/evidence/food-after-8x.png`, final two entries. The 25 revised foods use crisp bowls, pots, platters, jars, skewers, and raw bundles. The retained cooked meat remains a mottled diagonal bone/meat sprite, and cooked fish remains a muted whole-fish blob. They are recognizable in isolation but look inherited beside the new set.

**Player impact:** minor catalogue inconsistency; it does not obstruct cooking or item identity.

**One later correction:** redraw these two retained outputs in the same outline and palette discipline while preserving their unmistakable meat/fish silhouettes.

### P2 — Low preference: Salt Crust maturity is difficult to read from silhouette

**Evidence class:** rendered farming plates only; not observed world nodes.

**Reference:** the `salt_crust` row in `tools/r12_farming/evidence/crop-stages-17x4.png` and especially `tools/r12_farming/evidence/crop-geometry-17x4.png`. All four stages retain nearly the same thin vertical silhouette; most progression is a subtle color/fill change. The other families generally gain width, height, flowers, fruit, or branching.

**Player impact:** at world scale, a newcomer may have to inspect the node rather than recognize harvest readiness from shape. This remains a heuristic until an in-world screenshot confirms the contrast against its terrain.

**One later correction:** give the final stage a slightly broader crystalline crown or side cluster without changing collision or farming timing.

## Walkthrough areas with no reportable source-level defect

The mandatory faction/race/class sequence has explicit final-choice text and a safe loading state. Character geometry separates model, live stats, detail text, and equipment on the enlarged shared form. Talents retains equal locked/available row geometry, wrapped tooltips, a tall selected-description area, two-click purchasing, and respec confirmation. Bags exposes four bag selectors and an optional labelled quiver without crossing the shared inventory boundary. Help explains Basics discovery, Cooking ownership, food recovery, Skills recovery, and city services. Combat authority and five-minute food recovery expose meaningful feedback through existing item descriptions/chat/HUD seams, though their live clarity still belongs to the user's runtime playtest.

The revised food, wand, and double-bit Greataxe plates are materially clearer at native scale. Wands now read as handled magical implements rather than loose crystals, and Greataxes have broad opposing blades with stable tier palettes (`tools/r12_art/evidence/weapons-before-after-native.png`, `tools/r12_art/evidence/weapons-after-10x.png`). Crop families are substantially more distinct across the two farming plates, aside from the Salt Crust preference above.

## Final integration recheck

After Recipes and X3 integrate, recheck only: (1) Help wording against the final starter/Basics route; (2) the Skills catalogue with newly talent-gated active abilities present; (3) Cooking book discovery/provenance on final Recipes bytes; and (4) nav-tab readability after the final page set is registered. These are targeted source/geometry checks; the default-scale GUI, held art, world crops, drag/drop, hotbar combat, recovery, trader and trainer experience remain user-runtime observations.

## Bounded correction recheck — Q1 and Q2 resolved

Rechecked the uncommitted primary-worktree corrections to `mods/PLAYER/grug_inventory/pages.lua`, `mods/PLAYER/grug_skills/page.lua`, and the focused `tools/r12_skills/behavior.lua` extension against integrated head `d6d49147`. This was an independent code review of those diffs using the `docs/process/wp-workflow.md` checklist. I found no Critical, High, Medium, or Low issue in the correction diff. `git diff --check` passed. No game file was edited by this audit.

**Q1 resolved.** Help now states that the starter weapon is already equipped, directs the newcomer to make a useful tool or next weapon, and identifies the Weapon slot as the destination for a replacement (`mods/PLAYER/grug_inventory/pages.lua:208-214`). This matches the automatic class-specific starter grant and removes the redundant first-session objective.

**Q2 resolved.** The Skills catalogue now assigns abilities to indices 1–8 and exact mount tier IDs to indices 9–12, displaying them as separately labelled `8x1` and `4x1` rows (`mods/PLAYER/grug_skills/page.lua:17-28,110-123`). Sparse mount slots are handled with `pairs` in prior-entry detection, unlock announcement, and catalogue writes. Rebuild still clears all 16 slots before repopulating, so losing a mount tier or entitlement cannot leave a stale icon (`page.lua:36-57`). `allow_take`, `on_take`, and `allow_put` are unchanged and continue to resolve the source index through `slots[name][index]`, reconstruct the current stack, check duplicates/capacity/entitlement, and preserve the existing transaction guard (`page.lua:60-90`). The asserted maximum is eight abilities, matching the approved maximum class-kit row; mounts retain their stable tier-index mapping.

Focused verification passed on the reviewed working-tree bytes:

```text
chrt --idle 0 ionice -c3 luajit tools/r12_skills/behavior.lua .
r12 Skills real callbacks PASS: normalization, equipment notifications, retained tiers, owner/delete/recovery, bag absence, cooldown, late guards, unlock notice
```

Q3, Q4, P1, and P2 remain report-only recommendations for later user selection. Recipes and X3 still require the previously stated final integration recheck; this Q1/Q2 review does not certify those pending packages or make an observed-GUI claim.

## Final combined UI/Skills/Recipes source recheck — Recipes resolved

Rechecked integrated primary head `c46d94eb9348dfb05977e05a5f457dfbbd4e2168` plus the uncommitted documentation addition in `AGENTS.md` and the additional Cooking-authority assertion in `tools/r12_integration/probe_round12/init.lua`. This was a bounded read-only source and formspec-geometry pass. I did not rerun the broad integration probe, a PUC runtime, Luanti GUI, or a user world. No new defect was found.

### Combined formspec geometry

- The game-owned shared form remains `10.4x11.1`, with the hotbar at `y=7.2` and the remaining `main` inventory at `y=8.35` (`mods/PLAYER/grug_inventory/ui.lua:1-37`). The jobs Crafting page ends at approximately `y=4.16`: its recipe-book buttons occupy `x=0.10..0.92`, the 3x3 craft grid occupies `x=1.75..4.75` and `y=0.5..3.5`, and preview/arrow remain around `x=4.75..6.75`. Nothing approaches or masks the player's visible main inventory (`mods/PLAYER/grug_jobs/ui.lua:546-594`).
- Skills ends its instruction textarea at `y=6.85`, below the shared `content_bottom=7.0` and above the main inventory at `y=7.2`. Its `9.9`-wide passive/instruction textareas remain inside the `10.4` form, and its separately labelled ability and mount rows retain the reviewed index mapping (`mods/PLAYER/grug_skills/page.lua:110-129`).
- The recipe book is intentionally a standalone `10x9.8` form rather than an embedded shared-inventory page. Its two result rows end at `y=3.70`; undiscovered counts and the explicit “Acquire the main material to reveal more recipes.” guide occupy `y=4.02` and `4.35`; the separator is at `4.65`; recipe cells remain below it; and the Close button ends at `y=9.57`, inside the form (`mods/PLAYER/grug_jobs/ui.lua:460-509`). Current station hints are short and no current generated label crosses another interactive element. This is source geometry, not an observed default-scale GUI render.
- Furnace input stays in the ingredient relationship. For every non-grid recipe, the station icon is drawn at `x=4.18,y=7.38`, directly below the horizontal arrow at `x=4.15,y=6.55`, outside ingredient cells and output (`mods/PLAYER/grug_jobs/ui.lua:355-458`). Furnace, dual-furnace, brewing and 3x3 grid/custom-station cell arrangements remain distinct. Group tooltips show at most four alternatives plus a continuation count and use the shared wrapper.

### Discovery and Cooking ownership

The final book shows undiscovered counts for T1–T6 and the main-material instruction without implying a permission unlock. Exact runtime routes are bound to the independent declaration catalogue before Basics display; general routes carry starter or main-material presentation, while professional routes are removed before discovery filtering (`mods/PLAYER/grug_jobs/basics_presentation.lua`; `basics_routes.lua`; `ui.lua:460-507`). The committed focused evidence records 830 exact routes, 596 Basics routes, 234 profession routes, 63 starters, five alloy routes, four Bronze armor starters, persistent discovery, and the corrected station formspec.

The additional integration-probe loop is correctly scoped: it iterates every `grug_cooking.REFINEMENTS` route and resolves the actual `(station, output, input)` through `grug_jobs.recipe_for_craft`, requiring Cooking ownership and tier 1. This adds a direct full-game assertion for Bread/Cooked Meat/Cooked Fish provenance without changing runtime behavior (`tools/r12_integration/probe_round12/init.lua:40-44`). I inspected the assertion but did not rerun the integration probe under this report-only budget.

The new `AGENTS.md` paragraph accurately records the implemented exact-catalog audit, visibility-only discovery, actual Cooking book/furnace authority, verified existing-engine provenance, and station-icon placement. It does not introduce a new rule inconsistent with current source. `git diff --check` is clean for the uncommitted documentation and probe delta.

Q1 and Q2 remain resolved. Q3, Q4, P1, and P2 remain the only report-only recommendations for later user selection. X3's new talent abilities still await final integration and are outside this certification; the existing Talents layout is unchanged. Root should perform the X3/final checks independently after integration.
