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

local function level_up(player)
	grug_xp.set_xp(player, grug_xp.xp_for_level(19))
end

-- Asks an area and counts the answers; a generated answer means it was not.
local function ask_area(lib, p1, p2)
	local counts, left = {}, nil
	core.emerge_area(p1, p2, function(_, action, remaining)
		counts[action] = (counts[action] or 0) + 1
		left = remaining
	end)
	lib.wait_for(function() return left == 0 end, 100)
	return counts[core.EMERGE_GENERATED] or 0, counts[core.EMERGE_CANCELLED] or 0
end

-- Real leftovers of a used slot: a saved mob, a dropped item, chest meta, a timer.
local function plant(lib, run)
	local mob = core.add_entity(E.encounters(run)[1].pos, "grug_mobs:giant_spider")
	local item = core.add_item(vector.offset(run.places.arrival, 2, 0, 2), "default:dirt 5")
	local chest = run.places.chest
	core.load_area(chest)
	core.get_meta(chest):set_string("leftover", "yes")
	core.get_meta(chest):get_inventory():set_size("main", 8)
	core.get_meta(chest):get_inventory():add_item("main", "default:dirt 3")
	core.get_node_timer(chest):start(600)
	lib.logf("PLANTED mob %s item %s meta %s timer %s", tostring(mob ~= nil), tostring(item ~= nil),
		core.get_meta(chest):get_string("leftover"), tostring(core.get_node_timer(chest):is_started()))
end

