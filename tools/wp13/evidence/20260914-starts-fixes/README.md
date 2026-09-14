# WP13 starts: the combined review-fix round — `wp13-starts`

One fix round for the four parallel start lanes' reviews, plus the two
cross-cutting findings those reviews raised against the shared library, plus
the KAT rules the reviews asked for. Everything here is measured on the
frozen bytes this round produced.

The integration that merged the four lanes is the previous record,
`tools/wp13/evidence/20260914-starts-integration/`; each lane's own evidence
is untouched under `tools/wp13/evidence/20260914-<key>/`.

## Per start

| Start | Race | Anchor | Dump SHA before | Dump SHA after | Identity SHA |
| --- | --- | --- | --- | --- | --- |
| Hearthpine | dwarf | 1 | `760e0664…8ec9` | `760e0664…8ec9` | `e07ac54bec01e662…` |
| Dawnmere | human | 2 | `3bba042d…c832` | `24292831…6896` | `5ceef4b8bee3f9d2…` |
| Silverleaf | elf | 3 | `081bded8…0b5b` | `4935b1de…f596` | `2a2da4003b23d55c…` |
| Stillgrave | undead | 4 | `7dd3dbbd…c3ff` | `eeda9dbf…df2b` | `a0f41a3b806f4075…` |
| Sunscar | orc | 5 | `14bbca78…5f6b` | `46aa73df…b324` | `3130d8526cbeb0bb…` |
| Kapok | troll | 6 | `a73e0ede…a9c8` | `35a2597a…b0c8` | `651193c7ffa57c66…` |

Full digests in `dumps.txt`; reproduce with `dump.sh`. **Hearthpine did not
move**, which is the constraint this round was held to: its identity is part
of the frozen R7 mapgen manifest and of every piece of engine evidence
recorded since the first increment.

Composed integration row: `composed/6/168` — six starts, 168 names in the one
shared opcode-37 settlement palette.

## What changed, and what now guards it

### Cross-cutting (all four reviews)

| Finding | Change | Assertion that guards it |
| --- | --- | --- |
| `dressing.undergrowth` picked cells with `(7x + 11z) % density` and chose the plant with `(x + z) % 4`; `7x + 11z` IS `3(x + z)` modulo 4, so at density 4 one plant never appeared and Dawnmere's green was a carpet of one bush | both tests read different offsets into the new `parts.position_hash` (two LCG rounds lifted out of `sunscar.lua`) | `library_kat` §8c: where a race binds its two ground-cover roles to different nodes, the settlement must show both, counted per start |
| Hearthpine cannot be re-picked | the old selector survives as `dressing.vale_undergrowth`, called from exactly one place | `library_kat` §7c reads the wp13 sources and asserts one caller, `hearthpine` |
| the compositions sorted their palettes with `<`, which is `strcoll` | all six sort with the new `parts.less_bytes` | `library_kat` §7b runs it and `r7_settlement.less_bytes` over 21 names / 441 pairs chosen to separate the two rules if they drift |
| `library_kat` §8b matched emitted names against EVERY race's `window` role, and two races bind `xpanes:pane_flat` | the roster rows carry `race`; the question is asked of the start's own palette | the roster field is validated by `r7_settlement.config`'s `PROFILE_FIELDS` |

### Stillgrave Hollow (1 High, 1 Medium, 2 Low)

| Finding | Change | Assertion |
| --- | --- | --- |
| **H1** six of ten burial-ground wall runs silently skipped: the runs share their corners and each was tested with `free_area` over its whole extent | a run tests only the cells it writes, accepts a cell already carrying this palette's low wall, and is fatal on anything else | the composition asserts 164 wall cells; `blueprint_kat` holds the whole low-wall population at 418 |
| **M2** three route lamps silently dropped (the stall's roof oversailed one, a crate stood on one, one was authored inside the sunken ruin's footprint) | both lighting passes are fatal; the stall moved two nodes east, the crate one west, the third lamp to (17, 34) | the composition asserts 41 lamps |
| **M3** `room.ruin` switched off two invariants on an unchecked flag | a ruin must have no door landmark in it, be nobody's destination, be unlit, and really have a column open to the sky | `blueprint_kat`, per room |
| **L8** `railing` was `grug_decor:darkage_iron_bars`, a `glasslike` FULL cube | `default:fence_junglewood`, the Hollow's own fence timber | 44 palette entries incl. air (43 non-air), not 45 |
| **L7** the note quoted `blight_flora`'s return as the pad's flora | 359 bone piles, 612 dead shrubs | `library_kat` `ground_cover` row |

### Silverleaf Glade (1 High, 1 Medium, 4 Low)

