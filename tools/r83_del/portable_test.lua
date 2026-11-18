-- Round 83 lane DEL portable test (LuaJIT): the per-character clears of the
-- deletion (grug_core/character_delete.lua), each on the real mod code.
--
--   luajit tools/r83_del/portable_test.lua [repo]
--
-- The bridge's side (the command, the deferred answer, the login guards, the
-- grug_accounts and grug_mail clears, the start's mail pruning) is
-- tools/r691_bridge/portable_test.lua section I and J and
-- tools/r79_acc/portable_test.lua section D. This file loads on a small fake
-- engine the REAL grug_core/character_delete.lua, grug_parties/init.lua (its
-- ui.lua and hud.lua skipped), grug_clans/init.lua (its social.lua skipped),
-- grug_expeditions/runs.lua (catalogue, preparation and templates stubbed),
-- grug_housing's registry.lua, recovered.lua and admin.lua (api.lua's engine
-- calls stubbed) and grug_home/claim_home.lua, and checks:
--   R  the registry: the order of MODS, a missing clear named, a failing
--      clear stops neither the others nor the error;
--   P  a deleted party leader: the line to the online members, the party of
--      two dissolves, its Expedition passes to the last member;
--   K  a deleted clan leader: the line, the first captain leads (ruling 2),
--      the stored clan; a deleted member of a clan of two dissolves it;
--   E  a solo owner's Expedition ends with the reason "deleted";
--   H  housing: every claim of the name released with its stone (also one
--      its record no longer names), the event "deleted", no "claim lost"
--      notice from grug_home (a loss event still writes one; the clear drops
--      it), its rights in another claim gone and the others' kept, its record
--      dropped, its map-reset belongings and packed contents gone and a
--      name that only starts with it kept;
--   A  every clear again changes nothing (the deletion runs them twice).

local repo = arg and arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function eq(a, b, label)
	checks = checks + 1
	if a ~= b then
		error(("FAIL %s: got %s, wanted %s"):format(label, tostring(a), tostring(b)), 2)
	end
end

--
-- The fake engine
--

local function serialize(value)
	local kind = type(value)
	if kind == "table" then
		local parts, keys = {}, {}
		for k in pairs(value) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		for _, k in ipairs(keys) do
			parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(value[k])
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif kind == "string" then
		return ("%q"):format(value)
	end
	return tostring(value)
end

local wall = 1794000000
os.time = function() return wall end -- luacheck: ignore
local current_mod = "test"
local stores, hooks, logs, chats, players, joined = {}, {}, {}, {}, {}, {}
local nodes, removed_nodes = {}, {}

