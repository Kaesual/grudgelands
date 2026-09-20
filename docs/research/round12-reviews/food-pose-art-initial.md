# Independent review — Round 12 FOOD, POSE and ART

Review date: 2026-09-20

## Reviewed sources

- Baseline: `68ad8bb1`
- FOOD candidate: `d7fee71f`
- POSE candidate: `63ef0faf` (includes FOOD)
- ART candidate: `b44093bd9a3b994e3442abcc2d73bf2ef65804e1` in `/tmp/grug-r12-art`
- Contracts: `docs/research/round12-plan/README.md`, `skills-pose.md`, `interface-art-talents.md`, and the review checklist in `docs/process/wp-workflow.md`

I authored none of these candidates and made no candidate-file changes.

## Findings

### Medium — ART evidence omits two mandatory food results

`tools/r12_art/build_galleries.py:20-32,65-76` builds and displays the 18 authored dishes, six raw assemblies and Bread, but never includes the existing cooked meat and cooked fish required by the frozen R12-A asset checklist. Both the native and enlarged food galleries therefore cover 25 entries instead of the required 27, so the review artifact cannot establish catalog-context recognition or style compatibility for every cooked/refined result.

**Failure scenario:** cooked meat or cooked fish can remain visually weak or collide with a new dish in the Creative Food/catalog view while all supplied evidence still passes.

**Concrete fix:** add the registered cooked meat and cooked fish stacks, with their actual current texture resolution, to both native and enlarged labelled galleries; include their files or resolved source inputs in the evidence hash manifest. No replacement is required if the resulting visual audit accepts them.

### Medium — the Greataxe still reads as a one-sided axe at native scale

`tools/r12_art/build_assets.py:123-131` gives most of the head mass and highlight to the upper/right blade while the opposing lower/left blade is a much smaller five-pixel lobe. In `tools/r12_art/evidence/weapons-before-after-native.png` and `weapons-after-10x.png`, all six results read as a large single-bit axe with a rear spur rather than the frozen “large, symmetric or near-symmetric double-bit axe” silhouette.

**Failure scenario:** the inventory icon does not communicate the requested two-handed double-bit weapon and remains too close in concept to a one-handed axe family.

**Concrete fix:** enlarge the opposing blade to roughly match the primary blade's occupied mass around the centered eye, then regenerate all six tiers and both weapon galleries. Preserve the current diagonal grip and palette-only tier variation.

## Package verdicts

### FOOD — PASS

The only runtime value change is `grug_food.DURATION` from 180 to 300 seconds (`mods/ITEMS/grug_food/init.lua:6`) plus duration-derived tooltip wording (`:180-183`) and a corrected comment. Tier values, five-second interval, instant healing, percentage regeneration, combat suspension, modifier behavior and latest-food replacement remain unchanged. The focused real-code LuaJIT KAT passed 24 tier/role routes and exact 300-second expiry. Parser/static evidence is present and no PUC runtime was claimed.

### POSE — PASS

Explicit `_grug_wield_pose` metadata has first priority (`mods/PLAYER/grug_visuals/wield_geometry.lua:289-294`), followed by bow, axe and established tool-family dispatch (`:295-310`), with `forward` only as the unclassified fallback. The forward transform retains the centered hand position and changes only the orientation (`:357-364`). The focused fixture parses the real player B3D, proves the generic icon axis points forward, exercises explicit override and invalid-profile failure, and preserves the existing sword/tool/staff, axe and bow invariants. `apply.lua:442-446` audits explicit values at startup. Scope remains third-person/world attachments; first-person wieldmesh is untouched.

### ART — REVISE (2 Medium, 0 Critical/High/Low)

Jungle Cocoa clearly reads as a steaming brown mug and is distinct from Cocoa-Rubbed Game and Grand Feast. The six wands share stable geometry, include a clear grip/shaft/focus, and are distinct from the old loose crystal. Food art has readable transparency/outlines and a coherent bowl/pot/platter vocabulary; cooked outcomes differ from tied raw bundles. Accepted swords, one-handed axes, armor, crop ingredients and quiver are unchanged by the candidate diff.

The deterministic builder, CC0 project-art declarations, archived concept sheet, dimension/alpha checks and 37-entry SHA-256 manifest are internally consistent. Every manifested asset verified byte-for-byte; all 37 sprites are 16x16 RGBA with transparent and opaque pixels. Fix the two Medium findings and regenerate the affected manifests/galleries before merge.

## Checks performed

- Visually inspected the native and enlarged FOOD and weapon before/after galleries with the image viewer.
- Verified all 37 ART manifest hashes and checked 16x16 dimensions/alpha.
- Ran the focused FOOD LuaJIT KAT: PASS.
- Ran the focused POSE transform KAT against the real geometry/B3D path: PASS.
- Inspected frozen parser, SETGLOBAL, five-sweep and reference-pin evidence; no new executable-code issue found.
- Confirmed no unrelated accepted art family appears in the ART diff.
- No PUC runtime or broad suite was run, as required by the session override.
