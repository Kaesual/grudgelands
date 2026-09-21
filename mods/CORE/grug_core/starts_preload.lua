-- One world-bound preparation scheduler, dispatched only by server steps.
local plan_api = dofile(core.get_modpath("grug_core") .. "/preparation_plan.lua")
local storage = core.get_mod_storage()
local STORAGE_KEY = "world_preparation"
local selected = core.settings:get_bool("grug_prepare_full_world", false) and "full" or "starts"
local saved = storage:get_string(STORAGE_KEY)
local state = saved ~= "" and core.deserialize(saved) or nil
if saved ~= "" then
	assert(type(state) == "table" and (state.mode == "full" or state.mode == "starts"),
		"Invalid world preparation state; restore this world's storage from backup")
	if selected ~= state.mode then
		core.log("warning", "[grug_core] preparation config ignored: this world's immutable mode is " .. state.mode)
	end
else
	state = {mode = selected}
	-- Bind the mode before resolving anchors or queueing any native work.
	storage:set_string(STORAGE_KEY, core.serialize(state))
end
local pending, stopped, failed = false, false, false
local attempts, retry_at, elapsed, samples = 0, 0, 0, 0
local clock, accumulator = 0, 0
local listeners, start_listeners, races = {}, {}, {}
local notify = true
local was_ready = false
local function persist() storage:set_string(STORAGE_KEY, core.serialize(state)) end
local function ready() return state.total ~= nil and state.cursor == state.total end
function grug_core.world_preparation_status()
	local done, total = state.cursor or 0, state.total or 0
	return {mode=state.mode,completed=done,total=total,
		percent=total > 0 and done*100/total or 0, ready=ready(),failed=failed,
		eta_seconds=samples >= 3 and elapsed/samples*(total-done) or nil}
end
function grug_core.register_on_preparation_progress(fn) listeners[#listeners+1] = fn end
function grug_core.starts_ready() return ready() and 6 or 0, 6 end
function grug_core.start_ready(race) return races[race] == true and ready() end
function grug_core.starts_preload_failed() return failed end
function grug_core.register_on_starts_progress(fn) start_listeners[#start_listeners+1] = fn end
-- Explicit retry from the waiting screen preserves the immutable plan/prefix.
function grug_core.request_starts_preload()
	if failed and not pending and not stopped then
		failed, attempts, retry_at, notify = false, 0, 0, true
	end
	return not failed
end
local function initialize()
	local identities = grug_core.start_identities()
	assert(#identities == 6, "Preparation requires six authenticated start identities")
	for _, row in ipairs(identities) do races[row.race_id] = true end
	local geometry = core.get_mapgen_chunksize()
	if not state.total then
		state = plan_api.new(state.mode, geometry, identities)
		persist()
	else
		assert(state.order == "z-y-x" and type(state.cursor) == "number" and
			state.cursor >= 0 and state.cursor <= state.total and state.cursor % 1 == 0,
			"Invalid persisted preparation cursor/order")
		for _, axis in ipairs({"x","y","z"}) do
			assert(state.geometry[axis] == geometry[axis],
				"World preparation chunk geometry changed; restore the original mapgen settings")
		end
	end
	core.log("action", ("[grug_core] world preparation mode=%s cursor=%d/%d"):
		format(state.mode,state.cursor,state.total))
end
local function dispatch()
	pending = true
	attempts = attempts + 1
	local index = state.cursor + 1
	local lo, hi = plan_api.unit(state, index)
	local expected, total = plan_api.expected(lo,hi)
	local count, bad = 0, false
	local started = core.get_us_time()
	core.emerge_area(lo,hi,function(pos,action,remaining)
		if action ~= core.EMERGE_GENERATED and action ~= core.EMERGE_FROM_MEMORY and
				action ~= core.EMERGE_FROM_DISK then bad = true end
		local key = plan_api.key(pos)
		if expected[key] and not bad then expected[key] = false; count = count + 1 end
		if remaining ~= 0 then return end
		if not bad and count == total then
			state.cursor = index
			persist()
			elapsed = elapsed + (core.get_us_time()-started)/1000000
			samples, attempts = samples + 1, 0
		else
			retry_at = clock + 5
			if attempts >= 3 then
				failed = true
				core.log("error", "[grug_core] preparation stopped at chunk " .. index ..
					" after 3 failed attempts. Check emerge/mapgen errors, then retry or restart.")
			end
		end
		-- Never dispatch here: cancellation callbacks hold the native queue
		-- lock. Shutdown stops server steps BEFORE workers settle callbacks.
		pending, notify = false, true
	end)
end
core.register_on_mods_loaded(initialize)
core.register_on_shutdown(function() stopped = true end)
core.register_globalstep(function(dtime)
	accumulator = accumulator + dtime
	if accumulator < 0.2 then return end
	clock = clock + accumulator
	accumulator = 0
	if stopped then return end
	if notify then
		notify = false
		local status = grug_core.world_preparation_status()
		for _, fn in ipairs(listeners) do fn(status) end
		if status.ready ~= was_ready or failed then
			was_ready = status.ready
			for _, fn in ipairs(start_listeners) do fn(status.ready and 6 or 0,6,failed) end
		end
	end
	if state.total and not ready() and not pending and not failed and clock >= retry_at then dispatch() end
end)
