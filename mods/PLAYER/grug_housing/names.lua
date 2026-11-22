-- Home names (Round 86 lane NAMES; docs/design/housing.md "Home names"):
-- every claim has a name its owner (for an account claim: any member, as
-- is_owner says) renames on the stone's form; everyone, the owner too,
-- reads it with the house icon in the entry banner, under the minimap, in
-- the Map tab and in the protection hint. The rule of a typed name and the
-- default live in registry.lua (valid_name, set_name, default_name); this
-- file is the engine side: the rename an owner asks for and the admin
-- reset.
--
--   /claim_name_reset <player> | here   the default name again for the
--                                       player's claim or the claim you
--                                       stand in (`server` privilege)
--
-- A rename shows to everybody inside at their next location sample (about
-- a second; grug_map location.lua reads home_name every sample): nothing
-- is pushed.

local model = grug_housing.model

grug_housing.NAME_MAX = model.NAME_MAX

-- true, or false and the reason, for a name an owner typed.
function grug_housing.valid_name(text)
	return model.valid_name(text)
end

-- The character `name` renames the claim to `text`. Returns true and the
-- line to show, or false and the reason.
function grug_housing.rename(claim, name, text)
	if not grug_housing.is_owner(claim, name) then
		return false, "Only the home's owner can rename it."
	end
	-- The name it has (also a default the rule would refuse, such as one
	-- with "_" or over NAME_MAX characters): nothing to do.
	if text == grug_housing.home_name(claim) then
		return true, "Your home keeps its name."
	end
	local ok, reason = model.set_name(claim, text)
	if not ok then return false, reason end
	grug_housing.notify_claim_changed(claim, "renamed")
	core.log("action", ("[grug_housing] %s renamed claim %d to %q"):format(name,
		claim.id, text))
	return true, ("Your home is now called %s."):format(text)
end

-- The default name again (an admin's reset). Returns true and the name.
function grug_housing.reset_name(claim)
	local ok, name = model.reset_name(claim)
	if ok then grug_housing.notify_claim_changed(claim, "renamed") end
	return ok, name
end

-- The claim of character `name`: its own placed claim, else (an account
-- claim's member) a claim it is an owner of.
local function claim_of(name)
	local claim = model.player_claim(name)
	if claim then return claim end
	for _, other in ipairs(model.all_claims()) do
		if model.is_owner(other, name) then return other end
	end
	return nil
end

core.register_chatcommand("claim_name_reset", {
	params = "<player> | here",
	description = "Give a player's home, or the home you stand in, its default name again",
	privs = {server = true},
	func = function(admin, param)
		param = (param or ""):trim()
		if param == "" then return false, "Usage: /claim_name_reset <player> | here" end
		local claim
		if param == "here" then
			local player = core.get_player_by_name(admin)
			local pos = player and player:get_pos()
			if not pos then return false, "You must be in the world for that." end
			claim = model.claim_at(pos)
			if not claim then return false, "You are not standing in a claim." end
		else
			claim = claim_of(param)
			if not claim then return false, param .. " has no placed Claim Stone." end
		end
		local old = grug_housing.home_name(claim)
		local _, name = grug_housing.reset_name(claim)
		core.log("action", ("[grug_housing] %s reset the name of claim %d from %q to %q"):format(
			admin, claim.id, old, name))
		return true, ("Claim %d is called %s again (was %s)."):format(claim.id, name, old)
	end,
})
