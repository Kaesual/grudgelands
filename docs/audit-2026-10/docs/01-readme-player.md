# D1 — README.md from the player's perspective

**Scope:** `README.md` (403 lines), `game.conf`, `settingtypes.txt`,
`minetest.conf` (only where it affects a local player), `menu/`
(`icon.png`, `theme.ogg`, `LICENSE-media.md`; no other player-facing text
there), `CREDITS.md` (presentation only).
**Baseline:** `0f169898` (main; `origin/main` points at the same commit).
**Method:** read the README in full; built an inventory of player-visible
content from the code (class/race/talent-tree registrations, profession
registry, quest JSON count, settlement list, mob/boss registrations, mount
catalog, housing constants, PvP rules, party limit, inventory tabs via
`sfinv.register_page`, every `register_chatcommand`, control reads via
`get_player_control`, settings reads via `core.settings:get*`); compared
each README claim against it; validated every relative link and anchor in
the README (all resolve). Known gaps in `docs/maintenance/findings.md` and
`BACKLOG.md` were checked; none of the items below repeats them.

**Inventory (code, baseline):** 4 classes (Warrior, Mage, Priest, Scout;
`grug_classes/init.lua:136-164`, `scout.lua:6`), 2 talent trees each
(`talents.lua:378-709`, `scout_talents.lua:4,68`), level cap 60
(`grug_xp/init.lua:5`); 6 peoples with one passive each, Human/Dwarf/Elf
for The Accord, Orc/Troll/Undead for The Throng (`grug_classes/init.lua:173-207`);
6 start towns + 6 capitals (`grug_home/locations.lua:4-15`); 540 quests in
42 zone files, 55 of them repeatable; the level-41+ main story and Isquarre
(`rift_core.lua:38`); 6 primary + 2 secondary professions, 2 primaries max
(`grug_jobs/registry.lua:5-22`, `trainers.lua:24-26`); white/blue/gold
drops, bosses 2 items (`grug_quality/init.lua:76-95`); 4 riding tiers
(15/30 ground, 45/60 **flying**) and 2 boats (15/30)
(`grug_mounts/catalog.lua:14-32`); Claim Stone housing from level 20,
101×101, 5-lump activation (`grug_housing/registry.lua:33-38`,
`manager.lua:90`); PvP flag button 60 s (`grug_pvp/rules.lua:11-12`);
party of 10, own faction (`grug_parties/init.lua:17,205`); bosses: 2
island dragons, 6 capital kings, 2 fortress Generals, 2 war commanders,
the rift boss (`grug_mobs/bosses.lua:1-56`, `data/pvp_names.json:7-8`);
inventory tabs Crafting, Character (Stats/Effects/Achievements), Bags,
Skills, Talents, Quests, Map, Group, PvP, **Help** (six sub-pages,
`grug_inventory/help.lua:34-154`); player chat commands `/char`,
`/talents`, `/money`, `/xp`, `/faction`, `/race`, `/music`, `/ambience`
(admin-only: `/clear_mobs`, `/claim_remove`, `/pvpstate`, `/atmosphere`,
`/combatdebug`, `/road_spots`).

## Verdict

- **The pitch (lines 1–63) is accurate.** Every numeric claim checked holds:
  four classes with two trees each, level 60, six towns and six capitals,
  "more than 500 quests" (540), two of six primary professions plus
  Cooking and Alchemy, white/blue/gold drops with two items per boss,
  parties of up to ten from your own faction, the 60-second PvP button.
  Nothing removed from the design (rested XP, `/unstuck`, carried light,
  hoard chest, renewable ores) is described as present.
- **The Nether/underworld is handled correctly:** described only as "a
  story for a later expansion" (lines 63, 211, 286). No WoW/Blizzard
  reference appears in README, game.conf, settingtypes.txt, CREDITS.md or
  menu/.
- **As a player document it is weak.** Just over half the file (lines
  65–276, 212 of 403 lines) is a reverse changelog of 16 rounds with
  links to planning docs, playtest checklists and work-package counts.
  That duplicates `docs/STATUS.md` and buries the current state.
