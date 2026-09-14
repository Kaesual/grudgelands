# WP13 increment: character visuals

Candidate commit: see `candidate.txt`. The note for this increment is
[docs/research/wp13-character-visuals.md](../../../../docs/research/wp13-character-visuals.md),
the design record
[docs/design/character_visuals.md](../../../../docs/design/character_visuals.md),
the binding contract
[docs/research/wp13-character-visuals-contract.md](../../../../docs/research/wp13-character-visuals-contract.md).

| Path | What it is |
| --- | --- |
| `static.sh`, `static.txt` | `luac51 -p` and `SETGLOBAL` on every changed Lua file and on the whole `grug_*` and `tools` trees, the five plain-5.1 sweeps (scoped to the changed Lua, then repeated tree-wide), `tools/check_fresh_server.py`, the `LICENSE-media.md` row check for every shipped PNG, and a re-run of the art generator compared byte for byte |
| `kat-luajit.txt`, `kat-puc51.txt` | `tools/wp13/character_visuals_kat.lua` **and** `tools/wp13/visuals_order_kat.lua` on the frozen bytes, byte-identical under both interpreters (`sha256 85db85ab…ae2914ec`) |
| `engine.txt` | the grep of the single headless boot's server log: the mod's own startup line, the probe's spawned-entity readings, the listening line, and a census of every WARNING/ERROR in the whole boot |
| `probe/` | the temporary probe mod staged into `mods/PLAYER/zz_wp13_visual_probe/` for that one boot and deleted afterwards — it is what produced the `[wp13probe]` lines |
| `renders/` | flat front paper dolls of all six races, bare and in each of the two armor lines, because this lane cannot open a client |
| `files.sha256` | every file above plus every shipped PNG and every changed Lua file |

## How the evidence was produced

From the repository root:

```sh
bash tools/wp13/evidence/20260914-character-visuals/static.sh \
  > tools/wp13/evidence/20260914-character-visuals/static.txt 2>&1

LC_ALL=C luajit -e 'local r="." \
  io.write(dofile(r.."/tools/wp13/character_visuals_kat.lua")(r)) \
  io.write(dofile(r.."/tools/wp13/visuals_order_kat.lua")(r))'

# and the same line under tools/bin/lua51

python3 tools/wp13/gen_character_visuals.py \
  --renders tools/wp13/evidence/20260914-character-visuals/renders
```

and one engine boot:

```sh
cp -r tools/wp13/evidence/20260914-character-visuals/probe mods/PLAYER/zz_wp13_visual_probe
KEEP=1 tools/luanti_headless.sh 180
rm -rf mods/PLAYER/zz_wp13_visual_probe
```

`tools/luanti_headless.sh` stages the game into a fresh temp directory and
points `LUANTI_USER_PATH` and all three XDG dirs at it, so the user's personal
Luanti folder was never read or written. The launcher's own EXIT trap kills
**only** the process whose command line carries its own `--world <root>/`, so
nothing else on this shared workstation is touched; no blanket
`pkill luanti.bin` was used. `pgrep -f '^luanti.bin'` listed no foreign server
before the run and none after it, and the temp directory was removed.

## Results

- **KAT**: `wp13_cv_result PASS 0`, identical under LuaJIT and PUC 5.1.5.
  366 compositions, 14 distinct textures, all present on disk.
- **Static**: every changed file parses; one `SETGLOBAL` per mod table and none
  anywhere else; the five sweeps hit only prose in pre-existing comments
  (design-doc table rows containing `|`, and one comment that names the `\u{}`
  escape in order to forbid it); fresh-server audit PASS; all 14 PNGs carry a
  `LICENSE-media.md` row; the generator reproduces them byte for byte.
- **Engine**: `headless boot: PASS`, zero `ERROR`/`ModError` lines. 57 WARNING
  lines in the whole boot, all of them the pre-existing `No craft recipe …`
  chatter plus the deprecated-mod-storage notice — none from `grug_visuals`,
  `grug_mobs` or `grug_traders`. Guards, bandits, mirefolk and vendors all
  register and, when spawned, hold exactly the composed texture string with
  their wielded item set.

## Review round (2026-09-14)

Five findings applied, one measured and refuted:

| # | Finding | What was done |
| --- | --- | --- |
| 1 | the Character page renders one equipment change stale | fixed by load order: `grug_inventory` now declares `optional_depends = grug_visuals` and `grug_visuals` declares nothing back. Proven by the new `visuals_order_kat.lua`, which sorts the real mod.conf graph and fires the real `grug_core` seam. Negative control: reverting the two mod.conf lines makes it report `grug_visuals does not load before grug_inventory` at positions 28 vs 26 |
| 2 | `visual_size` never repaired after an external write | it is now written on every `apply`, outside the texture token; only the texture list stays guarded |
| 3 | KAT shape check was dead (`%` escape in a plain search) | needle fixed, plus a four-string negative corpus (`wp13_cv_shapecheck`) so a dead checker cannot pass again. The reviewer's own string `skin.png^overlay.png^[multiply:#ffffff` is now rejected with `[multiply outside a group` |
| 4 | BACKLOG.md still said vendors reuse the guard skin | updated |
| 5 | "Open points" in a decided design doc | moved into the increment record; the design doc keeps only decided rules |
| art | "the chest overlay leaves the torso's back and side faces uncovered" | **not reproduced — measured false.** Both chest overlays cover all six torso faces at 100% (`static.txt`, "per-face coverage of every armor overlay": `back 96/96 full`, `right 48/48 full`, `left 48/48 full`, `top`/`bottom 32/32 full`). The front-only paper doll could not show this, which is why the composites now render a **back row** as well, and why the generator asserts per-face coverage on every run |

## What changed in shared tooling

- `tools/wp13/gen_character_visuals.py` is new: the deterministic generator for
  all 14 PNGs, the review composites (front row and back row) and a per-face
  coverage assertion over every overlay -- "full" where a slot promises cover,
  "open" where it promises a face opening. It exits non-zero on a complaint.
- `tools/wp13/visuals_order_kat.lua` is new: the load-order and callback-order
  fixture behind the Character-page finding.
- `tools/wp13/character_visuals_kat.lua` is new. It does **not** use
  `tools/wp13/stub_registry.lua` — that module loads the node-registering
  vendored mods a settlement palette may name, which has nothing to do with
  armor items. It borrows the same pattern (a stub `core`, the real sources,
  every touched global handed back) against `grug_gear` and `grug_visuals`.
