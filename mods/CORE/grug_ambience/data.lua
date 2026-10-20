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
	-- The burning furnaces: 60 % of the fire gain (Round 47 ruling 15, the
	-- user, 2026-10-13); camp fires keep `fire`.
	furnace = 0.3,
	water = 0.5,
}

-- The fade of a loop whose node was dug or destroyed, seconds (Round 47
-- ruling 16: silent at once, without a click).
D.stop_fade = 0.25

-- Seconds between two calls for one player: a random value in this range.
D.call_gap = {90, 240}

-- The crossfade between two beds and the fade of a volume change, seconds.
D.crossfade = 3
D.volume_fade = 0.5

-- Round 52 (round52-ambience-plan.md §1-§2): the region bed follows the
-- BIOME under the player, bundled into sound groups, instead of the race
-- zone; three loops play at once (surface, cave, wind) at levels that follow
-- the height relative to the terrain (D.layers). Zone overrides by
-- atmosphere mood come before the biome.

-- Biome id (grug_zones.biome_at, the full `grug_` id of
-- wp40/r7_r6_manifest.lua SURFACE_ROWS) -> sound group. Moving between two
-- biomes of one group changes nothing.
D.groups = {
	grug_meadows = "temperate", grug_deep_forest = "temperate",
	grug_elf_forest = "temperate", grug_pine_hills = "temperate",
	grug_savanna = "savanna",
	grug_deep_jungle = "jungle", grug_jungle_fringe = "jungle", grug_jungle_edge = "jungle",
	grug_badlands = "badlands", grug_badlands_east = "badlands",
	grug_swamp = "swamp",
	grug_crags = "crags",
	grug_crags_snowy = "crags_snowy",
	grug_blight = "blight", grug_bone_forest = "blight",
}

