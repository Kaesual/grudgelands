-- R8-TAGS known-answer test for the shared observer-managed tag carrier.
-- Usage: lua kat.lua /absolute/repository/root
-- MUTATION=1 distance/hysteresis, 2 owner exclusion, 3 text propagation,
-- 4 orphan cleanup.

local function run(repo)
	assert(type(repo) == "string" and repo:sub(1, 1) == "/",
		"absolute repository root required")
	local mutation = tonumber(os.getenv("MUTATION") or "") or 0
	local saved = {
		core = rawget(_G, "core"),
		grug_core = rawget(_G, "grug_core"),
	}

local function equal(actual, expected, label)
	if actual ~= expected then
		error("r8 tags: " .. label .. ": expected " .. tostring(expected) ..
			", got " .. tostring(actual), 0)
	end
end

local function keys(set)
	local result = {}
	for key in pairs(set or {}) do result[#result + 1] = key end
	table.sort(result)
	return table.concat(result, ",")
end

local callbacks = {globalstep = {}}
local entity_defs = {}
local players = {}

local function new_object(properties)
	local object = {
		valid = true,
		properties = properties or {},
		property_writes = 0,
		observer_writes = 0,
		observers = nil,
	}
	function object:is_valid() return self.valid end
	function object:get_pos() return self.pos end
	function object:get_properties() return self.properties end
	function object:set_properties(values)
		self.property_writes = self.property_writes + 1
		for key, value in pairs(values) do
			if not (mutation == 3 and key == "nametag") then
				self.properties[key] = value
			end
		end
	end
	function object:set_attach(parent)
		self.parent = parent
	end
	function object:get_attach() return self.parent end
	function object:set_observers(value)
		self.observer_writes = self.observer_writes + 1
		self.observers = value
	end
	function object:get_luaentity() return self.entity end
	function object:remove()
		if mutation ~= 4 then self.valid = false end
	end
	return object
end

core = {
	get_connected_players = function() return players end,
	register_globalstep = function(fn)
		callbacks.globalstep[#callbacks.globalstep + 1] = fn
	end,
	register_entity = function(name, def) entity_defs[name] = def end,
	add_entity = function(pos, name)
		local def = assert(entity_defs[name], "registered carrier entity")
		local object = new_object({})
		object.pos = {x = pos.x, y = pos.y, z = pos.z}
		object.entity = {name = name, object = object}
		def.on_activate(object.entity)
		return object
	end,
}

grug_core = {}
dofile(repo .. "/mods/CORE/grug_core/tag_carrier.lua")

local function new_player(name, x)
	local player = new_object({
		selectionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	})
	player.name = name
	player.pos = {x = x, y = 0, z = 0}
	function player:get_player_name() return self.name end
	return player
end

local parent = new_object({
	selectionbox = {-0.4, -0.2, -0.4, 0.4, 2.1, 0.4},
})
parent.pos = {x = 0, y = 0, z = 0}
local alice = new_player("Alice", 24)
local bob = new_player("Bob", 27)
local cara = new_player("Cara", 31)
players = {alice, bob, cara}
grug_core.refresh_tag_player_snapshot()

local carrier = assert(grug_core.create_tag_carrier(parent), "carrier created")
equal(carrier.parent, parent, "carrier attachment")
equal(carrier.properties.selectionbox[5], 2.1, "parent nametag height retained")
equal(carrier.observer_writes, 1, "activation writes empty observer set once")

grug_core.update_tag_carrier_observers(carrier, parent)
if mutation == 1 then carrier.observers.Cara = true end
equal(keys(carrier.observers), "Alice", "initial per-viewer show set")
equal(carrier.observer_writes, 2, "initial set written once")
grug_core.update_tag_carrier_observers(carrier, parent)
equal(carrier.observer_writes, 2, "unchanged set not resent")

alice.pos.x = 27
bob.pos.x = 24
grug_core.refresh_tag_player_snapshot()
grug_core.update_tag_carrier_observers(carrier, parent)
equal(keys(carrier.observers), "Alice,Bob", "independent hysteresis states")
alice.pos.x = 31
grug_core.refresh_tag_player_snapshot()
grug_core.update_tag_carrier_observers(carrier, parent)
equal(keys(carrier.observers), "Bob", "hide beyond thirty")

local player_carrier = grug_core.create_tag_carrier(alice)
local owner_name = "Alice"
if mutation == 2 then owner_name = nil end
alice.pos.x = 0
bob.pos.x = 10
cara.pos.x = 40
grug_core.refresh_tag_player_snapshot()
grug_core.update_tag_carrier_observers(player_carrier, alice, owner_name)
equal(keys(player_carrier.observers), "Bob", "owner excluded from own carrier")

equal(grug_core.set_tag_carrier_text(carrier,
	"Elite Boar [Lv 8] 40/40"), true, "initial text write")
equal(carrier.properties.nametag, "Elite Boar [Lv 8] 40/40",
	"tier and HP text propagation")
equal(grug_core.set_tag_carrier_text(carrier,
	"!! Elite Boar [Lv 8] 21/40"), true, "telegraph and damage write")
equal(carrier.properties.nametag, "!! Elite Boar [Lv 8] 21/40",
	"prefix and changed HP propagation")
equal(grug_core.set_tag_carrier_text(carrier,
	"!! Elite Boar [Lv 8] 21/40"), false, "unchanged text not resent")

local carrier_def = entity_defs["grug_core:tag_carrier"]
carrier.parent = nil
carrier_def.on_step(carrier.entity)
equal(carrier.valid, false, "orphan removes itself on next step")

local output = "r8_tags=observers_Alice_then_Alice+Bob_then_Bob " ..
	"owner_excluded text_prefix_hp lifecycle_removed\n"
rawset(_G, "core", saved.core)
rawset(_G, "grug_core", saved.grug_core)
return output
end

return run
