# Expeditions

Repeatable group content in the Miner's Guild's name: a party, or one player, opens a
sealed mine far beyond the map, fights through it and takes the reward at its end.
Every run is written anew, so an Expedition can be played again and again.

**Decided** by the user, 2026-11-07; the framework and The Stilled Seam (levels 20–69)
are implemented in Round 71 (`grug_expeditions`). This file owns the game rules and their
numbers. The [concept](../planning/round71-expeditions-concept.md) stays as the record of
the rulings; [Round 71](../planning/round71-plan.md) holds what shipped. How it is built:
[module guide](../technical/module-guide.md#expeditions),
[template format](../technical/expedition-template-format.md).

The word is **Expedition**, for players, in docs and in code.

A few details below are the coordinator's defaults, standing until the user rules on them
([completion](../planning/round71-plan.md#decisions-during-the-round)): sight as a pull, a list holding only who engaged, forced exits in combat, no boats, refined bars in drops, the
black arrival, one chest roll, lost chest contents and a boss without
ground drops.

## 1. The set

Three Expeditions, each over a wide level range (user, 2026-11-07, [concept
§9](../planning/round71-expeditions-concept.md#9-after-the-build-three-expeditions-user-2026-11-07)):

| Expedition | Mob levels | Most players inside | State |
|---|---|---:|---|
| The Stilled Seam | 20–69 | 3 at every level | implemented |
| The Second Shift | 40–69 | 4 | implemented (Round 72) |
| The Last Mint | 60–69 | 4 | implemented in Round 72 (§15) |

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
Expedition at a time. Anyone who does not belong to it is teleported out at once.

- **Creating:** at the **Expedition Registrar**, in a capital's guild house
  ([settlements](settlements.md)). It serves its own faction. A party leader creates a
  party-owned Expedition, a player without a party a player-owned one; another party
  member cannot create one. Solo is allowed; the content stays balanced for a group.
- **A solo owner invites someone** and so leads a new party: the Expedition becomes the
  party's.
- **A solo owner joins a foreign party:** the Expedition ends at once, the owner is
  teleported out if inside, and leaving that party does not win it back. The invitation
  warns of this ([parties](parties.md)).
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
  the player's owner while they may enter it (owner, ready or under way, level, places);
  otherwise it says in one line why, or with no Expedition points to the Registrar.
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
  both open the ordinary waystone window without the Expeditions tab: the player travels
  to any of their discovered waystones or their Claim Stone, by the waystones' rules (no
  cooldown, refused in combat). The Expedition's waystones are never a destination. A
  trip out keeps the place and ends no run; the player leaves its packs' lists as they
  leave the box.
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
  A notice names the reason.
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
  respawns but a partly killed pack (below).
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

Two trap types, the same in every Expedition (user, 2026-11-07, [Round 72](../planning/round72-plan.md)
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
- **Wall trap:** a fireball on a fixed period (6 or 8 s in the plans), always, from its group's offset after the
  Expedition is ready, along a fixed direction at 8 nodes a second; no targeting. Stone stops it. A player in its way
  bursts it: the same hit to every player within 2 nodes. A shot with nobody of the run within 32 nodes of its line is
  left out, the rhythm kept.
- **A boss's marked spot** (The Second Shift's Auditor Nemm): the floor trap's ring and hit on one position, once;
  his reset or death takes the hit back. One that had a player in its area is his attack for the 15 s rule.

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

## 13. The Stilled Seam

An abandoned gold working held by spiders and golems, at mob levels 20–69. Its
[description](../planning/round71-l20-description.md) was approved by the user and has the
story, the floor plan and the texts.

- **Size:** 128 × 32 × 128, one floor, six rooms in a line.

| Room | Holds |
|---|---|
| 0 Arrival | start waystone |
| 1 Cart bay | pack a: 4 spiders; 1 ore |
| 2 Prop room | pack b: 2 spiders, 1 elite golem; 1 gem |
| 3 Sorting floor | packs c and d behind a rock screen: 3 spiders and 1 elite golem each |
| 4 Working face | [Flintback](biomes_mobs.md), alone |
| 5 Store | chest, end waystone; 4 ore, 2 gem |

- **Mobs:** 12 spiders, 3 elite golems and the boss. Spiders have 384 HP at 20, 2,696 at 60
  and 3,507 at 69; elites 1,152, 8,088 and 10,522; Flintback 8 × an elite's: 9,216, 64,704
  and 84,176. Every mob keeps its name at every level; Flintback's is one fixed name.
- **Ore:** eight shared places per run, five ore and three gem, of the run's tier (§1).
- **Chest, per player:** 1 Uncommon (blue) item, at 25 % a Rare (yellow) item, both at the
  run's level as item level, and a bag of 10 × a kill's coin bag at the run's level. The
  materials are what its spiders drop in each mob band: 3–5 Raw Silk and, at 50 %, 1–2 Venom
  Glands at every level; 1–2 Coarse Spider Silk at 21–30, Layered Spider Web at 31–40, Glass
  Spider Silk at 51–69; 1–2 Venom Sacs at 50 % at 31–40 and always at 41–50.
- **Balance** (`tools/r71_l20/balance.py`, modelled): up to 60 every level plays as 20 does,
  a run about 9 minutes. At 61–69 the level malus stretches packs and boss: at 69 a run
  is about 13.5 minutes, the boss about 4.8, and the tank takes about 2.9 times the
  damage of level 20 in pools.
- **Quest:** "Party: The Stilled Seam", from the six guild leaders
  ([quests](quests.md)): kill Flintback once, at any of its levels. The Expedition stays
  repeatable after the turn-in.

## 14. The Second Shift

A working mine whose whole shift is dead, kept at work by Auditor Nemm's branded pay, at
mob levels 40–69 for four players. Its [build plan](../planning/round72-second-shift.md) was
approved by the user and has the story, the floor plan and the quest texts; Round 72 built
it with the user's room rulings ([Round 72](../planning/round72-plan.md) §2.9): every floor
flat, no dais, and every pack room cut so that no pack can be walked round.

- **Size:** 128 × 32 × 128, one floor (the first air cell at y 8), six rooms in a line: The
  Stilled Seam's envelopes mirrored on x, cut smaller.

| Room | Holds |
|---|---|
| 0 Arrival | start waystone |
| 1 Timekeeper's desk | pack a: 3 raiders, 2 miners; the shift board; 1 ore |
| 2 Marking floor | pack b: 3 raiders, 1 elite miner; 2 of 4 floor traps; 1 gem |
| 3 Wage room | packs c and d, 3 raiders and 1 elite miner each, a rock screen between them with an 8-node bypass; 1 of 2 floor traps per bay |
| 4 Audit court | Auditor Nemm, alone; 2 of 4 floor traps |
| 5 Store | chest, end waystone; 4 ore, 2 gem |

- **The passage from room 1 to room 2** holds the wall trap: 1 of 2 muzzles, every 8 s.
- **Mobs:** Skeleton Raiders and Buried Miners at the run's level: 12 raiders, 2 miners, 3
  elite miners and the boss. Here the raiders are named by band (Shift Raider 40–49,
  Tallied Raider 50–59, Overdue Raider 60–69), the miners Buried Miner throughout.
- **No walking round** (proved on the template, `tools/r72_shift`): from every floor cell of
  rooms 1–4 a mob of that room notices a player within its view range (raider 16, miner 14,
  Nemm 20) and in sight. No pack sees another; only cells of room 3's bypass are seen by both
  of its packs, so the party clears bay c before it walks there.
- **Auditor Nemm:** an elite on the raider's body, bow and attacks, with 20 × an elite's HP:
  76,560 at 40, 161,760 at 60, 210,440 at 69. Every 12 s of a fight he marks his target's
  spot: the floor trap's ring and hit there 1.5 s later. He sees the whole court and drops
  nothing.
- **Ore:** eight shared places, five ore and three gem, of the run's tier (§1).
- **Chest, per player:** 1 Uncommon item, at 25 % a Rare item, a bag of 10 × a kill's coin
  bag at the run's level, 3–5 of the tier's bone and 1–2 of its flesh: Drilled Bone and
  Leathery Flesh at 40–49, Siege Bone and Scorched Flesh at 50–59, Unquiet Bone and
  Salt-Cured Flesh at 60–69.
- **Balance** (`tools/r72_shift/balance.py`, modelled): one normal per pack was added to the
  plan's roster, then Nemm's HP set the run: about 10 minutes at every level up to 60, the
  boss about 3.9 of them; at 69 about 17 minutes, Nemm about 9.1, and the tank takes about
  2.9 times the damage of level 40 in pools.
- **Quest:** "Party: The Second Shift", level 40, from the six guild leaders: kill Auditor
  Nemm once, at any of its levels. The Expedition stays repeatable after the turn-in.

## 15. The Last Mint

A buried branding works behind a furnace that became a lava lake, at mob levels 60–69,
for four players (Round 72). Its [build plan](../planning/round72-last-mint.md) was
approved by the user and has the story, the texts and the lake's section; the round's
rulings changed two things ([Round 72](../planning/round72-plan.md) §2.9): every floor is
flat (no dais), and no pack can be walked round.

- **Size:** 128 × 64 × 128, The Stilled Seam's envelope mirrored on z, one floor at y 31
  over a lake 24 nodes deep. Eight rooms in a line:

| Room | Holds |
|---|---|
| 0 Arrival | start waystone |
| 1 Salvage bins | pack a: 5 Lava Seeps; 1 ore |
| 2 Furnace room | pack b: 3 Seeps, 1 elite Seep, 1 Ember Wisp; floor traps (2 of 4) |
| L Lava crossing | two landings, five 4 × 4 pillars, six level gaps of 2 nodes; wall shots (1 of 2, twice) |
| 3 Cooling room | pack c: 3 Seeps, 1 elite Seep, 1 Wisp; 1 gem |
| 4 Press vestibule | pack d: 1 elite Bedrock Sentinel, 3 Wisps; floor traps (2 of 4) |
| 5 Press floor | **Duewarden**, alone, before the static press and its brand; floor traps (2 of 4) |
| 6 Store | chest, end waystone; 4 ore, 2 gems |

- **Rooms a pack cannot be walked round** (user, 2026-11-08): from every floor cell of a
  pack's room, at least one mob of that pack would notice the player (its view range: Seep
  10, Wisp 16, Sentinel 14, and sight). The rooms are smaller than the plan's envelopes and
  the members spread over them; no floor cell lies in the sight of two packs. Duewarden's
  hall is larger: the reward door holds until he dies.
- **The lake:** lava at y 2–7 under the basin, every top at y 31, gaps of two node rows
  with no height change, tops four deep for the run-up: a walking jump carries about 2.65
  nodes and needs no sprint or class skill. The sides are vertical walls: no ledge, shelf
  or climb, and the tops are beyond one Blink from the lava. A fall is death: lava takes
  20 % of the actual pool a second through every shield, five ticks for a full pool, and
  Return Home is refused (§4). Two of four wall sockets fire across a gap's middle every
  6 s, the second group 3 s after the first; every top and landing is clear of their
  lines, so a player waits on a top, watches a shot pass, then jumps. A burst reaches
  whoever stands within 2 of the one it hit: cross one at a time.
- **Mobs:** 16 normal (11 Seeps, 5 Wisps), 3 elites (2 Seeps, 1 Sentinel) and the boss,
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
- **Balance** (`tools/r72_mint/balance.py`, modelled): a run at 60 about 10 minutes, at 69
  about 15, Duewarden about 2.5 and 6 minutes; traps and deaths come on top.
- **Quest:** "Party: The Last Mint" at level 60, from the six guild leaders: kill Duewarden
  once, at any of its levels.
