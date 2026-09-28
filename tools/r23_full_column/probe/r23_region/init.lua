-- Disposable Round 23 measurement probe (staged by run_region.sh only).
-- Ends the bounded run with a normal shutdown from a server step once
-- `r23_stop_after` seconds have passed or the region is prepared, and logs
-- progress. With `r23_geo`, it also ranks candidate measurement regions
-- (ocean, coast, mountain, a start) from a coarse column sample.
local stop_after = tonumber(core.settings:get("r23_stop_after")) or 240
local started, stopping, last_report = nil, false, 0

local function geo()
	local source = grug_mapgen.wp40.planner_source
	local ids = grug_core.start_identities()
	local STEP, TILE = 40, 80
	local grid, x0, z0 = {}, -3952, -3552
	local nx, nz = math.floor(7920 / STEP), math.floor(7120 / STEP)
	for j = 0, nz - 1 do
		for i = 0, nx - 1 do
			local _, _, _, _, _, terrain_y, water_y =
				source.column_values_at(x0 + i * STEP + 20, z0 + j * STEP + 20)
			grid[j * nx + i] = {terrain_y, water_y ~= nil and water_y > terrain_y}
		end
	end
	for _, size in ipairs({12, 16, 20}) do
		local cells = size * TILE / STEP
		local best = {}
		for tj = 0, math.floor((nz - cells) / 2) do
			for ti = 0, math.floor((nx - cells) / 2) do
				local i0, j0 = ti * 2, tj * 2
				local wet, top, n = 0, -math.huge, 0
				for j = j0, j0 + cells - 1 do
					for i = i0, i0 + cells - 1 do
						local g = grid[j * nx + i]
						n = n + 1
						if g[2] then wet = wet + 1 end
						if g[1] > top then top = g[1] end
					end
				end
				local rx0, rz0 = x0 + i0 * STEP, z0 + j0 * STEP
				local rx1, rz1 = rx0 + size * TILE - 1, rz0 + size * TILE - 1
				local start
				for _, row in ipairs(ids) do
					local a = row.anchor
					if a.x - 64 >= rx0 and a.x + 63 <= rx1 and a.z - 64 >= rz0 and a.z + 63 <= rz1 then
						start = row.race_id
					end
				end
				local frac = wet / n
				if start and frac >= 0.15 and frac <= 0.6 and top >= 150 then
					best[#best + 1] = {score = top + 200 * math.min(frac, 0.35),
						text = ("[r23g] size=%d region=%d,%d,%d,%d wet=%.2f top=%d start=%s"):
							format(size, rx0, rx1, rz0, rz1, frac, top, start)}
				end
			end
		end
		table.sort(best, function(a, b) return a.score > b.score end)
		core.log("action", ("[r23g] size=%d candidates=%d"):format(size, #best))
		for k = 1, math.min(5, #best) do core.log("action", best[k].text) end
	end
end

core.register_on_mods_loaded(function()
	if core.settings:get_bool("r23_geo", false) then
		local t = core.get_us_time()
		geo()
		core.log("action", ("[r23g] geo_us=%d"):format(core.get_us_time() - t))
	end
end)

core.register_globalstep(function(dtime)
	if stopping then return end
	started = started or core.get_us_time()
	local elapsed = (core.get_us_time() - started) / 1000000
	local status = grug_core.world_preparation_status()
	if elapsed - last_report >= 30 then
		last_report = elapsed
		core.log("action", ("[r23s] t=%.1f completed=%d/%d"):format(elapsed,
			status.completed, status.total))
	end
	if elapsed >= stop_after or status.ready then
		stopping = true
		core.log("action", ("[r23s] stop t=%.1f completed=%d/%d ready=%s"):format(
			elapsed, status.completed, status.total, tostring(status.ready)))
		core.request_shutdown("r23 bounded run complete", false, 0)
	end
end)
