--
-- Mob sub-types, families, loot items and loot by band (Round 28 rulings 35
-- and 36, biomes_mobs.md "Sub-types" and "Loot by band"; data formats in
-- docs/planning/round28-design-frame.md §4.1-§4.3).
--
-- Everything here is DATA-DRIVEN from mods/ENTITIES/grug_mobs/data/:
--   subtypes.json  sub-type registrations grug_mobs:<role> (frame §4.1)
--   tints.json     tint ids {id, texture} or {id, modifier} (§4.1)
--   items.json     new loot items of kind signature/quest (§4.2)
--   drops.json     family drop tables by level band (§4.3)
-- A missing or empty file means "no data", and with no data the game behaves
-- exactly as before: no registration, every mob its own family, static drops.
--
-- Loaded after every mob file (init.lua): a sub-type copies an already
-- registered base definition.
--

local DATA_DIR = core.get_modpath(core.get_current_modname()) .. "/data"

-- Reads data/<file> as JSON. A missing file is nil ("no data"); a file that
-- does not parse is a load error, never silently empty.
function grug_mobs.read_data_json(file)
	local path = DATA_DIR .. "/" .. file
	local handle = io.open(path, "r")
	if not handle then
		return nil
	end
	local text = handle:read("*a")
	handle:close()
	if not text or text:match("^%s*$") then
		return nil
	end
	local data = core.parse_json(text)
	if data == nil then
		error("[grug_mobs] " .. path .. " is not valid JSON")
	end
	return data
end

-- A catalogue file is a list of records, or an object holding that list under
-- `key` (the design tools accept both, tools/r28_design/r28common.py).
local function records(data, key)
	if type(data) ~= "table" then
		return {}
	end
	if type(data[key]) == "table" then
		return data[key]
	end
	return data
end

local function fail(file, index, msg)
	error(("[grug_mobs] data/%s entry %s: %s"):format(file, tostring(index), msg))
end

local function is_int(v, lo, hi)
	return type(v) == "number" and v == math.floor(v)
		and (lo == nil or v >= lo) and (hi == nil or v <= hi)
end

local function role_of(name)
	return name:match("^grug_mobs:(.+)$") or name
end

--
-- Families
--
-- A sub-type's family is its `family`; an existing mob's family is its own
-- role (entity name without the mod prefix), so a design names an existing
-- mob's role as the family to put sub-types next to it ("boar" joins the
-- Boar, "zombie" the Zombie). With no sub-types every mob is alone in its
-- family, which is exactly today's same-name rule.
--

local SUBTYPES = {} -- role -> parsed sub-type record (see register_subtype)
grug_mobs.subtypes = SUBTYPES
local family_cache = {}

function grug_mobs.family_of(name_or_role)
	local family = family_cache[name_or_role]
	if family then
		return family
	end
	local role = role_of(name_or_role)
	local sub = SUBTYPES[role]
	family = sub and sub.family or role
	family_cache[name_or_role] = family
	return family
end

-- The sub-type record of an entity name or role, or nil for an existing mob.
function grug_mobs.subtype(name_or_role)
	return SUBTYPES[role_of(name_or_role)]
end

-- Do `a` and `b` answer each other's call for help (mobs_redo's group alert,
-- the pack_hunter and camp_swarm verbs)? A neutral mob never does, not even
-- with its own name: a neutral sub-type of a pack or swarm family stays a
-- single pull. Otherwise the same entity name always did and still does;
-- across a family both must take part in group alerts (`group_attack`).
function grug_mobs.alert_kin(a, b)
	if a._grug_disposition == "neutral" or b._grug_disposition == "neutral" then
		return false
	end
	if a.name == b.name then
		return true
	end
	return a.group_attack == true and b.group_attack == true
		and grug_mobs.family_of(a.name) == grug_mobs.family_of(b.name)
end

