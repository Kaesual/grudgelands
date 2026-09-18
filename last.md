# Lane R7-LVL completion report

## Result

R7.6 now replaces the smoothed single-target difficulty lattice with a
deterministic three-band integer staircase along the authored continent axis.
Accord runs toward +z, Throng toward -z, front zones run toward z = 0, and the
two level-60 summits stay flat. Political zone ownership and all terrain inputs
remain unchanged.

Commits:

- `46a399ed` — implement the axial field, KAT, active tooling and initial pin.
- `ef3e7c5e` — document the R7.6 contract and underground verification.
- `0b4de90a` — restore immutable R2 evidence, strengthen and pin the active
  digest, and make the political/difficulty projection boundary explicit.

The active `difficulty_field_sha256` is
`9d63740d7915d733bfd38aef4f767d5576489be85122a62affad3cad9eafa6f6`.
The earlier R2 artifact remains byte-for-byte historical at
`ba6e684b232e963251c3582e521c46a9364d602256eba9b6115bd0575e4c9c4b`.

## Measured levels

All six starts produced the same public surface-level progression toward their
capital/front:

| Start | 0 m | 101 m | 151 m | 300 m | 500 m | 800 m |
|---|---:|---:|---:|---:|---:|---:|
| Dwarf | 1 | 2 | 3 | 6 | 10 | 15 |
| Human | 1 | 2 | 3 | 6 | 10 | 15 |
| Elf | 1 | 2 | 3 | 6 | 10 | 15 |
| Undead | 1 | 2 | 3 | 6 | 10 | 15 |
| Orc | 1 | 2 | 3 | 6 | 10 | 15 |
| Troll | 1 | 2 | 3 | 6 | 10 | 15 |

The dwarf-column authored progression extents use the documented half-open hub
rule. The exact shared hub row belongs to the outer segment; the first
frontward node starts the named profile's own staircase.

| Zone | Outer edge | Hub | Inner edge | First frontward node |
|---|---:|---:|---:|---:|
| 2 Copperfell Foothills | L10 at z=-2050 | L10 at z=-2050 | L20 at z=-1500 | L11 at z=-2049 |
| 3 Dur Brannoc | L20 at z=-1500 | L20 at z=-1500 | L30 at z=-700 | L20 at z=-1499 |
| 5 Stormvault Heights | L30 at z=-700 | L30 at z=-700 | L40 at z=-250 | L31 at z=-699 |

This projection is intentionally not clipped at political power boundaries.
For example, the dwarf 300 m sample is politically Copperfell but must read
level 6; clipping it to Copperfell's published 11–20 range would contradict
the required 300 m and 500 m acceptance samples.

## Acceptance evidence

- `bash tools/wp11/static.sh` — PASS, including whole-tree Lua parsing,
  fresh-server audit, current R7 authority/consumer/anchor KATs and its dual
  interpreter fixture.
- Changed-file `tools/bin/luac51 -p`, `SETGLOBAL` inspection and all five Lua
  sweeps — PASS. The only operator-pattern hit is the existing comment
  `open envelope is |d| < gate_half`.
- `bash tools/wp40/quality/final_micro.sh
  /tmp/r7-ref/r7-lvl-final-micro-final` — PASS. PUC 5.1 and LuaJIT TSVs are
  byte-identical, both SHA-256
  `521f13c6d01fb8003b33a956f0da00bf5a061e53bf9bdf541a091882c87b225f`;
  all 6,770 bound inputs revalidated after execution.
- The embedded R7.6 KAT covers all 38 zones, every integer step in each authored
  extent, six starts, the 100/150-node safety override, and y=-1 through -1000.
  Its fixture output digest is
  `f4c065c865f2c52d72b3efb64649ce297401aabf4c90d9390a9fa43291d82318`.
- Underground code did not change. The existing
  `min(60,max(1,round_half_away(-3y/50)))` term has exactly three integer
  threshold crossings per complete uncapped 50-node window.
- Baseline versus final terrain TSV: byte-identical, SHA-256
  `6411be74fe6d51a60dd73ad2c6d318e957228546bc01ec3d92b98f963ff25c58`.
  Shore TSV is also byte-identical at
  `b610c272625eb29dbb72cf889b3e5dcb0b47218a4337c4a54fdf5e56ac9dc93e`.
- `PORT=31000 nice -n 19 bash tools/luanti_headless.sh 60` — PASS; the server
  listened on `127.0.0.1:31000`, and `pgrep -af '^luanti.bin'` was empty after
  cleanup.

## Mutation evidence

On the final candidate, the first band edge was shifted from
`scaled < profile.extent` to `scaled < profile.extent + 3`. The LuaJIT KAT
exited 1 with:

`R7 level-band KAT: elandor_hearthpine_vale staircase escaped band 2 at progress 167`

After restoration, `git diff --exit-code` passed and the KAT output was
byte-identical to the pre-mutation result.

## Review and documentation

Independent fresh-context review used GPT-5.6 Sol for this GPT-5.6 Sol
implementation (non-trivial classification; about 12 minutes observed review
time). Initial findings were 0 Critical / 2 High / 1 Medium. One fix round
restored the immutable R2 artifact, strengthened the live digest, and made the
mandated political/difficulty separation explicit. Focused re-review reported
no findings and verdict `MERGE`.

Updated documentation:

- `docs/design/world_zones.md` §§2 and 7.3: axial extent, band split,
  staircase placement, direction, hub tie, digest and civic policy.
- `docs/design/combat_stats.md`: surface rule and verified unchanged depth
  behavior.
- `AGENTS.md`: current R7.6 difficulty seam.
- `README.md`: design tour and current-state summary/date.

## Open items and blockers

None. Spawn tables, rosters, zone shapes, water, routes and POIs were not
changed.

## Runtime test plan

In a fresh Flatpak world, enter one Accord and one Throng start, use the debug
level readout while moving 0/101/151/300/500/800 nodes toward the capital, and
confirm 1/2/3/6/10/15 with mirrored direction. Then cross one ordinary band
edge and one front-zone band edge, verify levels never decrease within the
profile, and confirm capitals still spawn no ambient hostiles.
