# Round 70 DESIGN — land-use proposal

Date: 2026-11-07. Base: `55aa7708a2d6b28fbd3c87ad3e47b72cfea24a0d`.
Branch: `r70-design`. Author: GPT-6 Astra.

**Delivered for the coordinator's Opus evidence check, then the user's decision.**
Open [page.html](page.html). The page is self-contained and has not been published.
It contains twelve equal-scale today/proposed pairs, exact building and socket
movement schedules, six selectable whole-city seed comparisons, decision questions
and 86 numbered cost claims. [claims.md](claims.md) repeats those claims with
source locations. [README.md](README.md) explains reproduction and data provenance.

This lane changes only `tools/r70_design/`. Its upgrade classification is
**compatible, tools-only**. Implementing a selected layout would change map
generation and belongs to Round 70's declared **map reset**. No migration, game
implementation, castle architecture or world changes are included.

## Recommended land reservations

Reserve **45 × 35 nodes** for the same basic castle form in all six capitals,
including its future overhangs. Reserve **23 × 15 nodes** inside it for the throne
room. The royal footprint grows from 837 to 1,575 square nodes in five capitals,
and from 529 to 1,575 in Kezamba. Its mass closes an approach or faces a distinct
forecourt, rather than occupying a larger anonymous square.

Increase the nominal civic radius from **48 to 56**, the inner gate parameter
from 49 to 57 and the district keep-out from 52 to 60. This is eight nodes per
side, or 96 to 112 nominal width. The nominal square gains 3,328 square nodes
(36.1%). The outer 512-node capital reservation stays the same. The relatively
small width increase has a substantial district cost; it should be a conscious
choice, especially in Highcourt and Gor Drazhak.

Coordinates below are anchor-relative x/z, +z north; rectangle endpoints are
inclusive. These are reservations, not an approved building design.

| Capital | Castle reserve; front | Recommended arrangement and principal cost |
|---|---|---|
| Dur Brannoc | (−22,10)–(22,44); south | Keep the forge visible east of the royal approach and the ancestor precinct west. Move the working court east, broaden the approach and retain a rear bypass. Eleven existing templates move, including four gatehouses. |
| Highcourt | (−22,10)–(22,44); south | Keep the chapel and southern orchards; move the service yard/store east. Eleven templates move. Accept fewer optional district plots if this size is chosen. |
| Lethariel | (−52,−51)–(−18,−7); east | Turn the shared footprint onto the dry western shoulder. Give the two separate colonnades' land to the forecourt; move three gatehouses. Preserve the lake's intrusion, shrines and grove. No northern gatehouse or new land bridge. |
| Gor Drazhak | (−22,10)–(22,44); south | Put the stronghold at the head of the open approach, with stores/beasts east and the skull hall west. Keep the earth/timber boundary character. Eleven templates move; this has the largest optional-plot loss in the sample. |
| Nhal Veyr | (−22,10)–(22,44); south | Replace the small mausoleum reservation, preserve the separate vigil hall, move Bone Works/Charnel Yard east and move the fallen house out of the enlarged approach. Twelve templates move. Replace the close mausoleum patrol with the wider precinct loop. |
| Kezamba | (5,−52)–(49,−18); north | Keep the castle on the dry southern terrace. Relocate six civic buildings to the western service strip, move the waystone to (−12,8) and reconnect the quay. Preserve the lower cenote and supported decks; their extensions require height/landing work. |

For the starts, give the existing reach-3 waystone pad a **13 × 13 clear arrival
pocket** near the centre. Keep the Quartermaster at its present vendor socket,
spawn at (0,1,0), the main gate axis and the existing total envelope. Each town
keeps its 128-node fitting and rounded 12-node protected band; authored buildings
stay within ±63. The expanded centre is a mixture of paths and local ground,
not a requirement to pave one large rectangle.

