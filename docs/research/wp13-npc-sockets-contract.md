# WP13: settlement sockets for NPCs — contract

Status: decided by the coordinator on 2026-09-14 (Claude Fable) as the shared
seam between the structure lanes (blueprints, capitals) and the NPC lane.
User rulings in §5. Both sides implement against this file; changes to it are
announced to every open lane.

## 1. Why

Guards come out of guard banners at outposts and capitals (`grug_mobs/
camps.lua`), vendors stand at two fixed offsets from a capital anchor
(`grug_traders/vendors.lua`). The starts have neither, and hard-coded
offsets do not survive a blueprint change. A blueprint therefore exports
**sockets**: named standing positions with a role, in the same anchor-relative
coordinates as its other landmarks. Runtime mods read them through one
registry in `grug_core` and never touch the mapgen mod.

## 2. Blueprint side

`landmarks.sockets` is an array (fixed authored order) of

```lua
{id = "gate_west", role = "guard_post", x = -3, y = 1, z = 63,
 dir = {x = 0, z = 1}, group = nil, order = nil, kind = nil, tags = nil,
 spawn = nil}
```

- `x, y, z`: anchor-relative like `landmarks.spawn`; `y` is the node the
  entity stands in (feet), i.e. floor + 1. The cell and the one above it are
  air in the blueprint and the node below is walkable, checked by the
  library KAT for every socket.
- `dir`: the facing as one of the four axis vectors; consumers convert with
  `core.dir_to_yaw`.
- `role` is one of
  - `guard_post` — a guard stands here and returns here after fights;
  - `guard_patrol` — one waypoint of a patrol loop; `group` names the loop,
    `order` (1..n) its sequence;
  - `vendor` — a trader; `kind` is `"race"` or `"general"` (the two vendor
    families of `grug_traders`);
  - `idle` — a flair NPC spot; `tags` is an optional list such as
    `{"bench"}`, `{"door"}`, `{"work"}`, `{"fire"}` the NPC lane may use for
    animation or lines;
  - `idle` **with `spawn = false`** — a SPARE spot (added 2026-09-15, playtest
    round 2): a real authored standing position that nobody is ever placed on
    and every villager of the same composition may wander to. See §6;
  - `quest` — a quest-giver shell (later WP);
  - `king` — the throne (capitals only);
  - `waypoint` — reserved for WP17's travel waypoint; the structure lane
    places it, nobody else consumes it yet.
- `id` is unique within one blueprint; the string is stable (it may appear
  in logs and tests).
- `spawn` is either absent or exactly `false`, and only an `idle` socket may
  carry it. The registry normalizes it to a boolean, so a consumer reads
  `socket.spawn` and never has to spell "nil means true". Anything else is a
  build error (`grug_core/settlement_sockets.lua`).

Sockets are **not identity bytes**: the settlement identity SHA covers
schema, bounds, palette and cells only (`r7_settlement.lua`), so adding or
moving sockets keeps every blueprint identity. The usual file-digest rules
(`files.sha256`, micro pair) still apply to the edited sources.

## 3. Runtime side

`grug_core` owns a registry, filled by `grug_mapgen` at load from every
composition's `landmarks.sockets` and the settlement's anchor:

```lua
grug_core.register_settlement_sockets(settlement_key, race_id, anchor, sockets)
grug_core.settlement_sockets(race_id)      -- starts; list of world-space copies
grug_core.settlement_sockets_at(settlement_key)
```

- World position = anchor + local; `y` uses the published fitted `anchor.y`
  (starts and capitals both publish it).
- Returned entries carry the same fields plus `pos` (vector) and `yaw`.
- Consumers (`grug_mobs`, `grug_traders`, later quests) read the registry in
  `core.register_on_mods_loaded` or later, and only place entities after
  `grug_core.start_ready(race_id)` reports the area prepared; they never
  depend on `grug_mapgen`.
- Capitals register under their own key when the capital core lands; the
  two vendor offsets in `vendors.lua` migrate to `vendor` sockets at that
  moment and not before.
