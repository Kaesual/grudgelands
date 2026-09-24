local repo = assert(arg[1], "repository root required")
local now, node_name, timer_started = 100, "default:furnace", false
local fields = { ["grug_jobs:station_id"] = "fixture" }
local inventory_touched = false
local inventory = {
	get_size = function(_, name) return ({src=1,fuel=1,dst=4})[name] or 0 end,
	set_size = function() error("unexpected inventory resize") end,
	get_list = function() inventory_touched=true;error("public inventory processed") end,
}
local meta = {
	get_inventory = function() return inventory end,
	get_string = function(_, key) return fields[key] or "" end,
	set_string = function(_, key, value) fields[key] = value end,
	get_int = function(_, key) return tonumber(fields[key]) or 0 end,
	set_int = function(_, key, value) fields[key] = value end,
}
local callbacks, lbm, loaded
core = {
	get_modpath = function(name)
		assert(name == "grug_jobs"); return repo .. "/mods/PLAYER/grug_jobs"
	end,
	registered_nodes = {
		["default:furnace"] = {_grug_station="furnace"},
		["default:furnace_active"] = {_grug_station="furnace"},
	},
	override_item = function(name, def) if name == "default:furnace" then callbacks=def end end,
	register_on_mods_loaded = function(fn) loaded=fn end,
	register_lbm = function(def) lbm=def end,
	register_on_player_receive_fields = function() end,
	register_on_leaveplayer = function() end,
	register_globalstep = function() end,
	get_meta = function() return meta end,
	get_node_or_nil = function() return {name=node_name} end,
	get_node = function() return {name=node_name} end,
	swap_node = function(_, node) node_name=node.name end,
	get_node_timer = function() return {
		is_started=function() return timer_started end,
		start=function() timer_started=true end,
	} end,
	get_gametime = function() return now end,
	get_us_time = function() return 1 end,
	deserialize = function() return nil end,
	serialize = function() return "fixture-state" end,
}
vector = {equals=function() return false end,distance=function() return 0 end}
default = {get_inventory_drops=function() end,get_hotbar_bg=function() return "" end}
grug_jobs = {
	is_public_station = function() return true end,
	station_info = function() return {node="default:furnace"} end,
	station_book_button = function() return "" end,
}
dofile(repo .. "/mods/PLAYER/grug_jobs/workspaces.lua")
assert(loaded);loaded();assert(callbacks and callbacks.on_timer and lbm)

fields["grug_jobs:personal_burn_until"] = 110
node_name, timer_started = "default:furnace", false
lbm.action({x=0,y=0,z=0})
assert(node_name == "default:furnace_active" and timer_started,
	"activation did not restore personal light")
assert(callbacks.on_timer({x=0,y=0,z=0},1) == true and not inventory_touched,
	"public cosmetic timer processed inventory or stopped")
now = 110
assert(callbacks.on_timer({x=0,y=0,z=0},1) == false and
	node_name == "default:furnace" and fields["grug_jobs:personal_burn_until"] == 0 and
	not inventory_touched, "public cosmetic deadline did not expire cleanly")

fields["grug_jobs:personal_burn_until"] = 90
node_name, timer_started = "default:furnace_active", false
lbm.action({x=0,y=0,z=0})
assert(node_name == "default:furnace" and
	fields["grug_jobs:personal_burn_until"] == 0 and not timer_started,
	"activation retained expired personal light")
print("r21_furnace_workspaces_light_kat\tpass")
