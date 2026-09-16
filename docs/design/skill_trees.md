# Skill Trees (Talents) — WP11

**PROPOSAL 2026-09-16, NOT DECIDED.** This file is a complete proposal for
WP11, written so the user can decide it in one pass. Nothing here is
implemented, nothing in `mods/` was changed for it, and no other design file
was altered beyond a one-paragraph pointer in
[classes.md](classes.md) and [progression.md](progression.md).

The decided frame this proposal must fit is not restated as new design; it is
quoted where it binds:

- `progression.md` §2: "**1 talent point every 3 levels** (20 points total at
  60); talent trees hold 2 trees x 5 talents x 3 ranks = 30 ranks per class —
  you can fill two thirds: real choices, no full clear (WP11)"; "**exactly one
  capstone per tree**, unlocked at 8+ points in that tree, and **every capstone
  is a NEW active 'main skill'**"; "**Respec at the class trainer for gold**,
  price rising with level".
- `classes.md` core principles: "new active 'main skills' come from talent
  capstones (WP11, progression.md) — talents otherwise improve existing buttons
  rather than adding many new ones".
- `classes.md` §5: "Renew *(talent)* ... Unlocked via the Holy tree (WP11)".
- `economy.md` §4: "**Talent respec:** repeatable at the class trainer, rising
  with level".
- `AGENTS.md` layering: `docs/design/` holds *decided* design with no open
  questions. This file carries an open-decisions section (§5) because the lane
  brief asked for the proposal and its decisions in one deliverable; §5.1 is
  the decision about where the open questions should live once the rest is
  settled.

Everything this proposal says about the code today is a `file:line` citation
into the tree at `f37a0c5b`.

---

## 1. The shape

### 1.1 Trees per class

The three shipped classes are Warrior, Mage and Priest
(`mods/PLAYER/grug_classes/init.lua:136`, `:146`, `:156`). No class is
invented. Each gets two trees, and each tree is derived from what the class's
shipped kit already does, so a tree is a direction the player already feels:

| Class | Tree | What it is | Derived from |
|---|---|---|---|
| Warrior | **Bulwark** | take hits and hold attention | Taunt, the x3 tank threat of `classes.md` §3, armor rank 3 (`init.lua:143`) |
| Warrior | **Ruin** | spend rage for damage and control | Mighty Blow (`kits.lua:320`), Hamstring (`kits.lua:349`) |
| Mage | **Ember** | direct fire damage | Fireball (`kits.lua:436`) |
| Mage | **Rime** | control, distance, staying alive | Frost Nova (`kits.lua:477`), Blink (`kits.lua:517`) |
| Priest | **Mercy** | keeping others up | Flash Heal (`kits.lua:596`), Power Word: Shield (`kits.lua:623`), Renew (`kits.lua:651`) |
| Priest | **Reckoning** | solo damage and self-sufficiency | Smite (`kits.lua:572`) |

