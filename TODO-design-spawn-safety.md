# TODO — Spawn-platform sabotage & placement safety

Context: the WP18 runtime test showed both failure modes of the
placeholder spawn platforms (25×25 cobble + 64 nodes of air, one per race
capital). The fixes that landed: the platform height is now the median of
the heightmap over the FOOTPRINT (not a ±40 neighborhood), and the
protected zone is the footprint only — from 30 nodes below the platform
upward (`docs/design/world.md` §2). Consequence: the terrain right next to
a platform is player-editable again (that is the point — players must be
able to dig out of a pocket), which opens a small sabotage surface for
players of the OWN faction.

Mitigating fact: `default:water_source` and `default:lava_source`
(`mods/BASE/default/nodes.lua:2204` / `:2394`) set no `liquid_range`, so
they use the engine default of **8** — shorter than `CAMP_HALF` = 12. A
liquid placed right at the platform edge cannot flow to the center where
players spawn.

## Open questions

- **Q1 — Border**: is a bigger platform or a dedicated liquid-repelling
  border (e.g. a ring of non-`buildable_to`, liquid-blocking nodes just
  outside the footprint) worth it, or is the liquid_range 8 < 12 margin
  enough?
- **Q2 — Enclosed-pit detection**: should the builder notice when the
  platform ends up walled in (compare the chosen y against the MAX
  heightmap over the footprint + margin) and then widen the clearing,
  terrace the surrounding walls, or shift the platform up?
- **Q3 — Anti-griefing at spawn POIs in general**: own-faction players can
  dig/build right up to the platform edge (pits, walls, spawn camping
  props). Do we need a "no placement" apron, a rollback timer, or is this
  acceptable in a faction-vs-faction game?

## State

**Open** — revisit with **WP13**, where real capital structures replace
the platforms and shrink the problem (a proper capital brings its own
footprint, its own ≥ 10 node terrain protection and no ad-hoc clearing).
