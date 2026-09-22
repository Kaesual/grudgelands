-- Player atmosphere presets (docs/research/graphics-improvements.md §3, §7-A).
--
-- WHY THIS EXISTS: the engine ships every post effect neutral until the GAME
-- asks for it. `struct Lighting` constructs with shadow_intensity 0.0,
-- saturation 1.0, volumetric_light_strength 0.0 and a black shadow tint
-- (reference_projects/luanti/src/lighting.h:45-56), and its AutoExposure
-- member with luminance_min/max -3.0, exposure_correction 0.0 and both
-- adaptation speeds 1000.0 (lighting.h:33-39). `player:set_lighting()` is the
-- only way to move them, and the only one that reaches REMOTE clients at all:
-- the game-directory minetest.conf merely shifts client defaults for a locally
-- hosted process (graphics-improvements.md §2.1).
--
-- COST: one packet per call. l_object.cpp:2879 calls Server::setLighting,
-- which stores the value on the RemotePlayer and sends exactly one
-- TOCLIENT_SET_LIGHTING (server.cpp:3704-3709 — the only caller of
-- SendSetLighting in the whole engine). Nothing in this file runs per
-- globalstep; a preset is sent only when set_atmosphere is called with a name
-- that differs from the one the player already carries.
--
-- MERGE SEMANTICS (the trap): given a table, the engine starts from the
-- player's CURRENT lighting and overwrites only the fields present
-- (l_object.cpp:2836 `lighting = player->getLighting()`). A preset that omits
-- `volumetric_light` therefore INHERITS whatever the previous preset set. So
-- every preset below states every group it cares about, which makes preset
-- switching order-independent. Two merged keys are deliberately never set by
-- any preset: `shadows.direction` (l_object.cpp:2843-2846) and
-- `exposure.center_weight_power` (:2859); a future preset that sets either
-- must be paired with the same key stated in every other preset, or switching
-- away will inherit it. Given nil, the engine resets everything to the
-- defaults above (l_object.cpp:2834 `lua_isnoneornil`, documented in
-- lua_api.md:9591-9592) — that is what the `off` preset uses.
--
-- PRESET TABLE SHAPE (atmosphere_zones.lua extends this table with the
-- per-region moods and the driver that picks one; it does not restructure it):
--   description  human-readable, shown by /atmosphere
--   zone         optional zone id this preset is the look FOR. Zone switching
--                is NOT implemented here. atmosphere_zones.lua resolves a mood
--                from grug_zones instead of indexing on this key, so it is
--                still only carried by `hearthpine` as a worked example.
--   lighting     table for player:set_lighting, or nil for "engine defaults"
--   sky          optional table for player:set_sky   (nil = engine default sky)
--   clouds       optional table for player:set_clouds (nil = engine defaults)
-- Both sky and clouds reset to their defaults when called with no arguments
-- (lua_api.md:9390 and :9536), which is how a preset without them undoes a
-- preset that had them.
--
-- RESPAWN: no re-apply is needed. Lighting lives on the RemotePlayer
-- (remoteplayer.h:116-118, m_lighting at :159), which survives death — respawn
-- only repositions the player (builtin/game/death_screen.lua:27 ->
-- ObjectRef:respawn, lua_api.md:9651) and no engine path resends or
-- resets lighting. On the client the value is written only by
-- handleCommand_SetLighting (network/clientpackethandler.cpp:1883-1885). Hence
-- register_on_respawnplayer is deliberately absent.

-- Read once at load: a settings change needs a restart to reach the client
-- defaults anyway, and this keeps the join path free of a settings lookup.
-- The explicit `true` is the default that matters at runtime — a game's
-- settingtypes.txt is parsed by the main menu, not by the server
-- (lua_api.md:353-358).
local atmosphere_enabled = core.settings:get_bool("grug_atmosphere_enabled", true)

-- One 20-minute world day with a 15-minute day phase and 5-minute night
-- phase. Luanti's speed is virtual hours per real hour
-- (environment.cpp:281-308), so 15 virtual day hours / 0.25 real hours = 60,
-- while 9 virtual night hours / (5 / 60) real hours = 108. The phase edges
-- match grug_mobs' established spawn clock.
grug_core.DAY_PHASE_START = 0.1875 -- 04:30
grug_core.DAY_PHASE_END = 0.8125 -- 19:30
grug_core.DAY_TIME_SPEED = 60
grug_core.NIGHT_TIME_SPEED = 108
grug_core.NIGHT_LIGHT_FLOOR = 0.30
grug_core.NIGHT_VISION_RATIO = 0.45

