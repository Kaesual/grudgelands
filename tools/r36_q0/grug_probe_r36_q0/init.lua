-- Round 36 lane Q0 engine probe (staged by tools/r36_q0/engine.sh, never
-- shipped): on the real game, a Coal-Purse Factor added in The Broken
-- Causeway carries the ember tint, and keeps it after a relevel recomposes
-- its skin; a war commander wears his faction's tabard over the composed
-- guard skin; the rift boss draws Isquarre's texture; the four renamed quest
-- places stand on the world; the twelve object kinds, the two orders and the
-- three achievements are registered.
local P = "[r36q0] "
local function log(s) core.log("action", P .. s) end
local SR = grug_mobs.spawn_regions
local ok = true
local function expect(cond, what)
	log((cond and "ok   " or "FAIL ") .. what)
	ok = ok and cond
end
local function done()
	log("RESULT " .. (ok and "PASS" or "FAIL"))
	core.request_shutdown("r36q0 probe done", false, 0)
end
local function textures(object)
	local props = object and object:get_properties()
	return props and table.concat(props.textures or {}, " | ") or ""
end

core.register_on_mods_loaded(function()
	local kinds = 0
	for _ in pairs(grug_quests.use_objects) do kinds = kinds + 1 end
	expect(kinds == 12, "twelve quest-object kinds (" .. kinds .. ")")
	for _, id in ipairs({"grug_mobs:throng_captains_orders", "grug_mobs:accord_captains_orders"}) do
		expect(core.registered_items[id] ~= nil, id .. " is registered")
	end
	for _, id in ipairs({"every_name_accounted_for", "our_oaths_are_ours", "last_claim_denied"}) do
		expect(grug_achievements.book.achievement[id] ~= nil, "achievement " .. id)
	end
end)

local spot, emerged
local t, phase, phase_t = 0, "start", 0
core.register_globalstep(function(dtime)
	t, phase_t = t + dtime, phase_t + dtime
	if phase == "start" then
		if t < 3 then return end
		for zone, id in pairs({elandor_stormvault_heights = "brandscar_cairn",
				elandor_glassroot_wilds = "couriers_stump", kragmar_blackwind_rise = "ashen_grave",
				kragmar_thunderroot_wilds = "coinpit_hollow"}) do
			local at = SR.place_spot(zone, id)
			expect(at ~= nil, ("quest place %s/%s at (%s, %s)"):format(zone, id, at and at.x, at and at.z))
		end
		local senn = SR.leader_pos("toll_taker_senn")
		if not senn then expect(false, "Toll-Taker Senn's spot in The Broken Causeway"); return done() end
		local h = math.floor(grug_zones.terrain_height_at(senn.x, senn.z))
		spot = {x = senn.x + 8, y = h + 2, z = senn.z + 8}
		emerged = false
		local lo, hi = vector.subtract(spot, 16), vector.add(spot, 16)
		core.emerge_area(lo, hi, function(_, _, remaining) if remaining == 0 then emerged = true end end)
		for bx = math.floor(lo.x / 16), math.floor(hi.x / 16) do
			for by = math.floor(lo.y / 16), math.floor(hi.y / 16) do
				for bz = math.floor(lo.z / 16), math.floor(hi.z / 16) do
					core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
				end
			end
		end
		phase, phase_t = "emerge", 0
	elseif phase == "emerge" then
		if not emerged and phase_t < 120 then return end
		log(("zone at the spot: %s"):format(grug_zones.id_at(spot.x, spot.z)))
		local bandit = core.add_entity(spot, "grug_mobs:coal_purse_factor")
		local ent = bandit and bandit:get_luaentity()
		expect(ent ~= nil, "a Coal-Purse Factor is added")
		if ent then
			local before = textures(bandit)
			expect(before:find("#B4472A", 1, true) ~= nil, "tinted on activation: " .. before:sub(-60))
			ent._grug_visual_skin = nil -- force the recompose a bracket change would cause
			grug_mobs.relevel(ent, ent._grug_level == 41 and 50 or 41)
			local after = textures(bandit)
			expect(after:find("#B4472A", 1, true) ~= nil, "still tinted after the relevel: " .. after:sub(-60))
			local _, n = after:gsub("#B4472A", "")
			expect(n == 1, "the tint once (" .. n .. ")")
			bandit:remove()
		end
		for _, faction in ipairs({"accord", "throng"}) do
			local commander = core.add_entity(vector.add(spot, {x = 3, y = 0, z = 0}), "grug_mobs:commander_" .. faction)
			local skin = textures(commander)
			expect(skin:find("grug_mobs_commander_" .. faction .. "_overlay.png", 1, true) ~= nil and
				skin:find("grug_visuals", 1, true) ~= nil,
				"the " .. faction .. " commander wears his tabard over a composed skin")
			if commander then commander:remove() end
		end
		local boss = core.add_entity(vector.add(spot, {x = -3, y = 0, z = 0}), "grug_mobs:rift_boss")
		expect(textures(boss):find("grug_mobs_isquarre.png", 1, true) ~= nil, "the rift boss draws Isquarre")
		if boss then boss:remove() end
		done()
	end
end)
