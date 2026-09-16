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
  are *not* this lane's files and still carry the retired seam — see §6.10.
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
| **30 / 0** (pure) | both keystones, the capstone and every rank of one tree — **one** new button (the tree's new-skill keystone), one replaced button, and the capstone |
| **23 / 7** | one chain complete through its capstone; the other tree's entry talent maxed plus two |
| **21 / 9** | capstone rank 1 plus one maxed keystone; no keystone in the second tree |
| **20 / 10** | **both** keystones of the prioritised tree at rank 1 (both chains through tier 2 = 18, then one point in each keystone); the second tree gets a maxed tier-1 and most of a tier-2 |
| **15 / 15** | one complete chain, keystone included, in **each** tree — up to **two** new buttons, one per tree |
| **13 / 13** (+4 spare) | one keystone in each tree at rank 1, four points free — the cheapest route to both new buttons, at level 52 |

**No build can hold more than two new hotbar buttons.** Ruling 13 puts at most
one new-skill keystone in each tree, so a build's ceiling is one per tree, and
both are reachable: 13 points in each tree is 26 of 30 (§1.3's milestone
table), i.e. **both new buttons by level 52, with 4 points spare**. Every
other keystone and every capstone changes a button the player already has, or
no button at all.

That is the whole of the hotbar question. Before ruling 13 a pure-tree build
reached **three** new buttons at 23 points — level 46 — and a Warrior then
filled all eight keys with a quarter of their points unspent; §3.4 works the
new budget out per class and it tops out at **7 of 8**.

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
  returns all points, free. Four shipped comments assume the opposite — §6.11.

---

## 2. The talents

Reading the tables:

- **Chain** is the direction inside the tree (§1.1); **Tier** carries its gate
  from §1.2, and every talent below tier 1 additionally needs all ranks of the
  talent above it in its own chain.
- **Ranks** is the number of ranks and the per-rank progression.
- **Kind** is what a tier-3 or tier-4 talent *is*, under ruling 13:
  - **new skill** — a new hotbar button and a new `grug_abilities`
    registration. **At most one per tree**, so a build can never hold more
    than two.
  - **replaces** — an existing button keeps its key and changes what it does.
    No registration, no key; the talent is read inside the shipped ability's
    own body.
  - **effect** — a passive or triggered effect with no button at all. Every
    capstone is one of these last two.
  - **rule-breaker** — additionally marked `‼`. Ruling 10 permits a talent to
    break a base inequality (mob 4.4 > player 4.0, a stat cap, immunity to
    roots); the **limit is stated in the same cell** and is the price.
- **Effect** is written in the vocabulary of `combat_stats.md` §1/§2/§4 —
  armor percent, crit chance, dodge chance, max HP, max mana, rage, spell
  power, threat, absorb, root and slow duration. **No talent introduces a new
  mitigation term**, and no talent introduces a new *mechanic*: every one is
  a number, a duration or a flag on machinery the game already runs.
- **Modifies** names the shipped line the rank changes. **A kit table's
  `cooldown`, `charge`, `range` and `max_distance` fields are evaluated once
  at load time with no player in scope**, so talents that re-tune those hook
  the central per-player site instead — §3.2 lists the four of them.
- **Key** is the effect key of the data model in §3.2.

### 2.1 Warrior — Bulwark

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|---|
| 1 | **Ironbound** | Wall | 1 | 5 | — | +1 / 2 / 3 / 4 / 5 armor percent, under the 60 % cap | `grug_inventory/equipment.lua:479` | `armor_percent_add` |
| 2 | **Weathered** | Wall | 2 | 4 | — | max HP +3 / 6 / 9 / 12 | `grug_classes/stats.lua:20` | `max_hp_add` |
| 3 | **Hold Ground** *(keystone)* | Wall | 3 | 3 | **new skill** ‼ | cast, 25 rage, self; absorbs `20 / 30 / 40 + 2 × floor(Str/10)` for 8 s, **and for those 8 s the Warrior cannot be rooted or slowed**. *Limit: 8 s, **60 s cooldown**.* | new; `grug_core.set_absorb` (`grug_core/combat.lua:1012`); the immunity is a flag the speed aggregator of §3.9 already has to read | — |
| 4 | **Unbroken** *(capstone)* | Wall | 4 | 3 | **effect** ‼ | the first time in **180 s** that a hit would take the Warrior below 20 % max HP: armor percent +10 / 15 / 20 **and the 60 % armor cap rises to 70 / 75 / 80 %**, for 8 s. *Limit: 8 s, **180 s**.* | the two clamps, `grug_inventory/equipment.lua:480` and `grug_core/combat.lua:38`, plus the hp-change modifier that observes the threshold | `armor_cap_override` |
| 5 | **Spite** | Anvil | 1 | 5 | — | +1 / 2 / 3 / 4 / 5 rage per hit taken (base 4) | `grug_abilities/init.lua:2109-2110` | `rage_per_hit_taken_add` |
| 6 | **Affront** | Anvil | 2 | 4 | — | tank-ability threat ×3 → ×3.25 / 3.5 / 3.75 / 4.0 | **two sites**: `grug_core/combat.lua:963` (casts) and `grug_abilities/init.lua:910`, applied at `:955-957` (swings) | `threat_mult_add` |
| 7 | **Bellow** *(keystone)* | Anvil | 3 | 3 | **replaces Taunt** | Taunt stops being single-target: it forces **every** hostile mob within 6 / 8 / 10 m onto the Warrior for its 3 s, same key, same 8 s cooldown | `kits.lua:389-404`, the cast body, run over the radius loop of `kits.lua:490` | `taunt_radius` |
| 8 | **Grudge** | Anvil | 4 | 3 | — | Taunt cooldown 8 s → 7 / 6 / 5 s | `grug_abilities/init.lua:1233`, the one `arm_cooldown(user, def, def.cooldown)` call — **not** `kits.lua:387` | `taunt_cooldown_sub` |

Hold Ground is Bulwark's one new button and the tree's one rule-breaker
besides the capstone. Its break is the useful one for a tank: a Warrior who
has committed to holding a spot cannot be kited off it for eight seconds. The
named consequence stays: there is **one absorb per player and a new one
replaces the old** (`grug_core/combat.lua:1003-1012`), so a Priest's Power
Word: Shield cast onto the Warrior overwrites Hold Ground — §6.9 below.

### 2.2 Warrior — Ruin

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|---|
| 1 | **Heavy Hand** | Hammer | 1 | 5 | — | Mighty Blow ×1.5 → ×1.55 / 1.60 / 1.65 / 1.70 / 1.75 weapon damage | `kits.lua:342` | `mighty_blow_multiplier_add` |
| 2 | **Stoke** | Hammer | 2 | 4 | — | +1 / 2 / 3 / 4 rage per landed authoritative swing (base 12) | `grug_abilities/init.lua:939`, `:950`, `:966` | `rage_per_swing_add` |
| 3 | **Broadstroke** *(keystone)* | Hammer | 3 | 3 | **new skill** | swing, 30 rage, 10 s charge; on a landed swing `floor(weapon damage × 2.0 / 2.25 / 2.5) + melee bonus` on the target and half of that, rounded down, on every other hostile within 3 m; ×3 threat | new; the `proc_swing` shape of `kits.lua:340-344` plus the radius loop of `kits.lua:490` | — |
| 4 | **Ruination** *(capstone)* | Hammer | 4 | 3 | **effect** ‼ | a landed Broadstroke grants 10 s of crit chance +15 / 20 / 25 percentage points **with the 30 % crit cap raised to 45 / 50 / 55 %**. *Limit: 10 s, **120 s cooldown** on the trigger.* | `grug_classes/stats.lua:45` and its `math.min(0.30, …)` | `crit_cap_override` |
| 5 | **Keen Edge** | Lash | 1 | 5 | — | +1 / 2 / 3 / 4 / 5 percentage points crit chance (30 % cap holds) | `grug_classes/stats.lua:45` | `crit_chance_add` |
| 6 | **Hobble** | Lash | 2 | 4 | — | Hamstring charge 6 s → 5.5 / 5.0 / 4.5 / 4.0 s | `grug_abilities/init.lua:718`, the one line that arms a charge — **not** `kits.lua:356` | `hamstring_charge_sub` |
| 7 | **Tendon Cut** *(keystone)* | Lash | 3 | 3 | **replaces Hamstring** ‼ | Hamstring's charged proc **roots** for 2 / 2.5 / 3 s before its 50 % slow begins — a root off an ordinary swing. *Limit: **12 s internal cooldown**, independent of the charge, so a faster charge cannot shorten it.* | `kits.lua:368-374`, using the root machinery of `:495` (players) and `:504` (mobs) | `hamstring_root` |
| 8 | **Deadweight** | Lash | 4 | 3 | — | Hamstring's 50 % slow lasts 5 s → 6 / 7 / 8 s | `kits.lua:370` (mobs) and `:372` (players) | `hamstring_slow_add` |

Broadstroke is the game's first melee cleave and needs no new timing
machinery: it rides the authoritative swing exactly as Mighty Blow does
(`classes.md` §2b), and its charge keeps it off every swing. Tendon Cut is
Ruin's one rule-breaker: a Warrior who invests in the snare chain gets a hard
stop the class does not otherwise have, on a timer that is deliberately not
the one Hobble shortens.

**User finding, 2026-09-16 (ruling 16): rage fills too fast.** "In combat the
resource is effectively unlimited." Every talent in this tree assumes rage is
a limiter — Stoke adds to it, Heavy Hand and Broadstroke spend it, Ruination
costs nothing but rides a Broadstroke — so if the pool is always full, three
of the eight talents are re-tuning a number nobody feels. The shipped
generation and spend numbers, the arithmetic and two calibration options are
**open decision §6.2**; nothing in these tables is changed for it, because the
fix belongs to `classes.md` §3 rather than to WP11.

Charge (`kits.lua:291`) is the one shipped ability whose **own** numbers — 10 s
cooldown, 12 m reach, 3 damage, 15 rage — no talent re-tunes: a deliberate
gap, and a hook for a later third Warrior direction. It is not untouched,
though: Affront raises the tank-ability threat multiplier, and Charge is the
**only** caller in the game that passes one to a cast (`kits.lua:312`,
`threat_mult = 3`, read at `grug_core/combat.lua:963`).

### 2.3 Mage — Ember

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|---|
| 1 | **Tinder** | Blaze | 1 | 5 | — | Fireball `6 + spell power` → `+1 / 2 / 3 / 4 / 5` | `kits.lua:458` | `fireball_damage_add` |
| 2 | **Firebrand** | Blaze | 2 | 4 | — | +1 / 2 / 3 / 4 percentage points crit chance | `grug_classes/stats.lua:45` | `crit_chance_add` |
| 3 | **Brand** *(keystone)* | Blaze | 3 | 3 | **replaces Fireball** | Fireball's impact splashes `2 / 3 / 4 + floor(spell power / 2)` to every other hostile within 2 m. Same key, same 8 mana, same straight flight | `kits.lua:429` (the projectile's on-hit) plus the radius loop of `kits.lua:490` | `fireball_splash` |
| 4 | **Whitehot** *(capstone)* | Blaze | 4 | 3 | **effect** ‼ | the first Fireball that **crits** starts an 8 s window in which Fireball costs **4 mana instead of 8** and deals `+4 / 6 / 8`. *Limit: 8 s, **120 s cooldown** on the trigger.* | `grug_abilities/init.lua:1232` (`spend(user, def.cost)`) and `kits.lua:458` | `whitehot_window` |
| 5 | **Deep Well** | Cinder | 1 | 5 | — | max mana +3 / 6 / 9 / 12 / 15 % | `grug_classes/stats.lua:30` | `max_mana_percent_add` |
| 6 | **Far Cast** | Cinder | 2 | 4 | — | Fireball maximum distance 20 m → 21.5 / 23 / 24.5 / 26 m | two per-player reads, neither at a registration constant: the spawn call (`kits.lua:453-460`, since `grug_projectiles/init.lua:195` prefers `params.max_distance` over the registered `kits.lua:413`), and targeting reach in `grug_abilities.get_range` (`init.lua:170-177`), whose item-meta override `sync_kit` already refreshes (`grug_abilities/init.lua:1827-1831`) | `fireball_range_add` |
| 7 | **Cinderfall** *(keystone)* | Cinder | 3 | 3 | **new skill** | cast, 12 mana, 10 s cooldown, 20 m; a burst at the first thing the crosshair ray meets, dealing `5 / 7 / 9 + spell power` to every hostile within 3 m of it | new; `grug_core.combat_ray` (`kits.lua:58`) plus the radius loop of `kits.lua:490` | — |
| 8 | **Ashfall** | Cinder | 4 | 3 | — | Cinderfall's radius 3 m → 4 / 5 / 6 m | the new Cinderfall registration | `cinderfall_radius_add` |

