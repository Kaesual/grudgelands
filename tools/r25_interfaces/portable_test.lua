-- Round 25 Lane C portable fixture: the Claim Stone formspec, the Housing
-- Steward (Housing Manager before Round 26) and the Character-page status
-- (rulings 13-14). Round 26 (rulings 8-11): the draft form with the
-- activation button, the pick-up lock line, the draft status and the Steward
-- wording.
--
-- Loads the REAL grug_housing api.lua (claim-change callbacks, fuel items,
-- LUMP_SECONDS and FUEL_MAX, over an empty in-memory registry),
-- interface.lua, stone_form.lua and manager.lua, and the REAL grug_core
-- settlement_sockets.lua, under a minimal `core` stub. The contract functions
-- Lane A owns are replaced by fakes with an in-memory claim registry.
--
-- Usage (repo root): luajit tools/r25_interfaces/portable_test.lua

grug_sounds = {play = function() return false end, CLICK_STYLE = ""} -- Round 34 sound hooks: silent here
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
local function has(text, needle, label)
	check(type(text) == "string" and text:find(needle, 1, true) ~= nil,
		label .. " (missing " .. needle .. ")")
end
local function lacks(text, needle, label)
	check(type(text) == "string" and text:find(needle, 1, true) == nil,
		label .. " (unexpected " .. needle .. ")")
end

