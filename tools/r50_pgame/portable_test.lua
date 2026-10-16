-- Round 50 lane PGAME portable test (LuaJIT; docs/planning/round50-plan.md
-- rulings 5-8, D5-D8 and §3). Loads the REAL grug_core world_version.lua
-- (the pack-marker runner) and node_rightclick.lua, the REAL grug_housing
-- api.lua (over its registry model and an in-memory mod storage),
-- soulbound.lua, packed.lua, recovered.lua and interface.lua (with
-- stone_form.lua and manager.lua), and the vendored default/chests.lua
-- (the real chest and locked chest), under a small engine stub. The furnace,
-- the bookshelf and the vessels shelf are stand-ins whose on_construct sets
-- the list sizes their vendored on_construct sets (read from the source).
-- The tool's entries are written as §3 describes, before the load.
--   A. the guards: in main and in a bag, never in a chest, a station, the
--      mail, the inbox, a bag slot, the craft grid, a trade; never sold;
--      dropping is refused and keeps the item;
--   B. the marker handler at the load: unknown items removed, an unknown
--      node and a shrunken list into additional packed chests (D6), an
--      overfull charcoal stack split, the descriptions and images, the
--      marker deleted, an older pass untouched; a rerun and a half-done
--      rerun change nothing;
--   C. the entries survive M.map_reset; the list sizes match the vendored
--      on_construct code;
--   D. the Claim Stone inventory: the Belongings tab of the active stone
--      only (never the draft's), take-only, a take deletes its entry or
--      keeps the rest, a stale slot, a closed form and a full inventory take
--      nothing, the entries survive picking the stone up and losing it;
--   E. placing every container kind with exact contents (item meta
--      included), the locked chest owned by the placer, the furnace unlit,
--      a protected and an invalid spot keep the item, a packed container
--      that no longer fits is refused and kept;
--   F. the join notice and the Housing Steward's line.
--
--   luajit tools/r50_pgame/portable_test.lua [REPO]
-- Prints "R50 PGAME PORTABLE PASS checks=<n>", or the failures and raises.

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
local function has(text, needle, label)
	return check(type(text) == "string" and text:find(needle, 1, true) ~= nil,
		label .. " (missing " .. needle .. ")")
end
local function lacks(text, needle, label)
	return check(type(text) == "string" and text:find(needle, 1, true) == nil,
		label .. " (unexpected " .. needle .. ")")
end
local function read(path)
	local file = assert(io.open(ROOT .. "/" .. path, "r"))
	local text = file:read("*a")
	file:close()
	return text
end
function string.trim(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end

------------------------------------------------------------------------------
-- Serialization (deterministic: sorted keys) and stacks with item meta.
------------------------------------------------------------------------------
local function ser(value)
	local kind = type(value)
	if kind == "string" then return ("%q"):format(value) end
	if kind == "number" or kind == "boolean" then return tostring(value) end
	if kind ~= "table" then return "nil" end
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b)
		if type(a) ~= type(b) then return type(a) < type(b) end
		return a < b
	end)
	local parts = {}
	for _, key in ipairs(keys) do
		parts[#parts + 1] = "[" .. ser(key) .. "]=" .. ser(value[key])
	end
	return "{" .. table.concat(parts, ",") .. "}"
end
local function deser(text)
	local fn = loadstring("return " .. text)
	if not fn then return nil end
	setfenv(fn, {})
	local ok, value = pcall(fn)
	return ok and value or nil
end

local Stack = {}
Stack.__index = Stack
local function new_meta(fields)
	local meta = {fields = fields or {}}
	function meta:get_string(key) return self.fields[key] or "" end
	function meta:set_string(key, value)
		self.fields[key] = (value ~= nil and value ~= "") and tostring(value) or nil
	end
	function meta:get_int(key) return tonumber(self.fields[key]) or 0 end
	function meta:set_int(key, value) self:set_string(key, tostring(value)) end
	function meta:to_table()
		local copy = {}
		for key, value in pairs(self.fields) do copy[key] = value end
		return {fields = copy}
	end
	return meta
end
function ItemStack(value)
	local s = setmetatable({name = "", count = 0, meta = new_meta()}, Stack)
	if getmetatable(value) == Stack then
		s.name, s.count = value.name, value.count
		for key, v in pairs(value.meta.fields) do s.meta.fields[key] = v end
	elseif type(value) == "table" then
		s.name, s.count = value.name or "", value.count or 1
	elseif type(value) == "string" and value ~= "" then
		local name, rest = value:match("^(%S+)%s*(.*)$")
		local count, wear, meta = rest:match("^(%d+)%s*(%d*)%s*(.*)$")
		s.name, s.count = name, tonumber(count) or 1
		local fields = meta and meta ~= "" and deser(meta) or nil
		if fields then s.meta.fields = fields end
		local alias = core.registered_aliases[s.name]
		if alias then s.name = alias end
	end
	if s.count <= 0 then s.name, s.count = "", 0 end
	return s
end
function Stack:is_empty() return self.name == "" or self.count <= 0 end
function Stack:get_name() return self:is_empty() and "" or self.name end
function Stack:get_count() return self.count end
function Stack:set_count(n)
	self.count = n
	if n <= 0 then self.name, self.count = "", 0 end
end
function Stack:get_meta() return self.meta end
function Stack:get_definition() return core.registered_items[self.name] end
function Stack:get_stack_max()
	local def = core.registered_items[self.name]
	return def and def.stack_max or 99
end
function Stack:get_short_description()
	local text = self.meta:get_string("short_description")
	if text == "" then text = self.meta:get_string("description") end
	if text == "" then
		local def = core.registered_items[self.name]
		text = def and def.description or self.name
	end
	return (text:match("^[^\n]*"))
end
function Stack:to_string()
	if self:is_empty() then return "" end
	if next(self.meta.fields) then
		return self.name .. " " .. self.count .. " 0 " .. ser(self.meta.fields)
	end
	return self.count == 1 and self.name or self.name .. " " .. self.count
end
function Stack:take_item(n)
	n = math.min(n or 1, self.count)
	local taken = ItemStack(self)
	taken.count = n
	self:set_count(self.count - n)
	if taken.count <= 0 then return ItemStack("") end
	return taken
end

local function new_inventory()
	local inv = {lists = {}}
	function inv:set_size(list, size)
		local old, new = self.lists[list] or {}, {}
		for i = 1, size do new[i] = old[i] or ItemStack("") end
		self.lists[list] = new
	end
	function inv:get_size(list) return self.lists[list] and #self.lists[list] or 0 end
	function inv:get_stack(list, index)
		local stack = self.lists[list] and self.lists[list][index]
		return ItemStack(stack or "")
	end
	function inv:set_stack(list, index, stack)
		assert(self.lists[list] and index >= 1 and index <= #self.lists[list],
			"set_stack out of range: " .. tostring(list) .. "#" .. tostring(index))
		self.lists[list][index] = ItemStack(stack)
	end
	function inv:get_list(list)
		if not self.lists[list] then return nil end
		local out = {}
		for i, stack in ipairs(self.lists[list]) do out[i] = ItemStack(stack) end
		return out
	end
	function inv:set_list(list, stacks)
		local size = self:get_size(list)
		for i = 1, size do self.lists[list][i] = ItemStack(stacks[i] or "") end
	end
	function inv:get_lists()
		local out = {}
		for name in pairs(self.lists) do out[name] = self:get_list(name) end
		return out
	end
	function inv:is_empty(list)
		for _, stack in ipairs(self.lists[list] or {}) do
			if not stack:is_empty() then return false end
		end
		return true
	end
	function inv:contains_item(list, item)
		local name = ItemStack(item):get_name()
		for _, stack in ipairs(self.lists[list] or {}) do
			if stack:get_name() == name then return true end
		end
		return false
	end
	return inv
end

------------------------------------------------------------------------------
-- Engine surface.
------------------------------------------------------------------------------
local storages = {}
local current_mod = "grug_core"
local function mod_storage(mod)
	storages[mod] = storages[mod] or {}
	local data = storages[mod]
	return {
		get_string = function(_, key) return data[key] or "" end,
		set_string = function(_, key, value) data[key] = value ~= "" and value or nil end,
		get_int = function(_, key) return tonumber(data[key]) or 0 end,
		set_int = function(_, key, value) data[key] = tostring(value) end,
		get_keys = function()
			local keys = {}
			for key in pairs(data) do keys[#keys + 1] = key end
			return keys
		end,
	}
end
local function snapshot(mod)
	local keys, out = {}, {}
	for key in pairs(storages[mod] or {}) do keys[#keys + 1] = key end
	table.sort(keys)
	for _, key in ipairs(keys) do out[#out + 1] = key .. "=" .. storages[mod][key] end
	return table.concat(out, "\n")
end

local allow_player, mods_loaded, joins, receive, afters = {}, {}, {}, {}, {}
local shown, closed, chats, flashes, feeds = {}, {}, {}, {}, {}
local detached = {}
local nodes, metas = {}, {}
local protected = {}
local players = {}
local function hash(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end

core = {
	registered_items = {}, registered_nodes = {}, registered_aliases = {},
	registered_on_joinplayers = joins, detached_inventories = {},
	settings = {get = function() return nil end, get_bool = function(_, _, d) return d end},
	get_item_group = function(name, group)
		local def = core.registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	register_allow_player_inventory_action = function(fn) allow_player[#allow_player + 1] = fn end,
	register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_newplayer = function() end,
	register_on_leaveplayer = function() end,
	register_on_dieplayer = function() end,
	register_globalstep = function() end,
	register_on_player_receive_fields = function(fn) receive[#receive + 1] = fn end,
	register_lbm = function() end,
	register_craft = function() end,
	register_chatcommand = function() end,
	override_item = function(name, fields)
		for key, value in pairs(fields) do core.registered_items[name][key] = value end
	end,
	create_detached_inventory = function(name, callbacks)
		local inv = new_inventory()
		detached[name] = {callbacks = callbacks, inv = inv}
		core.detached_inventories[name] = callbacks
		return inv
	end,
	remove_detached_inventory = function(name)
		detached[name] = nil
		core.detached_inventories[name] = nil
	end,
	get_modpath = function(name)
		if name == "grug_housing" then return ROOT .. "/mods/PLAYER/grug_housing" end
		if name == "grug_core" then return ROOT .. "/mods/CORE/grug_core" end
		error("no modpath for " .. tostring(name))
	end,
	get_current_modname = function() return current_mod end,
	get_mod_storage = function() return mod_storage(current_mod) end,
	get_game_info = function() return {path = "/game"} end,
	get_worldpath = function() return "/world" end,
	get_dir_list = function() return {} end,
	log = function() end,
	serialize = function(value) return "return " .. ser(value) end,
	deserialize = function(text)
		if type(text) ~= "string" then return nil end
		return deser((text:gsub("^return%s*", "")))
	end,
	colorize = function(color, text) return "(c@" .. color .. ")" .. text end,
	formspec_escape = function(text)
		return (tostring(text):gsub("\\", "\\\\"):gsub("%[", "\\["):gsub("%]", "\\]")
			:gsub(";", "\\;"):gsub(",", "\\,"))
	end,
	pos_to_string = function(pos) return "(" .. hash(pos) .. ")" end,
	chat_send_player = function(name, text) chats[#chats + 1] = {name = name, text = text} end,
	after = function(_, fn, ...) afters[#afters + 1] = {fn = fn, args = {...}} end,
	show_formspec = function(name, formname, fs)
		shown[#shown + 1] = {name = name, formname = formname, fs = fs}
	end,
	close_formspec = function(name, formname)
		closed[#closed + 1] = {name = name, formname = formname}
	end,
	get_player_by_name = function(name) return players[name] end,
	player_exists = function(name) return players[name] ~= nil end,
	is_protected = function(pos) return protected[hash(pos)] == true end,
	record_protection_violation = function() end,
	sound_play = function() end,
	load_area = function() end,
}
minetest = core
function Settings() return {get = function(_, key) return key == "version" and "0.50.0" or nil end} end
vector = {
	round = function(p) return {x = math.floor(p.x + 0.5), y = math.floor(p.y + 0.5), z = math.floor(p.z + 0.5)} end,
	copy = function(p) return {x = p.x, y = p.y, z = p.z} end,
	equals = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end,
}
function table.copy(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, v in pairs(value) do copy[key] = table.copy(v) end
	return copy
end
local function run_afters()
	while #afters > 0 do
		local queue = afters
		afters = {}
		for _, job in ipairs(queue) do job.fn(unpack(job.args)) end
	end
end
local function last_shown(name)
	for i = #shown, 1, -1 do
		if shown[i].name == name then return shown[i] end
	end
end

-- The map: nodes with metadata and an inventory each.
function core.get_node_or_nil(pos) return nodes[hash(pos)] end
function core.get_node(pos) return nodes[hash(pos)] or {name = "air"} end
function core.get_meta(pos)
	local h = hash(pos)
	if not metas[h] then
		local meta = new_meta()
		local inv = new_inventory()
		function meta.get_inventory() return inv end
		metas[h] = meta
	end
	return metas[h]
end
function core.set_node(pos, node)
	local h = hash(pos)
	local old = nodes[h]
	local old_def = old and core.registered_nodes[old.name]
	if old_def and old_def.on_destruct then old_def.on_destruct(pos) end
	nodes[h], metas[h] = {name = node.name, param2 = node.param2 or 0}, nil
	local def = core.registered_nodes[node.name]
	if def and def.on_construct then def.on_construct(vector.copy(pos)) end
end
core.add_node = core.set_node
core.swap_node = function(pos, node) nodes[hash(pos)].name = node.name end
function core.remove_node(pos)
	local h = hash(pos)
	nodes[h], metas[h] = nil, nil
end
-- builtin core.item_place_node, reduced to what the packed item relies on:
-- the spot (above, or under when buildable_to), protection with the
-- violation, the node with on_construct, after_place_node, the take.
function core.item_place_node(itemstack, placer, pointed_thing)
	local def = itemstack:get_definition()
	if not def or not core.registered_nodes[def.name] or pointed_thing.type ~= "node" then
		return itemstack, nil
	end
	local under, above = pointed_thing.under, pointed_thing.above
	local under_def = core.registered_nodes[core.get_node(under).name] or {}
	local above_def = core.registered_nodes[core.get_node(above).name] or {}
	if not above_def.buildable_to and not under_def.buildable_to then return itemstack, nil end
	local place_to = vector.copy(under_def.buildable_to and under or above)
	if core.is_protected(place_to, placer:get_player_name()) then
		core.record_protection_violation(place_to, placer:get_player_name())
		return itemstack, nil
	end
	core.add_node(place_to, {name = def.name})
	if def.after_place_node then def.after_place_node(vector.copy(place_to), placer, itemstack, pointed_thing) end
	itemstack:take_item()
	return itemstack, place_to
end

local function item(name, def)
	def.name = name
	def.type = def.type or "craft"
	def.groups = def.groups or {}
	core.registered_items[name] = def
	return def
end
local function node(name, def)
	def.type = "node"
	item(name, def)
	core.registered_nodes[name] = def
	return def
end
function core.register_node(name, def)
	return node(name:gsub("^:", ""), def)
end
function core.register_craftitem(name, def) return item(name:gsub("^:", ""), def) end
node("air", {buildable_to = true})

------------------------------------------------------------------------------
-- The game around the code under test.
------------------------------------------------------------------------------
item("default:apple", {description = "Apple"})
item("default:torch", {description = "Torch"})
item("default:coal_lump", {description = "Coal Lump"})
item("grug_smelting:charcoal", {description = "Charcoal"})
item("default:iron_lump", {description = "Iron Lump"})
item("default:steel_ingot", {description = "Steel Ingot"})
item("default:book", {description = "Book", groups = {book = 1}})
item("default:book_written", {description = "Book With Text", stack_max = 1,
	groups = {book = 1}})
item("vessels:glass_bottle", {description = "Empty Glass Bottle", groups = {vessel = 1}})
item("t:sword", {description = "Bronze Sword", stack_max = 1})
-- A renamed item keeps its old name as an alias.
core.registered_aliases["old:apple"] = "default:apple"

-- The vendored chest and locked chest (default/chests.lua).
default = {
	get_translator = function(text, ...)
		local args = {...}
		return (text:gsub("@(%d)", function(i) return tostring(args[tonumber(i)]) end))
	end,
	set_inventory_action_loggers = function() end,
	node_sound_wood_defaults = function() return {} end,
	can_interact_with_node = function(player, pos)
		return player:get_player_name() == core.get_meta(pos):get_string("owner")
	end,
}
grug_inventory = {
	STATION = {x = 0.52, y = 0.78, pitch = 1.25, box_x = 0.4, box_w = 10.44, margin = 0.4},
	VIEW_GEOMETRY = {width = 9.75},
	BAG_COUNT = 4,
	station_box = function(label, inner_h)
		return "box[label=" .. label .. "]", 0.4 + 0.38 + inner_h + 0.12
	end,
	station_formspec = function(_, content) return content end,
	keep_scroll = function() return false end,
	content_list = function(i) return "grug_bag" .. i .. "_content" end,
}
function grug_inventory.carried_lists(inv)
	local lists = {"main"}
	for i = 1, 4 do
		if inv:get_size(grug_inventory.content_list(i)) > 0 then
			lists[#lists + 1] = grug_inventory.content_list(i)
		end
	end
	return lists
end
function grug_inventory.fits(player, stacks)
	local inv = player:get_inventory()
	local free = 0
	for _, list in ipairs(grug_inventory.carried_lists(inv)) do
		for _, stack in ipairs(inv:get_list(list)) do
			if stack:is_empty() then free = free + 1 end
		end
	end
	return free >= #stacks
end
function grug_inventory.give(player, stack)
	stack = ItemStack(stack)
	local inv = player:get_inventory()
	for _, list in ipairs(grug_inventory.carried_lists(inv)) do
		for index = 1, inv:get_size(list) do
			if inv:get_stack(list, index):is_empty() then
				inv:set_stack(list, index, stack)
				return ItemStack("")
			end
		end
	end
	return stack
end
dofile(ROOT .. "/mods/BASE/default/chests.lua")

-- The furnace, the bookshelf and the vessels shelf: stand-ins with the list
-- sizes their vendored on_construct sets.
local function source_sizes(path, anchor)
	local text = read(path)
	if anchor then
		local from = assert(text:find(anchor, 1, true), "anchor " .. anchor)
		text = text:sub(from, (text:find("\n}", from, true) or #text))
	end
	local sizes = {}
	for list, expr in text:gmatch("set_size%(%s*['\"]([%w_]+)['\"]%s*,%s*([%d%s%*]+)%)") do
		sizes[list] = assert(loadstring("return " .. expr))()
	end
	return sizes
end
local VENDORED = {
	["default:chest"] = source_sizes("mods/BASE/default/chests.lua"),
	["default:chest_locked"] = source_sizes("mods/BASE/default/chests.lua"),
	["default:furnace"] = source_sizes("mods/BASE/default/furnace.lua",
		'core.register_node("default:furnace",'),
	["default:bookshelf"] = source_sizes("mods/BASE/default/nodes.lua",
		"local default_bookshelf_def = {"),
	["vessels:shelf"] = source_sizes("mods/BASE/vessels/init.lua", "local vessels_shelf_def = {"),
}
local puts = {}
local function stand_in(name, def)
	def.description = def.description
	def.on_construct = function(pos)
		local inv = core.get_meta(pos):get_inventory()
		for list, size in pairs(VENDORED[name]) do inv:set_size(list, size) end
	end
	def.on_metadata_inventory_put = function(pos, listname)
		puts[#puts + 1] = name .. ":" .. listname
	end
	return node(name, def)
end
stand_in("default:furnace", {description = "Furnace", tiles = {"default_furnace_top.png",
	"default_furnace_bottom.png", "default_furnace_side.png", "default_furnace_side.png",
	"default_furnace_side.png", "default_furnace_front.png"}, on_timer = function() end})
node("default:furnace_active", {description = "Furnace", drop = "default:furnace",
	tiles = {"default_furnace_top.png"}})
stand_in("default:bookshelf", {description = "Bookshelf", tiles = {"default_wood.png",
	"default_wood.png", "default_wood.png", "default_wood.png", "default_bookshelf.png",
	"default_bookshelf.png"}})
stand_in("vessels:shelf", {description = "Vessels Shelf", tiles = {"default_wood.png",
	"default_wood.png", "default_wood.png", "default_wood.png", "vessels_shelf.png",
	"vessels_shelf.png"}})
node("t:anvil", {description = "Anvil", on_rightclick = function(_, _, _, itemstack)
	return itemstack
end})
node("t:stone", {description = "Stone"})

-- grug_core: the REAL world_version.lua (with an empty step registry) and
-- node_rightclick.lua; the feed and the flash record.
grug_core = {migrations = {versions = {}, handlers = {}},
	map_reset = {clear = function() end},
	severe = {report = function() end},
	flash = function(player, text) flashes[#flashes + 1] = {name = player:get_player_name(), text = text} end,
	feed = function(player, kind, text, key)
		feeds[#feeds + 1] = {name = player:get_player_name(), kind = kind, text = text, key = key}
		return true
	end,
	assign_service_socket = function() end,
	settlement_sockets_at = function() return {{id = "steward_socket", role = "housing_manager",
		pos = {x = 0, y = 0, z = 0}}} end,
}

-- The tool's pass 2 (§3), before the load: entries of two players, an
-- older pass 1, the counter and the marker. `lists` as the tool writes them.
local function packed_string(nodename, lists, seq)
	local stack = ItemStack("grug_housing:packed_container")
	stack.name = "grug_housing:packed_container" -- not registered yet
	stack.count = 1
	stack.meta.fields = {node = nodename, lists = "return " .. ser(lists), seq = tostring(seq)}
	return stack:to_string()
end
local BOOK = ItemStack("default:book_written")
BOOK.meta.fields = {title = "Letters", text = "Dear Ann,\nthe ore is yours.", owner = "ann",
	description = "\"Letters\" by ann"}
local BOOK_STRING = BOOK:to_string()
local SWORD = ItemStack("t:sword")
SWORD.meta.fields = {grug_quality = "rare", description = "Bronze Sword of the Bear"}
local SWORD_STRING = SWORD:to_string()

local chest_main = {}
for i = 1, 14 do chest_main[i] = "default:apple " .. i end
chest_main[3] = "gone:thing 5" -- removed in this version
chest_main[5] = BOOK_STRING
chest_main[6] = SWORD_STRING
chest_main[20] = "old:apple 2" -- an alias still counts
chest_main[21] = "" -- an empty slot as the tool may write it
local barrel = {}
for i = 1, 40 do barrel[i] = "default:torch " .. i end
local wide = {}
for i = 1, 40 do wide[i] = "default:coal_lump " .. i end

local housing = mod_storage("grug_housing")
local core_store = mod_storage("grug_core")
local SEED = {
	["recovered:ann:2:1"] = packed_string("default:chest", {main = chest_main}, 2),
	["recovered:ann:2:2"] = packed_string("default:chest_locked",
		{main = {"default:steel_ingot 7", [32] = "default:apple 1"}}, 2),
	["recovered:ann:2:3"] = packed_string("default:furnace_active", {src = {"default:iron_lump 30"},
		fuel = {"default:coal_lump 10"}, dst = {"default:steel_ingot 3", "", "", "gone:slag 2"}}, 2),
	["recovered:ann:2:4"] = packed_string("default:bookshelf",
		{books = {BOOK_STRING, "default:book 3", [16] = "default:book 1"}}, 2),
	["recovered:ann:2:5"] = packed_string("vessels:shelf", {vessels = {"vessels:glass_bottle 12"}}, 2),
	["recovered:ann:2:6"] = packed_string("gone:barrel", {stuff = barrel}, 2),
	["recovered:ann:2:7"] = packed_string("default:chest", {main = wide,
		hidden = {"default:apple 4"}}, 2),
	["recovered:ann:2:8"] = "grug_smelting:charcoal 150",
	["recovered:ann:2:9"] = "gone:coal 3",
	["recovered:ann:2:10"] = packed_string("gone:empty_barrel", {stuff = {}}, 2),
	["recovered:bob:2:1"] = packed_string("default:chest", {main = {"default:apple 9"}}, 2),
	-- An older pass the player never collected: kept as it is.
	["recovered:ann:1:1"] = packed_string("default:chest", {main = {"gone:relic 1"}}, 1),
	["pack_seq"] = "2",
}
for key, value in pairs(SEED) do housing:set_string(key, value) end
core_store:set_string("map_reset_pack:2", "1")
local SEED_SNAPSHOT = snapshot("grug_housing")

-- Load.
current_mod = "grug_core"
dofile(ROOT .. "/mods/CORE/grug_core/world_version.lua")
dofile(ROOT .. "/mods/CORE/grug_core/node_rightclick.lua")
grug_sounds = {play = function() end}
grug_factions = {get_faction = function() return "accord" end}
grug_mobs = {register_start_socket_role = function() end}
current_mod = "grug_housing"
grug_housing = {}
local HP = ROOT .. "/mods/PLAYER/grug_housing/"
for _, file in ipairs({"api.lua", "soulbound.lua", "packed.lua", "recovered.lua",
		"interface.lua"}) do
	dofile(HP .. file)
end
for _, fn in ipairs(mods_loaded) do fn() end
local H = grug_housing
local P, R = H.packed, H.recovered
local PACKED = P.ITEM

local function new_player(name, bag_size)
	local inv = new_inventory()
	inv:set_size("main", 32)
	inv:set_size("craft", 9)
	for i = 1, 4 do
		inv:set_size("grug_bag" .. i, 1)
		inv:set_size("grug_bag" .. i .. "_content", i == 1 and (bag_size or 8) or 0)
	end
	for _, list in ipairs({"grug_potion_belt", "grug_quiver_content", "grug_mail_out",
			"grug_inbox", "grug_equip_offhand"}) do
		inv:set_size(list, 4)
	end
	local p = {name = name, inv = inv, pos = {x = 0, y = 10, z = 0}, wield = ItemStack(""),
		meta = new_meta(), sneak = false}
	function p:is_player() return true end
	function p:get_player_name() return self.name end
	function p:get_inventory() return self.inv end
	function p:get_pos() return vector.copy(self.pos) end
	function p:get_meta() return self.meta end
	function p:get_hp() return 20 end
	function p:get_player_control() return {sneak = self.sneak} end
	function p:get_wielded_item() return ItemStack(self.wield) end
	players[name] = p
	return p
end
local function allow(p, action, info)
	for _, fn in ipairs(allow_player) do
		local answer = fn(p, action, p.inv, info)
		if answer ~= nil then return answer end
	end
	return nil
end
local function stored(key) return housing:get_string(key) end
local function stack_of(key) return ItemStack(stored(key)) end

------------------------------------------------------------------------------
-- B. The marker handler ran at the load.
------------------------------------------------------------------------------
do
	eq(core_store:get_string("map_reset_pack:2"), "", "B the marker is gone after the clean-up")
	-- The chest: the unknown item gone, the alias kept, the slots in place.
	local chest = stack_of("recovered:ann:2:1")
	eq(chest:get_name(), PACKED, "B the chest entry is a packed container")
	local lists = P.lists(chest)
	eq(lists.main[3], "", "B the unknown item left the chest")
	eq(lists.main[5], BOOK_STRING, "B the written book kept with its meta")
	eq(lists.main[6], SWORD_STRING, "B the quality sword kept with its meta")
	eq(lists.main[20], "old:apple 2", "B an alias counts as registered")
	eq(lists.main[1], "default:apple 1", "B the other slots unchanged")
	local description = chest:get_meta():get_string("description")
	has(description, "Packed Chest, 14 stacks", "B the chest's description counts its stacks")
	has(description, "Letters", "B ...and names the written book by its title")
	has(description, "Bronze Sword of the Bear", "B ...and the sword by its own name")
	has(description, "and 6 more", "B ...and counts what it does not list")
	has(description, "Soulbound", "B ...and says it is soulbound")
	eq(chest:get_meta():get_string("inventory_image"),
		"[inventorycube{default_chest_top.png{default_chest_front.png{default_chest_side.png&[transformFX",
		"B the chest's own look as the item image")
	-- The lit furnace comes back as the furnace (D7), the unknown slag gone.
	local furnace = stack_of("recovered:ann:2:3")
	eq(furnace:get_meta():get_string("node"), "default:furnace", "B a lit furnace packs as the furnace")
	eq(P.lists(furnace).dst[4], "", "B the unknown item left the furnace")
	has(furnace:get_meta():get_string("description"), "Packed Furnace, 3 stacks",
		"B the furnace's description")
	eq(furnace:get_meta():get_string("inventory_image"),
		"[inventorycube{default_furnace_top.png{default_furnace_front.png{default_furnace_side.png",
		"B the furnace's look")
	-- D6: the unknown node's 40 stacks fill a chest and an additional one.
	local barrel1, barrel2 = stack_of("recovered:ann:2:6"), stack_of("recovered:ann:2:6.1")
	eq(barrel1:get_meta():get_string("node"), "default:chest", "B D6 an unknown node becomes a chest")
	eq(#P.stacks(P.lists(barrel1)), 32, "B D6 ...filled to its size")
	eq(#P.stacks(P.lists(barrel2)), 8, "B D6 ...the rest in an additional chest")
	eq(P.lists(barrel2).main[8], "default:torch 40", "B D6 ...in the packed order")
	eq(stored("recovered:ann:2:6.2"), "", "B D6 no third chest")
	-- D6: a list bigger than the chest's, and a list the chest lacks.
	local wide1, wide2 = stack_of("recovered:ann:2:7"), stack_of("recovered:ann:2:7.1")
	eq(#P.stacks(P.lists(wide1)), 32, "B D6 a shrunken list keeps the node's size")
	eq(P.lists(wide1).hidden, nil, "B D6 a list the node lacks goes")
	eq(#P.stacks(P.lists(wide2)), 9, "B D6 the 8 stacks beyond and the lacking list's one")
	has(wide2:get_meta():get_string("description"), "Packed Chest, 9 stacks",
		"B D6 the additional chest is described")
	-- Charcoal above its stack size splits; unknown and empty entries go.
	eq(stored("recovered:ann:2:8"), "grug_smelting:charcoal 99", "B charcoal: one full stack")
	eq(stored("recovered:ann:2:8.1"), "grug_smelting:charcoal 51", "B charcoal: the rest")
	eq(stored("recovered:ann:2:9"), "", "B an unknown plain item goes")
	eq(stored("recovered:ann:2:10"), "", "B an empty unknown container goes")
	eq(stored("recovered:ann:1:1"), SEED["recovered:ann:1:1"], "B an older pass is not touched")
	eq(stored("pack_seq"), "2", "B the pass counter is the tool's")
	-- The order of the stone's slots: passes, then entries, then their parts.
	local order = {}
	for _, entry in ipairs(R.entries("ann")) do order[#order + 1] = entry.key:match("ann:(.*)$") end
	eq(table.concat(order, " "), "1:1 2:1 2:2 2:3 2:4 2:5 2:6 2:6.1 2:7 2:7.1 2:8 2:8.1",
		"B the entries in slot order")
	eq(R.count("bob"), 1, "B the other player's entry")

	-- A rerun changes nothing; nor does a rerun over a half-done pass.
	local done = snapshot("grug_housing")
	R.clean_pass(2)
	eq(snapshot("grug_housing"), done, "B a rerun writes the same")
	housing:set_string("recovered:ann:2:6", SEED["recovered:ann:2:6"])
	housing:set_string("recovered:ann:2:8", SEED["recovered:ann:2:8"])
	R.clean_pass(2)
	eq(snapshot("grug_housing"), done, "B a rerun over a half-done pass writes the same")
	-- A marker left by a failed start runs again through grug_core's runner.
	core_store:set_string("map_reset_pack:2", "1")
	grug_core.world_version.run_packs(core_store)
	eq(core_store:get_string("map_reset_pack:2"), "", "B the runner runs a pending marker again")
	eq(snapshot("grug_housing"), done, "B ...and changes nothing")
	check(SEED_SNAPSHOT ~= done, "B the load did clean the seeded pass")
end

------------------------------------------------------------------------------
-- C. The map reset's clear and the vendored list sizes.
------------------------------------------------------------------------------
do
	H.model.issue("ann", 30, false)
	H.model.create("ann", {x = 500, y = 10, z = 500})
	local before = {}
	for key, value in pairs(storages.grug_housing) do
		if key:match("^recovered:") or key == "pack_seq" then before[key] = value end
	end
	H.model.map_reset()
	local same, count = true, 0
	for key, value in pairs(before) do
		count = count + 1
		if storages.grug_housing[key] ~= value then same = false end
	end
	check(same and count > 10, "C M.map_reset leaves every recovered entry and pack_seq")
	eq(H.model.claim_count(), 0, "C ...and clears the claims")
	for name, sizes in pairs(P.CONTAINER_LISTS) do
		eq(ser(sizes), ser(VENDORED[name]), "C " .. name .. ": the list sizes of its on_construct")
	end
end

------------------------------------------------------------------------------
-- A. The guards.
------------------------------------------------------------------------------
do
	local p = new_player("guard", 8)
	local item = ItemStack(stored("recovered:bob:2:1"))
	eq(core.get_item_group(PACKED, "grug_soulbound"), 1, "A the packed item is soulbound")
	p.inv:set_stack("main", 1, item)
	p.inv:set_stack("grug_bag1_content", 2, item)
	for _, list in ipairs({"main", "grug_bag1_content"}) do
		eq(allow(p, "move", {from_list = "main", from_index = 1, to_list = list, to_index = 3,
			count = 1}), nil, "A moves into " .. list)
		eq(allow(p, "put", {listname = list, index = 4, stack = item}), nil, "A a put into " .. list)
	end
	for _, list in ipairs({"craft", "grug_bag1", "grug_potion_belt", "grug_quiver_content",
			"grug_mail_out", "grug_inbox", "grug_equip_offhand"}) do
		eq(allow(p, "move", {from_list = "grug_bag1_content", from_index = 2, to_list = list,
			to_index = 1, count = 1}), 0, "A refused: a bag to " .. list)
		eq(allow(p, "put", {listname = list, index = 1, stack = item}), 0, "A refused: a put into " .. list)
	end
	eq(core.registered_nodes["default:chest"].allow_metadata_inventory_put({x = 1, y = 1, z = 1},
		"main", 1, item, p), 0, "A a chest refuses it")
	eq(core.registered_nodes["default:furnace"].allow_metadata_inventory_put({x = 1, y = 1, z = 1},
		"fuel", 1, item, p), 0, "A a station refuses it")
	core.create_detached_inventory("trade", {allow_put = function() return 5 end})
	eq(detached.trade.callbacks.allow_put(detached.trade.inv, "give", 1, item, p), 0,
		"A a trade refuses it")
	has(read("mods/ENTITIES/grug_traders/prices.lua"),
		'NEVER_GROUPS = {"grug_soulbound"', "A the vendors never buy a soulbound item")
	local inbox = read("mods/PLAYER/grug_inventory/inbox.lua")
	has(inbox, 'core.get_item_group(name, "grug_soulbound") > 0', "A the inbox refuses soulbound items")
	local def = core.registered_items[PACKED]
	local kept = def.on_drop(ItemStack(item), p, p:get_pos())
	eq(kept:to_string(), item:to_string(), "A dropping is refused: the item stays")
	has(flashes[#flashes].text, "cannot be dropped", "A ...and the player is told")
end

------------------------------------------------------------------------------
-- D. The Claim Stone inventory.
------------------------------------------------------------------------------
local function submit(p, fields)
	for _, fn in ipairs(receive) do
		if fn(p, "grug_housing:stone", fields) then return end
	end
end
local function recovered_inv(name) return detached["grug_housing_recovered_" .. name] end
-- The engine's take: the detached slot into a player slot (no swap: the
-- stone's list takes nothing back), the player's put rules, allow_take,
-- the move, on_take.
local function engine_take(p, index, count, to_list, to_index)
	local d = recovered_inv(p.name)
	local src = d.inv:get_stack("recovered", index)
	if src:is_empty() then return 0 end
	count = math.min(count or src:get_count(), src:get_count())
	local part = ItemStack(src)
	part.count = count
	local dst = p.inv:get_stack(to_list, to_index)
	if not dst:is_empty() and (dst:get_name() ~= part:get_name() or
			dst:get_count() + count > dst:get_stack_max() or
			dst:to_string():find(" 0 ", 1, true)) then
		return 0
	end
	if allow(p, "put", {listname = to_list, index = to_index, stack = part}) == 0 then return 0 end
	local can = d.callbacks.allow_take(d.inv, "recovered", index, part, p)
	if can == 0 then return 0 end
	count = math.min(count, can)
	src:take_item(count)
	d.inv:set_stack("recovered", index, src)
	local moved = ItemStack(part)
	moved.count = count + (dst:is_empty() and 0 or dst:get_count())
	p.inv:set_stack(to_list, to_index, moved)
	local reported = ItemStack(part)
	reported.count = count
	d.callbacks.on_take(d.inv, "recovered", index, reported, p)
	return count
end
local function slot(name, index)
	return recovered_inv(name).inv:get_stack("recovered", index):to_string()
end

local claim
do
	local ann = new_player("ann", 8)
	ann.pos = {x = 100, y = 11, z = 100}
	grug_home = nil
	-- A draft: no Belongings tab, no take.
	H.model.issue("ann", 30, false)
	claim = H.model.create("ann", {x = 100, y = 10, z = 100})
	nodes[hash(claim.center)] = {name = H.DRAFT_STONE}
	H.open_stone_interface(ann, claim)
	local fs = last_shown("ann").fs
	has(fs, "not active", "D a draft shows the draft form")
	lacks(fs, "Belongings", "D ...without the Claim Stone inventory")
	submit(ann, {stone_tab = "2"})
	lacks(last_shown("ann").fs, "Belongings", "D ...also after a tab click")
	if recovered_inv("ann") then
		eq(recovered_inv("ann").callbacks.allow_take(recovered_inv("ann").inv, "recovered", 1,
			ItemStack("default:apple"), ann), 0, "D a draft's stone takes nothing")
	end

	-- Activated: the tab, its count, the entries in their order.
	H.model.activate(claim, 5)
	H.open_stone_interface(ann, claim)
	fs = last_shown("ann").fs
	has(fs, "tabheader[0,0;stone_tab;Claim Stone,Belongings (12);1;false;false]",
		"D the active stone's form has the Belongings tab with the count")
	eq(engine_take(ann, 1, 1, "main", 9), 0, "D the main tab takes nothing")
	submit(ann, {stone_tab = "2"})
	fs = last_shown("ann").fs
	has(fs, "list[detached:grug_housing_recovered_ann;recovered;0,0;8,2;]",
		"D the Claim Stone inventory, two rows")
	has(fs, "listring[detached:grug_housing_recovered_ann;recovered]listring[current_player;main]",
		"D shift-click takes into the inventory")
	has(fs, "Belongings from the old map", "D the box's label")
	lacks(fs, "scrollbar[", "D two rows need no scrollbar")
	eq(recovered_inv("ann").inv:get_size("recovered"), 16, "D the list rounded up to whole rows")
	eq(slot("ann", 1), stored("recovered:ann:1:1"), "D slot 1: the older pass first")
	eq(slot("ann", 12), "grug_smelting:charcoal 51", "D slot 12: the charcoal's rest")

	-- Take-only: no put, no move.
	local callbacks = recovered_inv("ann").callbacks
	eq(callbacks.allow_put(recovered_inv("ann").inv, "recovered", 13, ItemStack("default:apple"), ann),
		0, "D nothing goes in")
	eq(callbacks.allow_move(recovered_inv("ann").inv, "recovered", 1, "recovered", 13, 1, ann),
		0, "D nothing moves inside")

	-- A packed chest into the hotbar: the entry goes, the slots close up.
	local key2 = "recovered:ann:2:1"
	local chest = stored(key2)
	eq(engine_take(ann, 2, 1, "main", 1), 1, "D a packed chest taken onto the hotbar")
	eq(ann.inv:get_stack("main", 1):to_string(), chest, "D ...exactly the entry's item")
	eq(stored(key2), "", "D ...and its entry is gone")
	run_afters()
	eq(slot("ann", 2), stored("recovered:ann:2:2"), "D the slots close up after the take")
	has(last_shown("ann").fs, "Belongings (11)", "D the count follows")

	-- Part of the charcoal into a bag: the entry keeps the rest.
	eq(engine_take(ann, 10, 30, "grug_bag1_content", 1), 30, "D 30 charcoal into the bag")
	eq(stored("recovered:ann:2:8"), "grug_smelting:charcoal 69", "D the entry keeps 69")
	eq(ann.inv:get_stack("grug_bag1_content", 1):to_string(), "grug_smelting:charcoal 30",
		"D ...the bag holds 30")
	run_afters()

	-- Refused: into the mail, a stale slot, a full slot, a closed form.
	eq(engine_take(ann, 2, 1, "grug_mail_out", 1), 0, "D a packed item never goes into the mail")
	local stale = stored("recovered:ann:2:2")
	housing:set_string("recovered:ann:2:2", "default:apple 1")
	eq(engine_take(ann, 2, 1, "main", 2), 0, "D a slot that no longer holds its entry takes nothing")
	housing:set_string("recovered:ann:2:2", stale)
	ann.inv:set_stack("main", 2, ItemStack("default:torch 5"))
	eq(engine_take(ann, 2, 1, "main", 2), 0, "D a full slot takes nothing")
	eq(stored("recovered:ann:2:2"), stale, "D ...and the entry stays")
	core.show_formspec("ann", "other:form", "size[1,1]")
	eq(engine_take(ann, 3, 1, "main", 3), 0, "D with another form open nothing is taken")
	eq(ann.inv:get_stack("main", 3):to_string(), "", "D ...and nothing arrives")

	-- Picking the stone up and losing it leave the entries.
	local count = R.count("ann")
	H.open_stone_interface(ann, claim)
	H.model.remove(claim, "picked_up")
	eq(R.count("ann"), count, "D picking the stone up keeps the entries")
	H.model.stone_lost("ann")
	eq(R.count("ann"), count, "D losing the stone keeps the entries")
	H.model.issue("ann", 30, false)
	claim = H.model.create("ann", {x = 100, y = 10, z = 100})
	H.model.activate(claim, 5)
	H.open_stone_interface(ann, claim)
	has(last_shown("ann").fs, ("Belongings (%d)"):format(count), "D a new active stone shows them again")
end

------------------------------------------------------------------------------
-- E. Placing: every kind with exact contents.
------------------------------------------------------------------------------
do
	local ann = players.ann
	local function place(stack, at)
		local def = core.registered_items[PACKED]
		local below = {x = at.x, y = at.y - 1, z = at.z}
		nodes[hash(below)] = nodes[hash(below)] or {name = "t:stone"}
		return def.on_place(ItemStack(stack), ann, {type = "node", under = below, above = at})
	end
	local function lists_at(pos)
		local result = {}
		for listname, list in pairs(core.get_meta(pos):get_inventory():get_lists()) do
			local items = {}
			for index, stack in ipairs(list) do
				if not stack:is_empty() then items[index] = stack:to_string() end
			end
			result[listname] = items
		end
		return result
	end
	local function packed_items(stack)
		local result = {}
		for listname, list in pairs(P.lists(stack)) do
			local items = {}
			for index, text in pairs(list) do
				if text ~= "" then items[index] = ItemStack(text):to_string() end
			end
			result[listname] = items
		end
		return result
	end
	local kinds = {
		{"recovered:ann:2:2", "default:chest_locked"},
		{"recovered:ann:2:3", "default:furnace"},
		{"recovered:ann:2:4", "default:bookshelf"},
		{"recovered:ann:2:5", "vessels:shelf"},
		{"recovered:ann:2:6", "default:chest"},
	}
	for index, kind in ipairs(kinds) do
		local stack = ItemStack(stored(kind[1]))
		local at = {x = 10 * index, y = 5, z = 0}
		puts = {}
		local left = place(stack, at)
		eq(left:get_count(), 0, "E " .. kind[2] .. ": the packed item is used")
		eq(core.get_node(at).name, kind[2], "E " .. kind[2] .. ": the node stands")
		eq(ser(lists_at(at)), ser(packed_items(stack)), "E " .. kind[2] .. ": exactly its contents")
		if kind[2] == "default:chest_locked" then
			eq(core.get_meta(at):get_string("owner"), "ann", "E the locked chest belongs to the placer")
		elseif kind[2] == "default:furnace" then
			eq(#puts, 0, "E the furnace stays unlit until it is touched (D7)")
		elseif kind[2] == "default:bookshelf" then
			eq(puts[1], "default:bookshelf:books", "E the shelf counts its books (its put callback)")
			eq(core.get_meta(at):get_inventory():get_stack("books", 1):get_meta():get_string("text"),
				"Dear Ann,\nthe ore is yours.", "E the written book's text is intact")
		end
	end
	-- The chest of the first test, with its quality sword.
	local chest = ann.inv:get_stack("main", 1)
	local at = {x = 70, y = 5, z = 0}
	eq(place(chest, at):get_count(), 0, "E the packed chest is used")
	eq(core.get_meta(at):get_inventory():get_stack("main", 6):to_string(), SWORD_STRING,
		"E the sword keeps its quality meta")
	eq(core.get_meta(at):get_inventory():get_stack("main", 20):to_string(), "default:apple 2",
		"E the alias resolves")

	-- Failed placements keep the item.
	local spare = ItemStack(stored("recovered:ann:2:7"))
	local spot = {x = 80, y = 5, z = 0}
	protected[hash(spot)] = true
	eq(place(spare, spot):to_string(), spare:to_string(), "E a protected spot keeps the item")
	eq(core.get_node(spot).name, "air", "E ...and places nothing")
	protected[hash(spot)] = nil
	nodes[hash(spot)] = {name = "t:stone"}
	local def = core.registered_items[PACKED]
	local kept = def.on_place(ItemStack(spare), ann, {type = "node",
		under = {x = 80, y = 4, z = 0}, above = spot})
	eq(kept:to_string(), spare:to_string(), "E an occupied spot keeps the item")
	-- Right-clicking a station opens it, the item stays.
	nodes[hash({x = 90, y = 5, z = 0})] = {name = "t:anvil"}
	kept = def.on_place(ItemStack(spare), ann, {type = "node", under = {x = 90, y = 5, z = 0},
		above = {x = 90, y = 6, z = 0}})
	eq(kept:to_string(), spare:to_string(), "E a click on a station opens it and keeps the item")
	-- A packed list that no longer fits (no clean-up in between): refused.
	local misfit = P.make("default:furnace", {dst = {"", "", "", "", "default:steel_ingot 1"}}, 2)
	local mspot = {x = 100, y = 5, z = 30}
	eq(place(misfit, mspot):to_string(), misfit:to_string(), "E contents that do not fit: kept")
	eq(core.get_node(mspot).name, "air", "E ...and the node is taken back")
	-- A node this version cannot restore (never after the clean-up): kept.
	local unknown = P.make("gone:barrel", {stuff = {"default:apple 1"}}, 2)
	eq(place(unknown, {x = 110, y = 5, z = 30}):to_string(), unknown:to_string(),
		"E an unknown node: kept")
end

------------------------------------------------------------------------------
-- F. The join notice and the Housing Steward.
------------------------------------------------------------------------------
do
	feeds = {}
	local ann = players.ann
	local carl = new_player("carl", 8)
	for _, fn in ipairs(joins) do fn(ann) end
	for _, fn in ipairs(joins) do fn(carl) end
	run_afters()
	eq(#feeds, 1, "F one notice, only for the player with waiting belongings")
	eq(feeds[1] and feeds[1].text, "Belongings from the old map wait in your Claim Stone.",
		"F the notice's wording")
	eq(feeds[1] and feeds[1].name, "ann", "F ...to that player")
	local entity = {_grug_socket_role = "housing_manager", _grug_start = "highcourt",
		_grug_socket = "steward_socket", object = {get_pos = function() return {x = 0, y = 0, z = 0} end}}
	ann.pos, carl.pos = {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0}
	check(H.open_manager(ann, entity), "F the Steward talks to ann")
	has(last_shown("ann").fs, "Belongings from the old map wait in your Claim Stone.",
		"F the Steward says the same")
	check(H.open_manager(carl, entity), "F the Steward talks to carl")
	lacks(last_shown("carl").fs, "Belongings", "F ...and says nothing of it to a player without")
	has(last_shown("carl").fs, "size[10.5,6.8]", "F ...in the form's old size")
end

if failures > 0 then
	error(("R50 PGAME PORTABLE FAIL checks=%d failures=%d"):format(checks, failures), 0)
end
print(("R50 PGAME PORTABLE PASS checks=%d"):format(checks))
