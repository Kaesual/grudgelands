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

Every tree name here is a proposal, and **naming is not settled**:
`AGENTS.md:893` says "Never copy WoW assets/names 1:1", and several of the
names in this file — trees and talents both — are ordinary English words that
WoW also uses for talents. §5.6 lists them and is the decision.
`progression.md` §2 and `classes.md` §5 currently call the Priest healing tree
"the **Holy** tree"; **Mercy** is the same tree, renamed, and that rename is
part of the same decision.

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
  armor percent, crit chance, rage, mana, spell power, threat. **One effect in
  the whole proposal needs a stat the game does not have**: the Warrior tank
  capstone Stand Fast, which is why it carries two variants and its own open
  decision (§5.13). Everything else, Unyielding included, is an existing
  term.
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
| 3 | **Grudge** | 2 | Taunt cooldown 8 s -> 7 / 6 / 5 s | `grug_abilities/init.lua:1233` — the one `arm_cooldown(user, def, def.cooldown)` call, **not** the `cooldown = 8` constant at `kits.lua:387` | `taunt_cooldown_sub` |
| 4 | **Unyielding** | 2 | while at or below 30% max HP, **+4 / +8 / +12 armor percent** — the same stat Iron Discipline adds, under the same 60% cap, so it introduces no new mitigation term | `grug_inventory/equipment.lua:479` | `armor_percent_add_low_hp` |
| 5 | **Stand Fast** *(capstone)* | 3 | **new ability** (cast): 25 rage, 60 s cooldown, self. **Two variants — open decision §5.13.** *(A)* damage taken -25% / -30% / -35% for 8 s, a mitigation term `combat_stats.md` §2 does not have; *(B)* a self-absorb of `20 / 30 / 40 + 2 x floor(Str/10)` for 8 s, built entirely from shipped machinery | *(A)* a new step in the central hp-change modifier; *(B)* `grug_core.set_absorb` (`grug_core/combat.lua:1012`) | — |

Stand Fast takes the Warrior's **sixth** hotbar slot. The Warrior kit is the
game's largest: universal Strike (`kits.lua:268`) plus **four** class abilities
— Charge (`:291`), Mighty Blow (`:321`), Hamstring (`:350`), Taunt (`:380`),
the four rows of `classes.md:415-418` — already occupy keys 1-5 of the eight
`classes.md` §2b reserves. Both Warrior capstones therefore reach key 7. That
is the hotbar cost open decision §5.11 asks the user to accept, and it is
tighter than the Mage's and the Priest's, who hold three class abilities each
and end at key 6.

### 2.2 Warrior — Ruin

| # | Talent | Tier | Ranks 1/2/3 | Modifies | Key |
|---|---|---|---|---|---|
| 1 | **Heavy Hand** | 1 | Mighty Blow 1.5x -> 1.6 / 1.7 / 1.8x weapon damage | `kits.lua:342` | `mighty_blow_multiplier_add` |
| 2 | **Bloodrush** | 1 | +1 / +2 / +3 rage per landed authoritative swing (base 12) | `grug_abilities/init.lua:939`, `:950` and `:966` | `rage_per_swing_add` |
| 3 | **Cruel Edge** | 2 | +1 / +2 / +3 percentage points crit chance (cap 30% holds) | `grug_classes/stats.lua:44-46` | `crit_chance_add` |
| 4 | **Cripple** | 2 | Hamstring charge 6 s -> 5.5 / 5.0 / 4.5 s | `grug_abilities/init.lua:718` — the one line that arms a charge, **not** the `charge = 6` constant at `kits.lua:356` | `hamstring_charge_sub` |
| 5 | **Reaving Strike** *(capstone)* | 3 | **new ability** (swing): 30 rage, 10 s charge; on a landed swing `floor(weapon damage x 2.0 / 2.25 / 2.5) + melee bonus` on the target and half of that, rounded down, on every other hostile within 3 m; x3 threat | new; `proc_swing` shape of `kits.lua:340-344`, radius loop of `kits.lua:490` | — |

Reaving Strike is the game's first melee cleave. It is a swing skill, so it
costs no new timing machinery: it rides the authoritative swing exactly as
Mighty Blow does (`classes.md` §2b), and its charge keeps it off every swing.

### 2.3 Mage — Ember

