-- Round 58 lane CONSUME portable fixture (LuaJIT): the Miner's Guild
-- consumables, their effect slot and the Miner's Remains
-- (mods/PLAYER/grug_guild/effect.lua, items.lua).
--
--   luajit tools/r58_consume/portable_test.lua REPO
--
-- Loads the REAL grug_core hud_layout.lua, status_icons.lua and status.lua
-- (so grug_core's own leave and death clears run first, as in the engine),
-- grug_materials registry.lua and mining.lua, grug_guild's catalog.lua and
-- the two files under test, on a small fake engine: a clock with core.after
-- and node timers, a map of tier rock with a tunnel, blocks that can be
-- unloaded, player meta that outlives a "server" (a restart is a fresh load
-- of every file over the same store, so a crash is a restart without the
-- leave callbacks).
--
-- A. The 12 items (levels, tiers, icons) and the 6 Remains nodes; the
--    status row and its pictures.
-- B. Use: below the level, outside the band and while an effect runs it is
--    refused with nothing taken; a use takes one item and starts the slot.
-- C. Persistence: a leave and join (offline time does not count), a death
--    (grug_core's clear first, then the re-apply), the crash (the timer save,
--    then a join without a leave), the end; no position in player meta.
-- D. Ore Sense: its targets in catalogue order, one search per mark, the
--    marker for its user only and for marker_seconds, the interval, nothing
--    outside the band.
-- E. Treasure Hunt: the placement rules (tier rock, 26 solid neighbours,
--    protection and hard protection refused, unloaded refused), the marker
--    for the owner only and only within marker_range, removal by distance,
--    by the owner going offline (node timer) and at leave, the pause, the
--    token case, another player digging it (loot, no marker), a restart.
-- F. remains_loot per tier within the catalogue's ranges.
-- Prints "R58 CONSUME PORTABLE PASS checks=<n>" or raises.

local repo = assert(arg and arg[1], "usage: luajit portable_test.lua REPO")
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
end
local function eq(actual, expected, label)
	check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end
local function exists(path)
	local handle = io.open(repo .. "/" .. path, "rb")
	if handle then handle:close() end
	return handle ~= nil
end
local function png_size(path)
	local handle = io.open(repo .. "/" .. path, "rb")
	if not handle then return nil end
	local header = handle:read(24)
	handle:close()
	local function u32(offset)
		local a, b, c, d = header:byte(offset, offset + 3)
		return ((a * 256 + b) * 256 + c) * 256 + d
	end
	return u32(17), u32(21)
end

local catalog = dofile(repo .. "/mods/PLAYER/grug_guild/catalog.lua")

------------------------------------------------------------------------------
-- The persistent store (outlives a restart) and the fake engine.
------------------------------------------------------------------------------
local store = {
	nodes = {}, node_meta = {}, node_timers = {}, player_meta = {},
	unloaded = {}, protected = {}, hard = {},
}
local TIER_ROCK = {"default:stone", "grug_materials:t2_stone", "grug_materials:t3_stone",
	"grug_materials:t4_stone", "grug_materials:t5_stone", "grug_materials:t6_stone"}
local function key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end
local function block_key(pos)
	return math.floor(pos.x / 16) .. "," .. math.floor(pos.y / 16) .. "," .. math.floor(pos.z / 16)
end
local function copy_pos(pos) return {x = pos.x, y = pos.y, z = pos.z} end
local function inside(box, pos)
	return pos.x >= box[1].x and pos.x <= box[2].x and pos.y >= box[1].y and pos.y <= box[2].y and
		pos.z >= box[1].z and pos.z <= box[2].z
end

local clock, timers, players, env
local function tier_of(y)
	for index, row in ipairs(grug_materials.TIERS) do
		if y >= row.y_min then return index end
	end
	return 6
end
local function base(pos) return TIER_ROCK[tier_of(pos.y)] end
local function node_name(pos)
	if store.unloaded[block_key(pos)] then return nil end
	return store.nodes[key(pos)] or base(pos)
end
local function carve(minp, maxp, name)
	for x = minp.x, maxp.x do
		for y = minp.y, maxp.y do
			for z = minp.z, maxp.z do store.nodes[x .. "," .. y .. "," .. z] = name end
		end
	end
end

-- Every node the world knows (tiles as the game's).
local NODES = {
	air = {walkable = false, buildable_to = true, tiles = {}},
	ignore = {walkable = false, tiles = {}},
	["default:stone"] = {tiles = {"default_stone.png"}},
	["default:water_source"] = {liquidtype = "source", walkable = false, tiles = {"default_water.png"}},
}
for tier = 2, 6 do
	NODES[TIER_ROCK[tier]] = {tiles = {"grug_materials_t" .. tier .. "_stone.png"}}
end

local ItemStackMeta = {}
ItemStackMeta.__index = ItemStackMeta
function ItemStack(value)
	if type(value) == "table" then return setmetatable({name = value.name, count = value.count}, ItemStackMeta) end
	local name, count = tostring(value or ""):match("^(%S*)%s*(%d*)")
	return setmetatable({name = name, count = name == "" and 0 or tonumber(count) or 1}, ItemStackMeta)
end
function ItemStackMeta:get_name() return self.name end
function ItemStackMeta:get_count() return self.count end
function ItemStackMeta:is_empty() return self.count == 0 end
function ItemStackMeta:take_item(n)
	n = math.min(n or 1, self.count)
	self.count = self.count - n
	if self.count == 0 then self.name = "" end
	return ItemStack(self.name .. " " .. n)
end

local function meta_object(fields)
	return {
		get_string = function(_, k) return fields[k] or "" end,
		set_string = function(_, k, v)
			if v == "" then fields[k] = nil else fields[k] = v end
		end,
		get_int = function(_, k) return math.floor(tonumber(fields[k]) or 0) end,
		set_int = function(_, k, v) fields[k] = tostring(v) end,
		to_table = function()
			local out = {}
			for k, v in pairs(fields) do out[k] = v end
			return {fields = out, inventory = {}}
		end,
		fields = fields,
	}
end

local function serialize(value)
	local parts = {}
	local keys = {}
	for k in pairs(value) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local v = value[k]
		parts[#parts + 1] = k .. " = " .. (type(v) == "string" and string.format("%q", v) or tostring(v))
	end
	return "return {" .. table.concat(parts, ", ") .. "}"
end
local function deserialize(text)
	local fn = loadstring(text)
	if not fn then return nil end
	setfenv(fn, {})
	local ok, value = pcall(fn)
	return ok and value or nil
end

local search_calls = 0
local feed = {} -- name -> {texts}
local drops = {} -- {pos, name, stacks}

local function fake_player(name, pos, level)
	local p = {name = name, pos = copy_pos(pos), level = level or 60, huds = {}, next_id = 0, hp = 20}
	store.player_meta[name] = store.player_meta[name] or {}
	local meta = meta_object(store.player_meta[name])
	function p:is_player() return true end
	function p:get_player_name() return self.name end
	function p:get_pos() return copy_pos(self.pos) end
	function p:set_pos(at) self.pos = copy_pos(at) end
	function p:get_meta() return meta end
	function p:get_hp() return self.hp end
	function p:get_properties() return {} end
	function p:hud_add(def)
		self.next_id = self.next_id + 1
		local copy = {}
		for k, v in pairs(def) do copy[k] = v end
		self.huds[self.next_id] = copy
		return self.next_id
	end
	function p:hud_change(id, k, v) if self.huds[id] then self.huds[id][k] = v end end
	function p:hud_remove(id) self.huds[id] = nil end
	return p
end

local function waypoints(player)
	local out = {}
	for _, def in pairs(player.huds) do
		if def.type == "image_waypoint" then out[#out + 1] = def end
	end
	return out
end

-- One server: every file loaded fresh over `store`.
local function boot()
	-- Node timers keep their time left (the engine stores elapsed and
	-- timeout, not a clock).
	for _, t in pairs(store.node_timers) do t.at = 1e9 + (t.at - (clock or 1e9)) end
	clock = 1e9
	timers = {}
	players = {}
	env = {joins = {}, leaves = {}, deaths = {}, respawns = {}, cids = {}, names = {}}
	local registered_nodes, registered_items = {}, {}
	for name, def in pairs(NODES) do
		def.name = name
		registered_nodes[name] = def
		registered_items[name] = def
	end
	local function cid(name)
		local id = env.cids[name]
		if not id then
			id = #env.names + 1
			env.names[id] = name
			env.cids[name] = id
		end
		return id
	end
	core = {
		registered_nodes = registered_nodes, registered_items = registered_items,
		get_us_time = function() return clock end,
		after = function(seconds, fn)
			timers[#timers + 1] = {at = clock + seconds * 1e6, fn = fn}
		end,
		log = function() end,
		get_modpath = function() return nil end,
		register_on_joinplayer = function(fn) env.joins[#env.joins + 1] = fn end,
		register_on_leaveplayer = function(fn) env.leaves[#env.leaves + 1] = fn end,
		register_on_dieplayer = function(fn) env.deaths[#env.deaths + 1] = fn end,
		register_on_respawnplayer = function(fn) env.respawns[#env.respawns + 1] = fn end,
		register_globalstep = function() end,
		register_on_punchnode = function() end,
		register_on_protection_violation = function() end,
		register_on_mods_loaded = function() end,
		get_connected_players = function() return players end,
		get_player_by_name = function(name)
			for _, p in ipairs(players) do if p.name == name then return p end end
			return nil
		end,
		register_node = function(name, def)
			def.name = name
			registered_nodes[name] = def
			registered_items[name] = def
		end,
		register_craftitem = function(name, def)
			def.name = name
			registered_items[name] = def
		end,
		get_content_id = cid,
		get_name_from_content_id = function(id) return env.names[id] end,
		get_node_raw = function(x, y, z)
			local name = node_name({x = x, y = y, z = z})
			if not name then return cid("ignore"), 0, 0, false end
			return cid(name), 0, 0, true
		end,
		get_node_or_nil = function(pos)
			local name = node_name(pos)
			return name and {name = name} or nil
		end,
		get_node = function(pos) return {name = node_name(pos) or "ignore"} end,
		set_node = function(pos, node)
			store.nodes[key(pos)] = node.name
			store.node_meta[key(pos)] = nil
			store.node_timers[key(pos)] = nil
		end,
		get_meta = function(pos)
			local k = key(pos)
			store.node_meta[k] = store.node_meta[k] or {}
			return meta_object(store.node_meta[k])
		end,
		get_node_timer = function(pos)
			local k = key(pos)
			return {
				start = function(_, timeout)
					store.node_timers[k] = {pos = copy_pos(pos), timeout = timeout, at = clock + timeout * 1e6}
				end,
				stop = function() store.node_timers[k] = nil end,
				is_started = function() return store.node_timers[k] ~= nil end,
			}
		end,
		find_nodes_in_area = function(minp, maxp, names, grouped)
			search_calls = search_calls + 1
			assert(grouped, "the effect asks for grouped results")
			local wanted, out = {}, {}
			for _, n in ipairs(names) do wanted[n] = true; out[n] = {} end
			for x = minp.x, maxp.x do
				for y = minp.y, maxp.y do
					for z = minp.z, maxp.z do
						local name = node_name({x = x, y = y, z = z})
						if name and wanted[name] then out[name][#out[name] + 1] = {x = x, y = y, z = z} end
					end
				end
			end
			return out
		end,
		is_protected = function(pos, name)
			for _, box in ipairs(store.protected) do if inside(box, pos) then return true end end
			return false
		end,
		serialize = serialize,
		deserialize = deserialize,
		handle_node_drops = function(pos, stacks, digger)
			drops[#drops + 1] = {pos = copy_pos(pos), name = digger:get_player_name(), stacks = stacks}
		end,
		add_item = function() end,
	}
	grug_core = {}
	function grug_core.mono_time() return core.get_us_time() / 1e6 end
	function grug_core.in_combat() return false end
	dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
	dofile(repo .. "/mods/CORE/grug_core/status_icons.lua")
	dofile(repo .. "/mods/CORE/grug_core/status.lua")
	function grug_core.zone_authority_installed() return true end
	function grug_core.feed(player, _, text)
		local name = player:get_player_name()
		feed[name] = feed[name] or {}
		feed[name][#feed[name] + 1] = text
		return true
	end
	function grug_core.get_player_level(player) return player.level end
	-- The level gate's semantics (grug_core/combat.lua can_use_item_level).
	function grug_core.can_use_item_level(player, item)
		local def = core.registered_items[item]
		local required = def and (def._grug_req_level or def._grug_ilvl)
		if type(required) ~= "number" or required <= 0 then return true end
		return player.level >= required, required, player.level
	end
	grug_zones = {hard_protection_kind_at = function(pos)
		for _, box in ipairs(store.hard) do if inside(box, pos) then return "guild_room" end end
		return nil
	end}
	grug_materials = {}
	dofile(repo .. "/mods/ITEMS/grug_materials/registry.lua")
	dofile(repo .. "/mods/ITEMS/grug_materials/mining.lua")
	for _, resource in ipairs(grug_materials.RESOURCES) do
		NODES[resource.natural_node] = NODES[resource.natural_node] or
			{tiles = {"default_stone.png^mineral_" .. resource.key .. ".png"}}
		NODES[resource.natural_node].name = resource.natural_node
		registered_nodes[resource.natural_node] = NODES[resource.natural_node]
	end
	grug_money = {make_bag = function(copper)
		local stack = ItemStack("grug_money:bag_of_coins")
		stack.copper = copper
		return stack
	end}
	grug_guild = {catalog = dofile(repo .. "/mods/PLAYER/grug_guild/catalog.lua")}
	grug_guild.consumable = grug_guild.catalog.consumable
	grug_guild.remains = grug_guild.catalog.remains
	dofile(repo .. "/mods/PLAYER/grug_guild/effect.lua")
	dofile(repo .. "/mods/PLAYER/grug_guild/items.lua")
end

-- Runs core.after timers and node timers (of loaded blocks; an unloaded
-- block's timer catches up once it is loaded) in time order.
local function advance(seconds)
	local target = clock + seconds * 1e6
	while true do
		local best, best_index, best_kind
		for index, t in ipairs(timers) do
			if t.at <= target and (not best or t.at < best.at) then best, best_index, best_kind = t, index, "after" end
		end
		for k, t in pairs(store.node_timers) do
			if t.at <= target and not store.unloaded[block_key(t.pos)] and (not best or t.at < best.at) then
				best, best_index, best_kind = t, k, "node"
			end
		end
		if not best then break end
		clock = math.max(clock, best.at)
		if best_kind == "after" then
			table.remove(timers, best_index)
			best.fn()
		else
			local name = store.nodes[best_index] or base(best.pos)
			local def = core.registered_nodes[name]
			local keep = def and def.on_timer and def.on_timer(copy_pos(best.pos), best.timeout)
			if store.node_timers[best_index] == best then
				if keep then best.at = clock + best.timeout * 1e6 else store.node_timers[best_index] = nil end
			end
		end
	end
	clock = target
end

local function join(player)
	players[#players + 1] = player
	for _, fn in ipairs(env.joins) do fn(player) end
end
local function leave(player)
	for _, fn in ipairs(env.leaves) do fn(player) end
	for index, p in ipairs(players) do if p == player then table.remove(players, index) break end end
end
-- Offline without the leave callbacks (a crash or a timed-out client).
local function vanish(player)
	for index, p in ipairs(players) do if p == player then table.remove(players, index) break end end
end

local function use(player, item, count)
	local stack = ItemStack(item .. " " .. (count or 1))
	local def = core.registered_items[item]
	local result = def.on_use(stack, player, {type = "nothing"})
	return result and result:get_count() or stack:get_count()
end
local function last_feed(name)
	local list = feed[name] or {}
	return list[#list] or ""
end
local function status(player) return grug_core.get_status(player, catalog.STATUS.id) end
local function find_remains()
	local out = {}
	for k, name in pairs(store.nodes) do
		if name:find("^grug_guild:miners_remains_t") then
			local x, y, z = k:match("^(-?%d+),(-?%d+),(-?%d+)$")
			out[#out + 1] = {pos = {x = tonumber(x), y = tonumber(y), z = tonumber(z)}, name = name}
		end
	end
	return out
end
local function distance(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end
local function saved(player)
	local text = player:get_meta():get_string(grug_guild.EFFECT_KEY)
	return text ~= "" and deserialize(text) or nil
end
local function no_position_in_meta(label)
	for name, fields in pairs(store.player_meta) do
		for k, v in pairs(fields) do
			local value = deserialize(v) or {}
			check(k == grug_guild.EFFECT_KEY, label .. ": only the effect key in " .. name .. "'s meta (" .. k .. ")")
			for field in pairs(value) do
				check(field == "kind" or field == "tier" or field == "remaining",
					label .. ": the saved effect holds no position (" .. field .. ")")
			end
		end
	end
end

math.randomseed(58)
boot()

------------------------------------------------------------------------------
-- A. Items, nodes, status row.
------------------------------------------------------------------------------
for _, row in ipairs(catalog.CONSUMABLES) do
	local def = core.registered_items[row.item]
	check(def ~= nil, "A " .. row.item .. " is registered")
	if def then
		eq(def._grug_req_level, 10 * row.tier - 9, "A " .. row.item .. " use level")
		check((def.stack_max or 99) > 1, "A " .. row.item .. " stacks")
		eq(def.description:match("^[^\n]*"), row.name, "A " .. row.item .. " name line")
		check(type(def.on_use) == "function", "A " .. row.item .. " has a use")
		local image = "mods/PLAYER/grug_guild/textures/" .. def.inventory_image
		local w, h = png_size(image)
		check(w == 16 and h == 16, "A " .. row.item .. " icon is a 16x16 PNG (" .. image .. ")")
		check(def.description:find(grug_guild.band_text(row.tier), 1, true) ~= nil,
			"A " .. row.item .. " names its band")
		check((row.tier == 1) == (def.description:find("Requires level", 1, true) == nil),
			"A " .. row.item .. " names its level from T2 on")
	end
end
local overlay = "grug_guild_miners_remains_overlay.png"
check(exists("mods/PLAYER/grug_guild/textures/" .. overlay), "A the Remains overlay ships")
for tier = 1, 6 do
	local row = catalog.remains(tier)
	local def = core.registered_nodes[row.node]
	check(def ~= nil, "A " .. row.node .. " is registered")
	if def then
		eq(def.is_ground_content, false, "A " .. row.node .. " is no ground content")
		eq(def.drop, "", "A " .. row.node .. " has no item of its own")
		eq(def.groups.level or 0, grug_materials.level_for_tier(tier), "A " .. row.node .. " dig level")
		eq(def.groups.grug_pick_level or 0, grug_materials.level_for_tier(tier), "A " .. row.node .. " gate mirrored")
		eq(def.groups.grug_stratum, tier, "A " .. row.node .. " digs as its tier rock")
		eq(def.tiles[1], NODES[row.host].tiles[1] .. "^" .. overlay, "A " .. row.node .. " is its rock with the overlay")
		eq(grug_materials.required_pick_tier(row.node, def), tier, "A " .. row.node .. " needs the tier pick")
		check(type(def.on_timer) == "function" and type(def.after_dig_node) == "function",
			"A " .. row.node .. " has its timer and dig hooks")
	end
end
local status_def = grug_core.status_icons.STATUS[catalog.STATUS.id]
check(status_def ~= nil and status_def.kind == "buff", "A the mining_sense status row is a buff")
for kind, variant in pairs(catalog.STATUS.variants) do
	local texture = status_def and status_def.variants and status_def.variants[variant]
	local w, h = png_size("mods/CORE/grug_core/textures/" .. tostring(texture))
	check(w == 64 and h == 64, "A the " .. kind .. " status picture is a 64x64 PNG")
end
check(catalog.STATUS.id ~= "elixir", "A its own slot, not the elixir's")

------------------------------------------------------------------------------
-- B. Use and refusals.
------------------------------------------------------------------------------
-- A tunnel in T3 rock (y -350) and in T5 rock (y -800), each 7 x 3 x 41.
carve({x = -3, y = -350, z = -20}, {x = 3, y = -348, z = 20}, "air")
carve({x = -3, y = -800, z = -20}, {x = 3, y = -798, z = 20}, "air")

local low = fake_player("low", {x = 0, y = -150, z = 0}, 5)
join(low)
eq(use(low, "grug_guild:ore_sense_t2", 3), 3, "B below the use level: nothing taken")
eq(grug_guild.active_effect(low), nil, "B below the use level: no effect")
check(last_feed("low"):find("Requires level 11", 1, true) ~= nil, "B the level refusal names the level")

local alice = fake_player("alice", {x = 0, y = 0, z = 0}, 60)
join(alice)
eq(use(alice, "grug_guild:ore_sense_t3", 2), 2, "B outside the band: nothing taken")
check(last_feed("alice"):find("between y -301 and -500", 1, true) ~= nil, "B the depth refusal names the band")
local ok, err = grug_guild.start_effect(alice, "ore_sense", 3)
check(not ok and err == "depth", "B start_effect outside the band says depth")
ok, err = grug_guild.start_effect(alice, "ore_sense", 9)
check(not ok and err == "unknown", "B an unknown tier says unknown")

alice:set_pos({x = 0, y = -349, z = 0})
eq(use(alice, "grug_guild:ore_sense_t3", 2), 1, "B a use in the band takes one item")
local active = grug_guild.active_effect(alice)
check(active and active.kind == "ore_sense" and active.tier == 3, "B the effect runs")
check(active and math.abs(active.remaining - catalog.consumable("ore_sense", 3).duration) < 1,
	"B for the catalogue's duration")
local record = status(alice)
check(record and record.variant == "ore_sense" and record.label == "Ore Sense III", "B the slot shows Ore Sense III")
advance(120)
eq(use(alice, "grug_guild:treasure_hunt_t3", 4), 4, "B a second use while one runs: nothing taken")
ok, err = grug_guild.start_effect(alice, "ore_sense", 3)
check(not ok and err == "active", "B start_effect while one runs says active")
check(last_feed("alice"):find("Ore Sense III is active (", 1, true) ~= nil and
	last_feed("alice"):find("min left", 1, true) ~= nil, "B the refusal names the time left: " .. last_feed("alice"))
eq(grug_guild.active_effect(alice).kind, "ore_sense", "B the running effect is never replaced")

------------------------------------------------------------------------------
-- C. Persistence.
------------------------------------------------------------------------------
local before = grug_guild.active_effect(alice).remaining
-- grug_core's leave callback is registered first (status.lua loads first).
local core_leave_index, guild_leave_index
for index, fn in ipairs(env.leaves) do
	local source = debug.getinfo(fn, "S").source
	if source:find("grug_core/status.lua", 1, true) then core_leave_index = index end
	if source:find("grug_guild/effect.lua", 1, true) then guild_leave_index = index end
end
check(core_leave_index and guild_leave_index and core_leave_index < guild_leave_index,
	"C grug_core's leave clear runs before grug_guild's")
leave(alice)
local s = saved(alice)
check(s and s.kind == "ore_sense" and s.tier == 3 and math.abs(s.remaining - before) <= 1,
	"C the leave saved {kind, tier, remaining}")
advance(600) -- offline time does not count
local alice2 = fake_player("alice", {x = 0, y = 0, z = 0}, 60)
join(alice2)
alice = alice2
active = grug_guild.active_effect(alice)
check(active and math.abs(active.remaining - before) <= 1, "C the join resumes with the saved time (offline does not count)")
record = status(alice)
check(record and record.variant == "ore_sense", "C the join shows the slot again")

-- Death: grug_core clears every status in its own callback first.
local core_die_index, guild_die_index
for index, fn in ipairs(env.deaths) do
	local source = debug.getinfo(fn, "S").source
	if source:find("grug_core/status.lua", 1, true) then core_die_index = index end
	if source:find("grug_guild/effect.lua", 1, true) then guild_die_index = index end
end
check(core_die_index and guild_die_index and core_die_index < guild_die_index,
	"C grug_core's death clear runs before grug_guild's")
env.deaths[core_die_index](alice)
eq(status(alice), nil, "C grug_core's death clear removed the status")
for index = core_die_index + 1, #env.deaths do env.deaths[index](alice) end
record = status(alice)
check(record and record.variant == "ore_sense", "C after the death the slot is back")
for _, fn in ipairs(env.respawns) do fn(alice) end
check(status(alice) ~= nil and grug_guild.active_effect(alice) ~= nil, "C after the respawn it still runs")

-- The crash: the timer save, then a restart and a join without a leave.
advance(95)
local at_crash = grug_guild.active_effect(alice).remaining
s = saved(alice)
check(s and s.remaining >= at_crash and s.remaining <= at_crash + 31, "C the timer saved within 30 s (" ..
	tostring(s and s.remaining) .. " for " .. math.floor(at_crash) .. ")")
no_position_in_meta("C")
boot() -- the crash: no leave callback ran
alice = fake_player("alice", {x = 0, y = -349, z = 0}, 60)
join(alice)
active = grug_guild.active_effect(alice)
check(active and active.kind == "ore_sense" and active.remaining >= at_crash and active.remaining <= at_crash + 31,
	"C after the crash the join resumes from the timer save")
check(status(alice) ~= nil, "C after the crash the slot shows")

------------------------------------------------------------------------------
-- D. Ore Sense.
------------------------------------------------------------------------------
local bob = fake_player("bob", {x = 1, y = -349, z = 1}, 60)
join(bob)
local garnet = grug_materials.RESOURCE_BY_KEY.garnet.natural_node
local silver = grug_materials.RESOURCE_BY_KEY.silver.natural_node
local garnet_pos = {x = 9, y = -340, z = 5} -- farther than the silver
local silver_pos = {x = 5, y = -349, z = 0}
store.nodes[key(garnet_pos)] = garnet
store.nodes[key(silver_pos)] = silver
local calls = search_calls
local found, found_node = grug_guild.ore_sense_find(alice:get_pos(), 3, 16)
check(found and found_node == garnet and key(found) == key(garnet_pos), "D the first target (the gem) wins over a nearer silver")
eq(search_calls - calls, 1, "D one search for every target at once")
store.nodes[key(garnet_pos)] = nil
found, found_node = grug_guild.ore_sense_find(alice:get_pos(), 3, 16)
check(found and found_node == silver, "D then the next target")
eq(grug_guild.ore_sense_find(alice:get_pos(), 3, 3), nil, "D nothing beyond the range")
store.nodes[key(garnet_pos)] = garnet
-- Near the band's edge the search stays inside it: a garnet just above
-- y -301 (T2 rock) is not marked from y -305.
store.nodes["0,-298,0"] = garnet
found = grug_guild.ore_sense_find({x = 0, y = -305, z = 0}, 3, 16)
check(found == nil or found.y <= -301, "D the search is clipped to the band")
store.nodes["0,-298,0"] = nil

-- The marks over time: one search each, the marker for alice only (a
-- fresh use, so the whole duration is left).
check(grug_guild.stop_effect(alice), "D stop_effect")
eq(use(alice, "grug_guild:ore_sense_t3", 1), 0, "D a fresh use")
local row = catalog.consumable("ore_sense", 3)
local mark_times, marked = {}, 0
calls = search_calls
local last_seen
for _ = 1, 1000 do
	advance(1)
	local list = waypoints(alice)
	if #list > 0 and not last_seen then
		mark_times[#mark_times + 1] = clock
		marked = marked + 1
		check(key(list[1].world_pos) == key(garnet_pos), "D the marker sits on the deposit")
		check(list[1].text:find(garnet:gsub(".*:", ""), 1, true) ~= nil or list[1].text ~= "",
			"D the marker shows the ore's own tile")
	end
	if #list > 0 then last_seen = (last_seen or clock) else last_seen = nil end
	check(#list <= 1, "D one marker at a time")
	eq(#waypoints(bob), 0, "D the marker is alice's only")
end
check(marked >= 8 and marked <= 17, "D a mark every 60-120 s (" .. marked .. " in 1000 s)")
eq(search_calls - calls, marked, "D one search per mark")
for index = 2, #mark_times do
	local gap = (mark_times[index] - mark_times[index - 1]) / 1e6
	check(gap >= row.interval_min - 1 and gap <= row.interval_max + 1, "D the interval " .. gap .. " s")
end
-- The marker lasts marker_seconds.
do
	local shown, start
	for _ = 1, 130 * 10 do
		advance(0.1)
		local n = #waypoints(alice)
		if n > 0 and not start then start = clock end
		if n == 0 and start then shown = (clock - start) / 1e6 break end
	end
	check(shown and math.abs(shown - row.marker_seconds) <= 0.2, "D the marker shows for " ..
		row.marker_seconds .. " s (" .. tostring(shown) .. ")")
end
-- Outside the band: no search, no marker; the time runs on.
alice:set_pos({x = 0, y = -250, z = 0})
calls = search_calls
local remaining_before = grug_guild.active_effect(alice).remaining
advance(300)
eq(search_calls - calls, 0, "D outside the band no search")
eq(#waypoints(alice), 0, "D outside the band no marker")
check(math.abs(remaining_before - grug_guild.active_effect(alice).remaining - 300) < 1, "D the time runs everywhere")

-- The end: the effect, the slot and the saved key go.
advance(grug_guild.active_effect(alice).remaining + 1)
eq(grug_guild.active_effect(alice), nil, "C the effect ends after its time")
eq(status(alice), nil, "C the slot is gone at the end")
eq(alice:get_meta():get_string(grug_guild.EFFECT_KEY), "", "C the saved key is cleared at the end")
eq(use(alice, "grug_guild:treasure_hunt_t3", 1), 1, "C a new use outside its band after the end is refused")

------------------------------------------------------------------------------
-- E. Treasure Hunt (T5, y -800).
------------------------------------------------------------------------------
local tier5 = TIER_ROCK[5]
-- The spot rules.
local spot = {x = 0, y = -815, z = 0}
check(grug_guild.remains_spot_ok(spot, 5, "alice"), "E a spot in T5 rock, 26 solid neighbours")
check(not grug_guild.remains_spot_ok(spot, 4, "alice"), "E not another tier's Remains")
check(not grug_guild.remains_spot_ok({x = 0, y = -801, z = 0}, 5, "alice"), "E not next to air")
store.nodes["1,-814,1"] = "default:water_source"
check(not grug_guild.remains_spot_ok(spot, 5, "alice"), "E not next to water")
store.nodes["1,-814,1"] = nil
store.nodes[key(spot)] = grug_materials.RESOURCE_BY_KEY.ruby.natural_node
check(not grug_guild.remains_spot_ok(spot, 5, "alice"), "E only in the tier rock itself")
store.nodes[key(spot)] = nil
store.protected[1] = {{x = -1, y = -816, z = -1}, {x = 1, y = -814, z = 1}}
check(not grug_guild.remains_spot_ok(spot, 5, "alice"), "E never where core.is_protected")
store.protected[1] = nil
store.hard[1] = {{x = -1, y = -816, z = -1}, {x = 1, y = -814, z = 1}}
check(not grug_guild.remains_spot_ok(spot, 5, "alice"), "E never in a hard-protected box")
store.hard[1] = nil
store.unloaded[block_key({x = 0, y = -817, z = 0})] = true
check(not grug_guild.remains_spot_ok({x = 0, y = -816, z = 0}, 5, "alice") or
	block_key({x = 0, y = -817, z = 0}) == block_key({x = 0, y = -816, z = 0}), "E not beside an unloaded block")
store.unloaded = {}

alice:set_pos({x = 0, y = -799, z = 0})
bob:set_pos({x = 0, y = -799, z = 2})
eq(use(alice, "grug_guild:treasure_hunt_t5", 1), 0, "E a use in T5 takes the item")
eq(status(alice).variant, "treasure_hunt", "E the slot shows Treasure Hunt")
local th = catalog.consumable("treasure_hunt", 5)
local placed = find_remains()
eq(#placed, 1, "E one Remains at a time")
local first = placed[1]
if first then
	eq(first.name, "grug_guild:miners_remains_t5", "E the tier's Remains")
	local d = distance(first.pos, alice:get_pos())
	check(d >= th.place_min - 1 and d <= th.place_max + 1, "E placed " .. th.place_min .. "-" .. th.place_max ..
		" nodes away (" .. d .. ")")
	for dx = -1, 1 do for dy = -1, 1 do for dz = -1, 1 do
		local around = node_name({x = first.pos.x + dx, y = first.pos.y + dy, z = first.pos.z + dz})
		if dx ~= 0 or dy ~= 0 or dz ~= 0 then
			check(around ~= "air", "E no air around the Remains")
		end
	end end end
	local meta = store.node_meta[key(first.pos)] or {}
	eq(meta.owner, "alice", "E its owner in node meta")
	check(meta.token and meta.token ~= "", "E its placement token in node meta")
	check(store.node_timers[key(first.pos)] ~= nil, "E its node timer runs")
	local list = waypoints(alice)
	check(#list == 1 and key(list[1].world_pos) == key(first.pos), "E marked for its owner")
	eq(#waypoints(bob), 0, "E no marker for anybody else")
end
no_position_in_meta("E")

-- Within marker_range the marker shows, beyond it (but inside the remove
-- distance) it goes; the block stays.
local function stand(player, from, at)
	local dir = {x = 0, y = 0, z = 1}
	player:set_pos({x = from.x, y = -799, z = from.z + at})
end
if first then
	alice:set_pos({x = first.pos.x, y = first.pos.y, z = first.pos.z + th.marker_range + 4})
	advance(th.check_seconds + 0.1)
	eq(#waypoints(alice), 0, "E beyond marker_range no marker")
	eq(#find_remains(), 1, "E the block stays inside remove_distance")
	alice:set_pos({x = first.pos.x, y = first.pos.y, z = first.pos.z + 10})
	advance(th.check_seconds + 0.1)
	eq(#waypoints(alice), 1, "E back in range the marker shows")
	-- Beyond remove_distance: the rock comes back.
	alice:set_pos({x = first.pos.x, y = first.pos.y, z = first.pos.z + th.remove_distance + 5})
	advance(th.check_seconds + 0.1)
	eq(#find_remains(), 0, "E beyond remove_distance it is gone")
	eq(node_name(first.pos), tier5, "E the rock is back")
	eq(store.node_meta[key(first.pos)], nil, "E its meta is gone with it")
end
-- The pause, then the next one.
alice:set_pos({x = 0, y = -799, z = 0})
advance(th.check_seconds + 0.1)
eq(#find_remains(), 0, "E the next one waits for the pause")
advance(th.respawn_seconds)
eq(#find_remains(), 1, "E the next one after respawn_seconds")

-- The owner offline without a leave (a crash or a timeout): the block's
-- own timer removes it.
vanish(alice)
advance(th.check_seconds + 0.1)
eq(#find_remains(), 0, "E owner offline: the node timer removed it")
join(alice) -- (back in the same server: the runtime effect never left)
advance(th.check_seconds + th.respawn_seconds + 0.2)
eq(#find_remains(), 1, "E a new one once back")

-- Another player digs it: the loot goes to the digger, no marker for them,
-- the owner's effect waits for the next one.
placed = find_remains()
if placed[1] then
	local pos = placed[1].pos
	local def = core.registered_nodes[placed[1].name]
	local oldmeta = core.get_meta(pos):to_table()
	core.set_node(pos, {name = "air"}) -- builtin node_dig removes it first
	def.after_dig_node(pos, {name = placed[1].name}, oldmeta, bob)
	local got = drops[#drops]
	check(got and got.name == "bob", "E the digger gets the loot")
	local bag, bar
	for _, stack in ipairs(got and got.stacks or {}) do
		if stack:get_name() == "grug_money:bag_of_coins" then bag = stack end
		if stack:get_name() == catalog.remains(5).bar then bar = stack end
	end
	local loot_row = catalog.remains(5)
	check(bag and bag.copper >= loot_row.copper_min and bag.copper <= loot_row.copper_max, "E a Bag of Coins in range")
	check(bar and bar:get_count() >= loot_row.bars_min and bar:get_count() <= loot_row.bars_max, "E the tier's bars")
	eq(#waypoints(bob), 0, "E the digger never had a marker")
	advance(th.check_seconds + 0.1)
	eq(#find_remains(), 0, "E after a dig the pause runs")
	advance(th.respawn_seconds)
	eq(#find_remains(), 1, "E then the next one")
end

-- The token case: the Remains' block unloads while its owner walks away;
-- the effect forgets it and places a new one; the owner comes back, the
-- old block loads, and its timer sees a token that is no longer current.
placed = find_remains()
local old = placed[1]
if old then
	store.unloaded[block_key(old.pos)] = true
	alice:set_pos({x = old.pos.x, y = -799, z = old.pos.z + th.remove_distance + 8})
	advance(th.check_seconds + 0.1) -- forgotten (unplace skipped: unloaded)
	advance(th.respawn_seconds + th.check_seconds)
	local newer = find_remains()
	eq(#newer, 2, "E a new Remains while the old one sits unloaded")
	alice:set_pos({x = old.pos.x, y = old.pos.y, z = old.pos.z + 3}) -- back beside the old one
	store.unloaded = {}
	advance(0.01) -- the old block's timer catches up
	eq(node_name(old.pos), tier5, "E the old Remains removes itself: its token is not current")
	advance(th.check_seconds + 0.1)
	check(#find_remains() <= 1, "E at most one Remains")
end

-- The leave removes the Remains at once.
advance(th.respawn_seconds + th.check_seconds)
check(#find_remains() == 1, "E one before the leave")
leave(alice)
eq(#find_remains(), 0, "E the leave takes the Remains")
eq(saved(alice).kind, "treasure_hunt", "E the leave saved the effect")

-- A restart with a Remains in the map (the crash): it goes when its timer
-- fires, whether its owner comes back or not.
alice = fake_player("alice", {x = 0, y = -799, z = 0}, 60)
join(alice)
check(#find_remains() == 1, "E the rejoin places one")
local stale = find_remains()[1]
boot()
alice = fake_player("alice", {x = stale.pos.x, y = stale.pos.y, z = stale.pos.z + 2}, 60)
store.unloaded[block_key(stale.pos)] = true -- not loaded at the join
join(alice)
store.unloaded = {}
advance(th.check_seconds + 0.1)
eq(node_name(stale.pos), tier5, "E after a restart the old Remains is gone (stale token)")
check(#find_remains() <= 1, "E and only the new effect's one exists")
check(grug_guild.stop_effect(alice), "E stop_effect stops it")
eq(#find_remains(), 0, "E stop_effect takes the Remains")
eq(status(alice), nil, "E stop_effect clears the slot")
eq(alice:get_meta():get_string(grug_guild.EFFECT_KEY), "", "E stop_effect clears the saved key")

------------------------------------------------------------------------------
-- F. remains_loot.
------------------------------------------------------------------------------
for tier = 1, 6 do
	local r = catalog.remains(tier)
	local low_roll = grug_guild.remains_loot(tier, function(lo) return lo end)
	eq(low_roll.copper, r.copper_min, "F T" .. tier .. " lowest copper")
	local high_roll = grug_guild.remains_loot(tier, function(_, hi) return hi end)
	eq(high_roll.copper, r.copper_max, "F T" .. tier .. " highest copper")
	local gem_seen, rolls = 0, 4000
	for _ = 1, rolls do
		local loot = grug_guild.remains_loot(tier, math.random)
		check(loot.copper >= r.copper_min and loot.copper <= r.copper_max, "F T" .. tier .. " copper in range")
		local bars_ok, gem = false, false
		for _, item in ipairs(loot.items) do
			local name, count = item:match("^(%S+) (%d+)$")
			count = tonumber(count)
			if name == r.bar then bars_ok = count >= r.bars_min and count <= r.bars_max
			elseif name == r.gem then gem = count == 1
			else check(false, "F T" .. tier .. " only its bar and gem: " .. item) end
		end
		check(bars_ok or r.bars_max == 0, "F T" .. tier .. " its bars")
		if gem then gem_seen = gem_seen + 1 end
	end
	local share = gem_seen / rolls
	check(math.abs(share - 1 / r.gem_chance) < 0.04, "F T" .. tier .. " the gem about 1 in " .. r.gem_chance ..
		" (" .. share .. ")")
end

if failures > 0 then
	error("R58 CONSUME PORTABLE FAIL " .. failures .. " of " .. checks)
end
print("R58 CONSUME PORTABLE PASS checks=" .. checks)
