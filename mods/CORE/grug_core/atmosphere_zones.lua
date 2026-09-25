-- Zone-driven atmosphere moods: one look per race region, plus underground,
-- open ocean, the shared Battlegrounds and the two level-60 dragon islands.
-- Loaded after atmosphere.lua, which owns the preset table, the send-on-change
-- rule and the /atmosphere command; this file only adds presets to that table
-- and decides which one a player should be carrying.
--
-- WHY A SECOND FILE: atmosphere.lua is the shipped A/B layer and its four
-- presets are frozen reference points. Everything that depends on world
-- geometry lives here, behind its own setting, so turning the zone layer off
-- leaves that reference layer byte-for-byte the behaviour it had.
--
-- ============================ ENGINE CONTRACT ============================
--
-- set_sky MERGES, exactly like set_lighting. l_object.cpp:2218 starts from
-- `player->getSkyParams()` and overwrites only what the table carries, so a
-- mood that omits a field INHERITS the previous mood's value. Three merge
-- traps decide the shape of the tables below:
--
--   1. Inside `sky_color`, every colour is read with `read_color` on a field
--      that may be nil (l_object.cpp:2257-2283). read_color leaves the target
--      untouched when the value is not a table/number/string
--      (common/c_converter.cpp:286-288), so an omitted colour is *inherited*,
--      not defaulted. Every mood therefore states all seven sky colours.
--   2. Merely HAVING a `sky_color` table resets fog_sun_tint and fog_moon_tint
--      to opaque white before reading them (l_object.cpp:2286, :2291 — the
--      "prevent flickering clouds at dawn/dusk" lines). Omitting them does not
--      inherit, it whitens the sunrise. Every mood states both, and states
--      `fog_tint_type` (l_object.cpp:2296) to say which pair the client uses
--      (lua_api.md:9438-9441).
--   3. The `fog` block reads fog_distance/fog_start with the CURRENT value as
--      the default (l_object.cpp:2305-2308) and fog_color through read_color
--      (:2310-2312). All three are stated by every mood; a mood that wants the
--      client's own view distance states the documented reset value -1
--      (lua_api.md:9445, :9451) rather than omitting the field. Since
--      2026-09-17 EVERY mood states -1 (user ruling: the view distance is
--      the client's own setting in every zone, no per-zone cap; the mood
--      lives in fog_start, fog_color and the sky colours). A positive
--      fog_distance also caps the server's block send range
--      (clientiface.cpp:180-184: wanted_range = min(wanted_range,
--      ceil(fog_distance / 16))), which is why the caps were removed.
--
-- fog_color only takes effect when its ALPHA is non-zero: client/sky.h:119-123
-- returns the override only for `getAlpha() > 0` and falls back to the sky
-- background otherwise. Six-digit ColorSpec gives alpha 255, which is why every
-- fog_color below is six digits and every cloud colour is eight.
--
-- set_clouds merges the same way (l_object.cpp:2654 `player->getCloudParams()`),
-- so every mood states every cloud field.
--
-- COST: one packet per group per change, and only on change.
-- Server::setSky/setClouds/setLighting (server.cpp:3661-3709) each store the
-- value on the RemotePlayer and send exactly one packet; those three functions
-- are the only callers of SendSetSky/SendCloudParams/SendSetLighting in the
-- engine. grug_core.set_atmosphere returns early when the name is unchanged,
-- so a standing player costs zero packets.
--
-- TRANSITIONS: the client eases the SKY and HORIZON colours by itself. Sky
-- update() lerps m_bgcolor_bright_f / m_skycolor_bright_f toward the targets
-- built from sky_color every frame with fraction 0.98 (client/sky.cpp:336-387),
-- i.e. about 2% per frame, so a mood change fades in over roughly a second at
-- 60 fps. The explicit fog_color override does NOT ease: getFogColor returns
-- the stored value raw (client/sky.h:118-123), and fog_distance/fog_start are
-- applied to draw_control the frame the packet arrives (client/game.cpp:2435,
-- :2441-2446, :3403-3406). Cloud parameters likewise switch hard. We accept
-- that: no interpolation loop is implemented here, because a per-step colour
-- ramp is exactly the per-globalstep packet traffic this package exists to
-- avoid. The sky ease covers the largest visual jump on its own.
--
-- SUN/MOON: deliberately not touched. set_sun/set_moon are two more packets
-- per change and would have to be stated by EVERY preset to stay merge-safe
-- (including the shipped four, which are frozen). The directional warmth a
-- mood wants is already available inside the sky packet as
-- fog_sun_tint/fog_moon_tint, which cost nothing extra.

