# Round 34 — Sound: round plan

Coordinator: Claude (Opus 5.5), planned 2026-10-04. Status: **approved by the
user (2026-10-04).**

Sound is part of V1 (user, 2026-10-03). The game is almost silent today: 94
files, all from minetest_game, mobs_redo and two food/drink cues
([sound research](../research/sound-research-2026-10.md), Round 32 R2). This
round adds effects at the central hooks, mob voices, ambience per region and
calm music, following the user's seven decisions (§2.1) and the user's picks
from two listening pages (§2.2). Routing as before: Claude orchestrates, Opus
implements and reviews (independent review per code lane). GPT-6 Astra has
no task this round (no art, no quest text).

Starts after Round 33 is complete; WP9 follows as a round of its own. Not in
this round: a weather system (§2.1 ruling 7), voiced NPC lines, footstep
replacement, a client-side music channel (the engine has none).

## 1. Lanes and waves

| Lane | Wave | Kind | Content |
|---|---|---|---|
| **S1a** Effects: play helper and events | 1 | code + media | new mod `grug_sounds`: play helper and event table; formspec click style; NPC, quest, progression, UI, crafting, travel, mount and world events; the Round 33 hooks (§4.1) |
| **S2** Ambience and music | 1 | code + media | new mod `grug_ambience`: per-player ambience beds and sparse calls on the existing per-player tick, music pools with on-demand delivery, music and ambience volume per player (§4.2) |
| **S1b** Combat and creatures | 2 | code + media | weapon and ability sounds, mob voices by archetype, bosses and dragons, the telegraph growl (§4.3) — uses S1a's helper |
| **F1** Mobs in water | 1 | code | mobs follow their target through water in combat; ambient roaming still avoids water (§2.3, §4.5) |
| **F2** Small fixes and the Bag of Coins | 1 | code | text boxes at the trainer and in the crafting UI, cooking recipe balance, money withdraw and deposit with a Bag of Coins (§2.3, §4.6) |
| **D** Documentation and credits | 3 | docs | completion, design doc `docs/design/sound.md`, top-level `CREDITS.md`, BACKLOG/ROADMAP/STATUS/README (§4.4) |

S1a, S2, F1 and F2 start together; F1 and F2 are small and merge first
(§7). S1b starts after S1a is
merged **and** the user's listening review of S1a, so the helper, the gain
conventions and the naming are settled before the largest file set lands. D
last.

**Approval gate (user ruling, 2026-10-04): no sound enters the game unless
the user approved that exact file on a listening page.** "Sometimes no sound
is better than a bad sound." So:

- Every sound the user picked on the two earlier pages (§2.2) is an
  approved **recording**. Its final cut goes on the lane's page once more
  for a quick confirmation: the 30 s bed loops (the pages played 16 s
  excerpts), and the trims the user asked for (C2.1 at 2 s, C5.2 without
  its first 0.3–0.5 s, B.6 first 5 s, the rebuilt C13.1 forge loop). A short
  effect used exactly as heard needs no second look.
- A lane proposes everything else on its own German preview page
  (`~/projects/grudgelands-orchestration/r34/previews/<lane>/index.html`):
  per event 2–4 candidates in the final cut (mono Ogg rendered as MP3 for
  listening), numbered, with source and licence. The coordinator publishes
  it as a private artifact and records the user's picks in
  `~/projects/grudgelands-orchestration/r34/approved/<lane>.txt` (one line
  per shipped file: file name, page number, source); the lane copies it to
  `tools/r34_<lane>/approved.txt`.
- The lane ships only files on that list, and its fixture fails on any
  `.ogg` in its mod that the list does not name. **An event without an approved
  file stays silent**: its hook is either not added or added without a
  sound name, never with a placeholder. A changed cut (shorter, trimmed,
  re-looped) is a new file and needs a new approval.
- Code may be built while the page waits; files land in the branch only
  after the picks. A second page in the same lane covers what the user
  rejected (or the event stays silent; the user may say so directly).
- After the merge the user listens in the game (GUI check): gains and
  pacing are tuned then; swapping a file again goes through a page.

## 2. User rulings

### 2.1 The seven decisions (2026-10-04, all as recommended)

