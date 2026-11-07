# R70 DESIGN check (page 3a715b08)

**Verdict: FIX FIRST.** Concept and numbers hold. One capital's layout does not work, the throne room shrinks unannounced, and the schedules are not exact.

## Must fix (ranked by how far they mislead the decision)

1. **Highcourt fails as drawn (C022, C026, "rear bypass").** `chapel_quest` (−22,27) stands inside the castle (x ≥ −22). The chapel's only doors (−24,27/28) open east into the castle wall. The west bypass (x=−27, width 5) crosses the chapel footprint (−34..−24, 20..34). `validate_geometry` tests neither. Fix: shift chapel and `north_house` about 8 west (±57 allows it), carry the socket, add road and door checks.
2. **The throne room shrinks.** Reserved: 23×15 = 345 nodes². Today's reachable hall floor: 684 in five capitals, 402 in Kezamba (flood fill on template cells). §2.7 asks for "more impressive". Enlarge it, or show the comparison.
3. **C007, C018/25/32/39/46/53: the guard mismatch is misframed.** Two is deliberate: 494a6073 (2026-09-19) removed `door_guard_west/east` from `ROYAL_GUARD_SOCKET`, with a test asserting "door guard still resolves as a royal guard" and census 2×6. Stale: world.md:497, world_zones.md:1869/1886/1898, biomes_mobs.md:849, start_npcs.lua:921. Each hall keeps both as ordinary guard posts at the great door. Drop the "two unbound spare positions" and show the door guards.
4. **"Exact" socket schedules are not exact.** Missing in all six capitals: `door_guard_*`, `hall_idle_*`. Also missing: Lethariel's four `colonnade_*_idle_*`; inside castles `citadel_walk_north`, `precinct_walk_north`, `core_spare_*`, `forecourt_idle`. Gor Drazhak `court_idle_wain` (37,31) lands in the moved `beast_shed` fence; `court_work_fire`, `court_idle_store`, `precinct_walk_court` fall inside moved boxes. Four capitals' `*_booth_*` stay while their market shifts. Hearthpine `watch_plaza_west` (−18,0) is on a fence (C060).
5. **Effort understated.** "Eleven templates move" hides 50–63 Lua-authored sockets per core (22 in Kezamba) in 800–1,000-line compositions. C003 omits: `RADIUS = 49` in the compositions, precinct_ring.lua:14, corner towers at ±47 (three capitals), city_green.lua:100, r7_capitals.lua:237, height.lua:333 (river keep-out radius 99.9 → 111.2, so rivers change world-wide), duplicates like sunscar.lua:87 `BREASTWORKS`.

## Other wrong or weak claims

- C008: "keep combat within the room" has no mechanism; the leash is 30 from where the chase began (aggro.lua:544).
- C059: Hearthpine `hall_quest` does not move; the moved workyard's wall now stands directly beside it.
- C033: Lethariel's vendors do not move (boilerplate).
- C081: the pocket also holds eight posts (sunscar.lua:514).
- C021/28/35/42/49/56: correct but mask-only; label them.

## Missing costs

- **Template gate:** format doc §6.1 fixes box, pivot and point ids, so the castle needs new templates, roster `use` lines, a `BASELINE` move, and tools/r58_townfix/portable_test.lua:356 `HALLS`.
- **Height:** `BOUNDS.capital_core` y max 40 caps the castle (today's top 31).
- **Docs:** the 96×96 rule also lives in world_zones.md:721/810/1741/1765.
- **Fleet:** civic_width changes every seed; a full fleet run is due.

## Confirmed

- **Data:** Hearthpine, Sunscar, Stillgrave layouts and Dur Brannoc, Lethariel, Kezamba PLOTS match the exports. My reruns of the three `today` seeds match the committed capitals structurally.
- **Numbers:** 48→56, 837/529→1,575, 3,328, 36.1%, plot counts, losses and template counts recompute.
- **Claims:** all others hold. Sampled by mechanism: families C015–20 and C057–60 rest on one reading each. C001–C006, C009–C014, C034, C055, C058, C061, C066, C071 read directly.
- **New measurement (scratch copy, 40 fleet seeds, today vs civic_width=112 plus 56/57/60, old cores):** all 240 capitals place every required plot, no load failure; castles dry and flat on every seed.

| Capital | Mean plots | Worst seed |
|---|---|---|
| Gor Drazhak | −2.1 | −5 |
| Highcourt | −1.9 | −6 |
| Kezamba | −1.2 | −8 |
| Nhal Veyr | −1.15 | −5 |
| Dur Brannoc | −1.1 | −5 |
| Lethariel | −0.1 | −4 |

Seven unrouted-street cases appear, three disappear. `infeasible` seeds: Kezamba 3 → 3, Lethariel 0 → 2, Gor Drazhak 2 → 0. The ranking holds, but single seeds differ from the page (12345: Dur Brannoc 50 vs 47, Kezamba 49 vs 51). Add this table.

- **Rulings:** one form, town envelope, waystones near centre, Lethariel, Kezamba kept. Four castles fit today's ±49, so growth serves the moved neighbours; say so.

## Could not verify

Walkability on built geometry, deck landings, browser and phone behaviour, the castle's real shape. No Luanti server. Fixtures: none, no claim needed one. The page still says this check is pending. Worktree untouched.

---

# Pass 2 re-check (7eddf6b9, read-only)

**Verdict: FIX FIRST, text only.** The layouts stand; the 48/56 paragraph (C091) misleads. No geometry change; the coordinator can check it.

**Fixed, independently rechecked:** all five must-fix items and the weak claims.
- Cell-level rerun of all 659 schedule rows: no socket in a wall, fence or castle; the two flagged cells are pads on displaced furniture the page names.
- Highcourt's chapel doors and bypass clear. Budget 304+805+120+346 = 1,575 holds.
- `verify.py` passes.

**Fix in C091 and the shared text:**
1. **48's main saving is unnamed.** It drops most of C003 (gatehouses, rings, `RADIUS`, civic_width, `BOUNDS`, collar, landing scan, `city_green`). The page names only district and river change.
2. **River cost overstates 56.** Both options need the map reset; rivers then cost a fleet run. Rivers stay unchanged only if all six stay at 48.
3. **Two capitals are not a free choice.** A 45-long side exceeds a quadrant at ±46 with avenues kept (my search: no placement). At 48 they would have to straddle an axis or hug the ring. Say: as placed, Lethariel and Kezamba need growth; only the four are optional. The mixed choice is unmeasured; the 40-seed table is all-six 56.
4. **48 ignores the ruling.** §2.7 says the core "grows somewhat"; say that 48 departs from it.
5. **Compact costs missing:**
   - Today's great door climbs two stair rows (z=7, 8). Compact has only z=3, which Dur Brannoc uses as kerb, so stairs enter the foyer.
   - The north gate's watch rectangle (z 37–41) collides with castle and bypass in all four.
6. **+17.7% compares gross with net.** Today's gross hall is 29×25 = 725 (+11%), and depth shrinks 25→23. Add this.

Fixtures: none.
