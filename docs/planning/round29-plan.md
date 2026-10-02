# Round 29 — Economy and travel: round plan

Coordinator: Claude (Opus 5.5), 2026-10-02. Status: **approved by the user 2026-10-02** (wave 1 go, decisions of §6).

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