Tree names are proposals and are own names, per `AGENTS.md:893` ("Never copy
WoW assets/names 1:1"). `progression.md` §2 and `classes.md` §5 currently call
the Priest healing tree "the **Holy** tree"; **Mercy** is the same tree under
an own name. That rename is open decision §5.6.

### 1.2 Tiers and prerequisites inside a tree

Each tree holds five talents in three tiers:

| Tier | Talents | Unlocked at | Contents |
|---|---|---|---|
| 1 | 2 | 0 points in this tree | the two entry modifiers |
| 2 | 2 | **3 points** in this tree | the two stronger modifiers |
| 3 | 1 | **8 points** in this tree | the capstone: a new active main skill |

- The gate is **points already spent in that tree**, not in that tier, which
  is the only prerequisite rule the proposal has. There are no per-talent
  arrows: with five talents, arrows add bookkeeping and no decision.
- The 8-point gate on tier 3 is `progression.md` §2 verbatim.
- Every talent has **3 ranks**, the capstone included (rank 1 grants the
  ability; ranks 2 and 3 improve it). That is what makes the class total
  2 x 5 x 3 = **30 ranks** come out exactly as `progression.md` §2 states; see
  open decision §5.4 for the alternative.

### 1.3 Points, and the arithmetic of "two thirds fillable"

- One point at **every level divisible by 3**: levels 3, 6, 9, ..., 60.
  Point count at level L is `floor(L / 3)`; at level 60 that is
  **20 points**. Levels 1 and 2 grant none, so the first decision arrives at
  level 3.
- Ranks available per class: 2 trees x 5 talents x 3 ranks = **30**.
- **20 / 30 = 2/3 exactly.** A character at 60 has spent two thirds of the
  ranks in their class and can never hold all of them.
- One tree alone costs 5 x 3 = **15** ranks, so a 20-point character can fill
  one tree completely and still has 5 points for the other; filling both would
  need 30. "No full clear" holds in the class, not in the tree.
- Capstone reachability: the first capstone rank costs 8 points of
  prerequisite plus itself = **9 points in that tree** = level 27. Two
  capstones cost 9 + 9 = **18 <= 20**, so a level-60 character can hold both
  new main skills, with 2 points left over — the second lands at level 54.
  Whether that is wanted is open decision §5.5.
- XP loss never de-levels (`progression.md` §3, and `grug_xp` clamps the loss
  to the level floor, `mods/PLAYER/grug_xp/init.lua:85-96`), so a point is
  never taken back by dying.

### 1.4 Respec

- **Where:** the class trainer, per `progression.md` §2 and `economy.md` §4.
  No class-trainer NPC exists yet: `world.md:408` says capitals hold class
  trainers, but `docs/research/wp13-npc-sockets-contract.md` §8.4 lists
  `vendor.kind` as `{race, general, butcher, smith, fishmonger, baker, tailor}`
  plus the wave-2 kinds, with **no `trainer` kind**. See open decision §5.8.
- **What:** a respec sets every rank to 0 and returns all earned points. The
  proposal has no partial (single-tree) respec — one button, one price, no
  argument about which half was refunded.
- **Price:** `economy.md` §3 forbids a stale fixed copper table and requires
  time-priced sinks to derive their ledger amount from **measured reliable net
  solo income**, exactly as mount pacing (§4.2) and claim upgrades (§4.1) do.
  The proposal therefore prices a respec as **5 minutes of reliable net solo
  income at the character's own level bracket**, rounded by §4.1's rule (the
  coarsest denomination in `1s / 25c / 5c / 1c` whose nearest multiple stays
  within 5% of the target, exact midpoints upward). Because bracket income
  rises on the same approximate x2.5 tier index as everything else
  (`economy.md` §3), the price "rises with level" without a hand-written
  table, and WP44 calibrates the six numbers with every other measured sink.
- **The first respec of a character is free.** It is the safety net for a
  mis-clicked first point at level 3, when the character has no money at all.
  Open decision §5.7 carries both halves of this.
- **A class switch is not a respec.** `/class` is an admin command
  (`selection.lua:554-596`) and already wipes kit state through `sync_kit`
  (`grug_abilities/init.lua:1772-1780`); it clears all talents and returns all
  points, free.

---

## 2. The talents

Reading the tables:

- **Effect** is written in the vocabulary of `combat_stats.md` §1/§2/§4 —
  armor percent, crit chance, rage, mana, spell power, threat — never in a
  new stat.
- **Modifies** names the shipped line the rank changes, or says "new ability".
- **Key** is the effect key of the data model in §3.2. Three ranks are always
  written `a / b / c`.
- Caps are never lifted by a talent: crit stays capped at 30%, dodge at 30%,
  armor at 60% (`combat_stats.md` §2; the clamps live at
  `grug_classes/stats.lua:45`, `:49` and `grug_core/combat.lua:38`).

### 2.1 Warrior — Bulwark

| # | Talent | Tier | Ranks 1/2/3 | Modifies | Key |
|---|---|---|---|---|---|
| 1 | **Iron Discipline** | 1 | +2 / +4 / +6 armor percent (still capped at 60) | `grug_inventory/equipment.lua:479` (the `get_armor_percent` override) | `armor_percent_add` |
| 2 | **Battle Hunger** | 1 | +1 / +2 / +3 rage per hit taken (on top of the base 4) | `grug_abilities/init.lua:2109-2110`, beside the orc perk | `rage_per_hit_taken_add` |
| 3 | **Grudge** | 2 | Taunt cooldown 8 s -> 7 / 6 / 5 s | `kits.lua:387` | `taunt_cooldown_sub` |
| 4 | **Unyielding** | 2 | while at or below 30% max HP, damage taken -3% / -6% / -9% | the central hp-change modifier in `grug_core/combat.lua`, in the armor step of the §2 order (dodge -> armor -> ward -> absorb) | `low_hp_reduction_percent` |
| 5 | **Stand Fast** *(capstone)* | 3 | **new ability** (cast): 25 rage, 60 s cooldown, self; damage taken -25% / -30% / -35% for 8 s | new; reuses the same reduction seam as Unyielding | — |

Stand Fast takes the Warrior's **fifth** hotbar slot (Strike plus three class
abilities occupy 1-4; `classes.md` §2b keys 1-8).

### 2.2 Warrior — Ruin

