-- Round 31 Lane P1b portable test (docs/planning/round31-plan.md §6 rulings
-- 8 and 9). Loads the REAL files under small stubs:
--   H  grug_abilities/kits.lua: Heal, Shield and Mend
--      aimed at an ally the PvP flag rules out (an unflagged helper, a
--      flagged ally) refuse with a reason and touch nobody -- a false cast
--      return is what makes try_cast spend nothing -- instead of falling back
--      to the caster; aim at no ally (empty, a protected enemy) still casts
--      on the caster; a flagged helper still supports the flagged ally.
--   M  grug_mounts/catalog.lua: within each riding tier every race and
--      faction gets the same collision and selection box (tier 2 the
--      Courser's collision box; tiers 3 and 4 one flyer body), each rider
--      lies inside the selection box, every body passes two-by-two openings,
--      the visual sizes and looks stay per race and faction, and the capital
--      displays keep each model's own box (display_box) for their name tags.
-- Usage (repo root): luajit tools/r31_p1b/portable_test.lua [REPO]
local repo = arg[1] or "."

local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function same_box(a, b)
	if #a ~= #b then return false end
	for i = 1, #a do
		if math.abs(a[i] - b[i]) > 1e-9 then return false end
	end
	return true
end

core = setmetatable({
	get_us_time = function() return 1000000 end,
	add_particlespawner = function() end,
	get_objects_inside_radius = function() return {} end,
}, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return function() end end
	return nil
end})
vector = {
	offset = function(p, x, y, z) return {x = p.x + x, y = p.y + y, z = p.z + z} end,
	distance = function() return 1 end,
	new = function(x, y, z) return {x = x, y = y, z = z} end,
}

