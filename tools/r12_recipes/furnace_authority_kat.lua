-- Focused real-code check for Cooking ownership at furnace extraction.
local root = arg[1] or "."

local function stack(value)
	local text = type(value) == "table" and value:to_string() or tostring(value or "")
	local name = text:match("^(%S+)") or ""
	local count = tonumber(text:match(" (%d+)$")) or (name == "" and 0 or 1)
	local result = {}
	function result:get_name() return name end
	function result:get_count() return count end
	function result:is_empty() return name == "" or count == 0 end
	function result:to_string() return self:is_empty() and "" or name .. " " .. count end
	return result
end
ItemStack = stack

local engine = {
	["grug_cooking:bread"] = "grug_cooking:wild_grain",
	["mobs:meat"] = "mobs:meat_raw",
	["grug_fishing:cooked_fish"] = "grug_mobs:raw_fish",
}
local values, messages = {}, {}
local node_meta = {}
function node_meta:get_string(key) return tostring(values[key] or "") end
function node_meta:set_string(key, value) values[key] = tostring(value) end
function node_meta:get_int(key) return tonumber(values[key]) or 0 end
function node_meta:set_int(key, value) values[key] = tonumber(value) or 0 end
function node_meta:get_inventory()
	return {get_stack = function() return ItemStack("") end}
end

core = {
	registered_nodes = { ["default:furnace"] = {}, ["default:furnace_active"] = {} },
	registered_items = {}, registered_craft_predicts = {}, registered_on_crafts = {},
}
for output, input in pairs(engine) do
	core.registered_items[output] = {}; core.registered_items[input] = {}
end
function core.get_all_craft_recipes(output)
	local input = engine[output]
	return input and {{method = "cooking", items = {input}, output = output}} or nil
end
function core.get_item_group() return 0 end
function core.register_craft() error("existing recipe was installed twice", 0) end
function core.register_craft_predict(fn) core.registered_craft_predicts[#core.registered_craft_predicts + 1] = fn end
function core.register_on_craft(fn) core.registered_on_crafts[#core.registered_on_crafts + 1] = fn end
function core.register_on_mods_loaded() end
function core.register_on_leaveplayer() end
function core.register_on_player_receive_fields() end
function core.after() end
function core.get_gametime() return 1 end
function core.get_meta() return node_meta end
function core.override_item(name, changes)
	for key, value in pairs(changes) do core.registered_nodes[name][key] = value end
end
function core.formspec_escape(value) return tostring(value) end
function core.chat_send_player(name, text) messages[#messages + 1] = name .. ":" .. text end
function core.log() end

grug_xp = {get_level = function() return 1 end}
grug_inventory = {refresh = function() end}
grug_items = nil
grug_brewing = nil
grug_jobs = {}

dofile(root .. "/mods/PLAYER/grug_jobs/registry.lua")
dofile(root .. "/mods/PLAYER/grug_jobs/state.lua")
dofile(root .. "/mods/PLAYER/grug_jobs/stations.lua")

for output, input in pairs(engine) do
	grug_jobs.register_ingredient_tier(input, 1)
	grug_jobs.register_recipe({profession = "cooking", tier = 1,
		station = "furnace", inputs = {input}, output = output,
		hint = "Furnace", existing_engine_recipe = true})
	local resolved = grug_jobs.recipe_for_craft("furnace", output, {input})
	assert(resolved and resolved.profession == "cooking" and resolved.tier == 1)
end

local player = {}
function player:get_player_name() return "cook" end
function player:get_meta() return node_meta end
function player:get_hp() return 20 end
function player:is_player() return true end

local furnace = core.registered_nodes["default:furnace"]
for output in pairs(engine) do
	local result = ItemStack(output)
	assert(furnace.allow_metadata_inventory_take({}, "dst", 1, result, player) == 0,
		output .. " escaped the unlearned Cooking gate")
end
assert(grug_jobs.learn(player, "cooking"))
local before = grug_jobs.crafts_in_tier(player, "cooking")
for output in pairs(engine) do
	local result = ItemStack(output)
	assert(furnace.allow_metadata_inventory_take({}, "dst", 1, result, player) == 1,
		output .. " was refused after learning Cooking")
	furnace.on_metadata_inventory_take({}, "dst", 1, result, player)
end
assert(grug_jobs.crafts_in_tier(player, "cooking") == before + 3,
	"Cooking extraction did not record all three crafts")

print("R12 RECIPES furnace authority PASS unlearned=denied learned=3 progression=3")
