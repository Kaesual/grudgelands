-- Round 89 lane BUBBLE (round89-plan.md §2.2, §3 "The bubble"). Loads the
-- REAL grug_core hud_layout.lua, status_icons.lua, status.lua,
-- shield_bubble.lua, combat.lua and environment_damage.lua on a small fake
-- engine (objects that attach, detach and deactivate as
-- src/server/unit_sao.cpp does; the status pass through the Round 81 test
-- double) and checks the bubble's lifecycle:
--   A  the first absorb makes one bubble, attached to the player at
--      CENTER_Y with forced_visible left false, its colour by id (gold,
--      frost, plain) and the entity's properties (not saved, not
--      pointable, blended, culled);
--   B  a second absorb of another id recolours the same object (never a
--      second one); a recast of the older id takes the colour back; an
--      unchanged colour writes nothing;
--   C  the absorb added last ends first: the colour falls back to the
--      latest still live at the next status pass;
--   D  used up by the soak: gone in the same hit; a partial soak keeps it;
--   E  expired: gone at the status pass that expires the shield status
--      (its on_expire), with no damage and no other call;
--   F  death and leave remove it; a player object removed without the
--      leave callback takes its bubble along (on_detach);
--   G  add_absorb returning 0 (the cap at maximum HP) adds no bubble; a
--      capped refresh that ends the only contribution removes it;
--   H  a bubble removed from outside (a cleared object) comes back at the
--      next sync; the mesh and textures exist and the mesh's generator
--      agrees (--check is the tool's own; here: files present, OBJ
--      triangle count in the brief's range).
-- Usage: luajit tools/r89_bubble/portable_test.lua REPO
local repo = assert(arg and arg[1], "usage: luajit portable_test.lua REPO")
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then failures = failures + 1; print("FAIL " .. label) end
	return ok
end
local function eq(a, b, label)
	return check(a == b, label .. " (got " .. tostring(a) .. ", expected " .. tostring(b) .. ")")
end

------------------------------------------------------------------------------
-- Engine stub.
------------------------------------------------------------------------------
local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = copy(v) end
	return out
end
table.copy = copy
vector = {offset = function(p, x, y, z) return {x = p.x + x, y = p.y + y, z = p.z + z} end,
	new = function(x, y, z) return {x = x, y = y, z = z} end}

local us_time = 1000000
local noop = function() end
local modifiers, loggers, globalsteps = {}, {}, {}
local on_die, on_leave, on_join = {}, {}, {}
local entities = {}
local connected = {}
local pending_deactivation = {}
local added = 0           -- add_entity calls
local property_writes = 0 -- set_properties calls on bubbles

local Object = {}
Object.__index = Object
function Object:is_valid() return not self.gone end
function Object:get_luaentity() return not self.gone and self.entity or nil end
function Object:get_pos() return not self.gone and {x = 0, y = 0, z = 0} or nil end
function Object:set_properties(p)
	if self.gone then return end
	property_writes = property_writes + 1
	for k, v in pairs(p) do self.props[k] = v end
end
function Object:get_properties() return not self.gone and self.props or nil end
function Object:get_attach()
	local a = self.attach
	if not a then return nil end
	return a.parent, a.bone, a.position, a.rotation, a.forced_visible
end
function Object:set_attach(parent, bone, position, rotation, forced_visible)
	if self.gone then return end
	self.attach = {parent = parent, bone = bone, position = position,
		rotation = rotation, forced_visible = forced_visible == true}
	parent.children[self] = true
end
-- unit_sao.cpp: setAttachment(0) runs the child's on_detach once the link is
-- gone; markForRemoval clears the attachments first (onMarkedForRemoval).
local function detach(child)
	local a = child.attach
	if not a then return end
	child.attach = nil
	a.parent.children[child] = nil
	if child.entity and child.entity.on_detach then child.entity.on_detach(child.entity, a.parent) end
end
function Object:remove()
	if self.gone or self.pending then return end
	self.pending = true
	detach(self)
	self.gone = true
	pending_deactivation[#pending_deactivation + 1] = self
end
-- The environment deletes removed objects on a later step: on_deactivate.
local function flush()
	local list = pending_deactivation
	pending_deactivation = {}
	for _, obj in ipairs(list) do
		if obj.entity.on_deactivate then obj.entity.on_deactivate(obj.entity, true) end
	end
end

core = {
	registered_items = {}, registered_entities = entities,
	registered_nodes = {air = {walkable = false, drawtype = "airlike"}},
	get_us_time = function() return us_time end,
	get_item_group = function() return 0 end,
	get_translated_string = function(_, text) return text end,
	register_on_player_hpchange = function(fn, modifier)
		local list = modifier and modifiers or loggers
		list[#list + 1] = fn
	end,
	register_on_dieplayer = function(fn) on_die[#on_die + 1] = fn end,
	register_on_leaveplayer = function(fn) on_leave[#on_leave + 1] = fn end,
	register_on_joinplayer = function(fn) on_join[#on_join + 1] = fn end,
	register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
	register_entity = function(name, def) entities[name] = def end,
	add_entity = function(pos, name)
		local def = entities[name]
		if not def then return nil end
		added = added + 1
		local obj = setmetatable({props = copy(def.initial_properties), children = {}}, Object)
		obj.entity = setmetatable({name = name, object = obj}, {__index = def})
		if def.on_activate then def.on_activate(obj.entity, "") end
		return obj
	end,
	get_connected_players = function() return connected end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	chat_send_player = noop,
	add_particlespawner = noop,
}
setmetatable(core, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return noop end
	return nil
end})
grug_sounds = {play = function() return false end, CLICK_STYLE = ""}

grug_core = {}
grug_core.particles = {play = noop}
dofile(repo .. "/tools/r81_passes/all_players_pass.lua")(grug_core, core)
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
dofile(repo .. "/mods/CORE/grug_core/item_names.lua")
dofile(repo .. "/mods/CORE/grug_core/status_icons.lua")
dofile(repo .. "/mods/CORE/grug_core/status.lua")
dofile(repo .. "/mods/CORE/grug_core/shield_bubble.lua")
dofile(repo .. "/mods/CORE/grug_core/combat.lua")
-- For grug_core.bypasses_absorb only: its own per-player pass stays out.
local register_pass = grug_core.register_player_pass
grug_core.register_player_pass = noop
dofile(repo .. "/mods/CORE/grug_core/environment_damage.lua")
grug_core.register_player_pass = register_pass
local bubble = grug_core.shield_bubble

local function new_player(name, hp_max)
	local p = {name = name, hp = hp_max, hp_max = hp_max, children = {}, huds = {}}
	function p:get_player_name() return self.name end
	function p:get_hp() return self.hp end
	function p:get_properties() return {hp_max = self.hp_max} end
	function p:get_pos() return {x = 0, y = 0, z = 0} end
	function p:is_player() return true end
	function p:get_meta() return {get_string = function() return "" end} end
	function p:hud_add(def) self.huds[#self.huds + 1] = def; return #self.huds end
	function p:hud_change() end
	connected[#connected + 1] = p
	for _, fn in ipairs(on_join) do fn(p) end
	return p
end
local function leave(p)
	for _, fn in ipairs(on_leave) do fn(p, false) end
	for i = #connected, 1, -1 do if connected[i] == p then table.remove(connected, i) end end
end
local function die(p)
	for _, fn in ipairs(on_die) do fn(p, {type = "set_hp"}) end
end
-- One hit as the engine runs it (tools/r80_fixes): modifiers, loggers, store.
local function hit(p, change)
	local reason = {type = "set_hp", from = "mod"}
	for i = #modifiers, 1, -1 do change = modifiers[i](p, change, reason) end
	for _, fn in ipairs(loggers) do fn(p, change, reason) end
	p.hp = math.max(0, math.min(p.hp_max, p.hp + change))
	return change
end
-- Time passes in server steps of 0.05 s; every status pass and deferred
-- deletion runs as in the engine.
local function advance(seconds)
	local steps = math.floor(seconds / 0.05 + 0.5)
	for _ = 1, steps do
		us_time = us_time + 50000
		for _, fn in ipairs(globalsteps) do fn(0.05) end
		flush()
	end
end
local function children_of(p, name)
	local n = 0
	for child in pairs(p.children) do
		if not child.gone and child.entity and child.entity.name == name then n = n + 1 end
	end
	return n
end
local function color(p)
	local _, c = bubble.shown(p:get_player_name())
	return c
end

------------------------------------------------------------------------------
-- A  the first absorb.
------------------------------------------------------------------------------
do
	local def = entities[bubble.ENTITY]
	check(def ~= nil, "A the entity is registered")
	local props = def.initial_properties
	eq(props.static_save, false, "A never saved")
	eq(props.physical, false, "A not physical")
	eq(props.pointable, false, "A not pointable")
	eq(props.collide_with_objects, false, "A no collision")
	eq(props.visual, "mesh", "A a mesh")
	eq(props.mesh, "grug_core_shield_bubble.obj", "A its mesh")
	eq(props.use_texture_alpha, true, "A blended")
	eq(props.backface_culling, true, "A the near half only")
	check(props.nametag == nil or props.nametag == "", "A no nametag")

	local p = new_player("anna", 100)
	eq(bubble.shown("anna"), nil, "A no bubble before a shield")
	eq(grug_core.add_absorb(p, "hold_ground", 20, 5, p), 20, "A Hold Ground adds 20")
	local obj, c = bubble.shown("anna")
	check(obj ~= nil, "A one bubble after the first absorb")
	eq(c, "plain", "A Hold Ground is plain")
	eq(obj.props.textures[1], "grug_core_shield_bubble_plain.png", "A the plain texture")
	local parent, bone, position, rotation, forced = obj:get_attach()
	eq(parent, p, "A attached to the player")
	eq(bone, "", "A at the origin")
	eq(position.y, bubble.CENTER_Y, "A centred CENTER_Y above the feet")
	eq(forced, false, "A forced_visible false: hidden from its own first person")
	eq(children_of(p, bubble.ENTITY), 1, "A exactly one bubble child")
	eq(bubble.color_of("shield_spell"), "gold", "A the Priest's Shield is gold")
	eq(bubble.color_of("rime_mantle"), "frost", "A Rime Mantle is frost")
	for _, id in ipairs({"hold_ground", "unbroken", "parry", "close_dance", "last_light"}) do
		eq(bubble.color_of(id), "plain", "A " .. id .. " is plain")
	end
	leave(p)
	flush()
end

------------------------------------------------------------------------------
-- B  a second absorb recolours the same object; a recast takes it back.
------------------------------------------------------------------------------
do
	local p = new_player("bert", 100)
	grug_core.add_absorb(p, "parry", 10, 8, p)
	local first = bubble.shown("bert")
	local made = added
	grug_core.add_absorb(p, "shield_spell", 20, 10, p)
	local second = bubble.shown("bert")
	eq(second, first, "B the same object after a second shield")
	eq(added, made, "B no second entity")
	eq(color(p), "gold", "B the shield cast last colours it (gold)")
	eq(first.props.textures[1], "grug_core_shield_bubble_gold.png", "B the gold texture")
	grug_core.add_absorb(p, "rime_mantle", 10, 6, p)
	eq(color(p), "frost", "B then Rime Mantle (frost)")
	grug_core.add_absorb(p, "shield_spell", 20, 10, p)
	eq(color(p), "gold", "B a recast of the Shield takes the colour back")
	eq(children_of(p, bubble.ENTITY), 1, "B never more than one bubble")
	local writes = property_writes
	advance(1.0) -- two status passes read the shield (get_absorb) twice
	grug_core.absorb_modifier(p, "anything")
	eq(property_writes, writes, "B an unchanged colour writes nothing")
	leave(p)
	flush()
end

------------------------------------------------------------------------------
-- C  the absorb added last ends first: the colour falls back.
------------------------------------------------------------------------------
do
	local p = new_player("cora", 100)
	grug_core.add_absorb(p, "hold_ground", 10, 10, p)
	grug_core.add_absorb(p, "rime_mantle", 10, 2, p)
	eq(color(p), "frost", "C Rime Mantle cast last")
	advance(1.9)
	eq(color(p), "frost", "C still frost while it lives")
	advance(0.6) -- past its end plus one status pass at most
	eq(color(p), "plain", "C back to the older Hold Ground at the next pass")
	check(bubble.shown("cora") ~= nil, "C the bubble stays")
	leave(p)
	flush()
end

------------------------------------------------------------------------------
-- D  used up by the soak.
------------------------------------------------------------------------------
do
	local p = new_player("dirk", 100)
	grug_core.add_absorb(p, "shield_spell", 20, 10, p)
	eq(hit(p, -8), 0, "D a partial soak")
	check(bubble.shown("dirk") ~= nil, "D a partial soak keeps the bubble")
	eq(hit(p, -30), -18, "D the rest breaks it")
	eq(bubble.shown("dirk"), nil, "D used up: gone in the same hit")
	flush()
	eq(children_of(p, bubble.ENTITY), 0, "D no child left")
	-- Two shields: the shorter-lived soaks first, the colour follows.
	grug_core.add_absorb(p, "close_dance", 10, 20, p)
	grug_core.add_absorb(p, "rime_mantle", 5, 5, p)
	hit(p, -5)
	eq(color(p), "plain", "D Rime Mantle soaked away: back to Close Dance")
	leave(p)
	flush()
end

------------------------------------------------------------------------------
-- E  expired, with nothing else calling.
------------------------------------------------------------------------------
do
	local p = new_player("eve", 100)
	grug_core.add_absorb(p, "unbroken", 10, 3, p)
	advance(2.9)
	check(bubble.shown("eve") ~= nil, "E alive before its end")
	advance(0.55) -- the end plus one status pass
	eq(bubble.shown("eve"), nil, "E gone at the pass that expires the shield")
	eq(grug_core.get_status(p, "shield"), nil, "E the shield status went too")
	eq(children_of(p, bubble.ENTITY), 0, "E no child left")
	leave(p)
	flush()
end

------------------------------------------------------------------------------
-- F  death, leave, and a player object removed without the leave.
------------------------------------------------------------------------------
do
	local p = new_player("finn", 100)
	grug_core.add_absorb(p, "last_light", 10, 30, p)
	local obj = bubble.shown("finn")
	die(p)
	eq(bubble.shown("finn"), nil, "F death removes it")
	check(obj.gone, "F the object is removed")
	grug_core.add_absorb(p, "last_light", 10, 30, p)
	obj = bubble.shown("finn")
	leave(p)
	eq(bubble.shown("finn"), nil, "F leave removes it")
	check(obj.gone, "F the object is removed at leave")
	flush()
	local q = new_player("gale", 100)
	grug_core.add_absorb(q, "parry", 10, 30, q)
	obj = bubble.shown("gale")
	-- The engine's removal of the parent: clearChildAttachments runs the
	-- child's on_detach.
	for child in pairs(q.children) do detach(child) end
	check(obj.gone, "F a bubble whose parent is gone removes itself")
	flush()
	eq(bubble.shown("gale"), nil, "F and is forgotten at its deactivation")
	leave(q)
	flush()
end

------------------------------------------------------------------------------
-- G  add_absorb returning 0.
------------------------------------------------------------------------------
do
	local p = new_player("hana", 20)
	eq(grug_core.add_absorb(p, "hold_ground", 0, 5, p), 0, "G nothing to add")
	eq(bubble.shown("hana"), nil, "G a zero absorb adds no bubble")
	eq(grug_core.add_absorb(p, "hold_ground", 20, 5, p), 20, "G the cap fills")
	eq(grug_core.add_absorb(p, "shield_spell", 10, 10, p), 0, "G capped at maximum HP")
	eq(color(p), "plain", "G a capped add does not recolour")
	eq(grug_core.add_absorb(p, "hold_ground", 0, 5, p), 0, "G a refresh that adds nothing")
	eq(bubble.shown("hana"), nil, "G ends the only contribution and the bubble")
	leave(p)
	flush()
end

------------------------------------------------------------------------------
-- H  removed from outside; the media.
------------------------------------------------------------------------------
do
	local p = new_player("ida", 100)
	grug_core.add_absorb(p, "shield_spell", 20, 10, p)
	local obj = bubble.shown("ida")
	obj:remove() -- an outside removal (a cleared object): on_detach, then on_deactivate
	flush()
	eq(bubble.shown("ida"), nil, "H a cleared bubble is forgotten")
	advance(0.5)
	local again = bubble.shown("ida")
	check(again ~= nil and again ~= obj, "H the next pass makes a new one")
	eq(children_of(p, bubble.ENTITY), 1, "H still exactly one")
	leave(p)
	flush()

	local function read(path)
		local handle = io.open(repo .. "/" .. path, "rb")
		if not handle then return nil end
		local data = handle:read("*a")
		handle:close()
		return data
	end
	local mesh = read("mods/CORE/grug_core/models/grug_core_shield_bubble.obj")
	check(mesh ~= nil, "H the mesh exists")
	local faces = 0
	for _ in (mesh or ""):gmatch("\nf ") do faces = faces + 1 end
	check(faces >= 24 and faces <= 300, "H low poly: " .. faces .. " triangles")
	for _, key in ipairs({"gold", "frost", "plain"}) do
		local data = read("mods/CORE/grug_core/textures/" .. bubble.TEXTURES[key])
		check(data and data:sub(2, 4) == "PNG", "H the " .. key .. " texture exists")
	end
end

if failures > 0 then
	error(("R89 BUBBLE PORTABLE FAIL %d of %d"):format(failures, checks), 0)
end
print(("R89 BUBBLE PORTABLE PASS checks=%d"):format(checks))
