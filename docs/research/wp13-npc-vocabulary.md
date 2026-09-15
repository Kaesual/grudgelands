# WP13 wave 2: the NPC vocabulary — six activities, seven professions, a capital probe

Status: shipped 2026-09-15 on `wp13-w2-npc-vocabulary`, based on main
`922bfd92` ("Extend the socket vocabulary for the wave-2 capitals").
Implements the wave-2 halves of `wp13-npc-sockets-contract.md` §8.2 (the
activity table) and §8.4 (the vendor kinds), whose registry rows the
coordinator landed before the lanes started. Round 3 — the first half of the
same sections — is [wp13-npc-work.md](wp13-npc-work.md).

## 1. What this lane owns and what it shipped

The coordinator's §8.5 split gives the NPC lane the *behaviour* behind the
names: animations, wielded items, stock tables, vendor entities, the spoken
lines, and the load measurement. The five capital lanes place the sockets.
So this lane ships:

| | |
| --- | --- |
| activities | the six of §8.2's second table (`mine`, `brew`, `carve`, `mourn`, `spar`, `forage`) |
| vendors | the seven entities of §8.4's second row (mason, brewer, bowyer, herbalist, armourer, tanner, embalmer) and their shelves |
| lines | **42** new race-flavoured lines (seven keys × six races), plus the line-key rule of §3 |
| probe | `run_npc_probe.sh`'s new **capital mode**, the open item of `wp13-highcourt-fill.md` §9.4 |

Nothing in `mods/MAPGEN` and nothing in `wp13/*.lua` was touched, so the six
start identity SHAs and Highcourt's blueprint digests cannot have moved — and
`start_identity.lua` reports the wave-1 digest `0bbf87a7…` unchanged (§6).

## 2. The six activities

`start_villagers.lua`'s `ACTIVITY` table gains six rows. Four of them are the
two shapes round 3 already had — a `work` animation loop with a tool, or a
`stand` pose with two seconds of swing every ten — and two are new shapes:

| activity | animation | wielded | note |
| --- | --- | --- | --- |
| `mine` | `work` loop | `default:pick_bronze` | §8.2's "pick"; the same item the smith's "hammer or pick" uses, because the game has no hammer |
| `brew` | `stand` + swing | `default:stick` | §8.2 explicitly allows "nothing or a ladle-like stick" |
| `carve` | `work` loop | `default:axe_stone` | "axe or pick"; the axe, because §8.2's feature is a log or a totem |
| `mourn` | `stand`, **head bowed** | none | see §2.1 |
| `spar` | `work` loop | the tier-1 sword, by FAMILY | see §2.2 |
| `forage` | `stand` + swing | none | the `tend` shape: picking is weeding |

`sweep` remains the only activity that moves; `mourn` is now the only one that
bows. Both are asserted against the contract in `start_npcs_kat`, in the
direction that catches an omission: every name in the transcribed vocabulary
must be implemented, and the two exclusive properties must be exclusive.

### 2.1 The mourner's head, measured rather than assumed

§8.2 asks for "head bowed if the mesh allows". The mesh does: `character.b3d`
carries the bones `Head`, `Body`, `Arm_Left`, `Arm_Right`, `Leg_Left` and
`Leg_Right`, read straight out of the model file (`strings -n 3` over
`mods/BASE/player_api/models/character.b3d`, in the evidence directory).

So the bow is `object:set_bone_override("Head", {rotation = {vec =
vector.new(-0.35, 0, 0), interpolation = 0, absolute = false}})`, written once
per activation next to the tool dressing:

* **relative, not absolute.** `absolute = false` composes the override with the
  animated pose (`lua_api.md`), so the mourner keeps whatever the stand
  animation does with its head; an absolute override would replace it and
  freeze the head outright.
* **once per activation**, on the same `self.temp` flag pattern as the wield
  dressing, so it costs one call and never a per-second write. The KAT measures
  exactly 1 write over ten seconds of the real tick.
* **guarded on the object**, not assumed: `set_bone_override` is Luanti ≥ 5.9,
  and an engine without it leaves the still stand §8.2's own "if the mesh
  allows" already permits. Nothing logs, because an older engine is not a
  defect of this table.

**The one thing that is NOT measured is the SIGN**, and it is named rather than
claimed: a headless server draws no frame. The evidence for `-0.35` is
VoxeLibre's trading piglin, the same Blockmen-derived humanoid lineage, which
nods DOWN at the trade with a Head rotation of `(-0.7, 0, 0)`
(`mobs_mc/piglin.lua:115`). If the user's playtest shows a mourner looking at
the sky, `MOURN_PITCH` is the whole fix — one constant, one sign.

