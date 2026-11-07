# Round 70 DESIGN — capital cores and start towns

Open **[page.html](page.html)** directly in a browser. It is self-contained:
CSS, JavaScript, SVG and selectable planner data are inline; no network requests.

**Accepted by the user, 2026-11-07:** radius 56 for all six capitals and every
pass-3 per-place recommendation. Pass 5 corrects two amendments after the
independent check: move
Lethariel’s lake 14 north and Kezamba’s 18 north relative to unchanged city
anchors. The other ten layouts stay. Historical note: radius 48 was considered
and not selected; its compact alternatives are retired.

This is 2D land use, not a built castle or runtime acceptance. The two lake
amendments still need the user’s decision and the coordinator’s independent
re-check. [REPORT.md](REPORT.md) owns this delivery’s recommendation, measurements,
costs and limits; [claims.md](claims.md) repeats all 93 cited page claims.

## Reading the page

Twelve sections show **today beside the proposal**, with equal-scale plans,
exact building schedules, all **659** exported sockets, costs and district
service bindings. Only Kezamba and Lethariel have new decision questions. Their
sections add the smaller-shift tradeoffs, exact lake-chain coordinates, castle-site
checks, three-seed results and the better 40-seed lake comparison.

- The 45×35 castle and 35×23 hall reservations stay in all six cities. No castle
  architecture is designed. Two royal guards and two ordinary door guards stay.
- Lethariel gains 1,259 dry columns at radius 56. Both colonnades move north
  instead of being retired, and the shrine follows the marble quay. No north crossing
  is promised; a new
  crossing is a separate open option. The mere precinct drifts inland. Its western
  castle stays; a central northern castle would need a larger lake shift.
- Kezamba gains 1,336 dry columns. Five rather than six templates move; the two
  western houses and original waystone plaza stay. The moot house still
  straddles water; the northern boardwalk remains and the east avenue becomes
  dry inside the core, losing one of the two boardwalks. Its southern castle stays.
  The question offers a smaller four-node shift with less land and a revised layout.
- These gains are measured against the same expanded ±57 cell boundary. They
  require the lake change, which is not built. The two comparisons use the real
  shifted-water planner, today’s core cells and the old landing detector.
- The lake shifts are 12.5% / 16.1% of core width, but reduce wet core columns
  by 54.0% / 33.9%. The POI exclusion boxes move, and Kezamba needs a new mask
  generator. These costs are named on the page.
- The separate 40-seed lake comparison is the better planner figure; the older
  civic-width evidence remains historical and uses unshifted lakes.

Coordinates are anchor-relative x/z, **+z north**. Inclusive building pivots are
solid; faint outlines include every non-air written column and overhang.
Nominal profile width 112 is distinct from the authored ±57 cell limits. Quays,
streets and gold shapes in the proposed views are land reservations. They do not
certify future voxels, furnishings, terrain seams or routes.

Theme, sockets, reward-distance slice and building highlights remain available.
The whole-city selectors use exact seed strings `12345`,
`3684797457838814663`, `17713522922938657774`. The two changed city views show
shifted-water results; the other four retain their earlier mask-only studies.

## Rebuild

From the repository root:

```sh
python3 tools/r70_design/run.py
python3 tools/r70_design/run.py --lakes
python3 tools/r70_design/build.py
python3 tools/r70_design/verify.py
bash tools/check_lua.sh tools/r70_design/export.lua tools/r70_design/lake_variant.lua
```

The queue reuses committed outputs. Remove only an affected output deliberately
when its input changes. It runs at most two LuaJIT processes under `chrt --idle 0`
and `ionice -c3`, with separate logs and outputs. The real world assembly plans
terrain, water, roads and placement; it never boots Luanti or generates voxels.

`--lakes` exports the real authored-water masks and paired planner runs. The
`lake0` control and `lake_shift` proposal both enlarge all six civic profiles to
112, CORE/GATE/KEEP to 56/57/60, and the two calm squares to half=57. Only the
latter translates the lake capsule points. `lake_variant.lua` does this in memory;
no game file changes. Existing game `MERE`/lagoon masks are checked against the
unshifted water at ±47, and the new masks against actual fitted wet-column counts.
Final core geometry and the landing scan are intentionally not substituted.

For optional SVG inspection:

```sh
python3 tools/r70_design/inspect_svg.py /tmp/r70-design-plans
python3 tools/r70_design/inspect_svg.py /tmp/r70-design-plans-dark --dark
```

This uses librsvg, not a browser. It does not test events, phone layout, the
engine or walking. Future implementation needs the full template gate, full
seed fleet, and desktop/web checks listed in the report.

## Evidence files

| File | Purpose |
|---|---|
| `export.lua`, `run.py` | Real composition/template, socket and planner exports; bounded queue and reuse. |
| `lake_variant.lua` | Design-only displacement of the two lake chains and expanded calm square. |
| `data/blueprints.json`, `data/geometry.json` | Unchanged actual twelve compositions, template pivots, doors, sockets and compact written-cell runs. |
| `data/bindings.json` | Actual district service, inn and guild bindings. |
| `data/lakes.json` | Exact old/new water-indicator masks; old composition-mask agreement at ±47. |
| `data/<seed>-lake0.json`, `data/<seed>-lake_shift.json` | Six paired real-planner exports; new core wet-column and castle checks for the two cities. |
| `data/shore-check.json` | Two-seed mere precinct distance probe, per-plot results and exact method. |
| `data/lake-metrics.json` | Dry land, smaller-shift buffer checks and northern castle-site probes. |
| `data/socket-schedules.json`, `data/metrics.json` | All proposed sockets and current page’s per-seed plot movement/loss counts. |
| `data/<seed>-today.json`, `data/<seed>-proposed.json` | Original current-game / mask-only planner evidence, unchanged. |
| `data/checker-lake-fleet.json`, `data/design-check-pass4.md` | Pass-4 independent lake review; 40-seed aggregates rechecked from existing outputs. |
| `data/checker-fleet.json`, `data/design-check.md`, `data/royal-binding.txt` | Prior independent review, 40-seed receipt and guard-binding history. |
| `proposals.py`, `build.py`, `geometry.py`, `claims.py` | Land reservations, page/ledger construction and bounded geometry checks. |
| `shell.html`, `style.css`, `page.js`, `verify.py`, `inspect_svg.py` | Presentation inputs, artifact checks and SVG inspection. |

Game-code base: `55aa7708a2d6b28fbd3c87ad3e47b72cfea24a0d`. Pass 4 starts at
`c3612f30`. No image-model assets are used. This package is **compatible, tools
only**; implementation belongs to Round 70’s **map reset**. Agents do not push.
