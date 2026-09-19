# WP40 R7 evidence harness

This directory owns the offline R7-D evidence boundary. It does not implement
map generation or duplicate any production placement rule.

## Layers

- `contract.lua` validates the closed `12/8/6` gathering population and the
  normalized integration, Stage-A, Stage-B and pilot receipt schemas. The
  current Stage-B name map contains 88 entries, including six cultural names.
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

## Refreeze of 2026-09-15 (roster, populations, sweep)

The WP13 lanes added and changed production Lua after the R7 source audit was
frozen, so the audit's first assertion failed on today's `main`. The user's
ruling was **refreeze, do not retire**. Every number below was re-derived with
the audit's own derivation and frozen at the derived value; none was hand-
picked.

| Frozen expectation | Before | After | Derivation |
| --- | --- | --- | --- |
| `changed_production_lua.txt` rows, `source_audit.sh` roster assertion and receipt count | 142 (assertion) / 134 (receipt row) | 157 | `{ git diff --name-only --diff-filter=AM d6002a2 -- mods; git ls-files --others --exclude-standard -- mods; } \| sort -u \| rg '[.]lua$'` — the exact pipeline `source_audit.sh` runs, then `cmp` against the frozen roster |
| `deleted_legacy_lua` (assertion and receipt count) | 7 | 12 | `git diff --name-only --diff-filter=D d6002a2 -- mods \| rg '[.]lua$' \| wc -l` |
| micro-KAT input population (`source_audit.sh`, `final_micro.sh`, `micro_kat_cli.lua`) | 108 / 115 / 120 — three different stale values for one set | 187 | `cat tools/wp40/r7/micro_inputs.txt tools/wp40/r7/changed_production_lua.txt \| awk 'NF' \| sort -u \| wc -l` |
| `executed_module_population` / `source/executed_module_count` / `expected_changed_population` / `micro_kat_fixture.lua` default | 74 / 74 / 75 / 77 | 157 | `wc -l < tools/wp40/r7/changed_production_lua.txt` — the roster file is the freeze, these bind to it |

The 15 files the refreeze adds to the roster are round-A `starts_preload.lua`
and `settlement_sockets.lua`, the `grug_visuals` mod, the start NPC/villager
and patrol files, `grug_classes/init.lua`, the `wp13` avenue/capitals/
Highcourt files, `wp40/r7_highcourt_blueprint.lua` and `wp40/simple_map.lua`.
The roster only grew; nothing left it.

Three further repairs in the same commit:

- **The `\bminetest\.` sweep is its own step now** (`run.sh`, `static_gates`).
  The game's default settings file is literally named `minetest.conf`, and
  three `grug_core` comments legitimately name it. The sweep excludes exactly
  that literal instead of the comments being rewritten, and it keeps an
  explicit `rg` status check so a missing/broken sweep cannot report success
  without running. The remaining `io.popen`/`os.execute`/`os.exit` sweep is
  unchanged.
- **`anchor_activation_kat.lua` passes the successor's fourth argument.** The
  2026-09-15 seam generalisation gave `r7_successor.lua` a `roster_keys`
  parameter that it cross-checks against the settlement configs; the KAT still
  called the three-argument form, which failed `run.sh unit` (and therefore
  every mode) on `main`.
- **`quality/final_micro.sh` no longer calls
  `manifest_constructor_kat.lua`.** That KAT loads the deleted
  `wp40/r7_hearthpine.lua` and passes a single `hearthpine_blueprint` identity
  to the manifest. Its property — constructing and authenticating the real
  `r7_manifest` rather than validating a self-built receipt — is now carried by
  `tools/wp13/seam_kat.lua`, which builds the manifest from the roster-derived
  settlement order, so the LuaJIT pre-step runs
  `tools/wp13/final_micro.lua` instead. The superseded KAT is kept, not
  deleted, and carries a header note saying so.

`micro_kat_fixture.lua` was taught the same seam: `r7_runtime.lua` now walks
the WP13 settlement roster at load time, so the fixture stubs
`r7_settlement.lua` with one settlement (roster, `prepare`, `config`,
`less_bytes`), renames the single Hearthpine content channel to the union
`settlement` channel, and publishes the six start identities the round-A start
NPCs derive their race roster from.

**Still open, and deliberately not in this commit:**
`tools/wp40/r7/node_semantics_fixture.lua` cannot resolve the settlement
palette any more. The roster's union palette is 178 node names — 58
`grug_decor`, 34 `stairs`, 7 `doors`, 6 `wool`, 4 `beds`, 4 `xpanes`, 3
`walls` — while the fixture reconstructs semantics from `default`,
`grug_trees`, `grug_materials`, `grug_nodes`, `grug_gathering` and three
hand-listed stair shapes. It therefore fails on `beds:bed_bottom`, which
blocks both `micro_kat.lua` and `runtime_fixture.lua` (and hence the
superseded manifest constructor KAT). Teaching the fixture the newly vendored
mods is the WP40-lane follow-up already recorded in
`docs/research/wp13-hearthpine-library.md`; until it lands,
`tools/wp40/quality/final_micro.sh` stops at that fixture and
`tools/wp13/final_micro.lua` is the working final-byte pair. `run.sh unit` and
`run.sh static` both PASS.
