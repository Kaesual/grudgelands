-- mods/default/item_entity.lua

local builtin_item = minetest.registered_entities["__builtin:item"]

-- strictly speaking none of this is part of the API, so do some checks
-- and if it looks wrong skip the modifications
if not builtin_item or type(builtin_item.set_item) ~= "function" or type(builtin_item.on_step) ~= "function" then
	minetest.log("warning", "Builtin item entity does not look as expected, skipping overrides.")
	return
end

local smoke_particles = {
	amount = 3,
	time = 0.1,
	minpos = vector.new(-0.1, -0.1, -0.1),
	maxpos = vector.new(0.1, 0.1, 0.1),
	minvel = vector.new(0, 2.5, 0),
	maxvel = vector.new(0, 2.5, 0),
	minacc = vector.new(-0.15, -0.02, -0.15),
	maxacc = vector.new(0.15, -0.01, 0.15),
	minexptime = 4,
	maxexptime = 6,
	minsize = 5,
	maxsize = 5,
	collisiondetection = true,
	texture = {
		name = "default_item_smoke.png"
	}
}
if minetest.features.particle_blend_clip then
	smoke_particles.texture.blend = "clip"
end

-- GRUG PATCH (0.49.1 DROP): seconds after an item comes to rest at which its
-- resting position is sent again (see on_step).
local RESYNC_FIRST, RESYNC_LAST = 0.5, 2

-- GRUG PATCH (R56 FLOAT): an item inside water rises straight up at RISE
-- nodes/s and rests at the surface; the engine has no liquid physics for
-- entities, so the builtin item sinks to the bottom. "Water" is any liquid
-- by liquidtype except the lava group. Items lying on land never look.
local RISE = 2
local GRAVITY = tonumber(core.settings:get("movement_gravity")) or 9.81
local ZERO = vector.new(0, 0, 0)

-- The height of the water surface in the node at pos, or nil when the node
-- holds no water. A flowing node's level as the engine draws it
-- (getLiquidNeighborhood in src/client/content_mapblock.cpp); one falling
-- down a column counts as full.
local function water_top(pos)
	local node = core.get_node_or_nil(pos)
	local def = node and core.registered_nodes[node.name]
	if not def or (def.liquidtype or "none") == "none" or
			(def.groups and def.groups.lava or 0) > 0 then
		return nil
	end
	local y = math.floor(pos.y + 0.5)
	if def.liquidtype ~= "flowing" or node.param2 >= 8 then
		return y + 0.5
	end
	local range = math.max(1, math.min(8, def.liquid_range or 8))
	local level = math.max(0, node.param2 % 8 - (8 - range))
	return y - 0.5 + (level + 0.5) / range
end

-- Rest at height y: still, and sent through the 0.49.1 resync below.
local function float_settle(self, pos, y)
	self._grug_float, self._grug_top = "rest", nil
	pos.y = y
	self.object:set_acceleration(ZERO)
	self.object:set_velocity(ZERO)
	self.object:set_pos(pos)
	self._grug_resync = 0
end

