-- R7's single stable world-authority installation seam. grug_mapgen calls
-- install_zone_authority exactly once after it has authenticated the R4
-- session and the private consumer payload. No fallback geometry exists.

local PUBLIC_METHODS = {
	"get",
	"at",
	"neighbors",
	"anchor",
	"id_at",
	"biome_at",
	"race_region_at",
	"faction_at",
	"territory_rule_at",
	"hard_protection_kind_at",
	"pvp_rule_at",
	"surface_mob_level_at",
	"mob_level_at",
	"guard_level_at",
	"terrain_height_at",
	"water_class_at",
	"hard_footprint_in",
}

local EXPECTED_RACES = {
	dwarf = {faction_id = "accord", start_id = 1, capital_id = 7},
	human = {faction_id = "accord", start_id = 2, capital_id = 8},
	elf = {faction_id = "accord", start_id = 3, capital_id = 9},
	undead = {faction_id = "throng", start_id = 4, capital_id = 10},
	orc = {faction_id = "throng", start_id = 5, capital_id = 11},
	troll = {faction_id = "throng", start_id = 6, capital_id = 12},
}

-- EXPECTED_RACES ordered by start_id. A map has no order, and both the
-- startup start-area preload and the mob start-footprint gate need the six
-- start identities in one stable order.
local START_ORDER = {"dwarf", "human", "elf", "undead", "orc", "troll"}

local EXPECTED_OUTPOST_RACES = {
	"dwarf", "dwarf", "dwarf", "dwarf",
	"human", "human", "human", "human",
	"elf", "elf", "elf", "elf",
	"undead", "undead", "undead", "undead",
	"orc", "orc", "orc", "orc",
	"troll", "troll", "troll", "troll",
}

-- Each authenticated four-row race roster is ordered from its home end to
-- its terminal frontier end. Preserve WP6's three-leg chain in that order:
-- the first three posts walk forward, while the terminal post walks back.
local OUTPOST_PATROL_TARGET_SLOT = {2, 3, 4, 3}

local EXPECTED_RARE_IDS = {
	"grimtusk",
	"old_whitefang",
	"korgans_bane",
	"silkfang",
	"marrowclaw",
	"dustwing",
	"emerald_coil",
	"ashmaw",
	"bonerattle_north",
	"bonerattle_south",
}

local authority
local world_feature_kind_at
local world_feature_boxes_in
local race_anchors
local outposts
local rare_routes

local function fail(message)
	error("[grug_core] R7 zone authority: " .. message, 2)
end

local function dense_array(value, expected, label)
	if type(value) ~= "table" or #value ~= expected then
		fail(label .. " must contain exactly " .. expected .. " rows")
	end
	for i = 1, expected do
		if value[i] == nil then
			fail(label .. " must be a dense array")
		end
	end
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key > expected or
				key % 1 ~= 0 then
			fail(label .. " must be a dense array")
		end
	end
end

local function exact_fields(value, allowed, label)
	if type(value) ~= "table" then
		fail(label .. " must be a table")
	end
	for key in pairs(value) do
		if not allowed[key] then
			fail(label .. " contains unexpected field " .. tostring(key))
		end
	end
end

local function integer(value, label)
	if type(value) ~= "number" or value % 1 ~= 0 or
			value < -9007199254740991 or value > 9007199254740991 then
		fail(label .. " must be a safe integer")
	end
	return value
end

local function copy_position(value)
	return {x = value.x, y = value.y, z = value.z}
end

local function copy_route(value)
	local result = {}
	for i = 1, #value do
		result[i] = copy_position(value[i])
	end
	return result
end

local function copy_outpost(value)
	return {
		id = value.id,
		faction = value.faction,
		race = value.race,
		anchor = copy_position(value.anchor),
	}
end

