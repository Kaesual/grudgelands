# Class Kits — Resources & Abilities (MVP)

Decided spec (2026-08-06). Implementation: WP4 (`grug_abilities`, resource
HUD, damage pipeline hooks in `grug_core`), WP19 (kit tuning, GCD, target
lock), WP35 (§2b's universal ability and §2c's ability-item skins); skill
trees extend these kits in WP11. Attribute/derived-stat formulas: `combat_stats.md` §1/§2; threat
values: `combat_stats.md` §4.

Core principles:

- **Instant abilities + cooldowns, no cast times in the MVP.** Cast bars
  (and pushback) may come later for selected spells; the Home Stone's
  10 s cast (world.md §6) is its own mechanic and stays.
- **Abilities are hotbar items** (indestructible, not droppable/tradeable,
  locked to the main inventory; granted at class pick, except §2b's
  universal Strike, which is granted on join). Left click = cast at the
  pointed target; the item's wear bar displays the running cooldown —
  **the Strike is the one exception and shows none** (§2b). What the item
  *looks* like is §2c.
- **Global cooldown 1.0 s** across all abilities of a class (decided
  2026-08-06, WP19) — turns button mashing into a rotation. §2b's Strike
  is off it in both directions.
- **Soft target lock** (WP19): the last punched/pointed enemy or ally
  stays the implicit target for ~8 s; abilities default to it (makes
  healing moving allies possible).
- Three to four abilities per class in the MVP; **new active "main
  skills" come from talent capstones** (WP11, progression.md) — talents
  otherwise improve existing buttons rather than adding many new ones.
- **Balance constraints** (decided 2026-08-06): group content is sized
  for **2–3 players**, and every encounter must be **beatable without a
  healer** (food/potions as the substitute) — the Priest makes groups
  comfortable, never mandatory.

## 1. Resources

| Resource | Classes | Pool | Regeneration |
|----------|---------|------|--------------|
| Mana | Mage, Priest | 10 + 2×Int (combat_stats §2) | 2%/s out of combat, 0.5%/s in combat (combat_stats §5) |
| Rage | Warrior | 0–100, starts at 0 | +12 per landed **Strike** hit (§2b — the auto-attack; the class abilities generate no rage), +4 per hit taken, +15 from Charge; decays 2/s out of combat |

- **Rage is granted on damage that actually landed**, not on a swing
  attempted: a target that cancels the punch (a vendor NPC, an evading
  mob), an `immune_to` mob or a player with PvP off yields **0 rage**.
- **In combat** = dealt or received damage within the last 5 s. The
  definition lives in `grug_core` (`mark_in_combat`/`in_combat`) and is
  shared with recovery (combat_stats §5) and mob leashing (WP6).
- Resources are runtime state, not persisted: mana is full on join and
  respawn, rage is 0.
- HUD: a colored resource line (mana blue, rage red) above the XP line.

## 2. Damage pipeline (grug_core)

- Ability damage/heals go through `grug_core` helpers that roll **crit**
  (attacker's chance, ×1.5) and — for player targets — **dodge**
  (combat_stats §2), then apply via `object:punch` so armor groups,
  knockback and mob death handling (XP, loot) keep working.
- Mob→player punches roll the player's dodge centrally (hp change
  modifier in `grug_core`).
- **Auto-attacks carry the melee bonus and roll crit since 2026-08-07**
  (combat_stats §2), on both paths: the Strike of §2b routes through the
  same `grug_core` helpers as every other ability, and the held-button
  path for tools and fists gets them from the `mobs/api.lua` cadence
  patch. WP5's equip-time stack-meta `tool_capabilities` override
  (enchant design in AGENTS.md) is what will carry a rolled attack-speed
  affix into the Strike's cadence — it is read per swing, so that needs
  no further ability work.
- **Threat hooks are stubs in WP4** (`grug_core.add_threat`,
  `add_heal_threat`): abilities already report their threat values
  (combat_stats §4: tank abilities ×3, healing ×0.5); WP6 replaces the
  stubs with the real threat table. Taunt's forced-target effect works
  already via mobs_redo `do_attack(player, force)`.

## 2b. Universal abilities (no class kit)

