-- /prof, the debug/admin command for professions: show, set, learn and
-- unlearn an online player's professions by name. The tier is capped at the
-- character's band (state.lua `admin_set`); the target gets one chat line.

local USAGE = "Usage: /prof <player> | /prof set <player> <1|2> <profession> <tier>" ..
	" | /prof set <player> <cooking|alchemy> <tier> | /prof clear <player> <1|2>" ..
	" | /prof learn <player> <profession> [tier] | /prof unlearn <player> <profession>"

-- A profession by its key or its name ("alchemist" or "Alchemy").
local function find_profession(word)
	word = word:lower()
	if grug_jobs.PROFESSIONS[word] then return word end
	for key, definition in pairs(grug_jobs.PROFESSIONS) do
		if definition.name:lower() == word then return key end
	end
end

local function parse_tier(word)
	local tier = tonumber(word and word:match("^[Tt]?(%d)$"))
	if tier and tier >= 1 and tier <= 6 then return tier end
end

local function parse_slot(word)
	local slot = tonumber(word and word:match("^(%d)$"))
	if slot and slot >= 1 and slot <= grug_jobs.PRIMARY_SLOTS then return slot end
end

local function profession_name(profession)
	return grug_jobs.PROFESSIONS[profession].name
end

-- "Weaponsmith T2 (crafts 3/15)"; the last tier has no threshold.
local function tier_text(player, profession)
	local tier = grug_jobs.profession_level(player, profession)
	local threshold = grug_jobs.CRAFTS_TO_ADVANCE[tier]
	return ("%s T%d (crafts %s)"):format(profession_name(profession), tier,
		threshold and (grug_jobs.crafts_in_tier(player, profession) .. "/" .. threshold)
		or "max")
end

local function show(target, target_name)
	local parts = {}
	for slot = 1, grug_jobs.PRIMARY_SLOTS do
		local profession = grug_jobs.primary_at(target, slot)
		parts[#parts + 1] = "slot " .. slot .. " " ..
			(profession and tier_text(target, profession) or "empty")
	end
	for _, profession in ipairs(grug_jobs.SECONDARY_PROFESSIONS) do
		parts[#parts + 1] = grug_jobs.has(target, profession) and
			tier_text(target, profession) or (profession_name(profession) .. " not learned")
	end
	return ("%s, character level %d (eligible up to T%d): %s."):format(target_name,
		grug_xp.get_level(target), grug_jobs.character_tier(target),
		table.concat(parts, ", "))
end

-- The sentence after a capped grant.
local function cap_note(target, target_name, asked, granted)
	if granted >= asked then return "" end
	return (" Asked for T%d; %s is only eligible for T%d (character level %d).")
		:format(asked, target_name, granted, grug_xp.get_level(target))
end

-- Each returns ok, the admin's text and the target's line (nil: none).
local function set(target, target_name, words)
	local slot, profession, tier
	if #words == 5 then
		slot, profession, tier = parse_slot(words[3]), find_profession(words[4]),
			parse_tier(words[5])
		if not slot then return false, "Slot must be 1 or 2." end
	elseif #words == 4 then
		profession, tier = find_profession(words[3]), parse_tier(words[4])
	else
		return false, USAGE
	end
	if not profession then return false, "Unknown profession." end
	if not tier then return false, "Tier must be 1 to 6 (or T1 to T6)." end
	local ok, granted = grug_jobs.admin_set(target, profession, tier, slot)
	if not ok then return false, granted end
	local name = profession_name(profession)
	local what = slot and ("slot " .. slot .. " to " .. name) or name
	return true, ("%s: set %s T%d.%s"):format(target_name, what, granted,
		cap_note(target, target_name, tier, granted)),
		("An admin set %s%s tier %d."):format(what, slot and "" or " to", granted)
end

local function clear(target, target_name, words)
	local slot = #words == 3 and parse_slot(words[3])
	if not slot then return false, "Usage: /prof clear <player> <1|2>" end
	local profession = grug_jobs.primary_at(target, slot)
	if not profession then return false, target_name .. ": slot " .. slot .. " is empty." end
	grug_jobs.admin_unlearn(target, profession)
	return true, ("%s: cleared slot %d (%s)."):format(target_name, slot,
		profession_name(profession)),
		("An admin removed %s; its progression was lost."):format(profession_name(profession))
end

local function learn(target, target_name, words)
	if #words ~= 3 and #words ~= 4 then
		return false, "Usage: /prof learn <player> <profession> [tier]"
	end
	local profession = find_profession(words[3])
	if not profession then return false, "Unknown profession." end
	local tier = 1
	if words[4] then
		tier = parse_tier(words[4])
		if not tier then return false, "Tier must be 1 to 6 (or T1 to T6)." end
	end
	if grug_jobs.has(target, profession) then
		return false, ("%s already knows %s; use /prof set."):format(target_name,
			tier_text(target, profession))
	end
	local slot
	if grug_jobs.PROFESSIONS[profession].class == "primary" then
		for index = 1, grug_jobs.PRIMARY_SLOTS do
			if not grug_jobs.primary_at(target, index) then slot = index break end
		end
		if not slot then
			return false, target_name .. " has both primary slots taken; " ..
				"use /prof set or /prof clear."
		end
	end
	local ok, granted = grug_jobs.admin_set(target, profession, tier, slot)
	if not ok then return false, granted end
	return true, ("%s: learned %s T%d%s.%s"):format(target_name, profession_name(profession),
		granted, slot and (" in slot " .. slot) or "", cap_note(target, target_name, tier, granted)),
		("An admin taught you %s (tier %d)."):format(profession_name(profession), granted)
end

local function unlearn(target, target_name, words)
	local profession = #words == 3 and find_profession(words[3])
	if not profession then return false, "Usage: /prof unlearn <player> <profession>" end
	if not grug_jobs.admin_unlearn(target, profession) then
		return false, ("%s does not know %s."):format(target_name, profession_name(profession))
	end
	local text = ("%s: unlearned %s."):format(target_name, profession_name(profession))
	if profession == "cooking" then text = text .. " Cooking is learned again at the next join." end
	return true, text,
		("An admin removed %s; its progression was lost."):format(profession_name(profession))
end

local ACTIONS = {set = set, clear = clear, learn = learn, unlearn = unlearn}

core.register_chatcommand("prof", {
	params = "<player> | set|clear|learn|unlearn <player> ...",
	description = "Show or set an online player's professions (debug)",
	privs = {server = true},
	func = function(name, param)
		local words = {}
		for word in param:gmatch("%S+") do words[#words + 1] = word end
		if #words == 1 then
			local target = core.get_player_by_name(words[1])
			if not target then return false, "Player is not online: " .. words[1] end
			return true, show(target, words[1])
		end
		local action = ACTIONS[(words[1] or ""):lower()]
		if not action or not words[2] then return false, USAGE end
		local target = core.get_player_by_name(words[2])
		if not target then return false, "Player is not online: " .. words[2] end
		local ok, text, notice = action(target, words[2], words)
		if ok then
			core.log("action", ("[grug_jobs] %s ran /prof %s: %s"):format(name, param, text))
			if notice and words[2] ~= name then core.chat_send_player(words[2], notice) end
		end
		return ok, text
	end,
})
