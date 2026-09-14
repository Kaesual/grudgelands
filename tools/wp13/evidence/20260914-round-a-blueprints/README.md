# WP13 starts: round A of the user's playtest — the blueprint half

The user walked the six starts in the GUI client and named three things. All
three are the same kind of defect and none of the review rounds could have
found them, because every cell involved is correctly placed, correctly
oriented and correctly supported. What was wrong was the SHAPE of the node —
a bottom slab's surface lies half a node below the top of its own cell — or
what the running world does to a node after the writer has finished.

The previous record is `tools/wp13/evidence/20260914-starts-fixes/`; each
lane's own evidence is untouched under `tools/wp13/evidence/20260914-<key>/`.
Everything here is measured on the frozen bytes this round produced.

## Per start

| Start | Race | Anchor | Dump SHA before | Dump SHA after | Moved |
| --- | --- | --- | --- | --- | --- |
| Hearthpine | dwarf | 1 | `760e0664…8ec9` | `760e0664…8ec9` | no |
| Dawnmere | human | 2 | `24292831…6896` | `40809e86…562b` | tilled fields |
| Silverleaf | elf | 3 | `4935b1de…f596` | `ed280686…204a` | the shrine's bell |
| Stillgrave | undead | 4 | `eeda9dbf…df2b` | `eeda9dbf…df2b` | no |
| Sunscar | orc | 5 | `46aa73df…b324` | `0676ef95…2db6` | decks and wains |
| Kapok | troll | 6 | `35a2597a…b0c8` | `35a2597a…b0c8` | no |

Full digests in `dumps.txt`; reproduce with `dump.sh`. **Hearthpine did not
move**, which is the constraint every round is held to: its identity is part
of the frozen R7 mapgen manifest and of every piece of engine evidence
recorded since the first increment. Stillgrave and Kapok did not move either
— nothing in them is a slab under a load, a floating nodebox or a furrow.

Composed integration row: `composed/6/168` — unchanged. The camp stopped
emitting `grug_decor:cottages_wagon_load` and the hamlet started emitting
`grug_nodes:tilled_soil`, so the one shared opcode-37 settlement palette is
the same size it was.

## The three findings

### 1. Orc parapets: the deck was half a node lower than everything on it

`roofs.raster` caps a flat field with `roof_slab`, and a bottom slab fills the
LOWER half of its cell. `roofs.flat_deck` stands a deck one course above the
wall head, so in Sunscar Camp the deck's walking surface lay at the middle of
its cell while the breastwork ring, the five braziers on the warlord's
fighting top and everything else standing on a deck began at the cell
boundary above it. **296 cells** of it, on every parapeted building in the
camp: the hall, the armoury and its forge wing, the three lodges, the chief's
round lodge and both gate towers.

A deck is walked on and built on, so `flat_deck` marks its field `deck = true`
and the rasteriser caps it with `roof_ridge` — the full cube of the same
desert-stonebrick roof family. `roofs.combine` carries the flag, because
`buildings.build` combines even a single block's field; a combined roof is a
deck only when every part is one, so a deck meeting a pitched block is left
alone rather than thickening a ridge nobody stands on. The deck patch laid
where the forge wing's cut west ring used to be is the same full cube, for the
same reason.

No cell moved and no landmark changed: 150 merlons, 537 berm cells, 1,323 rock
cells, 96 stakes, as before.

| Guarded by | What it says |
| --- | --- |
| `library_kat` §8d | a `group:slab` cell written at an upright facedir may not have a non-air cell above it, in ANY start. The family is read from the real registry (`stairs` puts `slab = 1` in a slab's groups, `stair = 1` in a stair's); a STAIR is outside the rule because its raised half reaches the top of its own cell. Reported per start as `free_slabs`. |
| `library_kat` §8e | every param2 20..23 cell is a `group:slab` or `group:stair` node with `paramtype2 = "facedir"` — `stairs`' `rotate_and_place` is the one placement in this game that writes that axis, and it writes it for nothing else — and meets a non-air cell above it, because meeting what is above is the only reason to flip a slab. Reported as `upside_down`. |
| `parts.Buffer:put` | the construction-time half of §8e, written without a registry: a facedir node may carry only the upright axis or axis 20, and only a `parts.shaped` node — a `stairs:` node or one of the six grug_decor shapes — may be flipped at all. A flipped barrel is refused at construction; `library_kat` §8 proves `parts.shaped` equal to the registry's `group:stair`/`group:slab` for every emitted name, in both directions. |
| no table-top exemption | §8d deliberately has none. A prop on a bottom-slab table floats exactly as a breastwork on a bottom-slab deck does; a table meant to carry something is a top slab or a full node, and §8e then requires that flip to meet what is above it. The two rules compose into one: a shaped node's surface must be at the top of its cell whenever anything rests on it. No start exercises it today — all six tables are bare. |

