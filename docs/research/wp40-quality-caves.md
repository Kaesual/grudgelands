# WP40 quality follow-up: surface cave entrances

Status: implementation on `wp40-quality-caves`, 2026-09-13.

Fresh worlds add sparse deterministic hillside entrances without scanning the
world or running a second carve pass. Each 192 by 192 horizontal cell has at
most one candidate and only one quarter of cells pass the seed gate. Candidate
mouths stay 40 nodes from every cell edge. A seeded 24- or 32-node endpoint
sample selects the steepest cardinal uphill direction and requires a rise of at
least six nodes from a mouth at y = 16 or higher.

An accepted entrance is a 32-node tube of radius two. Its centre begins one
node above the mouth surface and descends one node after every four forward
steps. The integer circular section uses
`floor(sqrt(4 - side_offset^2))`; the last 16 sections retain at least three
nodes of roof. A closed end is valid and this feature does not claim a
connection to a native cave network.

The complete tube footprint plus a two-node horizontal halo must remain inside
its source cell on ordinary dry land in one logical zone. Any water or named
hydrology, transition, functional surface, hard foundation, static exclusion
or housing mask rejects the complete candidate. The query uses a fixed
128-slot cache. Cell decisions depend only on the full seed and cell
coordinates, so cache eviction and query order cannot change the result.

`planner_source.surface_cave_run_at(x, z)` returns the inclusive vertical air
run for a tube column. The R5 planner splits its priority-5 terrain fill and
surface around that run and emits the existing terrain-clear opcode 26 with
`CUT_NATURAL`; higher-priority engineered operations therefore retain their
normal authority. R6's prospective P5 replay returns the same air run, and P7
surface/support analysis returns no material inside it. The actual
VoxelManip-backed support and host checks remain unchanged.

The compact fixture exercises the production cave factory with a synthetic
hillside, all four directions, every exclusion, negative cells, tube geometry,
cache eviction and reverse query order. Its LuaJIT expanded mode additionally
uses the real terrain stack for seed `13191094842853985814` and seed `0`, and
checks an entrance crossing an 80-node owner boundary through the actual R5/R6
planner. The compact mode is suitable for the single final PUC/LuaJIT fixture;
development and expanded searches remain LuaJIT-only.
