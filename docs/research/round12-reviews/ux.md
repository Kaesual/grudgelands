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
