# Round 11 COMBAT evidence

Date: 2026-09-20. Implementation model: native GPT-5.6 Sol. This is a
non-trivial implementation and requires an independent fresh-agent review
before integration.

## Frozen implementation

- Dependency head: `afa8d883` (reviewed GAME plus merged GEAR).
- Frozen implementation commit: `4dbb65be1cd1e6a8191ef15820683e71e6ad365c`.
- Frozen source tree: `fe847de359dd615687ce6c2cb67a55082ff810fa`.
- `tools/r11_combat/armor_kat.lua`:
  `a50d01fb1ea3113e91dfefd6d15c87a356ebb9b7c8a3a2c0f4e40db37d9f13fc`.
- `mods/CORE/grug_core/combat.lua`:
  `eedd0f8b1f6ce6cd42187c553f2361fd87d3b0d7e17c51249ab973dc7ab814dd`.
- `mods/ITEMS/grug_quality/init.lua`:
  `8bdca1e5ca2037d9d3040d6c93192799bf38e5a8fce4864de75aba612d245e36`.
- `mods/ENTITIES/grug_mobs/boss_dragons.lua`:
  `0923a4ffcc33321637425f470c4733acd18c25a2b30ce03c620308033ad27a1d`.
- `mods/ENTITIES/grug_projectiles/init.lua`:
  `287845738d182ae160f97dbcfceeff1a82d7a901efb8cec49d775c017f866194`.

## Implemented contract

Armor uses raw, uncapped rating and the authoritative attacker level. Direct
Grudgelands mobs and NPCs use their live level, PvP uses the attacking
character's level, and both mob and player projectiles carry an immutable
launch-level snapshot. Unknown attackers and environmental damage bypass
armor. Armor resolves once before absorb; fall damage retains its separate
Dwarf and absorb order. Zero rating leaves fractional PvP damage untouched for
the existing accumulator.

The rating aggregate is four armor bases plus shield base, refinement deltas,
ordinary armor-rating affixes, cultural/talent/status sources. Unbroken's
exclusive 21-point capstone multiplies that aggregate by 1.40. Its persisted
180-second trigger adds 15 rating after the multiplier for eight seconds. The
Character and Talents pages display base rating, multiplier, emergency add,
result and same-own-level reduction.

COMBAT also publishes two REPAIR seams. The action owner calls
`run_settled_outgoing_action(player, action_id, kind)` exactly once; the id is
unique for the live player session and one action never emits per AoE victim or
native packet. `register_on_settled_incoming_hit` observes only a nonlethal
punch with actual HP loss after dodge, armor and absorb.

## Balance audit

| Case | Rating | Attacker | Reduction |
| --- | ---: | ---: | ---: |
| Maximum Ruin/DPS sources | 210 | L70 | 60.87% |
| Same sources, Unbroken passive | 294 | L70 | 68.53% |
| Same sources, emergency window | 309 | L70 | 69.59% |

Rating is not clamped before the formula; only reduction caps at 70%. The
maximum-source input remains 82 refined plate + 82 refined shield + 30 from
five maximum armor affixes + 7 cultural finish + 4 Stoneskin + 5 Ironbound =
210. Shield refinement is included in the shared refinement aggregate.

Dragons changed from actual L60 to actual L70. Authored boss HP remains 18,000;
formula damage changes from 38 to 47.5 before the existing player-pressure
fit. An L60 player's higher-target multiplier changes from 1.0 to 0.5. Raw XP
changes from 600 to 700, while the retained player-level-plus-five cap awards
650 to an L60 killer. Dragon loot remains explicitly authored at item level 75.
Kings remain actual L65.

## Verification

No PUC runtime was run, per the Round 11 user ruling. The plain-5.1 parser was
run over every changed Lua file. `SETGLOBAL` inspection found only the existing
single mod-table declarations in changed `init.lua` files. All five static
sweeps were run across `mods/*/grug_*` and the changed tools Lua; reported
matches were inspected as existing comments, string separators, command
parameters or frozen manifest data, with no prohibited changed-code use.

Focused LuaJIT checks passed:

- `tools/r11_combat/armor_kat.lua`: K(1/60/65/70), final-only cap, maximum
  builds, PvP level, projectile snapshot, unattributed/environment bypass,
  zero-rating fractional preservation and actual dragon level.
- `tools/wp39/projectile_test.lua`: real projectile lifecycle and settlement.
- `tools/r5_progression/progression_kat.lua`: real central damage, pressure,
  ability and support consumers.
- `tools/wp11/talent_tree_kat.lua`: real 21-point capstone, window lifecycle,
  rating consumer and talent gates.
- `tools/wp11/talent_ui_kat.lua`: real Talents page rendering.
- `tools/r11_gear/quality_kat.lua`: real cached affix/equipment consumers.

`git diff --check` passed. No sync, push, broad population run, PUC runtime or
user-world mutation was performed.
