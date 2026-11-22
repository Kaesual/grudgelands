-- Round 86 lane PACK portable test (docs/planning/round86-plan.md §4 PACK,
-- §3.1; concept ruling 7, plan ruling 13): an account claim's belongings.
-- Loads the REAL grug_housing packed.lua and recovered.lua over an in-memory
-- mod storage and a small engine stub; lane STONE's membership is faked
-- (grug_housing.account_owner_of, the owner text `account:<id>:<faction>`).
--   A. the key forms: a player's, an account's, and names that look like
--      either (a character called "account", one called like the account id);
--   B. the first start's clean-up of one pass with both key forms side by
--      side: D6's extra chests, the stacked empties and the content keys per
--      holder, nothing crossing over; a rerun changes nothing;
--   C. every member sees the account's entries, a non-member its own, a
--      member of the other faction none of them;
--   D. the join move: entries still in the stone move with their contents,
--      keep their pass, take the next free numbers; an item taken out before
--      stays the character's and still holds its contents; a second move, a
--      join without entries and a bad owner text move nothing;
--   E. leaving: one way, nothing comes back; the claim ending and a new one
--      change nothing (the entries hang on the account, not on a claim);
--   F. two members taking the same entry: no duplicate, no loss;
--   G. the deletion of a member, of a character named "account" and of one
--      named like the account id: the account's entries stay;
--   H. the join hook (a member's own entries, e.g. its account stone's draft
--      packed under its name, move at its login) and the notices;
--   I. fix round 1: a member carries the account's highest-numbered packed
--      chest (its entry gone, its contents waiting under its content key); a
--      join adds a packed chest of the same pass: it takes the next number
--      whose content key is free too, and each chest unpacks once with its
--      own contents.
-- The Belongings tab with two members' views: tools/r50_pgame section G.
--
--   luajit tools/r86_pack/portable_test.lua [REPO]

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

