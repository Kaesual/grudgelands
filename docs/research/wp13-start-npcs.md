# WP13: the start settlements' first NPC roster

Increment record, 2026-09-14. Implements
[wp13-npc-sockets-contract.md](wp13-npc-sockets-contract.md) on both sides —
the blueprint export and the runtime registry — and the first roster that
consumes it. Evidence:
`tools/wp13/evidence/20260914-start-npcs/`.

## What shipped

1. **Sockets in every composition.** All six `mods/MAPGEN/grug_mapgen/wp13/`
   compositions export `landmarks.sockets`: thirteen sockets each, in a fixed
   authored order — two `guard_post` flanking the gate street, one
   `guard_patrol` loop of five waypoints, one `vendor` of kind `race` near the
   arrival plaza, four `idle` spots tagged `door`/`bench`/`work`/`fire`, one
   `quest` spot beside the hall.
2. **The registry** `mods/CORE/grug_core/settlement_sockets.lua`:
   `register_settlement_sockets` / `settlement_sockets(race_id)` /
   `settlement_sockets_at(key)` plus `settlement_socket_anchor(key)` and
   `settlement_socket_settlements()`. Filled from `wp40/r7_loader.lua` for the
   six starts.
3. **The placement engine** `mods/ENTITIES/grug_mobs/start_npcs.lua`: one pass
   per start, driven only by the registry, with a per-socket role resolver
   registry so `grug_traders` keeps ownership of which vendor stands where.
4. **The NPC families** `mods/ENTITIES/grug_mobs/start_villagers.lua`:
   `grug_mobs:villager_<race>` (flair) and `grug_mobs:elder_<race>` (quest
   shell) for the six start races, with `_grug_visual = {race = ...}` and the
   guard skin as the placeholder texture.

## Sockets are not identity bytes, and that was measured

`wp40/r7_settlement.lua` hashes schema, bounds, palette and cells — landmarks
are not in the digest. So all six blueprint dumps and all six settlement
identity SHA-256s are byte-identical to the round-A record
(`dumps.txt`, and the `wp13_integration` row in `final-micro/micro-*.tsv`).

## The socket tables

Anchor-relative, `y = 1` for every socket (the node above the settlement's own
ground course). `dir` is the axis the entity faces.

| Start | gate posts | patrol loop | vendor | idle (door/bench/work/fire) | quest |
| --- | --- | --- | --- | --- | --- |
| Hearthpine | (∓4, 59) facing +z | `vale` 1..5: (0,52) (0,24) (−9,2) (0,−6) (9,2) | (7,−5) | (−16,4) (7,1) (−19,17) (2,−10) | (−28,26) |
| Dawnmere | (∓4, 57) facing +z | `fields` 1..5: (0,52) (0,24) (−9,0) (0,−6) (10,0) | (6,−4) | (10,−16) (−6,7) (−19,0) (22,−1) | (−11,8) |
| Silverleaf | (∓4, 57) facing +z | `glade` 1..5: (0,52) (0,24) (−10,0) (0,−7) (10,0) | (7,−4) | (−21,16) (−7,5) (28,−1) (−31,0) | (20,14) |
| Stillgrave | (∓4, −56) facing −z | `hollow` 1..5: (0,−52) (0,−24) (−9,0) (0,6) (9,0) | (7,−5) | (−13,32) (−10,4) (22,−1) (−5,−57) | (2,10) |
| Sunscar | (∓4, −51) facing −z | `camp` 1..5: (0,−40) (0,−22) (−11,0) (−1,7) (11,0) | (8,−5) | (−11,−22) (−3,8) (−25,−2) (20,−2) | (3,12) |
| Kapok | (∓4, −45) facing −z | `cradle` 1..5: (0,−36) (0,−18) (−10,0) (0,10) (10,0) | (7,−4) | (−2,17) (−12,27) (−17,24) (13,20) | (3,17) |

Each `idle` and `quest` socket stands at the feature it is named for: a home's
doorstep, a bench or stone settle, the workyard/barn/bowyer/bone works/beast
pen/drying shed, and the warmest thing the start has outdoors (forge door,
smithy, market lanterns, gate brazier, armoury forge, fish smoker). Kapok keeps
no gate wall, so its watch stands where the road passes the watchpost.