--
-- Tints (frame §4.1): a baked texture replaces the body texture, a modifier
-- is appended to it. The body is every material slot that carries the
-- mesh's first non-blank texture (boar skin, zombie skin, skeleton bones, an
-- atlas mesh's every slot); blank overlay and held-item slots keep theirs.
--

local TINTS = {}
local BLANK = "grug_mobs_blank.png"

for i, row in ipairs(records(grug_mobs.read_data_json("tints.json"), "tints")) do
	if type(row) ~= "table" or type(row.id) ~= "string" or row.id == "" then
		fail("tints.json", i, "needs a string id")
	end
	if TINTS[row.id] then
		fail("tints.json", row.id, "duplicate tint id")
	end
	local texture = type(row.texture) == "string" and row.texture ~= ""
	local modifier = type(row.modifier) == "string" and row.modifier ~= ""
	if texture == modifier then
		fail("tints.json", row.id, "needs exactly one of texture or modifier")
	end
	TINTS[row.id] = {texture = texture and row.texture or nil,
		modifier = modifier and row.modifier or nil}
end

-- Idempotent: a list that already carries the tint comes back unchanged, so
-- the per-activation re-application never stacks modifiers.
function grug_mobs.tint_textures(textures, tint)
	local body
	for i = 1, #textures do
		if textures[i] ~= BLANK then
			body = textures[i]
			break
		end
	end
	local out = {}
	for i = 1, #textures do
		local slot = textures[i]
		if body and slot == body then
			if tint.texture then
				slot = tint.texture
			elseif slot:sub(-#tint.modifier) ~= tint.modifier then
				slot = slot .. tint.modifier
			end
		end
		out[i] = slot
	end
	return out
end

local function same_list(a, b)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

-- Zone display name and tint (frame §4.1). The zone is the one of the spawn
-- position, read on the first activation and persisted as a plain field;
-- every later activation re-applies the same name and tint (grug_visuals
-- recomposes a humanoid skin on each activation, so the tint goes on top of
-- it each time). Runs after the base's own after_activate. The name is kept
-- in self.temp for the per-step guard below.
local function apply_zone_variant(self, sub)
	local zone = ""
	if next(sub.display_by_zone) or next(sub.tint_by_zone) then
		if self._grug_variant_zone == nil then
			local pos = self.object and self.object:get_pos()
			self._grug_variant_zone = pos and grug_zones.id_at(pos.x, pos.z) or ""
		end
		zone = self._grug_variant_zone
	end
	local display = sub.display_by_zone[zone] or sub.display
	self.temp = self.temp or {}
	self.temp.grug_display = display
	if self.description ~= display then
		self.description = display
	end
	local tint = TINTS[sub.tint_by_zone[zone] or ""]
	local pristine = self._grug_base_texture or self.base_texture
	if tint and type(pristine) == "table" then
		local textures = grug_mobs.tint_textures(pristine, tint)
		if not same_list(textures, pristine) then
			grug_mobs.set_base_texture(self, textures)
		end
	end
end

--
-- Loot items (frame §4.2). Kinds `signature` and `quest` are registered here
-- unless the id already exists (an existing item used as signature loot keeps
-- its registration); `generic` items are existing ones and `reagent` items
-- belong to grug_professions. The inventory image is a tinted placeholder
-- until the C4 art lands; the `icon` text is kept as `_grug_icon_brief`.
-- A new signature item's `tier` (1-6) is its vendor price in copper (the
-- 1-6c mob-material band, economy.md §3) and its ingredient tier, which
-- grug_professions registers with grug_jobs (grug_mobs loads before it). A
-- quest item has neither: traders do not buy quest props.
--

local PLACEHOLDER_IMAGE = {
	signature = "grug_mobs_item_bone.png^[multiply:#d9b26f",
	quest = "grug_mobs_item_stolen_purse.png^[multiply:#9fc2e0",
}
local ITEM_GROUPS = {
	signature = {grug_material = 1},
	quest = {},
}
local new_items = {} -- ids this file registered or expects from their own mod
-- New signature item id -> tier, for the ingredient tiers (grug_professions).
grug_mobs.loot_item_tiers = {}