Fireball's flight is not eaten by the longer range: `lifetime = 2`
(`kits.lua:420`) at `speed = 20` (`:412`) allows 40 m. Ember takes **no**
rule-breaker besides its capstone — see §2.9's note on the bounded pass.

### 2.4 Mage — Rime

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|---|
| 1 | **Deep Chill** | Frost | 1 | 5 | — | Frost Nova root 4 s → 4.2 / 4.4 / 4.6 / 4.8 / 5.0 s | `kits.lua:495` (players) and `:504` (mobs) | `frost_nova_root_add` |
| 2 | **Hoarfrost** | Frost | 2 | 4 | — | Frost Nova follow-up slow 3 s → 4 / 5 / 6 / 7 s (the 50 % stays) | `kits.lua:496` and `:505` | `frost_nova_slow_add` |
| 3 | **Frostbind** *(keystone)* | Frost | 3 | 3 | **replaces Frost Nova** | Frost Nova stops being self-centred: it is cast at the pointed hostile up to 20 m away and roots everything within 3 / 4 / 5 m **of the target**. Same key, same 10 mana, same 12 s cooldown — a control tool instead of a panic button | `kits.lua:488-490` (the cast body and its radius origin) | `frost_nova_ranged` |
| 4 | **Rimebite** *(capstone)* | Frost | 4 | 3 | **effect** | every root Frost Nova applies also deals `3 / 5 / 7 + floor(spell power / 2)` on application | `kits.lua:495-505` | `control_damage_add` |
| 5 | **Cold Focus** | Ward | 1 | 5 | — | in-combat mana regeneration 0.5 %/s → 0.6 / 0.7 / 0.8 / 0.9 / 1.0 %/s | `grug_abilities/init.lua:2202` | `combat_mana_regen_add` |
| 6 | **Quick Step** | Ward | 2 | 4 | — | Blink cooldown 15 s → 13.5 / 12 / 10.5 / 9 s | `grug_abilities/init.lua:1233` — **not** `kits.lua:526` | `blink_cooldown_sub` |
| 7 | **Glacial Ward** *(keystone)* | Ward | 3 | 3 | **new skill** | cast, 10 mana, 30 s cooldown, self; absorbs `10 / 15 / 20 + 2 × spell power` for 10 s | new; `grug_core.set_absorb` (`grug_core/combat.lua:1012`) | — |
| 8 | **Far Step** | Ward | 4 | 3 | — | Blink distance 10 m → 12 / 14 / 16 m | `kits.lua:533` (inside the cast body, player in scope) | `blink_distance_add` |

