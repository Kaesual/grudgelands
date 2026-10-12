# TODO — Depth pulse placement and servant roster

The decided depth curve, the pulse and T6 resource role live in
`docs/design/combat_stats.md` §3, `docs/design/biomes_mobs.md` §4.1 and
`docs/design/world.md` §4c. Renewable camp sockets are removed (user decision
2026-09-29, WP audit E5). WP34 is now only the depth pulse.
Historical decisions and rationale from the former version of this TODO are
preserved in [the world-design archive](docs/archive/design/world-historical.md).

## A2 — Placement geometry (closed, Round 46)

Decided by the user on 2026-10-12 (the Round 46 lane DP design note) and built
in `grug_mobs/depth_pulse.lua`; the rule text is `biomes_mobs.md` §4.1:

- Distance band: 6–14 nodes from the player's eyes, found by up to four rays.
- Line of sight: every spot lies on an open ray from the player's eyes.
- Solid-adjacent air: not needed for flyers; a ground arrival settles on the
  floor at most 4 nodes below its spot.
- No legal position: in a sealed room the farthest spot of at least 3 nodes
  is taken; with none, the arrival is skipped and stays owed (at most one,
  retried each second). No node is ever changed.

## A2/D10 — Servants below −1000 (closed, Round 46)

Below −1000 the pulse brings the **Riftwing** (a violet cave-bat flyer, only
the pulse brings it), the Ember Wisp, the Rift Spawn and the Bedrock Sentinel
(the Land Guard). The Land Guard and the Rift Spawn's deep row joined the
pulse (WP audit E4) and have no cave row any more. They keep their family
drops; arrivals give no coin bag.

The settled limits remain: regular mobs cap at level 60; deeper danger comes
from arrival pressure, not higher regular-mob stats. This band pays in raw
materials, has no gear-drop layer and has no separate apex boss in the MVP.
