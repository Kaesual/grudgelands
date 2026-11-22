-- The Claim Stone inventory (Round 50 lane PGAME, docs/planning/round50-plan.md
-- rulings 7-8, D6, D8 and §3). Before a map reset the migration tool writes
-- each claim's containers and its unburnt fuel into this mod's storage, one
-- entry per item, owned by the claim's owner:
--   recovered:<player>:<seq>:<n>   one item string: a packed container
--                                  (packed.lua) or plain charcoal stacks
--   pack_seq                       the tool's pass counter
-- and marks the pass in grug_core's storage, `map_reset_pack:<seq>`. At the
-- next start grug_core's runner (world_version.lua) hands each marked pass to
-- the clean-up below, after the map-reset clears and before any join. The
-- clean-up writes keys of its own in the same pass:
--   recovered:<player>:<seq>:<n>.<k>   D6's additional packed chests and the
--                                      parts of an overfull stack
--   recovered:<player>:<seq>:0.<k>     the pass's empty containers as their
--                                      nodes' items, stacked (ruling 13)
--   packed:<player>:<seq>:<n>[.<k>]    a packed container's contents, which
--                                      its item references (ruling 14)
--
-- The entries and contents belong to the player, not to the claim: picking
-- the stone up, losing it or a later map reset (registry.lua M.map_reset
-- clears only the claim records) leaves them. They show, take-only, in the active stone's
-- form (stone_form.lua); taking an item deletes its entry or keeps the rest.
--
-- Round 86 (lane PACK, plan §3.1, rulings 7 and 13): an account claim's
-- belongings are held by the claim's owner text, `account:<id>:<faction>`,
-- under the same key shapes:
--   recovered:account:<id>:<faction>:<seq>:<n>[.<k>]
--   packed:account:<id>:<faction>:<seq>:<n>[.<k>]
-- (the pass writes the claim's owner verbatim). The holder field of a
-- player key holds no colon, so its pattern can never read an account key
-- and the reverse (five fields after `recovered:` against three). Every
-- member sees and takes them (R.holder); they stay when the claim ends or
-- the last member goes and show again in the next account claim of that
-- account and faction. A character's own entries move to them when it
-- joins (R.move_to_account), one way; a packed item already taken out
-- stays its holder's and keeps its content key.

local R = {}
grug_housing.recovered = R

local storage = grug_housing.storage
local packed = grug_housing.packed
local PREFIX = "recovered:"
R.PREFIX = PREFIX

-- Whether `text` is an account claim's owner text, `account:<id>:<faction>`.
function R.is_account(text)
	return type(text) == "string" and text:find("^account:[%w_%-]+:[%w_%-]+$") ~= nil
end

-- holder, seq, n, k (k 0 for a tool key) of an entry key, else nil; the
-- holder is a player's name or an account's owner text.
function R.parse_key(key)
	local holder, seq, n, k = key:match("^recovered:([%w_%-]+):(%d+):(%d+)%.?(%d*)$")
	if not holder then
		holder, seq, n, k = key:match(
			"^recovered:(account:[%w_%-]+:[%w_%-]+):(%d+):(%d+)%.?(%d*)$")
	end
	if not holder then return nil end
	return holder, tonumber(seq), tonumber(n), tonumber(k) or 0
end

local function key_before(a, b)
	local _, sa, na, ka = R.parse_key(a)
	local _, sb, nb, kb = R.parse_key(b)
	if sa ~= sb then return sa < sb end
	if na ~= nb then return na < nb end
	if ka ~= kb then return ka < kb end
	return a < b
end

-- The waiting keys per player, sorted (the order of the stone's slots); read
-- from storage once, then kept by every write here. Nothing else writes the
-- entries while the server runs.
local index

local function build_index()
	index = {}
	for _, key in ipairs(storage:get_keys()) do
		local player = R.parse_key(key)
		if player then
			index[player] = index[player] or {}
			table.insert(index[player], key)
		end
	end
	for _, keys in pairs(index) do table.sort(keys, key_before) end
end

local function keys_of(name)
	if not index then build_index() end
	return index[name] or {}
end

-- Round 86: whose entries the character `name` sees in its stone's
-- Belongings tab (and the Steward's line and the join notice): the holder
-- the keys name, `recovered:<holder>:...`. A member of an account claim
-- (grug_housing.account_owner_of) sees the account's, whether or not its
-- claim stands; every other character its own.
function R.holder(name)
	local account = grug_housing.account_owner_of and grug_housing.account_owner_of(name)
	if R.is_account(account) then return account end
	return name
end

-- Round 86: moves the character's own waiting entries, with their packed
-- contents, to those of the account claim whose owner text is `owner_text`
-- (`account:<id>:<faction>`), one way (concept ruling 7); returns how many
-- moved. Each keeps its pass and takes the next free number of the
-- account's in it, `recovered:<owner_text>:<seq>:<m>` (above every stored
-- entry, and never one whose content key a carried item still refers to:
-- Round 86 fix round 1); a packed item's
-- contents move to that key's content key and the item's reference with
-- them. Every write happens in this one call, and the engine commits mod
-- storage only between server steps (reference_projects/luanti
-- src/server.cpp AsyncRunStep, endSave/beginSave), so a crash leaves all
-- the old keys or all the new ones, never a mix.
function R.move_to_account(name, owner_text)
	if not R.is_account(owner_text) or R.is_account(name) then return 0 end
	local own = keys_of(name)
	if #own == 0 then return 0 end
	local moving = {}
	for i, key in ipairs(own) do moving[i] = key end
	local next_n, target = {}, keys_of(owner_text)
	for _, key in ipairs(target) do
		local _, seq, n = R.parse_key(key)
		if n >= (next_n[seq] or 1) then next_n[seq] = n + 1 end
	end
	for _, key in ipairs(moving) do
		local _, seq = R.parse_key(key)
		-- A number is free only when neither its entry nor its content key
		-- holds anything: an item a member took out has no entry any more,
		-- but its contents wait under its content key until it is unpacked.
		local n, new_key = next_n[seq] or 1, nil
		while true do
			new_key = ("%s%s:%d:%d"):format(PREFIX, owner_text, seq, n)
			if storage:get_string(new_key) == "" and
					storage:get_string(packed.content_key(new_key)) == "" then
				break
			end
			n = n + 1
		end
		next_n[seq] = n + 1
		local value = storage:get_string(key)
		local stack = ItemStack(value)
		local ref = stack:get_name() == packed.ITEM and stack:get_meta():get_string("ref") or ""
		if ref ~= "" then
			local new_ref = packed.content_key(new_key)
			storage:set_string(new_ref, storage:get_string(ref))
			stack:get_meta():set_string("ref", new_ref)
			value = stack:to_string()
		end
		storage:set_string(new_key, value)
		storage:set_string(key, "")
		if ref ~= "" then storage:set_string(ref, "") end
		target[#target + 1] = new_key
	end
	table.sort(target, key_before)
	index[owner_text], index[name] = target, nil
	core.log("action", ("[grug_housing] %d belongings of %s moved to %s"):format(
		#moving, name, owner_text))
	return #moving
end

-- The entries the character's stone shows (its holder's), in slot order:
-- {key = ..., stack = ItemStack}.
function R.entries(name)
	local result = {}
	for _, key in ipairs(keys_of(R.holder(name))) do
		result[#result + 1] = {key = key, stack = ItemStack(storage:get_string(key))}
	end
	return result
end

function R.count(name)
	return #keys_of(R.holder(name))
end

-- What entry `key` holds now, "" when it is gone.
function R.stored(key)
	return storage:get_string(key)
end

-- Takes `count` items of entry `key` (a take from the stone's slot): the rest
-- stays, an emptied entry is deleted. Returns the stack taken, empty when the
-- entry does not hold that many.
function R.take(key, count)
	local stack = ItemStack(storage:get_string(key))
	if stack:is_empty() or count <= 0 or count > stack:get_count() then
		return ItemStack("")
	end
	local taken = stack:take_item(count)
	storage:set_string(key, stack:is_empty() and "" or stack:to_string())
	if stack:is_empty() then
		local name = R.parse_key(key)
		local keys = keys_of(name)
		for i = #keys, 1, -1 do
			if keys[i] == key then table.remove(keys, i) end
		end
		if index and index[name] and #index[name] == 0 then index[name] = nil end
	end
	return taken
end

-- The deletion of a character (Round 83): every entry and packed content of
-- `name` goes. A packed item is soulbound, so it can only be in the owner's
-- carried lists, which go with the engine's player record.
-- Round 86: a key under the name's prefix that reads as another holder's
-- (an account's, `recovered:account:...` for a character named "account")
-- stays; so do the account's entries of a member (ruling 13).
function R.forget(name)
	local entry, content = PREFIX .. name .. ":", "packed:" .. name .. ":"
	for _, key in ipairs(storage:get_keys()) do
		local rest
		if key:sub(1, #entry) == entry then
			rest = key:sub(#PREFIX + 1)
		elseif key:sub(1, #content) == content then
			rest = key:sub(#"packed:" + 1)
		end
		if rest then
			local holder = R.parse_key(PREFIX .. rest)
			if holder == nil or holder == name then storage:set_string(key, "") end
		end
	end
	if index then index[name] = nil end
end

--
-- The first start's clean-up of a pass (§3, the world marker; rulings 8,
-- 13 and 14): every entry of pass `seq` loses the items this version does
-- not register; a packed container is fitted to its node (D6, extra chests
-- under `<n>.<k>`), its contents move into storage under its content key
-- (packed.content_key) and the item keeps only the reference, the node,
-- the pass, the description and the image; an empty container becomes its
-- node's own item, stacked with the player's other ones of the pass under
-- `0.<k>` (the tool counts from 1); a stack above its stack size is split.
-- Safe to run again: each key it writes is a function of the entries it
-- reads, new keys are written before old ones change or go, a cleaned item
-- (a reference, no lists) is left alone, and the stacked empties count as
-- written once their first key, written last, exists.
--

-- Splits `stacks` (an array of item strings) into chests of the chest's
-- size: an array of lists tables.
local function chest_lists(stacks)
	local size = packed.CONTAINER_LISTS[packed.CHEST].main
	local chests = {}
	for i = 1, #stacks, size do
		local main = {}
		for j = i, math.min(i + size - 1, #stacks) do main[#main + 1] = stacks[j] end
		chests[#chests + 1] = {main = main}
	end
	return chests
end

-- A packed entry's node and lists, fitted to the node, the extra chests'
-- lists (D6) and, for a node this version does not restore as itself, the
-- node's plain item (packed.node_item). The node is nil for an empty one
-- this version cannot restore.
-- Lists that do not decode raise: the runner stops the load and keeps the
-- marker and the entry, never an empty container in their place.
local function clean_packed(key, stack, removed)
	local meta = stack:get_meta()
	local node = meta:get_string("node")
	local text = meta:get_string("lists")
	if text ~= "" and type(core.deserialize(text, true)) ~= "table" then
		error(("%s: the packed lists of %s do not decode"):format(key, node), 0)
	end
	local lists = packed.lists(stack)
	-- Unregistered items go (ruling 8).
	for _, list in pairs(lists) do
		for i, item in pairs(list) do
			local name = ItemStack(item):get_name()
			if name ~= "" and not packed.registered(name) then
				list[i] = ""
				removed[#removed + 1] = item
			elseif name == "" then
				list[i] = ""
			end
		end
	end
	local base = packed.restorable(node)
	local extras = {}
	-- Moves list[from..] into extras.
	local function extra(list, from)
		for i = from, table.maxn(list) do
			if list[i] and list[i] ~= "" then extras[#extras + 1] = list[i] end
			list[i] = nil
		end
	end
	local names = {}
	for listname in pairs(lists) do names[#names + 1] = listname end
	table.sort(names)
	if base then
		-- Stacks beyond a list's size, and lists the node lacks, go extra.
		local sizes = packed.CONTAINER_LISTS[base]
		for _, listname in ipairs(names) do
			local size = sizes[listname]
			extra(lists[listname], (size or 0) + 1)
			if not size then lists[listname] = nil end
		end
		return base, lists, chest_lists(extras)
	end
	-- A node this version cannot restore (a station, a gone node): its
	-- stacks go into chests, and the node comes back as its plain item if
	-- it still exists.
	for _, listname in ipairs(names) do extra(lists[listname], 1) end
	local item = packed.node_item(node)
	if #extras == 0 then return nil, {}, {}, item end
	local chests = chest_lists(extras)
	return packed.CHEST, table.remove(chests, 1), chests, item
end

-- Writes a cleaned packed item under `key`: its contents first.
local function store_packed(key, node, lists, seq)
	local ref = packed.content_key(key)
	storage:set_string(ref, core.serialize(lists))
	storage:set_string(key, packed.make_ref(node, ref, seq, lists):to_string())
end

-- The stacked empties' keys of a player's pass: `0.<k>`.
local function empties_key(player, seq, k)
	return ("recovered:%s:%d:0.%d"):format(player, seq, k)
end

-- Ruling 13: the empty containers' items, stacked; written last to first, so
-- the first key stands for all of them; then the empties go.
local function stack_empties(player, seq, empties)
	if storage:get_string(empties_key(player, seq, 1)) == "" then
		local totals, names = {}, {}
		for _, empty in ipairs(empties) do
			if empty.item then
				if not totals[empty.item] then names[#names + 1] = empty.item end
				totals[empty.item] = (totals[empty.item] or 0) + 1
			end
		end
		table.sort(names)
		local stacks = {}
		for _, name in ipairs(names) do
			local left, max = totals[name], ItemStack(name):get_stack_max()
			while left > 0 do
				local count = math.min(max, left)
				stacks[#stacks + 1] = ItemStack(name .. " " .. count)
				left = left - count
			end
		end
		for k = #stacks, 1, -1 do
			storage:set_string(empties_key(player, seq, k), stacks[k]:to_string())
		end
	end
	for _, empty in ipairs(empties) do
		if empty.key then storage:set_string(empty.key, "") end
	end
end

-- One entry. Returns whether it was deleted. A filled container whose node
-- comes back as a plain item too (a station) is rewritten only after the
-- stacking (`later`), so a rerun still reads its node from it.
local function clean_entry(key, seq, removed, empties, later)
	local stack = ItemStack(storage:get_string(key))
	local name = stack:get_name()
	if stack:is_empty() or not packed.registered(name) then
		if not stack:is_empty() then removed[#removed + 1] = stack:to_string() end
		storage:set_string(key, "")
		return true
	end
	if name == packed.ITEM then
		local meta = stack:get_meta()
		if meta:get_string("ref") ~= "" and meta:get_string("lists") == "" then
			return false -- cleaned before
		end
		local node, lists, chests, item = clean_packed(key, stack, removed)
		for k, chest in ipairs(chests) do
			store_packed(key .. "." .. k, packed.CHEST, chest, seq)
		end
		if node and #packed.stacks(lists) > 0 then
			if item then
				empties[#empties + 1] = {item = item}
				later[#later + 1] = {key = key, node = node, lists = lists}
			else
				store_packed(key, node, lists, seq)
			end
			return false
		end
		empties[#empties + 1] = {key = key, item = node or item}
		return true
	end
	-- Plain stacks (the stone's charcoal): split at the stack size.
	local max = stack:get_stack_max()
	if stack:get_count() <= max then return false end
	local k, left = 0, stack:get_count() - max
	while left > 0 do
		k = k + 1
		local part = ItemStack(stack)
		part:set_count(math.min(max, left))
		left = left - part:get_count()
		storage:set_string(key .. "." .. k, part:to_string())
	end
	stack:set_count(max)
	storage:set_string(key, stack:to_string())
	return false
end

-- Runs the clean-up of pass `seq`; returns a summary for the log.
function R.clean_pass(seq)
	seq = tonumber(seq)
	assert(seq, "the pass number is no number")
	-- The tool's own entries of the pass, per player; derived keys are
	-- written from theirs.
	local players, keys = {}, {}
	for _, key in ipairs(storage:get_keys()) do
		local player, key_seq, n, k = R.parse_key(key)
		if player and key_seq == seq and k == 0 and n > 0 then
			if not keys[player] then
				keys[player] = {}
				players[#players + 1] = player
			end
			table.insert(keys[player], key)
		end
	end
	table.sort(players)
	local stats = {entries = 0, deleted = 0, empties = 0, removed = 0}
	for _, player in ipairs(players) do
		table.sort(keys[player], key_before)
		local empties, later = {}, {}
		for _, key in ipairs(keys[player]) do
			local removed = {}
			if clean_entry(key, seq, removed, empties, later) then
				stats.deleted = stats.deleted + 1
			end
			if #removed > 0 then
				stats.removed = stats.removed + #removed
				core.log("action", ("[grug_housing] map reset pass %d: %s lost unknown %s"):format(
					seq, key, table.concat(removed, ", ")))
			end
		end
		stats.entries = stats.entries + #keys[player]
		stats.empties = stats.empties + #empties
		if #empties > 0 then stack_empties(player, seq, empties) end
		for _, entry in ipairs(later) do store_packed(entry.key, entry.node, entry.lists, seq) end
	end
	index = nil
	core.log("action", ("[grug_housing] map reset pass %d: %d entries cleaned, %d deleted " ..
		"(%d containers back as their nodes' items), %d unknown items removed"):format(seq,
		stats.entries, stats.deleted, stats.empties, stats.removed))
	return stats
end

grug_core.world_version.register_pack_handler(R.clean_pass)

-- D8: one notice at every join while belongings wait.
R.NOTICE = "Belongings from the old map wait in your Claim Stone."
R.ACCOUNT_NOTICE = "Belongings from the old map wait in your account's Claim Stone."

-- The notice for the character `name`: a member's belongings are the account's.
function R.notice(name)
	return R.holder(name) ~= name and R.ACCOUNT_NOTICE or R.NOTICE
end

-- Round 86: a member's own entries (a pass packed its account stone's draft
-- under its name, or a join left some) move to the account's at its join,
-- before the notice counts them.
core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local holder = R.holder(name)
	if holder ~= name and #keys_of(name) > 0 then R.move_to_account(name, holder) end
	if R.count(name) == 0 then return end
	core.after(0, function()
		local online = core.get_player_by_name(name)
		if online then grug_core.feed(online, "notice", R.notice(name), "grug_housing_recovered") end
	end)
end)
