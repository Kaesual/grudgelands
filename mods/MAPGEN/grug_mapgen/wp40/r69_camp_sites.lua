-- The camps under construction of this world, for the box rewrite of the
-- migration 0.69.0 (`camp_rewrite.lua`): {key, place()}, in roster order.
-- `place()` gives a camp's cells as the writer settles them
-- (`r7_settlement.anchor_cells`). The list holds only keys, anchors and the
-- published identities; the cells are rebuilt when a job asks.
--
-- It lives here and not in `r7_runtime.lua` because that file is part of the
-- preparation authority (`preparation_identity.lua`): a change there stops a
-- world in `full` preparation mode at its next start.
-- Plain Lua 5.1, no globals.
return function(wp40, raw_sha256, socket_rows, prepared_blueprints)
	local sites = {}
	for _, row in ipairs(socket_rows) do
		if row.slot == "camp_construction" then
			local prepared = assert(prepared_blueprints[row.key],
				"camp site without a preparation: " .. row.key)
			local anchor, identity = row.anchor, prepared.identity.sha256
			sites[#sites + 1] = {key = row.key, place = function()
				local settlement = dofile(wp40 .. "/r7_settlement.lua")
				for _, profile in ipairs(settlement.roster) do
					if profile.key == row.key then
						local source = dofile(wp40 .. "/" .. profile.blueprint_file)({}, profile)
						return settlement.anchor_cells(profile, source, identity, anchor, raw_sha256)
					end
				end
				error("camp site outside the roster: " .. row.key, 0)
			end}
		end
	end
	return sites
end
