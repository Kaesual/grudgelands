# Scout — the fourth class (PROPOSAL, 2026-09-16, NOT DECIDED)

**PROPOSAL, written with [skill_trees.md](skill_trees.md) revision 2.** The
user's ruling 7 of 2026-09-16 creates a fourth class, **Scout**, in leather
armour, with two trees — ranged (bow) and melee — **planned now and
implemented later**. Rulings 8 and 9 added invisibility rules and the Sprint
idea; **rulings 12 and 14 then cut the class back to its simplest workable
form**, which is what this file now describes. Nothing here is implemented and
nothing in `mods/` was changed for it.

> **Ruling 12 (user, 2026-09-16), and it has priority over everything else in
> this file:** the Scout is to be **as simple as possible**, ahead of "as cool
> as possible". **No invisibility in version 1**, no poison, no traps; the bow
> family through the existing sprite generator; **arrows ballistic** with
> gravity while **Fireball stays straight** — "the trajectory is what makes
> the archer hard"; leather borrows the cloth cut; a base kit of **four
> abilities from existing mechanics only**.
>
> **Ruling 14 (user, 2026-09-16):** the Scout **uses mana**. No new resource.

The invisibility rulings and the whole stealth analysis are **not deleted** —
they are §8, "Deferred: stealth v2", intact, so that the day the user wants
them the research is already done.

**Why this is its own file and not a chapter of `skill_trees.md`.** Most of
what a new class needs is not talent design: a weapon family that does not
exist, an armour line registered `false`, character visuals, trader stock and
a profession that already has an owner. The Scout's **two talent trees stay in
`skill_trees.md` §2.7/§2.8**, with all four classes' tables under one
arithmetic and one name audit; everything else is here. Both files are
proposals and both carry one shared open-decisions list (`skill_trees.md` §6).

---

## 1. What the Scout is

| | |
|---|---|
| **Armour** | leather — armor class 2 (`inventory_equipment.md:184-193`) |
| **Weapons** | bow (ranged) and dagger / 1H sword (melee) |
| **Resource** | **mana** — ruling 14, decided. The bar uses the class-neutral level pool `round(20 + 5L + 0.66L²)` before mana-percent gear/talents (`combat_stats.md` §2); Intelligence does not add mana |
| **Trees** | **Quarry** (bow) and **Veil** (blade and evasion) — `skill_trees.md` §2.7/§2.8, named by ruling 27 |
| **Attributes** | Dexterity-led; growth proposed **+2 Dex / +1 Str / +1 Int** per level, against `combat_stats.md:40-41`'s Warrior +3 Str/+1 Dex, Mage +3 Int/+1 Dex, Priest +1 Str/+2 Int/+1 Dex |
| **Role** | ranged damage that can also fight at knife range; the most evasive class in the game |

At level 60 the proposed growth gives Dex `10 + 2 × 59 = 128`, so
`combat_stats.md:55-56`'s formulas put the Scout at **17.8 % crit** and
**12.8 % dodge** from attributes alone — the highest of any class, and still
far under the 30 % caps, which is what leaves room for the dodge talents and
the dodge windows of §2.

The same growth gives Int `10 + 59 = 69`, while the class-neutral mana rule
gives the Scout the same **2696** base mana as every level-60 caster before
mana-percent gear/talents. Intelligence contributes spell power only. What
scales an **arrow** is ruling 28: `weapon damage + floor(Dex/10)`, through a
new `grug_classes.get_ranged_bonus` (`skill_trees.md` §7, task 9).

Ruling 12 rules out poison and traps outright, and ruling 7 already did for
poison: "no new combat mechanic". `classes.md:475-487` planned poison as "the
**Rogue's** signature damage type" for a Phase-2 Rogue class; **that plan is
superseded by the Scout** and the correction is made in `classes.md`'s own
commit.

## 2. Base kit

`classes.md:59` — "Three to four abilities per class in the MVP" — and ruling
12 names all four and requires each to be built from a mechanic the game
already runs. Four class abilities plus the universal Strike
(`kits.lua:288-310`) put the Scout on keys 1-5, and `skill_trees.md` §3.4's
ceiling of two talent buttons puts the worst case at 7 of 8.

| Ability | Kind | Cost | Cooldown | Effect | Existing mechanic it reuses |
|---|---|---|---|---|---|
| **Loose** | cast | 1 arrow | none (ammo-limited) | Requires a bow in the weapon slot. A **ballistic** arrow along the cast-time crosshair, 25 m, initial impulse from a bounded draw time, gravity supplying the trajectory | `grug_projectiles` — swept collision, owner validation, the per-owner active cap and max-distance cleanup are all shipped (`classes.md:287-290`); only gravity is new, and `combat_stats.md:249-252` already specifies it |
| **Snare Shot** | cast | 8 % base mana + 1 arrow | 12 s | The arrow slows the target by 50 % for 4 s | `grug_mobs.slow` for mobs and the player movement aggregator — the same two paths Hamstring uses (`kits.lua:421-430`) |
| **Sidestep** | cast | 10 % base mana | 30 s | Dodge chance **+15** percentage points for 4 s, **inside** the 30 % cap. A base ability has no ranks; the Veil tree shortens its cooldown (Slip Away) and replaces it (Shake Loose) | `grug_classes.get_crit_chance`'s twin `get_dodge_chance` (`grug_classes/stats.lua:128-140`) and the timed-window table of `skill_trees.md` §3.2 |
| **Sprint** ‼ | cast | 15 % base mana | **300 s** | Movement speed **+25 % for 10 s** — 5.0 nodes/s against the ordinary aggressive band's 4.6 | the speed aggregator of `skill_trees.md` §3.9, as one named modifier with its own duration |

