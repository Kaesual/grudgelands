# Round 10 engine-gate handoff

This directory records the Round 10 additions to the existing WP13 capital
engine probe. The production game is unchanged by this package.

`tools/wp13/run_capital.sh <capital> full <output>` now waits for the normal
five-second settlement placement heartbeat and emits two additional reports:

- `<capital>-services.tsv`: the eight fitted service plots, seven real station
  nodes, eight profession trainers (Cooking included), one Riding trainer,
  four catalog-backed mount displays and three real gear displays;
- `<capital>-precinct.tsv`: actual authored ring-48 cells and passable authored
  gate thresholds at radius 49.

The runner requires the exact service totals and one PASS marker for each new
witness. It retains the prior ignored-node and overlay digest gates and adds
`overlay-delta.tsv`, which records each old/new digest and cell count. A changed
frozen digest still fails until its explicit geometry delta is reviewed.

## Acceptance state

The harness source passed the Lua 5.1 parser, the explicit tool-source global
assignment check, all five Lua compatibility sweeps, Bash syntax validation,
the fresh-server compatibility scan and `git diff --check`. No engine run is
claimed here. Final acceptance remains pending the orchestrator's six frozen
capital `full` runs after the integrated MAP-B source is final. Those runs must
retain their per-run `harness.sha256`, machine reports, probe log, overlay
digests and explicit delta table.

