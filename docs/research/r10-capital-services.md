# Round 10 capital services

Final integrated status and exact gate identities: [Round 10 final completion](round10-final-completion.md).
Final technical gates PASS. The reviewed changes are delivered on main, synchronized
and pushed; GUI acceptance remains pending.

Candidate `b80b2037` independently source-reviewed CLEAN and delivered on main.
Final interpreter parity passes; main delivery, synchronization and push are complete.
Authority: `docs/research/round10-execution.md`, `docs/design/settlements.md`,
`docs/design/professions.md` and `docs/design/items_crafting.md`. Fresh-server
mode applies; current-version entity reload and station activation are tested.

The six civic rings now use radius 48. Actual gatehouse geometry reaches ±49,
so the projection includes that extent. Inner avenue endpoints start at ±50;
gate approach paving reaches the moved door cells. Outer route pins are unchanged.
Nhal Veyr's 72 battlement bars follow their wall direction.

Existing themed outer plots now hold eight profession trainers, seven public
stations and a separate Riding trainer per capital. Both smiths share one Forge.
The six starts retain Cooking only. A shared 21×17 stable contains four full-size
catalog mount displays behind its trainer: 24 displays total. Two rows of broad
bays accommodate the posed T3/T4 wings without shrinking them. Existing vendors,
ordinary workers, kings, guards and travel services remain separate roles.

`wp13/capital_services.lua` owns authored sockets and room furniture.
`settlement_sockets.lua` validates their roles and closed tags. Station consumers
use explicit public sockets rather than offsets from trainers. The Cooking
furnace has the narrowly documented vendor patch in `VENDOR.md`; private furnace
protection and Cooking extraction progression remain intact. Dedicated Riding
sessions validate the live trainer, settlement, player distance and purchase
state. Profession trainers do not carry the retired Riding hook.

Displays have no AI, step callback, combat, riding or collectible inventory.
Socket leases provide deduplication and current-save activation. Mount grounding
is absolute from the authored floor and evaluated stand pose, so repeated reload
cannot accumulate displacement. Inert furnishings cannot drop, burn, grow or
convert into harvestable material. Hide and loom frames use distinct existing
leather/cloth textures. No production art or imported model was changed.

## Requirement and evidence map

| Requirement | Production seam | Evidence |
| --- | --- | --- |
| Radius, bars, gates, projection and safe approaches | six capital cores, quadrants, `r7_settlement` | full WP13 LuaJIT runner; precinct, six city and seam KATs |
| No ordinary building/ring collision | actual pre-ring buffer and writer | `tools/r10_cap/ring_overlap.lua`; all six zero; intentional corner-tower joins separately counted |
| All six real plot builders and shared service rooms | plot builders, `capital_services`, `parts` rotation | portable `geometry_micro.lua`; eight trainers/seven stations in real roster fixtures |
| Actual manifest and terrain-resolved station reach | `r7_manifest.new`, runtime settlement sockets | R8-ALCH capital KAT; 42 world-coordinate station rows with nearby correct trainers |
| Real planner boundary consumption | actual R5 source/runtime planner | `planner_integration.lua`; six core/avenue boundary columns |
| Dedicated Riding purchase and old hook absence | actual villager click, trainer, state, money, items | portable `purchase_micro.lua`; full existing mounts LuaJIT KAT |
| Entity ACL, reload and lease deduplication | displays and actual start-NPC activation | portable `services_micro.lua`, repeated nonzero grounding/reload |
| Furnace activation, timer, access and progression | actual default furnace and jobs adapters | portable `furnace_micro.lua` |
| Full-size posed mounts, roof/rail/trough/aisle clearance | actual catalog, B3D models, emitted stable cells | 24 conservative envelope checks; 12 production foot constants reproduced |
| Readable profession furnishing and mount appearances | actual node/item textures and meshes | 13 native textured cutaways, 12 stand views and gear-binding detail sheet |

Final candidate evidence is `tools/r10_cap/evidence/geometry/`; the separately
reviewed callback checkpoint remains in `evidence/callbacks/`. Input SHA manifests
bind current production modules, fixture and renderer sources, meshes and media.
Native rendering is reproducible through `tools/r10_cap/render.sh`.

The pose evaluator follows pinned Luanti/Irrlicht B3D loader frame mapping,
node-global bind vertices, bone weights and skinning, cited in `b3d_pose.py`.
Conservative posed AABBs are disjoint from **all actual non-air node cubes**,
including the omitted roofs, with 0.01-node margin. This proves stronger spatial
separation than checking a few vertices or collision boxes. Offline renders do
not replace the engine visual gate. Cutaways omit upper roofs/front walls;
trainer bars are diagnostic position markers. Gear detail shows actual registered
artwork, not a claim to reproduce the engine's wielditem extrusion.

The full WP13 LuaJIT suite passes, including its nine-seed capital water checks.
The source manifest constructor passes on the changed geometry. No source-pin
oracle was weakened, historical R7 source roster stays exactly 157, and no PUC
runtime was run in this lane. Root owns the single final integrated PUC/LuaJIT
pair after MAP-B. The six-capital service/precinct/Alchemy and six-start
order/reload engine gates and final parity pass; overlay attribution is
independently CLEAN. Main delivery, synchronization and push are complete.

Known unrelated deviation: decided `bandit_frontier` building-core width is 24 while current
source remains 16. CAP neither widens that geometry nor changes design to 16.
Unbuilt POI and housing expansion remain outside this package.

Implementation model: native GPT-6 Astra. Independent reviewer: native GPT-5.6
Sol; source CLEAN at `b80b2037`, zero remaining material findings, two focused
preflight fix rounds; observed elapsed time unknown. See
`round10-reviews/cap-review.md`. No merge, push, sync, personal-world access or
external AI was performed by this lane.

## User runtime check after integration

On a fresh world, visit each capital's Riding stable and the seven workshop
locations. Check full mount silhouettes, station access, two smiths sharing one
Forge, no profession-trainer Riding entry, protected noncollectible displays,
and unchanged Cooking purchase/extraction requirements. Leave and reload the
area to check stable display position and deduplication. Walk all four civic
gates and inspect Nhal Veyr's wall bars.

## Post-integration corrections

The real engine found a display-placement High in the mob-only facing helper;
`561a9c2b` corrects plain display activation and is independently reviewed.
`ccd10d96` independently preserves lamp/pier cadence when the inner avenue
start moves to 50. The final six-capital engine witnesses pass service,
precinct and Alchemy checks. [Exact overlay attribution](../../tools/r10_capital_phase/ATTRIBUTION.md)
separates the accepted inner changes from earlier terrain changes and reports
zero unexplained coordinates across all 18 historical comparisons; attribution and current-baseline reviews are independently CLEAN. The central completion record owns final gate identities.