| # | Talent | Tier | Ranks 1/2/3 | Modifies | Key |
|---|---|---|---|---|---|
| 1 | **Kindling** | 1 | Fireball damage `6 + spell power` -> `+1 / +2 / +3` | `kits.lua:458` | `fireball_damage_add` |
| 2 | **Far Cast** | 1 | Fireball maximum distance 20 m -> 22 / 24 / 26 m | two per-player reads, neither at a registration constant: flight at the `grug_projectiles.spawn` call (`kits.lua:453-460`), which already honours `params.max_distance` over the registered default (`grug_projectiles/init.lua:195`); targeting reach in `grug_abilities.get_range` (`init.lua:170-177`), the twin of the elf `ability_range_bonus` perk, whose item-meta override `sync_kit` already refreshes (`init.lua:1827-1831`) | `fireball_range_add` |
| 3 | **Scorching Focus** | 2 | +1 / +2 / +3 percentage points crit chance | `grug_classes/stats.lua:44-46` | `crit_chance_add` |
| 4 | **Deep Well** | 2 | max mana +5% / +10% / +15% | `grug_classes/stats.lua:25-31` | `max_mana_percent_add` |
| 5 | **Cinderfall** *(capstone)* | 3 | **new ability** (cast): 12 mana, 10 s cooldown, 20 m; a burst at the first thing the crosshair ray meets, dealing `5 / 7 / 9 + spell power` to every hostile within 3 m of it | new; `grug_core.combat_ray` (`kits.lua:58`) plus the radius loop of `kits.lua:490` | — |

Cinderfall is the game's first area damage spell and is deliberately the Mage's
answer to a pack, which Frost Nova can only delay.

### 2.4 Mage — Rime

| # | Talent | Tier | Ranks 1/2/3 | Modifies | Key |
|---|---|---|---|---|---|
| 1 | **Deep Chill** | 1 | Frost Nova root 4 s -> 4.5 / 5.0 / 5.5 s | `kits.lua:495` (players) and `:504` (mobs) | `frost_nova_root_add` |
| 2 | **Quick Step** | 1 | Blink cooldown 15 s -> 13 / 11 / 9 s | `grug_abilities/init.lua:1233` (the shared `arm_cooldown` call), **not** `kits.lua:526` | `blink_cooldown_sub` |
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
| 2 | **Swift Word** | 1 | Smite cooldown 2 s -> 1.8 / 1.6 / 1.4 s | `grug_abilities/init.lua:1233` (the shared `arm_cooldown` call), **not** `kits.lua:581` | `smite_cooldown_sub` |
| 3 | **Warded Wrath** | 2 | while the Priest carries an absorb shield, Smite deals `+1 / +2 / +3` | `kits.lua:591`, gated on `grug_core.get_absorb(user) > 0` (`grug_core/combat.lua:1020`) | `smite_damage_while_shielded_add` |
| 4 | **Zealous Mind** | 2 | +1 / +2 / +3 percentage points crit chance | `grug_classes/stats.lua:44-46` | `crit_chance_add` |
| 5 | **Word of Ruin** *(capstone)* | 3 | **new ability** (cast): 8 mana, 12 s cooldown, 20 m; `6 / 8 / 10 + spell power` damage and heals the Priest for 50% of the damage actually dealt | new; `grug_core.deal_ability_damage` returns the post-crit, post-dodge amount (`grug_core/combat.lua:970`), healed back with `grug_core.heal_player(..., {no_crit = true})` (`:977-981`, `:984`) so one crit is not counted twice | — |

Word of Ruin is the Priest's solo-viability capstone and the counterpart to
Mercy's group capstone. The `no_crit` flag exists for exactly this class of
derived heal (`grug_core/combat.lua:977-981`).

One bound to state rather than let an implementer discover: that return value
is the amount the ability *published*, taken before the central modifier
applies armor (`:38`) and the absorb shield (`:1003-1030`) to a **player**
target. Against a mob it is what landed and the drain is exact; against an
armoured PvP target it over-heals by the mitigated share. This proposal
therefore specifies the drain as "50% of the damage dealt **before the
target's armor**" rather than promising a post-mitigation figure the pipeline
does not publish.

### 2.7 Count