Rime also takes no rule-breaker besides its capstone, and its capstone does
not break one either — Rimebite is simply a strong effect. Same absorb caveat
as §2.1: Glacial Ward and Power Word: Shield overwrite each other (§6.9).

### 2.5 Priest — Mercy

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|---|
| 1 | **Gentle Hand** | Balm | 1 | 5 | — | Flash Heal `8 + 2 × spell power` → `+1 / 2 / 3 / 4 / 5` | `kits.lua:613` | `flash_heal_add` |
| 2 | **Quiet Steps** | Balm | 2 | 4 | — | heal threat factor 0.5 → 0.45 / 0.40 / 0.35 / 0.30 (`combat_stats.md` §4) | `grug_core/combat.lua:241`, read at `:417` inside `add_heal_threat` (`:404`) | `heal_threat_factor_sub` |
| 3 | **Renew** *(keystone)* | Balm | 3 | 3 | **new skill** *(already registered)* | the shipped ability (`kits.lua:651-677`), granted at rank 1 exactly as `classes.md` §5 specifies (6 mana, 8 s cooldown, `3 + spell power` every 3 s for 12 s); ranks 2 and 3 raise the tick to `4` and `5 + spell power` | `kits.lua:671`; the grant gate is `talent_gated = true` at `kits.lua:656` | `renew_tick_add` |
| 4 | **Hearten** *(capstone)* | Balm | 4 | 3 | **replaces Flash Heal** | Flash Heal also heals every **other** ally within 8 m for `50 / 65 / 80 %` of the amount. Same key, same 8 mana, same 4 s cooldown — the Priest's group heal, without a group-heal button | `kits.lua:612-614` plus the radius loop of `kits.lua:490` | `flash_heal_splash` |
| 5 | **Warding Faith** | Aegis | 1 | 5 | — | Power Word: Shield absorb `+1 / 2 / 3 / 4 / 5` | `kits.lua:640` | `shield_absorb_add` |
| 6 | **Deep Reserve** | Aegis | 2 | 4 | — | max mana +3 / 6 / 9 / 12 % | `grug_classes/stats.lua:30` | `max_mana_percent_add` |
| 7 | **Turn Aside** *(keystone)* | Aegis | 3 | 3 | **replaces Power Word: Shield** | while the shield holds (at most its 15 s), its target's dodge chance is +10 / 15 / 20 percentage points, **inside** the 30 % cap. Same key, same cost — the shield now buys avoidance as well as absorption | `kits.lua:639-640` and `grug_classes/stats.lua:49` | `dodge_chance_window` |
| 8 | **Second Skin** | Aegis | 4 | 3 | — | Power Word: Shield lasts 15 s → 18 / 21 / 24 s | `kits.lua:640` (the `15` argument) | `shield_duration_add` |

Renew is Mercy's **keystone**, and it is the one new-skill keystone in the
whole design that is **already registered**. `progression.md` §2 called it
"the Priest Holy capstone"; ruling 3 re-cut what a capstone is, and the
correction is in `progression.md`'s own commit (§5.3). `classes.md:459`'s
sentence stays true apart from the tree's name.

### 2.6 Priest — Reckoning

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|---|
| 1 | **Sharpened Word** | Word | 1 | 5 | — | Smite `4 + spell power` → `+1 / 2 / 3 / 4 / 5` | `kits.lua:591` | `smite_damage_add` |
| 2 | **Swift Word** | Word | 2 | 4 | — | Smite cooldown 2 s → 1.85 / 1.7 / 1.55 / 1.4 s | `grug_abilities/init.lua:1233` — **not** `kits.lua:581` | `smite_cooldown_sub` |
| 3 | **Word of Ruin** *(keystone)* | Word | 3 | 3 | **new skill** | cast, 8 mana, 12 s cooldown, 20 m; `6 / 8 / 10 + spell power` damage, healing the Priest for 50 % of it | new; `grug_core.deal_ability_damage` returns the post-crit amount (`grug_core/combat.lua:970`), healed back with `grug_core.heal_player(…, {no_crit = true})` (`:977-981`, `:984`) | — |
| 4 | **Last Word** *(capstone)* | Word | 4 | 3 | **effect** ‼ | while the Priest is below 25 % max HP, Word of Ruin's drain heals for **125 / 150 / 175 %** of the damage dealt — above the 100 % the pipeline otherwise allows. *Limit: 8 s per trigger, **180 s cooldown**.* | the drain half of the Word of Ruin registration | `drain_ratio_override` |
| 5 | **Hard Faith** | Wrath | 1 | 5 | — | +1 / 2 / 3 / 4 / 5 percentage points crit chance | `grug_classes/stats.lua:45` | `crit_chance_add` |
| 6 | **Warded Wrath** | Wrath | 2 | 4 | — | while the Priest carries an absorb shield, Smite deals `+1 / 2 / 3 / 4` | `kits.lua:591`, gated on `grug_core.get_absorb(user) > 0` (`grug_core/combat.lua:1020`) | `smite_damage_while_shielded_add` |
| 7 | **Recompense** *(keystone)* | Wrath | 3 | 3 | **replaces Smite** | Smite costs 6 mana instead of 4 and grants the Priest an absorb of `6 / 9 / 12 + spell power` on every landed cast, refreshing rather than stacking. Same key — the solo nuke becomes the solo sustain | `kits.lua:583-592` and `grug_core.set_absorb` (`grug_core/combat.lua:1012`) | `smite_absorb` |
| 8 | **Hardened** | Wrath | 4 | 3 | — | max HP +4 / 8 / 12 | `grug_classes/stats.lua:20` | `max_hp_add` |

Word of Ruin's drain is specified as "50 % of the damage dealt **before the
target's armor**": `deal_ability_damage` returns the amount the ability
published, taken before the central modifier applies armor (`:36-42`) and the
absorb shield (`grug_core/combat.lua:1003-1030`) to a *player* target. Against a mob it is exactly
what landed.

### 2.7 Scout — Quarry (planned, not implemented)

The Scout's kit, resource, armour, bow and the **deferred stealth work** are
[scout.md](scout.md); its two trees are here so that §1.3's arithmetic and
§2.11's name audit cover all four classes. Every "Modifies" cell would say
*new*, because none of the code exists yet, so the column is dropped.