**Sprint is a rule-breaker in the base kit, and it is the clearest example of
ruling 10** — "skills may explicitly break the base inequalities… the bigger
the break, the stronger the limit". It breaks the one inequality the whole mob
game rests on, so it carries the strongest limit in the design: ten seconds,
once every five minutes. The user's words: "a deliberate special, not an
every-fight button." The three decided files that state the opposite pillar
need one sentence each — `skill_trees.md` §7 task 1 carries that, and it is not
this lane's to write.

What is deliberately **not** in the base kit: a melee finisher (it is Veil's
keystone, `skill_trees.md` §2.8), a root (Quarry's keystone), and stealth of
any kind (§8).

## 3. The bow does not exist

Measured, not looked up. `mods/ENTITIES/grug_traders/stock.lua:428-435`
records a headless dump of all 1012 registered item names:

> "**THERE IS NO BOW.** Nothing in the 1012 is a bow, a stave, a bowstring or
> a quiver — the only archery items in the game are `grug_mobs:arrow`
> ("Bundle of Arrows", the skeleton archer's drop, whose own item comment
> already says 'there is no bow/quiver item yet') and the castle ARROWSLIT
> nodes, which are masonry."

The bowyer shelf therefore sells arrows, sticks and feathers
(`stock.lua:474-479`) and gets no bracket tab, "there is no ranged family in
`grug_gear` to reach".

What **is** decided and waiting:

- `items_crafting.md` §9 (`:2423-2445`) is a complete inactive substrate:
  bow family on the 1H weapon curve (8/13/19/24 damage at ilvl 12/27/42/57),
  **25 m range, 0.5 s charge**, partial charge scales linearly, enchant pool =
  melee weapons (attack speed → charge speed), one bow per material tier,
  material-named under §3.0.3. Arrows craft 20 per batch from 1 iron bar +
  4 sticks + 4 sharp feathers. **Producer: the Woodcarver.** Quiver =
  Leatherworker bag-slot item. Its closing line is the one this class
  answers: "No current or committed class consumes a bow baseline… until a
  class package explicitly adopts it."
- `combat_stats.md:249-252`: "Bows reuse the infrastructure later… a bow is
  drawn up to a maximum and releases a ballistic arrow whose initial impulse
  comes from draw time; gravity supplies the trajectory."
- The weapon ladder's shape is `tools/wp13/gen_weapon_ladder.py` and one
  sprite per family per material (`items_crafting.md:606-643`), so a bow
  family is **six new sprites and six new registrations**, not a new system.

The arrow entity already exists in another mod: `grug_mobs:arrow_entity`
(`skeleton_archer.lua:18`), used by the archer, the raider and both golems.
A player bow should **not** reuse it — mob arrows carry `stamp_arrow_damage`
(`skeleton_archer.lua:68`) and the mob level pipeline — but it is the working
reference for the entity shape.

## 4. Leather armour exists on paper only

`mods/ITEMS/grug_gear/init.lua:77-79`, in the generator's own words:

> "leather — the Leatherworker's six leather grades (§3.4). Registered
> **`false`** below (its only wearer, the Rogue, is Phase 2) but **NAMED**
> here, so the day it registers nothing is invented."

The six grades are `light / cured / heavy / scaled / sleek / nightscale`
(`init.lua:82-99`), one per material tier, in the same table as the metal and
cloth ladders. Flipping the line registers **24 items** (6 grades × 4 slots).
Everything downstream is then already true:

- `inventory_equipment.md:184-193`: armor class **cloth 1 < leather 2 <
  metal 3**; a class may wear its rank "and everything below", and leather
  already ships as "the **Warrior's** light avoidance set" — so a Scout at
  rank 2 wears leather and cloth, and the below-inclusive rule needs no change
  beyond the new class's rank.
- `professions.md:52`: the **Leatherworker** already owns the six grades and
  "later **quivers**"; `:93-94` already says "Phase 2's Rogue wants leather,
  which already has a maker". No profession is created; the Scout is the
  wearer the line was drawn for.
- `character_visuals.md:71-73`: two armour lines ship, cloth and metal, "and
  each has one overlay per slot: head, chest, legs, feet. **Leather borrows
  the cloth cut until its own art exists, because it has no wearer before the
  Rogue.**" So the Scout needs **no new overlay art to ship** — it needs the
  six leather tints on the cloth silhouette — and its own art is a later
  pass. This is the single largest saving in the whole class.
- `items_crafting.md` §10 P2 (`:2468-2473`) already parks the mirrored
  signature recipes "in Phase 2 when the Rogue makes top leather PvP-relevant".


### 4.1 The arrow's physics, and the licence question ruling 12 raises

Ruling 12 asks for **ballistic arrows** — gravity, an impulse from draw time —
while **Fireball stays straight**, "the trajectory is what makes the archer
hard". That split is already the decided design:
`combat_stats.md:249-252` gives the bow gravity and draw time,
`classes.md:280-286` gives Fireball "no homing, gravity or splash", and
`classes.md:287-290` says the shared collision foundation "must support later
arrows". So no decided sentence has to change for it; one projectile
registration gains a gravity term that `grug_projectiles` does not have today.

The coordinator names **VoxeLibre's `mcl_bows`** as a usable reference port
for that physics. Checked against this repo's own rule rather than taken on
trust — and the answer is **dual-licensing, not a disagreement**:

- `AGENTS.md:829-833`: "**Code: GPL-3.0-or-later**… Compatible code inputs:
  MIT, Apache-2.0, LGPL-2.1/3.0 (also '-only'), GPL-2.0-or-later, **GPL-3.0**.
  **Hard exclusion: GPL-2.0-only code.**"
- **VoxeLibre states both licences and says they are a choice.**
  `reference_projects/VoxeLibre/LEGAL.md:25-28`: a per-mod licence "counts as
  **dual-licensing**. You can choose which license applies to you: Either the
  license of VoxeLibre (GNU GPLv3) or the mod's license." With
  `reference_projects/VoxeLibre/mods/ITEMS/mcl_bows/README.txt`'s "Source
  code: LGPL 3.0", **mcl_bows is available under either LGPL-3.0 or GPL-3.0**,
  and both are on `AGENTS.md:832-833`'s permitted list. There is nothing for a
  porting lane to discover and nothing is blocked. (`items_crafting.md:2425-2426`
  records only the LGPL half, which is one of the two and therefore not
  wrong.)
- **Media is a separate question, and the number in our own docs is wrong.**
  `items_crafting.md:2425-2426` says "media CC BY-SA 4.0 + 2 attribution
  sounds". `mcl_bows/README.txt` actually lists **two CC0 sounds**
  (`mcl_bows_bow_shoot.ogg`, `mcl_bows_hit_other.ogg`) and **one CC BY 3.0**
  (`mcl_bows_hit_player.ogg`, tim.kahn); CC BY-SA 4.0 is the *texture*
  licence. So there is **one** attribution-requiring sound, not two, and it is
  **CC BY 3.0**. `items_crafting.md` is not this lane's file, but a
  `LICENSE-media.md` row copied from it would carry the wrong licence — which
  is exactly the failure `AGENTS.md:839-841` warns about ("verify the license
  **in the source repo** — ContentDB metadata can be wrong").
- `AGENTS.md:129` and `:146`: a vendored third party carries "upstream repo +
  commit + license + patch list", and **ad-hoc clones into a scratchpad are
  forbidden**.

*A note on reading these files.* `reference_projects/` holds **nine registered
submodules**, but a **worktree does not populate submodule contents** — they
are empty here and populated in the main checkout. The three VoxeLibre facts
above were read there by the independent review of 2026-09-16 at the pinned
commit `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`, and anyone can re-check
them from the main checkout at the paths given.

**Recommendation: port the physics, import nothing.** The ballistic part is a
velocity, a gravity constant and a lifetime guard on top of machinery this
game already owns; reading mcl_bows to get the draw-time curve right is
research, not a dependency, and it leaves the repo with no new vendored tree,
no new submodule and no new media rows. If the lane does end up vendoring,
`AGENTS.md:129`'s record and a `LICENSE-media.md` table are not optional.

## 5. What version 1 leaves out, and why

Ruling 12 in one table. Nothing here is rejected; it is sequenced.

| Left out | Ruling | Where it went |
|---|---|---|
| **Invisibility** | 12: "no invisibility in version 1" | §8, whole, with rulings 8's detection rules and the three blocking conflicts it carries. The Veil capstone is **Untouchable** instead (`skill_trees.md` §2.8) — a strong, time-limited dodge window built from a stat the game already rolls |
| **Poison** | 7 and 12 | nowhere. `classes.md:475-487`'s Phase-2 Rogue plan is retired in this lane's `classes.md` commit, so no work package owns a player poison stat any more |
| **Traps** | 12 | nowhere. Ruling 7 allowed them "if cheap"; ruling 12 removed the option, and they were the one idea in the class that needed a placed-entity lifecycle |
| **A third resource** | 14: the Scout uses mana | nowhere; §1 |
| **A quiver item** | not ruled — simply not needed for v1 | `professions.md:52` already assigns it to the Leatherworker "later"; arrows stack in the main inventory until then |
| **A dedicated leather overlay** | 12: "leather borrows the cloth cut" | `character_visuals.md:71-73` already says so; the art is a later pass |

What that leaves is a class made entirely of numbers, durations and flags on
machinery the game already runs — which is the point of ruling 12, and the
reason §7's lane count drops from five to three.

## 6. Conflicts with shipped systems

Version 1 only; the stealth conflicts are in §8. Each item carries a severity:
**blocks** (cannot ship as written until resolved), **needs a rule** (ships
once somebody decides who owns what), **cosmetic**.

### 6.1 Movement ownership — **was blocking, resolved by ruling 11**

`mods/ENTITIES/grug_mobs/verbs.lua:100-118` states the problem in its own
comment: independent owners of `physics_override.speed`, each name-keyed, each
restoring to `speed = 1` when its own effect ends, "so an overlapping mob web
+ player snare can end early (the first restore lifts both)… **the fix is one
shared owner in `grug_core`**". That comment counts **two** — mob webs
(`verbs.lua:140-169`) and the ability movement aggregator seam
(`kits.lua:149-201`) — and
`mounts.md:128-133` and `boats.md:113-117` both repeat the count. **Measured,
there are three**: `grug_classes/selection.lua:52` freezes a player during
character creation with `{speed = 0, jump = 0, gravity = 0}`, re-asserts it
whenever it drifts (`:49-53`), and restores a **snapshot** at `:91` — which
would write a running slow back permanently. `skill_trees.md` §3.9 lists all
three and sizes the migration.

Sprint and Snare Shot would have been a fourth and fifth writer.
**Ruling 11 decides the fix** — one central aggregator in `grug_core`, named
modifiers with independent durations, roots as a hard flag, mounts outside it
— covering **speed and jump**, because the shipped roots set both
(`kits.lua:589` is `{speed = 0.1, jump = 0.3}`). It is **not** the Scout's to
build: `docs/research/mob-pressure-task-card.md` §4b carries it, because a mob
that must keep moving while its attack clock runs is the other consumer. The
Scout's former "speed and stealth" lane collapses into the class lane once it
exists.

### 6.2 Sprint breaks a decided pillar, deliberately — **needs a rule**

`mounts.md:173-190` states it outright: ordinary aggressive mobs run **4.6** against a
player's **4.0** (`combat_stats.md:310-315`), and the 25 m soft de-aggro, the
45 m chase give-up and the 40 m leash "all assume the mob can close the
distance". It is why the Swiftness Draught is capped at **+8 % for 15 s**
(`items_crafting.md` §10 P4: `4.0 × 1.08 = 4.32 < 4.6`) and why any damage
dismounts a rider.

At +25 % a sprinting Scout runs 5.0 and outruns every aggressive mob for ten
seconds. **Ruling 10 permits exactly this** — the break is the point, the
five-minute cooldown is the price. What is still open is the paperwork:
`mounts.md` §3.1 and `combat_stats.md` §3 have to say that the inequality
holds *except* for named, long-cooldown skills, or the next reader files
Sprint as a bug. Neither file is this lane's; `skill_trees.md` §7 task 1
carries it, and the exact numbers are ruling 29: **+25 % for 10 s on a 300 s cooldown**.

### 6.3 Faster mobs versus the Mage's kiting fantasy — **needs a rule**

`classes.md:439-441`: "Frost Nova became the rotation pivot — **kiting IS the
Mage fantasy here**." Kiting is a function of the same one inequality. The
mob-pressure task card proposes making mobs "a bit faster"; every 0.1 the mob
gains, the Mage's Frost Nova window loses, and the 25 m soft de-aggro
(`combat_stats.md:328-330`) becomes harder to reach in the same proportion.
The Scout's Sprint pushes from the other side, with a cooldown long enough
that it cannot be the answer to an ordinary fight. **Rule needed before any
mob speed changes**: the root duration, the soft-de-aggro distance and the mob
speed are one system and cannot be tuned separately.

### 6.4 Caps versus timed windows — **resolved by ruling 10, with a doc amendment**

`combat_stats.md:104-108`: "The caps remain 30 % Crit, 30 % Dodge and 60 %
armor. Values above a cap remain present on their stacks but have no further
combat effect… There is **no automatic overflow conversion or cap raise**."
The Scout's base-kit Sidestep stays inside the 30 % dodge cap and is simply
clamped — which means a Scout with good gear gets *less* from their own
button, a real consequence and not a bug. The Veil capstone **Untouchable**
does raise the cap, to 50-60 % for six seconds once every three minutes, which
is what ruling 10 permits for a capstone. `combat_stats.md` §2 needs the one
paragraph `skill_trees.md` §2.10 describes, and the Talents header has to show
the raised cap while it runs (`:104-108` already requires effective **and**
raw).

### 6.5 The bow has no wield pose and no starter — **needs a rule**

`grug_visuals/apply.lua:82-87` maps an item to one of **three** wield poses,
and the tables live in `wield_geometry.lua` — a bow is a fourth silhouette,
held across the body rather than hilt-in-fist. Separately,
`inventory_equipment.md:84-85` grants "a **Warrior** the stone sword, a
**Priest** and a **Mage** the wooden staff" at class choice, and there is no
below-ladder bow the way `grug_gear:staff_wood` was created for casters
(`items_crafting.md:639-643`). Both are small and both have to be decided by
the lane that registers the bow family, not discovered by it.

### 6.6 Claims, protection and nametags — **no conflict**

Nothing in the claim/protection system reads a class or a speed
(`housing.md` §2, `economy.md` §4.1), and player nametags already use the
25 m / 30 m proximity gate (`combat_stats.md` §6). Recorded because they
are the first things a reviewer asks about, and because both *would* have been
conflicts if version 1 had stealth (§8).

## 7. Scope: what the Scout costs

### 7.1 Dependencies and side effects on other work packages

| Area | What the Scout needs | Evidence |
|---|---|---|
| **WP11 (skill trees)** | the whole talent machinery first. The Scout's 16 talents are data on top of X1-X4 | `skill_trees.md` §4 |
| **The speed aggregator** | ruling 11's `grug_core` aggregator, **owned by the mob-pressure lane**, before Sprint or Snare Shot | `skill_trees.md` §3.9; `docs/research/mob-pressure-task-card.md` |
| **Weapon ladder §3.0.3** | a **bow family**: six registrations, six sprites through the existing `tools/wp13/gen_weapon_ladder.py`, one bracket tab for the bowyer, a below-ladder starter bow, and the fourth wield pose of §6.5 | `items_crafting.md:606-643`, `:2428-2432`; `grug_visuals/apply.lua:82-87` |
| **Arrows** | a player arrow item and a **ballistic** entity on `grug_projectiles`; the craft (1 iron bar + 4 sticks + 4 sharp feathers → 20) exists on paper; the physics reference and its licence are §4.1 | `items_crafting.md:2433-2436`; reference entity `skeleton_archer.lua:18` |
| **Leather armour** | flip `grug_gear`'s leather line from `false` to registered: **24 items** and 24 icons, on the **borrowed cloth cut** — no new overlay art | `grug_gear/init.lua:77-99`; `character_visuals.md:71-73` |
| **Professions** | none created. The **Leatherworker** already owns the grades and the future quiver; the **Woodcarver** already owns the bow | `professions.md:52`, `:93-94`, `:192-195`; `items_crafting.md:2437-2441` |
| **Traders** | the bowyer shelf gains its bracket tab (it explicitly has none today); the tanner shelf gains the leather grades | `grug_traders/stock.lua:428-435`, `:472-479` |
| **Character visuals** | the six leather tints on the cloth silhouette, and the bow pose | `character_visuals.md:71-73` |
| **`combat_stats.md`** | one sentence for the ranged damage term of ruling 28, and the cap-override paragraph WP11 already owes | beside `grug_classes.get_melee_bonus` at `grug_classes/stats.lua:107-115` |
| **PvP (WP41)** | nothing in version 1. Sprint and Sidestep are ordinary buffs under the existing tag rules | `combat_stats.md:270-289` |
| **`grug_visuals`, `grug_mobs` AI, nametags** | **nothing** — every one of those was an invisibility dependency (§8) | — |

### 7.2 The lane cut

Ruling 12 collapses the previous five lanes to **three**, plus the design lane
that is already done, because the two most entangled pieces are gone: the
stealth lane disappears with invisibility, and the `grug_core` speed work
moves to the mob-pressure lane that needs it anyway.

| Lane | Scope | Depends on | Size |
|---|---|---|---|
| **S0 — design** | this file and `skill_trees.md` §2.7/§2.8 | — | **done** |
| **S1 — bow and arrows** | the bow family (6 registrations + 6 sprites through the existing generator + the bracket tab), the below-ladder starter bow, the fourth wield pose, the player arrow item and its **ballistic** entity on `grug_projectiles`, the draw-time charge on the shipped charge-bar machinery (`classes.md` §2b), the Woodcarver recipes and the bowyer shelf | — | **L** |
| **S2 — leather and the tanner line** | flip `grug_gear`'s leather ladder (24 items, 24 icons), the six tints on the borrowed cloth cut, armor class 2 for the new rank, the Leatherworker recipes and the tanner shelf | — | **M-L** |
| **S3 — the class and its trees** | `grug_classes` registration (attributes, growth, colour), the four base abilities of §2, the class-selection entry, the starter grant, the ranged damage term of ruling 28, **and** the 16 talents of `skill_trees.md` §2.7/§2.8 — 10 numeric consumers, **2 new-skill keystones** (Pinning Shot, Opening), **3 replacements** (Twin Shot, Shake Loose and the capstone Longshot) and **1 capstone effect** (Untouchable) — plus the KAT rows | S1, S2, WP11 X1-X4, the aggregator | **L** |

### 7.3 My estimate, and what changed

The coordinator's first estimate was "one wave of four lanes plus a design
lane". My previous estimate was **five plus design**, and the extra one was
the stealth/speed lane. **Ruling 12 removes it and ruling 11 re-homes its
`grug_core` half**, so my estimate is now **three implementation lanes plus
the design lane** — one fewer than the original four, for a class that does
more than the original sketch did.

What that rests on, measured rather than assumed:

- **S1 and S2 are each a genuine lane.** S2 alone registers 24 items with 24
  icons and touches the armor-class rule; it is cheaper than it looks only
  because `character_visuals.md:71-73` already lets leather borrow the cloth
  cut, which is the single largest saving in the class.
- **S3 absorbs what used to be two lanes** (the class and its trees) because
  ruling 13 leaves the Scout with just **two** new ability registrations
  across both trees, and everything else is a read inside an ability that S3
  itself wrote.
- **The wave is still not self-contained.** S3 cannot start before WP11's
  X1-X4 and the aggregator; S1 and S2 are independent of everything and could
  be pulled forward into any earlier wave as pure item work.
- **Nothing in version 1 touches `grug_visuals`, the mobs AI or PvP.** That is
  ruling 12's whole return: the three conflicts marked **blocks** in the
  previous revision were all stealth's, and all three are now in §8.

A realistic sequencing: **WP11 (four lanes) + the aggregator → S1 ∥ S2 → S3.**

## 8. Deferred: stealth v2

**Nothing in this chapter is part of version 1.** Ruling 12 removed
invisibility from the Scout's first release; rulings 8's stealth rules and the
research behind them are kept here **verbatim and complete**, so that the day
the user wants stealth the design, the seam, the detection arithmetic and the
three blocking conflicts are already written. The Veil capstone in version 1
is **Untouchable** (`skill_trees.md` §2.8), not invisibility.

The numbers below were an open decision of an earlier revision of
`skill_trees.md`; with stealth deferred they are simply undecided and
unscheduled, and §6 of that file no longer carries them.

### 8.1 The rulings and the mechanism

#### 8.1.1 The rules, verbatim

> Invisibility (melee-tree capstone): combat **BREAKS** it (dealing or taking
> damage, casting a hostile ability); there is a **DETECTION chance** even
> while invisible when very close to a mob; mobs (and guards) of a **HIGHER
> level** than the player have a markedly higher detection chance — "no
> level-40 player sneaks past a level-60 mob or guard"; invisibility
> **SIGNIFICANTLY reduces movement speed**.

#### 8.1.2 The seam that already exists

Vendored mobs_redo carries a complete invisibility hook that **nothing
feeds**:

```lua
-- mods/ENTITIES/mobs/api.lua:1259-1265
local function is_invisible(self, player_name)
    if use_invisibility and not self.ignore_invisibility
    and invisibility.is_visible and not invisibility.is_visible(player_name) then
        return true
    end
end
```

`use_invisibility` is `core.get_modpath("invisibility")` (`mods/ENTITIES/mobs/api.lua:9`) and
**no mod of that name exists in this game** (`find mods -maxdepth 2 -iname
'*invisib*'` finds no mod directory; the only match anywhere in `mods/` is the
texture `default_invisible_node_overlay.png`), so `use_invisibility` is `nil`
and the whole path is dead today. It is consumed at **six** sites, and those
six are exactly the AI behaviour ruling 8 describes:

| Site in `mods/ENTITIES/mobs/api.lua` | What it does |
|---|---|
| `api.lua:1874-1882` | target acquisition skips an invisible player |
| `api.lua:1966` | a second acquisition path skips them |
| `api.lua:2065` | a player-scan path skips them |
| `api.lua:2341-2348` | a mob **stops attacking** when its target turns invisible |
| `api.lua:3511-3515` | a punch from an invisible attacker does not set aggro |
| `api.lua:1273-1275` | `follow_holding` ignores an invisible player |

There is a seventh entry point that is not behaviour: `mobs:is_invisible`
(`api.lua:1267-1268`) is a public wrapper around the same local, and it is
what an `invisibility` mod's own KAT would call.

Per-mob opt-out already exists: `ignore_invisibility` is read from the def at
`api.lua:4085`, so an individual family — a named rare, a boss, a royal guard
— can be made immune without a patch.

**So the AI half is free.** Shipping a small `invisibility` mod that publishes
`invisibility.is_visible(name)` turns all six sites on at once, with **no
GRUG PATCH** added to the 62 that already live in `api.lua`.

#### 8.1.3 What is NOT free: the player is still drawn

The mobs_redo hook is AI-only. It does not hide anything on screen. Making the
Scout actually invisible is a second, separate job and it collides with
`grug_visuals` — see §6.

#### 8.1.4 The detection roll (proposed)

In the vocabulary the rest of the game uses:

- **Bands by distance** between mob and Scout:
  - `d ≤ 3 m` — **always detected**. "Very close" is not a roll; walking into
    a mob's face ends the trick.
  - `3 m < d ≤ 8 m` — **rolled**, once per tick.
  - `d > 8 m` — never detected by this roll, and **never further than the mob
    can see**: the outer edge is `min(8, view_range)`, not a flat 8. That
    qualifier is load-bearing rather than tidy. Measured on this tree, 8 m is
    *not* below the shipped floor: the crocodile is `view_range = 6`
    (`crocodile.lua:61`) and eight critters are exactly 8 (`cave_bat.lua:43`,
    `bone_weevil.lua:46`, `cave_crawler.lua:33`, `carrion_crow.lua:56`,
    `parrot.lua:44`, `gull.lua:46`, `rabbit.lua:46`, `bog_fowl.lua:32`);
    everything else is 10-16. A flat 8 would let a crocodile detect a Scout
    two metres beyond its own eyesight.
- **Chance per tick** inside the band:
  `p = 0.10 + 0.05 × max(0, mob_level − scout_level)`, clamped to 1.0.
  - equal level: 10 % per second;
  - the ruling's case, a level-40 Scout against a level-60 mob or guard:
    `0.10 + 0.05 × 20 = 1.10 → 1.0`, i.e. **detected on the first tick inside
    8 m**. That is what "no level-40 player sneaks past a level-60 mob or
    guard" has to mean numerically, and it is why the per-level term is the
    one number to keep even if the others move.
  - a level-60 Scout against a level-40 mob: 10 %, no bonus below.
- **Tick: 1 Hz, on the mob's own step**, not a new globalstep. The mob level
  is already on the entity (`_grug_level`, `grug_mobs/levels.lua`) and
  `grug_core.mob_level_at` exists, so the term costs one subtraction.
- **On detection** the Scout's invisibility ends immediately (the same path as
  the combat break), the mob acquires normally, and the capstone goes on
  cooldown — there is no "detected but still hidden" state to reason about.
- **Break conditions** (ruling 8): dealing damage, taking damage, or casting
  any hostile ability. The seams are the ones already central: the outgoing
  side at `grug_core.deal_ability_damage` (`combat.lua:1021-1074`)
  threat) and the authoritative swing, the incoming side at the central
  hp-change modifier, and the cast side at `grug_abilities/init.lua:1508-1583`
  (the one `spend` call) filtered to hostile kinds.
