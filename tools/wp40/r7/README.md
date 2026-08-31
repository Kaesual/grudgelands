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

`runtime_adapter.lua` is intentionally absent from this preparatory commit.
The coordinator adds it under this directory only after the final production
R7 session API exists. It must return normalized proof results and may call the
integrated production fixtures; it must not reimplement P9G, R6 projection,
protection or query semantics. Until it exists, integration, pilot and fleet
commands fail closed before any worker starts.

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

`unit` is usable before the production cutover. `static` requires the complete
atomic cutover, and `integration` additionally requires `runtime_adapter.lua`.

The pilot accepts exactly one new path below `/tmp`, measures one
representative seed, writes a canonical projection and stops unconditionally:

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

The fleet hard-caps itself at seven workstation-wide Lua processes, launches
seven idle-priority LuaJIT workers over slots `1-5`, `6-10`, `11-15`, `16-20`,
`21-25`, `26-30` and `31-32`, and gives each worker a private scratch tree and
read-only projection copy. It re-runs the source receipt after the workers and
rejects changed inputs. No PUC runtime is part of this runner; the one final
PUC/LuaJIT micro-KAT pair is a later frozen-byte coordinator gate.

On a successful fleet, the finalizer promotes the artifact, Stage-A aggregate,
Stage-B aggregate, P9G ledger, run receipt, approved pilot projection and
canonical combined log to `docs/research/`. The promotion manifest is written
last and binds every durable file by SHA-256; acceptance evidence is never left
only in `/tmp`.