| # | Talent | Tier | Ranks 1/2/3 | Modifies | Key |
|---|---|---|---|---|---|
| 1 | **Heavy Hand** | 1 | Mighty Blow 1.5x -> 1.6 / 1.7 / 1.8x weapon damage | `kits.lua:342` | `mighty_blow_multiplier_add` |
| 2 | **Bloodrush** | 1 | +1 / +2 / +3 rage per landed authoritative swing (base 12) | `grug_abilities/init.lua:939`, `:950` and `:966` | `rage_per_swing_add` |
| 3 | **Cruel Edge** | 2 | +1 / +2 / +3 percentage points crit chance (cap 30% holds) | `grug_classes/stats.lua:44-46` | `crit_chance_add` |
| 4 | **Cripple** | 2 | Hamstring charge 6 s -> 5.5 / 5.0 / 4.5 s | `kits.lua:356` | `hamstring_charge_sub` |
| 5 | **Reaving Strike** *(capstone)* | 3 | **new ability** (swing): 30 rage, 10 s charge; on a landed swing `floor(weapon damage x 2.0 / 2.25 / 2.5) + melee bonus` on the target and half of that, rounded down, on every other hostile within 3 m; x3 threat | new; `proc_swing` shape of `kits.lua:340-344`, radius loop of `kits.lua:490` | — |

Reaving Strike is the game's first melee cleave. It is a swing skill, so it
costs no new timing machinery: it rides the authoritative swing exactly as
Mighty Blow does (`classes.md` §2b), and its charge keeps it off every swing.

### 2.3 Mage — Ember

| # | Talent | Tier | Ranks 1/2/3 | Modifies | Key |
|---|---|---|---|---|---|
| 1 | **Kindling** | 1 | Fireball damage `6 + spell power` -> `+1 / +2 / +3` | `kits.lua:458` | `fireball_damage_add` |
| 2 | **Far Cast** | 1 | Fireball maximum distance 20 m -> 22 / 24 / 26 m | `kits.lua:413` (and the ability `range`, `kits.lua:446`) | `fireball_range_add` |
| 3 | **Scorching Focus** | 2 | +1 / +2 / +3 percentage points crit chance | `grug_classes/stats.lua:44-46` | `crit_chance_add` |
| 4 | **Deep Well** | 2 | max mana +5% / +10% / +15% | `grug_classes/stats.lua:25-31` | `max_mana_percent_add` |
| 5 | **Cinderfall** *(capstone)* | 3 | **new ability** (cast): 12 mana, 10 s cooldown, 20 m; a burst at the first thing the crosshair ray meets, dealing `5 / 7 / 9 + spell power` to every hostile within 3 m of it | new; `grug_core.combat_ray` (`kits.lua:58`) plus the radius loop of `kits.lua:490` | — |

Cinderfall is the game's first area damage spell and is deliberately the Mage's
answer to a pack, which Frost Nova can only delay.

### 2.4 Mage — Rime

| # | Talent | Tier | Ranks 1/2/3 | Modifies | Key |
|---|---|---|---|---|---|
| 1 | **Deep Chill** | 1 | Frost Nova root 4 s -> 4.5 / 5.0 / 5.5 s | `kits.lua:495` (players) and `:504` (mobs) | `frost_nova_root_add` |
| 2 | **Quick Step** | 1 | Blink cooldown 15 s -> 13 / 11 / 9 s | `kits.lua:526` | `blink_cooldown_sub` |
| 3 | **Hoarfrost** | 2 | Frost Nova follow-up slow 3 s -> 4 / 5 / 6 s (the 50% stays) | `kits.lua:496` and `:505` | `frost_nova_slow_add` |
| 4 | **Cold Focus** | 2 | in-combat mana regeneration 0.5%/s -> 0.7 / 0.9 / 1.1%/s | `grug_abilities/init.lua:2202` | `combat_mana_regen_add` |
| 5 | **Glacial Ward** *(capstone)* | 3 | **new ability** (cast): 10 mana, 30 s cooldown, self only; absorbs `10 / 15 / 20 + 2 x spell power` damage for 10 s | new; `grug_core.set_absorb` (`grug_core/combat.lua:1012`) | — |

Named consequence, not a defect to discover later: there is **one absorb per
player** and a new one replaces the old (`grug_core/combat.lua:1003-1012`), so
a Priest's Power Word: Shield and a Mage's own Glacial Ward overwrite each
other. The proposal accepts that rather than building shield stacking.

### 2.5 Priest — Mercy

