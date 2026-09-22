# WP39 historical combat fixtures

`projectile_test.lua` and `cast_projectile_test.lua` retain the historical
ballistic/directional projectile contract and are retired as current projectile
acceptance tests by Round 17. Use [the Round 17 fixture](../r17_combat/README.md)
for current homing, no-target/no-payment and lifecycle semantics. Their historical
success reports are not certification of current projectile behavior.

The other files concern separate ray, melee and diagnostic contracts; this note
does not declare those historical fixtures current integration gates.
