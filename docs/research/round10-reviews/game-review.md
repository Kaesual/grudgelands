# Independent GAME review

- Reviewed candidate: `99a274a32a9173cd11e84da53f8c18ac25d5794c`
- Production/test freeze: `06a152aa556a634a0ee3a98cc6b459530d5ba4fa`
- Base: `38ae136d`
- Reviewer: GPT-5.6 Sol, native agent
- Independence: the reviewer did not author the GAME candidate; its earlier
  Round-10 work was the separate EQUIP package.
- Mode: read-only; no candidate edits, no personal-world access, no PUC rerun.
- Result: **0 Critical / 0 High / 1 Medium / 0 Low**

## Findings

### Medium — the ambient cliff probe accepts non-walkable blockers as safe ground

[`mods/ENTITIES/mobs/api.lua:1011-1024`] runs the vertical probe and then ends
with `return (not def and def.walkable)`. For every registered node definition
this expression is false regardless of `def.walkable`; if the definition is
missing it attempts to index `nil`. Luanti's actual line-of-sight implementation
stops on **any non-air content**, rather than on walkable support
([`reference_projects/luanti/src/environment.cpp:63-77`]).

Concrete trigger: an ambient `stand`/`walk` mob with no authored height fear
approaches a deep drop whose two-node probe intersects a registered
non-walkable node, such as water or a buildable decoration without supporting
ground in the sampled column. `is_node_dangerous` may legitimately return
false, the final expression also returns false, and mobs_redo does not set
`self.at_cliff`; the mob can enter the unsupported/deep column despite the
one-node-drop rule. The final decision should treat a missing or non-walkable
blocker as a cliff (`not def or not def.walkable`) after the existing dangerous
node check. This line predates the candidate, but the candidate newly routes
all ambient `fear_height = 0` mobs through it, making the defect part of the
changed behavior and acceptance scope.

## Missing requirement evidence

These are evidence gaps, separate from the verified defect above:

1. The final fall fixture checks one native severity (`-5`) at one 100-HP pool,
   with and without Dwarf reduction
   ([`tools/r6_food_buffs/kat.lua:158-164`]). It does not exercise native zero,
   fractional ceiling boundaries, a low and high maximum-HP pair, a severity
   above the nominal 20-point native pool, or prove armor/dodge remain untouched.
2. The mount fixture directly proves manual cleanup and damage-driven cleanup,
   but does not invoke the registered death, leave, shutdown or external-detach
   paths. Thus it does not independently prove that each removes the child
   visual and untimed status exactly once. The implementation funnels these
   paths through `grug_mounts.dismount`, but the requested lifecycle matrix is
   absent from executable evidence.
3. No focused fixture drives the changed `mob_class:is_at_cliff` against actual
   node categories or endpoint rounding. The KAT suite therefore could not
   detect the finding above. A lightweight source-faithful oracle should cover
   one-node support, a two-node/deeper air drop, non-walkable content, dangerous
   content, `fear_height = 0`, flight and combat/scripted exceptions.

The first-person mount visibility and exact camera composition properly remain
a declared GUI acceptance item; offline Lua evidence cannot replace that test.

## Verified checks

- Read the complete diff and the affected design text, completion record,
  workflow checklist and Lua 5.1 rules.
- Mount controller/visual separation keeps the physical parent at neutral
  scale, attaches the non-physical visual directly to the player with
  `forced_visible = false`, and compensates rider scale in visual scale and
  seat offset. Luanti hides non-forced children of the local player in first
  person at `content_cao.cpp:412-419, 469-480`; attachment offsets use the
  documented tenfold unit at `lua_api.md:8866-8875`.
- Controller punches forward to the current rider and re-fetch the attacker's
  wielded stack before committing wear. Damage, manual dismount and the shared
  cleanup path remove the visual and status. The land controller alone receives
  `stepheight = 1.01`; Luanti consumes the property in server entity collision
  at `src/server/luaentity_sao.cpp:179` and the step comparison is
  `src/collision.cpp:523-540`.
- Mounted hostile PvP returns before authoritative claims, ordinary clocks,
  target refresh, damage accumulation and rage settlement. Swing and cast
  entry points also use the live controller/rider marker rather than trusting
  an arbitrary attachment.
- Fall processing preserves native zero through the existing non-negative
  early return, scales negative native fall results with
  `ceil(max_hp * r / 20)`, applies Dwarf afterward and absorb last; armor and
  dodge remain confined to punch reasons. There is no 100% cap.
- Dragon targetless ground behavior returns `false` from `do_custom`, so the
  real mobs_redo `on_step` exits before ordinary state AI can overwrite the
  rest walk (`mods/ENTITIES/mobs/api.lua:3898-3919`). The added one-second
  acquisition runs before every targetless rest/walk early return. Target
  validity excludes peaceful players; wind-ups cancel on target loss;
  targetless flight lands; rest obstruction/cliff stops without teleport;
  scorch refreshes combat. Existing leash processing still runs in the wrapper
  before the dragon callback.
- The weak vendor potion calls the existing Apothecary Loop bridge once,
  rounds once afterward, then retains central heal and cooldown settlement.
- Verified immutable final evidence without rerunning PUC:
  `puc51-replacement.txt` and `luajit-replacement.txt` are byte-identical,
  1,042 bytes each, SHA-256
  `c236c219e12a92a04c5f9b1f94cd4569172fb9b66ea405b4aff0ecd19a1fdbf3`.
  Runner SHA-256 is
  `b704e1783948e6749e06db8959bc178791990ce002ecf3077455260001e2b1c3`;
  interpreter/parser hashes match the review brief. The candidate worktree was
  clean and at the reviewed commit; `git diff --check` passed.

## Required disposition

Fix the cliff blocker predicate and add focused cliff coverage. The changed
production/test bytes then require a replacement compact LuaJIT/PUC pair under
the workflow rule. The missing fall and mount lifecycle cases should be added
to that same bounded fixture before the candidate is approved.
