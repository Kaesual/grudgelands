"""Observation and matched-prefix stop in the disposable copy only."""
def instrument(s):
    header='''-- Disposable-snapshot observation only; production scheduling constants unchanged.
    local diag = {steps=0,scan_steps=0,scan_us=0,persist_us=0,persists=0,actions={},dispatches=0,callbacks=0}
    local diag_stop_after_prefix = false
    local diag_start = core.get_us_time()
    local diag_last, diag_step, diag_complete = diag_start, nil, nil
    local function diag_log(kind, data)
     core.log("action", "[pregen_diag] " .. core.write_json({us=core.get_us_time(),kind=kind,data=data}))
    end
    '''
    s=header+s
    s=s.replace('local function persist() storage:set_string(STORAGE_KEY, core.serialize(state)) end','local function persist() local t=core.get_us_time(); storage:set_string(STORAGE_KEY, core.serialize(state)); diag.persist_us=diag.persist_us+core.get_us_time()-t;diag.persists=diag.persists+1 end')
    s=s.replace('core.emerge_area(lo,hi,function(pos,action,remaining)','''diag.dispatches=diag.dispatches+1
     diag_log("dispatch",{id=diag.dispatches,cursor=state.cursor,selection=state.selection,lo=lo,hi=hi,gap_us=diag_complete and started-diag_complete or nil})
     core.emerge_area(lo,hi,function(pos,action,remaining)
      diag.callbacks=diag.callbacks+1;diag.actions[tostring(action)]=(diag.actions[tostring(action)] or 0)+1''')
    s=s.replace('pending, notify = false, true','''pending, notify = false, true
      diag_complete=core.get_us_time()
      diag_log("complete",{id=diag.dispatches,duration_us=diag_complete-started,cursor=state.cursor,selection=state.selection,actions=diag.actions})''')
    s=s.replace('if stopped then return end','''if stopped then return end
     if diag_stop_after_prefix then stopped=true;core.request_shutdown("matched preparation prefix complete",false,0);return end
     local diag_now=core.get_us_time()
     diag.steps=diag.steps+1
     if diag_step then
      local delta=diag_now-diag_step
      diag.step_us=(diag.step_us or 0)+delta;diag.step_max_us=math.max(diag.step_max_us or 0,delta)
     end
     diag_step=diag_now
     if diag_now-diag_last>=5000000 then
      diag.cursor=state.cursor;diag.selection=state.selection;diag.scan=scan;diag.pending=pending;diag.failed=failed
      diag_log("sample",diag)
      diag={steps=0,scan_steps=0,scan_us=0,persist_us=0,persists=0,actions=diag.actions,dispatches=diag.dispatches,callbacks=diag.callbacks}
      diag_last=diag_now
     end''')
    s=s.replace('tile_elapsed = tile_elapsed + (core.get_us_time()-started)/1000000\n\t\t\tif scan', 'diag.scan_steps=diag.scan_steps+1;diag.scan_us=diag.scan_us+core.get_us_time()-started\n\t\t\ttile_elapsed = tile_elapsed + (core.get_us_time()-started)/1000000\n\t\t\tif scan')
    s+='''\ncore.register_on_mods_loaded(function()
     diag_log("settings",{version=core.get_version(),step=core.settings:get("dedicated_server_step"),emerge_threads=core.settings:get("num_emerge_threads"),jit=core.global_exists("jit") and jit.version or "absent",seed=core.get_mapgen_setting("seed")})
    end)
    core.register_on_shutdown(function() diag_log("shutdown",{status=grug_core.world_preparation_status()}) end)
    '''
    
    s=s.replace('diag_log("complete",{id=diag.dispatches,duration_us=diag_complete-started,cursor=state.cursor,selection=state.selection,actions=diag.actions})', 'diag_log("complete",{id=diag.dispatches,duration_us=diag_complete-started,cursor=state.cursor,selection=state.selection,actions=diag.actions})\n  if state.cursor == 561 then diag_stop_after_prefix=true end')
    s=s.replace('diag.step_us=(diag.step_us or 0)+delta;diag.step_max_us=math.max(diag.step_max_us or 0,delta)', 'diag.step_us=(diag.step_us or 0)+delta;diag.step_max_us=math.max(diag.step_max_us or 0,delta);diag.step_hist=diag.step_hist or {};local bucket=tostring(math.floor(delta/1000));diag.step_hist[bucket]=(diag.step_hist[bucket] or 0)+1')
    s=s.replace('diag.scan_steps=diag.scan_steps+1;diag.scan_us=diag.scan_us+core.get_us_time()-started', 'diag.scan_steps=diag.scan_steps+1;diag.scan_us=diag.scan_us+core.get_us_time()-started;diag.scan_max_us=math.max(diag.scan_max_us or 0,core.get_us_time()-started)')
    return s
