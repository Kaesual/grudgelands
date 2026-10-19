-- The graph talent registry (Round 52 lane GRAPH, round52-class-plan.md §3
-- "GRAPH", rulings C6 and C12, decisions D3 and D4). It is built BESIDE
-- today's registry (talents.lua) and nothing live reads it in Round 52: only
-- the admin preview (talent_graph_ui.lua) and the fixtures do. Round K
-- switches the Talents page and the stored talents over to it, with an
-- automatic talent reset for every character.
--
-- A class has two trees; a tree is a graph of nodes. Each node has
--   * a GATE: the points already spent in its tree before its first rank,
--     one of GATE_ROWS (the page draws one row per gate);
--   * any number of PREREQUISITES (`requires`), each needing ONE rank -- not
--     a full chain as today's hard chain does;
--   * a TYPE: "modifier" or "window" (numbers on existing skills; a window
--     node opens a readiness window in round K), or "unlock", "transform" or
--     "ultimate", which grant the ability `ability` and have one rank. A
--     transform's ability carries the ability-side `transforms` field (D8);
--     this registry names the ability id only, never the old skill. The
--     ultimate is the tree's one granting node at ULTIMATE_GATE;
--   * EFFECTS as data, {key = {value per rank}}: a shared stat key, one of
--     its class's own keys (D4: each class registers its table, so the class
--     lanes of round K never edit one shared list), or a parametrised
--     modifier "<family>:<param>" (class-redesign/continuation.md §4 item 5)
--     whose param is a tag or ability id its class registered;
--   * `code` (the node list's id, F1 ... V14), `name`, `description`, and
--     `col` (its column on the page, 1..COLUMNS).
--
-- The gate rule, exact on both paths: a node's gate counts the ranks of the
-- tree's nodes with a LOWER gate. In a build bought in order that equals the
-- points spent in the tree whenever a gate refuses (every node of the gate
-- or above needs those points first), and on a stored string it rejects two
-- nodes of one gate that only "pay" for each other. The spend refusal and
-- the read path share structure_refusal, so both say the same text.
--
-- Points stay floor(level / 2), 30 at level 60 (talents.lua): an ultimate
-- costs 21 in its tree, so two cannot coexist and a mixed build may take
-- neither -- arithmetic, not a rule.

local graph = {}
grug_classes.graph = graph

-- The gates of the node list (class-redesign/node-list.md): levels 2, 6, 14,
-- 22, 26, 34 and 42 at the earliest. The page draws one row per gate.
graph.GATE_ROWS = {0, 2, 6, 10, 12, 16, 20}
graph.ULTIMATE_GATE = 20
-- The most points a character ever has (level 60).
graph.POINTS_MAX = 30
-- The page's node columns (d5-geometry: up to 5 columns of icons).
graph.COLUMNS = 5

local TYPES = {modifier = true, window = true, unlock = true, transform = true,
	ultimate = true}
local GRANTS = {unlock = true, transform = true, ultimate = true}

graph.trees = {}
graph.tree_ids = {} -- registration order
graph.nodes = {}
graph.node_ids = {} -- registration order: serialisation, refunds, field names
graph.codes = {} -- node-list code -> node

--
-- The key vocabulary (D4). Shared stat keys keep today's names, units and
-- consumers (talents.lua EFFECT_KEYS); the families are the data-driven
-- modifiers, read in round K by one ability-parameter pipeline.
--
graph.SHARED_KEYS = {
	armor_percent_add = "% of armor_k (grug_quality raw armor)",
	max_hp_percent_add = "% of the class pool (stats.lua get_max_hp)",
	max_mana_percent_add = "% of the pool (stats.lua get_max_mana)",
	crit_chance_add = "percentage points (stats.lua get_crit_chance)",
	dodge_chance_add = "percentage points (stats.lua dodge)",
}
graph.KEY_FAMILIES = {
	damage_pct = "% of the untalented damage of the skills the param names",
	cost_pct = "% change of their cost (negative is cheaper)",
	cooldown_sub = "seconds off their cooldown",
	radius_add = "metres on their radius",
	duration_add = "seconds on their duration",
	range_add = "metres on their range",
}
local class_keys = {} -- class id -> {key = consumer}
local class_params = {} -- class id -> {param = true}

-- D4: a class's own keys (`keys`, {key = "the consumer that reads it"}) and
-- the params its family keys may name (`params`: tags such as "fire" or
-- "paid", and ability ids). Called once per class; round K's class files
-- each call it for their own class.
function graph.register_class_vocabulary(class_id, def)
	assert(grug_classes.registered_classes[class_id],
		"vocabulary for an unknown class " .. tostring(class_id))
	assert(not class_keys[class_id], "duplicate vocabulary for " .. class_id)
	class_keys[class_id] = {}
	class_params[class_id] = {}
	for key, consumer in pairs(def.keys or {}) do
		assert(not graph.SHARED_KEYS[key] and not key:find(":", 1, true),
			"class key " .. key .. " clashes with a shared key or a family")
		assert(type(consumer) == "string", "class key " .. key .. " names no consumer")
		class_keys[class_id][key] = consumer
	end
	for _, param in ipairs(def.params or {}) do
		assert(param:match("^[a-z][a-z0-9_]*$"), "bad param " .. tostring(param))
		class_params[class_id][param] = true
	end
end

-- Whether `key` is in the vocabulary of `class_id`.
function graph.valid_key(class_id, key)
	if graph.SHARED_KEYS[key] or (class_keys[class_id] or {})[key] then
		return true
	end
	local family, param = key:match("^([a-z_]+):([a-z0-9_]+)$")
	return family ~= nil and graph.KEY_FAMILIES[family] ~= nil and
		(class_params[class_id] or {})[param] == true
end

--
-- Registration. Shapes are asserted at load, so a malformed tree stops the
-- server instead of quietly doing nothing (the rule of talents.lua).
--
function graph.register_tree(def)
	assert(type(def) == "table" and def.id and def.class and def.name,
		"incomplete graph tree: " .. tostring(def and def.id))
	assert(not graph.trees[def.id], "duplicate graph tree " .. def.id)
	assert(grug_classes.registered_classes[def.class],
		"graph tree " .. def.id .. " names an unknown class " .. tostring(def.class))
	assert(type(def.nodes) == "table" and #def.nodes > 0,
		"graph tree " .. def.id .. " has no nodes")
	for _, node in ipairs(def.nodes) do
		assert(node.id and node.code and node.name,
			"incomplete node in " .. def.id .. ": " .. tostring(node.id))
		assert(not graph.nodes[node.id], "duplicate node id " .. node.id)
		assert(not graph.codes[node.code], "duplicate node code " .. node.code)
		node.tree = def.id
		node.class = def.class
		node.requires = node.requires or {}
		node.effects = node.effects or {}
		graph.nodes[node.id] = node
		graph.codes[node.code] = node
		graph.node_ids[#graph.node_ids + 1] = node.id
	end
	graph.trees[def.id] = def
	graph.tree_ids[#graph.tree_ids + 1] = def.id
	return def
end

function graph.trees_of_class(class_id)
	local list = {}
	for _, tree_id in ipairs(graph.tree_ids) do
		if graph.trees[tree_id].class == class_id then
			list[#list + 1] = graph.trees[tree_id]
		end
	end
	return list
end

--
-- The rules on a ranks table ({node id = rank}, one class's two trees).
--

local function spent(ranks)
	local total = 0
	for _, rank in pairs(ranks) do total = total + rank end
	return total
end
graph.spent = spent

function graph.tree_points(ranks, tree_id)
	local total = 0
	for _, node in ipairs(graph.trees[tree_id].nodes) do
		total = total + (ranks[node.id] or 0)
	end
	return total
end

-- The ranks in the tree's nodes of a lower gate than `def`'s.
local function gate_points(ranks, def)
	local total = 0
	for _, node in ipairs(graph.trees[def.tree].nodes) do
		if node.gate < def.gate then total = total + (ranks[node.id] or 0) end
	end
	return total
end

-- The gate and the prerequisites: nil, or the reason both paths give.
local function structure_refusal(ranks, def)
	local have = gate_points(ranks, def)
	if have < def.gate then
		return ("%s needs %d points in %s (you have %d)."):format(def.name, def.gate,
			graph.trees[def.tree].name, have)
	end
	for _, parent_id in ipairs(def.requires) do
		if (ranks[parent_id] or 0) < 1 then
			return ("%s needs a rank in %s."):format(def.name, graph.nodes[parent_id].name)
		end
	end
	return nil
end
graph.structure_refusal = structure_refusal

-- nil when one more rank of `id` may be bought, else the reason. The
-- structural reasons come before the budget, so a locked node says why.
function graph.spend_refusal(class_id, ranks, id, budget)
	local def = graph.nodes[id]
	if not def then
		return "No such talent."
	end
	if def.class ~= class_id then
		return def.name .. " belongs to another class."
	end
	local rank = ranks[id] or 0
	if rank >= def.ranks then
		return ("%s is already at %d/%d."):format(def.name, def.ranks, def.ranks)
	end
	local reason = structure_refusal(ranks, def)
	if reason then
		return reason
	end
	if spent(ranks) >= budget then
		return "No talent points left."
	end
	return nil
end

-- A new ranks table with one more rank of `id`, or nil plus the refusal.
function graph.spend(class_id, ranks, id, budget)
	local reason = graph.spend_refusal(class_id, ranks, id, budget)
	if reason then
		return nil, reason
	end
	local out = {}
	for key, rank in pairs(ranks) do out[key] = rank end
	out[id] = (out[id] or 0) + 1
	return out
end

-- The full reset: every rank to 0, every point back.
function graph.reset(ranks)
	return {}, spent(ranks)
end

-- Drops every rank whose gate or prerequisite fails, until none does; each
-- drop is recorded in `dropped` with the spend path's reason. Dropping only
-- lowers totals, so the loop terminates.
local function enforce(ranks, dropped)
	while true do
		local drop
		for _, id in ipairs(graph.node_ids) do
			if ranks[id] then
				local reason = structure_refusal(ranks, graph.nodes[id])
				if reason then
					drop = drop or {}
					drop[#drop + 1] = id
					dropped[id] = reason
				end
			end
		end
		if not drop then
			return
		end
		for _, id in ipairs(drop) do ranks[id] = nil end
	end
end

-- The read path: a stored "id=rank,..." string of `class_id`, validated.
-- Unknown ids and other classes' nodes are dropped, ranks clamped, gates and
-- prerequisites enforced, and the total refunded down to `budget`, deepest
-- first (highest gate, then latest registration), so two servers agree.
-- Returns the ranks and {id = reason} of what it dropped.
function graph.parse(class_id, raw, budget)
	local ranks, dropped = {}, {}
	for id, value in tostring(raw or ""):gmatch("([%a][%w_]*)=(%-?%d+)") do
		local def = graph.nodes[id]
		if not def or def.class ~= class_id then
			dropped[id] = def and def.name .. " belongs to another class." or "No such talent."
		else
			local rank = math.min(def.ranks, math.floor(tonumber(value) or 0))
			if rank > 0 then ranks[id] = rank end
		end
	end
	enforce(ranks, dropped)
	while spent(ranks) > budget do
		local worst
		for _, id in ipairs(graph.node_ids) do
			if ranks[id] and (not worst or graph.nodes[id].gate >= worst.gate) then
				worst = graph.nodes[id]
			end
		end
		ranks[worst.id] = ranks[worst.id] - 1
		if ranks[worst.id] <= 0 then ranks[worst.id] = nil end
		dropped[worst.id] = dropped[worst.id] or "Refunded: more ranks than points."
		enforce(ranks, dropped)
	end
	return ranks, dropped
end

-- "id=rank,..." in registration order.
function graph.serialize(ranks)
	local parts = {}
	for _, id in ipairs(graph.node_ids) do
		if (ranks[id] or 0) > 0 then parts[#parts + 1] = id .. "=" .. ranks[id] end
	end
	return table.concat(parts, ",")
end

-- A purchase order in the node list's notation ("F1x4 F4 F2x3 ..."), bought
-- rank by rank through spend. Returns the ranks, or nil plus the failing
-- step and its refusal.
function graph.apply_order(class_id, order, budget, ranks)
	ranks = ranks or {}
	for token in tostring(order):gmatch("[^%s,]+") do
		local code, count = token:match("^([%a]+%d+)x?(%d*)$")
		local def = code and graph.codes[code]
		if not def then
			return nil, token .. ": no such node."
		end
		for _ = 1, tonumber(count) or 1 do
			local reason
			ranks, reason = graph.spend(class_id, ranks, def.id, budget)
			if not ranks then
				return nil, token .. ": " .. reason
			end
		end
	end
	return ranks
end

--
-- Load-time audit: the shapes, the prerequisite graph (no cycle), every node
-- reachable within POINTS_MAX, the rank sums, the vocabulary, the layout
-- cells and the sample build.
--

local GATE_ROW = {}
for index, gate in ipairs(graph.GATE_ROWS) do GATE_ROW[gate] = index end
graph.GATE_ROW = GATE_ROW

-- The fewest points with which `target` gets its first rank: buy its missing
-- ancestors as soon as their gate allows, other ranks (lowest gate first)
-- while a gate waits. Nil when nothing is buyable before it.
local function reach_cost(tree, target)
	local needed, stack = {[target.id] = true}, {target}
	while #stack > 0 do
		local def = table.remove(stack)
		for _, parent_id in ipairs(def.requires) do
			if not needed[parent_id] then
				needed[parent_id] = true
				stack[#stack + 1] = graph.nodes[parent_id]
			end
		end
	end
	local ranks, total = {}, 0
	while not ranks[target.id] do
		local pick
		for pass = 1, 2 do
			for _, def in ipairs(tree.nodes) do
				local wanted = pass == 1 and needed[def.id] and not ranks[def.id]
					or pass == 2 and not needed[def.id] and (ranks[def.id] or 0) < def.ranks
				if wanted and not structure_refusal(ranks, def) and
						(not pick or def.gate < pick.gate) then
					pick = def
				end
			end
			if pick then break end
		end
		if not pick or total >= graph.POINTS_MAX then
			return nil
		end
		ranks[pick.id] = (ranks[pick.id] or 0) + 1
		total = total + 1
	end
	return total
end

function graph.audit()
	for _, tree_id in ipairs(graph.tree_ids) do
		local tree = graph.trees[tree_id]
		local label = "graph tree " .. tree_id
		local ultimates, ranks, cells = 0, 0, {}
		for _, def in ipairs(tree.nodes) do
			local name = label .. " node " .. def.id
			assert(TYPES[def.type], name .. " has no valid type")
			assert(type(def.ranks) == "number" and def.ranks >= 1 and
				def.ranks == math.floor(def.ranks), name .. " has no rank count")
			assert(GATE_ROW[def.gate], name .. " has a gate outside GATE_ROWS")
			if GRANTS[def.type] then
				assert(type(def.ability) == "string" and def.ranks == 1,
					name .. " grants an ability: it needs `ability` and one rank")
				assert(class_params[def.class] and class_params[def.class][def.ability],
					name .. "'s ability is not among its class's params")
			else
				assert(def.ability == nil, name .. " is no granting node but names an ability")
			end
			if def.type == "ultimate" then
				ultimates = ultimates + 1
				assert(def.gate == graph.ULTIMATE_GATE, name .. ": an ultimate sits at its gate")
			end
			for _, parent_id in ipairs(def.requires) do
				local parent = graph.nodes[parent_id]
				assert(parent and parent.tree == tree_id and parent_id ~= def.id,
					name .. " requires " .. tostring(parent_id) .. " outside its tree")
				assert(parent.gate <= def.gate, name .. " requires a node of a higher gate")
			end
			for key, values in pairs(def.effects) do
				assert(graph.valid_key(def.class, key),
					name .. " uses effect key '" .. key .. "' outside its vocabulary")
				assert(type(values) == "table" and #values == def.ranks,
					name .. " effect '" .. key .. "' needs one value per rank")
				for _, value in ipairs(values) do
					assert(type(value) == "number", name .. " effect '" .. key ..
						"' has a non-numeric value")
				end
			end
			assert(type(def.col) == "number" and def.col >= 1 and def.col <= graph.COLUMNS
				and def.col == math.floor(def.col), name .. " has no column")
			local cell = def.gate .. ":" .. def.col
			assert(not cells[cell], name .. " shares its cell with " .. tostring(cells[cell]))
			cells[cell] = def.id
			ranks = ranks + def.ranks
		end
		assert(ultimates == 1, label .. " holds " .. ultimates .. " ultimates instead of 1")
		-- Rank sums: the declared total, and more than a character's points,
		-- so even a pure build leaves ranks unbought.
		assert(ranks == tree.ranks, label .. " holds " .. ranks ..
			" ranks, its data says " .. tostring(tree.ranks))
		assert(ranks > graph.POINTS_MAX, label .. " could be bought out")
		-- No cycle: a depth-first walk over the prerequisites.
		local state = {}
		local function visit(def)
			assert(state[def.id] ~= "open", label .. " has a prerequisite cycle at " .. def.id)
			if state[def.id] then return end
			state[def.id] = "open"
			for _, parent_id in ipairs(def.requires) do visit(graph.nodes[parent_id]) end
			state[def.id] = "done"
		end
		for _, def in ipairs(tree.nodes) do visit(def) end
		for _, def in ipairs(tree.nodes) do
			local cost = reach_cost(tree, def)
			assert(cost and cost <= graph.POINTS_MAX,
				label .. " node " .. def.id .. " is not reachable within " ..
				graph.POINTS_MAX .. " points")
			def.reach_cost = cost
		end
		-- The sample build the preview shows (D3): a legal order in this tree.
		if tree.example then
			local built, reason = graph.apply_order(tree.class, tree.example, graph.POINTS_MAX)
			assert(built, label .. " sample build: " .. tostring(reason))
			for id in pairs(built) do
				assert(graph.nodes[id].tree == tree_id, label .. " sample build leaves its tree")
			end
			tree.example_ranks = built
		end
	end
end
