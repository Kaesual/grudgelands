# WP47 bound-item transfer resolution

## Finding

A source-side player `take` denial cannot implement the WP47 transfer rule.
Luanti presents both a player-to-foreign-inventory move and a Q/drop action to
the same player inventory `allow_take` callback. The Lua callback receives only
`action == "take"`, its source list/index/stack, and no destination identity.
Rejecting it blocks both external storage and the required delete-on-drop.

The engine paths prove the distinction exists at the destination instead:

- Cross-inventory `IMoveAction` calls the destination's `allowPut` and the
  source's `allowTake` independently
  (`reference_projects/luanti/src/inventorymanager.cpp:187-215, 383-431`).
- Destination dispatch is exact: player, node metadata, or detached inventory
  (`inventorymanager.cpp:187-199`).
- `IDropAction` calls only the source inventory's `allowTake`, then invokes the
  item's `on_drop`; it has no destination inventory and no `allowPut`
  (`inventorymanager.cpp:669-767`). An empty stack returned by `on_drop` is
  counted as actually dropped and removed from the source without creating a
  world item (`:744-775`).
- Server packet handling applies range/access checks to node and detached
  inventories before an `IMoveAction`, but a player may always address only
  their own player inventory (`reference_projects/luanti/src/network/serverpackethandler.cpp:570-735`).
- Swaps do not bypass the model: the engine runs the allow callbacks again with
  directions swapped and rejects the whole swap if either side refuses
  (`inventorymanager.cpp:397-430`).

Therefore WP47 should allow source `take`, use destination guards for every
foreign inventory, and keep same-player list restrictions in the player
callback where list names are visible.

## Complete shipped destination inventory census

The current game exposes these inventory families:

1. **The player's own inventory**: `main`, `craft`, `craftpreview`,
   `craftresult`, eight equipment/quiver/bag-container lists, and four
   `grug_bagN_content` lists. The server itself rejects moves into
   `craftpreview`/`craftresult` (`serverpackethandler.cpp:674-701`). Existing
   callbacks in `grug_inventory/equipment.lua` and `bags.lua` gate equipment,
   quiver, bag containers, and bag contents.
2. **Node metadata inventories**:
   - default chests (`mods/BASE/default/chests.lua`);
   - default furnaces (`mods/BASE/default/furnace.lua`);
   - vessels shelf (`mods/BASE/vessels/init.lua`);
   - bookshelf (`mods/BASE/default/nodes.lua:2491-2559`);
   - profession stations (`mods/PLAYER/grug_jobs/station_nodes.lua`);
   - smelting station (`mods/ITEMS/grug_smelting/node.lua`);
   - brewing stand (`mods/ITEMS/grug_brewing/node.lua`).
   The repository-wide `list[context|nodemeta]` and `set_size` census found no
   other shipped node inventory UI.
3. **Detached inventories**:
   - per-player `creative_<player>` infinite source;
   - global creative `trash` sink
     (`mods/BASE/creative/inventory.lua:33-53, 133-143`);
   - the proposed private WP47 Skills catalogue.
   A repository-wide `create_detached_inventory` census found no other shipped
   detached inventory.
4. **Vendor/trainer UI** uses formspec buttons and direct server transactions,
   not a detached or node inventory. Player crafting uses the player's own
   lists. Bags are also player lists, not external inventories.

The engine-maintained `core.detached_inventories` table records each detached
inventory and its live callbacks; callback lookup reads this table by name at
action time (`reference_projects/luanti/builtin/game/detached_inventory.lua:1-27`,
`reference_projects/luanti/src/script/cpp_api/s_inventory.cpp:170-190`).

## Proposed finite guard design

### Shared identity

Give every ability and mount representation a shared item group, for example
`grug_bound_skill = 1`. A helper owned by the new `grug_skills` mod performs the
single group lookup. Do not dispatch by an item-name list.

### Player inventory callback

Replace the current ability main-only rule and mount blanket outbound-take rule
with one callback:

- `move`: if the moved stack is bound, allow only when both `from_list` and
  `to_list` are `main` or `grug_bag1_content` through
  `grug_bag4_content`; otherwise return `0`.
- `put`: if a bound stack is entering the player's inventory, allow only
  `main` or an owned, currently sized bag-content list. This covers Skills
  recovery and prevents a foreign/server-visible inventory move from targeting
  craft/equipment/quiver/bag-container lists.
- `take`: return `nil` for bound stacks. This deliberately permits Q/drop and
  lets the destination's guard decide every cross-inventory move.
- unrelated stacks return `nil`, preserving OR-combined callback behavior.

Player-to-player inventory moves cannot be addressed: the server access check
accepts a player inventory location only when its name equals the acting player
(`serverpackethandler.cpp:620-628`).

### Every node metadata destination

At `register_on_mods_loaded`, iterate `core.registered_nodes` and compose each
definition's `allow_metadata_inventory_put` through `core.override_item`:

```lua
local previous = def.allow_metadata_inventory_put
allow_metadata_inventory_put = function(pos, list, index, stack, player)
    if is_bound_skill(stack) then return 0 end
    if previous then return previous(pos, list, index, stack, player) end
    return stack:get_count()
end
```

This is stronger and less fragile than naming the seven current node families:
all registrations are complete at `mods_loaded`, nodes dynamically resolve the
current registered definition, and future shipped storage nodes become safe by
default. It preserves each old callback exactly for unrelated items and
reproduces the engine's permissive default when none existed.

