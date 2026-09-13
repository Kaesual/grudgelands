# WP40 flying-mob near-ground nudge

## Scope and engine seam

This package changes only Grudgelands mobs registered through
`grug_mobs.register_mob` whose live mobs_redo fields say `fly = true` and
`fly_in = "air"`. Water fliers such as the Kraken and every ground mob are
outside the mechanism.

mobs_redo calls `do_custom` before `do_states` on each entity step. Its
`dogfight` attack branch already tracks the target vertically when the target
is outside reach. It compares the floored mob origin with the floored target
origin plus one node, then commands `+walk_velocity` or `-walk_velocity` while
the next node is valid flight medium. Collision boxes enter the later punch
line-of-sight calculation; they do not determine this vertical command. The
eagle/vulture box begins 0.01 nodes below its origin, so the existing origin
rule does drive it down to a grounded player rather than preserving a hidden
high-altitude offset. The nudge
therefore runs from the existing Grudgelands `do_custom` wrapper and yields
whenever mobs_redo owns purposeful steering: attack, runaway, following,
evade, or a Grudgelands root. It does not acquire or replace a target.

## Frozen tuning contract

- Probe period: 0.75 seconds, with the first probe staggered over 16 phases by
  the entity's initial integer position.
- Probe depth: at most 12 integer node positions directly below the entity's
  collision-box bottom. A walkable registered node is ground. An unknown,
  unloaded, or `ignore` node ends the probe without a ground result.
- Comfortable clearance: 2 to 4 nodes between the ground-node top and the
  live collision-box bottom. This puts ordinary birds within practical melee
  reach without pinning them to one altitude.
- Above 4 nodes: additive vertical bias tends toward -0.65 nodes/second.
- Below 2 nodes: additive vertical bias tends toward +0.55 nodes/second.
- Inside the band, without a valid probe, or while another steering owner is
  active: the additive bias tends toward zero.
- Bias acceleration is limited to 0.8 nodes/second squared. Position is never
  teleported. The controller subtracts its previous additive bias from the
  current velocity before adding the next bias, preserving native horizontal
  and vertical steering. If mobs_redo replaces vertical velocity between
  ticks, that value becomes the new baseline and the obsolete bias is
  discarded. Losing the bottom of the probe over a ravine removes
  the downward tendency gradually instead of commanding a drop toward the
  newly distant floor.

All controller state lives under mobs_redo's transient `self.temp` table. A
reload starts with no cached ground and zero owned bias; there is no persisted
format and no migration path.

## Verification boundary

`tools/wp40/quality/flight_fixture.lua` loads the production controller with a
stub ObjectRef and covers high hover, low-ground avoidance, a sudden canyon,
unknown/unloaded nodes, attack ownership, non-air mobs, roots, and fresh
lifecycle state. It emits one canonical line suitable for WP40's final compact
PUC/LuaJIT digest pair; development execution remains LuaJIT-only.
