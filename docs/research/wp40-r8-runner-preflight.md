# WP40 R8 headless runner preflight

Status: corrected G2 real-engine pilot accepted; the first combined 10+32 G3
pair failed only at its exact two-hour timeout. The independently reviewed
four-worker replacement completed without timeout but failed closed under its
original native-event policy. Its immutable raw evidence is eligible for the
separately reviewed `recovery_v1` evaluation below. The runner remains a narrow
release smoke, not a replacement for offline R7 evidence, R2/R6 capacity and
supply evidence, or the later visual gates.

## Contract

`tools/wp40/r8/run_sharded.sh` is the sole normal final-G3 entry point. It
starts `run.sh` twice as an internal pair worker: the `feature` worker consumes
the exact committed 10-row `smoke-corpus.tsv` with no native rows, and the
`native` worker consumes the zero-row `empty-feature-corpus.tsv` plus the exact
32-row `native-witness-corpus.tsv`. Each worker owns one forward/reverse pair,
so four fresh worlds run concurrently. `WP40_R8_MODE=pilot` retains the
historical combined three-feature plus one-native-row pair.

The coordinator immediately re-executes itself from an exact commit-derived
input tree, persists that tree below the immutable capture and runs both child
workers plus the final JQ validator from the persisted copy. A live worktree
edit during the multi-hour run therefore cannot change the accepted bytes.
Corpus rows use:

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
the four fresh worlds must report the same actual runtime manifest. The capture
identity also binds
the Flatpak identity, runner/probe bytes, candidate table and both corpora. A
caller revision is resolved once to one full 40-hex commit before any
archive. The before/after Flatpak deployment and version bytes must match, as
must all four engines' in-process identity. It gives the Flatpak only the per-order
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
requests native cave/dungeon generation notifications. Under the approved
`recovery_v1` policy, the native shard requires complete random-walk-cave
begin/end pairs and inspected nearby cave air in each order, equal normalized
event counts/witness totals, all five retained strata and the native gravel
blob. Cave notification positions and local air counts are diagnostic because
they can vary with request order even when the inspected content is equal.
Dungeon evidence has three states: no notification in either order is
`not_observed` and non-blocking; a notification in only one order is blocking;
notifications in both orders require at least one inspected surviving room in
each. The fixed grid does not grow after an unlucky result, and a
`not_observed` receipt must not claim dungeon preservation. Raw server/console logs, a
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
5. Inspect each shard's `comparison.json`, then the coordinator's aggregate or
   recovery `comparison.json`. Require equal central content/param2/light
   feature rows, content-only native census rows, the normalized native-event
   gates above in both native orders, 42 unique IDs across the two shards, and one identical
   exact frozen-corpus ID set, checkout, seed, host/in-process engine identity,
   Lua runtime and production manifest across all four worlds. All four
   positive elapsed/RSS values are mandatory. Keep the master
   `checksums.sha256` and both child captures together; do not combine them
   into a historical T2 artifact or call this result exhaustive.

## Failed-closed G3 recovery

The completed sharded capture
`47be3ce009a333423b161b17e53bd4e24645f07ca0910314b1f249aa63b9b9ae`
remains immutable and formally failed under the policy embedded in candidate
`d20bcf58b751be256e3b96fe14df4b5dc901e6eb`. Recovery does not edit its
`comparison.json`, invent a missing native child manifest or manufacture the
top-level receipts that the coordinator correctly withheld.

`tools/wp40/r8/recover_sharded_g3.sh` is the sole recovery entry point. It
re-executes from an explicitly selected reviewed commit, binds the source to
its 83-file tree SHA-256
`a6e401b3e5987653e738f8ddb1c89b8a4cfd23c10ef15b8d05ade0946085141e`,
reproduces the master and both child capture IDs, verifies every original input
blob and mode against `d20bcf5...`, verifies the feature child checksum set and
four independently recorded raw-event hashes, and checks all four
contemporaneous child before/after Flatpak identities. It then recomputes the
complete semantic comparison from the raw JSONL streams under `recovery_v1`.
No current Flatpak query, engine process, build, Lua runtime or world mutation
is part of recovery.

The new output is a separate immutable recovery directory with a source-tree
checksum inventory, comparison, manifest, compact receipt, captured recovery
inputs and its own checksum set. The original worker status (`feature=0`,
`native=1`) and missing original receipts are explicit required inputs. Any
source mutation, `.partial` file, missing log, nonzero engine/time status,
error scan, incomplete emerge/shutdown population, identity drift, semantic
snapshot mismatch or failed corrected native gate remains blocking.

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
