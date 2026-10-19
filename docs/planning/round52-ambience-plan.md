# Round 52, part A — ambience by biome and height

Coordinator: Claude (Opus 5.5), drafted 2026-10-19 in a read-only design
session while Round 51 runs. Status: **started** 2026-10-19 (the user's questions settled the same day; the user's "go").
**Frame plan:** [round52-plan.md](round52-plan.md) owns the lanes, waves,
shared files, the joint lane D and the release. Part B is the
[class rework foundation](round52-class-plan.md). Where this part names its
own D lane or a version, the frame plan wins.

Listening page (all picks, stored ratings, the height mixer):
https://claude.ai/artifact/BTuPPXa2Kk5zZ8TCBSApZN. Snapshot of its ratings:
`sound-r52/page-db-2026-10-19/`.

**In short:**
- Region beds follow the **biome** under the player, bundled into a few
  sound groups. Before, they followed the race zone.
- Three loops play at the same time: **surface**, **cave** and **wind**.
  Their levels follow the player's height **relative to the terrain**.
  - Digging down fades the surface out.
  - A real cave fades in the cave bed, quietly.
  - Towers and the flying mount fade in a soft wind.
  - On high peaks a quieter wind plays as well.
- The atmosphere's "underground" sky and fog also switch relative to the
  terrain instead of at y −20.
- Sparse **calls** (crows, hawks, owls, wolves) by sound group (§6.1).
- Release **compatible**: no map reset, no migration.