function string.trim(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end

--
-- Engine surface
--

local function ItemStackImpl(spec)
	local name, count = "", 0
	if type(spec) == "string" and spec ~= "" then
		local n, c = spec:match("^(%S+)%s*(%d*)$")
		name, count = n, tonumber(c) or 1
	elseif type(spec) == "table" then
		name, count = spec.name, spec.count
	end
	local s = {name = name, count = count}
	function s:get_name() return self.name end
	function s:get_count() return self.count end
	function s:is_empty() return self.count <= 0 or self.name == "" end
	return s
end
ItemStack = ItemStackImpl

local shown, closed, dropped, receive, globalsteps = {}, {}, {}, {}, {}
local joins, leaves, deaths = {}, {}, {}
local players, known = {}, {}
local detached = {}
local escapes = {["\\"] = "\\\\", ["["] = "\\[", ["]"] = "\\]", [";"] = "\\;",
	[","] = "\\,", ["$"] = "\\$"}

core = {
	formspec_escape = function(text)
		return text and string.gsub(text, "[\\%[%];,$]", escapes)
	end,
	colorize = function(color, message)
		return "\27(c@" .. color .. ")" .. message .. "\27(c@#ffffff)"
	end,
	show_formspec = function(name, formname, fs)
		shown[#shown + 1] = {name = name, formname = formname, fs = fs}
	end,
	close_formspec = function(name, formname)
		closed[#closed + 1] = {name = name, formname = formname}
	end,
	create_detached_inventory = function(invname, callbacks, player)
		local lists = {}
		local inv = {}
		function inv:set_size(list, size)
			lists[list] = {}
			for i = 1, size do lists[list][i] = ItemStack("") end
		end
		function inv:set_stack(list, index, stack) lists[list][index] = stack end
		function inv:get_stack(list, index) return lists[list][index] end
		detached[invname] = {callbacks = callbacks, inv = inv, player = player}
		return inv
	end,
	remove_detached_inventory = function(invname) detached[invname] = nil end,
	add_item = function(pos, stack) dropped[#dropped + 1] = stack end,
	register_on_player_receive_fields = function(fn) receive[#receive + 1] = fn end,
	register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
	register_on_dieplayer = function(fn) deaths[#deaths + 1] = fn end,
	get_connected_players = function()
		local list = {}
		for _, p in pairs(players) do list[#list + 1] = p end
		return list
	end,
	get_player_by_name = function(name) return players[name] end,
	player_exists = function(name) return known[name] == true end,
	explode_textlist_event = function(evt)
		local t, r = tostring(evt):match("^(%u+):(%d+)$")
		if t and t ~= "INV" then return {type = t, index = tonumber(r)} end
		return {type = "INV", index = 0}
	end,
	dir_to_yaw = function(dir) return math.atan2(-dir.x, dir.z) end,
	get_modpath = function(name)
		assert(name == "grug_housing")
		return "mods/PLAYER/grug_housing"
	end,
	-- The real api.lua builds its registry over mod storage: empty here, the
	-- contract functions are replaced by the fakes below.
	get_mod_storage = function()
		local data = {}
		return {
			get_string = function(_, k) return data[k] or "" end,
			set_string = function(_, k, v) data[k] = v ~= "" and v or nil end,
			get_keys = function()
				local keys = {}
				for k in pairs(data) do keys[#keys + 1] = k end
				return keys
			end,
		}
	end,
	log = function() end,
}
vector = {new = function(x, y, z)
	if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
	return {x = x, y = y, z = z}
end}

local function submit(player, formname, fields)
	for _, fn in ipairs(receive) do
		if fn(player, formname, fields) then return true end
	end
	return false
end
local function last_shown(name)
	for i = #shown, 1, -1 do
		if shown[i].name == name then return shown[i] end
	end
end

local function new_player(name, pos)
	local p = {name = name, pos = pos, hp = 20, given = {}, main_full = false}
	function p:get_player_name() return self.name end
	function p:is_player() return true end
	function p:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
	function p:get_hp() return self.hp end
	function p:get_inventory()
		local owner = self
		return {add_item = function(_, list, stack)
			assert(list == "main")
			if owner.main_full then return stack end
			owner.given[#owner.given + 1] = stack
			return ItemStack("")
		end}
	end
	players[name] = p
	known[name] = true
	return p
end

-- sfinv stand-in: only what the status refresh touches.
local sfinv_sets = {}
sfinv = {contexts = {}, set_player_inventory_formspec = function(player)
	sfinv_sets[#sfinv_sets + 1] = player:get_player_name()
end}

--
-- grug_core (real socket registry), grug_mobs, grug_factions stand-ins
--

grug_core = {}
-- Round 41: the platform's map reset (grug_core/map_reset.lua), idle here.
grug_core.map_reset = {clear = function() end}
dofile("mods/CORE/grug_core/settlement_sockets.lua")
local CAPITALS = {
	{key = "highcourt", race = "human", plot = "market_counting_house"},
	{key = "dur_brannoc", race = "dwarf", plot = "forge_guild_house"},
	{key = "lethariel", race = "elf", plot = "market_weaver"},
	{key = "nhal_veyr", race = "undead", plot = "market_shroud_house"},
	{key = "gor_drazhak", race = "orc", plot = "warren_weaver"},
	{key = "kezamba", race = "troll", plot = "shore_tailor"},
}
for index, capital in ipairs(CAPITALS) do
	local sid = capital.plot .. "/" .. capital.plot .. "_gate_idle"
	grug_core.register_settlement_sockets(capital.key, capital.race,
		{x = index * 1000, y = 10, z = 0}, {
			{id = sid, role = "idle", x = 5, y = 1, z = 7, dir = {x = 0, z = -1},
				tags = {"door"}},
			{id = "other_idle", role = "idle", x = 1, y = 1, z = 1, dir = {x = 1, z = 0}},
		})
end
-- The innkeeper path now delegates to the generic service assignment.
grug_core.register_settlement_sockets("dawnmere", "human", {x = 0, y = 0, z = 0},
	{{id = "home_innkeeper", role = "idle", x = 0, y = 1, z = 0, dir = {x = 1, z = 0}}})
eq(grug_core.assign_innkeeper_socket("dawnmere", "home_innkeeper").role, "innkeeper",
	"innkeeper assignment still works")
check(not pcall(grug_core.assign_service_socket, "dawnmere", "home_innkeeper",
	"housing_manager"), "a taken socket cannot be assigned twice")
check(not pcall(grug_core.assign_service_socket, "highcourt", "other_idle", "king"),
	"service roles are closed")

local resolvers = {}
grug_mobs = {register_start_socket_role = function(role, fn) resolvers[role] = fn end}
local factions = {}
grug_factions = {get_faction = function(player) return factions[player:get_player_name()] end}

--
-- grug_housing: real api.lua, fake contract
--

grug_housing = {}
dofile("mods/PLAYER/grug_housing/api.lua")
local H = grug_housing
local LUMP = H.LUMP_SECONDS
eq(LUMP, 26160, "one lump burns 7 h 16 min (api.lua)")
check(H.is_fuel("default:coal_lump") and H.is_fuel("grug_smelting:charcoal") and
	not H.is_fuel("default:coalblock"), "fuel kinds come from api.lua")
-- Round 26 review: refunds come back as charcoal (coal only without
-- grug_smelting), and activation spends charcoal before coal.
eq(H.refund_item(), "default:coal_lump", "no charcoal registered: coal refund")
core.registered_items = {["grug_smelting:charcoal"] = {}}
eq(H.refund_item(), "grug_smelting:charcoal", "refund as charcoal, the cheaper lump")
core.registered_items = nil
eq(table.concat(H.FUEL_ORDER, ","), "grug_smelting:charcoal,default:coal_lump",
	"activation takes charcoal first")
local now = 1000000
local claims, states = {}, {}
local calls = {add_fuel = {}, set_permission = {}, pick_up = {}, issue = {},
	activate = {}}
local pick_up_result = {false, "Your Claim Stone stays in place for another 5 h 00 min."}
local activate_result = {true, "Claim Stone activated: your home is protected."}
local issue_result = {true, "Here is your Claim Stone."}

function H.player_claim(name) return claims[name], states[name] or "never" end
function H.is_draft(claim) return claim.activated_at == 0 end
function H.is_active(claim)
	return claim.activated_at ~= 0 and claim.paid_until > now
end
function H.draft_remaining(claim)
	if claim.activated_at ~= 0 then return 0 end
	return math.max(0, claim.placed_at + 300 - now)
end
function H.pickup_wait(claim)
	if claim.activated_at == 0 then return 0 end
	return math.max(0, claim.activated_at + 43200 - now)
end
function H.activate(player)
	local name = player:get_player_name()
	calls.activate[#calls.activate + 1] = name
	local claim = claims[name]
	if activate_result[1] and claim then
		claim.activated_at = now
		claim.paid_until = now + 5 * LUMP
		H.notify_claim_changed(claim, "activated")
	end
	return activate_result[1], activate_result[2]
end
function H.remaining_seconds(claim) return math.max(0, claim.paid_until - now) end
function H.permission(claim, name)
	if name == claim.owner then return "owner" end
	return claim.permissions[name]
end
function H.add_fuel(claim, count)
	calls.add_fuel[#calls.add_fuel + 1] = count
	local free = 99 - math.ceil(H.remaining_seconds(claim) / LUMP)
	local accepted = math.max(0, math.min(count, free))
	if accepted > 0 then
		claim.paid_until = math.max(now, claim.paid_until) + accepted * LUMP
		H.notify_claim_changed(claim, "fuel")
	end
	return accepted
end
function H.set_permission(claim, name, level)
	calls.set_permission[#calls.set_permission + 1] = {name = name, level = level}
	claim.permissions[name] = level
	H.notify_claim_changed(claim, "permission")
	return true
end
function H.pick_up(player)
	calls.pick_up[#calls.pick_up + 1] = player:get_player_name()
	if pick_up_result[1] then
		local name = player:get_player_name()
		local claim = claims[name]
		claims[name], states[name] = nil, "carried"
		H.notify_claim_changed(claim, "picked_up")
	end
	return pick_up_result[1], pick_up_result[2]
end
function H.issue_stone(player)
	calls.issue[#calls.issue + 1] = player:get_player_name()
	return issue_result[1], issue_result[2]
end

dofile("mods/PLAYER/grug_housing/interface.lua")

--
-- 1. Housing Manager sockets: six capitals, one role resolver
--

for _, capital in ipairs(CAPITALS) do
	local found
	for _, socket in ipairs(grug_core.settlement_sockets_at(capital.key)) do
		if socket.role == "housing_manager" then found = socket end
	end
	check(found ~= nil and found.id == capital.plot .. "/" .. capital.plot .. "_gate_idle",
		capital.key .. " has its Housing Manager socket")
end
local managers = H.manager_sockets()
eq(#managers, 6, "manager_sockets lists six capitals")
check(type(resolvers.housing_manager) == "function", "housing_manager role registered")
eq(resolvers.housing_manager({}, {race_id = "orc"}), "grug_mobs:villager_orc",
	"Manager is the capital's race villager")

--
-- 2. Formatting helpers
--

local DAY = 86400
local status_of = H.character_status
eq(H.character_status_formspec("nobody", 2.75, 3.8), "", "never: nothing on the page")
check(status_of("nobody") == nil, "never: no status")

--
-- 3. Stone formspec per state
--

local owner = new_player("owner", {x = 0, y = 10, z = 0})
factions.owner = "accord"
local claim = {id = 7, owner = "owner", center = {x = 0, y = 9, z = 0},
	placed_at = now - DAY, activated_at = now - DAY,
	paid_until = now + 12 * DAY + 4 * 3600 + 31 * 60 + 59,
	permissions = {zed = "interact", bob = "everything", owner = "everything"}}
claims.owner, states.owner = claim, "placed"
known.bob, known.zed = true, true

check(H.open_stone_interface(owner, claim), "owner opens the stone form")
local fs = last_shown("owner").fs
eq(last_shown("owner").formname, "grug_housing:stone", "stone formname")
has(fs, "Fuel left: 12 d 4 h 31 min", "remaining time to the minute")
lacks(fs, "\27(c@#ff6060)Fuel left", "more than 24 h is not red")
has(fs, "list[detached:grug_housing_fuel_owner;fuel;", "detached fuel slot")
has(fs, "item_image[0.4,1.4;1,1;default:coal_lump]", "burning lumps drawn on the slot")
-- ceil((12 d 4 h 31 min 59 s) / 26160) = 41
has(fs, ";41]", "slot shows ceil(remaining / 26160) lumps")
has(fs, ";bob — Everything,zed — Interact;", "access list sorted, owner not listed")
lacks(fs, "owner —", "owner not in the access list")
has(fs, "listring[detached:grug_housing_fuel_owner;fuel]listring[current_player;main]",
	"shift-click ring")
lacks(fs, "set_home", "no Set-as-home button without grug_home.set_home_claim")
has(fs, "button[0.4,6.75;3.1,0.8;pick_up;Pick up stone]", "pick-up button")
lacks(fs, "Pick-up possible", "no lock line 24 h after activation")
lacks(fs, "activate", "no activation button on an activated stone")

-- R26 ruling 10: the 12 h lock after activation is shown.
claim.activated_at = now - 3600
H.open_stone_interface(owner, claim)
has(last_shown("owner").fs, "Pick-up possible in 11 h 0 min.", "pick-up lock line")
claim.activated_at = now - DAY

claim.paid_until = now + 23 * 3600
H.open_stone_interface(owner, claim)
has(last_shown("owner").fs, "\27(c@#ff6060)Fuel left: 23 h 0 min", "below 24 h is red")

claim.paid_until = now - 5
H.open_stone_interface(owner, claim)
fs = last_shown("owner").fs
has(fs, "No fuel: anyone can access your home right now", "empty stone says so")
lacks(fs, "item_image", "empty slot draws no lumps")

local intruder = new_player("bob", {x = 1, y = 10, z = 0})
local before = #shown
check(not H.open_stone_interface(intruder, claim), "a non-owner cannot open the form")
eq(#shown, before, "nothing shown to a non-owner")

-- Set as home appears with grug_home.set_home_claim.
local home_calls = {}
grug_home = {set_home_claim = function(player, c)
	home_calls[#home_calls + 1] = c.id
	return true, "Your Claim Stone is now your home."
end}
H.open_stone_interface(owner, claim)
has(last_shown("owner").fs, "button[3.8,6.75;3.1,0.8;set_home;Set as home]",
	"Set-as-home button with grug_home.set_home_claim")
submit(owner, "grug_housing:stone", {set_home = ""})
eq(home_calls[1], 7, "Set as home passes the claim")
has(last_shown("owner").fs, "Your Claim Stone is now your home.", "home message shown")
grug_home = nil

--
-- 4. Fuel slot: accept, refuse, partial, no take
--

claim.paid_until = now + 90 * LUMP -- 90 lumps burning, room for 9
H.open_stone_interface(owner, claim)
local d = detached["grug_housing_fuel_owner"]
check(d ~= nil and d.player == "owner", "detached inventory visible to the owner only")
local cb = d.callbacks
local function put(player, itemstring)
	local stack = ItemStack(itemstring)
	local allowed = cb.allow_put(d.inv, "fuel", 1, stack, player)
	if allowed > 0 then
		local moved = ItemStack(stack:get_name() .. " " .. allowed)
		d.inv:set_stack("fuel", 1, moved)
		cb.on_put(d.inv, "fuel", 1, moved, player)
	end
	return allowed
end
eq(cb.allow_put(d.inv, "fuel", 1, ItemStack("default:coalblock 3"), owner), 0,
	"coal blocks refused")
eq(cb.allow_put(d.inv, "fuel", 1, ItemStack("default:stone 3"), owner), 0,
	"other items refused")
eq(cb.allow_take(d.inv, "fuel", 1, ItemStack("default:coal_lump 1"), owner), 0,
	"nothing can be taken out")
eq(cb.allow_move(d.inv, "fuel", 1, "fuel", 1, 1, owner), 0, "nothing can be moved")

eq(put(owner, "default:coal_lump 5"), 5, "coal lumps accepted")
eq(calls.add_fuel[#calls.add_fuel], 5, "add_fuel called with the put count")
check(d.inv:get_stack("fuel", 1):is_empty(), "slot is emptied after a put")
eq(#owner.given, 0, "nothing returned on a full accept")
has(last_shown("owner").fs, "Added 5.", "accept message")
has(last_shown("owner").fs, ";95]", "slot shows 95 lumps after the put")

eq(put(owner, "grug_smelting:charcoal 10"), 10, "charcoal accepted")
eq(calls.add_fuel[#calls.add_fuel], 10, "add_fuel called for charcoal")
eq(#owner.given, 1, "partial accept returns the rest")
eq(owner.given[1]:get_name(), "grug_smelting:charcoal", "rest is the same item")
eq(owner.given[1]:get_count(), 6, "rest is the not-accepted count (10 - 4)")
has(last_shown("owner").fs, "Added 4\\, 6 returned", "partial message")

owner.main_full = true
eq(put(owner, "default:coal_lump 3"), 3, "a put onto a full stone is still taken")
eq(#dropped, 1, "full inventory: the refused lumps drop at the player")
eq(dropped[1]:get_count(), 3, "all three refused lumps dropped")
has(last_shown("owner").fs, "\27(c@#ff6060)The fuel slot is full (99 lumps).",
	"refusal message in red")
owner.main_full = false

-- Out of reach: the form no longer acts.
owner.pos = {x = 40, y = 10, z = 0}
eq(cb.allow_put(d.inv, "fuel", 1, ItemStack("default:coal_lump 1"), owner), 0,
	"no fuel from out of reach")
owner.pos = {x = 0, y = 10, z = 0}

--
-- 5. Access list through on_receive_fields
--

H.open_stone_interface(owner, claim)
local n = #calls.set_permission
check(submit(owner, "grug_housing:stone", {perm_name = "ghost", perm_interact = ""}),
	"stone fields handled")
eq(#calls.set_permission, n, "unknown player not added")
has(last_shown("owner").fs, "There is no player called ghost.", "unknown-name message")

submit(owner, "grug_housing:stone", {perm_name = "owner", perm_everything = ""})
eq(#calls.set_permission, n, "owner cannot be added")
has(last_shown("owner").fs, "You own this claim.", "owner message")

known.carol = true
submit(owner, "grug_housing:stone", {perm_name = " carol ", perm_interact = ""})
eq(calls.set_permission[#calls.set_permission].name, "carol", "carol added (trimmed)")
eq(calls.set_permission[#calls.set_permission].level, "interact", "with Interact")
has(last_shown("owner").fs, "carol — Interact", "carol listed")

-- Select carol (row 2 of bob, carol, zed) and change her to Everything with an
-- empty name field: the selected row is the target.
submit(owner, "grug_housing:stone", {perm_list = "CHG:2", perm_name = ""})
has(last_shown("owner").fs, "field[6.1,3.6;4.25,0.7;perm_name;Player name;carol]",
	"selecting a row fills the name")
submit(owner, "grug_housing:stone", {perm_name = "", perm_everything = ""})
eq(calls.set_permission[#calls.set_permission].name, "carol", "change targets the selection")
eq(calls.set_permission[#calls.set_permission].level, "everything", "changed to Everything")
has(last_shown("owner").fs, "carol — Everything", "change shown")

n = #calls.set_permission
submit(owner, "grug_housing:stone", {perm_name = "carol", perm_everything = ""})
eq(#calls.set_permission, n, "same level is not set again")

submit(owner, "grug_housing:stone", {perm_name = "carol", perm_remove = ""})
eq(calls.set_permission[#calls.set_permission].name, "carol", "carol removed")
check(calls.set_permission[#calls.set_permission].level == nil, "remove passes nil")
lacks(last_shown("owner").fs, "carol —", "carol no longer listed")

n = #calls.set_permission
submit(owner, "grug_housing:stone", {perm_name = "carol", perm_remove = ""})
eq(#calls.set_permission, n, "removing a player without access does nothing")
has(last_shown("owner").fs, "carol has no access.", "no-access message")

-- Enter in the name field neither closes nor acts.
before = #shown
submit(owner, "grug_housing:stone", {perm_name = "x", key_enter_field = "perm_name"})
eq(#shown, before, "Enter in the name field does nothing")

--
-- 6. Claim changes refresh an open form
--

before = #shown
claim.paid_until = claim.paid_until + LUMP
H.notify_claim_changed(claim, "fuel")
eq(#shown, before + 1, "a fuel change redraws the open form")

--
-- 7. Pick up with confirmation
--

submit(owner, "grug_housing:stone", {pick_up = ""})
has(last_shown("owner").fs, "Pick up your Claim Stone?", "confirmation shown")
submit(owner, "grug_housing:stone", {cancel_pick_up = ""})
has(last_shown("owner").fs, "Your Claim Stone", "cancel returns to the form")
eq(#calls.pick_up, 0, "cancel does not pick up")

submit(owner, "grug_housing:stone", {pick_up = ""})
submit(owner, "grug_housing:stone", {confirm_pick_up = ""})
eq(#calls.pick_up, 1, "confirm calls pick_up")
has(last_shown("owner").fs,
	"\27(c@#ff6060)Your Claim Stone stays in place for another 5 h 00 min.",
	"pick-up lock message shown in red")

pick_up_result = {true, "You picked up your Claim Stone and 60 lumps."}
local closed_before = #closed
submit(owner, "grug_housing:stone", {pick_up = ""})
submit(owner, "grug_housing:stone", {confirm_pick_up = ""})
eq(last_shown("owner").formname, "grug_housing:notice", "success shows a notice")
has(last_shown("owner").fs, "You picked up your Claim Stone and 60 lumps.",
	"pick-up message shown")
eq(#closed, closed_before, "the acting player's form is replaced, not closed twice")
check(submit(owner, "grug_housing:notice", {ok = "", quit = "true"}), "notice handled")
before = #shown
submit(owner, "grug_housing:stone", {perm_name = "bob", perm_interact = ""})
eq(#shown, before, "a stale form does nothing after the pick-up")

-- Another claim change closes an open form.
claims.owner, states.owner = claim, "placed"
H.open_stone_interface(owner, claim)
closed_before = #closed
H.notify_claim_changed(claim, "destroyed")
eq(#closed, closed_before + 1, "destruction closes the open form")

--
-- 7b. R26 rulings 8-10: the draft form and activation
--

local draft = {id = 8, owner = "owner", center = {x = 0, y = 9, z = 0},
	placed_at = now - 60, activated_at = 0, paid_until = now - 60, permissions = {}}
claims.owner, states.owner = draft, "placed"
grug_home = {set_home_claim = function() return true end}
check(H.open_stone_interface(owner, draft), "owner opens the draft form")
fs = last_shown("owner").fs
has(fs, "Your Claim Stone (draft\\, not active)", "draft title")
has(fs, "crumbles in 4 min 00 s unless you activate it.", "draft countdown to the second")
has(fs, "button[0.4,2.3;4.2,0.7;activate;Activate (5 coal)]", "activation button")
lacks(fs, "field[", "draft form: no text field (the redraw keeps nothing typed)")
lacks(fs, "list[current_player", "draft form: no inventory list")
lacks(fs, "perm_list", "draft form: no access list")
lacks(fs, "list[detached:grug_housing_fuel_owner", "no fuel slot on a draft")
lacks(fs, "listring[detached:", "no fuel listring on a draft")
lacks(fs, "set_home", "a draft is no home: no Set-as-home button")
has(fs, "pick_up;Pick up stone", "a draft can be picked up")
d = detached["grug_housing_fuel_owner"]
eq(d.callbacks.allow_put(d.inv, "fuel", 1, ItemStack("default:coal_lump 5"), owner), 0,
	"a draft takes no fuel through the slot")
submit(owner, "grug_housing:stone", {pick_up = ""})
has(last_shown("owner").fs, "It is not active yet\\; you can place it again at once.",
	"draft pick-up confirmation")
submit(owner, "grug_housing:stone", {cancel_pick_up = ""})
activate_result = {false, "Activation needs 5 coal lumps or charcoal in your inventory; you have 2."}
submit(owner, "grug_housing:stone", {activate = ""})
eq(calls.activate[#calls.activate], "owner", "the button calls activate")
has(last_shown("owner").fs, "\27(c@#ff6060)Activation needs 5 coal lumps", "refusal in red")
has(last_shown("owner").fs, "activate;Activate", "still a draft after a refusal")
activate_result = {true, "Claim Stone activated: your home is protected."}
submit(owner, "grug_housing:stone", {activate = ""})
fs = last_shown("owner").fs
has(fs, "Claim Stone activated: your home is protected.", "activation message")
has(fs, "list[detached:grug_housing_fuel_owner;fuel;", "activated: the fuel slot appears")
has(fs, "Fuel left: 1 d 12 h 20 min", "activated with 5 lumps")
has(fs, "Pick-up possible in 12 h 0 min.", "activated: the 12 h lock starts")
has(fs, "set_home;Set as home", "activated: Set as home")
lacks(fs, "activate;", "activated: no activation button")
grug_home = nil
-- The countdown redraws itself once a second while the draft form is open,
-- only for that player, and stops with the form.
do
	local tick = globalsteps[2] -- stone_form.lua's draft tick
	draft.activated_at, draft.paid_until, draft.placed_at = 0, now - 60, now - 60
	H.open_stone_interface(owner, draft)
	local count = #shown
	tick(0.5)
	eq(#shown, count, "no redraw before a second has passed")
	now = now + 1
	tick(0.5)
	eq(#shown, count + 1, "the open draft form is redrawn after a second")
	has(last_shown("owner").fs, "crumbles in 3 min 59 s", "the countdown moved on")
	eq(last_shown("owner").name, "owner", "only the owner's form")
	submit(owner, "grug_housing:stone", {pick_up = ""})
	count = #shown
	now = now + 1
	tick(1)
	eq(#shown, count, "no redraw while the pick-up confirmation is open")
	submit(owner, "grug_housing:stone", {cancel_pick_up = ""})
	submit(owner, "grug_housing:stone", {quit = "true"})
	count = #shown
	tick(1)
	eq(#shown, count, "closing the form stops the countdown")
	-- Another mod's form shown on top (no quit for ours): no redraw over it.
	H.open_stone_interface(owner, draft)
	core.show_formspec("owner", "othermod:dialog", "size[2,2]")
	count = #shown
	now = now + 1
	tick(1)
	eq(#shown, count, "a form shown by another mod is not covered by the countdown")
	H.open_stone_interface(owner, draft)
	submit(owner, "othermod:dialog", {ok = ""})
	count = #shown
	now = now + 1
	tick(1)
	eq(#shown, count, "fields from another form end the countdown too")
	now = now - 2
	H.open_stone_interface(owner, claim)
	count = #shown
	tick(1)
	eq(#shown, count, "an activated stone's form is not redrawn")
	submit(owner, "grug_housing:stone", {quit = "true"})
	now = now - 2
	claims.owner = draft
end

-- An expired draft closes the open form.
draft.activated_at, draft.paid_until = 0, now - 60
H.open_stone_interface(owner, draft)
closed_before = #closed
H.notify_claim_changed(draft, "draft_expired")
eq(#closed, closed_before + 1, "an expired draft closes the open form")
H.open_stone_interface(owner, draft)
closed_before = #closed
H.notify_claim_changed(draft, "removed")
eq(#closed, closed_before + 1, "an admin removal closes the open form")
claims.owner, states.owner = claim, "placed"

--
-- 8. Housing Steward dialog
--

local npc_pos = {x = 1000 + 5, y = 11, z = 7} -- highcourt socket
local manager = {_grug_socket_role = "housing_manager", _grug_start = "highcourt",
	_grug_socket = "market_counting_house/market_counting_house_gate_idle",
	object = {get_pos = function() return npc_pos end}}
local visitor = new_player("visitor", {x = 1003, y = 11, z = 7})
factions.visitor = "accord"
check(H.open_manager(visitor, manager), "Steward opens for the own faction")
fs = last_shown("visitor").fs
eq(last_shown("visitor").formname, "grug_housing:manager", "manager formname")
has(fs, "From level 20 you get one Claim Stone for free.", "level-20 line")
has(fs, "99 lumps last about 30 days.", "upkeep line")
has(fs, "coal lumps or charcoal", "fuel kinds line")
has(fs, "When the fuel runs out\\, the protection ends.", "empty-fuel line")
has(fs, "label[0.4,0.5;Housing Steward]", "Steward title")
lacks(fs, "Manager", "no Manager wording")
lacks(fs, "24 hours", "no daily rule any more")
has(fs, "Activate it within 5 minutes with 5 coal lumps or charcoal", "activation line")
has(fs, "stays in place for 12 hours", "pick-up lock line")
has(fs, "button[0.4,5.5;5.2,0.8;receive;Receive Claim Stone]", "receive button")

submit(visitor, "grug_housing:manager", {receive = ""})
eq(calls.issue[1], "visitor", "receive calls issue_stone")
has(last_shown("visitor").fs, "\27(c@#8fdc7a)Here is your Claim Stone.", "issue ok in green")
issue_result = {false, "You need level 20 for a Claim Stone."}
submit(visitor, "grug_housing:manager", {receive = ""})
has(last_shown("visitor").fs, "\27(c@#ff6060)You need level 20 for a Claim Stone.",
	"issue refusal in red")

factions.visitor = "throng"
check(not H.open_manager(visitor, manager), "other faction refused")
factions.visitor = "accord"
visitor.pos = {x = 1020, y = 11, z = 7}
check(not H.open_manager(visitor, manager), "out of talking range refused")
visitor.pos = {x = 1003, y = 11, z = 7}
npc_pos = {x = 1015, y = 11, z = 7}
visitor.pos = {x = 1013, y = 11, z = 7}
check(not H.open_manager(visitor, manager), "a Manager away from its socket refused")
npc_pos = {x = 1005, y = 11, z = 7}
visitor.pos = {x = 1003, y = 11, z = 7}
check(not H.open_manager(visitor, {_grug_socket_role = "innkeeper",
	_grug_start = "highcourt", object = manager.object}), "other roles refused")

--
-- 9. Character-page status per state
--

local RED = "\27(c@#ff6060)"
local function status_fs(name) return H.character_status_formspec(name, 2.75, 3.8) end

states.owner, claims.owner = "carried", nil
eq(status_of("owner").text, "Your Claim Stone is in your inventory, not placed yet",
	"carried wording")
lacks(status_fs("owner"), RED, "carried is not red")

states.owner = "needs_stone"
eq(status_of("owner").text, "You have no Claim Stone; ask a Housing Steward for a new one",
	"needs_stone wording")

states.owner, claims.owner = "placed", draft
draft.placed_at = now - 90
eq(status_of("owner").text,
	"Your Claim Stone is not active yet: activate it within 3 min or it crumbles",
	"draft wording")
has(status_fs("owner"), RED, "draft status in red")
states.owner, claims.owner = "needs_stone", nil

states.owner = "destroyed"
eq(status_of("owner").text, "Your Claim Stone has been destroyed", "destroyed wording")
has(status_fs("owner"), RED .. "Your Claim Stone has been destroyed", "destroyed in red")

states.owner = "removed"
eq(status_of("owner").text, "Your Claim Stone was removed by an admin",
	"R26: admin removal wording")
has(status_fs("owner"), RED .. "Your Claim Stone was removed by", "removed in red")

states.owner, claims.owner = "placed", claim
claim.paid_until = now + 3 * DAY + 5 * 3600 + 7 * 60
eq(status_of("owner").text, "Claim Stone fuel: 3 d 5 h 7 min", "remaining wording")
lacks(status_fs("owner"), RED, "3 days is not red")
claim.paid_until = now + 59
eq(status_of("owner").text, "Claim Stone fuel: < 1 min", "last minute wording")
has(status_fs("owner"), RED, "below 24 h is red")
claim.paid_until = now
eq(status_of("owner").text,
	"Your Claim Stone needs fuel, anyone can access your home right now",
	"empty fuel wording (ruling 14)")
local page = status_fs("owner")
local RESET = "\27(c@#ffffff)"
has(page, "label[2.75,3.80;" .. RED .. "Your Claim Stone needs fuel\\, anyone" .. RESET .. "]",
	"first wrapped line")
has(page, "label[2.75,4.25;" .. RED .. "can access your home right now" .. RESET .. "]",
	"second wrapped line")

--
-- 10. The cached Character page follows status changes
--

sfinv.contexts.owner = {page = "grug_inventory:character"}
for _, fn in ipairs(joins) do fn(owner) end
local step = globalsteps[1] -- the Character-page poll (interface.lua)
local sets = #sfinv_sets
step(10)
eq(#sfinv_sets, sets, "unchanged status does not rebuild the page")
claim.paid_until = now + 2 * DAY
step(10)
eq(#sfinv_sets, sets + 1, "changed status rebuilds the cached page")
step(10)
eq(#sfinv_sets, sets + 1, "only once per change")
sfinv.contexts.owner = {page = "grug_inventory:bags"}
claim.paid_until = now + 3 * DAY
step(10)
eq(#sfinv_sets, sets + 1, "other pages are not rebuilt")
sfinv.contexts.owner = {page = "grug_inventory:character"}
claim.paid_until = now + 4 * DAY
H.notify_claim_changed(claim, "fuel")
eq(#sfinv_sets, sets + 2, "a claim event refreshes the owner's page at once")

-- Leave cleans the detached inventory.
for _, fn in ipairs(leaves) do fn(owner) end
check(detached["grug_housing_fuel_owner"] == nil, "leave removes the detached inventory")

print(("r25 interfaces fixture: %s (%d checks, %d failures)"):format(
	failures == 0 and "PASS" or "FAIL", checks, failures))
if failures > 0 then error("r25 interfaces fixture failed", 0) end
