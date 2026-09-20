# Round 11 COMBAT independent review

Reviewer: native GPT-5.6 Sol (fresh read-only review)

Candidate: `wp4-r11-combat` at `3a9f0ce00120f73b3bfb232cb1c59f5f41927215`

Verified base: `afa8d8835260c6969a02cdd65c6ec143fb8a2d72`

Author: native GPT-5.6 Sol (independent context)

## Verdict

Clean. No substantive findings.

## Review coverage

- Checked the full `afa8d883..3a9f0ce0` production and test diff against `docs/process/wp-workflow.md`, `docs/process/agent-model-policy.md`, `docs/research/luanti-lua.md`, the current living design in `docs/design/combat_stats.md` and `docs/design/skill_trees.md`, and the approved Round 11 combat annex.
- Verified the rating equation and final-only 70% cap, including `K(1/60/65/70)`, the 210/294/309 rating cases, and the documented 60.87%/68.53%/69.59% L70 reductions.
- Traced rating aggregation through armor bases, shield base, refinement, affixes, talent/status sources, the permanent learned-Unbroken multiplier, and the separate active-window addition. The known broken-item aggregate work remains explicitly assigned to REPAIR and is not treated as a COMBAT defect.
- Traced attacker provenance through direct mob/NPC punches, mobs_redo arrows, dragon breath, player projectiles, ability punches, ordinary PvP, and authoritative PvP. Environmental/unattributed damage bypasses armor; fall retains its separate pool scaling, Dwarf reduction, and absorb order; armor is applied once before absorb.
- Checked the dragon's actual L70 definition against the existing level engine: boss HP remains the authored flat 18,000, damage and XP derive from actual level, the player-relative XP cap remains, and authored loot item levels are unchanged.
- Read Luanti's callback dispatcher at `reference_projects/luanti/builtin/game/register.lua:546-563`; non-modifier HP callbacks receive the final modifier result before storage. The Unbroken threshold and incoming REPAIR seam therefore observe post-dodge, post-pressure, post-armor, post-absorb actual HP loss and exclude lethal hits as specified. REPAIR's outgoing callbacks are publication seams only in this package, as planned.
- Confirmed the evidence hashes match the frozen implementation tree `fe847de359dd615687ce6c2cb67a55082ff810fa` at `4dbb65be`, while the reviewed head adds only the evidence document.

## Verification performed

- `git diff --check afa8d883..HEAD`: pass.
- Plain Lua 5.1 parser over every changed Lua file: pass. This was syntax/static verification only, not PUC runtime.
- `SETGLOBAL` inspection over changed mod Lua: only the expected existing mod-table declarations in `grug_projectiles`, `grug_gear`, `grug_items`, and `grug_abilities`.
- Focused LuaJIT checks: `tools/r11_combat/armor_kat.lua`, `tools/wp39/projectile_test.lua`, `tools/wp11/talent_tree_kat.lua`, `tools/wp11/talent_ui_kat.lua`, and `tools/r11_gear/quality_kat.lua`: pass.
- No PUC runtime, broad suite, sync, production edit, or commit was performed.

## Residual runtime checks

The remaining evidence is the normal user GUI/runtime gate: compare identical high-rating Ruin and 21-point Bulwark characters against a dragon, cross the Unbroken threshold with a surviving punch, verify the eight-second display/window and persistent 180-second cooldown, and spot-check PvP, projectile, fall, absorb, and Character/Talents display behavior.
