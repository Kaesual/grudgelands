-- Disposable engine probe (fix 0.50.2 lane CMAP): the Claim Stone preview
-- on the minimap, for screenshots. Never shipped: tools/r502_cmap/capture.sh
-- stages it through tools/luanti_headless.sh and connects one real client.
-- The driver (character creation, SHOT / ack handshake) is the Round 48 HUD
-- probe's.
--
-- After the character is made (Accord, Human, Warrior) the probe finds, near
-- the start, a spot whose claim square reaches a forbidden border (BORDER)
-- and one with a village, camp or point of interest in the minimap's window
-- (SITE), both in an eligible zone, using grug_housing's own rule
-- (column_problem, placement_world). For each shot it moves the player,
-- puts the Claim Stone into the wielded slot or empties it, sets the
-- minimap switch, waits SETTLE seconds and logs "SHOT <name>" and a CHECK
-- line (claim mode, overlay tiles and fills in the cell texture, the
-- square). The CLAIM shot places a draft for another name next to BORDER.
local P = "[r502cmap] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r502cmap_settle") or "") or 7
local FACTION = "accord"
local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r502cmap_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local world = grug_housing.placement_world
local function allowed(x, z)
	local zone = world.zone_at(x, z)
	return not grug_housing.column_problem(FACTION, world.water_class_at(x, z), zone,
		zone and world.territory_at(x, z) or nil)
end

-- Eligible columns on a 32-node grid, nearest to `from` first: BORDER has a
-- forbidden column 60 nodes off in one of the four directions and no
-- settlement near its square; SITE has a settlement within 120 nodes.
local function find_spots(from)
	local rows = {}
	for z = -3100, 3100, 32 do
		for x = -3500, 3500, 32 do
			local dx, dz = x - from.x, z - from.z
			rows[#rows + 1] = {x = x, z = z, d = dx * dx + dz * dz}
		end
	end
	table.sort(rows, function(a, b) return a.d < b.d end)
	local border, site
	for _, row in ipairs(rows) do
		if border and site then break end
		local x, z = row.x, row.z
		if allowed(x, z) then
			local near = world.feature_in(x - 50, z - 50, x + 50, z + 50, 16)
			if not border and not near and (not allowed(x + 60, z) or not allowed(x - 60, z) or
					not allowed(x, z + 60) or not allowed(x, z - 60)) then
				border = {x = x, z = z}
			elseif not site and not near and
					world.feature_in(x - 120, z - 120, x + 120, z + 120, 0) then
				site = {x = x, z = z}
			end
		end
	end
	return border, site
end

local SHOTS = {
	{name = "C1_border", spot = "border", stone = true, shown = true},
	{name = "C2_settlement", spot = "site", stone = true, shown = true},
	{name = "C3_claim_in_view", spot = "border", stone = true, shown = true, draft = true},
	{name = "C4_switched_off_with_stone", spot = "border", stone = true, shown = false},
	{name = "C5_switched_off_no_stone", spot = "border", stone = false, shown = false},
	{name = "C6_no_stone", spot = "border", stone = false, shown = true},
}

local function place(player, spot)
	local y = grug_zones.terrain_height_at(spot.x, spot.z)
	player:set_pos({x = spot.x + 0.5, y = math.max(y, 1) + 2, z = spot.z + 0.5})
end

local function show(player, shot)
	place(player, state.spots[shot.spot])
	-- the wielded slot holds the stone or nothing (this engine has no
	-- set_wield_index)
	player:get_inventory():set_stack("main", player:get_wield_index(),
		ItemStack(shot.stone and grug_housing.STONE_ITEM or ""))
	grug_map.minimap.set_enabled(player, shot.shown)
	if shot.draft and not state.draft then
		-- a draft with its node (a claim whose stone is missing from a
		-- loaded block vanishes at stone.lua's next check)
		local spot = state.spots.border
		local pos = {x = spot.x + 95, z = spot.z + 40}
		pos.y = math.max(grug_zones.terrain_height_at(pos.x, pos.z), 1) + 1
		core.load_area(pos)
		core.set_node(pos, {name = grug_housing.DRAFT_STONE})
		state.draft = grug_housing.model.create("neighbor", pos)
		log(("draft %d at %s"):format(state.draft.id, core.pos_to_string(pos)))
	end
end

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.5 then return end
	local step = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, {faction_accord = "Accord"})
			submit(player, {race_human = "Human"})
			submit(player, {class_warrior = "Warrior"})
			submit(player, {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		local at = vector.round(player:get_pos())
		log("character complete at " .. core.pos_to_string(at))
		local border, site = find_spots(at)
		log(("spots: border %s, site %s"):format(border and (border.x .. "," .. border.z) or "none",
			site and (site.x .. "," .. site.z) or "none"))
		state.spots = {border = border or {x = at.x, z = at.z}, site = site or border or
			{x = at.x, z = at.z}}
		log(("minimap available: %s"):format(tostring(grug_map.minimap.available())))
		state.phase = "shoot"
		state.shot, state.waited, state.logged = 1, 0, false
		log("READY")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if state.waited == 0 then show(player, shot) end
		state.waited = state.waited + step
		if not state.logged and state.waited >= SETTLE then
			state.logged = true
			local texture = grug_map.minimap.texture_of(player) or ""
			local fills, overlays = 0, 0
			for _ in texture:gmatch("%^%[fill:") do fills = fills + 1 end
			for _ in texture:gmatch("grug_map_claim_") do overlays = overlays + 1 end
			local square, map = "none", "none"
			for _, def in pairs(player:hud_get_all()) do
				if def.z_index == 12 then square = def.text ~= "" and "shown" or "hidden" end
				if def.z_index == 11 then map = def.text == texture and "current" or "other" end
			end
			log(("SHOT %s"):format(shot.name))
			log(("CHECK %s: claim mode %s, %d overlay tiles and %d claim fills in the cell " ..
				"texture, map %s, square %s"):format(shot.name,
				tostring(grug_map.minimap.claim_of(player)), overlays, fills, map, square))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged = 0, false
		end
	end
end)