| Start town | New waystone x/z | Recommended move |
|---|---|---|
| Hearthpine | (−9,7) | Spread the closest homes and workyard; set the forge back four nodes. Five templates move. |
| Dawnmere | (−9,−8) | Spread the hall and inn and step them back. Only two templates move. Keep a grassy green; move the displaced well to (−10,7). |
| Silverleaf | (13,8) | Preserve the actual crescent cells. Spread the two raised houses and move the lore hall north-east, with both +3 podiums and their stairs. Three templates move. |
| Stillgrave | (−12,−2) | Move the chapel and northern row back six nodes; move Bone Works east. Six templates move. Preserve the burial margins and move the displaced settle/spare standing spots. |
| Sunscar | (−11,2) | Move the hall back, armoury east and beast pen north-west. Three templates move. Move the acacia work feature and its socket together. |
| Kapok Cradle | (−10,−7) | Spread the near stilt houses; move the lodge and northern work buildings to frame one clearing. Five templates move. Carry stairs, landings and terrace furniture with them. |

One recommended layout is supplied per place. The questions on the page ask about
specific choices within those layouts; no second fully developed option is claimed.

## Real planner experiment

The exporter executes the real compositions and template loader, and the actual
capital planner through shared world assembly. It uses no fixture or replacement
planner. The six planner jobs ran at idle CPU/I/O priority, with at most two
LuaJIT processes. Each job has its own committed JSON and log. Existing results
are reused by `run.py`; identical planning work need not run again.

Seeds are exact strings from `tools/seed_fleet/seeds.txt`, in the following order:

1. `12345`
2. `3684797457838814663`
3. `17713522922938657774`

For each seed, one run uses the original parameters and one changes only
CORE/CORE_GATE/CORE_KEEP to 56/57/60 in memory. All six capitals are exported in
each run: **36 plans**, with outlines, streets, plots, four outer gates and
terrain/mask samples. The page embeds the exact planner geometry for selection.

| Capital | Plot totals, today → proposed, in seed order | Surviving plots changing position, height or rotation | Sampled eligible land removed by the larger keep-out |
|---|---|---|---|
| Dur Brannoc | 48 → 50; 51 → 49; 51 → 52 | 48; 48; 51 | approximately 3,648 square nodes |
| Highcourt | 49 → 47; 51 → 47; 53 → 48 | 47; 47; 47 | approximately 3,648 square nodes |
| Lethariel | 45 → 45; 44 → 43; 40 → 41 | 45; 42; 39 | approximately 2,752 square nodes |
| Gor Drazhak | 52 → 46; 51 → 47; 50 → 46 | 45; 47; 46 | approximately 3,648 square nodes |
| Nhal Veyr | 49 → 47; 49 → 48; 48 → 47 | 45; 48; 46 | approximately 3,648 square nodes |
| Kezamba | 51 → 49; 49 → 50; 51 → 49 | 49; 46; 47 | approximately 2,464 square nodes |

All ten required plots (eight service plots, inn, miners_guild) are present in
every baseline and proposed plan. Optional-plot losses and gains are named in the
page and [data/metrics.json](data/metrics.json). The removed-land estimate is a
two-node-grid sample multiplied by four, not exact polygon area or lost building
floor area. Repacking can increase the total number of plots despite taking land
away from the planner. It also changes the generated outer outline and gate
locations within the unchanged reservation.

Lethariel and Kezamba report `ring1/q1 ring2/q1` as `no_route` in both variants of
all three seeds. These are existing reported gaps, not newly attributed failures.
No timing or performance conclusion is drawn.

**Scope limit:** the experiment retains existing civic_width=96, fitted terrain,
authored buildings and the old core-landing detector. It measures the planner's
response to the enlarged exclusion, not a finished 112-node civic implementation.
The proposed castle reserves sample dry on all three *existing* terrains. This
does not certify final earthwork, new landing heights or generated-street clearance.
See C001–C005 and each city's measured claim in [claims.md](claims.md).

## Consequences the implementation must own

The page names the exact affected sockets and bindings for each place. The shared
dependencies are not limited to translating the visible buildings:

- Coordinate `civic_width`, terrain fitting/collar, `BOUNDS.capital_core`, the
  separate hard-coded ±49 plot-collar exclusion and the 46…49 landing scan with
  the planner parameters. Preserve Lethariel's lake wedge and Kezamba's terrain
  categories and deck landings. The current Kezamba ravine mask is empty.
- Rebuild each core boundary and avenue connection. Distinguish the four outer
  planner gates in every capital from authored inner gatehouses: four in four
  capitals, three in Lethariel and no standard inner gatehouse kit in Kezamba.
