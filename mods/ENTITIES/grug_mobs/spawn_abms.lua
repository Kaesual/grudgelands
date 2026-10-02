--
-- Spawn ABMs: retired and merged rows (Round 30 P2, the user's ruling on perf
-- review 2026-10 #11, round30-plan.md §1).
--
-- mobs_redo registers one ABM per spawn row (mobs:spawn). With 88 rows the
-- engine scanned an active block for some spawn ABM nearly every second: each
-- ABM keeps its own timer, and a block is scanned whenever any ABM whose
-- nodes it holds is due (src/server/blockmodifier.cpp ABMHandler). The rows
-- now go through mobs.register_spawn_abm (a GRUG PATCH in mobs/api.lua):
--
--   * a surface row no zone can use any more is retired
--     (spawn_policy.lua grug_mobs.spawn_row_kept): the spawn regions own the
--     surface of every recipe zone;
--   * every other row joins one merged ABM per node set: "underground"
--     (stone and strata, y <= -40), "water" (water sources: Kraken, Reed
--     Angelfish) and "surface" (the recipes' critters and the Rift Spawn's
--     surface row). A merged ABM's nodes and neighbours are the union of its
--     rows', its y range their hull, its interval their shortest one, and its
--     chance the largest that still lets every row keep its own rate.
--
-- The dispatcher keeps each row's semantics: a triggered node runs a row only
-- when the node is one of the row's own nodes, lies in the row's y range and
-- has one of the row's own neighbours (checked only where the row's list is
-- narrower than the group's), and with the probability that turns the
-- merged trigger rate into the row's own: a row of chance c and interval i
-- fires per node with rate 1 / (c x i); the merged ABM triggers with rate
-- 1 / (C x I), so the row runs with p = C x I / (c x i) <= 1. Everything after
-- the trigger (the per-row light, height, cap, player and policy checks of
-- mobs_redo's spawn_action) is the row's own unchanged code.
--

local random = math.random

-- mob name -> number of retired rows, for the boot log.
local retired = {}
local retired_count = 0
local groups = {} -- group name -> {rows = {...}}
local finalized = false

local function group_of(spec)
	if spec.max_y <= -40 then
		return "underground"
	end
	for _, node in ipairs(spec.nodenames) do
		if node == "default:water_source" then
			return "water"
		end
	end
	return "surface"
end

local function as_list(value)
	if type(value) == "table" then
		return value
	end
	return {value}
end

function mobs.register_spawn_abm(spec, name)
	if finalized then
		error("[grug_mobs] spawn row registered after the spawn ABMs were " ..
			"merged: " .. tostring(name))
	end
	if not grug_mobs.spawn_row_kept(name, spec.max_y) then
		retired[name] = (retired[name] or 0) + 1
		retired_count = retired_count + 1
		return
	end
	local group_name = group_of(spec)
	local group = groups[group_name]
	if not group then
		group = {rows = {}}
		groups[group_name] = group
	end
	local nodes = as_list(spec.nodenames)
	local row = {
		mob = name,
		nodes = nodes,
		neighbors = spec.neighbors and as_list(spec.neighbors) or nil,
		interval = spec.interval,
		chance = spec.chance,
		min_y = spec.min_y,
		max_y = spec.max_y,
		action = spec.action,
	}
	-- Node membership: exact names, and groups resolved per node name.
	row.names, row.node_groups = {}, {}
	for _, node in ipairs(nodes) do
		local group_key = node:match("^group:(.+)$")
		if group_key then
			row.node_groups[#row.node_groups + 1] = group_key
		else
			row.names[node] = true
		end
	end
	group.rows[#group.rows + 1] = row
end

local function row_hosts(row, node_name)
	if row.names[node_name] then
		return true
	end
	for i = 1, #row.node_groups do
		if core.get_item_group(node_name, row.node_groups[i]) > 0 then
			return true
		end
	end
	return false
end

local function add_unique(list, seen, values)
	for _, value in ipairs(values or {}) do
		if not seen[value] then
			seen[value] = true
			list[#list + 1] = value
		end
	end
end

local function same_set(a, b_seen, b_count)
	if #a ~= b_count then
		return false
	end
	for _, value in ipairs(a) do
		if not b_seen[value] then
			return false
		end
	end
	return true
end

-- Pure: the merged ABM's interval and chance and each row's probability `p`.
-- Exposed for the portable test.
function grug_mobs.merge_spawn_rates(rows)
	local interval
	for _, row in ipairs(rows) do
		if not interval or row.interval < interval then
			interval = row.interval
		end
	end
	local chance
	for _, row in ipairs(rows) do
		local fit = row.chance * row.interval / interval
		if not chance or fit < chance then
			chance = fit
		end
	end
	chance = math.max(1, math.floor(chance))
	for _, row in ipairs(rows) do
		row.p = math.min(1, chance * interval / (row.chance * row.interval))
	end
	return interval, chance
end

local function register_group(group_name, group)
	local rows = group.rows
	local nodes, nodes_seen = {}, {}
	local neighbors, neighbors_seen = {}, {}
	local any_without_neighbors = false
	local min_y, max_y
	for _, row in ipairs(rows) do
		add_unique(nodes, nodes_seen, row.nodes)
		if row.neighbors then
			add_unique(neighbors, neighbors_seen, row.neighbors)
		else
			any_without_neighbors = true
		end
		min_y = math.min(min_y or row.min_y, row.min_y)
		max_y = math.max(max_y or row.max_y, row.max_y)
	end
	if any_without_neighbors then
		-- One row needs no neighbour: the group checks none, each row its own.
		neighbors, neighbors_seen = nil, {}
	end
	local count = 0
	for _ in pairs(neighbors_seen) do count = count + 1 end
	for _, row in ipairs(rows) do
		row.check_neighbors = row.neighbors ~= nil and
			not same_set(row.neighbors, neighbors_seen, count)
	end
	local interval, chance = grug_mobs.merge_spawn_rates(rows)
	-- node name -> the rows hosted there, built on first sight of the node.
	local by_node = {}
	local function rows_for(node_name)
		local list = by_node[node_name]
		if not list then
			list = {}
			for _, row in ipairs(rows) do
				if row_hosts(row, node_name) then
					list[#list + 1] = row
				end
			end
			by_node[node_name] = list
		end
		return list
	end
	core.register_abm({
		label = "grug_mobs " .. group_name .. " spawning",
		nodenames = nodes,
		neighbors = neighbors,
		interval = interval,
		chance = chance,
		catch_up = false,
		min_y = min_y, max_y = max_y,
		action = function(pos, node, active_object_count, active_object_count_wider)
			local list = rows_for(node.name)
			local y = pos.y
			for i = 1, #list do
				local row = list[i]
				if y >= row.min_y and y <= row.max_y
						and (row.p >= 1 or random() < row.p)
						and (not row.check_neighbors or
							core.find_node_near(pos, 1, row.neighbors)) then
					-- spawn_action moves its position: each row its own copy.
					row.action({x = pos.x, y = y, z = pos.z}, node,
						active_object_count, active_object_count_wider)
				end
			end
		end,
	})
	core.log("action", ("[grug_mobs] spawn ABM %s: %d rows, interval %s, " ..
		"chance %d"):format(group_name, #rows, tostring(interval), chance))
end

core.register_on_mods_loaded(function()
	finalized = true
	local names = {}
	for group_name in pairs(groups) do names[#names + 1] = group_name end
	table.sort(names)
	for _, group_name in ipairs(names) do
		register_group(group_name, groups[group_name])
	end
	local mobs_retired = {}
	for name in pairs(retired) do mobs_retired[#mobs_retired + 1] = name end
	table.sort(mobs_retired)
	core.log("action", ("[grug_mobs] %d surface spawn rows retired (spawn " ..
		"regions): %s"):format(retired_count, table.concat(mobs_retired, ", ")))
end)
