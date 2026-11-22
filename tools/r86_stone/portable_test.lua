-- Round 86 lane STONE portable test (LuaJIT): the account Claim Stone
-- (docs/planning/housing-rework-concept.md §3.1 rulings 1-10,
-- docs/planning/round86-plan.md rulings 10, 13, 14, 16 and §2.3).
--
--   luajit tools/r86_stone/portable_test.lua [repo]
--
-- Loads the REAL grug_accounts (init, model, flow; its list drives unlink
-- and disappearance as tools/r79_acc does), the REAL grug_housing api.lua,
-- account.lua, stone.lua, packed.lua, recovered.lua, interface.lua (the
-- stone form and the Housing Steward), admin.lua and grug_home's
-- claim_home.lua on a fake engine with a clock, nodes, inventories and the
-- hooks. The claim mask is a stand-in that allows every chunk.
--
-- The state table (written from the rulings before the code; each row's
-- player-visible result is checked):
--   S  the choice at the Steward
--      S1 below level 20: both columns give the level line, nothing happens
--      S2 no account: the account column says it needs an account and a link
--      S3 a personal claim placed: "Pick up your Claim Stone first"
--      S4 a carried personal stone, choosing the account: the click asks
--         once, then the stone vanishes, an Account Claim Stone comes, the
--         character is a member; lane PACK's move is called (name, owner)
--      S5 the reverse: a member carrying an account stone leaves: the stone
--         vanishes, "personal, no stone", the personal button is back
--      S6 the account claim stands: "Join your account's home", no item
--      S7 it does not stand: a member without a stone gets one
--   D  ruling 16
--      D1 two members place drafts; one activates; the other draft goes at
--         once, its block loaded, its placer told
--      D2 a leftover account stone vanishes at the placing attempt, with its
--         line
--      D3 a draft crumbling changes nothing for the others
--      D4 the refusals live in the registry (validate, activate)
--   R  rights
--      R1 a member opens the form, fuels, sets permissions, picks up
--      R2 a same-account character with a personal stone has none unless
--         the permission list names it
--      R3 a member's name is refused in the permission list
--      R4 a character whose name equals an account id has no rights anywhere
--   L  leaving
--      L1 never the last member of a standing claim; another member may
--      L2 joining and leaving repeatedly: no item, no second claim, no free
--         stone, no quota
--   E  the claim ends: fuel runs out (the members stay owners), dug as
--      empty (every member told, each may get a stone again), picked up by
--      a member (the stone and the lumps go to it)
--   U  losing the link
--      U1 unlink of a member: it leaves, its home falls back with a line,
--         its carried account stone vanishes
--      U2 unlink of the last member (ruling 18 of 2026-11-22): the claim
--         stands ownerless, protects (its former member too), cannot be
--         opened or refuelled; a relinked character joins it (no item) and
--         owns it; the bad lists (empty, a malformed account row, a lower
--         version) leave it standing; its fuel running out makes it the
--         empty stone (still joinable, refuelled by a new owner, dug by
--         anyone); an empty claim meeting a list change stays; the offline
--         character's notice at its join; no reconcile without a held list
--      F  an admin's faction change of the last member ends it at once
--      U3 the account vanishes from the list: every member goes, the claim
--         stands ownerless; /claim_remove here ends it at once
--      U4 a binding that stops counting without an event: the reconcile at
--         load finds it
--      U5 character.delete of a member and of the last member (the binding
--         is forgotten first)
--      U6 an admin's faction change counts as leaving
--   M  the map reset (ruling 14): members stay members; v2 records of
--      0.83.0 and 0.85.0 still decode; a 0.85.0 world plays on
--   H  "Set as home", travel and respawn per member; the loss notice
--      reaches every member
--   G  /claim_remove <member> removes the account claim
-- Prints "R86 STONE PORTABLE PASS checks=<n>".

local repo = arg and arg[1] or "."
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end
local function eq(actual, expected, label)
	check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end
local function has(text, needle, label)
	check(type(text) == "string" and text:find(needle, 1, true) ~= nil,
		label .. " (missing " .. needle .. ")")
end
local function lacks(text, needle, label)
	check(type(text) == "string" and text:find(needle, 1, true) == nil,
		label .. " (unexpected " .. needle .. ")")
end

--
-- Fake engine
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
local function deserialize(text)
	local chunk = loadstring("return " .. text:gsub("^return ", ""))
	return chunk and chunk() or nil
end

local clock = 1800000000
os.time = function() return clock end -- luacheck: ignore

local STACK_MAX = {}
local function ItemStackImpl(spec)
	local name, count = "", 0
	if type(spec) == "string" and spec ~= "" then
		local n, c = spec:match("^(%S+)%s*(%d*)$")
		name, count = n, tonumber(c) or 1
	elseif type(spec) == "table" then
		name, count = spec.name or spec:get_name(), spec.count or spec:get_count()
	end
	local s = {name = name, count = count}
	function s:get_name() return self.count > 0 and self.name or "" end
	function s:get_count() return self.name ~= "" and self.count or 0 end
	function s:is_empty() return self.count <= 0 or self.name == "" end
	function s:take_item(n)
		n = math.min(n or 1, self.count)
		self.count = self.count - n
		return ItemStackImpl(self.name .. " " .. n)
	end
	function s:set_count(n) self.count = n end
	function s:get_stack_max() return STACK_MAX[self.name] or 99 end
	function s:to_string() return self:is_empty() and "" or (self.name .. " " .. self.count) end
	function s:get_meta() return {get_string = function() return "" end} end
	return s
end
ItemStack = ItemStackImpl