local function require_anchor(session, ref, expected_slot, expected_numeric_id,
		label)
	exact_fields(ref, {zone_id = true, slot_id = true}, label .. " reference")
	if type(ref) ~= "table" or type(ref.zone_id) ~= "string" or
			type(ref.slot_id) ~= "string" or ref.slot_id ~= expected_slot then
		fail(label .. " reference differs")
	end
	local anchor = session.anchor(ref.zone_id, ref.slot_id)
	if type(anchor) ~= "table" or type(anchor.id) ~= "string" or
			anchor.id ~= ("anchor_%03d"):format(expected_numeric_id) or
			anchor.numeric_id ~= expected_numeric_id or
			anchor.slot_id ~= ref.slot_id or
			integer(anchor.x, label .. " x") ~= anchor.x or
			integer(anchor.y, label .. " y") ~= anchor.y or
			integer(anchor.z, label .. " z") ~= anchor.z or
			session.id_at(anchor.x, anchor.z) ~= ref.zone_id then
		fail(label .. " does not resolve to its stable R4 anchor")
	end
	return anchor
end

local function validate_session(session)
	if type(session) ~= "table" then
		fail("session must be a table")
	end
	for i = 1, #PUBLIC_METHODS do
		local name = PUBLIC_METHODS[i]
		if type(session[name]) ~= "function" then
			fail("session is missing public method " .. name)
		end
	end
	if type(session.compatibility) ~= "table" or
			type(session.compatibility.surface_level_at) ~= "function" or
			type(session.compatibility.mob_level_at) ~= "function" or
			type(session.compatibility.guard_level_at) ~= "function" or
			type(session.compatibility.open_sea_at) ~= "function" or
			type(session.compatibility.territory_at) ~= "function" or
			type(session.compatibility.zone_at) ~= "function" or
			type(session.compatibility.world_protected_for_faction) ~= "function" then
		fail("session compatibility payload differs")
	end
end

local function validate_races(session, rows)
	dense_array(rows, 6, "race anchors")
	local result = {}
	for i = 1, #rows do
		local row = rows[i]
		exact_fields(row, {race_id = true, faction_id = true, start = true,
			capital = true}, "race anchor row " .. i)
		local expected = type(row) == "table" and
			EXPECTED_RACES[row.race_id] or nil
		if not expected or row.faction_id ~= expected.faction_id or
				result[row.race_id] then
			fail("race anchor identity differs at row " .. i)
		end
		local start = require_anchor(session, row.start, "start",
			expected.start_id,
			"race " .. row.race_id .. " start")
		local capital = require_anchor(session, row.capital, "capital",
			expected.capital_id,
			"race " .. row.race_id .. " capital")
		if session.faction_at(start) ~= row.faction_id or
				session.faction_at(capital) ~= row.faction_id then
			fail("race anchor faction differs for " .. row.race_id)
		end
		result[row.race_id] = {
			faction_id = row.faction_id,
			start = start,
			capital = capital,
		}
	end
	for race_id in pairs(EXPECTED_RACES) do
		if not result[race_id] then
			fail("race anchor is missing for " .. race_id)
		end
	end
	return result
end

local function validate_outposts(session, rows)
	dense_array(rows, 24, "outpost anchors")
	local result, by_id = {}, {}
	for i = 1, #rows do
		local row = rows[i]
		exact_fields(row, {race_id = true, faction_id = true, anchor = true},
			"outpost row " .. i)
		local expected_race = EXPECTED_OUTPOST_RACES[i]
		local expected = type(row) == "table" and
			EXPECTED_RACES[row.race_id] or nil
		if not expected or row.race_id ~= expected_race or
				row.faction_id ~= expected.faction_id or
				type(row.anchor) ~= "table" then
			fail("outpost identity differs at row " .. i)
		end
		local anchor = require_anchor(session, row.anchor,
			row.anchor.slot_id, i + 24, "outpost row " .. i)
		if not row.anchor.slot_id:match("^outpost_%d+$") or
				session.race_region_at(anchor.x, anchor.z) ~= row.race_id or
				by_id[anchor.id] then
			fail("outpost anchor differs at row " .. i)
		end
		local record = {
			id = anchor.id,
			faction = row.faction_id,
			race = row.race_id,
			anchor = anchor,
		}
		result[i] = record
		by_id[anchor.id] = record
	end
	return result
end

