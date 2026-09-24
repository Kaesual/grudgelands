# Round 20 F3: equipment, enchantments and durability presentation

Implementation lane: native Astra, branch `wp20-gear`, 2026-09-24.
Contract: [Round 20 plan, F3](../planning/round20-pois-quests-fixes.md#f3--equipment-permissions-enchant-pools-and-wear-display-astra).
Status: implementation and static checks complete; independent review and
consolidated final runtime validation are pending. This is not a runtime pass.

## Changes

Weapon-family permission authority lives in `grug_gear/permissions.lua`.
Warrior: sword/dagger/Battle Axe; Scout: bow/sword/dagger; Mage and Priest:
staff/wand/dagger. Drag/equip, starter placement, creation-time reconciliation
and combat weapon reads use that authority. Existing armor ranks, levels,
hand count and starter weapon choices remain. `Usable by` text is shared,
class-readable item text, not viewer-dependent coloring.

Weapon enchant pools now distinguish sword, dagger and greataxe. Daggers add
Intelligence; Battle Axes exclude Dexterity and maximum Mana. All six tiers and
both channels have named recipes, owned by Weaponsmith. Other family pools and
Woodcarver ownership remain. The catalog grows from 456 to 588 operations.
Fixed enchantments stay on the item when its wearer changes. Scout melee bonus
now reads Dexterity; other classes retain Strength. Caster damage already uses
level-based baseline damage plus Intelligence spell power (`kits.lua` Fireball
and Smite), so dagger permission requires no caster-family reclassification.

`grug_repair.durability` computes whole normalized remaining units as
`ceil(((65535 - wear) * maximum - remainder) / 65535)`, clamped to its lifetime;
broken equipment reports zero. Tool and hoe authored uses override combat
lifetimes. Combat wear and the display share the same lifetime authority.
Existing exact wear, Creative exemptions and repair costs remain unchanged.
Wear, hoe use, repair, acquisition and normal inventory rebuilds refresh the
changed stack. Same-stack durability notifications skip inventory-wide tooltip
rebuilds; there is no new per-frame scan.

Armor, shields, spellbooks and quivers use native tool registration for wear
bars, with zero damage and empty digging capabilities and no weapon-slot group.
`grug_inventory.get_cosmetic_weapon/offhand` returns copies including broken
items. Combat accessors still reject broken equipment. Ability changes are
limited to those two getter substitutions inside `slot_source`; cooldown/charge
bars and input handling are untouched.

Broken inventory and first-person images use the existing opaque-only
`cracko` modifier. Original per-stack image overrides are remembered only while
broken, with last-render comparisons to preserve newly authored enchant images;
repair restores the current base/enchant appearance. Third-person attachments
use native `wield_item` with a bounded visual-only ItemStack (name and appearance
keys), so wear remainders, descriptions and action identities do not invalidate
the appearance cache. Player armor cracks are applied inside only the affected
armor layer, and the composition cache records each broken slot.

## Engine evidence

Read-only source: primary checkout `reference_projects/luanti`.

- `src/gui/drawItemStack.cpp:192`: native wear bars require `ITEM_TOOL`.
- `src/client/content_cao.cpp:737`: `OBJECTVISUAL_WIELDITEM` deserializes
  `wield_item`, while the older `textures[0]` path constructs a name-only item.
- `src/client/content_cao.cpp:1498`: changing `wield_item` invalidates the visual.
- `doc/lua_api.md:715`: `cracko` overlays fully opaque pixels only.

## Validation and review handoff

Executed: plain Lua 5.1 parser on all 16 changed/new Lua files; bytecode
`SETGLOBAL` inspection; all five conformance sweeps, explicitly including
`tools/` fixtures; `git diff --check`. Only expected mod globals and scoped test
doubles are written. Sweep 4 hits are existing comments and literal pipe
separators in ability cache tokens, not operator syntax.

No Lua runtime, engine, sync, merge or push was run by this lane.
`tools/r13_enchants/final_micro.lua` now covers the 588-operation real catalog
and invokes `tools/r20/gear_micro.lua` for the 144 class/family/tier permission
cases, pool restrictions, normalized durability boundaries, repeat-safe broken
art and repair restoration, armor-layer composition, and Scout Dexterity.
Root should include this single fixture in the final compact PUC/LuaJIT digest
pair; historical broad catalog suites are not required.

Review should especially inspect equipment notification order, same-stack wear
cadence, image restoration after enchanting broken items, and runtime visual
metadata support. Independent review model/verdict, final-byte runtime digest
and any fixes must be recorded by the coordinator before delivery.

Calibration: implementation model Astra; assigned due to shared equipment,
combat, metadata, texture and native rendering boundaries. Actual effort:
one implementation pass with source inspection and static checks. Review
severity/outcome and final validation remain pending; no review is claimed.

## User runtime acceptance

Try each class's allowed and refused weapons plus lower-rank armor. Check
sword/dagger/Battle Axe enchant options at low and high tiers. Compare exact
remaining durability after one use, then break and repair a weapon, tool,
armor piece and offhand. Verify inventory, first-person skill skin,
third-person held item and only the affected armor layer retain their shape
with cracks while broken, lose usable stats, and restore cleanly after repair.

## Review follow-up: real equipment and repair boundaries

`tools/r20/gear_boundary.lua` is called by the existing gear micro fixture in
the consolidated final interpreter pair. It loads the actual inventory
equipment and repair runtime modules, captures the real allow callback, and
checks all 24 class/family equip decisions. It exercises one actual first wear
event, duplicate-event suppression, a seeded penultimate state followed by one
actual final wear event, broken combat versus cosmetic getters, owned cosmetic
copies, and the actual service quote/apply path. An equipment notification
assertion reads the combat getter during notification, proving invalidation
precedes consumers. Repair restores durability/remainder, removes cracks and
consumes the quote. Money's atomic transaction is a bounded fixture double;
this is not a replacement for its separate transaction tests.

No lifetime loops or runtime were added to the implementation lane. Both
fixture files pass the parser and five sweeps; their intentional fixture-global
writes are covered by the parent r13 fixture's save/restore boundary. Final
runtime evidence remains pending with the consolidated root run.
