# WP13 evidence: Gor Drazhak, the orc capital (2026-09-15)

The package is [docs/research/wp13-gor_drazhak.md](../../../../docs/research/wp13-gor_drazhak.md);
this directory is what it is measured on. Every script here is re-runnable from
the repository root and writes the `.txt` beside it.

| Script | Output | What it proves |
| --- | --- | --- |
| `static.sh` | `static.txt` | `luac51 -p` and the SETGLOBAL count on every touched file, the whole `mods` and `tools` trees parsing under plain 5.1, the five plain-5.1 sweeps, and `check_fresh_server.py`. The only sweep hits this package contributes are one `os.exit` in `gor_drazhak_lots.lua` — the standalone-CLI pattern `highcourt_plots.lua`, `capital_plots.lua` and `capital_wall.lua` have carried since the renderer landed, none of them ever loaded by the engine — and one `\|` inside a comment quoting the contract's own race table. |
| `identity.sh` | `identity.txt` | Nothing this lane touched moved a shipped identity: the six start digests and the `0bbf87a7…` hash of the whole start fixture, Highcourt's 376 274 cells, and the four KATs before this one. |
| `final-micro.sh` | `final-micro.txt`, `final-micro/` | Every WP13 fixture in one process under LuaJIT and again under the engine's bundled PUC 5.1 build, with the exact input set hashed before and after, and the two outputs compared byte for byte. |
| `legality.sh` | `legality.txt` | `capital_wall.lua` over the rampart-line dumps of the two gate seeds, and `gor_drazhak_lots.lua` over the whole-envelope terrain grids of three worlds. Takes the dump directory as an argument, because the grid TSVs are 700 kB each and are not committed; `terrain/` carries the probe summaries instead. |
| `surface.sh` | `surface.txt` | THE PLOT GATE: 52 plots × 3 worlds, sampled column by column at their real positions by the engine's own height authority. 156 rows, 0 illegal. |
| `renders.sh` | `renders/*.png` | The capital as BUILT, drawn from the TSVs the probe read back out of the finished map (`renders/tsv/`, seed 531802985935182545) — not from the composition. |

## The engine passes

`gor_drazhak/` carries one probe summary, one NPC log and one error listing per
seed, plus the read-back digests of the core, a district plot, an avenue, a
stretch of rampart and a gate. `timings.txt` is the summary. The three passes
were taken with

```
WP13_CAPITAL_PORT=31402 tools/wp13/run_capital.sh \
    /tmp/grug-w2-gor-full-<seed> gor_drazhak full <seed>
```

on the two gate seeds and the user's world seed.

**Every one of them reports `errors=3` and `run_capital.sh` therefore says
FAILED, and that is not a defect in this capital.** The three lines are one per
wave-2 vendor kind whose entity `grug_traders` has not registered yet
(`vendor_tanner`, `vendor_brewer`, `vendor_armourer`), which is exactly what the
sockets contract's section 8.4 says happens — "an error line at placement and an
empty socket, never a load failure". `gor_drazhak/errors-<seed>.txt` is the
complete list of ERROR and ModError lines in each log, and it is those three and
nothing else. The gate turns green by itself when the NPC vocabulary lane lands
the entities.

## The numbers to look at first

* per-mapchunk steady mean **0.50 – 0.67 s** over the three worlds, against the
  contract's limit of twice the ~0.5 s Dawnmere chunk, and against a
  same-treatment control (Lethariel: a capital WP40 fits, flattens, terraces and
  protects exactly like this one and which has no WP13 blueprints at all) at
  **2.24 – 2.75 s**;
* the roster placed in full on all three: `guards 30/30 flair 207/207 vendor 4/4
  quest 2/2 pending 0 spare 26 residents 207 walkers 31`;
* **no finding from the seam's load-time terrain audit** on any of the three;
* 355 234 cells of the contract's 400 000, against Highcourt's 376 274.