### 2.2 `spar` wields a family, and there is no race axis to wield

§8.2 says "the settlement's tier-1 weapon" and the wave-2 brief said "the
settlement RACE's tier-1 weapon". **There is no race axis in the weapon
ladder, and inventing one is a design decision this lane declined to make.**
`items_crafting.md` §3.0.3 is explicit: one item per concept, six MATERIAL
tiers (Bronze … Abyssal Steel) and four weapon families (sword, dagger,
greataxe, staff), all material-named. Nothing in `docs/design` gives a race a
weapon, and `grug_classes`' six race definitions carry a passive each and no
martial flavour at all.

So "the settlement's tier-1 weapon" resolves with no invention to the T1 rung
of the one family that is `fixed = true` in `grug_gear`'s catalogue — always
on sale, never in the rotation pool — which is the sword, and which is also
the family every guard in the game already wears (`guard.lua`'s
`weapon_family = "sword"`). `grug_gear:sword_bronze` on every capital.

The activity row therefore names `weapon_family = "sword", bracket = 1` and
never an item string, and the resolution happens in `grug_visuals.compose`,
which owns the `grug_gear` dependency. `grug_mobs` has none (`mod.conf`), and
acquiring one for a single string would be the wrong trade.

**Ruled and accepted** by the coordinator on 2026-09-15 after the review of
this lane: `spar` uses the fixed sword family. So `docs/design/settlements.md`
naming the tier-1 sword records a decision rather than leaking an
implementation choice into design. If the user later wants a dwarf sparring
with a greataxe and an elf with a dagger, that is a `docs/design` addition (a
race → weapon family row) plus one table in this file, not a code problem.

### 2.3 The tool audit grew a weapon half

The load-time audit that reports the wielded tools now resolves the weapon
family too, through `core.global_exists("grug_gear")` rather than a dependency
— the only way to probe a global without tripping `strict.lua`. A family that
resolves to nothing is reported exactly like an unregistered item, because it
is the same failure for the player: an empty hand. The line is

```
[grug_mobs] settlement work activities: tools 7, weapon families 1, all registered
```

and `start_npcs_kat` asserts it verbatim (labelled counts rather than English
plurals, so it never has to read "1 weapon families").

## 3. The spoken line follows the activity where no tag was authored

A resident answers a right-click with `LINES[race][tags[1]]`. Exactly four tag
names are authored in `mods/` today: `work` (28 sockets), `bench` (23 literal
plus 4 the Highcourt plot helper passes positionally), `door` (20) and `fire`
(11).

`tags` is OPTIONAL on a `work` socket while `activity` is REQUIRED (§8.1), so
an untagged workplace would talk about nothing in particular while standing at
a grave or a cauldron. One line in `start_npcs.lua`'s `install` fixes that:

```lua
entity._grug_idle_tag = slot.tag or slot.activity
```

**This is the intended behaviour and not a compatibility measure** — a smith
should talk like a smith — and the coordinator ruled it so on 2026-09-15 after
the review of this lane.

### 3.1 How many sockets it actually affects, measured

The first version of this note said "on main every `work` socket carries a tag,
so nothing changes today". **That is false and the review caught it.** The tree
holds 48 `work` sockets and only 16 of them are tagged:

| where | `work` sockets | tagged |
| --- | ---: | ---: |
| the six starts (`wp13/<start>.lua`, literal socket tables) | 12 | **12** (`work`, `fire`, `bench`) |
| Highcourt (`plots.work(id, activity, x, z, face, tags, y)`) | 36 | **4** — the `{"bench"}` `sit` seats; `tags` is the sixth, optional argument and 32 calls omit it |
| Dur Brannoc | 0 | — |

So **32 of 48 `work` sockets are untagged**, and this line changes what key
those 32 residents answer with.

It is nevertheless behaviour-neutral **today**, for a narrower and more fragile
reason than the first version gave: `LINES` gained only the six WAVE-2 activity
names, and carries **no key for any round-3 activity name** (`chop`, `farm`,
`fish`, `pray`, `sit`, `smith`, `stall`, `sweep`, `tend`). So
`_grug_idle_tag = "chop"` still resolves through `race.default`, exactly as
`_grug_idle_tag = nil` did. `_grug_idle_tag` feeds nothing but the spoken line
(its only reader is `answer(...)` in `start_villagers.lua`), so there is no
other surface.

