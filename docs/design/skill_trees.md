# Skill Trees (Talents) — WP11

**PROPOSAL, revision 2 (2026-09-16), NOT DECIDED.** Revision 1 (2026-09-16)
built two trees of five talents per class on a 20-point budget. The user's
rulings of **2026-09-16** (§5) replace the budget, the tree size, the tier
shape, the capstone rule and the respec seam, and add a fourth class. This
revision rebuilds the proposal on those rulings. Nothing here is implemented,
and nothing in `mods/` was changed for it.

Companion files written with this revision:

- [scout.md](scout.md) — the fourth class (Scout): kit, armour, bow, the
  conflicts its stealth and sprint have with shipped systems, and the lane
  cut. Its two trees live here in §2.7/§2.8 so that all four classes' talent
  tables stay in one place under one arithmetic.
- `docs/research/mob-pressure-task-card.md` — the melee-pressure and
  ranged-mob task card of the same session. Not part of WP11; it is named
  here because the Scout's kiting and stealth read on top of it.

The decided frame this proposal must fit is quoted where it binds. Where a
user ruling of 2026-09-16 **supersedes** a decided sentence, the sentence is
named with its file and line and the correction is made in that file's own
commit (§5.3).

- `classes.md` core principles (`:54-56`): "Three to four abilities per class
  in the MVP; **new active 'main skills' come from talent capstones** (WP11,
  progression.md) — talents otherwise improve existing buttons rather than
  adding many new ones." **Ruling 3 widens this**: new skills now come from
  keystones as well as capstones, and ruling 4 makes the tree their *only*
  source.
- `classes.md` §5 (`:459`): "Renew *(talent)* … Unlocked via the Holy tree
  (WP11)." Still true; Renew is the Mercy tree's first keystone (§2.5).
- `economy.md` §4 (`:92`): "**Talent respec:** repeatable at the class
  trainer, rising with level". **Ruling 4 supersedes the location**: there is
  no class trainer. `economy.md:92` and `items_crafting.md` §8.3 (`:2380`)
  are *not* this lane's files and still carry the retired seam — see §6.9.
- `AGENTS.md:66-71`: `docs/design/` holds *decided* design with no open
  questions. This file carries an open-decisions section (§6) because the
  lane brief asked for the proposal and its decisions in one deliverable;
  §6.1 is the decision about where the open questions should live.
- `AGENTS.md:844`: "Never copy WoW assets/names 1:1 — Blizzard IP. Own
  assets, own names with a recognizable character." Ruling 5 makes this
  binding for every talent name; §2.11 is the audit.

Everything this proposal says about the code is a `file:line` citation into
`mods/` at **`70dda602`**, re-resolved after this file was written; nothing
under `mods/` is changed by this lane, so those numbers are the same on both.
Citations into the four **design docs this lane edits** (`combat_stats.md`,
`classes.md`, `progression.md`, `BACKLOG.md`) are **branch-relative**: they
point at this branch's own text, not at `main`'s. The one place that has to
point at the retired text instead — §5.2's supersession table — writes those
numbers as `main:NNN` and quotes the sentence in full.

---

## 1. The shape

### 1.1 Four classes, two trees, two chains per tree

Three classes ship (`grug_classes/init.lua:136`, `:146`, `:156`); the fourth,
**Scout**, is planned now and implemented later (ruling 7,
[scout.md](scout.md)). Each class gets two trees, and — new in revision 2 —
**each tree holds two rough playstyle directions, called chains** (ruling 2).
A chain is a straight line of four talents: two numeric, then a keystone,
then either the capstone or a finisher.

| Class | Tree | Direction | Chain A | Chain B |
|---|---|---|---|---|
| Warrior | **Bulwark** | take hits and hold attention | **Wall** — mitigation | **Anvil** — threat and control |
| Warrior | **Ruin** | spend rage for damage | **Hammer** — big hits | **Lash** — crit and snare |
| Mage | **Ember** | fire damage | **Blaze** — single target | **Cinder** — area and reach |
| Mage | **Rime** | control and survival | **Frost** — roots and slows | **Ward** — mana, escape, absorb |
| Priest | **Mercy** | keeping others up | **Balm** — direct and over-time heals | **Aegis** — absorbs and avoidance |
| Priest | **Reckoning** | solo damage and self-sufficiency | **Word** — the Smite line | **Wrath** — crit and self-repair |
| Scout | **Quarry** | the bow | **Draw** — shot power | **Ranging** — reach, ammo, movement |
| Scout | **Veil** | the blade and the shadow | **Blade** — melee damage | **Shadow** — avoidance and stealth |

Tree names are unchanged from revision 1 by ruling 5 ("Tree names as proposed
stay"). Ruin, Rime and Reckoning are known collisions with WoW talent names
and the user has kept them deliberately; **talent** names are a different
matter and §2.11 audits every one of them. The Scout's two tree names are new
and §6.7 is their decision.

Two sites in the repo still call the Priest healing tree "the **Holy** tree",
one of them a code comment: `classes.md:459` and
`mods/PLAYER/grug_abilities/kits.lua:650`. (Revision 1 counted three; the
third was `progression.md`'s "Priest Holy capstone", which **this lane's own
`progression.md` commit already removed** — `grep -n Holy
docs/design/progression.md` now returns nothing.) **Mercy** is the same tree
renamed; the rename has to reach the two that are left (§6.6).

### 1.2 Tiers, gates and hard chains

Both dependency kinds ruling 2 asks for are used:

- A **tier gate** is points already spent *in that tree* (not in that tier).
- A **hard chain** is "all ranks in the talent above it, in the same chain".

| Tier | Contents | Tier gate (points in this tree) | Hard chain |
|---|---|---|---|
| 1 | one entry talent per chain, **5 ranks** | 0 | — |
| 2 | one talent per chain, **4 ranks** | 5 | tier-1 talent of the same chain at 5/5 |
| 3 | one **keystone** per chain, **3 ranks** | 12 | tier-2 talent of the same chain at 4/4 |
| 4 | the **capstone** on its chain, a finisher on the other, **3 ranks** each | 20 | tier-3 talent of the same chain at 3/3 |

Rank counts vary by talent strength exactly as ruling 2 asks: **5 / 4 / 3 / 3**
down a chain. The weakest per-rank talent carries the most ranks; keystone and
capstone carry three, so rank 1 grants the thing and ranks 2 and 3 improve it.

Per tree that is **8 talents and 15 + 15 = 30 ranks**; per class **16 talents
and 60 ranks**.

The two gate kinds interact deliberately:

- The tier-2 gate (5) is exactly the cost of maxing a tier-1 talent, so a
  player who commits to one chain opens tier 2 at the moment the hard chain
  lets them through it. No dead point.
- The tier-3 gate (12) is **three more than a single chain costs**
  (5 + 4 = 9), so a keystone cannot be rushed on one chain alone: three
  points have to go into the tree's other direction first. That is what makes
  a tree read as a tree rather than as two unrelated ladders.
- The tier-4 gate (20) is **eight more than a chain's first three talents**
  (5 + 4 + 3 = 12), so a capstone needs most of the other chain as well.

### 1.3 Points, and the arithmetic (rulings 1 and 2)

- **One point every two levels, the first at level 2**: levels 2, 4, 6, …, 60.
  The point count at level L is `floor(L / 2)`; at level 60 that is
  **30 points**.
- **Ranks per tree: 30. Ranks per class: 60.** `30 / 60` is **exactly one
  half** of a class's ranks and **exactly one whole tree**.
- **A full tree costs 30 points = level 60**, so a "pure" build finishes its
  tree with the last point the game hands out — and a full tree is never
  forced: every split is legal.
- Ruling 1's "two thirds was a rough guideline, slight deviation is fine" is
  what this uses: the fraction is now one half of the class, or one tree of
  two.

Worked reachability, per tree, counting points **in that tree**:

| Milestone | Cost in the tree | Total points | Character level |
|---|---|---|---|
| tier-1 talent maxed (5/5) | 5 | 5 | 10 |
| tier-2 talent maxed (4/4) | 9 | 9 | 18 |
| **first keystone**, rank 1 | 9 on the chain + 3 in the other chain (gate 12) + 1 | 13 | **26** |
| first keystone maxed (3/3) | 15 | 15 | 30 |
| **second keystone**, rank 1 (same tree) | both chains through tier 2 (18) + 1 + 1 | 20 | **40** |
| **capstone**, rank 1 | its chain to 12 + 8 elsewhere in the tree (gate 20) + 1 | 21 | **42** |
| capstone maxed (3/3) | 23 | 23 | **46** |
| **the whole tree** | 30 | 30 | **60** |

What the common splits buy:

| Split | What it reaches |
|---|---|
| **30 / 0** (pure) | both keystones, the capstone and every rank of one tree — three new buttons where the capstone is a skill |
| **23 / 7** | one chain complete through its capstone; the other tree's entry talent maxed plus two |
| **21 / 9** | capstone rank 1 plus one maxed keystone; no keystone in the second tree |
| **20 / 10** | **both** keystones of the prioritised tree at rank 1 (both chains through tier 2 = 18, then one point in each keystone); the second tree gets a maxed tier-1 and most of a tier-2 |
| **15 / 15** | one complete chain, keystone included, in **each** tree — two new buttons, one per tree |
| **13 / 13** (+4 spare) | one keystone in each tree at rank 1, four points free |

**No build can hold more than three new active skills**, and the cheapest
route to three costs **23 points in one tree — level 46, with 7 points still
free.** Four keystones cost 20 + 20 = 40 > 30 and three from two trees cost
20 + 13 = 33 > 30, so all three must come from a single tree; but they need
only rank 1 each, not a full tree. Worked on the Warrior's Ruin:

| Points | Running total | On | Why |
|---:|---:|---|---|
| 5 | 5 | Heavy Hand 5/5 | opens tier 2 (gate 5) and is Stoke's hard chain |
| 4 | 9 | Stoke 4/4 | Broadstroke's hard chain |
| 5 | 14 | Keen Edge 5/5 | the other chain — and what clears the tier-3 gate of 12 |
| 3 | 17 | Broadstroke 3/3 | **new skill 1**, and Ruination's hard chain |
| 4 | 21 | Hobble 4/4 | Pin's hard chain; also clears the tier-4 gate of 20 |
| 1 | 22 | Pin 1/3 | **new skill 2** |
| 1 | **23** | Ruination 1/3 | **new skill 3** |

The **23 / 7** row of the table above spends its 23 differently (deeper on one
chain, no second keystone) and reaches only two, which is why the split table
alone does not show this. §6.11 is the hotbar decision that follows, and it
follows at **level 46**, not at 60.

XP loss never de-levels (`progression.md` §3; `grug_xp` clamps the loss to the
level floor, `mods/PLAYER/grug_xp/init.lua:85-96`), so a point is never taken
back by dying.

### 1.4 Respec (ruling 4)

- **Where: in the talent UI itself. There is no class trainer and no NPC.**
  Ruling 4 is explicit. This retires revision 1's open decision about a
  trainer NPC entirely and supersedes the location half of `progression.md`
  §2 (`:45-50`) and `economy.md` §4 (`:92`). The consequence to accept:
  `world.md:408`'s class trainers lose their stated purpose, and
  `docs/research/wp13-npc-sockets-contract.md` §8.4 never needs a `trainer`
  vendor kind.
- **What:** a respec sets every rank to 0 and returns all 30 points. No
  partial or single-tree respec — one button, one price.
- **Price:** ruling 4 records the user as "against money" while money is still
  what the decided docs name as the sink. `BACKLOG.md:540-548` carries the
  only number written down anywhere: "the **respec price** (§8.3, **5c ×
  level, min 25c**) has no consumer yet — `grug_money.take` is the API it
  will call" (`mods/PLAYER/grug_money/init.lua:122`). §6.8 puts the price to
  the user with three options, including keeping that formula.