- **A new player gets no first steps and no controls.** Grudgelands'
  controls are unusual: skills are dragged from the Skills tab onto the
  hotbar, the weapon lives in Character-page hand slots, and held left
  click switches between mining and fighting. The README explains none
  of this and never mentions the in-game **Help** tab, which already has
  a good "first steps" guide.
- **The local-install instructions are missing a step that can break a
  world:** changing any mapgen checkbox in Luanti's *New World* dialog
  makes the game refuse to load (RDM-01). The README also does not warn
  about the "Preparing the world" wait on the first start.
- **The status lines are already out of date:** Round 36 is described as
  "complete locally" and Round 35 as "the latest pushed state", but
  Round 36 was pushed on 2026-10-05 (RDM-02).
- **Several major features appear only in the changelog:** housing, flying
  mounts, dragons and kings, and the depth/pick rules are missing from
  "What you can play today".
- The design-doc table and the external links are complete and correct.
  CREDITS.md is well organised for its readers.

## Mismatch table

| ID | Sev | Category | Direction | Doc location | Short description |
|---|---|---|---|---|---|
| RDM-01 | High | Missing | doc stale → fix doc (code option → Jan) | README.md:299-302 | Local install omits "leave the New World mapgen options at their defaults"; any changed checkbox makes the world fail to load |
| RDM-02 | Medium | Outdated | doc stale → fix doc | README.md:71-72, 221-233 | Round 36 called "complete locally"/"merged locally", Round 35 "latest pushed"; R36 was pushed 2026-10-05 |
| RDM-03 | Medium | Bloat | doc stale → fix doc | README.md:65-276 | 212-line round-by-round changelog plus WP counts and checklist links bury the current state and duplicate STATUS.md |
| RDM-04 | Medium | Missing | doc stale → fix doc | README.md (no section) | No getting-started or controls section; the in-game Help tab is never mentioned |
| RDM-05 | Medium | Missing | doc stale → fix doc | README.md:41-44 | Claim Stone housing is missing from "What you can play today" (appears only in the Round 25/26 history) |
| RDM-06 | Medium | Missing | doc stale → fix doc | README.md:41-42 | Flying mounts (levels 45/60) and the mount/boat levels are not mentioned |
| RDM-07 | Medium | Missing | doc stale → fix doc | README.md:299-302 | First start of a new world waits for "Preparing the world"; not mentioned |
| RDM-08 | Low | Missing | doc stale → fix doc | README.md:24-27, 45, 59 | Peoples, capitals, continents and racial passives are never named |
| RDM-09 | Low | Missing | doc stale → fix doc | README.md:28-40 | Bosses (island dragons, capital kings, Generals, rift boss) absent from the feature list |
| RDM-10 | Low | Missing | doc stale → fix doc | README.md:50-53 | Player chat commands undocumented; "volume settings" doesn't say where they are (`/music`, `/ambience`, Help → Sound) |
| RDM-11 | Low | Outdated | doc stale → fix doc | README.md:207-208 | "the 200-arrow Basics recipe" — one craft now makes 100 arrows |
| RDM-12 | Low | Unclear/Agent-trap | doc stale → fix doc | README.md:204 | "Round 20 supplies 240 quests" next to "more than 500 quests" (line 29) reads like a contradiction |
| RDM-13 | Low | Wrong | doc stale → fix doc | README.md:301-302 | "Development uses Luanti 5.17.0-dev" mixes up the reference checkout with the test client (Flatpak 5.17.0) |
| RDM-14 | Low | Unclear/Agent-trap | unclear → Jan decides | README.md:333-334 | Asks bug reporters for "your game version", but the game has no version a player can see |
| RDM-15 | Low | Missing | doc stale → fix doc | README.md:293-324 | Host-facing facts are missing: the game's settings (map quality, full-world prep, mob damage ×1.5, tree regrowth, atmosphere), and that damage is always on with creative off |
| RDM-16 | Low | Unclear/Agent-trap | doc stale → fix doc | settingtypes.txt:15, 26-27, 36, 59, 63-67 | Main-menu setting descriptions show code internals (function names, globalstep, "observer-managed") |
| RDM-17 | Low | Contradiction | doc stale → fix doc | CREDITS.md:10-12 vs README.md:397-399 | "combined game is GPL-3.0" vs "GPL-3.0-only" |
| RDM-18 | Low | Unclear/Agent-trap | doc stale → fix doc | README.md:82 | "a war commander guards two enemy camps": in fact there are two commanders, one per faction's camp |
| RDM-19 | Low | Bloat | doc stale → fix doc | README.md:248-258, 390 | Development notes (music tab idea, POI placement, Cooking feedback, guard healing, "Round 18 decisions" routing row) in a player document |

