# WP13 playtest round 1: apron vegetation, and the throne that faced the wall

Two items from the user's GUI playtest of 2026-09-15, in one lane because they
share no code: a **terrain** fix around every start and a **one-cell** fix in
Highcourt's king's hall. The same playtest produced other items in other lanes,
which is why this directory is named after its two subjects rather than after
the round.

The whole gate set was run twice against these bytes and agrees with itself:
every engine digest, every cover count and the final-micro pair are identical
between the two runs.

The previous records are `tools/wp13/evidence/20260914-round-b-terrain/` (the
terrain half) and `tools/wp13/evidence/20260915-seam-generalisation/` (the
capital half). Before means `main` at `70702d2`.

## 1. The bare ring around every start

Round B let biome decorations back into the 256-node blend ring and explicitly
left the next lever alone: *"the most visible square around a start is the
treeline on the 148-node protection square … softening that outline is the next
lever if the user still sees an edge."* The user still saw it — an eleven-node
bare ring, the ten-node protection apron plus the pad edge.

**User ruling, 2026-09-15:** hard protection restricts BUILDING, not growing.
Vegetation may grow inside the apron, with a **jagged** inner edge so the
treeline does not read as a square; only the pad (the 128-node build envelope)
and the road surfaces stay clear.

### What the apron was, and what it is

A start's hard protection is one compiled claim exclusion,
`exclude:active:hard:anchor_00N`, a centred half-open 148 × 148 square
(`hard_start_core_v1`). It answered every query, including the `"vegetation"`
purpose round B introduced, which is why the apron measured `0` hosts while the
ring around it measured tens of thousands.

That one shape — and only that one, and only for a `"vegetation"` query — now
steps aside on a column that lies past a **jittered inner boundary**:

- the boundary sits at **`1 + offset(x, z)`** nodes outside the half-open
  128-node build envelope, with `offset` in **0 .. 5**;
- `offset` comes from one **seed-derived value-noise lattice per start**,
  period 16, bilinear with smootherstep, memoised per corner
  (`simple_map.lua`, `apron_offset`);
- excess **0 is refused unconditionally**, so "never into the envelope" is a
  property of the arithmetic and not of the amplitude;
- the amplitude is checked against the apron's own depth at compile time
  (`apron >= START_APRON_AMPLITUDE + 1`, a `fail()` otherwise), so the
  outermost apron ring always hosts and the carve can never reach the envelope
  even if the source moves the widths.

The envelope width is not written down a second time: it is the START anchor
profile's own `fitting_width`, resolved through the hard record's anchor, which
is the same 128 the height fitting keeps flat. No other hard recipe is marked —
the capital square is 532 wide and its own apron rule has not been decided.

**Everything else still answers**, and that is what keeps the roads clear: the
gate road's own `exclude:route:<id>` corridor is a different shape in the same
bucket, so it refuses across the apron exactly as it does along the rest of the
road.

### The jagged edge itself, per ray

`measure/apron_edge.lua` walks one ray per perimeter column of all four sides
(4 × 128 = 512 rays per start) outward from the first column past the envelope,
and records the excess at which the vegetation rule first stops refusing.
`blocked` is a ray that never opens — the gate road's 16-wide claim corridor,
which is 17 columns.

| seed 531802985935182545 | rays | blocked | min | max | e1 | e2 | e3 | e4 | e5 | e6 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Hearthpine `anchor_001` | 512 | 17 | 1 | 5 | 11 | 99 | 202 | 118 | 65 | 0 |
| Dawnmere `anchor_002` | 512 | 17 | 1 | 6 | 18 | 137 | 133 | 144 | 50 | 13 |
| Silverleaf `anchor_003` | 512 | 17 | 1 | 6 | 6 | 51 | 167 | 193 | 70 | 8 |
| Stillgrave `anchor_004` | 512 | 17 | 2 | 6 | 0 | 78 | 97 | 207 | 89 | 24 |
| Sunscar `anchor_005` | 512 | 17 | 1 | 5 | 62 | 168 | 144 | 64 | 57 | 0 |
| Kapok `anchor_006` | 512 | 17 | 1 | 6 | 9 | 146 | 154 | 103 | 68 | 15 |

