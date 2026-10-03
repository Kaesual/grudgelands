# Sound research for V1 (Round 32, Lane R2)

Read-only study, 2026-10-03, against main `c8951467`. It answers four
questions for the V1 sound work (user ruling: sound is part of V1): which
sounds the game plays today, which events are silent, where good sounds and
calm music with a compatible licence come from, and what an implementation
round would cost. A German listening page with examples goes to the user
separately; this report is the reference.

Every claim is marked by how it was established:
**[code]** read in this repository (`path:line`), **[engine]** read in the
pinned Luanti source (`reference_projects/luanti`, 5.16.0-74-gdf0487906),
**[measured]** measured with ffprobe/ffmpeg or a script (see Evidence),
**[source]** taken from the cited web page (fetched 2026-10-03).

## 1. Summary

1. **The game is almost silent.** 94 sound files ship today, all mono Ogg
   Vorbis, 1.35 MB in total [measured]. They are minetest_game's node set
   (dig, dug, place, footsteps), door, chest, furnace and tool-break sounds,
   the three mobs_redo defaults, one drinking and three eating sounds.
   Nothing in quests, NPCs, progression, abilities, UI, mounts, ambience,
   settlements or bosses has its own sound; mobs have no voices.
2. **Nearly every gap has one central hook already.** Quest accept and
   turn-in, vendor and trainer dialogs, level-up, talents, profession tiers,
   ability casts, ability damage, projectiles, money, mounts, travel, the
   zone banner and the PvP flag each pass through one function. Only
   formspec button clicks, mob voices and ambience/music need a new piece.
3. **Licence-clean sources exist for everything except voiced NPC lines.**
   CC0 packs (Kenney, rubberduck and artisticdude on OpenGameArt) and
   Freesound's CC0 filter cover effects, ambience, water and weather; CC BY
   adds a few good fantasy packs. Calm music is available under CC BY 4.0
   (Scott Buckley, Kevin MacLeod, Alexander Nakarada) and CC BY 3.0/CC0
   (OpenGameArt). Voiced NPC greetings have no good free source.
4. **Luanti has no music channel.** The engine has one master volume; a
   music volume slider was declined upstream. A game-side per-player music
   volume through `core.sound_fade` is the established workaround (VoxeLibre
   ships exactly this).
5. **Effort:** one effects lane (about 120–150 files, ~30 call sites, a
   formspec click style, mob sound tables by archetype) and one
   ambience-and-music lane (a per-player player on the existing 2 s
   atmosphere tick, settings UI, 8–12 tracks). The real cost is choosing
   sounds by ear and keeping one licence row per file.

## 2. Inventory: what plays today

### 2.1 Sound files

| Mod | Files | Licence (per upstream notice) | Played by |
|---|---|---|---|
| `BASE/default` | 74 (dig, dug, place, footsteps for dirt/grass/gravel/sand/snow/ice/wood/stone/metal/glass/water, chest open/close, furnace hum, glass break, lava cooling, item smoke, tool break, `player_damage`) | CC BY-SA 3.0 (Mito551 set), CC BY 3.0 and CC0 per file — `mods/BASE/default/README.txt:257-361` | node sound tables, engine, chests, furnace, tools |
| `BASE/doors` | 8 (wood, steel, glass door; fence gate) | CC BY 3.0 / CC0 per file — `mods/BASE/doors/README.txt:71-87` | doors in settlements |
| `BASE/xpanes` | 2 (steel bar door) | CC BY-SA 3.0 — `mods/BASE/xpanes/README.txt:25-32` (TumeniNodes) | steel bar door |
| `ENTITIES/mobs` | 3 (`mobs_punch`, `mobs_swing`, `mobs_spell`) | CC0 — `mods/ENTITIES/mobs/license.txt:36-43` | hit on a mob, mobs_redo internals, dragon warning |
| `ITEMS/grug_alchemy` | 1 (`grug_alchemy_drink`) | CC0, from VoxeLibre — `mods/ITEMS/grug_alchemy/LICENSE-media.md` | potion use |
| `ITEMS/grug_food` | 3 (`grug_food_eat.1-3`) | CC BY 3.0 (sonictechtonic), from Lord of the Test — `mods/ITEMS/grug_food/LICENSE-media.md` | eating |