## Details

### RDM-01 Local install: mapgen options in the New World dialog must stay at their defaults

**Doc says:** "place this repository in your Luanti `games/` directory as
`grudgelands`, then select it when creating a **new world**. The game uses
mapgen **v7**." (README.md:299-301)
**Code does:** at world construction, the mapgen runtime calls
`error()` unless the live mapgen settings match exactly:
`mg_flags` must be exactly `biomes,caves,decorations,dungeons,light,ores`;
`mgv7_spflags` must be exactly `mountains,ridges,nofloatlands,caverns`;
`chunksize` 5, `water_level` 1, `mapgen_limit` 31007, and
`num_emerge_threads` 1 (`mods/MAPGEN/grug_mapgen/wp40/r7_runtime.lua:22-24,
85-111`, called at `:255` and `:437`). Luanti's New World dialog shows
checkboxes for Caves, Dungeons, Decorations and the v7 flags
(Mountains, Ridges, Floatlands, Caverns) and writes them into the world
(`reference_projects/luanti/builtin/mainmenu/dlg_create_world.lua:159-215,
383-386`). The checkboxes start from the player's own saved settings
(`:465-468`), so a player who used other v7 options before may start from
non-default values without touching anything. `game.conf` sets only
`allowed_mapgens = v7`; it has no `disallowed_mapgen_settings` line to
hide those checkboxes (`game.conf:7-8`). The game's own `minetest.conf`
is only a default layer, and the player's config wins
(`minetest.conf:3-9`).
**Impact:** a player who ticks "Floatlands" or unticks "Caves" gets a
world that fails to load with an error that means nothing to them
("WP40 R7 runtime: …"). The README is the only installation guide.
**Suggested fix:** in "Play with Luanti", add: "Keep the map generator
options of the New World dialog at their defaults (Caves, Dungeons,
Decorations, Mountains, Ridges and Caverns on, Floatlands off). Other
values, or your own overrides of `chunksize`, `water_level`,
`mapgen_limit` or `num_emerge_threads`, stop the world from loading."
For the code side, see Open questions: adding
`disallowed_mapgen_settings = mg_flags, mgv7_spflags, chunksize, water_level, mapgen_limit`
to game.conf would hide the checkboxes and remove the trap.
- **Verification (phase 2):** Confirmed — `validate_live_scalars` (mods/MAPGEN/grug_mapgen/wp40/r7_runtime.lua:85-111, run at construction :255) fails on any change to Caves/Dungeons/Decorations (mg_flags) or to the v7 Mountains/"Rivers" (= `ridges`)/Caverns/Floatlands boxes (reference_projects/luanti/builtin/mainmenu/dlg_create_world.lua:26-31, 383-386), and engine defaults match the required tuple, so only a changed box or a non-default saved setting aborts; note the dialog labels `ridges` "Rivers", so the suggested README text should say "Rivers", not "Ridges". The key is supported (reference_projects/luanti/doc/lua_api.md:171-174; dlg_create_world.lua:127-129, 163, 201) but it only hides the checkboxes: the dialog still writes the player's saved `mg_flags`/`mgv7_spflags` (dlg_create_world.lua:383-386, 465-468), and `chunksize`/`water_level`/`mapgen_limit` are not in that dialog at all, so the game.conf line reduces the trap rather than removing it.

### RDM-02 Round 36 is reported as unpushed

