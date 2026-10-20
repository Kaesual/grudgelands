# Skill Trees (Talents)

**Decided design, live since Round 53 (0.53.0, round K of the class
rework).** Each of the four classes has two talent trees, drawn as graphs:
nodes on seven gate rows, joined by prerequisites, with one ultimate per
tree. A character earns 30 points by level 60; every tree holds more ranks
than that. The trees are the eight of the
[node list](../planning/class-redesign/node-list.md) under the user's
decisions of 2026-10-20 ([round 53 plan](../planning/round53-plan.md) §2);
Round 52 built the engine and the page beside the old trees (§3.12), Round
53 made them live with one talent reset for every character (the 0.53.0
migration step, [upgrade contract](../technical/upgrade-contract.md)).

- The kits the talents act on are [classes.md](classes.md) §3–§5 and
  [scout.md](scout.md) §2; the numbers are the frozen balance calculator's
  (round 53 plan §3 "Numbers").
- Code is cited by symbol (a function, a registration, a field), never by
  line number.
- The trees of revision 2 (two chains per tree, keystones and capstones, 64
  talents, Rounds 11–52) and their delivery history — the talent name audit,
  the KAT, the file table, the lanes, the full ruling texts and the closed
  task list — are archived in the
  [WP11 delivery record](../archive/design/skill-trees-wp11-delivery.md)
  (section G holds the last text of the old trees).

Companion file: [scout.md](scout.md), the fourth class (kit, armour, bow,
stealth deferred). Its two trees live here in §2.7/§2.8 so that all four
classes' talents stay in one place under one arithmetic.

---

## 1. The shape

### 1.1 Four classes, two trees each

| Class | Tree | Direction | Nodes | Ranks | Skills it grants (T = transform) | Ultimate |
|---|---|---|---:|---:|---|---|
| Warrior | **Bulwark** | guard | 14 | 33 | Retort (T of Strike), Hold Ground, Taunt, Bellow (T of Taunt) | Unbroken |
| Warrior | **Ruin** | rage damage | 14 | 33 | Mighty Blow, Hamstring, Broadstroke (T of Mighty Blow) | Ruination |
| Mage | **Ember** | fire damage | 13 | 32 | Fireball, Flame Lance, Meteor | Fire Rain |
| Mage | **Rime** | frost control | 14 | 33 | Cold Spark (T of Fiery Spark), Blink, Rime Mantle, Ice Nova (T of Ice Wave) | Winter Field |
| Priest | **Mercy** | support | 13 | 33 | Shield, Mend, Hearten | Haven |
| Priest | **Reckoning** | judgment | 14 | 34 | Rebuke, Word of Ruin, Censure | Final Word |
| Scout | **Quarry** | the bow | 13 | 32 | True Draw, Snare Shot, Split Shot | Arrowfall |
| Scout | **Veil** | the blade | 14 | 33 | Bladecraft (T of Loose), Opening, Parry, Flourish | Close Dance |

**109 nodes, 263 ranks.** Every class starts with its own starters and
needs no talent for them: the Warrior Strike and Charge, the Mage Fiery
Spark and Ice Wave, the Priest Smite and Heal, the Scout Loose, Sidestep
and Sprint (plus the universal Strike; [classes.md](classes.md) §2d). Every
other skill comes from a tree.

The tree names are decided (ruling 5 kept Bulwark, Ruin, Ember, Rime, Mercy
and Reckoning, ruling 27 named Quarry and Veil). Node names follow §2.11.

### 1.2 Nodes, gates and prerequisites

Each node has a **type**:

- **modifier:** a number on an existing skill or stat;
- **window:** its ranks feed a readiness window (§3.2);
- **unlock:** grants a skill into the Talents & Skills catalogue and places
  nothing on a hotbar (Round 50 D1, class plan C8);
- **transform:** replaces a skill in place on hotbars A and B and shares
  its cooldown (§3.4);
- **ultimate:** the tree's one unlock at the last gate.

A granting node (unlock, transform, ultimate) has one rank; a modifier or
window node has one to five.

A node's **gate** is the number of points already spent in its tree before
its first rank: 0, 2, 6, 10, 12, 16 or 20, one row of the page each. With one
point every two levels the rows open at levels 2, 6, 14, 22, 26, 34 and 42 at
the earliest. Exactly: a node's gate counts the ranks of the tree's nodes
with a **lower** gate, so two nodes of one row never pay for each other
(`graph.structure_refusal`, the same text on the spend and the read path:
"Meteor needs 12 points in Ember (you have 8).").

A node may have **prerequisites** (`requires`), nodes of the same tree and
of no higher gate; each needs **one** rank, never a full chain ("Opening
needs a rank in Bladecraft."). A transform's later nodes require the
transform (Keen Cold requires Cold Spark), an ultimate requires the unlock
it grows from.

### 1.3 Points and the arithmetic

- **One point every two levels, the first at level 2** (ruling 1): levels
  2, 4, 6, …, 60. The point count at level L is `floor(L / 2)`
  (`grug_classes.talent_points_at`); at level 60 that is **30 points**.
  Points are never stored, so they cannot disagree with the level.
- **A tree holds 32 to 34 ranks**, more than the 30 points, so even a pure
  build leaves ranks unbought (the audit asserts it). A full tree is never
  forced: every split is legal.
- **An ultimate costs 21 points in its tree:** its gate is 20, so it is the
  21st point at the earliest, at **level 42**. Two ultimates would cost 42
  of 30 points; a mixed build may take neither. This is arithmetic, not a
  rule.
- Each tree carries a **sample build** (`example`, a legal 30-point order in
  node codes) that the load-time audit buys rank by rank; the fixtures use
  it (§3.12).

There is no hotbar budget rule any more: a normal loadout uses four to six
skills, and owning more is allowed (the delivery plan's §6). The skills
wait in the catalogue and the player places them on hotbar A or B.

Death costs no XP (Round 18); dying never removes talent points.

### 1.4 Respec, and no class change (rulings 4, 20, 22)

- **Where: on the Talents & Skills page itself.** There is no class
  trainer and no NPC (ruling 4).
- **What: a full reset** (ruling 20, `graph.reset`): every rank to 0, all
  points back. No partial or single-tree respec.
- **Price (ruling 22):** **five minutes of measured reliable net solo
  income at the character's own bracket**, rounded by `economy.md` §4.1's
  rule, **and the first respec of a character is free**. The six bracket
  prices are `grug_classes.RESPEC_PRICES` (15, 35, 75, 200, 550 and 1200
  copper), listed in [economy.md](economy.md) §4 (the price owner) and
  checked by `tools/r29_e4/income.py --check`; the purchase is
  `grug_classes.buy_respec`, which takes the money before the reset. The
  0.53.0 migration step cleared every character's
  `grug_classes:respec_used`, so the first respec after the talent reset
  is free again (round 53 plan §8 Q3).
- **There is no class change at all (ruling 20).** Not for players, and
  **not for admins** (§3.10).
- **A level drop resets talents completely and for free**
  (`grug_classes.on_level_change_talents`): the talent state is wiped and
  every point returned, with one feed line. Only a direct `grug_xp.set_xp`
  call can lower a level; the `/xp` command only grants a positive amount.

---

## 2. The talents

Reading the tables:

- **Code** is the node list's code (the docs' name; Reckoning is RK1–RK14
  so it does not collide with Rime's R1–R14, and Mercy keeps the gap of the
  cut M12 Shelter). The code id beside the name is `<tree>_<name>`; its
  talent icon is `grug_classes_talent_<name>.png`, a granting node shows
  its skill's icon.
- **Effect** is the node's player text from the data, as the page shows
  it: no unit letters.
- **Keys** are the effect keys with their value per rank (§3.2): shared
  stat keys, the class's own keys, and the family keys
  `<family>:<param>`, which reach every skill whose id or tag is the param.
  Tags: Mage `fire` (Fiery Spark, Fireball, Flame Lance, Meteor, Fire Rain)
  and `frost` (Ice Wave, Cold Spark, Blink, Rime Mantle, Ice Nova, Winter
  Field); Priest `support` (Heal, Shield, Mend, Hearten, Haven) and `paid`
  (Rebuke, Word of Ruin, Final Word; Censure is named by its id); Scout
  `bow` (Loose, True Draw, Snare Shot, Split Shot, Arrowfall, Bladecraft's
  right-click shot) and `blade` (Bladecraft, Opening, Parry, Flourish,
  Close Dance, and Strike); the Warrior's skills carry no tag.
- **Units in the code** (round 53 plan §3): **D** the Mage's untalented
  Fiery Spark hit (spell base + spell power, "a Spark hit"); **S** a Strike
  hit (melee weapon damage + melee bonus); **R** and **M** the Scout's base
  bow hit (bow damage + Dexterity bonus) and base blade hit (Melee-slot
  weapon + melee bonus); the Priest's "Smite hit" is its spell unit (spell
  base + spell power) and its "base hit" `B(L)` scaled like the spell by the
  caster weapon (§2.10); **P** the class-neutral base pool, **Q** the
  support factor, **K** the level's armor constant `grug_core.armor_k(L)`.
  A unit add ("+0.05 D") is a class key holding the coefficient; the kit
  multiplies it by its unit. `damage_pct` is a percentage of the skill's
  untalented damage, applied once.

