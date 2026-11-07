-- The scenarios, one per run.sh SCENARIO.
local S = {}
local E = grug_expeditions

-- The box against its template: nodes that differ, and stone outside the template.
local function verify(lib, run)
	local tpl = E.templates[E.definition(run.expedition).template]
	local vm = VoxelManip()
	local e1, e2 = vm:read_from_map(run.minp, run.maxp)
	local area = VoxelArea(e1, e2)
	local data, param2 = vm:get_data(), vm:get_param2_data()
	local stone = core.get_content_id(E.catalogue.CLEAR_NODE)
	local sx, sy, sz = tpl.size.x, tpl.size.y, tpl.size.z
	local total = sx * sy * sz
	local wrong, wrong2, outside = 0, 0, 0
	for z = 0, E.catalogue.BOX.z - 1 do
		for y = 0, E.catalogue.BOX.y - 1 do
			for x = 0, E.catalogue.BOX.x - 1 do
				local got = area:index(run.minp.x + x, run.minp.y + y, run.minp.z + z)
				if x < sx and y < sy and z < sz then
					local at = z * sy * sx + y * sx + x + 1
					if data[got] ~= tpl.ids[tpl.cells:byte(at)] then wrong = wrong + 1 end
					if param2[got] ~= tpl.cells:byte(total + at) then wrong2 = wrong2 + 1 end
				elseif data[got] ~= stone then
					outside = outside + 1
				end
			end
		end
	end
	return lib.check(wrong == 0 and wrong2 == 0 and outside == 0,
		("layout nodes_wrong %d param2_wrong %d outside_wrong %d"):format(wrong, wrong2, outside))
end
S.verify = verify

-- Phase 1: create, refused while preparing, ready, the layout, enter, waystone back.
function S.basic(lib, player)
	lib.phase("baseline")
	lib.wait(10)
	lib.phase_end()
	grug_xp.set_xp(player, grug_xp.xp_for_level(19))
	local level = grug_xp.get_level(player)
	lib.logf("level %d, offered %d levels", level, #E.offered_levels(player, "test_vault"))
	local ok, why = E.can_create(player, "test_vault", 9)
	lib.check(not ok, "create at +9 refused: " .. tostring(why))
	local ready, ended, entered, left = 0, 0, 0, 0
	E.register_on_ready(function() ready = ready + 1 end)
	E.register_on_end(function() ended = ended + 1 end)
	E.register_on_enter(function() entered = entered + 1 end)
	E.register_on_leave(function() left = left + 1 end)
	lib.phase("prepare")
	local run = assert(E.create(player, "test_vault", 0))
	ok, why = E.enter(player, "highcourt")
	lib.check(not ok, "enter while preparing refused: " .. tostring(why))
	local status = E.preparation(run)
	lib.logf("preparation %s", dump(status):gsub("%s+", " "))
	local took = lib.wait_for(function() return run.state == "ready" end, 60)
	lib.phase_end()
	lib.check(took ~= nil and ready == 1, ("ready after %.2f s"):format(took or -1))
	verify(lib, run)
	lib.check(E.slot_at(run.places.arrival) == run.slot, "slot_at finds the arrival")
	lib.check(E.run_at(run.places.arrival) == run, "run_at finds the run")
	lib.check(E.run_of(player) == run, "run_of finds the run")
	lib.logf("run %d slot %d encounters %d", run.id, run.slot,
		#E.encounters(run))
	lib.check(E.enter(player, "highcourt"), "enter starts")
	lib.wait_for(function() return E.run_inside(player) == run end, 30)
	lib.check(E.run_inside(player) == run and entered == 1, "inside, state " .. run.state)
	lib.check(run.state == "running" and run.entered[lib.NAME], "a place is taken")
	lib.logf("standing at %s", core.pos_to_string(player:get_pos()))
	lib.wait(3)
	core.registered_nodes["grug_expeditions:waystone"].on_rightclick(run.places.start_waystone,
		{name = "grug_expeditions:waystone"}, player)
	lib.wait_for(function() return E.run_inside(player) == nil end, 40)
	lib.check(left == 1 and E.run_inside(player) == nil, "left through the waystone")
	lib.logf("back at %s", core.pos_to_string(player:get_pos()))
	E.end_run(run, "probe")
	lib.check(ended == 1 and E.run_at(run.places.arrival) == nil, "ended, slot free")
	local second = assert(E.create(player, "test_vault", 0))
	lib.check(second.slot == run.slot, "the first free slot again")
	lib.wait_for(function() return second.state == "ready" end, 60)
	verify(lib, second)
	lib.phase_end()
end

return S
