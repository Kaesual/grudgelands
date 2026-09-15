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
refill. A marker is written the moment an NPC is placed, and cleared in two
places: from the guard's `on_die`, and from the heartbeat pass when the socket
is visibly empty.

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

**A marker must never outlive its NPC, and `on_die` alone does not guarantee
that.** `on_die` is reached only from `check_for_death` (api.lua:870-876), so
`/clearobjects`, the `mob_active_limit` removal inside `mob_activate`
(api.lua:3311-3314) and a shutdown between the mod-storage flush and the map
flush all end with a marker and nothing standing on it — and that socket would
then never refill for the life of the world. The heartbeat pass therefore also
re-checks the sockets it *can* see: a placed slot within `PLAYER_RANGE` of a
player whose `socket_occupied` is false is freed and queued again at once (no
respawn delay — a death earns one, an entity that simply is not there any more
does not). It is the exact mirror of the second gate, and it runs only on the
heartbeat because a player being near is what makes the mapblock active, which
is what makes the scan able to answer at all. This is also why the heartbeat
now walks every row instead of skipping full ones: a full row is exactly where
a marker without an NPC hides.

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
  for 20–50 s, then picks another, at 1.1 walk velocity (playtest round 1 raised
  the dwell to 20–60 s, turned a door socket's facing round, and fixed the ring
  advance that made this paragraph a description of what the code was supposed to
  do rather than of what it did). `walk_chance = 0` and
  `randomly_turn = false` keep mobs_redo's own wander out of it — and playtest
  round 1 found what else `walk_chance = 0` means inside `do_jump`. A right-click
  answers with one line chosen by the tag of the socket it is standing at
  (`door`/`bench`/`work`/`fire`, or the race's default), throttled to one answer
  per two seconds. No formspec.
- **Quest shell**: stationary, nametagged, one placeholder line. No quest logic.
- **Vendor**: the race's own `grug_traders:vendor_race_<race>` entity, with the
  capital offsets in `vendors.lua` untouched — the contract migrates those to
  `vendor` sockets when the capital core lands, not before. Its
  `after_activate` now also re-asserts `_grug_face_yaw`, so a start vendor
  keeps its authored facing across reloads (a capital vendor carries no such
  field and the call is a no-op for it).
- **Race appearance**: both new families call
  `grug_visuals.apply_entity(self, {race = race_id})` from `after_activate`,
  guarded by `core.global_exists("grug_visuals")`, exactly as `vendors.lua`
  does. `grug_mobs.register_mob` is what normally reads a definition's
  `_grug_visual`, and these two families deliberately do not go through it, so
  without the explicit call they would keep the placeholder guard skin for
  good. The def still carries `_grug_visual` as the contract's declaration;
  this call is what makes it act. No `write_textures` argument: that exists for
  grug_mobs' tier tint, and a villager has no tier.

## Verification

- **KAT pair, byte-identical.** `library_kat` + `blueprint_kat` +
  `integration_fixture` + `settlement_sockets_kat` + `start_npcs_kat` in one
  process under LuaJIT and under `tools/bin/lua51`, `LC_ALL=C`:
  `758c3e8c5facc9eb75a25cb25eb4bd56455e3d79f4f7830614a74068191455de` from both
  (`kat.sh`, and the same digest from `final-micro.sh`, which hashes its input
  set before and after both runs).
- **Socket validity, all six starts.** `blueprint_kat.lua` now checks every
  socket of every start against the finished pad: unique id, known role, axis
  facing, air at the feet and the head, walkable ground below, outside every
  authored room, and reachable on foot from the arrival through the fixture's
  own flood fill. Plus one patrol loop of 4–6 waypoints numbered without a gap,
  no two consecutive waypoints inside `route_tick`'s 4 m arrival radius, and
  **exact** per-start socket populations, like the prop populations beside them.
- **Placement-engine KAT.** `tools/wp13/start_npcs_kat.lua` drives the real
  `start_npcs.lua` against a stub engine through the five states that decide
  whether a settlement ends up with its roster exactly once: cold placement
  with nobody near, a restart that places nothing, markers whose NPCs are gone
  (`/clearobjects`) freed and refilled by the heartbeat, a guard death that is
  not refilled before its slot falls due and is afterwards, and the second gate
  restoring a lost marker instead of spawning a twin. The stub models the one
  engine fact the whole design hangs off — `get_objects_inside_radius` answers
  only while a player is inside the activation radius — so the restart case
  cannot pass for the wrong reason. This is also the only place the lost-entity
  re-check can be *proved*: it is gated on a nearby player by design, and a
  headless boot has no player in it.
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
| preload | 6/6 ready after 38.0 s | 6/6 ready after 10.4 s, from disk |
| per start | `guards 3/3 flair 4/4 vendor 1/1 quest 1/1 new 9 pending 0` | `… new 0 pending 0` |
| placed | 54 (9 × 6 starts) | 0 |
| ERROR / ModError | 0 | 0 |

`engine-census.txt` closes the half the log cannot: the kept world's
`map.sqlite` is decompressed block by block and its static objects counted by
entity name after the second boot — 18 guards, 24 villagers, 6 elders and 6
race vendors, 54 in total, which is the roster exactly once. It counts the
composed skins from the same blobs, which is the proof that the visuals seam
really ran: 54 `grug_visuals_skin_<race>.png` textures, six per start for the
villagers, elder and race vendor plus nine per faction for the guards (the
guard's own `_grug_visual` composes accord as human and throng as orc). A static object in
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
- **Uniqueness is per settlement key, not per race**, and contract §3 gained
  one sentence saying so. The first version refused a second registration for a
  race, which would have refused every capital the moment the capital core
  lands — each race has a start *and* a capital. `settlement_sockets(race_id)`
  answers with the race's START (the first settlement registered for it, which
  `grug_mapgen` publishes while the world authority is installed) and
  `settlement_sockets_at(key)` is the capital path. The registry KAT covers
  it: a second settlement for one race is accepted, the race accessor still
  returns the start, and the capital answers under its own key.
- Returned socket entries keep `x`, `y`, `z` as the **authored local**
  coordinates and add `pos`/`yaw` in world space, which is the literal reading
  of "the same fields plus `pos` and `yaw`".
- Flair NPCs carry a nametag, which the contract asks for only on the quest
  shell. Without one a player cannot tell a clickable villager from a guard,
  and there are at most five per settlement.

## Known limits, deliberately accepted

- ~~**Hostile mobs can target a villager.**~~ **Not accepted after all** — the
  2026-09-15 playtest found a boar standing in front of an invulnerable villager
  hitting her indefinitely at a capital, where "in practice nothing hostile
  reaches them" does not hold. `attack_npcs = false` is now applied by the
  registration wrapper to every mob (playtest round 1, item 5).
- **A wiped mod storage with a kept map duplicates the roster once.** The
  markers are the primary gate and the scan cannot substitute for them at
  start-ready, where no player is near and `get_objects_inside_radius`
  therefore sees nothing. Deleting `world/mod_storage/grug_mobs` while keeping
  `map.sqlite` is the one state that produces a second roster; it is not a
  state the game can reach on its own, and in fresh-server mode it is a
  developer action.
- **`face_yaw` writes a rotation once a second per post guard and per dwelling
  villager even when the yaw has not changed** (`set_rotation` on at most 30
  objects in a fully populated world, and only while they are activated). It is
  cheap enough to leave unconditional rather than add a compare that would have
  to reproduce mobs_redo's own pending smooth-rotation state.

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
  roster of changed production Lua) was **already stale on `main` at
  `44c2a34`**: the derived population is 151 against its expected 142, because
  round A's `starts_preload.lua` and the visuals lane's four files
  (`grug_classes/init.lua`, `grug_visuals/{apply,compose,init}.lua`) are not in
  it. This increment adds four more (`settlement_sockets.lua`, `patrol.lua`,
  `start_npcs.lua`, `start_villagers.lua`) and changes the content of twelve
  files that *are* in it (both `init.lua`, `guard.lua`, `vendors.lua`, the six
  compositions, `r7_loader.lua`, `r7_runtime.lua`), so the fixture's
  `source/changed_production_lua_sha256` moves from
  `8eb4e6ee…a9b4` (at `44c2a34`) to `f6e0ca2e…cf8b`. That WP40-owned artefact is
  deliberately not edited here; the live engine boots are what covers the two
  R7 files this lane touched.
