-- Round 48 lane WORLD portable test (LuaJIT): the mailbox on the waystone
-- pads (round48-plan.md §4.3, mail-plan.md ruling 1 and §4.4).
--
--   luajit tools/r48_world/portable_test.lua [REPO]
--
-- A. The node (grug_mapgen/world_nodes.lua, the real file, on a fake
--    engine): `grug_mapgen:mailbox` cannot be dug, drops nothing, survives a
--    blast, turns by facedir, has its three textures; a right-click calls
--    grug_mail.open_mailbox(player, pos) when grug_mail has it and does
--    nothing (no error) without grug_mail, without the function or for a
--    clicker that is no player.
-- B. The twelve pads (six starts, six capital cores): one mailbox each, off
--    the pad's cross arms, not beside the stone (not even diagonally), inside
--    the pad's diamond and within three nodes of the `travel_waypoint`
--    socket, on ground with nothing over it, on no socket, its front turned
--    toward the stone.
-- C. None elsewhere: every other composition of the settlement roster (the
--    Round 14 and Round 20 POIs, the dragon arenas, the PvP POIs) and every
--    capital plot holds no mailbox.
-- D. The name: with the twelve settlements in the real grug_core socket
--    registry (anchors far apart), each mailbox resolves to exactly one
--    settlement whose `waypoint` socket lies within three nodes -- its own,
--    with the settlement's label.
-- Prints "R48 WORLD PORTABLE PASS checks=<n>" or raises on the first failure.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local MAILBOX = "grug_mapgen:mailbox"
local REACH = 3 -- the starts' pad reach; every capital's diamond is wider

