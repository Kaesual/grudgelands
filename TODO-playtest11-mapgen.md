# TODO — Playtest 11 mapgen findings (2026-09-19, user, with three screenshots)

Open questions from the user after Round 8 (R8-MAP-A merged 1e165a0a) and
the checks they require. To be worked through in a fresh context before any
mapgen change is planned; every item is a measurement first, a decision
second.

## Findings

1. **Perceived mapgen slowdown** (small, uncertain). Check: measure with the
   WP40 profile harness (`tools/wp40/profile/run.sh`) on main before/after
   MAP-A (45e0c07b vs 1e165a0a): per-chunk write time; suspects are the
   per-column coast-profile evaluation, the strata blobs, the cave candidate
   search and the radius-12 flood-fill proof per candidate at write time.
2. **Inland lakes and ponds still have stone rims at water level.** The user
   meant exactly these water bodies with "sand near water". Check: what the
   freshwater rule does today (freshwater runs = beach or bluff only, thin
   sand lip 1–2 nodes; the R6 bank rule puts the first dry column at
   `water_y`; the bluff face is gravel/stone; the wet-bed selector). Decide:
   sand rims (2–4 nodes, with the bank rule) around inland fresh water.
3. **Cave mouths landed mostly on the steep coasts, not inland.** Many v7
   caves lie directly under a one-node-thick surface inland and still do not
   break through. The coast-cliff caves look buggy (screenshot 1: holes in
   the cliff face) — treat as a regression. Check: (a) where the 9–10
   carved mouths per region actually are (coast vs. inland; the committed
   candidate files under `tools/r8_map_a/evidence/` have coordinates);
   (b) whether the cliff/terraced profiles expose native v7 cave air by
   lowering `H` behind the bank (the visible "holes" would be pre-existing
   v7 caves cut open by the new coast, not carved mouths); (c) why inland
   sinkhole candidates fail the proof (search bound ≤ 24 nodes, the ±12
   proof box inside the unchanged owner input, the ≥ 24-voxel continuation)
   when the cave is one node below the surface.
4. **Coast band too narrow; beaches too small.** The profile only shapes a
   few columns behind the bank. The user's target ("gut feeling numbers, to
   be refined"): a beach at least 20 nodes deep (orthogonal to the water
   line) and 40–50 nodes long, rising one node every 2–5 nodes; the terrain
   near a beach mostly falling towards it as a gentle hill (about 45°
   overall, not always). Check: how the profile band width is bounded today
   (relief, exemptions, blend length), what a wider "pulled-down" coast
   costs (it touches `H` over a larger distance: fixture pins, routes,
   POIs, start/capital fittings must stay exempt), and whether low-lying
   zones can get it first with less risk. Constraint from the user: no huge
   map rework, no new performance problem, no POI rework.
5. **Screenshot 3 (noclip inside terrain near (1160, 15, -1751)):** the
   caves look like plain Luanti v7 caves; the user thought v7 takes over at
   y = 0 and asks whether our own layer is only one node thick. Answer from
   the contract (`world_zones.md` §7.6): native v7 is the cave/ore/dungeon/
   stratum substrate at EVERY depth; our layer owns the surface height `H`,
   the surface materials and the strata band down to y = −37, and it
   normalises only sky-side void above `T`; native cave air at or below the
   datum survives. So a v7 cave can sit one node under our surface. Check
   and document whether that is the intended contract or whether a minimum
   surface thickness (or "open it if thinner than n") is wanted — this is
   the same lever as finding 3.

## Sequence

Measure 1, 3a–c and the band width of 4 first (read-only, offline where
possible), then discuss the beach/coast redesign with the user before any
lane brief. Candidate lanes: R9-MAP-B is the WP40 lane of Round 9; the
coast/beach/cave-mouth changes either join it (sequenced) or form R9-MAP-C.