- `docs/design/world.md` §4a describes respawn slots in terms of camp anchors;
  the start watch is a third consumer of that rule and is documented in
  `settlements.md` instead.

## Playtest round 1 (2026-09-15)

The user played the six starts and Highcourt in the GUI and found eight defects.
All eight are fixed in this increment; the numbers are his. Evidence:
`tools/wp13/evidence/20260915-npc-playtest-1/`.

### 1. Unbounded spawns — the marker was freed for every NPC that walked

`socket_occupied` asked `get_objects_inside_radius(socket, 8)`, i.e. "is my NPC
standing ON its socket right now". A guard walking its patrol loop and a
villager ambling between idle spots both answer no, so the heartbeat freed the
marker and placed a twin — every five seconds, for every NPC that was not at
home. After a while a start had about fifty guards in it.

Occupancy is now an **identity** question. Each settlement is scanned once per
heartbeat around its anchor, out to its furthest socket plus `SCAN_MARGIN` = 48
(the guard leash is 30), and every entity carrying this settlement's key is
matched to the socket its `_grug_socket` books — wherever it stands
(`start_npcs.lua` `scan_row`). Four things bound the population, and the marker
alone did not:

1. the marker, which is still what makes a restart place nothing;
2. that scan **removes** a second entity found on a socket that is already held,
   which is what heals a world that already has twins;