Also compose `allow_metadata_inventory_move` to refuse a move when the source
stack already inside node metadata is bound. The ordinary UI cannot create that
state after the put guard, but this closes forged/server-inserted strays and
swap paths. Preserve the previous callback for all other stacks. Do not modify
`allow_metadata_inventory_take`: a stranded bound item must be recoverable back
to the owner, and destination player-list gates then control where it lands.

Store wrapper markers on the node definition (for example
`_grug_bound_skill_guard = true`) and audit at startup that every registered
node is wrapped once. This avoids double wrapping if another late audit calls
the installer and produces a concrete count in the startup log.

### Every shipped detached destination

Detached callbacks are looked up dynamically from `core.detached_inventories`,
so wrapping those callback tables is sufficient; the raw C++ inventory need not
be recreated.

- At `mods_loaded`, wrap all existing detached inventories (currently global
  creative `trash`) so `allow_put` returns `0` for a bound item and delegates
  exactly for unrelated items.
- On each player join, after the dependency-ordered creative join callback has
  created `creative_<name>`, wrap every then-existing non-Skills detached
  inventory not already marked. `creative_<name>` already rejects all puts,
  but the wrapper makes the WP47 invariant explicit and audited.
- Create the player's Skills detached inventory afterward and mark it as the
  sole exception. Its authenticated `allow_put = -1` is the intended delete
  transaction: the destination remains unchanged while the engine consumes the
  player source (`inventorymanager.cpp:486-493`). Its `allow_take = -1` remains
  the infinite-source recovery path (`:463-484`).
- On page open/join, run the small detached audit again before displaying the
  page. This covers any shipped detached inventory created after `mods_loaded`
  without globally monkeypatching `core.create_detached_inventory`. The current
  census has only creative and Skills, so this is event-driven and tiny.

Do not wrap or replace the public `core.create_detached_inventory` function.
The finite registry audit keeps provenance (`mod_origin`) intact and avoids a
global API interposition whose ordering would be difficult for later mods to
reason about.

### Drop and catalogue deletion

Ability and mount `on_drop` return `ItemStack("")` and perform no other action.
Because the player source callback permits `take`, `IDropAction` reaches this
callback and removes the source representation without spawning
`__builtin:item`. The active mount controller is untouched.

Dragging a representation onto the matching Skills catalogue uses the Skills
detached `allow_put = -1`. Authenticate the player, source item identity,
ability/mount entitlement, and owner metadata before returning `-1`; reject all
other puts. Since destination-infinite semantics restore the catalogue cell and
consume the source, no `on_put` inventory mutation is needed beyond refreshing
an inline status message.

## Mount dependency correction

Add `grug_inventory` to `mods/PLAYER/grug_mounts/mod.conf` dependencies. The
new exact-tier mount normalizer must recognize the four owned bag-content lists
through the public `grug_inventory.BAG_COUNT` / `content_list` API rather than
string-pattern guessing. This edge is acyclic:

```text
grug_inventory -> grug_core, grug_factions, grug_classes, grug_gear,
                  grug_xp, sfinv, player_api
grug_mounts    -> grug_inventory (new), plus its existing dependencies
grug_skills    -> grug_abilities + grug_mounts + grug_inventory
```

`grug_inventory` has no dependency on mounts or skills; its optional visuals
edge also does not lead back to mounts.

## Acceptance and focused engine tests

The WP47 transaction KAT must exercise the real callback composition and these
cases:

1. `IDropAction`-equivalent player `take` is permitted and empty `on_drop`
   deletes the representation without a world item.
2. Player main/bag-to-chest, furnace, profession station, brewing, smelting,
   vessel shelf, and bookshelf puts return zero for both ability and mount
   groups; ordinary ingredients/items retain the exact old callback result.
3. A registered node with no prior allow callback receives the bound guard and
   remains permissive for ordinary items.
4. Player main/bag-to-creative and trash is denied; ordinary creative trash
   behavior remains unchanged.
5. Player-to-Skills put deletes only an authenticated, currently entitled item;
   forged owner, locked ability, unowned tier, unrelated item, and another
   player's callback all fail.
6. Skills-to-main infinite take still works once, while the live duplicate scan
   blocks a second take if the first copy is in main, craft, or any owned bag.
7. Same-player main↔owned-bag moves succeed. Moves to craft, equipment, quiver,
   bag-container, zero-sized/non-owned bag content, and arbitrary custom player
   lists fail.
8. Swap and shift-click paths cannot bypass either destination family. A bound
   item forged into node/detached storage can leave for valid player storage but
   cannot move deeper within external storage.
9. Startup/page-open audits report all registered nodes and all shipped detached
   inventories guarded, with exactly the authenticated per-player Skills
   inventories exempted.

Use a focused LuaJIT harness plus source-level assertions over the engine paths;
run `luac51 -p`, changed-file `SETGLOBAL`, and the five static sweeps. This
session runs no PUC runtime and no broad suite.

## Resolution

Destination guarding satisfies all three requirements simultaneously:

- Q/drop reaches `on_drop` and deletes the representation;
- returning an item to Skills reaches the authenticated infinite-destination
  delete path;
- every shipped external inventory refuses bound items at its own destination.

No user-facing compromise or additional ruling is required. The implementation
must treat an unguarded newly introduced node/detached inventory as a startup
audit failure, not silently weaken the bound-item contract.
