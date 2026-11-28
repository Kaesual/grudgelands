-- The one-off box rewrite of the two halls of the arena Breach Road (Round 89,
-- the migration 0.89.0; the deliberate exception of
-- docs/technical/upgrade-contract.md §5.9, the pattern of Round 69's
-- camp_rewrite.lua): every cell of each hall template's box becomes what a
-- fresh world's mapgen writes there, without a map reset. No player can have
-- built in a box (the arena's protected box holds both, kind `arena`, no
-- digging or building for anyone), so no old cell has to survive.
--
-- It stands beside camp_rewrite.lua instead of generalising it: that job's
-- handler runs against new game code for good, so its file stays as it is.
-- The flow is the same:
--   1. emerge the box: a chunk that does not exist yet generates, with the new
--      templates, so the write below is a harmless repeat there, and a half
--      generated hall ends whole;
--   2. in a server step of its own: the old metadata and node timers leave the
--      box (a VoxelManip write keeps both) and the cells go in through one
--      VoxelManip with the engine's light update. The same cells as the
--      arena's writer, from the same model (`wp40/r89_hall_sites.lua`). Like
--      generation it runs no on_construct.
-- The pending key is durable and map-bound (cleared by a map reset). It goes
-- only once two map saves have passed since the last write: the engine saves
-- map and mod storage apart, so a crash may lose a written block, and then
-- the next start repeats the job. A repeat is harmless: same cells, same
-- bytes.
--
-- Before the key goes, both boxes are read back. The engine's mapgen
-- VoxelManip holds its chunk and a one-block shell from before generation and
-- writes all of it back after, so a chunk generating beside a box during a
-- write undoes that write in the shell (docs/technical/upstream-workarounds.md).
-- A box that differs, or that cannot be read, runs the job again, TRIES passes
-- in all; then it reports severe and keeps the key for the next start, as a
-- failed emerge or write does. A new world never has the key.
--
-- request() (the migration's world handler) records the work; it does nothing
-- at a start that resets the map, whose map generates the new halls.
-- `sites`: {key, place()} per hall; place() -> {cells = {{x, y, z, name,
-- param2}, ...} relative to `base`, base, min, max}.
return function(engine, storage, sites, map_reset, severe)
	local KEY = "hall_rewrite"
	local SOURCE = "grug_mapgen"
	local TRIES = 3
	local M = {}
	local scheduled = false
	local passes = 1
	-- The prepared halls of this job, by index: built once, gone with it.
	local places = {}

	-- Writes one prepared hall. Returns the number of cells, or nil and the
	-- reason.
	local function write(place)
		local vm = engine.get_voxel_manip()
		local emin, emax = vm:read_from_map(place.min, place.max)
		local area = VoxelArea(emin, emax)
		local data, param2 = vm:get_data(), vm:get_param2_data()
		local ignore = engine.CONTENT_IGNORE
		local base, cells = place.base, place.cells
		for index = 1, #cells do
			local cell = cells[index]
			if data[area:index(base.x + cell.x, base.y + cell.y, base.z + cell.z)] == ignore then
				return nil, "a cell of the box is not loaded"
			end
		end
		for _, pos in ipairs(engine.find_nodes_with_meta(place.min, place.max)) do
			engine.get_meta(pos):from_table(nil)
		end
		local pos = {x = 0, y = 0, z = 0}
		for index = 1, #cells do
			local cell = cells[index]
			pos.x, pos.y, pos.z = base.x + cell.x, base.y + cell.y, base.z + cell.z
			engine.get_node_timer(pos):stop()
			local at = area:index(pos.x, pos.y, pos.z)
			data[at], param2[at] = engine.get_content_id(cell.name), cell.param2
		end
		vm:set_data(data)
		vm:set_param2_data(param2)
		vm:write_to_map(true)
		return #cells
	end

	-- How many cells of a written hall differ from the model in node or
	-- param2, and how many could not be read.
	local function compare(place)
		local vm = engine.get_voxel_manip()
		local emin, emax = vm:read_from_map(place.min, place.max)
		local area = VoxelArea(emin, emax)
		local data, param2 = vm:get_data(), vm:get_param2_data()
		local ignore = engine.CONTENT_IGNORE
		local base = place.base
		local differ, unread = 0, 0
		for _, cell in ipairs(place.cells) do
			local at = area:index(base.x + cell.x, base.y + cell.y, base.z + cell.z)
			if data[at] == ignore then
				unread = unread + 1
			elseif data[at] ~= engine.get_content_id(cell.name) or param2[at] ~= cell.param2 then
				differ = differ + 1
			end
		end
		return differ, unread
	end

	local function failed(key, reason)
		severe.report(SOURCE, "The arena hall " .. key .. " could not be rewritten; " ..
			"the next start tries again", tostring(reason), "hall_rewrite")
	end

	local run
	-- Two map saves after the last write: every box read back, then the key.
	local function settle()
		local problems = {}
		for index, site in ipairs(sites) do
			local ok, differ, unread = pcall(compare, places[index])
			if not ok then
				problems[#problems + 1] = site.key .. " unreadable: " .. tostring(differ)
			elseif differ + unread > 0 then
				problems[#problems + 1] = ("%s: %d cells differ, %d unread"):format(site.key,
					differ, unread)
			end
		end
		if #problems == 0 then
			storage:set_string(KEY, "")
			sites, places = nil, nil
			engine.log("action", "[grug_mapgen] the arena halls' rewrite is done, every box read back")
			return
		end
		local detail = table.concat(problems, "; ")
		if passes >= TRIES then
			return failed("(after " .. passes .. " passes)", detail)
		end
		passes = passes + 1
		engine.log("warning", "[grug_mapgen] the arena halls' read-back found " .. detail ..
			"; writing again, pass " .. passes)
		run(1)
	end

	local function finish(site, place, index, started, emerge_failed)
		if emerge_failed then return failed(site.key, "its emerge failed") end
		local start = engine.get_us_time()
		local ok, written, reason = pcall(write, place)
		if not ok then return failed(site.key, written) end
		if not written then return failed(site.key, reason) end
		engine.log("action", ("[grug_mapgen] arena hall %s rewritten: %d cells, " ..
			"emerge %.1f s, write %.1f ms"):format(site.key, written,
			(start - started) / 1000000, (engine.get_us_time() - start) / 1000))
		run(index + 1)
	end

	function run(index)
		local site = sites[index]
		if not site then
			local interval = tonumber(engine.settings:get("server_map_save_interval")) or 5.3
			engine.after(2 * interval + 1, settle)
			return
		end
		local started = engine.get_us_time()
		local ok, place = pcall(function() return places[index] or site.place() end)
		if not ok then return failed(site.key, place) end
		places[index] = place
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

	-- Map-bound: a new map generates the new halls.
	map_reset.clear(SOURCE, function() storage:set_string(KEY, "") end)
	start()
	return M
end
