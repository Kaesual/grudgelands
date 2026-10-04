# Round 34 — Sound: round plan

Coordinator: Claude (Opus 5.5), planned 2026-10-04. Status: **complete
locally 2026-10-04** ([completion and GUI checklist](#completion-2026-10-04));
approved by the user 2026-10-04. The user's choices during the round
(§2.2a, the ruling-9 refinement in §2.3) win over the earlier sections;
the design as built is [sound.md](../design/sound.md).

Sound is part of V1 (user, 2026-10-03). The game is almost silent today: 94
files, all from minetest_game, mobs_redo and two food/drink cues
([sound research](../research/sound-research-2026-10.md), Round 32 R2). This
round adds effects at the central hooks, mob voices, ambience per region and
calm music, following the user's seven decisions (§2.1) and the user's picks
from two listening pages (§2.2), plus two small fix lanes from the user's
Round 33 findings (§2.3). Routing as before: Claude orchestrates, Opus
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
| **F1** Mobs in water | 1 | code | mobs follow their target through water in combat; ambient roaming still avoids water (§2.3, §4.5) |
| **F2** Small fixes and the Bag of Coins | 1 | code | text boxes at the trainer and in the crafting UI, cooking recipe balance, Bag of Coins, map markers for the capital services, damage-fit fractions, no gear from encounter adds, thin ice breaking behind the player (§2.3, §4.6) |
| **S1b** Combat and creatures | 2 | code + media | weapon and ability sounds, mob voices by archetype, bosses and dragons, the telegraph growl (§4.3) — uses S1a's helper |
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

### 2.2a Picks from the lane pages and the ambience pilot (user, 2026-10-04)

**Ambience is a pilot this round.** Listening to the final bed loops, the
user found many beds too present for a zone background. Rather than ship
all and remove them later, this round ships beds for **one zone only, the
humans**: B1.1 by day, B9.1 at night (B1.2 and B9.3 have too much hiss),
at a base gain clearly below the page level; the user judges the pilot in
the GUI check, and the other zones follow later with quieter recordings
("a soft surface, no single sounds in front"). S2's code stays
region-independent, so more zones are data plus a page. Other choices:

- **Pilot extended to all zones (user, same day, after hearing it in the
  game: "surprisingly good, maybe minimally quieter"):** every bed at gain
  0.2; elves B2.1, B2.3; trolls B2.2, B3.1; orcs B4.4; dwarves B4.2, B5.2;
  undead B6.1, B6.3; Battlegrounds B7.2; dragon islands B8.2; night (humans,
  elves, trolls, orcs) B9.1, B9.2; underground B10.1, B10.3, B10.4, B10.5
  (deep only); sea and coast B11.1. No stream bed (B12.2 stays the
  flowing-water loop), no underwater bed.
- **No ambient calls** (owl, crows, hawk, wolf): fewer layers, so the user
  can tell sounds apart in the game. The crow recording (B.3/B.4) becomes
  the **Carrion Crow's** voice in S1b (war cry or an occasional call while
  it fights). **Distant thunder** C11.1–C11.4 stays, as a rare sound on the
  dragon islands only.
- **Forge** E1.2 only (the rebuilt hammer loop), **fire/hearth** E2.1.
- **Flowing water** B12.2, positional at *flowing* water nodes only (water or
  river water that runs off somewhere), not at sources; S2 checks how often
  our worlds have flowing water and reports.
- **Music** as planned (§2.1 rulings 3–5).
- **Effects (S1a page):** E1.1 quest complete about 0.5 s shorter at the end
  (new cut, confirm), E2.1 smithy craft, E3.1 repair, E4.1 cooking (E4.2
  out), E5.1 alchemy, E6.1 gallop, E7.1 wing beats; one cue per villager
  role F1.1, F2.1, F3.1, F4.2, F5.1, F6.2; quest abandon G1.2; profession
  learned H1.3, profession tier H2.3; craft J1.3, upgrade J3.1, crown J4.3,
  cloak J5.3, money (Bag of Coins deposit) J6.2; travel L1.2; PvP L4.1
  **only on the Enable PvP button**.
- **Silent by choice:** quest progress, talent, achievement, enchant (may
  get a sound later), blue/gold/bag/boss drops, mount summon and dismount,
  respawn, zone banner, PvP off, and any automatic PvP flag change.
  Approved lists: `~/projects/grudgelands-orchestration/r34/approved/`.

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
5. **Map markers** for the Crownbinder and the Decor Merchant (map page and
   minimap, like the other capital services).
6. **Damage-fit reference with fractions:** `baseline_melee_total`
   (`grug_core/combat.lua` ~99–102) keeps the Strength/10 fraction like live
   damage since Round 33, so same-level damage returns to the fit (today about
   +1.6 % at level 60, up to +5 % at levels 2–9).
7. **No gear from encounter adds:** royal guards (already none in code; fix
   `items_crafting.md` §5.4, which promises them elite loot) and the dragons'
   whelps (`_grug_boss_summon`; today they roll gear and bags like ordinary
   mobs) drop no gear and no bag.
8. **Watch in the playtest, no change now:** the Scout's full damage set
   (+55 % / +82 % at item level 60 / 70). **Optional at the round's end:** a
   real-client performance test with several clients.
9. **Wyrmglass thin ice breaks behind the player** (user, 2026-10-04, after
   the push of Rounds 30–33). Today a node breaks only after a player stood
   1.5 s on the same node (`ICE_BREAK_TIME`, a per-player timer that resets
   when the player moves). New: **every thin-ice node a player steps on
   breaks, together with its four neighbours, 1 s later, always** — also
   when the player has already moved on. This makes the ice dangerous for
   the players behind and asks the group to coordinate. Each node keeps at
   most one pending break: walking over it again, or over a neighbour, never
   resets or postpones its timer (an earlier pending time wins). The refreeze
   after 20 s stays. *Refined by the user (2026-10-04):* each sample of the
   0.25 s hazard pass marks every thin-ice node in the 3×3×3 cube around the
   player's feet (instead of the node plus its four neighbours); a marked node
   breaks 1 s later. The wider mark covers the gap between two samples, so no
   path sampling is needed.

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
- Map markers for the Crownbinder and the Decor Merchant (ruling 5).
- The damage-fit reference keeps attribute fractions (ruling 6); re-run the
  fixtures that pin the fit and report the same-level damage before/after.
- Encounter adds drop nothing (ruling 7): whelps join the royal guards and
  bodyguards in the kill-loot hook's early return (`grug_quality`
  ~913–917); fixture case; `items_crafting.md` §5.4 corrected.