| seed 8675309 | rays | blocked | min | max | e1 | e2 | e3 | e4 | e5 | e6 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Hearthpine | 512 | 17 | 2 | 6 | 0 | 48 | 121 | 165 | 134 | 27 |
| Dawnmere | 512 | 17 | 1 | 6 | 4 | 35 | 162 | 170 | 123 | 1 |
| Silverleaf | 512 | 17 | 1 | 6 | 8 | 65 | 174 | 136 | 74 | 38 |
| Stillgrave | 512 | 17 | 2 | 6 | 0 | 66 | 190 | 140 | 81 | 18 |
| Sunscar | 512 | 17 | 1 | 6 | 44 | 109 | 90 | 163 | 86 | 3 |
| Kapok | 512 | 17 | 1 | 6 | 9 | 51 | 225 | 106 | 96 | 8 |

Nothing lands at excess 7..10 on either seed, which is the amplitude bound
showing up in the measurement. The two seeds give different outlines for the
same start (Hearthpine 1..5 against 2..6, and different shapes), and a repeat
run on one seed is byte-identical. `measurements/apron_edge-*.tsv` also carries
the raw per-ray profile, so the outline itself can be diffed.

### The two invariants, per column rather than per ray

The same file counts every column of the half-open 148 square:

| | apron columns | open to vegetation | **columns of the 128 envelope open** |
| --- | --- | --- | --- |
| user seed, six starts | 5,520 each | 3,948 … 4,457 | **0** |
| boundary seed, six starts | 5,520 each | 3,862 … 4,180 | **0** |

5,520 is 148² − 128² exactly. Before this round the middle column was 0 on
every start and every seed.

### The bands, compared with round B's own table

`measure/ring_bands.lua` is round B's script unchanged, so the numbers are
directly comparable (its bands are symmetric Chebyshev, which is why the
one-node negative edge of the half-open 148 square shows up in the 74–127 band
rather than in the apron band):

| band, seed 531802985935182545 | columns | veg. excluded before | veg. excluded after | host before | host after |
| --- | --- | --- | --- | --- | --- |
| pad 0–63 | 16,129 | 16,129 | **16,129** | **0** | **0** |
| apron 64–73 | 5,480 | 5,480 | 1,301–1,810 | 0 | 3,670–4,179 |
| ring 74–127 | 43,416 | 1,196–4,521 | 918–4,226 | 42,200–42,221 | 42,495–42,499 |
| outside 128–160 | 38,016 | 550–5,088 | unchanged | unchanged | unchanged |

The pad row is the point: 16,129 of 16,129 columns still excluded, 0 hosts,
before and after, on both seeds.

### The road keeps its shoulder where the new hosts are

`measure/road_shoulder.lua` is round B's script with three rows added per start
at z offsets 65/69/73 — inside the apron, where the gate road crosses it. The
number is the smallest lateral distance from the gate axis at which a
decoration may host:

| | apron 65/69/73 | approach 80/100/120 | ordinary stretch (the crossing pin) |
| --- | --- | --- | --- |
| all six starts, both seeds | **9**, or no host at all on that row | 9 | 9–23 |

Nine is exactly the ±8 clear corridor a primary route's 16-wide claim exclusion
gives. Rows that report no host within 40 nodes are rows whose jitter boundary
lies further out than that particular offset — the jitter, not the road. Every
`approach` and `ordinary` row is **byte-identical** to `main`.

### In the engine

`tools/wp13/run_engine.sh` through the isolated Flatpak launcher, both gate
seeds, forward and reverse owner order, each with its own cold world and its own
disk-only reload: eight runs.

**All eight agree on `206a86a057b0b6ed4cb5ee71df67413e0f40b70f0b486ea3947bbbbb99eac9a6`** —
the digest round A recorded and round B held.

| Start | per-start digest | apron cover, user / boundary | ring cover, user / boundary |
| --- | --- | --- | --- |
| Hearthpine | `03311c95b8463c42…` | 23/588 · 19/588 | 96/1888 · 102/1888 |
| Dawnmere | `19f8c63f3de9dfe0…` | 119/637 · 83/637 | 934/3999 · 599/3999 |
| Silverleaf | `a81a370a26a293f6…` | 24/588 · 27/588 | 97/1888 · 99/1888 |
| Stillgrave | `13f3cff1f580eb6d…` | 10/588 · 7/588 | 33/1676 · 30/1676 |
| Sunscar | `de46c91105d36125…` | 123/637 · 106/637 | 806/3679 · 960/3679 |
| Kapok | `e11c30ec9e88b7ce…` | 21/588 · 22/588 | 100/1676 · 111/1676 |

