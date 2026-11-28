# Breach Road · The sealed balconies

[Open the offline pick page](index.html) · [The Accord from the rail](renders/accord-after-rail.jpg) · [The Throng from the deck](renders/throng-after-balcony.jpg)

The timber rail moves one cell inward. Each **6 × 9** clear deck holds two rows of six. Players can stand on the rail along its full nine-node length. The three solid parapet posts and two projecting upper corbels give way to a clear opening between the original end walls. The stair still turns inside the hall and arrives under the canopy.

A sheet of **45 invisible full cubes per hall** occupies the next row toward the road. It meets both solid flanks and extends from the deck’s floor layer to the canopy underside. The friendly box ends at the barrier’s inner face, keeping the rail friendly through its full width. Both roofs offer a contested 5 × 5 landing.

## Layout handoff

Inclusive arena-local **(lx, ly, lz)** endpoints, relative to the road datum.

| Volume | The Accord | The Throng |
|---|---|---|
| Invisible barrier | (22, 14, −14) … (22, 18, −6) | (−22, 14, 6) … (−22, 18, 14) |
| Friendly hall | (31, 7, −14) … (41, 13, 14) | (−41, 7, −14) … (−31, 13, 14) |
| Friendly upper stair | (30, 14, −14) … (37, 18, −12) | (−37, 14, 12) … (−30, 18, 14) |
| Friendly balcony | (23, 15, −14) … (29, 18, −6) | (−29, 15, 6) … (−23, 18, 14) |

**Visible from the deck and rail.** Spectators can follow the road crossing, the stairs on the opposite terrace and the opposing standard. Looking along the rail reveals the nearer road mouth. The arcade still hides short stretches of road, and the gate directly beneath the deck is out of sight. [Along the road](renders/accord-after-flank.jpg)

**Nodes.** The 19 shipped template nodes are listed by hall. The sole pending registration is `grug_mapgen:arena_barrier`. It must pass light, stop movement, projectiles and attack/heal targeting rays, and prevent selection, digging and placement against it. Runtime behaviour awaits HALLS. [Full node list and proposed properties](nodes.json)

**Changed cells against the live templates** in ascending template layers 1–13. Layers 0 and 14–18 have zero changes.

| Hall | Counts | Total |
|---|---|---:|
| The Accord | 45, 47, 41, 35, 20, 14, 21, 135, 69, 60, 60, 60, 139 | 746 |
| The Throng | 45, 47, 41, 35, 20, 14, 21, 127, 71, 52, 54, 55, 139 | 721 |

**Compatible, tools only.** `build.py --check` reproduced both templates, 40 stills and the page. The enclosure check covers flying paths and outward rays, including the stair opening. Firefox passed 19 offline checks of the views, barrier toggles and phone layout. Grep found no fixture reading this report. No Lua or game engine ran.

Handoff commit via `git log -1 --format=%H -- tools/r89_balcony_draft/`. Handoff `git status --porcelain` is empty.
