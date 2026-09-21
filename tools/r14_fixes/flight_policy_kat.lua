local root = assert(arg[1], "repository root required")

local mode = "accord_home"
local function zone()
	if mode == "wyrmglass" then
		return {id = "front_wyrmglass_crown", territory_rule = "contested_land"}
	elseif mode == "stormscale" then
		return {id = "front_stormscale_summit", territory_rule = "contested_land"}
	end
	return {id = "ordinary", territory_rule = mode}
end

core = {
	register_entity = function() end,
	register_on_player_hpchange = function() end,
	register_on_dieplayer = function() end,
	register_on_leaveplayer = function() end,
	register_on_shutdown = function() end,
	global_exists = function() return false end,
}
vector = {add = function(first, second)
	return {x = first.x + second.x, y = first.y + second.y,
		z = first.z + second.z}
end}
player_api = {player_attached = {}, set_animation = function() end}
grug_core = {}
grug_mounts = {TIERS = {}, FLIGHT_CEILING = 600}
grug_classes = {register_on_race_chosen = function() end}
grug_factions = {
	get_faction = function(player) return player.faction end,
	register_on_faction_chosen = function() end,
}
grug_zones = {
	water_class_at = function()
		return mode == "ocean" and "deep_ocean" or "land"
	end,
	at = function() return zone() end,
}

dofile(root .. "/mods/PLAYER/grug_mounts/entity.lua")

local accord = {faction = "accord"}
local throng = {faction = "throng"}
local pos = {x = 0, y = 100, z = 0}
local function state(player, expected, kind)
	local allowed, actual_kind = grug_mounts.flight_state(player, pos)
	assert(allowed == expected and actual_kind == kind)
end

mode = "accord_home"
state(accord, true, nil)
state(throng, false, "enemy")
mode = "throng_home"
state(accord, false, "enemy")
state(throng, true, nil)
for _, contested in ipairs({"contested_land", "holy_grounds"}) do
	mode = contested
	state(accord, true, nil)
	state(throng, true, nil)
end
for _, island in ipairs({"wyrmglass", "stormscale"}) do
	mode = island
	state(accord, false, "island")
	state(throng, false, "island")
end
mode = "ocean"
state(accord, false, "ocean")
state(throng, false, "ocean")

io.write("r14_flight_policy_v1|homes=factional|mainland_contested=both|islands=neither|ocean=neither\n")
