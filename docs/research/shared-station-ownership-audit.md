# Shared station inventory audit

## Current facts

All placed production stations use node metadata inventories. They are shared
by every player who can access that node; there is no owner, participant or
per-player work-order identity on an input, fuel or output stack.

- The normal Furnace has one shared `src`, one `fuel` and four `dst` slots
  (`mods/BASE/default/furnace.lua:391-397`). Ordinary furnaces use node
  protection for put/take; authored public hearths instead permit any living
  player within eight nodes (`default/furnace.lua:63-105`,
  `mods/PLAYER/grug_jobs/station_nodes.lua:39-50`). The timer consumes inputs
  and writes output without a player identity (`default/furnace.lua:137-190`).
- The Dual Furnace has two shared inputs, two outputs and one fuel slot
  (`mods/ITEMS/grug_smelting/node.lua:342-350`). Protection gates ordinary
  inventory actions, but there is no stack ownership (`node.lua:75-112`). Its
  timer consumes both material slots before adding the shared output
  (`node.lua:183-200`). Its current alloy recipes are Basics recipes, so the
  profession output gate does not distinguish players.
- The Brewing Stand has two shared reagent slots, one vial, one fuel and two
  outputs (`mods/ITEMS/grug_brewing/node.lua:155-169`). At a registered public
  station, `may_access` returns true without a player/owner check; at other
  locations it uses node protection (`node.lua:34-38`). Inputs are consumed by
  the timer before output extraction is authorized (`node.lua:171-205,
  266-303`).
- Forge, Tanning Rack, Tailor Bench, Carving Bench and Jeweller's Bench all use
  one shared nine-slot `craft` list and one shared `output` list
  (`mods/PLAYER/grug_jobs/station_nodes.lua:127-146`). Public socket positions
  are open to all; private placements use node protection. Normal inventory
  actions additionally require the player to be within eight nodes
  (`station_nodes.lua:53-64,148-204`). Their inputs are consumed only when an
  authorized player takes a normal output or successfully applies an
  operation, rather than while preparing the preview.
- The player's ordinary 3x3 crafting grid is a player inventory list and is
  personal. It is the exception among the current crafting surfaces.

The practical consequences are:

1. **Input and output theft is possible at shared/public stations.** Another
   player can remove staged inputs or fuel. A different player who satisfies
   the output recipe's profession gate can take the completed output and gets
   the progression credit. No callback connects that output to the player who
   supplied the materials (`mods/PLAYER/grug_jobs/stations.lua:225-272`).
2. **Authorization occurs too late for timed professional stations.** Furnace
   and Brewing inputs can be accepted and consumed without proving that the
   depositing player can perform the resulting professional recipe. Output
   extraction then checks the taker's profession. This can strand Bread,
   Cooked Meat, Cooked Fish, potions or other professional outputs until a
   qualified player arrives. For the custom benches, inputs remain removable,
   but an unqualified player can still stage a recipe that only a qualified
   player can complete.
3. **Public access is broader than protection ownership.** Capital station
   sockets are deliberately registered as public after mods load
   (`station_nodes.lua:448-459`). Capital protection prevents ordinary node
   digging, but it does not make inventory contents private.
4. **Normal digging refuses non-empty stations, but the station callbacks do
   not themselves check ownership.** Furnace, Dual Furnace, Brewing Stand and
   custom benches use inventory-emptiness-only `can_dig` checks
   (`default/furnace.lua:55-59`, `grug_smelting/node.lua:75-79`,
   `grug_brewing/node.lua:309-313`, `grug_jobs/station_nodes.lua:209-212`).
   The engine's protection boundary normally rejects player digging in a
   protected capital.
5. **Blast callbacks are a separate weak boundary.** Furnace, Dual Furnace and
   Brewing Stand unconditionally drop all inventory lists and remove the node;
   the custom profession stations drop the `craft` list and station node, but
   not their `output` preview (`default/furnace.lua:411-418`,
   `grug_smelting/node.lua:326-333`, `grug_brewing/node.lua:345-352`,
   `grug_jobs/station_nodes.lua:274-279`). None of those callbacks checks
   protection or the public-socket registry. The shipped game does not contain
   a TNT mod that currently invokes these node blast paths, so this is a latent
   integration boundary rather than a demonstrated live theft path. Any future
   explosion provider must enforce protection before calling them, or the
   station callbacks must fail closed themselves. The Dual Furnace header's
   claim that `on_blast` empty-checks all lists does not match its implementation
   (`grug_smelting/node.lua:20-24,326-333`).

## Recommended later work package

Create a separate **Station Work Orders** package after Round 12. Keep the
placed node as the shared visual/UI anchor, but store each professional job in
a persistent per-player work order keyed by player and station identity. Each
player should see only their staged inputs, fuel/progress where applicable and
output. Profession-free public Basics processing can remain explicitly shared
if that social behavior is desired; professional work should be private by
default.

The package should include these contracts:

- Authorize the player and resolve the exact recipe before starting or
  consuming a professional job. A later output check remains a defensive
  revalidation, not the first authorization point.
- Reserve and consume an exact input snapshot atomically. Recipe swaps,
  disconnects, station unload/reload and concurrent users cannot transfer one
  player's progress or materials to another.
- Provide Cancel/Collect actions. Cancel restores the exact unconsumed inputs
  to that player's inventories atomically; if they do not fit, refuse the
  cancellation unchanged and retain the work order for later collection.
- Persist completed outputs until their owner collects them. Award profession
  progression to the work-order owner exactly once, even after reconnect or
  station reload.
- Decide explicitly whether fuel is a station-wide public resource or part of
  each work order. Mixing private ingredients with an anonymous shared fuel
  pool should not happen accidentally.
- Close dig/blast/removal paths over active work orders: either refuse removal
  while orders exist or transfer every order to a player recovery queue before
  removing the node. Protection checks must live at the destructive callback
  boundary as well as in the explosion provider.
- Cover two simultaneous players, unauthorized staging, qualified theft,
  disconnect/reconnect, full inventory on cancel/collect, node unload, node
  removal and exact-once progression in focused tests.

This is a distinct ownership and transaction model, not a small follow-up to
the Round 12 recipe-book changes. It should be designed and reviewed as its own
work package.
