-- Round 19 UI fixture. Loads the real page builders and drives the real
-- Talents receive-fields callback. The return value is canonical so root can
-- include it in the final cross-interpreter micro-KAT.
return function(repo)
	repo = repo or "."
	local rows = {}
	local function record(name, value)
		rows[#rows + 1] = name .. "=" .. tostring(value)
	end
	local function load_in(env, relative)
		local chunk = assert(loadfile(repo .. "/" .. relative))
		setfenv(chunk, env)
		return chunk()
	end
	local function escape(value)
		return tostring(value):gsub("\\", "\\\\"):gsub("]", "\\]")
			:gsub("%[", "\\["):gsub(";", "\\;"):gsub(",", "\\,")
	end

	-- Formspec parser for the touched visible elements. Escaped separators stay
	-- inside a field; therefore a textarea must serialize to exactly five fields.
	local function fields(body)
		local result, field, escaped = {}, "", false
		for index = 1, #body do
			local char = body:sub(index, index)
			if escaped then
				field = field .. char
				escaped = false
			elseif char == "\\" then
				field = field .. char
				escaped = true
			elseif char == ";" then
				result[#result + 1] = field
				field = ""
			else
				field = field .. char
			end
		end
		result[#result + 1] = field
		return result
	end
	local function elements(spec)
		local result, index = {}, 1
		while true do
			local start, finish, kind = spec:find("([%a_]+)%[", index)
			if not start then break end
			local body, cursor, escaped = "", finish + 1, false
			while cursor <= #spec do
				local char = spec:sub(cursor, cursor)
				if escaped then
					body = body .. char
					escaped = false
				elseif char == "\\" then
					body = body .. char
					escaped = true
				elseif char == "]" then
					break
				else
					body = body .. char
				end
				cursor = cursor + 1
			end
			assert(cursor <= #spec, "unterminated " .. kind)
			result[#result + 1] = {kind = kind, fields = fields(body)}
			index = cursor + 1
		end
		return result
	end

	local function make_meta()
		local data, meta = {}, {}
		function meta:get_string(key) return data[key] or "" end
		function meta:set_string(key, value) data[key] = tostring(value) end
		function meta:get_int(key) return tonumber(data[key]) or 0 end
		function meta:set_int(key, value) data[key] = tostring(value) end
		return meta
	end

	-- Real talent model plus real UI callback.
	local callbacks = {mods_loaded = {}}
	local talent_env = setmetatable({}, {__index = _G})
	talent_env._G = talent_env
	local core = {formspec_escape = escape}
	function core.register_on_player_hpchange() end
	function core.get_item_group() return 0 end
	function core.get_us_time() return 1000000 end
	function core.colorize(_, text) return text end
	function core.chat_send_player() end
	function core.register_chatcommand() end
	function core.register_on_leaveplayer() end
	function core.register_on_dieplayer() end
	function core.register_on_mods_loaded(func)
		callbacks.mods_loaded[#callbacks.mods_loaded + 1] = func
	end
	function core.get_modpath() return repo .. "/mods/PLAYER/grug_classes" end
	function core.get_current_modname() return "grug_classes" end
	talent_env.core = core
	talent_env.dofile = function(path)
		local chunk = assert(loadfile(path))
		setfenv(chunk, talent_env)
		return chunk()
	end
	local classes = {registered_classes = {
		warrior = {id = "warrior", name = "Warrior"},
		mage = {id = "mage", name = "Mage"},
		priest = {id = "priest", name = "Priest"},
		scout = {id = "scout", name = "Scout"},
	}, class_ids = {"warrior", "mage", "priest", "scout"}}
	function classes.get_class(player) return player.class end
	function classes.register_on_class_chosen() end
	function classes.apply_stats() end
	function classes.pool_percent_amount(_, _, percent) return percent end
	talent_env.grug_classes = classes
	local xp = {}
	function xp.get_level(player) return player.level end
	function xp.register_on_level_change() end
	talent_env.grug_xp = xp
	talent_env.grug_money = {
		take = function() return true end,
		format = function(value) return tostring(value) .. "c" end,
	}
	talent_env.grug_core = {
		absorb_modifier = function() return 0 end,
		clear_absorb_modifiers = function() end,
	}
	local inventory_ui = {}
	talent_env.grug_inventory = inventory_ui
	local contexts = {}
	local sfinv = {pages = {}, pages_unordered = {}, contexts = contexts}
	function sfinv.get_nav_fs() return "" end
	function sfinv.register_page(name, def)
		def.name = name
		sfinv.pages[name] = def
		sfinv.pages_unordered[#sfinv.pages_unordered + 1] = def
	end
	function sfinv.make_formspec(_, _, content) return content end
	function sfinv.get_page(player) return contexts[player.name].page end
	function sfinv.set_page() end
	talent_env.sfinv = sfinv
	load_in(talent_env, "mods/PLAYER/grug_classes/talents.lua")
	load_in(talent_env, "mods/PLAYER/grug_inventory/ui.lua")
	load_in(talent_env, "mods/PLAYER/grug_classes/talents_ui.lua")
	local player = {name = "buyer", class = "warrior", level = 60,
		meta = make_meta()}
	function player:get_player_name() return self.name end
	function player:is_player() return true end
	function player:get_meta() return self.meta end
	contexts.buyer = {page = "grug_classes:talents"}
	local page = assert(sfinv.pages["grug_classes:talents"])
	local function talent_field(id)
		for index, candidate in ipairs(classes.talent_ids) do
			if candidate == id then return "grug_talent_pick_" .. index end
		end
		error("missing talent " .. id)
	end
	local function click(id)
		return page:on_player_receive_fields(player, contexts.buyer,
			{[talent_field(id)] = "true"})
	end
	click("ironbound")
	assert(classes.talent_rank(player, "ironbound") == 1,
		"first click did not buy exactly one rank")
	click("ironbound")
	assert(classes.talent_rank(player, "ironbound") == 2,
		"second deliberate click did not buy one further rank")
	click("weathered")
	assert(classes.talent_rank(player, "weathered") == 0,
		"locked talent purchase succeeded")
	assert(contexts.buyer.grug_talent_notice:find("needs 5 points", 1, true),
		"authoritative gate refusal was not surfaced")
	contexts.buyer.grug_talent_tree = "ruin"
	local before = classes.talent_rank(player, "ironbound")
	click("ironbound")
	assert(classes.talent_rank(player, "ironbound") == before,
		"forged hidden-tree field bought a rank")
	contexts.buyer.grug_talent_tree = "bulwark"
	contexts.buyer.grug_talent_selected = "ironbound"
	local ironbound = classes.registered_talents.ironbound
	local saved_description = ironbound.description
	ironbound.description = saved_description .. "; selected detail"
	local talent_spec = classes.talent_formspec_content(player, contexts.buyer)
	ironbound.description = saved_description
	assert(not talent_spec:find("Crit", 1, true) and
		not talent_spec:find("Dodge", 1, true) and
		not talent_spec:find("Armor", 1, true),
		"Talents still renders combat statistics")
	for _, element in ipairs(elements(talent_spec)) do
		if element.kind == "textarea" then
			assert(#element.fields == 5,
				"Talents textarea serialized with " .. #element.fields .. " fields")
		end
	end
	record("talents", "first-click+authority")

	-- Load the real Character/Help page builder into the same bounded UI env.
	-- Its Help prose intentionally contains semicolons, which exercises the
	-- assembled-text escape rather than checking only a source literal.
	function classes.get_class_def() return {resource = "mana"} end
	function classes.get_pool_breakdown()
		return {final = 100, base = 80, class_factor = 1,
			gear_percent = 10, talent_percent = 10, status_percent = 5}
	end
	function classes.get_crit_chance() return 0.15 end
	function classes.get_dodge_chance() return 0.10 end
	talent_env.grug_core.get_armor_rating = function() return 40 end
	talent_env.grug_core.get_armor_rating_breakdown = function()
		return {base = 40, multiplier = 1, emergency = 0, result = 40}
	end
	talent_env.grug_core.get_player_level = function() return 60 end
	talent_env.grug_core.armor_reduction = function() return 0.10 end
	talent_env.grug_core.register_on_equipment_change = function() end
	talent_env.grug_core.register_on_status_modifiers_changed = function() end
	talent_env.grug_money.get = function() return 0 end
	talent_env.grug_money.register_on_change = function() end
	talent_env.grug_inventory.equipment_slots = {}
	talent_env.grug_inventory.BAG_COUNT = 4
	talent_env.grug_inventory.bag_list = function(index) return "bag" .. index end
	talent_env.grug_inventory.content_list = function(index) return "content" .. index end
	talent_env.player_api = {registered_models = {
		["character.b3d"] = {textures = {"character.png"}},
	}}
	function player:get_properties() return {} end
	function player:get_inventory()
		return {get_stack = function()
			return {is_empty = function() return true end,
				get_description = function() return "" end}
		end}
	end
	function sfinv.get_or_create_context(actor) return contexts[actor.name] end
	function sfinv.set_player_inventory_formspec() end
	xp.register_on_level_change = function() end
	load_in(talent_env, "mods/PLAYER/grug_inventory/pages.lua")
	local help_spec = sfinv.pages["grug_inventory:help"]:get(player, contexts.buyer)
	local help_textareas = 0
	for _, element in ipairs(elements(help_spec)) do
		if element.kind == "textarea" then
			help_textareas = help_textareas + 1
			assert(#element.fields == 5,
				"Help textarea serialized with " .. #element.fields .. " fields")
		end
	end
	assert(help_textareas == 1, "unexpected Help textarea count")
	local character_spec = sfinv.pages["grug_inventory:character"]:get(
		player, contexts.buyer)
	assert(character_spec:find("Crit: 15.0%", 1, true) and
		character_spec:find("Dodge: 10.0%", 1, true))
	assert(not character_spec:find("Pool and armor details", 1, true))
	record("character", "concise-totals")

	-- Real Skills page builder. Keep the inventory behavior present while the
	-- check targets its serialized visible elements.
	local skills_env = setmetatable({}, {__index = _G})
	skills_env._G = skills_env
	local detached = {}
	local skill_core = {formspec_escape = escape}
	function skill_core.create_detached_inventory(name)
		local inv = {stacks = {}}
		function inv:set_size() end
		function inv:set_stack(_, index, stack) self.stacks[index] = stack end
		detached[name] = inv
		return inv
	end
	function skill_core.remove_detached_inventory() end
	function skill_core.register_on_joinplayer() end
	function skill_core.register_on_leaveplayer() end
	function skill_core.register_on_mods_loaded() end
	function skill_core.after() end
	function skill_core.chat_send_player() end
	skills_env.core = skill_core
	skills_env.ItemStack = function(name)
		return {get_name = function() return name end}
	end
	local skill_player = {name = "viewer"}
	function skill_player:get_player_name() return self.name end
	function skill_player:get_inventory()
		return {contains_item = function() return false end,
			room_for_item = function() return true end, get_size = function() return 0 end}
	end
	skills_env.grug_inventory = {BAG_COUNT = 4,
		content_list = function(index) return "bag" .. index end}
	skills_env.grug_abilities = {registered = {strike = {name = "Strike"}},
		unlocked_ids = function() return {"strike"} end,
		stack_for = function(_, id) return skills_env.ItemStack("ability:" .. id) end}
	skills_env.grug_mounts = {owned_tier_ids = function() return {1} end,
		stack_for = function(_, id) return skills_env.ItemStack("mount:" .. id) end,
		register_on_owned_tiers_changed = function() end}
	skills_env.grug_classes = {registered_talents = {
		passive = {name = "Careful; Focus", description = "Dodge; safely", ability = false}},
		talent_rank = function() return 1 end,
		talent_description_for = function(_, def) return def.description end,
		register_on_class_chosen = function() end,
		register_on_talents_changed = function() end,
		register_on_race_chosen = function() end}
	skills_env.grug_factions = {register_on_faction_chosen = function() end}
	skills_env.grug_skills = {guard_destinations = function() end,
		is_entitled = function() return true end}
	local skill_sfinv = {pages = {}, pages_unordered = {}}
	function skill_sfinv.register_page(name, def)
		def.name = name
		skill_sfinv.pages[name] = def
		skill_sfinv.pages_unordered[#skill_sfinv.pages_unordered + 1] = def
	end
	function skill_sfinv.make_formspec(_, _, content) return content end
	skills_env.sfinv = skill_sfinv
	load_in(skills_env, "mods/PLAYER/grug_skills/page.lua")
	-- No detached inventory is needed to serialize the page; rebuild safely
	-- returns until the real join callback creates it.
	local skill_spec = skills_env.grug_skills.page_content(skill_player)
	assert(skill_spec:find("Drop skills to remove them. Drag them back from here.",
		1, true), "Skills hint missing")
	local textareas, mount_bottom, passive_top = 0
	for _, element in ipairs(elements(skill_spec)) do
		if element.kind == "textarea" then
			textareas = textareas + 1
			assert(#element.fields == 5,
				"Skills textarea serialized with " .. #element.fields .. " fields")
		elseif element.kind == "list" and element.fields[2] == "catalog" and
				element.fields[5] == "8" then
			local _, y = element.fields[3]:match("^([^,]+),([^,]+)$")
			local _, height = element.fields[4]:match("^([^,]+),([^,]+)$")
			-- Legacy list cells occupy image height 13/15 of their spacing.
			mount_bottom = tonumber(y) + tonumber(height) * 13 / 15
		elseif element.kind == "label" and
				element.fields[2] == "Passive and replacement talents" then
			local _, y = element.fields[1]:match("^([^,]+),([^,]+)$")
			-- Legacy labels are vertically centered with a 0.375-unit text box.
			passive_top = tonumber(y) - 0.375 / 2
		end
	end
	assert(textareas == 1, "unexpected Skills textarea count")
	assert(mount_bottom and passive_top and mount_bottom <= passive_top,
		"Purchased mounts overlap the passive-talents heading")
	record("skills", "textarea-fields-5")

	table.sort(rows)
	return table.concat(rows, "\n") .. "\n"
end
