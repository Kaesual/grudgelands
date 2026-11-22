-- The Claim Stone's placement preview, per map chunk (Round 86 lane PREVIEW;
-- docs/design/housing.md §2 "Placement preview"). Pure: the registry model
-- and the claim mask come in as arguments, so the game (api.lua, for the
-- minimap's claim mode) and tools/r86_preview run these bytes.
--
-- chunk_refusal answers for one chunk exactly what registry.lua validate
-- answers for the chunk's own sake, in validate's order: no claim mask (its
-- build failed: nothing is allowed), the mask's rule (its reason id, an
-- unknown one as "not_ground"), a claim record already in the chunk, the
-- quota (with the kind id). A chunk it allows is never refused for the
-- chunk; inside it a placement can still be refused by the player's own
-- state (depth, faction, a stone already placed) or the spot (the chunk's
-- edge, the arrival cube), which validate names when it happens.
--
--   local P = dofile(".../preview.lua")
--   P.chunk_refusal(model, mask, faction, cx, cz) -> nil, or code [, kind id]
--   P.hint(code, kind_label)                      -> the line beside the
--                                                    minimap for the chunk the
--                                                    player stands in
local P = {}

function P.chunk_refusal(model, mask, faction, cx, cz)
	if faction ~= "accord" and faction ~= "throng" then return "no_faction" end
	if not mask then return "no_mask" end
	local ground, reason = mask.ground(faction, cx, cz)
	if not ground then
		return model.MESSAGES[reason] and reason or "not_ground"
	end
	if model.chunk_claim(cx, cz) then return "taken" end
	local kind = mask.quota_refusal(cx, cz, model.quota_taken(mask))
	if kind then return "quota", kind end
	return nil
end

-- Why the square the player stands in cannot be claimed, short enough for
-- one HUD line; the refusal on placing (registry.lua MESSAGES) says the
-- same at length ("too near": within 16 nodes). "%s" in quota is the
-- kind's spawn area by its name.
P.HINTS = {
	no_faction = "choose a faction first",
	taken = "a Claim Stone already stands in it",
	quota = "too much of %s is claimed already",
	shelf = "it reaches over the coastal shelf",
	sea = "it reaches over the open sea",
	enemy = "it reaches into enemy territory",
	low_level = "it reaches into a level 1-10 zone",
	high_level = "it reaches into a level 31+ zone",
	not_home = "not all of it is your faction's home land",
	town = "too near a town or protected landmark",
	deep_water = "it reaches over protected deep water",
	site = "too near a village, camp or point of interest",
	landmark = "too near a protected landmark",
	road = "a road runs through it",
	camp = "a camp's grounds reach into it",
	leader = "too near where a zone leader stands",
	place = "too near a quest place",
	rare = "too near a rare creature's path",
	capital_ring = "it lies next to a capital's walls",
	not_ground = "it is no claim ground",
}
P.FREE = "This square: free to claim"
P.NO_MASK = "No Claim Stone can be placed: this world's\nclaim map failed to build. Tell an admin."

function P.hint(code, kind_label)
	if not code then return P.FREE end
	if code == "no_mask" then return P.NO_MASK end
	local text = P.HINTS[code] or P.HINTS.not_ground
	if code == "quota" then text = text:format(kind_label or "a creature's ground") end
	return "This square: " .. text
end

return P
