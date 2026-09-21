# Round 15 — POI character, regional quests and readable HUD

Status: independent reviews and final technical gates PASS; delivery in progress. User Go on 2026-09-21 includes the atlas
quest-giver layer. Waypoints are explicitly deferred. Unexpected complexity
pauses the affected lane for escalation; unrelated work continues.
Date: 2026-09-21. Coordinator: Astra; native agents only, no Claude this session.

## Evidence and user requests

- Round 14 is delivered. Its catalog contains six race-specific chains of nine
  main quests plus two optional lessons: 66 definitions, 11 per race, 24 NPCs.
  Opening objectives repeat across cultures; 66 does not mean 66 distinct
  gameplay concepts. Main chains are race-gated in the current catalog.
- The 18 POIs share three geometric compositions and mostly vary palettes.
  Villages use four identical symmetric huts. User requests an Astra-led visual
  design pass with varied buildings and deliberate, less mechanical layouts.
- Quest symbols should be five times their current linear size, expanding
  downward while keeping their current upper extent, not moving farther up.
- The atlas already renders a small static `@` for the viewer. Replace this
  with a conspicuous heading triangle; add live same-party position/headings.
- Replace the numeric XP HUD line with a wider, thinner progress bar above the
  hotbar. Put quest tracking at middle-right and party tracking at middle-left.
- Further multiplayer/fishing playtest feedback is still pending.

## Approved packages

### A. POI composition — Astra

Recompose all 18 existing villages, outposts and camps using the established
building/decor libraries. Each location needs a dominant landmark, differently
sized secondary structures, readable arrival/paths, useful open space and
activity-specific interiors. Cultural identity must change silhouettes and
composition, not merely materials. Avoid replacing symmetry with random clutter.

Goldmead pilot: a larger granary/work hall, a small dwelling and an open work
shelter around an off-centre yard; uneven roof heights, an orchard/farm edge,
loaded supplies and an identifiable steward's workplace. Outposts should have
one useful lookout and practical stores; camps need a leader's shelter,
supplies/fire and a legible captive area rather than four matching pavilions.

Prefer larger individual buildings within the existing guaranteed fitted cores
(24×24 villages/camps, 16×16 outposts). Greater exterior footprints require
explicit matching changes to fitting/roster/clearance, never unsupported cells
beyond the pad. Escalate if a meaningful visual result requires substantial
terrain work. Retain functional roots, walkable sockets, camp spawn clearance,
existing protection rules and stable quest identities.

Acceptance requires actual textured views from arrival, eye level/interior and
above, plus independent visual review. Review Goldmead village, Redtusk outpost
and Mournfen camp as three different pilots before propagating the approach.
A geometry checksum alone is not visual acceptance. Deliver a contact gallery
of all 18 final locations plus eye-level views of the three pilots.

Read-only Astra planning review confirmed the repeated geometry and proposed:

| Region | Village composition | Outpost | Camp |
|---|---|---|---|
| Copperfell | Long stone/pine workshop, transverse dwelling, workyard | Low stone signal tower and guard shelter | Occupied ruined workshop and stolen tools |
| Goldmead | Large house/work annex, turned small dwelling, open shed | One usable tower and side office/store | Plundered farm, patched roof and grain stores |
| Starbough | Two unequal narrow houses and communal covered walk | Light elevated lookout and open sightline | Poacher worksite, cut trunks and unequal shelters |
| Mournfen | Dwelling, wax/store workshop, tended memorial space | Low watchhouse and sheltered observation niche | Reused ruined enclosure and raised stores |
| Redtusk | Broad earth/stone house, low annex, open cooking court | Strong timber lookout and angled palisade segment | Caravan raiders' shade roof and gathered freight |
| Raincall | Low stilt communal house, small house, preparation shelter | Roofed lookout and dry equipment niche | One patched main canopy and two smaller sleeping places |

