# Independent review: Round 12 Recipes

Reviewed candidate `9ca2abaff91b8b0035697a8f04f1c478cd0d13f4`
against `900102d7` and the R12-R contract. No candidate or user-world files were
modified.

## Findings

### High — Opening Basics crashes on every current dual-furnace alloy route

`mods/PLAYER/grug_jobs/basics_presentation.lua:48-75` derives a declaration
from recipe inputs. A route with two non-auxiliary inputs and neither token in
its small priority list returns `no explicit main material for mixed route`;
`bind` asserts that result at `:84-96`. All five shipped alloy recipes have this
shape (`mods/ITEMS/grug_smelting/recipes.lua:56-70`), and
`engine_general_recipes` appends those records before calling `bind`
(`mods/PLAYER/grug_jobs/ui.lua:164-195`). Thus the first Basics open reaches an
assertion instead of a recipe book.

Focused reproduction on the frozen source, using the real presentation module
and the current Bronze route fields, returned:

```text
false  .../basics_presentation.lua:90: no explicit main material for mixed route: dual_furnace
```

The fix is the contract's actual explicit, content-owned route declaration
registry. Declare Bronze against Copper Bar and each later alloy against its
tier-defining metal input; enumerate the complete real catalog at startup and
fail there for uncovered/stale/duplicate route identities, before a player
opens the page.

### High — Cooking Bread, cooked meat and cooked fish leak into Basics

General-engine catalog filtering excludes a recipe only when
`grug_jobs.recipe_for_craft` finds a registered profession route
(`mods/PLAYER/grug_jobs/ui.lua:144-160`). Cooking registers its dishes and raw
assemblies with `grug_jobs`, but Bread is registered only as an engine cooking
recipe (`mods/ITEMS/grug_cooking/init.lua:253-261`). Cooked meat, cooked fish and
Bread are merely listed in `grug_cooking.REFINEMENTS` at `:263-270`; that table
is never consumed by another registration site. Consequently those professional
refinements have no ownership record for the exclusion test and are classified
as `profession = "general"` before discovery filtering. A player who has seen
Wild Grain/raw meat/raw fish will see the Cooking route in Basics, directly
violating the required pre-visibility ownership boundary.

Register these furnace routes as Cooking-owned records, or add a complete
route-identity ownership registry consumed before Basics presentation. The
catalog fixture must prove Bread and every other professional route are absent
from the unfiltered Basics record set.

### High — T1 Bronze metal armor is absent from the explicit starter set

The starter table lists Bronze tools and feedstocks but no metal armor outputs
(`mods/PLAYER/grug_jobs/basics_presentation.lua:9-22`). `material_for_gear`
recognizes cloth/leather armor, then tries to parse every remaining output as
`family_material` (`:26-46`). An output such as
`grug_gear:head_metal_bronze` becomes material `metal_bronze`, which is not in
`MATERIALS`, so it falls into input inference. Its Bronze Bar is returned as a
non-starter main material because the armor definition uses `_grug_ilvl`, not
the `_grug_tier` starter shortcut at `:52-65`. The same applies to chest, legs
and feet. A fresh character therefore cannot inspect the complete T1 Bronze
metal set required by the frozen starter contract.

Declare every T1 metal armor route as `starter = true` by exact route identity;
do not extend another naming or tier inference shortcut.

### Medium — The required complete runtime-catalog coverage test is missing

`tools/r12_recipes/presentation_kat.lua` constructs four representative fake
records and proves only those (`:1-25`). It never loads the current engine
recipe corpus, `grug_smelting.RECIPES`, professional ownership, mirrored
routes, or the complete starter outputs. The implementation's `declarations`
table also starts empty and is populated from the same records it claims to
audit (`basics_presentation.lua:3,84-96`), so its duplicate/stale loop cannot
prove an independently declared catalog. This is why all three release defects
above pass the supplied evidence.

Add the mandated bounded real-catalog enumeration fixture comparing every
current general route identity against an independently authored declaration
set, with explicit negative provenance cases for all professional routes. Until
that exists and passes, complete route coverage remains unproven even after the
specific defects are repaired.

## Verified clean areas

- Discovery persists sorted concrete item names, handles comma-separated group
  tokens as an intersection, scans every player inventory list except
  `craftpreview`, and does not apply level or crafting-authority gates.
- Inventory-event scans and the throttled two-second reconciliation refresh an
  open book only when a new concrete item is first observed; unchanged scans do
  not churn formspecs.
- Route keys include station, output, method, width, shapelessness and ordered
  displayed input signature, so mirrored/alternate shapes can remain distinct.
- The furnace input is rendered in the recipe relationship and the station
  icon appears below the arrow; furnace, dual-furnace and custom-station cell
  layouts remain distinct.
- Group tooltips are bounded to four alternatives, add a continuation count and
  pass through the shared wrapping helper when available.

No PUC runtime or broad suite ran. One focused LuaJIT reproduction was used to
confirm the real Bronze dual-furnace assertion.

## Correction re-review — `b8a329939dcd1832353eecab85003dbbe22219e8`

Reviewed the correction atop `9ca2abaff91b8b0035697a8f04f1c478cd0d13f4`. The exact declaration catalog, starter coverage, alloy declarations and pre-visibility exclusion are now sound, but the candidate is **not clean** because the newly declared Cooking ownership is not enforced by the actual furnace authority.

### High — The three Cooking-owned refinements remain universally craftable

The new policy explicitly says it controls only book presentation (`mods/PLAYER/grug_jobs/basics_presentation.lua:1-3`). Its `bind` method overwrites the UI record's `profession` and appends that record to a presentation-only list (`:32-50`), which `ui.lua:213-225` adds to the Cooking book. It never registers a `grug_jobs` recipe.

