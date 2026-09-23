"""Observation plus reviewed prefix/drain or two-pending stop in a disposable copy."""


def replace_once(source, old, new):
    assert source.count(old) == 1, ('instrumentation anchor changed', old)
    return source.replace(old, new, 1)


def instrument(source, mode='prefix', limit=561):
    assert mode in ('prefix', 'stop_pending', 'resume')
    assert isinstance(limit, int) and limit >= 561
    assert 'local NOTIFY_INTERVAL, MAX_INFLIGHT = 0.2, 2' in source
    assert 'FULL_PREPARATION_SCAN_BUDGET_US, SCAN_BATCH, SCAN_LIMIT = 100000, 16, 8192' in source
    header = '''-- Disposable-copy observation and bounded stop; never shipped to players.
local diag_prefix_limit = LIMIT
local diag_mode = "MODE"
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
'''.replace('LIMIT', str(limit)).replace('MODE', mode)
    source = replace_once(source,
        'local function persist() storage:set_string(STORAGE_KEY, core.serialize(state)) end',
        'local function persist() local t=core.get_us_time(); storage:set_string(STORAGE_KEY, core.serialize(state)); diag.persist_us=diag.persist_us+core.get_us_time()-t;diag.persists=diag.persists+1 end')
    source = replace_once(source, 'local function dispatch(row)\n', '''local function dispatch(row)
 local diag_started=core.get_us_time()
 diag.dispatches=diag.dispatches+1
 local diag_request_id=diag.dispatches
 local diag_actions, diag_first_callback = {}, true
 diag.inflight=diag.inflight+1;diag.max_inflight=math.max(diag.max_inflight,diag.inflight)
 diag_log("dispatch",{id=diag_request_id,cursor=state.cursor,planned_cursor=row.index-1,
  selection=row.selection,lo=row.lo,hi=row.hi,inflight=diag.inflight,queue_depth=#queue,
  gap_us=diag_complete and diag_started-diag_complete or nil})
''')
    source = replace_once(source, 'core.emerge_area(row.lo,row.hi,function(pos,action,remaining)', '''core.emerge_area(row.lo,row.hi,function(pos,action,remaining)
  diag.callbacks=diag.callbacks+1
  local diag_action=tostring(action)
  diag.actions[diag_action]=(diag.actions[diag_action] or 0)+1
  diag_actions[diag_action]=(diag_actions[diag_action] or 0)+1
  if diag_first_callback then
   diag_first_callback=false
   diag_log("first_callback",{id=diag_request_id,action=action,remaining=remaining})
  end''')
    source = replace_once(source, '\t\tnotify = true\n\tend)', '''\t\tnotify = true
  diag.inflight=diag.inflight-1
  diag_complete=core.get_us_time()
  diag_log("complete",{id=diag_request_id,duration_us=diag_complete-diag_started,
   cursor=state.cursor,selection=state.selection,request_actions=diag_actions,
   actions=diag.actions,inflight=diag.inflight,queue_depth=#queue,status=row.status})
\tend)''')
    source = replace_once(source, '\tif stopped then return end\n', '''\tif stopped then return end
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
''')
    source = replace_once(source,
        'while #queue < MAX_INFLIGHT and planner.cursor < planner.total do',
        'while #queue < MAX_INFLIGHT and planner.cursor < planner.total and planner.cursor < diag_prefix_limit do')
    source = replace_once(source, '\t\t\tscan = scan or plan_api.begin(planner,source)',
        '\t\t\tdiag_scan_started=core.get_us_time()\n\t\t\tscan = scan or plan_api.begin(planner,source)')
    source = replace_once(source,
        'if core.get_us_time() - started >= FULL_PREPARATION_SCAN_BUDGET_US then return end',
        'if core.get_us_time() - started >= FULL_PREPARATION_SCAN_BUDGET_US then diag_scan_done();return end')
    source = replace_once(source, '\t\t\tif scan then return end',
        '\t\t\tdiag_scan_done()\n\t\t\tif scan then return end')
    tail = '''
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
'''
    return header + source + tail