- Wyrmglass thin ice (ruling 9): a pending break per node (keyed by node
  position, server-wide, not per player); each 0.25 s sample marks every
  thin-ice node in the 3×3×3 cube around the player's feet, fired 1 s later;
  a node that already has a pending break keeps it. No path sampling (the
  cube covers the gap between samples). The break sound plays once per
  break, not once per node. `dragon_arena.lua`
  `ice_step` and its fixture case (`tools/r31_da2/portable_test.lua`)
  follow the new rule; `docs/design/world.md` (Wyrmglass hazards) updated.
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
warnings for our names in the log), and an independent Opus review. Sound
lanes also: the preview page and the user's picks before any file lands
(§1 approval gate), and the review checks every shipped sound file against
`tools/r34_<lane>/approved.txt` and the licence row. S2 also reports the
per-player pass before and after with stand-ins. End: one boot of main,
`tools/sync_to_luanti.sh`, the user's GUI check (desktop and web build:
clicks, a quest, a fight, a mount ride, one region bed per mood, music
starts after joining, volume and off switches, a town; a mob following
across a stream, the trainer and crafting text boxes, a Bag of Coins
withdrawn, dropped, picked up by a second player and deposited, the new map
markers, a run across Wyrmglass thin ice that breaks 1 s behind the runner in a 3×3 band).

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
  it, mono Ogg hides the difference), noted in the licence row. **Agents work
  only with the previews** (user, 2026-10-04); if a listening review shows a
  file needs its original, the user downloads it by hand into
  `~/projects/grudgelands-orchestration/r34/originals/` and the lane swaps it
  in. No Freesound credentials go to agents, briefs or the repository.