local zones_enabled = core.settings:get_bool("grug_atmosphere_zones", true)

local presets = grug_core.atmosphere_presets

---------------------------------------------------------------------------
-- Mood construction
---------------------------------------------------------------------------

-- The shipped `default` numbers, repeated here as the baseline every mood
-- starts from. Copied rather than read out of presets["default"]: a mood must
-- be a plain literal table of numbers and strings so that nothing in the send
-- path ever walks or copies a preset.
local BASE_LUMINANCE_MIN = -3.5
local BASE_LUMINANCE_MAX = -2.5
local BASE_SPEED_DARK_BRIGHT = 1500
local BASE_SPEED_BRIGHT_DARK = 700
local BASE_SHADOW_INTENSITY = 0.33
local BASE_SATURATION = 1.1
local BASE_EXPOSURE_CORRECTION = 0.35
local BASE_BLOOM_INTENSITY = 0.05

-- Builds one complete lighting table. Every group the engine merges is stated,
-- so switching between any two moods (or to any shipped preset) is
-- order-independent. `shadows.direction` and `exposure.center_weight_power`
-- stay unstated across the whole game, as atmosphere.lua's header requires.
local function lighting(spec)
	return {
		shadows = {
			intensity = spec.shadow_intensity or BASE_SHADOW_INTENSITY,
			tint = {
				r = spec.shadow_r,
				g = spec.shadow_g,
				b = spec.shadow_b,
			},
		},
		saturation = spec.saturation or BASE_SATURATION,
		exposure = {
			luminance_min = BASE_LUMINANCE_MIN,
			luminance_max = BASE_LUMINANCE_MAX,
			exposure_correction = spec.exposure or BASE_EXPOSURE_CORRECTION,
			speed_dark_bright = BASE_SPEED_DARK_BRIGHT,
			speed_bright_dark = BASE_SPEED_BRIGHT_DARK,
		},
		bloom = {
			intensity = spec.bloom or BASE_BLOOM_INTENSITY,
			strength_factor = 1.0,
			radius = 1.0,
		},
		volumetric_light = {strength = 0},
	}
end

-- Builds one complete sky table. See the three merge traps in the header for
-- why nothing here may be omitted.
local function sky(spec)
	return {
		type = "regular",
		clouds = spec.clouds_visible ~= false,
		sky_color = {
			day_sky = spec.day_sky,
			day_horizon = spec.day_horizon,
			dawn_sky = spec.dawn_sky,
			dawn_horizon = spec.dawn_horizon,
			night_sky = spec.night_sky,
			night_horizon = spec.night_horizon,
			indoors = spec.indoors,
			fog_sun_tint = spec.fog_sun_tint,
			fog_moon_tint = spec.fog_moon_tint,
			fog_tint_type = spec.fog_tint_type or "custom",
		},
		fog = {
			-- -1 is the documented "client controls it" reset
			-- (lua_api.md:9445, :9451), stated so a clear mood actively undoes
			-- a hazy one instead of inheriting its cap.
			fog_distance = spec.fog_distance,
			fog_start = spec.fog_start,
			fog_color = spec.fog_color,
		},
	}
end

-- Builds one complete cloud table.
local function clouds(spec)
	return {
		density = spec.density,
		color = spec.color,
		ambient = spec.ambient,
		height = spec.height,
		thickness = spec.thickness,
		speed = {x = 0, z = spec.drift},
		shadow = spec.shadow,
	}
end

