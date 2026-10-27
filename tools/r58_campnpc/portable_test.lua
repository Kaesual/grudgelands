-- Round 58 lane CAMPNPC portable fixture (LuaJIT): the Miner's Guild's
-- people and the camp vendor.
--
--   luajit tools/r58_campnpc/portable_test.lua REPO
--
-- F. The foremen and the guild leaders (grug_quests/npcs.lua) on the real
--    settlement sockets of seed 42 (tools/seed_fleet/runtime.lua: the camps'
--    and capitals' blueprints and templates as the world registers them)
--    and the real camp index (wp40/r58_camps.lua): 36 foremen, one per camp
--    on its `quest_foreman` socket, titled Foreman (two by name since Round
--    60), role foreman_t<tier>,
--    of the camp's faction; six leaders on the guild house's leader socket
--    (capital_services.GUILD_HALL, never a literal id), named, of the
--    capital's faction; the exchange socket can be taken over as the
--    service role guild_exchange; a tier quest listing foreman_tk..t6 per
--    faction variant binds every own camp of tier >= k, each foreman in one
--    variant only (registry.lua's assert holds).
-- W. The window and the purchase on the whole game's registrations (the
--    Round 57 game harness): the camp vendor and the exchange counter are
--    guild vendors; grug_guild.vendor_rows locks rows by rank;
--    grug_guild.buy refuses below the rank, above the balance, with a full
--    bag and without a faction (nothing spent) and spends the balance,
--    never the lifetime; the camp vendor's Buy mode is the reputation page
--    (locked rows greyed with "Reach Reputation Rank N", no button; a
--    forged click on a locked row buys nothing); the exchange counter has
--    no page; the camp vendor's Repair button opens the repair form and
--    repairs; the repair provider refuses the other faction, a player out
--    of range and a socket that is no camp vendor's.
-- Prints "R58 CAMPNPC PORTABLE PASS checks=<n>" or raises.

local repo = assert(arg and arg[1], "usage: luajit portable_test.lua REPO")
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. ": expected " .. tostring(expected) ..
		", got " .. tostring(actual))
end

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local hall = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp13/capital_services.lua").GUILD_HALL
local LEADERS = {highcourt = "Alis Cartwright", dur_brannoc = "Hadrin Beamset",
	lethariel = "Caelir Veinward", nhal_veyr = "Iven Lastshift",
	gor_drazhak = "Drava Flintshoulder", kezamba = "Ombali Ropekeeper"}
local CAPITAL_FACTION = {highcourt = "accord", dur_brannoc = "accord", lethariel = "accord",
	nhal_veyr = "throng", gor_drazhak = "throng", kezamba = "throng"}

