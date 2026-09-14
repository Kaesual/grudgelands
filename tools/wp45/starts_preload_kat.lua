-- Compact real-code KAT for grug_core's startup preload of all six start
-- areas (user decision 2026-09-14). Drives the production module with faked
-- emerge callbacks: normal completion, the concurrency cap, cancellation on
-- shutdown, the bounded retry, a permanent failure and a restart in which
-- every block comes back from disk.
--
-- Runs under LuaJIT and tools/bin/lua51 alike; prints one canonical digest.

local repo = arg[1] or "."

local function assert_equal(actual, expected, context)
	if actual ~= expected then
		error((context or "value") .. ": expected " .. tostring(expected) ..
			", got " .. tostring(actual), 2)
	end
end

local ANCHORS = {
	{race_id = "dwarf", faction_id = "accord", x = -550, y = 40, z = -900},
	{race_id = "human", faction_id = "accord", x = 10, y = 30, z = -900},
	{race_id = "elf", faction_id = "accord", x = 560, y = 35, z = -900},
	{race_id = "undead", faction_id = "throng", x = -550, y = 20, z = 900},
	{race_id = "orc", faction_id = "throng", x = 10, y = 35, z = 900},
	{race_id = "troll", faction_id = "throng", x = 560, y = 25, z = 900},
}

local harness = {}