Every per-start digest is the one round A recorded. **Why they can be:** the
per-start digest in `tools/wp13/engine_cases.lua` is the SHA-256 of
`blueprint.cells` read back out of the finished map — every authored cell's
local x/y/z, node name and param2, minus the one deliberate persistence canary.
It covers the authored blueprint volume and nothing else. The apron, ring and
wild cover counts are separate **fields** on the same log line, never folded
into the digest, which is exactly why round B could move the ring while holding
the digest, and why this round can move the apron the same way.

The apron column moved from round B's `0/588` and `0/637` on every start and
both seeds to 7–123. The ring column moves by a few columns per start (96→96,
935→934, 98→97, 35→33, 823→806, 99→100 on the user seed) because a decoration
whose footprint straddles the 148 boundary is checked over its WHOLE footprint:
some ring candidates that the apron used to refuse now place, and the per-cell
budgets shift with the eligible counts.

No `ERROR` and no `ModError` in any of the eight server logs; the startup
preload reported all six starts ready in each of them (47.6 s cold on the user
seed's forward run, 46.7 s on the boundary seed's). After each seed the process table was checked for a server
naming THIS run's output path — none — and `pgrep -f '^luanti.bin'` was empty at
the end. The process table was NOT compared as a whole and no `luanti.bin` was
killed by name: the user runs a GUI client on the same machine.

## 2. The throne faced the wall

`capitals.king_hall` wrote the **king socket's own facedir** into the seat, so
the chair's back stood between the king and his hall.

Both nodes the `throne` role can bind carry their back on their own **+Z**
side — `grug_decor:xdecor_chair`'s two tall posts and its back panel sit at
pixels z 11..13 of its nodebox, and the degraded binding is a stair-seat whose
raised half is its +Z half — and a facedir node's +Z side looks along
`core.facedir_to_dir(param2)`. A seat that LOOKS at `face` therefore carries
`(face + 2) % 4`, which is what `parts.seat` writes. `king_hall` now names the
direction and does the arithmetic. **One cell moved in the whole hall**
(`renders/tsv/before-after.diff`):

```
15	6	24	grug_decor:xdecor_chair	2      ->      0
```

`tools/wp13/highcourt_kat.lua` now asserts it, from its own direction model
rather than from the arithmetic under test: the seat's look direction is the
opposite of its +Z side, it must equal the king socket's own facing, and that
shared direction must be `-z`, the great door. New row
`highcourt_throne 0 2 0,-1 great_door`. Putting the rejected literal back fails
the fixture.

### The renderer could not show it

`render_blueprint.py` drew every `nodebox` — the chair included — as one generic
inset box, so the review loop's own pictures were blind to the thing the user
saw from the ground. It now knows a `chair` shape (seat plus back, turned with
the facedir) and `extract_tiles.py` classifies the chair as one, so a
regenerated `node_tiles.json` keeps it. `renders/`:

| File | What it shows |
| --- | --- |
| `throne-orientation-reference.png` | a chair at param2 0 with a GOLD block at +z and an OBSIDIAN block at +x, so the view's axes are readable off the picture itself — the back sits on the gold side |
| `king_hall-throne-before.png` | the dais with the rejected facedir: the back between the king and his hall |
| `king_hall-throne-after.png` | the same cells fixed: the back against the masonry screen, the seat looking down the carpet |
| `king_hall-dais-after.png` | the dais in context |

### What moved

Highcourt's **core identity SHA-256**, and with it the settlement-level one,
because a blueprint identity covers every cell's param2:
`90eae871e24a12472287cf875a67b3cd344d094ec5393dd594e3512748ab26bc` →
`187f79e0ba52103818eba53f7ed9c3beadc631682648918301287fa4a7200499`.

Unchanged: the population (101,831 cells in the core, 169,150 in the
settlement), all nine district plot SHAs, the avenue overlay SHA
`99a634004c395a50…` and all six START blueprint SHAs.

`tools/wp13/run_highcourt.sh`, one full pass, seed 531802985935182545:
`exit=0 errors=0 complete=1`, and the built-avenue digest re-measured to the
committed `9d6f0167f043f8993edef2a44b60afd37a530e07691ccff9c600b37bd93640a2`.
That gate hashes the road as read back out of the finished map, which no chair
touches — and no start apron either, since the carve is marked on
`hard_start_core_v1` only.

