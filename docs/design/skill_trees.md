# Skill Trees (Talents) — WP11

**Decided design, revision 2 of 2026-09-16, implemented.** Four classes each
have two trees with two chains. Characters gain 30 points, each tree contains
28 ranks, and one capstone is reachable. The model, the talent consumers, the
Talents page, the respec and the level-up notice shipped in Rounds 11 and 12
and on 2026-09-17 (WP11 lanes X1–X4, the Scout's trees in Round 11); Round 35
made every damage and armour talent level-proof (§2.10) and applied the
user's picks from a review of all talents (2026-10-05); Round 36 added the
support factor. The tables below carry the current values.

- "Ruling N" means the user's rulings of 2026-09-16, summarised in §5.
- Code is cited by symbol (a function, a registration, a field), never by
  line number.
- The delivery history — the old citation layer at `70dda602`, the talent
  name audit, the KAT, the file table, the lanes, the full ruling texts with
  what each replaced and the closed task list — is archived in the
  [WP11 delivery record](../archive/design/skill-trees-wp11-delivery.md).

Companion file: [scout.md](scout.md), the fourth class (kit, armour, bow,
stealth deferred). Its two trees live here in §2.7/§2.8 so that all four
classes' talent tables stay in one place under one arithmetic.

---

## 1. The shape

### 1.1 Four classes, two trees, two chains per tree

Four classes ship; the fourth, **Scout**, was delivered in Round 11 (ruling 7,
[scout.md](scout.md)). Each class has two trees, and **each tree holds two
rough playstyle directions, called chains** (ruling 2). A chain is a straight
line of four talents: two numeric, then a keystone, then either the capstone
or a finisher.

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

The tree names are decided: ruling 5 kept Bulwark, Ruin, Ember, Rime, Mercy
and Reckoning, ruling 27 named Quarry and Veil. The Priest's healing tree is
**Mercy** (formerly "Holy"; renamed everywhere). Talent names follow §2.11.

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
a chain, and the capstone is **one rank** (ruling 17): a capstone is one
strong effect or one replacement, and what gates it is its chain plus the
points in the tree, not a ladder of its own — the variety ruling 2 asks for
is already carried by the 5/4/3 above it.

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
  The point count at level L is `floor(L / 2)`
  (`grug_classes.talent_points_at`); at level 60 that is **30 points**.
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
already has, or no button at all. §3.4 works the budget out per class: the
worst case is **6 of 8** keys for Warrior, Mage and Priest and **7 of 8** for
the Scout.

Death costs no XP (Round 18); dying never removes talent points.

### 1.4 Respec, and no class change (rulings 4, 20, 22)

- **Where: in the talent UI itself** (the Talents & Skills page, §3.5). There is no
  class trainer and no NPC (ruling 4).
- **What: a full reset.** Ruling 20 — a respec sets every rank to 0 and
  returns all 30 points. No partial or single-tree respec: one button, one
  price, nothing to argue about over which half was refunded.
- **Price (ruling 22):** **five minutes of measured reliable net solo income
  at the character's own bracket**, rounded by `economy.md` §4.1's rule, **and
  the first respec of a character is free**. Because bracket income rises on
  the same approximate ×2.5 tier index as everything else (`economy.md` §3),
  the price rises with level without a hand-written table. The free first
  respec is the safety net for a mis-clicked first point at level 2, when the
  character has no money at all. The six bracket prices are
  `grug_classes.RESPEC_PRICES`, listed in [economy.md](economy.md) §4 (the
  price owner) and checked by `tools/r29_e4/income.py --check`; the purchase
  is `grug_classes.buy_respec`, which takes the money before the reset.
- **There is no class change at all (ruling 20).** Not for players, and **not
  for admins**: "equipment would be a problem otherwise". A respec re-spends
  talents; nothing in the game changes a character's class (§3.10).
- **A level drop resets talents completely and for free** (ruling 20's
  simplest form): rather than blocking spends or refunding cheapest-first,
  the talent state is wiped and every point returned
  (`grug_classes.on_level_change_talents`). Only a direct `grug_xp.set_xp`
  call can lower a level; the `/xp` command only grants a positive amount.

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
    break a base inequality (mob 4.6 > player 4.0, a stat cap, immunity to
    roots); the **limit is stated in the same cell** and is the price.
- **Effect** is written in the vocabulary of `combat_stats.md` §1/§2/§4 —
  armor rating, crit chance, dodge chance, max HP, max mana, rage, spell
  power, threat, absorb, root and slow duration. **No talent introduces a new
  mitigation term**, and no talent introduces a new *mechanic*: every one is
  a number, a duration or a flag on machinery the game already runs.
- **Modifies** names the code site that reads the talent. **A kit table's
  `cooldown`, `charge`, `range` and `max_distance` fields are evaluated once
  at load time with no player in scope**, so talents that re-tune those hook
  a central per-player seam instead — §3.2 lists them. `kits.lua` is
  `grug_abilities/kits.lua`; "the Taunt cast" means that ability's
  registration there.
- **Key** is the effect key in `grug_classes/talents.lua` (§3.2).

### 2.1 Warrior — Bulwark

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|---|
| 1 | **Ironbound** | Wall | 1 | 5 | — | armor rating +3 / 6 / 9 / 12 / 15 % of `K(L)` (§2.10): +1.5 … 7.5 at level 60, about +1 … 5 at level 30 | the armor-rating aggregate, `grug_core.get_armor_rating` | `armor_percent_add` |
| 2 | **Weathered** | Wall | 2 | 4 | — | max HP +2.5 / 5 / 7.5 / 10% of the class base pool | `grug_classes.get_pool_breakdown` | `max_hp_percent_add` |
| 3 | **Hold Ground** *(keystone)* | Wall | 3 | 3 | **new skill** ‼ | cast, 25 rage, self; absorbs 20% / 30% / 40% of the class-neutral base pool for 8 s, **and for those 8 s the Warrior cannot be rooted or slowed**. *Limit: 8 s, **60 s cooldown**.* | new (`hold_ground` in `kits.lua`); `grug_core.add_absorb`; the immunity is the movement aggregator's (`grug_core.set_move_immunity`, §3.9) | `hold_ground_absorb` |
| 4 | **Unbroken** *(capstone)* | Wall | 4 | **1** | **effect** ‼ | permanently multiplies total armor rating by **1.65** after the Warrior commits 21 points to Bulwark. The first hit in **180 s** that would take the Warrior below 20% max HP then adds **33 % of `K(L)` as rating after the multiplier** (about 15 at level 50, §2.10) for 8 s. The universal 70% reduction cap remains, so the capstone counts most against stronger foes. | `grug_core.get_armor_rating` (the ×1.65 is `grug_core.PROTECTION_ARMOR_MULTIPLIER` while ranked) plus the low-HP trigger in `talents.lua`'s hp-change hook | `armor_rating_add_low_hp` |
| 5 | **Spite** | Anvil | 1 | 5 | — | +1 / 2 / 3 / 4 / 5 rage per hit taken (base 3) | the hit-taken rage grant in `grug_abilities/init.lua` (its hp-change hook) | `rage_per_hit_taken_add` |
| 6 | **Affront** | Anvil | 2 | 4 | — | tank-ability threat ×3 → ×3.25 / 3.5 / 3.75 / 4.0 | casts in `grug_core.deal_ability_damage`; authoritative swings in `grug_abilities/init.lua`'s `attempt_swing` | `threat_mult_add` |
| 7 | **Bellow** *(keystone)* | Anvil | 3 | 3 | **replaces Taunt** | Taunt stops being single-target: it forces **every** hostile mob within 6 / 8 / 10 m onto the Warrior for its 3 s, same key, same 8 s cooldown | the Taunt cast, run over a hostile-radius loop | `taunt_radius` |
| 8 | **Grudge** | Anvil | 4 | 3 | — | Taunt cooldown 8 s → 7 / 6 / 5 s | `grug_abilities.effective_cooldown` (Taunt's `cooldown_talent`) | `taunt_cooldown_sub` |

Hold Ground is Bulwark's one new button and the tree's one rule-breaker
besides the capstone. Its break is the useful one for a tank: a Warrior who
has committed to holding a spot cannot be kited off it for eight seconds. Its
absorb stacks with the Priest's Shield and every other absorb (ruling 23,
§3.11).

Weathered's 2.5% per rank (Round 35; 1.5% before, the conversion of the
former flat ranks) adds 5 HP at its first reachable rank at level 12.

