-- Round 37 lane IX portable test (LuaJIT): the interaction fixes of
-- round37-plan.md §4.4 on a fake engine, each with the REAL game files.
--
--   luajit tools/r37_ix/portable_test.lua [repo]
--
--   R  right-click routing (ITM-03): grug_core/node_rightclick.lua with the
--      real grug_farming/init.lua (seeds, and bucket.lua it loads) and
--      grug_fishing/init.lua (the rod). Seeds, the full and the empty bucket
--      and the rod open a chest instead of their own use; with sneak the
--      item's own use runs (a full bucket pours, the chest stays shut); seeds
--      still plant on soil, harvest a mature regrowing crop, and the rod
--      still casts at water.
--   T  tall-crop tops (ITM-02), the same farming file: a mature Sugar Cane's
--      upper nodes go with its root when the root is removed (the attached
--      drop when its soil is dug), replaced (a block placed on it) or
--      flooded; an orphaned upper node can be dug (no drops) unless
--      protected; dig_crop and the regrowth harvest keep working, and the
--      stage change's swap leaves the new helpers standing.
--   F  the furnace form (PLY-03): default/node_formspec.lua and
--      grug_jobs/workspaces.lua. The 1 s pass re-shows the furnace form only
--      while it is the open form: the recipe book, a form another mod shows
--      and a closed form all stop it, and the session ends.
--   G  grass and moss (X-02): grug_core/protection.lua and the two ABMs of
--      default/functions.lua. In a town, a capital, a POI core or on a road
--      dirt stays dirt and cobble stays cobble; on open ground both grow.
--   W  the water guard (CORE-02): grug_core/water_guard.lua. Water flowing
--      into guarded air is set back as the barrier, whose on_flood refuses
--      the next flow before any change (a small liquid-tick model: one
--      revert instead of one per tick); outside the guard the barrier floods
--      like air and nothing is reverted; a guarded drain still restores the
--      water.
--   S  slab on slab (ITM-10): grug_decor/shapes.lua and
--      grug_materials/derivatives.lua keep the slab when the placement fails.
-- Prints "R37 IX PORTABLE PASS checks=<n>" or the failures (exit 1).

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
local real_dofile = dofile
local function path(rel) return ROOT .. "/" .. rel end