**The forward consequence, stated because it is real:** the first time anybody
adds a `chop` or a `tend` line for flavour, **32 Highcourt residents change what
they say** — 7 choppers, 9 tenders, 7 farmers, 3 fishers and the rest. That is
the point of the rule, not a hazard, but it is a deliberate step and this lane
does not take it: the nine round-3 activity keys are left absent ON PURPOSE
(coordinator's ruling, 2026-09-15), so that flavour pass is one visible commit
rather than a side effect of this one.

`LINES` therefore gains seven keys per race — the six wave-2 activity names and
`shade` — which is **6 × 7 = 42** new lines. A key nobody authors still falls
back to `default`, so a capital lane cannot produce a missing line whichever
way it tags.

`shade` is forward-looking data and **not** a gap this lane closed: the string
occurs nowhere in `mods/`, and its only occurrences in the tree are as the
SECOND tag of fixture sockets in two KATs. Only `tags[1]` is ever read, so no
NPC has ever asked for a `shade` line.

## 4. The seven profession vendors

`vendors.lua` registers seven more entities, **appended** to `PROFESSIONS`
because the salt is positional (`PROFESSION_SALT_BASE + index`) and
re-ordering the list would re-roll every existing shop's hourly shelf. Salts
21–25 are unchanged; the new ones are 26–32.

### 4.1 The shelves, and why they are thin

Every item on them was **measured**: one headless boot of this tree dumped all
**1012** registered item names with their `_grug_sell_price`
(`items.txt` in the evidence directory), and every name and every price
comparison below comes out of that dump. Two findings shaped the shelves:

* **There is no bow.** Nothing in the 1012 is a bow, a stave, a bowstring or a
  quiver. The only archery items in the game are `grug_mobs:arrow` ("Bundle of
  Arrows", the skeleton archer's drop, whose own item comment already says
  "there is no bow/quiver item yet") and `grug_decor`'s castle ARROWSLIT
  nodes, which are masonry. So the bowyer sells arrows, sticks and the two
  feathers, exactly as the brief allows — and gets no bracket tab, because
  there is no ranged family in `grug_gear` for one to reach.
* **There are no processed intermediate goods.** §3.0.3's leather grades are
  "named, not yet registered"; nothing in the tree is a rivet, a buckle, a
  bolt of cured hide or a jar. Twelve trades therefore share one pool of about
  forty sellable materials, so a handful of items appear on two shelves. Where
  that happens the PRICE IS THE SAME on both, so it is one good in two shops
  and never an arbitrage.

| kind | shelf (copper) | gear tabs |
| --- | --- | --- |
| mason | cobble 2, gravel 1, clay brick 2, stone brick 5, sandstone brick 5, stone block 6 | no |
| brewer | weak healing potion 8, wild cocoa 4, marshbloom 3, rock salt 3, apple 2 | no |
| bowyer | bundle of arrows 5, stick 2, feather 3, sharp feather 9 | no |
| herbalist | gravemoss 3, dragonweed 5, crimson lotus 8, sunleaf 3, venom gland 9, slime gel 7 | no |
| armourer | bronze bar 7, steel bar 26, heavy leather 16, heavy cloth 13, shiny scale 9 | **yes** |
| tanner | leather 8, light leather 6, heavy leather 16, sleek pelt 18, ape hair 10 | no |
| embalmer | bone 3, gravesalt 6, candle 4, linen scrap 3, rotting flesh 5 | no |

Four items are exclusive to a new shelf and sold nowhere else: the sleek pelt
and the ape hair (tanner), the shiny scale (armourer) and
`grug_materials:gravesalt` (embalmer), which is the undead region's own
cultural material.

### 4.2 The armourer's gear tabs, decided against §3.0.3

The brief asked for a decision. **The armourer gets the bracket tabs.** Eight
of the nine fixed items in a bracket catalogue are armour (`grug_gear`'s four
metal and four cloth pieces against one sword), so an armourer that could not
reach the tabs would be an armourer with no armour to sell.

§3.0.3 is satisfied: it forbids a second ITEM per concept, and two vendors
reaching one catalogue duplicate nothing — the race and general Quartermasters
already both do. What the round-3 lane's reasoning actually forbade is
re-listing the ladder on a general SHELF, which is why the armourer's own
shelf is materials and not a hand-copied ladder.

**Ruled and accepted** by the coordinator on 2026-09-15, with the costs named
rather than hidden. There are two:

* `sells_gear` (`trade.lua`) is one boolean over the whole catalogue, so the
  armourer's tabs also carry the sword and the rotating weapon extras. An
  armour-only tab is a second view of the same catalogue — a trade-UI change
  and a contract question, not this lane's.
* §8.4 allows one vendor per kind, so **a capital that places both a smith and
  an armourer has two shops selling the same fixed catalogue.** They are not
  copies of each other hour to hour — the hourly rotation is seeded per kind
  (salts 22 and 30), so the two rotating slots differ — but the nine fixed
  items are the same nine on both counters. That goes on the user's playtest
  checklist (§10) rather than being assumed desirable.

### 4.3 The money-loop audit now covers the profession shelves

`grug_traders/init.lua`'s second startup audit ("no vendor buy/sell spread
that prints money") walked the core stock and the six bracket catalogues only.
The five shelves round 3 introduced were outside it, so a butcher could have
been priced into a loop and nothing would have said so. Twelve shelves is
where that stopped being theoretical, and the audit now walks
`profession_stock` as well. All twelve pass: every shelf price is above the
item's discounted buy-back, which is checked on the discounted price even
though a profession vendor can never grant the kinship discount (it carries no
`race`).

## 5. The capital probe mode

`wp13-highcourt-fill.md` §9.4 declined to give `npc_probe` a Highcourt mode and
listed two reasons. Both are right, and both are answered by making it a MODE
with its own programme rather than a flag on the start one:

* **the readiness gate.** `grug_core.start_ready(race)` is a statement about a
  race's START, which for Highcourt is Dawnmere 1500 nodes away and ready long
  before a capital chunk exists. The capital programme does not ask it: it
  forceloads the capital and waits for the map to answer.
* **the scale.** A capital has no preload, 256 sockets against a start's
  eighteen, and an envelope no single emerge covers. The capital programme
  forceloads **every socket's own mapblock** (deduplicated by block
  coordinate, `limit = -1` to lift the 16-block `max_forceloaded_blocks`
  default) and **holds them for the life of the run**.

