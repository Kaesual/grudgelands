# WP13 playtest round 2 — settlement NPC behaviour (2026-09-15)

Evidence for the three rulings the user gave after playing the round-1 build.
The round itself is written up in
[docs/research/wp13-npc-round-2.md](../../../../docs/research/wp13-npc-round-2.md);
this directory holds what the gates printed.

| file | what it is |
| --- | --- |
| `static.sh` / `static.txt` | `luac51 -p` per touched file and tree-wide, the SETGLOBAL count, the five plain-5.1 sweeps (touched mods, `mods/*/grug_*`, `tools/wp13`), `check_fresh_server.py` |
| `final-micro.sh` / `final-micro/` | the one bounded final-byte process: every WP13 fixture in one interpreter, once under LuaJIT and once under `tools/bin/lua51`, with the input set hashed before and after both runs |
| `kat.txt` | the `start_npcs_kat` report on its own, which is the part of the micro TSV this round rewrote most |
| `start-identities.txt` | the six start blueprint identity digests, to be diffed against `20260915-npc-playtest-1/start-identities.txt` |
| `npc-probe/` | `tools/wp13/run_npc_probe.sh`: three boots on ONE world through `tools/luanti_headless.sh` with the disposable probe of `tools/wp13/npc_probe` |
| `highcourt/` | `tools/wp13/run_highcourt.sh … full`: the capital's own pass, re-run because its socket table gained ten spares and a `door` tag |

Ports: `PORT=31142` for the NPC probe, `WP13_HIGHCOURT_PORT=31151` for the
capital pass — this lane's own band. Both runs go through the isolated
launchers, and `pgrep -af '^luanti.bin --server'` is clean of them afterwards.

## The gates

- **Final micro pair byte-identical**, output_sha256
  `a4edd369c7af6cf8e9c21ec186a3145947d1ad0ca966c4eb4a582417d7768bad` from both
  interpreters. It was
  `4f2d2b769578c00bd9947a5904dd4f1635fae0e2503420f990a585f7841cbdf5` in round 1,
  and 46 rows moved — all of them socket bookkeeping and the two reports this
  round rewrote: `start_npcs_kat` (the new `spare`, `noncombatant` and
  `elder_turned` lines, the four new registry refusals, the `census`/`amble`
  rows), `settlement_sockets_kat`'s per-socket rows, the six `wp13_blueprint`
  rows (16 sockets each, 3 spare), `highcourt_core` (75 sockets, 10 spare) and
  `wp13_seam` (105/30/10). **The `wp13_integration` row is byte-identical**, so
  every settlement identity SHA — the six starts and Highcourt's
  `187f79e0ba52103818eba53f7ed9c3beadc631682648918301287fa4a7200499` — is
  unchanged. Sockets are landmarks, not identity bytes.
- **Six-start identities**: `start-identities.txt` is byte-identical to round
  1's. This round writes no mapgen cell.
- **Static**: clean, and every hit is pre-existing. `luac51 -p` passes per
  touched file and over the whole `mods`/`tools` tree; `mods/*/grug_*` writes 17
  globals (one table per mod). The five sweeps report the same five pre-existing
  classes round 1 enumerated — the `\u{}` comments in `levels.lua` /
  `target_frame.lua`, `|` inside prose tables and usage strings, `::Transform::`
  in a C++ symbol name, the file name `minetest.conf` in three comments, and the
  fifteen real `os.exit` calls in the standalone `tools/wp13` dump scripts, none
  of which run inside the engine sandbox. This round added none of them.
  `check_fresh_server.py` PASS.
