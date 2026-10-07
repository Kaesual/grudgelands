-- Interface contract (plan section "Lanes") and the claim core (Lane A).
-- Lanes B, C and D code against the signatures and return shapes below.
--
-- A claim is a table { id, owner, center = {x, y, z}, placed_at, paid_until }
-- (seconds of os.time()), plus `activated_at` (0 while the stone is a draft,
-- Round 26), `expired_for` and `permissions` (name -> "everything" |
-- "interact"). Read it, never write it: every change goes through the
-- functions here, which persist it. The model itself lives in registry.lua
-- (pure, shared with tools/r25_claim_core/fixture.lua).

local modpath = core.get_modpath("grug_housing")
local storage = core.get_mod_storage()

local model = dofile(modpath .. "/registry.lua")({
	storage = {
		get_string = function(key) return storage:get_string(key) end,
		set_string = function(key, value) storage:set_string(key, value) end,
		keys = function() return storage:get_keys() end,
	},
	-- Ruling 10: the wall clock. Server downtime counts.
	now = os.time,
})
model.load()
-- The platform's map reset: the claims go with the map (registry.lua).
grug_core.map_reset.clear("the housing claims", model.map_reset)
grug_housing.model = model

-- Claim size and placement bounds (rulings 1-2).
grug_housing.RADIUS = model.RADIUS
grug_housing.MIN_Y = model.MIN_Y
grug_housing.LUMP_SECONDS = model.LUMP_SECONDS
grug_housing.FUEL_MAX = model.FUEL_MAX
-- Round 26 rulings 8-10: a draft lasts DRAFT_SECONDS, activation pays
-- ACTIVATION_LUMPS, pick-up waits PICKUP_LOCK_SECONDS after activation.
grug_housing.DRAFT_SECONDS = model.DRAFT_SECONDS
grug_housing.ACTIVATION_LUMPS = model.ACTIVATION_LUMPS
grug_housing.PICKUP_LOCK_SECONDS = model.PICKUP_LOCK_SECONDS

-- The soulbound Claim Stone item, registered by Lane A (stone.lua). The item
-- is also the node of the fuelled stone; placing it sets DRAFT_STONE (the
-- half-transparent draft, R26 ruling 8); an activated stone without fuel is
-- EMPTY_STONE (the only variant a pick can dig, ruling 12).
grug_housing.STONE_ITEM = "grug_housing:claim_stone"
grug_housing.EMPTY_STONE = "grug_housing:claim_stone_empty"
grug_housing.DRAFT_STONE = "grug_housing:claim_stone_draft"
grug_housing.STONE_NODES = {
	[grug_housing.STONE_ITEM] = true,
	[grug_housing.EMPTY_STONE] = true,
	[grug_housing.DRAFT_STONE] = true,
}

-- Ruling 10: coal lumps and charcoal burn alike; coal blocks are refused.
grug_housing.FUEL_ITEMS = {
	["default:coal_lump"] = true,
	["grug_smelting:charcoal"] = true,
}
-- Unburnt whole lumps come back as charcoal on pick-up, the cheaper lump
-- (any log makes it), so placing and picking up never turns charcoal into
-- mined coal. Coal only when grug_smelting is missing.
grug_housing.REFUND_ITEM = "grug_smelting:charcoal"
grug_housing.REFUND_FALLBACK = "default:coal_lump"

function grug_housing.refund_item()
	local items = core.registered_items
	if items and items[grug_housing.REFUND_ITEM] then return grug_housing.REFUND_ITEM end
	return grug_housing.REFUND_FALLBACK
end

-- Activation takes its lumps from the main inventory in this order: charcoal
-- first, so the scarcer coal is spent last.
grug_housing.FUEL_ORDER = {"grug_smelting:charcoal", "default:coal_lump"}

function grug_housing.is_fuel(itemname)
	return grug_housing.FUEL_ITEMS[itemname] == true
end