Ruling 12 makes the Scout **as simple as possible**: no invisibility in
version 1, no poison, no traps, and every talent built from a mechanic the
game already runs.

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Key |
|---|---|---|---|---|---|---|---|
| 1 | **Strong Draw** | Draw | 1 | 5 | — | Loose damage `+1 / 2 / 3 / 4 / 5` | `loose_damage_add` |
| 2 | **Cold Eye** | Draw | 2 | 4 | — | +1 / 2 / 3 / 4 percentage points crit chance | `crit_chance_add` |
| 3 | **Twin Shot** *(keystone)* | Draw | 3 | 3 | **replaces Loose** | a full draw looses two arrows, the second for `50 / 60 / 70 %` damage; costs 2 arrows. Same key | `loose_second_arrow` |
| 4 | **Longshot** *(capstone)* | Draw | 4 | 3 | **replaces Loose** | Loose's range 25 m → 30 / 33 / 36 m, and a hit landed beyond 25 m deals `+2 / 4 / 6` | `loose_range_add` |
| 5 | **Quiver** | Ranging | 1 | 5 | — | Loose's arrow is not consumed 10 / 20 / 30 / 40 / 50 % of the time | `arrow_refund_chance` |
| 6 | **Fletching** | Ranging | 2 | 4 | — | Loose's draw time 0.5 s → 0.45 / 0.40 / 0.35 / 0.30 s | `draw_time_sub` |
| 7 | **Pinning Shot** *(keystone)* | Ranging | 3 | 3 | **new skill** ‼ | cast, 25 m; roots the pointed hostile for 2 / 2.5 / 3 s — a root at bow range, which no class has. *Limit: **30 s cooldown**.* | — |
| 8 | **Shifting Weight** | Ranging | 4 | 3 | — | +1 / 2 / 3 percentage points dodge chance | `dodge_chance_add` |

### 2.8 Scout — Veil (planned, not implemented)

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Key |
|---|---|---|---|---|---|---|---|
| 1 | **Fine Edge** | Blade | 1 | 5 | — | +1 / 2 / 3 / 4 / 5 damage on a landed authoritative swing | `melee_damage_add` |
| 2 | **Deep Focus** | Blade | 2 | 4 | — | max resource +3 / 6 / 9 / 12 % | `max_mana_percent_add` |
| 3 | **Opening** *(keystone)* | Blade | 3 | 3 | **new skill** | swing, 12 s charge; on a landed swing taken from **behind** the target (a yaw comparison, no new state), `floor(weapon damage × 2.2 / 2.5 / 2.8) + melee bonus` | — |
| 4 | **Follow Through** | Blade | 4 | 3 | — | Opening's charge 12 s → 10 / 8 / 6 s | `opening_charge_sub` |
| 5 | **Light Step** | Shadow | 1 | 5 | — | +1 / 2 / 3 / 4 / 5 percentage points dodge chance | `dodge_chance_add` |
| 6 | **Slip Away** | Shadow | 2 | 4 | — | Sidestep's cooldown 30 s → 26 / 22 / 18 / 14 s | `sidestep_cooldown_sub` |
| 7 | **Shake Loose** *(keystone)* | Shadow | 3 | 3 | **replaces Sidestep** ‼ | Sidestep also clears every slow and root on the Scout, and for its 4 s the Scout cannot be slowed or rooted again. Same key. *Limit: 4 s, on Sidestep's own **30 s cooldown** (and Slip Away shortens it, which is the trade).* | `root_slow_immunity` |
| 8 | **Untouchable** *(capstone)* | Shadow | 4 | 3 | **effect** ‼ | when the Scout drops below 30 % max HP: dodge chance +20 / 25 / 30 percentage points **and the 30 % dodge cap rises to 50 / 55 / 60 %**, for 6 s. *Limit: 6 s, **180 s cooldown**.* | `dodge_cap_override` |

**Untouchable replaces version 1's invisibility capstone** (ruling 12). The
invisibility rulings, the detection-roll design and the full conflict analysis
are kept intact in [scout.md](scout.md) §8, "Deferred: stealth v2" — nothing is
lost, it is simply not in the first version. Untouchable is what a "pure Veil"
build gets instead: a six-second window in which a leather class survives a
burst that would kill it, built from the dodge stat the game already rolls.

### 2.9 Count

| | Per tree | Per class | All four classes |
|---|---|---|---|
| Talents | 8 | 16 | **64** |
| Ranks | 30 | 60 | **240** |
| Numeric talents (tiers 1, 2 and the tier-4 finisher) | 5 | 10 | **40** |
| Keystones | 2 | 4 | **16** |
| …of which **add a new skill** (ruling 13: at most one per tree) | 1 | 2 | **8** |
| …of which **replace an existing skill** | 1 | 2 | **8** |
| Capstones (never a new skill) | 1 | 2 | **8** |
| …effects | — | — | **6** (Unbroken, Ruination, Whitehot, Rimebite, Last Word, Untouchable) |
| …replacements | — | — | **2** (Hearten, Longshot) |

**New ability registrations: 8 across all four classes** — one per tree, the
new-skill keystones: Hold Ground, Broadstroke, Cinderfall, Glacial Ward,
Renew, Word of Ruin, Pinning Shot, Opening. Of those, **Renew already exists
in code** (`kits.lua:651-677`) and **two belong to the unimplemented Scout**
(Pinning Shot, Opening), so:

> **WP11 registers five new abilities** — Hold Ground, Broadstroke,
> Cinderfall, Glacial Ward, Word of Ruin.

That is ruling 13's whole point and it is the largest scope change in this
revision: the pre-ruling design registered **fifteen**, and eight new buttons
per build was more than `classes.md` §2b's hotbar can carry. Nothing was cut
from the *design* — the other eleven talents that used to be new skills are
now replacements or effects, which is a cheaper implementation **and** a
better one, because a replacement deepens a button the player already knows
instead of adding a ninth.