**Doc says:** "Round 36 … is complete locally and awaits a playtest"
(README.md:71-72); "independently reviewed and merged locally" (:224-225);
"Round 35 is the latest pushed state" (:232).
**Code does:** `git reflog show origin/main` shows
`1e8a975d … 2026-10-05 18:47:21: update by push` and
`0f169898 … 21:19:04: update by push`. `origin/main` equals the baseline
HEAD, so Round 36 and the later commits are pushed.
**Impact:** agents and readers believe Round 36 is unreleased. The same
stale state appears in `docs/STATUS.md:9` ("not pushed") and in the
auto-memory. Those are other lanes' scope, but they should be fixed
together.
**Suggested fix:** in README.md:71-72 replace "is complete locally and
awaits a playtest" with "is complete and pushed and awaits a playtest".
Change :225 "merged locally" to "merged and pushed", and :232 to
"Round 36 is the latest pushed state". If RDM-03 is applied, these lines
move out of the README anyway.

### RDM-03 The "Current State" changelog dominates the README

**Doc says:** README.md:65-276 is a reverse diary covering Round 36 back
to Round 20. It includes per-round "is complete and pushed / awaits a
playtest" status, commit-level detail ("isolated server startup … are
verified", :207-208; "the full 100-anchor art roster", :204-205), a
work-package tally (:216-218) and eleven playtest-checklist links listed
twice (:234-246, :262-274).
**Code does:** n/a. The section duplicates `docs/STATUS.md` ("delivery
pointer", STATUS.md:3), which already holds this history per round.
**Impact:** a player looking for "what can I do in this game" has to
read past 212 lines of change notes. A one-paragraph summary would serve
better. Each new round adds another paragraph, so the problem keeps
growing, and the round notes go stale (RDM-02, RDM-11, RDM-12).
**Suggested fix:** replace lines 65-276 with a short "Current state"
of 5–8 lines: the latest round and what it added in one or two sentences,
"Expect world resets: Round 36 needs a fresh world", "Not yet in the
game: scripted war-front battles, the underworld", and a link to
`docs/STATUS.md` for round-by-round history and playtest status. Move
the round paragraphs that STATUS.md does not already cover to STATUS.md
or a new `CHANGELOG.md` written for players (Jan decides which).

### RDM-04 No getting-started or controls section; the in-game Help tab is not mentioned

**Doc says:** nothing about first steps or controls. The only guidance
is "Try a class, follow a few quests" (README.md:328).
**Code does:** the game has unusual controls:
- the starter weapon is equipped in the Character page's hand slots, not
  the hotbar; skills are dragged from the Skills tab onto the hotbar,
  selected, and fired with left click (`grug_inventory/help.lua:37`,
  `:101-104`);
- held left click mines, or fights a creature that walks into your aim
  (`grug_abilities/input.lua:1-24, 445`);
- `I` opens the inventory, and character creation and world preparation
  point to it ("press I to continue" / "press I to see progress",
  `grug_classes/selection.lua:60,64`);
- flying mounts climb with Jump and descend with Sneak
  (`grug_mounts/entity.lua:390-391`).
The inventory has a **Help** tab (`grug_inventory/help.lua:231-232`) with
six sub-pages: first steps, quest symbols, professions, ore depths,
formulas, sound. The README does not mention it.
**Impact:** the very first thing a new player needs is missing.
Players who expect usual Luanti or MMO controls (a number key casts a
skill, the weapon goes in the hotbar) get stuck.
**Suggested fix:** add a "Getting started" section right after "What you
can play today" (about 10 lines): create a character (faction, people,
class, look); press `I` and open the **Help** tab; equip/skills/hotbar/
left-click in two lines; yellow `!` and `?` quest givers; head for your
capital around level 10; Return home on the Character page; death costs
nothing (help.lua:116). Link to the Help tab as the full guide. Do not
copy the whole Help text into the README.

### RDM-05 Housing is missing from the feature list

