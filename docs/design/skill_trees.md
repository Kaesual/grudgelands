# Skill Trees (Talents) — WP11

**DECIDED, revision 2 (2026-09-16).** Revision 1 (2026-09-16)
built two trees of five talents per class on a 20-point budget. The user's
rulings of **2026-09-16** (§5) replace the budget, the tree size, the tier
shape, the capstone rule and the respec seam, and add a fourth class. This
revision rebuilds the decided design on those rulings.

**Status, 2026-09-20: lanes X1–X4 of §4 are implemented.** X1/X2
(round 4, lane W1) shipped `mods/PLAYER/grug_classes/talents.lua` with the 48 talents of the three
shipped classes, the point budget, both gate kinds, the spend/respec rules,
the validating persistence path, the window table and the two accessors, plus
the thirty numeric consumers of §3.8 and the code halves of rulings 19, 20 and
25 and of §7 task 5. X4 adds the sfinv page, paid/free-first respec transaction
and level-up notice; `/talents` remains read-only and the interim `/talent` and
`/respec` commands are gone. WP44 has not published measured income yet, so
X4's six prices remain the explicitly named coordinator placeholder in
`talents_ui.lua`, not accepted measured values. Round 12 completes X3's
original-class abilities, replacements and capstone consumers, including named
absorb contributions and accepted-action settlement. Round 11's Scout trees,
Ironbound and Unbroken are preserved under their decided caps. The X1/X2 record:
`docs/research/wp11-talents-phase1.md`.

Companion files written with this revision:

- [scout.md](scout.md) — the fourth class (Scout): kit, armour, bow, the
  conflicts its stealth and sprint have with shipped systems, and the lane
  cut. Its two trees live here in §2.7/§2.8 so that all four classes' talent
  tables stay in one place under one arithmetic.
- `docs/research/mob-pressure-task-card.md` — the melee-pressure and
  ranged-mob task card of the same session. Not part of WP11; it is named
  here because the Scout's kiting and stealth read on top of it.

The decided frame this design must fit is quoted where it binds. Where a
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
- `economy.md` §4 and `items_crafting.md` §8.3 now implement ruling 4's
  decided location: respec is performed in the talent UI, with no class
  trainer or NPC. The older trainer sentence survives only in labelled
  supersession history.
- `AGENTS.md` requires `docs/design/` to contain decided rules only. Section 6
  is therefore a closed decision record; it contains no current open question.
- `AGENTS.md:844`: "Never copy WoW assets/names 1:1 — Blizzard IP. Own
  assets, own names with a recognizable character." Ruling 5 makes this
  binding for every talent name; §2.11 is the audit.

Everything this design says about the code is a `file:line` citation into
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

