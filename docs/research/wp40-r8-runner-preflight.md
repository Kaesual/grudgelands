# WP40 R8 headless runner preflight

Status: corrected G2 real-engine pilot accepted; the first combined 10+32 G3
pair failed only at its exact two-hour timeout. The user approved the sharded
four-worker correction and a three-hour safety boundary; its exact bytes await
focused independent review. The runner remains a narrow release smoke, not a
replacement for offline R7 evidence, R2/R6 capacity and supply evidence, or
the later visual gates.

## Contract

`tools/wp40/r8/run_sharded.sh` is the sole normal final-G3 entry point. It
starts `run.sh` twice as an internal pair worker: the `feature` worker consumes
the exact committed 10-row `smoke-corpus.tsv` with no native rows, and the
`native` worker consumes the zero-row `empty-feature-corpus.tsv` plus the exact
32-row `native-witness-corpus.tsv`. Each worker owns one forward/reverse pair,
so four fresh worlds run concurrently. `WP40_R8_MODE=pilot` retains the
historical combined three-feature plus one-native-row pair. Corpus rows use:

```text
id<TAB>x<TAB>surface-or-y<TAB>z
```

The coordinates are node coordinates. `surface` resolves to the first node
above the published `grug_zones.terrain_height_at` value for the selected
seed, keeping vegetation and an anchor root in scope at a vertical owner edge;
an integer y stays exact. The probe applies the pinned v7 chunksize-five containing-chunk
formula and rejects duplicate resulting 80-node mapchunks. `forward` preserves
the reviewed TSV order and `reverse` uses its exact reverse. Each order is a
separate fresh world and a separate `LUANTI_USER_PATH`, so the second order
cannot read generated blocks or page state from the first order.

The host runner archives the selected commit into each disposable game path,
adds only the probe mod, pins `mg_name=v7`, `chunksize=5`, `water_level=1`, and
`num_emerge_threads=1`, and refuses to overwrite a result directory whose ID
already exists. It accepts only a seed in the frozen candidate table and binds
the corresponding R7 offline-manifest SHA-256 as provenance. R7's accepted
manifest was mocked-engine evidence and includes content identities, so the
real engine's manifest is recorded rather than falsely required to equal it;
the two fresh worlds must report the same actual runtime manifest. The capture
identity also binds
the Flatpak identity, runner/probe bytes, candidate table and both corpora. A
caller revision is resolved once to one full 40-hex commit before either
archive. The before/after Flatpak deployment and version bytes must match, as
must both engines' in-process identity. It gives the Flatpak only the per-order
temporary root and that order's exact immutable capture-output directory,
where live `.partial` logs and probe events survive an interruption, and
keeps the installed Luanti world and the user's normal XDG paths out of the
run.

Pilot orders are sequential by default. The final coordinator fixes both pair
workers to parallel order execution, distinct port ranges 32001--32002 and
32003--32004, and exactly four Lua engine processes under the workstation-wide
seven-process cap. Engine launches use `chrt --idle 0` and `ionice -c3`.

After every requested mapchunk has emerged, the probe reads all central 80³
feature mapchunks in one common ID order and records content-ID, param2 and
packed-light SHA-256 digests plus the central/emerged bounds. It also retains a canonical
node-name census and day/night-nibble extrema/counts, rejects `ignore`, requires
daylight in surface slices, and checks the exact Highcourt banner, a fixed
8 by 8 channel-water envelope with a 56-source minimum,
and Seed-0 ruby-root expectations. Seven additional deep slices receive a
content-only hash and canonical census. The 25 event-grid chunks are emerged
but not snapshotted, keeping the native-event gate cheap. Emerge action counts
and timings remain
separate per request. The comparison is byte-oriented at the digest row level
and also compares these readable summaries. The packed light array is the
engine's public `VoxelManip:get_light_data()` representation; this runner does
not invent a second day/night API.

Startup events record engine/version, seed, mapgen settings, Lua runtime and
the live `grug_mapgen.wp40` status. The status' `production_enabled` and
`writer_count` fields are the one-writer indicators available without adding a
production writer or a second mapgen authority. A read-only probe callback
requests native cave/dungeon generation notifications. The native shard requires
matched random-walk-cave begin/end counts, inspected nearby cave air, at least
one inspected surviving dungeon room, all five retained strata and the native
gravel blob. The fixed grid does not grow after an unlucky result. Raw
server/console logs, a
targeted error scan, GNU `time -v` walltime/RSS output, probe `/proc` RSS and
the final `register_on_shutdown` event remain separate immutable outputs.

## Preflight before the first real run

