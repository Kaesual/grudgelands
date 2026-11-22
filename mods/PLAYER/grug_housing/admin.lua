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
-- `<player>` may name a member of an account claim (Round 86, plan §2.3):
-- the account's claim, or the member's own draft, is removed.
--
-- A removed claim ends like a destroyed one, with its own wording: the
-- owner's state becomes "removed" ("Your Claim Stone was removed by an admin"
-- on the Character page; a new stone from a Housing Steward at once, no
-- placing lock), the "removed" event resets a claim home, nothing is
-- refunded. Needs the `server` privilege.
--
-- The deletion of a character (Round 83 ruling 3) releases its claims the
-- same way, with the event "deleted" (grug_home writes no "claim lost" notice
-- for it) and without a log line (the deletion's one line is grug_bridge's);
-- its record and its rights in other claims go too.

local model = grug_housing.model
local ORPHAN_RADIUS = 16

local function remove_claim(claim, admin)
	local had_node = grug_housing.remove_stone_node(claim)
	model.remove(claim, "removed")
	grug_housing.notify_claim_changed(claim, "removed")
	-- Round 86: every member of an account claim hears it.
	for _, name in ipairs(model.owner_names(claim)) do
		if core.get_player_by_name(name) then
			core.chat_send_player(name, "Your Claim Stone was removed by an " ..
				"admin. A Housing Steward gives you a new one.")
		end
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

-- The deletion's clear (grug_core/character_delete.lua): every claim the name
-- owns, not only its record's (an orphan from a crash goes as well), and its
-- rights in the others. Round 86: deliberately the claims stored under the
-- name itself, not is_owner: an account claim (owner text
-- `account:<id>:<faction>`) never matches, so a member's deletion leaves it
-- (its membership: lane STONE).
function grug_housing.forget_character(name)
	-- Round 86: a member's membership ends by its own record (grug_accounts
	-- forgot the binding first); the last member's account claim ends with
	-- the event "deleted" (account.lua).
	grug_housing.end_account_membership(name, "deleted")
	for _, claim in ipairs(model.all_claims()) do
		if claim.owner == name then
			grug_housing.remove_stone_node(claim)
			model.remove(claim, "deleted")
			grug_housing.notify_claim_changed(claim, "deleted")
		elseif claim.permissions[name] then
			grug_housing.set_permission(claim, name, nil)
		end
	end
	model.forget_player(name)
	grug_housing.recovered.forget(name)
end
