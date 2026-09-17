# Round 6 balance baseline

Measured before the Round 6 Lane B formula changes with:
`/usr/bin/luajit tools/r5_progression/ttk_measure.lua . --r6-table`.
TTK uses deterministic non-critical hits, the generated baseline sword,
Fireball at one cast per second, Smite at its two-second cooldown, and the
elite's 20% damage intake. TTD is raw time against one normal same-level mob
at one hit per second, before dodge, armor, absorb or healing.

| Level | Class | Baseline attack | HP | Mana | Effective hit | Normal TTK (s) | Elite TTK (s) | Raw TTD (s) |
|---:|---|---|---:|---:|---:|---:|---:|---:|
| 1 | Warrior | Sword | 30 | 0 | 6 | 5 | 20 | 13.0 |
| 1 | Mage | Fireball | 30 | 30 | 7 | 4 | 16 | 13.0 |
| 1 | Priest | Smite | 30 | 30 | 5 | 12 | 40 | 13.0 |
| 10 | Warrior | Sword | 75 | 0 | 12 | 12 | 46 | 13.6 |
| 10 | Mage | Fireball | 48 | 84 | 13 | 11 | 41 | 8.7 |
| 10 | Priest | Smite | 57 | 66 | 9 | 32 | 118 | 10.4 |
| 20 | Warrior | Sword | 125 | 0 | 29 | 14 | 51 | 12.5 |
| 20 | Mage | Fireball | 68 | 144 | 25 | 16 | 58 | 6.8 |
| 20 | Priest | Smite | 87 | 106 | 17 | 46 | 178 | 8.7 |
| 40 | Warrior | Sword | 225 | 0 | 90 | 15 | 54 | 10.2 |
| 40 | Mage | Fireball | 108 | 264 | 60 | 22 | 80 | 4.9 |
| 40 | Priest | Smite | 147 | 186 | 40 | 64 | 240 | 6.7 |
| 60 | Warrior | Sword | 325 | 0 | 181 | 15 | 57 | 8.6 |
| 60 | Mage | Fireball | 148 | 384 | 108 | 25 | 95 | 3.9 |
| 60 | Priest | Smite | 207 | 266 | 72 | 76 | 284 | 5.4 |