- **Movement penalty**: ×0.6 speed (4.0 → 2.4 nodes/s) while invisible — "a
  significant reduction", and it also means a Scout can never use stealth to
  outrun anything.

#### 8.1.5 Guards

`grug_mobs/guard.lua` guards are ordinary `grug_mobs.register_mob` entities
with `attack_type = "dogfight"` (`:181`), `view_range = 14` (`:205`) and a
level from the separate `guard_level_at` field — **~36 at the war coast, ~47
in the inner ring, 60+ in the safe core** (`guard.lua:22-25`, quoted
exactly), and a guard at
level ≥ 60 promotes itself to elite (`:91`). They therefore take part in the
detection roll through exactly the same `is_invisible` sites, and the level
term does the work the ruling asks for: a capital's level-60 royal guard
detects any Scout below level 60 on the first tick inside 8 m.

The camp's designated patroller carries `_grug_patrol_route` and ambles
between outposts (`guard.lua:32-34`, `patrol.lua`); a patrolling guard is a
*moving* 8 m band, which is the interesting case for a stealth route and needs
no extra code.

**Open, and named rather than assumed:** whether a capital's hard-protection
volume should make stealth impossible outright (an `ignore_invisibility = true`
on the royal guard def, one field, `api.lua:4085`) or leave it to the level
term. Recommendation: set the field on royal guards, because a throne room is
exactly the place a 100 % roll should not be a roll at all.