- **Freesound is rate-limited (HTTP 429) and slow.** Lanes first reuse what
  is already downloaded (`r32/r2-evidence/dl/`, `r34/listen/dl/`, their
  `clips.json`/`info.json`). New searches and downloads go through one shared
  lock, `~/projects/grudgelands-orchestration/r34/fs_run.sh` (one slot,
  `flock`, like `engine_run.sh`), with the backoff of
  `r34/listen/scripts/fs_search.py`; never two lanes against the API at once.
  Future multi-agent sound research runs serially, not in parallel.
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
    (`choose_cloak_by_name`). Enchant tiers, upgrades, the crown
    (`grug_items.crown_item`), vendors, the Decor Merchant, the Crownbinder
    (`grug_traders/crown.lua`) and potions I–VI merged after this plan was
    written (main `16c498b9`): find their functions on main and refresh all
    line numbers above when writing the briefs.
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
  block; F2's thin-ice change moves the break sound call that S1b later
  swaps (C5.4).
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

## Completion (2026-10-04)

Every lane below is merged on local main (last lane S1b, `b0d648f5`); not
pushed. Each code lane was independently reviewed by Opus once: F1 and F2
merged as reviewed (F2 then took the user's 3×3×3 refinement, checked by
the coordinator), S1a after three fixes, S2 and S1b with small fixes the
coordinator verified. Every shipped `.ogg` is on its lane's
`tools/r34_<lane>/approved.txt` with a licence row, and each sound lane's
fixture fails on an unlisted file. After each merge the coordinator ran the
portable fixtures (`tools/run_fixtures.sh`, **77 of 77** on `b0d648f5`,
re-run on this lane's branch), `check_fresh_server.py` and a smoke boot (no
missing-sound warning). No mapgen change: a world of Round 33 or later
serves the GUI test.

### Shipped, by lane

Numbers are each lane's own probe or fixture, same seed and method before
and after (comparisons, never targets). Sizes measured on `b0d648f5`.

- **F1 mobs in water** (merge `18802160`; [combat_stats.md](../design/combat_stats.md)
  §3, VENDOR.md "Round 34 F1"): a floating mob that does not fly wades in
  the attack state, while fleeing, on the evade run home and whenever it
  already swims; idle roaming keeps treating water as a drop; lava and every
  damaging liquid stay a boundary. A swimming mob facing a bank one node up
  hops onto it (`GRUG_CLIMB_RISE` 3 nodes/s); an idle mob in water swims home
  on the 1 Hz leash tick (`shore_check`). Four `GRUG PATCH` markers (120 in
  `mobs/api.lua`). Engine probe (seed 12345, a Wolf at two real stream
  crossings): ambient roaming 0 of 74 samples in water at both; the chase
  enters the water after 0.8–1.4 s, crosses in 4.7–5.2 s and reaches its
  target; the evade run ends on land after 12.6–18.4 s, a mob stranded in
  water stands on land after 8.3–11.8 s; the cliff probe costs 4.45 µs and
  the leash tick 2.10 µs per call. Fixture 93 checks.
