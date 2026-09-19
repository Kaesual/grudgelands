# TODO — Playtest 11 findings (2026-09-19, user, fresh world)

Collected while the playtest runs; folded into the Round 9 lanes once the
playtest is complete. Mapgen findings are already in `TODO-round9.md`
(R9-MAP-C).

## Verified good

- (1) Per-viewer nametags with two clients: as intended.
- (2) Strike tooltip per class: correct.
- (4) Mob wave 1 in a start zone by day and night: looks good.
- (6) Kings and royal guards look great (changes below).

## Findings

- **Stone plate through every cave at y = −34/−35, one node thick.**
  Suspects: the R8 strata pass (depth band down to 40 nodes below the
  surface) or the fill floor at y = −37 writing host rock into native cave
  air at one row. Check in R9-MAP-C step 0 (cheap: which pass writes at that
  row) and fix there; the skin rule must not add a second plate.
- (3a) **Trainer names:** the profession trainers must carry their
  profession ("Cook", "Cooking Trainer"), not a generic label.
- (3b) **Profession book UI: rebuild as a VoxeLibre-style craft guide.**
  Top: the list of craftable items with a text search. Bottom: the 3×3 grid
  with the arrow and the output, showing the exact placement; left/right
  arrows cycle through alternative recipes of the same output; the station
  is shown beside the grid. The current book is overloaded and hides the
  grid placement. Project licence is GPLv3, so VoxeLibre's `mcl_craftguide`
  (GPLv3) may be studied or adapted with attribution; formspec only, the
  `grug_jobs` registry stays.
- (5a) **Undead capital walls:** on the z-oriented wall segments the iron
  bars on top of the battlements are rotated 90° wrong (param2); the
  x-oriented segments are right. WP13 precinct ring.
- (5b) **Walls overlap the core buildings** in most capitals (the wall
  wins, looks broken). Options: move the conflicting buildings one or two
  nodes inward (risk: new conflicts with neighbouring buildings), or move
  the whole ring and its gates two nodes outward. The user prefers the
  simpler one; the lane decides after checking how gates are cut where
  routes enter (routes are solved in WP40 with fixed capital fittings, so
  the outward move must not touch a route pin).
- (6a) **Royal guards without crowns**; only the king wears one.
- (6b) **Two royal guards instead of four** (four are too hard).
- (7a) **Dragons twice as large**, collision box scaled with the visual
  (today `size` 4 / box ±1.5 × 4 and ±1.2 × 3.2).
- (7b) **Dragon behaviour reads as broken:** flying animation, no
  movement, damage after a short wait. Cause: the dragons are authored as
  stationary hoard guardians (`walk_velocity` and `run_velocity` 0, breath
  projectile up to 32 nodes). Needs a user ruling: keep stationary with a
  clearer telegraph (breath particles, roar), or let them move/fly within
  the leash (36 nodes).
- (7c) **Dragon HP 54 000 → 18 000** for V1 testing.
- Dragon positions: Wyrmglass Ice Dragon (west island) at x = −3260,
  z = −40; Stormscale Jungle Wyvern (east island) at x = 3260, z = −40.

## Still to test

- (8) Cooking v1 through the grid and the raw-assembly furnace route.
- (9) Fishing in several level bands.
- (10) Alchemy v1: trainer, brewing stand, one potion and one elixir.
