-- Per-viewer nametags (combat_stats.md section 6).
--
-- Object nametag properties are global. A transparent child entity gives the
-- text its own managed observer set, so each connected player gets an
-- independent 25/30-node hysteresis state while the parent stays unchanged.

local ENTITY_NAME = "grug_core:tag_carrier"
local HP_ENTITY_NAME = "grug_core:injured_hp_bar"
local SHOW_D2 = 25 * 25
local HIDE_D2 = 30 * 30
local SNAPSHOT_INTERVAL = 1

local CATEGORY_DEFAULTS = {
	aggressive = {foreground = "#ff4b4b", background = "#00000040"},
	neutral = {foreground = "#ffd447", background = "#00000040"},
	guard = {foreground = "#b76cff", background = "#00000040"},
	npc = {foreground = "#d8c5ff", background = "#00000040"},
	player = {foreground = "#ffffff", background = "#00000040"},
	critter = {foreground = "#ffffff", background = "#00000040"},
}

local function setting_color(name, fallback)
	local value = core.settings:get(name)
	return value and core.colorspec_to_colorstring(value) or fallback
end

local CATEGORY_COLORS = {}
for category, defaults in pairs(CATEGORY_DEFAULTS) do
	local prefix = "grug_nametag_" .. category .. "_"
	CATEGORY_COLORS[category] = {
		foreground = setting_color(prefix .. "foreground", defaults.foreground),
		background = setting_color(prefix .. "background", defaults.background),
	}
end

local HP_BARS_ENABLED = core.settings:get_bool("grug_injured_mob_hp_bars", true)

local player_snapshot = {}
local player_count = 0
local snapshot_elapsed = 0
local visibility_callbacks = {}
-- callback(parent, observers, removed): membership is borrowed, read-only.
-- Called every existing visibility tick so consumers can refresh state without scans.
function grug_core.register_tag_visibility(callback)
	visibility_callbacks[#visibility_callbacks + 1] = callback
end
local managed_carriers = {}
local carrier_by_parent = {}

function grug_core.register_hp_bar_presentation(entity_name, definition)
	local registered = type(entity_name) == "string"
		and core.registered_entities[entity_name]
	if not registered or type(definition) ~= "table" then return false end
	local anchor_y = tonumber(definition.anchor_y)
	local width = tonumber(definition.width)
	local height = tonumber(definition.height)
	if not anchor_y or not width or not height or anchor_y < 0
			or width <= 0 or height <= 0 then
		return false
	end
	registered._grug_hp_bar_presentation = {
		anchor_y = anchor_y, width = width, height = height,
	}
	return true
end

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

local function category_for(parent)
	if parent:is_player() then return "player" end
	local entity = parent:get_luaentity()
	if not entity then return "npc" end
	local name = entity.name or ""
	if name == "grug_mobs:guard_accord" or name == "grug_mobs:guard_throng"
			or name == "grug_mobs:land_guard"
			or name:match("^grug_mobs:royal_guard_") then
		return "guard"
	end
	if entity._grug_disposition == "aggressive"
			or entity._grug_disposition == "neutral"
			or entity._grug_disposition == "critter" then
		return entity._grug_disposition
	end
	return "npc"
end

local function hp_texture(percent)
	local width = math.max(1, math.floor(percent * 62 / 100 + 0.5))
	return "[fill:64x8:#101810e0^[fill:" .. width ..
		"x6:1,1:#39d353ff"
end

core.register_entity(HP_ENTITY_NAME, {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		visual = "sprite",
		visual_size = {x = 0.8, y = 0.1},
		textures = {hp_texture(100)},
		use_texture_alpha = true,
		selectionbox = {0, 0, 0, 0, 0, 0},
		static_save = false,
		shaded = false,
		show_on_minimap = false,
	},

	on_activate = function(self)
		self._grug_observers = {}
		self.object:set_observers({})
	end,
})

local function remove_hp_bar(row)
	local bar = row and row.hp_bar
	if object_valid(bar) then bar:remove() end
	if row then
		row.hp_bar = nil
		row.hp_percent = nil
		row.hp_observers = nil
		row.hp_scale_x = nil
		row.hp_scale_y = nil
	end
end

