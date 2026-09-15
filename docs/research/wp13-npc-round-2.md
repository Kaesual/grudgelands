# WP13 playtest round 2 — settlement NPC behaviour (2026-09-15)

Lane 2 of WP13 round 2. The user played the round-1 build in the GUI and gave
three rulings; this note records what shipped against each, what it cost and
what is still open. The decided design lives in
[settlements.md](../design/settlements.md) ("Settlement NPCs and guard
targeting", "Capitals in the world") and [world.md](../design/world.md) §4; the
seam is [wp13-npc-sockets-contract.md](wp13-npc-sockets-contract.md) §§2, 5–7.
Round 1 is [wp13-start-npcs.md](wp13-start-npcs.md) "Playtest round 1".

## 1. The three rulings, and what each one turned into

### 1.1 Combat: hostiles and guards may fight, civilians are never a target

Round 1 answered "a boar stands in front of a village woman hitting her for
ever" by giving **every** mob `attack_npcs = false` in
`grug_mobs.register_mob`. That bought the villagers their peace and paid for it
with the only NPC-versus-monster fight the settlements have: a wolf at the gate
could no longer acquire the watch at all.

The user's ruling splits the two. What shipped:

- `grug_mobs.no_npc_targets` is **gone**, and with it the blanket narrowing in
  `register_mob`. A hostile keeps mobs_redo's own default (`attack_npcs = true`,
  api.lua:170), so the pair at a gate engages in either direction and a guard
  can lose. `guard.lua` keeps its **own** `attack_npcs = false`, so guard versus
  guard stays off across factions (world.md §4).
- The veto is now a property of the **target**: `grug_mobs.noncombatant(def)`
  (verbs.lua) declares a family non-combatant and wraps its `after_activate` to
  install `_grug_noncombatant` on every activation. `grug_mobs.is_noncombatant`
  is the pure predicate.
- The **40th `GRUG PATCH`** in `mods/ENTITIES/mobs/api.lua` drops such a
  candidate in `general_attack`'s own filter, beside the existing
  `_grug_ignore_player` hook (VENDOR.md).

Why the flag is installed at activation and not left in the def: mobs_redo's
`register_mob` copies an explicit whitelist into the entity prototype
(api.lua:3196ff), so a `_grug_*` def field reaches neither `self` nor
`core.registered_entities[name]` — AGENTS.md's WP6 runtime-field rule. The def
keeps `_grug_noncombatant = true` as the declaration a reader and the KAT see;
the verb is the one place that turns the declaration into behaviour.

Why `attack_npcs` could not express it at all: it is one boolean over the whole
`type = "npc"` family, and that family holds both the guards a hostile MAY fight
and the three civilian families it may not.