- **F2 small fixes and the Bag of Coins** (merge `217590b2`, refinement
  `b9ceea6a`, `0522c99b`; [economy.md](../design/economy.md) §1,
  [world.md](../design/world.md) Wyrmglass,
  [items_crafting.md](../design/items_crafting.md) §5): the trainer's text
  box is three lines high, the crafting Basics hint five, neither scrolls.
  **Cooking:** each tier's Caster dish now costs more input (vendor value)
  than its Hearty and Hunter dishes — T1 Sweetroot Mash 2c → 4c (Hearty Stew
  3c), T2 Berry Preserve 3c → 7c (Pumpkin Stew 5c), T4 Marshbloom Chowder
  17c → 33c (Marsh Roast 23c), T5 Stormkelp Broth 42c → 121c (Kelp-Wrapped
  Roast 81c); T3 (12c over 8c) and T6 (240c over 142c) already held.
  **Damage fit:** `baseline_melee_total` keeps Strength/10 unfloored, so a
  same-level fight meets the pool again (before: up to +15 % at level 4,
  +1.6 % at level 60). **Bag of Coins** (`grug_money/coins.lua`): Withdraw on
  the Character page (gold, silver, copper; one transaction; refused for a
  non-whole amount, more than the balance or a full inventory), a deposit
  slot that destroys the bag and credits it (refused above
  `grug_money.MAX`), traders pay nothing for it. **Map markers** for the
  Crownbinder and the Decor Merchant (kind `service`). **Encounter adds**
  (royal guards, bodyguards, dragon whelps, a King's raiders) drop no gear
  and no bag. **Wyrmglass thin ice:** each 0.25 s sample marks the thin ice
  in the 3 × 3 × 3 cube around the feet, which breaks 1 s later, never reset
  or postponed. Fixture 104 checks.
- **S1a effects** (merge `d1e93752`, `fa2af74e`; [sound.md](../design/sound.md)
  §3): `mods/CORE/grug_sounds` with `grug_sounds.play(event, target)`, the
  hook list and the formspec click; NPC role cues, quest text, abandon and
  complete, buy, sell, money, level-up, profession learned and tier, crafts
  by kind (also on taking a dish or potion out of a furnace or brewing
  stand), upgrade, crown, repair, equip, cloak, potions, gallop, wing beats,
  boat, travel, fishing and the Enable PvP button; 30 files. Fixture 1410
  checks.
- **S2 ambience and music** (merges `2dc2e726`, `1b668339`;
  [sound.md](../design/sound.md) §4–§6): `mods/CORE/grug_ambience` with the
  eight-slot per-player pass, beds by mood, night, depth, sea and town,
  dragon-island thunder, forge, fire and flowing-water loops, music pools
  pushed on demand, the main-menu theme, the Help page's Sound sub-page and
  `/music`, `/ambience`; `grug_map.location.in_town`. 19 beds, 3 loops and 4
  thunder variants (26 files) in `sounds/`, 16 tracks in `music/`, plus
  `menu/theme.ogg`. **Pass cost** (40 stand-ins at the human start, seed
  12345, the human pilot): ambience 512 µs/s, 23.3 µs per evaluation of
  which the node search is 18.4 µs; the atmosphere, location and ambience
  passes together 684 → 1245 µs/s (the town flag adds to the location
  sample). The all-zones beds were not re-measured. **Flowing water** is
  rare: 374 flowing nodes in twelve sampled regions, 6 of 768 16 × 16
  columns (0.8 %); the node search and choice at a river bank 128 → 48 µs.
  Fixture 266 checks.
- **S1b combat and creatures** (merge `b0d648f5`; [sound.md](../design/sound.md)
  §3.2–§3.5, VENDOR.md "Round 34 S1b"): the swing into the air, hits by
  weapon kind on mobs and players, block, dodge, player death; one cue per
  ability theme (`grug_abilities.CAST_SOUNDS`), projectile launch and hit;
  22 voice families (`grug_mobs/voices.lua`, `_grug_voice` on every mob)
  through two `GRUG PATCH` call-outs (122 in `mobs/api.lua`); dragon breath,
  lightning, enrage, wrath and wind-up, the breaking ice, the kings' and
  Generals' signature attack; 88 files. Fixture 1029 checks.
- **D:** [sound.md](../design/sound.md), [CREDITS.md](../../CREDITS.md),
  this section, the status files, the module guide and AGENTS.

**Sizes.** `grug_sounds`: 118 files, 1.49 MB; `grug_ambience/sounds`: 26
files, 5.23 MB; together the shipped sounds 94 files / 1.33 MB → 238 files
/ 8.04 MB. **First-join media** (every file under the mods' `textures`,
`sounds`, `models` and `locale`): 14.10 → 20.82 MB. Music, 16 tracks in
`grug_ambience/music` (30.03 MB), never joins the first download; each
track is pushed to one player while music is on. `menu/theme.ogg`: 1.52 MB.

### Late additions (after Lane D)

- **F3 — rivers never cover a POI core** (user: fix now, option B). About
  1 % of random seeds failed at load since at least Round 29 ("planner
  anchor tuple differs at 29": a wide river was detoured around each POI
  separately and ended over a close neighbour). `water_layout.lua` now joins
  POI cores whose clearances overlap or leave less than `POI_PAD` into one
  obstacle and detours round both; a tributary junction that would cross a
  core moves only within that core's clearance arc, else bends round it; a
  guard (`wet_core`) stops a build with a named error if a core is still
  wet. Fleet of 504 seeds: main 4 load failures plus 35 seeds with water on
  a core; branch 0 and 0 (minimum margin 5.2 after the review fix); 69
  seeds' rivers changed, seed 12345 byte-identical; water build 0.840 s vs
  0.841 s. Review found unbounded junction moves (1.5–1.8 km straight
  canyons on 2 seeds), fixed before the merge (longest junction stretch
  114 nodes; main 110). Fixture `tools/r34_f3`.
- **Seed fleet** (user: the map keeps fixed POIs; robustness from testing):
  `tools/seed_fleet/run.sh quick` (100 seeds, about 4 min) before merging
  any world-generation change, `full` (303 seeds, about 13 min) at the end
  of every round that changed world generation; rule in AGENTS.md.
- **Wisp blink** never lands in a liquid (a player saw a Wisp under water:
  its blink treated water as open, and a Wisp has no collision and takes
  no water damage). Fixture `tools/r34_wisp`.

### The user's choices during the round

1. **Thin ice** marks the 3 × 3 × 3 cube around the feet each sample, no
   path sampling (§2.3 ruling 9).
2. **A King's skeleton raiders** drop no gear either (F2's call, accepted).
3. **Cooking ranking:** the Caster dish is the strongest of a tier, Hearty
   and Hunter count as equal.
