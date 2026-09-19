local PRIMARY_SLOTS = 2
local META_PRIMARY = "grug_jobs:primary:"
local META_LEARNED = "grug_jobs:learned:"
local META_LEVEL = "grug_jobs:level:"
local META_CRAFTS = "grug_jobs:crafts:"

grug_jobs.CRAFTS_TO_ADVANCE = {10, 15, 20, 25, 30}

local function set_string(meta, key, value)
	value = value or ""
	if meta:get_string(key) ~= value then meta:set_string(key, value) end
end

local function set_int(meta, key, value)
	if meta:get_int(key) ~= value then meta:set_int(key, value) end
end

local function message(player, text)
	if core.chat_send_player and player and player.get_player_name then
		core.chat_send_player(player:get_player_name(), text)
	end
end

function grug_jobs.character_tier(player)
	local level = grug_xp.get_level(player)
	if level < 1 then level = 1 end
	return math.min(6, math.floor((level - 1) / 10) + 1)
end

function grug_jobs.primary_at(player, slot)
	if slot < 1 or slot > PRIMARY_SLOTS then return nil end
	local value = player:get_meta():get_string(META_PRIMARY .. slot)
	return value ~= "" and value or nil
end

function grug_jobs.has(player, profession)
	local definition = grug_jobs.PROFESSIONS[profession]
	if not definition then return false end
	local meta = player:get_meta()
	if definition.class == "primary" then
		for slot = 1, PRIMARY_SLOTS do
			if meta:get_string(META_PRIMARY .. slot) == profession then return true end
		end
		return false
	end
	return meta:get_int(META_LEARNED .. profession) == 1
end

function grug_jobs.learn(player, profession)
	local definition = grug_jobs.PROFESSIONS[profession]
	if not definition then return false, "Unknown profession." end
	if grug_jobs.has(player, profession) then
		return true, "You already know " .. definition.name .. "."
	end
	local meta = player:get_meta()
	if definition.class == "primary" then
		local empty
		for slot = 1, PRIMARY_SLOTS do
			if meta:get_string(META_PRIMARY .. slot) == "" then empty = slot break end
		end
		if not empty then
			local text = "Two primary professions already learned. Unlearn one first."
			message(player, text)
			return false, text
		end
		set_string(meta, META_PRIMARY .. empty, profession)
	else
		set_int(meta, META_LEARNED .. profession, 1)
	end
	set_int(meta, META_LEVEL .. profession, 1)
	set_int(meta, META_CRAFTS .. profession, 0)
	if type(grug_jobs.discover_tier_one_inputs) == "function" then
		grug_jobs.discover_tier_one_inputs(player, profession)
	end
	local text = "Learned " .. definition.name .. "."
	message(player, text)
	return true, text
end

function grug_jobs.unlearn(player, profession)
	local definition = grug_jobs.PROFESSIONS[profession]
	if not definition or not grug_jobs.has(player, profession) then
		return false, "You do not know that profession."
	end
	local meta = player:get_meta()
	if definition.class == "primary" then
		for slot = 1, PRIMARY_SLOTS do
			local key = META_PRIMARY .. slot
			if meta:get_string(key) == profession then set_string(meta, key, "") end
		end
	else
		set_int(meta, META_LEARNED .. profession, 0)
	end
	set_int(meta, META_LEVEL .. profession, 0)
	set_int(meta, META_CRAFTS .. profession, 0)
	local text = "Unlearned " .. definition.name .. "; its progression was lost."
	message(player, text)
	return true, text
end

-- Returns 0 for an unlearned profession; a learned profession always returns
-- one of the six recipe tiers.
function grug_jobs.profession_level(player, profession)
	if not grug_jobs.has(player, profession) then return 0 end
	local stored = player:get_meta():get_int(META_LEVEL .. profession)
	if stored < 1 then stored = 1 end
	return math.min(stored, grug_jobs.character_tier(player), 6)
end

function grug_jobs.crafts_in_tier(player, profession)
	if not grug_jobs.has(player, profession) then return 0 end
	return math.max(0, player:get_meta():get_int(META_CRAFTS .. profession))
end

function grug_jobs.record_craft(player, profession, tier)
	if not grug_jobs.has(player, profession) then return false, 0 end
	local current = grug_jobs.profession_level(player, profession)
	local meta = player:get_meta()
	if tier ~= current or current >= 6 then
		return false, current
	end
	local threshold = grug_jobs.CRAFTS_TO_ADVANCE[current]
	local count = math.min(threshold,
		math.max(0, meta:get_int(META_CRAFTS .. profession)))
	-- A capped threshold stays saturated. Entering the next character band does
	-- not advance automatically; this next successful current-tier craft does.
	if count >= threshold and grug_jobs.character_tier(player) > current then
		set_int(meta, META_LEVEL .. profession, current + 1)
		set_int(meta, META_CRAFTS .. profession, 0)
		message(player, grug_jobs.PROFESSIONS[profession].name ..
			" advanced to tier " .. (current + 1) .. ".")
		return true, current + 1
	end
	if count >= threshold then return false, current end
	count = count + 1
	set_int(meta, META_CRAFTS .. profession, count)
	if count >= threshold and grug_jobs.character_tier(player) > current then
		set_int(meta, META_LEVEL .. profession, current + 1)
		set_int(meta, META_CRAFTS .. profession, 0)
		message(player, grug_jobs.PROFESSIONS[profession].name ..
			" advanced to tier " .. (current + 1) .. ".")
		return true, current + 1
	elseif count >= threshold then
		message(player, grug_jobs.PROFESSIONS[profession].name ..
			" tier progress is ready; craft once more at character level " ..
			(current * 10 + 1) .. " to advance.")
	end
	return false, current
end

function grug_jobs.can_craft_recipe(player, recipe)
	if type(recipe) ~= "table" or not grug_jobs.has(player, recipe.profession) then
		return false, "Learn " ..
			(recipe and grug_jobs.PROFESSIONS[recipe.profession] and
			grug_jobs.PROFESSIONS[recipe.profession].name or "the profession") ..
			" at a trainer."
	end
	local level = grug_jobs.profession_level(player, recipe.profession)
	if level < recipe.tier then
		return false, grug_jobs.PROFESSIONS[recipe.profession].name ..
			" tier " .. recipe.tier .. " required."
	end
	local handler = grug_jobs.station_handler(recipe.station)
	if handler and handler.can_use then
		local allowed, reason = handler.can_use(player, recipe)
		if not allowed then return false, reason or "The station refused this recipe." end
	end
	return true
end

grug_jobs.PRIMARY_SLOTS = PRIMARY_SLOTS
