-- Round 45 lane EU portable test (LuaJIT): enchants and upgrades as crafting
-- jobs (round45-plan.md §4.6; ui-crafting-rework-plan.md §2.24, §2.26,
-- §2.30-2.32, §4.3, §4.6).
--
--   luajit tools/r45_eu/portable_test.lua [REPO]
--
-- Loads the REAL grug_gear and grug_quality (init.lua), the vendored sfinv,
-- grug_inventory's bags.lua (the give helper and the fit check) and ui.lua
-- (the frame), the REAL grug_jobs registry.lua, state.lua, jobs.lua,
-- overview.lua, ui.lua, craft_box.lua, operation_jobs.lua,
-- operation_box.lua and station_operations.lua, and the REAL enchant and
-- upgrade registrations (grug_professions enchants.lua with its data files,
-- grug_artisans enchants.lua) under a stub engine with a wall clock,
-- core.after and an ItemStack double whose metadata survives itemstrings.
-- Checks:
--   D  the data: 588 enchants and 36 upgrades, enchants count as progress
--      and upgrades never, one own material per upgrade level, a Stick on
--      top for weapons, upgrades.json equals the data design's copy;
--   A  the allow chain goes on after an accepted item; an item left in the
--      slot comes back at join and at an unlearn (give helper, output
--      area, else it stays);
--   T  the target slot: made at join, takes one piece of equipment only,
--      placing or taking resends the open Crafting page once; the buttons
--      only in a learned primary area; tab and row clicks leave the box;
--   E  enchanting: the list holds exactly the valid enchants up to the
--      profession tier (family, item tier, channels, "would not change"),
--      the preview equals the result, 5 s, the item lives only in the job,
--      cancel returns the exact item and the materials, the overwrite
--      warning, the station, no output space, a target changed between the
--      preview and the click is judged again, a refused begin gives
--      everything back, XP as a counting craft (one per job, none below the
--      tier, none after an unlearn), a restart in the middle of a job and a
--      login after its end;
--   U  upgrades: +N and Max to the cap 10 x tier, the materials limit Max,
--      the profession-tier rule (a T2 smith raises a T1 item to 10 at most,
--      never a T3 item), the cost per level (a weapon also a Stick), 1 s per
--      level, enchants follow, the warning's two-step and its yellow
--      "Upgrade anyway", "Already at the cap" (an upgraded, a crowned and a
--      boss item; never a negative +N), lowering above the maximum, no XP,
--      cancel;
--   P  the boxes inside the crafting column and above the view, balanced
--      brackets, the bytes against the recipe box (printed);
--   H  the Help lines on enchants, upgrades and stations.
-- Prints "R45 EU PORTABLE PASS checks=<n>" or the failures (exit 1).

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
		label .. " (found " .. needle .. ")")
