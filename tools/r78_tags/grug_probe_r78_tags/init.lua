-- Disposable Round 78 TAGS probe (tools/r78_tags/run.sh). Never shipped.
--
-- The question (round78-plan.md ruling 7, the lost carrier): does the engine
-- drop a non-static tag carrier whose map block is not in memory, as
-- serverenvironment.cpp deactivateFarObjects reads (`still_active` for
-- !isStaticAllowed is getBlockNoCreateNoEx != nullptr), while one in a loaded
-- block stays? And is core.get_node_or_nil nil exactly there (the guard
-- grug_core's replace_carrier waits on)? One carrier at an emerged spot, one
-- at the character waiting point (0, 31000, 0); both are read after 8 s
-- (active_block_mgmt_interval is 2 s). Every line carries "[r78tags]"; the
-- probe ends the server when done.
local P = "[r78tags] "
local function log(s) core.log("action", P .. s) end
local LOADED = {x = 0, y = 8, z = 0}
local WAITING = {x = 0, y = 31000, z = 0}
local started, t, phase, a, b = false, 0, "boot", nil, nil

local function place()
	a = core.add_entity(LOADED, "grug_core:tag_carrier")
	b = core.add_entity(WAITING, "grug_core:tag_carrier")
	log(("placed: loaded=%s waiting=%s node_or_nil loaded=%s waiting=%s"):format(
		tostring(a and a:is_valid()), tostring(b and b:is_valid()),
		tostring(core.get_node_or_nil(LOADED) ~= nil),
		tostring(core.get_node_or_nil(WAITING) ~= nil)))
	phase, t = "wait", 0
end

core.register_globalstep(function(dtime)
	t = t + dtime
	if phase == "boot" and t > 2 then
		phase = "emerge"
		core.emerge_area(LOADED, LOADED, function(_, _, remaining)
			if remaining == 0 then place() end
		end)
	elseif phase == "wait" and t > 8 then
		phase = "done"
		local kept = a and a:is_valid() or false
		local dropped = not (b and b:is_valid())
		log(("after 8 s: loaded carrier valid=%s, waiting-point carrier dropped=%s"):format(
			tostring(kept), tostring(dropped)))
		log("RESULT " .. ((kept and dropped and core.get_node_or_nil(WAITING) == nil)
			and "PASS" or "FAIL"))
		if a and a:is_valid() then a:remove() end
		core.request_shutdown("r78 tags probe done")
	end
end)
