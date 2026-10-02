# Round 29 — Economy and travel: round plan

Coordinator: Claude (Opus 5.5), 2026-10-02. Status: **approved by the user 2026-10-02** (wave 1 go, decisions of §6); **complete 2026-10-02** ([completion](#completion-2026-10-02)), not pushed.

This plan schedules four approved inputs; it does not repeat their rules:

| Input | What it decides |
|---|---|
| [economy-vendor-plan.md](economy-vendor-plan.md) | vendor model, loot price formula, WP44 cutover, gem depth tiers, lanes E1–E5 |
| [travel-boats-waypoints-plan.md](travel-boats-waypoints-plan.md) | boats as water mounts, shipwright, Kraken retune, waystones, lanes B/K/W/M/D |
| [round29-quests-plan.md](round29-quests-plan.md) | quests on the Round 28 framework, lanes Q1–Q9; Q1–Q6 answered by the user 2026-10-02 (all as recommended) |
| Mapgen bundle (user, 2026-10-02; BACKLOG "Round 28 carry-overs and Round 29") | gem tiers, `apex_sockets` removal, Battlegrounds +50 % in z, middle road, mapgen band data |

Routing (user, per session): Claude orchestrates; **Opus implements and
reviews** (independent Opus review per lane, never the implementer);
**GPT-6 Astra** only art and quest texts.

## 1. Mapgen bundle — measured scope

A read-only scoping pass (2026-10-02, offline LuaJIT runs of the zone field
on five seeds, no engine runs) found:

- **Battlegrounds +50 % in z is one parameter.** Zones are a power diagram
  over segment sites; the four Battlegrounds zones sit on z = 0, the six
  contested 31–40 zones on z = ±700, and `front_bias = -160000`
  (`wp40/source/simple_map.lua:174`) sets the border at |z| ≈ 236. Setting
  it to about **+15000** moves the border to |z| ≈ 361: Battlegrounds area
  +50 % (measured +42…+55 % over five seeds), both factions lose about the
  same area, x-borders between the Battlegrounds zones, all 37 neighbour
  pairs, islands, channels, boat paths and landings are unchanged; the
  channel self-check still passes (narrowest strait 300–312, limit 104).
  *Why this route:* no new geometry code, total map size unchanged, exactly
  the user's restatement.
- **20 anchors in the donor strips move** home-ward by about 120 nodes
  (outposts at ±434…±566, bandit frontier camps, clash sites, rares), in
  `simple_map.lua` **and** the same rows of `wp40/r20_poi_catalog.lua` (a
  mismatch fails the load). Anchor count and order stay 100, so the frozen
  consumer-payload digest does not move.
- **Middle road:** one extra `pair` step Highcourt (0, −1500) ↔ Gor Drazhak
  (0, 1500) in `wp40/road_layout.lua` inputs; the router exists. A failed
  route only counts in `stats.failed`, so the lane must assert it. The two
  bandit camps on x ≈ 0 (Coalbrand, Sunderstrap) move to |x| ≥ 80 so the
  road runs straight. The road gets no waypoint (travel plan §4).
- **Band data:** `simple_map.lua:87,88,90` → Gravesalt 51–60, Causeway 41–50,
  Skyglass 51–60; the level field adapts itself. The gameplay override
  `grug_core/zone_bands.lua` then becomes empty and is **deleted** with its
  readers (no placeholder).
- **`apex_sockets` removal:** data in `simple_map.lua`, the 24-count pin and
  overlap checks in `r6_settlement.lua`, dead `exact_column` branches in
  `zones.lua`, two tool fixtures. No frozen digest.
- **Gem tiers:** resource rows become universal with one band each
  (`r7_r6_manifest.lua`, `r6_content.lua`, `wp43_handoff.lua`,
  `r6_settlement.lua`); the frozen pin in `r7_manifest.lua:484-492` moves
  once (fails loudly, re-pinned in that lane); gameplay side in
  `grug_materials`, `grug_smelting`, `grug_artisans`, `enchants.json`, help.
- **WP17 mapgen:** the waystone node does not exist yet and must be
  registered before content resolution; capitals have the socket, starts
  need a pad + socket; the shipwright socket goes into the shared stable
  design.

Caches (D71 layout cache, pregen identity) hash the mapgen tree and
invalidate themselves. Spawn recipes contain no coordinates; the spawn tools
are re-run on the new world.

## 2. Lanes

| Lane | Content | Main files | Depends on |
|---|---|---|---|
| **Q1** Quest core | placeholders filled from `spawn_regions.describe`, load check against fixed compass words, copper from weight when omitted, ledger routes 31–40 (three zones), 41–50, 51–60 (two each) | `grug_quests`, `tools/r28_design` | — |
| **E1** Traders and prices | economy plan E1, plus claim-station repair (D7), loot text pass (identical tier texts, "Spider Silk" from outlaws), WP5 marked done | `grug_traders`, `grug_gear`, `grug_mobs/subtypes.lua` price line, `grug_materials` prices | — |
| **B** Boats, shipwright, Kraken | travel plan lanes B and K | `grug_mounts`, `grug_mobs/kraken.lua`, status icon | — |
| **W** Waypoints incl. their mapgen | travel plan lane W **and** its mapgen items §4.1–4.3 (waystone node in `grug_mapgen/world_nodes.lua`, capital waystones, start pads, shipwright socket + role) | new travel mod, `grug_home/travel.lua` helper, `grug_map`, `wp13/*`, `settlement_sockets.lua` | — |
| **M-res** Gems + `apex_sockets` | economy plan E2, `apex_sockets` removal, the `r7_manifest` re-pin | `wp40/r6_*`, `r7_r6_manifest`, `wp43_handoff`, `r7_manifest`, `simple_map.lua` 357–560, gem gameplay files | merges before M-geo (owns the re-pin) |
| **M-geo** Bands, Battlegrounds, middle road | band data → `front_bias` + anchor moves → middle road; delete `zone_bands.lua` | `simple_map.lua` 87–90/174/237–338, `r20_poi_catalog.lua`, `road_layout.lua`, `grug_core` readers, tools | rebases on M-res |
| **A** Art (Astra) | waystone texture, waypoint map/minimap marker, two boat item icons, boat status icon; boat hulls: a licensed mesh if one fits, else Astra textures on a simple hull | textures only; lanes B/W integrate | — |
| **Q2–Q7** Race tracks | one lane per race, Opus structure → Astra text pass → Opus re-validation; Q2 starts from `r28-c2` | `grug_quests/data/zones/*` of the track | Q1 merged **and** the spawn playtest evaluated |
| **Q8** Contested 31–40 | both factions' three contested zones | their quest files | Q1, playtest, final check after M-geo |
| **Q9** Front and islands | 41–60 front quests, repeatables, island bounties (boat access) | `*.front.quests.json`, 41–60 zones | Q1, playtest, B merged (island route) |
| **E4** Prices from income | mount, respec and both boat prices from a per-band income estimate | `grug_mounts`, `grug_classes` placeholders | E1 + quest lanes |
| **D** Documentation | economy plan §7, travel plan lane D, `world_zones.md` §7.3/§8.3/§9.2/§11, `spawn_regions.md`, AGENTS, BACKLOG/ROADMAP/README | docs | end of round (lanes update their own design docs in-lane) |

Changes against the input plans, with reasons:

- **E3 dropped**: Q1 computes copper from weight (Q4 = yes), and the
  legacy quests are replaced, not recomputed.
- **Travel plan lane M split up**: waystone node, pads and shipwright socket
  go into lane **W** (one owner for the node from definition to placement;
  no hand-over of a node name between lanes); the Battlegrounds/road check
  of §4.4 goes into **M-geo**.
- **Mapgen bundle in two lanes** (M-res, M-geo): disjoint hunks of
  `simple_map.lua`, different risks (pins vs. geometry), each with its own
  short engine run.

## 3. Waves

**Wave 1 — now, independent of the spawn playtest (6 lanes + art):**
Q1, E1, B, W, M-res, M-geo, A.
*Why now:* none of them builds on spawn density; they share no files except
two noted contact points (below).

**Wave 2 — after the spawn playtest is evaluated and Q1 is merged:**
Q2–Q7, Q8, Q9 (staggered so at most eight lanes run at once). Playtest
findings on spawn regions become a small fix lane first if needed.
*Why wait:* 300 quests on top of a density or region problem would be
rewritten.

**Wave 3 — integration:**
1. Merge order for the world: M-res → M-geo → W (mapgen part).
2. One integration check (§5), then **one fresh world** for the user.
3. Re-run `tools/r28_regions/run.sh`, `quest_targets.py` and the world view
   (`tools/r28_world/run.sh --before 1910d8ea`) on the new geometry; quest
   lanes still open re-validate their targets.
4. E4 prices, then D.

Contact points:

- **E1 ↔ M-res** both touch `grug_materials` (`registry.lua`, `ores.lua`):
  E1 prices, M-res gem rows. The price formula reads the gem tier, so it
  picks up M-res's tiers without coordination; whichever merges second
  rebases.
- **B ↔ W**: W places the shipwright socket, B registers its role handler.
  Until both are merged no shipwright stands there; nothing fails.

## 4. Rules for every lane

- AGENTS.md; `tools/check_lua.sh` on every changed Lua file; LuaJIT only
  (PUC ignored during development, optional crash smoke at the end).
- Headless only through `LC_ALL=C tools/luanti_headless.sh`, own run root,
  kill only your own run, `pgrep` clean afterwards; never the user's Luanti
  folder.
- Mapgen budget: few engine runs of at most about 5 minutes over a chosen
  region, one final check of about 15 minutes, never a full world, no
  repeats.
- Fresh-server mode: no migrations, no compatibility aliases (old gem
  grades, old prices, `zone_bands.lua`).
- Performance is reported as a comparison, never a target; noticeably slower
  or much more complex → back to the coordinator.
- Quest texts: no item tooltip texts, no fixed compass words, places and
  directions only as placeholders.
- Agents never push; the coordinator merges after review, the user pushes.

## 5. Verification

Offline (per lane): load validators, portable tests, `validate.py`/ledger,
zone-field check on five seeds (M-geo: area, strait, neighbour pairs),
`tools/r25_road_poi/world.lua` on three seeds (M-geo: middle road exists,
`failed == 0`, |x| < ~150 at z = 0).

Engine runs (≤ ~5 min each):

1. M-geo: x −200…200, z −700…700 at the surface — road crossing, moved
   camps and clash sites, band border, clean load.
2. M-res: a 64 × 64 column y +50…−1300 — each gem only in its band, about
   one per 512 host nodes.
3. W: Dawnmere (0, −2550) and Highcourt (0, −1500) — pad, waystone, socket.

Final integration (~15 min): the x = 0 strip Highcourt → Gor Drazhak plus
the west island approach (−2500, ±125).

User (GUI, fresh world): the economy plan's test list (§8), the travel
plan's list (§7, 17 items), the quest sample per track (Q3), and a look at
the wider Battlegrounds and the middle road.

## 6. User decisions (2026-10-02)

1. **Wave 1 go** with the seven lanes Q1, E1, B, W, M-res, M-geo, A, plus
   the playtest fix lane P (§7).
2. **Bandit camps on x ≈ 0** (Coalbrand, Sunderstrap) move to |x| ≥ 80 so
   the middle road runs straight (lane M-geo).
3. **Boat hulls:** first choice the two boats of *Lord of the Test* (a slow
   and a fast one) if their licences allow it; otherwise the *VoxeLibre*
   boat for both tiers, the fast one with a sail added by Astra (lane A).
   Lane B verifies the licence and records it in
   `grug_mounts/LICENSE-media.md`.

## 7. Spawn playtest (user, 2026-10-02) and lane P

Checklist points 1–5 (start zone, names, quests, mobs, combat input) are
fine. Findings:

| # | Finding | Ruling / action |
|---|---|---|
| P1 | Mobs show a particle effect when they spawn; it was never asked for and particles "pop up" everywhere while walking. | Remove it. |
| P2 | Leaders with 2× HP are too strong. | Leader HP multiplier **1.5×** (size stays 1.15×). |
| P3 | Dawnmere's first quest says "Defeat Boar or Small Boar"; Dawnmere spawns only Small and Aggressive Boars. | Leftover of the mechanical legacy split (base mob kept next to the appended sub-type). Drop base-mob targets from legacy quests wherever the zone's recipe never spawns them, so names match the world until Q2–Q7 replace the files. |
| P4 | The Basic Crafting Book shows only two undiscovered T6 recipes. | Check whether that is the intended T6 content of that book; fix if it is a bug, otherwise report the reason. |

Lane **P** runs in wave 1; it touches `grug_mobs` and legacy quest data,
which no other wave-1 lane edits.

## Completion (2026-10-02)

Every lane below is merged on local main (last commit `2b40d5b5`, E4);
each was independently reviewed by Opus, and the coordinator ran the gates
on main after every merge (the `tools/r2*_*/portable_test.lua` fixtures,
`tools/r28_design/validate.py`, `tools/check_fresh_server.py`,
`quest_targets.py`, a headless boot). The quest lanes were merged together
through one integration branch after the user approved a quest sample
per track (quests plan Q3):
quest targets ok 1033, 0 missing; every fixture and the headless boot
passed. Not pushed.

**Final engine check (§5), PASS** on seeds 42 and 20261002: the middle road
is continuous and reaches the capital gates; the Battlegrounds borders lie
at |z| ≈ 320–452; levels stay in their bands; the moved camps and clash
sites are protected; the channel is intact; 12 waystones and 6 shipwright
sockets with their Shipwright NPCs; gems only in their band; a clean load
with the 38 region maps built at start in 9.5–10 s. One finding: the
dragon-island boat landings are mostly a one-node shore strip below high
cliffs (open item below). Next: synchronization, then the user's GUI test
on a fresh world (checklist below).

### Shipped, by lane

- **P** (`b13cfa12`), the spawn playtest fixes (§7): P1 no smoke puff when
  mobs_redo places a mob (one GRUG PATCH); P2 leader HP 1.5× (size stays
  1.15×); P3 legacy kill objectives dropped 73 targets their zone's recipe
  never spawns (since replaced by the new quest files); P4 was a bug — the
  Basics book took gear one tier low and bars and tools as T1; its T6 page
  grows from 2 to 36 recipes.
- **B** (`f6652818`): boats as water mounts in `grug_mounts` (Boat L15,
  4 nodes/s; Improved Boat L30, 8 nodes/s; owner-bound skill items, summon
  only with the feet in water, gone once off the water, damage ejects), the
  Shipwright beside every capital's Riding Trainer, *Lord of the Test* hulls
  (WTFPL); the Kraken Guard swims 10 nodes/s in deep ocean and 5 elsewhere,
  view range 40 ([boats.md](../design/boats.md)).
- **W** (`e3e10df5`): the waystone node `grug_mapgen:waystone`, placed by
  the mapgen in all six capitals and on a new pad in all six starts;
  discovery by proximity or right-click, instant free travel between the own
  faction's discovered stones through one shared travel path with home
  return and respawn (`grug_home/travel.lua`); the waypoint marker on the
  Map tab and minimap; the shipwright socket in the shared stable
  ([world.md](../design/world.md) §6).
- **M-res** (`56753932`): gems by depth, T1 Citrine, T2 Jade, T3 Garnet,
  T4 Sapphire, T5 Ruby, T6 Diamond, each only in its own tier rock at about
  one per 512 host nodes; no G1/G2 grades; `apex_sockets` removed; the
  frozen WP43 projection re-pinned once. Mob gem drops follow the tiers
  (Land Guard Diamond, Dungeon Master Sapphire, golems Citrine).
- **Q1** (`07ddf3cb`): quest text placeholders `{dir_from_giver:T}`,
  `{dir_of:P:T}`, `{zone_area:T}`, `{name:T}` (titles only `{name}`); fixed
  compass words fail the load; copper from weight; ledger track routes;
  every zone's region map built at server start (+8.8–9.6 s boot, +53 MiB
  Lua heap) ([quests.md](../design/quests.md) "For content lanes").
- **M-geo** (`33ac05f9`): mapgen band data (Causeway 41–50,
  Gravesalt/Skyglass 51–60) and `grug_core/zone_bands.lua` deleted;
  `front_bias` +15000, Battlegrounds +49.9 % in area over 15 seeds; 20
  anchors moved home-ward; Coalbrand Yard and Sunderstrap Camp at x = ∓96;
  the middle road Highcourt ↔ Gor Drazhak across z = 0; a steep camp belt
  falls back to its flattest block up to slope 0.5; the zone atlas probe
  reads the spawn recipes ([world_zones.md](../design/world_zones.md)).
- **E1** (`a429db63`): one price module (`grug_traders/prices.lua`, rules
  in `price_rules.lua`) for every payout: loot and gathered goods by class
  × tier (band medians 4.3 / 9.0 / 16.7 / 39.0 / 147.6 / 239.3c per kill),
  processed goods by their inputs, free world materials worth 0, 5 %
  buy-back on vendor goods; the Common gear axis 25c … 25s; shelves by the
  vendor rule; repair at crafting stations in an active claim (D7); the loot
  text pass (Raw Silk); the fishing rod a T1 craft from 3 sticks + 2 thread;
  sticks unsellable ([economy.md](../design/economy.md)). WP44 and WP5's
  price parts are delivered.
- **T** (`8f063274`): quest tooling for the new format —
  `quest_targets.py` checks roles, areas, leaders and placeholder targets on
  every seed; the Q0 portable test runs the shipped files over the real
  registrations; the B4 legacy oracle retired; region stats re-rendered on
  the new geometry; a cross-zone leader counts as spawned.
- **A** (`7e696133`): six textures by GPT-6 Astra (CC0): two boat icons,
  the boat status glyph, the waystone (side and top) and the waypoint marker.
- **Q2–Q7** (`9ae075dc` … `49be16c7`): new quest files per race track,
  Opus structure and an Astra text pass: Human 54, Dwarf 58, Elf 71,
  Undead 53, Orc 48, Troll 63 quests.
- **Q8a / Q8t** (`3a436992`, `87db976c`): the contested 31–40 zones, 35
  Accord and 30 Throng quests (79–85 % of the band).
- **Q9a / Q9t** (`0ffd0804`, `384d86bd`): front quests 41–60 from the
  31–40 outposts and capitals, repeatable bounties and island bounties
  (boat access), 40 Accord and 39 Throng quests.
- **Integration** (`c8c6f505`): the legacy-only P3 check retired; 491
  quests in 42 files replace the 240 legacy quests (55 repeatable, 56
  optional, 15 group).
- **E4** (`8b3324fc`, `d20f91d9`): prices from a per-band income estimate
  (`tools/r29_e4/income.py`): riding 1s10c / 7s / 1g63s / 7g33s, Boat 1s10c,
  Improved Boat 7s, respec 15c / 35c / 75c / 1s90c / 7s / 12s; no "Price
  pending" state ([economy plan, E4 completion](economy-vendor-plan.md#e4-completion-2026-10-02)).
- **Performance review** (`0791e6be`, read-only):
  [perf-review-2026-10.md](../research/perf-review-2026-10.md), 22
  findings and a region-map file-cache design; it becomes Round 30.
- **D**: this section, the status files, the design-doc leftovers, the
  zone atlas regenerated with the new quests, the `quest_targets.py`
  legacy path removed.

### Rulings made during the round

- **Wave 1 (coordinator and user, 2026-10-02):** a bought boat is
  ownership only, its item comes from the Skills page like riding; using
  another tier's item replaces the active mount or boat. The fishing rod is
  T1 (3 sticks + 2 thread); sticks are not bought back and no longer drop.
  Quest titles take names only; every zone's region map is built at start
  instead of at first use (0.1–0.6 s blocked the server). Blackwind Rise's
  belt stays as it is (camp fallback on three seeds).
- **Spawn playtest P1–P4:** as in §7.
- **Sister access:** an entry quest of a 20–30 zone requires nothing from
  another zone, so any race can pick it as its sister zone.
- **Uniform sizing:** every 20–30 zone offers at least about 30 % of the
  band on its own (frame 35–50 %); the race's own main route keeps about
  60–70 %, the rest as "Optional:" quests. The Troll track keeps its
  heartland sizes (the second heartland stands in for the sister).
- **Uniform location text:** never "{name:X} {zone_area:X}" (the place
  twice); a clause or the name only.
- **Heartland exits:** every heartland hands on (no dead end after its
  last quest).
- **Six-seed robustness:** every area and placeholder target forms on seeds
  42, 7, 2026, 1234, 99999 and 314159.
- **Front bounty baseline N = 2:** the 41–60 budget counts two repeats per
  bounty (Throng 72 / 68 %, Accord 70–73 / 67–70 %;
  [quests.md](../design/quests.md)).
- **Prices kept:** no band-5 loot smoothing now (Expert Riding 1g63s against
  1g38s on the target axis, Master 7g33s against 8g76s).
- **Performance (for Round 30):** mobs give up unreachable static targets
  (#4); the region-map file cache, yes; the Map tab redraws the arrow and
  rebuilds at most every 2 s, only on a signature change, with a shared
  marker style (#3); the surface spawn ABMs are retired where the region
  spawner is authoritative and the rest (underground, ocean, rift) merge
  into a few ABMs (#11); the other findings as recommended.

### Open items

In [BACKLOG](../../BACKLOG.md#round-29-carry-overs): Round 30 performance
(lanes P1–P4), band-5 loot median smoothing, PvP and enemy-guard quests
the new quest format cannot express, possible bugs (Dawnmere NPC
duplication seen once, `general_attack` eye height), the dragon-island
landings (a walkable beach or ramp at each), the Pallcloth Den trail along
the front, thin front areas (`tomb_fen`, `siegecrest`), the legacy
quest fields the game still reads, and two stale fixtures.

### Playtest checklist

On a fresh world (all of Round 29 needs one):

1. **Quests, start zone:** the first quests send you to named regions with
   a direction ("southeast from here", "in the east of Dawnmere Fields");
   no text has an unfilled `{…}` and no fixed compass word; copper rewards
   look small but fair; the flow start → home zone → capital → heartland
   hands on without a dead end.
2. **Quests, heartland and sister:** "Optional:" quests appear beside the
   main line; another race's 20–30 zone offers quests without requirements
   from its own track.
3. **Contested 31–40:** each of the faction's three zones has quests at its
   outposts and capital; the front line opens toward 41.
4. **Front bounty:** take a repeatable bounty at 41+, turn it in, see
   "Repeatable again in N min.", take it again after the cooldown (front bounties 20–30 min, island bounties 60 min).
5. **Economy (economy plan §8):** buy and sell at a start vendor and a
   profession shop; removed goods are gone; sell a stack of T1 and of T4
   loot and compare with the gear prices; enchant at T2 and T4 with a
   depth-mined gem; repair one item at a trainer and at a crafting station
   inside your active claim.
6. **Gems by depth:** mine each gem in its band (Citrine in stone above
   −100 … Diamond below −1000) with the right pick; the wrong pick cannot
   dig it.
7. **Prices:** Apprentice Riding 1s10c, Journeyman 7s, Expert 1g63s,
   Master 7g33s; Boat 1s10c, Improved Boat 7s; the second respec costs the
   bracket's price (the first is free).
8. **Battlegrounds:** wider in north–south than before; the middle road runs
   from Highcourt to Gor Drazhak straight across z = 0; Coalbrand Yard and
   Sunderstrap Camp stand clear of it.
9. **Boats and waypoints (travel plan §7, items 1–17):** see the
   [travel plan's GUI list](travel-boats-waypoints-plan.md#7-gui-test-list-fresh-world-after-the-mapgen-bundle):
   the Shipwright beside the Riding Trainer, buying and summoning the Boat in
   water only, waterfall and dug-out water, ejection by damage, the Improved
   Boat at 30, the channel row to an island beach, the Kraken in deep ocean;
   the own start's waystone known, discovering a capital waystone, instant
   travel, combat and enemy-faction refusals.
10. **Island landings:** land a boat at both landings of each dragon island
    and try to step ashore; the engine check found mostly a one-node shore
    strip below cliffs 40–130 nodes high, so note where you cannot get up.
11. **Spawn fixes:** no smoke puff when mobs appear; leaders have a quarter
    less HP than before (1.5× instead of 2×); the Basics book lists T6 recipes.
