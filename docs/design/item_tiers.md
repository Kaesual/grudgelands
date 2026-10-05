# Item tiers: enchant values, recipes, upgrades, the crown, potions and money

**Status: approved by the user, version 2** (Round 33 lane DS, 2026-10-04;
version 2 follows the user's rulings of the same day on Crit and Dexterity,
profession families and two leftovers, marked "(v2)"). The user accepted every
recommended option of the preview: Intelligence stays weak for Priest heals,
attribute fractions count, repair factor ×1.0, crown fee 1 h of band-6 income,
no money fee for upgrades, elixirs worth two enchants, the Weak Healing Potion
heals a fixed 35 HP, one-faction signatures stay sell-only, the culture vendor
price bands as proposed, Ornament Components removed, Cut Citrine is the T1
trinket gem (the Cut Quartz recipe goes). The user's rulings are
[round33-plan.md](../planning/round33-plan.md) §2; this file turns them into
the numbers lanes C4 (enchant tiers, upgrades, crown) and C5 (vendors,
potions, economy) implemented in Round 33; where the shipped game differs,
an "As built" note says so. **Round 36 (lane K, the user's picks
2026-10-05):** gear Intelligence now raises heals and absorbs like a Mage's
Fireball (§1.3, Appendix A), replacing the "Intelligence stays weak" choice
above, and the Dexterity curve's `c` fell from 0.0019 to 0.0011 so the
Scout's full set sits at the Warrior's (§1.3, §1.4).
Every table between `generated` markers is printed by a script in
[`tools/r33_ds/`](../../tools/r33_ds/) and refreshed by
`python3 tools/r33_ds/build_doc.py` (`--check` fails when this file is stale).