local function validate_rare_routes(session, rows)
	dense_array(rows, 10, "rare routes")
	local result = {}
	for i = 1, #rows do
		local row = rows[i]
		exact_fields(row, {id = true, anchor = true, patrol_offsets = true},
			"rare route row " .. i)
		local expected_id = EXPECTED_RARE_IDS[i]
		if type(row) ~= "table" or row.id ~= expected_id or
				result[row.id] or type(row.anchor) ~= "table" or
				type(row.anchor.slot_id) ~= "string" or
				not row.anchor.slot_id:match("^rare_[a-z0-9_]+$") then
			fail("rare route identity differs at row " .. i)
		end
		local anchor = require_anchor(session, row.anchor,
			row.anchor.slot_id, i + 90, "rare route " .. row.id)
		local water_class = session.water_class_at(anchor.x, anchor.z)
		if water_class == "deep_ocean" or
				water_class == "immutable_dragon_channel" then
			fail("rare route anchor is not ordinary land for " .. row.id)
		end
		dense_array(row.patrol_offsets, 3,
			"rare route offsets for " .. row.id)
		local route = {}
		for n = 1, #row.patrol_offsets do
			local offset = row.patrol_offsets[n]
			exact_fields(offset, {x = true, z = true},
				"rare route offset " .. row.id .. ":" .. n)
			if type(offset) ~= "table" then
				fail("rare route offset differs for " .. row.id)
			end
			local x = anchor.x + integer(offset.x,
				"rare route offset x for " .. row.id)
			local z = anchor.z + integer(offset.z,
				"rare route offset z for " .. row.id)
			if math.abs(offset.x) > 80 or math.abs(offset.z) > 80 or
					(offset.x == 0 and offset.z == 0) then
				fail("rare route offset bound differs for " .. row.id)
			end
			for previous = 1, n - 1 do
				if route[previous].x == x and route[previous].z == z then
					fail("rare route contains a duplicate point for " .. row.id)
				end
			end
			local y = session.terrain_height_at(x, z)
			integer(y, "rare route height for " .. row.id)
			route[n] = {x = x, y = y + 1, z = z}
		end
		result[row.id] = route
	end
	for i = 1, #EXPECTED_RARE_IDS do
		local id = EXPECTED_RARE_IDS[i]
		if not result[id] then
			fail("rare route is missing for " .. id)
		end
	end
	return result
end

