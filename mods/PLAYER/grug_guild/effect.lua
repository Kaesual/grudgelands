-- The mining effect (spec §7, §10.5): Ore Sense and Treasure Hunt. One
-- status id, grug_guild.catalog.STATUS.id ("mining_sense"), with a variant
-- per kind ("ore_sense", "treasure_hunt"), so one of the two runs at a
-- time; not the elixir's id. It starts only in its tier's depth
-- (grug_materials.tier_at(y) == tier); its time then runs everywhere, but it
-- marks and places nothing while its user is outside that band.
--
--   grug_guild.active_effect(player) -> {kind, tier, remaining} | nil
--   grug_guild.start_effect(player, kind, tier) -> true | false, err
--       err "unknown", "level" (below the item's use level), "active" (an
--       effect runs: never replaced), "depth" (outside its tier's band)
--   grug_guild.stop_effect(player) -> bool   (admin and tests)
--
-- Persistence. Statuses are runtime-only: grug_core clears them in its own
-- leave and death callbacks, which run before these (grug_core loads
-- first). So the effect keeps its own end time per player, and the status
-- is only its picture: re-applied from that end time at join and after
-- death. Saved state, one key, no position (nothing map-bound):
--   player meta grug_guild:effect   core.serialize({kind, tier, remaining})
--       remaining in whole seconds; written every SAVE_SECONDS while the
--       effect runs (a crash skips on_leaveplayer: the player then loses at
--       most that much) and at leave; read at join; cleared when it ends.
--
-- The markers are per-player HUD image waypoints (player:hud_add): sent to
-- the user only, and drawn over the world, so a deposit or a Remains inside
-- the rock shows where it is. Particles and entities are depth-tested and
-- the rock in front would hide them (luanti src/client/particles.cpp
-- getMaterialForParticle: the Z test stays on; only Z writes go off).
--
-- Ore Sense: every interval_min..interval_max seconds (uniform), while the
-- user is in the band, ONE core.find_nodes_in_area over the `range` box
-- (clipped to the band) for every target node at once; the mark goes to the
-- nearest deposit of the first target (catalogue order) that has one, for
-- marker_seconds.
--
-- Treasure Hunt: one Miner's Remains at a time (items.lua registers the
-- nodes), placed place_min..place_max nodes from the user in the tier's own
-- rock with all 26 neighbours solid, never where core.is_protected (for the
-- user) or the hard protection (grug_zones.hard_protection_kind_at) says
-- so. Every check_seconds the effect marks it while the user is within
-- marker_range and forgets it (the rock comes back) beyond remove_distance;
-- the next one respawn_seconds after the last was dug or removed. The block
-- itself holds its owner and a placement token in node meta, and its own
-- node timer (check_seconds) turns it back into rock when its owner is
-- offline or beyond remove_distance, or when the token is no longer the
-- owner's current one: a Remains in a block that was unloaded while its
-- owner walked away catches up when the block loads, even if a newer one
-- exists by then. Its position is runtime-only, never in player meta.

local catalog = grug_guild.catalog
local STATUS_ID = catalog.STATUS.id

grug_guild.EFFECT_KEY = "grug_guild:effect"
local EFFECT_KEY = grug_guild.EFFECT_KEY

-- Technical, not tuning: how often a running effect writes its remaining
-- time (the crash case), how many spots one Treasure Hunt check tries, and
-- the markers' on-screen size (16 px tiles, doubled).
local SAVE_SECONDS = 30
local PLACE_TRIES = 16
local MARKER_SCALE = {x = 2, y = 2}

local effects = {} -- player name -> the running effect (runtime only)
local token_sequence = 0

local function player_name(player)
	if not player or not player.is_player or not player:is_player() then return nil end
	return player:get_player_name()
end

local function now_us()
	return core.get_us_time()
end

local function remaining_seconds(effect)
	return math.max(0, (effect.ends_us - now_us()) / 1e6)
end

local function tier_row(tier)
	return grug_materials.TIERS[tier]
end

-- The band in words, for refusals, descriptions and the Effects tab.
function grug_guild.band_text(tier)
	local row = tier_row(tier)
	if tier == 1 then return "at y " .. row.y_min .. " and above" end
	if tier == #grug_materials.TIERS then return "at y " .. row.y_max .. " and below" end
	return "between y " .. row.y_max .. " and " .. row.y_min
end

local function in_band(tier, y)
	return grug_materials.tier_at(math.floor(y + 0.5)) == tier
end

