# WP13 round 3, NPC work lane — evidence

Branch `wp13-r3-npc-work`, based on main `19abee02`. The change is described in
`docs/research/wp13-npc-work.md`; this directory is the measurement.

## What is here

| file | what it is |
|---|---|
| `static.sh` | the static gate script: parser + SETGLOBAL per changed file and tree-wide, the five plain-5.1 sweeps, the fresh-server audit, the six start identities, both KATs under both interpreters, and the neighbouring fixtures |
| `static.txt` | its output |
| `files.sha256` | the sources this increment changed |
| `start_npcs_kat-luajit.txt`, `start_npcs_kat-puc51.txt` | the placement/behaviour KAT under both interpreters (identical) |
| `blueprint_kat-luajit.txt`, `blueprint_kat-puc51.txt` | the blueprint KAT under both interpreters (identical) |
| `final_micro-luajit.tsv`, `final_micro-puc51.tsv` | the WP13 micro pair, byte-identical, `output_sha256=b713b6623d60bd10d186484a6cbaef0800c1735363fc00bc96e835d46d77eaf3` under both |
| `load-before.txt`, `load-after.txt` | the engine load probe, on the tree before the change and on the finished tree |
| `npc-probe.txt` | the three-boot behaviour probe's own lines |
| `npc-probe-boot1.log`, `npc-probe-boot2.log`, `npc-probe-boot3.log` | its server logs |
| `render-work-sockets.sh`, `renders/` | one textured render per `work` socket, centred on the socket, cut away at y = 3 |

## What the renders are, and are not

`tools/wp13/render_blueprint.py` draws NODES. It cannot draw an entity, let
alone an animated one, so there is no screenshot of a smith swinging a hammer
anywhere in here and there is no headless path that could produce one: the
server has no renderer and the animation only exists on a client.

What the twelve renders show is the other half of the question — **where each
worker stands and what it is facing**. Sunscar's `work_forge` is the clearest:
the cutaway shows the open-sided armoury shelter with its anvil, and the socket
is the cell immediately south of it. The animation itself is documented by
frame range, speed and wielded item in `docs/research/wp13-npc-work.md` section
2, and the engine probe reads back the animation mobs_redo actually wrote onto
each work resident's object (`event=work ... anim=...`).

## How to reproduce

```sh
cd <repo>
bash tools/wp13/evidence/20260915-npc-work/static.sh

# the load probe; run it once on this tree and once on 397ae840 (the probe's
# own first commit, whose mods are main 19abee02) for the before/after pair
PORT=31420 tools/wp13/run_npc_load.sh /abs/out/load-after

# the three-boot behaviour probe
PORT=31430 tools/wp13/run_npc_probe.sh /abs/out/npc-probe
```

Both engine scripts run through `tools/luanti_headless.sh`, which stages the
game into a fresh scratch directory under `/tmp`, points `LUANTI_USER_PATH` and
every XDG directory at it, kills only its own server and deletes the tree
afterwards. Nothing under the user's personal Flatpak folder is read or
written. Ports are this lane's block, 31400-31499.

## The load measurement

`tools/wp13/run_npc_load.sh` boots the game once and walks the six starts one
at a time: forceload the arrival, settle 8 s, measure 30 s, release. A forceload
activates blocks exactly as a player standing there would
(`ActiveBlockList::update` starts from the forceloaded set); what it cannot do
is make `core.get_connected_players()` answer, so the two player-gated paths in
the game — the vendor presence poll and the nametag gate — are idle during the
measurement and every number below is the floor.

Per start, before -> after:

| number | before | after |
|---|---|---|
| active mobs in the settlement | 9 | 11 |
| of which residents | 4 (all ambling) | 6 (2 work, 3 static idle, 1 walker) |
| walker share | n/a | 16.7 % |
| `core.find_path` calls in a 30 s window | 0 | 0 |
| mean server step | 90.24–90.33 ms | 90.26–90.33 ms |
| worst server step | 91.00–92.16 ms | 90.96–91.67 ms |

The mean server step is not by itself a measure of the NPCs: a dedicated server
runs a FIXED step (`dedicated_server_step`, 0.09 s) and only exceeds it once it
cannot keep up. It says there is headroom. What measures the NPCs is the
microbenchmark beside it — every settlement NPC's `do_custom` called once per
simulated second inside `core.get_us_time()`:

| | before (9 NPCs) | after (11 NPCs) |
|---|---|---|
| per settlement-second | 18.7–39.7 µs | 16.2–34.1 µs |
| per NPC-second | 2.7–5.7 µs | 1.5–3.1 µs |

**Two more NPCs per start, and the settlement's whole per-second tick got
slightly cheaper** — a static resident's tick is a distance test and an
already-correct animation, where an ambling one walked a ring. Both runs are in
the tens of microseconds per settlement per simulated second, i.e. under a
tenth of a percent of one 90 ms server step, so the fair claim is "unchanged
within noise, in the direction of cheaper", not a speed-up.

Both numbers above are from runs with no other server competing. An earlier
"after" run taken while four other lanes had their own headless servers up
(`uptime` load average 7.7 on 16 cores) read 14.3–62.4 µs — which is what the
spread of this measurement looks like under contention, and why the final pair
was taken on a quiet machine.

`find_path_total` over a whole boot is 3 before and 4 after; those calls happen
outside every measured window, during the preload and the guard placement, and
`patrol.lua`'s stuck rescue is the only caller a settlement has. **No resident
of either kind ever asks the pathfinder.**

## The behaviour probe

`tools/wp13/run_npc_probe.sh`, three boots on one world, `errors=0 complete=3`.
The round-3 lines out of `npc-probe.txt`:

```
event=wander socket=idle_west_door    walker=true  ring=4 distinct=3
event=wander socket=idle_plaza_bench  walker=false ring=4 distinct=1
event=wander socket=idle_workyard     walker=false ring=2 distinct=1
event=wander socket=idle_forge_door   walker=false ring=3 distinct=1
event=wander_done walkers=1 moved=1 static=3 strayed=0

event=work phase=fresh    socket=work_woodpile activity=chop anim=stand item=default:axe_stone ring=none drift=0.10
event=work phase=fresh    socket=work_garden   activity=tend anim=stand item=nil              ring=none drift=0.00
event=work phase=reloaded socket=work_woodpile activity=chop anim=walk  item=default:axe_stone ring=none drift=1.31
event=work phase=reloaded socket=work_garden   activity=tend anim=stand item=nil              ring=none drift=0.00

event=tag phase=far       family=villager metres=40 want=Vale Dwarf           shown=-
event=tag phase=near      family=villager metres=20 want=Vale Dwarf           shown=Vale Dwarf
event=tag phase=far_again family=villager metres=40 want=Vale Dwarf           shown=-
   ... the same three phases for the elder and the vendor ...

event=profession kind=butcher    entity=true nametag=Butcher    offers=6 brackets=false
event=profession kind=smith      entity=true nametag=Blacksmith offers=6 brackets=true
event=profession kind=fishmonger entity=true nametag=Fishmonger offers=4 brackets=false
event=profession kind=baker      entity=true nametag=Baker      offers=4 brackets=false
event=profession kind=tailor     entity=true nametag=Tailor     offers=6 brackets=false
```

The `anim=walk drift=1.31` line on boot 2 is the walk home in progress, not a
defect: boot 1's own wanderer phase teleports the whole roster forty nodes off
its sockets, and boot 2 catches that resident on its way back (boot 3 reads
`anim=stand drift=0.66`, and the fresh-world phase reads 0.10 and 0.00).
