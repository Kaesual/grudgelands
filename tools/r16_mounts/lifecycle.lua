-- Isolated real-code lifecycle fixture; callable by the combined final runner.
return function(root)
	local env = setmetatable({}, {__index = _G})
	env._G = env
	local callbacks = {join = {}, leave = {}, shutdown = {}, die = {}}
	local entities, players, deferred = {}, {}, {}
	local core = {registered_nodes = {air = {walkable = false, liquidtype = "none"}}}
	env.core = core
	-- The unchanged vendored player API uses the engine's deprecated alias.
	env["minetest"] = core
	for _, kind in ipairs({"join", "leave", "die"}) do
		core["register_on_" .. kind .. "player"] = function(fn)
			callbacks[kind][#callbacks[kind] + 1] = fn
		end
	end
	core.register_on_shutdown = function(fn) callbacks.shutdown[#callbacks.shutdown + 1] = fn end
	core.register_globalstep = function() end
	core.register_on_player_hpchange = function() end
	core.register_entity = function(name, definition) entities[name] = definition end
	core.get_modpath = function(name) if name == "player_api" then return "player_api" end end
	core.get_player_by_name = function(name) return players[name] end
	core.get_connected_players = function()
		local out = {}; for _, player in pairs(players) do out[#out + 1] = player end; return out
	end
	core.global_exists = function(name) return env[name] ~= nil end
	core.after = function(_, fn, ...) deferred[#deferred + 1] = {fn, {...}} end
	core.serialize = function(value) return value end
	core.deserialize = function(value) return value end
	core.get_node_or_nil = function() return {name = "air"} end
	core.chat_send_player = function() end
	env.vector = {add = function(a, b) return {x = a.x+b.x, y = a.y+b.y, z = a.z+b.z} end}
	local function load(path) local chunk = assert(loadfile(root .. "/" .. path)); setfenv(chunk, env); chunk() end
	load("mods/BASE/player_api/api.lua")
	env.player_api.register_model("test", {textures = {"test"},
		animations = {stand = {x = 0, y = 1}, sit = {x = 2, y = 3}}})
	env.mobs = {}
	load("mods/ENTITIES/mobs/mount.lua")
	local model = {attach_y = 1, eye_y = 1, visual_size = {x = 1, y = 1},
		animation = {stand = {0, 1, 30}}, mesh = "test", textures = {"test"}}
	env.grug_mounts = {TIERS = {[1] = {mode = "land", speed = 6.4},
		[4] = {mode = "flight", speed = 10}}, model_for = function() return model end}
	env.grug_core = {clear_status = function(p) p.status = nil end,
		set_status = function(p) p.status = true end}
	env.grug_classes = {register_on_race_chosen = function() end}
	env.grug_factions = {register_on_faction_chosen = function() end}
	env.grug_visuals = {apply = function(p)
		-- Real player_api access reproduces the original missing-record failure.
		env.player_api.get_animation(p)
		p.restores = p.restores + 1
		p:set_properties({visual_size = {x = 0.8, y = 0.8}})
	end}
	load("mods/PLAYER/grug_mounts/entity.lua")
	local function object(pos, definition)
		local o = {pos = pos, valid = true, removes = 0}
		function o:is_valid() return self.valid end
		function o:get_pos() return self.pos end
		function o:get_luaentity() return self.entity end
		function o:set_properties() end
		function o:set_armor_groups() end
		function o:set_animation() end
		function o:set_attach() end
		function o:remove()
			assert(self.valid, "double remove")
			self.removes = self.removes + 1
			if definition.on_deactivate then definition.on_deactivate(self.entity) end
			self.valid = false
		end
		o.entity = setmetatable({object = o}, {__index = definition})
		return o
	end
	core.add_entity = function(pos, name, data)
		local def = assert(entities[name]); local o = object(pos, def)
		def.on_activate(o.entity, data); return o
	end
	local function player()
		local p = {restores = 0, pos = {x = 0, y = 20, z = 0}}
		function p:is_player() return true end
		function p:get_player_name() return "rider" end
		function p:get_pos() return self.pos end
		function p:set_pos(pos) self.pos = pos end
		function p:get_velocity() return {x = 1, y = 2, z = 3} end
		function p:add_velocity() end
		function p:get_attach() return self.parent end
		function p:set_attach(parent) self.parent = parent end
		function p:set_detach() self.parent = nil end
		function p:set_eye_offset(first) self.eye = first end
		function p:get_properties() return {visual_size = {x = 0.8, y = 0.8}} end
		function p:set_animation() end
		function p:set_local_animation() end
		function p:set_properties(props) self.properties = props end
		function p:get_look_horizontal() return 0 end
		function p:hud_remove() self.warning_removed = true end
		players.rider = p
		for _, fn in ipairs(callbacks.join) do fn(p) end
		env.player_api.set_model(p, "test")
		return p
	end
	local cases = 0
	for _, tier in ipairs({1, 4}) do
		for _, mode in ipairs({"leave", "leave_reverse", "shutdown", "shutdown_reverse", "manual", "death"}) do
			local p = player()
			assert(env.grug_mounts.spawn_entity(p, tier, p.pos))
			local record = env.grug_mounts.active.rider
			record.hud_id = 7
			local before = #deferred
			if mode == "manual" then
				assert(env.grug_mounts.dismount(p, "manual", false))
			elseif mode == "death" then
				for _, fn in ipairs(callbacks.die) do fn(p) end
			else
				local hooks = mode:match("^leave") and callbacks.leave or callbacks.shutdown
				-- player_api is always first; exercise either vendor/own order.
				if hooks == callbacks.leave then hooks[1](p) end
				local first = hooks == callbacks.leave and 2 or 1
				if mode:match("reverse$") then
					for i = #hooks, first, -1 do hooks[i](p) end
				else for i = first, #hooks do hooks[i](p) end end
				assert(p.restores == 0 and #deferred == before)
				assert(env.player_api.player_attached.rider == nil)
			end
			assert(not p.parent and not p.status and p.warning_removed)
			assert(not env.grug_mounts.active.rider)
			assert(record.object.removes == 1 and record.visual.removes == 1)
			assert(not record.object.entity.driver and not record.object.entity._grug_rider)
			assert(p.eye.y == 0)
			if mode == "manual" or mode == "death" then
				assert(p.restores == 1 and p.properties.visual_size.x == 0.8)
				assert(env.player_api.get_animation(p).animation == "stand")
			end
			assert(not env.grug_mounts.dismount(p))
			for _, fn in ipairs(callbacks.leave) do fn(p) end
			for _, fn in ipairs(callbacks.shutdown) do fn() end
			assert(record.object.removes == 1 and record.visual.removes == 1)
			players.rider = nil
			cases = cases + 1
		end
	end
	return "mount-lifecycle:" .. cases .. ":ok"
end
