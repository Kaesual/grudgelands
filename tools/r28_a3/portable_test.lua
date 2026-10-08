-- Round 28 Lane A3 portable test (LuaJIT): mob looks, rulings 9-11.
--
-- Loads the REAL grug_core tag_carrier.lua, grug_mobs levels.lua and
-- patrol.lua, and the REAL mobs:scale_mob cut out of the vendored api.lua,
-- under a minimal `core` stub. Checks:
--   * ruling 10 -- every HP bar is world-sized (0.8 x 0.1 nodes) whatever the
--     parent's visual_size (fox 10, serpent 0.3), the explicit dragon profile
--     keeps its own world size, and the anchor stays in the parent's scaled
--     frame; a tier rescale after the bar exists re-attaches it at the new
--     box top, and sync_tag_carrier_box moves the nametag carrier's box;
--   * ruling 9 -- the elite scale is 1.4 (model AND boxes), the king's
--     authored base from bosses.lua ends at a final visual_size of 1.6 with a
--     box exactly the model's height (character.b3d: 1.70 nodes at size 1),
--     taller than an elite guard's;
--   * ruling 11 -- walk_toward turns instantly and the velocity it sets
--     already points at the target, also when a smoothed turn was pending.
--
-- Usage (repo root): luajit tools/r28_a3/portable_test.lua [ROOT]

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function near(a, b, label)
	return check(type(a) == "number" and math.abs(a - b) < 1e-6,
		label .. " (got " .. tostring(a) .. ", expected " .. tostring(b) .. ")")
end

------------------------------------------------------------------------------
-- Engine surface.
------------------------------------------------------------------------------
local players = {}
local entities_by_name = {}

local function new_object(props, entity)
	local o = {props = props or {}, valid = true, entity = entity}
	function o:is_valid() return self.valid end
	function o:get_properties() return self.props end
	function o:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
	function o:set_attach(parent, _, pos) self.attach = {parent = parent, pos = pos} end
	function o:get_attach() return self.attach and self.attach.parent end
	function o:get_pos() return {x = 0, y = 0, z = 0} end
	function o:get_luaentity() return self.entity end
	function o:is_player() return false end
	function o:set_observers(observers) self.observers = observers end
	function o:remove() self.valid = false end
	function o:set_armor_groups(groups) self.armor = groups end
	if entity then entity.object = o end
	return o
end

local added = {}
_G.core = {
	settings = {
		get = function() return nil end,
		get_bool = function(_, _, default) return default end,
	},
	log = function() end,
	registered_entities = {},
	register_entity = function(name, def)
		entities_by_name[name] = def
		core.registered_entities[name] = def
	end,
	register_globalstep = function() end,
	get_connected_players = function() return players end,
	add_entity = function(_, name)
		local def = entities_by_name[name]
		local props = {}
		for k, v in pairs(def.initial_properties or {}) do props[k] = v end
		local entity = setmetatable({name = name}, {__index = def})
		local o = new_object(props, entity)
		if def.on_activate then def.on_activate(entity) end
		added[#added + 1] = o
		return o
	end,
	dir_to_yaw = function(dir) return -math.atan2(dir.x, dir.z) end,
	global_exists = function() return false end,
}
_G.vector = {new = function(x, y, z) return {x = x, y = y, z = z} end}
-- builtin/common/math.lua
function math.round(x)
	if x < 0 then return math.ceil(x - 0.5) end
	return math.floor(x + 0.5)
end
_G.grug_core = {format_k = function(v) return tostring(v) end,
	mob_level_at = function() return 10 end}
_G.grug_zones = {mob_level_at = function() return 10 end,
	guard_level_at = function() return 60 end}
_G.grug_mobs = {}
-- levels.lua derives kill XP from grug_xp's kill-equivalent unit.
_G.grug_xp = {mob_xp = function(level) return 25 + 5 * level end, LEVEL_OFFSET = 5}

-- The vendored mobs:scale_mob, verbatim, cut out of api.lua.
local api = assert(io.open(ROOT .. "/mods/ENTITIES/mobs/api.lua")):read("*a")
local scale_src = api:match("\nfunction mobs:scale_mob%(.-\nend\n")
assert(scale_src, "mobs:scale_mob not found in api.lua")
-- walk_toward marks the mob as driven (Round 42 ST): the real navigation.
_G.mobs = {grug_nav = dofile(ROOT .. "/mods/ENTITIES/mobs/grug_nav.lua")}
-- scale_mob cuts a tall mob's physics box (Round 42 NV1, ruling 20).
_G.grug_obstacle = dofile(ROOT .. "/mods/ENTITIES/mobs/grug_obstacle.lua")
assert(loadstring(scale_src))()

dofile(ROOT .. "/mods/CORE/grug_core/tag_carrier.lua")
dofile(ROOT .. "/mods/ENTITIES/grug_mobs/levels.lua")
dofile(ROOT .. "/mods/ENTITIES/grug_mobs/npc_doors.lua")
dofile(ROOT .. "/mods/ENTITIES/grug_mobs/patrol.lua")
-- init.lua's ensure_tag_carrier, reduced to what the checks read.
function grug_mobs.ensure_tag_carrier(self)
	self.temp = self.temp or {}
	self.temp.grug_tag_carrier = self.temp.grug_tag_carrier or
		grug_core.create_tag_carrier(self.object)
	return self.temp.grug_tag_carrier
end

------------------------------------------------------------------------------
-- Ruling 10: bar geometry.
------------------------------------------------------------------------------
local geometry = grug_core.hp_bar_geometry
do
	local anchor, w, h = geometry({visual_size = {x = 10, y = 10},
		selectionbox = {-0.35, -0.05, -0.7, 0.35, 0.8, 0.65, rotate = true}})
	near(w, 0.8, "fox bar width is world-sized")
	near(h, 0.1, "fox bar height is world-sized")
	near(anchor, (0.8 + 0.12) * 10 / 10, "fox anchor in the parent's scaled frame")
	anchor, w, h = geometry({visual_size = {x = 0.3, y = 0.3},
		selectionbox = {-0.5, -0.05, -1.3, 0.5, 1.1, 0.8, rotate = true}})
	near(w, 0.8, "serpent bar width is world-sized")
	near(h, 0.1, "serpent bar height is world-sized")
	near(anchor, (1.1 + 0.12) * 10 / 0.3, "serpent anchor in the parent's scaled frame")
	anchor, w, h = geometry({visual_size = {x = 8, y = 8},
		selectionbox = {-3, -0.65, -4.8, 3, 2.65, 3, rotate = true}},
		{anchor_y = 2.77, width = 3, height = 0.25})
	near(w, 3, "dragon profile width")
	near(h, 0.25, "dragon profile height")
	near(anchor, 2.77 * 10 / 8, "dragon profile anchor")
	anchor = geometry({visual_size = {x = 1, y = 1},
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}})
	near(anchor, (1.7 + 0.12) * 10, "collisionbox fallback")
