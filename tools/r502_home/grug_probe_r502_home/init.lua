-- Disposable engine probe (fix 0.50.2 lane HOME): claims on the minimap and
-- in the location line and banner, for screenshots. Never shipped:
-- tools/r502_home/capture.sh stages it through tools/luanti_headless.sh and
-- connects one real client. The driver (character creation, SHOT / ack
-- handshake) is tools/r502_cmap's probe's.
--
-- After the character is made (Accord, Human, Warrior) the probe finds,
-- near the start, an eligible column with no settlement near (grug_housing's
-- own rule) and places two drafts with their stone nodes: the player's own
-- claim there (HOME) and another player's ("neighbor") 110 nodes south of
-- it. Each stone is set only after core.emerge_area has generated its
-- area: a node set into a chunk not yet generated makes the mapgen's
-- refinement refuse that chunk (a [GRUG-SEVERE] line). For each shot it moves the player (for a banner shot first outside,
-- then after SETTLE seconds into the claim, and takes the shot BANNER
-- seconds later, while the banner shows), puts the Claim Stone into the
-- wielded slot or empties it, and logs "SHOT <name>" and a CHECK line (the
-- location text, the banner, the frames and red fills in the cell
-- texture). At the end it logs the location sample's and the minimap's
-- engine cost (their M.stats over the run).
local P = "[r502home] "
local NAME = "grugcap"
local OTHER = "neighbor"
local SETTLE = tonumber(core.settings:get("r502home_settle") or "") or 7
local BANNER = 1.6
local FACTION = "accord"
local OWN_FRAME, OTHER_FRAME = "#40d04acc", "#f0d040cc"
local function log(msg) core.log("action", P .. msg) end

local state = {phase = "wait", clock = 0}

local function submit(player, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, "", fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r502home_ack", "r")
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
local function clear(x, z)
	return allowed(x, z) and not world.feature_in(x - 50, z - 50, x + 50, z + 50, 16)
end

-- The nearest column on a 32-node grid where both claims' centres are
-- eligible and clear of settlements.
local function find_spot(from)
	local rows = {}
	for z = -3100, 3100, 32 do
		for x = -3500, 3500, 32 do
			local dx, dz = x - from.x, z - from.z
			rows[#rows + 1] = {x = x, z = z, d = dx * dx + dz * dz}
		end
	end
	table.sort(rows, function(a, b) return a.d < b.d end)
	for _, row in ipairs(rows) do
		if clear(row.x, row.z) and clear(row.x, row.z - 110) then
			return {x = row.x, z = row.z}
		end
	end
	return {x = from.x, z = from.z}
end

local function ground(x, z)
	return math.max(grug_zones.terrain_height_at(x, z), 1)
end

-- The draft once its area is generated; `state.pending` counts the drafts
-- still waiting.
local function draft(owner, x, z)
	local pos = {x = x, y = ground(x, z) + 1, z = z}
	state.pending = (state.pending or 0) + 1
	local function emerged(_, _, remaining)
		if remaining > 0 then return end
		-- a block another emerge was already generating comes back
		-- cancelled: ask again until the stone's node is there
		if core.get_node(pos).name == "ignore" then
			core.emerge_area(vector.subtract(pos, 16), vector.add(pos, 16), emerged)
			return
		end
		core.set_node(pos, {name = grug_housing.DRAFT_STONE})
		local claim = grug_housing.model.create(owner, pos)
		log(("claim %d of %s at %s"):format(claim.id, owner, core.pos_to_string(pos)))
		state.pending = state.pending - 1
	end
	core.emerge_area(vector.subtract(pos, 16), vector.add(pos, 16), emerged)
end

-- offsets from the own claim's centre
local SHOTS = {
	{name = "H1_frames", pos = {-80, -40}},
	{name = "H2_your_home", pre = {-70, 0}, pos = {-40, 0}},
	{name = "H3_neighbor_home", pre = {0, -55}, pos = {0, -80}},
	{name = "H4_stone_all_red", pos = {-80, -40}, stone = true},
}

local function place(player, offset)
	local x, z = state.spot.x + offset[1], state.spot.z + offset[2]
	player:set_pos({x = x + 0.5, y = ground(x, z) + 2, z = z + 0.5})
end

local function count(text, needle)
	local n, at = 0, 1
	while true do
		local found = text:find(needle, at, true)
		if not found then return n end
		n, at = n + 1, found + 1
	end
end

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.2 then return end
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
		state.spot = find_spot(at)
		log(("spots: home %d,%d"):format(state.spot.x, state.spot.z))
		draft(NAME, state.spot.x, state.spot.z)
		draft(OTHER, state.spot.x, state.spot.z - 110)
		log(("minimap available: %s"):format(tostring(grug_map.minimap.available())))
		state.phase = "emerge"
	elseif state.phase == "emerge" then
		if state.pending > 0 then return end
		state.samples0, state.us0 = grug_map.location.stats.samples, grug_map.location.stats.us
		state.updates0, state.mus0 = grug_map.minimap.stats.updates, grug_map.minimap.stats.us
		state.phase = "shoot"
		state.shot, state.waited, state.logged, state.entered = 1, 0, false, false
		log("READY")
	elseif state.phase == "shoot" then
		local shot = SHOTS[state.shot]
		if not shot then
			state.phase = "done"
			local L, Mm = grug_map.location.stats, grug_map.minimap.stats
			local samples, updates = L.samples - state.samples0, Mm.updates - state.updates0
			log(("stats: location %d samples, %.1f us per sample; minimap %d updates, " ..
				"%.1f us per player and step"):format(samples,
				(L.us - state.us0) / math.max(1, samples), updates,
				(Mm.us - state.mus0) / math.max(1, updates)))
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
			return
		end
		if state.waited == 0 then
			place(player, shot.pre or shot.pos)
			player:get_inventory():set_stack("main", player:get_wield_index(),
				ItemStack(shot.stone and grug_housing.STONE_ITEM or ""))
		end
		state.waited = state.waited + step
		local due = SETTLE
		if shot.pre then
			if not state.entered and state.waited >= SETTLE then
				state.entered = true
				place(player, shot.pos)
			end
			due = SETTLE + BANNER
		end
		if not state.logged and state.waited >= due then
			state.logged = true
			local texture = grug_map.minimap.texture_of(player) or ""
			local banner = "?"
			for _, def in pairs(player:hud_get_all()) do
				if def.type == "text" and def.size and def.size.x == 2.5 then banner = def.text end
			end
			log(("SHOT %s"):format(shot.name))
			log(("CHECK %s: location %q, banner %q, %d own and %d other frame edges, %d fills, " ..
				"claim mode %s"):format(shot.name, (grug_map.location.text_of(player)), banner,
				count(texture, OWN_FRAME), count(texture, OTHER_FRAME), count(texture, "^[fill:"),
				tostring(grug_map.minimap.claim_of(player))))
		elseif state.logged and read_ack() == shot.name then
			state.shot = state.shot + 1
			state.waited, state.logged, state.entered = 0, false, false
		end
	end
end)
