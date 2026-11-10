-- The ride restored at login (Round 74, user ruling 2026-11-10;
-- docs/design/mounts.md §3): the logout keeps its teardown dismount
-- (entity.lua), which saves the ride's tier in the player's meta and sets
-- the player where the mount was. At the next join the player is held there
-- (no movement, no gravity) until the block is active, then the same tier is
-- summoned under every rule of a summon and the player seated. A ride the
-- rules refuse there (the flight rule, the ceiling, an enemy town, a boat
-- off the water), or one whose block is not active within RESTORE_WAIT
-- seconds, is not summoned: a flyer's rider is set down on the ground below
-- (no fall, so no fall damage), any other simply released. A player who
-- mounted meanwhile (the quickbar works while held) keeps that ride and is
-- released. The key is cleared at the join in every outcome; a player who
-- leaves again while held keeps it for the next login, unless the teardown
-- saved the ride they were on. One core.after chain per joining rider; no
-- globalstep.

local KEY = grug_mounts.LOGOUT_RIDE_KEY
local HOLD = "grug_mounts:restore"
local RESTORE_POLL = 0.25
local RESTORE_WAIT = 5
-- The ground below a flyer (set_down): the column is emerged (generated
-- where the flight passed high over ungenerated land) and searched down from
-- the rider in stages of SET_DOWN_STEP nodes below the lower of the rider and
-- the column's analytic surface, at most SET_DOWN_REACH nodes below it (a
-- ravine, a cave under an underground flyer). An unknown node (not emerged
-- yet) or no ground in the stage keeps the rider held and looks again after
-- SET_DOWN_RETRY seconds, the next time a stage deeper; SET_DOWN_TIMEOUT
-- seconds after the set-down began the rider is released where they are
-- (the last resort). Never into lava: a column whose landing or way down
-- holds a harmful node gives way to the nearest safe column within
-- SET_DOWN_RADIUS (the emerge covers them); with none, the rider stays held
-- until that last resort.
local SET_DOWN_STEP = 128
local SET_DOWN_REACH = 512
local SET_DOWN_RADIUS = 4
local SET_DOWN_RETRY = 1
local SET_DOWN_TIMEOUT = 30
-- player name -> the restore under way (a table: a newer join's replaces it)
local pending = {}

local function release(player, token)
	if pending[player:get_player_name()] == token then
		pending[player:get_player_name()] = nil
	end
	grug_core.release_movement(player, HOLD)
end

local function harmful(definition)
	return (definition.damage_per_second or 0) > 0 or
		(definition.groups and (definition.groups.lava or 0) > 0)
end

-- The ground of column (x, z) for a rider whose feet are in node `feet`,
-- down to `bottom`: "ground" and the feet's position on the first walkable
-- or liquid node with two open cells over it; "harmful" when that node or a
-- cell on the way to it hurts (lava, fire); "blocked" at a solid without
-- that room at or below the feet (never on through rock into a cave below:
-- a neighbour's hill or wall); "unknown" at a node not loaded; "none" at the
-- bottom. The scan starts at the rider's head, feet + 2, so a rider standing
-- on the ground finds that ground; a solid there or at feet + 1 (a low
-- ceiling, a neighbour's step) is passed.
local function column_ground(x, z, feet, bottom)
	local start = feet + 2
	local open = 0
	for y = start, bottom, -1 do
		local node = core.get_node_or_nil({x = x, y = y, z = z})
		if not node or node.name == "ignore" then return "unknown" end
		local definition = core.registered_nodes[node.name] or {walkable = true}
		local floor = definition.walkable or (definition.liquidtype or "none") ~= "none"
		if harmful(definition) and (open > 0 or y == start) then return "harmful" end
		if floor and open >= 2 then
			return "ground", {x = x, y = y + 0.5, z = z}
		elseif floor or harmful(definition) then
			if y <= feet then return "blocked" end
			open = 0
		else
			open = open + 1
		end
	end
	return "none"
end

-- The columns round (x, z) within SET_DOWN_RADIUS, nearest first.
local NEIGHBOURS = {}
for dx = -SET_DOWN_RADIUS, SET_DOWN_RADIUS do
	for dz = -SET_DOWN_RADIUS, SET_DOWN_RADIUS do
		if dx ~= 0 or dz ~= 0 then NEIGHBOURS[#NEIGHBOURS + 1] = {dx, dz, dx * dx + dz * dz} end
	end
end
table.sort(NEIGHBOURS, function(a, b)
	if a[3] ~= b[3] then return a[3] < b[3] end
	if a[1] ~= b[1] then return a[1] < b[1] end
	return a[2] < b[2]
end)

-- A flyer whose ride does not come back: set on the ground below, then
-- released (the stages above).
local function set_down(player, token)
	local name = player:get_player_name()
	local pos = player:get_pos()
	local x, z = math.floor(pos.x + 0.5), math.floor(pos.z + 0.5)
	local depth = grug_core.depth_below_surface and grug_core.depth_below_surface(pos)
	local start = math.floor(math.min(pos.y, depth and pos.y + depth or pos.y) + 0.5)
	local top = math.floor(pos.y + 0.5)
	local limit = start - SET_DOWN_REACH
	local bottom = start - SET_DOWN_STEP
	local started = core.get_us_time()
	local look
	local function stage()
		local answered = false
		core.emerge_area({x = x - SET_DOWN_RADIUS, y = bottom, z = z - SET_DOWN_RADIUS},
			{x = x + SET_DOWN_RADIUS, y = top + 2, z = z + SET_DOWN_RADIUS}, function(_, _, remaining)
				if remaining == 0 and not answered then
					answered = true
					core.after(0, look)
				end
			end)
	end
	look = function()
		local p = core.get_player_by_name(name)
		if not p or pending[name] ~= token then return end
		if p:get_hp() <= 0 then return release(p, token) end
		local result, ground = column_ground(x, z, top, bottom)
		if result == "ground" then
			p:set_pos({x = pos.x, y = ground.y, z = pos.z})
			return release(p, token)
		end
		if result == "harmful" then
			for _, offset in ipairs(NEIGHBOURS) do
				local beside, at = column_ground(x + offset[1], z + offset[2], top, bottom)
				if beside == "ground" then
					p:set_pos(at)
					return release(p, token)
				end
			end
			-- Lava all round: held until the last resort (no new look helps).
			return
		end
		if core.get_us_time() - started >= SET_DOWN_TIMEOUT * 1e6 then
			return release(p, token)
		end
		if result == "none" then bottom = math.max(limit, bottom - SET_DOWN_STEP) end
		core.after(SET_DOWN_RETRY, stage)
	end
	stage()
	-- A stalled emerge: the last resort, once.
	core.after(SET_DOWN_TIMEOUT, function()
		local p = core.get_player_by_name(name)
		if p and pending[name] == token then release(p, token) end
	end)
end

local function attempt(name, token, waited)
	if pending[name] ~= token then return end
	local player = core.get_player_by_name(name)
	if not player then
		pending[name] = nil
		return
	end
	local pos = player:get_pos()
	if player:get_hp() <= 0 or not pos then return release(player, token) end
	-- Mounted meanwhile (the quickbar): that ride stays.
	if grug_mounts.is_mounted(player) then return release(player, token) end
	local active = core.compare_block_status(pos, "active") == true
	if not active and waited < RESTORE_WAIT then
		core.after(RESTORE_POLL, function() attempt(name, token, waited + RESTORE_POLL) end)
		return
	end
	local ok, refusal = false, "Your mount could not be summoned here."
	if active then ok, refusal = grug_mounts.mount_saved(player, token.tier) end
	if ok then return release(player, token) end
	if refusal then grug_core.feed(player, "notice", refusal, "mount") end
	if grug_mounts.TIERS[token.tier].mode == "flight" then return set_down(player, token) end
	release(player, token)
end

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local meta = player:get_meta()
	local tier_id = meta:get_int(KEY)
	pending[name] = nil
	if tier_id == 0 then return end
	meta:set_string(KEY, "")
	if not grug_mounts.TIERS[tier_id] or not grug_mounts.owns_tier(player, tier_id) or
			player:get_hp() <= 0 or (grug_core.player_in_creation_stasis and
			grug_core.player_in_creation_stasis(name)) then
		return
	end
	local token = {tier = tier_id}
	pending[name] = token
	grug_core.hold_movement(player, HOLD)
	core.after(RESTORE_POLL, function() attempt(name, token, RESTORE_POLL) end)
end)

-- Leaving (or a shutdown) while held: the ride waits for the next login.
-- entity.lua's teardown runs first; a ride it saved (mounted meanwhile)
-- is the newer one and stays.
local function keep(player)
	local token = pending[player:get_player_name()]
	if not token then return end
	pending[player:get_player_name()] = nil
	local meta = player:get_meta()
	if meta:get_int(KEY) == 0 then meta:set_int(KEY, token.tier) end
end

core.register_on_leaveplayer(keep)

core.register_on_shutdown(function()
	for _, player in ipairs(core.get_connected_players()) do keep(player) end
end)