That last clause is the whole experiment. Round 3's evidence found Highcourt's
baker unplaced and diagnosed it as "the ground under him, not the socket": the
Highcourt harness emerges each mapchunk once and moves on, so the bakehouse
plot's block was unloaded again by the time the placement heartbeat reached
it, and a 180-second soak did not help because more time does not help a slot
whose ground is not loaded.

The programme is an inventory and nothing else — it displaces nobody, removes
nobody and spawns no hostile:

1. forceload the anchor grid, wait for the anchor column to answer (≤ 240 s);
2. plan one forceload per distinct socket mapblock **and per sampled point of
   every patrol loop's legs** (§5.1), issue them in batches of 24 a second,
   then wait until every planned block reports loaded — bounded by a stall
   clock (60 s without a new block) rather than only by a 300 s total;
3. let the heartbeat run until every socket the settlement owes is marked, capped
   at 120 s;
4. inventory: per role, per activity, per vendor kind, the walker share both
   as measured off the entities and as the placement engine's own census
   reports it, and then **one line per carrying socket with nobody standing on
   it**, carrying the node name, the loaded flag, the active flag and whether
   the placement engine's own **marker** is set.

### 5.1 What three runs of it taught, and what it asserts

The mode was written, run, and corrected three times, and each correction is a
statement about what a harness can honestly claim:

* **run 1** lost its own log: without `KEEP=1` the launcher deletes the run
  directory before the runner can copy it out, so a failing capital run
  reported nothing but the launcher's ten-line grep. Fixed in the runner.
* **run 2** found one gap of 181 and it was a *patrolling* guard. Its own
  socket's block was loaded and active; the guard was not on it, because a
  patroller is between waypoints by definition. So the plan now also holds the
  blocks along every loop's legs, sampled every 8 nodes with the y
  interpolated (a gate-tower loop climbs): 131 blocks became **221**, over
  **56 legs**.
* **run 3** found the same one gap anyway. That settled the question the other
  way: **no set of blocks can promise to contain a walking NPC**, and asserting
  `live == roster` would make this mode fail on a healthy capital. So the
  assertion moved to what the placement engine actually claims —

  1. `marked == roster - owed`: every socket the settlement owes is filled,
     less world.md §4a's booked guard refills. This is the strong claim and it
     is the one the round-3 open item asked for.
  2. no carrying socket is **unmarked**: a socket with neither an NPC nor a
     marker is a socket nothing was ever placed on, which is the shape of the
     round-3 baker.

  `live` is reported and never asserted: an NPC in an inactive mapblock is
  asleep, not absent, which is the same distinction `start_npcs.lua`'s own
  `strikeable` rule is built on. The marker is read straight out of
  `grug_mobs.storage`, so the probe asks the engine rather than inferring.

