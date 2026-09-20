# R11 REPAIR independent review — findings

Candidate: `2ad85b152d315add945245a088a28855c94ba2a0`  
Review: fresh native GPT-5.6 Sol, read-only  
Result: **not clean**

## High

1. **`mods/ITEMS/grug_repair/runtime.lua:35-39` — floating-point remainder leaves both combat lifetimes one event too long.** The code repeatedly adds `65535 / lifetime`, stores the fractional remainder as decimal text, and floors each event. Under the required LuaJIT runtime, exactly 3000 Common events produce wear `65534` with remainder `0.99999999999658939`; 6000 refined events produce the same result. The item therefore remains usable until event 3001/6001, violating the exact 3000/6000 budgets. A targeted LuaJIT arithmetic reproduction was run; no PUC runtime or broad suite was run.

2. **`mods/ITEMS/grug_repair/runtime.lua:176-188` and `mods/ITEMS/grug_farming/init.lua:262-288` — a broken hoe can still till soil and may delete itself.** The generic override only short-circuits `after_use`, but the shipped hoe performs tilling and calls `itemstack:add_wear(...)` in `on_use`. A wear-65535 hoe therefore enters `hoe_on_use`, changes the node, and invokes native destructive wear despite the design requiring a broken hoe to perform no operation and keep its concrete stack. The approved FARM branch adds more hoes through this same callback shape, so merging it does not cure the boundary.

3. **`mods/ITEMS/grug_repair/runtime.lua:5-6,98-121` — captured projectile identity can collide after a server restart and wear a different owned item.** `_grug_repair_item_id` persists in stack metadata, while `item_serial` resets to zero at every mod load. After a prior `owner:1` item remains in main/bag storage, the first unmarked launch item after restart is also assigned `owner:1`; settlement scans weapon/offhand/main/bags and wears the first match, so moving the launched item can debit the older stack instead of the concrete launch-time weapon/spellbook. This breaks the frozen Fireball identity-swap requirement and the future multi-projectile API contract.

4. **`mods/ITEMS/grug_repair/runtime.lua:138-149` — healing and absorb settlement is emitted per target callback, not once per originating action.** Each effective heal/shield callback creates a fresh table as its action ID. A future aura action that heals or shields five targets consequently spends five durability events. This directly contradicts the action seam's own contract at `mods/CORE/grug_core/combat.lua:1229-1233`, which says per-target heal/absorb callbacks must not own settlement because they multiply AoE wear. The API is therefore not ready for the required future aura/multiple-result actions.

## Medium

5. **`docs/research/round11-repair-evidence.md:6-19,26-28` — the evidence claims runtime behavior that none of the cited KATs exercises.** `tools/r11_repair/service_kat.lua` loads only money, service, and providers; it never loads `runtime.lua`, the combat settlement hooks, the mobs wear patch, real equipment consumers, or capability restoration (its mock metadata does not even implement `set_tool_capabilities`). The armor and pre-existing projectile KATs contain no repair assertions. Thus preservation at 65535, exact budgets, broken-effect suppression/restoration, action deduplication, incoming/outgoing exclusions, and concrete Fireball identity are all asserted without executable coverage; the exact-budget defect above demonstrates that the missing coverage is material.

## Low

6. **`VENDOR.md:287` — the vendored patch ledger is stale.** The candidate adds a new `GRUG PATCH (Round 11 repair)` site to `mods/ENTITIES/mobs/api.lua`; the file now contains 66 markers, while the ledger still states 65 and does not describe the new non-destructive exhaustion patch.

No production files, commits, sync targets, pushes, or user-world state were changed.