## Why a registry-driven watch and not a guard banner

The work package left the choice open. A banner plus the existing LBM and camp
mechanism was rejected on four blocking grounds, all written out in
`start_npcs.lua`'s header:

1. **A banner is a cell, and cells are identity bytes.** Six banners would move
   six frozen settlement identities, the R7 manifest SHA and every piece of
   engine evidence recorded against them. `tools/wp13/blueprint_kat.lua`
   already refuses a `grug_nodes:guard_banner` cell outright ("decorative
   spawner"), so the blueprint side is closed by assertion.
2. **camps.lua has no concept of an authored position.** `free_spot_near`
   places a member at a random standable spot inside a radius with no facing at
   all; "two posts, one per side of the gate street, both looking down the
   road" cannot be expressed to it without building a second placement engine
   inside it.
3. **Its patrol route comes from the outpost roster.** `assign_patrol` asks
   `grug_core.outpost_at` / `outpost_patrol_target`, i.e. the 24 authenticated
   outpost anchors. A start is not an outpost, so a banner there gets no route,
   and the authored five-waypoint loop has no way in.
4. **A banner is written by mapgen.** Every later NPC change would drag the
   whole WP13 engine gate (`tools/wp13/run_engine.sh`: two seeds, four worlds)
   behind it. Nothing in this increment touches what the mapgen writes, so that
   gate is not triggered.

What *is* reused is the camp mechanism's **model**: world.md §4a's respawn
slots. Each guard socket is one slot; a killed start guard's socket refills
180–360 s later, the same rhythm an outpost picket has, and a settlement nobody
is standing in simply gets its guard back late rather than never.

The guards themselves are the unchanged `grug_mobs:guard_accord` /
`guard_throng` entities: same faction veto (the user's 2026-09-14 ruling — they
attack enemy-faction players everywhere), same `attack_monsters`, same level
from the inverse guard field via `_grug_level_source = "guard"`, same elite
promotion at level 60. guard.lua gained exactly two things: a call to
`grug_mobs.start_post_tick` for guards that carry a post, and an `on_die` that
frees a start socket. Neither touches targeting.

## Persistence and idempotence: one mod-storage marker per socket

`grug_mobs.storage` holds `startnpc:<race>:<socket>` = `"1"` for every occupied
socket, plus `startnpcdue:<race>:<socket>` for a guard slot waiting out its
refill. A marker is written the moment an NPC is placed and cleared only by
that NPC's death.

**Why not a presence scan as the primary gate.** `core.get_objects_inside_radius`
only ever sees *activated* objects, and a mapblock is activated by a player
being near it — not by being loaded. Placement happens when
`grug_core.start_ready(race_id)` reports the area prepared, which is exactly
the moment the 128 × 128 envelope is loaded and no player is anywhere near it.
A scan would therefore find nothing on the second boot and duplicate the whole
roster, forever, because `type = "npc"` entities never expire. `vendors.lua`
escapes that only by never looking at a slot further than 24 nodes from a
player, which a roster that must exist before anyone arrives cannot do.

The scan is kept as the **second** gate: if a marker is missing but the entity
booked on that socket is standing there anyway, the marker is restored instead
of a twin being spawned. It matches the *socket*, not merely the entity name —
and that is not a refinement. The first headless boot of this increment matched
by name inside an 8-node radius, saw the guard of the post next door (the two
gate posts are eight nodes apart and carry the same entity), "restored" a marker
nobody had lost and left that post empty: Hearthpine came up with one guard
instead of three. The fix is in `socket_occupied`, with that measurement in the
comment.

Only guards are mortal; every other family cancels every punch and switches off
every environmental damage source (the api.lua evidence is quoted in
`start_villagers.lua`, from `vendors.lua`).

## Placement uses core.add_entity, deliberately

`mobs:add_mob` refuses whenever no player is inside the active area
(api.lua:3885-3890, `count_mobs` → `is_pla`) because that is the ABM spawner's
own gate. Authored settlement content decides its own position — the same rule
`wp13-start-preload.md` states for camps, guards and rares — and the whole
point of placing at start-ready is that the prepared area has no player in it.
The collision-box lift `add_mob` performs is kept via
`grug_mobs.place_on_ground`.

## Behaviour

- **Post guard**: `_grug_home` is its socket, so aggro.lua's evade runs it back
  there after a chase; `start_post_tick` (1 Hz, idle only, skipped while
  evading) walks it home beyond two nodes and otherwise holds it standing at the
  socket's yaw. It deliberately carries **no** `_grug_camp_pos`, which would
  switch on aggro.lua's 20-node camp roam cap as a second, looser owner of the
  same behaviour.
- **Patroller**: one guard with `_grug_patrol_route = {points, wp}`, walked by
  the existing `grug_mobs.route_tick`; aggro.lua already exempts a route carrier
  from both the leash and the roam cap.
- **Flair villager**: walks to its current idle socket, stands there facing it
  for 20–50 s, then picks another, at 1.1 walk velocity. `walk_chance = 0` and
  `randomly_turn = false` keep mobs_redo's own wander out of it. A right-click
  answers with one line chosen by the tag of the socket it is standing at
  (`door`/`bench`/`work`/`fire`, or the race's default), throttled to one answer
  per two seconds. No formspec.
- **Quest shell**: stationary, nametagged, one placeholder line. No quest logic.
- **Vendor**: the race's own `grug_traders:vendor_race_<race>` entity, with the
  capital offsets in `vendors.lua` untouched — the contract migrates those to
  `vendor` sockets when the capital core lands, not before.

## Verification

- **KAT pair, byte-identical.** `library_kat` + `blueprint_kat` +
  `integration_fixture` + the new `settlement_sockets_kat` in one process under
  LuaJIT and under `tools/bin/lua51`, `LC_ALL=C`:
  `0dbeadcd07d98f3de19e7eb536953c0a7e561a653acbf4bfc7220b39588179d1` from both
  (`kat.sh`, and the same digest from `final-micro.sh`, which hashes its input
  set before and after both runs).
- **Socket validity, all six starts.** `blueprint_kat.lua` now checks every
  socket of every start against the finished pad: unique id, known role, axis
  facing, air at the feet and the head, walkable ground below, outside every
  authored room, and reachable on foot from the arrival through the fixture's
  own flood fill. Plus one patrol loop of 4–6 waypoints numbered without a gap,
  no two consecutive waypoints inside `route_tick`'s 4 m arrival radius, and
  **exact** per-start socket populations, like the prop populations beside them.
- **Registry KAT.** `tools/wp13/settlement_sockets_kat.lua` drives the real
  `grug_core` file against a stub engine: world-space conversion against the
  published fitted anchor, the four axis yaws against the engine's own
  `core.dir_to_yaw` one-liner (the stub also asserts the facing handed to it is
  horizontal), copies in both directions (a consumer mutating a returned entry,
  and the caller mutating the authored table afterwards), and all twenty-one
  refusals — with the assertion that a refused registration leaves no state.
- **Static gates** (`static.txt`): `luac51 -p` and the SETGLOBAL count per
  touched file and tree-wide, the five plain-5.1 sweeps scoped to the touched
  files (clean apart from a `|` inside a pre-existing comment) and over the
  whole WP13 surface, the six unchanged blueprint dumps, and
  `check_fresh_server.py` PASS.
- **Engine** (`engine.sh`, `engine-boot1.log`, `engine-boot2.log`,
  `engine-census.txt`): two headless boots through `tools/luanti_headless.sh`
  on seed 531802985935182545. See the table below. Zero ERROR and zero ModError
  lines in both.
- **Not triggered**: `tools/wp13/run_engine.sh`. This increment writes no
  mapgen cell — sockets are landmarks — and the six blueprint dumps prove it.

### Engine results

| | boot 1 (fresh world) | boot 2 (same world) |
| --- | --- | --- |
| preload | 6/6 ready after 37.6 s | 6/6 ready after 8.8 s, from disk |
| per start | `guards 3/3 flair 4/4 vendor 1/1 quest 1/1 new 9 pending 0` | `… new 0 pending 0` |
| placed | 54 (9 × 6 starts) | 0 |
| ERROR / ModError | 0 | 0 |

`engine-census.txt` closes the half the log cannot: the kept world's
`map.sqlite` is decompressed block by block and its static objects counted by
entity name after the second boot — 18 guards, 24 villagers, 6 elders and 6
race vendors, 54 in total, which is the roster exactly once. A static object in
a loaded but inactive mapblock is invisible to every Lua query, so this is the
only way to see that the first boot's entities survived the restart and were
not doubled. The 54 mod-storage markers are in
`world/mod_storage/grug_mobs`, nine per race, and no `startnpcdue:` key exists
because nothing died.

## Deviations from the contract

- Every start carries **four** `idle` sockets, the upper end of the contract's
  "three to four", and **five** patrol waypoints, mid-range of its "four to
  six". Both are choices, not exceptions.
- The registry gained two queries the contract does not name —
  `settlement_socket_anchor(key)` and `settlement_socket_settlements()`. The
  second is how a consumer walks the registry without restating the six-start
  roster; the first is what lets `grug_mobs` cross-check the socket anchor
  against the anchor the consumer payload publishes (it logs an error if they
  ever differ, which would put every NPC at a different height from the
  buildings).
- Returned socket entries keep `x`, `y`, `z` as the **authored local**
  coordinates and add `pos`/`yaw` in world space, which is the literal reading
  of "the same fields plus `pos` and `yaw`".
- Flair NPCs carry a nametag, which the contract asks for only on the quest
  shell. Without one a player cannot tell a clickable villager from a guard,
  and there are at most five per settlement.

## Open points

- The `_grug_visual` field is inert until the character-visuals lane merges, and
  all five families currently wear the faction guard skin — including the six
  race vendors, which is the pre-existing asset TODO in `vendors.lua`. NB
  mobs_redo copies only its own def whitelist onto the entity, so that lane
  must read `_grug_visual` off `core.registered_entities[name]`, not off `self`.
- A start guard dragged far from its post during a fight and killed there frees
  its socket correctly, but the refill appears at the socket while the corpse's
  loot lies where it fell. That is the same behaviour an outpost has.
- `tools/wp40/r7/changed_production_lua.txt` (the WP40 R7 source audit's frozen
  roster of changed production Lua) was already stale on `main` before this
  lane: `mods/CORE/grug_core/starts_preload.lua` from the round-A server half is
  missing from it, so the audit's population check fails at 143 against its
  expected 142. This increment adds three more files and does not touch that
  WP40-owned artefact.
- `docs/design/world.md` §4a describes respawn slots in terms of camp anchors;
  the start watch is a third consumer of that rule and is documented in
  `settlements.md` instead.

## User runtime test

Fresh world, seed `531802985935182545`, any race; `tools/sync_to_luanti.sh`
first.

1. Walk out of the arrival plaza to the gate. Two guards stand one node inside
   the gate line, one either side of the road, both looking down it. Walk past
   them and back: they return to their exact node and face the road again
   instead of drifting.
2. Stand on the road a while: a third guard of the same colours comes up or down
   it on the patrol loop (gate, main street, both flanks of the plaza, the hall
   front) and keeps going around.
3. Right-click each of the four villagers. Each answers once with a line that
   fits where it is standing (doorstep, bench, work yard, fire), and a held
   mouse button does not spam the chat. Watch one for a minute: it walks to
   another of the four spots at walking pace and stands facing it.
4. Right-click the elder beside the hall: a nametag and one placeholder line, no
   formspec.
5. Right-click the Quartermaster on the plaza: the normal trade window, with the
   same-race discount.
6. Kill one gate guard (creative, or an enemy character). The post stays empty
   for three to six minutes and is then manned again, once — not twice.
7. Leave and rejoin, then restart the server and walk the same settlement: the
   same nine NPCs, in the same places, facing the same way. None of them is
   doubled.
8. Take an enemy-faction character to another race's start: the gate guards
   attack; with an own-faction or a brand-new factionless character they do not.
