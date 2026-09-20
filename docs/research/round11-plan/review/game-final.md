# Round 11 GAME independent review

Date: 2026-09-20
Reviewer: native GPT-5.6 Sol (independent read-only review)
Source worktree: `/home/jan/projects/grudgelands/.claude/worktrees/r11-game`
Source branch: `wp23-r11-game`
Base: `45fbc477d3f929945b3100ce523983194a8c5757`
Reviewed head: `43c09f399b2f2126067bed990919936d0c092595`
Range: `45fbc477..43c09f39`

## Verdict

Clean after focused fix round 3. All three verified Medium findings are fixed;
no Critical, High, Medium or Low defect remains in the reviewed GAME package.

## Findings

### Medium — Character-page armor denominator is no longer the approved same-level value — FIXED ROUND 1

`docs/design/combat_stats.md:172-173` says the Character/Talents UI shows
reduction against “the relevant attacker”. The approved Round 11 contract is
specific: the Character page shows raw rating and **same-level reduction**
(`docs/research/round11-plan/README.md:95`). A character page normally has no
attacking entity from which to derive a “relevant attacker”, so a later COMBAT
consumer could reasonably choose current target, last attacker, or player
level and still claim conformance to the Living Spec. Concrete failure
scenario: the UI is implemented against an L70 selected dragon while a level-60
player inspects the page, showing 60.9% for the 210-rating example rather than
the approved same-level capped value; the page changes merely because the
target changes. Replace “relevant attacker” with the player’s own character
level for the Character-page reduction (while retaining raw/multiplied rating
display).

Fix verification at `56148decc7deb54c1690390ad97690d71e59da15`:
`docs/design/combat_stats.md:172-175` now expressly evaluates the preview
against the player's own character level and states that selected target and
last attacker do not change it. This exactly closes the approved same-level
display contract. The fix is Markdown-only; no runtime retest was needed.

### Medium — New mobs_redo in-place patches are absent from the mandatory vendor ledger

`mods/ENTITIES/mobs/api.lua:3596-3599` and the registration whitelist near
`:4055` add two new `GRUG PATCH` sites for `_grug_no_far_despawn`, but the
`mods/ENTITIES/mobs` row in `VENDOR.md:287` does not list that local patch and
still reports 62 markers. The reviewed head actually contains 65 markers in
that file. This violates `VENDOR.md:10-19`, which requires a complete local
patch list so an upstream refresh can reapply every deviation. Concrete failure
scenario: a future mobs_redo update follows the ledger, omits the authored-boss
far-cull exemption, and live dragons again become terminal unload markers while
their encounter ledger remains alive. Add the two-site authored-boss culling
exemption to the mobs_redo row and reconcile its current count to 65.

Fix-round-2 status: **PARTIALLY FIXED.** `VENDOR.md:287` now lists both new
sites and the actual total of 65, matching the source count. However,
`VENDOR.md:185-186` still calls 62 the current inventory and `VENDOR.md:308`
still refers to “the 62-marker inventory above.” These live contradictions
leave the mandatory ledger internally inconsistent. Change both current
references to 65.

Fix-round-3 verification: **FIXED.** Both current cross-references now state
65 and the source still contains exactly 65 markers.

### Medium — Walking endpoints raise real displays by 0.5 node; the fixture uses a non-production floor

`mods/ENTITIES/grug_mobs/capital_displays.lua:51-54` computes an endpoint as
`socket.pos.y + 0.02 - foot_y`, while real installation stores
`_grug_display_floor = slot.pos.y - 0.5` at
`mods/ENTITIES/grug_mobs/start_npcs.lua:1125-1129`. CAP's real socket contract
asserts each endpoint has the same y as its mount-display socket. The display
therefore starts at `socket.y - 0.5 + 0.02 - foot_y` and snaps upward exactly
0.5 node on its first walking step (the movement path assigns target y
directly). Reload at home repeats the mismatch. `tools/r11_game/display_kat.lua:43-50`
masks it by setting `_grug_display_floor = 10` while its endpoint y is also 10,
which production never does. Concrete failure scenario: every T1/T2 capital
display visibly levitates half a node once its initial pause ends, despite the
new full-clip minimum. Subtract 0.5 from endpoint socket y and make the fixture
use production-equivalent floor 9.5 while asserting no vertical jump.

Fix-round-3 verification: **FIXED.** Endpoint y now uses the same
`socket.pos.y - 0.5` top-face convention as installation. The fixture uses
the production-equivalent 9.5 floor, asserts no first-step jump, and exercises
current-version reload preservation of floor and walk target.

## Verified runtime review

- `mods/ENTITIES/mobs/api.lua:3593-3623` preserves `_grug_no_far_despawn`
  entities through real mobs_redo static serialization while retaining the
  existing ordinary terminal-cull path. `mods/ENTITIES/grug_mobs/boss_dragons.lua`
  opts in exactly the two authored dragons; death and respawn remain owned by
  their encounter ledger.
