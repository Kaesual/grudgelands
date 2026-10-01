# Progression — Pacing, Death, Reward Cadence

Decided rules (established 2026-08-06; housing milestone revised in Round 25,
2026-09-29).
The game ships 240 quests (Rounds 14, 15 and 20: 66 starter quests, 36
optional local quests, the capital, regional and travel quests), kept since
Round 28 as one data file per zone (`quests.md`, "Quest data"); each zone's
Round 28 design replaces its file. The broader named-zone WP9 story remains
open.

## 1. Leveling pace

- **Level 60 in ~10–20 played hours** (2–3 evenings) — deliberately much
  faster than WoW. The endgame (PvP, apex bosses, housing, jobs) is the
  game; leveling is the on-ramp.
- The curve is measured in **kill equivalents** (Round 28 rulings 30–32,
  2026-10-01; section "XP units and level curve" below): early levels need
  8 same-level kills' worth of XP, rising linearly to about 25 at level 59.
  Quests carry most of it (Ruling 33: questing covers about 90 % of a start
  zone's band and about 80 % elsewhere). Tune with playtests, not redesigns.

## XP units and level curve

Round 28 rulings 30–32 (2026-10-01). Every XP amount is expressed in **kill
equivalents (KE)**: `M(L) = 25 + 5·L`, the XP of one normal-tier kill at
level L (L1 30, L10 75, L30 175, L60 325). A level-3 mob gives 1.33× a
level-1 mob, not 3×.

- **Level curve:** XP from level L to L + 1 is `M(L) × k(L)` rounded to tens,
  with `k(L) = 8 + 0.29·(L − 1)` same-level kill equivalents. Level 60 is the
  cap; XP is capped at the level-60 total (194,220).
- **Bands:**

| Band | XP | KE |
|---|---:|---:|
| 1 → 10 | 4,200 | 82 |
| 10 → 20 | 11,750 | 119 |
| 20 → 30 | 21,960 | 148 |
| 30 → 40 | 35,100 | 177 |
| 40 → 50 | 51,140 | 206 |
| 50 → 60 | 70,070 | 235 |
| 1 → 60 | 194,220 | 968 |

- **Per level** (M = one kill equivalent at that level, "to next" = XP for
  the next level, "start" = cumulative XP at which the level starts):

| L | M | to next | start | L | M | to next | start | L | M | to next | start |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 30 | 240 | 0 | 21 | 130 | 1,790 | 17,640 | 41 | 230 | 4,510 | 77,350 |
| 2 | 35 | 290 | 240 | 22 | 135 | 1,900 | 19,430 | 42 | 235 | 4,670 | 81,860 |
| 3 | 40 | 340 | 530 | 23 | 140 | 2,010 | 21,330 | 43 | 240 | 4,840 | 86,530 |
| 4 | 45 | 400 | 870 | 24 | 145 | 2,130 | 23,340 | 44 | 245 | 5,020 | 91,370 |
| 5 | 50 | 460 | 1,270 | 25 | 150 | 2,240 | 25,470 | 45 | 250 | 5,190 | 96,390 |
| 6 | 55 | 520 | 1,730 | 26 | 155 | 2,360 | 27,710 | 46 | 255 | 5,370 | 101,580 |
| 7 | 60 | 580 | 2,250 | 27 | 160 | 2,490 | 30,070 | 47 | 260 | 5,550 | 106,950 |
| 8 | 65 | 650 | 2,830 | 28 | 165 | 2,610 | 32,560 | 48 | 265 | 5,730 | 112,500 |
| 9 | 70 | 720 | 3,480 | 29 | 170 | 2,740 | 35,170 | 49 | 270 | 5,920 | 118,230 |
| 10 | 75 | 800 | 4,200 | 30 | 175 | 2,870 | 37,910 | 50 | 275 | 6,110 | 124,150 |
| 11 | 80 | 870 | 5,000 | 31 | 180 | 3,010 | 40,780 | 51 | 280 | 6,300 | 130,260 |
| 12 | 85 | 950 | 5,870 | 32 | 185 | 3,140 | 43,790 | 52 | 285 | 6,500 | 136,560 |
| 13 | 90 | 1,030 | 6,820 | 33 | 190 | 3,280 | 46,930 | 53 | 290 | 6,690 | 143,060 |
| 14 | 95 | 1,120 | 7,850 | 34 | 195 | 3,430 | 50,210 | 54 | 295 | 6,890 | 149,750 |
| 15 | 100 | 1,210 | 8,970 | 35 | 200 | 3,570 | 53,640 | 55 | 300 | 7,100 | 156,640 |
| 16 | 105 | 1,300 | 10,180 | 36 | 205 | 3,720 | 57,210 | 56 | 305 | 7,300 | 163,740 |
| 17 | 110 | 1,390 | 11,480 | 37 | 210 | 3,870 | 60,930 | 57 | 310 | 7,510 | 171,040 |
| 18 | 115 | 1,490 | 12,870 | 38 | 215 | 4,030 | 64,800 | 58 | 315 | 7,730 | 178,550 |
| 19 | 120 | 1,590 | 14,360 | 39 | 220 | 4,180 | 68,830 | 59 | 320 | 7,940 | 186,280 |
| 20 | 125 | 1,690 | 15,950 | 40 | 225 | 4,340 | 73,010 | 60 | 325 | — | 194,220 |

- **Quest rewards** are authored as a **weight in KE** at the quest's reward
  level: `XP = round(weight × M(quest level))` (`grug_xp.quest_reward(level,
  weight)`); the human +10 % quest bonus applies on top when the reward is
  granted (source `quest`). Weights and the per-band budget (Ruling 33) are
  set by the design frame (`docs/planning/round28-design-frame.md` §2.2).
- **Kill XP** and **gathering XP**: sections below.
- One place: `grug_xp.mob_xp`, `grug_xp.level_xp`, `grug_xp.quest_reward`,
  `grug_xp.gather_xp` and the level table in `mods/PLAYER/grug_xp/init.lua`.
  The design ledger (`tools/r28_design/r28common.py`) implements the same
  formulas; `tools/r28_b3_xp/portable_test.lua` requires both to agree.
  Retuning the curve is one edit there.

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
- **Level 20 — Claim Stone:** the Housing Steward in every capital hands out
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
- Quest XP uses the authored reward level rather than the receiver's level
  and does not scale at hand-in. New quests (Round 28) author a weight in
  kill equivalents ("XP units and level curve"); the split older quests in
  the zone files still carry the fixed integers ("Current fixed quest reward
  table") until their zone's design replaces them.
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
`Lv 8 (320/650)`. Every XP gain also appears as "+N XP" in the message
feed (gains within 1.5 s summed), and a level-up is a large centre
announcement, never a chat line (`inventory_equipment.md`, "Message feed"). The bar fills fully at maximum level. `/xp` reports exact
XP; a server administrator can grant a validated positive amount to an online
player with `/xp give <player> <amount>`. All offsets use the shared HUD layout
owner.

## Kill XP

Round 28 ruling 30 (2026-10-01). A kill pays each eligible participant

`XP = M(min(mob level, player level + 5)) × tier multiplier`, then divided by
the eligible head count (rounded down),

with tier multipliers normal ×1, elite ×4, rare ×6. The boss tier pays the
normal ×1 (its HP is flat, `combat_stats.md` §3); critters pay 0; a def's
`_grug_xp_reward` overrides the formula (the Kraken: 0). The Round 16 ×1.5 is
gone: the unit itself was raised.

- **Gray rule:** a mob at level ≤ player level − 10 gives that player 0.
- **Cap:** the formula reads at most player level + 5; the gray test reads
  the mob's actual level.
- **Split:** each recipient's own capped value divided by the same eligible
  count (online, within 40 nodes, accepted damage or effective healing);
  no XP from a mob of the player's own faction; one settlement per death.
- **No race bonus on kills:** the only XP race bonus is the human +10 % on
  quest rewards.
- Examples (solo): L1 mob at L1 30, L3 mob at L1 40, L20 mob at L1 55 (cap),
  L10 elite at L10 300, L10 rare 450; two players at L10 and L1 on an L10
  mob receive 37 and 27.

## Gathering XP

Round 24 ruling 28 (2026-09-29), in kill equivalents since Round 28 ruling 32
(2026-10-01). XP sources are mob kills, quest rewards, administrator grants
and gathering. Every natural ore or gem node a player digs and every fish a
player catches gives

`XP = ratio × M(min(reference level, player level + 5))`, rounded half up,

| Source | Ratio (KE) | Reference level |
|---|---:|---|
| ore node (every natural resource node that is not a gem) | 0.10 | 10 × harvest tier: T1 10 … T5 50 |
| gem node (the six regional G1/G2 gems) | 0.20 | 10 × harvest tier: G1 (T2) 20, G2 (T4) 40 |
| fish (not junk from the catch table) | 0.33 | 10 × the water's zone band: 10 … 60 |

The ratios are the Round 24 factors (1.5 / 3 / 5 against a 15L kill)
carried over to the new unit.

- There is no gray rule: T1 ore always pays (8 XP at level 5 and above).
- Examples: coal at level 1 gives 6 (0.1 × M(6) = 5.5 rounded up); a G2 gem
  at level 30 gives 40; a band-1 fish at level 1 gives 18; a band-6 fish at
  level 60 gives 107.
- The ratios and the formula live in one place, `grug_xp.GATHER_XP_RATIO`
  and `grug_xp.gather_xp` (`mods/PLAYER/grug_xp/init.lua`); XP is added
  with source `gathering`, which carries no race or class bonus. The
  Goldsmith's extra raw gem is an item bonus and adds no XP.
- Only a successful player dig of a natural resource node (the
  `grug_materials` harvest callback) and a reeled-in fish pay. There is no
  anti-cheat or autoclicker check (user ruling). A caught fish shows its XP in
  its feed line ("Caught Silver Trout (+N XP)"); ore XP shows as an
  ordinary "+N XP" feed line.

## Current fixed quest reward table

**Legacy values.** These fixed integers were sized against the pre-Round-28
quadratic curve (interval `200L − 100`) and stay unchanged until the Round 28
zone designs replace the quests (Ruling 32 weights). Against the new curve
they are mis-sized: a level-1 quest is 0.5–0.7 kill equivalents (6–8 % of
the level), levels 3–5 are 2.5–3.6 KE (29–39 % of a level), and from level 10
on every quest is 3.8–9.5 KE, 36–85 % of a whole level (the old design meant
15–35 %; the new interval at level 10 is 800 instead of 1,900). Example: the
L10–12 regional and local quests of one start town add 4,430 XP, which takes
a player from level 10 to about level 14 by rewards alone.

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

Ordinary rewards used 15%, 20% or 25% of the intended level interval of the
old quadratic curve; the camp finale used 35%. Kill XP earned while doing the objective is additional and
continues to use the shared participation/split rules.

Round 20 conversation-only travel handoffs use the existing light/lesson rate:
15% of the authored target-level interval (old curve), rounded to a fixed integer catalog
reward. They award no kill XP and do not scale to the receiving player's level.
Comparable light quests provide the coin budget; no new reward currency or
travel-distance formula is introduced.