**Hotbar budget** (ruling 13's second half): a new skill is one per tree, and
no build can reach more than one per tree, so **no build exceeds base kit + 2
keys**. §3.4 works it out per class; the worst case is a Warrior at 7 of 8,
which leaves WP14's shield work a key. **This resolves what the previous
revision carried as open decision §6.11.**

**Rule-breakers** (ruling 10), all with their limit in the cell:

| Tree | Rule-breaker besides the capstone | Capstone breaks a rule? |
|---|---|---|
| Bulwark | **Hold Ground** — root/slow immunity, 8 s, 60 s cd | yes — Unbroken, armor cap → 80 %, 8 s / 180 s |
| Ruin | **Tendon Cut** — root off a swing, 12 s internal cd | yes — Ruination, crit cap → 55 %, 10 s / 120 s |
| Ember | none | yes — Whitehot, half mana cost, 8 s / 120 s |
| Rime | none | no |
| Mercy | none | no |
| Reckoning | none | yes — Last Word, drain > 100 %, 8 s / 180 s |
| Quarry | **Pinning Shot** — a root at 25 m, 30 s cd | no (Longshot is a plain replacement) |
| Veil | **Shake Loose** — root/slow immunity, 4 s, 30 s cd | yes — Untouchable, dodge cap → 60 %, 6 s / 180 s |

The pass is bounded at **at most** one per tree, not exactly one, and it was
used **twice in the six shipped-class trees**. Rime, Mercy and Ember took none
because their fantasies did not need one, and leaving headroom is cheaper than
inventing breaks: every rule-breaker is a rule the KAT then has to prove is
broken *only* under its own conditions.

Effect keys, counted from the Key column of §§2.1-2.8: **57 key cells, 50
distinct** (7 rows carry no key — the eight new-skill keystones minus Renew,
whose rank scaling does have one). **Three** keys are shared across classes:
`crit_chance_add` (all four), `max_mana_percent_add` (Mage, Priest, Scout) and
`max_hp_add` (Warrior, Priest). `dodge_chance_add` appears twice but **both
are the Scout** (Shifting Weight in Quarry, Light Step in Veil) — shared across
trees, not classes. §3.2's closed vocabulary and §3.7's KAT group 5 are sized
on the 50.

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

**Nine talents deliberately break a decided rule, and every one states its
price.** Ruling 10 is what permits it — "skills may explicitly break the base
inequalities; that is what skills are for (Blink and a dodge roll already do).
The bigger the break, the stronger the limit, usually cooldown or duration."
All nine are listed in §2.9 with their limits — four rule-breakers besides a
capstone, and five capstones that break one. Three break a **cap**, which
`combat_stats.md:104-108` otherwise forbids outright ("values above a cap
remain present on their stacks but have no further combat effect… there is no
automatic overflow conversion or cap raise"): Unbroken (armor → 80 % for 8 s),
Ruination (crit → 55 % for 10 s) and Untouchable (dodge → 60 % for 6 s). Four
break an **immunity or control rule** (Hold Ground, Shake Loose, Tendon Cut,
Pinning Shot), one breaks a **resource cost** (Whitehot) and one a **healing
ratio** (Last Word). The Scout's base-kit Sprint is a tenth, and it is not a
talent — [scout.md](scout.md) §2 carries it.

`combat_stats.md` §2 therefore needs one new paragraph when WP11 lands — not a
new stat, but the sentence that says caps are absolute **except** for a named,
time-limited, single-source override, and that the Character page shows the
raised cap while it runs (`:104-108` already requires effective **and** raw).
That amendment is lane X3's, and it is the only decided-doc change the talent
system forces. Talents that are *not* marked `‼` stay inside every cap, so
Turn Aside's +20 dodge is clamped at 30 % like any gear roll.

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

- **Low risk (no collision either reader is aware of), 59 names:** Ironbound,
  Weathered, Hold Ground, Unbroken, Spite, Affront, Bellow, Grudge, Heavy
  Hand, Stoke, Broadstroke, Ruination, Keen Edge, Hobble, Deadweight, Tinder,
  Firebrand, Brand, Whitehot, Deep Well, Far Cast, Cinderfall, Ashfall,
  Hoarfrost, Frostbind, Rimebite, Cold Focus, Quick Step, Far Step, Gentle
  Hand, Quiet Steps, Hearten, Warding Faith, Deep Reserve, Turn Aside, Second
  Skin, Sharpened Word, Swift Word, Word of Ruin, Last Word, Hard Faith,
  Warded Wrath, Recompense, Hardened, Strong Draw, Cold Eye, Twin Shot,
  Longshot, Fletching, Pinning Shot, Shifting Weight, Fine Edge, Deep Focus,
  Follow Through, Light Step, Slip Away, Shake Loose, Untouchable, Tendon
  Cut.
- **Medium risk, flagged and NOT renamed** — the user's call, alternatives
  given:

  | Name | Why | If the user wants it changed |
  |---|---|---|
  | **Deep Chill** | the shape of *Deep Freeze* (Frost Mage) | **Long Winter** |
  | **Glacial Ward** | near *Ice Ward* / *Ice Barrier* (Frost Mage) | **Coldshell** |
  | **Quiver** | an ordinary noun and a Hunter aura in some expansions | **Full Quiver** |
  | **Opening** | generic, but next to WoW's "opener" vocabulary | **First Cut** |

  *Retired from this list by the third round of rulings*: **Pin** became
  **Tendon Cut** when it turned into a Hamstring replacement, and **Sprint**
  left the trees for the Scout's base kit ([scout.md](scout.md) §2), where the
  same medium-risk note applies and **Break Away** is the alternative.

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
-- with talents, cap-aware (§2.10; ruling 10)
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

### 3.4 Granting a new skill, and replacing an existing one

**Two mechanisms, and ruling 13 makes the second one carry most of the
design.**

**A new skill** (the eight new-skill keystones of §2.9) is an ordinary
`grug_abilities` registration with `talent_gated = true`, exactly like Renew
today (`kits.lua:656`). **Three** existing sites test that flag, and the file
itself states they must never disagree (`grug_abilities/init.lua:1705-1710`):

- `kit_of(class)` drops every `talent_gated` def in both of its loops, the
  universal one (`init.lua:1719`) and the class one (`:1724`). It becomes
  `kit_of(class, player)` and keeps a gated def when
  `grug_classes.talent_rank(player, def.talent) > 0`.
- The purge branch in `sync_kit` (`init.lua:1808-1810`) uses the same
  predicate, or a granted skill would be destroyed on the next sync.

`kit_of` has exactly one caller (`init.lua:1858`) and the grant loop passes
its index straight to `grant_at`, so a def's position in that list **is** its
hotbar key. Registering the new abilities after the class section keeps every
base ability at the key it has today — the concern the file's own comment
raises at `init.lua:1712-1715`. Renew is the exception: it is *not* appended,
it is already the fourth entry of `by_class["priest"]` (`kits.lua:651`, after
Smite `:572`, Flash Heal `:596` and Power Word: Shield `:623`), so a gated def
unlocked later could still shift it. The rule that makes the guarantee true
for every class: **a talent-granted ability is placed in the first free slot
after the base kit, in unlock order, not at its `kit_of` index.** Under ruling
10 at most two such abilities exist per build, so this is now one rule
covering two slots rather than a shuffling problem.

**A replacement** (the eight replacing keystones and the two replacing
capstones) is **not** a registration and touches none of the above. The
shipped ability keeps its id, its key, its icon and its registration; the
talent is a read inside its own `cast` or `proc_swing` body, exactly like
every numeric talent in §2 — Bellow is a radius the Taunt body reads, Hearten
is a loop the Flash Heal body runs, Frostbind is where Frost Nova takes its
origin from. That is why ruling 13 is cheaper as well as kinder to the
hotbar: **ten of the sixteen keystones and capstones cost zero new
registrations, zero new items and zero grant logic.**

Re-granting is driven by a new callback mirroring `register_on_class_chosen`
(`grug_classes/init.lua:68`, consumed at `grug_abilities/init.lua:1881`):

```lua
grug_classes.register_on_talents_changed(function(player) sync_kit(player) end)
```

It fires on every spend and on respec. A replacement needs no re-grant at all
— the next cast simply reads a different number.

**Hotbar budget** (`classes.md` §2b reserves keys 1-8). Under ruling 13 the
ceiling is **base kit + 2**, and it is the same for every class:

| Class | Base kit | Max new buttons | Worst case |
|---|---|---|---|
| Warrior | Strike + 4 (`kits.lua:268`, `:291`, `:321`, `:350`, `:380`; `classes.md:419-422`) = 5 | 2 (Hold Ground, Broadstroke) | **7 of 8** |
| Mage | Strike + 3 = 4 | 2 (Cinderfall, Glacial Ward) | 6 of 8 |
| Priest | Strike + 3 = 4 | 2 (Renew, Word of Ruin) | 6 of 8 |
| Scout | Strike + 4 ([scout.md](scout.md) §2) = 5 | 2 (Pinning Shot, Opening) | 7 of 8 |

The Warrior is still the tightest and still has **one free key**, which is
what `classes.md:466`'s parked "Warrior shield abilities → after WP14
(offhand/shields)" needs — and `register_ability` already carries the
`slot = "offhand"` plumbing for them (`grug_abilities/init.lua:501-510`).
**This is what closes the hotbar question**; it was open decision §6.11 in the
previous revision and is now decided by ruling 13 (§5.1).

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
| `grug_abilities/kits.lua` (new section) | **5 new ability registrations** for the three shipped classes — the new-skill keystones Hold Ground, Broadstroke, Cinderfall, Glacial Ward and Word of Ruin (§2.9) | medium |
| `grug_abilities/kits.lua:389-404, 429, 488-490, 583-592, 612-614, 639-640, 368-374` | **the six replacing keystones and capstones** of the three shipped classes — Bellow, Tendon Cut, Brand, Frostbind, Turn Aside, Recompense, Hearten — each a read inside the shipped ability's own body, no registration (§3.4) | medium |
| `grug_inventory/equipment.lua:479-480` | Ironbound and Unbroken, and the cap override | small |
| `grug_core/combat.lua:38,241,963` and `grug_abilities/init.lua:910` | armor cap override; heal threat factor; the threat multiplier on **both** its sites (cast and swing) | small |
| `grug_core/` the speed aggregator | **prerequisite, not this WP** — §3.9. Hold Ground's and Shake Loose's root/slow immunity are flags it owns, and the Scout's Sprint is a modifier in it | — |
| `tools/wp11/talent_tree_kat.lua` | **new** — §3.7 | medium |
| `docs/design/combat_stats.md` §2 | the **cap-override paragraph** of §2.10 — the one decided-doc amendment the talent system forces | small |
| `docs/design/classes.md`, `progression.md`, `economy.md`, `items_crafting.md`, `README.md` | the "base value" wording of §2.10 and the retired class-trainer respec seam (§6.10) | small |

### 3.9 The speed aggregator (ruling 11) — a prerequisite this WP does not own

Three talents and one base-kit ability in this design write the player's
movement speed: Hold Ground and Shake Loose set a **root/slow immunity flag**,
the Scout's Sprint sets a **+25 % modifier**, and Tendon Cut and Pinning Shot
apply a **root**. They cannot be written the way the game writes speed today.

`mods/ENTITIES/grug_mobs/verbs.lua:100-118` says so in its own comment: there
are **two independent owners** of `physics_override.speed` — mob webs
(`verbs.lua:140-169`) and the ability snare chain (`kits.lua:144-175`) — each
keyed by player name, each restoring to `speed = 1` when its own effect ends,
"so an overlapping mob web + player snare can end early (the first restore
lifts both)… **the fix is one shared owner in `grug_core`**". `mounts.md:128-133`
and `boats.md:113-117` both lean on that count being two, and both state that
a mount's speed is the entity's velocity and therefore **adds no third owner**.

**Ruling 11 decides the shape**: one central aggregator in `grug_core` where
each system registers a **named** modifier with its **own duration**; effects
overlap freely; a **root is a hard flag** — speed 0 regardless of modifiers,
never a "−1000 %"; **mounts stay outside it**, exactly as `mounts.md:128-133`
already requires.

```lua
-- names are the owner's, durations are independent, nothing restores to 1
grug_core.set_speed_modifier(player, "sprint", 0.25, 10)     -- +25 % for 10 s
grug_core.set_speed_modifier(player, "mob_web", -0.40, 7)    -- a web
grug_core.clear_speed_modifier(player, "sprint")
grug_core.set_root(player, 3)            -- hard flag: speed 0 for 3 s
grug_core.set_speed_immunity(player, 8)  -- Hold Ground / Shake Loose
```

**Recommended combination rule: additive percentages, then one clamp.**
`speed = clamp(1 + Σ modifier, 0.1, 1.5)`, with a root or a zero clamp taking
precedence, and an immunity discarding negative modifiers and roots for its
duration. Additive is the recommendation over a product for three reasons: it
is what the shipped numbers already read like (a 50 % slow is `speed = 0.5`,
`kits.lua:372`), two slows multiplying to 0.25 is a stacking rule nobody
decided, and a sum is the only form in which the KAT can state a single
invariant ("no combination leaves the player below 0.1 or above 1.5") without
enumerating orders.

**Size: roughly 100 lines** — a per-player table of named entries with
expiries, one accumulator, the two existing writers migrated onto it, the
join/leave reset that `verbs.lua:176-186` already has, and a KAT for overlap,
expiry, root precedence and immunity.

**It is a prerequisite, and it is not WP11's.** The mob-pressure lane needs it
for the same reason (`docs/research/mob-pressure-task-card.md` carries it as
that lane's prerequisite, since a mob that must keep moving while it swings
is the other consumer). WP11 should **not** start Hold Ground, Shake Loose or
anything Scout-shaped until it exists; everything else in §4 is independent of
it.

---

## 4. Implementation lanes

Ruling 13 shrank this WP more than any other decision in the revision: five
new ability registrations instead of fifteen, and ten of the sixteen keystones
and capstones now cost no registration at all (§3.4). The five-lane cut of the
previous revision collapses back to **four**, in dependency order. X2, X3 and
X4 run in parallel once X1 has landed.

| Lane | Scope | Depends on | Size |
|---|---|---|---|
| **X1 — the model** | `talents.lua`: registry, the 48 talent registrations of the three shipped classes (data only, no consumer), points, the two gate kinds, spend/respec rules, persistence with the validating read path, the window table of §3.2, `get_talent_bonus` / `talent_rank`, the `on_talents_changed` callback, and the whole KAT of §3.7 except group 5's consumer half. Ships with **zero gameplay effect** — every talent is inert. | — | M |
| **X2 — the numeric consumers** | The 30 numeric talents of the three shipped classes at the sites of the §3.8 table. **Twenty-four are a one-line read where the table says; six hook the four central per-player seams of §3.2**, and each of those needs its own no-talent regression case (KAT group 8). Completes KAT groups 5 and 6. Touches shared files, so it is one lane and not split by class. | X1 | M |
| **X3 — keystones and capstones** | **Five** new ability registrations (Hold Ground, Broadstroke, Cinderfall, Glacial Ward, Word of Ruin), Renew's rank scaling, the grant predicate at the three `talent_gated` sites and the append-after-base-kit rule of §3.4; **six replacements** written inside the shipped abilities' own bodies (Bellow, Tendon Cut, Brand, Frostbind, Turn Aside, Recompense, Hearten); the **six capstone effects**; the three **cap-override** paths (`stats.lua:45` and `:49`, `equipment.lua:480` with `combat.lua:38`) and the `combat_stats.md` §2 amendment of §2.10; an engine probe per new ability and per replacement. **Hold Ground's root/slow immunity needs the §3.9 aggregator first.** | X1, §3.9 for one talent | L |
| **X4 — UI, level-up and respec** | The sfinv Talents page of §3.5, the two `mod.conf` edges, the level-up chat line with its `old_level ~= nil` guard, the respec transaction against `grug_money.take`, the price of §6.8, and the raw-vs-effective display `combat_stats.md:104-108` requires — including the **raised cap** while a rule-breaker runs. | X1 | M |

X3 is the only lane that owes a runtime test on a headless server; X1, X2 and
X4 are provable with the KAT plus one probe each. A **replacement** owes a
probe of its own kind: the shipped ability must still behave exactly as
`classes.md` §§3-5 specifies with the talent unranked, and differently with it
ranked — that is the mutation proof for ten of the sixteen.

**Outside this WP but ahead of it**: the speed aggregator of §3.9 (~100 lines
in `grug_core`), which the mob-pressure lane owns and which X3 needs for one
talent. The Scout's own lanes are [scout.md](scout.md) §7 and need X1-X4
first.

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
   the `combat_stats.md` caps; only capstones may exceed a cap, time-limited.
   **SUPERSEDED the same day by ruling 10**, which widens it: rule-breaker
   talents may too. It is no longer an open decision.*
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
   *([scout.md](scout.md) §5; they are deferred whole to [scout.md](scout.md) §8.)*
9. **Sprint** (2026-09-16, second set): a new talent idea for the rogue
   direction or for both leather trees — about **10 s of markedly increased
   movement speed**. *(Refined by ruling 10 below; it is now the Scout's
   base-kit ability, [scout.md](scout.md) §2.)*

**Third round, 2026-09-16.** These four change the design more than any of the
first nine, and two of them retire earlier recommendations of this file.

10. **Rule-breaking, with limits.** "Skills may explicitly **break the base
    inequalities** (mob 4.4 > player 4.0, stat caps, roots) — that is what
    skills are for (Blink and a dodge roll already do). The rule: **the bigger
    the break, the stronger the limit**, usually cooldown or duration."
    **Sprint stays IN combat**, ~10 s, cooldown **at least 3 minutes, rather
    5** — "a deliberate special, not an every-fight button." This **replaces**
    the coordinator's cap proposal (ruling 6): **capstones AND rule-breaker
    talents** may exceed caps, time-limited. *(§2's `‼` marks, §2.9's table,
    §2.10. It **withdraws this file's previous recommendation** that Sprint be
    out-of-combat only, and it requires the `mounts.md` amendment named in
    §6.4.)*
11. **Speed ownership.** "Effects overlap freely with independent durations;
    the design is **one central aggregator in `grug_core`** where each system
    registers a **named modifier with its own duration**; a **root is a hard
    flag** (speed 0 regardless of modifiers), never a '−1000 %'; **mounts stay
    outside** the aggregator." *(§3.9 sizes it at ~100 lines and recommends
    additive percentages; it is a **prerequisite owned by the mob-pressure
    lane**, not by WP11, and the Scout's speed-and-stealth lane collapses into
    it.)*
