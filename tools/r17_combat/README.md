# Round 17 combat regression

Current portable fixture:

```sh
luajit -e 'io.write(dofile("tools/r17_combat/micro.lua")("."))'
```

Root invokes the same returned function in the single final integrated PUC/JIT
pair. The fixture loads the production ray/lock/projectile foundation, mob
formula/verbs, changed actor definitions, Scout and Fireball callbacks. It checks
release obstruction/no aim, target movement beyond range/behind cover, once-only
impact, death/respawn/replacement/teleport/evade cancellation, batch rollback and
cost, actual royal volley and generic actor launch, fixed aura/poison/scorch
scaling, invalid-setting fallback and base/default formula values.

Engine armor/dodge/absorb, inventory durability and actual client visuals remain
owned by their existing production settlement seams; this small fixture does not
claim a native-engine playtest or duplicate their complete historical suites.

## Superseded fixtures

The ballistic assertions in `tools/wp39/projectile_test.lua`,
`tools/wp39/cast_projectile_test.lua` and
`tools/r11_followup/arrow_visual_kat.lua` describe the historical WP39/R11
contract. They are retired as current projectile acceptance oracles: empty aim
no longer launches, terrain only blocks release, and gravity/swept collision no
longer governs targeted flight. Their original bytes remain historical evidence.
The historical `tools/wp11/evidence/20260916-mob-pressure/kat.sh` is not a current
combat runner. Use this fixture for current projectile behavior.

The mount KAT's deleted collision-module dependency has been replaced with the
shared launch ray. Its unrelated old purchase-auto-insertion assertion (line 364)
already conflicts with the shipped Skills catalog; no claim is made that the
entire historical mount suite passes current design.
