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
 profession = nil, spawn = nil}
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
  - `trainer` — a profession trainer resident; `profession` is exactly one of
    `blacksmith`, `alchemist`, `tailor`, `leatherworker`, `woodcarver`,
    `goldsmith` or `cooking`. No other role may carry `profession`;
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

Since 2026-09-18 every start additionally carries one `trainer` socket for
Cooking. Every capital carries seven `trainer` sockets, one for each of the six
primary professions and one for Cooking.

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
seven elders stood with their backs to the street) and for **any position in
`tags`**. `tags` is a list: the turn is a statement about any entry, while the
NPC's spoken line follows `tags[1]`, so `{"bench", "door"}` is a bench spot at a
door and both halves hold.

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

## 8. Work sockets, profession vendors and the 80/20 rule (2026-09-15)

Playtest round 3: the capitals are empty and every resident is either a
doorstep-stander or a wanderer. The user's rulings: guards always patrol;
residents are **about 80 % static at a workplace with an activity animation
and about 20 % walkers on short routes** (server load: path-finding and
animated meshes are the cost, not the entity count); and the variety of
activities is what makes a district read as lived in — a butcher with a
butcher's house, a smith at a forge, citizens fishing at a pond with a
fishmonger beside it.

### 8.1 The `work` role

A new role, `work`, is a resident's workplace. It is a `spawn` socket (one
resident is placed on it, the roster counts it) and it carries

```lua
{id = "forge_anvil", role = "work", activity = "smith",
 x = 12, y = 1, z = -7, dir = {x = 1, z = 0}}
```

- `activity` is REQUIRED and one of the closed vocabulary below. Anything else
  is a build error in the registry, so a typo in a plot table fails at load
  and never silently produces a standing NPC.
- `dir` faces the thing being worked (the anvil, the water, the field row,
  the counter). The NPC lane may turn the mesh as the animation needs, but
  the authored facing names the feature, like `idle`'s does.
- A `work` socket is always STATIC: its resident never leaves it. It may carry
  `tags` like an `idle` socket (for the spoken line); `door` keeps its §7
  meaning.
- The blueprint KATs hold a `work` socket to every rule an `idle` socket
  obeys (feet and head air, walkable ground, outside rooms, reachable from
  the arrival) and additionally require the feature named by the activity to
  stand where `dir` points, within three nodes: `smith` an anvil or furnace,
  `fish` a water node, `farm` a farmland or crop node, `chop` a log or tree,
  `pray` the chapel's door, an altar, a candle or a grave marker (the socket
  stands OUTSIDE, as every socket does; "chapel interior" was the first
  wording and contradicted the outside rule, corrected 2026-09-15 after the
  NPC lane's review), `tend` a plant or a flower, `stall` a counter (any
  solid node at waist height), `sit` a stair or slab or bench node under the
  socket's own feet cell is NOT required — `sit` sits on the ground it
  stands on. The feature search stops at the first solid node on the
  socket's own course, so a feature behind a wall does not count.
- `fish` is **capital-only**: a start blueprint may contain no water cell
  (`blueprint_kat`), and the feature test reads blueprint cells, so no start
  can author it; a capital plot may carry its own pond and does (Highcourt).

### 8.2 Activity vocabulary (closed; extend here first)