-- Registers one mood as an ordinary preset, so /atmosphere <mood> can force it
-- for an A/B test and grug_core.set_atmosphere needs no new code path.
local MOODS = {}

local function mood(name, description, light_spec, sky_spec, cloud_spec)
	presets[name] = {
		description = description,
		lighting = lighting(light_spec),
		sky = sky(sky_spec),
		clouds = clouds(cloud_spec),
	}
	MOODS[name] = true
end

---------------------------------------------------------------------------
-- The moods (world_zones.md §10 race-region character)
---------------------------------------------------------------------------

-- Dwarf: pine shelves, granite, snow ridges. Cool blue-grey, slightly
-- desaturated, an early fog_start that makes the ridges stack.
mood("dwarf", "Dwarf region: cold blue-grey stone haze",
	{shadow_r = 14, shadow_g = 18, shadow_b = 26,
		saturation = 1.05, exposure = 0.30, bloom = 0.05},
	{day_sky = "#5c8fc4", day_horizon = "#a8c0cf",
		dawn_sky = "#9fb0d2", dawn_horizon = "#c3cbd4",
		night_sky = "#0a3c74", night_horizon = "#2c5f93",
		indoors = "#5a6266",
		fog_sun_tint = "#e0a071", fog_moon_tint = "#8fa8c8",
		fog_distance = -1, fog_start = 0.45, fog_color = "#8fa3ad"},
	{density = 0.5, color = "#f2f7fbe5", ambient = "#10161c",
		height = 150, thickness = 18, drift = -2.5, shadow = "#b8c2c9"})

-- Human: fields, oak woods, river forks. The clear warm reference look; the
-- reference look with the latest fog_start.
mood("human", "Human region: clear warm farmland light",
	{shadow_r = 24, shadow_g = 20, shadow_b = 12,
		saturation = 1.12, exposure = 0.38, bloom = 0.06},
	{day_sky = "#6cbaf7", day_horizon = "#b8dcf0",
		dawn_sky = "#cdb9f0", dawn_horizon = "#f0d1b4",
		night_sky = "#0b3f94", night_horizon = "#3f77c0",
		indoors = "#6b6a63",
		fog_sun_tint = "#ffa552", fog_moon_tint = "#8fa4cc",
		fog_distance = -1, fog_start = 0.70, fog_color = "#cfe0ea"},
	{density = 0.35, color = "#fff6ece5", ambient = "#141008",
		height = 130, thickness = 16, drift = -2.0, shadow = "#d0c8bc"})

-- Elf: silverwood, pale cliffs, lakes. Bright and silvery: pale, low
-- saturation, brighter exposure and the strongest ordinary bloom.
mood("elf", "Elf region: bright silver haze over pale cliffs",
	{shadow_r = 18, shadow_g = 22, shadow_b = 28,
		saturation = 1.02, exposure = 0.45, bloom = 0.10},
	{day_sky = "#7fc6ee", day_horizon = "#d4ecf0",
		dawn_sky = "#d3c8f5", dawn_horizon = "#e4dcf2",
		night_sky = "#1b3f8a", night_horizon = "#5a86c8",
		indoors = "#74777a",
		fog_sun_tint = "#ffd2a0", fog_moon_tint = "#b7c8ee",
		fog_distance = -1, fog_start = 0.60, fog_color = "#dceaee"},
	{density = 0.3, color = "#fffdfae5", ambient = "#1a2028",
		height = 170, thickness = 12, drift = -1.5, shadow = "#ccd6dc"})

-- Undead: blight basins, bone ridges, salt cliffs. The strongest mood in the
-- set: pale grey-green fog closed to 110 nodes and clearly desaturated light.
-- Shadow intensity drops because a hazed sky casts weaker shadows.
mood("undead", "Undead region: pale grey-green blight fog",
	{shadow_intensity = 0.25, shadow_r = 16, shadow_g = 22, shadow_b = 18,
		saturation = 0.72, exposure = 0.22, bloom = 0.04},
	{day_sky = "#7d8f80", day_horizon = "#aeb8a6",
		dawn_sky = "#8e93a0", dawn_horizon = "#b0ad9c",
		night_sky = "#14201c", night_horizon = "#33453c",
		indoors = "#4d554e",
		fog_sun_tint = "#b9b089", fog_moon_tint = "#93a89a",
		fog_distance = -1, fog_start = 0.25, fog_color = "#9aa894"},
	{density = 0.75, color = "#c9d2c4e5", ambient = "#0e120f",
		height = 110, thickness = 24, drift = -1.0, shadow = "#7e887a"})