Abilities that belong to **no class** — every character has them, including
one that has not picked a class yet. Today there is exactly one, and it is
what used to be the held attack button (`combat_stats.md` §2; decided
2026-08-08, shipped with WP35).

| Ability | Cost | Cooldown | Effect |
|---------|------|----------|--------|
| Strike | free | the **equipped weapon's** `full_punch_interval`, resolved per cast | Melee hit (4 m) with the item in the weapon slot: weapon damage + floor(Str/10), crit ×1.5, threat ×1. Grants the Warrior 12 rage per landed hit (§1). Toggles auto-repeat. |

- **Granted to every class and to a classless character**, and placed
  **first in the hotbar** so it lands on key 1 for everyone — a fresh
  character is never standing in the world with no way to fight back.
- **Free**, because it is what *generates* the Warrior's resource.
- **Off the global cooldown in both directions**: it neither waits for a
  GCD nor starts one. A 1 s GCD would cap a 0.7 s dagger and make attack
  speed a dead stat, and a swing that started one would lock the class kit
  out for as long as the player keeps attacking.
- **No wear-bar cooldown display** — the one exception to the hotbar rule
  in the core principles above. Its cooldown restarts every 0.7–1.4 s for
  as long as a fight lasts and every wear write re-sends the whole
  inventory to the client; same rationale as the deliberately silent GCD.
- **Auto-repeat is a toggle**: the first cast keeps swinging at the target
  held by the soft target lock, at the weapon's speed. It stops on target
  dead or gone, out of range, out of line of sight, a **second cast**,
  death, disconnect, respawn or a class change. The weapon is re-read
  **every swing**, so unequipping mid-fight drops to fist damage instead of
  stopping the attack, and swapping a greataxe for a dagger changes the
  cadence from the next swing on.
- **An empty weapon slot makes it weak, never uncastable**: it swings for
  the bare-hand baseline. The same holds for every weapon-scaled class
  ability.
- It is **melee**, so the elf's +5 m ability-range passive (`world.md` §7)
  does **not** apply to it — that perk is a **ranged/spell** bonus, or an
  elf would carry a 9 m sword. The melee class abilities (Mighty Blow,
  Hamstring) keep their 4 m for the same reason.
- **Hostile players are valid targets**, through the same friendly-fire
  check, dodge pre-roll and threat report as every other ability.

## 2c. What an ability item looks like

Decided 2026-08-08, shipped with WP35. This **answers** §6's old deferral
of "own ability icons": the icon *is* the equipped weapon plus the ability
color, and the tinted orb becomes the no-weapon fallback.

