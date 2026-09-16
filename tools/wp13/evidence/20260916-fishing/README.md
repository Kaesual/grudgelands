# WP13 playtest round 5, wave 3 lane F — the axe in the hand, the rod, and fish

Increment record:
[`docs/research/wp13-fishing.md`](../../../../docs/research/wp13-fishing.md).
Base: `main` at `ed11781f` (the WP26 merge; rebased there from `f37a0c5b` after the
independent review). Branch: `wp13-w3-fishing`.

| File | What it is |
|---|---|
| `renders/wield-axe.png`, `wield-greataxe.png`, `wield-rod.png`, `wield-sword.png` | **The things to look at.** Each sprite where the engine actually puts it, drawn orthographically from the character's left at four points of the chop. The axe sheets are before/after; the rod sheet is the stick an angler used to hold above the rod it holds now; the sword sheet is the control, where the two rows are identical by construction. |
| `render_wield.py` | the renderer. It reads the attachment out of the REAL `wield_geometry.lua` through `luajit` (no number transcribed) and maps every sprite pixel through the same bone/attachment maths the fixture checks. The body behind it is schematic, from `character.b3d`'s own model numbers; the weapon is not. |
| `sprite_axis.py` | the measurement the whole axe argument rests on: for every held sprite, the opaque grip pixel, the signed centroid offset from the long axis, and the silhouette overlap with its own mirror about that axis — i.e. how much of it the new roll can move at all. |
| `static.sh`, `static.txt` | parser + `SETGLOBAL` per changed file and tree-wide, the five plain-5.1 sweeps scoped and tree-wide, `check_fresh_server.py`, the `LICENSE-media.md` row check for the shipped PNG, the imported sprite's sha256, and `sprite_axis.py`. |
| `kats.sh`, `kat-luajit.txt`, `kat-puc51.txt` | the four WP13 fixtures this increment touches — wield transform, fishing, character visuals, start NPCs — in one fixed order, once under each interpreter. **Byte-identical**, sha256 `7a42540a…89ff58b8`. |
| `mutations.sh`, `mutations.txt` | twelve deliberate breakages and what each fixture says. Eleven go red; **M2 is expected to pass and says so**, because it flips a sign that `TILT_UP = 0` makes inert. |
| `headless-boot.log` | one `tools/luanti_headless.sh 200` boot on port 31210 with `probe/` staged, re-taken on the rebased tree so `grug_smelting` is loaded next to this mod. Zero `ERROR`/`ModError`. The `[fishprobe]` lines carry the registrations, the poses, the recipes and the catch table **out of the live engine registry**, so "the KAT says so" and "the server agrees" are two statements. |
| `probe/` | the disposable probe mod staged for that one boot and never shipped. |
| `npc-probe/` | `tools/wp13/run_npc_probe.sh` in `start` mode, three boots on one world at gate seed `531802985935182545`, port 31215. Two notes on it are below. |
| `headless-boot-angler.log`, `headless-boot-angler-reload.log` | the angler in the world: two boots on ONE world (the second through `ROOT=`), with the probe forceloading Kezamba's three `fish` sockets and reading the wield entity back off the villagers standing on them. |
| `watch_gate.sh`, `watch-gate.txt`, `watch-gate-A-watched.log`, `watch-gate-B-unwatched.log` | the controlled experiment behind §6a of the increment record: two boots on two fresh worlds, differing in exactly one thing — the second replaces `grug_mobs.nearest_player_d2` from the probe, which is the only reason a headless boot's work residents are never dressed. No shipped byte is patched. |
| `identities.txt` | the six start identity digests and Highcourt's blueprint digests, this branch against `main`. |
| `final-micro.txt` | `tools/wp13/final_micro.lua` under both interpreters, and the one-line diff against `main`'s output. |
| `files.sha256` | every file above plus every changed source. |

### Two notes on the `npc-probe/` run

* **It does not show an angler, and could not have.** `npc_probe`'s start programme
  inventories `grug_core.settlement_socket_settlements()[1]` — Hearthpine, the
  dwarf start (`probe.txt`, `event=ready key=hearthpine`) — and the only
  `activity = "fish"` sockets in the game are Kezamba's three cenote anglers.
  That is why this lane staged a probe of its own for the angler. What the run
  *does* carry is the `chop` resident holding `item=default:axe_stone` on
  boot 3, i.e. the axe seam working end to end in an engine — and the
  `anim=stand` on its fresh boot, which is one of the two corroborations that
  the watch gate, not the wield seam, is what a headless boot is looking at.
* **Boot 1 died on the environment, not on the game**: three `ERROR` lines,
  all of them `Failed to save block: disk I/O error`. `/tmp` is a 30 GB tmpfs
  and stood at 80 % with seven wave-3 lanes writing worlds into it. Boots 2 and
  3 ran clean (`error-count.txt`: `3 / 0 / 0`).

## How the evidence was produced

From the repository root:

