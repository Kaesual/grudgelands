-- Disposable-copy observation and bounded stop; never shipped to players.
local diag_prefix_limit = 563
local diag_mode = "stop_pending"
local diag = {steps=0,scan_steps=0,scan_us=0,persist_us=0,persists=0,
 actions={},dispatches=0,callbacks=0,inflight=0,max_inflight=0}
local diag_last, diag_step, diag_complete = core.get_us_time(), nil, nil
local diag_scan_started, diag_step_scan_us, diag_step_scanned = nil, 0, false
local function diag_log(kind, data)
 core.log("action", "[pregen_diag] " .. core.write_json({us=core.get_us_time(),kind=kind,data=data}))
end
local function diag_scan_done()
 local duration=core.get_us_time()-diag_scan_started
 if not diag_step_scanned then diag.scan_steps=diag.scan_steps+1;diag_step_scanned=true end
 diag.scan_us=diag.scan_us+duration
 diag_step_scan_us=diag_step_scan_us+duration
 diag.scan_max_us=math.max(diag.scan_max_us or 0,diag_step_scan_us)
 diag_scan_started=nil
end
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
local source, scan
local tile_elapsed = 0
local queue, planner = {}, nil
local stopped, failed = false, false
local elapsed, samples = 0, 0
local clock, notification_elapsed = 0, 0
-- UI updates remain at 5 Hz; work may resume on the next server step.
local NOTIFY_INTERVAL, MAX_INFLIGHT = 0.2, 2
-- Only unfinished full preparation scans columns; ready worlds and starts-only
-- preparation never enter this budgeted branch or alter on-demand emergence.
local FULL_PREPARATION_SCAN_BUDGET_US, SCAN_BATCH, SCAN_LIMIT = 100000, 16, 8192
local listeners, start_listeners, races = {}, {}, {}
local notify = true
local was_ready = false
local function persist() local t=core.get_us_time(); storage:set_string(STORAGE_KEY, core.serialize(state)); diag.persist_us=diag.persist_us+core.get_us_time()-t;diag.persists=diag.persists+1 end
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
	if failed and not stopped then
		for _, row in ipairs(queue) do
			if row.status == "pending" then return false end
		end
		for _, row in ipairs(queue) do
			if row.status == "retry" then row.attempts, row.retry_at = 0, 0 end
		end
		failed, notify = false, true
	end
	return not failed
end
local function selection_copy(tile)
	if not tile then return nil end
	local copy = {}
	for k, v in pairs(tile) do copy[k] = v end
	return copy
