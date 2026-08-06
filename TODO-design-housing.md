# TODO — Housing Layout (ocean model)

Context: the continent redesign (2026-08-06, `docs/design/world.md` §1)
moved housing off-continent into the safe ocean beyond the coastal zone
(|z| ≳ 4000). The ownership/economy anchors are decided (world.md §5:
guild-owned, on-demand allocation, split build/mining rights forming the
editable cube, depth treasures, no respawn). Open is the **layout and the
generation mechanics**.

## Q1 — One island per guild, or a contiguous housing shelf?

- **A: One island per guild** (user leaning). Each guild gets its own
  island, generated with generous water spacing to the neighbors —
  real "island feeling", natural visual ownership, the ocean is the
  buffer. Expansion = the island's usable cube grows (more surface
  and/or depth of the SAME island; the island is generated at full
  reserve size from the start, rights unlock parts of it).
- **B: Contiguous housing shelf** "behind" the continent — one large
  land band, guild areas carved out with unbuildable safe borders in
  between. More "district" than "island"; cheaper to reason about
  distances, less charming.
- Recommendation: **A**. It matches R3 (ocean = unbuildable) so buffers
  are automatic, and per-island generation is technically clean (below).

## Q2 — How does "on-demand generation" actually work?

Luanti generates terrain when chunks emerge, deterministically from the
seed — we cannot literally "create land later" where ocean was already
generated. Recommendation (makes A cheap):

- Islands live on a **fixed allocation grid** in the housing band (e.g.
  one slot per 1000×1000 cell, spiral order behind the own continent).
  The island terrain function is deterministic per slot, but an island
  only RENDERS as land if its slot is marked **allocated** in mod
  storage (the mapgen pass checks the registry; unallocated slots
  generate as plain ocean).
- Buying housing = allocating the next free slot (or a random free one
  for spacing). Chunks there have virtually never been emerged before
  (nobody travels the deadly open sea), so the island generates on first
  visit — "on demand" without regenerating anything.
- Edge case: a slot whose chunks WERE already emerged as ocean (deadly
  sea tourists) — either skip such slots at allocation time (tracked via
  a cheap emerged-flag) or accept a one-time forced regen of those few
  chunks. Decide during implementation.

## Q3 — Island access

- Recommendation: buying housing immediately grants the island's
  **waypoint** (world.md §6) and unlocks it for all guild members —
  travel to housing is teleport-only by design; the deadly sea stays
  deadly. First visit needs no boat trip.
- Open: do visitors of other guilds get waypoint access (world.md §5
  allows visiting), or only after being invited while standing there?

## Q4 — Numbers (later, with the economy design)

- Island reserve size + grid cell size, base cube (x/z and y), step
  sizes and prices for build vs. mining rights (gold-income curve first:
  TODO-design-items-crafting.md §4).
- Depth treasure distribution per island.
- Distance of the housing band: |z| ≈ 4000 as working value (coastal
  ocean ends ~3200 from z=0; leave slack for the deadly sea belt).
