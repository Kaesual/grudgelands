-- Ambience and music data (Round 34 lane S2). PURE data, read by init.lua
-- and the portable fixture. Sound names follow round34-plan.md §3:
-- `grug_ambience_<mood>_<what>` for beds and calls in sounds/, music
-- `grug_music_<slug>.ogg` in music/ (outside every sounds/ folder, pushed per
-- player). Every name below is a shipped file on the approved list
-- (tools/r34_s2/approved.txt, the user's picks); init.lua additionally plays
-- only names whose file it finds, so a missing file stays silent.
-- Page numbers in the comments: "R32 x.y" the Round 32 listening page,
-- "R34 x.y" the Round 34 page, "S2 x.y" this lane's preview page.
--
-- Round 34 (round34-plan.md §2.2a): after the human pilot the user picked a
-- bed for every zone, all at one quiet gain; no ambient calls but distant
-- thunder on the dragon islands. The code reads everything from these
-- tables, so another bed is a name here (and a listening page), nothing else.
--
-- Round 35 (round35-plan.md §2.8): music is a capital feature. It plays only
-- in the six capitals, each with its own rotation (D.rotations), and where it
-- plays the bed is silent; the region pools of Round 34 are gone, their
-- tracks stay in D.tracks.

local D = {}

-- Base gains before the player's volume (tuned in the user's GUI check; the
-- files are levelled to one reference: beds and loops -20 LUFS, music -18
-- LUFS, calls peak -3 dBFS). Beds play well below the listening page's
-- level (the user: the pilot was good at 0.25, "maybe minimally quieter").
D.gains = {
	bed = 0.2,
	-- Factor on the bed inside start towns and capitals (in a capital the
	-- bed plays only while the player has music off).
	town_bed = 0.5,
	call = 0.35,
	music = 0.6,
	fire = 0.5,
	water = 0.5,
}

-- Seconds between two calls for one player: a random value in this range.
D.call_gap = {90, 240}

-- The crossfade between two beds and the fade of a volume change, seconds.
D.crossfade = 3
D.volume_fade = 0.5

-- Beds: key -> sound names; one is picked at random each time the bed
-- starts and loops until the state changes. Keys rules.lua knows besides
-- the region rows: underwater, underground, underground_deep, sea, stream
-- (no stream and no underwater bed ships: those states fall back to the
-- region bed resp. stay silent; flowing water has its own loop below).
D.beds = {
	human = {"grug_ambience_human_meadow"}, -- S2 B1.1
	elf = {"grug_ambience_elf_blackbirds", "grug_ambience_elf_forest"}, -- S2 B2.1, B2.3
	troll = {"grug_ambience_elf_birdsong", "grug_ambience_troll_jungle"}, -- S2 B2.2, B3.1
	orc = {"grug_ambience_orc_steppe"}, -- S2 B4.4
	dwarf = {"grug_ambience_orc_wind", "grug_ambience_dwarf_storm"}, -- S2 B4.2, B5.2
	undead = {"grug_ambience_undead_graveyard", "grug_ambience_undead_lake"}, -- S2 B6.1, B6.3
	battlegrounds = {"grug_ambience_battlegrounds_gusts"}, -- S2 B7.2
	dragon_island = {"grug_ambience_dragon_island_coast"}, -- S2 B8.2
	-- S2 B11.1: the open ocean, and sea water near the player anywhere.
	ocean = {"grug_ambience_sea_waves"},
	sea = {"grug_ambience_sea_waves"},
	night = {"grug_ambience_night_forest", "grug_ambience_night_crickets"}, -- S2 B9.1, B9.2
	underground = {"grug_ambience_underground_dungeon", "grug_ambience_underground_dark",
		"grug_ambience_underground_creepy"}, -- S2 B10.1, B10.3, B10.4
	underground_deep = {"grug_ambience_underground_crystal"}, -- S2 B10.5, below deep_y only
}

