# Round 32 — Fixes, preparation and research: round plan

Coordinator: Claude (Opus 5.5), 2026-10-03. Status: **draft for the user's
approval.**

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