end

------------------------------------------------------------------------------
-- Ruling 9 + 10: a live elite promotion moves the bar and the nametag box.
------------------------------------------------------------------------------
local function base_mob(name, size, box, tier, fixed)
	grug_mobs.register_level_cfg(name, {_grug_tier = tier, _grug_fixed_level = fixed})
	core.registered_entities[name] = core.registered_entities[name] or {}
	local entity = {name = name, health = 50, _grug_disposition = "aggressive",
		base_size = {x = size, y = size},
		base_colbox = {box[1], box[2], box[3], box[4], box[5], box[6]},
		base_selbox = {box[1], box[2], box[3], box[4], box[5], box[6]},
		armor = 100}
	new_object({visual_size = {x = size, y = size},
		collisionbox = {box[1], box[2], box[3], box[4], box[5], box[6]},
		selectionbox = {box[1], box[2], box[3], box[4], box[5], box[6]}}, entity)
	return entity
end

players[1] = {
	get_pos = function() return {x = 1, y = 0, z = 1} end,
	get_player_name = function() return "viewer" end,
}
do
	local guard = base_mob("test:guard", 1, {-0.3, 0, -0.3, 0.3, 1.7, 0.3}, "normal")
	grug_mobs.ensure_init(guard) -- level + stats, normal tier, carrier created
	local carrier = guard.temp and guard.temp.grug_tag_carrier
	check(carrier ~= nil, "guard has a tag carrier")
	near(carrier.props.selectionbox[5], 1.7, "carrier copies the unscaled box")
	guard.health = math.floor(guard.hp_max / 2) -- injured: bar shows
	grug_core.refresh_tag_player_snapshot()
	grug_core.manage_tag_carriers()
	local bar
	for _, o in ipairs(added) do
		if o.entity.name == "grug_core:injured_hp_bar" and o.valid then bar = o end
	end
	check(bar ~= nil, "injured guard shows an HP bar")
	near(bar.props.visual_size.x, 0.8, "bar width before promotion")
	near(bar.attach.pos.y, (1.7 + 0.12) * 10, "bar anchor before promotion")

	grug_mobs.set_tier(guard, "elite")
	near(guard.object.props.visual_size.x, 1.4, "elite visual_size is 1.4")
	near(guard.object.props.selectionbox[5], 1.7 * 1.4, "elite box scales with the visual")
	near(guard.object.props.collisionbox[4], 0.3 * 1.4, "elite collisionbox scales with the visual")
	near(carrier.props.selectionbox[5], 1.7 * 1.4, "carrier box follows the promotion")
	guard.health = math.floor(guard.hp_max / 2)
	grug_core.manage_tag_carriers()
	near(bar.props.visual_size.x, 0.8, "bar width stays world-sized after promotion")
	near(bar.props.visual_size.y, 0.1, "bar height stays world-sized after promotion")
	near(bar.attach.pos.y, (1.7 * 1.4 + 0.12) * 10 / 1.4,
		"bar re-attached at the promoted box top")

	-- Demotion back to normal restores the authored size exactly.
	grug_mobs.set_tier(guard, "normal")
	near(guard.object.props.visual_size.x, 1, "normal tier restores visual_size 1")
	near(carrier.props.selectionbox[5], 1.7, "carrier box follows the demotion")