- **A settlement key is unique, a race id is not** (every race has a start and
  a capital). `settlement_sockets(race_id)` therefore answers with the race's
  START — the first settlement registered for it, which `grug_mapgen` publishes
  while the world authority is installed — and every other settlement is
  reached through `settlement_sockets_at(key)`.

## 4. Start roster (first version, coordinator's defaults)

Per start: two `guard_post` at the gate (one per side of the gate street),
one `guard_patrol` loop of four to six waypoints through the settlement,
one `vendor` of kind `race` near the arrival plaza, three to four `idle`
spots (door, bench, work area, fire), one `quest` spot near the hall.

Since 2026-09-15 also **three spare `idle` spots per start** and **ten in
Highcourt's core** (§6). They are part of the `idle` population the KATs count
and are additionally counted on their own, because the two numbers say
different things: `idle` is how many standing positions a settlement offers,
`spare` how many of them nobody lives on.

## 5. User rulings

- **Guards attack enemy-faction players everywhere** (2026-09-14). The
  faction veto of `guard.lua` stays the single rule; start guards inherit it
  unchanged. Start guards still ignore own-faction and factionless players
  and fight hostile mobs.
- Settlements offer no storage, quest or profession services in WP13
  (settlements.md); a `quest` socket is a position, not a system.
- **Hostiles and guards may fight; non-combatants are never a target**
  (2026-09-15, playtest round 2). This replaces the round-1 rule that gave every
  mob `attack_npcs = false`. The veto is a property of the TARGET
  (`grug_mobs.noncombatant` installs `_grug_noncombatant` at activation, and a
  GRUG PATCH in `general_attack`'s candidate filter drops such an entity), not a
  narrowing of the attacker. Villagers, elders and vendors carry it; guards do
  not, and keep their own `attack_npcs = false` so guard-versus-guard stays off.

## 6. Spare idle sockets (2026-09-15)

`spawn = false` on an `idle` socket means **wander target, never a home**:

- the placement engine's roster — and with it every mod-storage marker, the hard
  population cap and every census — counts only SPAWN sockets;
- the amble's spot ring (`next_spot`) walks **every** idle socket of the NPC's
  own composition, spares included, in the blueprint's authored order. The index
  a spot gets is the index the placement engine writes into `_grug_idle_spot`,
  so it is taken from that authored order and never from a count of the placed
  sockets;
- a spare carries **no tag**. A tag names a feature the NPC standing there talks
  about (`LINES[race][tag]`), and a spare is a place to stand.

Why they exist: without them a settlement's idle spots and its idle NPCs are the
same list, so every candidate spot is permanently occupied and the amble
degenerates into people trading doorsteps — which is what the 2026-09-15
playtest saw.

A spare is a real standing position and is held to every rule an authored socket
is: feet and head air, walkable settlement ground under it, outside every room,
reachable on foot from the arrival. `tools/wp13/blueprint_kat.lua` and
`tools/wp13/highcourt_kat.lua` measure that against the finished pad, and both
assert the exact spare population per settlement.

## 7. The `door` tag (2026-09-15)

`door` is a **consumer rule, not a geometric claim**: `start_npcs.lua`'s
`socket_face_yaw` turns a door-tagged socket's NPC 180° from its authored
facing, for **every role** (round 1 restricted it to `idle`, which is why all
seven elders stood with their backs to the street).

The authored `dir` therefore keeps meaning "the feature this socket belongs to",
and two readings of that are both in use and both legal:

- the six starts' and Highcourt's `quest` sockets stand OUTSIDE on a doorstep
  facing the door, so the turn puts the elder's face on the street. Both KATs
  measure this one: the tag must be present, the authored facing must run into
  the building within five nodes, and the cell behind — where the elder will
  actually look — must be free and reachable;
- the capitals' own gate and hall-service `idle` sockets stand INSIDE a gate
  looking in, so the turn faces the citizen at the door it is about to leave by.

A new role placed at a door inherits the turn by carrying the tag.
