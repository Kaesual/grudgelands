# Dur Brannoc: the review round and the rebase onto `7f988a60`

The package was written against `main` at `9e22b0d` and merged after one
independent review and two rebases: first onto `af43f64c` (the round-2 weapon
ladder and the round-2 NPC fixes), then onto `7f988a60` (Highcourt's districts
2–4). Everything in `README.md` was re-run on the final tree; this file is what
changed and what the numbers moved to.

## What the review found

**M1 (must fix): the two spare sockets were not spare.** `citadel_walk_west` and
`citadel_walk_north` were ordinary `idle` sockets with a `walk` TAG and no
`spawn` field — a description, not a contract — and this package's own engine
evidence showed a villager placed on each (`flair 53/53`). They carry
`spawn = false` and no tag now, which is the shape lane 3's spares settled on,
and `dur_brannoc_kat.lua` asserts both halves of the arithmetic: the composition
publishes exactly two spares, only an `idle` socket may be one, and the placed
idle roster is the idle total minus them.

```
dur_brannoc_spares	2	0	53	51
start npcs dwarf dur_brannoc: guards 19/19 flair 51/51 vendor 2/2 quest 1/1 new 3 pending 0 spare 2
```

**S1: `capital_wall.lua` was not modelling the module it checks.** It built the
deck envelope over the run's span alone while `wall.lua` builds it over the span
plus the look-around either side. Three columns of `wall_west` and one of
`wall_north` moved when the window was put back, and with them the corner step:
the honest answer is zero at seven of the eight corners and **one node** where
`wall_north` meets `wall_west`'s turret on the user seed (built decks 104 and
103), which the turret's three-course rampart opening walks. `wall-legality.txt`
and the record's section 3 say so now; the commit message of `124a4051` still
says "zero" and stands as history.

**S2: the KAT's "not on a street" rule did not know about the wall.** It read the
avenues and the ring street only, so a plot pushed against the curtain would have
been caught only by `capital_plots.lua`, which needs two engine scans to run at
all. The curtain runs are in it at `wall.HALF` now.

Six smaller notes are fixed in place: the gate-passage comment said five columns
where `GATE_PASSAGE` makes seven; `M.THICK` was never read and is `M.CURTAIN`,
used; one line was indented with spaces; the record's cell and column counts for
the wall were wrong (147 102 over 2 056 columns, not ~147 000 over 2 084); and
the quest socket now moves to the doorstep and is tagged `door`.

## What the rebase changed

Lane 3 changed the seam under this package in four ways, all adopted:

1. **`r7_runtime.lua` validates the world seed once** and hands every blueprint
   source `{full_seed, raw_sha256}`. Dur Brannoc reads neither — one district, no
   quadrant permutation — but `r7_dur_brannoc_blueprint.lua` refuses a HALF seam
   rather than shrugging at it.
2. **`r7_settlement.audit_terrain` runs at load per capital plot.** It found a
   plot this package's own offline predicate had passed: `forge_copse` at
   (112, −88) sat under a rise of 12 against a clear of 11. The cause was the
   predicate, not the plot — `capital_plots.lua` was reading the top of the
   plot's BOUNDS while the audit reads the airspace the plot really CUT, and a
   grove's authored air reaches y = 24 over its trees while the plot's own clear
   over its two-node margin ring stops at its roof.

   Three things changed out of that one finding, and the order matters.
   `dur_brannoc_district.lua` now cuts the WHOLE plot box to the top of its own
   part rather than to `peak + 2`, so the grove's margin ring is cleared to 24
   like its middle (the copse costs 9 746 cells instead of 7 978, still inside
   the 12 000 a plot may have, and no other plot in the district changes by a
   cell, because no other part reaches above its own roof). `capital_plots.lua`
   reads the composition's published `clear_to` instead of the top of its
   bounds. And the PROBE's own sample was wrong in the same direction: it read
   the rise off the plot's perimeter alone while the audit reads it off the
   perimeter, the two-node margin ring and every other interior column, so both
   seeds were re-scanned with the audit's sample and two plots moved on the
   result — the copse to (112, −92) and the ore yard to (112, 64), which had a
   rise of 12 against a clear of 13 and is now 8. **The load-time audit is clean
   on the final tree.**
3. **`socket_overrides`**, the hook `highcourt_plot.lua` gained, replaces this
   package's own `recast` for the temple's quest socket: it is moved onto the
   doorstep and tagged `door`, exactly as `highcourt_district_lore.lua` does with
   the same generator-owned socket.
4. **Spares carry `spawn = false` and no tag.**

`seam_kat.lua` and `highcourt_timing.lua` changed on main as well; this package's
one-line change to each — take the FIRST capital of the roster, not the last —
merged onto them without conflict and is still there.

## The numbers on the final tree

| | value |
| --- | --- |
| core / largest plot / whole capital | 95 914 of 150 000 · 9 746 of 12 000 · 299 660 of 400 000 |
| sockets | 94 — 53 idle of which 2 spare, so 51 placed |
| engine, seed 531802985935182545 | 0 ERROR, 0 ModError, 0 terrain-audit findings, `guards 19/19 flair 51/51 vendor 2/2 quest 1/1 spare 2` |
| built-geometry digests | avenue, rampart and gate all match the committed values |
| fixtures, LuaJIT vs PUC 5.1 | `dur_brannoc_kat`, `highcourt_kat`, `seam_kat`, `library_kat`, `blueprint_kat`, `settlement_sockets_kat`, `start_npcs_kat`, `integration_fixture` — every pair byte-identical |
| Highcourt and the library, this tree vs `7f988a60` | `highcourt_kat 10767f72…`, `library_kat 104d21df…`, `blueprint_kat 175675a5…` — identical |
| the six starts | identity SHAs unchanged |

| the interpreter pair | `37221ada423b25a03a06851d7532488e5dd59c7b787d1cc5d58429dac22af12b`, both runs |

The per-fixture digests are in `identity.txt`, the interpreter pair in
`final-micro/digests.txt`, the engine pass in `dur_brannoc/`.
