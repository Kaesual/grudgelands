-- Lava that stays where it was put (Round 72, The Last Mint's lake). water_guard.lua
-- guards water by the territory rule; every other liquid flows wherever no world
-- alteration guard refuses it. A held place keeps its lava as it was written: nothing
-- flows in, nothing flows out, nothing turns into anything else. An owner registers
-- a predicate pos -> true for its places (grug_expeditions: every slot's box, where
-- the templates write lava). Engine callbacks only, as water_guard.lua's: nothing
-- runs while no liquid moves. Lava written with nothing beside or below it to flow
-- into never moves at all; this is the guard for everything else.
--
-- The two boundaries are water_guard.lua's: on_flood refuses a flow into a floodable
-- node before it happens; air takes no on_flood (src/servermap.cpp), so a flow into
-- air is set back after the transform, and the air becomes the water guard's barrier,
-- itself floodable, so the next flow is refused before it changes anything.
local holds = {}

function grug_core.register_lava_hold(predicate)
	assert(type(predicate) == "function", "lava hold must be a function")
	holds[#holds + 1] = predicate
end

function grug_core.lava_held(pos)
	for index = 1, #holds do
		if holds[index](pos) == true then return true end
	end
	return false
end

-- The nodes of the `lava` group, filled at mods loaded.
local lava = {}

core.register_on_mods_loaded(function()
	for name, definition in pairs(core.registered_nodes) do
		if (definition.groups and definition.groups.lava or 0) > 0 then lava[name] = true end
	end
	for name, definition in pairs(core.registered_nodes) do
		if definition.floodable and name ~= "air" then
			local original = definition.on_flood
			core.override_item(name, {on_flood = function(pos, oldnode, newnode)
				if lava[newnode.name] and grug_core.lava_held(pos) then return true end
				if original then return original(pos, oldnode, newnode) end
			end})
		end
	end
end)

core.register_on_liquid_transformed(function(positions, old_nodes)
	for index = 1, #positions do
		local pos, oldnode = positions[index], old_nodes[index]
		local current = core.get_node_or_nil(pos)
		if current and oldnode and current.name ~= oldnode.name and
				(lava[current.name] or lava[oldnode.name]) and grug_core.lava_held(pos) then
			-- swap_node keeps metadata and runs no construct or destruct callbacks.
			core.swap_node(pos, oldnode.name == "air" and {name = grug_core.WATER_BARRIER} or oldnode)
		end
	end
end)