All 94 files are mono [measured], so all can play positionally.
`grug_mobs`, `grug_mounts` and the other `grug_*` mods ship no sounds by
decision: `mods/ENTITIES/grug_mobs/LICENSE-media.md:10` (freesound-derived
mob audio was not cleared), `mods/PLAYER/grug_mounts/LICENSE-media.md:3`.

### 2.2 Where sounds are triggered

- **Node sounds** [code]: about 330 node registrations use
  `default.node_sound_*_defaults` (stone 80, wood 59, leaves 45, metal 25,
  glass 22, dirt 22, plain 15, sand 7, gravel 6, water 5, snow 4, ice 4) —
  helpers in `mods/BASE/default/functions.lua:5-140`. These give dig, dug,
  place and footstep sounds for the player and for every mob with
  `makes_footstep_sound = true`. `node_sound_defaults` has an empty
  footstep (`functions.lua:7-8`), so those 15 nodes are silent underfoot.
- **Engine built-ins** [engine]: `player_damage`, `player_falling_damage`,
  `player_jump` and `default_dig_<group>` are played by the client if the
  files exist (`doc/lua_api.md:1487-1497`,
  `src/client/sound_maker.cpp:20-75`). Only `player_damage` exists here;
  falling damage and jumping are silent.
- **Explicit `core.sound_play` calls** [code], all of them:
  - `ENTITIES/mobs/api.lua:3607`: `mobs_punch` (or the weapon's
    `sound.use`) on every accepted hit on a mob.
  - `ENTITIES/mobs/api.lua:280-295` `mob_sound`: random, war cry, attack,
    damage, death, jump sounds from the mob's `sounds` table. No grug mob
    defines one except the rift spawn (`grug_mobs/rift_spawn.lua:85`), so
    mobs are mute.
  - `grug_mobs/bosses.lua:719`: `mobs_spell` for the dragon respawn warning.
  - `grug_mobs/boss_dragons.lua:319`: `default_break_glass` when arena ice
    breaks.
  - `grug_mobs/rift_spawn.lua:69`: the rift burst (`default_item_smoke`).
  - `grug_alchemy/effects.lua:24`: drinking; `grug_food/init.lua:358`:
    eating loop; `grug_food/init.lua:443`: place sound for placed food.
  - `grug_fishing/init.lua:221,251,282`: cast and catch reuse
    `default_water_footstep`.
  - `grug_farming/init.lua:302`, `grug_farming/hoes.lua:41`: planting and
    tilling reuse node sounds.
  - `BASE/default/furnace.lua:329`, `chests.lua:306,322`, `torch.lua:12`,
    doors and xpanes: vanilla behaviour.
- **Item sounds** [code]: tools carry `sound = {breaks =
  "default_tool_breaks"}` (`grug_materials/tools.lua:113`); no item defines
  `punch_use`/`punch_use_air`, so swings into the air are silent
  [engine: `src/client/game.cpp:2776-2778`].
- **Broken reference** [code]: `ENTITIES/mobs/api.lua:4951,4980` fall back to
  `tnt_explode`, which does not exist. Harmless today (the only exploding
  mob sets its own sound), worth knowing.
- **Mob hearing is off** [code]: mobs_redo wraps `core.sound_play` with a
  per-call object search when `mobs_can_hear` is on
  (`ENTITIES/mobs/api.lua:5469-5562`); `minetest.conf:78` sets it to false,
  so more sounds cost no Lua work in that wrapper.
- **Placeholders left for a sound pass** [code]: `grug_mobs/telegraph.lua:77`
  ("a wind-up growl belongs here … see BACKLOG") and
  `grug_mobs/panther.lua:7-13` (the panther must stay without `war_cry` on
  purpose). BACKLOG.md has no sound entry, so that pointer is dangling.

## 3. Gaps: events that should have a sound

Hook column: the function where a sound call fits, read in code (line
numbers spot-checked). "Central" means every case passes through it.