Routing (the user's last setting): Claude coordinates, Opus implements and
reviews.

## 0. For the coordinator who runs this round

The plan was written in a design session with the user. This section carries
what that session knew and the rest of the plan does not say.

**Where things are.**
- **Listening page:** https://claude.ai/artifact/BTuPPXa2Kk5zZ8TCBSApZN.
  - Its source is `sound-r52/page/` (`index.html` plus the clips in `a/`).
  - It stores ratings in its `db`: `verdicts/<id>` with `v` = keep / reuse /
    drop and a `note`, and the agreed height curve in `mixer/linear`.
  - Read them with the `ArtifactData` tool.
  - The 2026-10-19 snapshot is `sound-r52/page-db-2026-10-19/`.
- **Search material:** queries, results, previews, clips and the serial
  search, fetch and clip scripts are in `sound-r52/` (`queries.tsv`, `fs/`,
  `dl/`, `clips/`, `info.json`, `scripts/`).
- **Earlier downloads:** `r34/listen/dl/` and `r32/r2-evidence/dl/` are
  read-only sources. Copy from them, never move or delete.
  `r34/listen/dl/fs_214677.mp3` is an empty failed download; leave it.

**How the user listens.** These are standing preferences from the user's
memory, kept for this round.
- **Sound gate.** Nothing ships without the user's pick on a listening page.
  A new cut (trimmed, re-looped) needs a new pick. Silence is better than a
  bad sound.
- **What the user hears.**
  - The user notices hiss, rain, traffic, voices, microphone wind and
    animals that do not exist in the game. Pick sources without them.
  - Wind is tiring over time: keep it in the background.
- **Listening pages** are private Artifact pages **in German**, with
  numbered candidates, play buttons and stored keep/redo ratings. The
  coordinator reads the ratings back.
  - The page above is the template.
  - Clips are levelled like the shipped beds (−20 LUFS), so they compare
    fairly.
- **Freesound** is rate-limited. Use one serial lock
  (`r34/fs_run.sh <label> <command>`), HQ previews only, CC0 only, no GenAI
  tag.
- **Tuning.** Levels and pacing are tuned by ear in the user's GUI check.
  Swapping a file goes through a page again.
- **Language.** Chat with the user is German; repo docs are English.

**Before the start, after R51:**
- Check `SURFACE_ROWS` in `wp40/r7_r6_manifest.lua` against §2.
- If R51 added or renamed a biome, map it to the nearest group and say so in
  the start message. The user may overrule.
- Check that `terrain_height_at`, `water_query_at` and the coastal belt
  still behave as §3.2 steps 2–3 assume, because R51's TERRAIN lane changes
  the terrain.
- If they do not, adapt the depth helper in the AMB brief so the rulings'
  behaviour holds:
  - on the ground = 0;
  - swimmers count as on the surface;
  - towers count as up.

  Ask the user only if the behaviour itself would have to change.

## 1. The user's rulings (2026-10-19)

1. **Biome instead of zone.** The human beds suit every temperate forest,
   the elf and dwarf forests included. The orc bed suits the savanna and the
   troll bed suits the jungle.
2. **Battlegrounds** get a sound of their own, picked from new candidates.
   The gusts move to the wind at height.
3. **Dwarf crags: no wind.** If nothing fits, they stay silent.
4. **Wind on mountain peaks** above a certain height is fine, but not loud:
   wind is tiring over time.
5. **The atmosphere's underground switch** becomes relative to the terrain
   height.
6. **Cave or dug tunnel.** The cave bed ("Dark Dungeon") plays only in
   *real* caves, and quietly. In ordinary underground (a dug tunnel) there is
   no bed at all; the surface just fades out. The distinction is made by the
   amount of open air around the player.
7. **Height curve** (linear throughout, confirmed on the mixer):

   | Layer | Fade |
   |---|---|
   | surface, going down | 100 % at 0, 0 % at −15 |
   | surface, going up | 100 % up to +10, 0 % at +60 |
   | wind | 0 % at +30, full at +100, **full = 50 %** of the bed level |
   | cave | 0 % at −4, full at −16, **full = 40 %**, real caves only |

   Heights are in nodes relative to the reference of §3.2 step 2 (terrain,
   or the water surface over water). The levels are percentages of the
   normal bed level. Town halving and the player's volume apply on top.
   - The user's first note said +50 for the upper end.
   - In chat on 2026-10-19 the user changed it to "+10 to +60"; that value
     is final, and `mixer/linear` stores it.
8. **Cave probe cost.** The cave check runs in the same 2-s pass as the
   fire/water search. Adding air to that search would cost more (see §3.3),
   so it is a separate small sampled probe.
9. **Ratings on the page.**
   - **Dropped:** elf blackbirds, the graveyard wind, "Eerie Ambience" (the
     dark cave bed), the desert wind and the winter storm.
     - The last two have no page verdict.
     - Their drop comes from the user's note: of all winds, only "Windy Day
       (gusts)" is good, and the rest does not appear in the archived
       `notes/general.json`.
   - **Reused:** "Windy Day (gusts)" becomes the wind at height.
   - **Kept:** everything else in section 1 of the page except "Dark
     Forest" (`underground_creepy`, rated "reuse": "maybe swamp, but there
     are probably better sounds"), which §2 drops because the swamp has its
     frogs.

## 2. Sound groups and beds

Plain names are existing bed files (`grug_ambience_<name>.ogg`). "n_" /
"c_" entries are page ids that get new files and keys (target names below,
sources in §4).

**Target file names** (SND writes them, AMB names them; existing files keep
their names, even where the old mood prefix is historical):

| Source | File |
|---|---|
| n_164272 | `grug_ambience_battlegrounds_fields.ogg` |
| n_393693 | `grug_ambience_crags_mountain.ogg` |
| n_733782 | `grug_ambience_crags_birds.ogg` |
| n_855953 | `grug_ambience_crags_birds_clear.ogg` |
| n_352597 | `grug_ambience_badlands_quiet.ogg` |
| c_or3 | `grug_ambience_badlands_crickets.ogg` |
| c_un4 | `grug_ambience_swamp_frogs.ogg` |
| n_325501 | `grug_ambience_swamp_evening.ogg` |
| n_516157 | `grug_ambience_night_tropical.ogg` (jungle and swamp) |
| n_450537 | `grug_ambience_jungle_night_crickets.ogg` |
| n_635951 | `grug_ambience_jungle_night_hills.ogg` |
| n_871624 | `grug_ambience_jungle_night_rainforest.ogg` |
| n_328293 | `grug_ambience_night_insects.ogg` |
| c_ni4 | `grug_ambience_night_owl_crickets.ogg` |
| c_dw2 | `grug_ambience_snow_afternoon.ogg` |
| crows, hawks, owls, wolves | `grug_ambience_call_<crow\|hawk\|owl\|wolf>.<1\|2>.ogg`. Thunder style: the engine picks the variant, and the r34 fixture accepts `.<n>.ogg`. |

| Group | Biomes | Day | Night |
|---|---|---|---|
| temperate | meadows, deep_forest, elf_forest, pine_hills | human_meadow, elf_forest | night_forest, night_crickets, c_ni4, n_328293 |
| savanna | savanna | orc_steppe | night_crickets |
| jungle | deep_jungle, jungle_fringe, jungle_edge | troll_jungle, elf_birdsong | n_450537, n_516157, n_635951, n_871624 |
| badlands | badlands, badlands_east | n_352597, c_or3 | c_or3 |
| swamp | swamp | c_un4 | c_un4, n_325501, n_516157 |
| crags | crags | n_393693, n_733782, n_855953 | silence (§6.2) |
| snowy crags | crags_snowy | c_dw2 | c_dw2 (§6.2) |
| blight | blight, bone_forest | undead_lake | undead_lake |
| beach | beach | sea_waves | sea_waves |

**Precedence:**
- **Zone overrides** come before the biome:
  - battlegrounds: n_164272, day and night;
  - dragon islands: as today, with thunder;
  - open ocean: as today. Over the ocean and the dragon channels the depth
    reference is sea level, so the flying mount still gets wind there
    *(coordinator)*.
- **Unchanged:** sea or stream water near the player, underwater, music in
  the capitals, half gain in towns.
- **Several files in one slot:** one is picked at random each time the bed
  starts, as today.

**Layers:**
- wind: `battlegrounds_gusts` (the page's "Windy Day (gusts)", reused);
- cave: `underground_dungeon`;
- deep cave below y −500: `underground_crystal`, as today;
- `underground_creepy` and `underground_dark` leave the cave pool.

**Dropped files** leave the repo and `LICENSE-media.md`:
- `elf_blackbirds`, `undead_graveyard`, `underground_dark`, `orc_wind`,
  `dwarf_storm`;
- `underground_creepy`: rated "reuse": "maybe swamp, but there are
  probably better sounds"; the swamp now has its frogs.

## 3. Lanes

| Lane | Wave | Model | Owns | Depends on |
|---|---|---|---|---|
| SND | 1 | Opus | staged audio under `tools/r52_snd/` (not shipped), its listening page | the picks (§4) |
| AMB | 1, final step after the user's SND approval | Opus | `grug_ambience/` (data, rules, init, `sounds/`), `grug_core/atmosphere_zones.lua` (including the depth helper), `tools/r34_s2/approved.txt`, `LICENSE-media.md`, the fixtures in §3.2 step 10 | SND's approved files |
| D | last (frame plan) | Opus | docs, version, release files for both parts (frame plan §5) | every lane merged |

**One governing approved list:** `tools/r34_s2/approved.txt`. SND does not
create a second one. AMB is the only lane that changes it, and the only lane
that adds or removes shipped `.ogg` files. That keeps `data.lua`, the files
and the list in step: `tools/r34_s2/portable_test.lua:46-55, 598-623` fails
whenever a named file is missing or a shipped file is unlisted.

### 3.1 SND — asset preparation (wave 1, Opus)

**Goal:** loop-clean beds and trimmed calls from the picks, on the shipped
conventions (R34 plan §3):
- mono Ogg, about 30 s, 2-s loop crossfade, 60 Hz high-pass;
- beds at −20 LUFS, calls peaking at −3 dBFS;
- one `LICENSE-media.md` row each, with the licence verified on the source
  page;
- no GenAI tag.

**Sources:**
- `sound-r52/dl/` and `r34/listen/dl/` (copy, never move).
- No new Freesound access is needed. If any is, it goes serially through
  `r34/fs_run.sh`.

**Cutting:**
- Pick the excerpt by measurement. A loudness scan over the source picks a
  window without bursts (voices, single loud calls, handling noise), near
  the page clip where possible.
- n_733782 and n_855953 are only about 36 s long. Their loop uses nearly the
  whole file.

**The page.**
- The cut is new, so it needs a new approval (sound gate).
- The lane builds one listening page: each final loop plays twice in a row,
  so the seam is audible, and each call plays once. The page carries
  numbered keep/redo ratings.
- A redo is one more cut on the same page.

**Out:**
- the final `.ogg` files with their target names, staged under
  `tools/r52_snd/out/` (not in `mods/`, so nothing ships before approval);
- the generator script;
- a `picks.md` listing the approved names;
- the licence rows ready to paste.

AMB moves the approved files into the mod.

### 3.2 AMB — biome groups, layers, cave probe, relative underground (wave 1, Opus)

**Goal:** the behaviour of §1 and §2. Files: `grug_ambience/` (data, rules,
init) and `grug_core/atmosphere_zones.lua`.

1. **Biome groups.**
   - At most one `grug_zones.biome_at(x, z)` per pass, served from the
     column memo of step 11, gives the group (biome →
     group table in `data.lua`). The real ids carry the `grug_` prefix
     (`grug_meadows` …). Key the table by the full id, or strip the prefix
     the way `spawn_regions_core.lua:682-687` does.
   - `biome_at` returns nil only for ownerless columns (deep ocean, dragon
     channels); there the ocean override applies as today. Coastal-shelf and
     lake columns return the land biome.
   - Zone overrides by mood stay (battlegrounds, dragon island, ocean).
   - Moving between biomes of one group changes nothing. Between groups the
     existing two-pass hysteresis and the 3-s crossfade apply.
2. **Depth helper.** One shared helper, `grug_core.depth_below_surface(pos)`,
   defined in `atmosphere_zones.lua`. That file already resolves the zone
   authority, so no new file and no `init.lua` change are needed:
   - `depth = reference(x, z) − pos.y` through the installed zone authority.
     `terrain_height_at` is already block-cached in `height.lua` (warm call
     < 1 µs); step 11's per-player column memo sits on top of it. It follows settlement grading,
     roads and shores; buildings and towers do not count, which is what the
     rulings want.
   - **Water columns.** Over coastal shelf, lakes and rivers,
     `terrain_height_at` is the *bed*, so a swimmer or a boat would count as
     high above the ground. R51 widens the owned coastal belt to 250–350
     nodes, which makes this matter. The reference is therefore the higher
     of terrain and water surface.
     - Use R51's public `water_query_at(x, z)` (`zone_authority.lua`
       `PUBLIC_METHODS`; `wp40/zones.lua:1333`). It returns a water depth
       for wet columns, so surface = terrain + depth. No change to the
       authority or to `grug_mapgen` is needed.
     - Do **not** add a method to `PUBLIC_METHODS`: the install check
       (`zone_authority.lua:158-166`) fails if the zones session lacks it,
       and that session lives in `grug_mapgen`.
     - The extra call runs only when the column is wet: check
       `water_class_at` first, or use `water_query_at` alone if it is
       cheap; the lane measures.
   - The helper returns nil before the authority exists. Over the ocean and
     the dragon channels (no owner) the reference is sea level (y 1); the
     ocean mood itself behaves as today.
   - Both the atmosphere and the ambience use it.
3. **Atmosphere.**
   - `mood_key_at` (`atmosphere_zones.lua:466`) switches to "underground"
     when the player is more than 20 nodes below the reference. This
     replaces the absolute `UNDERGROUND_Y = -20` (:407).
   - **Hysteresis band:** in at depth > 20, out at depth < 16. Today the
     absolute y can only flip on vertical movement. A relative depth would
     flip sky and fog every pass along a level tunnel under rolling ground,
     and each flip sends a full `set_atmosphere` (:520-535).
   - The ocean rule (no zone id → ocean at every depth) stays.
   - Nothing outside `grug_ambience` reads the "underground" mood. The mobs'
     "underground" is a separate absolute rule (`spawn_policy.lua`) and stays.
   - The cost comment in `mood_key_at` (:472-479) is updated.
4. **Three layers.**
   - The bed state becomes up to three handles:
     - surface (the group bed);
     - cave (only while the cave probe says "cave");
     - wind (the rising curve, plus the peak wind).
   - Each pass sets each layer's target level from §1.7 and fades to it
     with `core.sound_fade` over about 2 s (one pass), subject to the dead
     band and the 0.01 floor of step 11.
   - Each layer tracks its last gain, because `fade()` (`init.lua:132-135`)
     computes the step from it.
   - **Fading to 0 deletes the sound**
     (`reference_projects/luanti/doc/lua_api.md:7583-7591`), so the
     handle is dead once that fade is issued. It is issued only after 3
     passes at the floor (step 11). If the layer rises again after that, it
     starts a new handle with a fade-in. Never re-fade a handle and start a
     new one in the same pass.
   - Underwater and music keep their current overrides for all layers. Where
     music plays there is no bed, no wind and no cave. Town halving applies
     to every layer.
   - **The deep crystal bed** (§6.6): below y −500 the cave
     layer plays `underground_crystal` instead of `underground_dungeon`. It
     follows the same cave probe and the 40 % cap. A dug tunnel below −500 is
     silent like any other dug tunnel. Today it plays in any underground
     below −500 at full gain (`rules.lua:69-71`).
5. **Peak wind.**
   - The wind layer is the higher of two values: the relative curve, and a
     peak term that fades in above an absolute y and is capped at **25 %**
     (§6.4; ruling 4: "not loud").
   - The lane measures the height of the world's highest peaks (snowy crags,
     pine hills) and sets the start about 15 nodes below typical peak tops.
     It reports the numbers.
   - The peak wind plays on crag peaks too. Ruling 3 ("crags: no wind") is
     about the crags *bed*; ruling 4 allows wind on peaks (§6.7).
   - The peak term applies only on or above the surface (depth ≤ 4). In a
     tunnel inside a high mountain there is no wind.
