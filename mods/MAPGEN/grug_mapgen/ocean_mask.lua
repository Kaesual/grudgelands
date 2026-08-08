-- CONTINENT OCEAN MASK — the main-environment half. Three jobs, none of them
-- voxel work (the carve itself lives in ocean_mask_mapgen.lua and runs in the
-- mapgen environment):
--
--   1. build the shared geometry from grug_core's continent rectangle and hand
--      the same three numbers to the mapgen environment via IPC;
--   2. register the mapgen script;
--   3. register the idempotent healing LBM for worlds generated before WP36.
--
-- Nothing here may assume the mapgen env exists yet: the mapgen threads are
-- initialized after every mod is loaded (lua_api.md:7688-7690), so the IPC value
-- below is always in place by the time ocean_mask_mapgen.lua reads it.

local path = core.get_modpath(core.get_current_modname())

--
-- (1) Geometry — one source of truth for two Lua states
--

local CONTINENT = {
	x_half = grug_core.CONTINENT_X_HALF,
	z_min = grug_core.CONTINENT_Z_MIN,
	z_max = grug_core.CONTINENT_Z_MAX,
}

local geom = dofile(path .. "/geometry.lua")(CONTINENT)
grug_mapgen.geometry = geom

-- Kept as direct handles for the same reason they always were: these are pure
-- arithmetic and can be exercised headless, without the engine. Nothing outside
-- this mod may re-derive the coast profile — ask these.
-- NB tools/biomecheck/model.py re-implements exactly this geometry and its
-- header cites structures.lua; the logic now lives in geometry.lua.
grug_mapgen.continent_distance = geom.continent_distance
grug_mapgen.surface_cap = geom.surface_cap
grug_mapgen.column_cap = geom.column_cap

--
-- (2) The mapgen script
--

-- The mapgen env is a separate Lua state: no grug_core, no mod storage, no POI
-- registry. It gets the rectangle — and only the rectangle, the profile is
-- geometry.lua's — through the engine's cross-environment key/value store
-- (lua_api.md:7825-7840).
core.ipc_set("grug_mapgen:continent", CONTINENT)
core.register_mapgen_script(path .. "/ocean_mask_mapgen.lua")

--
-- (3) The healing LBM (WP36 item 2)
--
-- Every world generated before this WP carries floating tree crowns over the
-- coastal water: the mask clamped its carve to maxp.y while the engine places
-- schematic decorations up to emax.y = maxp.y + 16 (mg_decoration.cpp:424).
-- Mapgen never runs over a generated chunk again, so the fix in
-- ocean_mask_mapgen.lua cannot reach those worlds — an LBM can.
--
-- WHY IT IS SAFE TO RUN AT EVERY LOAD: column_cap is a pure function of (x, z).
-- The sweep therefore reproduces exactly the cut the mapgen made (or should
-- have made) for that column, at any time, in any session, and a column that is
-- already correct is air/water above its cap, where nothing below matches. It
-- is also SELF-EXTINGUISHING: once a block is healed it has no matching node
-- above its cap left, so every later activation of it writes nothing.
--
-- run_at_every_load = true is required, not preferred: an LBM with
-- run_at_every_load = false never runs on mapblocks generated after the LBM was
-- introduced (lua_api.md:10312-10316), which would leave any chunk generated
-- from now on — i.e. exactly the ones a player is about to walk into —
-- unhealed on a world that is otherwise fixed.
--
-- COST. Three gates, in increasing order of price, and the first two are O(1)
-- per mapblock:
--
--  a) The engine already scans every activated mapblock for run_at_every_load
--     LBMs — grug_mobs' guard_banner_init and camp_fire_init are two of them —
--     and all of them share ONE bucket in the lookup table (blockmodifier.cpp
--     :380-386, keyed U32_MAX). Adding this LBM therefore adds no block scan
--     at all; it only extends the content-id -> LBM mapping that scan already
--     consults. Nothing reaches Lua for a block without a matching node.
--  b) box_needs_mask on the mapblock box: a block that is fully inland
--     (continent_distance >= TAPER + INSET_MAX everywhere) or entirely at or
--     below the deepest cap the mask can ever produce (MASK_MIN_Y) returns
--     immediately — the same arithmetic gate the mapgen pass uses, with
--     grow = 0 because an LBM only sees the block's own nodes.
--  c) box_cap_bounds, still without a noise sample: below the box's lowest
--     possible cap there is nothing to do (this covers the low-altitude forest
--     of the inner coast band, the bulk of what survives gate b), and above its
--     highest possible cap every matched node is above its column's cap, so the
--     per-column lookup is skipped entirely — which is precisely the case of
--     the floating crowns at y 48+ over a beach.
--
-- Only when a block straddles the cap does it pay per column, and then at most
-- 16x16 = 256 column_cap calls, memoised for the whole call: the node list of
-- one bulk_action always belongs to a single mapblock (s_env.cpp:464-477).
--
-- BLAST RADIUS. nodenames is not "everything solid": it is the content the
-- engine's own decoration stage can place, minus terrain material (see
-- healable_nodes below). An LBM cannot tell mapgen overflow from a player
-- build, and the honest limit of that is stated there.
--