local function bar_height_and_scale(parent)
	local properties = parent:get_properties() or {}
	local box = properties.selectionbox or properties.collisionbox or
		{0, 0, 0, 0, 1, 0}
	local scale = properties.visual_size or {x = 1, y = 1}
	local sx = math.abs(scale.x or 1)
	local sy = math.abs(scale.y or 1)
	if sx < 0.01 then sx = 1 end
	if sy < 0.01 then sy = 1 end
	local entity = parent:get_luaentity()
	local registered = entity and core.registered_entities[entity.name]
	local presentation = entity and entity._grug_hp_bar_presentation
		or registered and registered._grug_hp_bar_presentation
	if presentation then
		local anchor_y = tonumber(presentation.anchor_y)
		local width = tonumber(presentation.width)
		local height = tonumber(presentation.height)
		if anchor_y and width and height and anchor_y >= 0 and width > 0
				and height > 0 then
			-- Empty-bone attachment translation inherits the parent's scene-node
			-- scale. Irrlicht billboards build their vertices in world space from
			-- their own Size, so their dimensions do not inherit that scale.
			return anchor_y * 10 / sy, width, height
		end
	end
	-- Attachment coordinates are in tenths of a node and inherit the parent's
	-- scene-node scale. Divide both offset and sprite size to keep one stable
	-- world-space bar from rats through dragons. It sits below the nametag,
	-- whose engine offset is selection-box max Y + 0.3 nodes.
	return ((box[5] or 1) + 0.12) * 10 / sy, 0.8 / sx, 0.1 / sy
end

local function ensure_hp_bar(row)
	if object_valid(row.hp_bar) then return row.hp_bar end
	local parent = row.parent
	local pos = parent:get_pos()
	if not pos then return nil end
	local bar = core.add_entity(pos, HP_ENTITY_NAME)
	if not bar then return nil end
	local height, sx, sy = bar_height_and_scale(parent)
	bar:set_properties({visual_size = {x = sx, y = sy}})
	bar:set_attach(parent, "", {x = 0, y = height, z = 0},
		{x = 0, y = 0, z = 0})
	row.hp_bar = bar
	row.hp_scale_x, row.hp_scale_y = sx, sy
	return bar
end

local function refresh_hp_bar(row, observers)
	if not HP_BARS_ENABLED or (row.category ~= "aggressive"
			and row.category ~= "neutral" and row.category ~= "guard") then
		remove_hp_bar(row)
		return
	end
	local entity = row.parent:get_luaentity()
	local hp = entity and tonumber(entity.health)
	local hp_max = entity and tonumber(entity.hp_max)
	if not hp_max or hp_max <= 0 then
		local properties = row.parent:get_properties() or {}
		hp_max = tonumber(properties.hp_max)
	end
	if not hp or not hp_max or hp <= 0 or hp >= hp_max then
		remove_hp_bar(row)
		return
	end
	-- Defer creation and texture work until somebody can actually see it.
	if next(observers) == nil then
		if object_valid(row.hp_bar) and not same_set(row.hp_observers or {}, observers) then
			row.hp_bar:set_observers(observers)
			row.hp_observers = observers
		end
		return
	end
	local percent = math.max(1, math.min(99,
		math.floor(hp * 100 / hp_max + 0.5)))
	local bar = ensure_hp_bar(row)
	if not bar then return end
	local height, sx, sy = bar_height_and_scale(row.parent)
	if row.hp_scale_x ~= sx or row.hp_scale_y ~= sy then
		bar:set_properties({visual_size = {x = sx, y = sy}})
		bar:set_attach(row.parent, "", {x = 0, y = height, z = 0},
			{x = 0, y = 0, z = 0})
		row.hp_scale_x, row.hp_scale_y = sx, sy
	end
	if row.hp_percent ~= percent then
		row.hp_percent = percent
		bar:set_properties({textures = {hp_texture(percent)}})
	end
	if not same_set(row.hp_observers or {}, observers) then
		bar:set_observers(observers)
		row.hp_observers = observers
	end
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
	if row then
		for _, callback in ipairs(visibility_callbacks) do callback(row.parent, {}, true) end
	end
	managed_carriers[carrier] = nil
	remove_hp_bar(row)
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
			local observers = carrier:get_luaentity()._grug_observers or {}
			refresh_hp_bar(row, observers)
			for _, callback in ipairs(visibility_callbacks) do callback(parent, observers, false) end
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
	managed_carriers[carrier] = {parent = parent, owner_name = owner_name,
		category = category_for(parent)}
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
	local row = managed_carriers[carrier]
	local colors = CATEGORY_COLORS[row and row.category or "npc"]
	carrier:set_properties({nametag = text,
		nametag_color = colors.foreground,
		nametag_bgcolor = colors.background})
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