local function rounded(pos)
	return {x = math.floor(pos.x + 0.5), y = math.floor(pos.y + 0.5), z = math.floor(pos.z + 0.5)}
end

local function distance(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function detail(row)
	if row.kind == "ore_sense" then
		return "Marks nearby ore " .. grug_guild.band_text(row.tier)
	end
	return "Hides Miner's Remains nearby " .. grug_guild.band_text(row.tier)
end

local function apply_status(player, effect)
	grug_core.set_status(player, STATUS_ID, {
		label = effect.row.name, detail = detail(effect.row),
		variant = effect.row.variant, expiry_us = effect.ends_us,
	})
end

local function save(player, effect)
	player:get_meta():set_string(EFFECT_KEY, core.serialize({kind = effect.row.kind,
		tier = effect.row.tier, remaining = math.ceil(remaining_seconds(effect))}))
end

-- A marker shown to one player at a world position.
local function add_marker(player, pos, texture)
	return player:hud_add({
		type = "image_waypoint", world_pos = pos, text = texture,
		scale = MARKER_SCALE, alignment = {x = 0, y = 0}, offset = {x = 0, y = 0},
		z_index = 0,
	})
end

local function remove_marker(effect, key)
	local id = effect[key]
	effect[key] = nil
	local player = id and core.get_player_by_name(effect.name)
	if player then player:hud_remove(id) end
end

-- Calls fn after `seconds` while this effect is still the player's.
local function later(effect, seconds, fn)
	core.after(seconds, function()
		if effects[effect.name] == effect then fn() end
	end)
end

------------------------------------------------------------------------------
-- Treasure Hunt: the Remains.
------------------------------------------------------------------------------

local solid_cache = {} -- content id -> bool
local function solid(cid)
	local known = solid_cache[cid]
	if known == nil then
		local name = core.get_name_from_content_id(cid)
		local def = core.registered_nodes[name]
		known = def ~= nil and name ~= "air" and name ~= "ignore" and def.walkable ~= false and
			(def.liquidtype or "none") == "none" and not def.buildable_to
		solid_cache[cid] = known
	end
	return known
end

-- True when `name` may not have a Remains at pos: the user's protection or
-- the hard protection (towns, landmarks, the guild rooms, ...).
local function protected(pos, name)
	if core.is_protected(pos, name) then return true end
	if grug_core.zone_authority_installed and grug_core.zone_authority_installed() and
			grug_zones.hard_protection_kind_at(pos) ~= nil then
		return true
	end
	return false
end

-- A spot for the tier's Remains: the tier rock itself, all 26 neighbours
-- loaded and solid, in the band, not protected.
function grug_guild.remains_spot_ok(pos, tier, name)
	if not in_band(tier, pos.y) then return false end
	local host = core.get_content_id(catalog.remains(tier).host)
	local cid, _, _, loaded = core.get_node_raw(pos.x, pos.y, pos.z)
	if not loaded or cid ~= host then return false end
	for dx = -1, 1 do
		for dy = -1, 1 do
			for dz = -1, 1 do
				if dx ~= 0 or dy ~= 0 or dz ~= 0 then
					local other, _, _, ok = core.get_node_raw(pos.x + dx, pos.y + dy, pos.z + dz)
					if not ok or not solid(other) then return false end
				end
			end
		end
	end
	return not protected(pos, name)
end

local function random_spot(center, row, owner)
	local reach = row.place_max
	for _ = 1, PLACE_TRIES do
		local offset = {x = math.random(-reach, reach), y = math.random(-reach, reach),
			z = math.random(-reach, reach)}
		local length = math.sqrt(offset.x * offset.x + offset.y * offset.y + offset.z * offset.z)
		if length >= row.place_min and length <= row.place_max then
			local pos = {x = center.x + offset.x, y = center.y + offset.y, z = center.z + offset.z}
			if grug_guild.remains_spot_ok(pos, row.tier, owner) then return pos end
		end
	end
	return nil
end

-- The effect forgets its Remains (dug, removed or gone) and waits for the
-- next one.
local function forget_remains(effect)
	effect.remains = nil
	effect.next_place_us = now_us() + effect.row.respawn_seconds * 1e6
	remove_marker(effect, "remains_marker")
end

-- The Remains at pos turns back into its rock if it is still there.
local function unplace(pos, tier)
	local node = core.get_node_or_nil(pos)
	local remains = catalog.remains(tier)
	if node and node.name == remains.node then
		core.set_node(pos, {name = remains.host})
	end
end

local function place_remains(player, effect)
	local row = effect.row
	local pos = random_spot(rounded(player:get_pos()), row, effect.name)
	if not pos then return false end
	token_sequence = token_sequence + 1
	local token = effect.name .. "/" .. now_us() .. "/" .. token_sequence
	core.set_node(pos, {name = catalog.remains(row.tier).node})
	local meta = core.get_meta(pos)
	meta:set_string("owner", effect.name)
	meta:set_string("token", token)
	core.get_node_timer(pos):start(row.check_seconds)
	effect.remains = {pos = pos, token = token}
	return true
end

local function remains_texture(tier)
	local def = core.registered_nodes[catalog.remains(tier).node]
	local tile = def and def.tiles and def.tiles[1]
	return type(tile) == "string" and tile or ""
end

local function treasure_check(effect)
	local player = core.get_player_by_name(effect.name)
	if not player then return end
	local row = effect.row
	local pos = player:get_pos()
	local remains = effect.remains
	if remains then
		local node = core.get_node_or_nil(remains.pos)
		if node and node.name ~= catalog.remains(row.tier).node then
			forget_remains(effect) -- gone some other way
		elseif distance(pos, remains.pos) > row.remove_distance then
			unplace(remains.pos, row.tier)
			forget_remains(effect)
		elseif distance(pos, remains.pos) <= row.marker_range then
			if not effect.remains_marker then
				effect.remains_marker = add_marker(player, remains.pos, remains_texture(row.tier))
			end
		else
			remove_marker(effect, "remains_marker")
		end
	elseif now_us() >= effect.next_place_us and in_band(row.tier, pos.y) then
		if place_remains(player, effect) then treasure_check(effect) end
	end
end

local function treasure_loop(effect)
	later(effect, effect.row.check_seconds, function()
		treasure_check(effect)
		treasure_loop(effect)
	end)
end

-- The Remains' node timer (items.lua): true keeps the block, false means it
-- turned back into its rock.
function grug_guild._remains_on_timer(pos, tier)
	local meta = core.get_meta(pos)
	local owner, token = meta:get_string("owner"), meta:get_string("token")
	local effect = effects[owner]
	local current = effect and effect.remains and effect.remains.token == token
	local player = owner ~= "" and core.get_player_by_name(owner)
	if current and player and distance(player:get_pos(), pos) <= effect.row.remove_distance then
		return true
	end
	core.set_node(pos, {name = catalog.remains(tier).host})
	if current then forget_remains(effect) end
	return false
end

-- A Remains was dug (items.lua, after_dig_node): its owner's effect waits
-- for the next one.
function grug_guild._remains_on_dig(oldmeta)
	local fields = oldmeta and oldmeta.fields or {}
	local effect = effects[fields.owner or ""]
	if effect and effect.remains and effect.remains.token == fields.token then
		forget_remains(effect)
	end
end

------------------------------------------------------------------------------
-- Ore Sense: the marks.
------------------------------------------------------------------------------

local target_nodes = {} -- tier -> {node names in catalogue order}
for tier, keys in ipairs(catalog.ORE_SENSE_TARGETS) do
	local nodes = {}
	for index, key in ipairs(keys) do
		nodes[index] = grug_materials.RESOURCE_BY_KEY[key].natural_node
	end
	target_nodes[tier] = nodes
end

-- The deposit Ore Sense of `tier` marks from pos: the nearest node of the
-- first target with one in the range box (clipped to the band), or nil.
-- One engine search for all targets.
function grug_guild.ore_sense_find(pos, tier, range)
	pos = rounded(pos)
	local band = tier_row(tier)
	local minp = {x = pos.x - range, y = math.max(pos.y - range, band.y_min), z = pos.z - range}
	local maxp = {x = pos.x + range, y = math.min(pos.y + range, band.y_max), z = pos.z + range}
	if minp.y > maxp.y then return nil end
	local found = core.find_nodes_in_area(minp, maxp, target_nodes[tier], true)
	for _, node_name in ipairs(target_nodes[tier]) do
		local best, best_distance
		for _, at in ipairs(found[node_name] or {}) do
			local d = distance(pos, at)
			if not best or d < best_distance then best, best_distance = at, d end
		end
		if best then return best, node_name end
	end
	return nil
end

local function ore_texture(node_name)
	local def = core.registered_nodes[node_name]
	local tile = def and def.tiles and def.tiles[1]
	if type(tile) == "table" then tile = tile.name end
	return type(tile) == "string" and tile or ""
end

local function ore_sense_mark(effect)
	local player = core.get_player_by_name(effect.name)
	if not player then return end
	local row = effect.row
	local pos = player:get_pos()
	if not in_band(row.tier, pos.y) then return end
	local at, node_name = grug_guild.ore_sense_find(pos, row.tier, row.range)
	if not at then return end
	remove_marker(effect, "ore_marker")
	local id = add_marker(player, at, ore_texture(node_name))
	effect.ore_marker = id
	later(effect, row.marker_seconds, function()
		if effect.ore_marker == id then remove_marker(effect, "ore_marker") end
	end)
end

local function ore_sense_loop(effect)
	local row = effect.row
	later(effect, math.random(row.interval_min, row.interval_max), function()
		ore_sense_mark(effect)
		ore_sense_loop(effect)
	end)
end

------------------------------------------------------------------------------
-- The effect's life.
------------------------------------------------------------------------------

local function finish(effect)
	if effects[effect.name] ~= effect then return end
	if effect.remains then unplace(effect.remains.pos, effect.row.tier) end
	remove_marker(effect, "ore_marker")
	remove_marker(effect, "remains_marker")
	effects[effect.name] = nil
	local player = core.get_player_by_name(effect.name)
	if player then
		grug_core.clear_status(player, STATUS_ID)
		player:get_meta():set_string(EFFECT_KEY, "")
	end
end

local function expiry_loop(effect)
	later(effect, math.max(0.1, remaining_seconds(effect)), function()
		if remaining_seconds(effect) <= 0 then finish(effect) else expiry_loop(effect) end
	end)
end

local function save_loop(effect)
	later(effect, SAVE_SECONDS, function()
		local player = core.get_player_by_name(effect.name)
		if player then save(player, effect) end
		save_loop(effect)
	end)
end

-- Runs `row` for `seconds` from now (a new use or a saved effect).
local function begin(player, row, seconds)
	local effect = {name = player:get_player_name(), row = row,
		ends_us = now_us() + seconds * 1e6, next_place_us = 0}
	effects[effect.name] = effect
	apply_status(player, effect)
	save(player, effect)
	expiry_loop(effect)
	save_loop(effect)
	if row.kind == "ore_sense" then
		ore_sense_loop(effect)
	else
		treasure_check(effect)
		treasure_loop(effect)
	end
	return effect
end

function grug_guild.active_effect(player)
	local effect = effects[player_name(player) or ""]
	if not effect then return nil end
	return {kind = effect.row.kind, tier = effect.row.tier, remaining = remaining_seconds(effect)}
end

function grug_guild.start_effect(player, kind, tier)
	local row = catalog.consumable(kind, tier)
	if not row or not player_name(player) then return false, "unknown" end
	if not grug_core.can_use_item_level(player, row.item) then return false, "level" end
	if effects[player:get_player_name()] then return false, "active" end
	if not in_band(row.tier, player:get_pos().y) then return false, "depth" end
	begin(player, row, row.duration)
	return true
end

function grug_guild.stop_effect(player)
	local effect = effects[player_name(player) or ""]
	if not effect then return false end
	finish(effect)
	return true
end

-- The saved effect, or nil for none or a broken value.
local function saved(player)
	local text = player:get_meta():get_string(EFFECT_KEY)
	if text == "" then return nil end
	local value = core.deserialize(text, true)
	if type(value) ~= "table" then return nil end
	local row = catalog.consumable(value.kind, value.tier)
	local seconds = tonumber(value.remaining)
	if not row or not seconds or seconds <= 0 then return nil end
	return row, math.min(seconds, row.duration)
end

core.register_on_joinplayer(function(player)
	local row, seconds = saved(player)
	if row then
		begin(player, row, seconds)
	elseif player:get_meta():get_string(EFFECT_KEY) ~= "" then
		player:get_meta():set_string(EFFECT_KEY, "")
	end
end)

core.register_on_leaveplayer(function(player)
	local effect = effects[player:get_player_name()]
	if not effect then return end
	save(player, effect)
	-- The Remains goes with its owner (its timer would see to it too).
	if effect.remains then unplace(effect.remains.pos, effect.row.tier) end
	effects[effect.name] = nil
end)

-- grug_core cleared the status in its own death callback just before this
-- one; the effect goes on, so its picture comes back.
local function reapply(player)
	local effect = effects[player:get_player_name()]
	if effect and remaining_seconds(effect) > 0 then apply_status(player, effect) end
end
core.register_on_dieplayer(reapply)
core.register_on_respawnplayer(reapply)
