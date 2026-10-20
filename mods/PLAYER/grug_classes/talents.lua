-- Talents (docs/design/skill_trees.md).
--
-- Since Round 53 (round K, round53-plan.md §4 "LIVE") the live talents are
-- the GRAPH talents (talent_graph.lua, one data file per class): this file
-- loads and audits them, stores each character's ranks under
-- grug_classes:talents in the graph's format, and answers every consumer
-- through the unchanged accessors (get_talent_bonus, talent_rank, the
-- points, register_on_talents_changed), the spend and respec rules, the
-- level-drop reset and the read-only /talents.
--
-- The old registry (WP11 lane X1: register_tree/register_talent, its
-- vocabulary, the four old data files, the Unbroken passive) went with the
-- round's clean-up (INTEG part 2).
--
-- Points (§1.3, ruling 1): one every two levels, the first at level 2, so
-- floor(level / 2) and 30 at level 60. Never persisted -- deriving it is what
-- makes "points available" and "level" incapable of disagreeing.

local META_TALENTS = "grug_classes:talents"

grug_classes.TALENT_LEVELS_PER_POINT = 2

-- The points a character of `level` has earned in total: the one rule, also
-- read by the level-up banner (grug_xp) and the level-change notice below.
function grug_classes.talent_points_at(level)
	return math.floor(level / grug_classes.TALENT_LEVELS_PER_POINT)
end

function grug_classes.talent_points_total(player)
	return grug_classes.talent_points_at(grug_xp.get_level(player))
end

--
-- The live talents (Round 53, round K: round53-plan.md §4 "LIVE", K3, K4).
-- The graph registry, one data file per class and the audit; every accessor
-- below reads a character's ranks through it.
--

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/talent_graph.lua")
for _, class_id in ipairs({"mage", "warrior", "priest", "scout"}) do
	dofile(modpath .. "/talent_graph_" .. class_id .. ".lua")
end
local graph = grug_classes.graph
graph.audit()