**Doc says:** "Life between adventures. Grow crops, go fishing, prepare
food, visit vendors and save for a mount or a boat. Bind your home at an
innkeeper …" (README.md:41-44). Claim Stones appear only in the round
history (:173-175, :183-188).
**Code does:** Claim Stone housing is live: one free stone from level 20
from the Housing Steward (`grug_housing/manager.lua:90`), a 101×101
protected claim, a 5-minute draft activated with 5 lumps
(`grug_housing/registry.lua:33-38`), allowed only in the own faction's
home land, outside level 1–10 zones, level 31+ zones and capital zones
(`registry.lua:436-448`).
**Impact:** a central sandbox feature is invisible to anyone who reads
only the pitch. If RDM-03 is applied, the only mention disappears with
the changelog.
**Suggested fix:** add to the "Life between adventures" bullet: "From
level 20 a Housing Steward in your capital gives you a Claim Stone: a
protected 101 × 101 plot in your faction's level 11–30 lands (not in a
capital's zone), kept running with coal or charcoal, with access for
friends."

### RDM-06 Flying mounts and mount/boat levels are not mentioned

**Doc says:** "save for a mount or a boat" (README.md:42).
**Code does:** Apprentice/Journeyman Riding (ground) at levels 15/30, and
Expert/Master Riding (**flight**) at 45/60; Boat at 15, Improved Boat at
30 (`grug_mounts/catalog.lua:14-32`). Riding Trainer and Shipwright stand
in every capital (help.lua:112-113).
**Impact:** flying is a major draw at high level and goes unmentioned.
**Suggested fix:** "Learn to ride from level 15 and to fly from level 45
at your capital's stable; boats from level 15 are the way to the dragon
islands."

### RDM-07 The first-start wait is not mentioned

**Doc says:** install steps end at "select it when creating a new world"
(README.md:299-301). The caveat about full-world preparation sits inside
the collapsed development block (:261-262).
**Code does:** before anyone can enter a fresh world, the game prepares
the six start areas. The player sees "Preparing the world – press I to
see progress" (`grug_classes/selection.lua:64`;
`docs/design/world_preparation.md:11-20`: "Players cannot enter the
unprepared world while the selected preparation plan is incomplete").
`grug_prepare_full_world` (settingtypes.txt:57-61) can stretch this to
many hours.
**Impact:** a first-time local player may think the game has hung.
**Suggested fix:** one sentence in "Play with Luanti": "The first start
of a new world prepares the six starting areas before you can enter;
press I to see the progress. Leave 'Prepare full world before entry' off
unless you host a server and can wait several hours."

### RDM-08 Peoples, capitals and continents are not named

**Doc says:** "two factions and six peoples" (README.md:45), "Six
starting towns and six capitals" (:26-27), "rival continents" (:59).
**Code does:** The Accord: Human (Highcourt), Dwarf (Dur Brannoc), Elf
(Lethariel). The Throng: Orc (Gor Drazhak), Undead (Nhal Veyr), Troll
(Kezamba) (`grug_home/locations.lua:4-15`, help.lua:47). Each people has
one passive (`grug_classes/init.lua:173-207`). The continents are
Elandor and Kragmar (zone file prefixes, `menu/LICENSE-media.md:9-11`).
**Impact:** a player can't tell from the README which people belongs to
which faction. That choice is the first decision in the game.
**Suggested fix:** a small table under "What you can play today": faction
→ people → capital, with a one-line passive each. See Open questions
for the naming concern.

### RDM-09 Bosses are absent from the feature list

**Doc says:** "take on stronger enemies" (README.md:29); dragons appear
only in the changelog (:87, :141-142, :148-149).
**Code does:** two island dragons (the Wyrmglass Ice Dragon, the
Stormscale Jungle Wyvern), a king with royal guards on each capital's
throne, two fortress Generals (`grug_mobs/bosses.lua:1-56`) and Isquarre
at the rift (`rift_core.lua:38`). Kings, Generals and guards fight enemy
players anywhere (`docs/design/pvp.md:93-95`).
**Suggested fix:** one bullet: "Bosses: two dragons on their own islands
at level 60, the kings of the six capitals, each fortress's General and
the rift's Isquarre; bosses drop two blue or gold items."

### RDM-10 Player chat commands and sound controls

