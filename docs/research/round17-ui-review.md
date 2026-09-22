# Round 17 C/D/E independent review

Verdict: **FIX FIRST**.

Reviewed the frozen integrated candidates `148d2a4d` (C DISPOSITION),
`0f1d3293` (D DISPLAY) and `5a085d06` (E PARTY), including their real
registration, combat, observer, quest-marker, class and formspec consumers.
Reviewer: native Sol. Review elapsed wall time: unknown. Initial findings:
Critical **0**, High **0**, Medium **0**, Low **1**. Fix rounds: **0**.

Independence: this reviewer authored none of C, D or E and did not author a
contested ruling in their contracts. HOME and COMBAT are excluded from this
verdict and have separate reviewers. No production file, implementation commit,
PUC runtime, broad suite, subagent or provider CLI was used by this review.

## Finding

### L1 — The PARTY report claims receive-field/layout coverage that its KAT never executes

`tools/r17_party/kat.lua:1-132` loads production `init.lua`, `hud_layout.lua`
and `hud.lua`, but never loads `mods/PLAYER/grug_parties/ui.lua`. Consequently
the claim at `docs/research/round17-party.md:29-31` that the fixture loads the
production layout path and checks receive-field validation is false.

Concrete failure: a future change can swap the dropdown indices, accept an
invalid submitted value, or overlap/change the Group formspec geometry while
`tools/r17_party/kat.lua` still passes all eleven checks. The current production
code is correct on inspection: `ui.lua:66-67` requests numeric index events,
Luanti returns one-based index strings for that mode
(`reference_projects/luanti/doc/lua_api.md:3571-3585` and
`reference_projects/luanti/src/gui/guiFormSpecMenu.cpp:4253-4262`), and
`ui.lua:168-175` maps only `"1"` and `"2"` before the API validates the mode.
The dropdown ends at x=10.20 and does not overlap the existing top-row controls
or the lists beginning at y=0.78.

Correction: extend the compact KAT to load the production `ui.lua`, capture the
registered page, submit `"2"`, `"1"` and an invalid value through its actual
receive-fields callback, and assert the emitted formspec contains the selected
index and fixed geometry. Alternatively narrow the implementation report to
the evidence actually present, but the Round 17 E acceptance explicitly names
UI receive-field validation, so the production-path regression is preferred.

## Verified implementation behavior

- C applies disposition before spawn-role and no-acquire derivation. Neutral
  definitions are non-passive with all unsolicited acquisition fields off, so
  mobs_redo's punch path still calls `do_attack` while ordinary acquisition and
  group pulls remain suppressed. Aggressive rats remain proactive; critters
  remain passive and noncombatant. Boar, Plague Boar and Jungle Boar are the
  intended behavior change.
- `mobs:register_mob` copies only its explicit whitelist. C correctly writes
  `_grug_disposition` to the canonical registered prototype after registration,
  so live instances inherit the field. Missing wrapped families fail during
  registration; dynamic kings resolve aggressive and guards bypass ambient
  disposition deliberately. Villagers/elders and vendor-style peaceful NPCs
  use their separate direct registration paths. Root's integrated real-roster
  probe/final parity remains a pending gate rather than evidence supplied by
  these three commits.
- D classifies players first, then the four guard name families, then the three
  canonical creature dispositions, with peaceful tagged entities falling back
  to NPC. Kings, bosses and adds retain their registered combat disposition.
  Mount code creates no tag carrier.
- All twelve colors are startup-read and invalid colors fall back through
  `colorspec_to_colorstring`; eight-digit backgrounds retain alpha. Pinned
  client code creates sprites as billboards and parents the child scene node to
  the scaled parent node, supporting the inverse visual-size and attachment
  offset compensation used by the implementation.
- Injured bars are eligible only for aggressive, neutral and guard carriers.
  They read the mobs_redo live `health`/`hp_max`, disappear at full HP, zero HP,
  removal and detach, share the carrier's existing observer set, and update
  texture only when the rounded integer percent changes. The helper is
  nonphysical, nonpointable and nonpersistent. The existing visibility callback
  continues to drive quest markers independently; the HP helper is not a
  managed carrier and cannot be mistaken for a quest parent.
- E stores a personal validated mode in player metadata. Online rows call the
  canonical `grug_classes.get_class(member)`; offline rows contain no class or
  fabricated health. The four requested colors and all-green default are exact.
  Existing HUD change caching suppresses unchanged scale/texture writes, and
  the canonical class-chosen callback refreshes affected online party viewers.

## Executed evidence

The bounded LuaJIT lane fixtures passed on the reviewed integrated tree:

```text
round17-disposition  8
r17-display: PASS categories, settings fallback, shared observers, integer HP updates, stable scale, eligibility and cleanup
r17-display: PASS disabled HP sprite setting
round17-party  11
```

`git diff 148d2a4d^..5a085d06 --check` was clean. These fixtures are useful
module checks, but the PARTY fixture has the L1 coverage gap and the disposition
fixture is not a real full-roster startup load. Root still owns the final
integrated PUC 5.1/LuaJIT micro-KAT parity pair and native GUI acceptance.

Calibration: implementing model native Sol for C/D/E; reviewing model native
Sol in an independent context; package classification non-trivial; initial
Critical/High count **0/0** (Medium/Low **0/1**); fix rounds **0**; observed
implementation elapsed wall time unknown; observed review elapsed wall time
unknown.