### 5.2 The baker, answered

**Neither the socket nor the placement was at fault. The harness was.** With
every socket block held, Highcourt's placement engine reports

```
[grug_mobs] start npcs human highcourt: guards 28/28 flair 144/144 vendor 7/7
            quest 2/2 new 18 pending 0 spare 26 residents 144 walkers 22
```

— `pending 0`, `vendor 7/7`, and `homes_bakehouse`'s whole plot populated. The
round-3 diagnosis ("what is missing is the ground under him, not the socket")
is confirmed exactly, and the 180-second soak it tried did not help for the
reason it gave: more time does not help a slot whose ground is not loaded, and
what this mode adds is not time but *holding the ground*.

The inventory on the user's gate seed:

| | |
| --- | --- |
| sockets / carrying sockets | 256 / **181** |
| roster / marked / owed | 181 / **181** / 0 |
| residents (entities / census) | **144** / 144 |
| walkers (entities / census) | **22** / 22 — **15.3 %**, inside §8.3's 10–30 % band |
| spare | 26 |
| roles | `guard_patrol` 8 standing of 9 loops, `guard_post` 19, `idle` 108, `quest` 2, `vendor` 7, `work` 36 |
| activities | `chop` 7, `farm` 7, `fish` 3, `pray` 1, `sit` 5, `smith` 1, `stall` 1, `sweep` 2, `tend` 9 (36) |
| vendor kinds | butcher, baker, fishmonger, smith, tailor, general, race — **all seven, one each** |

Every number matches what the Highcourt fill lane's KAT expects. Two of them
are worth naming on their own: `fish` and `pray` are animated in a real
settlement for the first time (round 3 could author neither in a start, for the
geometric reasons in `wp13-npc-work.md` §4), and no wave-2 activity appears —
correctly, because no capital places one yet.

Mode selection is a file, not an environment variable: `tools/luanti_headless.sh`
passes no environment into the Flatpak, so the runner stages its **own copy**
of `tools/wp13/npc_probe` under the output directory with a one-table
`mode.lua` in it and points `PROBE` at that. `loadfile` inside a mod directory
is what the engine's security sandbox allows. The repository's probe directory
is never written to.

## 6. Measurements

See §7 for the exact commands. Everything is in
`tools/wp13/evidence/20260915-npc-vocabulary/`.

### 6.1 Fixtures

| | before | after |
| --- | --- | --- |
| `start_npcs_kat` states | 20 | 21 (new: 17b, the two wave-2 shapes) |
| its fixture's roster | 13 of 16 sockets | 15 of 18 |
| its residents / walkers / share | 8 / 2 / 25.0 % | 10 / 2 / **20.0 %** |
| activities implemented | 9 | **15** |
| wielded tools / weapon families | 4 / 0 | **7 / 1** |
| `vendor_fixture` vendor entities | 13 | **20** |
| `micro_kat_fixture` trader projection | 13 | **20** |

The share moved because the fixture gained two `work` sockets and no `idle`
one, which is exactly what §8.3 says lowers it; 20.0 % is inside the 10–30 %
band. Both interpreters agree byte for byte: the WP13 final micro pair reports
`output_sha256=b3aa0177d8997a0d5019ffbd8c581842e3bbc10b9ddb11966a75da99348aef51`
under LuaJIT and under `tools/bin/lua51`.

State 17b measures, on the real residents the real placement engine put on the
two new sockets: the mourner's head override exists, is relative, is on the x
axis only and was written **once** in one activation; no other activity bowed a
head; the sparring resident was handed `weapon_family = "sword"`, `bracket = 1`
and no item, and the visuals seam resolved it to `grug_gear:sword_bronze`; the
untagged work socket answers with `mourn` and the tagged one still with `work`;
and every one of the seven new line keys is a line of its own rather than the
`default` fallback.

### 6.2 Identities

`luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua .` →
sha256 of the output `0bbf87a7253deadca55951752adde73e82c31cd10878dc64ef6d44af91ad1f5f`,
the wave-1 recorded value. Highcourt's blueprint digests are untouched by
construction: this lane changed no file under `mods/MAPGEN` and no
`tools/wp13/*.lua` other than `start_npcs_kat.lua` and the probe.