### 8.2 The conflicts stealth carries, and version 1 does not

These four were the reason the previous revision's Scout wave needed a fifth
lane, and three of them were marked **blocks**. None of them applies to
version 1, because nothing in version 1 hides a player.

#### 8.2.1 `grug_visuals` owns the player's textures and re-asserts them — **blocks**

`mods/PLAYER/grug_visuals/apply.lua:269-300` is the only writer of the player
model's appearance: it composes a texture list and hands it to
`player_api.set_textures` (`:283`) behind a change token (`entry.key`), and
writes `visual_size` unconditionally (`:296`). It re-runs on join (`:333`),
respawn (`:349`), race choice (`:355`), class choice (`:359`) and **every
equipment change** (`:373`).

An invisibility implementation that writes the player's textures or
`visual_size` itself would be (a) overwritten by the next equipment change,
and (b) worse, would leave `entry.key` stale, so `apply()` would believe
nothing had changed and never restore the visible skin. **Invisibility has to
go through `grug_visuals` as a composition input**, not around it — a
`hidden` flag in `player_spec` (`apply.lua:213`) that `compose` answers with a
fully transparent texture list. That is a `grug_visuals` change and it is not
in `grug_classes`' dependency direction.

#### 8.2.2 The attached weapon entity would keep floating — **blocks**

