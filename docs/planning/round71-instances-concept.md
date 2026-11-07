# Round 71 — instances: concept

Concept from the user's notes and rulings of 2026-11-07, checked against the
code at `829be5dd`. This is the rulings' source for [Round 71](round71-plan.md).
Everything is ruled by the user unless it is marked as a proposal. Players see
instances as **Expeditions**.

Plans: [Round 71](round71-plan.md), [Round 70](round70-plan.md). Round 70 §2.10
(item levels, kings, dragons) comes first.

## 1. Scope and order

1. The framework and the level 20 instance.
2. **Before the level 20 instance is built, the user gets a short description
   document to read and approve.**
3. The user tests it. The other four instances follow on the proven format.

## 2. The instance

- A cuboid template. The hull and most geometry are indestructible stone.
  Anything destructible is so on purpose: a tunnel the story asks for, or ore
  and gem nodes.
- Lasts 10–20 minutes, balanced for 3–4 players, linear at first.
- The first instances are planned as 2D floor plans on one main floor (user and
  coordinator, 2026-11-07). Several y levels stay out for now; the template format
  stays 3D.
- First set: levels 20, 30, 40, 50 and 60.
- Mobs do not respawn. What is dead stays dead.
- **Maximum players inside:** 3 at levels 20 and 30, 4 at levels 40–60. Fewer are
  always allowed. Entering takes a place; only leaving the party frees it, so a
  larger party is full after the first 3–4 entries.
- **No building** at all. Short jump-and-run tasks may appear in the higher
  instances, for example a lava lake with pillars at level 60.
- **No mounts:** neither riding nor flying.
- Proposal: return travel works inside; it leaves the instance but not the party.
- Death inside: the player respawns at the start waystone.

## 3. Levels

- The leader picks the mob level in a dropdown, **+0 to +9**. It sets mob and boss
  level, the item level of rewards and of drops from **all** mobs in the instance
  (a mob drops at its own level), so the level 60 instance reaches 61–69 and T7.
- **Entry level:** instance level minus 2, at most 60: level 60 needs 58, 61 needs
  59, 62–69 need 60.
- Every instance mob gets its level per entity through `_grug_spawn_level` /
  `grug_mobs.relevel` (`levels.lua`), which replaces the cap. `_grug_fixed_level`
  is one value per mob definition and cannot carry +0 to +9.
- `roll_mob_gear` caps non-boss mobs at item level 60 (`grug_quality/init.lua`).
  This round lifts it for instance mobs only.

## 4. Access

- An instance is bound to one party id. Anyone not in exactly this party is
  teleported out at once, and so is anyone who leaves the party.
- The party leader activates an instance in a capital; members teleport in from
  there. Proposal: in the guild house, a registrar NPC on the clerk's socket,
  which exists in all six capitals and needs no template change.
- Before creating it, the leader sees a dialog with each member's eligibility.
  Example: level 20 at +5 needs level 23, so a level 22 member gets a warning. It
  only warns; the leader may still create it.
- Inside are two waystones: the arrival at the start, and one at the end that
  works after completion and only leads back.

**Release**

- A slot is reserved for only 10 minutes while no member is inside, both after
  creation and after the run began. An offline member does not count.
- After those 10 minutes, or when the party dissolves, the binding ends. Nobody
  can enter any more and the slot is free again.
- A player who logs in after their instance was released goes straight home.
- Proposal: the 10 minutes start when the instance is ready, and a server restart
  ends every binding, which falls under the login rule above.

## 5. Slots and preparation

- **The server alone clears and fills instances; no instance content comes from
  the map generator.** Instances need no map reset.
- Slots lie far out in the ocean, outside the normal map. They are generic and
  equal, sized for the largest instance. Any slot holds any instance.
- The minimap shows only ocean there, so it gives no orientation, but it shows
  party members correctly.
- **One operation:** on activation, clear the box and write the whole template
  at the chosen level. There is no journal of dug blocks or killed mobs, and the
  result is always the planned layout.
- **Low priority, no impact on the running game.** The server prepares an
  instance as fast as it currently can; 1–2 minutes is fine. It need not prepare
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

- Every instance has a small storyline, written by Codex, and a storyline quest
  whose goal is killing the boss. It may link to the main story.
- **All of these quests are optional, level 60 included:** free, not on the
  chained story path, without the `story` flag.
- Story hook: the Miner's Guild ran into trouble while mining and needs fighters.

## 7. Rewards

- A reward room lies behind the boss; its door opens when the boss is dead.
- Its chest has **a separate inventory per player**, with items, Bags of Coins and
  crafting materials from an instance-specific loot table at the chosen level.
- Ores and gems are not in the chest. They are minable nodes of the instance's own
  tier only:

| Instance | Ore and gem tier |
|---|---|
| Level 20 | T2 |
| Level 30 | T3 |
| Level 40 | T4 |
| Level 50 | T5 |
| Level 60 | T6 |

- Nodes are rare on the way, only after the first mob pack, and not too many. The
  reward room is somewhat richer: the real reward comes at the end.
- **Exception to world rule R4:** instance ore is "renewable", but only through an
  instance reset. Update `world.md` R4.
- **Instance bosses have no 24-hour lockout** (`bosses.lua` `LOOT_LOCKOUT` must not
  apply), and there is no other lockout timer: `world.md` R4 pays materials in
  danger and travel, not by waiting. The run length is the limiter.

## 8. Checks for the plan

- **XP:** instance mobs pay XP. 10–20 minutes at +9 needs a check against the level
  pace (`progression.md`).
- `tools/r29_e4/income.py --check`, because the chests hold coins.
- The rule for group quests below level 51 (Round 61) holds, because these quests
  are optional.
