# Sound

The game's sound as built in Round 34 ([plan](../planning/round34-plan.md),
[completion](../planning/round34-plan.md#completion-2026-10-04)): effects at
the game's events, mob voices by family, quiet ambience beds per region, loops
at hearths and flowing water, music in the six capitals (since
Round 35, [plan](../planning/round35-plan.md) §2.8), and per-player
settings. Sound is part of V1. Two mods own it: `mods/CORE/grug_sounds`
(effects, the play helper, the formspec click) and `mods/CORE/grug_ambience`
(beds, calls, loops, music, settings). Numbers that change with tuning (gains,
intervals, hearing distances, the track list) live in their data tables, not
here: `EVENTS` in `grug_sounds/init.lua`, `grug_ambience/data.lua`,
`VOICES` in `grug_mobs/voices.lua` and `CAST_SOUNDS` in
`grug_abilities/init.lua`. Credits: [CREDITS.md](../../CREDITS.md).

## 1. The approval gate

**No sound enters the game unless the user approved that exact file on a
listening page** (user ruling, 2026-10-04: "sometimes no sound is better than
a bad sound"). Process for any new or changed sound:

1. A lane proposes 2–4 candidates per event on a preview page in the final cut
   (mono Ogg rendered as MP3), numbered, with source and licence.
2. The user picks; the coordinator records the pick (file name, page number,
   source) in the lane's approval list, which ships as
   `tools/r34_<lane>/approved.txt` (or a later round's list, e.g.
   `tools/r35_f/approved.txt`).
3. Only listed files ship. Each lane's fixture fails on an `.ogg` its list
   does not name. A changed cut (shorter, trimmed, re-looped) is a new file and
   needs a new approval.
4. **An event without an approved file stays silent**: it has no spec (its
   call is a no-op) or no call site, never a placeholder file.
5. Gains and pacing are tuned in the user's GUI check; swapping a file goes
   through a page again.

**The inherited set** (user decision 2026-10-05). The sounds that came with
the vendored code and the older cues from before the gate are accepted as
they are, without a listening page and outside the approval lists: the
minetest_game files (`mods/BASE/default/sounds`, 77 files: footsteps,
digging, placing, furnaces, `player_damage`), the doors and xpanes door
sounds (8 and 2 files), mobs_redo's `mobs_punch`, `mobs_swing` and
`mobs_spell`, and the old eat and drink cues (`grug_food_eat.1`–`.3`,
`grug_alchemy_drink`). They are accepted at the kind of event they already
had (Round 35's ore digs reuse `default_dig_cracky` this way). A file used as
the cue of a new game event goes through a page like any other: the three
cues that once repurposed inherited files — the dragon-return warning
(`mobs_spell`) and the Rift Spawn fuse and burst — were picked on lane SN's
pages in Round 37 and now play their approved files (§3.4, §3.5);
`mobs_spell` ships with mobs_redo but the game no longer plays it. Its
licence: the source page (Little Robot Sound Factory, "Spell_01.wav") says CC
BY 4.0 while mobs_redo's `license.txt` says CC0, so
[CREDITS.md](../../CREDITS.md) credits it under CC BY 4.0. Five call sites in
three mods still play inherited or pre-gate files directly with
`core.sound_play` instead of through `grug_sounds.play`, and are accepted as
part of the set: the hoe's till (`default_dig_crumbly`,
`grug_farming/hoes.lua`), planting (`default_place_node`,
`grug_farming/init.lua`), the fishing bite (`default_water_footstep`,
`grug_fishing`) and two in `grug_food`: the looped eating sound
(`grug_food_eat`) and a food placed by a click (its node's own place sound).

## 2. Conventions

- **Format:** Ogg Vorbis. Effects and everything positional are mono
  (`libvorbis -q:a 3`; only mono plays positionally); music is stereo at
  q0–q1. Beds are about 30 s, loop-clean (crossfaded ends); cuts start at the
  event itself (silence trimmed).
- **Loudness reference** (the level the user judged the pages at): effects
  peak-normalised to −3 dBFS, beds and loops −20 LUFS, music −18 LUFS
  integrated. Code gains therefore mean the same across mods.
- **Names:** `grug_sounds_<event>[.<n>]`, `grug_ambience_<mood>_<what>`
  (`.1`, `.2` … are variants the engine picks at random); music
  `grug_music_<slug>.ogg` in `grug_ambience/music/`, outside every `sounds/`
  folder.
- **Licences:** one `LICENSE-media.md` row per file (file, title, author,
  source URL, licence and version, modifications), the licence checked on the
  source page per file. CC0 first, CC BY where clearly better, the p0ss pack
  (CC BY-SA 3.0) only where nothing else fits. Never NC or ND, Pixabay, BBC,
  Sonniss, a Freesound file with a GenAI tag or a TenPlus1 ambience file.
  Freesound sources are the public HQ previews (128 kbit MP3), noted in the
  row.
- **Positional or personal:** UI, dialog, progression and money cues are
  personal (`to_player`); crafting, mounts, fishing, travel, combat, voices
  and boss cues are positional on the object or position, heard by everyone
  near. A personal sound ignores `max_hear_distance` in the engine, so
  `grug_ambience` limits its personal positional loops itself (§5.3).
- **Network:** every one-shot is ephemeral, except the two ride sounds
  (gallop, wing beats), which keep a handle so they can be stopped.
  Frequent events are rate-limited per target (§3.1). Mob hearing stays off.
- **What the picks teach:** no rain, traffic, microphone wind or steady hiss
  under a bed; no animals the game does not have; no monster voices inside a
  bed; effects short and focused.

## 3. Effects (`grug_sounds`)

### 3.1 The play helper

A call site is one line: `grug_sounds.play(event, target)` with a player, any
other object (the sound follows it) or a position. `EVENTS` maps an event to
its spec: sound name, gain, pitch spread, hearing distance (default 16),
`personal`, and `interval` — at most one play per target in that many seconds
(default 0.1 s, which folds the repeats of one server step). A call inside the
interval is dropped before anything is allocated. `HOOKS` lists every event a
call site may name; the S1a and S1b fixtures check call sites, specs, shipped
files and the approval lists against each other.
`grug_sounds.item_sound(event)` gives an item definition's sound table (the
client plays it).

**Formspec clicks:** one `style_type[button,image_button,checkbox,tabheader,dropdown;sound=…]`
extends every player's formspec prepend on join and is carried into the two
formspecs that drop the prepend. The client plays it at the file's own level
(a formspec style has no gain).

### 3.2 Events that sound

- **NPC dialogs, one cue per role** (no voiced lines): quest giver (a book
  opening), vendor (coins), profession trainer, innkeeper, stable (riding
  trainer), Shipwright, Housing Steward, Crownbinder.
- **Quests:** the quest text (a page turning), abandon, complete.
- **Trade and money:** buy and sell (coins); money on a Bag of Coins deposit.
- **Progression:** level-up (a fanfare), profession learned, profession tier.
- **Crafting:** every finished craft by kind through the one progress hook
  (`grug_jobs.award_progress`): the smiths' hammer for Weaponsmith and
  Armorsmith, cooking, alchemy, the plain craft for everything else; upgrade
  and the crown; repair. **Station sounds** (Round 45 PT8, the user,
  2026-10-09): a station with a sound plays it only when a player starts a
  job there (a recipe, an enchant or an upgrade), at the station the start
  found within 4 nodes: the forge the smiths' hammer, the brewing stand the
  alchemy cue; the other stations have none, furnaces keep their fire loop.
  A recipe made at such a station has no cue at its end (the station played
  it at the start). While the sound plays at a station, another start there
  queues it once more, never more often (four starts within one sound: it
  plays twice). `grug_jobs/station_sounds.lua`. A dish or potion taken out of a furnace or brewing
  stand plays the cooking or alchemy cue; smelting stays silent.
- **Items:** equip, the cloak choice, drinking (every potion path; the
  VoxeLibre drinking sound), eating (`grug_food`), and gear breaking (Round
  35: once, when equipped gear, a bow, a tool or a hoe wears into broken,
  never on later uses of the broken item; heard on the wearer up to 8 nodes).
- **Mounts and boats:** gallop, wing beats and the boat's splash, repeated at
  their clip length while moving. Gallop and wing beats stop at once (a
  0.1 s fade) when the mount stands still and on every dismount, and the
  gallop pauses while a ground mount has been off the ground for more than
  0.5 s (a jump, a fall deeper than about one node) and starts again on
  landing (Round 45 playtest). The mount's own step reads this; there is
  no extra timer.
- **Travel** (waystone, home), **fishing** cast and catch (the splash), and
  the **"Flag me for PvP" button**.
- **Combat:** the swing into the air (the swing skills' item sound, played by
  the client); a player's hit by the equipped melee weapon's kind (swords and
  greataxes blade, daggers a lighter blade, staffs and wands blunt, the bare
  hand mobs_redo's punch), on mobs and on players; an absorb shield taking a
  hit (not a damage-over-time tick); dodge; a player's death.
- **Abilities:** one cue per theme at the caster (`CAST_SOUNDS`): Charge,
  Taunt, Hold Ground; Ice Nova, Glacial Ward, Cinderfall; Smite, Heal and
  Mend, Shield, Word of Ruin; Sidestep. Fireball and the Scout's shots sound
  through their projectile at launch and at the hit; the weapon swings sound
  through the hit.
- **Mob voices** (§3.4), **bosses** (§3.5).

### 3.3 Silent by the user's choice

Quest accept and quest progress, talent learned, achievement, enchant (its
hook stays, without a sound, and may get one later), blue, gold, bag and boss
drops, mount summon and dismount, respawn, the zone banner, every automatic
PvP flag change, critical hits, Blink, Sprint, and every refusal or
error (no refusal cue). *Why:* fewer layers, so the sounds that remain can be
told apart in play; a refusal already shows its reason as text.

### 3.4 Mob voices

Every mob definition names a voice family in `_grug_voice` (`false` for none,
the fish); registration without one is an error. `grug_mobs.apply_voice`
turns the family into the mobs_redo `sounds` table with the events that have
a file, and a sub-type inherits its base's voice. Families (`VOICES`):
humanoid, goblin, undead, mummy, skeleton, spirit, giant, elemental, canine,
feline, boar, beast, grazer, bird, crow, critter, insect, slime, reptile,
aquatic, dragon, kraken. mobs_redo plays `war_cry` when a mob takes a target,
`damage` on a health loss and `death` once; the vendored `mob_sound` routes a
`grug_sounds` event through the helper (a `GRUG PATCH`), so the spec's
per-mob interval keeps a mob hit several times a second to one grunt and a
chase to one war cry.

- **No random calls** for any family: the layer most likely to become noise.
- **Felines carry no war cry:** they stalk silently (the panther). Boars share
  the pounce but charge loudly.
- **The Carrion Crow** calls when it is hit and takes flight (the crow
  recording picked for ambience, user); it has no roaming call.
- **Wind-ups:** the dragons growl at their own wind-ups; a humanoid elite's
  wind-up, a King's and a General's signature attack play the humanoid
  special-attack cue; **every other elite's or rare's wind-up is silent**
  (user). The wind-up cue is the family's `telegraph` entry.
- **The Rift Spawn** (Round 37): its 2 s fuse plays the lava-cooling hiss
  (one of three variants) once when the fuse starts, heard to 10 nodes, and
  again if a reset fuse starts anew; the burst plays an explosion once where
  it bursts, heard to 32 nodes. Both are `grug_sounds` events (`rift_fuse`
  through mobs_redo's fuse sound, `rift_burst` in the burst itself).

### 3.5 Bosses

Dragons: roar (war cry and enrage), growl on damage, death, fire and frost
breath, the arena lightning, the dragon's wrath (personal, to each player it
hits) and the wind-up growl at most every 10 s; the return warning (Round
37): a gong at the lair once, a minute before a slain dragon returns, heard
as far as its chat line (160 nodes). Wyrmglass thin ice: one
breaking sound per break, at most one a second while a run keeps breaking ice.
Kings and the General: the signature attack. The Kraken has its own voice
family.

## 4. Ambience beds (`grug_ambience`)

### 4.1 The per-player pass

Every online player is evaluated once every 2 s in one of eight slots of
0.25 s, so no step handles every player. A pass reads the atmosphere mood the
player already carries (`grug_core.get_atmosphere`), day or night from the
world clock, the town flag and the capital of the location sampler
(`grug_map.location.in_town`, `capital_of`), one water probe and, above
ground, one node search for the loops (§4.4). A forced `/atmosphere <mood>`
preset drives the bed like the zone would; a preset that is no mood keeps
what the player had.

### 4.2 Which bed

One looped bed per player, to that player only, at the bed gain (the same
for every bed) times the player's volume:

- **Under water** (the eye in water): no bed; ambience is silent.
- **Underground** (the `underground` mood, below y −20): a cave bed, day or
  night alike; below y −500 the deep crystal-cave bed.
- **Sea water near the player** (default water around the feet): the sea bed,
  over the region's. River and lake water has no bed of its own; the region
  bed plays.
- **The region's bed** by mood: humans, elves, trolls, orcs, dwarves, undead,
  the Battlegrounds, the dragon islands and the open ocean each have a day
  bed (one or two variants). **At night** humans, elves, trolls and orcs
  switch to the night bed (crickets and night forest); the other regions keep
  their day bed.
- **In start towns and capitals** the bed plays at half gain.
- **Either music or the bed, never both** (Round 35): where music plays — in
  a capital with music on — the bed is silent; with music off the capital's
  bed plays again. Outside the capitals there is no music and the beds play
  as above. Calls and the loops of §4.4 are not affected.
- A mood without a row has no bed.

A new bed must be wanted on two passes in a row before it replaces the playing
one (walking a shore or a town edge does not swap beds every pass); diving in
or surfacing changes at once, and so does music starting or ending. A change crossfades over 3 s. Which file plays
for which mood: `D.beds` and `D.region` in `data.lua`.

### 4.3 Calls

One-shot calls at a point 40–56 nodes from the player, to that player, at
most one per 90–240 s. This round ships one: **distant thunder on the dragon
islands** (four variants). No owl, crow, hawk or wolf calls (user: fewer
layers).

### 4.4 Loops at hearths and flowing water

Positional loops to the player at nodes near them, found by one
`find_nodes_in_area` per pass in a box ±12 × ±5 × ±12 around the player.
Round 45 PT8 (the user, 2026-10-09) removed the hammer loop at the
profession forge and the cottages anvil, and its file: it played with
nobody at work; the forge now sounds when a job starts there (§3.2, the
short hammer cue).

- **fire:** a burning furnace (the public town hearths while they burn) and
  camp fires, heard to 10 nodes;
- **flowing water:** only at *flowing* water or river water, never at a
  source, heard to 14 nodes. Flowing water is rare in our worlds (6 of 768
  16 × 16 columns in twelve sampled regions, seed 12345).

At most the nearest two of each kind play; a playing loop stays while it is
among the nearest four, so walking along a river does not restart it. No loops
under water or underground. The engine ignores `max_hear_distance` for a
personal sound, so the choice drops nodes beyond their hearing distance
itself.

## 5. Music

Music is a capital feature (user ruling, Round 35: music every few minutes
broke the immersion).

- **Only in the six capitals**, not in start towns, nowhere else. A player
  counts as in a capital from the first step into its city (its protected
  footprint, where the location line names the city) until about 8 nodes
  beyond it (`grug_map/location_view.lua` `capital_at`), so walking along the
  border does not switch the music on and off. A capital is told from a start
  town by its anchor slot in the settlement registry.
- **One rotation per capital** (`D.rotations`, by settlement key), chosen by
  the capital's people; entering starts it at a random place and plays its
  tracks in turn with a pause of about 5 s between two. Leaving the city
  fades the track out over 3 s while the bed fades back in (a 3 s crossfade);
  switching music off does the same, the bed following on the next pass
  (within 2 s); entering, the bed fades out while the first track fades in
  once its download is there. A short fade, never a hard cut (§4.2).
- **On-demand delivery:** music files stay out of every `sounds/` folder, so
  the first join downloads none of them. A track is pushed to that one player
  with `core.dynamic_add_media` (`client_cache`, not ephemeral) and plays in
  the push callback: the first track after entering waits for its download;
  the next one is pushed 60 s before the playing track ends, so its download
  hides behind it. A push not confirmed within 120 s is given up and the
  rotation moves on; a refused one holds pushes for 30 s. A player with music
  off, or outside the capitals, is never pushed anything. Pushed files do not
  persist across server restarts.
- **Not played by default:** the Round 34 region pools (Land, Front and sea,
  Underground) are gone; tracks no rotation names stay in the game (`D.tracks`)
  for a possible music tab. *Master of the Feast* is in no rotation (too fast
  and high-energy for a town, the user's listening check of Round 35).
- **The main-menu theme** is `menu/theme.ogg` (the client plays it in the main
  menu), the same piece as *Fantasy Orchestral Theme*.
- Track list and lengths: `D.tracks`; credits in [CREDITS.md](../../CREDITS.md).

## 6. Settings and commands

- Per player, in player meta: **music** and **ambience**, each on or off and a
  volume of 0–100 %. Defaults: both on, music at 35 %, ambience at 100 %. A
  volume of 0 counts as off; switching a channel on at volume 0 restores its
  default.
- **Help → Sound** (a sub-page of the Help tab): a checkbox and a volume
  dropdown in 5 % steps per channel, applied at once (fades of 0.5 s).
- **Chat:** `/music [on|off|<0-100>]` and `/ambience [on|off|<0-100>]`; without
  a word they report the current setting.
- Switching music off stops a playing track and all further pushes (in a
  capital the bed returns); switching ambience off fades the bed and the loops
  out. The client's own volume
  applies on top.
