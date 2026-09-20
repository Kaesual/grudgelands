# Independent Round 12 plan review

**Verdict: GO-ready after corrections.** I found no remaining blocker in the frozen Round 12 plan. This was a read-only plan and engine-contract review; I did not implement gameplay or run runtime tests.

## Scope reviewed

- `docs/research/round12-plan/README.md`
- `docs/research/round12-plan/farming.md`
- `docs/research/round12-plan/interface-art-talents.md`
- `docs/research/round12-plan/skills-pose.md`
- `TODO-round12-planning.md`
- the living `docs/design/items_crafting.md` food-duration change
- relevant current mod dependency/inventory code and pinned Luanti inventory dispatch (`src/inventorymanager.cpp`, `src/script/cpp_api/s_player.cpp`, `src/script/cpp_api/s_inventory.cpp`, `src/script/cpp_api/s_nodemeta.cpp`)

## Findings resolved in the frozen plan

### 1. High — source-side bound-item refusal blocked both required deletion paths

The original Skills contract proposed refusing player-to-external `take` while also requiring Q/drop deletion and drag-back deletion into the Skills detached catalog. Luanti sends only the source `{listname,index,stack}` to the player `take` callback. Both an ordinary cross-inventory move and `IDropAction` invoke that same callback; it has no destination identity. A zero return therefore blocked Q/drop before the item's `on_drop` and also blocked player-to-Skills return.

The corrected plan now allows the source take and enforces the policy at every destination: authenticated player `put`, composed node-metadata `allow_put`, and the finite set of shipped detached-inventory constructors. It preserves Q/drop, allows only the authenticated Skills catalog to consume a returned representation, handles both directions of occupied-slot swaps, preserves existing callback counts/`-1`, and requires a coverage census plus adversarial tests. This matches the pinned engine dispatch and is suitable for a standalone game with a controlled inventory surface.

### 2. Medium — mount normalization used bag APIs without a declared dependency

Exact-tier mount normalization must scan the four `grug_inventory` bag-content lists. `grug_mounts/mod.conf` did not declare that dependency and was absent from the planned ownership list. The corrected plan explicitly adds `grug_inventory` to the mount dependency and includes `mod.conf` in the package files. The current dependency graph has no reverse `grug_inventory -> grug_mounts` edge, so this does not introduce a cycle.

### 3. Medium — the binding passive-list requirement lacked an API and UI contract

The coordinator contract required passive abilities to appear as passive information, while the original annex enumerated only registered draggable ability stacks and excluded passive/replacement talents. The corrected annex adds a scrollable, read-only section sourced from the authoritative ranked-talent registry, with no dummy ItemStack or activation path, and adds respec acceptance coverage.

### 4. Medium — atomic tall-crop digging needed a pre-dig transaction

The farming annex required complete protection/occupancy validation before any segment changes, but did not initially require a pre-dig hook. `after_dig_node` cannot satisfy that rule because the clicked helper has already been removed. The corrected plan requires custom `on_dig` or an engine-verified equivalent, no independent helper drop, and a protected-root/unprotected-upper regression case.

## Remaining assessment

- The 17-family matrix implements the approved annual, regrowing and retained-base categories without changing wild renewal, source density, ingredient identity or yield. Its source/licence gate correctly requires a permanent pinned Hades reference only if bytes are selected for shipping.
- The five-minute food change is concrete (`grug_food.DURATION = 300`) and preserves tick cadence and all other effects.
- The Skills contract preserves a one-time base kit at initial character creation and forbids later automatic grants, including mount purchases. Bought mount tiers remain distinct and retain 6.4/8/8/12 nodes/s.
- Shared-file ownership is coherent: UI serializes `pages.lua` and Creative edits; SKILLS owns ability/mount representation policy; TALENTS consumes frozen eligibility seams; FARM owns crop lifecycle and art; POSE follows ART grip conventions; UX stays report-only.
- Test planning follows the session override: parser/static gates remain, behavioral work uses bounded LuaJIT fixtures, and no PUC runtime or broad suite is scheduled. The bounded X3 headless check is scoped to its actual settlement behavior.
- Recipe discovery builds on the existing throttled reconciliation path and adds event coverage for player-owned lists; it does not turn visibility into craft authority.
- The generic 90-degree pose has explicit precedence and preserves existing authored weapon/bow transforms.

## Implementation watchpoints (covered by acceptance, not blockers)

- Freeze and audit the inventory-surface census. Any new detached constructor or late node callback must fail coverage rather than silently bypass the destination guard.
- Exercise ordinary items through every composed destination callback so the global bound-item policy does not change existing counts, protection decisions, or `-1` semantics.
- Keep source hashes and independent reviews per package after integration; a post-review Lua-byte change requires refreshed evidence.

**Final recommendation:** request the user's Round 12 Go. The plan is concrete enough for autonomous execution and has no unresolved design or engine-contract blocker.
