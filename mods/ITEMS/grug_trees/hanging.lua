-- Hanging plants as a strand above an end (Round 51 lane LG, land plan §4
-- "Swamp"): a continuous strand node repeats down a run and one tapered end
-- node closes it, so a run of any length reads as one curtain. The world
-- generator writes the strand above the end (wp40/tree_templates.lua,
-- HANGING); this file keeps the run whole when a player digs it:
--
--   * the piece right above the dug one, a strand of the same pair, turns
--     into the end (digging the end moves the end up, and so on up);
--   * the pieces below the dug one hung from it and fall away with it
--     (they drop nothing, like the plant itself; a protected piece stays).
--
-- One rule for every pair: `register(strand, tip)` is the one entry, so the
-- jungle's lianas (lane LP) reuse it. Hanging plants come back only with
-- their tree (the tree's leaf decay takes them, a regrown tree brings its
-- own); there is no regrowth of their own.
--
-- Pure: every engine access comes through `api`, so the fixture runs it:
--   api.get_node(pos) -> {name, param2}, api.swap_node(pos, node),
--   api.remove_node(pos), api.is_protected(pos, player_name) -> bool,
--   api.override_item(name, fields)
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
		end
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
		return pair
	end

	function M.pair(name) return pair_of[name] end
	return M
end