### 2.1 Warrior — Bulwark

| Code | Node | Type | Ranks | Gate | Requires | Effect | Keys |
|---|---|---|---:|---:|---|---|---|
| B1 | **Retort** `bulwark_retort` | transform `retort` | 1 | 0 | — | Strike becomes Retort: when a hostile hit takes your health, your next swing within 4 s deals +25 % of a Strike hit; 6 s internal cooldown. | — |
| B2 | **Ironbound** `bulwark_ironbound` | modifier | 4 | 0 | — | Armor +4/8/12/16 % of the level's armor constant. | `armor_percent_add` 4/8/12/16 |
| B3 | **Weathered** `bulwark_weathered` | modifier | 3 | 0 | — | Max health +3/6/9 %. | `max_hp_percent_add` 3/6/9 |
| B4 | **Hold Ground** `bulwark_hold_ground` | unlock `hold_ground` | 1 | 2 | — | Unlocks Hold Ground: a shield of 12 % of a base health pool for 5 s; 25 rage, 24 s cooldown. | — |
| B5 | **Measured Answer** `bulwark_measured_answer` | modifier | 3 | 6 | B1 | Retort's bonus rises to 30/35/40 % of a Strike hit. | `retort_bonus_add` 0.05/0.1/0.15 |
| B6 | **Turn the Edge** `bulwark_turn_the_edge` | modifier | 3 | 6 | — | Dodge chance +2/4/6 %. | `dodge_chance_add` 2/4/6 |
| B7 | **Taunt** `bulwark_taunt` | unlock `taunt` | 1 | 6 | — | Unlocks Taunt: the enemy in your crosshair attacks you for 3 s; free, 8 s cooldown. | — |
| B8 | **Recover** `bulwark_recover` | modifier | 3 | 10 | B1 | A landed Retort heals 0.7/1.3/2.0 % of a base health pool; never critical. | `retort_heal_percent` 0.7/1.3/2 |
| B9 | **Bellow** `bulwark_bellow` | transform `bellow` | 1 | 12 | B7 | Taunt becomes Bellow: every enemy within 6 m around you; the same cooldown. | — |
| B10 | **Layered Guard** `bulwark_layered_guard` | modifier | 3 | 12 | B4 | Hold Ground's shield +3/6/9 % of a base health pool. | `hold_ground_absorb_add` 3/6/9 |
| B11 | **Halt** `bulwark_halt` | modifier | 3 | 12 | — | Charge's arrival also slows by 20/25/30 % for the stun and 2 s more. | `charge_slow_percent` 20/25/30 |
| B12 | **Unbroken** `bulwark_unbroken` | ultimate `unbroken` | 1 | 20 | B4 | Unlocks Unbroken: for 8 s, armor +50 % of the level's armor constant and a shield of 15 % of a base health pool; 25 rage, 60 s cooldown. | — |
| B13 | **Enduring Stand** `bulwark_enduring_stand` | modifier | 3 | 20 | B12 | Unbroken lasts +0.5/1.0/1.5 s. | `duration_add:unbroken` 0.5/1/1.5 |
| B14 | **Gather Yourself** `bulwark_gather_yourself` | modifier | 3 | 16 | B4 | Hold Ground's cooldown -1/2/3 s. | `cooldown_sub:hold_ground` 1/2/3 |

