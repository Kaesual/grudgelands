-- Round 78 lane SMALL portable test (LuaJIT): the seven small fixes, each
-- against the shipped code (whole files where they load under a stub, the
-- changed function cut out of its file where the file needs the engine).
--
--   P  the potion cooldown: 30 s, and its "Potion cooldown" status in the row
--      from the start to the end, again after a relog (potion.lua,
--      status.lua, status_icons.lua, hud_layout.lua)
--   R  repair costs half (grug_repair/service.lua)
--   G  guard posts: free_spot_near at street level beside lamp posts, and a
--      guard on a lamp post moved down (grug_mobs/camps.lua)
--   T  towering: the placer's own body never blocks, other bodies do
--      (grug_core/placement.lua)
--   A  the Claim Stone activates with anthracite in any mix
--      (grug_housing/api.lua)
--   O  Ore Sense skips a protected deposit (grug_guild/effect.lua)
--   F  a flying mount's raised retry (grug_mounts/entity.lua)
--
-- Usage (repo root): luajit tools/r78_small/portable_test.lua [REPO]

local repo = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
end
local function eq(actual, expected, label)
	check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end

local function read(path)
	local file = assert(io.open(repo .. "/" .. path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end

-- The text of `file` from `first` (included) to the end of the function that
-- starts at `last_header` (its first "\nend\n"), run with `epilogue` appended
-- in `env` (falling back to _G).
local function extract(file, first, last_header, epilogue, env)
	local source = read(file)
	local start = assert(source:find(first, 1, true), file .. ": " .. first)
	local head = assert(source:find(last_header, start, true), file .. ": " .. last_header)
	local stop = assert(source:find("\nend\n", head, true), file .. ": end of " .. last_header)
	local chunk = assert(loadstring(source:sub(start, stop + 4) .. epilogue, "=" .. file))
	setfenv(chunk, setmetatable(env, {__index = _G}))
	return chunk()
end

------------------------------------------------------------------------------
-- The engine stub shared by the whole-file loads.
------------------------------------------------------------------------------
local now_us, now_s = 5e9, 1000000
os.time = function() return now_s end
local callbacks = {join = {}, leave = {}, die = {}}
core = {
	get_us_time = function() return now_us end,
	register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
	register_on_leaveplayer = function(fn) callbacks.leave[#callbacks.leave + 1] = fn end,
	register_on_dieplayer = function(fn) callbacks.die[#callbacks.die + 1] = fn end,
	register_globalstep = function() end,
	get_connected_players = function() return {} end,
	registered_nodes = {},
	registered_items = {},
	registered_entities = {},
	register_craftitem = function(name, def) core.registered_items[name] = def end,
	log = function() end,
}

local function fake_player(name)
	local p = {name = name, huds = {}, next_id = 0, meta = {}, hp = 20}
	function p:is_player() return true end
	function p:get_player_name() return self.name end
	function p:get_hp() return self.hp end
	function p:get_pos() return self.pos end
	function p:get_properties() return {collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}} end
	function p:get_meta()
		local meta = self.meta
		return {
			get_string = function(_, key) return meta[key] or "" end,
			set_string = function(_, key, value) meta[key] = value end,
		}
	end
	function p:hud_add(def)
		self.next_id = self.next_id + 1
		local copy = {}
		for k, v in pairs(def) do copy[k] = v end
		self.huds[self.next_id] = copy
		return self.next_id
	end
	function p:hud_change(id, key, value) self.huds[id][key] = value end
	return p
end

------------------------------------------------------------------------------
-- P. The potion cooldown and its status.
------------------------------------------------------------------------------
grug_core = {}
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
dofile(repo .. "/mods/CORE/grug_core/status_icons.lua")
dofile(repo .. "/mods/CORE/grug_core/status.lua")
grug_traders = {}
dofile(repo .. "/mods/ENTITIES/grug_traders/potion.lua")
eq(grug_traders.POTION_COOLDOWN, 30, "P the shared potion cooldown is 30 s (ruling 1)")

local icons = grug_core.status_icons
local def = icons.STATUS.potion_cooldown
check(def ~= nil, "P potion_cooldown is a registered status")
eq(def and def.kind, "neutral", "P ...of the neutral kind")
eq(def and def.name, "Potion cooldown", "P ...named Potion cooldown")

local function potion_entry(player)
	for _, entry in ipairs(grug_core.status_effects(player)) do
		if entry.id == "potion_cooldown" then return entry end
	end
	return nil
end
local function row_texture(player)
	local first = player.huds[1] -- the first slot's icon
	return first and first.text or ""
end

local ada = fake_player("ada")
for _, fn in ipairs(callbacks.join) do fn(ada) end
eq(potion_entry(ada), nil, "P no status before a potion")
grug_traders.start_potion_cooldown(ada)
local entry = potion_entry(ada)
check(entry ~= nil, "P the status appears when the cooldown starts")
eq(entry and entry.caption, "30s", "P ...with the full countdown")
eq(entry and entry.kind, "neutral", "P ...neutral")
eq(entry and entry.name, "Potion cooldown", "P ...labelled Potion cooldown")
check(row_texture(ada):find("grug_traders_item_potion_healing_weak.png", 1, true) ~= nil and
	row_texture(ada):find("grug_status_frame_neutral.png", 1, true) ~= nil,
	"P the row shows the potion on the neutral plate at once: " .. row_texture(ada))
now_s, now_us = now_s + 29, now_us + 29e6
entry = potion_entry(ada)
eq(entry and entry.caption, "1s", "P one second left after 29 s")
eq(grug_traders.potion_cooldown_left(ada), 1, "P ...the cooldown agrees")
now_s, now_us = now_s + 1, now_us + 1e6
eq(potion_entry(ada), nil, "P the status ends with the cooldown at 30 s")
eq(grug_traders.potion_cooldown_left(ada), 0, "P ...which is over")
-- A relog while it runs: the runtime statuses go, the source reads it back.
grug_traders.start_potion_cooldown(ada)
now_s, now_us = now_s + 10, now_us + 10e6
for _, fn in ipairs(callbacks.leave) do fn(ada) end
local ada2 = fake_player("ada")
ada2.meta = ada.meta
now_s, now_us = now_s + 5, now_us + 5e6
for _, fn in ipairs(callbacks.join) do fn(ada2) end
entry = potion_entry(ada2)
eq(entry and entry.caption, "15s", "P after a relog the status shows the time still left")
-- A death clears stored statuses, never this one while it runs.
for _, fn in ipairs(callbacks.die) do fn(ada2) end
check(potion_entry(ada2) ~= nil, "P ...and after a death")
now_s, now_us = now_s + 15, now_us + 15e6
eq(potion_entry(ada2), nil, "P ...and ends on time")

------------------------------------------------------------------------------
-- R. Repair costs half.
------------------------------------------------------------------------------
do
	grug_repair = {}
	local price = 2500
	grug_gear = {reference_purchase_price = function() return price end}
	dofile(repo .. "/mods/ITEMS/grug_repair/service.lua")
	local function stack(wear)
		return {
			is_empty = function() return false end,
			get_definition = function() return {groups = {grug_equip_chest = 1}} end,
			get_wear = function() return wear end,
		}
	end
	eq(grug_repair.FACTOR, 0.5, "R the repair factor is 0.5 (ruling 3)")
	local samples = {{65535, 1250}, {32768, 626}, {6554, 126}, {1, 1}, {0, 0}}
	for _, sample in ipairs(samples) do
		local wear, want = sample[1], sample[2]
		local was = math.ceil(1.0 * price * wear / 65535)
		local cost = grug_repair.cost(stack(wear))
		eq(cost, want, "R wear " .. wear .. " costs " .. want .. " (0.76.2: " .. was .. ")")
		check(cost == math.ceil(was / 2) or cost == math.ceil(was / 2) + 1 or wear <= 1,
			"R ...about half of the old price at wear " .. wear)
	end
end

------------------------------------------------------------------------------
-- G. Guard posts at street level.
------------------------------------------------------------------------------
do
	local CAMPS = "mods/ENTITIES/grug_mobs/camps.lua"
	local source = read(CAMPS)
	local SPOT_TRIES = tonumber(source:match("local SPOT_TRIES = (%d+)"))
	local BANNER_NODE = source:match('local BANNER_NODE = "([^"]+)"')
	check(SPOT_TRIES ~= nil and BANNER_NODE ~= nil, "G the constants are found")
	-- A street at y = 10 (its floor), the banner in the air cell at y = 11.
	-- Every third column carries a lamp post (dressing.path_light: posts in the
	-- street cell and the one above, a floor torch on top), a crate here and
	-- there, a torch lying on the street, and a rope hanging from above.
	local world = {}
	local function key(x, y, z) return x .. "," .. y .. "," .. z end
	local LAMPS = {}
	for x = -20, 20 do
		for z = -20, 20 do
			world[key(x, 10, z)] = "default:stone"
			if x % 3 == 0 and z % 3 == 0 and (x ~= 0 or z ~= 0) then
				world[key(x, 11, z)] = "default:pine_tree"
				world[key(x, 12, z)] = "default:pine_tree"
				world[key(x, 13, z)] = "default:torch"
				LAMPS[x .. "," .. z] = true
			elseif x % 7 == 1 and z % 5 == 2 then
				world[key(x, 11, z)] = "grug_decor:crate"
			elseif x % 11 == 4 and z % 4 == 1 then
				-- A torch on the street: no floor to stand on.
				world[key(x, 10, z)] = "default:torch"
			end
		end
	end
	world[key(0, 11, 0)] = BANNER_NODE
	core.registered_nodes = {
		["default:stone"] = {walkable = true},
		["default:pine_tree"] = {walkable = true},
		["grug_decor:crate"] = {walkable = true},
		["default:torch"] = {walkable = false},
		[BANNER_NODE] = {walkable = false},
	}
	core.get_node_or_nil = function(p)
		if p.x < -21 or p.x > 21 or p.z < -21 or p.z > 21 then return nil end
		return {name = world[key(p.x, p.y, p.z)] or "air"}
	end
	core.get_item_group = function() return 0 end
	local free_spot_near = extract(CAMPS, "local CAMP_LEVELS = ",
		"local function free_spot_near(pos, radius, street)", "\nreturn free_spot_near",
		{SPOT_TRIES = SPOT_TRIES})
	local banner = {x = 0, y = 11, z = 0}
	math.randomseed(7801)
	local found, on_lamp, bad_level, bad_floor = 0, 0, 0, 0
	local levels = {}
	for _ = 1, 3000 do
		local p = free_spot_near(banner, 15, true)
		if p then
			found = found + 1
			levels[p.y] = (levels[p.y] or 0) + 1
			if LAMPS[p.x .. "," .. p.z] then on_lamp = on_lamp + 1 end
			if p.y < banner.y - 1 or p.y > banner.y + 1 then bad_level = bad_level + 1 end
			local floor = world[key(p.x, p.y - 1, p.z)]
			if not floor or not core.registered_nodes[floor].walkable then
				bad_floor = bad_floor + 1
			end
		end
	end
	check(found > 2900, "G a street spot is found nearly every time (" .. found .. " of 3000)")
	eq(on_lamp, 0, "G never on a lamp post or its torch")
	eq(bad_level, 0, "G never beyond street level +-1")
	eq(bad_floor, 0, "G always on a walkable floor (never a torch)")
	check((levels[11] or 0) > 0.9 * found, "G mostly in the street cell itself")
	-- The camp fire's old search on the same street does reach the lamp tops,
	-- which is what put the guards there.
	local old_tops = 0
	for _ = 1, 3000 do
		local p = free_spot_near(banner, 15)
		if p and LAMPS[p.x .. "," .. p.z] then old_tops = old_tops + 1 end
	end
	check(old_tops > 0, "G the camp-fire search (+3..-3) does reach lamp tops (" .. old_tops .. ")")

	-- A guard already on a lamp post is moved down; others stay.
	local camp_member = extract(CAMPS, "local function camp_member(cfg, name)",
		"local function camp_member(cfg, name)", "\nreturn camp_member", {})
	local gm = {registered_camp_types = {
		guard_accord = {mob = "grug_mobs:guard_accord", radius = 15, node = BANNER_NODE},
		bandit = {mob = "grug_mobs:bandit", radius = 12, node = "grug_nodes:camp_fire"},
	}}
	extract(CAMPS, "function grug_mobs.guard_to_street(self)",
		"function grug_mobs.guard_to_street(self)", "", {
			grug_mobs = gm, camp_member = camp_member, BANNER_NODE = BANNER_NODE,
			free_spot_near = free_spot_near,
		})
	local function guard(pos, fields)
		local object = {pos = pos}
		function object:get_pos() return self.pos end
		function object:set_pos(p) self.pos = p end
		local self = {name = "grug_mobs:guard_accord", object = object,
			_grug_camp_pos = {x = 0, y = 11, z = 0}, state = "stand"}
		for k, v in pairs(fields or {}) do self[k] = v end
		return self
	end
	-- On the torch of the lamp at (3, 3): the torch cell is y 13, its top 13.5.
	local up = guard({x = 3, y = 13.5, z = 3})
	check(gm.guard_to_street(up), "G a guard on a lamp post is moved")
	check(up.object.pos.y >= 9.5 and up.object.pos.y <= 11.5 and
		not LAMPS[up.object.pos.x .. "," .. up.object.pos.z],
		"G ...to a street spot: " .. up.object.pos.x .. "," .. up.object.pos.y .. "," .. up.object.pos.z)
	local street = guard({x = 2, y = 10.5, z = 2})
	check(not gm.guard_to_street(street) and street.object.pos.y == 10.5, "G a guard on the street stays")
	local crate = guard({x = 1, y = 11.5, z = 2})
	check(not gm.guard_to_street(crate), "G a guard one node up (a crate, a slope) stays")
	local patrol = guard({x = 3, y = 13.5, z = 3}, {_grug_patrol_route = {points = {}}})
	check(not gm.guard_to_street(patrol), "G a patroller is left alone")
	local fighting = guard({x = 3, y = 13.5, z = 3}, {state = "attack"})
	check(not gm.guard_to_street(fighting), "G a guard in a fight is left alone")
	local away = guard({x = 30, y = 13.5, z = 0})
	check(not gm.guard_to_street(away), "G a guard off its post is left alone")
	local socket = guard({x = 3, y = 13.5, z = 3}, {_grug_camp_pos = false})
	check(not gm.guard_to_street(socket), "G a guard without a camp (a start socket) is left alone")
	check(read("mods/ENTITIES/grug_mobs/guard.lua"):find("grug_mobs.guard_to_street(self)", 1, true) ~= nil,
		"G the guard's tick asks once per activation")
end

------------------------------------------------------------------------------
-- T. Towering: the placer's own body.
------------------------------------------------------------------------------
do
	local objects = {}
	core.get_objects_inside_radius = function() return objects end
	core.registered_nodes = {["default:stone"] = {walkable = true},
		["default:torch"] = {walkable = false}}
	core.item_place_node = function() end
	core.registered_entities = {}
	local fighting = {}
	local feed = {}
	grug_core = {
		in_combat = function(player) return fighting[player:get_player_name()] == true end,
		feed = function(_, _, text) feed[#feed + 1] = text end,
	}
	dofile(repo .. "/mods/CORE/grug_core/placement.lua")
	local P = grug_core.placement
	local function player_at(name, pos)
		local p = fake_player(name)
		p.pos = pos
		return p
	end
	local function mob_at(pos)
		local entity = {_cmi_is_mob = true, health = 10, state = "stand",
			_grug_cbox = {-0.4, 0, -0.4, 0.4, 1.8, 0.4}}
		return {get_pos = function() return pos end, get_luaentity = function() return entity end,
			is_player = function() return false end}
	end
	-- Mid-jump: the builder's feet 0.3 above the cell it places into (y = 1
	-- spans 0.5..1.5), its box still reaching into it.
	local builder = player_at("builder", {x = 0, y = 0.8, z = 0})
	objects = {builder}
	local cell = {{x = 0, y = 1, z = 0}}
	eq(P.refusal(builder, "default:stone", cell), nil, "T the placer may place into its own cell (ruling 8)")
	check(not grug_core.placement_refused(builder, "default:stone", cell) and #feed == 0,
		"T ...no refusal, no line")
	-- Into its own head cell too (the stock client does not send it).
	eq(P.refusal(builder, "default:stone", {{x = 0, y = 2, z = 0}}), nil, "T ...its own head cell too")
	-- Another player in the cell still blocks, also beside the placer.
	local other = player_at("other", {x = 0, y = 0.8, z = 0})
	objects = {builder, other}
	eq(P.refusal(builder, "default:stone", cell), P.BODY_LINE, "T another player still blocks")
	objects = {other}
	eq(P.refusal(builder, "default:stone", cell), P.BODY_LINE, "T ...also without the placer near")
	-- A mob still blocks.
	objects = {builder, mob_at({x = 0, y = 0.5, z = 0})}
	eq(P.refusal(builder, "default:stone", cell), P.BODY_LINE, "T a mob still blocks")
	-- Doors, beds and the rest pass their placer: two cells, the placer in both.
	objects = {builder}
	eq(P.refusal(builder, "default:stone", {{x = 0, y = 1, z = 0}, {x = 0, y = 2, z = 0}}), nil,
		"T a two-cell placement into the placer's own cells")
	-- Without a placer (a falling node's landing) every body counts.
	check(grug_core.body_in_cells(cell), "T a landing without a placer is blocked by the player")
	check(not grug_core.body_in_cells(cell, builder), "T ...the placer's exemption needs the placer")
	check(grug_core.body_in_cells(cell, other), "T ...and is that player's only")
	-- In combat the combat line still comes first.
	fighting.builder = true
	eq(P.refusal(builder, "default:stone", cell), P.COMBAT_LINE, "T in combat: the combat line")
	fighting.builder = nil
	-- Every set_node caller of the rule passes its placer.
	for _, file in ipairs({"mods/BASE/doors/init.lua", "mods/BASE/beds/api.lua",
			"mods/ITEMS/grug_farming/bucket.lua", "mods/ITEMS/grug_signs/init.lua",
			"mods/PLAYER/grug_housing/stone.lua"}) do
		local text = read(file)
		local arg1 = text:match("placement_refused%(%s*([%w_]+)%s*,")
		check(arg1 == "placer" or arg1 == "user", "T " .. file .. " passes its placer (" ..
			tostring(arg1) .. ")")
	end
end

------------------------------------------------------------------------------
-- A. Claim Stone activation with anthracite.
------------------------------------------------------------------------------
do
	local API = "mods/PLAYER/grug_housing/api.lua"
	grug_housing = {}
	extract(API, "grug_housing.FUEL_ORDER = ", "grug_housing.FUEL_ORDER = ", "", {})
	local stacks_mt = {}
	stacks_mt.__index = stacks_mt
	function stacks_mt:get_name() return self.name end
	function stacks_mt:get_count() return self.count end
	ItemStack = function(text)
		local name, count = text:match("^(%S+)%s*(%d*)$")
		return setmetatable({name = name, count = tonumber(count) or 1}, stacks_mt)
	end
	local function inventory(list)
		local inv = {lists = {main = list, store = {}}}
		function inv:get_list(name) return self.lists[name] end
		function inv:get_size(name) return name == "store" and 0 or #(self.lists[name] or {}) end
		function inv:remove_item(name, want)
			local taken = 0
			for _, stack in ipairs(self.lists[name]) do
				if stack.name == want.name and taken < want.count then
					local n = math.min(stack.count, want.count - taken)
					stack.count, taken = stack.count - n, taken + n
					if stack.count == 0 then stack.name = "" end
				end
			end
			return ItemStack(want.name .. " " .. taken)
		end
		return inv
	end
	local activated = {}
	local model = {
		ACTIVATION_LUMPS = 5,
		player_claim = function() return {id = 1} end,
		is_draft = function() return true end,
		activate = function(_, count) activated[#activated + 1] = count; return count end,
		PICKUP_LOCK_SECONDS = 43200,
	}
	local activate = extract(API, "local function fuel_carried(inv)",
		"function grug_housing.activate(player)", "\nreturn grug_housing.activate", {
			model = model, grug_housing = grug_housing,
			grug_inventory = {consume_lists = function() return {"main"} end,
				carried_lists = function() return {"main"} end, HOTBAR_STORE = "store"},
		})
	grug_housing.sync_stone_node = function() end
	grug_housing.notify_claim_changed = function() end
	local function owner(list)
		local p = fake_player("owner")
		local inv = inventory(list)
		function p:get_inventory() return inv end
		return p, inv
	end
	local function count_of(inv, name)
		local n = 0
		for _, stack in ipairs(inv.lists.main) do if stack.name == name then n = n + stack.count end end
		return n
	end
	local A = "grug_materials:anthracite"
	local C = "default:coal_lump"
	local H = "grug_smelting:charcoal"
	eq(grug_housing.FUEL_ORDER[#grug_housing.FUEL_ORDER], A, "A anthracite is in the activation order, last")
	local cases = {
		{"five anthracite", {{A, 5}}, true, {[A] = 0}},
		{"two coal, three anthracite", {{C, 2}, {A, 3}}, true, {[C] = 0, [A] = 0}},
		{"charcoal, coal and anthracite: anthracite last", {{A, 4}, {H, 2}, {C, 2}}, true,
			{[H] = 0, [C] = 0, [A] = 3}},
		{"four anthracite are too few", {{A, 4}}, false, {[A] = 4}},
	}
	for _, case in ipairs(cases) do
		local list = {}
		for index, row in ipairs(case[2]) do list[index] = ItemStack(row[1] .. " " .. row[2]) end
		local p, inv = owner(list)
		local ok, message = activate(p)
		eq(ok, case[3], "A " .. case[1] .. " (" .. tostring(message) .. ")")
		for name, left in pairs(case[4]) do
			eq(count_of(inv, name), left, "A " .. case[1] .. ": " .. name .. " left")
		end
		if not ok then
			check(message:find("anthracite", 1, true) ~= nil, "A the refusal names anthracite")
		end
	end
	eq(activated[#activated], 5, "A five lumps burnt, anthracite one for one")
end

------------------------------------------------------------------------------
-- O. Ore Sense skips protected deposits.
------------------------------------------------------------------------------
do
	local EFFECT = "mods/PLAYER/grug_guild/effect.lua"
	grug_guild = {}
	local protected, calls = {}, 0
	core.is_protected = function(pos, name)
		calls = calls + 1
		return protected[pos.x .. "," .. pos.y .. "," .. pos.z] == true and name == "miner"
	end
	local deposits = {}
	core.find_nodes_in_area = function() return {["t:ore"] = deposits, ["t:gem"] = {}} end
	local function distance(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end
	extract(EFFECT, "grug_guild.ORE_SENSE_CHECKS = ", "function grug_guild.ore_sense_find(", "", {
		grug_guild = grug_guild,
		rounded = function(p) return {x = p.x, y = p.y, z = p.z} end,
		tier_row = function() return {y_min = -1000, y_max = 1000} end,
		target_nodes = {[1] = {"t:ore", "t:gem"}},
		distance = distance,
	})
	local here = {x = 0, y = 0, z = 0}
	local free = {x = 5, y = 0, z = 0}
	local claimed = {x = 3, y = 0, z = 0}
	protected["3,0,0"] = true
	deposits = {claimed, free}
	local always_first = function(lo) return lo end
	local at = grug_guild.ore_sense_find(here, 1, 16, always_first, "miner")
	check(at and at.x == 5, "O a protected deposit is skipped, the free one marked")
	deposits = {claimed}
	eq(grug_guild.ore_sense_find(here, 1, 16, always_first, "miner"), nil,
		"O only protected deposits: no mark")
	deposits = {claimed}
	at = grug_guild.ore_sense_find(here, 1, 16, always_first, "other")
	check(at and at.x == 3, "O protection is the user's: another player may dig it")
	deposits = {claimed}
	at = grug_guild.ore_sense_find(here, 1, 16, always_first)
	check(at and at.x == 3, "O without a name (the old callers) nothing is filtered")
	-- Bounded: many protected deposits cost at most ORE_SENSE_CHECKS calls.
	deposits = {}
	for x = 1, 200 do
		deposits[x] = {x = x % 15, y = 0, z = math.floor(x / 15)}
		protected[deposits[x].x .. ",0," .. deposits[x].z] = true
	end
	calls = 0
	eq(grug_guild.ore_sense_find(here, 1, 16, nil, "miner"), nil, "O a town full of deposits: no mark")
	eq(calls, grug_guild.ORE_SENSE_CHECKS, "O ...after at most " .. grug_guild.ORE_SENSE_CHECKS ..
		" protection checks")
	check(read(EFFECT):find("ore_sense_find(pos, row.tier, row.range, nil,\n\t\teffect.name)", 1, true)
		~= nil, "O the mark passes its user's name")
end

------------------------------------------------------------------------------
-- F. A flying mount's raised retry.
------------------------------------------------------------------------------
do
	local ENTITY = "mods/PLAYER/grug_mounts/entity.lua"
	local source = read(ENTITY)
	local FLYER_ROOM_REFUSAL = source:match('local FLYER_ROOM_REFUSAL = "([^"]+)"')
	local blocked_below -- origins whose y is below this are blocked
	local asked = {}
	local box_blocked = function(pos, box)
		asked[#asked + 1] = pos.y
		check(box[2] >= 0, "F the body is tested from the feet up")
		return pos.y < blocked_below
	end
	local summon_position = extract(ENTITY, "local function summon_position(player, tier_id, seated)",
		"local function summon_position(player, tier_id, seated)", "\nreturn summon_position", {
			grug_core = {in_combat = function() return false end},
			grug_mounts = {
				TIERS = {[1] = {mode = "land"}, [3] = {mode = "flight"}},
				enemy_town_at = function() return false end,
				boat_touches_water = function() return false end,
				flight_state = function() return true end,
				FLIGHT_CEILING = 600,
				model_for = function() return {collisionbox = {-0.9, -0.1, -0.9, 0.9, 1.55, 0.9}} end,
			},
			grug_factions = {get_faction = function() return "accord" end},
			grug_mobs = {box_blocked = box_blocked},
			summon_guards = {},
			active = {},
			in_liquid = function() return false end,
			on_ground = function() return true end,
			FLYER_ROOM_REFUSAL = FLYER_ROOM_REFUSAL,
		})
	local rider = fake_player("rider")
	rider.pos = {x = 0, y = 49.5, z = 0}
	blocked_below = -math.huge
	local pos = summon_position(rider, 3)
	eq(pos and pos.y, 49.5, "F room at the feet: the flyer comes there")
	-- A step beside the feet: the feet box is blocked, one node up is free.
	blocked_below, asked = 50, {}
	pos = summon_position(rider, 3)
	eq(pos and pos.y, 50.5, "F no room at the feet: the flyer comes one node higher (ruling 13)")
	eq(#asked, 2, "F ...after one more test")
	-- Blocked up there too (a ceiling, a protected wall): refused.
	blocked_below, asked = 51, {}
	local refused, message = summon_position(rider, 3)
	eq(refused, nil, "F no room a node higher either: refused")
	eq(message, FLYER_ROOM_REFUSAL, "F ...with the room line")
	eq(#asked, 2, "F ...only one retry")
	-- At the flight ceiling the raised try would pass it: refused.
	rider.pos = {x = 0, y = 599.5, z = 0}
	blocked_below = 600
	refused, message = summon_position(rider, 3)
	check(refused == nil and message == FLYER_ROOM_REFUSAL, "F the raised try respects the flight ceiling")
	-- A ground mount never asks for room (one-node tunnels) and never rises.
	rider.pos = {x = 0, y = 49.5, z = 0}
	blocked_below, asked = math.huge, {}
	pos = summon_position(rider, 1)
	eq(pos and pos.y, 49.5, "F a ground mount comes at the feet")
	eq(#asked, 0, "F ...without a room test")
end

if failures > 0 then
	print(("R78 SMALL PORTABLE FAIL failures=%d checks=%d"):format(failures, checks))
	os.exit(1)
end
print(("R78 SMALL PORTABLE PASS checks=%d"):format(checks))
