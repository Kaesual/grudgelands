# Round 10 farming completion

Date: 2026-09-20.

The farming runtime keeps the existing seventeen stable crop families: the
fifteen Cooking plants plus Potato and Corn. Each registered harvest converts
to two seeds; a hoe prepares any legal `group:soil` node; water within three
nodes hydrates the soil; four timed stages mature after 200 seconds each; and a
mature crop returns its harvest item and one seed for replanting. Growth time
advances only on wet crop soil. The existing node metadata retains partial wet
progress across dry pauses and reloads.

Seed placement can hydrate and swap its supporting soil before placing the crop.
Both the supporting soil and crop position are therefore checked independently
with `core.is_protected` before either node or timer changes. This prevents a
player standing outside a protected civic field from changing its protected
soil through the crop position above it. Hoe use continues to check the ground
position it changes.

Map generation through VoxelManip does not invoke node `on_construct`. The
single existing `run_at_every_load` LBM remains the activation path for authored
field soil: it starts a missing hydration timer and leaves a running timer
untouched. This is current-version activation and persistence, not migration.
MAP-B owns conversion of authored field cells to these soil nodes and all wild
acquisition placement; this package changes no map generator or gathering
authorization.

`tools/r10_farm/farming_completion_kat.lua` loads the production mod and proves
the complete seed, hoe, wet growth, harvest and replant route for every one of
the seventeen families. It also covers VoxelManip soil activation, idempotent
reload behavior, and independent protection at both touched planting positions.
The fixture returns deterministic text for inclusion in the shared final
PUC/LuaJIT comparison.
