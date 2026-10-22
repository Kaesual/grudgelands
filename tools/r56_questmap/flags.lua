-- Round 56 lane QUESTMAP: what the quest rework needs to see, per quest.
--
--   local F = dofile(REPO .. "/tools/r56_questmap/flags.lua")
--   local facts = F.analyse(model.quests, model.zones)
--
-- `quests` are model.lua's rows (id, zone, requires, objectives with type,
-- item, group, roles, object; rewards.items); `zones` give level_min (a start
-- zone's band starts at 1). Returns {by_id = {id -> facts}, families =
-- {key -> {ids}}, limits = F.LIMITS}; a quest's facts:
--   ancestors   every quest it needs, directly or through another (count)
--   depth       the longest prerequisite path ending at it (itself 1)
--   unlocks     quests that name it in `requires`, as a list of ids
--   kill_chain  the longest run of kill-only quests, one requiring the next,
--               through it (0 when it is no kill-only quest)
--   family      its objective signature (objective types and targets;
--               counts, areas and levels ignored), false for a travel quest
--   family_zones / family_starts  zones / start zones with that signature
--   reward_items  reward item ids that an item objective also requests
--   flags       the names below that hold
-- Flags:
--   start_twin       the same signature in two or more start zones
--   repeated         the same signature in two or more zones
--   reward_is_request a reward item is also a requested item
--   kill_chain       kill_chain >= LIMITS.kill_chain
--   deep             ancestors >= LIMITS.ancestors
-- Plain Lua 5.1.
local F = {}

-- Rough marks, not rules: a run of four kill quests in a row; ten quests
-- before a quest opens.
F.LIMITS = {kill_chain = 4, ancestors = 10}

local function target_key(objective)
	if objective.type == "item" then
		return objective.item or ("group:" .. tostring(objective.group))
	elseif objective.type == "kill" then
		local roles = {}
		for i, role in ipairs(objective.roles or {}) do roles[i] = role end
		table.sort(roles)
		return table.concat(roles, "+")
	elseif objective.type == "use" then
		return objective.object
	end
	return objective.npc
end

-- The signature of a quest: its objectives' "type:target", sorted; a travel
-- quest (talk only) has none, as every handoff would match every other.
function F.signature(quest)
	local parts, talk_only = {}, true
	for i, objective in ipairs(quest.objectives) do
		parts[i] = objective.type .. ":" .. tostring(target_key(objective))
		if objective.type ~= "talk" then talk_only = false end
	end
	if talk_only then return false end
	table.sort(parts)
	return table.concat(parts, " ")
end

local function kill_only(quest)
	for _, objective in ipairs(quest.objectives) do
		if objective.type ~= "kill" then return false end
	end
	return #quest.objectives > 0
end

function F.analyse(quests, zones)
	local by_id, start_zone, children = {}, {}, {}
	for _, zone in ipairs(zones or {}) do start_zone[zone.id] = zone.level_min == 1 end
	for _, quest in ipairs(quests) do
		by_id[quest.id] = quest
		children[quest.id] = {}
	end
	for _, quest in ipairs(quests) do
		for _, prior in ipairs(quest.requires) do
			if children[prior] then table.insert(children[prior], quest.id) end
		end
	end

	-- Ancestors and depth (validate.lua refuses cycles; `seen` guards anyway).
	local ancestors, depth = {}, {}
	local function walk(id, seen)
		if ancestors[id] then return ancestors[id] end
		seen = seen or {}
		if seen[id] then return {} end
		seen[id] = true
		local set, deepest = {}, 0
		for _, prior in ipairs(by_id[id] and by_id[id].requires or {}) do
			if by_id[prior] then
				set[prior] = true
				for other in pairs(walk(prior, seen)) do set[other] = true end
				deepest = math.max(deepest, depth[prior] or 0)
			end
		end
		ancestors[id], depth[id] = set, deepest + 1
		return set
	end

	-- Kill-only runs: up = longest run ending here, down = starting here.
	local up, down = {}, {}
	local function run_up(id)
		if up[id] == nil then
			up[id] = 0
			if kill_only(by_id[id]) then
				local best = 0
				for _, prior in ipairs(by_id[id].requires) do
					if by_id[prior] then best = math.max(best, run_up(prior)) end
				end
				up[id] = best + 1
			end
		end
		return up[id]
	end
	local function run_down(id)
		if down[id] == nil then
			down[id] = 0
			if kill_only(by_id[id]) then
				local best = 0
				for _, child in ipairs(children[id]) do best = math.max(best, run_down(child)) end
				down[id] = best + 1
			end
		end
		return down[id]
	end

	-- Families: one signature across zones.
	local families, family_zones, family_starts = {}, {}, {}
	for _, quest in ipairs(quests) do
		local key = F.signature(quest)
		if key then
			families[key] = families[key] or {}
			table.insert(families[key], quest.id)
			family_zones[key] = family_zones[key] or {}
			family_zones[key][quest.zone] = true
		end
	end
	local function count(set, only)
		local n = 0
		for zone in pairs(set) do
			if not only or only[zone] then n = n + 1 end
		end
		return n
	end
	for key, set in pairs(family_zones) do
		family_starts[key] = count(set, start_zone)
		family_zones[key] = count(set)
	end

	local out = {}
	for _, quest in ipairs(quests) do
		local id = quest.id
		local n = 0
		for _ in pairs(walk(id)) do n = n + 1 end
		local key = F.signature(quest)
		local requested = {}
		for _, objective in ipairs(quest.objectives) do
			if objective.type == "item" and objective.item then requested[objective.item] = true end
		end
		local reward_items = {}
		for _, reward in ipairs(quest.rewards.items or {}) do
			if requested[reward.item] then reward_items[#reward_items + 1] = reward.item end
		end
		local chain = kill_only(quest) and (run_up(id) + run_down(id) - 1) or 0
		local facts = {
			ancestors = n, depth = depth[id], unlocks = children[id], kill_chain = chain,
			family = key, family_zones = key and family_zones[key] or 0,
			family_starts = key and family_starts[key] or 0,
			reward_items = reward_items, flags = {},
		}
		local function flag(ok, name)
			if ok then facts.flags[#facts.flags + 1] = name end
		end
		flag(start_zone[quest.zone] and facts.family_starts >= 2, "start_twin")
		flag(facts.family_zones >= 2, "repeated")
		flag(#reward_items > 0, "reward_is_request")
		flag(chain >= F.LIMITS.kill_chain, "kill_chain")
		flag(n >= F.LIMITS.ancestors, "deep")
		out[id] = facts
	end
	return {by_id = out, families = families, limits = F.LIMITS}
end

return F