-- Region beds by atmosphere mood: the day bed and, optionally, the night
-- bed (crickets for the humans, elves, trolls and orcs; the other regions
-- keep their own bed at night). A mood without a row has no bed.
D.region = {
	human = {day = "human", night = "night"},
	elf = {day = "elf", night = "night"},
	troll = {day = "troll", night = "night"},
	orc = {day = "orc", night = "night"},
	dwarf = {day = "dwarf"},
	undead = {day = "undead"},
	battlegrounds = {day = "battlegrounds"},
	dragon_island = {day = "dragon_island"},
	ocean = {day = "ocean"},
}

-- Below this y the underground bed is the deep one (the Silversteel tier,
-- world.md mining depths).
D.deep_y = -500

-- Calls: one-shots placed at a random point `distance` nodes from the
-- player (positional, to that player only), `time` "day", "night" or
-- "any". Thunder has four variants (.1-.4, picked by the engine; R34
-- C11.1-C11.4).
D.calls = {
	thunder = {sound = "grug_ambience_call_thunder", time = "any",
		moods = {dragon_island = true}, distance = {40, 56}},
}

-- Loops at nodes near the player (positional, to that player only): node
-- name -> kind, kind -> sound, hearing distance (the engine ignores
-- max_hear_distance for a to_player sound, so init.lua drops nodes farther
-- than `hear` itself; the search box below bounds it too) and how many of
-- that kind play at once (the nearest; a playing one stays while it is in reach and
-- among the nearest few, so walking along a river does not restart them).
-- init.lua adds every other registered flowing liquid whose source is one
-- of the two waters to "water" (never a source node).
-- Round 45 PT8 (the user, 2026-10-09): no hammer loop at forges and anvils
-- any more, it sounded with nobody at work; the forge plays its sound when a
-- job starts there (grug_jobs/station_sounds.lua).
D.emitter_nodes = {
	-- A burning furnace: the public town hearths are default:furnace and
	-- turn into this node while they burn (grug_jobs station_nodes.lua).
	["default:furnace_active"] = "fire",
	["grug_nodes:camp_fire"] = "fire",
	["default:water_flowing"] = "water",
	["default:river_water_flowing"] = "water",
}
D.emitters = {
	fire = {sound = "grug_ambience_fire", hear = 10, limit = 2}, -- S2 E2.1
	water = {sound = "grug_ambience_stream_pond", hear = 14, limit = 2}, -- S2 B12.2
}
-- The box searched around the player (half sizes).
D.emitter_reach = {x = 12, y = 5, z = 12}

