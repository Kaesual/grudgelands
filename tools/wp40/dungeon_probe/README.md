# WP40 native-dungeon provenance probe

This disposable probe verifies the engine contract behind the WP40 Section 2.4
Reality Check. Its static audit reads the pinned Luanti 5.17-dev sources and
current dungeon/stratum registrations. The accompanying lattice audit proves
the `chunksize = 5`, `water_level = 1`, and `mgv7_dungeon_ymax = -193`
vertical-separation contract, including both one-mapblock emerge collars.
Its optional runtime half creates a fresh game and world below a validated
`/tmp` directory, gives Flatpak only that directory, uses a temporary
`LUANTI_USER_PATH`, and removes the directory on exit.

Run the pinned-source and plain-Lua-5.1 checks:

```sh
bash tools/wp40/run_dungeon_probe.sh
```

Both modes require `jq`. The runner parses every marked runtime record as
complete JSON and validates its exact schema, scalar types, integer vectors,
central/emerged bounds, event counts, API values, and terminal ordering. It
also constructs and reparses the machine summary with `jq`; malformed or
partially matching text cannot satisfy the gate. Static fixtures prove that a
malformed `BROKEN` record and a dungeon vector missing `z` both fail closed.

Run the confirming installed-host probe:

```sh
WP40_DUNGEON_PROBE_HEADLESS=1 bash tools/wp40/run_dungeon_probe.sh
```

The optional run is fail-closed. It requires the configured engine-version
class (Luanti 5.16.x by default), exactly one main record requesting 81
mapchunks, exactly one completion record reporting all 81, no emerge error,
all four public content/node/param2/emerged-area accessors, all three tested
flag accessors to remain `nil`, and at least one positive dungeon event. The
2026-08-13 exploratory run used Luanti 5.16.1 and seed `40200517` and observed
38 positive callbacks. That count is recorded as a non-portable observation,
not a golden acceptance value; only positivity is invariant. The accepted
manifest-bound run with `mgv7_dungeon_ymax = -193` observed 31 positive
callbacks and is retained under manifest digest
`256d0ff33ce6748b056287d5ca056e95893d313ae7bbca243eda07dd0f33c8c7` for the
same reason.

An accepted host run writes `raw.log`, `summary.json`, and the exact temporary
configuration below `evidence/<manifest-digest>/`. The summary identifies the
committed `git archive` base and the digest of the current working-tree probe
injected after extraction, so an uncommitted probe cannot silently disappear.
Each `raw.log` is retained byte-for-byte. The root `.gitattributes` disables
Git's whitespace diagnostic only for
`tools/wp40/dungeon_probe/evidence/*/raw.log`, so an engine banner cannot make
the commit gate rewrite raw evidence; authored files retain normal checks.
The manifest digest uses canonical labelled content hashes for the game archive
commit, injected probe payload, expected engine-version expression, and exact
configuration bytes; it never hashes a `sha256sum` output containing a file
path. A static reproducibility fixture proves that identical configuration
bytes stored under different paths produce the same digest and that changed
bytes change it.

Disposable worlds and caches remain under the guarded temporary directory and
are deleted on exit. A static-only PASS makes no installed-host claim. Host
evidence corroborates but does not replace the pinned 5.17-dev source audit.
The probe never syncs or modifies the installed Grudgelands game, reference
pins, or a persistent world.
