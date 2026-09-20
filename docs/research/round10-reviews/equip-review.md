# Independent EQUIP review

**Verdict: CLEAN**

- Candidate: `b8dc0db3bf541eed63593da93dcc89aac9ef1a55`
- Base: `39a50f3e`
- Corrected source/oracle commit: `77bf1eb1`
- Reviewer: native GPT-5.6 Sol; independent of implementation
- Findings: Critical 0, High 0, Medium 0, Low 0
- Review fix rounds: 0 (the author's earlier oracle correction predates this independent review)

## Scope reviewed

I reviewed the complete base-to-candidate diff and the accepted R10 authority, including profession IDs and slot rules, Basics versus profession ownership, recipe-book presentation, VoxeLibre-shaped base recipes, station transactions, refinement/affix and upgrade-kit semantics, mastery gates, vendor rotation, dependencies, tests, and final evidence. I also checked the pinned Luanti inventory move sequence for the station's ordinary-output callback.

The package consistently replaces the retired Blacksmith with Weaponsmith and Armorsmith, keeps Cooking secondary, and leaves the other five primaries intact. Universal base equipment is registered as engine crafting rather than profession content; profession routes refine the concrete base stack or append one legal affix. The base recipe oracle preserves row/column empties, mirrored axe/hoe alternatives, and output quantities rather than comparing flattened ingredient bags. No G2 surcharge or new capability ladder was introduced.

The ordinary station quality mutation in `allow_metadata_inventory_take` initially warranted scrutiny. It is valid for this transaction: pinned `IMoveAction::apply` explicitly reacquires the source list after callbacks and bounds/moves from the current source stack (`reference_projects/luanti/src/inventorymanager.cpp:232-244, 442-443, 479-481`); the subsequent `onTake` receives the moved stack (`:570-572`). The marker in `grug_quality` prevents a second roll on the same output stack. In-place operations separately validate access, the exact current recipe/family/materials, output room, and successful operation before consuming inputs and recording progress (`mods/PLAYER/grug_jobs/station_nodes.lua:196-234`).

The vendor has 13 fixed items and three of four conceptual rotating families, with caster represented by exactly one of wand/scepter/orb; the hourly seed remains deterministic per vendor and bracket, and the existing one-in-five Uncommon replacement is retained. No new persistent format or compatibility branch was added.

## Evidence checked

The checked-in final PUC 5.1 and LuaJIT outputs are each 194 lines and byte-identical with SHA-256 `50756e38b046e128518ef3fd9523efd575439b5feeaed893fbe451eecc79e2e1`. The documented runner SHA-256 is `f6f87e6e5e8b13f755e5aaf6aad8358f67a8c9e3456905c7116a537ad9697471`. I inspected the corrected recipe-shape checks and the real-code station/quality fixtures without rerunning either interpreter. Reference submodules are pinned without `+`, `-`, or `U` markers.

## Pending integration gates

- CAP must project the two separate smith trainers and shared public forge under its reconciled capital layout.
- ART must provide the four generic leather inventory paths activated by this candidate.
- Root must run the combined six-capital boot/static/final-pair gate after package integration.
- The user's fresh-world GUI playtest remains the runtime acceptance gate.
