-- Interface contract (plan section "Lanes"). Lane A replaces these stubs with
-- the real claim core; the signatures and return shapes are fixed so Lanes
-- B, C and D can code against them from the start.
--
-- A claim is a table { id, owner, center = {x, y, z}, placed_at, paid_until }
-- (seconds of os.time()), plus whatever else Lane A needs.

-- Claim size and placement bounds (rulings 1-2).
grug_housing.RADIUS = 50
grug_housing.MIN_Y = -100

-- The soulbound Claim Stone item, registered by Lane A.
grug_housing.STONE_ITEM = "grug_housing:claim_stone"

-- The claim covering pos (x/z only, y >= MIN_Y), or nil.
function grug_housing.claim_at(pos)
	return nil
end

-- True while the claim has fuel (paid_until is in the future).
function grug_housing.is_active(claim)
	return false
end

-- Whole seconds of fuel left, 0 when empty.
function grug_housing.remaining_seconds(claim)
	return 0
end

-- "owner", "everything", "interact" or nil for this player name.
function grug_housing.permission(claim, name)
	return nil
end

-- The player's claim (or nil) and a state: "never", "carried", "placed",
-- "destroyed" or "needs_stone".
function grug_housing.player_claim(name)
	return nil, "never"
end

-- Housing Manager hand-out (ruling 7): gives the stone when the player is
-- level 20+ and has none; returns ok, message.
function grug_housing.issue_stone(player)
	return false, "Housing is not available yet."
end

-- Burns count lumps into paid_until; returns the number accepted.
function grug_housing.add_fuel(claim, count)
	return 0
end

-- Owner pick-up through the stone interface; returns ok, message.
function grug_housing.pick_up(player)
	return false, "Housing is not available yet."
end

-- level is "everything", "interact" or nil (remove); returns ok, message.
function grug_housing.set_permission(claim, name, level)
	return false, "Housing is not available yet."
end

-- The centre of the 3 x 3 x 3 arrival cube above the stone (ruling 6).
function grug_housing.arrival_pos(claim)
	local c = claim.center
	return {x = c.x, y = c.y + 1, z = c.z}
end

-- fn(claim, event) runs after every change; event is one of "placed",
-- "fuel", "permission", "picked_up", "destroyed", "expired".
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

-- Set by Lane C: opens the owner's stone formspec. Lane A's stone node calls
-- it from on_rightclick when the clicker is the owner.
function grug_housing.open_stone_interface(player, claim)
end
