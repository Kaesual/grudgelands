-- Disposable 0.49.1 DOOR probe (tools/r491_door/probe.sh). Never shipped.
--
-- CAUSE: a closed wooden door (the bottom node with its two-node box, the
-- unpointable `doors:hidden` on top) and a stand-in with a dialog NPC's
-- selection box (read from the real vendor definition) behind it. From both
-- sides of the door, at several distances, eye height 1.47 (player_api), one
-- ray per aim point on the panel, upper and lower half, cut at the hand
-- reach of 4 like the client's pointing. The FIRST result of core.raycast is
-- what the client points at: client and server share
-- Environment::continueRaycast and its RaycastSort (only a `rotate = true`
-- object box differs, and an NPC box is not rotated). Repeated with the door
-- open and with no door.
--
-- FIX (once grug_mobs.door_before_npc exists): the helper on the same rays
-- with a fake clicker. Expected: it hands the click to the closed door
-- (which then is open) on every ray where the engine points at the NPC
-- behind it, and nowhere else: not where the engine already points at the
-- door (the client sends that node click itself), not with the door open,
-- without a door, or with the NPC in front of the door. Then one click per real
-- dialog NPC kind (vendor, villager, elder) through its own on_rightclick.
--
-- Every line carries "[r491door]"; the probe ends the server when done.
local P = "[r491door] "
local function log(s) core.log("action", P .. s) end

core.register_entity("grug_probe_r491_door:npc", {
	initial_properties = {visual = "cube", textures = {"blank.png"},
		visual_size = {x = 0.6, y = 1.7, z = 0.6}, physical = false,
		collide_with_objects = false, static_save = false, pointable = true,
		selectionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}},
})

local BASE = vector.new(8, 200, 8)
local FLOOR_Y = BASE.y - 0.5
local EYE = 1.47
local REACH = 4
local DOOR = "doors:door_wood"
local phase, t, emerged = "wait", 0, false

local function fmt(v) return ("%.3f"):format(v) end

local function place_door(state)
	core.set_node(BASE, {name = "air"})
	core.set_node(vector.offset(BASE, 0, 1, 0), {name = "air"})
	if state == "none" then return end
	if state == "closed" then
		core.set_node(BASE, {name = DOOR .. "_a", param2 = 0})
	else
		-- doors.door_toggle's transform for state 1, dir 0.
		core.set_node(BASE, {name = DOOR .. "_c", param2 = 1})
		core.get_meta(BASE):set_int("state", 1)
	end
	core.set_node(vector.offset(BASE, 0, 1, 0), {name = "doors:hidden", param2 = 0})
end

local function build()
	for x = -5, 5 do
		for z = -6, 6 do
			core.set_node(vector.new(BASE.x + x, BASE.y - 1, BASE.z + z), {name = "default:stone"})
			for y = 0, 3 do
				core.set_node(vector.new(BASE.x + x, BASE.y + y, BASE.z + z), {name = "air"})
			end
		end
	end
end

-- The panel of the closed door at param2 0, measured, not assumed.
local function panel_faces()
	local function first_z(from, to)
		for pointed in core.raycast(from, to, false, false) do
			if pointed.type == "node" then return pointed.intersection_point.z - BASE.z end
		end
	end
	local y = BASE.y + 0.2
	local out_face = first_z(vector.new(BASE.x, y, BASE.z - 3), vector.new(BASE.x, y, BASE.z + 3))
	local in_face = first_z(vector.new(BASE.x, y, BASE.z + 3), vector.new(BASE.x, y, BASE.z - 3))
	return out_face, in_face
end

