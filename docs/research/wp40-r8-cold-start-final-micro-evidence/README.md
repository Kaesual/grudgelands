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

The final pair for accepted commit
`f07abf1aecd9830163c36533ecbce16a09c0b58c` is published in `result/`.
LuaJIT and PUC 5.1 produced byte-identical canonical output for all 108 inputs
and all 74 changed production modules. The final-audit SHA-256 is
`79044fd1d7ff9ee5d4327136dfac587c3aa9314ef22f8c89e06919e410cd3ce8`;
the micro receipt SHA-256 is
`40c3280c903afcdde760790b1e6bd4f452dd0fd3784566d235917ce1a2a5a588`.
An independent read-only artifact audit reproduced every binding and returned
ACCEPT with 0 Critical / 0 High / 0 Medium / 0 Low findings.