Per class: 10 talents, of which **8 are numeric modifiers and 2 are
capstones**, 30 ranks. Across three classes: 30 talents, 90 ranks, 24 numeric
talents over 21 distinct effect keys (`crit_chance_add` is used by all three
classes, `max_mana_percent_add` by two), and 6 capstones of which one (Renew)
already exists in code. `progression.md` §2's "9 of 10 talents are numeric
modifiers" does not survive "exactly one capstone per tree" — that is open
decision §5.3.

### 2.8 Two consequences of touching shipped numbers

**The decided ability tables become *base* values.** `classes.md` §§3-5 state
their numbers flatly: Mighty Blow is "exactly floor(weapon damage x 1.5)"
(`classes.md:416`), Hamstring charges 6 s (`:417`), Taunt runs 8 s (`:418`),
Frost Nova roots 4 s then slows 3 s (`:437`), Smite has a 2 s cooldown
(`:452`), and the 2026-08-06 kit-tuning note reasons from "+12 rage per
auto-hit" (`:408`, `:421`). Fourteen talents re-tune exactly these. Nothing forbids
it — improving existing buttons is what `classes.md:50-52` says talents are
for — but when WP11 lands, those tables are the **unspecced baseline** and
`classes.md` needs that word, or the next reader will treat a talented Taunt
as a bug.

**Charge is the one shipped ability no talent touches.** §1.1 derives the
trees from what each kit already does, and the Warrior's engage tool
(`kits.lua:291`) is the gap: its 10 s cooldown, 12 m reach, 3 damage and
15 rage are all untouched by Bulwark and Ruin. That is a deliberate omission
rather than an oversight — the two Warrior trees are about holding a fight and
about spending rage, and a talent that only shortens the approach improves
neither — but a later round that wants a third Warrior direction has an
obvious, unused hook sitting there.

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

**Reading needs no new edge; the UI and the respec do.**
`grug_classes/mod.conf` depends on `grug_core`, `grug_factions` and `grug_xp`
only. The Talents page of §3.5 needs **`sfinv`** (today a dependency of
`grug_inventory` alone) and the respec transaction of §1.4 needs
**`grug_money`** (`grug_money.take`, `mods/PLAYER/grug_money/init.lua:122`).
Both are one-line `mod.conf` additions with a load-order consequence, and
lane X4 owns them — they are named here so nobody discovers them mid-lane.

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

Every numeric talent in §2 is one call to this function at the site the
table's **Modifies** column names, and nothing else. **The site is not always
in `kits.lua`.** A kit table's `cooldown`, `charge`, `range` and
`max_distance` fields are evaluated **once at load time**, with no player in
scope: a per-player read written there would change the number for everybody.
Five talents therefore hook the central per-player site instead, and each of
those sites already exists and is already the single one of its kind:

| Talent | The constant it re-tunes | Where the read goes |
|---|---|---|
| Grudge, Quick Step, Swift Word | `cooldown` in the ability def | `grug_abilities/init.lua:1233`, the sole `arm_cooldown(user, def, def.cooldown)` call |
| Cripple | `charge` in the ability def | `grug_abilities/init.lua:718`, the sole line that arms a charge timer |
| Far Cast | `max_distance` in the projectile registration and `range` in the ability def | the spawn call (`kits.lua:453-460`), since `grug_projectiles/init.lua:195` prefers `params.max_distance`; and `grug_abilities.get_range` (`init.lua:170-177`) for reach |

The other nineteen numeric talents do sit at the line their table names, each
inside a function body with the player in scope. Two worked examples:

```lua
-- grug_classes/stats.lua:45 today (the body of the function at :44)
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
read at one site" does not belong in this proposal's first round — and exactly
one candidate fails that test, Stand Fast's variant (A), which is why §5.13
puts it to the user instead of smuggling it in as a table row.

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
`talent_gated = true`, exactly like Renew today (`kits.lua:656`). **Three**
existing sites test that flag, and the file itself states they must never
disagree (`grug_abilities/init.lua:1705-1710`):

- `kit_of(class)` drops every `talent_gated` def in both of its loops, the
  universal one (`init.lua:1719`) and the class one (`:1724`). It becomes
  `kit_of(class, player)` and keeps a gated def when
  `grug_classes.talent_rank(player, def.talent) > 0`.
- The purge branch in `sync_kit` (`init.lua:1808-1810`) uses the same
  predicate, or a granted capstone would be destroyed on the next sync.

`kit_of` has exactly one caller (`init.lua:1858`) and the grant loop passes
its index straight to `grant_at`, so a def's position in that list **is** its
hotbar key.

**The base kit's keys are safe; a capstone's key is not, unless the grant
rule changes.** Registering the capstones after the class section keeps every
base ability at the key it has today — the concern the file's own comment
raises at `init.lua:1712-1715`. But Renew is *not* appended: it is already the
fourth entry of `by_class["priest"]` (`kits.lua:651`, after Smite `:572`,
Flash Heal `:596` and Power Word: Shield `:623`). A Priest who unlocks Word of
Ruin first receives it at key 5; unlocking Renew afterwards puts Renew at
index 5 in `kit_of`, and `grant_at` (`init.lua:1731-1770`) moves the occupant
aside — the capstone the player already learned changes key.

The fix is one rule for lane X3, and it is the rule that makes the guarantee
true for every class: **a capstone is granted into the first free slot after
the base kit, in unlock order, not at its `kit_of` index.** Base positions
stay index-addressed as today; only gated defs are appended. The cheaper
alternative is to state the guarantee for the base kit alone and accept that a
second capstone may move the first one's key — worse, because it breaks a
muscle-memory key at exactly the moment the player is learning a new button.

Counts: a Warrior with both capstones fills keys **1-7** of 8 (Strike plus
four class abilities, §2.1); a Mage or Priest fills 1-6.

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
`grug_inventory` keeps its two pages. This costs the `sfinv` dependency edge
named in §3.1. sfinv uses legacy coordinates and the content area spans about
y 0.3-5.0 (`pages.lua:1-2`).

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
`grug_xp/init.lua:34`). The same registration gains the talent line:

```lua
-- old_level is nil on join (grug_xp/init.lua:32-33), which is why
-- stats.lua:91-92 already guards it. Arithmetic on nil here would error
-- on every single join.
if old_level ~= nil and
        math.floor(new_level / 3) > math.floor(old_level / 3) then
