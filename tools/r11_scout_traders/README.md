# Round 11 Scout trader evidence

`stock_kat.lua` loads the production `grug_traders/stock.lua` module with a
bounded engine fixture. It verifies all six brackets and forty consecutive
hourly rotations per bracket:

- the shared shelf keeps its 13 fixed plus three rotating entries;
- bows participate in the five-family rotation and the Bowyer view contains
  only the current bracket bow when that family is stocked;
- the Tanner view contains exactly the four leather pieces of the current
  grade and therefore does not maintain a second gear catalog;
- the Bowyer General shelf supplies `grug_gear:arrow` exactly once and never
  exposes the obsolete `grug_mobs:arrow` loot bundle.

Run from the repository root with:

```sh
luajit -e 'io.write(dofile("tools/r11_scout_traders/stock_kat.lua")("."))'
```

This is a LuaJIT development fixture. The Round 11 plan does not schedule a
PUC runtime for this isolated lane.

`static.sh` runs the plain-5.1 parser, reports `SETGLOBAL` opcodes and performs
the five required source sweeps. A worktree without its own untracked
`tools/bin` can point it at the integration root's identical compiler with
`GRUG_LUAC51=/path/to/tools/bin/luac51`.
