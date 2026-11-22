# The claim mask's world-folder files

Round 85 (lane MASK; plan rulings 6, 7, 14–16 and 20). The claim mask says
which 80 × 80 map chunks are claim ground for each faction
([housing.md](../design/housing.md) §2); `grug_housing` builds it at every
start from the world plan (`mods/PLAYER/grug_housing/claim_mask.lua`, the
engine glue `mask.lua`) and keeps the claim snapshot and scan cache in the world folder. Round 87
also records the roads in housing areas. This page is the
format for every other reader, a Python tool in particular (the later soft
map reset, [housing rework concept](../planning/housing-rework-concept.md)
Part C).

The files are text lines ending in `\n`, ASCII, and end in one trailer
line `end <sha256>`: the lowercase hex SHA-256 of every byte before that
line. A file whose trailer is missing or whose hash differs is damaged and
is not read.

## grug_claim_mask.txt: the map's snapshot

Written **once per map**: at a start whose map has no snapshot yet (a new
world, or the first start after a map reset), never at a later start. A
snapshot belongs to the map whose seed and map-reset record its header names;
at the first start after a map reset the record differs and the file is
written anew for the new map (nothing else clears it). A damaged snapshot is
written anew too, with a warning in the log. A snapshot that could not be
computed or written is reported as `[GRUG-SEVERE]`; the file stays as it was
(none, or the previous map's), so the next start writes it again, and the
mask itself stays in use.

```
grug_claim_mask_v1
game=0.85.0
seed=3684797457838814663
map_reset=4
mapgen=<sha256>
settings=mg_name:v7;water_level:1;...
interpreter=LuaJIT 2.1.1700008891
noise=<sha256>
native=<sha256>
mask=<sha256>
chunk=80
origin=-32
strip=8
step=4
digest=16
chunks 739
accord -28 -28 06a3645f35e32f31 f4b3307512a3f8bc 3193fea2d4cc58a3 e3b0c44298fc1c14 e14881960950e524
...
end <sha256>
```

The header, one `name=value` line each, in this order:

| Name | Value |
|---|---|
| `game` | `game.conf`'s version of the game that wrote the file |
| `seed` | the world's full seed |
| `map_reset` | the world's map-reset record when the file was written (`grug_core.map_reset.applied`, [upgrade contract](upgrade-contract.md) §3.1) |
| `mapgen`, `settings`, `interpreter` | the world-layout cache's key parts (`grug_mapgen.wp40.world_key`: the digest of the mapgen mod's sources, the v7 settings, the interpreter) |
| `noise`, `native` | `wp40/r7_native.lua`'s `NOISE_DIGEST` (the v7 noise parameters the game pins) and `NATIVE_DIGEST` |
| `mask` | the digest of the mask's own files (the scan cache's `builder` key below) |
| `chunk`, `origin` | the chunk side and its first node: chunk `cx` holds nodes `80 cx − 32 … 80 cx + 47`, the same in z |
| `strip`, `step` | the fingerprints' border strip and lattice step (below) |
| `digest` | the number of hex characters each fingerprint keeps (the first ones of a SHA-256) |

Then `chunks <n>` and `n` rows, one per claim-ground chunk of the mask at
the time of writing, The Accord first, then The Throng, each in row order
(`cz`, then `cx`):

```
<faction> <cx> <cz> <height> <water> <zone> <roads> <places>
```

`faction` is `accord` or `throng`. The five fingerprints are digests, each
over the chunk plus `strip` nodes beyond each of its edges (the area
`80 cx − 32 − strip … 80 cx + 47 + strip`, the same in z), so a change next
to the chunk shows in its row:

| Fingerprint | Digested text (lines joined by `\n`) |
|---|---|
| `height` | the planner's terrain height (`grug_zones.terrain_height_at`, the pure surface, no generated block) at every point of the `step` lattice of the area, starting at its corner, z rows then x |
| `water` | the water class (`grug_zones.water_class_at`) at the same points |
| `zone` | the owning zone's id at the same points, `-` for none |
| `roads` | per road segment whose corridor (half width + 1) comes within reach of the area, in road id and point order: `<road id> <x> <z> <surface y> <x> <z> <surface y>` of its two centreline points, each `%.2f` |
| `places` | first `feature <kind> <id>` (the settlement core or hard footprint the placement check finds within 16 nodes of the area, or `- -`), then sorted: `camp <i> <j>` for every 32 × 32 camp cell meeting the area, `leader <x> <z>`, `place <x> <z>` and `rare <x> <z>` for every leader spot, quest place and rare route point whose 16-node square meets it |

A digest is `sha256(text)` cut to `digest` hex characters. What each
component reads is the mask's own input, so two snapshots that agree on a
chunk's row saw the same world plan there. They compare the world plan, not
generated blocks. The lattice samples one column in sixteen: a change
narrower than `step` nodes can slip between its points.

## grug_claim_ground.txt: the scan cache

A cache, not map state: the mask's expensive step (the column rule on every
column of a chunk, rule 5 of `claim_mask.lua`) depends only on the world
plan and the code, so its answers are kept per chunk and faction. A start
uses the file only when every key line equals its own; any other file is
replaced once the start has scanned. A map reset with the same seed and code
keeps it valid, like the other world-folder caches.

```
grug_claim_ground_v1
seed=<full seed>
mapgen=<sha256>
settings=<v7 settings>
interpreter=<interpreter>
builder=<sha256 over grug_housing/claim_mask.lua, mask.lua, grug_core/zone_authority.lua>
s <cx> <cz> <faction> <code> <cap>
...
end <sha256>
```

`code` is `ok` (every column is the faction's claim ground) or the first
column problem the scan met (`shelf`, `sea`, `enemy`, `low_level`,
`high_level`, `not_home`, `town`, `deep_water`); `cap` is `1` when the chunk
holds a capital-zone column (the capital ring's condition), else `0`. Rows
are sorted by their `cx cz faction` text.

## grug_road_chunks.txt

Round 87 adds a separate road reference. On the first start of a map, housing
records every 80 × 80 chunk where a protected road corridor covers at least one
node column in either faction's housing zones. Zone membership comes from the
same faction and level rules as housing. Other claim exclusions and actual
player occupancy have no effect. The snapshot includes capital streets and trails.
Column tests use the finished polylines, with half width plus the protection margin.

The body starts with `grug_road_chunks_v1`, then `grid 80 -32`, `seed <full seed>`,
`reset <applied reset counter>` and `from <previous counter or ->` on separate
lines. Two sections, `previous <count>` and `current <count>`, each have that
many unique `cx cz` lines in lexical order. The file ends in the same SHA-256
trailer as the claim snapshot. A single atomic write installs both sets.
A restart of the same map reuses that file. At the next reset of the same world
and seed, the old current set becomes the previous set. A missing, damaged or
different-seed reference starts a new history. A failed write is reported and
retried next start. Round 87 ships ordinary live routing and uses the stored
occupancy in the offline road study.

## Sizes and cost

On the production seed (3684797457838814663, the seed fleet's runtime
without the engine, `tools/r85_mask/run.lua`): 739 snapshot rows (about
73 KB), 830 cache rows (about 17 KB). The first start of a world plan scans
the 830 chunks (about 20 s of LuaJIT, about 3.4 µs a column for the zone
and water answers); a later start reads the cache and builds the mask in
about 0.4 s. The snapshot's fingerprints take about 6 s, once per map.
