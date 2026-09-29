-- Lane B: generic right-click and node-inventory guard inside active claims
-- (ruling 18), and the claim reason for the protection hint.
--
-- The engine asks core.is_protected only for digging and placing. Inside an
-- ACTIVE claim (fuel left, ruling 11) a player without at least "interact"
-- permission may not right-click a node, put into, take from or move within a
-- node inventory, or submit a node form. "interact", "everything" and the
-- owner all pass. Every node's on_rightclick and on_receive_fields (where it
-- has one) and every node's three allow_metadata_inventory_* callbacks get
-- one generic check: which nodes carry an inventory is decided at run time
-- (on_construct), and an allow callback only runs on an inventory action.
-- Outside claims and in expired claims the check is a single claim_at call
-- that answers nil or an inactive claim; world protection (towns, roads) is
-- not consulted here and is unchanged.
--
-- The contract functions are looked up on grug_housing at call time, never
-- captured, so Lane A's core and test fakes both apply.

-- Nodes the guard leaves alone, with the reason (proposed list).
grug_housing.INTERACTION_EXCEPTIONS = {
	-- Reading a sign is free. Writing stays an edit: the sign's own
	-- on_receive_fields asks core.is_protected and reports the violation.
	["default:sign_wall_wood"] = "reading a sign",
	["grug_materials:iron_sign_wall"] = "reading a sign",
	-- The stone's owner-only interface is guarded by Lanes A and C.
	[grug_housing.STONE_ITEM] = "Claim Stone (owner-only interface)",
}

-- True when `name` may not interact at `pos`: an active claim without at
-- least "interact" permission for that name. The protection_bypass privilege
-- is honoured by grug_core.interaction_guarded, which calls this.
function grug_housing.interaction_refused(pos, name)
	local claim = grug_housing.claim_at(pos)
	if not claim or not grug_housing.is_active(claim) then return false end
	return grug_housing.permission(claim, name) == nil
end

grug_core.register_interaction_guard(grug_housing.interaction_refused)

-- The claim reason for the protection hint. It answers only where the claim
-- itself refuses edits: an active claim and neither the owner nor an
-- "everything" permission. The world reason wins over it (grug_core).
function grug_housing.protection_reason(pos, name)
	local claim = grug_housing.claim_at(pos)
	if not claim or not grug_housing.is_active(claim) then return nil end
	local level = grug_housing.permission(claim, name)
	if level == "owner" or level == "everything" then return nil end
	return "claim", "Home of " .. tostring(claim.owner) .. " – protected"
end

grug_core.register_protection_reason(grug_housing.protection_reason)

local function actor_name(actor)
	local name = actor and actor.get_player_name and actor:get_player_name()
	return type(name) == "string" and name or ""
end

-- A refusal shows the protection hint line through the shared violation
-- callback (grug_materials), the same flash every refused dig uses.
local function refused(pos, actor)
	local name = actor_name(actor)
	if not grug_core.interaction_guarded(pos, name) then return false end
	if name ~= "" then core.record_protection_violation(pos, name) end
	return true
end

-- A submission that only closes the form changes nothing and earns no hint.
local function closes_only(fields)
	for key in pairs(fields or {}) do
		if key ~= "quit" then return false end
	end
	return true
end

local wrappers = {}

local function guard_rightclick(original)
	return function(pos, node, clicker, itemstack, pointed_thing)
		if refused(pos, clicker) then return itemstack end
		return original(pos, node, clicker, itemstack, pointed_thing)
	end
end

local function guard_put(original)
	return function(pos, listname, index, stack, player)
		if refused(pos, player) then return 0 end
		if original then return original(pos, listname, index, stack, player) end
		return stack:get_count()
	end
end

local function guard_take(original)
	return function(pos, listname, index, stack, player)
		if refused(pos, player) then return 0 end
		if original then return original(pos, listname, index, stack, player) end
		return stack:get_count()
	end
end

local function guard_move(original)
	return function(pos, from_list, from_index, to_list, to_index, count, player)
		if refused(pos, player) then return 0 end
		if original then
			return original(pos, from_list, from_index, to_list, to_index, count,
				player)
		end
		return count
	end
end

local function guard_fields(original)
	return function(pos, formname, fields, sender)
		local name = actor_name(sender)
		if grug_core.interaction_guarded(pos, name) then
			if name ~= "" and not closes_only(fields) then
				core.record_protection_violation(pos, name)
			end
			return
		end
		return original(pos, formname, fields, sender)
	end
end

local function wrap(def, field, make)
	local wrapper = make(def[field])
	wrappers[wrapper] = true
	-- In place and raw: a registered definition silently ignores NEW keys
	-- (builtin register_item's __newindex), and the engine and every direct
	-- caller look the callback up in core.registered_nodes at call time.
	rawset(def, field, wrapper)
end

-- Summary of the installation, for probes and diagnostics.
grug_housing.interaction_guard_report = nil

local function install()
	local report = {nodes = 0, rightclick = {}, fields = {}, exceptions = {}}
	for name, def in pairs(core.registered_nodes) do
		if grug_housing.INTERACTION_EXCEPTIONS[name] then
			report.exceptions[#report.exceptions + 1] = name
		elseif not wrappers[def.allow_metadata_inventory_take] then
			report.nodes = report.nodes + 1
			if type(def.on_rightclick) == "function" then
				report.rightclick[#report.rightclick + 1] = name
				wrap(def, "on_rightclick", guard_rightclick)
			end
			-- Every node: a node without allow callbacks still gets an
			-- inventory from on_construct and shows it from on_rightclick
			-- (the chest), and the engine would then allow everything.
			wrap(def, "allow_metadata_inventory_put", guard_put)
			wrap(def, "allow_metadata_inventory_take", guard_take)
			wrap(def, "allow_metadata_inventory_move", guard_move)
			if type(def.on_receive_fields) == "function" then
				report.fields[#report.fields + 1] = name
				wrap(def, "on_receive_fields", guard_fields)
			end
		end
	end
	table.sort(report.exceptions)
	table.sort(report.rightclick)
	table.sort(report.fields)
	grug_housing.interaction_guard_report = report
	core.log("action", ("[grug_housing] interaction guard: node inventories on " ..
		"%d nodes, right-click on %d, node form on %d; exceptions: %s"):format(
		report.nodes, #report.rightclick, #report.fields,
		#report.exceptions > 0 and table.concat(report.exceptions, ", ") or "none"))
end

-- Installed once from the mods-loaded phase. Other mods replace node
-- callbacks in their own register_on_mods_loaded (grug_jobs installs every
-- station's on_rightclick and allow callbacks there, and it may run after
-- this mod), so the wrap itself runs on the first server step, when every
-- mods-loaded change is in place and before any player can act.
core.register_on_mods_loaded(function()
	core.after(0, install)
end)
