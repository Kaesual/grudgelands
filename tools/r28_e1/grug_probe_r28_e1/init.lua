-- Disposable engine probe (Round 28 Lane E1). Never shipped:
-- tools/r28_e1/run.sh stages it through tools/luanti_headless.sh with a copy
-- of the design catalogue (docs/planning/round28/design/catalog/*.json) in
-- catalog/, so the SHIPPED data in the mods is checked against the catalogue
-- on the real registry and the real mobs_redo AI:
--   reg      every sub-type: registered, base, mesh, size and boxes,
--            disposition and the fields it forces, tier, levels, family,
--            drop family, leader flag, zone keys and tint ids; every tint's
--            texture exists; every item registered with the catalogue name
--            (new ones with their icon brief and their own existing icon
--            texture <mod>_<name>.png), every drop item registered;
--   enchant  588 operations, each costing own material + the catalogue's
--            stat loot + family input;
--   live     every sub-type spawned once: level in range, name, tier,
--            disposition;
--   zone     every zone display name and tint on a spawned mob;
--   drops    one kill (live player tag) per family and band, plus the bands
--            only another family's member reaches and one leader per drop
--            family with a leader bonus: every dropped item comes from the
--            band table (plus the bonus for a leader), every guaranteed row
--            drops.

local P = "[r28_e1_probe] "
local MODPATH = core.get_modpath(core.get_current_modname())
local failures, checks = 0, 0
local FLOOR_Y = 300
local SIZE = 48
local SPACING = 6

local function log(msg) core.log("action", P .. msg) end
-- Quiet on success (thousands of checks); every failure is an ERROR line.
local function check(ok, msg)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		core.log("error", P .. "FAIL " .. msg)
	end
	return ok
end
local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r28 e1 probe done", false, 0)
end
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

local function read_catalog(file)
	local handle = assert(io.open(MODPATH .. "/catalog/" .. file, "r"), "catalog/" .. file)
	local text = handle:read("*a")
	handle:close()
	return assert(core.parse_json(text), "catalog/" .. file .. " parses")
end

local SUBS = read_catalog("subtypes.json")
local ITEMS = read_catalog("items.json")
local DROPS = {}
for _, row in ipairs(read_catalog("drops.json")) do DROPS[row.family] = row end
local TINTS = {}
for _, row in ipairs(read_catalog("tints.json")) do TINTS[row.id] = row end
local ENCHANTS = {}
for _, row in ipairs(read_catalog("enchants.json")) do ENCHANTS[row.tier] = row end
local REAGENTS = read_catalog("reagents.json")

local function band_range(band) return (band - 1) * 10 + 1, band * 10 end
local function expected_tier(row)
	return row.disposition == "critter" and "critter" or (row.tier or "normal")
end
local function first_line(text)
	return (core.get_translated_string("en", tostring(text or "")):match("^[^\n]*"))
end

------------------------------------------------------------------------------
-- Registration (once mods are loaded).
------------------------------------------------------------------------------
local function texture_exists(file)
	for _, mod in ipairs(core.get_modnames()) do
		local handle = io.open(core.get_modpath(mod) .. "/textures/" .. file, "r")
		if handle then
			handle:close()
			return true
		end
	end
	return false
end

local function subtype_checks()
	local zones = {}
	for _, id in ipairs(grug_mobs.spawn_areas.zone_ids()) do zones[id] = true end
	local registered, leaders = 0, 0
	for _, row in ipairs(SUBS) do
		local name = "grug_mobs:" .. row.role
		local proto, base = core.registered_entities[name], core.registered_entities[row.base]
		local sub = grug_mobs.subtype(name)
		if check(proto and base and sub, name .. " registered (base " .. row.base .. ")") then
			registered = registered + 1
			if sub.leader then leaders = leaders + 1 end
			local pp, bp = proto.initial_properties, base.initial_properties
			check(sub.base == row.base and pp.mesh == bp.mesh and pp.visual == bp.visual,
				name .. " is a copy of " .. row.base)
			local s = row.size
			local boxes = near(pp.visual_size.x, bp.visual_size.x * s)
				and near(pp.visual_size.y, bp.visual_size.y * s)
			for i = 1, 6 do
				boxes = boxes and near(pp.collisionbox[i], bp.collisionbox[i] * s)
				if bp.selectionbox then
					boxes = boxes and near(pp.selectionbox[i], bp.selectionbox[i] * s)
				end
			end
			check(boxes, name .. " visual size and boxes x " .. s)
			check(proto.description == row.display, name .. " display " .. row.display)
			check(grug_mobs.disposition(name) == row.disposition,
				name .. " disposition " .. row.disposition)
			if row.disposition == "neutral" then
				check(proto.attack_players == false and proto.group_attack == false,
					name .. " neutral: no acquisition, no group alert")
			elseif row.disposition == "aggressive" then
				check(proto.attack_type ~= nil and proto.attack_players ~= false,
					name .. " aggressive with an attack")
			end
			check(sub.tier == (row.tier or "normal"), name .. " tier " .. tostring(row.tier))
			check(sub.levels[1] == row.levels[1] and sub.levels[2] == row.levels[2],
				name .. " levels")
			check(grug_mobs.family_of(name) == row.family, name .. " family " .. row.family)
			check(sub.drops == row.drops, name .. " drop family " .. row.drops)
			check(sub.leader == (row.leader == true), name .. " leader flag")
			for zone, tint in pairs(row.tint_by_zone or {}) do
				check(zones[zone] and TINTS[tint], name .. " tint " .. tint .. " in zone " .. zone)
			end
			for zone in pairs(row.display_by_zone or {}) do
				check(zones[zone], name .. " display zone " .. zone)
			end
		end
	end
	log(("sub-types: %d of %d registered, %d leaders"):format(registered, #SUBS, leaders))
	check(registered == 188 and leaders == 49, "188 sub-types, 49 leaders")
	for id, tint in pairs(TINTS) do
		if tint.texture then
			check(texture_exists(tint.texture), "tint " .. id .. " texture " .. tint.texture .. " exists")
		else
			check(type(tint.modifier) == "string" and tint.modifier:sub(1, 2) == "^[",
				"tint " .. id .. " modifier")
		end
	end
end

local function item_checks()
	local new, existing, kinds = 0, 0, {}
	for _, row in ipairs(ITEMS) do
		kinds[row.kind] = (kinds[row.kind] or 0) + 1
		local def = core.registered_items[row.id]
		if check(def, row.id .. " (" .. row.kind .. ") registered") then
			if def._grug_icon_brief then
				new = new + 1
				check(row.icon and def._grug_icon_brief == row.icon and def.short_description == row.name
					and def.mod_origin == "grug_mobs", row.id .. " new item: name and icon brief")
				-- Round 28 art: every new item ships its own icon <mod>_<name>.png.
				local icon = row.id:gsub(":", "_") .. ".png"
				check(def.inventory_image == icon and texture_exists(icon),
					row.id .. " inventory image " .. tostring(def.inventory_image) .. " is its own icon")
				if row.kind == "signature" then
					check(def.groups.grug_material == 1, row.id .. " is a mob material")
					check(def._grug_sell_price == row.tier and grug_traders.sell_price(row.id) == row.tier,
						row.id .. " sells for " .. row.tier .. "c")
					check(grug_jobs.ingredient_tier(row.id) == row.tier,
						row.id .. " ingredient tier " .. row.tier)
				else
					check(def._grug_sell_price == nil, row.id .. " quest item has no price")
				end
			else
				existing = existing + 1
				check(row.icon == nil, row.id .. " has an icon brief but was registered before")
				check(first_line(def.short_description or def.description) == row.name,
					row.id .. " existing name " .. tostring(def.description) .. " = " .. row.name)
			end
		end
	end
	log(("items: %d signature, %d generic, %d quest; %d new, %d existing"):format(
		kinds.signature or 0, kinds.generic or 0, kinds.quest or 0, new, existing))
	check(#ITEMS == 119 and new == 89, "119 items, 89 new")
	local rows, missing = 0, 0
	for family, entry in pairs(DROPS) do
		local lists = {entry.leader_bonus or {}}
		for _, list in pairs(entry.bands) do lists[#lists + 1] = list end
		for _, list in ipairs(lists) do
			for _, r in ipairs(list) do
				rows = rows + 1
				if not check(core.registered_items[r.item], family .. " drops unknown " .. r.item) then
					missing = missing + 1
				end
			end
		end
	end
	log(("drops: %d rows, %d unknown items"):format(rows, missing))
end

local function enchant_checks()
	local operations = grug_jobs.station_operations()
	check(#operations == 588, "588 enchant operations (got " .. #operations .. ")")
	local per_profession, used = {}, {}
	for _, op in ipairs(operations) do
		per_profession[op.profession] = (per_profession[op.profession] or 0) + 1
		local row, inputs = ENCHANTS[op.tier], op.flat_inputs
		check(row and #inputs == 3 and inputs[2] == row.stat_loot[op.enchant_stat]
			and inputs[3] == row.family_input[op.family],
			op.id .. " costs " .. table.concat(inputs, ","))
		used[inputs[2]] = true
		used[inputs[3]] = true
	end
	check(per_profession.weaponsmith == 204 and per_profession.armorsmith == 84 and
		per_profession.leatherworker == 60 and per_profession.tailor == 48 and
		per_profession.woodcarver == 108 and per_profession.goldsmith == 84,
		"operations per profession")
	-- Every catalogue input is used by some operation.
	local inputs = 0
	for tier = 1, 6 do
		for _, item in pairs(ENCHANTS[tier].stat_loot) do
			check(used[item], "T" .. tier .. " stat loot " .. item .. " is used")
			inputs = inputs + 1
		end
		for _, item in pairs(ENCHANTS[tier].family_input) do
			check(used[item], "T" .. tier .. " family input " .. item .. " is used")
			inputs = inputs + 1
		end
	end
	check(#REAGENTS == 0, "the catalogue has no universal reagent")
	local sword = grug_jobs.station_operation("enchant:sword:prefix:str:t1")
	log("sample: sword T1 Strength = " .. table.concat(sword and sword.flat_inputs or {}, " + "))
	log(("enchants: %d operations, %d catalogue bindings checked"):format(#operations, inputs))
end

------------------------------------------------------------------------------
-- One platform, a grid of spawn slots.
------------------------------------------------------------------------------
local origin

local function find_origin()
	for r = 0, 60 do
		for i = -r, r do
			for _, c in ipairs({{i, -r}, {i, r}, {-r, i}, {r, i}}) do
				local x, z = c[1] * 128, c[2] * 128
				local ok = true
				for _, d in ipairs({{0, 0}, {SIZE, 0}, {0, SIZE}, {SIZE, SIZE}}) do
					if not grug_zones.id_at(x + d[1], z + d[2]) then
						ok = false
						break
					end
				end
				if ok then return vector.new(x, 0, z) end
			end
		end
	end
end

local function bounds()
	return vector.new(origin.x, FLOOR_Y - 1, origin.z),
		vector.new(origin.x + SIZE - 1, FLOOR_Y + 8, origin.z + SIZE - 1)
end

local function build()
	local minp, maxp = bounds()
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

local function prepare(done)
	local minp, maxp = bounds()
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
				build()
				done()
			end)
		end)
end

local PER_ROW = math.floor(SIZE / SPACING)
local BATCH = PER_ROW * PER_ROW
local function slot(i)
	local k = (i - 1) % BATCH
	return vector.new(origin.x + SPACING / 2 + (k % PER_ROW) * SPACING, FLOOR_Y + 1,
		origin.z + SPACING / 2 + math.floor(k / PER_ROW) * SPACING)
end

-- Feet on the floor: a box reaching below the origin (golem, spider, treant)
-- would otherwise start inside the stone and suffocate. Elites grow x1.4.
local function spawn(name, pos, static)
	local proto = core.registered_entities[name]
	local sub = grug_mobs.subtype(name)
	local low = proto and proto.initial_properties.collisionbox[2] or 0
	if sub and sub.tier == "elite" then low = low * 1.4 end
	pos = vector.new(pos.x, FLOOR_Y + 0.6 - math.min(0, low), pos.z)
	local obj = core.add_entity(pos, name, core.serialize(static or {}))
	if not check(obj ~= nil, "spawned " .. name) then return nil end
	return obj
end

-- Runs `list` in batches of one platform grid: start(entry, pos) returns the
-- object, then after `wait` seconds settle(entries, objects, next_batch).
local function batches(list, wait, start, settle, done)
	local first = 1
	local function step()
		if first > #list then return done() end
		local entries, objects = {}, {}
		for i = first, math.min(#list, first + BATCH - 1) do
			entries[#entries + 1] = list[i]
			objects[#objects + 1] = start(list[i], slot(#entries)) or false
		end
		first = first + BATCH
		core.after(wait, function() settle(entries, objects, step) end)
	end
	step()
end

local function remove_all(objects)
	for _, obj in ipairs(objects) do
		if obj and obj:get_pos() then obj:remove() end
	end
end

------------------------------------------------------------------------------
-- Live phase: every sub-type once.
------------------------------------------------------------------------------
local function live_phase(done)
	local seen = 0
	batches(SUBS, 1.5, function(row, pos)
		return spawn("grug_mobs:" .. row.role, pos, {_grug_variant_zone = ""})
	end, function(rows, objects, next_batch)
		for i, row in ipairs(rows) do
			local name = "grug_mobs:" .. row.role
			local ent = objects[i] and objects[i]:get_luaentity()
			if check(ent, name .. " alive after activation") then
				seen = seen + 1
				local level = ent._grug_level
				check(level and level >= row.levels[1] and level <= row.levels[2],
					name .. " level " .. tostring(level) .. " in " .. row.levels[1] .. "-" .. row.levels[2])
				check(ent.description == row.display, name .. " live name " .. tostring(ent.description))
				check(ent._grug_tier == expected_tier(row), name .. " live tier " .. tostring(ent._grug_tier))
				check(ent._grug_disposition == row.disposition,
					name .. " live disposition " .. tostring(ent._grug_disposition))
			end
		end
		remove_all(objects)
		next_batch()
	end, function()
		log(("live: %d of %d sub-types activated"):format(seen, #SUBS))
		done()
	end)
end

------------------------------------------------------------------------------
-- Zone phase: every zone name and tint, and a zone-less control per tint.
------------------------------------------------------------------------------
local function tint_shown(textures, tint)
	for _, t in ipairs(textures or {}) do
		if tint.texture and t == tint.texture then return true end
		if tint.modifier and t:find(tint.modifier, 1, true) then return true end
	end
	return false
end

local function zone_phase(done)
	local list = {}
	for _, row in ipairs(SUBS) do
		local keys = {}
		for zone in pairs(row.display_by_zone or {}) do keys[zone] = true end
		for zone in pairs(row.tint_by_zone or {}) do keys[zone] = true end
		local sorted = {}
		for zone in pairs(keys) do sorted[#sorted + 1] = zone end
		table.sort(sorted)
		for _, zone in ipairs(sorted) do list[#list + 1] = {row = row, zone = zone} end
		if next(row.tint_by_zone or {}) then list[#list + 1] = {row = row, zone = ""} end
	end
	local tinted = 0
	batches(list, 1.5, function(entry, pos)
		return spawn("grug_mobs:" .. entry.row.role, pos, {_grug_variant_zone = entry.zone})
	end, function(entries, objects, next_batch)
		for i, entry in ipairs(entries) do
			local row, zone = entry.row, entry.zone
			local label = row.role .. " in " .. (zone == "" and "(no zone)" or zone)
			local ent = objects[i] and objects[i]:get_luaentity()
			if check(ent, label .. " alive") then
				local want = (row.display_by_zone or {})[zone] or row.display
				check(ent.description == want, label .. " shows " .. want .. " (got " ..
					tostring(ent.description) .. ")")
				local textures = ent.object:get_properties().textures
				local tint_id = (row.tint_by_zone or {})[zone]
				if tint_id then
					tinted = tinted + 1
					check(tint_shown(textures, TINTS[tint_id]), label .. " tint " .. tint_id ..
						" (textures " .. table.concat(textures or {}, ", ") .. ")")
				elseif zone == "" then
					for id, tint in pairs(TINTS) do
						check(not tint_shown(textures, tint), label .. " untinted, not " .. id)
					end
				end
			end
		end
		remove_all(objects)
		next_batch()
	end, function()
		log(("zone: %d spawns, %d tinted"):format(#list, tinted))
		done()
	end)
end

------------------------------------------------------------------------------
-- Drop phase.
------------------------------------------------------------------------------
local function overlaps(row, band)
	local lo, hi = band_range(band)
	return row.levels[1] <= hi and row.levels[2] >= lo
end

local function kill_plan()
	local by_family, families = {}, {}
	for _, row in ipairs(SUBS) do
		if not by_family[row.family] then
			by_family[row.family] = {}
			families[#families + 1] = row.family
		end
		table.insert(by_family[row.family], row)
	end
	table.sort(families)
	local function pick(rows, band, want_leader)
		local best
		for _, row in ipairs(rows) do
			if (band == nil or overlaps(row, band)) and (want_leader == nil
					or (row.leader == true) == want_leader) then
				if not best or ((best.leader == true) and not row.leader)
						or ((best.leader == true) == (row.leader == true) and row.role < best.role) then
					best = row
				end
			end
		end
		return best
	end
	local plan, covered = {}, {}
	local function add(row, band, why)
		local lo, hi = band_range(band)
		plan[#plan + 1] = {row = row, band = band, level = math.max(lo, row.levels[1]),
			why = why}
		covered[row.drops .. "/" .. band] = true
	end
	-- One per combat family and band.
	for _, family in ipairs(families) do
		for band = 1, 6 do
			local row = pick(by_family[family], band)
			if row then add(row, band, "family") end
		end
	end
	-- Drop-family bands no family pick reached.
	for _, row in ipairs(SUBS) do
		for band = 1, 6 do
			if overlaps(row, band) then
				local key = row.drops .. "/" .. band
				if not covered[key] then add(row, band, "drop band") end
			end
		end
	end
	-- One leader per drop family with a leader bonus.
	local leader_for = {}
	for _, row in ipairs(SUBS) do
		local bonus = DROPS[row.drops] and DROPS[row.drops].leader_bonus
		if row.leader and bonus and #bonus > 0 and not leader_for[row.drops] then
			leader_for[row.drops] = row
			local band = math.floor((row.levels[1] - 1) / 10) + 1
			add(row, band, "leader")
		end
	end
	local pairs_count = 0
	for _ in pairs(covered) do pairs_count = pairs_count + 1 end
	log(("drop plan: %d kills over %d drop family/band pairs"):format(#plan, pairs_count))
	check(pairs_count == 86, "all 86 drop family/band pairs are killed")
	return plan
end

local function allowed_rows(entry)
	local family_table = DROPS[entry.row.drops] or {bands = {}}
	local rows = {}
	for _, r in ipairs(family_table.bands[tostring(entry.band)] or {}) do
		rows[#rows + 1] = r
	end
	if entry.row.leader then
		for _, r in ipairs(family_table.leader_bonus or {}) do
			rows[#rows + 1] = r
		end
	end
	return rows
end

local function drops_phase(done)
	local plan = kill_plan()
	local kills, items_seen = 0, 0
	batches(plan, 1.2, function(entry, pos)
		local obj = spawn("grug_mobs:" .. entry.row.role, pos, {_grug_variant_zone = ""})
		local ent = obj and obj:get_luaentity()
		if ent then
			-- Before the first step, as a spawn row's level would be.
			ent._grug_level = entry.level
			ent._grug_no_quality_loot = true
		end
		return obj
	end, function(entries, objects, next_batch)
		local deaths = {}
		for i, entry in ipairs(entries) do
			local label = entry.row.role .. " L" .. entry.level .. " (" .. entry.why .. ")"
			local ent = objects[i] and objects[i]:get_luaentity()
			if check(ent, label .. " alive before the kill") then
				check(ent._grug_level == entry.level, label .. " kept its level (" ..
					tostring(ent._grug_level) .. ")")
				deaths[i] = ent.object:get_pos()
				ent._grug_player_tag = {name = "probe_player", until_t = core.get_gametime() + 60}
				ent.health = 0
				ent:check_for_death({type = "unknown"})
				kills = kills + 1
			end
		end
		core.after(1.0, function()
			-- Every dropped stack goes to the nearest death position.
			local got = {}
			local center = vector.new(origin.x + SIZE / 2, FLOOR_Y + 1, origin.z + SIZE / 2)
			for _, obj in ipairs(core.get_objects_inside_radius(center, SIZE)) do
				local e = obj:get_luaentity()
				if e and e.name == "__builtin:item" then
					local pos, best, best_d = obj:get_pos(), nil, nil
					for i, d in pairs(deaths) do
						local dist = (pos.x - d.x) ^ 2 + (pos.z - d.z) ^ 2
						if not best_d or dist < best_d then best, best_d = i, dist end
					end
					if best then
						local stack = ItemStack(e.itemstring)
						got[best] = got[best] or {}
						got[best][stack:get_name()] = (got[best][stack:get_name()] or 0) + stack:get_count()
						items_seen = items_seen + stack:get_count()
					end
					obj:remove()
				end
			end
			for i in pairs(deaths) do
				local entry = entries[i]
				local label = entry.row.role .. " L" .. entry.level .. " drops " .. entry.row.drops ..
					" T" .. entry.band .. " (" .. entry.why .. ")"
				local rows, max_of, need = allowed_rows(entry), {}, {}
				for _, r in ipairs(rows) do
					max_of[r.item] = (max_of[r.item] or 0) + (r.max or 1)
					if r.chance == 1 then need[r.item] = (need[r.item] or 0) + (r.min or 1) end
				end
				check(#rows > 0, label .. " has a band table")
				local list = {}
				for item, count in pairs(got[i] or {}) do
					list[#list + 1] = item .. " x" .. count
					check(max_of[item] and count <= max_of[item],
						label .. " dropped " .. item .. " x" .. count .. " from its band table")
				end
				for item, count in pairs(need) do
					check(((got[i] or {})[item] or 0) >= count, label .. " guaranteed " .. item)
				end
				table.sort(list)
				log(label .. ": " .. (#list > 0 and table.concat(list, ", ") or "nothing"))
			end
			remove_all(objects)
			next_batch()
		end)
	end, function()
		log(("drops: %d kills, %d items"):format(kills, items_seen))
		done()
	end)
end

------------------------------------------------------------------------------

core.register_on_mods_loaded(function()
	subtype_checks()
	item_checks()
	enchant_checks()
end)

core.after(2, function()
	origin = find_origin()
	if not check(origin ~= nil, "found a platform column") then return finish() end
	log("platform " .. core.pos_to_string(origin) .. " (" .. grug_zones.id_at(origin.x, origin.z) .. ")")
	core.set_timeofday(0)
	prepare(function()
		core.after(1, function()
			live_phase(function()
				zone_phase(function()
					drops_phase(finish)
				end)
			end)
		end)
	end)
end)
