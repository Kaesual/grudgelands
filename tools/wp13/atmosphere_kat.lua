-- atmosphere_kat.lua -- engine-free smoke test for the grug_core atmosphere
-- layer and its zone-driven moods.
--
-- Loads mods/CORE/grug_core/atmosphere.lua and atmosphere_zones.lua against a
-- minimal `core` stub and a stub `grug_zones`, then asserts the package
-- contract:
--
--   1. every mood states EVERY lighting group, a full sky block (all seven
--      sky colours, both fog tints, the tint type and all three fog fields)
--      and a full cloud block -- the merge semantics in the two files require
--      it, and an omitted field silently inherits the previous mood;
--   2. every fog_color carries a non-zero alpha, or the client ignores the
--      override (reference_projects/luanti/src/client/sky.h:119-123);
--   3. walking a fake player across zone boundaries emits exactly one
--      lighting + sky + clouds set per mood change, and nothing at all while
--      the player stands still;
--   4. deep ocean (no owning zone) and y below the underground threshold
--      resolve to their own moods, and deep ocean keeps its mood at any depth;
--   5. a manual /atmosphere preset pauses the zone driver and /atmosphere auto
--      resumes it, re-applying the mood of the player's current position;
--   6. with grug_atmosphere_enabled = false nothing is ever sent, and with
--      grug_atmosphere_zones = false no globalstep is registered at all.
--
-- Run under both interpreters (from the repo root):
--     luajit          tools/wp13/atmosphere_kat.lua
--     tools/bin/lua51 tools/wp13/atmosphere_kat.lua
--
-- Exit status is 0 on success; any violation raises and aborts.

local MODPATH = "mods/CORE/grug_core"

---------------------------------------------------------------------------
-- tiny helpers
---------------------------------------------------------------------------

local violations = {}