local stores = {}
local function new_store(mod)
	local rows = stores[mod] or {}
	stores[mod] = rows
	return {
		get_string = function(_, k) return rows[k] or "" end,
		set_string = function(_, k, v) if v == "" then rows[k] = nil else rows[k] = v end end,
		get_keys = function()
			local keys = {}
			for k in pairs(rows) do keys[#keys + 1] = k end
			return keys
		end,
	}
end

local hooks = {join = {}, leave = {}, die = {}, mods_loaded = {}, fields = {}, globalstep = {}}
local timers = {}
local players, known, chats, shown, closed = {}, {}, {}, {}, {}
local nodes, loaded = {}, {}
local function key(p) return p.x .. "/" .. p.y .. "/" .. p.z end
local current_mod = "grug_accounts"
local MODPATH = {
	grug_accounts = repo .. "/mods/PLAYER/grug_accounts",
	grug_housing = repo .. "/mods/PLAYER/grug_housing",
	grug_home = repo .. "/mods/PLAYER/grug_home",
}
local escapes = {["\\"] = "\\\\", ["["] = "\\[", ["]"] = "\\]", [";"] = "\\;",
	[","] = "\\,", ["$"] = "\\$"}
local logs = {}

core = {
	log = function(level, text) logs[#logs + 1] = level .. " " .. text end,
	serialize = function(value) return "return " .. serialize(value) end,
	deserialize = deserialize,
	get_modpath = function(name) return MODPATH[name] end,
	-- Round 86 ART: a placed stone faces its placer (builtin's rule).
	dir_to_fourdir = function(d)
		if math.abs(d.x) > math.abs(d.z) then return d.x < 0 and 3 or 1 end
		return d.z < 0 and 2 or 0
	end,
	get_current_modname = function() return current_mod end,
	get_mod_storage = function() return new_store(current_mod) end,
	sha1 = function(text) return ("%040x"):format(#text) end,
	get_us_time = function() return 1 end,
	after = function(delay, func, ...)
		timers[#timers + 1] = {func = func, args = {...}}
	end,
	get_player_by_name = function(name) return players[name] end,
	get_connected_players = function()
		local list = {}
		for _, p in pairs(players) do list[#list + 1] = p end
		return list
	end,
	player_exists = function(name) return known[name] == true end,
	get_auth_handler = function() return {get_auth = function() return nil end} end,
	chat_send_player = function(name, text)
		chats[name] = chats[name] or {}
		table.insert(chats[name], text)
	end,
	show_formspec = function(name, formname, fs)
		shown[#shown + 1] = {name = name, formname = formname, fs = fs}
	end,
	close_formspec = function(name, formname) closed[#closed + 1] = {name, formname} end,
	formspec_escape = function(text) return text and (string.gsub(text, "[\\%[%];,$]", escapes)) end,
	colorize = function(color, message) return "\27(c@" .. color .. ")" .. message .. "\27(c@#ffffff)" end,
	registered_nodes = {air = {buildable_to = true}, ["default:stone"] = {}},
	registered_items = {},
	register_node = function(name, def) core.registered_nodes[name] = def; core.registered_items[name] = def end,
	register_craftitem = function(name, def) core.registered_items[name] = def end,
	override_item = function() end,
	register_chatcommand = function(name, def) core.commands = core.commands or {}; core.commands[name] = def end,
	register_on_joinplayer = function(fn) table.insert(hooks.join, fn) end,
	register_on_leaveplayer = function(fn) table.insert(hooks.leave, fn) end,
	register_on_dieplayer = function(fn) table.insert(hooks.die, fn) end,
	register_on_mods_loaded = function(fn) table.insert(hooks.mods_loaded, fn) end,
	register_on_player_receive_fields = function(fn) table.insert(hooks.fields, fn) end,
	register_globalstep = function(fn) table.insert(hooks.globalstep, fn) end,
	register_on_placenode = function() end,
	create_detached_inventory = function()
		local lists = {}
		local inv = {}
		function inv:set_size(list, size)
			lists[list] = {}
			for i = 1, size do lists[list][i] = ItemStack("") end
		end
		function inv:set_list(list, stacks) lists[list] = stacks end
		function inv:set_stack(list, index, stack) lists[list][index] = stack end
		function inv:get_stack(list, index) return lists[list][index] end
		return inv
	end,
	remove_detached_inventory = function() end,
	explode_textlist_event = function() return {type = "INV", index = 0} end,
	pos_to_string = function(p) return "(" .. p.x .. "," .. p.y .. "," .. p.z .. ")" end,
	get_node_or_nil = function(p)
		if not loaded[key(p)] and nodes[key(p)] then return nil end
		return {name = nodes[key(p)] or "air"}
	end,
	get_node = function(p) return {name = nodes[key(p)] or "air"} end,
	set_node = function(p, node) nodes[key(p)] = node.name; loaded[key(p)] = true end,
	swap_node = function(p, node) nodes[key(p)] = node.name end,
	remove_node = function(p) nodes[key(p)] = nil end,
	load_area = function(p) loaded[key(p)] = true end,
	is_protected = function() return false end,
	record_protection_violation = function() end,
	add_item = function() end,
}
vector = {new = function(x, y, z) return {x = x, y = y, z = z} end,
	equals = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end}
function string.trim(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end

local function run_timers()
	while #timers > 0 do
		local list = timers
		timers = {}
		for _, t in ipairs(list) do t.func(unpack(t.args)) end
	end
end

-- Players with a meta and a list inventory (main 8 slots, one bag).
local Meta = {}
Meta.__index = Meta
function Meta:get_string(k) return self.fields[k] or "" end
function Meta:set_string(k, v) self.fields[k] = v ~= "" and v or nil end
function Meta:get_int(k) return tonumber(self.fields[k]) or 0 end
function Meta:set_int(k, v) self.fields[k] = tostring(v) end

local levels, factions = {}, {}
local function new_player(name, faction, level, id)
	local p = {name = name, pos = {x = 0, y = 10, z = 0}, meta = setmetatable({fields = {}}, Meta)}
	local lists = {main = {}, bag1 = {}}
	for i = 1, 8 do lists.main[i] = ItemStack("") end
	for i = 1, 4 do lists.bag1[i] = ItemStack("") end
	local inv = {}
	function inv:get_lists() return lists end
	function inv:get_list(l) return lists[l] end
	function inv:get_size(l) return lists[l] and #lists[l] or 0 end
	function inv:set_stack(l, i, stack) lists[l][i] = ItemStack(stack) end
	function inv:get_stack(l, i) return lists[l][i] end
	function inv:contains_item(l, item)
		local want = type(item) == "string" and item:match("^(%S+)") or item:get_name()
		for _, s in ipairs(lists[l] or {}) do if s:get_name() == want then return true end end
		return false
	end
	function inv:add_item(l, stack)
		stack = ItemStack(stack)
		for i, s in ipairs(lists[l]) do
			if s:is_empty() then lists[l][i] = stack; return ItemStack("") end
		end
		return stack
	end
	function inv:remove_item(l, stack)
		stack = ItemStack(stack)
		local taken = 0
		for _, s in ipairs(lists[l] or {}) do
			if s:get_name() == stack:get_name() and taken < stack:get_count() then
				local n = math.min(s:get_count(), stack:get_count() - taken)
				s.count, taken = s.count - n, taken + n
			end
		end
		return ItemStack(stack:get_name() .. " " .. taken)
	end
	function inv:room_for_item(l, stack)
		for _, s in ipairs(lists[l]) do if s:is_empty() then return true end end
		return false
	end
	p.inv = inv
	function p:get_player_name() return self.name end
	function p:is_player() return true end
	function p:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
	function p:get_meta() return self.meta end
	function p:get_inventory() return self.inv end
	function p:get_hp() return 20 end
	function p:get_player_control() return {} end
	function p:set_formspec_prepend() end
	factions[name], levels[name] = faction, level or 25
	if id then p.meta:set_string("grug_accounts:character_id", id) end
	known[name] = true
	return p
end
local function join(p)
	players[p.name] = p
	for _, fn in ipairs(hooks.join) do fn(p) end
	run_timers()
	return p
end
local function leave(p)
	for _, fn in ipairs(hooks.leave) do fn(p) end
	players[p.name] = nil
end
local function count_item(p, item)
	local n = 0
	for _, list in pairs(p.inv:get_lists()) do
		for _, s in ipairs(list) do if s:get_name() == item then n = n + s:get_count() end end
	end
	return n
end
local function give(p, item) p.inv:add_item("main", ItemStack(item)) end
local function heard(name)
	local list = chats[name] or {}
	chats[name] = nil
	return table.concat(list, "\n")
end

--
-- The game's other mods, as far as these files use them
--

grug_sounds = {play = function() return false end, CLICK_STYLE = ""}
local feeds = {}
local faction_callbacks = {}
grug_core = {text = dofile(repo .. "/mods/CORE/grug_core/text.lua"),
	feed = function(player, kind, text) feeds[#feeds + 1] = player:get_player_name() .. ": " .. text end,
	flash = function() end,
	map_reset = {clear = function(_, fn) grug_core.map_reset.fn = fn end, pending = function() return false end,
		register_on_relocate = function(fn) grug_core.map_reset.relocate = fn end},
	severe = {report = function() end},
	placement_refused = function() return false end,
	zone_authority_installed = function() return true end,
	get_player_faction = function(name) return players[name] and factions[name] or nil end,
	npc_window_permitted = function() return true end,
	assign_service_socket = function() end,
	settlement_sockets_at = function() return {} end,
	world_version = {register_pack_handler = function() end},
	world_alterable = function() return true end,
}
dofile(repo .. "/mods/CORE/grug_core/ui.lua")
grug_factions = {
	get_faction = function(player) return factions[player:get_player_name()] end,
	register_on_faction_chosen = function(fn) faction_callbacks[#faction_callbacks + 1] = fn end,
}
local function set_faction(p, id)
	factions[p.name] = id
	for _, fn in ipairs(faction_callbacks) do fn(p, id) end
end
grug_classes = {get_class = function() return "warrior" end, register_on_arrival = function() end}
grug_xp = {get_level = function(player) return levels[player:get_player_name()] or 1 end}
grug_mobs = {register_start_socket_role = function() end,
	spawn_regions = {area_by_tag = function() return nil end}}
grug_zones = {}
grug_inventory = {
	give = function(player, stack) return player:get_inventory():add_item("main", stack) end,
	fits = function(player) return player:get_inventory():room_for_item("main") end,
	consume_lists = function() return {"main", "bag1"} end,
	carried_lists = function() return {"main", "bag1"} end,
	HOTBAR_STORE = "store",
	STATION = {x = 0.52, y = 0.78, pitch = 1.25, box_x = 0.3, box_w = 10},
	VIEW_GEOMETRY = {width = 10},
	station_box = function() return "", 1 end,
	station_formspec = function(_, content) return content end,
	keep_scroll = function() return false end,
	hotbar_switch_fields = function() return false end,
}
sfinv = {contexts = {}, set_player_inventory_formspec = function() end}

-- grug_accounts, real (its page needs no sfinv here)
current_mod = "grug_accounts"
local real_sfinv = sfinv
sfinv = nil
dofile(MODPATH.grug_accounts .. "/init.lua")
sfinv = real_sfinv
-- grug_housing, real (mask.lua, soulbound, protection, interaction left out)
current_mod = "grug_housing"
grug_housing = {}
for _, file in ipairs({"api.lua", "account.lua", "stone.lua", "packed.lua", "recovered.lua",
		"interface.lua", "admin.lua"}) do
	dofile(MODPATH.grug_housing .. "/" .. file)
end
local H, model = grug_housing, grug_housing.model
-- The claim mask stand-in: every chunk is claim ground, no quota.
H.mask = {ground = function() return true end, quota_refusal = function() return nil end,
	add_taken = function() end}
-- Lane PACK's seam, spied.
local moves = {}
local real_move = H.recovered.move_to_account
H.recovered.move_to_account = function(name, owner)
	moves[#moves + 1] = name .. ">" .. tostring(owner)
	return real_move(name, owner)
end
-- grug_home, real claim_home.lua on an innkeeper stand-in
current_mod = "grug_home"
local INN = {id = "highcourt", label = "Highcourt"}
grug_home = {innkeeper = function() return INN end, cancel = function() end}
dofile(MODPATH.grug_home .. "/claim_home.lua")
for _, fn in ipairs(hooks.mods_loaded) do fn() end
run_timers()

-- The list the website sends; ids are 32 hex characters.
local function cid(n) return ("%032x"):format(n) end
local version = 0
local function send(accounts, characters)
	version = version + 1
	local list = {version = version, accounts = {}, characters = {}}
	for _, id in ipairs(accounts) do list.accounts[#list.accounts + 1] = {id = id, name = id, rewards = {}} end
	for name, row in pairs(characters) do
		list.characters[#list.characters + 1] = {name = name, character_id = row[1], account_id = row[2]}
	end
	grug_accounts.apply_list(list)
	run_timers()
end

local STONE, ACC = H.STONE_ITEM, H.ACCOUNT_ITEM
local OWNER = model.owner_text("acc_1", "accord")

-- Steward helpers
local npc = {}
local function steward(p)
	assert(H.open_manager(p, npc))
	return shown[#shown].fs
end
local function press(p, field)
	for _, fn in ipairs(hooks.fields) do
		if fn(p, "grug_housing:manager", {[field] = ""}) then break end
	end
	return shown[#shown].fs
end
-- Placing an item at pos (on stone below).
local function place(p, item, pos)
	nodes[key({x = pos.x, y = pos.y - 1, z = pos.z})] = "default:stone"
	local stack = nil
	for _, list in pairs(p.inv:get_lists()) do
		for _, s in ipairs(list) do if s:get_name() == item then stack = s end end
	end
	assert(stack, p.name .. " holds no " .. item)
	return core.registered_nodes[item].on_place(stack, p,
		{type = "node", under = {x = pos.x, y = pos.y - 1, z = pos.z}, above = pos})
end
local function activate(p)
	give(p, "default:coal_lump 5")
	return H.activate(p)
end

--
-- The characters: Ann, Bea, Cid on account acc_1 (The Accord), Dan on acc_1
-- with a personal stone, Eve unlinked, "acc_1" a character named like the
-- account id, Fay on acc_2.
--
local ann = join(new_player("Ann", "accord", 25, cid(1)))
local bea = join(new_player("Bea", "accord", 25, cid(2)))
local cid3 = join(new_player("Cid", "accord", 25, cid(3)))
local dan = join(new_player("Dan", "accord", 25, cid(4)))
local eve = join(new_player("Eve", "accord", 25, cid(5)))
local twin = join(new_player("acc_1", "accord", 25, cid(6)))
local low = join(new_player("Low", "accord", 12, cid(7)))
send({"acc_1", "acc_2"}, {Ann = {cid(1), "acc_1"}, Bea = {cid(2), "acc_1"}, Cid = {cid(3), "acc_1"},
	Dan = {cid(4), "acc_1"}, Low = {cid(7), "acc_1"}})
eq(H.binding_owner("Ann", "accord"), OWNER, "the owner text of Ann's binding")

-- S1 below level 20
do
	local fs = steward(low)
	has(fs, "You need level 20 to choose a Claim Stone.", "S1 the account column's level line")
	has(fs, "You need level 20 to receive a Claim Stone.", "S1 the personal column's level line")
	lacks(fs, ";account;", "S1 no account button")
	local ok = H.choose_account(low)
	check(not ok and model.account_owner_of("Low") == nil, "S1 the choice refused")
end

-- S2 no account
do
	local fs = steward(eve)
	has(fs, core.formspec_escape(H.NO_ACCOUNT_LINE), "S2 the account column needs an account")
	has(fs, ";receive;Receive Claim Stone]", "S2 the personal stone is offered")
	check(not H.choose_account(eve), "S2 the choice refused")
end

-- S3 a personal claim placed (Dan)
do
	check(H.issue_stone(dan), "S3 Dan receives a personal stone")
	place(dan, STONE, {x = 1000, y = 10, z = 0})
	local claim, state = H.player_claim("Dan")
	check(claim and state == "placed", "S3 Dan's personal draft stands")
	local fs = steward(dan)
	has(fs, "Pick up your Claim Stone first", "S3 the account column: pick up first")
	check(not H.choose_account(dan), "S3 the choice refused")
end

-- S4 a carried personal stone, choosing the account (Ann)
do
	check(H.issue_stone(ann), "S4 Ann receives a personal stone")
	eq(count_item(ann, STONE), 1, "S4 Ann carries it")
	local fs = steward(ann)
	has(fs, ";account;Choose the Account Claim Stone]", "S4 the account button")
	has(fs, "The Claim Stone you carry vanishes", "S4 the warning line")
	fs = press(ann, "account")
	has(fs, "Confirm: Choose the Account Claim Stone", "S4 the first click asks (the item's capitals kept)")
	eq(count_item(ann, STONE), 1, "S4 ...and takes nothing yet")
	fs = press(ann, "account")
	eq(count_item(ann, STONE), 0, "S4 the personal stone vanished")
	eq(count_item(ann, ACC), 1, "S4 an Account Claim Stone came")
	eq(model.account_owner_of("Ann"), OWNER, "S4 Ann is a member")
	eq(select(2, H.player_claim("Ann")), "member", "S4 her state")
	eq(moves[#moves], "Ann>" .. OWNER, "S4 PACK's move ran with the owner text")
	has(fs, "Here is your Account Claim Stone", "S4 the green line")
	has(fs, "You already carry a Claim Stone.", "S4 the account column: carried")
end

-- S7 / D: Bea and Cid choose too (no claim stands: each gets a stone)
do
	check(H.choose_account(bea) and count_item(bea, ACC) == 1, "S7 Bea gets an account stone")
	check(H.choose_account(cid3) and count_item(cid3, ACC) == 1, "S7 Cid gets one")
	check(not H.choose_account(bea), "S7 not a second one while carrying")
	eq(#model.members(OWNER), 3, "S7 three members")
end

-- D1 two members place drafts; Ann activates; Bea's draft goes at once
local A_POS, B_POS = {x = 0, y = 10, z = 0}, {x = 200, y = 10, z = 0}
do
	place(ann, ACC, A_POS)
	place(bea, ACC, B_POS)
	local a, b = H.player_claim("Ann"), H.player_claim("Bea")
	check(a and b and a ~= b and a.kind == "account" and b.kind == "account",
		"D1 two account drafts")
	eq(a.owner, "Ann", "D1 a draft belongs to its placer (ruling 16)")
	check(H.is_owner(a, "Ann") and not H.is_owner(a, "Bea"), "D1 ...only to it")
	eq(nodes[key(A_POS)], "grug_housing:account_stone_draft", "D1 the account draft node")
	eq(count_item(ann, ACC), 0, "D1 the placed stone left the inventory")
	loaded[key(B_POS)] = nil -- Bea's block unloaded
	local version = model.claim_set_version()
	local ok = activate(ann)
	check(ok, "D1 Ann activates")
	check(model.claim_set_version() ~= version, "V the activation's owner change bumps the claim set version")
	eq(a.owner, OWNER, "D1 the activated claim's owner is the owner text")
	eq(H.account_claim(OWNER), a, "D1 the account claim stands")
	check(model.claim_by_id(b.id) == nil, "D1 Bea's draft is gone at once")
	eq(nodes[key(B_POS)], nil, "D1 ...its node too, the block loaded for it")
	has(heard("Bea"), "Another character of your account activated its Claim Stone",
		"D1 Bea is told")
	eq(nodes[key(A_POS)], "grug_housing:account_stone", "D1 the fuelled account node")
	eq(select(2, H.player_claim("Bea")), "member", "D1 Bea stays a member")
	eq(H.player_claim("Bea"), a, "D1 ...whose claim is the account's")
end

-- D2 a leftover stone vanishes at the placing attempt (Cid)
do
	eq(count_item(cid3, ACC), 1, "D2 Cid still carries his")
	place(cid3, ACC, {x = 400, y = 10, z = 0})
	eq(count_item(cid3, ACC), 0, "D2 it vanished")
	has(heard("Cid"), "Your account's home already stands", "D2 with its line")
	eq(nodes[key({x = 400, y = 10, z = 0})], nil, "D2 nothing placed")
end

-- D4 the refusals live in the registry
do
	local ok, code = model.validate("Bea", "accord", {x = 600, y = 10, z = 0},
		{mask = H.mask, cube_clear = function() return true end}, "account")
	check(not ok and code == "account_stands", "D4 validate refuses a second account claim")
	local d = model.create("Bea", {x = 600, y = 10, z = 0}, "account")
	local burnt, why = model.activate(d, 5)
	check(burnt == 0 and why == "account_stands", "D4 activate refuses it")
	model.remove(d, "draft_expired")
	eq(select(2, H.player_claim("Bea")), "member", "D4 ...and the removal leaves Bea a member")
end

-- S6 the claim stands: joining gives no item (Dan picks his up first)
do
	clock = clock + 1
	local dclaim = H.player_claim("Dan")
	check(H.pick_up(dan), "S6 Dan picks his personal draft up")
	local fs = steward(dan)
	has(fs, ";account;Join your account's home]", "S6 the join button")
	press(dan, "account")
	press(dan, "account") -- he carries his personal stone: asked once
	eq(count_item(dan, ACC), 0, "S6 joining a standing claim gives no item")
	eq(count_item(dan, STONE), 0, "S6 his personal stone vanished")
	eq(model.account_owner_of("Dan"), OWNER, "S6 Dan is a member")
	check(model.claim_by_id(dclaim.id) == nil, "S6 his old draft is gone")
end

-- R rights
local claim = H.account_claim(OWNER)
do
	check(H.is_owner(claim, "Bea") and H.permission(claim, "Bea") == "owner", "R1 Bea owns it")
	-- the form opens for a member
	bea.pos = {x = 0, y = 11, z = 0}
	check(H.open_stone_interface(bea, claim), "R1 the form opens for a member")
	local fs = shown[#shown].fs
	has(fs, "Your account's Claim Stone", "R1 the account heading")
	has(fs, "Owners: Ann\\, Bea\\, Cid\\, Dan", "R1 the owners line")
	eq(H.add_fuel(claim, 3), 3, "R1 Bea fuels")
	local ok, message = H.set_permission(claim, "Ann", "interact")
	check(not ok and message == "The owner always has access.", "R3 a member's name is refused")
	ok = H.set_permission(claim, "Eve", "interact")
	check(ok and H.permission(claim, "Eve") == "interact", "R1 Bea sets a permission")
	-- R2 a same-account character with a personal stone: Fay? use Low (acc_1, no choice)
	eq(H.permission(claim, "Low"), nil, "R2 a same-account non-member has no rights")
	H.set_permission(claim, "Low", "everything")
	eq(H.permission(claim, "Low"), "everything", "R2 ...unless the list names it")
	H.set_permission(claim, "Low", nil)
	-- R4 a character named like the account id
	check(not H.is_owner(claim, "acc_1") and H.permission(claim, "acc_1") == nil,
		"R4 no rights for a name equal to the account id")
	local ok4 = model.protects({x = 5, y = 12, z = 5}, "acc_1", function() return false end)
	check(ok4, "R4 ...the claim protects against it")
	-- A visitor's right-click names the home (lane NAMES' home_name), not an owner.
	heard("Eve")
	core.registered_nodes["grug_housing:account_stone"].on_rightclick(claim.center, nil, eve, ItemStack(""))
	has(heard("Eve"), "Account Claim Stone of " .. H.home_name(claim) .. ".", "R a visitor's line names the home")
	check(not model.protects({x = 5, y = 12, z = 5}, "Cid", function() return false end),
		"R1 ...not against a member")
end

-- P3 a member's old permission entry: shown, removable, never granted
do
	H.set_permission(claim, "Zed", "interact")
	version = model.claim_set_version()
	model.join("Zed", OWNER)
	check(model.claim_set_version() ~= version, "V a join bumps the claim set version")
	eq(H.permission(claim, "Zed"), "owner", "P3 Zed joined: an owner")
	bea.pos = {x = 0, y = 11, z = 0}
	check(H.open_stone_interface(bea, claim), "P3 Bea's form")
	has(shown[#shown].fs, "Zed — Interact (an owner now)", "P3 the old entry shows")
	local ok, message = H.set_permission(claim, "Zed", "everything")
	check(not ok and message == "The owner always has access.", "P3 no new level for an owner")
	ok = H.set_permission(claim, "Zed", nil)
	check(ok and claim.permissions.Zed == nil, "P3 the old entry can be removed")
	version = model.claim_set_version()
	model.end_membership("Zed")
	check(model.claim_set_version() ~= version, "V leaving bumps the claim set version")
	eq(H.permission(claim, "Zed"), nil, "P3 Zed left: no access comes back")
end

-- L leaving
do
	heard("Cid")
	local ok = H.leave_account(cid3)
	check(ok and model.account_owner_of("Cid") == nil, "L1 Cid leaves")
	eq(select(2, H.player_claim("Cid")), "needs_stone", "L1 ...personal, no stone")
	local fs = steward(cid3)
	has(fs, ";receive;Receive Claim Stone]", "S5 the personal button is back")
	-- L2 join and leave again: no stone (the claim stands), no second claim
	local before = model.claim_count()
	for _ = 1, 3 do
		check(H.choose_account(cid3), "L2 Cid joins again")
		check(H.leave_account(cid3), "L2 ...and leaves")
	end
	eq(count_item(cid3, ACC) + count_item(cid3, STONE), 0, "L2 no stone gained")
	eq(model.claim_count(), before, "L2 no claim gained")
end

-- H "Set as home" per member; E the claim's fuel runs out, it is dug as
-- empty: every member told, each may get a stone again
local function at_stone(p, c) p.pos = {x = c.center.x, y = c.center.y + 1, z = c.center.z} end
do
	at_stone(ann, claim); at_stone(bea, claim)
	check(grug_home.set_home_claim(ann), "H Ann sets the account claim as home")
	check(grug_home.set_home_claim(bea), "H Bea too")
	eq(grug_home.get(ann).claim, tostring(claim.id), "H Ann's home (travel, respawn)")
	eq(grug_home.get(bea).claim, tostring(claim.id), "H Bea's home")
	eq(grug_home.get(dan).claim, nil, "H Dan's home is his innkeeper (his own choice)")
	check(grug_home.claim_waypoint(dan) ~= nil, "H ...but the stone is his waypoint")
	eq(grug_home.claim_waypoint(dan).texture, H.ACCOUNT_STONE_TEXTURE, "H ...with the account look")
	-- E1 the fuel runs out: the members stay owners, no new stone
	clock = claim.paid_until + 1
	model.expiry_scan()
	check(not H.is_active(claim) and H.is_owner(claim, "Bea"), "E1 expired: Bea still owns it")
	check(not model.can_issue_account("Bea", 25, false), "E1 ...and gets no stone while it stands")
	-- E2 dug as empty
	nodes[key(claim.center)] = "grug_housing:account_stone_empty"
	loaded[key(claim.center)] = true
	heard("Ann"); heard("Bea")
	local def = core.registered_nodes["grug_housing:account_stone_empty"]
	eq(def.groups.grug_claim_stone, 1, "E2 the empty account stone digs as the personal one")
	nodes[key(claim.center)] = nil -- the engine digs the node first
	def.after_dig_node(claim.center, nil, nil, eve)
	check(model.account_claim(OWNER) == nil, "E2 dug as empty: the claim is gone")
	local a, b = heard("Ann"), heard("Bea")
	has(a, "Your Claim Stone has been destroyed.", "E2 Ann is told")
	has(b, "Your Claim Stone has been destroyed.", "E2 Bea is told")
	has(b, "Your home is now the Highcourt Innkeeper", "H the loss notice: Bea's home falls back")
	eq(grug_home.get(bea).claim, nil, "H ...to the innkeeper")
	eq(model.account_owner_of("Bea"), OWNER, "E2 Bea stays a member")
	check(H.choose_account(bea) and count_item(bea, ACC) == 1, "E2 Bea may get a stone again")
	check(H.choose_account(ann) and count_item(ann, ACC) == 1, "E2 so may Ann")
	-- E3 Ann's stone becomes the claim; Bea picks it up later
	place(ann, ACC, {x = 0, y = 10, z = 0})
	check(activate(ann), "E3 Ann activates again")
	claim = model.account_claim(OWNER)
	clock = clock + 13 * 3600
	at_stone(bea, claim)
	local ok = H.pick_up(bea)
	check(ok and count_item(bea, ACC) == 2, "E3 Bea picks it up: the stone is hers (with her leftover)")
	check(model.account_claim(OWNER) == nil, "E3 the claim is gone")
	eq(model.account_owner_of("Ann"), OWNER, "E3 Ann stays a member")
	place(bea, ACC, {x = 0, y = 10, z = 0})
	check(activate(bea), "E3 Bea places and activates it")
	claim = model.account_claim(OWNER)
	place(bea, ACC, {x = 300, y = 10, z = 0})
	eq(count_item(bea, ACC), 0, "D2 her second stone vanishes at the attempt")
end

-- U1 the unlink of a member (Dan): it leaves, its home falls back, its stone vanishes
do
	at_stone(dan, claim)
	check(grug_home.set_home_claim(dan), "U1 Dan's home is the claim")
	give(dan, ACC)
	heard("Dan")
	send({"acc_1", "acc_2"}, {Ann = {cid(1), "acc_1"}, Bea = {cid(2), "acc_1"},
		Low = {cid(7), "acc_1"}, Dan = {cid(4), "acc_2"}})
	eq(model.account_owner_of("Dan"), nil, "U1 Dan (now on another account) left")
	eq(select(2, H.player_claim("Dan")), "needs_stone", "U1 ...personal, no stone")
	eq(count_item(dan, ACC), 0, "U1 his account stone vanished")
	local line = heard("Dan")
	has(line, "no longer linked to the account of its home", "U1 he is told")
	has(line, "is no longer yours: your character is no longer linked to its account",
		"U1 his home falls back, with the unlink's own words")
	eq(grug_home.get(dan).claim, nil, "U1 ...to the innkeeper")
	check(model.account_claim(OWNER) == claim, "U1 the claim stays")
end

-- U4 a binding that stops counting without an event, found by the reconcile at load
do
	leave(bea)
	stores.grug_accounts["id:bea"] = cid(99) -- another character id in the index
	H.reconcile_all()
	eq(model.account_owner_of("Bea"), nil, "U4 the reconcile ends Bea's membership")
	check(model.account_claim(OWNER) == claim, "U4 Ann keeps the claim")
	join(bea) -- her meta id wins over the index again (grug_accounts)
	eq(model.account_owner_of("Bea"), nil, "U4 ...and she stays out")
end

-- L1 Ann is the last member: she cannot leave, she picks the stone up instead
do
	local ok, why = H.leave_account(ann)
	check(not ok and why:find("last character", 1, true), "L1 the last member cannot leave")
	has(steward(ann), "You are the last character in your account", "L1 ...the Steward says so")
end

-- U2 (ruling 18, which replaces "the claim ends" here: a list may be
-- faulty) the unlink of the last member leaves the claim standing ownerless
do
	heard("Ann")
	send({"acc_1", "acc_2"}, {Bea = {cid(2), "acc_1"}, Low = {cid(7), "acc_1"},
		Dan = {cid(4), "acc_2"}})
	eq(model.account_owner_of("Ann"), nil, "U2 Ann left with the unlink")
	has(heard("Ann"), "It stands on; a character of that account and faction can join it again " ..
		"at a Housing Steward.", "U2 ...and is told the home stands")
	check(model.account_claim(OWNER) == claim and H.is_ownerless(claim), "U2 the claim stands ownerless")
	eq(nodes[key(claim.center)], "grug_housing:account_stone", "U2 ...its stone too")
	check(H.is_active(claim) and model.protects({x = 5, y = 12, z = 5}, "Ann", function() return false end),
		"U2 it protects, against Ann as well")
	check(not H.open_stone_interface(ann, claim), "U2 nobody opens it (no refuel)")
	-- a draft placed meanwhile: the claim stands, so the stone crumbles
	check(H.choose_account(bea), "U2 Bea (linked to acc_1) joins")
	eq(count_item(bea, ACC), 0, "U2 ...joining the standing claim gives no item")
	check(H.is_owner(claim, "Bea") and not H.is_ownerless(claim), "U2 ...and owns it again")
	-- G the bad lists: empty, a malformed account row, a lower version
	local good = {Bea = {cid(2), "acc_1"}, Low = {cid(7), "acc_1"}, Dan = {cid(4), "acc_2"}}
	local function rejoin(label)
		check(model.account_claim(OWNER) == claim and H.is_ownerless(claim), label .. ": the claim stays")
		send({"acc_1", "acc_2"}, good)
		check(H.choose_account(bea) and H.is_owner(claim, "Bea"), label .. ": relinked, Bea owns it again")
	end
	send({}, {})
	eq(model.account_owner_of("Bea"), nil, "G an empty list unlinks Bea")
	rejoin("G the empty list")
	version = version + 1
	grug_accounts.apply_list({version = version, accounts = {{id = "bad id!", name = "x", rewards = {}}},
		characters = {{name = "Bea", character_id = cid(2), account_id = "bad id!"}}})
	run_timers()
	eq(model.account_owner_of("Bea"), nil, "G a malformed account row unlinks Bea")
	rejoin("G the malformed row")
	grug_accounts.apply_list({version = 1, accounts = {}, characters = {}})
	run_timers()
	eq(model.account_owner_of("Bea"), nil, "G a lower version (a restored backup) unlinks Bea")
	rejoin("G the lower version")
	-- the fuel runs out while ownerless: it is the empty stone, as any claim
	-- whose owner stopped fuelling (the coordinator's decision of 2026-11-22)
	send({"acc_1", "acc_2"}, {Low = {cid(7), "acc_1"}, Dan = {cid(4), "acc_2"}})
	check(H.is_ownerless(claim), "E ownerless again")
	clock = claim.paid_until + 1
	for _, c in ipairs(model.expiry_scan()) do
		H.sync_stone_node(c)
		H.notify_claim_changed(c, "expired")
	end
	run_timers()
	check(model.claim_by_id(claim.id) == claim and not H.is_active(claim), "E its fuel gone, the claim stays")
	eq(nodes[key(claim.center)], "grug_housing:account_stone_empty", "E ...as the empty stone")
	H.reconcile_all()
	check(model.account_claim(OWNER) == claim, "E the load's reconcile leaves the dry ownerless claim")
	-- the offline former member hears of it at its next join
	leave(bea)
	send({"acc_1", "acc_2"}, good)
	feeds = {}
	join(bea)
	local notice = table.concat(feeds, "\n")
	has(notice, "Bea: Your account's home stands without an owner. A Housing Steward lets you join it.",
		"O the offline character's notice at its join")
	-- no notice for one that cannot join: below level 20, or a placed personal stone
	feeds = {}
	leave(low)
	join(low)
	lacks(table.concat(feeds, "\n"), "stands without an owner", "O no notice below level 20")
	check(H.issue_stone(cid3), "O Cid takes a personal stone")
	send({"acc_1", "acc_2"}, {Bea = {cid(2), "acc_1"}, Low = {cid(7), "acc_1"},
		Dan = {cid(4), "acc_2"}, Cid = {cid(3), "acc_1"}})
	place(cid3, STONE, {x = 1200, y = 10, z = 0})
	feeds = {}
	leave(cid3)
	join(cid3)
	lacks(table.concat(feeds, "\n"), "stands without an owner", "O no notice with a placed personal stone")
	check(H.pick_up(cid3), "O Cid picks his stone up again")
	check(H.choose_account(bea) and H.is_owner(claim, "Bea"), "E the dry claim is still joinable")
	eq(H.add_fuel(claim, 2), 2, "E ...and its new owner refuels it")
	-- an empty claim meeting a list change stays
	clock = claim.paid_until + 1
	model.expiry_scan()
	send({"acc_1", "acc_2"}, {Low = {cid(7), "acc_1"}, Dan = {cid(4), "acc_2"}})
	check(model.claim_by_id(claim.id) == claim and H.is_ownerless(claim),
		"E an empty claim meeting a list change stays")
	-- no list held (version 0, or a stored list that did not decode): no list check
	send({"acc_1", "acc_2"}, good)
	check(H.choose_account(bea), "N Bea joins once more")
	local held = grug_accounts.held_version
	grug_accounts.held_version = function() return 0 end
	stores.grug_accounts["id:bea"] = cid(98)
	leave(bea)
	H.reconcile_all()
	eq(model.account_owner_of("Bea"), OWNER, "N without a held list the reconcile leaves members")
	grug_accounts.held_version = held
	stores.grug_accounts["id:bea"] = cid(2)
	join(bea)
	-- anyone digs the empty stone: it ends
	nodes[key(claim.center)] = nil
	core.registered_nodes["grug_housing:account_stone_empty"].after_dig_node(claim.center, nil, nil, eve)
	check(model.claim_by_id(claim.id) == nil, "E the empty stone dug: the claim ends")
	eq(model.claim_count(), 0, "E no claim record stays")
end

-- U3 the account vanishes from the list: every member goes, the claim ends
local OWNER2 = model.owner_text("acc_2", "accord")
do
	check(H.choose_account(dan), "U3 Dan chooses acc_2's stone")
	local fay = join(new_player("Fay", "accord", 30, cid(8)))
	send({"acc_1", "acc_2"}, {Bea = {cid(2), "acc_1"}, Low = {cid(7), "acc_1"},
		Dan = {cid(4), "acc_2"}, Fay = {cid(8), "acc_2"}})
	check(H.choose_account(fay), "U3 Fay too")
	place(dan, ACC, {x = 2000, y = 10, z = 0})
	check(activate(dan), "U3 Dan activates acc_2's home")
	local c2 = model.account_claim(OWNER2)
	check(c2 ~= nil and #model.members(OWNER2) == 2, "U3 two members")
	send({"acc_1"}, {Bea = {cid(2), "acc_1"}, Low = {cid(7), "acc_1"}})
	check(model.account_owner_of("Dan") == nil and model.account_owner_of("Fay") == nil,
		"U3 both left")
	-- Ruling 18: the account leaving the list leaves the claim ownerless.
	check(model.claim_by_id(c2.id) == c2 and H.is_ownerless(c2), "U3 the claim stands ownerless")
	-- the direct path: /claim_remove here (an admin standing in it) ends it at once
	local adm = join(new_player("Adm", "accord", 30, cid(13)))
	adm.pos = {x = c2.center.x + 3, y = c2.center.y + 1, z = c2.center.z}
	local ok = core.commands.claim_remove.func("Adm", "here")
	check(ok and model.claim_by_id(c2.id) == nil, "U3 /claim_remove here ends the ownerless claim at once")
	leave(adm)
end

-- U5 character.delete of a member and of the last member
do
	local gus = join(new_player("Gus", "accord", 30, cid(9)))
	local ida = join(new_player("Ida", "accord", 30, cid(10)))
	send({"acc_1", "acc_3"}, {Bea = {cid(2), "acc_1"}, Low = {cid(7), "acc_1"},
		Gus = {cid(9), "acc_3"}, Ida = {cid(10), "acc_3"}})
	local OWNER3 = model.owner_text("acc_3", "accord")
	check(H.choose_account(gus) and H.choose_account(ida), "U5 Gus and Ida choose acc_3")
	place(gus, ACC, {x = 3000, y = 10, z = 0})
	check(activate(gus), "U5 Gus activates")
	local c3 = model.account_claim(OWNER3)
	leave(ida)
	grug_core.character_delete = dofile(repo .. "/mods/CORE/grug_core/character_delete.lua")
	-- the registry's order: grug_accounts first (the binding goes), housing later
	grug_accounts.forget_character("Ida")
	H.forget_character("Ida")
	eq(model.account_owner_of("Ida"), nil, "U5 Ida's deletion ends her membership")
	eq(stores.grug_housing["player:Ida"], nil, "U5 ...and her record")
	check(model.account_claim(OWNER3) == c3, "U5 the claim stays with Gus")
	leave(gus)
	grug_accounts.forget_character("Gus")
	H.forget_character("Gus")
	check(model.claim_by_id(c3.id) == nil, "U5 the last member's deletion ends the claim")
	-- U6 an admin's faction change counts as leaving
	local hal = join(new_player("Hal", "accord", 30, cid(11)))
	local ivo = join(new_player("Ivo", "accord", 30, cid(12)))
	send({"acc_1", "acc_4"}, {Bea = {cid(2), "acc_1"}, Low = {cid(7), "acc_1"},
		Hal = {cid(11), "acc_4"}, Ivo = {cid(12), "acc_4"}})
	check(H.choose_account(hal) and H.choose_account(ivo), "U6 Hal and Ivo choose acc_4")
	heard("Hal")
	set_faction(hal, "throng")
	eq(model.account_owner_of("Hal"), nil, "U6 Hal's faction change: he left")
	has(heard("Hal"), "Your faction changed: you left your account's home.", "U6 ...and is told")
	eq(count_item(hal, ACC), 0, "U6 ...his account stone vanished")
	set_faction(hal, "accord")
	-- M the map reset: the claim goes, the members stay
	place(ivo, ACC, {x = 4000, y = 10, z = 0})
	check(activate(ivo), "M Ivo activates acc_4's home")
	local OWNER4 = model.owner_text("acc_4", "accord")
	check(H.choose_account(hal), "M Hal joins it (no item)")
	eq(count_item(hal, ACC), 0, "M ...no item")
	-- G /claim_remove <member> (here before the reset)
	local ok, text = core.commands.claim_remove.func("admin", "Hal")
	check(ok and text:find(OWNER4, 1, true), "G /claim_remove Hal removes the account claim")
	has(heard("Ivo"), "Your Claim Stone was removed by an admin", "G every member hears it")
	eq(model.account_owner_of("Ivo"), OWNER4, "G the members stay")
	check(H.choose_account(ivo), "G Ivo gets a stone again")
	place(ivo, ACC, {x = 4000, y = 10, z = 0})
	check(activate(ivo), "M ...the home stands again")
	grug_core.map_reset.fn()
	check(model.account_claim(OWNER4) == nil and model.claim_count() == 0, "M the reset clears it")
	check(model.account_owner_of("Ivo") == OWNER4 and model.account_owner_of("Hal") == OWNER4,
		"M the members stay members (ruling 14)")
	check(model.can_issue_account("Hal", 30, false), "M ...and get stones at the Steward")
end

-- F the faction change of the last member of a standing, fuelled claim
-- (an admin's direct act): the claim ends at once
do
	local kim = join(new_player("Kim", "accord", 30, cid(14)))
	send({"acc_1", "acc_4", "acc_5"}, {Bea = {cid(2), "acc_1"}, Low = {cid(7), "acc_1"},
		Hal = {cid(11), "acc_4"}, Ivo = {cid(12), "acc_4"}, Kim = {cid(14), "acc_5"}})
	check(H.choose_account(kim), "F Kim chooses acc_5")
	place(kim, ACC, {x = 5000, y = 10, z = 0})
	check(activate(kim), "F Kim activates")
	local c5 = model.account_claim(model.owner_text("acc_5", "accord"))
	check(c5 and H.is_active(c5), "F a fuelled claim, one member")
	set_faction(kim, "throng")
	check(model.claim_by_id(c5.id) == nil, "F the faction change ends it at once")
end

-- M records: 0.83.0 and 0.85.0 records decode; member records round-trip
do
	local rows = {["player:Old"] = "v2|placed|3", ["player:Gone"] = "v2|needs_stone|0",
		["claim:3"] = "v3|Old|0|10|0|1|2|3|3||| ",
		["player:Mem"] = "v2|member|account:a_1:throng", ["player:Bad"] = "v2|member|a_1"}
	local store = {get_string = function(k) return rows[k] or "" end,
		set_string = function(k, v) rows[k] = v ~= "" and v or nil end,
		keys = function() local list = {} for k in pairs(rows) do list[#list + 1] = k end return list end}
	local m = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")({storage = store,
		now = function() return clock end})
	eq(#m.load(), 0, "M every claim record loads")
	local c, state = m.player_claim("Old")
	check(c and c.id == 3 and state == "placed", "M a 0.85.0 placed record decodes")
	eq(m.player_state("Gone"), "needs_stone", "M ...a 0.83.0 one too")
	eq(m.account_owner_of("Mem"), "account:a_1:throng", "M a member record decodes")
	eq(m.player_state("Bad"), "never", "M a malformed member record does not")
	m.map_reset()
	eq(m.player_state("Old"), "needs_stone", "M the reset: placed becomes needs_stone")
	eq(rows["player:Mem"], "v2|member|account:a_1:throng", "M ...a member's record stays")
end

-- The grep proof lives in the report; here: no claim.owner comparison with
-- a name outside the owner function in the account file.
do
	local f = io.open(repo .. "/mods/PLAYER/grug_housing/account.lua")
	local text = f:read("*a")
	f:close()
	lacks(text, ".owner ==", "the account file compares no owner")
end

if #failures > 0 then
	for _, line in ipairs(failures) do print("FAIL " .. line) end
	error(("R86 STONE PORTABLE FAIL %d of %d checks"):format(#failures, checks), 0)
end
print(("R86 STONE PORTABLE PASS checks=%d"):format(checks))