- **A class switch is not a respec.** `/class` is an admin command
  (`grug_classes/selection.lua:554-596`) and already wipes kit state through
  `sync_kit` (`grug_abilities/init.lua:1772-1780`); it clears all talents and
  returns all points, free. Four shipped comments assume the opposite — §6.10.

---

## 2. The talents

Reading the tables:

- **Chain** is the direction inside the tree (§1.1); **Tier** carries its
  gate from §1.2, and every talent below tier 1 additionally needs all ranks
  of the talent above it in its own chain.
- **Ranks** is the number of ranks and the per-rank progression.
- **Effect** is written in the vocabulary of `combat_stats.md` §1/§2/§4 —
  armor percent, crit chance, dodge chance, max HP, max mana, rage, spell
  power, threat, absorb, root and slow duration. **No talent introduces a new
  mitigation term.** Three capstones deliberately exceed a cap for a bounded
  time, which is exactly what ruling 6 allows and §6.5 puts to the user.
- **Modifies** names the shipped line the rank changes, or "new skill"
  (keystone) / "new effect" (capstone). **A kit table's `cooldown`, `charge`,
  `range` and `max_distance` fields are evaluated once at load time with no
  player in scope**, so talents that re-tune those hook the central
  per-player site instead — §3.2 lists the three of them.
- **Key** is the effect key of the data model in §3.2.

### 2.1 Warrior — Bulwark

| # | Talent | Chain | Tier | Ranks | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|
| 1 | **Ironbound** | Wall | 1 | 5 | +1 / 2 / 3 / 4 / 5 armor percent, still under the 60 % cap | `grug_inventory/equipment.lua:479` (`get_armor_percent`) | `armor_percent_add` |
| 2 | **Weathered** | Wall | 2 | 4 | max HP +3 / 6 / 9 / 12 | `grug_classes/stats.lua:20` | `max_hp_add` |
| 3 | **Hold Ground** *(keystone)* | Wall | 3 | 3 | **new skill** (cast): 25 rage, 60 s cooldown, self; absorbs `20 / 30 / 40 + 2 × floor(Str/10)` for 8 s | new; `grug_core.set_absorb` (`grug_core/combat.lua:1012`) | — |
| 4 | **Unbroken** *(capstone)* | Wall | 4 | 3 | **new effect**, no hotbar key: the first time in 180 s that a hit would take the Warrior below 20 % max HP, armor percent +10 / 15 / 20 for 8 s **and the armor cap rises to 70 / 75 / 80 %** for those 8 s | the two clamps, `grug_inventory/equipment.lua:480` and `grug_core/combat.lua:38`, plus the central hp-change modifier that observes the threshold | `armor_cap_override` |
| 5 | **Spite** | Anvil | 1 | 5 | +1 / 2 / 3 / 4 / 5 rage per hit taken (on top of the base 4) | `grug_abilities/init.lua:2109-2110`, beside the orc perk | `rage_per_hit_taken_add` |
| 6 | **Affront** | Anvil | 2 | 4 | tank-ability threat multiplier ×3 → ×3.25 / 3.5 / 3.75 / 4.0 | **two sites**: casts at `grug_core/combat.lua:963` (`local mult = opts.threat_mult or 1`) and swings at `grug_abilities/init.lua:910` (`context.threat_mult = threat_mult or 1`, applied at `:955-957`) | `threat_mult_add` |
| 7 | **Bellow** *(keystone)* | Anvil | 3 | 3 | **new skill** (cast): 15 rage, 20 s cooldown, no target; every hostile mob within 6 / 8 / 10 m is forced onto the Warrior for 3 s | new; the Taunt body (`kits.lua:389-404`, `grug_core.taunt`) run over the radius loop of `kits.lua:490` | — |
| 8 | **Grudge** | Anvil | 4 | 3 | Taunt cooldown 8 s → 7 / 6 / 5 s | `grug_abilities/init.lua:1233`, the one `arm_cooldown(user, def, def.cooldown)` call — **not** `kits.lua:387` | `taunt_cooldown_sub` |

**Hold Ground replaces revision 1's "Stand Fast".** Revision 1 put a
percentage damage-reduction window to the user as its own open decision,
because `combat_stats.md` §2 (`:59-82`) knows exactly one physical mitigation
term — armor points, 1 point = 1 %, hard cap 60 % — plus the Warding Draught
and the absorb shield, resolved in that order. Ruling 6 answers the question
from the other side: a capstone may exceed a cap, time-limited. So the
mitigation *keystone* is built from the shipped absorb and the *capstone*
(Unbroken) is the one thing that lifts the armor cap, for 8 seconds, once
every three minutes. No fourth mitigation term is created anywhere.

Named consequence: there is **one absorb per player and a new one replaces
the old** (`grug_core/combat.lua:1003-1012`), so a Priest's Power Word:
Shield cast onto the Warrior overwrites Hold Ground and vice versa. This is
the same collision revision 1 recorded for the Mage; §6.12 asks whether a
second absorb slot for self-cast tank cooldowns is worth building.

### 2.2 Warrior — Ruin

| # | Talent | Chain | Tier | Ranks | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|
| 1 | **Heavy Hand** | Hammer | 1 | 5 | Mighty Blow ×1.5 → ×1.55 / 1.60 / 1.65 / 1.70 / 1.75 weapon damage | `kits.lua:342` | `mighty_blow_multiplier_add` |
| 2 | **Stoke** | Hammer | 2 | 4 | +1 / 2 / 3 / 4 rage per landed authoritative swing (base 12) | `grug_abilities/init.lua:939`, `:950`, `:966` | `rage_per_swing_add` |
| 3 | **Broadstroke** *(keystone)* | Hammer | 3 | 3 | **new skill** (swing): 30 rage, 10 s charge; on a landed swing `floor(weapon damage × 2.0 / 2.25 / 2.5) + melee bonus` on the target and half of that, rounded down, on every other hostile within 3 m; ×3 threat | new; the `proc_swing` shape of `kits.lua:340-344` plus the radius loop of `kits.lua:490` | — |
| 4 | **Ruination** *(capstone)* | Hammer | 4 | 3 | **new skill** (cast): 40 rage, 90 s cooldown, self, 10 s; crit chance +15 / 20 / 25 percentage points **and the crit cap rises to 45 / 50 / 55 %** for those 10 s | `grug_classes/stats.lua:45` and its `math.min(0.30, …)` | `crit_cap_override` |
| 5 | **Keen Edge** | Lash | 1 | 5 | +1 / 2 / 3 / 4 / 5 percentage points crit chance (30 % cap holds) | `grug_classes/stats.lua:45` | `crit_chance_add` |
| 6 | **Hobble** | Lash | 2 | 4 | Hamstring charge 6 s → 5.5 / 5.0 / 4.5 / 4.0 s | `grug_abilities/init.lua:718`, the one line that arms a charge — **not** `kits.lua:356` | `hamstring_charge_sub` |
| 7 | **Pin** *(keystone)* | Lash | 3 | 3 | **new skill** (cast): 15 rage, 25 s cooldown, 8 m; roots the pointed hostile for 2 / 2.5 / 3 s | new; the root machinery of `kits.lua:495` (players) and `:504` (mobs) | — |
| 8 | **Deadweight** | Lash | 4 | 3 | Hamstring's 50 % slow lasts 5 s → 6 / 7 / 8 s | `kits.lua:370` (mobs) and `:372` (players) | `hamstring_slow_add` |

Broadstroke is the game's first melee cleave and needs no new timing
machinery: it rides the authoritative swing exactly as Mighty Blow does
(`classes.md` §2b), and its charge keeps it off every swing.

