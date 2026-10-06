-- Round 40 lane V4: GUI probe for Charge as a dash and the cooldown overlay
-- (docs/planning/round40-plan.md §4.1 "V4 Probe", research §3.1 and §3.3).
-- Tools only, never shipped: copy this folder into a test world's worldmods
-- (README.md: install, every command, the report form).
--
--   /psetup <course> [mob <entity>] | back | clear    test courses
--   /pdummy [<m>] [mob <entity>] | clear              a target on real terrain
--   /pcharge <variant> [key=value ...]                 one Charge
--   /plead <m>                                         a static Body lead
--   /pcd ...                                           the cooldown overlay
--   /pbench                                            server-side timings

local MOD = core.get_current_modname()
local path = core.get_modpath(MOD)
local P = {MOD = MOD, path = path}
P.planner = dofile(path .. "/planner.lua")
P.hudmath = dofile(path .. "/hudmath.lua")
P.shapes = dofile(path .. "/shapes.lua")

function P.say(name, msg)
	for line in tostring(msg):gmatch("[^\n]+") do
		core.chat_send_player(name, "[r40] " .. line)
		core.log("action", "[r40 " .. name .. "] " .. line)
	end
end

dofile(path .. "/course.lua")(P)
dofile(path .. "/charge.lua")(P)
dofile(path .. "/overlay.lua")(P)
dofile(path .. "/bench.lua")(P)

