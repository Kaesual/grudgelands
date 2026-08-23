# WP40 T2 pinned PUC conformance core fixtures

This directory contains the deterministic expected bytes for the bounded
Pinned PUC Conformance Core (PCC). `micro-v1.txt` is the five-group semantic
micro-corpus, `source-v1.txt` is the targeted Source checksum parity KAT, and
`optional-load-v1.txt` pins the dual-runtime optional-load result.
The compiler pair, worker pair and seven-seed merge fixtures were captured only
after their complete LuaJIT and PUC runs agreed. The worker fixture separates
canonical stdout from raw runtime telemetry: stdout and the complete TSV are
byte-identical, while the two exactly anchored telemetry lines are retained raw
and compared after removal of only their terminal wall/CPU values. Their
selection and checksums are recorded in `manifest-v1.tsv` and the retained
evidence package.

`merge-v1.txt` replaces only its exactly one leading host-specific interpreter
identity with `WP40 T2 census interpreter: <LuaJIT>`. The runner first proves
that the configured LuaJIT is genuine and resolves to a different executable
from PUC; all remaining report bytes and both merge trees remain exact. This
mechanical normalization and the associated fail-closed checks landed in
implementation commit `ee4478bc4210b0be75661152a9c1f240f53a36ce`
(tree `b91ba958bf7643c6a9c39eea3581a1b56aa7690d`).

The selection is never ad hoc: 27 `seed_corpus.lua` seeds; compiler witnesses
`1959553668008863006` and `2147483648`; worker witnesses `2147483648` and
`16178445837170081103`; the seven `t2_census_worker.lua --kat` seeds; and the
selector endpoints/winners already carried by the retained C1-v3 F2 evidence.
Any later seed, fixture or digest change requires a later owning memo in
`docs/research/wp40-t2-contracts.md`.

The selector carrier is not a new six-candidate PCC run. The completed C1-v3
F2 evidence already parses/ranks the full retained pool, independently
rescores its fixed 20 rows (including candidates 0 and 4095), and compiles
slots 28--31 under PUC. F1 and F2 remain separately named final rounds and are
not duplicated by this fixture directory.
