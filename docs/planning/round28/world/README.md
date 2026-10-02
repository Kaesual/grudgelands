# World view: spawn levels and the border rule (Round 28 Lane W1)

Every zone's spawn recipe raises its levels from its `from` (where players
come in) to its `to` (where they move on). These images show the **whole
mainland** at once, so the levels on both sides of every zone border can be
compared. The user approved the border rule on 2026-10-02 and extended it
to the front zones; it is applied to the shipped recipes, and The Broken
Causeway plays 41–50.

- `before_seed_<s>.png|md`: main `38e1da4b` (every zone with a recipe, before
  the rule; the Causeway still 31–40).
- `final_seed_<s>.png|md`: the recipes with the rule applied (this branch).
- `compare_seed_<s>.png`: both maps side by side (before left, final right)
  with the border length per class above each.
- `border_rule.md`: every zone's `from` / `to`, as shipped and by the rule
  (now all the same).

Seeds 42, 7 and 2026.

## Reading the images

- **Land colour:** the level of the cell's spawn region (the middle of its
  belt), on one blue ramp from L1 (light) to L60 (dark). Thin dark lines
  separate the belts inside a zone; each belt patch carries its level range
  (`L21-23`). Cream is land that no region covers (coast fringes, islets the
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

## The border rule (user, 2026-10-02)

| zone kind | low (`from`) | high (`to`) | neutral |
|---|---|---|---|
| start 1–10 | the start town | the race's own home zone (11–20) | heartlands |
| home 11–20 | its start zone | its capital zone and every adjacent heartland | — |
| capital 20–30 | the capital city and the race's own home zone | contested zones | heartlands |
| heartland 21–30 | the faction's capital and home (11–20) zones; a start zone | contested zones (or a front zone) | other heartlands |
| contested 31–40 | the faction's 20–30 zones | front zones | other contested zones |
| front 41–60 | every lower-band neighbour | every higher-band neighbour; none: the core | same-band fronts |
| dragon islands | unchanged (one belt) | | |

A capital's `from` names the city and the border together:
`{"anchor": "capital", "border": "<home zone>"}` (both are sources). A
start zone's border to a heartland is a forced gap (10 → 21): neutral on the
start side, low on the heartland side, so a player crossing from the start
zone meets the heartland's lowest levels. The Broken Causeway and The
Shattered Line (41–50) rise from their contested borders toward Gravesalt
Escarpment and The Skyglass Canopy (51–60), which rise from their lower
neighbours to their core. The rule is stated in
[spawn_regions.md](../../../design/spawn_regions.md#entry-and-exit-borders-the-border-rule).

## Results

Border length in nodes per class, before (main `38e1da4b`) → final:

| seed | fit | step | jump | forced |
|---|---:|---:|---:|---:|
| 42 | 38496 → 51200 | 16096 → 5088 | 1984 → 992 | 5696 → 4992 |
| 7 | 39232 → 50656 | 14464 → 5440 | 2656 → 800 | 4960 → 4416 |
| 2026 | 38016 → 50784 | 14720 → 3936 | 2048 → 704 | 6304 → 5664 |

Forced borders shrink because The Broken Causeway (now 41–50) beside
Gravesalt Escarpment (51–60) is an ordinary border.

The red borders left are short (32–128 nodes each) and sit where three zones
meet and two zones' entries come together:

- a contested zone's first belt (L31-33) beside a heartland's first belt
  (L21-23), where the heartland's capital or home border runs up to the
  contested zone (Blackwind Rise | Ossuary Reach, Glassroot Wilds | Lorindor,
  Frostbarrow Shelf | Stormvault Heights);
- a home zone's first belt (L11-13) beside a heartland's (L21-23) at their
  shared start zone (Mournfen | Ossuary Reach, Raincall Basin | Totemwater
  Reach, Moonfall Wood | Starbough Vale, Copperfell Foothills | Frostbarrow
  Shelf);
- a 41–50 front's first belt (L41-43) beside a 51–60 front's first belt
  (L51-53) where both meet the same contested zone (The Broken Causeway |
  Gravesalt Escarpment at Stormvault Heights, The Shattered Line | The
  Skyglass Canopy at Glassroot Wilds).

Most yellow left is the neutral capital | heartland border (a capital's top
belt L28-30 beside the heartland's first belt L21-23). Seeds 7 and 2026 have
start | heartland contacts the seed-42 atlas does not list (Dawnmere |
Whitebridge, Hearthpine | Frostbarrow, Sunscar | Whispering Reedlands):
forced gaps either way.

## Re-running

```
tools/r28_world/run.sh --variants "before final" --before 38e1da4b
tools/r28_world/run.sh                          # current vs proposed (defaults)
```

Options: `--seeds "42 7 2026"`, `--out DIR`, `--variants "A [B]"` (`current`
or `final`: this tree's recipes; `proposed`: the rule's copies;
`before`: the tree of `--before REF`, extracted with `git archive`). One
LuaJIT process per seed and variant builds the analytic world once (about
20 s) and every mainland zone's region map with the game's own
`spawn_regions_core.lua`; up to seven run at once under idle scheduling,
then `render.py` draws each image and `pair.py` the side-by-side.
`tools/r28_world/border_rule.py` writes the report (`--report`), proposal
copies (`--out DIR`) or the shipped recipes (`--apply`; only their `from` /
`to` lines change); `--self-test` checks the table on a synthetic atlas. The
border classes are in `tools/r28_world/borders.lua`, tested by
`tools/r28_w1/portable_test.lua`.