| Group | Event | Hook | Central | Today |
|---|---|---|---|---|
| NPCs | quest giver dialog | `grug_quests/npc.lua:15` `Q.open_npc` | yes | silent |
| | vendor open / buy / sell | `grug_traders/trade.lua:313` `open`, `:388` `do_buy`, `:429` `do_sell` | yes | silent |
| | trainer, innkeeper, mount trainer, shipwright, steward | `grug_mobs/start_villagers.lua:1035` villager `on_rightclick` dispatch | yes | silent |
| | faction refusal | `grug_factions/service.lua:23` `refuse` | yes | silent |
| Quests | accept / abandon / turn-in | `grug_quests/state.lua:261` `Q.accept`, `:283` `Q.abandon`, `:402` `Q.turn_in` | yes | silent |
| | objective progress | `grug_quests/hud.lua:106` `post_progress` | yes | silent |
| Progression | level-up | `grug_xp/init.lua:100-104` in `set_xp` (banner) | yes | silent |
| | profession tier-up, profession learned | `grug_jobs/state.lua:159` `record_craft`, `:57` `learn` | yes | silent |
| | talent learned | `grug_classes/talents.lua:1123` `spend_talent` | yes | silent |
| Crafting | craft finished (grid, station, operation, enchant) | `grug_jobs/state.lua:159` `record_craft` | yes | silent |
| | repair | `grug_repair/service.lua:75` `apply` | yes | silent |
| | mining, gathering, fishing, farming | node dig sounds; `grug_materials/mining.lua:446` for ore | partly | node sounds only |
| Abilities | cast (21 registrations, 4 classes) | `grug_abilities/init.lua:1445` `try_cast` | yes | silent |
| | ability hit, crit, dodge | `grug_core/combat.lua:1417` `deal_ability_damage` | yes | `mobs_punch` only |
| Combat | melee hit on mob | `ENTITIES/mobs/api.lua:3607` | yes | `mobs_punch` |
| | swing into the air / miss | item `sound.punch_use_air` (engine, client-side) | per item | silent |
| | mob evade / immune | `grug_mobs/init.lua:738` | yes | silent |
| | block / parry | no system exists | — | — |
| | player hurt / dodge | `grug_core/combat.lua:1761` hpchange | yes | engine `player_damage` |
| | player death, respawn | `grug_core/death_messages.lua:145`, `grug_home/travel.lua:243` (`respawn`) | yes | silent |
| | mob voices (idle, aggro, hurt, death) | mob def `sounds` table (`mobs/api.lua:280`) | per def | silent |
| | projectile launch / impact | `grug_projectiles/init.lua:255` `spawn`, `:319` `settle_hit` | yes | silent |
| UI | button clicks | none — one `style_type[…;sound=…]` in the formspec prepend (`BASE/default/init.lua:28-39`) would cover every formspec client-side | new | silent |
| | inventory tab switch | `BASE/sfinv/api.lua:143` `set_page` | yes | silent |
| | inventory open | the server is not told (engine) | impossible | — |
| | refusal / error notice | `grug_core/flash.lua:24` (8 callers; ~58 refusals use plain chat) | partly | silent |
| | money gained | `grug_money/init.lua:104` `add` | yes | silent |
| | equip | `grug_core/combat.lua:328` `notify_equipment_change` (filter on reason) | yes | silent |
| Mounts | summon / dismount | `grug_mounts/entity.lua:666` `mount`, `:162` `dismount` | yes | silent |
| | gallop, flight, boat | `entity.lua:357` `land_step`, `:383` `flight_step`, `:405` `water_step` | yes | silent (mount entity has no footsteps) |
| Footsteps | per surface | node sound tables | yes | covered for 11 surfaces; old recordings |
| Travel | waystone, hearth, home | `grug_home/travel.lua:12` `teleport` | yes | silent |
| World | zone banner, capitals | `grug_map/location.lua:309` `display` | yes | silent |
| | PvP flag on/off | `grug_pvp/init.lua:86` `notify` | yes | silent |
| Ambience | per region and depth | `grug_core/atmosphere_zones.lua:520` `evaluate` (2 s per player, mood keys) | yes | silent |
| Water | rivers, sea, underwater | same tick (ocean mood exists) + position checks | new | water footsteps only |
| Weather | rain, thunder | **no weather system exists** [code] | — | — |
| Day/night | night ambience | `grug_core/atmosphere.lua:256` 1 s clock | yes | silent |
| Settlements | market, smithy, hearth | capital name from `grug_map/location.lua` | new | silent |
| Bosses | dragon breath, wrath, enrage, lightning | `grug_mobs/boss_dragons.lua:544,121,657,592` | spread | ice break only |
| | telegraph wind-up | `grug_mobs/telegraph.lua:67` `start_windup` | yes | silent (TODO) |
| | Kraken, kings | `grug_mobs/kraken.lua:122`, `bosses.lua:474` | spread | silent |

