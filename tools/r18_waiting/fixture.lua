-- Bounded real-module fixture for Round 18 package F.
return function(repo)
	local env = setmetatable({}, {__index = _G})
	env._G = env
	local callbacks = {receive = {}, join = {}, new = {}, leave = {}, progress = {}}
	local deferred, online, forms, form_count, emerges = {}, {}, {}, {}, {}
	local status = {mode = "starts", completed = 0, total = 6, percent = 0,
		ready = false, failed = false}
	local function noop() end
	local function register(bucket)
		return function(fn) bucket[#bucket + 1] = fn end
	end
	local core = {
		EMERGE_CANCELLED = 0, EMERGE_ERRORED = 1,
		factions = nil,
		registered_chatcommands = {},
		formspec_escape = function(value) return tostring(value) end,
		colorize = function(_, value) return value end,
		global_exists = function(name) return env[name] ~= nil end,
		get_player_by_name = function(name) return online[name] end,
		show_formspec = function(name, formname, spec)
			forms[name] = formname
			form_count[formname] = (form_count[formname] or 0) + 1
		end,
		close_formspec = function(name, formname)
			if forms[name] == formname then forms[name] = nil end
		end,
		after = function(_, fn) deferred[#deferred + 1] = fn end,
		register_on_player_receive_fields = register(callbacks.receive),
		register_on_joinplayer = register(callbacks.join),
		register_on_newplayer = register(callbacks.new),
		register_on_leaveplayer = register(callbacks.leave),
		register_globalstep = noop,
		register_on_player_hpchange = noop,
		register_on_mods_loaded = noop,
		register_on_respawnplayer = noop,
		chat_send_player = noop,
		log = noop,
	}
	core.register_chatcommand = function(name, def) core.registered_chatcommands[name] = def end
	setmetatable(core, {__index = function(_, key)
		if key:match("^register_") then return noop end
	end})
	env.core = core
	env.vector = {offset = function(pos, x, y, z)
		return {x = pos.x + x, y = pos.y + y, z = pos.z + z}
	end}
	local grug_core = {
		factions = {
			accord = {name = "Accord", color = "#00f"},
			throng = {name = "Throng", color = "#f00"},
		},
		zone_authority_installed = function() return true end,
		world_preparation_status = function() return status end,
		starts_ready = function() return status.ready and 6 or 0, 6 end,
		starts_preload_failed = function() return status.failed end,
		request_starts_preload = function()
			status.failed = false
			return true
		end,
		register_on_preparation_progress = register(callbacks.progress),
		register_on_starts_progress = noop,
		hold_movement = function(player) player.held = true end,
		release_movement = function(player) player.held = false end,
		create_tag_carrier = function()
			return {is_valid = function() return true end}
		end,
		set_tag_carrier_text = function() return true end,
		remove_tag_carrier = noop,
		start_position = function() return {x = 90, y = 8, z = 70} end,
		invalidate_combat_identity = noop,
	}
	env.grug_core = grug_core
	local function load(path)
		local fn = assert(loadfile(repo .. "/" .. path))
		setfenv(fn, env)
		return fn()
	end
	local function flush()
		while #deferred > 0 do
			local queue = deferred
			deferred = {}
			for _, fn in ipairs(queue) do fn() end
		end
	end
	local function meta(initial)
		local strings, ints = initial or {}, {}
		return {
			get_string = function(_, key) return strings[key] or "" end,
			set_string = function(_, key, value) strings[key] = value end,
			get_int = function(_, key) return ints[key] or 0 end,
			set_int = function(_, key, value) ints[key] = value end,
		}
	end
	local function player(name, initial)
		local p = {name = name, meta = meta(initial), armor = {}, pos = {x = 1, y = 2, z = 3},
			velocity = {x = 0, y = 0, z = 0}, grants = 0, teleports = 0}
		function p:get_player_name() return self.name end
		function p:get_meta() return self.meta end
		function p:get_inventory()
			return {add_item = function() p.grants = p.grants + 1 end}
		end
		function p:get_properties() return {hp_max = 100} end
		function p:get_hp() return 100 end
		function p:set_hp() end
		function p:set_nametag_attributes() end
		function p:get_armor_groups() return self.armor end
		function p:set_armor_groups(value) self.armor = value end
		function p:get_velocity() return self.velocity end
		function p:add_velocity(value) self.velocity = value end
		function p:set_pos(value) self.pos = value; self.teleports = self.teleports + 1 end
		online[name] = p
		return p
	end
	local function event(bucket, p)
		for _, fn in ipairs(callbacks[bucket]) do fn(p) end
	end
	local function receive(p, formname, fields)
		for i = #callbacks.receive, 1, -1 do
			if callbacks.receive[i](p, formname, fields or {}) then return true end
		end
		return false
	end
	local function progress()
		for _, fn in ipairs(callbacks.progress) do fn(status) end
	end
	core.emerge_area = function(_, _, callback)
		emerges[#emerges + 1] = callback
	end

	load("mods/PLAYER/grug_factions/init.lua")
	local classes = {
		registered_races = {
			human = {id = "human", name = "Human", faction = "accord", description = ""},
			orc = {id = "orc", name = "Orc", faction = "throng", description = ""},
		},
		race_ids = {accord = {"human"}, throng = {"orc"}},
		registered_classes = {warrior = {id = "warrior", name = "Warrior", description = ""}},
		class_ids = {"warrior"},
	}
	function classes.get_race(p)
		local id = p:get_meta():get_string("grug_classes:race")
		local def = classes.registered_races[id]
		return def and def.faction == env.grug_factions.get_faction(p) and id or nil
	end
	function classes.set_race(p, id)
		local def = classes.registered_races[id]
		if not def or def.faction ~= env.grug_factions.get_faction(p) then return false end
		p:get_meta():set_string("grug_classes:race", id)
		return true
	end
	function classes.get_race_def(p) return classes.registered_races[classes.get_race(p)] end
	function classes.get_class(p)
		local id = p:get_meta():get_string("grug_classes:class")
		return classes.registered_classes[id] and id or nil
	end
	function classes.set_class(p, id)
		if not classes.registered_classes[id] then return false end
		p:get_meta():set_string("grug_classes:class", id)
		p.class_sets = (p.class_sets or 0) + 1
		return true
	end
	function classes.get_class_def(p) return classes.registered_classes[classes.get_class(p)] end
	function classes.get_max_hp() return 100 end
	env.grug_classes = classes
	grug_core.get_player_race = function(name)
		local p = online[name]
		return p and classes.get_race(p) or nil
	end
	load("mods/PLAYER/grug_classes/selection.lua")

	local fresh = player("fresh")
	event("new", fresh); event("join", fresh); flush()
	assert(forms.fresh == "grug_classes:loading" and fresh.held, "pending new player waits in stasis")
	receive(fresh, "grug_factions:select", {choose_accord = true})
	receive(fresh, "grug_classes:race", {choose_human = true})
	receive(fresh, "grug_classes:class", {choose_warrior = true})
	assert(not env.grug_factions.get_faction(fresh) and not classes.get_race(fresh) and
		not classes.get_class(fresh), "forged pending submissions are inert")
	receive(fresh, "grug_classes:loading", {quit = true})
	local dismissed_count = form_count["grug_classes:loading"]
	status.completed, status.percent = 2, 33
	progress()
	assert(form_count["grug_classes:loading"] == dismissed_count, "progress respects dismissal")
	status.failed = true
	progress()
	local failure_count = form_count["grug_classes:loading"]
	progress()
	assert(failure_count == dismissed_count + 1 and
		form_count["grug_classes:loading"] == failure_count, "failure reopens exactly once")
	receive(fresh, "grug_classes:loading", {retry_spawn = true})
	assert(not status.failed, "retry reaches scheduler")
	status.ready, status.completed, status.percent = true, 6, 100
	progress()
	assert(forms.fresh == "grug_factions:select", "ready starts faction selection")
	receive(fresh, "grug_factions:select", {choose_accord = true})
	assert(forms.fresh == "grug_classes:race" and fresh.grants == 2, "faction commits once")
	receive(fresh, "grug_classes:race", {choose_human = true})
	assert(forms.fresh == "grug_classes:class", "race continues to class")
	receive(fresh, "grug_classes:class", {choose_warrior = true})
	assert(#emerges == 1, "new character waits for its arrival emerge")
	receive(fresh, "grug_classes:loading", {quit = true})
	local before_arrival_failure = form_count["grug_classes:loading"]
	emerges[1]({}, core.EMERGE_ERRORED, 0); flush()
	assert(forms.fresh == "grug_classes:loading" and
		form_count["grug_classes:loading"] == before_arrival_failure + 1,
		"arrival failure reopens once after dismissed arrival wait")
	receive(fresh, "grug_classes:loading", {quit = true})
	local dismissed_arrival_error = form_count["grug_classes:loading"]
	progress()
	assert(form_count["grug_classes:loading"] == dismissed_arrival_error,
		"repeated ready progress respects dismissed arrival error")
	receive(fresh, "grug_classes:loading", {retry_spawn = true})
	assert(#emerges == 2, "arrival retry starts a fresh emerge")
	emerges[2]({}, 2, 0); flush()
	assert(classes.get_class(fresh) == "warrior" and fresh.teleports == 1 and not fresh.held,
		"new character completes once after emerge")

	status.ready, status.failed, status.completed, status.percent = false, false, 0, 0
	local partial = player("partial", { ["grug_factions:faction"] = "throng" })
	event("join", partial); flush()
	assert(forms.partial == "grug_classes:loading", "partial character waits before race")
	status.ready = true; progress()
	assert(forms.partial == "grug_classes:race", "partial character resumes at race")

	status.ready = false
	local complete = player("complete", {
		["grug_factions:faction"] = "accord", ["grug_classes:race"] = "human",
		["grug_classes:class"] = "warrior",
	})
	event("join", complete); flush()
	assert(forms.complete == "grug_classes:loading" and complete.held, "complete character waits safely")
	status.ready = true; progress()
	assert(not complete.held and complete.teleports == 0 and complete.grants == 0 and
		(complete.class_sets or 0) == 0, "complete character resumes without recreation")

	status.ready = false
	local stale = player("stale", {
		["grug_factions:faction"] = "accord", ["grug_classes:race"] = "human",
	})
	event("join", stale); flush(); status.ready = true; progress()
	receive(stale, "grug_classes:class", {choose_warrior = true})
	local stale_callback = emerges[#emerges]
	event("leave", stale); online.stale = nil
	local replacement = player("stale", {
		["grug_factions:faction"] = "accord", ["grug_classes:race"] = "human",
	})
	event("join", replacement); flush()
	stale_callback({}, 2, 0); flush()
	assert(not classes.get_class(replacement) and replacement.teleports == 0,
		"stale callback cannot complete rejoined player")

	return "r18_waiting:v1:pending,forged,dismiss,failure,retry,ready,new,partial,complete,stale"
end
