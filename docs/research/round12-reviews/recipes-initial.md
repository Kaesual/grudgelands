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
