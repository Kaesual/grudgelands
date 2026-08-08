-- Destructibility rules (docs/design/world.md §2) as one central
-- core.is_protected override:
--   R1 — own faction continent: free digging/building except protected
--        zones (the six race-capital spawn platforms and every POI in the
--        registry below — military outposts today, villages/real capitals
--        with WP13).
--   R2 — enemy continent: nothing may be dug or placed (torches included).
--   R3 — ocean: everything outside the two continent rectangles (strait,
--        coastal ocean, open sea) is locked for everyone. Sole exception
--        later: guild housing cubes (R5), which get their own WP.
-- R4 (ore respawn) is deferred to the outpost/mining-zone WPs.

local old_is_protected = core.is_protected

local CAMP_HALF = grug_core.CAMP_HALF
local DEPTH = grug_core.POI_PROTECT_DEPTH

-- Literally the same store the platform heights use: builtin caches one
-- StorageRef per mod name (builtin/common/mod_storage.lua), and this file is
-- dofile'd from grug_core/init.lua, so core.get_current_modname() still says
-- grug_core here. init.lua's handle is a local of another chunk and cannot be
-- reached from this one — asking again is the cheap, correct way. Fetched at
-- load time as the AGENTS.md persistence rule demands.
local storage = core.get_mod_storage()

