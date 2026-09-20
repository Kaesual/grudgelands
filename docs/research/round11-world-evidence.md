# Round 11 WORLD-CAP implementation evidence

Status: implemented on `wp40-r11-world-cap`, based on `45fbc477`; independent
review and integration remain pending. No main merge, sync, push or GUI
acceptance is claimed. The accepted scope is the WORLD-CAP portion of the
[Round 11 plan](round11-plan/README.md), with the coordinator-approved beach
technical replan after the original hypothesis was disproved.

## Authority and source checkpoints

- `7e63e965`: living specification first, in `world_zones.md`, `settlements.md`
  and the stable placement paragraph of `mounts.md`.
- `0ff61733`: actual CAP geometry, product definitions, motion endpoints and
  first focused geometry/mesh evidence.
- The final correction in this record restores the existing coast exclusion
  policy in `world_zones.md`: the initial proposed purpose-specific coast veto
  was not causal and was not implemented. The adopted change is bounded shore
  orientation resolution. `world.md`, FARM ecology/protection and GAME display
  lifecycle remain outside this branch's ownership.

Exact file bindings live in `tools/r11_world/evidence/source-inputs.sha256`;
`baseline-height.sha256` binds the before source. The evidence manifest binds
recorded outputs separately. Neither manifest represents a global source audit
or refreshes any historical WP40 projection oracle.

## Beach diagnosis and correction

Seed: `15140735923413111218`. The user positions are `(-414,20,-2724)` and
`(-511,20,-2562)`. The initial two 13×13 probes did not establish the reported
pillars: the first center was an ordinary beach; the second center lay in a
planned bay. Both original probe rows and the subsequent two 65×65 sightline
rectangles are retained. The larger rectangles contain the visible dry banks.

The actual runtime height constructor showed no claim, cave claim, functional
surface or landmark veto causing the spikes. The fallback shore lookup selected
one nearest point on a four-node sampling lattice, then chose its dominant X/Z
component as the coast orientation. At diagonal shores this changed run identity
between neighboring columns, selecting unrelated profile hashes. For example,
`(-415,-2720)` was height 9 among heights 4–5; `(-485,-2575)` was a height-20
bluff among beach heights 3–4. The latter's orientation/run selected the bluff;
there was no surviving native-material veto.

`height.lua` now retains that fallback's Euclidean distance, water level and
freshwater identity, but obtains its orientation from the nearest actual cardinal
water contact at distances 17–52. Direction order resolves equal-distance ties;
no contact retains the original fallback. The existing first 16-node cardinal
query, profile hashes, width/slope formulas, class policy, course, functional
priority and all exclusion masks remain unchanged. No final-height shaving or
new broad terrain allowance was introduced.

The bounded comparison covers 8,450 actual source columns. Class, owner-modulo
coordinates, claims, functionals, landmark flag, incoming height and shore
distance are identical. Whenever run identity remains the same, profile, width,
coast target and final height are also identical. Heights change in 211/4,225
and 37/4,225 columns respectively. The explicit thin-column oracle (a dry column
at least five nodes higher than both opposing dry neighbors on either axis)
finds 7→0 and 9→0. This is the precise measured criterion; it is not a global
claim that all natural slopes have one-node steps or that every world beach was
sampled. `beach-comparison.json` lists every original detected spike.

Cost is bounded in source: only the existing coarse fallback calls the new
helper. It performs at most 4×36 = 144 cached classification probes, stops each
direction at its first contact and truncates subsequent directions at the best
distance. It allocates no per-probe tables. The focused diagonal/tie/no-contact
fixture verifies this bound. This is a call-bound analysis, not a comparative
performance measurement or fleet.

`beach_writer.lua` exercises the actual R5 source, planner and VM adapter on
two 80×23×80 owner slices. Six columns spanning both defects contain synthetic
native stone, grass soil and coal ore; all cells above the corrected target
through y=24 become air. This rejects the competing skipped-material-class
hypothesis through the real writer. The test is not native v7 input, a complete
R7 tail, an engine screenshot or a whole-world census. No engine runtime was
launched for this package. Initial tool-only failures (diagnostic Lua upvalue
limit, absent worktree reference path and incorrect fixture call-mode spelling)
were corrected before the retained passing checks; none was a production defect.
The pinned engine reference was read through a temporary link to the existing
root checkout, removed afterward; no reference commit was changed.

## Capital geometry and protected products

The shared gatehouse clears exactly one additional cell `(3,11,d-2)` after its
existing flight construction. No tread, rise, deck, gate passage, footprint or
route changes accompany it. There is deliberately no bespoke staircase test.

