# Evidence: the streets after playtest 6 (2026-09-16)

The increment record is
[docs/research/wp13-streets-round4.md](../../../../docs/research/wp13-streets-round4.md).
Everything here was taken on branch `wp13-r4-streets`, on `main` at
**`dfb32cd5`** ("Read one Highcourt avenue expectation, the one every capital
runner reads" — the wave-3 merge).

Round 4, Lane G. Three findings from playtest 6, in a fresh world on the user's
own seed `15912857179583385436`:

1. Lethariel's north-east ring corner over the mere — "two street ends meet on
   a bridge over water; the rail of each protrudes into the other street";
2. Lethariel's north-west corner — "two streets overlay each other with a
   2-node offset across the walking direction";
3. Kezamba's north crossing over water — "the side rails leave only a one-node
   gap into the crossing"; wanted: "railings, fences, verge posts and pillars
   end at the crossing square; the plateau square is rail-free towards every
   street that joins it".

## What is here

| File | What it is | How to re-take it |
| --- | --- | --- |
| `measurements/before-*.tsv`, `*.log` | the streets of all six capitals on `main` at `dfb32cd5`, on all nine fixture seeds, with the two new columns | `luajit tools/wp13/street_geometry.lua /path/to/main <seed> out.tsv` |
| `measurements/after-*.tsv`, `*.log` | the same nine seeds on this branch | `luajit tools/wp13/street_geometry.lua . <seed> out.tsv` |
| `walkability/`, `walkability.txt` | **the headline number**: neighbouring road columns more than a node apart, over the whole capital as the seam writes it — six capitals × nine seeds, both trees | `luajit tools/wp13/walkability.lua . <seed>` |
| `walker_ring.lua`, `walker_ring.txt` | goal D: the offline replay of the 80/20 split and `bounded_spots`, which names the composition behind `min_walker_ring=1` in five of the six capitals | `luajit tools/wp13/evidence/20260916-streets-r4/walker_ring.lua .` |
| `kat/*-luajit.txt`, `kat/*-puc51.txt` | every WP13 KAT this lane touches, under both interpreters; each pair is byte-identical | `luajit -e 'io.write(dofile("tools/wp13/<kat>.lua")("."))'` and the same with `tools/bin/lua51` |
| `micro-luajit.tsv`, `micro-puc51.tsv` | the whole WP13 fixture set in one process under each interpreter; the two are byte-identical | `luajit tools/wp13/final_micro.lua . <out> luajit` and `tools/bin/lua51 tools/wp13/final_micro.lua . <out> puc51` |
| `mutation.py`, `mutation.txt` | **this round's KAT proof**: four mutations, one per half of the two rules, each red on the section that owns it | `python3 tools/wp13/evidence/20260916-streets-r4/mutation.py .` |
| `mutation-wave3.txt`, `mutation-review-wave3.txt` | wave 3's eleven mutations, re-run on this tree, all still red | `python3 tools/wp13/evidence/20260916-streets/mutation.py .` and `mutation-review.py` |
| `gates.sh`, `gates.txt` | every road gate of `tools/wp13`, green | `bash tools/wp13/evidence/20260916-streets-r4/gates.sh .` |
| `overlay_bench.lua`, `bench-before.tsv`, `bench-after.tsv` | what the round costs: every street run of every capital over one synthetic terraced surface, timed, on both trees | `luajit .../overlay_bench.lua . after` and the same file pointed at a `main` checkout |
| `engine/<key>-full-<seed>[-x]/` | the engine passes: the runner's stdout, the probe lines, the NPC placement lines and the read-back overlay digests | `WP13_CAPITAL_PORT=31010 tools/wp13/run_capital.sh <out> <key> full <seed>` |
| `refreeze.sh` | what re-froze the built-geometry digests, from those passes and from nothing else | `bash .../refreeze.sh . <engine root>` |
| `street_dump.lua`, `renders.sh`, `renders/` | the three places playtest 6 named, before and after, on the user's own seed | `bash .../renders.sh /path/to/main` |
| `static.sh`, `static.txt` | parser, SETGLOBAL, the five plain-5.1 sweeps and the fresh-server audit | `bash tools/wp13/evidence/20260916-streets-r4/static.sh` |
| `identity.txt` | the six start identities against `main`'s own, and every settlement identity root | see the record's §6 |

## The headline numbers

Six capitals × nine fixture seeds, measured off the cells the overlay writes:

| metric | before (`main` dfb32cd5) | after |
| --- | --- | --- |
| verge cells inside another run's carriageway | 2405..2695 | **0** |
| …of those, rails inside a junction square | 172..236 | **0** |
| unwalkable road pairs, all six capitals | 3..14, all Lethariel's | **0** |
| parallel overlaps in the tree | 20 (14 butt joints + 6 side by side) | **12, all butt joints** |
| lamp standards | 4444 | 4030 (414 stood in another street) |
| worst cross-profile spread / step / junction spread | 0 / 1 / 0 | 0 / 1 / 0 |
| whole street network of all six capitals (bench) | 152.0 ms, 250 240 surface calls | 145.0 ms, 233 433 |

## The renders

| File | What |
| --- | --- |
| `renders/before-lethariel-ring-corner-northeast-1900--1400.png` | the corner the user named: two bridge ends meeting, each one's rail across the other's carriageway |
| `renders/after-lethariel-ring-corner-northeast-1900--1400.png` | the same corner with the verge ending at the joining street and the outer parapet kept |
| `renders/before-lethariel-ring-corner-northwest-1700--1400.png` | the lane/ring overlap: two streets two nodes apart |
| `renders/after-lethariel-ring-corner-northwest-1700--1400.png` | one street: the ring carrying on north as the district lane |
| `renders/before-kezamba-north-crossing-1800-1595.png` | the crossing over water with four rails closing it |
| `renders/after-kezamba-north-crossing-1800-1595.png` | the same crossing open on all four sides |
