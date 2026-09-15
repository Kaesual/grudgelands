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
| `final_micro-luajit.tsv`, `final_micro-puc51.tsv` | the WP13 micro pair, byte-identical, `output_sha256=e257b5804bcf5c5f3dc8b1c23665bdc69cc8fde52eb350f131b92200fa1d23c3` under both |
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
| mean server step | 90.24–90.33 ms | 90.19–90.27 ms |
| worst server step | 91.00–92.16 ms | 90.93–91.05 ms |
| smallest walker ring | — | 3 (Stillgrave, Dawnmere, Sunscar) to 5 (Kapok) |

The mean server step is not by itself a measure of the NPCs: a dedicated server
runs a FIXED step (`dedicated_server_step`, 0.09 s) and only exceeds it once it
cannot keep up. It says there is headroom. What measures the NPCs is the
microbenchmark beside it — every settlement NPC's `do_custom` called once per
simulated second inside `core.get_us_time()`:

`npcs=` in those lines is how many NPCs of the settlement have a `do_custom` at
all, so the denominators differ: 7 before (three guards and four villagers) and
11 after (the elder and the vendor gained a tick for the nametag gate, and there
are two more residents).

| | before (7 ticking NPCs) | after (11 ticking NPCs) |
|---|---|---|
| per settlement-second | 18.70–39.65 µs | 14.95–28.70 µs |
| per NPC-second | 2.67–5.66 µs | 1.36–2.61 µs |

**What is defensible from this is that the cost stayed in the same
tens-of-microseconds band while the settlement gained two residents and four
ticking entities** — under a tenth of a percent of one 90 ms server step either
way. An earlier draft of this note read the two ranges as a speed-up; that does
not survive looking at the windows IN ORDER (after: 2.61, 1.36, 2.57, 1.46,
2.25, 1.39 — Dawnmere, the first window, is the worst in its own run, and the
spread inside a single run is as large as the difference between the runs). The
ordering effect is a warm-up artefact of measuring the first settlement first,
so the honest claim is "unchanged", not "cheaper".

Two further caveats on this number, both in the direction of a FLOOR:

* the microbenchmark runs with **no connected player**, so the two things a
  player switches on — the activity animation inside the 24-node watch radius
  and the nametag gate's property writes — are not in it. Both are bounded by
  construction (one animation write per change, one nametag write per 25/30 m
  crossing), and the KAT measures them: 1 animation write in 120 s of
  hammering, 6-7 in 30 s of swinging;
* a forceload activates the blocks but is not a player, so the vendor presence
  poll is idle too.

Both rows above are from runs with no other server competing. An earlier
"after" run taken while four other lanes had their own headless servers up
(`uptime` load average 7.7 on 16 cores) read 14.3–62.4 µs per settlement-second
— which is what the spread of this measurement looks like under contention, and
why the final pair was taken on a quiet machine.

`find_path_total` over a whole boot is 3 before and 6 after; those calls happen
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

event=work phase=fresh    socket=work_woodpile activity=chop anim=stand ring=none drift=0.00
event=work phase=fresh    socket=work_garden   activity=tend anim=stand ring=none drift=0.00

event=ring socket=idle_west_door   walker=true  ring=4
event=ring socket=idle_forge_door  walker=false ring=3
event=ring socket=idle_plaza_bench walker=false ring=4
event=ring socket=idle_workyard    walker=false ring=2
event=ring_done walkers=1 static=3

event=vendor_skin key=hearthpine race=dwarf before=grug_visuals_skin_human.png after=grug_visuals_skin_dwarf.png want=grug_visuals_skin_dwarf.png

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

The review of this lane added two more claims to the same run (`event=ring`,
one line per idle resident, and `event=vendor_skin`): every WALKER is handed a
ring of at least two spots -- Stillgrave shipped a ring of ONE and therefore no
moving resident at all until `WALK_RADIUS` became a preference rather than a
wall -- and a profession vendor placed without a settlement field composes the
Accord fallback and is recomposed as the settlement's own race by the restyle
hook the placement engine now calls after `install`.

Both reboots read `drift=0.00` for both work residents, with
`item=default:axe_stone` back in the woodcutter's hand: boot 1's own wanderer
phase teleports the whole roster forty nodes off its sockets, and by the time
the world is booted again they have walked back. (An earlier run of this probe
caught one of them mid-walk at `anim=walk drift=1.31`, which is what the walk
home looks like while it is happening.)

`item=nil` on `work_garden` is correct: `tend` is one of the activities that
wields nothing (contract section 8.2).
