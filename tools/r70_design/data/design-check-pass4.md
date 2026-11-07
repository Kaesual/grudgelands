# Pass 4 re-check (4146eb8b, read-only)

**Verdict: FIX FIRST.** The shift itself holds. One character promise is false; two costs are hidden.

**Fix:**
1. **Lethariel: "the north avenue still crosses water" is false.** Nothing crosses today. `pad()` leaves the band empty, `core_landing` fails, and the planner starts that avenue on the shore: (−28,80) today, (−42,62) shifted. Three seeds show no street across it in any variant; the `CAUSEWAY` comments and settlements.md:400 are stale. A crossing is new build: deck, landing scan, at least 34 nodes to the west shore on z=57, 131 along the axis. It is unmeasured. Say "new", cost it, and put it in the question, or drop it.
2. **Kezamba's question hides the east boardwalk's loss.** The lake leaves the east avenue entirely (z=0 wet from x=18 → none), for any shift of about 12 or more. Avenues over water fall 2 → 1; settlements.md says two. 627 deck, rail and pier cells stand over today's water. Ask the user.
3. **Mere precinct drifts inland.** The pin holds, but plot centres on two seeds move from 19–32 nodes off the shore to 32–44. Show this or tune the pin.
4. **`cenote_fish_3` (−10,44) looks through `cenote_fish_2` (−9,44)** at reach one; kezamba.lua:755 records that exact fault. Choose another column.
5. **Three-seed unrouted result understates.** My 40 seeds (`lake0` vs `lake_shift`): Lethariel 9 new, 1 gone; Kezamba 3 new, 5 gone. Plots: Lethariel −0.15 mean (−3…+3), Kezamba +1 (−8…+6). Add this table.
6. **Name:** POI exclusion box moves (placement.lua:365); the mask generator is deleted (kezamba_lagoon.lua:4), so a new one is needed. "A little" holds by distance (12–16% of core width), not by share: wet core columns fall 54% and 34%; say so.

**Confirmed:**
- 40 seeds: every required plot placed, no load failure; the other four capitals plan identically, so no river effect reaches them.
- All dry counts recompute; translation is rigid inside ±57; anchor reasoning correct; no socket on water; only the moot house straddles it.
- Other ten: schedules, proposals, metrics identical. Unbuilt numbers are labelled honestly.

**Not verified:** full fleet, real recut core, bank geometry. Fixtures: none.
