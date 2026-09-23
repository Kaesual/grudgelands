# TODO — Depth pulse placement and servant roster

The decided depth curve, renewable camp sockets and T6 resource role live in
`docs/design/combat_stats.md` §3, `docs/design/biomes_mobs.md` §4.1 and
`docs/design/world.md` §§2/4c. WP34 remains future work with dependencies in
BACKLOG; existing cave mobs do not mean the phase-in pulse is shipped.
Historical decisions and rationale from the former version of this TODO are
preserved in [the world-design archive](docs/archive/design/world-historical.md).

## A2 — Placement geometry (open)

The player-centric, light-independent pulse and its curve, six-mob per-player
cap and approximately two-second telegraph are decided in `biomes_mobs.md`
§4.1. Its exact placement still needs a decision:

- Distance band from the player.
- Line-of-sight rule.
- Whether the target must be a solid-adjacent air node.
- Behavior when no legal position exists: skip or widen the search.

No placement values or fallback behavior are authorized by this TODO.

## A2/D10 — Servants below −1000 (open)

Choose families, licensed animated models and drop tables for the deep band's
servants. They join the same pulse and accounting model, rather than becoming
a second place-bound spawn source. The shallow half uses existing cave
families, so the dedicated roster may follow that mechanics increment.

The settled limits remain: regular mobs cap at level 60; deeper danger comes
from arrival pressure, not higher regular-mob stats. This band pays in raw
materials, has no gear-drop layer and has no separate apex boss in the MVP.

## Implementation dependency

BACKLOG WP34 owns the pulse and depth economy; WP13 owns mining-camp structures
and WP44 supplies the economy dependency. The two questions above remain open;
this cleanup neither closes them nor starts implementation.
