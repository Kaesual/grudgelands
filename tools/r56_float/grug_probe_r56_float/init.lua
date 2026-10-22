-- Disposable Round 56 FLOAT probe (never shipped), staged by
-- tools/r56_float/probe.sh through tools/luanti_headless.sh.
--
-- High in the sky (y 300, forceloaded, no player needed) it builds a
-- stone-walled pool of water sources 6 deep (surface y 306.5), a land
-- platform beside it and a small lava basin. Then, at the same moment:
--   land    N items on the platform (the way every drop starts: add_item);
--   drop    N items let fall into the pool from 6 nodes above its surface;
--   bottom  N items spawned at the pool's floor;
--   lava    one item into the lava.
-- Tools only (one per stack), so nothing merges.
--
-- Lines (prefix "[r56float] "):
--   Y t=<s> g=<group> n=<i> y=<y> vy=<vy>      a few items every 0.5 s
--   SETTLE g=<group> ...                       the state of every group at T+18 s
--   COST g=<group> items=.. steps=.. lookups_per_step=.. us_per_step=..
--                                              T+20..T+30 s: node lookups
--                                              (get_node/get_node_or_nil) and
--                                              time inside the item's on_step
--   SETPOS g=<group> per_item=<min>..<max>     set_pos calls made by on_step
--   DRAIN ...                                  the pool emptied at T+30 s,
--                                              the state at T+34 s
-- Ends with "[r56float] shutdown".
local P = "[r56float] "
local N = 40
local function log(msg) core.log("action", P .. msg) end
local function now() return core.get_us_time() / 1e6 end

local ORIGIN = vector.new(40, 300, 40)
local POOL = {x0 = 1, x1 = 8, z0 = 1, z1 = 8, y0 = 1, y1 = 6} -- water, relative
local LAND = {x0 = 12, x1 = 21, z0 = 0, z1 = 9}
local LAVA = {x0 = 25, x1 = 26, z0 = 1, z1 = 2, y0 = 1, y1 = 2}

local TOOLS = {}
local records = {}
local by_ent = {}
local in_step -- the record whose on_step runs, or nil
local measuring = false