4. **Ambience:** a pilot with the human beds, then every zone after hearing
   it ("surprisingly good, maybe minimally quieter"), all beds at gain 0.2;
   no stream and no underwater bed.
5. **No ambient calls** but distant thunder on the dragon islands; the crow
   recording becomes the **Carrion Crow's** voice.
6. **Quest accept is silent**, and so are quest progress, talent,
   achievement, enchant, the drops, mount summon and dismount, respawn, the
   zone banner, PvP off and automatic flag changes, crit, Blink and Sprint;
   the PvP cue only on the Enable PvP button; money on the Bag of Coins
   deposit; no refusal cue.
7. **Wind-up sounds** only for the dragons (P2.1) and the humanoid special
   attack (R2.3, also the kings' and Generals' signature); every other
   elite winds up silently.
8. **Music:** M7 *A Dragon's Lullaby* and M8 *The Great Sea* (first 2:00) for
   Front and sea, M10 *Katabasis I* (first 3:20) and M11 *Permafrost* for
   the Underground; M6 *Fantasy Orchestral Theme* also as the main-menu
   theme.
9. **Effect and voice picks** from the S1a, S2 and S1b pages and their
   second pages (Ice Nova, Taunt, Charge, the human death), including the
   families S1b added (goblin, mummy, skeleton, spirit, elemental, grazer,
   crow, kraken); the lists are `tools/r34_<lane>/approved.txt`.

### Open notes