The third-person weapon is a **separate entity** attached to the player's
right-hand bone: `core.add_entity(pos, WIELD_ENTITY)` then
`obj:set_attach(parent, WIELD_BONE, …)` (`apply.lua:95-101`), with
`visual = "wielditem"` (`:55`). Attached entities are drawn independently of
their parent's textures, so hiding the player leaves a sword hovering in
mid-air at shoulder height — which is *worse* than no invisibility at all,
because it is a precise position marker.

Worse, a 1 s globalstep poll re-syncs the wield entity for every connected
player (`apply.lua:314-331`), so a one-time removal is undone within a second.
The stealth lane must reach `sync_wield` (`:117-169`) with the same `hidden`
flag. Armour is not affected: armour is drawn as texture overlays on the
player model (`character_visuals.md:19-21`), so it disappears with the skin.

#### 8.2.3 Player nametags — **needs the stealth state**

Player nametags use the per-viewer **25 m visible / 30 m hidden** carrier gate
(`combat_stats.md` §6; adopted 2026-09-18). Stealth must exclude every viewer
from that carrier even inside 25 m and return control to the distance gate when
stealth ends; otherwise the floating name reveals the hidden player's exact
position to nearby players.

#### 8.2.4 The non-combatant veto and `_grug_ignore_player` share the target loop — **needs a rule**