Four classes ship; the fourth,
**Scout**, was delivered in Round 11 (ruling 7,
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
and ruling 27 settles them.

Two sites in the repo still call the Priest healing tree "the **Holy** tree",
one of them a code comment: `classes.md:464` and
`mods/PLAYER/grug_abilities/kits.lua:650`. (Revision 1 counted three; the
third was `progression.md`'s "Priest Holy capstone", which **this lane's own
`progression.md` commit already removed** — `grep -n Holy
docs/design/progression.md` now returns nothing.) **Mercy** is the same tree
renamed; the rename has to reach the two that are left — §7, task 5.

### 1.2 Tiers, gates and hard chains

Both dependency kinds ruling 2 asks for are used:

- A **tier gate** is points already spent *in that tree* (not in that tier).
- A **hard chain** is "all ranks in the talent above it, in the same chain".

| Tier | Contents | Tier gate (points in this tree) | Hard chain |
|---|---|---|---|
| 1 | one entry talent per chain, **5 ranks** | 0 | — |
| 2 | one talent per chain, **4 ranks** | 5 | tier-1 talent of the same chain at 5/5 |
| 3 | one **keystone** per chain, **3 ranks** | 12 | tier-2 talent of the same chain at 4/4 |
| 4 | the **capstone** on its chain (**1 rank**), a finisher on the other (**3 ranks**) | 20 | tier-3 talent of the same chain at 3/3 |

Rank counts vary by talent strength exactly as ruling 2 asks: **5 / 4 / 3** down
a chain, and the capstone is **one rank**. That last number is **ruling 17**, decided:
a capstone is one strong effect or one replacement, and what gates it is its
chain plus the points in the tree, not a ladder of its own — the variety
ruling 2 asks for is already carried by the 5/4/3 above it.

Per tree that is **8 talents and 13 + 15 = 28 ranks**; per class **16 talents
and 56 ranks**. Twenty-eight is ruling 2's "about 30", and it means a player
who fills one tree completely still has **2 points** to place elsewhere.

The two gate kinds interact deliberately:

- The tier-2 gate (5) is exactly the cost of maxing a tier-1 talent, so a
  player who commits to one chain opens tier 2 at the moment the hard chain
  lets them through it. No dead point.
- The tier-3 gate (12) is **three more than a single chain costs**
  (5 + 4 = 9), so a keystone cannot be rushed on one chain alone: three
  points have to go into the tree's other direction first. That is what makes
  a tree read as a tree rather than as two unrelated ladders.
- The tier-4 gate (20) is **eight more than a chain's first three talents**
  (5 + 4 + 3 = 12), so a capstone needs most of the other chain as well —
  and that is what makes ruling 18's "one capstone per character" true by
  arithmetic rather than by a rule. §1.3 works it out.

### 1.3 Points, and the arithmetic (rulings 1, 2, 17 and 18)

- **One point every two levels, the first at level 2**: levels 2, 4, 6, …, 60.
  The point count at level L is `floor(L / 2)`; at level 60 that is
  **30 points**.
- **Ranks per tree: 28** (13 on the capstone's chain, 15 on the other).
  **Ranks per class: 56.**
- **A full tree costs 28 of the 30 points**, so a "pure" build finishes its
  tree at level 56 and still has two points to place. A full tree is never
  forced: every split is legal.
- Ruling 1's "two thirds was a rough guideline, slight deviation is fine" is
  what this uses: the fraction is now half the class, or one tree of two.

Worked reachability, per tree, counting points **in that tree**:

| Milestone | Cost in the tree | Total points | Character level |
|---|---|---|---|
| tier-1 talent maxed (5/5) | 5 | 5 | 10 |
| tier-2 talent maxed (4/4) | 9 | 9 | 18 |
| **first keystone**, rank 1 | 9 on the chain + 3 in the other chain (gate 12) + 1 | 13 | **26** |
| first keystone maxed (3/3) | 15 | 15 | 30 |
| **second keystone**, rank 1 (same tree) | both chains through tier 2 (18) + 1 + 1 | 20 | **40** |
| **the capstone** (its only rank) | its chain to 12 + 8 elsewhere in the tree (gate 20) + 1 | **21** | **42** |
| **the whole tree** | 28 | 28 | **56** |

#### One capstone per character, by arithmetic (ruling 18)

The user's ruling is that a level-60 character holds **exactly one** capstone,
and that this must follow **implicitly from the tree's requirements** rather
than from a rule that says so. It does, and these are the numbers:

- **A capstone costs 21 points in its tree.** Its chain must be complete
  through the keystone (`5 + 4 + 3 = 12`), the tier-4 gate needs 20 points in
  the tree, so 8 must go into the other chain (`5 + 3`), and the capstone
  itself is the 21st. There is no cheaper order: the hard chain fixes the 12
  and the gate fixes the 20.
- **21 of 30 is 70 % of everything the game hands out** — comfortably more
  than the half ruling 18 asks for.
- **Two capstones are impossible**: `21 + 21 = 42 > 30`. Not discouraged —
  arithmetically out of reach, with 12 points missing.
- **The first capstone lands at level 42**, inside ruling 18's 40-44 target.
  Level 40 would need a 20-point capstone and level 44 a 22-point one, so the
  gate has one point of slack in either direction if playtesting wants it.
- The remaining **9 points** go wherever the player likes: the second tree's
  first chain through its keystone (13 is out of reach, but 9 buys a maxed
  tier-1 and a maxed tier-2), or depth at home.

What the common splits buy:

| Split | What it reaches |
|---|---|
| **28 / 2** (pure) | both keystones, the capstone and every rank of one tree — **one** new button, one replaced button, the capstone, and 2 points parked |
| **21 / 9** | the capstone plus one maxed keystone; the second tree gets a maxed tier-1 and tier-2 pair but no keystone |
| **20 / 10** | **both** keystones of the prioritised tree at rank 1 (both chains through tier 2 = 18, then one point in each) — **no capstone**, one point short |
| **15 / 15** | one chain through its keystone in **each** tree — up to **two** new buttons, one per tree, and no capstone |
| **13 / 13** (+4 spare) | one keystone in each tree at rank 1, four points free — the cheapest route to both new buttons, at level 52 |

The 20/10 row is the interesting one: a player who wants *both* of a tree's
keystones spends exactly the 20 that opens tier 4 and then has nothing left
for the capstone in that tree. Breadth and the capstone are a real choice, and
the point that decides it is the 21st.

**No build can hold more than two new hotbar buttons.** Ruling 13 puts at most
one new-skill keystone in each tree, so the ceiling is one per tree and both
are reachable at 13 + 13 = 26 points — **both new buttons by level 52, with 4
spare**. Every other keystone and every capstone changes a button the player
already has, or no button at all. §3.4 works the budget out per class; with
ruling 19's Warrior change the worst case is now **6 of 8**.

XP loss is 25% of the current level's whole XP span and never de-levels
(`combat_stats.md` §3; `mods/PLAYER/grug_xp/init.lua:86-104` clamps the fixed
loss to the level floor), so a point is never taken back by dying.

### 1.4 Respec, and the class change that no longer exists (rulings 4, 20, 22)

- **Where: in the talent UI itself. There is no class trainer and no NPC.**
  Ruling 4 is explicit. This supersedes the location half of `progression.md`
  §2 and `economy.md` §4. Those living sections and `world.md` now state the
  no-trainer rule; `docs/research/wp13-npc-sockets-contract.md` §8.4 never
  needs a `trainer` vendor kind.
- **What: a full reset.** Ruling 20 — a respec sets every rank to 0 and
  returns all 30 points. No partial or single-tree respec: one button, one
  price, nothing to argue about over which half was refunded.
- **Price (ruling 22, decided):** **five minutes of measured reliable net solo
  income at the character's own bracket**, rounded by `economy.md` §4.1's rule
  (the coarsest denomination in `1s / 25c / 5c / 1c` whose nearest multiple
  stays within 5 % of the target, exact midpoints upward), **and the first
  respec of a character is free**. Because bracket income rises on the same
  approximate ×2.5 tier index as everything else (`economy.md` §3), the price
  "rises with level" without a hand-written table, and WP44 calibrates the six
  numbers with every other measured sink. The free first respec is the safety
  net for a mis-clicked first point at level 2, when the character has no
  money at all. (Main's 5.7 said "level 3" — the level the *old* cadence gave
  the first point; ruling 1 moved it to 2 and the sentence follows it.)
  **This retires `BACKLOG.md`'s "5c × level, min 25c"** (`:542-550`), the only
  other respec number in the repo; `grug_money.take`
  (`mods/PLAYER/grug_money/init.lua:122`) is still the API it calls. Until
  WP44 publishes the six measured values, the implementation keeps an
  explicitly named coordinator-placeholder table at the transaction seam;
  it is not an alternative price rule and must be replaced by WP44's outputs.
- **There is no class change at all any more (ruling 20).** Not for players,
  and **not for admins**: "equipment would be a problem otherwise". The
  shipped `/class` registration (`grug_classes/selection.lua:594-595` — one
  call to the generic helper above it, not the helper) is removed with WP11,
  not merely left admin-only, and §3.10 lists what that touches.
  A respec re-spends talents; nothing in the game changes a character's class.
- **An admin level drop resets talents completely and for free** (ruling 20's
  simplest form). `/xp` can lower a level (`grug_xp/init.lua:142-162`), which
  could otherwise leave more ranks spent than `floor(level / 2)` allows;
  rather than blocking spends or refunding cheapest-first, the talent state is
  wiped and every point returned. `/xp` is an admin command, so the simplest
  correct behaviour wins.

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
  armor rating, crit chance, dodge chance, max HP, max mana, rage, spell
  power, threat, absorb, root and slow duration. **No talent introduces a new
  mitigation term**, and no talent introduces a new *mechanic*: every one is
  a number, a duration or a flag on machinery the game already runs.
- **Modifies** names the shipped line the rank changes. **A kit table's
  `cooldown`, `charge`, `range` and `max_distance` fields are evaluated once
  at load time with no player in scope**, so talents that re-tune those hook
  the central per-player site instead — §3.2 lists the four of them.
- **Key** is the effect key of the data model in §3.2.

### 2.1 Warrior — Bulwark

Round 11 implements only the armor-rating portion of lane X3 needed by
Ironbound and Unbroken. That targeted slice does not authorize the other X3
keystones, replacements or capstones; their existing package dependencies and
review gates remain unchanged.

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|---|
| 1 | **Ironbound** | Wall | 1 | 5 | — | +1 / 2 / 3 / 4 / 5 armor rating | armor-rating aggregate | `armor_rating_add` |
| 2 | **Weathered** | Wall | 2 | 4 | — | max HP +1.5 / 3 / 4.5 / 6% of the class base pool | `grug_classes/stats.lua` | `max_hp_percent_add` |
| 3 | **Hold Ground** *(keystone)* | Wall | 3 | 3 | **new skill** ‼ | cast, 25 rage, self; absorbs 20% / 30% / 40% of the class-neutral base pool for 8 s, **and for those 8 s the Warrior cannot be rooted or slowed**. *Limit: 8 s, **60 s cooldown**.* | new; `grug_core.add_absorb`; the immunity is a flag the speed aggregator of §3.9 already has to read | — |
| 4 | **Unbroken** *(capstone)* | Wall | 4 | **1** | **effect** ‼ | permanently multiplies total armor rating by **1.65** after the Warrior commits 21 points to Bulwark. The first hit in **180 s** that would take the Warrior below 20% max HP then adds **15 rating after the multiplier** for 8 s. The universal 70% reduction cap remains. | armor-rating aggregate plus the hp-change threshold/window | `armor_rating_multiplier`, `armor_rating_add_low_hp` |
| 5 | **Spite** | Anvil | 1 | 5 | — | +1 / 2 / 3 / 4 / 5 rage per hit taken (base 3) | `grug_abilities/init.lua:2491-2495` | `rage_per_hit_taken_add` |
| 6 | **Affront** | Anvil | 2 | 4 | — | tank-ability threat ×3 → ×3.25 / 3.5 / 3.75 / 4.0 | casts in `grug_core/combat.lua:1083-1089`; authoritative swings in `grug_abilities/init.lua:1383-1389` | `threat_mult_add` |
| 7 | **Bellow** *(keystone)* | Anvil | 3 | 3 | **replaces Taunt** | Taunt stops being single-target: it forces **every** hostile mob within 6 / 8 / 10 m onto the Warrior for its 3 s, same key, same 8 s cooldown | `kits.lua:437-465`, the cast body, run over a hostile-radius loop | `taunt_radius` |
| 8 | **Grudge** | Anvil | 4 | 3 | — | Taunt cooldown 8 s → 7 / 6 / 5 s | `grug_abilities/init.lua:1566-1567`, the one effective cooldown arm | `taunt_cooldown_sub` |

Hold Ground is Bulwark's one new button and the tree's one rule-breaker
besides the capstone. Its break is the useful one for a tank: a Warrior who
has committed to holding a spot cannot be kited off it for eight seconds. The
named consequence stays: there is **one absorb per player and a new one
replaces the old** (`grug_core/combat.lua:1003-1012`), so a Priest's Power
Word: Shield cast onto the Warrior overwrites Hold Ground. **Ruling 23 ends that**: absorbs stack, §3.11.

Weathered's 1.5% per rank is the pool conversion anchor: its first reachable
rank at level 12 adds 3 HP after rounding, matching the former flat first rank.

### 2.2 Warrior — Ruin

**Ruling 19 removes Hamstring from the Warrior's base kit** so that every
class starts with Strike plus three, and it says the skill "may return later
through a keystone". It does: **Hamstring is Ruin's new-skill keystone**, the
second of the two in this design that are already registered in code
(`kits.lua:403`, gated the way Renew is at `:812`). That makes Broadstroke a
replacement rather than a registration, and it re-cuts the Lash chain so that
nothing below tier 3 modifies a skill the player may not have yet.

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|---|
| 1 | **Heavy Hand** | Hammer | 1 | 5 | — | Mighty Blow ×1.5 → ×1.55 / 1.60 / 1.65 / 1.70 / 1.75 weapon damage | `kits.lua:384-391` | `mighty_blow_multiplier_add` |
| 2 | **Stoke** | Hammer | 2 | 4 | — | +1 / 2 / 3 / 4 rage per landed authoritative swing (base 8) | `grug_abilities/init.lua:90-99` and its authoritative/proportional callers | `rage_per_swing_add` |
| 3 | **Broadstroke** *(keystone)* | Hammer | 3 | 3 | **replaces Mighty Blow** | Mighty Blow also strikes every other hostile within 3 m for **half** its total, rounded down, at ×3 threat — the game's first melee cleave, on the key Mighty Blow already occupies | `kits.lua:384-391` plus a hostile-radius loop | `mighty_blow_cleave` |
| 4 | **Ruination** *(capstone)* | Hammer | 4 | **1** | **effect** ‼ | a landed Mighty Blow grants **10 s** of crit chance **+20 percentage points** with the 30 % crit cap raised to **50 %**. *Limit: 10 s, **120 s cooldown** on the trigger.* | `grug_classes/stats.lua:122-140` | `crit_cap_override` |
| 5 | **Keen Edge** | Lash | 1 | 5 | — | +1 / 2 / 3 / 4 / 5 percentage points crit chance (30 % cap holds) | `grug_classes/stats.lua:122-137` | `crit_chance_add` |
| 6 | **Onset** | Lash | 2 | 4 | — | Charge cooldown 10 s → 9 / 8 / 7 / 6 s | `grug_abilities/init.lua:1566-1567`, the one effective cooldown arm | `charge_cooldown_sub` |
| 7 | **Hamstring** *(keystone)* | Lash | 3 | 3 | **new skill** *(already registered)* | the shipped ability (`kits.lua:403-434`): 10 rage, a 6 s charge, and on a charged proc a 50 % slow for 5 s exactly as `classes.md:426` specifies. Ranks 2 and 3 lengthen the slow to **6 / 7 s** | `kits.lua:421-430`; the grant gate is `talent_gated = true` at `:409` | `hamstring_slow_add` |
| 8 | **Tendon Cut** | Lash | 4 | 3 | ‼ | Hamstring's charged proc **roots** for 2 / 2.5 / 3 s before its slow begins — a root off an ordinary swing. *Limit: **12 s internal cooldown**, independent of the charge.* | `kits.lua:421-430`, using the player/mob root machinery at `:589` and `:596` | `hamstring_root` |

Ruin's chain totals are the asymmetry §1.2 describes: Hammer
`5 + 4 + 3 + 1 = 13` because it carries the one-rank capstone, Lash
`5 + 4 + 3 + 3 = 15`.

Broadstroke needs no new timing machinery: it rides the authoritative swing
exactly as Mighty Blow already does (`classes.md` §2b), and Mighty Blow's rage
cost is what keeps it off every swing. Tendon Cut is Ruin's one rule-breaker
besides the capstone, on a timer deliberately independent of the charge.

**Charge is no longer the untouched ability.** Onset re-tunes its cooldown,
and Affront (§2.1) raises the threat multiplier it is the only caster to pass
(`kits.lua:312`, `threat_mult = 3`, read at `grug_core/combat.lua:963`). Its
12 m reach, 3 damage and 15 rage are still untouched by any talent.

**User finding, 2026-09-16 (ruling 16): rage fills too fast.** "In combat the
resource is effectively unlimited." Every talent in this tree assumes rage is
a limiter — Stoke adds to it, Heavy Hand and Broadstroke spend it — so if the
pool is always full, several of them re-tune a number nobody feels. The
shipped generation and spend numbers, the arithmetic and two calibration
options are **ruling 25** and **§7 task 8**; nothing in these tables changes for it,
because the fix belongs to `classes.md` §3 rather than to WP11.

### 2.3 Mage — Ember

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|---|
| 1 | **Tinder** | Blaze | 1 | 5 | — | Fireball's `baseline weapon + spell power` raw value gains +1 / 2 / 3 / 4 / 5 before the damage fit | `kits.lua` | `fireball_damage_add` |
| 2 | **Firebrand** | Blaze | 2 | 4 | — | +1 / 2 / 3 / 4 percentage points crit chance | `grug_classes/stats.lua:122-137` | `crit_chance_add` |
| 3 | **Brand** *(keystone)* | Blaze | 3 | 3 | **replaces Fireball** | Fireball's impact splashes `2 / 3 / 4 + floor(spell power / 2)` to every other hostile within 2 m. Same key, same 6% base-mana cost, same 1 s cast interval, same straight flight | `kits.lua` (the projectile's on-hit) plus its radius loop | `fireball_splash` |
| 4 | **Whitehot** *(capstone)* | Blaze | 4 | **1** | **effect** ‼ | the first Fireball that **crits** starts an 8 s window in which Fireball costs **3% instead of 6% base mana** and deals **+6**. *Limit: 8 s, **120 s cooldown** on the trigger.* | the central cost seam and Fireball values | `whitehot_window` |
| 5 | **Deep Well** | Cinder | 1 | 5 | — | max mana +3 / 6 / 9 / 12 / 15 % | `grug_classes/stats.lua:67-105` | `max_mana_percent_add` |
| 6 | **Far Cast** | Cinder | 2 | 4 | — | Fireball maximum distance 20 m → 21.5 / 23 / 24.5 / 26 m | two per-player reads, neither at a registration constant: the spawn call (`kits.lua:534-547`, since `grug_projectiles/init.lua:195` prefers `params.max_distance` over the registered `kits.lua:470-479`), and targeting reach in `grug_abilities.get_range` (`init.lua:267-276`), whose item-meta override `normalize_kit` refreshes (`grug_abilities/init.lua:2181-2197`) | `fireball_range_add` |
| 7 | **Cinderfall** *(keystone)* | Cinder | 3 | 3 | **new skill** | cast, 12% base mana, 10 s cooldown, 20 m; a burst at the first thing the crosshair ray meets, dealing `5 / 7 / 9 + spell power` to every hostile within 3 m of it | new; `grug_core.combat_ray` plus the radius loop | — |
| 8 | **Ashfall** | Cinder | 4 | 3 | — | Cinderfall's radius 3 m → 4 / 5 / 6 m | the new Cinderfall registration | `cinderfall_radius_add` |

Fireball's flight is not eaten by the longer range: `lifetime = 2`
(`kits.lua:479`) at `speed = 20` (`:471`) allows 40 m. Ember takes **no**
rule-breaker besides its capstone — see §2.9's note on the bounded pass.

### 2.4 Mage — Rime

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|---|
| 1 | **Deep Chill** | Frost | 1 | 5 | — | Frost Nova root 4 s → 4.2 / 4.4 / 4.6 / 4.8 / 5.0 s | `kits.lua:581-598` | `frost_nova_root_add` |
| 2 | **Hoarfrost** | Frost | 2 | 4 | — | Frost Nova follow-up slow 3 s → 4 / 5 / 6 / 7 s (the 50 % stays) | `kits.lua:583-598` | `frost_nova_slow_add` |
| 3 | **Frostbind** *(keystone)* | Frost | 3 | 3 | **replaces Frost Nova** | Frost Nova stops being self-centred: it is cast at the pointed hostile up to 20 m away and roots everything within 3 / 4 / 5 m **of the target**. Same key, same 10% base-mana cost, same 12 s cooldown — a control tool instead of a panic button | `kits.lua` (the cast body and its radius origin) | `frost_nova_ranged` |
| 4 | **Rimebite** *(capstone)* | Frost | 4 | **1** | **effect** | every root Frost Nova applies also deals `5 + floor(spell power / 2)` on application | `kits.lua:581-598` | `control_damage_add` |
| 5 | **Cold Focus** | Ward | 1 | 5 | — | in-combat mana regeneration ×1.2 / ×1.4 / ×1.6 / ×1.8 / ×2.0 (the base rate is `max(0.25 × (1 + 0.15 × level), 0.0025 × maximum mana)` mana/s, combat_stats.md §5) | `grug_abilities/init.lua` mana-regeneration ticker | `combat_mana_regen_add` |
| 6 | **Quick Step** | Ward | 2 | 4 | — | Blink cooldown 15 s → 13.5 / 12 / 10.5 / 9 s | `grug_abilities/init.lua:1566-1567` — **not** the registration constant | `blink_cooldown_sub` |
| 7 | **Glacial Ward** *(keystone)* | Ward | 3 | 3 | **new skill** | cast, 10% base mana, 30 s cooldown, self; absorbs 10% / 15% / 20% of the class-neutral base pool plus the spell-power percentage for 10 s | new; `grug_core.add_absorb` | — |
| 8 | **Far Step** | Ward | 4 | 3 | — | Blink distance 10 m → 12 / 14 / 16 m | `kits.lua:623-641` (inside the cast body, player in scope) | `blink_distance_add` |

Rime also takes no rule-breaker besides its capstone, and its capstone does
not break one either — Rimebite is simply a strong effect. Same absorb caveat
as §2.1: Glacial Ward and Power Word: Shield no longer overwrite each other — ruling 23, §3.11.

### 2.5 Priest — Mercy

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|---|
| 1 | **Gentle Hand** | Balm | 1 | 5 | — | Flash Heal's 25% base-pool share gains +1 / 2 / 3 / 4 / 5 percentage points | `kits.lua` | `flash_heal_add` |
| 2 | **Quiet Steps** | Balm | 2 | 4 | — | heal threat factor 0.5 → 0.45 / 0.40 / 0.35 / 0.30 (`combat_stats.md` §4) | `grug_core/combat.lua:355`, read inside `add_heal_threat` at `:518-535` | `heal_threat_factor_sub` |
| 3 | **Renew** *(keystone)* | Balm | 3 | 3 | **new skill** *(already registered)* | the shipped ability, granted at rank 1 exactly as `classes.md` §5 specifies (6% base mana, 8 s cooldown, 8% of the base pool plus spell-power percentage every 3 s for 12 s); ranks 2 and 3 raise the tick to 9% and 10% | `kits.lua`; the grant gate is `talent_gated = true` | `renew_tick_add` |
| 4 | **Hearten** *(capstone)* | Balm | 4 | **1** | **replaces Flash Heal** | Flash Heal also heals every **other** ally within 8 m for **65 %** of the amount. Same key, same 8% base-mana cost, same 4 s cooldown — the Priest's group heal, without a group-heal button | `kits.lua` plus its radius loop | `flash_heal_splash` |
| 5 | **Warding Faith** | Aegis | 1 | 5 | — | Power Word: Shield's 25% base-pool share gains +1 / 2 / 3 / 4 / 5 percentage points | `kits.lua` | `shield_absorb_add` |
| 6 | **Deep Reserve** | Aegis | 2 | 4 | — | max mana +3 / 6 / 9 / 12 % | `grug_classes/stats.lua:67-105` | `max_mana_percent_add` |
| 7 | **Turn Aside** *(keystone)* | Aegis | 3 | 3 | **replaces Power Word: Shield** | while the shield holds (at most its 15 s), its target's dodge chance is +10 / 15 / 20 percentage points, **inside** the 30 % cap. Same key, same cost — the shield now buys avoidance as well as absorption | `kits.lua:764-803` and `grug_classes/stats.lua:128-140` | `dodge_chance_window` |
| 8 | **Second Skin** | Aegis | 4 | 3 | — | Power Word: Shield lasts 15 s → 18 / 21 / 24 s | `kits.lua:795-799` | `shield_duration_add` |

Renew is Mercy's **keystone**, and it is the one new-skill keystone in the
whole design that is **already registered**. `progression.md` §2 called it
"the Priest Holy capstone"; ruling 3 re-cut what a capstone is, and the
correction is in `progression.md`'s own commit (§5.3). `classes.md:464`'s
sentence stays true apart from the tree's name.

### 2.6 Priest — Reckoning

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|---|
| 1 | **Sharpened Word** | Word | 1 | 5 | — | Smite's `1.5 × (baseline weapon + spell power)` raw value gains +1 / 2 / 3 / 4 / 5 before the damage fit | `kits.lua` | `smite_damage_add` |
| 2 | **Swift Word** | Word | 2 | 4 | — | Smite cooldown 2 s → 1.85 / 1.7 / 1.55 / 1.4 s | `grug_abilities/init.lua:1566-1567` — **not** the registration constant | `smite_cooldown_sub` |
| 3 | **Word of Ruin** *(keystone)* | Word | 3 | 3 | **new skill** | cast, 8% base mana, 12 s cooldown, 20 m; `6 / 8 / 10 + spell power` damage, healing the Priest for 50 % of it | new; `grug_core.deal_ability_damage` returns the post-crit amount, healed back with `grug_core.heal_player(…, {no_crit = true})` | — |
| 4 | **Last Word** *(capstone)* | Word | 4 | **1** | **effect** ‼ | while the Priest is below 25 % max HP, Word of Ruin's drain heals for **150 %** of the damage dealt — above the 100 % the pipeline otherwise allows. *Limit: 8 s per trigger, **180 s cooldown**.* | the drain half of the Word of Ruin registration | `drain_ratio_override` |
| 5 | **Hard Faith** | Wrath | 1 | 5 | — | +1 / 2 / 3 / 4 / 5 percentage points crit chance | `grug_classes/stats.lua:122-137` | `crit_chance_add` |
| 6 | **Warded Wrath** | Wrath | 2 | 4 | — | while the Priest carries an absorb shield, Smite deals `+1 / 2 / 3 / 4` | `kits.lua:677-717`, gated on `grug_core.get_absorb(user) > 0` (`grug_core/combat.lua:1168`) | `smite_damage_while_shielded_add` |
| 7 | **Recompense** *(keystone)* | Wrath | 3 | 3 | **replaces Smite** | Smite costs 6% instead of 5% base mana and grants the Priest an absorb of 6% / 9% / 12% of the class-neutral base pool plus the spell-power percentage on every landed cast, refreshing rather than stacking. Same key — the solo nuke becomes the solo sustain | Smite settlement and `grug_core.add_absorb` | `smite_absorb` |
| 8 | **Hardened** | Wrath | 4 | 3 | — | max HP +0.3 / 0.6 / 0.9% of the class base pool | `grug_classes/stats.lua` | `max_hp_percent_add` |

Word of Ruin's drain is specified as "50 % of the damage dealt **before the
target's armor**": `deal_ability_damage` returns the amount the ability
published, taken before the central modifier applies armor and the
absorb shield (`grug_core/combat.lua:1147-1168`) to a *player* target. Against a mob it is exactly
what landed.

Hardened's 0.3% per rank uses the same rule: its first reachable rank at level
42 adds 4 HP after rounding, matching the former flat first rank.

### 2.7 Scout — Quarry (implemented in Round 11)

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
| 4 | **Longshot** *(capstone)* | Draw | 4 | **1** | **replaces Loose** | Loose's range 25 m → **33 m**, and a hit landed beyond 25 m deals **+4** | `loose_range_add` |
| 5 | **Quiver** | Ranging | 1 | 5 | — | Loose's arrow is not consumed 10 / 20 / 30 / 40 / 50 % of the time | `arrow_refund_chance` |
| 6 | **Fletching** | Ranging | 2 | 4 | — | Loose's draw time 0.5 s → 0.45 / 0.40 / 0.35 / 0.30 s | `draw_time_sub` |
| 7 | **Pinning Shot** *(keystone)* | Ranging | 3 | 3 | **new skill** ‼ | cast, **12% base mana + 1 arrow**, 25 m; roots the pointed hostile for 2 / 2.5 / 3 s — a root at bow range, which no class has. *Limit: **30 s cooldown**.* | — |
| 8 | **Shifting Weight** | Ranging | 4 | 3 | — | +1 / 2 / 3 percentage points dodge chance | `dodge_chance_add` |

### 2.8 Scout — Veil (implemented in Round 11)

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Key |
|---|---|---|---|---|---|---|---|
| 1 | **Fine Edge** | Blade | 1 | 5 | — | +1 / 2 / 3 / 4 / 5 damage on a landed authoritative swing | `melee_damage_add` |
| 2 | **Deep Focus** | Blade | 2 | 4 | — | max resource +3 / 6 / 9 / 12 % | `max_mana_percent_add` |
| 3 | **Opening** *(keystone)* | Blade | 3 | 3 | **new skill** | swing, **15% base mana**, 12 s charge; on a landed swing taken from **behind** the target (a yaw comparison, no new state), `floor(weapon damage × 2.2 / 2.5 / 2.8) + melee bonus` | — |
| 4 | **Follow Through** | Blade | 4 | 3 | — | Opening's charge 12 s → 10 / 8 / 6 s | `opening_charge_sub` |
| 5 | **Light Step** | Shadow | 1 | 5 | — | +1 / 2 / 3 / 4 / 5 percentage points dodge chance | `dodge_chance_add` |
| 6 | **Slip Away** | Shadow | 2 | 4 | — | Sidestep's cooldown 30 s → 26 / 22 / 18 / 14 s | `sidestep_cooldown_sub` |
| 7 | **Shake Loose** *(keystone)* | Shadow | 3 | 3 | **replaces Sidestep** ‼ | Sidestep also clears every slow and root on the Scout, and for its 4 s the Scout cannot be slowed or rooted again. Same key. *Limit: 4 s, on Sidestep's own **30 s cooldown** (and Slip Away shortens it, which is the trade).* | `root_slow_immunity` |
| 8 | **Untouchable** *(capstone)* | Shadow | 4 | **1** | **effect** ‼ | when the Scout drops below 30 % max HP: dodge chance **+25** percentage points **and the 30 % dodge cap rises to 55 %**, for 6 s. *Limit: 6 s, **180 s cooldown**.* | `dodge_cap_override` |

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
| Ranks | **28** (13 + 15) | 56 | **224** |
| Talents that are neither keystone nor capstone | 5 | 10 | **40** (39 plain numerics plus the rule-breaking finisher Tendon Cut) |
| Keystones | 2 | 4 | **16** |
| …of which **add a new skill** (ruling 13: at most one per tree) | 1 | 2 | **8** |
| …of which **replace an existing skill** | 1 | 2 | **8** (Bellow, Broadstroke, Brand, Frostbind, Turn Aside, Recompense, Twin Shot, Shake Loose) |
| Capstones (never a new skill, **one rank** — ruling 17, decided) | 1 | 2 | **8** |
| …effects | — | — | **6** (Unbroken, Ruination, Whitehot, Rimebite, Last Word, Untouchable) |
| …replacements | — | — | **2** (Hearten, Longshot) |

**New-skill keystones: 8 across all four classes**, one per tree — Hold
Ground, Hamstring, Cinderfall, Glacial Ward, Renew, Word of Ruin, Pinning
Shot, Opening. **Four of those are registered in code**: Renew
(`kits.lua:651-677`, already `talent_gated`), Hamstring
(`kits.lua:350-377`) and Round 11's Pinning Shot and Opening. So:

> **WP11 registers four new abilities** — Hold Ground, Cinderfall, Glacial
> Ward, Word of Ruin.

That is the cumulative effect of rulings 13, 17 and 19, and it is the largest
scope change in the revision: the pre-ruling design registered **fifteen** and
gave a build up to eight new buttons. Nothing was cut from the *design* —
what used to be new skills are now **ten replacements** and **six effects**,
which is cheaper to build and better to play, because a replacement deepens a
button the player already knows instead of adding a ninth. **Sixteen of the
twenty-four keystones and capstones cost no registration at all.**

**Hotbar budget** (ruling 13's second half, and ruling 19's): a new skill is
one per tree and no build reaches more than one per tree, so **no build
exceeds base kit + 2 keys** — and since ruling 19 takes Hamstring out of the
Warrior's base kit, **every class now starts with Strike + 3 and tops out at
6 of 8**. §3.4 works it out per class. This resolves what the previous
revision carried as an open decision on the hotbar, and it leaves WP14's shield work
**two** free keys rather than one.

**Rule-breakers** (ruling 10), all with their limit in the cell:

| Tree | Rule-breaker besides the capstone | Capstone breaks a rule? |
|---|---|---|
| Bulwark | **Hold Ground** — root/slow immunity, 8 s, 60 s cd | yes — Unbroken permanently multiplies total rating ×1.65 after the exclusive 21-point commitment; its +15-rating emergency window lasts 8 s / 180 s |
| Ruin | **Tendon Cut** — root off a swing, 12 s internal cd | yes — Ruination, crit cap → 50 %, 10 s / 120 s |
| Ember | none | yes — Whitehot, half mana cost, 8 s / 120 s |
| Rime | none | no |
| Mercy | none | no |
| Reckoning | none | yes — Last Word, drain > 100 %, 8 s / 180 s |
| Quarry | **Pinning Shot** — a root at 25 m, 30 s cd | no (Longshot is a plain replacement) |
| Veil | **Shake Loose** — root/slow immunity, 4 s, 30 s cd | yes — Untouchable, dodge cap → 55 %, 6 s / 180 s |

The pass is bounded at **at most** one per tree, not exactly one, and it was
used **twice in the six shipped-class trees**. Rime, Mercy and Ember took none
because their fantasies did not need one, and leaving headroom is cheaper than
inventing breaks: every rule-breaker is a rule the KAT then has to prove is
broken *only* under its own conditions.

Effect keys, counted from the Key column of §§2.1-2.8: **58 key cells, 51
distinct** (6 rows carry no key — the eight new-skill keystones minus Renew
and Hamstring, whose rank scaling each has one). **Three** keys are shared
across classes:
`crit_chance_add` (all four), `max_mana_percent_add` (Mage, Priest, Scout) and
`max_hp_percent_add` (Warrior, Priest). `dodge_chance_add` appears twice but **both
are the Scout** (Shifting Weight in Quarry, Light Step in Veil) — shared across
trees, not classes. §3.2's closed vocabulary and §3.7's KAT group 5 are sized
on the 51.

`progression.md` §2's "**9 of 10 talents are numeric modifiers**" does not
survive rulings 2 and 3 in any reading: a tree of 8 talents carries 5 numeric,
2 keystones and 1 capstone. §5.3 corrects the sentence.

### 2.10 Two consequences of touching shipped numbers

**The decided ability tables become *base* values.** `classes.md` §§3-5 state
their numbers flatly: Mighty Blow is "exactly floor(weapon damage × 1.5)"
(`classes.md:425`), Hamstring charges 6 s and slows for 5 s (`:421`), Taunt
runs 8 s (`:422`), Frost Nova roots 4 s then slows 3 s (`:441`), Blink
  teleports 10 m (`:442`), Smite has a 2 s cooldown (`:456`), Flash Heal uses
  25% of the base pool, Power Word: Shield lasts 15 s (`:458`), and
the 2026-08-06 kit-tuning note reasons from "+12 rage per auto-hit" (`:413`,
`:425`). **Eighteen talents re-tune exactly these numbers.** Nothing forbids
it — improving existing buttons is what `classes.md:59-61` says talents are
for — but when WP11 lands those tables are the **untalented baseline**, and
`classes.md` needs that word or the next reader will file a talented Taunt as
a bug.

Flat damage additions from these talents are assembled before the damage-only
`grug_core.level_scale(level)`. Healing and absorb talents instead add
percentage points to the ability's class-neutral base-pool share; spell power
is applied as a percentage bonus and `scale_player_value` remains an identity.
Applying the damage scalar to those completed support values would double
their level growth.

**Nine talents deliberately break a decided rule, and every one states its
price.** Ruling 10 is what permits it — "skills may explicitly break the base
inequalities; that is what skills are for (Blink and a dodge roll already do).
The bigger the break, the stronger the limit, usually cooldown or duration."
All nine are listed in §2.9 with their limits — four rule-breakers besides a
capstone, and five capstones that break one. Two break a **cap**: Ruination
(crit → 50 % for 10 s) and Untouchable (dodge → 55 % for 6 s). Unbroken instead
multiplies raw armor rating while preserving the universal 70% reduction cap.
Four
break an **immunity or control rule** (Hold Ground, Shake Loose, Tendon Cut,
Pinning Shot), one breaks a **resource cost** (Whitehot) and one a **healing
ratio** (Last Word). The Scout's base-kit Sprint is a tenth, and it is not a
talent — [scout.md](scout.md) §2 carries it.

`combat_stats.md` §2 owns the armor formula and the named Crit/Dodge cap
exceptions. The Talents header shows raw rating, Unbroken's multiplier and the
resulting armor rating rather than presenting rating as a percentage.
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

*Two entries of that table name talents that no longer exist*: **Hobble**
(Lash's old tier-2) and **Deadweight** (its old tier-4) were both retired by
ruling 19's Ruin rebuild, which moved Hamstring to tier 3 and put **Onset**
and **Tendon Cut** in their places — Hamstring's own ranks now carry the slow
duration Deadweight used to. The renames stay recorded because the table is a
history of what was retired and why, not a list of live names.

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

- **Low risk (no collision either reader is aware of), 54 names:** Ironbound,
  Weathered, Hold Ground, Unbroken, Spite, Affront, Bellow, Grudge, Heavy
  Hand, Stoke, Broadstroke, Ruination, Keen Edge, Tinder,
  Firebrand, Whitehot, Deep Well, Far Cast, Cinderfall, Ashfall,
  Hoarfrost, Rimebite, Cold Focus, Quick Step, Far Step, Gentle
  Hand, Quiet Steps, Hearten, Warding Faith, Deep Reserve, Turn Aside, Second
  Skin, Sharpened Word, Swift Word, Word of Ruin, Last Word, Hard Faith,
  Warded Wrath, Recompense, Hardened, Strong Draw, Cold Eye, Twin Shot,
  Longshot, Fletching, Shifting Weight, Fine Edge, Deep Focus,
  Follow Through, Light Step, Slip Away, Shake Loose, Untouchable, Onset.
- **Medium risk, recorded and NOT renamed.** **Ruling 21 settles the
  criterion**: "what matters is the overall similarity — single words like
  'Holy' or 'Sprint' are not protected; the whole picture must not sit too
  close to WoW." Every entry below is a *single-word or single-concept* echo,
  so none of them is renamed; the list stays because a reviewer should be able
  to see that it was looked at, and because if enough of them accumulated the
  *picture* would be the thing ruling 21 forbids.

  | Name | The echo | An alternative, if the picture ever gets too close |
  |---|---|---|
  | **Deep Chill** | the shape of *Deep Freeze* (Frost Mage) | **Long Winter** |
  | **Frostbind** | *Frostbite*, a Classic Frost Mage talent, and this is a Frost-tree talent | **Rimelock** |
  | **Glacial Ward** | near *Ice Ward* / *Ice Barrier* (Frost Mage) | **Coldshell** |
  | **Tendon Cut** | *Tendon Rip*, a Classic Hunter pet snare, and this is a snare | **Cut Deep** |
  | **Pinning Shot** | *Binding Shot*, a Hunter talent that roots at range — the same function and the same placement | **Stake Shot** |
  | **Brand** | *Fiery Brand* (Vengeance Demon Hunter) | **Sear** |
  | **Quiver** | an ordinary noun, and a Hunter aura in some expansions | **Full Quiver** |
  | **Opening** | generic, but next to WoW's "opener" vocabulary | **First Cut** |
  | **Snare Shot** | the Scout's base kit ([scout.md](scout.md) §2): an ordinary phrase, and adjacent to the Hunter "…Shot" family | **Cripple Shot** |
  | **Sprint** | the Scout's base kit: an ordinary English word, and a Rogue ability — **explicitly named by ruling 21 as not protected** | **Break Away** |

  **The count is the thing to watch, not any single entry.** Three of these
  sit on the Scout's bow tree and one in its base kit, which is the one place
  in the design where the picture could start to read as WoW's Hunter. If a
  later pass renames anything, that cluster is where to start.

- **A question for the user, not an automatic rename.** Under ruling 21 this
  is the one naming item that is about the *picture* rather than a word: the
  Priest's **Sharpened Word / Swift Word / Word of Ruin / Last Word** extend
  WoW's Priest *"Power Word:" / "Shadow Word:" / "Holy Word:"* family — four
  new talents, on the Priest, in that exact vocabulary — and **Twin Shot**
  plus Snare Shot extend the Hunter *"…Shot"* family on the bow class. The
  shipped `Power Word: Shield` is pre-existing and ruling 5 does not reopen
  it. Clean replacements if the user wants them: **Whetted Verse**, **Quick
  Verse**, **Verse of Ruin**, **Final Verse**; **Twinned Arrow**.
- **Deliberately kept by ruling 5 (tree names):** Ruin, Rime, Reckoning.
- **Renew and Hamstring keep their names**, and are the two talents that are
  also shipped abilities (§2.5, §2.2). They belong to the pre-existing group
  with the nine shipped ability names — Power Word: Shield, Frost Nova, Flash
  Heal, Blink, Hamstring, Charge, Smite, Taunt, Renew — which ruling 5 does
  not reopen and which ruling 21's "single words are not protected" settles
  for all but *Power Word: Shield*, the one that is a phrase rather than a
  word.
- **The audit covers all 64 talents**: 54 low-risk, 8 medium (the table
  above, which also carries the Scout's two base-kit names), and these two
  shipped names. A script over §§2.1-2.8 checks that every name in a table
  appears in exactly one of those groups.

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
    name = "Ironbound", description = "Armor rating +1 per rank.",
    effects = {armor_rating_add = {1, 2, 3, 4, 5}},  -- one value per rank
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
    effects = {armor_rating_multiplier = {1.65},
               armor_rating_add_low_hp = {15}},
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
per-player read written there would change the number for everybody. **Five
talents of the three shipped classes** therefore hook a central per-player
site instead, and each of those sites already exists and is already the only
one of its kind:

| Talent | The constant it re-tunes | Where the read goes |
|---|---|---|
| Grudge, Quick Step, Swift Word | `cooldown` in the ability def | `grug_abilities/init.lua:1233`, the sole `arm_cooldown(user, def, def.cooldown)` call |
| Onset | `cooldown` in the ability def — Charge's, `kits.lua:299` | the same `arm_cooldown` call, `grug_abilities/init.lua:1233` |
| Far Cast | `max_distance` in the projectile registration (`kits.lua:413`) and `range` in the ability def (`:446`) | flight: the spawn call (`kits.lua:453-460`), since `grug_projectiles/init.lua:195` prefers `params.max_distance`; targeting reach: `grug_abilities.get_range` (`init.lua:170-177`), the twin of the elf `ability_range_bonus` perk, whose item-meta override `normalize_kit` refreshes (`grug_abilities/init.lua:1827-1831`) |

The Scout adds two more, both onto sites already in the
table: **Slip Away** (Sidestep's cooldown → `init.lua:1233`) and **Follow
Through** (Opening's charge → `init.lua:718`). Nothing in either tree hooks
the `spend` call at `init.lua:1232` except the Mage capstone **Whitehot**,
which halves Fireball's mana cost for its window — the previous revision
routed a Scout talent through that seam, and ruling 14's move from focus to
mana removed it.

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

**Timed windows are the one new shape revision 2 adds.** **Eight talents** are
not a constant summed bonus but a bounded window. Six belong to the three
shipped classes — **Hold Ground** (its root/slow immunity), **Unbroken**,
**Ruination**, **Whitehot**, **Turn Aside** and **Last Word** — and two to the
Scout, **Shake Loose** and **Untouchable**. Of these, four are triggered by a
condition rather than by a button (Unbroken, Ruination, Whitehot, Last Word),
which is a start time the talent code sets, not a new mechanism. The Scout's
base-kit **Sidestep** and **Sprint** use the same table without being talents
([scout.md](scout.md) §2), which is why the table belongs to the window shape
rather than to the talent registry. They are not a third seam — `get_talent_bonus` returns 0 for a window key that is not
running — but they need one small per-player expiry table of the shape
`grug_core`'s absorbs already use (`grug_core/combat.lua:1010-1017`), owned by
`talents.lua` and cleared on leave, death and respec — **not** on a class
change, which ruling 20 abolished. That table
is the single place a window lives; nothing else in the design needs state.

### 3.3 Persistence

- One player-meta **string** key, `grug_classes:talents`, holding `id=rank`
  pairs separated by commas: `ironbound=4,grudge=1`. The same store class and
  race already use (`grug_classes/init.lua:3-4`, `:76`, `:113`); a string
  keeps it to one key instead of sixty-four, and it stays human-readable for
  `/talents` debugging.
- One player-meta **integer** key, `grug_classes:respec_used`, is 0 until the
  first successful free reset and 1 thereafter. It persists across reconnects
  so the free reset is granted once per character; paid resets leave it at 1.
- Parsed once per join into a per-player runtime cache (the pattern of
  `grug_abilities`' runtime tables, `init.lua:22-38`), invalidated on spend,
  respec and leave (a class change is no longer an event — ruling 20).
- **The read path validates, it does not trust.** Unknown ids are dropped,
  ranks are clamped to the talent's own rank count, a rank whose tier gate or
  hard chain is not satisfied is dropped **together with everything below it
  in its chain**, and the total spent is clamped to `floor(level / 2)`. A
  hand-edited meta string therefore cannot buy a capstone at level 4.
- No point balance is persisted. Points available are always derived
  (`floor(grug_xp.get_level(player) / 2)`, `grug_xp/init.lua:48`), never
  stored, so the two can never disagree.

### 3.4 Granting a new skill, and replacing an existing one

A newly ranked active-skill talent adds its ability to the Skills catalogue and announces that location; it does not insert an item. Full respec removes representations that are no longer unlocked. Re-ranking exposes the ability for manual recovery. Passive and replacement talents remain read-only information and never create dummy items.

**Two mechanisms, and ruling 13 makes the second one carry most of the
design.**

**A new skill** is an ordinary `grug_abilities` registration with
`talent_gated = true` and its owning talent ID. The shared
`grug_abilities.is_unlocked(player, id)` predicate checks class membership and
positive talent rank; catalogue listing, recovery, normalization and actual
cast/swing execution all use that authority. Possessing a forged or stale
representation never grants an ability.

A talent-granted ability appears in Inventory > Skills and is recovered
manually. Registration order determines catalogue order but never moves an
existing hotbar item. Under ruling 10 at most two such abilities exist per
build. Base-kit insertion occurs once at character creation; later unlocks
announce catalogue availability and do not require a free inventory slot.

**A replacement** (the eight replacing keystones and the two replacing
capstones) is **not** a registration and touches none of the above. The
shipped ability keeps its id, its key, its icon and its registration; the
talent is a read inside its own `cast` or `proc_swing` body, exactly like
every numeric talent in §2 — Bellow is a radius the Taunt body reads, Hearten
is a loop the Flash Heal body runs, Frostbind is where Frost Nova takes its
origin from. That is why ruling 13 is cheaper as well as kinder to the
hotbar: of the **twenty-four** keystones and capstones, **sixteen** — the ten
replacements and the six effects — cost zero new registrations, zero new
items and zero grant logic.

Talent spending and respec invoke `grug_abilities.normalize_kit(player)`.
This removes stale or duplicate representations and refreshes surviving item
metadata without filling discarded slots. The Skills catalogue refreshes its
entitlement list and announces new entries. Replacements need no additional
item: the next cast reads the current talent rank.

**Hotbar budget** (`classes.md` §2b reserves keys 1-8). Under rulings 13 and
19 the ceiling is **base kit + 2**. Warrior, Mage and Priest start with
**Strike + 3**; Scout's explicitly approved four class abilities give it
**Strike + 4**:

| Class | Base kit | Max new buttons | Worst case |
|---|---|---|---|
| Warrior | Strike + 3 — Charge (`kits.lua:291`), Mighty Blow (`:321`), Taunt (`:380`); **Hamstring leaves the base kit with ruling 19** and returns as Ruin's keystone | 2 (Hold Ground, Hamstring) | **6 of 8** |
| Mage | Strike + 3 (`classes.md:445-447`) | 2 (Cinderfall, Glacial Ward) | 6 of 8 |
| Priest | Strike + 3 (`classes.md:461-463`) | 2 (Renew, Word of Ruin) | 6 of 8 |
| Scout | Strike + 4 ([scout.md](scout.md) §2) | 2 (Pinning Shot, Opening) | **7 of 8** |

Two keys stay free in the original three classes; Scout keeps at least one
free key. The Warrior's remaining space accommodates `classes.md`'s parked
"Warrior shield abilities → after WP14 (offhand/shields)", for which
`register_ability` already carries the `slot = "offhand"` plumbing
(`grug_abilities/init.lua`). All four classes remain inside the eight-key
hotbar; Scout's extra base skill does not add an extra talent-button allowance.

**A Warrior who takes neither Ruin keystone has no snare.** That is the cost
of ruling 19, and it should be visible rather than discovered: Hamstring is
`classes.md:419-420`'s "control tool (in
an engine where mobs outrun players, the snare is the Warrior's identity)", and a Bulwark-only Warrior now reaches
level 26 before that identity is available at all. The counter-argument the
ruling rests on is that a Warrior who wants the snare gets it **and** its
ranks in one 13-point commitment, instead of being handed it at level 1 and
then re-tuning it with three separate talents.

### 3.5 UI

A third `sfinv` page beside Character and Bags (`grug_inventory/pages.lua:182`,
`:246`), registered from `grug_classes/talents_ui.lua` so the page lives
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
| Crit 30/42% (30)                  Armor rating 299 (181 x1.65) |
| Dodge 20/20% (30)                                             |
|                                            [ Respec  --  1s25c]|
|      WALL                       ANVIL                          |
| T1 | Ironbound      5/5 |   | Spite          5/5 |             |
| T2 | Weathered     4/4 |   | Affront        3/4 |     (>=5)   |
| T3 | Hold Ground *  3/3 |   | Bellow *       0/3 |     (>=12)  |
| T4 | Unbroken **    1/1 |   | Grudge         0/3 |     (>=20)  |
|                                                               |
| Unbroken -- rank 1/1: total armor rating x1.65; below 20% HP, |
| +15 rating after the multiplier for 8 s / 180 s.             |
+---------------------------------------------------------------+
```

- `*` marks a keystone, `**` the capstone; a locked talent is a plain label
  (no click target) with its reason spelled out ("needs 12 points in Bulwark"
  or "needs Weathered 4/4").
- Clicking a talent selects it and writes the one-line explanation; clicking
  the selected talent again spends a point, so the page needs no "+" column
  and no confirmation dialog.
- The **Respec button lives here** (ruling 4) with its price in the label and
  an inline confirmation prompt, since there is no NPC to host the transaction.
- Fixed numeric button fields map only to registered trees and talents of the
  submitting PlayerRef's own class. Names and descriptions are escaped with
  `core.formspec_escape`; no player name or free-text field enters a purchase.
- Two compact header rows above the tree controls show effective/raw Crit and
  Dodge plus raw/resulting Armor rating and its active multiplier. Every label stays inside the
  eight-unit form, and both rows end before the tree controls; the T1 row starts
  below those controls and chain headings. A running named Crit/Dodge cap
  override shows its raised display cap; Unbroken instead shows the active
  rating multiplier and emergency addition.
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
(`grug_xp/init.lua:62-64`) only when at least one point is unspent, directing
the player to Inventory > Talents. No new globalstep, no new HUD element, no
new packet.

### 3.7 The KAT

`tools/wp11/talent_tree_kat.lua`, plain Lua 5.1 under a stub registry, in the
shape of `tools/wp13/ability_rightclick_kat.lua:1-45` — it loads the **real**
`talents.lua` and the real `register_talent`, and runs under both interpreters
with identical output. Eight groups, each able to go red on its own:

1. **Shape.** Every class has exactly 2 trees; every tree 8 talents in two
   chains of 4; ranks 5/4/3/3 by tier; exactly one keystone per chain in
   tier 3; exactly one capstone per tree, in tier 4, on a declared chain.
   Tier gates are 0/5/12/**20** points in the tree. Totals: **28 ranks per
   tree, 56 per class**.
2. **Arithmetic.** `floor(60/2) == 30`; one tree costs **28**; each tree is
   13 + 15 ranks; the milestone table of §1.3 reproduces exactly
   (13 / 15 / 20 / 21 / 28 points in a tree); **a capstone costs 21 and two
   cost 42 > 30**, which is ruling 18's "one capstone per character" as an
   assertion rather than a rule; two full trees cost 56 > 30; no build holds
   more than two new-skill keystones. This row goes red if anyone re-tunes
   the cadence or a gate without re-tuning the trees.
3. **Spend rules**, as a table of cases: a tier-2 rank with 4 points in the
   tree is refused and with 5 accepted; a tier-3 rank with 11 refused, 12
   accepted; tier 4 with 19 refused, 20 accepted; a tier-2 rank whose
   tier-1 chain talent is at 4/5 is refused; a sixth rank refused; a spend
   with 0 points left refused; a spend at level 1 refused; **a capstone
   refused at 20 points in the tree and accepted at 21**, and refused at 21
   when its chain's keystone is at 2/3; **a second rank in any capstone
   refused** (ruling 17); and **a second capstone refused outright**, because
   30 points cannot reach two (§1.3's arithmetic — this is the row that goes
   red if anyone re-tunes a gate and quietly makes two reachable).
4. **Persistence round trip.** Serialize → parse → identical; forged meta
   (`unknown_id=2,ruination=9`) is dropped and clamped; a forged mid-chain rank
   drops everything below it in that chain.
5. **Effect-key coverage.** Every key in the closed vocabulary is read by at
   least one consumer source file, and every `effects` key a talent uses is in
   the vocabulary. This is the row that goes red when a talent is added whose
   modifier nothing applies — the failure mode a numeric talent system has.
6. **Cap and armor invariants.** With every crit talent at rank 5 on a level-60
   character and **no** window running, `get_crit_chance` still returns
   ≤ 0.30; with every dodge talent maxed, `get_dodge_chance` ≤ 0.30; with the
   armor talents maxed, final armor reduction remains ≤ 0.70. With identical
   maximum gear and five Ironbound ranks, a damage Warrior remains about 60.9%
   against an L70 dragon; the 21-point Bulwark commitment reaches about 68.5%,
   and its emergency window about 69.6%. **With Ruination running, and only
   then,** crit may reach 0.50. (The dodge cap is only
   raised by the Scout's Untouchable, so its invariant belongs to lane S3 and
   this group asserts dodge ≤ 0.30 unconditionally for the three shipped
   classes.)
7. **Window lifecycle.** Every timed window returns 0 before it starts and
   after it expires, and respec, death and leave clear it — those are now the
   only three lifecycle events, since ruling 20 removed the class change.
8. **The shared central seams stay neutral without talents.** The six talents
   that hook `arm_cooldown` (`grug_abilities/init.lua:1233`), the charge line (`:718`), the
   spend line (`:1232`) and `get_range` (`:170-177`) sit on paths every
   ability of every class runs through. One case per seam with **no talent
   ranked** must reproduce today's value exactly — Taunt 8 s, Blink 15 s,
   Smite 2 s, Hamstring 6 s, Fireball 6% base mana and 20 m, and an elf's Fireball
   still 25 m.

**Mutation proof** the review should demand: revert the one line of
`stats.lua:45` that adds `crit_chance_add` and group 5 goes red; give a
tier-1 talent 6 ranks and group 1 goes red; make the `arm_cooldown` read
default to 1 instead of 0 and group 8 goes red; let a window key leak past its
expiry and group 7 goes red.

`tools/wp11/talent_ui_kat.lua` loads the real model and page. It covers the
select-then-buy interaction, budget/tier/prerequisite refusals, free-first and
charged respecs through the public money API, the guarded level-up notice,
numeric-field ownership, navigation order, formspec escaping, talent-data
tooltips and the raw/effective/cap render. It runs byte-identically under both
interpreters; changing the first-respec test from unused to used makes its
free-first assertion fail.

### 3.8 What changes where

| File | Change | Size |
|---|---|---|
| `grug_classes/talents.lua` | **new** — registry, the 48 talents of the three shipped classes (3 classes x 2 trees x 8), spend/respec, persistence, window table, the two accessors | large |
| `grug_classes/talents_ui.lua` | **new** — the sfinv page of §3.5 | medium |
| `grug_classes/init.lua:210-214` | one `dofile` line for the UI | 1 line |
| `grug_classes/mod.conf` | two dependency edges: `sfinv` and `grug_money` | 1 line |
| `grug_classes/stats.lua:20,30,45,90` | four talent reads (max HP, max mana, crit + the crit-cap override, the level-up line with the `old_level ~= nil` guard). `stats.lua:49`'s dodge cap is the Scout's alone and belongs to lane S3 | small |
| `grug_abilities/kits.lua:342,370,372,453-460,458,495,496,504,505,533,591,613,640,671` | one talent read per numeric talent whose number lives inside a function body, plus Warded Wrath's shield gate at `kits.lua:591` | medium |
| `grug_abilities/init.lua:170-177,718,1232,1233` | the four **central per-player seams** the load-time constants force (§3.2) | small |
| `grug_abilities/init.lua:939,950,966,1719,1724,1808,1858,2109,2202` | rage per swing; the grant predicate at the three `talent_gated` sites; the append-after-base-kit rule; rage per hit taken; in-combat mana regen | small |
| `grug_abilities/kits.lua` (new section) | **4 new ability registrations** for the three shipped classes — Hold Ground, Cinderfall, Glacial Ward, Word of Ruin (§2.9) | medium |
| `grug_abilities/kits.lua:350` | one `talent_gated = true` on the **shipped Hamstring**, which ruling 19 moves out of the Warrior's base kit and into Ruin's keystone | 1 line |
| `grug_abilities/kits.lua:340-344, 368-374, 389-404, 429, 488-490, 583-592, 612-614, 639-640` | **the seven replacements** of the three shipped classes — six replacing keystones (Bellow, Broadstroke, Brand, Frostbind, Turn Aside, Recompense) and the replacing capstone Hearten — plus the rule-breaking finisher Tendon Cut; each a read inside the shipped ability's own body, no registration (§3.4) | medium |
| `grug_inventory/equipment.lua` armor aggregate | Ironbound rating and Unbroken's deep-tree ×1.65 plus emergency +15 | small |
| `grug_core/combat.lua` and `grug_abilities/init.lua` | attacker-level armor formula; heal threat factor; the threat multiplier on **both** its sites (cast and swing) | small |
| `grug_core/` the speed aggregator | **prerequisite, not this WP** — §3.9. Hold Ground's and Shake Loose's root/slow immunity are flags it owns, and the Scout's Sprint is a modifier in it | — |
| `tools/wp11/talent_tree_kat.lua` | **new** — §3.7 | medium |
| `tools/wp11/talent_ui_kat.lua` | **new** — X4 interactions, transaction and render checks | medium |
| `docs/design/combat_stats.md` §2 | the common cap-override rule; Round 11 has filled its Unbroken armor and Scout dodge cases, while the remaining Mage crit consumer belongs to X3 | small |
| `docs/design/classes.md`, `progression.md`, `economy.md`, `items_crafting.md`, `README.md` | the "base value" wording of §2.10 and the no-class-trainer respec rule | small |

### 3.9 The movement aggregator (ruling 11) — a prerequisite this WP does not own

Three talents and one base-kit ability in this design write the player's
movement: Hold Ground and Shake Loose set a **root/slow immunity flag**, the
Scout's Sprint sets a **+50 % modifier**, and Tendon Cut and Pinning Shot
apply a **root**. They cannot be written the way the game writes movement
today.

**Measured, not inherited.** `grug_mobs/verbs.lua:100-118` says there are two
owners of `physics_override.speed`, and `mounts.md:128-133` and
`boats.md:113-117` both repeat that count. A `grep` over the tree finds
**three**:

| Writer | Lines | What it writes |
|---|---|---|
| mob webs / snares | `grug_mobs/verbs.lua:153`, `:167`, `:178` | `{speed = factor}`, then `{speed = 1}` to restore, plus a join reset |
| the ability root/slow chain | `grug_abilities/kits.lua:161`, `:167` | `{speed = 1, jump = 1}` and `{speed = stage.speed, jump = stage.jump or 1}` |
| **character creation** | `grug_classes/selection.lua:52`, `:91` | `{speed = 0, jump = 0, gravity = 0}` — and `:91` restores a **snapshot** |

The third is the one the two existing comments miss, and it is the most
awkward kind for an aggregator:

- `reassert_player_lock` (`selection.lua:49-53`) **re-asserts** the freeze
  whenever it observes the override drifting, so it would fight any other
  writer for the whole of character creation.
- `release_player` (`:91`) writes back `session.physics`, a snapshot taken
  when creation began. If a slow or a sprint is running at that moment, the
  snapshot captures the *modified* value and restores it permanently after the
  aggregator believes the effect expired — **exactly the bug class ruling 11
  exists to end**, and one the aggregator does not fix unless this writer
  migrates too.

**It is an aggregator for speed *and* jump, not speed alone.** The shipped
roots are speed+jump pairs — Frost Nova's stages are
`{speed = 0.1, jump = 0.3, time = 4}` (`kits.lua:495`) and the applier writes
`jump = stage.jump or 1` (`:167`) — while `verbs.lua:114-116` deliberately
records "We only ever write `speed`; `jump` is left alone, so a mob web can
never lift a PvP jump root". A speed-only API cannot express the roots it is
supposed to absorb. **Gravity stays out**: its only writer is
`selection.lua:52`'s spawn freeze, which is a whole-player lock rather than a
combat effect, and it migrates as a single named exclusive hold, not as a
gravity modifier.

**Ruling 11 decides the shape**: one central aggregator in `grug_core` where
each system registers a **named** modifier with its **own duration**; effects
overlap freely; a **root is a hard flag** — speed 0 regardless of modifiers,
never a "−1000 %"; **mounts stay outside it**, exactly as `mounts.md:128-133`
already requires.

```lua
grug_core.set_move_modifier(player, "sprint", {speed = 0.50}, 10)
grug_core.set_move_modifier(player, "mob_web", {speed = -0.40}, 7)
grug_core.clear_move_modifier(player, "sprint")
grug_core.set_root(player, 4)             -- hard flag: speed 0, jump 0
grug_core.set_move_immunity(player, 8)    -- discards negatives and roots
grug_core.hold_movement(player, "class_creation")  -- exclusive; releases exactly
```

**Recommended combination rule: additive percentages per axis, then one
clamp.** `speed = clamp(1 + Σ speed, 0.1, 1.5)` and the same for `jump`, with
a root or an exclusive hold taking precedence over the sum. Additive rather
than multiplicative because the shipped numbers already read as absolute
speeds (`kits.lua:372` sets `speed = 0.5`), because two slows multiplying to
0.25 is a stacking rule nobody decided, and because a sum is the only form in
which the KAT can state a single invariant without enumerating orders. Ruling
26 makes it binding.

**Size, honestly.** The **core** is roughly **100 lines**: a per-player table
of named entries with expiries, one accumulator per axis, the root flag, the
immunity, the exclusive hold, and the join/leave reset `verbs.lua:176-186`
already performs. The **migrations are extra** and are what the lane must
budget for — the machinery being replaced is about 95 lines in
`verbs.lua:100-200` plus about 55 in `kits.lua:118-176`, and the third writer
brings its own snapshot/re-assert logic:

| Piece | Work |
|---|---|
| aggregator core (speed + jump, root, immunity, hold) | ~100 lines, new |
| migrate `grug_mobs/verbs.lua`'s slow chain | rewrite ~95 lines down to calls |
| migrate `grug_abilities/kits.lua`'s staged root/slow | rewrite ~55 lines, and the staged `root → slow` chain becomes two named modifiers with different durations, which is what it always wanted to be |
| migrate `grug_classes/selection.lua` | the freeze becomes `hold_movement`, the snapshot restore disappears |
| KAT | overlap, expiry, root precedence, immunity, hold, and a no-effect baseline per axis |

**It is a prerequisite, and it is not WP11's.**
`docs/research/mob-pressure-task-card.md` §4b carries it, because a mob that
must keep moving while it swings is the other consumer. WP11 should **not**
start Hold Ground or anything Scout-shaped until it exists; everything else in
§4 is independent of it.

### 3.10 Removing the class change (ruling 20) — what it touches

Ruling 20 removes class changing from the game entirely, for admins too. That
is a deletion rather than a feature, but it is not free: **five** shipped
comments and one command registration assume the opposite, and WP11 is the WP
that makes them wrong.

| Site | What it is | What ruling 20 does to it |
|---|---|---|
| `grug_classes/selection.lua:594-595` | the `/class` registration — one call to the generic `register_set_command` helper | **that call is removed**, and nothing else. `:554-592` is the helper itself and `:596-597` registers `/race`, which ruling 20 does not touch; deleting the range would take both with it |
| `grug_abilities/init.lua:1772-1780` | `normalize_kit` entitlement purge — removes unavailable kit representations | **kept**, and it becomes the respec path's purge instead: a full talent reset has to take back the two talent-granted buttons (§3.4), which is the same operation |
| `grug_abilities/init.lua` lifecycle | Separate one-time character kit insertion from normalization | Class switching is unavailable. Join and talent changes normalize existing representations; neither re-grants discarded skills. Skills recovery preserves cooldown and charge state. |
| `grug_inventory/equipment.lua:57` | "the class-change unequip below, later WP11 respec / WP14…" | comment corrected: there is no class change, and a talent respec never unequips anything |
| `grug_inventory/equipment.lua:501` | "Admin-only today, **player-reachable with WP11's respec**" | the promise is **withdrawn**. The class-restriction unequip path becomes unreachable by design, and the comment must say so rather than point at a WP11 that will not deliver it |
| `grug_inventory/equipment.lua:579` | "a Warrior who respecs to Mage" | comment corrected: that character cannot exist |
| `grug_core/combat.lua:110` | "WP11's respec unequipping what the new class may not wear" | comment corrected; it is listed there among "the writers this is waiting for", and one of them is now never coming |

**The equipment argument is the ruling's own**, and it is the strongest one:
a class change has to decide what happens to gear the new class may not wear
(`inventory_equipment.md:184-193`'s armor-class ranks — Warrior 3, Mage 1,
Priest 1), and every answer is bad. Removing the operation removes the
question. The cost is that `equipment.lua:501`'s class-restriction unequip
code stays in the tree with no caller; it should be kept (it is the guard that
makes the rank rule true if anything ever writes an equipment list directly)
and re-commented, not deleted.

**Character creation is unaffected**: choosing a class for the first time is
not a change, and `selection.lua`'s creation flow stays exactly as it is —
including the movement freeze that §3.9 migrates onto the aggregator.

### 3.11 Absorb shields stack (ruling 23)

Revision 2 recorded "one absorb per player, a new one replaces the old"
(`grug_core/combat.lua:1003-1012`) as a named consequence and put a second
slot to the user as an open decision, because four sources write it: Power
Word: Shield (Priest base kit), Glacial Ward (Mage keystone), Hold Ground
(Warrior keystone) and Recompense (Priest keystone, on every landed Smite).
A healer shielding the tank deleted the tank's own cooldown.

**Ruling 23 answers it with the pattern ruling 11 already established**:
absorbs stack as **named contributions with independent durations**, one
aggregator, no replacement.

```lua
grug_core.add_absorb(target, "power_word_shield", amount, 15)
grug_core.add_absorb(target, "hold_ground", amount, 8)
grug_core.get_absorb(target)        -- unchanged signature: the total
```

- **Soak order: shortest remaining duration first.** A shield about to expire
  should be the one that is spent, or a long self-buff swallows damage a
  15-second heal-cast was meant to take. This is the one rule the old single
  slot never had to state.
- **Re-casting the same name refreshes that contribution**, and does not add a
  second one — so Recompense on every Smite tops its own shield up rather than
  stacking a dozen.
- **The read side does not change.** `grug_core.get_absorb(player)`
  (`combat.lua:1020`) keeps its signature and returns the sum, so Warded
  Wrath's "while the Priest carries an absorb shield" gate (§2.6) and the
  central hp-change modifier's soak (`:1003-1030`) are untouched.
- **A cap is still needed**, and it is a number for the balance pass rather
  than for this file: with four writers and no replacement, a coordinated pair
  can stack more absorb than any single source was balanced against.
  Recommendation: cap the **total** at the target's max HP, which is
  self-scaling and needs no table.

**Size: ~40 lines in `grug_core/combat.lua`**, replacing the ~30 that the
single slot occupies at `:1003-1030`. **It shares no code with the movement
aggregator of §3.9** — the arithmetic is different (a consumable pool drained
by damage, not a multiplier summed per axis) — but it shares its *shape*:
named entries, independent expiries, one accessor, cleared on leave and death.
Building them in the same lane would let one KAT cover both lifecycles, and
that is the only argument for pairing them.

**Ownership**: it is a `grug_core` change, so like §3.9 it is **not**
`grug_classes`' to make. Unlike §3.9 it has no consumer outside WP11 — no mob
and no NPC writes an absorb — so WP11's lane X3 can carry it.

---

## 4. Implementation lanes

Rulings 13, 17 and 19 together shrank this WP more than any other decision in
the revision: **four** new ability registrations instead of fifteen, sixteen
of the twenty-four keystones and capstones costing nothing to register, and
one-rank capstones. The five-lane cut of the previous revision collapses back
to **four**, in dependency order. X2, X3 and X4 run in parallel once X1 has
landed.

| Lane | Scope | Depends on | Size |
|---|---|---|---|
| **X1 — the model** | `talents.lua`: registry, the 48 talent registrations of the three shipped classes (data only, no consumer), points, the two gate kinds, spend/respec rules, persistence with the validating read path, the window table of §3.2, `get_talent_bonus` / `talent_rank`, the `on_talents_changed` callback, and the whole KAT of §3.7 except group 5's consumer half. Ships with **zero gameplay effect** — every talent is inert. | — | M |
| **X2 — the numeric consumers** | The **30** talents of the three shipped classes that are neither keystone nor capstone, at the sites of the §3.8 table. **Twenty-five are a one-line read where the table says; five hook the three central per-player seams of §3.2** (Grudge, Quick Step, Swift Word and Onset on `arm_cooldown`; Far Cast on the spawn call and `get_range`), and each of those needs its own no-talent regression case (KAT group 8). Completes KAT groups 5 and 6. Touches shared files, so it is one lane and not split by class. | X1 | M |
| **X3 — keystones and capstones (implemented Round 12)** | **Four** new ability registrations (Hold Ground, Cinderfall, Glacial Ward, Word of Ruin); the `talent_gated` flag on the **two shipped abilities that become keystones**, Renew (already flagged) and Hamstring (`kits.lua:350`, ruling 19), plus their rank scaling; the shared entitlement predicate and manual Skills recovery rule of §3.4; **seven replacements** written inside the shipped abilities' own bodies (Bellow, Broadstroke, Brand, Frostbind, Turn Aside, Recompense, Hearten) and the rule-breaking finisher Tendon Cut; the remaining capstone effects and cap-override paths. Round 11 already delivered Ironbound and Unbroken's armor-rating multiplier/window, Round 12 preserves that implementation alongside Scout. The Crit override, named absorbs and Hold Ground immunity use the shared §3 seams. The bounded native X3 probe covers each ability/replacement and lifecycle. | X1, §3.9 for one talent | L |
| **X4 — UI, level-up and respec (implemented 2026-09-17)** | The sfinv Talents page of §3.5, the two `mod.conf` edges, the level-up chat line with its `old_level ~= nil` guard, the respec transaction against `grug_money.take`, the price of ruling 22 (§1.4), and the raw-vs-effective display `combat_stats.md:104-108` requires — including the **raised cap** while a rule-breaker runs. The six price values remain a coordinator placeholder until WP44 publishes the measured ledger outputs. | X1 | M |

X3 is the only lane that owes a runtime test on a headless server; X1, X2 and
X4 are provable with the KAT plus one probe each. A **replacement** owes a
probe of its own kind: the shipped ability must still behave exactly as
`classes.md` §§3-5 specifies with the talent unranked, and differently with it
ranked — that is the mutation proof for the sixteen of twenty-four that
register nothing.

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
   shape; ruling 22 settles it.)*
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
    §7, task 1.)*
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
    back to four lanes. It **resolves** the previous revision's hotbar decision: no build
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
    §7's task 8.)*

**Fifth round, 2026-09-16.** The user answered the *original* open-decisions
list of revision 1 (`main:docs/design/skill_trees.md` §§5.1-5.13) rather than
this file's renumbered §6; each answer is mapped onto the current document
below. After this round **every one of revision 1's thirteen questions is
closed**.

17. **A capstone has ONE rank** — a strong effect or a replacement — and what
    gates it is its chain plus the points in the tree, not a ladder of its
    own. *(Answers original 5.4, and it is worth recording **against** what.
    Main's §5.4 recommended the opposite — "(a) Capstone has 3 ranks…
    **Recommendation: (a)**" — so this is the user taking option (b) over the
    document's own advice, on the coordinator's later recommendation in the
    dialogue, and confirmed by the user afterwards. It is **decided**, not
    pending.*
    *One half of main's 5.4(b) is deliberately **not** taken: it read
    "Capstone has 1 rank **and one numeric talent in the tree gets 5 ranks, so
    the tree still holds 15**". This design takes the one-rank capstone and
    **drops the compensating rank**, which is exactly why a tree is **28** and
    not 30. That is accepted under ruling 1's "slight deviation is fine"
    rather than overlooked: a fifth rank bolted onto one numeric talent per
    tree would buy two ranks of padding and cost the 5/4/3 ladder its
    regularity, and 28 of 30 points leaves a player two to place freely, which
    reads better than an exact fit. §1.2 and §1.3 carry the number openly.)*
18. **Only one capstone per level-60 character, and it must follow
    *implicitly* from the tree's requirements**: reaching a capstone costs
    more than half of all available points, and the first one lands around
    **level 40-44**. *(Answers original 5.5, which asked whether both
    capstones should be reachable — the answer is no. §1.3 shows the gates
    already do it: a capstone costs **21 in-tree points = 70 % of 30 = level
    42**, and two cost 42 > 30, so the second is arithmetically out of reach
    rather than discouraged.)*
19. **Every class starts with four skills — Strike plus three.** The Warrior
    loses one: **Hamstring leaves the base kit**, and "it may return later
    through a keystone". *(Answers original 5.11, the hotbar question.
    Hamstring is now Ruin's new-skill keystone, §2.2; §3.4's budget drops to
    **6 of 8** for every class.)*
20. **Class change is removed entirely, including for admins** — "equipment
    would be a problem otherwise". A respec is **not** a class change; a
    respec is a **full reset**; and an admin level drop triggers a **full free
    reset** as well. *(Answers original 5.9 and 5.10. §1.4 and §3.10 carry the
    consequences, including the shipped `/class` command and the four code
    comments that assume a switch.)*
21. **Names: what matters is the overall picture.** "Single words like 'Holy'
    or 'Sprint' are not protected — the whole must not sit too close to WoW."
    Keep the audit; do not rename for single common words. *(Answers original
    5.6. §2.11 keeps its confidence labels and stops proposing renames for
    single-word collisions.)*
22. **Respec price: original 5.7's option (a)** — five minutes of measured
    reliable net solo income at the character's own bracket, **and the first
    respec of a character is free**. *(Closes what this file carried as an open decision on the respec price.
    `BACKLOG.md`'s "5c × level, min 25c" is retired by it.)*
23. **Absorbs stack**, the way speed effects do: named contributions with
    independent durations in one aggregator, instead of "one absorb slot, a
    new shield replaces the old". The Warrior's tank cooldown keeps the
    **self-absorb** form of original 5.13 variant (B) — in this design that is
    **Hold Ground**, Bulwark's keystone, since ruling 13 made the capstone
    (Unbroken) an effect. *(Closes what this file
    carried as an open decision on the absorb collision; §3.11 sizes it and says what it shares with §3.9.)*
24. **Open questions may live inside the design docs**, as long as each is
    clearly attributable to its design doc — so §6 stays in this file and in
    `scout.md`, and no root `TODO-…md` is created. *(Answers original 5.1 and
    closes this file's earlier question about where the open list should live.)*

Original 5.2, 5.3, 5.8 and 5.12 were already closed by rulings 1, 2/3, 4 and
10 respectively, and are recorded there.

**Sixth round, 2026-09-16 (interactive).** The user answered the five items
that were still open after the fifth round. **Nothing in this design is
undecided any more.**

25. **Warrior rage: option (b) — lower the income and add decay.**
    Swing **12 → 8** at all five sites, hit taken **4 → 3**, and **5 rage/s
    decay out of combat** on the existing `grug_core.in_combat` window.
    *(Answers ruling 16's finding. This is a `classes.md` §3 tuning change,
    not WP11's — §7 task 8 carries it for the WP11 / mob-pressure round, with
    option (a) — raise Mighty Blow to 35 and Hamstring to 15 — recorded there
    as the fallback if (b) overshoots and leaves the Warrior starved.)*
26. **The movement aggregator combines additively, per axis, with one clamp.**
    `clamp(1 + Σ, 0.1, 1.5)` for speed and for jump; a root or an exclusive
    hold takes precedence over the sum. *(§3.9 and
    `docs/research/mob-pressure-task-card.md` §4b already describe it; the
    ruling makes the recommendation binding.)*
27. **The Scout's trees are Quarry and Veil.** *(The names used throughout
    §2.7, §2.8 and [scout.md](scout.md).)*
28. **A bow's damage is `weapon damage + floor(Dex/10)`**, through a new
    `grug_classes.get_ranged_bonus` beside `get_melee_bonus`
    (`grug_classes/stats.lua:34-36`). *(One accessor, and one sentence added
    to `combat_stats.md` §2 — §7 task 9. It is what makes the Scout's
    Dexterity-led growth mean something.)*
29. **Historical ruling: Sprint is +25 % for 10 s on a 300 s cooldown.**
    **The user amended the speed to +50% on 2026-09-20; duration, cooldown
    and the existing movement cap remain unchanged.** *(The amended value
    puts a sprinting Scout at 6.0 nodes/s against
    the ordinary aggressive band's 4.6, which ruling 10 permits and which
    **confirms §7 task 1**: `mounts.md` §3.1 and `combat_stats.md` §3 must
    record the exception.)*

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
| 4 | `progression.md main:36-37` "**Respec at the class trainer for gold**, price rising with level — repeatable per-character gold sink and the class trainer's purpose", together with the former matching text in `economy.md`, `items_crafting.md` and `world.md`. All living sections now state the no-trainer rule. |
| 5 | revision 1's naming open decision, for talents |
| 7 | `classes.md main:466-470` "**Poison → arrives with the Rogue in Phase 2** (noted 2026-08-08). Poison is intended as the **Rogue's signature damage type** … and the Rogue is the Phase 2 class" — the Phase-2 Rogue is **superseded by the Scout**, and with it the poison plan. The bullet is now `classes.md:475-487` on this branch and quotes its own retired text. |

### 5.3 Where each correction is made

One commit per file, this lane's files only:

Line numbers below follow the preamble's convention: `main:NNN` is the text as
it stood before this lane, the bare number is where it is on this branch.

| File | Correction |
|---|---|
| `docs/design/progression.md` | §2's cadence, tree-size and capstone bullets (`main:28-37`, now `:30-52`); the respec location; the pointer paragraph |
| `docs/design/combat_stats.md` | `main:14`'s "1 skill point per level", now `:13-20` |
| `docs/design/classes.md` | the pointer paragraph; the Phase-2 Rogue bullet (`main:466-470`, now `:470-482`) marked superseded by the Scout |
| `BACKLOG.md` | the WP11 row (`main:34`) and the respec-price note (`main:539-540`, now `:542-550`) |

The living sections of `economy.md`, `items_crafting.md` and `world.md` have
since been corrected. `docs/research/post-wp40-readiness.md` is a historical
readiness record rather than current design authority.

---

## 6. Closed decision record

**No open decisions as of 2026-09-16.** Six rounds of rulings closed all
thirteen questions of revision 1 and the five that survived into revision 2;
§5 carries each with its ruling text, and §7 carries remaining implementation
work.

The heading stays for whatever the first playtest raises. When something new
goes here it should carry, as the user's meta-instruction of 2026-09-16
requires, **why it is open** — not only what the options are.

For the record, the five items this section held until the sixth round, and
where their answers now live:

| Was open | Decided by | Now in |
|---|---|---|
| Warrior rage calibration | ruling 25 — option (b), lower income and add decay | §2.2's note, §7 task 8 |
| the movement aggregator's arithmetic | ruling 26 — additive per axis, one clamp | §3.9 |
| the Scout's tree names | ruling 27 — Quarry / Veil | §1.1, §2.7, §2.8 |
| what feeds a bow's damage | ruling 28 — `weapon damage + floor(Dex/10)` | [scout.md](scout.md) §1, §7 task 9 |
| Sprint's percentage and cooldown | user amendment 2026-09-20 — +50 % / 10 s / 300 s | [scout.md](scout.md) §2, §7 task 1 |

---

## 7. Decided, but needing an edit outside this lane

Not decisions — **tasks**. Each is settled design that this lane may not
write, because the file belongs to somebody else or because it is code. They
are listed so that the merge does not leave the repo contradicting itself.

| # | Task | Why it cannot be done here |
|---|---|---|
| 1 | Amend `mounts.md` §3.1's pillar paragraph and `combat_stats.md` §3 to say the 4.4 > 4.0 inequality holds **except** for named, long-cooldown skills, of which Sprint is the first at **+50 % for 10 s every 300 s**; the Swiftness Draught's +8 % stays as it is | rulings 10 and 29 decided it; neither file is this lane's |
| 2 | Implement the remaining Mage crit-cap override without replacing Round 11's delivered Unbroken armor path or Scout dodge-cap override | the common cap rule is decided and documented; the remaining consumer belongs to X3 |
| 4 | Correct the five shipped comments that assume a class change (`grug_inventory/equipment.lua:57`, `:501`, `:579`, `grug_core/combat.lua:110`, `grug_abilities/init.lua:1775-1776`) and remove the `/class` registration at `grug_classes/selection.lua:594-595` — **not** the `:554-592` helper, which `/race` still needs | ruling 20 decided it; it is code, and this lane is docs-only (§3.10 lists the sites) |
| 5 | Rename the two remaining "Holy tree" mentions to Mercy — the Renew row at `classes.md:464` and the comment at `mods/PLAYER/grug_abilities/kits.lua:650` | bookkeeping after ruling 5's tree names; one is code |
| 7 | Fix three drifted citations **into** `mods/ENTITIES/mobs/api.lua`, held by three other files: `mounts.md:165` points at api.lua 2525-2526 where the line is **2531**, and the comments at `grug_mobs/golem.lua:67` and `grug_mobs/skeleton_archer.lua:65` both point at api.lua 2249 where the line is **2366** | found while writing `docs/research/mob-pressure-task-card.md`, which carries them; two are code comments |
| 8 | **Re-tune Warrior rage** (ruling 25): swing **12 → 8** at all five `add_rage` sites (`grug_abilities/init.lua:939`, `:950`, `:966`, `:1915`, `:2099`), hit taken **4 → 3** (`:2109-2110`), and a **5 rage/s out-of-combat decay** on the existing `grug_core.in_combat` window (read at `:2201`). `classes.md` §3's table and its "+12 rage per auto-hit" tuning note (`:418`, `:430`) move with it. **Fallback if (b) overshoots**: leave the income alone and raise the prices instead — Mighty Blow 25 → 35, Hamstring 10 → 15 | it is `classes.md` §3 tuning plus code, for the WP11 / mob-pressure round; WP11's talents must then be re-checked against whichever number lands, because Stoke, Heavy Hand and Broadstroke all assume rage is a limiter |
| 9 | **Delivered in Round 11:** the ranged damage term from ruling 28, `weapon damage + floor(Dex/10)`, published as `grug_classes.get_ranged_bonus` beside `get_melee_bonus` | implemented with the Scout consumer |