end

------------------------------------------------------------------------------
-- Ruling 9: the king's authored base (bosses.lua king_def) lands at 1.6.
------------------------------------------------------------------------------
do
	local src = assert(io.open(ROOT .. "/mods/ENTITIES/grug_mobs/bosses.lua")):read("*a")
	local vs_src, box_src = src:match(
		"local function king_def.-visual_size = (%b{}).-collisionbox = (%b{})")
	check(vs_src ~= nil, "king_def visual_size and collisionbox found")
	local vs = assert(loadstring("return " .. vs_src))()
	local box = assert(loadstring("return " .. box_src))()
	check(vs.x == vs.y, "king visual_size is uniform")
	local king = base_mob("test:king", vs.x, box, "elite", 65)
	grug_mobs.ensure_init(king) -- first tick: tier visuals at once
	local CHARACTER_HEIGHT = 1.7 -- character.b3d, nodes at visual_size 1
	near(king.object.props.visual_size.x, 1.6, "king final visual_size")
	-- Round 42 NV1 (ruling 20): the physics box of a mob taller than two
	-- nodes stops just under two; the selection box keeps the model height.
	near(king.object.props.collisionbox[5], 1.95,
		"king physics box top just under 2 nodes")
	near(king.object.props.selectionbox[5], CHARACTER_HEIGHT * 1.6,
		"king selectionbox top = model height")
	check(king.object.props.selectionbox[5] > 1.7 * 1.4,
		"king stands taller than an elite guard")
	near(king.object.props.collisionbox[4] / king.object.props.visual_size.x,
		0.3, "king box width keeps the player box proportion")
end

------------------------------------------------------------------------------
-- Ruling 11: walk_toward turns and walks together.
------------------------------------------------------------------------------
do
	local function fake_mob(yaw)
		local mob = {rotate = 0, state = "stand", walk_velocity = 1.2}
		mob.object = {yaw = yaw}
		function mob.object.get_yaw(o) return o.yaw end
		function mob.object.set_velocity(o, v) o.velocity = v end
		-- mob_class:set_yaw: delay 0 writes the rotation, otherwise the step
		-- function turns toward target_yaw over `delay` steps.
		function mob:set_yaw(y, delay)
			if (delay or 0) == 0 then self.object.yaw = y; return y end
			self.target_yaw, self.delay = y, delay
			return y
		end
		function mob:yaw_to_pos(target, rot, delay)
			local pos = {x = 0, y = 0, z = 0}
			local y = core.dir_to_yaw({x = target.x - pos.x, z = target.z - pos.z})
				+ (rot or 0) - self.rotate
			return self:set_yaw(y, delay)
		end
		-- mob_class:set_velocity: built from the CURRENT object yaw.
		function mob:set_velocity(v)
			local y = self.object:get_yaw() + self.rotate
			self.object:set_velocity({x = math.sin(y) * -v, y = 0, z = math.cos(y) * v})
		end
		return mob
	end
	local mob = fake_mob(math.pi / 2) -- facing -x
	mob.target_yaw, mob.delay = math.pi / 2 + 0.4, 6 -- a random turn in flight
	grug_mobs.walk_toward(mob, 10, 0, {x = 0, y = 0, z = 0}) -- target at +x
	local v = mob.object.velocity
	check(v and v.x > 1.19 and math.abs(v.z) < 1e-6,
		"velocity points at the target at once (got " ..
		tostring(v and v.x) .. ", " .. tostring(v and v.z) .. ")")
	near(mob.object.yaw, -math.pi / 2, "yaw is the target yaw at once")
	check((mob.delay or 0) == 0, "pending smoothed turn dropped")
	check(mob.state == "walk", "state is walk")
end

print(("r28_a3 portable test: %d checks, %d failures"):format(checks, failures))
print(failures == 0 and "RESULT PASS" or "RESULT FAIL")
if failures > 0 then error("r28_a3 portable test failed", 0) end
