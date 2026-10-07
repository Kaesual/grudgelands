-- Disposable engine probe (Round 41 lane CR, the production mapgen crash).
-- Never shipped: tools/r41_cr/engine.sh stages it through
-- tools/luanti_headless.sh with one plan file as plan.txt.
--
-- The plan is one step per line, run in order (no player is needed):
--   emerge X Y Z           generate the map chunk holding node (X,Y,Z) and
--                          wait until the engine reports the block
--   wait S                 let the server run S seconds (liquid ticks)
--   census X1 Y1 Z1 X2 Y2 Z2
--                          log every node name in that box with its count
--                          (an ungenerated block reads as ignore)
--   place X Y Z NAME       core.set_node, e.g. a foreign node in the top
--                          layer of a chunk not generated yet
--   water_over_air X1 Y Z1 X2 Z2
--                          a water source above every air node of layer Y
--                          in that box (cave water reaching those openings);
--                          the liquid tick and the water guard do the rest
--   continue_after_severe  do not stop at the first severe report
--   shutdown               stop the server
-- A severe report (grug_core.severe, relayed from the mapgen environment) is
-- recorded as the red chat message every player would see; the probe counts
-- the messages and, unless told otherwise, stops generating at the first one
-- (the lane's stop rule) and shuts down.

local P = "[r41cr_probe] "
local function log(msg) core.log("action", P .. msg) end

core.settings:set("server_unload_unused_data_timeout", "3600")

local modpath = core.get_modpath(core.get_current_modname())
local steps = {}
local file = io.open(modpath .. "/plan.txt", "r")
if file then
	for line in file:lines() do
		line = line:gsub("#.*$", "")
		local words = {}
		for word in line:gmatch("%S+") do words[#words + 1] = word end
		if #words > 0 then steps[#steps + 1] = words end
	end
	file:close()
end
log("plan with " .. #steps .. " steps")

-- Every chat message (the severe relay's red line among them) is recorded.
local chat_messages, severe_seen = 0, 0
local stop_at_severe = true
local original_chat_send_all = core.chat_send_all
function core.chat_send_all(message)
	chat_messages = chat_messages + 1
	if tostring(message):find("Severe server error", 1, true) then
		severe_seen = severe_seen + 1
	end
	log("chat_send_all #" .. chat_messages .. ": " .. tostring(message))
	return original_chat_send_all(message)
end

local function number(words, index)
	local value = tonumber(words[index])
	assert(value, "plan step " .. table.concat(words, " ") .. ": number expected")
	return value
end

local function census(p1, p2)
	local vm = core.get_voxel_manip(p1, p2)
	local emin, emax = vm:get_emerged_area()
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local counts, names = {}, {}
	for z = p1.z, p2.z do
		for y = p1.y, p2.y do
			for x = p1.x, p2.x do
				local cid = data[area:index(x, y, z)]
				local name = core.get_name_from_content_id(cid)
				if not counts[name] then
					counts[name] = 0
					names[#names + 1] = name
					log(("  first %s at (%d,%d,%d)"):format(name, x, y, z))
				end
				counts[name] = counts[name] + 1
			end
		end
	end
	table.sort(names)
	local parts = {}
	for _, name in ipairs(names) do parts[#parts + 1] = name .. "=" .. counts[name] end
	log(("census (%d,%d,%d)-(%d,%d,%d): %s"):format(p1.x, p1.y, p1.z, p2.x, p2.y,
		p2.z, table.concat(parts, " ")))
end

local started = 0
local run_step
local function next_step(index)
	core.after(0, run_step, index + 1)
end

function run_step(index)
	if stop_at_severe and severe_seen > 0 then
		log(("stop rule: severe report seen, %d remaining steps skipped"):format(
			#steps - index + 1))
		index = #steps + 1
	end
	local words = steps[index]
	if not words then
		log(("done after %.1f s: chat messages %d, severe %d"):format(
			(core.get_us_time() - started) / 1e6, chat_messages, severe_seen))
		core.request_shutdown("r41cr probe done", false, 0)
		return
	end
	local kind = words[1]
	if kind == "emerge" then
		local pos = {x = number(words, 2), y = number(words, 3), z = number(words, 4)}
		local t0 = core.get_us_time()
		log(("emerge (%d,%d,%d) ..."):format(pos.x, pos.y, pos.z))
		core.emerge_area(pos, pos, function(_, action, remaining)
			if remaining > 0 then return end
			log(("emerge (%d,%d,%d) action=%s wall=%.2f s"):format(pos.x, pos.y,
				pos.z, tostring(action), (core.get_us_time() - t0) / 1e6))
			-- the main environment's on_generated (the relay) runs before this
			-- callback; one step later the chat message is in
			core.after(0.5, run_step, index + 1)
		end)
	elseif kind == "wait" then
		core.after(number(words, 2), run_step, index + 1)
	elseif kind == "census" then
		census({x = number(words, 2), y = number(words, 3), z = number(words, 4)},
			{x = number(words, 5), y = number(words, 6), z = number(words, 7)})
		next_step(index)
	elseif kind == "place" then
		local pos = {x = number(words, 2), y = number(words, 3), z = number(words, 4)}
		core.set_node(pos, {name = words[5]})
		log(("placed %s at (%d,%d,%d), now %s"):format(words[5], pos.x, pos.y, pos.z,
			core.get_node(pos).name))
		next_step(index)
	elseif kind == "water_over_air" then
		local x1, y, z1 = number(words, 2), number(words, 3), number(words, 4)
		local x2, z2 = number(words, 5), number(words, 6)
		local placed = 0
		for z = z1, z2 do
			for x = x1, x2 do
				if core.get_node({x = x, y = y, z = z}).name == "air" then
					core.set_node({x = x, y = y + 1, z = z}, {name = "default:water_source"})
					placed = placed + 1
				end
			end
		end
		log(("water_over_air layer %d: %d water sources placed"):format(y, placed))
		next_step(index)
	elseif kind == "continue_after_severe" then
		stop_at_severe = false
		next_step(index)
	elseif kind == "shutdown" then
		run_step(#steps + 1)
	else
		error("unknown plan step " .. kind)
	end
end

core.register_on_mods_loaded(function()
	core.after(1, function()
		started = core.get_us_time()
		run_step(1)
	end)
end)