```

On that condition, send one chat line under the existing "Reached level N!"
(`grug_xp/init.lua:62-64`):

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
require. Seven groups, each of which can go red on its own:

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
   character, `get_crit_chance` still returns <= 0.30; with the armor talents
   (Iron Discipline and, below 30% HP, Unyielding) at rank 3 on 60% gear,
   `get_armor_percent` still returns <= 60.
7. **The shared central seams stay neutral without talents.** The five talents
   that hook `arm_cooldown` (`init.lua:1233`), the charge arming line (`:718`)
   and `get_range` (`:170-177`) sit on paths every ability of every class runs
   through. One case per seam with **no talent ranked** must reproduce today's
   value exactly — Taunt 8 s, Blink 15 s, Smite 2 s, Hamstring 6 s, Fireball
   20 m, and an elf's Fireball still 25 m — so a talent read can never quietly
   re-tune an untalented character.

**Mutation proof** the review should demand: revert the one line of
`stats.lua:45` that adds `crit_chance_add` and group 5 must go red; raise a
talent to 4 ranks and group 1 must go red; make the `arm_cooldown` read
default to 1 instead of 0 and group 7 must go red.

### 3.8 What changes where

| File | Change | Size |
|---|---|---|
| `grug_classes/talents.lua` | **new** — registry, the 30 talents, spend/respec, persistence, the two accessors | large |
| `grug_classes/talents_ui.lua` | **new** — the sfinv page | medium |
| `grug_classes/init.lua:210-213` | two `dofile` lines | 2 lines |
| `grug_classes/mod.conf` | two dependency edges: `sfinv` (the page) and `grug_money` (the respec) — §3.1 | 1 line |
| `grug_classes/stats.lua:25,45,90` | three talent reads (max mana, crit, the level-up line with the `old_level ~= nil` guard of §3.6) | small |
| `grug_abilities/kits.lua:342,453-460,458,495,496,504,505,591,613,640,671` | one talent read per numeric talent whose number lives **inside a function body**: Heavy Hand, Far Cast's spawn call, Kindling, Deep Chill, Hoarfrost, Sharpened Word, Gentle Hand, Warding Faith, Renew's tick. Plus Warded Wrath's shield gate at `:591` and five new capstone registrations | medium |
| `grug_abilities/init.lua:170-177,718,1233` | the three **central per-player seams** the load-time constants forced us to (§3.2): `get_range` for Far Cast's reach, the charge arming line for Cripple, the one `arm_cooldown` call for Grudge, Quick Step and Swift Word | small |
| `grug_abilities/init.lua:1719,1724,1808,1858,2109,2202,939` | the capstone grant predicate (three `talent_gated` sites, one predicate) and the append-after-base-kit grant rule of §3.4; rage per hit taken; in-combat mana regen; rage per swing | small |
| `grug_inventory/equipment.lua:479` | Iron Discipline and Unyielding, both inside the existing 60% clamp | 1-2 lines |
| `grug_core/combat.lua:241` | heal threat factor (Quiet Steps) | 1 line |
| `grug_core/combat.lua`, central hp-change modifier | **only if open decision §5.13 picks Stand Fast variant (A)**: a new timed mitigation window with two entry points (`combat_stats.md:63-73` splits authoritative swings from the modifier) and an amendment to `combat_stats.md` §2. Variant (B) needs none of this. | **medium, and conditional** |
| `tools/wp13/talent_tree_kat.lua` | **new** — §3.7 | medium |
| `docs/design/classes.md`, `progression.md`, `combat_stats.md`, `README.md` | pointer paragraphs, "base value" wording on the §3-§5 ability tables (§2.8), and the design-tour row (`AGENTS.md:84-86`) | small |

---

## 4. Implementation lanes

Four lanes, in dependency order. Lanes 2 and 3 can run in parallel once lane 1
has landed; lane 4 needs lane 1 only.

| Lane | Scope | Depends on | Size |
|---|---|---|---|
| **X1 — the model** | `talents.lua`: registry, the 30 registrations (data only, no consumer), points, spend/respec rules, persistence with the validating read path, `get_talent_bonus` / `talent_rank`, the `on_talents_changed` callback, and the whole KAT of §3.7 except group 5's consumer half. Ships with **zero gameplay effect** — every talent is inert. | — | M |
| **X2 — the numeric consumers** | The 24 numeric talents at the sites of the §3.8 table, across `kits.lua`, `stats.lua`, `grug_abilities/init.lua`, `grug_inventory/equipment.lua` and `grug_core/combat.lua`. **Nineteen are a one-line read where the table says; five (Grudge, Quick Step, Swift Word, Cripple, Far Cast) hook the three central per-player seams of §3.2 instead, because their kit numbers are load-time constants.** Those five are shared-path edits that every ability's cooldown, charge or reach runs through, so each needs its own no-talent regression case in the KAT — that is what keeps this lane M rather than S. Completes KAT group 5 and adds group 6. Touches shared files, so it is one lane and not split by class. | X1 | M |
| **X3 — the capstones** | Five new ability registrations (Stand Fast, Reaving Strike, Cinderfall, Glacial Ward, Word of Ruin), Renew's rank scaling, the grant predicate at the three `talent_gated` sites, the append-after-base-kit grant rule of §3.4, and an engine probe per capstone. This is the only lane with new combat behaviour. **Size depends on open decision §5.13**: L as scoped, and L+ if Stand Fast variant (A) is chosen, which adds a new mitigation window with two pipeline entry points and a `combat_stats.md` §2 amendment. | X1 | L |
| **X4 — UI, level-up and respec** | The sfinv Talents page, the two `mod.conf` edges of §3.1, the level-up chat line with its `old_level ~= nil` guard, the respec transaction against `grug_money.take`, and the class-trainer seam of open decision §5.8. | X1 | S-M |

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
skill tree (**1 skill point per level**)"; `progression.md` §2's first bullet
(`:28` on this branch, `:20` on `main`) says "**1 talent point every 3
levels** (20 points total at 60)". At 1/level a character has 59
points against 30 ranks and fills everything twice over, which destroys "two
thirds fillable".
*(a)* `progression.md` wins; correct `combat_stats.md:14`.
*(b)* `combat_stats.md` wins; re-cut the trees to roughly 90 ranks.
**Recommendation: (a)** — the whole 20/30 arithmetic and the capstone gate at
8 points are built on it, and `combat_stats.md:14` reads like a pre-2026-08-06
leftover in a "core principles" list rather than a specification.

**5.3 — "9 of 10 talents are numeric" versus "one capstone per tree".**
`progression.md` §2's second bullet (`:31-33` here, `:23-25` on `main`) says
both, and per class they cannot both hold: 2 trees
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

**5.6 — Names: the proposal's own are not all clean either.**
`AGENTS.md:893` says "Never copy WoW assets/names 1:1 — Blizzard IP. Own
assets, own names". Three separate groups are in scope:

1. **"Holy tree"** — the decided docs already carry a WoW priest tree name, in
   **three** places, the third of which is code: `progression.md:34` (`:26` on
   `main`), `classes.md:455` (`:448` on `main`) and the comment
   `mods/PLAYER/grug_abilities/kits.lua:650` ("the Holy tree unlocks it in
   WP11"). A rename has to reach all three.
2. **Names this proposal invents that WoW also uses for talents.** These are
   ordinary English words, so the case is weaker than a phrase like "Power
   Word: Shield" — but they are 1:1 matches, and a rename costs nothing at
   proposal stage. Flagged to the best of the author's knowledge, not verified
   against a WoW source in this repo:

   | Proposed here | Also a WoW talent/spell name |
   |---|---|
   | **Ruin** (Warrior tree) | Classic Warlock Destruction talent |
   | **Rime** (Mage tree) | Frost Death Knight proc/talent |
   | **Reckoning** (Priest tree) | Classic Paladin Protection talent |
   | **Meditation** (Mercy #4) | Classic Priest Discipline talent — and this proposal gives it the same 5/10/15 ranks |
   | **Kindling** (Ember #1) | Fire Mage talent |
   | **Cripple** (Ruin #4) | Warlock spell |

   Bulwark, Ember and Mercy, and the remaining talent names, have no such
   match the author is aware of.
3. **Nine *shipped* ability names** are already in position 2's situation
   (Power Word: Shield, Frost Nova, Flash Heal, Blink, Hamstring, Charge,
   Smite, Taunt, Renew). Pre-existing, outside WP11, flagged only.

*(a)* Rename the six in group 2 along with "Holy tree", before any of this is
built and while the cost is one edit per name.
*(b)* Accept ordinary English words that happen to collide, and rename only
the unambiguous carry-over ("Holy tree").
**Recommendation: (a)** for group 2 and the "Holy tree", because a rename is
free now and expensive once a player has learned the word; group 3 stays a
separate question for a later pass.

**5.7 — Respec price shape.**
`economy.md` §4 and `progression.md` §2 say "for gold, rising with level" and
name no number, and `economy.md` §3 forbids a stale fixed table. **One number
does survive on the page**: `BACKLOG.md:537-538` still reads "the **respec
price** (§8.3, 5c x level, min 25c) has no consumer yet — `grug_money.take` is
the API it will call". `items_crafting.md` §8.3 (`:2341`) has since been
rewritten to "repeatable at the class trainer and rising with level", so the
formula is a leftover of the retired flat pricing — but it is still written
down, and whichever option is chosen should retire it explicitly rather than
leave two prices in the repo. (The `grug_money.take` half is correct and is
what lane X4 calls; it exists at `mods/PLAYER/grug_money/init.lua:122`.)
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

**5.10 — Are talents wiped by a class switch, and is a respec a class change?**
`/class` is admin-only and already wipes kit state through `sync_kit`. §1.4
says a class switch clears all talents and returns all points, and that a
respec is *not* a class change — but **four shipped comments assume the
opposite**, namely that WP11's respec is what finally makes the class-change
unequip path player-reachable: `grug_inventory/equipment.lua:57` ("later WP11
respec"), `:501` ("Admin-only today, player-reachable with WP11's respec"),
`:579` ("a Warrior who respecs to Mage") and `grug_core/combat.lua:110`
("WP11's respec unequipping what the new class may not wear").
*(a)* A respec re-spends talents only; a class switch clears them and returns
all points, free. The four comments are then **wrong on the day WP11 lands**
and must be corrected in the same WP, and `equipment.lua:501`'s promise that
the path becomes player-reachable stays unkept until some later WP offers a
paid class change.
*(b)* The class trainer sells a class change as well, which keeps all four
comments true and gives the unequip path its first real user.
**Recommendation: (a)** — a talent respec and a class change are different
products and `progression.md` §2 only bought the first; but (a) is only
honest if the four comments are corrected with it, so that correction belongs
in WP11's scope either way.

**5.11 — The Warrior runs out of hotbar first.**
`classes.md` §2b's "rotation is the hotbar" assumes keys 1-8. The Warrior kit
is the largest: Strike plus **four** class abilities (`classes.md:415-418`)
already occupy 1-5, so two capstones put him at **7 of 8** — one free key —
while a Mage or Priest ends at 6 with two free. The next claim on those keys
is already written down: `classes.md:462` parks "Warrior shield abilities →
after WP14 (offhand/shields)", and `register_ability` already carries the
`slot = "offhand"` plumbing for them (`grug_abilities/init.lua:501-510`). One
key is not enough for a shield *set*.
*(a)* Accept 7 of 8 now and let WP14 decide then — it may ship a single shield
ability, or the hotbar may grow a second row by the time it lands.
*(b)* Give the Warrior's trees one capstone between them instead of one each,
which is decision 5.5(b) arriving by another route and costs the Warrior the
level-54 beat every other class keeps.
*(c)* Accept 7 of 8 and write into `classes.md` §6 that WP14's Warrior shield
work has exactly one hotbar key, so it is designed against that budget from
the start.
**Recommendation: (c)** — it costs nothing today, keeps both capstones, and
hands WP14 the constraint instead of the surprise.

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
exception would be the first one. Whichever way it goes, the same paragraph
requires the Character page to show **effective and raw** ("`Armor 60% (67%
raw)`"), so a talent's contribution has to reach the raw figure too — one more
consumer for `get_talent_bonus` in lane X4, not a free consequence of (a).

**5.13 — Stand Fast needs a mitigation term the game does not have.**
Every other talent in §2 is written in an existing stat. The Warrior tank
capstone is the one that cannot be: `combat_stats.md` §2 (`:53-76`) knows
exactly **one** physical mitigation term — armor points, 1 point = 1%
reduction, hard cap 60% — plus the target-race Warding Draught and the absorb
shield, resolved in that order (dodge -> armor -> ward -> absorb). A "damage
taken -30% for 8 s" window is a fourth term, and it is why Unyielding was
rewritten as flat armor percent (§2.1) while the capstone was not: a capstone
that merely adds armor gives a plate Warrior already at the 60% cap **nothing
at all**, which is the one class it exists for.

*(A)* **Add the term.** A timed percentage reduction, resolved with armor.
Costs: an amendment to `combat_stats.md` §2's resolution order; a timed
per-player state with an expiry, i.e. the shape of `combat.lua:1010-1030`, not
§3.2's "one key, read at one line"; and **two** entry points, because
`combat_stats.md:63-73` has authoritative swings resolve armor on the full
swing before entering the central modifier. It also multiplies rather than
adds: a 60%-armor Warrior under rank-3 Stand Fast takes `0.40 x 0.65 = 0.26`
of the hit, i.e. **74% total mitigation**, above the documented 60% ceiling by
a second factor rather than by lifting the cap. If that number is wanted, it
should be written into `combat_stats.md` deliberately, not arrive as a side
effect of a talent.

*(B)* **Use the shield that exists.** Stand Fast becomes a self-absorb of
`20 / 30 / 40 + 2 x floor(Str/10)` for 8 s through `grug_core.set_absorb`
(`grug_core/combat.lua:1012`). No new stat, no new pipeline entry, no
`combat_stats.md` amendment, and it scales with the tank's own attribute. The
cost is that it reads as a smaller wall than a percentage, and it collides
with the one-absorb-per-player rule (`combat.lua:1003-1012`) — a Priest's
Power Word: Shield on the tank would replace it, which is exactly backwards
for a tank cooldown.

**Recommendation: (A), decided deliberately** — a tank capstone whose whole
job is surviving a burst has to work at the armor cap, and (B)'s collision
with the healer's own shield is worse than a fourth mitigation term. But (A)
is a change to `combat_stats.md` §2 and to `grug_core`'s damage pipeline, not
a talent: it belongs in the lane plan as its own item (§4 sizes X3 as L+ for
it) and it needs the user's yes, not an implementer's. If the answer is no,
(B) ships and the Priest-overwrites-the-tank case is documented as a known
interaction.
