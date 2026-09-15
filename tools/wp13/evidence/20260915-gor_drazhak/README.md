# WP13 evidence: Gor Drazhak, the orc capital (2026-09-15)

The package is [docs/research/wp13-gor_drazhak.md](../../../../docs/research/wp13-gor_drazhak.md);
this directory is what it is measured on. Every script here is re-runnable from
the repository root and writes the `.txt` beside it.

**This directory carries the FIX ROUND's numbers.** The first version of the
package was measured on three fixture seeds, an independent review found a
blocker and three should-fixes hiding in the other six, and everything below was
re-taken on the rebased tree (`main` at `c8050057`) over all nine. Section 10 of
the note is the record.

| Script | Output | What it proves |
| --- | --- | --- |
| `nine.sh <dump-prefix>` | `nine.txt`, `nine/` | **THE NINE-SEED SWEEP.** The rampart on nine worlds (dry, step no deeper than a terrace, faces overlapping, gates dry, and the four corners continuous); the 36 district lots and 16 fill lots on nine worlds; and the engine's own load-time terrain audit on nine worlds. Takes the terrain dumps' directory prefix as an argument — they are 700 kB each and are not committed. |
| `static.sh` | `static.txt` | `luac51 -p` and the SETGLOBAL count on every touched file, the whole `mods` and `tools` trees parsing under plain 5.1, the five plain-5.1 sweeps, and `check_fresh_server.py`. The only sweep hits this package contributes are one `os.exit` in each of its two standalone CLIs — the pattern `highcourt_plots.lua`, `capital_plots.lua` and `capital_wall.lua` have carried since the renderer landed, none of them ever loaded by the engine — and one `\|` inside a comment quoting the contract's own race table. |
| `identity.sh` | `identity.txt` | Nothing this lane touched moved a shipped identity: the six start digests and the `0bbf87a7…` hash of the whole start fixture, Highcourt's 376 274 cells, and the four KATs before this one, each compared against the value the SAME KAT produces on an archive of `main`. |
| `final-micro.sh` | `final-micro.txt`, `final-micro/` | Every WP13 fixture in one process under LuaJIT and again under the engine's bundled PUC 5.1 build, with the exact input set hashed before and after, and the two outputs compared byte for byte. |
| `legality.sh <prefix>` | `legality.txt` | Lane D's `capital_wall.lua` over the two gate seeds, and `gor_drazhak_lots.lua` over three. Kept because it is the general predicate and the comparison point; `nine.sh` is the gate. |
| `surface.sh` | `surface.txt` | The plot rules replayed over the committed per-plot surface dumps of the three seeds the probe writes them for. |
| `renders.sh` | `renders/*.png` | The capital as BUILT, drawn from the TSVs the probe read back out of the finished map (`renders/tsv/`, seed 531802985935182545) — not from the composition. |

## The engine passes

`gor_drazhak/` carries one probe summary, one NPC log and one error listing per
seed, plus the read-back digests of the core, a district plot, an avenue, a
stretch of rampart and a gate. `timings.txt` is the first round's summary and
`nine/` the fix round's. The three passes were taken with

```
WP13_CAPITAL_PORT=31402 tools/wp13/run_capital.sh \
    /tmp/grug-w2-gor-full2-<seed> gor_drazhak full <seed>
```

**All three return PASS with `errors=0`.** The first round's three ERROR lines
were the three wave-2 vendor kinds whose entities `grug_traders` had not
registered; Lane N landed them on `main` at `c8050057` and the passes are clean.

## The numbers to look at first

* **the rampart's four corners are continuous on all nine worlds.** The raw
  corner step — what the two runs would compute without the reconciliation of
  `wp13/orc_palisade.lua` section 1b — reaches **four nodes on the user's own
  world seed** through an opening three courses high; reconciled it is **zero**
  everywhere. `nine/rampart-nine-seeds.txt` carries both columns;
* **52 of 52 lots legal on nine worlds**, and **zero `audit_terrain` findings on
  nine worlds** (`nine/lots-nine-seeds.txt`, `nine/audit-nine-seeds.txt`);
* per-mapchunk steady mean **0.611 – 0.710 s** over the three worlds, against
  the contract's limit of twice the ~0.5 s Dawnmere chunk, and against a
  same-treatment control (Lethariel: a capital WP40 fits, flattens, terraces and
  protects exactly like this one and which has no WP13 blueprints at all) at
  **2.17 – 2.43 s**;
* the roster: `guards 30/30 vendor 7/7 quest 2/2 spare 73 residents 160
  walkers 21` on all three, `flair 160/160 pending 0` on the boundary seed and
  `pending 3` / `pending 62` on the other two — pending means "the socket's own
  mapblock was not loaded when its turn came", which the emerge corpus decides
  and the heartbeat retries; nothing was refused on any of the three;
* **160 residents and 21 walkers**, inside the coordinator's 150–170 / ≤25 band
  (Highcourt 144 / 22);
* 369 864 cells of the contract's 400 000, against Highcourt's 376 274.