end
local function initialize()
	local identities = grug_core.start_identities()
	assert(#identities == 6, "Preparation requires six authenticated start identities")
	for _, row in ipairs(identities) do races[row.race_id] = true end
	local geometry = core.get_mapgen_chunksize()
	if state.mode == "full" then
		local authority = grug_mapgen and grug_mapgen.wp40
		assert(core.get_mapgen_setting("mg_name") == "v7" and authority and
			authority.production_enabled and authority.preparation_source,
			"Full preparation requires the current Grudgelands v7 surface authority")
		source = authority.preparation_source
		assert(type(source.identity) == "string" and type(source.tile_bounds) == "function" and
			type(source.column_bounds) == "function", "Invalid surface preparation authority")
	end
	if not state.total then
		state = plan_api.new(state.mode, geometry, identities)
		state.authority = source and source.identity or nil
		persist()
	else
		assert(state.order == (state.mode == "full" and "z-x-local-y-v1" or "z-y-x") and type(state.cursor) == "number" and
			state.cursor >= 0 and state.cursor <= state.total and state.cursor % 1 == 0,
			"Invalid persisted preparation cursor/order")
		for _, axis in ipairs({"x","y","z"}) do
			assert(state.geometry[axis] == geometry[axis],
				"World preparation chunk geometry changed; restore the original mapgen settings")
		end
		if source then
			assert(state.authority == source.identity,
				"Surface preparation authority changed; restore the original game and mapgen settings")
			local tile = state.selection
			if tile then
				assert(tile.index == state.cursor+1 and tile.inner >= 0 and tile.inner % 1 == 0 and
					tile.y_min+tile.inner*geometry.y*16 <= tile.y_max,
					"Invalid persisted surface preparation selection")
			end
		end
	end
	-- Immutable geometry/bounds may be shared; speculative cursor/selection may not.
	planner = {}
	for k, v in pairs(state) do planner[k] = v end
	planner.selection = selection_copy(state.selection)
	tile_elapsed = core.get_us_time()
	core.log("action", ("[grug_core] world preparation mode=%s cursor=%d/%d"):
		format(state.mode,state.cursor,state.total))
end
-- Only a successful contiguous prefix is durable. Future selections and outcomes
-- are bounded, ephemeral lookahead and may be recomputed/replayed after restart.
local function commit_prefix()
	while queue[1] and queue[1].status == "success" do
		local row = table.remove(queue, 1)
		state.selection = selection_copy(row.selection)
		local completed = plan_api.complete(state)
		if completed then
			local now = core.get_us_time()
			elapsed = elapsed + (now - tile_elapsed) / 1000000
			tile_elapsed, samples = now, samples + 1
		end
		if queue[1] then state.selection = selection_copy(queue[1].selection) end
		persist()
	end
end
local function dispatch(row)
 local diag_started=core.get_us_time()
 diag.dispatches=diag.dispatches+1
 local diag_request_id=diag.dispatches
 local diag_actions, diag_first_callback = {}, true
 diag.inflight=diag.inflight+1;diag.max_inflight=math.max(diag.max_inflight,diag.inflight)
 diag_log("dispatch",{id=diag_request_id,cursor=state.cursor,planned_cursor=row.index-1,
  selection=row.selection,lo=row.lo,hi=row.hi,inflight=diag.inflight,queue_depth=#queue,
  gap_us=diag_complete and diag_started-diag_complete or nil})
	row.status, row.attempts = "pending", row.attempts + 1
	local expected, total = plan_api.expected(row.lo, row.hi)
	local count, bad = 0, false
	core.emerge_area(row.lo,row.hi,function(pos,action,remaining)
  diag.callbacks=diag.callbacks+1
  local diag_action=tostring(action)
  diag.actions[diag_action]=(diag.actions[diag_action] or 0)+1
  diag_actions[diag_action]=(diag_actions[diag_action] or 0)+1
  if diag_first_callback then
   diag_first_callback=false
   diag_log("first_callback",{id=diag_request_id,action=action,remaining=remaining})
  end
		if action ~= core.EMERGE_GENERATED and action ~= core.EMERGE_FROM_MEMORY and
				action ~= core.EMERGE_FROM_DISK then bad = true end
		local key = plan_api.key(pos)
		if expected[key] and not bad then expected[key] = false; count = count + 1 end
		if remaining ~= 0 then return end
		if not bad and count == total then
			row.status = "success"
			commit_prefix()
		else
			row.status, row.retry_at = "retry", clock + 5
			if row.attempts >= 3 then
				failed = true
				core.log("error", "[grug_core] preparation stopped at tile/chunk " .. row.index ..
					" after 3 failed attempts. Check emerge/mapgen errors, then retry or restart.")
			end
		end
		-- Never dispatch here: cancellation callbacks hold the native queue
		-- lock. Shutdown stops server steps BEFORE workers settle callbacks.
		notify = true
  diag.inflight=diag.inflight-1
  diag_complete=core.get_us_time()
  diag_log("complete",{id=diag_request_id,duration_us=diag_complete-diag_started,
   cursor=state.cursor,selection=state.selection,request_actions=diag_actions,
   actions=diag.actions,inflight=diag.inflight,queue_depth=#queue,status=row.status})
	end)
end
core.register_on_mods_loaded(initialize)
core.register_on_shutdown(function() stopped = true end)
core.register_globalstep(function(dtime)
	if stopped then return end
 if (diag_mode=="stop_pending" and diag.inflight==2) or
   (diag_mode~="stop_pending" and state.cursor==diag_prefix_limit and #queue==0 and diag.inflight==0) then
  stopped=true
  diag_log("stop_request",{mode=diag_mode,cursor=state.cursor,inflight=diag.inflight,queue_depth=#queue})
  core.request_shutdown("bounded preparation measurement complete",false,0)
  return
 end
 local diag_now=core.get_us_time()
 diag.steps=diag.steps+1
 if diag_step then
  local delta=diag_now-diag_step
  diag.step_us=(diag.step_us or 0)+delta
  diag.step_max_us=math.max(diag.step_max_us or 0,delta)
  diag.step_hist=diag.step_hist or {}
  local bucket=tostring(math.floor(delta/1000))
  diag.step_hist[bucket]=(diag.step_hist[bucket] or 0)+1
 end
 diag_step=diag_now
 diag_step_scan_us,diag_step_scanned=0,false
 if diag_now-diag_last>=5000000 then
  diag.cursor=state.cursor;diag.selection=state.selection;diag.scan=scan
  diag.queue_depth=#queue;diag.planner_cursor=planner and planner.cursor;diag.failed=failed
  diag_log("sample",diag)
  diag={steps=0,scan_steps=0,scan_us=0,persist_us=0,persists=0,
   actions=diag.actions,dispatches=diag.dispatches,callbacks=diag.callbacks,
   inflight=diag.inflight,max_inflight=diag.max_inflight}
  diag_last=diag_now
 end
	clock = clock + dtime
	notification_elapsed = notification_elapsed + dtime
	if notify and notification_elapsed >= NOTIFY_INTERVAL then
		notification_elapsed = 0
		notify = false
		local status = grug_core.world_preparation_status()
		for _, fn in ipairs(listeners) do fn(status) end
		if status.ready ~= was_ready or failed then
			was_ready = status.ready
			for _, fn in ipairs(start_listeners) do fn(status.ready and 6 or 0,6,failed) end
		end
	end
	if not state.total or ready() or failed then return end
	-- A gap pauses speculative filling. Existing later requests may still settle;
	-- retry their exact coordinates without discarding successful later outcomes.
	for _, row in ipairs(queue) do
		if row.status == "retry" then
			if clock >= row.retry_at then dispatch(row) end
			return
		end
	end
	local started, columns = core.get_us_time(), 0
	while #queue < MAX_INFLIGHT and planner.cursor < planner.total and planner.cursor < diag_prefix_limit do
		if source and not planner.selection then
			-- Scan while the native worker handles the preceding request. Bounds
			-- yield for UI/shutdown; there is no duty-cycle delay or busy wait.
			diag_scan_started=core.get_us_time()
			scan = scan or plan_api.begin(planner,source)
			while columns < SCAN_LIMIT do
				columns = columns + SCAN_BATCH
				if plan_api.scan(planner,scan,source,SCAN_BATCH) then scan = nil; break end
				if core.get_us_time() - started >= FULL_PREPARATION_SCAN_BUDGET_US then diag_scan_done();return end
			end
			diag_scan_done()
			if scan then return end
		end
		local index = planner.cursor + 1
		local lo, hi = plan_api.unit(planner,index)
		local row = {index=index,lo=lo,hi=hi,selection=selection_copy(planner.selection),attempts=0}
		queue[#queue+1] = row
		if #queue == 1 then
			state.selection = selection_copy(row.selection)
			persist() -- Freeze the current head selection before its first request.
		end
		plan_api.complete(planner)
		dispatch(row)
		if columns >= SCAN_LIMIT or core.get_us_time() - started >= FULL_PREPARATION_SCAN_BUDGET_US then return end
	end
end)

core.register_on_mods_loaded(function()
 diag_log("settings",{version=core.get_version(),step=core.settings:get("dedicated_server_step"),
  emerge_threads=core.settings:get("num_emerge_threads"),jit=core.global_exists("jit") and jit.version or "absent",
  seed=core.get_mapgen_setting("seed")})
 diag_log("boot",{mode=diag_mode,limit=diag_prefix_limit,status=grug_core.world_preparation_status()})
end)
core.register_on_shutdown(function()
 local rows={}
 for i,row in ipairs(queue) do rows[i]={index=row.index,status=row.status,selection=row.selection} end
 diag_log("shutdown",{queue_rows=rows,status=grug_core.world_preparation_status(),inflight=diag.inflight,
  queue_depth=#queue,selection=state.selection,dispatches=diag.dispatches,max_inflight=diag.max_inflight})
end)
