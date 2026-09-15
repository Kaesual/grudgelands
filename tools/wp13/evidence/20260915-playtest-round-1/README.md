# WP13 playtest round 1 (2026-09-15)

Candidate commits: see `candidate.txt`. The note for this round is the
"Playtest round 1" section of
[docs/research/wp13-character-visuals.md](../../../../docs/research/wp13-character-visuals.md);
the decided design records are
[docs/design/character_visuals.md](../../../../docs/design/character_visuals.md)
§4 (how a weapon is held) and
[docs/design/classes.md](../../../../docs/design/classes.md) §2b
("Right-click with a skill in hand opens the door").

Two defects from the user's GUI playtest:

1. **The sword was held backwards** — the tip in the hand, the hilt sticking
   straight out behind the guard. The 2026-09-14 numbers were eyeballed; they
   are now derived in `mods/PLAYER/grug_visuals/wield_geometry.lua`.
2. **Right-click with a skill in hand did not open doors** — not a cast eating
   the click (right-click never cast) but the swing items' own `"blocking"`
   pointabilities hiding `oddly_breakable_by_hand` nodes from the client.

An independent review of the first candidate returned "merge after fixes" with
six findings; all six are applied here and the whole gate set was re-run on the
result. The two that changed behaviour:

- **HIGH** — `on_secondary_use` is also what `INTERACT_PLACE` on an *object*
  calls, immediately before the engine runs that object's own right-click
  (`serverpackethandler.cpp:1192-1208`). The first draft ignored `pointed_thing`
  there, so right-clicking a vendor would have opened the shop **and** fired the
  `on_rightclick` of the first node behind him. A type guard now returns first,
  and two fixture cases hold it down.
- **MEDIUM** — the 4 m hand-reach bound existed only on `on_secondary_use`. A
  cast item has no blocking pointabilities and a range of up to 20, so
  `on_place` could open a door across a courtyard, which §2b now forbids. The
  bound is on both callbacks and two fixture cases cover it.

The other four: §2b's promise narrowed to what actually works (nodes with an
`on_rightclick`; the node-meta-formspec nodes are documented as out of reach),
§2c's stale "not shown in third person" sentence corrected, `GRIP_FRACTION`
corrected from `-5/16` to `-5.5/16` (the centre of sprite row 13, not its top
edge — it moves `pos` to `{0, 3.809, 1.461}`), and the note's animation figures
re-measured with the caveat that a `KEYS` angle's sign depends on Irrlicht's
transposed quaternion convention while the rest frame does not.

| Path | What it is |
| --- | --- |
| `static.sh`, `static.txt` | `luac51 -p` on every changed file and tree-wide, `SETGLOBAL` per file, the five plain-5.1 sweeps (scoped to the changed files, then counted tree-wide), `tools/check_fresh_server.py` |
| `kat-luajit.txt`, `kat-puc51.txt` | all four WP13 fixtures — the two new ones plus the two the round must not break — under LuaJIT and `tools/bin/lua51`, byte-identical (`sha256 fe6861d4…f410046c`) |
| `engine.txt` | the single headless boot's log census: the listening line, this mod's startup line, and every distinct WARNING with counts |
| `files.sha256` | every file above plus every changed source file |

## How the evidence was produced

From the repository root:

```sh
bash tools/wp13/evidence/20260915-playtest-round-1/static.sh \
  > tools/wp13/evidence/20260915-playtest-round-1/static.txt 2>&1

LC_ALL=C luajit -e 'local r="." \
  io.write(dofile(r.."/tools/wp13/wield_transform_kat.lua")(r)) \
  io.write(dofile(r.."/tools/wp13/ability_rightclick_kat.lua")(r)) \
  io.write(dofile(r.."/tools/wp13/character_visuals_kat.lua")(r)) \
  io.write(dofile(r.."/tools/wp13/visuals_order_kat.lua")(r))'

# and the same line under tools/bin/lua51
```

and one engine boot:

```sh
KEEP=1 tools/luanti_headless.sh 180
```

`tools/luanti_headless.sh` stages the game into a fresh temp directory and
points `LUANTI_USER_PATH` and all three XDG dirs at it, so the user's personal
Luanti folder was never read or written, and its EXIT trap kills only the
process carrying its own `--world`. The temp directory was deleted afterwards.
`pgrep -f '^luanti'` listed nothing of this lane's at the end (a foreign
`grudgelands-wp13-highcourt.*` server belonging to another lane was running and
was deliberately left alone).

## Results

- **`wp13_wield_result PASS 0`.** The fixture parses `character.b3d` itself and
  reports the bone frame (`x->-1,0,0  y->0,-1,0  z->0,0,1`), the arm's reach
  (5.250) and fist centre (bone y 4.200), the face quad's normal (`0,0,1`), and
  then the sprite's own corner points: with the arm hanging the grip sits
  exactly in the fist, the hilt 0.664 units behind it and the tip 3.586 in front
  and 0.961 up, blade direction `0,0.259,0.966`, flat normal horizontal. Its
  **negative control** re-runs the same maths on the photographed numbers and
  prints `hilt-hand 0,-1.300,-3.700  tip-hand 0,-1.300,0.700` — the reported
  picture, which is what makes the fix trustworthy without a client.
- **`wp13_rmb_result PASS 0`.** The real `grug_abilities/init.lua` is loaded
  under a stub engine, one swing and one cast ability are registered through the
  real `register_ability`, and both kinds are driven through twelve right-click
  cases each plus the LMB cast case: the door's `on_rightclick` is called
  exactly in the two cases that should call it; sneaking, out-of-reach on either
  callback, behind-a-wall and an **object** click call nothing; the ray is 4 m
  with objects and liquids off, and is not cast at all where it should not be;
  every case also asserts how often the code asked for the eye position, so a
  gate that never ran cannot pass by standing next to a door; and the cast
  counter stays at 0 for every right-click while `on_use` still casts once.
  Three negative controls, taken by hand on this tree: deleting the two
  `tool_def` lines gives `FAIL 106`; neutering the object type guard gives
  `FAIL 6` with both object cases reporting `called on_rightclick 1 times,
  expected 0` — the reviewer's finding, reproduced; neutering the `on_place`
  reach test gives `FAIL 8` with a door 5.5 m away opening.
- **`wp13_cv_result PASS 0`** and **`wp13_order_result PASS 0`** — the two
  fixtures from the 2026-09-14 increment, unchanged and still green.
- **Static**: every file parses under the engine's own PUC 5.1.5 parser; one
  `SETGLOBAL` per mod table and none in the two new fixtures or in
  `wield_geometry.lua`; the five sweeps hit only prose (the two new hits are
  `core::Transform::buildMatrix` C++ references in comments, and the three
  sweep-4 hits in `grug_abilities/init.lua` are a pre-existing comment and two
  pre-existing `"|"` string literals); fresh-server audit PASS.
- **Engine**: one boot, `PASS`, 139 log lines, **0 ERROR/ModError**, 57 WARNING
  — all pre-existing (the mod-storage-backend advice pair and the vendored
  `stairs` metal-block fuel-recipe rows).
