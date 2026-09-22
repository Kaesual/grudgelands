# Progression — Pacing, Death, Reward Cadence

Decided rules (established 2026-08-06; housing cadence integrated 2026-08-12).
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
- **Level 20 — first Claim Stone:** a short introduction from the passive,
  invulnerable Housing Steward unlocks the first free owner-bound Claim Stone.
  It may be placed only in the authored level-11–30 housing zones and starts
  the non-combat home-progression line ([housing.md](housing.md) §2;
  `economy.md` §4.1).
- **Levels 35 / 50 / 60 — claim upgrades:** the same stable stone may reach
  tiers II / III / IV by paying the universal-metal and measured-income costs.
  Claims never buy mining depth or a private material source.
- **Level 60 — additional claims when enabled:** a second or third stone is an
  endgame sink gated by all existing stones being tier IV, the configured
  per-character limit and the faction live-stone capacity.

## 3. Death rules (MVP — deliberately simple)

Decided 2026-08-06; PvP exemption decided 2026-08-13; refinements
(graveyards at outposts, res sickness, Priest resurrection) come later with
WP6/WP19:

The respawn and inventory rules apply to every death; the XP consequence
depends on the death's attribution.

- Death = **respawn at the bound innkeeper home with full inventory**
  ([home travel](home_travel.md)). The initial home is the own race's safe
  outer starting settlement. No corpse run, item loss or durability-on-death
  mechanic.
- **PvE XP loss: 25% of the whole current-level span, permanent**
  (floored at the current level start, so it never de-levels).
- **Confirmed PvP deaths cost no XP.** A death whose final HP-lowering
  committed transaction is attributed by the single PvP authority
  (`grug_pvp.classify_death`, WP41) to an eligible hostile player applies
  no XP loss. Every other death — PvE, environment, unclassified — keeps
  the 25% rule. Standing in contested ground or carrying the PvP tag never
  grants the exemption, and a death whose final commit is environmental
  (fall or lava after PvP damage) is unclassified and keeps the loss. The
  attribution seam belongs to WP41; the exemption is applied centrally in
  the XP death path (WP9 wiring), never by individual combat paths.
- The *distance* back is the real penalty: dying far from the spawn
  costs travel time — which scales naturally with how deep you pushed.
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

## Round 14 quest participation

Kill quests use the same per-mob damage/effective-heal participation as shared
XP, preserving its current online/40-node eligibility and existing XP splitting.
Party membership confers no automatic credit. Quest counters award a full kill
to each eligible participant with the matching active quest; zero XP from a
gray mob does not itself erase quest credit. See `quests.md`.

## Round 15 XP presentation

The numeric XP HUD line is replaced with a gold progress bar directly above
the hotbar, 360×6 HUD units (life remains 180×16). A compact label to its right
shows the level and current interval progress, for example
`Lv 8 (520/1500)`. The bar fills fully at maximum level. `/xp` reports exact
XP; a server administrator can grant a validated positive amount to an online
player with `/xp give <player> <amount>`. All offsets use the shared HUD layout
owner.

## Round 16 kill XP

Eligible mob-kill XP is increased by 50% at the shared settlement boundary,
before the existing participant split. The one-settlement guard, 40-node
eligibility, per-recipient gray rule, faction refusal and race bonus remain
unchanged. Quest rewards and administrator grants are not multiplied.

## Current fixed quest reward table

Rewards below are per quest, shared by the six racial variants. They are fixed
catalog values before any applicable racial modifier; no runtime level scaling.

| Quest position / work | Intended level | XP |
| --- | ---: | ---: |
| Starter 1 | 1 | 20 |
| Starter 2 | 2 | 60 |
| Starter 3 | 3 | 100 |
| Starter 4 | 4 | 140 |
| Starter 5 | 5 | 180 |
| Starter 6 (regional handoff) | 8 | 300 |
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
