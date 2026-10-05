# Round 35 — Fixes and character creation: round plan

Coordinator: Claude (Opus 5.5), planned 2026-10-05. Status: **approved by the
user (2026-10-05)**, with the upstream-workaround list (§2.10) added at the
user's request.

The user's first GUI test of Round 34 found a set of bugs and rough edges
(§2); four read-only investigations explained each of them (coordinator log,
`HANDOVER.md` "ROUND 34", 2026-10-05). This round fixes them, reworks the
music into a capital-only feature, puts every talent on a level-proof
footing, and builds the one-window character creation from the BACKLOG.
Routing as before: Claude orchestrates, Opus implements and reviews
(independent review per code lane). GPT-6 Astra has no task this round.

Starts after the user's Round 34 GUI test and push; WP9 follows as a round
of its own. Not in this round: the music tab (a study only, §4.5), a weather
system, seed-dependent POI placement (set aside by the user, BACKLOG).

## 1. Lanes and waves

| Lane | Wave | Kind | Content |
|---|---|---|---|
| **T** Targeting | 1 | code + doc | the server's combat ray tests rotated selection boxes itself (engine bug, §2.1); starts the upstream-workaround list (§2.10) |
| **F** Small fixes | 1 | code + one sound page | break sound, broken-weapon look, empty hand, ore and sand dig sounds, flint removed, quest dialog list and read-only text (§2.2–§2.4) |
| **E** Mobs and economy | 1 | code + data | night mobs leave at dawn; drop-table audit against the income targets, rat drops lowered (§2.5, §2.6) |
| **B** Talents | 1 | code, two phases | every flat "+N" talent becomes level-proof; a strong/weak review of all talents for the user's decision (§2.7) |
| **M** Music | 1 | code | music only in capitals, either music or the ambience bed, never both; quieter, short pauses; music tab effort study (§2.8) |
| **C** Character creation | 1 | code | faction, race, class and look in one window, nothing stored before "Create character" (§2.9) |
| **D** Documentation | 2 | docs | completion, GUI checklist, status files, design docs |

All six code lanes start together. Shared files (§7) decide the merge
order: T before F (both touch `grug_abilities/init.lua`), F before C (both
touch `grug_visuals`), B phase 1 reports before its phase 2 lands. D last.

## 2. User rulings (2026-10-05)

### 2.1 Fireballs stop on some mobs (engine bug)

Holding the left mouse button as a Mage stops casting at Braindead Zombies:
the crosshair turns white, no Fireball, no melee. Cause, verified by the
coordinator in the engine source and present in the user's Luanti 5.17.0
(since 5.12, upstream commit d74af2f1a): `UnitSAO::getTotalRotation()`
returns degrees, and the server raycast passes them to
`boxLineCollision(…, rotation_radians, …)`. For a mob facing beyond ±90°
the server tips a `rotate = true` selection box over, so our server-side
combat ray (`grug_core/combat_ray.lua`) misses the upper body of tall,
narrow boxes (zombies, skeletons, felines, hyenas, the crocodile sideways)
while the flat boar box almost always hits. The client is correct.
**Ruling:** our combat ray tests rotated boxes itself in Lua instead of
trusting the engine for them (cost reported, not gated; user, after
discussing the cost). The coordinator wrote the upstream bug report (with a headless repro on
5.17.0: 10 of 24 facings miss, all beyond ±90°) at
`/home/jan/Desktop/luanti-hitbox-issue.md`; the user files it.

### 2.2 Items and their display

1. **Break sound** when equipped gear breaks (weapon, bow, armour, offhand):
   none today (our `after_use` keeps the broken stack, so the engine's tool
   break sound never fires). One hook in `grug_repair` `wear_stack`; the file
   goes through the approval gate (a small page, candidates incl. the shipped
   `default_tool_breaks`).
2. **A broken weapon stays visible as broken** while a skill is in hand, with
   the break sound when it breaks. It is shown today with `[cracko`, which is
   barely visible on a thin 16×16 blade: make it clearly broken (for example
   darkened or desaturated plus the crack); first version by feel, the user
   iterates.