------------------------------------------------------------------------------
-- F. The foremen and the guild leaders on seed 42's sockets.
------------------------------------------------------------------------------
do
	local SEED = "42"
	local RT = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, SEED)
	local rows = RT.main.settlement_sockets(RT.built)
	local layout = RT.main.placement_layout_text()
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local camps = dofile(wp40 .. "/r58_camps.lua").index(layout,
		{raw_sha256 = common.new_sha256(), full_seed = SEED})

	-- The real socket registry under a small engine.
	_G.core = _G.core or {}
	core.log = core.log or function() end
	core.dir_to_yaw = core.dir_to_yaw or function(d) return math.atan2(-d.x, d.z) end
	core.get_modpath = function(name)
		return name == "grug_mapgen" and repo .. "/mods/MAPGEN/grug_mapgen" or nil
	end
	local function copy(value)
		if type(value) ~= "table" then return value end
		local out = {}
		for k, v in pairs(value) do out[k] = copy(v) end
		return out
	end
	table.copy = table.copy or copy
	_G.grug_core = {}
	dofile(repo .. "/mods/CORE/grug_core/settlement_sockets.lua")
	for _, row in ipairs(rows) do
		grug_core.register_settlement_sockets(row.key, row.race, row.anchor, row.sockets,
			row.label, row.slot)
	end
	local races = {human = "accord", dwarf = "accord", elf = "accord",
		orc = "throng", troll = "throng", undead = "throng"}
	_G.grug_classes = {registered_races = {}}
	for race, faction in pairs(races) do grug_classes.registered_races[race] = {faction = faction} end
	_G.grug_mapgen = {mining_camps = camps}
	_G.grug_quests = {}
	dofile(repo .. "/mods/PLAYER/grug_quests/registry.lua")
	dofile(repo .. "/mods/PLAYER/grug_quests/npcs.lua")
	local Q = grug_quests
	Q.resolve_npc_factions()

	local socket_of = {}
	for _, record in ipairs(grug_core.settlement_socket_settlements()) do
		for _, socket in ipairs(grug_core.settlement_sockets_at(record.key)) do
			socket_of[record.key .. "/" .. socket.id] = socket
		end
	end

	-- The foremen.
	eq(#camps.camps, 36, "F 36 camps with a lift")
	local per_role, foremen = {}, 0
	for id in pairs(Q.registered_npcs) do
		if id:find("^r58_foreman_") then foremen = foremen + 1 end
	end
	eq(foremen, 36, "F 36 foremen")
	for _, camp in ipairs(camps.camps) do
		local id = "r58_foreman_" .. camp.id
		local npc = Q.registered_npcs[id]
		if check(npc ~= nil, "F " .. id .. " registered") then
			eq(npc.settlement, camp.id, "F " .. id .. " in its camp")
			eq(npc.socket, "quest_foreman", "F " .. id .. " on the camp's quest_foreman socket")
			local socket = socket_of[camp.id .. "/quest_foreman"]
			check(socket ~= nil and socket.role == "quest", "F " .. id .. " the socket is a quest socket")
			-- Round 60 CAPITALS: the story's two foremen carry their names
			-- (round60-plan.md §2a point 3), and since Round 61 chapter 3's
			-- two (round61-plan.md §2a point 4); every other one is "Foreman".
			local title = ({mining_camp_frostbarrow_shelf = "Brodd Deeppeg",
				mining_camp_ossuary_reach = "Rellis Shalemark", mining_camp_ashenward_march = "Audra Wainholt",
				mining_camp_bannerbreak_mesa = "Greda Stonehaul"})[camp.id] or "Foreman"
			eq(npc.title, title, "F " .. id .. " titled " .. title)
			eq(npc.role, "foreman_t" .. camp.tier, "F " .. id .. " the role of its tier")
			eq(npc.faction, camp.faction, "F " .. id .. " of its camp's faction")
			eq(Q.npc_by_socket[camp.id .. "/quest_foreman"], id, "F " .. id .. " owns its socket")
			local key = npc.role .. "/" .. npc.faction
			per_role[key] = (per_role[key] or 0) + 1
		end
	end
	-- Per tier: T2 6, T3 8, T4 6 mining camps (half per faction), T5 and T6
	-- 8 war camps each (4 per faction).
	for tier, count in pairs({[2] = 3, [3] = 4, [4] = 3, [5] = 4, [6] = 4}) do
		for _, faction in ipairs({"accord", "throng"}) do
			eq(per_role["foreman_t" .. tier .. "/" .. faction], count,
				"F foreman_t" .. tier .. " " .. faction .. " count")
		end
	end
	eq(per_role["foreman_t1/accord"], nil, "F no T1 foreman")
	-- No foreman in a camp under construction (no quest socket there).
	for _, site in ipairs(camps.under_construction) do
		eq(Q.registered_npcs["r58_foreman_" .. site.id], nil, "F no foreman at " .. site.id)
	end

	-- The guild leaders.
	check(type(hall.leader) == "string" and type(hall.exchange) == "string",
		"F the hall socket contract names the leader and the exchange socket")
	for capital, name in pairs(LEADERS) do
		local id = "r58_guild_leader_" .. capital
		local npc = Q.registered_npcs[id]
		if check(npc ~= nil, "F " .. id .. " registered") then
			eq(npc.settlement, capital, "F " .. id .. " in its capital")
			eq(npc.socket, hall.leader, "F " .. id .. " on GUILD_HALL.leader")
			local socket = socket_of[capital .. "/" .. hall.leader]
			check(socket ~= nil and socket.role == "quest", "F " .. id .. " the socket is a quest socket")
			eq(npc.title, name, "F " .. id .. " named")
			eq(npc.faction, CAPITAL_FACTION[capital], "F " .. id .. " of the capital's faction")
			eq(npc.role, nil, "F " .. id .. " no giver role")
		end
		-- The exchange counter's socket takes the service role.
		local ok, entry = pcall(grug_core.assign_service_socket, capital, hall.exchange, "guild_exchange")
		check(ok and entry and entry.role == "guild_exchange",
			"F " .. capital .. " the exchange socket becomes guild_exchange")
	end
	check(not pcall(grug_core.assign_service_socket, "highcourt", hall.exchange, "no_such_role"),
		"F an unknown service role is refused")

	-- The role scheme for lane GUILDQUESTS: a tier-3 quest lists the role
	-- rows foreman_t3 .. foreman_t6 per faction variant.
	Q.use_objects = {}
	local function roles(faction, from)
		local out = {}
		for tier = from, 6 do out[#out + 1] = {role = "foreman_t" .. tier, faction = faction} end
		return out
	end
	Q.register_quest("r58_campnpc_probe_t3", {title = "Probe", description = "Probe.",
		rewards = {weight = 1}, level = 23, variants = {
			{key = "accord", giver_roles = roles("accord", 3),
				objectives = {{type = "item", item = "default:iron_lump", count = 1}}},
			{key = "throng", giver_roles = roles("throng", 3),
				objectives = {{type = "item", item = "default:iron_lump", count = 1}}}}})
	check(pcall(Q.bind_role_givers), "F the tier roles bind without the one-variant assert")
	local def = Q.registered_quests.r58_campnpc_probe_t3
	local expect = {accord = 0, throng = 0}
	for _, camp in ipairs(camps.camps) do
		if camp.tier >= 3 then expect[camp.faction] = expect[camp.faction] + 1 end
	end
	for _, faction in ipairs({"accord", "throng"}) do
		local variant = def.variant_by_key[faction]
		eq(#variant.givers, expect[faction], "F tier 3 " .. faction .. ": every own camp of tier >= 3 gives it")
		for _, npc in ipairs(variant.givers) do
			check(Q.registered_npcs[npc].faction == faction, "F " .. npc .. " gives its own faction's variant")
		end
	end
	local t2 = "r58_foreman_" .. camps.camps[1].id
	for _, camp in ipairs(camps.camps) do
		if camp.tier == 2 then t2 = "r58_foreman_" .. camp.id break end
	end
	eq(def.giver_variant[t2], nil, "F a T2 foreman does not give the tier-3 quest")
end

------------------------------------------------------------------------------
-- W. The window and the purchase on the game's registrations.
------------------------------------------------------------------------------
local game = dofile(repo .. "/tools/r57_details/game_harness.lua")(repo)
for _, line in ipairs(game.failures) do
	check(not (line:find("grug_guild", 1, true) or line:find("grug_traders", 1, true) or
		line:find("grug_repair", 1, true)), "W the mods load in the harness: " .. line)
end
local C = grug_guild.catalog

-- Fake players (as tools/r58_rep): meta, an inventory, online.
local function new_meta()
	local data = {}
	return {
		get_int = function(_, key) return math.floor(tonumber(data[key]) or 0) end,
		set_int = function(_, key, value) data[key] = tostring(value) end,
		get_string = function(_, key) return data[key] or "" end,
		set_string = function(_, key, value) data[key] = value end,
		contains = function(_, key) return data[key] ~= nil end,
		data = data,
	}
end
local BAG = grug_inventory.content_list(1)
local STORE = grug_inventory.HOTBAR_STORE
local Stack = getmetatable(ItemStack("default:dirt"))
-- Wear (the harness's stacks have none): kept on the stack and copied.
local plain_item_stack = ItemStack
_G.ItemStack = function(value)
	local stack = plain_item_stack(value)
	if type(value) == "table" and getmetatable(value) == Stack then stack.wear = value.wear end
	return stack
end
function Stack:get_wear() return self.wear or 0 end
function Stack:set_wear(wear) self.wear = wear end
function Stack:equals(other)
	return self.name == other.name and self.count == other.count and (self.wear or 0) == (other.wear or 0)
end
-- The engine's add_item: into an empty stack or onto the same item up to
-- its stack size; returns the leftover.
function Stack:add_item(other)
	other = ItemStack(other)
	if other:is_empty() then return other end
	if self:is_empty() then
		self.name, self.count, self.wear, self.meta = other.name, 0, other.wear, other.meta
	elseif self.name ~= other.name then
		return other
	end
	local def = core.registered_items[self.name] or {}
	local max = def.stack_max or 99
	local into = math.min(max - self.count, other.count)
	self.count = self.count + into
	other.count = other.count - into
	if other.count == 0 then other.name = "" end
	return other
end
function Stack:get_description()
	local def = core.registered_items[self.name]
	return def and def.description or self.name
end
local function new_inv()
	local lists = {}
	for list, size in pairs({main = 32, [BAG] = 8, [STORE] = 8}) do
		lists[list] = {}
		for i = 1, size do lists[list][i] = ItemStack("") end
	end
	local inv = {lists = lists}
	function inv:get_size(list) return lists[list] and #lists[list] or 0 end
	function inv:get_list(list)
		if not lists[list] then return nil end
		local out = {}
		for i, stack in ipairs(lists[list]) do out[i] = ItemStack(stack) end
		return out
	end
	function inv:get_stack(list, i) return ItemStack(lists[list] and lists[list][i] or "") end
	function inv:set_stack(list, i, stack)
		if not lists[list] or not lists[list][i] then return false end
		lists[list][i] = ItemStack(stack)
		return true
	end
	function inv:set_list(list, stacks)
		for i = 1, #lists[list] do lists[list][i] = ItemStack(stacks[i] or "") end
	end
	return inv
end
local function count_of(inv, name)
	local n = 0
	for _, stacks in pairs(inv.lists) do
		for _, stack in ipairs(stacks) do
			if stack:get_name() == name then n = n + stack:get_count() end
		end
	end
	return n
end
local online = {}
local function new_player(name, faction, pos)
	local meta, inv = new_meta(), new_inv()
	if faction then meta:set_string("grug_factions:faction", faction) end
	local player = {
		get_player_name = function() return name end,
		is_player = function() return true end,
		get_meta = function() return meta end,
		get_inventory = function() return inv end,
		get_hp = function() return 20 end,
		meta = meta, inv = inv, pos = pos or {x = 0, y = 0, z = 0},
	}
	player.get_pos = function() return player.pos end
	online[name] = player
	return player
end
core.get_player_by_name = function(name) return online[name] end
local function fill_bag(player, item)
	for list, stacks in pairs(player.inv.lists) do
		for i = 1, #stacks do player.inv.lists[list][i] = ItemStack(item) end
	end
end

-- The two vendor definitions.
local CAMP = "grug_traders:vendor_camp"
local EXCHANGE = "grug_traders:guild_exchange"
local camp_vendor, exchange = grug_traders.vendors[CAMP], grug_traders.vendors[EXCHANGE]
check(camp_vendor and grug_traders.guild_vendor(camp_vendor), "W the camp vendor is a guild vendor")
check(camp_vendor and camp_vendor.guild_page == true and camp_vendor.repairs == true and
	camp_vendor.nametag == "Camp Vendor", "W the camp vendor has the reputation page and repairs")
check(camp_vendor and not grug_traders.sells_gear(camp_vendor), "W the camp vendor sells no gear")
check(exchange and grug_traders.guild_vendor(exchange), "W the exchange counter is a guild vendor")
check(exchange and exchange.guild_page == nil and exchange.repairs == nil and
	exchange.nametag == "Miner's Guild Exchange", "W the exchange counter: no page, no repair")
check(exchange and exchange.faction == nil and exchange.race == nil,
	"W the exchange counter serves its capital's faction (the settlement's race)")
check(core.registered_entities[EXCHANGE] ~= nil and core.registered_entities[CAMP] ~= nil,
	"W both vendor entities are registered")

-- vendor_rows and buy.
local ann = new_player("ann", "accord")
local rows = grug_guild.vendor_rows(ann)
eq(#rows, 6, "W six rows")
local shape = true
for tier, row in ipairs(rows) do
	shape = shape and row.tier == tier and row.rank == tier and #row.items == 2 and
		row.items[1].item == "grug_guild:ore_sense_t" .. tier and
		row.items[2].item == "grug_guild:treasure_hunt_t" .. tier and not row.unlocked
end
check(shape, "W six rows by tier, Ore Sense and Treasure Hunt, all locked at rank 0")
grug_guild.add(ann, C.RANKS[3], "test")
rows = grug_guild.vendor_rows(ann)
check(rows[1].unlocked and rows[2].unlocked and rows[3].unlocked and not rows[4].unlocked and
	not rows[6].unlocked, "W rank 3 unlocks rows 1-3")

local T1, T3, T4 = C.consumable("ore_sense", 1), C.consumable("treasure_hunt", 3), C.consumable("ore_sense", 4)
local function state(player)
	return grug_guild.lifetime(player), grug_guild.balance(player)
end
local life0, bal0 = state(ann)
local ok, err = grug_guild.buy(ann, T4.item)
check(ok == false and err == "rank", "W a T4 item below rank 4 is refused (rank)")
ok, err = grug_guild.buy(ann, "default:dirt")
check(ok == false and err == "unknown", "W an item the guild does not sell (unknown)")
local l, b = state(ann)
check(l == life0 and b == bal0 and count_of(ann.inv, T4.item) == 0, "W nothing spent or given on a refusal")
ok = grug_guild.buy(ann, T3.item)
eq(ok, true, "W a T3 item at rank 3")
l, b = state(ann)
eq(b, bal0 - T3.price, "W the purchase spends the balance")
eq(l, life0, "W ...never the lifetime")
eq(grug_guild.rank(ann), 3, "W ...and keeps the rank")
eq(count_of(ann.inv, T3.item), 1, "W the item is given")
-- Above the balance.
grug_guild.spend(ann, grug_guild.balance(ann))
ok, err = grug_guild.buy(ann, T1.item)
check(ok == false and err == "insufficient", "W an empty balance is refused (insufficient)")
-- A full bag.
grug_guild.add(ann, T1.price, "test")
fill_bag(ann, "default:dirt 99")
local fl, fb = state(ann)
ok, err = grug_guild.buy(ann, T1.item)
check(ok == false and err == "full", "W a full bag is refused (full)")
l, b = state(ann)
check(l == fl and b == fb and count_of(ann.inv, T1.item) == 0, "W ...and nothing spent")
-- No faction.
local nobody = new_player("nobody", nil)
ok, err = grug_guild.buy(nobody, T1.item)
check(ok == false and err == "no_faction", "W no faction refused (no_faction)")

-- The window.
local shown
local formnames = {}
core.show_formspec = function(name, formname, formspec)
	formnames[#formnames + 1] = formname
	if formname == "grug_traders:trade" then shown = formspec end
	if formname:find("^grug_repair:service:") then shown = formspec end
end
core.close_formspec = function() end
core.chat_send_player = function() end
-- The harness's vector is a permissive stand-in: the two calls used here.
_G.vector = {}
vector.new = function(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x, y = y, z = z}
end
vector.distance = function(a, c)
	local dx, dy, dz = a.x - c.x, a.y - c.y, a.z - c.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end
local handlers = rawget(core, "registered_on_player_receive_fieldss") or {}
local function submit(player, formname, fields)
	for _, fn in ipairs(handlers) do
		if fn(player, formname, fields) then return end
	end
end
local function has(text) return shown ~= nil and shown:find(text, 1, true) ~= nil end
local KEY = {}
for index, row in ipairs(C.CONSUMABLES) do KEY[row.item] = index end

-- A camp in the harness's registry: its vendor socket and a quest socket.
local CAMP_KEY = "mining_camp_campnpc_test"
local CAMP_POS = {x = 100, y = 10, z = 100}
grug_core.register_settlement_sockets(CAMP_KEY, "dwarf", {x = 100, y = 9, z = 94}, {
	{id = "vendor_camp", role = "vendor", kind = "camp", x = 0, y = 1, z = 6, dir = {x = 0, z = -1}},
	{id = "quest_foreman", role = "quest", x = 3, y = 1, z = 6, dir = {x = 0, z = -1}},
}, "CAMPNPC Test Camp", "mining_camp")
local ORIGIN = {settlement = CAMP_KEY, socket = "vendor_camp"}

local bo = new_player("bo", "accord", {x = 101, y = 10, z = 101})
grug_traders.open(bo, CAMP, CAMP_POS, "accord", ORIGIN)
check(has("label[0.6,1.75;Miner's Guild]") and has("mode_tradein;Trade-in]"),
	"W the camp vendor opens on Trade-in")
check(has(";repair;Repair]"), "W the camp vendor shows Repair")
submit(bo, "grug_traders:trade", {mode_buy = "Buy"})
check(has("Rank 0 of 10") and has("Reach Reputation Rank 1") and has("Reach Reputation Rank 6"),
	"W rank 0: the page, every row locked")
check(not has("repbuy_"), "W rank 0: no buy button")
check(not has("tab_general"), "W the page has no shelf tabs")
-- Round 58 LIFT: the picked reputation icon is set, so a price is the icon
-- and the number (grug_guild.reputation_formspec).
check(has("grug_guild_reputation.png]label[") and
	has(";" .. grug_guild.format_points(T4.price) .. "]"), "W a locked row shows its price")
-- A forged click on a locked row buys nothing.
grug_guild.add(bo, 5, "test")
submit(bo, "grug_traders:trade", {["repbuy_" .. KEY[T1.item]] = "x"})
eq(count_of(bo.inv, T1.item), 0, "W a forged click on a locked row buys nothing")
-- Rank 3.
grug_guild.add(bo, C.RANKS[3], "test")
submit(bo, "grug_traders:trade", {mode_buy = "Buy"})
check(has("Rank 3 of 10") and has("repbuy_" .. KEY[T1.item] .. ";Buy]") and
	has("repbuy_" .. KEY[T3.item] .. ";Buy]"), "W rank 3: rows 1-3 have buttons")
check(not has("repbuy_" .. KEY[T4.item] .. ";") and has("Reach Reputation Rank 4") and
	not has("Reach Reputation Rank 3"), "W rank 3: row 4 locked")
check(has("Use from level 21"), "W an unlocked row says its use level")
local bl, bb = state(bo)
submit(bo, "grug_traders:trade", {["repbuy_" .. KEY[T1.item]] = "x"})
eq(count_of(bo.inv, T1.item), 1, "W the page's button buys")
check(has("Bought Ore Sense I for " .. grug_guild.format_points(T1.price) .. " reputation."),
	"W the status line")
l, b = state(bo)
check(l == bl and b == bb - T1.price, "W the page spends the balance, never the lifetime")
submit(bo, "grug_traders:trade", {["repbuy_" .. KEY[T4.item]] = "x"})
eq(count_of(bo.inv, T4.item), 0, "W a forged click on row 4 buys nothing")
-- The rank is checked again at the purchase: the form showed row 3 unlocked,
-- then an admin's /faction gives the other guild (rank 0 there).
submit(bo, "grug_traders:trade", {mode_buy = "Buy"})
bo.meta:set_string("grug_factions:faction", "throng")
grug_core.feed = grug_core.feed or function() end
local refused_life = grug_guild.lifetime(bo)
submit(bo, "grug_traders:trade", {["repbuy_" .. KEY[T3.item]] = "x"})
eq(count_of(bo.inv, T3.item), 0, "W the rank is checked again at the purchase")
eq(grug_guild.lifetime(bo), refused_life, "W ...and nothing spent")
bo.meta:set_string("grug_factions:faction", "accord")

-- The exchange counter: Trade-in, Sell, no page.
local cy = new_player("cy", "accord", {x = 0, y = 0, z = 0})
grug_guild.add(cy, C.RANKS[6], "test")
grug_traders.open(cy, EXCHANGE, {x = 0, y = 0, z = 0}, "accord")
check(has("label[0.6,1.75;Miner's Guild]"), "W the exchange counter opens on Trade-in")
check(not has(";repair;Repair]"), "W the exchange counter does not repair")
submit(cy, "grug_traders:trade", {mode_buy = "Buy"})
check(has("The Miner's Guild sells its goods at the mining camps.") and not has("repbuy_"),
	"W the exchange counter has no reputation page")
submit(cy, "grug_traders:trade", {["repbuy_" .. KEY[T1.item]] = "x"})
eq(count_of(cy.inv, T1.item), 0, "W a forged page click at the exchange counter buys nothing")
submit(cy, "grug_traders:trade", {mode_sell = "Sell"})
check(has("The vendor buys most things"), "W the exchange counter buys like every vendor")

-- The other faction is refused at the window (the camp's faction).
local orc = new_player("grosh", "throng", {x = 101, y = 10, z = 101})
shown = nil
grug_traders.open(orc, CAMP, CAMP_POS, "accord", ORIGIN)
eq(shown, nil, "W the camp vendor refuses the other faction")

-- Repair.
check(grug_repair.can_open_camp_vendor(bo, CAMP_KEY, "vendor_camp"), "W repair permitted at the camp vendor")
check(not grug_repair.can_open_camp_vendor(orc, CAMP_KEY, "vendor_camp"), "W repair refuses the other faction")
check(not grug_repair.can_open_camp_vendor(bo, CAMP_KEY, "quest_foreman"),
	"W repair refuses a socket that is no camp vendor's")
check(not grug_repair.can_open_camp_vendor(bo, "no_such_camp", "vendor_camp"), "W repair refuses an unknown camp")
local far = bo.pos
bo.pos = {x = 120, y = 10, z = 120}
check(not grug_repair.can_open_camp_vendor(bo, CAMP_KEY, "vendor_camp"), "W repair refuses a player out of range")
bo.pos = far
check(not grug_repair.provider_permitted(bo, {kind = "camp_vendor", settlement = CAMP_KEY}),
	"W a provider without a socket is refused")

-- A worn item, repaired through the camp vendor's button.
local GEAR
for name, def in pairs(core.registered_items) do
	if not GEAR and name:find("^grug_gear:") and grug_repair.eligible(ItemStack(name)) then
		local price = grug_gear.reference_purchase_price(ItemStack(name))
		if price and price > 0 then GEAR = name end
	end
end
if check(GEAR ~= nil, "W a repairable gear item exists") then
	local worn = ItemStack(GEAR)
	worn:set_wear(32768)
	bo.inv:set_stack("main", 9, worn)
	grug_money.add(bo, 100000)
	grug_traders.open(bo, CAMP, CAMP_POS, "accord", ORIGIN)
	submit(bo, "grug_traders:trade", {repair = "Repair"})
	eq(formnames[#formnames], "grug_traders:trade", "W Repair stays in the trader form")
	check(has(";mode_buy;Buy]") and has(";mode_sell;Sell]") and has(";mode_tradein;Trade-in]"), "W Repair keeps all trader navigation")
	check(not has("button_exit["), "W embedded Repair has no separate Close")
	check(has("repair_1;Repair "), "W ...listing the worn item")
	local money = grug_money.get(bo)
	local all_field = assert(shown:match(";(quote_%d+_all);Repair all:"))
	submit(bo, formnames[#formnames], {[all_field] = "Repair all"})
	eq(bo.inv:get_stack("main", 9):get_wear(), 0, "W the camp vendor repairs")
	check(grug_money.get(bo) < money, "W ...for money")
	-- A stale Buy click cannot buy while the current mode is Repair.
	local before = count_of(bo.inv, T1.item)
	submit(bo, "grug_traders:trade", {["repbuy_" .. KEY[T1.item]] = "x"})
	eq(count_of(bo.inv, T1.item), before, "W wrong-mode Buy is ignored")
	bo.inv:set_stack("main", 9, worn)
	local after_repair_money = grug_money.get(bo)
	submit(bo, "grug_traders:trade", {[all_field] = "Repair all"})
	eq(bo.inv:get_stack("main", 9):get_wear(), 32768, "W stale quote action cannot repair new wear")
	eq(grug_money.get(bo), after_repair_money, "W stale quote action spends nothing")
	submit(bo, "grug_traders:trade", {mode_buy = "Buy"})
	check(has("repbuy_"), "W Buy returns within the same trader session")
	submit(bo, "grug_traders:trade", {repair = "Repair"})
	local fresh_all = assert(shown:match(";(quote_%d+_all);Repair all:"))
	local old_pos = bo.get_pos
	bo.get_pos = function() return {x = CAMP_POS.x + 20, y = CAMP_POS.y, z = CAMP_POS.z} end
	submit(bo, "grug_traders:trade", {[fresh_all] = "Repair all"})
	eq(bo.inv:get_stack("main", 9):get_wear(), 32768, "W embedded repair refuses leaving trader range")
	bo.get_pos = old_pos

end
-- Repair from the button is refused for a window opened without its socket.
grug_traders.open(bo, CAMP, CAMP_POS, "accord")
check(not has(";repair;Repair]"), "W no Repair without the vendor's socket")

if failures > 0 then
	error(("R58 CAMPNPC PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
print(("R58 CAMPNPC PORTABLE PASS checks=%d"):format(checks))