- Every ability item **wears the equipped item's skin**. An ability reads
  either the weapon slot (the default — every shipped ability) or the
  offhand (for WP14's shield abilities). A Warrior with a sword equipped
  holds *his* sword whichever ability is selected, and swapping the weapon
  reskins every ability at once, without reopening the character screen.
- **No exception list.** The abilities that do no weapon damage at all —
  Blink, Renew, Power Word: Shield and every future utility spell — take
  the weapon skin like the rest. An exception list would put the orb back
  on exactly the abilities whose color is hardest to remember.
- **Hotbar icon = the shared orb texture, tinted in the ability's color
  and dimmed, with the weapon art composited on top.** The color the eye
  already learned stays a large area, so the abilities stay tellable apart.
  No new asset is needed for it.
- **The in-hand (wield) image is the weapon art alone, no glow** — a
  glowing disc extruded into a slab in the player's hand is exactly the
  "round thing" this replaces.
- **Empty slot = the plain tinted orb**, i.e. the look the game shipped
  with before the weapon slot existed.
- Still deferred: the alternative composition (weapon art plus a tinted
  border/halo overlay) — it needs art, not a redesign. And the weapon is
  **not** shown on the character model in third person; the engine draws
  the wield item in first person only, and putting it on the model needs
  the multiskin layering `inventory_equipment.md` §1 parks in Phase 3.

## 3. Warrior (Rage)

Tank/melee. All Warrior abilities count as tank abilities: **×3 threat**.

Kit tuning decided 2026-08-06 (implementation: WP19): Mighty Blow became
the rage DUMP (no cooldown — at +12 rage per auto-hit a cooldown left the
Warrior permanently rage-capped), Hamstring added as the control tool (in
an engine where mobs outrun players, the snare is the Warrior's identity).

| Ability | Cost | Cooldown | Effect |
|---------|------|----------|--------|
| Charge | — (generates 15 rage) | 10 s | Dash to an enemy up to 12 m away, 3 damage. Engage tool. |
| Mighty Blow | 25 rage | GCD only | Melee hit (4 m): floor(weapon damage × 1.5) + melee bonus. The rage dump. |
| Hamstring | 10 rage | 6 s | Melee hit (4 m): 2 damage + 50% slow for 5 s. |
| Taunt | free | 8 s | Target mob (8 m) is forced onto the Warrior for 3 s; threat set to top×1.1 (combat_stats §4; threat part + force duration land with WP6). |

## 4. Mage (Mana)

Ranged damage; fragile, keeps enemies away.

Kit tuning decided 2026-08-06 (implementation: WP19): Fireball pays with
mana instead of a cooldown (5 mana against a 240+ pool was free), Frost
Nova became the rotation pivot — kiting IS the Mage fantasy here.

| Ability | Cost | Cooldown | Effect |
|---------|------|----------|--------|
| Fireball | 8 | GCD only | 20 m ranged hit: 6 + spell power damage. Bread-and-butter nuke, limited by the mana pool. |
| Frost Nova | 10 | 12 s | Roots all enemies within 5 m for 4 s, then 50% slow for 3 s (no damage — pure control; rooted mobs keep attacking in melee range). |
| Blink | 8 | 15 s | Teleport up to 10 m in look direction (blocked by walls). Escape valve. |

## 5. Priest (Mana)

Healer/support with a solo damage tool.

Kit tuning decided 2026-08-06 (implementation: WP19): **Power Word:
Shield replaces Renew** in the base kit (an absorb plays differently
from a second heal and makes the Priest useful BEFORE damage lands; our
central hp-change modifier makes absorbs nearly free to build). Renew
moves into the talent tree.

| Ability | Cost | Cooldown | Effect |
|---------|------|----------|--------|
| Smite | 4 | 2 s | 20 m ranged hit: 4 + spell power damage. Solo viability. |
| Flash Heal | 8 | 4 s | Heals 8 + 2×spell power. Targets the pointed ally (15 m), otherwise self. Threat: 0.5× effective healing (WP6). |
| Power Word: Shield | 8 | 10 s | Absorb shield on ally/self: soaks 8 + 2×spell power damage, lasts 15 s or until consumed. |
| Renew *(talent)* | 6 | 8 s | Heal over time: 3 + spell power every 3 s for 12 s. Unlocked via the Holy tree (WP11). |

## 6. Explicitly deferred

- Cast times / cast-bar spells, ability sounds → Phase 3 polish.
  (**Ability icons are no longer deferred**: since 2026-08-08 an ability
  item shows the equipped weapon plus its own color — §2c.)
- Warrior shield abilities → after WP14 (offhand/shields).
- Buffs/auras (e.g. Battle Shout) and party frames → with skill trees
  (WP11) or later. (Power Word: Shield moved into the base kit with the
  WP19 kit tuning, §5.)
- **Poison → arrives with the Rogue in Phase 2** (noted 2026-08-08).
  Poison is intended as the **Rogue's signature damage type** — the
  damage-over-time channel §2's pipeline does not have yet — and the
  Rogue is the Phase 2 class (ROADMAP; `professions.md` §2 already
  builds the leather line for it). **Until then there is no poison
  stat**: it appears in no `combat_stats.md` §2 formula, in no
  `items_crafting.md` §6.2 enchant pool and in no §6.3 roll range, so
  nothing may carry "+poison" — not an affix word, not a trinket, not a
  drop. What exists today is poison as a **mob** effect only (the
  serpent's flat damage-over-time on hit, `biomes_mobs.md` §3.1, and the
  Alchemist's Antivenom that cures it, `items_crafting.md` §3.6); that
  is a mob verb, not a player stat, and the Rogue work is what turns it
  into one.
- PvP tuning of roots/taunt (diminishing returns etc.) → balancing pass.
