-- The one-off box rewrite of the camps under construction (Round 69 ruling 5,
-- the deliberate exception of docs/technical/upgrade-contract.md §5.9): every
-- cell of each of the six camps' boxes becomes what a fresh world's mapgen
-- writes there, without a map reset. No player can have built in a box (it is
-- protection kind `war_camp`, ten nodes wider than the box on every side in x
-- and z), so no old cell has to survive.
--
-- The job runs once, after the load, one camp at a time:
--   1. emerge the box: a chunk that does not exist yet generates, with the new
--      blueprint, so the write below is a harmless repeat there, and a half
--      generated camp ends whole;
--   2. in a server step of its own: the old metadata and node timers leave the
--      replaced cells (a VoxelManip write keeps both) and the cells go in
--      through one VoxelManip with the engine's light update. The same cells
--      as the writer's, read from the same prepared blueprint, on the same
--      base, leaving out the anchor root the writer leaves out. Like
--      generation it runs no on_construct.
-- The pending key is durable and map-bound (cleared by a map reset). It goes
-- only once two map saves have passed since the last write: the engine saves
-- map and mod storage apart, so a crash may lose a written block, and then
-- the next start repeats the job. A repeat is harmless: same cells, same
-- bytes. A failed emerge or write reports severe and keeps the key for the
-- next start. Only this one job touches the map; a new world never has the key.
--
-- request() (the migration's world handler) records the work; it does nothing
-- at a start that resets the map, whose map generates the new blueprint.
return function(engine, storage, sites, map_reset, severe)
	local KEY = "camp_rewrite"
	local SOURCE = "grug_mapgen"
	local M = {}
	local scheduled = false

	-- Writes one prepared camp. Returns true, or nil and the reason.
	local function write(place)
		local vm = engine.get_voxel_manip()
		local emin, emax = vm:read_from_map(place.min, place.max)
		local area = VoxelArea(emin, emax)
		local data, param2 = vm:get_data(), vm:get_param2_data()
		local ignore = engine.CONTENT_IGNORE
		local base, root = place.base, place.reserved
		local root_x, root_y, root_z = root and root.x, root and root.y, root and root.z
		local cells = place.cells
		for index = 1, #cells do
			local cell = cells[index]
			if data[area:index(base.x + cell.x, base.y + cell.y, base.z + cell.z)] == ignore then
				return nil, "a cell of the box is not loaded"
			end
		end
		for _, pos in ipairs(engine.find_nodes_with_meta(place.min, place.max)) do
			if pos.x ~= root_x or pos.y ~= root_y or pos.z ~= root_z then
				engine.get_meta(pos):from_table(nil)
			end
		end
		local pos = {x = 0, y = 0, z = 0}
		local written = 0
		for index = 1, #cells do
			local cell = cells[index]
			pos.x, pos.y, pos.z = base.x + cell.x, base.y + cell.y, base.z + cell.z
			if pos.x ~= root_x or pos.y ~= root_y or pos.z ~= root_z then
				engine.get_node_timer(pos):stop()
				local at = area:index(pos.x, pos.y, pos.z)
				data[at], param2[at] = engine.get_content_id(cell.name), cell.param2
				written = written + 1
			end
		end
		vm:set_data(data)
		vm:set_param2_data(param2)
		vm:write_to_map(true)
		return written
	end

	local function failed(key, reason)
		severe.report(SOURCE, "The camp site " .. key .. " could not be rewritten; " ..
			"the next start tries again", tostring(reason), "camp_rewrite")
	end

	local run
	local function finish(site, place, index, started, emerge_failed)
		if emerge_failed then return failed(site.key, "its emerge failed") end
		local start = engine.get_us_time()
		local ok, written, reason = pcall(write, place)
		if not ok then return failed(site.key, written) end
		if not written then return failed(site.key, reason) end
		engine.log("action", ("[grug_mapgen] camp site %s rewritten: %d cells, " ..
			"emerge %.1f s, write %.1f ms"):format(site.key, written,
			(start - started) / 1000000, (engine.get_us_time() - start) / 1000))
		run(index + 1)
	end

	function run(index)
		local site = sites[index]
		if not site then
			local interval = tonumber(engine.settings:get("server_map_save_interval")) or 5.3
			engine.after(2 * interval + 1, function()
				storage:set_string(KEY, "")
				sites = nil
				engine.log("action", "[grug_mapgen] the camp sites' rewrite is done")
			end)
			return
		end
		local started = engine.get_us_time()
		local ok, place = pcall(site.place)
		if not ok then return failed(site.key, place) end
		local emerge_failed = false
		engine.emerge_area(place.min, place.max, function(_, action, remaining)
			if action == engine.EMERGE_ERRORED or action == engine.EMERGE_CANCELLED then
				emerge_failed = true
			end
			if remaining == 0 then
				-- Out of the emerge thread's completion callback.
				engine.after(0, finish, site, place, index, started, emerge_failed)
			end
		end)
	end

	local function start()
		if scheduled or storage:get_string(KEY) == "" then return end
		scheduled = true
		engine.after(0, run, 1)
	end

	function M.request()
		if map_reset.pending() then return end
		storage:set_string(KEY, "1")
		start()
	end

	-- Whether the job still has to run or to settle.
	function M.pending()
		return storage:get_string(KEY) ~= ""
	end

	-- Map-bound: a new map generates the new blueprint.
	map_reset.clear(SOURCE, function() storage:set_string(KEY, "") end)
	start()
	-- The sites hold the prepared camps, which the load would otherwise
	-- release: they stay only for a job. grug_core's world markers ran first,
	-- so every request comes before this.
	engine.register_on_mods_loaded(function()
		if not M.pending() then sites = nil end
	end)
	return M
end
