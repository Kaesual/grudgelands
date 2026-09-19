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
  wins, looks broken). Ruling 2026-09-19: move the core ring and its gates
  two nodes outward (user: the core ring is not connected to the WP40 route
  pins, which lie far outside the outer ring; the only routes into the core
  are the outer ring's straightforward alleys). WP13 code only.
- (6a) **Royal guards without crowns**; only the king wears one.
- (6b) **Two royal guards instead of four** (four are too hard).
- (7a) **Dragons twice as large**, collision box scaled with the visual
  (today `size` 4 / box ±1.5 × 4 and ±1.2 × 3.2).
- (7b) **Dragons must move** (ruling 2026-09-19): walk or fly at their own
  discretion, faster than any player movement so nobody simply runs away;
  today they are stationary hoard guardians (`walk_velocity`/`run_velocity`
  0). Their breath projectiles are invisible and leave no ground effect:
  both must become visible. Further boss ideas are under discussion (see
  the chat of 2026-09-19); prefer cool-and-simple. Candidate lane R9-BOSS
  (dragons + the royal-guard changes), wave 1, parallel to MOB2.
- (7c) **Dragon HP 54 000 → 18 000** for V1 testing.
- Dragon positions: Wyrmglass Ice Dragon (west island) at x = −3260,
  z = −40; Stormscale Jungle Wyvern (east island) at x = 3260, z = −40.

## Decided on 2026-09-19 for the remaining points

- (8) Cooking is tested after the next round, once the rebuilt recipe
  books exist. Book detail: the **Close button returns to the crafting
  UI**, it does not close the inventory.
- **Recipe discovery (proposal, awaiting the user's yes):** a recipe is
  listed in the book when (a) its tier is unlocked and (b) the player has
  held every ingredient at least once (a per-player "seen items" set from a
  cheap periodic inventory scan, since code-side pickups bypass the
  inventory-action callback). Learning a profession marks its T1 recipes
  as discovered so the book is never empty; undiscovered recipes per tier
  are shown as a count. Tier unlock stays as built: crafts at the current
  tier only, automatic at the threshold, capped by the character band.
- (9) Fishing: not tested separately; feedback comes from the friends'
  playtest evenings.
- (10) Brewing stand takes two reagents plus a vial. Backlog, not Round 9:
  an optional third "catalyst" slot with a handful of generic catalysts
  that modify any potion (duration, doubled output) — one function, no
  per-recipe work — if more variety is wanted later.
