# World view: spawn levels and the border rule (Round 28 Lane W1)

Every zone's spawn recipe raises its levels from its `from` (where players
come in) to its `to` (where they move on). These images show the **whole
mainland** at once, so the levels on both sides of every zone border can be
compared: today's recipes (`current_seed_<s>`) against the recipes the
border rule gives (`proposed_seed_<s>`), for seeds 42, 7 and 2026. The
proposal is drawn from copies; the shipped recipes are unchanged until the
user decides.

## Reading the images

- **Land colour:** the level of the cell's spawn region (the middle of its
  belt), on one blue ramp from L1 (light) to L60 (dark). Thin dark lines
  separate the belts inside a zone; each belt patch carries its level range
  (`L21-23`). Grey hatched land is a zone without a recipe (today's palette
  spawning). Cream is land that no region covers (coast fringes, islets the
  zone's region map does not reach). Sea and inland water are neutral greys.
- **Zone borders** are coloured by the level fit across them. For each side
  shared by two land cells (32 nodes) of different zones, the gap is the
  distance between the two regions' level ranges (0 when they overlap, 1 when
  they touch, e.g. L8-10 next to L11-13):
  - green **fit**: gap ≤ 1;
  - yellow **step**: gap 2–5;
  - red **jump**: gap > 5;
  - magenta **forced**: the two zones' bands lie more than 5 apart (a start
    zone 1–10 beside a heartland 21–30, a contested zone 31–40 beside a
    front zone 51–60), so no recipe can close the gap;
  - grey: a side has no recipe.
- **Places:** start towns (circle) and capitals (diamond) with their names;
  zone names with their bands.
- **Side panel:** the ramp, the border length per class, and the red and
  yellow borders (length in nodes, zone and level range on each side).
- The two dragon islands are left out: one belt (L60) and no land border.

Each image has a stats file (`.md`) with the totals per class, every red,
yellow and forced border (zone pair, length, level ranges, gap), a table per
zone pair, the zone pairs that touch on that seed but are not neighbours in
the atlas, and per zone its `from` / `to` and its recipe file.
`border_rule.md` lists every zone's `from` / `to` today and by the rule.

## The border rule (user, 2026-10-02)

| zone kind | low (`from`) | high (`to`) | neutral |
|---|---|---|---|
| start 1–10 | the start town | the race's own home zone (11–20) | heartlands |
| home 11–20 | its start zone | its capital zone and every adjacent heartland | — |
| capital 20–30 | the capital city and the race's own home zone | contested zones | heartlands |
| heartland 21–30 | the faction's capital and home (11–20) zones; a start zone (see below) | contested zones (or a front zone) | other heartlands |
| contested 31–40 | the faction's 20–30 zones | front zones | other contested zones |
| front, islands, The Broken Causeway | unchanged | | |

A capital's `from` names the city and the border together:
`{"anchor": "capital", "border": "<home zone>"}` (both are sources). A
start zone's border to a heartland is a forced gap (10 → 21); the rule keeps
it neutral on the start side and makes it low on the heartland side, so a
player crossing from the start zone meets the heartland's lowest levels.

## Re-running

```
tools/r28_world/run.sh [--seeds "42 7 2026"] [--out docs/planning/round28/world] [--only current|proposed]
```

One LuaJIT process per seed and variant builds the analytic world once
(about 20 s) and every mainland zone's region map with the game's own
`spawn_regions_core.lua`; up to seven run at once under idle scheduling,
then `render.py` draws each image. The proposal comes from
`tools/r28_world/border_rule.py --out <dir>` (into the run's scratch
directory). `border_rule.py --apply` writes the rule into the shipped
recipes (only their `from` / `to` lines change); `--self-test` checks the
table on a synthetic atlas. The border classes are in
`tools/r28_world/borders.lua`, tested by `tools/r28_w1/portable_test.lua`.