-- Orc: ochre grass, dry rivers, red mesas. Warm ochre dust, thin high cloud
-- and a fast drift, so the mesas read as wind-scoured.
mood("orc", "Orc region: ochre dust over red mesas",
	{shadow_r = 32, shadow_g = 20, shadow_b = 10,
		saturation = 1.08, exposure = 0.42, bloom = 0.06},
	{day_sky = "#7fb3d8", day_horizon = "#e2b98a",
		dawn_sky = "#d8a583", dawn_horizon = "#e8c090",
		night_sky = "#16264a", night_horizon = "#4a4a66",
		indoors = "#6b6153",
		fog_sun_tint = "#ff9640", fog_moon_tint = "#a89880",
		fog_distance = -1, fog_start = 0.35, fog_color = "#c9a271"},
	{density = 0.25, color = "#f6e2c6e5", ambient = "#1c140a",
		height = 190, thickness = 12, drift = -3.0, shadow = "#bfa385"})

-- Troll: kapok basins, rivers, reed mazes, storm jungle. Warm humid haze:
-- green-tinted fog close in, the highest saturation and a thick low overcast.
mood("troll", "Troll region: warm humid jungle haze",
	{shadow_r = 14, shadow_g = 26, shadow_b = 14,
		saturation = 1.20, exposure = 0.30, bloom = 0.09},
	{day_sky = "#5fb8b0", day_horizon = "#bcd9a8",
		dawn_sky = "#b9c39a", dawn_horizon = "#dcc9a0",
		night_sky = "#0a2a30", night_horizon = "#2a5a52",
		indoors = "#5c6355",
		fog_sun_tint = "#ffb877", fog_moon_tint = "#8fb0a4",
		fog_distance = -1, fog_start = 0.30, fog_color = "#a8c096"},
	{density = 0.8, color = "#e8f0d8e5", ambient = "#101a10",
		height = 100, thickness = 28, drift = -1.0, shadow = "#94a382"})

-- The four shared Battlegrounds (world_zones.md §8.3, territory_rule
-- "holy_grounds"): ash and smoke, grey-brown, desaturated, short view.
mood("battlegrounds", "Battlegrounds: ash haze over the shared front",
	{shadow_intensity = 0.28, shadow_r = 24, shadow_g = 20, shadow_b = 16,
		saturation = 0.85, exposure = 0.28, bloom = 0.05},
	{day_sky = "#7e7f84", day_horizon = "#b3a89c",
		dawn_sky = "#a0949a", dawn_horizon = "#c0ab96",
		night_sky = "#1a1a22", night_horizon = "#3c3a40",
		indoors = "#5a5550",
		fog_sun_tint = "#d98a4a", fog_moon_tint = "#8a8894",
		fog_distance = -1, fog_start = 0.28, fog_color = "#9a9188"},
	{density = 0.85, color = "#cfc6bae5", ambient = "#14100c",
		height = 105, thickness = 26, drift = -3.5, shadow = "#7a736a"})

-- The two offshore level-60 dragon islands (world_zones.md §8.3): storm-lit,
-- violet, the highest contrast and bloom in the game.
mood("dragon_island", "Dragon island: storm-lit violet endpoint",
	{shadow_intensity = 0.40, shadow_r = 20, shadow_g = 14, shadow_b = 30,
		saturation = 1.18, exposure = 0.25, bloom = 0.14},
	{day_sky = "#46527a", day_horizon = "#8e7f96",
		dawn_sky = "#7d6a94", dawn_horizon = "#a88a92",
		night_sky = "#0c0f1e", night_horizon = "#2a2246",
		indoors = "#4a4658",
		fog_sun_tint = "#ff7a3c", fog_moon_tint = "#9a90c4",
		fog_distance = -1, fog_start = 0.30, fog_color = "#6e6785"},
	{density = 0.95, color = "#b9b2cae5", ambient = "#16122a",
		height = 95, thickness = 32, drift = -4.0, shadow = "#5e586e"})

