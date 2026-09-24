# Round 21 nature implementation

G2, 2026-09-24. Author: native Astra; independent review and integrated final
portable pair remain coordinator-owned. Branch `wp21-nature`, baseline
`fbd23c7b`. No engine, full-world generation, VM owner or seed fleet was run.

## Delivered behavior

- Broad height corners receive one convex 1:2:1 smoothing pass per axis during
  construction. The existing 64-node grid gains a three-cell transition support;
  queries retain four-corner interpolation and do not scan new neighbors.
  Continental profile ranges and broad octaves remain unchanged.
- The existing detail pair becomes periods 128/32, weighted 3/4 and 1/4.
  Lowland detail amplitude changes 6 to 9, rolling hills 9 to 12; other
  amplitudes stay unchanged. No additional octave or cache is introduced.
- Frostbarrow tarns and Moonfall lake have deterministic 48-node-period edge
  variation bounded to eight nodes inward/outward. Membership, claim exclusion,
  spatial candidate bounds, banks and basin depth share this geometry. Relevant
  route/anchor reservation bounding boxes preserve an eight-node safety collar
  and fade variation in over another sixteen nodes. This conservative masking
  deliberately retains more unchanged perimeter near long routes.
- These two ordinary waters shallow to one water node at their rim, then reach
  their existing varied deep bed over sixteen nodes. Civic water and every
  reach named by a hydrology interface retain their outlines and authored joins.
  This is intentionally not a deformation of every river, marsh or city basin.
- Forty-eight-node coast runs blend through sixteen nodes on either side of
  their boundary, meeting at half-weight. The old blend swapped the full
  opposite target at each boundary, explaining a concrete surviving seam class.
  The eighth coast-profile return value is the nearby water level; existing
  consumers of the first seven values and the planner column tuple are unchanged.
- Dry sand follows final height: at most twelve nodes over sea level, four over
  freshwater, further limited to `2 + floor(shore_distance / 2)`. High lateral
  coast blends use stone, including their filler and exposed bank material.
  This preserves low beach bands instead of painting tall blended walls sand.
- Height identity advances to `wp40-height-shore-v6` / height schema v6.
  Fresh-world mode applies; no migration or old-world reshaping.

## Integration boundaries

G3 continues using existing column class/ground/water/exclusion semantics; it
must not reconstruct water geometry. G1 retains the existing grade identities
and priorities. `preparation_source.lua` already reads final heights and water
through the real column tuple; no scheduling change is required. Its eight-node
visible-water envelope remains intentional. Root's real manifest/planner check
also checks the combined projection and preparation envelope. This package's
scalar probe is not a substitute for that integration gate.

## Bounded evidence

`tools/round21/nature_micro.lua` is a portable callable fixture for the exact
production edge, broad smoothing, shallow-bowl, coast-blend and sand-eligibility
helpers. It tests negative coordinates, inward/outward offsets, one-node edge
continuity, convex smoothing, unchanged reserved depths, shared boundary heights
and elevated freshwater material selection. LuaJIT development execution took
less than 0.01 seconds. The final PUC/LuaJIT pair is deliberately not run here.

`tools/round21/nature_columns.lua` constructs the real horizontal and runtime
height authority for exactly seed `7354267267733045968`. It visits 757 bounded
sample positions: 629 lake cross-section positions, seven terrain/report points,
and 121 coastal-grid positions. It does not construct a content roster or VM.
Output: `tools/round21/evidence/nature-columns.log`.

| Run | Wall | User CPU | System CPU | Result |
|---|---:|---:|---:|---|
| Initial scalar probe | 8.87s | 8.76s | 0.08s | Fixture incorrectly assumed every classified reach column still exposes water after functional grading; stopped on nil water. Production construction passed. |
| Corrected bounded probe | 9.15s | 9.05s | 0.07s | Passed; exposed-water predicate corrected. |

A separate existing surface-selector fixture startup failed before sampling because
the isolated worktree has no reference-project checkout (less than 0.01 seconds).
Its low/high beach assertions were updated; the coordinator runs it only as part
of the chosen integrated gate with the read-only primary reference root.

Total measured mapgen CPU: 17.96 seconds; zero 80³ owners. No additional terrain
population was run. After that probe, an output-preserving optimization reuses
one edge offset across a basin's segments and removes unused unsmoothed evidence
rows; root's integrated final check owns verification of those final bytes.

Observed exposed depths: Frostbarrow 1–3; Moonfall 1–10. The respective scans
contain 119 and 104 nonzero offsets; Lethariel and Raincall have zero offsets.
The coast grid exercises 22 low and 50 high sand-eligibility positions. At the
reported X/Z, terrain is y=4; at (-1680,-2920), y=15. These are actual final
heights, not a claim that camera Y=24 was a terrain height.

All seven changed/new Lua files passed the plain-5.1 parser and had no SETGLOBAL
opcodes. All five source sweeps were run on them, including tool Lua explicitly;
the only hit was an existing comment containing `|d|` in `simple_map.lua`.

## User GUI acceptance

Use a fresh world with the reported seed. Compare normal lowland hills and an
ordinary profile transition outside graded city/start grounds; retain the tall
mountain character. Visit Frostbarrow tarns and Moonfall lake for irregular edges
and shallow margins. Check reserved city/waterfall joins, then the coast around
(-1680,24,-2932) for preserved beaches, softer lateral joins and no tall sand
sheets. Aquatic decorations/fish are G3's separate visual acceptance. Visual
quality remains user-run; these scalar checks do not certify the screenshots.