--
-- Runtime state. One parsed cache per online player (the pattern of
-- grug_abilities' runtime tables), cleared on leave and on every change. The
-- timed-window table of §3.2 lives in talent_windows.lua;
-- clear_talent_windows clears it on leave, death and respec.
--
-- The store (K4) keeps the meta key grug_classes:talents in the graph's
-- format, "<node id>=<rank>,...". graph.parse validates it on every read:
-- unknown ids (every id of the old trees: none carries a tree prefix) and
-- other classes' nodes are dropped, ranks clamped, gates and prerequisites
-- enforced, the total refunded down to floor(level / 2), deepest first. A
-- 0.52 string therefore reads as zero ranks; the 0.53.0 migration step
-- clears it anyway.
--

local cache = {} -- player name -> {ranks, spent, tree_points, sums}

-- The ranks the stored string names for the character's class, clamped per
-- node but before any gate or budget: the level-drop line reports this --
-- the count after the budget would say how many ranks a lower level may
-- hold rather than how many the reset took away.
local function stored_rank_total(player)
	local class_id = grug_classes.get_class(player)
	local raw = player:get_meta():get_string(META_TALENTS) or ""
	local total = 0
	for id, value in raw:gmatch("([%a][%w_]*)=(%-?%d+)") do
		local def = graph.nodes[id]
		if def and def.class == class_id then
			total = total + math.max(0, math.min(def.ranks, math.floor(tonumber(value) or 0)))
		end
	end
	return total
end

local function parse(player)
	local ranks = graph.parse(grug_classes.get_class(player),
		player:get_meta():get_string(META_TALENTS),
		grug_classes.talent_points_total(player))
	-- Pre-summed effects, so the consumers on the damage pipeline pay one
	-- table index. Summed in REGISTRATION order, never in `pairs` order: a
	-- float sum whose order depends on a hash would let two servers disagree.
	local tree_points, sums = {}, {}
	for _, id in ipairs(graph.node_ids) do
		local rank = ranks[id]
		if rank then
			local def = graph.nodes[id]
			tree_points[def.tree] = (tree_points[def.tree] or 0) + rank
			for key, values in pairs(def.effects) do
				sums[key] = (sums[key] or 0) + values[rank]
			end
		end
	end
	return {ranks = ranks, spent = graph.spent(ranks), tree_points = tree_points, sums = sums}
end

local function state(player)
	local name = player:get_player_name()
	local entry = cache[name]
	if not entry then
		entry = parse(player)
		cache[name] = entry
	end
	return entry
end

function grug_classes.invalidate_talents(player)
	cache[player:get_player_name()] = nil
end

-- Timed windows (§3.2): the window runtime lives in talent_windows.lua.
dofile(modpath .. "/talent_windows.lua")

--
-- The accessors every consumer reads. get_talent_bonus is the deliberate
-- twin of get_race_perk, down to the grug_core stub override at the bottom
-- of this file.
--

-- The summed rank value of `key` over the player's ranks: a shared key, a
-- class key or "<family>:<param>" (graph.valid_key); 0 when none. A
-- level-scaled key (armor_percent_add) answers with its amount at the
-- player's level.
function grug_classes.get_talent_bonus(player, key)
	if not player or not player.is_player or not player:is_player() then
		return 0
	end
	local total = state(player).sums[key] or 0
	if total ~= 0 and graph.LEVEL_SCALED_KEYS[key] then
		return graph.level_amount(key, total, grug_xp.get_level(player))
	end
	return total
end

-- The rank of graph node `talent_id` ("<tree>_<name>"); used by the kit
-- grant (an ability's `talent`), the gates and the UI, never by a numeric
-- consumer.
function grug_classes.talent_rank(player, talent_id)
	if not player or not player.is_player or not player:is_player() then
		return 0
	end
	return state(player).ranks[talent_id] or 0
end

-- The player's ranks, {node id = rank}: the parsed cache itself, read only.
function grug_classes.talent_ranks(player)
	return state(player).ranks
end

function grug_classes.talent_points_spent(player)
	return state(player).spent
end

function grug_classes.talent_points_available(player)
	return grug_classes.talent_points_total(player)
		- grug_classes.talent_points_spent(player)
end

function grug_classes.tree_points(player, tree_id)
	return state(player).tree_points[tree_id] or 0
end

local talents_changed_callbacks = {}

-- func(player) -- called after any change to a character's talents (a spend,
-- a respec, an admin level drop). The mirror of register_on_class_chosen;
-- grug_abilities re-syncs the kit here.
function grug_classes.register_on_talents_changed(func)
	table.insert(talents_changed_callbacks, func)
end

local function commit(player, ranks)
	player:get_meta():set_string(META_TALENTS, graph.serialize(ranks))
	cache[player:get_player_name()] = nil
	for _, func in ipairs(talents_changed_callbacks) do
		func(player)
	end
end

--
-- Spending, and the refusal reasons the UI shows: the graph's rules
-- (graph.spend_refusal), the same texts the read path gives.
--

-- Returns true, or false plus the reason a rank of node `talent_id` cannot
-- be bought.
function grug_classes.can_spend_talent(player, talent_id)
	local class_id = grug_classes.get_class(player)
	if not class_id then
		return false, "You have no class yet."
	end
	local reason = graph.spend_refusal(class_id, state(player).ranks, talent_id,
		grug_classes.talent_points_total(player))
	if reason then
		return false, reason
	end
	return true
end

function grug_classes.spend_talent(player, talent_id)
	local ok, reason = grug_classes.can_spend_talent(player, talent_id)
	if not ok then
		return false, reason
	end
	commit(player, (graph.spend(grug_classes.get_class(player), state(player).ranks,
		talent_id, grug_classes.talent_points_total(player))))
	return true
end

-- A respec is a FULL reset (ruling 20, graph.reset): every rank to 0, all
-- points back. Pricing and the money transaction live on the sfinv page;
-- this function is the deterministic reset used there and by the free
-- level-drop path.
function grug_classes.respec(player)
	local cleared, spent = graph.reset(state(player).ranks)
	grug_classes.clear_talent_windows(player)
	commit(player, cleared)
	return spent
end

--
-- Level changes (§3.6 and ruling 20's last bullet). Called from the existing
-- grug_xp level-change registration in stats.lua, so the order against
-- apply_stats is fixed rather than incidental.
--
-- A level drop would otherwise leave more ranks spent than floor(level / 2)
-- allows. Only a direct grug_xp.set_xp to less XP lowers a level (/xp only
-- grants XP; no game path takes any away). Rather than blocking spends or
-- refunding cheapest-first, the talent state is wiped and every point
-- returned -- free, because no player action can lower a level and the
-- simplest correct behaviour wins.
function grug_classes.on_level_change_talents(player, old_level, new_level)
	cache[player:get_player_name()] = nil
	if old_level == nil then
		return
	end
	if new_level < old_level then
		-- The stored total, not the re-parsed one: the cache was dropped a
		-- few lines up, so talent_points_spent would already have been
		-- trimmed to floor(new_level / 2) and a big drop would under-report
		-- what it wiped.
		local spent = stored_rank_total(player)
		if spent > 0 then
			grug_classes.respec(player)
			grug_core.feed(player, "quest", "Your level dropped: all " .. spent ..
				" talent points were returned.", "talents")
		end
		return
	end
	-- old_level is nil on join (grug_xp/init.lua:32-33). Arithmetic on nil
	-- here would error on every single join, which is why the guard above is
	-- not optional.
	if grug_classes.talent_points_at(new_level)
			> grug_classes.talent_points_at(old_level) then
		local left = grug_classes.talent_points_available(player)
		if left > 0 then
			-- In the message feed beside the level-up's XP line, never chat.
			grug_core.feed(player, "quest", "Talent point earned - " .. left ..
				" to spend. Open the Talents & Skills tab.", "talents")
		end
	end
end

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	grug_classes.clear_talent_windows(player)
	cache[name] = nil
end)

-- A character's FIRST class pick at creation is not a class change (ruling 20
-- removed those), but it does decide which talents are the character's at all,
-- and the parsed cache may already exist from a read taken before it. One
-- invalidation is cheaper than reasoning about whether such a read can happen.
grug_classes.register_on_class_chosen(function(player)
	cache[player:get_player_name()] = nil
end)

