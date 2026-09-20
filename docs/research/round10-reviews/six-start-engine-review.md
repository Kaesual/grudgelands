# Six-start engine evidence review

## Scope and binding

- Frozen production candidate: `2fcda6086cdf7c78c50e0037935b39933dd67e6b`.
- Evidence root: `/tmp/grudgelands-r10-final-engines/six-starts`.
- Reviewed forward/reverse cold generation and disk reload outputs, summaries, errors, exit states, engine versions, environments, invocation records, source/harness hashes, snapshots and the archived launcher.
- Artifact-only review; no Lua or engine process was started.

Every common harness/source hash recorded by the runs matches the corresponding file read directly from candidate `2fcda608`, including `engine_cases.lua`, `run_engine.sh`, the WP40 profile driver, probe, comparison script and both instrumentation patches. The two case-list hashes differ intentionally because one list is forward and one reverse. Their snapshot-manifest digests also differ because ordering is part of those manifests; this is expected and is tested by the identical canonical output below.

The launcher actually named in both invocations, `/tmp/grudgelands-r10/final-six-start-launcher.sh`, is byte-identical to the committed evidence copy `tools/r10_integration/evidence/final-attempt2/six-start-launcher.sh` (SHA-256 `e7c48e56bf39a39d4686137e785e42a7504556bb9970fb8710b864d6520bd28b`). The launcher:

- accepts only a realpath-resolved `/tmp/grudgelands-wp40-profile-run.*/user` tree;
- accepts only realpath-resolved `forward` or `reverse` output beneath the exact final evidence root;
- gives Flatpak filesystem access only to that temporary profile root and selected result directory; and
- redirects cache, data, config and runtime XDG roots into the unique profile tree, with the runtime directory mode set to 0700.

The environment records show distinct temporary forward/reverse profile roots and matching source game, seed, case count and engine configuration. Both runs used Luanti 5.17.0 with LuaJIT 2.1.1784272936.

## Results

All four engine phases have exit status 0 and empty `errors.log` files:

- forward cold;
- forward disk reload;
- reverse cold; and
- reverse disk reload.

Both orderings report the profile runner PASS. Each cold pass executed 92 mapgen callbacks; each disk pass loaded 5,500 blocks with zero mapgen callbacks, demonstrating reload from persisted map data rather than regeneration. Forward and reverse sample digests differ as expected because their case ordering differs, while their canonically ordered outputs are byte-identical:

- forward cold TSV = reverse cold TSV, SHA-256 `23f75bd309696a8cba1c108d36642103bfc332cf7b54277837b09fd78a00c4c7`;
- forward disk TSV = reverse disk TSV, SHA-256 `f3096ac61969849465af150b1c0ca1753448bbcb015afe1e1575e67b9b64b0ce`;
- all four canonical reports yield `27ab0ba785073e61c6a8f83249f5da08e675cdb1066dbe983347063acddcc96f`.

## Verdict

**PASS, source-scoped to frozen candidate `2fcda608`.** The four real-engine phases are error-free, isolated, reload-stable and invariant under forward/reverse case order for the six-start corpus.

This result does not cover a later production candidate. The separately identified capital overlay phase correction changes world-generation bytes and therefore requires its own appropriately scoped replacement evidence; this report must remain attached to `2fcda608` rather than being carried forward by assumption.
