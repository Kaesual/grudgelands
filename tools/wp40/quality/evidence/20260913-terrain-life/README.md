# Terrain-life local evidence

Candidate: WP40 terrain/POI/inland-water polish based on `291faff`.

`terrain_life_fixture.lua` was run under idle-scheduled LuaJIT for seed `0` and
the reported visual-test seed `4655649881628627392`. The `before-*` files use
production files exported byte-for-byte from `291faff`; `after-*` use the
candidate worktree. Every timing covers the same 45,426 x/z queries. Timings
are process CPU seconds from one local run and establish observed cost only,
not a guaranteed performance bound.

On the reported seed, the sum of the 88 ordinary-anchor center-to-old-fitting-
edge discontinuity witnesses fell from 1,075 to 864 nodes. Seed 0 changed from
1,000 to 995. This is a conservative coarse witness: roads or authored relief
may own either sampled endpoint, and it does not claim every footprint has a
smaller value. The actual contract uses the dry building-core median and
bounded minimax fitting in production.

The after samples observe planned-water depths 1..15 and coastal-shelf depths
1..8. Deep ocean and immutable dragon channels remain exactly depth 24 in all
14,525 such columns per seed (see the TSV counts). Construction CPU changed from
5.91 to 6.47 seconds on the reported seed and from 6.25 to 6.72 seconds on seed
0; query CPU was within 0.37..0.48 seconds. These single-run numbers support
only the claim that the implementation reuses existing lattices and remained
in the same measured order of magnitude.

The focused LuaJIT `quality_geometry_fixture.lua` passed on seeds `0` and
`13191094842853985814`; all six capital cores remained flat, their envelopes
retained 20..44 distinct elevations, and the ordinary road probe retained its
one-node range. Static plain-5.1 parsing, `SETGLOBAL` inspection and the five
repository sweeps passed for changed production files. The historical R7
micro-KAT correctly rejected the changed frozen R8 sample at row 1; it is not
rewritten here. The coordinator owns the one final PUC/LuaJIT micro-KAT pair on
the integrated final bytes.