**Doc says:** "each capital has its own calm music, with volume settings
for both" (README.md:52-53). No commands are listed.
**Code does:** `/music` and `/ambience` `[on|off|0-100]`
(`grug_ambience/init.lua:518-530`), also as controls on Help → Sound
(help.lua:3-5). Other player commands: `/char`
(`selection.lua:889`), `/talents` (`talents.lua:1311`), `/money`
(`grug_money/init.lua:184`), `/xp` (`grug_xp/init.lua:268`), `/faction`
and `/race` (show only without the server privilege;
`grug_factions/init.lua:328`, `selection.lua:916-953`).
**Suggested fix:** in the Getting-started section, add one line: "Sound:
Help → Sound or `/music 50`, `/ambience off`. Useful commands: `/char`,
`/talents`, `/money`."

### RDM-11 The arrow recipe figure is out of date

**Doc says:** "the 200-arrow Basics recipe are verified" (README.md:207-208).
**Code does:** one craft makes 100 arrows ("One craft fills one arrow
stack (stack_max 100, Round 28 ruling 26)",
`grug_professions/base_recipes.lua:142-143`).
**Suggested fix:** delete the sentence (development detail; see RDM-03),
or change it to 100.

### RDM-12 "240 quests" next to "more than 500"

**Doc says:** "The preceding Round 20 supplies 240 quests" (README.md:204);
"More than 500 quests" (:29).
**Code does:** 540 quest ids across
`mods/PLAYER/grug_quests/data/zones/*.json` (counted at baseline;
matches `docs/STATUS.md:21`). The 240 legacy quests were replaced in
Round 29 (STATUS.md:369).
**Suggested fix:** remove it together with the Round 20/21 history
(RDM-03). If kept, write "Round 20 supplied the first 240 quests (since
replaced)".

### RDM-13 Engine version

**Doc says:** "Development uses Luanti **5.17.0-dev**; compatibility with
older versions has not been established." (README.md:301-302)
**Code does:** 5.17.0-dev is the read-only reference source checkout
(`AGENTS.md:458-461`). The client used for testing is the Flatpak
`org.luanti.luanti` (AGENTS.md:876), whose installed version is
`5.17.0` (`flatpak info org.luanti.luanti`).
**Impact:** players may think they need a development build.
**Suggested fix:** "Tested with Luanti 5.17.0; older versions are
untested."

### RDM-14 "Your game version" does not exist

**Doc says:** "include what you were doing, your game version and whether
you played through the browser or a native Luanti client" (README.md:333-334).
**Code does:** `game.conf` has no version field, and no player-visible
version string exists (grep for a game version in `mods/CORE` and
`mods/PLAYER` finds only internal cache versions; the Help → About page
shows none, help.lua:139-144).
**Suggested fix:** either ask for "the date you played (and for a local
copy, the commit)", or (Jan decides) add a version line to Help → About
and game.conf.

### RDM-15 Host-facing facts missing

**Doc says:** nothing about server/singleplayer settings.
**Code does:** `settingtypes.txt` offers World map quality (normal/high),
Prepare full world, Non-player damage multiplier (default **1.5**,
`grug_mobs/levels.lua:120`), tree regrowth, atmosphere presets and
nametag colours. `game.conf:4-5` forces damage on and creative off.
**Suggested fix:** a three-line "Hosting a server" note under "Play with
Luanti": settings live under *Settings → Games → Grudgelands*; name the
four that matter (map quality, full-world prep, damage multiplier,
regrowth); damage is always on and creative mode is off; link
`docs/design/world_preparation.md`.

### RDM-16 settingtypes.txt descriptions show code internals