local ITEM_KINDS = {signature = true, quest = true, generic = true, reagent = true}

for i, row in ipairs(records(grug_mobs.read_data_json("items.json"), "items")) do
	if type(row) ~= "table" or type(row.id) ~= "string"
			or not row.id:match("^[%w_]+:[%w_]+$") then
		fail("items.json", i, "needs an id 'mod:name'")
	end
	if not ITEM_KINDS[row.kind] then
		fail("items.json", row.id, "kind must be signature, generic, reagent or quest")
	end
	if PLACEHOLDER_IMAGE[row.kind] and not core.registered_items[row.id] then
		if row.id:sub(1, 10) ~= "grug_mobs:" then
			-- Another mod's namespace: that mod registers it (checked below).
			new_items[#new_items + 1] = row.id
		else
			if type(row.name) ~= "string" or row.name == "" then
				fail("items.json", row.id, "needs a name")
			end
			if row.kind == "signature" and not is_int(row.tier, 1, 6) then
				fail("items.json", row.id, "needs a tier 1..6")
			end
			local description = row.name
			if type(row.description) == "string" and row.description ~= "" then
				description = description .. "\n" ..
					core.colorize("#a0a0a0", row.description)
			end
			core.register_craftitem(row.id, {
				description = description,
				short_description = row.name,
				inventory_image = PLACEHOLDER_IMAGE[row.kind],
				groups = table.copy(ITEM_GROUPS[row.kind]),
				_grug_icon_brief = row.icon,
				_grug_sell_price = row.kind == "signature" and row.tier or nil,
			})
			if row.kind == "signature" then
				grug_mobs.loot_item_tiers[row.id] = row.tier
			end
		end
	end
end

--
-- Drop tables by level band (ruling 36, frame §4.3)
--

local DROPS = {} -- drop family -> {bands = {[1..6] = rows}, leader_bonus = rows}
local drop_items = {} -- every item a drop row names, checked once mods are loaded

local function drop_rows(list, where)
	if type(list) ~= "table" then
		fail("drops.json", where, "rows must be a list")
	end
	local rows = {}
	for j, row in ipairs(list) do
		local at = where .. "[" .. j .. "]"
		if type(row) ~= "table" or type(row.item) ~= "string" then
			fail("drops.json", at, "row needs an item")
		end
		local lo, hi = row.min or 1, row.max or 1
		if not is_int(row.chance, 1) or not is_int(lo, 1) or not is_int(hi, lo) then
			fail("drops.json", at, "chance >= 1 and 1 <= min <= max (integers)")
		end
		rows[j] = {name = row.item, chance = row.chance, min = lo, max = hi}
		drop_items[row.item] = at
	end
	return rows
end

for i, row in ipairs(records(grug_mobs.read_data_json("drops.json"), "drops")) do
	if type(row) ~= "table" or type(row.family) ~= "string" or row.family == "" then
		fail("drops.json", i, "needs a family")
	end
	if DROPS[row.family] then
		fail("drops.json", row.family, "duplicate family")
	end
	local entry = {bands = {}}
	if type(row.bands) ~= "table" then
		fail("drops.json", row.family, "needs bands")
	end
	for band, list in pairs(row.bands) do
		local n = tonumber(band)
		if not is_int(n, 1, 6) then
			fail("drops.json", row.family, "band key " .. tostring(band) .. " is not 1..6")
		end
		entry.bands[n] = drop_rows(list, row.family .. ".bands." .. band)
	end
	if row.leader_bonus ~= nil then
		entry.leader_bonus = drop_rows(row.leader_bonus, row.family .. ".leader_bonus")
	end
	DROPS[row.family] = entry
end

-- Level band: 1-10 -> 1, 11-20 -> 2, ... 51-60 -> 6 (higher levels stay 6).
function grug_mobs.level_band(level)
	local band = math.floor(((level or 1) - 1) / 10) + 1
	return math.max(1, math.min(6, band))
end

-- The drop rows of this mob from its family table, or nil when the family
-- has no table or the table has no (or an empty) row list for the mob's band: the caller then
-- keeps the definition's static drops (aggro.lua _item_drop_filter). A leader
-- (sub-type `leader`, or `_grug_leader` on a placed leader) adds the
-- family's leader_bonus. The rows are fresh tables every call.
function grug_mobs.band_drop_rows(self)
	local role = role_of(self.name or "")
	local sub = SUBTYPES[role]
	local entry = DROPS[sub and sub.drops or role]
	local rows = entry and entry.bands[grug_mobs.level_band(self._grug_level)]
	if not rows or #rows == 0 then
		return nil
	end
	local out = {}
	for i = 1, #rows do
		out[i] = table.copy(rows[i])
	end
	if entry.leader_bonus and (self._grug_leader or (sub and sub.leader)) then
		for i = 1, #entry.leader_bonus do
			out[#out + 1] = table.copy(entry.leader_bonus[i])
		end
	end
	return out
end

-- Every item the band tables and leader bonuses name -> set of the drop
-- families naming it (the trader audit, grug_traders/init.lua).
function grug_mobs.band_drop_items()
	local out = {}
	for family, entry in pairs(DROPS) do
		local lists = {entry.leader_bonus or {}}
		for _, rows in pairs(entry.bands) do
			lists[#lists + 1] = rows
		end
		for _, rows in ipairs(lists) do
			for _, row in ipairs(rows) do
				out[row.name] = out[row.name] or {}
				out[row.name][family] = true
			end
		end
	end
	return out
end

--
-- Sub-type registrations (ruling 35, frame §4.1)
--

local DISPOSITIONS = {neutral = true, aggressive = true, critter = true}

local function scale_box(box, s)
	local out = {}
	for k, v in pairs(box) do
		out[k] = type(k) == "number" and v * s or v -- keeps `rotate`
	end
	return out
end

local function string_map(value, file, role, key)
	if value == nil then
		return {}
	end
	if type(value) ~= "table" then
		fail(file, role, key .. " must be an object")
	end
	for zone, text in pairs(value) do
		if type(zone) ~= "string" or type(text) ~= "string" or text == "" then
			fail(file, role, key .. " maps zone ids to strings")
		end
	end
	return value
end

local function register_subtype(i, row)
	local file = "subtypes.json"
	if type(row) ~= "table" or type(row.role) ~= "string"
			or not row.role:match("^[a-z][a-z0-9_]*$") then
		fail(file, i, "needs a snake_case role")
	end
	local role = row.role
	local name = "grug_mobs:" .. role
	if SUBTYPES[role] then
		fail(file, role, "duplicate role")
	end
	if core.registered_entities[name] then
		fail(file, role, "collides with the existing entity " .. name)
	end
	local base = row.base
	local def = type(base) == "string" and grug_mobs.copy_base_def(base)
	if not def or SUBTYPES[role_of(base)] then
		fail(file, role, "base " .. tostring(base) ..
			" is not an existing grug_mobs registration")
	end
	if def._grug_fixed_level or not grug_mobs.disposition(base) then
		fail(file, role, "base " .. base ..
			" is an encounter actor or guard, not an ambient mob")
	end
	if type(row.family) ~= "string" or row.family == "" then
		fail(file, role, "needs a family")
	end
	if type(row.display) ~= "string" or row.display == "" then
		fail(file, role, "needs a display name")
	end
	local size = row.size
	if type(size) ~= "number" or size <= 0 then
		fail(file, role, "size must be a positive number")
	end
	if not DISPOSITIONS[row.disposition] then
		fail(file, role, "disposition must be neutral, aggressive or critter")
	end
	-- An aggressive mob acquires players on sight; without an attack type it
	-- would chase them and never strike.
	if row.disposition == "aggressive" and not def.attack_type then
		fail(file, role, "aggressive, but base " .. base .. " has no attack_type")
	end
	local tier = row.tier or "normal"
	if tier ~= "normal" and tier ~= "elite" then
		fail(file, role, "tier must be normal or elite")
	end
	local levels = row.levels
	if type(levels) ~= "table" or not is_int(levels[1], 1, 60)
			or not is_int(levels[2], levels[1], 60) then
		fail(file, role, "levels must be [lo, hi] within 1..60")
	end
	if row.leader ~= nil and type(row.leader) ~= "boolean" then
		fail(file, role, "leader must be true or false")
	end
	local sub = {
		role = role,
		name = name,
		base = base,
		family = row.family,
		drops = type(row.drops) == "string" and row.drops ~= ""
			and row.drops or row.family,
		display = row.display,
		display_by_zone = string_map(row.display_by_zone, file, role, "display_by_zone"),
		tint_by_zone = string_map(row.tint_by_zone, file, role, "tint_by_zone"),
		size = size,
		disposition = row.disposition,
		tier = tier,
		leader = row.leader == true,
		levels = {levels[1], levels[2]},
	}
	for zone, tint in pairs(sub.tint_by_zone) do
		if not TINTS[tint] then
			fail(file, role, "tint " .. tint .. " (zone " .. zone ..
				") is not in tints.json")
		end
	end

	-- The base's model, animations, verbs and static drops, resized.
	def.description = sub.display
	local vs = def.visual_size or {x = 1, y = 1}
	def.visual_size = {x = vs.x * size, y = vs.y * size, z = vs.z and vs.z * size}
	def.collisionbox = scale_box(def.collisionbox
		or {-0.25, -0.25, -0.25, 0.25, 0.25, 0.25}, size)
	if def.selectionbox then
		def.selectionbox = scale_box(def.selectionbox, size)
	end
	-- A critter disposition needs the critter tier (disposition.lua).
	def._grug_tier = sub.disposition == "critter" and "critter" or tier
	-- The authored tier, name and leader flag win over anything the base
	-- family rolls at spawn (the Elder Bear and Silverback rolls rename and
	-- promote through on_spawn): set_tier leaves an authored tier alone
	-- (levels.lua), and the name is put back on the next step.
	def._grug_authored_tier = true
	def._grug_min_level = sub.levels[1]
	def._grug_max_level = sub.levels[2]
	local base_after_activate = def.after_activate
	def.after_activate = function(self, staticdata, mob_def, dtime)
		if base_after_activate then
			base_after_activate(self, staticdata, mob_def, dtime)
		end
		apply_zone_variant(self, sub)
	end
	local base_do_custom = def.do_custom
	def.do_custom = function(self, dtime, moveresult)
		local display = self.temp and self.temp.grug_display
		if display and self.description ~= display then
			self.description = display
			if self.update_tag then
				self:update_tag()
			end
		end
		if base_do_custom then
			return base_do_custom(self, dtime, moveresult)
		end
	end
	SUBTYPES[role] = sub
	family_cache = {}
	grug_mobs.register_disposition(name, sub.disposition)
	grug_mobs.register_mob(name, def)
end

for i, row in ipairs(records(grug_mobs.read_data_json("subtypes.json"), "subtypes")) do
	register_subtype(i, row)
end

-- Every item a drop row names, and every new item another mod owns, must
-- exist once all mods are loaded: a typo would otherwise drop unknown items.
core.register_on_mods_loaded(function()
	for item, where in pairs(drop_items) do
		if not core.registered_items[item] then
			error("[grug_mobs] data/drops.json " .. where .. ": unknown item " .. item)
		end
	end
	for _, item in ipairs(new_items) do
		if not core.registered_items[item] then
			error("[grug_mobs] data/items.json: " .. item ..
				" is in another mod's namespace and no mod registered it")
		end
	end
end)