3. `grug_mobs.start_npc_claim`, called by all five families on activation
   (guard.lua's tick, both flair families' `after_activate`, vendors.lua's), so a
   twin coming back with its mapblock removes itself at once;
4. a hard cap in `place`: a settlement already holding as many NPCs as its
   roster has places nothing more, whatever its markers say. It is deliberately
   an ASSERTION -- with the claim map keyed per socket and the twin removal of
   (2), it cannot be reached in a pass where the socket being filled is unheld —
   and it costs one comparison to have something fire loudly if that keying is
   ever broken again, which is the defect's own shape.

Freeing a marker also became harder in two ways. It needs the socket's own
mapblock to be **active** — `core.compare_block_status(pos, "active")`, which is
the question the old "a player within 24 nodes" was approximating, and which a
forceload answers as well as a player does — and `FREE_STRIKES` = 3 consecutive
passes must agree, because one empty answer is not proof that an NPC is gone.

With that, neither trigger asks about players at all any more. What a pass may
do is decided per socket by the map: loaded allows a placement, active allows a
free. The old `if #players == 0 then return end` made both the retry and the
re-check dead code on a server nobody was logged in to — which is also every
engine probe.

### 2. Stuck patrols

Mostly a consequence of item 1 (groups of twins walking into each other), but a
route is a direction and not a path, so `patrol.lua` gained a three-stage
rescue, opt-in per caller (`route_tick(..., rescue)`; the start and capital watch
passes true, the named rares keep the plain nudge):

| after | stage |
| --- | --- |
| 20 s without progress | ask `core.find_path` and steer at its first node |
| 45 s without progress | give the waypoint up, take the next one |
| 90 s stuck in total | teleport onto the waypoint — **only** with no player within 48 nodes (the user's ruling) |

Two clocks are what make that an escalation: the skip **lowers** the first one
(a grace period, not a fresh timeout) and only real progress clears the second.
The post guard's walk home uses stages 1 and 3 of the same helpers — a post has
no next waypoint to skip to — and lands exactly on its authored socket.

### 3. Villagers did not wander

The cause was the ring advance, not the timers. It walked the ring looking for a
**free** spot and fell back to its own index when it found none — and with four
villagers standing on four spots, every candidate is always taken. So every
villager re-rolled its dwell where it stood, for ever. The user saw them stand
in front of their houses and move once (the one time another villager happened
to be in transit).

The occupancy test may now only ever **skip** a candidate; when all of them are
taken the villager still advances by one. Advancing in step is what keeps four
villagers on four sockets spread out, which is what the original comment said
and what the fallback undid. Alongside it: the dwell is 20–60 s as specified,
and the dwell in progress when a mapblock activates is capped at 20 s, so the
wait a player sees on walking in is bounded by that and not by the whole roll. A
villager that cannot reach its spot for 15 s takes another one instead of
pushing (it has neither a pathfinder nor, since item 6, a jump).

### 4. Facing at doors

A socket's `dir` is measured at the feature it stands on, which for a doorstep
means the NPC showed the street its back. The **consumer** turns a door-tagged
idle socket round (`socket_face_yaw` in `start_npcs.lua`), so the blueprint data
keeps meaning one thing and no future composition can forget the rule. Sockets
are not identity bytes, so editing the seven socket tables would have been legal
too — it would have been ~30 entries and one more thing to get right per new
settlement.

### 5. Hostile mobs targeted NPCs

`attack_npcs` defaults to **true** in mobs_redo's `mob_class` (api.lua:170) and
is read in exactly one place, general_attack's candidate filter (api.lua:1814).
guard.lua set it false; the eighteen hostile families did not, so a boar stood
in front of an invulnerable villager hitting her for as long as anyone watched.

`grug_mobs.no_npc_targets` (verbs.lua) is now applied by
`grug_mobs.register_mob` to **every** def, before the `no_acquire` derivation
and before mobs_redo copies the field. The exception is explicit and named after
world.md §4's own: `_grug_attack_npcs = true` for a dedicated war-front unit.
Nothing else changes — `attack_players`, `attack_animals` and `attack_monsters`
stay as the def wrote them, so guards still fight monsters, and a punched
monster still retaliates against the guard through on_punch's own
`do_attack(hitter)` (api.lua:3208-3213), which consults `passive`, `state`,
`child` and ownership but never any `attack_*` field.

**It does change who starts a guard-versus-monster fight, and that is
deliberate.** A guard is `type = "npc"`, so bandits, mirefolk and every other
hostile family used to acquire one on sight; from now on they do not. Guards
still acquire them (`attack_monsters = true`) and a monster a guard hits fights
back for as long as the fight lasts, so a bandit camp beside an outpost no longer
walks into the watch on its own — the watch is what opens hostilities. That is
world.md §4's "ordinary guards attack enemy players and monsters, never arbitrary
NPCs", read from the other side.

### 6. Perpetual jumping

`walk_chance = 0` means "mobs_redo's own wander is off" to us. Inside
`do_jump` it means **"this is a jumping mob"**: api.lua:1131 reads
`if (not blocked and ...) or self.walk_chance == 0`, i.e. the villagers took the
jump branch unconditionally. `do_jump` runs four times a second from `on_step`
and skips only a mob whose vertical velocity is non-zero, so every villager
hopped again the instant it landed, for the whole length of every walk, with
`jump_height = 4` and the `core.after(0.3, set_acceleration{y = 0})` that
follows a jump in the same function. In Highcourt's core, where the idle spots
are further apart, that is most of a villager's life.

Both flair families now carry `jump_height = 0`, which is the gate at
api.lua:1114 — `do_jump` returns before the jumping-mob clause. `jump` itself is
not a field mobs_redo reads at all (it is in no def whitelist and nothing in
api.lua consults it) and is kept `false` only so the def does not claim the
opposite of what it does. Guards keep `jump_height = 4` and are unaffected: they
have the default `walk_chance` of 50, so they only jump when there is a solid
node in front worth hopping onto, and a guard that loops instead of climbing is
now caught by item 2's rescue.

### 7. Nametags per settlement

There is one villager entity per **race** and it serves that race's start *and*
its capital, so a name read off the race put "Dawnmere Farmer" in the middle of
Highcourt. `grug_mobs.settlement_npc_name` answers per settlement: the six
starts keep the flavour names they shipped with (a race has exactly one start,
so those are settlement names already) and every other settlement is named after
itself — "Highcourt Citizen", "Highcourt Elder" — derived from the key, so the
next capital needs no edit.

The name is resolved once, by the placement, and persists with the entity. It
needed one extra call: `core.add_entity` activates an entity synchronously, so
`after_activate` has already run by the time `install` writes the field, and
`place` therefore re-asserts the nametag (`grug_mobs.start_npc_retag`) exactly
as it already re-asserts the facing.

### 8. "Elite Accord Guard [Lv 60] 945/10"

`hp_max` is in mobs_redo's `is_property_name` table (api.lua:3297-3301), so
`mob_activate`'s staticdata loop writes it to the **object** and never back onto
`self` (api.lua:3327-3332). Two consequences, and the second is the defect:

1. `self.hp_max` is nil for the whole of every activation after the first, so
   the nametag and aggro.lua's leash heal fall back to the property;
2. the **next** save therefore carries no `hp_max` at all (`clean_staticdata`
   serializes the fields that exist), and the activation after *that* keeps
   `initial_properties.hp_max`, which for a def that sets none is mobs_redo's
   own default of **10** (api.lua:3647). A level-60 elite then reads 945/10 and
   its first damage is clamped to 10 by check_for_death's "make sure health
   isn't higher than max" (api.lua:849).

Two reload cycles, which is why it looked random. Fixed where the maximum is
owned rather than in the vendored api.lua: `ensure_init` re-derives it on every
activation that finds the mob already levelled (`reassert_max` in levels.lua).
The level and tier are persisted plain fields, so the derived max is a pure
function of what came back; health is left alone except that a value above the
max is brought down, so a wounded mob stays wounded across a reload.

### What the review of this round found

The independent review of 2026-09-15 verified all eight fixes and asked for four
changes. All four are in; the first is the interesting one.

1. **`socket_seeable` guarded the wrong mapblock.** The strike rule asked whether
   the SOCKET's block was active, and `compare_block_status` answers for the
   block containing the position it is handed
   (`ServerEnvironment::getBlockStatus`, serverenvironment.cpp:1159-1172) while
   `active_block_range` defaults to four blocks = 64 nodes. Highcourt's ring loop
   spans about a hundred, so a player at the south gate leaves the north-west
   patroller's own block inactive: no claim, three passes, marker freed, a fresh
   full-HP guard placed — and the original removing itself on reactivation. The
   starts are immune (their loops are ≤ 58 nodes across) but a capital is not.

   The engine distinguishes the two cases and we now ask it:
   `on_deactivate(self, removal)` fires with `removal = false` when a mapblock is
   unloaded and `true` when the object is removed. The unload case records the
   position the NPC went out of memory at — a block that is inactive by
   construction at that moment — and the socket is struck only once **that** block
   is active again, because an NPC still on disk comes back with its own block. A
   `/clearobjects` leaves no such record (`mode = "full"` calls no callback at
   all) and keeps the socket's own block as the whole test. The hook is installed
   on mobs_redo's shared `mob_class`, which defines none of its own: one hook for
   all five families, no patch to a vendored file.

   Under it, `start_npc_claim` decides a contest over one socket by **age**
   (`_grug_placed_at`, stamped by `install`) instead of by which entity activated
   second. So even a strike that does misfire costs a transient spare and never
   the wounded original.

2. **A loop nobody can walk is terminal.** After three reported give-ups the mob
   says once that it is going quiet and keeps trying in silence, and a refused
   teleport is retried every 10 s instead of on every tick (`snap_try`). With
   every waypoint unreachable AND a player inside 48 nodes, the first version
   logged a line and called `get_objects_inside_radius` once a second for as long
   as the player stood there.

3. **The probe's population assertion was one-sided** — it failed only on
   `live > roster`, so a run that read `live = 0` passed. Every terminal phase is
   strict now: `live == roster`, `marked == roster`, and no two NPCs sharing a
   socket.

4. **Evidence wording and coverage**: the 79/115 wound is marked incidental and
   no longer implies a pre-fix run that was never made, Highcourt's `new` split is
   marked as one run's, the README no longer calls fifteen real `os.exit` calls
   "prose", and `files.sha256(.sh)` freezes the round's bytes. world.md §4 gained
   the sentence that no mob initiates against NPCs except war-front units, and
   item 5 above now says plainly what that changes for bandits and mirefolk.

Two notes the review left as information, not changes: `standing_y` takes the
topmost valid cell within +4 of the mob, so an out-of-sight snap can land on a
structure above the waypoint; and the 48 nodes are a radius, not line of sight,
which is the user's ruling as given.

### Verification

- **KAT pair, byte-identical.** `tools/wp13/start_npcs_kat.lua` now drives four
  production files against the stub engine — `patrol.lua`, `verbs.lua`,
  `start_villagers.lua` and `start_npcs.lua`, in init.lua's own order — through
  seventeen report rows: the six states it had, plus the door flip and the
  settlement nametag (items 4 and 7), the wanderer, the out-of-range NPC and the
  twin healing (item 1 and the review's finding on it), the census, the amble and
  a blocked villager (item 3), the no-jump gate (item 6), the three-stage stuck
  rescue including the out-of-sight ruling and its terminal state (item 2) and
  the NPC-targeting verb (item 5).

  The stub models the whole activation edge, because that is what the design
  hangs off: an object exists only while its own block is active,
  `get_objects_inside_radius` and `get_pos()` both answer accordingly,
  `core.add_entity` creates an ACTIVE object even where no player is, a restart
  activates only what a player is near, and `on_deactivate` is dispatched with
  `removal = true` for a removal and `false` for an unload — through mobs_redo's
  shared `mob_class`, exactly as the engine dispatches it. The `out_of_range` row
  fails against the pre-fix predicate, which is what makes it a regression test
  rather than a tautology. The mobs the behaviour rows drive are the entities the
  placement engine placed in the same process, so the amble runs on the fields
  `install` really wrote rather than on a hand-built table.
- **`tools/wp13/final_micro.lua` pair**, LuaJIT and `tools/bin/lua51`,
  `LC_ALL=C`: output_sha256
  `4f2d2b769578c00bd9947a5904dd4f1635fae0e2503420f990a585f7841cbdf5` from both,
  with this round rebased onto `d2538b9`. Three groups of rows moved against the
  seam round's `871f0d29…`: this round's own KAT report, and — from main, not
  from here — the new `highcourt_throne` row and Highcourt's identity
  (`187f79e0…`), both of which arrived with the throne lane. The six start
  identities are untouched in it.
- **Static gates** (`static.txt`): `luac51 -p` per touched file and over the
  whole tree, the SETGLOBAL count (17 grug mod writes, one table per mod), the
  five plain-5.1 sweeps scoped to the touched files, to `mods/*/grug_*` and to
  `tools/wp13` — every hit pre-existing prose in a comment — and
  `check_fresh_server.py` PASS.
- **Six-start identities unchanged**: `start-identities.txt` is byte-identical
  to the committed `20260914-capital-parts/start-identity.txt`. This round
  writes no mapgen cell.
- **Engine**, `tools/wp13/run_npc_probe.sh` (three boots on ONE world through
  `tools/luanti_headless.sh`, the disposable probe of `tools/wp13/npc_probe`
  staged with the launcher's new `PROBE=`): see the table below.
- **Engine**, `tools/wp13/run_highcourt.sh` once: the capital pass, zero ERROR
  and zero ModError, its avenue digest unchanged.

### Engine results

`tools/wp13/run_npc_probe.sh`, seed 531802985935182545: three boots on ONE world
through `tools/luanti_headless.sh`, with the disposable probe of
`tools/wp13/npc_probe` staged by the launcher's new `PROBE=`. Zero ERROR and zero
ModError in all three logs.

Every census counts Hearthpine's NPCs **by identity out of the map**
(`_grug_start` on an activated entity), not out of the placement log, and the
probe logs an error if that count ever exceeds the roster.

| | boot 1 (fresh world) | boot 2 (same world) | boot 3 (same world) |
| --- | --- | --- | --- |
| Hearthpine placement line | `guards 3/3 flair 4/4 vendor 1/1 quest 1/1 new 9 pending 0` | `… new 0 pending 0` | `… new 0 pending 0` |
| all six starts | 54 placements, i.e. the whole roster once (plus one for the socket cleared below) | none | none |
| census roster/marked/live/twins | 9/9/9/0 | 9/9/9/0 | 9/9/9/0 |
| guard HP tuple | `self_hp_max=115 prop_hp_max=115`, tag `… 115/115` | the same, and `79/115` for the one the wolf wounded | the same again, still `79/115` |

Boot 1 additionally, in order:

- **Item 3.** `event=pos` every ten seconds for three minutes: all four villagers
  walk between their idle sockets, dwell there and rotate through the spot
  indices. Two of them standing next to each other for a while is expected —
  with four villagers on four sockets every candidate spot is occupied, so the
  ring advance takes an occupied one, the collision box stops the walker about a
  node short, and they separate again as their dwells run out. A frozen village
  was the defect; a pair of villagers standing together is not.
- **Item 1, the false free.** All nine NPCs moved 40 nodes off their sockets,
  then sixteen more heartbeats: `live=9 twins=0` at every census and not one
  "marked but empty" line. Before the fix that state produced one twin per NPC
  per heartbeat.
- **Item 1, the real free.** One villager then removed outright (`mobs:remove`,
  what `/clearobjects` does to a whole settlement). Five seconds later:
  `marked=9 live=8` — one empty pass is not proof. Twenty-five seconds later:
  exactly ONE `socket idle_forge_door is marked but empty` warning, exactly one
  `placed at socket idle_forge_door`, and `live=9` again. This is also where
  `core.compare_block_status` is exercised against the real engine.
- **Item 8.** `self_hp_max` and the object property agree at 115 on all three
  boots. Incidentally — the wolf below wounded one of them — the `watch_gate`
  guard comes back as `79/115` on boot 2 and again on boot 3: **a wound survives
  two reloads with the maximum intact.** That is the tuple the lost `hp_max`
  corrupts, by the two-save sequence described above; this round did not run the
  pre-fix code to watch it corrupt, and the number is incidental rather than
  arranged. The injection instead makes the defect's exact state on purpose
  (`self.hp_max` nil, the object back on the definition default of 10) and the
  activation path puts both back to 115 in the same tick. 115 is the level-20
  guard-field value at a start; the user's 945/10 was a capital's level-60 elite,
  which is the same arithmetic on a bigger number.
- **Item 1, the review's finding.** One villager then moved OUT of the
  forceloaded grid, so its own mapblock goes inactive while the socket it is
  booked on stays active — `compare_block_status` answers for the block
  containing the position it is handed, and those are two different blocks. The
  probe logs both answers to prove the premise, then asserts the consequence at
  ten and at forty seconds: `live=8 marked=9`, i.e. the NPC is out of the
  environment and its marker is untouched. Forceloading its block brings it
  back and the census returns to 9/9. Against the pre-fix predicate the same
  state freed the marker and placed a fresh guard.
- **Item 5.** A wolf two nodes from a villager: `attack_npcs=false`,
  `target=nil` and its full 65 HP at every observation — it never acquires the
  NPC next to it. A wolf two nodes from a guard post, three seconds in:
  `guard … state=attack target=grug_mobs:wolf` and `wolf … state=attack
  target=grug_mobs:guard_accord health=55`, i.e. the guard acquired it and it hit
  back; 35 HP at six seconds, dead by fifteen.

One artefact of the probe worth knowing when reading `probe.txt`: the `ready`
census can report `live=0`, because it fires in the same globalstep as the
forceload while the engine's active-block management runs on its own two-second
interval. Nothing is activated yet at that instant — which is also exactly why
the free path cannot misfire there: `compare_block_status` answers "loaded", not
"active", until the pass that activates the block activates its objects too.

`tools/wp13/run_highcourt.sh` once, on the same seed: zero ERROR, zero ModError
and the built avenue's digest equal to the committed value for that seed
(`9d6f0167…`, 1595 road cells). Its NPC line is **better** than the seam round's,
and for a reason worth recording:

| | seam generalisation (2026-09-15, morning) | this round |
| --- | --- | --- |
| Highcourt | `guards 17/19 flair 30/49 vendor 2/2 quest 1/1 new 50 pending 21` | `guards 19/19 flair 49/49 vendor 2/2 quest 1/1 new 12 pending 0` |

**Neither `new` number is a gate**, and `new 12` is this one run's split: both
depend on which mapblocks the emerge sequence happened to have loaded when the
anchor first answered, exactly as the seam round said of its own. The right-hand
column is the reproducible part and the point — **pending 0**. The heartbeat does
not wait for a player any more, so every socket whose node is loaded is filled on
the next beat instead of waiting for somebody to walk up to it, and this probe
has no player in it at all.

### Runtime test for the user (round 1)

Fresh world, seed `531802985935182545`, any race; `tools/sync_to_luanti.sh` first.

1. Stand in a start for five minutes. There are exactly nine NPCs and they stay
   nine — no growing crowd of guards, and no twin appearing on a spot somebody
   has just walked away from.
2. Watch the villagers: within twenty seconds one walks off to another spot at
   walking pace, and **nothing hops**. The one on a doorstep faces the street.
3. Follow the patrolling guard round its loop twice. It keeps going; if it ever
   wedges itself it paths round, then takes the next waypoint, and it is only
   ever moved outright while you are more than 48 nodes away.
4. Lure a boar or a wolf into the settlement. It ignores the villagers
   completely; the guards go for it and it fights them back.
5. Go to Highcourt. Its villagers are "Highcourt Citizen" and its elder
   "Highcourt Elder", nobody in it is a "Dawnmere Farmer", and nothing jumps.
6. Frame an elite guard at a capital (level 60): the health reads `945/945`.
   Restart the server twice and look again — still `945/945`, and the first hit
   takes it to 935 rather than to 9.
7. `/clearobjects` on the arrival plaza, then wait fifteen seconds: the sockets
   whose mapblocks you are keeping active report "marked but empty" once each and
   refill once each.

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
   mouse button does not spam the chat. Watch one for a minute: within twenty
   seconds of your arrival it walks to another of the four spots at walking pace
   — never hopping — and stands facing it. The one at a doorstep looks out into
   the street, not at the door.
4. Right-click the elder beside the hall: a nametag and one placeholder line, no
   formspec.
5. Right-click the Quartermaster on the plaza: the normal trade window, with the
   same-race discount.
6. Kill one gate guard (creative, or an enemy character). The post stays empty
   for three to six minutes and is then manned again, once — not twice.
7. Leave and rejoin, then restart the server and walk the same settlement: the
   same nine NPCs, in the same places, facing the same way, each wearing its
   race's skin rather than a guard's. None of them is doubled.
8. `/clearobjects` while standing on the arrival plaza, then wait three
   heartbeats (~15 s): the sockets whose mapblocks you are keeping active report
   "marked but empty" in the log and are filled again; walk to the gate and the
   posts there fill as you arrive. Three passes have to agree before a marker is
   freed, so a guard that is merely away on patrol never triggers it.
9. Take an enemy-faction character to another race's start: the gate guards
   attack; with an own-faction or a brand-new factionless character they do not.
