-- Round 67 lane CONTAINERS: the player sort's byte-identity cases. Loaded by
-- portable_test.lua after the r44_ch harness (the REAL grug_inventory); it
-- replaces the harness's ItemStack with one that carries metadata (quality,
-- item level, free fields), so the order's every key and the merge rule
-- (identical name, wear and metadata) take part. Each case fills a player's
-- main and four bags from a fixed pseudo-random sequence, sorts (the Sort
-- button, or the 0.48.0 step's `sizes`) and folds every list into a 32-bit
-- digest. The digests of the base commit 9fcf8093 (before the sort became
-- grug_inventory.sort_slots) are pinned in portable_test.lua.
--
-- Returns a function(H) -> digest string, leftover count.

local Meta = {}
Meta.__index = Meta
function Meta:get_int(key) return math.floor(tonumber(self.fields[key]) or 0) end
function Meta:get_string(key) return self.fields[key] or "" end
function Meta:set_int(key, value) self.fields[key] = tostring(value) end
function Meta:set_string(key, value) self.fields[key] = value ~= "" and value or nil end
function Meta:to_table() return {fields = self.fields} end
local function meta_string(fields)
	local keys = {}
	for key in pairs(fields) do keys[#keys + 1] = key end
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do parts[#parts + 1] = key .. "=" .. fields[key] end
	return table.concat(parts, ";")
end

local Stack = {}
Stack.__index = Stack
local function new_stack(item)
	local self = setmetatable({fields = {}, wear = 0}, Stack)
	if type(item) == "table" then
		self.name, self.count, self.wear = item.name, item.count, item.wear or 0
		for key, value in pairs(item.fields or {}) do self.fields[key] = value end
		return self
	end
	local name, count, wear, meta = tostring(item or ""):match("^(%S*)%s*(%d*)%s*(%d*)%s*(.*)$")
	self.name = name or ""
	self.count = self.name == "" and 0 or (tonumber(count) or 1)
	self.wear = tonumber(wear) or 0
	for key, value in (meta or ""):gmatch("([^=;]+)=([^;]*)") do self.fields[key] = value end
	return self
end
function Stack:get_name() return self.count > 0 and self.name or "" end
function Stack:get_count() return self.count end
function Stack:is_empty() return self.count <= 0 or self.name == "" end
function Stack:get_wear() return self.wear end
function Stack:get_definition() return core.registered_items[self.name] end
function Stack:get_description() return self.name end
function Stack:get_stack_max()
	local def = core.registered_items[self.name]
	return def and def.stack_max or 99
end
function Stack:get_free_space() return self:get_stack_max() - self.count end
function Stack:get_meta() return setmetatable({fields = self.fields}, Meta) end
function Stack:set_count(n)
	self.count = n
	if n <= 0 then self.name, self.count, self.fields, self.wear = "", 0, {}, 0 end
end
function Stack:take_item(n)
	n = math.min(n or 1, self.count)
	local taken = new_stack(self)
	taken:set_count(n)
	self:set_count(self.count - n)
	return taken
end
local function compatible(a, b)
	return a.name == b.name and a.wear == b.wear and
		meta_string(a.fields) == meta_string(b.fields)
end
function Stack:add_item(other)
	other = new_stack(other)
	if other:is_empty() then return other end
	if self:is_empty() then
		local fit = math.min(other.count, other:get_stack_max())
		self.name, self.count, self.wear = other.name, fit, other.wear
		self.fields = {}
		for key, value in pairs(other.fields) do self.fields[key] = value end
		other:set_count(other.count - fit)
		return other
	end
	if not compatible(self, other) then return other end
	local fit = math.max(0, math.min(other.count, self:get_stack_max() - self.count))
	self.count = self.count + fit
	other:set_count(other.count - fit)
	return other
end
function Stack:to_string()
	if self:is_empty() then return "" end
	local meta = meta_string(self.fields)
	return self.name .. " " .. self.count .. " " .. self.wear .. (meta ~= "" and " " .. meta or "")
end

-- The items: every category, tiers by bracket, food tier and item level,
-- small stack sizes so merges overflow, a soulbound and a bound skill item.
local ITEMS = {
	{"s:sword_a", 1, {grug_equip_weapon = 1}, {_grug_bracket = 2}},
	{"s:sword_b", 1, {grug_equip_weapon = 1}, {_grug_bracket = 5}},
	{"s:shield", 1, {grug_equip_offhand = 1}, {_grug_bracket = 3}},
	{"s:ring", 1, {grug_equip_trinket = 1}, {}},
	{"s:helm", 1, {grug_equip_head = 1}, {_grug_bracket = 1}},
	{"s:boots", 1, {grug_equip_feet = 1}, {_grug_ilvl = 34}},
	{"s:arrow", 100, {grug_arrow = 1}, {}},
	{"s:bread", 20, {grug_food = 1, grug_food_tier = 2}, {}},
	{"s:stew", 20, {grug_food = 1, grug_food_tier = 4}, {}},
	{"s:potion", 10, {grug_potion = 1}, {_grug_ilvl = 12}},
	{"s:ore", 99, {}, {_grug_ilvl = 41}},
	{"s:bar", 99, {}, {}},
	{"s:Dirt", 99, {}, {}},
	{"s:apple", 7, {}, {}},
	{"s:claim", 1, {grug_soulbound = 1}, {}},
	{"s:skill", 1, {grug_bound_skill = 1}, {}},
}
for _, row in ipairs(ITEMS) do
	local def = {description = row[1]:sub(3), stack_max = row[2], groups = row[3]}
	for key, value in pairs(row[4]) do def[key] = value end
	core.registered_items[row[1]] = def
end

return function(H)
	ItemStack = new_stack
	local seed = 12345
	local function random(n)
		seed = (seed * 1103515245 + 12345) % 2147483648
		return math.floor(seed / 65536) % n + 1
	end
	local function filled(name, bags, full)
		local p = H.player(name, "warrior", {})
		local inv = p:get_inventory()
		for i = 1, 4 do inv:set_size("grug_bag" .. i .. "_content", bags[i]) end
		for _, list in ipairs({"main", "grug_bag1_content", "grug_bag2_content",
				"grug_bag3_content", "grug_bag4_content"}) do
			for index = 1, inv:get_size(list) do
				if full or random(3) > 1 then
					local row = ITEMS[random(#ITEMS)]
					local stack = new_stack(row[1] .. " " .. random(row[2]))
					local roll = random(6)
					if roll == 1 then stack:get_meta():set_int("grug_quality", random(4)) end
					if roll == 2 then stack:get_meta():set_int("grug_ilvl", random(60)) end
					if roll == 3 then stack.wear = random(3) * 1000 end
					if roll == 4 then stack:get_meta():set_string("note", "n" .. random(2)) end
					inv:set_stack(list, index, stack)
				end
			end
		end
		return p, inv
	end
	local function fold(digest, text)
		for i = 1, #text do digest = (digest * 33 + text:byte(i)) % 4294967296 end
		return (digest * 33 + 10) % 4294967296
	end
	local digest, left_total = 5381, 0
	local SIZES = {8, 12, 16, 20, 0}
	for case = 1, 60 do
		local bags = {SIZES[random(5)], SIZES[random(5)], SIZES[random(5)], SIZES[random(5)]}
		local p, inv = filled("sort" .. case, bags, case % 4 == 0)
		local sizes
		if case % 4 == 0 then
			sizes = {}
			for i = 1, 4 do
				if bags[i] > 8 then
					sizes["grug_bag" .. i .. "_content"] = bags[i] - 4 * random(2)
				end
			end
		end
		local changed, left = grug_inventory.sort(p, sizes)
		digest = fold(digest, tostring(changed) .. "|" .. #left)
		for _, entry in ipairs(left) do
			digest = fold(digest, entry.list .. "#" .. entry.index .. "=" .. entry.stack:to_string())
		end
		left_total = left_total + #left
		for _, list in ipairs({"main", "grug_bag1_content", "grug_bag2_content",
				"grug_bag3_content", "grug_bag4_content"}) do
			for index = 1, inv:get_size(list) do
				digest = fold(digest, inv:get_stack(list, index):to_string())
			end
		end
		-- A second sort of a sorted inventory changes nothing.
		digest = fold(digest, tostring((grug_inventory.sort(p, sizes))))
	end
	return ("%08x"):format(digest), left_total
end