3. **No weapon in the weapon slot:** a skill selected on the hotbar shows the
   empty hand in first person, not the coloured skill orb (the engine falls
   back to the skill item's own `wield_image`). Third person is already empty.

### 2.3 Mining

1. **Ores, coal and gem ores** play the stone dig sound while being dug (today
   silent: they are dug through `grug_resource`, and the engine looks for a
   missing `default_dig_grug_resource`). **Sand** under a shovel plays the sand
   dig sound (silent for the same reason). Existing files, no listening page
   (user). Check every node dug by `grug_resource` or `grug_loose`.
2. **Flint is removed:** gravel drops only gravel; `default:flint` goes with
   its price row (it has no use; fresh-server mode, no alias).
3. **Not bugs** (answered, no change): Citrine near the surface is the T1 gem
   since Round 29 (y ≥ −100); the ore-free bands 8–11 (a secondary rock band,
   basalt in the undead lands), 18–21 (gravel) and 29–33 (dirt or clay) nodes
   below the surface stay.

### 2.4 Quest dialog

1. **Quest list too narrow** at quest givers (titles and "(available)" are
   cut off). A Luanti `textlist` cannot wrap, and two rows never highlight
   together. Ruling: widen the dialog and the list, show the status as the
   entry's colour instead of the "(available)" text (one colour per status,
   explained by a small legend or the tooltip), shorten "[Repeatable]";
   the quest log's list gets the same change.
2. **Quest text is editable:** the description `textarea` has a name; it
   becomes read-only (the only such field in the game).

### 2.5 Night mobs leave at dawn

Night-only mobs (for example the Large Grave Rats in Stillgrave Hollow) stay
through the day today: the clock only gates spawning. **Ruling:** at dawn
the free region mobs spawned for the night leave, **except a mob in combat
or near a player**; such a mob leaves as soon as neither holds. Underground
mobs (clock "any") are unaffected.

### 2.6 Drop tables against the income targets

The four start-zone drops at 7c are the T1 signature value by design (Round
29 raised it from 3c to 7c for the income targets); the outlier is the rat's
drop table (tail and fur 1/2 each, about 8c per kill against a band-1 target
of 3c). **Ruling:** lower the rat's drops and audit every mob's drop chances.
The yardstick is the defined income per hour (`economy.md` §3,
`tools/r29_e4/income.py`), whose loot part comes from each band's median
kill payout (`tools/r29_e1/band_payout.sh`, targets in
`economy-vendor-plan.md`). Where a fix would make an important item too rare
(a quest item, a recipe input, an achievement counter), the lane reports
instead of deciding.

### 2.7 Talents

Flat "+N" talents add before the level multiplier, so they fade: Tinder's
five ranks add +41 % to a Fireball at level 10 and +11 % at level 60. The
same holds for Strong Draw and Fine Edge (Scout), Sharpened Word, Warded
Wrath, Whitehot, the base numbers of Brand, Cinderfall, Rimebite and Word of
Ruin, and Ironbound's armour per rank. **Ruling:** every affected talent
becomes percentage-based (or level-scaled where a percentage does not fit,
for example armour), not only Tinder; the tooltip shows the value at the
player's level. Beyond that the lane reviews **all** talents for "too strong
/ too weak" and reports; the user decides with the coordinator what changes.

### 2.8 Music: a capital feature, either music or the bed

The music every few minutes breaks the user's immersion. **Ruling:**

- **Music plays only in the six capitals** (not in start towns, nowhere
  else). Entering a capital starts it, leaving ends it (a short fade, no hard
  cut). Each capital has its own rotation.
