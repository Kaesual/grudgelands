# Round 18 XP lane report

Date: 2026-09-23
Lane: E — level-up feedback and forgiving XP

## Result

- `grug_xp.set_xp` now clamps all stored XP to the cumulative level-60
  threshold (`348100`) and returns the actual signed change. Invalid and
  non-finite values are rejected without mutating player metadata.
- `/xp give` accepts a grant that reaches or exceeds the cap, discards the
  overflow and reports the amount actually granted. A capped recipient is a
  successful zero-XP grant.
- Each upward level transition sends one level message and one bounded gold
  particle burst, including a grant that crosses several levels. Join-style
  callbacks and downward transitions do neither.
- The ordered level callbacks first recompute final HP stats and fill a living
  character to the final HP maximum, then fill mana to its final maximum and
  refresh the resource HUD once. Rage is unchanged. Dead players remain dead.
- The XP death callback, deduction constant and loss message were removed.
  Other mods continue to own home travel, inventory, death cleanup and
  damage-event equipment wear.

## Development evidence

`tools/r18_xp/micro.lua` loads the real `grug_xp/init.lua`,
`grug_classes/stats.lua` and `grug_abilities/init.lua` modules in one stub
engine environment. It drives the real callback list via `set_xp`, rather than
matching source text. The fixture covers a multi-level transition, HP/mana
fill, unchanged rage, one burst, join-style and downward callbacks, a dead
recipient, death callbacks, shared-setter overflow, the level-60 no-op, the
admin downward API, and `/xp give` reporting/non-finite rejection.

Development invocation:

```sh
luajit -e 'io.write(dofile("tools/r18_xp/micro.lua")("."))'
```

Expected canonical line:

```text
r18_xp\tPASS\thp=full\tmana=full\trage=unchanged\tburst=once\tcap=348100\tdeath=preserved
```

The lane ran LuaJIT development execution only. The coordinator owns the one
final PUC 5.1/LuaJIT micro-KAT pair on integrated frozen bytes.

## Limits

The fixture is a bounded standalone engine stub, so it does not render the
particle effect or verify Flatpak client presentation. Runtime acceptance
should confirm that one short gold burst appears around a living player after
both a single-level and a multi-level grant, and that the resulting resource
bars show the final maxima.