### 6.3 Static gates

`static.txt`: `luac51 -p` and the SETGLOBAL count per changed file (0
everywhere except the two files that legitimately declare their mod table),
the whole tree parsing, the five plain-5.1 sweeps scoped and tree-wide,
`check_fresh_server.py` PASS, and a re-check of every one of the 62 profession
shelf entries against the 1012-name engine dump (**no unregistered name**).
The three sweep-4 hits in `stock.lua` are pre-existing `|` characters inside
comments on lines this lane did not touch.

### 6.4 Engine

**The two startup audits, on the real server** (`probe-start/audits.txt`):

```
[grug_mobs] settlement work activities: tools 7, weapon families 1, all registered
[grug_traders] 12 profession shelves, 62 offers, all registered
```

No offer was dropped, so every one of the 62 shelf entries names an item the
engine really registers; `grug_gear` resolved `spar`'s family; and neither of
`grug_traders`' loop audits fired (no `MONEY LOOP`, no `CRAFT LOOP` line
anywhere in the log), which is the first run in which the profession shelves
were inside the money-loop audit at all.

**`run_npc_probe.sh` in START mode**, three boots on one world, unchanged
programme: `errors=0 complete=3`. Every round-1/2/3 claim still holds with the
wave-2 code in — the work residents stand on their sockets with their activity,
animation and tool on a fresh world and after two reboots; the nametag gate is
empty at 40 m and right at 20 m for all three peaceful families; the walker
reaches a second spot and the static residents reach none; the profession
shelves have offers; and a butcher composed without a settlement is restyled to
the settlement's race.

**`run_npc_probe.sh` in CAPITAL mode** on Highcourt: `errors=0 complete=1`.
221 blocks planned over 56 patrol legs, all loaded 28 s after the anchor came
up, the roster full 5 s later, and the inventory of §5.2. One gap, marked, a
patrolling guard.

### 6.5 The work tick's cost profile

`run_npc_load.sh`, one boot, the six starts one at a time (forceload the
arrival, settle 8 s, measure 30 s, release): `errors=0 complete=1 windows=6`.

**What is unchanged and is asserted structurally**, per start and per 30-second
window:

* **zero `core.find_path` calls** — in all six windows, exactly as round 3.
  (The run's total over 290 s is 6, all from the guards' patrol rescue, which
  is not a resident.)
* 11 active mobs, 6 residents (4 idle + 2 work), **walker share 16.7 %** in
  every start, minimum walker ring 3–5;
* mean server step 90.30–90.35 ms, worst 91.04–91.45 — the dedicated server's
  fixed 0.09 s step with headroom, i.e. the same non-measurement of the NPCs
  round 3 documented.

**The microbenchmark** (every settlement NPC's `do_custom` called once per
simulated second inside `core.get_us_time`): **21.60–39.70 µs per settlement
per simulated second**, 1.96–3.61 µs per ticking NPC over 11 of them, in the
order dawnmere 33.60, hearthpine 39.70, kapok 28.65, silverleaf 32.40,
stillgrave 21.60, sunscar 25.05.

The first version of this note carried "higher than round 3's 14.95–28.70 µs"
as an open item. **The independent review retired it by measuring, and this is
the measurement**: it re-ran the identical bytes with the identical harness on
the same machine, and the ordering of the settlements inverted.

| µs per settlement per simulated second | this lane's run | the review's re-run |
| --- | ---: | ---: |
| dawnmere | 33.60 | 41.65 |
| hearthpine | **39.70** | **17.75** |
| kapok | 28.65 | 33.75 |
| silverleaf | 32.40 | 21.00 |
| stillgrave | 21.60 | 22.15 |
| sunscar | 25.05 | 19.95 |
| range / mean | 21.60–39.70 / **30.17** | 17.75–41.65 / **26.04** |

Hearthpine goes from the top of the range to below round 3's own *floor*;
dawnmere from the middle to the top; the two orderings are essentially
uncorrelated, and the re-run's mean is the LOWER of the two. The spread inside
one run is larger than the distance between the runs — which is exactly what
round 3's own note warned about ("the trend inside each run is as large as the
difference between the runs"), and what a 20-sample integer microbenchmark
(`us_total` 833 against 355) can be expected to do on a workstation shared with
other lanes' engine runs.