local function new_store(name)
	local rows = stores[name] or {}
	stores[name] = rows
	return {
		get_string = function(_, key) return rows[key] or "" end,
		set_string = function(_, key, value) rows[key] = value ~= "" and value or nil end,
		get_keys = function()
			local keys = {}
			for key in pairs(rows) do keys[#keys + 1] = key end
			table.sort(keys)
			return keys
		end,
	}
end
local function hook(kind)
	return function(fn) hooks[#hooks + 1] = {kind = kind, fn = fn} end
end
local function run_hooks(kind, ...)
	for _, entry in ipairs(hooks) do
		if entry.kind == kind then entry.fn(...) end
	end
end
local function pos_key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end

_G.core = {
	colorize = function(color, text) return "\27(c@" .. color .. ")" .. text .. "\27(c@#ffffff)" end,
	get_modpath = function(name) return repo .. "/mods/PLAYER/" .. name end,
	get_current_modname = function() return current_mod end,
	get_mod_storage = function() return new_store(current_mod) end,
	serialize = function(value) return "return " .. serialize(value) end,
	deserialize = function(text)
		local fn = loadstring(text)
		if not fn then return nil end
		local ok, value = pcall(fn)
		return ok and value or nil
	end,
	get_us_time = function() return 1000000 end,
	after = function() end,
	register_globalstep = function() end,
	register_on_joinplayer = hook("join"),
	register_on_leaveplayer = hook("leave"),
	register_on_shutdown = hook("shutdown"),
	register_chatcommand = function() end,
	get_player_by_name = function(name) return joined[name] and players[name] or nil end,
	chat_send_player = function(name, text)
		chats[name] = chats[name] or {}
		chats[name][#chats[name] + 1] = text
	end,
	log = function(level, text) logs[#logs + 1] = level .. ": " .. text end,
	load_area = function() end,
	get_node_or_nil = function(pos)
		local name = nodes[pos_key(pos)]
		return name and {name = name} or nil
	end,
	remove_node = function(pos)
		nodes[pos_key(pos)] = nil
		removed_nodes[#removed_nodes + 1] = pos_key(pos)
	end,
	pos_to_string = function(pos) return "(" .. pos_key(pos) .. ")" end,
	close_formspec = function() end,
}

local Meta = {}
Meta.__index = Meta
function Meta:get_string(key) return self.fields[key] or "" end
function Meta:set_string(key, value) self.fields[key] = value ~= "" and value or nil end
function Meta:get_int(key) return tonumber(self.fields[key]) or 0 end
function Meta:set_int(key, value) self.fields[key] = value ~= 0 and tostring(value) or nil end

local function make_player(name)
	local p = {name = name, faction = "accord", level = 10, class = "warrior",
		meta = setmetatable({fields = {}}, Meta)}
	function p:get_player_name() return self.name end
	function p:is_player() return true end
	function p:get_meta() return self.meta end
	function p:get_hp() return 20 end
	function p:get_pos() return {x = 0, y = 0, z = 0} end
	function p:get_properties() return {hp_max = 20} end
	players[name] = p
	return p
end
local function join(name)
	local p = players[name] or make_player(name)
	joined[name] = true
	run_hooks("join", p)
	return p
end
local function heard(name)
	local list = chats[name] or {}
	chats[name] = nil
	return list
end

_G.grug_core = {
	character_delete = dofile(repo .. "/mods/CORE/grug_core/character_delete.lua"),
	map_reset = {clear = function() end, register_on_relocate = function() end},
	world_version = {register_pack_handler = function() end},
	feed = function() end,
}
_G.grug_factions = {
	get_faction = function(p) return p.faction end,
	register_on_faction_chosen = hook("faction"),
}
_G.grug_xp = {
	get_level = function(p) return type(p) == "table" and p.level or 10 end,
	register_on_level_change = hook("level"),
}
_G.grug_classes = {
	get_class = function(p) return p.class end,
	register_on_class_chosen = hook("class"),
	register_on_race_chosen = hook("race"),
}

-- R. The registry ------------------------------------------------------------
do
	local registry = grug_core.character_delete
	local order = {}
	for index, mod in ipairs(registry.MODS) do order[mod] = index end
	eq(order.grug_accounts, 1, "R the tombstone first")
	check(order.grug_parties < order.grug_expeditions, "R parties before Expeditions")
	check(order.grug_housing < order.grug_home, "R housing before home")
	for _, mod in ipairs({"grug_classes", "grug_clans", "grug_mail", "grug_achievements"}) do
		check(order[mod], "R listed: " .. mod)
	end
	local real = registry.MODS
	local ran = {}
	_G.r83_a = {forget_character = function(name) ran[#ran + 1] = "a:" .. name end}
	_G.r83_b = {forget_character = function() error("broken") end}
	_G.r83_c = {forget_character = function(name) ran[#ran + 1] = "c:" .. name end}
	registry.MODS = {"r83_a", "r83_b", "r83_c", "r83_d"}
	eq(table.concat(registry.missing(), ","), "r83_d", "R a missing clear is named")
	registry.MODS = {"r83_a", "r83_b", "r83_c"}
	local ok, err = pcall(registry.clear, "Vex")
	check(not ok and tostring(err):find("r83_b", 1, true), "R a failing clear is the error")
	eq(table.concat(ran, ","), "a:Vex,c:Vex", "R the others ran, in order")
	check(logs[#logs]:find("^error: %[grug_core%] the character clear of r83_b failed"),
		"R and logged")
	registry.MODS = real
end

--
-- The mods, with stored parties and clans: Vex leads a party with Hol and a
-- clan with Tol (member) and Hol (captain).
--

stores.grug_parties = {parties = "return " .. serialize({next_id = 1, groups = {
	[1] = {members = {"Vex", "Hol"}, leader = "Vex", faction = "accord", levels = {Vex = 10, Hol = 10}}}})}
stores.grug_clans = {clans = "return " .. serialize({next_id = 1, clans = {
	["1"] = {faction = "accord", members = {{name = "Vex", role = "leader", level = 10},
		{name = "Tol", role = "member", level = 5}, {name = "Hol", role = "captain", level = 10}}}}})}

local real_dofile = dofile
dofile = function(path) -- luacheck: ignore
	if path:match("grug_parties/ui%.lua$") or path:match("grug_parties/hud%.lua$") or
			path:match("grug_clans/social%.lua$") then
		return
	end
	return real_dofile(path)
end
current_mod = "grug_parties"
real_dofile(repo .. "/mods/PLAYER/grug_parties/init.lua")
current_mod = "grug_clans"
real_dofile(repo .. "/mods/PLAYER/grug_clans/init.lua")

-- grug_expeditions' runs.lua on stubs: one slot kind, no preparation.
local ended = {}
do
	_G.grug_home = {register_on_teleport = function() end}
	_G.grug_expeditions = {templates = {t = {places = {}, encounters = {}}}}
	local catalogue = {SLOTS = 4, DESERTER_SECONDS = 600,
		slot_box = function(slot) return {x = slot * 100, y = 0, z = 0}, {x = slot * 100 + 50, y = 50, z = 50} end,
		slot_at = function() return nil end,
		definition = function() return {level = 10, max_level = 10, max_players = 5, template = "t"} end,
		entry_level = function() return 1 end}
	local preparation = {init = function() end, enqueue = function() end, cancel = function() end,
		status = function() return "ready" end}
	current_mod = "grug_expeditions"
	assert(loadfile(repo .. "/mods/PLAYER/grug_expeditions/runs.lua"))(catalogue, preparation)
	grug_expeditions.register_on_end(function(run, reason) ended[#ended + 1] = reason end)
end

-- grug_housing: the real registry, recovered.lua and admin.lua; grug_home's
-- claim_home.lua hears the claim events.
local events = {}
do
	current_mod = "grug_housing"
	local storage = new_store("grug_housing")
	local model = real_dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")({
		storage = {get_string = function(key) return storage:get_string(key) end,
			set_string = function(key, value) storage:set_string(key, value) end,
			keys = function() return storage:get_keys() end},
		now = os.time})
	model.load()
	local listeners = {}
	_G.grug_housing = {model = model, storage = storage,
		STONE_NODES = {["grug_housing:claim_stone"] = true},
		player_claim = function(name) return model.player_claim(name) end,
		register_on_claim_changed = function(fn) listeners[#listeners + 1] = fn end,
		notify_claim_changed = function(claim, event)
			events[#events + 1] = event .. ":" .. claim.id
			for _, fn in ipairs(listeners) do fn(claim, event) end
		end,
		set_permission = function(claim, name, level)
			local ok, message = model.set_permission(claim, name, level)
			if ok then grug_housing.notify_claim_changed(claim, "permission") end
			return ok, message
		end,
	}
	function grug_housing.remove_stone_node(claim)
		local node = core.get_node_or_nil(claim.center)
		if node and grug_housing.STONE_NODES[node.name] then
			core.remove_node(claim.center)
			return true
		end
		return false
	end
	grug_housing.packed = {}
	real_dofile(repo .. "/mods/PLAYER/grug_housing/recovered.lua")
	real_dofile(repo .. "/mods/PLAYER/grug_housing/admin.lua")
	current_mod = "grug_home"
	_G.grug_home = grug_home or {}
	grug_home.register_on_teleport = grug_home.register_on_teleport or function() end
	real_dofile(repo .. "/mods/PLAYER/grug_home/claim_home.lua")
end
current_mod = "test"
dofile = real_dofile -- luacheck: ignore

local registry = grug_core.character_delete
registry.MODS = {"grug_parties", "grug_clans", "grug_expeditions", "grug_housing", "grug_home"}
eq(#registry.missing(), 0, "the loaded mods have their clears")

-- Map-reset belongings as the migration tool writes them, before any join
-- (recovered.lua reads the keys once).
local housing_rows = stores.grug_housing
housing_rows["recovered:Vex:1:1"] = "default:chest"
housing_rows["recovered:Vex:1:1.1"] = "default:dirt 99"
housing_rows["packed:Vex:1:2"] = "return {}"
housing_rows["recovered:Vexa:1:1"] = "default:chest"
housing_rows["packed:Vexa:1:1"] = "return {}"
housing_rows["recovered:Hol:1:1"] = "default:chest"
local hol = join("Hol")
heard("Hol")
local party_run = assert(grug_expeditions.create("Vex", "x", 0), "a party run")
eq(party_run.owner.kind, "party", "the party's run")
local solo_run = assert(grug_expeditions.create("Tol", "x", 0), "a solo run")

-- Housing: Vex's placed claim, an older claim its record no longer names,
-- and Hol's claim where Vex and Tol have rights.
local model = grug_housing.model
local orphan = model.create("Vex", {x = 0, y = 10, z = 0})
local placed = model.create("Vex", {x = 1000, y = 10, z = 0})
local hols = model.create("Hol", {x = 2000, y = 10, z = 0})
for _, claim in ipairs({orphan, placed, hols}) do nodes[pos_key(claim.center)] = "grug_housing:claim_stone" end
model.set_permission(hols, "Vex", "everything")
model.set_permission(hols, "Tol", "interact")
eq(grug_housing.recovered.count("Vex"), 2, "H Vex's belongings wait")
-- A loss event writes grug_home's notice; the deletion's clear drops it.
grug_housing.notify_claim_changed({id = 99, owner = "Vex"}, "destroyed")
eq(stores.grug_home["claim_lost:Vex"], "destroyed 99", "H a loss writes the notice")

-- The deletion of Vex, its clears in the registry's order.
events = {}
registry.clear("Vex")

-- P. The party.
local lines = heard("Hol")
local party_line = core.colorize("#6fb6ff", "[Party] Vex is no longer a member.")
local clan_line = core.colorize("#7ee081", "[Clan] Vex is no longer a member.")
local seen = {}
for _, line in ipairs(lines) do seen[line] = true end
check(seen[party_line], "P the party line")
eq(grug_parties.view("Hol"), nil, "P a party of two dissolves")
check(not stores.grug_parties.parties:find("Vex", 1, true), "P stored without Vex")
eq(party_run.owner.kind .. ":" .. tostring(party_run.owner.name), "player:Hol",
	"P its Expedition passes to the last member")
check(party_run.state ~= "ended", "P and goes on")

-- K. The clan.
check(seen[clan_line], "K the clan line")
check(seen[core.colorize("#7ee081", "[Clan] Hol now leads the clan.")], "K the first captain leads")
eq(grug_clans.role_of("Hol"), "leader", "K Hol leads")
check(not stores.grug_clans.clans:find("Vex", 1, true), "K stored without Vex")

-- H. Housing and home.
eq(model.claim_by_id(orphan.id), nil, "H the claim its record forgot is released")
eq(model.claim_by_id(placed.id), nil, "H the placed claim is released")
eq(nodes[pos_key(orphan.center)], nil, "H its stone removed")
eq(nodes[pos_key(placed.center)], nil, "H and the other")
eq(nodes[pos_key(hols.center)], "grug_housing:claim_stone", "H Hol's stone stands")
local kinds = table.concat(events, ",")
check(kinds:find("deleted:" .. orphan.id, 1, true) and kinds:find("deleted:" .. placed.id, 1, true),
	"H the event deleted")
check(not kinds:find("removed", 1, true) and not kinds:find("destroyed", 1, true), "H no loss event")
eq(stores.grug_home["claim_lost:Vex"], nil, "H no notice left")
eq(hols.permissions.Vex, nil, "H its right in Hol's claim")
eq(hols.permissions.Tol, "interact", "H another's right stays")
check(not housing_rows["claim:" .. hols.id]:find("Vex", 1, true), "H stored without it")
eq(housing_rows["player:Vex"], nil, "H its record")
eq(model.player_state("Vex"), "never", "H in memory too")
eq(grug_housing.recovered.count("Vex"), 0, "H its belongings")
eq(housing_rows["packed:Vex:1:2"], nil, "H its packed contents")
eq(housing_rows["recovered:Vexa:1:1"] .. housing_rows["packed:Vexa:1:1"], "default:chestreturn {}",
	"H a longer name's stay")
eq(housing_rows["recovered:Hol:1:1"], "default:chest", "H others' stay")
for key in pairs(housing_rows) do
	check(not key:find("Vex:", 1, true) and not key:find(":Vex$"), "H no key of Vex: " .. key)
end
check(not logs[#logs] or not logs[#logs]:find("Vex", 1, true), "H no log line names it")

-- A. Twice changes nothing.
local before = serialize(stores)
events = {}
registry.clear("Vex")
eq(serialize(stores), before, "A a second run changes no store")
eq(#events, 0, "A and no event")
eq(#heard("Hol"), 0, "A and no line")

-- K, E. Tol: the clan of two dissolves, its solo Expedition ends.
registry.clear("Tol")
eq(grug_clans.role_of("Hol"), nil, "K a clan of two dissolves")
check(seen[clan_line], "K (Vex's line was heard)")
local dissolved = false
for _, line in ipairs(heard("Hol")) do
	dissolved = dissolved or line == core.colorize("#7ee081", "[Clan] The clan has been dissolved.")
end
check(dissolved, "K the other hears it")
eq(solo_run.state, "ended", "E the solo run ends")
eq(ended[#ended], "deleted", "E with the reason deleted")
eq(hols.permissions.Tol, nil, "H Tol's right goes too")
eq(grug_expeditions.run_of("Tol"), nil, "E nothing left for the name")
check(hol and party_run.state ~= "ended", "E Hol's run stays")

print(("r83_del PASS (%d checks)"):format(checks))