These are scene proposals, not new professions or resource mechanics. Visible
workplaces use existing NPC roles; do not invent a combined quest/work role or
promise an escorted captive's physical return. Existing ordinary shell mutation
rules remain in force. Vegetation and paving soften the square pad visually
without exceeding its fitted extent.

Approved: improve these 18 first; do not batch-add the remaining roster
or make new biome/terrain systems in this round. No additional world anchors are included.

### B. Local stories and reward pass — Sol, Astra creative review

Add six additional quests per race, concentrated at the existing village,
outpost and camp: 36 additions, 102 total. Use small optional branches and local
story conclusions, not another six-step mandatory kill chain. Start from each
POI's visible occupation/problem. At most one additional village quest giver
per race initially; agree socket IDs/roles with A before either lane implements.

Use existing kill and item-hand-in mechanics only, with locally obtainable
items/mobs and checked time-of-day availability. No escorts, custom quest-drop
engine, repeatable rewards, required professions, PvP gates or Nether content.
Retain current race/faction rules unless the user explicitly changes them.

Reward recommendation: assign a fixed authored target level and effort class;
review XP against that level's actual XP span and expected required combat.
Do not scale rewards with the player's level at turn-in (waiting should not pay).
Aim for a modest increase, roughly 15–20% on later comparable tasks where the
combined progression supports it, not a blanket multiplier. Current early
rewards already equal or exceed a level span in several cases (first quest:
150 XP versus 100 XP from level 1 to 2). Preserve a worthwhile introductory
reward without accelerating players past the newly authored content.
Produce a small per-route progression ledger, including kill XP and the human
quest-XP passive; no broad economy simulation.

### C. Quest markers and HUD — Astra

- Scale both question/exclamation models 5×; derive the attachment offset from
  actual model bounds so their world-space upper extent remains fixed. Preserve
  per-viewer states, visibility distance and shared hysteresis. Check NPC/name
  overlap for different races and clearly report if the requested scale collides.
- Right-centre quest block, left-centre party block, with edge padding and each
  block vertically centred as its contents change. Preserve both saved toggles
  and empty-state hiding. Wrap quest text; use actual right alignment per line.
- Suggested XP bar: 360×6 HUD units versus existing life bar 180×16, gold fill,
  directly above the hotbar; fit resource/life/breath/money/notifications through
  the existing shared layout owner. Remove the old numeric HUD line. Exact XP
  stays available in Character or existing `/xp`; propose a small level label
  beside the bar and a full bar at the level cap.
- Check long quest titles, three tracked quests, ten party members, small
  windows and HUD scaling. No per-tick unchanged HUD writes.

### D. Live atlas markers — coordinator Astra

Viewer: gold directional triangle with outline; online party members: cyan
triangles with names/tooltips. Viewer draws last. Offline members retain their
party listing but have no fictitious current map position. Show only markers
inside the chosen world/region view. Names may move to hover in dense clusters.

Refresh only while the map is actually open, initially at a throttled 0.5 s
interval, and only when visible marker state changes. Preserve selected view,
detail and click identity; closing/switching tabs stops updates. Use a finite
heading sprite set rather than continuously creating unique media. Confirm the
formspec update path does not disrupt pointer interaction before expanding it.

Approved addition: atlas markers for known authored quest givers
with the existing ready/available/active/locked precedence and name/status tooltip.
Reuse the same quest authority. No remote accept/turn-in, target tracking or
travel permissions. This is preferable to an unrelated large WP this round.

## Coordination and scope decisions

- Parallel A/B/C initially, D when a native slot is free; current runtime has
  three child-agent slots. The coordinator owns cross-lane integration/docs.
- B may draft independently, then freezes giver/socket contracts with A.
  C owns shared HUD layout; D owns map UI/provider changes. Reviewers are fresh
  agents who did not author the work they review.
