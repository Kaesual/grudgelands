-- Disposable headless lifecycle probe. Staged only by luanti_headless.sh.

local anchor
local test_parent
local started = false
local elapsed = 0

local function forceload(pos)
	for dx = -64, 64, 16 do
		for dz = -64, 64, 16 do
			core.forceload_block({x = pos.x + dx, y = pos.y,
				z = pos.z + dz}, true, -1)
		end
	end
end

local function census(label)
	local parents, carriers, linked, orphans = 0, 0, 0, 0
	local objects = core.get_objects_inside_radius(anchor, 128)
	for index = 1, #objects do
		local object = objects[index]
		local entity = object:get_luaentity()
		if grug_core.is_tag_carrier(entity) then
			carriers = carriers + 1
			local parent = object:get_attach()
			if parent and parent:is_valid() then linked = linked + 1
			else orphans = orphans + 1 end
		elseif entity and entity._cmi_is_mob and
				(entity.name:sub(1, 10) == "grug_mobs:" or
				entity.name:sub(1, 13) == "grug_traders:") then
			parents = parents + 1
		end
	end
	core.log("action", "GRUG_R8_TAG event=" .. label ..
		" parents=" .. parents .. " carriers=" .. carriers ..
		" linked=" .. linked .. " orphans=" .. orphans)
	return parents, carriers, linked, orphans
end

core.register_on_mods_loaded(function()
	core.after(0, function()
		anchor = grug_core.start_position("accord", "human")
		if not anchor then
			core.log("error", "GRUG_R8_TAG missing human start")
			return
		end
		forceload(anchor)
	end)
end)

core.register_globalstep(function(dtime)
	if not anchor or not grug_core.start_ready("human") then return end
	elapsed = elapsed + dtime
	if not started and elapsed >= 2 then
		started = true
		local object = core.add_entity({x = anchor.x + 2, y = anchor.y + 2,
			z = anchor.z + 2}, "grug_mobs:stag")
		test_parent = object
	elseif started and elapsed >= 4 and test_parent then
		local parents, carriers, linked, orphans = census("before_remove")
		if parents ~= carriers or carriers ~= linked or orphans ~= 0 then
			core.log("error", "GRUG_R8_TAG unequal census before removal")
		end
		test_parent:remove()
		test_parent = nil
	elseif started and elapsed >= 6 then
		local parents, carriers, linked, orphans = census("after_remove")
		if parents ~= carriers or carriers ~= linked or orphans ~= 0 then
			core.log("error", "GRUG_R8_TAG unequal census after removal")
		else
			core.log("action", "GRUG_R8_TAG event=pass")
		end
		core.request_shutdown("R8 tag census complete", false, 0)
		started = false
	end
end)