-- Start towns sound like they look (0.52.1, the user, 2026-10-20): inside a
-- start town (grug_map's location: a town, not a capital) the sound key is
-- the group of the biome its composition's ground is, whatever biome cell
-- the town stands on (a start town can sit in a swamp cell). The ground is
-- the race palette's `ground` role (grug_mapgen wp13/palette.lua, laid by
-- each composition over the town), matched to the biome whose top node it
-- is (wp40/r7_r6_manifest.lua SURFACE_ROWS); the orcs' dry grass is the
-- savanna's (its top is the dry-dirt variant). tools/r34_s2 derives the
-- table from those files. The nearest start anchor within town_reach
-- (half the start town's 152-node footprint, rounded up) is the town.
D.town_looks = {
	dwarf = "grug_pine_hills", -- dirt with coniferous litter
	human = "grug_meadows", -- dirt with grass
	elf = "grug_elf_forest", -- dirt with silver litter
	undead = "grug_blight", -- blight dirt
	orc = "grug_savanna", -- dirt with dry grass
	troll = "grug_jungle_edge", -- dirt with rainforest litter
}
D.town_reach = 80

-- Biomes that keep the sound key the player brings (0.52.1): the beach is
-- a palette patch that lies mostly far from the sea (seed 12345, a 32-node
-- grid: 32 of the 44 Gravesalt samples more than 64 nodes from it), so it
-- plays the neighbouring land's bed, and the surf comes from the sea share
-- like on every other coast (D.sea).
D.neutral = {grug_beach = true}

-- Atmosphere moods that override the biome group: the Battlegrounds, the
-- dragon islands (with their channels) and the open ocean. An ownerless
-- column (no biome: the deep ocean) is the ocean as well, also with the
-- atmosphere layer off.
D.overrides = {battlegrounds = true, dragon_island = true, ocean = true}

-- Beds: key -> sound names; one is picked at random each time the bed
-- starts and loops until the state changes. Besides the D.region rows:
-- the sea layer's surf (D.sea), stream (river water near the player; no
-- stream bed ships, so river and lake water keeps the region bed),
-- underwater (the surface layer while the eye is in water, at the full bed
-- level, nothing else playing), the wind layer, the cave layer and its deep
-- variant. Page ids "SND" are the Round 52 cuts the user
-- approved (tools/r52_snd/picks.md, the ambience plan's §4 sources).
D.beds = {
	temperate = {"grug_ambience_human_meadow", "grug_ambience_elf_forest"}, -- S2 B1.1, B2.3
	temperate_night = {"grug_ambience_night_forest", "grug_ambience_night_crickets",
		"grug_ambience_night_owl_crickets", "grug_ambience_night_insects"}, -- S2 B9.1, B9.2, SND c_ni4, n_328293
	savanna = {"grug_ambience_orc_steppe"}, -- S2 B4.4
	savanna_night = {"grug_ambience_night_crickets"}, -- S2 B9.2
	jungle = {"grug_ambience_troll_jungle", "grug_ambience_elf_birdsong"}, -- S2 B3.1, B2.2
	jungle_night = {"grug_ambience_jungle_night_crickets", "grug_ambience_night_tropical",
		"grug_ambience_jungle_night_hills", "grug_ambience_jungle_night_rainforest"}, -- SND n_450537, n_516157, n_635951, n_871624
	badlands = {"grug_ambience_badlands_quiet", "grug_ambience_badlands_crickets"}, -- SND n_352597, c_or3
	badlands_night = {"grug_ambience_badlands_crickets"}, -- SND c_or3
	swamp = {"grug_ambience_swamp_frogs"}, -- SND c_un4
	swamp_night = {"grug_ambience_swamp_frogs", "grug_ambience_swamp_evening",
		"grug_ambience_night_tropical"}, -- SND c_un4, n_325501, n_516157
	-- §6.3: the two short sources stay in the pool with Troodos.
	crags = {"grug_ambience_crags_mountain", "grug_ambience_crags_birds",
		"grug_ambience_crags_birds_clear"}, -- SND n_393693, n_733782, n_855953
	crags_snowy = {"grug_ambience_snow_afternoon"}, -- SND c_dw2, day and night (§6.2)
	blight = {"grug_ambience_undead_lake"}, -- S2 B6.3
	-- Ruling 2: the Battlegrounds get a bed of their own.
	battlegrounds = {"grug_ambience_battlegrounds_fields"}, -- SND n_164272
	dragon_island = {"grug_ambience_dragon_island_coast"}, -- S2 B8.2
	-- S2 B11.1: the open ocean, and the surf of the sea layer (D.sea).
	ocean = {"grug_ambience_sea_waves"},
	sea = {"grug_ambience_sea_waves"},
	-- 0.52.1: the user's two picks of the UW page (#2, #4), one pool, so a
	-- dive starts one of them at random and both can be compared in game.
	underwater = {"grug_ambience_underwater_dcsfx", "grug_ambience_underwater_verberne"},
	-- The layers (ruling 2: the Battlegrounds' gusts are the wind at height).
	wind = {"grug_ambience_battlegrounds_gusts"}, -- S2 B7.2
	cave = {"grug_ambience_underground_dungeon"}, -- S2 B10.1
	cave_deep = {"grug_ambience_underground_crystal"}, -- S2 B10.5, below deep_y only
}

-- The surface bed by sound key (a group or an override): the day bed and,
-- optionally, the night bed. A night bed without a shipped file falls back
-- to the day bed; `night = false` is silence at night (the crags, §6.2). A
-- key without a row has no bed. `surf` (0.52.1, rules.lua surf_mode): "only"
-- where the key is the sea itself (the surf plays alone), "none" where the
-- key has its own coast bed (the dragon islands: no surf beside it); every
-- other key blends into the surf at the coast.
D.region = {
	temperate = {day = "temperate", night = "temperate_night"},
	savanna = {day = "savanna", night = "savanna_night"},
	jungle = {day = "jungle", night = "jungle_night"},
	badlands = {day = "badlands", night = "badlands_night"},
	swamp = {day = "swamp", night = "swamp_night"},
	crags = {day = "crags", night = false},
	crags_snowy = {day = "crags_snowy"},
	blight = {day = "blight"},
	battlegrounds = {day = "battlegrounds"},
	dragon_island = {day = "dragon_island", surf = "none"},
	ocean = {day = "ocean", surf = "only"},
}

-- The sea layer (0.52.1, round52-ambience-plan.md §8): the surf, by the
-- share of sea columns (grug_zones.water_query_at: bay, belt, channel, open
-- sea; never a lake, a river or a swamp pool) among the columns every
-- `step` nodes within `radius` of the player (49 samples). On land the surf
-- takes share / full_share of the surface level and the region bed the
-- rest: a straight coast reads about a half at the water line (full surf)
-- and nothing `radius` nodes inland. On a sea column, boat or swimming or
-- flying over it, only the surf plays. Both follow the surface layer's
-- height curve (D.layers.surface).
D.sea = {step = 4, radius = 16, full_share = 0.5}

-- The layers' levels (ruling 7, linear throughout), as shares of the bed
-- level (D.gains.bed times the player's volume, halved in towns), by the
-- height above the surface reference (grug_core.depth_below_surface: the
-- terrain, or the water surface over water):
--   surface  100 % from -0 up to +up_full, 0 % at -down and at +up_zero;
--   wind     0 % at +from, `level` at +full and above;
--   peak     the wind on high ground, only within max_depth of the surface
--            or above it: 0 at the absolute y, `level` at y + ramp (§6.4:
--            capped at 25 %, starting about 15 nodes below typical peak
--            tops); the wind layer plays the higher of the two. Measured on
--            seed 12345 (tools/r52_amb engine.sh calib, terrain on a 32-node
--            grid): the highest sample of each 256-node cell is, for the
--            snowy crags, 230 in the median (p75 344, p90 463, max 527),
--            for the crags 125 (p75 284, max 478), for the pine hills only
--            21 (p90 131, max 157); so the start is 15 below the snowy
--            crags' typical top, and the pine hills stay below it;
--   cave     only while the cave probe says "cave": 0 at depth `from`,
--            `level` at depth `full` and below.
D.layers = {
	surface = {down = 15, up_full = 10, up_zero = 60},
	wind = {from = 30, full = 100, level = 0.5},
	peak = {y = 215, ramp = 15, level = 0.25, max_depth = 4},
	cave = {from = 4, full = 16, level = 0.4},
}

-- Seconds over which a layer follows its level (one pass).
D.layer_fade = 2

-- The cave probe (§3.2 step 6): open air (a node that is not walkable and
-- no liquid) sampled on a sparse grid round the player's feet: every
-- `grid_xz` offset on x and z, every `grid_y` offset above the feet. An
-- unloaded node counts as solid. A share of open nodes at or above
-- `threshold` is a real cave; a dug tunnel stays below it. The probe runs
-- only deeper than `min_depth`. Calibrated in the engine (tools/r52_amb
-- engine.sh calib, seed 12345, 4,502 standable spots in natural v7 caves
-- 6-150 nodes down): natural caves read 0.23 at the 5th percentile, 0.43 in
-- the median, 97 % of the spots at 0.20 or more; a dug 1 x 2 tunnel reads
-- 0.05-0.09, a 3 x 3 corridor 0.07-0.11 (0.19 at a hall's mouth), a
-- 17 x 6 x 16 hall 0.24-0.67 (a large dug hall counts as a cave, accepted).
-- The narrowest natural tunnels (about 3 % of the spots) stay silent.
D.cave = {
	grid_xz = {-4, -2, 0, 2, 4},
	grid_y = {-1, 1, 3},
	threshold = 0.2,
	min_depth = 4,
}

-- Below this y the cave layer plays the deep bed (the Silversteel tier,
-- world.md mining depths), with a band of deep_band nodes either side: in
-- below deep_y - deep_band, out above deep_y + deep_band, so a cave floor
-- at -500 does not swap the two beds back and forth.
D.deep_y = -500
D.deep_band = 2

-- Calls: one-shots placed at a random point `distance` nodes from the
-- player (positional, to that player only), `time` "day", "night" or
-- "any", where the player's sound key (a group or a zone override) is in
-- `keys` or the biome under the player in `biomes`; a call with `surface`
-- plays only while the surface layer is at least that share. Thunder has
-- four variants (.1-.4, picked by the engine; R34 C11.1-C11.4) and keeps
-- its rule; the animal calls of §3.2 step 8 (two variants each, SND
-- c_ca_*) play 24-40 nodes away and only while the surface layer is at
-- 50 % or more (no hawks in a mine, no wolves on a tower). The wolves' pine
-- hills are a biome of the temperate group, hence their `biomes` list.
D.calls = {
	thunder = {sound = "grug_ambience_call_thunder", time = "any",
		keys = {dragon_island = true}, distance = {40, 56}},
	crow = {sound = "grug_ambience_call_crow", time = "day",
		keys = {battlegrounds = true, blight = true}, distance = {24, 40}, surface = 0.5},
	hawk = {sound = "grug_ambience_call_hawk", time = "day",
		keys = {crags = true, badlands = true}, distance = {24, 40}, surface = 0.5},
	owl = {sound = "grug_ambience_call_owl", time = "night",
		keys = {temperate = true}, distance = {24, 40}, surface = 0.5},
	wolf = {sound = "grug_ambience_call_wolf", time = "night",
		keys = {crags = true}, biomes = {grug_pine_hills = true}, distance = {24, 40}, surface = 0.5},
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
-- Round 47 (rulings 14-16, the user, 2026-10-13): both burning furnaces are
-- their own kind, the same fire loop at a lower gain; a kind with
-- `stop_on_destruct` fades out at once for every listener when its node is
-- dug or destroyed (init.lua hooks the node's on_destruct), instead of on
-- the next pass.
D.emitter_nodes = {
	-- A burning furnace: the public town hearths are default:furnace and
	-- turn into this node while they burn (grug_jobs station_nodes.lua).
	["default:furnace_active"] = "furnace",
	-- The Dual Furnace while it burns (grug_jobs workspaces.lua swaps it).
	["grug_smelting:dual_furnace_active"] = "furnace",
	["grug_nodes:camp_fire"] = "fire",
	["default:water_flowing"] = "water",
	["default:river_water_flowing"] = "water",
}
D.emitters = {
	fire = {sound = "grug_ambience_fire", hear = 10, limit = 2}, -- S2 E2.1
	furnace = {sound = "grug_ambience_fire", hear = 10, limit = 2,
		stop_on_destruct = true}, -- S2 E2.1
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