| Finding | Change | Assertion |
| --- | --- | --- |
| **H1** the terrace podium stopped at `plot.z + spec.d - 1` while the apron and railing reach `plot.z + spec.d`: 18 apron cells and the rail on them hung a storey up | the podium reaches the same node the things on it do | `blueprint_kat`: every cell of a start's `paved` family rests on a non-air cell; a start declaring raised floors declares the exact count (Kapok, 912), every other start allows none |
| — the review also asked for a generic neighbour rule | `library_kat` §11: every BUILDING cell touches another across a face or a vertical diagonal | it found the four-course belfry's bell hanging in mid air; trees, wallmounted nodes and sprites are exempt, each for a reason at the site |
| **M1/L1** the columnar crown carried a parity notch that left 868 leaves with nothing on any face, and its top leaf was one course short | the crown is `aspen_tree.mts`'s, course for course, with the top leaf two above the last log | `library_kat` §11 (leaves are exempt there, but the crown is now solid anyway) and `blueprint_kat`'s elf tree rule at `high = 2` |
| **L3** `light_support = "self"` skipped the floating-light check entirely | a self-carrying lamp is checked against all six faces | `blueprint_kat` |
| **L2/L4** the header comment and contract §4's elf column described a palette that never shipped | both corrected, with the four reasons the registry forced each change | — |

### Sunscar Camp (2 Medium, 8 Low)

| Finding | Change | Assertion |
| --- | --- | --- |
| **M2** an eight-course mesa filling the north-east corner out to the pad edge, where `world_zones.md` §8.4 gives open savanna with small rock masks | a three-course outcrop, nothing closer than four nodes to the edge, six staggered slabs: 1,323 cells where there were 2,626 | the `outcrop_cells` landmark |
| **M1** the WP40 R7 changed-production Lua roster had not been told about the four lanes | 134 → 142, derived the way `source_audit.sh` derives it | `static.sh` re-derives and compares |
| **L1** `merlon_cells` published the parapet's whole ring cell count, before the roof cuts | `parapet` collects cap positions; the composition counts the caps still standing: 150 | the landmark |
| **L2** stone points on timber stakes | new optional role `stake_cap` = `stairs:stair_outer_acacia_wood` | the palette role check |
| **L3** seven columns of the armoury roofed only by a `walls:` nodebox | the wing's west ring is cut like the main one and the deck laid across | — |
| **L4** `dressing.standard`'s `lights` parameter was dead | removed | — |
| **L5** the control-owner loop never ran once the roster reached six starts | two controls added outright and counted in the bound | `engine_cases` |
| **L6** three node-shape claims for nodes nothing emits | removed from `PARAM2_KIND`, `FULL_SOLID` and the tile overrides | — |
| **L7/L8** the owner-count comment and the `main_street` extent test | comment corrected; the street check is anchored to the pad (`min.x == -2`, `max.x == 2`, one end of z at the origin) | `blueprint_kat` |

### Kapok Cradle (1 High, 1 Medium, 3 Low)

| Finding | Change | Assertion |
| --- | --- | --- |
| **H1** `lantern` was bound to `grug_decor:xdecor_lantern`, `group:attached_node = 3` = *floor*; all sixteen hang under decks and the engine would have dropped every one | rebound to `grug_decor:xdecor_lantern_hanging`, rating 4 = ceiling (`reference_projects/luanti/builtin/game/falling.lua:391-399`); three comments corrected | `blueprint_kat`'s `"ceiling"` prop mode, population 16 |
| **M1** the bridge soffit left one node of headroom over a 1.8-node player | `DECK` 3 → 4 | the route walk in `blueprint_kat` |
| **L1** `parts.pane`/`pane_base` keyed on the `xpanes:` prefix, a third answer to a question `library_kat` asks with `group:pane` | `parts` carries a written-out `PANE_NAMES` set | `library_kat` §7a: the set agrees with `group:pane` for all 779 registered nodes |
| **L3** prop clearance tested 4 courses while a totem is 7 or 8 | `open_air` takes the real height; both totem calls pass it | the fatal placement path |
| **L5** the cauldron "fires" | recorded as cold geometry in the note: this game ships no fire mod | — |

## Checks

| Gate | Result |
| --- | --- |
| `tools/bin/luac51 -p` per changed file | PASS, 28 files |
| `tools/bin/luac51 -p` tree-wide | PASS for `mods/*/grug_*` and for `tools` |
| SETGLOBAL | 0 on every changed file |
| Five plain-5.1 sweeps, changed files | zero hits |
| Five plain-5.1 sweeps, `wp13/` + changed `wp40` + `tools/wp13` | only the six pre-existing `os.exit` lines in `tools/wp13/dump_blueprint.lua`, a developer tool that never runs in the engine sandbox |
| `python3 -m py_compile tools/wp13/extract_tiles.py` | PASS |
| `node_tiles.json` parses, regenerated | PASS, 468 nodes |
| WP40 R7 changed-production roster | PASS, 142 files, script expects 142 |
| `tools/check_fresh_server.py` | `Fresh-server source audit: PASS` |
| `library_kat` + `blueprint_kat` + `integration_fixture`, LuaJIT vs PUC 5.1 | byte-identical, `78843a0595977b97…` |
| `atmosphere_kat`, LuaJIT vs PUC 5.1 | `OK` under both, identical apart from the interpreter banner the KAT prints on line 2 |
| `tools/wp13/final_micro.lua` pair | byte-identical, `78843a0595977b975940066f2964c24dcbeafe869367adc1eeff63d4d15d021e` |
| Engine gate, both seeds | see below |