------------------------------------------------------------------------------
-- Serialization (sorted keys) and item stacks with meta (as tools/r50_pgame).
------------------------------------------------------------------------------
local function ser(value)
	local kind = type(value)
	if kind == "string" then return ("%q"):format(value) end
	if kind == "number" or kind == "boolean" then return tostring(value) end
	if kind ~= "table" then return "nil" end
	local keys = {}
	for key in pairs(value) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b)
		if type(a) ~= type(b) then return type(a) < type(b) end
		return a < b
	end)
	local parts = {}
	for _, key in ipairs(keys) do parts[#parts + 1] = "[" .. ser(key) .. "]=" .. ser(value[key]) end
	return "{" .. table.concat(parts, ",") .. "}"
end
local function deser(text)
	local fn = loadstring("return " .. text)
	if not fn then return nil end
	setfenv(fn, {})
	local ok, value = pcall(fn)
	return ok and value or nil
end

local Stack = {}
Stack.__index = Stack
local function new_meta()
	local meta = {fields = {}}
	function meta:get_string(key) return self.fields[key] or "" end
	function meta:set_string(key, value)
		self.fields[key] = (value ~= nil and value ~= "") and tostring(value) or nil
	end
	return meta
end
function ItemStack(value)
	local s = setmetatable({name = "", count = 0, meta = new_meta()}, Stack)
	if getmetatable(value) == Stack then
		s.name, s.count = value.name, value.count
		for key, v in pairs(value.meta.fields) do s.meta.fields[key] = v end
	elseif type(value) == "string" and value ~= "" then
		local name, rest = value:match("^(%S+)%s*(.*)$")
		local count, _, meta = rest:match("^(%d+)%s*(%d*)%s*(.*)$")
		s.name, s.count = name, tonumber(count) or 1
		local fields = meta and meta ~= "" and deser(meta) or nil
		if fields then s.meta.fields = fields end
	end
	if s.count <= 0 then s.name, s.count = "", 0 end
	return s
end
function Stack:is_empty() return self.name == "" or self.count <= 0 end
function Stack:get_name() return self:is_empty() and "" or self.name end
function Stack:get_count() return self.count end
function Stack:set_count(n)
	self.count = n
	if n <= 0 then self.name, self.count = "", 0 end
end
function Stack:get_meta() return self.meta end
function Stack:get_stack_max()
	local def = core.registered_items[self.name]
	return def and def.stack_max or 99
end
function Stack:get_short_description()
	local def = core.registered_items[self.name]
	return def and def.description or self.name
end
function Stack:to_string()
	if self:is_empty() then return "" end
	if next(self.meta.fields) then
		return self.name .. " " .. self.count .. " 0 " .. ser(self.meta.fields)
	end
	return self.count == 1 and self.name or self.name .. " " .. self.count
end
function Stack:take_item(n)
	n = math.min(n or 1, self.count)
	local taken = ItemStack(self)
	taken.count = n
	self:set_count(self.count - n)
	if taken.count <= 0 then return ItemStack("") end
	return taken
end

------------------------------------------------------------------------------
-- Engine surface and the code under test.
------------------------------------------------------------------------------
local data = {}
local storage = {
	get_string = function(_, key) return data[key] or "" end,
	set_string = function(_, key, value) data[key] = value ~= "" and value or nil end,
	get_keys = function()
		local keys = {}
		for key in pairs(data) do keys[#keys + 1] = key end
		return keys
	end,
}
local function snapshot()
	local keys, out = {}, {}
	for key in pairs(data) do keys[#keys + 1] = key end
	table.sort(keys)
	for _, key in ipairs(keys) do out[#out + 1] = key .. "=" .. data[key] end
	return table.concat(out, "\n")
end
local joins, afters, feeds, logs, players = {}, {}, {}, {}, {}
core = {
	registered_items = {}, registered_nodes = {}, registered_aliases = {},
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_craftitem = function(name, def) core.registered_items[name] = def end,
	after = function(_, fn) afters[#afters + 1] = fn end,
	get_player_by_name = function(name) return players[name] end,
	log = function(level, text) logs[#logs + 1] = level .. ": " .. text end,
	serialize = function(value) return "return " .. ser(value) end,
	deserialize = function(text)
		if type(text) ~= "string" then return nil end
		return deser((text:gsub("^return%s*", "")))
	end,
	colorize = function(color, text) return "(c@" .. color .. ")" .. text end,
}
local function item(name, def)
	def.description = def.description or name
	core.registered_items[name] = def
end
local function node(name, def)
	item(name, def)
	core.registered_nodes[name] = def
end
item("default:apple", {description = "Apple"})
item("grug_smelting:charcoal", {description = "Charcoal"})
node("default:chest", {description = "Chest", tiles = {"chest_top.png", "chest_top.png",
	"chest_side.png", "chest_side.png", "chest_side.png", "chest_front.png"}})

local pack_handlers = {}
grug_core = {
	world_version = {register_pack_handler = function(fn) pack_handlers[#pack_handlers + 1] = fn end},
	feed = function(player, kind, text) feeds[#feeds + 1] = player:get_player_name() .. ": " .. text end,
	flash = function() end,
}
local members = {}
grug_housing = {storage = storage,
	account_owner_of = function(name) return members[name] end}
dofile(ROOT .. "/mods/PLAYER/grug_housing/packed.lua")
dofile(ROOT .. "/mods/PLAYER/grug_housing/recovered.lua")
local P, R = grug_housing.packed, grug_housing.recovered
eq(#pack_handlers, 1, "the clean-up registers as the pack handler")
local function player(name)
	local p = {get_player_name = function() return name end}
	players[name] = p
	return p
end
local function join(name)
	for _, fn in ipairs(joins) do fn(player(name)) end
	for _, fn in ipairs(afters) do fn() end
	afters = {}
end

local ACC = "account:a_1842:accord"
local OTHER_FACTION = "account:a_1842:throng"

-- What the tool writes (pack.py): `lists` in the item, the owner verbatim.
local function packed_string(lists, seq)
	local stack = ItemStack(P.ITEM)
	stack.meta.fields = {node = "default:chest", lists = "return " .. ser(lists), seq = tostring(seq)}
	return stack:to_string()
end
local function apples(count)
	local main = {}
	for i = 1, count do main[i] = "default:apple " .. i end
	return main
end
-- Every item a holder's entries hold, packed contents included, as sorted
-- "name count" lines (what nothing may lose or duplicate).
local function items_of(keys)
	local out = {}
	for _, key in ipairs(keys) do
		local stack = ItemStack(data[key] or "")
		if stack:get_name() == P.ITEM then
			local lists = P.contents(stack) or P.lists(stack)
			for _, s in ipairs(P.stacks(lists)) do out[#out + 1] = s:to_string() end
		elseif not stack:is_empty() then
			out[#out + 1] = stack:to_string()
		end
	end
	table.sort(out)
	return table.concat(out, ",")
end
local function keys_of(holder)
	local keys = {}
	for _, entry in ipairs(R.entries(holder)) do keys[#keys + 1] = entry.key end
	return keys
end
local function holder_keys(holder)
	local keys = {}
	for key in pairs(data) do
		if R.parse_key(key) == holder then keys[#keys + 1] = key end
	end
	table.sort(keys)
	return keys
end

------------------------------------------------------------------------------
-- A. The key forms.
------------------------------------------------------------------------------
do
	local function parsed(key)
		local holder, seq, n, k = R.parse_key(key)
		return tostring(holder) .. "|" .. tostring(seq) .. "|" .. tostring(n) .. "|" .. tostring(k)
	end
	eq(parsed("recovered:ann:3:2"), "ann|3|2|0", "A a player's key")
	eq(parsed("recovered:ann:3:2.4"), "ann|3|2|4", "A ...with its part")
	eq(parsed("recovered:" .. ACC .. ":3:2"), ACC .. "|3|2|0", "A an account's key")
	eq(parsed("recovered:" .. ACC .. ":3:0.1"), ACC .. "|3|0|1", "A ...its stacked empties")
	eq(parsed("recovered:account:3:2"), "account|3|2|0", "A a character called account")
	eq(parsed("recovered:a_1842:3:2"), "a_1842|3|2|0", "A a character called like the account id")
	eq(parsed("recovered:account:1842:3:2"), "nil|nil|nil|nil",
		"A an owner text without its faction is no key")
	eq(parsed("recovered:account:a:b:c:3:2"), "nil|nil|nil|nil", "A ...nor one with an extra field")
	eq(R.parse_key("packed:" .. ACC .. ":3:2"), nil, "A a content key is no entry key")
	eq(P.content_key("recovered:" .. ACC .. ":3:2.1"), "packed:" .. ACC .. ":3:2.1",
		"A the account's content key")
	check(R.is_account(ACC) and R.is_account(OTHER_FACTION), "A owner texts")
	check(not R.is_account("account") and not R.is_account("a_1842") and
		not R.is_account("account:a_1842") and not R.is_account(nil), "A ...names are none")
end

------------------------------------------------------------------------------
-- B. The clean-up of pass 3 with both forms; pass 2 cleaned before.
------------------------------------------------------------------------------
local SEED = {
	-- The account claim's containers (and a 40-stack chest: one extra chest).
	["recovered:" .. ACC .. ":3:1"] = packed_string({main = apples(5)}, 3),
	["recovered:" .. ACC .. ":3:2"] = packed_string({main = {""}}, 3),
	["recovered:" .. ACC .. ":3:3"] = packed_string({main = apples(40)}, 3),
	["recovered:" .. ACC .. ":3:4"] = packed_string({main = {}}, 3),
	["recovered:" .. ACC .. ":3:5"] = "grug_smelting:charcoal 150",
	-- A character called "account" and one called like the account id.
	["recovered:account:3:1"] = packed_string({main = apples(2)}, 3),
	["recovered:account:3:2"] = packed_string({main = {""}}, 3),
	["recovered:a_1842:3:1"] = packed_string({main = apples(3)}, 3),
	-- carl, who joins the account later: two passes, a part and the empties.
	["recovered:carl:3:1"] = packed_string({main = apples(4)}, 3),
	["recovered:carl:3:2"] = packed_string({main = apples(34)}, 3),
	["recovered:carl:3:3"] = packed_string({main = {""}}, 3),
	["recovered:carl:3:4"] = "grug_smelting:charcoal 120",
	["recovered:carl:3:5"] = packed_string({main = apples(6)}, 3),
	["recovered:carl:2:1"] = "grug_smelting:charcoal 7",
	-- erin's account stone draft (its placer's), fred's personal claim.
	["recovered:erin:3:1"] = "grug_smelting:charcoal 5",
	["recovered:fred:3:1"] = "grug_smelting:charcoal 5",
	-- hank joins after a member took the account's highest entry out (I).
	["recovered:hank:3:1"] = packed_string({main = apples(7)}, 3),
	pack_seq = "3",
}
for key, value in pairs(SEED) do data[key] = value end
local stats = pack_handlers[1](3)
do
	eq(stats.entries, 16, "B every tool entry of the pass, both forms")
	local function ref_of(key) return ItemStack(data[key]):get_meta():get_string("ref") end
	eq(ref_of("recovered:" .. ACC .. ":3:1"), "packed:" .. ACC .. ":3:1",
		"B an account's packed chest refers to the account's content key")
	check(data["packed:" .. ACC .. ":3:1"] ~= nil, "B ...which holds its contents")
	eq(ref_of("recovered:" .. ACC .. ":3:3.1"), "packed:" .. ACC .. ":3:3.1",
		"B the account's extra chest (D6) under <n>.<k>")
	eq(data["recovered:" .. ACC .. ":3:0.1"], "default:chest 2",
		"B the account's two empties stacked under 0.1")
	eq(data["recovered:" .. ACC .. ":3:2"], nil, "B ...the empties' entries gone")
	eq(data["recovered:" .. ACC .. ":3:5.1"], "grug_smelting:charcoal 51", "B the charcoal split")
	eq(data["recovered:account:3:0.1"], "default:chest",
		"B the character called account: its own empty, not stacked with the account's")
	eq(ref_of("recovered:account:3:1"), "packed:account:3:1", "B ...its own content key")
	eq(ref_of("recovered:a_1842:3:1"), "packed:a_1842:3:1", "B the a_1842 character's own")
	eq(items_of(keys_of(ACC)), items_of({"recovered:" .. ACC .. ":3:1", "recovered:" .. ACC .. ":3:3",
		"recovered:" .. ACC .. ":3:3.1", "recovered:" .. ACC .. ":3:5", "recovered:" .. ACC .. ":3:5.1",
		"recovered:" .. ACC .. ":3:0.1"}), "B the account's entries are exactly its own")
	eq(#keys_of(ACC), 6, "B six account entries")
	eq(#keys_of("account"), 2, "B two of the character called account")
	local before = snapshot()
	pack_handlers[1](3)
	eq(snapshot(), before, "B a rerun changes nothing")
end

------------------------------------------------------------------------------
-- C. Who sees what.
------------------------------------------------------------------------------
members.ann, members.bob, members.tess = ACC, ACC, OTHER_FACTION
do
	eq(R.holder("ann"), ACC, "C a member's holder is the account")
	eq(R.count("ann"), 6, "C ann sees the account's six")
	eq(table.concat(keys_of("bob"), ","), table.concat(keys_of("ann"), ","),
		"C bob sees the same entries in the same order")
	eq(R.holder("a_1842"), "a_1842", "C a character called like the account id holds its own")
	eq(R.count("a_1842"), 1, "C ...and sees only its own")
	eq(R.count("account"), 2, "C the character called account sees only its own")
	eq(R.count("tess"), 0, "C a member of the account's other faction sees none of them")
	eq(R.count("carl"), 8, "C carl, no member, sees his own")
	members.mallory = "a_1842" -- a broken membership: never an owner text
	eq(R.holder("mallory"), "mallory", "C a membership that is no owner text counts as none")
	members.mallory = nil
end

------------------------------------------------------------------------------
-- D. carl joins the account.
------------------------------------------------------------------------------
do
	-- Before joining carl takes his first packed chest out.
	local carried = R.take("recovered:carl:3:1", 1)
	eq(carried:get_meta():get_string("ref"), "packed:carl:3:1", "D carl carries a packed chest")
	local own_before = items_of(keys_of("carl"))
	local acc_before = items_of(keys_of(ACC))
	local moving = R.count("carl")
	local contents = {}
	for _, key in ipairs(keys_of("carl")) do
		local ref = ItemStack(data[key]):get_meta():get_string("ref")
		if ref ~= "" then contents[key] = data[ref] end
	end
	members.carl = ACC
	eq(R.move_to_account("carl", ACC), moving, "D every entry still in the stone moves")
	eq(#holder_keys("carl"), 0, "D carl holds no entry of his own")
	local stray = 0
	for key in pairs(data) do
		if key:find("^packed:carl:") and key ~= "packed:carl:3:1" then stray = stray + 1 end
	end
	eq(stray, 0, "D ...nor the contents of a moved one")
	check(data["packed:carl:3:1"] ~= nil, "D the carried chest's contents stay where its item refers")
	check(P.contents(carried) ~= nil and #P.stacks(P.contents(carried)) == 4,
		"D ...so it still unpacks with its four stacks")
	local acc_after = items_of(keys_of(ACC))
	local expected = {}
	for part in (acc_before .. "," .. own_before):gmatch("[^,]+") do expected[#expected + 1] = part end
	table.sort(expected)
	eq(acc_after, table.concat(expected, ","), "D the account holds exactly its own and carl's")
	eq(#keys_of(ACC), 6 + moving, "D ...one entry per moved one")
	-- Pass 3's entries continue after the account's highest number (5), pass 2 keeps its pass.
	check(data["recovered:" .. ACC .. ":2:1"] == "grug_smelting:charcoal 7",
		"D carl's pass-2 charcoal is the account's pass-2 entry 1")
	for n = 6, 5 + moving - 1 do
		check(data["recovered:" .. ACC .. ":3:" .. n] ~= nil, "D pass-3 entry " .. n .. " of the account")
	end
	eq(data["recovered:" .. ACC .. ":3:" .. (5 + moving)], nil, "D ...and no more")
	-- Each moved packed item refers to its new key's contents, which are the old ones.
	local refs_ok, moved = true, {}
	for _, key in ipairs(keys_of(ACC)) do
		local stack = ItemStack(data[key])
		local _, seq, n = R.parse_key(key)
		if stack:get_name() == P.ITEM and seq == 3 and n >= 6 then
			local ref = stack:get_meta():get_string("ref")
			refs_ok = refs_ok and ref == P.content_key(key)
			moved[#moved + 1] = data[ref] or ""
		end
	end
	check(refs_ok, "D every moved packed item refers to its new content key")
	local old = {}
	for _, text in pairs(contents) do old[#old + 1] = text end
	table.sort(old)
	table.sort(moved)
	eq(#moved, 3, "D three packed items moved")
	eq(table.concat(moved, "|"), table.concat(old, "|"), "D ...with exactly their contents")
	local after = snapshot()
	eq(R.move_to_account("carl", ACC), 0, "D a second move moves nothing")
	eq(R.move_to_account("bob", ACC), 0, "D a join without entries moves nothing")
	eq(R.move_to_account("account", "account:x"), 0, "D a bad owner text moves nothing")
	eq(R.move_to_account(ACC, ACC), 0, "D an owner text is no character")
	eq(snapshot(), after, "D ...and writes nothing")
	local moved_log = false
	for _, line in ipairs(logs) do
		if line == "action: [grug_housing] " .. moving .. " belongings of carl moved to " .. ACC then
			moved_log = true
		end
	end
	check(moved_log, "D the move is logged")
end

------------------------------------------------------------------------------
-- E. Leaving; the claim ending and a new one.
------------------------------------------------------------------------------
do
	local count = R.count("ann")
	members.carl = nil
	eq(R.count("carl"), 0, "E carl leaves: nothing comes back (one way)")
	eq(R.count("ann"), count, "E ...and the account keeps all")
	-- The entries hang on the owner text alone: no claim record is read.
	local file = assert(io.open(ROOT .. "/mods/PLAYER/grug_housing/recovered.lua"))
	local source = file:read("*a")
	file:close()
	check(not source:find("player_claim", 1, true) and not source:find("model%.") and
		not source:find("claim_at", 1, true), "E recovered.lua reads no claim record")
	members.ann, members.bob = nil, nil
	eq(R.count("ann"), 0, "E with no member left (the last unlinked) ann sees none")
	check(data["recovered:" .. ACC .. ":3:1"] ~= nil, "E ...the account's entries stay")
	members.dora = ACC
	eq(R.count("dora"), count, "E a new member of a new account claim sees them all again")
	members.ann, members.bob = ACC, ACC
end

------------------------------------------------------------------------------
-- F. Two members take the same entry.
------------------------------------------------------------------------------
do
	local key = "recovered:" .. ACC .. ":3:5"
	eq(data[key], "grug_smelting:charcoal 99", "F the entry holds 99 charcoal")
	local a = R.take(key, 50)
	eq(a:to_string(), "grug_smelting:charcoal 50", "F ann takes 50")
	eq(R.take(key, 99):to_string(), "", "F bob's stale take of 99 takes nothing")
	local b = R.take(key, 49)
	eq(b:to_string(), "grug_smelting:charcoal 49", "F bob takes the 49 left")
	eq(data[key], nil, "F ...the entry is gone")
	eq(R.take(key, 1):to_string(), "", "F ann's second take finds nothing")
	local whole = "recovered:" .. ACC .. ":3:1"
	local first = R.take(whole, 1)
	check(first:get_name() == P.ITEM, "F ann takes a packed chest")
	eq(R.take(whole, 1):to_string(), "", "F bob's take of it takes nothing")
	local seen = 0
	for _, entry in ipairs(R.entries("bob")) do
		if entry.key == whole or entry.key == key then seen = seen + 1 end
	end
	eq(seen, 0, "F neither shows to bob any more")
end

------------------------------------------------------------------------------
-- I. A carried item's number is never reused (fix round 1).
------------------------------------------------------------------------------
do
	local top = "recovered:" .. ACC .. ":3:11"
	local function apples_in(stack)
		local lists = P.contents(stack)
		return lists and #P.stacks(lists) or -1
	end
	check(ItemStack(data[top]):get_name() == P.ITEM, "I the account's highest pass-3 entry is a packed chest")
	local carried = R.take(top, 1) -- bob takes it out
	eq(apples_in(carried), 6, "I bob carries the six-stack chest")
	local carried_row = data["packed:" .. ACC .. ":3:11"]
	members.hank = ACC
	eq(R.move_to_account("hank", ACC), 1, "I hank's packed chest moves")
	eq(data[top], nil, "I the carried chest's number is not reused")
	eq(data["packed:" .. ACC .. ":3:11"], carried_row, "I the carried chest keeps its own contents")
	local moved_key = "recovered:" .. ACC .. ":3:12"
	local moved = ItemStack(data[moved_key] or "")
	eq(moved:get_meta():get_string("ref"), "packed:" .. ACC .. ":3:12", "I the moved chest takes number 12")
	eq(apples_in(moved), 7, "I ...with hank's seven stacks")
	-- Each unpacks once: a placement deletes its contents row (packed.lua on_place).
	storage:set_string(carried:get_meta():get_string("ref"), "")
	eq(apples_in(carried), -1, "I bob's chest unpacked: its row is gone")
	eq(apples_in(moved), 7, "I ...the moved chest still holds its own")
	local taken = R.take(moved_key, 1)
	storage:set_string(taken:get_meta():get_string("ref"), "")
	eq(apples_in(taken), -1, "I the moved chest unpacked once")
	members.hank = nil
end

------------------------------------------------------------------------------
-- G. Deletions.
------------------------------------------------------------------------------
do
	local function account_rows()
		local rows = {}
		for key, value in pairs(data) do
			if key:find(ACC, 1, true) then rows[#rows + 1] = key .. "=" .. value end
		end
		table.sort(rows)
		return table.concat(rows, "\n")
	end
	local account_keys = account_rows()
	R.forget("ann")
	R.forget("a_1842")
	eq(#holder_keys("a_1842"), 0, "G the a_1842 character's entries go with it")
	eq(data["packed:a_1842:3:1"], nil, "G ...and their contents")
	R.forget("account")
	eq(#holder_keys("account"), 0, "G the character called account: its entries go")
	eq(data["packed:account:3:1"], nil, "G ...and its contents")
	check(account_rows() == account_keys and account_keys:find("packed:" .. ACC, 1, true),
		"G every account entry and content stays through all three")
	check(data["packed:" .. ACC .. ":3:3"] ~= nil, "G ...and their contents")
	eq(R.count("bob"), #keys_of(ACC), "G bob still sees them")
	R.forget("carl")
	eq(data["packed:carl:3:1"], nil, "G carl's deletion takes the contents of the chest he carries")
end

------------------------------------------------------------------------------
-- H. The join hook and the notices.
------------------------------------------------------------------------------
do
	-- The pass packed erin's account stone draft under her name.
	members.erin = ACC
	local count = R.count("erin")
	feeds = {}
	join("erin")
	eq(#holder_keys("erin"), 0, "H erin's own entries moved at her join")
	eq(R.count("erin"), count + 1, "H ...into the account's")
	eq(feeds[1], "erin: Belongings from the old map wait in your account's Claim Stone.",
		"H a member's notice")
	eq(R.notice("bob"), R.ACCOUNT_NOTICE, "H the Steward's line for a member")
	feeds = {}
	join("fred")
	eq(#holder_keys("fred"), 1, "H a non-member keeps his own at his join")
	eq(feeds[1], "fred: Belongings from the old map wait in your Claim Stone.", "H his notice")
	eq(R.notice("fred"), R.NOTICE, "H ...and the Steward's line")
	feeds = {}
	join("gina")
	eq(#feeds, 0, "H no notice without belongings")
end

if failures > 0 then
	error(("R86 PACK FIXTURE FAIL checks=%d failures=%d"):format(checks, failures), 0)
end
print(("R86 PACK FIXTURE PASS checks=%d"):format(checks))
