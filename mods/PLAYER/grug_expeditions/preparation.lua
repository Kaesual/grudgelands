-- Preparing a slot (Round 71, the sequence lane SPIKE measured, corrected by its
-- review): one preparation at a time, driven by a core.after(0) chain that runs
-- only while one is under way, so an idle server pays nothing. Every phase's work
-- is counted, BLOCKS_PER_STEP mapblocks per server step, never a clock.
--
-- 1. Live objects out: core.delete_area keeps them (l_env.cpp ModApiEnv::l_delete_area).
-- 2. core.delete_area, mapblock by mapblock: stale nodes, meta, timers and saved
--    mobs go, also after a restart. One call over the box would be 256 synchronous
--    database round trips in one server step (upstream-workarounds.md).
-- 3. Generate the box +- 16, one chunk at a time, each asked by the one block at its
--    centre, so a player's own emerge waits for at most that chunk. A chunk that
--    comes back cancelled (being generated for someone else) is asked again. A
--    deleted block alone makes the engine generate its chunk: an asked block still
--    in the map would answer at once and leave the deleted ones empty, so every
--    chunk holding a block of the box must have its centre in the box.
--    catalogue.chunks_of and the fixture hold this for all 100 slots.
-- 4. The gate: every block of the box +- 16 is asked once more and must answer as
--    already generated (emerge.cpp EmergeThread::run calls back after finishGen and
--    getBlockOrStartGen answers memory or disk only for a generated block). A chunk
--    generated after the template would write its one block border into the box:
--    all chunks round the box are done before the first write.
-- 5. The clearing pass: every mapblock of the box solid. Slices opening air beside
--    natural cave water let it flow; the water guard then leaves
--    grug_core:water_barrier nodes in the box.
-- 6. The template, mapblock by mapblock.
--
-- Each write has its own VoxelManip and the engine's own light. VoxelManip writes no
-- meta and no timers: on_ready's listeners set theirs after the last block.
local M = {}
local catalogue, send_out

-- Gives up on a chunk, or on the gate, after this many answers in a row.
local MAX_EMERGE_TRIES = 30
local queue = {}
local job -- the one preparation under way
local running = false

function M.init(rows, on_player_in_box)
	catalogue, send_out = rows, on_player_in_box
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

-- One server step of a job, by its phase; "done" or "failed" ends the job.
local PHASES = {}

function PHASES.clear(work)
	local run = work.run
	for object in core.objects_in_area(run.minp, run.maxp) do
		if object:is_player() then
			send_out(object)
		elseif not object:get_attach() then -- a player's tag stays with them
			object:remove()
		end
	end
	work.blocks, work.block = blocks_of(run.minp, catalogue.BOX), 1
	work.phase = "delete"
end

function PHASES.delete(work)
	for _ = 1, catalogue.BLOCKS_PER_STEP do
		local area = work.blocks[work.block]
		if not area then
			work.chunks, work.chunk = catalogue.chunks_of(work.run.slot), 1
			work.blocks, work.block = nil, nil
			work.phase = "generate"
			return
		end
		if not core.delete_area(area[1], area[2]) then
			core.log("warning", "[grug_expeditions] delete_area refused " ..
				core.pos_to_string(area[1]))
		end
		work.block = work.block + 1
	end
end

-- Asks for p1..p2 once. Only flags in the callback: it runs on the emerge thread.
local function ask(p1, p2)
	local request = {}
	core.emerge_area(p1, p2, function(_, action, left)
		if action == core.EMERGE_CANCELLED or action == core.EMERGE_ERRORED then
			request.refused = true
		elseif action == core.EMERGE_GENERATED then
			request.generated = true
		end
		request.left = left
	end)
	return request
end

function PHASES.generate(work)
	local request = work.request
	if request then
		if request.left ~= 0 then return end
		work.request = nil
		if request.refused then
			work.tries = work.tries + 1
			if work.tries >= MAX_EMERGE_TRIES then return "failed" end
		else
			work.chunk, work.tries = work.chunk + 1, 0
		end
	end
	local at = work.chunks[work.chunk]
	if at then
		work.request = ask(at, at)
	else
		work.phase = "gate"
	end
end

function PHASES.gate(work)
	local request = work.request
	if request then
		if request.left ~= 0 then return end
		work.request = nil
		if not request.refused and not request.generated then
			work.blocks, work.block = blocks_of(work.run.minp, catalogue.BOX), 1
			work.phase = "seal"
			return
		end
		work.gates = work.gates + 1
		if work.gates >= MAX_EMERGE_TRIES then return "failed" end
	end
	local margin = catalogue.EMERGE_MARGIN
	work.request = ask(vector.offset(work.run.minp, -margin, -margin, -margin),
		vector.offset(work.run.maxp, margin, margin, margin))
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
		core.log("action", ("[grug_expeditions] slot %d %s, %d more gate passes"):format(
			work.run.slot, result == "done" and "prepared" or "NOT prepared", work.gates))
		work.finish(result == "done")
	end
	core.after(0, pump)
end

-- Starts preparing `run` (minp, maxp) from `tpl`. finish(ok) runs on a server
-- step after the last block, or with false when the map refused the box.
function M.enqueue(run, tpl, finish)
	queue[#queue + 1] = {run = run, tpl = tpl, finish = finish, phase = "clear", tries = 0, gates = 0}
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
-- ("clear", "delete", "generate", "gate", "seal", "write"), nil when none is under
-- way for it.
function M.status(run)
	if job and job.run == run then
		local list = job.blocks or job.chunks
		local total = list and #list or 0
		return {phase = job.phase, done = (job.block or job.chunk or 1) - 1, total = total}
	end
	for index, work in ipairs(queue) do
		if work.run == run then return {waiting = index - 1 + (job and 1 or 0)} end
	end
end

return M