The same measurement found one more slab under a load, in Silverleaf: the
shrine's bell. `buildings.belfry` hangs the bell one course under the frame
beam a tall lantern gets, and a bottom slab hangs half a node below the timber
it is tied to. Where there is a frame the bell is written upside down now;
where there is none (a three-course lantern, the bell resting on its lamp) it
stays the right way up. That is the one `upside_down` cell in the six starts.

### 2. Orc wains: a nodebox can float from above as well

`grug_decor:cottages_wagon_load`'s nodebox runs from y = 0 to y = 0.5 — the
TOP half of its cell (`mods/ITEMS/grug_decor/cottages.lua`, `wagon_load_box`).
`dressing.wagon` writes the load one course above its bearer log, so all
**15 loads** on the camp's five wains stood half a node clear of the cart, and
no arrangement of full-node bearers could have closed it: the node below would
have to be one and a half nodes tall.

The orc `cargo` role is `stairs:slab_acacia_wood` now — a half-height stack of
sawn boards that fills the BOTTOM of its cell, rests on the bearer and carries
nothing itself, which is exactly what a bottom slab is for. `dressing.wagon`
is unchanged. The camp emits `cottages_wagon_load` nowhere any more, so its
`parts.PARAM2_KIND` claim went with it (the same clean-up the previous round's
L6 made for three other unemitted shape claims).

Dawnmere's three handcarts were already flush: their load is
`grug_decor:xdecor_barrel`, a full cube resting on a log. Measured, not
assumed — which is why the rule is about the shape of the node and not about
carts.

| Guarded by | What it says |
| --- | --- |
| `blueprint_kat` sunscar props | `stairs:slab_acacia_wood` population is EXACTLY 43 — 15 wagon loads and 28 interior table tops — and none of them floating (a prop must have a non-air cell under it) |
| `blueprint_kat` cart rule | 15 carts, each a `cart_load` at y = 2 standing on a bearer log at y = 1, never beside one |
| the composition | `dressing.wagon` still returns false on a refused cell and `prop`/`paved_prop` still raise on a false |

### 3. Human fields: a blueprint can be correct and still not survive the world

Dawnmere's crop furrows were `default:dirt`, written through the palette's
`ground_patch` role, and the planted rows `default:dirt_with_grass` through
`planter_soil`. Default's "Grass spread" ABM
(`mods/BASE/default/functions.lua`) has `nodenames = {"default:dirt"}` — that
one name and nothing else — so every lit furrow became the grass beside it
within minutes of the chunk going active and the eight fields read as lawn.
Every fixture stayed green, because the blueprint it checks is still correct;
the defect appears one ABM tick after the writer has finished.

New node `grug_nodes:tilled_soil` ("Tilled Soil"), bound through a new
OPTIONAL palette role `crop_soil` that only the human palette names, used by
`dressing.crop_rows` for both courses of a field — **3,267 cells**. What it
carries, and why:

- it is not `default:dirt`, so it is not in that ABM's `nodenames`;
- no `spreading_dirt_type`, so the "Grass covered" ABM (which acts on
  `group:spreading_dirt_type`) cannot reach it either: neither a target nor a
  source of grass spread, in both directions;
- no `soil`, because that group is what `default.can_grow` asks for before it
  grows a sapling and a ploughed field is not a tree nursery;
- **no `grug_natural`, and it is NOT added to
  `grug_materials.NATURAL_GROUND_NODES`.** What the audit actually requires
  was read rather than guessed: `grug_materials/audit.lua` asserts only the
  converse — every name IN that roster carries the marker — and
  `registry.lua`'s structural pass only asserts the roster is duplicate-free
  and indexed. Nothing requires an authored node to carry it, and carrying it
  would put a farmer's furrow under the mining transaction's pick-tier and
  depth gating (`grug_materials/mining.lua`, `is_natural_node`), which is
  wrong for ground a settlement writes inside its own pad;
- `is_ground_content = false`, so cave carving cannot eat a field;
- `drop = "default:dirt"`, so it adds nothing to the economy.

**A tilled furrow carries no weeds, and that is a decision, not a side
effect.** Six places in the library ask whether a cell may carry a wild plant
and all six asked it as `below.name:find("dirt")` — a substring of a node
name, which is a spelling and not a property. `grug_nodes:tilled_soil` does
not contain "dirt", so the moment the furrows changed the answer changed with
them and **425 tufts and bushes left Dawnmere's fields** (286 `grass_3`, 139
`grass_4`) without anyone deciding it. The look is the one we want — a
ploughed field is weed-free — but nobody had chosen it, so the substring is
gone. All six sites now ask `parts.wild_soil`, a written-out roster of the
nine soils the substring used to accept, and the rule it encodes is written
down: *a plant seeds itself in ground the MAPGEN generates, never in ground a
settlement authored.* Converting the six sites is byte-identical — the roster
is exactly the set of dirt-family names the six starts emit, measured, and the
dumps above are unchanged by it.