--
-- POI registry (world.md §2 "villages, outposts and the real capitals also
-- protect >= 10 nodes of surrounding terrain")
--
-- Deliberately concrete instead of a register_poi_KIND framework: a POI is
-- an axis-aligned x/z square with a base level, and that is all the
-- protection shape of §2 needs. Kinds/roles belong to whoever places them.
--
--   grug_core.add_poi({id = "outpost:accord:dwarf:inner",
--                      x = -550, z = -500, half = 14, y_base = 12})
--
-- `half` is the FINAL horizontal half-extent the caller wants protected,
-- surround included — the registry does not add anything to it. Mapgen
-- therefore passes grug_core.OUTPOST_HALF + 10 (§2's ">= 10 nodes of
-- surrounding terrain"), and a future village passes its own structure half
-- plus the same 10.
--
-- Persistence: ONE serialized table under the key "pois", mirrored in the
-- in-memory list below at load time. A few dozen entries is what the §9 POI
-- budget produces (24 outposts today; the bandit camps of the same pass are
-- deliberately NOT registered — they are raidable), so one string is cheaper
-- than a key per POI.
--
-- Idempotent by id: mapgen may look at the same anchor from up to four
-- neighbouring mapchunks, so add_poi has to be a no-op when nothing changed
-- (in particular it must not rewrite mod storage on every mapchunk).
--

local pois = {} -- array of {id, x, z, half, y_base}
local poi_by_id = {} -- id -> the SAME record (not an index)

do
	local raw = storage:get_string("pois")
	local loaded = raw ~= "" and core.deserialize(raw) or nil
	if type(loaded) == "table" then
		for i = 1, #loaded do
			local p = loaded[i]
			if type(p) == "table" and p.id and p.x and p.z and p.half
					and p.y_base then
				pois[#pois + 1] = p
				poi_by_id[p.id] = p
			end
		end
	end
end

local function save_pois()
	storage:set_string("pois", core.serialize(pois))
end

-- Adds or updates a protected POI. Returns the stored record.
function grug_core.add_poi(def)
	if not (def and def.id and def.x and def.z and def.half
			and def.y_base) then
		core.log("error", "[grug_core] add_poi: incomplete POI definition")
		return nil
	end
	local x = math.floor(def.x)
	local z = math.floor(def.z)
	local half = math.floor(def.half)
	local y_base = math.floor(def.y_base)
	local rec = poi_by_id[def.id]
	if rec then
		if rec.x == x and rec.z == z and rec.half == half
				and rec.y_base == y_base then
			return rec -- unchanged: no storage write at all
		end
		rec.x, rec.z, rec.half, rec.y_base = x, z, half, y_base
	else
		rec = {id = def.id, x = x, z = z, half = half, y_base = y_base}
		pois[#pois + 1] = rec
		poi_by_id[def.id] = rec
	end
	save_pois()
	core.log("action", ("[grug_core] POI %s protected: %d,%d half %d, from " ..
		"y=%d up"):format(rec.id, rec.x, rec.z, rec.half, rec.y_base - DEPTH))
	return rec
end

function grug_core.get_poi(id)
	return poi_by_id[id]
end

-- Protected zone of a race capital's spawn platform (world.md §2):
--   * horizontally ONLY the platform footprint (|dx|, |dz| <= CAMP_HALF).
--     The terrain right next to a platform stays diggable on purpose — the
--     platform is terrain-adaptive, so its edge can end up against a hillside
--     or in a pocket, and a player who spawns there must be able to dig out.
--   * vertically from POI_PROTECT_DEPTH below the platform upward without a
--     limit: no towers over the capital, no tunnel sabotage from directly
--     below, while mining deeper down stays free.
-- The registry above uses the same vertical rule with a LARGER horizontal
-- zone that includes the >= 10 nodes of surrounding terrain §2 asks for.
-- Footprints never overlap (capitals are 550+ nodes apart), so the first
-- matching capital decides.
local function in_capital_zone(pos)
	for race_id, capital in pairs(grug_core.capitals) do
		if math.abs(pos.x - capital.x) <= CAMP_HALF and
				math.abs(pos.z - capital.z) <= CAMP_HALF then
			-- Undecided platform (chunk never generated): the fallback y is
			-- what get_spawn_pos would use too.
			local platform_y = grug_core.get_camp_platform_y(race_id)
				or grug_core.CAMP_PLATFORM_Y
			return pos.y >= platform_y - DEPTH
		end
	end
	return false
end

-- Linear scan over the registry. Budget: is_protected runs on every dig/place
-- ATTEMPT (not per node per step), and the §9 POI budget keeps this list well
-- under 100 entries, so a scan of four number comparisons per POI is far
-- cheaper than an AreaStore. It is deliberately allocation-free — no
-- vector.new, no closures, nothing the GC has to collect per dig.
local function in_poi_zone(pos)
	local x, y, z = pos.x, pos.y, pos.z
	for i = 1, #pois do
		local p = pois[i]
		local dx = x - p.x
		if dx < 0 then dx = -dx end
		if dx <= p.half then
			local dz = z - p.z
			if dz < 0 then dz = -dz end
			if dz <= p.half and y >= p.y_base - DEPTH then
				return true
			end
		end
	end
	return false
end

-- BOX form of the two zone tests above, for passes that work on a whole
-- mapblock instead of on one dig attempt: true when any protected structure
-- zone — a capital platform or any POI — intersects minp..maxp.
--
-- It exists because "do not touch a protected POI" has to be answerable
-- WITHOUT the caller knowing what kind of structure stands there or what it is
-- built of: grug_mapgen's ocean-mask healing LBM would otherwise delete the
-- four wooden corner posts of every outpost whose pad mapgen clamped onto the
-- coast cap (12 of the 24 sit in the coast/war-coast band), and WP13's
-- structures would walk into the same trap one by one. Asking here means they
-- are all covered by the rule that already protects them from players.
--
-- Same rules as in_capital_zone/in_poi_zone, transposed: the horizontal square
-- is unchanged, and the vertical half-line "from y_base - DEPTH upward" becomes
-- "the box's TOP edge reaches it". Deliberately allocation-free and linear —
-- the §9 POI budget keeps the list under 100 entries, and the caller pays this
-- once per mapblock, after its own cheap arithmetic gates.
function grug_core.protected_zone_in_box(minp, maxp)
	for race_id, capital in pairs(grug_core.capitals) do
		if maxp.x >= capital.x - CAMP_HALF and
				minp.x <= capital.x + CAMP_HALF and
				maxp.z >= capital.z - CAMP_HALF and
				minp.z <= capital.z + CAMP_HALF then
			local platform_y = grug_core.get_camp_platform_y(race_id)
				or grug_core.CAMP_PLATFORM_Y
			if maxp.y >= platform_y - DEPTH then
				return true
			end
		end
	end
	for i = 1, #pois do
		local p = pois[i]
		if maxp.x >= p.x - p.half and minp.x <= p.x + p.half and
				maxp.z >= p.z - p.half and minp.z <= p.z + p.half and
				maxp.y >= p.y_base - DEPTH then
			return true
		end
	end
	return false
end

function core.is_protected(pos, name)
	if name ~= "" and
			core.check_player_privs(name, {protection_bypass = true}) then
		return old_is_protected(pos, name)
	end

	local territory = grug_core.territory_at(pos)
	if territory == "ocean" then
		return true -- R3
	end
	-- Factionless actors (offline names, mods asking with "") get the safe
	-- default: protected.
	if grug_core.get_player_faction(name) ~= territory then
		return true -- R2
	end
	if in_capital_zone(pos) or in_poi_zone(pos) then
		return true -- protected zone inside the own continent
	end
	return old_is_protected(pos, name) -- R1, other mods may still object
end
