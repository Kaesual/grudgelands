# Station viewer rules — design audit

Date: 2026-09-21. User explicitly requested a native GPT-6 Astra read-only
assessment before implementation. Coordinator recorded the agent's findings;
no game code or tests were changed. Decision state:
[station TODO](../../TODO-station-ownership.md).

## Conclusion

Shared inputs with viewer-specific qualified output previews are feasible.
The unresolved design cases are automatic Alchemy and which step of two-stage
Cooking grants the single profession credit. Inserting-player ownership is not
required by the collector-credit model.

## Evidence and boundaries

- `mods/ITEMS/grug_brewing/node.lua:171` runs automatic brewing; `:281` gates
  collection. Free automatic production and extraction would allow any player
  with ingredients to produce potions, changing `docs/design/professions.md:107`.
  Preserve exclusivity through a qualified preparation or explicitly authorized
  batch start, or deliberately decide that production becomes universal.
- `mods/ITEMS/grug_cooking/init.lua:198,233-238` registers direct dishes and both
  raw assembly/final furnace routes. `mods/PLAYER/grug_jobs/stations.lua:119,263`
  awards grid and furnace progress. Choose preparation-only or final-only credit
  for two-stage recipes. Direct grid dishes continue to credit once at crafting.
- `mods/ITEMS/grug_cooking/init.lua:254` has three simple meat/fish/grain furnace
  routes with no qualified raw-preparation stage. Free furnaces make these
  universally producible; do not silently retain a Cooking extraction gate.
- `mods/PLAYER/grug_jobs/state.lua:122` already limits progress to learned
  professions and the exact effective current tier. Separate that optional
  progress check from permission to collect an automatic result.
- `mods/PLAYER/grug_jobs/station_nodes.lua:105` currently stores one shared
  output preview. Separate player previews are needed. Owner-limited detached
  inventories have server-enforced owner checks in pinned Luanti
  `src/server/serverinventorymgr.cpp:155`, but are not persistent storage.
- Refinement/affix Apply at `station_nodes.lua:213` and
  `mods/ITEMS/grug_quality/init.lua:591` preserves concrete item metadata and
  rolls only at commit. Eligibility-specific previews fit this model; taking
  a preview directly must not bypass the operation or enable preview rerolls.
- Pinned Luanti `src/network/serverpackethandler.cpp:642` checks distance for
  node inventories, but not detached inventories. A preview adapter must check
  live player, distance, area access and station identity explicitly.
- `src/inventorymanager.cpp:383,569` defines the inventory transaction and
  notification paths. Same-inventory moves use move callbacks, not take
  callbacks. Every output exit must settle progress at most once, including
  partial stacks; reinserting an already credited result must never recredit it.
- Personal station inventories need separate persistent inputs, outputs, fuel,
  time and recipe state per player and physical station. Node activation
  (`src/serverenvironment.cpp:554`) may account for elapsed server game time;
  real server downtime is not automatically included.

At every commit, revalidate current ingredients, eligibility, station access and
destination capacity. Refresh other viewers after shared-input changes. A stale
preview is never authorization or an independently owned result. If final-only
credit is chosen, an unqualified collector permanently consumes the pending
credit without receiving profession progress.

No implementation approval is inferred from this feasibility assessment.