## Checks

| Gate | Result |
| --- | --- |
| `tools/bin/luac51 -p`, changed files | PASS, 8 files |
| `tools/bin/luac51 -p`, tree-wide | PASS, 486 files |
| SETGLOBAL, changed files | 0 on every one |
| Five plain-5.1 sweeps, changed files | zero hits |
| Five sweeps, `mods/*/grug_*` | only the three pre-existing `minetest.conf` comment mentions in `grug_core` |
| `tools/check_fresh_server.py` | `Fresh-server source audit: PASS` |
| `tools/wp40/r7/run.sh unit` | PASS |
| `tools/wp40/r7/run.sh static` | PASS, `changed_production_lua` 157 (roster NOT edited: all four production files are already on it) |
| `tools/wp13/final_micro.lua` pair, LuaJIT vs PUC 5.1 | byte-identical, `fdf1f8669ad139fd…` |
| `tools/wp13/terrain_fixture.lua`, 5 seeds × 6 starts | PASS, **byte-identical to round B** |
| Engine gate, six starts, both seeds | all eight runs agree on `206a86a057b0b6ed…` |
| `tools/wp13/run_highcourt.sh`, full, user seed | PASS, 0 errors, avenue digest unchanged |

One note on reproducing `static.sh` from an agent worktree: the WP40 R7
source audit reads two files of the `reference_projects/luanti` submodule
(`builtin/game/item.lua`, `builtin/game/register.lua`), and a worktree
deliberately has no submodules, because they share `.git/modules` with the
user's own checkout and moving a pinned commit as a side effect is
forbidden. The recorded run made those two paths readable and removed them
again afterwards; nothing was checked out and no pinned commit moved. In a
checkout with the submodule present the script needs no such step.

`bash static.sh`, `bash final-micro.sh`, `bash engine.sh`,
`bash renders.sh <absent absolute dir>` and
`bash measure.sh <absent absolute dir> [<other repo root>]` reproduce all of it.

### Which frozen values moved

| Value | Before | After | Why |
| --- | --- | --- | --- |
| WP13 final micro pair | `871f0d2942f9e1dc…` | `fdf1f8669ad139fd…` | the Highcourt core identity below, plus the new `highcourt_throne` row |
| Highcourt core / settlement identity SHA | `90eae871e24a1247…` | `187f79e0ba521038…` | one cell's param2 |
| Six start blueprint identity SHAs | — | unchanged | no blueprint file moved |
| Nine district plot SHAs, avenue overlay SHA | — | unchanged | nothing in them moved |
| Six per-start engine digests, combined | `206a86a057b0b6ed…` | unchanged | the digest covers authored blueprint cells only |
| `run_highcourt.sh` avenue digest | `9d6f0167f043f899…` | unchanged | it hashes the capital's built road; the carve is a start rule |
| `terrain_fixture.lua`, 5 × 6 | — | unchanged | `height.lua` is untouched by this round |
| `library_kat` / `blueprint_kat` / `seam_kat` / sockets / NPC rows | — | unchanged | counts, not param2 digests |
| WP40 R7 `changed_production_lua` | 157 | 157 | all four files were already on the refrozen roster |

`quality_geometry_micro_kat` was not re-run: this round does not touch
`height.lua`, and `terrain_fixture.lua` — which exercises the same fitting and
the round-B jitter witness over 5 seeds × 6 starts — is byte-identical.

### One record correction made here

`docs/research/wp13-seam-generalisation.md` printed the final-micro pair as
`c4a93a7d5ec0f65a…`. That was the seam package's pre-fix-round value; its own
review fix round (`691b0e9`) regenerated the committed
`final-micro/digests.txt` to `871f0d2942f9e1dc…` without updating the prose.
The document now carries the committed value and says why.

## Files

`measure/` holds the three offline measurement scripts and `measurements/`
their output, with `-before.tsv` taken against a `git archive` copy of `main`
at `70702d2`. `user-seed/` and `boundary-seed/` hold the engine evidence,
`highcourt/` the capital pass, `final-micro/` the frozen-byte pair,
`renders/` the throne pictures and `static.txt` the static gates.
`files.sha256` is the frozen-byte manifest, regenerated by `files.sha256.sh`.