Bread is still registered only with `core.register_craft`, and Cooked Meat / Cooked Fish still exist only in the unused `grug_cooking.REFINEMENTS` data (`mods/ITEMS/grug_cooking/init.lua:253-270`). Furnace extraction asks `grug_jobs.recipe_for_craft`; a nil result delegates unrestricted extraction and records no Cooking craft (`mods/PLAYER/grug_jobs/stations.lua:232-270`). Therefore a player without Cooking can still take all three outputs despite the living spec now calling them Cooking-owned.

The candidate's own native evidence proves the mismatch. `tools/r12_recipes/evidence/engine-catalog.log` records each route as `general` because the probe derives ownership from the real `recipe_for_craft` boundary (`tools/r12_recipes/catalog_probe/init.lua:31-48`). The later assertions test only the rewritten book records (`:72-99`) and hard-code `profession=234`; they do not test `can_craft_recipe` or output extraction.

Reproduction: in a real catalog boot, call `grug_jobs.recipe_for_craft("furnace", "grug_cooking:bread", {"grug_cooking:wild_grain"})` (and the analogous meat/fish routes). It returns nil, so the furnace `allow_metadata_inventory_take` path allows the output for an unlearned player. Register all three exact furnace routes as Cooking recipes through the existing registry, then exercise an unlearned and learned player through the real extraction callback. Keep the presentation declarations as the independent coverage oracle.

### Low — Obsolete tier-one discovery compatibility hook remains live

`grug_jobs.discover_tier_one_inputs` is now a no-op returning false (`mods/PLAYER/grug_jobs/discovery.lua:50`), while `grug_jobs.learn` retains a conditional call to it (`mods/PLAYER/grug_jobs/state.lua:80-82`). There are no other callers or implementations. Under the fresh-server rule this is dead compatibility structure; remove both the stub and call rather than carrying a legacy hook into the new discovery model.

### Verified corrections

- The frozen catalog has 830 unique supported runtime identities. The native log contains 831 supported-looking rows only because the engine's registered empty item produces the extra identity `grid / empty output / normal / width 0 / shapeless`; production explicitly excludes empty output names before binding. Missing, stale and duplicate declared identities fail at startup.
- All five dual-furnace alloy routes have explicit main-material declarations and no longer crash the first Basics open.
- The general catalog has 63 explicit starter routes, including all four T1 Bronze metal armor routes.
- Bread, Cooked Meat and Cooked Fish are excluded from Basics before discovery filtering and shown in the Cooking book. The remaining defect is craft authorization, not presentation.
- Discovery still scans main, bags and other inventory lists except `craftpreview`, persists concrete names, and refreshes only after a newly observed item.
- The seven committed source hashes match the reviewed files; `git diff --check` reports only the intentional blank final line in the probe `mod.conf` and no whitespace error.

No PUC runtime or broad suite ran. I did not duplicate the unchanged bounded native probe because its committed output directly exposes the authority mismatch above.

## Final correction re-review — `f86bc36a396513b58e155b0889d0cacb8ddd1884`

**Verdict: CLEAN.** Both remaining findings are closed, and no new issue was found in the correction from `b8a329939dcd1832353eecab85003dbbe22219e8`.

- Cooking now registers all three refinements with the normal Jobs registry as exact T1 furnace routes (`mods/ITEMS/grug_cooking/init.lua:263-280`). They consequently participate in the same `recipe_for_craft`, `can_craft_recipe` and `record_craft` paths as other professional furnace recipes.
- The new `existing_engine_recipe` adapter is bounded to grid/furnace, proves exactly one matching existing engine route and exactly one total route for that output before accepting ownership (`mods/PLAYER/grug_jobs/registry.lua:629-648`). It records the normal profession recipe but deliberately skips `install_recipe`, preventing a duplicate `core.register_craft` (`:675-713`). Final collision validation rechecks the engine corpus and exact matching provenance after all mods load (`:765-825`). The three Cooking outputs satisfy this strict scope in the native boot.
- The actual furnace callbacks now resolve these outputs: an unlearned player is denied before extraction, while a learned cook is allowed and receives one progression credit per taken output. The real-code callback fixture covers all three and deliberately makes `core.register_craft` fatal, proving the adapter did not reinstall them (`tools/r12_recipes/furnace_authority_kat.lua:39-43,66-100`). Reviewer rerun passed:

  ```text
  chrt --idle 0 ionice -c3 luajit tools/r12_recipes/furnace_authority_kat.lua .
  R12 RECIPES furnace authority PASS unlearned=denied learned=3 progression=3
  ```

- The updated native catalog independently derives owner names from `recipe_for_craft` (`tools/r12_recipes/catalog_probe/init.lua:35-49`). Its committed log labels Bread, Cooked Meat and Cooked Fish `owner=cooking`, and its explicit authority assertions pass for all three (`:100-112`). The same boot retains `catalog=830`, `basics=596`, 63 starters, five alloys and four Bronze armor starters.
- The presentation-only profession-record bridge was removed. Cooking-book rows now come from the real registry, so presentation and craft authority share one record rather than diverging.
- `discover_tier_one_inputs` and its sole conditional caller are both gone (`mods/PLAYER/grug_jobs/discovery.lua:43-50`; `mods/PLAYER/grug_jobs/state.lua:72-83`). Repository search finds no remaining reference.
- All twelve committed source-input hashes match the reviewed files. The checked-in static summary reports the Lua 5.1 parser and five sweeps passing; its single SETGLOBAL occurrence is the expected mod-global declaration for `grug_cooking`. `git diff --check` has no error.

No PUC runtime or broad suite ran.
