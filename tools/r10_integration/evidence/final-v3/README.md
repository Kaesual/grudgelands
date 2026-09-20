# Round 10 final-v3 evidence archive

This is a byte-preserving archive of the runtime and static evidence produced
from source `8dd1c8e463a13ccc356cdade123875471b398707`. It does not claim final
parity or delivery readiness. Independent overlay attribution remains pending,
and the final compact PUC 5.1/LuaJIT pair must run on the eventual final source.

## Recorded outcomes

- All six capital **engine processes** exited 0 with zero errors and completed
  their requested work. Their outer wrappers each exited 1 because seven
  historical overlay comparisons differed: all six avenues and Highcourt's
  rampart. Those differences are retained, not ignored or accepted here.
- All four six-start phases passed and canonicalized to
  `27ab0ba785073e61c6a8f83249f5da08e675cdb1066dbe983347063acddcc96f`.
- Static evidence covers 185 Lua files. The result records parser/sweeps 0,
  fresh-server 0 and diff-check 2; the independent review explains that the two
  diff hits are preserved documentation/evidence whitespace, not production
  Lua defects.
- The post-phase aggregate LuaJIT run exited 0. It is development evidence,
  not the final cross-interpreter parity pair.

## Layout and identity

- `runtime/capitals/`: complete capital outputs, including raw TSVs, logs,
  harness hashes, overlay differences and wrapper results.
- `runtime/six-starts/`: all four phase outputs, snapshots, environment and
  engine-version records.
- `static/`: the complete final-v3 static output.
- `reviews/`: the independent review and freshly extracted machine tables.
- `launchers/`: the exact three coordinator launchers.
- `post-phase/`: the root-owned aggregate LuaJIT TSV and log.

Launcher SHA-256 identities:

- `run_final_capitals_v3.py`: `af8ea4c226ae924cfb461470a15a3412a4fa84c8cace86f2eac66a6cc75c1ec4`
- `final-six-start-launcher-v3.sh`: `5599135b567e6c183e35d0a3bdd756676ad26998a3809cbed5d3d8d3b74d5f8e`
- `run_final_static_v3.py`: `fbf0e5f812f0d6670b8c6d9be89cfaf2eb83f775ba07a0bcee80e7aaaf1c7c65`

The six-start engine record identifies Luanti 5.17.0 with LuaJIT
2.1.1784272936. Per-run `harness.sha256`, invocation and environment files bind
the production runners and runtime context.

Files larger than 200 KiB are stored as deterministic `gzip -n` streams.
`uncompressed.sha256` names and hashes the logical uncompressed payload;
`archived.sha256` hashes the bytes actually stored. Run `./verify.sh` from this
directory to validate both layers.
