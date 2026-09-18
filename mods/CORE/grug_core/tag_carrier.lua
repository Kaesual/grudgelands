-- Per-viewer nametags (combat_stats.md section 6).
--
-- Object nametag properties are global. A transparent child entity gives the
-- text its own managed observer set, so each connected player gets an
-- independent 25/30-node hysteresis state while the parent stays unchanged.

local ENTITY_NAME = "grug_core:tag_carrier"
local SHOW_D2 = 25 * 25
local HIDE_D2 = 30 * 30
local SNAPSHOT_INTERVAL = 1

local player_snapshot = {}
local player_count = 0
local snapshot_elapsed = 0
local managed_carriers = {}
local carrier_by_parent = {}

local function object_valid(object)
	return object and object:is_valid()
end

local function same_set(left, right)
	for name in pairs(left) do
		if not right[name] then return false end
	end
	for name in pairs(right) do
		if not left[name] then return false end
	end
	return true
end

local function refresh_snapshot()
	local players = core.get_connected_players()
	local count = 0
	for index = 1, #players do
		local player = players[index]
		local pos = player:get_pos()
		if pos then
			count = count + 1
			local row = player_snapshot[count]
			if not row then
				row = {}
				player_snapshot[count] = row
			end
			row.name = player:get_player_name()
			row.x, row.y, row.z = pos.x, pos.y, pos.z
		end
	end
	player_count = count
end

core.register_entity(ENTITY_NAME, {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		visual = "sprite",
		visual_size = {x = 0, y = 0},
		textures = {"grug_mobs_blank.png"},
		use_texture_alpha = true,
		selectionbox = {0, 0, 0, 0, 0, 0},
		static_save = false,
		nametag = "",
		nametag_color = "#ffffff",
	},

	on_activate = function(self)
		self._grug_observers = {}
		self.object:set_observers({})
	end,
})

local function forget_carrier(carrier, row)
	if not carrier then return end
	managed_carriers[carrier] = nil
	if row and carrier_by_parent[row.parent] == carrier then
		carrier_by_parent[row.parent] = nil
	end
end

local function update_observers(carrier, parent, owner_name)
	local entity = carrier:get_luaentity()
	if not entity or entity.name ~= ENTITY_NAME then return false end
	local pos = parent:get_pos()
	if not pos then return false end
	local previous = entity._grug_observers or {}
	local observers = {}
	for index = 1, player_count do
		local player = player_snapshot[index]
		local name = player.name
		if name ~= owner_name then
			local dx = pos.x - player.x
			local dy = pos.y - player.y
			local dz = pos.z - player.z
			local d2 = dx * dx + dy * dy + dz * dz
			if d2 < SHOW_D2 or (d2 <= HIDE_D2 and previous[name]) then
				observers[name] = true
			end
		end
	end
	if same_set(previous, observers) then return false end
	entity._grug_observers = observers
	carrier:set_observers(observers)
	return true
end

local function manage_carriers()
	for carrier, row in pairs(managed_carriers) do
		local parent = row.parent
		if not object_valid(carrier) then
			forget_carrier(carrier, row)
		elseif not object_valid(parent) or carrier:get_attach() ~= parent then
			forget_carrier(carrier, row)
			carrier:remove()
		else
			update_observers(carrier, parent, row.owner_name)
		end
	end
end

core.register_globalstep(function(dtime)
	snapshot_elapsed = snapshot_elapsed + dtime
	if snapshot_elapsed < SNAPSHOT_INTERVAL then return end
	snapshot_elapsed = snapshot_elapsed % SNAPSHOT_INTERVAL
	refresh_snapshot()
	manage_carriers()
end)

function grug_core.create_tag_carrier(parent, owner_name)
	if not object_valid(parent) then return nil end
	local existing = carrier_by_parent[parent]
	if object_valid(existing) then
		local row = managed_carriers[existing]
		if row and owner_name ~= nil then row.owner_name = owner_name end
		return existing
	end
	local pos = parent:get_pos()
	if not pos then return nil end
	local carrier = core.add_entity(pos, ENTITY_NAME)
	if not carrier then return nil end
	local properties = parent:get_properties() or {}
	carrier:set_properties({
		selectionbox = properties.selectionbox or properties.collisionbox or
			{0, 0, 0, 0, 0, 0},
	})
	carrier:set_attach(parent, "", {x = 0, y = 0, z = 0},
		{x = 0, y = 0, z = 0})
	managed_carriers[carrier] = {parent = parent, owner_name = owner_name}
	carrier_by_parent[parent] = carrier
	return carrier
end

function grug_core.remove_tag_carrier(carrier)
	if not carrier then return end
	if object_valid(carrier) then
		forget_carrier(carrier, managed_carriers[carrier])
		carrier:remove()
	else
		forget_carrier(carrier, managed_carriers[carrier])
	end
end

function grug_core.set_tag_carrier_text(carrier, text)
	if not object_valid(carrier) then return false end
	local entity = carrier:get_luaentity()
	if not entity or entity.name ~= ENTITY_NAME then return false end
	text = type(text) == "string" and text or ""
	if entity._grug_text == text then return false end
	entity._grug_text = text
	carrier:set_properties({nametag = text, nametag_color = "#ffffff"})
	return true
end

function grug_core.nearest_tag_player_d2(pos)
	if not pos then return nil end
	local best
	for index = 1, player_count do
		local player = player_snapshot[index]
		local dx = pos.x - player.x
		local dy = pos.y - player.y
		local dz = pos.z - player.z
		local d2 = dx * dx + dy * dy + dz * dz
		if not best or d2 < best then best = d2 end
	end
	return best
end

function grug_core.is_tag_carrier(entity)
	return type(entity) == "table" and entity.name == ENTITY_NAME
end

-- Test seam: production refreshes only through the throttled globalstep.
grug_core.refresh_tag_player_snapshot = refresh_snapshot
grug_core.manage_tag_carriers = manage_carriers
