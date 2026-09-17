# Round 6 balance result

Measured after the Round 6 Lane B formula changes with:
`/usr/bin/luajit tools/r5_progression/ttk_measure.lua . --r6-table`.
TTK uses deterministic non-critical hits, an own-level baseline sword,
Fireball at its server-enforced one-second cast interval, Smite at its
two-second cooldown, and the
elite's 20% damage intake. TTD is time against one normal same-level mob at
one hit per second after the integer player-side mob-pressure fit, but before
dodge, armor, absorb or healing. The accepted KAT tolerance is 10% around the
8–12 second (Priest 12–16 second) normal TTK and 25–30 second TTD bands; elite
TTK must be 3–4 times the corresponding normal row with the same tolerance.
The independent-review fixes moved no row: the benchmark's one-second
Fireball assumption became the production cadence, while removal of the
duplicate ilvl multiplier is neutral for own-level baseline weapons.

| Level | Class | Baseline attack | HP | Mana | Effective hit | Normal TTK (s) | Elite TTK (s) | Raw TTD (s) |
|---:|---|---|---:|---:|---:|---:|---:|---:|
| 1 | Warrior | Sword | 31 | 0 | 3 | 9 | 39 | 31.0 |
| 1 | Mage | Fireball | 23 | 26 | 3 | 9 | 39 | 23.0 |
| 1 | Priest | Smite | 26 | 26 | 5 | 12 | 40 | 26.0 |
| 10 | Warrior | Sword | 163 | 0 | 17 | 8 | 32 | 33.0 |
| 10 | Mage | Fireball | 122 | 136 | 17 | 8 | 32 | 25.0 |
| 10 | Priest | Smite | 136 | 136 | 23 | 12 | 46 | 28.0 |
| 20 | Warrior | Sword | 461 | 0 | 48 | 8 | 31 | 33.0 |
| 20 | Mage | Fireball | 346 | 384 | 48 | 8 | 31 | 25.0 |
| 20 | Priest | Smite | 384 | 384 | 64 | 12 | 46 | 28.0 |
| 40 | Warrior | Sword | 1531 | 0 | 159 | 9 | 31 | 33.0 |
| 40 | Mage | Fireball | 1148 | 1276 | 159 | 9 | 31 | 25.0 |
| 40 | Priest | Smite | 1276 | 1276 | 207 | 14 | 48 | 28.0 |
| 60 | Warrior | Sword | 3235 | 0 | 337 | 8 | 31 | 33.0 |
| 60 | Mage | Fireball | 2426 | 2696 | 337 | 8 | 31 | 25.0 |
| 60 | Priest | Smite | 2696 | 2696 | 438 | 14 | 48 | 28.0 |