local function objects_in(run)
	local n, names = 0, {}
	for object in core.objects_in_area(run.minp, run.maxp) do
		local entity = object:get_luaentity()
		-- A player's tag and wield are attached; test_vault's wall trap fires on
		-- its own (Round 72 TRAPS) and is no leftover.
		if not object:is_player() and not object:get_attach()
				and not (entity and entity.name == "grug_expeditions:trap_fireball") then
			n = n + 1
			names[#names + 1] = entity and entity.name or "?"
		end
	end
	return n, table.concat(names, " ")
end

local function no_leftovers(lib, run, label)
	local n, names = objects_in(run)
	local chest = run.places.chest
	core.load_area(chest)
	local meta = core.get_meta(chest)
	local stacks = meta:get_inventory():get_size("main")
	lib.check(n == 0 and meta:get_string("leftover") == "" and stacks == 0 and
		not core.get_node_timer(chest):is_started(),
		("%s: objects %d (%s), meta '%s', inventory %d, timer %s"):format(label, n, names,
			meta:get_string("leftover"), stacks, tostring(core.get_node_timer(chest):is_started())))
end

local function wait_ready(lib, run)
	local took = lib.wait_for(function() return run.state == "ready" end, 120)
	lib.check(took ~= nil, ("ready after %.2f s"):format(took or -1))
end

local function enter(lib, player, run)
	assert(E.enter(player, "highcourt"))
	lib.wait_for(function() return E.run_inside(player) == run end, 30)
	lib.check(E.run_inside(player) == run, "inside at " .. core.pos_to_string(player:get_pos()))
end

-- The client moves over fresh land at 10 nodes a second, a mount's pace, at a real
-- viewing range; the preparation runs twice beside it, the second over the first.
function S.move(lib, player)
	level_up(player)
	grug_core.hold_movement(player, "r71frame:move")
	local at = vector.round(player:get_pos())
	at.y = 90
	local step_len = 0.9
	local last_chunks = lib.chunks
	lib.on_extra = function()
		at.z = at.z + step_len
		player:set_pos(at)
	end
	local function rate(label, t0)
		lib.logf("CHUNKS %s %d in %.1f s", label, lib.chunks - last_chunks, (core.get_us_time() - t0) / 1e6)
		last_chunks = lib.chunks
	end
	local t0 = core.get_us_time()
	lib.wait(15) -- the first chunks of the walk
	rate("warmup", t0)
	lib.phase("walk_baseline")
	t0 = core.get_us_time()
	lib.wait(50)
	lib.phase_end()
	rate("walk_baseline", t0)
	lib.phase("walk_prepare")
	t0 = core.get_us_time()
	local run = assert(E.create(player, "test_vault", 0))
	lib.job_run = run
	wait_ready(lib, run)
	verify(lib, run)
	E.end_run(run, "probe")
	local second = assert(E.create(player, "test_vault", 0))
	lib.job_run = second
	wait_ready(lib, second)
	lib.phase_end()
	rate("walk_prepare", t0)
	lib.job_report("walk")
	verify(lib, second)
	lib.phase("walk_after")
	t0 = core.get_us_time()
	lib.wait(30)
	lib.phase_end()
	rate("walk_after", t0)
	lib.on_extra = nil
	lib.logf("walked to %s", core.pos_to_string(at))
end

-- A run from create to end, the release clock, a rewrite over real leftovers, later
-- generation round a fresh box, Return Home.
function S.life(lib, player)
	level_up(player)
	E.catalogue.RESERVE_SECONDS = 20
	local log = {}
	E.register_on_end(function(run, why) log[#log + 1] = run.id .. " " .. why end)
	local run = assert(E.create(player, "test_vault", 0))
	lib.job_run = run
	wait_ready(lib, run)
	lib.job_report("life_fresh")
	verify(lib, run)
	local a = vector.offset(run.minp, -16, -16, -16)
	local b = vector.offset(run.maxp, 16, 16, 16)
	local generated, cancelled = ask_area(lib, a, b)
	lib.check(generated == 0 and cancelled == 0, ("box +- 16 generated: %d new, %d cancelled"):format(generated,
		cancelled))
	enter(lib, player, run)
	lib.check(run.state == "running", "running")
	plant(lib, run)
	lib.wait(8)
	lib.logf("objects after planting: %d (%s)", objects_in(run))
	assert(E.leave(player))
	lib.wait_for(function() return E.run_inside(player) == nil end, 40)
	lib.logf("left to %s", core.pos_to_string(player:get_pos()))
	local t0 = core.get_us_time()
	lib.wait_for(function() return run.state == "ended" end, 40)
	lib.check(run.state == "ended" and log[1] == run.id .. " empty",
		("released %.1f s after the last one out"):format((core.get_us_time() - t0) / 1e6))
	lib.check(E.run_at(run.places.arrival) == nil and E.run_of(player) == nil, "slot and owner free")
	lib.logf("objects still in the old box: %d (%s)", objects_in(run))
	lib.logf("meta still in the old box: '%s'", core.get_meta(run.places.chest):get_string("leftover"))
	E.catalogue.RESERVE_SECONDS = 600
	local second = assert(E.create(player, "test_vault", 0))
	lib.check(second.slot == run.slot, "the same slot")
	lib.job_run = second
	wait_ready(lib, second)
	lib.job_report("life_rewrite")
	no_leftovers(lib, second, "after the rewrite")
	verify(lib, second)
	enter(lib, player, second)
	lib.wait(25)
	no_leftovers(lib, second, "25 s inside")
	verify(lib, second)
	-- every chunk touching the box is generated: more generation cannot reach it
	generated = ask_area(lib, vector.offset(second.minp, -160, -112, -160),
		vector.offset(second.maxp, 160, 112, 160))
	lib.logf("generated round the box: %d blocks answered new", generated)
	lib.wait(10)
	verify(lib, second)
	grug_home.return_home(player)
	lib.wait_for(function() return E.run_inside(player) == nil end, 40)
	lib.check(E.run_inside(player) == nil and second.entered[lib.NAME], "Return Home left, the place stays")
	lib.logf("home at %s, cooldown %d", core.pos_to_string(player:get_pos()), grug_home.remaining(player))
	E.end_run(second, "probe")
end

-- First boot of the restart proof: stops with the player inside a run, leftovers in it.
function S.restart1(lib, player)
	level_up(player)
	local run = assert(E.create(player, "test_vault", 0))
	wait_ready(lib, run)
	enter(lib, player, run)
	plant(lib, run)
	lib.wait(12)
	lib.logf("objects at shutdown: %d (%s)", objects_in(run))
end

local join_pos
core.register_on_joinplayer(function(player) join_pos = player:get_pos() end)

-- Second boot, same world: no run left, the player goes home, the slot rewrites.
function S.restart2(lib, player)
	local first = {minp = (E.slot_box(1))}
	first.minp, first.maxp = E.slot_box(1)
	lib.check(E.slot_at(join_pos) == 1, "logged in inside the box: " .. core.pos_to_string(join_pos))
	lib.wait_for(function() return E.slot_at(player:get_pos()) == nil end, 30)
	lib.wait(3)
	lib.check(E.slot_at(player:get_pos()) == nil and E.run_of(player) == nil,
		"went home to " .. core.pos_to_string(player:get_pos()))
	lib.logf("objects back in the old box: %d (%s)", objects_in(first))
	lib.wait(10)
	local chest = vector.add(first.minp, E.templates.test_vault.places.chest)
	core.load_area(chest)
	lib.logf("old chest: meta '%s', timer %s", core.get_meta(chest):get_string("leftover"),
		tostring(core.get_node_timer(chest):is_started()))
	local run = assert(E.create(player, "test_vault", 0))
	lib.check(run.slot == 1, "the same slot")
	lib.job_run = run
	wait_ready(lib, run)
	lib.job_report("restart")
	no_leftovers(lib, run, "after the rewrite")
	verify(lib, run)
	enter(lib, player, run)
	lib.wait(25)
	no_leftovers(lib, run, "25 s inside")
	verify(lib, run)
end

-- Phase 1: create, refused while preparing, ready, the layout, enter, waystone back.
function S.basic(lib, player)
	lib.phase("baseline")
	lib.wait(10)
	lib.phase_end()
	level_up(player)
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

-- Round 71 FOLLOW: what hangs on a player inside stays on them, at a run's end and when
-- a preparation clears the box round them. The feed's lines are logged as well.
local function tag_of(player)
	for _, child in ipairs(player:get_children()) do
		local entity = child:get_luaentity()
		if entity and entity.name == "grug_core:tag_carrier" then return child end
	end
end

local function keeps_tag(lib, player, tag, label)
	local alive = tag:is_valid() and tag_of(player) == tag
	lib.check(alive, ("%s: the tag lives, at %s"):format(label, core.pos_to_string(player:get_pos())))
	lib.logf("%s: text '%s'", label, alive and tag:get_nametag_attributes().text or "(gone)")
end

function S.tag(lib, player)
	level_up(player)
	local feed = grug_core.feed
	grug_core.feed = function(who, kind, text, key)
		lib.logf("FEED %s %s: %s", kind, tostring(key), text)
		return feed(who, kind, text, key)
	end
	local run = assert(E.create(player, "test_vault", 0))
	wait_ready(lib, run)
	enter(lib, player, run)
	lib.wait(2)
	local tag = assert(tag_of(player), "no name tag")
	lib.logf("attached before the end: %d", #player:get_children())
	E.end_run(run, "joined_party")
	lib.wait_for(function() return not E.slot_at(player:get_pos()) end, 40)
	lib.wait(3)
	keeps_tag(lib, player, tag, "run end")

	-- A player a preparation finds in the box: a trip home lands too fast to be caught,
	-- so the probe puts them there, and waits for the tag to be there too.
	player:set_pos(run.places.arrival)
	lib.wait_for(function()
		local at = tag:get_pos()
		return at and E.slot_at(at) == run.slot
	end, 10)
	lib.check(E.slot_at(player:get_pos()) == run.slot, "in the box before the preparation")
	local next_run = assert(E.create(player, "test_vault", 0))
	wait_ready(lib, next_run)
	lib.check(not E.slot_at(player:get_pos()), "sent out of the box")
	lib.wait(3)
	keeps_tag(lib, player, tag, "preparation")
end

return S
