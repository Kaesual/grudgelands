# WP13 seam generalisation — evidence, 2026-09-15

Record: [`docs/research/wp13-seam-generalisation.md`](../../../../docs/research/wp13-seam-generalisation.md).

| Path | What |
| --- | --- |
| `static.sh` / `static.txt` | `luac51 -p`, SETGLOBAL per touched file and tree-wide, the five plain-5.1 sweeps, the fresh-server audit |
| `final-micro.sh` / `final-micro/` | the one bounded final-byte process: every WP13 fixture under LuaJIT and under PUC 5.1, inputs hashed before and after, the two outputs byte-identical |
| `timing.sh` / `timing.txt` | build time of the capital and of the seam, three runs under each interpreter |
| `engine-user-seed/`, `engine-boundary-seed/` | `tools/wp13/run_engine.sh` over the six starts: forward and reverse owner order, cold world and disk reload, twelve digests identical to round A. The per-world directories are dropped; the `*-cold.tsv` / `*-disk.tsv` lines and `digests.txt` are the evidence |
| `highcourt/probe.txt` | the Highcourt engine pass: per-mapchunk timings by kind, the socket inventory, the dump counts |
| `highcourt/npcs.txt` | every placement line of that boot, six starts and Highcourt |
| `highcourt/harness.sha256` | the probe and runner bytes that pass ran |
| `surface/*.tsv` | the surface under every district plot footprint, both gate seeds, before and after the two plots were moved |
| `renders/*.png` | Highcourt as built in terrain, drawn from the map read-back |
| `renders/tsv/*.tsv` | the read-back dumps themselves, anchor-relative, the renderer's input |
| `files.sha256` / `files.sha256.sh` | the frozen-byte manifest of every input and every artefact |

Reproducing, from the repository root:

```sh
bash tools/wp13/evidence/20260915-seam-generalisation/static.sh
bash tools/wp13/evidence/20260915-seam-generalisation/final-micro.sh
bash tools/wp13/evidence/20260915-seam-generalisation/timing.sh
WP13_SEED=531802985935182545 WP13_PORT_BASE=33000 bash tools/wp13/run_engine.sh \
    /tmp/wp13-seam-user tools/wp13/evidence/20260914-round-a-blueprints/luanti-flatpak-launcher.sh
bash tools/wp13/run_highcourt.sh /tmp/wp13-highcourt full 531802985935182545
```
