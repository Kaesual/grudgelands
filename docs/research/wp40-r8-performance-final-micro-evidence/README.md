# WP40 R8 performance final micro-KAT evidence

The root-level artifacts in this directory are the durable first
final-interpreter pair for the mapgen performance tranche frozen at commit
`f30b3ccac542364d0a78d399d200362a80989da1`.

That candidate was superseded after focused review found a Medium-severity
fail-open constructor-selector fallback. The artifacts remain as an immutable
audit trail but are not the accepted final pair. The corrected replacement
pair is retained in the `replacement/` child directory.

The one authorized final invocation was:

```text
tools/wp40/r8/performance_final_micro.sh \
  docs/research/wp40-r8-performance-final-micro-evidence/receipt.tsv
```

It ran one LuaJIT process and one PUC 5.1 process concurrently at idle
priority. Both processes exited with status zero and produced byte-identical
canonical output over 111 immutable inputs while executing all 15 production
Lua modules changed from baseline `7e9284f`.

- Receipt SHA-256: `e05ca37802485dc5431193bcab39822a55dd62858924ffcfd34ed71b02ae3013`
- Canonical-output SHA-256: `660a89a975980460b734f2ded1cc7e4e3e6004668f77dfb512d30297b03ad17e`
- Internal canonical digest: `2917b083ef423f56654303aa365cea72a8286b5e48d9589c4a73b16c56e6f037`
- LuaJIT log SHA-256: `a1bed3adda3889762663e19d92dccb3d481e1baecd56eec770e1f83acbfeade3`
- PUC 5.1 log SHA-256: `baa7367560e54733997d883b1a5d5cb2b54de675694759bbda08c5671b759764`

The receipt binds the distinct interpreter binaries, every input hash, both
logs, the canonical output and the executed-module roster. In particular, the
output exercises the runtime R6 planner/template constructors and an accepted
P9G write with runtime proof ledgers omitted.
