# Round 35 — Fixes and character creation: round plan

Coordinator: Claude (Opus 5.5), planned 2026-10-05. Status: **complete
locally 2026-10-05** ([completion and GUI checklist](#completion-2026-10-05));
approved by the user 2026-10-05, with the upstream-workaround list (§2.10)
added at the user's request. The user's choices during the round
([completion](#the-users-choices-during-the-round)) win over the earlier
sections; the design as built is in `docs/design/`.

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
while the flat boar box almost always hits. Every yaw but 0 is misread:
elongated boxes (the crocodile) also miss at yaws inside ±90° (30°, 60°;
Lane T's engine probe). The client is correct.
**Ruling:** our combat ray tests rotated boxes itself in Lua instead of
trusting the engine for them (cost reported, not gated; user, after
discussing the cost). The coordinator wrote the upstream bug report (with a headless repro on
5.17.0: 8 of 24 facings miss — 105, 120, 150, 180, 195, 225, 240 and 255°,
all beyond ±90°; this plan first said "10 of 24", a miscount) at
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

## Completion (2026-10-05)

Every code lane below is merged on local main (last lane B, `a15bd0ae`);
not pushed. Each code lane was independently reviewed by Opus once, and
every review said MERGE: T after four small review fixes (blocking
pointability, a float-tolerant box compare, the candidate margin, the cost
lines), M with its review items and the user's rotation check, F's phase 1
as reviewed (phase 2, the picked file, checked by the coordinator), C as
reviewed (one stale comment fixed at the merge), E with the user's drop
picks as a follow-up, B's phase 2 with four stale doc lines fixed at the
merge. After each merge the coordinator ran the portable fixtures,
`check_fresh_server.py`, `validate.py --game` and `income.py --check`;
`tools/run_fixtures.sh` passes **84 of 84** on `a15bd0ae` (re-run on this
lane's branch). One boot of main with T, M, F and C (seed
6000697105738334415) passed. No mapgen change: a world of Round 33 or later
serves the GUI test.

### Shipped, by lane

Numbers are each lane's own probe or fixture, same seed and method before
and after (comparisons, never targets).

- **T aiming at rotated boxes** (merge `6932e10b`;
  [upstream workarounds](../technical/upstream-workarounds.md) §1,
  [combat_stats.md](../design/combat_stats.md)): `grug_core.aim_raycast`
  keeps the engine's raycast for nodes and every other object and tests
  `rotate = true` selection boxes in Lua, turned as the client turns them;
  the combat ray (held swings, skill targets, the crosshair colour,
  projectile aim), the hold ray, right-click interaction and the Target
  Frame use it. The independent review compared it with a C++ copy of the
  client path on 400 000 random cases: 0 mismatches. **Misses** in the
  engine probe (`tools/r35_t/engine.sh`, a mob turning through every yaw in
  15° steps, rays at several heights and sides):

  | Mob (rays) | Engine ray | Before: combat ray / Fireball | After: combat ray / Fireball |
  |---|---|---|---|
  | Zombie (288) | 62 | 62 / 62 | 0 / 0 |
  | Crocodile (192) | 32 | 32 / 32 | 0 / 0 |

  The crocodile also misses at 30° and 60° (§2.1). The upstream check
  (`tools/r35_t/upstream_check.sh`) reports 8 of 24 yaws missing on Luanti
  5.17.0. **Cost** per ray in a busy fight (20 zombies, six fake players;
  µs, median / best, after the review fixes, each round alternating with the
  plain engine ray):

  | Ray | Engine ray only | With the workaround |
  |---|---|---|
  | `combat_ray` 4 m (melee hold) | 13.9 / 13.6 | 35.1 / 32.8 |
  | `combat_ray` 20 m | 21.3 / 20.8 | 59.3 / 52.5 |
  | `aimed_target` 20 m (Fireball) | 21.9 / 21.6 | 67.0 / 53.2 |
  | the aim ray alone, 20 m | 15.6 / 15.4 | 47.9 / 44.1 |

  Medians spread with garbage collection (the review measured the
  `aimed_target` median at 137 µs, best 56 µs); the review's worst-case
  estimate is about 1–2.5 ms of server time per second per fighting player
  with 20 rotated mobs round every ray. `docs/technical/upstream-workarounds.md`
  starts with this entry and the `num_emerge_threads = 1` pin (Luanti
  #9357). Fixture 42 278 checks.
- **M capital music** (merge `e2f323ab`; [sound.md](../design/sound.md)
  §4–§6): music plays only in the six capitals, one rotation each
  (`D.rotations`), from entering (the first track as soon as it is
  downloaded) to leaving (8 nodes of hysteresis at the border); 5 s between
  tracks, the next track pushed 60 s before the current one ends. Either
  music or the bed: where music plays the bed is silent, with music off the
  capital's bed returns; the change is a 3 s crossfade. Default music volume
  35 %, the Help dropdown in 5 % steps, `/music` and the Help text name the
  capitals. The region pools are gone; all 16 tracks stay. Probe
  (`tools/r35_m/engine.sh`, seed 12345, 40 stand-ins, 60 s in Dawnmere, then
  in Highcourt, about one in four walking across the city border):

  | | Dawnmere before → after | Highcourt before → after |
  |---|---|---|
  | ambience evaluation without its node search | 8.2 → 8.7 µs | 6.5 → 10.0 µs |
  | location sample | 7.9 → 8.8 µs | 7.6 → 10.8 µs |
  | music pushes / plays | 24 / 19 → 0 / 0 | — → 20 / 11 |
  | bed plays (Highcourt) | | 80 → 19 (the border walkers) |

  The after run shared the machine with another lane (the unchanged
  atmosphere pass rose 24 % and 62 %), so the cost differences are mostly
  load; the review's re-run gave 10.2 µs per location sample in the capital
  against 8.9 µs in the start town, and 16 pushes and 11 plays in
  Highcourt. Rotations as confirmed by the user:

  | Capital | Rotation |
  |---|---|
  | Highcourt | Fantasy Orchestral Theme, Town Theme, Village Consort, Minstrel Guild |
  | Dur Brannoc | Memories of Stone, Thatched Villagers, Permafrost |
  | Lethariel | Achaidh Cheide, Soliloquy, Folk Round, A Dragon's Lullaby |
  | Gor Drazhak | The Great Sea, Teller of the Tales, Forest Walk |
  | Kezamba | Forest Walk, The Great Sea, A Dragon's Lullaby, Thatched Villagers |
  | Nhal Veyr | Katabasis I, Permafrost, Teller of the Tales, Soliloquy |

  Master of the Feast stays in the game but in no rotation. **Music tab
  study:** about 450 lines (an inventory page with the track table, volume
  and "play now" about 180, the playlist in player meta about 40, the
  scheduler source and the "play now" action about 70, a fixture about 150,
  plus docs); open questions are where a playlist plays (everywhere would
  undo the immersion ruling), a "loading" note for the first play, a push
  rate limit, up to about 29 MB of downloads per player and no seeking in
  the engine. The user decides later. Fixture 132 checks.
- **F small fixes** (merge `c35f617d`; [sound.md](../design/sound.md)
  §3.2, [durability_repair.md](../design/durability_repair.md),
  [character_visuals.md](../design/character_visuals.md),
  [quests.md](../design/quests.md)): **break sound** — equipped gear
  (weapon, bow, armour, offhand) or a tool that wears into broken plays
  `grug_sounds_gear_break` once, at the break (the user's pick B1.2,
  rubberduck, CC0, mono; spec gain 0.7, positional on the player, heard
  within 8 nodes); the hook sits in all three wear paths of
  `grug_repair/runtime.lua`. **Broken look** — `^[hsl:0:-80:-35^[cracko:1:4`
  (drained of colour, darkened, cracked) on the inventory icon, the held
  weapon, the weapon a held skill shows and worn armour; a first version by
  feel. **Empty hand** — a skill with an empty weapon slot shows
  `wieldhand.png` at the engine hand's scale in first person
  (`SKIN_VERSION` 4). **Dig sounds** — one load-time pass gives the 42
  nodes dug through `grug_resource` (ores, coal, gem ores) the stone dig
  (`default_dig_cracky`, gain 0.5) and those dug through `grug_loose` (sand
  and the other loose ground) the crumbly dig (gain 0.4); gravel and snow
  keep their own. **Flint** is gone (gravel drops gravel, no price row).
  **Quest dialog** — `size[16,9.4]` with a 7-unit list; the status is the
  entry's colour (available gold, ready to complete green, in progress
  blue, locked grey) with a legend line and a tooltip, "(R)" for
  repeatable, the description read-only; the quest log's list grew from
  3.45 to 4.45 units. The longest resolved title (380 px at 16 px Arimo)
  fits at about 1080p; at 720p about 95 % of titles fit. Fixture 98 checks;
  no hot path changed, so no timings.
- **C character creation in one window** (merge `70ded723`;
  [world.md](../design/world.md) §7,
  [character_visuals.md](../design/character_visuals.md) §1.1): one window
  `grug_classes:create` (faction row, race column, class row, the look
  panel, "Create character") with a session-only draft; Create stores
  faction, race, look and class at once and marks the character as
  arriving until the single arrival teleport. The faction, race, class and
  look forms are gone. **Window size:** `formspec_version[4]`, real
  coordinates, 15 × 10.6, no taller than the inventory (10.4 × 11.1), so
  the window is never the one that shrinks the GUI: by the engine's scaling
  (`calculateImgsize`) it gets 50.9 px per unit at 1024 × 600 (the
  inventory 48.6), 764 × 540 px; a phone-like 2400 × 1080 at density 2.6
  with a 14 pt font gets 91.7 px per unit, and the tight labels are sized
  for that font (only the Scout's description may scroll there). Fixture 131
  checks (the window's geometry included: everything inside, no clickable
  overlap, a tooltip on every button); engine probe 73 checks through the
  real receive-fields chain (seed 42). No per-step work, so no timings.
- **E mobs and economy** (merge `e1facaeb`;
  [biomes_mobs.md](../design/biomes_mobs.md), the generated grades in
  [item_tiers.md](../design/item_tiers.md)): **dawn departure** — a free
  region mob spawned under the night clock leaves by day with mobs_redo's
  smoke puff, unless it is in combat or a player is within **32 nodes**
  (beyond the 24-node spawn exclusion and every ambient mob's view range of
  at most 18, inside the 48–64-node active range); camp members and every
  mob without the night clock stay. One field test per mob step, a check
  once a second per night mob: 0.61 µs per call (1.0 ms over about 45 s).
  Engine run across a dawn (seed 12345): four night rats gone 0.7 s after
  dawn, the fighting one stayed until its target was removed (20.1 s) and
  left 0.14 s later, the day rat stayed. **Drop audit** by loot-table
  chances only; band medians before = after (`band_payout.sh`), so the
  income model and every derived price stay:

  | Band | 1 | 2 | 3 | 4 | 5 | 6 |
  |---|---:|---:|---:|---:|---:|---:|
  | Target (c) | 3 | 8 | 19 | 48 | 120 | 300 |
  | Median (c) | 4.3 | 9.0 | 16.7 | 43.6 | 119.5 | 239.3 |

  Payout per kill, before → after (copper; every other family unchanged):

  | Family | Band 1 | Band 2 | Band 3 | Band 4 | Band 5 | Band 6 |
  |---|---:|---:|---:|---:|---:|---:|
  | Rat (tail, fur 1/2 → 1/3) | 8.0 → 5.7 | 19.0 → 13.0 | – | – | – | – |
  | Crab (eye, leg 1/2 → 1/3) | 8.0 → 5.7 | 16.0 → 13.0 | – | – | – | – |
  | Fox (band-1 Fang 1/3 → 1/6) | 10.0 → 7.0 | – | – | – | – | – |
  | Crocodile (Tooth 1/3 → 1/6) | – | 17.7 → 12.3 | 26.7 → 21.3 | – | – | – |
  | Zombie (flesh 1/2 → 1/3, 2nd signature 1/3 → 1/6) | – | – | 45.0 → 30.0 | 101.0 → 63.7 | 241.3 → 148.0 | 592.1 → 358.8 |
  | Outlaw (strap 1/1 → 1/3, talisman 1/2 → 1/3) | – | – | 74.5 → 37.0 | 175.2 → 81.8 | 429.0 → 195.6 | 1059.8 → 476.4 |

  Expected kills for the affected quests: Crab Leg (four pantry quests, 2
  needed) 4 → 6 and (two, 3 needed) 6 → 9; Pickled Flesh
  (`nhal_veyr_provisions_02`, 4 needed) 8 → 12; Rat Fur Patch (five
  `pantry_01` quests, 2 needed) 4 → 6, so after the 8-rat hunt a player
  holds both furs 80 % of the time instead of 96.5 %. No quest asks for a
  weapon strap or a band 3–6 signature. Fixture 79 checks.
- **B level-proof talents** (merge `a15bd0ae`;
  [skill_trees.md](../design/skill_trees.md) §2.10,
  [combat_stats.md](../design/combat_stats.md), [classes.md](../design/classes.md),
  [scout.md](../design/scout.md)): 13 flat talent values became a
  percentage of a level reference at the player's level — of the base hit
  `B(L)` (the same-level baseline hit before the damage scalar: 17 / 95 /
  337 at levels 10 / 30 / 60) for damage, of the armour constant `K(L)` for
  armour; each keeps today's strength at the middle of its tier's level
  range (30 / 35 / 45 / 50). The tooltip shows each rank at the viewer's
  level. Full ranks, share of the ability:

  | Talent | Before at L10 / L30 / L60 | After (every level) |
  |---|---|---|
  | Tinder (Mage T1) | 43 / 20 / 11 % | 20 % |
  | Sharpened Word (Priest T1) | 31 / 15 / 9 % | 15 % |
  | Strong Draw, Fine Edge (Scout T1) | 46 / 23 / 13 % | 23 % |
  | Ironbound (Warrior T1, armour) | +5 rating | 15 % of `K(L)` |
  | Warded Wrath (Priest T2) | – / 12 / 7 % | 12 % |
  | Brand splash (Mage T3) | – / 16 / 9 % | 12 % |
  | Cinderfall (Mage T3) | – / 36 / 21 % | 25 % |
  | Word of Ruin (Priest T3) | – / 30 / 18 % | 22–23 % |
  | Rimebite (Mage T4) | – / – / 46 % of Ice Nova | 25 % of a base hit (100 % of Ice Nova) |
  | Whitehot window (Mage T4) | – / – / 14 % | 30 % of a base hit |
  | Longshot beyond 25 m (Scout T4) | – / – / 5 % | 6 % |
  | Unbroken emergency rating (Warrior T4) | +15 rating | 33 % of `K(L)` |

  The review of all 64 talents and the user's picks
  (`tools/r35_b/numbers.py decided`; level 60, level 30 in brackets):

  | Figure | Before | After |
  |---|---|---|
  | Scout Quarry draw chain vs a Warrior | 2.2× (2.3×) | 1.6× (1.6×) |
  | Recompense vs one mob's damage | 242 % (220 %) | 81 % (73 %) |
  | Whitehot | +1.1 % DPS | +4.0 % DPS, 24 % of the pool per 60 s |
  | Ruination | +1.4 % DPS | +4.1 % DPS (+4.2 %) |
  | Rimebite, one target | +2.9 % | +3.9 % |
  | Last Word per trigger | 199 HP (7 % of HP) | 499 HP (19 %) |
  | Heavy Hand 5/5 / Keen Edge 5/5 | +5.4 % / +4.6 % DPS | +11.7 % / +9.2 % DPS |
  | Hardened 3/3 / Weathered 4/4 | +0.9 % / +6 % HP | +6 % / +10 % HP |
  | Cold Focus 5/5, time until out of mana | +5 % | +10 % (+9 %) |
  | Swift Word 4/4, Smite rate | +43 % | +25 % |
  | Charge damage after the level scalar | 23.1 (11.6) | 40.4 (11.5) |

  Crit at level 60 with two crit enchants and 2 points per crit-talent
  rank: Warrior and Priest 27–28 %, Mage 25–26 %, a Scout with Dexterity on
  all eight items 34–35 %, held at the 30 % cap; Elixir of Precision VI
  takes every class to the cap. Fixture 386 checks; `get_talent_bonus`
  gains one table lookup and a short formula, so no measuring run.
- **D:** this section, the status files, AGENTS.md, the module guide and
  the design index.

### The user's choices during the round

1. **Break sound:** B1.2 (rubberduck, metal breaking with falling pieces,
   CC0) of four candidates; list `tools/r35_f/approved.txt`.
2. **Talents "all as recommended"**, the eight decisions of the review
   page: (1) the percentage is of the level's base hit, independent of
   gear; (2) today's strength is kept at the middle of each tier's range
   (30 / 35 / 45 / 50); (3) the 13 values as proposed; (4) too strong:
   Recompense a 6 s internal cooldown, Fletching full draw 2.0 s, Twin Shot
   40 / 50 / 60 %, Swift Word 1.6 s; (5) weak: Hardened 2 / 4 / 6 % of the
   class's base pool, Second Skin shortens the Shield cooldown to 9 / 8 /
   7 s, Weathered 2.5 % per rank, Heavy Hand Mighty Blow up to ×2.0, Cold
   Focus +40 % mana regeneration per rank (×3.0 at 5/5), Shifting Weight and the four crit
   talents 2 points per rank; (6) capstones: Whitehot a 60 s cooldown and
   +30 % of a base hit, Ruination a 15 s window every 60 s, Last Word 12 s
   and a Word of Ruin cooldown reset, Rimebite 25 % of a base hit, Unbroken
   only a text change; (7) Charge 12 % of a base hit; (8) Opening also on
   a rooted or stunned target. Also Loose floors once, after the level
   scalar.
3. **Rotations** confirmed as proposed, except **Master of the Feast**,
   removed from every rotation (too energetic for a town); it stays in the
   game.
4. **The 3 s crossfade** between music and the bed stays (the
   coordinator's call on the M review: "a short fade, no hard cut"), not a
   strict gap.
5. **Drops:** the rat (tail and fur 1/3), the Fox Fang (band 1, 1/6) and
   the Crocodile Tooth (1/6) as the lane changed them, then the outlaw,
   zombie and crab outliers as recommended.
6. **Near distance** for dawn departure: 32 nodes.

### Open notes

In the [BACKLOG](../../BACKLOG.md#round-35-carry-overs); none blocks the
GUI test. Numbers are comparisons, never targets.

- **Spell formulas** still round to an integer before the level scalar
  (`grug_abilities/kits.lua` ~124–127): up to ±4 damage at level 60, the
  issue the user fixed for Loose (Mighty Blow and Opening floor by design).
- **Ability items show the static cooldown** (Shield with Second Skin,
  Swift Word, Grudge, Quick Step).
- **Scout crit above the cap:** a fully geared Scout reaches 34–35 % and
  is held at 30 %; optional "(30 % cap holds)" in Cold Eye's text.
- **Recompense's internal cooldown** is per session (a relog resets it).
- **Opening on rooted targets** also works in PvP (Pinning Shot, then
  Opening).
- **Admin `/faction`** on an existing character re-enters the full
  creation window (its class and look picks are ignored).
- **Capture probes** `tools/r26_map`, `tools/r26_status_icons`,
  `tools/r27_minimap` still drive removed creation fields (broken since
  Round 31).
- **Music tab** study: about 450 lines; the user decides later.
- **Long war-camp quest titles** are cut below about 1080p.
- **Aim-ray cost:** about 1–2.5 ms/s per fighting player in the worst case;
  rotated hits behind a "blocking" node or non-rotated object are not held
  back (none exists).
- **Night mobs** may vanish in a puff 32–64 nodes away by day; a fast mount
  can reach one before its first check (it then stays).
- **Band 3** stays below its income target (16.7c against 19c).

### GUI playtest checklist

Desktop client and the web build, a world of Round 33 or later (no mapgen change); helpers `/xp give`,
`/teleport`, `/giveme`, `/time` (privileges `server`, `give`, `settime`).
Say what looks or sounds wrong; looks are tuned from your notes.

Aiming (T):

1. **A held Fireball and held melee on Braindead Zombies** while walking
   round them, so they face you from every side: the crosshair stays
   coloured and every cast and swing lands; then the same on a
   **crocodile** (including from the side and at a slant) and on a
   **dragon**, aiming at a wing tip and the tail.
2. **The crosshair colour** on a mob that turns away from you does not
   drop to white while it is under the crosshair.

Items, mining and quests (F):

3. **Gear breaking:** wear a weapon, a bow, an armour piece and an offhand
   down to broken: the break sound plays once (gain 0.7, also heard by a
   player close by), not again on later use.
4. **The broken look** (drained of colour, darkened, cracked) on the
   inventory icon, the held weapon, the weapon shown while a skill is held,
   and worn armour on the model.
5. **A skill with an empty weapon slot** shows the bare hand in first
   person, not the coloured orb; third person stays empty.
6. **Digging:** iron and other ores, coal, a gem ore (stone dig sound);
   sand and gravel with a shovel (crumbly sound); gravel drops only gravel,
   never flint.
7. **The quest dialog** at a quest giver: entries in gold, green, blue and
   grey with the legend line and its tooltip, "(R)" on repeatables, the
   description cannot be edited; the **quest log** list the same. Make the
   window small and open a **war-camp quest** with a long title.

Mobs and loot (E):

8. **Night rats** (Large Grave Rats in Stillgrave Hollow) at dawn: rats
   out of your reach leave in a puff in the distance; one you are fighting
   stays until the fight ends, then leaves; one within 32 nodes stays
   while you are near.
9. **Start-zone loot** over a few kills (rats, crabs, a fox): fewer tails,
   furs, eyes and legs than before; a pantry quest still finishes in a
   handful of kills.

Talents (B):

10. **Talent tooltips** at your level: Tinder, Ironbound, Second Skin
    (the Shield cooldown), Cold Focus each show the value per rank at your
    level; check at two levels (`/xp give`).
11. **Charge** damage at a low and a high level; **Opening** on a target
    rooted by Pinning Shot (from the front); **Last Word** resetting Word
    of Ruin's cooldown at once.

Music (M):

12. **Capital music:** enter each capital — music starts (after its
    download the first time) and the town bed fades out; leave — the
    music fades over 3 s and the bed returns; walk along the wall without
    the music toggling.
13. **No music in a start town** (Dawnmere and the others), only the
    quiet bed.
14. **Music off** (`/music off` or Help → Sound) in a capital: the bed
    plays again; on again: music returns. `/music 50` changes a playing
    track; the Help → Sound page shows **35 %** by default.

Character creation (C):

15. **The new creation window** at **1024 × 600**, in a **phone-like
    window** and in the **web build**: the faction row, race column, class
    row and the look area all readable; tooltips on every button; the
    model turns with the mouse and holds no weapon.
16. **Choices:** a faction change clears race and look and keeps the
    class; a race change rolls a new look; "Create character" stays grey
    until faction, race and class are chosen.
17. **Esc and I** pause and resume with the draft kept; **disconnect
    before Create** and reconnect: creation starts over with nothing
    stored; **reconnect during the arrival wait** after Create: the
    arrival resumes.
