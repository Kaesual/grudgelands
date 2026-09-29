-- Claim protection (rulings 6, 11, 13, 14, 17, 19; Round 26 rulings 8 and 12).
-- grug_housing wraps core.is_protected after grug_core: world protection
-- (towns, landmarks, roads, the other faction's home territory) is asked
-- first and always wins, so an enemy-faction player stays blocked whatever
-- permission a claim gives. Inside an active claim only the owner and
-- "everything" players dig and place; a draft or an empty claim protects
-- nothing (R26 ruling 8, ruling 11). The arrival cube above a standing stone
-- takes no placement from anybody, draft, fuelled or empty.

local model = grug_housing.model
local previous_is_protected = core.is_protected

-- A placement target: the engine places into air and buildable_to nodes.
local function open_at(pos)
	local node = core.get_node_or_nil(pos)
	if not node or node.name == "air" then return true end
	local def = core.registered_nodes[node.name]
	return def ~= nil and def.buildable_to == true
end

-- R26 ruling 12: a buildable_to node in the arrival cube (snow) is a
-- placement target, so the cube rule would refuse digging it too; the
-- engine asks the same is_protected for both. While a player punches or digs
-- a buildable_to node, `digging[name]` holds that node's position, and the
-- cube rule steps aside for exactly that position: the node is then judged
-- like any other node of the claim (the owner and "everything" dig it;
-- anybody when the claim is a draft or empty). A placement never runs inside
-- a punch or dig callback, so it still meets the cube rule.
local digging = {}

local function pos_key(pos)
	return math.floor(pos.x + 0.5) .. "," .. math.floor(pos.y + 0.5) .. "," ..
		math.floor(pos.z + 0.5)
end

local function digging_at(pos, name)
	if digging[name] ~= pos_key(pos) then return false end
	local node = core.get_node_or_nil(pos)
	return node ~= nil and node.name ~= "air"
end

function core.is_protected(pos, name)
	if previous_is_protected(pos, name) then return true end
	if not model.protects(pos, name, open_at, digging_at) then return false end
	-- The protection_bypass privilege passes claims as it passes the world.
	return name == "" or
		not core.check_player_privs(name, {protection_bypass = true})
end

local function with_digging(original)
	return function(pos, node, actor, ...)
		local name = actor and actor.is_player and actor:is_player() and
			actor:get_player_name()
		if type(name) ~= "string" or name == "" or not pos then
			return original(pos, node, actor, ...)
		end
		local previous = digging[name]
		digging[name] = pos_key(pos)
		local result = original(pos, node, actor, ...)
		digging[name] = previous
		return result
	end
end

-- Every buildable_to node's on_punch (the protection hint on punching) and
-- on_dig, outermost: installed on the first server step, after the
-- mods-loaded overrides of grug_abilities (the skill hand's dig check) and
-- grug_materials. In place and raw, as interaction.lua does: the engine looks
-- the callbacks up in core.registered_nodes at call time.
local function install_digging()
	local count = 0
	for _, def in pairs(core.registered_nodes) do
		if def.buildable_to == true then
			for _, field in ipairs({"on_punch", "on_dig"}) do
				if type(def[field]) == "function" then
					rawset(def, field, with_digging(def[field]))
				end
			end
			count = count + 1
		end
	end
	core.log("action", ("[grug_housing] arrival-cube dig context on %d " ..
		"buildable_to nodes"):format(count))
end

core.register_on_mods_loaded(function()
	core.after(0, install_digging)
end)

core.register_on_leaveplayer(function(player)
	digging[player:get_player_name()] = nil
end)

-- Ruling 6: liquids never flow into an arrival cube (water_guard.lua asks
-- the world alteration guards for every liquid).
grug_core.register_world_alteration_guard(function(pos)
	return model.arrival_cube_claim(pos) == nil
end)

-- Ruling 14: nothing regrows inside an active claim, nor into an arrival
-- cube; an expired claim or a draft renews like any other ground (ruling 19).
grug_core.register_natural_renewal_guard(function(pos)
	local claim = model.claim_at(pos)
	if not claim then return true end
	return not model.is_active(claim) and not model.in_arrival_cube(claim, pos)
end)