- `mods/PLAYER/grug_mounts/entity.lua:194-265,315-319,390-395` keeps the
  controller rotationally neutral, derives translation from live look yaw and
  applies engine-convention attachment rotation even while stationary. The
  visible mesh remains the player's non-forced child, preserving the existing
  first-person hiding contract. Rendered yaw/camera behavior remains an honest
  GUI gate.
- `mods/ENTITIES/grug_mobs/capital_displays.lua:21-137` gives T1/T2 displays a
  throttled 0.1-second, 0.6-node/s endpoint walk with pauses and persisted
  target/pause state. T3/T4 displays remain stationary and loop their stand
  animation. Missing endpoint pairs fail closed to stationary animation.
- The approved maximum-armor clarification is present: the formula does not
  clamp raw rating; Unbroken requires the exclusive 21-point capstone and
  multiplies the same maximum 210 rating to 294; the Living Spec records the
  same-gear L70 checks of approximately 60.9% DPS, 68.5% Bulwark and 69.6%
  during the +15 emergency window (`docs/design/skill_trees.md:1048-1055`).

## Integration dependencies and evidence boundary

- The reviewed GAME head deliberately still defines dragons at L60 in
  `mods/ENTITIES/grug_mobs/boss_dragons.lua`; the approved dependency table
  assigns the actual L70 runtime change and its HP/damage/XP/loot audit to
  COMBAT. Do not treat this branch alone as satisfying the newly folded L70
  design text.
- GAME consumes CAP endpoint ids `<mount socket id>_walk_a` and `_walk_b` but
  does not contain their geometry. Full endpoint population, clearance and
  reload behavior therefore remain an integration/engine gate after CAP lands.
- I inspected the focused fixtures and the recorded targeted LuaJIT evidence;
  I did not rerun tests or historical suites. The evidence records parser,
  SETGLOBAL and five-sweep completion and explicitly records that no PUC
  runtime ran, matching the latest user amendment. The recorded LuaJIT stdout
  digest is `66fd035af1c9708ba77ad4a499fbca57ba9941fdbe2710e566738a94154e3f00`.

## Reviewed source hashes

```text
3a03b2c485e93211a318451772a71ed275a841ddd2256427e80c15d48068159b  mods/ENTITIES/grug_mobs/boss_dragons.lua
7ae064146717dd98c59b27ddfa6352a20425eb44c878e3eef16c9594d81549c6  mods/ENTITIES/grug_mobs/capital_displays.lua
f22619b2ef3f4c3881cc19680eb42cc3001fdc190b33c501c20538bdb1326c40  mods/ENTITIES/mobs/api.lua
ba8d0d5a617a5d761f597efe203ba3d75720882d37ef7265a2d45ca88693ae66  mods/PLAYER/grug_mounts/entity.lua
0ab4fc2cba3350ea7a56330eff4c0307bc01c91c6a8f2f8e4d26a85ec66260fa  docs/research/round11-game-evidence.md
9604b0564f8ae2affc5813ae4346a13adc84a8469ee30014c0454b73a455092d  docs/design/combat_stats.md
```

Fix-round-2 reviewed hashes:

```text
91ba066b5e9fc7c2545fe7cb253160ba2b48e13a923ef75fc9f585bf8a6dfecc  VENDOR.md
5b5c6256cacb3c0fee8416571fd7451d239b20352aaf1f46613aa2faa8c93fdc  docs/research/round11-game-evidence.md
fa50d6e4a06d6d4a6edb924267c319679e21f397fdc4e04271ef4654ae4c0980  mods/ENTITIES/grug_mobs/capital_displays.lua
6fda83bc2ad2b83256deb871f728e09cf02f7fec94d44babba80028853efc27e  tools/r11_game/display_kat.lua
```

Fix-round-3 reviewed hashes:

```text
3f6a6f0e84f616f410799fd606837ea5cbf954f2ee313f731935203d0fe6f40d  VENDOR.md
75bdd30ddf7728aa769505d50485a59f573e7c18506c5fe85c0087f4b749d0a0  docs/research/round11-game-evidence.md
8d0ee5a252b310916d0df22e8f024d5cfe4eb2e33f9e789a718334908eefdd94  mods/ENTITIES/grug_mobs/capital_displays.lua
f1985bfaa9506328909130277eefac4950d2565916da5207d639399a3a17d709  tools/r11_game/display_kat.lua
```

## Calibration

- Model: native GPT-5.6 Sol
- Independence: reviewer did not author the reviewed change
- Files in reviewed diff: 16
- Production Lua files examined: 4
- Targeted fixture/runner Lua and shell files examined: 6
- Design/evidence Markdown files examined: 5
- Findings through fix round 3: Critical 0, High 0, Medium 3, Low 0
- Fixed in round 1: Medium 1
- Fixed in round 3: Medium 2 (vendor ledger, endpoint vertical coordinate/KAT)
- Newly verified in round 2: Medium 1 (endpoint vertical coordinate/KAT)
- Remaining findings: Critical 0, High 0, Medium 0, Low 0
- False-positive count: unknown until coordinator adjudication
- Elapsed time: unknown
