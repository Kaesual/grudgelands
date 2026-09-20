# Independent review — Round 11 vegetation pursuit correction

Date: 2026-09-20
Baseline: `dcd2e462`
Branch: `wp11-vegetation-chase-fix`
Reviewer: native GPT-5.6 Sol (`vegetation_review`), read-only and independent of source authorship

## Verdict

**CLEAN — no Critical, High, Medium, or Low findings.**

The correction matches the reported failure and remains bounded. Pinned Luanti `src/environment.cpp:63-78` confirms that `core.line_of_sight` stops on every non-air node, so the former first-blocker predicate necessarily classified plantlike nodes as cliffs after `7a4a4c4e`. The new `has_safe_support` walks only the inclusive vertical voxel column covered by the original probe, uses the engine's signed half-away-from-zero node-coordinate rule, skips harmless non-walkable cover, and requires actual walkable support before the authored lower endpoint.

Safety behavior is preserved: `ignore`, explicitly unloaded reads, unknown node definitions, dangerous nodes, liquids, and columns without support all return unsafe. The ambient probe still uses depth 1.5, preserving flat ground and a one-node descent while refusing a two-node descent at positive, negative, zero-crossing, and near-half boundaries. Combat keeps each mob's authored `fear_height` (six for the boar); flight and fear-zero non-ambient exceptions remain intact.

The helper is shared by `is_at_cliff` and the existing `sidestep_safe` callback. It adds no A* request, scan outside the original vertical column, timer, or globalstep. The normal cliff calculation remains under mobs_redo's existing quarter-second node timer; the lateral check runs only during the already bounded failed-path sidestep. Direct raw-backed node reads are bounded by the authored descent depth.

## Reviewed evidence

- Frozen production SHA-256: `cb6503da6cf73f16c3d3be826c50fd36d97deabf3028e21263867d8a1849eda1` (`mods/ENTITIES/mobs/api.lua`).
- Frozen focused fixtures: `653ca1d05a0732b5f18f4c8639e73624b110723fe447a73b4f65e497a6e05625` (`cliff_kat.lua`) and `d80ed4620e6fc1435a23464917701ee97430272ef6e8a89cca150d5f33accb00` (`chase_kat.lua`).
- `tools/r11_vegetation/evidence/author-inputs.sha256` and `source-inputs.sha256` both verify against the reviewed checkout.
- Focused LuaJIT receipts pass: cliff/support boundaries and the extracted real dogfight chase branch report plant run, unsupported cliff stop, liquid stop, and unloaded/ignore stop.
- Static receipt: all 328 first-party plus changed vendor/tool Lua files pass `tools/bin/luac51 -p`; changed production bytecode has only the expected `mobs` global-table write; all five sweeps were inspected with no prohibited live construct; `git diff --check` passes; all 13 reference pins are unchanged.
- The revised VENDOR inventory correctly advances the actual `GRUG PATCH` marker count from 66 to 67 and documents the shared support predicate. The living design docs and playtest checklist match the code's scope.

No PUC runtime was run or duplicated, following the session's explicit minimal-LuaJIT instruction. The remaining uncertainty is the intended GUI/runtime acceptance: after synchronization and restart, ranged-hit a boar among plants as Scout and Priest and confirm it approaches; also verify idle roaming still refuses a drop deeper than one block.
