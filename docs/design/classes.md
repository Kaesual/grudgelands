# Class Kits — Resources & Abilities (MVP)

Decided spec (2026-08-06). Implementation: WP4 (`wob_abilities`, resource
HUD, damage pipeline hooks in `wob_core`); skill trees extend these kits
in WP11. Attribute/derived-stat formulas: `combat_stats.md` §1/§2; threat
values: `combat_stats.md` §4.

Core principles:

- **Instant abilities + cooldowns, no cast times in the MVP.** Cast bars
  (and pushback) may come later for selected spells; the Home Stone's
  10 s cast (world.md §6) is its own mechanic and stays.
- **Abilities are hotbar items** (granted at class pick, indestructible,
  not droppable/tradeable, locked to the main inventory). Left click =
  cast at the pointed target; the item's wear bar displays the running
  cooldown.
- **Global cooldown 1.0 s** across all abilities of a class (decided
  2026-08-06, WP19) — turns button mashing into a rotation.
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
| Rage | Warrior | 0–100, starts at 0 | +12 per melee hit dealt (auto-attacks, not ability hits), +4 per hit taken, +15 from Charge; decays 2/s out of combat |

- **In combat** = dealt or received damage within the last 5 s. The
  definition lives in `wob_core` (`mark_in_combat`/`in_combat`) and is
  shared with recovery (combat_stats §5) and mob leashing (WP6).
- Resources are runtime state, not persisted: mana is full on join and
  respawn, rage is 0.
- HUD: a colored resource line (mana blue, rage red) above the XP line.

## 2. Damage pipeline (wob_core)

- Ability damage/heals go through `wob_core` helpers that roll **crit**
  (attacker's chance, ×1.5) and — for player targets — **dodge**
  (combat_stats §2), then apply via `object:punch` so armor groups,
  knockback and mob death handling (XP, loot) keep working.
- Mob→player punches roll the player's dodge centrally (hp change
  modifier in `wob_core`).
- Auto-attack integration of melee bonus & crit rides on WP5's
  equip-time stack-meta `tool_capabilities` override (enchant design in
  AGENTS.md) — not part of WP4.
- **Threat hooks are stubs in WP4** (`wob_core.add_threat`,
  `add_heal_threat`): abilities already report their threat values
  (combat_stats §4: tank abilities ×3, healing ×0.5); WP6 replaces the
  stubs with the real threat table. Taunt's forced-target effect works
  already via mobs_redo `do_attack(player, force)`.

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

- Cast times / cast-bar spells, ability sounds, own ability icons
  (MVP: tinted orb icons) → Phase 3 polish.
- Warrior shield abilities → after WP14 (offhand/shields).
- Buffs/auras (e.g. Battle Shout, Power Word: Shield absorbs) and party
  frames → with skill trees (WP11) or later.
- PvP tuning of roots/taunt (diminishing returns etc.) → balancing pass.