**Doc says (shown in Luanti's settings menu):** "With this off,
grug_core.set_atmosphere does nothing" (settingtypes.txt:15); "A
globalstep re-checks each player's zone" (:26-27); "observer-managed
nametags" (:36); "Development diagnostic … capital plot" (:63-67).
Line 59 joins two sentences on one long line ("…are not prepared. Read
once on the first fresh-world boot…").
**Impact:** host-facing UI text written for developers. Low.
**Suggested fix:** reword for a server host, for example "Turn off to
use the engine's default lighting", "The sky and light change with the
zone you are in", "Name-tag colours by kind", and prefix the terrain-audit
setting with "(Developers)". Re-wrap line 59.

### RDM-17 License wording differs between CREDITS and README

**Doc says:** "the combined game is GPL-3.0 because it includes
GPL-3.0-only code from cottages" (CREDITS.md:10-12) vs "The combined game
is **GPL-3.0-only**" (README.md:398).
**Suggested fix:** use "GPL-3.0-only" in CREDITS.md:11 as well.

### RDM-18 War commanders

**Doc says:** "a war commander guards two enemy camps" (README.md:82).
**Code does:** two commanders, War Commander Stonegrudge and War
Commander Greyvow, each in one faction's high war camp
(`grug_mobs/data/pvp_names.json:7-8`).
**Suggested fix:** "each faction's highest war camp now has a war
commander".

### RDM-19 Development notes in a player document

**Doc says:** "A possible music tab, a few missing decoration pieces and
the main-menu background are noted, and the deep spawn pulse stays for
later. Points of interest stay at fixed positions (per-world placement
set aside)" (README.md:250-252); "The confusing Cooking feedback now has
a distinct success message; the trainer flows still need in-game
acceptance. Friendly-guard healing remains deferred." (:257-259); design
table row "Decision routing | Round 18 decisions" (:390).
**Suggested fix:** move these to STATUS.md/BACKLOG (they are already
tracked there) and drop the "Decision routing" row from the player
table. It can stay in `docs/design/README.md`.

## Proposed structure changes

The main problem is structure: the README serves three readers (players,
contributors, the project's own status tracking) and the status tracking
has taken over. Proposed outline (target about 150–200 lines):

1. **Header**: crest, one-line pitch, Play in browser · Install · Discord
   (keep as is), "in active development, expect world resets".
2. **What you can play today**: the current bullets, plus housing
   (RDM-05), flying mounts (RDM-06) and bosses (RDM-09); a small
   faction/people/capital table (RDM-08); the story paragraph.
3. **Getting started (new)**: character creation, `I` → **Help** tab,
   skills to hotbar and left click, quest symbols, go to your capital at
   about level 10, Return home, death is free, sound commands (RDM-04,
   RDM-10).
4. **Current state (short)**: 5–8 lines and a link to `docs/STATUS.md`
   (RDM-02, RDM-03); "Not yet in the game: scripted war-front battles,
   the underworld (a later expansion)".
5. **What's ahead**: keep.
6. **Play with Luanti**: browser link; install; **keep the New World
   mapgen options at their defaults** (RDM-01); the first-start wait
   (RDM-07); the tested engine version (RDM-13); a short "Hosting a
   server" note (RDM-15); the development setup in `<details>` (keep).
7. **Feedback and contributions**: keep, with a fixed version request
   (RDM-14).
8. **The person behind it / Built on community work / Support**: keep.
9. **Explore the design**: keep the table without the "Decision routing"
   row (RDM-19).
10. **License**: keep.

## Open questions for Jan

1. **RDM-01 code fix:** should `game.conf` get
   `disallowed_mapgen_settings = mg_flags, mgv7_spflags, chunksize, water_level, mapgen_limit`
   (and maybe `seed` stays allowed) so the New World dialog cannot
   produce a world that refuses to load? That is a code change outside
   this lane. The README warning is the doc-side fallback.
2. **Where does the round history go?** Into `docs/STATUS.md` (which
   already has most of it) or into a new player-facing `CHANGELOG.md`?
3. **Game version:** add a visible version (Help → About, game.conf), or
   ask bug reporters for date/commit instead?
4. **Naming the peoples in the README (RDM-08):** the six peoples are
   registered as Human, Dwarf, Elf / Orc, Troll, Undead, and a code
   comment says "own flavor names come later (no 1:1 copies)"
   (`grug_classes/init.lua:167`). Do you want the README to list them
   under these generic names now, or wait for the flavour names? Related,
   outside this lane: `ROADMAP.md:349` plans "Paladin, Rogue, Warlock and
   Shaman". These are generic fantasy terms, but as a set they match one
   well-known MMO's class roster. Flagging this only because of the
   no-WoW rule; your call whether it matters.
5. **Should the README describe PvP-relevant NPCs?** Kings, Generals and
   guards attack enemy players regardless of flag (pvp.md:93-95). That is
   useful for players to know, but it may be more than the pitch needs.