-- Music. Tracks: id -> file (in music/), length in seconds (the shipped
-- file's; the scheduler has no other way to know when a track ends), and the
-- title and artist the "Now playing" box under the minimap shows (0.45.1,
-- grug_map minimap.lua), as LICENSE-media.md credits them (one shortened
-- display title, marked below). Every shipped
-- track is listed, also one no rotation names: Master of the Feast (too fast
-- and high-energy for a town, the user's listening check of Round 35), kept
-- for a possible music tab (round35-plan.md §2.8).
D.tracks = {
	memories_of_stone = {file = "grug_music_memories_of_stone.ogg", seconds = 331,
		title = "Memories Of Stone", artist = "Scott Buckley"}, -- R32 M1
	achaidh_cheide = {file = "grug_music_achaidh_cheide.ogg", seconds = 135,
		title = "Achaidh Cheide", artist = "Kevin MacLeod"}, -- R32 M2
	soliloquy = {file = "grug_music_soliloquy.ogg", seconds = 225,
		title = "Soliloquy", artist = "Matthew Pablo"}, -- R32 M4
	fantasy_orchestral_theme = {file = "grug_music_fantasy_orchestral_theme.ogg",
		seconds = 192, title = "Fantasy Orchestral Theme", artist = "joth"}, -- R32 M6
	forest_walk = {file = "grug_music_forest_walk.ogg", seconds = 218,
		title = "Forest Walk", artist = "Alexander Nakarada"}, -- R32 M3
	town_theme = {file = "grug_music_town_theme.ogg", seconds = 98,
		-- Shown as "Town Theme" (the user, 0.45.1); the source title is
		-- "Town Theme RPG", which LICENSE-media.md keeps.
		title = "Town Theme", artist = "cynicmusic"}, -- R34 D.1
	thatched_villagers = {file = "grug_music_thatched_villagers.ogg", seconds = 246,
		title = "Thatched Villagers", artist = "Kevin MacLeod"}, -- R34 D.2
	minstrel_guild = {file = "grug_music_minstrel_guild.ogg", seconds = 186,
		title = "Minstrel Guild", artist = "Kevin MacLeod"}, -- R34 D.3
	master_of_the_feast = {file = "grug_music_master_of_the_feast.ogg", seconds = 229,
		title = "Master of the Feast", artist = "Kevin MacLeod"}, -- R34 D.4
	folk_round = {file = "grug_music_folk_round.ogg", seconds = 184,
		title = "Folk Round", artist = "Kevin MacLeod"}, -- R34 D.5
	teller_of_the_tales = {file = "grug_music_teller_of_the_tales.ogg", seconds = 213,
		title = "Teller of the Tales", artist = "Kevin MacLeod"}, -- R34 D.6
	village_consort = {file = "grug_music_village_consort.ogg", seconds = 215,
		title = "Village Consort", artist = "Kevin MacLeod"}, -- R34 D.7
	a_dragons_lullaby = {file = "grug_music_a_dragons_lullaby.ogg", seconds = 169,
		title = "A Dragon's Lullaby", artist = "Scott Buckley"}, -- S2 M7
	-- S2 M8: the first 2:00 (the calm part) with a fade-out.
	the_great_sea = {file = "grug_music_the_great_sea.ogg", seconds = 120,
		title = "The Great Sea", artist = "Scott Buckley"},
	-- S2 M10: the first 3:20 with a fade-out.
	katabasis_i = {file = "grug_music_katabasis_i.ogg", seconds = 200,
		title = "Katabasis I", artist = "Scott Buckley"},
	permafrost = {file = "grug_music_permafrost.ogg", seconds = 449,
		title = "Permafrost", artist = "Scott Buckley"}, -- S2 M11
}

-- One rotation per capital (settlement key -> track ids, played in this
-- order from a random start on entering; a track may sit in several). By
-- the capital's people (Round 35, confirmed by the user after listening):
D.rotations = {
	-- Humans: the stately main theme and the court and market consorts.
	highcourt = {"fantasy_orchestral_theme", "town_theme", "village_consort",
		"minstrel_guild"},
	-- Dwarves: the fiddle over stone, a thatched village tune and the
	-- mountain cold.
	dur_brannoc = {"memories_of_stone", "thatched_villagers", "permafrost"},
	-- Elves: calm Celtic airs, soft strings and a lullaby.
	lethariel = {"achaidh_cheide", "soliloquy", "folk_round", "a_dragons_lullaby"},
	-- Orcs: the wide horizon of the steppe, campfire tales, a dramatic march.
	gor_drazhak = {"the_great_sea", "teller_of_the_tales", "forest_walk"},
	-- Trolls: forest and water round the cenote, a lullaby, a lively village.
	kezamba = {"forest_walk", "the_great_sea", "a_dragons_lullaby",
		"thatched_villagers"},
	-- Undead: the descent, the cold, sombre tales and a lonely soliloquy.
	nhal_veyr = {"katabasis_i", "permafrost", "teller_of_the_tales", "soliloquy"},
}

-- Scheduler timings in seconds (round35-plan.md §2.8): a pause of `pause`
-- between two tracks; the next file pushed `push_lead` seconds before the
-- playing track ends (so its download hides behind it; the first track after
-- entering a capital may wait for its own); a push given up after
-- `push_timeout`; after a refused push nothing is pushed for `retry`; the
-- track fades out over `fade_out` on leaving the capital or switching music
-- off.
D.music = {
	pause = 5,
	push_lead = 60,
	push_timeout = 120,
	retry = 30,
	fade_out = 3,
}

return D
