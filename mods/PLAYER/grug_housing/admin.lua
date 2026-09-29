-- Admin removal of claims and orphaned stones (Round 26 ruling 12, Round 25
-- carry-over). A fuelled stone nobody can dig, or a stone node left without
-- its registry row (a crash between the map save and the mod-storage save),
-- needs a way out that is not a world edit.
--
--   /claim_remove <player>   the player's placed claim (draft, fuelled or
--                            empty) and its stone
--   /claim_remove here       the claim covering the admin's position
--   /claim_remove orphans    every Claim Stone node without a claim within
--                            ORPHAN_RADIUS nodes of the admin
--
-- A removed claim ends like a destroyed one: the owner's state becomes
-- "destroyed" (a new stone from a Housing Steward at once, no placing lock),
-- the "destroyed" event resets a claim home, nothing is refunded. Needs the
-- `server` privilege.

local model = grug_housing.model
local ORPHAN_RADIUS = 16

local function remove_claim(claim, admin)
	local had_node = grug_housing.remove_stone_node(claim)
	model.remove(claim, "destroyed")
	grug_housing.notify_claim_changed(claim, "destroyed")
	local owner = core.get_player_by_name(claim.owner)
	if owner then
		core.chat_send_player(claim.owner, "An admin removed your Claim Stone. " ..
			"A Housing Steward gives you a new one.")
	end
	core.log("action", ("[grug_housing] %s removed Claim Stone %d of %s at %s%s"):format(
		admin, claim.id, claim.owner, core.pos_to_string(claim.center),
		had_node and "" or " (no stone node found)"))
	return ("Removed Claim Stone %d of %s at %s."):format(claim.id, claim.owner,
		core.pos_to_string(claim.center))
end

-- Stone nodes whose position is no claim's centre, around pos.
local function remove_orphans(pos, admin)
	local r = ORPHAN_RADIUS
	local minp = vector.round(vector.subtract(pos, r))
	local maxp = vector.round(vector.add(pos, r))
	core.load_area(minp, maxp)
	local found = core.find_nodes_in_area(minp, maxp, {"group:grug_claim_stone_node"})
	local removed = 0
	for _, at in ipairs(found) do
		local claim = model.claim_at(at)
		if not (claim and vector.equals(claim.center, at)) then
			core.remove_node(at)
			removed = removed + 1
			core.log("action", ("[grug_housing] %s removed an orphaned Claim Stone " ..
				"node at %s"):format(admin, core.pos_to_string(at)))
		end
	end
	return ("Removed %d orphaned Claim Stone node(s) within %d nodes (%d stone " ..
		"node(s) checked)."):format(removed, r, #found)
end

core.register_chatcommand("claim_remove", {
	params = "<player> | here | orphans",
	description = "Remove a player's Claim Stone claim, the claim you stand " ..
		"in, or orphaned Claim Stone nodes near you",
	privs = {server = true},
	func = function(name, param)
		param = (param or ""):trim()
		if param == "" then
			return false, "Usage: /claim_remove <player> | here | orphans"
		end
		if param == "here" or param == "orphans" then
			local admin = core.get_player_by_name(name)
			local pos = admin and admin:get_pos()
			if not pos then return false, "You must be in the world for that." end
			if param == "orphans" then return true, remove_orphans(pos, name) end
			local claim = model.claim_at(pos)
			if not claim then return false, "You are not standing in a claim." end
			return true, remove_claim(claim, name)
		end
		local claim, state = model.player_claim(param)
		if not claim then
			return false, ("%s has no placed Claim Stone (state: %s)."):format(param, state)
		end
		return true, remove_claim(claim, name)
	end,
})