`mods/ENTITIES/mobs/api.lua:1874-1882` and `:1903-1917` hold two GRUG PATCH
vetoes in the same
target-selection loop that `is_invisible` sits in (`:1874-1877`): the per-entity
`_grug_ignore_player` hook (the undead night truce) and the per-target
`_grug_noncombatant` flag (`grug_mobs.noncombatant`, `verbs.lua:724-746`).
Adding a *third* filter to that loop is cheap — it is already the shape — but
the **order matters for `continue` semantics**: the loop removes a vetoed
candidate so the mob picks another instead of re-acquiring forever
(`api.lua:1882`, `:1916`). Invisibility must be filtered in the same
place
and the same way, not short-circuited earlier. One rule, written down, and the
KAT case that proves a vetoed candidate is removed rather than skipped.

#### 8.2.5 PvP: invisibility has no rule at all — **needs a rule**

`combat_stats.md:270-289` and `world_zones.md` §4/§15 define PvP eligibility
and the tag: a voluntary hostile action tags its user before eligibility
resolution, and the tag clears 60 s after the last qualifying damage. The
mobs_redo hook is a *mob* system; it says nothing about players seeing each
other. Two questions no decided file answers:

1. Is a stealthed Scout invisible to **enemy players**? If yes, the same
   `grug_visuals` composition path hides them from everybody — there is no
   per-observer texture in Luanti without one entity per viewer — so it also
   hides them from their **own faction**, which is a PvP and a group-play
   decision, not a rendering detail.
