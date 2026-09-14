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
-- switching order-independent. Given nil, the engine resets everything to the
-- defaults above (l_object.cpp:2834 `lua_isnoneornil`, documented in
-- lua_api.md:9591-9592) — that is what the `off` preset uses.
--
-- PRESET TABLE SHAPE (a later per-zone package extends this, it does not
-- restructure it):
--   description  human-readable, shown by /atmosphere
--   zone         optional zone id this preset is the look FOR. Zone switching
--                is NOT implemented here; the key exists so a zone package can
--                index presets by zone without touching the entries again.
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
	-- previous one had and must be undone. No shipped preset sets them, so on
	-- the current content this never sends a sky packet at all.
	if preset.sky or (previous and previous.sky) then
		player:set_sky(preset.sky)
	end
	if preset.clouds or (previous and previous.clouds) then
		player:set_clouds(preset.clouds)
	end

	applied[name] = preset_name
	return true
end

core.register_on_joinplayer(function(player)
	grug_core.set_atmosphere(player, DEFAULT_PRESET)
end)

core.register_on_leaveplayer(function(player)
	applied[player:get_player_name()] = nil
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
	params = "[<preset>|off]",
	description = "Apply a lighting preset to yourself (A/B test)",
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
				". Presets: " .. preset_list()
		end
		if not atmosphere_enabled then
			return false, "The atmosphere layer is off " ..
				"(grug_atmosphere_enabled = false)."
		end
		if not presets[param] then
			return false, "Unknown preset. Presets: " .. preset_list()
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
		if unchanged then
			return true, "Atmosphere already " .. param .. "; nothing sent."
		end
		return true, "Atmosphere: " .. param .. " - " ..
			presets[param].description
	end,
})
