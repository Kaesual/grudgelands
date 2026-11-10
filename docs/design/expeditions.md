# Expeditions

Repeatable group content in the Miner's Guild's name: a party, or one player, opens a
sealed mine far beyond the map, fights through it and takes the reward at its end.
Every run is written anew, so an Expedition can be played again and again.

**Decided** by the user, 2026-11-07; the framework and The Stilled Seam (levels 20–69)
are implemented in Round 71 (`grug_expeditions`), The Second Shift, The Last Mint, the
traps, the Expeditions tab and the reshaped rooms in Round 72; Round 73 (0.73.0) redesigned all
three: floors with stairs, bent passages, light from what belongs there, dark stretches, the
ambush, lava falls, critters and particles; Round 74 (0.74.0) shortened the closing and the
Deserter's Mark, quickened the wall traps and gave the mobs the walk grid. This file owns the game rules
and their numbers. The [concept](../planning/round71-expeditions-concept.md) stays as the
record of the rulings, the [Round 73 concept](../planning/round73-expedition-redesign-concept.md)
as that of the redesign's; [Round 71](../planning/round71-plan.md),
[Round 72](../planning/round72-plan.md#completion-2026-11-08) and
[Round 73](../planning/round73-plan.md#completion-2026-11-10) hold what shipped. How it is built:
[module guide](../technical/module-guide.md#expeditions),
[template format](../technical/expedition-template-format.md).

The word is **Expedition**, for players, in docs and in code.

A few details below are the coordinator's defaults, standing until the user rules on them
([completion](../planning/round71-plan.md#decisions-during-the-round)): sight as a pull, a list holding only who engaged, forced exits in combat, no boats, refined bars in drops, the
black arrival, one chest roll, lost chest contents and a boss without
ground drops. Round 72.1's (§5): Cancel counts down like Finish while someone is inside,
Finish and Cancel are refused while a run is prepared or already closing, and a run that
can be finished offers Finish alone.

## 1. The set

Three Expeditions, each over a wide level range (user, 2026-11-07, [concept
§9](../planning/round71-expeditions-concept.md#9-after-the-build-three-expeditions-user-2026-11-07)):

| Expedition | Mob levels | Most players inside | State |
|---|---|---:|---|
| The Stilled Seam | 20–69 | 3 at every level | implemented in Round 71, reshaped in Rounds 72 and 73 (§13) |
| The Second Shift | 40–69 | 4 | implemented in Round 72, reshaped in Round 73 (§14) |
| The Last Mint | 60–69 | 4 | implemented in Round 72, reshaped in Round 73 (§15) |

**Every 10 levels the tier follows:** the reward, the ore and the gem. The ore is what that
tier's rock is mined for, the next metal's input ([items](items_crafting.md) §3.0.1): T2's
Anthracite is the Steel input (user, 2026-11-07; the story keeps its gold working).

| Tier | Mob levels | Ore | Gem |
|---|---|---|---|
| T2 | 20–29 | Anthracite | Jade |
| T3 | 30–39 | Silver | Garnet |
| T4 | 40–49 | Emberglass | Sapphire |
| T5 | 50–59 | Abyssal Crystal | Ruby |
| T6 | 60–69 | Abyssal Crystal (T6 has no ore of its own; user) | Diamond |

An Expedition lasts 10–20 minutes, is balanced for 3–4 players and runs in a line at
first. Floor plans are 2D on one main floor for now; the template format stays 3D.

**Rooms** (user, 2026-11-08): an Expedition must not read as a row of rectangular rooms.
Walls and ceilings are irregular in plan and in height (overhangs, sloped or stepped
ceilings, niches, ribs), and now and then a cuboid room reads as meant. Since Round 73 each
Expedition has its own few room types (a sunken floor with a stair ring, terraces, a
collapse with a rubble ramp, a pillared hall, a square work room, a lava fall as the
centrepiece), never one next to its own, and the dressing follows what happened in the room.
**No pack can be walked round:** from every walkable floor cell of a pack's room at least
one mob of that pack would notice the player (in its view range and in sight, over the
relief), and no perch lies out of a pack's reach.

**Floors** (Round 73, the user, 2026-11-09 and 2026-11-10; replaces Round 72's flat floors
and "no dais"): every change of height is a stair (normal, inner or outer) of an existing
stair set, so players and mobs walk it without a jump and finding a way stays a question of
x and z. One walking surface per column, neighbours at most one node apart, no ridge or
trench one node wide, and a trap's floor flat. **Height maps must not look even:** pits and
rises of several levels with irregular outlines and uneven slopes, more than one feature in
a larger room, and some rooms flat on purpose. Boss rooms may have relief too (a sunken
arena, terraces). Every walking cell and stair has the free height of its Expedition's
tallest mob plus one node over its own floor.

**Passages** (Round 73) bend and change width, with a niche, a short dead end, a widening,
a stair run or a lower stretch every 15–20 nodes or so; a niche never makes a way round a
pack, a trap or an ambush. A straight passage is a choice: the dark ambush stretches.

**Light** (Round 73) comes from things that belong there: a desk, a door, the ore, a lava
fall, candles on crates, lamps set in the rock; never a grid, never a row along a wall. A
hanging light sits at the feet plus the tallest mob plus one or higher, or in a wall cell,
so no mob's head meets it. At eye height:

| Where | Light |
|---|---|
| The fighting floor: every cell a pack or the boss fights on, the traps and their radius | 4 or more everywhere, 6 or more on 75 % (the user, 2026-11-10: pack rooms may be darker in patches) |
| The arrival, the store, the waystones, the chest, the door | 6 or more |
| Everywhere else: passages, niches, rooms without a pack | anything, 0 included, with a light in sight |
| An ambush's zone and its alcoves | 0 |

**Dark stretches:** from every floor cell below light 4 a light is in sight from the eye,
within about 32 nodes, so a dark stretch is a nearly straight passage with a light at its
end, never a maze.

**Dressing** (Round 73): moss, mossy cobble, lichen, a few plants, bones and cobwebs in
high corners, in clusters where they fit (damp places, low ceilings), not spread evenly.
Nothing walkable and no cobweb lies on a walking cell, and no gathering source or crop
anywhere: it would be loot outside the chest.

Every written template is proved for all of this, the ambush, lava and particle rules
included, by one shared proof (`tools/expedition_templates/proofs.lua`, 14 rules); the
height maps' variety is left to the previews and the review.

## 2. Levels and entry

- The creator picks the **mob level** inside the Expedition's range, in two steps: a tier,
  which names its ore and gem, then a level inside it. Only tiers with a level the creator
  may enter are offered; the window starts at the creator's own level. The level sets every
  mob and the boss, the item level of their drops and of the chest, and the tier. Players
  are capped at 60, so 61–69 is played at 60 with the level malus: the top of the range is
  meant to be hard.
- **Entry level:** run level − 2, at most 60. Level 60 needs 58, 61 needs 59, 62–69
  need 60.
- The dropdowns offer only levels the **creator** may enter, for a party leader too: a
  level 29 player creates up to 31, a level 60 player everything.
- A party leader sees one row per member with their eligibility before creating. It warns
  and stops nobody.
- **Entering is a hard gate:** a player below the entry level cannot teleport in. Level
  21 admits a level 19 player, level 22 does not.

## 3. Owner

An Expedition has **one owner: one player or one party**, and an owner has one
Expedition at a time, until it ends: a run it no longer wants is finished or cancelled
(§5). Anyone who does not belong to it is teleported out at once.

- **Creating:** at the **Expedition Registrar**, outdoors a few steps from a capital's great hall door
  ([settlements](settlements.md)). It serves its own faction. A party leader creates a
  party-owned Expedition, a player without a party a player-owned one; another party
  member cannot create one. Solo is allowed; the content stays balanced for a group.
- **A solo owner invites someone** and so leads a new party: the Expedition becomes the
  party's.
- **A solo owner joins a foreign party:** the Expedition ends at once, the owner is
  teleported out if inside, and leaving that party does not win it back. The invitation
  warns of this ([parties](parties.md)). Since Round 72.1 the owner also gets the
  **Deserter's Mark** (§5), unless the run could be finished (its boss dead, or none) or
  was already finished or cancelled.
- **A party falls to one member:** that member becomes the owner.
- **Leaving the party**, by choice, kicked or by a faction change: the player is
  teleported out at once, in combat too, and their place is free again. This also frees
  them from a pack, without a penalty: the rule is "or they leave the Expedition".

## 4. Entering and leaving

- **Preparing:** creating shows "Your Expedition is being prepared...". Nobody can enter
  before it is ready; a notice says when it is.
- **Enter** at a registrar of the player's faction, or (Round 72, user 2026-11-08) on the
  **Expeditions tab** of every waystone outside the Expeditions and of the Claim Stone
  ([world.md](world.md) §6, [housing](housing.md) §7.1). The tab lists the Expedition of
  the player's owner while they may enter it (owner, the Deserter's Mark, ready or under
  way, closing, level, places); otherwise it says in one line why, or with no Expedition
  points to the Registrar. Below that, since Round 72.1, the run's state and, for its
  leader, Finish or Cancel (§5), also when the leader cannot enter.
  Creating stays at the Registrar alone. Entering from the tab is a waystone trip by the
  waystones' rules: standing at the stone, alive, and refused in combat, at the click and
  again on arrival; it arrives at the start waystone as from the Registrar.
- **The way back** of a forced exit or a login after the end leads to the waystone of
  the last way in: the Registrar's capital, the waystone whose tab was used, or from the
  Claim Stone the waystone of the player's innkeeper home.
- **Places:** entering takes one, for as long as the player stays in the party. Leaving
  the box keeps it; the player can go back in. So a larger party is full after the first
  3 or 4 entries, and only leaving the party frees a place.
- **Two waystones** stand inside: at the start, and in the reward room. Since Round 72
  both open the ordinary waystone window: the player travels to any of their discovered
  waystones or their Claim Stone, by the waystones' rules (no cooldown, refused in
  combat). The Expedition's waystones are never a destination. A trip out keeps the place
  and ends no run; the player leaves its packs' lists as they leave the box. Since Round
  72.1 the window also has an Expeditions tab with the run's state and its leader's
  Finish or Cancel alone, never Enter.
- **Return Home** works inside, under its normal rules ([home travel](home_travel.md)),
  but not in lava (Round 72, the user's ruling for The Last Mint): standing in it, or
  falling towards it, a player is refused ("Cannot return home from the lava."). A fall
  into the lake is death with no way out. Logout is unchanged: a login stands where the
  player was.
- Neither way leaves the party.

## 5. Release, logout, restart

- **10 minutes:** an Expedition is reserved for only 10 minutes while nobody of the owner
  is inside, both after it is ready and after the run began. So a ready Expedition must be
  entered within 10 minutes. An offline member does not count as inside; a dead one does until they log out; a respawn stands them at
the start waystone, still inside.
- After those 10 minutes it **ends**: nobody can enter any more, and the slot is free.
  A notice names the reason. Letting a run lapse so gives no Deserter's Mark.
- **Finish** (Round 72.1, the user, 2026-11-09) ends a run properly once its boss is dead,
  or at once when its template has none. Only the party's **current leader**, or the solo
  owner, may finish, at the Registrar, on the Expeditions tab of a waystone outside or of
  the Claim Stone, or at a waystone inside; it needs no confirmation. The run ends **30
  seconds** later (60 until Round 74, the user, 2026-11-10):
  - Everyone inside sees "This Expedition ends in N seconds." as the banner line, once a
    second for the whole countdown; whoever enters meanwhile sees it from their arrival on.
    Members outside get one notice: "<leader> finished the Expedition. It ends in 30
    seconds."
  - Entering is refused for the last **10 seconds** ("This Expedition is closing."), at
    the click and on the arrival of a trip already on its way.
  - At the end everyone still inside goes to the waystone of their last way in, as at
    every end; a dead player stays dead and respawns at home. What is left in the chest is
    lost (§10).
- **Cancel** ends a run that cannot be finished, in any state from ready on, never
  entered included; the same leader, the same places. A run whose boss is dead offers
  Finish alone. The first click asks: "Cancel this Expedition? You cannot open or enter an
  Expedition for 2 minutes.", with Confirm and Back. With nobody inside the run ends at
  once; otherwise it counts down 30 seconds like Finish, with the banner "This Expedition
  was cancelled. It ends in N seconds.", and nobody can enter it from the click on.
- **The buttons** (Round 72.2, the user, 2026-11-10): the leader only ever sees one of
  them, Finish in green, Cancel in red (its Confirm red too). An open Registrar window or
  Expeditions tab of the owner's players is redrawn **once** when Finish or Cancel starts
  the countdown and once at the end; it does not count down itself (the banner does), and
  a window the player left (walked away from its stone, or another form replaced it) does
  not pop back.
- Finish and Cancel are refused while a run is being prepared (about 15 seconds) and
  once it is closing. During the countdown the owner still holds the run, so a new one can
  be opened only after its end; the 10-minute clock runs on, and whichever end comes
  first ends it.
- **The Deserter's Mark:** whoever cancels, and nobody else (party members are never
  punished for their leader), can neither open nor enter any Expedition, their party's
  included, for **2 minutes** of real time (5 until Round 74, the user, 2026-11-10), from
  the click. A refusal names it with the time left: "Deserter's Mark: no Expeditions for
  1:42." It runs on through a logout and a
  server restart (its end is saved player meta), and shows in the status row and the
  Effects tab as "Deserter's Mark", "Cannot open or enter Expeditions"; its icon is the
  contested banner upside down and muted until a drawn one is picked. The leader may hand
  leadership on: a new leader without the mark may open a new run at once, which the
  bearer cannot enter while the mark lasts.
- **Logout out of combat** costs nothing: the player comes back where they stood.
- **Logout on a pack's list** counts as a death, with Round 70's penalty once
  ([durability](durability_repair.md)), and takes the player off the list. The death
  happens at the next login, and they stand at the start waystone if the Expedition still
  belongs to them. A server shutdown is no logout.
- **Whoever logs in after their Expedition ended** stands at the waystone of their last
  way in (§4).
- **A server restart ends every Expedition**, which then falls under the rule above.
  Nothing about a run is saved.

## 6. Slots and preparation

The server alone clears and fills an Expedition. No content comes from the map generator,
so Expeditions need no map reset.

| What | Value |
|---|---|
| Slots | **100**, generic and equal; any slot holds any Expedition |
| Box | 128 × 64 × 128 nodes, y −112 to −49, below the seabed (y −23) |
| Grid | 10 × 10, pitch 320 on x and z; first box from x 8064, z −1616, last ending at x 11071, z 1391 |
| Free slot | the first free one is taken; with none free the creator gets a refusal |
| One operation | on activation the box is cleared and the whole template written at the chosen level. No journal of dug blocks or killed mobs: a run always starts as planned |
| Order | one preparation at a time, 4 mapblocks per server step, a count and never a clock |
| Time | about 15 seconds; low priority, never competing with players |

The slots lie far beyond the map, in the open sea's class. There the minimap shows ocean
and the party's arrows ([atlas](world_map.md)), and the location line shows the
Expedition's name. An arrival hides the unloaded room behind one second of black.

## 7. The rules inside

- **Hull:** the walls are indestructible. Anything destructible is so on purpose: a tunnel
  the story asks for, or ore and gem nodes. The open sea's rule refuses everything else
  ([world.md](world.md) R3).
- **No building** at all, and players place no liquids. A template's own lava is allowed
  and stays where it was written (Round 72, `grug_core/lava_guard.lua`: every box holds its
  lava; nothing flows in, out or away). Short jump-and-run tasks appear in the higher
  Expeditions: The Last Mint's lake (§15).
- **Lava** (Round 73, the user, 2026-11-10): one to three lava falls per Expedition (The Last Mint three besides its
  lake). A fall runs from a source in a wall niche down a recess into a basin beside the floor, also in a
  fighting area, lit by its own glow; none lies at a passage's mouth, at the foot of a stair run, in the dark or in an
  ambush's stretch, and no lava cell is a walking cell. Stepping in, or being pushed in by a pack's hits, is the players' danger. Every mob of an Expedition
  (bosses, ambushes and critters included) is immune to lava, and none walks into it by itself: its paths, its chase,
  its way home and its spawn spot all keep lava a boundary, and a pack's jump to a player standing in a basin lands on
  the basin's rim. A mob pushed in takes no damage and climbs out. The boss's floor (§8) has no lava cell, but a target
  in a small basin stays within the boss's reach of its rim, so standing in the lava keeps the fight and burns.
- **Particles** (Round 73): the template places a few spawners that fit the place (dripping water, dust, ash, paper
  scraps, embers, sparks; [format](../technical/expedition-template-format.md)). Only the run's players inside see
  them, only while they are inside, and they go with the run; a few hundred live particles per Expedition at most.
- **No mounts:** neither riding nor flying, and no boats ([mounts](mounts.md) §4.0).
- **Death:** the player respawns at the start waystone. Round 70's death penalty applies
  ([durability](durability_repair.md)).
- **Digging:** only what the template marks, in a running Expedition, by a player who
  belongs to it. The ordinary mining path applies: the right pick, drop and wear. A hole
  takes no block.
- **No natural mob spawns** over the slot field plus 320 nodes on every side, at any y, the
  water rows included: x 7744 to 11391, z −1936 to 1711. So no random mob's nametag shows
  through a wall ([biomes and mobs](biomes_mobs.md)).

## 8. Mobs and packs

- A room's mobs appear when a player of the run comes within 48 nodes, once. Nothing
  respawns but a partly killed pack (below). An ambush's room (Traps, below) waits for its zone instead.
- **Critters** (Round 73): a few Cave Bats, Cave Crawlers and Bone Weevils, placed like a room's mobs but outside every
  pack. Inside an Expedition they drop nothing, settle no kill (no XP, which the critter tier never pays, and no quest
  credit), and hitting one starts no fight and pulls no pack; they keep fleeing. They never count for the door, the
  boss or the chest, and nothing places them again.
- Every mob is at the run's level through its own entity, whatever its spawn row says,
  and pays XP as usual.
- **No easing for a high level or a race** (0.72.0, the user, 2026-11-07 and 2026-11-08):
  an Expedition's mob notices a player of any level at its full view range (no shrinking
  aggro radius by level gap), and the Undead truce does not hold against it. Every
  Expedition's mob carries the mark, the boss included, whatever its Expedition.
- **Drops:** each mob drops at its own level, 61–69 included, from the T6 pool, and no ore
  or gem ([items](items_crafting.md)). Refined bars stay.
- **Packs** ([full rules](combat_stats.md#expedition-packs), the owner of the mob's side,
  with its distances and times):
  - A pack is pulled whole: engaging one mob pulls all of it. Sight counts.
  - It never gives up, and a player on its list stays in combat until it is dead or they
    leave it, so waystones and Return Home stay refused. A pulled pack ends in a win, a
    death or a logout.
  - Whoever never engaged is not on the list and may walk out.
  - A dead player leaves the list, and back at the start waystone they are not hunted.
  - A mob left behind jumps after its player. Nobody stays in combat with nothing able to
    reach them.
  - **Wipe:** with nobody left on its list the pack goes home healed, and its dead stand
    at their place at once. A fully dead pack stays dead.
- **Their way** (Round 74, the user, 2026-11-10): every mob path inside an Expedition goes over its template's
  **walk grid**, written with the template and loaded once for every run of it
  ([format](../technical/expedition-template-format.md)): the floor's walking cells, the moves between them (one node
  up or down, no corner cut), the room a wide body needs (a Giant Spider keeps two nodes from walls, a two-node elite
  a free 2 x 2 block), and the reward door, passable once open. A chasing mob searches it as soon as its straight
  line to its target is blocked, at any distance, and so comes round a pillar or a corner instead of running into
  it; an evading mob walks home along the shortest way to its home, steering at the furthest cell ahead it can walk
  to straight (round a corner close by, along the grid's path). A mob in the air or pushed into a wall finds its
  walking cell within two nodes. Mobs do not leap: a mob whose home the grid cannot reach (one that crossed The
  Last Mint's lake by its pack's jump) is **set home at once**, and one that fell into the lake once it has been
  off the grid about 5–6 s, placed the way a pack's jump places a mob, instead of waiting for the 40 s teleport
  (the user, 2026-11-10).
- **The boss** is a pack of one: a wipe heals it and sends it home. Its **room is its range**
  (0.72.0, the user, 2026-11-07): its floor inside the template's envelope (the places
  `boss_room_min` and `boss_room_max`), so it pursues nobody into a passage and a ledge is
  no safe spot. A player who leaves the room leaves its list; alone they reset it at once,
  otherwise only a Taunt within 3 s keeps the fight. **15 s without an attack** reset it
  too; a trap's hit is no attack, the boss's own marked spot with a player in its area is.
  Its reset is the wipe
  ([full rules](combat_stats.md), §4 "Kings and bosses"). Its death gives
  **credit only**: no 24-hour lockout, no direct reward and no drops at all, coin bag
  included; the chest pays. There is no other lockout timer: the run's length is the
  limiter ([world.md](world.md) R4). Credit counts per Expedition, at any of its levels.

### Traps

Two trap types and, since Round 73, the ambush, the same in every Expedition (user, 2026-11-07, [Round 72](../planning/round72-plan.md)
§2.9; built in Round 72, `grug_expeditions/traps.lua`). The numbers are the plans' proposals, tuned in the user's
test.

- **Spots:** the template names the candidates in groups, and each run arms a set number of each group's candidates
  (say 2 of 4), drawn at random once per creation. The choice and the marks of fired traps last the run: a wipe
  changes neither. An unchosen candidate is ordinary floor or wall.
- **Players only:** traps never notice or hurt a mob, and a fireball flies through mobs. They are silent and never
  damage the terrain or push anyone.
- **Damage:** 45 % of the run level's neutral HP pool (that of level 60 above 60) per hit, through dodge, armor and
  absorbs like a mob's hit. A trap's hit marks the player in combat.
- **Floor trap:** invisible until it first fires. A player whose feet come within 0.6 of its spot on the floor starts
  it (a jump over it does not): a muted red ring of radius 2 for 1.5 s, then the hit to every player within 2 nodes of
  it and in sight of it. It rearms 10 s after the hit; standing on it then starts it again. From its first hit a red
  mark shows its spot for the rest of the run.
- **Wall trap:** a fireball on a fixed period (2 s in both templates since Round 74, the user, 2026-11-10; 6 and 8 s
  before), always, from its group's offset after the Expedition is ready, along a fixed direction at 8 nodes a
  second; no targeting. Stone stops it. A player in its way
  bursts it: the same hit to every player within 2 nodes. A shot with nobody of the run within 32 nodes of its line is
  left out, the rhythm kept.
- **A boss's marked spot** (The Second Shift's Auditor Nemm): the floor trap's ring and hit on one position, once;
  his reset or death takes the hit back. One that had a player in its area is his attack for the 15 s rule.
- **The ambush** (Round 73, the user, 2026-11-10; `traps.lua`, `encounters.lua`): an invisible zone across a long
  dark passage, its alcoves in the walls beside it. The template names the candidates in groups as traps do (and in
  the same name space), two per Expedition with one armed per run in the plans, chosen with the traps when the run is
  ready. A living player of the run who enters or crosses the zone springs it, at any height in the passage and by
  any movement: a walk, a sprint, a jump over it, a Blink or a Charge across it, a knockback. A respawn, Return Home,
  waystone travel and the way in never do. It fires once per run: no ring, no mark, no damage of its own, no rearm,
  and a wipe changes nothing. Its pack, normal tier and melee only, appears in its alcoves at that moment, never
  earlier, and takes that player at once; the only cue is a faint dust burst at the alcoves. From then on it is a pack
  like every other: after a wipe it waits in its alcoves, visible, and crossing again spawns nothing new. An unarmed
  candidate stays quiet and its pack never appears. It gives no reward and opens nothing.
  - **Placement** (proved on every template): the zone spans its passage wall to wall, two to three nodes deep on a
    flat floor, so every walk to the end crosses it; its alcoves are dark, fit their mob and lead nowhere. It lies in
    no pack or boss room, out of every pack's notice, out of sight of the arrival and the start waystone (where a
    respawn stands, so a wipe's pack does not chase the party there), with no trap in its dark stretch, and **never as
    the first fight** (the user, 2026-11-10): every walk from the arrival reaches it through a pack room first. Its
    pack is about half a room pack by the Expedition's balance model, from its own roster (The Stilled Seam's two
    spiders a third of its mean room pack, kept by the user, 2026-11-10).

## 9. Tank and healer

**Every Expedition needs a tank and a healer.** The Warrior need not be skilled defensively
and the healer need not be skilled for healing, but without a Warrior and a healer an
Expedition is hard or impossible.

Balance is for a Warrior, a Priest and the rest of the party, at **player level =
Expedition level**. A player at the entry limit keeps the level malus
([combat](combat_stats.md)) as their own problem: nothing is tuned for them.

## 10. Rewards

- The **reward room** lies behind the boss. Its door opens when the boss is dead, and only
  in that box.
- Its **chest** has a separate inventory per player. Everyone of the owner who has entered
  this run opens their own, also a member who came in after the kill.
- One roll per player per run, at the first opening. It may be reopened until the run ends,
  so a full bag is no loss. **What is left at the end is lost**, and the chest says so.
- It holds items, Bags of Coins and crafting materials from the Expedition's own loot table
  at the run's level, **never ores or gems**.

## 11. Ore

- Ores and gems are minable nodes of the run's tier only (§1). A template is written once,
  with the T2 nodes; a run of another tier writes its own ore and gem in their places, and
  only those can be dug. The rock round them stays the template's: the ore textures are
  drawn on plain stone.
- They are rare on the way, only after the first mob pack, and not too many. The reward
  room is somewhat richer: the real reward comes at the end.
- **Expeditions support mining, they do not replace it** (user, 2026-11-07): what a run
  yields per player of its tier's ore and gem stays clearly below the same time of ordinary
  mining in that tier's rock, gems above all. The knob is fewer filled places at a tier.
- **Exception to [world.md](world.md) R4:** Expedition ore is renewable through an
  Expedition's reset only. A mined node comes back with the next run's template, and
  through nothing else.

## 12. Story and quests

Every Expedition has a small storyline and a storyline quest whose goal is killing the boss:
the Miner's Guild ran into trouble while mining and needs fighters. **All of these quests are
optional, level 60 included:** free, not on the chained story path, without the `story` flag.
So the rule for group quests below 51 holds ([quests](quests.md#group-quests-round-61)).

Every character gets the **Expedition Registrar's letter** at level 20, always, or at the
next login when already above it ([mail](mail.md) §8, Round 72).

## 13. The Stilled Seam

An abandoned gold working held by spiders and golems, at mob levels 20–69. Its
[description](../planning/round71-l20-description.md) was approved by the user and has the
story, the floor plan and the texts.

- **Size:** 128 × 32 × 128, one floor, six rooms in a line. Round 73 (lane SEAM) reshaped
  every room and passage round the same places: the oldest and roughest mine of the three,
  with the most moss and lichen, timber sets in the passages, rubble stairs, dripping water
  and bats.

| Room | Holds |
|---|---|
| 0 Arrival | small timber refuge, a boarded entrance with a rubble slump two levels up beside it, lanterns over the start waystone |
| 1 Cart bay | raised loading floor two levels up in the north-west, a sump a level down in the south, the old rails; a hooded cart with a candle; pack a: 4 spiders; 1 ore in the blind siding after the pack |
| 2 Prop room | a collapse: a rubble ramp three levels up to the north-east under a broken roof, a scour in the south-west, timber pairs in the walls, a lava fall from a hot seam in the east wall; pack b: 2 spiders, 1 elite golem; 1 gem |
| 3 Sorting floor | bay c a sunken sorting floor two levels deep beside a spoil heap, hooded tables with candles; bay d a square work room, flat on purpose; the rock screen between them; packs c and d: 3 spiders and 1 elite golem each |
| 4 Working face | Flintback's court: a sunken arena of uneven levels (a broad hollow, a deeper pit off his place, a rim terrace, a spoil bank), a high fractured dome, cobble piers and a lava fall in the north-east wall; [Flintback](biomes_mobs.md), alone |
| 5 Store | square plank store beneath pine coffers, flat on purpose, hooded barrels and capped mineral seams; chest, end waystone; 4 ore, 2 gem |

- **Floor and passages (Round 73):** the floor is one height map with every change of
  height a stair (relief by stairs only; the first air is y 5, pits down to y 3, the ramp up
  to y 8). The passages bend and change width, with niches, a rubble hump, stair runs down
  and up and a widening without a pack; the two dark drifts are long and straight on
  purpose. The court's range stays its envelope (54, 94)–(79, 119) in x/z.
- **Light (Round 73):** from things in the mine: lanterns hung over the tallest mob's head
  room, candles on the hooded tables, barrels and cart, miners' anthracite lamps in niches
  cut into the rock, and the two lava falls. No grid. The fighting floors, the arrival,
  the waystones, the chest and the door are lit; the passages have dark stretches with a
  light in sight.
- **Ambush (Round 73):** two candidates, one armed per run: the haulage drift between the
  cart bay and the prop room, and the drift down from the prop room to the sorting floor.
  Each is two spiders, one in a shallow alcove on each side of a dark zone across the
  drift, after the first pack and out of every pack's and the arrival's sight.
- **Lava (Round 73):** two falls, beside pack b's fighting floor and over Flintback's arena;
  a pack's hits can push a player in.
- **Critters and particles (Round 73):** two bats (the refuge, the store), two crawlers and
  a weevil in the passages' niches; dripping water in the niches, the drift and over the
  rubble ramp, dust motes in the refuge, the cart bay and the court (122 live particles at
  most).
- **Mobs:** 12 spiders, 3 elite golems and the boss, and the armed ambush's 2 spiders.
  Spiders have 384 HP at 20, 2,696 at 60 and 3,507 at 69; elites 1,152, 8,088 and 10,522;
  Flintback 8 × an elite's: 9,216, 64,704 and 84,176. Every mob keeps its name at every level; Flintback's is one fixed name.
- **Ore:** eight shared places per run, five ore and three gem, of the run's tier (§1).
- **Chest, per player:** 1 Uncommon (blue) item, at 25 % a Rare (yellow) item, both at the
  run's level as item level, and a bag of 10 × a kill's coin bag at the run's level. The
  materials are what its spiders drop in each mob band: 3–5 Raw Silk and, at 50 %, 1–2 Venom
  Glands at every level; 1–2 Coarse Spider Silk at 21–30, Layered Spider Web at 31–40, Glass
  Spider Silk at 51–69; 1–2 Venom Sacs at 50 % at 31–40 and always at 41–50.
- **Balance** (`tools/r71_l20/balance.py`, modelled): up to 60 every level plays as 20 does,
  a run about 9.3 minutes with the ambush. At 61–69 the level malus stretches packs and
  boss: at 69 a run is about 14.4 minutes, the boss about 4.8, and the tank takes about 2.9
  times the damage of level 20 in pools. The ambush's two spiders take half the time of
  pack a (a third of a mean room pack) and deal 30 % of its damage.
- **Quest:** "Party: The Stilled Seam", from the six guild leaders
  ([quests](quests.md)): kill Flintback once, at any of its levels. The Expedition stays
  repeatable after the turn-in.

## 14. The Second Shift

A working mine whose whole shift is dead, kept at work by Auditor Nemm's branded pay, at
mob levels 40–69 for four players. Its [build plan](../planning/round72-second-shift.md) was
approved by the user and has the story, the floor plan and the quest texts; Round 72 built
it with the user's room rulings ([Round 72](../planning/round72-plan.md) §2.9): every pack
room cut so that no pack can be walked round. Round 73 reshaped it
([concept](../planning/round73-expedition-redesign-concept.md) §4, §5): a mine still keeping
its books, order gone sour.

- **Size:** 128 × 32 × 128, six rooms in a line in The Stilled Seam's envelopes mirrored on x.
  The floor is a height map with stairs (Round 73), from y 5 (bay d's pay floor) to y 10 (the
  court's west gallery); the arrival, the chest and the waystones stand at y 8.

| Room | Holds |
|---|---|
| 0 Arrival | bent refuge beneath a low, sloping timber roof; boarded collapse, hooded benches, a raised bench along the east wall; start waystone under a lamp |
| 1 Timekeeper's office | square and flat on purpose, plank floor and wainscot; the timekeeper's desk under shelves with the shift board, three rows of clerks' desks with candles, a sunken cart siding along the south wall, cobwebs; pack a: 3 raiders, 2 miners; 1 ore |
| 2 Marking floor | terraces stepping down west in three levels, tally benches, a lava fall in the west wall; pack b: 3 raiders, 1 elite miner; 2 of 4 floor traps; 1 gem |
| 3 Wage hall | bay c steps down a level from the entry, lit pay tables on the east wall; bay d's sunken pay floor two levels deep round the rock screen's south; bones; packs c and d, 3 raiders and 1 elite miner each; the bypass and 1 of 2 floor traps per bay |
| 4 Audit court | a sunken audit floor round Nemm under a high ribbed canopy, the auditors' galleries west (two levels) and south; a lava fall in the north wall; Auditor Nemm, alone; 2 of 4 floor traps |
| 5 Store | flat and square on purpose: plank floor, lamp niches, coffers; chest, end waystone; 4 ore, 2 gem |

- **Passages:** the arrival's cut bends over a hump with a niche; the trap gallery between
  rooms 1 and 2 holds the wall trap (1 of 2 muzzles, every 2 s since Round 74) and stays
  straight where the fireball flies; the **grain drift** (room 2 to 3) and the **pay drift** (room 3 north, then
  east under a low roof into the court) are long, straight and dark on purpose, mossy, each
  dipping a node; the door's cut jogs into the store.
- **The ambush** (Round 73): two candidates, one in each drift, one armed per run. Its zone
  spans the drift; three Buried Miners (normal, melee) wait in two alcoves beside it, about
  half a room pack (`tools/r72_shift/balance.py`: about 48 % of a room pack's fighting time,
  35 % of its damage). It lies after the marking floor's and the wage hall's packs, out of
  every pack's notice and of the arrival's sight; the light at the drift's far end is in sight
  from the dark.
- **Light** from things that belong there: candles on the desks, lamps on the pay tables and
  coffers, lamp niches in the walls, torches at the trap gallery's muzzles and the door, posts
  and lanterns hung at the feet plus four (Nemm's height plus one), two lava falls. The
  fighting floor holds 4 everywhere and 6 on about 86 % (the build aims for 80 %, the proof asks 75 %).
- **Lava:** two falls (marking floor, court), each into a basin beside the fighting floor.
- **Critters:** two bats (arrival, store), two weevils (the arrival's cut, the trap gallery's
  widening) and a crawler (the pay drift's niche). **Particles:** paper over the office's
  desks and the pay tables, ash at both falls, dust in the arrival's cut and the store.
- **Mobs:** Skeleton Raiders and Buried Miners at the run's level: 12 raiders, 2 miners, 3
  elite miners and the boss, plus the ambush's 3 miners. Here the raiders are named by band
  (Shift Raider 40–49, Tallied Raider 50–59, Overdue Raider 60–69), the miners Buried Miner
  throughout.
- **No walking round** (proved on the template, `tools/r72_shift` on the shared proof): from
  every floor cell of rooms 1–4 a mob of that room notices a player within its view range
  (raider 16, miner 14, Nemm 20) and in sight, over the relief. No pack sees another; only
  cells of room 3's bypass are seen by both of its packs, so the party clears bay c before it
  walks there.
- **Auditor Nemm:** an elite on the raider's body, bow and attacks, with 14 × an elite's HP
  (20 × until Round 73, the user, 2026-11-10): 53,592 at 40, 113,232 at 60, 147,308 at 69. Every 12 s of a fight he marks his target's
  spot: the floor trap's ring and hit there 1.5 s later. He sees the whole court and drops
  nothing.
- **Ore:** eight shared places, five ore and three gem, of the run's tier (§1).
- **Chest, per player:** 1 Uncommon item, at 25 % a Rare item, a bag of 10 × a kill's coin
  bag at the run's level, 3–5 of the tier's bone and 1–2 of its flesh: Drilled Bone and
  Leathery Flesh at 40–49, Siege Bone and Scorched Flesh at 50–59, Unquiet Bone and
  Salt-Cured Flesh at 60–69.
- **Balance** (`tools/r72_shift/balance.py`, modelled): one normal per pack was added to the
  plan's roster, then Nemm's HP set the run. At 14 × (Round 73): about 9 minutes at every
  level up to 60, the boss about 2.7 of them; at 69 about 14 minutes, Nemm about 6.4, and the
  tank takes about 2.9 times the damage of level 40 in pools (at 20 × it was about 10
  minutes with a 3.9-minute boss, and 17 with 9.1 at 69). Round 73's longer drifts add about 8 s of walk.
- **Quest:** "Party: The Second Shift", level 40, from the six guild leaders: kill Auditor
  Nemm once, at any of its levels. The Expedition stays repeatable after the turn-in.

## 15. The Last Mint

A buried branding works behind a furnace that became a lava lake, at mob levels 60–69,
for four players (Round 72). Its [build plan](../planning/round72-last-mint.md) was
approved by the user and has the story, the texts and the lake's section. Round 72's
rulings ([Round 72](../planning/round72-plan.md) §2.9) made every floor flat and no pack
walkable round; Round 73 ([concept](../planning/round73-expedition-redesign-concept.md),
the user, 2026-11-09/10) gave it a floor of stairs, bent passages, light from what belongs
there, two ambush candidates, three lava falls, dressing, critters and embers, and kept the
route, the packs, the boss, the lake, the press, the traps, the ore, the door and the chest.

- **Size:** 128 × 64 × 128, The Stilled Seam's envelope mirrored on z. The floor is a
  height map from y 29 to 35 (the first air row), every change a stair (normal, inner,
  outer); the lake's tops and landings stand at 32, 24 nodes over its lava. Every walking
  cell keeps 5 nodes of air (the tallest mob, an elite Sentinel or Duewarden at 3.66, plus
  one), the wisp rooms 5 to 7. Eight rooms in a line, no room type next to its own:

| Room | Holds |
|---|---|
| 0 Arrival | stepped receiving vault: terraces climbing two steps west, a shallow dip in the south annex; the arrival and the start waystone on the upper terrace under lanterns |
| 1 Salvage bins | brick barrel vault over a sunken sorting floor (two levels down, a long gentle side), iron bin mouths in the wall and runners in the floor; pack a: 5 Lava Seeps; 1 ore |
| 2 Furnace room | low basalt vault with emberglass panels; a raised hearth with three furnace mouths of glowing coals along the east wall, a low rise by the way in, a lava fall in the south wall as its centrepiece; pack b: 3 Seeps, 1 elite Seep, 1 Ember Wisp; floor traps (2 of 4) |
| L Lava crossing | unchanged: tall basalt furnace throat; two landings, five 4 × 4 pillars, six level gaps of 2 nodes; wall shots (1 of 2, twice); lamps in the piers at the landings |
| 3 Cooling room | low slate vault; a slag heap of two levels against the iron rack bands, steep to the south; a small dip in the south-east; pack c: 3 Seeps, 1 elite Seep, 1 Wisp; 1 gem |
| 4 Press vestibule | iron coffer over basalt with emberglass; terraces climbing two steps west, a trough by the east wall, steel die cupboards; pack d: 1 elite Bedrock Sentinel, 3 Wisps; floor traps (2 of 4, one in the trough) |
| 5 Press floor | high basalt nave on four columns; **Duewarden** alone on a sunken arena, two rings down with a long side toward the door, lanterns round him, two emberglass eyes in the press's face, a lava fall in the east wall; floor traps (2 of 4) on the flat rim |
| 6 Store | a deliberately regular brick strongroom, flat and square on purpose; wood floor, candles in wall niches, a ring of lanterns over the chest and the end waystone; 4 ore, 2 gems |

- **Passages** bend, narrow and widen, with a niche or a stair run on the way: a step down
  to the bins, a stair up from the lake to the cooling room and down again before the
  vestibule, lower stretches under iron ties, mossy cobble in patches, bones in the niches.
  Two are long and straight on purpose, the ambush candidates.
- **Light:** emberglass lamps set in the masonry (walls and low vaults), lanterns on ropes
  in the high vaults, the furnace mouths' coals, candles in niches, the lava. Nothing hangs
  lower than 5 nodes over the floor; the rest sits in the walls. Every pack's floor has
  light 4 or more and mostly 6; the passages keep a lamp at a bend and are dark between.
- **The ambush** (§8, Traps): two candidates in one group, one armed per run. *The flue
  run*, north out of the bins and a long straight dark run east toward the glow of a lava
  fall at its end; *the drift*, a long straight dark run south between the cooling room and
  the vestibule, a lamp at each end. Each zone lies across the full width at light 0 with
  an alcove on either side; its pack is 3 Lava Seeps (normal, melee), about half a room
  pack by the balance model (0.44 of a room pack's fighting time, 0.32 of its damage).
  Both lie after pack a, out of every pack's notice and out of the arrival's sight.
- **Lava falls:** three besides the lake and its pillars: at the end of the flue run, in the
  furnace room's south wall, in the east wall of Duewarden's hall. Each runs down a recess
  into a small basin beside the floor; a pack's hits can push a player in, and no mob
  walks in (§7).
- **Critters:** two Cave Bats in the arrival's and the store's vaults, a Cave Crawler in
  the niche by the cooling room, a Bone Weevil in the niche before the reward door.
- **Particles:** embers rising at the three falls and over the lake, sparks at the furnace
  mouths and the press, dust in the arrival and the store: 200 live at most.
- **Rooms a pack cannot be walked round** (user, 2026-11-08): from every floor cell of a
  pack's room, at least one mob of that pack would notice the player (its view range: Seep
  10, Wisp 16, Sentinel 14, and sight over the relief). The relief lies mostly at the
  rooms' edges, and a mob or two stands on the higher ground; no floor cell lies in the
  sight of two packs. Duewarden's hall is larger: the reward door holds until he dies.
- **The lake:** lava at y 2–7 under the basin, every top at y 31, gaps of two node rows
  with no height change, tops four deep for the run-up: a walking jump carries about 2.65
  nodes and needs no sprint or class skill. The sides are vertical walls: no ledge, shelf
  or climb, and the tops are beyond one Blink from the lava. A fall is death: lava takes
  20 % of the actual pool a second through every shield, five ticks for a full pool, and
  Return Home is refused (§4). Two of four wall sockets fire across a gap's middle every
  2 s (6 until Round 74), the second group 1 s after the first; every top and landing is
  clear of their lines, so a player waits on a top, watches a shot pass, then jumps. A burst reaches
  whoever stands within 2 of the one it hit: cross one at a time.
- **Mobs:** 16 normal (11 Seeps, 5 Wisps), 3 elites (2 Seeps, 1 Sentinel) and the boss, and
  the armed ambush's 3 Seeps,
  every one at the run's level, with its family's name at every level. Wisps keep within
  the wisp rooms' seven nodes of air. The Seeps' Emberglass, the Wisps' Emberglass and the
  Sentinel's Rough Diamond go through the Expedition's drop filter: Slime Gel and Heavy
  Leather stay.
- **Duewarden:** the Bedrock Sentinel's body, melee and signalled frontal slam (the elite
  tier's), 14 × an elite's HP: 113,232 at 60, 147,308 at 69. No adds, no phases. His hall
  inside the envelope (48, 8)–(79, 39) is his range; traps never hurt him and never count
  as his attack. One fixed name over 60–69.
- **Ore:** eight shared places, five ore and three gems: Abyssal Crystal and Diamond at T6.
- **Chest, per player:** 1 Uncommon item, at 25 % a Rare item, both at the run's level, a
  bag of 10 × a kill's coin bag, 3–5 Stone Core, 1–2 Slime Gel.
- **Balance** (`tools/r72_mint/balance.py`, modelled): a run at 60 about 11 minutes, at 69
  about 16, the ambush under a minute, Duewarden about 2.5 and 6 minutes; traps and deaths
  come on top.
- **Quest:** "Party: The Last Mint" at level 60, from the six guild leaders: kill Duewarden
  once, at any of its levels.


The three expedition-specific paintings are exclusive 2% personal Reward Chest
rolls; see [decorations.md](decorations.md#original-wall-art) for their access and
formats. The normal per-player, per-run reward cache applies.
