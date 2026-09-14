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
 dir = {x = 0, z = 1}, group = nil, order = nil, kind = nil, tags = nil}
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
  - `quest` — a quest-giver shell (later WP);
  - `king` — the throne (capitals only);
  - `waypoint` — reserved for WP17's travel waypoint; the structure lane
    places it, nobody else consumes it yet.
- `id` is unique within one blueprint; the string is stable (it may appear
  in logs and tests).

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

## 5. User rulings

- **Guards attack enemy-faction players everywhere** (2026-09-14). The
  faction veto of `guard.lua` stays the single rule; start guards inherit it
  unchanged. Start guards still ignore own-faction and factionless players
  and fight hostile mobs.
- Settlements offer no storage, quest or profession services in WP13
  (settlements.md); a `quest` socket is a position, not a system.
