# Round 32 — Fixes, preparation and research: round plan

Coordinator: Claude (Opus 5.5), 2026-10-03. Status: **complete locally
2026-10-03** ([completion and GUI checklist](#completion-2026-10-03));
approved by the user 2026-10-03 ("go"). The in-round rulings (one LMB state
machine, the personal notices in the feed, lane F4) are in the completion
section; where they differ from §2, they win.

A small round between the content rounds: the first findings of the user's
Round 30/31 playtest, and three read-only studies that prepare the next large
rounds (performance before a big multi-player playtest, sound for V1, items
and professions). Routing as before: Claude orchestrates, Opus implements and
reviews (independent review per code lane), GPT-6 Astra only texts and art on
request.

Not in this round: seed-dependent POI placement (the user, 2026-10-03:
optional, set aside), WP9 (moves to Round 33 or later).

## 1. Lanes

| Lane | Kind | Content |
|---|---|---|
| **F1** Map and HUD | code | minimap zoom ×2, hostile-camp map symbol, coloured zone names with the territory line (§2.1–2.3) |
| **F2** Combat input and quest labels | code | LMB hold: gather → combat switch (§2.4); quest kill labels use the zone's mob name (§2.5) |
| **F3** Playtest fixes | code | further small findings from the user's playtest, as they come (one lane, batched) |
| **R1** Performance review | read-only | measured against the October review, focus Round 30/31 additions and 50/100-player scale (§3.1) |
| **R2** Sound research | read-only | inventory, gaps, licence-compatible sources, calm background music (§3.2) |
| **R3** Items and professions analysis | read-only | the loop across all tiers, open parts, proposals and questions for a design session (§3.3) |
| **D** Documentation | docs | completion, BACKLOG/ROADMAP/STATUS (sound into V1, placement set aside) |

F1, F2, R1, R2 and R3 start together; F3 when findings arrive; D last.
Contact point: F1 and F2 touch no common file (F1: `grug_map`, the zone
banner, minimap; F2: `grug_abilities/input.lua`, `grug_quests/labels.lua`,
`tools/r28_design/validate.py`).

## 2. Fixes (user rulings, 2026-10-03)

### 2.1 Minimap zoom
Twice the zoom (`minimap_view.lua` `WINDOW_NODES` 880 → 440): markers of
quest givers and trainers sit twice as far apart, so players can locate them.
The base map stays (tiles, download and cache unchanged); at `normal` quality
each base pixel is drawn larger. Adjust the cell size only if the bezel edge
needs it. Report texture size and per-player data rate before/after.

### 2.2 Hostile camps on the map
Bandit and other hostile camps get their own map symbol and colour instead of
"!", which reads as an available quest.

### 2.3 Zone names: colour and territory line
- **Territory status** at the player's position, depth included: friendly
  (own peaceful land above y −501), contested (contested zones, and every
  column at y ≤ −501), enemy (enemy land above y −501).
- **Colour** by status, on the large centred banner and the zone line under
  the minimap: **green** friendly, **yellow** contested, **red** enemy. Both
  banner lines in the same colour; the line under the minimap follows the
  status continuously.
- The large banner (name at 2.5×) gets a second centred line in normal text
  size that replaces Round 31's PvP subtitle: "Friendly Territory",
  "Contested Territory (PvP)", "Enemy Territory (PvP)". **No level range**
  (user: underground it would only confuse).
- **Trigger:** the banner shows whenever the zone **or** the territory status
  changes. So crossing y −501 under friendly or enemy land (through caves or
  shafts too) shows the same zone name again with the changed line and
  colour; crossing it in a contested zone shows nothing; a zone change always
  shows.
- Under the minimap: the zone name as today, only coloured.

### 2.4 LMB hold: gather may become combat (supersedes Round 28 ruling 14's lock)

*As planned; the rule as built (one state machine, the threat and skill
gates, the flee release) is in the [completion](#rulings-made-during-the-round)
and `classes.md` §2b.*
Within one continuous LMB hold:
- Gather mode switches to combat as soon as a valid hostile is in the
  crosshair **and** in reach; only in this direction.
- In combat mode the hit always goes to the hostile currently in the
  crosshair and in reach (switching between enemies is free).
- Gather is allowed again only when the last targeted hostile has died (a
  despawned or unloaded one counts as dead — coordinator proposal); targeting
  another hostile during the same hold locks it again until that one dies.
- Releasing LMB or a skill/slot change resets everything.

### 2.5 Quest kill labels
Kill and drop objectives name the mob exactly as the player sees it in that
zone (the zone's display name, e.g. "Small Jungle Boar"), not the generic
role name; 30 quests and 4 item objectives are affected today. A validator
rule keeps it so.

## 3. Studies (read-only; each delivers a report, no code)

### 3.1 Performance review (R1)
Reuse the October review (`docs/research/perf-review-2026-10.md`) and its
probes (`~/projects/grudgelands-orchestration/r29/perf-evidence/`). Measure
the same baselines again, then everything new since: the PvP location tick
and combat gate, garrisons and respawn slots, the dragon arena tick and
hazards, look and enchant composition and its caches, per-viewer map lists,
quest markers, Round 30's caches. Scale: 50 and 100 fake players across start
zones, a capital and a fortress. Deliverable: a prioritized finding list with
measured numbers and proposed fixes (numbers are comparisons, no targets).

### 3.2 Sound research (R2)
- Inventory: which sounds the game plays today and where (mods, events).
- Gaps: talking to NPCs, crafting, level-up, abilities and hits, UI, mounts,
  footsteps, ambience per biome, water, weather.
- Sources that fit the project's licences (CC0, CC BY, CC BY-SA, as
  `LICENSE-media.md` allows): sites, packs, quality, attribution duty.
- Background music: calm, no automatic switch in combat; candidates and how
  it would play (per region or a playlist, volume setting).
- A short listening page (private artifact) with examples, and an effort
  estimate for an implementation round.

### 3.3 Items and professions analysis (R3)
The user wants the system to feel rewarding and make sense across all tiers.
Analyse the loop as it is (loot, vendors, crafting, enchanting, repair, gems,
mob drops) per tier; where it lacks reward or sense; the open parts (item
level scaling affixes, cultural and PvP finishes, masterwork at item level
70, helper services, drops without a use: 67 of 94 signature drops have no
recipe, Emberglass Shard, Cut Citrine, Feather); and proposals with questions
for a design session with the user. Deliverable: a proposal document.

## 4. Rules
As Round 31 (§4 there): AGENTS.md; `tools/check_lua.sh`; headless only
through `LC_ALL=C tools/luanti_headless.sh` under `chrt --idle 0`, never the
user's Luanti folder; numbers are comparisons; fresh-server mode; agents never
push; the user pushes.

## 5. Verification
F1/F2/F3: fixtures (`tools/run_fixtures.sh`), one engine boot each, an
independent review. Studies: the coordinator reads and summarizes them for
the user. End: sync and the user's GUI check of the fixes.

## 6. Orchestration notes (for the coordinator)

- **Start state:** main `2b87c15f` or later (local; Rounds 30 and 31 not
  pushed, both GUI tests running). Worktrees `.claude/worktrees/r32-<lane>`
  on branch `r32-<lane>`, `tools/bin/` copied into each.
- **Briefs** in `~/projects/grudgelands-orchestration/r32/`: start from
  `r31/common-brief.md` and `r31/review-common.md` (update round, base
  commit, plan path; keep every rule, including "no commercial-game
  references"); copy `r31/engine_run.sh` with its lock path changed. Log in
  `~/projects/grudgelands-orchestration/r28/HANDOVER.md` under "ROUND 32".
  Read-only lanes (R1–R3) get a read-only brief: no commits to game code,
  reports and pages in the orchestration folder, the coordinator publishes
  pages as private artifacts.
- **Code facts gathered before the round** (verify, they are hints):
  - Minimap zoom: one constant `V.WINDOW_NODES = 880` in
    `grug_map/minimap_view.lua` (~24); cell size `GRID`, `COVER`, `REDUCE`,
    `BEZEL_HOLE` nearby. Base map tiles (512 px PNG, `base.lua`) and their
    cache key do not depend on the zoom.
  - Hostile camp "!": `grug_map/page.lua` ~102 (`bandit_camp` → kind
    `hostile`) and ~250–255 (symbols and colours; "!" is also the quest
    giver's "available" symbol).
  - Zone banner and subtitle: `grug_map/location.lua`, `location_view.lua`,
    `grug_core/hud_layout.lua` (Round 31 lane P2); the zone line under the
    minimap in `grug_map/minimap.lua`/`minimap_view.lua`; territory status
    from `grug_pvp.state`/`pvp_rule_at`/`faction_at` (`CONTESTED_DEPTH_Y`
    in `grug_mapgen/wp40/zones.lua`).
  - LMB hold: `grug_abilities/input.lua` — `decide_mode` (~204–220), mode
    set once at ~434–438, `end_mode`/`reset`/`cancel`, `combat_hit`
    (~222–227) re-casts the crosshair ray each 0.05 s step, `M.can_dig`
    refuses digging in combat mode; rule text `docs/design/classes.md`
    ~187–205 (Round 28 ruling 14, "Mode lock") — F2 rewrites it.
  - Quest labels: `grug_quests/labels.lua` `mob_label`/`objective_subject`
    (~11–39) use the entity's generic `description`; the zone name lives in
    `grug_mobs/subtypes.lua` `display_by_zone` (`apply_zone_variant`
    ~181–204); `Q.placeholder_target` (~186) already does the zone lookup
    for leaders. 30 quests and 4 item objectives in 13 zones are affected;
    `tools/r28_design/validate.py` `kill_objective` (~1112) is where a rule
    fits.
  - Performance baseline: `docs/research/perf-review-2026-10.md`; probes and
    evidence in `~/projects/grudgelands-orchestration/r29/perf-evidence/`
    (helpers A mobs/pathing, B combat/UI with fake players, C scheduled code
    and memory, D regions and boot) and `r30/p1-evidence/`; Round 31 lane
    probes under `tools/r31_*`.
  - Items and professions (for R3): the data/loot integration is done (Round
    28/29 recipe updates; no recipe needs an unobtainable item); 67 of 94
    signature drops have no recipe use (34 used nowhere but traders);
    Emberglass Shard, Cut Citrine and Feather have no consumer; band-3
    outliers and band 6 at 0.80; none of the WP5/WP10 features (cultural and
    PvP finishes, masterwork ilvl 70, helper services, affix scaling by item
    level) exists in code; BACKLOG "Enchantment and item-level revision".
  - Underground mob level: `mob_level_at` = max(surface level, depth level),
    depth level continuous (≈ 3 levels per 50 nodes: −100 ≈ 6, −500 ≈ 30,
    ≤ −992 = 60) — why the banner shows no level range.
- **Merge order:** F1 and F2 independent; F3 after them; D last. Every code
  lane gets an independent Opus review; findings are hypotheses until
  verified.
- **End:** `tools/run_fixtures.sh` on main, sync with
  `tools/sync_to_luanti.sh`, the user's GUI check; the user pushes.

## Completion (2026-10-03)

Every code lane below is merged on local main (last lane F4, `2f709fbc`);
not pushed. Each was independently reviewed by Opus: F1 once, F2 once and
twice more after its reworks (the last small commit `ed102631` checked by
the coordinator), F3's first two passes (the third checked by the
coordinator), F4 once. The coordinator ran the portable fixtures after each
merge (`tools/run_fixtures.sh`, 66 of 66 on `2f709fbc`), a smoke boot of
main (150 s, no ERROR line) and synced the game to the user's client. The
round changes no mapgen, so the Round 31 fresh world serves its GUI test.
The three studies are in `docs/research/`.

### Shipped, by lane

Numbers are each lane's own probe before and after, same seed and area
(comparisons, never targets).

- **F1 map and HUD** (merge `716d9f2a`, design in
  [world_map.md](../design/world_map.md) and [pvp.md](../design/pvp.md)):
  - **Minimap zoom ×2:** `WINDOW_NODES` 880 → 440; the cell grid goes from 6
    to 2 base pixels at normal quality and from 16 to 8 at high, so the
    bezel still covers the overhang; the base map, its tiles and their
    download are unchanged. A normal cell texture is 144² → 72² px, a high
    one 240² → 120² px. The bezel at normal now steps in about 40 px:
    1080p 265 → 239 px, 768p 186 → 159, 1440p 345 → 358 (it fills 0.79–0.99
    of its box by window size, 0.88–0.98 before); high keeps 265 px at
    1080p. Engine probe `tools/r32_f1/engine.sh` (one stand-in leaving
    Dawnmere, 30 s per speed), minimap data per player: walking
    0.23 → 0.39 KB/s, sprinting 0.29 → 0.31, riding 0.23 → 0.21, flying
    0.15 → 0.31 KB/s; new cell textures 0.17–0.40 → 0.47–1.23 per second.
  - **Hostile camps** on the Map tab: a red "X" instead of the quest giver's
    gold "!", by anchor slot (`bandit_N`, `mirefolk`;
    `settlement_icons.lua` `HOSTILE`). The old kind key had missed the six
    frontier bandit camps and the four Mirefolk camps.
  - **Territory line and colours:** `grug_pvp.territory_at` (the location
    flag's own rule, `R.territory` in `rules.lua`) gives friendly, contested
    or enemy from the position, never from the flag. The banner's second
    line ("Friendly Territory", "Contested Territory (PvP)", "Enemy
    Territory (PvP)", no level range) replaces Round 31's PvP subtitle; the
    banner and the line under the minimap are green, yellow or red; the
    banner shows on a zone or a status change, so crossing y −501 under
    friendly or enemy land shows it again, under contested land nothing.
    The flag-change resample hook is gone. The location sample costs
    34.7 → 53.9 µs per player and second (two more zone queries).
- **F2 combat input and quest labels** (merge `cb53ad7c`, rule text
  [classes.md](../design/classes.md#left-click-and-held-input) §2b and
  [quests.md](../design/quests.md)):
  - **One LMB hold state machine** in `grug_abilities/input.lua` (gather
    or combat locked on a foe `s.foe`; only the start differs), built in
    three steps by the rulings below: a gather hold switches to combat on a
    hostile combat accepts in the crosshair and reach while an attacking
    skill is selected; combat returns to gather when the foe is gone
    (dead, despawned, unloaded, no longer a valid target, evading, or
    farther than `FLEE_REACH` = 2 × the reach); self and support skills
    fire only on a fresh press. A held gather step costs nothing on a solid
    node or air, one combat ray behind a plant, loot or an actor.
  - **Quest kill labels** name the mob as its zone shows it ("Small Jungle
    Boar" in the Kapok Cradle), resolved once at load from a leader's zone,
    else the objective area's, else the quest's: 30 quests in 13 zones
    changed; the 4 item objectives already named their source correctly.
    `validate.py` gains `E-label-name` and `E-item-source-drop`. Tracker
    lines longer than 38 characters (cut with "...") 83 → 89 of 424.
- **F3 playtest fixes** (three passes; merges `0f1a007c`, `c548b022`):
  - Pass 1: the feed kind `combat` (grey) for "You dodge!" and "Dismount
    before attacking."; the quest log's description, objectives and rewards
    in one scrolling text field (text height 3.19 → 4.6 units) without a
    hard wrap, "Track on HUD" left and Abandon right in one row, the
    confirmation taking the row alone.
  - Passes 2 and 3: the personal notices move from chat to the message
    feed, one keyed line per group (`potion`, `food`, `weapon_hint`,
    `mount`, `talents`, `boss_loot`, `equip:<reason>`, `class_change:*`,
    `starter:<slot>`): potion and food refusals, the raw-weapon hint (one
    short line), mount notices (dismount reason, flight-boundary warning,
    summon refusal, "That mount is not bound to this character."), talent
    points, the boss-loot notice ("free main inventory space, then
    rejoin"), equip refusals (the two-handed ones shortened to one line),
    the class-change unequip lines and the starter-weapon line
    ([inventory_equipment.md](../design/inventory_equipment.md) "Message
    feed").
- **F4 performance fixes** (merge `2f709fbc`; added during the round from
  R1's findings R1–R3, the user's approval): the Map tab poll runs every
  0.1 s and reads at most 8 signatures and builds at most 2 forms per pass,
  longest-waiting first; the party HUD polls in five 0.1 s slots, skips
  players without a party (`grug_parties.in_party`) and lays out only on a
  window change; the spawner serves camps and leaders in 20 zone slices of
  0.25 s, each zone once per 5 s. Probe: R1's scale probe, crowd scenario,
  seed 12345, 100 stand-ins: the Map tab's largest step 34.5 → 13.4 ms, the
  party HUD's 16.2 → 4.3 ms, the leader tick's all-zone sweep gone (one
  leader placement of up to 12 ms remains); all Lua per step p99 42.5 →
  37.6 ms, maximum 68.5 → 64.3 ms, 81.0 → 70.9 ms/s. The Map tab now keeps
  a true 2.0 s cadence (rounding had made it about 2.5 s), so an open tab
  sends about 20 % more (2.62 → 3.15 KB/s per player in the probe).
- **R1 performance review** (read-only,
  [perf-review-2026-10-r32.md](../research/perf-review-2026-10-r32.md)):
  the October baselines improved (40 stand-ins 111 → 36 ms/s); 50
  stand-ins 40–74 ms/s of Lua, 100 → 65–121 ms/s; spikes from all-player
  passes (fixed by F4); 2.9–3.3 GB process memory after the first mapgen
  (the emerge thread's mapgen environment, 630–745 MiB live); 13.8 MB of
  media per first join. Findings R1–R5 before a 50-player playtest, R6–R13
  later.
- **R2 sound research** (read-only,
  [sound-research-2026-10.md](../research/sound-research-2026-10.md), and
  a private listening page with 62 clips): 94 sound files today
  (1.35 MB), about 30 silent events with one central hook each, licence-clean
  sources for everything but voiced NPC greetings, calm CC BY music, no
  music channel in Luanti (a per-player gain through `core.sound_fade`);
  two lanes (S1 effects, S2 ambience and music), about 150–210 files.
- **R3 items and professions analysis** (read-only,
  [items-professions-analysis-2026-10.md](../research/items-professions-analysis-2026-10.md),
  and a private summary page): no quest gives gear; trinkets, spellbooks and
  bags above 8 slots only through a profession, with no way to pay another
  player; three primaries craft nothing but enchants; 67 of 94 signatures
  without a recipe use; enchant stats far apart in value. Options 1–5 and
  16 questions for a design session.
- **D:** this section, the three studies under `docs/research/`, the status
  files, the module guide and AGENTS.

### Rulings made during the round

1. **Plan (approval):** sound is part of V1; items and professions get an
   analysis, then a design session; seed-dependent POI placement is set
   aside; WP9 moves to a later round.
2. **Territory line:** it follows the position's territory, not the flag's
   reason; a player flagged by the button in own land still reads
   "Friendly Territory".
3. **LMB hold, one machine:** a hold that begins on a hostile behaves like
   one that switched; every hold starts as gather, a key-down on a valid
   hostile enters the same combat state at once.
4. **Neutral mobs and critters switch a gather hold too** (the user,
   reversing the coordinator's first ruling); a player switches it only
   when both are flagged (`grug_pvp.can_harm`). The switch needs an
   attacking skill selected (coordinator).
5. **Self and support skills never fire from a hold on their own:** always
   a fresh press at the right target. A priest gathering does not heal an
   ally who walks into the crosshair; a self skill pressed at a hostile
   casts once per press, the held press strikes; the one repeat is a
   support cast a fresh press began on an ally, on that same ally.
6. **Gone:** dead, despawned or unloaded; no longer a valid target (a
   dropped PvP flag, an evading mob; coordinator); or fled farther than
   `FLEE_REACH` = 2 × the combat reach (coordinator proposal, tunable; the
   user's "flee" meant the evading mob, which is covered). The same foe
   back in the crosshair and reach locks again.
7. **Chat → feed:** combat notices (F3 pass 1); the user's groups 1–6
   (potion and food refusals, weapon hints, mount notices, talent points,
   boss loot) to the feed, 7–9 (boss and dragon broadcasts, deaths, rare
   sightings) stay in chat; then also the equip refusals, the class-change
   notices and "not bound", the boss-loot wording and a one-line raw-weapon
   hint. The one-time no-weapon hint (about 170 characters) stays in chat
   (coordinator: unreadable in the feed's 2.5 s).
8. **Map arrow** stays at 2 s (R1's 4 s option declined).
9. **F4 approved in-round** (Map tab rebuild budget, party HUD slots,
   leader and camp slices; behaviour unchanged).
10. **No real-client performance test now;** perhaps at the end of the next
    round.

### Open items

In the [BACKLOG](../../BACKLOG.md#round-32-carry-overs): the minimap bezel
size at normal quality and the high-quality detail (`REDUCE.high` stays 2)
for the GUI test; F1's location sample could reuse `grug_pvp`'s zone
queries; standing exactly at y −501 can flicker the banner (the rule
itself); F4's fixture gaps (the scroll-quiet check, the `slot_of` clean-up),
the Map tab interval stretching beyond about 40 viewers whose maps change at
once (about N/20 s), `page.lua` 2.4 → 4.2 ms/s at 50 stand-ins in one run
and R3's gain not visible at 100 in one run; R1's later list R6–R13
(re-measure input and crosshair, R6, and the minimap glide, R7, after F1
and F2), `remote_media` and at least 4 GB RAM for a playtest server, the
mapgen-environment memory investigation; `tools/r29_e4/income.py --check`
failing on main since Round 31's quest data; the sound round's seven open
decisions; the items design session's 16 questions and R3's side findings;
the real-client performance test. Proposed next (coordinator, awaiting the
user): Round 33 with the sound lanes S1 and S2 (after the seven answers),
items options 1 and 2 (after the design session) and a small fix lane;
WP9 in a round of its own after it.

### GUI playtest checklist

One Flatpak client (two for the PvP cases) on the Round 31 fresh world or a
new one; helpers `/xp give`, `/teleport`, `/pvpstate` (privilege
`server`). Round 32 changes no mapgen.

Map and HUD (F1):

1. **Minimap zoom:** quest givers and trainers in a start town sit twice as
   far apart as before and can be told apart; walking, riding and flying
   glide without jumps at cell swaps.
2. **Minimap size at normal quality** (`grug_map_quality` normal, the
   default): the bezel is about 10 % smaller at 1080p (239 px instead of
   265) and changes in steps of about 40 px between window sizes; say
   whether that is fine. At high quality the size is unchanged; note
   whether the map looks coarser than before.
3. **Hostile camps:** on the Map tab every bandit camp of the start zones
   **and of the frontier** and every **Mirefolk camp** shows a red "X";
   quest givers keep the gold "!", other places the "+".
4. **Banner colours:** walking from own land into a contested zone and into
   enemy land shows the zone name with "Friendly Territory" (green),
   "Contested Territory (PvP)" (yellow) and "Enemy Territory (PvP)" (red);
   the zone line under the minimap takes the same colour at once.
5. **Depth:** under own land go down past y −501 (a shaft, a cave or
   `/teleport` to y −495 and then −510): the same zone name shows again,
   yellow, "Contested Territory (PvP)"; coming back up shows it green
   again. Under enemy land: red → yellow. In a contested zone crossing
   y −501 shows nothing.
6. **Button flag:** press "Flag me for PvP" in own land: the banner and the
   minimap line stay green "Friendly Territory" (the PvP icon shows the
   flag).

LMB hold (F2), with an attacking skill (Strike) selected unless noted:

7. **Mine, a mob walks in:** hold LMB on stone; an aggressive mob steps
   into the crosshair within reach: the hold attacks it and digs nothing
   while it lives.
8. **Neutral mob or critter:** the same with a neutral animal or a critter
   walking into the crosshair: the hold switches to combat as well.
9. **Players:** an enemy player walking in switches the hold only when
   both are flagged; an unflagged enemy, an ally or an NPC never does.
10. **Self and support skills:** with Glacial Ward, Blink or Heal
    selected, holding on a node never fires the skill when a mob or player
    walks in (the hold keeps gathering); the skill fires only on a fresh
    press.
11. **Priest:** a healing priest mining while an ally walks into the
    crosshair: no heal. A fresh press on the ally heals and keeps healing
    that ally while held, not another one walking in.
12. **Foe gone:** keep holding while the foe dies, flees about two reaches
    away or resets (runs home): the hold mines again; the same foe coming
    back into the crosshair and reach is attacked again.
13. **Quest kill names:** in a start zone and one later zone, kill
    objectives in the quest dialogue, the log, the tracker and the feed
    use the name the mob shows there (for example "Small Jungle Boar" in
    the Kapok Cradle), not a generic one.

Feed and quest window (F3):

14. **Combat notices:** "You dodge!" and, when attacking while mounted,
    "Dismount before attacking." appear grey in the feed above the bars,
    not in chat.
15. **Personal notices in the feed:** a potion at full health, food or a
    potion above your level, equipping a weapon above your level or a
    two-handed weapon with an offhand worn, summoning a mount where it is
    refused, a talent point at an even level: each is one feed line,
    repeated presses refresh it rather than stacking. **Still in chat:**
    deaths, rare sightings, dragon arena and boss return warnings and the
    one-time no-weapon hint.
16. **Quest window:** description, objectives and rewards in one scrolling
    text field; "Track on HUD" on the left and Abandon on the right in one
    row; after Abandon, "Confirm abandon" and Cancel take the row alone,
    also in a small window (1280 × 720 or a large GUI scale).

Performance fixes (F4):

17. **Map tab and party HUD look unchanged:** with the Map tab open, your
    arrow and party markers still move about every 2 s; zoom and marker
    clicks answer at once; the party health bars update as before.