### 2.2 Warrior — Ruin

**Ruling 19 removes Hamstring from the Warrior's base kit** so that every
class starts with Strike plus three, and it says the skill "may return later
through a keystone". It does: **Hamstring is Ruin's new-skill keystone**, one
of the keystones whose ability was registered before WP11 (the `hamstring`
registration in `kits.lua`, `talent_gated` like Mend's). That makes
Broadstroke a replacement rather than a registration, and it cuts the Lash
chain so that nothing below tier 3 modifies a skill the player may not have
yet.

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|---|
| 1 | **Heavy Hand** | Hammer | 1 | 5 | — | Mighty Blow ×1.5 → ×1.6 / 1.7 / 1.8 / 1.9 / 2.0 weapon damage | the Mighty Blow proc in `kits.lua` | `mighty_blow_multiplier_add` |
| 2 | **Stoke** | Hammer | 2 | 4 | — | +1 / 2 / 3 / 4 rage per landed authoritative swing (base 8) | the swing rage in `grug_abilities/init.lua` (`swing_rage`) and its authoritative callers | `rage_per_swing_add` |
| 3 | **Broadstroke** *(keystone)* | Hammer | 3 | 3 | **replaces Mighty Blow** | Mighty Blow also strikes every other hostile within 3 m for **half** its total, rounded down, at ×3 threat — the game's first melee cleave, on the key Mighty Blow already occupies | the Mighty Blow proc plus a hostile-radius loop | `mighty_blow_cleave` |
| 4 | **Ruination** *(capstone)* | Hammer | 4 | **1** | **effect** ‼ | a landed Mighty Blow grants **15 s** of crit chance **+20 percentage points** with the 30 % crit cap raised to **50 %**. *Limit: 15 s, **60 s cooldown** on the trigger.* | `grug_classes.get_crit_chance_raw` and the cap in `grug_classes.get_crit_chance` | `crit_chance_add_window`, `crit_cap_override` |
| 5 | **Keen Edge** | Lash | 1 | 5 | — | +2 / 4 / 6 / 8 / 10 percentage points crit chance (30 % cap holds) | `grug_classes.get_crit_chance_raw` | `crit_chance_add` |
| 6 | **Onset** | Lash | 2 | 4 | — | Charge cooldown 10 s → 9 / 8 / 7 / 6 s | `grug_abilities.effective_cooldown` (Charge's `cooldown_talent`) | `charge_cooldown_sub` |
| 7 | **Hamstring** *(keystone)* | Lash | 3 | 3 | **new skill** *(registered before WP11)* | the shipped ability: 10 rage, a 6 s charge, and on a charged proc a 50 % slow for 5 s exactly as `classes.md` §3 specifies. Ranks 2 and 3 lengthen the slow to **6 / 7 s** | the Hamstring proc in `kits.lua`; the grant gate is its `talent_gated = true` | `hamstring_slow_add` |
| 8 | **Tendon Cut** | Lash | 4 | 3 | ‼ | Hamstring's charged proc **roots** for 2 / 2.5 / 3 s before its slow begins — a root off an ordinary swing. *Limit: **12 s internal cooldown**, independent of the charge.* | the Hamstring proc, using the shared root machinery (`grug_mobs.root` on mobs, `grug_core.set_root` on players) | `hamstring_root` |

Ruin's chain totals are the asymmetry §1.2 describes: Hammer
`5 + 4 + 3 + 1 = 13` because it carries the one-rank capstone, Lash
`5 + 4 + 3 + 3 = 15`.

Broadstroke needs no new timing machinery: it rides the authoritative swing
exactly as Mighty Blow already does (`classes.md` §2b), and Mighty Blow's rage
cost is what keeps it off every swing. Tendon Cut is Ruin's one rule-breaker
besides the capstone, on a timer deliberately independent of the charge.

**Charge is no longer the untouched ability.** Onset re-tunes its cooldown,
and Affront (§2.1) raises the threat multiplier it passes (Charge's
`threat_mult = 3`, read in `grug_core.deal_ability_damage`). Its 12 m reach,
its 12 % of a base hit and its 15 rage are untouched by any talent.

**Rage is a limiter.** Stoke adds to it, Heavy Hand and Broadstroke spend it;
all three are calibrated against the rage ledger of ruling 25 (`classes.md`
§3: +8 per landed swing, +3 per hit taken, −5/s out of combat).

### 2.3 Mage — Ember

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|---|
| 1 | **Tinder** | Blaze | 1 | 5 | — | Fireball's `baseline weapon + spell power` raw value gains 4 / 8 / 12 / 16 / 20 % of a base hit before the damage fit (§2.10) | the Fireball values in `kits.lua` | `fireball_damage_add` |
| 2 | **Firebrand** | Blaze | 2 | 4 | — | +2 / 4 / 6 / 8 percentage points crit chance (30 % cap holds) | `grug_classes.get_crit_chance_raw` | `crit_chance_add` |
| 3 | **Brand** *(keystone)* | Blaze | 3 | 3 | **replaces Fireball** | Fireball's impact splashes `6 / 9 / 12 % of a base hit + spell power / 2` to every other hostile within 2 m. Same key, same 6% base-mana cost, same 1 s cast interval, same homing flight | the Fireball projectile's on-hit plus its radius loop | `fireball_splash` |
| 4 | **Whitehot** *(capstone)* | Blaze | 4 | **1** | **effect** ‼ | the first Fireball that **crits** starts an 8 s window in which Fireball costs **3% instead of 6% base mana** and deals **+30 % of a base hit**. *Limit: 8 s, **60 s cooldown** on the trigger.* | the central cost seam `grug_abilities.cost_for` and the Fireball values | `whitehot_window`, `whitehot_damage` |
| 5 | **Deep Well** | Cinder | 1 | 5 | — | max mana +3 / 6 / 9 / 12 / 15 % | `grug_classes.get_pool_breakdown` | `max_mana_percent_add` |
| 6 | **Far Cast** | Cinder | 2 | 4 | — | Fireball acquisition range 20 m → 21.5 / 23 / 24.5 / 26 m at release; no later range expiry | `grug_abilities.get_range` (Fireball's `range_talent`) and the current combat ray at release; the flight distance at Fireball's spawn call | `fireball_range_add` |
| 7 | **Cinderfall** *(keystone)* | Cinder | 3 | 3 | **new skill** | cast, 12% base mana, 10 s cooldown, 20 m; a burst at the first solid contact or actor the crosshair ray meets, dealing `15 / 20 / 25 % of a base hit + spell power` to every hostile within 3 m of it | new (`cinderfall` in `kits.lua`); `grug_core.combat_ray` plus the radius loop | `cinderfall_damage` |
| 8 | **Ashfall** | Cinder | 4 | 3 | — | Cinderfall's radius 3 m → 4 / 5 / 6 m | the Cinderfall registration | `cinderfall_radius_add` |

Far Cast increases acquisition reach only. Once released, Fireball follows its
locked target for the launch-distance-derived flight duration, even if the target
moves beyond that reach (see `combat_stats.md`, “Hostile casts and projectiles”). Ember takes **no** rule-breaker
besides its capstone — see §2.9's note on the bounded pass.

### 2.4 Mage — Rime

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|---|
| 1 | **Deep Chill** | Frost | 1 | 5 | — | Ice Nova root 4 s → 4.2 / 4.4 / 4.6 / 4.8 / 5.0 s | the Ice Nova cast in `kits.lua` | `ice_nova_root_add` |
| 2 | **Hoarfrost** | Frost | 2 | 4 | — | Ice Nova follow-up slow 3 s → 4 / 5 / 6 / 7 s (the 50 % stays) | the Ice Nova cast | `ice_nova_slow_add` |
| 3 | **Frostbind** *(keystone)* | Frost | 3 | 3 | **replaces Ice Nova** | Ice Nova stops being self-centred: it is cast at the pointed hostile up to 20 m away and roots everything within 3 / 4 / 5 m **of the target**. Same key, same 10% base-mana cost, same 12 s cooldown — a control tool instead of a panic button | the Ice Nova cast body and its radius origin | `ice_nova_ranged` |
| 4 | **Rimebite** *(capstone)* | Frost | 4 | **1** | **effect** | Ice Nova adds `25 % of a base hit + spell power / 2` to its quarter-Fireball baseline before spell scaling, once per accepted hit | the Ice Nova cast | `control_damage_add` |
| 5 | **Cold Focus** | Ward | 1 | 5 | — | in-combat mana regeneration ×1.4 / ×1.8 / ×2.2 / ×2.6 / ×3.0 (the base rate is `max(0.25 × (1 + 0.15 × level), 0.0025 × maximum mana)` mana/s, combat_stats.md §5) | `grug_abilities.mana_regen_rate` | `combat_mana_regen_add` |
| 6 | **Quick Step** | Ward | 2 | 4 | — | Blink cooldown 15 s → 13.5 / 12 / 10.5 / 9 s | `grug_abilities.effective_cooldown` (Blink's `cooldown_talent`) — **not** the registration constant | `blink_cooldown_sub` |
| 7 | **Glacial Ward** *(keystone)* | Ward | 3 | 3 | **new skill** | cast, 10% base mana, 30 s cooldown, self; absorbs 10% / 15% / 20% of the class-neutral base pool times the support factor (gear Intelligence) for 10 s | new (`glacial_ward` in `kits.lua`); `grug_core.add_absorb` | `glacial_ward_absorb` |
| 8 | **Far Step** | Ward | 4 | 3 | — | Blink distance 10 m → 12 / 14 / 16 m | the Blink cast body (player in scope) | `blink_distance_add` |

Rime also takes no rule-breaker besides its capstone, and its capstone does
not break one either — Rimebite is simply a strong effect. Glacial Ward and
Shield stack like every absorb (ruling 23, §3.11).

### 2.5 Priest — Mercy

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|---|
| 1 | **Gentle Hand** | Balm | 1 | 5 | — | Heal's 25% base-pool share gains +1 / 2 / 3 / 4 / 5 percentage points | the Heal cast in `kits.lua` | `heal_add` |
| 2 | **Quiet Steps** | Balm | 2 | 4 | — | heal threat factor 0.5 → 0.45 / 0.40 / 0.35 / 0.30 (`combat_stats.md` §4) | `grug_core.add_heal_threat` (against `grug_core.HEAL_THREAT_FACTOR`) | `heal_threat_factor_sub` |
| 3 | **Mend** *(keystone)* | Balm | 3 | 3 | **new skill** *(registered before WP11)* | the shipped ability, granted at rank 1 exactly as `classes.md` §5 specifies (6% base mana, 8 s cooldown, 8% of the base pool times the support factor every 3 s for 12 s); ranks 2 and 3 raise the tick to 9% and 10% | the Mend cast in `kits.lua`; the grant gate is `talent_gated = true` | `mend_tick_add` |
| 4 | **Hearten** *(capstone)* | Balm | 4 | **1** | **replaces Heal** | Heal also heals every **other** ally within 8 m for **65 %** of the amount. Same key, same 8% base-mana cost, same 4 s cooldown — the Priest's group heal, without a group-heal button | the Heal cast plus its radius loop | `heal_splash` |
| 5 | **Warding Faith** | Aegis | 1 | 5 | — | Shield's 25% base-pool share gains +1 / 2 / 3 / 4 / 5 percentage points | the Shield cast in `kits.lua` | `shield_absorb_add` |
| 6 | **Deep Reserve** | Aegis | 2 | 4 | — | max mana +3 / 6 / 9 / 12 % | `grug_classes.get_pool_breakdown` | `max_mana_percent_add` |
| 7 | **Turn Aside** *(keystone)* | Aegis | 3 | 3 | **replaces Shield** | while the shield holds (at most its 15 s), its target's dodge chance is +10 / 15 / 20 percentage points, **inside** the 30 % cap. Same key, same cost — the shield now buys avoidance as well as absorption | the Shield cast (an absorb modifier, `dodge_percent`) and `grug_classes.get_dodge_chance_raw` | `dodge_chance_window` |
| 8 | **Second Skin** | Aegis | 4 | 3 | — | Shield cooldown 10 s → 9 / 8 / 7 s (Round 35; it lengthened the shield before, which a consumed shield never used) | `grug_abilities.effective_cooldown` (Shield's `cooldown_talent`) | `shield_cooldown_sub` |

Mend is Mercy's **keystone**, registered before WP11 and `talent_gated`;
`classes.md` §5 lists its base values.

### 2.6 Priest — Reckoning

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Modifies | Key |
|---|---|---|---|---|---|---|---|---|
| 1 | **Sharpened Word** | Word | 1 | 5 | — | Smite's `1.5 × (baseline weapon + spell power)` raw value gains 4 / 8 / 12 / 16 / 20 % of a base hit before the damage fit (§2.10) | the Smite values in `kits.lua` | `smite_damage_add` |
| 2 | **Swift Word** | Word | 2 | 4 | — | Smite cooldown 2 s → 1.9 / 1.8 / 1.7 / 1.6 s | `grug_abilities.effective_cooldown` (Smite's `cooldown_talent`) — **not** the registration constant | `smite_cooldown_sub` |
| 3 | **Word of Ruin** *(keystone)* | Word | 3 | 3 | **new skill** | cast, 8% base mana, 12 s cooldown, 20 m; `18 / 24 / 30 % of a base hit + spell power` damage, healing the Priest for 50 % of it | new (`word_of_ruin` in `kits.lua`); `grug_core.deal_ability_damage` returns the post-crit amount, healed back with `grug_core.heal_player(…, {no_crit = true})` | `word_of_ruin_damage` |
| 4 | **Last Word** *(capstone)* | Word | 4 | **1** | **effect** ‼ | while the Priest is below 25 % max HP, Word of Ruin's drain heals for **150 %** of the damage dealt — above the 100 % the pipeline otherwise allows — and the trigger resets Word of Ruin's cooldown, so a second cast drains inside the window. *Limit: 12 s per trigger, **180 s cooldown**.* | the drain half of the Word of Ruin registration | `drain_ratio_override` |
| 5 | **Hard Faith** | Wrath | 1 | 5 | — | +2 / 4 / 6 / 8 / 10 percentage points crit chance (30 % cap holds) | `grug_classes.get_crit_chance_raw` | `crit_chance_add` |
| 6 | **Warded Wrath** | Wrath | 2 | 4 | — | while the Priest carries an absorb shield, Smite deals `+4 / 8 / 12 / 16 % of a base hit` | the Smite values, gated on `grug_core.get_absorb(user) > 0` | `smite_damage_while_shielded_add` |
| 7 | **Recompense** *(keystone)* | Wrath | 3 | 3 | **replaces Smite** | Smite costs 6% instead of 5% base mana and grants the Priest an absorb of 6% / 9% / 12% of the class-neutral base pool times the support factor on a landed cast at most once every 6 s (internal cooldown, Round 35), refreshing rather than stacking. Same key — the solo nuke becomes the solo sustain | Smite settlement, `grug_abilities.cost_for` and `grug_core.add_absorb` | `smite_absorb` |
| 8 | **Hardened** | Wrath | 4 | 3 | — | max HP +2 / 4 / 6% of the class base pool | `grug_classes.get_pool_breakdown` | `max_hp_percent_add` |

Word of Ruin's drain is specified as "50 % of the damage dealt **before the
target's armor**": `deal_ability_damage` returns the amount the ability
published, taken before the central modifier applies armor and the absorb
shield to a *player* target. Against a mob it is exactly what landed.

Hardened's 2% per rank (Round 35; 0.3% before, the conversion of a former flat
+4 HP that left it a dead pick) adds 28 HP at its first reachable rank at level 42.

### 2.7 Scout — Quarry (implemented in Round 11)

The Scout's kit, resource, armour, bow and the **deferred stealth work** are
[scout.md](scout.md); its two trees are here so that §1.3's arithmetic covers
all four classes. The Scout's talents are read in `grug_abilities/scout.lua`
and `grug_classes/scout.lua`, so the Modifies column is dropped.

Ruling 12 makes the Scout **as simple as possible**: no invisibility in
version 1, no poison, no traps, and every talent built from a mechanic the
game already runs.

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Key |
|---|---|---|---|---|---|---|---|
| 1 | **Strong Draw** | Draw | 1 | 5 | — | Loose damage `+4 / 8 / 12 / 16 / 20 % of a base hit`, before the draw multiplier | `loose_damage_add` |
| 2 | **Cold Eye** | Draw | 2 | 4 | — | +2 / 4 / 6 / 8 percentage points crit chance (30 % cap holds) | `crit_chance_add` |
| 3 | **Twin Shot** *(keystone)* | Draw | 3 | 3 | **replaces Loose** | a full draw looses two arrows, the second for `40 / 50 / 60 %` damage; costs 2 arrows. Same key | `loose_second_arrow` |
| 4 | **Longshot** *(capstone)* | Draw | 4 | **1** | **replaces Loose** | Loose's range 25 m → **33 m**, and a hit landed beyond 25 m deals **+11 % of a base hit** | `loose_range_add`, `longshot_damage_add` |
| 5 | **Quiver** | Ranging | 1 | 5 | — | Loose's arrow is not consumed 10 / 20 / 30 / 40 / 50 % of the time | `arrow_refund_chance` |
| 6 | **Fletching** | Ranging | 2 | 4 | — | Loose's draw time 2.5 s → 2.375 / 2.25 / 2.125 / 2.0 s (subtracts 0.125 / 0.25 / 0.375 / 0.5 s before the draw-speed affix divides; 0.5 s floor) | `draw_time_sub` |
| 7 | **Pinning Shot** *(keystone)* | Ranging | 3 | 3 | **new skill** ‼ | cast, **12% base mana + 1 arrow**, 25 m; roots the pointed hostile for 2 / 2.5 / 3 s — a root at bow range, which no class has. *Limit: **30 s cooldown**.* | `pinning_root` |
| 8 | **Shifting Weight** | Ranging | 4 | 3 | — | +2 / 4 / 6 percentage points dodge chance | `dodge_chance_add` |

### 2.8 Scout — Veil (implemented in Round 11)

| # | Talent | Chain | Tier | Ranks | Kind | Effect | Key |
|---|---|---|---|---|---|---|---|
| 1 | **Fine Edge** | Blade | 1 | 5 | — | +4 / 8 / 12 / 16 / 20 % of a base hit on a landed authoritative swing | `melee_damage_add` |
| 2 | **Deep Focus** | Blade | 2 | 4 | — | max resource +3 / 6 / 9 / 12 % | `max_mana_percent_add` |
| 3 | **Opening** *(keystone)* | Blade | 3 | 3 | **new skill** | swing, **15% base mana**, 12 s charge; on a landed swing taken from **behind** the target (a yaw comparison, no new state) or at a rooted or stunned target (Round 35), `floor(weapon damage × 2.2 / 2.5 / 2.8) + melee bonus` | `opening_multiplier` |
| 4 | **Follow Through** | Blade | 4 | 3 | — | Opening's charge 12 s → 10 / 8 / 6 s | `opening_charge_sub` |
| 5 | **Light Step** | Shadow | 1 | 5 | — | +1 / 2 / 3 / 4 / 5 percentage points dodge chance | `dodge_chance_add` |
| 6 | **Slip Away** | Shadow | 2 | 4 | — | Sidestep's cooldown 30 s → 26 / 22 / 18 / 14 s | `sidestep_cooldown_sub` |
| 7 | **Shake Loose** *(keystone)* | Shadow | 3 | 3 | **replaces Sidestep** ‼ | Sidestep also clears every slow and root on the Scout, and for its 4 s the Scout cannot be slowed or rooted again. Same key. *Limit: 4 s, on Sidestep's own **30 s cooldown** (and Slip Away shortens it, which is the trade).* | `root_slow_immunity` |
| 8 | **Untouchable** *(capstone)* | Shadow | 4 | **1** | **effect** ‼ | when the Scout drops below 30 % max HP: dodge chance **+25** percentage points **and the 30 % dodge cap rises to 55 %**, for 6 s. *Limit: 6 s, **180 s cooldown**.* | `dodge_chance_window`, `dodge_cap_override` |

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
| Capstones (never a new skill, **one rank** — ruling 17) | 1 | 2 | **8** |
| …effects | — | — | **6** (Unbroken, Ruination, Whitehot, Rimebite, Last Word, Untouchable) |
| …replacements | — | — | **2** (Hearten, Longshot) |

**New-skill keystones: 8 across all four classes**, one per tree — Hold
Ground, Hamstring, Cinderfall, Glacial Ward, Mend, Word of Ruin, Pinning
Shot, Opening. Mend and Hamstring were registered before WP11, Pinning Shot
and Opening came with the Scout in Round 11, and WP11 added Hold Ground,
Cinderfall, Glacial Ward and Word of Ruin. **Sixteen of the twenty-four
keystones and capstones** — the ten replacements and the six effects — need
no registration at all: a replacement deepens a button the player already
knows instead of adding another.

**Hotbar budget** (ruling 13's second half, and ruling 19's): a new skill is
one per tree and no build reaches more than one per tree, so **no build
exceeds base kit + 2 keys** — and since ruling 19 takes Hamstring out of the
Warrior's base kit, **Warrior, Mage and Priest start with Strike + 3 and top
out at 6 of 8**, the Scout at 7 of 8. §3.4 works it out per class.

**Rule-breakers** (ruling 10), all with their limit in the cell:

| Tree | Rule-breaker besides the capstone | Capstone breaks a rule? |
|---|---|---|
| Bulwark | **Hold Ground** — root/slow immunity, 8 s, 60 s cd | yes — Unbroken permanently multiplies total rating ×1.65 after the exclusive 21-point commitment; its emergency window (33 % of `K(L)` as rating) lasts 8 s / 180 s |
| Ruin | **Tendon Cut** — root off a swing, 12 s internal cd | yes — Ruination, crit cap → 50 %, 15 s / 60 s |
| Ember | none | yes — Whitehot, half mana cost, 8 s / 60 s |
| Rime | none | no |
| Mercy | none | no |
| Reckoning | none | yes — Last Word, drain > 100 % and a Word of Ruin reset, 12 s / 180 s |
| Quarry | **Pinning Shot** — a root at 25 m, 30 s cd | no (Longshot is a plain replacement) |
| Veil | **Shake Loose** — root/slow immunity, 4 s, 30 s cd | yes — Untouchable, dodge cap → 55 %, 6 s / 180 s |

The pass is bounded at **at most** one per tree, not exactly one, and it was
used **twice in the six original-class trees**. Rime, Mercy and Ember took
none because their fantasies did not need one, and leaving headroom is
cheaper than inventing breaks.

**Effect keys**, counted from the code (`grug_classes/talents.lua` and
`scout_talents.lua`): every talent carries at least one key; **68 key cells,
60 distinct**. Four keys are shared across classes — `crit_chance_add` (all
four), `max_mana_percent_add` (Mage, Priest, Scout), `max_hp_percent_add`
(Warrior, Priest) and `dodge_chance_window` (Turn Aside, Untouchable) — and
`dodge_chance_add` appears twice, both on the Scout (Shifting Weight, Light
Step). Every key must be in the closed vocabulary (§3.1).

### 2.10 Two consequences of touching shipped numbers

**The decided ability tables are *base* values.** `classes.md` §3–§5 state
their numbers flatly (Mighty Blow is exactly floor(weapon damage × 1.5),
Hamstring charges 6 s and slows for 5 s, Taunt runs 8 s, Ice Nova roots 4 s
then slows 3 s, Blink teleports 10 m, Smite has a 2 s cooldown, Heal uses 25%
of the base pool, Shield lasts 15 s). **Eighteen talents re-tune exactly
these numbers.** Improving existing buttons is what talents are for, so those
tables are the **untalented baseline** (`classes.md` says so), and a talented
Taunt is the design working, not a bug.

**Level-proof values (Round 35, user ruling 2026-10-05).** A flat "+N" added
before the damage scalar fades with level (Tinder's +5 was +43 % of a
Fireball at level 10 and +11 % at level 60). Every damage and armour talent
therefore states a **percentage of a level reference**, and
`grug_classes.get_talent_bonus` returns the amount at the player's level
(`talent_level_amount`, the keys in `TALENT_LEVEL_SCALED_KEYS`), so each
consumer still adds it where it added the flat value:

- **damage — % of a base hit:** `B(L)` of the damage fit
  (`grug_core.baseline_melee_total`, `combat_stats.md` §2), the raw same-level
  hit before the scalar; a same-level Fireball without gear is exactly 100 %,
  and after the scalar a base hit is one eighth of the base pool (17 / 95 /
  337 damage at levels 10 / 30 / 60). Tinder, Brand, Whitehot, Cinderfall,
  Rimebite, Sharpened Word, Warded Wrath, Word of Ruin, Strong Draw, Longshot,
  Fine Edge; Charge's base damage (12 %) follows the same rule;
- **armour — % of `K(L)`** at the character's own level, the rating that halves
  a same-level hit: Ironbound and Unbroken's emergency rating.

The amounts do not grow with gear, like the flat values they replace, so the
itemization ceiling of `combat_stats.md` §2 stays separate. Each percentage
kept the former flat value at the middle of the levels where the talent can
be held (tier 1 level 30, tier 2 35, tier 3 45, tier 4 50); the user then
raised Whitehot (16 → 30 %) and Rimebite (13 → 25 %). The talent tooltip
shows every rank's amount at the viewer's level (damage after the scalar,
before crit). The derivation and tables are in `tools/r35_b/numbers.py`.

Healing and absorb talents instead add percentage points to the ability's
class-neutral base-pool share; the support factor (gear Intelligence over a
base hit, `combat_stats.md` §2, Round 36) multiplies the result and
`scale_player_value` remains an identity. Applying the damage scalar to
those completed support values would double their level growth.

**Nine talents deliberately break a decided rule, and every one states its
price.** Ruling 10 is what permits it — "skills may explicitly break the base
inequalities; that is what skills are for (Blink and a dodge roll already do).
The bigger the break, the stronger the limit, usually cooldown or duration."
All nine are listed in §2.9 with their limits — four rule-breakers besides a
capstone, and five capstones that break one. Two break a **cap**: Ruination
(crit → 50 % for 15 s every 60 s) and Untouchable (dodge → 55 % for 6 s). Unbroken instead
multiplies raw armor rating while preserving the universal 70% reduction cap.
Four
break an **immunity or control rule** (Hold Ground, Shake Loose, Tendon Cut,
Pinning Shot), one breaks a **resource cost** (Whitehot) and one a **healing
ratio** (Last Word). The Scout's base-kit Sprint is a tenth, and it is not a
talent — [scout.md](scout.md) §2 carries it.

`combat_stats.md` §2 owns the armor formula and the named Crit/Dodge cap
exceptions. Character shows resulting armor rating and Damage reduction (same-level);
Help explains Unbroken's multiplier and cap rules. Talents contains only build
selection, descriptions and purchases (Round 19). Talents that are *not* marked `‼` stay inside every cap, so
Turn Aside's +20 dodge is clamped at 30 % like any gear roll.

### 2.11 Names (rulings 5 and 21)

Every talent name passed the name audit of 2026-09-16 (ruling 5: talent names
must not remind of an existing game; ruling 21: the overall picture matters,
single common words are not protected). The tree names stay by ruling 5. Round
31 renamed the shipped abilities whose names matched another game's; the
current names are Heal, Shield and Mend (Priest) and Ice Nova (Mage). The
audit, its confidence labels and the names it recorded but kept are in the
[delivery record](../archive/design/skill-trees-wp11-delivery.md) section C.
New names follow AGENTS.md "Naming".

---

## 3. Data model and seams

### 3.1 Where talents live

`grug_classes` owns the talents: it owns the class registry and the per-player
derived stats every numeric talent touches, and both `grug_inventory` and
`grug_abilities` depend on it, so both read talents without a new dependency
edge.

- `grug_classes/talents.lua`: the registry, the 48 talents of Warrior, Mage
  and Priest as data, the point budget, both gate kinds, spend and respec,
  persistence, the timed-window table and the accessors.
- `grug_classes/scout_talents.lua`: the Scout's 16 talents.
- `grug_classes/talents_ui.lua`: the Talents & Skills page with the tree
  framework (§3.5) and the paid respec
  (`grug_classes.buy_respec`); for these `grug_classes` depends on `sfinv` and
  `grug_money`.

Registration mirrors `register_class`:

```lua
grug_classes.register_tree({
    id = "bulwark", class = "warrior", name = "Bulwark",
    chains = {"wall", "anvil"},          -- exactly two, ruling 2
    capstone_chain = "wall",             -- which chain carries the capstone
})

grug_classes.register_talent({
    id = "ironbound", tree = "bulwark", chain = "wall", tier = 1,
    name = "Ironbound",
    effects = {armor_percent_add = {3, 6, 9, 12, 15}},  -- one value per rank
})

grug_classes.register_talent({
    id = "hold_ground", tree = "bulwark", chain = "wall", tier = 3,
    keystone = true,                     -- exactly one per chain, tier 3
    ability = "hold_ground",             -- the grug_abilities id it grants
    effects = {hold_ground_absorb = {20, 30, 40}},
})
```

`register_talent` asserts the shape at load time the way `register_ability`
does: tier in 1..4, a keystone only in tier 3, a capstone only in tier 4 and
on its tree's capstone chain, one value per rank, and every effect key present
in the closed vocabulary (`grug_classes.TALENT_EFFECT_KEYS`).
`grug_classes.audit_talents` then checks the counts once after load: eight
talents and 28 ranks per tree, one keystone per chain, one capstone per tree,
two trees per class, and every windowed talent's keys in the window table. A
typo is a startup failure, never a silently inert talent.

### 3.2 The one hook

```lua
-- Summed bonus of this key over the player's ranked talents; 0 when none.
-- A level-scaled key answers with its amount at the player's level (§2.10).
function grug_classes.get_talent_bonus(player, key)
```

It is the deliberate twin of `grug_classes.get_race_perk`, down to the stub
override for mods below `grug_classes` in the dependency graph
(`grug_core.get_talent_bonus`).

Every numeric talent in §2 is one call to this function at the site its
**Modifies** column names, and nothing else. **The site is not always in
`kits.lua`.** A kit table's `cooldown`, `charge`, `range` and `max_distance`
fields are evaluated **once at load time**, with no player in scope: a
per-player read written there would change the number for everybody. Those
talents name their key in the ability definition instead, and one central
per-player seam reads it:

| Seam | Ability field | Talents |
|---|---|---|
| `grug_abilities.effective_cooldown` | `cooldown_talent` | Grudge, Onset, Quick Step, Swift Word, Second Skin, Slip Away |
| `grug_abilities.effective_charge` | `charge_talent` | Follow Through |
| `grug_abilities.get_range` | `range_talent` | Far Cast (also the flight distance at Fireball's spawn call), Longshot |
| `grug_abilities.cost_for` | — (by ability id) | Whitehot (Fireball 3 % in its window), Recompense (Smite 6 %) |

Every other numeric talent sits inside a function body with the player in
scope (for example `grug_classes.get_crit_chance_raw` adds `crit_chance_add`).

A second, smaller accessor answers unlock questions:

```lua
-- 0..5; used by the kit grant, the gates and the UI, never by a numeric consumer.
function grug_classes.talent_rank(player, talent_id)
```

**Timed windows.** **Eight talents** are not a constant summed bonus but a
bounded window: **Hold Ground** (its root/slow immunity), **Unbroken**,
**Ruination**, **Whitehot**, **Turn Aside**, **Last Word**, **Shake Loose**
and **Untouchable**. Four are triggered by a condition rather than by a
button (Unbroken, Ruination, Whitehot, Last Word), which is a start time the
talent code sets, not a new mechanism. The Scout's base-kit **Sidestep** and
**Sprint** use the same table without being talents ([scout.md](scout.md)
§2). `get_talent_bonus` returns 0 for a window key that is not running (the
keys in `grug_classes.TALENT_WINDOW_KEYS`), so a consumer needs no second
accessor. The windows live in one per-player expiry table in `talents.lua`
(`start_talent_window`, `talent_window_active`), cleared on leave, death and
respec (`clear_talent_windows`); that table is the single place a window
lives.

### 3.3 Persistence

- One player-meta **string** key, `grug_classes:talents`, holding `id=rank`
  pairs separated by commas: `ironbound=4,grudge=1`. A string keeps it to one
  key instead of sixty-four, and it stays human-readable for `/talents`
  debugging.
- One player-meta **integer** key, `grug_classes:respec_used`, is 0 until the
  first successful reset and 1 thereafter. It persists across reconnects so
  the free reset is granted once per character; paid resets leave it at 1.
- Parsed once per join into a per-player runtime cache, invalidated on spend,
  respec, a level change, the first class pick and leave.
- **The read path validates, it does not trust.** Unknown ids are dropped,
  ranks are clamped to the talent's own rank count, a rank whose tier gate or
  hard chain is not satisfied is dropped **together with everything below it
  in its chain**, and the total spent is clamped to `floor(level / 2)`. A
  hand-edited meta string therefore cannot buy a capstone at level 4.
- No point balance is persisted. Points available are always derived
  (`grug_classes.talent_points_available` from the level), never stored, so
  the two can never disagree.

### 3.4 Granting a new skill, and replacing an existing one

A newly ranked active-skill talent adds its ability to the skill catalogue and puts it on the first free hotbar slot; with a full hotbar it waits in the catalogue (Round 44: skills live on the hotbar only, `inventory_equipment.md` §6). The message feed says which. Full respec removes representations that are no longer unlocked. Re-ranking grants the ability the same way. Passive and replacement talents remain read-only information and never create dummy items.

**Two mechanisms, and ruling 13 makes the second one carry most of the
design.**

**A new skill** is an ordinary `grug_abilities` registration with
`talent_gated = true` and its owning talent ID. The shared
`grug_abilities.is_unlocked(player, id)` predicate checks class membership and
positive talent rank; catalogue listing, recovery, normalization and actual
cast/swing execution all use that authority. Possessing a forged or stale
representation never grants an ability.

A talent-granted ability appears in the Talents & Skills catalogue and on a
free hotbar slot when there is one; otherwise the player drags it there.
Registration order determines catalogue order but never moves an existing
hotbar item. Under ruling 13 at most two such abilities exist per build.
Base-kit insertion occurs once at character creation; later unlocks never
need a free slot outside the hotbar and never use one.

**A replacement** (the eight replacing keystones and the two replacing
capstones) is **not** a registration and touches none of the above. The
shipped ability keeps its id, its key, its icon and its registration; the
talent is a read inside its own `cast` or `proc_swing` body, exactly like
every numeric talent in §2 — Bellow is a radius the Taunt body reads, Hearten
is a loop the Heal body runs, Frostbind is where Ice Nova takes its
origin from. Of the **twenty-four** keystones and capstones, **sixteen** — the
ten replacements and the six effects — cost zero new registrations, zero new
items and zero grant logic.

Talent spending and respec invoke `grug_abilities.normalize_kit(player)`.
This removes stale or duplicate representations and refreshes surviving item
metadata without filling discarded slots. The skill catalogue refreshes its
entitlement list, places new entries on a free hotbar slot and announces them. Replacements need no additional
item: the next cast reads the current talent rank.

**Hotbar budget** (`classes.md` §2b reserves keys 1-8). Under rulings 13 and
19 the ceiling is **base kit + 2**. Warrior, Mage and Priest start with
**Strike + 3**; Scout's explicitly approved four class abilities give it
**Strike + 4**:

| Class | Base kit | Max new buttons | Worst case |
|---|---|---|---|
| Warrior | Strike + 3 — Charge, Mighty Blow, Taunt; **Hamstring left the base kit with ruling 19** and returns as Ruin's keystone | 2 (Hold Ground, Hamstring) | **6 of 8** |
| Mage | Strike + 3 (`classes.md` §4) | 2 (Cinderfall, Glacial Ward) | 6 of 8 |
| Priest | Strike + 3 (`classes.md` §5) | 2 (Mend, Word of Ruin) | 6 of 8 |
| Scout | Strike + 4 ([scout.md](scout.md) §2) | 2 (Pinning Shot, Opening) | **7 of 8** |

Two keys stay free in the original three classes; Scout keeps at least one
free key. No Warrior shield ability exists (`classes.md` §6); if one comes,
`register_ability` already carries the `slot = "offhand"` plumbing. All four
classes remain inside the eight-key hotbar; Scout's extra base skill does not
add an extra talent-button allowance.

**A Warrior who takes neither Ruin keystone has no snare.** That is the cost
of ruling 19, and it should be visible rather than discovered: Hamstring is
the Warrior's control tool (in an engine where mobs outrun players, the snare
is the Warrior's identity, `classes.md` §3), and a Bulwark-only Warrior now
reaches level 26 before that identity is available at all. The
counter-argument the ruling rests on is that a Warrior who wants the snare
gets it **and** its ranks in one 13-point commitment, instead of being handed
it at level 1 and then re-tuning it with three separate talents.

### 3.5 UI

Since Round 44 (`ui-crafting-rework-plan.md` ruling 7 and §3.4) one tab,
**Talents & Skills**, registered from `grug_classes/talents_ui.lua`, shows
the class's talent trees; `grug_skills` adds the skill catalogue row under
them (`inventory_equipment.md` §6) and the shared frame the short inventory
(the hotbar and two scrolling rows) below. The page uses real coordinates.

- **Tree framework** (`grug_classes.layout_tree`): a tree is a list of
  sections (with optional column labels) and a list of nodes `{id, section,
  row, col, requires = {…}}`. Sections sit side by side, nodes are image
  buttons at their row and column, and every requirement is a connector of
  `box[]` segments drawn before (under) the nodes, orthogonal: down from the
  parent, across in the gap above the child's row, down into the child. A
  node may have several parents and children. Today's data
  (`grug_classes.talent_tree_data`) gives two sections, the class's two trees
  side by side, each chain a column labelled with its name, each tier a row
  and the talent above in the chain the one requirement; a connector is gold
  once its parent has every rank.

```
+--------------------------------------------------------------------+
| Inventory | Character | Talents & Skills | Crafting | ...  (tabs)  |
+--------------------------------------------------------------------+
| Scout talents   Talent points available: 3 of 15  [ Respec: Free ] |
| +- Quarry — 12 points -----------+ +- Veil — 0 points ------------+ |
| | Draw           | Ranging       | | Blade         | Shadow       | |
| | Strong Draw    | Quiver        | | Fine Edge     | Light Step   | |
| |     5/5        |   3/5         | |    0/5        |    0/5       | |
| |       |               |        | |      |               |       | |
| | Cold Eye  4/4  | Fletching 0/4 | | ...                          | |
| | ... four rows, one per tier    | |                              | |
| +--------------------------------+ +------------------------------+ |
| (the selected talent's text, or a notice)                          |
| Drag skills onto the hotbar. Drag one back here to remove it.      |
| Skills  [Strike][Sprint][Loose][Snare Shot]                        |
| (two inventory rows, scrolling; then the hotbar)                   |
+--------------------------------------------------------------------+
```

- A node shows the talent's name, `*` for a keystone or `**` for the
  capstone, and its rank. Its look tells the state: buyable (green), every
  rank bought, some ranks but not buyable now, locked (dimmed); the selected
  node is gold. Hover explains the effect and, when locked, the reason
  ("needs 12 points in Bulwark" or "needs Weathered 4/4").
- Clicking an available talent immediately spends one point for one rank;
  clicking another node selects it and shows its text and the reason in the
  line below the trees. There is no preselection click or purchase
  confirmation.
- The **Respec button lives here** (ruling 4) with its price in the label and
  an inline confirmation prompt, since there is no NPC to host the transaction.
- Fixed numeric button fields map only to registered talents of the
  submitting PlayerRef's own class. Names and descriptions are escaped with
  `core.formspec_escape`; no player name or free-text field enters a purchase.
- Combat statistics are on Character, not Talents. The freed space belongs to
  tree controls, ranks and wrapped descriptions. Effective Character values
  include active effects; Help explains caps, multipliers and exceptions.
- Round 18 supplies semantic action icons for active talent abilities as well
  as base skills (`classes.md` §2c). Passive talent-tree artwork remains outside
  that action-icon scope.
- `/talents` is a read-only rank summary; no command changes talent state.

### 3.6 Level-up flow

`grug_classes.on_level_change_talents` runs from `grug_classes`' level-change
registration (`grug_xp.register_on_level_change`). `old_level` is nil on
join, so the function returns there before any arithmetic. When
`talent_points_at(new_level) > talent_points_at(old_level)` and at least one
point is unspent, it posts one message-feed line directing the player to
the Talents & Skills tab, alongside the "Reached level N!" level-up banner (a
large centre message since Round 28 ruling 20, no longer a chat line). No new
globalstep, no new HUD element, no new packet. The banner itself names the
points the jump earned in a second line, "You gained +1 Talent Point" (or "+N
Talent Points" over several levels; Round 36 §2.14.4); both read the one rule
`grug_classes.talent_points_at(level)` = floor(level / 2). A level drop takes
the free full reset of §1.4 instead.

### 3.7 The KAT (archived)

The WP11 KAT plan (eight test groups and their mutation proofs) is in the
[delivery record](../archive/design/skill-trees-wp11-delivery.md) §3.7. The
load-time asserts of §3.1 enforce the shape; the current fixtures are listed
in [tools/README.md](../../tools/README.md).

### 3.8 What changes where (archived)

The WP11 file table is in the
[delivery record](../archive/design/skill-trees-wp11-delivery.md) §3.8; the
consumer of each talent is its Modifies cell in §2.

### 3.9 The movement aggregator (ruling 11)

Talents and skills that change movement go through one central aggregator,
`grug_core/movement.lua`; it is the only writer of the player's
`physics_override` speed and jump. Hold Ground and Shake Loose set a
root/slow immunity, the Scout's Sprint adds a speed modifier, and Tendon Cut,
Pinning Shot and Ice Nova apply roots. The rules (ruling 11, combination by
ruling 26):

- Each system registers a **named** modifier with its **own duration**;
  effects overlap freely.
- A **root is a hard flag** — speed 0 and jump 0 regardless of modifiers,
  never a "−1000 %". The shared physics writer zeros locomotion with native
  braking, so a moving player stops; falling and gravity stay active.
- **Movement immunity** removes roots and discards negative modifiers.
- An **exclusive hold** (character creation's freeze) takes precedence and
  releases exactly.
- **Combination: additive percentages per axis, then one clamp**:
  `speed = clamp(1 + Σ speed, 0.1, 1.5)` and the same for `jump`, a root or
  an exclusive hold taking precedence over the sum. Two slows add; they never
  multiply.
- **Stances** (user ruling 2026-09-28) are self-imposed speed factors applied
  after the sum: `speed = clamp(clamp(1 + Σ speed, 0.1, 1.5) × Π stances,
  0.1, 1.5)`. Immunity does not discard a stance (it is not a debuff), Shake
  Loose's negative clear keeps it, and it scales Sprint and every other
  positive modifier. Jump is not affected. Current stances: eating ×0.35
  (`grug_food`) and drawing or holding a drawn bow ×0.5 (Scout Loose); each
  owner clears its stance on every end path, and death and leave drop the
  whole record.
- Charge's stun is separate: it sets speed and jump to zero and blocks
  action execution. Gravity stays unchanged for combat control.
- **Mounts stay outside the aggregator** (`mounts.md`): a mount's speed is
  its entity's velocity.

API: `grug_core.set_move_modifier`, `clear_move_modifier`, `set_root`,
`set_move_immunity`, `clear_move_immunity`, `hold_movement`,
`release_movement`, `set_move_stance`, `clear_move_stance`,
`get_move_stance`. The original sizing and the writer audit are in the
[delivery record](../archive/design/skill-trees-wp11-delivery.md) §3.9.

### 3.10 No class change (ruling 20)

Class changing does not exist, for players and admins alike: no command,
no trainer, no respec option changes a character's class, and a respec never
unequips anything. Choosing a class for the first time at character creation
is not a change. A class change would have to decide what happens to gear
the new class may not wear (`inventory_equipment.md` §2's armour-class
ranks), and every answer is bad; removing the operation removes the
question. The class-restriction unequip code in `grug_inventory` stays as a
guard that keeps the rank rule true if anything writes an equipment list
directly. The original site list is in the
[delivery record](../archive/design/skill-trees-wp11-delivery.md) §3.10.

### 3.11 Absorb shields stack (ruling 23)

Absorbs are **named contributions with independent durations** in one
aggregator, never "a new shield replaces the old" (`grug_core.add_absorb`):

```lua
grug_core.add_absorb(target, "shield_spell", amount, 15)
grug_core.add_absorb(target, "hold_ground", amount, 8)
grug_core.get_absorb(target)        -- the total
```

- **Soak order: shortest remaining duration first**, so a shield about to
  expire is the one that is spent.
- **Re-casting the same name refreshes that contribution** and does not add a
  second one, so Recompense tops its own shield up (at most once every 6 s)
  rather than stacking a dozen.
- **The total is capped at the target's maximum HP**: a new contribution
  absorbs at most what the others leave below that cap.
- `grug_core.get_absorb(player)` returns the sum, so Warded Wrath's "while the
  Priest carries an absorb shield" gate (§2.6) and the central hp-change
  modifier's soak read one number.
- Contributions are cleared on death and leave. A contribution can carry a
  caster-owned talent modifier (Turn Aside's dodge), which respec, death and
  leave of the caster remove (`grug_core.clear_absorb_modifiers`); the absorb
  itself keeps its lifetime.

Writers: the Priest's Shield, Glacial Ward, Hold Ground, Recompense and the
Last Light Locket's trinket special (`items_crafting.md` §6.2).

---

## 4. Implementation lanes (archived)

WP11 shipped in four lanes: X1 the model, X2 the numeric consumers, X3 the
keystones and capstones (Round 12), X4 the UI, level-up and respec
(2026-09-17); the Scout's trees came with Round 11. Their scope table is in
the [delivery record](../archive/design/skill-trees-wp11-delivery.md) §4.

---

## 5. The user's rulings (2026-09-16)

The binding frame of this design, one line each. The full texts, the order in
which they were given and what each replaced are in the
[delivery record](../archive/design/skill-trees-wp11-delivery.md) §5.

1. **Talent points:** one every 2 levels, the first at level 2, so 30 at
   level 60; "two thirds" was a rough guideline (§1.3).
2. **Tree size:** about 30 ranks per tree, two playstyle directions (chains)
   per tree, both gate kinds (points in the tree and hard chains), rank
   counts 3–5 by strength; a full tree is not forced (§1.1, §1.2).
3. **Keystones and capstones:** per tree two keystones and one capstone; the
   capstone hangs on its own chain (§1.2, §2).
4. **No class trainer:** new skills come only from the tree; the base kit at
   class choice stays; respec for money in the talent UI, no NPC (§1.4, §3.5).
5. **Names:** the tree names stay; talent names must not remind of an existing
   game (§2.11).
6. *(Coordinator cap proposal, superseded the same day by ruling 10.)*
7. **The Scout:** a fourth class in leather armour, a bow tree and a melee
   tree, no poison ([scout.md](scout.md)).
8. **Invisibility rules** (combat breaks it, a detection chance, higher-level
   mobs detect better, slower movement) — deferred whole to
   [scout.md](scout.md) §8.
9. **Sprint:** about 10 s of markedly increased speed; it became the Scout's
   base-kit ability ([scout.md](scout.md) §2).
10. **Rule-breaking with limits:** skills may break the base inequalities
    (mob speed over player speed, stat caps, roots); the bigger the break, the
    stronger the limit. Capstones and rule-breaker talents may exceed caps,
    time-limited; Sprint stays usable in combat on a long cooldown (§2.9,
    §2.10).
11. **Speed ownership:** one central aggregator with named modifiers and
    their own durations; a root is a hard flag; mounts stay outside (§3.9).
12. **The Scout as simple as possible:** no invisibility in version 1, no
    poison, no traps, a base kit of four from existing mechanics
    ([scout.md](scout.md)). Its "arrows ballistic, Fireball straight" half was
    overridden in Round 17: arrows and Fireball home on the release-time target.
13. **Per tree at most one keystone adds a new skill;** the other keystone
    improves or replaces a skill; the capstone is an effect or a replacement
    (§2, §2.9).
14. **The Scout uses mana** ([scout.md](scout.md) §1).
15. **HUD:** a thin, point-accurate life bar and one mana-or-rage bar above
    the hotbar instead of hearts (`classes.md` §1).
16. *(A user finding — rage fills too fast — answered by ruling 25.)*
17. **A capstone has one rank** (§1.2).
18. **One capstone per level-60 character,** following implicitly from the
    tree's requirements, the first around level 40–44 (§1.3).
19. **Every class starts with Strike plus three;** Hamstring leaves the
    Warrior's base kit and returns as Ruin's keystone (§2.2).
20. **No class change at all,** admins included; a respec is a full reset; a
    level drop resets talents for free (§1.4, §3.10).
21. **Names: the overall picture matters;** single common words are not
    protected (§2.11).
22. **Respec price:** five minutes of measured reliable net solo income at the
    character's own bracket; the first respec is free (§1.4).
23. **Absorbs stack** as named contributions with independent durations
    (§3.11).
24. *(Where open questions live; answered then as "inside the design docs".
    The documentation rules now keep open questions in BACKLOG or a root
    `TODO-*.md` file, [documentation](../process/documentation.md).)*
25. **Warrior rage:** lower the income and add decay — swing 12 → 8, hit
    taken 4 → 3, 5 rage/s out of combat (`classes.md` §3).
26. **The movement aggregator combines additively per axis with one clamp**;
    stances multiply the clamped result (2026-09-28) (§3.9).
27. **The Scout's trees are Quarry and Veil** (§1.1).
28. **A bow's damage is weapon damage + Dex/10**, through
    `grug_classes.get_ranged_bonus` (fractions count since Round 33,
    `combat_stats.md` §2).
29. **Sprint** is +50 % for 10 s on a 300 s cooldown (+25 % as ruled, amended
    by the user on 2026-09-20; [scout.md](scout.md) §2).

---

## 6. Open decisions

None in this file. Open questions about talents (for example the "Word"
names, BACKLOG DP-06) are in [BACKLOG](../../BACKLOG.md) under "Audit
2026-10 open questions". The closed decision record of revision 2 is in the
[delivery record](../archive/design/skill-trees-wp11-delivery.md) §6.

## 7. Tasks (closed)

The revision's task list for other files is closed; its rows and their status
are in the [delivery record](../archive/design/skill-trees-wp11-delivery.md)
section F.
