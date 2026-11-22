-- Round 81 lane SOCIAL: the fake engines shared by portable_test.lua (the
-- checks) and measure.lua (the before/after numbers). Each builder loads the
-- REAL files of the repository at `repo` into fresh globals and returns a
-- world table; a builder replaces the globals of the one before.
local H = {}

local function counted(counters, key)
	counters[key] = (counters[key] or 0) + 1
end

------------------------------------------------------------------------------
-- Tag carriers: grug_core player_slots.lua + tag_carrier.lua.
------------------------------------------------------------------------------
function H.tags(repo)
	local W = {counters = {}, players = {}, live = {}, steps = {}}
	local registered, joins, leaves = {}, {}, {}
	local counters, live = W.counters, W.live
	local function new_object(pos, entity)
		-- get_pos hands out one table per object (the engine makes a new
		-- one per call; here the allocation measurement sees only the code
		-- under test).
		local o = {pos = pos, valid = true, entity = entity, props = {}}
		function o:is_valid() return self.valid end
		function o:get_pos()
			if not self.valid then return nil end
			return self.parent and self.parent:get_pos() or self.pos
		end
		function o:get_properties()
			counted(counters, "properties")
			return self.props
		end
		function o:set_properties(p)
			for k, v in pairs(p) do self.props[k] = v end
		end
		function o:set_attach(parent, _, offset)
			self.parent, self.offset = parent, offset
		end
		function o:get_attach() return self.parent end
		function o:get_luaentity() return self.entity end
		function o:is_player() return false end
		function o:set_observers(observers)
			counted(counters, "set_observers")
			self.observers = observers
		end
		function o:remove() self.valid = false; live[self] = nil end
		if entity then entity.object = o end
		return o
	end
	W.new_object = new_object
	_G.core = {
		settings = {get = function() return nil end,
			get_bool = function(_, _, default) return default end},
		colorspec_to_colorstring = function(v) return v end,
		registered_entities = registered,
		register_entity = function(name, def) registered[name] = def end,
		register_globalstep = function(fn) W.steps[#W.steps + 1] = fn end,
		register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
		register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
		get_connected_players = function() return W.players end,
		get_node_or_nil = function() return {name = "air"} end,
		add_entity = function(pos, name)
			local def = registered[name]
			local entity = setmetatable({name = name}, {__index = def})
			local o = new_object(pos, entity)
			live[o] = true
			if def.on_activate then def.on_activate(entity) end
			return o
		end,
	}
	_G.grug_core = {
		start_identities = function()
			return {{race_id = "human", faction_id = "accord"},
				{race_id = "orc", faction_id = "throng"}}
		end,
		settlement_socket_settlements = function()
			return {{key = "highcourt", race_id = "human"},
				{key = "gor_drazhak", race_id = "orc"}}
		end,
	}
	dofile(repo .. "/mods/CORE/grug_core/player_slots.lua")
	dofile(repo .. "/mods/CORE/grug_core/tag_carrier.lua")
	-- grug_factions' one line: a player's faction from its meta.
	grug_core.get_player_object_faction = function(player)
		counted(counters, "faction")
		return player.faction
	end
	function W.player(name, faction, x, y, z)
		local p = {name = name, faction = faction, pos = {x = x, y = y or 0, z = z or 0}}
		function p:get_pos() return self.pos end
		function p:get_player_name() return self.name end
		function p:is_player() return true end
		function p:is_valid() return true end
		function p:get_properties() return {} end
		function p:get_luaentity() return nil end
		W.players[#W.players + 1] = p
		for _, fn in ipairs(joins) do fn(p) end
		return p
	end
	-- A mob parent (its entity) at x, y, z.
	function W.mob(fields, x, y, z)
		local entity = {health = 100, hp_max = 100}
		for k, v in pairs(fields) do entity[k] = v end
		local o = new_object({x = x, y = y or 0, z = z or 0}, entity)
		o.props = {selectionbox = {-0.4, 0, -0.4, 0.4, 1.7, 0.4}, visual_size = {x = 1, y = 1}}
		live[o] = true
		return entity
	end
	-- One server step of `dtime` through every registered globalstep.
	function W.step(dtime)
		for _, fn in ipairs(W.steps) do fn(dtime) end
	end
	-- One simulated second in eight 1/8 s steps.
	function W.second()
		for _ = 1, 8 do W.step(0.125) end
	end
	-- The carriers attached to `parent` other than `held`.
	function W.foe_of(parent, held)
		for o in pairs(live) do
			if o.parent == parent and o ~= held and o.entity and
					o.entity.name == "grug_core:tag_carrier" then
				return o
			end
		end
		return nil
	end
	return W
end

------------------------------------------------------------------------------
-- Parties: grug_parties init.lua (its own ui.lua left out) and hud.lua, with
-- grug_core hud_layout.lua. `groups` is the stored party state.
------------------------------------------------------------------------------
function H.parties(repo, groups)
	local W = {counters = {}, players = {}, steps = {}, changes = {}}
	local counters = W.counters
	local joins, leaves, joined = {}, {}, {}
	local storage = {}
	W.us = 1000000
	local function serialize(value)
		local kind = type(value)
		if kind == "table" then
			local keys, parts = {}, {}
			for k in pairs(value) do keys[#keys + 1] = k end
			table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
			for _, k in ipairs(keys) do
				parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(value[k])
			end
			return "{" .. table.concat(parts, ",") .. "}"
		elseif kind == "string" then
			return ("%q"):format(value)
		end
		return tostring(value)
	end
	local next_id = 0
	for id in pairs(groups) do next_id = math.max(next_id, tonumber(id)) end
	storage.parties = "return " .. serialize({next_id = next_id, groups = groups})
	local order = {}
	_G.core = {
		get_modpath = function(name) return repo .. "/mods/PLAYER/" .. name end,
		get_current_modname = function() return "grug_parties" end,
		get_mod_storage = function()
			return {get_string = function(_, key) return storage[key] or "" end,
				set_string = function(_, key, value) storage[key] = value end}
		end,
		serialize = function(value) return "return " .. serialize(value) end,
		deserialize = function(text)
			local fn = loadstring(text)
			return fn and fn() or nil
		end,
		get_us_time = function() return W.us end,
		register_globalstep = function(fn) W.steps[#W.steps + 1] = fn end,
		register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
		register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
		register_chatcommand = function() end,
		get_player_by_name = function(name) return joined[name] and W.players[name] or nil end,
		get_connected_players = function()
			local list = {}
			for _, name in ipairs(order) do list[#list + 1] = W.players[name] end
			return list
		end,
		get_player_window_information = function()
			return {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
		end,
		chat_send_player = function() end,
		log = function() end,
		colorize = function(_, text) return text end,
	}
	_G.grug_core = {}
	dofile(repo .. "/mods/CORE/grug_core/ui.lua")
	dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
	grug_core.status_icons = {class_icon = function(class) return "icon_" .. tostring(class) end}
	_G.grug_factions = {
		get_faction = function(player) return player.faction end,
		register_on_faction_chosen = function() end,
	}
	W.level_callbacks = {}
	_G.grug_xp = {
		get_level = function(player)
			counted(counters, "level")
			return player and player.level or 1
		end,
		register_on_level_change = function(fn) W.level_callbacks[#W.level_callbacks + 1] = fn end,
	}
	_G.grug_classes = {
		get_class = function(player)
			counted(counters, "class")
			return player.class
		end,
		register_on_class_chosen = function() end,
		register_on_race_chosen = function() end,
	}
	-- init.lua loads ui.lua (the Social tab, tools/r67_social) and hud.lua;
	-- only hud.lua here.
	local real_dofile = dofile
	_G.dofile = function(path)
		if path:match("/grug_parties/ui%.lua$") then return end
		return real_dofile(path)
	end
	real_dofile(repo .. "/mods/PLAYER/grug_parties/init.lua")
	_G.dofile = real_dofile
	grug_parties.invitation_warning = function() return nil end
	grug_parties.register_on_change(function(name, reason)
		W.changes[#W.changes + 1] = {name = name, reason = reason}
	end)
	local Meta = {}
	Meta.__index = Meta
	function Meta:get_string(key)
		counted(counters, "meta")
		return self.fields[key] or ""
	end
	function Meta:set_string(key, value) self.fields[key] = value ~= "" and value or nil end
	function Meta:get_int(key)
		counted(counters, "meta")
		return tonumber(self.fields[key]) or 0
	end
	function Meta:set_int(key, value) self.fields[key] = value ~= 0 and tostring(value) or nil end
	function W.player(name, faction, class, level)
		local p = {name = name, faction = faction, class = class, level = level or 10,
			meta = setmetatable({fields = {}}, Meta), huds = {}, next_id = 0, hp = 20, hp_max = 20}
		function p:get_player_name() return self.name end
		function p:is_player() return true end
		function p:get_meta() return self.meta end
		function p:get_hp() return self.hp end
		function p:get_properties()
			counted(counters, "properties")
			return {hp_max = self.hp_max}
		end
		function p:hud_add(def)
			self.next_id = self.next_id + 1
			local copy = {}
			for k, v in pairs(def) do copy[k] = v end
			self.huds[self.next_id] = copy
			return self.next_id
		end
		function p:hud_change(id, key, value)
			counted(counters, "hud_change")
			self.huds[id][key] = value
		end
		function p:hud_remove(id) self.huds[id] = nil end
		W.players[name] = p
		return p
	end
	function W.join(p)
		joined[p.name] = true
		order[#order + 1] = p.name
		for _, fn in ipairs(joins) do fn(p) end
	end
	function W.step(seconds)
		local t = 0
		while t < seconds - 1e-9 do
			t = t + 0.1
			W.us = W.us + 100000
			for _, fn in ipairs(W.steps) do fn(0.1) end
		end
	end
	-- The texts of a player's HUD text elements, sorted.
	function W.labels(p)
		local list = {}
		for _, def in pairs(p.huds) do
			if def.type == "text" then list[#list + 1] = def.text end
		end
		table.sort(list)
		return table.concat(list, "\n")
	end
	return W
end

-- `count` parties of `size` members each (ids "1".."count"), all Accord;
-- member i of party k is "p<k>_<i>".
function H.party_groups(count, size)
	local groups = {}
	for k = 1, count do
		local members, levels = {}, {}
		for i = 1, size do
			local name = ("p%d_%d"):format(k, i)
			members[i], levels[name] = name, 10
		end
		groups[tostring(k)] = {leader = members[1], faction = "accord",
			members = members, levels = levels}
	end
	return groups
end

------------------------------------------------------------------------------
-- Housing: registry.lua (pure) and stone.lua's pass.
------------------------------------------------------------------------------
function H.registry(repo)
	local data, clock = {}, {t = 1700000000}
	local storage = {
		get_string = function(key) return data[key] or "" end,
		set_string = function(key, value) data[key] = value ~= "" and value or nil end,
		keys = function()
			local list = {}
			for key in pairs(data) do list[#list + 1] = key end
			return list
		end,
	}
	local new = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")
	local M = new({storage = storage, now = function() return clock.t end})
	M.load()
	local function reload()
		local N = new({storage = storage, now = function() return clock.t end})
		N.load()
		return N
	end
	return M, clock, reload
end

-- stone.lua on the real registry; nodes[key] holds the node at a claim
-- centre ("x/y/z"), nil is an unloaded block.
function H.stone(repo)
	local W = {counters = {}, steps = {}, nodes = {}, events = {}}
	local counters, nodes = W.counters, W.nodes
	local M, clock = H.registry(repo)
	W.model, W.clock = M, clock
	local function key(p) return p.x .. "/" .. p.y .. "/" .. p.z end
	W.key = key
	_G.core = {
		register_node = function() end,
		register_on_mods_loaded = function() end,
		-- Round 86 ART: stone.lua reads its look from stone_art.lua.
		get_modpath = function(name) return repo .. "/mods/PLAYER/" .. name end,
		register_globalstep = function(fn) W.steps[#W.steps + 1] = fn end,
		get_node_or_nil = function(pos)
			counted(counters, "get_node")
			local name = nodes[key(pos)]
			return name and {name = name} or nil
		end,
		get_player_by_name = function() return nil end,
		chat_send_player = function() end,
		log = function() end,
	}
	local real_all = M.all_claims
	M.all_claims = function()
		counted(counters, "all_claims")
		return real_all()
	end
	_G.grug_housing = {
		model = M,
		STONE_ITEM = "grug_housing:claim_stone",
		EMPTY_STONE = "grug_housing:claim_stone_empty",
		DRAFT_STONE = "grug_housing:claim_stone_draft",
		STONE_NODES = {["grug_housing:claim_stone"] = true,
			["grug_housing:claim_stone_empty"] = true,
			["grug_housing:claim_stone_draft"] = true},
		-- Round 86: the stone items and the nodes per kind (api.lua), which
		-- stone.lua reads for the Account Claim Stone's copies.
		STONE_ITEMS = {["grug_housing:claim_stone"] = "", ["grug_housing:account_stone"] = "account"},
		STONE_KINDS = {[""] = {item = "grug_housing:claim_stone",
			empty = "grug_housing:claim_stone_empty", draft = "grug_housing:claim_stone_draft"},
			account = {item = "grug_housing:account_stone",
			empty = "grug_housing:account_stone_empty", draft = "grug_housing:account_stone_draft"}},
		sync_stone_node = function(claim)
			counted(counters, "sync")
			core.get_node_or_nil(claim.center)
		end,
		notify_claim_changed = function(claim, event)
			W.events[#W.events + 1] = {id = claim.id, event = event}
		end,
		remove_stone_node = function(claim) nodes[key(claim.center)] = nil end,
	}
	_G.grug_core = {flash = function() end, FLASH_COLOR = {notice = 1}}
	dofile(repo .. "/mods/PLAYER/grug_housing/stone.lua")
	function W.step(dtime)
		for _, fn in ipairs(W.steps) do fn(dtime) end
	end
	-- `count` activated claims 300 nodes apart, their stones standing.
	function W.claims(count, first)
		local list = {}
		for i = 1, count do
			local name = ("owner%d"):format((first or 0) + i)
			M.issue(name, 20, false)
			local claim = M.create(name, {x = ((first or 0) + i) * 300, y = 10, z = 0})
			M.activate(claim, 10)
			nodes[key(claim.center)] = "grug_housing:claim_stone"
			list[i] = claim
		end
		return list
	end
	return W
end

return H
