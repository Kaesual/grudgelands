-- Disposable Round 37 lane PO probe (per-player polling). Never shipped,
-- staged only into a throwaway game copy by tools/luanti_headless.sh (PROBE=)
-- through tools/r37_po/engine.sh.
--
-- The Round 32 performance study's scale probe (docs/research/
-- perf-review-2026-10-r32.md section 1, its "crowd" scenario) with the same
-- stand-in counts: fake player stand-ins (Lua tables answering the ObjectRef
-- methods the game calls) join through the real join chain beside the Accord
-- human start, walk, half of them "fight" (a nearby mob is told to attack),
-- one in ten keeps the Map tab open and parties of five form. Phases: idle
-- (0), 50 and 100 walking, then the 100 standing still (r37po_still_s). Each
-- stand-in carries the same twelve stacks (the study's stand-ins carried
-- nothing).
--
-- Measured per phase: every globalstep (ms/s per callback: the minimap
-- grug_map/minimap.lua, the quest tracker grug_quests/hud.lua, the discovery
-- pass grug_jobs/discovery.lua, the weapon hint grug_inventory/equipment.lua)
-- and the quest-marker recomputes (fn Q.marker_states). Then micro benchmarks:
-- one Claim Stone placement check at a spot whose 101 x 101 scan passes and
-- whose cube is blocked (the held right-click case), first and repeated; a
-- discovery scan; the tracker key; the marker memo.
-- Every line carries "[r37po]"; "MARK <name>" lines mark the phases.

local P = "[r37po] "
local function log(s) core.log("action", P .. s) end
local function mark(name) core.log("action", P .. "MARK " .. name) end
local now = core.get_us_time
local NF1 = tonumber(core.settings:get("r37po_fakes1") or "") or 50
local NF2 = tonumber(core.settings:get("r37po_fakes2") or "") or 100
local IDLE_S = tonumber(core.settings:get("r37po_idle_s") or "") or 20
local SETTLE_S = tonumber(core.settings:get("r37po_settle_s") or "") or 10
local RUN_S = tonumber(core.settings:get("r37po_run_s") or "") or 40
local SKIP_MICRO = core.settings:get_bool("r37po_skip_micro", false)
-- The last phase: every stand-in stands still (no walking, no fights).
local STILL_S = tonumber(core.settings:get("r37po_still_s") or "") or 30
local still = false

---------------------------------------------------------------------------
-- Fake players
---------------------------------------------------------------------------
local fakes, fake_list, fake_tables = {}, {}, {}
local orig_gcp = core.get_connected_players
local orig_gpbn = core.get_player_by_name
core.get_connected_players = function()
	local real = orig_gcp()
	if #fake_list == 0 then return real end
	local out = {}
	for i = 1, #real do out[i] = real[i] end
	for i = 1, #fake_list do out[#out + 1] = fake_list[i] end
	return out
end
core.get_player_by_name = function(name) return fakes[name] or orig_gpbn(name) end
local orig_gpwi = core.get_player_window_information
core.get_player_window_information = function(name)
	if fakes[name] then
		return {size = {x = 1920, y = 1080}, max_formspec_size = {x = 20, y = 11.25},
			real_gui_scaling = 1, real_hud_scaling = 1}
	end
	return orig_gpwi(name)
end
local orig_gpi = core.get_player_information
core.get_player_information = function(name)
	if fakes[name] then
		return {address = "127.0.0.1", ip_version = 4, connection_uptime = 100,
			protocol_version = 48, formspec_version = 8, lang_code = "",
			min_rtt = 0.01, max_rtt = 0.05, avg_rtt = 0.02, min_jitter = 0,
			max_jitter = 0, avg_jitter = 0, version_string = "5.15.0"}
	end
	return orig_gpi(name)
end

-- traffic: per phase totals, and a sampled call-site attribution
local traffic = {hud_n = 0, hud_bytes = 0, hud_same = 0, fs_n = 0, fs_bytes = 0,
	fs_same = 0, show_n = 0, show_bytes = 0, props_n = 0}
local hud_sites, fs_sites = {}, {}
local site_tick = 0
local function site(level)
	local info = debug.getinfo(level, "Sl")
	if not info then return "?" end
	return (info.short_src or "?"):gsub("^.*/mods/", "") .. ":" .. (info.currentline or 0)
end
local function grug_site()
	for level = 3, 10 do
		local info = debug.getinfo(level, "Sl")
		if not info then break end
		local src = info.short_src or ""
		if not src:find("sfinv", 1, true) and not src:find("grug_probe_r37_po", 1, true) and src ~= "[C]" then
			return src:gsub("^.*/mods/", "") .. ":" .. (info.currentline or 0)
		end
	end
	return "?"
end
local function vkey(v)
	if type(v) == "table" then
		return ("%s,%s,%s"):format(tostring(v.x), tostring(v.y), tostring(v.z))
	end
	return tostring(v)
end
local function vbytes(v)
	if type(v) == "string" then return 2 + #v end
	if type(v) == "table" then return 8 end
	return 4
end

