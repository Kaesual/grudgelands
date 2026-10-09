-- Round 45 lane ST portable test (LuaJIT): stations, cooking and alchemy
-- (round45-plan.md §4.5; ui-crafting-rework-plan.md §2.27, §2.28, §2.30,
-- §2.31, §4.7).
--
--   luajit tools/r45_st/portable_test.lua [REPO]
--
-- Loads under one stub engine the REAL grug_brewing (init.lua, node.lua),
-- grug_jobs registry.lua, state.lua, jobs.lua, trainers.lua,
-- station_nodes.lua, workspaces.lua and automatic.lua, grug_cooking/init.lua,
-- grug_alchemy/recipes.lua, grug_mobs/start_npcs.lua (with the real
-- pvp_garrison.lua), grug_map/providers.lua and grug_repair/providers.lua.
-- Checks:
--   S  proximity stations: the forge, the four benches and the brewing stand
--      (lit or not) have no on_rightclick and no lists, open nothing, take
--      and give nothing; the furnace and the dual furnace keep their dialog;
--      the activation LBM names only the furnaces; a lit brewing stand goes
--      out at its node timer;
--   D  the dig refund: an old forge's crafting grid, an old brewing stand's
--      mixture, fuel and output lists and every saved workspace record come
--      out when a player-placed station is dug or blasted; an authored public
--      station stays undiggable and blast-proof;
--   C  Cooking at join: a character who does not know it learns it at T1
--      (existing characters at join, new ones at their arrival), quietly; a
--      player still creating a character stores nothing; known tiers and
--      crafts stay; no trainer teaches it;
--   T  the trainer mapping in each reader: grug_jobs.trainer_teaches and
--      open_trainer; start_npcs.lua at placement (an ordinary resident on
--      the Cooking socket, the tailor trainer unchanged) and at activation (a
--      saved Cooking trainer turns ordinary); the map's service markers; the
--      repair provider;
--   A  alchemy: every catalogue product is one Alchemy record at the brewing
--      stand, 2 s, giving XP, that makes the finished potion; a job makes
--      finished potions at the stand with Alchemy XP per potion and is
--      refused without a stand within 4 nodes;
--   M  the mixtures stay registered as inert items: no record makes or uses
--      one, no ingredient tier, no brewing adapter, no brewing lists.
-- Prints "R45 ST PORTABLE PASS checks=<n>" or the failures (exit 1).

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function read_file(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

------------------------------------------------------------------------------
-- Engine model.
------------------------------------------------------------------------------
local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = copy(v) end
	return setmetatable(out, getmetatable(value))
end
local function literal(value)
	local kind = type(value)
	if kind == "table" then
		local parts = {}
		for key, item in pairs(value) do
			parts[#parts + 1] = "[" .. literal(key) .. "]=" .. literal(item)
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif kind == "string" then
		return ("%q"):format(value)
	elseif kind == "number" then
		return ("%.17g"):format(value)
	end
	return tostring(value)
end

local clock = 1700000000
os.time = function() return math.floor(clock) end
local process_start = clock
local afters = {}
local function run_timers()
	local ran = true
	while ran do
		ran = false
		table.sort(afters, function(a, b) return a.at < b.at end)
		for index, entry in ipairs(afters) do
			if entry.at <= clock + 0.00001 then
				table.remove(afters, index)
				entry.fn()
				ran = true
				break
			end
		end
	end
end

local function pos_key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end
vector = {}
local vmeta = {__index = vector}
function vector.new(x, y, z)
	if type(x) == "table" then return setmetatable({x = x.x, y = x.y, z = x.z}, vmeta) end
	return setmetatable({x = x or 0, y = y or 0, z = z or 0}, vmeta)
end
function vector.offset(v, x, y, z) return vector.new(v.x + x, v.y + y, v.z + z) end
function vector.distance(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end
function vector.round(v)
	return vector.new(math.floor(v.x + 0.5), math.floor(v.y + 0.5), math.floor(v.z + 0.5))
end
function vector.equals(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end

-- Item stacks: name, count, wear and a metadata table.
local registered_items = {}
local Meta = {}
Meta.__index = Meta
local function new_meta() return setmetatable({fields = {}}, Meta) end
function Meta:get_int(key) return tonumber(self.fields[key]) or 0 end
function Meta:get_string(key) return self.fields[key] or "" end
function Meta:set_int(key, value)
	self.writes = (self.writes or 0) + 1
	self.fields[key] = value ~= 0 and tostring(value) or nil
end
function Meta:set_string(key, value)
	self.writes = (self.writes or 0) + 1
	self.fields[key] = value ~= "" and value or nil
end
function Meta:get_keys()
	local keys = {}
	for key in pairs(self.fields) do keys[#keys + 1] = key end
	return keys
end
function Meta:mark_as_private() end
function Meta:to_table() return {fields = copy(self.fields)} end

local Stack = {}
Stack.__index = Stack
function ItemStack(item)
	local self = setmetatable({meta = new_meta()}, Stack)
	if getmetatable(item) == Stack then
		self.name, self.count, self.wear = item.name, item.count, item.wear
		self.meta.fields = copy(item.meta.fields)
		return self
	end
	if type(item) == "table" then
		self.name, self.count, self.wear = item.name or "", item.count or 1, item.wear or 0
		return self
	end
	local name, count = tostring(item or ""):match("^(%S*)%s*(%d*)")
	self.name = name or ""
	self.count = self.name == "" and 0 or (tonumber(count) or 1)
	self.wear = 0
	return self
end
function Stack:get_name() return self.count > 0 and self.name or "" end
function Stack:get_count() return self.count end
function Stack:set_count(count) self.count = count if count <= 0 then self.name = "" end end
function Stack:is_empty() return self.count <= 0 or self.name == "" end
function Stack:get_wear() return self.wear end
function Stack:get_meta() return self.meta end
function Stack:get_stack_max()
	local def = registered_items[self.name]
	return def and def.stack_max or 99
end
function Stack:to_string()
	if self:is_empty() then return "" end
	return self.count == 1 and self.name or (self.name .. " " .. self.count)
end
function Stack:to_table() return {name = self.name, count = self.count} end
function Stack:take_item(n)
	n = math.min(n or 1, self.count)
	local taken = ItemStack(self)
	taken.count = n
	self:set_count(self.count - n)
	return taken
end
local function same_kind(a, b)
	return a.name == b.name and a.wear == b.wear and
		literal(a.meta.fields) == literal(b.meta.fields)
end
function Stack:add_item(other)
	other = ItemStack(other)
	if other:is_empty() then return ItemStack("") end
	if self:is_empty() then
		local take = math.min(other.count, other:get_stack_max())
		self.name, self.wear, self.count = other.name, other.wear, take
		self.meta.fields = copy(other.meta.fields)
		other:set_count(other.count - take)
		return other
	end
	if not same_kind(self, other) then return other end
	local take = math.min(other.count, self:get_stack_max() - self.count)
	self.count = self.count + take
	other:set_count(other.count - take)
	return other
end

local function new_inventory()
	local inv = {lists = {}}
	function inv:get_size(list) return self.lists[list] and #self.lists[list] or 0 end
	function inv:set_size(list, size)
		local old = self.lists[list] or {}
		local new = {}
		for i = 1, size do new[i] = old[i] or ItemStack("") end
		self.lists[list] = new
	end
	function inv:get_stack(list, i) return ItemStack((self.lists[list] or {})[i] or "") end
	function inv:set_stack(list, i, stack) self.lists[list][i] = ItemStack(stack) end
	function inv:get_list(list)
		if not self.lists[list] then return nil end
		local out = {}
		for i, stack in ipairs(self.lists[list]) do out[i] = ItemStack(stack) end
		return out
	end
	function inv:set_list(list, stacks)
		self.lists[list] = {}
		for i, stack in ipairs(stacks) do self.lists[list][i] = ItemStack(stack) end
	end
	function inv:get_lists()
		local out = {}
		for name in pairs(self.lists) do out[name] = self:get_list(name) end
		return out
	end
	function inv:add_item(list, stack)
		local rest = ItemStack(stack)
		for _, slot in ipairs(self.lists[list] or {}) do
			if not slot:is_empty() then rest = slot:add_item(rest) end
		end
		for _, slot in ipairs(self.lists[list] or {}) do
			if slot:is_empty() then rest = slot:add_item(rest) end
		end
		return rest
	end
	function inv:count(list, name)
		local n = 0
		for _, slot in ipairs(self.lists[list] or {}) do
			if slot:get_name() == name then n = n + slot:get_count() end
		end
		return n
	end
	return inv
end

-- The node world: names and metadata by position, node timers, LBMs.
local nodes, node_metas, timers, lbms = {}, {}, {}, {}
local protected, shown, chat, sounds = {}, {}, {}, {}
local callbacks = {loaded = {}, join = {}, leave = {}, fields = {}}
local entity_defs = {}
local online = {}
local logs = {}
local function node_meta(pos)
	local key = pos_key(pos)
	local meta = node_metas[key]
	if not meta then
		meta = new_meta()
		meta.inv = new_inventory()
		function meta:get_inventory() return self.inv end
		node_metas[key] = meta
	end
	return meta
end

local mod_paths = {
	grug_jobs = "/mods/PLAYER/grug_jobs", grug_brewing = "/mods/ITEMS/grug_brewing",
	grug_cooking = "/mods/ITEMS/grug_cooking", grug_alchemy = "/mods/ITEMS/grug_alchemy",
}
local current_mod = "grug_brewing"
local function register_item(name, def, kind)
	name = name:gsub("^:", "")
	def = copy(def)
	def.name, def.type = name, kind
	registered_items[name] = def
	if kind == "node" then core.registered_nodes[name] = def end
	return def
end
core = {
	registered_items = registered_items,
	registered_nodes = {},
	registered_entities = entity_defs,
	register_node = function(name, def) register_item(name, def, "node") end,
	register_craftitem = function(name, def) register_item(name, def, "craft") end,
	override_item = function(name, fields)
		local def = assert(registered_items[name], "override of " .. name)
		for key, value in pairs(fields) do def[key] = value end
	end,
	register_lbm = function(def) lbms[def.name:gsub("^:", "")] = def end,
	register_on_mods_loaded = function(fn) callbacks.loaded[#callbacks.loaded + 1] = fn end,
	register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
	register_on_leaveplayer = function(fn) callbacks.leave[#callbacks.leave + 1] = fn end,
	register_on_player_receive_fields = function(fn) callbacks.fields[#callbacks.fields + 1] = fn end,
	register_globalstep = function() end,
	get_modpath = function(name) return ROOT .. assert(mod_paths[name], name) end,
	get_current_modname = function() return current_mod end,
	get_meta = node_meta,
	get_node_or_nil = function(pos)
		local name = nodes[pos_key(vector.round(pos))]
		return {name = name or "default:dirt_with_grass"}
	end,
	get_node = function(pos) return core.get_node_or_nil(pos) end,
	swap_node = function(pos, node) nodes[pos_key(pos)] = node.name end,
	remove_node = function(pos) nodes[pos_key(pos)] = nil end,
	get_node_timer = function(pos)
		local key = pos_key(pos)
		return {start = function(_, t) timers[key] = t end,
			is_started = function() return timers[key] ~= nil end,
			stop = function() timers[key] = nil end}
	end,
	is_protected = function(pos) return protected[pos_key(pos)] == true end,
	show_formspec = function(name, form, spec) shown[#shown + 1] = {name = name, form = form, spec = spec} end,
	formspec_escape = function(text) return text end,
	chat_send_player = function(name, text) chat[#chat + 1] = name .. ": " .. text end,
	get_gametime = function() return clock - process_start end,
	get_us_time = function() return math.floor((clock - process_start) * 1000000) end,
	after = function(delay, fn) afters[#afters + 1] = {at = clock + delay, fn = fn} end,
	log = function(level, text) logs[#logs + 1] = level .. ": " .. text end,
	serialize = function(value) return "return " .. literal(value) end,
	deserialize = function(text)
		local fn = type(text) == "string" and loadstring(text)
		if not fn then return nil end
		setfenv(fn, {})
		local ok, value = pcall(fn)
		return ok and value or nil
	end,
	get_item_group = function(name, group)
		local def = registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	find_nodes_in_area = function(minp, maxp, names)
		local wanted, found = {}, {}
		for _, name in ipairs(names) do wanted[name] = true end
		for key, name in pairs(nodes) do
			local x, y, z = key:match("^(-?%d+),(-?%d+),(-?%d+)$")
			x, y, z = tonumber(x), tonumber(y), tonumber(z)
			if wanted[name] and x >= minp.x and x <= maxp.x and y >= minp.y and
					y <= maxp.y and z >= minp.z and z <= maxp.z then
				found[#found + 1] = vector.new(x, y, z)
			end
		end
		return found
	end,
	get_player_by_name = function(name) return online[name] end,
	add_item = function() end,
	pos_to_string = function(p) return ("(%d,%d,%d)"):format(p.x, p.y, p.z) end,
	create_detached_inventory = function() return new_inventory() end,
	get_craft_result = function() return {time = 0, item = ItemStack("")}, {items = {}} end,
	remove_detached_inventory = function() end,
	compare_block_status = function() return false end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})

local function new_player(name, pos)
	local meta, inv = new_meta(), new_inventory()
	inv:set_size("main", 32)
	local player = {name = name, pos = vector.new(pos or {x = 0, y = 10, z = 0}), hp = 20}
	function player:is_player() return true end
	function player:get_player_name() return self.name end
	function player:get_meta() return meta end
	function player:get_inventory() return inv end
	function player:get_pos() return vector.new(self.pos) end
	function player:get_hp() return self.hp end
	function player:get_inventory_formspec() return "" end
	online[name] = player
	return player
end

------------------------------------------------------------------------------
-- Mods the loaded files read.
------------------------------------------------------------------------------
default = {
	node_sound_metal_defaults = function() return {} end,
	node_sound_wood_defaults = function() return {} end,
	set_inventory_action_loggers = function() end,
	get_hotbar_bg = function() return "" end,
	node_formspec = {shown_form = function() return nil end},
	get_inventory_drops = function(pos, list, drops)
		local inv = core.get_meta(pos):get_inventory()
		for i = 1, inv:get_size(list) do
			local stack = inv:get_stack(list, i)
			if not stack:is_empty() then drops[#drops + 1] = stack:to_string() end
		end
	end,
}
grug_sounds = {play = function(event) sounds[#sounds + 1] = event return false end}
local levels = {}
grug_xp = {get_level = function(player) return levels[player:get_player_name()] or 60 end}
local feed = {}
grug_core = {
	interaction_protected = function(pos) return protected[pos_key(pos)] == true end,
	feed = function(player, _, text) feed[#feed + 1] = player:get_player_name() .. ": " .. text end,
	item_name = function(name) return (registered_items[name] or {}).description or name end,
	faction_ids = {"accord", "throng"},
}
grug_inventory = {BAG_COUNT = 0, content_list = function(i) return "grug_bag" .. i .. "_content" end,
	carried_lists = function() return {"main"} end,
	fits = function() return true end,
	give = function(player, stack) return player:get_inventory():add_item("main", stack) end}
local refreshed = 0
grug_inventory.refresh = function() refreshed = refreshed + 1 end
local classes = {}
local arrival
grug_classes = {
	get_class = function(player) return classes[player:get_player_name()] end,
	register_on_arrival = function(fn) arrival = fn end,
	registered_races = {human = {faction = "accord"}},
}
grug_factions = {get_faction = function() return "accord" end}
grug_smelting = {match = function() return nil end}

-- The settlement of the trainer readers: one start with the Cooking trainer
-- socket the world data gives every start, plus a tailor trainer.
local ANCHOR = {x = 0, y = 10, z = 100}
local SOCKETS = {
	{id = "trainer_cooking", role = "trainer", profession = "cooking",
		pos = {x = 2, y = 10, z = 102}, yaw = 0},
	{id = "trainer_tailor", role = "trainer", profession = "tailor",
		pos = {x = -2, y = 10, z = 102}, yaw = 0},
	{id = "cook_oven", role = "public_station", tags = {"furnace"},
		pos = {x = 4, y = 10, z = 104}, yaw = 0},
}
grug_core.start_identities = function() return {{race_id = "human", faction_id = "accord"}} end
grug_core.settlement_socket_settlements = function()
	return {{key = "dawnmere", race_id = "human", anchor = copy(ANCHOR)}}
end
grug_core.settlement_sockets_at = function(key)
	if key ~= "dawnmere" then return {} end
	local out = copy(SOCKETS)
	for _, socket in ipairs(out) do socket.pos = vector.new(socket.pos) end
	return out
end
grug_core.start_anchor = function() return copy(ANCHOR) end
grug_core.capital_anchor = function() return nil end
grug_core.start_ready = function() return true end
grug_core.register_on_starts_progress = function() end

-- grug_mobs: the real start_npcs.lua with stand-in families (r30_c's model).
local store = {}
mobs = {mob_class = {}}
function mobs:remove(entity) entity.object:remove() end
local live = {}
local function activate(name, staticdata, pos)
	local def = assert(entity_defs[name], name)
	local object = {pos = vector.new(pos or ANCHOR), valid = true}
	local entity = setmetatable({name = name, object = object}, {__index = def})
	function object:get_pos() return self.valid and vector.new(self.pos) or nil end
	function object:remove() self.valid = false end
	function object:get_luaentity() return self.valid and entity or nil end
	for k, v in pairs(core.deserialize(staticdata) or {}) do entity[k] = v end
	live[#live + 1] = entity
	if def.after_activate then def.after_activate(entity) end
	return object, entity
end
core.add_entity = function(pos, name, staticdata) return (activate(name, staticdata, pos)) end
core.get_objects_inside_radius = function()
	local out = {}
	for _, entity in ipairs(live) do
		if entity.object.valid then out[#out + 1] = entity.object end
	end
	return out
end
local retagged = {}
grug_mobs = {
	storage = {get_string = function(_, k) return store[k] or "" end,
		set_string = function(_, k, v) store[k] = v end},
	place_on_ground = function() end,
	face_yaw = function() end,
	refresh_visual = function() end,
	route_settlement = function() end,
	settlement_npc_name = function(key, _, _, family) return key .. " " .. family end,
	start_npc_retag = function(entity) retagged[#retagged + 1] = entity._grug_npc_name end,
	read_data_json = function()
		local rows = {}
		for object in read_file("mods/ENTITIES/grug_mobs/data/items.json"):gmatch("%b{}") do
			local id = object:match('"id"%s*:%s*"([^"]+)"')
			local tier = tonumber(object:match('"tier"%s*:%s*(%d+)'))
			if id and tier then rows[#rows + 1] = {id = id, tier = tier} end
		end
		return rows
	end,
}
do
	local names = dofile(ROOT .. "/tools/r28_b1/json.lua").parse(
		read_file("mods/ENTITIES/grug_mobs/data/pvp_names.json"))
	grug_mobs.pvp_garrison = dofile(ROOT .. "/mods/ENTITIES/grug_mobs/pvp_garrison.lua").new(
		dofile(ROOT .. "/mods/MAPGEN/grug_mapgen/wp40/r31_pvp_catalog.lua"), names)
end
-- The villager family claims on its first tick (start_villagers.lua).
entity_defs["grug_mobs:villager_human"] = {on_tick = function(self)
	self.temp = self.temp or {}
	if not self.temp.claimed then
		self.temp.claimed = true
		grug_mobs.start_npc_claim(self)
	end
end}
dofile(ROOT .. "/mods/ENTITIES/grug_mobs/start_npcs.lua")

------------------------------------------------------------------------------
-- The game's load order: grug_brewing, grug_jobs, grug_cooking, grug_alchemy.
------------------------------------------------------------------------------
dofile(ROOT .. "/mods/ITEMS/grug_brewing/init.lua")
core.register_node("default:furnace", {description = "Furnace"})
core.register_node("default:furnace_active", {description = "Furnace"})
core.register_node("grug_smelting:dual_furnace", {description = "Dual Furnace"})
core.register_node("grug_smelting:dual_furnace_active", {description = "Dual Furnace"})

current_mod = "grug_jobs"
grug_jobs = {}
local JOBS = ROOT .. "/mods/PLAYER/grug_jobs/"
local before_registry = #callbacks.loaded
dofile(JOBS .. "registry.lua")
-- The registry's load audit wants every item of the whole game: not run.
while #callbacks.loaded > before_registry do table.remove(callbacks.loaded) end
dofile(JOBS .. "state.lua")
dofile(JOBS .. "jobs.lua")
dofile(JOBS .. "trainers.lua")
local factory = dofile(JOBS .. "station_nodes.lua")
factory.install_jobs(grug_jobs)

current_mod = "grug_cooking"
grug_food = {register_item = function() return true end}
for _, name in ipairs({"grug_gathering:potato", "grug_gathering:corn",
		"default:blueberries", "default:apple"}) do
	core.register_craftitem(name, {description = name})
end
dofile(ROOT .. "/mods/ITEMS/grug_cooking/init.lua")

current_mod = "grug_alchemy"
grug_alchemy = {
	register_consumable = function(id, def)
		core.register_craftitem("grug_alchemy:" .. id, {description = def.description,
			inventory_image = "grug_alchemy_" .. id .. ".png", stack_max = 10,
			groups = {grug_potion = 1}})
	end,
	potion_use = function() return function() end end,
	elixir_use = function() return function() end end,
	utility_use = function() return function() end end,
	TIER_LEVELS = {1, 11, 21, 31, 41, 51},
}
grug_traders = {POTION_COOLDOWN = 60, register_all_vendor_stock = function() end}
local herb_authorizer
grug_gathering = {register_herb_authorizer = function(fn) herb_authorizer = fn end}
dofile(ROOT .. "/mods/ITEMS/grug_alchemy/recipes.lua")

-- The readers that load after grug_jobs.
grug_map = {atlas = {}}
local marker_providers = {}
function grug_map.atlas.register_marker_provider(kind, fn) marker_providers[kind] = fn end
grug_quests = {registered_npcs = {}, marker_states = function() return {} end}
dofile(ROOT .. "/mods/PLAYER/grug_map/providers.lua")
local repair_providers = {}
grug_repair = {
	register_provider = function(kind, fn) repair_providers[kind] = fn end,
	provider_permitted = function(player, provider)
		return provider ~= nil and repair_providers[provider.kind](player, provider) == true
	end,
}
dofile(ROOT .. "/mods/ITEMS/grug_repair/providers.lua")

for _, fn in ipairs(callbacks.loaded) do fn() end

local PROXIMITY = {"grug_jobs:forge", "grug_jobs:tanning_rack", "grug_jobs:tailor_bench",
	"grug_jobs:carving_bench", "grug_jobs:jewellers_bench", "grug_brewing:brewing_stand",
	"grug_brewing:brewing_stand_active"}
local PREFIX = "grug_jobs:workspace:"
local function place(pos, name)
	nodes[pos_key(pos)] = name
	node_metas[pos_key(pos)] = nil
	timers[pos_key(pos)] = nil
	local def = core.registered_nodes[name]
	if def.on_construct then def.on_construct(pos) end
	return def, core.get_meta(pos)
end
local function counts(drops)
	local out = {}
	for _, item in ipairs(drops) do
		local stack = ItemStack(item)
		out[stack:get_name()] = (out[stack:get_name()] or 0) + stack:get_count()
	end
	return out
end

------------------------------------------------------------------------------
-- S. Proximity stations.
------------------------------------------------------------------------------
do
	local smith = new_player("smith", {x = 0, y = 10, z = 0})
	for index, name in ipairs(PROXIMITY) do
		local def = core.registered_nodes[name]
		check(def ~= nil and def._grug_station ~= nil, "S " .. name .. " is a station")
		def = def or {}
		eq(def.on_rightclick, nil, "S " .. name .. " has no on_rightclick")
		eq(def.on_construct, nil, "S " .. name .. " builds no lists")
		local pos = vector.new(index, 10, 1)
		local _, meta = place(pos, name)
		eq(next(meta:get_inventory():get_lists()), nil, "S a new " .. name .. " holds no list")
		local before = #shown
		eq(grug_jobs.workspaces.open(pos, smith), false, "S " .. name .. " opens nothing")
		eq(#shown, before, "S " .. name .. " shows no form")
		-- An old list (before Round 45) neither takes nor gives.
		meta:get_inventory():set_size("craft", 9)
		meta:get_inventory():set_stack("craft", 1, ItemStack("default:stick 4"))
		eq(def.allow_metadata_inventory_take(pos, "craft", 1, ItemStack("default:stick 4"), smith),
			0, "S " .. name .. " gives nothing from an old list")
		eq(def.allow_metadata_inventory_put(pos, "craft", 2, ItemStack("default:stick"), smith),
			0, "S " .. name .. " takes nothing")
	end
	for _, name in ipairs({"default:furnace", "grug_smelting:dual_furnace"}) do
		local def = core.registered_nodes[name]
		check(type(def.on_rightclick) == "function", "S " .. name .. " keeps its dialog")
		local pos = vector.new(0, 10, 3)
		local _, meta = place(pos, name)
		check(next(meta:get_inventory():get_lists()) ~= nil, "S a new " .. name .. " has its lists")
		local before = #shown
		def.on_rightclick(pos, {name = name}, smith, ItemStack(""))
		eq(#shown, before + 1, "S " .. name .. " shows its form")
		eq(shown[#shown].form, "grug_jobs:workspace", "S ...the workspace form")
		check(not shown[#shown].spec:find("Crafting moved", 1, true), "S ...without a notice")
	end
	local lbm = lbms["grug_jobs:workspace_activation"]
	check(lbm ~= nil, "S the workspace activation LBM exists")
	local named = {}
	for _, name in ipairs(lbm and lbm.nodenames or {}) do named[name] = true end
	check(named["default:furnace"] and named["grug_smelting:dual_furnace"],
		"S the activation LBM names the furnaces")
	for _, name in ipairs(PROXIMITY) do
		check(not named[name], "S the activation LBM skips " .. name)
	end
	eq(lbms["grug_jobs:activate_stations"], nil, "S the old grid LBM is gone")
	-- A brewing stand lit before Round 45 goes out at its node timer.
	local pos = vector.new(9, 10, 1)
	local def = place(pos, "grug_brewing:brewing_stand_active")
	eq(def.on_timer(pos, 1), false, "S the lit stand's timer stops")
	eq(nodes[pos_key(pos)], "grug_brewing:brewing_stand", "S ...and the stand goes out")
end

------------------------------------------------------------------------------
-- D. The dig refund of player-placed stations (round45-plan.md ruling 3).
------------------------------------------------------------------------------
do
	local digger = new_player("digger", {x = 0, y = 10, z = 10})
	local pos = vector.new(0, 10, 12)
	local def, meta = place(pos, "grug_jobs:forge")
	local inv = meta:get_inventory()
	inv:set_size("craft", 9)
	inv:set_stack("craft", 1, ItemStack("grug_materials:steel_bar 3"))
	inv:set_stack("craft", 5, ItemStack("default:stick 2"))
	meta:set_string(PREFIX .. "alice", core.serialize({lists = {craft = {"default:coal_lump 2", ""}}}))
	eq(def.can_dig(pos, digger), true, "D an old full forge can be dug")
	local drops = {"grug_jobs:forge"}
	def.preserve_metadata(pos, {name = "grug_jobs:forge"}, meta:to_table().fields, drops)
	local got = counts(drops)
	eq(got["grug_jobs:forge"], 1, "D the dug forge drops itself")
	eq(got["grug_materials:steel_bar"], 3, "D ...its old crafting grid")
	eq(got["default:stick"], 2, "D ...all of it")
	eq(got["default:coal_lump"], 2, "D ...and a saved workspace record")
	got = counts(def.on_blast(pos))
	eq(got["grug_jobs:forge"], 1, "D a blast drops the forge")
	eq(got["grug_materials:steel_bar"], 3, "D ...and its old grid")
	eq(nodes[pos_key(pos)], nil, "D ...and removes it")

	local stand_pos = vector.new(0, 10, 13)
	local stand, stand_meta = place(stand_pos, "grug_brewing:brewing_stand")
	local stand_inv = stand_meta:get_inventory()
	stand_inv:set_size("mixture", 1)
	stand_inv:set_size("fuel", 1)
	stand_inv:set_size("output", 2)
	stand_inv:set_stack("mixture", 1, ItemStack("grug_alchemy:mixture_potion_healing_t1 2"))
	stand_inv:set_stack("fuel", 1, ItemStack("default:coal_lump 3"))
	stand_inv:set_stack("output", 2, ItemStack("grug_alchemy:potion_healing_t1"))
	drops = {"grug_brewing:brewing_stand"}
	stand.preserve_metadata(stand_pos, {name = "grug_brewing:brewing_stand"},
		stand_meta:to_table().fields, drops)
	got = counts(drops)
	eq(got["grug_alchemy:mixture_potion_healing_t1"], 2, "D an old stand's mixture comes out")
	eq(got["default:coal_lump"], 3, "D ...its fuel")
	eq(got["grug_alchemy:potion_healing_t1"], 1, "D ...and its output")

	local bench_pos = vector.new(0, 10, 14)
	local bench = place(bench_pos, "grug_jobs:tailor_bench")
	drops = {"grug_jobs:tailor_bench"}
	bench.preserve_metadata(bench_pos, {name = "grug_jobs:tailor_bench"}, {}, drops)
	eq(#drops, 1, "D a new bench drops only itself")

	-- An authored public station (a capital's) stays undiggable and blast-proof.
	factory.register_public_position("forge", pos)
	place(pos, "grug_jobs:forge")
	eq(def.can_dig(pos, digger), false, "D a public forge cannot be dug")
	eq(#def.on_blast(pos), 0, "D ...and a blast leaves it")
	protected[pos_key(bench_pos)] = true
	eq(bench.can_dig(bench_pos, digger), false, "D protection still refuses the dig")
	protected[pos_key(bench_pos)] = nil
end

------------------------------------------------------------------------------
-- C. Cooking at join (spec ruling 28).
------------------------------------------------------------------------------
do
	local function join(player)
		for _, fn in ipairs(callbacks.join) do fn(player) end
	end
	chat, sounds, refreshed = {}, {}, 0
	-- A new player: nothing is stored while the character is being created.
	local new = new_player("newcomer")
	join(new)
	eq(grug_jobs.has(new, "cooking"), false, "C a player in character creation knows nothing")
	local stored = {}
	for key in pairs(new:get_meta().fields) do
		if key:find("^grug_jobs:learned") or key:find("^grug_jobs:level") then stored[#stored + 1] = key end
	end
	eq(#stored, 0, "C ...and nothing about professions is stored")
	-- Its arrival after "Create character".
	classes.newcomer = "warrior"
	check(arrival ~= nil, "C Cooking registers an arrival callback")
	if arrival then arrival(new) end
	eq(grug_jobs.has(new, "cooking"), true, "C a new character knows Cooking at its arrival")
	eq(grug_jobs.profession_level(new, "cooking"), 1, "C ...at T1")
	eq(grug_jobs.crafts_in_tier(new, "cooking"), 0, "C ...with no crafts")
	-- An existing character without Cooking learns it at its next join.
	local old = new_player("veteran")
	classes.veteran = "mage"
	levels.veteran = 35
	join(old)
	eq(grug_jobs.has(old, "cooking"), true, "C an existing character learns Cooking at join")
	eq(grug_jobs.profession_level(old, "cooking"), 1, "C ...at T1")
	eq(#chat, 0, "C the join learning is quiet (no chat)")
	eq(#sounds, 0, "C ...plays no sound")
	eq(refreshed, 0, "C ...and resends no page")
	-- A character who knows Cooking keeps its tier and crafts.
	local cook = new_player("cook")
	classes.cook = "scout"
	levels.cook = 40
	local meta = cook:get_meta()
	meta:set_int("grug_jobs:learned:cooking", 1)
	meta:set_int("grug_jobs:level:cooking", 3)
	meta:set_int("grug_jobs:crafts:cooking", 7)
	meta.writes = 0
	join(cook)
	eq(grug_jobs.profession_level(cook, "cooking"), 3, "C a known Cooking keeps its tier")
	eq(grug_jobs.crafts_in_tier(cook, "cooking"), 7, "C ...and its crafts")
	eq(meta.writes, 0, "C ...and the join writes nothing")
	old:get_meta().writes = 0
	join(old)
	eq(old:get_meta().writes, 0, "C a second join writes nothing")
	-- A Cooking record: no station, 1 s, XP.
	local stew = grug_jobs.recipes_for_output("grug_cooking:sweetroot_mash")[1]
	check(stew and stew.area == "cooking" and stew.station == nil and stew.time == 1 and
		stew.progress == true, "C a simple dish is a Cooking recipe without a station")
	eq(grug_jobs.STARTER_PROFESSIONS.cooking, true, "C Cooking is a starter profession")
	eq(grug_jobs.unlearn(old, "cooking"), false, "C Cooking cannot be unlearned")
end

------------------------------------------------------------------------------
-- T. The trainer mapping in each trainer-role reader.
------------------------------------------------------------------------------
do
	eq(grug_jobs.trainer_teaches("cooking"), false, "T no trainer teaches Cooking")
	eq(grug_jobs.trainer_teaches("tailor"), true, "T a tailor trainer teaches")
	eq(grug_jobs.trainer_teaches("alchemist"), true, "T an alchemy trainer teaches")
	eq(grug_jobs.trainer_teaches("nonsense"), false, "T an unknown profession has no trainer")
	local visitor = new_player("visitor", {x = 0, y = 10, z = 102})
	local before = #shown
	eq(grug_jobs.open_trainer(visitor, "cooking", {x = 2, y = 10, z = 102}), false,
		"T open_trainer refuses Cooking")
	eq(#shown, before, "T ...and shows no trainer dialog")
	eq(grug_jobs.open_trainer(visitor, "tailor", {x = -2, y = 10, z = 102}), true,
		"T open_trainer still opens the tailor trainer")

	-- start_npcs.lua at placement.
	run_timers()
	for _, entity in ipairs(live) do
		if entity.on_tick and entity.object.valid then entity:on_tick() end
	end
	local by_socket = {}
	for _, entity in ipairs(live) do
		if entity.object.valid and entity._grug_socket then by_socket[entity._grug_socket] = entity end
	end
	local cooking, tailor = by_socket.trainer_cooking, by_socket.trainer_tailor
	check(cooking ~= nil and tailor ~= nil, "T both trainer sockets hold an NPC")
	cooking, tailor = cooking or {}, tailor or {}
	eq(cooking.name, "grug_mobs:villager_human", "T the Cooking socket holds a villager")
	eq(cooking._grug_profession, nil, "T ...without a profession")
	eq(cooking._grug_npc_name, "dawnmere villager", "T ...named as a villager")
	eq(cooking._grug_socket_role, "trainer", "T ...on its unchanged trainer socket")
	eq(cooking._grug_walker, false, "T ...standing at it")
	eq(tailor._grug_profession, "tailor", "T the tailor trainer keeps its profession")
	eq(tailor._grug_npc_name, "Tailor Trainer", "T ...and its name")

	-- At activation: a Cooking trainer saved before Round 45 turns ordinary.
	retagged = {}
	local _, saved = activate("grug_mobs:villager_human", core.serialize({
		_grug_start = "dawnmere", _grug_socket = "trainer_cooking",
		_grug_socket_role = "trainer", _grug_profession = "cooking",
		_grug_npc_name = "Cooking Trainer", _grug_placed_at = -1, _grug_walker = false}),
		{x = 2, y = 10, z = 102})
	saved:on_tick()
	eq(saved._grug_profession, nil, "T a saved Cooking trainer loses its profession at activation")
	eq(saved._grug_npc_name, "dawnmere villager", "T ...takes the villager name")
	eq(retagged[1], "dawnmere villager", "T ...and its nametag follows")
	local _, saved_tailor = activate("grug_mobs:villager_human", core.serialize({
		_grug_start = "dawnmere", _grug_socket = "trainer_tailor",
		_grug_socket_role = "trainer", _grug_profession = "tailor",
		_grug_npc_name = "Tailor Trainer", _grug_placed_at = -1}), {x = -2, y = 10, z = 102})
	saved_tailor:on_tick()
	eq(saved_tailor._grug_profession, "tailor", "T a saved tailor trainer stays a trainer")

	-- The map: no marker for the Cooking socket, the tailor trainer's stays.
	local labels = {}
	for _, marker in ipairs(marker_providers.service(visitor)) do labels[marker.label] = marker.kind end
	eq(labels["Tailor Trainer"], "trainer", "T the map marks the tailor trainer")
	eq(labels["Cooking Trainer"], nil, "T the map marks no Cooking trainer")
	local trainer_markers = 0
	for _, kind in pairs(labels) do if kind == "trainer" then trainer_markers = trainer_markers + 1 end end
	eq(trainer_markers, 1, "T ...one trainer marker in all")

	-- Repair: the tailor trainer offers it, the former Cooking trainer never
	-- (even a stale entity that still carries the profession).
	saved_tailor.object.pos = vector.new(-2, 10, 102)
	eq(grug_repair.can_open_trainer(visitor, saved_tailor), true, "T the tailor trainer repairs")
	eq(grug_repair.can_open_trainer(visitor, saved), false, "T the former Cooking trainer does not")
	local _, stale = activate("grug_mobs:villager_human", core.serialize({
		_grug_start = "dawnmere", _grug_socket = "trainer_cooking",
		_grug_socket_role = "trainer", _grug_profession = "cooking"}), {x = 2, y = 10, z = 102})
	eq(grug_repair.can_open_trainer(visitor, stale), false,
		"T ...not even before its first claim")
end

------------------------------------------------------------------------------
-- A. Alchemy: finished potions at the brewing stand.
------------------------------------------------------------------------------
do
	local by_output = {}
	local mixtures_made, mixtures_used = 0, 0
	for _, recipe in ipairs(grug_jobs.recipes) do
		if recipe.output:find("^grug_alchemy:mixture_") then mixtures_made = mixtures_made + 1 end
		for _, entry in ipairs(recipe.ingredients) do
			if entry.item and entry.item:find("^grug_alchemy:mixture_") then
				mixtures_used = mixtures_used + 1
			end
		end
		if recipe.area == "alchemist" then
			by_output[recipe.output] = (by_output[recipe.output] or 0) + 1
		end
	end
	eq(#grug_alchemy.CATALOG, 40, "A the catalogue has its 40 products")
	for _, row in ipairs(grug_alchemy.CATALOG) do
		local output = "grug_alchemy:" .. row.id
		local records = grug_jobs.recipes_for_output(output)
		eq(#records, 1, "A " .. row.id .. " has one recipe")
		local recipe = records[1] or {}
		check(recipe.area == "alchemist" and recipe.station == "brewing_stand" and
			recipe.time == 2 and recipe.progress == true and recipe.tier == row.tier and
			recipe.count == 1, "A " .. row.id .. ": Alchemy at the brewing stand, 2 s, XP, T" .. row.tier)
		local listed = {}
		for _, entry in ipairs(recipe.ingredients or {}) do
			listed[#listed + 1] = (entry.item or ("group:" .. entry.group)) .. "*" .. entry.n
		end
		local expected = {}
		for _, input in ipairs(row.inputs) do expected[#expected + 1] = input .. "*1" end
		eq(table.concat(listed, "+"), table.concat(expected, "+"), "A " .. row.id .. " keeps its ingredients")
	end
	eq(by_output["grug_brewing:brewing_stand"], 1, "A the stand's own recipe stays")
	local count = 0
	for _ in pairs(by_output) do count = count + 1 end
	eq(count, 41, "A the Alchemy area holds the 40 products and the stand")
	eq(mixtures_made, 0, "A no recipe makes a mixture")
	eq(mixtures_used, 0, "A no recipe uses a mixture")

	-- A job: refused without a stand within 4 nodes, then two potions.
	local alchemist = new_player("alchemist", {x = 50, y = 10, z = 50})
	classes.alchemist = "mage"
	levels.alchemist = 12
	grug_jobs.learn(alchemist, "alchemist", true)
	grug_jobs.ensure_output_area(alchemist)
	local inv = alchemist:get_inventory()
	inv:set_stack("main", 9, ItemStack("grug_gathering:gravemoss 2"))
	inv:set_stack("main", 10, ItemStack("grug_gathering:sunleaf 2"))
	inv:set_stack("main", 11, ItemStack("vessels:glass_bottle 2"))
	local id = grug_jobs.recipes_for_output("grug_alchemy:potion_healing_t1")[1].id
	nodes[pos_key(vector.new(55, 10, 50))] = "grug_brewing:brewing_stand"
	local ok, reason, info = grug_jobs.start_job(alchemist, id, 2)
	eq(ok, false, "A a job 5 nodes from the stand is refused")
	eq(reason, "Requires: Brewing Stand nearby", "A ...with the station hint")
	eq(info and info.code, "station", "A ...code station")
	eq(inv:count("main", "grug_gathering:gravemoss"), 2, "A ...and takes nothing")
	nodes[pos_key(vector.new(55, 10, 50))] = nil
	ok = grug_jobs.start_job(alchemist, id, 2)
	eq(ok, false, "A a job without any stand is refused")
	nodes[pos_key(vector.new(53, 11, 52))] = "grug_brewing:brewing_stand_active"
	ok = grug_jobs.start_job(alchemist, id, 2)
	eq(ok, true, "A a lit stand counts as the brewing stand too")
	grug_jobs.cancel_job(alchemist)
	nodes[pos_key(vector.new(53, 11, 52))] = "grug_brewing:brewing_stand"
	local job
	ok, reason, job = grug_jobs.start_job(alchemist, id, 2)
	eq(ok, true, "A a job within 4 nodes of the stand starts")
	eq(job and job.finish - job.start, 4, "A ...two potions take 2 s each")
	eq(inv:count("main", "grug_gathering:gravemoss"), 0, "A ...and consumes the herbs")
	clock = clock + 4
	run_timers()
	eq(inv:count("grug_craft_out", "grug_alchemy:potion_healing_t1"), 2,
		"A the finished potions are in the output area")
	eq(inv:count("grug_craft_out", "grug_alchemy:mixture_potion_healing_t1"), 0, "A ...no mixture")
	eq(grug_jobs.crafts_in_tier(alchemist, "alchemist"), 2, "A one Alchemy XP per potion")
	-- The herb gate stays: only an alchemist gathers herbs.
	check(herb_authorizer ~= nil, "A the herb gate is registered")
	if herb_authorizer then
		eq((herb_authorizer(alchemist)), true, "A an alchemist may gather herbs")
		eq((herb_authorizer(new_player("farmer"))), false, "A nobody else may")
	end
end

------------------------------------------------------------------------------
-- M. The mixtures are inert items.
------------------------------------------------------------------------------
do
	local mixtures = 0
	for name, def in pairs(registered_items) do
		if name:find("^grug_alchemy:mixture_") then
			mixtures = mixtures + 1
			check(def.groups and def.groups.grug_potion_mixture == 1, "M " .. name .. " keeps its group")
			check(def.description:find("No longer used", 1, true) ~= nil, "M " .. name .. " says it is unused")
			eq(grug_jobs.ingredient_tier(name), nil, "M " .. name .. " is no ingredient")
			eq(def.on_use, nil, "M " .. name .. " has no use")
		end
	end
	eq(mixtures, 40, "M the 40 mixture ids stay registered")
	eq(grug_brewing.register_recipe, nil, "M the brewing adapter is gone")
	eq(grug_brewing.match, nil, "M ...and its matcher")
	local automatic = dofile(JOBS .. "automatic.lua")
	eq(automatic.sizes.brewing_stand, nil, "M the automatic brewing is gone")
	check(automatic.sizes.furnace and automatic.sizes.dual_furnace, "M the furnaces stay automatic")
	local source = read_file("mods/PLAYER/grug_jobs/automatic.lua")
	eq(source:find("grug_brewing", 1, true), nil, "M automatic.lua reads no brewing")
end

if failures > 0 then
	print(("%d checks, %d failures"):format(checks, failures))
	os.exit(1)
end
print(("R45 ST PORTABLE PASS checks=%d"):format(checks))
