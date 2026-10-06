-- Round 39 lane WG portable test (LuaJIT): the player model as glTF
-- (round39-web-data-plan.md §4.3).
--
--   luajit tools/r39_wg/portable_test.lua [repo]
--
-- The model itself is checked in Python (stdlib), outside this fixture:
--   python3 tools/web_data/model/build_glb.py --check
--   python3 tools/web_data/model/check_glb.py
--
-- Checks:
--   P  the GUI probe (tools/web_data/model/probe) on a fake engine: its frame
--      table and speed are player_api's; /glb_probe spawns the glTF model and
--      the .b3d with the caller's textures and visual size, facing the
--      caller; the glTF model plays its named clip at speed 1, the .b3d the
--      frame range at 30 fps; both switch stand -> walk -> stand together;
--      "clear" removes them; without play_animation the glTF model falls back
--      to its first clip.

local ROOT = arg[1] or "."
local checks, failures = 0, {}

local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
end

local function eq(got, want, label)
	check(got == want, label .. " (got " .. tostring(got) .. ", want " .. tostring(want) .. ")")
end

local function read(path)
	local f = assert(io.open(ROOT .. "/" .. path, "rb"))
	local text = f:read("*a")
	f:close()
	return text
end

-- P: the probe.
local api = read("mods/BASE/player_api/init.lua")
local api_frames = {}
for anim, x, y in api:gmatch("(%w+)%s*=%s*{%s*x%s*=%s*(%d+),%s*y%s*=%s*(%d+)") do
	api_frames[anim] = {x = tonumber(x), y = tonumber(y)}
end
local api_speed = tonumber(api:match("animation_speed%s*=%s*(%d+)"))

local entity_def, command
local objects = {}
local players = {}

local function fake_object(pos, name)
	local o = {pos = pos, name = name, props = {}, calls = {}, removed = false}
	function o:get_pos() return not self.removed and self.pos or nil end
	function o:remove() self.removed = true end
	function o:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
	function o:get_properties() return self.props end
	function o:set_yaw(y) self.yaw = y end
	function o:set_animation(range, speed, blend, loop)
		self.calls[#self.calls + 1] = {"set", range, speed, loop}
	end
	function o:get_luaentity() return self.lua end
	return o
end

local function with_tracks(o)
	function o:play_animation(track, spec)
		self.calls[#self.calls + 1] = {"play", track, spec}
	end
	function o:stop_animation() self.calls[#self.calls + 1] = {"stop"} end
	return o
end

local tracks = true
core = {
	register_entity = function(name, def) eq(name, "grug_glb_probe:model", "P entity name"); entity_def = def end,
	register_chatcommand = function(name, def) eq(name, "glb_probe", "P command name"); command = def end,
	get_player_by_name = function(name) return players[name] end,
	add_entity = function(pos, name)
		local o = fake_object(pos, name)
		if tracks then with_tracks(o) end
		o.lua = setmetatable({object = o}, {__index = entity_def})
		for k, v in pairs(entity_def.initial_properties) do o.props[k] = v end
		objects[#objects + 1] = o
		return o
	end,
}
vector = {
	add = function(a, b) return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z} end,
	subtract = function(a, b) return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z} end,
}
dofile(ROOT .. "/tools/web_data/model/probe/init.lua")

-- The probe's constants against player_api (read back through the upvalues
-- of its play function would be brittle; the source is the contract).
local probe = read("tools/web_data/model/probe/init.lua")
eq(tonumber(probe:match("local SPEED = (%d+)")), api_speed, "P speed is player_api's")
for anim, x, y in probe:match("local FRAMES = (%b{})"):gmatch("(%w+)%s*=%s*{x%s*=%s*(%d+),%s*y%s*=%s*(%d+)}") do
	eq(tonumber(x), api_frames[anim] and api_frames[anim].x, "P " .. anim .. " start")
	eq(tonumber(y), api_frames[anim] and api_frames[anim].y, "P " .. anim .. " end")
end

local skin, cloak = "grug_visuals_skin.png^armor.png", "cloak_red.png"
local size = {x = 1.1, y = 1.1, z = 1.1}
players.tester = {
	get_properties = function() return {textures = {skin, cloak}, visual_size = size} end,
	get_look_horizontal = function() return 0 end,
	get_pos = function() return {x = 10, y = 5, z = 20} end,
}

local function last_call(o)
	return o.calls[#o.calls]
end

local ok, msg = command.func("tester", "")
check(ok, "P /glb_probe succeeds: " .. tostring(msg))
eq(#objects, 2, "P two models")
local glb, b3d = objects[1], objects[2]
eq(glb.props.mesh, "grug_visuals_character.glb", "P left model is the glb")
eq(b3d.props.mesh, "grug_visuals_character.b3d", "P right model is the b3d")
for _, o in ipairs(objects) do
	eq(o.props.textures[1], skin, "P " .. o.props.mesh .. " wears the caller's skin")
	eq(o.props.textures[2], cloak, "P " .. o.props.mesh .. " wears the caller's cloak")
	eq(o.props.visual_size, size, "P " .. o.props.mesh .. " has the caller's visual size")
	check(math.abs(o.yaw - math.pi) < 1e-9, "P " .. o.props.mesh .. " faces the caller")
	eq(o.pos.z, 23, "P " .. o.props.mesh .. " three nodes ahead")
end
check(glb.pos.x < 10 and b3d.pos.x > 10, "P glb on the caller's left, b3d on the right")

local function clip_of(o)
	local c = last_call(o)
	if c[1] == "play" then return c[2], c[3].speed end
	for anim, r in pairs(api_frames) do
		if r.x == c[2].x and r.y == c[2].y then return anim, c[3] end
	end
end
local function expect(clip, label)
	local name, speed = clip_of(glb)
	eq(name, clip, label .. ": glb clip")
	eq(speed, 1, label .. ": glb plays seconds at speed 1")
	eq(glb.calls[#glb.calls - 1][1], "stop", label .. ": glb stops the other clip first")
	name, speed = clip_of(b3d)
	eq(name, clip, label .. ": b3d range")
	eq(speed, api_speed, label .. ": b3d at player_api's speed")
	eq(glb.props.nametag, "glb: " .. clip, label .. ": glb nametag")
	eq(b3d.props.nametag, "b3d: " .. clip, label .. ": b3d nametag")
end
expect("stand", "P spawn")
for _, o in ipairs(objects) do o.lua:on_step(3.9) end
expect("stand", "P before the switch")
for _, o in ipairs(objects) do o.lua:on_step(0.2) end
expect("walk", "P after 4 s")
for _, o in ipairs(objects) do o.lua:on_step(4) end
expect("stand", "P after 8 s")

ok = command.func("tester", "clear")
check(ok and glb.removed and b3d.removed, "P clear removes both")
command.func("tester", "")
eq(#objects, 4, "P a second spawn")
command.func("tester", "")
check(objects[3].removed and objects[4].removed and not objects[5].removed,
	"P a new spawn replaces the old pair")

tracks = false
command.func("tester", "")
local old = objects[#objects - 1]
local c = last_call(old)
check(c[1] == "set" and c[2].x == 0 and math.abs(c[2].y - 79 / 30) < 1e-9 and c[3] == 1,
	"P without play_animation the glb plays its first clip in seconds")

if #failures == 0 then
	print("R39 WG PORTABLE PASS checks=" .. checks)
else
	for _, label in ipairs(failures) do print("FAIL " .. label) end
	error(("R39 WG PORTABLE FAIL %d of %d checks"):format(#failures, checks), 0)
end
