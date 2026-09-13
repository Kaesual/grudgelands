# Terrain-life local evidence

Candidate: WP40 terrain/POI/inland-water polish based on `291faff`.

`terrain_life_fixture.lua` was run under idle-scheduled LuaJIT for seed `0` and
the reported visual-test seed `4655649881628627392`. The `before-*` files use
production files exported from `291faff`, with only the unrelated historical
final-axis failure bypassed so the same instrumentation could complete;
`after-*` use commit `d7207a4`. Every row comes from full instrumented `.new`
construction and the same 45,426 x/z queries. It is distinct from live
`.new_runtime` startup. Timings are process CPU seconds from one local run and
do not establish a chunk-performance guarantee.

Against natural terrain in columns actually owned by each fitting, the sum of
the 88 ordinary-anchor worst cut/fill witnesses fell from 3,682 to 1,335 on the
reported seed and from 3,784 to 1,382 on seed 0. The single worst witness fell
from 146 to 111 and from 164 to 130 respectively. Core and collar displacement
are recorded separately by the production evidence helper.

The after samples observe planned-water depths 1..15 and coastal-shelf depths
1..8. Deep ocean and immutable dragon channels remain exactly depth 24 in all
14,525 such columns per seed (see the TSV counts). Full instrumented
construction measured 146.38 to 172.09 CPU seconds on the reported seed and
151.72 to 153.76 on seed 0; query CPU measured 0.34 to 0.53 seconds.

The checked-runtime LuaJIT `quality_geometry_fixture.lua` passed on eight seeds,
including `0`, the reported seed and `13191094842853985814`; every actual path
axis passed the unchanged final composed one-step scan. All six capital cores
remained flat, their envelopes
retained 20..44 distinct elevations, and the ordinary road probe retained its
one-node range. Static plain-5.1 parsing, `SETGLOBAL` inspection and the five
repository sweeps are owned by the coordinator on the integrated bytes. The R7
micro-KAT expectation now covers the changed terrain sample plus functional
crossing and water-transition tuples. The coordinator owns the one final
PUC/LuaJIT micro-KAT pair on the integrated final bytes.
