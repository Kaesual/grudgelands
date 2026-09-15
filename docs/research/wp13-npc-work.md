# WP13 round 3: settlement work, the 80/20 split and profession vendors

Status: shipped 2026-09-15 on `wp13-r3-npc-work`, based on main `19abee02`.
Implements section 8 of `wp13-npc-sockets-contract.md` (the user's playtest
round-3 rulings) plus the nametag finding of the same playtest.

## 1. What the user reported and what it turned into

> "Nobody does anything, and I want lived-in settlements without paying for it
> in server load."

and, separately,

> the nametags of peaceful NPCs are readable much further away than a guard's,
> which makes a busy district a wall of floating names.

The rulings are the contract's section 8: guards always patrol (unchanged);
residents are about 80 % static at a workplace with an activity animation and
about 20 % walkers on short routes; the activity vocabulary is closed;
`vendor.kind` grows by five professions. This lane owns the behaviour, the
animations, the wielded items, the walker selection and its bound, the
profession entities and their stock, the first `work` sockets in the six
starts, and the load measurement.

## 2. The `work` role

One resident per `work` socket, and it is the SAME villager entity per race —
`grug_mobs:villager_<race>` — because what a resident does comes out of the
socket's `activity`, not out of a family. That keeps the nametag rule, the
non-combatant flag, the claim registry and the marker machinery exactly as they
were; the placement engine gained a resolver and two fields.

`start_villagers.lua`'s `resident_tick` routes on one plain field: a resident
carrying `_grug_work_activity` runs the work tick, everybody else ambles.

### 2.1 Animations, read off the mesh

The ranges are `mods/BASE/player_api/init.lua`'s own registration of
`character.b3d`, and `start_npcs_kat` re-reads that file and compares, so a
range that drifts fails rather than putting a villager in a frame nobody
authored:

| key | frames | used for |
|---|---|---|
| `stand` | 0–79 | `pray`, `stall`, and the rest pose of `fish` / `tend` |
| `sit` | 81–160 | `sit` |
| `walk` | 168–187 | `sweep` |
| `work` | 189–198 at speed **10** | `smith`, `farm`, `chop`, and the swing of `fish` / `tend` |
| `punch` | 189–198 at speed 30 | unchanged; a villager never reaches it |

`work` is the mesh's `mine` swing at a third of the player's 30 fps. That is
what turns a punch into a hammer blow, a hoe stroke and an axe swing — the same
frames at fighting speed read as a fight.

### 2.2 The activity table

| activity | animation | wielded item | note |
|---|---|---|---|
| `smith` | `work` loop | `default:pick_bronze` | the contract's "hammer or pick" |
| `fish` | `stand` + swing | `default:stick` | section 8.2 explicitly allows a stick |
| `farm` | `work` loop | `default:shovel_stone` | **there is no farming mod and therefore no hoe**; the shovel is the closest tool this vocabulary has |
| `chop` | `work` loop | `default:axe_stone` | |
| `tend` | `stand` + swing | none | |
| `pray` | `stand` | none | |
| `stall` | `stand`, facing the counter | none | |
| `sit` | `sit` | none | |
| `sweep` | `walk` along a two-node line | none | the only activity that moves |

"Swing" is two seconds of the `work` animation every ten. The tool goes through
the character-visuals wield seam (`grug_visuals.apply_entity`'s `weapon`
field) — the same path a guard's sword takes, so the bone attachment and the
transform are the visuals lane's and not a second copy.

A load-time audit reports the four tools, and names any that the registry does
not have: an unregistered item draws nothing at all through the wield seam, so
without the audit a renamed tool would be a smith swinging an empty fist that
nothing complained about.

### 2.3 Three things make it cheap, and all three are measured

1. **No path-finding, ever.** A static resident has no destination. `sweep`
   walks a straight two-node line with `walk_toward` and no rescue. The KAT
   counts `core.find_path` calls over 120 simulated seconds (0) and the engine
   load probe counts them over a 30-second window per start (0).
2. **One property write per change.** `mob_class:set_animation` returns without
   touching the object when the animation asked for is already the current one
   (api.lua:461), so a hammering smith writes its animation **once for the life
   of its activation** — the KAT measures 1 write in 120 s — and a swinging
   `tend` resident writes 6–7 in 30 s.