2. Does entering stealth **tag** the Scout? Under `combat_stats.md:274-275` a
   voluntary hostile action tags; stealth is not damage, but stealthing into a
   contested zone to reach an enemy is plainly a hostile act.

Recommendation: invisibility hides the Scout from **mobs only** in the first
version (the free half, §8.1.2), and player-vs-player stealth is deferred to
WP41 with the rest of PvP. That keeps 6.2 and 6.3 out of the critical path
too, since nothing needs to be hidden on screen if only the AI is fooled —
though a Scout who is invisible to mobs while fully visible to the player
reads as a bug and needs a visible status entry at minimum. The shipped
first-pass presentation is the text list; WP10 later replaces it with icons
(`inventory_equipment.md` §5).

#### 8.2.6 Claims and protection — **cosmetic**

Nothing in the claim/protection system reads visibility; claim protection is
positional and owner-based (`housing.md` §2, `economy.md` §4.1). A stealthed
player can already stand anywhere a visible one can. No conflict found; named
because the coordinator asked.

#### 8.2.7 The elite/rare telegraph and the weapon-ready reticle — **needs a rule**

`combat_stats.md:331-348`: elites and rares telegraph with a 2 s wind-up, a
`!!` nametag prefix and a 90° frontal cone of `reach + 1.5 m`, and "the first
wind-up needs **4 s of MELEE engagement**". A mob whose target vanishes
mid-wind-up is an undefined state today: `api.lua:2341-2348` drops the target when
it becomes invisible, but the telegraph is `grug_mobs/telegraph.lua`'s own
timer. Rule needed: **a lost target cancels the wind-up** (and the `!!`
prefix), or a rare fires a ×3 cone into empty air.

The weapon-ready reticle (`combat_stats.md:174-179`) is client-side and shows
only weapon readiness, so it is unaffected — but the **aim-miss rule** is:
`combat_stats.md:154-161` says an aim miss brings "no damage/rage/threat/cost/
charge/effect and, crucially, no clock advance", and a
Scout who vanishes under an enemy's crosshair in PvP produces exactly that.
Behaviour is already defined and correct; recorded so nobody re-derives it.