- **KATs** (LuaJIT, and again inside the PUC half of the micro pair):
  `start_npcs_kat`, `settlement_sockets_kat`, `blueprint_kat`, `highcourt_kat`,
  `seam_kat`, `library_kat`, `integration_fixture` — all green. The rows this
  round is about: `spare unplaced unmarked ring_3 spots_1_2`,
  `door_facing door_turned bench_kept elder_turned`,
  `amble moved_at_22 spots_3_and_3_of_3 spare_reached`,
  `census hearthpine start 7 7 spare_1`,
  `noncombatant declared installed_on_activate chained villager_and_elder
  guard_excluded hostile_default`.
- **Engine, the six starts** (`npc-probe/`): `errors=0 complete=3`. Every
  settlement logs `guards 3/3 flair 4/4 vendor 1/1 quest 1/1 … pending 0
  spare 3`, i.e. the roster is unchanged at 9 and the three spares carry
  nobody. Boot 1's census is `roster=9 marked=9 live=9 twins=0 spare=3` through
  the whole programme, boots 2 and 3 read the same after a reload.
- **Engine, the capital** (`highcourt/`): `errors=0`, `ModError=0`,
  `event=complete mode=full requested=47 completed=47`, the committed avenue
  road digest `9d6f0167…` and the same cell counts as round 1 (`core_cells=43075
  plot_cells=5760 avenue_cells=79752`). Its socket inventory is `sockets=105
  role_idle=59` (was 95/49) and its roster is unchanged:
  `guards 19/19 flair 49/49 vendor 2/2 quest 1/1 new 3 pending 0 spare 10`.
  `grep -c core_spare npcs.txt` is 0 — no spare was ever placed on.

## What the probe proves this round, and how

Four claims were added to the round-1 programme, which the same three boots
otherwise run unchanged; one round-1 timing was widened (below). The forceload
mechanism, the identity census and the reading guide for `probe.txt` are in
[`../20260915-npc-playtest-1/README.md`](../20260915-npc-playtest-1/README.md)
and still apply.

- **R1 — spare sockets never spawn.** Every `event=census` line now carries
  `spare=<n>`, and the probe reads the settlement's spare set out of
  `grug_core` and fails if any NPC is booked on one. Hearthpine: `roster=9`,
  `spare=3`, in every phase.
- **R2 — villagers visit more than one spot.** `event=wander socket=… distinct=n`
  per villager and one `event=wander_done`. The sampler runs once a SECOND over
  the 170-second amble window and records where a villager is *standing*, not
  what it is heading for; a 20-second sampler would miss whole visits, because a
  dwell is 20–60 s and a Hearthpine walk about 25 s.
- **R3 — the elder faces the street.** `event=facing socket=hall_quest role=quest
  tag=door authored=… want=… have=… delta=…`, read off the OBJECT's yaw because
  that is what the player sees, and again on the reload boots: `mob_activate`
  hands every mob a random yaw, so the authored facing has to be re-asserted on
  every activation. Quest sockets only — an elder is the one family with no
  movement, so its yaw is the rule and nothing else.
- **The unload case prepares its destination now.** The round-1 review case
  "an NPC whose own mapblock went inactive comes back when the block does"
  teleported the villager to its own position + 128 and hoped; that volume is
  never generated, and an object moved into a block that does not exist is not
  unloaded but LOST (two runs of this round showed it: the block read
  `active=true loaded=true` and the NPC was gone, and the next boot then freed
  the marker and placed a replacement). The away point is a fixed offset from
  the anchor now, forceloaded — hence generated — before anything moves there,
  the NPC is put on the ground the probe reads out of that column
  (`event=away_request`, `event=unload`), and only then is the forceload
  released. The re-activation window is 25 s rather than 6, with
  `event=reload_request` / `event=reload_wait` recording the block's own
  status.
- **R4 — mutual combat, and not with civilians.** `event=hostile` now also
  prints `attack_npcs` and fails if a hostile still carries `false`;
  `event=engagement` says whether the gate pair held each other as targets; and
  every hostile's and every guard's target is tested against
  `grug_mobs.is_noncombatant` — the entity's own flag, not a name list, because
  a name list is exactly what a new civilian family would be missing from.