**So the observation is noise below the measurement's own resolution and is
retired rather than carried as an open item.** Re-taking it on a quiet machine
would buy nothing: the measurement cannot resolve a difference this small.

What held in every window of BOTH runs is the part that is a claim about the
code: `find_path=0` per window, walker share 16.7 %, 6 residents of whom 1
walks, the fixed 90.3 ms step.

What the code says, against which the numbers are a sanity check rather than
the argument: a wave-2 activity adds to the per-second hot path exactly one
table lookup and two field reads (`apply_pose`'s early return for every
activity that is not `mourn`, and for `mourn` after its single write). It adds
no path-finding, no per-second property write and no new entity.

## 7. How to re-run it

```bash
bash tools/wp13/evidence/20260915-npc-vocabulary/static.sh
luajit -e 'io.write(dofile("tools/wp13/start_npcs_kat.lua")("."))'
tools/bin/lua51 -e 'io.write(dofile("tools/wp13/start_npcs_kat.lua")("."))'
luajit tools/wp13/final_micro.lua . /tmp/fm-luajit.tsv luajit
tools/bin/lua51 tools/wp13/final_micro.lua . /tmp/fm-puc51.tsv puc51
luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua .

# the engine, one server at a time, ports in this lane's own block
PORT=31610 tools/wp13/run_npc_probe.sh /tmp/npcvocab-start 531802985935182545 start
PORT=31620 tools/wp13/run_npc_probe.sh /tmp/npcvocab-capital 531802985935182545 capital highcourt
PORT=31630 tools/wp13/run_npc_load.sh /tmp/npcvocab-load 531802985935182545
```

## 8. What the review found

The independent review (2026-09-15, against head `90e6f35e`) reproduced every
gate — the static sweeps byte-identical to the committed `static.txt`, both
KATs under both interpreters, the final micro pair at `b3aa0177…`, the six
start identities at `0bbf87a7…`, and its own capital-mode, start-mode and load
runs, all `errors=0`. It raised **no blocker**. What it did find, and what this
note now says instead:

* **The line-key justification was false** (§3.1). "On main every `work` socket
  carries a tag" is wrong: 32 of the tree's 48 do not, because Highcourt's
  `plots.work(id, activity, x, z, face, tags, y)` takes `tags` as an optional
  sixth argument and 32 calls omit it. The change is safe today for a narrower
  reason, now written down, and the forward consequence is stated.
* **"43 new lines" was 42**, and `shade` was described as a gap this lane
  closed when it is forward-looking data nothing reads (§3).
* **The microbenchmark observation was noise** (§6.5). The review's re-run of
  the identical bytes inverted the ordering of the settlements, so the open
  item is retired with both runs' numbers rather than carried.
* **`kat/micro-kat-fixture.txt` could never re-verify**: LuaJIT's traceback
  ends in an ASLR address, and `sha256sum -c` over `files.sha256` failed on
  that one file of 52. The address is now replaced with `0xADDRESS` in
  `kat.sh`, so the capture is reproducible and the manifest checks 52 of 52.
* **Two of the lane's three flagged decisions were accepted** (the fixed sword
  family, the armourer's gear tabs) with one cost the note had not named — two
  shops on one catalogue in a capital that has both a smith and an armourer,
  now in §4.2 and on the playtest checklist. The third, the bow's sign, is on
  the checklist too.
