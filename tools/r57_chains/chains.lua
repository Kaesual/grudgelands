-- Round 57 lane CHAINDEPTH: the recipe chain walk (round57-plan.md ruling 8,
-- the basis of ruling 6's recursive Basic unlock). Pure Lua 5.1: no engine
-- call, no global; the contract is in tools/r57_chains/README.md.
--
--   local chains = dofile(ROOT .. "/tools/r57_chains/chains.lua")
--   local result = chains.analyse(steps, members)
--
-- `steps` is a list of crafted steps:
--   {id = <unique string>, output = <item>, count = <n made>,
--    ingredients = {{item = <item>, n = <n>} | {group = <name>, n = <n>}, ...},
--    basic = <true for a Basic recipe>}
-- `members` maps a group name (no "group:" prefix) to its item names.
--
-- An item is raw when no step makes it. A step's depth is 1 + the deepest
-- of its ingredients (a raw item is 0); an item's depth is its shallowest
-- step's; a group ingredient is its cheapest member. Loops are broken by
-- chains.RULES, in order, before the depths are taken (see README).
local chains = {}

local INF = math.huge

chains.RULES = {
	{id = "unpack", text = "a step that splits one item into several of another " ..
		"(1 block into 9 bars, 1 sandstone into 4 sand) never counts as a source " ..
		"inside a loop: the loop's base item is what the block is packed from"},
	{id = "cut_back", text = "a step that turns a product back into its own " ..
		"ingredient never counts as a source: its one ingredient is made by a " ..
		"single step from this step's output alone (stair or slab back to its block)"},
	{id = "shallower", text = "an item takes its shallowest step; a loop step is " ..
		"always deeper than the step that enters the loop from outside, so it is " ..
		"never the source"},
	{id = "seed", text = "a loop that nothing outside feeds: its item used most " ..
		"often as a named ingredient outside the loop (then the first by name) " ..
		"counts as raw, and the walk repeats until no such loop is left"},
}

local function token(entry)
	return entry.group and ("group:" .. entry.group) or entry.item
end
chains.token = token

local function sorted_keys(set)
	local list = {}
	for key in pairs(set) do list[#list + 1] = key end
	table.sort(list)
	return list
end

-- The item names a step's ingredient may be: the item, or the group's members.
local function candidates(entry, members)
	if entry.item then return {entry.item} end
	return members[entry.group] or {}
end

-- Strongly connected components of the item graph (an edge from each output
-- to each item its steps may consume), over the steps `usable` allows. Only
-- components with a loop are returned, each as {items = sorted list, set}.
local function loops(steps, usable, members)
	local edges = {}
	for _, step in ipairs(steps) do
		if usable[step.id] then
			local list = edges[step.output] or {}
			edges[step.output] = list
			for _, entry in ipairs(step.ingredients) do
				for _, name in ipairs(candidates(entry, members)) do list[#list + 1] = name end
			end
		end
	end
	local index, low, on_stack, stack, counter, result = {}, {}, {}, {}, 0, {}
	local function connect(node)
		counter = counter + 1
		index[node], low[node] = counter, counter
		stack[#stack + 1], on_stack[node] = node, true
		for _, next_node in ipairs(edges[node] or {}) do
			if not index[next_node] then
				connect(next_node)
				if low[next_node] < low[node] then low[node] = low[next_node] end
			elseif on_stack[next_node] and index[next_node] < low[node] then
				low[node] = index[next_node]
			end
		end
		if low[node] == index[node] then
			local set, size, self_loop = {}, 0, false
			repeat
				local member = table.remove(stack)
				on_stack[member] = nil
				set[member], size = true, size + 1
			until member == node
			for _, next_node in ipairs(edges[node] or {}) do
				if next_node == node then self_loop = true end
			end
			if size > 1 or self_loop then
				result[#result + 1] = {items = sorted_keys(set), set = set}
			end
		end
	end
	for _, node in ipairs(sorted_keys(edges)) do
		if not index[node] then connect(node) end
	end
	return result
end

-- Whether a step consumes something of its own output's loop.
local function on_loop(step, loop, members)
	if not loop.set[step.output] then return false end
	for _, entry in ipairs(step.ingredients) do
		for _, name in ipairs(candidates(entry, members)) do
			if loop.set[name] then return true end
		end
	end
	return false
end

function chains.analyse(steps, members)
	members = members or {}
	local by_id, producers = {}, {}
	for _, step in ipairs(steps) do
		assert(type(step.id) == "string" and not by_id[step.id], "chains: step ids must be unique")
		by_id[step.id] = step
		producers[step.output] = producers[step.output] or {}
		table.insert(producers[step.output], step)
	end
	local usable, broken = {}, {}
	for _, step in ipairs(steps) do usable[step.id] = true end

	-- The loops of the full graph, the report's own section.
	local found = loops(steps, usable, members)
	local loop_of = {}
	for number, loop in ipairs(found) do
		for _, name in ipairs(loop.items) do loop_of[name] = number end
	end
	local function loop_step(step)
		local number = loop_of[step.output]
		return number and on_loop(step, found[number], members)
	end

	-- Rule unpack.
	for _, step in ipairs(steps) do
		local only = step.ingredients[1]
		if loop_step(step) and #step.ingredients == 1 and only.item and only.n == 1 and
				(step.count or 1) > 1 then
			usable[step.id], broken[step.id] = false, "unpack"
		end
	end
	-- Rule cut_back, on what unpack left.
	local cut = {}
	for _, step in ipairs(steps) do
		local only = step.ingredients[1]
		if usable[step.id] and loop_step(step) and #step.ingredients == 1 and only.item then
			local makers = {}
			for _, maker in ipairs(producers[only.item] or {}) do
				if usable[maker.id] then makers[#makers + 1] = maker end
			end
			local maker = makers[1]
			if #makers == 1 and #maker.ingredients == 1 and
					maker.ingredients[1].item == step.output then
				cut[#cut + 1] = step
			end
		end
	end
	for _, step in ipairs(cut) do usable[step.id], broken[step.id] = false, "cut_back" end

	-- The depths: a fixpoint over the usable steps (rule shallower), and
	-- rule seed for what stays unreachable.
	local seeded = {}
	local depth = {}
	local function raw(name)
		if seeded[name] then return true end
		for _, step in ipairs(producers[name] or {}) do
			if usable[step.id] then return false end
		end
		return true
	end
	local function entry_depth(entry)
		local best = INF
		for _, name in ipairs(candidates(entry, members)) do
			local value = depth[name]
			if value == nil then value = raw(name) and 0 or INF end
			if value < best then best = value end
		end
		-- A group without a member counts as raw (the registry refuses one).
		if entry.group and #candidates(entry, members) == 0 then best = 0 end
		return best
	end
	local function step_depth(step)
		local deepest = 0
		for _, entry in ipairs(step.ingredients) do
			local value = entry_depth(entry)
			if value > deepest then deepest = value end
		end
		return deepest + 1
	end
	local function settle()
		depth = {}
		for name in pairs(producers) do
			if raw(name) then depth[name] = 0 else depth[name] = INF end
		end
		local changed = true
		while changed do
			changed = false
			for _, step in ipairs(steps) do
				if usable[step.id] and not seeded[step.output] then
					local value = step_depth(step)
					if value < depth[step.output] then
						depth[step.output], changed = value, true
					end
				end
			end
		end
	end
	settle()
	while true do
		local stuck = {}
		for name, value in pairs(depth) do
			if value == INF then stuck[name] = true end
		end
		if next(stuck) == nil then break end
		-- The loops among the stuck items; seed one item in each.
		local stuck_steps = {}
		for _, step in ipairs(steps) do
			if usable[step.id] and stuck[step.output] then stuck_steps[step.id] = true end
		end
		local stuck_loops = loops(steps, stuck_steps, members)
		assert(#stuck_loops > 0, "chains: an unreachable item outside a loop")
		for _, loop in ipairs(stuck_loops) do
			local uses = {}
			for _, step in ipairs(steps) do
				if not loop.set[step.output] then
					for _, entry in ipairs(step.ingredients) do
						if entry.item and loop.set[entry.item] then
							uses[entry.item] = (uses[entry.item] or 0) + 1
						end
					end
				end
			end
			local best
			for _, name in ipairs(loop.items) do
				if not best or (uses[name] or 0) > (uses[best] or 0) then best = name end
			end
			seeded[best] = true
		end
		settle()
	end

	-- The trees, level by level: a step's ingredients are all shallower, so
	-- every item of a lower level has chosen its step before.
	local step_info, item_info, chosen_member = {}, {}, {}
	local by_level, top = {}, 0
	for _, step in ipairs(steps) do
		local value = step_depth(step)
		by_level[value] = by_level[value] or {}
		table.insert(by_level[value], step)
		if value > top then top = value end
	end
	for name, value in pairs(depth) do
		if value == 0 then item_info[name] = {depth = 0, tree = {}, size = 0} end
	end
	-- The member a group entry resolves to: the shallowest, then the fewest
	-- steps, then the first by name.
	local function resolve(entry)
		if entry.item then return entry.item end
		local key = entry.group
		if chosen_member[key] ~= nil then return chosen_member[key] or nil end
		local best, best_depth, best_size
		for _, name in ipairs(candidates(entry, members)) do
			local value = depth[name] or 0
			local size = item_info[name] and item_info[name].size or 0
			if not best or value < best_depth or (value == best_depth and
					(size < best_size or (size == best_size and name < best))) then
				best, best_depth, best_size = name, value, size
			end
		end
		chosen_member[key] = best or false
		return best
	end
	for level = 1, top do
		for _, step in ipairs(by_level[level] or {}) do
			local tree, size, chosen = {[step.id] = true}, 1, {}
			for index, entry in ipairs(step.ingredients) do
				local name = resolve(entry)
				chosen[index] = name
				local below = name and item_info[name]
				for id in pairs(below and below.tree or {}) do
					if not tree[id] then tree[id], size = true, size + 1 end
				end
			end
			step_info[step.id] = {depth = level, tree = tree, size = size, chosen = chosen}
		end
		-- Items of this depth take their usable step of this depth with the
		-- fewest steps, then the first by id.
		for _, step in ipairs(by_level[level] or {}) do
			local name = step.output
			if usable[step.id] and not seeded[name] and depth[name] == level then
				local info, best = step_info[step.id], item_info[name]
				if not best or info.size < best.size or
						(info.size == best.size and step.id < best.via) then
					item_info[name] = {depth = level, via = step.id, tree = info.tree,
						size = info.size}
				end
			end
		end
	end

	-- The result.
	local result = {steps = {}, items = {}, loops = {}, groups = {}, seeded = sorted_keys(seeded),
		by_id = by_id, members = members}
	for _, step in ipairs(steps) do
		local info = step_info[step.id]
		local basics = {}
		for id in pairs(info.tree) do
			if id ~= step.id and by_id[id].basic then basics[#basics + 1] = id end
		end
		table.sort(basics)
		local used = item_info[step.output] and item_info[step.output].via == step.id
		result.steps[step.id] = {depth = info.depth, steps = info.size, basics = basics,
			chosen = info.chosen, source = used or false,
			broken = broken[step.id], loop = loop_step(step) and true or false,
			alternatives = #producers[step.output]}
	end
	for name, value in pairs(depth) do
		local info = item_info[name]
		result.items[name] = {depth = value, raw = value == 0, seeded = seeded[name] or false,
			via = info and info.via, steps = info and info.size or 0,
			tree = info and info.tree or {}}
	end
	for key, name in pairs(chosen_member) do result.groups[key] = name end
	for _, loop in ipairs(found) do
		local list = {}
		for _, step in ipairs(steps) do
			if on_loop(step, loop, members) then
				local rule = broken[step.id]
				if not rule and seeded[step.output] then rule = "seed" end
				if not rule and not result.steps[step.id].source then rule = "shallower" end
				list[#list + 1] = {id = step.id, rule = rule}
			end
		end
		table.sort(list, function(a, b) return a.id < b.id end)
		local seeds = {}
		for _, name in ipairs(loop.items) do
			if seeded[name] then seeds[#seeds + 1] = name end
		end
		result.loops[#result.loops + 1] = {items = loop.items, steps = list, seeds = seeds}
	end
	-- Every step, deepest first, then the most steps, then by id.
	local order = {}
	for _, step in ipairs(steps) do order[#order + 1] = step.id end
	table.sort(order, function(a, b)
		local sa, sb = result.steps[a], result.steps[b]
		if sa.depth ~= sb.depth then return sa.depth > sb.depth end
		if sa.steps ~= sb.steps then return sa.steps > sb.steps end
		return a < b
	end)
	result.order = order
	return result
end

-- The longest chain of a step down to a raw item: a list of
-- {item = <name>, step = <id or nil>}, from the step's output to the raw end,
-- following the deepest ingredient (then the first by position).
function chains.path(result, step_id)
	local chain = {}
	local current = step_id
	while current do
		local step = result.by_id[current]
		chain[#chain + 1] = {item = step.output, step = current}
		local deepest, deepest_name = -1, nil
		for index in ipairs(step.ingredients) do
			local name = result.steps[current].chosen[index]
			local value = name and result.items[name] and result.items[name].depth or 0
			if value > deepest then deepest, deepest_name = value, name end
		end
		if not deepest_name then break end
		local item = result.items[deepest_name]
		if not item or item.raw or not item.via then
			chain[#chain + 1] = {item = deepest_name}
			break
		end
		current = item.via
	end
	return chain
end

-- What a list of ingredients costs (an enchant's or an upgrade's): the
-- deepest ingredient's depth (0 when all are raw), the distinct steps of
-- their trees, the Basic steps among them and the item each entry resolves
-- to (a group: its cheapest member, as in the walk).
function chains.consume(result, ingredients)
	local deepest, tree, size, chosen = 0, {}, 0, {}
	for index, entry in ipairs(ingredients) do
		local name = entry.item
		if not name then
			name = result.groups[entry.group]
			if name == nil then
				local best
				for _, member in ipairs(result.members[entry.group] or {}) do
					local value = result.items[member] and result.items[member].depth or 0
					local best_value = best and result.items[best] and result.items[best].depth or 0
					if not best or value < best_value or (value == best_value and member < best) then
						best = member
					end
				end
				name = best
			end
		end
		chosen[index] = name
		local item = name and result.items[name]
		if item then
			if item.depth > deepest then deepest = item.depth end
			for id in pairs(item.tree) do
				if not tree[id] then tree[id], size = true, size + 1 end
			end
		end
	end
	local basics = {}
	for id in pairs(tree) do
		if result.by_id[id].basic then basics[#basics + 1] = id end
	end
	table.sort(basics)
	return {depth = deepest, steps = size, basics = basics, chosen = chosen}
end

return chains
