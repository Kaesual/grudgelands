# Round 6 start-level probe

Read-only production-zone probe, run with `/usr/bin/luajit` against
`mods/MAPGEN/grug_mapgen/wp40/zones.lua` and
`source/simple_map.lua`. Each non-zero radius reports the minimum and maximum
of the four cardinal samples at that exact distance from the authored start
anchor.

| Start | Position | 0 m | 50 m | 100 m | 150 m |
|---|---:|---:|---:|---:|---:|
| Dwarf | −1800, −2550 | 5 | 5 | 5 | 5–6 |
| Human | 0, −2550 | 5 | 5 | 5–6 | 5–7 |
| Elf | 1800, −2550 | 5 | 5 | 5 | 5–7 |
| Undead | −1800, 2550 | 5 | 5 | 5 | 5 |
| Orc | 0, 2550 | 5 | 5 | 5–6 | 5–7 |
| Troll | 1800, 2550 | 5 | 5 | 5–6 | 5–7 |

The field therefore violates the required level 1–2 inner band at all six
starts. The owning code is the private `surface_level_from_classification`
function in `wp40/zones.lua`, consumed by `session.surface_mob_level_at`;
`grug_core.mob_level_at` only delegates to that authority.