-- Deep ocean and the immutable dragon channels: no zone owns the column, so
-- there is nothing between the player and the horizon. Cold, open, clean.
mood("ocean", "Open ocean: cold clean horizon",
	{shadow_r = 10, shadow_g = 18, shadow_b = 30,
		saturation = 1.05, exposure = 0.40, bloom = 0.06},
	{day_sky = "#4f9fe0", day_horizon = "#9fc9e8",
		dawn_sky = "#a9b6e4", dawn_horizon = "#c6c4dc",
		night_sky = "#04224e", night_horizon = "#1d4d86",
		indoors = "#5f6a72",
		fog_sun_tint = "#ffb070", fog_moon_tint = "#8aa6d4",
		fog_distance = -1, fog_start = 0.75, fog_color = "#a6c4da"},
	{density = 0.45, color = "#f4f8fce5", ambient = "#0c1420",
		height = 140, thickness = 14, drift = -3.0, shadow = "#b6c4d0"})

-- Underground. `indoors` is the colour the client actually uses below ground
-- (lua_api.md:9432), so it carries the mood; fog_color applies regardless of
-- sky type (lua_api.md:9454) and closes the view to 90 nodes. Clouds are hidden
-- rather than merely unseen, which matters at a hillside entrance mouth. Bloom
-- stays high so a torch reads as a light source, and saturation drops.
-- graphics-improvements.md §3 names exactly this look.
mood("underground", "Underground: near-black rock, torch bloom, short fog",
	{shadow_r = 10, shadow_g = 8, shadow_b = 6,
		saturation = 0.80, exposure = 0.30, bloom = 0.10},
	{clouds_visible = false,
		day_sky = "#101418", day_horizon = "#171b20",
		dawn_sky = "#101418", dawn_horizon = "#171b20",
		night_sky = "#05070a", night_horizon = "#0a0d11",
		indoors = "#2a2622",
		fog_sun_tint = "#ffffff", fog_moon_tint = "#ffffff",
		fog_tint_type = "default",
		fog_distance = -1, fog_start = 0.20, fog_color = "#16130f"},
	{density = 0, color = "#6a645ae5", ambient = "#000000",
		height = 120, thickness = 16, drift = -2.0, shadow = "#3a3630"})

grug_core.atmosphere_moods = MOODS

---------------------------------------------------------------------------
-- Region-relative cloud base (Round 22 D7, world_zones.md §7.6)
---------------------------------------------------------------------------

-- Terrain height differs per world, so a fixed cloud y per race mood can put
-- a capital inside its own clouds. Once the world authority exists, each race
-- mood's cloud base (set_clouds `height`, the y of the cloud bottom) is raised
-- to at least CLOUD_CLEARANCE above that capital's ground: the highest of the
-- capital anchor's own y and nine terrain samples across its 96 by 96 civic
-- core. A mood already high enough keeps its value, as does every mood if the
-- computation fails. Every other mood field is unchanged. Runs before any
-- player can join, so no player carries a stale copy of the preset.
local CLOUD_CLEARANCE = 60
local CIVIC_HALF = 48

-- Computes every new cloud base first and returns them; nothing is written,
-- so an error anywhere leaves all presets authored.
local function region_cloud_bases()
	local result = {}
	-- start_identities is the authority's six-race roster (race + faction).
	for _, row in ipairs(grug_core.start_identities()) do
		local anchor = grug_core.capital_anchor(row.faction_id, row.race_id)
		local preset = presets[row.race_id]
		if anchor and preset and MOODS[row.race_id] then
			local ground = anchor.y
			for dz = -CIVIC_HALF, CIVIC_HALF, CIVIC_HALF do
				for dx = -CIVIC_HALF, CIVIC_HALF, CIVIC_HALF do
					ground = math.max(ground,
						grug_zones.terrain_height_at(anchor.x + dx, anchor.z + dz))
				end
			end
			result[#result + 1] = {preset = preset, race = row.race_id,
				ground = ground,
				height = math.max(preset.clouds.height, ground + CLOUD_CLEARANCE)}
		end
	end
	return result
