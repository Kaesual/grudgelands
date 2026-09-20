# TODO — Starter tool lifetimes

Updated: 2026-09-21. User requested discussion before implementation.
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

## User proposal — 2026-09-21

User goal: very short-lived wooden bootstrap tools, somewhat better stone,
then durable metal tools whose tier becomes the main progression limit. Wood,
Stone and Bronze remain T1 from the tool progression perspective.

The earlier coordinator suggestion of 24/64/512 is superseded by the user's
proposal below. No implementation has started; the user explicitly requested
a feedback/discussion round first.

| Tier/material | All four tool families | Weapons and armor |
|---|---:|---:|
| Wood | 30 | removed |
| Stone | 60 | removed |
| Bronze / T1 | 300 | 1000 |
| Iron / T2 | 600 | 1500 |
| Steel / T3 | 1000 | 2000 |
| Silversteel / T4 | 1500 | 2500 |
| Embersteel / T5 | 2000 | 3000 |
| Abyssal Steel / T6 | 3000 | 4000 |

- Tools and weapons are disjoint. One-handed axes become woodcutting tools
  (suggested English label: "Woodcutting Axe"), cannot enter the weapon slot,
  cause no damage and have no damage tooltip. The two-handed weapon is a
  "Battle Axe". Apply the no-damage tool principle consistently to picks,
  shovels and hoes as well; existing direct tool-punch paths need review.
- Remove wooden/stone weapons from registration, recipes, starter grants and
  catalogs. All weapon families begin at Bronze; this is a progression tier,
  not a requirement that a bow or staff be made entirely of metal.
- New characters receive their class's Bronze weapon. Preserve Scout's 200
  arrows; its current backup Stone Sword also needs a Bronze replacement.
- Each successful incoming combat hit spends one use on one randomly selected
  equipped armor piece, rather than on every armor piece. Define eligible
  non-broken candidates and shield participation before implementation.
- Add the missing Stone Hoe. Wood/Stone/Bronze tools all retain T1 access.

Open details: the existing refinement lifetime multiplier (currently x2; user
asked asynchronously), shields/spellbooks, and retention of deeper-mining wear
penalties. Current 3000/6000 weapon budgets mean this proposal reduces early-tier
weapon lifetime; randomly selecting armor reduces aggregate armor wear. Exact
event rules should preserve one outgoing wear debit per settled action, not per
victim/projectile, and no combat wear for falls or environmental damage.