-- ---------------------------------------------------------------------------
-- A. the node
-- ---------------------------------------------------------------------------
do
	local defs = {}
	local engine = {register_node = function(name, def) defs[name] = def end,
		get_node_timer = function() return {start = function() end} end,
		get_objects_inside_radius = function() return {} end}
	local quiet = function() return {} end
	local saved_default = rawget(_G, "default")
	_G.default = setmetatable({}, {__index = function() return quiet end})
	dofile(repo .. "/mods/MAPGEN/grug_mapgen/world_nodes.lua")(engine,
		repo .. "/mods/MAPGEN/grug_mapgen", {crop_visual = function() return {} end},
		{source_can_dig = function() return function() end end})
	_G.default = saved_default
	local def = defs[MAILBOX]
	check(def ~= nil, "A the mailbox is registered")
	check(def.diggable == false and def.drop == "" and def.is_ground_content == false,
		"A not diggable, no drop, no ground content")
	check(type(def.on_blast) == "function" and def.on_blast({x = 0, y = 0, z = 0}) == nil,
		"A on_blast is a no-op")
	check(def.paramtype2 == "facedir" and def.drawtype == "nodebox", "A a facedir nodebox")
	check(def.groups and def.groups.not_in_creative_inventory == 1, "A not in creative")
	local want = {"grug_mapgen_mailbox_top.png", "grug_mapgen_mailbox_side.png",
		"grug_mapgen_mailbox_front.png"}
	for _, name in ipairs(want) do
		local f = io.open(repo .. "/mods/MAPGEN/grug_mapgen/textures/" .. name, "rb")
		check(f ~= nil, "A texture file " .. name)
		if f then f:close() end
	end
	check(def.tiles[1] == want[1] and def.tiles[3] == want[2] and def.tiles[6] == want[3],
		"A top, side and front (-z) tiles")
	local player = {is_player = function() return true end}
	local pos = {x = 1, y = 2, z = 3}
	local saved_mail = rawget(_G, "grug_mail")
	_G.grug_mail = nil
	def.on_rightclick(pos, {name = MAILBOX}, player)
	check(true, "A without grug_mail: nothing")
	_G.grug_mail = {}
	def.on_rightclick(pos, {name = MAILBOX}, player)
	check(true, "A without open_mailbox: nothing")
	local calls = {}
	_G.grug_mail = {open_mailbox = function(p, at) calls[#calls + 1] = {p, at} end}
	def.on_rightclick(pos, {name = MAILBOX}, {is_player = function() return false end})
	def.on_rightclick(pos, {name = MAILBOX}, nil)
	check(#calls == 0, "A a clicker that is no player opens nothing")
	def.on_rightclick(pos, {name = MAILBOX}, player)
	check(#calls == 1 and calls[1][1] == player and calls[1][2] == pos,
		"A a right-click opens the mailbox with player and position")
	_G.grug_mail = saved_mail
end

-- ---------------------------------------------------------------------------
-- B. the twelve pads
-- ---------------------------------------------------------------------------
_G.core = _G.core or {}
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local capital = dofile(wp40 .. "/r7_capital_blueprint.lua")
local STARTS = {"hearthpine", "dawnmere", "silverleaf", "stillgrave", "sunscar", "kapok"}
local CAPITALS = {"highcourt", "dur_brannoc", "lethariel", "nhal_veyr", "gor_drazhak", "kezamba"}
-- core.facedir_to_dir for the upright axis: the node's +z (back) side
local BACK = {[0] = {0, 1}, {1, 0}, {0, -1}, {-1, 0}}

local profiles = {}
for _, p in ipairs(settlement.roster) do profiles[p.key] = p end

local pads = {}
local function pad(key, bp)
	local socket
	for _, s in ipairs(bp.landmarks.sockets) do
		if s.id == "travel_waypoint" then socket = s end
	end
	check(socket and socket.role == "waypoint" and socket.y == 1, key .. ": waypoint socket")
	local at, boxes = {}, {}
	for _, c in ipairs(bp.cells) do
		at[c.x .. "," .. c.y .. "," .. c.z] = c.name
		if c.name == MAILBOX then boxes[#boxes + 1] = c end
	end
	check(#boxes == 1, key .. ": one mailbox (" .. #boxes .. ")")
	local m = boxes[1]
	local dx, dz = m.x - socket.x, m.z - socket.z
	local cheb = math.max(math.abs(dx), math.abs(dz))
	check(m.y == 1, key .. ": the mailbox stands on the ground course")
	check(dx ~= 0 and dz ~= 0, key .. ": off the pad's cross arms")
	check(cheb >= 2, key .. ": not beside the stone")
	check(cheb <= 3 and math.abs(dx) + math.abs(dz) <= REACH,
		key .. ": on the pad, within reach of the waypoint socket")
	local ground = at[m.x .. ",0," .. m.z]
	check(ground ~= nil and ground ~= "air", key .. ": on ground")
	check((at[m.x .. ",2," .. m.z] or "air") == "air", key .. ": nothing over it")
	for _, s in ipairs(bp.landmarks.sockets) do
		check(not (s.x == m.x and s.z == m.z), key .. ": no socket " .. s.id .. " on it")
	end
	local param2 = m.param2 or 0
	check(param2 < 4, key .. ": upright")
	local back = BACK[param2]
	-- the front looks against the back; it must look toward the stone
	check(-back[1] * (socket.x - m.x) - back[2] * (socket.z - m.z) > 0,
		key .. ": its front faces the stone")
	pads[#pads + 1] = {key = key, bp = bp, socket = socket, mailbox = m, dx = dx, dz = dz}
end
for _, key in ipairs(STARTS) do
	local bp = dofile(wp40 .. "/r7_" .. key .. "_blueprint.lua")
	if type(bp) == "function" then bp = bp() end
	pad(key, bp)
end
local plots = {}
for _, key in ipairs(CAPITALS) do
	local kit = capital.kit(key)
	pad(key, kit.core.build())
	for _, plot in ipairs(kit.plots) do plots[#plots + 1] = {key .. "/" .. plot.id, plot.build} end
end
check(#pads == 12, "twelve pads")

-- ---------------------------------------------------------------------------
-- C. none elsewhere
-- ---------------------------------------------------------------------------
local function count(bp)
	local n = 0
	for _, c in ipairs(bp.cells) do
		if c.name == MAILBOX then n = n + 1 end
	end
	return n
end
local others = 0
local options = {raw_sha256 = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256(),
	full_seed = "42"}
for _, profile in ipairs(settlement.roster) do
	if profile.slot ~= "start" and profile.slot ~= "capital" then
		local bp = dofile(wp40 .. "/" .. profile.blueprint_file)(options, profile)
		if type(bp) == "function" then bp = bp(options) end
		check(count(bp) == 0, profile.key .. ": no mailbox")
		others = others + 1
	end
end
for _, plot in ipairs(plots) do
	check(count(plot[2]()) == 0, plot[1] .. ": no mailbox")
end
check(others == #settlement.roster - 12, "every other roster composition looked at (" ..
	others .. ")")

-- ---------------------------------------------------------------------------
-- D. the mailbox's name (mail plan §3.16)
-- ---------------------------------------------------------------------------
_G.grug_core = {}
core.dir_to_yaw = core.dir_to_yaw or function(d) return math.atan2(-d.x, d.z) end
_G.vector = _G.vector or {}
vector.new = vector.new or function(x, y, z) return {x = x, y = y, z = z} end
dofile(repo .. "/mods/CORE/grug_core/settlement_sockets.lua")
for index, row in ipairs(pads) do
	local p = profiles[row.key]
	row.anchor = {x = index * 1000, y = 10 + index, z = -index * 700}
	grug_core.register_settlement_sockets(row.key, p.race, row.anchor,
		row.bp.landmarks.sockets, p.label, p.slot)
end
local function resolve(pos)
	local found = {}
	for _, s in ipairs(grug_core.settlement_socket_settlements()) do
		if s.slot == "start" or s.slot == "capital" then
			for _, entry in ipairs(grug_core.settlement_sockets_at(s.key)) do
				if entry.role == "waypoint" and entry.pos.y == pos.y and
						math.max(math.abs(entry.pos.x - pos.x), math.abs(entry.pos.z - pos.z)) <= 3 then
					found[#found + 1] = s
				end
			end
		end
	end
	return found
end
for _, row in ipairs(pads) do
	local m = row.mailbox
	local pos = {x = row.anchor.x + m.x, y = row.anchor.y + m.y, z = row.anchor.z + m.z}
	local found = resolve(pos)
	check(#found == 1 and found[1].key == row.key and found[1].display_name == profiles[row.key].label,
		row.key .. ": the mailbox resolves to " .. profiles[row.key].label)
	print(("  %-12s %-12s mailbox at stone %+d,%+d facedir %d"):format(row.key,
		found[1].display_name, row.dx, row.dz, m.param2 or 0))
end

print(("R48 WORLD PORTABLE PASS checks=%d"):format(checks))