local function new_meta(store)
	local m = {}
	function m:get_string(k) return store[k] or "" end
	function m:set_string(k, v)
		v = tostring(v or "")
		store[k] = v ~= "" and v or nil
	end
	function m:get(k) return store[k] end
	function m:get_int(k) return math.floor(tonumber(store[k]) or 0) end
	function m:set_int(k, v) store[k] = tostring(math.floor(v)) end
	function m:get_float(k) return tonumber(store[k]) or 0 end
	function m:set_float(k, v) store[k] = tostring(v) end
	function m:contains(k) return store[k] ~= nil end
	function m:get_keys() local r = {} for k in pairs(store) do r[#r + 1] = k end return r end
	function m:to_table() return {fields = table.copy(store)} end
	function m:from_table(t)
		for k in pairs(store) do store[k] = nil end
		for k, v in pairs(t and t.fields or {}) do store[k] = tostring(v) end
		return true
	end
	function m:equals(o) return o == m end
	function m:mark_as_private() end
	return m
end

local missing = {}
local FM = {} -- fake methods
function FM:is_player() return true end
function FM:is_valid() return true end
function FM:get_player_name() return self._name end
function FM:get_pos() return {x = self._pos.x, y = self._pos.y, z = self._pos.z} end
function FM:set_pos(v) self._pos = vector.copy(v) end
function FM:move_to(v) self._pos = vector.copy(v) end
function FM:get_velocity() return vector.zero() end
function FM:add_velocity() end
function FM:get_acceleration() return vector.zero() end
function FM:get_look_horizontal() return self._yaw end
function FM:get_look_yaw() return self._yaw end
function FM:get_look_vertical() return self._pitch end
function FM:get_look_pitch() return self._pitch end
function FM:set_look_horizontal(v) self._yaw = v end
function FM:set_look_vertical(v) self._pitch = v end
function FM:get_yaw() return self._yaw end
function FM:get_rotation() return vector.new(0, self._yaw, 0) end
function FM:set_rotation() end
function FM:get_look_dir()
	local c = math.cos(self._pitch)
	return vector.new(-math.sin(self._yaw) * c, -math.sin(self._pitch), math.cos(self._yaw) * c)
end
function FM:get_hp() return self._hp end
function FM:set_hp(hp)
	self._hp = math.max(1, math.min(self._props.hp_max or 20, math.floor(hp)))
end
function FM:get_breath() return self._breath end
function FM:set_breath(v) self._breath = v end
function FM:get_properties() return table.copy(self._props) end
function FM:set_properties(t)
	traffic.props_n = traffic.props_n + 1
	for k, v in pairs(t or {}) do self._props[k] = v end
end
function FM:get_meta() return self._meta end
function FM:get_inventory() return self._inv end
function FM:get_wield_index() return self._wield end
function FM:get_wield_list() return "main" end
function FM:get_wielded_item() return self._inv:get_stack("main", self._wield) end
function FM:set_wielded_item(s) self._inv:set_stack("main", self._wield, s) return true end
local NO_CONTROL = {up = false, down = false, left = false, right = false, jump = false,
	aux1 = false, sneak = false, dig = false, place = false, LMB = false,
	RMB = false, zoom = false, movement_x = 0, movement_y = 0}
function FM:get_player_control()
	local c = table.copy(NO_CONTROL)
	if self._walking then c.up = true; c.movement_y = 1 end
	return c
end
function FM:get_player_control_bits() return self._walking and 1 or 0 end
function FM:get_armor_groups() return table.copy(self._armor) end
function FM:set_armor_groups(t) self._armor = table.copy(t) end
function FM:get_physics_override() return table.copy(self._physics) end
function FM:set_physics_override(t) for k, v in pairs(t or {}) do self._physics[k] = v end end
function FM:get_attach() return nil end
function FM:get_children() return {} end
function FM:set_attach() end
function FM:set_detach() end
function FM:get_luaentity() return nil end
function FM:get_entity_name() return nil end
function FM:punch() end
function FM:right_click() end
function FM:remove() end
function FM:get_eye_offset() return vector.copy(self._eye1), vector.copy(self._eye3), vector.copy(self._eye3) end
function FM:set_eye_offset(a, b) self._eye1 = a and vector.copy(a) or vector.zero(); self._eye3 = b and vector.copy(b) or vector.zero() end
function FM:get_flags() return table.copy(self._flags) end
function FM:set_flags(t) for k, v in pairs(t or {}) do self._flags[k] = v end end
function FM:hud_get_flags() return table.copy(self._hudflags) end
function FM:hud_set_flags(t) for k, v in pairs(t or {}) do self._hudflags[k] = v end end
function FM:hud_set_hotbar_itemcount() end
function FM:hud_get_hotbar_itemcount() return 8 end
function FM:hud_set_hotbar_image() end
function FM:hud_get_hotbar_image() return "" end
function FM:hud_set_hotbar_selected_image() end
function FM:hud_get_hotbar_selected_image() return "" end
function FM:set_minimap_modes() end
function FM:set_sky(t) self._sky = t or {} end
function FM:get_sky() return self._sky end
function FM:get_sky_color() return {} end
function FM:set_sun() end
function FM:get_sun() return {} end
function FM:set_moon() end
function FM:get_moon() return {} end
function FM:set_stars() end
function FM:get_stars() return {} end
function FM:set_clouds() end
function FM:get_clouds() return {} end
function FM:set_lighting(t) self._lighting = t or {} end
function FM:get_lighting() return self._lighting end
function FM:override_day_night_ratio() end
function FM:get_day_night_ratio() return nil end
function FM:set_nametag_attributes(t) for k, v in pairs(t or {}) do self._nametag[k] = v end end
function FM:get_nametag_attributes() return table.copy(self._nametag) end
function FM:set_animation(range, speed, blend, loop) self._anim = {range = range, speed = speed, blend = blend, loop = loop} end
function FM:get_animation() local a = self._anim return a.range, a.speed, a.blend, a.loop end
function FM:set_local_animation() end
function FM:get_local_animation() return {x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}, 30 end
function FM:set_animation_frame_speed() end
function FM:set_bone_position() end
function FM:set_bone_override() end
function FM:get_bone_override() return {} end
function FM:get_bone_position() return vector.zero(), vector.zero() end
function FM:set_fov() end
function FM:get_fov() return 0, false, 0 end
function FM:set_observers() end
function FM:get_observers() return nil end
function FM:get_effective_observers() return nil end
function FM:send_mapblock() return false end
function FM:set_formspec_prepend(s) self._prepend = s end
function FM:get_formspec_prepend() return self._prepend end
function FM:get_inventory_formspec() return self._formspec end
function FM:set_inventory_formspec(fs)
	traffic.fs_n = traffic.fs_n + 1
	traffic.fs_bytes = traffic.fs_bytes + #fs
	self._fs_bytes = self._fs_bytes + #fs
	if fs == self._formspec then traffic.fs_same = traffic.fs_same + 1 end
	local key = grug_site()
	local r = fs_sites[key] or {n = 0, bytes = 0}
	fs_sites[key] = r
	r.n, r.bytes = r.n + 1, r.bytes + #fs
	self._formspec = fs
end
function FM:respawn() end
function FM:get_player_velocity() return vector.zero() end
function FM:get_camera() return {mode = "any"} end
function FM:set_camera() end
function FM:hud_add(def)
	self._next_hud = self._next_hud + 1
	local id = self._next_hud
	local rec = {}
	for k, v in pairs(def or {}) do rec[k] = vkey(v) end
	self._huds[id] = {last = rec}
	traffic.hud_n = traffic.hud_n + 1
	traffic.hud_bytes = traffic.hud_bytes + 60
	self._hud_bytes = self._hud_bytes + 60
	return id
end
function FM:hud_change(id, stat, value)
	local rec = self._huds[id]
	local k = vkey(value)
	local bytes = 18 + vbytes(value)
	traffic.hud_n = traffic.hud_n + 1
	traffic.hud_bytes = traffic.hud_bytes + bytes
	self._hud_bytes = self._hud_bytes + bytes
	if rec and rec.last[stat] == k then traffic.hud_same = traffic.hud_same + 1 end
	if rec then rec.last[stat] = k end
	site_tick = site_tick + 1
	if site_tick % 16 == 0 then
		local s = site(3)
		local r = hud_sites[s] or {n = 0, bytes = 0}
		hud_sites[s] = r
		r.n, r.bytes = r.n + 16, r.bytes + 16 * bytes
	end
end
function FM:hud_remove(id) self._huds[id] = nil; traffic.hud_n = traffic.hud_n + 1 end
function FM:hud_get(id) return nil end
function FM:hud_get_all() return {} end
local FMT = {__index = function(_, key)
	local fn = FM[key]
	if fn then return fn end
	if type(key) ~= "string" or not (key:match("^get_") or key:match("^set_") or
			key:match("^hud_") or key:match("^is_") or key:match("^add_") or
			key:match("^send_") or key:match("^override_")) then
		return nil
	end
	return function()
		if not missing[key] then missing[key] = site(3) end
		return nil
	end
end}

-- What every stand-in carries (the same in every run).
local CARRIED = {"default:dirt 40", "default:cobble 60", "default:tree 7", "default:wood 20",
	"default:stick 9", "default:torch 12", "grug_food:raw_meat 3", "default:coal_lump 5",
	"default:apple 4", "default:sand 15", "default:gravel 8", "default:pine_tree 2"}
local function make_fake(name, pos, yaw)
	local inv = core.create_detached_inventory("r37po_" .. name, {}, name)
	inv:set_size("main", 32)
	inv:set_size("craft", 9)
	inv:set_size("craftpreview", 1)
	inv:set_size("craftresult", 1)
	inv:set_size("hand", 1)
	inv:set_width("craft", 3)
	for i, item in ipairs(CARRIED) do
		if core.registered_items[item:match("^(%S+)")] then inv:set_stack("main", i + 1, item) end
	end
	local store = {}
	local p = setmetatable({_name = name, _pos = vector.copy(pos), _yaw = yaw or 0, _pitch = -0.1,
		_hp = 20, _breath = 10, _inv = inv, _meta = new_meta(store), _store = store,
		_huds = {}, _next_hud = 0, _wield = 1, _formspec = "", _prepend = "",
		_hud_bytes = 0, _fs_bytes = 0,
		_armor = {fleshy = 100}, _physics = {speed = 1, jump = 1, gravity = 1},
		_props = {hp_max = 20, breath_max = 10, eye_height = 1.625,
			collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
			selectionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
			visual = "mesh", mesh = "character.b3d", textures = {"character.png"},
			visual_size = {x = 1, y = 1}, stepheight = 0.6, nametag = ""},
		_flags = {breathing = true, drowning = true, node_damage = true},
		_hudflags = {hotbar = true, healthbar = true, crosshair = true,
			wielditem = true, breathbar = true, minimap = false, minimap_radar = false,
			basic_debug = false, chat = true},
		_nametag = {color = {a = 255, r = 255, g = 255, b = 255}, text = ""},
		_lighting = {}, _sky = {}, _anim = {range = {x = 0, y = 0}, speed = 0, blend = 0, loop = true},
		_eye1 = vector.zero(), _eye3 = vector.zero(),
	}, FMT)
	fake_tables[p] = true
	return p
end

---------------------------------------------------------------------------
-- Instrumentation
---------------------------------------------------------------------------
local stats = {}          -- key -> {us, n, max}
local recording = false
local step_lua, step_obj = 0, 0
local steps = {}
local last_marker
local function acc(key, dt)
	local s = stats[key]
	if not s then s = {us = 0, n = 0, max = 0}; stats[key] = s end
	s.us = s.us + dt
	s.n = s.n + 1
	if dt > s.max then s.max = dt end
end

local calls = {}
local function count_wrap(tab, field, label)
	local orig = tab[field]
	if type(orig) ~= "function" then return end
	local r = {n = 0, us = 0}
	calls[label] = r
	tab[field] = function(...)
		if not recording then return orig(...) end
		local t = now()
		local a, b, c, d = orig(...)
		r.n = r.n + 1
		r.us = r.us + (now() - t)
		return a, b, c, d
	end
end

local function wrap_fn(tab, field, key)
	if type(tab) ~= "table" or type(tab[field]) ~= "function" then
		log("no function to wrap: " .. key)
		return
	end
	local orig = tab[field]
	tab[field] = function(...)
		if not recording then return orig(...) end
		local t = now()
		local a, b, c, d = orig(...)
		acc(key, now() - t)
		return a, b, c, d
	end
end

local function key_of(fn, prefix)
	local info = debug.getinfo(fn, "S")
	return prefix .. ((info.short_src or "?"):gsub("^.*/mods/", ""):gsub("^.*/builtin/", "builtin/")) ..
		":" .. (info.linedefined or 0)
end

local function wrap_globalsteps()
	local list = core.registered_globalsteps
	local n = 0
	for i = 1, #list do
		local fn = list[i]
		local key = key_of(fn, "gs ")
		if not key:find("grug_probe_r37_po", 1, true) then
			n = n + 1
			list[i] = function(dtime)
				local t = now()
				local ok, err = pcall(fn, dtime)
				local d = now() - t
				step_lua = step_lua + d
				if recording then acc(key, d) end
				if not ok then
					local e = "gserr " .. key
					if not stats[e] then log("GSERR " .. key .. " " .. tostring(err):sub(1, 400)) end
					acc(e, 0)
				end
			end
		end
	end
	-- the step marker FIRST: closes the previous server step
	table.insert(list, 1, function(dtime)
		local t = now()
		if recording then
			steps[#steps + 1] = {lua = step_lua + step_obj, obj = step_obj,
				wall = last_marker and (t - last_marker) or 0, dtime = dtime}
		end
		last_marker = t
		step_lua, step_obj = 0, 0
	end)
	log("wrapped globalsteps: " .. n)
end

local ent_errs = {}
local function wrap_entities()
	local n = 0
	for ename, def in pairs(core.registered_entities) do
		for _, field in ipairs({"on_step", "on_activate", "get_staticdata"}) do
			local fn = def[field]
			if type(fn) == "function" then
				local key = (field == "on_step" and "ent " or field .. " ") .. ename
				def[field] = function(self, ...)
					local t = now()
					local ok, a, b = pcall(fn, self, ...)
					local d = now() - t
					step_obj = step_obj + d
					if recording then acc(key, d) end
					if not ok then
						if not ent_errs[key] then
							ent_errs[key] = true
							log("ENTERR " .. key .. " " .. tostring(a):sub(1, 300))
						end
						return nil
					end
					return a, b
				end
				n = n + 1
			end
		end
	end
	log("wrapped entity callbacks: " .. n)
end

local function wrap_abms_lbms_timers()
	for i, abm in ipairs(core.registered_abms) do
		local f = abm.action
		local key = "abm " .. tostring(abm.label or i)
		abm.action = function(...)
			local t = now()
			local r = f(...)
			local d = now() - t
			step_obj = step_obj + d
			if recording then acc(key, d) end
			return r
		end
	end
	for _, lbm in ipairs(core.registered_lbms or {}) do
		local f = lbm.action or lbm.bulk_action
		local field = lbm.action and "action" or "bulk_action"
		local key = "lbm " .. tostring(lbm.name)
		lbm[field] = function(...)
			local t = now()
			local r = f(...)
			local d = now() - t
			step_obj = step_obj + d
			if recording then acc(key, d) end
			return r
		end
	end
	local nt = 0
	for name, def in pairs(core.registered_nodes) do
		if type(def.on_timer) == "function" then
			local f = def.on_timer
			local key = "timer " .. name
			rawset(def, "on_timer", function(...)
				local t = now()
				local r = f(...)
				local d = now() - t
				step_obj = step_obj + d
				if recording then acc(key, d) end
				return r
			end)
			nt = nt + 1
		end
	end
	log(("wrapped %d abms, %d lbms, %d node timers"):format(#core.registered_abms,
		#(core.registered_lbms or {}), nt))
end

local function pct(sorted, p)
	if #sorted == 0 then return 0 end
	local i = math.max(1, math.min(#sorted, math.ceil(#sorted * p)))
	return sorted[i]
end
local function dist(values)
	local s, sum = {}, 0
	for i = 1, #values do s[i] = values[i]; sum = sum + values[i] end
	table.sort(s)
	return ("n=%d mean=%.0f p50=%.0f p95=%.0f p99=%.0f max=%.0f"):format(#s,
		#s > 0 and sum / #s or 0, pct(s, 0.5), pct(s, 0.95), pct(s, 0.99), s[#s] or 0)
end

local function object_census()
	local by, total, mobs_n = {}, 0, 0
	for _, obj in pairs(core.objects_by_guid or core.luaentities or {}) do
		local ent = obj.get_luaentity and obj:get_luaentity() or obj
		local name = ent and ent.name or "?"
		by[name] = (by[name] or 0) + 1
		total = total + 1
		if ent and ent._cmi_is_mob then mobs_n = mobs_n + 1 end
	end
	local rows = {}
	for k, v in pairs(by) do rows[#rows + 1] = {k, v} end
	table.sort(rows, function(a, b) return a[2] > b[2] end)
	local parts = {}
	for i = 1, math.min(18, #rows) do parts[#parts + 1] = rows[i][1] .. "=" .. rows[i][2] end
	return total, mobs_n, table.concat(parts, " ")
end

local phase_t0, heap_max, heap_min
local function begin_phase()
	stats, steps = {}, {}
	for _, r in pairs(calls) do r.n, r.us = 0, 0 end
	traffic = {hud_n = 0, hud_bytes = 0, hud_same = 0, fs_n = 0, fs_bytes = 0,
		fs_same = 0, show_n = 0, show_bytes = 0, props_n = 0}
	hud_sites, fs_sites = {}, {}
	for _, p in ipairs(fake_list) do p._hud_bytes, p._fs_bytes = 0, 0 end
	heap_max, heap_min = 0, math.huge
	recording = true
	phase_t0 = now()
end

local function end_phase(name)
	recording = false
	local seconds = (now() - phase_t0) / 1e6
	local np = #fake_list
	local total, mobs_n, census = object_census()
	log(("==== PHASE %s: %.1f s, %d fakes, objects %d, mobs %d (active count %s), heap %.1f..%.1f MiB"):format(
		name, seconds, np, total, mobs_n, tostring(mobs and mobs.get_active_mob_count and
		mobs:get_active_mob_count() or "?"), heap_min / 1024, heap_max / 1024))
	log(name .. " objects: " .. census)
	local lua, wall, obj = {}, {}, {}
	local over50, over100, lua_sum = 0, 0, 0
	for i = 1, #steps do
		local r = steps[i]
		lua[i], wall[i], obj[i] = r.lua, r.wall, r.obj
		lua_sum = lua_sum + r.lua
		if r.wall > 50000 then over50 = over50 + 1 end
		if r.wall > 100000 then over100 = over100 + 1 end
	end
	log(("%s STEP lua    %s us"):format(name, dist(lua)))
	log(("%s STEP objabm %s us"):format(name, dist(obj)))
	log(("%s STEP wall   %s us; wall>50ms %d, >100ms %d"):format(name, dist(wall), over50, over100))
	log(("%s LUA total %.2f ms/s (%.1f %% of wall)"):format(name, lua_sum / seconds / 1000,
		lua_sum / (seconds * 1e6) * 100))
	local rows, sums = {}, {gs = 0, ent = 0, abm = 0, timer = 0, other = 0}
	for key, s in pairs(stats) do
		rows[#rows + 1] = {key = key, s = s}
		local cls = key:match("^(%S+)")
		if cls == "gs" then sums.gs = sums.gs + s.us
		elseif cls == "ent" then sums.ent = sums.ent + s.us
		elseif cls == "abm" then sums.abm = sums.abm + s.us
		elseif cls == "timer" then sums.timer = sums.timer + s.us
		elseif cls ~= "fn" then sums.other = sums.other + s.us end
	end
	log(("%s SHARE globalsteps %.2f ms/s, entity on_step %.2f, abm %.2f, node timers %.2f, activate/staticdata/lbm %.2f"):format(
		name, sums.gs / seconds / 1000, sums.ent / seconds / 1000, sums.abm / seconds / 1000,
		sums.timer / seconds / 1000, sums.other / seconds / 1000))
	table.sort(rows, function(a, b) return a.s.us > b.s.us end)
	for i = 1, math.min(60, #rows) do
		local r = rows[i]
		log(("%s CB %-62s %9.1f us/s n=%7d avg=%8.1f max=%7d"):format(name, r.key,
			r.s.us / seconds, r.s.n, r.s.us / math.max(1, r.s.n), r.s.max))
	end
	for label, r in pairs(calls) do
		if r.n > 0 then
			log(("%s CALL %-28s n=%7d (%.1f/s) total %.1f ms/s avg %.2f us"):format(name, label, r.n,
				r.n / seconds, r.us / seconds / 1000, r.us / r.n))
		end
	end
	local per = math.max(1, np)
	log(("%s NET hud n=%d (%.1f/s/player) %.0f B/s/player identical=%d; inv formspec n=%d %.0f B/s/player identical=%d; show_formspec n=%d; set_properties n=%d"):format(
		name, traffic.hud_n, traffic.hud_n / seconds / per, traffic.hud_bytes / seconds / per,
		traffic.hud_same, traffic.fs_n, traffic.fs_bytes / seconds / per, traffic.fs_same,
		traffic.show_n, traffic.props_n))
	local srt = {}
	for k, r in pairs(hud_sites) do srt[#srt + 1] = {k, r} end
	table.sort(srt, function(a, b) return a[2].bytes > b[2].bytes end)
	for i = 1, math.min(12, #srt) do
		log(("%s HUDSITE %-50s ~n=%d ~%.0f B/s/player"):format(name, srt[i][1], srt[i][2].n,
			srt[i][2].bytes / seconds / per))
	end
	srt = {}
	for k, r in pairs(fs_sites) do srt[#srt + 1] = {k, r} end
	table.sort(srt, function(a, b) return a[2].bytes > b[2].bytes end)
	for i = 1, math.min(8, #srt) do
		log(("%s FSSITE %-50s n=%d bytes=%d (%.0f B/s/player; avg %.0f B)"):format(name, srt[i][1],
			srt[i][2].n, srt[i][2].bytes, srt[i][2].bytes / seconds / per, srt[i][2].bytes / srt[i][2].n))
	end
	-- the heaviest per-player traffic (map viewers)
	local heavy = {}
	for _, p in ipairs(fake_list) do heavy[#heavy + 1] = p end
	table.sort(heavy, function(a, b) return (a._hud_bytes + a._fs_bytes) > (b._hud_bytes + b._fs_bytes) end)
	for i = 1, math.min(4, #heavy) do
		local p = heavy[i]
		log(("%s NETTOP %s area=%s map=%s hud %.0f B/s, formspec %.0f B/s"):format(name, p._name,
			p._area.id, tostring(p._map), p._hud_bytes / seconds, p._fs_bytes / seconds))
	end
	if grug_map and grug_map.minimap and grug_map.minimap.stats then
		local mm = grug_map.minimap.stats
		log(("%s minimap stats: updates=%d avg_us=%.1f changes=%d bytes=%d textures=%d"):format(name,
			mm.updates, mm.us / math.max(1, mm.updates), mm.changes, mm.bytes, mm.textures))
		mm.updates, mm.us, mm.changes, mm.bytes, mm.textures = 0, 0, 0, 0, 0
	end
	local SRs = grug_mobs and grug_mobs.spawn_regions and grug_mobs.spawn_regions.stats
	if SRs then
		local parts = {}
		for k, v in pairs(SRs) do parts[#parts + 1] = k .. "=" .. v end
		table.sort(parts)
		log(name .. " spawn attempts: " .. table.concat(parts, " "))
		for k in pairs(SRs) do SRs[k] = nil end
	end
	if grug_pvp and grug_pvp.tick_stats then
		local ts = grug_pvp.tick_stats
		log(("%s pvp location samples=%d avg_us=%.2f"):format(name, ts.samples, ts.us / math.max(1, ts.samples)))
		ts.samples, ts.us = 0, 0
	end
	if grug_map and grug_map.location and grug_map.location.stats then
		local ls = grug_map.location.stats
		log(("%s location samples=%d avg_us=%.2f"):format(name, ls.samples, ls.us / math.max(1, ls.samples)))
		ls.samples, ls.us = 0, 0
	end
end

---------------------------------------------------------------------------
-- Areas and stand-in behaviour
---------------------------------------------------------------------------
local areas = {}
local function ground_y(x, z, fallback)
	local h = grug_zones and grug_zones.terrain_height_at and grug_zones.terrain_height_at(x, z)
	if type(h) ~= "number" then return fallback end
	return math.floor(h) + 1
end

local function build_areas()
	local accord_start = grug_core.start_position("accord", "human")
	local throng_start = grug_core.start_position("throng", "orc")
	local capital = grug_core.capital_anchor("accord", "human")
	local fortress
	local faction_of_race = {}
	for _, identity in ipairs(grug_core.start_identities()) do
		faction_of_race[identity.race_id] = identity.faction_id
	end
	for _, row in ipairs(grug_core.settlement_socket_settlements()) do
		if row.slot == "pvp_fortress" then
			log(("fortress %s race %s faction %s at %s"):format(row.key, tostring(row.race_id),
				tostring(faction_of_race[row.race_id]), core.pos_to_string(row.anchor)))
			if faction_of_race[row.race_id] == "accord" then fortress = row end
		end
	end
	local function area(id, centre, radius, box, faction, races, share, mixed)
		local a = {id = id, centre = vector.copy(centre), radius = radius, box = box,
			faction = faction, races = races, share = share, mixed = mixed}
		a.centre.y = ground_y(centre.x, centre.z, centre.y)
		areas[#areas + 1] = a
		log(("area %s centre %s radius %d"):format(id, core.pos_to_string(a.centre), radius))
	end
	if core.settings:get("r37po_scenario") == "crowd" then
		-- everyone questing in one start zone's wild (a playtest's first hour)
		area("accord_start", vector.offset(accord_start, 130, 0, 0), 70, 104, "accord",
			{"human", "dwarf", "elf"}, 1.0)
		areas[1].crowd = true
		return
	end
	-- the starts: the town edge and the wild beside it (players quest outside)
	area("accord_start", vector.offset(accord_start, 140, 0, 30), 44, 64, "accord",
		{"human", "dwarf", "elf"}, 0.30)
	area("throng_start", vector.offset(throng_start, 140, 0, 30), 44, 64, "throng",
		{"orc", "troll", "undead"}, 0.30)
	area("capital", capital, 50, 64, "accord", {"human", "dwarf", "elf"}, 0.25)
	if fortress then
		area("fortress", fortress.anchor, 30, 48, "accord", {"human", "dwarf", "elf"}, 0.15, true)
	end
end

local emerge_pending = 0
local forced = 0
local function load_areas(done)
	local t0 = now()
	for _, a in ipairs(areas) do
		local c, b = a.centre, a.box
		local minp = {x = c.x - b - 16, y = c.y - 32, z = c.z - b - 16}
		local maxp = {x = c.x + b + 16, y = c.y + 40, z = c.z + b + 16}
		emerge_pending = emerge_pending + 1
		core.emerge_area(minp, maxp, function(_, _, remaining)
			if remaining == 0 then
				emerge_pending = emerge_pending - 1
				if emerge_pending == 0 then
					log(("emerge done in %.1f s"):format((now() - t0) / 1e6))
					done()
				end
			end
		end)
	end
end
local function forceload_areas()
	for _, a in ipairs(areas) do
		local c, b = a.centre, a.box
		for x = math.floor((c.x - b) / 16), math.floor((c.x + b) / 16) do
			for z = math.floor((c.z - b) / 16), math.floor((c.z + b) / 16) do
				local dy = a.crowd and 32 or 16
				for y = math.floor((c.y - dy) / 16), math.floor((c.y + dy) / 16) do
					if core.forceload_block({x = x * 16 + 8, y = y * 16 + 8, z = z * 16 + 8}, true) then
						forced = forced + 1
					end
				end
			end
		end
	end
	log("forceloaded blocks: " .. forced)
end

local quest_ids
local function quest_state(kind)
	if not quest_ids then
		quest_ids = {}
		for id, def in pairs(grug_quests.registered_quests or {}) do
			quest_ids[#quest_ids + 1] = id
		end
		table.sort(quest_ids)
	end
	local active, completed, tracked = {}, {}, {}
	local nactive = 0
	local max_active = kind == "late" and 10 or 3
	local max_completed = kind == "late" and math.huge or 15
	local ncompleted = 0
	for _, id in ipairs(quest_ids) do
		local def = grug_quests.registered_quests[id]
		if nactive < max_active and not def.repeatable then
			active[id] = {}
			nactive = nactive + 1
			tracked[#tracked + 1] = id
		elseif ncompleted < max_completed then
			completed[id] = true
			ncompleted = ncompleted + 1
		end
	end
	return core.serialize({active = active, completed = completed, tracked = tracked,
		hud = true, cooldowns = {}})
end

local classes = {"mage", "warrior", "priest", "scout"}
local join_stats = {}
local function pick_area(i, n)
	-- deterministic split by shares
	local x = ((i - 1) + 0.5) / n
	local acc_share = 0
	for _, a in ipairs(areas) do
		acc_share = acc_share + a.share
		if x <= acc_share then return a end
	end
	return areas[#areas]
end

local function new_waypoint(p)
	local a = p._area
	local ang = math.random() * 2 * math.pi
	local r = math.sqrt(math.random()) * a.radius
	local x, z = a.centre.x + r * math.cos(ang), a.centre.z + r * math.sin(ang)
	p._wp = {x = x, y = ground_y(x, z, a.centre.y), z = z}
end

local function join_fake(i, n)
	local a = pick_area(i, n)
	local name = ("r37po%03d"):format(i)
	local faction, races = a.faction, a.races
	-- the fortress: every second stand-in an attacker of the other faction
	if a.mixed and i % 2 == 0 then
		faction, races = "throng", {"orc", "troll", "undead"}
	end
	local race = races[(i % #races) + 1]
	local start = vector.copy(a.centre)
	start.x = start.x + math.random(-a.radius, a.radius) * 0.5
	start.z = start.z + math.random(-a.radius, a.radius) * 0.5
	start.y = ground_y(start.x, start.z, a.centre.y)
	local p = make_fake(name, start, math.random() * 6.28)
	p._area, p._faction = a, faction
	local m = p:get_meta()
	m:set_string("grug_factions:faction", faction)
	m:set_string("grug_classes:race", race)
	m:set_string("grug_classes:class", classes[(i - 1) % 4 + 1])
	local look = grug_visuals and grug_visuals.roll_look and grug_visuals.roll_look(race, math.random)
	if look then m:set_string("grug_visuals:look", grug_visuals.look_string(look)) end
	local late = a.id == "capital" or a.id == "fortress"
	m:set_string("grug_quests:state", quest_state(late and "late" or "early"))
	if grug_xp and grug_xp.xp_for_level then
		m:set_int("grug_xp:xp", grug_xp.xp_for_level(late and 60 or 8))
	end
	pcall(function()
		local h = core.get_auth_handler()
		if not h.get_auth(name) then h.create_auth(name, "") end
	end)
	fakes[name] = p
	fake_list[#fake_list + 1] = p
	for _, cb in ipairs(core.registered_on_joinplayers) do
		local key = key_of(cb, "join ")
		local t = now()
		local ok, err = pcall(cb, p, nil)
		local d = now() - t
		local r = join_stats[key] or {us = 0, n = 0}
		join_stats[key] = r
		r.us, r.n = r.us + d, r.n + 1
		if not ok and not r.err then r.err = true; log("JOINERR " .. key .. " " .. tostring(err):sub(1, 300)) end
	end
	-- roles
	p._fighter = (a.crowd and i % 2 == 0) or (a.id:find("start", 1, true) and i % 3 == 0) or
		(a.mixed and faction == "throng")
	p._map = (i % 10 == 0)
	new_waypoint(p)
	return p
end

local function report_join(count)
	local rows, total = {}, 0
	for k, r in pairs(join_stats) do rows[#rows + 1] = {k = k, r = r}; total = total + r.us end
	table.sort(rows, function(a, b) return a.r.us > b.r.us end)
	log(("JOIN total %.1f ms for %d players (%.2f ms/player)"):format(total / 1000, count, total / 1000 / count))
	for i = 1, math.min(12, #rows) do
		log(("JOIN %-60s %8.1f us/player"):format(rows[i].k, rows[i].r.us / rows[i].r.n))
	end
	join_stats = {}
end

local HOSTILE_TYPES = {monster = true}
local function find_foe(p)
	local pos = p._pos
	local best, bd
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 18)) do
		local ent = obj:get_luaentity()
		if ent and ent._cmi_is_mob and ent.health and ent.health > 0 and ent.state ~= "die" then
			local ok
			if p._area.mixed then
				ok = ent._grug_faction == "accord"
			else
				ok = HOSTILE_TYPES[ent.type] or ent.type == "animal"
			end
			if ok then
				local d = vector.distance(pos, obj:get_pos())
				if not bd or d < bd then best, bd = obj, d end
			end
		end
	end
	return best
end

local party_queue = {}
local function plan_parties(from, to)
	-- groups of five inside one area and faction, in join order
	local groups = {}
	for i = from, to do
		local p = fake_list[i]
		local key = p._area.id .. "/" .. p._faction
		local g = groups[key]
		if not g or #g >= 5 then g = {}; groups[key .. "#" .. i] = g; groups[key] = g end
		g[#g + 1] = i
		if #g > 1 then party_queue[#party_queue + 1] = {g[1], i} end
	end
end

local fight_stats = {engaged = 0, kills = 0, errors = 0}
local move_acc, fight_acc = 0, 0
local function move_fakes(dtime)
	if still then return end
	move_acc = move_acc + dtime
	fight_acc = fight_acc + dtime
	local do_fight = fight_acc >= 1.0
	if do_fight then fight_acc = 0 end
	for _, p in ipairs(fake_list) do
		local foe = p._foe
		if foe and (not foe:get_pos() or not foe:get_luaentity()) then foe, p._foe = nil, nil end
		if p._fighter and do_fight then
			if not foe then
				foe = find_foe(p)
				if foe then
					p._foe, p._foe_t = foe, 0
					local ent = foe:get_luaentity()
					local ok = pcall(ent.do_attack, ent, p, true)
					if ok then fight_stats.engaged = fight_stats.engaged + 1
					else fight_stats.errors = fight_stats.errors + 1 end
				end
			else
				p._foe_t = (p._foe_t or 0) + 1
				pcall(grug_core.mark_in_combat, p)
				if p._foe_t >= 12 then
					local ent = foe:get_luaentity()
					if ent then
						ent.health = 0
						local ok = pcall(ent.check_for_death, ent, {type = "punch", puncher = p})
						if ok then fight_stats.kills = fight_stats.kills + 1
						else fight_stats.errors = fight_stats.errors + 1 end
					end
					p._foe = nil
				end
			end
		end
		if p._foe then
			local fp = p._foe:get_pos()
			if fp then
				local dx, dz = fp.x - p._pos.x, fp.z - p._pos.z
				local d = math.sqrt(dx * dx + dz * dz)
				p._yaw = math.atan2(-dx, dz)
				p._pitch = 0.1
				p._walking = d > 2.5
				if d > 2.5 then
					local step = math.min(d - 2, 4 * dtime)
					p._pos = {x = p._pos.x + dx / d * step, y = fp.y, z = p._pos.z + dz / d * step}
				end
			end
		else
			local wp = p._wp
			local dx, dz = wp.x - p._pos.x, wp.z - p._pos.z
			local d = math.sqrt(dx * dx + dz * dz)
			if d < 1 then
				new_waypoint(p)
			else
				local step = math.min(d, 4 * dtime)
				p._pos = {x = p._pos.x + dx / d * step,
					y = p._pos.y + (wp.y - p._pos.y) * math.min(1, step / d),
					z = p._pos.z + dz / d * step}
				p._yaw = math.atan2(-dx, dz)
				p._pitch = -0.1
				p._walking = true
			end
		end
	end
end

local map_queue = {}
local STAGGER = core.settings:get_bool("r37po_map_stagger", true)
local function open_map(p)
	local ok, err = pcall(sfinv.set_page, p, "grug_map:atlas")
	if not ok then log("set_page map failed " .. tostring(err)) end
end
local function open_maps(from, to)
	for i = from, to do
		local p = fake_list[i]
		if p._map then
			if STAGGER then map_queue[#map_queue + 1] = p else open_map(p) end
		end
	end
end
local map_acc = 0
local function open_queued_maps(dtime)
	map_acc = map_acc + dtime
	if map_acc < 0.7 or #map_queue == 0 then return end
	map_acc = 0
	open_map(table.remove(map_queue, 1))
end

---------------------------------------------------------------------------
-- Micro benchmarks (Round 30/31 systems)
---------------------------------------------------------------------------
local function bench(label, n, fn)
	local ok, err = pcall(fn, 1)
	if not ok then log("MICRO " .. label .. " ERROR " .. tostring(err):sub(1, 300)); return end
	collectgarbage("collect")
	local t = now()
	for i = 1, n do fn(i) end
	local d = now() - t
	log(("MICRO %-58s %10.2f us/call (n=%d)"):format(label, d / n, n))
	return d / n
end

local function heap_gc()
	local t = now()
	collectgarbage("collect")
	collectgarbage("collect")
	return collectgarbage("count") / 1024, (now() - t) / 1000
end

local function file_size(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:seek("end")
	f:close()
	return s
end

local function micro()
	recording = false
	local accord
	for _, p in ipairs(fake_list) do
		if p._faction == "accord" then accord = p; break end
	end
	-- How many stand-ins have an active item objective (the tracker reads
	-- their holdings either way before Round 37, only for those after).
	local with_items = 0
	for _, p in ipairs(fake_list) do
		local state = core.deserialize(p:get_meta():get_string("grug_quests:state")) or {}
		local has = false
		for id in pairs(state.active or {}) do
			for _, objective in ipairs(grug_quests.registered_quests[id].objectives) do
				if objective.type == "item" then has = true end
			end
		end
		if has then with_items = with_items + 1 end
	end
	log(("stand-ins with an active item objective: %d of %d"):format(with_items, #fake_list))
	-- quest markers and the tracker key
	local qs = accord:get_meta():get_string("grug_quests:state")
	local raws, flip = {qs, qs .. " "}, 1
	bench("Q.marker_states recompute incl. decode", 100, function()
		flip = 3 - flip
		accord:get_meta():set_string("grug_quests:state", raws[flip])
		grug_quests.marker_states(accord)
	end)
	accord:get_meta():set_string("grug_quests:state", qs)
	bench("Q.marker_states memo hit", 2000, function() grug_quests.marker_states(accord) end)
	bench("Q.journal_key", 500, function() grug_quests.journal_key(accord) end)
	if grug_jobs._scan_discovery then
		bench("grug_jobs discovery scan (one stand-in)", 500, function() grug_jobs._scan_discovery(accord) end)
	end
	bench("grug_map.minimap.refresh (slow path)", 100, function() grug_map.minimap.refresh(accord) end)
	-- Claim Stone placement: a spot whose 101 x 101 scan passes for the
	-- Accord and whose arrival cube is blocked (an unloaded cube reads as
	-- blocked), found on a coarse grid around the Accord human start; the
	-- search itself is not timed.
	if grug_housing and grug_housing.validate_placement then
		local start = grug_core.start_position("accord", "human")
		local found, tried = nil, 0
		local search_t = now()
		for r = 300, 3000, 150 do
			for k = 0, 15 do
				local a = k / 16 * 2 * math.pi
				local x = math.floor(start.x + r * math.cos(a))
				local z = math.floor(start.z + r * math.sin(a))
				local id = grug_zones.id_at(x, z)
				local zone = id and grug_zones.get(id)
				if zone and zone.faction == "accord" and zone.level_min >= 11 and
						zone.level_max <= 30 and not zone.civic_no_hostiles then
					tried = tried + 1
					local ok, code = grug_housing.validate_placement(accord, {x = x, y = 31000, z = z})
					if not ok and code == "cube" then found = {x = x, y = 31000, z = z}; break end
				end
				if tried >= 40 then break end
			end
			if found or tried >= 40 then break end
		end
		log(("claim spot search: %s after %d candidates in %.0f ms"):format(
			found and core.pos_to_string(found) or "none", tried, (now() - search_t) / 1000))
		if found then
			-- the first check at a fresh spot one node off, then repeats
			local fresh = {x = found.x + 1, y = found.y, z = found.z}
			local t = now()
			local ok, code = grug_housing.validate_placement(accord, fresh)
			log(("MICRO claim placement first check %10.2f us (%s %s)"):format(now() - t,
				tostring(ok), tostring(code)))
			bench("claim placement repeated (same spot, held click)", 20, function()
				grug_housing.validate_placement(accord, fresh)
			end)
		end
		local early = accord:get_pos()
		local ok, code = grug_housing.validate_placement(accord, early)
		log(("claim placement at the stand-in (early refusal): %s %s"):format(tostring(ok), tostring(code)))
		bench("claim placement early refusal (stand-in spot)", 200, function()
			grug_housing.validate_placement(accord, early)
		end)
	end
	recording = false
end

---------------------------------------------------------------------------
-- Driver
---------------------------------------------------------------------------
local state = {phase = "wait", t = 0, phase_t = 0}
local function set_phase(ph) state.phase, state.phase_t = ph, 0; log("phase -> " .. ph) end

core.register_on_mods_loaded(function()
	core.after(0, wrap_globalsteps)
	wrap_entities()
	wrap_abms_lbms_timers()
	count_wrap(core, "raycast", "core.raycast")
	count_wrap(core, "get_objects_inside_radius", "objects_inside_radius")
	count_wrap(core, "find_path", "core.find_path")
	count_wrap(core, "deserialize", "core.deserialize")
	count_wrap(core, "serialize", "core.serialize")
	count_wrap(core, "add_particlespawner", "add_particlespawner")
	count_wrap(core, "sound_play", "sound_play")
	count_wrap(core, "show_formspec", "show_formspec")
	count_wrap(core, "add_entity", "add_entity")
	count_wrap(core, "line_of_sight", "line_of_sight")
	-- mobs_redo's add_mob spawns only with a player ObjectRef within its
	-- count radius (count_mobs, api.lua), which a table stand-in can never
	-- be: in the crowd scenario a minimal add_mob without that test lets
	-- the region spawner populate the stand-ins' surroundings.
	if core.settings:get("r37po_scenario") == "crowd" and mobs and mobs.add_mob then
		local limit = tonumber(core.settings:get("mob_active_limit")) or 0
		mobs.add_mob = function(_, pos, def)
			if not pos or not def or not mobs.spawning_mobs[def.name] or
					not core.registered_entities[def.name] then
				return nil
			end
			if limit > 0 and mobs:get_active_mob_count() >= limit then return nil end
			local obj = core.add_entity(pos, def.name)
			return obj and obj:get_luaentity() or nil
		end
		log("crowd: add_mob without the player-object test")
	end
	local SR = grug_mobs and grug_mobs.spawn_regions
	wrap_fn(SR, "attempt", "fn SR.attempt")
	wrap_fn(SR, "leader_tick", "fn SR.leader_tick")
	wrap_fn(SR, "spawn_mob", "fn SR.spawn_mob")
	wrap_fn(grug_mobs, "region_camp_tick", "fn grug_mobs.region_camp_tick")
	wrap_fn(grug_quests, "journal_key", "fn Q.journal_key")
	wrap_fn(grug_quests, "journal", "fn Q.journal")
	wrap_fn(grug_quests, "marker_states", "fn Q.marker_states")
	wrap_fn(grug_parties, "view", "fn grug_parties.view")
	wrap_fn(grug_map and grug_map.atlas, "collect_markers", "fn atlas.collect_markers")
	wrap_fn(grug_abilities and grug_abilities.input, "step", "fn input.step")
	wrap_fn(grug_abilities and grug_abilities.crosshair, "update", "fn crosshair.update")
	wrap_fn(grug_core, "combat_ray", "fn grug_core.combat_ray")
	wrap_fn(sfinv, "get_formspec", "fn sfinv.get_formspec")
	local ctc = grug_core.create_tag_carrier
	if ctc then
		grug_core.create_tag_carrier = function(parent, ...)
			if fake_tables[parent] then return nil end
			return ctc(parent, ...)
		end
	end
	local orig = grug_core.world_preparation_status
	grug_core.world_preparation_status = function()
		local s = orig()
		if #fake_list > 0 then s.ready = true end
		return s
	end
	log(("mods loaded: heap %.1f MiB, jit %s"):format(collectgarbage("count") / 1024,
		tostring(rawget(_G, "jit") and jit.version)))
end)

local heap_acc = 0
core.register_globalstep(function(dtime)
	state.t = state.t + dtime
	state.phase_t = state.phase_t + dtime
	if recording then
		heap_acc = heap_acc + dtime
		if heap_acc >= 0.5 then
			heap_acc = 0
			local h = collectgarbage("count")
			if h > heap_max then heap_max = h end
			if h < heap_min then heap_min = h end
		end
	end
	if #fake_list > 0 then move_fakes(dtime); open_queued_maps(dtime) end
	local ph = state.phase
	if ph == "wait" then
		if state.t > 3 and grug_core.zone_authority_installed and grug_core.zone_authority_installed()
				and grug_core.world_preparation_status().ready then
			log(("preparation ready at uptime %.1f s"):format(state.t))
			build_areas()
			set_phase("emerge")
			load_areas(function() state.emerged = true end)
		end
	elseif ph == "emerge" then
		if state.emerged or state.phase_t > 150 then
			log("emerged=" .. tostring(state.emerged) .. " after " .. ("%.1f"):format(state.phase_t))
			forceload_areas()
			set_phase("settle0")
		end
	elseif ph == "settle0" then
		if state.phase_t >= 20 then
			local h, ms = heap_gc()
			log(("HEAP idle after full GC %.1f MiB (GC %.1f ms)"):format(h, ms))
			mark("idle_start")
			begin_phase()
			set_phase("idle")
		end
	elseif ph == "idle" then
		if state.phase_t >= IDLE_S then
			mark("idle_end")
			end_phase("idle")
			local t = now()
			for i = 1, NF1 do join_fake(i, NF1) end
			log(("joined %d in %.1f ms"):format(NF1, (now() - t) / 1000))
			report_join(NF1)
			plan_parties(1, NF1)
			open_maps(1, NF1)
			set_phase("settle1")
		end
	elseif ph == "settle1" or ph == "settle2" then
		state.party_acc = (state.party_acc or 0) + dtime
		if state.party_acc >= 1.1 and #party_queue > 0 then
			state.party_acc = 0
			local used = {}
			for i = #party_queue, 1, -1 do
				local row = party_queue[i]
				if not used[row[1]] then
					used[row[1]] = true
					local leader, member = fake_list[row[1]], fake_list[row[2]]
					pcall(grug_parties.invite, leader, member:get_player_name())
					pcall(grug_parties.accept, member, leader:get_player_name())
					table.remove(party_queue, i)
				end
			end
		end
		if state.phase_t >= SETTLE_S then
			local tag = ph == "settle1" and "p" .. NF1 or "p" .. NF2
			mark(tag .. "_start")
			begin_phase()
			set_phase(ph == "settle1" and "run1" or "run2")
		end
	elseif ph == "run1" then
		if state.phase_t >= RUN_S then
			mark("p" .. NF1 .. "_end")
			end_phase("p" .. NF1)
			log(("fights: engaged %d kills %d errors %d"):format(fight_stats.engaged,
				fight_stats.kills, fight_stats.errors))
			local h, ms = heap_gc()
			log(("HEAP p%d after full GC %.1f MiB (GC %.1f ms)"):format(NF1, h, ms))
			if NF2 > NF1 then
				local first = #fake_list + 1
				local t = now()
				-- the second wave keeps the same split over the areas
				for i = NF1 + 1, NF2 do join_fake(i, NF2) end
				log(("joined %d more in %.1f ms"):format(NF2 - NF1, (now() - t) / 1000))
				report_join(NF2 - NF1)
				plan_parties(first, #fake_list)
				open_maps(first, #fake_list)
				set_phase("settle2")
			else
				set_phase("micro")
			end
		end
	elseif ph == "run2" then
		if state.phase_t >= RUN_S then
			mark("p" .. NF2 .. "_end")
			end_phase("p" .. NF2)
			log(("fights: engaged %d kills %d errors %d"):format(fight_stats.engaged,
				fight_stats.kills, fight_stats.errors))
			local h, ms = heap_gc()
			log(("HEAP p%d after full GC %.1f MiB (GC %.1f ms)"):format(NF2, h, ms))
			still = true
			for _, p in ipairs(fake_list) do p._walking, p._foe = false, nil end
			set_phase("settle3")
		end
	elseif ph == "settle3" then
		if state.phase_t >= 5 then
			mark("p" .. NF2 .. "still_start")
			begin_phase()
			set_phase("run3")
		end
	elseif ph == "run3" then
		if state.phase_t >= STILL_S then
			mark("p" .. NF2 .. "still_end")
			end_phase("p" .. NF2 .. "still")
			set_phase("micro")
		end
	elseif ph == "micro" then
		if not SKIP_MICRO then
			local ok, err = pcall(micro)
			if not ok then log("MICRO failed " .. tostring(err)) end
		end
		local parts = {}
		for k, v in pairs(missing) do parts[#parts + 1] = k .. "@" .. v end
		table.sort(parts)
		log("MISSING methods: " .. table.concat(parts, " "))
		set_phase("leave")
	elseif ph == "leave" then
		local t = now()
		for _, p in ipairs(fake_list) do
			for _, cb in ipairs(core.registered_on_leaveplayers) do
				pcall(cb, p, false)
			end
		end
		log(("leave callbacks for %d in %.1f ms"):format(#fake_list, (now() - t) / 1000))
		fakes = {}
		for i = #fake_list, 1, -1 do fake_list[i] = nil end
		set_phase("after_leave")
	elseif ph == "after_leave" then
		if state.phase_t >= 4 then
			local h, ms = heap_gc()
			log(("HEAP after leave, full GC %.1f MiB (GC %.1f ms)"):format(h, ms))
			log("RESULT DONE")
			set_phase("done")
			core.request_shutdown("r37po done", false, 0)
		end
	end
end)