end

core.register_on_mods_loaded(function()
	if not grug_core.zone_authority_installed() then
		return
	end
	local ok, result = pcall(region_cloud_bases)
	if ok then
		local report = {}
		for _, row in ipairs(result) do
			report[#report + 1] = ("%s %d (capital ground %d, authored %d)"):
				format(row.race, row.height, row.ground, row.preset.clouds.height)
			row.preset.clouds.height = row.height
		end
		core.log("action", "[grug_core] region cloud base: " ..
			table.concat(report, ", "))
	else
		core.log("error", "[grug_core] region cloud base kept authored: " ..
			tostring(result))
	end
end)

---------------------------------------------------------------------------
-- Zone resolution
---------------------------------------------------------------------------

-- Sea level is y = 1 (minetest.conf water_level, mirrored in the authored
-- source as constants.water_level). The shallowest authored relief profile,
-- wetland_delta, is pinned at min_above_water = 2, so no authored DRY land
-- surface exists below y = 3. y < -20 is therefore at least 23 nodes under the
-- lowest possible ground and cannot be reached by walking; a player there is
-- inside rock, a cave or a mine. It is also well above the y = -37 line where
-- the authored broad fills start (world_zones.md §13.1), so the threshold
-- never argues with mapgen.
local UNDERGROUND_Y = -20

-- Deep ocean and the immutable dragon channels are full-column classes
-- (world_zones.md §13.2 territory precedence), so the ocean mood holds at every
-- depth there: id_at returns nil and we never reach the underground branch.

local DEFAULT_MOOD = grug_core.ATMOSPHERE_DEFAULT

-- Resolved once, the first time a query succeeds. grug_zones is installed by
-- grug_mapgen through grug_core.install_zone_authority (zone_authority.lua),
-- which runs after every CORE file has been loaded, so it cannot be captured
-- here at load time. The global is read only after the documented predicate
-- says it exists.
local zones_api

local function zone_api()
	if zones_api then
		return zones_api
	end
	if not grug_core.zone_authority_installed() then
		return nil
	end
	zones_api = grug_zones
	return zones_api
end

-- zone id -> mood name. At most 38 entries for the whole life of the server
-- (world_zones.md §8 has 38 zones), each filled by exactly one grug_zones.get
-- call the first time a player stands in that zone. Every later visit is a
-- table lookup.
local mood_by_zone = {}

local function classify(zones, zone_id)
	-- get() returns a defensive copy; this is the only allocating zone call in
	-- the package and it runs at most once per zone id, ever.
	local record = zones.get(zone_id)
	if not record then
		return DEFAULT_MOOD
	end
	-- The four mainland Battlegrounds are exactly the holy_grounds rule
	-- (world_zones.md §8.3); the token names the macro rectangle, not a
	-- protection right, which is why it is safe to read as "this is the front".
	if record.territory_rule == "holy_grounds" then
		return "battlegrounds"
	end
	-- The two dragon islands are the only 60/60 zones in the catalog
	-- (world_zones.md §8.3: every other contested band is 31-40, 41-50 or
	-- 51-59).
	if record.level_min == 60 and record.level_max == 60 then
		return "dragon_island"
	end
	if MOODS[record.race_region] then
		return record.race_region
	end
	return DEFAULT_MOOD
end

-- The mood a position should be showing, or nil when no zone authority exists
-- yet (in which case the player keeps whatever they have).
local function mood_key_at(pos)
	local zones = zone_api()
	if not zones then
		return nil
	end
	-- THE COST OF THIS PACKAGE, per evaluated player per 2 s: one id_at.
	-- id_at is the allocation-free hot point query of the public surface
	-- (world_zones.md §13.2); it normalises x/z, runs one
	-- classification_values_at and indexes the owner table
	-- (wp40/zones.lua:1122-1127). The same call is what grug_mobs' spawn
	-- policy already performs per spawn candidate
	-- (grug_mobs/spawn_policy.lua:138), at a far higher rate than this.
	local zone_id = zones.id_at(pos.x, pos.z)
	if not zone_id then
		return "ocean"
	end
	if pos.y < UNDERGROUND_Y then
		return "underground"
	end
	local key = mood_by_zone[zone_id]
	if not key then
		key = classify(zones, zone_id)
		mood_by_zone[zone_id] = key
	end
	return key
end

---------------------------------------------------------------------------
-- The driver
---------------------------------------------------------------------------

if not (grug_core.atmosphere_enabled and zones_enabled) then
	-- Presets stay registered so /atmosphere <mood> still works for a manual
	-- A/B test; nothing evaluates anything and the stubs in atmosphere.lua
	-- keep /atmosphere auto reporting the layer as unavailable.
	return
end

-- Player name -> stagger slot. Also the driver's roster: a name is in here
-- exactly while that player is online.
local slot_of = {}
-- Player name -> true while a manual preset holds. Absent means zone-driven.
local auto_off = {}
local join_counter = 0

-- SLOTS * SLOT_PERIOD is the per-player evaluation interval. Rather than one
-- timer per player, the step advances a slot counter and evaluates only the
-- players in the current slot, so the work of a 100-player server is spread
-- over eight steps instead of landing on one.
local SLOTS = 8
local SLOT_PERIOD = 0.25
local accumulator = 0
local current_slot = 0

local function evaluate(name)
	-- Re-fetched by name, never captured: this runs an arbitrary time after
	-- the join that put the name in the roster.
	local player = core.get_player_by_name(name)
	if not player then
		return
	end
	local key = mood_key_at(player:get_pos())
	if not key then
		return
	end
	-- set_atmosphere is the single send-on-change gate: it returns early
	-- without sending anything when the player already carries `key`, and
	-- otherwise sends exactly one lighting, one sky and one clouds packet.
	grug_core.set_atmosphere(player, key)
end

core.register_globalstep(function(dtime)
	accumulator = accumulator + dtime
	if accumulator < SLOT_PERIOD then
		return
	end
	-- Subtract rather than zero, so the average rate stays exact. A stall
	-- longer than one period collapses to a single tick instead of firing a
	-- burst of catch-up slots.
	accumulator = accumulator - SLOT_PERIOD
	if accumulator > SLOT_PERIOD then
		accumulator = 0
	end
	current_slot = current_slot % SLOTS + 1
	for name, slot in pairs(slot_of) do
		if slot == current_slot and not auto_off[name] then
			evaluate(name)
		end
	end
end)

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	join_counter = join_counter + 1
	slot_of[name] = join_counter % SLOTS + 1
	auto_off[name] = nil
	-- Evaluated immediately so nobody spends the first two seconds in the
	-- `default` preset atmosphere.lua's own join handler just applied. On a
	-- server whose zone authority is installed this replaces that packet set
	-- once; it is the only time two sets are sent close together.
	evaluate(name)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	slot_of[name] = nil
	auto_off[name] = nil
end)

---------------------------------------------------------------------------
-- /atmosphere seams (declared in atmosphere.lua)
---------------------------------------------------------------------------

function grug_core.atmosphere_manual_pause(name)
	auto_off[name] = true
end

function grug_core.atmosphere_resume_auto(name)
	auto_off[name] = nil
	local player = core.get_player_by_name(name)
	if not player then
		return "Atmosphere: auto (zone-driven) again."
	end
	local key = mood_key_at(player:get_pos())
	if not key then
		return "Atmosphere: auto (zone-driven) again; " ..
			"no zone authority is installed yet."
	end
	grug_core.set_atmosphere(player, key)
	return "Atmosphere: auto (zone-driven) - " .. key .. "."
end

function grug_core.atmosphere_mode(name)
	return auto_off[name] and "manual" or "auto"
end