end
local function read_file(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"), "cannot read " .. path)
	local text = handle:read("*a")
	handle:close()
	return text
end
-- The data files are plain JSON with identifier keys: enough for a Lua table.
local function decode_json(text)
	local lua = text:gsub("%[", "{"):gsub("%]", "}"):gsub('"([%w_]+)"%s*:', "%1 =")
	return assert(loadstring("return " .. lua))()
end
function table.copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, child in pairs(value) do out[key] = table.copy(child) end
	return out
end

------------------------------------------------------------------------------
-- Clock: real time in seconds; os.time() is its floor; the microsecond
-- counter starts at 0 with each server process.
------------------------------------------------------------------------------
local real, process_start = 1700000000.4, 1700000000.4
os.time = function() return math.floor(real) end
local afters = {}
local function advance(seconds) real = real + seconds end
local function run_timers()
	local ran = true
	while ran do
		ran = false
		table.sort(afters, function(a, b) return a.at < b.at end)
		for index, entry in ipairs(afters) do
			if entry.at <= real + 0.00001 then
				table.remove(afters, index)
				entry.fn()
				ran = true
				break
			end
		end
	end
end
local function pass(seconds)
	advance(seconds)
	run_timers()
end

------------------------------------------------------------------------------
-- Engine surface.
------------------------------------------------------------------------------
local callbacks = {allow = {}, join = {}, leave = {}, loaded = {}, receive = {}, action = {}}
local loading = "?"
local online, nodes, feed_lines, sounds = {}, {}, {}, {}
local function serialize(value)
	local kind = type(value)
	if kind == "table" then
		local keys = {}
		for key in pairs(value) do keys[#keys + 1] = key end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		local parts = {}
		for _, key in ipairs(keys) do
			parts[#parts + 1] = "[" .. serialize(key) .. "]=" .. serialize(value[key])
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif kind == "string" then
		return ("%q"):format(value)
	elseif kind == "number" then
		return ("%.17g"):format(value)
	end
	return tostring(value)
end
local function fs_escape(text)
	return (tostring(text):gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
		:gsub(";", "\\;"):gsub(",", "\\,"):gsub("%$", "\\$"))
end
local modpaths = {
	grug_gear = ROOT .. "/mods/ITEMS/grug_gear",
	grug_quality = ROOT .. "/mods/ITEMS/grug_quality",
}
local current_mod = "grug_inventory"
core = {
	registered_items = {},
	registered_nodes = {},
	formspec_escape = fs_escape,
	colorize = function(color, text) return "\27(c@" .. color .. ")" .. text .. "\27(c@#ffffff)" end,
	strip_colors = function(text) return (text:gsub("\27%(c@#%x+%)", "")) end,
	get_item_group = function(name, group)
		local def = core.registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end,
	register_allow_player_inventory_action = function(f) table.insert(callbacks.allow, f) end,
	register_on_player_inventory_action = function(f) table.insert(callbacks.action, f) end,
	register_on_joinplayer = function(f) table.insert(callbacks.join, f) end,
	register_on_leaveplayer = function(f) table.insert(callbacks.leave, f) end,
	register_on_mods_loaded = function(f) table.insert(callbacks.loaded, {fn = f, file = loading}) end,
	register_on_player_receive_fields = function(f) table.insert(callbacks.receive, f) end,
	register_craftitem = function(name, def)
		def.type = "craft"
		core.registered_items[name] = def
	end,
	register_tool = function(name, def)
		def.type = "tool"
		def.stack_max = 1
		core.registered_items[name] = def
	end,
	override_item = function(name, fields)
		for key, value in pairs(fields) do core.registered_items[name][key] = value end
	end,
	get_modpath = function(name)
		return modpaths[name] or (ROOT .. "/mods/PLAYER/" .. (name or "grug_inventory"))
	end,
	get_current_modname = function() return current_mod end,
	is_creative_enabled = function() return false end,
	log = function() end,
	chat_send_player = function() end,
	add_item = function(_, stack) error("an item was dropped at a player's feet: " ..
		ItemStack(stack):to_string()) end,
	handle_node_drops = function() end,
	get_us_time = function() return math.floor((real - process_start) * 1000000) end,
	after = function(delay, fn) afters[#afters + 1] = {at = real + delay, fn = fn} end,
	get_player_by_name = function(name) return online[name] end,
	get_connected_players = function() return {} end,
	serialize = function(value) return "return " .. serialize(value) end,
	deserialize = function(text)
		if type(text) ~= "string" then return nil end
		local fn = loadstring(text)
		if not fn then return nil end
		setfenv(fn, {})
		local ok, value = pcall(fn)
		return ok and value or nil
	end,
	find_nodes_in_area = function(minp, maxp, names)
		local wanted, found = {}, {}
		for _, name in ipairs(names) do wanted[name] = true end
		for _, node in ipairs(nodes) do
			local p = node.pos
			if wanted[node.name] and p.x >= minp.x and p.x <= maxp.x and
					p.y >= minp.y and p.y <= maxp.y and p.z >= minp.z and p.z <= maxp.z then
				found[#found + 1] = p
			end
		end
		return found
	end,
	get_translator = function() return function(text) return text end end,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
minetest = core
dump = function(value) return tostring(value) end
vector = {
	offset = function(pos, x, y, z) return {x = pos.x + x, y = pos.y + y, z = pos.z + z} end,
	round = function(pos)
		return {x = math.floor(pos.x + 0.5), y = math.floor(pos.y + 0.5),
			z = math.floor(pos.z + 0.5)}
	end,
}
PcgRandom = function(seed)
	local state = seed % 2147483647
	if state == 0 then state = 1 end
	local function step() state = (state * 48271) % 2147483647 end
	step(); step(); step()
	return {next = function(_, low, high)
		step()
		return low + state % (high - low + 1)
	end}
end

------------------------------------------------------------------------------
-- ItemStack double: name, count, wear and metadata; an itemstring carries
-- the metadata (escaped), so a stored job target comes back exactly; stacks
-- merge only when name, wear and metadata are identical; a tool itemstring
-- reads as one item (as the engine's).
------------------------------------------------------------------------------
local Meta = {}
Meta.__index = Meta
function Meta:get_int(key) return math.floor(tonumber(self.fields[key]) or 0) end
function Meta:get_string(key) return self.fields[key] or "" end
function Meta:set_int(key, value) self.fields[key] = tostring(value) end
function Meta:set_string(key, value) self.fields[key] = value ~= "" and value or nil end
function Meta:get_keys()
	local keys = {}
	for key in pairs(self.fields) do keys[#keys + 1] = key end
	return keys
end
function Meta:set_tool_capabilities(caps)
	self.fields.tool_capabilities = caps and serialize(caps) or nil
end
local function encode(text)
	return (text:gsub("[%%;=%s]", function(c) return ("%%%02X"):format(c:byte()) end))
end
local function decode(text)
	return (text:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end
local function meta_string(fields)
	local keys = {}
	for key in pairs(fields) do keys[#keys + 1] = key end
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do parts[#parts + 1] = encode(key) .. "=" .. encode(fields[key]) end
	return table.concat(parts, ";")
end
local Stack = {}
Stack.__index = Stack
function ItemStack(item)
	local self = setmetatable({fields = {}}, Stack)
	if type(item) == "table" then
		self.name, self.count, self.wear = item.name, item.count, item.wear
		for key, value in pairs(item.fields or {}) do self.fields[key] = value end
		return self
	end
	local name, count, wear, meta = tostring(item or ""):match("^(%S*)%s*(%d*)%s*(%d*)%s*(.*)$")
	self.name = name or ""
	self.count = self.name == "" and 0 or (tonumber(count) or 1)
	local def = core.registered_items[self.name]
	if def and def.type == "tool" and self.count > 1 then self.count = 1 end
	self.wear = tonumber(wear) or 0
	for key, value in (meta or ""):gmatch("([^=;]+)=([^;]*)") do
		self.fields[decode(key)] = decode(value)
	end
	return self
end
function Stack:get_name() return self.count > 0 and self.name or "" end
function Stack:get_count() return self.count end
function Stack:is_empty() return self.count <= 0 or self.name == "" end
function Stack:get_wear() return self.wear end
function Stack:get_definition() return core.registered_items[self.name] end
function Stack:get_stack_max()
	local def = core.registered_items[self.name]
	return def and def.stack_max or 99
end
function Stack:get_meta() return setmetatable({fields = self.fields}, Meta) end
function Stack:get_tool_capabilities()
	local own = self.fields.tool_capabilities
	if own then return core.deserialize("return " .. own) end
	return (core.registered_items[self.name] or {}).tool_capabilities
end
function Stack:set_count(c)
	self.count = c
	if c <= 0 then self.name, self.count, self.fields = "", 0, {} end
end
function Stack:take_item(c)
	c = math.min(c or 1, self.count)
	local taken = ItemStack(self)
	taken:set_count(c)
	self:set_count(self.count - c)
	return taken
end
local function compatible(a, b)
	return a.name == b.name and a.wear == b.wear and
		meta_string(a.fields) == meta_string(b.fields)
end
function Stack:add_item(other)
	other = ItemStack(other)
	if other:is_empty() then return other end
	if self:is_empty() then
		local fit = math.min(other.count, ItemStack(other):get_stack_max())
		self.name, self.count, self.wear = other.name, fit, other.wear
		self.fields = {}
		for key, value in pairs(other.fields) do self.fields[key] = value end
		other:set_count(other.count - fit)
		return other
	end
	if not compatible(self, other) then return other end
	local fit = math.max(0, math.min(other.count, self:get_stack_max() - self.count))
	self.count = self.count + fit
	other:set_count(other.count - fit)
	return other
end
function Stack:to_string()
	if self:is_empty() then return "" end
	local meta = meta_string(self.fields)
	return self.name .. " " .. self.count .. " " .. self.wear .. (meta ~= "" and " " .. meta or "")
end
-- The same item: name, count, wear and every metadata field.
local function same_item(a, b)
	return a:get_name() == b:get_name() and a:get_count() == b:get_count() and
		compatible(a, b)
end
-- The same item handed back through the give helper, which adds a weapon's
-- "Effective at level" line to its tooltip (grug_gear's pickup setup).
local function returned_item(back, item)
	if not back or back:get_name() ~= item:get_name() or back:get_count() ~= item:get_count() or
			back:get_wear() ~= item:get_wear() then
		return false
	end
	local a, b = {}, {}
	for key, value in pairs(back.fields) do a[key] = value end
	for key, value in pairs(item.fields) do b[key] = value end
	local desc_a, desc_b = a.description or "", b.description or ""
	a.description, b.description = nil, nil
	return meta_string(a) == meta_string(b) and desc_a:sub(1, #desc_b) == desc_b
end

local function new_inventory()
	local inv = {lists = {}}
	function inv:set_size(list, size)
		local old = self.lists[list] or {}
		local new = {}
		for i = 1, size do new[i] = old[i] or ItemStack("") end
		self.lists[list] = new
	end
	function inv:get_size(list) return #(self.lists[list] or {}) end
	function inv:get_stack(list, i)
		local l = self.lists[list]
		return ItemStack(l and l[i] or "")
	end
	function inv:set_stack(list, i, stack) self.lists[list][i] = ItemStack(stack) end
	function inv:get_list(list)
		local l = self.lists[list]
		if not l then return nil end
		local out = {}
		for i = 1, #l do out[i] = ItemStack(l[i]) end
		return out
	end
	function inv:is_empty(list)
		for _, s in ipairs(self.lists[list] or {}) do
			if not s:is_empty() then return false end
		end
		return true
	end
	function inv:add_item(list, stack)
		stack = ItemStack(stack)
		local l = self.lists[list]
		for pass_no = 1, 2 do
			for i = 1, #l do
				if not stack:is_empty() and ((pass_no == 1 and not l[i]:is_empty()) or
						(pass_no == 2 and l[i]:is_empty())) then
					stack = l[i]:add_item(stack)
				end
			end
		end
		return stack
	end
	return inv
end

------------------------------------------------------------------------------
-- Mod surface.
------------------------------------------------------------------------------
local character_level = 25
local function permissive(base)
	return setmetatable(base, {__index = function() return function() end end})
end
grug_core = permissive({
	feed = function(_, _, text)
		feed_lines[#feed_lines + 1] = text
		return true
	end,
	item_name = function(item)
		local name = type(item) == "string" and item or item:get_name()
		local def = core.registered_items[name:match("^%S*")]
		return def and (def.description or name):match("^[^\n]*") or name
	end,
	level_scale = function() return 1 end,
	plain_text = function(text) return (tostring(text or ""):gsub("\27%([^)]*%)", "")) end,
	get_player_level = function() return character_level end,
})
grug_classes = permissive({get_class = function() return "warrior" end,
	get_melee_bonus = function() return 0 end, pool_percent_amount = function() return 42 end})
grug_mobs = permissive({})
grug_xp = {get_level = function() return character_level end}
grug_sounds = {play = function(event) sounds[#sounds + 1] = event end, CLICK_STYLE = ""}

grug_inventory = {}
loading = "sfinv"
dofile(ROOT .. "/mods/BASE/sfinv/api.lua")
sfinv.register_page("sfinv:crafting", {title = "Crafting", get = function() return "" end})
sfinv.register_page("grug_inventory:inventory", {title = "Inventory",
	get = function() return "INVENTORY" end})
loading = "bags"
dofile(ROOT .. "/mods/PLAYER/grug_inventory/bags.lua")
dofile(ROOT .. "/mods/PLAYER/grug_inventory/ui.lua")
grug_inventory.equipment_changed = function() end
grug_inventory.equipment_slots = {}

current_mod = "grug_gear"
loading = "grug_gear"
dofile(ROOT .. "/mods/ITEMS/grug_gear/init.lua")
current_mod = "grug_quality"
loading = "grug_quality"
dofile(ROOT .. "/mods/ITEMS/grug_quality/init.lua")
local Q = grug_items

current_mod = "grug_jobs"
grug_jobs = {}
loading = "registry"
dofile(ROOT .. "/mods/PLAYER/grug_jobs/registry.lua")
loading = "grug_jobs"
dofile(ROOT .. "/mods/PLAYER/grug_jobs/state.lua")
local first_join = #callbacks.join + 1
dofile(ROOT .. "/mods/PLAYER/grug_jobs/jobs.lua")
dofile(ROOT .. "/mods/PLAYER/grug_jobs/overview.lua")
dofile(ROOT .. "/mods/PLAYER/grug_jobs/ui.lua")
dofile(ROOT .. "/mods/PLAYER/grug_jobs/craft_box.lua")
local jobs_join = first_join
local ops_join = #callbacks.join + 1
dofile(ROOT .. "/mods/PLAYER/grug_jobs/operation_jobs.lua")
dofile(ROOT .. "/mods/PLAYER/grug_jobs/operation_box.lua")
local J = grug_jobs

-- The enchant and upgrade registrations, as grug_professions loads them.
loading = "station_operations"
dofile(ROOT .. "/mods/PLAYER/grug_jobs/station_operations.lua")
loading = "professions"
grug_professions = {
	enchant_data = dofile(ROOT .. "/mods/ITEMS/grug_professions/enchant_data.lua"),
	read_json = function(name)
		return decode_json(read_file("mods/ITEMS/grug_professions/data/" .. name))
	end,
	INGREDIENT_TIERS = {},
}
dofile(ROOT .. "/mods/ITEMS/grug_professions/enchants.lua")
dofile(ROOT .. "/mods/ITEMS/grug_artisans/enchants.lua")
loading = "test"

-- Every material an operation names, the Stick and the test recipe's inputs
-- as plain items.
local function material(name)
	if not core.registered_items[name] then
		core.registered_items[name] = {description = name:match(":(.*)$"):gsub("_", " ")
			:gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end),
			stack_max = 99, groups = {}, type = "craft"}
	end
end
for _, op in ipairs(J.station_operations()) do
	for _, item in ipairs(op.flat_inputs) do material(item) end
end
material("default:stick")
core.registered_items["default:stick"].description = "Stick"
material("grug_materials:steel_bar")
core.registered_items["grug_materials:steel_bar"].description = "Steel Bar"
core.registered_items["grug_materials:bronze_bar"].description = "Bronze Bar"
core.registered_nodes["grug_jobs:forge"] = {_grug_station = "forge"}
-- The recipe box for the bytes comparison: the steel sword at the forge.
J.register_ingredient_tier("grug_materials:steel_bar", 3)
local sword_recipe = J.register_recipe({area = "weaponsmith", tier = 3, station = "forge",
	output = "grug_gear:sword_steel", time = 3,
	ingredients = {{item = "grug_materials:steel_bar", n = 3}, {item = "default:stick", n = 1}}})
for _, entry in ipairs(callbacks.loaded) do
	if entry.file == "registry" then entry.fn() end
end

local FIELDS = J.CRAFT_FIELDS
local OF = J.OPERATION_FIELDS
local OUT, TARGET = J.OUTPUT_LIST, J.TARGET_LIST

local function new_meta()
	local fields = {}
	return {
		get_string = function(_, key) return fields[key] or "" end,
		set_string = function(_, key, value) fields[key] = value ~= "" and value or nil end,
		get_int = function(_, key) return math.floor(tonumber(fields[key]) or 0) end,
		set_int = function(_, key, value) fields[key] = tostring(value) end,
		fields = fields,
	}
end
local function join(player)
	online[player.name] = player
	for _, f in ipairs(callbacks.join) do f(player) end
end
local function leave(player)
	online[player.name] = nil
	for _, f in ipairs(callbacks.leave) do f(player) end
end
local function new_player(name)
	local inv = new_inventory()
	inv:set_size("main", 32)
	local player = {name = name, inv = inv, meta = new_meta(), sent = 0,
		pos = {x = 0.3, y = 10, z = -0.2}}
	function player:get_player_name() return name end
	function player:get_inventory() return inv end
	function player:get_meta() return self.meta end
	function player:is_player() return true end
	function player:get_pos() return self.pos end
	function player:set_inventory_formspec(fs)
		self.sent = self.sent + 1
		self.formspec = fs
	end
	join(player)
	return player
end
local function put(player, list, index, itemstring)
	player.inv:set_stack(list, index, ItemStack(itemstring))
end
-- Every item of `name` the player holds in any list, the job's target and
-- consumed stacks included (an item is never lost or duplicated).
local function total(player, name)
	local count = 0
	for _, stacks in pairs(player.inv.lists) do
		for _, stack in ipairs(stacks) do
			if stack:get_name() == name then count = count + stack:get_count() end
		end
	end
	local job = J.job_state(player)
	if job then
		local stored = {}
		if job.target then stored[1] = job.target end
		for _, item in ipairs(job.consumed or {}) do stored[#stored + 1] = item end
		for _, item in ipairs(stored) do
			local stack = ItemStack(item)
			if stack:get_name() == name then count = count + stack:get_count() end
		end
	end
	return count
end
local function context_of(player) return sfinv.get_or_create_context(player) end
local function st_of(player) return context_of(player).grug_craft end
local function open(player)
	sfinv.set_page(player, "sfinv:crafting")
	return player.formspec
end
local function click(player, fields)
	for _, f in ipairs(callbacks.receive) do
		local r = f(player, "", fields)
		if r then return r end
	end
end
local function content(fs)
	return fs:match("real_coordinates%[false%](.*)$") or ""
end
-- The engine's inventory action: the allow callbacks (OR, first number
-- wins), then the move and the action callbacks. Returns the allowed count.
local function move(player, from_list, from_index, to_list, to_index)
	local inv = player.inv
	local stack = inv:get_stack(from_list, from_index)
	local info = {from_list = from_list, from_index = from_index, to_list = to_list,
		to_index = to_index, count = stack:get_count()}
	local allowed = stack:get_count()
	for _, f in ipairs(callbacks.allow) do
		local r = f(player, "move", inv, info)
		if r ~= nil then allowed = r break end
	end
	if allowed <= 0 then return 0 end
	local moving = stack:take_item(allowed)
	local there = inv:get_stack(to_list, to_index)
	inv:set_stack(to_list, to_index, moving)
	inv:set_stack(from_list, from_index, stack:is_empty() and there or stack)
	for _, f in ipairs(callbacks.action) do f(player, "move", inv, info) end
	return allowed
end
local function crafted(name, ilvl)
	local stack = ItemStack(name)
	Q.crafted_output(stack)
	if ilvl then
		stack:get_meta():set_int("grug_ilvl", ilvl)
		Q.roll_enchants(stack, ilvl, 0, 1)
	end
	return stack
end
local function learn(player, profession, tier)
	J.learn(player, profession, true)
	player.meta:set_int("grug_jobs:level:" .. profession, tier)
end
local function at_forge(player)
	nodes = {{name = "grug_jobs:forge", pos = {x = 2, y = 10, z = 0}}}
	player.pos = {x = 0.3, y = 10, z = -0.2}
end
local function weaponsmith_area(player)
	open(player)
	local st = st_of(player)
	for index = 1, 5 do
		if (player.formspec or ""):find(FIELDS.area .. index .. ";Weaponsmith]", 1, true) then
			click(player, {[FIELDS.area .. index] = "Weaponsmith"})
			return st
		end
	end
	return st
end
local function plain_text(text)
	return (text:gsub("\27%(c@#%x+%)", ""):gsub("\\(.)", "%1"))
end
local function label_text(fs)
	local parts = {}
	for body in fs:gmatch("label%[(.-[^\\])%]") do
		local text = body:match("^%-?[%d%.]+,%-?[%d%.]+;(.*)$")
		if text then parts[#parts + 1] = plain_text(text) end
	end
	return table.concat(parts, " ")
end
local function says(fs, sentence, label)
	return check(label_text(fs):find(sentence, 1, true) ~= nil,
		label .. " (missing text " .. sentence .. ")")
end
-- The textlist's entries of the enchant box.
local function list_entries(fs)
	local body = fs:match("textlist%[[^;]*;[^;]*;" .. OF.list .. ";(.-[^\\]);%d+;false%]")
	local entries = {}
	if not body then return entries end
	for entry in (body .. ","):gmatch("(.-[^\\]),") do entries[#entries + 1] = plain_text(entry) end
	return entries
end
local function count_text(text, needle)
	local found, from = 0, 1
	while true do
		local a, b = text:find(needle, from, true)
		if not a then return found end
		found, from = found + 1, b + 1
	end
end

------------------------------------------------------------------------------
-- D. The data.
------------------------------------------------------------------------------
local enchants, upgrades = 0, 0
for _, op in ipairs(J.station_operations()) do
	if op.operation == "enchant" then
		enchants = enchants + 1
		check(op.progress == true, "D " .. op.id .. " counts as progress")
	else
		upgrades = upgrades + 1
		check(op.progress == false, "D " .. op.id .. " gives no XP")
		check(#op.ingredients == 1 and op.ingredients[1].n == 1,
			"D " .. op.id .. " costs one own material per level")
		eq(op.weapon_extra[1] and op.weapon_extra[1].item, "default:stick",
			"D " .. op.id .. " takes a Stick for a weapon")
	end
end
eq(enchants, 588, "D 588 enchant operations")
eq(upgrades, 36, "D one upgrade per profession and tier")
eq(J.upgrade_operation("weaponsmith", 3).ingredients[1].item, "grug_materials:steel_bar",
	"D a T3 Weaponsmith upgrade level costs a Steel Bar")
eq(J.upgrade_operation("goldsmith", 6).ingredients[1].item,
	"grug_artisans:setting_gold_filigreed_abyssal_steel", "D the Goldsmith's own material")
eq(read_file("mods/ITEMS/grug_professions/data/upgrades.json"),
	read_file("tools/r33_ds/upgrades_r33.json"), "D upgrades.json is the data design's")
lacks(read_file("mods/ITEMS/grug_professions/data/upgrades.json"), "signatures",
	"D upgrades take no signatures")
do
	local sword = crafted("grug_gear:sword_steel")
	local chest = crafted("grug_gear:chest_metal_steel")
	local op = J.upgrade_operation("weaponsmith", 3)
	local list = J.operation_ingredients(op, sword)
	eq(#list, 2, "D a weapon level: the bar and a Stick")
	eq(list[2] and list[2].item, "default:stick", "D the Stick is the second material")
	eq(#J.operation_ingredients(J.upgrade_operation("armorsmith", 3), chest), 1,
		"D an armour level: the bar only")
	eq(#op.ingredients, 1, "D the operation itself keeps one material")
end

------------------------------------------------------------------------------
-- T. The target slot and the buttons.
------------------------------------------------------------------------------
local smith = new_player("smith")
eq(smith.inv:get_size(TARGET), 1, "T the target slot is made at join")
learn(smith, "weaponsmith", 3)
at_forge(smith)
do
	put(smith, "main", 9, "default:stick 5")
	eq(move(smith, "main", 9, TARGET, 1), 0, "T a stack of sticks does not go in")
	put(smith, "main", 10, crafted("grug_materials:pick_bronze"):to_string())
	core.registered_items["grug_materials:pick_bronze"] = core.registered_items["grug_materials:pick_bronze"] or
		{type = "tool", stack_max = 1, groups = {pickaxe = 1}, description = "Bronze Pick"}
	eq(move(smith, "main", 10, TARGET, 1), 0, "T a tool does not go in")
	put(smith, "main", 9, "")
	put(smith, "main", 10, "")
	local fs = open(smith)
	lacks(fs, "grug_craft_box_enchant", "T no box buttons in Basic")
	weaponsmith_area(smith)
	fs = smith.formspec
	has(fs, "grug_craft_box_enchant;Enchant an item]", "T the enchant button in a learned primary")
	has(fs, "grug_craft_box_upgrade;Upgrade an item]", "T the upgrade button")
	-- Round 45 playtest fix 3: ordinary buttons (the pane and its border),
	-- not the borderless tab style that read as text; the open box's button
	-- gold.
	lacks(fs, "style[grug_craft_box_", "T no style on the closed boxes' buttons")
	has(fs, "button[0.2,8.65;2.45,0.55;grug_craft_box_enchant;", "T the enchant button's size")
	has(fs, "button[2.75,8.65;2.45,0.55;grug_craft_box_upgrade;", "T the upgrade button's size")
	has(fs, "button[0.2,8.05;0.8,0.55;grug_craft_prev;<]", "T the pager above them")
	local sent = smith.sent
	click(smith, {grug_craft_box_enchant = "Enchant an item"})
	eq(st_of(smith).box, "enchant", "T the button opens the enchant box")
	has(smith.formspec, "style[grug_craft_box_enchant;bgcolor=#8a682f;bgcolor_hovered=#a77f3b;" ..
		"bgcolor_pressed=#6f5427;border=true]", "T the open box's button in the gold style")
	lacks(smith.formspec, "style[grug_craft_box_upgrade", "T the other button stays plain")
	lacks(smith.formspec, "border=false]button[0.2,8.65", "T no borderless entry button")
	eq(smith.sent, sent + 1, "T one resend")
	has(smith.formspec, "list[current_player;grug_craft_target;", "T the box draws the slot")
	has(smith.formspec, "listring[current_player;grug_craft_out]listring[current_player;main]" ..
		"listring[current_player;grug_craft_target]listring[current_player;main]",
		"T shift-click from main reaches the slot, the output still main")
	put(smith, "main", 9, crafted("grug_gear:sword_steel"):to_string())
	sent = smith.sent
	eq(move(smith, "main", 9, TARGET, 1), 1, "T a sword goes in")
	eq(smith.sent, sent + 1, "T placing the item resends the open page once")
	sent = smith.sent
	eq(move(smith, TARGET, 1, "main", 9), 1, "T the item comes out")
	eq(smith.sent, sent + 1, "T taking it resends once")
	-- A tab click and a row click return to the recipe box.
	click(smith, {[FIELDS.area .. "1"] = "Basic"})
	eq(st_of(smith).box, nil, "T an area tab leaves the box")
	weaponsmith_area(smith)
	click(smith, {grug_craft_box_upgrade = "Upgrade an item"})
	eq(st_of(smith).box, "upgrade", "T the upgrade box")
	click(smith, {[FIELDS.row .. "1"] = "x"})
	eq(st_of(smith).box, nil, "T a recipe row leaves the box")
	-- Not learned: no buttons.
	local other = new_player("other")
	open(other)
	lacks(other.formspec, "grug_craft_box_", "T no buttons without a learned primary")
	leave(other)
	put(smith, "main", 9, "")
end

------------------------------------------------------------------------------
-- A. The allow chain (review Low 1): an accepted item returns nothing, so a
-- later callback still judges the move; and the hand-back (the user,
-- 2026-10-09) of an item left in the slot at join and at an unlearn.
------------------------------------------------------------------------------
do
	local sword = crafted("grug_gear:sword_steel")
	local inv = smith.inv
	put(smith, "main", 9, sword:to_string())
	local later = function(_, action, _, info)
		if action == "move" and info.from_list == "main" and info.from_index == 9 then return 0 end
	end
	table.insert(callbacks.allow, later)
	eq(move(smith, "main", 9, TARGET, 1), 0, "A a later allow callback still refuses the move")
	table.remove(callbacks.allow)
	for _, f in ipairs(callbacks.allow) do
		local r = f(smith, "move", inv, {from_list = "main", from_index = 9, to_list = TARGET,
			to_index = 1, count = 1})
		check(r == nil, "A no callback returns a number for an accepted item")
	end
	eq(move(smith, "main", 9, TARGET, 1), 1, "A without it the sword goes in")
	-- At join it comes back through the give helper.
	leave(smith)
	join(smith)
	check(inv:get_stack(TARGET, 1):is_empty(), "A join: the slot is empty")
	eq(total(smith, "grug_gear:sword_steel"), 1, "A join: the sword is back, once")
	check(inv:get_stack("main", 9):get_name() == "grug_gear:sword_steel", "A join: into main[9]")
	-- An inventory without room: the output area; without room there too it
	-- stays in the slot.
	local filler = {}
	for _, list in ipairs(grug_inventory.carried_lists(inv)) do
		for index = 1, inv:get_size(list) do
			filler[#filler + 1] = {list, index}
			inv:set_stack(list, index, ItemStack("default:stick 99"))
		end
	end
	inv:set_stack(TARGET, 1, sword)
	leave(smith)
	join(smith)
	check(inv:get_stack(TARGET, 1):is_empty() and
		inv:get_stack(OUT, 1):get_name() == "grug_gear:sword_steel",
		"A a full inventory: into the output area")
	inv:set_stack(TARGET, 1, inv:get_stack(OUT, 1))
	for index = 1, 4 do inv:set_stack(OUT, index, ItemStack("default:stick 99")) end
	leave(smith)
	join(smith)
	check(same_item(inv:get_stack(TARGET, 1), sword), "A no room anywhere: it stays in the slot")
	eq(total(smith, "grug_gear:sword_steel"), 1, "A ... once")
	for _, slot in ipairs(filler) do inv:set_stack(slot[1], slot[2], ItemStack("")) end
	for index = 1, 4 do inv:set_stack(OUT, index, ItemStack("")) end
	-- An unlearn hands it back too.
	learn(smith, "armorsmith", 1)
	J.unlearn(smith, "armorsmith")
	check(inv:get_stack(TARGET, 1):is_empty(), "A unlearn: the slot is empty")
	eq(total(smith, "grug_gear:sword_steel"), 1, "A unlearn: the sword is back, once")
	for _, list in ipairs({"main"}) do
		for index = 1, inv:get_size(list) do inv:set_stack(list, index, ItemStack("")) end
	end
	learn(smith, "weaponsmith", 3)
end

------------------------------------------------------------------------------
-- E. Enchanting.
------------------------------------------------------------------------------
local function enchant_box(player)
	weaponsmith_area(player)
	click(player, {grug_craft_box_enchant = "Enchant an item"})
	return player.formspec
end
local function choose(player, wanted)
	local fs = player.formspec
	for index, entry in ipairs(list_entries(fs)) do
		if entry == wanted then
			click(player, {[OF.list] = "CHG:" .. index})
			return index
		end
	end
	check(false, "E the list offers " .. wanted)
end
local function stock(player, items)
	local index = 9
	for name, count in pairs(items) do
		put(player, "main", index, name .. " " .. count)
		index = index + 1
	end
end
local function clear(player)
	for list, stacks in pairs(player.inv.lists) do
		for index = 1, #stacks do player.inv:set_stack(list, index, ItemStack("")) end
	end
end
local STR_T3 = J.station_operation("enchant:sword:prefix:str:t3")
local function stock_enchant(player, op, times)
	local items = {}
	for _, entry in ipairs(op.ingredients) do
		items[entry.item] = (items[entry.item] or 0) + entry.n * (times or 1)
	end
	stock(player, items)
end

do
	clear(smith)
	local fs = enchant_box(smith)
	says(fs, "Place an item in the Target slot to see the Weaponsmith enchants", "E empty slot")
	has(fs, "Enchant · 5 s", "E the box names its 5 s")
	-- A crafted steel sword (T3, item level 21) and a T3 smith: every sword
	-- enchant of T1-T3 in both channels.
	local sword = crafted("grug_gear:sword_steel")
	eq(Q.effective_ilvl(sword), 21, "E a crafted steel sword is item level 21")
	put(smith, TARGET, 1, sword:to_string())
	fs = open(smith)
	local entries = list_entries(fs)
	eq(#entries, 6 * 2 * 3, "E 36 sword enchants of T1-T3")
	eq(entries[1], "T3 prefix: +5 Strength", "E the best tier first, prefix first, with its value here")
	local tiers_ok = true
	for _, entry in ipairs(entries) do
		local tier = tonumber(entry:match("^T(%d)"))
		tiers_ok = tiers_ok and tier and tier <= 3
	end
	check(tiers_ok, "E nothing above the profession and item tier")
	-- A T2 smith sees T1-T2 only.
	learn(smith, "weaponsmith", 2)
	eq(#list_entries(open(smith)), 24, "E a T2 smith: 24")
	learn(smith, "weaponsmith", 3)
	-- A leather chest is not the Weaponsmith's.
	put(smith, TARGET, 1, crafted("grug_gear:chest_leather_heavy"):to_string())
	fs = open(smith)
	says(fs, "Weaponsmith (tier 3) has no enchant for this item.", "E another family")
	eq(#list_entries(fs), 0, "E no list for another family")
	put(smith, TARGET, 1, sword:to_string())
	open(smith)

	-- The preview and the result.
	stock_enchant(smith, STR_T3)
	choose(smith, "T3 prefix: +5 Strength")
	fs = smith.formspec
	local expected = Q.operation_plan(STR_T3, sword, smith).output
	has(fs, "tooltip[7.9,1.6;1,1;" .. fs_escape(expected:get_meta():get_string("description")) .. "]",
		"E the preview's tooltip is the computed description")
	local image = expected:get_meta():get_string("inventory_image")
	check(image ~= "", "E the result has its enchant image")
	has(fs, "image[7.95,1.65;0.9,0.9;" .. fs_escape(image) .. "]", "E the preview shows it")
	has(fs, "grug_craft_ench_go;Enchant now]", "E Enchant now is enabled")
	says(fs, "Crafting this will give you a Weaponsmith experience point", "E the XP hint")
	local crafts_before = J.crafts_in_tier(smith, "weaponsmith")
	local bars = total(smith, "grug_materials:steel_bar")
	click(smith, {[OF.enchant] = "Enchant now"})
	local job = J.job_state(smith)
	check(job ~= nil and job.kind == "enchant", "E the job starts")
	eq(job and job.finish - job.start, 5, "E 5 s")
	check(smith.inv:get_stack(TARGET, 1):is_empty(), "E the item left the slot")
	eq(total(smith, "grug_gear:sword_steel"), 1, "E the item lives only in the job")
	check(same_item(ItemStack(job.target), sword), "E the job holds the exact item")
	eq(total(smith, "grug_materials:steel_bar"), bars, "E the bar is held by the job, not lost")
	has(smith.formspec, ";Cancel]", "E the button is Cancel while it runs")
	has(smith.formspec, "Enchanting…", "E the indicator")
	says(smith.formspec, "Steel Sword", "E the job's label names the item")
	pass(4.9)
	check(J.job_state(smith) ~= nil, "E not done at 4.9 s")
	pass(0.1)
	eq(J.job_state(smith), nil, "E done at 5 s")
	local out = smith.inv:get_stack(OUT, 1)
	check(same_item(out, expected), "E the result equals the preview")
	eq(total(smith, "grug_gear:sword_steel"), 1, "E one sword, in the output area")
	eq(J.crafts_in_tier(smith, "weaponsmith"), crafts_before + 1, "E one XP for the enchant")
	eq(feed_lines[#feed_lines], "Heavy Steel Sword is ready", "E the feed line")

	-- The overwrite warning: a T2 Strength on the T3 one; the same T3 is gone
	-- from the list, and so is Strength in the other channel.
	smith.inv:set_stack(TARGET, 1, out)
	smith.inv:set_stack(OUT, 1, ItemStack(""))
	fs = open(smith)
	entries = list_entries(fs)
	eq(#entries, 36 - 1 - 3, "E the same enchant and the other channel's Strength leave the list")
	for _, entry in ipairs(entries) do
		check(entry ~= "T3 prefix: +5 Strength" and not entry:find("suffix: %+%d+ Strength"),
			"E not offered: " .. entry)
	end
	choose(smith, "T2 prefix: +5 Strength")
	says(smith.formspec, "Replaces T3 Strength with T2 Strength.", "E the overwrite warning")

	-- Cancel returns the exact item and the materials.
	local placed = smith.inv:get_stack(TARGET, 1)
	clear(smith)
	smith.inv:set_stack(TARGET, 1, placed)
	local T2 = J.station_operation("enchant:sword:prefix:str:t2")
	stock_enchant(smith, T2)
	open(smith)
	choose(smith, "T2 prefix: +5 Strength")
	local before = {}
	for _, entry in ipairs(T2.ingredients) do before[entry.item] = total(smith, entry.item) end
	click(smith, {[OF.enchant] = "Enchant now"})
	check(J.job_state(smith) ~= nil, "E a second enchant starts")
	pass(2)
	click(smith, {[FIELDS.stop] = "Cancel"})
	eq(J.job_state(smith), nil, "E cancelled")
	local back
	for _, stack in ipairs(smith.inv:get_list("main")) do
		if stack:get_name() == "grug_gear:sword_steel" then back = stack end
	end
	check(returned_item(back, placed), "E cancel returns the exact item")
	for item, count in pairs(before) do
		eq(total(smith, item), count, "E cancel returns " .. item)
	end
end

-- The station, the output area, a changed target, a refused begin.
do
	clear(smith)
	local sword = crafted("grug_gear:sword_steel")
	put(smith, TARGET, 1, sword:to_string())
	stock_enchant(smith, STR_T3, 2)
	enchant_box(smith)
	choose(smith, "T3 prefix: +5 Strength")
	nodes = {}
	local fs = open(smith)
	says(fs, "Requires: Forge nearby", "E away from the forge")
	has(fs, FIELDS.recheck .. ";Enchant now]", "E the button is greyed")
	local ok, reason, info = J.start_operation(smith, STR_T3.id)
	check(not ok and info.code == "station", "E the start refuses away from the forge")
	at_forge(smith)
	for index = 1, 4 do put(smith, OUT, index, "default:stick 99") end
	ok, reason = J.start_operation(smith, STR_T3.id)
	eq(reason, "No space in the output area", "E no output space")
	check(same_item(smith.inv:get_stack(TARGET, 1), sword), "E nothing taken without space")
	for index = 1, 4 do put(smith, OUT, index, "") end
	-- The item changed after the page showed the enchant: the start judges
	-- the item now in the slot.
	local enchanted = Q.operation_plan(STR_T3, sword, smith).output
	smith.inv:set_stack(TARGET, 1, enchanted)
	local bars = total(smith, "grug_materials:steel_bar")
	click(smith, {[OF.enchant] = "Enchant now"})
	eq(J.job_state(smith), nil, "E a changed target does not start")
	says(smith.formspec, "This enchantment would not change the item.", "E it says why")
	eq(total(smith, "grug_materials:steel_bar"), bars, "E nothing consumed")
	-- A refused begin gives everything back.
	smith.inv:set_stack(TARGET, 1, sword)
	local begin = J.begin_job
	J.begin_job = function() return nil, "A crafting job is already running." end
	ok, reason = J.start_operation(smith, STR_T3.id)
	J.begin_job = begin
	check(not ok, "E a refused begin refuses the start")
	check(same_item(smith.inv:get_stack(TARGET, 1), sword), "E ... the item back in its slot")
	eq(total(smith, "grug_materials:steel_bar"), bars, "E ... and the materials back")
	-- A second job cannot start while one runs.
	ok = J.start_operation(smith, STR_T3.id)
	check(ok, "E an enchant starts")
	put(smith, TARGET, 1, crafted("grug_gear:sword_steel"):to_string())
	ok, reason = J.start_operation(smith, STR_T3.id)
	eq(reason, "A crafting job is already running.", "E one job at a time")
	pass(5)
	eq(J.job_state(smith), nil, "E done")
	clear(smith)
end

-- XP: none below the current tier; none after an unlearn during the job.
do
	local sword = crafted("grug_gear:sword_steel")
	local T1 = J.station_operation("enchant:sword:prefix:str:t1")
	put(smith, TARGET, 1, sword:to_string())
	stock_enchant(smith, T1)
	local before = J.crafts_in_tier(smith, "weaponsmith")
	check(J.start_operation(smith, T1.id), "E a T1 enchant by a T3 smith")
	pass(5)
	eq(J.crafts_in_tier(smith, "weaponsmith"), before, "E no XP below the tier")
	clear(smith)
	local hand = new_player("hand")
	learn(hand, "weaponsmith", 3)
	at_forge(hand)
	put(hand, TARGET, 1, crafted("grug_gear:sword_steel"):to_string())
	stock_enchant(hand, STR_T3)
	check(J.start_operation(hand, STR_T3.id), "E the job starts")
	J.unlearn(hand, "weaponsmith")
	learn(hand, "weaponsmith", 3)
	pass(5)
	eq(J.crafts_in_tier(hand, "weaponsmith"), 0, "E an unlearn during the job gives no XP")
	check(not hand.inv:get_stack(OUT, 1):is_empty(), "E ... but the job finishes")
	leave(hand)
end

-- A restart in the middle of an enchant job, and a login after its end.
do
	local r = new_player("restart")
	learn(r, "weaponsmith", 3)
	at_forge(r)
	local sword = crafted("grug_gear:sword_steel")
	put(r, TARGET, 1, sword:to_string())
	stock_enchant(r, STR_T3)
	local expected = Q.operation_plan(STR_T3, sword, r).output
	check(J.start_operation(r, STR_T3.id), "E the job starts before the restart")
	pass(2)
	leave(r)
	-- The server stops: the timers die; a new process starts its counter at
	-- 0 and loads jobs.lua and operation_jobs.lua again.
	afters = {}
	advance(1)
	process_start = real
	local keep = {}
	for index = 1, #callbacks.join do
		if index ~= jobs_join and index ~= ops_join then keep[#keep + 1] = callbacks.join[index] end
	end
	callbacks.join = keep
	jobs_join = #callbacks.join + 1
	dofile(ROOT .. "/mods/PLAYER/grug_jobs/jobs.lua")
	ops_join = #callbacks.join + 1
	dofile(ROOT .. "/mods/PLAYER/grug_jobs/operation_jobs.lua")
	join(r)
	check(J.job_state(r) ~= nil, "E the job survives the restart")
	pass(1.9)
	check(J.job_state(r) ~= nil, "E ... still running at 4.9 s")
	pass(0.1)
	eq(J.job_state(r), nil, "E ... and ends at 5 s")
	check(same_item(r.inv:get_stack(OUT, 1), expected), "E the result after the restart")
	eq(total(r, "grug_gear:sword_steel"), 1, "E one sword after the restart")
	-- Logged out until after the end: it completes at login.
	clear(r)
	put(r, TARGET, 1, sword:to_string())
	stock_enchant(r, STR_T3)
	check(J.start_operation(r, STR_T3.id), "E another job")
	leave(r)
	advance(60)
	join(r)
	eq(J.job_state(r), nil, "E a job past its end completes at login")
	check(same_item(r.inv:get_stack(OUT, 1), expected), "E ... with the same result")
	leave(r)
end

------------------------------------------------------------------------------
-- U. Upgrades.
------------------------------------------------------------------------------
local function upgrade_box(player)
	weaponsmith_area(player)
	click(player, {grug_craft_box_upgrade = "Upgrade an item"})
	return player.formspec
end
local function stock_levels(player, bars, sticks, bar)
	stock(player, {[bar or "grug_materials:steel_bar"] = bars, ["default:stick"] = sticks})
end

do
	clear(smith)
	character_level = 30
	local fs = upgrade_box(smith)
	says(fs, "Place an item in the slot.", "U empty slot")
	has(fs, "Upgrade · 1 s per level", "U the box names its 1 s per level")
	lacks(fs, "Crafting this will", "U no XP hint for upgrades")
	-- A steel sword with a T3 Strength enchant.
	local sword = Q.operation_plan(STR_T3, crafted("grug_gear:sword_steel"), smith).output
	put(smith, TARGET, 1, sword:to_string())
	stock_levels(smith, 20, 20)
	fs = open(smith)
	says(fs, "Item level 21", "U the item level")
	says(fs, "Cap 30 (Weaponsmith tier 3)", "U the cap and the tier")
	has(fs, OF.levels .. ";;1]", "U the field starts at 1")
	click(smith, {[OF.max] = "Max", [OF.levels] = "1"})
	has(smith.formspec, OF.levels .. ";;9]", "U Max fills to the cap")
	says(smith.formspec, "Result: item level 30 (cap)", "U the result at the cap")
	-- Above the cap: lowered, noted, nothing started.
	click(smith, {[OF.upgrade] = "Upgrade now", [OF.levels] = "12"})
	eq(J.job_state(smith), nil, "U +12 does not start")
	has(smith.formspec, OF.levels .. ";;9]", "U the field is lowered to 9")
	says(smith.formspec, "The cap is item level 30 — levels reduced to 9", "U the note")
	-- The materials limit Max.
	clear(smith)
	put(smith, TARGET, 1, sword:to_string())
	stock_levels(smith, 4, 20)
	click(smith, {[OF.max] = "Max", [OF.levels] = "9"})
	has(smith.formspec, OF.levels .. ";;4]", "U Max: what the materials pay for")
	click(smith, {[OF.upgrade] = "Upgrade now", [OF.levels] = "6"})
	eq(J.job_state(smith), nil, "U too few materials do not start")
	says(smith.formspec, "Not enough ingredients — levels reduced to 4", "U the materials note")
	-- +3: 3 s, three bars and three sticks, item level 24, enchants follow.
	clear(smith)
	put(smith, TARGET, 1, sword:to_string())
	stock_levels(smith, 5, 5)
	local crafts = J.crafts_in_tier(smith, "weaponsmith")
	click(smith, {[OF.upgrade] = "Upgrade now", [OF.levels] = "3"})
	local job = J.job_state(smith)
	check(job ~= nil and job.kind == "upgrade", "U +3 starts at once below the player's level")
	eq(job and job.finish - job.start, 3, "U 1 s per level")
	eq(total(smith, "grug_materials:steel_bar"), 5, "U the bars are held by the job")
	eq(smith.inv:get_stack(TARGET, 1):is_empty(), true, "U the item left the slot")
	says(smith.formspec, "Steel Sword +3 levels", "U the job's label")
	has(smith.formspec, "Upgrading…", "U the indicator says Upgrading…")
	lacks(smith.formspec, "Crafting…", "U ... not Crafting…")
	has(smith.formspec, FIELDS.stop .. ";Stop]", "U Stop while it runs")
	pass(3)
	eq(J.job_state(smith), nil, "U done after 3 s")
	local out = smith.inv:get_stack(OUT, 1)
	eq(Q.effective_ilvl(out), 24, "U item level 24")
	eq(out:get_meta():get_int("grug_req_level"), 24, "U the requirement follows")
	local affix = Q.get_affixes(out)[1]
	eq(affix and affix.tier, 3, "U the enchant keeps its tier")
	eq(affix and affix.value, Q.enchant_value("str", 24, 3), "U its value follows the item level")
	eq(smith.inv:get_stack("main", 9):get_count() + smith.inv:get_stack("main", 10):get_count(),
		4, "U three bars and three sticks consumed (2 and 2 left)")
	eq(total(smith, "grug_materials:steel_bar"), 2, "U three bars used")
	eq(total(smith, "default:stick"), 2, "U three sticks used")
	eq(J.crafts_in_tier(smith, "weaponsmith"), crafts, "U no XP for an upgrade")
	eq(sounds[#sounds], "upgrade", "U the upgrade sound")
	-- An armour piece pays the bar only.
	clear(smith)
	put(smith, TARGET, 1, crafted("grug_gear:chest_metal_steel"):to_string())
	stock_levels(smith, 2, 0)
	open(smith)
	-- (the armour belongs to the Armorsmith)
	says(smith.formspec, "Weaponsmith does not upgrade this item.", "U another profession's item")
	learn(smith, "armorsmith", 3)
	local ok, reason = J.start_operation(smith, J.upgrade_operation("armorsmith", 3).id, 2)
	check(ok, "U an Armorsmith raises the chest without sticks (" .. tostring(reason) .. ")")
	pass(2)
	eq(Q.effective_ilvl(smith.inv:get_stack(OUT, 1)), 23, "U the chest at 23")
	eq(total(smith, "grug_materials:steel_bar"), 0, "U two bars, no stick")
	J.unlearn(smith, "armorsmith")
	-- Cancel returns the item and the materials.
	clear(smith)
	put(smith, TARGET, 1, out:to_string())
	stock_levels(smith, 3, 3)
	upgrade_box(smith)
	click(smith, {[OF.upgrade] = "Upgrade now", [OF.levels] = "2"})
	check(J.job_state(smith) ~= nil, "U a job to cancel")
	pass(1)
	click(smith, {[FIELDS.stop] = "Stop"})
	eq(J.job_state(smith), nil, "U cancelled")
	local back
	for _, stack in ipairs(smith.inv:get_list("main")) do
		if stack:get_name() == "grug_gear:sword_steel" then back = stack end
	end
	check(returned_item(back, out), "U cancel returns the exact item")
	eq(total(smith, "grug_materials:steel_bar"), 3, "U ... and the bars")
	eq(total(smith, "default:stick"), 3, "U ... and the sticks")
end

-- The warning two-step.
do
	clear(smith)
	character_level = 22
	local sword = crafted("grug_gear:sword_steel")
	put(smith, TARGET, 1, sword:to_string())
	stock_levels(smith, 9, 9)
	upgrade_box(smith)
	click(smith, {[OF.levels] = "1", key_enter_field = OF.levels})
	lacks(smith.formspec, "Upgrade anyway", "U +1 to 22: no warning at the player's level")
	click(smith, {[OF.upgrade] = "Upgrade now", [OF.levels] = "5"})
	eq(J.job_state(smith), nil, "U the first click above the level does not start")
	local fs = smith.formspec
	says(fs, "The target item level exceeds your level, you won't be able to use this " ..
		"item before you have reached level 26.", "U the warning")
	has(fs, "style[" .. OF.upgrade .. ";bgcolor=#f0c419", "U the button is yellow")
	has(fs, OF.upgrade .. ";Upgrade anyway]", "U Upgrade anyway")
	-- Another count is a new question.
	click(smith, {[OF.upgrade] = "Upgrade anyway", [OF.levels] = "6"})
	eq(J.job_state(smith), nil, "U a changed count shows its warning first")
	says(smith.formspec, "reached level 27.", "U the warning for +6")
	click(smith, {[OF.upgrade] = "Upgrade anyway", [OF.levels] = "6"})
	check(J.job_state(smith) ~= nil, "U the second click starts")
	pass(6)
	eq(Q.effective_ilvl(smith.inv:get_stack(OUT, 1)), 27, "U item level 27 above the player's")
	-- Max fills to the cap even above the level, and shows the warning.
	clear(smith)
	put(smith, TARGET, 1, sword:to_string())
	stock_levels(smith, 9, 9)
	click(smith, {[OF.max] = "Max", [OF.levels] = "1"})
	has(smith.formspec, OF.levels .. ";;9]", "U Max to the cap")
	says(smith.formspec, "reached level 30.", "U ... with the warning")
	character_level = 30
end

-- The profession-tier rule and the cap.
do
	clear(smith)
	learn(smith, "weaponsmith", 2)
	character_level = 15
	put(smith, TARGET, 1, crafted("grug_gear:sword_steel"):to_string())
	stock_levels(smith, 9, 9)
	upgrade_box(smith)
	says(smith.formspec, "Weaponsmith tier 3 required.", "U a T2 smith cannot upgrade a T3 item")
	has(smith.formspec, FIELDS.recheck .. ";Upgrade now]", "U the button is greyed")
	local ok, reason = J.start_operation(smith, J.upgrade_operation("weaponsmith", 3).id, 1)
	eq(reason, "Weaponsmith tier 3 required.", "U the start refuses too")
	clear(smith)
	local bronze = crafted("grug_gear:sword_bronze")
	put(smith, TARGET, 1, bronze:to_string())
	stock_levels(smith, 20, 20, "grug_materials:bronze_bar")
	open(smith)
	says(smith.formspec, "Cap 10 (Weaponsmith tier 1)", "U a T1 item's cap is 10 for a T2 smith")
	click(smith, {[OF.upgrade] = "Upgrade now", [OF.levels] = "10"})
	has(smith.formspec, OF.levels .. ";;9]", "U +10 on a level-1 item is lowered to 9")
	click(smith, {[OF.upgrade] = "Upgrade now", [OF.levels] = "9"})
	pass(9)
	local top = smith.inv:get_stack(OUT, 1)
	eq(Q.effective_ilvl(top), 10, "U a T2 smith raises a T1 sword to 10, never past it")
	-- Already at the cap: an upgraded item, a crowned one and a boss drop.
	learn(smith, "weaponsmith", 6)
	character_level = 60
	local crowned = Q.crown_item(crafted("grug_gear:sword_steel"), smith)
	local boss
	for seed = 1, 60 do
		for _, stack in ipairs(Q.roll_mob_gear({name = "grug_mobs:boss", _grug_tier = "boss",
				_grug_level = 70, _grug_boss_id = "king:accord", _grug_royal_king = true}, seed)) do
			if stack:get_name():find("^grug_gear:sword_") then boss = boss or stack end
		end
	end
	for label, item in pairs({["upgraded T1"] = top, crowned = crowned, boss = boss}) do
		clear(smith)
		put(smith, TARGET, 1, item:to_string())
		stock(smith, {["default:stick"] = 9})
		local fs = upgrade_box(smith)
		local _, cap = Q.upgrade_span(item)
		says(fs, "Already at the cap (item level " .. cap .. ").", "U " .. label .. ": at the cap")
		lacks(fs, OF.levels, "U " .. label .. ": no levels field")
		lacks(fs, "+-", "U " .. label .. ": never a negative +N")
		has(fs, FIELDS.recheck .. ";Upgrade now]", "U " .. label .. ": the button is greyed")
		local ok2, why = J.start_operation(smith,
			J.upgrade_operation("weaponsmith", select(3, Q.upgrade_span(item))).id, 1)
		check(not ok2 and why:find("Already at the cap", 1, true),
			"U " .. label .. ": the start refuses")
		check(same_item(smith.inv:get_stack(TARGET, 1), item), "U " .. label .. ": untouched")
	end
	check(boss ~= nil and Q.effective_ilvl(boss) == 65, "U the boss sword is item level 65")
	learn(smith, "weaponsmith", 3)
	character_level = 30
	clear(smith)
end

------------------------------------------------------------------------------
-- P. Geometry and bytes.
------------------------------------------------------------------------------
local function rects(part)
	local out = {}
	for name, body in part:gmatch("([%w_]+)%[(.-[^\\])%]") do
		local x, y, w, h = body:match("^(%-?[%d%.]+),(%-?[%d%.]+);(%-?[%d%.]+),(%-?[%d%.]+)")
		if name == "list" then
			local lx, ly, cols, rows = body:match(";[%w_]+;(%-?[%d%.]+),(%-?[%d%.]+);(%d+),(%d+);")
			out[#out + 1] = {name = name, x = tonumber(lx), y = tonumber(ly),
				w = cols * 1.25 - 0.25, h = rows * 1.25 - 0.25}
		elseif name == "label" then
			local lx, ly, text = body:match("^(%-?[%d%.]+),(%-?[%d%.]+);(.*)$")
			local _, extra = plain_text(text):gsub("[\128-\191]", "")
			out[#out + 1] = {name = name, x = tonumber(lx), y = tonumber(ly) - 0.2,
				w = (#plain_text(text) - extra) / 6.6, h = 0.4, text = plain_text(text)}
		elseif x and name ~= "tooltip" and name ~= "style" then
			out[#out + 1] = {name = name, x = tonumber(x), y = tonumber(y),
				w = tonumber(w), h = tonumber(h)}
		end
	end
	return out
end
local COLUMNS = {{0.2, 5.2}, {5.4, 10.2}, {10.4, 13.3}}
local function geometry_ok(fs, label)
	local ok = true
	for _, r in ipairs(rects(content(fs))) do
		local right, bottom = r.x + r.w, r.y + r.h
		if r.x < 0 or r.y < 0 or right > 13.5 + 1e-6 or bottom > 9.3 + 1e-6 then
			ok = check(false, ("%s: %s at %.2f,%.2f+%.2f,%.2f leaves the page area"):format(
				label, r.name, r.x, r.y, r.w, r.h))
		elseif r.y >= 0.95 then
			for _, column in ipairs(COLUMNS) do
				if r.x >= column[1] - 1e-6 and r.x < column[2] and right > column[2] + 0.05 then
					ok = check(false, ("%s: %s %q at %.2f,%.2f runs out of its column (%.2f)")
						:format(label, r.name, r.text or "", r.x, r.y, right))
				end
			end
			-- The box's own elements end above the button.
			if r.x >= 5.4 and r.x < 10.2 and r.name == "label" and r.y + r.h > 8.4 + 1e-6 then
				ok = check(false, ("%s: label %q at %.2f runs into the button"):format(label,
					r.text or "", r.y))
			end
		end
	end
	check(ok, label .. ": every element inside its column, above the view")
	local opened = select(2, fs:gsub("%[", "")) - select(2, fs:gsub("\\%[", ""))
	local closed = select(2, fs:gsub("%]", "")) - select(2, fs:gsub("\\%]", ""))
	eq(opened, closed, label .. ": balanced brackets")
end
local function box_part(fs)
	local part = content(fs)
	local from = part:find("box[5.4,0.95;4.8,8.25;", 1, true)
	local to = part:find("box[10.4,0.95;2.9,8.25;", 1, true)
	return from and to and part:sub(from, to - 1) or ""
end
do
	clear(smith)
	character_level = 22
	local sword = Q.operation_plan(STR_T3, crafted("grug_gear:sword_steel"), smith).output
	stock_enchant(smith, J.station_operation("enchant:sword:suffix:crit_percent:t3"))
	stock_levels(smith, 9, 9)
	-- The recipe box with the steel sword chosen.
	weaponsmith_area(smith)
	local rows = st_of(smith).rows
	for index, id in ipairs(rows) do
		if id == sword_recipe.id then click(smith, {[FIELDS.row .. index] = "x"}) end
	end
	local recipe_fs = smith.formspec
	geometry_ok(recipe_fs, "P recipe box")
	local recipe_bytes, recipe_page = #box_part(recipe_fs), #recipe_fs
	-- Round 45 playtest fix 3: the steel sword's description is the one the
	-- job makes (real grug_gear and grug_quality), without its name line.
	do
		local made = ItemStack("grug_gear:sword_steel")
		Q.crafted_output(made, smith)
		local expected = plain_text(made:get_meta():get_string("description"))
			:match("^[^\n]*\n(.*)$")
		local area = box_part(recipe_fs):match("textarea%[[%d%.,;]+;;(.-[^\\])%]")
		eq(area and plain_text(area), expected, "P the sword's description is the job's")
		has(expected or "", "Item level 21", "P ... with the T3 base item level")
		has(expected or "", "Requires level 21", "P ... and the requirement")
		lacks(area or "", "\27", "P ... without colour escapes")
	end
	-- The enchant box with a chosen enchant and its overwrite warning.
	put(smith, TARGET, 1, sword:to_string())
	enchant_box(smith)
	choose(smith, "T3 suffix: +2.6% Crit")
	local enchant_fs = smith.formspec
	geometry_ok(enchant_fs, "P enchant box")
	choose(smith, "T2 prefix: +5 Strength")
	geometry_ok(smith.formspec, "P enchant box with the warning")
	-- The upgrade box with the warning.
	upgrade_box(smith)
	click(smith, {[OF.levels] = "1", key_enter_field = OF.levels})
	click(smith, {[OF.upgrade] = "Upgrade now", [OF.levels] = "9"})
	local upgrade_fs = smith.formspec
	eq(J.job_state(smith), nil, "P the first click above the level only warns")
	says(upgrade_fs, "The target item level exceeds your level", "P the upgrade box warns")
	geometry_ok(upgrade_fs, "P upgrade box with the warning")
	nodes = {}
	geometry_ok(open(smith), "P upgrade box away from the forge")
	at_forge(smith)
	print(("bytes: recipe box %d (page %d), enchant box %d (page %d, %d list rows), " ..
		"upgrade box %d (page %d)"):format(recipe_bytes, recipe_page, #box_part(enchant_fs),
		#enchant_fs, #list_entries(enchant_fs), #box_part(upgrade_fs), #upgrade_fs))
	check(#box_part(enchant_fs) > 0 and #box_part(upgrade_fs) > 0, "P the boxes are measured")
	-- A T6 sword at a T6 smith: the longest list.
	learn(smith, "weaponsmith", 6)
	character_level = 60
	clear(smith)
	put(smith, TARGET, 1, crafted("grug_gear:sword_abyssal_steel"):to_string())
	local big = enchant_box(smith)
	eq(#list_entries(big), 72, "P a T6 sword at a T6 smith lists 72 enchants")
	geometry_ok(big, "P the longest list")
	print(("bytes: enchant box with 72 rows %d (page %d)"):format(#box_part(big), #big))
	eq(count_text(big, "textlist["), 1, "P one list element")
end

------------------------------------------------------------------------------
-- H. The Help lines on enchants and upgrades (UI left them for this lane).
------------------------------------------------------------------------------
do
	local help = read_file("mods/PLAYER/grug_inventory/help.lua")
	lacks(help, "lifts an item to its tier's top item level", "H the old upgrade line is gone")
	for _, part in ipairs({"press Enchant an item or Upgrade an item",
			"An enchant takes 5 s", "An upgrade adds +N item levels, 1 s each, up to 10 × the item's tier",
			"a weapon also a Stick", "Upgrades give no XP", "Cooking needs none",
			"upgrades, stations and materials such as bolts, settings or cut gems do not"}) do
		has(help, part, "H Help says: " .. part)
	end
end

if failures > 0 then
	print(("R45 EU PORTABLE FAIL failures=%d checks=%d"):format(failures, checks))
	os.exit(1)
end
print(("R45 EU PORTABLE PASS checks=%d"):format(checks))