| # | Talent | Tier | Ranks 1/2/3 | Modifies | Key |
|---|---|---|---|---|---|
| 1 | **Gentle Hand** | 1 | Flash Heal `8 + 2 x spell power` -> `+1 / +2 / +3` | `kits.lua:613` | `flash_heal_add` |
| 2 | **Warding Faith** | 1 | Power Word: Shield absorb -> `+2 / +4 / +6` | `kits.lua:640` | `shield_absorb_add` |
| 3 | **Quiet Steps** | 2 | heal threat factor 0.5 -> 0.4 / 0.3 / 0.2 (`combat_stats.md` §4) | `grug_core/combat.lua:241` via `add_heal_threat` (`:404`) | `heal_threat_factor_sub` |
| 4 | **Meditation** | 2 | max mana +5% / +10% / +15% | `grug_classes/stats.lua:25-31` | `max_mana_percent_add` |
| 5 | **Renew** *(capstone)* | 3 | **the already-registered ability** (`kits.lua:651-677`), granted at rank 1 exactly as `classes.md` §5 specifies (6 mana, 8 s cooldown, `3 + spell power` every 3 s for 12 s); ranks 2 and 3 raise the tick to `4` and `5 + spell power` | `kits.lua:671`; the grant gate is `talent_gated = true` at `kits.lua:656` | `renew_tick_add` |

Renew is kept as the Priest healing capstone, as `classes.md` §5 and
`progression.md` §2 already decided. It is the one capstone that needs no new
ability code at all — only the grant gate of §3.4.

### 2.6 Priest — Reckoning

| # | Talent | Tier | Ranks 1/2/3 | Modifies | Key |
|---|---|---|---|---|---|
| 1 | **Sharpened Word** | 1 | Smite `4 + spell power` -> `+1 / +2 / +3` | `kits.lua:591` | `smite_damage_add` |
| 2 | **Swift Word** | 1 | Smite cooldown 2 s -> 1.8 / 1.6 / 1.4 s | `kits.lua:581` | `smite_cooldown_sub` |
| 3 | **Warded Wrath** | 2 | while the Priest carries an absorb shield, Smite deals `+1 / +2 / +3` | `kits.lua:591`, gated on `grug_core.get_absorb(user) > 0` (`grug_core/combat.lua:1020`) | `smite_damage_while_shielded_add` |
| 4 | **Zealous Mind** | 2 | +1 / +2 / +3 percentage points crit chance | `grug_classes/stats.lua:44-46` | `crit_chance_add` |
| 5 | **Word of Ruin** *(capstone)* | 3 | **new ability** (cast): 8 mana, 12 s cooldown, 20 m; `6 / 8 / 10 + spell power` damage and heals the Priest for 50% of the damage actually dealt | new; `grug_core.deal_ability_damage` already returns the landed amount (`grug_core/combat.lua:970`), healed back with `grug_core.heal_player(..., {no_crit = true})` (`:977-981`, `:984`) so one crit is not counted twice | — |

Word of Ruin is the Priest's solo-viability capstone and the counterpart to
Mercy's group capstone. The `no_crit` flag exists for exactly this class of
derived heal (`grug_core/combat.lua:977-981`).

### 2.7 Count

Per class: 10 talents, of which **8 are numeric modifiers and 2 are
capstones**, 30 ranks. Across three classes: 30 talents, 90 ranks, 24 numeric
talents over 21 distinct effect keys (`crit_chance_add` is used by all three
classes, `max_mana_percent_add` by two), and 6 capstones of which one (Renew)
already exists in code. `progression.md` §2's "9 of 10 talents are numeric
modifiers" does not survive "exactly one capstone per tree" — that is open
decision §5.3.

---

## 3. Data model and seams

### 3.1 Where talents live

New file **`mods/PLAYER/grug_classes/talents.lua`**, loaded from the existing
`dofile` block at `grug_classes/init.lua:210-213`, next to `stats.lua` and
`perks.lua`. `grug_classes` is the right owner for three reasons that already
hold in the tree: it owns the class registry (`init.lua:11-18`) and its def
comment already reserves room for "skill trees (WP11)" (`init.lua:7-8`); it
already owns the per-player derived stats every numeric talent touches
(`stats.lua`); and it is a dependency of both `grug_inventory` and
`grug_abilities` (`stats.lua:79-82`), so both can read talents without a new
dependency edge.

Registration mirrors `register_class` (`init.lua:14`):

```lua
grug_classes.register_tree({
    id = "bulwark", class = "warrior", name = "Bulwark",
    description = "Take the hits and hold their attention.",
})

grug_classes.register_talent({
    id = "iron_discipline", tree = "bulwark", tier = 1, name = "Iron Discipline",
    description = "Armor +2% per rank.",
    effects = {armor_percent_add = {2, 4, 6}},   -- one value per rank
})

grug_classes.register_talent({
    id = "stand_fast", tree = "bulwark", tier = 3, name = "Stand Fast",
    capstone = true,                             -- exactly one per tree
    ability = "stand_fast",                      -- the grug_abilities id it grants
    effects = {stand_fast_reduction = {25, 30, 35}},
})
```

`register_talent` asserts the shape at load time, the way
`register_ability` does (`grug_abilities/init.lua:475-510`): tier in 1..3,
three values per effect list, exactly one capstone per tree in tier 3, five
talents per tree, two trees per class, and every effect key present in the
closed vocabulary table. A typo is a startup failure, never a silently inert
talent.

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

