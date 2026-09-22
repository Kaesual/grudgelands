# Round 16 progression handoff

Implementation lane D plus the XP-label/admin-command part of lane E.
Baseline: `bddd1edfbf8516b8ec553886f554bc480ad63625`.

## Fixed reward table

The level interval is `100 * (2L - 1)`. Rewards are catalog constants and do
not inspect the receiver's level. Ordinary starter quests use 20%, the hard
outpost step uses 25%, and the camp finale uses 35%. Optional local work uses
15%/20%/25% for light/standard/hard effort. Values are integral at every
authored level, except L12 standard's exact 460 and therefore require no
runtime rounding policy.

| Catalog row | Intended level | Effort | Old XP | New XP | Same-level normal kill XP after Round 16 |
| --- | ---: | --- | ---: | ---: | ---: |
| Starter 1 | 1 | standard | 150 | 20 | 15 |
| Starter 2 | 2 | standard | 300 | 60 | 30 |
| Starter 3 | 3 | standard | 550 | 100 | 45 |
| Starter 4 | 4 | standard | 900 | 140 | 60 |
| Starter 5 | 5 | standard | 1,500 | 180 | 75 |
| Starter 6 | 8 | standard | 3,000 | 300 | 120 |
| Starter 7 | 10 | standard | 2,200 | 380 | 150 |
| Starter 8 | 11 | hard | 2,800 | 525 | 165 |
| Starter 9 | 12 | finale | 3,400 | 805 | 180 |
| Axe lesson | 1 | light | 150 | 15 | 15 |
| Pick lesson | 2 | light | 250 | 45 | 30 |
| Village local 1 | 10 | light | 550 | 285 | 150 |
| Village local 2 | 10 | standard | 700 | 380 | 150 |
| Outpost local 1 | 11 | light | 650 | 315 | 165 |
| Outpost local 2 | 11 | standard | 800 | 420 | 165 |
| Camp local 1 | 12 | standard | 900 | 460 | 180 |
| Camp local 2 | 12 | hard | 1,100 | 575 | 180 |

The same-level kill column is the normal-tier formula `10L` multiplied once
by 1.5. Participant splitting still happens afterward. The human kill bonus,
when applicable, remains downstream in `grug_xp.add_xp`.

## Guidance and handoff

Registry construction appends `Requirements: Minimum level: ...` and named
prerequisite titles to the shared description consumed by NPC dialogue and the
quest journal. Each race's starter quest 6 now uses its village steward as
`turnin_npc`; quest 7 was already offered by that steward. Existing active,
ready, marker and atlas state all resolve through that same field.

## XP UI and command

The existing right-of-bar label now carries interval progress, such as
`Lv 2 (25/300)`, and reads `Lv 60 (max)` at the cap. `/xp` remains a self-query.
`/xp give <player> <amount>` requires the `server` privilege, an online target,
a positive whole amount, and a result at or below the level-60 XP maximum.
Admin XP carries no reward source, so no race or kill multiplier is involved.

## Evidence and residual risk

Callable development fixture:

```sh
luajit tools/r16_progression/kat.lua .
```

It loads the real quest registry/catalog, quest state, XP module and mob award
module. It checks all reward rows, six regional handoffs, visible requirements,
turn-in settlement, the label, privileged and rejected grants, 1.5 kill XP
before a two-recipient split, downstream race bonus, range eligibility, gray
suppression and exactly-once settlement. The coordinator owns the final compact
PUC/LuaJIT parity run.

The only material runtime risk is text width at unusually large GUI scaling;
the label keeps the existing shared right-side anchor and can be checked in the
GUI playtest. The reward correction is intentionally a large reduction because
the old values exceeded the newly approved fraction of a level interval.
