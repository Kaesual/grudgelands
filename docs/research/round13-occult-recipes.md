# Round 13 occult weapon recipe followup

2026-09-21, user approved all six tiers of wands, staves and bows. The closed
proposal was folded into [the current design](../design/crafting_equipment_revision.md#plain-caster-weapons-and-bows)
and its TODO removed. Whole-WP completion counts are unchanged.

## Delivered scope

- Eighteen weapon outputs, twenty-four routes: wand and staff once per tier,
  bow in both mirrored orientations. All use ordinary sticks and the matching
  metal bar; caster weapons use the six approved mob components.
- The six obsolete metal-rod wand alternatives are removed. The exact native
  catalog now has 650 routes instead of the historical Round 13 total of 656.
- Bronze stays a starter recipe; T2–T6 book discovery follows the matching bar.
  All tiers remain craftable without a profession or character-level gate.
- Boar Tusk and Rotting Flesh are classified as crafting materials, preserving
  their existing drop chances and vendor values. No weapon stats, other recipes,
  graded-wood production or enchant material costs change.

## Verification and review

Implementation: native GPT-5.6 Sol recipe/catalog agent; root owns item groups,
documentation and native fixture. Independent native GPT-5.6 Sol review covers
both authors' changes. The [independent review](round13-reviews/occult-recipes.md)
is clean: no production findings, one Medium fixture finding corrected and
rechecked. Calibration: 0 Critical / 0 High, one review correction round,
elapsed wall time unknown. No PUC runtime, mapgen population or user-world
mutation was performed. GUI acceptance remains user-owned.

The existing isolated native integration probe includes
`tools/r13_integration/probe/weapon_recipes.lua`: actual engine matching and
ingredient consumption for all twenty-four routes, obsolete/incomplete pattern
refusal, exact per-output route counts, profession-free level-one craft previews,
and bar-based inventory discovery. The production startup catalog audit remains
enabled, and the existing combined enchant/station checks continue to run.

Final native evidence: **2,341 assertions passed**, including all 24 new recipe
variants, the **650-route** production catalog, all **456** named enchant book
operations and five actual Apply transactions. The engine used LuaJIT
2.1.1784272936. All five changed Lua files match the staged, tested bytes.
Plain-5.1 parser/SETGLOBAL and the five sweeps pass; remaining sweep matches
are existing prose/quoted data, not forbidden syntax or calls. Evidence:
[`occult-native.log`](../../tools/r13_integration/evidence/occult-native.log),
[`occult-static.log`](../../tools/r13_integration/evidence/occult-static.log),
[`occult-inputs.sha256`](../../tools/r13_integration/evidence/occult-inputs.sha256).

Two probe-only mistakes were corrected before the successful final run: a
deferred callback cannot use `get_current_modname`, and the profession-only
`can_craft_recipe` API is not the Basics permission path. The fixture now uses
the engine's actual `core.craft_predict` callback chain (reference
`reference_projects/luanti/builtin/game/register.lua:376`). Neither correction
changed production game code or broadened its authorization rules.

## Runtime acceptance

Restart the game, open Basics and craft a Bronze wand, staff and both bow
orientations. Check the shown ingredients and consumed amounts. Collect an Iron
Bar with a character that has not discovered it: the three Iron weapons should
appear. A later-tier weapon can be crafted without learning Woodcarver.
