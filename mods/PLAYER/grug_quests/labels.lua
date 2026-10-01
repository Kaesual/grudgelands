-- How an objective reads in the dialogue, the quest log, the HUD tracker and
-- the message feed. Item names come from grug_core.item_name (never the
-- tooltip); text is plain (translation escapes resolved).
local Q = grug_quests
local plain = grug_core.plain_text

local function title_case(text)
	return (text:gsub("_", " "):gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end

local function mob_label(name)
	local def = core.registered_entities[name]
	local label = def and def.description
	if not label or label == "" then label = title_case(name:match("[^:]+$") or name) end
	return plain(label)
end

-- The short subject: "Wood Axe", "Any Tree", "Small Boar or Large Rat",
-- "Elder Maren".
function Q.objective_subject(objective)
	if objective.type == "item" then
		if objective.item then return grug_core.item_name(objective.item) end
		return "Any " .. title_case(objective.group)
	end
	if objective.type == "talk" then
		local npc = Q.registered_npcs[objective.npc]
		return npc and npc.title or tostring(objective.npc)
	end
	local names = {}
	for _, name in ipairs(objective.mobs or {}) do names[#names + 1] = mob_label(name) end
	return table.concat(names, " or ")
end

-- The task: "Bring Wood Axe", "Defeat Small Boar", "Travel to Elder Maren".
function Q.objective_action(objective)
	local verb = objective.type == "item" and "Bring " or
		(objective.type == "talk" and "Travel to " or "Defeat ")
	return verb .. Q.objective_subject(objective)
end

-- A repeatable's cooldown in words: "30 min", "2 h", "1 h 30 min".
function Q.cooldown_text(seconds)
	local minutes = math.ceil(seconds / 60)
	local hours = math.floor(minutes / 60)
	minutes = minutes - hours * 60
	if hours == 0 then return minutes .. " min" end
	if minutes == 0 then return hours .. " h" end
	return ("%d h %d min"):format(hours, minutes)
end
