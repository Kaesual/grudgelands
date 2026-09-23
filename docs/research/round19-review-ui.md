# Round 19 independent review — lanes B/C

Reviewer: native GPT-5.6 Sol  
Author model: native GPT-5.6 Sol  
Snapshot: `17786aefc409bc6b89fd8b19db89f02fd8f02fb8`  
Baseline: `3b23a8f8`  
Scope: Character/Talents/Skills; party colour default; status anchor; Scout Sprint display; relevant living-document changes and bounded fixtures. Dragon-bar lane D was excluded.

## Verdict

**PASS.** No open Critical, High, Medium or Low findings remain in lanes B/C.

The final production code matches the Round 19 contract: Character exposes concise effective totals; Talents purchases one rank on the first valid click while rejecting locked and hidden-tree submissions through the real authority path; respec confirmation remains intact; assembled textarea text is escaped; the Skills hint and catalog geometry are valid; missing party colour preferences resolve to `by_class` while stored `all_green` remains authoritative; the status list is top-centred; and Sprint's display reads the existing movement modifier without adding or clearing movement authority.

## Initial findings and closure

Initial count: **Critical 0 / High 0 / Medium 1 / Low 1**. Both findings were corrected before the final snapshot.

1. **Medium — resolved:** `mods/PLAYER/grug_skills/page.lua` originally placed the passive-talents heading at legacy Y 3.35 while the purchased-mount cell beginning at Y 2.65 extended to about Y 3.517. The heading therefore overlapped the mount slot. Commit `7d9fca99` moved the heading to 3.75 and textarea to 4.15. The final fixture derives the legacy cell extent and asserts separation (`tools/r19_ui/fixture.lua:308-332`). Engine basis: `reference_projects/luanti/src/gui/guiFormSpecMenu.cpp:3332-3340` defines legacy vertical spacing as 15/13 of image size.
2. **Low — resolved:** `mods/PLAYER/grug_inventory/pages.lua` still said “The Character pool lines read …” after those derivation lines had been removed. Commit `0d7e53a7` changed the sentence to describe the maximum-pool formula directly (`mods/PLAYER/grug_inventory/pages.lua:209`).

## Verification

- Reviewed the B/C production diff and relevant living documents against `docs/research/round19-plan.md`, `docs/process/wp-workflow.md`, and `docs/research/luanti-lua.md`.
- Inspected the generated formspec paths and escape-aware fixture parser. The real Talent callback covers first-click one-rank settlement, a second deliberate rank, locked denial and a forged hidden-tree field. Help, Talents and Skills textareas serialize to five fields.
- Confirmed the corrected Skills geometry against the engine's legacy-coordinate calculation.
- Inspected Sprint lifecycle against `grug_core/status.lua` and `grug_core/movement.lua`: the movement modifier remains the sole speed source; the status value callback suppresses display after explicit movement removal; the common clocks expire together; status lifecycle clears on death and leave/reconnect.
- Confirmed the final C fixture loads the real `hud_layout.lua` rather than a copied expected anchor and covers expiry, explicit movement removal, death and leave/reconnect.
- Bounded LuaJIT runs on the final snapshot passed:

```text
character=concise-totals
skills=textarea-fields-5
talents=first-click+authority
r19-hud PASS checks=16 party=by-class status=top-centre sprint=authoritative dragon=5x3x0.25 ordinary=0.8x0.1
```

No PUC runtime was run; the coordinator owns the single frozen-byte PUC/LuaJIT final micro-KAT pair. Client font wrapping and physical rendering remain part of the user GUI pass.
