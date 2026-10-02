# Quests on the new world — plan draft for Round 29

Draft by the Round 28 coordinator (Claude Opus 5.5), 2026-10-02. Status:
**draft for discussion with the user**; open questions are marked **Q**.
It becomes part of the Round 29 plan ("Economy and travel",
`economy-vendor-plan.md` §10) together with the economy lanes, WP17 and
the mapgen bundle.

## 1. Why this is its own step

Round 28 rebuilt the world under the quests: data-driven sub-types and
loot, the XP curve `M(L) = 25 + 5L`, quests as per-zone JSON, and rule-based
spawn regions for all 38 zones with a border rule that makes levels meet
across zone borders. The 240 shipped quests are still the legacy ones,
mechanically split into the new format: their XP is oversized for the new
curve, they target base mobs (Round 28 appended the matching sub-types),
and 22 of them name targets the new recipes never spawn (accepted
`W-recipe-target` warnings). This step replaces them with quests written
for the new world.

**Why in Round 29 and not Round 28** (user, 2026-10-02): the quest lanes
are nearly pure data in `grug_quests/data` and run in parallel with the
economy (traders, prices), travel (mounts, boats, waypoints) and mapgen
lanes without touching their files. A short playtest of the new spawn
distribution with the legacy quests comes first, so density, region size or
camp problems surface before 300 quests sit on top.

## 2. What is ready on main

- Region kinds per zone (`data/zones/<zone>.spawns.json`), named, with level
  ranges per belt; camps and named leaders by rule; every kind/camp is a
  quest area (`<zone>/<kind>`), credited by the mob's area tag.
- `grug_mobs.spawn_regions.describe(zone, target, mode, ref)`: eight compass
  words, three modes — of a named place ("southeast of Highcourt"), from
  the giver ("southeast from here"), within the zone ("in the southeast of
  Dawnmere Fields"), with "near …" and "in the heart of …" cases.
- Final display names (signal words only in start zones), 195 sub-types,
  119 items; quest log shows each target's level range (Lane Q0).
- Load validation: roles/areas exist, level fit (targets within quest level
  ±3, containment), `W-recipe-target`; `tools/r28_regions/quest_targets.py`
  checks on three seeds that every kill target really forms a region.
- Design tools: `tools/r28_design/validate.py` and `ledger.py` (XP budget
  per route, solo and duo).
- Material: the Human route quests Astra wrote in Round 28 (branch
  `r28-c2`, not merged): Dawnmere 15, Goldmead 14, Highcourt 7, Whitebridge
  8 quests, six named leaders (Crumb, Hobb, Quill, Penn, Thorn, Murk). Its
  spawn areas are obsolete; its quests, texts and ledger are input.

## 3. Rules every quest lane follows

From the Round 28 design frame (§2, §2.4, §2.5, §4.7) and later user
decisions:

1. **Routes and budgets** (frame §2.1/§2.2, updated 2026-10-02): 1–10 start
   zone; 11–20 home zone; 20–30 own capital + own heartland ≈ 60–70 %, the
   rest from one sister zone of the player's choice (travel quests offer
   2–3 targets); **31–40 the faction's three contested zones, a player uses
   all three**; **41–50 The Broken Causeway and The Shattered Line**;
   **51–60 Gravesalt Escarpment and The Skyglass Canopy**; islands (60) are
   endgame, not leveling. Questing share and reward share per band as in
   frame §2.2; the ledger checks every route.
2. **Difficulty** (frame §2.4): the main route of every band is solo-able
   by every class; line climaxes in 1–30 are normal-tier named leaders, from
   31 an elite climax may be marked "Group" and the route still reaches its
   target without it.
3. **Limits** (frame §2.5): ≤ 2 givers per hub, ≤ 2 lines per giver, start
   towns: elder (hunt + tools lines), cook (pantry + kitchen lines);
   repeatables belong to a line, clearly labelled.
4. **Targets**: kill quests name the exact sub-type and its area (a region
   kind or camp); signal words only in start zones; leaders by role.
   Every target forms on every seed (`quest_targets.py` = 0 missing).
5. **Texts** (user, 2026-10-02): English, 2–4 sentences, the giver's race
   voice, light humour welcome; **no item tooltip texts** (item names only);
   **directions and places only as placeholders** filled per seed from the
   spawn regions and leader placement — never a fixed compass word; for
   kinds spread over many patches (open kinds) use the zone phrasing or a
   named place, "from here" only for compact targets (camps, leaders,
   shore strips).
6. **Islands**: flight is forbidden on both islands and their channels;
   island quests assume boat access (WP17, same round) and never promise
   flying.
7. **Money**: quest copper uses the economy cutover column
   `round_half_up(0.08 × P(T) × weight)`, P = 25 / 65 / 160 / 400 / 1,000 /
   2,500 (`economy-vendor-plan.md` §4).

