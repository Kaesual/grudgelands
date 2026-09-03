# WP40 R8 cold-start replacement micro-KAT evidence

This directory is reserved for the one final LuaJIT/PUC 5.1 parity pair on
the independently reviewed cold-start correction bytes. The pair is not run
until the production and micro-KAT input set is frozen.

`tools/wp40/r8/finalize_cold_start.sh` owns this replacement lane. It stages
the inherited R7 micro-KAT without publishing it, requires byte-identical
pre/post source audits, binds the accepted R8 integration receipt and tracked
engine-pilot checksums, validates every micro artifact, and atomically
publishes the complete `result/` directory without overwrite. This is separate
from the historical R7 root freeze, whose immutable evidence remains intact.