Three families carry it: `grug_mobs:villager_<race>`, `grug_mobs:elder_<race>`
(`start_villagers.lua`'s shared `npc_def`) and `grug_traders:vendor_*`
(`vendors.lua`'s `register_vendor`).

`general_attack` is the only acquisition path that had to change. Every other
`do_attack` caller in the tree is provocation — on_punch's retaliation, the
group alert, the pack/swarm verbs, the threat switch, Taunt — and all of them
pass whoever punched. A non-combatant never punches.

### 1.2 The elder faced the door

Round 1 added `FACE_AWAY_TAGS = {door = true}` to `start_npcs.lua`'s
`socket_face_yaw`, keyed on `socket.role == "idle"`. All seven quest sockets —
the six Village Elders and Highcourt's chapel Elder — stand on a doorstep with
their authored facing on the door, and the role test left every one of them
showing the street its back.

The role test is deleted: the turn now follows the **tag**, which is where the
geometry is described, for every role — and for any position in `tags`, not only
the first. `tags` is a list in the contract; its first entry is the one the
spoken line reads off, so `{"bench", "door"}` is a bench spot at a door and
reading `tags[1]` alone would have turned the rule off for exactly that shape.
The seven quest sockets carry `tags = {"door"}`, and any future role placed at a
door inherits the turn by saying so. Sockets are not identity bytes, so this is a
socket-table edit.

Measured, not asserted: both blueprint KATs now check a `quest` socket against
the finished pad — the tag is present, the authored facing really runs into the
building within five nodes (a doorstep is not always the node in front of the
leaf; Sunscar's tusk door opens onto its own porch), and the cell behind, where
the elder actually looks, is free and is one of the positions the route flood
reached.

One thing deliberately **not** changed: `door` is a consumer rule, not a
geometric claim, and the capitals' own gate and hall-service `idle` sockets use
it the other way round — they stand inside a gate looking in, so the turn faces
the citizen at the door it is about to leave by. Both readings are legal and
both are documented in the contract (§7); only the `quest` shape is measured.

### 1.3 Waypoints: as many spots as citizens

The user's question was exactly right. A start had four `idle` sockets and four
villagers, Highcourt's core thirty and thirty — so every candidate spot in
`next_spot` was permanently occupied and the amble degenerated into people
trading doorsteps.

What shipped: **spare sockets**, `spawn = false` on an `idle` socket.

- The **registry** (`grug_core/settlement_sockets.lua`) validates the field
  (absent or exactly `false`, and only on an `idle` socket — a `guard_post` with
  `spawn = false` would be a gate nobody mans, written as one word) and
  normalizes it to a boolean so no consumer spells "nil means true".
- The **roster** counts only spawn sockets: `carries` in `build_rows` adds
  `socket.spawn ~= false`, so a spare enters no marker, no hard cap, no census
  row and no placement.
- The **spot ring** keeps every idle socket, spares included, in the authored
  order. The index is now recorded in the same pass that builds the ring
  (`spot_index`) instead of being re-derived from a count of the placed sockets
  — that count drifts the moment a spare sits in front of a home in the authored
  order, and would have pointed every villager at the wrong spot.
- The census gains a `spare` field and the per-settlement log line a
  `spare <n>` column.

Three per start, ten in Highcourt's core. They belong to the composition that
authored them, so a core citizen reaches the core's ten and a district plot's
citizen keeps to its plot.

## 2. Choosing the spare positions

Not eyeballed. A scratch selection tool replayed `blueprint_kat.lua`'s own
socket test over the finished pad and took the first candidates in a fixed
order:

- feet and head exactly air, a third node of air above, the node below really
  solid, outside every authored room, reachable on foot from the arrival by the
  KAT's conservative walk;
- `y == 1` — the settlement's own ground course, so nobody stands on a fence, a
  tree trunk or a stair;
- at least 7 nodes from every authored socket (8 in Highcourt), 8 to 30 from the
  arrival (≤ 42 in Highcourt), at least 14 apart from one another (18 in
  Highcourt);
- nearest to the arrival first, so the choice is deterministic and the three ids
  `idle_spare_1..3` are simply that order.

Every one of them is then re-measured by the shipped KATs on every run, which is
the check that matters: the tool is scaffolding, the KAT is the gate.

## 3. Sockets per settlement, before and after

Roster = the sockets an NPC is actually placed on (the patrol loop carries one
guard on its first waypoint; `king` and `waypoint` carry nobody).

| settlement | sockets before | sockets after | idle before | idle after | spare | roster |
| --- | --- | --- | --- | --- | --- | --- |
| dawnmere | 13 | 16 | 4 | 7 | 3 | 9 |
| hearthpine | 13 | 16 | 4 | 7 | 3 | 9 |
| kapok | 13 | 16 | 4 | 7 | 3 | 9 |
| silverleaf | 13 | 16 | 4 | 7 | 3 | 9 |
| stillgrave | 13 | 16 | 4 | 7 | 3 | 9 |
| sunscar | 13 | 16 | 4 | 7 | 3 | 9 |
| highcourt core | 65 | 75 | 30 | 40 | 10 | 50 |
| highcourt market district (9 plots) | 30 | 30 | 12 | 12 | 0 | 21 |

The six starts' blueprint identity SHAs and Highcourt's are unchanged — sockets
are landmarks, not identity bytes (contract §2).

## 4. Gates

Everything under `tools/wp13/evidence/20260915-npc-round-2/`.

- `static.sh` / `static.txt` — `luac51 -p` per touched file and tree-wide, the
  SETGLOBAL count, the five plain-5.1 sweeps (touched mods, `mods/*/grug_*`,
  `tools/wp13`), `check_fresh_server.py`.
- `final-micro.sh` / `final-micro/` — the one bounded final-byte process: every
  WP13 fixture in one interpreter, once under LuaJIT and once under
  `tools/bin/lua51`, inputs hashed before and after both runs.
- `kat.txt` — the `start_npcs_kat` report on its own.
- `start-identities.txt` — the six start identity digests, diffed against
  round 1's.
- `npc-probe/` — `tools/wp13/run_npc_probe.sh`, three boots on one world.

## 5. What the probe adds this round

Four claims were added to the round-1 programme; one round-1 timing was widened
(the last bullet).

- **R1 spare sockets never spawn.** Every census phase reads the settlement's
  spare set out of `grug_core` and fails if any NPC is booked on one.
- **R2 villagers visit more than one spot.** A one-second sampler over the
  170-second amble window records which spot each flair NPC is actually
  *standing* at (a target index proves an intention, an arrival proves a walk),
  and every villager must have stood at two different ones. Sampled per second
  and not at the nine logging points because a dwell is 20–60 s and a Hearthpine
  walk about 25 s — a 20-second sampler would make this a coin toss.
- **R3 the elder faces the street.** Read off the OBJECT's yaw, because that is
  what the player sees, and checked again after a reboot: `mob_activate` hands
  every mob a random yaw, so the authored facing has to be re-asserted on every
  activation. Quest sockets only — an elder is the one family with no movement
  at all, so its yaw is the rule and nothing else.
- **One round-1 case was repaired, and the defect was the probe's, not the
  game's.** The review case "an NPC whose own mapblock went inactive comes back
  when the block does" teleported a villager to *its own position + 128* and
  hoped. That volume is 150-odd nodes from the anchor, outside everything the
  preload and the probe's own grid ever generate, so where the NPC landed was
  whatever the map happened to have there — and **an object moved into a block
  that does not exist is not unloaded, it is lost**. Two runs of this round
  showed it exactly: the block read `active=true loaded=true` at the check and
  the NPC was still missing, and the NEXT boot then freed the marker and placed
  a replacement — the engine saying the object was gone rather than asleep. Round
  1 passed it by luck of where its villager stood, and the wider spot ring of
  this round made the luck run out.
  The destination is now a FIXED offset from the anchor (deterministic, unlike a
  wandering villager's position), it is forceloaded — which generates it —
  before anything is moved there, the NPC is put on the ground the probe reads
  out of that column, and only then is the forceload released, which is what
  makes the block inactive and is the state under test. The re-activation window
  is 25 s rather than 6 (the engine reads the block off disk and then waits for
  its own `active_block_mgmt_interval`), with `event=reload_request` /
  `event=reload_wait` recording the block's own status on the way.
- **R4 mutual combat, and not with civilians.** A hostile may no longer carry
  `attack_npcs = false`; the gate pair must engage in at least one direction;
  and no mob the settlement scan reaches may hold a non-combatant as its target,
  asked of the entity's flag rather than of a name list — a name list is exactly
  what a new civilian family would be missing from.

## 6. Open points

- **Guard-versus-guard across factions is still off.** The user's ruling did not
  change it and NPC-vs-NPC war needs its own design pass (world.md §4).
- **No war-front unit exists yet**, so the documented exception has no consumer.
  With `no_npc_targets` gone, `_grug_attack_npcs` is gone too: a war-front def
  that wants to hunt civilians would have to clear `_grug_noncombatant` on the
  target side, which no design asks for.
- **The `door` tag carries two readings** (contract §7). Only the `quest` shape
  is measured; the capitals' gate and service sockets are the other one. If a
  future round wants one meaning, the capital sockets are the ones to re-author.
- **Spare spots are not themed.** They carry no tag, so a villager standing on
  one answers with its race's `default` line. Giving them tags would be a
  flavour pass, not a mechanism change.
- **District plots have no spares.** A district citizen still has exactly one
  spot of its own composition and therefore does not wander. Adding a spare per
  plot belongs to the districts lane, which owns those files.