```sh
bash tools/wp13/evidence/20260916-fishing/static.sh \
  > tools/wp13/evidence/20260916-fishing/static.txt 2>&1

tools/wp13/evidence/20260916-fishing/kats.sh luajit \
  > tools/wp13/evidence/20260916-fishing/kat-luajit.txt 2>&1
tools/wp13/evidence/20260916-fishing/kats.sh tools/bin/lua51 \
  > tools/wp13/evidence/20260916-fishing/kat-puc51.txt 2>&1

bash tools/wp13/evidence/20260916-fishing/mutations.sh \
  > tools/wp13/evidence/20260916-fishing/mutations.txt 2>&1

python3 tools/wp13/evidence/20260916-fishing/render_wield.py \
  tools/wp13/evidence/20260916-fishing/renders
```

and two engine passes, both through `tools/luanti_headless.sh`:

```sh
# the watch-gate experiment (watch-gate.txt and its two logs)
PORT=31210 BUDGET=240 tools/wp13/evidence/20260916-fishing/watch_gate.sh \
  /tmp/grug-w3-fishing-watch

# the registry pass (headless-boot.log)
PORT=31210 KEEP=1 PROBE=tools/wp13/evidence/20260916-fishing/probe \
  nice -n 19 tools/luanti_headless.sh 200

# the angler pass: a fresh world, then the SAME world again
PORT=31210 KEEP=1 SEED=531802985935182545 \
  PROBE=tools/wp13/evidence/20260916-fishing/probe \
  nice -n 19 tools/luanti_headless.sh 480          # -> server.log
PORT=31210 ROOT=<the kept root> SEED=531802985935182545 \
  PROBE=tools/wp13/evidence/20260916-fishing/probe \
  nice -n 19 tools/luanti_headless.sh 300          # -> server.2.log

# the standard start programme
PORT=31215 nice -n 19 tools/wp13/run_npc_probe.sh \
  /tmp/grug-w3-fishing-npc 531802985935182545 start
```

The launcher stages the game into a fresh temp directory and points
`LUANTI_USER_PATH` and all three XDG dirs at it, so the user's personal Luanti
folder was never read or written; its EXIT trap kills only the process carrying
its own `--world <root>/`, and no blanket `pkill` was used. `pgrep -af
'luanti.bin --server' | grep 31210` and `… | grep 31215` listed nothing before
and nothing after, and both temp directories were removed.

## Results

* **KATs**: `wp13_wield_result PASS 0`, `wp13_fishing_result PASS 0`,
  `wp13_cv_result PASS 0`, start-NPC fixture clean — identical under LuaJIT and
  PUC 5.1.5.
* **Static**: every changed file parses; one `SETGLOBAL` in the new mod's
  `init.lua` and none anywhere else; the five sweeps hit only pre-existing prose
  (`core::Transform::buildMatrix` in two comments) plus the pre-existing wp40
  tooling; fresh-server audit PASS; the one shipped PNG carries its
  `LICENSE-media.md` row.
* **Sprite measurement**: of the **63** sprites a character can hold, **39** are
  **100.0 %** invariant under the new roll — every sword, dagger, pick and
  shovel of all three ladders, plus the stick — so the round-2 sword cannot have
  changed; the roll moves 28 pixels of an axe (all three axe families) and 38 of
  a greataxe. The counts are printed by the script, not hand-counted.
* **The angler**: on a FRESH world all three Kezamba `fish` sockets carry a
  `grug_mobs:villager_troll` with `activity=fish` and an **empty hand** at every
  sample; the same world rebooted gives all three
  `wield_item=grug_fishing:rod wield_pose=tool wield_entity=true` 20 s in.
  **That split is a probe artefact, not a defect**, and `watch-gate.txt` is the
  one-variable experiment that says so: a headless boot has no player, so
  `watched()` in `start_villagers.lua` is false on every tick and the dressing
  block is never reached at all. Override `grug_mobs.nearest_player_d2` from the
  probe and the same fresh world dresses the anglers. §6a of the increment
  record carries the whole correction — an earlier draft of it blamed
  `add_entity` and proposed a per-tick patch; that diagnosis was wrong and the
  patch is withdrawn.
* **Engine** (re-taken after the rebase, so WP26's `grug_smelting` is loaded
  alongside): `headless boot: PASS`, zero `ERROR`/`ModError`; 61 `WARNING`
  lines, all of them the pre-existing `No craft recipe matches input (type:
  fuel, …)` chatter, the deprecated-mod-storage notice and two seed-dependent
  `grug_mapgen` plot-placement warnings (this boot takes a random seed) — none
  from `grug_fishing`, `grug_visuals` or `grug_mobs`. The `grug_traders` startup
  audits print clean, including WP26's new `audit_alloys.lua`, and
  `[grug_smelting] recipe audit passed: 5 cooking, 5 dualfurn, 12 storage pairs,
  1 station` sits next to `[grug_fishing] 3 catch entries`. The cooked fish's
  own `cooking` recipe still resolves in the engine's registry
  (`[fishprobe] recipe grug_fishing:cooked_fish #1 method=cooking
  items=grug_mobs:raw_fish`).
* **Unchanged**: the six start identities (`0bbf87a7…91ad1f5f`) and Highcourt's
  blueprint digests (`66e2ed00…b9998f79`) are byte-identical to `main`;
  `bash tools/wp40/r7/run.sh unit` PASS.
* **Moved, deliberately**: `final_micro.lua`'s digest,
  `5bb22bb8…e1778f82` → `c9b8082f…6552feb`. The **entire** diff is one field of
  one row — `fish=stand/default:stick` → `fish=stand/grug_fishing:rod` — which
  is the ruling.