Every numeric talent in §2 is one call to this function at the line the table
names, and nothing else. Two worked examples:

```lua
-- grug_classes/stats.lua:44 today
return math.min(0.30, 0.05 + 0.001 * grug_classes.get_attributes(player).dex)
-- with talents (the 30% cap of combat_stats.md §2 still binds)
return math.min(0.30, 0.05 + 0.001 * grug_classes.get_attributes(player).dex
    + 0.01 * grug_classes.get_talent_bonus(player, "crit_chance_add"))

-- kits.lua:342 today
return math.floor(ctx.weapon_damage * 1.5) + ctx.melee_bonus, 3, ...
-- with talents
local mult = 1.5 + 0.1 * grug_classes.get_talent_bonus(user, "mighty_blow_multiplier_add")
return math.floor(ctx.weapon_damage * mult) + ctx.melee_bonus, 3, ...
```

A second, smaller accessor answers unlock questions:

```lua
-- 0..3; used by the kit grant and the UI, never by a numeric consumer.
function grug_classes.talent_rank(player, talent_id)
```

There is no third seam. A talent that cannot be expressed as "one key, summed,
read at one line" does not belong in this proposal's first round.

### 3.3 Persistence

- One player-meta **string** key, `grug_classes:talents`, holding
  `id=rank` pairs separated by commas: `iron_discipline=2,grudge=1`. The same
  store class and race already use (`grug_classes/init.lua:3-4`, `:76`,
  `:113`); a string keeps it to one key instead of thirty, and it stays
  human-readable for `/talents` debugging.
