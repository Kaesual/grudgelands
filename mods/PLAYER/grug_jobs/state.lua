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

-- `quiet` (Round 45, lane ST: Cooking learned at join) skips the chat line,
-- the sound and the page refresh.
function grug_jobs.learn(player, profession, quiet)
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
	local text = "Learned " .. definition.name .. "."
	if quiet then return true, text end
	message(player, text)
	grug_sounds.play("profession_learned", player)
	if grug_inventory and grug_inventory.refresh then grug_inventory.refresh(player, true) end
	return true, text
end

function grug_jobs.unlearn(player, profession)
	local definition = grug_jobs.PROFESSIONS[profession]
	if not definition or not grug_jobs.has(player, profession) then
		return false, "You do not know that profession."
	end
	if definition.class ~= "primary" then
		return false, definition.name .. " cannot be unlearned."
	end
	local meta = player:get_meta()
	for slot = 1, PRIMARY_SLOTS do
		local key = META_PRIMARY .. slot
		if meta:get_string(key) == profession then set_string(meta, key, "") end
	end
	set_int(meta, META_LEVEL .. profession, 0)
	set_int(meta, META_CRAFTS .. profession, 0)
	-- A running job of this profession finishes without XP (lane JB).
	if grug_jobs.forfeit_job_xp then grug_jobs.forfeit_job_xp(player, profession) end
	-- An item left in the enchant/upgrade slot comes back (lane EU).
	if grug_jobs.return_operation_target then grug_jobs.return_operation_target(player) end
	local text = "Unlearned " .. definition.name .. "; its progression was lost."
	message(player, text)
	if grug_inventory and grug_inventory.refresh then grug_inventory.refresh(player, true) end
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

-- `crafts` crafts of `tier` at once (a job, lane JB): each counts while the
-- tier's threshold is not reached, so the XP is min(crafts, XP left in the
-- tier) (spec §2.22); a saturated profession advances at the first counted
-- craft once the character's level band allows it. Returns whether it
-- advanced, the level and the XP gained.
local function record_craft(player, profession, tier, crafts)
	if not grug_jobs.has(player, profession) then return false, 0, 0 end
	local current = grug_jobs.profession_level(player, profession)
	local meta = player:get_meta()
	if tier ~= current or current >= 6 then
		return false, current, 0
	end
	local threshold = grug_jobs.CRAFTS_TO_ADVANCE[current]
	local count = math.min(threshold,
		math.max(0, meta:get_int(META_CRAFTS .. profession)))
	-- A capped threshold stays saturated. Entering the next character band does
	-- not advance automatically; the next successful current-tier craft does.
	local gained = math.min(math.max(1, crafts or 1), threshold - count)
	count = count + gained
	if gained > 0 then set_int(meta, META_CRAFTS .. profession, count) end
	if count >= threshold and grug_jobs.character_tier(player) > current then
		set_int(meta, META_LEVEL .. profession, current + 1)
		set_int(meta, META_CRAFTS .. profession, 0)
		message(player, grug_jobs.PROFESSIONS[profession].name ..
			" advanced to tier " .. (current + 1) .. ".")
		return true, current + 1, gained
	elseif count >= threshold and gained > 0 then
		message(player, grug_jobs.PROFESSIONS[profession].name ..
			" tier progress is ready; craft once more at character level " ..
			(current * 10 + 1) .. " to advance.")
	end
	return false, current, gained
end

-- A counted craft plays the tier sound when the profession advanced. The
-- overview on the Crafting tab follows with the job's end resend (ui.lua).
function grug_jobs.record_craft(player, profession, tier, crafts)
	local advanced, level, gained = record_craft(player, profession, tier, crafts)
	if advanced then grug_sounds.play("profession_tier", player) end
	return advanced, level, gained
end

-- The one place a finished craft or station operation awards progress (Round
-- 33): only a recipe flagged `progress` counts (registry.lua: end products,
-- never stations, intermediates or automatic finishes). Station operations
-- (enchants; profession upgrades join them) are flagged when they register.
local award_callbacks = {}

-- Every finished craft passes award_progress, so its sound plays there
-- (Round 34): station operations by kind, cooking, alchemy and the two smiths
-- by profession, everything else the plain craft. A recipe made at a station
-- with a sound has none at the end: the station played it at the start
-- (Round 45 PT8, station_sounds.lua); enchants and upgrades keep theirs.
local CRAFT_SOUNDS = {enchant = "enchant", upgrade = "upgrade", cooking = "craft_cooking",
	alchemist = "craft_alchemy", weaponsmith = "craft_smithy", armorsmith = "craft_smithy"}
local function craft_sound(recipe)
	if recipe.operation then return CRAFT_SOUNDS[recipe.operation] or "craft" end
	local station_sounds = grug_jobs.STATION_SOUNDS
	if recipe.station and station_sounds and station_sounds[recipe.station] then return nil end
	return CRAFT_SOUNDS[recipe.profession or ""] or "craft"
end

-- A product taken out of a furnace (workspaces.lua, which finishes without
-- award_progress): the cooking cue for a dish a raw assembly cooks into
-- (grug_cooking.RAW_ASSEMBLIES), so smelting and the plain refinements stay
-- silent. Nil for anything else.
local finished_dishes
function grug_jobs.furnace_take_sound(stack)
	if not finished_dishes then
		finished_dishes = {}
		local cooking = rawget(_G, "grug_cooking")
		for _, row in ipairs(cooking and cooking.RAW_ASSEMBLIES or {}) do
			finished_dishes[row.output] = true
		end
	end
	return finished_dishes[ItemStack(stack):get_name()] and "craft_cooking" or nil
end

-- fn(player, recipe, items) after every finished craft award_progress counts
-- (grug_achievements counts dishes and potions from it): `items` is the
-- number of items the craft or job made.
function grug_jobs.register_on_award_progress(fn)
	award_callbacks[#award_callbacks + 1] = fn
end

-- One finished craft, or a finished job of `crafts` crafts (lane JB): the
-- sound once, the XP of record_craft (none with `no_xp`: the profession was
-- unlearned while the job ran), the callbacks with the items made. Returns
-- whether the profession advanced, its level and the XP gained.
function grug_jobs.award_progress(player, recipe, crafts, no_xp)
	if type(recipe) ~= "table" then return false end
	crafts = crafts or 1
	local sound = craft_sound(recipe)
	if sound then grug_sounds.play(sound, player) end
	if not recipe.progress then return false end
	local advanced, level, gained = false, nil, 0
	if not no_xp then
		advanced, level, gained = grug_jobs.record_craft(player, recipe.profession,
			recipe.tier, crafts)
	end
	for index = 1, #award_callbacks do
		award_callbacks[index](player, recipe, crafts * (recipe.count or 1))
	end
	return advanced, level, gained
end

-- Whether the player's professions allow a recipe or station operation: a
-- Basic recipe always, a profession one when the profession is learned at
-- the recipe's tier or higher (spec §2.34: profession tier = item tier). The
-- station nearby is the job start's check (lane JB).
function grug_jobs.can_craft_recipe(player, recipe)
	if type(recipe) == "table" and recipe.area == "basic" then return true end
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
	return true
end

grug_jobs.PRIMARY_SLOTS = PRIMARY_SLOTS