core.register_on_mods_loaded(function()
	for name, def in pairs(core.registered_tools) do
		if def.description and def.description ~= "" and
				(def.groups or {}).not_in_creative_inventory ~= 1 and
				(def.groups or {}).flammable == nil then
			TOOLS[#TOOLS + 1] = name
		end
	end
	table.sort(TOOLS)

	-- node lookups made inside an item's on_step
	local get_node, get_node_or_nil = core.get_node, core.get_node_or_nil
	core.get_node = function(...)
		if in_step and measuring then in_step.lookups = in_step.lookups + 1 end
		return get_node(...)
	end
	core.get_node_or_nil = function(...)
		if in_step and measuring then in_step.lookups = in_step.lookups + 1 end
		return get_node_or_nil(...)
	end

	local item = core.registered_entities["__builtin:item"]
	local step = item.on_step
	item.on_step = function(self, dtime, moveresult, ...)
		local rec = by_ent[self]
		if not rec then return step(self, dtime, moveresult, ...) end
		if not rec.wrapped_setpos then
			-- count the set_pos calls this object's on_step makes
			rec.wrapped_setpos = true
			-- (getmetatable gives the method table: ObjectRef sets __metatable)
			local mt = getmetatable(self.object)
			local index = type(mt) == "table" and (mt.set_pos and mt or mt.__index)
			if type(index) == "table" and not index._r56_setpos then
				local set_pos = index.set_pos
				index._r56_setpos = true
				index.set_pos = function(obj, ...)
					if in_step and in_step.ent.object == obj then
						in_step.setpos = in_step.setpos + 1
					end
					return set_pos(obj, ...)
				end
			end
		end
		in_step = rec
		local t0 = core.get_us_time()
		local result = step(self, dtime, moveresult, ...)
		local spent = core.get_us_time() - t0
		in_step = nil
		if measuring then
			rec.steps = rec.steps + 1
			rec.us = rec.us + spent
		end
		return result
	end
end)

local function set(rel, name)
	core.set_node(vector.add(ORIGIN, rel), {name = name})
end

local function build()
	for x = 0, 27 do
		for z = 0, 9 do set(vector.new(x, 0, z), "default:stone") end
	end
	for x = POOL.x0 - 1, POOL.x1 + 1 do
		for z = POOL.z0 - 1, POOL.z1 + 1 do
			for y = POOL.y0, POOL.y1 + 1 do
				local inside = x >= POOL.x0 and x <= POOL.x1 and z >= POOL.z0 and z <= POOL.z1
				if not inside then
					set(vector.new(x, y, z), "default:stone")
				elseif y <= POOL.y1 then
					set(vector.new(x, y, z), "default:water_source")
				end
			end
		end
	end
	for x = LAVA.x0 - 1, LAVA.x1 + 1 do
		for z = LAVA.z0 - 1, LAVA.z1 + 1 do
			for y = LAVA.y0, LAVA.y1 + 1 do
				local inside = x >= LAVA.x0 and x <= LAVA.x1 and z >= LAVA.z0 and z <= LAVA.z1
				if not inside then
					set(vector.new(x, y, z), "default:stone")
				elseif y <= LAVA.y1 then
					set(vector.new(x, y, z), "default:lava_source")
				end
			end
		end
	end
end

local function spawn(group, rel, n)
	local pos = vector.add(ORIGIN, rel)
	local obj = core.add_item(pos, ItemStack(TOOLS[(#records) % #TOOLS + 1]))
	if not obj then
		log(("NOSPAWN g=%s n=%d"):format(group, n))
		return
	end
	local ent = obj:get_luaentity()
	local rec = {group = group, n = n, ent = ent, steps = 0, us = 0, lookups = 0, setpos = 0}
	records[#records + 1] = rec
	by_ent[ent] = rec
end

local function each(group, fn)
	for _, rec in ipairs(records) do
		if rec.group == group then fn(rec) end
	end
end

local function state(group)
	local count, gone, ymin, ymax, vmax = 0, 0, math.huge, -math.huge, 0
	each(group, function(rec)
		local pos = rec.ent.object and rec.ent.object:get_pos()
		if not pos then
			gone = gone + 1
			return
		end
		count = count + 1
		local v = rec.ent.object:get_velocity()
		ymin, ymax = math.min(ymin, pos.y), math.max(ymax, pos.y)
		vmax = math.max(vmax, math.abs(v.x) + math.abs(v.y) + math.abs(v.z))
	end)
	return ("g=%s items=%d gone=%d y=%.3f..%.3f max|v|=%.3f"):format(group, count, gone,
		ymin, ymax, vmax)
end

local function track(t0)
	local t = now() - t0
	for _, rec in ipairs(records) do
		if rec.n <= 3 or rec.group == "lava" then
			local pos = rec.ent.object and rec.ent.object:get_pos()
			if pos then
				local v = rec.ent.object:get_velocity()
				log(("Y t=%.1f g=%s n=%d y=%.3f vy=%.3f"):format(t, rec.group, rec.n, pos.y, v.y))
			else
				log(("Y t=%.1f g=%s n=%d gone"):format(t, rec.group, rec.n))
			end
		end
	end
end

local function cost(group)
	local items, steps, lookups, us, smin, smax = 0, 0, 0, 0, math.huge, 0
	each(group, function(rec)
		if rec.steps > 0 then
			items = items + 1
			steps, lookups, us = steps + rec.steps, lookups + rec.lookups, us + rec.us
		end
		smin, smax = math.min(smin, rec.setpos), math.max(smax, rec.setpos)
	end)
	log(("COST g=%s items=%d steps=%d lookups_per_step=%.3f us_per_step=%.2f"):format(group,
		items, steps, steps > 0 and lookups / steps or 0, steps > 0 and us / steps or 0))
	log(("SETPOS g=%s per_item=%d..%d"):format(group, smin, smax))
end

local function run()
	build()
	core.after(1, function()
		local n = {land = 0, drop = 0, bottom = 0}
		for i = 0, N - 1 do
			n.land = n.land + 1
			spawn("land", vector.new(LAND.x0 + i % 10, 1.5, LAND.z0 + math.floor(i / 10) * 2), n.land)
		end
		-- 64 pool cells: the first N drops, then N bottoms, wrapping over the cells
		local cells = {}
		for x = POOL.x0, POOL.x1 do
			for z = POOL.z0, POOL.z1 do cells[#cells + 1] = {x = x, z = z} end
		end
		for i = 1, N do
			local c = cells[(i - 1) % #cells + 1]
			n.drop = n.drop + 1
			spawn("drop", vector.new(c.x, POOL.y1 + 6.5, c.z), n.drop)
		end
		for i = 1, N do
			local c = cells[(i + N - 1) % #cells + 1]
			n.bottom = n.bottom + 1
			spawn("bottom", vector.new(c.x + 0.2, POOL.y0 + 0.3, c.z - 0.2), n.bottom)
		end
		spawn("lava", vector.new(LAVA.x0, LAVA.y1 + 3, LAVA.z0), 1)
		local t0 = now()
		log(("SPAWNED land=%d drop=%d bottom=%d surface_y=%.1f floor_top_y=%.1f"):format(n.land,
			n.drop, n.bottom, ORIGIN.y + POOL.y1 + 0.5, ORIGIN.y + 0.5))
		local tracker
		tracker = function()
			if now() - t0 > 34 then return end
			track(t0)
			core.after(0.5, tracker)
		end
		tracker()
		core.after(18, function()
			for _, g in ipairs({"land", "drop", "bottom", "lava"}) do log("SETTLE " .. state(g)) end
		end)
		core.after(20, function()
			for _, rec in ipairs(records) do rec.steps, rec.us, rec.lookups = 0, 0, 0 end
			measuring = true
		end)
		core.after(30, function()
			measuring = false
			for _, g in ipairs({"land", "drop", "bottom"}) do cost(g) end
			for x = POOL.x0, POOL.x1 do
				for z = POOL.z0, POOL.z1 do
					for y = POOL.y0, POOL.y1 do set(vector.new(x, y, z), "air") end
				end
			end
			log("DRAIN pool emptied")
		end)
		core.after(34, function()
			for _, g in ipairs({"land", "drop", "bottom", "lava"}) do log("DRAIN " .. state(g)) end
			log("shutdown")
			core.request_shutdown("r56 float probe done", false, 0)
		end)
	end)
end

core.after(2, function()
	local minp = ORIGIN
	local maxp = vector.add(ORIGIN, vector.new(27, 16, 9))
	for bx = math.floor(minp.x / 16), math.floor(maxp.x / 16) do
		for bz = math.floor(minp.z / 16), math.floor(maxp.z / 16) do
			for by = math.floor(minp.y / 16), math.floor(maxp.y / 16) do
				core.forceload_block(vector.new(bx * 16, by * 16, bz * 16), true, -1)
			end
		end
	end
	core.emerge_area(vector.offset(minp, -16, -16, -16), vector.offset(maxp, 16, 16, 16),
		function(_, _, remaining)
			if remaining > 0 then return end
			core.after(0, run)
		end)
end)
