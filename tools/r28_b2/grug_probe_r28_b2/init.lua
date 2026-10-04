-- Disposable engine probe (Round 28 Lane B2). Never shipped:
-- tools/r28_b2/run.sh stages it through tools/luanti_headless.sh together
-- with a GAME_PATCH that puts the test catalogue tools/r28_b2/sample/data/
-- into the staged grug_mobs/data/.
--
-- On the real registry and the real mobs_redo AI with the vendored GRUG
-- PATCHes:
--   reg     sub-type prototypes: name, model, size and boxes (rotate kept),
--           disposition and the fields it forces, loot items;
--   zone    display name and tint from the spawn zone (Kapok vs elsewhere),
--           levels inside the sub-type's range;
--   alert   a punch on one mob calls its family (both group_attack), never a
--           neutral relative or another family (the api.lua group alert);
--   drops   kills with a live player tag drop the band table (no static
--           rows), the leader bonus, the static fallback without a table.

local P = "[r28_b2_probe] "
local failures, checks = 0, 0
local FLOOR_Y = 300
local SIZE = 24

local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if ok then
		log("ok   " .. msg)
	else
		failures = failures + 1
		core.log("error", P .. "FAIL " .. msg)
	end
	return ok
end
local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r28 b2 probe done", false, 0)
end
local function near(a, b) return math.abs(a - b) < 1e-6 end

local hook_calls = 0
grug_mobs.register_participant_drop_hook(function() hook_calls = hook_calls + 1 end)

core.register_entity("grug_probe_r28_b2:dummy", {
	initial_properties = {
		physical = true, static_save = false, hp_max = 1000,
		visual = "cube", textures = {"default_stone.png", "default_stone.png",
			"default_stone.png", "default_stone.png", "default_stone.png",
			"default_stone.png"},
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.77, 0.3},
	},
	on_punch = function() return true end,
})

------------------------------------------------------------------------------
-- Registration (runs once mods are loaded).
------------------------------------------------------------------------------
local function proto(name) return core.registered_entities[name] end

local function registration_checks()
	local base, small = proto("grug_mobs:boar"), proto("grug_mobs:small_boar")
	if not check(base and small, "grug_mobs:small_boar is registered") then return end
	for _, role in ipairs({"aggressive_boar", "boar_matriarch", "large_rat",
			"rat_king_odo", "braindead_zombie", "young_wolf", "grizzled_wolf", "bear_cub"}) do
		check(proto("grug_mobs:" .. role) ~= nil, "grug_mobs:" .. role .. " is registered")
	end
	local bp, sp = base.initial_properties, small.initial_properties
	check(small.description == "Small Boar", "description is the display name")
	check(sp.mesh == bp.mesh, "same mesh as the base")
	check(near(sp.visual_size.x, bp.visual_size.x * 0.85), "visual_size x 0.85")
	local box_ok = true
	for i = 1, 6 do
		box_ok = box_ok and near(sp.collisionbox[i], bp.collisionbox[i] * 0.85)
			and near(sp.selectionbox[i], bp.selectionbox[i] * 0.85)
	end
	check(box_ok, "collision and selection boxes x 0.85")
	check(sp.selectionbox.rotate == true, "selection box stays rotated")
	check(grug_mobs.disposition("grug_mobs:small_boar") == "neutral",
		"small boar is neutral")
	check(grug_mobs.disposition("grug_mobs:aggressive_boar") == "aggressive",
		"aggressive boar is aggressive")
	check(small.group_attack == false and small.attack_players == false,
		"neutral: no group alert, no acquisition")
	local aggr = proto("grug_mobs:aggressive_boar")
	check(aggr.group_attack == true and aggr.attack_players == true,
		"aggressive boar: group alert and acquisition")
	check(grug_mobs.family_of("grug_mobs:braindead_zombie") == "zombie"
		and grug_mobs.family_of("grug_mobs:zombie") == "zombie"
		and grug_mobs.family_of("grug_mobs:giant_rat") == "giant_rat",
		"families: sub-type family, existing role")
	local tail = core.registered_items["grug_mobs:rat_tail"]
	check(tail and tail.short_description == "Rat Tail", "rat tail item registered")
	check(core.registered_items["grug_mobs:crop_ledger"] ~= nil, "quest item registered")
	local tusk = core.registered_items["grug_mobs:boar_tusk"]
	check(tusk and tusk.description == "Boar Tusk", "existing boar tusk untouched")