local function check(ok, msg)
	if not ok then
		violations[#violations + 1] = msg
	end
	return ok
end

local function sorted_keys(t)
	local out = {}
	for k in pairs(t) do
		out[#out + 1] = k
	end
	table.sort(out)
	return out
end

---------------------------------------------------------------------------
-- the harness: one complete load of the two files against fresh stubs
---------------------------------------------------------------------------

-- A fake player. get_pos returns a fresh table like the engine does.
local function make_player(harness, name, x, y, z)
	local self = {x = x, y = y, z = z, name = name}
	function self.is_player()
		return true
	end
	function self.get_player_name()
		return name
	end
	function self.get_pos()
		return {x = self.x, y = self.y, z = self.z}
	end
	function self.set_lighting(_, value)
		harness.sent[#harness.sent + 1] = {name = name, kind = "lighting",
			value = value}
	end
	function self.set_sky(_, value)
		harness.sent[#harness.sent + 1] = {name = name, kind = "sky",
			value = value}
	end
	function self.set_clouds(_, value)
		harness.sent[#harness.sent + 1] = {name = name, kind = "clouds",
			value = value}
	end
	-- The mod calls these with `:`, so the first argument is the table itself;
	-- the closures above already ignore it.
	return self
end

-- zone id -> the record grug_zones.get returns. Only the three fields the
-- classifier reads matter, and they mirror the catalog rows quoted in
-- docs/design/world_zones.md §8.
local ZONE_RECORDS = {
	elandor_hearthpine_vale = {race_region = "dwarf",
		territory_rule = "accord_home", level_min = 1, level_max = 10},
	elandor_dawnmere_fields = {race_region = "human",
		territory_rule = "accord_home", level_min = 1, level_max = 10},
	elandor_silverleaf_glades = {race_region = "elf",
		territory_rule = "accord_home", level_min = 1, level_max = 10},
	kragmar_stillgrave_hollow = {race_region = "undead",
		territory_rule = "throng_home", level_min = 1, level_max = 10},
	kragmar_sunscar_flats = {race_region = "orc",
		territory_rule = "throng_home", level_min = 1, level_max = 10},
	kragmar_kapok_cradle = {race_region = "troll",
		territory_rule = "throng_home", level_min = 1, level_max = 10},
	front_shattered_line = {race_region = "orc",
		territory_rule = "holy_grounds", level_min = 41, level_max = 50},
	front_wyrmglass_crown = {race_region = "dwarf",
		territory_rule = "contested_land", level_min = 60, level_max = 60},
	front_stormscale_summit = {race_region = "troll",
		territory_rule = "contested_land", level_min = 60, level_max = 60},
}

-- A deliberately coarse fake world: the x coordinate picks the zone, and one
-- band has no owner at all (deep ocean / a dragon channel).
local ZONE_BY_BAND = {
	[0] = "elandor_hearthpine_vale",
	[1] = "elandor_dawnmere_fields",
	[2] = "elandor_silverleaf_glades",
	[3] = "kragmar_stillgrave_hollow",
	[4] = "kragmar_sunscar_flats",
	[5] = "kragmar_kapok_cradle",
	[6] = "front_shattered_line",
	[7] = "front_wyrmglass_crown",
	[8] = "front_stormscale_summit",
	[9] = false, -- deep ocean: id_at returns nil
}

local function load_harness(opts)
	opts = opts or {}
	local harness = {
		sent = {},
		globalsteps = {},
		joins = {},
		leaves = {},
		commands = {},
		players = {},
		logs = {},
		get_calls = 0,
		id_at_calls = 0,
	}

	local core_stub = {}
	core_stub.settings = {
		get_bool = function(_, key, fallback)
			if opts[key] ~= nil then
				return opts[key]
			end
			return fallback
		end,
		get = function()
			return nil
		end,
	}
	function core_stub.log(level, message)
		harness.logs[#harness.logs + 1] = tostring(level) .. ": " ..
			tostring(message)
	end
	function core_stub.register_globalstep(fn)
		harness.globalsteps[#harness.globalsteps + 1] = fn
	end
	function core_stub.register_on_joinplayer(fn)
		harness.joins[#harness.joins + 1] = fn
	end
	function core_stub.register_on_leaveplayer(fn)
		harness.leaves[#harness.leaves + 1] = fn
	end
	function core_stub.register_chatcommand(name, def)
		harness.commands[name] = def
	end
	function core_stub.get_player_by_name(name)
		return harness.players[name]
	end
	function core_stub.check_player_privs()
		return true
	end

	-- Zone stub. Counts every public query so the KAT can prove the cost claim
	-- of one id_at per evaluation and one get per zone id, ever.
	local zones_stub = {}
	function zones_stub.id_at(x, z)
		harness.id_at_calls = harness.id_at_calls + 1
		assert(type(x) == "number" and type(z) == "number",
			"id_at called with a non-number coordinate")
		local band = math.floor(x / 1000)
		local id = ZONE_BY_BAND[band]
		return id or nil
	end
	function zones_stub.get(zone_id)
		harness.get_calls = harness.get_calls + 1
		local record = ZONE_RECORDS[zone_id]
		if not record then
			return nil
		end
		-- A defensive copy, exactly like the real surface.
		return {race_region = record.race_region,
			territory_rule = record.territory_rule,
			level_min = record.level_min, level_max = record.level_max}
	end

	-- Install the globals the two files read, then load them in init.lua order.
	local saved_core, saved_minetest = core, minetest
	local saved_grug_core, saved_grug_zones = grug_core, grug_zones
	core = core_stub
	minetest = core_stub
	grug_core = {}
	grug_zones = zones_stub

	function grug_core.zone_authority_installed()
		return opts.authority ~= false
	end

	local ok, err = pcall(function()
		dofile(MODPATH .. "/atmosphere.lua")
		dofile(MODPATH .. "/atmosphere_zones.lua")
	end)

	harness.core = core_stub
	harness.grug_core = grug_core
	harness.zones = zones_stub

	core, minetest = saved_core, saved_minetest
	grug_core, grug_zones = saved_grug_core, saved_grug_zones

	if not ok then
		error(err, 0)
	end

	-- Convenience drivers.
	function harness.join(name, x, y, z)
		local player = make_player(harness, name, x, y, z)
		harness.players[name] = player
		-- Both globals must be live while a mod callback runs.
		local sc, sm, sg, sz = core, minetest, grug_core, grug_zones
		core, minetest = core_stub, core_stub
		grug_core, grug_zones = harness.grug_core, zones_stub
		for _, fn in ipairs(harness.joins) do
			fn(player)
		end
		core, minetest, grug_core, grug_zones = sc, sm, sg, sz
		return player
	end

	function harness.leave(name)
		local player = harness.players[name]
		local sc, sm, sg, sz = core, minetest, grug_core, grug_zones
		core, minetest = core_stub, core_stub
		grug_core, grug_zones = harness.grug_core, zones_stub
		for _, fn in ipairs(harness.leaves) do
			fn(player)
		end
		core, minetest, grug_core, grug_zones = sc, sm, sg, sz
		harness.players[name] = nil
	end

	-- Runs `steps` globalstep calls of `dtime` each.
	function harness.step(steps, dtime)
		local sc, sm, sg, sz = core, minetest, grug_core, grug_zones
		core, minetest = core_stub, core_stub
		grug_core, grug_zones = harness.grug_core, zones_stub
		for _ = 1, steps do
			for _, fn in ipairs(harness.globalsteps) do
				fn(dtime)
			end
		end
		core, minetest, grug_core, grug_zones = sc, sm, sg, sz
	end

	function harness.command(name, param)
		local def = harness.commands.atmosphere
		local sc, sm, sg, sz = core, minetest, grug_core, grug_zones
		core, minetest = core_stub, core_stub
		grug_core, grug_zones = harness.grug_core, zones_stub
		local success, message = def.func(name, param)
		core, minetest, grug_core, grug_zones = sc, sm, sg, sz
		return success, message
	end

	return harness
end

---------------------------------------------------------------------------
-- 1 + 2: shape of every mood
---------------------------------------------------------------------------

local base = load_harness()
local presets = base.grug_core.atmosphere_presets
local moods = base.grug_core.atmosphere_moods

local EXPECTED_MOODS = {
	"battlegrounds", "dragon_island", "dwarf", "elf", "human", "ocean",
	"orc", "troll", "underground", "undead",
}
do
	local have = sorted_keys(moods)
	local want = {}
	for i = 1, #EXPECTED_MOODS do
		want[i] = EXPECTED_MOODS[i]
	end
	table.sort(want)
	check(#have == #want, "mood count: " .. #have .. " (want " .. #want .. ")")
	for i = 1, math.max(#have, #want) do
		check(have[i] == want[i], "mood " .. i .. ": got " ..
			tostring(have[i]) .. ", want " .. tostring(want[i]))
	end
end

local SKY_COLORS = {"day_sky", "day_horizon", "dawn_sky", "dawn_horizon",
	"night_sky", "night_horizon", "indoors", "fog_sun_tint", "fog_moon_tint"}
local FOG_FIELDS = {"fog_distance", "fog_start", "fog_color"}
local CLOUD_FIELDS = {"density", "color", "ambient", "height", "thickness",
	"shadow"}

-- Parses a ColorSpec of the "#rrggbb" / "#rrggbbaa" form and returns its alpha.
local function colorspec_alpha(value)
	if type(value) ~= "string" then
		return nil
	end
	local body = value:match("^#(%x+)$")
	if not body then
		return nil
	end
	if #body == 6 or #body == 3 then
		return 255
	end
	if #body == 8 then
		return tonumber(body:sub(7, 8), 16)
	end
	if #body == 4 then
		return tonumber(body:sub(4, 4), 16) * 17
	end
	return nil
end

for _, name in ipairs(sorted_keys(moods)) do
	local preset = presets[name]
	local where = "mood " .. name
	if check(type(preset) == "table", where .. ": not registered as a preset") then
		check(type(preset.description) == "string",
			where .. ": no description")

		-- lighting: every group the engine merges
		local light = preset.lighting
		if check(type(light) == "table", where .. ": no lighting table") then
			check(type(light.shadows) == "table" and
				type(light.shadows.intensity) == "number",
				where .. ": shadows.intensity missing")
			local tint = light.shadows and light.shadows.tint
			check(type(tint) == "table" and type(tint.r) == "number" and
				type(tint.g) == "number" and type(tint.b) == "number",
				where .. ": shadows.tint incomplete")
			check(type(light.saturation) == "number",
				where .. ": saturation missing")
			local exposure = light.exposure
			if check(type(exposure) == "table", where .. ": exposure missing") then
				for _, field in ipairs({"luminance_min", "luminance_max",
						"exposure_correction", "speed_dark_bright",
						"speed_bright_dark"}) do
					check(type(exposure[field]) == "number",
						where .. ": exposure." .. field .. " missing")
				end
				check(exposure.center_weight_power == nil,
					where .. ": exposure.center_weight_power must stay unstated")
			end
			local bloom = light.bloom
			if check(type(bloom) == "table", where .. ": bloom missing") then
				for _, field in ipairs({"intensity", "strength_factor", "radius"}) do
					check(type(bloom[field]) == "number",
						where .. ": bloom." .. field .. " missing")
				end
			end
			check(type(light.volumetric_light) == "table" and
				type(light.volumetric_light.strength) == "number",
				where .. ": volumetric_light.strength missing")
			check(light.shadows == nil or light.shadows.direction == nil,
				where .. ": shadows.direction must stay unstated")
		end

		-- sky: type, clouds flag, all seven colours, both tints, tint type,
		-- all three fog fields
		local sky_table = preset.sky
		if check(type(sky_table) == "table", where .. ": no sky table") then
			check(sky_table.type == "regular",
				where .. ": sky.type is not \"regular\"")
			check(type(sky_table.clouds) == "boolean",
				where .. ": sky.clouds flag missing")
			local sky_color = sky_table.sky_color
			if check(type(sky_color) == "table",
					where .. ": sky.sky_color missing") then
				for _, field in ipairs(SKY_COLORS) do
					check(colorspec_alpha(sky_color[field]) ~= nil,
						where .. ": sky_color." .. field ..
						" missing or not a hex ColorSpec")
				end
				check(sky_color.fog_tint_type == "custom" or
					sky_color.fog_tint_type == "default",
					where .. ": sky_color.fog_tint_type missing")
			end
			local fog = sky_table.fog
			if check(type(fog) == "table", where .. ": sky.fog missing") then
				for _, field in ipairs(FOG_FIELDS) do
					check(fog[field] ~= nil,
						where .. ": fog." .. field .. " missing")
				end
				check(type(fog.fog_distance) == "number",
					where .. ": fog.fog_distance is not a number")
				check(type(fog.fog_start) == "number" and
					(fog.fog_start < 0 or (fog.fog_start >= 0 and
						fog.fog_start <= 0.99)),
					where .. ": fog.fog_start outside [0, 0.99] and not -1")
				-- An alpha of zero means "no override" on the client.
				local alpha = colorspec_alpha(fog.fog_color)
				check(alpha ~= nil and alpha > 0,
					where .. ": fog.fog_color needs a non-zero alpha")
			end
		end

		-- clouds: every merged field
		local cloud = preset.clouds
		if check(type(cloud) == "table", where .. ": no clouds table") then
			for _, field in ipairs(CLOUD_FIELDS) do
				check(cloud[field] ~= nil,
					where .. ": clouds." .. field .. " missing")
			end
			check(type(cloud.speed) == "table" and
				type(cloud.speed.x) == "number" and
				type(cloud.speed.z) == "number",
				where .. ": clouds.speed incomplete")
			check(colorspec_alpha(cloud.color) ~= nil,
				where .. ": clouds.color is not a hex ColorSpec")
		end
	end
end

-- The four shipped presets must be untouched by the zone package.
check(presets["default"] ~= nil and presets["default"].sky == nil,
	"shipped preset `default` grew a sky block")
check(presets["hearthpine"] ~= nil and presets["hearthpine"].sky == nil,
	"shipped preset `hearthpine` grew a sky block")
check(presets["godrays"] ~= nil and presets["godrays"].sky == nil,
	"shipped preset `godrays` grew a sky block")
check(presets["off"] ~= nil and presets["off"].lighting == nil,
	"shipped preset `off` is no longer a full reset")
check(presets["default"].lighting.saturation == 1.1,
	"shipped preset `default` saturation changed")
check(presets["godrays"].lighting.volumetric_light.strength == 0.45,
	"shipped preset `godrays` volumetric strength changed")

---------------------------------------------------------------------------
-- 3 + 4: walking across boundaries
---------------------------------------------------------------------------

-- Groups the recorded packets into "sets": one lighting + one sky + one clouds
-- from a single set_atmosphere call.
local function summarize(sent)
	local sets = {}
	local i = 1
	while i <= #sent do
		local lighting_packet = sent[i]
		assert(lighting_packet.kind == "lighting",
			"a set did not start with a lighting packet (got " ..
			lighting_packet.kind .. ")")
		local set = {name = lighting_packet.name, lighting = true}
		i = i + 1
		while i <= #sent and sent[i].kind ~= "lighting" do
			set[sent[i].kind] = true
			i = i + 1
		end
		sets[#sets + 1] = set
	end
	return sets
end

local function band_x(band)
	return band * 1000 + 500
end

do
	local h = load_harness()
	local hc = h.grug_core

	-- Join in the dwarf band. atmosphere.lua's join handler applies `default`
	-- (lighting only, no sky), then the zone driver applies `dwarf`.
	h.join("alice", band_x(0), 20, 0)
	local sets = summarize(h.sent)
	check(#sets == 2, "join: " .. #sets .. " set(s), want 2 (default + mood)")
	check(hc.get_atmosphere("alice") == "dwarf",
		"join: mood is " .. tostring(hc.get_atmosphere("alice")) ..
		", want dwarf")
	check(sets[2].sky and sets[2].clouds,
		"join: the mood set did not carry sky and clouds")

	-- Standing still: 40 steps of 0.25 s = 10 s = five full evaluation rounds.
	h.sent = {}
	local id_at_before = h.id_at_calls
	h.step(40, 0.25)
	check(#h.sent == 0, "stationary: " .. #h.sent .. " packet(s), want 0")
	check(h.id_at_calls - id_at_before == 5,
		"stationary: " .. (h.id_at_calls - id_at_before) ..
		" id_at call(s) in 10 s, want 5 (one per 2 s)")

	-- Walk band by band. Each move must produce exactly one set.
	local WALK = {
		{band = 1, mood = "human"},
		{band = 2, mood = "elf"},
		{band = 3, mood = "undead"},
		{band = 4, mood = "orc"},
		{band = 5, mood = "troll"},
		{band = 6, mood = "battlegrounds"},
		{band = 7, mood = "dragon_island"},
		{band = 8, mood = "dragon_island"}, -- the other 60/60 island: no change
		{band = 9, mood = "ocean"},
	}
	local expected_sets = 0
	local previous = "dragon_island"
	for _, leg in ipairs(WALK) do
		h.sent = {}
		h.players.alice.x = band_x(leg.band)
		h.step(8, 0.25) -- one full round: every slot fires once
		local legsets = summarize(h.sent)
		local want = 1
		if leg.mood == previous then
			want = 0
		end
		previous = leg.mood
		check(#legsets == want, "walk to band " .. leg.band .. " (" ..
			leg.mood .. "): " .. #legsets .. " set(s), want " .. want)
		if want == 1 then
			check(legsets[1].sky and legsets[1].clouds,
				"walk to band " .. leg.band .. ": set lacked sky or clouds")
		end
		check(hc.get_atmosphere("alice") == leg.mood,
			"walk to band " .. leg.band .. ": mood is " ..
			tostring(hc.get_atmosphere("alice")) .. ", want " .. leg.mood)
		expected_sets = expected_sets + want
	end
	check(expected_sets == 8,
		"walk: " .. expected_sets .. " change(s), want 8")

	-- Deep ocean keeps its mood at depth: no owning zone means no underground
	-- override, at any y.
	h.sent = {}
	h.players.alice.y = -300
	h.step(8, 0.25)
	check(#h.sent == 0, "diving in deep ocean sent " .. #h.sent ..
		" packet(s), want 0")
	check(hc.get_atmosphere("alice") == "ocean",
		"deep ocean at y=-300 is " .. tostring(hc.get_atmosphere("alice")))

	-- Underground overrides an owning zone's mood, and coming back up restores
	-- it. -20 is the threshold: -20 is still surface, -21 is underground.
	h.players.alice.x = band_x(1)
	h.players.alice.y = -20
	h.step(8, 0.25)
	check(hc.get_atmosphere("alice") == "human",
		"y = -20 is " .. tostring(hc.get_atmosphere("alice")) ..
		", want human (the threshold is exclusive)")
	h.sent = {}
	h.players.alice.y = -21
	h.step(8, 0.25)
	check(#summarize(h.sent) == 1, "descending past the threshold sent " ..
		#summarize(h.sent) .. " set(s), want 1")
	check(hc.get_atmosphere("alice") == "underground",
		"y = -21 is " .. tostring(hc.get_atmosphere("alice")) ..
		", want underground")
	h.sent = {}
	h.players.alice.y = 12
	h.step(8, 0.25)
	check(#summarize(h.sent) == 1, "surfacing sent " ..
		#summarize(h.sent) .. " set(s), want 1")
	check(hc.get_atmosphere("alice") == "human",
		"back at the surface: " .. tostring(hc.get_atmosphere("alice")))

	-- get() is consulted once per zone id, ever: bands 0-8 are the nine owned
	-- zones, band 9 has no owner, and the repeat visit to the human band costs
	-- nothing.
	check(h.get_calls == 9, "grug_zones.get called " .. h.get_calls ..
		" time(s), want 9 (once per distinct owned zone id)")

	-- Staggering: two players in different slots must not evaluate on the same
	-- step. Join order decides the slot, so consecutive joins differ.
	local hs = load_harness()
	hs.join("p1", band_x(0), 20, 0)
	hs.join("p2", band_x(0), 20, 0)
	hs.players.p1.x = band_x(4)
	hs.players.p2.x = band_x(4)
	local per_step = {}
	for step_index = 1, 8 do
		local before = #hs.sent
		hs.step(1, 0.25)
		per_step[step_index] = #hs.sent - before
	end
	local busy = 0
	for _, count in ipairs(per_step) do
		if count > 0 then
			busy = busy + 1
		end
	end
	check(busy == 2, "stagger: the two players changed on " .. busy ..
		" distinct step(s), want 2")

	-- Nothing is logged per step.
	check(#h.logs == 0, "the driver logged " .. #h.logs ..
		" message(s); it must log nothing")
end

---------------------------------------------------------------------------
-- 5: manual pause and /atmosphere auto
---------------------------------------------------------------------------

do
	local h = load_harness()
	local hc = h.grug_core
	h.join("bob", band_x(1), 20, 0) -- human
	check(hc.atmosphere_mode("bob") == "auto",
		"a fresh player is in " .. hc.atmosphere_mode("bob") .. " mode")

	-- A manual preset pauses the driver.
	local ok, message = h.command("bob", "godrays")
	check(ok, "/atmosphere godrays failed: " .. tostring(message))
	check(hc.get_atmosphere("bob") == "godrays",
		"manual preset did not apply")
	check(hc.atmosphere_mode("bob") == "manual",
		"a manual preset left the player in auto mode")

	-- Moving while paused changes nothing.
	h.sent = {}
	h.players.bob.x = band_x(4) -- orc band
	h.step(16, 0.25)
	check(#h.sent == 0, "paused player sent " .. #h.sent ..
		" packet(s) after moving, want 0")
	check(hc.get_atmosphere("bob") == "godrays",
		"paused player drifted to " .. tostring(hc.get_atmosphere("bob")))

	-- `auto` resumes and immediately applies the mood of where they stand.
	h.sent = {}
	ok, message = h.command("bob", "auto")
	check(ok, "/atmosphere auto failed: " .. tostring(message))
	check(hc.atmosphere_mode("bob") == "auto",
		"`auto` did not clear the manual pause")
	check(hc.get_atmosphere("bob") == "orc",
		"`auto` applied " .. tostring(hc.get_atmosphere("bob")) ..
		", want orc (the band the player is standing in)")
	check(#summarize(h.sent) == 1, "`auto` sent " .. #summarize(h.sent) ..
		" set(s), want 1")

	-- And the driver is live again.
	h.sent = {}
	h.players.bob.x = band_x(5) -- troll band
	h.step(8, 0.25)
	check(hc.get_atmosphere("bob") == "troll",
		"after `auto` the driver did not resume")

	-- `auto` is not shadowed by a preset of the same name.
	check(presets["auto"] == nil, "a preset named `auto` would shadow the mode")

	-- Leaving clears the roster: no further evaluation for that name.
	h.leave("bob")
	h.sent = {}
	h.step(16, 0.25)
	check(#h.sent == 0, "a departed player still received " .. #h.sent ..
		" packet(s)")
end

---------------------------------------------------------------------------
-- 6: the off switches
---------------------------------------------------------------------------

do
	local h = load_harness({grug_atmosphere_enabled = false})
	h.join("carol", band_x(1), 20, 0)
	h.step(40, 0.25)
	check(#h.sent == 0, "with grug_atmosphere_enabled = false, " .. #h.sent ..
		" packet(s) were sent, want 0")
	check(#h.globalsteps == 0,
		"with grug_atmosphere_enabled = false, " .. #h.globalsteps ..
		" globalstep(s) were registered, want 0")
	local ok, message = h.command("carol", "dwarf")
	check(not ok, "the master switch did not refuse /atmosphere dwarf")
	ok, message = h.command("carol", "auto")
	check(not ok, "the master switch did not refuse /atmosphere auto: " ..
		tostring(message))
end

do
	local h = load_harness({grug_atmosphere_zones = false})
	h.join("dave", band_x(1), 20, 0)
	h.step(40, 0.25)
	check(#h.globalsteps == 0,
		"with grug_atmosphere_zones = false, " .. #h.globalsteps ..
		" globalstep(s) were registered, want 0")
	-- Only the join preset from atmosphere.lua, and no zone evaluation.
	check(#summarize(h.sent) == 1, "with the zone layer off, join sent " ..
		#summarize(h.sent) .. " set(s), want 1 (the shipped default)")
	check(h.grug_core.get_atmosphere("dave") == "default",
		"with the zone layer off, the player is on " ..
		tostring(h.grug_core.get_atmosphere("dave")))
	check(h.id_at_calls == 0, "with the zone layer off, id_at was called " ..
		h.id_at_calls .. " time(s), want 0")
	-- The moods stay available as manual presets.
	check(h.grug_core.atmosphere_presets["undead"] ~= nil,
		"with the zone layer off, the moods vanished as manual presets")
	local ok = h.command("dave", "undead")
	check(ok, "with the zone layer off, /atmosphere undead was refused")
	local auto_ok, auto_message = h.command("dave", "auto")
	check(not auto_ok, "with the zone layer off, /atmosphere auto succeeded: " ..
		tostring(auto_message))
end

-- No zone authority installed yet: the driver must not crash and must leave
-- the player on the shipped default.
do
	local h = load_harness({authority = false})
	h.join("erin", band_x(1), 20, 0)
	h.step(40, 0.25)
	check(h.grug_core.get_atmosphere("erin") == "default",
		"without a zone authority the player is on " ..
		tostring(h.grug_core.get_atmosphere("erin")))
	check(h.id_at_calls == 0,
		"without a zone authority id_at was called " .. h.id_at_calls ..
		" time(s), want 0")
end

---------------------------------------------------------------------------
-- report
---------------------------------------------------------------------------

print("grug_core atmosphere KAT")
print(string.format("  interpreter        : %s", _VERSION ..
	(type(jit) == "table" and " / " .. jit.version or "")))
print(string.format("  presets total      : %d", #sorted_keys(presets)))
print(string.format("  zone moods         : %d", #sorted_keys(moods)))
for _, name in ipairs(sorted_keys(moods)) do
	local fog = presets[name].sky.fog
	print(string.format("    %-14s fog %s at %s, start %.2f, saturation %.2f",
		name, fog.fog_color,
		fog.fog_distance < 0 and "client range" or
			(tostring(fog.fog_distance) .. " nodes"),
		fog.fog_start, presets[name].lighting.saturation))
end

if #violations > 0 then
	print("FAILURES:")
	for _, v in ipairs(violations) do
		print("  " .. v)
	end
	error(#violations .. " contract violation(s)", 0)
end

print("OK")
