# Expeditions

Repeatable group content in the Miner's Guild's name: a party, or one player, opens a
sealed mine far beyond the map, fights through it and takes the reward at its end.
Every run is written anew, so an Expedition can be played again and again.

**Decided** by the user, 2026-11-07; the framework and the level 20 Expedition are
implemented in Round 71 (`grug_expeditions`). This file owns the game rules and their
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

| Expedition | Level | Most players inside | Ore and gem tier | State |
|---|---|---:|---|---|
| The Stilled Seam | 20 | 3 | T2 | implemented |
| Level 30 | 30 | 3 | T3 | approved, not built |
| Level 40 | 40 | 4 | T4 | approved, not built |
| Level 50 | 50 | 4 | T5 | approved, not built |
| Level 60 | 60 | 4 | T6 | approved, not built |

The four later Expeditions follow on the proven format, after the user's test. Their
[outline](../planning/round71-expeditions-outline.md) holds proposals; nothing in it is
decided.

An Expedition lasts 10–20 minutes, is balanced for 3–4 players and runs in a line at
first. Floor plans are 2D on one main floor for now; the template format stays 3D.

## 2. Levels and entry

- The creator picks **+0 to +9** on top of the Expedition's level. That sets the level of
  every mob and the boss, the item level of their drops and of the chest. So level 60
  reaches 61–69 and T7.
- **Entry level:** run level − 2, at most 60. Level 60 needs 58, 61 needs 59, 62–69
  need 60.
- The dropdown offers only levels the **creator** may enter, for a party leader too.
- A party leader sees one row per member with their eligibility before creating. It warns
  and stops nobody.
- **Entering is a hard gate:** a player below the entry level cannot teleport in. Level
  20 at +1 (level 21) admits a level 19 player, at +2 (level 22) it does not.

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
- **Enter** at a registrar of the player's faction. It is refused in combat. That capital
  is where the way back leads.
- **Places:** entering takes one, for as long as the player stays in the party. Leaving
  the box keeps it; the player can go back in. So a larger party is full after the first
  3 or 4 entries, and only leaving the party frees a place.
- **Two waystones** stand inside: at the start, and in the reward room. Both lead to the
  capital the player came from, without a cooldown, and both are refused in combat.
- **Return Home** works inside, under its normal rules ([home travel](home_travel.md)).
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
- **Whoever logs in after their Expedition ended** stands in the capital they came from.
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
- **No building** at all, and no liquids. Short jump-and-run tasks may appear in the higher
  Expeditions.
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
- **The boss** is a pack of one: a wipe heals it and sends it home. Its death gives
  **credit only**: no 24-hour lockout, no direct reward and no drops at all, coin bag
  included; the chest pays. There is no other lockout timer: the run's length is the
  limiter ([world.md](world.md) R4). Credit counts per Expedition, at any of its levels.

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

- Ores and gems are minable nodes of the Expedition's own tier only (§1), also at +9.
- They are rare on the way, only after the first mob pack, and not too many. The reward
  room is somewhat richer: the real reward comes at the end.
- **Exception to [world.md](world.md) R4:** Expedition ore is renewable through an
  Expedition's reset only. A mined node comes back with the next run's template, and
  through nothing else.

## 12. Story and quests

Every Expedition has a small storyline and a storyline quest whose goal is killing the boss:
the Miner's Guild ran into trouble while mining and needs fighters. **All of these quests are
optional, level 60 included:** free, not on the chained story path, without the `story` flag.
So the rule for group quests below 51 holds ([quests](quests.md#group-quests-round-61)).

## 13. The Stilled Seam

The level 20 Expedition: an abandoned gold working held by spiders and golems. Its
[description](../planning/round71-l20-description.md) was approved by the user and has the
story, the floor plan and the texts.

- **Size:** 128 × 32 × 128, one floor, six rooms in a line.

| Room | Holds |
|---|---|
| 0 Arrival | start waystone |
| 1 Cart bay | pack a: 4 spiders; 1 Gold |
| 2 Prop room | pack b: 2 spiders, 1 elite golem; 1 Jade |
| 3 Sorting floor | packs c and d behind a rock screen: 3 spiders and 1 elite golem each |
| 4 Working face | [Flintback](biomes_mobs.md), alone |
| 5 Store | chest, end waystone; 4 Gold, 2 Jade |

- **Mobs:** 12 spiders, 3 elite golems and the boss. Spiders have 384 HP at 20 and 720 at 29,
  elites 1,152 and 2,160, Flintback 8 × an elite's: 9,216 and 17,280.
- **Ore:** eight shared nodes per run, all T2, also at +9.
- **Chest, per player:** 1 Uncommon (blue) item, at 25 % a Rare (yellow) item, a bag of 10 × a
  kill's coin bag at the run's level, 3–5 Spider Silk, 1–2 Coarse Spider Silk at 21–29, 1–2 Venom Gland at 50 %.
- **Quest:** "Party: The Stilled Seam", from the six guild leaders
  ([quests](quests.md)): kill Flintback once, at any of its levels. The Expedition stays
  repeatable after the turn-in.