In the [BACKLOG](../../BACKLOG.md#round-34-carry-overs); none blocks the
GUI test. Numbers are comparisons, never targets.

- **Public town furnaces** use the vendored furnace form, so taking a dish
  out of one plays no cooking cue (the profession stations do).
- **The formspec click** plays at the file's level (a style has no gain).
- **Music push cost** is unmeasured: the engine hashes the file on the main
  thread, a few milliseconds per push.
- **Town pool under capitals:** the town flag is by x/z only, so a cave
  below a capital plays the Town pool and the half-gain bed.
- **Volume rounding:** a `/music` or `/ambience` volume off the 10 % grid
  shows rounded on the Help page's dropdown.
- **Licence URLs:** the incompetech rows point at the catalogue, not at
  each track's page.
- **Water probe:** since the sea bed ships, the probe reads 33 nodes per
  evaluation instead of 1 (not re-measured; a code comment in
  `grug_ambience/init.lua` still says no sea bed exists).
- **S1a review notes:** the gallop follows the requested speed; a clip's
  tail plays after a stop; position sounds of one event within 0.1 s fold
  into one.
- **F1:** an idle mob facing a two-node bank may stay in water (no
  regression); animals following food do not wade; `grug_bank_ahead` runs
  per step for a floating mob in water (could be cached).
- **F2:** the Money label may overlap at a very large balance (GUI check).
- **Scout** full damage set above the ceiling: watch in the playtest.
- Optional: a real-client performance test with several clients.

### GUI playtest checklist

Desktop client and the web build, a world of Round 33 or later; helpers
`/xp give`, `/teleport`, `/giveme` (privileges `server`, `give`). Say what
is too loud, too quiet, too frequent or wrong; gains are tuned from your
notes.

UI, NPCs and progression (S1a):

1. **Clicks** in every window (inventory tabs, Character, Help, Map, a
   vendor, a trainer, the quest dialog, crafting).
2. **Quests:** a quest giver's dialog opens with a book cue, selecting a
   quest turns a page; **accept is silent**; abandon and turn-in each play
   their cue.
3. **Buy and sell** at a vendor (coins).
4. **Role cues:** a profession trainer, an innkeeper, the stable (riding
   trainer), the Shipwright, the Housing Steward, the Crownbinder.
5. **Level-up** fanfare; **profession learned** and a **tier** reached.
6. **Crafting:** at the smithy (hammer), cooking, alchemy at the brewing
   stand, a plain craft; take a finished dish out of a profession furnace;
   **repair**, an **upgrade**, a **crown**; choose a **cloak**; equip gear.
7. **Bag of Coins:** withdraw (no sound), deposit (the money cue); a second
   player picks up a dropped bag and deposits it.
8. **Enable PvP** button plays a cue; walking into contested land does not.
9. **Mounts and travel:** gallop on a land mount, wing beats in flight, the
   boat's splash; fishing cast and catch; travel by waystone and home.

Ambience and music (S2):

10. **Music after joining** (30–90 s) on desktop **and** in the web build;
    a few minutes of quiet between pieces; Help → **Sound**, `/music` and
    `/ambience` (on, off, a volume) apply at once.
11. **Beds per zone** by day and night in each region (crickets at night
    for humans, elves, trolls and orcs), a **town** (half gain, the Town
    pool), a **cave**, **deep underground** (below y −500), the **sea**, and
    silence under water.
12. **Loops:** a forge and anvil, a burning hearth or camp fire, flowing
    water (a stream or waterfall, not a still lake).
13. **Dragon-island thunder:** rare, distant.

Combat and creatures (S1b):

14. **Melee hits** by weapon kind (sword or greataxe, dagger, staff or
    wand, fist), on mobs and on a flagged player; dodge; an absorb shield
    taking a hit; your own death.
15. **Abilities** of each class: Warrior Charge, Taunt, Hold Ground;
    Mage Fireball, Ice Nova, Glacial Ward, Cinderfall (Blink silent);
    Priest Smite, Heal, Mend, Shield, Word of Ruin; Scout Loose, Snare and
    Pinning Shot, Sidestep (Sprint silent).
16. **Voices** across families (a wolf, a boar, a bear, a goblin, a zombie,
    a skeleton, a wisp, a slime, a spider, a crocodile, a crab): war cry,
    hurt, death; the **panther** charges without a war cry; the **Carrion
    Crow** calls when hit.
17. **Dragons:** the wind-up growl, fire and frost breath, enrage, the
    wrath outside the arena, the arena lightning; on Wyrmglass, **thin ice
    breaking 1 s behind a runner** in a 3 × 3 band, one breaking sound at a
    time.
18. **A King's** (or a General's) special attack; other elites wind up
    silently.

Fixes (F1, F2):

19. **A mob following across a stream** and swimming back to land after
    the fight.
20. **Text boxes:** the trainer's "Known:" box and the crafting page's
    Basics hint show without a scrollbar.
21. **Map markers** for the Crownbinder and the Decor Merchant on the Map
    tab and the minimap.

Late additions:

22. **A new world with a random seed** loads (the Round 34 seed fix); rivers
    near outposts and camps run around them, not through.
23. **A Wisp** chasing you while you swim stays above the water.