## 4. Sources

### 4.1 Rules that decide a source

- Allowed: CC0, CC BY 3.0/4.0, CC BY-SA 3.0/4.0, kept per file
  ([licensing.md](licensing.md) §1–2). Never NC or ND.
- Luanti ships media as loose files to every client, so "royalty-free"
  licences that forbid redistributing the raw files do not fit even when
  they allow use in a game. GPL-licensed media is allowed by AGENTS.md but
  adds the source-form duty; prefer CC.
- Luanti plays only Ogg Vorbis; positional sounds must be mono
  [engine: `doc/lua_api.md:1323-1326`]. Every pack below needs conversion
  (`ffmpeg -ac 1 -c:a libvorbis -q:a 3`): Kenney's and rubberduck's Oggs are
  stereo (44.1 or 48 kHz) except 77 of Kenney's 100 interface sounds [measured].
- Verify in the source, not in a mod's summary: the TenPlus1 ambience case
  below shows why.

### 4.2 Effects and ambience

| Source | Licence | Attribution | Contents | Quality / fit | Format, size |
|---|---|---|---|---|---|
| [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio) | CC0 [source, `License.txt` in zip] | optional | 50 files: books, cloth, coins, doors, footsteps, knife, metal pot, chop | clean, dry foley; fits UI and crafting | Ogg stereo, 0.96 MB zip [measured] |
| [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds) | CC0 | optional | 130 files: hits by material, punches, mining, 5 footstep surfaces | very usable for hits and footsteps | Ogg, 0.80 MB |
| [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) | CC0 | optional | 100 files: click, open/close, confirm, error, toggle, scroll | neutral UI, slightly modern | Ogg, 0.83 MB |
| [Kenney UI Audio](https://kenney.nl/assets/ui-audio) | CC0 | optional | 50 clicks, switches, rollovers | very short | Ogg, 0.41 MB |
| [Kenney Music Jingles](https://kenney.nl/assets/music-jingles) | CC0 | optional | 85 jingles in 5 styles (8-bit, hit, pizzicato, sax, steel drum) | pizzicato and steel usable for quest/level cues; 8-bit and sax do not fit | Ogg, 1.24 MB |
| [80 CC0 RPG SFX](https://opengameart.org/content/80-cc0-rpg-sfx) (rubberduck) | CC0 | none | blades, books, chains, creatures, coins, gems, spells (fire), stones, wood | good, consistent | Ogg, 1.8 MB |
| [80 CC0 creature SFX](https://opengameart.org/content/80-cc0-creature-sfx), [#2](https://opengameart.org/content/80-cc0-creture-sfx-2) (rubberduck) | CC0 | none | grunts, roars, hurt, die, bugs, slimes | covers mob archetypes | Ogg, 1.9 MB each |
| [100 CC0 SFX #2](https://opengameart.org/content/100-cc0-sfx-2), [100 CC0 metal and wood](https://opengameart.org/content/100-cc0-metal-and-wood-sfx), [75 CC0 breaking/falling/hit](https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx), [40 CC0 water/splash/slime](https://opengameart.org/content/40-cc0-water-splash-slime-sfx) (rubberduck) | CC0 | none | ambient and water loops, rain loop, thunder, doors, locks, splashes | good filler; loops short | Ogg, 1.6–2.4 MB each |
| [RPG Sound Pack](https://opengameart.org/content/rpg-sound-pack) (artisticdude) | CC0 | requested, not required | 95 WAV: swings, unsheathe, spell, inventory foley, ogre/giant/shade/slime voices | dated but characterful; good boss/creature voices | WAV, 12.5 MB |
| [Monster Sound Effects Pack](https://opengameart.org/content/monster-sound-effects-pack) (Ogrebane) | CC0 | none | 20 monster grunts, pain, death | usable for humanoid enemies | WAV, 1.4 MB |
| [Fantasy Sound Effects Library](https://opengameart.org/content/fantasy-sound-effects-library) (Little Robot Sound Factory) | CC BY 3.0 | required, with link | 45: dragon growls, goblin voices, gold pickup, inventory, spells, traps, jingles | high quality, very fitting | MP3 + WAV, 31 MB |
| [Spell Sounds Starter Pack](https://opengameart.org/content/spell-sounds-starter-pack) (p0ss) | CC BY-SA 3.0 **or** GPL 3.0 or GPL 2.0 (multi-licence) | required | ~75 spells: heal, curse, freeze, blessing, zap, warp | dated synthetic; usable for some spells | 9.8 MB; some ".ogg" are WAV per a comment |
| [Freesound](https://freesound.org), CC0 filter | CC0 / CC BY / CC BY-NC / legacy Sampling+ **per file** [source: FAQ] | CC BY: per file | everything: ambience by biome, rain, thunder, rivers, sea, market crowds, smithy, horses, wings, roars | field recordings of high quality; choose per file | WAV/FLAC originals need login; previews MP3/Ogg |
| [TenPlus1 Ambience](https://codeberg.org/tenplus1/ambience) | code MIT; sounds **mixed per file** | per file | 36 short ambience sounds | **use as code reference only** — see below | Ogg, mono |
| minetest_game `default` (vendored) | CC BY-SA 3.0 / CC BY 3.0 / CC0 per file | per file | footsteps, dig, place | already shipped | — |
| VoxeLibre (`reference_projects/VoxeLibre`) | "no non-free licences" (`LEGAL.md:38-40`), per-mod READMEs | per file | 476 Oggs (58 MB of sound folders) incl. mobs, weather rain (CC BY-SA 3.0) | audit per file before taking any | Ogg |

**TenPlus1 ambience (finding).** The 2026-08 shopping list
([assets/sounds_ambience.md](assets/sounds_ambience.md)) says only `seagull_2` must be
excluded. At commit `4587abc9` (2026-10-02) [source:
`license.txt` and `sounds/license.txt` on Codeberg]: `seagull_2` is CC BY-NC
4.0; `caverealms_crystal.ogg` and `caverealms_deep_whoosh.ogg` are under the
**Pixabay** licence (not CC); the jungle sounds point to freesfx.co.uk (own
licence); about ten files (`bird1`, `bird2`, `crestedlark`, `peacock`,
`deer`, `jungle_day_1`, `jungle_night_*`, `river`, `canadianloon2`,
`desertwind`, `lava`) are not mapped to any licence line; several are
SoundBible re-uploads. Take its mechanism (sound sets, `/mvol`, `/svol`)
as a reference and fetch originals from Freesound instead. The shopping list
needs this correction.

**Avoid** [source]: BBC Sound Effects (RemArc licence, personal, educational
and research use only); Sonniss GDC bundles (no redistribution of raw files,
an open game repository counts as redistribution); Pixabay sounds and music
(Pixabay Content License, not CC; no standalone redistribution); ZapSplat,
Mixkit, Soundimage, Bensound and similar custom licences (not CC, outside
the project's licence list — not checked in detail for that reason);
Freesound files under CC BY-NC or Sampling+; anything whose page carries
Freesound's GenAI tag or comes from recent bulk "CC0 mega packs" without a
traceable author (risk of AI output of unknown origin). The Freesound picks
in the listening page carry no GenAI tag in a page scan [measured].

**Own generator.** The project's art is generator output (CC0). Simple UI
clicks, chimes and jingles can be made the same way: a 70-line numpy script
produced a level-up arpeggio, quest accept/complete chimes, a click and an
error buzz [measured; evidence `scripts/synth.py`]. Good for UI and
progression cues; not for foley, voices, ambience or music.

**Voiced NPC greetings.** No convincing CC0/CC BY fantasy greeting set was
found (OpenGameArt has voice packs, mostly announcer or fighter lines).
Options: neutral cues only (book, coins, chime), own recordings, or
generated murmur. A decision for the user.

### 4.3 Footsteps

The vendored minetest_game set already covers 11 surfaces (section 2.1).
Kenney Impact Sounds adds cleaner grass, wood, snow, concrete and carpet
steps (5 variants each, CC0). Replacing the Mito551 set (CC BY-SA 3.0) is
optional polish, not a gap.

## 5. Background music

### 5.1 Candidates

Lengths and loudness measured on the downloaded files (integrated loudness
I in LUFS, loudness range LRA in LU — a higher LRA means quieter passages
next to louder ones). Mood from the source page or the track's genre tags.

| # | Track | Composer | Licence | Length | I / LRA | Mood | Source |
|---|---|---|---|---|---|---|---|
| M1 | Memories Of Stone | Scott Buckley | CC BY 4.0 | 5:30 | −14.6 / 12.2 | "peaceful, bittersweet strings and brass", Hardanger fiddle | [page](https://www.scottbuckley.com.au/library/memories-of-stone/) |
| M1b | Wildflowers | Scott Buckley | CC BY 4.0 | 5:22 | −14.3 / 9.0 | piano and strings, "building to a more energetic ending" | [page](https://www.scottbuckley.com.au/library/wildflowers/) |
| M2 | Achaidh Cheide | Kevin MacLeod | CC BY 4.0 | 2:14 | −16.3 / 8.0 | Celtic, calm | [incompetech](https://incompetech.com/music/royalty-free/) |
| M2b | Thatched Villagers | Kevin MacLeod | CC BY 4.0 | 4:05 | −12.4 / 5.6 | light village tune | incompetech |
| M3 | Forest Walk | Alexander Nakarada | CC BY 4.0 | 3:38 | −13.2 / 5.4 | Celtic/medieval, tagged "sad, dramatic" | [page](https://creatorchords.com/music/forest-walk/) |
| M4 | Soliloquy | Matthew Pablo | CC BY 3.0 | 3:44 | −19.3 / 11.7 | soft orchestral | [OGA](https://opengameart.org/content/soliloquy) |
| M5 | Lonely Blossom | Exhale & Tim Unwin | CC BY-SA 4.0 | 3:53 | −18.8 / 13.6 | quiet piano | VoxeLibre `mods/PLAYER/mcl_music`, `CREDITS.md:195-201` |
| M6 | Fantasy Orchestral Theme | joth | CC0 | 3:12 | −15.3 / 11.6 | "begins fairly slow and serene" | [OGA](https://opengameart.org/content/fantasy-orchestral-theme) |
| — | Town Theme RPG | cynicmusic | CC0 | 1:37 | −13.0 / 4.1 | town loop | [OGA](https://opengameart.org/content/town-theme-rpg) |
| — | Home in the Wilderness | Herowl | CC BY-SA 4.0 | 1:09 | −16.2 / 4.2 | calm | VoxeLibre |

Catalogues to draw more tracks from: Scott Buckley's library (whole site CC
BY 4.0, ambient and orchestral), incompetech (CC BY 4.0, searchable by
mood), CreatorChords/Nakarada (CC BY 4.0, Celtic and medieval; paid
licence only removes the credit), OpenGameArt (licence per entry; Matthew
Pablo CC BY 3.0, joth CC0), Komiku on Free Music Archive (CC0 albums, more
playful in style), VoxeLibre's 32 tracks (CC BY-SA 3.0/4.0, 32 MB, mostly
piano and light electronic in a block-game style; only a few fit).
Attribution texts are fixed by the composers, e.g. "'Memories Of Stone' by
Scott Buckley – released under CC-BY 4.0. www.scottbuckley.com.au"
[source]; CC BY allows trimming a track to its calm part with a
modification note.

### 5.2 How it would play

- **Engine limits** [engine, source]: no music channel or music volume —
  one master `sound_volume` (`builtin/settingtypes.txt:864-874`); upstream
  closed a music slider request as "Won't add"
  ([#9057](https://github.com/luanti-org/luanti/issues/9057)) and the music
  support issue is open since 2018
  ([#7867](https://github.com/luanti-org/luanti/issues/7867)). Sounds over
  3 s are streamed by the client
  (`src/client/sound/sound_constants.h:90-91`), so long tracks do not decode
  into RAM at once. A non-positional `to_player` sound may be stereo.
- **Per-player volume:** store a music gain (and an ambience gain) in player
  meta; play with `gain = setting`; on change `core.sound_fade(handle, 1,
  new_gain)` (fading to 0 deletes the sound,
  `doc/lua_api.md:7583-7590`). VoxeLibre's `mcl_music` does exactly this
  (`reference_projects/VoxeLibre/mods/PLAYER/mcl_music/init.lua:55-67`), plus
  a `/music` toggle.
- **Selection:** the atmosphere tick already computes a mood key per player
  every 2 s — `dwarf`, `human`, `elf`, `undead`, `orc`, `troll`,
  `battlegrounds`, `dragon_island`, `ocean`, underground below y −20 and a
  default (`grug_core/atmosphere_zones.lua:171-302,407,466-532`). A music
  player can read the same key: a pool per mood group (for example
  "peaceful lands", "frontier", "underground", "sea and islands") or one
  playlist everywhere.
- **Pacing:** play a track, then silence for a random 3–8 minutes; on a
  mood change do not cut the running track — let it end and choose the next
  from the new pool (VoxeLibre waits at least 5 minutes after a scenario
  change, `mcl_music/init.lua:51,163-181`). No combat switch (user).
- **Main menu:** a game can ship `menu/theme.ogg` (and `theme.1.ogg` …)
  for the main menu [engine: `doc/lua_api.md:224-233`].

### 5.3 Memory and download cost

- Today: 13.8 MB of textures, models and sounds, of which 1.35 MB sounds
  [measured]. Every client downloads all media on first join and caches it.
- Music as Ogg Vorbis [measured on M1 and M2]: stereo q0 ≈ 0.43 MB/min,
  q1 ≈ 0.54 MB/min, q2 ≈ 0.70 MB/min. Ten tracks of ~3.5 min: about
  15 MB (q0) to 25 MB (q2) — the join download doubles or triples.
- Options: fewer, shorter tracks; q0/q1 (calm orchestral music hides the
  artefacts well); or keep music out of `sounds/` and push it with
  `core.dynamic_add_media{filepath=…, to_player=…, client_cache=true}` only
  to players who turn music on (`doc/lua_api.md:7791-7826`; the client
  caches it, remote media servers apply). The last option needs a short
  engine test.
- Ambience beds: a 30 s mono loop is 0.19–0.23 MB (q0–q3) [measured]; 15
  loops ≈ 3 MB. Effects: 5–15 KB each as mono q3 [measured]; 150 effects ≈
  1.5–2 MB.

## 6. Effort estimate for an implementation round

### 6.1 What exists

- Central hooks for ~30 events (section 3).
- Node sounds and engine footsteps work; `player_damage` exists.
- The 2 s per-player mood tick and the 1 s zone tick
  (`grug_map/location.lua:343`) give region, depth, capital and day/night.
- Player meta for per-player settings; Help page or a new tab for a
  settings block (no settings page exists today; checkboxes live on single
  pages, e.g. `grug_map/page.lua:180`).

### 6.2 New mechanisms

1. **A small play helper** (one function, a name table per event, ephemeral
   one-shots, `to_player` vs positional with `max_hear_distance`), so the
   ~30 call sites stay one line each.
2. **Formspec click sounds:** one `style_type[button,image_button,tabheader;
   sound=…]` in the existing prepend (`BASE/default/init.lua:28-39`); played
   by the client without server work. Check per formspec that local
   `style_type` lines do not drop it.
3. **Mob sounds by archetype** (beast, canine, feline, boar, insect, slime,
   undead, humanoid, bird, reptile, aquatic, dragon): a `sounds` table set at
   registration (random, war cry, damage, death; distance). Keep the
   panther without `war_cry` (`grug_mobs/panther.lua:7-13`). 89
   `grug_mobs` registrations share these by family.
4. **Per-player ambience and music player:** on the mood tick; one looped
   bed per mood with crossfade (`sound_fade`), sparse one-shots (birds,
   owl, distant thunder) with a per-player timer; night variants from the
   world clock; water beds when near water or underwater; settlement beds in
   capitals. Per-player gains and an on/off toggle; a music scheduler as in
   5.2. Network: one start packet per loop; one-shots no more often than
   every few seconds per player.
5. **No weather system exists.** Rain and thunder sounds only make sense
   with one (sky, particles, sound) — a separate decision.

### 6.3 Size

| Part | Files | Notes |
|---|---|---|
| UI, NPC, quests, progression | 15–20 | some may be generated |
| Combat and abilities | 35–45 | swings, hits by weapon type, crit, dodge, death, respawn, one cast/impact per ability theme (~21 abilities) |
| Mob voices | 40–60 | 12 archetypes × 3–4 events, 1–2 variants |
| Crafting, gathering, mounts, travel | 15–20 | |
| Bosses and dragons | 10–15 | |
| Ambience and water | 30–40 | ~11 mood beds, night variants, one-shots, 3 water beds, 3 settlement beds |
| Music | 8–12 tracks | 15–25 MB unless delivered on demand |
| **Total** | **~150–210 files** | each a `LICENSE-media.md` row (file, author, source URL, licence+version, "converted to mono Ogg, trimmed") |

Two lanes fit: **S1 effects** (helper, ~30 hooks, click style, mob tables,
~120–150 files) and **S2 ambience and music** (player, settings, beds,
tracks), plus a short listening review by the user after each (iteration by
ear). Licence work: a top-level `CREDITS.md` becomes worthwhile (AGENTS.md
"Licenses" foresees it once sources accumulate); CC BY credits must name the
author, link source and licence, and note the conversion. Fixtures: the play
helper and the music scheduler are pure logic and fit a portable fixture;
the rest needs one engine smoke boot and a GUI listen.

## 7. Questions for the user

1. Effects: CC0 packs first, CC BY where clearly better (e.g. the Little
   Robot dragon growls), own generated UI/jingle cues — or packs only?
2. NPC dialogs: neutral cues (book, coins, chime) or voiced greetings (no
   good free source; own recordings needed)?
3. Music: which candidates fit; one playlist everywhere or pools per region
   group; pause length between tracks.
4. Music delivery: with the game for everyone (+15–25 MB) or on demand only
   for players who turn it on.
5. Ambience: continuous beds per region with sparse calls, or sparse calls
   only.
6. Weather: leave rain/thunder out of V1 (no weather system), or add a small
   weather system as its own package.

## Evidence

All files are outside the repository in
`~/projects/grudgelands-orchestration/r32/r2-evidence/`:

- `dl/` — downloaded packs (Kenney ×5, OpenGameArt ×11), music candidates
  (`dl/music/`), Freesound HQ previews (`dl/freesound/`, 21 files).
- `ambience_license.txt`, `ambience_README.md`, `ambience_init.lua` —
  TenPlus1 ambience at `4587abc9`.
- `fs/*.json`, `scripts/fs_search.py` — Freesound CC0 searches (id, user,
  title, duration, licence, GenAI tag scan, preview URL).
- `scripts/synth.py`, `gen/` — own generated cues.
- `scripts/clips.py`, `clips/`, `clips.json` — the 62 listening clips with
  credit and licence per clip.
- `enc/` — Ogg size measurements (music q0/q2/q4, mono loops, effects).
- Loudness: `ffmpeg -af ebur128` on each music file; channel counts:
  `ffprobe` over every shipped `.ogg`.
- Hook survey: an Explore sub-agent's table, line numbers spot-checked by
  hand (`Q.accept`, `try_cast`, `set_xp`, `deal_ability_damage`,
  `grug_traders.open`, `record_craft`, `evaluate`, `telegraph.start_windup`
  and ten more); one correction applied (the formspec prepend does exist in
  `BASE/default/init.lua`).
- No engine runs were made.