function grug_core.is_day_phase(timeofday)
	return timeofday >= grug_core.DAY_PHASE_START and
		timeofday <= grug_core.DAY_PHASE_END
end

-- Published so the zone package can decide at load time whether to register a
-- globalstep at all. A plain boolean field, read once: the master switch never
-- changes during a run.
grug_core.atmosphere_enabled = atmosphere_enabled

-- Applied on join and the fallback for every zone that has no preset yet.
-- Published so the later zone package can fall back to it by name instead of
-- repeating the string.
local DEFAULT_PRESET = "default"
grug_core.ATMOSPHERE_DEFAULT = DEFAULT_PRESET

-- Values derive from the MIT VoxeLibre shader preset quoted in
-- graphics-improvements.md §3 (shadows 0.33, the exposure block, saturation
-- 1.1). Deviations from it are commented per preset.
local presets = {}
grug_core.atmosphere_presets = presets

presets["default"] = {
	description = "Grudgelands baseline: dynamic shadows, mild bloom, warm exposure",
	lighting = {
		-- 0.33 is the VoxeLibre value and also enable_shadows' default. It is
		-- the switch that turns dynamic shadows on at all: at intensity 0 the
		-- client renders none, however the setting stands (lua_api.md:9609).
		shadows = {intensity = 0.33, tint = {r = 0, g = 0, b = 0}},
		-- > 1 oversaturates while keeping luma (lua_api.md:9594-9601); 1.1 is
		-- the VoxeLibre value and is the cheapest effect in the package — it
		-- rides along in the post pass that is already running.
		saturation = 1.1,
		exposure = {
			luminance_min = -3.5,
			luminance_max = -2.5,
			exposure_correction = 0.35,
			speed_dark_bright = 1500,
			speed_bright_dark = 700,
		},
		-- 0.05 is today's engine default, stated explicitly because the API
		-- doc announces that the default will change to 0 and tells games that
		-- want to keep it to set it (lua_api.md:9632-9634). Mild on purpose:
		-- bloom is what makes a torch read as a light source, not a bright
		-- texture, and anything higher washes out snow and sand.
		bloom = {intensity = 0.05, strength_factor = 1.0, radius = 1.0},
		-- Volumetric light is the most expensive post effect of the set
		-- (graphics-improvements.md §2) and is OFF in every shipped preset
		-- except `godrays`. Stated rather than omitted because of the merge
		-- semantics in the header.
		volumetric_light = {strength = 0},
	},
}

presets["hearthpine"] = {
	description = "Hearthpine Vale: warmer shadows, torch-friendly bloom",
	-- The one preset that already carries a zone id, as the worked example for
	-- the zone package. Nothing reads this key yet.
	zone = "hearthpine_vale",
	lighting = {
		-- A warm, very dark tint instead of pure black: shadow cores under the
		-- pines and inside the dwarf halls go brown rather than flat black, so
		-- torchlight has something warm to sit in. Integer [0,255] per channel
		-- (lua_api.md:9610-9611); these values are near-black on purpose.
		shadows = {intensity = 0.33, tint = {r = 28, g = 20, b = 12}},
		saturation = 1.15,
		exposure = {
			luminance_min = -3.5,
			luminance_max = -2.5,
			-- Slightly brighter than baseline so a torchlit night reads warm
			-- instead of merely dark; the equation is
			-- e = 2^correction / clamp(luminance, 2^min, 2^max)
			-- (lua_api.md:9618).
			exposure_correction = 0.45,
			speed_dark_bright = 1500,
			speed_bright_dark = 700,
		},
		bloom = {intensity = 0.08, strength_factor = 1.0, radius = 1.0},
		volumetric_light = {strength = 0},
	},
}