Since Round 33 this file replaces the fixed crafted values and the found
roll windows of [items_crafting.md](items_crafting.md) §6.3, §6b.2 and
[crafting_equipment_revision.md](crafting_equipment_revision.md#enchanting),
the alchemy table of items_crafting.md §3.6, the 20 % repair factor of
[durability_repair.md](durability_repair.md#price) and
[economy.md](economy.md) §4, the crit rules of
[combat_stats.md](combat_stats.md) §2 (§1.0 below) and the bow and spellbook
ownership of [professions.md](professions.md) §2 (§3.3 below).

Tiers: T1 = item or character level 1–10 … T6 = 51–60, T7 = 61–70 (boss
drops and crowned items only).

## 1. Enchant values

### 1.0 Crit and Dexterity (v2, user ruling 2026-10-04)

- **Dexterity gives 0.05 percentage points of Crit** (was 0.1) and, unchanged,
  0.1 points of Dodge per point. Base Crit stays 5 %; both caps stay 30 %.
- **A crit deals ×2** (was ×1.5), for damage and for heals (`grug_core/combat.lua`
  melee, ability and heal crit rolls; `grug_classes/stats.lua`
  `get_crit_chance_raw`).
- Without gear every class deals and heals about **+2.4 %** more on average
  (the expected factor goes from `1.025 + 0.0005 Dex` to `1.05 + 0.0005 Dex`):

<!-- generated: basechange -->
| Level | Warrior | Scout | Mage | Priest (heal) | Priest (Smite) |
|---:|---:|---:|---:|---:|---:|
| 1 | +2.4 % | +2.4 % | +2.4 % | +2.4 % | +2.4 % |
| 10 | +2.4 % | +2.4 % | +2.4 % | +2.4 % | +2.4 % |
| 30 | +2.4 % | +2.4 % | +2.4 % | +2.4 % | +2.4 % |
| 60 | +2.4 % | +2.3 % | +2.4 % | +2.4 % | +2.4 % |
<!-- end generated -->

- **Crit talents** are worth about twice as much: each crit point now adds
  about 1 % damage instead of 0.5 %; Round 35 then doubled their points to 2
  per rank ([skill_trees.md](skill_trees.md)). The Warrior's Ruination window
  (+20 points, cap 50 %, since Round 35 15 s every 60 s) rises from +9 % to
  +18 % damage while it lasts; a capstone burst, still bounded by its 50 %
  cap. Whitehot (triggered by a Fireball crit) fires a little later on
  average, because base crit from Dexterity is lower. Round 33 changed no
  talent for it; at its 50 % cap a Ruination hit averages ×1.5 instead of ×1.25,
  the one number to watch in a playtest.

<!-- generated: talents -->
| Talent | Effect | Class | Gain today (×1.5) | Gain new (×2) |
|---|---|---|---:|---:|
| Keen Edge 5/5 | +10 crit points | Warrior | +4.7 % | +9.2 % |
| Firebrand 4/4 | +8 crit points | Mage | +3.8 % | +7.4 % |
| Cold Eye 4/4 | +8 crit points | Scout | +3.7 % | +7.2 % |
| Ruination window | +20 crit points, cap 50 %, 15 s per 60 s | Warrior | +9.4 % | +18.4 % |
<!-- end generated -->

### 1.1 The rule

Every enchant, crafted or dropped, stores its stat and its tier (1–7). Its
value is

```
L     = clamp(min(item level, 10 × enchant tier), 1, 70)
value = round(a + b × L + c × L², decimals), at least `minimum`
```

with `round(x, d) = floor(x × 10^d + 0.5) / 10^d` (Lua `math.floor`). The
value is recomputed whenever the item level or the enchant tier changes
(upgrade, crown); it is never stored as a free number.

- **Crafted** enchants have the recipe's tier (T1–T6).
- **Dropped** enchants have the item's tier: `min(7, floor((ilvl − 1) / 10) + 1)`.
  There is no random value window any more: a found enchant is worth exactly
  what the formula gives at its item level.
- **The crown** raises every enchant on the item by one tier (§4).

<!-- generated: coefficients -->
| Stat | a | b | c | decimals | minimum |
|---|---:|---:|---:|---:|---:|
| Strength | 0.8 | 0.15 | 0.0025 | 0 | 1 |
| Dexterity | 0.8 | 0.13 | 0.0011 | 0 | 1 |
| Intelligence | 0.8 | 0.15 | 0.0025 | 0 | 1 |
| Crit % | 1.7 | 0.044 | 0 | 1 | 0 |
| Attack speed % | 1.6 | 0.04 | 0 | 1 | 0 |
| Max HP % | 1.6 | 0.04 | 0 | 1 | 0 |
| Max Mana % | 2.2 | 0.03 | 0 | 1 | 0 |
| Dodge % | 1.5 | 0.032 | 0 | 1 | 0 |
| Armor rating | 0 | 0.08 | 0 | 1 | 0.5 |
<!-- end generated -->

The percentage stats, armor rating included, are shown and summed with one
decimal (today HP, Mana, attack speed and armor are whole numbers); without
it T6, T7 at 65 and T7 at 70 would round to the same value.

*Rationale:* one enchant is worth about the same in its kind for the class
that wants it (plan §2.9), and that worth grows with the item level, from
about 2 % at level 10 to 4 % at 60 and 4.4 % at 70:
`target(L) = 1.6 % + 0.04 % × L` of damage, healing or effective HP. A fully
damage-enchanted level-60 Warrior gains about +47 % damage at item level 60
and +69 % at 70 (table "A full set at level 60"), the order of the design's
+50–60 % endgame ceiling
([combat_stats.md](combat_stats.md) §2). Crit follows a crit point's ×2 worth
(about 1 % damage per point); Dexterity has its own curve (§1.4).

<!-- generated: values -->
### Values at the tier tops (upgraded or found at the top)

| Stat | Formula | T1 (10) | T2 (20) | T3 (30) | T4 (40) | T5 (50) | T6 (60) | T7 (65) | T7 (70) | Today T1 → T6 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Strength | 0.8 + 0.15 × L + 0.0025 × L², whole number, at least 1 | 3 | 5 | 8 | 11 | 15 | 19 | 21 | 24 | 2 / 3 / 5 / 7 / 9 / 10 |
| Dexterity | 0.8 + 0.13 × L + 0.0011 × L², whole number, at least 1 | 2 | 4 | 6 | 8 | 10 | 13 | 14 | 15 | 2 / 3 / 5 / 7 / 9 / 10 |
| Intelligence | 0.8 + 0.15 × L + 0.0025 × L², whole number, at least 1 | 3 | 5 | 8 | 11 | 15 | 19 | 21 | 24 | 2 / 3 / 5 / 7 / 9 / 10 |
| Crit % | 1.7 + 0.044 × L, one decimal | 2.1 | 2.6 | 3.0 | 3.5 | 3.9 | 4.3 | 4.6 | 4.8 | 0.5 / 0.8 / 1.2 / 1.6 / 2 / 2.5 |
| Attack speed % | 1.6 + 0.04 × L, one decimal | 2.0 | 2.4 | 2.8 | 3.2 | 3.6 | 4.0 | 4.2 | 4.4 | 4 / 6 / 8 / 10 / 12 / 14 |
| Max HP % | 1.6 + 0.04 × L, one decimal | 2.0 | 2.4 | 2.8 | 3.2 | 3.6 | 4.0 | 4.2 | 4.4 | 1 / 2 / 2 / 3 / 4 / 5 |
| Max Mana % | 2.2 + 0.03 × L, one decimal | 2.5 | 2.8 | 3.1 | 3.4 | 3.7 | 4.0 | 4.2 | 4.3 | 1 / 2 / 2 / 3 / 4 / 5 |
| Dodge % | 1.5 + 0.032 × L, one decimal | 1.8 | 2.1 | 2.5 | 2.8 | 3.1 | 3.4 | 3.6 | 3.7 | 0.5 / 0.8 / 1.2 / 1.6 / 2 / 2.5 |
| Armor rating | 0.08 × L, one decimal | 0.8 | 1.6 | 2.4 | 3.2 | 4.0 | 4.8 | 5.2 | 5.6 | 1 / 2 / 3 / 4 / 5 / 6 |

### Values on plain bases (vendor or crafted item level 3/10/20/30/40/50)

| Stat | T1 (3) | T2 (10) | T3 (20) | T4 (30) | T5 (40) | T6 (50) |
|---|---:|---:|---:|---:|---:|---:|
| Strength | 1 | 3 | 5 | 8 | 11 | 15 |
| Dexterity | 1 | 2 | 4 | 6 | 8 | 10 |
| Intelligence | 1 | 3 | 5 | 8 | 11 | 15 |
| Crit % | 1.8 | 2.1 | 2.6 | 3.0 | 3.5 | 3.9 |
| Attack speed % | 1.7 | 2.0 | 2.4 | 2.8 | 3.2 | 3.6 |
| Max HP % | 1.7 | 2.0 | 2.4 | 2.8 | 3.2 | 3.6 |
| Max Mana % | 2.3 | 2.5 | 2.8 | 3.1 | 3.4 | 3.7 |
| Dodge % | 1.6 | 1.8 | 2.1 | 2.5 | 2.8 | 3.1 |
| Armor rating | 0.5 | 0.8 | 1.6 | 2.4 | 3.2 | 4.0 |

### A full set at level 60

| Item level | Warrior, damage set | Scout, damage set | Mage, damage set (short fight / mana-bound) | Warrior, 5 × HP |
|---:|---:|---:|---:|---:|
| 60 | +47 % | +49 % | +45 % / +80 % | +20 % |
| 65 | +57 % | +59 % | +50 % / +88 % | +27 % |
| 70 | +69 % | +69 % | +57 % / +97 % | +32 % |

Damage sets: an attribute on every one of the eight items, two Crit enchants, Attack speed on the weapon (Warrior, Scout); the Mage's remaining six channels Mana. Against the same character in plain item-level-60 gear (Appendix A).
<!-- end generated -->

### 1.2 The class check

Each cell is the relative gain of one enchant at the point's item level for
a character of that level wearing gear of that item level (T7 rows: a
level-60 character with item level 65 or 70). Models and code references are
in Appendix A; `python3 tools/r33_ds/stat_values.py --check` fails when a
checked kind spreads by more than ×1.35 (×1.5 at T1 middle, where one or two
attribute points cannot be finer).

<!-- generated: classcheck -->
#### Warrior

Gain in % of one enchant at the point's item level (damage, healing or effective HP against a same-level mob).

| Point | Target | damage: Str | damage: Crit | damage: Attack speed | damage (battle axe): Str | damage (battle axe): Crit | damage (battle axe): Attack speed | survival: HP | survival: Armor (2H) | survival: Armor (shield) | survival: Armor (shield, foe +5) | Dex rider: Dex → damage | Dex rider: Dex → EHP |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| T1 mid | 1.8 | 2.1 | 1.8 | 1.7 | 1.5 | 1.8 | 1.7 | 1.8 | 1.5 | 1.2 | 1.1 | 0.0 | 0.1 |
| T1 top | 2.0 | 2.2 | 2.0 | 1.9 | 1.6 | 2.0 | 1.9 | 2.0 | 2.1 | 1.5 | 1.4 | 0.1 | 0.2 |
| T2 mid | 2.2 | 2.5 | 2.3 | 2.1 | 1.8 | 2.3 | 2.1 | 2.2 | 2.6 | 1.8 | 1.8 | 0.1 | 0.3 |
| T2 top | 2.4 | 2.5 | 2.4 | 2.3 | 1.8 | 2.4 | 2.3 | 2.4 | 3.0 | 2.1 | 2.0 | 0.2 | 0.4 |
| T3 mid | 2.6 | 2.5 | 2.6 | 2.5 | 1.8 | 2.6 | 2.5 | 2.6 | 3.4 | 2.3 | 2.2 | 0.2 | 0.5 |
| T3 top | 2.8 | 2.9 | 2.8 | 2.7 | 2.1 | 2.8 | 2.7 | 2.8 | 3.6 | 2.4 | 2.4 | 0.3 | 0.6 |
| T4 mid | 3.0 | 2.9 | 3.0 | 2.9 | 2.2 | 3.0 | 2.9 | 3.0 | 3.8 | 2.5 | 2.5 | 0.3 | 0.7 |
| T4 top | 3.2 | 3.2 | 3.3 | 3.1 | 2.4 | 3.3 | 3.1 | 3.2 | 4.0 | 2.7 | 2.6 | 0.3 | 0.8 |
| T5 mid | 3.4 | 3.4 | 3.4 | 3.3 | 2.5 | 3.4 | 3.2 | 3.4 | 4.1 | 2.7 | 2.7 | 0.4 | 1.0 |
| T5 top | 3.6 | 3.5 | 3.6 | 3.5 | 2.7 | 3.6 | 3.4 | 3.6 | 4.3 | 2.8 | 2.7 | 0.4 | 1.1 |
| T6 mid | 3.8 | 3.8 | 3.8 | 3.7 | 2.8 | 3.8 | 3.6 | 3.8 | 4.3 | 1.8 | 2.8 | 0.5 | 1.2 |
| T6 top | 4.0 | 3.9 | 4.0 | 3.9 | 2.9 | 4.0 | 3.8 | 4.0 | 4.4 | 0.4 | 2.3 | 0.6 | 1.4 |
| T7 65 | 4.2 | 4.1 | 4.2 | 4.1 | 3.0 | 4.2 | 4.0 | 4.2 | 4.6 | 0.0 | 2.4 | 0.6 | 1.5 |
| T7 70 | 4.4 | 4.5 | 4.4 | 4.3 | 3.3 | 4.4 | 4.2 | 4.4 | 4.8 | 0.0 | 2.5 | 0.6 | 1.6 |

#### Scout

Gain in % of one enchant at the point's item level (damage, healing or effective HP against a same-level mob).

| Point | Target | damage: Dex | damage: Crit | damage: Attack speed | survival: HP | survival: Dodge | Dex rider: Dex → EHP |
|---|---|---:|---:|---:|---:|---:|---:|
| T1 mid | 1.8 | 1.3 | 1.8 | 1.8 | 1.8 | 1.8 | 0.1 |
| T1 top | 2.0 | 1.9 | 2.0 | 2.0 | 2.0 | 1.9 | 0.2 |
| T2 mid | 2.2 | 2.5 | 2.2 | 2.2 | 2.2 | 2.1 | 0.3 |
| T2 top | 2.4 | 2.7 | 2.4 | 2.4 | 2.4 | 2.3 | 0.4 |
| T3 mid | 2.6 | 2.9 | 2.6 | 2.6 | 2.6 | 2.5 | 0.5 |
| T3 top | 2.8 | 3.0 | 2.8 | 2.8 | 2.8 | 2.8 | 0.6 |
| T4 mid | 3.0 | 3.3 | 2.9 | 3.0 | 3.0 | 2.9 | 0.8 |
| T4 top | 3.2 | 3.4 | 3.2 | 3.2 | 3.2 | 3.2 | 0.9 |
| T5 mid | 3.4 | 3.4 | 3.4 | 3.4 | 3.4 | 3.3 | 1.0 |
| T5 top | 3.6 | 3.5 | 3.5 | 3.6 | 3.6 | 3.6 | 1.1 |
| T6 mid | 3.8 | 3.7 | 3.7 | 3.8 | 3.8 | 3.9 | 1.3 |
| T6 top | 4.0 | 4.0 | 3.9 | 4.0 | 4.0 | 4.1 | 1.5 |
| T7 65 | 4.2 | 4.2 | 4.1 | 4.2 | 4.2 | 4.3 | 1.6 |
| T7 70 | 4.4 | 4.3 | 4.3 | 4.4 | 4.4 | 4.4 | 1.8 |

#### Mage

Gain in % of one enchant at the point's item level (damage, healing or effective HP against a same-level mob).

| Point | Target | damage: Int | damage: Crit | damage: Mana | survival: HP |
|---|---|---:|---:|---:|---:|
| T1 mid | 1.8 | 2.4 | 1.8 | 1.7 | 1.8 |
| T1 top | 2.0 | 2.6 | 2.0 | 2.0 | 2.0 |
| T2 mid | 2.2 | 2.8 | 2.3 | 2.3 | 2.2 |
| T2 top | 2.4 | 2.8 | 2.4 | 2.4 | 2.4 |
| T3 mid | 2.6 | 2.8 | 2.6 | 3.0 | 2.6 |
| T3 top | 2.8 | 3.2 | 2.8 | 3.1 | 2.8 |
| T4 mid | 3.0 | 3.3 | 3.0 | 3.3 | 3.0 |
| T4 top | 3.2 | 3.6 | 3.3 | 3.4 | 3.2 |
| T5 mid | 3.4 | 3.8 | 3.4 | 3.6 | 3.4 |
| T5 top | 3.6 | 4.0 | 3.6 | 3.7 | 3.6 |
| T6 mid | 3.8 | 4.2 | 3.8 | 3.9 | 3.8 |
| T6 top | 4.0 | 4.3 | 4.0 | 4.0 | 4.0 |
| T7 65 | 4.2 | 4.8 | 4.2 | 4.2 | 4.2 |
| T7 70 | 4.4 | 5.5 | 4.4 | 4.3 | 4.4 |

#### Priest

Gain in % of one enchant at the point's item level (damage, healing or effective HP against a same-level mob).

| Point | Target | healing: Int | healing: Crit | healing: Mana | damage (Smite): Int | damage (Smite): Crit | damage (Smite): Mana | survival: HP |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| T1 mid | 1.8 | 2.4 | 1.8 | 1.7 | 2.6 | 1.8 | 1.7 | 1.8 |
| T1 top | 2.0 | 2.6 | 2.0 | 2.0 | 2.8 | 2.0 | 2.0 | 2.0 |
| T2 mid | 2.2 | 2.8 | 2.3 | 2.3 | 3.1 | 2.3 | 2.3 | 2.2 |
| T2 top | 2.4 | 2.8 | 2.4 | 2.4 | 3.2 | 2.4 | 2.4 | 2.4 |
| T3 mid | 2.6 | 2.8 | 2.6 | 3.0 | 3.2 | 2.6 | 3.0 | 2.6 |
| T3 top | 2.8 | 3.2 | 2.8 | 3.1 | 3.7 | 2.8 | 3.1 | 2.8 |
| T4 mid | 3.0 | 3.3 | 3.0 | 3.3 | 3.8 | 3.0 | 3.3 | 3.0 |
| T4 top | 3.2 | 3.6 | 3.3 | 3.4 | 4.1 | 3.3 | 3.4 | 3.2 |
| T5 mid | 3.4 | 3.8 | 3.4 | 3.6 | 4.4 | 3.4 | 3.6 | 3.4 |
| T5 top | 3.6 | 4.0 | 3.6 | 3.7 | 4.6 | 3.6 | 3.7 | 3.6 |
| T6 mid | 3.8 | 4.2 | 3.8 | 3.9 | 4.9 | 3.8 | 3.9 | 3.8 |
| T6 top | 4.0 | 4.3 | 4.0 | 4.0 | 5.0 | 4.0 | 4.0 | 4.0 |
| T7 65 | 4.2 | 4.8 | 4.2 | 4.2 | 5.6 | 4.2 | 4.2 | 4.2 |
| T7 70 | 4.4 | 5.5 | 4.4 | 4.3 | 6.3 | 4.4 | 4.3 | 4.4 |
<!-- end generated -->

### 1.3 What the check shows

- **No stat dominates.** Per class and kind the checked stats stay within
  ×1.35 of each other from T1 to T7: Strength, Crit and Attack speed for the
  Warrior; Dexterity, Crit and Attack speed for the Scout; Intelligence,
  Crit and Mana for the Mage; Intelligence, Crit and Mana for the Priest's
  healing (since Round 36); HP,
  Armor and Dodge for survival. Attack speed falls from today's 4–14 % to
  1.7–4.4 %, Crit moves from 0.5–2.5 to 1.8–4.8 percentage points (v2).
- **Crit reaches its 30 % cap after about five enchants** at level 60
  (Warrior and Mage five, Scout four, v2); the cap no longer decides the
  Crit choice in an ordinary set.
- **Battle axe:** Strength adds a flat amount per swing, and the axe swings
  every 1.4 s, so for a two-handed Warrior one Strength enchant is worth
  about 0.7 of a Crit or Attack speed enchant. On armour Strength competes
  only with HP and Armor, so it stays the axe-Warrior's damage pick there.
- **A shield-bearing Warrior reaches the 70 % armor cap** against a
  same-level foe from about level 55 with plain gear (metal set plus shield).
  From there an armor enchant counts only against stronger foes (a level-65
  King: +2.3–2.4 % effective HP per enchant). This is today's armor formula.
- **The Priest's healing uses Intelligence like a Mage's Fireball** (Round
  36): healing and absorbs are multiplied by `1 + gear Int / 10 / B(L)`,
  where gear Int is the Intelligence above the class's own level growth and
  B(L) a base hit (43.7 at level 60). A Priest without Intelligence gear
  heals exactly the listed pool share (before Round 36 `1 + Int / 1000`, so 6 /
  9 / 11 % more at levels 30 / 45 / 60); one Intelligence enchant adds
  2.4–5.5 % (formerly 0.2–2.1 %), the Mage's Intelligence column, and a full
  Intelligence set +35 % at item level 60 and +44 % at 70 (formerly +13 % /
  +17 %). Heal, Hearten's splash, Mend, Shield, Recompense and the Mage's
  Glacial Ward share the factor.
- **Mana's curve starts higher than HP's:** at low levels the flat part of
  in-combat regeneration dominates small pools, so the same percentage would
  be worth less there; with its own curve Mana meets the target from T1.
- **The 60-second mana-bound fight** is the casters' measure: Mana counts in
  full when a fight runs the pool dry (elites, bosses, chained pulls) and not
  at all in a short fight. A fully damage-enchanted level-60 Mage gains +45 %
  in short fights and +80 % in mana-bound ones (table "A full set at level
  60").
- **The Scout's full damage set** gains +49 / +59 / +69 % at item level 60 /
  65 / 70 (Warrior +47 / +57 / +69 %). Its Dexterity on all eight items also
  raises Crit (§1.4), which the Warrior's Strength does not; with the Round 33
  curve (`c` = 0.0019) that made +55 / +68 / +82 %. Round 36 lowered `c` to
  0.0011; the band at item levels 65 and 70 is "no higher than the Warrior"
  (user, 2026-10-05), since the item-level-70 weapon alone lifts every set
  above +60 %.

### 1.4 Dexterity (v2)

Dexterity is three things for a Scout (bow and blade damage, Crit, Dodge) and
two small things for everyone else (0.05 points of Crit and 0.1 of Dodge per
point). Round 33 chose the largest curve that kept the Scout's check; Round
36 lowered it (`c` 0.0019 → 0.0011) so the Scout's full set matches the
Warrior's: a Scout's Dexterity enchant is now worth about one Crit enchant in
damage (×0.99–1.12), plus its dodge. For a Warrior, Mage or Priest it gives
about **0.4 of a Dodge enchant** from level 60 (0.3 at 40) and a sixth of a
Crit enchant:

<!-- generated: dexsplit -->
| Item level | Dexterity | Crit points (share of a Crit enchant) | Dodge points (share of a Dodge enchant) | Scout: damage vs a Crit enchant |
|---:|---:|---:|---:|---:|
| 10 | 2 | 0.10 (0.05) | 0.2 (0.11) | ×0.99 |
| 20 | 4 | 0.20 (0.08) | 0.4 (0.19) | ×1.12 |
| 30 | 6 | 0.30 (0.10) | 0.6 (0.24) | ×1.10 |
| 40 | 8 | 0.40 (0.11) | 0.8 (0.29) | ×1.05 |
| 50 | 10 | 0.50 (0.13) | 1.0 (0.32) | ×1.00 |
| 60 | 13 | 0.65 (0.15) | 1.3 (0.38) | ×1.05 |
| 70 | 15 | 0.75 (0.16) | 1.5 (0.41) | ×0.99 |
<!-- end generated -->

The plan's "half a Crit plus half a Dodge enchant" holds for the Dodge half
only. Both halves need the crit points per Dexterity point to stand to the
dodge points as a Crit enchant's points stand to a Dodge enchant's; under ×2
a Crit enchant has about 1.25 times a Dodge enchant's points, so the rates
would have to be about 0.125 % crit to 0.1 % dodge, not 0.05 to 0.1. With the
ruled rates, a Dexterity enchant large enough for half a Crit enchant (about
43 points at level 60) would be worth three Crit enchants to a Scout.

## 2. Enchant recipes T1–T6

### 2.1 Inputs

An enchant of tier T on family F for stat S in channel K costs three items,
as today, with one change: the loot item depends on the channel.

```
own material of the owning profession, tier T   (bar, leather, bolt, wood, setting)
prefix_loot[S]  or  suffix_loot[S]  of tier T   (a signature drop of the tier)
family_input[F] of tier T                        (mined or gathered; unchanged)
```

`grug_professions/data/enchants.json` replaces `stat_loot` with
`prefix_loot` and `suffix_loot` (both complete over the nine stats; the
trinket's prefix pool uses `prefix_loot`, its suffix pool `suffix_loot`).
The full file is
[`tools/r33_ds/enchants_r33.json`](../../tools/r33_ds/enchants_r33.json);
`family_input` is today's, unchanged. The owning profession of each family
and its own material are §3.3 (v2: bow enchants take the Leatherworker's
leather grade, spellbook enchants the Tailor's bolt).

*Rationale:* separate prefix and suffix loot doubles the signature slots per
tier (9 → 18) and gives each suffix its animal where a signature fits it
(Bear: teeth and claws, Fox: tails and hair, Owl: eyes, talismans and
feathers, Ox: sinew and flesh, Raven: feathers and talismans, Eagle: claws,
Hornet: venom and fangs, Cat: cat claws, Tortoise: shells and bone).

### 2.2 Input rules

`python3 tools/r33_ds/allocation.py --check` keeps them:

- every input drops for both factions: in zones of both The Accord and The
  Throng, or in a shared front zone (T5, T6);
- an input is a signature of the recipe's own tier (Alchemy may also use the
  existing generic reagents and herbs, never above the recipe tier);
- a **scarce** input (fewer than about 0.05 drops per weighted spawn,
  `tools/r33_ds/availability.py`) appears only in a low-volume recipe (a
  Weaponsmith, Woodcarver or Goldsmith upgrade, at most one per recipe) and
  never in an enchant;
- every signature either has a use or is listed in §2.4 with its reason.

<!-- generated: enchantloot -->
#### Enchant loot per channel (prefix / suffix)

| Stat | T1 prefix / suffix | T2 prefix / suffix | T3 prefix / suffix | T4 prefix / suffix | T5 prefix / suffix | T6 prefix / suffix |
|---|---|---|---|---|---|---|
| Str | Boar Tusk / Crab Leg | Ridged Boar Tusk / Fang | Hard-Set Molar / Gnarled Boar Tusk | Gritted Teeth / Warpack Fang | Clenched Jaw / Siegepack Fang | Last-Laugh Dentures / Unquiet Bone |
| Dex | Rat Tail / Fine Sinew | Sinewy Rat Tail / Tough Sinew | Balanced Weapon Strap / Braided Sinew | Reinforced Weapon Strap / Ape Hair | Siege Weapon Strap / Siege Weapon Strap | Unbroken Weapon Strap / Silver Ape Hair |
| Int | Crab Eye / Crab Eye | Clear Crab Eye / Knotted Talisman | Coded Talisman / Bound Wisp Mote | Campaign Talisman / Storm Feather | Siege Talisman / Ash Feather | Last-Pay Talisman / Last-Hex Shard |
| HP | Tattered Flesh / Fine Sinew | Foul Flesh / Tough Sinew | Pickled Flesh / Braided Sinew | Leathery Flesh / Ironbound Sinew | Scorched Flesh / Scorched Flesh | Salt-Cured Flesh / Salt-Cured Flesh |
| Mana | Crab Eye / Bandit Talisman | Clear Crab Eye / Knotted Talisman | Bound Wisp Mote / Clouded Reed Pearl | Campaign Talisman / Storm Feather | Siege Talisman / Siege Talisman | Last-Pay Talisman / Salt-Barbed Feather |
| Crit | Bandit Talisman / Boar Tusk | Ridged Boar Tusk / Fang | Serrated Fang / Shearing Cat Claw | Gritted Teeth / Razor Cat Claw | Clenched Jaw / Siegepack Fang | Last-Laugh Dentures / Glass Cat Claw |
| Speed | Rat Tail / Rat Tail | Sinewy Rat Tail / Sinewy Rat Tail | Balanced Weapon Strap / Barbed Feather | Reinforced Weapon Strap / Warpack Fang | Siege Weapon Strap / Scorch Venom | Unbroken Weapon Strap / Glass Venom |
| Dodge | Rat Fur Patch / Rat Tail | Dense Rat Fur / Sinewy Rat Tail | Coarse Spider Silk / Shearing Cat Claw | Layered Spider Web / Razor Cat Claw | Siege Weapon Strap / Ash Feather | Glass Spider Silk / Glass Cat Claw |
| Armor | Rat Fur Patch / Crab Leg | Dense Rat Fur / Ridged Crab Shell | Layered Crab Shell / Layered Crab Shell | Marching Bone / Storm Crab Shell | Siege Bone / Clenched Jaw | Unbroken Weapon Strap / Unquiet Bone |
<!-- end generated -->

### 2.3 Every signature

`Zones A/T/F`: zones of The Accord / The Throng / the shared front that place
the drop. `Load`: a rough demand weight over all its uses. `Today`: its use
before Round 33.

<!-- generated: signatures -->
| Tier | Signature | Zones A/T/F | Grade | Uses | Load | Today |
|---:|---|---|---|---|---:|---|
| 1 | Bandit Talisman | 3/3/0 | regular | enchant Mana suffix; enchant Crit prefix; upgrade goldsmith | 3.5 | — |
| 1 | Boar Tusk | 3/3/0 | common | enchant Str prefix; enchant Crit suffix; upgrade weaponsmith; upgrade woodcarver; Elixir of Precision I | 6.5 | enchant |
| 1 | Crab Eye | 3/3/0 | common | enchant Int prefix; enchant Int suffix; enchant Mana prefix; upgrade goldsmith; Elixir of Focus I | 6.5 | enchant |
| 1 | Crab Leg | 3/3/0 | common | enchant Str suffix; enchant Armor suffix; upgrade armorsmith; Stoneskin Elixir I | 5.8 | — |
| 1 | Fine Sinew | 1/3/0 | regular | enchant Dex suffix; enchant HP suffix; upgrade woodcarver | 4.2 | — |
| 1 | Fox Tail | 3/0/0 | one faction | sell-only: one faction (Accord only) | 0.0 | — |
| 1 | Mild Venom | 0/2/0 | one faction | sell-only: one faction (Throng only) | 0.0 | — |
| 1 | Small Cat Claw | 0/1/0 | one faction | sell-only: one faction (Throng start zone only) | 0.0 | — |
| 1 | Rat Fur Patch | 3/3/0 | common | enchant Dodge prefix; enchant Armor prefix; upgrade armorsmith; upgrade leatherworker | 6.5 | enchant |
| 1 | Rat Tail | 3/3/0 | common | enchant Dex prefix; enchant Speed prefix; enchant Speed suffix; enchant Dodge suffix; upgrade weaponsmith; upgrade tailor | 7.0 | enchant |
| 1 | Tattered Flesh | 3/3/0 | common | enchant HP prefix; upgrade leatherworker; upgrade tailor; Elixir of Vigor I | 7.5 | enchant |
| 2 | Bitter Venom | 0/4/0 | one faction | sell-only: one faction (Throng only) | 0.0 | — |
| 2 | Blunt Crocodile Tooth | 0/1/0 | one faction | sell-only: one faction (Throng only) | 0.0 | — |
| 2 | Brush Fox Tail | 3/0/0 | one faction | sell-only: one faction (Accord only) | 0.0 | — |
| 2 | Clear Crab Eye | 3/3/0 | regular | enchant Int prefix; enchant Mana prefix; upgrade goldsmith; Elixir of Focus II | 5.0 | enchant |
| 2 | Dense Rat Fur | 3/3/0 | common | enchant Dodge prefix; enchant Armor prefix; upgrade armorsmith; upgrade leatherworker | 6.5 | enchant |
| 2 | Fang | 6/2/0 | common | enchant Str suffix; enchant Crit suffix; upgrade weaponsmith; Swiftness Draught | 5.0 | recipe |
| 2 | Foul Flesh | 6/6/0 | common | enchant HP prefix; upgrade leatherworker | 4.0 | enchant |
| 2 | Hooked Cat Claw | 0/1/0 | one faction | sell-only: one faction (Throng only) | 0.0 | — |
| 2 | Knotted Talisman | 6/6/0 | common | enchant Int suffix; enchant Mana suffix; upgrade tailor; upgrade goldsmith | 6.5 | — |
| 2 | Reed Pearl | 0/1/0 | one faction | sell-only: one faction (Throng only) | 0.0 | — |
| 2 | Ridged Boar Tusk | 3/3/0 | common | enchant Str prefix; enchant Crit prefix; upgrade weaponsmith; upgrade woodcarver; Elixir of Precision II | 6.5 | enchant |
| 2 | Ridged Crab Shell | 3/3/0 | regular | enchant Armor suffix; upgrade armorsmith; Stoneskin Elixir II | 4.2 | — |
| 2 | Sinewy Rat Tail | 3/3/0 | common | enchant Dex prefix; enchant Speed prefix; enchant Speed suffix; enchant Dodge suffix; upgrade tailor | 5.5 | enchant |
| 2 | Stolen Purse | 1/0/0 | one faction | sell-only: one faction (Accord only); a trash-class purse | 0.0 | — |
| 2 | Thin Slime Gel | 0/1/0 | one faction | sell-only: one faction (Throng only) | 0.0 | — |
| 2 | Tough Sinew | 4/5/0 | common | enchant Dex suffix; enchant HP suffix; upgrade woodcarver; Elixir of Vigor II | 5.2 | — |
| 2 | Wisp Mote | 0/1/0 | one faction | sell-only: one faction (Throng only) | 0.0 | — |
| 3 | Balanced Weapon Strap | 6/3/0 | common | enchant Dex prefix; enchant Speed prefix | 1.8 | enchant |
| 3 | Barbed Feather | 1/1/0 | regular | enchant Speed suffix | 0.5 | — |
| 3 | Bone Chitin | 0/1/0 | one faction | sell-only: one faction (Throng only) | 0.0 | — |
| 3 | Bound Wisp Mote | 3/2/0 | common | enchant Int suffix; enchant Mana prefix; upgrade woodcarver; Cave Draught | 5.0 | — |
| 3 | Braided Sinew | 7/7/0 | common | enchant Dex suffix; enchant HP suffix; upgrade armorsmith; upgrade woodcarver; upgrade leatherworker | 9.2 | — |
| 3 | Chipped Core | 0/0/0 | none | sell-only: no placed source (stone golems are not in a spawn recipe) | 0.0 | — |
| 3 | Clasped Purse | 2/1/0 | scarce | upgrade goldsmith | 1.5 | — |
| 3 | Clouded Reed Pearl | 2/1/0 | regular | enchant Mana suffix; upgrade tailor; upgrade goldsmith | 5.0 | — |
| 3 | Coarse Spider Silk | 2/1/0 | regular | enchant Dodge prefix; upgrade leatherworker; upgrade tailor | 5.8 | — |
| 3 | Coded Talisman | 6/3/0 | common | enchant Int prefix | 1.5 | enchant |
| 3 | Concentrated Venom | 0/3/0 | one faction | sell-only: one faction (Throng only) | 0.0 | — |
| 3 | Etched Bone | 0/1/0 | one faction | sell-only: one faction (Throng only) | 0.0 | — |
| 3 | Gnarled Boar Tusk | 2/2/0 | common | enchant Str suffix; upgrade weaponsmith | 3.0 | — |
| 3 | Layered Crab Shell | 4/4/0 | common | enchant Armor prefix; enchant Armor suffix; upgrade armorsmith; Stoneskin Elixir III | 5.0 | — |
| 3 | Gravewood Resin | 0/1/0 | one faction | sell-only: one faction (Throng only) | 0.0 | — |
| 3 | Pickled Flesh | 3/3/0 | common | enchant HP prefix | 1.5 | enchant |
| 3 | Ridged Crocodile Tooth | 0/2/0 | one faction | sell-only: one faction (Throng only) | 0.0 | — |
| 3 | Serrated Fang | 3/3/0 | common | enchant Crit prefix; upgrade weaponsmith; Elixir of Precision III | 3.5 | — |
| 3 | Shearing Cat Claw | 1/4/0 | common | enchant Crit suffix; enchant Dodge suffix | 1.8 | — |
| 3 | Silver-Tip Fox Tail | 2/0/0 | one faction | sell-only: one faction (Accord only) | 0.0 | — |
| 3 | Hard-Set Molar | 3/3/0 | common | enchant Str prefix | 1.5 | enchant |
| 4 | Ape Hair | 1/1/0 | regular | enchant Dex suffix; upgrade leatherworker | 3.8 | — |
| 4 | Bitter Resin | 1/1/0 | scarce | upgrade woodcarver | 1.5 | — |
| 4 | Campaign Purse | 1/1/0 | scarce | upgrade goldsmith | 1.5 | — |
| 4 | Campaign Talisman | 3/3/0 | common | enchant Int prefix; enchant Mana prefix; upgrade tailor; upgrade goldsmith; Elixir of Focus IV | 7.5 | enchant |
| 4 | Gritted Teeth | 3/3/0 | common | enchant Str prefix; enchant Crit prefix | 2.5 | enchant |
| 4 | Hex Bottle Shard | 0/1/0 | one faction | sell-only: one faction (Throng only) | 0.0 | — |
| 4 | Ironbound Sinew | 3/1/0 | common | enchant HP suffix; upgrade armorsmith; Elixir of Vigor IV | 5.0 | — |
| 4 | Layered Bone Chitin | 0/1/0 | one faction | sell-only: one faction (Throng only) | 0.0 | — |
| 4 | Layered Spider Web | 2/2/0 | regular | enchant Dodge prefix; upgrade tailor | 3.2 | — |
| 4 | Leathery Flesh | 3/3/0 | common | enchant HP prefix; upgrade leatherworker; Healing Potion IV | 5.0 | enchant |
| 4 | Marching Bone | 2/2/0 | common | enchant Armor prefix; upgrade weaponsmith | 2.2 | — |
| 4 | Razor Cat Claw | 2/2/0 | common | enchant Crit suffix; enchant Dodge suffix; Elixir of Precision IV | 2.8 | — |
| 4 | Reinforced Weapon Strap | 3/3/0 | common | enchant Dex prefix; enchant Speed prefix | 1.8 | enchant |
| 4 | Flickering Wisp Mote | 2/0/0 | one faction | sell-only: one faction (Accord only) | 0.0 | — |
| 4 | Scarred Bear Claw | 2/1/0 | scarce | upgrade weaponsmith | 1.5 | — |
| 4 | Storm Crab Shell | 2/2/0 | regular | enchant Armor suffix; upgrade armorsmith | 3.2 | — |
| 4 | Storm Feather | 2/1/0 | common | enchant Int suffix; enchant Mana suffix; upgrade woodcarver | 4.0 | — |
| 4 | Veined Core | 1/0/0 | one faction | sell-only: no regular source (one unique elite) | 0.0 | — |
| 4 | Warpack Fang | 3/2/0 | common | enchant Str suffix; enchant Speed suffix | 2.0 | — |
| 5 | Ash Feather | 0/0/2 | regular | enchant Int suffix; enchant Dodge suffix; upgrade woodcarver | 3.8 | — |
| 5 | Clenched Jaw | 0/0/2 | regular | enchant Str prefix; enchant Crit prefix; enchant Armor suffix; upgrade goldsmith | 4.8 | enchant |
| 5 | Scorch Venom | 0/0/2 | regular | enchant Speed suffix; upgrade weaponsmith; upgrade tailor | 4.5 | — |
| 5 | Scorched Flesh | 0/0/2 | common | enchant HP prefix; enchant HP suffix; upgrade leatherworker; Elixir of Vigor V | 6.5 | enchant |
| 5 | Siege Bone | 0/0/2 | regular | enchant Armor prefix; upgrade armorsmith; Stoneskin Elixir V | 4.2 | — |
| 5 | Siege Cat Claw | 0/0/1 | scarce | upgrade weaponsmith | 1.5 | — |
| 5 | Siege Core | 0/0/2 | scarce | sell-only: no regular source (two unique elites) | 0.0 | — |
| 5 | Siege Talisman | 0/0/2 | regular | enchant Int prefix; enchant Mana prefix; enchant Mana suffix; upgrade tailor; upgrade goldsmith | 7.5 | enchant |
| 5 | Siege Weapon Strap | 0/0/2 | regular | enchant Dex prefix; enchant Dex suffix; enchant Speed prefix; enchant Dodge prefix; upgrade armorsmith; upgrade leatherworker | 8.8 | enchant |
| 5 | Siegepack Fang | 0/0/2 | regular | enchant Str suffix; enchant Crit suffix; upgrade woodcarver; Elixir of Precision V | 5.0 | — |
| 6 | Abyssal Crab Shell | 0/0/0 | none | sell-only: no placed source (the reef lurker is not in a spawn recipe) | 0.0 | — |
| 6 | Glass Cat Claw | 0/0/3 | regular | enchant Crit suffix; enchant Dodge suffix | 1.8 | — |
| 6 | Glass Spider Silk | 0/0/3 | regular | enchant Dodge prefix; upgrade tailor | 3.2 | — |
| 6 | Glass Venom | 0/0/2 | regular | enchant Speed suffix; upgrade tailor | 3.0 | — |
| 6 | Last-Hex Shard | 0/0/2 | regular | enchant Int suffix; upgrade goldsmith; Elixir of Focus VI | 4.0 | — |
| 6 | Last-Laugh Dentures | 0/0/4 | common | enchant Str prefix; enchant Crit prefix | 2.5 | enchant |
| 6 | Last-Pay Talisman | 0/0/4 | common | enchant Int prefix; enchant Mana prefix; upgrade goldsmith | 4.0 | enchant |
| 6 | Rime Sinew | 0/0/2 | scarce | upgrade woodcarver | 1.5 | — |
| 6 | Salt-Barbed Feather | 0/0/4 | regular | enchant Mana suffix; upgrade woodcarver | 2.5 | — |
| 6 | Salt Bear Claw | 0/0/1 | scarce | upgrade weaponsmith | 1.5 | — |
| 6 | Salt Chitin | 0/0/1 | scarce | sell-only: scarce (one zone, rare weevil); a hunter's trophy | 0.0 | — |
| 6 | Salt-Cured Flesh | 0/0/4 | common | enchant HP prefix; enchant HP suffix; upgrade leatherworker; Elixir of Vigor VI | 6.5 | enchant |
| 6 | Saltpack Fang | 0/0/1 | scarce | sell-only: scarce (one zone, few hounds); a hunter's trophy | 0.0 | — |
| 6 | Silver Ape Hair | 0/0/2 | regular | enchant Dex suffix; upgrade leatherworker | 3.8 | — |
| 6 | Unbroken Weapon Strap | 0/0/4 | common | enchant Dex prefix; enchant Speed prefix; enchant Armor prefix; upgrade armorsmith | 5.0 | enchant |
| 6 | Unquiet Bone | 0/0/4 | common | enchant Str suffix; enchant Armor suffix; upgrade weaponsmith; upgrade armorsmith; Stoneskin Elixir VI | 7.2 | — |

Signatures: 94; with a use: 68 (today 27); newly used: 41; sell-only: 26.
<!-- end generated -->

### 2.4 Sell-only signatures and why

- **One faction (20):** their families live only in one faction's zones, so a
  recipe needing them would lock the other faction out. They keep their quest
  uses.
- **No placed source (4):** Chipped Core and Veined Core (the stone golems
  are no spawn-recipe mob; Veined Core only from one unique elite), Siege Core
  (two unique elites on 300 s respawn), Abyssal Crab Shell (the reef lurker
  is in no spawn recipe).
- **Scarce trophies (2):** Saltpack Fang and Salt Chitin come from one zone's
  rare mob; a recipe would turn them into a bottleneck.

## 3. Profession upgrades

### 3.1 The rule

- A profession upgrades the items of its families (§3.3) at its station
  (Forge, Carving Bench, Tanning Rack, Tailor Bench, Jeweller's Bench).
- The upgrade's tier is the item's material tier T (`_grug_bracket`); the
  crafter's profession tier must be at least T, as for an enchant of tier T.
- Eligible when the item's level is below `10 × T`; the result's item level
  is `10 × T`, its level requirement `min(10 × T, 60)`. Never lowering:
  boss drops (65/70), crowned items and items already at the top are refused.
- Enchants keep their stat, channel and tier; their values follow the new
  item level (§1.1). Weapon damage, armor rating and shield rating follow the
  item level as today. A trinket's special and a spellbook's mana line are
  fixed per tier and do not change.
- An upgrade is a profession progression craft (plan §2.7).
- Inputs: **2 × the profession's own material of tier T + one each of two
  signatures of tier T**, no money. Data:
  [`tools/r33_ds/upgrades_r33.json`](../../tools/r33_ds/upgrades_r33.json).
- One upgrade recipe per profession and tier covers all its families.

<!-- generated: upgrades -->
#### Upgrade inputs (plus 2 × own material)

| Profession (families) | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---|---|---|---|---|---|
| Weaponsmith (sword, dagger, battle axe) | Boar Tusk + Rat Tail | Ridged Boar Tusk + Fang | Serrated Fang + Gnarled Boar Tusk | Scarred Bear Claw + Marching Bone | Siege Cat Claw + Scorch Venom | Salt Bear Claw + Unquiet Bone |
| Armorsmith (metal armour, shield) | Crab Leg + Rat Fur Patch | Ridged Crab Shell + Dense Rat Fur | Layered Crab Shell + Braided Sinew | Storm Crab Shell + Ironbound Sinew | Siege Bone + Siege Weapon Strap | Unquiet Bone + Unbroken Weapon Strap |
| Woodcarver (staff, wand) | Fine Sinew + Boar Tusk | Tough Sinew + Ridged Boar Tusk | Braided Sinew + Bound Wisp Mote | Bitter Resin + Storm Feather | Ash Feather + Siegepack Fang | Salt-Barbed Feather + Rime Sinew |
| Leatherworker (leather armour, bow) | Rat Fur Patch + Tattered Flesh | Dense Rat Fur + Foul Flesh | Coarse Spider Silk + Braided Sinew | Ape Hair + Leathery Flesh | Siege Weapon Strap + Scorched Flesh | Silver Ape Hair + Salt-Cured Flesh |
| Tailor (cloth armour, spellbook) | Rat Tail + Tattered Flesh | Knotted Talisman + Sinewy Rat Tail | Coarse Spider Silk + Clouded Reed Pearl | Layered Spider Web + Campaign Talisman | Siege Talisman + Scorch Venom | Glass Spider Silk + Glass Venom |
| Goldsmith (trinket) | Crab Eye + Bandit Talisman | Clear Crab Eye + Knotted Talisman | Clasped Purse + Clouded Reed Pearl | Campaign Purse + Campaign Talisman | Clenched Jaw + Siege Talisman | Last-Hex Shard + Last-Pay Talisman |

#### Own material (upgrades and enchants)

| Profession | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---|---|---|---|---|---|
| Weaponsmith | Bronze Bar | Iron Bar | Steel Bar | Silversteel Bar | Embersteel Bar | Abyssal Steel Bar |
| Armorsmith | Bronze Bar | Iron Bar | Steel Bar | Silversteel Bar | Embersteel Bar | Abyssal Steel Bar |
| Woodcarver | Seasoned Wood | Polished Wood | Hardened Wood | Inlaid Wood | Lacquered Wood | Heartwood Wood |
| Leatherworker | Light Leather | Cured Leather | Heavy Leather | Scaled Hide | Sleek Leather | Nightscale Leather |
| Tailor | Patch Bolt | Woven Bolt | Heavy Bolt | Silkweave Bolt | Silk Bolt | Stormweave Bolt |
| Goldsmith | Tin Setting | Iron Setting | Copper-inlaid Steel Setting | Gold Setting | Gold-filigreed Embersteel Setting | Gold-filigreed Abyssal Steel Setting |
<!-- end generated -->

### 3.2 What an upgrade is worth

A plain base sits at the bottom of its tier (item level 3/10/20/30/40/50) and
an upgrade lifts it to the top (10/20/…/60). Example, an Embersteel sword (T5)
with two T5 enchants: item level 40 → 50, damage 18 → 22, a Strength enchant
11 → 15, a Crit enchant 3.5 → 3.9 %. An upgraded T(n) weapon or armour piece
equals a plain T(n+1) one in base stats; the upgrade keeps its enchants, which
a new base would have to buy again.

### 3.3 Profession families (v2, user ruling 2026-10-04)

Two professions dress every class in armour, weapon and offhand:

| Profession | Makes, enchants and upgrades | Class pairs |
|---|---|---|
| Weaponsmith | swords, daggers, battle axes (also the Scout's melee blade) | Warrior, Scout |
| Armorsmith | metal armour, shields | Warrior |
| Woodcarver | staves, wands | Mage, Priest |
| Leatherworker | leather armour, **bows** (from the Woodcarver) | Scout |
| Tailor | cloth armour, **spellbooks** (from the Goldsmith) | Mage, Priest |
| Goldsmith | trinkets for everyone; gems and settings | all |

Warrior: Armorsmith + Weaponsmith. Scout: Leatherworker + Weaponsmith.
Mage and Priest: Tailor + Woodcarver. The Goldsmith serves every class.

- **The Tailor's spellbook** (replaces the Goldsmith's Setting + Parchment):
  `2 × the bolt of tier T + 1 Parchment` at the Tailor Bench, Journeyman
  mastery as today; it counts as a progression craft. Item, tier and stats of
  the six spellbooks are unchanged.
- Bow enchants and upgrades take the Leatherworker's leather grade of the
  tier; spellbook enchants and upgrades the Tailor's bolt. Family inputs and
  signatures are unchanged.
- Every profession keeps a counting recipe at every tier:

<!-- generated: progression -->
| Profession | Families | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---|---|---|---|---|---|---|
| Weaponsmith | sword, dagger, battle axe | enchants, upgrade | enchants, upgrade | enchants, upgrade | enchants, upgrade | enchants, upgrade | enchants, upgrade |
| Armorsmith | metal armour, shield | enchants, upgrade | enchants, upgrade | enchants, upgrade | enchants, upgrade | enchants, upgrade | enchants, upgrade |
| Woodcarver | staff, wand | enchants, upgrade | enchants, upgrade | enchants, upgrade | enchants, upgrade | enchants, upgrade | enchants, upgrade |
| Leatherworker | leather armour, bow | enchants, upgrade, 8-slot bag | enchants, upgrade, 16-slot bag | enchants, upgrade | enchants, upgrade, 24-slot bag | enchants, upgrade, 32-slot bag | enchants, upgrade |
| Tailor | cloth armour, spellbook | enchants, upgrade, spellbook, 8-slot bag | enchants, upgrade, spellbook, 16-slot bag | enchants, upgrade, spellbook | enchants, upgrade, spellbook, 24-slot bag | enchants, upgrade, spellbook, 32-slot bag | enchants, upgrade, spellbook |
| Goldsmith | trinket | enchants, upgrade, six trinkets | enchants, upgrade, six trinkets | enchants, upgrade, six trinkets | enchants, upgrade, six trinkets | enchants, upgrade, six trinkets | enchants, upgrade, six trinkets |
<!-- end generated -->

### 3.4 Two Goldsmith leftovers (v2, approved: user choices 11A, 12A)

- **Ornament Components T3–T6** are removed (item, recipe, ingredient-tier
  registrations): an intermediate without a consumer that sells for nothing
  and is made from one-faction reagents.
- **Cut Citrine becomes the T1 trinket gem** in place of Cut Quartz, so the
  gem ladder runs Citrine (T1) to Diamond (T6) in the trinket recipes as in
  the mines; the Cut Quartz recipe goes with it (Quartz stays a raw T1 enchant
  input; it is a mineral, not a gem, and has no storage block).
- After both, the generic loot Slime Gel and Crocodile Tooth (one faction)
  and Stone Core (no placed source) keep no recipe use; they stay vendor
  loot. Shiny Scale moves to Stoneskin Elixir IV.

## 4. The crown

- The crown NPC in every capital applies one Fallen Crown to one item for a
  money fee: the item level becomes `10 × T + 5` (T = material tier) and every
  enchant gains one tier (T6 → T7 at most). Values follow §1.1: a crowned T6
  item's T7 enchants are worth their item-level-65 value.
- Once per item (a stored flag); refused where it would not raise the item
  level (boss drops at 65/70, an already crowned item).
- **Fee: one hour of band-6 net solo income**, rounded by
  [economy.md](economy.md) §4.1, from the same income estimate as the mount
  prices (`tools/r29_e4/income.py`): 1g 45s on the estimate before Round 33.
  **As built: 1g 48s** (`grug_traders.CROWN_FEE`), the same rule on the
  estimate with the Round 33 terms (column "after" below; accepted by the
  coordinator). The Fallen Crown stays unsellable.
- Re-enchanting a crowned item uses T1–T6 recipes only; the station preview
  names a weaker replacement, e.g. "replaces T7 Strength with T6 Strength".

*Rationale:* money's use at level 60 (plan §2.6); one hour per crowned item
makes a crowned set (eight items) a goal of about eight hours of income plus
eight King kills, next to Master Riding's five hours.

<!-- generated: crown -->
| Sink | Rule | Price (today's band-6 income) | Price (after) |
|---|---|---:|---:|
| Crown fee (option 1) | 30 min of band-6 income | 73s | 74s |
| Crown fee (option 2, proposed) | 1 h of band-6 income | 1g 45s | 1g 47s |
| Crown fee (option 3) | 2 h of band-6 income | 2g 90s | 2g 95s |
<!-- end generated -->

## 5. Potions and elixirs

- **Healing and mana potions restore fixed amounts**, about half a Priest's
  base pool at the tier's top level (plan §2.7). Mana potions fit beside them:
  spell costs are percentages of the same base pool, so a Mana Potion VI
  (1350) is eight Fireballs or six Heals at level 60, and both kinds share
  one potion clock, so a caster chooses between them.
- **One shared 60-second potion cooldown** for every potion; the 45-second
  exception of the old Greater potions goes. Elixirs keep their own rule: one
  elixir at a time, the newest replaces it.
- **Elixirs** give two enchants' worth of their stat at the tier's top level
  (Vigor, Focus, Precision, 15 minutes); Stoneskin gives one armor enchant
  for 30 minutes, which for cloth and leather wearers is about two enchants of
  effective HP (the armor curve is fitted to plate).
- Names count by tier with Roman numerals, like today's elixirs. Level
  requirement: the tier's first level.
- **The vendor's Weak Healing Potion** heals a fixed 35 HP (half of Healing
  Potion I) at its 8c price; today it heals 15 % of maximum HP at every level.
- Recipes avoid one-faction reagents: Slime Gel and Crocodile Tooth (Throng
  only) leave the Cave Draught, Deepwater Elixir, Elixir of Vigor IV and
  Stoneskin Elixir (v2: Stoneskin IV takes Shiny Scale).
- Removed with lane C2 (plan §2.8): the Warding Draught, apothecary gear,
  imbuing oils, the Sovereign's Flask.

<!-- generated: alchemy -->
| Tier | Level | Product | Effect | Ingredients (+ Glass Bottle) |
|---:|---:|---|---|---|
| 1 | 1 | Healing Potion I | restores 70 HP at once | Gravemoss + Sunleaf |
| 1 | 1 | Mana Potion I | restores 70 Mana at once | Gravemoss + a root vegetable (Carrot, Cassava ...) |
| 1 | 1 | Elixir of Vigor I | +4.0 % maximum HP, 15 min | Sunleaf + Tattered Flesh |
| 1 | 1 | Elixir of Focus I | +5.0 % maximum Mana, 15 min | Gravemoss + Crab Eye |
| 1 | 1 | Elixir of Precision I | +4.2 percentage points Crit, 15 min | Sunleaf + Boar Tusk |
| 1 | 1 | Stoneskin Elixir I | +0.8 armor rating, 30 min | Gravemoss + Crab Leg |
| 2 | 11 | Healing Potion II | restores 200 HP at once | Dragonweed + Sunleaf |
| 2 | 11 | Mana Potion II | restores 200 Mana at once | Dragonweed + Sugar Cane |
| 2 | 11 | Elixir of Vigor II | +4.8 % maximum HP, 15 min | Dragonweed + Tough Sinew |
| 2 | 11 | Elixir of Focus II | +5.6 % maximum Mana, 15 min | Dragonweed + Clear Crab Eye |
| 2 | 11 | Elixir of Precision II | +5.2 percentage points Crit, 15 min | Dragonweed + Ridged Boar Tusk |
| 2 | 11 | Stoneskin Elixir II | +1.6 armor rating, 30 min | Dragonweed + Ridged Crab Shell |
| 2 | 11 | Antivenom | clears all poison (unchanged) | Dragonweed + Venom Gland |
| 2 | 11 | Swiftness Draught | +10 % movement speed for 5 s (unchanged) | Dragonweed + Fang |
| 3 | 21 | Healing Potion III | restores 400 HP at once | Crimson Lotus + Gravemoss |
| 3 | 21 | Mana Potion III | restores 400 Mana at once | Crimson Lotus + Sugar Cane |
| 3 | 21 | Elixir of Vigor III | +5.6 % maximum HP, 15 min | Crimson Lotus + Bear Claw |
| 3 | 21 | Elixir of Focus III | +6.2 % maximum Mana, 15 min | Crimson Lotus + Cave Cap |
| 3 | 21 | Elixir of Precision III | +6.0 percentage points Crit, 15 min | Crimson Lotus + Serrated Fang |
| 3 | 21 | Stoneskin Elixir III | +2.4 armor rating, 30 min | Crimson Lotus + Layered Crab Shell |
| 3 | 21 | Cave Draught | night vision for 10 min (unchanged) | Cave Cap + Bound Wisp Mote |
| 4 | 31 | Healing Potion IV | restores 650 HP at once | Crimson Lotus + Leathery Flesh |
| 4 | 31 | Mana Potion IV | restores 650 Mana at once | Crimson Lotus + Venom Sac |
| 4 | 31 | Elixir of Vigor IV | +6.4 % maximum HP, 15 min | Crimson Lotus + Ironbound Sinew |
| 4 | 31 | Elixir of Focus IV | +6.8 % maximum Mana, 15 min | Crimson Lotus + Campaign Talisman |
| 4 | 31 | Elixir of Precision IV | +7.0 percentage points Crit, 15 min | Crimson Lotus + Razor Cat Claw |
| 4 | 31 | Stoneskin Elixir IV | +3.2 armor rating, 30 min | Crimson Lotus + Shiny Scale |
| 5 | 41 | Healing Potion V | restores 1000 HP at once | Ember Moss + Crimson Lotus |
| 5 | 41 | Mana Potion V | restores 1000 Mana at once | Stormkelp + Crimson Lotus |
| 5 | 41 | Elixir of Vigor V | +7.2 % maximum HP, 15 min | Ember Moss + Scorched Flesh |
| 5 | 41 | Elixir of Focus V | +7.4 % maximum Mana, 15 min | Ember Moss + Cave Cap |
| 5 | 41 | Elixir of Precision V | +7.8 percentage points Crit, 15 min | Ember Moss + Siegepack Fang |
| 5 | 41 | Stoneskin Elixir V | +4.0 armor rating, 30 min | Stormkelp + Siege Bone |
| 5 | 41 | Deepwater Elixir | water breathing for 10 min (unchanged) | Stormkelp + Cave Cap |
| 6 | 51 | Healing Potion VI | restores 1350 HP at once | Wild Cocoa + Ember Moss |
| 6 | 51 | Mana Potion VI | restores 1350 Mana at once | Wild Cocoa + Stormkelp |
| 6 | 51 | Elixir of Vigor VI | +8.0 % maximum HP, 15 min | Wild Cocoa + Salt-Cured Flesh |
| 6 | 51 | Elixir of Focus VI | +8.0 % maximum Mana, 15 min | Wild Cocoa + Last-Hex Shard |
| 6 | 51 | Elixir of Precision VI | +8.6 percentage points Crit, 15 min | Ember Moss + Sharp Feather |
| 6 | 51 | Stoneskin Elixir VI | +4.8 armor rating, 30 min | Wild Cocoa + Unquiet Bone |

Potion check: amount against half the base pool at the tier's top level.

| Tier | Amount | 50 % of P(10 T) | Share of a level-(10 T) Warrior / Priest / Mage HP |
|---:|---:|---:|---|
| 1 | 70 | 68 | 43 % / 51 % / 57 % |
| 2 | 200 | 192 | 43 % / 52 % / 58 % |
| 3 | 400 | 382 | 44 % / 52 % / 58 % |
| 4 | 650 | 638 | 42 % / 51 % / 57 % |
| 5 | 1000 | 960 | 43 % / 52 % / 58 % |
| 6 | 1350 | 1348 | 42 % / 50 % / 56 % |
<!-- end generated -->

## 6. Money

### 6.1 Sale values of dropped gear

Blue sells for 3 times, gold for 6 times the Common buy-back of its slot and
tier (plan §2.1). Shields, spellbooks and trinkets use the "other" slot; item
level 61+ uses T6.

<!-- generated: sale -->
| Slot | Quality | T1 | T2 | T3 | T4 | T5 | T6 and item level 61+ |
|---|---|---:|---:|---:|---:|---:|---:|
| Weapon | white (×1) | 2c | 4c | 8c | 20c | 50c | 1s 25c |
| Weapon | blue (×3) | 6c | 12c | 24c | 60c | 1s 50c | 3s 75c |
| Weapon | gold (×6) | 12c | 24c | 48c | 1s 20c | 3s | 7s 50c |
| Chest | white (×1) | 1c | 3c | 7c | 16c | 40c | 1s |
| Chest | blue (×3) | 3c | 9c | 21c | 48c | 1s 20c | 3s |
| Chest | gold (×6) | 6c | 18c | 42c | 96c | 2s 40c | 6s |
| Head, legs, feet, shield, spellbook, trinket | white (×1) | 1c | 2c | 4c | 10c | 25c | 63c |
| Head, legs, feet, shield, spellbook, trinket | blue (×3) | 3c | 6c | 12c | 30c | 75c | 1s 89c |
| Head, legs, feet, shield, spellbook, trinket | gold (×6) | 6c | 12c | 24c | 60c | 1s 50c | 3s 78c |
<!-- end generated -->

### 6.2 Repair

```
repair_cost = ceil(1.00 × P × w)
```

`P` is the reference purchase price times the quality multiplier 1 / 3 / 6, `w`
the missing durability fraction ([durability_repair.md](durability_repair.md#price)).
The factor rises from 0.20 to **1.00**: wearing an item out once costs what it
would cost to buy again. Repair then takes about 3–9 % of net income for blue
gear and 6–18 % for gold, against 0.6–1.8 % today (§6.5).

### 6.3 Upgrade and crafting costs

Upgrades and enchants cost items, never money. An upgrade's inputs sell for
about 6–9 minutes of the band's income:

<!-- generated: upgradecost -->
| Tier | Two signatures | Two own materials (bar … setting) | Total sell value | Minutes of the band's income |
|---:|---:|---|---:|---:|
| T1 | 14c | 0c–4c | up to 18c | 6.1 |
| T2 | 36c | 0c–20c | up to 56c | 7.7 |
| T3 | 90c | 0c–52c | up to 1s 42c | 9.3 |
| T4 | 2s 24c | 0c–56c | up to 2s 80c | 6.9 |
| T5 | 5s 60c | 0c–1s 60c | up to 7s 20c | 6.6 |
| T6 | 14s | 0c–1s 64c | up to 15s 64c | 6.5 |
<!-- end generated -->

### 6.4 The culture vendor

One culture vendor in every capital sells cosmetic, non-craftable blocks and
lights (plan §2.6); the items as built are listed in
[economy.md](economy.md) §4 (the Decor Merchant). Fixed prices,
the same at every level, ordinary vendor rules (5 % buy-back):

| Band | Kinds | Price each | Band-6 income time |
|---|---|---:|---:|
| Accent blocks | tiles, carved or polished stone, panels, glass accents | 25c | 6 s |
| Small lights | candles, small lanterns, table lamps | 1s | 25 s |
| Large lights | hanging lanterns, chandeliers, braziers, lamp posts | 10s | 4 min |
| Showpieces | statues, banners, large carved or woven pieces | 1g | 41 min |

*Rationale:* accents and candles stay affordable from the first levels; a
decorated house (about 300 accents, 20 small and 10 large lights, 5
showpieces) costs about 7g, some five hours of band-6 income, like Master
Riding.

### 6.5 Income before and after

`tools/r33_ds/money.py` runs the Round 29 income estimate unchanged and adds
the Round 33 terms per band: every normal kill's gear drop sold (white 5 %,
blue 2 %, gold 1 % at ×1/×3/×6; an upper bound, players keep what they wear)
and repair at the new factor on the estimate's own wear (blue gear; the gold
column shows a player in gold gear). Mount and respec prices move by less than
3 %; lane C5 recalibrates them with the repaired `income.py --check`.

<!-- generated: income -->
| Band | Net/h today | Gear sales/h | Repair/h today | Repair/h new (blue) | Repair/h new (gold) | Net/h after (blue) | Change | Repair share today → after (blue / gold) |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| 1 → 10 | 1s 77c | 8c | 3c | 17c | 33c | 1s 72c | -3.1 % | 1.8 % → 8.9 % / 17.7 % |
| 10 → 20 | 4s 35c | 17c | 6c | 28c | 57c | 4s 28c | -1.4 % | 1.3 % → 6.2 % / 12.5 % |
| 20 → 30 | 9s 18c | 35c | 11c | 53c | 1s 5c | 9s 11c | -0.8 % | 1.1 % → 5.5 % / 10.9 % |
| 30 → 40 | 24s 39c | 85c | 21c | 1s 5c | 2s 10c | 24s 40c | +0.0 % | 0.9 % → 4.1 % / 8.3 % |
| 40 → 50 | 65s 65c | 2s 14c | 44c | 2s 20c | 4s 40c | 66s 3c | +0.6 % | 0.7 % → 3.2 % / 6.5 % |
| 50 → 60 | 1g 45s 4c | 5s 98c | 92c | 4s 60c | 9s 19c | 1g 47s 35c | +1.6 % | 0.6 % → 3.0 % / 6.0 % |
<!-- end generated -->

## Appendix A: the models

All from the shipped code (Round 33 survey, verified by hand):

- **Warrior:** Strike on the weapon's swing clock (`full_punch_interval /
  (1 + attack speed)`), damage `W + Str/10`; Mighty Blow replaces a due swing
  at 25 rage with `floor(1.5 W) + Str/10`; rage +8 per landed swing and +3 per
  hit taken, one mob hit per second (`grug_abilities/kits.lua:357-399`,
  `init.lua:93-111`).
- **Scout:** full-draw Loose `(bow + Dex/10) × 2.25` every
  `2.5 s / (1 + the bow's own attack speed)` (`grug_abilities/scout.lua:63-87,
  335-357`).
- **Mage:** Fireball `Bw(L) + Int/10`, 6 % of P(L) per cast, at most one cast a
  second; the fight's mana is the pool plus 60 s of in-combat regeneration
  `max(0.25 (1 + 0.15 L), 0.0025 × max mana)` (`kits.lua:545-620`,
  `init.lua:131-145`).
- **Priest:** Heal `25 % P(L) × (1 + gear Int / 10 / B(L))` (Round 36;
  `grug_classes/stats.lua` `get_support_factor`, `kits.lua` `support_value`),
  8 % P(L), heals crit ×2 (v2); Smite `1.5 (Bw + Int/10)`, 5 %, every 2 s
  (`kits.lua`, `grug_core/combat.lua` `heal_player`).
- **Crit** `5 % + 0.05 % Dex + gear`, cap 30 %, ×2 on every swing, spell, arrow
  and heal (v2; before Round 33 0.1 % and ×1.5); **Dodge** `0.1 % Dex + gear`, cap 30 %; **armor**
  `min(0.70, R / (R + K))`, `K(L) = 20 + 0.5 min(L, 60) + 8.5 max(L − 60, 0)`
  ([combat_stats.md](combat_stats.md) §2).
- **Effective HP** `= HP / ((1 − dodge)(1 − armor reduction))` against a
  same-level foe; the Warrior's armor is the metal set, with or without a
  shield (a shield adds the full metal set's rating).
- Attributes enter continuously (`Str/10`, not `floor`): the expected value
  over the class's growth.

## Appendix B: the scripts

| Script | Prints |
|---|---|
| `tools/r33_ds/stat_values.py [--check]` | §1 tables, class check, Dexterity split, base change and crit talents |
| `tools/r33_ds/availability.py` | where every mob loot item drops, per faction |
| `tools/r33_ds/allocation.py [--check] [--json]` | §2–§3 inputs, signature uses, the two JSON files |
| `tools/r33_ds/alchemy.py` | §5 |
| `tools/r33_ds/money.py [--factor F]` | §6 |
| `tools/r33_ds/build_doc.py [--check]` | refreshes the generated blocks of this file |
