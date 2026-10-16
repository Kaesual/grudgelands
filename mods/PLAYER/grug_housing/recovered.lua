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
-- clean-up writes keys of its own in the same pass, `<n>.<k>` (D6's
-- additional packed chests and the parts of an overfull stack).
--
-- The entries belong to the player, not to the claim: picking the stone up,
-- losing it or a later map reset (registry.lua M.map_reset clears only the
-- claim records) leaves them. They show, take-only, in the active stone's
-- form (stone_form.lua); taking an item deletes its entry or keeps the rest.

local R = {}
grug_housing.recovered = R

local storage = grug_housing.storage
local packed = grug_housing.packed
local PREFIX = "recovered:"
R.PREFIX = PREFIX

-- player, seq, n, k (k 0 for a tool key) of an entry key, else nil.
function R.parse_key(key)
	local player, seq, n, k = key:match("^recovered:([%w_%-]+):(%d+):(%d+)%.?(%d*)$")
	if not player then return nil end
	return player, tonumber(seq), tonumber(n), tonumber(k) or 0
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

-- The player's entries in slot order: {key = ..., stack = ItemStack}.
function R.entries(name)
	local result = {}
	for _, key in ipairs(keys_of(name)) do
		result[#result + 1] = {key = key, stack = ItemStack(storage:get_string(key))}
	end
	return result
end

function R.count(name)
	return #keys_of(name)
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

--
-- The first start's clean-up of a pass (§3, the world marker): every entry
-- of pass `seq` loses the items this version does not register; a packed
-- container is fitted to its node (D6); a stack above its stack size is
-- split; the packed items get their descriptions and images (D5). Safe to
-- run again: every key it writes is a function of the entry it reads, the
-- derived keys first and the entry itself last, so a rerun over a half-done
-- pass writes the same values, and a cleaned entry cleans to itself.
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

-- A packed entry's cleaned item and the extra chests' lists (D6). Lists
-- that do not decode raise: the runner stops the load and keeps the marker
-- and the entry, never an empty container in their place.
local function clean_packed(key, stack, seq, removed)
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
	if base then
		-- Stacks beyond a list's size, and lists the node lacks, go extra.
		local sizes = packed.CONTAINER_LISTS[base]
		local names = {}
		for listname in pairs(lists) do names[#names + 1] = listname end
		table.sort(names)
		for _, listname in ipairs(names) do
			local size = sizes[listname]
			extra(lists[listname], (size or 0) + 1)
			if not size then lists[listname] = nil end
		end
		node = base
	else
		-- A node this version cannot restore: its stacks go into chests.
		local names = {}
		for listname in pairs(lists) do names[#names + 1] = listname end
		table.sort(names)
		for _, listname in ipairs(names) do extra(lists[listname], 1) end
		if #extras == 0 then return nil, {} end
		local chests = chest_lists(extras)
		node, lists, extras = packed.CHEST, chests[1], {}
		for i = 2, #chests do
			for _, item in ipairs(chests[i].main) do extras[#extras + 1] = item end
		end
	end
	local cleaned = packed.describe(packed.make(node, lists, meta:get_string("seq") ~= "" and
		meta:get_string("seq") or seq))
	local more = {}
	for _, chest in ipairs(chest_lists(extras)) do
		more[#more + 1] = packed.describe(packed.make(packed.CHEST, chest, seq))
	end
	return cleaned, more
end

-- One entry: returns the item to keep (nil: delete) and the extra items.
local function clean_entry(key, stack, seq, removed)
	local name = stack:get_name()
	if stack:is_empty() then return nil, {} end
	if not packed.registered(name) then
		removed[#removed + 1] = stack:to_string()
		return nil, {}
	end
	if name == packed.ITEM then
		return clean_packed(key, stack, seq, removed)
	end
	-- Plain stacks (the stone's charcoal): split at the stack size.
	local max = stack:get_stack_max()
	if stack:get_count() <= max then return stack, {} end
	local more, left = {}, stack:get_count() - max
	stack:set_count(max)
	while left > 0 do
		local part = ItemStack(stack)
		part:set_count(math.min(max, left))
		left = left - part:get_count()
		more[#more + 1] = part
	end
	return stack, more
end

-- Runs the clean-up of pass `seq`; returns a summary for the log.
function R.clean_pass(seq)
	seq = tonumber(seq)
	assert(seq, "the pass number is no number")
	local keys = {}
	for _, key in ipairs(storage:get_keys()) do
		local player, key_seq, _, k = R.parse_key(key)
		-- The pass's own entries; derived keys are rewritten from theirs.
		if player and key_seq == seq and k == 0 then keys[#keys + 1] = key end
	end
	table.sort(keys, key_before)
	local stats = {entries = #keys, deleted = 0, extra = 0, removed = 0}
	for _, key in ipairs(keys) do
		local removed = {}
		local keep, more = clean_entry(key, ItemStack(storage:get_string(key)), seq, removed)
		for k, item in ipairs(more) do
			storage:set_string(key .. "." .. k, item:to_string())
		end
		stats.extra = stats.extra + #more
		storage:set_string(key, keep and keep:to_string() or "")
		if not keep then stats.deleted = stats.deleted + 1 end
		if #removed > 0 then
			stats.removed = stats.removed + #removed
			core.log("action", ("[grug_housing] map reset pass %d: %s lost unknown %s"):format(
				seq, key, table.concat(removed, ", ")))
		end
	end
	index = nil
	core.log("action", ("[grug_housing] map reset pass %d: %d entries cleaned, %d deleted, " ..
		"%d extra, %d unknown items removed"):format(seq, stats.entries, stats.deleted,
		stats.extra, stats.removed))
	return stats
end

grug_core.world_version.register_pack_handler(R.clean_pass)

-- D8: one notice at every join while belongings wait.
R.NOTICE = "Belongings from the old map wait in your Claim Stone."

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	if R.count(name) == 0 then return end
	core.after(0, function()
		local online = core.get_player_by_name(name)
		if online then grug_core.feed(online, "notice", R.NOTICE, "grug_housing_recovered") end
	end)
end)
