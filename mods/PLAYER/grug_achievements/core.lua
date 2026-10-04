--
-- The pure rules of achievements and cloaks: counters, tiers, unlocks and the
-- selected cloak, all on a PlayerMetaRef-shaped `meta` (get_int/set_int,
-- get_string/set_string). No engine call, so tools/r33_c3/portable_test.lua
-- runs this very file against a table.
--
-- Everything lives in player meta, i.e. per character:
--   grug_achievements:n:<counter>     the counter (int)
--   grug_achievements:tier:<id>       tiers earned of achievement <id> (int)
--   grug_achievements:cloaks          earned cloak ids, comma-separated
--   grug_achievements:cloak           the selected cloak id ("" = No cloak)
-- The default cloaks are never stored: every character owns them.
--

local R = {}

local P = "grug_achievements:"
R.KEY_COUNT = P .. "n:"
R.KEY_TIER = P .. "tier:"
R.KEY_CLOAKS = P .. "cloaks"
R.KEY_SELECTED = P .. "cloak"
R.NONE = "none"

local ROMAN = {"", " II", " III", " IV", " V", " VI"}

-- Index the catalogue (catalog.lua) and check it; a broken row is a load
-- error, never a silently missing cloak.
function R.build(catalog)
	local book = {cloaks = {}, cloak = {}, achievements = {}, achievement = {},
		by_counter = {}, default = {}}
	for index, cloak in ipairs(catalog.cloaks) do
		assert(type(cloak.id) == "string" and cloak.id:find("^[a-z0-9_]+$"),
			"grug_achievements: cloak " .. index .. " needs an id")
		assert(not book.cloak[cloak.id], "grug_achievements: cloak " .. cloak.id .. " twice")
		assert(type(cloak.name) == "string" and not cloak.name:find("[,;%[%]]"),
			"grug_achievements: cloak " .. cloak.id .. " needs a plain name")
		book.cloak[cloak.id] = cloak
		book.cloaks[index] = cloak
	end
	assert(book.cloak[R.NONE] and not book.cloak[R.NONE].texture,
		"grug_achievements: the catalogue needs the textureless \"none\" cloak")
	for _, id in ipairs(catalog.defaults) do
		assert(book.cloak[id], "grug_achievements: unknown default cloak " .. id)
		book.default[id] = true
	end
	for index, ach in ipairs(catalog.achievements) do
		assert(type(ach.id) == "string" and not book.achievement[ach.id],
			"grug_achievements: achievement " .. index .. " needs a unique id")
		assert(type(ach.counter) == "string" and ach.counter ~= "",
			"grug_achievements: " .. ach.id .. " needs a counter")
		assert(type(ach.tiers) == "table" and #ach.tiers >= 1 and #ach.tiers <= #ROMAN,
			"grug_achievements: " .. ach.id .. " needs 1.." .. #ROMAN .. " tiers")
		local last = 0
		for t, tier in ipairs(ach.tiers) do
			assert(type(tier.at == 1 and ach.text_one or ach.text) == "string",
				"grug_achievements: " .. ach.id .. " tier " .. t .. " has no condition text")
			assert(type(tier.at) == "number" and tier.at > last,
				"grug_achievements: " .. ach.id .. " tier " .. t .. " must rise")
			assert(tier.cloak == nil or (book.cloak[tier.cloak] and
				not book.default[tier.cloak]),
				"grug_achievements: " .. ach.id .. " tier " .. t .. " unlocks an unknown cloak")
			last = tier.at
		end
		book.achievement[ach.id] = ach
		book.achievements[index] = ach
		local list = book.by_counter[ach.counter] or {}
		list[#list + 1] = ach
		book.by_counter[ach.counter] = list
	end
	return book
end

--
-- Counters
--

function R.count(meta, counter)
	return meta:get_int(R.KEY_COUNT .. counter)
end

function R.add(meta, counter, amount)
	local value = meta:get_int(R.KEY_COUNT .. counter) + (amount or 1)
	meta:set_int(R.KEY_COUNT .. counter, value)
	return value
end

--
-- Tiers
--

-- How many tiers `value` reaches.
function R.reached(ach, value)
	local count = 0
	for _, tier in ipairs(ach.tiers) do
		if value >= tier.at then
			count = count + 1
		else
			break
		end
	end
	return count
end

function R.earned(meta, ach)
	return meta:get_int(R.KEY_TIER .. ach.id)
end

-- The title of tier `t` ("Hunter", "Hunter II", ...); the plain name for an
-- achievement with one tier.
function R.title(ach, t)
	if #ach.tiers == 1 or t < 1 then
		return ach.name
	end
	return ach.name .. ROMAN[t]
end

--
-- Cloaks
--

local function stored_cloaks(book, meta)
	local list, seen = {}, {}
	for id in meta:get_string(R.KEY_CLOAKS):gmatch("[^,]+") do
		-- A cloak the catalogue no longer has is ignored, not an error.
		if book.cloak[id] and not seen[id] then
			seen[id] = true
			list[#list + 1] = id
		end
	end
	return list, seen
end

function R.has_cloak(book, meta, id)
	if book.default[id] then
		return book.cloak[id] ~= nil
	end
	local _, seen = stored_cloaks(book, meta)
	return seen[id] == true
end

-- Owned cloaks in catalogue order (defaults included).
function R.unlocked(book, meta)
	local _, seen = stored_cloaks(book, meta)
	local list = {}
	for _, cloak in ipairs(book.cloaks) do
		if book.default[cloak.id] or seen[cloak.id] then
			list[#list + 1] = cloak.id
		end
	end
	return list
end

local function unlock(book, meta, id)
	local list, seen = stored_cloaks(book, meta)
	if seen[id] or book.default[id] then
		return false
	end
	list[#list + 1] = id
	meta:set_string(R.KEY_CLOAKS, table.concat(list, ","))
	return true
end

-- Bring achievement `ach` in line with its counter `value`: every tier newly
-- reached is earned once and unlocks its cloak. Returns the new tiers as
-- {achievement, tier, cloak} rows (empty when nothing changed). Never takes a
-- tier back.
function R.settle(book, meta, ach, value)
	local earned = R.earned(meta, ach)
	local reached = R.reached(ach, value)
	local new = {}
	if reached <= earned then
		return new
	end
	for t = earned + 1, reached do
		local cloak = ach.tiers[t].cloak
		if cloak then
			unlock(book, meta, cloak)
		end
		new[#new + 1] = {achievement = ach, tier = t, cloak = cloak}
	end
	meta:set_int(R.KEY_TIER .. ach.id, reached)
	return new
end

-- The selected cloak; anything not owned (or no longer in the catalogue)
-- reads as No cloak.
function R.selected(book, meta)
	local id = meta:get_string(R.KEY_SELECTED)
	if id ~= "" and R.has_cloak(book, meta, id) then
		return id
	end
	return R.NONE
end

function R.select(book, meta, id)
	if not book.cloak[id] or not R.has_cloak(book, meta, id) then
		return false
	end
	meta:set_string(R.KEY_SELECTED, id == R.NONE and "" or id)
	return true
end

-- The model texture of the selected cloak, nil for No cloak.
function R.cloak_texture(book, meta)
	return book.cloak[R.selected(book, meta)].texture
end

return R