3. **Nothing at all while nobody is watching.** Beyond 24 nodes from the
   nearest player (the vendor presence poll's own `PLAYER_RANGE`) the tick sets
   the velocity to zero once and returns. The distance comes from the single
   cached player snapshot `levels.lua` already refreshes once a second for the
   whole mob population — no second global accumulator.

And the tick returns exactly `false`, which is what holds the whole thing
together: mobs_redo skips the rest of `on_step` on that answer (api.lua:3595),
so `do_states` never runs — and `do_states` in the stand state calls
`set_animation("stand")` once a second (api.lua:2133), which would overwrite
the activity within a second of it being set. The same veto skips
`general_attack`, `breed` and `follow_flop`, which for a non-combatant with no
follow list is pure saving.

## 3. The 80/20 split

Nothing is authored. Among a settlement's resident spawn sockets in **authored
order**, every fifth `idle` spawn socket starting with the first hosts a
walker; every `work` socket and every other `idle` socket hosts a static
resident. Spares (`spawn = false`) are not residents and take no place in the
count — counting them would shift every later socket's parity for a reason that
has nothing to do with who lives there.

The decision is written onto the entity as a plain boolean (`_grug_walker`), so
it survives unload/reload and no activation re-derives it.

### 3.1 The walker bound: 20 nodes, measured

Contract section 8.3 leaves the bound to this lane and asks for it to be
measured and stated. **20 nodes, horizontal, around the resident's own socket.**

Measured from the six starts' authored socket tables. Hearthpine's walker
stands at `idle_west_door` (-16, 4); the distances to the other idle spots of
its composition are

| target | nodes |
|---|---|
| `idle_spare_2` (-8, 9) | 9.4 |
| `idle_workyard` (-19, 17) | 13.3 |
| `idle_spare_3` (-6, -13) | 19.7 |
| `idle_forge_door` (2, -10) | 22.8 |
| `idle_plaza_bench` (7, 1) | 23.2 |
| `idle_spare_1` (7, 9) | 23.5 |

so a bound of 20 leaves three destinations around the walker's own socket and
cuts the two cross-settlement marches. The other five starts sit in the same
9–24 band. A resident ALWAYS keeps its own socket in the ring whatever the
radius says, so a ring is never empty; a ring of one is a resident that stands
still, which is legal.

Two ring shapes, and the difference is the split itself:

* a **walker** gets every spot within the radius, homes and spares alike — the
  round-1 amble with a leash on it, dwell 20–60 s;
* a **static** resident gets its own socket plus the **spares** within the
  radius, dwell 180–420 s. That is the user's "at most a rare short hop", and
  restricting it to spares is what stops the hop being a trade of doorsteps
  with the neighbour.

The first-activation dwell cap (which bounds the wait a player walking in has
before anything moves) is now a **walker's** only: a static resident standing
at its door for its first three minutes is the behaviour, not a wait, and
capping it made every static resident hop the moment its minimum ran out.

### 3.2 The share per start

Each of the six starts has four `idle` spawn sockets, three spares and — new
here — two `work` sockets. So per start:

* residents 6 = 4 idle + 2 work
* walkers 1 (the first idle spawn socket in authored order)
* **share 16.7 %**, inside the contract's 10–30 % band.

The KAT fixture carries six idle spawn sockets and two work sockets, so it
shows the stride as well as the first pick: walkers are the 1st and the 6th,
residents 8, share 25.0 %.

## 4. Where the work sockets are

Two per start, at features that already exist. **No cell moves**, and
`tools/wp13/evidence/20260914-capital-parts/start_identity.lua` reports the six
identity SHAs unchanged (see the evidence directory).

| start | socket | activity | stands at |
|---|---|---|---|
| hearthpine | `work_woodpile` (-12, 1, -13) | `chop` | the pines above the lane |
| hearthpine | `work_garden` (-19, 1, 21) | `tend` | the tufts north of the workyard |
| dawnmere | `work_field` (18, 1, 31) | `farm` | the first tilled row, inside the fence |
| dawnmere | `work_green_seat` (-5, 1, 15) | `sit` | the green's bench walk |
| silverleaf | `work_planters` (4, 1, 11) | `tend` | the fern bed north of the court |
| silverleaf | `work_market` (-33, 1, 5) | `stall` | the covered market's slate counter |
| stillgrave | `work_gravewood` (10, 1, -6) | `chop` | the gravewood by the lane |
| stillgrave | `work_blightbed` (-22, 1, -8) | `tend` | the blighted bed west of the court |
| sunscar | `work_forge` (-34, 1, 2) | `smith` | the open anvil west of the muster yard |
| sunscar | `work_acacia` (-14, 1, -1) | `chop` | the acacia on the north lane |
| kapok | `work_jungle` (-29, 1, 13) | `chop` | the jungle edge west of the lodge |
| kapok | `work_terrace` (-16, 1, 24) | `sit` | the lodge terrace |

Two activities the brief named are deliberately absent, and the reasons are
geometric rather than editorial. **`smith`** needs an anvil OUTSIDE a room,
because a socket is never inside one; only Sunscar has an outdoor anvil
(Dawnmere's three stand inside the smithy). **`fish`** needs a water node, and
no blueprint may contain water at all — `blueprint_kat` refuses every water and
lava cell outright, so the river is generated terrain outside the pad and a
fishing socket would be authored against something the composition cannot
promise. **`pray`** wants a chapel interior, which is the same indoor problem.
If the user wants a fisher on the Kapok bank, the honest way is a contract
change: either a `fish` socket whose feature test looks at the terrain rather
than the blueprint, or a water feature authored into the pad.

`blueprint_kat` holds a `work` socket to every rule an `idle` socket obeys and
adds section 8.1's feature check: the activity must come from the closed
vocabulary and the node that activity names must stand within three nodes of
where the socket looks. The feature vocabulary is per start (a pine log is not
an acacia log), and `farm` searches the GROUND course, because a field is what
you stand on rather than what you stand in front of.

**The search stops at the first obstruction**, and that clause was earned
rather than designed. The first `work_garden` stood a gardener one node east of
a pine trunk with the grass it was to tend two nodes BEHIND the trunk; the test
passed and the engine probe then showed a resident that could not walk back to
its own spot. Testing the obstruction at the socket's own course, after the
feature test at that reach, immediately caught two more: Dawnmere's farmer was
on the lane outside the fenced strips, and Silverleaf's gardener was looking
through the court furniture. All three moved; the table above is the corrected
one.

### 4.1 A displaced resident walks home

A static resident is defined by standing on its socket, and things move an NPC:
a knockback, an admin teleport, the probe's own wanderer phase. The first
engine run found exactly that — the walkers came home and the work residents
stood in a field through two reboots. The work tick now walks home when it is
more than 1.2 nodes off, with `walk_toward` and **no pathfinder**, and with
patrol.lua's out-of-sight snap after thirty seconds without measurable progress
as the last resort (the stall clock rather than the total, because what stops a
resident is an obstacle it oscillates around and oscillation resets a total).

The walk home is the one part of the tick that is NOT gated on a player being
near: the correction has to have happened before the player arrives. It costs
one squared distance per second. The unwatched branch stops with the stand
animation, so a resident that has just walked home does not jog on the spot for
somebody watching from beyond the 24-node watch radius and inside the engine's
much wider object-send range.

## 5. Profession vendors

`grug_traders` registers five: butcher, smith, fishmonger, baker, tailor.

**One entity per profession, not one per race.** A profession is a shop, not a
faction or a race perk, so a profession vendor carries neither `faction` nor
`race` — which is exactly what `can_trade` and `has_discount` already read, so
both keep working without a line of change (everybody may trade; nobody gets
the kinship discount). It is **drawn** as the race of the settlement it stands
in, resolved from the settlement key the placement engine wrote, so one butcher
entity is a dwarf in Hearthpine and an orc in Sunscar.

Shelves are built only from items the game already registers (section 8.4):

* butcher — raw and cooked meat, `mobs:leather`, light and heavy leather, tusk
* fishmonger — raw fish, scaled hide, crocodile tooth, stormkelp
* baker — corn, potato, melon, mushroom (WP33's gathering catalog)
* tailor — the linen/heavy-cloth/spider-silk line plus white and brown wool
* smith — bronze, iron and steel bars plus the below-ladder bronze tools

**Only the smith keeps the gear bracket tabs.** `items_crafting.md` §3.0.3
makes the vendor bracket catalog and the base craft ladder the same items, so a
smith that listed the ladder on its own shelf would be a second copy of it; and
a baker is not on that ladder at all. The other four show one tab.

A load-time audit drops any shelf entry whose item is not registered and logs an
error naming it — an unknown item renders as a buyable "unknown item" button in
the trade formspec, which is the failure mode `stock.lua`'s own header warns
about.

The six starts get no profession socket: the Highcourt fill lane places those.
What this lane proves in the engine is that the five entities exist and their
shelves survived the audit with offers on them.

## 6. The nametag proximity gate (the second round-3 finding)

Combat mobs and guards were culled at 25/30 m by `levels.lua`'s
`tag_gate_tick`. Villagers, elders and vendors wrote a **static** nametag
property once at activation, and the engine has no distance cull of its own, so
their names rendered out to the ~128 m object-send range. The cause was not a
different range but the absence of one.

`levels.lua` now offers the same gate to a caller with a static text
(`grug_mobs.plain_tag_gate_tick(self, text)`): the same 25/30 m hysteresis, the
same single cached player snapshot, exactly one `set_properties` per state flip
and none in between. The three families keep the desired text in a plain field
(`_grug_tag_want`) and mobs_redo's own `update_tag` calls now refresh that
field and touch no property, so a rename while the tag is hidden costs nothing
and the rising edge writes whatever the text is by then —
`grug_mobs.start_npc_retag` keeps working unchanged.

Slots: the villager's amble and work ticks already ran once a second. The elder
gained a tick for no other reason, and so did the vendor; both return `false`,
which for mobs with zero velocities and no targeting was already a no-op step.
The vendor definition also **lost its `nametag` field**, because mobs_redo
copies it onto the object at activation and it would put the tag back on screen
at 128 m on every reload until the gate's next tick took it off.

`grug_mobs.nearest_player_d2` is published and the gate calls it through the
table, which is what lets the engine probe substitute the distance source: a
headless server has no client to connect and therefore no connected player,
while the property write is exactly the thing that has to be measured.

## 7. Measurements

### 7.1 Load, before and after

`tools/wp13/run_npc_load.sh` boots the game once, walks the six starts one at a
time (forceload the arrival, settle 8 s, measure 30 s, release) and reports per
start: the active mob count, `core.find_path` calls per minute, the mean and
worst server step, and a direct microbenchmark of the mod-side tick.

The mean server step is 90 ms before and after, and that number is not a
measure of the NPCs: a dedicated server runs a **fixed** step
(`dedicated_server_step`, 0.09 s) and only exceeds it once it cannot keep up.
It says there is headroom, which is worth knowing. What measures the NPCs is
the microbenchmark: every settlement NPC's `do_custom` called once per
simulated second inside `core.get_us_time()`, which is exactly the work the
server does for it.

The numbers are in `tools/wp13/evidence/20260915-npc-work/`
(`load-before.txt`, `load-after.txt`).

### 7.2 Behaviour, in the engine

`tools/wp13/run_npc_probe.sh` (three boots on one world) gained the round-3
claims: work residents stand on their sockets with no wander ring, carrying
their activity, animation and tool — on a fresh world and again after a reboot;
the nametag property is empty at 40 m and the right name at 20 m for a
villager, an elder and a vendor; the five profession shelves have offers. R2's
wander verdict is split — a walker must reach a second spot, a static resident
must reach none.

### 7.3 Fixtures

`tools/wp13/start_npcs_kat.lua` gained six states (the split by socket and its
share, a static resident standing still, the work resident, the animation
ranges against `player_api`'s own file, the closed vocabulary and its tools,
and the gate being reached once a second by all three families). Identical
output under `luajit` and `tools/bin/lua51`.

## 8. What the review should look at

* **The `do_custom` veto.** A work resident and an elder now return `false`
  from `do_custom` on every step. That is deliberate and load-bearing (section
  2.3), but it also skips `general_attack`, `breed`, `follow_flop`,
  `do_runaway_from` and `do_stay_near` for those entities. All five are no-ops
  for a non-combatant with no follow list and no breeding — worth a second
  pair of eyes on that claim.
* **The walker share is a settlement-wide property.** The KAT and the load
  probe assert the 10–30 % band on the six starts and on the fixture. A capital
  whose composition ends up with many `work` sockets and few `idle` spawn ones
  can fall below 10 % under the contract's own rule, because the rule counts
  fifths of the IDLE sockets while the share is measured against ALL residents.
  Nothing asserts it for Highcourt or Dur Brannoc today. Flagged for the
  coordinator rather than fixed here: changing the rule is a contract change.
* **`grug_visuals.apply_entity` stores an ObjectRef** (`_grug_wield_obj`) on
  the entity. That is the visuals lane's existing design and every guard
  already goes through it; the work residents are simply more users of it.
* **The profession vendors' skin** is resolved from the settlement key at
  activation. An entity placed by something other than the settlement socket
  engine (nothing does today) would fall back to the Accord founding race.

## 9. What is open

* No `fish` and no `pray` socket anywhere yet, for the geometric reasons in
  section 4. Both need either a contract change or a composition that authors
  the feature.
* `farm` wields a stone shovel because the game has no hoe. When a farming
  item lands, one line in `ACTIVITY` changes and the startup audit is what will
  have said so.
* Profession vendor **sockets** are the Highcourt fill lane's; this lane ships
  the entities and the shelves, and no settlement places one yet.
* Renders: the headless server cannot draw a frame, so there is no screenshot
  of a hammering smith. What is documented instead is the exact frame range,
  speed and wielded item per activity (section 2), and the engine probe reads
  the animation mobs_redo actually wrote onto each work resident's object.