Consumers: `kits_warrior.lua` (Retort, Hold Ground, Taunt, Bellow, Unbroken
and the class keys `retort_bonus_add`, `retort_heal_percent`,
`hold_ground_absorb_add`), `charge.lua` (Halt's `charge_slow_percent`), the
shared stat keys (`grug_quality` raw armor, `stats.lua`). Retort is Strike
with a readiness window: a hostile punch that took health (the settled-hit
hook: not dodged, not fully absorbed, not lethal, not the Warrior's own)
opens the window `retort` for 4 s with a 6 s internal cooldown, and the next
landed Retort spends it for ×(1 + bonus) and Recover's flat heal, never a
crit; its readiness lives only in the window and the swing callback, never
in a charge or a cost, so a held LMB always swings (K8). Hold Ground and
Unbroken grant no immunity. The node id `bulwark_unbroken` keeps the old
low-health passive's `talent_rank(player, "unbroken")` at 0 by its prefix
(the passive itself went in Round 53).

### 2.2 Warrior — Ruin

| Code | Node | Type | Ranks | Gate | Requires | Effect | Keys |
|---|---|---|---:|---:|---|---|---|
| U1 | **Mighty Blow** `ruin_mighty_blow` | unlock `mighty_blow` | 1 | 0 | — | Unlocks Mighty Blow: a swing for 145 % of a Strike hit when you have 25 rage, else a plain swing; no cooldown of its own. | — |
| U2 | **Heavy Hand** `ruin_heavy_hand` | modifier | 4 | 0 | U1 | Mighty Blow and Broadstroke hit +5/10/15/20 % of a Strike hit. | `mighty_blow_unit_add` 0.05/0.1/0.15/0.2 |
| U3 | **Stoke** `ruin_stoke` | modifier | 3 | 0 | — | +1/2/3 rage per full swing. | `rage_per_swing_add` 1/2/3 |
| U4 | **Hamstring** `ruin_hamstring` | unlock `hamstring` | 1 | 2 | — | Unlocks Hamstring: a swing for a full Strike hit that slows by 35 % for 3 s; 10 rage, recharges in 8 s. | — |
| U5 | **Keen Edge** `ruin_keen_edge` | modifier | 3 | 6 | — | Critical chance +2/4/6 %. | `crit_chance_add` 2/4/6 |
| U6 | **Onset** `ruin_onset` | modifier | 3 | 6 | — | Charge's cooldown -0.5/1.0/1.5 s. | `cooldown_sub:charge` 0.5/1/1.5 |
| U7 | **Broadstroke** `ruin_broadstroke` | transform `broadstroke` | 1 | 6 | U1 | Mighty Blow becomes Broadstroke: the same hit, and up to 2 others in a 100 degree, 3 m arc take 35 % of a Strike hit, critical hits allowed. | — |
| U8 | **Follow Through** `ruin_follow_through` | modifier | 3 | 10 | U7 | Broadstroke's other targets take 40/45/50 % of a Strike hit. | `broadstroke_secondary_add` 0.05/0.1/0.15 |
| U9 | **Clean Cut** `ruin_clean_cut` | modifier | 3 | 10 | U4 | Hamstring's slow lasts +0.5/1.0/1.5 s. | `duration_add:hamstring` 0.5/1/1.5 |
| U10 | **Finisher** `ruin_finisher` | modifier | 3 | 12 | U1 | Mighty Blow and Broadstroke hit +8/16/24 % of a Strike hit against a target below 30 % health. | `finisher_unit_add` 0.08/0.16/0.24 |
| U11 | **Relentless** `ruin_relentless` | modifier | 3 | 16 | U1 | Mighty Blow and Broadstroke cost 1/2/3 rage less. | `mighty_blow_cost_sub` 1/2/3 |
| U12 | **Ruination** `ruin_ruination` | ultimate `ruination` | 1 | 20 | U1 | Unlocks Ruination: for 8 s your swings deal +15 % damage and each landed swing gives 2 more rage; 20 rage, 60 s cooldown. | — |
| U13 | **Long Fury** `ruin_long_fury` | modifier | 3 | 20 | U12 | Ruination lasts +0.5/1.0/1.5 s. | `duration_add:ruination` 0.5/1/1.5 |
| U14 | **Reach the Fight** `ruin_reach_the_fight` | modifier | 1 | 12 | — | Charge's arrival gives 5 more rage. | `charge_rage_add` 5 |

Consumers: `kits_warrior.lua` (Mighty Blow, Broadstroke, Hamstring,
Ruination and `mighty_blow_unit_add`, `finisher_unit_add`,
`mighty_blow_cost_sub` through `cost_adjust`, `broadstroke_secondary_add`),
`charge.lua` (`charge_rage_add`), `grug_abilities/init.lua` (Stoke's
`rage_per_swing_add` in `swing_rage`). Stoke and Ruination's +2 rage scale
with the weapon's base swing interval over the 1 s reference like every
swing grant (Round 46 ruling 9), so every weapon earns the same rage per
second. Ruination's ×1.15 is a multiplier on every swing (procs included)
through the swing callback and also reaches Broadstroke's other targets;
Finisher reads the target's health before the swing. Broadstroke's other
targets (`area.cone`, nearest first, the shared target check) may
crit and give no rage.

### 2.3 Mage — Ember

| Code | Node | Type | Ranks | Gate | Requires | Effect | Keys |
|---|---|---|---:|---:|---|---|---|
| F1 | **Fire Mastery** `ember_fire_mastery` | modifier | 4 | 0 | — | All fire damage +5/10/15/20 %. | `damage_pct:fire` 5/10/15/20 |
| F2 | **Measured Fuel** `ember_measured_fuel` | modifier | 3 | 0 | — | Paid fire spells cost 4/8/12 % less. | `cost_pct:fire` -4/-8/-12 |
| F3 | **Far Cast** `ember_far_cast` | modifier | 3 | 0 | — | Fiery Spark and Cold Spark reach 1/2/3 m farther. | `range_add:cold_spark` 1/2/3; `range_add:fiery_spark` 1/2/3 |
| F4 | **Fireball** `ember_fireball` | unlock `fireball` | 1 | 2 | F1 | Unlocks Fireball: 160 % of a Spark hit, and 15 % to others within 2 m; 5 s cooldown, 6 % mana, 1 s recovery. | — |
| F5 | **Flame Lance** `ember_flame_lance` | unlock `flame_lance` | 1 | 6 | — | Unlocks Flame Lance: an instant heavy bolt for 220 % of a Spark hit; 8 s cooldown, 10 % mana, 1.5 s recovery. | — |
| F6 | **Heat Focus** `ember_heat_focus` | modifier | 3 | 6 | F5 | Flame Lance deals +5/10/15 % damage. | `damage_pct:flame_lance` 5/10/15 |
| F7 | **Afterglow** `ember_afterglow` | modifier | 3 | 6 | F4 | Fireball's hit +5/10/15 % of a Spark hit. | `fireball_unit_add` 0.05/0.1/0.15 |
| F8 | **Meteor** `ember_meteor` | unlock `meteor` | 1 | 12 | F4 | Unlocks Meteor: strikes the ground in your crosshair after 1.5 s with a warning, 140 % of a Spark hit within 3 m; 18 s cooldown, 14 % mana. | — |
| F9 | **Wide Ember** `ember_wide_ember` | modifier | 3 | 12 | F4 | Fireball's splash rises to 20/25/30 % of a Spark hit. | `fireball_splash_unit_add` 0.05/0.1/0.15 |
| F10 | **Broad Impact** `ember_broad_impact` | modifier | 3 | 12 | F8 | Meteor's radius +0.25/0.50/0.75 m. | `radius_add:meteor` 0.25/0.5/0.75 |
| F11 | **Controlled Burn** `ember_controlled_burn` | modifier | 3 | 16 | F8 | Meteor and Fire Rain cost 5/10/15 % less, on top of Measured Fuel. | `cost_pct:fire_rain` -5/-10/-15; `cost_pct:meteor` -5/-10/-15 |
| F12 | **Fire Rain** `ember_fire_rain` | ultimate `fire_rain` | 1 | 20 | F8 | Unlocks Fire Rain: one shower on the ground in your crosshair after 1.5 s, about 250 % of a Spark hit within 5 m; 60 s cooldown, 22 % mana, 1.5 s recovery. | — |
| F13 | **Spreading Rain** `ember_spreading_rain` | modifier | 3 | 20 | F12 | Fire Rain's radius +0.25/0.50/0.75 m. | `radius_add:fire_rain` 0.25/0.5/0.75 |

Consumers: `kits_mage.lua` (every Ember skill; the class keys
`fireball_unit_add` and `fireball_splash_unit_add` in D) and the shared
cast path (the family keys). Fire Mastery's `damage_pct:fire` raises a
skill's whole coefficient once; Measured Fuel and Controlled Burn add up
(Meteor at full ranks costs 14 % × 0.73). Meteor and Fire Rain are ground
areas ([ability_targeting.md](ability_targeting.md) §4); their hits and
Fireball's splash never crit (§2.10).

### 2.4 Mage — Rime

| Code | Node | Type | Ranks | Gate | Requires | Effect | Keys |
|---|---|---|---:|---:|---|---|---|
| R1 | **Cold Spark** `rime_cold_spark` | transform `cold_spark` | 1 | 0 | — | Fiery Spark becomes Cold Spark: a free frost bolt for a full Spark hit that slows by 12 % for 1.5 s; fire bonuses do not apply. | — |
| R2 | **Mana Reserve** `rime_mana_reserve` | modifier | 4 | 0 | — | Max mana +5/10/15/20 %. | `max_mana_percent_add` 5/10/15/20 |
| R3 | **Keen Cold** `rime_keen_cold` | modifier | 3 | 0 | R1 | Cold Spark +3/6/9 % of a Spark hit; the slow stays 12 %. | `cold_spark_unit_add` 0.03/0.06/0.09 |
| R4 | **Blink** `rime_blink` | unlock `blink` | 1 | 2 | — | Unlocks Blink: a 10 m teleport; 20 s cooldown, 8 % mana. | — |
| R5 | **Clear Thought** `rime_clear_thought` | modifier | 3 | 2 | — | Paid frost and utility spells cost 4/8/12 % less. | `cost_pct:frost` -4/-8/-12 |
| R6 | **Quick Step** `rime_quick_step` | modifier | 3 | 6 | R4 | Blink's cooldown -1/2/3 s. | `cooldown_sub:blink` 1/2/3 |
| R7 | **Rime Mantle** `rime_rime_mantle` | unlock `rime_mantle` | 1 | 6 | — | Unlocks Rime Mantle: for 6 s, armor +20 % of the level's armor constant and a shield of 12 % of a base health pool; 24 s cooldown, 10 % mana. | — |
| R8 | **Thick Ice** `rime_thick_ice` | modifier | 3 | 10 | R7 | Rime Mantle's armor +4/8/12 % of the level's armor constant. | `rime_mantle_armor_add` 0.04/0.08/0.12 |
| R9 | **Ice Nova** `rime_ice_nova` | transform `ice_nova` | 1 | 12 | — | Ice Wave becomes Ice Nova: 65 % of a Spark hit within 5 m around you and a 2.5 s root; 18 s cooldown, 10 % mana; the cooldown is shared. | — |
| R10 | **Cold Shock** `rime_cold_shock` | window | 3 | 12 | R9, R1 | When Ice Nova hits an enemy, your next Cold Spark within 4 s deals +25/50/75 % of a Spark hit; one charge. | `cold_shock_unit_add` 0.25/0.5/0.75 |
| R11 | **Returning Cold** `rime_returning_cold` | modifier | 3 | 12 | — | Ice Wave's and Ice Nova's cooldown -1/2/3 s. | `cooldown_sub:ice_nova` 1/2/3; `cooldown_sub:ice_wave` 1/2/3 |
| R12 | **Far Frost** `rime_far_frost` | modifier | 3 | 16 | R9 | Ice Nova's radius +0.25/0.50/0.75 m. | `radius_add:ice_nova` 0.25/0.5/0.75 |
| R13 | **Winter Field** `rime_winter_field` | ultimate `winter_field` | 1 | 20 | R9 | Unlocks Winter Field: one blast on the ground in your crosshair after 1 s, about 100 % of a Spark hit and a 40 % slow for 5 s within 4 m; 60 s cooldown, 18 % mana. | — |
| R14 | **Lasting Armor** `rime_lasting_armor` | modifier | 3 | 16 | R7 | Rime Mantle lasts +0.5/1.0/1.5 s. | `duration_add:rime_mantle` 0.5/1/1.5 |

Consumers: `kits_mage.lua` (every Rime skill; `cold_spark_unit_add`,
`cold_shock_unit_add` in D, `rime_mantle_armor_add` in K). Cold Spark
transforms Fiery Spark and shares its clock, Ice Nova transforms Ice Wave
and shares its cooldown, so Returning Cold names both. Cold Shock opens the
window `cold_shock` (4 s, one charge, no internal cooldown: the Nova's own
cooldown spaces it) when an Ice Nova hit is accepted; the next Cold Spark
that launches spends it. Rime Mantle is an armor status plus a flat 12 % P
shield (the stored calculator change `tuning/mage_rime`), without the
support factor. Ice Wave, Ice Nova and Winter Field never crit.

### 2.5 Priest — Mercy

| Code | Node | Type | Ranks | Gate | Requires | Effect | Keys |
|---|---|---|---:|---:|---|---|---|
| M1 | **Steady Word** `mercy_steady_word` | modifier | 3 | 0 | — | Smite +5/10/15 % of a base hit; with Sharpened Word only the higher counts. | `smite_steady_add` 0.05/0.1/0.15 |
| M2 | **Measured Care** `mercy_measured_care` | modifier | 3 | 0 | — | Heal, Shield, Mend, Hearten and Haven cost 4/8/12 % less. | `cost_pct:support` -4/-8/-12 |
| M3 | **Shield** `mercy_shield` | unlock `shield_spell` | 1 | 2 | — | Unlocks Shield: you or the ally under your crosshair gets a shield of 24 % of a base health pool for 10 s; 12 s cooldown; a new cast replaces it. | — |
| M4 | **Gentle Hand** `mercy_gentle_hand` | modifier | 3 | 2 | — | Heal +2/4/6 % of a base health pool. | `heal_share_add` 2/4/6 |
| M5 | **Warding Faith** `mercy_warding_faith` | modifier | 5 | 6 | M3 | Shield +2/4/6/8/10 % of a base health pool. | `shield_share_add` 2/4/6/8/10 |
| M6 | **Mend** `mercy_mend` | unlock `mend` | 1 | 6 | — | Unlocks Mend: heals the target 4 times, 7 % of a base health pool every 3 s; the newest cast replaces it. | — |
| M7 | **Patient Care** `mercy_patient_care` | modifier | 3 | 10 | M6 | Mend's ticks +0.5/1.0/1.5 % of a base health pool. | `mend_share_add` 0.5/1/1.5 |
| M8 | **Clear Conscience** `mercy_clear_conscience` | window | 3 | 10 | — | After Heal, Shield or Mend your next Smite within 5 s deals +10/20/30 % of a base hit; 8 s internal cooldown. | `clear_conscience_add` 0.1/0.2/0.3 |
| M9 | **Deep Reserve** `mercy_deep_reserve` | modifier | 3 | 12 | — | Max mana +4/8/12 %. | `max_mana_percent_add` 4/8/12 |
| M10 | **Hearten** `mercy_hearten` | unlock `hearten` | 1 | 12 | — | Unlocks Hearten: you and up to 3 allies within 6 m, lowest health first, heal 15 % of a base health pool each; 20 s cooldown, 14 % mana, 1.5 s recovery. | — |
| M11 | **Quiet Care** `mercy_quiet_care` | modifier | 3 | 12 | — | Your healing draws 45/40/35 % threat instead of 50 %. | `heal_threat_factor_sub` 0.05/0.1/0.15 |
| M13 | **Haven** `mercy_haven` | ultimate `haven` | 1 | 20 | M10 | Unlocks Haven: you and up to 4 allies within 8 m heal 6 times, 7 % of a base health pool every 2 s; 60 s cooldown, 1.5 s recovery. | — |
| M14 | **Lasting Haven** `mercy_lasting_haven` | modifier | 3 | 20 | M13 | Haven heals 1/2/3 more times. | `duration_add:haven` 2/4/6 |

Consumers: `kits_priest.lua` (every Mercy skill and the class keys
`smite_steady_add`, `heal_share_add`, `shield_share_add`, `mend_share_add`,
`clear_conscience_add`), `grug_core/combat.lua` (Quiet Care's
`heal_threat_factor_sub` in `add_heal_threat`). Gentle Hand, Warding Faith
and Patient Care add percentage points to the base shares (Heal 25 %,
Shield 24 %, Mend 7 % of P), so the full ranks give Heal 31 %, Shield 34 %
(Warding Faith has five ranks, round 53 plan §8 Q1) and Mend 8.5 %; the
support factor Q multiplies the result. Steady Word and Sharpened Word are
two keys the kit max-combines: only the higher counts. Clear Conscience's
window `clear_conscience` opens on a committed Heal, Shield or Mend (5 s, an
8 s internal cooldown) and the next Smite spends it. Lasting Haven's
`duration_add:haven` of 2/4/6 s is one to three more ticks of 2 s.

### 2.6 Priest — Reckoning

| Code | Node | Type | Ranks | Gate | Requires | Effect | Keys |
|---|---|---|---:|---:|---|---|---|
| RK1 | **Sharpened Word** `reckoning_sharpened_word` | modifier | 3 | 0 | — | Smite +5/10/15 % of a base hit; with Steady Word only the higher counts. | `smite_sharpened_add` 0.05/0.1/0.15 |
| RK2 | **Measured Judgment** `reckoning_measured_judgment` | modifier | 3 | 0 | — | Rebuke, Word of Ruin, Censure and Final Word cost 4/8/12 % less. | `cost_pct:censure` -4/-8/-12; `cost_pct:paid` -4/-8/-12 |
| RK3 | **Rebuke** `reckoning_rebuke` | unlock `rebuke` | 1 | 2 | — | Unlocks Rebuke: an instant hit at the enemy in your crosshair for 180 % of a Smite hit; 6 s cooldown, 6 % mana. | — |
| RK4 | **Firm Rebuke** `reckoning_firm_rebuke` | modifier | 3 | 2 | RK3 | Rebuke +10/20/30 % of a base hit. | `rebuke_add` 0.1/0.2/0.3 |
| RK5 | **Long Reach** `reckoning_long_reach` | modifier | 3 | 6 | — | Smite, Rebuke, Word of Ruin and Final Word reach 1/2/3 m farther. | `range_add:final_word` 1/2/3; `range_add:rebuke` 1/2/3; `range_add:smite` 1/2/3; `range_add:word_of_ruin` 1/2/3 |
| RK6 | **Word of Ruin** `reckoning_word_of_ruin` | unlock `word_of_ruin` | 1 | 6 | — | Unlocks Word of Ruin: an instant hit for 160 % of a Smite hit that heals you for half the damage, at most 6 % of a base health pool; 16 s cooldown, 10 % mana. | — |
| RK7 | **Resolute Word** `reckoning_resolute_word` | modifier | 3 | 10 | RK6 | Word of Ruin heals at most 7/8/9 % of a base health pool. | `word_of_ruin_cap_add` 1/2/3 |
| RK8 | **Hard Faith** `reckoning_hard_faith` | modifier | 3 | 10 | — | Rebuke, Word of Ruin and Final Word deal +3/6/9 % damage. | `damage_pct:paid` 3/6/9 |
| RK9 | **Censure** `reckoning_censure` | unlock `censure` | 1 | 12 | — | Unlocks Censure: strikes the ground in your crosshair after 0.75 s with a warning, 120 % of a Smite hit to the 4 nearest within 3 m; 18 s cooldown, 12 % mana. | — |
| RK10 | **Broad Judgment** `reckoning_broad_judgment` | modifier | 3 | 12 | RK9 | Censure's radius +0.25/0.50/0.75 m. | `radius_add:censure` 0.25/0.5/0.75 |
| RK11 | **Deep Resolve** `reckoning_deep_resolve` | modifier | 3 | 12 | — | Max mana +4/8/12 %. | `max_mana_percent_add` 4/8/12 |
| RK12 | **Press the Verdict** `reckoning_press_the_verdict` | modifier | 3 | 16 | RK3 | Rebuke's cooldown -0.5/1.0/1.5 s. | `cooldown_sub:rebuke` 0.5/1/1.5 |
| RK13 | **Final Word** `reckoning_final_word` | ultimate `final_word` | 1 | 20 | RK3 | Unlocks Final Word: an instant hit at the enemy in your crosshair for 280 % of a Smite hit; 60 s cooldown, 20 % mana, 1.5 s recovery. | — |
| RK14 | **Unfinished Sentence** `reckoning_unfinished_sentence` | modifier | 3 | 20 | RK13 | Final Word +10/20/30 % of a base hit. | `final_word_add` 0.1/0.2/0.3 |

Consumers: `kits_priest.lua` (every Reckoning skill and
`smite_sharpened_add`, `rebuke_add`, `word_of_ruin_cap_add`,
`final_word_add`). Hard Faith's `damage_pct:paid` raises only the
untalented part of Rebuke, Word of Ruin and Final Word, not their talent
adds and not Censure (the frozen calculator); Measured Judgment discounts
all four. A "base hit" add follows the caster weapon like the spell (an
own-level staff or wand keeps it, no caster weapon halves it). Word of
Ruin heals half the damage it dealt, at most its pool cap (6 % P × Q plus
Resolute Word), never a crit. Censure is a ground area (0.75 s, the 4
nearest within its radius) and never crits.

### 2.7 Scout — Quarry

| Code | Node | Type | Ranks | Gate | Requires | Effect | Keys |
|---|---|---|---:|---:|---|---|---|
| Q1 | **Bowcraft** `quarry_bowcraft` | modifier | 4 | 0 | — | Bow attacks deal +5/10/15/20 % damage, Arrowfall included. | `damage_pct:bow` 5/10/15/20 |
| Q2 | **Quiver** `quarry_quiver` | modifier | 3 | 0 | — | Loose has a 10/20/30 % chance to keep its arrow. | `arrow_refund_chance` 10/20/30 |
| Q3 | **Measured Breath** `quarry_measured_breath` | modifier | 3 | 0 | — | Paid bow skills cost 5/10/15 % less. | `cost_pct:bow` -5/-10/-15 |
| Q4 | **True Draw** `quarry_true_draw` | unlock `true_draw` | 1 | 2 | — | Unlocks True Draw: an instant shot for 220 % of a base bow hit; 6 s cooldown, 6 % mana and 1 arrow, 1.35 s recovery. | — |
| Q5 | **Firm Aim** `quarry_firm_aim` | modifier | 3 | 6 | Q4 | True Draw +10/20/30 % of a base bow hit. | `true_draw_add` 0.1/0.2/0.3 |
| Q6 | **Snare Shot** `quarry_snare_shot` | unlock `snare_shot` | 1 | 6 | — | Unlocks Snare Shot: an instant shot for 45 % of a base bow hit that slows by 35 % for 3 s; 14 s cooldown, 5 % mana and 1 arrow, 0.85 s recovery. | — |
| Q7 | **Long View** `quarry_long_view` | modifier | 3 | 10 | — | Bow skills reach 1/2/3 m farther. | `range_add:bow` 1/2/3 |
| Q8 | **Split Shot** `quarry_split_shot` | unlock `split_shot` | 1 | 12 | — | Unlocks Split Shot: one arrow for 90 % of a base bow hit; up to 2 others within 3 m of the target take 55 %; 10 s cooldown, 8 % mana and 1 arrow. | — |
| Q9 | **Broad Shot** `quarry_broad_shot` | modifier | 3 | 12 | Q8 | Split Shot's other hits +5/10/15 % of a base bow hit. | `split_shot_add` 0.05/0.1/0.15 |
| Q10 | **Light Recovery** `quarry_light_recovery` | modifier | 3 | 16 | — | Sidestep costs 10/20/30 % less. | `cost_pct:sidestep` -10/-20/-30 |
| Q11 | **Follow the Line** `quarry_follow_the_line` | window | 3 | 16 | Q4 | A landed True Draw readies your next Loose within 3 s, at any target: +10/20/30 % of a base bow hit. | `follow_the_line_add` 0.1/0.2/0.3 |
| Q12 | **Arrowfall** `quarry_arrowfall` | ultimate `arrowfall` | 1 | 20 | Q4 | Unlocks Arrowfall: 4 arrows at once at the target under your crosshair, each 140 % of a base bow hit, critical hits allowed; 60 s cooldown, 16 % mana and 4 arrows, 2.5 s recovery. | — |
| Q13 | **Iron Hail** `quarry_iron_hail` | modifier | 3 | 20 | Q12 | Each Arrowfall arrow +4/8/12 % of a base bow hit. | `arrowfall_add` 0.04/0.08/0.12 |

The Scout's kit, resource, armour, bow and the **deferred stealth work**
are [scout.md](scout.md). Consumers: `grug_abilities/scout.lua` (every bow
skill and `arrow_refund_chance`, `true_draw_add`, `split_shot_add`,
`follow_the_line_add`, `arrowfall_add`, all shares of R). Bowcraft's
`damage_pct:bow` applies once to each bow skill, Arrowfall included. Follow
the Line opens the window `follow_the_line` (3 s) on a landed True Draw; the
next Loose (or Bladecraft's right-click shot) at any target spends it.
Split Shot's two other targets take their smaller hit without arrows of
their own and never crit; Arrowfall's four arrows may crit.

### 2.8 Scout — Veil

| Code | Node | Type | Ranks | Gate | Requires | Effect | Keys |
|---|---|---|---:|---:|---|---|---|
| V1 | **Bladecraft** `veil_bladecraft` | transform `bladecraft` | 1 | 0 | — | Loose becomes Bladecraft: left click swings your blade, right click looses an instant shot at an enemy; both share one clock. | — |
| V2 | **Fine Edge** `veil_fine_edge` | modifier | 4 | 0 | — | Blade attacks deal +8/16/24/32 % damage. | `damage_pct:blade` 8/16/24/32 |
| V3 | **Light Step** `veil_light_step` | modifier | 3 | 0 | — | Dodge chance +1/2/3 %. | `dodge_chance_add` 1/2/3 |
| V4 | **Opening** `veil_opening` | unlock `opening` | 1 | 2 | V1 | Unlocks Opening: your next swing deals 135 % of a base blade hit, 180 % from behind or in Parry's window; 8 s cooldown, 5 % mana. | — |
| V5 | **Deep Focus** `veil_deep_focus` | modifier | 3 | 2 | — | Paid blade skills, Parry and Close Dance cost 5/10/15 % less. | `cost_pct:blade` -5/-10/-15 |
| V6 | **Parry** `veil_parry` | unlock `parry` | 1 | 6 | — | Unlocks Parry: a shield of 10 % of a base health pool for 2 s, and Opening's window opens for 3 s; 12 s cooldown, 4 % mana, 0.5 s recovery. | — |
| V7 | **Held Guard** `veil_held_guard` | modifier | 3 | 6 | V6 | Parry's window and shield last +0.25/0.50/0.75 s. | `duration_add:parry` 0.25/0.5/0.75 |
| V8 | **Flourish** `veil_flourish` | unlock `flourish` | 1 | 12 | V1 | Unlocks Flourish: an instant 90 degree, 3 m sweep; the 3 nearest take 80 % of a base blade hit each; 12 s cooldown, 8 % mana. | — |
| V9 | **Wide Edge** `veil_wide_edge` | modifier | 3 | 12 | V8 | Flourish +5/10/15 % of a base blade hit per target. | `flourish_add` 0.05/0.1/0.15 |
| V10 | **Turn the Blade** `veil_turn_the_blade` | modifier | 3 | 12 | V4, V6 | Opening in Parry's window +10/20/30 % of a base blade hit. | `opening_parry_add` 0.1/0.2/0.3 |
| V11 | **Shake Loose** `veil_shake_loose` | modifier | 3 | 16 | — | Sidestep also frees you from slows and roots; its cooldown -1/2/3 s. | `cooldown_sub:sidestep` 1/2/3; `sidestep_frees` 1/1/1 |
| V12 | **Close Dance** `veil_close_dance` | ultimate `close_dance` | 1 | 20 | V4, V6 | Unlocks Close Dance: for 6 s your blade swings deal +35 % of a base blade hit, and a shield of 15 % of a base health pool; 60 s cooldown, 14 % mana, 0.25 s recovery. | — |
| V13 | **Cutting Rhythm** `veil_cutting_rhythm` | modifier | 3 | 20 | V12 | Close Dance's swing bonus +5/10/15 % of a base blade hit. | `close_dance_add` 0.05/0.1/0.15 |
| V14 | **Travel Worn** `veil_travel_worn` | modifier | 3 | 6 | — | Max health +3/6/9 %. | `max_hp_percent_add` 3/6/9 |

Consumers: `grug_abilities/scout.lua` (every blade skill and
`opening_parry_add`, `flourish_add`, `close_dance_add`, shares of M) and
`grug_classes/scout.lua` (Shake Loose's `sidestep_frees`). Fine Edge's
`damage_pct:blade` reaches Strike and Bladecraft's swing as well (the swing
path applies it to the plain swing by the definition's tags). Parry opens
Opening's window `parry` at the cast (no hit detection); Opening is
empowered from behind (the target's rear half-plane) **or** in that window,
one bonus, never two, and Turn the Blade adds only in the window. Close
Dance's window `close_dance` adds its share to every plain blade swing
(Strike, Bladecraft, an uncharged Opening) through the swing callback, not
to Opening's charged hit; Flourish never crits.

### 2.9 Count

| | Nodes | Ranks | Unlocks | Transforms | Windows | Modifiers | Ultimate |
|---|---:|---:|---:|---:|---:|---:|---:|
| Bulwark | 14 | 33 | 2 | 2 | 0 | 9 | 1 |
| Ruin | 14 | 33 | 2 | 1 | 0 | 10 | 1 |
| Ember | 13 | 32 | 3 | 0 | 0 | 9 | 1 |
| Rime | 14 | 33 | 2 | 2 | 1 | 8 | 1 |
| Mercy | 13 | 33 | 3 | 0 | 1 | 8 | 1 |
| Reckoning | 14 | 34 | 3 | 0 | 0 | 10 | 1 |
| Quarry | 13 | 32 | 3 | 0 | 1 | 8 | 1 |
| Veil | 14 | 33 | 3 | 1 | 0 | 9 | 1 |
| **Total** | **109** | **263** | **21** | **6** | **3** | **71** | **8** |

The 74 modifier and window nodes have their own talent icons; the 35
granting nodes show their skill's icon. The 25 skills new in Round 53 and
the 19 redrawn ones make 44 skill icons ([node list](../planning/class-redesign/node-list.md) §3).

### 2.10 Level-proof values

A flat "+N" added before the damage scalar fades with level (Round 35,
the user's ruling of 2026-10-05), so every talent value is a share of
something that already grows with the level:

- **Damage** adds are coefficients of the class's unit (D, S, R, M, a Smite
  hit), which the one level scalar of `deal_ability_damage` or the swing
  scales once; `damage_pct` is a share of the untalented damage. The
  Priest's "base hit" adds are `B(L)` of the damage fit
  (`grug_core.baseline_melee_total`, [combat_stats.md](combat_stats.md) §2)
  times the caster weapon's spell base over an own-level one's, so an
  own-level staff or wand keeps the number and none halves it (Round 46).
- **Armor** is the one level-scaled shared key: `armor_percent_add` stores
  a percentage of `K(L)` and `get_talent_bonus` answers with the rating at
  the player's level (`graph.LEVEL_SCALED_KEYS`, `graph.level_amount`);
  Rime Mantle's and Unbroken's armor is a share of `K(L)` in their kits.
- **Healing and absorbs** add percentage points to a share of the
  class-neutral base pool P; the support factor Q (gear Intelligence over a
  base hit, Round 36) multiplies the result where the kit uses it, and the
  damage scalar never touches it. The Warrior's absorbs and Recover use
  the support factor as well; Rime Mantle's, Parry's and Close Dance's
  shields are flat shares of P.

The node tooltip on the page shows the armor and pool amounts at the
viewer's level for every rank.

**Crit.** Areas never crit (`opts.no_crit` of `deal_ability_damage`, the
calculator's model): Ice Wave, Ice Nova, Meteor, Fire Rain, Winter Field,
Fireball's splash, Censure, Flourish and Split Shot's splash. Direct hits,
Arrowfall's arrows and Broadstroke's other targets may crit. Healing,
shields and Word of Ruin's heal never crit. Every cap of
[combat_stats.md](combat_stats.md) §2 holds: no node raises a cap or
grants an immunity.

### 2.11 Names (rulings 5 and 21)

Talent names must not remind of an existing game (ruling 5), and the
overall picture matters, single common words are not protected (ruling
21). The tree names stay by ruling 5. Generic genre words stay (Hamstring,
Smite, Rebuke, Blink, Fireball, Taunt, Split Shot, Ice Nova, Censure); the
user decided the names of the node list on 2026-10-19 and 2026-10-20 (True
Draw, Rime Mantle, Iron Hail and Lasting Armor final). The audit of the
former names is in the
[delivery record](../archive/design/skill-trees-wp11-delivery.md) section C.
New names follow AGENTS.md "Naming".

---

## 3. Data model and seams

### 3.1 Where talents live

`grug_classes` owns the talents: it owns the class registry and the
per-player derived stats every numeric talent touches, and both
`grug_inventory` and `grug_abilities` depend on it.

- `grug_classes/talent_graph.lua` (`grug_classes.graph`): the registry, the
  vocabulary, the rules (gates, prerequisites, spend, reset, parse) and the
  load-time audit (§3.12).
- `grug_classes/talent_graph_{mage,warrior,priest,scout}.lua`: one data
  file per class, its vocabulary and its two trees.
- `grug_classes/talents.lua`: loads and audits the graph, the point budget,
  the store and its cache, the accessors, spend and respec, the level-drop
  reset and the read-only `/talents`.
- `grug_classes/talent_graph_ui.lua` and `talents_ui.lua`: the page
  (`graph.page_content`) in the Talents & Skills tab and the paid respec
  (`grug_classes.buy_respec`); for these `grug_classes` depends on `sfinv`
  and `grug_money`.
- `grug_classes/talent_windows.lua`: the readiness windows (§3.2).

### 3.2 The one hook

```lua
-- The summed rank value of `key` over the player's ranks: a shared key, a
-- class key or "<family>:<param>"; 0 when none. A level-scaled key
-- (armor_percent_add) answers with its amount at the player's level.
function grug_classes.get_talent_bonus(player, key)
```

It is the deliberate twin of `grug_classes.get_race_perk`, down to the stub
override for mods below `grug_classes` (`grug_core.get_talent_bonus`). A
node's `effects` hold the value at each rank, not an increment per rank; the
parsed cache pre-sums them in registration order, so a read is one table
index.

- **Shared keys** (`graph.SHARED_KEYS`): `armor_percent_add`,
  `max_hp_percent_add`, `max_mana_percent_add`, `crit_chance_add` and
  `dodge_chance_add`, read by `grug_quality`'s raw armor and `stats.lua`.
- **Class keys** (`graph.register_class_vocabulary`, one call per class):
  each names its consumer, which reads it in the kit (§2's tables).
- **Family keys** (`graph.KEY_FAMILIES`: `damage_pct`, `cost_pct`,
  `cooldown_sub`, `radius_add`, `duration_add`, `range_add`) with a param
  the class registered, a tag or an ability id.
  `grug_abilities.family_bonus(player, def, family)` sums a family over the
  definition's id and its tags (a transformation by its own). The shared
  cast path applies `cost_pct` (`effective_cost`, then the definition's
  `cost_adjust`), `cooldown_sub` (`effective_cooldown`, never below 0) and
  `range_add` (`get_range`), and the tooltip shows them; the swing path
  charges a proc the same `effective_cost` and adds `damage_pct` to the
  plain swing; a kit reads `damage_pct`, `radius_add` and `duration_add`
  itself.

A second accessor answers unlock questions:
`grug_classes.talent_rank(player, node_id)` (the kit grant, the gates and
the UI, never a numeric consumer); `grug_classes.talent_ranks(player)`
returns the cached ranks table itself, read only.

**Readiness windows** (`talent_windows.lua`, keyed by any id):
`grug_classes.open_window(player, id, {duration, icd, value, label})`,
`get_window`, `consume_window` and `window_icd_ready`; the internal cooldown
runs on the monotonic clock in memory, and leave, death and respec end the
open windows (`clear_talent_windows`). Each shows its status icon
(`grug_core.status_icons.WINDOWS`). The seven windows: `cold_shock` (Cold
Shock), `retort` (Retort), `clear_conscience` (Clear Conscience),
`follow_the_line` (Follow the Line), `parry` (Parry), `ruination`
(Ruination) and `close_dance` (Close Dance). A window node's ranks set the
window's value (Cold Shock, Clear Conscience, Follow the Line); Parry,
Ruination and Close Dance open theirs at their cast, Retort on a hit taken.

**The swing callback** (`grug_abilities.register_on_swing`, from a class
file) is how a class's windows reach every landed swing: a damage
multiplier or add before the one scaling pass, extra rage and an
`on_landed` hook, the last two only when the swing lands
([module guide](../technical/module-guide.md#combat-and-classes)).

### 3.3 Persistence

- One player-meta **string** key, `grug_classes:talents`, holding the
  graph's `<node id>=<rank>` pairs in registration order, separated by
  commas: `ember_fire_mastery=4,ember_fireball=1`. The key kept its name
  from the old trees; their ids carry no tree prefix, so a 0.52 string reads
  as no rank at all, and the 0.53.0 step deleted it anyway.
- One player-meta **integer** key, `grug_classes:respec_used`, 0 until the
  first successful reset and 1 thereafter (the 0.53.0 step cleared it).
- Parsed into a per-player runtime cache, invalidated on spend, respec, a
  level change, the first class pick and leave.
- **The read path validates, it does not trust** (`graph.parse`): unknown
  ids and other classes' nodes are dropped, ranks clamped to the node's
  count, gates and prerequisites enforced, and the total refunded down to
  `floor(level / 2)`, deepest first (the highest gate, then the latest
  registration), so two servers agree. A hand-edited string cannot buy an
  ultimate at level 4.
- No point balance is persisted; the readiness windows and their internal
  cooldowns live in memory only.

### 3.4 Granting and transforming a skill

A newly ranked unlock or ultimate adds its ability to the Talents & Skills
catalogue and places nothing (Round 50 D1, class plan C8): the message feed
says "<Skill> unlocked. Drag it from Talents & Skills onto your hotbar."
Each granting node's ability is an ordinary `grug_abilities` registration
with `talent_gated = true` and `talent = "<node id>"`; the shared
`grug_abilities.is_unlocked(player, id)` predicate checks the class and a
positive rank, and catalogue listing, recovery, normalization and actual
cast or swing execution all use it. A forged or stale representation never
grants an ability.

**A transform** is an ability with `transforms = "<base id>"`: while its
node has a rank it replaces the base in place on hotbars A and B (and in
bags), shares the base's cooldown key, and `is_unlocked` is false for the
replaced base; a respec swaps it back. A class's own basic attack is a
transform of the universal Strike without a talent (Fiery Spark, Smite);
the Scout's Loose replaces nothing and is marked `basic_attack = true`.

Spending, respec and every join call `grug_abilities.normalize_kit(player)`:
it removes stale or locked representations, swaps transforms in place and
refreshes surviving item metadata without filling discarded slots. A
transform the player already holds in a bag wins, and the locked base on
the hotbar is then removed instead of swapped. Modifier nodes need no item:
the next cast reads the current rank.

### 3.5 UI

Since Round 44 one tab, **Talents & Skills**, shows the class's talents;
`grug_skills` adds the skill catalogue row under them in a "Skills" box,
scrolling sideways once it holds more than eight skills (Round 52), and the
shared frame the short inventory below. Since Round 53 the talents are the
graph page (`graph.page_content`, §3.12): one inner tab per tree, the
tree's background, the nodes on their gate rows with their connection
lines, buy on click, the refusal reason of a locked node, the respec
control with its price and an inline confirmation.

- A click on an available node spends one point for one rank at once;
  there is no preselection or purchase confirmation. A click on a node
  that cannot be bought selects it and shows its text and the reason in
  the strip above the skill row.
- Fixed button fields map only to the nodes of the submitting player's own
  class; names and descriptions are escaped; no free-text field enters a
  purchase.
- Combat statistics are on Character, not Talents; Help explains caps and
  formulas.
- `/talents` is a read-only rank summary (node ids, ranks and the refusal
  of each locked node); no command changes talent state.

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
load-time audit of §3.12 enforces the graph's shape; the current fixtures
(`tools/r53_live` for the store, the accessors and the page, one
`tools/r53_<class>` per class) are listed in
[tools/README.md](../../tools/README.md).

### 3.8 What changes where (archived)

The WP11 file table is in the
[delivery record](../archive/design/skill-trees-wp11-delivery.md) §3.8; the
consumers of the graph's keys are named in §2 and in each class key's
vocabulary entry.

### 3.9 The movement aggregator (ruling 11)

Talents and skills that change movement go through one central aggregator,
`grug_core/movement.lua`; it is the only writer of the player's
`physics_override` speed and jump. The Scout's Sprint adds a speed
modifier, the slows of Ice Wave, Cold Spark, Winter Field, Hamstring,
Charge's Halt and Snare Shot add negative ones, Ice Nova roots, and Shake
Loose clears the negative modifiers and roots on the Scout at Sidestep's
cast (`clear_negative_move_modifiers`). No skill grants movement immunity
since Round 53 (Hold Ground's went with the old trees). The rules (ruling
11, combination by ruling 26):

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
  positive modifier. Jump is not affected. The current stance: eating ×0.35
  (`grug_food`; the bow draw's ×0.5 went with the draw in Round 53); each
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
grug_core.add_absorb(target, "shield_spell", amount, 10)
grug_core.add_absorb(target, "hold_ground", amount, 5)
grug_core.get_absorb(target)        -- the total
```

- **Soak order: shortest remaining duration first**, so a shield about to
  expire is the one that is spent.
- **Re-casting the same name refreshes that contribution** and does not add a
  second one, so a recast Shield replaces its own contribution rather than
  stacking.
- **The total is capped at the target's maximum HP**: a new contribution
  absorbs at most what the others leave below that cap.
- `grug_core.get_absorb(player)` returns the sum, which the central
  hp-change modifier's soak and the `shield` status read.
- Contributions are cleared on death and leave.

Writers: the Priest's Shield, the Warrior's Hold Ground and Unbroken, the
Mage's Rime Mantle, the Scout's Parry and Close Dance, and the Last Light
Locket's trinket special (`items_crafting.md` §6.2). Each shows as the one
`shield` status icon.

### 3.12 The graph talents of round K (Round 52, live since Round 53)

Round 52 ([class plan](../planning/round52-class-plan.md) C6, C12, D3–D5,
D7) built the talent engine and page of the class rework beside the old
registry; Round 53 ([plan](../planning/round53-plan.md) §4 "LIVE", K3–K5)
made them the live talents. The trees are the eight of §2: 109 nodes,
32–34 ranks per tree (Warding Faith at 5 ranks, so Mercy has 33). This
section is the engine and the page; §1–§3.5 are the rules they enforce.

**The store** (`talents.lua`): the meta key `grug_classes:talents` holds
the graph's string, read through `graph.parse` at the character's class and
level; an old id (no tree prefix) reads as no rank. `get_talent_bonus`
sums a key over the ranks (a shared key, a class key or
`<family>:<param>`; `armor_percent_add` answers in rating points at the
player's level, `graph.level_amount`), `talent_rank` takes a node id,
spending and the full reset go through `graph.spend` and `graph.reset`,
and the level-drop reset, the "point earned" line and `/talents` read the
graph. Respec prices are unchanged (§1.4).

**The data format** (`grug_classes.graph`, `talent_graph.lua`):

```lua
graph.register_class_vocabulary("mage", {
    keys = {},                         -- class keys: {key = "the consumer"}
    params = {"fire", "fireball", …},  -- tags and ability ids families may name
})

graph.register_tree({
    id = "ember", class = "mage", name = "Ember", description = "…",
    ranks = 32,                        -- the declared rank total, audited
    example = "F1x4 F4 F2x3 …",        -- a worked 30-point build, audited
    nodes = {
        {id = "ember_fire_mastery", code = "F1", name = "Fire Mastery",
         type = "modifier", ranks = 4, gate = 0, col = 3,
         effects = {["damage_pct:fire"] = {5, 10, 15, 20}},
         description = "…"},
        {id = "ember_fireball", code = "F4", name = "Fireball", type = "unlock",
         ability = "fireball", ranks = 1, gate = 2, col = 3,
         requires = {"ember_fire_mastery"}, description = "…"},
        …
    },
})
graph.audit()
```

- **A node** has an id `<tree>_<name>` (Round 53; the codes stay in the
  docs), the node list's `code`,
  a `type` (`modifier`, `window`, `unlock`, `transform` or `ultimate`), a
  rank count, a **gate** (one of `graph.GATE_ROWS`: 0, 2, 6, 10, 12, 16,
  20; the page draws one row per gate), a column `col` 1–5, any number of
  prerequisites `requires` (each needs **one** rank, not a full chain) and
  its effects as data, one value per rank. A granting node (`unlock`,
  `transform`, `ultimate`) names its `ability` and has one rank; a
  transform's ability carries the ability-side `transforms` field
  ([module guide](../technical/module-guide.md#combat-and-classes)); each
  tree has exactly one ultimate, at gate 20.
- **Effect keys** come from three places: the shared stat keys
  (`graph.SHARED_KEYS`: armour, max HP, max mana, crit and dodge, with
  today's names and units), the class's own keys
  (`register_class_vocabulary`, one call per class, so round K's class
  lanes never edit one shared list: D4), and the families
  `<family>:<param>` (`damage_pct`, `cost_pct`, `cooldown_sub`,
  `radius_add`, `duration_add`, `range_add`) whose param is a tag or an
  ability id the class registered (the old registry's `EFFECT_KEYS` and
  `WINDOW_KEYS` went with it in Round 53).
- **The gate rule:** a node's gate counts the ranks in its tree's nodes of
  a **lower** gate. For a build bought in order that is the points spent
  in the tree; on a stored string it also rejects nodes of one gate that
  only "pay" for each other. One function (`graph.structure_refusal`)
  gives the reason on both paths, so the spend refusal and the read path
  say the same ("Meteor needs 12 points in Ember (you have 8).", "… needs
  a rank in …").
- **The rules** work on a ranks table `{node id = rank}`:
  `graph.spend_refusal(class, ranks, id, budget)` and `graph.spend` (one
  rank), `graph.reset` (everything back), `graph.parse(class, raw,
  budget)` (the read path: unknown and foreign ids dropped, ranks clamped,
  gates and prerequisites enforced, the total refunded deepest first),
  `graph.serialize` (`id=rank,…` in registration order) and
  `graph.apply_order` (a build in the node list's notation). Points stay
  `floor(level / 2)`, 30 at level 60 (`graph.POINTS_MAX`).
- **The audit** (`graph.audit()`, at load; a failure stops the server):
  types, ranks, gates and columns, one node per cell, prerequisites inside
  the tree and of no higher gate, no cycle, every node reachable within
  30 points, the declared rank total (and more than 30, so no tree can be
  bought out), the vocabulary and the sample build.

The data is one file per class, `talent_graph_<class>.lua` (Round 53;
Round 52's preview file and its admin command `/talent_preview` are gone).

**The page** (`graph.page_content`, in Talents & Skills since Round 53, in
the real coordinates of the sfinv frame; D5, `graph.PAGE`):

- one inner tab per tree, as buttons in the header row (y 0.15–0.75,
  2.6 wide) beside the points text and the respec control: the selected
  style of the Character page's mode buttons; the tab lives in the sfinv
  context, never stored; a click on a node buys a rank or, refused,
  selects it with the reason;
- the tab content rectangle **13 × 5.5** at (0.25, 0.95): the tree's
  background `grug_classes_tree_<tree>.png` (1040 × 440 px, 80 px per
  unit) or a plain dark box while none ships; seven gate rows of 0.6-high
  nodes with 0.18 between them, centred, the gate number at the left;
  five columns 2.16 wide;
- connection lines of `box[]` segments (0.06 thick) under the nodes,
  orthogonal (down, across in the gap above the child's row, down), gold
  once the parent has a rank;
- a node shows its icon (`grug_classes_talent_<name>.png`, named by the
  id without its tree prefix, K5; for a granting node its skill's
  `grug_abilities_skill_<ability>.png`) with
  its rank beside it, or its name and rank as text while no icon ships;
  its look follows the node styles, and the tooltip names the effect (for
  armor and the pools with every rank's amount at the viewer's level) and,
  when locked, the reason;
- the selected node's text (or the hint, or a respec notice) in a strip at
  6.50–7.15, above the skill row.

The art shipped with the user's picks of 2026-10-19/20 (D7): the eight
backgrounds and the 74 talent icons in Round 52, the 25 icons of the new
skills in Round 53, so every node shows an icon. 0.53.1 replaced 36 of
them with the user's picks of the Round 53 clarity redraw (2026-10-20): 26
skill icons, eight of them the 0.51 icons again, and 10 talent icons (the
`LICENSE-media.md` of `grug_abilities` and `grug_classes`).

## 4. Implementation lanes (archived)

WP11 shipped in four lanes: X1 the model, X2 the numeric consumers, X3 the
keystones and capstones (Round 12), X4 the UI, level-up and respec
(2026-09-17); the Scout's trees came with Round 11. Their scope table is in
the [delivery record](../archive/design/skill-trees-wp11-delivery.md) §4.

---

## 5. The user's rulings (2026-09-16)

The binding frame of the WP11 design, one line each. The full texts, the
order in which they were given and what each replaced are in the
[delivery record](../archive/design/skill-trees-wp11-delivery.md) §5. **Round
K (Round 53) replaced the tree shape:** rulings 2, 3, 13, 17, 18 and 19 are
superseded by the graph of §1 under the user's rulings of 2026-10-19 and
2026-10-20 ([continuation §4a](../planning/class-redesign/continuation.md#4a-user-rulings-of-2026-10-19-a-maximally-simple-rework),
[delivery plan](../planning/class-redesign/delivery-plan.md) §6,
[round 53 plan](../planning/round53-plan.md) §2); the others stand.

1. **Talent points:** one every 2 levels, the first at level 2, so 30 at
   level 60; "two thirds" was a rough guideline (§1.3).
2. *(Superseded in Round 53.)* **Tree size:** about 30 ranks per tree, two
   playstyle directions (chains) per tree, both gate kinds (points in the
   tree and hard chains), rank counts 3–5 by strength; a full tree is not
   forced. Now: 32–34 ranks, gates and one-rank prerequisites (§1.2).
3. *(Superseded in Round 53.)* **Keystones and capstones:** per tree two
   keystones and one capstone. Now: unlocks, transforms and one ultimate
   per tree (§1.1).
4. **No class trainer:** new skills come only from the tree; the base kit at
   class choice stays (since Round 53 each class's own starters, §1.1);
   respec for money in the talent UI, no NPC (§1.4, §3.5).
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
    stronger the limit. Sprint stays usable in combat on a long cooldown
    ([scout.md](scout.md) §2). Since Round 53 no talent exceeds a cap
    (§2.10).
11. **Speed ownership:** one central aggregator with named modifiers and
    their own durations; a root is a hard flag; mounts stay outside (§3.9).
12. **The Scout as simple as possible:** no invisibility in version 1, no
    poison, no traps, a base kit from existing mechanics
    ([scout.md](scout.md)). Its "arrows ballistic, Fireball straight" half was
    overridden in Round 17: arrows and Fireball home on the release-time target.
13. *(Superseded in Round 53.)* **Per tree at most one keystone adds a new
    skill;** the other keystone improves or replaces a skill; the capstone is
    an effect or a replacement. Now: each tree unlocks two to four skills and
    one ultimate (§1.1).
14. **The Scout uses mana** ([scout.md](scout.md) §1).
15. **HUD:** a thin, point-accurate life bar and one mana-or-rage bar above
    the hotbar instead of hearts (`classes.md` §1).
16. *(A user finding — rage fills too fast — answered by ruling 25.)*
17. *(Superseded in Round 53.)* **A capstone has one rank.** Now every
    granting node, the ultimate included, has one rank (§1.2).
18. *(Kept in spirit by Round 53.)* **One capstone per level-60 character,**
    following implicitly from the tree's requirements, the first around
    level 40–44: one ultimate, at level 42 at the earliest (§1.3).
19. *(Superseded in Round 53.)* **Every class starts with Strike plus
    three;** Hamstring leaves the Warrior's base kit and returns as Ruin's
    keystone. Now: each class's own starters (§1.1), Hamstring a Ruin
    unlock (§2.2).
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

None in this file. The balance fix round after the user's first playtest
of the new kits and the round's open notes are in
[BACKLOG](../../BACKLOG.md#round-53-carry-overs) "Round 53 carry-overs";
open questions about talents (for example the "Word" names, BACKLOG DP-06)
under "Audit 2026-10 open questions". The closed decision record of revision 2 is in the
[delivery record](../archive/design/skill-trees-wp11-delivery.md) §6.

## 7. Tasks (closed)

The revision's task list for other files is closed; its rows and their status
are in the [delivery record](../archive/design/skill-trees-wp11-delivery.md)
section F.