The whole `tools/wp40/r7/source_audit.sh` still cannot pass, for two frozen
expectations that belong to the WP40 lane and not to this one (the
deleted-legacy-Lua population, and the durable micro-KAT binding that pins the
old roster's SHA-256) — `docs/research/wp13-dawnmere-fields.md` records both.
What the review asked for is the changed-production roster step, and `static.sh`
derives and compares exactly that.

## Engine gate

One gate, six starts, two seeds, run sequentially by `engine.sh` on headless
Luanti 5.17.0 through the isolated Flatpak launcher. Each seed is a full
`run_engine.sh` pass: forward and reverse owner order, each with its own cold
world and its own disk-only reload, and `engine_cases.lua` reads the R7
settlement roster, so one run emerges, compares cell by cell and digests all
six starts.

**All eight runs agree on one digest:**
`be65d1d3301ed333fd6546edb5ed216b8e2b67acd6e561fe59996eb89d4f66c7`
(2 seeds x forward/reverse x cold/disk).

| Start | Authored cells | Torches lit | Per-start digest | Fitted y, user seed | Fitted y, boundary seed |
| --- | --- | --- | --- | --- | --- |
| Hearthpine | 61,932 | 74 | `03311c95b8463c42…` | 25 | 16 |
| Dawnmere | 66,361 | 98 | `0b85d19dcf8f0f51…` | 17 | 21 |
| Silverleaf | 71,495 | 113 | `12981b1cb30b158e…` | 21 | 42 |
| Stillgrave | 51,641 | 78 | `13f3cff1f580eb6d…` | 54 | 48 |
| Sunscar | 57,227 | 112 | `15f992a19f7616f7…` | 27 | 46 |
| Kapok | 72,535 | 87 | `e11c30ec9e88b7ce…` | 20 | 17 |

The per-start digests are identical on both seeds, which is the contract: a
blueprint's bytes are the same wherever the terrain puts it, and only the
anchor's fitted y moves. Hearthpine's `03311c95b8463c42…` is the same digest
the first increment recorded.

- **user seed** `531802985935182545`, 44 structure owners, evidence in
  `user-seed/`.
- **boundary seed** `8675309`, 62 structure owners, `filler_boundary=true` —
  this is the seed that puts Stillgrave's fitted surface at y = 48, just above
  the generated owner's ceiling, so filler restoration across an owner floor
  is exercised. Evidence in `boundary-seed/`.

Every run also placed and checked the persistence canary (one deliberate
server-side edit, re-read after the disk reload), walked each start's lit
five-wide main route end to end, proved every interior destination reachable,
and confirmed the three apron soil witnesses outside every blueprint. No
headless server was left behind after either seed; the launcher refuses to
start without an absolute scratch `LUANTI_USER_PATH` and pins every XDG
directory inside it, so nothing touched the personal Flatpak folder the
user's GUI client uses.

## Reproducing

```sh
tools/wp13/evidence/20260914-starts-fixes/static.sh      # parser, SETGLOBAL, sweeps, audits
tools/wp13/evidence/20260914-starts-fixes/kat.sh         # the KAT trio and atmosphere_kat, both interpreters
tools/wp13/evidence/20260914-starts-fixes/dump.sh        # the six dump SHA-256s
tools/wp13/evidence/20260914-starts-fixes/final-micro.sh # the frozen-byte micro-KAT pair
tools/wp13/evidence/20260914-starts-fixes/renders.sh     # overviews and the fixed spot per start
tools/wp13/evidence/20260914-starts-fixes/engine.sh      # the combined six-start engine gate
```

`renders/` holds a `-before.png` beside each `-after.png` for the five spots a
review finding was about: Dawnmere's green, Stillgrave's burial-ground walls,
Silverleaf's terrace back, Sunscar's outcrop and Kapok's bridge span.

## Post-review comment edit (coordinator, 2026-09-14)

After the focused re-review, two comment lines in
`mods/MAPGEN/grug_mapgen/wp13/palette.lua` (the lantern attachment note and
the troll vocabulary note) were corrected. No blueprint bytes changed: the
Kapok dump stays `35a2597a06a7dbd7…` and the final micro pair re-run on the
edited tree reproduces `78843a0595977b97…` under both interpreters. The
`palette.lua` hash in `files.sha256` and both `final-micro/inputs-*.sha256`
lists was updated from `e5b25058857aeb4d…` to `0656926d201da4c9…`; the engine receipts
were not regenerated because they do not read that file.
