# WP40 R7 evidence harness

This directory owns the offline R7-D evidence boundary. It does not implement
map generation or duplicate any production placement rule.

## Layers

- `contract.lua` validates the closed `12/8/6` gathering population and the
  normalized integration, Stage-A, Stage-B and pilot receipt schemas.
- `native_inputs_kat.lua` is the engine-free KAT for the six NoiseParams and
  six native ore records. `run.sh` accepts exactly one canonical PASS record
  from it.
- `source_audit.sh` requires six setters, zero Lua biomes/decorations, six
  native ores, exactly one `r7_mapgen.lua` loader/callback pair, one shared VM
  transaction, no WP33 writer and no legacy writer/platform path.
- `integration_adapter.lua` reads the pure gathering catalog and verifies its
  source hashes and defensive-copy behavior. Runtime work delegates to
  `runtime_adapter.lua`.

`runtime_adapter.lua` is the tool-only adapter over the integrated
production-private evidence facade. The integration gate uses the real writer
to capture a complete owner before replay and VM setters, including all seven
private cell fields and the actual run projection. The 32-seed workers use the
bounded affected-cell seven-tuple delta plus the immutable R6 aggregates; they
do not claim 32 full private-buffer or Full-VM executions. The adapter calls
production fixtures and does not reimplement P9G, R6 projection, protection or
query semantics.

The sole mapgen-environment script name expected by the source audit is
`mods/MAPGEN/grug_mapgen/wp40/r7_mapgen.lua`. This makes the one main loader
and one emerge callback mechanically distinguishable.

## Commands

Development-only checks (no PUC runtime):

```sh
bash tools/wp40/r7/run.sh unit
bash tools/wp40/r7/run.sh static
bash tools/wp40/r7/run.sh integration
```

An isolated worktree without the local ignored `tools/bin/luac51` artifact can
point at the already-built parser with `WP40_LUAC51_BIN=/absolute/path/luac51`.

`unit` is usable without an engine process. `static` requires the complete
atomic cutover, and `integration` additionally exercises the production-owned
private evidence seams through the mocked VM.

The pilot accepts exactly one new path below `/tmp`. It concurrently measures
the combined main-plus-access slot 17 and the main-only slot 18, writes a
canonical maximum-worker projection and stops unconditionally:

```sh
bash tools/wp40/r7/run.sh pilot /tmp/wp40-r7-pilot-projection.tsv
```

The fleet is a separate invocation. Both its argument and environment variable
must equal the SHA-256 of the exact approved projection file:

```sh
WP40_R7_APPROVED_PROJECTION_SHA256=<sha256> \
  bash tools/wp40/r7/run.sh fleet \
  /tmp/wp40-r7-pilot-projection.tsv <sha256>
```

The fleet hard-caps itself at seven workstation-wide Lua processes and runs
the closed 4,096-case population: all 32 seeds, each with the same 104 spatial
lattice owners plus 24 fixed risk owners. Seven idle-priority LuaJIT workers
own slots `1-5`, `6-10`, `11-15`, `16-20`, `21-24`, `25-28` and `29-32`, each
with private scratch and a read-only projection copy. Exactly one slot in each
worker range (`1, 6, 11, 17, 22, 27, 32`) additionally runs the complete
458-owner Frontier Access roster. Thus the main lane retains all 32 seeds while
the separately labelled Access ledger owns seven seeds, 3,206 owner cases and
20,518,400 column visits. The finalizer verifies
the exact sample assignment and repeats the merge with reversed worker
descriptors. It re-runs the source receipt after the workers and rejects
changed inputs. This is a stratified release-safety sample, not exhaustive
whole-world density evidence. Exact global density and 10% parity are retained
as advisory results. `sample_column_visit_population` counts every clipped
column visited by the exact owner roster; the separately recorded
`sample_surface_coverage_column_population` counts only columns for which the
production scan emits a zone/logical-biome surface classification (water and
other non-surface columns are intentionally absent from that coverage table).

The unchanged Stage-B v1 field names `normalized_artifact_sha256` and
`accepted_r6_projection_sha256` are compatibility names. In sampled receipts
they bind the normalized and accepted-77 projections of the exact sampled
owners; the immutable accepted R6 artifact SHA-256 remains a separate identity
field. Neither name claims regeneration of the complete R6 artifact.

On a successful fleet, the finalizer promotes the artifact, Stage-A aggregate,
Stage-B aggregate, main P9G ledger, separate Frontier Access ledger, run
receipt, source-audit receipt, final micro-KAT receipt, approved pilot
projection and canonical combined log to `docs/research/`. The promotion
manifest is written last and binds every durable file by SHA-256; acceptance
evidence is never left only in `/tmp`.
