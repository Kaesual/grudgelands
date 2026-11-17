-- Per-viewer nametags (combat_stats.md section 6).
--
-- Object nametag properties are global. A transparent child entity gives the
-- text its own managed observer set, so each connected player gets an
-- independent 25/30-node hysteresis state while the parent stays unchanged.
--
-- Friend and foe (Round 72, round72-plan.md §2.8): a faction unit (a player,
-- guard, captain, King, General or settlement NPC) is green for its own side
-- and red for the other, lighter for an NPC that never fights. One colour is
-- one object, so a unit has up to two carriers: the one its callers hold
-- serves its own side and every viewer without a faction, and a second one
-- serves the other side. That second carrier exists only while a viewer of
-- the other side is within tag range; the same pass makes and removes it.

local ENTITY_NAME = "grug_core:tag_carrier"
local HP_ENTITY_NAME = "grug_core:injured_hp_bar"
local SHOW_D2 = 25 * 25
local HIDE_D2 = 30 * 30
local SNAPSHOT_INTERVAL = 1
-- The carrier pass is spread over this many steps of each second (Round 30,
-- perf review #10): every carrier belongs to one slot and is still visited
-- once per second, but no single server step carries all of them.
local SLOTS = 8
local SLOT_INTERVAL = SNAPSHOT_INTERVAL / SLOTS
-- The player snapshot is bucketed by CELL x CELL node columns (Round 81,
-- audit C1-04/X4-03): a carrier tests only the players of its own and the
-- eight neighbouring cells. CELL is at least the hide distance (30), so
-- every viewer in range is among them.
local CELL = 32
local CELL_ROW = 65536 -- cell key = cell x * CELL_ROW + cell z
local floor = math.floor

local CATEGORY_DEFAULTS = {
	aggressive = {foreground = "#ff4b4b", background = "#00000040"},
	neutral = {foreground = "#ffd447", background = "#00000040"},
	guard = {foreground = "#b76cff", background = "#00000040"},
	npc = {foreground = "#d8c5ff", background = "#00000040"},
	player = {foreground = "#ffffff", background = "#00000040"},
	critter = {foreground = "#ffffff", background = "#00000040"},
	-- Round 72: faction units by the viewer's side; npc_* never fight.
	friend = {foreground = "#4bdc4b", background = "#00000040"},
	foe = {foreground = "#ff4b4b", background = "#00000040"},
	npc_friend = {foreground = "#b9f5b0", background = "#00000040"},
	npc_foe = {foreground = "#ffb3b3", background = "#00000040"},
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
-- cell key -> {n = count, [i] = snapshot index}; the cells filled by the
-- last refresh, and the ones before it (emptied first, dropped if unused).
local cells, cells_used, cells_before = {}, {}, {}
local cells_used_count = 0
-- A player's faction, read from player meta once per SNAPSHOT_INTERVAL
-- through the join slots (below) instead of on every snapshot refresh
-- (Round 81, audit C1-04); false for none. Weak keys: a player who leaves
-- drops out, a rejoin is a new object and reads afresh.
local faction_of = setmetatable({}, {__mode = "k"})
local slot_elapsed = 0
local visibility_callbacks = {}
-- callback(parent, observers, removed): membership is borrowed, read-only.
-- Called on the carrier's visibility tick whenever somebody observes it or its
-- observer set just changed (so once with the empty set after the last
-- observer left), and with removed = true when the carrier goes, so consumers
-- can refresh state without scans. An unobserved carrier whose set stays
-- empty is skipped.
function grug_core.register_tag_visibility(callback)
	visibility_callbacks[#visibility_callbacks + 1] = callback
end
local managed_carriers = {}
local carrier_by_parent = {}
-- slot -> {carrier = row}: the carriers visited on that step of the second.
local carrier_slots = {}
for slot = 1, SLOTS do carrier_slots[slot] = {} end
local last_slot = 0 -- the slot the newest carrier joined (round robin)
local current_slot = 0

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

local EMPTY = {}

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

-- The colour a unit gets while its faction is unknown, and for good when it
-- has none: a mob without a faction keeps these (§2.8).
local function category_for(parent)
	if parent:is_player() then return "player" end
	local entity = parent:get_luaentity()
	if not entity then return "npc" end
	local name = entity.name or ""
	if name == "grug_mobs:guard_accord" or name == "grug_mobs:guard_throng"
			or name:match("^grug_mobs:royal_guard_")
			-- Round 31 PvP garrisons: a camp captain, a General's bodyguard;
			-- Round 36 a war camp's commander.
			or name:match("^grug_mobs:captain_")
			or name:match("^grug_mobs:commander_")
			or name:match("^grug_mobs:bodyguard_") then
		return "guard"
	end
	if entity._grug_disposition == "aggressive"
			or entity._grug_disposition == "neutral"
			or entity._grug_disposition == "critter" then
		return entity._grug_disposition
	end
	return "npc"
end

-- A player's faction id or nil. grug_factions resolves it, the stub pattern
-- of grug_core.get_player_faction: grug_core never depends on a player mod.
function grug_core.get_player_object_faction(player)
	return nil
end

local function read_faction(player)
	local faction = grug_core.get_player_object_faction(player) or false
	faction_of[player] = faction
	return faction
end

-- The faction the tags use: the one read on the player's last slot visit
-- (at most SNAPSHOT_INTERVAL old), read at once the first time.
local function player_faction(player)
	local faction = faction_of[player]
	if faction == nil then faction = read_faction(player) end
	return faction or nil
end
grug_core.register_player_pass(SNAPSHOT_INTERVAL, read_faction)

-- Settlement key -> faction id, built once on first use from the socket
-- registry and the start roster (both final after load).
local settlement_factions
local function settlement_faction(key)
	if type(key) ~= "string" then return nil end
	if not settlement_factions then
		local identities = grug_core.start_identities and grug_core.start_identities()
		if not identities or #identities == 0 then return nil end
		local by_race = {}
		for _, identity in ipairs(identities) do
			by_race[identity.race_id] = identity.faction_id
		end
		settlement_factions = {}
		for _, record in ipairs(grug_core.settlement_socket_settlements and
				grug_core.settlement_socket_settlements() or {}) do
			settlement_factions[record.key] = by_race[record.race_id]
		end
	end
	return settlement_factions[key]
end

-- Fills row.faction and row.kind: "combat" (green and red), "npc" (light
-- green and light red) or nil (the category colour for every viewer).
-- A player is read on every visit (the faction is chosen after joining;
-- the value of its last slot visit, player_faction); a mob keeps its
-- faction once known. A fighting mob carries _grug_faction
-- (grug_mobs sets it on activation, before its carrier exists); a peaceful
-- resident (category npc), a capital's display included, belongs to its
-- settlement's faction (user ruling 2026-11-08: every NPC and guard is friend
-- or foe, no violet or lavender).
local function resolve_unit(row)
	if row.is_player then
		local faction = player_faction(row.parent)
		row.faction, row.kind = faction, faction and "combat" or nil
		return
	end
	if row.faction then return end
	local entity = row.parent:get_luaentity()
	if not entity then return end
	if entity._grug_faction then
		row.faction, row.kind = entity._grug_faction, "combat"
	elseif row.category == "npc" then
		local faction = settlement_faction(entity._grug_start)
		if faction then row.faction, row.kind = faction, "npc" end
	end
end

local function own_category(row)
	if row.kind == "combat" then return "friend" end
	if row.kind == "npc" then return "npc_friend" end
	return row.category
end

local function foe_category(row)
	return row.kind == "npc" and "npc_foe" or "foe"
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
		row.hp_height = nil
	end
end

-- Bar size in WORLD units for every mob. The bar is a sprite, and Irrlicht
-- billboards build their vertices in world space from their own Size, so
-- the parent's visual_size never reaches them: dividing by it (the old
-- ordinary-mob path) drew a fox's bar at a tenth of its size and a serpent's
-- 2.7 nodes wide. Only the attachment OFFSET lives in the parent's scaled
-- frame (empty-bone translation inherits the scene-node scale), so the
-- anchor height alone is divided by the parent's y scale.
local BAR_WIDTH = 0.8
local BAR_HEIGHT = 0.1
-- Below the nametag, whose engine offset is selection-box max Y + 0.3 nodes.
local BAR_LIFT = 0.12

local function bar_geometry(properties, presentation)
	local box = properties.selectionbox or properties.collisionbox or
		{0, 0, 0, 0, 1, 0}
	local scale = properties.visual_size or {x = 1, y = 1}
	local sy = math.abs(scale.y or 1)
	if sy < 0.01 then sy = 1 end
	if presentation then
		local anchor_y = tonumber(presentation.anchor_y)
		local width = tonumber(presentation.width)
		local height = tonumber(presentation.height)
		if anchor_y and width and height and anchor_y >= 0 and width > 0
				and height > 0 then
			return anchor_y * 10 / sy, width, height
		end
	end
	return ((box[5] or 1) + BAR_LIFT) * 10 / sy, BAR_WIDTH, BAR_HEIGHT
end
-- Test seam (tools/r28_a3/portable_test.lua): the pure size arithmetic.
grug_core.hp_bar_geometry = bar_geometry

local function bar_height_and_scale(parent)
	local properties = parent:get_properties() or {}
	local entity = parent:get_luaentity()
	local registered = entity and core.registered_entities[entity.name]
	local presentation = entity and entity._grug_hp_bar_presentation
		or registered and registered._grug_hp_bar_presentation
	return bar_geometry(properties, presentation)
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
	row.hp_scale_x, row.hp_scale_y, row.hp_height = sx, sy, height
	return bar
end

local function refresh_hp_bar(row, observers)
	if not HP_BARS_ENABLED or row.is_player or (row.kind ~= "combat"
			and row.category ~= "aggressive" and row.category ~= "neutral"
			and row.category ~= "guard") then
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
		if object_valid(row.hp_bar) and not same_set(row.hp_observers or EMPTY, observers) then
			row.hp_bar:set_observers(observers)
			row.hp_observers = observers
		end
		return
	end
	local percent = math.max(1, math.min(99,
		math.floor(hp * 100 / hp_max + 0.5)))
	-- A tier promotion that rescales the parent after the bar exists moves
	-- the bar through grug_core.sync_tag_carrier_box (follow_bar_geometry).
	local bar = ensure_hp_bar(row)
	if not bar then return end
	if row.hp_percent ~= percent then
		row.hp_percent = percent
		bar:set_properties({textures = {hp_texture(percent)}})
	end
	if not same_set(row.hp_observers or EMPTY, observers) then
		bar:set_observers(observers)
		row.hp_observers = observers
	end
end

-- The bar of a parent rescaled after the bar exists (a tier promotion):
-- its box top and its visual_size both move the anchor.
local function follow_bar_geometry(row)
	local bar = row.hp_bar
	if not object_valid(bar) then return end
	local height, sx, sy = bar_height_and_scale(row.parent)
	if row.hp_scale_x ~= sx or row.hp_scale_y ~= sy
			or row.hp_height ~= height then
		bar:set_properties({visual_size = {x = sx, y = sy}})
		bar:set_attach(row.parent, "", {x = 0, y = height, z = 0},
			{x = 0, y = 0, z = 0})
		row.hp_scale_x, row.hp_scale_y, row.hp_height = sx, sy, height
	end
end

-- Positions every slot step (the mobs' nearest_tag_player_d2 reads them
-- too); the viewer's side (Round 72) from player_faction, or read afresh
-- for every player when `read_factions` is set (the test seam).
local function refresh_snapshot(read_factions)
	local players = core.get_connected_players()
	cells_used, cells_before = cells_before, cells_used
	local before_count = cells_used_count
	for index = 1, before_count do cells[cells_before[index]].n = 0 end
	local count, used = 0, 0
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
			if read_factions then
				row.faction = read_faction(player) or nil
			else
				row.faction = player_faction(player)
			end
			local key = floor(pos.x / CELL) * CELL_ROW + floor(pos.z / CELL)
			local cell = cells[key]
			if not cell then
				cell = {n = 0}
				cells[key] = cell
			end
			if cell.n == 0 then
				used = used + 1
				cells_used[used] = key
			end
			cell.n = cell.n + 1
			cell[cell.n] = count
		end
	end
	for index = 1, before_count do
		local key = cells_before[index]
		if cells[key].n == 0 then cells[key] = nil end
	end
	cells_used_count = used
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

-- The engine draws a nametag at its OWN object's selection-box max Y + 0.3, so
-- the carrier wears a copy of its parent's box.
local function copy_parent_box(carrier, parent)
	local properties = parent:get_properties() or {}
	carrier:set_properties({
		selectionbox = properties.selectionbox or properties.collisionbox or
			{0, 0, 0, 0, 0, 0},
	})
end

-- Text and colour of one carrier; a write only when either changed.
local function style_carrier(carrier, text, category)
	local entity = carrier:get_luaentity()
	if not entity or entity.name ~= ENTITY_NAME then return false end
	if entity._grug_text == text and entity._grug_category == category then
		return false
	end
	entity._grug_text, entity._grug_category = text, category
	local colors = CATEGORY_COLORS[category] or CATEGORY_COLORS.npc
	carrier:set_properties({nametag = text,
		nametag_color = colors.foreground,
		nametag_bgcolor = colors.background})
	return true
end

local function remove_foe_carrier(row)
	if row and row.foe then
		if object_valid(row.foe) then row.foe:remove() end
		row.foe = nil
	end
end

local function forget_carrier(carrier, row)
	if not carrier then return end
	if row then
		for _, callback in ipairs(visibility_callbacks) do callback(row.parent, {}, true) end
	end
	managed_carriers[carrier] = nil
	remove_hp_bar(row)
	remove_foe_carrier(row)
	if row then carrier_slots[row.slot][carrier] = nil end
	if row and carrier_by_parent[row.parent] == carrier then
		carrier_by_parent[row.parent] = nil
	end
end

-- A new carrier entity on `parent`, attached at its origin, or nil.
local function spawn_carrier(parent)
	local pos = parent:get_pos()
	local carrier = pos and core.add_entity(pos, ENTITY_NAME)
	if not carrier then return nil end
	copy_parent_box(carrier, parent)
	carrier:set_attach(parent, "", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
	return carrier
end

-- A carrier still serving `parent`: valid and attached to it.
local function carrier_holds(carrier, parent)
	return object_valid(carrier) and carrier:get_attach() == parent
end

-- The other side's carrier, made when its first viewer comes in range.
local function ensure_foe_carrier(row, text)
	if carrier_holds(row.foe, row.parent) then return row.foe end
	remove_foe_carrier(row)
	local foe = spawn_carrier(row.parent)
	if not foe then return nil end
	style_carrier(foe, text or "", foe_category(row))
	row.foe = foe
	return foe
end

-- Round 78 (ruling 7): a player's carrier that is gone, invalid or detached
-- is replaced in its row, which keeps its slot, owner and text. The engine
-- drops a non-static entity whose map block is not in memory at an active
-- block pass (serverenvironment.cpp deactivateFarObjects: `still_active` for
-- !isStaticAllowed is getBlockNoCreateNoEx != nullptr), and an attached child
-- moves with its parent, so a player held where no block is loaded (the
-- character waiting point at y = 31000, grug_classes selection.lua) loses the
-- carrier for good. A replacement waits while the parent's own block is not
-- in memory (get_node_or_nil is nil exactly then, map.cpp Map::getNode), where
-- it would go the same way. Returns the replacement, or nil while it waits.
local function replace_carrier(old, row)
	local parent = row.parent
	local pos = parent:get_pos()
	if not pos or not core.get_node_or_nil(pos) then return nil end
	local carrier = spawn_carrier(parent)
	if not carrier then return nil end
	if object_valid(old) then old:remove() end
	managed_carriers[old] = nil
	carrier_slots[row.slot][old] = nil
	managed_carriers[carrier] = row
	carrier_slots[row.slot][carrier] = row
	carrier_by_parent[parent] = carrier
	-- The new carrier starts without viewers: rebuild the combined set on
	-- its first visit even when neither side's set changes then.
	row.both = nil
	style_carrier(carrier, row.text or "", own_category(row))
	return carrier
end

-- The viewers in range of the carrier being visited, reused by every visit:
-- range_names[i] and whether it belongs to the other side, range_foe[i].
local range_names, range_foe = {}, {}

local function set_size(set)
	local n = 0
	for _ in pairs(set) do n = n + 1 end
	return n
end

-- One walk over the snapshot cells around the carrier splits the viewers in
-- range by side: the held carrier gets its own side and every viewer without
-- a faction, the foe carrier the other side. A set is rebuilt only when it
-- changed (Round 81, audit X4-03). Returns both sides together (borrowed,
-- read-only) and whether either set changed.
local function update_observers(carrier, row)
	local entity = carrier:get_luaentity()
	if not entity or entity.name ~= ENTITY_NAME then return EMPTY, false end
	local pos = row.parent:get_pos()
	if not pos then return EMPTY, false end
	local owner_name, faction = row.owner_name, row.faction
	local previous = entity._grug_observers or EMPTY
	local foe_entity = object_valid(row.foe) and row.foe:get_luaentity()
	local previous_foe = foe_entity and foe_entity._grug_observers or EMPTY
	local n, own_count, own_same, foe_count = 0, 0, true, 0
	local cx, cz = floor(pos.x / CELL), floor(pos.z / CELL)
	for gx = cx - 1, cx + 1 do
		for gz = cz - 1, cz + 1 do
			local cell = cells[gx * CELL_ROW + gz]
			for i = 1, cell and cell.n or 0 do
				local player = player_snapshot[cell[i]]
				local name = player.name
				if name ~= owner_name then
					local dx = pos.x - player.x
					local dy = pos.y - player.y
					local dz = pos.z - player.z
					local d2 = dx * dx + dy * dy + dz * dz
					if d2 < SHOW_D2 or (d2 <= HIDE_D2 and
							(previous[name] or previous_foe[name])) then
						local side = player.faction
						local foe = faction and side and side ~= faction or false
						n = n + 1
						range_names[n], range_foe[n] = name, foe
						if foe then
							foe_count = foe_count + 1
						else
							own_count = own_count + 1
							if not previous[name] then own_same = false end
						end
					end
				end
			end
		end
	end
	local changed = false
	local observers = previous
	if not own_same or own_count ~= set_size(previous) then
		observers = {}
		for i = 1, n do
			if not range_foe[i] then observers[range_names[i]] = true end
		end
		entity._grug_observers = observers
		carrier:set_observers(observers)
		changed = true
	end
	if foe_count == 0 then
		if row.foe then
			changed = changed or next(previous_foe) ~= nil
			remove_foe_carrier(row)
		end
		row.both = nil
		return observers, changed
	end
	local foe = ensure_foe_carrier(row, row.text or entity._grug_text)
	foe_entity = foe and foe:get_luaentity()
	local foes
	if foe_entity then
		local sent = foe_entity._grug_observers or EMPTY
		local same = foe_count == set_size(sent)
		for i = 1, n do
			if same and range_foe[i] and not sent[range_names[i]] then same = false end
		end
		if not same then
			foes = {}
			for i = 1, n do
				if range_foe[i] then foes[range_names[i]] = true end
			end
			foe_entity._grug_observers = foes
			foe:set_observers(foes)
			changed = true
		end
	end
	-- Both sides together, rebuilt when a side changed (or without a foe
	-- carrier to hold the other side's set).
	if changed or not row.both or not foe_entity then
		local both = {}
		for i = 1, n do both[range_names[i]] = true end
		row.both = both
	end
	return row.both, changed
end

-- Returns true for a player's carrier that is lost while the player is
-- still there: the caller replaces it after its walk (replace_carrier adds a
-- key to the table being walked).
local function manage_carrier(carrier, row)
	local parent = row.parent
	if row.is_player and object_valid(parent)
			and not carrier_holds(carrier, parent) then
		return true
	elseif not object_valid(carrier) then
		forget_carrier(carrier, row)
	elseif not object_valid(parent) or carrier:get_attach() ~= parent then
		forget_carrier(carrier, row)
		carrier:remove()
	else
		resolve_unit(row)
		local entity = carrier:get_luaentity()
		local category = own_category(row)
		if entity and entity._grug_category ~= category then
			style_carrier(carrier, entity._grug_text or "", category)
		end
		local observers, changed = update_observers(carrier, row)
		refresh_hp_bar(row, observers)
		if changed or next(observers) ~= nil then
			for _, callback in ipairs(visibility_callbacks) do callback(parent, observers, false) end
		end
	end
end

-- One slot's carriers, or every carrier when `slot` is nil. A lost player
-- carrier is replaced after the walk and visited at once, so its viewers
-- get it on this pass; one whose replacement waits is retried next second.
local function manage_carriers(slot)
	local lost
	for carrier, row in pairs(slot and carrier_slots[slot] or managed_carriers) do
		if manage_carrier(carrier, row) then
			lost = lost or {}
			lost[#lost + 1] = carrier
		end
	end
	if not lost then return end
	for index = 1, #lost do
		local row = managed_carriers[lost[index]]
		local carrier = row and replace_carrier(lost[index], row)
		if carrier then manage_carrier(carrier, row) end
	end
end

-- One slot per elapsed 1/8 s: a long (lagging) step handles every slot it
-- covered, at most all eight, so the cycle stays about one second.
core.register_globalstep(function(dtime)
	slot_elapsed = slot_elapsed + dtime
	if slot_elapsed < SLOT_INTERVAL then return end
	local due = math.min(SLOTS, math.floor(slot_elapsed / SLOT_INTERVAL))
	slot_elapsed = slot_elapsed - due * SLOT_INTERVAL
	if slot_elapsed >= SLOT_INTERVAL then slot_elapsed = slot_elapsed % SLOT_INTERVAL end
	refresh_snapshot(false)
	for _ = 1, due do
		current_slot = current_slot % SLOTS + 1
		manage_carriers(current_slot)
	end
end)

-- A parent rescaled after its carrier exists (a tier promotion,
-- grug_mobs levels.lua) re-copies its box so the tag rides on the new top,
-- and its HP bar moves to the new anchor (Round 81, audit C1-04: the bar no
-- longer reads the parent's properties on every visit).
function grug_core.sync_tag_carrier_box(parent)
	local carrier = parent and carrier_by_parent[parent]
	if not object_valid(carrier) or not object_valid(parent) then
		return false
	end
	copy_parent_box(carrier, parent)
	local row = managed_carriers[carrier]
	if row and object_valid(row.foe) then copy_parent_box(row.foe, parent) end
	if row then follow_bar_geometry(row) end
	return true
end

-- The parent's carrier: the one it has, a replacement for one that is gone,
-- invalid or detached (Round 78), or a new one. A replacement that has to
-- wait for the parent's block returns the row's old handle: it is not valid,
-- but a text set on it is kept for the replacement.
function grug_core.create_tag_carrier(parent, owner_name)
	if not object_valid(parent) then return nil end
	local existing = carrier_by_parent[parent]
	local existing_row = existing and managed_carriers[existing]
	if existing_row then
		if owner_name ~= nil then existing_row.owner_name = owner_name end
		if carrier_holds(existing, parent) then return existing end
		return replace_carrier(existing, existing_row) or existing
	end
	local carrier = spawn_carrier(parent)
	if not carrier then return nil end
	last_slot = last_slot % SLOTS + 1
	local row = {parent = parent, owner_name = owner_name,
		category = category_for(parent), is_player = parent:is_player(),
		slot = last_slot}
	resolve_unit(row)
	managed_carriers[carrier] = row
	carrier_slots[last_slot][carrier] = row
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

-- The text reaches both sides' carriers; the colour is each carrier's own.
function grug_core.set_tag_carrier_text(carrier, text)
	if not carrier then return false end
	text = type(text) == "string" and text or ""
	local row = managed_carriers[carrier]
	-- The row keeps the text for a carrier that has to be replaced.
	if row then row.text = text end
	if not object_valid(carrier) then return false end
	local changed = style_carrier(carrier, text,
		row and own_category(row) or "npc")
	if row and object_valid(row.foe) then
		style_carrier(row.foe, text, foe_category(row))
	end
	return changed
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

-- Test seam: production refreshes only through the throttled globalstep,
-- one slot per step; the seams refresh the snapshot with every player's
-- faction read afresh and run a full pass over every carrier.
grug_core.refresh_tag_player_snapshot = function() refresh_snapshot(true) end
grug_core.manage_tag_carriers = function() manage_carriers(nil) end
