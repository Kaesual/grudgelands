-- Preparing a slot (Round 71, the sequence lane SPIKE measured): one preparation
-- at a time, driven by a core.after(0) chain that runs only while one is under
-- way, so an idle server pays nothing.
--
-- 1. Live objects out and core.delete_area: stale nodes, meta, timers and saved
--    mobs are gone, also after a restart. delete_area keeps live objects
--    (l_env.cpp ModApiEnv::l_delete_area), so they go first.
-- 2. Generate the box +- 16, one chunk at a time, each asked by one block, so a
--    player's own emerge waits for at most that chunk. A chunk that comes back
--    cancelled is asked again.
-- 3. The clearing pass: every mapblock of the box solid. Slices opening air
--    beside natural cave water let it flow; the water guard then leaves
--    grug_core:water_barrier nodes in the box.
-- 4. The template, mapblock by mapblock.
--
-- Steps 3 and 4 write BLOCKS_PER_STEP mapblocks per server step, each through its
-- own VoxelManip, with the engine's own light. VoxelManip writes no meta and no
-- timers: on_ready's listeners set theirs after the last block.
local M = {}
local catalogue, send_out

-- Gives up on one chunk after this many refusals in a row.
local MAX_EMERGE_TRIES = 30
-- chunksize 5 (minetest.conf): a mapchunk is 80 nodes, its corner at 80 k - 32.
local CHUNK = 80

local queue = {}
local job -- the one preparation under way
local running = false

function M.init(rows, on_player_in_box)
	catalogue, send_out = rows, on_player_in_box
end

local function chunk_index(v) return math.floor((v + 32) / CHUNK) end

-- One block in the middle of every chunk of the box and its margin.
local function chunks_of(minp, maxp)
	local margin, list = catalogue.EMERGE_MARGIN, {}
	for kz = chunk_index(minp.z - margin), chunk_index(maxp.z + margin) do
		for ky = chunk_index(minp.y - margin), chunk_index(maxp.y + margin) do
			for kx = chunk_index(minp.x - margin), chunk_index(maxp.x + margin) do
				list[#list + 1] = {x = CHUNK * kx - 32 + 40, y = CHUNK * ky - 32 + 40,
					z = CHUNK * kz - 32 + 40}
			end
		end
	end
	return list
end

-- The mapblocks from minp over `size` nodes, as corners.
local function blocks_of(minp, size)
	local list = {}
	for z = 0, size.z - 16, 16 do
		for y = 0, size.y - 16, 16 do
			for x = 0, size.x - 16, 16 do
				local a = {x = minp.x + x, y = minp.y + y, z = minp.z + z}
				list[#list + 1] = {a, {x = a.x + 15, y = a.y + 15, z = a.z + 15}}
			end
		end
	end
	return list
end

local data_buffer, param2_buffer = {}, {}

local function seal_block(area)
	local solid = core.get_content_id(catalogue.CLEAR_NODE)
	for i = 1, 4096 do
		data_buffer[i], param2_buffer[i] = solid, 0
	end
	local vm = VoxelManip()
	vm:read_from_map(area[1], area[2])
	vm:set_data(data_buffer)
	vm:set_param2_data(param2_buffer)
	vm:write_to_map(true)
end

local function write_block(tpl, minp, area)
	local byte = string.byte
	local cells, ids = tpl.cells, tpl.ids
	local sx, rows = tpl.size.x, tpl.size.x * tpl.size.y
	local total = rows * tpl.size.z
	local x0 = area[1].x - minp.x
	local y0, z0 = area[1].y - minp.y, area[1].z - minp.z
	local n = 0
	for z = z0, z0 + 15 do
		for y = y0, y0 + 15 do
			local base = z * rows + y * sx + x0
			for x = 1, 16 do
				n = n + 1
				data_buffer[n] = ids[byte(cells, base + x)]
				param2_buffer[n] = byte(cells, total + base + x)
			end
		end
	end
	local vm = VoxelManip()
	vm:read_from_map(area[1], area[2])
	vm:set_data(data_buffer)
	vm:set_param2_data(param2_buffer)
	vm:write_to_map(true)
end

local function clear_box(minp, maxp)
	for object in core.objects_in_area(minp, maxp) do
		if object:is_player() then send_out(object) else object:remove() end
	end
	-- false only says a block could not go; generation and both passes still run.
	if not core.delete_area(minp, maxp) then
		core.log("warning", "[grug_expeditions] delete_area incomplete at " ..
			core.pos_to_string(minp))
	end
end

-- One server step of a job, by its phase; "done" or "failed" ends the job.
local PHASES = {}

function PHASES.clear(work)
	local run = work.run
	clear_box(run.minp, run.maxp)
	work.chunks, work.chunk = chunks_of(run.minp, run.maxp), 1
	work.phase = "generate"
end

function PHASES.generate(work)
	local ask = work.ask
	if ask then
		if ask.left ~= 0 then return end -- the callback has not finished the chunk
		work.ask = nil
		if ask.refused then
			work.tries = work.tries + 1
			if work.tries >= MAX_EMERGE_TRIES then return "failed" end
		else
			work.chunk, work.tries = work.chunk + 1, 0
		end
	end
	local at = work.chunks[work.chunk]
	if not at then
		work.blocks, work.block = blocks_of(work.run.minp, catalogue.BOX), 1
		work.phase = "seal"
		return
	end
	local request = {}
	work.ask = request
	-- Only flags here: the callback is not the place to act on the map.
	core.emerge_area(at, at, function(_, action, left)
		if action == core.EMERGE_CANCELLED or action == core.EMERGE_ERRORED then
			request.refused = true
		end
		request.left = left
	end)
end

function PHASES.seal(work)
	for _ = 1, catalogue.BLOCKS_PER_STEP do
		local area = work.blocks[work.block]
		if not area then
			work.blocks, work.block = blocks_of(work.run.minp, work.tpl.size), 1
			work.phase = "write"
			return
		end
		seal_block(area)
		work.block = work.block + 1
	end
end

function PHASES.write(work)
	for _ = 1, catalogue.BLOCKS_PER_STEP do
		local area = work.blocks[work.block]
		if not area then return "done" end
		write_block(work.tpl, work.run.minp, area)
		work.block = work.block + 1
	end
end

local function pump()
	if not job then
		job = table.remove(queue, 1)
		if not job then
			running = false
			return
		end
	end
	local work = job
	local result = PHASES[work.phase](work)
	if result then
		job = nil
		work.finish(result == "done")
	end
	core.after(0, pump)
end

-- Starts preparing `run` (minp, maxp) from `tpl`. finish(ok) runs on a server
-- step after the last block, or with false when the map refused the box.
function M.enqueue(run, tpl, finish)
	queue[#queue + 1] = {run = run, tpl = tpl, finish = finish, phase = "clear", tries = 0}
	if not running then
		running = true
		core.after(0, pump)
	end
end

-- Drops `run`'s preparation; a half written box is cleared by the next one.
function M.cancel(run)
	if job and job.run == run then job = nil end
	for index, work in ipairs(queue) do
		if work.run == run then
			table.remove(queue, index)
			return
		end
	end
end

-- How far `run` is: {waiting = preparations before it} or {phase, done, total}
-- ("clear", "generate", "seal", "write"), nil when none is under way for it.
function M.status(run)
	if job and job.run == run then
		local total = job.blocks and #job.blocks or job.chunks and #job.chunks or 0
		return {phase = job.phase, done = (job.block or job.chunk or 1) - 1, total = total}
	end
	for index, work in ipairs(queue) do
		if work.run == run then return {waiting = index - 1 + (job and 1 or 0)} end
	end
end

return M
