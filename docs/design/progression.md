# Progression — Pacing, Death, Reward Cadence

Decided rules (established 2026-08-06; housing milestone revised in Round 25,
2026-09-29).
Rounds 14–15 implement 66 starter quests and 36 optional local quests;
the broader named-zone WP9 story remains open.

## 1. Leveling pace

- **Level 60 in ~10–20 played hours** (2–3 evenings) — deliberately much
  faster than WoW. The endgame (PvP, apex bosses, housing, jobs) is the
  game; leveling is the on-ramp.
- Current curve is quadratic. After the Round 16 kill-XP increase, normal
  same-level solo kills award `15L` XP before racial bonuses: the
  `(200L - 100)` interval needs about 7 kills at level 1 and approaches
  13.3 kills at higher levels without quests. Tune with playtests, not redesigns.
- **Rested XP** (WP21): logging out at an innkeeper accrues a rested
  bonus — rewards the irregular play patterns of a small server.

## 2. Reward cadence (the "new verbs" schedule)

Levels must keep delivering *decisions and buttons*, not just stats:

**The trees are decided.**
[skill_trees.md](skill_trees.md) (revision 2, 2026-09-16) defines
two trees per class on the cadence below, works the arithmetic out for every
milestone, and lists every talent, keystone and capstone for all **four**
classes — the fourth being the Scout ([scout.md](scout.md)). Its §6 records
that the design has no remaining open decision.

The three bullets below were rewritten on **2026-09-16** by the user's
rulings; the superseded text is named in `skill_trees.md` §5.2.