end

------------------------------------------------------------------------------
-- Two small platforms: one in Kapok Cradle, one elsewhere.
------------------------------------------------------------------------------
local function find_zone_origin(want, avoid)
	for r = 0, 60 do
		for i = -r, r do
			for _, c in ipairs({{i, -r}, {i, r}, {-r, i}, {r, i}}) do
				local x, z = c[1] * 128, c[2] * 128
				local ok = true
				for _, d in ipairs({{0, 0}, {SIZE, 0}, {0, SIZE}, {SIZE, SIZE}}) do
					local zone = grug_zones.id_at(x + d[1], z + d[2])
					if (want and zone ~= want) or (avoid and (zone == avoid or not zone)) then
						ok = false
						break
					end
				end
				if ok then return vector.new(x, 0, z) end
			end
		end
	end
end

local function bounds(o)
	return vector.new(o.x, FLOOR_Y - 1, o.z),
		vector.new(o.x + SIZE - 1, FLOOR_Y + 8, o.z + SIZE - 1)
end

local function build(o)
	local minp, maxp = bounds(o)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local stone, air = core.get_content_id("default:stone"), core.get_content_id("air")
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			for y = minp.y, maxp.y do
				data[area:index(x, y, z)] = y <= FLOOR_Y and stone or air
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

local function prepare(origins, done)
	local pending = #origins
	for _, o in ipairs(origins) do
		local minp, maxp = bounds(o)
		for bx = math.floor(minp.x / 16), math.floor(maxp.x / 16) do
			for bz = math.floor(minp.z / 16), math.floor(maxp.z / 16) do
				for by = math.floor(minp.y / 16), math.floor(maxp.y / 16) do
					core.forceload_block(vector.new(bx * 16, by * 16, bz * 16), true, -1)
				end
			end
		end
		core.emerge_area(vector.offset(minp, -16, -16, -16), vector.offset(maxp, 16, 16, 16),
			function(_, _, remaining)
				if remaining > 0 then return end
				core.after(0, function()
					build(o)
					pending = pending - 1
					if pending == 0 then done() end
				end)
			end)
	end
end

local function at(o, dx, dz) return vector.new(o.x + dx, FLOOR_Y + 1, o.z + dz) end

local function spawn(name, pos, level)
	local obj = core.add_entity(pos, name)
	if not check(obj ~= nil, "spawned " .. name) then return nil end
	local ent = obj:get_luaentity()
	if level then ent._grug_level = level end
	return {obj = obj, ent = ent, name = name}
end

------------------------------------------------------------------------------
-- Phases.
------------------------------------------------------------------------------
local kapok, other

-- The bear family's 1-in-10 Elder roll (bear.lua elder_roll, a spawn-row
-- on_spawn right after add_entity): rename, then set_tier elite before the
-- first tick. A bear cub (sub-type) keeps its authored name and tier.
local function elder_roll(rec)
	rec.ent.description = "Elder Bear"
	grug_mobs.set_tier(rec.ent, "elite")
end

local function identity_phase(done)
	local cub = spawn("grug_mobs:bear_cub", at(other, 4, 8))
	local bear = spawn("grug_mobs:bear", at(other, 8, 8))
	if cub then elder_roll(cub) end
	if bear then elder_roll(bear) end
	core.after(1.5, function()
		local ec, eb = cub and cub.obj:get_luaentity(), bear and bear.obj:get_luaentity()
		if ec then
			log("bear cub after the roll: " .. tostring(ec.description) .. " tier " ..
				tostring(ec._grug_tier) .. " tag " .. tostring(ec._grug_tag))
			check(ec._grug_tier == "normal", "bear cub stays normal tier")
			check(ec.description == "Bear Cub", "bear cub keeps its name")
			check(ec._grug_tag and ec._grug_tag:find("^Bear Cub") ~= nil, "nametag says Bear Cub")
			local base = proto("grug_mobs:bear").initial_properties.visual_size.x
			check(near(ec.object:get_properties().visual_size.x, base * 0.8),
				"bear cub keeps its authored size")
		end
		if eb then
			check(eb._grug_tier == "elite" and eb.description == "Elder Bear",
				"a base bear still becomes an Elder Bear")
		end
		for _, r in ipairs({cub, bear}) do if r and r.obj:get_pos() then r.obj:remove() end end
		done()
	end)
