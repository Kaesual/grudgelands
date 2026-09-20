# TODO — Starter tool lifetimes

Date: 2026-09-20. User requested current values before deciding new durability.
Wood/Stone/Bronze share T1 pick access. Missing immediate wooden/stone Basics
routes are a confirmed bug and were fixed independently; lifetime changes
are not yet approved.

## Current ordinary-use budgets

Base variants, non-Creative, ordinary matching level-0 nodes. Mining below the
natural depth allowance can spend extra wear. Combat wear is a separate system: even wooden/stone slot weapons currently
use the common 3,000 qualifying-action base equipment lifetime. The table below
is strictly digging/tilling.

| Material | Pickaxe | Axe | Shovel | Hoe |
|---|---:|---:|---:|---:|
| Wood | 30 | 30 | 30 | 64 |
| Stone | 60 | 60 | 60 | not implemented |
| Bronze | 180 | 180 | 225 | 128 |
| Iron | 180 | 216 | 252 | 192 |
| Steel | 180 | 180 | 270 | 256 |
| Silversteel | 240 | 288 | 360 | 384 |
| Embersteel | 300 | 360 | 450 | 512 |
| Abyssal Steel | 360 | 432 | 540 | 768 |

Sources: `grug_materials/mining.lua`, `overrides.lua`, `tools.lua`,
`default/tools.lua`, `grug_farming/hoes.lua`; engine `src/tool.cpp` applies
`uses * 3^(maxlevel - node.level)` to ordinary axe/shovel groupcaps. Picks use
maxlevel zero, while hoes spend their explicitly authored conversion budget.
These are not the raw legacy `uses` values. Iron/Steel axe lifetimes are currently
non-monotonic and should be corrected by the eventual calibration.

## Desired progression and initial recommendation

User goal: very short-lived wooden bootstrap tools, somewhat better stone,
then durable metal tools whose tier becomes the main progression limit. Wood,
Stone and Bronze remain T1 from the tool progression perspective.

Coordinator's initial discussion proposal: 24 Wood / 64 Stone / 512 Bronze
successful operations, shared across pickaxe/axe/shovel/hoe, followed by
monotonic higher-metal lifetimes. Add the missing Stone Hoe if this line is
adopted. The user has been asked about this magnitude; do not implement these
numbers or infer approval from the recipe visibility fix.
