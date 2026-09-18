-- Headless proof that the fixed Wyrmglass encounter creates its real entity
-- at the authenticated island anchor, independently of surface clock rows.

local real_add_entity = core.add_entity
local spawn_count = 0
local emerged = false
local after_spawn = 0
core.log("action", "R8_MOB1_BOSS_PROBE loaded")

core.add_entity = function(pos, name, staticdata)
	local object = real_add_entity(pos, name, staticdata)
	if object and name == "grug_mobs:ice_dragon" then
		spawn_count = spawn_count + 1
		core.log("action", "R8_MOB1_BOSS_SPAWN name=" .. name ..
			" count=" .. spawn_count ..
			" tod=" .. tostring(core.get_timeofday()) ..
			" zone=" .. tostring(grug_zones.id_at(pos.x, pos.z)) ..
			" x=" .. math.floor(pos.x) .. " y=" .. math.floor(pos.y) ..
			" z=" .. math.floor(pos.z))
	end
	return object
end

local x, z = -3260, -40
local y = grug_zones.terrain_height_at(x, z) + 1
-- Emerge only makes the production anchor ready. The registered boss
-- globalstep remains the sole caller of spawn_dragon, so this proof covers
-- readiness plus the persistent alive/due/warned gates rather than bypassing
-- them through a probe-only helper.
core.register_on_mods_loaded(function()
	core.after(0, function()
		core.emerge_area({x = x, y = y, z = z}, {x = x, y = y, z = z},
			function(_, _, remaining)
				if remaining ~= 0 then return end
				emerged = true
				core.log("action", "R8_MOB1_BOSS_READY anchor=-3260,-40")
			end)
	end)
end)

core.register_globalstep(function(dtime)
	if not emerged then return end
	assert(spawn_count <= 1, "production heartbeat spawned duplicate Ice Dragons")
	if spawn_count == 0 then return end
	after_spawn = after_spawn + dtime
	-- Cross at least one further 10-second production heartbeat before passing;
	-- this is what proves the persistent alive gate prevents a duplicate.
	if after_spawn < 12 then return end
	local storage = grug_mobs.storage
	local prefix = "boss:dragon:wyrmglass:"
	local alive = storage:get_string(prefix .. "alive")
	local due = storage:get_string(prefix .. "due")
	local warned = storage:get_string(prefix .. "warned")
	assert(spawn_count == 1, "expected exactly one heartbeat Ice Dragon spawn")
	assert(alive == "1" and due == "" and warned == "",
		"unexpected Wyrmglass storage state")
	core.log("action", "R8_MOB1_BOSS_STATE alive=" .. alive ..
		" due=<empty> warned=<empty>")
	core.log("action", "R8_MOB1_BOSS_RESULT ice_dragon=" .. spawn_count ..
		" clock=any anchor=-3260,-40 production=heartbeat")
	core.request_shutdown("R8-MOB1 boss spawn probe complete", false, 0)
end)
