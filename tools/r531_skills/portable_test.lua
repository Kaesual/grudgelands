-- 0.53.1 lane SKILLS portable test (LuaJIT; round53-fix-plan.md §1 rulings 1
-- and 8, §3 "SKILLS"):
--
--   luajit tools/r531_skills/portable_test.lua [repo]
--
--   A  the REAL grug_core/area.lua on a fake node map: one rule for every
--      area, cone and group -- whatever the filter accepts within the
--      horizontal radius and ±3 of the anchor (a cone: also its opening; a
--      group: around the caster) -- with no line of sight: a target behind a
--      wall and one on a ledge behind its edge are reached, one 4 above is
--      not, one 3 below is; the group is the same cylinder (an ally beyond
--      the old sphere but inside radius and band is in, one 4 above is
--      out); no ray is cast; area.clear_line is gone;
--   R  the REAL grug_abilities/init.lua with its whole dofile chain in a
--      sandbox (the tools/r53_hooks pattern): every pointing skill's
--      tooltip head ends in "Range: N m" with N from get_range (a range
--      talent and the elf's bonus, read from the race definition, never a
--      hard-coded number; melee without it), the static head the base;
--      self-kind skills show none unless they aim a ground area
--      (range_shown); the kit texts carry no hard-coded pointing range.
-- Prints "R531 SKILLS PORTABLE PASS checks=<n>" or the failures (exit 1).

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
local function read(path)
	local handle = assert(io.open(ROOT .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

------------------------------------------------------------------------------
-- A: the area helpers without line of sight.
------------------------------------------------------------------------------
do
	local saved = {core = rawget(_G, "core"), vector = rawget(_G, "vector"),
		grug_core = rawget(_G, "grug_core")}
	local vec = {}
	function vec.new(x, y, z)
		if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
		return {x = x or 0, y = y or 0, z = z or 0}
	end
	function vec.copy(v) return vec.new(v) end
	function vec.offset(v, x, y, z) return vec.new(v.x + x, v.y + y, v.z + z) end
	vector = vec
	local nodes = {}
	local function fill(x1, y1, z1, x2, y2, z2, name)
		for x = x1, x2 do for y = y1, y2 do for z = z1, z2 do
			nodes[x .. "," .. y .. "," .. z] = name
		end end end
	end
	local objects = {}
	local function object(name, x, y, z, player)
		local o = {name = name, pos = vec.new(x, y, z), player = player, hp = 20}
		function o:get_pos() return vec.copy(self.pos) end
		function o:is_player() return self.player == true end
		function o:get_player_name() return self.player and self.name or "" end
		function o:get_hp() return self.hp end
		function o:get_properties() return {hp_max = 20} end
		function o:get_look_horizontal() return 0 end
		function o:get_luaentity()
			return not self.player and {name = self.name, _grug_cbox = {-0.4, 0, -0.4, 0.4, 1.6, 0.4}} or nil
		end
		objects[#objects + 1] = o
		return o
	end
	local function in_box(p, a, b)
		return p.x >= a.x and p.x <= b.x and p.y >= a.y and p.y <= b.y and
			p.z >= a.z and p.z <= b.z
	end
	local rays = 0
	core = {
		get_node_or_nil = function(pos)
			return {name = nodes[pos.x .. "," .. pos.y .. "," .. pos.z] or "air"}
		end,
		registered_nodes = {air = {walkable = false}, stone = {walkable = true}},
		-- A stepping node ray (the r52_core stub): the code before 0.53.1
		-- found the walls with it.
		raycast = function(from, to)
			rays = rays + 1
			local hits = {}
			local d = {x = to.x - from.x, y = to.y - from.y, z = to.z - from.z}
			local steps = math.max(1, math.ceil(math.sqrt(d.x * d.x + d.y * d.y + d.z * d.z) / 0.01))
			local function cell(t)
				return math.floor(from.x + d.x * t + 0.5), math.floor(from.y + d.y * t + 0.5),
					math.floor(from.z + d.z * t + 0.5)
			end
			local px, py, pz = cell(0)
			for i = 1, steps do
				local x, y, z = cell(i / steps)
				if (x ~= px or y ~= py or z ~= pz) and nodes[x .. "," .. y .. "," .. z] then
					hits[#hits + 1] = {type = "node", under = {x = x, y = y, z = z}}
				end
				px, py, pz = x, y, z
			end
			local index = 0
			return function()
				index = index + 1
				return hits[index]
			end
		end,
		line_of_sight = function()
			rays = rays + 1
			return true
		end,
		get_objects_in_area = function(minp, maxp)
			local out = {}
			for _, o in ipairs(objects) do
				if in_box(o.pos, minp, maxp) then out[#out + 1] = o end
			end
			return out
		end,
		get_objects_inside_radius = function()
			error("the group is a cylinder (get_objects_in_area), not a sphere")
		end,
		yaw_to_dir = function(yaw) return vec.new(-math.sin(yaw), 0, math.cos(yaw)) end,
		register_on_leaveplayer = function() end,
		log = function() end,
	}
	grug_core = {}
	dofile(ROOT .. "/mods/CORE/grug_core/area.lua")
	local area = grug_core.area
	eq(area.clear_line, nil, "A area.clear_line is gone (no caller left)")
	eq(area.H, 3, "A the band is ±3")
	local function names(list)
		local out = {}
		for i, o in ipairs(list) do out[i] = o.name end
		return table.concat(out, ",")
	end
	local anyone = function() return true end

	-- A ground area: the anchor on the ground's top (y = 0.5).
	fill(-20, 0, -20, 20, 0, 20, "stone")
	local anchor = vec.new(0, 0.5, 0)
	object("open", 1, 0.5, 0)
	object("walled", 0, 0.5, 3)
	fill(-1, 1, 2, 1, 3, 2, "stone")         -- a wall 2 m north, 3 nodes high
	object("ledge", -3.5, 3.5, 0)            -- on a ledge 3 up, behind its edge
	fill(-5, 1, -1, -3, 3, 1, "stone")
	object("pillar", 0, 4.5, -3)             -- on a pillar 4 up: outside the band
	fill(0, 1, -3, 0, 4, -3, "stone")
	object("pit", 3, -2.5, 3)                -- 3 below, inside the band
	object("outside", 4.8, 0.5, 0)           -- beyond the radius
	eq(names(area.query(anchor, {radius = 4.5, filter = anyone})), "open,walled,ledge,pit",
		"A query: behind a wall and on a ledge behind its edge reached, 3 below too; " ..
		"4 above and beyond the radius not; nearest first")
	eq(names(area.query(anchor, {radius = 4.5, filter = anyone, cap = 2})), "open,walled",
		"A query: the cap keeps the nearest, the walled one among them")
	eq(names(area.query(anchor, {radius = 4.5,
		filter = function(o) return o.name ~= "walled" end})), "open,ledge,pit",
		"A query: the filter (valid_target) still decides")

	-- A cone: the caster faces +z (yaw 0).
	objects = {}
	nodes = {}
	fill(-20, 0, -20, 20, 0, 20, "stone")
	local caster = object("caster", 0, 0.5, 0, true)
	object("c_walled", 0.5, 0.5, 3.5)
	fill(-1, 1, 2, 2, 3, 2, "stone")         -- a wall across the cone
	object("c_step", -1, 3.5, 4)             -- behind a 3-node step edge
	fill(-2, 1, 3, 0, 3, 5, "stone")
	object("c_high", 0, 4.5, 2)              -- 4 above the caster's feet
	object("c_behind", 0, 0.5, -2)
	eq(names(area.cone(caster, {radius = 5, angle = 70, filter = anyone})), "c_walled,c_step",
		"A cone: behind a wall and behind a step edge reached; 4 above and behind not; " ..
		"the caster never")

	-- A group: around the caster's feet, a cylinder like the areas.
	objects = {}
	nodes = {}
	fill(-20, 0, -20, 20, 0, 20, "stone")
	local healer = object("healer", 0, 0.5, 0, true)
	object("g_walled", 0, 0.5, -5, true).hp = 5
	fill(-2, 1, -3, 2, 3, -3, "stone")       -- a wall between them
	object("g_ledge", 5.9, 3, 0, true).hp = 10 -- 6.4 m away: beyond the old sphere
	object("g_high", 2, 4.5, 0, true).hp = 1   -- 4 above: outside the band
	object("g_far", 0, 0.5, 6.5, true).hp = 1  -- beyond the radius
	object("g_mob", 1, 0.5, 1)                 -- not a player
	eq(names(area.group(healer, {radius = 6, cap = 10, eligible = anyone})),
		"g_walled,g_ledge,healer",
		"A group: the ally behind a wall and the one inside radius and band are healed; " ..
		"4 above, beyond the radius and a mob not; lowest share first")
	eq(rays, 0, "A no area, cone or group casts a ray")

	core, vector, grug_core = saved.core, saved.vector, saved.grug_core
end

------------------------------------------------------------------------------
-- R: "Range: N m" in the tooltip head.
------------------------------------------------------------------------------
-- The elf's ability range bonus as the race definition gives it (lane RACE
-- owns the number).
local ELF_BONUS = tonumber(read("mods/PLAYER/grug_classes/init.lua"):match(
	"ability_range_bonus%s*=%s*(%d+%.?%d*)"))
check(ELF_BONUS and ELF_BONUS > 0, "R the race definition gives an ability range bonus")

-- The skills whose `range` is a pointing range (the crosshair target or a
-- ground anchor); every other skill shows no range line.
local POINTING = {
	strike = true, retort = true, mighty_blow = true, broadstroke = true,
	hamstring = true, charge = true, taunt = true,
	fiery_spark = true, cold_spark = true, fireball = true, flame_lance = true,
	meteor = true, fire_rain = true, winter_field = true,
	smite = true, heal = true, shield_spell = true, mend = true, rebuke = true,
	word_of_ruin = true, censure = true, final_word = true,
	loose = true, true_draw = true, snare_shot = true, split_shot = true,
	arrowfall = true, bladecraft = true, opening = true,
}

local now_us = 1e9
local function any()
	return setmetatable({}, {__index = function() return any() end,
		__call = function() return nil end})
end
local Stack = {}
Stack.__index = Stack
local function ItemStack(spec)
	if type(spec) == "table" and getmetatable(spec) == Stack then
		local copy = setmetatable({name = spec.name, fields = {}}, Stack)
		for k, v in pairs(spec.fields) do copy.fields[k] = v end
		return copy
	end
	local name = type(spec) == "string" and spec:match("^(%S*)") or ""
	return setmetatable({name = name, fields = {}}, Stack)
end
function Stack:get_name() return self.name end
function Stack:is_empty() return self.name == "" end
function Stack:get_count() return self.name == "" and 0 or 1 end
function Stack:get_meta()
	local fields = self.fields
	return {
		get_string = function(_, k) return fields[k] or "" end,
		set_string = function(_, k, v) fields[k] = v ~= "" and v or nil end,
		get_int = function(_, k) return tonumber(fields[k]) or 0 end,
		set_int = function(_, k, v) fields[k] = tostring(v) end,
		set_tool_capabilities = function() end,
	}
end
function Stack:get_tool_capabilities() return {full_punch_interval = 1} end

local function new_player(name, class, perks)
	local p = {name = name, class = class, bonus = {}, perks = perks or {}}
	function p:get_player_name() return self.name end
	function p:is_player() return true end
	function p:get_hp() return 100 end
	function p:get_pos() return {x = 0, y = 0, z = 0} end
	function p:get_meta() return ItemStack("x"):get_meta() end
	function p:get_properties() return {hp_max = 100} end
	return p
end

local registered_classes = {warrior = {name = "Warrior", resource = "rage"},
	mage = {name = "Mage", resource = "mana"}, priest = {name = "Priest", resource = "mana"},
	scout = {name = "Scout"}}
local function with_any(t)
	return setmetatable(t, {__index = function() return any() end})
end
local fake_core = with_any({
	get_modpath = function() return ROOT .. "/mods/PLAYER/grug_abilities" end,
	get_current_modname = function() return "grug_abilities" end,
	get_us_time = function() return now_us end,
	global_exists = function(n) return n == "grug_inventory" end,
	register_tool = function() end,
	registered_items = {},
	get_item_group = function() return 0 end,
	get_player_by_name = function() return nil end,
	log = function() end,
})
local fake_grug_core = with_any({
	get_melee_weapon = function() return ItemStack("") end,
	scale_player_damage = false,
	base_pool = function() return 100 end,
	get_player_level = function() return 30 end,
})
local fake_classes = with_any({
	registered_classes = registered_classes,
	registered_talents = {},
	get_class = function(p) return p.class end,
	get_class_def = function(p) return registered_classes[p.class] end,
	talent_rank = function() return 0 end,
	get_talent_bonus = function(p, key) return p.bonus[key] or 0 end,
	get_melee_bonus = function() return 0 end,
	get_race_perk = function(p, key) return p.perks[key] end,
	get_max_mana = function() return 1000 end,
})
local fake_inventory = with_any({
	HOTBAR_STORE = "grug_hotbar_store", HOTBAR_SIZE = 8, BAG_COUNT = 1,
	content_list = function(i) return "grug_bag" .. i end,
	hand_list = function() return "grug_weapon" end,
	melee_list = function() return "grug_weapon" end,
})
local env = setmetatable({
	core = fake_core, ItemStack = ItemStack,
	grug_core = fake_grug_core, grug_classes = fake_classes,
	grug_inventory = fake_inventory,
	vector = with_any({direction = function() return {x = 0, y = 0, z = 1} end}),
}, {__index = function(_, k)
	local g = rawget(_G, k)
	if g ~= nil and k ~= "core" and k ~= "minetest" and k ~= "grug_core" and
			k ~= "vector" and k ~= "ItemStack" then return g end
	return any()
end})
env.dofile = function(path)
	return setfenv(assert(loadfile(path)), env)()
end
env._G = env
setfenv(assert(loadfile(ROOT .. "/mods/PLAYER/grug_abilities/init.lua")), env)()
local G = env.grug_abilities
check(G and G.registered.strike and G.registered.fireball and G.registered.loose,
	"R the real init.lua loads with its kits")

do
	local seen = {}
	for id, def in pairs(G.registered) do
		seen[id] = true
		local human = new_player("r_human_" .. id, def.class or "warrior")
		local elf = new_player("r_elf_" .. id, def.class or "warrior",
			{ability_range_bonus = ELF_BONUS})
		local head, static = G.description_prefix(elf, def), G.description_prefix(nil, def)
		local line = head:match("\nRange: ([%d%.]+) m\n$")
		if POINTING[id] then
			local base = def.range or 4
			eq(tonumber(line), G.get_range(elf, def), "R " .. id .. ": the elf's head ends in get_range")
			eq(G.get_range(elf, def), base + (def.melee and 0 or ELF_BONUS),
				"R " .. id .. ": the elf bonus " .. (def.melee and "not on melee" or "included"))
			eq(G.description_prefix(human, def):match("\nRange: ([%d%.]+) m\n$"),
				("%g"):format(base), "R " .. id .. ": a human's head shows the base range")
			eq(static:match("\nRange: ([%d%.]+) m\n$"), ("%g"):format(base),
				"R " .. id .. ": the static head shows the base range")
		else
			check(not head:find("Range:", 1, true) and not static:find("Range:", 1, true),
				"R " .. id .. ": no range line (a radius around the caster or no aim)")
		end
	end
	for id in pairs(POINTING) do
		check(seen[id], "R the pointing skill " .. id .. " is registered")
	end

	-- A range talent: Far Cast (range_add:fiery_spark) and Long View
	-- (range_add:bow) show in the head, the elf's bonus on top.
	local elf = new_player("r_talent", "mage", {ability_range_bonus = ELF_BONUS})
	elf.bonus["range_add:fiery_spark"] = 3
	eq(G.description_prefix(elf, G.registered.fiery_spark):match("\nRange: ([%d%.]+) m\n$"),
		("%g"):format(20 + 3 + ELF_BONUS), "R Far Cast 3 and the elf's bonus: Fiery Spark's range")
	elf.bonus["range_add:bow"] = 2
	eq(G.description_prefix(elf, G.registered.arrowfall):match("\nRange: ([%d%.]+) m\n$"),
		("%g"):format(25 + 2 + ELF_BONUS), "R Long View by the bow tag: Arrowfall's range")
	eq(G.description_prefix(elf, G.registered.meteor),
		"Meteor (Mage)\n14% base mana (" .. G.mana_cost(elf, 14) .. " mana), 18 s cooldown\n" ..
		"Range: " .. ("%g"):format(20 + ELF_BONUS) .. " m\n", "R Meteor's whole head")
end

-- No hard-coded pointing range in the kit texts: "up to N m" and "N m away"
-- are gone from every string (Blink's fixed teleport distance stays, it is
-- no get_range); "within N m" names an area's radius and stays.
do
	local kept = {}
	for _, file in ipairs({"kits.lua", "kits_warrior.lua", "kits_mage.lua",
			"kits_priest.lua", "scout.lua"}) do
		local text = read("mods/PLAYER/grug_abilities/" .. file)
		for line in text:gmatch("[^\n]+") do
			if not line:match("^%s*%-%-") then
				for literal in line:gmatch('"([^"]*)"') do
					if literal:find("up to [%d%%][%w%.]* m[%s:;.,]") or
							literal:find("up to [%d%%][%w%.]* m$") or
							literal:find("m away", 1, true) then
						kept[#kept + 1] = file .. ": " .. literal
					end
				end
			end
		end
	end
	eq(table.concat(kept, " | "), "kits_mage.lua: Teleport up to 10 m in your look direction:\\n" ..
		" | scout.lua: click looses an arrow at a visible hostile target up to %g m away ",
		"R the only range words left: Blink's teleport distance and Bladecraft's shot (from get_range)")
	local scout = read("mods/PLAYER/grug_abilities/scout.lua")
	check(scout:find("grug_abilities.get_range(player, bladecraft_shot)", 1, true) ~= nil,
		"R Bladecraft's shot range comes from get_range")
end

if failures > 0 then
	error(("R531 SKILLS PORTABLE FAIL %d of %d checks"):format(failures, checks))
end
print(("R531 SKILLS PORTABLE PASS checks=%d"):format(checks))