presets["godrays"] = {
	description = "Baseline plus volumetric light (expensive, A/B only)",
	lighting = {
		shadows = {intensity = 0.33, tint = {r = 0, g = 0, b = 0}},
		saturation = 1.1,
		exposure = {
			luminance_min = -3.5,
			luminance_max = -2.5,
			exposure_correction = 0.35,
			speed_dark_bright = 1500,
			speed_bright_dark = 700,
		},
		bloom = {intensity = 0.05, strength_factor = 1.0, radius = 1.0},
		-- The VoxeLibre value. Needs the client's Volumetric Lighting AND
		-- Bloom effects (lua_api.md:9642); both are off by default
		-- (builtin/settingtypes.txt:843, :848) and we do not turn volumetric
		-- lighting on in our minetest.conf, so this preset is opt-in twice.
		volumetric_light = {strength = 0.45},
	},
}

presets["off"] = {
	description = "Engine defaults (no shadows, saturation 1.0, neutral exposure)",
	-- nil lighting resets every parameter, so an A/B comparison against this
	-- preset is a real one and not a half-reverted state.
	lighting = nil,
}

-- Player name -> applied preset name. Cleared on leave, because the engine
-- never resends stored lighting on its own (SendSetLighting has exactly one
-- caller, server.cpp:3704-3709): a reconnecting client starts at engine
-- defaults, and a stale entry here would suppress the join packet.
local applied = {}

-- Per-player ratio effects compose here rather than letting each consumable
-- overwrite the engine override. A fixed ratio affects sunlight only, so an
-- enclosed cave with no sunlight stays dark; see ObjectRef's
-- override_day_night_ratio contract in lua_api.md:9553-9558.
local night_vision = {}
local applied_ratio = {}

local function desired_ratio(name, timeofday)
	local natural = core.time_to_day_night_ratio(timeofday)
	local floor = atmosphere_enabled and grug_core.NIGHT_LIGHT_FLOOR or 0
	if night_vision[name] and night_vision[name] > floor then
		floor = night_vision[name]
	end
	if natural < floor then
		return floor
	end
	return nil
end

local function sync_day_night_ratio(player, timeofday)
	local name = player:get_player_name()
	local ratio = desired_ratio(name, timeofday or core.get_timeofday())
	if applied_ratio[name] == ratio then
		return
	end
	player:override_day_night_ratio(ratio)
	applied_ratio[name] = ratio
end

-- Cave Draught is the one current night-vision producer. `ratio = nil`
-- removes it and immediately restores the natural/baseline composition.
function grug_core.set_night_vision(player, ratio)
	if not player or not player.is_player or not player:is_player() then
		return false
	end
	if ratio ~= nil and (type(ratio) ~= "number" or ratio < 0 or ratio > 1) then
		return false
	end
	local name = player:get_player_name()
	night_vision[name] = ratio
	sync_day_night_ratio(player)
	return true
end

local clock_accumulator = 0
local applied_time_speed
local original_time_speed = core.settings:get("time_speed")

local function sync_world_clock(timeofday)
	local speed = grug_core.is_day_phase(timeofday) and
		grug_core.DAY_TIME_SPEED or grug_core.NIGHT_TIME_SPEED
	local live_speed = tonumber(core.settings:get("time_speed"))
	if speed ~= applied_time_speed or live_speed ~= speed then
		-- Settings:set updates the live g_settings value. Server::AsyncRunStep
		-- reads it into both the environment clock and the client time packet on
		-- every step (server.cpp:697-709). The shutdown hook below restores the
		-- operator's value before an integrated client persists global settings.
		core.settings:set("time_speed", tostring(speed))
		applied_time_speed = speed
	end
end

core.register_on_shutdown(function()
	core.settings:set("time_speed", original_time_speed or "72")
end)

core.register_globalstep(function(dtime)
	clock_accumulator = clock_accumulator + dtime
	if clock_accumulator < 1 then
		return
	end
	clock_accumulator = clock_accumulator % 1
	local timeofday = core.get_timeofday()
	sync_world_clock(timeofday)
	local players = core.get_connected_players()
	for index = 1, #players do
		sync_day_night_ratio(players[index], timeofday)
	end
end)

-- Returns the preset name currently applied to `name`, or nil.
function grug_core.get_atmosphere(name)
	return applied[name]
end

