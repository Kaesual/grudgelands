# Housing rework — concept

Drafted with the user on 2026-11-21, after Round 84. Status: **Part A built in Round 85
(0.85.0), its placement preview and Part B in Round 86 (0.86.0); Part C is concept and
stays open.** It holds the
rulings and measurements of that session so that three later pieces of work can be planned
from it:

- **Part A, grid claims:** built in Round 85 (the arena and a full map reset); the
  placement preview of §2.1 rule 5 moved to Round 86 (Round 85 ruling 23) and was built
  there ([Round 86 Completion](round86-plan.md#completion-2026-11-22)).
- **Part B, the account Claim Stone and home names:** built in Round 86, together with the
  Account page "The Charter" (§3.3 says where the build differs from §3.1). Part B needed
  no map reset of its own; 0.86.0 is one because of the round's road cuts.
- **Part C, the soft map reset:** built when the first soft reset is needed, not before.

What this file says is direction and rulings, not a brief; each part gets its round plan.
Today's rules are in [housing.md](../design/housing.md); it is authoritative, this file
only records the direction and the rulings.

## How to add to this document

- A ruling goes into its part with its date. A **proposal** is not a ruling until the user
  says so; open questions are listed at the end of each part.
- Numbers come from the study named beside them. Rerun the study before relying on a number
  after world generation changed.

## 1. Why

- Round 85 adds an arena at the map's centre. The user ruled a **full map reset including
  claims** for it, so the arena's placement needs no compromise. A reset that removes every
  claim is the moment to change what a claim is.
- Claims should **survive later map resets wherever possible**. The first attempt (Round
  77, discarded) failed because free-standing 101 × 101 claims overlap map chunks
  arbitrarily and because terrain changed under some of them.
- A claim must never spoil the game for others: no claim on a road, a settlement, a camp or
  a quest place, and quest mobs keep enough ground to spawn on.
- Players with several characters want one shared home.

## 2. Part A: grid claims (Round 85)

**Built in Round 85** as rulings 1–4 and 6 say, with the plan's rulings 14–16 and 20
([round85-plan.md](round85-plan.md) §2); [housing.md](../design/housing.md) §1–§2 holds the
rules as built. **Rule 5, the placement preview, built in Round 86** (moved there by
Round 85 ruling 23; [round86-plan.md](round86-plan.md) §4 PREVIEW and ruling 2): with the
stone in hand the minimap shows per chunk whether a stone can be placed there for the
chunk's own sake, recomputed at every placement and removal, and a line names the
reason for the chunk the player stands in (housing.md §2 "Placement preview"). As built,
the quota's red is per chunk, as placement decides it (Round 85 ruling 16): a chunk turns
red when its own share of a kind would take the claimed part above half, so a chunk with
a smaller share can stay free, rather than every remaining chunk of the kind at once.

### 2.1 Rulings (the user, 2026-11-21)

1. **A claim is exactly one map chunk in x and z: 80 × 80 nodes.** Chunk column
   `cx = floor((floor(x / 16) + 2) / 5)`, nodes `80·cx − 32 … 80·cx + 47`, the same in z
   (`chunksize = 5`). The vertical rule of today stays (from y = −100 upward).
2. **A chunk is claim ground as a whole or not at all.** It is not claim ground when it
   holds any of: ground outside the allowed zones (rule 3), the coastal belt, the sea or
   protected deep water; a settlement, village, camp or POI core or a hard footprint, or
   ground within 16 nodes of one (today's margin); **a road**; a camp's spawn region, a
   leader's spot, a quest place or a named rare's route point (the study's 16-node radius
   around points is a proposal).
3. **Allowed zones:** the claimant's faction's seven level 11–30 zones, as today, **and its
   three capital zones**. In a capital zone a claim chunk keeps **one full chunk of
   distance** to the capital's protected city shape (the inside of the wall line, the wall
   with gatehouses and the 21-node band, `wp40/capital_protection.lua`): no chunk that
   holds any column of that shape may be among its eight neighbours.
4. **Quest mobs keep half their ground: a quota at placement.** For every mob kind a quest
   names, at most half of the kind's spawn ground may lie in claims. A placement that would
   exceed the half is refused. Nothing is reserved in advance: players choose which half.
5. **The placement preview** stays as it is in principle: with the Claim Stone in hand the
   minimap shows where a claim may go, now as whole chunks. When a placement brings a mob
   kind to its limit, every remaining chunk of that kind's ground turns red. The overlay is
   recomputed at every placement and removal.
6. **About 280 claims per faction are enough for now** (the user), also because Part B lets
   an account share one.

### 2.2 What was measured

Study CLAIMCAP, 2026-11-21: the game's own claim check on every column of every chunk, the
production seed and ten others, no engine. Tools `tools/r85_claimcap/` (branch
`r85-claimcap` until merged); report, tables and pictures in the orchestration folder
`r85/reports/claimcap-report.md` and `r85/claimcap/`.

Production seed, The Accord / The Throng (the ten other seeds in brackets where measured):

| Rule | Accord | Throng |
|---|---|---|
| Today: 101 × 101, best packing found | 260 | 272 |
| Today: 101 × 101, placed freely (a simulation) | about 177 | about 187 |
| Grid, today's zone, water and settlement rules | 395 (345–427) | 420 (360–429) |
| … and no road in the chunk | 285 (236–324) | 313 (242–332) |
| … and no camp, leader, quest place, rare route point ("D2") | 260 (200–293) | 295 (226–306) |
| D2 plus the capital zones at one chunk from the city | 366 (285–406) | 373 (312–401) |

- **The grid does not cost claims, it costs area per claim** (6,400 nodes against 10,201).
- The capital rings are only two to three chunks wide: at two chunks of distance they add
  35 / 25 chunks under the strictest rule measured, at one chunk 82 / 61.
- The row "D2 plus the capital zones" is the fixed mask of rulings 2 and 3. **Under the
  quota of ruling 4** (follow-up 2; ground counted in node columns per zone and kind,
  unclaimable ground counting as free) 336 / 323 claims fit at once on production when
  players claim in a plausible order, 349 / 340 at most; the ten other seeds give
  272–383 / 302–357. The quota costs 2–8 % of the mask and empties no zone; 146 / 73 mask
  chunks touch no quest kind at all, and the capital rings are effectively not limited.
  Counting whole cells instead of columns costs about 30–50 claims per faction; reading the
  half as "half of the claimable ground" gives 260 / 230 in a plausible order.
- Fixed variants measured for comparison: keeping the largest region of each quest kind
  free gives 290 / 281 with the capital zones; keeping regions with half of each kind's
  ground free gives 150 / 134 in the seven zones alone.
- For the preview: about 22–24 quest kinds per faction, at most three per chunk, under
  1,000 (chunk, kind) pairs per world; a placement check is three additions (an estimate
  from the study's data).
- Building ground: almost no chunk is mostly water; the median height span inside a chunk
  is 36 / 29 nodes, above 40 nodes for 42 % / 28 % of chunks. No slope filter was applied.
- All seven zones of a faction hold eligible chunks on every seed; the smallest zone on a
  bad seed has five or six.
- Roads may cross a claim today (their corridor stays protected for everyone); excluding
  road chunks is a new rule and the largest single cut.
- The one gate in the code that keeps capital zones out today:
  `grug_housing/registry.lua` (`civic_no_hostiles` returning "capital_zone").

### 2.3 Why the strict mask also serves Part C

A chunk that is claim ground holds no road, settlement, camp or authored quest content. A
kept claim chunk therefore never contains content the game builds itself, which was an
open problem of the Round 77 attempt (authored actors and records inside kept blocks).

### 2.4 Settled in the Round 85 plan

The questions this section listed, each with its answer
([round85-plan.md](round85-plan.md) §2, §3.1):

- **The quota arithmetic:** the user's yes, as Round 85 ruling 16 (columns of the 32 × 32
  spawn cells, drafts and expired claims counted, half of the kind's ground). A refused
  placement names the kind's spawn area: "This claim square (80 x 80) would put more than
  half of <area> under claims; half of it stays free for the creatures quests send you
  after."
- **Slivers:** do not count (ruling 14): a chunk that is not wholly claim ground is none.
- **Steep chunks:** neither filtered nor marked (ruling 15).
- **The night kill quests outside the cities:** their kinds fall under the quota like every
  other quest-named kind of a zone that can hold claim ground; nothing special was built.
- **The migration:** every claim ended with the 0.85.0 reset (ruling 4, plan §3.1): the
  pre-reset pass packed the containers of the old 101 × 101 squares, carried stones stayed,
  nothing was converted.
- **The mask:** built from the world plan at every start (its column scans cached in the
  world folder), the running version's mask deciding new placements (ruling 20); its
  snapshot with the fingerprints is stored once per map (ruling 7, §4.4).
- **The 16-node radius round points** (rule 2) stands as the plan's coordinator default.

## 3. Part B: the account Claim Stone and home names (Round 86)

Replaces the direction of [accounts-concept.md](accounts-concept.md) §5.5. No map reset is
needed, nothing changes for a character that does not opt in, and linking a character is
never refused because of a stone. **Built in Round 86** (0.86.0) as the rulings below say,
with the differences of §3.3; [housing.md](../design/housing.md) §1a, §3a and §3b hold the
rules as built.

### 3.1 Rulings (the user, 2026-11-21)

1. **A choice per character at the Housing Steward:** a **personal** Claim Stone (as today)
   or the **account** Claim Stone. Every player sees both options with an explanation; a
   character without an account reads that it needs an account on grudgelands.com and a
   link. The choice exists from level 20, like the stone.
2. **One account Claim Stone per account and faction.**
3. **Only a character without an active stone may choose.** A character with a personal
   claim picks its stone up (or loses it) first.
4. **Rights:** every character that chose "account" has full owner rights on the account
   claim (pick up, fuel, permissions). Characters of the same account with a personal stone
   have none, unless the permission list names them.
5. **The item:** joining a standing account claim gives no item. Before the claim stands,
   every joining character gets an account stone; once one is activated, no second one can
   be activated, and it vanishes at the attempt.
6. **Leaving** is possible only at the Housing Steward, and not for the last member: the
   last member picks the stone up instead. So one character never holds two claims.
7. **Belongings:** a character's Claim Stone inventory (packed containers of a map reset)
   is added to the account stone's inventory when it joins, also when it is the first
   member. One way: leaving later does not take them back.
8. **Losing the link:** an unlinked character falls back to "personal, no stone"; the claim
   stays with the account. A deleted account ends its claims as `/claim_remove` does. **A
   claim also ends when no character is left that owns it.**
9. **Travel:** through the existing "Set as home", per character; with the level 20 of
   rule 1 nobody below 20 travels to a claim.
10. **No account-bound locked chests or doors.** Inside the claim ordinary chests are
    protected already.
11. **Home names, for every claim:** the owner may rename the home, at most **24
    characters**; the default is "<character>'s Home" with the character that placed the
    stone. Wherever a claim's name shows (the line under the minimap, the entry banner, the
    Map tab's location line; the map itself draws no claim names), a **house icon** stands
    in front of it, so a home is never mistaken for a place of the world. An admin command
    resets a name to the default.

### 3.2 Settled in the Round 86 plan

The questions this section listed, each with its answer
([round86-plan.md](round86-plan.md) §2, §3.1):

- **A name's characters:** ASCII letters, digits, space, apostrophe and hyphen, 1–24
  characters, no leading or trailing space; no word filter (ruling 8). **The protection
  hint** shows the home's name with the house icon, "<home name> – protected" (ruling 9).
- **The house icon** is an image element beside the HUD text, placed from the text's
  width estimated with the client font's glyph widths; the icon is the shipped cottage
  `grug_map_home.png` (ruling 19).
- **The placer who leaves or is deleted:** the default name is stored at placement, so it
  stays; the admin reset of an account claim's name uses the first member by name (plan
  §2.3).
- **Storage:** an account claim's owner is the text `account:<account id>:<faction>`,
  which no name can be; membership is the character's own record, `v2|member|<owner
  text>`; an account's belongings have keys of their own (plan §3.1, settled in the lane
  briefs).

### 3.3 Built differently from §3.1 (the user's rulings of 2026-11-22)

- **Ruling 5, the item:** every member gets an account stone while the claim does not
  stand and may place it as a draft, owned by the character that placed it; activating one
  removes every other draft of that account and faction at once, and a leftover stone
  vanishes when it is placed (Round 86 ruling 16).
- **Ruling 8, a claim with no owner left:** a deleted account or an unlinked last member
  ends the claim as `/claim_remove` does, its belongings staying stored for the account
  and faction (ruling 13); narrowed by ruling 18: when the last member goes **through the
  website's list** (an unlink, the account gone from it), the claim stands ownerless,
  protects while its fuel lasts, cannot be refuelled and then is the empty stone anyone
  may dig; a character of that account and faction may join it again. The deletion of
  the last member by command, an admin's faction change of it, its pick-up and
  `/claim_remove` end it at once.
- **Membership across a map reset:** it survives; members get a stone at the Steward
  (ruling 14).
- **Ruling 11, names:** "Your Home" is gone, the owner too reads the home's name with the
  icon (ruling 15); an account claim's default name is "<character>'s Home" of the
  character that placed the stone, and every member may rename it (ruling 12).
- **The stone itself:** the account stone is its own item, "Account Claim Stone", told
  apart at a glance (ruling 10); both stones got a new look, a small house in a node box
  (rulings 11, 19, 20), and only the fuelled stone gives light.

## 4. Part C: the soft map reset (future)

### 4.1 The idea (the user, 2026-11-21)

Two kinds of map reset:

- A **hard reset** when the terrain in the claim areas changes clearly: every claim goes.
  Round 85 is one.
- A **soft reset** keeps as many claims as possible, although a road may move, a POI may
  shift or a capital may change its shape.

The classification of chunks can be computed for a new version before the update, on the
existing seed, and compared with the running world's.

### 4.2 Proposed shape (the coordinator; agreed in direction, not yet rulings)

1. **Compare per chunk, not layouts as a whole.** Byte equality of the road, POI and
   capital layouts is global (one moved road fails everything) and misses terrain changes:
   0.70.0 changed terrain on 75 of 1944 claim-zone chunk columns of the production seed
   without any need for a layout change (orchestration `r77/mapcmp/README.md`). Instead
   every chunk gets a **fingerprint** of what decides its generation: terrain height, water,
   zone, roads, POIs, each including a border strip towards the neighbours. Computing all
   claim-ground chunks offline is affordable (the capacity study took about four minutes
   per seed, its raster about 81 s per faction); in the running game it is computed once
   and cached, not at every start.
2. **The game computes, the host only deletes.** The pre-reset pass that packs containers
   today (run with the new version while the server is stopped) also computes the new
   fingerprints and the new mask, compares them with those the running version stored in
   the world, decides per claim "stays" or "is cleared", and writes the list of chunk
   columns to keep. The host deletes every other map block. It needs neither the old game
   version nor any knowledge of masks. The interface drafted for Round 85's first idea
   (orchestration `r84/platform-message.md`, never sent as final) is close to this.
3. **One procedure.** A hard reset is the case in which no fingerprint matches; a switch
   "clear everything" stays as an emergency brake.
4. **A claim stays** when its chunk's fingerprint is unchanged and the chunk is still claim
   ground by the fixed mask (§2.1 rulings 2 and 3). **The quota never clears a claim:** if
   a kind's ground changed so that more than half is claimed, existing claims stay and new
   ones are refused.
5. **A dry run before the update** names the homes that will not survive, so their owners
   can be warned.

### 4.3 Risks and what must be checked before it is built

- **Seams at the chunk border.** A kept chunk has old terrain, its neighbours are
  regenerated. The border strip is in the fingerprint; a differing strip clears the claim,
  or a small step (a proposal: up to two nodes) is accepted.
- **Regenerating a neighbour may write into the kept chunk.** The engine generates a chunk
  with a shell of one map block, and the game's generation transaction might write there.
  **Not checked.** Settle it from the engine source and with a probe first.
- **The engine and the noise parameters.** The base terrain comes from the engine's v7
  generator with noise parameters the game overrides and pins (`wp40/r7_native.lua`,
  `NATIVE_DIGEST`); the game's own pass writes the surface on top
  ([mapgen notes](../technical/modules/mapgen.md)). The game's parameters and digest belong
  in the fingerprint. The engine version does not: an engine update is not expected to
  change v7's output, and most updates need no reset. Proposal: a small **canary** at every
  engine update, which generates a few fixed chunks headless and compares their height maps
  with stored ones; a difference means the update needs a hard reset. Optional, cheap.
- **Saved objects in kept blocks.** Mobs saved in a kept chunk stay as saved; actors that
  must never be saved are covered since Round 84
  ([upstream workarounds](../technical/upstream-workarounds.md) §11).
- **What the comparison does not prove:** it compares the game's world plan, not generated
  blocks. A rehearsal on a copy of the production map before the real reset stays
  necessary.

### 4.4 What Round 85 did for it

- Grid claims with the strict fixed mask (Part A), built.
- The mask and the per-chunk fingerprints are stored in the world folder (the user's ruling,
  2026-11-21), so a later pass needs no old game version: `grug_claim_mask.txt`, written at
  the first start of each map and never at a later one, its header naming the seed, the
  map-reset record, the game version, the world-layout key and the pinned noise digests;
  per claim-ground chunk five fingerprints (terrain height, water, zone, roads, places),
  each over the chunk and an 8-node strip round it
  ([format](../technical/claim-mask-format.md)). The claim record (v3) already carries
  Part B's two fields, stored empty.

Everything else of Part C waits for the first soft reset, when the real change it must
survive is known.