- Parsed once per join into a per-player runtime cache (the pattern of
  `grug_abilities`' runtime tables, `init.lua:22-38`), invalidated on spend,
  respec, class change and leave.
- **The read path validates, it does not trust.** Unknown ids are dropped,
  ranks are clamped to the talent's rank count, a rank whose tier gate is not
  met is dropped, and the total spent is clamped to `floor(level / 3)`. A
  hand-edited meta string therefore cannot buy a capstone at level 4.
- Nothing else is persisted. Points available are always derived
  (`floor(grug_xp.get_level(player) / 3)`, `grug_xp/init.lua:48`), never
  stored, so the two can never disagree.

### 3.4 Granting a capstone ability

The capstones are ordinary `grug_abilities` registrations with
`talent_gated = true`, exactly like Renew today (`kits.lua:656`). Two
existing sites decide what a kit is, and the file itself states they must
never disagree (`grug_abilities/init.lua:1705-1710`):

- `kit_of(class)` (`init.lua:1716-1729`) currently drops every
  `talent_gated` def. It becomes `kit_of(class, player)` and keeps a gated def
  when `grug_classes.talent_rank(player, def.talent) > 0`.
- The purge branch in `sync_kit` (`init.lua:1808-1810`) uses the same
  predicate, or a granted capstone would be destroyed on the next sync.

**Hotbar order is preserved**: capstones are appended *after* the base class
kit, in tree registration order, so unlocking one cannot push Power Word:
Shield off key 4 — the concern the file's own comment raises at
`init.lua:1712-1715`. A Warrior with both capstones fills keys 1-6 of 8.

Re-granting is driven by a new callback that mirrors
`register_on_class_chosen` (`grug_classes/init.lua:68`, consumed at
`grug_abilities/init.lua:1881`):

```lua
grug_classes.register_on_talents_changed(function(player) sync_kit(player) end)
```

It fires on every spend and on respec. Nothing else in `grug_abilities`
changes for the capstones.

### 3.5 UI

A third `sfinv` page beside Character and Bags
(`grug_inventory/pages.lua:192`, `:233`), registered from a new
`grug_classes/talents_ui.lua` so the page lives with the data it shows and
`grug_inventory` keeps its two pages. sfinv uses legacy coordinates and the
content area spans about y 0.3-5.0 (`pages.lua:1-2`).

```
+---------------------------------------------------------------+
| Character | Bags | Talents |                        (sfinv tabs)
+---------------------------------------------------------------+
| Warrior     Points left: 4         [ Respec -- at a trainer ]  |
|                                                               |
|   BULWARK  (7)                  RUIN  (9)                     |
|   +-------------------+         +-------------------+         |
| T1| Iron Discipline 3/3|        | Heavy Hand     3/3|         |
|   | Battle Hunger   2/3|        | Bloodrush      0/3|         |
|   +-------------------+         +-------------------+         |
| T2| Grudge          2/3|        | Cruel Edge     3/3|   (>=3) |
|   | Unyielding      0/3|        | Cripple        2/3|         |
|   +-------------------+         +-------------------+         |
| T3| Stand Fast      0/3|        | Reaving Strike 1/3|   (>=8) |
|   |  locked: 7/8 pts  |         +-------------------+         |
|   +-------------------+                                       |
|                                                               |
| Cruel Edge -- rank 3/3: +3% crit chance. Next rank: maxed.    |
+---------------------------------------------------------------+
```

- Each talent is one `button` whose label is `Name  r/3`; a locked tier's
  buttons are rendered as plain labels (no click target) with the gate spelled
  out ("needs 8 points in Bulwark").
- Clicking a talent selects it and writes the one-line explanation at the
  bottom (current rank, next rank, what it changes). Clicking the selected
  talent again spends a point, so the page needs no separate "+" column and no
  confirmation dialog.
- `Points left` is the whole budget display; the per-tree number in the header
  is what the tier gates read.
- The Respec button is present but **disabled outside a class trainer's
  range**, with the reason in its label — the price and the transaction belong
  to the trainer dialog (§1.4, open decision §5.8).
- No new texture is needed. Signature talent icons are a later art pass, the
  same way `classes.md` §2c parks signature ability icons.

### 3.6 Level-up flow

`grug_classes` already registers on the level-change callback
(`grug_classes/stats.lua:90-93`, the callback itself at
`grug_xp/init.lua:34`). The same registration gains the talent line: when
`floor(new_level / 3) > floor(old_level / 3)`, send one chat line under the
existing "Reached level N!" (`grug_xp/init.lua:62-64`):

```
Talent point available (2 unspent) -- open your inventory, Talents tab.
```

No new globalstep, no new HUD element, no new packet: a level-up is already a
chat event.

### 3.7 The KAT

`tools/wp13/talent_tree_kat.lua` (or `tools/wp11/`), plain Lua 5.1 under a
stub registry, in the shape of `tools/wp13/ability_rightclick_kat.lua:1-45` —
it loads the **real** `talents.lua` and the real `register_talent`, and runs
under both interpreters with identical output, as the common lane rules
require. Six groups, each of which can go red on its own:

1. **Shape.** Every class has exactly 2 trees, every tree 5 talents in tiers
   2/2/1, every talent 3 ranks, exactly one capstone per tree and it is in
   tier 3. Totals: 30 ranks per class.
2. **Arithmetic.** `floor(60/3) == 20`; `20/30` is two thirds; one tree costs
   15; both capstones cost 9 + 9 = 18 <= 20; two full trees cost 30 > 20.
   This is the row that goes red if anyone re-tunes the cadence without
   re-tuning the trees.
3. **Spend rules**, driven as a table of cases: a tier-2 rank with 2 points in
   the tree is refused; the capstone with 7 is refused and with 8 accepted; a
   4th rank is refused; a spend with 0 points left is refused; a spend at
   level 2 is refused.
4. **Persistence round trip.** Serialize -> parse -> identical; and forged
   meta (`unknown_id=2,stand_fast=9`) is dropped and clamped rather than
   honoured.
5. **Effect-key coverage.** Every key in the closed vocabulary is read by at
   least one consumer source file, and every `effects` key used by a talent is
   in the vocabulary. This is the row that goes red when a talent is added
   whose modifier nothing applies — the failure mode a numeric talent system
   has.
6. **Cap invariants.** With every crit talent at rank 3 on a level-60
   character, `get_crit_chance` still returns <= 0.30; with the armor talent at
   rank 3 on 60% gear, `get_armor_percent` still returns <= 60.

**Mutation proof** the review should demand: revert the one line of
`stats.lua:45` that adds `crit_chance_add` and group 5 must go red; raise a
talent to 4 ranks and group 1 must go red.

### 3.8 What changes where

| File | Change | Size |
|---|---|---|
| `grug_classes/talents.lua` | **new** — registry, the 30 talents, spend/respec, persistence, the two accessors | large |
| `grug_classes/talents_ui.lua` | **new** — the sfinv page | medium |
| `grug_classes/init.lua:210-213` | two `dofile` lines | 2 lines |
| `grug_classes/stats.lua:25,44,90` | three talent reads (max mana, crit, the level-up line) | small |
| `grug_abilities/kits.lua` | one talent read per numeric talent that touches a kit number (lines 342, 356, 387, 413, 458, 495, 496, 504, 505, 526, 581, 591, 613, 640, 671) plus five new capstone registrations | medium |
| `grug_abilities/init.lua:1716,1808,2109,2202,939` | the capstone grant predicate (two sites, one predicate), rage per hit taken, in-combat mana regen, rage per swing | small |
| `grug_inventory/equipment.lua:479` | the armor talent, inside the existing 60% clamp | 1 line |
| `grug_core/combat.lua:241` and the central hp-change modifier | heal threat factor, and the damage-reduction window Unyielding and Stand Fast share | small |
| `tools/wp13/talent_tree_kat.lua` | **new** — §3.7 | medium |
| `docs/design/classes.md`, `progression.md`, `README.md` | pointer paragraphs and the design-tour row (`AGENTS.md:84-86`) | small |

---

## 4. Implementation lanes

Four lanes, in dependency order. Lanes 2 and 3 can run in parallel once lane 1
has landed; lane 4 needs lane 1 only.

| Lane | Scope | Depends on | Size |
|---|---|---|---|
| **X1 — the model** | `talents.lua`: registry, the 30 registrations (data only, no consumer), points, spend/respec rules, persistence with the validating read path, `get_talent_bonus` / `talent_rank`, the `on_talents_changed` callback, and the whole KAT of §3.7 except group 5's consumer half. Ships with **zero gameplay effect** — every talent is inert. | — | M |
| **X2 — the numeric consumers** | The 24 numeric talents: one read per line in the §3.8 table, across `kits.lua`, `stats.lua`, `grug_abilities/init.lua`, `grug_inventory/equipment.lua` and `grug_core/combat.lua`. Completes KAT group 5 and adds group 6. Touches shared files, so it is one lane and not split by class. | X1 | M |
| **X3 — the capstones** | Five new ability registrations (Stand Fast, Reaving Strike, Cinderfall, Glacial Ward, Word of Ruin), Renew's rank scaling, the one grant predicate at both `sync_kit` sites, the shared damage-reduction window, and an engine probe per capstone. This is the only lane with new combat behaviour. | X1 | L |
| **X4 — UI, level-up and respec** | The sfinv Talents page, the level-up chat line, the respec transaction against `grug_money`, and the class-trainer seam of open decision §5.8. | X1 | S-M |

X3 is the only lane that owes a runtime test on a headless server; X1, X2 and
X4 are provable with the KAT plus one probe each.

---

## 5. Open decisions for the user

Numbered for the reply. Each carries both defensible options and a
recommendation; none of them is decided here.

**5.1 — Where this proposal lives while it is open.**
`AGENTS.md:66-71` reserves `docs/design/` for decided design with no open
questions, and puts open questions in a root `TODO-<topic>.md` that is folded
in and deleted on decision. This file is in `docs/design/` because the lane
brief named that path.
*(a)* Keep it here with the PROPOSAL banner, and strip §5 when it is decided.
*(b)* Move §§1-4 to `TODO-design-skill-trees.md` now and create
`docs/design/skill_trees.md` only on the decision.
**Recommendation: (a)** — one file, one review, and the banner is unambiguous;
the layering rule is satisfied the moment §5 is answered and removed.

**5.2 — The point cadence contradicts itself across two decided files.**
`combat_stats.md:14` says "skills are acquired and improved through the class
skill tree (**1 skill point per level**)"; `progression.md:20` says "**1 talent
point every 3 levels** (20 points total at 60)". At 1/level a character has 59
points against 30 ranks and fills everything twice over, which destroys "two
thirds fillable".
*(a)* `progression.md` wins; correct `combat_stats.md:14`.
*(b)* `combat_stats.md` wins; re-cut the trees to roughly 90 ranks.
**Recommendation: (a)** — the whole 20/30 arithmetic and the capstone gate at
8 points are built on it, and `combat_stats.md:14` reads like a pre-2026-08-06
leftover in a "core principles" list rather than a specification.

**5.3 — "9 of 10 talents are numeric" versus "one capstone per tree".**
`progression.md:23-25` says both, and per class they cannot both hold: 2 trees
x 5 talents = 10 talents, of which 2 are capstones, so it is 8 numeric and 2
capstones. `BACKLOG.md`'s WP11 row repeats the same phrase as "9 numeric
talents + 1 capstone per tree", which would mean 10 talents per *tree*.
*(a)* Restate as "eight numeric talents and two capstones per class".
*(b)* Keep 9 numeric by making one tree's tier-3 slot a numeric talent and
giving the class only one capstone — which contradicts "exactly one capstone
per tree".
**Recommendation: (a)**, a wording fix in `progression.md` and `BACKLOG.md`.

**5.4 — Does the capstone have three ranks?**
30 ranks per class is only exact if all five talents have three ranks,
capstone included.
*(a)* Capstone has 3 ranks: rank 1 grants the ability, 2 and 3 improve it
(this proposal).
*(b)* Capstone has 1 rank and one numeric talent in the tree gets 5 ranks, so
the tree still holds 15.
**Recommendation: (a)** — it keeps "x 3 ranks" literally true for every
talent, and a capstone the player can keep investing in is a better level-50s
reward than one that is finished the moment it arrives.

**5.5 — May a level-60 character hold both capstones?**
At the decided 8-point gate, two capstones cost 9 + 9 = 18 of 20 points, so
yes, with 2 points to spare. That is two new main skills by level 60 (at
levels 27 and 54).
*(a)* Keep 8. Both capstones are reachable; the cost is that a both-capstones
build has only 2 points of numeric depth left, which is a real trade.
*(b)* Raise the gate to 11 points in-tree, which makes 11 + 11 = 22 > 20 and
guarantees exactly one new main skill per character.
**Recommendation: (a)** — it is the number `progression.md` §2 already
decided, and "the second capstone at level 54" is a good late beat on a curve
that otherwise stops giving new buttons after level 27.

**5.6 — Tree names.**
`progression.md:26` and `classes.md:448` call the Priest healing tree "the
**Holy** tree", which is a WoW priest tree name 1:1 and `AGENTS.md:893` says
never to copy those. The same question applies to the six names this file
proposes (Bulwark, Ruin, Ember, Rime, Mercy, Reckoning).
*(a)* Adopt the six own names; correct the two "Holy tree" mentions.
*(b)* Keep "Holy" and pick names in that register for the rest.
**Recommendation: (a)**. Note separately that several *shipped* ability names
(Power Word: Shield, Frost Nova, Flash Heal, Blink, Hamstring, Charge, Smite,
Taunt, Renew) are in the same position; that is pre-existing, outside WP11,
and is only flagged here, not changed.

**5.7 — Respec price shape.**
`economy.md` §4 and `progression.md` §2 say "for gold, rising with level" and
name no number, and `economy.md` §3 forbids a stale fixed table.
*(a)* 5 minutes of measured reliable net solo income at the character's
bracket, first respec free (this proposal).
*(b)* The same per-bracket base, but doubling with each respec inside a
rolling window, so serial re-specs are a real sink.
**Recommendation: (a)** — "rising with level" is what the two decided files
say, and (b) adds a timer and a counter to persist for a sink that is not yet
measured. Sub-question inside (a): should the first respec really be free?
Recommended yes, because the first point is spent at level 3 by a character
with no money.

**5.8 — The class trainer does not exist.**
`world.md:408` says capitals hold class trainers, `progression.md` §2 puts the
respec there, and `docs/research/wp13-npc-sockets-contract.md` §8.4's
`vendor.kind` list has no `trainer` kind, so there is no NPC and no socket.
*(a)* WP11 ships the talent system with an admin/debug `/respec` only, and a
later WP13 lane adds the `trainer` kind, the socket in each capital and the
dialog.
*(b)* WP11 also ships the trainer NPC, which means it takes on
`grug_traders`-shaped work and a socket vocabulary change owned by WP13.
**Recommendation: (a)** — it keeps WP11 inside `grug_classes`/`grug_abilities`
and does not make a talent system wait on capital content. The consequence to
accept: until that lane lands, respec is not purchasable and the gold sink of
`economy.md` §4 is not yet live.

**5.9 — Talents on an admin level drop.**
`/xp` can lower a level (`grug_xp/init.lua:142-162`), after which spent ranks
can exceed `floor(level/3)`.
*(a)* Block further spending until the level catches up, and leave the
existing ranks alone.
*(b)* Auto-refund the excess ranks, cheapest-tier first.
**Recommendation: (a)** — (b) would silently unspend a player's choices for an
admin action, and the validating read path of §3.3 already prevents the state
from being reachable by anything but an admin.

**5.10 — Are talents wiped by a class switch?**
`/class` is admin-only and already wipes kit state through `sync_kit`.
*(a)* A class switch clears all talents and returns all points, free.
*(b)* Talents are stored per class, so switching back restores the old build.
**Recommendation: (a)** — (b) needs a per-class meta key and exists only for
an admin command.

**5.11 — Does the capstone ability count against the hotbar?**
Two capstones put a Warrior at 6 of 8 hotbar items, and `classes.md` §2b's
"rotation is the hotbar" assumes keys 1-8.
*(a)* Accept; 8 is enough for the MVP and WP14's shield abilities are the next
claim on it.
*(b)* Cap a character at one capstone (which is decision 5.5b by another
route).
**Recommendation: (a)**.

**5.12 — Should any talent be allowed to lift a cap?**
Every numeric talent in §2 is written to respect the 30% crit, 30% dodge and
60% armor caps of `combat_stats.md` §2.
*(a)* Caps hold for talents exactly as they hold for gear; a capped
character's crit talent is dead weight and the Character page shows "raw" like
it does for gear (`combat_stats.md` §2).
*(b)* Talent points count outside the cap, which makes them strictly better
than gear at 60.
**Recommendation: (a)** — `combat_stats.md` §2 states that "values above a cap
remain present on their stacks but have no further combat effect" and that
"there is no automatic overflow conversion or cap raise", and a talent
exception would be the first one.