local function words(param)
	local out = {}
	for w in param:gmatch("%S+") do out[#out + 1] = w end
	return out
end

local function player_of(name)
	local player = core.get_player_by_name(name)
	if not player then return nil, "player not found" end
	return player
end

core.register_chatcommand("psetup", {
	params = "<" .. table.concat(P.shapes.ORDER, "|") .. "> [mob <entity>] | back | clear",
	description = "R40 probe: build a Charge test course next to you (temporary nodes)",
	privs = {server = true},
	func = function(name, param)
		local player, err = player_of(name)
		if not player then return false, err end
		local w = words(param)
		if w[1] == "clear" then
			local restored, kept = P.course.clear(name)
			if kept > 0 then
				return false, ("%d nodes restored, %d still unloaded and kept: walk back to the course and /psetup clear again")
					:format(restored, kept)
			end
			return true, ("course removed, %d nodes restored"):format(restored)
		elseif w[1] == "back" then
			return P.course.back(player)
		elseif not w[1] then
			local lines = {"courses:"}
			for _, key in ipairs(P.shapes.ORDER) do
				lines[#lines + 1] = ("  %s: %s"):format(key, P.shapes.LIST[key].text)
			end
			return true, table.concat(lines, "\n")
		end
		local mob = w[2] == "mob" and w[3] or nil
		return P.course.build(player, w[1], mob)
	end,
})

core.register_chatcommand("pdummy", {
	params = "[<metres>] [mob <entity>] | clear",
	description = "R40 probe: a Charge target on the real terrain ahead of you",
	privs = {server = true},
	func = function(name, param)
		local player, err = player_of(name)
		if not player then return false, err end
		local w = words(param)
		if w[1] == "clear" then
			P.course.remove_targets(name)
			return true, "targets removed (a course stays until /psetup clear)"
		end
		local dist = tonumber(w[1]) or 8
		local k = tonumber(w[1]) and 2 or 1
		local mob = w[k] == "mob" and w[k + 1] or nil
		return P.course.dummy(player, dist, mob)
	end,
})

-- key=value options of /pcharge; numbers only, except anim.
local function charge_opts(list)
	local o = {}
	for k, v in pairs(P.charge.DEFAULTS) do o[k] = v end
	for i = 2, #list do
		local k, v = list[i]:match("^(%w+)=(%S+)$")
		if not k or o[k] == nil then return nil, "unknown option " .. list[i] end
		if k == "anim" then
			o[k] = v
		else
			o[k] = tonumber(v)
			if not o[k] then return nil, "not a number: " .. list[i] end
		end
	end
	if o.speed <= 0 then return nil, "speed must be positive" end
	return o
end

core.register_chatcommand("pcharge", {
	params = "<teleport|ghost|physical|path|push> [speed=16] [lead=0] [fov=0] " ..
		"[leadin=0.1] [hold=0.1] [snap=0] [anim=walk|none] [step=0.6] " ..
		"[hopspeed=1] [gmax=50] [maxhop=6] [rise=1.6] [drop=4] [clear=0.35]",
	description = "R40 probe: Charge the probe target with one variant",
	privs = {server = true},
	func = function(name, param)
		local player, err = player_of(name)
		if not player then return false, err end
		local w = words(param)
		local variant = w[1]
		if not variant then return false, "which variant? teleport|ghost|physical|path|push" end
		local opts, why = charge_opts(w)
		if not opts then return false, why end
		local target = P.course.target(name)
		if not target then return false, "no probe target: /psetup <course> or /pdummy first" end
		local ok, msg = P.charge.start(player, target, variant, opts)
		if not ok then return false, msg end
		return true
	end,
})

core.register_chatcommand("plead", {
	params = "<metres> (0 clears)",
	description = "R40 probe: hold a relative Body lead to check its direction in third person",
	privs = {server = true},
	func = function(name, param)
		local player, err = player_of(name)
		if not player then return false, err end
		local m = tonumber(param) or 0
		if m == 0 then
			player:set_bone_override("Body", nil)
			return true, "Body override cleared"
		end
		local vs = player:get_properties().visual_size or {y = 1}
		player:set_bone_override("Body", {position = {vec = {x = 0, y = 0,
			z = m * 10 / (vs.y > 0 and vs.y or 1)}, interpolation = 0.2}})
		return true, ("Body moved %g m along the model's +z (forward expected)"):format(m)
	end,
})

local DEMO = {2, 5, 10, 30, 60, 65, 120, 300}

core.register_chatcommand("pcd", {
	params = "<slot> <seconds> | demo | clear | number text|shadow|image|none | " ..
		"layout exact|plain | textsize <x> | digitsize <share> | itemcount <n> | " ..
		"gui <gui_scaling> | maxwidth <w> | info",
	description = "R40 probe: fake cooldowns on the hotbar (the overlay)",
	func = function(name, param)
		local player, err = player_of(name)
		if not player then return false, err end
		local ov = P.overlay
		local st = ov.settings_for(name)
		local w = words(param)
		local cmd, arg = w[1], w[2]
		local n = tonumber(arg)
		if tonumber(cmd) then
			local slot, seconds = tonumber(cmd), n
			if not seconds or seconds <= 0 then return false, "/pcd <slot> <seconds>" end
			return ov.start(player, slot, seconds)
		elseif cmd == "demo" then
			local count = math.min(player:hud_get_hotbar_itemcount(),
				player:get_inventory():get_size("main"))
			for slot = 1, count do ov.start(player, slot, DEMO[(slot - 1) % #DEMO + 1]) end
			return true, "demo: " .. table.concat(DEMO, " s, ") .. " s on slots 1..8 (repeating)"
		elseif cmd == "clear" then
			ov.clear(player)
			return true, "cooldowns cleared"
		elseif cmd == "number" and (arg == "text" or arg == "shadow" or arg == "image" or arg == "none") then
			st.number = arg
		elseif cmd == "layout" and (arg == "exact" or arg == "plain") then
			st.layout_mode = arg
		elseif cmd == "textsize" and n and n > 0 then
			st.textsize = n
		elseif cmd == "digitsize" and n and n > 0 and n <= 1 then
			st.digitsize = n
		elseif cmd == "itemcount" and n and n >= 1 and n <= 32 then
			player:hud_set_hotbar_itemcount(math.floor(n))
		elseif cmd == "gui" and n and n > 0 then
			st.gui = n
		elseif cmd == "maxwidth" and n and n > 0 and n <= 1 then
			st.maxwidth = n
		elseif cmd == "info" or not cmd then
			return true, ov.describe(player)
		else
			return false, "unknown: /pcd " .. param
		end
		ov.refresh(player)
		return true, ov.describe(player)
	end,
})

core.register_chatcommand("pbench", {
	description = "R40 probe: server-side timings of the planner and the overlay pass",
	privs = {server = true},
	func = function(name)
		P.say(name, table.concat(P.bench.quick(), "\n"))
		return true
	end,
})

local registered = {}
for _, c in ipairs({"psetup", "pdummy", "pcharge", "plead", "pcd", "pbench"}) do
	if core.registered_chatcommands[c] then registered[#registered + 1] = "/" .. c end
end
core.log("action", "[" .. MOD .. "] loaded, commands registered: " .. table.concat(registered, " "))
