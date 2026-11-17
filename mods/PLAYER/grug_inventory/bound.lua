-- Bound items (Round 81 GUARDS; audit X2-01, C3-03): the one seam that keeps
-- an item group in the places its rule allows. grug_housing's soulbound
-- items (soulbound.lua) and grug_skills' skills and mount items
-- (bound_items.lua) register a rule each:
--
--   grug_inventory.register_bound_rule({
--     group = "<item group>",
--     -- The player inventory's own actions (register_allow_player_inventory_action):
--     -- 0 to refuse, nil to leave the action to the other callbacks.
--     player_action = function(player, action, inventory, info) ... end,
--     -- Optional: detached inventories that may take the group's stacks (a
--     -- name pattern), and whether a move inside a detached inventory is
--     -- refused too.
--     detached_exempt = "<pattern>", detached_move = true,
--   })
--
-- Three seams, installed here once for every rule:
--   * one player-inventory allow callback that asks each rule in turn. The
--     engine stops at the first number any allow callback returns (OR with
--     short circuit); a rule only ever answers 0, and for a bound stack no
--     other callback of the game answers more than 0, so where this one sits
--     among them changes no answer;
--   * every node's allow_metadata_inventory_put and _move refuse a bound
--     stack (any rule), else ask the node's own callback;
--   * every detached inventory's allow_put refuses a bound stack outside the
--     rule's exempt names, and allow_move one of a `detached_move` rule. An
--     inventory is wrapped when it is created (core.create_detached_inventory
--     below), one created before this file loaded once every mod has loaded.
--
-- Wrapping is idempotent: each wrapper is remembered, so a later walk wraps
-- only a callback something else replaced since (grug_jobs installs the
-- stations' allow callbacks in its own register_on_mods_loaded, without
-- calling the previous ones; grug_skills walks again at its turn, after it).

local rules = {}

function grug_inventory.register_bound_rule(rule)
	assert(type(rule) == "table" and type(rule.group) == "string" and
		type(rule.player_action) == "function")
	rules[#rules + 1] = rule
end

local function in_group(stack, group)
	return stack ~= nil and not stack:is_empty() and
		core.get_item_group(stack:get_name(), group) > 0
end

-- Is the stack bound under any rule? (Node inventories refuse them all.)
local function bound(stack)
	for i = 1, #rules do
		if in_group(stack, rules[i].group) then return true end
	end
	return false
end

local function detached_put_refused(name, stack)
	for i = 1, #rules do
		local rule = rules[i]
		if in_group(stack, rule.group) and
				not (rule.detached_exempt and name:match(rule.detached_exempt)) then
			return true
		end
	end
	return false
end

local function detached_move_refused(stack)
	for i = 1, #rules do
		if rules[i].detached_move and in_group(stack, rules[i].group) then return true end
	end
	return false
end

core.register_allow_player_inventory_action(function(player, action, inventory, info)
	for i = 1, #rules do
		local answer = rules[i].player_action(player, action, inventory, info)
		if answer ~= nil then return answer end
	end
end)

-- The wrappers this file made. Weak keys: a removed detached inventory's
-- wrappers go with it.
local own = setmetatable({}, {__mode = "k"})

local function wrap_node(name, def)
	local old_put, old_move = def.allow_metadata_inventory_put,
		def.allow_metadata_inventory_move
	local redefinition = {}
	if not own[old_put] then
		local put = function(pos, listname, index, stack, player)
			if bound(stack) then return 0 end
			if old_put then return old_put(pos, listname, index, stack, player) end
			return stack:get_count()
		end
		own[put] = true
		redefinition.allow_metadata_inventory_put = put
	end
	if not own[old_move] then
		local move = function(pos, from_list, from_index, to_list, to_index, count, player)
			local stack = core.get_meta(pos):get_inventory():get_stack(from_list, from_index)
			if bound(stack) then return 0 end
			if old_move then
				return old_move(pos, from_list, from_index, to_list, to_index, count, player)
			end
			return count
		end
		own[move] = true
		redefinition.allow_metadata_inventory_move = move
	end
	if next(redefinition) then core.override_item(name, redefinition) end
end

local function wrap_detached(name, callbacks)
	local old_put, old_move = callbacks.allow_put, callbacks.allow_move
	if not own[old_put] then
		local put = function(inv, listname, index, stack, player)
			if detached_put_refused(name, stack) then return 0 end
			if old_put then return old_put(inv, listname, index, stack, player) end
			return stack:get_count()
		end
		own[put] = true
		callbacks.allow_put = put
	end
	if not own[old_move] then
		local move = function(inv, from_list, from_index, to_list, to_index, count, player)
			if detached_move_refused(inv:get_stack(from_list, from_index)) then return 0 end
			if old_move then
				return old_move(inv, from_list, from_index, to_list, to_index, count, player)
			end
			return count
		end
		own[move] = true
		callbacks.allow_move = move
	end
	return callbacks
end

-- Wrapped at creation: builtin keeps its own copy of the callbacks
-- (builtin/game/detached_inventory.lua), so the wrap goes on a copy of the
-- caller's table.
local create_detached = core.create_detached_inventory
function core.create_detached_inventory(name, callbacks, player_name)
	local copy = {}
	for key, value in pairs(callbacks or {}) do copy[key] = value end
	return create_detached(name, wrap_detached(name, copy), player_name)
end

-- Every node, and the detached inventories created before this file loaded.
-- Runs once every mod has loaded; a mod whose own mods-loaded step replaces
-- node callbacks after this one calls it again (grug_skills/bound_items.lua).
function grug_inventory.guard_bound_destinations()
	for name, def in pairs(core.registered_nodes) do wrap_node(name, def) end
	for name, callbacks in pairs(core.detached_inventories or {}) do
		wrap_detached(name, callbacks)
	end
end
core.register_on_mods_loaded(grug_inventory.guard_bound_destinations)
