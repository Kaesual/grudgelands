# Hydrology depth crash reproduction

Engine: local Flatpak Luanti 5.17.0 with LuaJIT. Seed string:
`4074524248646631899`, read from the user's `test_mapgen/map_meta.txt`.
The user log's failing padded emerge extent was
`(-1568,32,-2208)..(-1457,143,-2097)`; its 80-node owner core is
`(-1552,48,-2192)..(-1473,127,-2113)`.

Both runs use the same empty-world request from `(-1632,64,-2272)` to
`(-1473,64,-2113)`, covering the failing owner and three neighboring owners.
`before/` uses production `3c2e173` and reproduces the exact
`classified hydrology profile depth differs` error. `after/` differs only by
`planner.patch`, generates the requested area, reports PASS and shuts down.
The temporary worldmod logs failed completions without throwing a second
error over the original engine exception. It is not shipped in the game.

The game copies live under `/tmp/grug-hydrology-smoke/{before,after}/user`.
For each phase the invocation is:

```sh
flatpak run --filesystem=/tmp/grug-hydrology-smoke   --env=LUANTI_USER_PATH=/tmp/grug-hydrology-smoke/PHASE/user   --command=luanti org.luanti.luanti --server --gameid grudgelands   --world /tmp/grug-hydrology-smoke/PHASE/WORLD   --config /tmp/grug-hydrology-smoke/PHASE/run2.conf   --logfile /tmp/grug-hydrology-smoke/PHASE/engine.log
```

WORLD is `world2` for before and `world` for after. Configs, test code and
planner hashes are archived alongside engine logs. Existing unmatched fuel
recipe warnings are unrelated; the passing run has no ERROR entries.

The final gate artifacts are in `parity/`. Its real-constructor preflight passes;
PUC and LuaJIT outputs are byte-identical (221 lines), SHA-256
`247c0c1183c6f339e3c554d5c309591da71b2e94a331ebcbf0b51f81032aff65`.
Input and output hash files retain their original run paths; archived bytes are
unchanged. `engine-game.sha256` binds the tested unmodified after-game mod files.
