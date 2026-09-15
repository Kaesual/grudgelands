# Evidence: Dur Brannoc upgraded to the Highcourt standard (WP13 wave 2, lane D)

Everything this package measured, and the scripts that reproduce it. The record
it belongs to is
[docs/research/wp13-dur-brannoc.md](../../../../docs/research/wp13-dur-brannoc.md)
sections 10 to 17; sections 1 to 9 of that file are wave 1 and its evidence is
`tools/wp13/evidence/20260915-dur-brannoc/`.

Written against `main` at `922bfd92`, rebased onto `c8050057` (the wave-2 NPC
vocabulary, which registers the seven wave-2 vendor kinds) for the fix round
that followed the independent review.

| Path | What |
| --- | --- |
| `static.sh` / `static.txt` | parser and SETGLOBAL per changed file and tree-wide, `bash -n` on the changed shell, the five plain-5.1 sweeps scoped and then tree-wide, and `check_fresh_server.py` |
| `identity.sh` | what this package did NOT move: the six start identities, Highcourt's 54, and `library_kat`/`blueprint_kat`/`highcourt_kat`; plus the Dur Brannoc KAT under both interpreters |
| `identity.txt` | that script's output on this tree |
| `mutation.sh` / `mutation.txt` | does the KAT defend what it advertises? One authored feature deleted at a time in a scratch copy of the tree, asserting the KAT turns RED for each -- the test the review used to prove the first version's `mine` rule was satisfied by the plot's own paving |
| `open-capital-digest.sh` / `open-capital-digest.txt` | does `run_capital.sh full` survive a capital with no curtain wall? The runner's own digest loop, cut out of the shipped file with `sed` and run against a synthetic walled log and a synthetic open one |
| `final-micro.sh` / `final-micro/` | the single bounded final-byte process: every WP13 fixture in one interpreter process, once under LuaJIT and once under the engine's bundled PUC 5.1, with the inputs hashed before and after |
| `timing.sh` / `timing.txt` | build time against the contract's section 2.3 budget, three runs per interpreter, with Highcourt's own row on the same tree |
| `lots.sh` / `lots.txt` | the lot predicate over all NINE seeds of `tools/wp13/capital_anchor_fixture.lua`: 36 district lots, 16 fill lots, 52 plots |
| `lots-derive.txt`, `lots-derive-fill.txt` | how the two committed grids were derived, so they are re-derivable rather than remembered |
| `fields/` | the digests and headers of the nine field dumps the predicate ran against; the dumps themselves are a megabyte each and re-derivable in 35 s per seed |
| `engine/<seed>/` | one cold-world engine pass per seed: the probe's own lines, the NPC roster, the error counts, the read-back overlay digests and the harness manifest |
| `engine/edge/` | the emerge-order gate: every capital anchor's root chunk emerged before its support chunk |
| `renders/capital-<seed>.png` | **the whole capital on one plane**, per gate seed, drawn from the composition on flat ground -- the same picture Highcourt's evidence carries, and the one to compare densities with by eye |
| `renders/` | the rest: Dur Brannoc as BUILT, drawn from TSVs the probe read back out of the finished map on the user gate seed |
| `renders.sh` | the script that drew them |
| `files.sha256` / `files.sha256.sh` | the frozen-byte manifest of every input and every piece of evidence above |

## The three seeds

`531802985935182545` and `8675309` are the two gate seeds every WP13 package
uses; `15912857179583385436` is the user's own world seed, which is the seed the
round-1 playtest found a Highcourt plot illegal on and the reason the lot
predicate of this package takes nine worlds rather than two.

## What a reader should look at first

1. `lots.txt` — the 36 + 16 lots and the 52 plots, legal on all nine worlds.
2. `engine/531802985935182545/probe.txt` — the socket inventory (269), the nine
   patrol loops and the per-mapchunk timings.
3. `renders/capital-531802985935182545.png` — the whole capital, beside
   `20260915-highcourt-districts/renders/capital-531802985935182545.png`.
4. `renders/district-ne.png` — a quarter with its lanes, which is the thing this
   package exists for.
5. `timing.txt` — 366 869 cells of 400 000, beside Highcourt's 376 274.
6. `mutation.txt` — the KAT turning red for every feature that is taken away.