-- Applies a named preset to one player. Returns true when the player now
-- carries the preset (including the no-op case where they already did), false
-- when nothing could be applied.
function grug_core.set_atmosphere(player, preset_name)
	if not atmosphere_enabled then
		return false
	end
	if not player or not player.is_player or not player:is_player() then
		return false
	end

	local preset = presets[preset_name]
	if not preset then
		core.log("warning", "[grug_core] unknown atmosphere preset: " ..
			tostring(preset_name))
		return false
	end

	local name = player:get_player_name()
	if applied[name] == preset_name then
		return true -- unchanged: send nothing
	end
	local previous = applied[name] and presets[applied[name]]

	player:set_lighting(preset.lighting)
	-- Only touch sky/clouds when a preset actually has an opinion, or when the
	-- previous one had and must be undone. None of the four presets in THIS
	-- file sets them; the zone moods in atmosphere_zones.lua all do, so moving
	-- between a mood and a shipped preset resets sky and clouds to the engine
	-- defaults rather than leaving half a mood behind.
	if preset.sky or (previous and previous.sky) then
		player:set_sky(preset.sky)
	end
	if preset.clouds or (previous and previous.clouds) then
		player:set_clouds(preset.clouds)
	end

	applied[name] = preset_name
	return true
end

-- Zone-package seams, resolved by atmosphere_zones.lua through the same
-- stub-override pattern init.lua uses for get_player_faction. They keep the
-- chat command in one place while the auto-mode bookkeeping stays in the file
-- that owns it; with the zone package off (or its setting false) the stubs
-- make `/atmosphere` behave exactly as it did before this package.
--
-- atmosphere_manual_pause(name): a manual preset was just applied, stop
--   driving that player from their zone.
-- atmosphere_resume_auto(name): `/atmosphere auto`. Returns a message string
--   on success, or nil when zone-driven mode is not available at all.
function grug_core.atmosphere_manual_pause(name)
end

function grug_core.atmosphere_resume_auto(name)
	return nil
end

-- atmosphere_mode(name): one word for the status line.
function grug_core.atmosphere_mode(name)
	return "manual"
end

core.register_on_joinplayer(function(player)
	grug_core.set_atmosphere(player, DEFAULT_PRESET)
	sync_day_night_ratio(player)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	applied[name] = nil
	applied_ratio[name] = nil
	night_vision[name] = nil
end)

local function preset_list()
	local names = {}
	for preset_name in pairs(presets) do
		names[#names + 1] = preset_name
	end
	table.sort(names)
	return table.concat(names, ", ")
end

core.register_chatcommand("atmosphere", {
	params = "[<preset>|off|auto]",
	description = "Apply a lighting preset to yourself (A/B test), " ..
		"or `auto` to return to the zone-driven mood",
	privs = {server = true},
	func = function(name, param)
		-- `privs` above is the engine-enforced gate; this repeats it through
		-- the documented API so the guarantee does not depend on the caller.
		if not core.check_player_privs(name, {server = true}) then
			return false, "The server privilege is required."
		end

		param = param:match("^%s*(.-)%s*$")
		if param == "" then
			return true, "Atmosphere: " ..
				tostring(grug_core.get_atmosphere(name) or "none") ..
				" (" .. grug_core.atmosphere_mode(name) ..
				"). Presets: " .. preset_list() .. ", auto"
		end
		if not atmosphere_enabled then
			return false, "The atmosphere layer is off " ..
				"(grug_atmosphere_enabled = false)."
		end
		-- `auto` is not a preset name and is checked before the preset table
		-- so a future preset can never shadow it.
		if param == "auto" then
			local message = grug_core.atmosphere_resume_auto(name)
			if not message then
				return false, "Zone-driven atmosphere is not available " ..
					"(grug_atmosphere_zones = false, or no zone authority)."
			end
			return true, message
		end
		if not presets[param] then
			return false, "Unknown preset. Presets: " .. preset_list() ..
				", auto"
		end

		-- Re-fetched by name rather than captured: the command runs long after
		-- the player object of any earlier call was valid.
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Only an online player can change their atmosphere."
		end

		local unchanged = grug_core.get_atmosphere(name) == param
		if not grug_core.set_atmosphere(player, param) then
			return false, "Could not apply preset " .. param .. "."
		end
		-- After the preset landed, so a failed apply does not silently stop
		-- the zone driver. Unconditional: re-applying the preset a player
		-- already carries is still an explicit "hold this one".
		grug_core.atmosphere_manual_pause(name)
		if unchanged then
			return true, "Atmosphere already " .. param .. "; nothing sent."
		end
		return true, "Atmosphere: " .. param .. " - " ..
			presets[param].description
	end,
})