- **1 talent point every 2 levels, the first at level 2** (30 points total
  at 60); a talent tree holds **28 ranks**, so a class holds 56 — you can fill
  **one whole tree** (28 of the 30 points) or spread over both with one
  prioritised, and a full tree is never forced (WP11). *(Supersedes "1 talent point every
  3 levels (20 points total at 60); 2 trees × 5 talents × 3 ranks".)*
- Each tree carries **two playstyle directions (chains)**, rank counts vary
  **3-5** by talent strength, and dependencies are of both kinds: points
  spent in the tree, and hard chains. Per tree: **two keystones and one
  capstone**, and the capstone hangs on its own chain and has **one rank**.
  **Per tree at most ONE keystone adds a new active "main skill"** (user
  rulings 2026-09-16); the other keystone and the capstone **improve or
  replace** a button the player already has, so no build carries more than two
  extra hotbar keys. The new skill is the "new ability every ~10 levels" beat
  (e.g. Renew, the Priest healing tree's keystone). **A character reaches
  exactly one capstone**: it costs 21 of the 30 points in a single tree, which
  is level 42, and two would cost 42. *(Supersedes "9 of 10 talents are numeric
  modifiers; exactly one capstone per tree, unlocked at 8+ points in that
  tree, and every capstone is a NEW active main skill".)*
- **New skills come only from the tree**; the base kit granted at class
  choice stays, and talents improve its numbers. **Respec for money in the
  talent UI — there is no class trainer and no NPC**; the price is **five
  minutes of measured reliable net solo income** at the character's bracket
  (`economy.md` §3/§4.1), and **the first respec of a character is free**. A
  respec is a **full reset**, and **class change is removed from the game
  entirely, for admins too**. *(Supersedes "Respec at the class trainer
  for gold". `economy.md` §4, `items_crafting.md` §8.3 and `world.md` §1 now
  state the same no-trainer rule.)*
- **Level 20 — Claim Stone:** the Housing Manager in every capital hands out
  the player's one free, soulbound Claim Stone. It claims a 101 × 101 home in
  the player's own level-11–30 home zones while it is fuelled
  ([housing.md](housing.md)). There are no claim tiers, upgrades or
  additional stones, and a claim never buys mining depth or a private
  material source.

## 3. Death rules (MVP — deliberately simple)

Revised 2026-09-23, Round 18:

- Every death respawns at the bound innkeeper home with full inventory
  ([home_travel.md](home_travel.md)). No corpse run or extra durability-on-death.
- **No death causes XP loss**, including PvE, PvP and environmental deaths.
  No replacement penalty is introduced; travel back remains a consequence.
- XP is capped at the cumulative threshold for level 60; overflow from normal
  rewards and `/xp give` is discarded. The command reports the actual award.
- On a real upward level transition, living characters refill HP and mana after
  final stats recompute; Warrior rage remains unchanged. One gold particle burst
  occurs even for a multi-level grant. Join, equipment recalculation and downward
  level changes do not refill; an XP grant does not resurrect a dead character.

## 4. Quest structure & level gates

- Main-questline beats use hard `min_level` gates (`story.md`).
- Quest descriptions show their minimum level and named prerequisite quests.
- Fixed XP rewards use the authored target level rather than the receiver's
  level: ordinary quests grant 15–25% of that level interval, while a
  substantial chain finale grants 30–40%. The starter catalog uses 20% for
  ordinary quests and 35% for its camp finale. These rewards do not scale at
  hand-in.
- The final quest at each starting settlement is handed in to the next
  regional giver, so completion and the following regional quest meet at the
  same NPC.
- First PvP quests begin in the level-31–40 contested approaches and
  Battlegrounds entry, never below level 31 (`world_zones.md` §§2/8).
- Gather and kill objectives use stable named-zone ids and authored biome/
  resource palettes so progression teaches exploration rather than old radial
  ring coordinates.

## Quest participation

Kill quests use the same per-mob damage/effective-heal participation as shared
XP, preserving its current online/40-node eligibility and existing XP splitting.
Party membership confers no automatic credit. Quest counters award a full kill
to each eligible participant with the matching active quest; zero XP from a
gray mob does not itself erase quest credit. See `quests.md`.

## XP presentation

The numeric XP HUD line is replaced with a gold progress bar directly above
the hotbar, 360×6 HUD units (life remains 180×16). A compact label to its right
shows the level and current interval progress, for example
`Lv 8 (520/1500)`. The bar fills fully at maximum level. `/xp` reports exact
XP; a server administrator can grant a validated positive amount to an online
player with `/xp give <player> <amount>`. All offsets use the shared HUD layout
owner.

## Kill XP

Eligible mob-kill XP is increased by 50% at the shared settlement boundary,
before the existing participant split. The one-settlement guard, 40-node
eligibility, per-recipient gray rule, faction refusal and race bonus remain
unchanged. Quest rewards and administrator grants are not multiplied.

## Gathering XP

Round 24 ruling 28 (2026-09-29). XP sources are mob kills, quest rewards,
administrator grants and gathering. Every natural ore or gem node a player digs
and every fish a player catches gives

`XP = factor × min(reference level, player level + 5)`, rounded half up,

| Source | Factor | Reference level |
|---|---:|---|
| ore node (every natural resource node that is not a gem) | 1.5 | 10 × harvest tier: T1 10 … T5 50 |
| gem node (the six regional G1/G2 gems) | 3 | 10 × harvest tier: G1 (T2) 20, G2 (T4) 40 |
| fish (not junk from the catch table) | 5 | 10 × the water's zone band: 10 … 60 |

- There is no gray rule: T1 ore always pays (15 XP at level 5 and above).
- Examples: coal at level 1 gives 9 (1.5 × 6), at level 2 gives 11 (10.5
  rounded up); a G2 gem at level 30 gives 105; a band-6 fish at level 60
  gives 300.
- The factors and the formula live in one place, `grug_xp.GATHERING_XP_FACTOR`
  and `grug_xp.gathering_xp` (`mods/PLAYER/grug_xp/init.lua`); XP is added
  with source `gathering`, which carries no race or class bonus. The
  Goldsmith's extra raw gem is an item bonus and adds no XP.
- Only a successful player dig of a natural resource node (the
  `grug_materials` harvest callback) and a reeled-in fish pay. There is no
  anti-cheat or autoclicker check (user ruling). A caught fish shows its XP in
  the catch notice ("Caught: Silver Trout (+100 XP)"); ore XP shows on the XP
  bar only.

## Current fixed quest reward table

Rewards below are per quest, shared by the six racial variants except where a
race's quest has its own target level: the Orc Starter 4 (the Husk patrol) is a
level-5 quest (Round 24; the Husk spawns in Sunscar from level 4) and grants the
level-5 reward, 180 XP. They are fixed catalog values before any applicable
racial modifier; no runtime level scaling.

| Quest position / work | Intended level | XP |
| --- | ---: | ---: |
| Starter 1 | 1 | 20 |
| Starter 2 (parallel cook delivery) | 1 | 20 |
| Starter 3 | 3 | 100 |
| Starter 4 | 4 | 140 |
| Starter 5 | 5 | 180 |
| Starter 6 (conversation-only regional handoff) | 10 | 285 |
| Regional 7 | 10 | 380 |
| Regional 8 (hard) | 11 | 525 |
| Regional 9 (camp finale) | 12 | 805 |
| Optional axe lesson | 1 | 15 |
| Optional pick lesson | 2 | 45 |
| Village local 1 / 2 | 10 | 285 / 380 |
| Outpost local 1 / 2 | 11 | 315 / 420 |
| Camp local 1 / 2 | 12 | 460 / 575 |

Ordinary rewards use 15%, 20% or 25% of the intended level interval; the camp
finale uses 35%. Kill XP earned while doing the objective is additional and
continues to use the shared participation/split rules.

Round 20 conversation-only travel handoffs use the existing light/lesson rate:
15% of the authored target-level interval, rounded to a fixed integer catalog
reward. They award no kill XP and do not scale to the receiving player's level.
Comparable light quests provide the coin budget; no new reward currency or
travel-distance formula is introduced.
