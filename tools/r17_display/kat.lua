-- Round 17 DISPLAY production fixture.
-- Usage: luajit tools/r17_display/kat.lua [repository root]

local root = arg[1] or "."
local registered, steps, players, objects = {}, {}, {}, {}
local disable_hp = os.getenv("DISABLE_HP") == "1"
local settings = {
	grug_nametag_aggressive_foreground = "invalid-color",
	grug_nametag_neutral_foreground = "#abcdef99",
}

local function copy(values)
	local result = {}
	for key, value in pairs(values or {}) do result[key] = value end
	return result
end

local function object(properties, entity, player_name)
	local value = {valid = true, properties = copy(properties), entity = entity,
		pos = {x = 0, y = 0, z = 0}, property_writes = 0,
		observer_writes = 0}
	function value:is_valid() return self.valid end
	function value:is_player() return player_name ~= nil end
	function value:get_player_name() return player_name or "" end
	function value:get_pos() return self.pos end
	function value:get_properties() return self.properties end
	function value:get_luaentity() return self.entity end
	function value:set_properties(changes)
		self.property_writes = self.property_writes + 1
		for key, child in pairs(changes) do self.properties[key] = child end
	end
	function value:set_attach(parent, bone, position)
		self.parent, self.attach_position = parent, position
	end
	function value:get_attach() return self.parent end
	function value:set_observers(observers)
		self.observer_writes = self.observer_writes + 1
		self.observers = copy(observers)
	end
	function value:remove() self.valid = false end
	return value
end

core = {
	settings = {
		get = function(_, name) return settings[name] end,
		get_bool = function(_, name, fallback)
			if name == "grug_injured_mob_hp_bars" then return not disable_hp end
			return fallback
		end,
	},
	colorspec_to_colorstring = function(value)
		if type(value) == "string" and value:match("^#%x%x%x%x%x%x%x?%x?$") then
			return value
		end
		return nil
	end,
	register_entity = function(name, def) registered[name] = def end,
	register_globalstep = function(callback) steps[#steps + 1] = callback end,
	get_connected_players = function() return players end,
}

function core.add_entity(pos, name)
	local def = assert(registered[name], "registered entity " .. name)
	local child = object(def.initial_properties)
	child.pos = copy(pos)
	child.entity = {name = name, object = child}
	def.on_activate(child.entity)
	objects[#objects + 1] = child
	return child
end

local viewer = object(nil, nil, "viewer")
viewer.pos.x = 10
players[1] = viewer
grug_core = {}
dofile(root .. "/mods/CORE/grug_core/tag_carrier.lua")

local function tick()
	for index = 1, #steps do steps[index](1) end
end

local function make_parent(name, category, hp, hp_max, scale)
	local entity = {name = name, _grug_disposition = category,
		health = hp, hp_max = hp_max}
	local parent = object({
		selectionbox = {-0.3, 0, -0.3, 0.3, 2, 0.3},
		visual_size = scale or {x = 1, y = 1}, hp_max = hp_max,
	}, entity)
	entity.object = parent
	return parent, entity
end

local aggressive, aggressive_entity = make_parent("grug_mobs:wolf",
	"aggressive", 50, 100, {x = 2, y = 4})
local carrier = assert(grug_core.create_tag_carrier(aggressive))
assert(grug_core.set_tag_carrier_text(carrier, "Wolf"))
assert(carrier.properties.nametag_color == "#ff4b4b",
	"invalid aggressive setting did not fall back")
assert(carrier.properties.nametag_bgcolor == "#00000040")

tick()
local bar = objects[#objects]
if disable_hp then
	assert(bar == carrier, "disabled HP setting still created a sprite")
	print("r17-display: PASS disabled HP sprite setting")
	return
end
assert(bar.entity.name == "grug_core:injured_hp_bar")
assert(bar.parent == aggressive and bar.observers.viewer)
assert(bar.properties.textures[1]:find("%[fill:31x6:1,1:#39d353ff"),
	"50 percent fill differs")
assert(bar.properties.visual_size.x == 0.4 and
	bar.properties.visual_size.y == 0.025, "parent scale correction differs")
assert(math.abs(bar.attach_position.y - 5.3) < 0.0001,
	"selection-box anchor differs")
local stable_property_writes = bar.property_writes
local stable_observer_writes = bar.observer_writes
tick()
assert(bar.property_writes == stable_property_writes,
	"unchanged percentage rewrote the sprite")
assert(bar.observer_writes == stable_observer_writes,
	"unchanged observers were resent")

aggressive_entity.health = 49
tick()
assert(bar.property_writes == stable_property_writes + 1,
	"integer percentage change did not update once")
viewer.pos.x = 31
tick()
assert(next(bar.observers) == nil, "HP bar escaped nametag hysteresis")
aggressive_entity.health = 100
tick()
assert(not bar.valid, "full-health bar survived")

local neutral = make_parent("grug_mobs:boar", "neutral", 10, 10)
local neutral_carrier = grug_core.create_tag_carrier(neutral)
grug_core.set_tag_carrier_text(neutral_carrier, "Boar")
assert(neutral_carrier.properties.nametag_color == "#abcdef99",
	"valid configured color was not used")

local guard = make_parent("grug_mobs:royal_guard_human", nil, 10, 20)
local guard_carrier = grug_core.create_tag_carrier(guard)
grug_core.set_tag_carrier_text(guard_carrier, "Royal Guard")
assert(guard_carrier.properties.nametag_color == "#b76cff")

local civilian, civilian_entity = make_parent("grug_mobs:villager_human",
	nil, 50, 100)
civilian_entity._grug_noncombatant = true
local npc_carrier = grug_core.create_tag_carrier(civilian)
grug_core.set_tag_carrier_text(npc_carrier, "Innkeeper")
assert(npc_carrier.properties.nametag_color == "#d8c5ff")

local critter = make_parent("grug_mobs:rabbit", "critter", 1, 1)
local critter_carrier = grug_core.create_tag_carrier(critter)
grug_core.set_tag_carrier_text(critter_carrier, "Rabbit")
assert(critter_carrier.properties.nametag_color == "#ffffff")

local player = object({selectionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}}, nil,
	"hero")
local player_carrier = grug_core.create_tag_carrier(player, "hero")
grug_core.set_tag_carrier_text(player_carrier, "Hero")
assert(player_carrier.properties.nametag_color == "#ffffff")

viewer.pos.x = 10
tick()
for index = 1, #objects do
	local child = objects[index]
	if child.valid and child.entity.name == "grug_core:injured_hp_bar" then
		assert(child.parent == guard,
			"noncombatant, critter or player received an HP bar")
	end
end
grug_core.remove_tag_carrier(guard_carrier)
for index = 1, #objects do
	local child = objects[index]
	if child.entity.name == "grug_core:injured_hp_bar" and child.parent == guard then
		assert(not child.valid, "HP bar survived carrier lifecycle cleanup")
	end
end

print("r17-display: PASS categories, settings fallback, shared observers, " ..
	"integer HP updates, stable scale, eligibility and cleanup")
