# Round 85 — The arena at the map's centre, grid claims (0.85.0, map reset)

**Status: started on the user's go, 2026-11-21.** Drafted on 2026-11-21 from the user's rulings at the end of
Round 84. Version **0.85.0**, a **map reset**: a new place in world generation, and claims
change their shape. Production runs 0.83.0, the workstation 0.84.1; the upgrade must work
from both. The round starts on the user's "go".

An independent Opus review of this plan (2026-11-21, verdict APPROVE AFTER FIXES: five
High, eight Medium; orchestration `r85/reports/plan-review.md`, with file and line evidence
the briefs take over) was checked by the coordinator (three load-bearing claims against the
code) and worked in. Its findings about the code are starting points: every lane re-checks
its own facts first (round workflow §2 step 4).

Preparation that exists: the arena draft "Breach Road", second pass
(`tools/r84_arena_draft/`, its `REPORT.md`), the site study (`tools/r84_site/`, orchestration
`r84/reports/site-report.md`), the claim capacity study (`tools/r85_claimcap/`, orchestration
`r85/reports/claimcap-report.md`), and the
[housing rework concept](housing-rework-concept.md), whose Part A this round builds.

Not in this round: the account Claim Stone, home names and the Account page "The Charter"
(the concept's Part B: the next, smaller round; the user, 2026-11-21) and the soft map reset
(Part C: built when the first one is needed).

Routing: to be confirmed by the user at the start (Round 84: this session coordinates, Opus
implements and reviews, GPT-6.2 Astra does art and design).

## How to add to this document

- A new ruling goes to §2 with its date. A lane goal changes in §4, a row in §1.
- A **ruling** is the user's, with its date. A **proposal** or **finding** is not a ruling
  until the user says so; a coordinator default is marked as such.

## 1. Lanes and order

| Wave | Lane | What | Model | Needs |
|---|---|---|---|---|
| 1 | WORLD | The arena as a rule of world generation: the site chosen by rule near (0, 0), ground levelled across both zones and blended into the terrain, no water in it, the middle road through its mouths, the protected footprint; one pure layout file for the later lanes | Opus | — |
| 1 | MASK | The claim mask as pure Lua over the world plan (zones, settlements, roads, camps, leaders, quest places, rare routes, capital rings), the quest kinds' ground per chunk, the stored mask and fingerprints | Opus | — |
| 1 | RESET | The pre-reset pass reads old and new claim records; the map reset declaration; the contract text | Opus | the record format agreed with CORE at the start |
| 2 | CORE | A claim is one map chunk: the registry's new record, the placement check with mask and quota, everything that reads a claim's extent | Opus | MASK |
| 2 | BUILD | The arena's blocks: terraces, stairs, both halls, the fringe that takes the local surface, dressing, smoke | Opus (Astra for look fixes) | WORLD's layout file; the user's go on WORLD's pictures |
| 2 | TERRITORY | The halls as friendly territory, two waystones, no hostile spawns, protection, names | Opus | WORLD's layout file |
| — | CLAIMUI | **Moved to the next round** (ruling 23). The placement preview by chunks with the quota's red, claim frames, the stone's texts, Help | — | — |
| 3 | D | Version, changelog, status, design documents, Completion | Opus | all above |

The user sees pictures before a merge at three points: WORLD's site on the eleven seeds
(before BUILD starts), BUILD's capture of the arena, and CLAIMUI's screenshots.

## 2. Rulings

### 2.1 Carried over (Round 84 plan §2, the user, 2026-11-21)

1. **The arena stands at the map's centre on the middle road**; the road may run through it,
   and the user prefers that. Each faction's building holds a waystone that is discovered
   like every other; the building's interior is friendly territory for its faction,
   everything outside is contested as everywhere in the Battlegrounds. The arena is
   protected from digging and building. (Ruling 6.)
2. **The placement works on every seed,** as a rule of world generation, never a spot picked
   on one seed. (Ruling 12.) The production seed is 3684797457838814663. (Ruling 10.)

### 2.2 New (the user, 2026-11-21)

3. **The design is "Breach Road", second pass:** the road at 0, the ruined galleries at +3,
   both halls and the lookout spurs at +6, twelve stair flights, two smoke hearths (22 live
   particles at most), sparse dressing, a block palette that fits the zones it stands in.
4. **A full map reset, claims included.** The arena's placement makes no compromise.
5. **The battlefield blends smoothly into the landscape:** no steep cut walls where they can
   be avoided.
6. **Grid claims** as the [concept](housing-rework-concept.md) §2.1 records them: one map
   chunk of 80 × 80 per claim; no claim ground where a chunk holds a road, a settlement or
   POI (with today's 16-node margin), a camp, a leader's spot, a quest place or a rare's
   route point; the seven level 11–30 zones and the three capital zones, the latter with one
   full chunk of distance to the city; a quota at placement that keeps half of every quest
   mob kind's ground free of claims; the minimap preview shows the allowed chunks, and a
   kind's remaining chunks turn red when its limit is reached.
7. **Mask and per-chunk fingerprints are stored in the world** already in this round, for a
   later soft reset.
8. **About 280 claims per faction are enough for now.**

### 2.3 Answers to the plan's questions (the user, 2026-11-21)

9. **The arena stands at the map's centre, on the best site near (0, 0).** (Revised on
   2026-11-21 after the user's question; first ruling: fixed at (0, 0).) World generation
   searches a small window around (0, 0) on the natural terrain for the site that needs
   the least work (no water, little relief under the footprint and its blend, close to
   where the middle road runs anyway), then levels the ground there so that it blends in
   (ruling 5). The search is a rule, the same on every seed, and reads only the natural
   world, which the arena does not change. **The road mouths are connected to the middle
   road** on every seed.
10. **No guards.** An enemy may stand in a hall unharmed. A defender who arrived unflagged
    (for example through the hall's waystone) is safe there, because the hall is friendly
    territory. Guards would let a player who fights outside flee into their protection
    just before dying; that is not intended.
11. **The hall is a muster point, not a safe room.** The flag rules are exactly today's
    ([pvp.md](../design/pvp.md) §2), with the hall as own peaceful territory: entering it
    clears the location flag at the next sample (once a second), so a player who had no
    PvP contact in the last 60 s and no running button timer is unflagged at once; a
    player who comes in from a fight keeps the flag for 60 s after the last contact and
    can be attacked inside. Area effects that pass walls apply as everywhere. Help says so.
12. **Mounts in the halls:** no special rule.
13. **No hostile spawns in the arena's area** (the protected footprint and its fringe).
14. **Slivers do not count:** a chunk that is not wholly claim ground is no claim ground.
15. **Steep ground is neither filtered nor marked.**
16. **The quota's arithmetic:** a quest-named kind's ground is the 32 × 32 spawn cells of
    all its regions in its zone, counted in node columns; a claim takes the columns of
    those cells inside its chunk; a placement is refused when the columns taken by all
    placed claims (drafts and expired ones included) would exceed half of the kind's
    ground. Ground that can never be claimed counts as free. Measured on the production
    seed (capacity study, follow-up 2): a mask of 366 / 373 chunks (The Accord / The
    Throng), 336 / 323 claims at once in a plausible order of placement, 349 / 340 at
    most; the ten other seeds 272–383 / 302–357.
17. **No other work that waits for a map reset** joins this round (the backlog's M3-01 and
    the capital plot options stay where they are).

### 2.4 The plan review's questions (the user, 2026-11-21)

18. **The road (R1):** the middle road is bent through the arena on every seed.
19. **Flight (R2):** no special rule in the halls; whatever holds for flying in the
    Battlegrounds holds inside them.
20. **The mask after a later update (R3):** new placements follow the running version's
    mask. A home yields when the world demands it: at a map reset, a claim whose chunk is
    no longer claim ground or whose ground changed (roads, places, cities moved) is
    cleared and its contents go to the Belongings tab; with an unchanged seed and terrain
    most or all homes stay. Between resets a compatible update clears no standing home
    (coordinator's reading of the user's answer; the generated world does not change
    without a reset).
21. **The Expeditions tab (R4):** the two arena waystones are ordinary waystones, the
    Expeditions tab included.
22. **Calming the land (R5):** allowed, with the radius as small as the site permits;
    wide flat ground looks dull. The site search (ruling 9) exists to keep it small.

### 2.5 During the round (the user, 2026-11-22)

23. **CLAIMUI moves to the next round,** which also holds the account Claim Stone, the
    home names and the Account page: those change the same texts and the same preview, so
    they are built once, as one round of parallel lanes. 0.85.0 does not go to production
    on its own; production is upgraded only after that round. Until then the placement
    preview is known to be wrong (a carry-over, §4 CLAIMUI): placement itself decides
    correctly and names the rule.
24. **The arena's protection covers the site itself,** not the blended ground around it.
25. **BUILD's deviations from the draft stand:** trodden dirt follows the biome, the
    hearth smoke lives 3 s (the shared helper's cap), the waystone stands between the dais
    blocks.

Still a coordinator default:

- The place's name on the location line and the map (default: "Breach Road") and the two
  waystones' names (TERRITORY proposes).

## 3. Shared conventions

### 3.1 Coordinator defaults (the user may overrule)

- The arena's halls come from the draft's two templates (`tools/r84_arena_draft/templates/`);
  the field (terraces, stairs, breastworks, rim) exists in the draft only as a Python
  construction (`sites.py`) and is ported to deterministic data. A lane that must deviate
  from the draft (terrain, engine limits) reports the deviation with a picture.
- Old claims end with the reset as at every map reset: containers are packed into the Claim
  Stone inventory, a placed stone does not come back, a carried one stays
  ([housing.md](../design/housing.md) §3, §3a). Nothing is converted.
- The 16-node radius around a leader's spot, a quest place and a rare's route point, and the
  capital distance rule applied to chunks that hold capital-zone ground, are the capacity
  study's choices and stand as defaults.
- Numbers of the capacity study are rough targets; no gate is built around a claim count.
  They are measured again once after WORLD's merge, because roads and rivers may move.

### 3.2 Release

0.85.0, **map reset** (`tools/web_data/upgrade.json`). The platform resets the map as at
every map reset; nothing new is asked of it in this round. Every new piece of map-bound
state (the claim records' new version, the stored mask and fingerprints, the quota's
counters if stored) gets its row in the upgrade contract's table of what a map reset
clears.

### 3.3 The claim record (agreed before wave 1 starts)

- `claim.center` stays the stone's position; the claim's area is the chunk that holds it.
  Most readers of a claim then need no change. The stone stands at least one node inside
  its chunk's edge, so that its arrival cube lies in the claim.
- The claim record gets a new version with empty fields for the concept's Part B (the
  owner's kind, the home's name), so the next round needs no migration.
- The `player:` record keeps its version: the game's own map reset only resets records it
  can read.
- The pre-reset pass (`tools/migration/pack.py`) reads **both**: the old record with its
  101 × 101 constants frozen in the tool, and the new one with the chunk as the area.
  Reading only the new one would pack nothing on production.

### 3.4 Shared files and merge order

- `mods/MAPGEN/grug_mapgen/wp40/world_protection.lua`: WORLD owns it; MASK needs a 2D road
  query there that does not exist yet. MASK adds it as its first commit and WORLD merges
  that commit before its own work on the file, or WORLD adds it on MASK's request: the
  coordinator settles which at the start.
- `grug_mobs` (a region-cell accessor for MASK; the spawn-region builder for TERRITORY):
  different files where possible; MASK merges first.
- `mods/PLAYER/grug_inventory/help.lua` and `grug_map`: TERRITORY and CLAIMUI both touch
  them; TERRITORY merges first (wave 2), CLAIMUI starts from the merged branch (wave 3).
- `tools/README.md`: append-only rows. `docs/design/housing.md`: MASK and CORE own §1–§2 and
  §6.4, CLAIMUI the preview paragraphs, RESET §3.
- Merge order: wave 1 MASK, WORLD, RESET; wave 2 CORE, TERRITORY, BUILD; wave 3 CLAIMUI, D.

## 4. Lane goals

### WORLD

The world plan knows one more place, the arena, on every seed by rule: on the best site in a small
window around (0, 0) (ruling 9), in the two Battlegrounds zones, whose border runs through or close by the site.

- **The site.** A pure rule over the natural terrain (the arena is hidden from the zone
  field, the terrain field and inland water, as the site study's `nofield_through`
  measured, so the natural world does not depend on the site): candidates in a window of
  up to 200 nodes around (0, 0) (the user, 2026-11-21), scored by water columns, relief under the footprint and
  its blend, and distance to the natural middle road. The lane sizes the window and the
  score from the eleven seeds and reports, per seed, the chosen site against (0, 0):
  relief, water columns, blend distance, road detour. Every reader of the arena's position
  takes it from the layout, never from a constant.
- **Levelling.** Today's fitting of a place takes its reference height from its own zone
  and grades only its own zone's columns, with a collar of 28 nodes; on a zone border that
  leaves a cut wall, and 28 nodes cannot absorb the measured 21–139 nodes of relief. The
  lane builds a fitting that levels **both** zones' columns to one datum and blends into
  the terrain over a distance sized from the relief and kept as short as the site
  permits (rulings 5 and 22; no wide flat plain), so the draft's
  footprint (levels 0 / +3 / +6; check the footprint's size against the draft's templates,
  99 × 91 in the report) stands without cut walls.
- **Water.** No lake, river or sea column lies in the footprint. A site set by rule
  does not get the placement's river guard, so the water layout must see the arena; the
  lane decides and reports which world readers see it (zone field, terrain, inland water,
  roads) and what that moves outside the Battlegrounds.
- **The road.** The middle road is one routed pair today, and roads bend round a place's
  reserve; on production it crosses z = 0 at x = −24, on one seed 136 nodes away. The lane
  routes it through the arena (ruling 18): a via-point with two legs, and the draft's straight
  inner segment at the road datum between the two mouths.
- **The layout file.** One pure Lua file (on the pattern of the dragon arenas' layout)
  gives the later lanes the footprint, the datum, both halls' interior boxes, the waystone
  cells, the road mouths and the smoke hearths. It is merged before wave 2 starts.
- **Evidence.** The arena's chunks join the seed fleet's sample, with a per-seed check: no
  water in the footprint, the road through both mouths, a grade limit on the blend, no
  seam at the zone border. The lane reports what moved against 0.84.1 on the eleven seeds
  (zones, roads, rivers, capitals) with the site study's comparison, and shows the site on
  the eleven seeds as pictures. Seed fleet `quick` after the lane.

### MASK

The claim mask as pure Lua over the world plan, so tools and fixtures run the real file:
which chunks are claim ground (ruling 6), the capital rings with their chunk of distance,
and per chunk the node columns of every quest-named kind's ground (ruling 16).

- **Cost.** The capacity study's raster took about 81 s per faction; the game cannot do
  that at every start. The mask is computed once and cached; the lane measures the first
  start and later starts and reports them (a comparison, not a target; a noticeably slower
  start goes to the user).
- **What is stored** (ruling 7), in a format the Python pre-reset pass can read, in the
  world folder: a header (format version, game version, seed, the game's noise digest),
  the mask as of the reset, and per claim-ground chunk **separate digests per component**
  (terrain height with a border strip towards the neighbours, water, zone, roads, places),
  so a later soft reset can tell what changed. Written once per map, at the first start
  after a reset, never at a later start.
- **Which mask the game uses.** New placements follow the mask of the running version
  (ruling 20); the stored data is the snapshot of the reset. Between resets no mask change
  clears a placed claim; at a reset a claim yields when its ground changed.
- The capacity study's tools check the mask against the study's counts, once now and once
  after WORLD's merge.

### RESET

The pre-reset pass packs the containers of old claims as before and understands the new
record too (§3.3); its fixtures stop pinning the current `registry.lua` for the old format
and carry frozen constants instead. It is run against a copy of a world with old claims and
against one with new claims. The release is declared a map reset; `check_upgrade` passes;
after the reset no claim record is left, the Housing Steward hands out stones, "Set as
home" falls back as at every map reset. The upgrade contract's table and
[housing.md](../design/housing.md) §3 say what happened to old claims.

### CORE

A claim is one map chunk (ruling 6, §3.3). The placement check asks the mask and the
quota; the quota counts every placed stone, draft and expired included (ruling 16; the
review checked draft griefing, expired claims, refuelling and races: no extra mechanism is
needed, a draft crumbles after five minutes and frees its share). Everything that reads a
claim's extent follows the chunk: protection, interaction, renewal, spawns, the mob push,
the arrival cube, the admin commands, the minimap's claim frames' data, home travel and
respawn, and the about 25 fixtures and tools that load or pin the claim geometry (the
lane lists them first and reports the list). The capital zones' single gate
(`grug_housing/registry.lua`, `civic_no_hostiles`) opens under the mask. The refusal
message names the rule that refused, in one line.

### BUILD

The arena is built at generation from WORLD's layout file: the two halls from the draft's
templates, the field ported from the draft's Python construction to deterministic data
(no noise functions at generation). The fringe takes each column's local surface, so the
site fits whatever biome patch the seed puts there. The two hearths smoke through the
shipped particle helper within the draft's budget (22 live particles). A headless capture
of the site on the production seed and two others goes to the user; the lane is merged
after the user's go.

### TERRITORY

Inside each hall the faction is at home: the PvP zone answer gets a small overlay for the
halls' interior boxes (territory is answered per zone today), in 3D, so the open courts
and the field stay contested. The flag rules are today's (rulings 10 and 11); there are
no guards and no flight overlay (ruling 19). Two waystones join the fixed list and are discovered
like every other (ruling 21). The spawn-region builder treats the arena as protected in **both**
zones, so no leader spot, camp or quest place can land in it, and no hostile mob spawns on
the footprint and its fringe (ruling 13). The whole site refuses digging and building for
everyone; the terrain guard covers it against fire and explosions. Help says that the hall
is a muster point, not a safe room. The lane proposes the two waystones' names.

### CLAIMUI

**Not built in this round (ruling 23).** Carried over: the claim mode's overlay is still the
old per-column one and shows ground as allowed that the mask refuses (roads, camps, leader
spots, the capital rings, the quota); the green square has the chunk's size but is centred
on the player; `housing.md`'s preview paragraphs describe the old preview. The goal below
and the brief written for it (`r85/lane-briefs.md`, "CLAIMUI") go to the next round.

With the Claim Stone in hand the minimap shows the chunk grid: allowed chunks, forbidden
ones, the chunk the player stands in. The quota's red is **per chunk**: a chunk turns red
when its own columns of a kind exceed what the kind has left, so a chunk with a small
share may still be allowed after a larger one is not; what the preview shows as allowed is
never refused by the quota. The overlay is recomputed at every placement and removal.
Claim frames on the minimap, the stone form's texts and Help follow. Screenshots of the
preview in a claim zone, in a capital ring and at a full quota go to the user; the lane is
merged only after the user's go.

### D

Version 0.85.0, changelog, status, the design documents the lanes did not finish, this
plan's Completion and Carry-overs, and the concept's Part A marked as built.

## 5. Rules

- AGENTS.md and the round workflow apply; the faction names, "Expedition" and the naming
  rule hold in briefs and pages too.
- Fixtures: a lane runs only the fixtures its change touches; the one full run is the
  coordinator's at the round end.
- A fix delta that changes game logic gets an independent delta review.
- CLAIMUI and BUILD are merged only after the user's explicit go on pictures; BUILD starts
  only after the user saw WORLD's pictures.
- Engine boots for world generation stay few and short (a chosen region, never a whole
  world): each brief names its lane's number of boots; probes cap their log output.
- The terrain guard applies: nothing in this round may let fire or explosions damage the
  arena.

## 6. Verification and human tests

Per lane the gates of round workflow §3 and its own fixtures. World generation: the seed
fleet with the arena's chunks in its sample and the per-seed arena check (WORLD), `quick`
after WORLD and after BUILD, `full` at the round's end. At the round end the full gates,
the capacity study's rerun, and one headless boot. A headless capture shows blocks and
terrain, not particles in motion or how riding feels.

Assumptions the lanes build on and must check first: that a levelling across a zone border
can be added to the existing fitting; that routing the middle road through a via-point
leaves the other roads' rules intact; that the mask can be computed in the game at an
acceptable first-start cost; that `claim.center` as the stone's position keeps most readers
unchanged.

Human-test proposals (offers):

- Ride the middle road through the arena from both ends; climb to both lookouts.
- Enter the enemy hall as an unflagged and as a flagged player; stand in your own hall
  while an enemy is inside.
- Place a Claim Stone in a claim zone and in a capital ring; try a chunk with a road.
- The rehearsal realm: reset a copy of production's world (0.83.0) and open the Belongings
  tab.

## 7. Orchestration notes

- **Start state:** main at 0.84.1 (not pushed at the time of writing); the round branch
  `round85` holds this plan, the concept and the capacity study's tools.
- **Before wave 1:** the coordinator settles the claim record (§3.3) and the owner of the
  2D road query (§3.4) with the lanes' briefs.
- **Platform:** a note to the kaesual coordinator that 0.85.0 is an ordinary map reset and
  that the keep-claims interface discussed earlier is not needed.
- **Process budget:** the seed fleets of WORLD and BUILD share the Lua queue with the
  claims lanes' fixtures; at most eight Lua processes.
- **Compaction checkpoints:** C0 before the start (the user compacts after this plan); C1
  after wave 1 (the user looks at WORLD's pictures); C2 after wave 2; C3 before D and the
  round-end run.
- **Decided during the round:** the site pictures, the arena capture, the claim preview
  screenshots, the waystones' names.

## Completion (2026-11-22)

Six lanes (Opus each) in two waves, each with an independent Opus review; CLAIMUI moved to
Round 86 (ruling 23) and was not started. Release **0.85.0**, a **map reset** (the twentieth;
`tools/web_data/upgrade.json`, no step, `map_reset_pass` stays 0.50.0): world generation
changes in the Battlegrounds and on the middle road, and the claim record moves to v3. Saved
keys: `grug_housing` `claim:<id>` is written and read only as v3 (twelve fields, `kind` and
`name` empty); the pre-reset pass reads v2 and v3; two new world-folder files
(`grug_claim_mask.txt`, the map's snapshot, and `grug_claim_ground.txt`, a cache); player
meta `grug_home:waypoints` may hold the two hall stones' ids. Merge order into `round85`:
RESET, MASK, WORLD, CORE, TERRITORY, BUILD, then lane D. 0.85.0 does not go to production
on its own (ruling 23).

**What shipped:**

- **RESET:** `tools/migration/pack.py` reads the v2 record with its 101 × 101 square frozen
  in the tool (`V2_RADIUS` 50) and the v3 record with the map chunk as its area; a record of
  another version or shape is skipped, counted in `pack_done` (`skipped`) and named on
  stderr. v2 behaves byte-identically to before (`tools/r85_reset/diff_v2.py` on four world
  variants against the base); the v3 area is exact to the chunk's edges at both signs. The
  fixtures stopped pinning `registry.lua`'s encode line and carry frozen constants; three
  checks of `r50_ptool` that had failed since Round 53 declared steps were corrected. New
  fixture `tools/r85_reset` (27 checks: the game's reset clears every `claim:` key of any
  version, owners get `needs_stone`, the home falls back to the innkeeper). The upgrade
  contract's table and housing.md §3 say what happens to old claims.
- **MASK:** the claim mask as pure Lua (`grug_housing/claim_mask.lua`, the store, the engine
  glue `mask.lua`): per faction which 80 × 80 chunks are claim ground (a 25-column lattice
  first, then every column), with a reason id per refused chunk, the capital rings (one
  chunk of distance), and per chunk the node columns of every quest-named kind's ground for
  the quota. Production seed: **366 / 373 chunks** (The Accord / The Throng), exactly the
  capacity study's set (also on 17713522922938657774 and 12345), 47 quota kinds; unchanged
  after WORLD's merge. Cost at the first start of a world plan: mask 19.2 s plus snapshot
  5.6 s (after WORLD's merge 21.0 s and 6.2 s), later starts 0.19–0.35 s (cache hit). The
  snapshot `grug_claim_mask.txt` (739 chunks, 73,600 bytes on production; five fingerprints
  per chunk over the chunk and an 8-node strip, [format](../technical/claim-mask-format.md))
  is written once per map. Fix round 1: a missing region map fails the mask closed, a failed
  snapshot leaves the mask in use (both `[GRUG-SEVERE]`). Fixture `tools/r85_mask` (86
  checks, with the real `mask.lua` on a fake engine). Mask fix (found by the round-end
  comparison with the study on seed 9512886083845910081): a city shape's row may hold an
  interval that covers no column, and the capital ring counted its chunk as a city chunk, so
  an Accord chunk two chunk rows from Dur Brannoc was refused as next to a capital; such an
  interval now marks nothing (delta review MERGE). The change can only add claim ground;
  production's mask is byte-identical.
- **WORLD:** the arena's site by rule (`wp40/breach_site.lua`): candidates every 8 nodes
  within 200 nodes of (0, 0) on dry land of the two Battlegrounds zones, scored by levelling,
  blend reach, the middle road's detour, the distance off z = 0 and (fix round 2) steep
  natural faces above grade 1.5; the hull levelled to one datum across both zones and
  blended over 8–64 nodes (up to 128 on a fallback site, below); the middle road as a straight inner road between the two mouths
  and one leg from each mouth to Highcourt and Gor Drazhak; the layout file
  `wp40/breach_layout.lua` for every later reader. On the eleven study seeds: no water
  column in the hull, at most 0.75 added grade (the limit is 1.25 over 4 nodes), blend reach
  12–45 nodes, search 0.08–0.31 s; production's site (−72, 8) did not move in fix round 2,
  three study seeds did. Outside the Battlegrounds the water texts are identical on all
  eleven seeds and no anchor moved; the middle road and the trails that join it moved
  (426–3,128 road cells per seed), and the Highcourt / Gor Drazhak capital texts changed on
  8 of 11 seeds (gate positions; a canal on two seeds). Fix round 1 (review M1, M2, L3, L5):
  the Gor Drazhak leg keeps the ring gap, the seed fleet samples every arena chunk and both
  sides of the hull's edge, the `r46_pl` probe expects `P2`. Fix round 2 (the user's
  decisions on the pictures): the face term, and a missing arena road leg or inner road is
  `[GRUG-SEVERE]` (key `arena_road`). Fixtures: new `tools/r85_world`; `r29_mgeo` and
  `r46_pl` rewritten.
- **CORE:** a claim is the map chunk of its stone (`registry.lua`: record v3, a chunk index,
  `claim_at` one lookup, 92 → 62 ns in a micro-bench), placed through the mask and the
  quota, with one refusal line per rule (housing.md §2 "Refusals"); one claim record per
  chunk (drafts and expired ones included); the capital-zone gate removed; no mask refuses
  every placement. Every extent reader goes through `claim_at` or `claim_bounds`; the
  minimap's claim frames and other claims' rectangles follow the chunk. One engine probe on
  production: every claim-ground chunk's interior accepted and its edge refused, 0 of 9,609
  / 9,602 refused chunks differing from the mask's reason, all 47 kinds named. Fix round 1
  (review M1, L3): `r81_social` H follows the chunk rule, the quota line says what the check
  refuses. Fixtures: new `tools/r85_core` (75 checks); `r25_claim_core`, `r25_interaction`,
  `r25_spawn_guard`, `r37_po`, `r41_up`, `r47_an`, `r502_cmap`, `r502_home`, `r531_flight`,
  `r69_push`, `r81_social` and `r85_mask` rewritten; the 0.84.1 registry frozen for the
  study tools (`tools/r85_claimcap/registry_084.lua`).
- **TERRITORY:** each hall's interior (3D) is its faction's peaceful ground
  (`grug_pvp/rules.lua` `R.hall_at`, `R.zone_answers`), the flag rules unchanged; two
  ordinary waystones, Breachward Hall and Breakfang Hall, the eighth of each network; the
  protected box (footprint bounds, datum −10 to +35) refuses digging and building ("Arena –
  protected") and a world alteration guard keeps fire, explosions, liquids and growth out;
  no ambient non-critter spawn on the footprint and fringe, no camp, leader or quest place
  on a reserved cell, no rare patrol point on the fringe; the name on the location line and
  a PvP-layer marker; one Help paragraph. On the eleven seeds every hall node answered right
  (2,233 of 2,233 per hall), open ground contested (3,366 of 3,366 samples), nothing on the
  fringe; one engine probe (49 checks). Fix round 1 (review L1): one helper
  `spawn_regions_core.reserved_of` gives the reserve to the game, the seed fleet and the
  mask tool, and the fleet refuses spawn-region content on the arena. Fixture
  `tools/r85_territory` (6,084 checks); `r29_w` knows the eight stones.
- **BUILD:** the arena's blocks at generation (`wp40/breach_model.lua`, `breach_writer.lua`,
  the field `breach_field.lua` generated from the draft's own construction by
  `tools/r85_build/gen_field.py`, the halls from the draft's templates), the dressing and
  trodden earth by the biome under each column, the game's waystone on each hall's cell,
  the hearth smoke (one 1 s spawner per hearth a second, at most 18 live). Every arena cell
  right on the eleven seeds (200,303 cells each, the fleet's `arena_blocks`); fleet time on
  production's nine arena chunks 0.594 → 0.618 s; the model holds 2.8 MB per Lua state.
  Seven engine boots (three captures of production, one of each of two other seeds, a smoke
  boot, and on the merged branch one probe that proved both hall waystones' arrival cells,
  55 checks). Fixture
  `tools/r85_build`.
- **Seed fleet `quick`:** 100 of 100 seeds after WORLD, after its fix round 2 and after
  wave 2 (on the merged branch of all six lanes).
- **Lane D:** version, changelog, upgrade declaration and its history entry, this section,
  STATUS, README, the concept's Part A marked as built, and the docs the lanes left wrong
  (the placement preview as it is, roads in claims, the claim goal in ROADMAP).

**Reviews:** RESET MERGE (no findings). MASK MERGE (Low 1, Low 2; fix round 1, delta review
MERGE). WORLD MERGE AFTER FIXES (M1 the ring gap, M2 the fleet's arena chunks, L3 the
one-sided grade check, L4 the hairpin, L5 the stale probe; fix round 1, delta review MERGE;
fix round 2, delta review MERGE with three Low: two wording points fixed by the coordinator,
the optional face fixture case a carry-over). CORE MERGE AFTER FIXES (M1 `r81_social`, L2
the claim-mode square, L3 the quota wording; fix round 1, fixture and text only, checked by
the coordinator; L2 went to CLAIMUI). TERRITORY MERGE (L1 the tools' reserve, L2 stones
before BUILD; fix round 1 for L1, delta review MERGE, the fleet check shown to fail on an
injected leader). BUILD MERGE (no findings).

**The user's choices during the round:** production runs 0.83.0 (not 0.78.0); the
answers to the plan review's questions (rulings 18–22) and the site search window of 200
nodes (ruling 9 revised); the reading of ruling 20 confirmed; MASK's first-start cost
accepted (option a); the go on WORLD's pictures, taken as its four recommendations (keep
sites up to 200 nodes off the centre, avoid steep natural faces, keep the 40-node mouth
stretch, a missing arena road is severe); the blend outside the arena stays unprotected
(ruling 24); BUILD's three deviations stand (ruling 25), taken as the go on its captures;
the waystone names as built (no objection, still a coordinator default); CLAIMUI moves to
Round 86 together with Part B and the Account page, and 0.85.0 reaches production only
after that round (ruling 23).

**Deviations from the plan:**

- **CLAIMUI not built** (ruling 23). **Known defect:** the Claim Stone's placement preview
  is still the old one: red per column by the mask's column rule and the settlement margin
  (no roads, camps, leaders' spots, quest places, rares' route points, capital rings or
  quota), every claim as its chunk in red, and a green 80 × 80 square centred on the player,
  not the chunk the stone would claim (`grug_map/base.lua` `claim_overlay`,
  `minimap.lua` `draw_square`). Placement itself decides correctly and names the rule.
  housing.md §2 "Placement preview" says so.
- WORLD: the footprint has 6,907 columns by the layout's polygon rule, the draft's raster
  6,957 (the 50 are rim columns, where nothing is written); relief under the hull at (0, 0)
  19–129 nodes, not 21–139; the added-grade limit is 1.25, not 0.5–1.0 (no vertical cut);
  sites lie up to 200 nodes from the centre, and on 7 of 11 seeds the hull lies wholly in
  one zone.
- MASK needed no 2D road query in `world_protection.lua` (§3.4): it reads the road
  corridors from its own file. It added one return field to `wp40/r7_loader.lua`
  (`capital_protection`). A border cell held by two zones' region maps counts for both
  kinds (13 chunks on production gain columns against the study).
  Fix round 3 (found by the round-end fleet on seed 5664044364126834037): a world with no
  site that passes every rule no longer takes the coarse best with a 64-node blend (there
  the levelling cut a bank of 10 nodes over 4 where the ground rose 4). It takes, of the up
  to 64 candidates measured, the one that fails only the blend's width and needs the
  narrowest blend, with blends up to 128 nodes (on that seed: site (120, 160), reach 103,
  added grade 0.75); a fallback that needs more is a `[GRUG-SEVERE]` report (`arena_blend`).
  Seven of the fleet's first 115 seeds are such worlds and moved; a world with a passing
  site, production and the eleven study seeds among them, is unchanged (delta review MERGE).
- TERRITORY: the layout's fringe box is flat in y, so it is used by columns only; its fix
  round touched game code (`reserved_of`, no behaviour change, delta-reviewed).
- BUILD: seven engine boots instead of the planned three plus one; the hall templates moved
  to `building_templates/templates/`; the three deviations of ruling 25.
- CORE left eleven old engine probe mods on the old geometry (Carry-overs).

**Round-end gates** (on `round85`, 2026-11-22): the full `tools/run_fixtures.sh` once after
lane D: 387 passed, 0 failed; after the two fixes below the fixtures they touch (`r85_world`,
`r85_mask`, `r85_core`, `r37_dc`): PASS. Seed fleet `full`: first 303 of 304 (seed
5664044364126834037: the arena's levelling added 6 over 4, WORLD fix round 3), after the fix
304 of 304; the levelling adds 2 over 4 on 163 seeds, 3 on 124, 4 on 13 and 5 (the limit)
on 4; 25 seeds use the fallback site. The capacity study's rerun on the eleven seeds with
the game's mask beside it: the chunk sets were equal on ten seeds (production 366 / 373) and
differed by one chunk on 9512886083845910081 (the mask fix above), equal after it; per seed
1–11 mask chunks differ in their columns per kind (the border cell that counts for both
kinds). `check_fresh_server` PASS; `check_upgrade` PASS (0.85.0, map reset declared);
`r28_design/validate.py --game` 0 errors, 18 warnings; `r29_e4/income.py --check` PASS; the
building templates' gate PASS (286 templates, 0 errors); the bat mesh and the arena field
generator `--check` PASS; a headless boot on the production seed PASS with no
`[GRUG-SEVERE]` line, before and after the mask fix.

**Human tests (offers):** ride the middle road through the arena from both ends and climb
to both lookouts; look at the blend's slopes and the south leg's hairpin on seed
6866842473207; enter your own hall unflagged and right after a fight, then the enemy hall,
and stand in your own hall while an enemy is inside (watch the banner); discover both hall
stones and travel to and from them; try to dig on the arena; watch the two hearths; place
a Claim Stone in a claim zone, in a capital ring, in a chunk with a road and on a chunk's
edge, and read each line; hold the stone near a chunk's edge and compare the green square
with the frame after placing (shows the known defect); on the rehearsal realm reset a copy
of production's world (0.83.0) and open the Belongings tab, get a new stone from the
Steward and travel home to the innkeeper.

## Carry-overs

Each line names where it came from. The first five are wanted work and have BACKLOG lines.

**Wanted work:**

- **CLAIMUI, the placement preview** (ruling 23; the known defect in Completion): with the
  stone in hand the minimap shows the chunk grid (allowed, forbidden, the chunk the player
  stands in), the quota's red per chunk from `mask.quota_refusal(cx, cz,
  grug_housing.quota_taken())`, recomputed on `claim_set_version`, a line that says why a
  chunk is forbidden, a nil mask shown as nothing allowed; the stone's item text, the stone
  form's texts and Help describe the chunk rule and the quota; screenshots before the merge.
  The lane brief written for it is the material for Round 86, which builds it together with
  the account Claim Stone, home names and the Account page.
- **The housing concept's Parts B and C** ([concept](housing-rework-concept.md)): Part B
  (the account Claim Stone, home names) in Round 86; the claim record's fields `kind` and
  `name` are stored empty for it. Part C (the soft map reset) when the first one is needed;
  the snapshot `grug_claim_mask.txt` is its stored input.
- **Road cut walls** (WORLD fix round 3's delta review; the user, 2026-11-22: carried over):
  a road's cut slope ends 24 nodes from the road (`road_layout.lua` `SIDE_MAX`), so where a
  hill rises faster the cut ends in a wall at the side zone's edge: 10–19 nodes beside the
  south mouth leg on seed 5664044364126834037, up to 31 near the arena on study seed
  6410640627505506314, up to 24 away from it on 9512886083845910081; none on the other nine
  study seeds, production included. Older than this round, but the arena's mouth legs run
  through rougher ground. The fleet's and the site tool's grade checks skip every pair that
  touches a road column, so no check sees it; it touches ruling 5 (no steep cut walls where
  they can be avoided).

- **The Account page** ("The Charter") with the website's default reward list, agreed with
  the website on 2026-11-22: `default_rewards` inside the `accounts` object of the `sync`
  response, for realms that report the capability `rewards.defaults`. The amendment to
  [web-accounts.md](../technical/web-accounts.md) comes first.
- **CORE:** eleven old engine probe mods under `tools/` still read the 101 × 101 claim
  (`r25_claim_core`, `r25_spawn_guard`, `r25_interaction`, `r25_claim_distance`,
  `r26_claim_activation`, `r26_capitals`, `r41_up`, `r44_mb`, `r37_po`, `r502_cmap`,
  `r502_home`); no gate runs them, `r26_capitals`' would fail on `model.RADIUS`. Update
  before a rerun.

**Notes:**

- **WORLD:** the site score's face term `K_FACE * max(0, face - FACE_FREE)`
  (`breach_site.lua:419`) has no upper bound (a cliff of grade 5 costs 14 points;
  `min(face, 3)` if a fleet seed ever shows it), and no fixture case pins the term (delta
  review 2 Low 3 proposes one: a flat world with a step east of (0, 0)). The tool
  `tools/r85_world/site.lua` calls `hull_project` on every column (line 116; tool time
  only). The steepest study seed stays 4282870288782723 (face 2.25 after fix round 2, no
  better site in the window); 6410640627505506314 keeps 2.0. The search measures at most 64
  candidates (`EXACT_MAX`). The south leg's hairpin on 6866842473207 stays (115° at both
  stretch lengths). Swamp pools may lie in the blend, never on the hull.
- **TERRITORY:** the seed fleet and `tools/r85_territory/seeds.lua` sample the fringe's
  zones every 8 nodes from its minimum corner (`seed.lua` about line 350), so a zone that
  meets the fringe only in the last strips would go unchecked (theoretical). Mobs may walk
  onto the arena: only spawning is closed, there is no idle push off it. Neutral wildlife
  does not spawn on the fringe either (the existing protected-surface rule of roads and
  villages, critters exempt; the lane recommends keeping it). The older `WET_RESORT`
  fallback of the POI placement can ignore the patrol rule in a degenerate zone. Discovery
  reach (8 nodes) works through the halls' walls, as for every stone.
- **BUILD:** the main server builds the arena model (about 2.8 MB) only to learn the box
  height (`r7_runtime.lua` about line 190). The seed fleet's `R.chunk` never runs the
  air-chunk skip, so a wrong skip is caught only by `tools/r85_build` fixture E and the
  engine probes. The stale comment at `tools/r51_t4/compare.lua:144` is fixed (lane D). The
  waystone between the dais blocks is less prominent than the draft's lamp marker (an art
  pass). The hall pictures of two seeds predate the waystone (identical elsewhere).
- **MASK:** the first start of a world plan costs about 25 s more, and the mask's 19–21 s
  come back at the first start after every release that changes `grug_mapgen` or the mask's
  files (accepted, option a); options b–d (a raw water query, the snapshot in slices, a
  coarser lattice) stay open. The 65 chunks refused only by a capital ring are fully
  scanned (about 1.4 s). Quest kinds of zones outside the quota are not counted where a
  border cell reaches into a claim chunk (slivers only). The scan shortcut assumes the
  territory at the world top of a dry claim-zone column is its zone's rule; a later
  territory overlay there must keep that or extend `scan_problem`. The fingerprints sample
  one column in sixteen.
- **RESET:** in a hand-made world with overlapping v2 and v3 areas a container would be
  packed twice (never in practice: the reset clears v2 before any v3 exists); v2 and v3
  share one `MIN_Y`, pinned to `registry.lua`.
- **The platform:** 0.85.0 is an ordinary map reset; nothing new is asked of the host. The
  game writes `grug_claim_mask.txt` into the world folder at the first start of each map
  and rewrites it when the world's map-reset record changes, so the host need not delete
  it. Production (0.83.0) is upgraded only after Round 86; the final platform note is the
  coordinator's.
