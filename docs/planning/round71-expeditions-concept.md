# Round 71 — Expeditions: concept

Concept from the user's notes and rulings of 2026-11-07, checked against the
code at `829be5dd`. This is the rulings' source for [Round 71](round71-plan.md).
Everything is ruled by the user unless it is marked as a proposal. The word is
**Expedition**, for players and in docs, briefs and code (user, 2026-11-07).
**This file stays as the record of the rulings; [`expeditions.md`](../design/expeditions.md)
owns the rules as they stand.**

Plans: [Round 71](round71-plan.md), [Round 70](round70-plan.md). Round 70 §2.10
(item levels, kings, dragons) comes first.

## 1. Scope and order

1. The framework and the level 20 Expedition.
2. **Before the level 20 Expedition is built, the user gets a short description
   document to read and approve.**
3. The user tests it. The other four Expeditions follow on the proven format.

## 2. The Expedition

- A cuboid template. The hull and most geometry are indestructible stone.
  Anything destructible is so on purpose: a tunnel the story asks for, or ore
  and gem nodes.
- Lasts 10–20 minutes, balanced for 3–4 players, linear at first.
- **Every Expedition needs a tank and a healer (user, 2026-11-07).** The Warrior need not
  be skilled defensively and the healer need not be skilled for healing, but without a
  Warrior and a healer an Expedition is hard or impossible. Balance is for a Warrior, a
  Priest and the rest of the party at player level = Expedition level.
- The first Expeditions are planned as 2D floor plans on one main floor (user and
  coordinator, 2026-11-07). Several y levels stay out for now; the template format
  stays 3D.
- First set: levels 20, 30, 40, 50 and 60.
- **Packs (user, 2026-11-07):** a pack is pulled whole: engaging one mob pulls all of
  it. Normal de-aggro does not apply: a pulled pack never gives up, and players stay in
  combat until the pack is dead or they leave the Expedition. If the pack leaves combat
  because all its players are dead or gone, it returns and its dead mobs respawn at
  once. A fully dead pack stays dead; nothing else respawns. A dead player leaves the
  pack's list, and a player back at the start waystone is not hunted. Waystones and
  Return Home stay refused in combat, so a pulled pack ends in a win, a death or a
  logout. A mob left behind jumps after its player, because a mob in an inactive block
  would otherwise hold them in combat for ever.
- **Maximum players inside:** 3 at levels 20 and 30, 4 at levels 40–60. Fewer are
  always allowed. Entering takes a place; only leaving the party frees it, so a
  larger party is full after the first 3–4 entries.
- **No building** at all. Short jump-and-run tasks may appear in the higher
  Expeditions, for example a lava lake with pillars at level 60.
- **No mounts:** neither riding nor flying.
- Death inside: the player respawns at the start waystone. Round 70's death
  penalty applies inside too (user, 2026-11-07).

## 3. Levels

- The creator picks the mob level in a dropdown, **+0 to +9**. It sets mob and boss
  level, the item level of rewards and of drops from **all** mobs in the Expedition
  (a mob drops at its own level), so the level 60 Expedition reaches 61–69 and T7.
- **Entry level:** Expedition level minus 2, at most 60: level 60 needs 58, 61 needs
  59, 62–69 need 60.
- Every Expedition mob gets its level per entity through `_grug_spawn_level` /
  `grug_mobs.relevel` (`levels.lua`), which replaces the cap. `_grug_fixed_level`
  is one value per mob definition and cannot carry +0 to +9.
- `roll_mob_gear` caps non-boss mobs at item level 60 (`grug_quality/init.lua`).
  This round lifts it for Expedition mobs only.

## 4. Access

- **An Expedition has one owner:** one player or one party (user, 2026-11-07).
  Anyone who does not belong to the owner is teleported out at once, and so is
  anyone who leaves the owning party.
- **Who creates:** a party leader creates a party-owned Expedition, a player
  without a party a player-owned one, both in a capital. A party member who is not
  the leader cannot create one. In the guild house, a registrar NPC on the clerk's
  socket, which exists in all six capitals and needs no template change.
- **Solo is allowed.** The content stays balanced for 3–4 players.
- **Changes of owner:**
  - A player-owned Expedition's owner invites someone and so leads a new party: the
    Expedition becomes party-owned, and its members may enter.
  - That owner joins a foreign party instead: the Expedition ends, the owner is
    teleported out if inside, and it cannot be won back by leaving that party. The
    invitation box warns that accepting ends the own Expedition.
  - A party falls to one member and dissolves: the last member becomes the
    Expedition's owner.
- **Level:** the dropdown offers only levels the creator may enter, for a party
  leader too. Before creating, the leader sees a dialog with each member's
  eligibility, which warns and does not stop the creation. **Entering is a hard
  gate:** a player below the entry level cannot teleport in. Example: level 20 at +1
  (level 21) admits a level 19 player, level 20 at +2 (level 22) does not.
- Inside are two waystones: the arrival at the start, and one in the reward room.
- **Leaving:** both waystones lead back to the capital the player came from, without
  a cooldown. Return Home works inside and goes home under its normal rules. Neither
  leaves the party.

**Release**

- An Expedition is reserved for only 10 minutes while no owner or member is inside,
  both after it is ready and after the run began. So a ready Expedition must be
  entered within 10 minutes. An offline member does not count.
- After those 10 minutes the Expedition ends. Nobody can enter any more and the slot
  is free again.
- **Logging out in combat with a pack counts as a death (user, 2026-11-07),** with the
  penalty, and takes the player off the pack's list. At the next login that player stands
  at the start waystone if the Expedition still belongs to them. Out of combat a logout
  costs nothing and the player comes back where they stood. Whoever logs in after their
  Expedition ended stands in the capital they came from.
