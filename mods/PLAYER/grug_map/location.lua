-- Zone and town names for players (Round 28 Lane M1; docs/design/world_map.md
-- "Zone and town names"). Why: players could not tell which zone they were
-- in, and quest texts and level routes now name zones.
--
--   * one location per player, sampled every second: the zone's display
--     name, or the town's name inside a start town or capital city (their
--     protected footprint, grug_zones.hard_footprint_in); villages, outposts,
--     camps and POIs keep the zone's name;
--   * the line under the minimap shows it (minimap.lua reads text_of);
--   * whether the player stands in a start town or capital (in_town, the
--     quieter town bed of grug_ambience) and in which capital, with a few
--     nodes of hysteresis at the city border (capital_of, Round 35: music
--     plays only in the six capitals);
--   * the territory status at the same position (Round 32: friendly,
--     contested or enemy, grug_pvp.territory_at, sampled with the name)
--     colours the minimap line and both banner lines;
--   * the entry banner shows a new location or status top centre for
--     DISPLAY seconds, debounced (location_view.lua), with the territory
--     line under the name;
--   * (until Round 44 the Map tab also got one marker per zone with its
--     level band, placed at start; the map window draws none, ruling 12,
--     so the placement and its zone-grid cache are gone).
--
-- Pure rules: location_view.lua.

local layout = grug_core.hud_layout
local L = dofile(core.get_modpath(core.get_current_modname()) .. "/location_view.lua")
local M = {view = L}
grug_map.location = M

-- Half the capital city's reserved square (source/simple_map.lua,
-- hard_capital_city_v1 bound_width 532), which is larger than a start town's
-- (152): a town is asked about only inside this box round its anchor.
local TOWN_REACH = 266
local TICK = 0.1
-- No territory status (the open sea, no faction): the calm notice colour.
local COLOR = grug_core.FEED_COLOR.notice

-- Comparison figures for the report: samples and their summed cost.
M.stats = {samples = 0, us = 0}

local resolve, town_at

local function zone_names()
	return setmetatable({}, {__index = function(names, id)
		local record = grug_zones.get(id)
		local name = record and record.display_name or id
		rawset(names, id, name)
		return name
	end})
end

-- The start towns and capital cities: every registered settlement whose
-- anchor column lies in a hard "town" footprint (villages, outposts and
-- camps have none). A capital is told from a start town by its anchor slot
-- in the settlement registry and carries its settlement key.
local function build_resolver()
	if not grug_core.zone_authority_installed() then return nil end
	local towns = {}
	for _, row in ipairs(grug_core.settlement_socket_settlements()) do
		local a = row.anchor
		local id, kind = grug_zones.hard_footprint_in(a.x, a.z, a.x, a.z)
		if kind == "town" then
			towns[#towns + 1] = {name = row.display_name or row.key, x = a.x, z = a.z,
				footprint = id, capital = row.slot == "capital" and row.key or nil}
		end
	end
	return L.resolver({zone_at = grug_zones.id_at, names = zone_names(),
		towns = towns, reach = TOWN_REACH,
		footprint_at = function(x, z) return (grug_zones.hard_footprint_in(x, z, x, z)) end})
end
resolve, town_at = build_resolver()

-- The location text at a position ("" before the world authority exists).
function M.text_at(pos)
	return resolve and resolve(pos.x, pos.z) or ""
end

-- ---------------------------------------------------------------------------
-- Per-player location and the entry banner
-- ---------------------------------------------------------------------------

-- player name -> {state, text, status, town, capital, next_sample, banner,
-- line, offset_y, shown_text, shown_line, shown_color}
local players = {}
-- player name -> true while a banner display runs
local busy = {}

local function now_seconds()
	return core.get_us_time() / 1000000
end

-- The player's current location text ("" before the first sample) and the
-- colour of its territory status (the minimap line).
function M.text_of(player)
	local name = type(player) == "string" and player or player:get_player_name()
	local rec = players[name]
	if not rec then return "", COLOR end
	return rec.text, L.color(rec.status, COLOR)
end

-- The territory status at `pos` for the player: "friendly", "contested",
-- "enemy" or nil. grug_pvp owns the rule (and the depth rule behind it);
-- it does not depend on this mod (nor this one on it), so it is looked up
-- at sample time.
local function territory(player, pos)
	local pvp = rawget(_G, "grug_pvp")
	return pvp and pvp.territory_at(pos, grug_factions.get_faction(player)) or nil