-- The claim covering pos (x/z only, y >= MIN_Y), or nil.
function grug_housing.claim_at(pos)
	return model.claim_at(pos)
end

-- True while the claim is activated and has fuel (paid_until is in the
-- future). A draft is never active: it protects nothing, spawns and
-- interaction are not guarded there.
function grug_housing.is_active(claim)
	return model.is_active(claim)
end

-- True while the placed stone is a draft, not yet activated (R26 ruling 8).
function grug_housing.is_draft(claim)
	return model.is_draft(claim)
end

-- Seconds until a draft crumbles; 0 for an activated claim.
function grug_housing.draft_remaining(claim)
	return model.draft_remaining(claim)
end

-- Seconds until the owner may pick the stone up (12 h after activation);
-- 0 when allowed, always 0 for a draft.
function grug_housing.pickup_wait(claim)
	return model.pickup_wait(claim)
end

-- Whole seconds of fuel left, 0 when empty.
function grug_housing.remaining_seconds(claim)
	return model.remaining_seconds(claim)
end

-- "owner", "everything", "interact" or nil for this player name.
function grug_housing.permission(claim, name)
	return model.permission(claim, name)
end

-- The player's claim (or nil) and a state: "never", "carried", "placed",
-- "destroyed", "removed" or "needs_stone". A standing stone, draft, fuelled
-- or empty, is "placed" with its claim. An expired draft leaves
-- "needs_stone", an admin removal "removed".
function grug_housing.player_claim(name)
	return model.player_claim(name)
end

-- fn(claim, event) runs after every change; event is one of "placed",
-- "activated", "fuel", "permission", "picked_up", "destroyed", "removed",
-- "draft_expired", "expired". "picked_up", "destroyed", "removed" (an admin,
-- admin.lua) and "draft_expired" pass the removed claim table. "expired" and
-- "draft_expired" come from a periodic check every few seconds (stone.lua);
-- "expired" once per burnt-out paid_until.
local claim_changed_callbacks = {}