end

local function zone_phase(done)
	local a = spawn("grug_mobs:small_boar", at(kapok, 4, 4))
	local b = spawn("grug_mobs:large_rat", at(kapok, 8, 4))
	local c = spawn("grug_mobs:small_boar", at(other, 4, 4))
	core.after(1.5, function()
		local ea, eb, ec = a and a.obj:get_luaentity(), b and b.obj:get_luaentity(),
			c and c.obj:get_luaentity()
		if ea then
			log("kapok small boar: " .. tostring(ea.description) .. " level " ..
				tostring(ea._grug_level) .. " textures " .. dump(ea.base_texture))
			check(ea.description == "Small Jungle Boar", "Kapok: display by zone")
			check(ea.base_texture[1] == "grug_mobs_boar_jungle.png", "Kapok: jungle texture")
			check(ea.object:get_properties().textures[1] == "grug_mobs_boar_jungle.png",
				"Kapok: the object shows the jungle texture")
			check(ea._grug_level >= 1 and ea._grug_level <= 3, "small boar level in 1-3")
		end
		if eb then
			check(eb.base_texture[1] == "grug_mobs_giant_rat.png^[multiply:#9fbf7f",
				"Kapok: large rat modifier tint")
		end
		if ec then
			log("other small boar: " .. tostring(ec.description) .. " zone " ..
				tostring(ec._grug_variant_zone))
			check(ec.description == "Small Boar", "elsewhere: plain display name")
			check(ec.base_texture[1] == "grug_mobs_boar.png^[multiply:#9a7a5a",
				"elsewhere: base texture")
		end
		for _, r in ipairs({a, b, c}) do if r and r.obj:get_pos() then r.obj:remove() end end
		done()
	end)
end

local function punch(target, dummy)
	target.obj:punch(dummy, 1.0, {full_punch_interval = 1.0,
		damage_groups = {fleshy = 1}}, vector.new(1, 0, 0))
end

local function alert_phase(done)
	core.set_timeofday(0)
	local dummy = core.add_entity(at(other, 12, 12), "grug_probe_r28_b2:dummy")
	local rat = spawn("grug_mobs:large_rat", at(other, 10, 10))
	local king = spawn("grug_mobs:rat_king_odo", at(other, 11, 10))
	local giant = spawn("grug_mobs:giant_rat", at(other, 10, 11))
	local zombie = spawn("grug_mobs:braindead_zombie", at(other, 11, 11))
	local small = spawn("grug_mobs:small_boar", at(other, 13, 10))
	local aggr = spawn("grug_mobs:aggressive_boar", at(other, 13, 11))
	local matri = spawn("grug_mobs:boar_matriarch", at(other, 13, 13))
	core.after(1.5, function()
		local function state(r)
			local e = r and r.obj:get_luaentity()
			return e and e.state, e and e.attack
		end
		punch(rat, dummy)
		local s, t = state(king)
		check(s == "attack" and t == dummy, "rat king answers the large rat (family)")
		s = state(giant)
		check(s ~= "attack", "giant rat (own family) stays: " .. tostring(s))
		s = state(zombie)
		check(s ~= "attack", "zombie (other family) stays: " .. tostring(s))
		punch(small, dummy)
		s = state(aggr)
		local s2 = state(matri)
		check(s ~= "attack" and s2 ~= "attack",
			"a punched neutral small boar pulls nobody: " .. tostring(s) .. "/" .. tostring(s2))
		punch(aggr, dummy)
		s, t = state(matri)
		check(s == "attack" and t == dummy, "the matriarch answers the aggressive boar")
		for _, r in ipairs({rat, king, giant, zombie, small, aggr, matri}) do
			if r and r.obj:get_pos() then r.obj:remove() end
		end
		dummy:remove()
		done()
	end)
end

