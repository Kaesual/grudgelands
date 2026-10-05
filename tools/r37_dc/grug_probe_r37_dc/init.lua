-- Disposable Round 37 lane DC probe (tools/r37_dc/engine.sh). Never shipped.
--
-- On a fresh world: logs the version Help -> About shows (read from the
-- staged game.conf by grug_inventory/help.lua) and the game.conf
-- disallowed_mapgen_settings line, then waits until the six start areas are
-- prepared (grug_core.starts_ready, what the "Preparing the world" screen
-- waits for) and logs the wall-clock second, so engine.sh can report the
-- wait from the server's launch. Every line carries "[r37dc]"; the probe ends
-- the server.
local P = "[r37dc] "
local function log(s) core.log("action", P .. s) end

local conf = Settings(core.get_game_info().path .. "/game.conf")
log("version=" .. tostring(grug_inventory.GAME_VERSION) ..
	" conf_version=" .. tostring(conf:get("version")) ..
	" disallowed_mapgen_settings=" .. tostring(conf:get("disallowed_mapgen_settings")))
log("loaded_at=" .. os.time())

local elapsed, done = 0, false
core.register_globalstep(function(dtime)
	if done then return end
	elapsed = elapsed + dtime
	if elapsed < 1 then return end
	elapsed = 0
	local ready, total = grug_core.starts_ready()
	local failed = grug_core.starts_preload_failed()
	if ready == total or failed then
		done = true
		local ok = ready == total and not failed and
			grug_inventory.GAME_VERSION == conf:get("version")
		log("starts_ready_at=" .. os.time() .. " ready=" .. ready .. "/" .. total ..
			" failed=" .. tostring(failed))
		log("RESULT " .. (ok and "PASS" or "FAIL"))
		core.request_shutdown("r37dc probe done", false, 0)
	end
end)