No new PNG. The three tiles are the vendored `default_dirt.png` with the
engine's own `^[colorize:#2b1d0e` modifier on the top and side faces, which is
a render-time operation on a file this project already ships; `LICENSE-media.md`
gained a section 1b saying so, and the table of PNGs this mod GENERATES is
unchanged. `tools/wp13/extract_tiles.py` needed no `MANUAL_OVERRIDES` entry:
its scanner reads the registration and `render_blueprint.py` implements
`[colorize`, so `node_tiles.json` (469 nodes) resolves the node on its own.
The `attached_node` junglegrass crop stands on it unchanged — the node is
walkable.

| Guarded by | What it says |
| --- | --- |
| `blueprint_kat` dawnmere `ground` | a new row: more than 3,000 `grug_nodes:tilled_soil` cells at y = 0. The `default:dirt` row drops from 400 to 100, because the 1,712 furrows left the population and the 162 worn-earth patches that role is actually for stay |
| `blueprint_kat` `ground_cover` | a new EXACT row per start, both of that race's ground-cover nodes. Dawnmere is 756 / 1,571; putting back the pre-round 1,857 fails the fixture with `ground cover population differs`. This is the assertion that would have caught the 425 |
| `library_kat` §7d | every member of `parts.WILD_SOIL` is registered, is an opaque full cube, and is in `grug_materials.NATURAL_GROUND_NODES` — read out of `registry.lua` as text, the way the retirement roster is. `grug_nodes:tilled_soil` is asserted absent from BOTH rosters, so adding it to either cannot pass unnoticed. The converse is deliberately not asserted: `grug_nodes:mud` is generated ground that still carries nothing, because the Cradle's mud flats are bare by authored intent |
| `library_kat` §3, §8 | the node must be registered, not retired, callback-free, and `parts.full_solid` / `parts.pane_connects` / `parts.shaped` must agree with the real registry about it in both directions |

## Checks

| Gate | Result |
| --- | --- |
| `tools/bin/luac51 -p` per changed file | PASS, 10 files |
| `tools/bin/luac51 -p` tree-wide | PASS for `mods/*/grug_*` and for `tools` |
| SETGLOBAL | 0 on every changed file |
| Five plain-5.1 sweeps, changed files | zero hits |
| Five plain-5.1 sweeps, `wp13/` + `grug_nodes` + changed `wp40` + `tools/wp13` | only the six pre-existing `os.exit` lines in `tools/wp13/dump_blueprint.lua`, a developer tool that never runs in the engine sandbox |
| `python3 -m py_compile tools/wp13/extract_tiles.py` | PASS |
| `node_tiles.json` parses, regenerated | PASS, 469 nodes |
| WP40 R7 changed-production roster | PASS, 142 files, script expects 142 (`grug_nodes/init.lua` was already on it) |
| `tools/check_fresh_server.py` | `Fresh-server source audit: PASS` |
| `library_kat` + `blueprint_kat` + `integration_fixture`, LuaJIT vs PUC 5.1 | byte-identical, `9b2466f08f84a246…` |
| `atmosphere_kat`, LuaJIT vs PUC 5.1 | `OK` under both, identical apart from the interpreter banner the KAT prints on line 2 |
| `tools/wp13/final_micro.lua` pair | byte-identical, `9b2466f08f84a246a74b42ce582540b760f78e9a22a134c8e1f5f7db6f8f60d8` |
| Engine gate, both seeds | see below |

The whole `tools/wp40/r7/source_audit.sh` still cannot pass, for the two frozen
expectations that belong to the WP40 lane and not to this one — see
`docs/research/wp13-dawnmere-fields.md`. `static.sh` derives and compares the
changed-production roster step, which is the part that is this round's
business.

## Engine gate

One gate, six starts, two seeds, run sequentially by `engine.sh` on headless
Luanti 5.17.0 through the isolated Flatpak launcher. Each seed is a full
`run_engine.sh` pass: forward and reverse owner order, each with its own cold
world and its own disk-only reload.

**All eight runs agree on one digest:**
`206a86a057b0b6ed4cb5ee71df67413e0f40b70f0b486ea3947bbbbb99eac9a6`
(2 seeds x forward/reverse x cold/disk).

