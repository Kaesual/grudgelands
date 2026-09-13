# Resource-sampler integration evidence

Adoption date: 2026-09-13. See [the integration report](../wp40-resource-sampling-integration.md).

- `engine/` is the complete final headless cold/disk run, with the runner's
  copied-game and instrumentation manifests. `engine-parity.json` compares the
  full digest to archived prototype sampler run 3 and verifies 868 current
  production files against the engine snapshot. The instrumented
  `r7_mapgen.lua` and three injected probe files are intentionally outside
  that direct repository-file comparison.
- `final-micro/` is the one final complete quality PUC/LuaJIT pair and actual
  R7 constructor preflight. Absolute output paths in its original receipts
  refer to `/tmp/grug-sampling-integration-final-micro`; the copied outputs
  have identical bytes. `inputs.sha256` resolves from the repository root.
- `expanded.*` records the LuaJIT-only population and writer/census checks.
- `r7-unit.log` records the current portable R7 unit suite. No historical
  artifact adapter, fleet or supply recertification is claimed.
- `static.log` and `static-check.py` record parsing, SETGLOBAL and five sweeps.
  The script is the exact local command helper; its path remains local.

Output SHA-256 for both 237-line final micro-KAT files:
`78274f7dcf59d3a8f7e221eb705e2a06240ee9d7d697daedb7c6f476e0c48754`.

No PUC population or Rehearsal VM was run. The installed engine uses LuaJIT;
a real fallback-engine GUI/runtime gate remains separate.
