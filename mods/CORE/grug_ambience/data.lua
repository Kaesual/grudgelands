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
-- Round 34 ships the ambience as a pilot (round34-plan.md §2.2a): beds for
-- the human region only, no ambient calls but distant thunder on the dragon
-- islands. The code reads everything from these tables, so a later zone is
-- a bed list plus a `region` row (and a listening page), nothing else.

local D = {}

-- Base gains before the player's volume (tuned in the user's GUI check; the
-- files are levelled to one reference: beds and loops -20 LUFS, music -18
-- LUFS, calls peak -3 dBFS). The bed starts well below the listening page's
-- level: the user found the beds too present there.
D.gains = {
	bed = 0.2,
	-- Factor on the bed inside start towns and capitals.
	town_bed = 0.5,
	call = 0.35,
	music = 0.6,
	forge = 0.6,
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
-- (none ships this round, so those states are silent).
D.beds = {
	human = {"grug_ambience_human_meadow"}, -- S2 B1.1
	night = {"grug_ambience_night_forest"}, -- S2 B9.1
}

-- Region beds by atmosphere mood: the day bed and, optionally, the night
-- bed. A mood without a row has no bed.
D.region = {
	human = {day = "human", night = "night"},
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
D.emitter_nodes = {
	["grug_jobs:forge"] = "forge",
	["grug_decor:cottages_anvil"] = "forge",
	-- A burning furnace: the public town hearths are default:furnace and
	-- turn into this node while they burn (grug_jobs station_nodes.lua).
	["default:furnace_active"] = "fire",
	["grug_nodes:camp_fire"] = "fire",
	["default:water_flowing"] = "water",
	["default:river_water_flowing"] = "water",
}
D.emitters = {
	forge = {sound = "grug_ambience_forge", hear = 16, limit = 2}, -- S2 E1.2
	fire = {sound = "grug_ambience_fire", hear = 10, limit = 2}, -- S2 E2.1
	water = {sound = "grug_ambience_stream_pond", hear = 14, limit = 2}, -- S2 B12.2
}
-- The box searched around the player (half sizes).
D.emitter_reach = {x = 12, y = 5, z = 12}

-- Music. Tracks: id -> file (in music/) and length in seconds (the shipped
-- file's; the scheduler has no other way to know when a track ends).
D.tracks = {
	memories_of_stone = {file = "grug_music_memories_of_stone.ogg", seconds = 331}, -- R32 M1
	achaidh_cheide = {file = "grug_music_achaidh_cheide.ogg", seconds = 135}, -- R32 M2
	soliloquy = {file = "grug_music_soliloquy.ogg", seconds = 225}, -- R32 M4
	fantasy_orchestral_theme = {file = "grug_music_fantasy_orchestral_theme.ogg",
		seconds = 192}, -- R32 M6
	forest_walk = {file = "grug_music_forest_walk.ogg", seconds = 218}, -- R32 M3
	town_theme = {file = "grug_music_town_theme.ogg", seconds = 98}, -- R34 D.1
	thatched_villagers = {file = "grug_music_thatched_villagers.ogg", seconds = 246}, -- R34 D.2
	minstrel_guild = {file = "grug_music_minstrel_guild.ogg", seconds = 186}, -- R34 D.3
	master_of_the_feast = {file = "grug_music_master_of_the_feast.ogg", seconds = 229}, -- R34 D.4
	folk_round = {file = "grug_music_folk_round.ogg", seconds = 184}, -- R34 D.5
	teller_of_the_tales = {file = "grug_music_teller_of_the_tales.ogg", seconds = 213}, -- R34 D.6
	village_consort = {file = "grug_music_village_consort.ogg", seconds = 215}, -- R34 D.7
	a_dragons_lullaby = {file = "grug_music_a_dragons_lullaby.ogg", seconds = 169}, -- S2 M7
	-- S2 M8: the first 2:00 (the calm part) with a fade-out.
	the_great_sea = {file = "grug_music_the_great_sea.ogg", seconds = 120},
	-- S2 M10: the first 3:20 with a fade-out.
	katabasis_i = {file = "grug_music_katabasis_i.ogg", seconds = 200},
	permafrost = {file = "grug_music_permafrost.ogg", seconds = 449}, -- S2 M11
}

-- Pools (§2.1 ruling 3 and 4; a track may sit in several).
D.pools = {
	land = {"memories_of_stone", "achaidh_cheide", "soliloquy",
		"fantasy_orchestral_theme"},
	front = {"forest_walk", "a_dragons_lullaby", "the_great_sea"},
	underground = {"katabasis_i", "permafrost"},
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