local function reset(identity_count)
	harness = {
		requests = {},
		after_queue = {},
		mods_loaded = {},
		logs = {},
		progress = {},
		open = 0,
		max_open = 0,
		clock = 0,
	}
	grug_core = {}
	function grug_core.start_identities()
		local result = {}
		for i = 1, (identity_count or #ANCHORS) do
			local row = ANCHORS[i]
			result[i] = {
				race_id = row.race_id,
				faction_id = row.faction_id,
				anchor = {x = row.x, y = row.y, z = row.z},
			}
		end
		return result
	end
	core = {
		EMERGE_GENERATED = 1,
		EMERGE_FROM_MEMORY = 2,
		EMERGE_FROM_DISK = 3,
		EMERGE_CANCELLED = 4,
		EMERGE_ERRORED = 5,
		get_us_time = function()
			harness.clock = harness.clock + 250000
			return harness.clock
		end,
		log = function(level, message)
			harness.logs[#harness.logs + 1] = level .. "|" .. message
		end,
		after = function(delay, fn)
			harness.after_queue[#harness.after_queue + 1] = {delay = delay, fn = fn}
		end,
		register_on_mods_loaded = function(fn)
			harness.mods_loaded[#harness.mods_loaded + 1] = fn
		end,
		emerge_area = function(pos1, pos2, callback)
			-- HARD RULE: the engine self-deadlocks if a block is enqueued from
			-- inside an emerge completion callback (src/emerge.cpp:302 vs
			-- :494-508), so every enqueue must come from a scheduled job.
			assert(not harness.in_callback,
				"core.emerge_area called from inside an emerge callback")
			harness.open = harness.open + 1
			if harness.open > harness.max_open then
				harness.max_open = harness.open
			end
			harness.requests[#harness.requests + 1] = {
				pos1 = pos1, pos2 = pos2, callback = callback, done = false,
			}
		end,
	}
end

-- Delivers `blocks` callbacks for one queued emerge request. `action` is used
-- for the FIRST block; every other block reports an ordinary terminal action.
local function deliver(index, action, blocks)
	local request = harness.requests[index]
	assert(request and not request.done, "emerge request " .. index)
	request.done = true
	harness.open = harness.open - 1
	blocks = blocks or 3
	harness.in_callback = true
	for block = 1, blocks do
		request.callback({x = block, y = 0, z = 0},
			block == 1 and action or core.EMERGE_GENERATED, blocks - block)
	end
	harness.in_callback = false
end

-- Which start a queued request belongs to, read back from its envelope.
local function request_race(request)
	for i = 1, #ANCHORS do
		if request.pos1.x == ANCHORS[i].x - 64 and
				request.pos1.z == ANCHORS[i].z - 64 then
			return ANCHORS[i].race_id
		end
	end
	error("unknown emerge envelope")
end

local function first_open_request()
	for i = 1, #harness.requests do
		if not harness.requests[i].done then
			return i
		end
	end
	return nil
end

local function run_after()
	while #harness.after_queue > 0 do
		local pending = harness.after_queue
		harness.after_queue = {}
		for index = 1, #pending do
			pending[index].fn()
		end
	end
end

-- Delivers every queued request, choosing each one's first-block action by
-- start, until nothing is in flight any more. Terminates because the module
-- retries a failing start only a bounded number of times.
local function drive(action_for_race)
	local index = first_open_request()
	while index do
		deliver(index, action_for_race(request_race(harness.requests[index])))
		run_after()
		index = first_open_request()
	end
end

local function boot(identity_count)
	reset(identity_count)
	dofile(repo .. "/mods/CORE/grug_core/starts_preload.lua")
	grug_core.register_on_starts_progress(function(ready, total, failed)
		harness.progress[#harness.progress + 1] =
			ready .. "/" .. total .. (failed and "!" or "")
	end)
	assert_equal(#harness.mods_loaded, 1, "mods_loaded registrations")
	harness.mods_loaded[1]()
	run_after()
end

local function count_logs(pattern)
	local total = 0
	for i = 1, #harness.logs do
		if harness.logs[i]:find(pattern, 1, true) then
			total = total + 1
		end
	end
	return total
end

--
-- 1. Cold start: six starts, never more than two emerges in flight.
--
boot()
local ready, total = grug_core.starts_ready()
assert_equal(ready, 0, "cold ready count")
assert_equal(total, 6, "cold total count")
assert_equal(#harness.requests, 2, "cold concurrent requests")
assert_equal(count_logs("start preload: emerging 6 start areas"), 1,
	"cold start log")

-- The requested volume is the 128 x 128 build envelope and the vertical
-- extent character creation used before (spawn - 24 .. spawn + 80).
local first = harness.requests[1]
assert_equal(first.pos1.x, -550 - 64, "envelope min x")
assert_equal(first.pos2.x, -550 + 63, "envelope max x")
assert_equal(first.pos1.z, -900 - 64, "envelope min z")
assert_equal(first.pos2.z, -900 + 63, "envelope max z")
assert_equal(first.pos1.y, 41 - 24, "envelope min y")
assert_equal(first.pos2.y, 41 + 80, "envelope max y")

for index = 1, 6 do
	deliver(index, core.EMERGE_GENERATED)
	ready = grug_core.starts_ready()
	assert_equal(ready, index, "ready after start " .. index)
	-- The replacement request is enqueued by a scheduled job, never by the
	-- callback that just completed.
	if index < 6 then
		assert_equal(#harness.requests, math.min(index + 1, 6),
			"no synchronous re-entry after start " .. index)
	end
	run_after()
	if index < 6 then
		assert_equal(#harness.requests, math.min(index + 2, 6),
			"queued requests after start " .. index)
	end
end
assert_equal(harness.max_open, 2, "concurrency cap")
assert_equal(#harness.requests, 6, "total requests on a cold start")
assert_equal(grug_core.start_ready("dwarf"), true, "dwarf ready")
assert_equal(grug_core.start_ready("troll"), true, "troll ready")
assert_equal(grug_core.start_ready("gnome"), false, "unknown race ready")
assert_equal(grug_core.starts_preload_failed(), false, "cold failure flag")
assert_equal(count_logs("start area ready:"), 6, "per-start action logs")
assert_equal(count_logs("all 6 start areas ready after"), 1, "completion log")
assert_equal(#harness.progress, 6, "progress notifications")
assert_equal(harness.progress[6], "6/6", "final progress notification")
-- Nothing is logged per block: 1 opening + 6 completions + 1 summary.
assert_equal(#harness.logs, 8, "log line count")

--
-- 2. Shutdown cancellation: a cancelled start is never counted ready and
--    never persisted; the bounded retry re-requests it and it then completes.
--
boot()
deliver(1, core.EMERGE_CANCELLED)
assert_equal(#harness.requests, 2,
	"a cancelled callback enqueues nothing synchronously")
run_after()
assert_equal(grug_core.starts_ready(), 0, "cancelled start is not ready")
assert_equal(grug_core.start_ready("dwarf"), false, "cancelled dwarf")
assert_equal(grug_core.starts_preload_failed(), false,
	"a first cancellation is not a permanent failure")
assert_equal(#harness.progress, 0, "cancellation sends no progress")
-- The one cancellation above was attempt 1; everything else succeeds.
drive(function() return core.EMERGE_FROM_DISK end)
assert_equal(#harness.requests, 7, "cancellation re-requested exactly one start")
assert_equal(grug_core.starts_ready(), 6, "every start ready after the retry")
assert_equal(grug_core.start_ready("dwarf"), true, "retried dwarf")
assert_equal(count_logs("did not complete (attempt 1)"), 1, "retry warning")

--
-- 3. A start that keeps erroring is refused after its bounded attempts and
--    becomes the retryable failure state; an explicit re-request clears it.
--
boot()
drive(function(race)
	return race == "dwarf" and core.EMERGE_ERRORED or core.EMERGE_FROM_DISK
end)
assert_equal(grug_core.starts_preload_failed(), true, "permanent failure flag")
assert_equal(grug_core.starts_ready(), 5, "five starts ready, one refused")
assert_equal(grug_core.start_ready("dwarf"), false, "permanently failed dwarf")
assert_equal(harness.progress[#harness.progress], "5/6!", "failure progress")
assert_equal(count_logs("could not be prepared after 3 attempts"), 1,
	"permanent failure log")
assert_equal(grug_core.request_starts_preload(), true, "manual re-request")
assert_equal(grug_core.starts_preload_failed(), false, "failure flag cleared")
drive(function() return core.EMERGE_FROM_DISK end)
assert_equal(grug_core.starts_ready(), 6, "re-requested start is ready")

--
-- 4. Restart after a shutdown: the preload is requested again and every
--    block comes back from disk, so all six complete without regenerating.
--
boot()
for index = 1, 6 do
	deliver(index, core.EMERGE_FROM_DISK, 1)
	run_after()
end
ready, total = grug_core.starts_ready()
assert_equal(ready, 6, "restart ready count")
assert_equal(total, 6, "restart total count")
assert_equal(#harness.requests, 6, "restart request count")
-- Requesting again after completion emerges nothing a second time.
assert_equal(grug_core.request_starts_preload(), true, "idle re-request")
run_after()
assert_equal(#harness.requests, 6, "idle re-request emerges nothing")

--
-- 5. A world authority that publishes the wrong number of starts fails loudly
--    and becomes the retryable failure state instead of an endless wait.
--
boot(5)
assert_equal(#harness.requests, 0, "incomplete authority emerges nothing")
assert_equal(grug_core.starts_preload_failed(), true, "incomplete authority")
assert_equal(count_logs("start anchors instead of 6"), 1,
	"incomplete authority log")

print(table.concat({
	"wp45_starts_preload_v1",
	"cold_requests=6",
	"max_concurrent=2",
	"cancel_retries=1",
	"permanent_failures=1",
	"restart_from_disk=6",
	"callback_reentry=0",
}, "|"))