## 4. Lanes

### Q1 Quest core (first, small; Opus)

- **Placeholders** in `title`/`text`: e.g. `{dir_from_giver:<kind|camp|leader>}`,
  `{dir_of:<place>:<target>}`, `{zone_area:<target>}`, `{place:<target>}`
  (the kind's display name) — exact syntax decided in the lane; filled per
  seed at load (or on display) through `spawn_regions.describe`; the offer
  dialogue, quest log and HUD show the filled text.
- **Validation** (game load + `validate.py`): every placeholder resolves;
  fixed compass words (`north`, `south-east`, …) in quest texts are an
  error; unknown places are errors.
- **Copper**: computed from `weight` and `level` by the cutover rule when a
  quest omits `rewards.copper` (recommended; **Q4**).
- Ledger update for the new routes (31–40 = three zones, 41–50 two, 51–60
  two).

### Q2–Q7 Race tracks (parallel; one lane per race)

Each lane replaces **all quest files of its race track in one change**
(the files of a track depend on each other through cross-zone `requires`):
start zone → home zone → capital outskirts → heartland(s), plus the travel
handoffs (start → home → capital → heartland, sister-zone offers, capital →
contested).

| Lane | Track (zones) |
|---|---|
| Q2 Human | Dawnmere Fields, Goldmead Vale, Highcourt, Whitebridge Shire |
| Q3 Dwarf | Hearthpine Vale, Copperfell Foothills, Dur Brannoc, Frostbarrow Shelf |
| Q4 Elf | Silverleaf Glades, Starbough Vale, Lethariel, Lorindor, Moonfall Wood |
| Q5 Undead | Stillgrave Hollow, Mournfen, Nhal Veyr, Ossuary Reach |
| Q6 Orc | Sunscar Flats, Redtusk Savanna, Gor Drazhak, Speargrass Reach |
| Q7 Troll | Kapok Cradle, Raincall Basin, Kezamba, Totemwater Reach, Whispering Reedlands |

Rough size, from the Human route Astra wrote in Round 28: start zone ~15,
home zone ~14, capital ~7, heartland ~8 quests (**Q1**: confirm or set
other targets; the ledger is the real measure).

### Q8 Contested 31–40 (two lanes, one per faction, or one; Opus)

Three contested zones per faction; outpost givers; the front line reserved
for Q9.

### Q9 Front and islands (Opus)

41–60 front quests in `<host>.front.quests.json` (31–40 outposts and
capitals as hosts), the 41–50 and 51–60 zones, repeatables/bounties
(41–60 questing ≈ 70 % incl. repeatables), island bounties (boat access).

### Who writes what (**Q2**)

Recommended split per track: **Opus** designs structure (lines, objectives,
areas, levels, weights, `requires`, ledger) and writes working texts;
**GPT-6 Astra** then rewrites titles and texts of the whole track in one
pass (texts only, same rules as §3.5; its brief lists the placeholder
syntax and forbids compass words and tooltip texts); Opus re-validates.
Alternative: Opus only (faster, flatter voice).

### Review (**Q3**)

Each lane gets the independent Opus review (structure, budgets, targets on
all seeds, placeholders, text rules). The user reads **a sample per track**
(recommended: the first five quests of the start zone and one full line in
the heartland) before the merge.

## 5. Order and dependencies in Round 29

1. Q1 first (small). Q2–Q9 start right after Q1 merges, in parallel
   (they touch only their own zone files).
2. Q9's island part waits for WP17's boat route to be decided (not merged).
3. The mapgen bundle (Battlegrounds +50 %, middle road) changes geometry,
   not kinds: quests reference kinds and placeholders, so they survive it;
   after the mapgen merge, re-run `quest_targets.py` and the world view on
   the new world.
4. Economy E3 (recompute copper) is unnecessary if Q1 computes copper from
   weight (**Q4**).

## 6. Open questions for the user

**Answered 2026-10-02:** the user accepted all six recommendations
(Q1 ≈ 15 / 14 / 7 / 8, Q2 Opus structure + Astra text pass, Q3 a sample
per track, Q4 copper from weight, Q5 one bounty line per hub where it fits,
Q6 reuse `r28-c2`). Scheduling: [round29-plan.md](round29-plan.md).

- **Q1** Quest counts per zone: take the Human sizes (≈ 15 / 14 / 7 / 8) as
  the rough target for every track, or different?
- **Q2** Texts: Opus structure + Astra text pass per track (recommended), or
  Opus only?
- **Q3** Your review: a sample per track (recommended) or more?
- **Q4** Copper computed automatically from weight when omitted
  (recommended), or written per quest?
- **Q5** Repeatables in 1–40: one bounty line per hub where it fits, or
  only in specific zones?
- **Q6** Reuse Astra's Round 28 Human quests as the basis of Q2 (re-checked
  against the new regions and rules), or start fresh?
