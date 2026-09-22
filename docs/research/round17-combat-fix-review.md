# Round 17 COMBAT focused correction review

Verdict: **MERGE** for the reviewed COMBAT scope.

Candidate: `6de2a68b71b97230c519685e02d0375381a3bcf7`, correction over
`7bcac7c1fc4dfe07d6c3e0dc01e37a0320b11a3b`. Reviewer: native Astra.
Fix rounds: **1**. Elapsed: unknown. Remaining findings: Critical **0**,
High **0**, Medium **0**, Low **0**. Original findings: two Medium, both closed.

Independence is unchanged from `round17-combat-review.md`: this reviewer
implemented HOME, not COMBAT. HOME implementation/acceptance remains excluded;
its separate independent review is not replaced by this verdict. Root reports
integration at `d4853fa2`; this review inspected the frozen lane correction,
not a second broad audit of the integrated round.

## Finding closure

**M1 closed.** `grug_core/homing.lua` now reads the engine-owned current
attachment and uses the greater of target/parent velocity for its displacement
allowance. The parent must still have a live position. The native
`ObjectRef:get_attach` contract (`reference_projects/luanti/src/script/lua_api/l_object.cpp:953`)
returns the actual attachment reference and works for player and Lua-entity
ObjectRefs; there is no client-supplied parent selection. Existing target/owner
generation validation remains before motion handling. The correction adds no
postlaunch range check, terrain check or retarget.

The production fixture now covers the original zero-speed rider with a
12-node/s parent: nine nodes over 0.75 seconds retain the shot, then three nodes
over 0.25 seconds yield exactly one impact at the original fixed duration.
Explicit short teleport invalidation and large external displacement still
cancel while attached.

**M2 closed.** `grug_mobs/telegraph.lua` returns before its punch loop when the
scaled base damage is zero or negative. Its previous minimum-one rounding for
strictly positive damage is unchanged. The fixture loads the actual telegraph
consumer and actual mob formula, checking no punch at scale 0 and the existing
rounded cone values 30/45 at scales 1.0/1.5 for a level-10 elite. Warning/cooldown
control flow remains intact; only zero-damage settlement is suppressed.

## Verification

Ran the corrected compact LuaJIT fixture once:

```text
r17_combat PASS homing lifecycle walls range batch actors scale scout fireball mounted-motion zero-cone
```

Read the complete correction diff and the relevant native attachment contract.
No new relevant regression was identified. No production code edits, commits,
PUC runtime, broad suite, world generation or native GUI session were performed.
Root retains the single final integrated PUC/LuaJIT parity pair on final bytes.
User runtime acceptance still includes mounted-target pursuit during delayed
updates and zero/normal/default damage-scale behavior, alongside the original
ranged-combat playtest.