local function consumer_payload_bytes(payload)
	local bytes = {"schema\tgrug_wp40_r7_consumer_payload_v1\n"}
	for index = 1, #payload.races do
		local row = payload.races[index]
		bytes[#bytes + 1] = table.concat({"race", row.race_id,
			row.faction_id, row.start.zone_id, row.start.slot_id,
			row.capital.zone_id, row.capital.slot_id}, "\t") .. "\n"
	end
	for index = 1, #payload.outposts do
		local row = payload.outposts[index]
		bytes[#bytes + 1] = table.concat({"outpost", row.race_id,
			row.faction_id, row.anchor.zone_id, row.anchor.slot_id}, "\t") .. "\n"
	end
	for index = 1, #payload.rare_routes do
		local row = payload.rare_routes[index]
		local fields = {"rare", row.id, row.anchor.zone_id, row.anchor.slot_id}
		for offset = 1, #row.patrol_offsets do
			fields[#fields + 1] = tostring(row.patrol_offsets[offset].x)
			fields[#fields + 1] = tostring(row.patrol_offsets[offset].z)
		end
		bytes[#bytes + 1] = table.concat(fields, "\t") .. "\n"
	end
	return table.concat(bytes)
end

local function public_registry(session)
	local methods = {}
	for i = 1, #PUBLIC_METHODS do
		local name = PUBLIC_METHODS[i]
		methods[name] = function(...)
			return session[name](...)
		end
	end
	return setmetatable({}, {
		__index = methods,
		__newindex = function()
			fail("published authority is immutable")
		end,
		__metatable = false,
	})
end

function grug_core.prepare_zone_authority(session, payload, world_protection)
	if authority then
		fail("authority may be installed only once")
	end
	-- Round 25 rulings 15-17: the road corridors and settlement cores
	-- (`grug_mapgen/wp40/world_protection.lua`).
	if type(world_protection) ~= "table" or
			world_protection.schema ~= "grug_wp40_world_protection_v1" or
			type(world_protection.kind_at) ~= "function" or
			type(world_protection.boxes_in) ~= "function" then
		fail("world protection differs")
	end
	if rawget(_G, "grug_zones") ~= nil then
		fail("grug_zones is already published by another owner")
	end
	validate_session(session)
	if type(payload) ~= "table" or
			payload.schema ~= "grug_wp40_r7_consumer_payload_v1" then
		fail("consumer payload schema differs")
	end
	exact_fields(payload, {schema = true, sha256 = true, races = true,
		outposts = true, rare_routes = true}, "consumer payload")

	-- Build every private consumer table before publishing any authority.
	local next_races = validate_races(session, payload.races)
	local next_outposts = validate_outposts(session, payload.outposts)
	local next_rare_routes = validate_rare_routes(session, payload.rare_routes)
	if type(core.sha256) ~= "function" or type(payload.sha256) ~= "string" or
			#payload.sha256 ~= 64 or
			core.sha256(consumer_payload_bytes(payload)) ~= payload.sha256 then
		fail("consumer payload digest differs")
	end
	local next_public = public_registry(session)
	return function()
		-- This closure contains assignments only. Every query, anchor, payload and
		-- policy check completed before the production writer was registered.
		race_anchors = next_races
		outposts = next_outposts
		rare_routes = next_rare_routes
		world_feature_kind_at = world_protection.kind_at
		world_feature_boxes_in = world_protection.boxes_in
		authority = session
		rawset(_G, "grug_zones", next_public)
		return true
	end
end

function grug_core.install_zone_authority(session, payload, world_protection)
	return grug_core.prepare_zone_authority(session, payload, world_protection)()
end

function grug_core.zone_authority_installed()
	return authority ~= nil
end

local function installed()
	if not authority then
		fail("authority is not installed")
	end
	return authority
end

-- Explicit compatibility adapters. They delegate to the accepted R4
-- compatibility payload and contain no independent geometry.
function grug_core.surface_level_at(x, z)
	return installed().compatibility.surface_level_at(x, z)
end

function grug_core.mob_level_at(pos)
	return installed().compatibility.mob_level_at(pos)
end

function grug_core.guard_level_at(pos)
	return installed().compatibility.guard_level_at(pos)
end

function grug_core.open_sea_at(pos)
	return installed().compatibility.open_sea_at(pos)
end

function grug_core.territory_at(pos)
	return installed().compatibility.territory_at(pos)
end

function grug_core.zone_at(pos)
	return installed().compatibility.zone_at(pos)
end

-- A node coordinate as the zone session rounds it (half away from zero).
local function node_coordinate(value)
	if value >= 0 then
		local base = math.floor(value)
		return value - base >= 0.5 and base + 1 or base
	end
	local base = math.ceil(value)
	return base - value >= 0.5 and base - 1 or base
end

-- What protects a position for every player whatever the faction (Round 25
-- rulings 15-17): "road", "bridge" (a road corridor, the road's half width
-- plus 3 nodes beside it and +-5 around its surface), "village", "camp" or
-- "poi" (a settlement's building core, 10 below its placement height to 10
-- above its highest node); nil elsewhere and before installation.
function grug_core.world_feature_at(pos)
	if not world_feature_kind_at or type(pos) ~= "table" or
			type(pos.x) ~= "number" or type(pos.y) ~= "number" or
			type(pos.z) ~= "number" then
		return nil
	end
	return world_feature_kind_at(node_coordinate(pos.x), node_coordinate(pos.y),
		node_coordinate(pos.z))
end

-- Claim placement (Round 25 ruling 27): true, the kind and the settlement key
-- of the first POI, village or camp core whose x/z rectangle, widened by
-- `margin` nodes, meets the inclusive x/z rectangle; false when none does.
-- x/z only (the cores' y extent does not matter to a claim), one scan of the
-- 88 cores. Fails closed (true) before installation. Towns, capitals and
-- landmarks are not in it: they are the zone session's hard footprints
-- (grug_zones.hard_protection_kind_at / territory_rule_at "hard_protected").
function grug_core.world_feature_boxes_in(min_x, min_z, max_x, max_z, margin)
	if not world_feature_boxes_in then return true end
	local kind, id = world_feature_boxes_in(min_x, min_z, max_x, max_z, margin or 0)
	if kind then return true, kind, id end
	return false
end

-- Exactly R4's pure faction policy (zone and territory rule, hard
-- protection), without the road and POI layer; fail closed before
-- installation. For system effects the road and POI rulings do not cover
-- (grug_core.ground_effect_protected).
function grug_core.zone_protected_for_faction(pos, faction_id)
	if not authority then
		return true
	end
	return authority.compatibility.world_protected_for_faction(pos, faction_id)
end

-- Fail closed before installation; afterwards R4's pure faction policy, and
-- the road and POI protection above for everyone where that policy allows.
-- Protection bypass and prior-handler delegation live in the single engine
-- wrapper in protection.lua.
function grug_core.world_protected_for_faction(pos, faction_id)
	if not authority then
		return true
	end
	if authority.compatibility.world_protected_for_faction(pos, faction_id) then
		return true
	end
	return grug_core.world_feature_at(pos) ~= nil
end

local function race_record(faction_id, race_id)
	if not authority then
		return nil
	end
	local row = race_anchors[race_id]
	if not row or row.faction_id ~= faction_id then
		return nil
	end
	return row
end

function grug_core.start_anchor(faction_id, race_id)
	local row = race_record(faction_id, race_id)
	return row and copy_position(row.start) or nil
end

-- The six start identities in START_ORDER, each with its own anchor copy.
-- Empty before the authority is installed. Consumers that need every start
-- (startup preload, start-footprint spawn gate) read exactly this list
-- instead of restating the race roster.
function grug_core.start_identities()
	local result = {}
	if not authority then
		return result
	end
	for i = 1, #START_ORDER do
		local race_id = START_ORDER[i]
		local row = race_anchors[race_id]
		if row then
			result[#result + 1] = {
				race_id = race_id,
				faction_id = row.faction_id,
				anchor = copy_position(row.start),
			}
		end
	end
	return result
end

function grug_core.capital_anchor(faction_id, race_id)
	local row = race_record(faction_id, race_id)
	return row and copy_position(row.capital) or nil
end

function grug_core.start_position(faction_id, race_id)
	local anchor = grug_core.start_anchor(faction_id, race_id)
	if not anchor then
		return nil
	end
	anchor.y = anchor.y + 1
	return anchor
end

function grug_core.outpost_at(pos)
	if not authority or type(pos) ~= "table" then
		return nil
	end
	for i = 1, #outposts do
		local row = outposts[i]
		if math.abs(pos.x - row.anchor.x) <= 4 and
				math.abs(pos.z - row.anchor.z) <= 4 then
			return copy_outpost(row)
		end
	end
	return nil
end

function grug_core.outpost_patrol_target(anchor)
	if not authority or type(anchor) ~= "table" or
			type(anchor.anchor) ~= "table" then
		return nil
	end
	for i = 1, #outposts do
		local row = outposts[i]
		if anchor.id == row.id then
			if anchor.faction ~= row.faction or anchor.race ~= row.race or
					anchor.anchor.x ~= row.anchor.x or
					anchor.anchor.y ~= row.anchor.y or
					anchor.anchor.z ~= row.anchor.z then
				return nil
			end
			local slot = (i - 1) % 4 + 1
			local target_index = i - slot +
				OUTPOST_PATROL_TARGET_SLOT[slot]
			local target = outposts[target_index]
			if not target or target.race ~= row.race or
					target.faction ~= row.faction then
				return nil
			end
			return copy_outpost(target)
		end
	end
	return nil
end

function grug_core.outpost_position(anchor)
	if not anchor or not anchor.anchor then
		return nil
	end
	return anchor.anchor.x, anchor.anchor.z
end

function grug_core.rare_route(id)
	local route = rare_routes and rare_routes[id] or nil
	return route and copy_route(route) or nil
end