- Re-author the named patrol corners, gate watches and standing spots. Route
  legs are cached in memory and failed legs can remain unavailable until restart;
  there is no persistent route-cache migration. Final door/stair walking remains
  an engine check.
- Keep `king`, `throne_guard_west`, `throne_guard_east`, public quest sockets and
  service bindings. The district annexes list the actual plot-prefixed sockets,
  including the guild, inn, Housing Steward, Crownbinder and Decor Merchant.
- At each start, move `travel_waypoint`, its pad, stone and mailbox together;
  retain arrival sides. Keep `hall_quest`, `quest_cook`, `cook_oven`, the home
  binding and Quartermaster identity. Cooking sockets come from the projection
  adapter after composition; the tool includes them. Template-owned quest/home
  sockets move with the template, while loose furniture and displaced spare
  standing points require explicit re-authoring.

Two encounter facts require particular attention in the independent check:

1. **Source conflict:** `world_zones.md` specifies four royal guards, while
   `ROYAL_GUARD_SOCKET` binds only the two named throne posts. The proposal reserves
   those two actual posts and two unbound spare positions. It does not decide to
   add guards. See C007 and the six encounter claims.
2. **60 is not the chase boundary:** the 60-node rule measures 3D reward
   participation from the king's death position, with a separate 60-second death
   grace. The king's chase leash is 30 from its chase anchor; royal guards have
   a five-node follow distance and no independent leash. The optional map circle
   is only a horizontal reference slice around the planned throne, not a combat
   boundary. See C008.

## Validation completed and limits

- Plain Lua 5.1 syntax/SETGLOBAL/sweeps: `bash tools/check_lua.sh
  tools/r70_design/export.lua` passed. Executable exports used LuaJIT.
- `build.py` checked all twelve geometry schedules: translated template
  written-column envelopes do not overlap, stay within the proposed core/existing
  town bounds, and leave new arrival pockets free of templates and unrelated
  sockets. Castle and throne-room reservation dimensions are shared. Current
  spawn positions are unchanged. These checks are conservative 2D checks, not
  collision tests of future castle geometry.
- `verify.py` checked Python/JavaScript syntax, twelve sections, 24 equal-scale
  plans with scale bars, unique ids, internal anchors, 86 matching claim ids,
  inline assets without external requests, exact seed strings and agreement of
  embedded city geometry with the raw exports. All 36 plans have four outer
  gates and all required plots.
- The embedded SVG plans were rendered directly with librsvg in light and dark
  colours for visual inspection. This validates the plan graphics only.

**Not verified:** complete browser layout or JavaScript interactions. Chromium
failed to start in this sandbox (crashpad `setsockopt: Operation not permitted`,
exit 133); Firefox also failed at startup (exit 139). Responsive CSS and theme
controls are supplied, but browser/mobile acceptance remains open. No attempt to
bypass sandbox permissions was made.

**Also open:** the coordinator's Opus cost review, the user's land-use decision,
all castle architecture, final terrain/shore/deck construction, full pathfinding,
standing/headroom, combat and desktop/web engine acceptance. No Luanti server or
whole-world voxel generation was run. No other agent, other worktree, merge or
push was used.

## Review and later GUI checklist

- [ ] Opus: verify the 86 numbered claims against the base code, especially the
  two/four royal-guard conflict, the 60-node rule and the landing/collar exclusions.
- [ ] Browser: open the standalone page locally with networking disabled; inspect
  every section at desktop and phone widths in light, dark and system themes.
- [ ] Browser: switch every seed selector, toggle socket/range overlays, focus
  buildings with the keyboard and follow a cost link through its closed accordion.
- [ ] User: decide the shared castle reservation, civic growth and twelve
  per-place layout questions before 3D design begins.
- [ ] Later implementation, desktop and web: check all spawn/waystone arrival
  sides, mailbox use, quest/home/service NPC standing and interactions, gate and
  patrol routes, stairs and deck approaches.
- [ ] Later implementation, desktop and web: check throne-room combat, king and
  bodyguard positions, chase behaviour and reward participation without increasing
  their existing rules as an incidental layout change.