- A server restart ends every Expedition, which falls under the login rule above.

## 5. Slots and preparation

- **The server alone clears and fills Expeditions; no Expedition content comes from
  the map generator.** Expeditions need no map reset.
- Slots lie far out in the ocean, outside the normal map. **There are 100 slots**
  (user, 2026-11-07), generic and equal, sized for the largest Expedition. Any slot
  holds any Expedition; the first free one is taken, so only as many are ever used
  as run at once. With no slot free the creator gets a refusal with a notice.
- The minimap shows only ocean there, so it gives no orientation, but it shows
  party members correctly.
- **One operation:** on activation, clear the box and write the whole template
  at the chosen level. There is no journal of dug blocks or killed mobs, and the
  result is always the planned layout.
- **Low priority, no impact on the running game.** The server prepares an
  Expedition as fast as it currently can; 1–2 minutes is fine. It need not prepare
  several at once.
- The dialog says something like "Your expedition is being prepared...". Nobody
  can enter before it is ready. The leader gets a short notice when it is.
- **The lane checks** what makes sense for performance: step size, emerge, and
  how many preparations run at once. Measure in the engine, with players online.

**Proposals for the lane:**

- Slots below the seabed, far beyond the map (about x 8000 and more), on a fixed
  grid. Off-map columns already resolve to `deep_ocean` and a chunk plans and
  writes there; the seabed lies around y −23.
- The open sea is immutable at every y (`world.md`), so the boxes need an
  exception, or ore cannot be dug.
- The world map must handle party arrows far outside its bounds.
- Natural spawns stay out of the box, the Kraken included.
- Spawn by encounter room when the party comes near, as the rift boss does.
- Bosses use the `bosses.lua` ledger for credit only, and its direct rewards must
  not bypass the chest.

## 6. Story

- Every Expedition has a small storyline, written by Codex, and a storyline quest
  whose goal is killing the boss. It may link to the main story.
- **All of these quests are optional, level 60 included:** free, not on the
  chained story path, without the `story` flag.
- Story hook: the Miner's Guild ran into trouble while mining and needs fighters.

## 7. Rewards

- A reward room lies behind the boss; its door opens when the boss is dead.
- Its chest has **a separate inventory per player**, with items, Bags of Coins and
  crafting materials from an Expedition-specific loot table at the chosen level.
- Ores and gems are not in the chest. They are minable nodes of the Expedition's own
  tier only:

| Expedition | Ore and gem tier |
|---|---|
| Level 20 | T2 |
| Level 30 | T3 |
| Level 40 | T4 |
| Level 50 | T5 |
| Level 60 | T6 |

- Nodes are rare on the way, only after the first mob pack, and not too many. The
  reward room is somewhat richer: the real reward comes at the end.
- **Exception to world rule R4:** Expedition ore is "renewable", but only through an
  Expedition reset. Update `world.md` R4.
- **Expedition bosses have no 24-hour lockout** (`bosses.lua` `LOOT_LOCKOUT` must not
  apply), and there is no other lockout timer: `world.md` R4 pays materials in
  danger and travel, not by waiting. The run length is the limiter.

## 8. Checks for the plan

- **XP:** Expedition mobs pay XP. 10–20 minutes at +9 needs a check against the level
  pace (`progression.md`).
- `tools/r29_e4/income.py --check`, because the chests hold coins.
- The rule for group quests below level 51 (Round 61) holds, because these quests
  are optional.

## 9. After the build: three Expeditions (user, 2026-11-07)

These rulings replace the first set of five and the +0 to +9 dropdown of §2 and §3.

- **Three Expeditions instead of five**, each selectable over a wide level range:

| Expedition | Mob levels | Players |
|---|---|---|
| The Stilled Seam | 20–69 | 3 at every level |
| The Second Shift | 40–69 | 4 |
| The Last Mint | 60–69 | 4 |

- **Every 10 levels the tier follows:** reward, ore and gem nodes are T2 at 20–29,
  T3 at 30–39, T4 at 40–49, T5 at 50–59, T6 at 60–69.
- **Selection in two steps:** a tier dropdown, which also names the tier's ore and
  gems, then a level dropdown inside that tier.
- **A player may create exactly what they may enter:** entry level min(level − 2, 60),
  so level 29 creates up to 31, level 59 up to 61, level 60 everything. This is the
  built rule; only the dropdown changes.
- Balance stays at player level = Expedition level. Players are capped at 60, so 61–69
  is played at 60 with the level malus: the top of each range is meant to be hard.
- The Stilled Seam is widened in Round 71 (lane RANGE). The Second Shift and The Last
  Mint are designed now and built in Round 72, after the user's GUI test of Rounds 70
  and 71.
- **Low effort first:** no big new mechanics. Level 60 must also be dangerous by its
  mechanics: The Last Mint has lava pillars in a lava lake; a fall is death, there is no
  way out of the lake. Lava already takes 20 % of the pool per second.
- **Traps, two types only**, never hurting or noticing mobs, their spots chosen at random
  on each creation:
  1. **Floor trap:** an invisible trigger. Stepping on it shows a muted red particle ring
     for 1.5 s, like the Mage's Meteor warning and distinct from player effects, then
     deals strong damage inside the ring. It rearms 10 s after firing and stays visible
     for the rest of that run after its first firing (coordinator default).
  2. **Wall projectile:** fires on a fixed period, always, a clearly visible fireball
     that deals area damage where it hits a player.
- **Ore at T6 is Abyssal Crystal**, the gem Diamond (user, 2026-11-07): an ore place holds
  the ore its tier's rock is mined for.
- **Expeditions support mining, they do not replace it (user, 2026-11-07):** a run's ore
  and gems stay clearly below what the same time of ordinary mining in that tier yields.
