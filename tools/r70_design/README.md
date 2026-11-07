# Round 70 DESIGN — capital cores and start towns

Open **[page.html](page.html)** directly in a browser. It is one standalone file:
CSS, JavaScript, SVG and all selectable planner data are inline. It makes no
external requests. Nothing is published by this lane.

This is a **2D land reservation proposal** revised after the completed Opus check
of pass 1 (FIX FIRST), for the coordinator's delta review and the user's decision. It is not a castle model, a voxel blueprint,
a game change or runtime acceptance. See [REPORT.md](REPORT.md) for recommendations,
measurements and limitations, and [claims.md](claims.md) for the numbered source ledger.

## What the page contains

- Twelve sections: six capitals and six start towns. Each has exported **today**
  and **proposed** plans at the same scale, a 20-node scale bar, building key,
  exact movement schedules and all **659** socket rows, implementation costs and a decision question.
- One 45 × 35 castle reservation in six placements; a 35 × 23 = **805 nodes² hall-floor reservation**
  inside each, versus the checker’s 684 / 402 reachable floor today. Wall and
  supporting-space budgets are shown separately. Lethariel faces east on its dry western shoulder;
  Kezamba faces north on the dry southern terrace. The other four face south.
- Nominal civic radius 48 → 56 (96 → 112 nominal width), with gates/keep-out
  parameter sensitivity. Each start gets a 13 × 13 clear waystone pocket around
  its existing reach-3 pad, without increasing the town envelope.
- Four drawn radius-48 land alternatives retain the same castle, with narrower
  approaches, a one-row doorstep and (Highcourt) two fewer houses. Recommendation:
  **56 for civic space**, not because the four castle boxes need the larger core.
- The checker’s **40-seed civic_width=112** evidence, labelled as measured with
  today’s cores, alongside the original **mask-only** comparison below. All 40
  exact seeds, per-seed counts/failures and input hashes are retained.
- Whole-capital comparisons for exact seed strings `12345`,
  `3684797457838814663` and `17713522922938657774`, all from
  `tools/seed_fleet/seeds.txt`. Each capital has its own seed selector; a dashed
  outline in the proposed city view shows the baseline outline.
- Theme selector (system/light/dark), optional socket dots, optional horizontal
  60-node reward-distance slice, and keyboard/click building highlights.
  At phone widths the equal-scale plan pair stacks vertically. The coordinate
  and service tables scroll horizontally within their container.

Coordinates are anchor-relative **x/z, +z north**, in nodes. Building rectangles
are the actual rotated template pivots; faint outlines include every non-air
written column, including overhangs. Landmark boxes are not mislabelled as building
footprints. Box endpoints are inclusive. Nominal terrain-profile widths (96/112,
128) are distinct from the authored cell limits (core ±49 today, proposed ±57;
starts ±63). Background colours are schematic classifications of exported cells,
not textures or a promise of exact future planting.

## Rebuild and inspect

Run from the repository root. LuaJIT is used for execution; the repository's
plain Lua 5.1 parser is used for syntax verification.

```sh
python3 tools/r70_design/run.py
python3 tools/r70_design/build.py
python3 tools/r70_design/verify.py
bash tools/check_lua.sh tools/r70_design/export.lua
```

`run.py` reuses committed data. If a deliberate source revision requires a new
measurement, remove only the affected data file(s) first. It exports blueprints, compact template/composition geometry
and service bindings, then queues the six planner runs with **at most two LuaJIT
processes**, under `chrt --idle 0` and `ionice -c3`. Each worker has its own output
and log. Seeds remain strings; no conversion through floating-point integers.
It never starts Luanti, writes a world, generates mapchunks or emits node content.
The real shared world assembly necessarily plans terrain/water/roads/POI placement
as inputs to the capital planner; this is not whole-world voxel generation.

The proposed planner runs change **only** `CORE=56`, `CORE_GATE=57`,
`CORE_KEEP=60` in memory. Terrain, `civic_width`, authored buildings and the
46…49 landing detector are deliberately still the current game. Therefore this
experiment measures sensitivity, not the final implementation or its feasibility.
The exporter does not hide missing required plots with stand-ins. The 40-seed
checker study additionally changed civic_width to 112; it still used the old
cores and landing detector. Neither study substitutes for the **full seed fleet**
required after implementation. No planner jobs were rerun in pass 2.

Optional SVG visual inspection (system PyGObject, librsvg and cairo):

```sh
python3 tools/r70_design/inspect_svg.py /tmp/r70-design-plans
python3 tools/r70_design/inspect_svg.py /tmp/r70-design-plans-dark --dark
```

These render the **actual SVGs embedded in the page**. They include all twelve main pairs and the four compact alternatives. They do not run a browser,
exercise JavaScript or certify responsive layout. Chromium and Firefox could not
start in this session's sandbox; browser checks remain open.

## Files and provenance

Base game code: **`55aa7708a2d6b28fbd3c87ad3e47b72cfea24a0d`**, branch `r70-design`.

| File | Purpose |
|---|---|
| `export.lua` | Executes the real WP13 compositions/template loader and real capital planner; observes template stamping for exact dimensions and sockets. |
| `run.py` | Bounded export queue and cache reuse; no server calls. |
| `data/blueprints.json` | Twelve real compositions: template pivots, written-column extents, doors, sockets, landmarks and schematic top-column classifications. |
| `data/geometry.json` | Actual stamped template and whole-composition non-air cell runs; palette of node names and current top heights. |
| `data/socket-schedules.json` | Every exported socket’s proposed x/z, origin, design attachment and nearby affected footprints. |
| `data/checker-fleet.json` | Compact preservation of the checker’s 40 paired seed exports, input hashes and recomputed aggregate evidence. |
| `data/design-check.md`, `data/royal-binding.txt` | Full pass-1 report and historical proof that two royal guards is deliberate. |
| `data/bindings.json` | Real district service/inn/guild tables and actual generated plot socket ids. |
| `data/<seed>-<variant>.json` | Six capitals per run, with outlines, streets, plots, gates, mask counts and local fitted-terrain samples. |
| `data/metrics.json` | Derived per-seed movement/loss counts. |
| `proposals.py` | Design-only reservations, translations, principal connections and furniture intentions. |
| `build.py`, `geometry.py`, `claims.py` | Page/ledger construction, source-line lookup and bounded geometric checks of buildings, streets, door exits, sockets, fences and walls. |
| `shell.html`, `style.css`, `page.js` | Inputs inlined into `page.html`; never fetched by that page. |
| `verify.py` | Artifact consistency, geometry, source-backed data, internal links and offline-resource checks; eight collision rejection regressions; no game fixture. |
| `inspect_svg.py` | Optional direct SVG rendering for visual inspection. |

No assets are generated by an image model. All geometry is exported data or explicit
2D design reservations. No files under `mods/`, another worktree or the main checkout
are changed. This package is compatible/tools-only; implementing the proposals
belongs to Round 70's declared **map reset**. Agents do not push or merge this lane.
