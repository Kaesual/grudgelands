# Round 11 vegetation pursuit regression

Date: 2026-09-20. Baseline: `dcd2e462`; branch:
`wp11-vegetation-chase-fix`. State: delivered on main, synchronized and pushed.

The user reports that boars hit from range by either Scout or Priest turn
toward the attacker but do not approach. They subsequently confirmed that
plants trigger the problem. This followup is authorized under the continuing
playtest-fix task; no user world changes or migrations are needed.

## Confirmed cause and bounded correction

Pinned Luanti `src/environment.cpp:63-78` stops `line_of_sight` at every non-air
node, including harmless non-walkable grass/crops. The earlier correction in
`7a4a4c4e` made the cliff predicate reject a non-walkable first blocker. It then
mistook vegetation above solid terrain for a cliff. Both chase and contact
branches stop when `at_cliff` is set but keep turning toward their target,
matching the reported symptom. The previous fixture modeled only support
blockers and did not cover a plant encountered before support.

The fix shares a bounded vertical support predicate between the forward cliff
guard and lateral escape check. Harmless non-walkable plants are skipped;
actual walkable support must still exist within the permitted descent.
Dangerous, unknown or unloaded terrain and unsupported vegetation stay unsafe.
Ambient one-node descent, authored combat fear heights, existing throttling
and pathfinding budgets remain unchanged. Attack target selection and damage
are outside this correction.

## Ownership, gates and delivery

- Native GPT-5.6 Sol `boar_chase_diagnosis`: source, vendor record and focused
  regression coverage. Root GPT-6 Astra: documentation and integration.
- Independent native GPT-5.6 Sol `vegetation_review`: read-only review; no
  source authorship. No Claude or own-provider CLI delegation.
- Minimal LuaJIT regressions for vegetation/support boundaries and the extracted
  actual pursuit branch; source review verifies that the escape probe consumes
  the same tested support helper. Plain-5.1 parser, SETGLOBAL and five sweeps.
  No PUC runtime, broad mapgen suite, seed population or performance run.
- Source freeze and [independent review](round11-vegetation-review.md) are clean.
  Runtime acceptance:
  after restarting Luanti, ranged-hit a boar amid plants as Scout and Priest;
  it must approach across supported terrain. Check that ordinary idle roaming
  still avoids a drop deeper than one block.

## Focused evidence

The support scan visits the same inclusive integer column as the original
vertical engine ray, using half-away-from-zero node rounding. It uses the
existing raw-node-backed lookup and stops at the first real safe support.
Both forward and lateral guards call the helper; no additional player scan,
path search or globalstep is introduced.

`tools/r11_vegetation/evidence/` contains the frozen input hashes and receipts.
The cliff fixture passes flat/one-step/deep-drop and signed-half boundaries,
vegetation over support, unsupported vegetation, liquid over solid support,
unknown nodes and dangerous support. The pursuit fixture executes the extracted
production chase branch: vegetation over ground selects run speed, whereas a
cliff, liquid or ignore column selects zero velocity. Lateral escape wiring is
source-reviewed; no full engine/GUI simulation is claimed.

The final static check parses 328 Lua files (all first-party modules plus changed
vendor/tools); SETGLOBAL has only the declared `mobs` table. All five sweeps
have no prohibited changed code, and all 13 reference pins are unchanged.
No PUC runtime was executed. The GUI retry remains the user's acceptance gate.

Calibration: implementing model native GPT-5.6 Sol, coordinator GPT-6 Astra,
independent reviewer native GPT-5.6 Sol. Final review: 0 Critical, 0 High,
0 Medium, 0 Low. Two pre-final coordinator correction passes refined endpoint/
liquid boundaries and replaced a mirrored pursuit test with the real branch;
review required only narrowing the escape evidence claim. Observed elapsed
wall time unknown.

Delivery: implementation `501dd82c`, main merge `ff7f43db`; synchronized to the
personal Luanti game folder and pushed to `Kaesual/grudgelands`. All 1,900
installed runtime files match main byte-for-byte. No user world changed.
Workers are finished; the next action is the post-restart GUI retry above.
