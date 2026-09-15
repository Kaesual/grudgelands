# WP13 evidence: Gor Drazhak, the orc capital (2026-09-15)

The package is [docs/research/wp13-gor_drazhak.md](../../../../docs/research/wp13-gor_drazhak.md);
this directory is what it is measured on. Every script here is re-runnable from
the repository root and writes the `.txt` beside it.

**This directory carries the SECOND REBASE's numbers** (`main` at `f5583e13` =
Lane N + Lane R + Lane D). Section 11 of the note is that round; section 10 is
the fix round before it.

**The fix round's own framing still applies.** The first version of the
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
| `renders.sh` | `renders/*.png` | The capital as BUILT, drawn from the TSVs the probe read back out of the finished map (`renders/tsv/`, seed 531802985935182545) — not from the composition — plus `plan-whole-capital.png`, the whole 512 envelope on one flat plane through Lane D's generic `dump_capital_plan.lua`, which is the picture to compare one capital's density with another's by. |
| `gates.sh` | `gates.txt`, `gates/` | **THE ROUTE-GATE ACCEPTANCE**, `luajit tools/wp13/route_gates.lua "$PWD" <seed> --strict` on the nine fixture seeds. **Gor Drazhak: zero route faults and zero city faults on all nine.** The tool's own exit status is the whole world's, so this script follows Gor Drazhak's count instead; every fault the sweep reports is Nhal Veyr's north gate. It also prints the worst raw ground step inside this capital's four gates, the ten columns Lane R's §3.1 hands to the capital lane. |

## The engine passes

`gor_drazhak/` carries one probe summary, one NPC log and one error listing per
seed, plus the read-back digests of the core, a district plot, an avenue, a
stretch of rampart and a gate. `timings.txt` is the first round's summary and
`nine/` the fix round's. The second rebase's two passes were taken with

```
WP13_CAPITAL_PORT=31403 WP13_CAPITAL_TIMEOUT=1500 tools/wp13/run_capital.sh \
    /tmp/grug-w2-gor-full3-<seed> gor_drazhak full <seed>
```

on the pilot seed 531802985935182545 and the user's world seed
15912857179583385436, one server at a time. **Both return PASS with
`errors=0`.** The first round's three ERROR lines were the three wave-2 vendor
kinds whose entities `grug_traders` had not registered; Lane N landed them on
`main` at `c8050057` and every pass since is clean.

The fix round's boundary-seed pass (8675309) is **not** kept here: its probe
dumps were labelled with the CANONICAL quadrant assignment against a SEEDED map,
which is the bug Lane D fixed, so the files would read as evidence of district
labels the map never held. Note §11.3 records what that cost and what replaced
it.

## The numbers to look at first

* **the rampart's four corners are continuous on all nine worlds.** The raw
  corner step — what the two runs would compute without the reconciliation of
  `wp13/orc_palisade.lua` section 1b — reaches **four nodes on the user's own
  world seed** through an opening three courses high; reconciled it is **zero**
  everywhere. `nine/rampart-nine-seeds.txt` carries both columns;
* **52 of 52 lots legal on nine worlds**, and **zero `audit_terrain` findings on
  nine worlds** (`nine/lots-nine-seeds.txt`, `nine/audit-nine-seeds.txt`);
* **zero route-gate faults for this capital on all nine seeds**, and the worst
  raw ground step inside a Gor Drazhak gate is 3 (west and east), 2 (north),
  1 (south) — well inside the 12 the tool refuses and the 8 the contract's
  terrace rule implies, so none of the ten columns inside a gate that Lane R's
  §3.1 hands to the capital lane needs terracing here;
* per-mapchunk steady mean **0.473 – 0.640 s** on the two worlds re-run after
  the second rebase, against the contract's limit of twice the ~0.5 s Dawnmere
  chunk, and against a same-treatment control (Lethariel: a capital WP40 fits,
  flattens, terraces and protects exactly like this one and which has no WP13
  blueprints at all) at **2.38 – 2.45 s**;
* the roster: `guards 30/30 vendor 7/7 quest 2/2 spare 73 residents 160
  walkers 21` on both, `flair 160/160 pending 0` on the pilot seed and
  `pending 9` on the user's — pending means "the socket's own mapblock was not
  loaded when its turn came", which the emerge corpus decides and the heartbeat
  retries; nothing was refused;
* **160 residents and 21 walkers**, inside the coordinator's 150–170 / ≤25 band
  (Highcourt 144 / 22);
* 369 864 cells of the contract's 400 000, against Highcourt's 376 274.
