# Round 13 playtest followups

2026-09-21. User-authorized fixes after the delivered Round 13 playtest.

## Scope

- Restore initial ability ordering: Strike first, the other base class abilities
  next, starter supplies afterwards. Preserve carried items and the Skills
  catalogue's disposable representations; joins and talent changes do not
  recreate deleted skills or rearrange inventory.
- Use the existing Human-field `grug_farming:soil` for every capital Riding
  Trainer stable floor, preventing grass spread. No new node, global soil rule,
  saved-world conversion or unrelated building changes.

## Execution

Root coordinates two native GPT-5.6 Sol implementation agents with separate file
ownership (abilities and the shared capital service builder), followed by a
fresh independent native review. Both changes are classified non-trivial because
they alter behavior. Branch: `wp47-playtest-hotbar-stables`.

Verification is limited to plain-Lua-5.1 parser/SETGLOBAL/five static sweeps,
focused existing Skills behavior coverage and source inspection of the shared
stable consumer and soil lifecycle. No PUC runtime or mapgen population suite.

Implementation and [independent review](round13-reviews/hotbar-stables.md) are
complete and clean. The existing `tools/r12_skills/behavior.lua` fixture now
starts with supplies already present and checks Strike on key 1, supplies after
the four base abilities and the first-grant marker; its existing deletion and
recovery assertions also pass under LuaJIT. All three changed Lua files pass
plain-5.1 parser, SETGLOBAL and the five static sweeps (including the tool fixture).
The capital change is one shared floor-node substitution; source inspection
confirms all six Riding plots and dry/wet soil never reverting to grassy dirt.

Calibration: implementation GPT-5.6 Sol (two agents), independent review
GPT-5.6 Sol (fresh nonauthor); 0 Critical / 0 High findings, 0 review fix rounds,
elapsed wall time unknown. Root maintained the documentation. GUI acceptance
remains user-owned. No whole-WP completion count changes.

## User runtime check

1. Create a fresh character: Strike is on key 1, the other base skills follow,
   then supplies. Move/delete a skill and reconnect: it stays moved/deleted.
2. In a fresh world's capital stable, confirm the floor stays earth beside
   nearby grass. Existing generated buildings are not retrofitted.