| activity | what the resident does | wielded item (NPC lane) |
|---|---|---|
| `smith` | hammers, punch animation on a slow loop | a hammer or pick |
| `fish` | stands still holding a rod, occasional punch swing | fishing rod (an existing item or a stick) |
| `farm` | hoes on a slow loop, punch animation | hoe |
| `chop` | swings an axe on a slow loop | axe |
| `tend` | crouch-free stand, occasional punch (weeding) | nothing |
| `pray` | stand animation, no swing | nothing |
| `stall` | stand animation, faces the counter | nothing |
| `sit` | sitting pose (the player mesh's sit frames 81..160) | nothing |
| `sweep` | walks a two-node line back and forth beside the socket | nothing |

Wave 2 (2026-09-15, the four remaining capitals and the Dur Brannoc upgrade;
the user's plan, vocabulary proposed by the coordinator and open to pruning)
adds six race-flavoured activities. The feature each expects under `dir`
within three nodes, checked by the placing lane's KAT exactly as §8.1 does:

| activity | what the resident does | feature under `dir` | wielded item (NPC lane) |
|---|---|---|---|
| `mine` | swings a pick at a rock face on a slow loop | a stone, ore or cobble node at head or chest height | pick |
| `brew` | stirs, occasional punch swing | a cauldron, barrel or a cooking pot node | nothing or a ladle-like stick |
| `carve` | chisels, punch animation on a slow loop | a log, a totem/statue part or a stone block | axe or pick |
| `mourn` | stands still, head bowed if the mesh allows | a grave marker, a coffin or a candle | nothing |
| `spar` | swings a weapon on a slow loop at a partner | another `spar` socket or a training dummy (a fence post or a wool node) | the settlement's tier-1 weapon |
| `forage` | crouch-free stand, occasional punch (picking) | a mushroom, a bush, a plant, a vine or leaves | nothing |

The exact animation choice is the NPC lane's; this table is the contract on
NAMES and on the feature each name expects. `sweep` is the only activity that
moves, and it stays within two nodes of its socket. An activity the NPC mod
does not animate yet is a resident standing still at its workplace
(`start_villagers.lua` returns no work tick for it), never a load error, so a
structure lane may author the wave-2 names before the NPC lane's animations
land.

### 8.3 Walkers and the 80/20 split

Nothing is authored for it. Among a settlement's resident spawn sockets
(`idle` with `spawn ~= false`, plus `work`) taken in authored order, the NPC
lane decides deterministically which residents walk: **every fifth `idle`
spawn socket, starting with the first, hosts a walker; every `work` socket
and every other `idle` socket hosts a static resident.** A static `idle`
resident keeps the round-1 amble only as a rare short hop (the spare ring),
never a continuous walk. A walker's route is short: spot ring entries within
a bounded distance of its home (the NPC lane measures and states the bound).

The KAT of the NPC lane asserts the resulting walker share per settlement is
between 10 % and 30 % of residents, so a composition that is all `work`
sockets (zero walkers) is a KAT failure, not a lively district. The
arithmetic: with I idle spawn sockets and W work sockets the rule yields
ceil(I/5) walkers of I+W residents, which stays inside the band exactly when
I >= W (roughly). Structure lanes therefore author **at least one `idle`
spawn socket per `work` socket** (the first wording, "one per five
residents", would have yielded 4 % and was corrected 2026-09-15 after the
NPC lane's review; Highcourt with 108 idle spawn and 36 work sockets gives
22 of 144, 15.3 %). A walker's ring holds at least two destinations: the
spots within the walk radius, and when fewer than two lie inside it, the
nearest spots until there are two, so no walker is ever handed a ring of one
(Stillgrave's first idle socket was, in the first version).

### 8.4 Profession vendors

`vendor.kind` grows from `{race, general}` to
`{race, general, butcher, smith, fishmonger, baker, tailor}`, and in wave 2
(2026-09-15) further by `{mason, brewer, bowyer, herbalist, armourer, tanner,
embalmer}`; a kind whose entity the traders mod has not registered yet is an
error line at placement and an empty socket, never a load failure. A profession
vendor is a trader with a stock table of its profession (the NPC lane owns
the tables, `grug_traders`) and the structure lane places its socket at the
matching building (a butcher's socket at the butcher's counter). A capital
may hold at most ONE vendor per kind (the Highcourt KAT's family rule
extends to every kind); the six starts keep their single `race` vendor.

### 8.5 Who owns what

- Registry vocabulary (`grug_core/settlement_sockets.lua`): the coordinator,
  landed with this section so both lanes build on it.
- KAT rules of §8.1 for `work` sockets and the feature-under-`dir` check:
  the Highcourt fill lane in `highcourt_kat.lua`; the NPC lane in
  `blueprint_kat.lua`, because it places the first `work` sockets in the six
  starts (one or two per start, at features that already exist) to have
  something to animate and to measure against.
- Animations, wield items, walker selection, walker bound, load measurement:
  the NPC lane (`grug_mobs/start_villagers.lua`, `start_npcs.lua`).
- Profession stock tables and the vendor entities: the NPC lane
  (`grug_traders`); the Highcourt fill lane places the sockets.
- Wave 2: the registry rows of the six activities and seven kinds above are
  landed by the coordinator before the lanes start (as in wave 1); each
  capital lane's own KAT checks the feature-under-`dir` rule for the
  activities it places; the NPC vocabulary lane (`grug_mobs`, `grug_traders`)
  owns their animations, wield items, stock tables and entities.