------------------------------------------------------------------------------
-- A small fake engine: a node map with callbacks, metadata, timers, items.
------------------------------------------------------------------------------
vector = {}
function vector.new(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x, y = y, z = z}
end
function vector.subtract(a, b) return vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
function vector.distance(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end
function vector.equals(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
function table.copy(t)
	local r = {}
	for k, v in pairs(t) do r[k] = type(v) == "table" and table.copy(v) or v end
	return r
end

local function key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end
local function P(x, y, z) return {x = x, y = y, z = z} end

local E -- the engine state of the current section

local function new_meta()
	local fields = {}
	local meta = {}
	function meta:set_string(k, v) fields[k] = v ~= "" and tostring(v) or nil end
	function meta:get_string(k) return fields[k] or "" end
	function meta:set_float(k, v) fields[k] = tostring(v) end
	function meta:get_float(k) return tonumber(fields[k]) or 0 end
	function meta:set_int(k, v) fields[k] = tostring(math.floor(v)) end
	function meta:get_int(k) return tonumber(fields[k]) or 0 end
	function meta:mark_as_private() end
	function meta:to_table() return {fields = fields} end
	function meta:get_inventory() return E.new_inventory() end
	return meta
end

local stack_mt = {}
stack_mt.__index = stack_mt
function ItemStack(value)
	if type(value) == "table" and getmetatable(value) == stack_mt then
		local copy = setmetatable({name = value.name, count = value.count,
			wear = value.wear, meta = value.meta}, stack_mt)
		return copy
	end
	local name, count = "", 0
	if type(value) == "string" and value ~= "" then
		name, count = value:match("^(%S+)%s*(%d*)$")
		count = tonumber(count) or 1
	end
	return setmetatable({name = name, count = count, wear = 0, meta = new_meta()}, stack_mt)
end
function stack_mt:get_name() return self.count > 0 and self.name or "" end
function stack_mt:get_count() return self.count end
function stack_mt:is_empty() return self.count <= 0 end
function stack_mt:get_meta() return self.meta end
function stack_mt:get_wear() return self.wear end
function stack_mt:add_wear(n) self.wear = self.wear + n end
function stack_mt:take_item(n)
	n = n or 1
	local taken = math.min(n, self.count)
	self.count = self.count - taken
	return ItemStack(self.name .. " " .. taken)
end
function stack_mt:to_string() return self.count > 0 and (self.name .. " " .. self.count) or "" end
function stack_mt:get_definition() return core.registered_items[self.name] or {} end

local function new_player(name, opts)
	opts = opts or {}
	local player = {name = name, sneak = false, pos = opts.pos or P(0, 1, 0),
		wield = opts.wield or ItemStack(""), received = {}}
	function player:get_player_name() return self.name end
	function player:is_player() return true end
	function player:get_player_control() return {sneak = self.sneak} end
	function player:get_pos() return self.pos end
	function player:get_hp() return 20 end
	function player:get_wielded_item() return self.wield end
	function player:set_wielded_item(stack) self.wield = stack end
	function player:get_inventory()
		local p = self
		return {add_item = function(_, _, item)
			p.received[#p.received + 1] = ItemStack(item):get_name()
			return ItemStack("")
		end, room_for_item = function() return true end}
	end
	return player
end

local function permissive(t)
	return setmetatable(t, {__index = function() return function() end end})
end

local function new_engine()
	E = {nodes = {}, metas = {}, timers = {}, protected = {}, violations = 0,
		swaps = {}, sets = 0, shown = {}, drops = {}, entities = 0, globalsteps = {},
		on_mods_loaded = {}, liquid = {}, receive = {}, abms = {}}
	function E.new_inventory()
		local lists = {}
		return {
			get_size = function(_, l) return lists[l] and #lists[l] or 0 end,
			set_size = function(_, l, n)
				lists[l] = {}
				for i = 1, n do lists[l][i] = ItemStack("") end
			end,
			get_list = function(_, l) return lists[l] end,
			set_list = function() end,
			get_lists = function() return lists end,
			get_stack = function(_, l, i) return lists[l] and lists[l][i] or ItemStack("") end,
			set_stack = function(_, l, i, s) if lists[l] then lists[l][i] = s end end,
			is_empty = function() return true end,
		}
	end
	local c = permissive({registered_nodes = {}, registered_items = {}})
	c.registered_nodes.air = {name = "air", buildable_to = true, groups = {},
		floodable = false}
	c.settings = {get_bool = function(_, _, default) return default end,
		get = function() return nil end, set = function() end}
	function c.get_modpath(mod)
		local dirs = {grug_farming = "mods/ITEMS/grug_farming",
			grug_fishing = "mods/ITEMS/grug_fishing", grug_jobs = "mods/PLAYER/grug_jobs"}
		return path(assert(dirs[mod], mod))
	end
	function c.get_current_modname() return E.modname end
	function c.get_node(pos)
		local node = E.nodes[key(pos)]
		return node and {name = node.name, param2 = node.param2 or 0} or {name = "air", param2 = 0}
	end
	c.get_node_or_nil = c.get_node
	function c.set_node(pos, node)
		local old = c.get_node(pos)
		local olddef = c.registered_nodes[old.name] or {}
		if olddef.on_destruct then olddef.on_destruct(pos) end
		E.nodes[key(pos)] = {name = node.name, param2 = node.param2 or 0}
		E.metas[key(pos)] = nil
		E.sets = E.sets + 1
		if olddef.after_destruct then olddef.after_destruct(pos, old) end
		local def = c.registered_nodes[node.name] or {}
		if def.on_construct then def.on_construct(pos) end
		return true
	end
	function c.remove_node(pos) return c.set_node(pos, {name = "air"}) end
	function c.swap_node(pos, node)
		E.nodes[key(pos)] = {name = node.name, param2 = node.param2 or 0}
		E.swaps[#E.swaps + 1] = {pos = pos, name = node.name}
	end
	function c.get_meta(pos)
		local k = type(pos) == "table" and key(pos) or tostring(pos)
		E.metas[k] = E.metas[k] or new_meta()
		return E.metas[k]
	end
	function c.get_node_timer(pos)
		local k = key(pos)
		E.timers[k] = E.timers[k] or {started = false, timeout = 0}
		local t = E.timers[k]
		return {
			start = function(_, s) t.started, t.timeout = true, s end,
			set = function(_, s) t.started, t.timeout = true, s end,
			stop = function() t.started = false end,
			is_started = function() return t.started end,
			get_timeout = function() return t.timeout end,
			get_elapsed = function() return 0 end,
		}
	end
	function c.is_protected(pos) return E.protected[key(pos)] == true end
	function c.record_protection_violation() E.violations = E.violations + 1 end
	function c.is_creative_enabled() return false end
	function c.handle_node_drops(_, drops) for _, d in ipairs(drops) do E.drops[#E.drops + 1] = d end end
	function c.get_item_group(name, group)
		local def = c.registered_items[name] or c.registered_nodes[name]
		return def and def.groups and def.groups[group] or 0
	end
	function c.register_node(name, def)
		def.name = name
		c.registered_nodes[name] = def
		c.registered_items[name] = def
	end
	function c.register_craftitem(name, def) def.name = name c.registered_items[name] = def end
	c.register_tool = c.register_craftitem
	function c.override_item(name, fields)
		local def = assert(c.registered_items[name] or c.registered_nodes[name], name)
		for k, v in pairs(fields) do def[k] = v end
	end
	function c.register_on_mods_loaded(fn) E.on_mods_loaded[#E.on_mods_loaded + 1] = fn end
	function c.register_globalstep(fn) E.globalsteps[#E.globalsteps + 1] = fn end
	function c.register_on_liquid_transformed(fn) E.liquid[#E.liquid + 1] = fn end
	function c.register_on_player_receive_fields(fn) E.receive[#E.receive + 1] = fn end
	function c.register_abm(def) E.abms[def.label] = def end
	function c.show_formspec(name, formname, formspec)
		E.shown[#E.shown + 1] = {name = name, form = formname, empty = formspec == ""}
	end
	function c.close_formspec(name, formname) c.show_formspec(name, formname, "") end
	function c.add_entity()
		E.entities = E.entities + 1
		return {is_valid = function() return true end, remove = function() end,
			move_to = function() end}
	end
	function c.item_eat() return function() end end
	function c.find_node_near() return nil end
	function c.get_player_by_name(name) return E.players and E.players[name] end
	function c.serialize() return "" end
	function c.deserialize() return nil end
	function c.get_gametime() return 0 end
	function c.dir_to_facedir() return 0 end
	function c.check_player_privs() return false end
	function c.hash_node_position(pos) return key(pos) end
	core = c
	minetest = c
	return c
end

local function run_receive(player, formname, fields)
	for _, fn in ipairs(E.receive) do
		if fn(player, formname, fields) then return true end
	end
	return false
end

local function step(seconds)
	for _, fn in ipairs(E.globalsteps) do fn(seconds) end
end

local function shows(form, name)
	local n = 0
	for _, s in ipairs(E.shown) do
		if s.form == form and not s.empty and (not name or s.name == name) then n = n + 1 end
	end
	return n
end

------------------------------------------------------------------------------
-- Farming and fishing on the fake engine (sections R and T).
------------------------------------------------------------------------------
local function load_farming()
	local c = new_engine()
	E.modname = "grug_farming"
	grug_core = {
		combat_eye_pos = function(player) return player:get_pos() end,
		world_alterable = function() return true end,
		natural_renewal_allowed = function() return true end,
		mob_level_at = function() return 5 end,
		item_name = function(n) return n end,
		feed = function() end,
	}
	real_dofile(path("mods/CORE/grug_core/node_rightclick.lua"))
	grug_nodes = {bind_crop_soil_callbacks = function() end,
		crop_visual = real_dofile(path("mods/ITEMS/grug_nodes/crop_visual.lua"))}
	default = {node_sound_leaves_defaults = function() return {} end}
	grug_cooking = {PLANTS = {
		{name = "fire_pepper", description = "Fire Pepper", item = "grug_cooking:fire_pepper", image = "p.png"},
		{name = "sugar_cane", description = "Sugar Cane", item = "grug_cooking:sugar_cane", image = "s.png"},
	}}
	for _, item in ipairs({"grug_cooking:fire_pepper", "grug_cooking:sugar_cane",
			"grug_gathering:potato", "grug_gathering:corn"}) do
		c.registered_items[item] = {name = item, description = item .. "\nx", inventory_image = "i.png"}
	end
	grug_mapgen = {wp40 = {vegetation = {}, planner_source = {}}}
	dofile = function(file)
		if file:match("/renewal%.lua$") then
			return function() return {constants = {TICK_SECONDS = 0.5}} end
		end
		if file:match("/hoes%.lua$") then return function() end end
		return real_dofile(file)
	end
	real_dofile(path("mods/ITEMS/grug_farming/init.lua"))
	dofile = real_dofile
	-- Nodes the tests point at.
	c.register_node("default:chest", {groups = {}, on_rightclick = function(pos, node, clicker, stack)
		E.chest_opened = (E.chest_opened or 0) + 1
		return stack
	end})
	c.register_node("default:water_source", {groups = {water = 3}, liquidtype = "source",
		buildable_to = true})
	c.register_node("default:cobble", {groups = {}})
	return c
end

local function pointing(under, above)
	return {type = "node", under = under, above = above or P(under.x, under.y + 1, under.z)}
end

do -- R: right-click routing
	local c = load_farming()
	local seed = c.registered_items["grug_farming:seed_fire_pepper"]
	local player = new_player("ann", {pos = P(0, 2, 2)})
	E.players = {ann = player}
	local chest = P(0, 1, 0)
	c.set_node(chest, {name = "default:chest"})

	-- Seeds at a chest: the chest opens, nothing planted, nothing spent.
	local stack = ItemStack("grug_farming:seed_fire_pepper 5")
	local result = seed.on_place(stack, player, pointing(chest))
	eq(E.chest_opened, 1, "R seeds at a chest open it")
	eq(result:get_count(), 5, "R seeds at a chest are not spent")
	eq(c.get_node(P(0, 2, 0)).name, "air", "R seeds at a chest plant nothing")
	-- With sneak the seeds' own use runs (a chest is no soil: nothing).
	player.sneak = true
	seed.on_place(ItemStack("grug_farming:seed_fire_pepper 5"), player, pointing(chest))
	eq(E.chest_opened, 1, "R sneak with seeds does not open the chest")
	player.sneak = false
	-- Seeds on soil still plant.
	local soil = P(3, 0, 0)
	c.set_node(soil, {name = "grug_farming:soil"})
	result = seed.on_place(ItemStack("grug_farming:seed_fire_pepper 5"), player, pointing(soil))
	eq(c.get_node(P(3, 1, 0)).name, "grug_farming:fire_pepper_1", "R seeds plant on soil")
	eq(result:get_count(), 4, "R planting spends one seed")
	-- Seeds at a mature regrowing crop harvest it.
	local crop = P(5, 1, 0)
	c.set_node(P(5, 0, 0), {name = "grug_farming:soil_wet"})
	c.set_node(crop, {name = "grug_farming:fire_pepper_4"})
	seed.on_place(ItemStack("grug_farming:seed_fire_pepper 5"), player, pointing(crop))
	eq(c.get_node(crop).name, "grug_farming:fire_pepper_2", "R seeds at a mature regrowing crop harvest it")
	eq(player.received[#player.received], "grug_cooking:fire_pepper", "R the harvest reaches the player")

	-- The full bucket at a chest opens it and pours nothing; sneak pours.
	local full_def = c.registered_items["grug_farming:water_bucket"]
	local full = ItemStack("grug_farming:water_bucket")
	full:get_meta():set_string("water_family", "ordinary")
	player.wield = full
	result = full_def.on_place(full, player, pointing(chest, P(0, 1, 1)))
	eq(E.chest_opened, 2, "R a full bucket at a chest opens it")
	eq(c.get_node(P(0, 1, 1)).name, "air", "R a full bucket pours nothing in front of a chest")
	eq(result:get_name(), "grug_farming:water_bucket", "R the bucket stays full")
	player.sneak = true
	result = full_def.on_place(full, player, pointing(chest, P(0, 1, 1)))
	eq(E.chest_opened, 2, "R sneak with a full bucket leaves the chest shut")
	eq(c.get_node(P(0, 1, 1)).name, "default:water_source", "R sneak with a full bucket pours")
	eq(result:get_name(), "grug_farming:empty_iron_bucket", "R pouring empties the bucket")
	player.sneak = false
	-- The empty bucket at a chest opens it; at water it fills.
	local empty_def = c.registered_items["grug_farming:empty_iron_bucket"]
	local empty = ItemStack("grug_farming:empty_iron_bucket")
	player.wield = empty
	empty_def.on_place(empty, player, pointing(chest))
	eq(E.chest_opened, 3, "R an empty bucket at a chest opens it")
	result = empty_def.on_place(empty, player, pointing(P(0, 1, 1)))
	eq(result:get_name(), "grug_farming:water_bucket", "R an empty bucket at water fills")

	-- The fishing rod (grug_fishing/init.lua on the same engine).
	E.modname = "grug_fishing"
	mobs = {add_eatable = function() end}
	grug_sounds = {play = function() end}
	grug_xp = {}
	PcgRandom = function() return {next = function(_, a) return a end} end
	real_dofile(path("mods/ITEMS/grug_fishing/init.lua"))
	local rod_def = c.registered_items["grug_fishing:rod"]
	local rod = ItemStack("grug_fishing:rod")
	player.wield = rod
	rod_def.on_place(rod, player, pointing(chest))
	eq(E.chest_opened, 4, "R the rod at a chest opens it")
	eq(E.entities, 0, "R the rod at a chest casts nothing")
	player.sneak = true
	rod_def.on_place(rod, player, pointing(chest))
	eq(E.chest_opened, 4, "R sneak with the rod leaves the chest shut")
	player.sneak = false
	local water = P(1, 0, 3)
	c.set_node(water, {name = "default:water_source"})
	rod_def.on_place(rod, player, pointing(water))
	eq(E.entities, 1, "R the rod still casts at water")
end

do -- T: tall-crop tops
	local c = load_farming()
	local player = new_player("ann", {pos = P(0, 2, 2)})
	E.players = {ann = player}
	local function cane(x)
		local root = P(x, 1, 0)
		c.set_node(P(x, 0, 0), {name = "grug_farming:soil_wet"})
		c.set_node(root, {name = "grug_farming:sugar_cane_4"})
		for level = 1, 3 do
			c.set_node(P(x, 1 + level, 0), {name = "grug_farming:sugar_cane_4_upper_" .. level})
		end
		return root
	end
	local function tops(x)
		local n = 0
		for level = 1, 3 do
			if c.get_node(P(x, 1 + level, 0)).name:find("_upper_") then n = n + 1 end
		end
		return n
	end
	-- The attached drop (builtin removes the root with remove_node).
	local root = cane(0)
	eq(tops(0), 3, "T a mature Sugar Cane stands four nodes high")
	c.remove_node(root)
	eq(tops(0), 0, "T the root's removal takes the upper nodes along")
	-- A block placed on the buildable root (set_node replaces it).
	root = cane(2)
	c.set_node(root, {name = "default:cobble"})
	eq(tops(2), 0, "T a block placed on the root takes the upper nodes along")
	-- A flood: the root's on_flood clears the tops and lets the water in.
	root = cane(4)
	local def = c.registered_nodes["grug_farming:sugar_cane_4"]
	local refused = def.on_flood and def.on_flood(root, c.get_node(root),
		{name = "default:water_flowing"})
	check(def.on_flood ~= nil, "T the root has an on_flood")
	check(not refused, "T a flood is not refused by the crop")
	eq(tops(4), 0, "T a flooded root takes the upper nodes along")
	-- An orphaned upper node (its root went without any callback).
	cane(6)
	c.swap_node(P(6, 1, 0), {name = "air"})
	local orphan = P(6, 3, 0)
	local helper = c.registered_nodes["grug_farming:sugar_cane_4_upper_2"]
	E.protected[key(orphan)] = true
	helper.on_dig(orphan, c.get_node(orphan), player)
	eq(c.get_node(orphan).name, "grug_farming:sugar_cane_4_upper_2", "T a protected orphan stays")
	check(E.violations > 0, "T a protected orphan records the violation")
	E.protected[key(orphan)] = nil
	local drops = #E.drops
	helper.on_dig(orphan, c.get_node(orphan), player)
	eq(c.get_node(orphan).name, "air", "T an orphaned upper node can be dug")
	eq(#E.drops, drops, "T an orphan drops nothing")
	-- dig_crop still digs the whole plant with its drops.
	root = cane(8)
	helper.on_dig(P(8, 3, 0), c.get_node(P(8, 3, 0)), player)
	eq(c.get_node(root).name, "air", "T digging a segment removes the root")
	eq(tops(8), 0, "T digging a segment removes every segment")
	eq(E.drops[#E.drops], "grug_cooking:sugar_cane", "T a mature dig drops the harvest")
	-- The regrowth harvest swaps the root (no destruct): stage 1, one node.
	root = cane(10)
	def.on_rightclick(root, c.get_node(root), player, ItemStack(""))
	eq(c.get_node(root).name, "grug_farming:sugar_cane_1", "T the harvest resets the root")
	eq(tops(10), 0, "T the harvest removes the upper growth")
	-- A growth step to stage 2 builds its helper and keeps it (swap, no destruct).
	local state_def = c.registered_nodes["grug_farming:sugar_cane_1"]
	c.get_meta(root):set_string("grug_crop_planter", "ann")
	state_def.on_timer(root, 200)
	eq(c.get_node(root).name, "grug_farming:sugar_cane_2", "T the crop grows a stage")
	eq(c.get_node(P(10, 2, 0)).name, "grug_farming:sugar_cane_2_upper_1",
		"T the grown stage keeps its new upper node")
end

------------------------------------------------------------------------------
-- F: the furnace form re-shows only while it is the open form (PLY-03).
------------------------------------------------------------------------------
do
	local c = new_engine()
	default = {get_hotbar_bg = function() return "" end,
		get_inventory_drops = function() end}
	real_dofile(path("mods/BASE/default/node_formspec.lua"))
	grug_core = {interaction_protected = function() return false end}
	grug_items = {enchant_legend_formspec = function() return "" end}
	grug_sounds = {play = function() end}
	local book_opened = 0
	grug_jobs = {
		station_info = function() return {display_name = "Furnace", node = "default:furnace"} end,
		is_public_station = function() return true end,
		station_book_button = function() return "" end,
		open_book = function(player)
			book_opened = book_opened + 1
			c.show_formspec(player:get_player_name(), "grug_jobs:book", "book")
		end,
	}
	function c.create_detached_inventory() return E.new_inventory() end
	function c.formspec_escape(s) return s end
	local stub_automatic = {sizes = {furnace = {src = 1, fuel = 1, dst = 4}},
		advance = function() end, fractions = function() return 0, 0 end,
		fuel_time = function() return 0 end, personal_light_deadline = function() return 0 end}
	dofile = function(file)
		if file:match("/automatic%.lua$") then return stub_automatic end
		return real_dofile(file)
	end
	local workspaces = real_dofile(path("mods/PLAYER/grug_jobs/workspaces.lua"))
	dofile = real_dofile
	c.register_node("default:furnace", {_grug_station = "furnace", groups = {}})
	local pos = P(0, 0, 0)
	c.set_node(pos, {name = "default:furnace"})
	c.get_meta(pos):set_string("grug_jobs:station_id", "s1")
	local player = new_player("ann", {pos = P(1, 0, 0)})
	E.players = {ann = player}
	local FORM = "grug_jobs:workspace"

	workspaces.open(pos, player)
	eq(shows(FORM), 1, "F the furnace opens its form")
	step(1.1)
	eq(shows(FORM), 2, "F the open furnace form refreshes each second")
	-- The recipe book from the furnace form: it stays.
	run_receive(player, FORM, {grug_jobs_book = "Book"})
	eq(book_opened, 1, "F the book button opens the book")
	step(1.1) step(1.1)
	eq(shows(FORM), 2, "F the furnace form never returns over the recipe book")
	-- Closing the book does not bring the furnace back.
	run_receive(player, "grug_jobs:book", {quit = "true"})
	step(1.1)
	eq(shows(FORM), 2, "F a closed book does not reopen the furnace")
	-- Another mod's form while the furnace is open.
	workspaces.open(pos, player)
	eq(shows(FORM), 3, "F the furnace opens again")
	c.show_formspec("ann", "other:dialog", "x")
	step(1.1) step(1.1)
	eq(shows(FORM), 3, "F the furnace form never returns over another form")
	-- A furnace closed with Esc: no refresh either.
	workspaces.open(pos, player)
	run_receive(player, FORM, {quit = "true"})
	step(1.1)
	eq(shows(FORM), 4, "F a closed furnace stays closed")
	-- Another player's open form is not touched by ann's book.
	local bob = new_player("bob", {pos = P(1, 0, 1)})
	E.players.bob = bob
	workspaces.open(pos, bob)
	workspaces.open(pos, player)
	run_receive(player, FORM, {grug_jobs_book = "Book"})
	step(1.1)
	eq(shows(FORM, "bob"), 2, "F another viewer's furnace form still refreshes")
	local record = default.node_formspec.shown_form
	eq(record and record("ann"), "grug_jobs:book", "F the record holds the open book")
end

------------------------------------------------------------------------------
-- G: grass spread and moss stop on authored ground (X-02).
------------------------------------------------------------------------------
do
	local c = new_engine()
	-- Territory by x: x < 0 a town ("hard_protected"), 0..9 open home ground,
	-- 10..19 a road, 20..29 a POI core, from 30 contested land.
	grug_core = {zone_authority_installed = function() return true end}
	grug_zones = {territory_rule_at = function(pos)
		if pos.x < 0 then return "hard_protected" end
		if pos.x >= 30 then return "contested_land" end
		return "accord_home"
	end}
	function grug_core.world_feature_at(pos)
		if pos.x >= 10 and pos.x < 20 then return "road" end
		if pos.x >= 20 and pos.x < 30 then return "poi" end
		return nil
	end
	real_dofile(path("mods/CORE/grug_core/protection.lua"))
	default = permissive({})
	real_dofile(path("mods/BASE/default/functions.lua"))
	local grass, moss = E.abms["Grass spread"], E.abms["Moss growth"]
	check(grass and moss, "G both vendored ABMs are registered")
	function c.get_node_light() return 15 end
	function c.find_node_near(pos) return P(pos.x + 1, pos.y, pos.z) end
	c.register_node("default:dirt_with_grass", {groups = {spreading_dirt_type = 1}})
	local function grows(x)
		local pos = P(x, 0, 0)
		c.set_node(pos, {name = "default:dirt"})
		c.set_node(P(x + 1, 0, 0), {name = "default:dirt_with_grass"})
		grass.action(pos, c.get_node(pos))
		local cobble = P(x, 5, 0)
		c.set_node(cobble, {name = "default:cobble"})
		moss.action(cobble, c.get_node(cobble))
		return c.get_node(pos).name ~= "default:dirt", c.get_node(cobble).name ~= "default:cobble"
	end
	for _, case in ipairs({{-5, "a town"}, {12, "a road"}, {22, "a POI core"}}) do
		local g, m = grows(case[1])
		check(not g, "G no grass spreads in " .. case[2])
		check(not m, "G no moss grows in " .. case[2])
	end
	for _, case in ipairs({{3, "home ground"}, {40, "contested land"}}) do
		local g, m = grows(case[1])
		check(g, "G grass spreads on " .. case[2])
		check(m, "G moss grows on " .. case[2])
	end
	-- Before the zone authority exists nothing grows (fail closed).
	grug_core.zone_authority_installed = function() return false end
	local g, m = grows(50)
	check(not g and not m, "G nothing grows before the zone authority")
end

------------------------------------------------------------------------------
-- W: the water guard ends the flow/revert loop (CORE-02).
------------------------------------------------------------------------------
do
	local c = new_engine()
	local guarded_x = 0 -- x >= guarded_x is a town
	grug_core = {zone_authority_installed = function() return true end,
		world_feature_at = function() return nil end}
	grug_zones = {territory_rule_at = function(pos)
		return pos.x >= guarded_x and "hard_protected" or "accord_home"
	end}
	real_dofile(path("mods/CORE/grug_core/protection.lua"))
	for _, name in ipairs({"default:water_source", "default:river_water_source"}) do
		c.register_node(name, {liquidtype = "source", groups = {water = 3}})
	end
	for _, name in ipairs({"default:water_flowing", "default:river_water_flowing"}) do
		c.register_node(name, {liquidtype = "flowing", groups = {water = 3}})
	end
	real_dofile(path("mods/CORE/grug_core/water_guard.lua"))
	local BARRIER = grug_core.WATER_BARRIER
	local barrier = c.registered_nodes[BARRIER or ""] or {}
	check(barrier.floodable and barrier.drawtype == "airlike" and
		not barrier.walkable and not barrier.pointable and barrier.buildable_to,
		"W the barrier is floodable and acts like air")
	for _, fn in ipairs(E.on_mods_loaded) do fn() end
	check(type(barrier.on_flood) == "function", "W the barrier's on_flood is wrapped")

	-- A tiny liquid tick: a river source at x - 1 floods the air at `pos` the
	-- way the engine does: air takes no on_flood, so it is transformed and
	-- reported; a floodable node is asked first and may refuse. A revert
	-- (any swap) re-queues the source for the next tick.
	local function model(pos, ticks)
		local transforms, queued = 0, true
		for _ = 1, ticks do
			if queued then
				queued = false
				local node = c.get_node(pos)
				local def = c.registered_nodes[node.name] or {}
				local flow = {name = "default:river_water_flowing", param2 = 7}
				local refused = node.name ~= "air" and def.floodable and def.on_flood and
					def.on_flood(pos, node, flow)
				if node.name == "air" or (def.floodable and not refused) then
					E.nodes[key(pos)] = flow
					transforms = transforms + 1
					local swaps = #E.swaps
					for _, fn in ipairs(E.liquid) do fn({pos}, {node}) end
					if #E.swaps > swaps then queued = true end
				end
			end
		end
		return transforms
	end
	local edge = P(0, 37, 0)
	eq(model(edge, 10), 1, "W guarded air is flooded and reverted once in ten ticks")
	eq(c.get_node(edge).name, BARRIER, "W the reverted air is the barrier")
	eq(model(edge, 10), 0, "W the barrier refuses every later flow before any change")
	-- Outside the guard nothing is reverted, and a barrier there floods like air.
	local open = P(-3, 37, 0)
	eq(model(open, 3), 1, "W unguarded air floods once")
	eq(c.get_node(open).name, "default:river_water_flowing", "W unguarded flow stays")
	E.nodes[key(open)] = {name = BARRIER or "air"}
	eq(model(open, 3), 1, "W an unguarded barrier floods like air")
	eq(c.get_node(open).name, "default:river_water_flowing", "W the unguarded barrier is water now")
	-- A guarded drain still restores the water it had.
	local drained = P(4, 37, 0)
	E.nodes[key(drained)] = {name = "air"}
	for _, fn in ipairs(E.liquid) do
		fn({drained}, {{name = "default:river_water_flowing", param2 = 5}})
	end
	eq(c.get_node(drained).name, "default:river_water_flowing", "W a guarded drain is restored")
	-- The decision itself.
	local revert = grug_core.water_guard_revert_node or function(node) return node end
	eq(revert({name = "air"}).name, BARRIER, "W reverted air becomes the barrier")
	eq(revert({name = "default:water_source"}).name, "default:water_source",
		"W reverted water stays water")
end

------------------------------------------------------------------------------
-- S: a refused slab-on-slab placement keeps the slab (ITM-10).
------------------------------------------------------------------------------
do
	-- Both on_place functions on a fake builtin item_place_node that places
	-- or refuses.
	local function slab_case(label, make_on_place, slab_name)
		local c = new_engine()
		local place_ok = true
		function c.item_place_node(stack) return stack, place_ok and P(0, 1, 0) or nil end
		local on_place = make_on_place(c)
		c.set_node(P(0, 0, 0), {name = slab_name})
		local player = new_player("ann")
		local stack = on_place(ItemStack(slab_name .. " 3"), player, pointing(P(0, 0, 0)))
		eq(stack:get_count(), 2, label .. " a placed slab is taken")
		place_ok = false
		stack = on_place(ItemStack(slab_name .. " 3"), player, pointing(P(0, 0, 0)))
		eq(stack:get_count(), 3, label .. " a refused slab is kept")
	end
	local function read(rel)
		local handle = assert(io.open(path(rel), "rb"))
		local text = handle:read("*a")
		handle:close()
		return text
	end
	-- grug_decor/shapes.lua: the slab's on_place, cut from the file.
	local block = read("mods/ITEMS/grug_decor/shapes.lua"):match(
		"(on_place = function%(itemstack, placer, pointed_thing%)\n\t\t\tlocal under = core%.get_node.-\n\t\tend,)\n\t}%)%)\nend")
	check(block ~= nil, "S the slab on_place is found in shapes.lua")
	if block then
		slab_case("S decor:", function()
			local fn = assert(loadstring("local rotate_and_place = function(s) return s end\nreturn {" ..
				block .. "}", "=shapes_slab"))()
			return fn.on_place
		end, "grug_decor:stonewall_slab")
	end
	-- grug_materials/derivatives.lua: the wrapper, cut from the file.
	local wrapper = read("mods/ITEMS/grug_materials/derivatives.lua"):match(
		"(\t\tdef%.on_place = function%(itemstack, placer, pointed_thing%).-\n\t\tend\n)")
	check(wrapper ~= nil, "S the slab wrapper is found in derivatives.lua")
	if wrapper then
		slab_case("S materials:", function()
			local fn = assert(loadstring("local def, source_on_place = {}, function(s) return s end\n" ..
				wrapper .. "\nreturn def.on_place", "=derivatives_slab"))()
			return fn
		end, "grug_materials:slab_iron")
	end
end

if failures > 0 then
	print(("R37 IX PORTABLE FAIL failures=%d checks=%d"):format(failures, checks))
	os.exit(1)
end
print(("R37 IX PORTABLE PASS checks=%d"):format(checks))