12. **The Scout is as simple as possible**, and that has priority over "as
    cool as possible": **no invisibility in version 1** (the melee capstone
    becomes a strong time-limited effect built from existing stats), **no
    poison, no traps**; the bow family through the existing sprite generator;
    **arrows ballistic** with gravity, while **Fireball stays straight** —
    "the trajectory is what makes the archer hard"; leather borrows the cloth
    cut; a **base kit of four abilities from existing mechanics only**.
    *(§2.7, §2.8, and [scout.md](scout.md), whose §8 keeps ruling 8 and the
    whole stealth analysis as "deferred: stealth v2".)*
13. **Keystones may modify or replace existing skills** instead of adding new
    ones — "eight new abilities per build is too many." **Per tree at most ONE
    keystone that adds a new skill**; the other keystone improves or replaces
    an existing skill; **the capstone is an effect or a replacement.**
    *(§2 throughout, §2.9's recount to **eight** registrations across four
    classes and **five** in WP11, §3.4's two mechanisms, and §4's collapse
    back to four lanes. It **resolves** what was open decision §6.11: no build
    exceeds base kit + 2 keys.)*

**Fourth round, 2026-09-16.**

14. **The Scout uses mana.** Decided — no new resource, no renamed bar in the
    data model beyond its label. *(Closes what this file carried as an open
    decision; [scout.md](scout.md) §1.)*