6. **Cave probe.**
   - It runs only when depth > 4.
   - It samples open air (air or another walkable-through, non-liquid node)
     on a sparse grid around the player, e.g. 5 × 3 × 5 points with a
     2-node stride (75 `get_node_raw` reads, no allocation). An unloaded
     node counts as solid.
   - A share of open air above a threshold means "cave". The threshold is
     calibrated in the engine on:
     - a natural v7 cave;
     - a 1 × 2 dug tunnel;
     - a 3 × 3 dug corridor;
     - a large dug hall (counts as a cave; that is accepted).
   - Hysteresis of two passes, like the beds.
   - The lane measures this probe against a small `find_nodes_in_area`
     (9 × 5 × 9, counts only) and keeps the cheaper one. It reports both
     numbers.
   - **Fallback:** if calibration cannot separate narrow natural v7 tunnels
     from a 3 × 3 dug corridor, narrow natural tunnels count as tunnels
     (silent). The lane reports it; no extra detection.
7. **Emitters underground.** Today fire and water loops stop whenever the
   mood is underground (`init.lua:452`). They now stop only underwater, so a
   burning furnace in a mine is heard. The 25 × 11 × 25 search then also
   runs on underground passes, and cave water gains loops. Both show up in
   the before/after numbers.
8. **Calls by group** *(the user: yes, §6.1)*. Call rows in `D.calls` take
   sound keys instead of moods: biome groups *and* the zone-override keys
   (battlegrounds, dragon_island).
   - crows: day, battlegrounds and blight;
   - hawk/falcon: day, crags and badlands;
   - owls: night, temperate;
   - wolves: night, crags and pine_hills (needs a sub-group, or "temperate
     at night above y X"). The lane proposes the cheaper one and the
     coordinator decides; the user hears the result in the GUI check;
   - thunder stays on the dragon islands;
   - the gap stays at 90–240 s per player.
   - **Animal calls play only while the surface layer is at ≥ 50 %.** No
     hawks in a mine, no wolves on a tower. Thunder keeps its current rule.
   - Animal calls are placed 24–40 nodes from the player (thunder keeps
     40–56).
   - The gain is tuned in the GUI check *(coordinator)*.
9. **Debug readout.** `/ambience debug` toggles a one-line HUD element (top
   left, small) for the player who types it. No privilege is needed: it only
   shows that player's own state: biome, group, depth, cave share and the
   three layer levels. It is needed to calibrate step 6 and for the user's
   GUI check.
   - `R.parse_command` (`rules.lua:38-46`) gains the word `debug`. Today it
     is rejected as a bad word (`init.lua:586-587`, tested at
     `tools/r34_s2/portable_test.lua:271`).
10. **Fixtures.**
    - **New:** `tools/r52_amb/portable_test.lua`, on the pure rules:
      - group lookup;
      - the layer curves at the ruling points (−15, +10, +60, +30, +100,
        −4, −16);
      - the cave share → state with hysteresis;
      - the atmosphere band (in 20, out 16);
      - the fade dead band, the 0.01 floor with stop after 3 passes, and the
        column memo (same column → no query);
      - call eligibility by sound key and time.
    - **Existing ones that load the real `init.lua` on fake runtimes** with
      no `grug_zones` and a stubbed `get_atmosphere`. Each needs a stub for
      the biome and depth calls:
      - `tools/r34_s2/portable_test.lua`: its runtime part (:455-483)
        drives beds by mood and expects `dwarf_storm`, so it is rewritten,
        not just adapted;
      - `tools/r35_m/portable_test.lua` (:402-408): it also counts beds as
        loops without a position (:434), and that changes with three layers;
      - `tools/r47_fs/portable_test.lua` (:120-127);
      - `tools/r451_mu/portable_test.lua` (:231-243).
    - These four are AMB's standing fixture selection.
11. **Performance design** *(coordinator, 2026-10-19)*.
    - **One column memo per player, shared.**
      - The atmosphere driver and the ambience run their own 8-slot
        schedulers, each once per player every 2 s
        (`atmosphere_zones.lua` ~:510-560). Both would query depth.
      - The depth helper therefore keeps, per player, the last column
        (`floor(x)`, `floor(z)`) with its biome, group and reference height
        (terrain or water surface). It recomputes only when the column
        changes.
      - A player standing, building or mining in place then costs no zone
        query at all. Two modules asking in the same column cost one.
      - Only `pos.y` changes the depth, and that is free.
    - **Dead band for fades.** A layer's `sound_fade` is sent only when its
      target differs from the last sent level by ≥ 0.03 (3 % of the bed
      level), or when the target reaches 0 (then it fades to the 0.01
     floor). Slow climbing or hovering on the mount
      then sends no fade every pass.
    - **No start/stop churn at the thresholds.**
      - A layer whose target falls to 0 fades to a floor of 0.01 and keeps
        its handle.
      - It is stopped (faded to 0, which deletes the sound) only after 3
        passes at 0.
      - A layer starts only when its target reaches ≥ 0.03.
      - Hovering around +30 (wind) or −4 (cave) thus does not restart loops
        every 2 s; each start is a new sound and a send to the client.
    - **Cave probe reuse.** The probe runs only when depth > 4, and only
      again when the player moved ≥ 2 nodes since the last probe or 3
      passes have gone by. Otherwise it reuses its last share.
    - **Debug HUD.** Updated only while switched on and only when a shown
      value changed.
    - **All new work stays inside the existing slot schedulers.** No new
      globalstep, no per-player timers.
12. **Performance numbers.** Before and after numbers from the module's own
    stats (`stats.us`, `stats.find_us` per pass), plus the share of passes
    served by the column memo, on the same seed and walk: surface, mine,
    tower, a fast flight on the mount. Reported, no target.
    - The fire/water search now also runs underground (step 7). Its cost in
      a busy mine is reported separately.
    - If it is clearly higher than on the surface, the coordinator brings
      the numbers to the user; the lane does not shrink the box on its own.
    - Fast flight crosses new `terrain_height_at` blocks (cold call about
      0.18 ms). The 48-block FIFO cache is shared with mob spawning; report
      cold-call counts during the flight.

**Order inside AMB.**
1. The code, the rules and the fixtures are built and reviewed against the
   shipped files while SND runs. `data.lua` keeps naming only shipped files.
   The new groups temporarily point at existing beds, or have none.
2. After the user approves SND's page, a final step does the following:
   - moves the approved files in;
   - deletes the dropped ones;
   - updates `data.lua`, `tools/r34_s2/approved.txt` and
     `LICENSE-media.md` together;
   - reruns the fixture selection.

   This step is a data delta and gets its own short review.

### 3.3 Why the cave probe is not part of the fire/water search

That search is `find_nodes_in_area` over 25 × 11 × 25 nodes with
`grouped = true`. It returns a position table for every match. Adding `air`
would return up to ~6,800 positions per player per pass on the surface. The
sampled probe reads 75 nodes and allocates nothing. Both run in the same
evaluation step, which is what the user asked for.

### 3.4 D — docs and release (the joint lane of the frame plan)

The frame plan's lane D covers both parts. For the ambience it does, as in
round-workflow §4:
- **Version:** set by the frame plan (0.52.0, compatible, no step).
- **Docs:** the ambience model (groups, layers, depth reference, cave probe,
  atmosphere band, debug command) in the module guide, plus the AGENTS.md
  pointer.
- **Planning files:** STATUS, ROADMAP/BACKLOG (the parked items of §4),
  README/CHANGELOG where they name sounds.
- **This plan:** the completion section with the GUI checklist.
- `LICENSE-media.md` is checked against the shipped files.

## 4. Sources of the picks

Page id | title | author | Freesound id | length | page clip start (s).
Paths: `sound-r52/dl/fs_<id>.mp3` (n_) and `r34/listen/dl/fs_<id>.mp3`
(c_). All CC0 1.0 (re-verify per file).

| Id | Title | Author | Freesound | Length | Clip start |
|---|---|---|---|---|---|
| n_164272 | Dark Ambience - Abandoned Fields | Dredile | 164272 | 103 s | 25.9 |
| n_393693 | Nature ambience Cyprus Troodos Mountains | gladkiy | 393693 | 781 s | 195.2 |
| n_733782 | Ambient Summer Field French Mountain Birds | Salomé_Lubczanski | 733782 | 36 s | 2.9 |
| n_855953 | 03 - Birds_stereo | Nordliecht | 855953 | 37 s | 3.5 |
| n_352597 | quietdesert birdcall-response | drewhalasz | 352597 | 213 s | 53.1 |
| n_325501 | King's Hut Late Evening | kangaroovindaloo | 325501 | 797 s | 199.3 |
| n_450537 | Amazon jungle night crickets loop | kyles | 450537 | 229 s | 57.3 |
| n_328293 | Forest at night, Sian Ka'an | felix.blume | 328293 | 301 s | 75.2 |
| n_516157 | Tropical Ambience Night Ecuador | pmoss2 | 516157 | 77 s | 19.2 |
| n_635951 | Jungle Night over Soufriere, St Lucia | el_boss | 635951 | 1194 s | 298.4 |
| n_871624 | Night at Nouragues science campsite | Clément_Baudet | 871624 | 513 s | 128.4 |
| c_or3 | wind light desert day steady eerie with crickets | kyles | 454361 | 119 s | 29.7 |
| c_dw2 | Appalachian Snowy Afternoon 2 | lakewoodsound | 719852 | 122 s | 30.5 |
| c_un4 | Lily pads and frogs at night | Danjocross | 503206 | — | 28.0 |
| c_ni4 | Crickets and tawny owl | raoul_slayer | 203598 | — | 35.1 |
| c_ca_crow1 / crow2 | crow / Crows_02 | nigelcoop / Q.K. | 75162 / 56234 | 4–5 s | 0 |
| c_ca_hawk1 / hawk2 | eagle wings and cry / falcon cry | stackpool / Framing_Noise | 39338 / 319619 | 5–6 s | 0 |
| c_ca_owl1 / owl2 | owl / owl | Breviceps / Anthousai | 465697 / 398734 | 4 s | 0 |
| c_ca_wolf1 / wolf2 | wolf howl with echo / distant howl | taure / sandboks | 380156 / 503516 | 8 s | 7.0 / 0 |

**Parked:**
- **Crows, long recordings** (n_214869, n_386768, n_353432; "reuse"):
  sources for more crow calls if two variants are too few.
- **n_236954** (birds near Szczawnica): "good, keep, no place yet".
- **c_bg3** (crackling fire): for large fires later, and an idea for the
  mage's fire rain in the class rework.
  - Lane D adds a BACKLOG line with the source (Freesound 182369, kingsrow,
    CC0; `r34/listen/dl/fs_182369.mp3`).
  - The coordinator adds a note on the class redesign board
    (https://claude.ai/artifact/G2wFpJVxhLq46htZwcogXR, its `notes` store).
- **c_bg1** (soft tonal wind): maybe a badlands night, but too short and too
  monotonous as a loop.

## 5. Rules and gates

- **Sound gate:** nothing ships that the user has not approved on a page as
  the final cut (SND page). A missing or unapproved file stays silent.
- **Gates** (round workflow §3):
  - `check_lua` on changed Lua, `check_fresh_server`;
  - the lane fixtures plus `tools/r34_s2/portable_test.lua`; the full
    `run_fixtures.sh` once per lane;
  - a smoke boot;
  - the upgrade classification is *compatible*;
  - an independent review of AMB, and of any SND fix that changes code.
- **Round end on main:**
  - `check_fresh_server`, `check_upgrade` and the full `run_fixtures.sh`;
  - one boot of main;
  - `sync_to_luanti`;
  - then the user's GUI check.
- **No seed fleet.** Nothing in world generation changes.
- **Headless runs** follow `tools/luanti_headless.sh` (isolation, LC_ALL=C).
  The cave calibration happens in a headless world where possible, and
  otherwise in one guided GUI session with the user. A few short engine runs
  at most.
- **Terrain guard:** not touched (no node changes).

## 5a. Orchestration notes

- **Start state:**
  - main after the R51 merge and its release (0.51.0, map reset), so the
    biome list includes R51's changes;
  - the plan is committed to `docs/planning/` before the worktrees are
    created.
- **Shared files:**
  - `grug_core/atmosphere_zones.lua`: AMB only; `zone_authority.lua` is
    read-only, no lane edits it;
  - `tools/r34_s2/approved.txt`: AMB only.
  - SND touches nothing under `mods/`.
- **Merge order:** AMB code (after review), then AMB's file step once SND is
  approved, then D.
- **Launch:** every brief carries the fixture sentence from the lane-start
  checklist (`LANE-START-CHECKLIST.md`) and quotes the rulings of §1 in
  full.
- **Notes only, no fix rounds:**
  - A forced `/atmosphere underground` preset no longer drives the beds
    (`init.lua:44-47`). The debug readout replaces it for checks.
  - With the atmosphere layer disabled there are no zone overrides; the
    biome groups still play.

## 6. Questions settled (the user, 2026-10-19: all seven "yes")

1. **Calls in this round,** mapped as in §3.2 step 8.
2. **Crags** are silent at night. **Snowy crags** play "Snowy Afternoon" day
   and night.
3. **The short sources** n_733782 and n_855953 stay in the random pool with
   Troodos. They are dropped if the loop shows in the GUI check.
4. **Peak wind:** capped at 25 %, starting about 15 nodes below typical
   peak tops. It is tuned in the GUI check.
5. **Stale page entries** were deleted on 2026-10-19. The archive stays in
   `page-db-2026-10-19/`.
6. **The deep crystal bed** plays only in real caves, at 40 %, like the
   dungeon bed.
7. **Peak wind on crag peaks too:** ruling 4 wins over ruling 3 on peaks.

## 7. GUI checklist

1. Walk meadow → forest → elf forest → pine hills: one continuous bed, no
   switch.
2. Savanna, jungle, badlands, swamp, crags, snowy crags, blight, beach: each
   group's bed, day and night (`/time`).
3. A battleground: "Abandoned Fields"; crows now and then.
4. Dig straight down: the bed fades out by −15, then silence in the shaft.
5. Break into a natural cave: the quiet dungeon bed fades in. Back into the
   dug tunnel: it fades out.
6. Build or fly up: the bed fades from +10 to +60, the wind from +30, still
   in the background at +100.
7. Stand on a high snowy peak: a light wind under the bed.
8. Sky and fog: underground only when more than 20 below the terrain, also
   in the mountains. Walking a long level tunnel does not make them flicker.
9. Swim or take a boat on the coast and on a lake: the bed stays, no wind.
10. A burning furnace in a mine is audible.
11. Capital with music on: no bed and no wind; music off: half-gain bed.
12. `/ambience debug` shows biome, group, depth, cave share and levels.