-- Kill with a live player tag; count the dropped stacks around the corpse.
local function kill_and_count(rec, done)
	local ent = rec.obj:get_luaentity()
	if not ent then return done({}) end
	local pos = rec.obj:get_pos()
	ent._grug_player_tag = {name = "probe_player", until_t = core.get_gametime() + 60}
	ent.health = 0
	ent:check_for_death({type = "unknown"})
	core.after(1.0, function()
		local counts = {}
		for _, obj in ipairs(core.get_objects_inside_radius(pos, 6)) do
			local e = obj:get_luaentity()
			if e and e.name == "__builtin:item" then
				local stack = ItemStack(e.itemstring)
				counts[stack:get_name()] = (counts[stack:get_name()] or 0) + stack:get_count()
				obj:remove()
			end
		end
		done(counts)
	end)
end

local function drops_phase(done)
	local plan = {
		-- {name, forced level, x}
		{"grug_mobs:braindead_zombie", nil}, {"grug_mobs:braindead_zombie", nil},
		{"grug_mobs:braindead_zombie", nil}, {"grug_mobs:zombie", 5},
		{"grug_mobs:zombie", 5}, {"grug_mobs:zombie", 5},
		{"grug_mobs:rat_king_odo", nil}, {"grug_mobs:rat_king_odo", nil},
		{"grug_mobs:young_wolf", nil},
	}
	local totals = {}
	local i = 0
	local function step()
		i = i + 1
		local item = plan[i]
		if not item then
			local function n(name, item_name)
				return totals[name] and totals[name][item_name] or 0
			end
			log("drop totals " .. dump(totals))
			check(n("grug_mobs:braindead_zombie", "grug_mobs:zombie_flesh") >= 3,
				"braindead zombie: rotting flesh every kill")
			check(n("grug_mobs:braindead_zombie", "grug_mobs:linen_scrap") == 0
				and n("grug_mobs:braindead_zombie", "grug_materials:iron_bar") == 0,
				"braindead zombie: no static linen or iron")
			check(n("grug_mobs:zombie", "grug_mobs:zombie_flesh") >= 3,
				"zombie L5 (family zombie): flesh every kill")
			check(n("grug_mobs:zombie", "grug_mobs:linen_scrap") == 0
				and n("grug_mobs:zombie", "grug_materials:iron_bar") == 0,
				"zombie L5: the band table replaced the static iron and linen")
			check(n("grug_mobs:rat_king_odo", "grug_mobs:rat_tail") >= 2,
				"rat king: rat tail every kill")
			local fur = n("grug_mobs:rat_king_odo", "grug_mobs:rat_fur_patch")
			check(fur >= 4 and fur <= 6, "rat king: leader bonus 2-3 fur per kill (" .. fur .. ")")
			check(n("grug_mobs:rat_king_odo", "mobs:meat_raw") == 0,
				"rat king: no static giant-rat meat")
			check(n("grug_mobs:young_wolf", "mobs:meat_raw") >= 1,
				"young wolf (no wolf table): the static wolf drops")
			check(hook_calls == 0, "participant hook not called without participants")
			return done()
		end
		local rec = spawn(item[1], at(other, 6 + i * 2, 18), item[2])
		if not rec then return step() end
		core.after(1.2, function()
			local ent = rec.obj:get_luaentity()
			log(item[1] .. " level " .. tostring(ent and ent._grug_level) ..
				" drop rule " .. tostring(ent and ent._grug_drop_rule))
			kill_and_count(rec, function(counts)
				totals[item[1]] = totals[item[1]] or {}
				for k, v in pairs(counts) do
					totals[item[1]][k] = (totals[item[1]][k] or 0) + v
				end
				step()
			end)
		end)
	end
	core.set_timeofday(0)
	step()
end

core.register_on_mods_loaded(registration_checks)

core.after(2, function()
	kapok = find_zone_origin("kragmar_kapok_cradle")
	other = find_zone_origin(nil, "kragmar_kapok_cradle")
	if not check(kapok ~= nil and other ~= nil, "found a Kapok and another column") then
		return finish()
	end
	log("kapok " .. core.pos_to_string(kapok) .. " (" .. grug_zones.id_at(kapok.x, kapok.z) ..
		"), other " .. core.pos_to_string(other) .. " (" .. tostring(grug_zones.id_at(other.x, other.z)) .. ")")
	prepare({kapok, other}, function()
		core.after(1, function()
			zone_phase(function()
				identity_phase(function()
					alert_phase(function()
						drops_phase(finish)
					end)
				end)
			end)
		end)
	end)
end)