Charge (`kits.lua:291`) is the one shipped ability whose **own** numbers — 10 s
cooldown, 12 m reach, 3 damage, 15 rage — no talent re-tunes: a deliberate
gap, and an obvious hook for a later third Warrior direction. It is not
untouched, though: Affront (§2.1 #6) raises the tank-ability threat
multiplier, and Charge is the **only** caller in the game that passes one to a
cast (`kits.lua:312`, `threat_mult = 3`, read at `grug_core/combat.lua:963`),
so a Bulwark Warrior's Charge does generate more threat. The swing side is a
second, parallel site: `proc_swing` returns its multiplier as a second value
(Mighty Blow's `3` at `kits.lua:342`), carried at
`grug_abilities/init.lua:903-910` and applied at `:955-957`. **Affront
therefore needs both reads, not one** — §3.8's `combat.lua:963` row is half of
it.

### 2.3 Mage — Ember

| # | Talent | Chain | Tier | Ranks | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|
| 1 | **Tinder** | Blaze | 1 | 5 | Fireball `6 + spell power` → `+1 / 2 / 3 / 4 / 5` | `kits.lua:458` | `fireball_damage_add` |
| 2 | **Firebrand** | Blaze | 2 | 4 | +1 / 2 / 3 / 4 percentage points crit chance | `grug_classes/stats.lua:45` | `crit_chance_add` |
| 3 | **Brand** *(keystone)* | Blaze | 3 | 3 | **new skill** (cast): 15 mana, 8 s cooldown, 25 m; a straight projectile dealing `10 / 13 / 16 + 2 × spell power` to the first hostile | new; the projectile registration shape of `kits.lua:411-435` and the spawn call of `:453-460` | — |
| 4 | **Whitehot** *(capstone)* | Blaze | 4 | 3 | **new skill** (cast): 25 mana, 60 s cooldown, self, 10 s; while it runs Fireball costs 4 mana instead of 8 and deals `+3 / 5 / 7` | `grug_abilities/init.lua:1232` (`spend(user, def.cost)`) and `kits.lua:458` | `whitehot_window` |
| 5 | **Deep Well** | Cinder | 1 | 5 | max mana +3 / 6 / 9 / 12 / 15 % | `grug_classes/stats.lua:30` | `max_mana_percent_add` |
| 6 | **Far Cast** | Cinder | 2 | 4 | Fireball maximum distance 20 m → 21.5 / 23 / 24.5 / 26 m | two per-player reads, neither at a registration constant: the spawn call (`kits.lua:453-460`, since `grug_projectiles/init.lua:195` prefers `params.max_distance` over the registered `kits.lua:413`), and targeting reach in `grug_abilities.get_range` (`init.lua:170-177`), whose item-meta override `sync_kit` already refreshes (`grug_abilities/init.lua:1827-1831`) | `fireball_range_add` |
| 7 | **Cinderfall** *(keystone)* | Cinder | 3 | 3 | **new skill** (cast): 12 mana, 10 s cooldown, 20 m; a burst at the first thing the crosshair ray meets, dealing `5 / 7 / 9 + spell power` to every hostile within 3 m of it | new; `grug_core.combat_ray` (`kits.lua:58`) plus the radius loop of `kits.lua:490` | — |
| 8 | **Ashfall** | Cinder | 4 | 3 | Cinderfall's radius 3 m → 4 / 5 / 6 m | the new Cinderfall registration | `cinderfall_radius_add` |

Fireball's flight is not silently eaten by the longer range: `lifetime = 2`
(`kits.lua:420`) at `speed = 20` (`:412`) allows 40 m.

### 2.4 Mage — Rime

| # | Talent | Chain | Tier | Ranks | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|
| 1 | **Deep Chill** | Frost | 1 | 5 | Frost Nova root 4 s → 4.2 / 4.4 / 4.6 / 4.8 / 5.0 s | `kits.lua:495` (players) and `:504` (mobs) | `frost_nova_root_add` |
| 2 | **Hoarfrost** | Frost | 2 | 4 | Frost Nova follow-up slow 3 s → 4 / 5 / 6 / 7 s (the 50 % stays) | `kits.lua:496` and `:505` | `frost_nova_slow_add` |
| 3 | **Frostbind** *(keystone)* | Frost | 3 | 3 | **new skill** (cast): 12 mana, 20 s cooldown, 20 m; roots the pointed hostile for 3 / 4 / 5 s | new; the same root machinery as `kits.lua:495` / `:504` | — |
| 4 | **Rimebite** *(capstone)* | Frost | 4 | 3 | **new effect**, no hotbar key: Frost Nova and Frostbind also deal `3 / 5 / 7 + floor(spell power / 2)` damage when the root lands | `kits.lua:495-505` and the new Frostbind | `control_damage_add` |
| 5 | **Cold Focus** | Ward | 1 | 5 | in-combat mana regeneration 0.5 %/s → 0.6 / 0.7 / 0.8 / 0.9 / 1.0 %/s | `grug_abilities/init.lua:2202` | `combat_mana_regen_add` |
| 6 | **Quick Step** | Ward | 2 | 4 | Blink cooldown 15 s → 13.5 / 12 / 10.5 / 9 s | `grug_abilities/init.lua:1233` — **not** `kits.lua:526` | `blink_cooldown_sub` |
| 7 | **Glacial Ward** *(keystone)* | Ward | 3 | 3 | **new skill** (cast): 10 mana, 30 s cooldown, self; absorbs `10 / 15 / 20 + 2 × spell power` for 10 s | new; `grug_core.set_absorb` (`grug_core/combat.lua:1012`) | — |
| 8 | **Far Step** | Ward | 4 | 3 | Blink distance 10 m → 12 / 14 / 16 m | `kits.lua:533` (inside the cast body, player in scope) | `blink_distance_add` |

Same named consequence as §2.1: one absorb per player, a new one replaces the
old (`grug_core/combat.lua:1003-1012`). A Mage's Glacial Ward and a Priest's
Power Word: Shield overwrite each other.

### 2.5 Priest — Mercy

| # | Talent | Chain | Tier | Ranks | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|
| 1 | **Gentle Hand** | Balm | 1 | 5 | Flash Heal `8 + 2 × spell power` → `+1 / 2 / 3 / 4 / 5` | `kits.lua:613` | `flash_heal_add` |
| 2 | **Quiet Steps** | Balm | 2 | 4 | heal threat factor 0.5 → 0.45 / 0.40 / 0.35 / 0.30 (`combat_stats.md` §4) | `grug_core/combat.lua:241`, read at `:417` inside `add_heal_threat` (`:404`) | `heal_threat_factor_sub` |
| 3 | **Renew** *(keystone)* | Balm | 3 | 3 | **the already-registered ability** (`kits.lua:651-677`), granted at rank 1 exactly as `classes.md` §5 specifies (6 mana, 8 s cooldown, `3 + spell power` every 3 s for 12 s); ranks 2 and 3 raise the tick to `4` and `5 + spell power` | `kits.lua:671`; the grant gate is `talent_gated = true` at `kits.lua:656` | `renew_tick_add` |
| 4 | **Hearten** *(capstone)* | Balm | 4 | 3 | **new skill** (cast): 20 mana, 30 s cooldown; heals the Priest and every ally within 10 m for `6 / 9 / 12 + spell power` | new; `grug_core.heal_player` (`grug_core/combat.lua:984`) over the radius loop of `kits.lua:490` | — |
| 5 | **Warding Faith** | Aegis | 1 | 5 | Power Word: Shield absorb `+1 / 2 / 3 / 4 / 5` | `kits.lua:640` | `shield_absorb_add` |
| 6 | **Deep Reserve** | Aegis | 2 | 4 | max mana +3 / 6 / 9 / 12 % | `grug_classes/stats.lua:30` | `max_mana_percent_add` |
| 7 | **Turn Aside** *(keystone)* | Aegis | 3 | 3 | **new skill** (cast): 10 mana, 25 s cooldown, self; dodge chance +10 / 15 / 20 percentage points for 6 s, **inside** the 30 % cap | new; `grug_classes/stats.lua:49` | `dodge_chance_window` |
| 8 | **Second Skin** | Aegis | 4 | 3 | Power Word: Shield lasts 15 s → 18 / 21 / 24 s | `kits.lua:640` (the `15` argument) | `shield_duration_add` |

Renew is the Mercy tree's **keystone**, not its capstone. `progression.md` §2
(`:34-35`) calls it "the Priest Holy capstone"; ruling 3 re-cuts what a
capstone is, and the correction is made in `progression.md`'s own commit
(§5.3). `classes.md:459`'s sentence ("Unlocked via the Holy tree (WP11)")
stays true apart from the tree's name.

### 2.6 Priest — Reckoning

| # | Talent | Chain | Tier | Ranks | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|
| 1 | **Sharpened Word** | Word | 1 | 5 | Smite `4 + spell power` → `+1 / 2 / 3 / 4 / 5` | `kits.lua:591` | `smite_damage_add` |
| 2 | **Swift Word** | Word | 2 | 4 | Smite cooldown 2 s → 1.85 / 1.7 / 1.55 / 1.4 s | `grug_abilities/init.lua:1233` — **not** `kits.lua:581` | `smite_cooldown_sub` |
| 3 | **Word of Ruin** *(keystone)* | Word | 3 | 3 | **new skill** (cast): 8 mana, 12 s cooldown, 20 m; `6 / 8 / 10 + spell power` damage, healing the Priest for 50 % of it | new; `grug_core.deal_ability_damage` returns the post-crit amount (`grug_core/combat.lua:970`), healed back with `grug_core.heal_player(…, {no_crit = true})` (`:977-981`, `:984`) | — |
| 4 | **Last Word** *(capstone)* | Word | 4 | 3 | **new skill** (cast): 25 mana, 60 s cooldown, 20 m; `20 / 26 / 32 + 3 × spell power` on the pointed hostile and half of that on every other hostile within 3 m | new; `grug_core.deal_ability_damage` plus the radius loop of `kits.lua:490` | — |
| 5 | **Hard Faith** | Wrath | 1 | 5 | +1 / 2 / 3 / 4 / 5 percentage points crit chance | `grug_classes/stats.lua:45` | `crit_chance_add` |
| 6 | **Warded Wrath** | Wrath | 2 | 4 | while the Priest carries an absorb shield, Smite deals `+1 / 2 / 3 / 4` | `kits.lua:591`, gated on `grug_core.get_absorb(user) > 0` (`grug_core/combat.lua:1020`) | `smite_damage_while_shielded_add` |
| 7 | **Recompense** *(keystone)* | Wrath | 3 | 3 | **new skill** (cast): 12 mana, 25 s cooldown, self; heals the Priest for `12 / 16 / 20 + 2 × spell power` and grants an absorb of half that for 10 s | new; `grug_core.heal_player` (`:984`) and `grug_core.set_absorb` (`:1012`) | — |
| 8 | **Hardened** | Wrath | 4 | 3 | max HP +4 / 8 / 12 | `grug_classes/stats.lua:20` | `max_hp_add` |

Word of Ruin's drain is specified as "50 % of the damage dealt **before the
target's armor**": `deal_ability_damage` returns the amount the ability
published, taken before the central modifier applies armor (`:36-42`) and the
absorb shield (`grug_core/combat.lua:1003-1030`) to a *player* target. Against a mob it is exactly
what landed; against an armoured PvP target a post-mitigation promise would be
one the pipeline cannot keep.

### 2.7 Scout — Quarry (planned, not implemented)

The Scout's kit, resource, armour and bow are [scout.md](scout.md); the two
trees are here so that §1.3's arithmetic and §2.11's name audit cover all four
classes. Every "Modifies" cell in §2.7 and §2.8 would say **new**, because
none of the code exists yet, so the column is dropped.

| # | Talent | Chain | Tier | Ranks | Effect | Key |
|---|---|---|---|---|---|---|
| 1 | **Strong Draw** | Draw | 1 | 5 | Loose damage `+1 / 2 / 3 / 4 / 5` | `loose_damage_add` |
| 2 | **Cold Eye** | Draw | 2 | 4 | +1 / 2 / 3 / 4 percentage points crit chance | `crit_chance_add` |
| 3 | **Twin Shot** *(keystone)* | Draw | 3 | 3 | **new skill** (cast): 25 focus, 10 s cooldown, 25 m, costs 2 arrows; two arrows in succession, each for the Loose amount `+0 / 1 / 2` | — |
| 4 | **Longshot** *(capstone)* | Draw | 4 | 3 | **new skill** (cast): 30 focus, 60 s cooldown, **45 m**; one arrow for `2.0 / 2.3 / 2.6 ×` the bow's full-charge damage plus the ranged bonus — the longest reach in the game | — |
| 5 | **Quiver** | Ranging | 1 | 5 | Loose's arrow is not consumed 10 / 20 / 30 / 40 / 50 % of the time | `arrow_refund_chance` |
| 6 | **Long Reach** | Ranging | 2 | 4 | Loose range 25 m → 27 / 29 / 31 / 33 m | `loose_range_add` |
| 7 | **Sprint** *(keystone)* | Ranging | 3 | 3 | **new skill** (cast): 20 focus, 45 s cooldown, self; movement speed **+25 % for 10 / 12 / 14 s, out of combat only** — §6.13's option (c), which is what §6.13 recommends. Options (a) +8/9/10 % in combat and (b) +25 % in combat are live alternatives; **the number and the in-combat question are open decision §6.13, because this is the one number the whole mob-speed pillar is built on** | `sprint_speed_window` |
| 8 | **Shifting Weight** | Ranging | 4 | 3 | +1 / 2 / 3 percentage points dodge chance | `dodge_chance_add` |

### 2.8 Scout — Veil (planned, not implemented)

| # | Talent | Chain | Tier | Ranks | Effect | Key |
|---|---|---|---|---|---|---|
| 1 | **Fine Edge** | Blade | 1 | 5 | Gut ×1.4 → ×1.45 / 1.50 / 1.55 / 1.60 / 1.65 weapon damage | `gut_multiplier_add` |
| 2 | **Deep Focus** | Blade | 2 | 4 | Gut costs 25 focus → 22 / 19 / 16 / 13 | `gut_cost_sub` |
| 3 | **Opening** *(keystone)* | Blade | 3 | 3 | **new skill** (swing): 30 focus, 12 s charge; on a landed swing taken from **behind** the target (a yaw comparison, no new state), `floor(weapon damage × 2.2 / 2.5 / 2.8) + melee bonus` | — |
| 4 | **Follow Through** | Blade | 4 | 3 | Opening's charge 12 s → 10 / 8 / 6 s | `opening_charge_sub` |
| 5 | **Light Step** | Shadow | 1 | 5 | +1 / 2 / 3 / 4 / 5 percentage points dodge chance | `dodge_chance_add` |
| 6 | **Slip Away** | Shadow | 2 | 4 | Slip's cooldown 20 s → 17 / 14 / 11 / 8 s | `slip_cooldown_sub` |
| 7 | **Sidestep** *(keystone)* | Shadow | 3 | 3 | **new skill** (cast): 15 focus, 30 s cooldown, self; dodge chance +15 / 20 / 25 percentage points for 4 s, **inside** the 30 % cap — the "timed dodge window" of ruling 7 | `dodge_chance_window` |
| 8 | **Unseen** *(capstone)* | Shadow | 4 | 3 | **new skill** (cast): 30 focus, 120 / 100 / 80 s cooldown, self; invisibility for 10 / 15 / 20 s at **60 % movement speed**, broken by dealing or taking damage or casting a hostile ability, with a per-tick detection roll. Reached the "pure build" way §6.14 recommends: the uniform tier-4 gate of 20 **plus both Veil keystones at 3/3**, which costs 24 points in Veil and leaves 6 for Quarry. (§6.14's alternative (a) is a per-talent gate override of 26; the tables use (b).) | `invisibility_window` |

**Unseen is the one talent with a prerequisite the other 63 do not have**, and
it is deliberate: ruling 7 says invisibility is "reachable only by a 'pure'
build". The tables use §6.14's recommended form — the uniform tier-4 gate of
20 **plus both of Veil's keystones at 3/3** — which is built out of the two
dependency kinds §1.2 already has, rather than a per-talent gate number.
Worked: Blade `5 + 4 + 3 (Opening 3/3) = 12`, Shadow `5 + 4 + 3 (Sidestep 3/3)
= 12`, so **24 points in Veil before Unseen is offered at all**; rank 1 is the
25th point (**level 50**), rank 3 the 27th (**level 54**), and a level-60
Scout who took it has **3 points** for Quarry. That is as pure as the ruling
asks for. §6.14 carries the alternative (a per-talent gate of 26) and the
decision.

The detection roll, the speed penalty, the mobs_redo seam and the guard case
are specified in [scout.md](scout.md) §5; their numbers are open decision
§6.15.

### 2.9 Count

| | Per tree | Per class | All four classes |
|---|---|---|---|
| Talents | 8 | 16 | **64** |
| Ranks | 30 | 60 | **240** |
| Numeric talents | 5 | 10 | **40** |
| Keystones (always a new skill) | 2 | 4 | **16** |
| Capstones | 1 | 2 | **8** |
| …of which are skills | — | — | **6** (Ruination, Whitehot, Hearten, Last Word, Longshot, Unseen) |
| …of which are effects with no hotbar key | — | — | **2** (Unbroken, Rimebite) |

New ability registrations: 16 keystones + 6 skill capstones = **22**, of which
**one already exists in code** (Renew, `kits.lua:651-677`) and **6 belong to
the unimplemented Scout** (its 4 keystones — Twin Shot, Sprint, Opening,
Sidestep — and its 2 skill capstones, Longshot and Unseen; `scout.md` §7.2
lane S5 counts the same six). **WP11 therefore registers 15 new abilities for
the three shipped classes**, counted the other way as well: 12 keystones minus
the shipped Renew = 11, plus 4 skill capstones (Ruination, Whitehot, Hearten, Last
Word) = 15. That is the single largest change in scope from revision 1, which
registered five, and §4 re-sizes the lanes for it.

Effect keys, counted from the Key column of §§2.1-2.8: **49 key cells, 42
distinct** (15 rows carry no key — a keystone or capstone whose whole effect
is the new ability). **Four** keys are shared across classes:
`crit_chance_add` (all four), `max_mana_percent_add` (Mage, Priest),
`max_hp_add` (Warrior, Priest) and `dodge_chance_window` (Priest, Scout).
`dodge_chance_add` also appears twice, but **both are the Scout** (Sure
Footing in Quarry, Light Step in Veil) — shared across trees, not classes.
§3.2's closed vocabulary and §3.7's KAT group 5 are sized on the 42.

`progression.md` §2's "**9 of 10 talents are numeric modifiers**" does not
survive rulings 2 and 3 in any reading: a tree of 8 talents carries 5 numeric,
2 keystones and 1 capstone. §5.3 corrects the sentence.

### 2.10 Two consequences of touching shipped numbers

**The decided ability tables become *base* values.** `classes.md` §§3-5 state
their numbers flatly: Mighty Blow is "exactly floor(weapon damage × 1.5)"
(`classes.md:420`), Hamstring charges 6 s and slows for 5 s (`:421`), Taunt
runs 8 s (`:422`), Frost Nova roots 4 s then slows 3 s (`:441`), Blink
teleports 10 m (`:442`), Smite has a 2 s cooldown (`:456`), Flash Heal heals
`8 + 2 × spell power` (`:457`), Power Word: Shield lasts 15 s (`:458`), and
the 2026-08-06 kit-tuning note reasons from "+12 rage per auto-hit" (`:413`,
`:425`). **Eighteen talents re-tune exactly these numbers.** Nothing forbids
it — improving existing buttons is what `classes.md:54-56` says talents are
for — but when WP11 lands those tables are the **untalented baseline**, and
`classes.md` needs that word or the next reader will file a talented Taunt as
a bug.

**Three capstones exceed a cap on purpose.** Unbroken raises the armor cap to
80 % for 8 s and Ruination raises the crit cap to 55 % for 10 s, while the two
dodge keystones (Turn Aside, Sidestep) deliberately stay **inside** the 30 %
cap because they are keystones, not capstones. `combat_stats.md:104-108`
currently states that "values above a cap remain present on their stacks but
have no further combat effect" and that "there is no automatic overflow
conversion or cap raise". Ruling 6 is what permits the exception; §6.5 is
where the user confirms it. If the answer is no, Unbroken becomes flat armor
inside 60 % and Ruination becomes a rage-and-damage window instead.

### 2.11 Name audit (ruling 5)

Ruling 5: "TALENT names must not remind of WoW — rename every talent the
review flagged (Ruin/Rime/Reckoning stay as TREE names; Meditation, Kindling,
Cripple as talent names go) and check the rest."

Renamed in this revision:

| Revision 1 | Revision 2 | Why |
|---|---|---|
| Meditation | **Deep Reserve** | Classic Priest Discipline talent, same 5/10/15 ranks |
| Kindling | **Tinder** | Fire Mage talent |
| Cripple | **Hobble** | Warlock spell |
| Iron Discipline | **Ironbound** | "Discipline" and "Iron Will" both read as WoW class terms |
| Battle Hunger | **Spite** | "Battle" + noun is the WoW warrior naming shape |
| Bloodrush | **Stoke** | too close to Bloodthirst / Blood Rush |
| Reaving Strike | **Broadstroke** | "…Strike" is the WoW ability suffix |
| Stand Fast | **Hold Ground** (keystone) + **Unbroken** (capstone) | "Last Stand" / "Stand Fast" read as warrior cooldown names |
| Scorching Focus | **Firebrand** | "Scorch" is a Fire Mage spell |
| Zealous Mind | **Hard Faith** | "Zeal" is a Paladin/Priest term in WoW |

**Second pass (independent review, 2026-09-16).** The review found five more
names on the first pass's "no collision" list that are WoW talent names, three
of them **Hunter** talents sitting on the bow class — the worst possible
placement. All five are renamed here, and one of them (Fervour) was itself a
first-pass rename, which is the argument for labelling confidence instead of
asserting cleanliness:

| First pass | Now | Why |
|---|---|---|
| Fervour | **Hard Faith** | *Fervor* — Hunter talent (Cataclysm/MoP) |
| Hawk-Eyed | **Cold Eye** | *Hawk Eye* — Classic Hunter talent, and a **Hunter** name on the bow class |
| Sure Footing | **Shifting Weight** | *Surefooted* — Classic Hunter talent, likewise |
| Thick Hide | **Weathered** | Classic Druid talent; Hunter pet family bonus |
| Pyre | **Whitehot** | Devastation Evoker's core spell (Dragonflight) |

Every talent name in §§2.1-2.8, checked against the author's and the
reviewer's knowledge of WoW. **This is not verifiable inside this repo**, so
each name carries a confidence label rather than a verdict, and "low" means
"no collision either of us is aware of", never "proven clean":

- **Low risk (no collision either reader is aware of), 57 names:** Ironbound,
  Weathered, Hold Ground, Unbroken, Spite, Affront, Bellow, Grudge, Heavy
  Hand, Stoke, Broadstroke, Ruination, Keen Edge, Hobble, Deadweight, Tinder,
  Firebrand, Brand, Whitehot, Deep Well, Far Cast, Cinderfall, Ashfall,
  Hoarfrost, Frostbind, Rimebite, Cold Focus, Quick Step, Far Step, Gentle
  Hand, Quiet Steps, Hearten, Warding Faith, Deep Reserve, Turn Aside, Second
  Skin, Sharpened Word, Swift Word, Word of Ruin, Last Word, Hard Faith,
  Warded Wrath, Recompense, Hardened, Strong Draw, Cold Eye, Twin Shot,
  Longshot, Long Reach, Shifting Weight, Fine Edge, Deep Focus, Follow
  Through, Light Step, Slip Away, Sidestep, Unseen.
- **Medium risk, flagged and NOT renamed** — the user's call, alternatives
  given:

  | Name | Why | If the user wants it changed |
  |---|---|---|
  | **Pin** | a Hunter pet (crocolisk) ability | **Stake** |
  | **Deep Chill** | the shape of *Deep Freeze* (Frost Mage) | **Long Winter** |
  | **Glacial Ward** | near *Ice Ward* / *Ice Barrier* (Frost Mage) | **Coldshell** |
  | **Sprint** | an ordinary English word and a Rogue ability | **Break Away** |
  | **Quiver** | an ordinary noun and a Hunter aura in some expansions | **Full Quiver** |
  | **Opening** | generic, but next to WoW's "opener" vocabulary | **First Cut** |

- **A question for the user, not an automatic rename.** The criterion this
  audit used to retire *Reaving Strike* was "…Strike is the WoW ability
  suffix". By that same criterion, **Sharpened Word / Swift Word / Word of
  Ruin / Last Word** extend WoW's Priest *"Power Word:" / "Shadow Word:" /
  "Holy Word:"* family — on the Priest — and **Twin Shot** extends the Hunter
  *"…Shot"* family on the bow class. The shipped `Power Word: Shield` is
  pre-existing and ruling 5 does not reopen it, but four *new* Priest talents
  in that exact vocabulary is a choice worth making knowingly. Answer it with
  §6.6. Clean replacements if wanted: **Whetted Verse**, **Quick Verse**,
  **Verse of Ruin**, **Final Verse**; **Twinned Arrow**.
- **Deliberately kept by ruling 5 (tree names):** Ruin, Rime, Reckoning.
- **Renew** keeps its name: it is already registered and already named in a
  decided file, so it belongs to the pre-existing group with the nine shipped
  ability names (Power Word: Shield, Frost Nova, Flash Heal, Blink, Hamstring,
  Charge, Smite, Taunt, Renew) that ruling 5 does not reopen.

---

## 3. Data model and seams

### 3.1 Where talents live

New file **`mods/PLAYER/grug_classes/talents.lua`**, loaded from the existing
`dofile` block at `grug_classes/init.lua:210-213`, next to `stats.lua` and
`perks.lua`. `grug_classes` is the right owner for three reasons that already
hold in the tree: it owns the class registry (`init.lua:11-18`) and its def
comment already reserves room for "skill trees (WP11)" (`init.lua:7-8`); it
owns the per-player derived stats every numeric talent touches (`stats.lua`);
and it is a dependency of both `grug_inventory` and `grug_abilities`
(`stats.lua:79-82`), so both read talents without a new dependency edge.

**Reading needs no new edge; the UI and the respec do.**
`grug_classes/mod.conf` depends on `grug_core`, `grug_factions` and `grug_xp`
only. The Talents page of §3.5 needs **`sfinv`** (today a dependency of
`grug_inventory` alone) and the respec transaction of §1.4 needs
**`grug_money`** (`grug_money.take`, `mods/PLAYER/grug_money/init.lua:122`).
Both are one-line `mod.conf` additions with a load-order consequence, and
lane X4 owns them.

Registration mirrors `register_class` (`init.lua:14`):

```lua
grug_classes.register_tree({
    id = "bulwark", class = "warrior", name = "Bulwark",
    chains = {"wall", "anvil"},          -- exactly two, ruling 2
    capstone_chain = "wall",             -- which chain carries the capstone
})

grug_classes.register_talent({
    id = "ironbound", tree = "bulwark", chain = "wall", tier = 1,
    name = "Ironbound", description = "Armor +1% per rank.",
    effects = {armor_percent_add = {1, 2, 3, 4, 5}},  -- one value per rank
})

grug_classes.register_talent({
    id = "hold_ground", tree = "bulwark", chain = "wall", tier = 3,
    keystone = true,                     -- exactly one per chain, tier 3
    ability = "hold_ground",             -- the grug_abilities id it grants
    effects = {hold_ground_absorb = {20, 30, 40}},
})

grug_classes.register_talent({
    id = "unbroken", tree = "bulwark", chain = "wall", tier = 4,
    capstone = true,                     -- exactly one per TREE, on its chain
    effects = {armor_percent_add_low_hp = {10, 15, 20},
               armor_cap_override = {70, 75, 80}},
})
```

`register_talent` asserts the shape at load time the way `register_ability`
does (`grug_abilities/init.lua:475-510`): tier in 1..4, rank counts 5/4/3/3
by tier, chain belongs to the tree, exactly two chains per tree, exactly one
keystone per chain in tier 3, exactly one capstone per tree in tier 4 and on
a declared chain, eight talents per tree, two trees per class, and every
effect key present in the closed vocabulary table. A typo is a startup
failure, never a silently inert talent.

### 3.2 The one hook

```lua
-- Summed bonus of this key over the player's ranked talents; 0 when none.
function grug_classes.get_talent_bonus(player, key)
```

It is the deliberate twin of `grug_classes.get_race_perk`
(`grug_classes/perks.lua:21-28`), down to the stub override for mods below
`grug_classes` in the dependency graph (`perks.lua:31`):

```lua
grug_core.get_talent_bonus = grug_classes.get_talent_bonus
```

Every numeric talent in §2 is one call to this function at the site its
**Modifies** column names, and nothing else. **The site is not always in
`kits.lua`.** A kit table's `cooldown`, `charge`, `range` and `max_distance`
fields are evaluated **once at load time**, with no player in scope: a
per-player read written there would change the number for everybody. Six
talents therefore hook a central per-player site instead, and each of those
sites already exists and is already the only one of its kind:

| Talent | The constant it re-tunes | Where the read goes |
|---|---|---|
| Grudge, Quick Step, Swift Word (+ Scout: Slip Away) | `cooldown` in the ability def | `grug_abilities/init.lua:1233`, the sole `arm_cooldown(user, def, def.cooldown)` call |
| Hobble (+ Scout: Follow Through) | `charge` in the ability def | `grug_abilities/init.lua:718`, the sole line that arms a charge timer |
| Far Cast (+ Scout: Long Reach) | `max_distance` in the projectile registration (`kits.lua:413`) and `range` in the ability def (`:446`) | flight: the spawn call (`kits.lua:453-460`), since `grug_projectiles/init.lua:195` prefers `params.max_distance`; targeting reach: `grug_abilities.get_range` (`init.lua:170-177`), the twin of the elf `ability_range_bonus` perk, whose item-meta override `sync_kit` already refreshes (`grug_abilities/init.lua:1827-1831`) |
| Deep Focus (Scout) | `cost` in the ability def | `grug_abilities/init.lua:1232`, the sole `spend(user, def.cost)` call |

Every other numeric talent sits at the line its table names, inside a function
body with the player in scope. Two worked examples:

```lua
-- grug_classes/stats.lua:45 today (the body of the function at :44)
return math.min(0.30, 0.05 + 0.001 * grug_classes.get_attributes(player).dex)
-- with talents, cap-aware (§6.5)
local cap = math.max(0.30,
    0.01 * grug_classes.get_talent_bonus(player, "crit_cap_override"))
return math.min(cap, 0.05 + 0.001 * grug_classes.get_attributes(player).dex
    + 0.01 * grug_classes.get_talent_bonus(player, "crit_chance_add"))

-- kits.lua:342 today
return math.floor(ctx.weapon_damage * 1.5) + ctx.melee_bonus, 3, ...
-- with talents
local mult = 1.5 + 0.05 * grug_classes.get_talent_bonus(user, "mighty_blow_multiplier_add")
return math.floor(ctx.weapon_damage * mult) + ctx.melee_bonus, 3, ...
```

A second, smaller accessor answers unlock questions:

```lua
-- 0..5; used by the kit grant, the gates and the UI, never by a numeric consumer.
function grug_classes.talent_rank(player, talent_id)
```

**Timed windows are the one new shape revision 2 adds.** Six talents are not
a constant summed bonus but a bounded window: Ruination, Whitehot, Turn Aside,
Sidestep, Sprint and Unseen, plus Unbroken's triggered window. They are not a
third seam — `get_talent_bonus` returns 0 for a window key that is not
running — but they need one small per-player expiry table of the shape
`grug_core`'s absorbs already use (`grug_core/combat.lua:1010-1017`), owned by
`talents.lua` and cleared on leave, death, respec and class change. That table
is the single place a window lives; nothing else in the design needs state.

### 3.3 Persistence

- One player-meta **string** key, `grug_classes:talents`, holding `id=rank`
  pairs separated by commas: `ironbound=4,grudge=1`. The same store class and
  race already use (`grug_classes/init.lua:3-4`, `:76`, `:113`); a string
  keeps it to one key instead of sixty-four, and it stays human-readable for
  `/talents` debugging.
- Parsed once per join into a per-player runtime cache (the pattern of
  `grug_abilities`' runtime tables, `init.lua:22-38`), invalidated on spend,
  respec, class change and leave.
- **The read path validates, it does not trust.** Unknown ids are dropped,
  ranks are clamped to the talent's own rank count, a rank whose tier gate or
  hard chain is not satisfied is dropped **together with everything below it
  in its chain**, and the total spent is clamped to `floor(level / 2)`. A
  hand-edited meta string therefore cannot buy a capstone at level 4.
- Nothing else is persisted. Points available are always derived
  (`floor(grug_xp.get_level(player) / 2)`, `grug_xp/init.lua:48`), never
  stored, so the two can never disagree.

### 3.4 Granting a keystone or capstone ability

Keystone and skill-capstone abilities are ordinary `grug_abilities`
registrations with `talent_gated = true`, exactly like Renew today
(`kits.lua:656`). **Three** existing sites test that flag, and the file itself
states they must never disagree (`grug_abilities/init.lua:1705-1710`):

- `kit_of(class)` drops every `talent_gated` def in both of its loops, the
  universal one (`init.lua:1719`) and the class one (`:1724`). It becomes
  `kit_of(class, player)` and keeps a gated def when
  `grug_classes.talent_rank(player, def.talent) > 0`.
- The purge branch in `sync_kit` (`init.lua:1808-1810`) uses the same
  predicate, or a granted skill would be destroyed on the next sync.

`kit_of` has exactly one caller (`init.lua:1858`) and the grant loop passes
its index straight to `grant_at`, so a def's position in that list **is** its
hotbar key.

**The base kit's keys are safe; a talent skill's key is not, unless the grant
rule changes.** Registering the new abilities after the class section keeps
every base ability at the key it has today — the concern the file's own
comment raises at `init.lua:1712-1715`. But Renew is *not* appended: it is
already the fourth entry of `by_class["priest"]` (`kits.lua:651`, after Smite
`:572`, Flash Heal `:596` and Power Word: Shield `:623`). A Priest who unlocks
Word of Ruin first receives it at key 5; unlocking Renew afterwards puts Renew
at index 5 in `kit_of`, and `grant_at` (`init.lua:1731-1770`) moves the
occupant aside — the skill the player already learned changes key. With up to
three talent skills per build this is no longer a corner case.

The fix is one rule for the capstone lane: **a talent-granted ability is
placed in the first free slot after the base kit, in unlock order, not at its
`kit_of` index.** Base positions stay index-addressed as today; only gated
defs are appended.

Re-granting is driven by a new callback mirroring `register_on_class_chosen`
(`grug_classes/init.lua:68`, consumed at `grug_abilities/init.lua:1881`):

```lua
grug_classes.register_on_talents_changed(function(player) sync_kit(player) end)
```

It fires on every spend and on respec. Nothing else in `grug_abilities`
changes for the grants.

**Hotbar budget** (`classes.md` §2b reserves keys 1-8):

| Class | Base kit | Max talent skills | Worst case |
|---|---|---|---|
| Warrior | Strike + 4 (`kits.lua:268`, `:291`, `:321`, `:350`, `:380`; `classes.md:419-422`) = 5 | 3 (pure Ruin: Broadstroke, Pin, Ruination) | **8 of 8** |
| Warrior, pure Bulwark | 5 | 2 (Hold Ground, Bellow — Unbroken has no key) | 7 of 8 |
| Mage | Strike + 3 = 4 | 3 (pure Ember) / 2 (pure Rime, Rimebite has no key) | 7 of 8 |
| Priest | Strike + 3 = 4 | 3 | 7 of 8 |
| Scout | Strike + 3 = 4 | 3 | 7 of 8 |

A pure-Ruin Warrior fills **every** key, and reaches that state at **level
46** with seven talent points still unspent (§1.3's worked route), not at
level 60. `classes.md:466` already parks "Warrior shield abilities → after
WP14 (offhand/shields)" as the next claim on those keys. §6.11 is that
decision.

### 3.5 UI

A third `sfinv` page beside Character and Bags (`grug_inventory/pages.lua:192`,
`:233`), registered from a new `grug_classes/talents_ui.lua` so the page lives
with the data it shows and `grug_inventory` keeps its two pages. This costs
the `sfinv` dependency edge of §3.1. sfinv uses legacy coordinates and the
content area spans about y 0.3-5.0 (`pages.lua:1-2`).

Revision 1's layout drew five talents per tree in three tiers. Revision 2 has
**eight talents per tree in two chains and four tiers**, which is a two-column
chain layout per tree and four rows — sixteen buttons for the class, plus the
per-tree point counters, the gate labels and the description line. That fits
the sfinv area only if the two trees are **tabbed rather than side by side**:

```
+---------------------------------------------------------------+
| Character | Bags | Talents |                        (sfinv tabs)
+---------------------------------------------------------------+
| Warrior      [ BULWARK 21 ] [ Ruin 9 ]      Points left: 0     |
|                                            [ Respec  --  1s25c]|
|      WALL                       ANVIL                          |
| T1 | Ironbound      5/5 |   | Spite          5/5 |             |
| T2 | Weathered     4/4 |   | Affront        3/4 |     (>=5)   |
| T3 | Hold Ground *  3/3 |   | Bellow *       0/3 |     (>=12)  |
| T4 | Unbroken **    1/3 |   | Grudge         0/3 |     (>=20)  |
|                                                               |
| Unbroken -- rank 1/3: below 20% HP, +10% armor and the armor  |
| cap rises to 70% for 8 s. Next rank: +15%, cap 75%.           |
+---------------------------------------------------------------+
```

- `*` marks a keystone, `**` the capstone; a locked talent is a plain label
  (no click target) with its reason spelled out ("needs 12 points in Bulwark"
  or "needs Weathered 4/4").
- Clicking a talent selects it and writes the one-line explanation; clicking
  the selected talent again spends a point, so the page needs no "+" column
  and no confirmation dialog.
- The **Respec button lives here** (ruling 4) with its price in the label and
  a confirmation dialog, since there is no NPC to host the transaction.
- No new texture is needed; signature talent icons are a later art pass, the
  way `classes.md` §2c parks signature ability icons.

### 3.6 Level-up flow

`grug_classes` already registers on the level-change callback
(`grug_classes/stats.lua:90-93`, the callback itself at `grug_xp/init.lua:34`).
The same registration gains the talent line:

```lua
-- old_level is nil on join (grug_xp/init.lua:32-33), which is why
-- stats.lua:91-92 already guards it. Arithmetic on nil here would error
-- on every single join.
if old_level ~= nil and
        math.floor(new_level / 2) > math.floor(old_level / 2) then
```

On that condition, send one chat line under the existing "Reached level N!"
(`grug_xp/init.lua:62-64`). No new globalstep, no new HUD element, no new
packet.

### 3.7 The KAT

`tools/wp11/talent_tree_kat.lua`, plain Lua 5.1 under a stub registry, in the
shape of `tools/wp13/ability_rightclick_kat.lua:1-45` — it loads the **real**
`talents.lua` and the real `register_talent`, and runs under both interpreters
with identical output. Eight groups, each able to go red on its own:

1. **Shape.** Every class has exactly 2 trees; every tree 8 talents in two
   chains of 4; ranks 5/4/3/3 by tier; exactly one keystone per chain in
   tier 3; exactly one capstone per tree, in tier 4, on a declared chain.
   Totals: 30 ranks per tree, 60 per class.
2. **Arithmetic.** `floor(60/2) == 30`; one tree costs 30; `30/60` is one
   half; the milestone table of §1.3 reproduces exactly (13 / 20 / 21 / 23 /
   30 points in a tree); two full trees cost 60 > 30; no build holds four
   keystones. This row goes red if anyone re-tunes the cadence without
   re-tuning the trees.
3. **Spend rules**, as a table of cases: a tier-2 rank with 4 points in the
   tree is refused and with 5 accepted; a tier-3 rank with 11 refused, 12
   accepted; tier 4 with 19 refused, 20 accepted; a tier-2 rank whose
   tier-1 chain talent is at 4/5 is refused; a sixth rank refused; a spend
   with 0 points left refused; a spend at level 1 refused; **Unseen refused
   at 25 points in Veil and accepted at 26** (§2.8's exception).
4. **Persistence round trip.** Serialize → parse → identical; forged meta
   (`unknown_id=2,unseen=9`) is dropped and clamped; a forged mid-chain rank
   drops everything below it in that chain.
5. **Effect-key coverage.** Every key in the closed vocabulary is read by at
   least one consumer source file, and every `effects` key a talent uses is in
   the vocabulary. This is the row that goes red when a talent is added whose
   modifier nothing applies — the failure mode a numeric talent system has.
6. **Cap invariants.** With every crit talent at rank 5 on a level-60
   character and **no** window running, `get_crit_chance` still returns
   ≤ 0.30; with every dodge talent maxed, `get_dodge_chance` ≤ 0.30; with the
   armor talents maxed on 60 % gear, `get_armor_percent` ≤ 60. **With
   Ruination running, and only then,** crit may reach 0.55; **with Unbroken
   running, and only then,** armor may reach 80.
7. **Window lifecycle.** Every timed window returns 0 before it starts and
   after it expires, and respec, class change, death and leave clear it.
8. **The shared central seams stay neutral without talents.** The six talents
   that hook `arm_cooldown` (`grug_abilities/init.lua:1233`), the charge line (`:718`), the
   spend line (`:1232`) and `get_range` (`:170-177`) sit on paths every
   ability of every class runs through. One case per seam with **no talent
   ranked** must reproduce today's value exactly — Taunt 8 s, Blink 15 s,
   Smite 2 s, Hamstring 6 s, Fireball 8 mana and 20 m, and an elf's Fireball
   still 25 m.

**Mutation proof** the review should demand: revert the one line of
`stats.lua:45` that adds `crit_chance_add` and group 5 goes red; give a
tier-1 talent 6 ranks and group 1 goes red; make the `arm_cooldown` read
default to 1 instead of 0 and group 8 goes red; let a window key leak past its
expiry and group 7 goes red.

### 3.8 What changes where

| File | Change | Size |
|---|---|---|
| `grug_classes/talents.lua` | **new** — registry, the 48 talents of the three shipped classes (3 classes x 2 trees x 8), spend/respec, persistence, window table, the two accessors | large |
| `grug_classes/talents_ui.lua` | **new** — the sfinv page of §3.5 | medium |
| `grug_classes/init.lua:210-213` | two `dofile` lines | 2 lines |
| `grug_classes/mod.conf` | two dependency edges: `sfinv` and `grug_money` | 1 line |
| `grug_classes/stats.lua:20,30,45,49,90` | five talent reads (max HP, max mana, crit + crit-cap, dodge, the level-up line with the `old_level ~= nil` guard) | small |
| `grug_abilities/kits.lua:342,370,372,453-460,458,495,496,504,505,533,591,613,640,671` | one talent read per numeric talent whose number lives inside a function body, plus Warded Wrath's shield gate at `kits.lua:591` | medium |
| `grug_abilities/init.lua:170-177,718,1232,1233` | the four **central per-player seams** the load-time constants force (§3.2) | small |
| `grug_abilities/init.lua:939,950,966,1719,1724,1808,1858,2109,2202` | rage per swing; the grant predicate at the three `talent_gated` sites; the append-after-base-kit rule; rage per hit taken; in-combat mana regen | small |
| `grug_abilities/kits.lua` (new section) | **15 new ability registrations** for the three shipped classes — 11 keystones and 4 skill capstones (§2.9) | **large** |
| `grug_inventory/equipment.lua:479-480` | Ironbound and Unbroken, and the cap override | small |
| `grug_core/combat.lua:38,241,963` and `grug_abilities/init.lua:910` | armor cap override; heal threat factor; the threat multiplier on **both** its sites (cast and swing) | small |
| `tools/wp11/talent_tree_kat.lua` | **new** — §3.7 | medium |
| `docs/design/classes.md`, `progression.md`, `combat_stats.md`, `economy.md`, `items_crafting.md`, `README.md` | the "base value" wording of §2.10, the retired class-trainer respec seam (§6.9) and the design-tour row (`AGENTS.md:84-86`) | small |

---

## 4. Implementation lanes

Revision 1 cut WP11 into four lanes on the assumption of five new abilities.
With **13** (§2.9) the capstone work no longer fits one lane, so the cut is
five, in dependency order. Lanes X2, X3a and X3b can run in parallel once X1
has landed; X4 needs X1 only.

| Lane | Scope | Depends on | Size |
|---|---|---|---|
| **X1 — the model** | `talents.lua`: registry, the 48 talent registrations of the three shipped classes (data only, no consumer), points, the two gate kinds, spend/respec rules, persistence with the validating read path, the window table, `get_talent_bonus` / `talent_rank`, the `on_talents_changed` callback, and the whole KAT of §3.7 except group 5's consumer half. Ships with **zero gameplay effect** — every talent is inert. | — | M |
| **X2 — the numeric consumers** | The 30 numeric talents of the three shipped classes at the sites of the §3.8 table. **Twenty-four are a one-line read where the table says; six hook the four central per-player seams of §3.2**, and each of those needs its own no-talent regression case (KAT group 8). Completes KAT groups 5 and 6. Touches shared files, so it is one lane and not split by class. | X1 | M |
| **X3a — keystones** | **Eleven** new ability registrations — Warrior: Hold Ground, Bellow, Broadstroke, Pin; Mage: Brand, Cinderfall, Frostbind, Glacial Ward; **Priest: Turn Aside, Word of Ruin, Recompense** — plus Renew's rank scaling (the twelfth keystone, already registered at `kits.lua:651-677`), the grant predicate at the three `talent_gated` sites, the append-after-base-kit rule of §3.4, and an engine probe per ability. | X1 | L |
| **X3b — capstones** | **Four** new ability registrations (Ruination, Whitehot, Hearten, Last Word) plus the two no-key effects (Unbroken, Rimebite), the two **cap-override** paths (`stats.lua:45`, `equipment.lua:480` and `combat.lua:38`) and the `combat_stats.md` §2 amendment they need. **Only starts once §6.5 is answered**; if the answer is "caps hold", it shrinks to M. | X1, §6.5 | L |
| **X4 — UI, level-up and respec** | The sfinv Talents page of §3.5, the two `mod.conf` edges, the level-up chat line with its `old_level ~= nil` guard, the respec transaction against `grug_money.take`, the price of §6.8, and the raw-vs-effective display `combat_stats.md:104-108` requires. | X1 | M |

X3a and X3b are the only lanes that owe a runtime test on a headless server;
X1, X2 and X4 are provable with the KAT plus one probe each.

The Scout's own lanes are [scout.md](scout.md) §7 and are **not** part of
WP11: they need the talent machinery (X1-X4) first.

---

## 5. Decided 2026-09-16 (the user's rulings)

These are the user's decisions of 2026-09-16, recorded as the binding frame
for this revision. Each is followed by what it replaced.

### 5.1 The rulings

1. **Talent points.** One point every 2 levels, the first at level 2 → **30
   points at level 60**. "Two thirds" was a rough guideline; slight deviation
   is fine. *(Built into §1.3.)*
2. **Tree size.** About **30 ranks per tree** (≈60 per class), so a player can
   fill one tree completely **or** spread over both with one prioritised. A
   full tree is **not** forced. Each tree contains **two rough playstyle
   directions (chains)**. Dependencies of both kinds: level/points gating
   **and** hard chains ("all ranks in A before B"). Rank counts vary **3-5**
   by talent strength; no need to invent more talents to reach 30 — vary
   ranks. *(Built into §1.1, §1.2; the chain is 5/4/3/3.)*
3. **Keystones and capstones.** Per tree: **two keystones and one capstone**.
   A keystone is a **new active skill** at a chain/tier boundary; the capstone
   is the **top talent of the tree** — a skill or a strong effect, and **not
   every capstone is a skill**. The capstone hangs on **its direction's
   chain**, not on the whole tree. *(Built into §1.2, §2; six capstones are
   skills and two are effects.)*
4. **No class trainer.** New skills come **only** from the tree; the base kit
   at class choice stays. Damage and effect improvements of skills come from
   the tree too. **Respec for money, in the talent UI, no NPC.** *(Built into
   §1.4, §3.5. The user is recorded as "against money" as the respec's price
   shape — see §6.8.)*
5. **Names.** Tree names as proposed stay (Bulwark/Ruin, Ember/Rime,
   Mercy/Reckoning). **Talent** names must not remind of WoW — rename every
   talent the review flagged (Meditation, Kindling, Cripple) and check the
   rest. *(Done in §2.11.)*
6. **Caps** *(coordinator proposal, not a user ruling)*: talents work within
   the `combat_stats.md` caps (30 % crit, 30 % dodge, 60 % armor); **only
   capstones may exceed a cap, time-limited**. *(Used by §2.1 and §2.2; it is
   open decision §6.5 and needs the user's yes.)*
7. **A fourth class, "Scout"** (the user's chosen name), leather armour,
   planned now and implemented later: two trees, ranged (bow) and melee
   (rogue-like). **No poison** — "no new combat mechanic"; the rogue direction
   uses existing stats: timed dodge windows, crit chance, cripple/slow,
   escape/retreat moves, traps if cheap. **Invisibility is the capstone of the
   melee tree, reachable only by a "pure" build.** *(§2.7, §2.8,
   [scout.md](scout.md).)*
8. **Invisibility rules** (2026-09-16, second set): combat **breaks** it
   (dealing or taking damage, casting a hostile ability); there is a
   **detection chance** even while invisible when very close to a mob; mobs
   and guards of a **higher level than the player** have a markedly higher
   detection chance — "no level-40 player sneaks past a level-60 mob or
   guard"; invisibility **significantly reduces movement speed**.
   *([scout.md](scout.md) §5; numbers are §6.15.)*
9. **Sprint** (2026-09-16, second set): a new talent idea for the rogue
   direction or for both leather trees — about **10 s of markedly increased
   movement speed**. *(§2.7 as the Ranging keystone; the percentage is §6.13,
   and it collides with a decided pillar — see scout.md §6.)*

### 5.2 What each ruling replaced

**The retired text no longer exists on this branch**, because this lane's own
commits replaced it. Every line number in the left-hand column is therefore a
line on **`main` at `70dda602`**, written `main:NNN`, and the retired sentence
is quoted in full so the supersession can be checked without a second
checkout. Line numbers elsewhere in this file are branch-relative.

| Ruling | Replaces (on `main` at `70dda602`) |
|---|---|
| 1 | `progression.md main:28` "**1 talent point every 3 levels** (20 points total at 60)" **and** `combat_stats.md main:14` "the class skill tree (**1 skill point per level**)". Revision 1's open decision about which one won is closed: **neither**. |
| 2 | `progression.md main:29-30` "talent trees hold 2 trees × 5 talents × 3 ranks = 30 ranks per class — you can fill two thirds: real choices, no full clear (WP11)" and `BACKLOG.md main:34`'s repetition of it |
| 3 | `progression.md main:31-35` "**9 of 10 talents are numeric modifiers** (cheap to build, easy to balance); **exactly one capstone per tree**, unlocked at 8+ points in that tree, and **every capstone is a NEW active 'main skill'** … (e.g. Priest Holy capstone: Renew; further capstones designed with WP11)" |
| 4 | `progression.md main:36-37` "**Respec at the class trainer for gold**, price rising with level — repeatable per-character gold sink and the class trainer's purpose", together with `economy.md:92`, `items_crafting.md:2380` and `world.md:408`, which this lane does not own and which still say it (§6.9) |
| 5 | revision 1's naming open decision, for talents |
| 7 | `classes.md main:466-470` "**Poison → arrives with the Rogue in Phase 2** (noted 2026-08-08). Poison is intended as the **Rogue's signature damage type** … and the Rogue is the Phase 2 class" — the Phase-2 Rogue is **superseded by the Scout**, and with it the poison plan. The bullet is now `classes.md:470-482` on this branch and quotes its own retired text. |

### 5.3 Where each correction is made

One commit per file, this lane's files only:

| File | Correction |
|---|---|
| `docs/design/progression.md` | §2's cadence, tree-size and capstone bullets; the respec location; the pointer paragraph |
| `docs/design/combat_stats.md` | `:13-15`'s "1 skill point per level" |
| `docs/design/classes.md` | the pointer paragraph; `:466-478`'s Phase-2 Rogue marked superseded by the Scout |
| `BACKLOG.md` | the WP11 row and the `:539-540` respec-price note |

**Not this lane's files, and therefore still wrong after this lane**:
`economy.md:92`, `items_crafting.md:2380` and `world.md:408` still send the
player to a class trainer. §6.9 carries them.

---

## 6. Open decisions for the user

Numbered for the reply. Each carries the options and a recommendation; none of
them is decided here.

**6.1 — Where this proposal lives while it is open.**
`AGENTS.md:66-71` reserves `docs/design/` for decided design with no open
questions and puts open questions in a root `TODO-<topic>.md` that is folded
in and deleted on decision. This file and `scout.md` are in `docs/design/`
because the lane brief named that path.
*(a)* Keep both here with the PROPOSAL banner and strip §6 when it is decided.
*(b)* Move §§1-5 to `TODO-design-skill-trees.md` now.
**Recommendation: (a)** — one file, one review, the banner is unambiguous, and
the layering rule is satisfied the moment §6 is answered and removed.

**6.2 — WP11 now registers fifteen new abilities. Is that one work package?**
Ruling 3 makes every keystone a new active skill, so the three shipped classes
gain **11 keystones** (12 minus the already-registered Renew) **and 4 skill
capstones** (§2.9) against revision 1's five registrations in total. That is
the biggest cost change in this revision and it is not a design question but a
scoping one.
*(a)* WP11 ships all of it, in the five lanes of §4.
*(b)* WP11 ships X1, X2, X3a and X4 — model, numerics, the **eleven
keystones** and the UI — and the four skill capstones plus the two no-key
capstone effects become their own follow-up WP (the id is the coordinator's;
`BACKLOG.md` uses `WP-Scout` for the class so that this split can keep
`WP11b`), after the first playtest of the trees. Every tree is then fully
playable to 20 points in it, which is level 40, and the capstone beat
(level 42-46) lands one WP later.
**Recommendation: (b)** — the capstones are the only part that needs the cap
decision (§6.5), the only part with no shipped machinery to lean on, and the
only part a player cannot see before level 42. Splitting there costs nothing
and halves the first delivery.

**6.3 — Talents on an admin level drop.**
`/xp` can lower a level (`grug_xp/init.lua:142-162`), after which spent ranks
can exceed `floor(level / 2)`.
*(a)* Block further spending until the level catches up and leave existing
ranks alone.
*(b)* Auto-refund the excess ranks, cheapest tier first.
**Recommendation: (a)** — (b) silently unspends a player's choices for an
admin action, and the validating read path of §3.3 already keeps the state
unreachable by anything but an admin.

**6.4 — The Scout's resource, and what feeds a bow's damage.**
Neither is decided anywhere. `classes.md` §1 knows two resources (rage, mana)
and `combat_stats.md` §1 gives Dexterity only crit and dodge, so a bow has no
damage attribute today.
*(a)* The Scout uses **Focus**, a rage-shaped 0-100 pool generated by landed
hits — the same shipped machinery (`grug_abilities.add_rage`, the HUD) under a
different name and colour — and bow damage is `weapon damage + floor(Dex/10)`
through a new `grug_classes.get_ranged_bonus` beside `get_melee_bonus`
(`stats.lua:34-36`), which is one accessor and an addition to
`combat_stats.md` §2.
*(b)* A third, time-regenerating resource (energy) and Str-fed bow damage.
**Recommendation: (a)** — (b) is a new resource system and a bow that scales
off Strength reads wrong on a leather class; (a) adds one accessor and one
sentence to a decided file. It does need the user's yes, because it puts a
third damage term into `combat_stats.md` §2.

**6.5 — May a capstone exceed a cap, time-limited?** *(ruling 6 is a
coordinator proposal and needs confirmation.)*
`combat_stats.md:104-108` says values above a cap "have no further combat
effect" and that "there is no automatic overflow conversion or cap raise".
Two capstones in §2 are built on the exception: Unbroken (armor cap 60 → 80 %
for 8 s, once per 3 min) and Ruination (crit cap 30 → 55 % for 10 s).
*(a)* Accept ruling 6: talents respect the caps, **capstones alone** may
exceed one, always for a bounded time, always written into `combat_stats.md`
§2 with the number.
*(b)* Caps hold absolutely. Unbroken becomes flat armor inside 60 % — which
gives a plate Warrior already at the cap nothing at all, the one class it
exists for — and Ruination becomes a rage/damage window instead.
**Recommendation: (a)**, with the constraint written down: a cap override is a
capstone-only, time-limited, single-source value, never additive with a second
override, and the Character page shows the raised cap while it runs
(`combat_stats.md:104-108` already requires effective **and** raw). Whichever
way it goes, this decision gates lane X3b.

**6.6 — The "Holy tree" rename has two sites left, one of them code.**
`classes.md:459` ("Unlocked via the Holy tree (WP11)") and the comment
`mods/PLAYER/grug_abilities/kits.lua:650` ("the Holy tree unlocks it in
WP11"). Mercy is the same tree. Revision 1 named a third site,
`progression.md`'s "Priest Holy capstone"; this lane's own `progression.md`
commit removed that sentence with the capstone rule it belonged to, so the
decision is smaller than it was.
*(a)* Rename both when the decision lands.
*(b)* Keep "Holy" as the tree name and drop "Mercy".
**Recommendation: (a)** — ruling 5 keeps the proposed tree names, and "Holy
tree" is the one unambiguous 1:1 carry-over of a WoW tree name in the repo.

**6.7 — The Scout's two tree names.**
The coordinator suggested **Hunt / Veil**. This proposal uses **Quarry /
Veil**, because "The Hunt" is a Demon Hunter ability in WoW while "Quarry"
(the hunted thing) has no collision the author is aware of.
*(a)* **Quarry / Veil** (used throughout §2.7, §2.8 and scout.md).
*(b)* **Hunt / Veil** (the coordinator's pair).
*(c)* **Hunt / Shroud** as the alternative pair.
**Recommendation: (a)** — same shape as Bulwark/Ruin and Ember/Rime, and the
one of the three with no WoW echo.

**6.8 — The respec price, when the respec has no NPC.**
Ruling 4 puts the respec in the talent UI and records the user as "against
money". `BACKLOG.md:540-548` carries the only number in the repo: 5c × level,
min 25c, spent through `grug_money.take`
(`mods/PLAYER/grug_money/init.lua:122`). `economy.md` §3 forbids a stale fixed
copper table and requires time-priced sinks to derive from measured reliable
net solo income.
*(a)* **Keep `BACKLOG.md`'s formula** — 5c × level, minimum 25c — as the
shipped number, and let WP44 recalibrate it with every other sink. Simplest,
and it retires the leftover by using it.
*(b)* **Measured**: five minutes of reliable net solo income at the
character's bracket, rounded by `economy.md` §4.1's rule. Correct by
`economy.md` §3, but it cannot be priced until WP44 measures the brackets.
*(c)* **Free, with a cooldown** (one respec per N hours), which is what "the
user is against money" reads like at face value. No sink, no `grug_money`
edge, one timestamp in player meta.
**Recommendation: (a) now, (b) at WP44** — it gives WP11 a number today and
the economy its rule later. But (c) is the honest reading of "against money"
and should be put to the user explicitly: if respec is meant to be free, the
`grug_money` dependency edge of §3.1 disappears and `economy.md` §4 loses a
sink it currently counts on.

**6.9 — Three decided files outside this lane still send the player to a
class trainer.**
`economy.md:92`, `items_crafting.md:2380` and `world.md:408`. Ruling 4 retired
the trainer; this lane may not edit those files.
*(a)* A follow-up docs commit (the wave's docs-alignment lane) corrects all
three in one pass.
*(b)* They are corrected when WP11 ships.
**Recommendation: (a)** — three sentences, and until then the repo states two
different respec locations.

**6.10 — Is a respec a class change? Four shipped comments say yes.**
`grug_inventory/equipment.lua:57` ("later WP11 respec"), `:501` ("Admin-only
today, **player-reachable with WP11's respec**"), `:579` ("a Warrior who
respecs to Mage") and `grug_core/combat.lua:110` ("WP11's respec unequipping
what the new class may not wear") all assume WP11's respec is what makes the
class-change unequip path player-reachable. §1.4 says the opposite.
*(a)* A respec re-spends talents only; a class switch stays admin-only. The
four comments are **wrong on the day WP11 lands** and must be corrected in the
same WP, and `equipment.lua:501`'s promise stays unkept.
*(b)* The talent UI also sells a class change, which keeps all four comments
true and gives the unequip path its first real user.
**Recommendation: (a)** — a talent respec and a class change are different
products; but (a) is only honest if those four comments are corrected with it,
so that correction belongs in WP11's scope either way.

**6.11 — A pure-Ruin Warrior fills all eight hotbar keys, from level 46.**
§3.4's table: Strike plus four class abilities is five keys, and three talent
skills make eight. The timing is what sharpens this: §1.3 works the cheapest
route to three new skills out at **23 points in one tree = level 46**, so the
full hotbar is not a level-60 endgame state a player grows into — it is
two-thirds of the way up the curve, with a quarter of the points still in
hand, and it lasts for fourteen levels of play before anything else changes.
`classes.md:466` parks "Warrior shield abilities → after WP14
(offhand/shields)" as the next claim on those keys, and `register_ability`
already carries the `slot = "offhand"` plumbing
(`grug_abilities/init.lua:501-510`).
*(a)* Accept 8 of 8 and let WP14 decide then.
*(b)* Make one Warrior keystone a no-key effect the way Unbroken and Rimebite
are, so the worst case is 7 of 8. Pin is the candidate.
*(c)* Accept 8 of 8 **and** write into `classes.md` §6 that WP14's Warrior
shield work has **zero** free hotbar keys and must therefore live on the
offhand slot or replace an existing button.
**Recommendation: (c) plus (b)** — (b) costs one keystone its button and buys
back the margin for every other class too; (c) hands WP14 the constraint
instead of the surprise.

**6.12 — One absorb per player, and now four writers.**
`grug_core/combat.lua:1003-1012`: one shield per player, a new one replaces
the old. Power Word: Shield (base kit), Glacial Ward (Mage keystone), Hold
Ground (Warrior keystone) and Recompense (Priest keystone) all write it, so a
healer shielding the tank **deletes the tank's own cooldown**.
*(a)* Accept and document it as a known interaction.
*(b)* Give `grug_core` a second absorb slot reserved for **self-cast** sources,
soaked after the first. Two numbers instead of one in one file, and it makes a
tank cooldown reliable.
**Recommendation: (b)** — with four writers the collision stops being a corner
case; it is roughly twenty lines in `combat.lua` and it removes the worst
feel-bug in the design.

**6.13 — Sprint's percentage is the one number the mob game is built on.**
`mounts.md:173-190` states the pillar outright: aggressive mobs run 4.4
against a player's 4.0 (`combat_stats.md:310-315`), and the 25 m soft
de-aggro, the 45 m chase give-up and the 40 m leash all assume the mob can
close. It is why the **Swiftness Draught is capped at +8 % for 15 s**
(`items_crafting.md` §10 P4: 4.0 × 1.08 = 4.32 < 4.4) and why a mount dismounts
on any damage. A "markedly increased movement speed" for 10 s (ruling 9) is
above that ceiling by construction.
*(a)* **+8 / 9 / 10 %** — rank 3 reaches exactly 4.4, the mob speed, and never
passes it. Honest to the pillar; arguably not "markedly".
*(b)* **+25 % for 10 s** (5.0 nodes/s), a deliberate, bounded pillar
exception: for ten seconds the Scout outruns every aggressive mob. It must
then be written into `combat_stats.md` §3 and `mounts.md` as the second
exception beside the Kraken Guard, and every consequence the mounts rule lists
applies for those ten seconds.
*(c)* **+25 % but out of combat only**, refused while the `in_combat` window
runs (`grug_core.in_combat`, used at `grug_abilities/init.lua:2201`) — a
travel tool, not an escape tool, and the pillar is untouched.
**Recommendation: (c)**, and §2.7's table uses it — it delivers the "markedly
faster" feel the ruling asks for without touching the one inequality the mob
game rests on, and the three ranks buy duration (10 / 12 / 14 s) rather than
more speed. If the user wants it in combat, (b) is the honest form and needs
the two design docs amended in the same WP; (a) is the only option that
changes nothing and is also the one nobody will feel.

**6.14 — How is Unseen made "pure"?**
Ruling 7 says invisibility must need a "pure" build, so Unseen needs a
prerequisite no other talent has.
*(a)* A **per-talent gate override** — 26 points in Veil instead of §1.2's
uniform 20 — used exactly once and asserted by `register_talent`. Rank 1 at
the 27th point (level 54), at most 4 points left for Quarry.
*(b)* Keep the gate uniform at 20 and add a **double hard chain**: both Veil
keystones at 3/3. That costs `5+4+3 + 5+4+3 = 24` points in Veil before Unseen
is offered; rank 1 is the 25th point (level 50), rank 3 the 27th (level 54),
and a level-60 Scout who maxes it has 3 points for Quarry.
**Recommendation: (b)**, and §2.8's table uses it — it reaches the same place
with the dependency kind ruling 2 already names, keeps one gate rule for the
whole system, and gives the KAT one invariant instead of two.

**6.15 — Invisibility's numbers.**
The mechanism is [scout.md](scout.md) §5; the numbers are:
detection radius band (proposed **3 m always-detect / 3-8 m rolled / beyond
8 m never**), base roll per tick (proposed **10 % per second inside the
band**), the level term (proposed **+5 percentage points per level the
mob/guard is above the Scout, no bonus below**), tick rate (proposed **1 Hz**,
on the existing mob step rather than a new globalstep), and the movement
penalty (proposed **×0.6 speed**, ruling 8's "significantly reduces").
*(a)* Ship the proposed numbers and tune them in a playtest.
*(b)* Decide them now.
**Recommendation: (a)**, with the level term as the one number that is not a
tuning knob: ruling 8's "no level-40 player sneaks past a level-60 mob or
guard" means a 20-level gap must be a near-certain detection, and +5 points
per level reaches 100 % at exactly 20 levels. That is the number to keep even
if the others move.