end

-- Whether the player stood inside a start town or capital city at the last
-- sample (grug_ambience, Round 34: a quieter bed).
function M.in_town(name)
	local rec = players[name]
	return rec ~= nil and rec.town == true
end

-- The settlement key of the capital the player counted as in at the last
-- sample (with the border hysteresis of location_view.lua capital_at), or
-- nil (grug_ambience, Round 35: music plays only in the capitals).
function M.capital_of(name)
	local rec = players[name]
	return rec and rec.capital or nil
end

-- Returns the location text (nil for none) and the territory status.
local function sample(player, rec)
	local started = core.get_us_time()
	local pos = player:get_pos()
	local text, town, here = "", false, nil
	if resolve then
		text, town, here = resolve(pos.x, pos.z)
		rec.capital = L.capital_at(town_at, rec.capital, pos.x, pos.z, here)
	end
	local status = territory(player, pos)
	M.stats.samples = M.stats.samples + 1
	M.stats.us = M.stats.us + (core.get_us_time() - started)
	rec.text, rec.status, rec.town = text, status, town == true
	return text ~= "" and text or nil, status
end

-- Name, territory line and their colour; only what changed is sent. "" hides
-- both lines.
local function show(player, rec, text, status)
	if text ~= rec.shown_text then
		rec.shown_text = text
		player:hud_change(rec.banner, "text", text)
	end
	local line = text ~= "" and L.line(status) or ""
	if line ~= rec.shown_line then
		rec.shown_line = line
		player:hud_change(rec.line, "text", line)
	end
	local color = L.color(status, COLOR)
	if text ~= "" and color ~= rec.shown_color then
		rec.shown_color = color
		player:hud_change(rec.banner, "number", color)
		player:hud_change(rec.line, "number", color)
	end
end

local function display(player, rec, text)
	local name = player:get_player_name()
	local window = core.get_player_window_information(name)
	local offset = layout.zone_banner_offset(window)
	if rec.offset_y ~= offset.y then
		rec.offset_y = offset.y
		player:hud_change(rec.banner, "offset", offset)
		player:hud_change(rec.line, "offset", layout.zone_subtitle_offset(window))
	end
	show(player, rec, text, rec.state.shown_status)
	busy[name] = true
end

-- Players joining one after another sample in different phases.
local JOIN_PHASE = 0.2
local joined = 0
core.register_on_joinplayer(function(player)
	joined = joined + 1
	local anchor = layout.anchors.zone_banner
	players[player:get_player_name()] = {state = L.new_state(), text = "",
		next_sample = now_seconds() + (joined * JOIN_PHASE) % L.SAMPLE,
		offset_y = anchor.offset.y, shown_text = "", shown_line = "", shown_color = COLOR,
		banner = player:hud_add(layout.text_element("zone_banner", {number = COLOR,
			text = "", size = {x = layout.ZONE_BANNER_SIZE}, style = 1, z_index = 2})),
		line = player:hud_add(layout.text_element("zone_subtitle",
			{number = COLOR, text = "", style = 1, z_index = 2}))}
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	players[name], busy[name] = nil, nil
end)

local elapsed = 0
core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < TICK then return end
	elapsed = 0
	local now = now_seconds()
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local rec = players[name]
		-- During character creation the player stands at the engine's spawn
		-- spot: no sample, so neither the line nor the banner names it; the
		-- first sample after release shows the start town.
		if rec and now >= rec.next_sample and not (grug_core.player_in_creation_stasis and
				grug_core.player_in_creation_stasis(name)) then
			-- A late step does not make up for missed samples.
			local next_sample = rec.next_sample + L.SAMPLE
			rec.next_sample = next_sample > now and next_sample or now + L.SAMPLE
			local text, status = sample(player, rec)
			text = L.sample(rec.state, text, now, status)
			if text then display(player, rec, text) end
		end
	end
	for name in pairs(busy) do
		local rec = players[name]
		local player = rec and core.get_player_by_name(name)
		if not player then
			busy[name] = nil
		elseif now >= rec.state.busy_until then
			-- A fresh sample decides: the player may have come back already.
			local text, status = sample(player, rec)
			local result = L.expire(rec.state, text, now, status)
			if result then
				display(player, rec, result)
			else
				show(player, rec, "", nil)
				busy[name] = nil
			end
		end
	end
end)
