-- Ambience and music data (Round 34 lane S2). PURE data, read by init.lua
-- and the portable fixture. Sound names follow round34-plan.md §3:
-- `grug_ambience_<mood>_<what>` for beds and calls in sounds/, music
-- `grug_music_<slug>.ogg` in music/ (outside every sounds/ folder, pushed per
-- player). Every name below must be a shipped file on the approved list
-- (tools/r34_s2/approved.txt, the user's picks); init.lua additionally plays
-- only names whose file it finds, so a missing file stays silent.
-- Page numbers in the comments: "R32 x.y" the Round 32 listening page, "A/B/
-- C/D x.y" the Round 34 page, "S2 x.y" this lane's preview page.

local D = {}

-- Base gains before the player's volume (tuned in the user's GUI check; the
-- files are levelled to one reference: beds -20 LUFS, music -18 LUFS, calls
-- and loops peak -3 dBFS).
D.gains = {
	bed = 0.5,
	-- Factor on the bed inside start towns and capitals.
	town_bed = 0.5,
	call = 0.35,
	music = 0.6,
	forge = 0.6,
	fire = 0.5,
}

-- Seconds between two calls for one player: a random value in this range.
D.call_gap = {40, 150}

-- The crossfade between two beds and the fade of a volume change, seconds.
D.crossfade = 3
D.volume_fade = 0.5

-- Beds: key -> sound names; one is picked at random each time the bed
-- starts and loops until the state changes.
D.beds = {
	human = {"grug_ambience_human_meadow", "grug_ambience_human_summer"},
	elf = {"grug_ambience_elf_blackbirds", "grug_ambience_elf_birdsong",
		"grug_ambience_elf_forest"},
	troll = {"grug_ambience_troll_jungle", "grug_ambience_troll_hills",
		"grug_ambience_elf_birdsong"},
	orc = {"grug_ambience_orc_desert", "grug_ambience_orc_wind",
		"grug_ambience_orc_crickets", "grug_ambience_orc_steppe"},
	dwarf = {"grug_ambience_dwarf_gusts", "grug_ambience_dwarf_storm",
		"grug_ambience_orc_wind"},
	undead = {"grug_ambience_undead_graveyard", "grug_ambience_undead_swamp",
		"grug_ambience_undead_lake"},
	battlegrounds = {"grug_ambience_battlegrounds_wind",
		"grug_ambience_battlegrounds_gusts"},
	dragon_island = {"grug_ambience_dragon_island_surf",
		"grug_ambience_dragon_island_coast"},
	ocean = {"grug_ambience_sea_waves", "grug_ambience_sea_surf"},
	night = {"grug_ambience_night_forest", "grug_ambience_night_crickets",
		"grug_ambience_night_owl"},
	underground = {"grug_ambience_underground_dungeon",
		"grug_ambience_underground_drips", "grug_ambience_underground_dark",
		"grug_ambience_underground_creepy"},
	underground_deep = {"grug_ambience_underground_crystal"},
	sea = {"grug_ambience_sea_waves", "grug_ambience_sea_surf"},
	stream = {"grug_ambience_stream_forest", "grug_ambience_stream_pond"},
	underwater = {"grug_ambience_underwater"},
}

-- Region beds by atmosphere mood: the day bed and, where crickets and owls
-- fit, the night bed. Snow, blight, the front, the islands and the open sea
-- keep their own bed at night.
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
-- player (positional, heard up to `hear` nodes), `time` "day", "night" or
-- "any". Thunder has four variants (.1-.4, picked by the engine).
D.calls = {
	owl = {sound = "grug_ambience_call_owl", time = "night",
		moods = {human = true, elf = true, troll = true, dwarf = true},
		distance = {14, 24}, hear = 48},
	wolf = {sound = "grug_ambience_call_wolf", time = "night",
		moods = {human = true, elf = true, dwarf = true, undead = true},
		distance = {24, 36}, hear = 64},
	crow = {sound = "grug_ambience_call_crow", time = "day",
		moods = {undead = true}, distance = {12, 24}, hear = 48},
	crows = {sound = "grug_ambience_call_crows", time = "day",
		moods = {undead = true}, distance = {16, 28}, hear = 48},
	hawk = {sound = "grug_ambience_call_hawk", time = "day",
		moods = {dwarf = true}, distance = {16, 28}, hear = 64},
	thunder = {sound = "grug_ambience_call_thunder", time = "any",
		moods = {dragon_island = true, battlegrounds = true},
		distance = {40, 56}, hear = 96},
}