local SIDES = {
	-- out: the player on -z, the panel's outer face; the NPC behind it is
	-- in the door's own cell (gap 0.075: an NPC on the cell centre) or beyond.
	{id = "out", sign = -1, gaps = {0.0, 0.075, 0.15, 0.25, 0.4, 0.6, 1.075}},
	-- in: the player on +z; the NPC behind is in the cell in front of the
	-- panel (gap 0.2: on that cell's centre) or beyond.
	{id = "in", sign = 1, gaps = {0.0, 0.1, 0.2, 0.3, 0.45, 0.65, 1.2}},
}
local DISTANCES = {0.8, 1.2, 1.6, 2.0, 2.5, 3.0, 3.5}
local AIM_X = {-0.25, 0, 0.25}
local HALVES = {lower = {0.25, 0.75}, upper = {1.25, 1.75}}

-- Every ray of one side: {half, eye, dir}.
local function rays(side, faces)
	local face = BASE.z + (side.id == "out" and faces.out or faces.inner)
	local list = {}
	for _, d in ipairs(DISTANCES) do
		local eye = vector.new(BASE.x, FLOOR_Y + EYE, face + side.sign * d)
		for half, heights in pairs(HALVES) do
			for _, h in ipairs(heights) do
				for _, ax in ipairs(AIM_X) do
					local aim = vector.new(BASE.x + ax, FLOOR_Y + h, face)
					local span = vector.distance(eye, aim)
					if span <= REACH then
						list[#list + 1] = {half = half, eye = eye,
							dir = vector.normalize(vector.subtract(aim, eye))}
					end
				end
			end
		end
	end
	return list
end

-- The NPC stand-in's centre behind (or, gap < 0, in front of) the panel.
local function npc_pos(side, faces, gap)
	if side.id == "out" then
		return vector.new(BASE.x, FLOOR_Y, BASE.z + faces.inner + 0.3 + gap)
	end
	return vector.new(BASE.x, FLOOR_Y, BASE.z + faces.out - 0.3 - gap)
end

local function first_hit(ray, npc)
	for pointed in core.raycast(ray.eye, vector.add(ray.eye, vector.multiply(ray.dir, REACH)), true, false) do
		if pointed.type == "object" and pointed.ref == npc then return "npc", pointed end
		if pointed.type == "node" then return "node", pointed end
	end
	return "nothing"
end

-- Is the NPC the physically nearest thing on the ray (true distances, not
-- the engine's order)? Then it, not the door, answers.
local function npc_physically_first(ray, npc)
	local npc_d, node_d
	for pointed in core.raycast(ray.eye, vector.add(ray.eye, vector.multiply(ray.dir, REACH)), true, false) do
		local d = vector.distance(ray.eye, pointed.intersection_point)
		if pointed.type == "object" and pointed.ref == npc then
			npc_d = npc_d or d
		elseif pointed.type == "node" then
			node_d = math.min(node_d or d, d)
		end
	end
	return npc_d ~= nil and (node_d == nil or npc_d < node_d)
end

local function fake_clicker(ray)
	local feet = vector.offset(ray.eye, 0, -EYE, 0)
	local c = {}
	function c:is_player() return true end
	function c:get_player_name() return "r491door" end
	function c:get_pos() return vector.copy(feet) end
	function c:get_properties() return {eye_height = EYE} end
	function c:get_eye_offset() return vector.new(0, 0, 0), vector.new(0, 0, 0) end
	function c:get_look_dir() return vector.copy(ray.dir) end
	function c:get_look_horizontal() return core.dir_to_yaw(ray.dir) end
	function c:get_wielded_item() return ItemStack("") end
	function c:get_player_control() return {sneak = false} end
	return c
end

local function door_open()
	local ref = doors.get(BASE)
	return ref ~= nil and ref:state()
end

local function run()
	build()
	place_door("closed")
	local out_face, in_face = panel_faces()
	log(("PANEL closed param2=0: outer face z=%s inner face z=%s (node-relative)"):format(
		fmt(out_face or 99), fmt(in_face or 99)))
	local faces = {out = out_face, inner = in_face}
	local vendor_name, villager_name, elder_name
	for name in pairs(core.registered_entities) do
		if name:find("^grug_traders:vendor_general_") then vendor_name = vendor_name or name end
		if name:find("^grug_mobs:villager_") then villager_name = villager_name or name end
		if name:find("^grug_mobs:elder_") then elder_name = elder_name or name end
	end
	local vdef = core.registered_entities[vendor_name or ""]
	local box = vdef and vdef.initial_properties and vdef.initial_properties.selectionbox
	if box then
		log(("NPC box %s: %s"):format(vendor_name, table.concat(box, ",")))
	end
	local npc = core.add_entity(BASE, "grug_probe_r491_door:npc")
	if box then npc:set_properties({selectionbox = box}) end

	-- CAUSE: what the shared engine ray points at first.
	for _, state in ipairs({"closed", "open", "none"}) do
		place_door(state)
		for _, side in ipairs(SIDES) do
			local list = rays(side, faces)
			for _, gap in ipairs(side.gaps) do
				npc:set_pos(npc_pos(side, faces, gap))
				local tally = {lower = {n = 0, npc = 0, node = 0}, upper = {n = 0, npc = 0, node = 0}}
				local margin = {lower = {}, upper = {}}
				for _, ray in ipairs(list) do
					local kind, pointed = first_hit(ray, npc)
					local row = tally[ray.half]
					row.n = row.n + 1
					if kind == "npc" then row.npc = row.npc + 1 end
					if kind == "node" then row.node = row.node + 1 end
					-- The physical order on this ray, for the closed door.
					if state == "closed" and kind == "npc" then
						local node_d
						for p in core.raycast(ray.eye, vector.add(ray.eye, vector.multiply(ray.dir, REACH)), false, false) do
							node_d = vector.distance(ray.eye, p.intersection_point)
							break
						end
						local npc_d = vector.distance(ray.eye, pointed.intersection_point)
						if node_d and node_d < npc_d then
							local m = margin[ray.half]
							m.n = (m.n or 0) + 1
							m.max = math.max(m.max or 0, npc_d - node_d)
						end
					end
				end
				log(("CAUSE door=%s side=%s gap=%s upper: npc %d/%d door %d | lower: npc %d/%d door %d%s"):format(
					state, side.id, fmt(gap), tally.upper.npc, tally.upper.n, tally.upper.node,
					tally.lower.npc, tally.lower.n, tally.lower.node,
					state == "closed" and (" | npc first although behind the panel: upper %d (up to %s m) lower %d (up to %s m)"):format(
						margin.upper.n or 0, fmt(margin.upper.max or 0), margin.lower.n or 0,
						fmt(margin.lower.max or 0)) or ""))
			end
		end
	end

	-- FIX: the helper on the same rays.
	local helper = grug_mobs.door_before_npc
	if not helper then
		log("FIX helper grug_mobs.door_before_npc absent (before the fix)")
	else
		local fails = 0
		local function expect(label, ok)
			if not ok then
				fails = fails + 1
				if fails <= 20 then log("FIX FAIL " .. label) end
			end
		end
		local self = npc:get_luaentity()
		local counts = {}
		for _, state in ipairs({"closed", "open", "none"}) do
			for _, side in ipairs(SIDES) do
				local list = rays(side, faces)
				-- behind the panel (every gap), and one NPC in front of it.
				local gaps = {}
				for _, g in ipairs(side.gaps) do gaps[#gaps + 1] = g end
				gaps[#gaps + 1] = -0.7
				for _, gap in ipairs(gaps) do
					npc:set_pos(npc_pos(side, faces, gap))
					for _, ray in ipairs(list) do
						place_door(state)
						-- Only the reported click: the engine points at the NPC
						-- (else the client sends a node click itself) and the
						-- closed door is physically first.
						local want = state == "closed" and first_hit(ray, npc) == "npc" and
							not npc_physically_first(ray, npc)
						local handed = helper(self, fake_clicker(ray))
						local key = state .. " " .. side.id .. " " .. ray.half .. (gap < 0 and " npc-in-front" or "")
						counts[key] = (counts[key] or 0) + (handed and 1 or 0)
						counts[key .. " n"] = (counts[key .. " n"] or 0) + 1
						counts[key .. " want"] = (counts[key .. " want"] or 0) + (want and 1 or 0)
						expect(("%s gap=%s eye=%s dir=%s handed=%s"):format(key, fmt(gap),
							core.pos_to_string(ray.eye, 2), core.pos_to_string(ray.dir, 2), tostring(handed)),
							handed == want)
						if state == "closed" then
							expect(key .. " door state after the click", door_open() == want)
						elseif state == "open" then
							expect(key .. " open door stays open", door_open())
						end
					end
				end
			end
		end
		local keys = {}
		for k in pairs(counts) do
			if not k:find(" n$") and not k:find(" want$") then keys[#keys + 1] = k end
		end
		table.sort(keys)
		for _, k in ipairs(keys) do
			log(("FIX %s: door took the click %d/%d (want %d)"):format(k, counts[k], counts[k .. " n"],
				counts[k .. " want"] or 0))
		end

		-- Wiring: each real dialog NPC kind behind the closed door, clicked
		-- through its own (wrapped) on_rightclick.
		local side = SIDES[1]
		local ray = {eye = vector.new(BASE.x, FLOOR_Y + EYE, BASE.z + faces.out - 2), dir = nil}
		ray.dir = vector.normalize(vector.subtract(vector.new(BASE.x, FLOOR_Y + 1.5, BASE.z + faces.out), ray.eye))
		npc:set_pos(vector.new(BASE.x + 4, FLOOR_Y, BASE.z + 5))
		for _, name in ipairs({vendor_name, villager_name, elder_name}) do
			place_door("closed")
			local pos = npc_pos(side, faces, 0.075)
			local obj = name and core.add_entity(pos, name)
			local ent = obj and obj:get_luaentity()
			if not ent then
				expect("WIRE " .. tostring(name) .. " could not be added", false)
			else
				obj:set_pos(pos)
				ent:on_rightclick(fake_clicker(ray))
				local opened = door_open()
				log(("WIRE %s behind the closed door, upper half from 2 m: door %s"):format(
					name, opened and "opened" or "STAYED SHUT"))
				expect("WIRE " .. name, opened)
				obj:remove()
			end
		end
		log(("RESULT FIX %s fails=%d"):format(fails == 0 and "PASS" or "FAIL", fails))
	end
	npc:remove()
end

core.register_globalstep(function(dtime)
	t = t + dtime
	if phase == "wait" and t > 3 then
		core.emerge_area(vector.subtract(BASE, {x = 8, y = 8, z = 8}),
			vector.add(BASE, {x = 8, y = 8, z = 8}), function(_, _, remaining)
				if remaining == 0 then emerged = true end
			end)
		core.forceload_block(BASE, true)
		phase, t = "emerge", 0
	elseif phase == "emerge" and (emerged or t > 60) then
		local ok, err = pcall(run)
		if not ok then log("RESULT ERROR " .. tostring(err)) end
		phase, t = "done", 0
	elseif phase == "done" and t > 1 then
		log("RESULT DONE")
		phase = "off"
		core.request_shutdown("r491door probe done", false, 0)
	end
end)