- User approved 36 additional quests, targeted reward retuning and the atlas
  quest-giver layer. Cosmetic defaults above are authorized implementation
  choices. Incorporate further playtest findings without silently growing scope.
- WP17 waypoints are a good following increment with decided visit-unlock and
  on-site travel rules (`docs/design/world.md` §6), but complete travel includes
  boats/Housing and should not silently enter this visual/content round.
- Unexpected major complexity pauses the affected lane for user discussion.

## Validation budget

Follow `docs/research/luanti-lua.md` Interpreter and test strategy: changed Lua
gets the 5.1 parser, SETGLOBAL inspection and five sweeps (tools explicitly
included). Development uses bounded LuaJIT fixtures. At final freeze use one
compact PUC process and its identical LuaJIT counterpart, compare canonical
output; reviewers inspect evidence without rerunning it. No seed fleets,
full-world preparation, broad historical WP40 suites or intermediate PUC runs.
Respect the workstation-wide seven-interpreter-process cap and idle scheduling
for any independent worker fleet; do not create a fleet for tiny checks.

POI integration must cover the actual manifest/planner consumers, walkable
approaches and NPC sockets with only representative chunks. UI acceptance needs
the user's fresh-world playtest after independent review, merge and sync.
Ratified rules are folded into design docs. This execution record owns progress
and handoffs, not a competing game-design authority.

## Live execution ledger

- Base: main `6908d1d5`; integration branch `wp15-world-polish`.
- A POIs: native Astra `r15_poi_impl`, authored in `/tmp/grug-r15-poi`.
  `f36b57c6` integrated as `4dc4f842`, then independent Sol review clean.
  Two earlier visual corrections added working details and varied camp layouts.
  Final author inspection identified two Medium raised-lookout landing gaps;
  both corrected and independently re-reviewed clean by Sol.
- B quests: native Sol `r15_quests_impl`, `/tmp/grug-r15-quests`.
  `c07c8984` integrated as `4433b97c`; independent Astra review clean.
  102 quests / 30 NPC identities, including 36 local quests. XP ledger accounts
  for concurrent objectives; existing later rewards intentionally unchanged.
- C HUD: native Astra `r15_poi_design`, originally `/tmp/grug-r15-hud`.
  `75370cc7` integrated as `146c551f`. Independent Astra found one Medium:
  GUI font scaling differs from HUD geometry scaling. Original author fixed
  party/side-width handling directly in root; focused independent review clean.
  Central legacy combat-stack text at extreme unequal scales remains a separately
  documented limitation, not a newly claimed responsive-UI feature.
- D atlas: coordinator Astra implementation; foundation `307d3ec2`.
  User approved resetting to Character when Map closes. Open-only half-second
  compare-first refresh is implemented; leave/death clean up live sessions.
  Independent Astra provider review and Sol lifecycle review are clean after
  correcting selected text surviving regional clipping (Medium) and replacing
  an overstated reconnect fixture claim with the tested disconnect claim (Low).
- Cooking user follow-up: Astra investigated actual NPC, formspec/peer and
  PlayerMeta paths. No confirmed cause or safe production fix. Existing local
  log has no instrumented trainer actions. Keep report open; see
  round15-cooking-investigation.md for the focused two-client reproduction.
- Final tools/r15_final parser/SETGLOBAL/five sweeps pass for 17 Lua files.
  One final PUC/LuaJIT pair matches canonical SHA8de2aaf7c4080ad0d423f36177318a338c66cae5f72f8992cbc3bc14ab509f46.
  Native3chunk integration passed: 102/30 registry,12,670cells,fiveNPCs.
  Frozen production payload matches all2,045 files of the native snapshot.
- Final completion/playtest docs record technical PASS; merge/sync/push pending.
- Thread cap requires reusing non-author lanes: Sol reviews POIs/atlas; POI
  author Astra reviews HUD; HUD author Astra reviews quests. Never self-review.
  No CLI agents; no reference-project or user-world edits.
