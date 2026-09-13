# WP40 terrain-fitted junction heights

**Status:** implemented bounded quality follow-up, 2026-09-13.

## Scope

This revision changes only the vertical targets of ordinary road junctions.
The accepted horizontal centrelines, route widths, ownership, geography,
exclusions, crossings, water masks, buildings and island landings remain
fixed. The production height schema is
`grug_wp40_simple_map_height_v3`, selected by source revision
`wp40-height-quality-v3`. Fresh-server development has no reader or fallback
for the former revision. Existing natural-relief random domains retain the v2
domain tag, so the revision changes junction fitting without reseeding terrain.

## Junction rule

Every coordinate shared by connected route endpoints has one deterministic
target. An ordinary dry junction prefers `scalar_before_paths` at that exact
column, after natural relief and fixed non-path grades and before any route
grade. This removes the former zone-wide minimum-height pin that cut radial
trenches or peaks into otherwise unrelated local terrain.

Fixed start and capital fittings, selected POI fittings, island arena and mine
fittings, island landings and planned-water clearance remain hard endpoint
constraints. Before choosing a free station target, every fixed POI spur
contributes the interval reachable at the accepted maximum adjacent grade of
one node. Island endpoint intervals propagate through the complete connected
island-route graph. The terrain preference is clamped to the resulting
interval. An empty interval fails construction and names the affected route or
zone; the solver never moves a fixed endpoint to manufacture feasibility.

The existing route solver then applies the unchanged water lower bounds, ford
and tunnel pins and one-node grade rule. It verifies every connected endpoint
against the single registered target after solving.

## Bounded evidence

`tools/wp40/quality/junction_fixture.lua` constructs seed `0` and reported
visual seed `13191094842853985814` under LuaJIT. It checks that all incident
endpoints equal their shared target, that the visible junction column equals
that target, and that each free node is the nearest feasible height to local
prepath terrain. It also requires every free target to be at least as close to
that terrain as the former zone-wide pin, with a strict improvement present in
each seed. Some nodes retain an unavoidable adjustment to reach a fixed POI,
landing or arena. Landing and water constraints remain fixed. The fixture
reports free, fixed, shared and improved junction populations plus the maximum
remaining free-node terrain deviation.

`tools/wp40/quality/junction_micro.lua` loads the changed production height
module and exercises the same feasible-preference and connected-edge interval
helpers without constructing a seed. The coordinator incorporates this helper
into the single final PUC 5.1/LuaJIT parity process after all WP40 quality bytes
are frozen.