local column_cap = geom.column_cap
local box_needs_mask = geom.box_needs_mask
local box_cap_bounds = geom.box_cap_bounds
local WATER_LEVEL = geom.WATER_LEVEL

local AIR = {name = "air"}
local WATER = {name = "default:water_source"}

-- The set the sweep is allowed to remove.
--
-- Derived, never hand-written: every node name that appears in a registered
-- decoration (the schematic's voxels, or a simple decoration's node list),
-- because that is exactly the content that can end up above the cap after the
-- mask ran — mgv7 places a decoration's ROOT inside minp..maxp
-- (mg_decoration.cpp:229-231), so only the part of a SCHEMATIC that reaches
-- past maxp.y ever survived the old carve.
--
-- Minus two exclusions:
--   * air, ignore and every liquid — the mask never replaces those, and
--     `ignore` in particular is never-generated volume;
--   * terrain material: any node that is also a biome surface/filler/stone/
--     riverbed/dust node or the place_on target of some decoration. The one
--     real case is default:dirt, which papyrus_on_dirt.mts carries in its
--     bottom slice — that slice sits at the decoration's root and was always
--     carved, so it cannot float, and keeping dirt out of this list means a
--     player's dirt platform over the coastal water is not something a block
--     load deletes.
-- The honest residual: a player who builds a treehouse out of trunks and leaves
-- ABOVE the coast profile (above column_cap, which over the water is below sea
-- level) will lose it. There is no signal in the map that distinguishes that
-- from mapgen overflow, and the alternative — never healing existing worlds —
-- is worse. Everything below the cap, and everything outside the coast band, is
-- untouched.
local function healable_nodes()
	local terrain = {}
	local function block(name)
		if type(name) == "string" then
			terrain[name] = true
		end
	end
	for _, def in pairs(core.registered_biomes) do
		block(def.node_top)
		block(def.node_filler)
		block(def.node_stone)
		block(def.node_riverbed)
		block(def.node_dust)
		block(def.node_water_top)
		block(def.node_water)
		block(def.node_river_water)
		block(def.node_cave_liquid)
	end
	for _, def in pairs(core.registered_decorations) do
		local on = def.place_on
		if type(on) == "table" then
			for i = 1, #on do
				block(on[i])
			end
		else
			block(on)
		end
	end

	local names, seen = {}, {}
	local function add(name)
		if type(name) ~= "string" or name == "" or seen[name] then
			return
		end
		seen[name] = true
		if name == "air" or name == "ignore" or terrain[name] then
			return
		end
		local def = core.registered_nodes[name]
		if not def then
			return
		end
		if def.liquidtype and def.liquidtype ~= "none" then
			return
		end
		names[#names + 1] = name
	end

	for _, def in pairs(core.registered_decorations) do
		if def.deco_type == "schematic" then
			-- register_decoration keeps the def table we passed
			-- (builtin/game/register.lua:502-512), so this is the read_schematic
			-- table decorations.lua built.
			local schem = def.schematic
			local voxels = type(schem) == "table" and schem.data
			if type(voxels) == "table" then
				for i = 1, #voxels do
					add(voxels[i].name)
				end
			end
		else
			local d = def.decoration
			if type(d) == "table" then
				for i = 1, #d do
					add(d[i])
				end
			else
				add(d)
			end
		end
	end
	return names
end

-- One bulk_action call = one mapblock (s_env.cpp:464-477), one content id.
local function heal_block(pos_list)
	local first = pos_list[1]
	if not first then
		return
	end
	local bx = math.floor(first.x / 16) * 16
	local by = math.floor(first.y / 16) * 16
	local bz = math.floor(first.z / 16) * 16
	local bmin = {x = bx, y = by, z = bz}
	local bmax = {x = bx + 15, y = by + 15, z = bz + 15}
	if not box_needs_mask(bmin, bmax, 0) then
		return
	end
	local cap_lo, cap_hi = box_cap_bounds(bmin, bmax, 0)
	if not cap_lo or bmax.y <= cap_lo then
		return -- the whole block sits at or below the lowest cap it can have
	end
	-- Above the highest cap the box can produce every node is above its own
	-- column's cap; no per-column noise lookup is needed at all.
	local all_above = cap_hi ~= nil and bmin.y > cap_hi

	local caps = {}
	local air, water, n_air, n_water = {}, {}, 0, 0
	for i = 1, #pos_list do
		local p = pos_list[i]
		local cut = all_above
		if not cut then
			local key = (p.x - bx) * 16 + (p.z - bz)
			local cap = caps[key]
			if cap == nil then
				cap = column_cap(p.x, p.z)
				if cap == nil then
					cap = false -- inland column: hands off, memoise that too
				end
				caps[key] = cap
			end
			cut = cap and p.y > cap
		end
		if cut then
			if p.y <= WATER_LEVEL then
				n_water = n_water + 1
				water[n_water] = p
			else
				n_air = n_air + 1
				air[n_air] = p
			end
		end
	end
	-- set_node, not swap_node: removing a canopy changes the light below it and
	-- the water has to start flowing, both of which only the full node-set path
	-- schedules.
	if n_air > 0 then
		core.bulk_set_node(air, AIR)
	end
	if n_water > 0 then
		core.bulk_set_node(water, WATER)
	end
end

-- Registered at LOAD TIME, deliberately, and never from register_on_mods_loaded:
-- core.register_lbm runs check_modname_prefix, which derives the required
-- "grug_mapgen:" prefix from core.get_current_modname()
-- (builtin/game/register.lua:58-69, :106). That is nil outside a mod's own load,
-- so the same call from an on_mods_loaded callback errors out on its own name.
--
-- Load time is sound for the node list too: init.lua dofiles biomes.lua and
-- decorations.lua before this file, and grug_mapgen registers every biome and
-- every decoration in this game (default's own sets are deliberately never
-- called — see the tail of mods/BASE/default/mapgen.lua). The audit below is
-- what keeps that assumption honest instead of silent.
local healable = healable_nodes()

if #healable > 0 then
	core.register_lbm({
		label = "Ocean mask: remove decoration overflow above the coast cap",
		name = "grug_mapgen:ocean_mask_heal",
		nodenames = healable,
		run_at_every_load = true,
		bulk_action = function(pos_list)
			heal_block(pos_list)
		end,
	})
else
	core.log("warning", "[grug_mapgen] no decoration content found — the " ..
		"ocean mask healing LBM is not registered")
end

-- Startup audit (the grug_traders pattern: silent when clean). If a mod that
-- loads after grug_mapgen registers decorations, their content is NOT in the
-- list above and existing worlds would keep floating crowns of exactly that
-- content. Nothing can be repaired here — the LBM is already registered and
-- core.registered_lbms is frozen on the first server step — so this says so
-- out loud rather than losing the case.
core.register_on_mods_loaded(function()
	local covered = {}
	for i = 1, #healable do
		covered[healable[i]] = true
	end
	local missing = {}
	local now = healable_nodes()
	for i = 1, #now do
		if not covered[now[i]] then
			missing[#missing + 1] = now[i]
		end
	end
	if #missing > 0 then
		core.log("warning", "[grug_mapgen] decorations registered after " ..
			"grug_mapgen: the ocean mask healing LBM does not cover " ..
			table.concat(missing, ", ") .. " — move the registration into " ..
			"grug_mapgen or load that mod earlier")
	end
end)
