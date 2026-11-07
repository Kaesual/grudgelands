-- Hanging plants as a strand above an end (Round 51 lane LG, land plan §4
-- "Swamp"): a continuous strand node repeats down a run and one tapered end
-- node closes it, so a run of any length reads as one curtain. The world
-- generator writes the strand above the end (wp40/tree_templates.lua,
-- HANGING); this file keeps the run whole when a player digs it:
--
--   * the piece right above the dug one, a strand of the same pair, turns
--     into the end (digging the end moves the end up, and so on up);
--   * the pieces below the dug one hung from it and fall away with it,
--     each giving the digger one piece as the dug one does (a protected
--     piece stays).
--
-- Placing (Round 70, round70-plan.md §2.3): one carried piece is one node.
-- It hangs as an end under a solid block or leaves; pointed at a run, it
-- joins the bottom of that run, whose old end becomes a strand. A piece
-- placed by a player never decays (default.after_place_leaves), so a block
-- dug away above it leaves it hanging in the air like any placed leaves.
--
-- One rule for every pair: `register(strand, tip)` is the one entry, so the
-- jungle's lianas (lane LP) reuse it. Hanging plants come back only with
-- their tree (the tree's leaf decay takes them, without a drop; a regrown
-- tree brings its own); there is no regrowth of their own.
--
-- Pure: every engine access comes through `api`, so the fixture runs it:
--   api.get_node(pos) -> {name, param2}, api.swap_node(pos, node),
--   api.remove_node(pos), api.is_protected(pos, player_name) -> bool,
--   api.record_violation(pos, player_name), api.override_item(name, fields),
--   api.drop(pos, item, digger), api.rightclick(stack, placer, pointed) ->
--   stack or nil, api.holds(node name) -> bool (a piece may hang under it),
--   api.item_place(stack, placer, pointed) -> stack, placed pos or nil
return function(api)
	local M = {}
	-- name -> the pair {strand = name, tip = name} it belongs to
	local pair_of = {}

	-- How many pieces below the dug one fall away at most (a run is a few
	-- nodes; the bound only keeps a malformed stack from looping long).
	M.MAX_RUN = 32

	local function below(pos, dy)
		return {x = pos.x, y = pos.y - dy, z = pos.z}
	end

	-- The dig rule for the node `oldnode` dug at `pos` (after_dig_node).
	function M.after_dig(pos, oldnode, digger)
		local pair = pair_of[oldnode.name]
		if not pair then return end
		local up = {x = pos.x, y = pos.y + 1, z = pos.z}
		local above = api.get_node(up)
		if above.name == pair.strand then
			api.swap_node(up, {name = pair.tip, param2 = above.param2})
		end
		local player = digger and digger.get_player_name and digger:get_player_name() or ""
		for dy = 1, M.MAX_RUN do
			local p = below(pos, dy)
			local name = api.get_node(p).name
			if (name ~= pair.strand and name ~= pair.tip) or api.is_protected(p, player) then
				break
			end
			api.remove_node(p)
			api.drop(p, pair.tip, digger)
		end
	end

	-- The lowest piece of the run through `pos`, or nil when the bound ends
	-- the walk.
	local function bottom_of(pair, pos)
		local last = pos
		for _ = 1, M.MAX_RUN do
			local next_down = below(last, 1)
			local name = api.get_node(next_down).name
			if name ~= pair.strand and name ~= pair.tip then return last end
			last = next_down
		end
		return nil
	end

	-- The carried end's on_place.
	function M.on_place(itemstack, placer, pointed)
		local clicked = api.rightclick(itemstack, placer, pointed)
		if clicked then return clicked end
		if pointed.type ~= "node" then return itemstack end
		local pair = pair_of[itemstack:get_name()]
		local under, last = pointed.under, nil
		local name = api.get_node(under).name
		if name == pair.strand or name == pair.tip then
			last = bottom_of(pair, under)
			if not last then return itemstack end
		elseif pointed.above.y ~= under.y - 1 or not api.holds(name) then
			return itemstack
		end
		local target = last and below(last, 1) or pointed.above
		if api.get_node(target).name ~= "air" then return itemstack end
		if last and api.is_protected(last, placer and placer:get_player_name() or "") then
			api.record_violation(last, placer and placer:get_player_name() or "")
			return itemstack
		end
		local stack, placed = api.item_place(itemstack, placer,
			{type = "node", under = last or under, above = target})
		if placed and last then
			api.swap_node(last, {name = pair.strand, param2 = api.get_node(last).param2})
		end
		return stack
	end

	-- Make `strand` and `tip` (both registered) one hanging pair.
	function M.register(strand, tip)
		local pair = {strand = strand, tip = tip}
		for _, name in ipairs({strand, tip}) do
			pair_of[name] = pair
			api.override_item(name, {after_dig_node = function(pos, oldnode, _, digger)
				M.after_dig(pos, oldnode, digger)
			end})
		end
		api.override_item(tip, {on_place = M.on_place})
		return pair
	end

	function M.pair(name) return pair_of[name] end
	return M
end