- **Either music or the ambience bed, never both — everywhere.** Where music
  plays the bed is silent; with music off (the player's switch) the capital's
  bed plays again. Outside capitals there is no music, so the beds play as
  today. The positional loops (forge, hearth, flowing water) and every effect
  are not affected; only the beds.
- **Quieter and continuous:** music volume defaults to 35 %; pauses between
  tracks about 5 s (plus a few seconds where a first download is needed — the
  next track may be pushed while the current one plays).
- Music stays switchable off completely (Help → Sound, `/music`).
- The Land, Front-and-sea and Underground pools are no longer played by
  default. Their tracks stay in the game for a possible music tab.
- **Music tab** (a personal playlist in the inventory, default off: tracks
  on/off, order up/down, volume, "play now"): nice to have, the user leans
  towards "not now". The lane estimates its effort; the user decides later.

### 2.9 Character creation in one window

As the BACKLOG entry "Character creation in one window" (user, 2026-10-05):
faction row at the top; a narrow race column on the left (no model before a
race is chosen); class buttons above the look area on the right; "Create
character" at the bottom right, active once faction, race and class are
chosen; the current choices highlighted, tooltips everywhere. Changing the
faction clears race and look (the class stays); changing the race rolls a new
random look. Mouse rotation on, auto-rotation off (the reset on each change
is accepted). No weapon in the preview. **Nothing is stored before "Create
character"**: a session-only draft, a disconnect starts over; the arrival
area loads after the click (a short wait in the dialog is fine, no prefetch);
a reconnect during that wait resumes it.

### 2.10 A list of upstream workarounds

Workarounds for engine problems that upstream will fix one day (like §2.1)
are easy to forget once the fix ships. **Ruling:** a small Markdown file in
the repository, `docs/technical/upstream-workarounds.md`, lists each of
them: the upstream problem (issue or PR link once filed, affected engine
versions), our workaround and where it lives in the code, how to tell
whether upstream fixed it (a test or a check), and what to remove then. It
is checked periodically — at every engine version change and at the start
of each round — and a workaround is removed once its fix is in the engine
version we require. Lane T creates the file with the rotated-box entry
(§2.1) and the existing pin `num_emerge_threads = 1` (`minetest.conf`,
Luanti #9357: ores and caves lost at chunk edges with more than one emerge
thread), plus any other engine workaround it finds marked in the code;
AGENTS.md gets one line pointing to it (lane D).

## 3. Shared conventions

- Fresh-server mode: no migrations, aliases or compatibility code.
- Numbers are comparisons, never targets (before/after on the same seed and
  method). If a change becomes clearly more complex or noticeably slower than
  planned, stop and report.
- Sounds only through the approval gate (Round 34 §1): only lane F's break
  sound needs a page this round; the dig sounds reuse shipped files by the
  user's ruling (§2.3).
- World generation is untouched this round. Should a lane touch it after
  all, `tools/seed_fleet/run.sh quick` runs before its merge (AGENTS.md).

## 4. Lanes (goals; the briefs add file facts)

### 4.1 T Targeting

- One shared helper for the server's combat ray: nodes stay the engine's
  raycast; objects whose selection box has `rotate = true` are tested in Lua
  (candidates from a narrow area along the ray, the box rotated by the
  object's `get_rotation()` in radians, merged with the other hits by
  distance). Every server-side aiming path uses it (`grug_core.combat_ray`,
  the hold-to-cast ray in `grug_abilities/input.lua`, the skill targets, the
  target frame); non-rotated boxes and players behave as before.
- `docs/technical/upstream-workarounds.md` (§2.10) with its first entries; the
  rotated-box entry names the helper and the fixture that would show the
  upstream fix (raycast a rotated box through the engine at every yaw).
- Fixture: a zombie and an elongated box (the crocodile) at yaws 0–345° in
  15° steps, rays at several heights and sides, all hit where the client box
  is; non-rotated boxes unchanged.
- Before/after cost of the ray with stand-ins (a busy fight, several
  players). One engine run that holds a cast on a zombie turning through all
  yaws.

### 4.2 F Small fixes

- Break sound (§2.2.1) with a German listening page of 2–4 candidates
  (approval gate); broken-weapon look (§2.2.2) and empty hand (§2.2.3), with
  the `SKIN_VERSION` bump the skin cache needs.
- Dig sounds for ores, coal, gem ores and sand (§2.3.1); flint removed
  (§2.3.2).
- Quest dialog and quest log (§2.4).
- Fixture cases for the dig sounds (every node dug by `grug_resource` or
  `grug_loose` has a `dig` sound), flint gone, the read-only description, the
  break hook.

### 4.3 E Mobs and economy

- Dawn departure (§2.5): night mobs carry their spawn clock already
  (`_grug_spawn_clock`); a cheap pass (spread over steps, no full object scan
  per step) removes them by day when not in combat and no player is within a
  "near" distance (propose one, about 24–32 nodes, and say why). Fixture for
  the rule; one engine run across a dawn.
- Drop audit (§2.6): per band the median kill payout before/after against
  its target, per family the payout per kill; lower the rat; fix other clear
  outliers by loot-table chances only. `tools/r29_e4/income.py --check` and
  `tools/r28_design/validate.py --game` stay green. Report every item that
  would become notably rarer, especially quest items, recipe inputs and
  achievement counters, before changing it.

### 4.4 B Talents (two phases)

- **Phase 1:** a percentage (or level-scaled) form for every flat talent of
  §2.7 with proposed values in a table (today vs proposed at levels 10, 30,
  60, per rank and at full ranks); the tooltip shows the value at the
  player's level. Plus a review of **all** talents across classes: too strong,
  too weak, dead picks, with numbers (the level-60 fit, the existing combat
  fixtures). The coordinator brings the report to the user.
- **Phase 2:** land the values and adjustments the user picks; update
  `skill_trees.md` and the class docs; fixtures.

### 4.5 M Music

- Capital-only music with one rotation per capital (§2.8): propose which
  shipped tracks each capital rotates (from the 16 tracks, by the capital's
  people; the user confirms in chat); start on entering, a short fade on
  leaving, a little hysteresis at the border so walking along it does not
  toggle; pauses about 5 s; the next track pushed during the current one where
  that hides the download.
- Either/or: in a capital with music on the bed is silent; music off (or a
  player who turned music off) gets the capital's bed back; loops unaffected.
- Default music volume 35 %; Help text and `/music` updated.
- **Music tab study** (no code): effort and risks of a personal playlist tab
  (track list with on/off and order, volume, "play now"; no seeking in the
  engine, a first play may wait for the download). One paragraph with a size
  estimate in the report.
- Fixture: scheduler (capital entry starts, exit stops, pause length, no
  pushes outside capitals or with music off), the either/or rule.

### 4.6 C Character creation

- §2.9 in full. The rewrite simplifies `grug_classes/selection.lua`'s step
  machine (no pending class, no per-step resume) and keeps creation stasis,
  Esc to pause and I to resume, the wait for world preparation at server
  start, the retry after a load failure, the dark backdrop.
- Layout checked at a small window size and in the web build (the user's GUI
  check); the old faction, race, class and look forms go (fresh server).
- Fixture for the draft rules (faction change clears race and look, race
  change rerolls, nothing stored before Create, a reconnect during the
  arrival wait resumes it); one engine boot through a creation.

### 4.7 D Documentation (wave 2)

Completion section here with numbers and the GUI checklist, BACKLOG (the
character-creation entry delivered, Round 35 carry-overs), ROADMAP, STATUS,
README, the design docs the lanes did not already update, AGENTS.md round
summary and a pointer to `docs/technical/upstream-workarounds.md` (§2.10).

## 5. Rules

As Round 34: AGENTS.md; `tools/check_lua.sh` (via bash) on every changed Lua
file; headless only through `LC_ALL=C chrt --idle 0 tools/luanti_headless.sh`,
never the user's Luanti folder; agents never push; no references to
commercial games; the factions are The Accord and The Throng.

## 6. Verification

Each code lane: its fixture and `tools/run_fixtures.sh`,
`python3 tools/check_fresh_server.py`, one smoke boot, an independent Opus
review. End: one boot of main, `tools/sync_to_luanti.sh`, the user's GUI
check (desktop and web build): a held Fireball on zombies at every facing;
gear breaking (sound and look); a skill with an empty weapon slot; digging
ores, coal, gems and sand; gravel without flint; the quest dialog and log;
night rats gone by day; start-zone loot over a few kills; talent tooltips;
capital music on entering and leaving, the bed with music off; the new
character creation including a disconnect.

## 7. Orchestration notes (for the coordinator)

- **Start state:** main after the user's Round 34 GUI test and push.
  Worktrees `.claude/worktrees/r35-<lane>` (`t`, `f`, `e`, `b`, `m`, `c`,
  `d`), `tools/bin/` copied; the Round 34 worktrees are removed first
  (never the sound download folders). Briefs in
  `~/projects/grudgelands-orchestration/r35/` from `r34/common-brief.md` and
  `r34/review-common.md`; log in `r28/HANDOVER.md` under "ROUND 35".
- **Round 34 state:** complete on main (local, not pushed when this plan was
  written); the user is still in the Round 34 GUI test (checklist in
  `round34-plan.md`, 23 points). Further findings from that test join lane F
  (or the lane they belong to). Remove the `r34-*` worktrees before the
  start.
- **Investigation facts** (2026-10-05, HANDOVER "Check A"–"Check D"; verify,
  they are hints):
  - Targeting: engine `src/server/unit_sao.h` `getTotalRotation()` (degrees)
    → `src/serverenvironment.cpp:1369` → `src/raycast.cpp` `boxLineCollision`
    (radians); ours: `grug_core/combat_ray.lua` (~182), the hold state machine
    `grug_abilities/input.lua` (combat hold ~472–483, `combat_hit` ~245–253,
    `ray()` ~57), `grug_abilities/init.lua` ~647, `target_frame.lua` ~155,
    `kits.lua` `aimed_target` ~54; crosshair colour `crosshair.lua`; zombie box
    `grug_mobs/zombie.lua` ~43–46, subtype scaling keeps `rotate`.
  - Break sound: `grug_repair/runtime.lua` `wear_stack` (~23–43, after
    `set_wear`), optional tool and hoe paths; broken look
    `grug_gear/permissions.lua` `broken_image` (~52), `grug_repair/
    presentation.lua` ~35–66.
  - Empty hand: `grug_abilities/init.lua` `apply_skin` writes `wield_image = ""`
    (~1714), so the engine falls back to the orb (~785–787); fix with meta
    `wield_image = "wieldhand.png"`, `wield_scale = "(1,1,2.5)"`, bump
    `SKIN_VERSION`.
  - Dig sounds: `default.node_sound_stone_defaults` has no `dig`
    (`BASE/default/functions.lua` ~16–24); `grug_materials/overrides.lua`
    `natural_resource()` (~15–36) and `ores.lua` (~34–43); use
    `dig = {name = "default_dig_cracky", gain = 0.5}` (and the sand
    equivalent). Flint: `BASE/default/nodes.lua` gravel drop (~605–613),
    `grug_traders/prices.lua` ~71.
  - Quest dialog: `grug_quests/npc.lua` textlist ~53, description textarea
    ~54, entry text ~27–29; quest log list `grug_quests/ui.lua` ~91.
  - Night mobs: clock checks `spawn_regions.lua` ~829/846,
    `spawn_policy.lua` ~443–499 (below y −40 the clock is "any", ~429);
    `remove_far_mobs = true` (`minetest.conf:71`) disables mobs_redo's
    lifetimer.
  - Drops: `grug_mobs/data/drops.json` (rat tail and fur 1/2 each);
    `grug_traders/price_rules.lua` (signature 7c at T1);
    `tools/r29_e1/band_payout.sh`, `tools/r29_e4/income.py`; band targets
    in `economy-vendor-plan.md`.
  - Talents: `grug_classes/talents.lua` (Tinder ~466–471, Whitehot ~492,
    Ironbound ~334, Sharpened Word ~659, Warded Wrath ~695),
    `scout_talents.lua` (Strong Draw ~13, Fine Edge ~75), fireball values
    `kits.lua` ~547–556, level scale `grug_core/combat.lua` ~138–152, talent
    tooltips `talents_ui.lua` ~75.
  - Music: `grug_ambience/data.lua` (`D.pools`, `town` pool D.1–D.7 + M2,
    gains, `town_bed`), scheduler in `rules.lua`, town flag via
    `grug_map/location.lua` `in_town` (capitals vs start towns: the
    resolver's `kind`).
  - Character creation: `grug_classes/selection.lua` (step machine, stasis,
    `start_arrival_load` ~367), `grug_factions/init.lua` faction form (~299),
    `grug_visuals/creation.lua` look form (~48–89).
- **Shared files:** `grug_abilities/init.lua` (T: ray; F: empty-hand skin;
  B: talent values in `kits.lua`/`talents.lua`), `grug_visuals` (F: broken
  look; C: creation), `grug_inventory/help.lua` (M: Sound text). Merge order T → F → C; M, E and B independent.
- **Freesound:** only lane F may search (break sound), through
  `r34/fs_run.sh`, previews only; the downloaded folders stay read-only.
- **Listening page:** lane F's break-sound page follows Round 34's pattern
  (German, data-URI audio, numbered, published privately by the coordinator;
  picks in `~/projects/grudgelands-orchestration/r35/approved/f.txt`).
