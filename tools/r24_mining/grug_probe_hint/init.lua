-- Round 24 playtest-fix probe (disposable, never shipped): in the Orc start
-- town, probe diggers of the Orc's own faction punch, dig and place through
-- the real registered callbacks (the node's on_punch/on_dig as wrapped by
-- grug_abilities, builtin node_dig/item_place_node, grug_materials' wrapper
-- and violation handler). Every refused action must show exactly one flash,
-- the protection line, whatever node or item is involved. Ends the server;
-- "RESULT PASS" is the verdict.

local PREFIX = "[r24_hint_probe] "
local checks, failures = 0, 0
local function log(message) core.log("action", PREFIX .. message) end
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		core.log("error", PREFIX .. "FAIL " .. label)
	end
	return ok
end

local probes = {} -- name -> fake player
local flashes = {} -- name -> {{message, color}, ...}

local function fake_player(name, item, pos)
	local stack = ItemStack(item)
	local meta = {get_string = function() return "" end,
		get_int = function() return 0 end, get_float = function() return 0 end,
		set_string = function() end, set_int = function() end}
	local p = {
		is_player = function() return true end,
		get_hp = function() return 20 end,
		get_player_name = function() return name end,
		get_wielded_item = function() return ItemStack(stack) end,
		set_wielded_item = function() return true end,
		get_wield_index = function() return 1 end,
		get_player_control = function() return {dig = true} end,
		get_pos = function() return vector.offset(pos, 0, 1, -2) end,
		get_look_dir = function() return {x = 0, y = 0, z = 1} end,
		get_look_horizontal = function() return 0 end,
		get_look_vertical = function() return 0 end,
		get_properties = function() return {eye_height = 1.625} end,
		get_eye_offset = function() return vector.new(0, 0, 0) end,
		get_meta = function() return meta end,
		get_inventory = function() return nil end,
	}
	probes[name] = p
	flashes[name] = {}
	return p
end

local function install_hooks()
	local get_player = core.get_player_by_name
	core.get_player_by_name = function(name)
		return probes[name] or get_player(name)
	end
	local faction = grug_core.get_player_faction
	grug_core.get_player_faction = function(name)
		if probes[name] then return "throng" end
		return faction(name)
	end
	local flash = grug_core.flash
	grug_core.flash = function(player, message, color)
		local name = player and player.get_player_name and player:get_player_name()
		if name and probes[name] then
			local list = flashes[name]
			list[#list + 1] = {message, color}
			return true
		end
		return flash(player, message, color)
	end
	local chat = core.chat_send_player
	core.chat_send_player = function(name, message)
		if probes[name] then
			local list = flashes[name]
			list[#list + 1] = {"CHAT:" .. message}
			return
		end
		return chat(name, message)
	end
end

local function diggable(stack, def)
	local params = core.get_dig_params(def.groups or {}, stack:get_tool_capabilities())
	if params.diggable then return true end
	return core.get_dig_params(def.groups or {},
		ItemStack(""):get_tool_capabilities()).diggable
end

local serial = 0
local function run_dig_case(pos, node_name, wield)
	serial = serial + 1
	local name = "r24hint" .. serial
	-- Solid support below, so an attached node (torch) is not dropped by
	-- builtin falling.lua's punch check (an artifact of a floating torch).
	core.set_node(vector.offset(pos, 0, -1, 0), {name = "default:stone"})
	core.set_node(pos, {name = node_name, param2 = 1})
	local node = core.get_node(pos)
	local def = core.registered_nodes[node_name]
	local p = fake_player(name, wield, pos)
	local pointed = {type = "node", under = pos, above = vector.offset(pos, 0, 1, 0)}
	local ok_punch, err_punch = pcall(def.on_punch, pos, node, p, pointed)
	local dug = "not attempted"
	if diggable(ItemStack(wield), def) then
		local ok, result = pcall(def.on_dig, pos, node, p)
		dug = ok and tostring(result) or ("error " .. tostring(result))
	end
	local label = node_name .. " with '" .. wield .. "'"
	local list = flashes[name]
	check(ok_punch, label .. ": punch ran (" .. tostring(err_punch) .. ")")
	check(core.get_node(pos).name == node_name, label .. ": node kept")
	check(#list == 1 and list[1][1] == "Town – protected" and
		list[1][2] == grug_core.FLASH_COLOR.notice,
		label .. ": one notice flash, got " .. #list .. " " ..
		tostring(list[1] and list[1][1]))
	log(("DIG %-24s %-24s dig=%s -> %s"):format(node_name, "'" .. wield .. "'", dug,
		list[1] and list[1][1] or "(none)"))
end

local function run_place_case(pos, item)
	serial = serial + 1
	local name = "r24hint" .. serial
	core.set_node(pos, {name = "air"})
	local p = fake_player(name, item, pos)
	local def = core.registered_items[item]
	local pointed = {type = "node", under = vector.offset(pos, 0, -1, 0), above = pos}
	local ok, err = pcall(def.on_place, ItemStack(item), p, pointed)
	local list = flashes[name]
	check(ok, "place " .. item .. " ran (" .. tostring(err) .. ")")
	check(core.get_node(pos).name == "air", "place " .. item .. " refused")
	check(#list == 1 and list[1][1] == "Town – protected",
		"place " .. item .. ": one flash, got " .. #list)
	log(("PLACE %-24s -> %s"):format(item, list[1] and list[1][1] or "(none)"))
end

local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r24 hint probe done", false, 0)
end

core.after(2, function()
	local anchor = grug_core.start_anchor("throng", "orc")
	if not check(anchor ~= nil, "orc start anchor") then return finish() end
	local minp = vector.offset(anchor, -8, -4, -8)
	local maxp = vector.offset(anchor, 8, 12, 8)
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		core.after(0, function()
			install_hooks()
			local base = vector.offset(anchor, -6, 6, 3)
			log("town anchor " .. core.pos_to_string(anchor) .. " protected for throng: " ..
				tostring(core.is_protected(base, "r24hint_check")) ..
				" reason " .. tostring(grug_core.protection_reason(base, "r24hint_check")))
			-- A real town node under the anchor, plus the playtest's node kinds.
			local town_node = core.get_node(vector.offset(anchor, 0, -1, 0)).name
			local names = {"default:dirt", "default:torch", "default:tree",
				"default:wood", "grug_materials:slate", "default:dirt_with_grass"}
			if town_node ~= "air" and town_node ~= "ignore" and
					core.registered_nodes[town_node] and
					core.registered_nodes[town_node].diggable ~= false then
				names[#names + 1] = town_node
			end
			local wields = {"", "default:pick_bronze", "default:apple",
				"default:shovel_bronze"}
			if core.registered_items["grug_abilities:strike"] then
				wields[#wields + 1] = "grug_abilities:strike"
			end
			local index = 0
			for _, node_name in ipairs(names) do
				for _, wield in ipairs(wields) do
					index = index + 1
					run_dig_case(vector.offset(base, index % 12, 2 * math.floor(index / 12), 0),
						node_name, wield)
				end
			end
			for i, item in ipairs({"default:dirt", "default:wood", "default:torch",
					"grug_materials:slate"}) do
				run_place_case(vector.offset(base, i, 4, 2), item)
			end
			finish()
		end)
	end)
end)