-- Called while the item flies, on the step it lands and while it floats:
-- one node lookup per call (a few more on a long step's settle).
local function float_step(self, moveresult)
	local pos = self.object:get_pos()
	if not pos then return end
	if self._grug_float == "rest" then
		-- still on water? Otherwise it falls as usual again.
		local top = water_top(vector.new(pos.x, pos.y - 0.1, pos.z))
		if not top or top < pos.y - 0.25 then
			self._grug_float = nil
			self.object:set_acceleration(vector.new(0, -GRAVITY, 0))
		end
		return
	end
	local top = water_top(pos)
	if top and pos.y < top then
		if self._grug_float ~= "rise" then
			-- into the water: no more drift, straight up
			self._grug_float = "rise"
			self.object:set_acceleration(ZERO)
			self.object:set_velocity(vector.new(0, RISE, 0))
		elseif moveresult.collides then
			return float_settle(self, pos, pos.y) -- held under a ceiling
		end
		self._grug_top = top
	elseif self._grug_float == "rise" then
		-- surfaced: rest on the water it rose through. A long server step
		-- can lift it more than a node past the last water node it was in,
		-- so the highest water between here and that node counts (this
		-- step only, at most a node per RISE * dtime).
		if not top then
			top = self._grug_top
			for y = math.floor(pos.y + 0.5) - 1, math.floor(self._grug_top) + 1, -1 do
				local found = water_top(vector.new(pos.x, y, pos.z))
				if found then
					top = found
					break
				end
			end
		end
		float_settle(self, pos, top)
	end
end

local item = {
	set_item = function(self, itemstring, ...)
		builtin_item.set_item(self, itemstring, ...)

		local stack = ItemStack(itemstring)
		local itemdef = minetest.registered_items[stack:get_name()]
		if itemdef and itemdef.groups.flammable ~= 0 then
			self.flammable = itemdef.groups.flammable
		end
	end,

	burn_up = function(self)
		-- disappear in a smoke puff
		local p = self.object:get_pos()
		self.object:remove()
		minetest.sound_play("default_item_smoke", {
			pos = p,
			gain = 1.0,
			max_hear_distance = 8,
		}, true)
		local ps = table.copy(smoke_particles)
		ps.minpos = vector.add(ps.minpos, p)
		ps.maxpos = vector.add(ps.maxpos, p)
		minetest.add_particlespawner(ps)
	end,

	on_step = function(self, dtime, moveresult, ...)
		local was_moving = self.moving_state -- (R56 FLOAT, below)
		builtin_item.on_step(self, dtime, moveresult, ...)
		local resync = self._grug_resync -- (0.49.1 DROP, below)

		-- GRUG PATCH (R56 FLOAT): water lifts the item. Looked at while it
		-- flies, on the step it lands (also a first step that lands at
		-- once) and while it floats; never while it lies on land or slides
		-- on ice. A settle starts the resync clock below with the next step,
		-- as a landing does.
		if moveresult and self.physical_state and self.itemstring ~= "" and
				(self._grug_float or not moveresult.collides or
				(not self.moving_state and (self._grug_unsettled or was_moving))) then
			float_step(self, moveresult)
		end

		-- GRUG PATCH (0.49.1 DROP): the stop is sent again. When an item comes
		-- to rest, the builtin zeroes its velocity and the engine sends that
		-- once, unreliably (LuaEntitySAO::step, never again while it lies
		-- still); a client that loses the packet keeps the last flight
		-- velocity and draws the item sliding over the ground for good, where
		-- no server ray finds it. set_pos re-sends position and velocity, so
		-- the client gets the stop twice more (upstream-workarounds.md §7).
		if moveresult then
			if not moveresult.collides or self.moving_state or self._grug_float == "rise" then
				self._grug_unsettled = true -- in the air, or sliding on ice
			elseif self._grug_unsettled then
				-- at rest from this step on: the clock starts with the next one
				self._grug_unsettled, self._grug_resync, resync = nil, 0, nil
			end
		end
		if resync then
			local after = resync + dtime
			if (resync < RESYNC_FIRST and after >= RESYNC_FIRST) or after >= RESYNC_LAST then
				local pos = self.object:get_pos()
				if pos then self.object:set_pos(pos) end
			end
			self._grug_resync = after < RESYNC_LAST and after or nil
		end

		if self.flammable then
			-- flammable, check for igniters every 10 s
			self.ignite_timer = (self.ignite_timer or 0) + dtime
			if self.ignite_timer > 10 then
				self.ignite_timer = 0

				local pos = self.object:get_pos()
				if pos == nil then
					return -- object already deleted
				end
				local node = minetest.get_node_or_nil(pos)
				if not node then
					return
				end

				-- Immediately burn up flammable items in lava
				if minetest.get_item_group(node.name, "lava") > 0 then
					self:burn_up()
				else
					--  otherwise there'll be a chance based on its igniter value
					local burn_chance = self.flammable
						* minetest.get_item_group(node.name, "igniter")
					if burn_chance > 0 and math.random(0, burn_chance) ~= 0 then
						self:burn_up()
					end
				end
			end
		end
	end,
}

-- set defined item as new __builtin:item, with the old one as fallback table
setmetatable(item, { __index = builtin_item })
minetest.register_entity(":__builtin:item", item)