1. Select and record the exact candidate commit with `WP40_CHECKOUT_SHA`; do
   not use a dirty worktree as an implicit snapshot. Confirm that the selected
   game commit is the reviewed R7 production tree and that no existing world
   is passed as `--world`.
2. Review the committed 10-row R8 feature corpus and fixed 32-row native
   corpus (or supply replacements before
   freezing the candidate). It covers deep/no-op, ordinary
   inland, a named-zone or logical-biome boundary, coast/shelf/ocean,
   Battlegrounds/route or crossing, a capital/start blend, a structure slice,
   and a resource/stratum case where those coordinates exist in the current
   world contract. Keep it to 10--15 unique canonical mapchunks; this is a
   smoke sample, not a topology population. Seed 0 is the only initially
   automatable release candidate because its exact resource root is accepted;
   Seeds 1 and 42 remain GUI alternatives until each has a reviewed witness.
3. Verify the host prerequisites: `flatpak`, the installed
   `org.luanti.luanti` app, `git`, `jq`, `rg`, `sha256sum`, `tar`, `timeout`,
   `chrt`, `ionice`, `setsid`, and GNU `/usr/bin/time`. The first real run must preserve the raw Flatpak
   version and server logs. Record the actual engine version; the pinned
   source reference is not evidence that the installed runtime matches it.
4. Review the generated config and manifest after the run: v7, chunksize 5,
   water level 1, dungeon limits from the accepted fresh-world manifest and
   exactly one emerge thread must all be realized. A missing `start`, a probe
   `timeout`, cancelled/errored emerge action, nonzero process exit, error-log
   match or unclean shutdown blocks interpretation.
5. Inspect each shard's `comparison.json`, then the coordinator's aggregate
   `comparison.json`. Require equal central content/param2/light feature rows,
   content-only native census rows, canonical native-event evidence in both
   native orders, 42 unique IDs across the two shards, and one identical
   checkout/seed/engine/runtime manifest across all four worlds. Keep the
   master `checksums.sha256` and both child captures together; do not combine
   them into a historical T2 artifact or call this result exhaustive.

## Open bindings and deliberate limits

- The committed R8 corpora are proposed freeze inputs. The coordinator and
  independent reviewer must check its coordinates against the accepted
  named-zone and resource vocabulary before the first engine pilot.
- The runner has no visual export, lighting-convergence phase, database census,
  100-requester trace, multi-emerge diagnostic, or fallback-engine claim.
  Those are separate R8 gates and are intentionally outside this minimal
  runner.
- The probe's one-writer evidence is deliberately indirect: production status
  says one writer is registered and the probe observes generated-callback
  lifecycle. It does not instrument or mutate `grug_mapgen` to count internal
  writes. A future stronger audit must preserve the same single-authority
  boundary rather than adding a competing writer.
- GNU `time` measures the Flatpak launcher; engine process RSS is separately
  captured from `/proc/self/status` by the trusted disposable probe. Neither
  measurement is a cold-cache or 100-player capacity claim.
- Every engine launch owns a new process group and passes Flatpak
  `--die-with-parent`. The host trap terminates wrappers before deleting each
  disposable world, while live engine logs and probe events remain as
  `.partial` files in the exact capture directory if a run is interrupted.
- After all emerge requests finish, the runner reads each complete central
  80³ array in canonical ID order.
  It intentionally does not hash database metadata, timestamps, entities or
  unloaded halo bytes. The central mapchunk row is the determinism unit.
- If R8 changes no production Lua, R7's accepted final production micro-KAT
  pair remains evidence for those unchanged bytes and is not rerun. The
  test-only probe receives the plain-5.1 parser/source gates and executes in
  the real-engine smoke. A production Lua fix receives exactly one replacement
  compact PUC 5.1/LuaJIT pair on its final frozen bytes.

The normal invocations are:

```sh
WP40_R8_MODE=pilot WP40_R8_TIMEOUT=900 WP40_R8_PARALLEL=0 \
  WP40_CHECKOUT_SHA=<frozen-commit> tools/wp40/r8/run.sh
WP40_R8_TIMEOUT=10770 WP40_CHECKOUT_SHA=<frozen-commit> \
  tools/wp40/r8/run_sharded.sh
```

Final workers reject every other timeout, shard, port or order-parallelism
value. The approximately two-hour runtime is an operational target, not a
near-completion kill point: `10770 + 30 = 10800` seconds is the three-hour
hung-process safety stop, while `liquid_update = 10770 + 31 = 10801` remains
one second later. Pilot mode retains its independently reviewed 900-second
per-order budget and may still be run sequentially.