1. **Effect sources:** CC0 packs first (Kenney, OpenGameArt by rubberduck,
   artisticdude, Ogrebane; Freesound CC0), CC BY where clearly better (e.g.
   the Little Robot Sound Factory dragon growl and fanfare), plus own
   generated UI and jingle cues where nothing fits (generator output, CC0,
   like the project's textures). The p0ss spell pack (CC BY-SA 3.0 / GPL)
   only where a cue has no other source. *Why:* best sound at the lowest
   licence cost; CC BY needs only a credit line, which the music needs anyway.
2. **NPC dialogs: neutral cues per role** (book for quest givers, coins for
   vendors, a short cue for trainers and other services). No voiced lines:
   there is no good free source. *Why:* cheap, licence-clean, no uncanny
   half-voicing.
3. **Music: pools per region group**, chosen by the atmosphere mood the
   player already carries: **Land** (the six race regions), **Front and sea**
   (Battlegrounds, dragon islands, open ocean), **Underground**, plus a
   **Town** pool for start towns and capitals (§2.2). A track may sit in
   several pools. A running track is never cut on a group change; the next
   one comes from the new pool. One track, then a random 3–8 minute pause;
   the first track 30–90 s after joining. No switch in combat (user, Round
   32). *Why:* the mood key exists already, so pools cost one table.
4. **Tracks:** M1 *Memories Of Stone* (Scott Buckley, CC BY 4.0), M2
   *Achaidh Cheide* (Kevin MacLeod, CC BY 4.0; the user hears it as tavern
   music, so it also goes to the Town pool), M4 *Soliloquy* (Matthew Pablo, CC
   BY 3.0), M6 *Fantasy Orchestral Theme* (joth, CC0) are set; M3 *Forest
   Walk* (Alexander Nakarada, CC BY 4.0) is possible (front); M5 is out. The
   Town pool takes D.1–D.7 of the Round 34 page (§2.2) and M2. S2 proposes
   2–4 more on its preview page where a pool is thin (Front and sea,
   Underground). Optional: one main-menu theme (`menu/theme.ogg`, engine
   feature).
5. **Music delivery: on demand.** Music files stay out of every `sounds/`
   folder and are pushed per player with `core.dynamic_add_media` after
   joining, one track at a time during the pause before it plays, only to
   players with music on. **Music is on by default.** *Why:* the first join
   stays as fast as today (13.8 MB of media; music would add 15–25 MB), and
   a player who turns music off never downloads it. If the engine test or
   the web build shows a blocker, S2 falls back to shipping the tracks and
   reports (§4.2).
6. **Ambience: quiet beds per region plus sparse calls**, night variants,
   water near the player and underwater, and towns. Volume and an off switch
   per player. *Why:* the user wants atmosphere, and the mood key maps well
   to landscapes (dwarf → mountains and snow, troll → jungle, orc → desert
   and mesa, undead → blight).
7. **Weather: not in V1.** Distant thunder plays as a rare ambience call on
   the dragon islands and the front, without a weather system. A small
   weather system (sky, particles within the web budget, rain bed) goes to
   the BACKLOG as an optional package (D writes the entry).

Defaults stated by the coordinator without objection: the music and
ambience volume sit in a small "Sound" block on an existing page, plus
`/music` and `/ambience` chat commands; the minetest_game footsteps stay
(the user: "they are good").

### 2.2 Picks from the listening pages

From the Round 32 page ([artifact](https://claude.ai/artifact/4Bi1SAvtuMxdQwn4R8XT7g),
numbers as on the page; 2026-10-04):

- **Use:** 1.1 book open (quest giver dialog), 1.2 page flip (quest text),
  1.3 coins (vendor buy/sell); 2.1 the Little Robot fanfare (level-up); 3.1
  swing, 3.3 blunt hit, 3.4 block/shield, 3.5 today's `mobs_punch` (stays);
  4.1 Kenney button click, 4.6 cloth (equip); 5.1 hammer on anvil (with the
  pauses cut), 5.2 mining, 5.4 wood chop; 6.1 gallop, 6.2 wing beats, 6.3
  splash (boats **and fishing**); 8.1 forest by day, 8.4 lake at night (for
  the undead region, "graveyard flair"), 8.5 desert wind (desert **and** ice
  desert), 8.6 mountain wind and birds (too much background noise — only if
  nothing better), 8.7 cave drips, 8.8 underwater; 8.3 fits a creepy cave
  better than the jungle; 9.4 distant thunder (start at the clap); 10.2
  smithy and 10.3 fire (at forges and hearths/ovens); 11.1 dragon roar, 11.2
  dragon growl; 11.3 giant voice for an ogre or giant taking damage; 11.5
  lightning only if nothing more punchy is found.
- **Not used:** 1.4–1.6 and 2.2–2.3 (jingles), 3.2, 3.6–3.10, 4.2–4.5, 5.3,
  9.1–9.3, 10.1 market crowd ("disturbing" — capitals get music instead),
  11.4 telegraph roar.
- **Music:** all six liked; the in-game effect is the real test.

From the Round 34 page ([artifact](https://claude.ai/artifact/Co1PWHqx3SJPAmZAMxpSur),
2026-10-04; sources and cut points in `r34/listen/clips.json`):

- **Ambience beds** (by atmosphere mood):
  - human: A1.1 (good), A1.3 (slight hiss)
  - elf: A2.2, A2.3 (also fits jungle or wooded steppe), 8.1
  - troll: A3.1, A3.4 (rainforest with rain), A2.3
  - orc: A4.1, 8.5, A4.3 (wind only); A3.3 is steppe
  - dwarf: A5.3 (sharp, gusty wind), A5.4 (light rain), 8.5 (ice desert)
  - undead: A6.1 (dark, windy, eerie), A6.2 (eerie swamp, clear water), 8.4
  - Battlegrounds: A7.1 (quiet background), A7.2 (wind only)
  - dragon islands: A8.2, A8.3
  - underground: A9.1 ("dark dungeon", drips on stone — very good), 8.7;
    A4.4 sounds like a crystal cave (deep underground); A6.3 a dark cave at
    a forest edge
  - night (over every region): A10.1 (crickets and owl), A10.2, A10.3
  - sea and coast: A11.2 (best), A11.3
  - streams and rivers: A12.1, A12.2 (also a small waterfall)
  - underwater: 8.8
  - dark forest: A9.3 (= 8.3)
- **Not used:** A1.2, A2.4 (rain), A1.4 (cars), A2.1, A3.2, A5.1, A5.2,
  A8.1 (hiss, microphone wind), A4.2, A6.4 (frogs — the game has none),
  A7.3 (close, fluttering fire), A9.2 (monster noises), A11.1 (too loud),
  A11.4.
- **Calls:** owl B.1; crows B.3 (great) and B.4 (crows at dusk); wolf B.6
  (only the first 5 s); hawk B.8 (very good); distant thunder C11.1–C11.4
  (all good).
- **Effects:**
  - quest accept C1.3; quest complete C2.1 cut to its first 2 s
  - **no refusal or error cue** (the user: not needed; C3 all rejected)
  - fire: C4.1 fireball, C4.2 fire beam, C4.3 big fireball (long, mighty)
  - frost: C5.2 without its first 0.3–0.5 s (the spreading frost wave),
    C5.1; C5.4 for the frost dragon's breaking ice
  - shield spell C6.2, heal C6.3
  - mob hurt: C7.1 humanoids and zombies; C7.3 mid-sized strange creatures
    (ghosts, wisps, the underground lava monsters)
  - mob death: C8.1 and C8.4 a ghost vanishing, C8.2 a mummy
  - voices: C9.2 ogres, trolls and the Land Guard; C9.3 wolf or hyena attack, C9.5
    wolf or hyena death; C9.4 (dragon growl 2) good but long
  - arena lightning C10.1, C10.2
  - cooking C12.1, C12.2; alchemy C12.4 (top), C12.1
  - forge: C13.1's first two blows are good, but blows 3 and 4 run together
    (rebuild an evenly spaced loop from the good blows); C13.2 one blow for
    repair; C13.3
- **Not used:** C1.1, C1.2, C1.4, C2.2–C2.4, C3, C4.4, C5.3, C6.1, C6.4,
  C7.2, C8.3 (a whetstone, not a death), C9.1, C10.3, C10.4, C12.3.
- **Town music:** D.1–D.7 all very good (D.6 *Teller of the Tales* is the
  one melancholic piece).

**What the picks teach about sources** (rules for the lanes): no rain,
traffic, microphone wind or steady hiss under a bed; no animals the game
does not have (frogs); no monster voices inside an ambience bed; effects
short and focused, with the cut starting at the event itself.

### 2.3 Fixes and the Bag of Coins (user, 2026-10-04, after Round 33)

1. **Mobs in water.** Today mobs_redo treats water as unsafe ground even in
   combat (`ENTITIES/mobs/api.lua` ~1070), so a mob at a water edge that only
   needs a sidestep stops and never moves again. Ruling: **every mob that does
   not fly can swim; mobs do not roam into water, but in combat they follow
   their target into water and cross it to reach it.** Preferring a faster
   land route is welcome where it is cheap, not required (mobs move straight
   at their target; there is no route search). Lava and other damaging
   liquids stay forbidden.
2. **Text boxes too low:** the trainer dialog's "Known: Cooking" box and the
   crafting UI's "Start with Basics …" text show a scrollbar although the
   dialog has room — the same fault the quest tab had before Round 32.
3. **Cooking balance:** within a tier, a stronger dish must cost more to make,
   never less (today Sweetroot Mash is far cheaper than Hearty Stew and
   stronger).
4. **Bag of Coins** (BACKLOG "Money withdraw and deposit"): withdraw on the
   Character page through a small dialog (gold, silver, copper) into a Bag of
   Coins item; a deposit slot destroys the bag and credits its amount;
   traders neither buy nor sell it; it can be dropped or stored, so players
   can give money to each other. No log line; no longer ground lifetime.

## 3. Shared conventions (both wave-1 lanes and S1b)

- **Format:** Ogg Vorbis. Positional sounds and every effect mono
  (`ffmpeg -ac 1 -c:a libvorbis -q:a 3`); music stereo at q0–q1
  (`doc/lua_api.md:1323-1326`: only mono plays positionally). Beds about
  30 s, loop-clean (crossfaded ends). Trim silence at the start.
- **Names:** `grug_sounds_<event>[.<n>]` and `grug_ambience_<mood>_<what>`
  (`.1`, `.2` … variants are picked at random by the engine). Music
  `grug_music_<slug>.ogg` in `grug_ambience/music/` (not `sounds/`).
- **Loudness:** one reference for all lanes, the one the user judged the
  listening pages at: effects peak-normalised to −3 dBFS, beds −20 LUFS,
  music −18 LUFS integrated. Gains in the code then mean the same thing
  across lanes; the in-game balance is tuned in the GUI check.
- **Licence:** one `LICENSE-media.md` row per file (file, title, author,
  source URL, exact licence and version, modifications such as "converted to
  mono Ogg, trimmed, loop crossfade"); licence verified on the source page
  per file; no NC/ND, no Pixabay, no BBC, no Sonniss, no Freesound file with
  a GenAI tag, no TenPlus1 ambience file (its code is a reference only).
  Generator output: the script lives in `tools/r34_<lane>/`, the row says
  "Grudgelands generator, CC0 1.0".
- **Network:** one-shots are ephemeral (`core.sound_play(spec, params,
  true)`); positional with a `max_hear_distance` that fits the event;
  frequent events (hits, ability ticks) never more than once per target per
  short interval. Mob hearing stays off (`minetest.conf:78`).
- **Size:** effects and ambience ship normally; together they should stay
  in the low single-digit megabytes (study: about 2 MB effects, 3 MB beds).
  Reported, not gated.

## 4. Lanes (goals; the briefs add file facts)

### 4.1 S1a Effects: play helper and events (wave 1)

- **New mod `mods/CORE/grug_sounds`** with all new effect files, its
  `LICENSE-media.md`, and one global `grug_sounds` with a small play helper:
  an event name maps to a sound spec (name, gain, pitch spread, distance,
  positional or `to_player`); a call site is one line. Hooked mods add
  `grug_sounds` to their dependencies. No refusal or error cue (user,
  §2.2): refusals stay silent.
- **Formspec clicks:** one `style_type[button,image_button,…;sound=…]` for
  every formspec (the prepend is set in vendored `BASE/default/init.lua`,
  so a `-- GRUG PATCH` with a `VENDOR.md` note, or a grug mod that extends
  the prepend after `default` — the lane picks the cheaper one). Check that
  local `style_type` lines in our formspecs do not drop the sound.
- **Events** (the study's table §3, re-checked on main; Round 33 additions
  at the end): quest-giver dialog and quest text; vendor open, buy, sell;
  trainer and other villager services; quest accept,
  abandon, turn-in, objective progress; level-up (fanfare); profession
  learned and tier-up; talent learned; craft finished; repair; money
  gained; equip; mount summon and dismount
  plus gallop, wing beats and boat movement; travel (waystone, hearth,
  home); zone banner (soft, rare); PvP flag on/off; respawn; fishing cast and
  catch (the splash, user).
- **Round 33 hooks** (names only; R33 is merged before this round starts —
  find each function on main): achievement unlocked (the feed announcement
  in `grug_achievements`), cloak chosen (Character page picker), enchant
  applied, profession upgrade, the crown applied at the Crownbinder, culture
  vendor purchase (if it does not already pass through the vendor buy path),
  drinking the fixed potions T1–T6 (the existing drink cue, check every
  potion path reaches it), a blue or gold drop and a boss double drop, a bag
  world drop.
- **Fixture:** the helper's event table (every event names an existing
  file; every shipped `grug_sounds_*` file is used or listed as a variant),
  `tools/r34_s1a/portable_test.lua`.

### 4.2 S2 Ambience and music (wave 1)

- **New mod `mods/CORE/grug_ambience`**: beds, calls and music with their
  `LICENSE-media.md`; per-player state; the settings.
- **Driver:** the player's mood from `grug_core.get_atmosphere(name)`
  (`atmosphere.lua:271`, applied by the existing 8-slot × 0.25 s per-player
  pass, `atmosphere_zones.lua:515-552`), day or night from the world clock
  (`grug_core.is_day_phase`, `atmosphere.lua:74`), whether the player is in
  a start town or capital (the location resolver in
  `grug_map/location.lua:62-82`; add a small seam rather than a second
  resolver), water and underwater from one cheap probe. Own per-player
  slots (no pass handles every player in one step, AGENTS.md Round 32).
- **Beds:** one looped `to_player` bed per state with a crossfade through
  `core.sound_fade` on change; night variants; water near the player and
  underwater override the region bed; in towns a quiet bed or none, the
  Town music pool carries the mood (user: music instead of market noise).
- **Smithy and fire** (10.2, 10.3, the forge loop): positional sounds at
  forges and hearths in settlements, through the cheapest trigger — an
  existing node timer, or one small nearby-node check in S2's own
  per-player slot (measured before and after).
- **Calls:** sparse one-shots per region (owl at night, crows over the
  undead, birds of prey in the mountains, distant thunder on dragon islands
  and the front), a per-player timer, never more often than every few
  seconds and mostly minutes apart.
- **Music:** the pools of §2.1 ruling 3 with the tracks of ruling 4 and
  §2.2; scheduler as in ruling 3 (VoxeLibre's `mcl_music` is the reference
  for gain changes and pacing, `reference_projects/VoxeLibre/mods/PLAYER/mcl_music/init.lua`);
  delivery by `core.dynamic_add_media{filepath=…, to_player=…,
  ephemeral=false, client_cache=true}` with playback in its callback
  (`doc/lua_api.md`, `dynamic_add_media`: not persisted across restarts, a
  file may be sent to several players, remote media applies). A headless
  run has no client to receive a pushed file, so S2 proves the server side
  (push, callback handling, scheduler) in its fixture and a smoke boot; the
  user's GUI check on desktop and in the web build is the real test.
  Fallback if delivery fails there: ship the tracks in `sounds/` (ruling 5's
  option a) and report.
- **Settings:** music and ambience volume (0–100 %) and on/off per player in
  player meta, applied at once with `core.sound_fade`; a small "Sound" block
  on an existing page (the Help page `grug_inventory/help.lua` or the
  Character page — the lane picks the one with room) and `/music`,
  `/ambience` commands.
- **Tracks:** the set tracks, the seven town pieces, plus 2–4 proposals
  for the thin pools (Scott Buckley, incompetech, Alexander Nakarada,
  OpenGameArt) on the preview page; trim to the calm part where CC BY allows
  it (modification noted).
- **Fixture:** scheduler and pools (no cut on a group change, the pause
  range, first-track delay, music off stops pushes), bed selection by
  state, `tools/r34_s2/portable_test.lua`. Before/after numbers of the
  per-player pass with stand-ins (the Round 30/32 probe).

### 4.3 S1b Combat and creatures (wave 2)

- **Combat:** swing into the air (item `sound.punch_use_air`), hit by
  weapon kind (blade, blunt; `mobs_punch` stays for fists), block, crit,
  dodge; player death and respawn (death_messages hook).
- **Abilities:** a cast and an impact per ability theme for the 21
  registrations (picked: C4.1–C4.3 fire, C5.1/C5.2 frost, C6.2 shield, C6.3
  heal; the other themes are S1b proposals), at
  `grug_abilities.try_cast` and `grug_core.deal_ability_damage`; projectile
  launch and impact at `grug_projectiles.spawn` / `settle_hit`.
- **Mob voices by archetype** (beast, canine, feline, boar, insect, slime,
  undead, humanoid, ogre/giant, bird, reptile, aquatic, dragon): a `sounds`
  table set at registration by family (random, war cry, damage, death,
  distance); the 89 `grug_mobs` registrations share them. **The panther
  keeps no war cry** (`grug_mobs/panther.lua:7-13`). The user's picks
  (§2.2) seed the families: 11.3 ogre and giant damage, C9.2 ogre, troll and
  Land Guard (`grug_mobs/land_guard.lua`) voices, C9.3 and C9.5 wolf and hyena attack and death, C7.1
  humanoid and zombie hurt, C7.3 ghosts, wisps and lava creatures, C8.1/C8.4
  ghost death, C8.2 mummy death. The other families (bear, boar, feline,
  insect, slime, bird, reptile, aquatic, critters) have no pick yet: S1b
  proposes them on its preview page.
- **Bosses:** dragon roar and growl (11.1, 11.2), breath, wrath, enrage,
  arena lightning C10.1/C10.2, the frost dragon's breaking ice C5.4,
  Kraken, Kings; the **telegraph wind-up growl** at
  `grug_mobs/telegraph.lua` (the TODO there; C9.4 cut to the 2 s wind-up or
  the family's own war cry, S1b proposes).
- **Fixture:** every mob family has a sound table, the panther has no
  `war_cry`, every referenced file exists; `tools/r34_s1b/portable_test.lua`.
- Fix the dangling `tnt_explode` fallback only if a mob can reach it
  (today none can; note, not a task).

### 4.5 F1 Mobs in water (wave 1)

- In combat states (attack, follow a target, flee and return home) liquid
  that does not hurt the mob counts as passable for every mob that floats and
  does not fly; ambient stand/walk keeps avoiding water. One small GRUG PATCH
  in the vendored probe with a `VENDOR.md` note, or a grug-side override —
  the cheaper one.
- Check the neighbours: the leash and soft de-aggro, evaders that park at
  obstacles (`grug_mobs/aggro.lua` ~342), swimmers and the Kraken
  (`_grug_swimmer`), mounts, guards and bosses (arenas), mobs that must not
  leave their zone. A mob swimming home after combat must reach land.
- Fixture for the probe rule per state; one engine run at a real water edge
  (a small region, ≤ 5 min) with a probe that pulls a mob across a stream.
  Report before/after per-step cost of the probe.

### 4.6 F2 Small fixes and the Bag of Coins (wave 1)

- Text boxes: size the trainer's "Known" box and the crafting UI's Basics
  text to their content where the dialog has room (the quest tab fix of
  Round 32 is the pattern).
- Cooking: a cost-versus-effect table per tier; raise or swap inputs so the
  stronger dish costs more; the report shows the table before and after.
- Bag of Coins as §2.3 ruling 4: one transaction for withdraw
  (`grug_money.take_with_inventory`), refused when the inventory is full or
  the amount is not a whole number between 1 and the balance; the deposit
  clamps at `grug_money.MAX` (refuse above); the amount lives in item meta,
  `stack_max = 1`, the tooltip shows it; the sell path refuses the bag.
  Fixture for withdraw, deposit, refusals and the sell refusal.
- The user's GUI-test findings of Round 33 may add small items here.

### 4.4 D Documentation and credits (wave 3)

`docs/design/sound.md` (events, pools, beds, settings, conventions of §3),
top-level `CREDITS.md` (every CC BY and CC BY-SA author of the new sounds and
music in the authors' own attribution wording, plus one line per vendored
upstream project from VENDOR.md; AGENTS.md "Licenses" foresees it), the
module guide sections for `grug_sounds` and `grug_ambience`, the weather
package as an optional BACKLOG entry, completion section here, BACKLOG,
ROADMAP, STATUS, README "Current State" and the AGENTS.md round summary.

## 5. Rules

As Round 33: AGENTS.md; `tools/check_lua.sh` (via bash) on every changed Lua
file; headless only through `LC_ALL=C chrt --idle 0 tools/luanti_headless.sh`,
never the user's Luanti folder; numbers are comparisons; fresh-server mode;
agents never push; no references to commercial games anywhere. Sound
sources only as §3 says, checked per file; an unclear licence means the file
is not used. Particle budgets are untouched (no new particles this round).

## 6. Verification

Each code lane: its fixture and the existing fixtures it touches
(`tools/run_fixtures.sh`), one engine smoke boot (no missing-sound
warnings for our names in the log), the preview page and the user's
picks before any file lands (§1 approval gate), an independent Opus review
that also checks every shipped sound file against
`tools/r34_<lane>/approved.txt` and the licence row. S2 also reports the
per-player pass before and after with stand-ins. End: one boot of main,
`tools/sync_to_luanti.sh`, the user's GUI check (desktop and web build:
clicks, a quest, a fight, a mount ride, one region bed per mood, music
starts after joining, volume and off switches, a town).

## 7. Orchestration notes (for the coordinator)

- **Start state:** main after Round 33 is complete (`46130d06` or later;
  this plan was written against `f135b29c`, before C4 and C5 merged). Worktrees
  `.claude/worktrees/r34-<lane>` (`s1a`, `s2`, `f1`, `f2`, `s1b`, `d`), `tools/bin/`
  copied. Briefs in `~/projects/grudgelands-orchestration/r34/` from
  `r33/common-brief.md` and `r33/review-common.md` (round number, worktree
  names, base commit, preview path, this plan; drop the Astra paragraph);
  `r33/engine_run.sh` copied with its lock path changed. Log in
  `r28/HANDOVER.md` under "ROUND 34".
- **Source material:** downloaded packs, Freesound previews and both
  listening pages' clip lists in
  `~/projects/grudgelands-orchestration/r32/r2-evidence/` (`dl/`,
  `clips.json`, `scripts/`) and `r34/listen/` (`dl/`, `info.json`,
  `clips.json`, `scripts/fs_search.py` with backoff — Freesound answers 429
  to parallel searches, so search serially). Freesound originals (WAV/FLAC)
  need a login; **the source is the HQ preview** (128 kbit MP3; CC0 allows
  it, mono Ogg hides the difference), noted in the licence row. The user has
  a Freesound account (2026-10-04) and may download originals by hand into
  `~/projects/grudgelands-orchestration/r34/originals/` (list of the 56
  picked recordings in its `README.md`); a lane takes the original where
  one is there. No Freesound credentials go to agents, briefs or the
  repository.
  Music needs no account: all set tracks and the town pieces are full-length
  files from the composers' own pages (Buckley, MacLeod 256–327 kbit/s;
  joth, Pablo, cynicmusic 108–199 kbit/s), already in `r32/r2-evidence/dl/music/`
  and `r34/listen/dl/`.
- **Code facts** (checked on `f135b29c`; verify, they are hints):
  - Quests: `Q.open_npc` `grug_quests/npc.lua:15`; `Q.accept`, `Q.abandon`,
    `Q.turn_in` `grug_quests/state.lua:261,283,402`; `post_progress`
    `grug_quests/hud.lua:106`.
  - Vendors: `grug_traders.open` `grug_traders/trade.lua:313`, `do_buy`
    `:388`, `do_sell` `:429`; villager service dispatch
    `grug_mobs/start_villagers.lua` (`on_rightclick`); refusal
    `grug_factions/service.lua` `refuse`.
  - Progression: level-up banner `grug_xp/init.lua:104` in `set_xp` (`:89`);
    `grug_jobs.learn` `grug_jobs/state.lua:57`, `record_craft` `:159`;
    `grug_classes.spend_talent` `grug_classes/talents.lua:1123`;
    `grug_repair.apply` `grug_repair/service.lua:75`; money
    `grug_money.add` `grug_money/init.lua:104`; equip
    `grug_core.notify_equipment_change` `grug_core/combat.lua:330`.
  - UI: formspec prepend `BASE/default/init.lua:27-39` (vendored, on join);
    `sfinv.set_page` `BASE/sfinv/api.lua:143`; `grug_core.flash`
    `grug_core/flash.lua:24`; feed `grug_core.feed` `grug_core/feed.lua:128`;
    Help page `grug_inventory/help.lua:206`, Character page
    `grug_inventory/pages.lua:399`; Map tab checkbox pattern
    `grug_map/page.lua:191`.
  - Round 33 on main: achievement announcement
    `grug_achievements/init.lua:67-73` (`announce` → `grug_core.feed`);
    cloak picker `grug_inventory/pages.lua:420-421`
    (`choose_cloak_by_name`). Enchant tiers, upgrades, the crown, vendors,
    culture vendor, Crownbinder and potions were in `r33-c4`/`r33-c5` at
    planning time.
  - Mounts: `dismount` `grug_mounts/entity.lua:162`, `land_step` `:358`,
    `flight_step` `:384`, `water_step` `:406`. Travel: `teleport`
    `grug_home/travel.lua:12`, `grug_home.respawn` `:243`. PvP flag
    `notify` `grug_pvp/init.lua:92`. Zone banner `display`
    `grug_map/location.lua:324`.
  - Combat: `grug_abilities.try_cast` `grug_abilities/init.lua:1445`;
    `grug_core.deal_ability_damage` `grug_core/combat.lua:1419`; player
    hpchange `:1762`; death `grug_core/death_messages.lua:145`;
    `grug_projectiles.spawn` `grug_projectiles/init.lua:255`, `settle_hit`
    `:319`; mobs_redo `mob_sound` `ENTITIES/mobs/api.lua:280`, hit sound
    `:3607-3609`, `tnt_explode` fallback `:4951`.
  - Bosses: `mobs_spell` warning `grug_mobs/bosses.lua:734`; arena ice
    `grug_mobs/boss_dragons.lua:319`; telegraph `start_windup`
    `grug_mobs/telegraph.lua:67` (TODO at about `:77`); panther
    `grug_mobs/panther.lua:7-13`.
  - Atmosphere: moods `dwarf human elf undead orc troll battlegrounds
    dragon_island ocean underground default`
    (`grug_core/atmosphere_zones.lua:173-345`); `mood_key_at` `:466` is
    local, but `grug_core.get_atmosphere(name)` (`atmosphere.lua:271`)
    returns the applied mood; a manual `/atmosphere` preset pauses the zone
    pass (`atmosphere_zones.lua:579`). Towns: `build_resolver`
    `grug_map/location.lua:62` (start towns and capitals, `kind == "town"`).
  - Existing sound calls to keep: drink `grug_alchemy/effects.lua:9`, eating
    `grug_food/init.lua`, furnace and chest sounds in `BASE/default`.
- **F1 and F2** merge first (small); S1a and S2 rebase. F2 touches
  `grug_money`, the Character page and the trainer/crafting formspecs, which
  S1a hooks for sounds (money gained, clicks) and S2 may use for its settings
  block.
- **Downloaded sound material is read-only** (user, 2026-10-04): lanes copy
  from `r32/r2-evidence/dl/`, `r34/listen/` and `r34/originals/` and never
  delete or move anything there.
- **Merge order:** S1a and S2 independent (different mods; both may touch
  `grug_inventory` only if S2 puts its settings block there and S1a hooks
  the cloak picker — S1a merges first, S2 rebases). S1b after S1a and the
  S1a listening review. D last. Smithy and fire sounds belong to S2 (its
  per-player slot), not to S1a.
- **Review extras** (for `review-common.md`): every shipped `.ogg` is on
  the lane's `approved.txt` and has a licence row with source URL; no event
  plays a file that is not shipped; one-shots ephemeral; the panther has no
  `war_cry`; the ambience and music pass allocates nothing per step beyond
  need and spreads players over slots; music off means no pushes.
- **Previews:** each lane writes its German page as in Round 33 (content
  only, data-URI audio, under about 10 MB, decisions first, numbered,
  informal "du"); the coordinator publishes and collects the picks.
- **End:** `tools/run_fixtures.sh` on main, sync, the user's GUI check; the
  user pushes.