-- Forge and fire loops at nodes near the player (positional, to that
-- player only): node name -> kind, kind -> sound and hearing distance.
D.emitter_nodes = {
	["grug_jobs:forge"] = "forge",
	["grug_decor:cottages_anvil"] = "forge",
	["grug_decor:xdecor_cauldron"] = "fire",
	["grug_nodes:camp_fire"] = "fire",
}
D.emitters = {
	forge = {sound = "grug_ambience_forge", hear = 16},
	fire = {sound = "grug_ambience_fire", hear = 10},
}
-- The box searched around the player (half sizes) and how many emitters of
-- each kind play at once (the nearest).
D.emitter_reach = {x = 12, y = 5, z = 12}
D.emitter_limit = 2

-- Music. Tracks: id -> file (in music/) and length in seconds (the shipped
-- file's; the scheduler has no other way to know when a track ends).
D.tracks = {
	memories_of_stone = {file = "grug_music_memories_of_stone.ogg", seconds = 331},
	achaidh_cheide = {file = "grug_music_achaidh_cheide.ogg", seconds = 135},
	soliloquy = {file = "grug_music_soliloquy.ogg", seconds = 225},
	fantasy_orchestral_theme = {file = "grug_music_fantasy_orchestral_theme.ogg",
		seconds = 192},
	forest_walk = {file = "grug_music_forest_walk.ogg", seconds = 218},
	town_theme = {file = "grug_music_town_theme.ogg", seconds = 98},
	thatched_villagers = {file = "grug_music_thatched_villagers.ogg", seconds = 246},
	minstrel_guild = {file = "grug_music_minstrel_guild.ogg", seconds = 186},
	master_of_the_feast = {file = "grug_music_master_of_the_feast.ogg", seconds = 229},
	folk_round = {file = "grug_music_folk_round.ogg", seconds = 184},
	teller_of_the_tales = {file = "grug_music_teller_of_the_tales.ogg", seconds = 213},
	village_consort = {file = "grug_music_village_consort.ogg", seconds = 215},
}

-- Pools (§2.1 ruling 3 and 4; a track may sit in several).
D.pools = {
	land = {"memories_of_stone", "achaidh_cheide", "soliloquy",
		"fantasy_orchestral_theme"},
	front = {"forest_walk"},
	underground = {},
	town = {"town_theme", "thatched_villagers", "minstrel_guild",
		"master_of_the_feast", "folk_round", "teller_of_the_tales",
		"village_consort", "achaidh_cheide"},
}

-- Atmosphere mood -> pool.
D.music_groups = {
	human = "land", elf = "land", troll = "land", orc = "land",
	dwarf = "land", undead = "land",
	battlegrounds = "front", dragon_island = "front", ocean = "front",
	underground = "underground",
}

-- Scheduler timings in seconds (ruling 3): the first track 30-90 s after
-- joining, a 3-8 min pause after each track, the next file pushed 60 s
-- before the pause ends, a push given up after 120 s, an empty pool
-- retried after 30 s, music switched back on plays after 5-15 s.
D.music = {
	first = {30, 90},
	pause = {180, 480},
	push_lead = 60,
	push_timeout = 120,
	empty_retry = 30,
	resume = {5, 15},
}

return D