------------------------------------------------------------------------------
-- H: the healer refusal.
------------------------------------------------------------------------------
do
	local function player(name, faction, flagged)
		local p = {name = name, faction = faction, flagged = flagged, hp = 50}
		function p:is_player() return true end
		function p:get_player_name() return self.name end
		function p:get_hp() return self.hp end
		function p:get_pos() return {x = 0, y = 0, z = 0} end
		function p:get_properties() return {eye_height = 1.5} end
		return p
	end
	grug_factions = {
		same_faction = function(a, b) return a.faction ~= nil and a.faction == b.faction end,
	}
	local contacts = {}
	grug_pvp = {
		can_support = function(h, t) return h.flagged or not t.flagged end,
		support_contact = function(h, t) contacts[#contacts + 1] = h.name .. ">" .. t.name end,
	}
	local ray
	local heals, absorbs = {}, {}
	grug_core = {
		combat_ray = function() return ray end,
		base_pool = function() return 100 end,
		get_player_level = function() return 1 end,
		heal_player = function(_, target, amount)
			heals[#heals + 1] = target.name
			return amount
		end,
		add_absorb = function(target, _, amount)
			absorbs[#absorbs + 1] = target.name
			return amount
		end,
		set_status = function() end,
	}
	grug_classes = {
		get_talent_bonus = function() return 0 end,
		get_spell_power_bonus = function() return 0 end,
		talent_rank = function() return 0 end,
		-- kits.lua reads Mend's display name from its talent keystone.
		registered_talents = {mend = {name = "Mend"}},
	}
	grug_projectiles = {register = function() end}
	local abilities = {}
	grug_abilities = {
		register_ability = function(def) abilities[def.id] = def end,
		get_range = function(_, def) return def.range or 4 end,
		set_target = function() end,
		valid_target = function(user, obj, kind)
			return kind == "friendly" and obj ~= user and obj:is_player() and
				obj:get_hp() > 0 and grug_factions.same_faction(user, obj) and
				grug_pvp.can_support(user, obj)
		end,
	}
	dofile(repo .. "/mods/PLAYER/grug_abilities/kits.lua")
	local ids = {"heal", "shield_spell", "mend"}
	for _, id in ipairs(ids) do check(abilities[id] ~= nil, "H: " .. id .. " registered") end
	eq(abilities.mend.name, "Mend", "H: Mend takes its display name from the talent keystone")

	local function cast(id, user)
		heals, absorbs, contacts = {}, {}, {}
		local def = abilities[id]
		return def.cast(user, nil, def)
	end
	local function touched()
		return #heals + #absorbs
	end

	local healer = player("healer", "accord", false)
	local ally = player("ally", "accord", true)
	local enemy = player("enemy", "throng", true)
	-- An unflagged healer aiming at a flagged ally: refused, nobody touched.
	ray = {status = "aim_miss", reason = "friendly", target = ally}
	for _, id in ipairs(ids) do
		local ok, err = cast(id, healer)
		check(not ok, "H: " .. id .. " refuses an ally the flag rules out")
		eq(err, grug_abilities.SUPPORT_REFUSED, "H: " .. id .. " says why")
		eq(touched(), 0, "H: " .. id .. " heals and shields nobody, the caster included")
		eq(#contacts, 0, "H: " .. id .. " makes no contact")
	end
	-- Aim at nothing: the caster.
	ray = {status = "aim_miss", reason = "empty"}
	for _, id in ipairs(ids) do
		local ok = cast(id, healer)
		check(ok, "H: " .. id .. " with no ally aimed casts")
	end
	cast("heal", healer)
	eq(heals[1], "healer", "H: Heal with no ally aimed heals the caster")
	cast("shield_spell", healer)
	eq(absorbs[1], "healer", "H: the shield with no ally aimed shields the caster")
	-- Aim at a protected enemy: not an ally, so the caster as before.
	ray = {status = "aim_miss", reason = "protected", target = enemy}
	check(cast("heal", healer) and heals[1] == "healer",
		"H: an enemy in the crosshair still resolves to the caster")
	-- Aim at an unflagged ally: supported.
	local calm = player("calm", "accord", false)
	ray = {status = "aim_miss", reason = "friendly", target = calm}
	check(cast("heal", healer) and heals[1] == "calm", "H: an unflagged ally is healed")
	-- A flagged helper supports the flagged ally and reports the contact.
	healer.flagged = true
	ray = {status = "aim_miss", reason = "friendly", target = ally}
	check(cast("heal", healer) and heals[1] == "ally", "H: a flagged helper heals the flagged ally")
	eq(contacts[1], "healer>ally", "H: the heal reports support contact")
	check(cast("shield_spell", healer) and absorbs[1] == "ally", "H: a flagged helper shields the flagged ally")
	-- A dead ally in the crosshair is no refusal (the existing rule decides).
	healer.flagged = false
	ally.hp = 0
	check(not grug_abilities.support_refused(healer, ally), "H: a dead ally is no PvP refusal")
	grug_factions, grug_pvp, grug_core, grug_classes, grug_projectiles, grug_abilities =
		nil, nil, nil, nil, nil, nil
end

------------------------------------------------------------------------------
-- M: equal mount boxes.
------------------------------------------------------------------------------
do
	table.copy = function(t)
		local out = {}
		for k, v in pairs(t) do out[k] = v end
		return out
	end
	grug_core = {FLIGHT_CEILING = 600}
	grug_mounts = {}
	local race_of = {}
	grug_factions = {get_faction = function(p) return p.faction end}
	grug_classes = {get_race = function(p) return race_of[p] end}
	dofile(repo .. "/mods/PLAYER/grug_mounts/catalog.lua")
	local M = grug_mounts.MODELS
	local races = {human = "accord", dwarf = "accord", elf = "accord",
		undead = "throng", orc = "throng", troll = "throng"}
	-- Every player kind: one per race, each with its faction.
	local players = {}
	for race, faction in pairs(races) do
		local p = {faction = faction}
		race_of[p] = race
		players[#players + 1] = {p = p, label = race .. "/" .. faction}
	end
	for tier = 1, 4 do
		local first = nil
		for _, row in ipairs(players) do
			local model = grug_mounts.model_for(row.p, tier)
			local label = "M: tier " .. tier .. " " .. row.label
			if check(model ~= nil, label .. " has a model") then
				first = first or model
				check(same_box(model.collisionbox, first.collisionbox), label .. " collision box equal")
				check(same_box(model.selectionbox, first.selectionbox), label .. " selection box equal")
				local seat = model.attach_y * model.visual_size.y / 10
				check(model.selectionbox[5] >= seat + 1.8 - 1e-9, label .. " rider inside the selection box")
			end
		end
		check(first.collisionbox[4] - first.collisionbox[1] < 2 and
			first.collisionbox[5] - first.collisionbox[2] < 2,
			"M: tier " .. tier .. " passes two-by-two openings")
	end
	check(same_box(M.human.collisionbox, M.t1_accord.collisionbox), "M: tier 2 collides like the Courser")
	check(same_box(M.expert_accord.collisionbox, M.master_throng.collisionbox),
		"M: tiers 3 and 4 share one flyer body")
	local distinct = {}
	for _, race in ipairs(grug_mounts.RACE_MOUNTS) do distinct[M[race].visual_size.x] = true end
	local n = 0
	for _ in pairs(distinct) do n = n + 1 end
	check(n >= 5, "M: tier-2 visual sizes stay per race (" .. n .. " distinct)")
	check(M.expert_accord.visual_size.x ~= M.master_throng.visual_size.x and
		M.master_accord.visual_size.x ~= M.master_throng.visual_size.x,
		"M: flyer visual sizes stay per tier and faction")
	check(M.expert_accord.mesh ~= M.expert_throng.mesh, "M: flyers keep their faction look")
	-- The riderless capital displays keep each model's own size (name tag
	-- height): display_box, never the shared ridden body.
	for key, top in pairs({human = 1.59, dwarf = 1.45, elf = 1.8, orc = 1.34,
			undead = 1.43, troll = 1.38, t1_accord = 1.59, t1_throng = 1.59,
			expert_accord = 1.5, expert_throng = 1.55, master_accord = 1.9,
			master_throng = 2.05}) do
		eq(M[key].display_box[5], top, "M: " .. key .. " display keeps its own height")
	end
end

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then error("R31 P1B PORTABLE FAIL") end
print("R31 P1B PORTABLE PASS checks=" .. checks)