All six stable plots use the same 21×17 open shelter contract: earth floor,
one-node perimeter fence with a five-node entrance, full flat roof at local y=6,
and exactly six posts at x=±10 and z=-8,0,8. Generic plot furniture is cleared
before this shelter is stamped so it cannot introduce hidden posts or walls.
The riding trainer and public front aisle remain unobstructed.

Each city retains four full-size display sockets. Ground tiers 1/2 additionally
publish `spawn=false` idle sockets `<mount socket id>_walk_a` and `_walk_b` at
the same authored y. Local x is -5/+5, z=-4..-2; Kezamba tier 2 uses z=-3..-2
for the tiger's tail clearance. Tiers 3/4 have no walking endpoints. Actual parts
rotation and the settlement registry resolve these to absolute terrain-fitted
positions. The focused socket test covers all four rotations and nonzero anchor
and terrain offsets; returned registry copies cannot mutate the authority.

GAME consumes these sockets through the existing settlement registry. It owns
motion, current-version persistence, unloading and grounded animation. The mesh
handoff requires absolute grounding from display floor +0.02 minus the minimum
of stand and move foot-Y, never repeated relative lifting. Move minima and full
sampled envelopes are in `motion-bounds.json`. The coordinator reports GAME
follow-ups `ce34679e` and `43c09f39` implement this handoff, including the existing
socket.y−0.5 floor convention; GAME's independent review remains separate from
this geometry record.

The actual six shelter exports pass 24 posed-model clearances. Eight ground
model clips contribute 422 integer-frame evaluations. Their full-yaw radius
swept along the authored endpoints clears every emitted nonair node cube,
neighboring mounts, grounded flyers and the public front aisle, with 0.01-node
margin. Fractional interpolation extrema are not proven; perceived animation and
clearance during normal play remain GUI acceptance. No mount mesh, scale or
rideable collision setting was changed.

Every profession has an exterior timber product frame. The shared Forge has
separate Weaponsmith and Armorsmith frames; the other six professions have
one each, totaling 48 frames. Each interior retains its profession counter/stand
with a fixed product plaque; Forge retains its authenticated weapon/armor display
sockets. Eight new `grug_decor` product definitions use existing item artwork on
a light backing. They have no editable inventory, pickup, dig, blast drop or
interaction action. Alchemy, Cooking and the six crafting disciplines are all
included; Riding remains its dedicated shelter service.

## Focused checks and visual evidence

All runtime checks used idle-priority LuaJIT. Per the user's Round 11 override,
**no PUC runtime, including a final parity pair, was run**. Plain Lua 5.1 parser,
SETGLOBAL inspection and all five sweeps passed for 18 changed/added Lua files.
No broad historical suite, census, PERF campaign or reference repin was run.

| Requirement | Actual consumer / retained evidence |
| --- | --- |
| Beach profile continuity and unchanged masks | `beach_probe.lua`, `compare_beach.py`, before/after TSVs, comparison JSON |
| Real clearing of stone/soil/ore | `beach_writer.lua`, `beach-writer.log` |
| Deterministic diagonal/tie behavior and call bound | `coast_fixture.lua`, `final-focused.log` |
| Six shelters, 48 service plots, protected products/stations | `capital_fixture.lua`, `capital.log` |
| Rotated absolute movement sockets and copies | `socket_fixture.lua`, `final-focused.log` |
| Full posed/moving geometry | B3D input manifest, `clearance.json`, `motion-bounds.json`, `motion-clearance.json` |
| Lua 5.1 static compatibility | `final-static.log` |
| Readable real textures | `evidence/views/`, emitted-view/input bindings |

The native Blender views render actual emitted cells and existing textures.
Three cutaways show Highcourt Riding, Forge and Tailor. The shelter roof alone
is omitted; shop courses y≥4 are omitted. Two closer views show the exterior
product frames. Plain trainer steles are position markers, not NPC artwork;
Forge item cards show the actual item binding, not engine wielditem extrusion.
The renderer corrects the negative-Z face UV order for these new item plaques.
Full roof/cell geometry is checked separately. The renderer reports no unresolved
textures. These are offline diagnostic views, not gameplay screenshots.

Reproduction commands and fixture limits are in `tools/r11_world/README.md`.
Source and output hashes permit review without rerunning the package.

## Review, calibration and next playtest

Implementer: native Astra. Task classification: hard/performance-sensitive
world geometry plus cross-package stable interface. Independent reviewer:
pending coordinator assignment. Critical/High findings and review fix rounds:
pending, not zero. Observed elapsed delivery time: unknown. Integration and GUI
acceptance remain pending.

On the next fresh-world GUI playtest, use the reported seed and inspect both
beach sightlines, the open stable with four visible mounts and ground movement,
and readable exterior/interior profession products. Products must remain
noncollectible and public stations usable. Exercise the capital normally;
there is no extra dedicated gate-opening test request.
