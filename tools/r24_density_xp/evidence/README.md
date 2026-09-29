# Round 24 Lane F density evidence (ruling 27)

Captured on 2026-09-29, seed 4242424242, through `tools/r24_density_xp/run.sh`
(isolated `tools/luanti_headless.sh` boots under `chrt --idle`, probe-only
`count_mobs` player shim, eight stationary probe points force-loaded as 7×7
blocks, 120 s day window, then 120 s night window, census of budgeted mobs
within 56 nodes at 60/90/120 s).

- **Same Husk gate on both sides.** Every run here is on a tree that already
  contains Lane D2 (Sunscar Husk from band 2) and Lane D3 (ruling 31). The
  baseline is `BASE=main` (D2 and D3 merged; `before-3` also has Lane G): the
  reverse of the Lane F `grug_mobs` change applied to the same tree, i.e.
  the Round 16 spawn rule. `after` is the Lane F branch at its final density
  code (commit after merging G). No ERROR lines in any log.
- `before-1`, `before-2`, `before-3`: three baseline boots. `after`: one Lane F
  boot. Emerge took 47–51 s per boot.
- The windows are short: by day no area reaches its cap, so the day numbers
  mostly measure refill speed and are noisy (the baseline itself spans
  12 / 7 / 11 at Hearthpine). The structural guarantee is proven in the
  portable fixture instead (`fixture.txt`): every sampled land column's point
  budget is at least its old population, and a species below its own
  Round 16 cap always spawns.

Summary (`summarize.py before-*.probe.txt -- after.probe.txt`): budgeted mobs
at the 120 s census, per boot, and the mean over all censuses of a side.

| Area | Clock | Before @120 s | After @120 s | Before mean | After mean |
|---|---|---|---|---:|---:|
| hearthpine | day | 12 / 7 / 11 | 6 | 9.7 | 6.3 |
| dawnmere | day | 4 / 4 / 5 | 10 | 4.7 | 9.0 |
| silverleaf | day | 7 / 6 / 6 | 11 | 6.6 | 10.3 |
| stillgrave | day | 10 / 8 / 10 | 11 | 8.8 | 10.0 |
| sunscar | day | 5 / 7 / 4 | 8 | 6.1 | 9.3 |
| kapok | day | 18 / 14 / 13 | 15 | 14.4 | 15.3 |
| moonfall | day | 8 / 9 / 7 | 7 | 8.7 | 7.0 |
| redtusk | day | 11 / 15 / 13 | 11 | 12.6 | 12.0 |
| hearthpine | night | 19 / 21 / 16 | 20 | 18.4 | 19.7 |
| dawnmere | night | 16 / 15 / 11 | 26 | 12.7 | 23.7 |
| silverleaf | night | 15 / 21 / 17 | 26 | 17.7 | 27.0 |
| stillgrave | night | 17 / 13 / 14 | 24 | 15.1 | 23.0 |
| sunscar | night | 14 / 16 / 10 | 14 | 14.4 | 16.3 |
| kapok | night | 25 / 23 / 25 | 29 | 25.0 | 30.3 |
| moonfall | night | 19 / 19 / 18 | 15 | 18.7 | 14.7 |
| redtusk | night | 21 / 24 / 19 | 16 | 21.7 | 16.0 |
| **sum** | day | | | **71.4** | **79.3** |
| **sum** | night | | | **143.7** | **170.7** |

Night counts include day animals still alive from the day window. Moonfall
(night) and Redtusk (night) are below the baseline in this single Lane F
sample although neither cap is lower there; a second sample would be needed
to tell noise from an effect.

**Review fix (after these runs):** every budgeted species is now also capped
at ceil(1.5 × its own Round 16 cap). The engine table above predates that
cap, but no species count in any `after` census exceeds its new cap (checked
against the roster), so the cap would not have changed these numbers.
`fixture.txt` is
regenerated with the cap: its lone-species cases, the worst-case totals table
and the per-column means include it.

Files: `before-*.probe.txt` / `after.probe.txt` (probe lines of each boot),
`fixture.txt` (the portable fixture's zone tables, the per-zone budget table
and the gathering-XP table at the same commit).
