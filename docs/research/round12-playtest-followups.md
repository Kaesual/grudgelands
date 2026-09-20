# Round 12 — First playtest corrections

Date: 2026-09-20. These corrections supplement the frozen
[round delivery](round12-completion.md); they do not rewrite its historical
native-test evidence.

## Corrected behavior

- `9a99f890`: wooden/stone pickaxes, axes, shovels and swords appear immediately
  in Basics. Both Bronze Hoe recipe orientations also become immediate starters.
  The recipes already existed and were manually craftable; their presentation
  incorrectly waited for material discovery. Ten route declarations change:
  starters 63 → 73, with 830 total routes (596 Basics, 234 profession) unchanged.
- `11f8ca3d`: Skills drag recovery authenticates the destination inventory using
  its engine location and player name. Comparing InvRef userdata wrongly rejected
  the fresh wrapper Luanti supplies for the same underlying player inventory.
  Entitlement, mount ownership, destination-list and duplicate checks remain.
- `463ab623`: the regression models both inventory callback sides in engine
  order, including infinite-source restoration and the destination notification.

## Independent review and verification

[Starter review](round12-reviews/playtest-starter-recipes.md) covers candidate
`2a8ed73c`; [Skills review](round12-reviews/playtest-skills-restore.md) covers
`9036d18f` plus correction `15d2808c`. These were cherry-picked unchanged into the
main commits above. Both final verdicts are clean.

Deployment: synced from main with `tools/sync_to_luanti.sh`; every installed
runtime source/media file was compared by SHA-256 to the current repository
payload and matched. Loading the changes still requires the user's game restart.

On integrated runtime source head `463ab623`:

```sh
chrt --idle 0 ionice -c3 luajit tools/r12_skills/behavior.lua .
chrt --idle 0 ionice -c3 luajit tools/r12_recipes/presentation_kat.lua .
```

Both pass. The recipe result is `routes=830 general=596 profession=234 starter=73
starter_tools=10`. All five changed Lua files pass the plain-5.1 parser,
SETGLOBAL inspection and all five forbidden syntax/API sweeps, including tools
fixtures explicitly. Production files introduce no global writes; fixture writes
are intentional harness setup. No PUC runtime, broad suite or GUI test was run.
The old 63-starter native catalog log remains historical evidence; engine recipe
registrations and identities did not change.

Calibration: implementation GPT-5.6 Sol; independent review GPT-5.6 Sol in a
separate non-author context; coordinator integration GPT-6 Astra. Each package
had zero Critical/High findings. Starter recipes needed zero correction rounds;
Skills needed one correction round for a Medium fixture-order finding, with no
production-code revision. Observed elapsed wall time: unknown.

## Discussion remains open

[Tool lifetime figures and proposal](../../TODO-tool-lifetimes.md) and
[station inventory modes](../../TODO-station-ownership.md) are planning records.
No durability, Stone Hoe, personal-station or ownership implementation is included.

## User runtime check

User acceptance on 2026-09-21: destroying and restoring Skills works.
The recipe visibility check has no separate acceptance report yet.

Restart the game to load the corrected Lua. Delete Taunt and drag it from Skills
into the main inventory; verify a second copy is unavailable while one exists
in main or a bag. Open Basics on a character without material discoveries and
check Wood/Stone pickaxe, axe, shovel and sword, plus Bronze Hoe visibility.
