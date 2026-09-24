# Round 21 startup correction

2026-09-24. User-reported follow-up to [Round 21](round21-completion.md).
Baseline `7908d494`. Native Astra root implementation and independent Astra
`r21_nature_preflight` review. Local integration pending.

Two startup blockers were confirmed and fixed:

1. Reed Angelfish was missing from the mandatory fixed-disposition table. The
   earlier fish fixture stubbed registration without calling that table. The
   fish is now explicitly a critter, and the regression invokes the real check.
2. The actual engine omits trailing empty crafting slots. The arrow Basics
   declaration contained nine slots while its native record ended at slot
   seven, causing the exact catalog audit to fail. The declaration now matches
   native output. Width3, positions3/5/7, Bronze+two Sticks, yield200 and immediate
   profession-free starter visibility are unchanged.

Missing-route diagnostics now escape NUL separators so the engine log retains
the item and full recipe instead of printing only `grid`.

## Verification

The corrected fish fixture first reproduced the exact reported error. Three
bounded isolated native launches then exposed the recipe blocker, identified
its truncated diagnostic and finally passed. The final disposable probe checked
the real entity, actual Basics records and visibility, and native crafting output
of 200 arrows; it requested immediate shutdown before world preparation.
Server reached listening and shut down cleanly. All three scratch worlds were
removed; no agent engine remains. The user's personal world was not opened.

Six changed/new Lua files pass the 5.1 parser and all five sweeps. Global writes
are fixture doubles. The final compact PUC/JIT regression outputs match:
`626e991dd8d09b4cda295fba4c5ae024dfe06402e5298793d2d3996e5ae49405`.
The earlier full R21 micro pair in this folder predates the arrow correction;
the `final-*` pair and real engine log are the final follow-up evidence.
No mapgen owner, census or full-world test was repeated.

Evidence: [engine](../../tools/round21/evidence/startup-fix/engine.log),
[portable](../../tools/round21/evidence/startup-fix/final-puc.log),
[static](../../tools/round21/evidence/startup-fix/static.log).
Review found no remaining blocker; the native catalog test closed a gap in the
previous source-only arrow review. Calibration: nontrivial, Astra/Astra,
0 newly review-raised Critical/High, two confirmed startup blockers fixed;
elapsed implementation time unknown. No remote push.

Runtime acceptance: restart the game/server, open Basics and find Arrows;
craft 200 with one Bronze Bar and two diagonal Sticks. No new world is needed
for these registration-only corrections.