core.register_on_dieplayer(function(player)
	grug_classes.clear_talent_windows(player)
end)

--
-- Read-only chat summary of the graph. Buying ranks and resetting a build
-- live exclusively on the sfinv Talents & Skills page; no command can mutate
-- talent state.
--

local function talent_line(player, def)
	local rank = grug_classes.talent_rank(player, def.id)
	local line = ("  %s %-30s %d/%d  %s"):format(def.type == "ultimate" and "!" or " ",
		def.id, rank, def.ranks, def.name)
	if rank < def.ranks then
		local ok, reason = grug_classes.can_spend_talent(player, def.id)
		if not ok then
			line = line .. "  (" .. reason .. ")"
		end
	end
	return line
end

core.register_chatcommand("talents", {
	params = "",
	description = "Show a read-only summary of your talent trees",
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "You must be online."
		end
		local class_id = grug_classes.get_class(player)
		if not class_id then
			return false, "You have no class yet."
		end
		local lines = {
			("%s - %d talent points, %d spent, %d left"):format(
				grug_classes.registered_classes[class_id].name,
				grug_classes.talent_points_total(player),
				grug_classes.talent_points_spent(player),
				grug_classes.talent_points_available(player)),
		}
		for _, tree in ipairs(graph.trees_of_class(class_id)) do
			lines[#lines + 1] = ("%s [%d]"):format(tree.name,
				grug_classes.tree_points(player, tree.id))
			for _, def in ipairs(tree.nodes) do
				lines[#lines + 1] = talent_line(player, def)
			end
		end
		lines[#lines + 1] = "! ultimate. Open the Talents & Skills tab to make changes."
		return true, table.concat(lines, "\n")
	end,
})

-- FIRST talents-changed consumer, and the reason the callback exists at all.
-- `grug_classes.apply_stats` is the only writer of a player's `hp_max`
-- (stats.lua), and until this line it ran on an equipment change, a level
-- change and the class pick only -- so Weathered raised get_max_hp while the
-- character's actual ceiling stayed where it was until something else moved
-- it, and a respec left the raised ceiling behind.
--
-- Registered HERE rather than from stats.lua, which is dofile'd before this
-- file and would find no callback to register on; and registered first, so a
-- later consumer (grug_abilities' kit sync, which has to take a
-- talent-granted button back on a respec) reads stats that are already
-- current -- the same ordering rule stats.lua states for the equipment-change
-- seam.
--
-- Deliberately WITHOUT heal_gain: spending a point must not hand out free
-- health, and apply_stats already clamps current HP down when a respec lowers
-- the maximum.
grug_classes.register_on_talents_changed(function(player)
	grug_classes.apply_stats(player)
end)

-- Stub override (same pattern as grug_core.get_race_perk): mods below
-- grug_classes in the dependency graph read talents through grug_core.
grug_core.get_talent_bonus = grug_classes.get_talent_bonus