| Start | Authored cells | Torches lit | Per-start digest | Moved? | Fitted y, user seed | Fitted y, boundary seed |
| --- | --- | --- | --- | --- | --- | --- |
| Hearthpine | 61,932 | 74 | `03311c95b8463c42…` | no | 25 | 16 |
| Dawnmere | 66,361 | 98 | `19f8c63f3de9dfe0…` | yes | 17 | 21 |
| Silverleaf | 71,495 | 113 | `a81a370a26a293f6…` | yes | 21 | 42 |
| Stillgrave | 51,641 | 78 | `13f3cff1f580eb6d…` | no | 54 | 48 |
| Sunscar | 57,227 | 112 | `de46c91105d36125…` | yes | 27 | 46 |
| Kapok | 72,535 | 87 | `e11c30ec9e88b7ce…` | no | 20 | 17 |

The per-start digests are identical on both seeds, which is the contract: a
blueprint's bytes are the same wherever the terrain puts it, and only the
anchor's fitted y moves. Every fitted y is the one the previous round
recorded, and Hearthpine's `03311c95b8463c42…` is the digest the first
increment recorded. The cell TOTALS are unchanged in all six starts, but that
is a property of the buffer and not of the settlement — a cell a composition
clears stays in the list as `air`. Sunscar and Silverleaf really did only
replace nodes; **Dawnmere lost 425 ground-cover cells** (286 `default:grass_3`
and 139 `default:grass_4`), which is the consequence of the tilled furrows
described under finding 3 and not a fourth change.

- **user seed** `531802985935182545`, 44 structure owners, evidence in
  `user-seed/`.
- **boundary seed** `8675309`, 62 structure owners, `filler_boundary=true` —
  the seed that puts Stillgrave's fitted surface at y = 48, just above the
  generated owner's ceiling. Evidence in `boundary-seed/`.

Both runs placed and checked the persistence canary, walked each start's lit
five-wide main route end to end, proved every interior destination reachable,
and confirmed the apron soil witnesses outside every blueprint. `pgrep -c -f
'^luanti.bin --server'` was 0 before the gate started; each seed is bounded by
`timeout --kill-after`, output goes to `/tmp` because the launcher mounts the
repository read-only, and after each seed the process table is checked for a
server still naming that run's output path — none remained, and both scratch
directories were removed.

## Renders

`renders/` holds the six overviews (`-overview-ne`, `-overview-sw`) and a
`-before.png` beside each `-after.png` for the three spots the playtest was
about:

- `sunscar-parapet-*`: the warlord hall's south-east breastwork from below the
  wall head. The before shot is the strip of daylight the user saw between the
  deck and the ring; the after shot is one masonry course.
- `sunscar-parapet-tower-*`: the west gate tower's ring, the same fix on a
  `watchpost` roof, which reaches the rasteriser by a different path.
- `sunscar-wain-*`: the wain by the warlord hall — three bearers, a wheel on
  each, and the load that used to ride above them.
- `dawnmere-field-*`: the east crop field. The construction-time picture
  changes little (the crop rows cover most of it); the point of the fix is
  what the picture looks like after the ABM has run, which no render can show.

## Reproducing

```sh
tools/wp13/evidence/20260914-round-a-blueprints/static.sh      # parser, SETGLOBAL, sweeps, audits
tools/wp13/evidence/20260914-round-a-blueprints/kat.sh         # the KAT trio and atmosphere_kat, both interpreters
tools/wp13/evidence/20260914-round-a-blueprints/dump.sh        # the six dump SHA-256s
tools/wp13/evidence/20260914-round-a-blueprints/final-micro.sh # the frozen-byte micro-KAT pair
tools/wp13/evidence/20260914-round-a-blueprints/renders.sh     # overviews and the three fixed spots
tools/wp13/evidence/20260914-round-a-blueprints/engine.sh      # the combined six-start engine gate
```

`renders.sh` writes only the `-after.png` files; the `-before.png` files were
rendered from a `git archive` of the parent commit through the same
`render_blueprint.py` invocations.

## Not fixed, and why

Two more short-node-under-something sites were measured and deliberately left:

- the smith's hood, a lone `chimney_cap` slab one course above the anvil in
  the forge kit (`interiors.lua`), in Dawnmere and Sunscar. Nothing rests on
  it, so it is outside the rule this round added; moving it would move
  Hearthpine, whose bytes are frozen.
- Kapok's bath-house slab over the tub, and its stone paths under a stilt
  deck. Same reason: the deck passes over the path, it does not stand on it.
- Sunscar's armoury-wing ring posts at (34, 6, -4) and (34, 6, 2). They stand
  on the stair that steps the main deck down to the wing deck, so a quarter of
  each `walls:desertcobble` post oversails the stair's low half. Pre-existing
  and unchanged by this round (the same stair is there in the parent commit);
  it is half a nodebox post over the step it runs along, and every way of
  moving it rebuilds the armoury's roof field. It is the one shape §8d's stair
  exemption lets through, and the KAT comment says so at the rule.

None of the three was in the user's report. They are recorded here so the next
round starts from a measurement rather than from a re-reading of the same
screens.