15. **The HUD's heart statbars are rejected** — "half hearts are an ugly
    approximation". Ruling: a **thin, point-accurate LIFE bar**, and a
    **mana-or-rage bar directly above the hotbar slots**; every class has
    exactly **one** secondary bar. *(Not WP11 —
    `docs/research/hud-bars-task-card.md`.)*
16. **Warrior rage fills too fast** — "in combat the resource is effectively
    unlimited". A user finding, not yet a decision. *(§2.2's note and open
    decision §6.2.)*

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
| 4 | `progression.md main:36-37` "**Respec at the class trainer for gold**, price rising with level — repeatable per-character gold sink and the class trainer's purpose", together with `economy.md:92`, `items_crafting.md:2380` and `world.md:408`, which this lane does not own and which still say it (§6.10) |
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

**The third and fourth rounds of rulings closed five of the previous
revision's fifteen**, so this list is shorter and renumbered:

| Was | Now |
|---|---|
| 6.5 — may a capstone exceed a cap? | **decided** by ruling 10: capstones *and* rule-breaker talents may, time-limited (§2.10) |
| 6.11 — the Warrior's eight-of-eight hotbar | **decided** by ruling 13: no build exceeds base kit + 2, worst case 7 of 8 (§3.4) |
| 6.13 — Sprint's percentage and whether it may run in combat | **decided** by ruling 10: in combat, ~10 s, cooldown ≥ 3 min. Only the `mounts.md` amendment is left, as 6.4 below |
| 6.14 — how Unseen is made "pure" | **gone**: ruling 12 drops invisibility from version 1 |
| 6.15 — invisibility's numbers | **deferred**: kept whole in [scout.md](scout.md) §8, "stealth v2" |
| the Scout's resource | **decided** by ruling 14: mana |

**6.1 — Where this proposal lives while it is open.**
`AGENTS.md:66-71` reserves `docs/design/` for decided design with no open
questions and puts open questions in a root `TODO-<topic>.md` that is folded
in and deleted on decision. This file and `scout.md` are in `docs/design/`
because the lane brief named that path.
*(a)* Keep both here with the PROPOSAL banner and strip §6 when it is decided.
*(b)* Move §§1-5 to `TODO-design-skill-trees.md` now.
**Recommendation: (a)** — one file, one review, the banner is unambiguous, and
the layering rule is satisfied the moment §6 is answered and removed.

**6.2 — Warrior rage: the user's finding, and what to re-tune.** *(ruling 16)*
The user reports that "in combat the resource is effectively unlimited" —
Mighty Blow's 25 rage never gates anything. The shipped numbers, measured:

| Source | Amount | Where |
|---|---|---|
| landed authoritative swing | **+12 rage** | `grug_abilities/init.lua:939`, `:950`, `:966` |
| hit taken | **+4 rage**, +1 more for an orc | `grug_abilities/init.lua:2109-2110` |
| Charge | **+15 rage** | `kits.lua:311`; `classes.md:419` |
| Mighty Blow | **−25 rage**, no cooldown | `kits.lua:327`; `classes.md:420` |
| Hamstring | **−10 rage**, 6 s charge | `kits.lua:357` |
| Charge, Taunt | free | `kits.lua:298`, `:386` |
| pool | 0-100 | `classes.md` §1 |
| **decay out of combat** | **none in the tree** | there is no rage decay anywhere |

The arithmetic behind the report: a level-appropriate weapon's
`full_punch_interval` is 1.0 s for a 1H sword (`items_crafting.md:890`), so a
Warrior in a sustained fight generates **12 rage/s from swings alone**, plus
4 per hit taken. Mighty Blow costs 25 and has no cooldown, so it procs on
roughly **every other swing** — which is what `classes.md:424-425` says it was
tuned for — but the pool is nevertheless full whenever the player is not
spending, and nothing removes rage between fights. Two knobs, with numbers:

*(a)* **Raise the price, keep the income.** Mighty Blow 25 → 35, Hamstring
10 → 15, Broadstroke (§2.2) 30 → 40. At +12/swing that moves the dump from
every second swing to every third, and Stoke's +1-4 then buys back roughly a
tenth of a swing per rank rather than being almost invisible. Cheapest: three
constants, no new machinery, and `classes.md` §3's table moves with it.
*(b)* **Lower the income and add decay.** Swing 12 → 8, hit taken 4 → 3, and
**5 rage/s decay while out of combat** (the `grug_core.in_combat` window
already exists, read at `grug_abilities/init.lua:2201`), so a fight opens near
empty and Charge's +15 becomes the opener it reads like. This makes rage a
resource with a shape instead of a meter that is always full, but it is a new
ticker and it re-tunes every Warrior talent in §2.1-§2.2.
**Recommendation: (a) first, measured in a playtest, with (b) held in reserve**
— (a) is three numbers and cannot break anything; (b) changes the class's feel
between fights and should not be decided from the same report that (a) might
fix. Either way this is **not WP11's** to do: it is a `classes.md` §3 tuning
change, and WP11's talents must be re-checked against whichever number lands.

**6.3 — Talents on an admin level drop.**
`/xp` can lower a level (`grug_xp/init.lua:142-162`), after which spent ranks
can exceed `floor(level / 2)`.
*(a)* Block further spending until the level catches up and leave existing
ranks alone.
*(b)* Auto-refund the excess ranks, cheapest tier first.
**Recommendation: (a)** — (b) silently unspends a player's choices for an
admin action, and the validating read path of §3.3 already keeps the state
unreachable by anything but an admin.

**6.4 — Sprint is decided; the decided docs it contradicts are not.**
Ruling 10 settles the design: Sprint runs **in combat**, ~10 s, cooldown at
least 3 minutes and rather 5. What it does not settle is the paperwork, and
this one cannot be skipped, because three decided files state the opposite
rule as a pillar:

- `mounts.md:173-190` — "aggressive mobs `run_velocity` **4.4** against a
  player's **4.0** … the whole mob game is built on top of that one
  inequality", and the 25 m soft de-aggro, the 45 m give-up and the 40 m leash
  "all assume the mob can close the distance";
- `mounts.md:187-190` and `items_crafting.md` §10 P4 — the Swiftness Draught
  is capped at **+8 % for 15 s** precisely so that `4.0 × 1.08 = 4.32 < 4.4`;
- `combat_stats.md:310-315` — the speed table itself.

At the proposed **+25 % (5.0 nodes/s)** a sprinting Scout outruns every
aggressive mob in the game for ten seconds. That is exactly what ruling 10
permits, and it needs to be **written down as permitted** rather than left as
a contradiction a later reader files as a bug.
*(a)* Amend `mounts.md` §3.1's pillar paragraph and `combat_stats.md` §3 with
one sentence: the inequality holds **except** for named, time-limited,
long-cooldown skills, of which Sprint is the first, and the Swiftness
Draught's +8 % stays where it is because a consumable has no cooldown of that
order.
*(b)* Keep the pillar absolute and cap Sprint at +9 % (4.36 < 4.4), which is
ruling 10's own "arguably not markedly".
**Recommendation: (a)**, with the exact percentage (**+25 %**) and cooldown
(**3 or 5 minutes** — the ruling says "rather 5") confirmed in the same
answer. Neither file is this lane's to edit.

**6.5 — The combination rule inside the speed aggregator.** *(ruling 11)*
§3.9 recommends **additive percentages with one clamp**,
`speed = clamp(1 + Σ modifier, 0.1, 1.5)`, roots as a hard flag ahead of it.
*(a)* Additive, as recommended.
*(b)* Multiplicative, which makes two 50 % slows 0.25 rather than 0.
**Recommendation: (a)** — the shipped numbers already read as absolute speeds
(`kits.lua:372` sets `speed = 0.5`), nobody has decided a stacking rule, and a
sum is the only form in which the KAT can state one invariant instead of
enumerating application orders. This is the mob-pressure lane's to implement,
but it is a design answer and it belongs in this list.

**6.6 — The "Holy tree" rename has two sites left, one of them code.**
`classes.md:459` ("Unlocked via the Holy tree (WP11)") and the comment
`mods/PLAYER/grug_abilities/kits.lua:650` ("the Holy tree unlocks it in
WP11"). Mercy is the same tree. Revision 1 named a third site,
`progression.md`'s "Priest Holy capstone"; this lane's own `progression.md`
commit removed that sentence with the capstone rule it belonged to.
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

**6.9 — One absorb per player, and now four writers.**
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


**6.10 — Three decided files outside this lane still send the player to a
class trainer.**
`economy.md:92`, `items_crafting.md:2380` and `world.md:408`; a fourth,
`docs/research/post-wp40-readiness.md:81`, lists class trainers as a civic
service. Ruling 4 retired the trainer; this lane may not edit those files.
*(a)* A follow-up docs commit corrects all four in one pass.
*(b)* They are corrected when WP11 ships.
**Recommendation: (a)** — four sentences, and until then the repo states two
different respec locations.

**6.11 — Is a respec a class change? Four shipped comments say yes.**
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

**6.12 — What feeds a bow's damage?** *(the half of the old 6.4 that ruling 14
did not answer.)*
Ruling 14 decides the Scout's resource: **mana**. It does not say what scales
an arrow. `combat_stats.md:40-41` gives Dexterity only crit and dodge, and
`:42-47`'s melee damage is `weapon damage + floor(Str/10)`, so a bow has no
damage attribute today.
*(a)* `weapon damage + floor(Dex/10)`, through a new
`grug_classes.get_ranged_bonus` beside `get_melee_bonus`
(`grug_classes/stats.lua:34-36`) — one accessor, one sentence added to
`combat_stats.md` §2, and it makes the Scout's Dexterity-led growth mean
something.
*(b)* Reuse the melee bonus, so a bow scales off Strength.
*(c)* Reuse the spell-power bonus, so it scales off Intelligence — consistent
with the Scout paying mana.
**Recommendation: (a)** — (b) reads wrong on a leather archer and (c) makes
Intelligence the stat for both a Fireball and an arrow. It does add a third
damage term to a decided file, which is why it is a question and not an
assumption.