function grug_housing.register_on_claim_changed(fn)
	assert(type(fn) == "function", "claim change callback must be a function")
	claim_changed_callbacks[#claim_changed_callbacks + 1] = fn
end

function grug_housing.notify_claim_changed(claim, event)
	for index = 1, #claim_changed_callbacks do
		claim_changed_callbacks[index](claim, event)
	end
end

-- Whether the Claim Stone item is anywhere in the player's inventory.
function grug_housing.holds_stone(player)
	local inv = player and player:get_inventory()
	if not inv then return false end
	for listname in pairs(inv:get_lists()) do
		if inv:contains_item(listname, grug_housing.STONE_ITEM) then return true end
	end
	return false
end

local function player_level(player)
	local xp = rawget(_G, "grug_xp")
	return xp and xp.get_level(player) or 0
end

-- Housing Steward hand-out (ruling 7): gives the stone when the player is
-- level 20+ and has none; returns ok, message.
function grug_housing.issue_stone(player)
	if not player or not player:is_player() then return false, "No player." end
	local name, level = player:get_player_name(), player_level(player)
	local holds = grug_housing.holds_stone(player)
	local ok, message = model.can_issue(name, level, holds)
	if not ok then return false, message end
	local inv = player:get_inventory()
	local stone = ItemStack(grug_housing.STONE_ITEM)
	if not inv:room_for_item("main", stone) then
		return false, "Make room in your inventory for the Claim Stone."
	end
	ok, message = model.issue(name, level, holds)
	if not ok then return false, message end
	inv:add_item("main", stone)
	return true, message
end

-- Makes the node at the stone match its claim: the draft stone while it is
-- a draft, the fuelled stone while the claim is active, the empty stone
-- otherwise. Only a loaded stone changes.
function grug_housing.sync_stone_node(claim)
	local node = core.get_node_or_nil(claim.center)
	if not node then return end
	local wanted = grug_housing.EMPTY_STONE
	if model.is_draft(claim) then
		wanted = grug_housing.DRAFT_STONE
	elseif model.is_active(claim) then
		wanted = grug_housing.STONE_ITEM
	end
	if grug_housing.STONE_NODES[node.name] and node.name ~= wanted then
		core.swap_node(claim.center, {name = wanted})
	end
end

-- Removes the stone node of a claim, loading its block when needed (a pick-up
-- from the form, an expired draft, an admin removal). Only a stone variant
-- is removed.
function grug_housing.remove_stone_node(claim)
	core.load_area(claim.center)
	local node = core.get_node_or_nil(claim.center)
	if node and grug_housing.STONE_NODES[node.name] then
		core.remove_node(claim.center)
		return true
	end
	return false
end

local function fuel_in_main(inv)
	local have = 0
	for _, item in ipairs(grug_housing.FUEL_ORDER) do
		for _, stack in ipairs(inv:get_list("main") or {}) do
			if stack:get_name() == item then have = have + stack:get_count() end
		end
	end
	return have
end

-- R26 ruling 9: the owner activates the draft; ACTIVATION_LUMPS coal lumps or
-- charcoal (mixed) are taken from the main inventory at once. Returns ok,
-- message.
function grug_housing.activate(player)
	if not player or not player:is_player() then return false, "No player." end
	local name = player:get_player_name()
	local claim = model.player_claim(name)
	if not claim then return false, "You have no placed Claim Stone." end
	if not model.is_draft(claim) then
		return false, "Your Claim Stone is already activated."
	end
	local need = model.ACTIVATION_LUMPS
	local inv = player:get_inventory()
	local have = fuel_in_main(inv)
	if have < need then
		return false, ("Activation needs %d coal lumps or charcoal in your " ..
			"inventory; you have %d."):format(need, have)
	end
	local left = need
	for _, item in ipairs(grug_housing.FUEL_ORDER) do
		if left <= 0 then break end
		local taken = inv:remove_item("main", ItemStack(item .. " " .. left))
		left = left - taken:get_count()
	end
	local burnt = model.activate(claim, need - left)
	if burnt <= 0 then
		-- Cannot happen after the count above; hand back what was taken.
		local back = need - left
		if back > 0 then
			local rest = inv:add_item("main",
				ItemStack(grug_housing.refund_item() .. " " .. back))
			if not rest:is_empty() then core.add_item(player:get_pos(), rest) end
		end
		return false, "The Claim Stone could not be activated."
	end
	grug_housing.sync_stone_node(claim)
	grug_housing.notify_claim_changed(claim, "activated")
	core.log("action", ("[grug_housing] %s activated Claim Stone %d with %d lumps"):format(
		name, claim.id, burnt))
	return true, ("Claim Stone activated: your home is protected. It stays " ..
		"in place for %d hours."):format(model.PICKUP_LOCK_SECONDS / 3600)
end

-- Burns count lumps into paid_until; returns the number accepted
-- (at most 99 - ceil(remaining / LUMP_SECONDS)); 0 for a draft.
function grug_housing.add_fuel(claim, count)
	local accepted = model.add_fuel(claim, count)
	if accepted > 0 then
		grug_housing.sync_stone_node(claim)
		grug_housing.notify_claim_changed(claim, "fuel")
	end
	return accepted
end

-- Owner pick-up through the stone interface; returns ok, message. The stone
-- goes back into the main inventory together with the unburnt whole lumps
-- (dropped at the player when they do not fit). A draft comes back at any
-- time; an activated stone only 12 h after activation (R26 ruling 10).
function grug_housing.pick_up(player)
	if not player or not player:is_player() then return false, "No player." end
	local name = player:get_player_name()
	local claim = model.player_claim(name)
	if not claim then return false, "You have no placed Claim Stone." end
	local wait = model.pickup_wait(claim)
	if wait > 0 then
		return false, "Your Claim Stone stays in place for another " ..
			model.wait_text(wait) .. "."
	end
	local inv = player:get_inventory()
	local stone = ItemStack(grug_housing.STONE_ITEM)
	if not inv:room_for_item("main", stone) then
		return false, "Make room in your inventory for the Claim Stone."
	end
	local lumps = model.refund_lumps(claim)
	grug_housing.remove_stone_node(claim)
	model.remove(claim, "picked_up")
	inv:add_item("main", stone)
	local refund = grug_housing.refund_item()
	if lumps > 0 then
		local left = inv:add_item("main", ItemStack(refund .. " " .. lumps))
		if not left:is_empty() then core.add_item(player:get_pos(), left) end
	end
	grug_housing.notify_claim_changed(claim, "picked_up")
	if lumps > 0 then
		return true, ("Claim Stone picked up; %d unburnt %s returned."):format(lumps,
			refund == grug_housing.REFUND_ITEM and "charcoal" or "coal")
	end
	return true, "Claim Stone picked up."
end

-- level is "everything", "interact" or nil (remove); returns ok, message.
function grug_housing.set_permission(claim, name, level)
	local ok, message = model.set_permission(claim, name, level)
	if ok then grug_housing.notify_claim_changed(claim, "permission") end
	return ok, message
end

-- The bottom-layer centre of the 3 x 3 x 3 arrival cube above the stone
-- (ruling 6): where a travelling player's feet go.
function grug_housing.arrival_pos(claim)
	local c = claim.center
	return {x = c.x, y = c.y + 1, z = c.z}
end

-- The world queries placement validation needs (registry.lua validate).
-- `fixed`: the column answers come from the world's zone layout, which
-- never changes while the server runs, so the registry keeps its scans.
local zone_records = {}
local world = {fixed = true}

function world.water_class_at(x, z)
	return grug_zones.water_class_at(x, z)
end

function world.zone_at(x, z)
	local id = grug_zones.id_at(x, z)
	if not id then return nil end
	local record = zone_records[id]
	if not record then
		record = grug_zones.get(id)
		zone_records[id] = record
	end
	return record
end

-- At the world top every town or landmark column answers "hard_protected",
-- whatever its protected floor: ruling 3 excludes them in x/z.
function world.territory_at(x, z)
	return grug_zones.territory_rule_at({x = x, y = 30000, z = z})
end

-- Ruling 27: the settlement cores of POIs, villages and camps (grug_core,
-- Round 25 ruling 16) and the hard footprints of start towns, capitals and
-- landmarks, each within `margin` of the claim square.
function world.feature_in(min_x, min_z, max_x, max_z, margin)
	if grug_core.world_feature_boxes_in(min_x, min_z, max_x, max_z, margin) then
		return "site"
	end
	local _, kind = grug_zones.hard_footprint_in(min_x - margin, min_z - margin,
		max_x + margin, max_z + margin)
	return kind
end

function world.cube_clear(pos)
	for dy = 1, 3 do
		for dz = -1, 1 do
			for dx = -1, 1 do
				local node = core.get_node_or_nil({x = pos.x + dx, y = pos.y + dy,
					z = pos.z + dz})
				if not node or node.name ~= "air" then return false end
			end
		end
	end
	return true
end

-- The world queries above, for probes that check placement without a map
-- (replace cube_clear in a copy).
grug_housing.placement_world = world

-- Rulings 2, 3, 5, 6 and 27 for a stone the player would place at pos;
-- returns true, or false, code, message. There is no placing lock (R26
-- ruling 10).
function grug_housing.validate_placement(player, pos)
	if not grug_core.zone_authority_installed() then
		return false, "no_world", "The world is not ready yet."
	end
	local name = player:get_player_name()
	return model.validate(name, grug_core.get_player_faction(name), pos, world)
end

-- Set by Lane C: opens the owner's stone formspec. Lane A's stone node calls
-- it from on_rightclick when the clicker is the owner.
function grug_housing.open_stone_interface(player, claim)
end