* **The capital probe restates THREE engine rules, not one**, and the note said
  one: `capital_carries` against `build_rows`' `carries`,
  `CAPITAL_CARRYING_ROLE` against the six registered resolvers, and the marker
  key string `"startnpc:<key>:<id>"` against `placed_key`. All three match
  today and the review checked each. The first two have a cross-check (the
  census's own `roster`, printed on the same line); the third is a bare string
  — but if `placed_key` ever changed prefix the probe would report every
  carrying socket as unmarked and fail loudly, which is the safe direction.
* **The profession money-loop audit** (§4.3) is a widening of an existing
  audit, so it now judges five shelves it did not before. The review
  re-computed all twelve shelves independently against the item dump:
  `entries=62 moneyloops=0 unregistered=0`, and every shared item priced
  identically on both its shelves.

## 9. What is open

* **No wave-2 activity and no wave-2 vendor kind is placed anywhere yet.** The
  five capital lanes place them; this lane ships the behaviour and proves it
  on the fixture and, for the round-3 vocabulary, in the engine. The capital
  probe is the harness those lanes' sockets will be inventoried with.
* **The nine round-3 activity keys are deliberately absent from `LINES`**
  (§3.1). Adding the first one moves 32 Highcourt residents' dialogue, which is
  a flavour pass somebody should take on purpose.
* **A race → weapon family mapping** would be a `docs/design` addition (§2.2).
  The coordinator ACCEPTED the fixed sword family on 2026-09-15, so this is a
  future enrichment and no longer an open decision.
* **`tools/wp13/highcourt_kat.lua`'s `VENDOR_KINDS`** lists the five round-3
  kinds only. It is the Highcourt fill lane's file (§8.5) and Highcourt places
  no wave-2 kind, so nothing is broken; a capital lane that places one into
  Highcourt would have to widen it.
* **Submodules are not checked out in a git worktree**, so
  `tools/wp40/r7/micro_kat_fixture.lua` stops in
  `node_semantics_fixture` with `cannot open
  ./reference_projects/luanti/builtin/game/item.lua` — an environment gap of
  the isolated worktree, not of this change. It runs *past* the trader
  projection check at line 859, which is this lane's assertion
  (`#trader_defs == 20`); the check would have raised "trader registration
  projection differs" otherwise. On a checkout with submodules it also has the
  pre-existing `missing override target default:shovel_wood` gap round 3
  already recorded. The gate in `kat.sh` was an assertion about an ABSENCE
  (a crash before line 859 would also have printed "passed"), so it now prints
  the `micro_kat_fixture.lua` line numbers the traceback reached — 1074 here,
  which is past 859.
* **`tools/wp13/npc_probe/init.lua`'s patrol-leg planner caps a loop at 64
  waypoints** (`for order = 1, 64`) and would silently truncate a longer one.
  Highcourt's largest loop is 10, so nothing is affected; left uncommented
  rather than touched in the fix round, because editing the probe source would
  invalidate the `harness.sha256` the three engine runs were taken under
  without a re-run to replace them.
* **No render of a bowed head or a sparring pair**: a headless server draws no
  frame. What is documented instead is the exact bone, rotation and evidence
  for the sign (§2.1).
* **`spar`'s facing is inherited, not asserted.** A sparring resident faces its
  partner through the generic authored-`dir` rule, which is the right answer
  and needs no new code — but nothing in this lane's KAT reads a sparrer's yaw,
  so a capital lane that places a PAIR facing the same way would not be caught
  here. §8.5 gives the feature-under-`dir` check to the placing lane's own KAT;
  flagged to those lanes.
* **The capital mode PRINTS its headline numbers and asserts only two of
  them** (§5.1): the marker count and "no unmarked carrying socket". Residents
  144, walkers 22, share 15.3 %, work 36 and the seven vendor kinds are report
  fields. A capital lane using this harness as a gate should know it will not
  catch a walker-share drift or a vendor kind that stopped being placed while
  its marker was set — and that `event=capital_gap` lines must never be pinned,
  because their count varies run to run (see the checklist below).

## 10. For the user's playtest round 4

Three things this package cannot settle from a headless server, in the order
they are quickest to look at:

1. **Does the mourner bow its head DOWN?** `MOURN_PITCH = -0.35` in
   `start_villagers.lua`. The mechanics are asserted by the KAT (relative
   override, x axis only, one write per activation); only the SIGN is
   unverified, and its evidence is VoxeLibre's trading piglin nodding down at
   `(-0.7, 0, 0)` on the same humanoid lineage (§2.1). If the mourner is
   looking at the sky, flipping that one constant is the whole fix. Nothing
   places a `mourn` socket yet, so this becomes visible when a wave-2 capital
   lands.
2. **A capital with both a smith and an armourer has two shops on one
   catalogue.** §8.4 allows one vendor per kind, and both now carry the gear
   bracket tabs — with different hourly rotations (salts 22 and 30), so the
   two shelves genuinely differ hour to hour. That is probably what a capital
   should feel like, and it is named here rather than discovered: if it reads
   as a duplicate, the fix is to take `brackets` off the armourer and give it
   an armour-only view, which is a trade-UI change (§4.2).
3. **Walking guards are invisible to a snapshot, and that is normal.** The
   capital probe reported **one** gap on this lane's run and **two** on the
   review's re-run of the same bytes (`homes_tavern/homes_tavern_watch` both
   times, plus `lore_shrine/lore_shrine_watch` on the re-run) — always marked,
   always a patroller, roster always full. That variation is the positive
   evidence for the run-3 decision not to assert `live == roster`: a capital
   that showed 181 of 181 standing would be one where nobody was walking.
