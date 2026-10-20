-- Round 53 lane HOOKS portable test (LuaJIT; round53-plan.md §4 HOOKS, K6-K9,
-- K14): the shared seams, tables, art and effects the class lanes build on.
--
--   luajit tools/r53_hooks/portable_test.lua [repo]
--
--   P  the effects: every "new" and "retint" card of tools/r52_pfx
--      (emitters.lua) equals the registered catalogue entry, colour
--      included, evaluated with the card's sample frame (34 new ids, 7
--      retints); every "keep" card's id exists; the four window cards'
--      colours are their PROC_COLORS rows;
--   I  the 25 skill icons ship as 64 x 64 PNGs with a LICENSE-media.md row
--      of their size;
--   S  the new statuses and the seven readiness windows have status rows
--      whose icons ship;
--   U  in the same sandbox, every shipped skill without talents keeps
--      main's cost, cooldown, range, tooltip head and cast clock; only a
--      swing now holds casts back one weapon interval (K9);
--   K  the REAL grug_abilities/init.lua with its whole dofile chain in a
--      sandbox (the tools/r52_bench pattern), on probe definitions:
--      the K6 rows of the 25 new skills (a family of their class, a pose
--      with clips or none, a cue); the family keys on the cast path
--      (cost_pct, cooldown_sub, range_add by id and tags, a transformation
--      by its own) and in the tooltip; on the swing path the proc cost
--      (cost_pct and the definition's cost_adjust) and the plain swing's
--      damage_pct by tags (Strike is a blade); the swing callback
--      (multiplier and add before the scaling pass, rage and on_landed only
--      when the swing lands); the clock seams (a function cast_interval,
--      occupied_cast and occupied_swing; the timing line shows the base);
--      K9 (a swing holds casts back one weapon interval); the refusal
--      reasons; K7 (the basic attack first);
--   F  K8, the held fallback, through the REAL input.lua on a fake engine,
--      one case per class: a refused skill at a hostile fires the current
--      basic attack once and silently (a swing basic attack swings, a cast
--      one casts), never when the skill is the basic attack or the refusal
--      is the action clock or the cast interval;
--   A  the REAL grug_core/area.lua on a fake node map: the facing cone
--      (opening, radius, band, line of sight, the filter, the cap, nearest
--      first, the caster never) and the fall height sampled at 0.6 x the
--      radius under a sloped ceiling (a rising slope or rock beside the area
--      lower nothing).
-- Prints "R53 HOOKS PORTABLE PASS checks=<n>" or the failures (exit 1).

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
local function near(actual, expected, label)
	return check(type(actual) == "number" and math.abs(actual - expected) < 1e-6,
		label .. " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end
local function read(path)
	local handle = io.open(ROOT .. "/" .. path, "rb")
	if not handle then return nil end
	local text = handle:read("*a")
	handle:close()
	return text
end

-- The 25 skills round K adds, by class and tree family (C7).
local NEW = {
	fiery_spark = {"mage", "ember"}, flame_lance = {"mage", "ember"},
	meteor = {"mage", "ember"}, fire_rain = {"mage", "ember"},
	cold_spark = {"mage", "rime"}, ice_wave = {"mage", "rime"},
	rime_mantle = {"mage", "rime"}, winter_field = {"mage", "rime"},
	retort = {"warrior", "bulwark"}, bellow = {"warrior", "bulwark"},
	unbroken = {"warrior", "bulwark"}, broadstroke = {"warrior", "ruin"},
	ruination = {"warrior", "ruin"},
	hearten = {"priest", "mercy"}, haven = {"priest", "mercy"},
	rebuke = {"priest", "reckoning"}, censure = {"priest", "reckoning"},
	final_word = {"priest", "reckoning"},
	true_draw = {"scout", "quarry"}, split_shot = {"scout", "quarry"},
	arrowfall = {"scout", "quarry"}, bladecraft = {"scout", "veil"},
	parry = {"scout", "veil"}, flourish = {"scout", "veil"},
	close_dance = {"scout", "veil"},
}
local NEW_IDS = {}
for id in pairs(NEW) do NEW_IDS[#NEW_IDS + 1] = id end
table.sort(NEW_IDS)
eq(#NEW_IDS, 25, "the 25 new skills")

------------------------------------------------------------------------------
-- P: the effects against the picked cards.
------------------------------------------------------------------------------
do
	core = {settings = {get = function() return nil end}, log = function() end,
		yaw_to_dir = function() return {x = 1, y = 0, z = 0} end}
	vector = {new = function(x, y, z) return {x = x, y = y, z = z} end}
	grug_core = {}
	dofile(ROOT .. "/mods/CORE/grug_core/particles.lua")
	dofile(ROOT .. "/mods/CORE/grug_core/particle_effects.lua")
	local P = grug_core.particles
	local cards = dofile(ROOT .. "/tools/r52_pfx/emitters.lua")
	local function same(a, b)
		if type(a) ~= type(b) then return false end
		if type(a) == "number" then return math.abs(a - b) < 1e-6 end
		if type(a) ~= "table" then return a == b end
		for k, v in pairs(a) do if not same(v, b[k]) then return false end end
		for k in pairs(b) do if a[k] == nil then return false end end
		return true
	end
	local new_ids, retints = {}, {}
	local WINDOW = {["pfx.cold_spark.window"] = "cold_shock", ["pfx.retort.window"] = "retort",
		["pfx.smite.window"] = "clear_conscience", ["pfx.loose.window"] = "follow_the_line"}
	for _, card in ipairs(cards) do
		local effect = P.registered(card.id)
		if card.status == "new" or card.status == "retint" then
			local list = type(effect) == "function" and effect(card.sample) or effect
			check(list ~= nil and same(card.emitters, list),
				"P " .. card.key .. ": " .. card.id .. " equals its card, colour included")
			local seen = card.status == "new" and new_ids or retints
			if not seen[card.id] then
				seen[card.id] = true
				seen.n = (seen.n or 0) + 1
			end
		elseif card.status == "keep" then
			check(effect ~= nil, "P " .. card.key .. ": the kept " .. card.id .. " ships")
		end
		if WINDOW[card.key] then
			eq(grug_core.PROC_COLORS[WINDOW[card.key]], card.emitters[1].color,
				"P " .. card.key .. ": the proc colour of " .. WINDOW[card.key])
		end
	end
	eq(new_ids.n, 34, "P the 34 new effect ids")
	eq(retints.n, 7, "P the 7 retinted effects")
	check(grug_core.PROC_COLORS.ruination and grug_core.PROC_COLORS.unbroken,
		"P the reused proc colours stay")
end

------------------------------------------------------------------------------
-- I: the skill icons and their licence rows.
------------------------------------------------------------------------------
do
	local license = read("mods/PLAYER/grug_abilities/LICENSE-media.md") or ""
	for _, id in ipairs(NEW_IDS) do
		local file = "grug_abilities_skill_" .. id .. ".png"
		local data = read("mods/PLAYER/grug_abilities/textures/" .. file)
		if check(data ~= nil, "I " .. file .. " ships") then
			local function u32(at)
				local a, b, c, d = data:byte(at, at + 3)
				return ((a * 256 + b) * 256 + c) * 256 + d
			end
			check(data:sub(2, 4) == "PNG" and u32(17) == 64 and u32(21) == 64,
				"I " .. file .. " is a 64 x 64 PNG")
			local row = license:match("\n| `textures/" .. file:gsub("%.", "%%.") ..
				"` | [^\n]-| (%d+) | `[0-9a-f]+` |")
			eq(tonumber(row), #data, "I " .. file .. " has its licence row with its size")
		end
	end
end

------------------------------------------------------------------------------
-- S: the status and window rows.
------------------------------------------------------------------------------
do
	grug_core = {}
	dofile(ROOT .. "/mods/CORE/grug_core/status_icons.lua")
	local icons = grug_core.status_icons
	local function ships(texture)
		local skill = texture:match("^grug_abilities_skill_(.+)%.png$")
		local talent = texture:match("^grug_classes_talent_(.+)%.png$")
		local path = skill and "mods/PLAYER/grug_abilities/textures/" .. texture or
			talent and "mods/PLAYER/grug_classes/textures/" .. texture
		return path ~= nil and read(path) ~= nil
	end
	for _, id in ipairs({"rime_mantle", "unbroken", "haven", "mend", "sidestep",
			"scout_sprint", "shield"}) do
		local def = icons.STATUS[id]
		check(def and def.kind == "buff" and ships(def.icon) or id == "shield",
			"S status " .. id .. " is a buff row whose icon ships")
	end
	local windows = 0
	for _, id in ipairs({"cold_shock", "retort", "clear_conscience", "follow_the_line",
			"parry", "ruination", "close_dance"}) do
		local status = icons.WINDOWS[id]
		local def = status and icons.STATUS[status]
		check(def and def.kind == "buff" and ships(def.icon),
			"S window " .. id .. " shows a status whose icon ships")
		windows = windows + 1
	end
	eq(windows, 7, "S the seven windows")
end

------------------------------------------------------------------------------
-- K: the real init.lua in a sandbox (the tools/r52_bench pattern).
------------------------------------------------------------------------------
local now_us = 1e9
local function any()
	return setmetatable({}, {__index = function() return any() end,
		__call = function() return nil end})
end
local Stack = {}
Stack.__index = Stack
local function ItemStack(spec)
	if type(spec) == "table" and getmetatable(spec) == Stack then
		local copy = setmetatable({name = spec.name, count = spec.count, fields = {}}, Stack)
		for k, v in pairs(spec.fields) do copy.fields[k] = v end
		return copy
	end
	local name = type(spec) == "string" and spec:match("^(%S*)") or ""
	return setmetatable({name = name, count = name == "" and 0 or 1, fields = {}}, Stack)
end
function Stack:get_name() return self.name end
function Stack:is_empty() return self.name == "" end
function Stack:get_count() return self.count end
function Stack:equals(other) return self:to_string() == other:to_string() end
function Stack:to_string()
	local keys = {}
	for k in pairs(self.fields) do keys[#keys + 1] = k end
	table.sort(keys)
	local parts = {self.name}
	for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(self.fields[k]) end
	return table.concat(parts, "|")
end
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

local LISTS = {"main", "grug_hotbar_store", "grug_bag1", "craft", "grug_weapon"}
local function new_inventory()
	local inv = {lists = {}}
	for _, l in ipairs(LISTS) do
		local list = {}
		for i = 1, 32 do list[i] = ItemStack("") end
		inv.lists[l] = list
	end
	function inv:get_size(l) return self.lists[l] and #self.lists[l] or 0 end
	function inv:get_stack(l, i) return ItemStack(self.lists[l][i]) end
	function inv:set_stack(l, i, s) self.lists[l][i] = ItemStack(s) end
	function inv:get_list(l)
		local out = {}
		for i, s in ipairs(self.lists[l] or {}) do out[i] = ItemStack(s) end
		return out
	end
	function inv:get_lists()
		local out = {}
		for _, l in ipairs(LISTS) do out[l] = self:get_list(l) end
		return out
	end
	function inv:contains_item(l, name)
		for _, s in ipairs(self.lists[l] or {}) do
			if s.name == name then return true end
		end
		return false
	end
	return inv
end
local function row(inv, l, n)
	local out = {}
	for i = 1, n do out[i] = inv.lists[l][i].name:gsub("^grug_abilities:", "") end
	return table.concat(out, ",")
end

local players = {}
local function new_player(name, class)
	local p = {name = name, class = class, ranks = {}, bonus = {}, hp = 100,
		inv = new_inventory(), wield = 1}
	function p:get_player_name() return self.name end
	function p:get_inventory() return self.inv end
	function p:is_player() return true end
	function p:get_hp() return self.hp end
	function p:get_pos() return {x = 0, y = 0, z = 0} end
	function p:get_wielded_item() return self.inv:get_stack("main", self.wield) end
	function p:get_wield_index() return self.wield end
	function p:get_meta() return ItemStack("x"):get_meta() end
	function p:get_properties() return {hp_max = 100} end
	function p:hud_get_hotbar_itemcount() return 8 end
	function p:hud_add() return 1 end
	function p:hud_change() end
	function p:hud_remove() end
	players[name] = p
	return p
end

local tools, input_api = {}, nil
local registered_classes = {warrior = {name = "Warrior", resource = "rage"},
	mage = {name = "Mage", resource = "mana"}, priest = {name = "Priest", resource = "mana"},
	scout = {name = "Scout"}, pc_archer = {name = "Archer"}, pc_brute = {name = "Brute"},
	pc_caster = {name = "Caster", resource = "mana"}}
local function with_any(t)
	return setmetatable(t, {__index = function() return any() end})
end
local callbacks = {}
local function capture(kind)
	return function(fn)
		callbacks[kind] = callbacks[kind] or {}
		table.insert(callbacks[kind], fn)
	end
end
local function fire(kind, ...)
	for _, fn in ipairs(callbacks[kind] or {}) do fn(...) end
end
local fake_core = with_any({
	register_on_dieplayer = capture("die"),
	register_on_leaveplayer = capture("leave"),
	get_modpath = function() return ROOT .. "/mods/PLAYER/grug_abilities" end,
	get_current_modname = function() return "grug_abilities" end,
	get_us_time = function() return now_us end,
	global_exists = function(n) return n == "grug_inventory" end,
	register_tool = function(name, def) tools[name] = def end,
	registered_items = {},
	get_item_group = function(name, group)
		return (group == "grug_ability" and name:find("^grug_abilities:")) and 1 or 0
	end,
	get_player_by_name = function(name) return players[name] end,
	log = function() end,
})
local melee_prepare, melee_finish
local transactions = {}
local fake_grug_core = with_any({
	get_melee_weapon = function() return ItemStack("") end,
	is_stunned = function() return false end,
	scale_player_damage = false,
	base_pool = function() return 100 end,
	get_player_level = function() return 30 end,
	register_native_melee_handler = function(prepare, finish)
		melee_prepare, melee_finish = prepare, finish
	end,
})
local fake_classes = with_any({
	registered_classes = registered_classes,
	registered_talents = {mend = {name = "Mend"}},
	get_class = function(p) return p.class end,
	get_class_def = function(p) return registered_classes[p.class] end,
	talent_rank = function(p, id) return p.ranks[id] or 0 end,
	-- The graph's accessor as LIVE answers it: per player and key.
	get_talent_bonus = function(p, key) return p.bonus and p.bonus[key] or 0 end,
	get_melee_bonus = function() return 0 end,
	get_race_perk = function() return nil end,
	get_max_mana = function() return 1000 end,
	talent_window_active = function() return false end,
	register_on_class_chosen = capture("class_chosen"),
})
local fake_inventory = with_any({
	HOTBAR_STORE = "grug_hotbar_store", HOTBAR_SIZE = 8, BAG_COUNT = 1,
	content_list = function(i) return "grug_bag" .. i end,
	get_cosmetic_hand = function() return nil end,
	hand_list = function() return "grug_weapon" end,
	melee_list = function() return "grug_weapon" end,
	equipment_changed = function() end,
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
	local chunk = setfenv(assert(loadfile(path)), env)
	local result = chunk()
	if path:find("/input%.lua$") then
		local real = result
		return function(api)
			input_api = api
			return real(api)
		end
	end
	return result
end
env._G = env
setfenv(assert(loadfile(ROOT .. "/mods/PLAYER/grug_abilities/init.lua")), env)()
local G = env.grug_abilities
check(G and G.registered.strike and input_api and melee_prepare and melee_finish,
	"K the real init.lua loads with its kits, input and melee handlers")

-- U: every shipped skill unchanged without talents, except K9. The oracle is
-- main's (681913a9) tooltip head and cost, range and cooldown rules.
do
	local function old_prefix(player, def)
		local cost_line
		if def.cost.mana_percent then
			cost_line = string.format("%g%% base mana", def.cost.mana_percent)
			if player then
				cost_line = cost_line .. " (" ..
					G.mana_cost(player, def.cost.mana_percent) .. " mana)"
			end
		elseif def.cost.mana then
			cost_line = def.cost.mana .. " mana"
		elseif def.cost.rage then
			cost_line = def.cost.rage .. " rage"
		else
			cost_line = "free"
		end
		local timing = def._grug_timing_line
		if player and def.kind == "swing" and def.charge then
			timing = G.effective_charge(player, def) .. " s charge"
		elseif player and def.cooldown_talent and not def.cast_interval then
			local cooldown = def.cooldown
			timing = cooldown > 0 and string.format("%g s cooldown", cooldown) or "no cooldown"
		end
		return def.name .. " (" .. def._grug_owner_line .. ")\n" .. cost_line .. ", " .. timing .. "\n"
	end
	local shipped = 0
	for id, def in pairs(G.registered) do
		shipped = shipped + 1
		local p = new_player("u_" .. id, def.class or "warrior")
		local same = G.effective_cost(p, def)
		local old = G.cost_for(p, def.cost, def.id)
		check(same.mana == old.mana and same.rage == old.rage, "U " .. id .. ": the cost as on main")
		eq(G.effective_cooldown(p, def), def.cooldown or 0, "U " .. id .. ": the cooldown as on main")
		eq(G.get_range(p, def), def.range or 4, "U " .. id .. ": the range as on main")
		eq(G.description_prefix(p, def), old_prefix(p, def), "U " .. id .. ": the tooltip head as on main")
		eq(G.description_prefix(nil, def), old_prefix(nil, def), "U " .. id .. ": the item's static head")
		-- Round 53 SCOUT: the Scout's casts take their calculator clocks
		-- (tools/r53_scout checks them).
		if def.kind == "cast" and def.class == "scout" then
			check(def.occupied_cast ~= nil and def.occupied_swing ~= nil,
				"U " .. id .. ": a Scout cast has its clock")
		elseif def.kind == "cast" then
			check(def.occupied_cast == 0 and def.occupied_swing == "weapon",
				"U " .. id .. ": a cast's clock as on main")
		else
			eq(def.occupied_cast, "weapon", "U " .. id .. ": a swing holds casts one interval (K9)")
		end
	end
	check(shipped >= 20, "U the shipped kits load (" .. shipped .. ")")
end

local cast_log = {}
local function probe(def)
	def.name = def.name or def.id
	def.description = def.description or def.id
	def.color = def.color or "#ffffff"
	def.target_kind = def.target_kind or "hostile"
	if def.kind == "cast" then
		def.cooldown = def.cooldown or 0
		def.cast = def.cast or function()
			cast_log[#cast_log + 1] = def.id
			return true
		end
	end
	G.register_ability(def)
	return G.registered[def.id]
end
local function wait(s) now_us = now_us + s * 1e6 end

-- K6: the rows exist before the class lanes register the skills.
do
	local hooks = {}
	local block = (read("mods/CORE/grug_sounds/init.lua") or ""):match("grug_sounds%.HOOKS = (%b{})")
	for event in (block or ""):gmatch('"([%w_]+)"') do hooks[event] = true end
	local CLIPS = {cast1 = true, cast2 = true, block = true, swing = true}
	for _, id in ipairs(NEW_IDS) do
		local class, family = NEW[id][1], NEW[id][2]
		eq(G.WEAPON_FX[id], family, "K6 the family of " .. id .. " (" .. class .. ")")
		local pose = G.SKILL_POSES[id]
		check(pose == nil or CLIPS[pose], "K6 " .. id .. " poses with clips or not at all")
		local cue = G.CAST_SOUNDS[id]
		check(cue == "weapon" or cue == "projectile" or cue == "silent" or hooks[cue],
			"K6 " .. id .. " has a cue: " .. tostring(cue))
	end
	eq(G.SKILL_POSES.broadstroke, "swing", "K6 Broadstroke swings")
	for _, id in ipairs({"fiery_spark", "cold_spark", "flame_lance", "true_draw",
			"split_shot"}) do
		eq(G.CAST_SOUNDS[id], "projectile", "K6 " .. id .. " sounds through its projectile")
	end
	-- The user's assignments (tools/r53_sks/assignments.json): a "shipped:"
	-- choice keeps that cue, a pick is its own hook with an approved file.
	local assignments = read("tools/r53_sks/assignments.json") or ""
	local approved = read("tools/r53_hooks/approved.txt") or ""
	local n = 0
	local list = assignments:match('"assignments": (%b[])') or ""
	for body in list:gmatch("%b{}") do
		local ability = body:match('"ability": "([%w_]+)"')
		local cue = body:match('"cue": "([^"]+)"')
		local choice = body:match('"choice": "([^"]+)"')
		if ability and cue and choice then
			n = n + 1
			local shipped = choice:match("^shipped:(.+)$")
			local event = cue == "cast" and "cast_" .. ability or
				cue == "impact" and ability .. "_impact" or
				cue == "projectile launch" and ability .. "_launch" or nil
			if shipped then
				local want = shipped == "swing" and "weapon" or shipped
				eq(G.CAST_SOUNDS[ability], want, "K6 " .. ability .. " keeps the shipped " .. shipped)
			elseif check(event and hooks[event], "K6 the hook of " .. ability .. "'s " .. cue) then
				if cue == "cast" then
					eq(G.CAST_SOUNDS[ability], event, "K6 " .. ability .. " casts with its pick")
				end
				check(approved:find("grug_sounds_" .. event .. ".ogg, R53 SKS " .. choice, 1, true),
					"K6 " .. event .. " is the approved file " .. choice)
				local shipped_file = read("mods/CORE/grug_sounds/sounds/grug_sounds_" .. event .. ".ogg")
				check(shipped_file ~= nil and shipped_file ==
					read("tools/r53_sks/out/" .. choice .. ".ogg"),
					"K6 grug_sounds_" .. event .. ".ogg is the pick's file unchanged")
			end
		end
	end
	eq(n, 26, "K6 the 26 assignments")
end

-- The family keys on the cast path.
local bolt = probe({id = "pf_bolt", class = "pc_caster", kind = "cast", tags = {"fire", "paid"},
	cost = {mana_percent = 10}, cooldown = 8, range = 20})
local cold = probe({id = "pf_cold", class = "pc_caster", kind = "cast", tags = {"frost"},
	talent_gated = true, talent = "rime_cold", transforms = "pf_bolt",
	cost = {mana_percent = 10}, cooldown = 8, range = 20})
do
	local p = new_player("k_fam", "pc_caster")
	eq(G.family_bonus(p, bolt, "cost_pct"), 0, "K a key nobody has adds nothing")
	eq(G.effective_cost(p, bolt).mana, 10, "K untalented: 10 % of a 100 pool")
	eq(G.effective_cooldown(p, bolt), 8, "K untalented: the cooldown as defined")
	eq(G.get_range(p, bolt), 20, "K untalented: the range as defined")
	eq(G.description_prefix(p, bolt), "pf_bolt (Caster)\n10% base mana (10 mana), 8 s cooldown\n",
		"K untalented: today's tooltip line")
	p.bonus = {["cost_pct:fire"] = -10, ["cost_pct:pf_bolt"] = -5, ["cost_pct:frost"] = -50,
		["cooldown_sub:pf_bolt"] = 2, ["range_add:fire"] = 3, ["range_add:pf_cold"] = 1}
	eq(G.family_bonus(p, bolt, "cost_pct"), -15, "K cost_pct by id and by tag, summed")
	eq(G.effective_cost(p, bolt).mana, 9, "K cost_pct before the mana: 8.5 % of 100 rounds to 9")
	eq(G.effective_cooldown(p, bolt), 6, "K cooldown_sub off the cooldown")
	eq(G.get_range(p, bolt), 23, "K range_add on the range")
	eq(G.description_prefix(p, bolt), "pf_bolt (Caster)\n8.5% base mana (9 mana), 6 s cooldown\n",
		"K the tooltip shows the player's cost and cooldown")
	eq(G.family_bonus(p, cold, "cost_pct"), -50, "K a transformation reads its own id and tags")
	eq(G.get_range(p, cold), 21, "K ...not its base's")
	p.bonus["cooldown_sub:pf_bolt"] = 20
	eq(G.effective_cooldown(p, bolt), 0, "K a cooldown never below 0")
	check(not pcall(probe, {id = "pf_bad_tag", class = "pc_caster", kind = "cast", tags = {"Fire"}}),
		"K a tag is a lower-case word")
	-- The cast path charges and refuses by the same cost.
	p.bonus = {}
	local reason = select(2, input_api.cast_refusal(p, bolt))
	eq(reason, "cost", "K a player without mana: the refusal reason is the cost")
end

-- The swing path: the proc's cost, the plain swing's damage_pct, the
-- swing callback.
local mob = {get_pos = function() return {x = 0, y = 0, z = 2} end,
	is_player = function() return false end, punches = 0}
function mob.punch(self) self.punches = self.punches + 1 end
G.swing_stats = function() return 10, 1.0 end
G.base_swing_interval = function() return 1.0 end
G.valid_target = function() return true end
fake_grug_core.combat_ray = function()
	return {status = "target", reason = "target", target = mob}
end
fake_grug_core.scale_player_damage = function(_, _, d) return d end
fake_grug_core.begin_authoritative_swing = function(_, _, t)
	transactions[#transactions + 1] = t
	return t
end
fake_grug_core.end_authoritative_swing = function() end
fake_grug_core.valid_authoritative_swing = function() return true end
fake_grug_core.get_authoritative_swing_context = function(token) return token end
local strike = G.registered.strike
local cleave = probe({id = "pf_cleave", class = "pc_brute", kind = "swing", cost = {rage = 25},
	proc_swing = function() return 30, 1, function() end end,
	cost_adjust = function(player, _, cost)
		cost.rage = cost.rage - (player.relentless or 0)
		return cost
	end})
local axe = probe({id = "pf_axe", class = "pc_brute", kind = "swing"})
local function swing(p, def)
	wait(5)
	local before = #transactions
	local ok = input_api.swing(p, def)
	return ok and transactions[before + 1] or nil
end
local function land(p, t, result)
	local context = melee_prepare(p, mob, t)
	melee_finish(context, result)
end
do
	local p = new_player("k_swing", "warrior")
	eq(strike.occupied_cast, "weapon", "K9 Strike holds casts one weapon interval by default")
	eq(swing(p, strike).raw_damage, 10, "K the plain swing: the weapon's 10")
	p.bonus = {["damage_pct:blade"] = 20}
	eq(swing(p, strike).raw_damage, 12, "K damage_pct:blade on Strike, a blade")
	registered_classes.pc_brute.resource = "rage"
	local brute = new_player("k_brute", "pc_brute")
	brute.bonus = {["damage_pct:blade"] = 20}
	brute.wield = 1
	eq(swing(brute, axe).raw_damage, 10, "K no tag, no damage_pct")
	G.add_rage(brute, 100)
	brute.bonus = {["cost_pct:pf_cleave"] = -10, ["damage_pct:pf_cleave"] = 50}
	brute.relentless = 3
	local t = swing(brute, cleave)
	eq(t and t.raw_damage, 30, "K a proc's damage is the kit's (damage_pct reaches the plain swing only)")
	eq(t and t.proc_cost.rage, 20, "K the proc cost: 25 rage, 10 % off (23), 3 off by cost_adjust")
	eq(cleave.cost.rage, 25, "K ...the definition's cost untouched")
	eq(G.effective_cost(brute, cleave).rage, 20, "K the cast path's cost is the same")
	-- K9: the swing holds casts back for the weapon's interval.
	local caster_p = new_player("k_k9", "pc_caster")
	local zap = probe({id = "pf_zap", class = "pc_caster", kind = "cast", cost = {}})
	check(swing(caster_p, strike) ~= nil, "K9 a swing lands")
	local message, why = input_api.cast_refusal(caster_p, zap)
	eq(why, "busy", "K9 ...then a cast waits (" .. tostring(message) .. ")")
	wait(0.99)
	eq(select(2, input_api.cast_refusal(caster_p, zap)), "busy", "K9 ...for the weapon's interval")
	wait(0.01)
	eq(input_api.cast_refusal(caster_p, zap), nil, "K9 ...and no longer")
	-- A late swing keeps the swing clock's catch-up: casts wait only until
	-- the next swing is due (review F1).
	check(swing(caster_p, strike) ~= nil, "K9 a late swing lands (0.1 s catch-up)")
	wait(0.89)
	eq(select(2, input_api.cast_refusal(caster_p, zap)), "busy", "K9 ...casts wait until the next swing is due")
	wait(0.02)
	eq(input_api.cast_refusal(caster_p, zap), nil, "K9 ...0.9 s, not a full interval")

	-- The swing callback.
	local landed = {}
	G.register_on_swing(function(player, sw)
		if player.ruination then
			return {damage_mult = 1.15, rage_add = 2, on_landed = function(_, s)
				landed[#landed + 1] = s.def.id
			end}
		end
	end)
	G.register_on_swing(function(_, sw)
		if sw.def.id == "strike" and not sw.proc then return {damage_add = 5} end
	end)
	local w = new_player("k_cb", "warrior")
	eq(swing(w, strike).raw_damage, 15, "K a callback's add (no window open)")
	w.ruination = true
	local tr = swing(w, strike)
	near(tr.raw_damage, 10 * 1.15 + 5, "K raw x every multiplier + every add, before the scaling")
	near(tr.scaled_damage, 10 * 1.15 + 5, "K ...crossing the one scaling pass")
	land(w, tr, {landed = false})
	eq(G.get_rage(w), 0, "K a missed swing gains nothing")
	eq(#landed, 0, "K ...and runs no on_landed")
	tr = swing(w, strike)
	land(w, tr, {landed = true, grant_rage = true})
	eq(G.get_rage(w), 10, "K a landed swing: 8 rage plus the callback's 2")
	eq(table.concat(landed, ","), "strike", "K ...and its on_landed once, with the swing")
	-- A proc swing gets the callbacks too.
	local b2 = new_player("k_cb2", "pc_brute")
	b2.ruination = true
	G.add_rage(b2, 100)
	local pt = swing(b2, cleave)
	near(pt and pt.raw_damage, 30 * 1.15, "K a proc swing is multiplied too")
	land(b2, pt, {landed = true, grant_rage = true})
	eq(landed[#landed], "pf_cleave", "K ...and its on_landed runs")
end

-- The clock seams: a function cast_interval, occupied_cast and
-- occupied_swing; the timing line shows the base.
do
	local loose = probe({id = "pf_loose", class = "pc_archer", kind = "cast", cost = {},
		cast_interval = function(player) return player and player.cadence or 0.85 end,
		occupied_cast = function(player) return player and player.occupied or 0.5 end,
		occupied_swing = function(player) return player and player.held or 0.4 end})
	eq(loose._grug_timing_line, "0.85 s cast interval", "K the timing line shows the base")
	local p = new_player("k_clock", "pc_archer")
	p.cadence, p.occupied, p.held = 0.65, 0.3, 0.2
	check(G.try_cast(p, loose, nil, function() end), "K the cast fires")
	eq(select(2, input_api.cast_refusal(p, loose)), "interval", "K the interval is armed")
	wait(0.31)
	eq(select(2, input_api.cast_refusal(p, loose)), "interval", "K ...the player's 0.65 s, not 0.85")
	wait(0.35)
	eq(input_api.cast_refusal(p, loose), nil, "K ...over at 0.66 s")
	local zap = G.registered.pf_zap
	check(G.try_cast(p, loose, nil, function() end), "K again")
	eq(select(2, input_api.cast_refusal(p, probe({id = "pf_other", class = "pc_archer",
		kind = "cast", cost = {}}))), "busy", "K the function occupied_cast holds casts")
	wait(0.31)
	eq(input_api.cast_refusal(p, G.registered.pf_other), nil, "K ...for the player's 0.3 s")
	-- occupied_swing as a function: the next swing waits the player's value.
	p.class = "warrior"
	wait(5)
	input_api.delay_strike(p, loose)
	wait(0.19)
	check(not input_api.swing(p, strike), "K the function occupied_swing holds the swing")
	wait(0.02)
	check(input_api.swing(p, strike), "K ...for the player's 0.2 s")
	check(not pcall(probe, {id = "pf_bad_clock", class = "pc_archer", kind = "cast",
		cast_interval = function() return 0 end}), "K a function interval's base must be > 0")
	check(not pcall(probe, {id = "pf_bad_weapon", class = "pc_archer", kind = "cast",
		occupied_cast = "weapon"}), "K \"weapon\" holds casts only after a swing")
	local _ = zap
end

-- The refusal reasons the held fallback reads.
do
	local p = new_player("k_why", "pc_caster")
	local spell = probe({id = "pf_spell", class = "pc_caster", kind = "cast", cost = {},
		cooldown = 4, cast_interval = 1})
	eq(select(2, input_api.cast_refusal(p, spell)), nil, "K ready: no reason")
	G.try_cast(p, spell, nil, function() end)
	eq(select(2, input_api.cast_refusal(p, spell)), "cooldown", "K the cooldown first")
	local other = probe({id = "pf_spell2", class = "pc_caster", kind = "cast", cost = {},
		cast_interval = 1, occupied_cast = 0.5})
	G.try_cast(p, other, nil, function() end)
	eq(select(2, input_api.cast_refusal(p, other)), "interval", "K then the cast interval")
	eq(select(2, input_api.cast_refusal(p, G.registered.pf_zap)), "busy", "K then the action clock")
	eq(select(2, input_api.cast_refusal(new_player("k_why2", "mage"), spell)), "class",
		"K another class")
	eq(select(2, input_api.cast_refusal(p, cold)), "locked", "K a locked skill")
end

-- K7: the basic attack first on a new character's hotbar.
do
	probe({id = "pa_shot", class = "pc_archer", kind = "cast", cost = {}, basic_attack = true})
	probe({id = "pa_step", class = "pc_archer", kind = "cast", cost = {}})
	probe({id = "pb_bash", class = "pc_brute", kind = "cast", cost = {}})
	-- The marked basic attack goes first, whatever its place in the file,
	-- then the class's other starters in file order, then Strike.
	local archer = new_player("k7_archer", "pc_archer")
	fire("class_chosen", archer, "pc_archer")
	eq(row(archer.inv, "main", 6), "pa_shot,pf_loose,pf_other,pa_step,strike,",
		"K7 the basic attack (basic_attack = true) in slot 1, Strike after the starters")
	local brute = new_player("k7_brute", "pc_brute")
	fire("class_chosen", brute, "pc_brute")
	eq(brute.inv.lists.main[1].name, "grug_abilities:strike",
		"K7 without a marked basic attack Strike is the basic attack, slot 1")
	local spark = probe({id = "pc_spark", class = "pc_caster", kind = "cast", cost = {},
		transforms = "strike"})
	local caster = new_player("k7_caster", "pc_caster")
	fire("class_chosen", caster, "pc_caster")
	eq(caster.inv.lists.main[1].name, "grug_abilities:pf_bolt",
		"K7 a transform of Strike stays where its class file puts it (registered first there)")
	check(G.current_form(caster, strike) == spark, "K8 the caster's basic attack is its Strike transform")
	check(not pcall(probe, {id = "pa_bad", class = "pc_archer", kind = "cast", basic_attack = true,
		talent_gated = true, transforms = "pa_shot"}), "K7 a transform is no marked basic attack")
end

------------------------------------------------------------------------------
-- F: K8, the held fallback, through the REAL input.lua.
------------------------------------------------------------------------------
do
	vector = {}
	function vector.new(x, y, z) return {x = x, y = y, z = z} end
	function vector.copy(v) return {x = v.x, y = v.y, z = v.z} end
	function vector.add(a, b) return vector.new(a.x + b.x, a.y + b.y, a.z + b.z) end
	function vector.subtract(a, b) return vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
	function vector.multiply(v, k) return vector.new(v.x * k, v.y * k, v.z * k) end
	function vector.distance(a, b)
		local d = vector.subtract(a, b)
		return math.sqrt(d.x * d.x + d.y * d.y + d.z * d.z)
	end
	local EYE = vector.new(0, 1.47, 0)
	local clock = 0
	local swings, casts, flashes = {}, {}, {}
	local mobf = {kind = "mob"}
	function mobf:get_pos() return vector.new(0, 1, 2) end
	function mobf:is_player() return false end
	function mobf:get_luaentity() return {name = "test:mob", health = 10, _cmi_is_mob = true, temp = {}} end
	local HIT = {type = "object", ref = mobf, intersection_point = vector.new(0, 1.47, 2)}
	local loaded = {}
	core = {
		registered_nodes = {}, registered_entities = {["__builtin:item"] = {on_punch = function() end}},
		get_us_time = function() return clock end,
		check_player_privs = function() return true end,
		get_node_or_nil = function() return {name = "air"} end,
		is_protected = function() return false end,
		get_item_group = function(name, group)
			return group == "grug_ability" and name:sub(1, 15) == "grug_abilities:" and 1 or 0
		end,
		raycast = function()
			local done = false
			return function()
				if done then return nil end
				done = true
				return HIT
			end
		end,
		override_item = function() end,
		register_on_mods_loaded = function(f) loaded[#loaded + 1] = f end,
		register_on_dieplayer = function() end,
		register_on_leaveplayer = function() end,
		register_on_joinplayer = function() end,
	}
	grug_mobs = {evade_notice = function() end}
	grug_inventory = {HOTBAR_STORE = "grug_hotbar_store"}
	rawset(_G, "ItemStack", function() return {get_tool_capabilities = function() return {} end} end)
	grug_core = {
		combat_eye_pos = function() return vector.copy(EYE) end,
		combat_actor = function(ref) return ref end,
		aim_raycast = function(o, d, liquids) return core.raycast(o, d, true, liquids) end,
		unseen_by = function() return false end,
		is_stunned = function() return false end,
		player_has_live_mount = function() return false end,
		register_on_stun = function() end,
		combat_ray = function()
			return {target = mobf, distance = 2, pointed = HIT, status = "target", reason = "hostile"}
		end,
	}
	local function stack(name)
		local st = {name = name or "", meta = {}}
		function st:get_name() return self.name end
		function st:get_meta()
			local m = self.meta
			return {get_string = function(_, k) return m[k] or "" end,
				set_string = function(_, k, v) m[k] = v ~= "" and v or nil end}
		end
		return st
	end
	local defs = {
		strike = {id = "strike", kind = "swing", target_kind = "hostile", name = "Strike"},
		blow = {id = "blow", kind = "swing", target_kind = "hostile", name = "Blow"},
		spark = {id = "spark", kind = "cast", target_kind = "hostile", name = "Spark"},
		bolt = {id = "bolt", kind = "cast", target_kind = "hostile", name = "Bolt"},
		heal = {id = "heal", kind = "cast", target_kind = "friendly", name = "Heal"},
		loose = {id = "loose", kind = "cast", target_kind = "hostile", name = "Loose"},
	}
	local basic = defs.strike
	local refusals = {} -- id -> {message, why}
	grug_abilities = {
		registered = defs,
		is_unlocked = function() return true end,
		current_form = function(_, def) return def == defs.strike and basic or def end,
		get_range = function() return 3 end,
		valid_target = function(_, ref, kind) return kind == "hostile" and ref == mobf end,
		evading_target = function() return false end,
		support_refused = function() return false end,
		flash = function(_, message) flashes[#flashes + 1] = message end,
		try_cast = function(_, def)
			casts[#casts + 1] = def.id
			return true
		end,
	}
	local wielded = "bolt"
	local input = dofile(ROOT .. "/mods/PLAYER/grug_abilities/input.lua")({
		selected = function() return defs[wielded] end,
		swing = function(_, def) swings[#swings + 1] = def.id end,
		cast_refusal = function(_, def)
			local r = refusals[def.id]
			if r then return r[1], r[2] end
			return nil
		end,
		swing_refusal = function(_, def)
			local r = refusals[def.id]
			return r and r[1] or nil
		end,
		delay_strike = function() end,
		within_hand_reach = function() return true end,
	})
	for _, f in ipairs(loaded) do f() end
	local controls = {dig = false, place = false}
	local main = {stack("grug_abilities:bolt")}
	local player = {
		get_player_name = function() return "f" end,
		get_player_control = function() return controls end,
		get_inventory = function()
			return {get_stack = function(_, _, i) return main[i] end,
				set_stack = function(_, _, i, st) main[i] = st end}
		end,
		get_wield_list = function() return "main" end,
		get_wield_index = function() return 1 end,
		get_wielded_item = function() return stack("grug_abilities:" .. wielded) end,
		set_wielded_item = function() return true end,
		get_hp = function() return 20 end,
		get_pos = function() return vector.new(0, 0, 0) end,
		get_look_dir = function() return vector.new(0, 0, 1) end,
	}
	local function list(t) return #t > 0 and table.concat(t, ",") or "-" end
	-- One press held for `steps` input passes on the mob, then released.
	local function run(item, steps)
		wielded = item
		controls.dig = false
		clock = clock + 2000000 -- past the 1 s a repeated notice waits
		for _ = 1, 4 do clock = clock + 50000; input.step(player) end
		swings, casts, flashes = {}, {}, {}
		controls.dig = true
		for _ = 1, steps do clock = clock + 50000; input.step(player) end
		controls.dig = false
		for _ = 1, 4 do clock = clock + 50000; input.step(player) end
		return ("casts=%s swings=%s flashes=%d"):format(list(casts), list(swings), #flashes)
	end

	-- Warrior: the basic attack is Strike, a swing.
	basic = defs.strike
	refusals = {bolt = {"Not enough rage.", "cost"}}
	eq(run("bolt", 1), "casts=- swings=strike flashes=1",
		"F warrior: a refused paid cast swings Strike once, its refusal reported once")
	eq(run("bolt", 3), "casts=- swings=strike,strike,strike flashes=1",
		"F warrior: held, each pass falls back (the swing clock paces it)")
	refusals = {bolt = {"You are still busy.", "busy"}}
	eq(run("bolt", 3), "casts=- swings=- flashes=1", "F warrior: the action clock: no fallback")
	refusals = {blow = {"Not enough rage."}}
	eq(run("blow", 1), "casts=- swings=strike flashes=1", "F warrior: a refused swing skill swings Strike")
	refusals = {}
	eq(run("blow", 1), "casts=- swings=blow flashes=0", "F warrior: a ready swing skill swings itself")

	-- Mage and Priest: the basic attack is a cast (Fiery Spark, Smite).
	for _, class in ipairs({"mage", "priest"}) do
		basic = defs.spark
		refusals = {bolt = {"Not enough mana.", "cost"}}
		eq(run("bolt", 1), "casts=spark swings=- flashes=1",
			"F " .. class .. ": a refused paid cast casts the basic attack once, silently")
		refusals = {bolt = {"Bolt is not ready.", "cooldown"}}
		eq(run("bolt", 2), "casts=spark,spark swings=- flashes=1",
			"F " .. class .. ": a cooldown falls back each pass (the cast interval paces it)")
		refusals = {bolt = {"Bolt is not ready.", "cooldown"},
			spark = {"Spark cast interval is not ready.", "interval"}}
		eq(run("bolt", 2), "casts=- swings=- flashes=1",
			"F " .. class .. ": the basic attack's own interval: nothing, quietly")
		refusals = {bolt = {"Bolt cast interval is not ready.", "interval"}}
		eq(run("bolt", 2), "casts=- swings=- flashes=1",
			"F " .. class .. ": the refused cast's interval: no fallback")
		refusals = {spark = {"Not enough mana.", "cost"}}
		eq(run("spark", 2), "casts=- swings=- flashes=1",
			"F " .. class .. ": the basic attack refused: no fallback")
		refusals = {}
		eq(run("heal", 2), "casts=heal,spark swings=- flashes=0",
			"F " .. class .. ": a support skill at a hostile fires once, held the basic attack")
		refusals = {blow = {"Not enough rage."}}
		eq(run("blow", 1), "casts=spark swings=- flashes=1",
			"F " .. class .. ": a refused swing skill falls back to the cast basic attack")
	end

	-- Scout: Strike is the basic attack; Loose is an LMB bow cast (Round 53
	-- SCOUT: the draw is gone).
	basic = defs.strike
	refusals = {bolt = {"No arrows.", "cost"}}
	eq(run("bolt", 1), "casts=- swings=strike flashes=1", "F scout: a refused shot swings Strike")
	refusals = {}
	eq(run("loose", 1), "casts=loose swings=- flashes=0", "F scout: Loose's LMB at a foe shoots")
end

------------------------------------------------------------------------------
-- A: the cone and the fall height.
------------------------------------------------------------------------------
do
	vector = {}
	function vector.new(x, y, z)
		if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
		return {x = x or 0, y = y or 0, z = z or 0}
	end
	function vector.copy(v) return vector.new(v) end
	function vector.offset(v, x, y, z) return vector.new(v.x + x, v.y + y, v.z + z) end
	function vector.add(a, b) return vector.new(a.x + b.x, a.y + b.y, a.z + b.z) end
	function vector.subtract(a, b) return vector.new(a.x - b.x, a.y - b.y, a.z - b.z) end
	function vector.multiply(a, s) return vector.new(a.x * s, a.y * s, a.z * s) end
	function vector.length(v) return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
	function vector.distance(a, b) return vector.length(vector.subtract(a, b)) end
	local nodes = {}
	local function key(x, y, z) return x .. "," .. y .. "," .. z end
	local function fill(x1, y1, z1, x2, y2, z2, name)
		for x = x1, x2 do for y = y1, y2 do for z = z1, z2 do nodes[key(x, y, z)] = name end end end
	end
	local function node_at(x, y, z)
		if y < -40 then return nil end
		return nodes[key(x, y, z)] or "air"
	end
	local REGISTERED = {air = {walkable = false, pointable = false}, stone = {walkable = true}}
	local function raycast(from, to)
		local hits = {}
		local d = vector.subtract(to, from)
		local steps = math.max(1, math.ceil(vector.length(d) / 0.01))
		local function cell(p) return math.floor(p.x + 0.5), math.floor(p.y + 0.5), math.floor(p.z + 0.5) end
		local px, py, pz = cell(from)
		for i = 1, steps do
			local p = vector.add(from, vector.multiply(d, i / steps))
			local x, y, z = cell(p)
			if x ~= px or y ~= py or z ~= pz then
				local def = REGISTERED[node_at(x, y, z) or "stone"]
				if def.pointable ~= false then
					hits[#hits + 1] = {type = "node", under = {x = x, y = y, z = z}, intersection_point = p}
				end
				px, py, pz = x, y, z
			end
		end
		local index = 0
		return function() index = index + 1; return hits[index] end
	end
	local objects = {}
	local function object(name, x, y, z, player)
		local o = {name = name, pos = vector.new(x, y, z), player = player}
		function o:is_player() return self.player == true end
		function o:get_pos() return vector.copy(self.pos) end
		function o:get_player_name() return self.name end
		function o:get_luaentity() return not self.player and {name = self.name, _grug_cbox = {0, 0, 0, 0, 1.6, 0}} or nil end
		function o:get_look_horizontal() return 0 end -- facing +z
		objects[#objects + 1] = o
		return o
	end
	core = {
		get_node_or_nil = function(pos)
			local name = node_at(pos.x, pos.y, pos.z)
			return name and {name = name} or nil
		end,
		registered_nodes = REGISTERED,
		raycast = raycast,
		get_objects_in_area = function(minp, maxp)
			local out = {}
			for _, o in ipairs(objects) do
				local p = o.pos
				if p.x >= minp.x and p.x <= maxp.x and p.y >= minp.y and p.y <= maxp.y and
						p.z >= minp.z and p.z <= maxp.z then
					out[#out + 1] = o
				end
			end
			return out
		end,
		yaw_to_dir = function(yaw) return vector.new(-math.sin(yaw), 0, math.cos(yaw)) end,
		register_on_leaveplayer = function() end,
		log = function() end,
	}
	grug_core = {}
	dofile(ROOT .. "/mods/CORE/grug_core/area.lua")
	local area = grug_core.area
	fill(-20, -1, -20, 20, -1, 20, "stone") -- ground: top at y = -0.5
	local caster = object("caster", 0, -0.5, 0, true)
	local ahead = object("ahead", 0, -0.5, 3)
	local edge = object("edge", 1.5, -0.5, 2.5) -- 31° off the facing
	local wide = object("wide", 2.5, -0.5, 2.5) -- 45° off
	local behind = object("behind", 0, -0.5, -2)
	local far = object("far", 0, -0.5, 5.5)
	local high = object("high", 0, 3.5, 2)
	local inside = object("inside", 0, -0.5, 0.005)
	local friend = object("friend", -0.5, -0.5, 2, true)
	local walled = object("walled", -2, -0.5, 4)
	fill(-2, 0, 3, -2, 2, 3, "stone") -- a wall between the caster and "walled"
	local function names(list)
		local out = {}
		for i, o in ipairs(list) do out[i] = o.name end
		return table.concat(out, ",")
	end
	local hostile = function(obj) return obj ~= friend end
	eq(names(area.cone(caster, {radius = 5, angle = 70, filter = hostile})), "inside,edge,ahead",
		"A a 70° 5 m cone: in front, nearest first; not beside, behind, too far, too high, a friend, behind a wall")
	eq(names(area.cone(caster, {radius = 5, angle = 100, filter = hostile})), "inside,edge,ahead,wide",
		"A a 100° cone takes the one 45° off")
	eq(names(area.cone(caster, {radius = 5, angle = 100, filter = hostile, cap = 2})), "inside,edge",
		"A the cap keeps the nearest")
	eq(names(area.cone(caster, {radius = 5, angle = 70, filter = hostile, dir = vector.new(0, 0, -1)})),
		"inside,behind", "A opts.dir turns the cone")
	eq(names(area.cone(caster, {radius = 5, angle = 70, band = 5, filter = hostile})),
		"inside,high,edge,ahead", "A a wider band reaches up (nearest by horizontal distance)")
	local _ = {far, walled}

	-- The fall height: the anchor column alone, then sampled at 0.6 x R.
	local anchor = vector.new(10, -0.5, 10)
	eq(area.fall_height(anchor), area.CEILING_CAP, "A open sky: the cap")
	eq(area.fall_height(anchor, 5), area.CEILING_CAP, "A open sky around too")
	fill(13, 4, 9, 13, 4, 11, "stone") -- an overhang 3 m east, its underside at 3.5
	eq(area.fall_height(anchor), area.CEILING_CAP, "A the anchor's column alone misses the overhang")
	near(area.fall_height(anchor, 5), 4 - 0.5 - (-0.5) - 0.5, "A at 0.6 x 5 m the overhang lowers the start")
	near(area.fall_height(anchor, 2), area.CEILING_CAP, "A a small area samples inside it, under the sky")
	-- A slope rising into a sample column and rock beside the area lower nothing.
	local hill = vector.new(-10, -0.5, -10)
	fill(-7, 0, -11, -7, 2, -9, "stone") -- the ground rises 3 nodes 3 m east, open above
	fill(-13, 0, -11, -13, 14, -9, "stone") -- solid rock 3 m west, all the way up
	eq(area.fall_height(hill, 5), area.CEILING_CAP, "A a rising slope and solid rock beside: still the cap")
end

if failures == 0 then
	print("R53 HOOKS PORTABLE PASS checks=" .. checks)
else
	error(("R53 HOOKS PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
