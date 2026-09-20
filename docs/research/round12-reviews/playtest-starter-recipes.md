# Independent review: Round 12 starter catalog fix

Reviewed candidate: `2a8ed73c33ddadfb97abed2a3e122204269f4023`

Baseline: `0659b8507f004bfcee50cc7ad4a60d47d6859673`

Reviewer independence: read-only review; I did not author the candidate and made no repository edits.

## Result

Clean. No Critical, High, Medium, or Low findings.

## Assessment

The production change is confined to ten existing `owner="general"` presentation declarations in `mods/PLAYER/grug_jobs/basics_routes.lua`: the wooden and stone axe, pick, shovel, and sword routes (eight identities), plus both mirrored Bronze hoe routes (two identities), change from `main_material=...` discovery to `starter=true` visibility. This implements immediate first-open visibility under `docs/design/inventory_equipment.md:247-251` and the approved T1 starter scope.

No route identity field changes: station, output, method, width, shapeless flag, and ordered inputs are unchanged for all ten declarations. No recipe registration, craft authorization, output, tool capability, or durability code changes. The complete catalog remains exactly 830 identities split into 596 Basics and 234 profession-owned routes. Starter routes rise by exactly ten, from 63 to 73.

The assertions cover each newly visible output and its exact route multiplicity: one route for each of the eight wooden/stone outputs and two mirrored routes for `grug_farming:hoe_bronze`. Existing wooden hoe, Bronze axe/pick/shovel, and Bronze armor starter declarations remain unchanged. The code's `basics_presentation.bind` still rejects missing, stale, or duplicate identities, so changing visibility metadata does not weaken whole-catalog identity enforcement.

## Verification

- Inspected the complete four-file diff and exact candidate commit.
- `git diff --check 0659b850..2a8ed73c`: PASS.
- `luajit tools/r12_recipes/presentation_kat.lua .`: PASS — `routes=830 general=596 profession=234 starter=73 starter_tools=10` plus missing/stale/duplicate mutation gates.
- Plain Lua 5.1 parse of all three changed Lua files: PASS, using the primary worktree's built `tools/bin/luac51`.
- Five prohibited-syntax/API sweeps over all changed Lua files: no hits.
- `SETGLOBAL`: none in the production route table or presentation KAT; the catalog probe has only its intentional fixture `core` assignment.

## Limits

No native GUI/runtime test was run, and no PUC runtime or broad suite was run. The checked-in `tools/r12_recipes/evidence/engine-catalog.log` and `source-inputs.sha256` remain the earlier 63-starter snapshot; this is historical engine-registry evidence rather than current visibility evidence. Since the candidate does not change any engine recipe registration or identity field, I did not treat the unchanged engine log as a defect. The updated LuaJIT presentation KAT directly exercises the changed policy bytes and exact 73-starter result.
